#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <sdktools>
#include <chat_processor_rework>
#include <colors>


public Plugin myinfo = {
    name        = "[CPR] LocalMute",
    author      = "TouchMe",
    description = "Allows a player to locally mute another player's text and voice chat",
    version     = "build0000",
    url         = "https://github.com/TouchMe-Inc/l4d2_chat_processor_rework"
};


#define TRANSLATIONS            "cpr_localmute.phrases"

#define IGNORE_NONE             0
#define IGNORE_CHAT             (1 << 1)
#define IGNORE_VOICE            (1 << 2)


int g_hClientLocalMute[MAXPLAYERS + 1][MAXPLAYERS + 1];


/**
 * Called before OnPluginStart.
 *
 * @param myself      Handle to the plugin
 * @param bLate       Whether or not the plugin was loaded "late" (after map load)
 * @param sErr        Error message buffer in case load failed
 * @param iErrLen     Maximum number of characters for error message buffer
 * @return            APLRes_Success | APLRes_SilentFailure
 */
public APLRes AskPluginLoad2(Handle myself, bool bLate, char[] sErr, int iErrLen)
{
    if (GetEngineVersion() != Engine_Left4Dead2)
    {
        strcopy(sErr, iErrLen, "Plugin only supports Left 4 Dead 2");
        return APLRes_SilentFailure;
    }

    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations(TRANSLATIONS);

    RegConsoleCmd("sm_localmute", Cmd_LocalMute);
}

public void OnClientDisconnect(int iClient)
{
    for (int iAuthor = 1; iAuthor <= MaxClients; iAuthor++)
    {
        g_hClientLocalMute[iClient][iAuthor] = IGNORE_NONE;
    }
}

public Action OnChatMessage(int iAuthor, Handle hRecipients, char[] szTag, char[] szName, char[] szMessage, int iFlags)
{
    int iResepient = 0;
    int iClient = 0;
    bool bChanged = false;

    while (iResepient < GetArraySize(hRecipients))
    {
        iClient = GetArrayCell(hRecipients, iResepient);

        if (!IsValidClient(iClient))
        {
            iResepient ++;
            continue;
        }

        if (g_hClientLocalMute[iClient][iAuthor] & IGNORE_CHAT)
        {
            RemoveFromArray(hRecipients, iResepient);
            bChanged = true;
        }

        else {
            iResepient ++;
        }
    }

    return bChanged ? Plugin_Changed : Plugin_Continue;
}

Action Cmd_LocalMute(int iClient, int iArgs)
{
    if (!iClient) {
        return Plugin_Handled;
    }

    if (!iArgs)
    {
        ShowPlayerMenu(iClient);
        return Plugin_Handled;
    }

    char szArg[32];
    GetCmdArg(1, szArg, sizeof(szArg));

    int iTarget = FindOneTarget(iClient, szArg);

    if (iTarget == -1)
    {
        CReplyToCommand(iClient, "%T%T", "TAG", iClient, "BAD_ARG", iClient, szArg);
        return Plugin_Handled;
    }

    if (iTarget == iClient) {
        return Plugin_Handled;
    }

    ShowIgnoreMenu(iClient, iTarget);

    return Plugin_Handled;
}

void ShowPlayerMenu(int iClient)
{
    Menu hMenu = CreateMenu(HandlerPlayerMenu, MenuAction_Select|MenuAction_End);

    SetMenuTitle(hMenu, "%T", "MENU_PLAYER_TITLE", iClient);

    char szTarget[4], szName[MAX_NAME_LENGTH];

    for (int iPlayer = 1; iPlayer <= MaxClients; iPlayer ++)
    {
        if (!IsClientInGame(iPlayer) || IsFakeClient(iPlayer) || iPlayer == iClient) {
            continue;
        }

        IntToString(iPlayer, szTarget, sizeof(szTarget));
        GetClientNameFixed(iPlayer, szName, sizeof(szName), 25);

        AddMenuItem(hMenu, szTarget, szName);
    }

    DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
}

/**
 *
 */
int HandlerPlayerMenu(Menu hMenu, MenuAction hAction, int iClient, int iItem)
{
    switch(hAction)
    {
        case MenuAction_End: CloseHandle(hMenu);

        case MenuAction_Select:
        {
            char szTarget[4]; GetMenuItem(hMenu, iItem, szTarget, sizeof(szTarget));

            int iTarget = StringToInt(szTarget);

            if (!IsValidClient(iTarget) || !IsClientInGame(iTarget)) {
                ShowPlayerMenu(iClient);
            } else {
                ShowIgnoreMenu(iClient, iTarget);
            }
        }
    }

    return 0;
}

