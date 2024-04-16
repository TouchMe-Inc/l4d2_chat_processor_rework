#pragma semicolon              1
#pragma newdecls               required

#include <sourcemod>
#include <colors>


public Plugin myinfo = {
	name = "ChatProcessorRework",
	author = "Simple Plugins, Mini, TouchMe",
	description = "Process chat and allows other plugins to manipulate chat",
	version = "build0001",
	url = "https://github.com/TouchMe-Inc/l4d2_chat_processor_rework"
};


#define SENDER_WORLD           0

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
 * Team.
 */
#define TEAM_SPECTATOR          1
#define TEAM_SURVIVOR           2
#define TEAM_INFECTED           3

/*
 * Other.
 */
#define TRANSLATIONS            "chat_processor_rework.phrases"


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

	g_fwdOnChatMessage = CreateGlobalForward("OnChatMessage", ET_Hook, Param_CellByRef, Param_Cell, Param_String, Param_String, Param_Cell);
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

Action Cmd_Say(int iSender, const char[] sCmd, int iArgs)
{
	if (iSender == SENDER_WORLD) {
		return Plugin_Continue;
	}

	/**
	 * Get the message.
	 */
 	char sMessage[MAXLENGTH_MESSAGE];
	GetCmdArgString(sMessage, sizeof(sMessage));
	CRemoveTags(sMessage, sizeof(sMessage));
	TrimString(sMessage);
	StripQuotes(sMessage);

	if (sMessage[0] == '/') {
		return Plugin_Handled;
	}

	/*
	 * Get the senders name.
	 */
	char sSenderName[MAXLENGTH_NAME];
	GetClientName(iSender, sSenderName, sizeof(sSenderName));
	CRemoveTags(sSenderName, sizeof(sSenderName));
	StripQuotes(sSenderName);

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
	Handle hRecipients = CreateArray();

	for (int iRecipient = 1; iRecipient <= MaxClients; iRecipient ++)
	{
		if (!IsClientInGame(iRecipient)) {
			continue;
		}

		if (IsFakeClient(iRecipient) && IsClientSourceTV(iRecipient))
		{
			PushArrayCell(hRecipients, iRecipient);
			continue;
		}

		if (iFlags & CHATFLAGS_TEAM && GetClientTeam(iRecipient) != iTeam) {
			continue;
		}

		PushArrayCell(hRecipients, iRecipient);
	}

	/*
	 * Because the message could be changed but not the name
	 * we need to compare the original name to the returned name.
	 * We do this because we may have to add the team color code to the name,
	 * where as the message doesn't get a color code by default.
	 */
	char sOriginalName[MAXLENGTH_NAME];
	strcopy(sOriginalName, sizeof(sOriginalName), sSenderName);

	/*
	 * Start the forward for other plugins.
	 */
	Action fResult = Plugin_Continue;

	Call_StartForward(g_fwdOnChatMessage);
	Call_PushCellRef(iSender);
	Call_PushCell(hRecipients);
	Call_PushStringEx(sSenderName, sizeof(sSenderName), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushStringEx(sMessage, sizeof(sMessage), SM_PARAM_STRING_UTF8|SM_PARAM_STRING_COPY, SM_PARAM_COPYBACK);
	Call_PushCell(iFlags);

	int fError = Call_Finish(fResult);

	if (fError != SP_ERROR_NONE)
	{
		ThrowNativeError(fError, "Forward OnChatMessage failed");
		CloseHandle(hRecipients);
		return Plugin_Continue;
	}

	else if (fResult == Plugin_Continue)
	{
		CloseHandle(hRecipients);
		return Plugin_Continue;
	}

	else if (fResult == Plugin_Stop)
	{
		CloseHandle(hRecipients);
		return Plugin_Handled;
	}

	/*
	 * This is the check for a name change. If it has not changed we add the team color code.
	 */
	if (StrEqual(sOriginalName, sSenderName)) {
		Format(sSenderName, sizeof(sSenderName), "\x03%s", sSenderName);
	}

	int iResepient = 0;

	while (iResepient < GetArraySize(hRecipients))
	{
		if (!IsValidPlayer(GetArrayCell(hRecipients, iResepient))) {
			RemoveFromArray(hRecipients, iResepient);
		} else {
			iResepient ++;
		}
	}

	/*
	 * Create a dp for print the message on the next gameframe.
	 */
	Handle hPack = CreateDataPack();

	WritePackCell(hPack, hRecipients);
	WritePackCell(hPack, iSender);
	WritePackString(hPack, sSenderName);
	WritePackString(hPack, sMessage);
	WritePackCell(hPack, iFlags);

	RequestFrame(Frame_SendClientMessage, hPack);

	// Stop the original message.
	return Plugin_Handled;
}

void Frame_SendClientMessage(Handle hPack)
{
	ResetPack(hPack);

	/**
	 * Get dp data.
	 */
	Handle hRecipients = ReadPackCell(hPack);
	int iSender = ReadPackCell(hPack);
	char sSenderName[MAXLENGTH_NAME]; ReadPackString(hPack, sSenderName, sizeof(sSenderName));
	char sMessage[MAXLENGTH_INPUT]; ReadPackString(hPack, sMessage, sizeof(sMessage));
	int iFlags = ReadPackCell(hPack);

	CloseHandle(hPack);

	char sChatType[64];

	if (iFlags & CHATFLAGS_TEAM)
	{
		if (iFlags & CHATFLAGS_SURVIVOR) {
			strcopy(sChatType, sizeof(sChatType), iFlags & CHATFLAGS_DEAD ? "L4D_Chat_Survivor_Dead" : "L4D_Chat_Survivor");
		} else if (iFlags & CHATFLAGS_INFECTED) {
			strcopy(sChatType, sizeof(sChatType), iFlags & CHATFLAGS_DEAD ? "L4D_Chat_Infected_Dead" : "L4D_Chat_Infected");
		} else if (iFlags & CHATFLAGS_SPECTATOR) {
			strcopy(sChatType, sizeof(sChatType), "L4D_Chat_Spec");
		}
	}

	else
	{
		if (iFlags & CHATFLAGS_SPECTATOR) {
			strcopy(sChatType, sizeof(sChatType), "L4D_Chat_AllSpec");
		} else if (iFlags & CHATFLAGS_DEAD) {
			strcopy(sChatType, sizeof(sChatType), "L4D_Chat_AllDead");
		} else {
			strcopy(sChatType, sizeof(sChatType), "L4D_Chat_All");
		}
	}

	int iRecipients = GetArraySize(hRecipients);

	for (int iRecipient = 0; iRecipient < iRecipients; iRecipient ++)
	{
		int iPlayer = GetArrayCell(hRecipients, iRecipient);

		if (!IsValidPlayer(iPlayer)) {
			continue;
		}

		CPrintToChatEx(iPlayer, iSender, "%T", sChatType, iPlayer, sSenderName, sMessage);
	}

	Call_StartForward(g_fwdOnChatMessagePost);
	Call_PushCell(iSender);
	Call_PushCell(hRecipients);
	Call_PushString(sSenderName);
	Call_PushString(sMessage);
	Call_PushCell(iFlags);
	Call_Finish();

	CloseHandle(hRecipients);
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

bool IsValidPlayer(int iClient)
{
	if (!IsValidClient(iClient) || !IsClientConnected(iClient) || IsFakeClient(iClient)) {
		return false;
	}

	return IsClientInGame(iClient);
}
