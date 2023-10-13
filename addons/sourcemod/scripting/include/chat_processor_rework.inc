#if defined _chat_processor_rework_included
  #endinput
#endif
#define _chat_processor_rework_included

#define MAXLENGTH_INPUT        128 // Inclues \0 and is the size of the chat input box.
#define MAXLENGTH_NAME         64  // This is backwords math to get compability.  Sourcemod has it set at 32, but there is room for more.
#define MAXLENGTH_MESSAGE      256 // This is based upon the SDK and the length of the entire message, including tags, name, : etc.

#define CHATFLAGS_INVALID      0
#define CHATFLAGS_ALL          (1 << 0)
#define CHATFLAGS_TEAM         (1 << 1)
#define CHATFLAGS_SPEC         (1 << 2)
#define CHATFLAGS_DEAD         (1 << 3)


/**
 * When a player types a chat message
 *
 * NOTES:
 * Use MAXLENGTH_  constants above for formating the strings
 * Do not rely on the recipients handle to exist beyond the forward
 * Do not start another usermessage (PrintToChat) within this forward
 *
 * @param 		author						The client index of the player who sent the chat message (Byref)
 * @param 		recipients					The handle to the client index adt array of the players who should recieve the chat message
 * @param 		name						The client's name of the player who sent the chat message (Byref)
 * @param 		message						The contents of the chat message (Byref)
 * @noreturn
 */
forward Action OnChatMessage(int &author, Handle recipients, char[] name, char[] message, int iFlags);


/**
 * Called after all OnChatMessage forwards have been fired and the message is being broadcast.
 *
 * NOTES:
 * Use MAXLENGTH_  constants above for formating the strings
 * Do not rely on the recipients handle to exist beyond the forward
 *
 * @param 		author						The client index of the player who sent the chat message
 * @param 		recipients					The handle to the client index adt array of the players who are receiting the chat message
 * @param 		name						The client's name of the player who sent the chat message (after any replacements)
 * @param 		message						The contents of the chat message (after any replacements)
 * @noreturn
 */
forward void OnChatMessage_Post(int author, Handle recipients, const char[] name, const char[] message, int iFlags);


public SharedPlugin:_pl_chat_processor_rework =
{
	name = "chat_processor_rework",
	file = "chat_processor_rework.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};