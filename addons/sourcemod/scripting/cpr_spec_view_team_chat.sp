#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <sdktools>
#include <chat_processor_rework>


public Plugin myinfo = {
    name        = "[CPR] SpecViewTeamChat",
    author      = "TouchMe",
    description = "Allows an observer to see players team chat",
    version     = "build0000",
    url         = "https://github.com/TouchMe-Inc/l4d2_chat_processor_rework"
};


#define TEAM_SPECTATOR          1


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

public Action OnChatMessage(int iAuthor, Handle hRecipients, char[] szTag, char[] szName, char[] szMessage, int iFlags)
{
    if (szMessage[0] == '!') {
        return Plugin_Continue;
    }
    
    if (iFlags & CHATFLAGS_SPECTATOR || ~iFlags & CHATFLAGS_TEAM) {
        return Plugin_Continue;
    }

    bool bChanged = false;

    for (int iClient = 1; iClient <= MaxClients; iClient ++)
    {
        if (!IsClientInGame(iClient)
        || !IsClientSpectator(iClient)
        || FindValueInArray(hRecipients, iClient) != -1) {
            continue;
        }

        PushArrayCell(hRecipients, iClient);

        bChanged = true;
    }

    return bChanged ? Plugin_Changed : Plugin_Continue;
}

/**
 * Spectator team player?
 */
bool IsClientSpectator(int iClient) {
    return (GetClientTeam(iClient) == TEAM_SPECTATOR);
}
