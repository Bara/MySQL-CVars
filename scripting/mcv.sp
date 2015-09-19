#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <mcv>

enum CVars_Cache
{
	String:cPluginName[MCV_PLUGIN_NAME],
	String:cCvarName[MCV_NAME],
	String:cCvarValue[MCV_VALUE],
	String:cCvarDescription[MCV_DESCRIPTION],
	String:cCvarType[MCV_TYPE]
};

enum ELOG_LEVEL
{
	DEFAULT = 0,
	TRACE,
	DEBUG,
	INFO,
	WARN,
	ERROR
};

char g_sELogLevel[6][32] = {
	"default",
	"trace",
	"debug",
	"info",
	"warn",
	"error"
};

int g_iCVarsCache[CVars_Cache];
ArrayList g_aCVarsCache = null;

Database g_dDB = null;

Handle g_hOnCVarsLoaded = null;

char g_sKVPath[PLATFORM_MAX_PATH];

public Plugin myinfo = 
{
	name = "MySQL CVars",
	author = "Bara",
	description = "Control cvars over mysql",
	version = "1.0.0",
	url = "www.bara.in"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	// Create forwards
	g_hOnCVarsLoaded = CreateGlobalForward("MCV_OnCVarsLoaded", ET_Ignore);
	
	// Create natives
	CreateNative("MCV_AddInt", Native_AddInt);
	CreateNative("MCV_AddBool", Native_AddBool);
	CreateNative("MCV_AddFloat", Native_AddFloat);
	CreateNative("MCV_AddString", Native_AddString);
	
	RegPluginLibrary("mcv");
	
	return APLRes_Success;
}

public void OnPluginStart()
{
	BuildPath(Path_SM, g_sKVPath, sizeof(g_sKVPath), "data/mcv.cfg");
	Database.Connect(OnConnect, "mcv");
}

public void OnMapEnd()
{
	delete g_dDB;
}

public void OnConnect(Database db, const char[] error, any data)
{
	#if defined MCV_DEBUG
		PrintToServer("OnConnect called!");
	#endif
	
	if(db == null || strlen(error) > 0)
	{
		MCV_Log(WARN, "(OnConnect) Connection to database failed!: %s", error);
	}
	else
	{
		g_dDB = db;
		
		DBDriver iDriver = g_dDB.Driver;
		
		char sDriver[16];
		iDriver.GetIdentifier(sDriver, sizeof(sDriver));
		if (!StrEqual(sDriver, "mysql", false))
		{
			MCV_Log(WARN, "(OnConnect) Only mysql support!");
			return;
		}
		
		if(!g_dDB.IsSameConnection(db))
		{
			MCV_Log(WARN, "(OnConnect) g_dDB has another connection as db");
			return;
		}
		
		CreateTable();
	}
	return;
}

stock void CreateTable()
{
	#if defined MCV_DEBUG
		PrintToServer("CreateTable called!");
	#endif
	
	char sQuery[1024];
	
	Format(sQuery, sizeof(sQuery), "\
		CREATE TABLE IF NOT EXISTS `mcv` ( \
			`id` int(11) NOT NULL AUTO_INCREMENT, \
			`plugin_name` varchar(%d) NOT NULL DEFAULT '', \
			`cvar_name` varchar(%d) NOT NULL DEFAULT '', \
			`cvar_value` varchar(%d) NOT NULL DEFAULT '', \
			`cvar_description` varchar(%d) NOT NULL DEFAULT '', \
			`cvar_type` varchar(%d) NOT NULL DEFAULT '', \
			`cvar_created` int(11) NOT NULL, \
			`cvar_last_modified` int(11) NOT NULL, \
			PRIMARY KEY (`id`)) \
		ENGINE=InnoDB DEFAULT CHARSET=utf8;", MCV_PLUGIN_NAME, MCV_NAME, MCV_VALUE, MCV_DESCRIPTION, MCV_TYPE);
	
	#if defined MCV_DEBUG
		PrintToServer("(CreateTable) Query: %s", sQuery);
	#endif
	
	g_dDB.Query(OnTableCreate, sQuery, _, DBPrio_Low);
}

