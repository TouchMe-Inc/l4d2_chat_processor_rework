#pragma semicolon              1
#pragma newdecls               required

#include <sourcemod>


public Plugin myinfo = {
	name = "ChatProcessorRework",
	author = "Simple Plugins, Mini, TouchMe",
	description = "Process chat and allows other plugins to manipulate chat",
	version = "build0000",
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
#define CHATFLAGS_ALL          (1 << 0)
#define CHATFLAGS_TEAM         (1 << 1)
#define CHATFLAGS_SPEC         (1 << 2)
#define CHATFLAGS_DEAD         (1 << 3)

/*
 * Other.
 */
#define TRANSLATIONS            "chat_processor_rework.phrases"


Handle g_hChatFormats = INVALID_HANDLE;

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
	g_hChatFormats = CreateTrie();

	UserMsg umSayText2 = GetUserMessageId("SayText2");

	if (umSayText2 != INVALID_MESSAGE_ID)
	{
		char sTranslationLocation[PLATFORM_MAX_PATH];
		BuildPath(Path_SM, sTranslationLocation, sizeof(sTranslationLocation), "translations/%s.txt", TRANSLATIONS);

		if (!GetChatFormats(sTranslationLocation)) {
			SetFailState("Could not parse the translation file");
		}

		LoadTranslations(TRANSLATIONS);

		HookUserMessage(umSayText2, OnSayText2, true);
	}
}

public Action OnSayText2(UserMsg msg_id, Handle bf, const int[] iPlayers, int iTotalPlayers, bool reliable, bool init)
{
	/*
	 * Get the sender of the usermessage and bug out if it is not a player.
	 */
	int iSender = BfReadByte(bf);

	if (iSender == SENDER_WORLD) {
		return Plugin_Continue;
	}

	/*
	 * Get the chat bool.  This determines if sent to console as well as chat.
	 */
	bool bChat = (BfReadByte(bf) ? true : false);

	/*
	 * Make sure we have a default translation string for the message
	 * This also determines the message type...
	 */
	char cpTranslationName[32];
	BfReadString(bf, cpTranslationName, sizeof(cpTranslationName));

	int buffer = 0;
	int iFlags = CHATFLAGS_INVALID;

	if (!GetTrieValue(g_hChatFormats, cpTranslationName, buffer)) {
		return Plugin_Continue;
	}

	else {
		iFlags = GetChatFlags(cpTranslationName);
	}

	/*
	 * Get the senders name.
	 */
	char sSenderName[MAXLENGTH_NAME];
	if (BfGetNumBytesLeft(bf)) {
		BfReadString(bf, sSenderName, sizeof(sSenderName));
	}

	/**
	 * Get the message.
	 */
	char sMessage[MAXLENGTH_INPUT];
	if (BfGetNumBytesLeft(bf)) {
		BfReadString(bf, sMessage, sizeof(sMessage));
	}

	/**
	 * Store the clients in an array so the call can manipulate it.
	 */
	Handle hRecipients = CreateArray();
	for (int iPlayer = 0; iPlayer < iTotalPlayers; iPlayer++)
	{
		PushArrayCell(hRecipients, iPlayers[iPlayer]);
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
		ThrowNativeError(fError, "Forward failed");
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
		FormatEx(sSenderName, sizeof(sSenderName), "\x03%s", sSenderName);
	}

	/**
	 * Create a dp for print the message on the next gameframe.
	 */
	Handle hPack = CreateDataPack();

	int iRecipients = GetArraySize(hRecipients);

	WritePackCell(hPack, iSender);

	for (int iRecipient = 0; iRecipient < iRecipients; iRecipient ++)
	{
		if (!IsValidPlayer(GetArrayCell(hRecipients, iRecipient)))
		{
			iRecipients--;
			RemoveFromArray(hRecipients, iRecipient);
		}
	}

	WritePackCell(hPack, iRecipients);

	for (int iRecipient = 0; iRecipient < iRecipients; iRecipient ++)
	{
		WritePackCell(hPack, GetArrayCell(hRecipients, iRecipient));
	}

	WritePackCell(hPack, bChat);
	WritePackString(hPack, cpTranslationName);
	WritePackString(hPack, sSenderName);
	WritePackString(hPack, sMessage);
	WritePackCell(hPack, iFlags);

	CloseHandle(hRecipients);

	RequestFrame(SayText2Post, hPack);

	// Stop the original message.
	return Plugin_Handled;
}

