#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <sdktools>
#include <clientprefs>
#include <colors>
#include <chat_processor_rework>
#include <vip_core>


public Plugin myinfo = {
    name        = "[CPR] VipTags",
    author      = "TouchMe",
    description = "",
    version     = "build0000",
    url         = "https://github.com/TouchMe-Inc/l4d2_chat_processor_rework"
};


#define TRANSLATIONS            "cpr_viptags.phrases"

#define PATH_TO_TAGS_FILE       "addons/sourcemod/configs/cpr_viptags.txt"

#define FEATURE_CHAT            "Chat"

enum {
    PREFIX = 0,
    COLOR_PREFIX,
    COLOR_NAME,
    COLOR_MESSAGE,
    FEATURE_SIZE
};

char FEATURE_NAME[FEATURE_SIZE][] = {
    "Chat_Prefix",
    "Chat_PrefixColor",
    "Chat_NameColor",
    "Chat_TextColor"
};

enum {
    COLOR_PHRASE = 0,
    COLOR_CODE
}

char COLORS[][] = {
    "COLOR_DEFAULT", "{default}",
    "COLOR_GOLD", "{green}",
    "COLOR_TEAM", "{teamcolor}",
    "COLOR_GREEN", "{olive}"
};


Cookie g_cChatSettings[FEATURE_SIZE];

StringMap g_smColors = null;
StringMap g_smTags = null;


public void OnPluginStart()
{
    LoadTranslations(TRANSLATIONS);

    g_cChatSettings[PREFIX] = new Cookie("VIP_Chat_Prefix", "Cookie with prefix", CookieAccess_Private);
    g_cChatSettings[COLOR_PREFIX] = new Cookie("VIP_Chat_PrefixColor", "Cookie with prefix color", CookieAccess_Private);
    g_cChatSettings[COLOR_NAME] = new Cookie("VIP_Chat_NameColor", "Cookie with name color", CookieAccess_Private);
    g_cChatSettings[COLOR_MESSAGE] = new Cookie("VIP_Chat_TextColor", "Cookie with message color", CookieAccess_Private);

    ImportTagsFromFile(g_smTags = new StringMap(), PATH_TO_TAGS_FILE);

    g_smColors = new StringMap();

    for (int iColor = 0; iColor < sizeof(COLORS); iColor += 2)
    {
        g_smColors.SetString(COLORS[iColor + 1], COLORS[iColor]);
    }

    if (VIP_IsVIPLoaded()) VIP_OnVIPLoaded();
}

void ImportTagsFromFile(StringMap aTags, const char[] szPath)
{
    KeyValues kv = new KeyValues("Config");

    if (!kv.ImportFromFile(szPath)) {
        SetFailState("Failed to parse keyvalues for %s", szPath);
    }

    if (kv.GotoFirstSubKey(false))
    {
        char szTagName[32], szTagValue[64];

        do
        {
            kv.GetSectionName(szTagName, sizeof(szTagName));
            kv.GetString(NULL_STRING, szTagValue, sizeof(szTagValue));

            aTags.SetString(szTagName, szTagValue);
        } while (KvGotoNextKey(kv, false));
    }

    delete kv;
}

public void OnPluginEnd()
{
    VIP_UnregisterFeature(FEATURE_CHAT);
    VIP_UnregisterFeature(FEATURE_NAME[PREFIX]);
    VIP_UnregisterFeature(FEATURE_NAME[COLOR_PREFIX]);
    VIP_UnregisterFeature(FEATURE_NAME[COLOR_NAME]);
    VIP_UnregisterFeature(FEATURE_NAME[COLOR_MESSAGE]);
}

public void VIP_OnVIPLoaded()
{
    VIP_RegisterFeature(FEATURE_CHAT, BOOL, SELECTABLE, OnSelectItem, _, OnDrawItem);
    VIP_RegisterFeature(FEATURE_NAME[PREFIX], STRING, HIDE);
    VIP_RegisterFeature(FEATURE_NAME[COLOR_PREFIX], STRING, HIDE);
    VIP_RegisterFeature(FEATURE_NAME[COLOR_NAME], STRING, HIDE);
    VIP_RegisterFeature(FEATURE_NAME[COLOR_MESSAGE], STRING, HIDE);
}

public bool OnSelectItem(int iClient, const char[] szFeatureName)
{
    ShowChatSettingsMenu(iClient);
    return false;
}

public int OnDrawItem(int iClient, const char[] szFeatureName, int iStyle)
{
    switch (VIP_GetClientFeatureStatus(iClient, FEATURE_CHAT))
    {
        case ENABLED: return ITEMDRAW_DEFAULT;
        case DISABLED, NO_ACCESS: return ITEMDRAW_DISABLED;
    }

    return iStyle;
}

