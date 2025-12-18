int g_iRespawnRoundLimit[MAXPLAYERS + 1] = {0, ...};

int g_cvarRespawnRoundLimit;

public void Respawn_OnPluginStart()
{
	Store_RegisterHandler("respawn", "", Respawn_OnMapStart, Respawn_Reset, Respawn_Config, Respawn_Equip, Respawn_Remove, false);

	g_cvarRespawnRoundLimit = RegisterConVar("sm_store_respawn_round_limit", "1", "Number of times you can buy respawn in a round", TYPE_INT);
}

public void Respawn_OnPlayerSpawn(int client)
{
	g_iRespawnRoundLimit[client] = 0;
}

public void Respawn_OnMapStart()
{
}

public void Respawn_Reset()
{
}

public bool Respawn_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, 0);
	return true;
}

public int Respawn_Equip(int client, int id)
{
	if(g_iRespawnRoundLimit[client] == g_eCvars[g_cvarRespawnRoundLimit].aCache)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Respawn Round Limit CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Respawn Round Limit");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Respawn Round Limit");
		#endif
		return 1;
	}

	CS_RespawnPlayer(client);

	++g_iRespawnRoundLimit[client];
	return 0;
}

public int Respawn_Remove(int client)
{
	return 0;
}