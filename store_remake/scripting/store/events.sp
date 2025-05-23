void Store_Events_OnPluginStart()
{
	// Hook events
	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_spawn", Event_PlayerSpawn);
	HookEventEx("player_changename", OnClientChangeName, EventHookMode_Pre);
}

//////////////////////////////
//			EVENTS			//
//////////////////////////////

public Action Event_PlayerDeath(Event event, char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(GetEventInt(event, "userid"));
	int attacker = GetClientOfUserId(GetEventInt(event, "attacker"));

	if(g_eCvars[g_cvarSaveOnDeath].aCache)
	{
		Store_SaveClientData(victim);
		Store_SaveClientInventory(victim);
		Store_SaveClientEquipment(victim);
	}

	if(!attacker || victim == attacker || !IsClientInGame(attacker) || IsFakeClient(attacker))
		return Plugin_Continue;

	if(g_eCvars[g_cvarCreditAmountKill].aCache)
	{
		//g_eClients[attacker][iCredits] += g_eCvars[g_cvarCreditAmountKill].aCache;
		g_eClients[attacker].iCredits += GetMultipliedCredits(attacker, g_eCvars[g_cvarCreditAmountKill].aCache);
		if(g_eCvars[g_cvarCreditMessages].aCache)
		{
			//Chat(attacker, "%t", "Credits Earned For Killing", g_eCvars[g_cvarCreditAmountKill].aCache, g_eClients[victim].szName_Client);
			//NotifyToChat(attacker, "%s%t", g_sChatPrefix, "Credits Earned For Killing", g_eCvars[g_cvarCreditAmountKill].aCache, g_eClients[victim].szName_Client);
			#if defined _clientmod_included
				MC_PrintToChat(attacker, "%s%t", g_sChatPrefix, "Credits Earned For Killing", g_eCvars[g_cvarCreditAmountKill].aCache, g_eClients[victim].szName_Client);
				C_PrintToChat(attacker, "%s%t", g_sChatPrefix, "Credits Earned For Killing", g_eCvars[g_cvarCreditAmountKill].aCache, g_eClients[victim].szName_Client);
			#else
				PrintToChat(attacker, "%s%t", g_sChatPrefix, "Credits Earned For Killing", g_eCvars[g_cvarCreditAmountKill].aCache, g_eClients[victim].szName_Client);
			#endif
		}
		Store_LogMessage(attacker, g_eCvars[g_cvarCreditAmountKill].aCache, "Earned for killing");
	}
		
	return Plugin_Continue;
}

public Action Event_PlayerSpawn(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!IsClientInGame(client))
		return Plugin_Continue;

#if !defined STANDALONE_BUILD
	//Health_OnPlayerSpawn(client);
#endif
		
	return Plugin_Continue;
}

public Action OnClientChangeName(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsClientConnected(client) || IsFakeClient(client))
		return Plugin_Continue;
	if (IsClientConnected(client))
	{
		char clientnewname[MAX_NAME_LENGTH];
		GetEventString(event, "newname", clientnewname, sizeof(clientnewname));
		char Eclientnewname[MAX_NAME_LENGTH * 2 + 1];
		SQL_EscapeString(g_hDatabase, clientnewname, Eclientnewname, sizeof(Eclientnewname));
		
		char query[10000];
		{
			Format(query, sizeof(query), "UPDATE `store_players` SET name='%s' WHERE authid = '%s';", Eclientnewname, g_eClients[client].szAuthId);
			
			SQL_TQuery(g_hDatabase, SQLCallback_NoError, query);
		}
	}
	return Plugin_Continue;
}
