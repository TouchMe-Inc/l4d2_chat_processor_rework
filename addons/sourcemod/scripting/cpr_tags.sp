#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <sdktools>
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

    ImportTagsFromFile(g_smTags, PATH_TO_TAGS_FILE);
}

public Action OnChatMessage(int iAuthor, Handle hRecipients, char[] szName, char[] szMessage, int iFlags)
{
    char szSteamID[32]; 
    GetClientAuthId(iAuthor, AuthId_Steam2, szSteamID, sizeof(szSteamID));

    char szTemplate[64];
    if (!g_smTags.GetString(szSteamID, szTemplate, sizeof(szTemplate))) {
        return Plugin_Continue;
    }

    Format(szName, MAXLENGTH_NAME, "%s%s", szTemplate, szName);

    return Plugin_Changed;
}

void ImportTagsFromFile(StringMap smTags, const char[] szPath)
{
    KeyValues kv = new KeyValues("Config");

    if (!kv.ImportFromFile(szPath)) {
        SetFailState("Failed to parse keyvalues for %s", szPath);
    }

    if (kv.JumpToKey("SteamID"))
    {
        if (kv.GotoFirstSubKey())
        {
            do
            {
                char steamID[64];
                kv.GetSectionName(steamID, sizeof(steamID));

                char prefix[64];
                kv.GetString("Prefix", prefix, sizeof(prefix));

                smTags.SetString(steamID, prefix);
            }
            while (kv.GotoNextKey());
        }

        kv.GoBack();
    }

    delete kv;
}