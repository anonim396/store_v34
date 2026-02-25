void Store_Commands_OnPluginStart()
{
	// Register Commands
	RegConsoleCmd("sm_store", Command_Store);
	RegConsoleCmd("sm_shop", Command_Store);
	RegConsoleCmd("sm_inv", Command_Inventory);
	RegConsoleCmd("sm_inventory", Command_Inventory);
	RegConsoleCmd("sm_gift", Command_Gift);
	RegConsoleCmd("sm_givecredits", Command_GiveCredits);
	RegConsoleCmd("sm_resetplayer", Command_ResetPlayer);
	RegConsoleCmd("sm_rsloadout", Command_ResetLoadout);
	RegConsoleCmd("sm_credits", Command_Credits);
	RegServerCmd("sm_store_custom_credits", Command_CustomCredits);
	
	RegAdminCmd("sm_store_reloadconfig", Command_ReloadConfig, ADMFLAG_ROOT);
	
	// Add a say command listener for shortcuts
	AddCommandListener(Command_Say, "say");
	AddCommandListener(Command_Say, "say_team");
}

//////////////////////////////////
//			COMMANDS	 		//
//////////////////////////////////

public Action Command_Say(int client, const char[] command,int argc)
{
	if(argc > 0)
	{		
		if(!client || !IsClientInGame(client))
			return Plugin_Continue;
		
		char m_szArg[256];
		GetCmdArg(1, STRING(m_szArg));
		
		// g_iPublicChatTrigger
		if(m_szArg[0] == '!' || m_szArg[0] == '/')
		{
			char shortcut[64];
			strcopy(shortcut, sizeof(shortcut), m_szArg[1]);
			TrimString(shortcut);
			
			int foundCategory = -1;
			for(int i = 0; i < g_iItems; ++i)
			{
				if((g_eItems[i].iPrice == -1 || g_eItems[i].iHandler == g_iPackageHandler) &&
				   strlen(g_eItems[i].szShortcut) > 0 &&
				   StrEqual(g_eItems[i].szShortcut, shortcut, false))
				{
					foundCategory = i;
					break;
				}
			}
			
			if(foundCategory == -1)
			{
				for(int i = 0; i < g_iItems; ++i)
				{
					if(strlen(g_eItems[i].szShortcut) > 0 &&
					   StrEqual(g_eItems[i].szShortcut, shortcut, false))
					{
						foundCategory = i;
						break;
					}
				}
			}
			
			if(foundCategory != -1)
			{
				g_bInvMode[client] = false;
				g_iMenuClient[client] = client;
				
				if(g_eItems[foundCategory].iPrice == -1 || 
				   g_eItems[foundCategory].iHandler == g_iPackageHandler)
				{
					DisplayStoreMenu(client, foundCategory);
				}
				else
				{
					if(g_eItems[foundCategory].iParent != -1)
					{
						DisplayStoreMenu(client, g_eItems[foundCategory].iParent);
					}
					else
					{
						DisplayStoreMenu(client);
					}
				}
				// Plugin_Continue so the chat message (e.g. !shop) stays visible
				return Plugin_Continue;
			}
			else
			{
				//PrintToServer("[Store DEBUG] Shortcut '%s' not found", shortcut);
			}
		}
	}
	
	return Plugin_Continue;
}

public Action Command_Store(int client,int params)
{
	if(!client || !IsValidClient(client))
			return Plugin_Continue;

	if(g_eCvars[g_cvarRequiredFlag].aCache && !GetClientPrivilege(client, g_eCvars[g_cvarRequiredFlag].aCache))
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "You dont have permission CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "You dont have permission");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "You dont have permission");
		#endif
		return Plugin_Handled;
	}
	
	if((g_eClients[client].iCredits == -1 && g_eClients[client].iItems == -1) || !g_eClients[client].bLoaded)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Inventory hasnt been fetched CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Inventory hasnt been fetched");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Inventory hasnt been fetched");
		#endif
		return Plugin_Handled;
	}
	
	char itemname[64];
	GetCmdArg(1, itemname, sizeof(itemname));
	
	//if(itemname[0] == '$')
	//{
	//strcopy(itemname, sizeof(itemname), itemname);
	//Store_ItemName(client, itemname);
	//}
	
	if(params > 0)
	{
		Store_ItemName(client, itemname);
	}
	
	if(params == 0)
	{
		g_bInvMode[client]=false;
		g_iMenuClient[client]=client;
		DisplayStoreMenu(client);
	}
	
	return Plugin_Handled;
}


