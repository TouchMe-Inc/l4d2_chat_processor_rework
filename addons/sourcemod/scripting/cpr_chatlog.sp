/*
 ----------------------------------------------------------------
 Plugin      : SaveChat
 Author      : citkabuto
 Game        : Any Source game
 Description : Will record all player messages to a file
 ================================================================
 Date       Version  Description
 ================================================================
 23/Feb/10  1.2.1    - Fixed bug with player team id
 15/Feb/10  1.2.0    - Now records team name when using cvar
                            sm_record_detail
 01/Feb/10  1.1.1    - Fixed bug to prevent errors when using
                       HLSW (client index 0 is invalid)
 31/Jan/10  1.1.0    - Fixed date format on filename
                       Added ability to record player info
                       when connecting using cvar:
                            sm_record_detail (0=none,1=all:def:1)
 28/Jan/10  1.0.0    - Initial Version
 ----------------------------------------------------------------
*/

#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <sdktools>
#include <geoip.inc>
#include <string.inc>
#include <colors>
#include <chat_processor_rework>

char chatFile[128];
ConVar sc_record_detail = null;

public Plugin myinfo = {
    name        = "SaveChat",
    author      = "citkabuto",
    description = "Records player chat messages to a file",
    version     = "---",
    url         = "http://forums.alliedmods.net/showthread.php?t=117116"
}

public void OnPluginStart()
{
    /* Register CVars */
    sc_record_detail = CreateConVar("sc_record_detail", "1",
        "Record player Steam ID and IP address");

    /* Format date for log filename */
    char date[21];
    FormatTime(date, sizeof(date), "%y%m%d", -1);

    /* Create name of logfile to use */
    char logFile[100];
    Format(logFile, sizeof(logFile), "/logs/%s_chat.log", date);
    BuildPath(Path_SM, chatFile, PLATFORM_MAX_PATH, logFile);
}

public void OnClientPostAdminCheck(int client)
{
    /* Only record player detail if CVAR set */
    if (GetConVarInt(sc_record_detail) != 1)
        return;

    if (IsFakeClient(client)) {
        return;
    }

    char msg[1024];

    char steamID[MAX_AUTHID_LENGTH];
    GetClientAuthId(client, AuthId_Steam2, steamID, sizeof(steamID));

    /* Get 2 digit country code for current player */
    char playerIP[32], country[3];
    if (GetClientIP(client, playerIP, sizeof(playerIP), true) == false) {
        country   = "  ";
    } else {
        if (GeoipCode2(playerIP, country) == false) {
            country = "  ";
        }
    }

    char time[21];
    FormatTime(time, sizeof(time), "%H:%M:%S", -1);

    Format(msg, sizeof(msg), "[%s] [%s] %-35N has joined (%s | %s)",
        time,
        country,
        client,
        steamID,
        playerIP);

    SaveMessage(msg);
}

/*
 * Extract all relevant information and format
 */
public void OnChatMessage_Post(int iAuthor, Handle hRecipients, const char[] szTag, const char[] szName, const char[] szMessage, int iFlags)
{
    char log[1024];

    char szLogMessage[MAXLENGTH_MESSAGE];
    strcopy(szLogMessage, sizeof szLogMessage, szMessage);
    CRemoveTags(szLogMessage, sizeof szLogMessage);

    /* Get 2 digit country code for current player */
    char playerIP[32], country[3];
    if (GetClientIP(iAuthor, playerIP, sizeof(playerIP), true) == false) {
        country   = "  ";
    } else {
        if (GeoipCode2(playerIP, country) == false) {
            country = "  ";
        }
    }

    char teamName[20];
    GetTeamName(GetClientTeam(iAuthor), teamName, sizeof(teamName));

    char time[21];
    FormatTime(time, sizeof(time), "%H:%M:%S", -1);

    if (GetConVarInt(sc_record_detail) == 1) {
        Format(log, sizeof(log), "[%s] [%s] [%-11s] %-35s :%s %s",
            time,
            country,
            teamName,
            szName,
            iFlags & CHATFLAGS_TEAM ? " (TEAM)" : "",
            szLogMessage);
    } else {
        Format(log, sizeof(log), "[%s] [%s] %-35s :%s %s",
            time,
            country,
            szName,
            iFlags & CHATFLAGS_TEAM ? " (TEAM)" : "",
            szLogMessage);
    }

    SaveMessage(log);
}

/*
 * Log a map transition
 */
public void OnMapStart()
{
    char map[64];
    char msg[1024];
    char date[21];
    char time[21];
    char logFile[100];

    GetCurrentMap(map, sizeof(map));

    /* The date may have rolled over, so update the logfile name here */
    FormatTime(date, sizeof(date), "%y%m%d", -1);
    Format(logFile, sizeof(logFile), "/logs/%s_chat.log", date);
    BuildPath(Path_SM, chatFile, PLATFORM_MAX_PATH, logFile);

    FormatTime(time, sizeof(time), "%d/%m/%Y %H:%M:%S", -1);
    Format(msg, sizeof(msg), "[%s] --- NEW MAP STARTED: %s ---", time, map);

    SaveMessage("--=================================================================--");
    SaveMessage(msg);
    SaveMessage("--=================================================================--");
}

/*
 * Log the message to file
 */
public void SaveMessage(const char[] message)
{
    Handle fileHandle = OpenFile(chatFile, "a");  /* Append */
    WriteFileLine(fileHandle, message);
    CloseHandle(fileHandle);
}

