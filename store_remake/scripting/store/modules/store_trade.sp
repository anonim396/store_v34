#if STORE_MODULE_TRADE

#define STORE_TRADE_MAX_OFFERS 16	//	Usermessage may not be able to hold more at a time

int g_cvarTradeEnabled = -1;
int g_cvarTradeCooldown = -1;
int g_cvarTradeReadyDelay = -1;

bool g_bReady[MAXPLAYERS+1] = {false, ...};
bool g_bMenuOpen[MAXPLAYERS+1] = {false, ...};

int g_iTraders[MAXPLAYERS+1] = {0, ...};
int g_iOfferedCredits[MAXPLAYERS+1] = {0, ...};
int g_iOffers[MAXPLAYERS+1][STORE_TRADE_MAX_OFFERS];
int g_iTradeCooldown[MAXPLAYERS+1] = {0, ...};

Handle g_hReadyTimers[MAXPLAYERS+1] = {INVALID_HANDLE};

void Trade_OnPluginStart()
{
	g_cvarTradeEnabled = RegisterConVar("sm_store_trade_enabled", "1", "Enable/disable the Store trade system", TYPE_INT);
	g_cvarTradeCooldown = RegisterConVar("sm_store_trade_cooldown", "300", "Time in seconds between trade ATTEMPTS", TYPE_INT);
	g_cvarTradeReadyDelay = RegisterConVar("sm_store_trade_ready_delay", "5", "Time in seconds before finishing trade", TYPE_INT);
	Store_BeginModuleConfig("sourcemod/store", "trade");
	STORE_CFG("sm_store_trade_enabled", "1");
	STORE_CFG("sm_store_trade_cooldown", "300");
	STORE_CFG("sm_store_trade_ready_delay", "5");
	Store_EndModuleConfig("sourcemod/store", "trade");

	for (int i = 0; i <= MaxClients; i++)
	{
		g_bReady[i] = false;
		g_bMenuOpen[i] = false;
		g_iTraders[i] = 0;
		g_iOfferedCredits[i] = 0;
		g_iTradeCooldown[i] = 0;
		g_hReadyTimers[i] = INVALID_HANDLE;
		for (int j = 0; j < STORE_TRADE_MAX_OFFERS; j++)
		{
			g_iOffers[i][j] = -1;
		}
	}

	Store_RegisterMenuHandler("trade", Trade_OnMenu, Trade_OnHandler);

	LoadTranslations("store.phrases");
	LoadTranslations("store-trade.phrases");

	RegConsoleCmd("sm_trade", Command_Trade);
	RegConsoleCmd("sm_offer", Command_Offer);

	CreateTimer(1.0, Timer_ShowPartnerMenu, _, TIMER_REPEAT);
}

void Trade_OnClientConnected(int client)
{
	g_iTradeCooldown[client] = 0;
	ResetTrade(client);
}

void Trade_OnClientDisconnect(int client)
{
	int target = GetClientOfUserId(g_iTraders[client]);
	if(target && IsClientInGame(target))
		ResetTrade(target);
	ResetTrade(client);
}

public Action Timer_ShowPartnerMenu(Handle timer, any data)
{
	LoopIngamePlayers(i)
	{
		if(!g_iTraders[i])
			continue;
		DisplayPartnerMenu(i);
	}
	return Plugin_Continue;
}

//////////////////////////////
//			COMMANDS 		//
//////////////////////////////

public Action Command_Offer(int client, int args)
{
	if(!g_iTraders[client])
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Trade Not Active CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Trade Not Active");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Trade Not Active");
		#endif
		return Plugin_Handled;
	}

	char m_szCredits[11];
	GetCmdArg(1, STRING(m_szCredits));

	int m_iCredits = StringToInt(m_szCredits);
	if(m_iCredits < 0 || Store_GetClientCredits(client) < m_iCredits)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Invalid Amount CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Credit Invalid Amount");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Credit Invalid Amount");
		#endif
		return Plugin_Handled;
	}

	g_iOfferedCredits[client]=m_iCredits;
	g_bReady[client] = false;
	DisplayTradeMenu(client);

	return Plugin_Handled;
}

