#pragma semicolon               1
#pragma newdecls                required

#include <sourcemod>
#include <chat_processor_rework>
#include <colors>


public Plugin myinfo = {
    name        = "[CPR] HideTrigger",
    author      = "TouchMe",
    description = "Hide message with '!'",
    version     = "build0000",
    url         = "https://github.com/TouchMe-Inc/l4d2_chat_processor_rework"
};


public Action OnChatMessage(int iAuthor, Handle hRecipients, char[] szTag, char[] szName, char[] szMessage, int iFlags)
{
    static char szClearMessage[MAXLENGTH_MESSAGE];
    strcopy(szClearMessage, sizeof szClearMessage, szMessage);
    CRemoveTags(szClearMessage, sizeof szClearMessage);

    if (szClearMessage[0] != '!') {
        return Plugin_Continue;
    }

    ClearArray(hRecipients);
    PushArrayCell(hRecipients, iAuthor);

    return Plugin_Changed;
}