public void OnTableCreate(Database db, DBResultSet results, const char[] error, any data)
{
	if(db == null || strlen(error) > 0)
	{
		MCV_Log(WARN, "(OnTableCreate) Query failed!: %s", error);
		return;
	}
	
	g_dDB.SetCharset("utf8");
	
	FillCache();
}

stock void FillCache()
{
	#if defined MCV_DEBUG
		PrintToServer("FillCache called!");
	#endif
	
	if(g_dDB != null)
	{
		char sQuery[512];
		
		Format(sQuery, sizeof(sQuery), "SELECT plugin_name, cvar_name, cvar_value, cvar_description, cvar_type FROM mcv");
		
		#if defined MCV_DEBUG
			PrintToServer("(FillCache) Query: %s", sQuery);
		#endif
		
		g_dDB.Query(OnFillCache, sQuery, _, DBPrio_High);
	}
	else
	{
		MCV_Log(WARN, "(FillCache) Error! Database is invalid...");
		return;
	}
}

public void OnFillCache(Database db, DBResultSet results, const char[] error, any data)
{
	#if defined MCV_DEBUG
		PrintToServer("OnFillCache called!");
	#endif
	
	if(db == null || strlen(error) > 0)
	{
		MCV_Log(WARN, "(OnFillCache) Query failed!: %s", error);
		return;
	}
	
	if(results.HasResults)
	{
		if(g_aCVarsCache != null)
			g_aCVarsCache.Clear();
		
		g_aCVarsCache = new ArrayList(sizeof(g_iCVarsCache));
		
		while(results.FetchRow())
		{
			int iCvars[CVars_Cache];
	
			results.FetchString(0, iCvars[cPluginName], MCV_PLUGIN_NAME);
			results.FetchString(1, iCvars[cCvarName], MCV_NAME);
			results.FetchString(2, iCvars[cCvarValue], MCV_VALUE);
			results.FetchString(3, iCvars[cCvarDescription], MCV_DESCRIPTION);
			results.FetchString(4, iCvars[cCvarType], MCV_TYPE);
			
			#if defined MCV_DEBUG
				PrintToServer("[OnFillCache] cPluginName: %s - cCvarName: %s - cCvarValue: %s - cCvarDescription: %s - cCarType: %s", iCvars[cPluginName], iCvars[cCvarName], iCvars[cCvarValue], iCvars[cCvarDescription], iCvars[cCvarType]);
			#endif
			
			g_aCVarsCache.PushArray(iCvars[0]);
			
			UpdateBackupFile(iCvars[cPluginName], iCvars[cCvarName], iCvars[cCvarValue], iCvars[cCvarDescription], iCvars[cCvarType]);
		}
	}
	
	Call_StartForward(g_hOnCVarsLoaded);
	Call_Finish();
}

