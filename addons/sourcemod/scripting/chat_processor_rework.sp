#pragma semicolon              1
#pragma newdecls               required

#include <sourcemod>
#include <colors>


public Plugin myinfo = {
    name        = "ChatProcessorRework",
    author      = "Simple Plugins, Mini, TouchMe",
    description = "Process chat and allows other plugins to manipulate chat",
    version     = "build_0003",
    url         = "https://github.com/TouchMe-Inc/l4d2_chat_processor_rework"
};


/*
 * String size.
 */
#define MAXLENGTH_INPUT        128 // Inclues \0 and is the size of the chat input box.
#define MAXLENGTH_NAME         64  // This is backwords math to get compability.  Sourcemod has it set at 32, but there is room for more.
#define MAXLENGTH_MESSAGE      256 // This is based upon the SDK and the length of the entire message, including tags, name, : etc.

/*
 * Chat flags.
 */
#define CHATFLAGS_INVALID      0
#define CHATFLAGS_TEAM         (1 << 0)
#define CHATFLAGS_SPECTATOR    (1 << 1)
#define CHATFLAGS_SURVIVOR     (1 << 2)
#define CHATFLAGS_INFECTED     (1 << 3)
#define CHATFLAGS_DEAD         (1 << 4)

/*
 * Team definitions.
 */
#define TEAM_SPECTATOR         1
#define TEAM_SURVIVOR          2
#define TEAM_INFECTED          3

/*
 * Other definitions.
 */
#define SENDER_WORLD           0
#define DEFAULT_HIDDEN_TRIGGER '/'
#define TRANSLATIONS           "chat_processor_rework.phrases"


GlobalForward g_fwdOnChatMessage = null;
GlobalForward g_fwdOnChatMessagePost = null;


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

    g_fwdOnChatMessage = CreateGlobalForward("OnChatMessage", ET_Hook, Param_Cell, Param_Cell, Param_String, Param_String, Param_Cell);
    g_fwdOnChatMessagePost = CreateGlobalForward("OnChatMessage_Post", ET_Ignore, Param_Cell, Param_Cell, Param_String, Param_String, Param_Cell);

    RegPluginLibrary("chat_processor_rework");

    return APLRes_Success;
}

public void OnPluginStart()
{
    LoadTranslations(TRANSLATIONS);

    AddCommandListener(Cmd_Say, "say");
    AddCommandListener(Cmd_Say, "say_team");
}

/**
 * Handler for "say" and "say_team" commands.
 *
 * @param iSender     Sender index.
 * @param sCmd        Command.
 * @param iArgs       Number of arguments.
 * @return            Plugin action.
 */
