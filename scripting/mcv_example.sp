#pragma semicolon 1


#include <sourcemod>
#include <mcv>


public void MCV_OnCVarsLoaded()
{
	#if defined MCV_CALL_DEBUG
		PrintToServer("MCV_OnCVarsLoaded called!");
	#endif
	
	int g_iTest1 = MCV_AddInt("int_test1", 46, "Description Test 1");
	int g_iTest2 = MCV_AddInt("int_test2", 256, "Description Test 2");
	int g_iTest3 = MCV_AddInt("int_test3", 21364, "Description Test 3");
	int g_iTest4 = MCV_AddInt("int_test4", 247524727, "Description Test 4");
	
	bool g_bTest1 = MCV_AddBool("bool_test1", true, "Description Test 1");
	bool g_bTest2 = MCV_AddBool("bool_test2", true, "Description Test 2");
	bool g_bTest3 = MCV_AddBool("bool_test3", false, "Description Test 3");
	bool g_bTest4 = MCV_AddBool("bool_test4", true, "Description Test 4");
	
	float g_fTest1 = MCV_AddFloat("float_test1", 1.0, "Description Test 1");
	float g_fTest2 = MCV_AddFloat("float_test2", 123124.14, "Description Test 2");
	float g_fTest3 = MCV_AddFloat("float_test3", 0.12, "Description Test 3");
	float g_fTest4 = MCV_AddFloat("float_test4", 12414.124314, "Description Test 4");
	
	char g_sTest1[MCV_MAX_CHAR_LENGTH];
	char g_sTest2[MCV_MAX_CHAR_LENGTH];
	char g_sTest3[MCV_MAX_CHAR_LENGTH];
	char g_sTest4[MCV_MAX_CHAR_LENGTH];
	
	MCV_AddString("string_test1", "test 1", "Description Test 1", g_sTest1, sizeof(g_sTest1));
	MCV_AddString("string_test2", "test 2", "Description Test 2", g_sTest2, sizeof(g_sTest2));
	MCV_AddString("string_test3", "test 3", "Description Test 3", g_sTest3, sizeof(g_sTest3));
	MCV_AddString("string_test4", "test 4", "Description Test 4", g_sTest4, sizeof(g_sTest4));
	
	#if defined MCV_DEBUG
		PrintToServer("(MCV_OnCVarsLoaded) Int Test1: %d", g_iTest1);
		PrintToServer("(MCV_OnCVarsLoaded) Int Test2: %d", g_iTest2);
		PrintToServer("(MCV_OnCVarsLoaded) Int Test3: %d", g_iTest3);
		PrintToServer("(MCV_OnCVarsLoaded) Int Test4: %d", g_iTest4);
		
		PrintToServer("(MCV_OnCVarsLoaded) Bool Test1: %d", g_bTest1);
		PrintToServer("(MCV_OnCVarsLoaded) Bool Test2: %d", g_bTest2);
		PrintToServer("(MCV_OnCVarsLoaded) Bool Test3: %d", g_bTest3);
		PrintToServer("(MCV_OnCVarsLoaded) Bool Test4: %d", g_bTest4);
		
		PrintToServer("(MCV_OnCVarsLoaded) Float Test1: %f", g_fTest1);
		PrintToServer("(MCV_OnCVarsLoaded) Float Test2: %f", g_fTest2);
		PrintToServer("(MCV_OnCVarsLoaded) Float Test3: %f", g_fTest3);
		PrintToServer("(MCV_OnCVarsLoaded) Float Test4: %f", g_fTest4);
		
		PrintToServer("(MCV_OnCVarsLoaded) String Test1: %s", g_sTest1);
		PrintToServer("(MCV_OnCVarsLoaded) String Test2: %s", g_sTest2);
		PrintToServer("(MCV_OnCVarsLoaded) String Test3: %s", g_sTest3);
		PrintToServer("(MCV_OnCVarsLoaded) String Test4: %s", g_sTest4);
	#endif
}