public int Native_AddInt(Handle plugin, int numParams)
{
	#if defined MCV_DEBUG
		PrintToServer("Native_AddInt called!");
	#endif
	
	char sPlName[MCV_PLUGIN_NAME];
	GetPluginBasename(plugin, sPlName, sizeof(sPlName));
	
	char sCName[MCV_NAME];
	int iCValue;
	char sCValue[MCV_VALUE];
	char sCDescription[MCV_DESCRIPTION];
	
	GetNativeString(1, sCName, sizeof(sCName));
	iCValue = view_as<int>(GetNativeCell(2));
	IntToString(iCValue, sCValue, sizeof(sCValue));
	GetNativeString(3, sCDescription, sizeof(sCDescription));
	
	
	#if defined MCV_DEBUG	
		PrintToServer("(Native_AddInt) Plugin: %s", sPlName);
	#endif
	
	bool bFound = false;
	
	if(g_aCVarsCache != null)
	{
		for (int i = 0; i < g_aCVarsCache.Length; i++)
		{
			int iCache[CVars_Cache];
			g_aCVarsCache.GetArray(i, iCache[0]);
			
			#if defined MCV_DEBUG
				PrintToServer("(Native_AddInt) cPluginName: %s - cCvarName: %s - cCvarValue: %s - cCvarDescription: %s - cCarType: %s", iCache[cPluginName], iCache[cCvarName], iCache[cCvarValue], iCache[cCvarDescription], iCache[cCvarType]);
			#endif
	
			if (StrEqual(iCache[cPluginName], sPlName, false) && StrEqual(iCache[cCvarName], sCName, false))
			{
				#if defined MCV_DEBUG
					PrintToServer("(Native_AddInt) Result for \"%s\" found! Value: %d", sCName, StringToInt(iCache[cCvarValue]));
				#endif
				
				bFound = true;
				
				return view_as<int>(StringToInt(iCache[cCvarValue]));
			}
		}
	}
	
	#if defined MCV_DEBUG
		PrintToServer("(Native_AddInt) No result for \"%s\" found!", sCName);
	#endif
	
	if(!bFound)
	{
		if (g_dDB != null)
		{
			char sQuery[2048];
			Format(sQuery, sizeof(sQuery), "INSERT INTO `mcv` (`plugin_name`, `cvar_name`, `cvar_value`, `cvar_description`, `cvar_type`) VALUES ('%s', '%s', '%d', '%s', '%s')", sPlName, sCName, iCValue, sCDescription, "int");
			
			#if defined MCV_DEBUG
				PrintToServer("(Native_AddInt) Query: %s", sQuery);
			#endif
			
			g_dDB.Query(OnCvarAdd, sQuery, _, DBPrio_High);
			
			int iCvars[CVars_Cache];
			
			Format(iCvars[cPluginName], MCV_PLUGIN_NAME, "%s", sPlName);
			Format(iCvars[cCvarName], MCV_NAME, "%s", sCName);
			Format(iCvars[cCvarValue], MCV_VALUE, "%d", iCValue);
			Format(iCvars[cCvarDescription], MCV_DESCRIPTION, "%s", sCDescription);
			Format(iCvars[cCvarType], MCV_TYPE, "int");
			
			#if defined MCV_DEBUG
				PrintToServer("[Native_AddInt] cPluginName: %s - cCvarName: %s - cCvarValue: %s - cCvarDescription: %s - cCarType: %s", iCvars[cPluginName], iCvars[cCvarName], iCvars[cCvarValue], iCvars[cCvarDescription], iCvars[cCvarType]);
			#endif
			
			g_aCVarsCache.PushArray(iCvars[0]);
			UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "int");
		}
		else
		{
			UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "int");
			MCV_Log(WARN, "(Native_AddInt) Error! Database is invalid...");
		}

		return iCValue;
	}
	else
	{
		UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "int");
	}
	
	return -1;
}