public Action Command_Inventory(int client,int params)
{
	if(!client || !IsValidClient(client))
			return Plugin_Continue;

	if(g_eCvars[g_cvarRequiredFlag].aCache && !GetClientPrivilege(client, g_eCvars[g_cvarRequiredFlag].aCache))
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "You dont have permission CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "You dont have permission");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "You dont have permission");
		#endif
		return Plugin_Handled;
	}
	
	if((g_eClients[client].iCredits == -1 && g_eClients[client].iItems == -1) || !g_eClients[client].bLoaded)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Inventory hasnt been fetched CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Inventory hasnt been fetched");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Inventory hasnt been fetched");
		#endif
		return Plugin_Handled;
	}
	
	g_bInvMode[client]=true;
	g_iMenuClient[client]=client;
	DisplayStoreMenu(client);
	
	return Plugin_Handled;
}


public Action Command_Gift(int client,int params)
{
	if(!client || !IsValidClient(client))
			return Plugin_Continue;

	if(!g_eCvars[g_cvarCreditGiftEnabled].aCache)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Gift Disabled CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Credit Gift Disabled");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Credit Gift Disabled");
		#endif

		return Plugin_Handled;
	}
	
	char m_szTmp[64];
	GetCmdArg(2, STRING(m_szTmp));
	
	int m_iCredits = StringToInt(m_szTmp);
	if(g_eClients[client].iCredits<m_iCredits || m_iCredits<=0)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Invalid Amount CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Credit Invalid Amount");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Credit Invalid Amount");
		#endif		
		return Plugin_Handled;
	}
	
	bool m_bTmp;
	int m_iTargets[1];
	GetCmdArg(1, STRING(m_szTmp));
	
	int m_clients = ProcessTargetString(m_szTmp, 0, m_iTargets, 1, 0, STRING(m_szTmp), m_bTmp);
	if(m_clients>2)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Too Many Matches CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Credit Too Many Matches");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Credit Too Many Matches");
		#endif
		return Plugin_Handled;
	}
	
	if(m_clients != 1)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit No Match CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Credit No Match");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Credit No Match");
		#endif
		return Plugin_Handled;
	}
	
	int m_iReceiver = m_iTargets[0];
	
	g_eClients[client].iCredits -= m_iCredits;
	g_eClients[m_iReceiver].iCredits += m_iCredits;
	
	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Gift Sent CM", m_iCredits, g_eClients[m_iReceiver].szName_Client);
		C_PrintToChat(client, "%s %t", g_sChatPrefix, "Credit Gift Sent", m_iCredits, g_eClients[m_iReceiver].szName_Client);
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix, "Credit Gift Sent", m_iCredits, g_eClients[m_iReceiver].szName_Client);
	#endif
	#if defined _clientmod_included
		MC_PrintToChat(m_iReceiver, "%s %t", g_sChatPrefix_CM, "Credit Gift Received CM", m_iCredits, g_eClients[client].szName_Client);
		C_PrintToChat(m_iReceiver, "%s %t", g_sChatPrefix, "Credit Gift Received", m_iCredits, g_eClients[client].szName_Client);
	#else
		PrintToChat(m_iReceiver, "%s %t", g_sChatPrefix, "Credit Gift Received", m_iCredits, g_eClients[client].szName_Client);
	#endif
	
	Store_LogMessage(m_iReceiver, m_iCredits, "Gifted by %N", client);
	Store_LogMessage(client, -m_iCredits, "Gifted to %N", m_iReceiver);
	
	return Plugin_Handled;
}

