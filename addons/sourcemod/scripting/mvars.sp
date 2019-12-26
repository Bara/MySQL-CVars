#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <autoexecconfig>
#include <mvars>

#define PLUGIN_VERSION "2.0.0"
#define PLUGIN_DESCRIPTION "With mVars you can control your convars over mysql, but as a side note: every plugin need an update."

enum struct mVar
{
    char PluginName[64];
    char Name[64];
    char Value[512];
    char Description[512];
    char Type[8];
}

ConVar g_cDebug = null;

ArrayList g_aVars = null;

Database g_dDatabase = null;

Handle g_hOnVarsLoaded = null;

char g_sKVPath[PLATFORM_MAX_PATH];
char g_sCharset[12] = "utf8mb4";

public Plugin myinfo = 
{
    name = "mVars",
    author = "Bara",
    description = PLUGIN_DESCRIPTION,
    version = PLUGIN_VERSION,
    url = "github.com/Bara"
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
    // Create forwards
    g_hOnVarsLoaded = CreateGlobalForward("MVars_OnVarsLoaded", ET_Ignore);
    
    // Create natives
    CreateNative("MVars_AddInt", Native_AddInt);
    CreateNative("MVars_AddBool", Native_AddBool);
    CreateNative("MVars_AddFloat", Native_AddFloat);
    CreateNative("MVars_AddString", Native_AddString);
    
    RegPluginLibrary("mvars");
    
    return APLRes_Success;
}

public void OnPluginStart()
{
    BuildPath(Path_SM, g_sKVPath, sizeof(g_sKVPath), "data/mvars.cfg");
    
    if (SQL_CheckConfig("mvars"))
    {
        Database.Connect(OnConnect, "mvars");
    }
    else
    {
        LogError("(OnPluginStart) No database entry found for \"mvars\" in databases.cfg");
        CallForward(g_hOnVarsLoaded);
    }
    
    CreateConVar("mysql_cvars_version", PLUGIN_VERSION, PLUGIN_DESCRIPTION, FCVAR_NOTIFY | FCVAR_DONTRECORD);

    AutoExecConfig_SetCreateDirectory(true);
    AutoExecConfig_SetCreateFile(true);
    AutoExecConfig_SetFile("plugin.mvars");
    g_cDebug = AutoExecConfig_CreateConVar("mvars_debug_mode", "0", "Enable or disable debug mode", _, true, 0.0, true, 1.0);
    AutoExecConfig_ExecuteFile();
    AutoExecConfig_CleanFile();
}

public void OnMapEnd()
{
    delete g_dDatabase;
}

public void OnConnect(Database db, const char[] error, any data)
{
    if (g_cDebug.BoolValue)
    {
        PrintToServer("OnConnect called!");
    }
    
    if(db == null || strlen(error) > 0)
    {
        CallForward(g_hOnVarsLoaded);
        LogError("(OnConnect) Connection to database failed!: %s", error);
    }
    else
    {
        g_dDatabase = db;
        
        DBDriver iDriver = g_dDatabase.Driver;
        
        char sDriver[16];
        iDriver.GetIdentifier(sDriver, sizeof(sDriver));
        if (!StrEqual(sDriver, "mysql", false))
        {
            CallForward(g_hOnVarsLoaded);
            LogError("(OnConnect) Only mysql support!");
            return;
        }
        
        if(!g_dDatabase.IsSameConnection(db))
        {
            CallForward(g_hOnVarsLoaded);
            LogMessage("(OnConnect) g_dDatabase has another connection as db");
            return;
        }

        if (!g_dDatabase.SetCharset(g_sCharset))
        {
            Format(g_sCharset, sizeof(g_sCharset), "utf8");
            g_dDatabase.SetCharset(g_sCharset);
        }
        
        CreateTable();
    }
    return;
}