public int Native_AddBool(Handle plugin, int numParams)
{
	#if defined MCV_DEBUG
		PrintToServer("Native_AddBool called!");
	#endif
	
	char sPlName[MCV_PLUGIN_NAME];
	GetPluginBasename(plugin, sPlName, sizeof(sPlName));
	
	char sCName[MCV_NAME];
	bool bCValue;
	char sCValue[MCV_VALUE];
	char sCDescription[MCV_DESCRIPTION];
	
	GetNativeString(1, sCName, sizeof(sCName));
	bCValue = view_as<bool>(GetNativeCell(2));
	IntToString(bCValue, sCValue, sizeof(sCValue));
	GetNativeString(3, sCDescription, sizeof(sCDescription));
	
	
	#if defined MCV_DEBUG	
		PrintToServer("(Native_AddBool) Plugin: %s", sPlName);
	#endif
	
	bool bFound = false;
	
	if(g_aCVarsCache != null)
	{
		for (int i = 0; i < g_aCVarsCache.Length; i++)
		{
			int iCache[CVars_Cache];
			g_aCVarsCache.GetArray(i, iCache[0]);
			
			#if defined MCV_DEBUG
				PrintToServer("(Native_AddBool) cPluginName: %s - cCvarName: %s - cCvarValue: %s - cCvarDescription: %s - cCarType: %s", iCache[cPluginName], iCache[cCvarName], iCache[cCvarValue], iCache[cCvarDescription], iCache[cCvarType]);
			#endif
	
			if (StrEqual(iCache[cPluginName], sPlName, false) && StrEqual(iCache[cCvarName], sCName, false))
			{
				#if defined MCV_DEBUG
					PrintToServer("(Native_AddBool) Result for \"%s\" found! Value: %d", sCName, StringToInt(iCache[cCvarValue]));
				#endif
				
				bFound = true;
				
				return view_as<bool>(StringToInt(iCache[cCvarValue]));
			}
		}
	}
	
	#if defined MCV_DEBUG
		PrintToServer("(Native_AddBool) No result for \"%s\" found!", sCName);
	#endif
	
	if(!bFound)
	{
		if (g_dDB != null)
		{
			char sQuery[2048];
			Format(sQuery, sizeof(sQuery), "INSERT INTO `mcv` (`plugin_name`, `cvar_name`, `cvar_value`, `cvar_description`, `cvar_type`) VALUES ('%s', '%s', '%d', '%s', '%s')", sPlName, sCName, bCValue, sCDescription, "bool");
			
			#if defined MCV_DEBUG
				PrintToServer("(Native_AddBool) Query: %s", sQuery);
			#endif
			
			g_dDB.Query(OnCvarAdd, sQuery, _, DBPrio_High);
			
			int iCvars[CVars_Cache];
			
			Format(iCvars[cPluginName], MCV_PLUGIN_NAME, "%s", sPlName);
			Format(iCvars[cCvarName], MCV_NAME, "%s", sCName);
			Format(iCvars[cCvarValue], MCV_VALUE, "%d", bCValue);
			Format(iCvars[cCvarDescription], MCV_DESCRIPTION, "%s", sCDescription);
			Format(iCvars[cCvarType], MCV_TYPE, "bool");
			
			#if defined MCV_DEBUG
				PrintToServer("[Native_AddBool] cPluginName: %s - cCvarName: %s - cCvarValue: %s - cCvarDescription: %s - cCarType: %s", iCvars[cPluginName], iCvars[cCvarName], iCvars[cCvarValue], iCvars[cCvarDescription], iCvars[cCvarType]);
			#endif
			
			g_aCVarsCache.PushArray(iCvars[0]);
			UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "bool");
		}
		else
		{
			UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "bool");
			MCV_Log(WARN, "(Native_AddBool) Error! Database is invalid...");
		}

		return bCValue;
	}
	else
	{
		UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "bool");
	}
	
	return -1;
}