public Action Command_GiveCredits(int client,int params)
{
	if(!client || !IsValidClient(client))
			return Plugin_Continue;

	if(client && !GetClientPrivilege(client, g_eCvars[g_cvarAdminFlag].aCache))
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "You dont have permission CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "You dont have permission");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "You dont have permission");
		#endif
		return Plugin_Handled;
	}
	
	char m_szTmp[64];
	if(!GetCmdArg(2, STRING(m_szTmp)))
	ReplyToCommand(client, "%sUsage: sm_givecredits <target> <credits>", g_sChatPrefix);
	
	int m_iCredits = StringToInt(m_szTmp);
	
	bool m_bTmp;
	int m_iTargets[1];
	GetCmdArg(1, STRING(m_szTmp));
	
	int m_iReceiver = -1;
	if(strncmp(m_szTmp, "STEAM_", 6)==0)
	{
		m_iReceiver = GetClientBySteamID(m_szTmp);
		// SteamID is not ingame
		if(m_iReceiver == 0)
		{
			char m_szQuery[512];
			char driver[12];
			SQL_ReadDriver(g_hDatabase, STRING(driver));
			if(driver[0] == 'm') // mysql
			SQL_FormatQuery(g_hDatabase, STRING(m_szQuery), "INSERT IGNORE INTO store_players (authid, credits) VALUES ('%s', %d) ON DUPLICATE KEY UPDATE credits=credits+%d", m_szTmp[8], m_iCredits, m_iCredits);
			else if(driver[0] == 'p') // postgresql
			{
				// PostgreSQL использует ON CONFLICT для обработки дубликатов
				SQL_FormatQuery(g_hDatabase, STRING(m_szQuery), 
					"INSERT INTO store_players (authid, credits) VALUES ('%s', %d) " ...
					"ON CONFLICT (authid) DO UPDATE SET credits = store_players.credits + %d", 
					m_szTmp[8], m_iCredits, m_iCredits);
			}
			else // sqlite
			{
				SQL_FormatQuery(g_hDatabase, STRING(m_szQuery), "INSERT OR IGNORE INTO store_players (authid) VALUES ('%s')", m_szTmp[8]);
				SQL_TVoid(g_hDatabase, m_szQuery);
				SQL_FormatQuery(g_hDatabase, STRING(m_szQuery), "UPDATE store_players SET credits=credits+%d WHERE authid='%s'", m_iCredits, m_szTmp[8]);
			}
			SQL_TVoid(g_hDatabase, m_szQuery);
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i))
					continue;

				#if defined _clientmod_included
					MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "Credits Given CM", m_szTmp[8], m_iCredits);
					C_PrintToChat(i, "%s %t", g_sChatPrefix, "Credits Given", m_szTmp[8], m_iCredits);
				#else
					PrintToChat(i, "%s %t", g_sChatPrefix, "Credits Given", m_szTmp[8], m_iCredits);
				#endif
			}
			m_iReceiver = -1;
		}
	} 
	else if(strcmp(m_szTmp, "@all")==0)
	{
		LoopIngamePlayers(i)
		{
			//FakeClientCommandEx(client, "sm_givecredits \"%N\" %d", i, m_iCredits);
			AdminGiveCredits(i, m_iCredits);
		}
	} 
	else if(strcmp(m_szTmp, "@t")==0 || strcmp(m_szTmp, "@red")==0)
	{
		LoopIngamePlayers(i)
		if(GetClientTeam(i)==2)
		{
			//FakeClientCommandEx(client, "sm_givecredits \"%N\" %d", i, m_iCredits);
			AdminGiveCredits(i, m_iCredits);
		}
	} 
	else if(strcmp(m_szTmp, "@ct")==0 || strcmp(m_szTmp, "@blu")==0)
	{
		LoopIngamePlayers(i)
		if(GetClientTeam(i)==3)
		{
			//FakeClientCommandEx(client, "sm_givecredits \"%N\" %d", i, m_iCredits);
			AdminGiveCredits(i, m_iCredits);
		}
	}
	else
	{
		int m_clients = ProcessTargetString(m_szTmp, 0, m_iTargets, 1, 0, STRING(m_szTmp), m_bTmp);
		if(m_clients>2)
		{
			if(client)
			{
				#if defined _clientmod_included
					MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Too Many Matches CM");
					C_PrintToChat(client, "%s %t", g_sChatPrefix, "Credit Too Many Matches");
				#else
					PrintToChat(client, "%s %t", g_sChatPrefix, "Credit Too Many Matches");
				#endif
			}
			else
			ReplyToCommand(client, "%t", "Credit Too Many Matches");
			return Plugin_Handled;
		} else if(m_clients != 1)
		{
			if(client)
			{
				#if defined _clientmod_included
					MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit No Match CM");
					C_PrintToChat(client, "%s %t", g_sChatPrefix, "Credit No Match");
				#else
					PrintToChat(client, "%s %t", g_sChatPrefix, "Credit No Match");
				#endif
			}
			else
			ReplyToCommand(client, "%t", "Credit No Match");
			return Plugin_Handled;
		}
		
		m_iReceiver = m_iTargets[0];
	}
	
	// The player is on the server
	if(m_iReceiver != -1)
	{
		g_eClients[m_iReceiver].iCredits += m_iCredits;
		if(g_eCvars[g_cvarSilent].aCache == 1)
		{
			if(client)
			{
				#if defined _clientmod_included
					MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credits Given CM", g_eClients[m_iReceiver].szName_Client, m_iCredits);
					C_PrintToChat(client, "%s %t", g_sChatPrefix, "Credits Given", g_eClients[m_iReceiver].szName_Client, m_iCredits);
				#else
					PrintToChat(client, "%s %t", g_sChatPrefix, "Credits Given", g_eClients[m_iReceiver].szName_Client, m_iCredits);
				#endif
			}
			else
			ReplyToCommand(client, "%t", "Credits Given", g_eClients[m_iReceiver].szName_Client, m_iCredits);
			#if defined _clientmod_included
				MC_PrintToChat(m_iReceiver, "%s %t", g_sChatPrefix_CM, "Credits Given CM", g_eClients[m_iReceiver].szName_Client, m_iCredits);
				C_PrintToChat(m_iReceiver, "%s %t", g_sChatPrefix, "Credits Given", g_eClients[m_iReceiver].szName_Client, m_iCredits);
			#else
				PrintToChat(m_iReceiver, "%s %t", g_sChatPrefix, "Credits Given", g_eClients[m_iReceiver].szName_Client, m_iCredits);
			#endif
		}
		else if(g_eCvars[g_cvarSilent].aCache == 0)
		{
			for (int i = 1; i <= MaxClients; i++)
			{
				if (!IsClientInGame(i))
					continue;

				#if defined _clientmod_included
					MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "Credits Given CM", g_eClients[m_iReceiver].szName_Client, m_iCredits);
					C_PrintToChat(i, "%s %t", g_sChatPrefix, "Credits Given", g_eClients[m_iReceiver].szName_Client, m_iCredits);
				#else
					PrintToChat(i, "%s %t", g_sChatPrefix, "Credits Given", g_eClients[m_iReceiver].szName_Client, m_iCredits);
				#endif
			}
		}
		Store_LogMessage(m_iReceiver, m_iCredits, "Given by Admin");
		
		Store_SaveClientData(m_iReceiver);
		Store_SaveClientInventory(m_iReceiver);
		Store_SaveClientEquipment(m_iReceiver);
	}
	
	
	return Plugin_Handled;
}