stock void CreateTable()
{
    if (g_cDebug.BoolValue)
    {
        PrintToServer("CreateTable called!");
    }
    
    char sQuery[1024];
    
    Format(sQuery, sizeof(sQuery), "\
        CREATE TABLE IF NOT EXISTS `mvars` ( \
            `id` int(11) NOT NULL AUTO_INCREMENT, \
            `plugin_name` varchar(64) NOT NULL DEFAULT '', \
            `cvar_name` varchar(64) NOT NULL DEFAULT '', \
            `cvar_value` varchar(512) NOT NULL DEFAULT '', \
            `cvar_description` varchar(512) NOT NULL DEFAULT '', \
            `cvar_type` varchar(8) NOT NULL DEFAULT '', \
            `cvar_created` int(11) NOT NULL, \
            `cvar_last_modified` int(11) NOT NULL, \
            PRIMARY KEY (`id`)) \
        ENGINE=InnoDB DEFAULT CHARSET=%s;", g_sCharset);
    
    if (g_cDebug.BoolValue)
    {
        PrintToServer("(CreateTable) Query: %s", sQuery);
    }
    
    g_dDatabase.Query(OnTableCreate, sQuery, _, DBPrio_Low);
}

public void OnTableCreate(Database db, DBResultSet results, const char[] error, any data)
{
    if(db == null || strlen(error) > 0)
    {
        CallForward(g_hOnVarsLoaded);
        LogError("(OnTableCreate) Query failed!: %s", error);
        return;
    }
    
    FillCache();
}

stock void FillCache()
{
    if (g_cDebug.BoolValue)
    {
        PrintToServer("FillCache called!");
    }
    
    if(g_dDatabase != null)
    {
        char sQuery[512];
        
        Format(sQuery, sizeof(sQuery), "SELECT plugin_name, cvar_name, cvar_value, cvar_description, cvar_type FROM mvars");
        
        if (g_cDebug.BoolValue)
        {
            PrintToServer("(FillCache) Query: %s", sQuery);
        }
        
        g_dDatabase.Query(OnFillCache, sQuery, _, DBPrio_High);
    }
    else
    {
        CallForward(g_hOnVarsLoaded);
        LogError("(FillCache) Error! Database is invalid...");
        return;
    }
}

public void OnFillCache(Database db, DBResultSet results, const char[] error, any data)
{
    if (g_cDebug.BoolValue)
    {
        PrintToServer("OnFillCache called!");
    }
    
    if(db == null || strlen(error) > 0)
    {
        CallForward(g_hOnVarsLoaded);
        LogError("(OnFillCache) Query failed!: %s", error);
        return;
    }
    
    if(results.HasResults)
    {
        if(g_aVars != null)
            g_aVars.Clear();
        
        g_aVars = new ArrayList(sizeof(mVar));
        
        while(results.FetchRow())
        {
            mVar mvar;
    
            results.FetchString(0, mvar.PluginName, sizeof(mvar.PluginName));
            results.FetchString(1, mvar.Name, sizeof(mvar.Name));
            results.FetchString(2, mvar.Value, sizeof(mvar.Value));
            results.FetchString(3, mvar.Description, sizeof(mvar.Description));
            results.FetchString(4, mvar.Type, sizeof(mvar.Type));
            
            if (g_cDebug.BoolValue)
            {
                PrintToServer("[OnFillCache] cluginName: %s - Name: %s - Value: %s - Description: %s - Type: %s", mvar.PluginName, mvar.Name, mvar.Value, mvar.Description, mvar.Type);
            }
            
            g_aVars.PushArray(mvar);
            
            UpdateBackupFile(mvar.PluginName, mvar.Name, mvar.Value, mvar.Description, mvar.Type);
        }
    }
    
    CallForward(g_hOnVarsLoaded);
}

