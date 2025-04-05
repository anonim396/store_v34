#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#tryinclude <thirdperson>

bool g_bThirdperson[MAXPLAYERS + 1];

public Plugin myinfo = 
{
	name		= "Simple Thirdperson API",
	author		= "ChatGPT + anonim396",
	description	= "Toggle between first and thirdperson",
	version		= "1.1"
};

#if defined _thirdperson_included_

ConVar g_hAllowThirdperson;

void ToggleThirdperson(int client)
{
	g_hAllowThirdperson = FindConVar("se_allow_thirdperson");
	if(g_hAllowThirdperson == null || GetConVarInt(g_hAllowThirdperson) < 1)
	{
		PrintToConsole(client, "[SM] The se_allow_thirdperson command was not found or was equal to 0, using an alternative method.");
		ToggleThirdpersonSimple(client);
	}
	else
		ClientCommand(client, g_bThirdperson[client] ? "thirdperson" : "firstperson");
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("IsPlayerInTP", Native_IsPlayerInTP);
	CreateNative("TogglePlayerTP", Native_TogglePlayerTP);
	return APLRes_Success;
}

public any Native_IsPlayerInTP(Handle plugin, int numParams)
{
	return g_bThirdperson[GetNativeCell(1)];
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
	if(!IsClientInGame(client))
		return;
	
	if(g_bThirdperson[client])
	{
		#if defined _thirdperson_included_
			ToggleThirdperson(client);
		#else
			return;
		#endif
	}
}

public void OnClientDisconnect(int client)
{
	g_bThirdperson[client] = false;
}

public Action Cmd_ToggleView(int client, int args)
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Handled;

	g_bThirdperson[client] = !g_bThirdperson[client];

	#if defined _thirdperson_included_
		ToggleThirdperson(client);
	#else
		ToggleThirdpersonSimple(client);
	#endif

	return Plugin_Handled;
}

void ToggleThirdpersonSimple(int client)
{
	if(g_bThirdperson[client])
	{
		float offset[3] = {-100.0, 0.0, 15.0};
		SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", 0);
		SetEntProp(client, Prop_Send, "m_iObserverMode", 1);
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
		SetEntProp(client, Prop_Send, "m_iFOV", 90);
		SetEntPropVector(client, Prop_Send, "m_vecThirdPersonViewOffset", offset);
	}
	else
	{
		SetEntProp(client, Prop_Send, "m_iObserverMode", 0);
		SetEntProp(client, Prop_Send, "m_bDrawViewmodel", 1);
		SetEntProp(client, Prop_Send, "m_iFOV", 90);
	}
}