public Action Command_Trade(int client, int args)
{
	if(g_iTraders[client])
	{
		DisplayTradeMenu(client);
		return Plugin_Handled;
	}

	if(g_iTradeCooldown[client] > GetTime())
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Trade Cooldown CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Trade Cooldown");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Trade Cooldown");
		#endif
		return Plugin_Handled;
	}

	Handle m_hMenu = CreateMenu(MenuHandler_SelectPlayer);
	SetMenuTitle(m_hMenu, "%t", "Trade Select Player");

	char m_szUserId[11];
	char m_szClientName[64];
	LoopIngamePlayers(i)
	{
		if(i == client)
			continue;
		if(g_iTraders[i])
			continue;
		if(!Store_IsClientLoaded(i))
			continue;

		IntToString(GetClientUserId(i), STRING(m_szUserId));
		GetClientName(i, STRING(m_szClientName));
		AddMenuItem(m_hMenu, m_szUserId, m_szClientName);
	}
	DisplayMenu(m_hMenu, client, 0);

	return Plugin_Handled;
}

//////////////////////////////
//		 STORE TRADE		//
//////////////////////////////

public void ResetTrade(int client)
{
	if (client <= 0 || client > MaxClients)
		return;

	int target = GetClientOfUserId(g_iTraders[client]);

	g_bReady[client] = false;
	g_iTraders[client] = 0;
	g_iOfferedCredits[client] = 0;

	ClearReadyTimerForClient(client);

	if (target > 0 && target <= MaxClients)
	{
		ClearReadyTimerForClient(target);
	}

	for (int i = 0; i < STORE_TRADE_MAX_OFFERS; ++i)
	{
		g_iOffers[client][i] = -1;
	}

	#if defined _clientmod_included
		CM_PrintKeyHintText(client, "");
	#else
		PrintCenterText(client, "");
	#endif
}

public int MenuHandler_SelectPlayer(Handle menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		char m_szUserId[11];
		GetMenuItem(menu, param2, STRING(m_szUserId));
		int target = GetClientOfUserId(StringToInt(m_szUserId));
		if(!target || !IsClientInGame(target))
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Player left CM");
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "Player left");
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "Player left");
			#endif
			Command_Trade(client, 0);
			return 0;
		}

		g_iTradeCooldown[client] = GetTime() + g_eCvars[g_cvarTradeCooldown].aCache;
		g_iTraders[client] = GetClientUserId(target);
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Waiting for confirmation CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Waiting for confirmation");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Waiting for confirmation");
		#endif
		Handle m_hMenu = CreateMenu(MenuHandler_InitTrade);
		SetMenuTitle(m_hMenu, "%t", "Trade Confirm", client);
		SetMenuExitButton(m_hMenu, false);
		AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "yes", "%t", "Confirm_Yes");
		AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "no",  "%t", "Confirm_No");
		DisplayMenu(m_hMenu, target, 30);
	}

	return 0;
}

public int MenuHandler_InitTrade(Handle menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
	{
		CloseHandle(menu);
		return 0;
	}

	if (action == MenuAction_Cancel && g_iTraders[client] == 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (g_iTraders[i] == GetClientUserId(client))
			{
				#if defined _clientmod_included
					MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "Trade Refused CM", client);
					C_PrintToChat(i, "%s %t", g_sChatPrefix, "Trade Refused", client);
				#else
					PrintToChat(i, "%s %t", g_sChatPrefix, "Trade Refused", client);
				#endif
				g_iTraders[i] = 0;
			}
		}
		return 0;
	}

	else if (action == MenuAction_Select)
	{
		int target = 0;
		for(int i=1;i<=MaxClients;++i)
		{
			if(g_iTraders[i] == GetClientUserId(client))
			{
				target = i;
				break;
			}
		}

		if(target == 0)
			return 0;

		if(param2 == 1)
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Trade Refused CM", client);
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "Trade Refused", client);
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "Trade Refused", client);
			#endif
			return 0;
		}

		if(!target)
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Player left CM");
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "Player left");
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "Player left");
			#endif
			return 0;
		}

		g_iTraders[client] = GetClientUserId(target);

		g_bReady[client]=false;
		g_bReady[target]=false;

		DisplayTradeMenu(client);
		DisplayTradeMenu(target);
	}

	return 0;
}