public void SayText2Post(Handle hPack)
{
	ResetPack(hPack);

	char sSenderName[MAXLENGTH_NAME];
	char sMessage[MAXLENGTH_INPUT];
	Handle hRecipients = CreateArray();

	int iSender = ReadPackCell(hPack);
	int iTotalPlayers = ReadPackCell(hPack);
	int iTotalPlayersPost = 0;
	int[] iPlayers = new int[iTotalPlayers];

	for (int x = 0; x < iTotalPlayers; x++)
	{
		int buffer = ReadPackCell(hPack);

		if (IsValidPlayer(buffer))
		{
			iPlayers[iTotalPlayersPost++] = buffer;
			PushArrayCell(hRecipients, buffer);
		}
	}

	bool bChat = view_as<bool>(ReadPackCell(hPack));
	char sChatType[32];
	ReadPackString(hPack, sChatType, sizeof(sChatType));
	ReadPackString(hPack, sSenderName, sizeof(sSenderName));
	ReadPackString(hPack, sMessage, sizeof(sMessage));

	char sTranslation[MAXLENGTH_MESSAGE];
	FormatEx(sTranslation, sizeof(sTranslation), "%t", sChatType, sSenderName, sMessage);

	{
		Handle bf = StartMessage("SayText2", iPlayers, iTotalPlayersPost, USERMSG_RELIABLE | USERMSG_BLOCKHOOKS);

		BfWriteByte(bf, iSender);
		BfWriteByte(bf, bChat);
		BfWriteString(bf, sTranslation);

		EndMessage();
	}

	Call_StartForward(g_fwdOnChatMessagePost);
	Call_PushCell(iSender);
	Call_PushCell(hRecipients);
	Call_PushString(sSenderName);
	Call_PushString(sMessage);
	Call_PushCell(ReadPackCell(hPack)); // Flags
	Call_Finish();

	CloseHandle(hRecipients);
	CloseHandle(hPack);
}

bool GetChatFormats(const char[] file)
{
	Handle hParser = SMC_CreateParser();

	int iLine = 0;
	int iColumn = 0;

	SMC_SetReaders(hParser, Config_NewSection, Config_KeyValue, Config_EndSection);
	SMCError result = SMC_ParseFile(hParser, file, iLine, iColumn);
	CloseHandle(hParser);

	if (result != SMCError_Okay)
	{
		char error[128];
		SMC_GetErrorString(result, error, sizeof(error));
		LogError("%s on line %d, col %d of %s", error, iLine, iColumn, file);
	}

	return (result == SMCError_Okay);
}

public SMCResult Config_NewSection(Handle parser, const char[] section, bool quotes)
{
	if (StrEqual(section, "Phrases")) {
		return SMCParse_Continue;
	}

	SetTrieValue(g_hChatFormats, section, 1);

	return SMCParse_Continue;
}

public SMCResult Config_KeyValue(Handle parser, const char[] key, const char[] value, bool key_quotes, bool value_quotes) {
	return SMCParse_Continue;
}

public SMCResult Config_EndSection(Handle parser) {
	return SMCParse_Continue;
}

int GetChatFlags(const char[] sTranslationName)
{
	int iFlags = 0;

	if (StrContains(sTranslationName, "all", false) != -1) {
		iFlags = iFlags | CHATFLAGS_ALL;
	}

	if (StrContains(sTranslationName, "team", false) != -1
	|| StrContains(sTranslationName, "survivor", false) != -1
	|| StrContains(sTranslationName, "infected", false) != -1) {
		iFlags = iFlags | CHATFLAGS_TEAM;
	}

	if (StrContains(sTranslationName, "spec", false) != -1) {
		iFlags = iFlags | CHATFLAGS_SPEC;
	}

	if (StrContains(sTranslationName, "dead", false) != -1) {
		iFlags = iFlags | CHATFLAGS_DEAD;
	}

	return iFlags;
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
