#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <chat_processor_rework>


public Plugin myinfo = {
    name        = "[CPR] Tags",
    author      = "TouchMe",
    description = "Adds tags to player names based on their SteamID using a config file",
    version     = "build0000",
    url         = "https://github.com/TouchMe-Inc/l4d2_chat_processor_rework"
};


#define PATH_TO_TAGS_FILE "addons/sourcemod/configs/cpr_tags.txt"

StringMap g_smTags = null;


public void OnPluginStart()
{
    g_smTags = new StringMap();

    if (!ImportTagsFromFile(g_smTags, PATH_TO_TAGS_FILE)) {
        SetFailState("Failed to parse keyvalues for %s", PATH_TO_TAGS_FILE);
    }

    RegAdminCmd("sm_reloadtags", Cmd_ReloadTags, ADMFLAG_CONFIG,
        "Reload chat tags from the config file");
}

/**
 * Reloads tags from the config file.
 *
 * Parses the file into a temporary StringMap first, and only swaps it in
 * if parsing succeeded. This way a broken config cannot wipe the
 * already-loaded tags.
 */
Action Cmd_ReloadTags(int iClient, int iArgs)
{
    g_smTags.Clear();

    if (!ImportTagsFromFile(g_smTags, PATH_TO_TAGS_FILE)) {
        return Plugin_Handled;
    }

    return Plugin_Handled;
}

public Action OnChatMessage(int iAuthor, Handle hRecipients, char[] szTag, char[] szName, char[] szMessage, int iFlags)
{
    static char szSteamID[MAX_AUTHID_LENGTH]; 
    GetClientAuthId(iAuthor, AuthId_Steam2, szSteamID, sizeof(szSteamID), false);

    static char szPrefix[64];
    if (!g_smTags.GetString(szSteamID, szPrefix, sizeof(szPrefix))) {
        return Plugin_Continue;
    }

    Format(szTag, MAXLENGTH_TAG, "%s%s", szPrefix, szTag);

    return Plugin_Changed;
}

bool ImportTagsFromFile(StringMap smTags, const char[] szPath)
{
    KeyValues kv = new KeyValues("Config");

    if (!kv.ImportFromFile(szPath))
    {
        delete kv;
        return false;
    }

    if (kv.JumpToKey("SteamID"))
    {
        if (kv.GotoFirstSubKey())
        {
            char szSteamID[MAX_AUTHID_LENGTH];
            char szPrefix[64];

            do
            {
                kv.GetSectionName(szSteamID, sizeof(szSteamID));
                kv.GetString("Prefix", szPrefix, sizeof(szPrefix));

                smTags.SetString(szSteamID, szPrefix);
            }
            while (kv.GotoNextKey());
        }

        kv.GoBack();
    }

    delete kv;
    return true;
}