public void DisplayTradeMenu(int client)
{
	int target = GetClientOfUserId(g_iTraders[client]);
	if(!target || !IsClientInGame(target))
		return;

	g_bMenuOpen[client] = true;

	Handle m_hMenu = CreateMenu(MenuHandler_Trade);
	SetMenuTitle(m_hMenu, "%t", "Trade Title", target, g_iOfferedCredits[client]);
	AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "ready", "%t", "Ready", (g_bReady[client]?"X":" "));
	AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "cancel", "%t", "Cancel");
	AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "offer", "%t\n\n\n", "Offer");

	Store_Item m_eItem;
	Type_Handler m_eHandler;
	char m_szItemID[11];

	for(int i=0;i<STORE_TRADE_MAX_OFFERS;++i)
	{
		if(g_iOffers[client][i] == -1)
			continue;
		Store_GetItem(g_iOffers[client][i], m_eItem);
		Store_GetHandler(m_eItem.iHandler, m_eHandler);

		IntToString(g_iOffers[client][i], STRING(m_szItemID));
		AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, m_szItemID, "%s %s", m_eItem.szName, m_eHandler.szType);
	}

	DisplayMenu(m_hMenu, client, 0);
}

public void DisplayPartnerMenu(int client)
{
	int target = GetClientOfUserId(g_iTraders[client]);
	if(!target || !IsClientInGame(target))
		return;

	if(g_iTraders[target] == 0)
		return;

	bool m_bRedisplay = false;
	bool m_bRedisplayTarget = false;
	if(g_iOfferedCredits[client] > Store_GetClientCredits(client))
	{
		g_iOfferedCredits[client] = 0;
		g_bReady[client] = false;
		m_bRedisplay = true;
	}

	if(!g_bMenuOpen[client])
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Trade menu CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Trade menu");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Trade menu");
		#endif
	}

	char m_szMessage[256];
	int idx = 0;
	idx += Format(m_szMessage[idx], sizeof(m_szMessage)-idx, "%t\n\n", (g_bReady[target]?"Partner Ready":"Partner Not Ready"));
	idx += Format(m_szMessage[idx], sizeof(m_szMessage)-idx, "%t\n\n", "Partner Credit Offer", g_iOfferedCredits[target]);
	idx += Format(m_szMessage[idx], sizeof(m_szMessage)-idx, "%t\n\n", "Partner Item Offer");

	Store_Item m_eItem;
	Type_Handler m_eHandler;

	int index = 0;
	for(int i=0;i<STORE_TRADE_MAX_OFFERS;++i)
	{
		if(g_iOffers[target][i] == -1)
			continue;
		if(!Store_HasClientItem(target, g_iOffers[target][i]))
		{
			g_iOffers[target][i] = -1;
			g_bReady[target] = false;
			m_bRedisplayTarget = true;
			continue;
		}
		Store_GetItem(g_iOffers[target][i], m_eItem);
		Store_GetHandler(m_eItem.iHandler, m_eHandler);
		idx += Format(m_szMessage[idx], sizeof(m_szMessage)-idx, "%d. %s %s\n", ++index, m_eItem.szName, m_eHandler.szType);
	}

	if(m_bRedisplay)
		DisplayTradeMenu(client);
	if(m_bRedisplayTarget)
		DisplayTradeMenu(target);

	#if defined _clientmod_included
		CM_PrintKeyHintText(client, m_szMessage);
	#else
		PrintCenterText(client, m_szMessage);
	#endif
}