Action Cmd_Say(int iSender, const char[] sCmd, int iArgs)
{
    if (iSender == SENDER_WORLD || !IsClientConnected(iSender)) {
        return Plugin_Continue;
    }

    /**
     * Get the message.
     */
    char sMessage[MAXLENGTH_MESSAGE];
    GetCmdArgString(sMessage, sizeof(sMessage));
    TrimString(sMessage);
    StripQuotes(sMessage);
    CRemoveTags(sMessage, sizeof(sMessage));

    if (sMessage[0] == DEFAULT_HIDDEN_TRIGGER) {
        return Plugin_Handled;
    }

    /*
     * Get the sender name.
     */
    char sSenderName[MAXLENGTH_NAME];
    GetClientName(iSender, sSenderName, sizeof(sSenderName));
    StripQuotes(sSenderName);
    CRemoveTags(sSenderName, sizeof(sSenderName));

    /*
     * Get the sender team. Wow.
     */
    int iTeam = GetClientTeam(iSender);

    /*
     * Get the message flags.
     */
    int iFlags = CHATFLAGS_INVALID;

    if (strcmp(sCmd, "say_team") == 0) {
        iFlags = iFlags | CHATFLAGS_TEAM;
    }

    switch (iTeam)
    {
        case TEAM_SPECTATOR: iFlags = iFlags | CHATFLAGS_SPECTATOR;
        case TEAM_SURVIVOR: iFlags = iFlags | CHATFLAGS_SURVIVOR;
        case TEAM_INFECTED: iFlags = iFlags | CHATFLAGS_INFECTED;
    }

    if (!IsPlayerAlive(iSender)) {
        iFlags = iFlags | CHATFLAGS_DEAD;
    }

    /**
     * Store the clients in an array so the call can manipulate it.
     */
    Handle hRecipients = iFlags & CHATFLAGS_TEAM ? PrepareRecipients(iTeam) : PrepareRecipients();

    /**
     * Preparing a copy of the data to undo changes.
     */
    char sOriginalName[MAXLENGTH_NAME];
    strcopy(sOriginalName, sizeof(sOriginalName), sSenderName);

    char sOriginalMessage[MAXLENGTH_MESSAGE];
    strcopy(sOriginalMessage, sizeof(sOriginalMessage), sMessage);

    Handle hOriginalRecipients = CloneArray(hRecipients);

    /*
     * Start the forward for other plugins.
     */
    Action fResult = CallOnChatMessage(iSender, hRecipients, sSenderName, sMessage, iFlags);

    if (fResult == Plugin_Continue)
    {
        CloseHandle(hRecipients);
        hRecipients = CloneArray(hOriginalRecipients);
        CloseHandle(hOriginalRecipients);

        strcopy(sSenderName, sizeof(sSenderName), sOriginalName);
        strcopy(sMessage, sizeof(sMessage), sOriginalMessage);
    }

    else if (fResult == Plugin_Stop)
    {
        CloseHandle(hRecipients);
        CloseHandle(hOriginalRecipients);
        return Plugin_Handled;
    }

    /**
     * Checking if there are valid recipients.
     */
    int iRecipients = ValidateRecipients(hRecipients);

    if (!iRecipients) {
        return Plugin_Handled;
    }

    /*
     * This is the check for a name change. If it has not changed we add the team color code.
     */
    if (StrEqual(sOriginalName, sSenderName)) {
        Format(sSenderName, sizeof(sSenderName), "\x03%s", sSenderName);
    }

    char sChatType[64]; GetChatTemplateByFlags(iFlags, sChatType, sizeof(sChatType));

    for (int iRecipient = 0; iRecipient < iRecipients; iRecipient ++)
    {
        int iPlayer = GetArrayCell(hRecipients, iRecipient);

        CPrintToChatEx(iPlayer, iSender, "%T", sChatType, iPlayer, sSenderName, sMessage);
    }

    /*
     * Start forwarding sent messages for other plugins.
     */
    CallOnChatMessagePost(iSender, hRecipients, sSenderName, sMessage, iFlags);

    /*
     * Clearing the Handle.
     */
    CloseHandle(hRecipients);

    /*
     * Stop the original message.
     */
    return Plugin_Handled;
}

/**
 * Get chat template by flags.
 *
 * @param iFlags         Chat flags.
 * @param sChatTemplate  Buffer for chat template.
 * @param iLength        Buffer length.
 */
void GetChatTemplateByFlags(int iFlags, char[] sChatTemplate, int iLength)
{
    if (iFlags & CHATFLAGS_TEAM) {
        if (iFlags & CHATFLAGS_SURVIVOR) {
            strcopy(sChatTemplate, iLength, iFlags & CHATFLAGS_DEAD ? "L4D_Chat_Survivor_Dead" : "L4D_Chat_Survivor");
        } else if (iFlags & CHATFLAGS_INFECTED) {
            strcopy(sChatTemplate, iLength, iFlags & CHATFLAGS_DEAD ? "L4D_Chat_Infected_Dead" : "L4D_Chat_Infected");
        } else if (iFlags & CHATFLAGS_SPECTATOR) {
            strcopy(sChatTemplate, iLength, "L4D_Chat_Spec");
        }
    } else if (iFlags & CHATFLAGS_SPECTATOR) {
        strcopy(sChatTemplate, iLength, "L4D_Chat_AllSpec");
    } else if (iFlags & CHATFLAGS_DEAD) {
        strcopy(sChatTemplate, iLength, "L4D_Chat_AllDead");
    } else {
        strcopy(sChatTemplate, iLength, "L4D_Chat_All");
    }
}