public int Native_AddFloat(Handle plugin, int numParams)
{
	#if defined MCV_DEBUG
		PrintToServer("Native_AddFloat called!");
	#endif
	
	char sPlName[MCV_PLUGIN_NAME];
	GetPluginBasename(plugin, sPlName, sizeof(sPlName));
	
	char sCName[MCV_NAME];
	float fCValue;
	char sCValue[MCV_VALUE];
	char sCDescription[MCV_DESCRIPTION];
	
	GetNativeString(1, sCName, sizeof(sCName));
	fCValue = view_as<float>(GetNativeCell(2));
	FloatToString(fCValue, sCValue, sizeof(sCValue));
	GetNativeString(3, sCDescription, sizeof(sCDescription));
	
	#if defined MCV_DEBUG	
		PrintToServer("(Native_AddFloat) Plugin: %s", sPlName);
	#endif
	
	bool bFound = false;
	
	if(g_aCVarsCache != null)
	{
		for (int i = 0; i < g_aCVarsCache.Length; i++)
		{
			int iCache[CVars_Cache];
			g_aCVarsCache.GetArray(i, iCache[0]);
			
			#if defined MCV_DEBUG
				PrintToServer("(Native_AddFloat) cPluginName: %s - cCvarName: %s - cCvarValue: %s - cCvarDescription: %s - cCarType: %s", iCache[cPluginName], iCache[cCvarName], iCache[cCvarValue], iCache[cCvarDescription], iCache[cCvarType]);
			#endif
	
			if (StrEqual(iCache[cPluginName], sPlName, false) && StrEqual(iCache[cCvarName], sCName, false))
			{
				#if defined MCV_DEBUG
					PrintToServer("(Native_AddFloat) Result for \"%s\" found! Value: %f", sCName, StringToFloat(iCache[cCvarValue]));
				#endif
				
				bFound = true;
				
				return view_as<int>(StringToFloat(iCache[cCvarValue]));
			}
		}
	}
	
	#if defined MCV_DEBUG
		PrintToServer("(Native_AddFloat) No result for \"%s\" found!", sCName);
	#endif
	
	if(!bFound)
	{
		if (g_dDB != null)
		{
			char sQuery[2048];
			Format(sQuery, sizeof(sQuery), "INSERT INTO `mcv` (`plugin_name`, `cvar_name`, `cvar_value`, `cvar_description`, `cvar_type`) VALUES ('%s', '%s', '%f', '%s', '%s')", sPlName, sCName, fCValue, sCDescription, "float");
			
			#if defined MCV_DEBUG
				PrintToServer("(Native_AddFloat) Query: %s", sQuery);
			#endif
			
			g_dDB.Query(OnCvarAdd, sQuery, _, DBPrio_High);
			
			int iCvars[CVars_Cache];
			
			Format(iCvars[cPluginName], MCV_PLUGIN_NAME, "%s", sPlName);
			Format(iCvars[cCvarName], MCV_NAME, "%s", sCName);
			Format(iCvars[cCvarValue], MCV_VALUE, "%f", fCValue);
			Format(iCvars[cCvarDescription], MCV_DESCRIPTION, "%s", sCDescription);
			Format(iCvars[cCvarType], MCV_TYPE, "float");
			
			#if defined MCV_DEBUG
				PrintToServer("[Native_AddFloat] cPluginName: %s - cCvarName: %s - cCvarValue: %s - cCvarDescription: %s - cCarType: %s", iCvars[cPluginName], iCvars[cCvarName], iCvars[cCvarValue], iCvars[cCvarDescription], iCvars[cCvarType]);
			#endif
			
			g_aCVarsCache.PushArray(iCvars[0]);
			UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "float");
		}
		else
		{
			UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "float");
			MCV_Log(WARN, "(Native_AddFloat) Error! Database is invalid...");
		}

		return view_as<int>(fCValue);
	}
	else
	{
		UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "float");
	}
	
	return view_as<int>(0.0);
}

