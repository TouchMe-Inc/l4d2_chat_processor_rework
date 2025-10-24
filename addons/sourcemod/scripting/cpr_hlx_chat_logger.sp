#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <sdktools>
#include <chat_processor_rework>
#include <colors>


public Plugin myinfo = {
    name        = "[CPR] HlxChatLogger",
    author      = "TouchMe",
    description = "See name",
    version     = "build0000",
    url         = "https://github.com/TouchMe-Inc/l4d2_chat_processor_rework"
};


public void OnChatMessage_Post(int iAuthor, Handle hRecipients, const char[] szTag, const char[] szName, const char[] szMessage, int iFlags)
{
    char szLogMessage[MAXLENGTH_MESSAGE];
    strcopy(szLogMessage, sizeof szLogMessage, szMessage);
    CRemoveTags(szLogMessage, sizeof szLogMessage);
    LogPlayerEvent(iAuthor, iFlags & CHATFLAGS_TEAM ? "say_team" : "say", szLogMessage);
}

void LogPlayerEvent(int client, const char[] verb, const char[] event, bool display_location = false, const char[] properties = "")
{
    if (!IsValidPlayer(client)) {
        return;
    }

    char player_authid[32];
    if (!GetClientAuthId(client, AuthId_Engine, player_authid, sizeof(player_authid), false))
    {
        strcopy(player_authid, sizeof(player_authid), "UNKNOWN");
    }

    char szTeamName[32];
    GetTeamName(GetClientTeam(client), szTeamName, sizeof szTeamName);

    if (display_location)
    {
        float player_origin[3];
        GetClientAbsOrigin(client, player_origin);
        LogToGame("\"%N<%d><%s><%s>\" %s \"%s\"%s (position \"%d %d %d\")", client, GetClientUserId(client), player_authid, szTeamName, verb, event, properties, RoundFloat(player_origin[0]), RoundFloat(player_origin[1]), RoundFloat(player_origin[2]));
    }
    else
    {
        LogToGame("\"%N<%d><%s><%s>\" %s \"%s\"%s", client, GetClientUserId(client), player_authid, szTeamName, verb, event, properties);
    }
}

bool IsValidPlayer(int client) {
    return client > 0 && client <= MaxClients && IsClientInGame(client);
}