public int Native_AddInt(Handle plugin, int numParams)
{
    if (g_cDebug.BoolValue)
    {
        PrintToServer("Native_AddInt called!");
    }
    
    char sPlName[64];
    GetPluginBasename(plugin, sPlName, sizeof(sPlName));
    
    char sCName[64];
    int iCValue;
    char sCValue[512];
    char sCDescription[512];
    
    GetNativeString(1, sCName, sizeof(sCName));
    iCValue = view_as<int>(GetNativeCell(2));
    IntToString(iCValue, sCValue, sizeof(sCValue));
    GetNativeString(3, sCDescription, sizeof(sCDescription));
    
    
    if (g_cDebug.BoolValue)	
    {
        PrintToServer("(Native_AddInt) Plugin: %s", sPlName);
    }
    
    bool bFound = false;
    
    if(g_aVars != null)
    {
        for (int i = 0; i < g_aVars.Length; i++)
        {
            mVar mvar;
            g_aVars.GetArray(i, mvar);
            
            if (g_cDebug.BoolValue)
            {
                PrintToServer("(Native_AddInt) PluginName: %s - Name: %s - Value: %s - Description: %s - Type: %s", mvar.PluginName, mvar.Name, mvar.Value, mvar.Description, mvar.Type);
            }
    
            if (StrEqual(mvar.PluginName, sPlName, false) && StrEqual(mvar.Name, sCName, false))
            {
                if (g_cDebug.BoolValue)
                {
                    PrintToServer("(Native_AddInt) Result for \"%s\" found! Value: %d", sCName, StringToInt(mvar.Value));
                }
                
                bFound = true;
                
                return view_as<int>(StringToInt(mvar.Value));
            }
        }
    }
    
    if (g_cDebug.BoolValue)
    {
        PrintToServer("(Native_AddInt) No result for \"%s\" found!", sCName);
    }
    
    if(!bFound)
    {
        if (g_dDatabase != null)
        {
            char sQuery[2048];
            Format(sQuery, sizeof(sQuery), "INSERT INTO `mvars` (`plugin_name`, `cvar_name`, `cvar_value`, `cvar_description`, `cvar_type`) VALUES ('%s', '%s', '%d', '%s', '%s')", sPlName, sCName, iCValue, sCDescription, "int");
            
            if (g_cDebug.BoolValue)
            {
                PrintToServer("(Native_AddInt) Query: %s", sQuery);
            }
            
            g_dDatabase.Query(OnCvarAdd, sQuery, _, DBPrio_High);
            
            mVar mvar;
            
            Format(mvar.PluginName, sizeof(mvar.PluginName), "%s", sPlName);
            Format(mvar.Name, sizeof(mvar.Name), "%s", sCName);
            Format(mvar.Value, sizeof(mvar.Value), "%d", iCValue);
            Format(mvar.Description, sizeof(mvar.Description), "%s", sCDescription);
            Format(mvar.Type, sizeof(mvar.Type), "int");
            
            if (g_cDebug.BoolValue)
            {
                PrintToServer("[Native_AddInt] PluginName: %s - Name: %s - Value: %s - Description: %s - Type: %s", mvar.PluginName, mvar.Name, mvar.Value, mvar.Description, mvar.Type);
            }
            
            g_aVars.PushArray(mvar);
            UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "int");
        }
        else
        {
            UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "int");
            LogError("(Native_AddInt) Error! Database is invalid...");
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
    if (g_cDebug.BoolValue)
    {
        PrintToServer("Native_AddBool called!");
    }
    
    char sPlName[64];
    GetPluginBasename(plugin, sPlName, sizeof(sPlName));
    
    char sCName[64];
    bool bCValue;
    char sCValue[512];
    char sCDescription[512];
    
    GetNativeString(1, sCName, sizeof(sCName));
    bCValue = view_as<bool>(GetNativeCell(2));
    IntToString(bCValue, sCValue, sizeof(sCValue));
    GetNativeString(3, sCDescription, sizeof(sCDescription));
    
    
    if (g_cDebug.BoolValue)	
    {
        PrintToServer("(Native_AddBool) Plugin: %s", sPlName);
    }
    
    bool bFound = false;
    
    if(g_aVars != null)
    {
        for (int i = 0; i < g_aVars.Length; i++)
        {
            mVar mvar;
            g_aVars.GetArray(i, mvar);
            
            if (g_cDebug.BoolValue)
            {
                PrintToServer("(Native_AddBool) PluginName: %s - Name: %s - Value: %s - Description: %s - Type: %s", mvar.PluginName, mvar.Name, mvar.Value, mvar.Description, mvar.Type);
            }
    
            if (StrEqual(mvar.PluginName, sPlName, false) && StrEqual(mvar.Name, sCName, false))
            {
                if (g_cDebug.BoolValue)
                {
                    PrintToServer("(Native_AddBool) Result for \"%s\" found! Value: %d", sCName, StringToInt(mvar.Value));
                }
                
                bFound = true;
                
                return view_as<bool>(StringToInt(mvar.Value));
            }
        }
    }
    
    if (g_cDebug.BoolValue)
    {
        PrintToServer("(Native_AddBool) No result for \"%s\" found!", sCName);
    }
    
    if(!bFound)
    {
        if (g_dDatabase != null)
        {
            char sQuery[2048];
            Format(sQuery, sizeof(sQuery), "INSERT INTO `mvars` (`plugin_name`, `cvar_name`, `cvar_value`, `cvar_description`, `cvar_type`) VALUES ('%s', '%s', '%d', '%s', '%s')", sPlName, sCName, bCValue, sCDescription, "bool");
            
            if (g_cDebug.BoolValue)
            {
                PrintToServer("(Native_AddBool) Query: %s", sQuery);
            }
            
            g_dDatabase.Query(OnCvarAdd, sQuery, _, DBPrio_High);
            
            mVar mvar;
            
            Format(mvar.PluginName, sizeof(mvar.PluginName), "%s", sPlName);
            Format(mvar.Name, sizeof(mvar.Name), "%s", sCName);
            Format(mvar.Value, sizeof(mvar.Value), "%d", bCValue);
            Format(mvar.Description, sizeof(mvar.Description), "%s", sCDescription);
            Format(mvar.Type, sizeof(mvar.Type), "bool");
            
            if (g_cDebug.BoolValue)
            {
                PrintToServer("[Native_AddBool] PluginName: %s - Name: %s - Value: %s - Description: %s - Type: %s", mvar.PluginName, mvar.Name, mvar.Value, mvar.Description, mvar.Type);
            }
            
            g_aVars.PushArray(mvar);
            UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "bool");
        }
        else
        {
            UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "bool");
            LogError("(Native_AddBool) Error! Database is invalid...");
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
    if (g_cDebug.BoolValue)
    {
        PrintToServer("Native_AddFloat called!");
    }
    
    char sPlName[64];
    GetPluginBasename(plugin, sPlName, sizeof(sPlName));
    
    char sCName[64];
    float fCValue;
    char sCValue[512];
    char sCDescription[512];
    
    GetNativeString(1, sCName, sizeof(sCName));
    fCValue = view_as<float>(GetNativeCell(2));
    FloatToString(fCValue, sCValue, sizeof(sCValue));
    GetNativeString(3, sCDescription, sizeof(sCDescription));
    
    if (g_cDebug.BoolValue)	
    {
        PrintToServer("(Native_AddFloat) Plugin: %s", sPlName);
    }
    
    bool bFound = false;
    
    if(g_aVars != null)
    {
        for (int i = 0; i < g_aVars.Length; i++)
        {
            mVar mvar;
            g_aVars.GetArray(i, mvar);
            
            if (g_cDebug.BoolValue)
            {
                PrintToServer("(Native_AddFloat) PluginName: %s - Name: %s - Value: %s - Description: %s - Type: %s", mvar.PluginName, mvar.Name, mvar.Value, mvar.Description, mvar.Type);
            }
    
            if (StrEqual(mvar.PluginName, sPlName, false) && StrEqual(mvar.Name, sCName, false))
            {
                if (g_cDebug.BoolValue)
                {
                    PrintToServer("(Native_AddFloat) Result for \"%s\" found! Value: %f", sCName, StringToFloat(mvar.Value));
                }
                
                bFound = true;
                
                return view_as<int>(StringToFloat(mvar.Value));
            }
        }
    }
    
    if (g_cDebug.BoolValue)
    {
        PrintToServer("(Native_AddFloat) No result for \"%s\" found!", sCName);
    }
    
    if(!bFound)
    {
        if (g_dDatabase != null)
        {
            char sQuery[2048];
            Format(sQuery, sizeof(sQuery), "INSERT INTO `mvars` (`plugin_name`, `cvar_name`, `cvar_value`, `cvar_description`, `cvar_type`) VALUES ('%s', '%s', '%f', '%s', '%s')", sPlName, sCName, fCValue, sCDescription, "float");
            
            if (g_cDebug.BoolValue)
            {
                PrintToServer("(Native_AddFloat) Query: %s", sQuery);
            }
            
            g_dDatabase.Query(OnCvarAdd, sQuery, _, DBPrio_High);
            
            mVar mvar;
            
            Format(mvar.PluginName, sizeof(mvar.PluginName), "%s", sPlName);
            Format(mvar.Name, sizeof(mvar.Name), "%s", sCName);
            Format(mvar.Value, sizeof(mvar.Value), "%f", fCValue);
            Format(mvar.Description, sizeof(mvar.Description), "%s", sCDescription);
            Format(mvar.Type, sizeof(mvar.Type), "float");
            
            if (g_cDebug.BoolValue)
            {
                PrintToServer("[Native_AddFloat] PluginName: %s - Name: %s - Value: %s - Description: %s - Type: %s", mvar.PluginName, mvar.Name, mvar.Value, mvar.Description, mvar.Type);
            }
            
            g_aVars.PushArray(mvar);
            UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "float");
        }
        else
        {
            UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "float");
            LogError("(Native_AddFloat) Error! Database is invalid...");
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
    if (g_cDebug.BoolValue)
    {
        PrintToServer("Native_AddString called!");
    }
    
    char sPlName[64];
    GetPluginBasename(plugin, sPlName, sizeof(sPlName));
    
    char sCName[64];
    char sCValue[512];
    char sCDescription[512];
    
    GetNativeString(1, sCName, sizeof(sCName));
    GetNativeString(2, sCValue, sizeof(sCValue));
    GetNativeString(3, sCDescription, sizeof(sCDescription));
    
    if (g_cDebug.BoolValue)	
    {
        PrintToServer("(Native_AddString) Plugin: %s", sPlName);
    }
    
    bool bFound = false;
    
    if(g_aVars != null)
    {
        for (int i = 0; i < g_aVars.Length; i++)
        {
            mVar mvar;
            g_aVars.GetArray(i, mvar);
            
            if (g_cDebug.BoolValue)
            {
                PrintToServer("(Native_AddString) PluginName: %s - Name: %s - Value: %s - Description: %s - Type: %s", mvar.PluginName, mvar.Name, mvar.Value, mvar.Description, mvar.Type);
            }
    
            if (StrEqual(mvar.PluginName, sPlName, false) && StrEqual(mvar.Name, sCName, false))
            {
                if (g_cDebug.BoolValue)
                {
                    PrintToServer("(Native_AddString) Result for \"%s\" found! Value: %s", sCName, mvar.Value);
                }
                
                bFound = true;
                
                return SetNativeString(4, mvar.Value, GetNativeCell(5), false);
            }
        }
    }
    
    if (g_cDebug.BoolValue)
    {
        PrintToServer("(Native_AddString) No result for \"%s\" found!", sCName);
    }
    
    if(!bFound)
    {
        if (g_dDatabase != null)
        {
            char sEscapedCValue[512];
            g_dDatabase.Escape(sCValue, sEscapedCValue, sizeof(sEscapedCValue));
            
            char sQuery[2048];
            Format(sQuery, sizeof(sQuery), "INSERT INTO `mvars` (`plugin_name`, `cvar_name`, `cvar_value`, `cvar_description`, `cvar_type`) VALUES ('%s', '%s', '%s', '%s', '%s')", sPlName, sCName, sEscapedCValue, sCDescription, "string");
            
            if (g_cDebug.BoolValue)
            {
                PrintToServer("(Native_AddString) Query: %s", sQuery);
            }
            
            g_dDatabase.Query(OnCvarAdd, sQuery, _, DBPrio_High);
            
            mVar mvar;
            
            Format(mvar.PluginName, sizeof(mvar.PluginName), "%s", sPlName);
            Format(mvar.Name, sizeof(mvar.Name), "%s", sCName);
            Format(mvar.Value, sizeof(mvar.Value), "%s", sCValue);
            Format(mvar.Description, sizeof(mvar.Description), "%s", sCDescription);
            Format(mvar.Type, sizeof(mvar.Type), "string");
            
            if (g_cDebug.BoolValue)
            {
                PrintToServer("[Native_AddString] PluginName: %s - Name: %s - Value: %s - Description: %s - Type: %s", mvar.PluginName, mvar.Name, mvar.Value, mvar.Description, mvar.Type);
            }
            
            g_aVars.PushArray(mvar);
            UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "string");
        }
        else
        {
            UpdateBackupFile(sPlName, sCName, sCValue, sCDescription, "string");
            LogError("(Native_AddString) Error! Database is invalid...");
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
    if (g_cDebug.BoolValue)
    {
        PrintToServer("OnAddCvar called!");
    }
    
    if(db == null || strlen(error) > 0)
    {
        LogError("(OnAddCvar) Query failed!: %s", error);
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
    
    KeyValues kvBackup = new KeyValues("mVars");
    
    if(!kvBackup.ImportFromFile(g_sKVPath))
    {
        SetFailState("Can't read mvars.cfg correctly!");
        return;
    }
    
    kvBackup.JumpToKey(plugin, true);
    kvBackup.JumpToKey(name, true);
    
    if(StrEqual(type, "string", false))
    {
        PrintToServer("(UpdateBackupFile) [String] Name: %s Value: %s Description: %s", name, value, description);
        kvBackup.SetString("value", value);
        kvBackup.SetString("description", description);
    }
    else if(StrEqual(type, "int", false) || StrEqual(type, "bool", false))
    {
        PrintToServer("(UpdateBackupFile) [Int/Bool] Name: %s Value: %s Description: %s", name, value, description);
        kvBackup.SetNum("value", StringToInt(value));
        kvBackup.SetString("description", description);
    }
    else if(StrEqual(type, "float", false))
    {
        PrintToServer("(UpdateBackupFile) [Float] Name: %s Value: %s Description: %s", name, value, description);
        kvBackup.SetFloat("value", StringToFloat(value));
        kvBackup.SetString("description", description);
    }
    
    kvBackup.Rewind();
    kvBackup.ExportToFile(g_sKVPath);
    
    delete kvBackup;
}

stock void GetBackupValue(const char[] plugin, const char[] name, const char[] type)
{
    KeyValues kvBackup = new KeyValues("mVars");
    
    if(!kvBackup.ImportFromFile(g_sKVPath))
    {
        SetFailState("Can't read mvars.cfg correctly!");
        return;
    }
    
    if(!kvBackup.JumpToKey(plugin, false))
    {
        SetFailState("Can't find cvars for %s!", plugin);
        return;
    }
    
    if(!kvBackup.JumpToKey(name, false))
    {
        SetFailState("Can't find cvar %s for %s!", name, plugin);
        return;
    }
    
    if (StrEqual(type, "int", false))
    {
        return kvBackup.GetNum("value");
    }
    else if (StrEqual(type, "bool", false))
    {
        return view_as<bool>(kvBackup.GetNum("value"));
    }
    else if (StrEqual(type, "float", false))
    {
        return view_as<float>(kvBackup.GetFloat("value"));
    }
}

stock void GetBackupStringValue(const char[] plugin, const char[] name, char[] output, int size)
{
    KeyValues kvBackup = new KeyValues("mVars");
    
    if(!kvBackup.ImportFromFile(g_sKVPath))
    {
        SetFailState("Can't read mvars.cfg correctly!");
        return;
    }
    
    if(!kvBackup.JumpToKey(plugin, false))
    {
        SetFailState("Can't find cvars for %s!", plugin);
        return;
    }
    
    if(!kvBackup.JumpToKey(name, false))
    {
        SetFailState("Can't find cvar %s for %s!", name, plugin);
        return;
    }
    
    kvBackup.GetString("value", output, size);
    return;
}

stock void CallForward(Handle hForward)
{
    Call_StartForward(hForward);
    Call_Finish();
}