public int MenuHandler_Trade(Handle menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
	{
		if (client > 0 && client <= MaxClients)
			g_bMenuOpen[client] = false;
		CloseHandle(menu);
	}
	else if (action == MenuAction_Cancel)
	{
	}
	else if (action == MenuAction_Select)
	{
		if(param2 == 0)
		{
			g_bReady[client] = !g_bReady[client];
			DisplayTradeMenu(client);

			int target = GetClientOfUserId(g_iTraders[client]);

			if(g_bReady[client] && g_bReady[target])
			{
				g_hReadyTimers[client] = CreateTimer(0.0, Timer_ReadyTimer, g_eCvars[g_cvarTradeReadyDelay].aCache);
				g_hReadyTimers[target] = g_hReadyTimers[client];
			}
			else if(g_hReadyTimers[client] != INVALID_HANDLE)
			{
				ClearReadyTimerForClient(g_hReadyTimers[client]);
				g_hReadyTimers[client] = INVALID_HANDLE;
				g_hReadyTimers[target] = INVALID_HANDLE;
			}
		}
		else if(param2 == 1)
		{
			if(Store_ShouldConfirm())
			{
				Handle m_hMenu = CreateMenu(MenuHandler_Cancel);
				SetMenuTitle(m_hMenu, "%t", "Trade Confirm Cancel", client);
				SetMenuExitButton(m_hMenu, false);
				AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "yes", "%t", "Confirm_Yes");
				AddMenuItemEx(m_hMenu, ITEMDRAW_DEFAULT, "no",  "%t", "Confirm_No");
				DisplayMenu(m_hMenu, client, 0);
			}
			else
			{
				MenuHandler_Cancel(INVALID_HANDLE, MenuAction_Select, client, 0);
			}
		} else if(param2 == 2)
		{
			FakeClientCommandEx(client, "sm_inventory");
		}
		else
		{
			char m_szItemId[11];
			GetMenuItem(menu, param2, STRING(m_szItemId));
			int m_iItemID = StringToInt(m_szItemId);

			for(int i=0;i<STORE_TRADE_MAX_OFFERS;++i)
			{
				if(g_iOffers[client][i] == m_iItemID)
				{
					g_iOffers[client][i] = -1;
					break;
				}
			}
			DisplayTradeMenu(client);
		}
	}

	return 0;
}

public Action Timer_ReadyTimer(Handle timer, any data)
{
	int client = 0;
	int target = 0;

	for (int i = 1; i <= MaxClients; ++i)
	{
		if (g_hReadyTimers[i] == timer)
		{
			if (client == 0)
				client = i;
			else if (target == 0)
				target = i;
			else
			{
			}
		}
	}

	if (client == 0)
		return Plugin_Continue;

	if (data > 0)
	{
		if (client > 0 && IsClientInGame(client))
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Ready Timer CM", data);
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "Ready Timer", data);
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "Ready Timer", data);
			#endif
		}
		if (target > 0 && IsClientInGame(target))
		{
			#if defined _clientmod_included
				MC_PrintToChat(target, "%s %t", g_sChatPrefix_CM, "Ready Timer CM", data);
				C_PrintToChat(target, "%s %t", g_sChatPrefix, "Ready Timer", data);
			#else
				PrintToChat(target, "%s %t", g_sChatPrefix, "Ready Timer", data);
			#endif
		}

		Handle newTimer = CreateTimer(1.0, Timer_ReadyTimer, data-1);
		if (client > 0)
			g_hReadyTimers[client] = newTimer;
		if (target > 0)
			g_hReadyTimers[target] = newTimer;
	}
	else
	{
		if (client > 0 && IsClientInGame(client) && target > 0 && IsClientInGame(target))
		{
			for (int i = 0; i < STORE_TRADE_MAX_OFFERS; ++i)
			{
				if (g_iOffers[client][i] != -1)
					Store_GiveClientItem(client, target, g_iOffers[client][i]);
				if (g_iOffers[target][i] != -1)
					Store_GiveClientItem(target, client, g_iOffers[target][i]);
			}
			Store_SetClientCredits(client, Store_GetClientCredits(client) + g_iOfferedCredits[target] - g_iOfferedCredits[client]);
			Store_SetClientCredits(target, Store_GetClientCredits(target) + g_iOfferedCredits[client] - g_iOfferedCredits[target]);

			ResetTrade(target);
			ResetTrade(client);

			#if defined _clientmod_included
				MC_PrintToChat(target, "%s %t", g_sChatPrefix_CM, "Trade Successful CM");
				C_PrintToChat(target, "%s %t", g_sChatPrefix, "Trade Successful");
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Trade Successful CM");
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "Trade Successful");
			#else
				PrintToChat(target, "%s %t", g_sChatPrefix, "Trade Successful");
				PrintToChat(client, "%s %t", g_sChatPrefix, "Trade Successful");
			#endif

			if (g_bMenuOpen[client])
				CancelClientMenu(client);
			if (g_bMenuOpen[target])
				CancelClientMenu(target);
		}
		else
		{
			if (client > 0)
				ResetTrade(client);
			if (target > 0)
				ResetTrade(target);
		}
	}

	return Plugin_Continue;
}

