#pragma semicolon 1

#include <sourcemod>
#include <mvars>

public void MVars_OnVarsLoaded()
{
    LogMessage("MVars_OnVarsLoaded called!");
    
    int g_iTest1 = MVars_AddInt("int_test1", 46, "Description Test 1");
    int g_iTest2 = MVars_AddInt("int_test2", 256, "Description Test 2");
    int g_iTest3 = MVars_AddInt("int_test3", 21364, "Description Test 3");
    int g_iTest4 = MVars_AddInt("int_test4", 247524727, "Description Test 4");
    
    bool g_bTest1 = MVars_AddBool("bool_test1", true, "Description Test 1");
    bool g_bTest2 = MVars_AddBool("bool_test2", true, "Description Test 2");
    bool g_bTest3 = MVars_AddBool("bool_test3", false, "Description Test 3");
    bool g_bTest4 = MVars_AddBool("bool_test4", true, "Description Test 4");
    
    float g_fTest1 = MVars_AddFloat("float_test1", 1.0, "Description Test 1");
    float g_fTest2 = MVars_AddFloat("float_test2", 123124.14, "Description Test 2");
    float g_fTest3 = MVars_AddFloat("float_test3", 0.12, "Description Test 3");
    float g_fTest4 = MVars_AddFloat("float_test4", 12414.124314, "Description Test 4");
    
    char g_sTest1[64];
    char g_sTest2[64];
    char g_sTest3[64];
    char g_sTest4[64];
    
    MVars_AddString("string_test1", "test 1", "Description Test 1", g_sTest1, sizeof(g_sTest1));
    MVars_AddString("string_test2", "test 2", "Description Test 2", g_sTest2, sizeof(g_sTest2));
    MVars_AddString("string_test3", "test 3", "Description Test 3", g_sTest3, sizeof(g_sTest3));
    MVars_AddString("string_test4", "test 4", "Description Test 4", g_sTest4, sizeof(g_sTest4));
    
    LogMessage("(MVars_OnVarsLoaded) Int Test1: %d", g_iTest1);
    LogMessage("(MVars_OnVarsLoaded) Int Test2: %d", g_iTest2);
    LogMessage("(MVars_OnVarsLoaded) Int Test3: %d", g_iTest3);
    LogMessage("(MVars_OnVarsLoaded) Int Test4: %d", g_iTest4);
    
    LogMessage("(MVars_OnVarsLoaded) Bool Test1: %d", g_bTest1);
    LogMessage("(MVars_OnVarsLoaded) Bool Test2: %d", g_bTest2);
    LogMessage("(MVars_OnVarsLoaded) Bool Test3: %d", g_bTest3);
    LogMessage("(MVars_OnVarsLoaded) Bool Test4: %d", g_bTest4);
    
    LogMessage("(MVars_OnVarsLoaded) Float Test1: %f", g_fTest1);
    LogMessage("(MVars_OnVarsLoaded) Float Test2: %f", g_fTest2);
    LogMessage("(MVars_OnVarsLoaded) Float Test3: %f", g_fTest3);
    LogMessage("(MVars_OnVarsLoaded) Float Test4: %f", g_fTest4);
    
    LogMessage("(MVars_OnVarsLoaded) String Test1: %s", g_sTest1);
    LogMessage("(MVars_OnVarsLoaded) String Test2: %s", g_sTest2);
    LogMessage("(MVars_OnVarsLoaded) String Test3: %s", g_sTest3);
    LogMessage("(MVars_OnVarsLoaded) String Test4: %s", g_sTest4);
}
