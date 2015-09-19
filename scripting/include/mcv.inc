#if defined _mcv_included
 #endinput
#endif
#define _mcv_included

#define MCV_MAX_CHAR_LENGTH 512
#define MCV_PLUGIN_NAME 64
#define MCV_NAME 64
#define MCV_VALUE 512
#define MCV_DESCRIPTION 512
#define MCV_TYPE 8

#define MCV_DEBUG

forward void MCV_OnCVarsLoaded();

native int MCV_AddInt(const char[] name, int value, const char[] description);
native bool MCV_AddBool(const char[] name, bool value, const char[] description);
native float MCV_AddFloat(const char[] name, float value, const char[] description);
native void MCV_AddString(const char[] name, const char[] value, const char[] description, char[] output, int size);