void ShowChatSettingsMenu(int iClient)
{
    Menu menu = new Menu(Handler_ChatSettingsMenu);
    menu.ExitBackButton = true;
    menu.SetTitle("%T", "MENU_CHAT_SETTINGS_TITLE", iClient);

    char szBuffer[32];
    FormatEx(szBuffer, sizeof(szBuffer), "%T", "MENU_CHAT_SETTINGS_DISABLE_ALL", iClient);
    menu.AddItem("", szBuffer);

    AddMenuFeatureItem(menu, "MENU_CHAT_SETTINGS_PREFIX", iClient, PREFIX);
    AddMenuFeatureItem(menu, "MENU_CHAT_SETTINGS_COLOR_PREFIX", iClient, COLOR_PREFIX);
    AddMenuFeatureItem(menu, "MENU_CHAT_SETTINGS_COLOR_NAME", iClient, COLOR_NAME);
    AddMenuFeatureItem(menu, "MENU_CHAT_SETTINGS_COLOR_MESSAGE", iClient, COLOR_MESSAGE);

    menu.Display(iClient, MENU_TIME_FOREVER);
}

void AddMenuFeatureItem(Menu &menu, const char[] szFeatureName, int iClient, int iIdx)
{
    char szBuffer[128];
    switch (VIP_GetClientFeatureStatus(iClient, FEATURE_NAME[iIdx]))
    {
        case ENABLED:
        {
            char szIdx[4];
            FormatEx(szIdx, sizeof(szIdx), "%d", iIdx);
            FormatEx(szBuffer, sizeof(szBuffer), "%T", szFeatureName, iClient);

            menu.AddItem(szIdx, szBuffer);
        }

        case NO_ACCESS:
        {
            FormatEx(szBuffer, sizeof(szBuffer), "%T", szFeatureName, iClient);
            menu.AddItem("", szBuffer, ITEMDRAW_DISABLED);
        }
    }
}

int Handler_ChatSettingsMenu(Menu menu, MenuAction maAction, int iClient, int iItem)
{
    switch (maAction)
    {
        case MenuAction_End: delete menu;

        case MenuAction_Cancel: {
            if (iItem == MenuCancel_ExitBack) VIP_SendClientVIPMenu(iClient);
        }

        case MenuAction_Select:
        {
            if (iItem == 0)
            {
                for (int iIdx = 0; iIdx < FEATURE_SIZE; iIdx ++)
                {
                    if (!VIP_IsClientFeatureUse(iClient, FEATURE_NAME[iIdx])) {
                        continue;
                    }

                    g_cChatSettings[iIdx].Set(iClient, "");
                }

                ShowChatSettingsMenu(iClient);
                return 0;
            }

            char szIdx[4];
            menu.GetItem(iItem, szIdx, sizeof(szIdx));

            int iIdx = StringToInt(szIdx);

            switch (iIdx)
            {
                case PREFIX: ShowSetupPrefixMenu(iClient);
                case COLOR_PREFIX, COLOR_NAME, COLOR_MESSAGE: ShowSetupColorMenu(iClient, iIdx);
            }
        }
    }

    return 0;
}

void ShowSetupPrefixMenu(int iClient)
{
    char szCookieValue[64];
    g_cChatSettings[PREFIX].Get(iClient, szCookieValue, sizeof(szCookieValue));
    bool bHasPrefix = szCookieValue[0] != '\0';

    Menu menu = new Menu(Handler_SetupPrefixMenu);

    char szBuffer[64];
    FormatEx(szBuffer, sizeof(szBuffer), "%T", "MENU_PREFIX_DISABLE", iClient);
    menu.AddItem("", szBuffer, !bHasPrefix ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);

    if (!bHasPrefix) {
        FormatEx(szCookieValue, sizeof(szCookieValue), "%T", "NONE", iClient);
    } else {
        CRemoveTags(szCookieValue, sizeof(szCookieValue));
    }
    
    menu.SetTitle("%T", "MENU_PREFIX_TITLE", iClient, szCookieValue);

    StringMapSnapshot smsTags = g_smTags.Snapshot();

    int iSize = smsTags.Length;
    char szTagKey[32], szTagValue[64];
    for (int iTag = 0; iTag < iSize; iTag ++)
    {
        smsTags.GetKey(iTag, szTagKey, sizeof(szTagKey));
        g_smTags.GetString(szTagKey, szTagValue, sizeof(szTagValue));

        menu.AddItem(szTagValue, szTagKey);
    }

    menu.ExitBackButton = true;
    menu.Display(iClient, MENU_TIME_FOREVER);
}

int Handler_SetupPrefixMenu(Menu menu, MenuAction maAction, int iClient, int iItem)
{
    switch (maAction)
    {
        case MenuAction_End: delete menu;

        case MenuAction_Cancel: {
            if (iItem == MenuCancel_ExitBack) ShowChatSettingsMenu(iClient);
        }

        case MenuAction_Select:
        {
            char szItemData[64];
            GetMenuItem(menu, iItem, szItemData, sizeof(szItemData));

            if (szItemData[0] == '\0')
            {
                g_cChatSettings[PREFIX].Set(iClient, "");

                ShowSetupPrefixMenu(iClient);
                return 0;
            }

            g_cChatSettings[PREFIX].Set(iClient, szItemData);
            ShowSetupPrefixMenu(iClient);
        }
    }

    return 0;
}