public Action Command_ResetPlayer(int client,int params)
{
	if(!client || !IsValidClient(client))
			return Plugin_Continue;

	if(client && !GetClientPrivilege(client, g_eCvars[g_cvarAdminFlag].aCache))
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "You dont have permission CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "You dont have permission");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "You dont have permission");
		#endif
		return Plugin_Handled;
	}
	
	char m_szTmp[64];
	bool m_bTmp;
	int m_iTargets[1];
	GetCmdArg(1, STRING(m_szTmp));
	
	int m_iReceiver = -1;
	if(strncmp(m_szTmp, "STEAM_", 6)==0)
	{
		m_iReceiver = GetClientBySteamID(m_szTmp);
		// SteamID is not ingame
		if(m_iReceiver == 0)
		{
			char m_szQuery[512];
			SQL_FormatQuery(g_hDatabase, STRING(m_szQuery), "SELECT id, authid FROM store_players WHERE authid='%s'", m_szTmp[9]);
			SQL_TQuery(g_hDatabase, SQLCallback_ResetPlayer, m_szQuery, g_eClients[client].iUserId);
		}
	}
	else
	{	
		int m_clients = ProcessTargetString(m_szTmp, 0, m_iTargets, 1, 0, STRING(m_szTmp), m_bTmp);
		if(m_clients>2)
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Too Many Matches CM");
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "Credit Too Many Matches");
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "Credit Too Many Matches");
			#endif
			return Plugin_Handled;
		}
		
		if(m_clients != 1)
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit No Match CM");
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "Credit No Match");
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "Credit No Match");
			#endif
			return Plugin_Handled;
		}
		
		m_iReceiver = m_iTargets[0];
	}
	
	// The player is on the server
	if(m_iReceiver != -1)
	{
		Store_LogMessage(client, -g_eClients[m_iReceiver].iCredits, "Player resetted");
		g_eClients[m_iReceiver].iCredits = 0;
		for (int i = 0; i < g_eClients[m_iReceiver].iItems; ++i)
			Store_RemoveItem(m_iReceiver, g_eClientItems[m_iReceiver][i].iUniqueId);
		g_eClients[m_iReceiver].iItems = 0;

		// Sync DB: zero credits and remove items/equipment so toplists stay correct
		char m_szQuery[512];
		int pid = g_eClients[m_iReceiver].iId_Client;
		Format(STRING(m_szQuery), "UPDATE store_players SET credits=0 WHERE id=%d", pid);
		SQL_TVoid(g_hDatabase, m_szQuery);
		Format(STRING(m_szQuery), "DELETE FROM store_items WHERE player_id=%d", pid);
		SQL_TVoid(g_hDatabase, m_szQuery);
		Format(STRING(m_szQuery), "DELETE FROM store_equipment WHERE player_id=%d", pid);
		SQL_TVoid(g_hDatabase, m_szQuery);

		Modules_OnPlayerReset(m_iReceiver);

		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i))
				continue;

			#if defined _clientmod_included
				MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "Player Resetted CM", g_eClients[m_iReceiver].szName_Client);
				C_PrintToChat(i, "%s %t", g_sChatPrefix, "Player Resetted", g_eClients[m_iReceiver].szName_Client);
			#else
				PrintToChat(i, "%s %t", g_sChatPrefix, "Player Resetted", g_eClients[m_iReceiver].szName_Client);
			#endif
		}
	}
	
	return Plugin_Handled;
}

