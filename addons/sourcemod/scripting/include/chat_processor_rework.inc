#if defined _chat_processor_rework_included
  #endinput
#endif
#define _chat_processor_rework_included


#define MAXLENGTH_TAG			    128
#define MAXLENGTH_NAME			    128
#define MAXLENGTH_MESSAGE		    256

/*
 * Chat flags.
 */
#define CHATFLAGS_INVALID      0
#define CHATFLAGS_TEAM         (1 << 0)
#define CHATFLAGS_SPECTATOR    (1 << 1)
#define CHATFLAGS_SURVIVOR     (1 << 2)
#define CHATFLAGS_INFECTED     (1 << 3)
#define CHATFLAGS_DEAD         (1 << 4)


/**
 * When a player types a chat message
 *
 * NOTES:
 * Use MAXLENGTH_  constants above for formating the strings
 * Do not rely on the recipients handle to exist beyond the forward
 * Do not start another usermessage (PrintToChat) within this forward
 *
 * @param 		iAuthor						The client index of the player who sent the chat message
 * @param 		hRecipients					The handle to the client index adt array of the players who should recieve the chat message
 * @param 		szName						The client's name of the player who sent the chat message (Byref)
 * @param 		szMessage					The contents of the chat message (Byref)
 * @noreturn
 */
forward Action OnChatMessage(int iAuthor, Handle hRecipients, char[] szTag, char[] szName, char[] szMessage, int iFlags);

/**
 * Called after all OnChatMessage forwards have been fired and the message is being broadcast.
 *
 * NOTES:
 * Use MAXLENGTH_  constants above for formating the strings
 * Do not rely on the recipients handle to exist beyond the forward
 *
 * @param 		iAuthor						The client index of the player who sent the chat message
 * @param 		recipients					The handle to the client index adt array of the players who are receiting the chat message
 * @param 		szName						The client's name of the player who sent the chat message (after any replacements)
 * @param 		szMessage					The contents of the chat message (after any replacements)
 * @noreturn
 */
forward void OnChatMessage_Post(int iAuthor, Handle hRecipients, const char[] szTag, const char[] szName, const char[] szMessage, int iFlags);

/**
Shared plugin information
**/
public SharedPlugin __pl_chat_processor_rework =
{
    name = "chat_processor_rework",
    file = "chat_processor_rework.smx",
#if defined REQUIRE_PLUGIN
    required = 1
#else
    required = 0
#endif
};