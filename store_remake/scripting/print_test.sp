#include <sourcemod>
#tryinclude <clientmod>          
#tryinclude <clientmod/multicolors>
#tryinclude <chatmodern>
public Plugin myinfo = {
	name = "Chat color test",
	author = "anonim8",
	description = "",
	version = "",
	url = ""
};
#if defined _chat_modern_included
ChatModern chatm;
#endif
public void OnPluginStart(){
	#if defined _chat_modern_included
	chatm = new ChatModern(GetEngineVersion());
	#endif
	RegConsoleCmd("sm_test", Cmd_Test);
}

public Action Cmd_Test(int client, int args){
	if (IsValidClient(client)){
		CM_PrintToChatAll();
	}
	return Plugin_Handled;
}

stock bool IsValidClient(int client){
	if (client >= 1 && client <= MaxClients && IsClientConnected(client) && IsClientInGame(client) && !IsFakeClient(client) && !IsClientSourceTV(client) && !IsClientReplay(client)){
		return true;
	}
	return false;
}

stock void CM_PrintToChatAll()
{
	#if defined _clientmod_included && defined _chat_modern_included
		for (int i = 1; i <= MaxClients; i++)
		{
			MC_PrintToChat(i, "{white}TEXT_CM TEXT_CM TEXT_CM");
			if (!CM_IsClientModUser(i))
				chatm.CPrintToChat(i, "\x04TEXT_CHATM TEXT_CHATM TEXT_CHATM");
		}
	#else
		#if defined _clientmod_included
			for (int i = 1; i <= MaxClients; i++)
			{
				MC_PrintToChat(i, "{white}TEXT_CM TEXT_CM TEXT_CM");
				C_PrintToChat(i, "\x04TEXT_OLD TEXT_OLD TEXT_OLD");
			}
		#else
			#if defined _chat_modern_included
				chatm.CPrintToChatAll("\x04TEXT_CHATM TEXT_CHATM TEXT_CHATM");
			#else
				PrintToChatAll("\x04TEXT_OLD TEXT_OLD TEXT_OLD");
			#endif
		#endif
	#endif
}