void ShowSetupColorMenu(int iClient, int iIdx)
{
    char szCookieValue[32];
    g_cChatSettings[iIdx].Get(iClient, szCookieValue, sizeof(szCookieValue));

    char szCurrentColor[32];
    if (szCookieValue[0] == '\0') {
        FormatEx(szCurrentColor, sizeof(szCurrentColor), "%T", "NONE", iClient);
    }
    else
    {
        char szValue[32];
        g_smColors.GetString(szCookieValue, szValue, sizeof(szValue));
        FormatEx(szCurrentColor, sizeof(szCurrentColor), "%T", szValue, iClient);
    }

    Menu menu = new Menu(Handler_SetupColorMenu);
    menu.ExitBackButton = true;

    switch (iIdx)
    {
        case COLOR_PREFIX: menu.SetTitle("%T", "MENU_COLOR_PREFIX_TITLE", iClient, szCurrentColor);
        case COLOR_NAME: menu.SetTitle("%T", "MENU_COLOR_NAME_TITLE", iClient, szCurrentColor);
        case COLOR_MESSAGE: menu.SetTitle("%T", "MENU_COLOR_MESSAGE_TITLE", iClient, szCurrentColor);
    }

    char szData[4 + 32];
    FormatEx(szData, sizeof(szData), "%d", iIdx);

    char szBuffer[64];


    FormatEx(szBuffer, sizeof(szBuffer), "%T", "MENU_COLOR_RESET", iClient);

    menu.AddItem("", szBuffer);

    for (int iColor = 0; iColor < sizeof(COLORS); iColor+=2)
    {
        FormatEx(szData, sizeof(szData), "%d %s", iIdx, COLORS[iColor + 1]);
        FormatEx(szBuffer, sizeof(szBuffer), "%T", COLORS[iColor], iClient);

        menu.AddItem(szData, szBuffer, StrEqual(COLORS[iColor + 1], szCookieValue) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
    }

    menu.Display(iClient, MENU_TIME_FOREVER);
}

int Handler_SetupColorMenu(Menu menu, MenuAction maAction, int iClient, int iItem)
{
    switch (maAction)
    {
        case MenuAction_End: delete menu;

        case MenuAction_Cancel: {
            if (iItem == MenuCancel_ExitBack) ShowChatSettingsMenu(iClient);
        }

        case MenuAction_Select:
        {
            char szItemData[4 + 32];
            GetMenuItem(menu, iItem, szItemData, sizeof(szItemData));

            if (iItem == 0)
            {
                int iIdx = StringToInt(szItemData);
                g_cChatSettings[iIdx].Set(iClient, "");

                ShowSetupColorMenu(iClient, iIdx);
                return 0;
            }

            char szIdx[4], szColor[32];
            BreakString(szItemData[BreakString(szItemData, szIdx, sizeof(szIdx))], szColor, sizeof(szColor));

            int iIdx = StringToInt(szIdx);

            g_cChatSettings[iIdx].Set(iClient, szColor);

            ShowSetupColorMenu(iClient, iIdx);
        }
    }

    return 0;
}

public Action OnChatMessage(int iAuthor, Handle hRecipients, char[] szTag, char[] szName, char[] szMessage, int iFlags)
{
    if (!VIP_IsClientVIP(iAuthor) || !VIP_IsClientFeatureUse(iAuthor, FEATURE_CHAT)) {
        return Plugin_Continue;
    }

    char szChatFeature[32];

    if (PrepareChatFeature(iAuthor, COLOR_NAME, szChatFeature, sizeof(szChatFeature))) {
        Format(szName, MAXLENGTH_NAME, "%s%s", szChatFeature, szName);
    } else {
        Format(szName, MAXLENGTH_NAME, "{teamcolor}%s", szName);
    }

    if (PrepareChatFeature(iAuthor, COLOR_MESSAGE, szChatFeature, sizeof(szChatFeature))) {
        Format(szMessage, MAXLENGTH_MESSAGE, "%s%s", szChatFeature, szMessage);
    }

    if (PrepareChatFeature(iAuthor, PREFIX, szChatFeature, sizeof(szChatFeature)))
    {
        char szPrefixColor[16];

        if (PrepareChatFeature(iAuthor, COLOR_PREFIX, szPrefixColor, sizeof(szPrefixColor))) {
            Format(szTag, MAXLENGTH_TAG, "%s%s%s", szTag, szPrefixColor, szChatFeature);
        } else {
            Format(szTag, MAXLENGTH_TAG, "%s%s", szTag, szChatFeature);
        }
    }

    return Plugin_Changed;
}

bool PrepareChatFeature(int iClient, int iIdx, char[] szBuffer, int iLength)
{
    if (!VIP_IsClientFeatureUse(iClient, FEATURE_NAME[iIdx])) {
        return false;
    }

    g_cChatSettings[iIdx].Get(iClient, szBuffer, iLength);

    return (szBuffer[0] != '\0');
}