public int Native_AddString(Handle plugin, int numParams)
{
	#if defined MCV_DEBUG
		PrintToServer("Native_AddString called!");
	#endif
	
	char sPlName[MCV_PLUGIN_NAME];
	GetPluginBasename(plugin, sPlName, sizeof(sPlName));
	
	char sCName[MCV_NAME];
	char sCValue[MCV_VALUE];
	char sCDescription[MCV_DESCRIPTION];
	
	GetNativeString(1, sCName, sizeof(sCName));
	GetNativeString(2, sCValue, sizeof(sCValue));
	GetNativeString(3, sCDescription, sizeof(sCDescription));
	
	#if defined MCV_DEBUG	
		PrintToServer("(Native_AddString) Plugin: %s", sPlName);
	#endif
	
	bool bFound = false;
	
	if(g_aCVarsCache != null)
	{
		for (int i = 0; i < g_aCVarsCache.Length; i++)
		{
			int iCache[CVars_Cache];
			g_aCVarsCache.GetArray(i, iCache[0]);
			
			#if defined MCV_DEBUG
				PrintToServer("(Native_AddString) cPluginName: %s - cCvarName: %s - cCvarValue: %s - cCvarDescription: %s - cCarType: %s", iCache[cPluginName], iCache[cCvarName], iCache[cCvarValue], iCache[cCvarDescription], iCache[cCvarType]);
			#endif
	
			if (StrEqual(iCache[cPluginName], sPlName, false) && StrEqual(iCache[cCvarName], sCName, false))
			{
				#if defined MCV_DEBUG
					PrintToServer("(Native_AddString) Result for \"%s\" found! Value: %s", sCName, iCache[cCvarValue]);
				#endif
				
				bFound = true;
				
				return SetNativeString(4, iCache[cCvarValue], GetNativeCell(5), false);
			}
		}
	}
	
	#if defined MCV_DEBUG
		PrintToServer("(Native_AddString) No result for \"%s\" found!", sCName);
	#endif
	
	if(!bFound)
	{
		if (g_dDB != null)
		{
			char sEscapedCValue[MCV_VALUE];
			g_dDB.Escape(sCValue, sEscapedCValue, sizeof(sEscapedCValue));
			
			char sQuery[2048];
			Format(sQuery, sizeof(sQuery), "INSERT INTO `mcv` (`plugin_name`, `cvar_name`, `cvar_value`, `cvar_description`, `cvar_type`) VALUES ('%s', '%s', '%s', '%s', '%s')", sPlName, sCName, sEscapedCValue, sCDescription, "string");
			
			#if defined MCV_DEBUG
				PrintToServer("(Native_AddString) Query: %s", sQuery);
			#endif
			
			g_dDB.Query(OnCvarAdd, sQuery, _, DBPrio_High);
			
			int iCvars[CVars_Cache];
			
			Format(iCvars[cPluginName], MCV_PLUGIN_NAME, "%s", sPlName);
			Format(iCvars[cCvarName], MCV_NAME, "%s", sCName);
			Format(iCvars[cCvarValue], MCV_VALUE, "%s", sCValue);
			Format(iCvars[cCvarDescription], MCV_DESCRIPTION, "%s", sCDescription);
			Format(iCvars[cCvarType], MCV_TYPE, "string");
			
			#if defined MCV_DEBUG
				PrintToServer("[Native_AddString] cPluginName: %s - cCvarName: %s - cCvarValue: %s - cCvarDescription: %s - cCarType: %s", iCvars[cPluginName], iCvars[cCvarName], iCvars[cCvarValue], iCvars[cCvarDescription], iCvars[cCvarType]);
			#endif
			
			g_aCVarsCache.PushArray(iCvars[0]);
			UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "string");
		}
		else
		{
			UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "string");
			MCV_Log(WARN, "(Native_AddString) Error! Database is invalid...");
		}

		return SetNativeString(4, sCValue, GetNativeCell(5), false);
	}
	else
	{
		UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "string");
	}
	
	return SetNativeString(4, "", GetNativeCell(5), false);
}

public void OnCvarAdd(Database db, DBResultSet results, const char[] error, any data)
{
	#if defined MCV_DEBUG
		PrintToServer("OnAddCvar called!");
	#endif
	
	if(db == null || strlen(error) > 0)
	{
		MCV_Log(WARN, "(OnAddCvar) Query failed!: %s", error);
	}
}

stock void GetPluginBasename(Handle plugin, char[] buffer, int maxlength)
{
	GetPluginFilename(plugin, buffer, maxlength);
	ReplaceString(buffer, maxlength, ".smx", "", false);
}

