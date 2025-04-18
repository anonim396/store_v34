#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#tryinclude <thirdperson>

#define OBSERVER_MODE_NONE 0
#define OBSERVER_MODE_THIRD_PERSON 1

bool g_bThirdperson[MAXPLAYERS + 1];
ConVar g_hAllowThirdperson;

public Plugin myinfo = 
{
	name		= "Simple Thirdperson API",
	author		= "ChatGPT + anonim396",
	description	= "Toggle between first and thirdperson",
	version		= "1.2"
};

#if defined _thirdperson_included_
void ToggleThirdperson(int client)
{	
	if (!IsValidClient(client))
	{
		LogError("Invalid client %d in ToggleThirdperson", client);
		return;
	}
	
	if(g_hAllowThirdperson != null && GetConVarInt(g_hAllowThirdperson) > 0)
	{
		ClientCommand(client, g_bThirdperson[client] ? "thirdperson" : "firstperson");
	}
	else
	{
		PrintToConsole(client, "[SM] The se_allow_thirdperson command was not found or was equal to 0, using an alternative method.");
		ToggleThirdpersonSimple(client);
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("IsPlayerInTP", Native_IsPlayerInTP);
	CreateNative("TogglePlayerTP", Native_TogglePlayerTP);
	return APLRes_Success;
}

public any Native_IsPlayerInTP(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	if (!IsValidClient(client)) 
	{
		LogError("Invalid client index %d in Native_IsPlayerInTP", client);
		return false;
	}
	return g_bThirdperson[client];
}

public any Native_TogglePlayerTP(Handle plugin, int numParams)
{
	int client = GetNativeCell(1);
	g_bThirdperson[client] = !g_bThirdperson[client];
	ToggleThirdperson(client);
	return g_bThirdperson[client];
}
#endif

public void OnPluginStart()
{	
	RegConsoleCmd("sm_tp", Cmd_ToggleView);
	HookEvent("player_spawn", Event_PlayerSpawn);
}

public Action Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{	
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!IsValidClient(client)) 
	{
		LogError("Invalid client %d in Event_PlayerSpawn", client);
		return Plugin_Continue;
	}
	
	if (g_hAllowThirdperson == null)
	{
		g_hAllowThirdperson = FindConVar("se_allow_thirdperson");
	}
	
	if(g_bThirdperson[client])
	{
		#if defined _thirdperson_included_
			ToggleThirdperson(client);
		#else
			ToggleThirdpersonSimple(client);
		#endif
	}
	return Plugin_Continue;
}

public void OnClientDisconnect(int client)
{
	if (!IsValidClient(client)) return;
	g_bThirdperson[client] = false;
}

public Action Cmd_ToggleView(int client, int args)
{
	if (!IsValidClient(client))
	{
		LogError("Invalid client %d in Cmd_ToggleView", client);
		return Plugin_Handled;
	}

	if(GetConVarInt(g_hAllowThirdperson) > 0 && g_bThirdperson[client] == true)
	{
		SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
	}


	g_bThirdperson[client] ^= true;

	#if defined _thirdperson_included_
		ToggleThirdperson(client);
	#else
		ToggleThirdpersonSimple(client);
	#endif

	return Plugin_Handled;
}

void ToggleThirdpersonSimple(int client)
{	
	SetObserverMode(client, g_bThirdperson[client]);
}

void SetObserverMode(int client, bool thirdPerson)
{	
	SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
	SetEntProp(client, Prop_Send, "m_iObserverMode", thirdPerson ? OBSERVER_MODE_THIRD_PERSON : OBSERVER_MODE_NONE);
	SetEntProp(client, Prop_Send, "m_bDrawViewmodel", !thirdPerson);
}

bool IsValidClient(int client)
{
	return (0 < client <= MaxClients) && IsClientInGame(client) && IsPlayerAlive(client);
}