public int MenuHandler_Cancel(Handle menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Cancel && g_iTraders[client] == 0)
	{
	}
	else if (action == MenuAction_Select)
	{
		if(param2 == 0)
		{
			ResetTrade(client);
			int target = GetClientOfUserId(g_iTraders[client]);
			if(!target || !IsClientInGame(target))
				return 0;
			ResetTrade(target);
			#if defined _clientmod_included
				MC_PrintToChat(target, "%s %t", g_sChatPrefix_CM, "Trade Cancelled CM");
				C_PrintToChat(target, "%s %t", g_sChatPrefix, "Trade Cancelled");
			#else
				PrintToChat(target, "%s %t", g_sChatPrefix, "Trade Cancelled");
			#endif
		}
		else
			DisplayTradeMenu(client);
	}

	return 0;
}

//////////////////////////////
//		STORE CALLBACKS		//
//////////////////////////////

public void Trade_OnMenu(Handle &menu, int client, int itemid)
{
	int target = Store_GetClientTarget(client);
	if(!Store_IsClientVIP(target) && !Store_IsItemInBoughtPackage(target, itemid) && g_iTraders[client])
	{
		RemoveAllMenuItems(menu);
		AddMenuItemEx(menu, ITEMDRAW_DEFAULT, "add_to_offer", "%t", "Offer item");
	}
	else if(!Store_IsClientVIP(target) && !Store_IsItemInBoughtPackage(target, itemid) && !g_iTraders[client])
	{
		AddMenuItemEx(menu, ITEMDRAW_DEFAULT, "trade_this_item", "%t", "Trade item");
	}
}

public bool Trade_OnHandler(int client, char[] info, int itemid)
{
	if(!g_eCvars[g_cvarTradeEnabled].aCache)
		return false;

	if(strcmp(info, "add_to_offer")==0)
	{
		Store_Item m_eItem;
		Type_Handler m_eHandler;
		Store_GetItem(itemid, m_eItem);
		Store_GetHandler(m_eItem.iHandler, m_eHandler);
		char m_szTitle[128];
		Format(m_szTitle, sizeof(m_szTitle), "%t", "Confirm_Offer_Item", m_eItem.szName, m_eHandler.szType);
		Store_SetClientMenu(client, 2);
		if(Store_ShouldConfirm())
			Store_DisplayConfirmMenu(client, m_szTitle, Trade_MenuHandler, itemid);
		else
			Trade_MenuHandler(INVALID_HANDLE, MenuAction_Select, client, itemid);
	} else if(strcmp(info, "trade_this_item")==0)
	{
		Store_Item m_eItem;
		Type_Handler m_eHandler;
		Store_GetItem(itemid, m_eItem);
		Store_GetHandler(m_eItem.iHandler, m_eHandler);
		char m_szTitle[128];
		Format(m_szTitle, sizeof(m_szTitle), "%t", "Confirm_Trade_Item", m_eItem.szName, m_eHandler.szType);
		Store_SetClientMenu(client, 2);
		if(Store_ShouldConfirm())
			Store_DisplayConfirmMenu(client, m_szTitle, Trade_ConfirmTradeHandler, itemid);
		else
			Trade_ConfirmTradeHandler(INVALID_HANDLE, MenuAction_Select, client, itemid);
	}
	return false;
}

public int Trade_MenuHandler(Handle menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		if(menu == INVALID_HANDLE)
		{
			int target = Store_GetClientTarget(client);
			for(int i=0;i<STORE_TRADE_MAX_OFFERS;++i)
			{
				if(g_iOffers[target][i] == -1)
				{
					g_iOffers[target][i] = param2;
					break;
				}
			}
			g_bReady[target] = false;
			DisplayTradeMenu(target);
		}
	}

	return 0;
}

public int Trade_ConfirmTradeHandler(Handle menu, MenuAction action, int client, int param2)
{
	if(action == MenuAction_Select)
	{
		if(menu == INVALID_HANDLE)
		{
			g_iOffers[client][0] = param2;
			Command_Trade(client, 0);
		}
	}

	return 0;
}

void ClearReadyTimerForClient(int client)
{
	if (client <= 0 || client > MaxClients)
		return;

	if (g_hReadyTimers[client] != INVALID_HANDLE)
	{
		ClearTimer(g_hReadyTimers[client]);
		g_hReadyTimers[client] = INVALID_HANDLE;
	}
}

#else
void Trade_OnPluginStart() {}
void Trade_OnClientConnected(int client)
{
	#pragma unused client
}
void Trade_OnClientDisconnect(int client)
{
	#pragma unused client
}
#endif
