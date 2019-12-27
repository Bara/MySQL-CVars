#if defined _mvars_included
 #endinput
#endif
#define _mvars_included

forward void MVars_OnVarsLoaded();

native bool MVars_IsReady();
native int MVars_AddInt(const char[] name, int value, const char[] description);
native bool MVars_AddBool(const char[] name, bool value, const char[] description);
native float MVars_AddFloat(const char[] name, float value, const char[] description);
native void MVars_AddString(const char[] name, const char[] value, const char[] description, char[] output, int size);

public SharedPlugin __pl_mvars =
{
    name = "mvars",
    file = "mvars.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public __pl_mvars_SetNTVOptional()
{
    MarkNativeAsOptional("MVars_IsReady")
    MarkNativeAsOptional("MVars_AddInt");
    MarkNativeAsOptional("MVars_AddBool");
    MarkNativeAsOptional("MVars_AddFloat");
    MarkNativeAsOptional("MVars_AddString");
}
#endif