stock void UpdateBackupFile(const char[] plugin, const char[] name, const char[] value, const char[] description, const char[] type)
{
	PrintToServer("(UpdateBackupFile) Name: %s Value: %s Description: %s", name, value, description);
	
	KeyValues kv_Backup = CreateKeyValues("MCV");
	
	if(!kv_Backup.ImportFromFile(g_sKVPath))
	{
		ThrowError("Can't read mcv.cfg correctly!");
		return;
	}
	
	kv_Backup.JumpToKey(plugin, true);
	kv_Backup.JumpToKey(name, true);
	
	if(StrEqual(type, "string", false))
	{
		PrintToServer("(UpdateBackupFile) [String] Name: %s Value: %s Description: %s", name, value, description);
		kv_Backup.SetString("value", value);
		kv_Backup.SetString("description", description);
	}
	
	if(StrEqual(type, "int", false) || StrEqual(type, "bool", false))
	{
		PrintToServer("(UpdateBackupFile) [Int/Bool] Name: %s Value: %s Description: %s", name, value, description);
		kv_Backup.SetNum("value", StringToInt(value));
		kv_Backup.SetString("description", description);
	}
	
	if(StrEqual(type, "float", false))
	{
		PrintToServer("(UpdateBackupFile) [Float] Name: %s Value: %s Description: %s", name, value, description);
		kv_Backup.SetFloat("value", StringToFloat(value));
		kv_Backup.SetString("description", description);
	}
	
	kv_Backup.Rewind();
	kv_Backup.ExportToFile(g_sKVPath);
	
	delete kv_Backup;
}

stock void GetBackupValue(const char[] plugin, const char[] name, const char[] type)
{
	KeyValues kv_Backup = CreateKeyValues("MCV");
	
	if(!kv_Backup.ImportFromFile(g_sKVPath))
	{
		ThrowError("Can't read mcv.cfg correctly!");
		return;
	}
	
	if(!kv_Backup.JumpToKey(plugin, false))
	{
		ThrowError("Can't find cvars for %s!", plugin);
		return;
	}
	
	if(!kv_Backup.JumpToKey(name, false))
	{
		ThrowError("Can't find cvar %s for %s!", name, plugin);
		return;
	}
	
	if (StrEqual(type, "int", false))
		return kv_Backup.GetNum("value");
	else if (StrEqual(type, "bool", false))
		return view_as<bool>(kv_Backup.GetNum("value"));
	else if (StrEqual(type, "float", false))
		return view_as<float>(kv_Backup.GetFloat("value"));
}

stock void GetBackupStringValue(const char[] plugin, const char[] name, char[] output, int size)
{
	KeyValues kv_Backup = CreateKeyValues("MCV");
	
	if(!kv_Backup.ImportFromFile(g_sKVPath))
	{
		ThrowError("Can't read mcv.cfg correctly!");
		return;
	}
	
	if(!kv_Backup.JumpToKey(plugin, false))
	{
		ThrowError("Can't find cvars for %s!", plugin);
		return;
	}
	
	if(!kv_Backup.JumpToKey(name, false))
	{
		ThrowError("Can't find cvar %s for %s!", name, plugin);
		return;
	}
	
	kv_Backup.GetString("value", output, size);
	return;
}

stock void MCV_Log(ELOG_LEVEL level = INFO, const char[] format, any ...)
{
	char sPath[PLATFORM_MAX_PATH + 1];
	char sLevelPath[PLATFORM_MAX_PATH + 1];
	char sFile[PLATFORM_MAX_PATH + 1];
	char sBuffer[1024];

	BuildPath(Path_SM, sPath, sizeof(sPath), "logs/mcv");
		
	if(!DirExists(sPath))
	{
		CreateDirectory(sPath, 755);
	}

	if(level < TRACE || level > ERROR)
	{
		Format(sLevelPath, sizeof(sLevelPath), "%s", sPath);
	}
	else
	{
		Format(sLevelPath, sizeof(sLevelPath), "%s/%s", sPath, g_sELogLevel[level]);
	}

	
	if(!DirExists(sLevelPath))
	{
		CreateDirectory(sLevelPath, 755);
	}

	char buffer[16];
	FormatTime(buffer, sizeof(buffer), "%Y%m%d", GetTime());
	Format(sFile, sizeof(sFile), "%s/%s-%s.log", sLevelPath, buffer);

	VFormat(sBuffer, sizeof(sBuffer), format, 6);

	LogToFile(sFile, sBuffer);
}