public Action Command_Credits(int client,int params)
{	
	if(!client || !IsValidClient(client))
			return Plugin_Continue;

	if(g_eClients[client].iCredits == -1 && g_eClients[client].iItems == -1)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Inventory hasnt been fetched CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Inventory hasnt been fetched");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Inventory hasnt been fetched");
		#endif
		return Plugin_Handled;
	}
	
	if(g_iSpam[client]<GetTime())
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i))
				continue;

			#if defined _clientmod_included
				MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "Player Credits CM", g_eClients[client].szName_Client, g_eClients[client].iCredits);
				C_PrintToChat(i, "%s %t", g_sChatPrefix, "Player Credits", g_eClients[client].szName_Client, g_eClients[client].iCredits);
			#else
				PrintToChat(i, "%s %t", g_sChatPrefix, "Player Credits", g_eClients[client].szName_Client, g_eClients[client].iCredits);
			#endif
		}
		g_iSpam[client] = GetTime()+12;
		//g_iSpam[client] = GetTime()+ g_cvarCredits.FloatValue;
	}
	
	return Plugin_Handled;
}

public Action Command_CustomCredits(int params)
{
	if(params < 2)
	{
		PrintToServer("sm_store_custom_credits [flag] [multiplier]");
		return Plugin_Handled;
	}
	
	char tmp[16];
	GetCmdArg(1, STRING(tmp));
	char flag = ReadFlagString(tmp);
	GetCmdArg(2, STRING(tmp));
	float mult = StringToFloat(tmp);
	
	any size = GetArraySize(g_hCustomCredits);
	int index = -1;
	for(int i=0;i<size;++i)
	{
		int sflag = GetArrayCell(g_hCustomCredits, i, 0);
		if(sflag == flag)
		{
			index = i;
			break;
		}
	}
	
	if(index == -1)
	{
		index = PushArrayCell(g_hCustomCredits, flag);
	}
	
	SetArrayCell(g_hCustomCredits, index, mult, 1);
	
	return Plugin_Handled;
}

public Action Command_ReloadConfig(int client, int args)
{
	if(!client || !IsValidClient(client))
			return Plugin_Continue;

	if(g_eCvars[g_cvarConfirmation].aCache)
	{
		char buffer[128];
		if(!g_eCvars[gc_iReloadType].aCache)
		Format(buffer, sizeof(buffer), "%t", "confirm_reload_type_0", view_as<int>(g_eCvars[gc_iReloadDelay].aCache));
		else Format(buffer, sizeof(buffer), "%t", "confirm_reload_type_1");
		Store_DisplayConfirmMenu(client, buffer, FakeMenuHandler_StoreReloadConfig, 0);
	}
	else
	{
		Store_ReloadConfig();
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Config reloaded. Please restart or change map");
	}
	
	return Plugin_Handled;
}

public Action Command_ResetLoadout(int client, int args)
{
	if(!client || !IsValidClient(client))
			return Plugin_Continue;
	
	if((g_eClients[client].iCredits == -1 && g_eClients[client].iItems == -1) || !g_eClients[client].bLoaded)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Inventory hasnt been fetched CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Inventory hasnt been fetched");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Inventory hasnt been fetched");
		#endif
		return Plugin_Handled;
	}
	else
	{
		char sBuffer[128];
		Format(sBuffer, sizeof(sBuffer), "%t", "Store Confirm Reset Loadout");
		Store_DisplayConfirmMenu(client, sBuffer, FakeMenuHandler_StoreResetLoadout, 0);
	}
	
	return Plugin_Handled;
}