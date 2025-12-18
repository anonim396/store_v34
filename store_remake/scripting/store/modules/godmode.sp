float g_flGodmodes[STORE_MAX_ITEMS];
int g_iGodmodes = 0;
int g_iGodmodeRoundLimit[MAXPLAYERS + 1] = {0, ...};

int g_cvarGodmodeRoundLimit;
int g_cvarGodmodeTeam;

public void Godmode_OnPluginStart()
{
	Store_RegisterHandler("godmode", "", Godmode_OnMapStart, Godmode_Reset, Godmode_Config, Godmode_Equip, Godmode_Remove, false);

	g_cvarGodmodeRoundLimit = RegisterConVar("sm_store_godmode_round_limit", "1", "Number of times you can buy godmode in a round", TYPE_INT);
	g_cvarGodmodeTeam = RegisterConVar("sm_store_godmode_team", "0", "Team that can use godmode. 0=Any 2=Terrorist 3=Counter-Terrorist", TYPE_INT);
}

public void Godmode_OnPlayerSpawn(int client)
{
	if(!IsClientInGame(client))
		return;

	g_iGodmodeRoundLimit[client] = 0;
}

public void Godmode_OnMapStart()
{
}

public void Godmode_Reset()
{
	g_iGodmodes = 0;
}

public bool Godmode_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iGodmodes);
	
	g_flGodmodes[g_iGodmodes] = KvGetFloat(kv, "duration");

	++g_iGodmodes;
	return true;
}

public int Godmode_Equip(int client, int id)
{
	if(g_iGodmodeRoundLimit[client] == g_eCvars[g_cvarGodmodeRoundLimit].aCache)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Godmode Round Limit CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Godmode Round Limit");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Godmode Round Limit");
		#endif
		return 1;
	}

	if(g_eCvars[g_cvarGodmodeTeam].aCache != 0 && g_eCvars[g_cvarGodmodeTeam].aCache != GetClientTeam(client))
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Godmode Wrong Team CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Godmode Wrong Team");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Godmode Wrong Team");
		#endif
		return 1;
	}

	int m_iData = Store_GetDataIndex(id);

	SDKHook(client, SDKHook_OnTakeDamage, Godmode_OnTakeDamage);
	CreateTimer(g_flGodmodes[m_iData], Godmode_WearOff, GetClientUserId(client));

	++g_iGodmodeRoundLimit[client];
	return 0;
}

public int Godmode_Remove(int client)
{
	return 0;
}

public Action Godmode_WearOff(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client))
		return Plugin_Stop;
	SDKUnhook(client, SDKHook_OnTakeDamage, Godmode_OnTakeDamage);
	return Plugin_Stop;
}

public Action Godmode_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], float damagePosition[3])
{
	damage = 0.0;
	return Plugin_Changed;
}