/**
 * Prepare recipients.
 *
 * @param iTeam  Team index (default -1).
 * @return       Handle of recipients array.
 */
Handle PrepareRecipients(int iTeam = -1)
{
    Handle hRecipients = CreateArray();

    bool bIsValidTeam = IsValidTeam(iTeam);

    for (int iRecipient = 1; iRecipient <= MaxClients; iRecipient ++)
    {
        if (!IsClientInGame(iRecipient)) {
            continue;
        }

        if (IsFakeClient(iRecipient))
        {
            if (IsClientSourceTV(iRecipient)) {
                PushArrayCell(hRecipients, iRecipient);
            }

            continue;
        }

        if (bIsValidTeam && GetClientTeam(iRecipient) != iTeam) {
            continue;
        }

        PushArrayCell(hRecipients, iRecipient);
    }

    return hRecipients;
}

/**
 * Validate recipients.
 *
 * @param hRecipients  Handle of recipients array.
 * @return             Number of valid recipients.
 */
int ValidateRecipients(Handle hRecipients)
{
    int iRecipientCounter = 0;

    while (iRecipientCounter < GetArraySize(hRecipients))
    {
        if (!IsValidRecipient(GetArrayCell(hRecipients, iRecipientCounter))) {
            RemoveFromArray(hRecipients, iRecipientCounter);
        } else {
            iRecipientCounter ++;
        }
    }

    return iRecipientCounter;
}

/**
 * Call forward for chat message.
 *
 * @param iSender           Sender index.
 * @param hRecipients       Handle of recipients array.
 * @param sSenderName       Sender name.
 * @param sMessage          Message.
 * @param iFlags            Chat flags.
 * @return                  Plugin action.
 */
Action CallOnChatMessage(int iSender, Handle hRecipients, char[] sSenderName, char[] sMessage, int iFlags)
{
    Action fResult = Plugin_Continue;

    if (GetForwardFunctionCount(g_fwdOnChatMessage))
    {
        Call_StartForward(g_fwdOnChatMessage);
        Call_PushCell(iSender);
        Call_PushCell(hRecipients);
        Call_PushStringEx(sSenderName, MAXLENGTH_NAME, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
        Call_PushStringEx(sMessage, MAXLENGTH_MESSAGE, SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
        Call_PushCell(iFlags);

        if (Call_Finish(fResult) != SP_ERROR_NONE) {
            return Plugin_Continue;
        }
    }

    return fResult;
}

/**
 * Call forward for post chat message.
 *
 * @param iSender       Sender index.
 * @param hRecipients   Handle of recipients array.
 * @param sSenderName   Sender name.
 * @param sMessage      Message.
 * @param iFlags        Chat flags.
 */
void CallOnChatMessagePost(int iSender, Handle hRecipients, char[] sSenderName, char[] sMessage, int iFlags)
{
    if (GetForwardFunctionCount(g_fwdOnChatMessagePost))
    {
        Call_StartForward(g_fwdOnChatMessagePost);
        Call_PushCell(iSender);
        Call_PushCell(hRecipients);
        Call_PushString(sSenderName);
        Call_PushString(sMessage);
        Call_PushCell(iFlags);
        Call_Finish();
    }
}

/**
 * Validates if is a valid team.
 *
 * @param iTeam     Team index.
 * @return          True if team is valid, false otherwise.
 */
bool IsValidTeam(int iTeam) {
    return iTeam >= TEAM_SPECTATOR && iTeam <= TEAM_INFECTED;
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

/**
 * Validates if is a valid recipient.
 *
 * @param iRecipient Recipient index.
 * @return           True if recipient is valid, false otherwise.
 */
bool IsValidRecipient(int iRecipient)
{
    if (!IsValidClient(iRecipient)
    || !IsClientInGame(iRecipient)
    || (IsFakeClient(iRecipient) && !IsClientSourceTV(iRecipient))
    ) {
        return false;
    }

    return true;
}