void ShowIgnoreMenu(int iClient, int iTarget)
{
    char szTarget[4]; IntToString(iTarget, szTarget, sizeof(szTarget));

    Menu hMenu = CreateMenu(HandlerIgnoreMenu, MenuAction_Select|MenuAction_End);

    char szName[MAX_NAME_LENGTH]; GetClientNameFixed(iTarget, szName, sizeof(szName), 25);

    SetMenuTitle(hMenu, "%T", "MENU_IGONORE_TITLE", iClient, szName);

    AddMenuItemFormat(hMenu, szTarget, "%T", g_hClientLocalMute[iClient][iTarget] & IGNORE_CHAT ? "MENU_CHAT_PROHIBITED" : "MENU_CHAT_ALLOWED", iClient);
    AddMenuItemFormat(hMenu, szTarget,  "%T", g_hClientLocalMute[iClient][iTarget] & IGNORE_VOICE ? "MENU_VOICE_PROHIBITED" : "MENU_VOICE_ALLOWED", iClient);

    DisplayMenu(hMenu, iClient, MENU_TIME_FOREVER);
}

/**
 *
 */
int HandlerIgnoreMenu(Menu hMenu, MenuAction hAction, int iClient, int iItem)
{
    switch(hAction)
    {
        case MenuAction_End: CloseHandle(hMenu);

        case MenuAction_Select:
        {
            char szTarget[4]; GetMenuItem(hMenu, iItem, szTarget, sizeof(szTarget));

            int iTarget = StringToInt(szTarget);

            if (!IsValidClient(iTarget) || !IsClientInGame(iTarget))
            {
                ShowPlayerMenu(iClient);
                return 0;
            }

            switch (iItem)
            {
                case 0:
                {
                    if (g_hClientLocalMute[iClient][iTarget] & IGNORE_CHAT) {
                        g_hClientLocalMute[iClient][iTarget] &= ~IGNORE_CHAT;
                    } else {
                        g_hClientLocalMute[iClient][iTarget] |= IGNORE_CHAT;
                    }

                    ShowIgnoreMenu(iClient, iTarget);
                }

                case 1:
                {
                    if (g_hClientLocalMute[iClient][iTarget] & IGNORE_VOICE)
                    {
                        g_hClientLocalMute[iClient][iTarget] &= ~IGNORE_VOICE;
                        SetListenOverride(iClient, iTarget, Listen_Default);
                    }

                    else
                    {
                        g_hClientLocalMute[iClient][iTarget] |= IGNORE_VOICE;
                        SetListenOverride(iClient, iTarget, Listen_No);
                    }

                    ShowIgnoreMenu(iClient, iTarget);
                }

                default: ShowPlayerMenu(iClient);
            }
        }
    }

    return 0;
}

/*
 * Returns the player that was found by the request.
 */
int FindOneTarget(int iClient, const char[] szTarget)
{
    char iTargetName[MAX_TARGET_LENGTH];
    int iTargetList[1];
    bool isMl = false;

    bool bFound = ProcessTargetString(
        szTarget,
        iClient,
        iTargetList,
        1,
        COMMAND_FILTER_CONNECTED|COMMAND_FILTER_NO_IMMUNITY|COMMAND_FILTER_NO_MULTI|COMMAND_FILTER_NO_BOTS,
        iTargetName,
        sizeof(iTargetName),
        isMl
    ) > 0;

    return bFound ? iTargetList[0] : -1;
}

void GetClientNameFixed(int iClient, char[] szName, int iLength, int iMaxSize)
{
    GetClientName(iClient, szName, iLength);

    if (strlen(szName) > iMaxSize)
    {
        szName[iMaxSize - 3] = szName[iMaxSize - 2] = szName[iMaxSize - 1] = '.';
        szName[iMaxSize] = '\0';
    }
}

bool AddMenuItemFormat(Handle hMenu, const char[] sKey, const char[] sText, any ...)
{
    char sFormatText[128];
    VFormat(sFormatText, sizeof(sFormatText), sText, 4);
    return AddMenuItem(hMenu, sKey, sFormatText);
}

/**
 * Validates if is a valid client.
 *
 * @param iClient   Client index.
 * @return          True if client is valid, false otherwise.
 */
bool IsValidClient(int iClient) {
    return (1 <= iClient <= MaxClients);
}
