Handle g_hAdminMenu = INVALID_HANDLE;
char g_szClientData[MAXPLAYERS+1][256];
//new TopMenuObject:g_eStoreAdmin;
TopMenuObject g_eStoreAdmin;

void Store_Admin_AdminMenuOnPluginStart()
{
	Handle topmenu;
	if (LibraryExists("adminmenu") && ((topmenu = GetAdminTopMenu()) != INVALID_HANDLE))
		OnAdminMenuReady(topmenu);
}

//////////////////////////////
//		 ADMIN MENUS		//
//////////////////////////////

public void OnAdminMenuReady(Handle topmenu)
{
	if (topmenu == g_hAdminMenu)
		return;
	g_hAdminMenu = topmenu;

	g_eStoreAdmin = AddToTopMenu(g_hAdminMenu, "Store Admin", TopMenuObject_Category, CategoryHandler_StoreAdmin, INVALID_TOPMENUOBJECT);
	AddToTopMenu(g_hAdminMenu, "sm_store_resetdb", TopMenuObject_Item, AdminMenu_ResetDb, g_eStoreAdmin, "sm_store_resetdb", g_eCvars[g_cvarAdminFlag].aCache);
	AddToTopMenu(g_hAdminMenu, "sm_store_resetplayer", TopMenuObject_Item, AdminMenu_ResetPlayer, g_eStoreAdmin, "sm_store_resetplayer", g_eCvars[g_cvarAdminFlag].aCache);
	AddToTopMenu(g_hAdminMenu, "sm_store_givecredits", TopMenuObject_Item, AdminMenu_GiveCredits, g_eStoreAdmin, "sm_store_givecredits", g_eCvars[g_cvarAdminFlag].aCache);
	AddToTopMenu(g_hAdminMenu, "sm_store_viewinventory", TopMenuObject_Item, AdminMenu_ViewInventory, g_eStoreAdmin, "sm_store_viewinventory", g_eCvars[g_cvarAdminFlag].aCache);
	AddToTopMenu(g_hAdminMenu, "sm_store_reload_config", TopMenuObject_Item, AdminMenu_RealoadConfig, g_eStoreAdmin, "sm_store_reload_config", g_eCvars[g_cvarAdminFlag].aCache);
}

public void CategoryHandler_StoreAdmin(Handle topmenu, TopMenuAction action, TopMenuObject object_id,int param, char[] buffer,int maxlength)
{
	if (action == TopMenuAction_DisplayTitle || action == TopMenuAction_DisplayOption)
	{
		char translated[128];
		Format(translated, sizeof(translated), "%t", "Store Admin Category");
		strcopy(buffer, maxlength, translated);
	}
}

//////////////////////////////
//		Reload config		//
//////////////////////////////

public void AdminMenu_RealoadConfig(Handle topmenu, TopMenuAction action, TopMenuObject object_id,int client, char[] buffer,int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		char translated[128];
		Format(translated, sizeof(translated), "%t", "Reload store config");
		strcopy(buffer, maxlength, translated);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 0;

		char sBuffer[256];
		if(!g_eCvars[gc_iReloadType].aCache)
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "confirm_reload_type_0", view_as<int>(g_eCvars[gc_iReloadDelay].aCache));
		}
		else 
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "confirm_reload_type_1");
		}
		Store_DisplayConfirmMenu(client, sBuffer, FakeMenuHandler_StoreReloadConfig, 0);
	}
}

//////////////////////////////
//		Reset database		//
//////////////////////////////

public void AdminMenu_ResetDb(Handle topmenu, TopMenuAction action, TopMenuObject object_id,int client, char[] buffer,int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		char translated[128];
		Format(translated, sizeof(translated), "%t", "Reset database");
		strcopy(buffer, maxlength, translated);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 0;
		
		char confirmMsg[256];
		Format(confirmMsg, sizeof(confirmMsg), "%t", "confirm_reset_database");
		
		Store_DisplayConfirmMenu(client, confirmMsg, FakeMenuHandler_ResetDatabase, 0);
	}
}

public void FakeMenuHandler_ResetDatabase(Handle menu, MenuAction action, int client,int param2)
{
	SQL_TVoid(g_hDatabase, "DROP TABLE store_players");
	SQL_TVoid(g_hDatabase, "DROP TABLE store_items");
	SQL_TVoid(g_hDatabase, "DROP TABLE store_equipment");
	ServerCommand("_restart");
}

//////////////////////////////
//		Reset player		//
//////////////////////////////

public void AdminMenu_ResetPlayer(Handle topmenu, TopMenuAction action, TopMenuObject object_id,int client, char[] buffer,int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		char translated[128];
		Format(translated, sizeof(translated), "%t", "Reset player");
		strcopy(buffer, maxlength, translated);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 4;
		Handle m_hMenu = CreateMenu(MenuHandler_ResetPlayer);
		
		char menuTitle[128];
		Format(menuTitle, sizeof(menuTitle), "%t", "choose_player_reset");
		SetMenuTitle(m_hMenu, menuTitle);
		
		SetMenuExitBackButton(m_hMenu, true);
		LoopAuthorizedPlayers(i)
		{
			char m_szName[64];
			char m_szAuthId[32];
			GetClientName(i, STRING(m_szName));
			GetLegacyAuthString(i, STRING(m_szAuthId));
			AddMenuItem(m_hMenu, m_szAuthId, m_szName);
		}
		DisplayMenu(m_hMenu, client, 0);
	}
}

public int MenuHandler_ResetPlayer(Handle menu, MenuAction action,int client,int param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		if(menu == INVALID_HANDLE)
		{
			FakeClientCommandEx(client, "sm_resetplayer \"%s\"", g_szClientData[client]);
		}
		else
		{
			any style;
			char m_szName[64];
			GetMenuItem(menu, param2, g_szClientData[client], sizeof(g_szClientData[]), style, STRING(m_szName));

			char m_szTitle[256];
			Format(STRING(m_szTitle), "%t", "confirm_reset_player", m_szName);
			Store_DisplayConfirmMenu(client, m_szTitle, MenuHandler_ResetPlayer, 0);
		}
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		RedisplayAdminMenu(g_hAdminMenu, client);
		
	return 0;
}

//////////////////////////////
//		Give credits		//
//////////////////////////////

public void AdminMenu_GiveCredits(Handle topmenu, TopMenuAction action, TopMenuObject object_id,int client, char[] buffer,int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		char translated[128];
		Format(translated, sizeof(translated), "%t", "Give credits");
		strcopy(buffer, maxlength, translated);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 5;
		Handle m_hMenu = CreateMenu(MenuHandler_GiveCredits);
		
		char menuTitle[128];
		Format(menuTitle, sizeof(menuTitle), "%t", "choose_player_credits");
		SetMenuTitle(m_hMenu, menuTitle);
		
		SetMenuExitBackButton(m_hMenu, true);
		LoopAuthorizedPlayers(i)
		{
			char m_szName[64];
			char m_szAuthId[32];
			GetClientName(i, STRING(m_szName));
			GetLegacyAuthString(i, STRING(m_szAuthId));
			AddMenuItem(m_hMenu, m_szAuthId, m_szName);
		}
		DisplayMenu(m_hMenu, client, 0);
	}
}

public int MenuHandler_GiveCredits(Handle menu, MenuAction action,int client,int param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		if(param2 != -1)
			GetMenuItem(menu, param2, g_szClientData[client], sizeof(g_szClientData[]));
		
		Handle m_hMenu = CreateMenu(MenuHandler_GiveCredits2);

		int target = GetClientBySteamID(g_szClientData[client]);
		if(target == 0)
		{
			AdminMenu_GiveCredits(g_hAdminMenu, TopMenuAction_SelectOption, g_eStoreAdmin, client, "", 0);
			return 0;
		}

		char menuTitle[256];
		char playerName[MAX_NAME_LENGTH];
		GetClientName(target, playerName, sizeof(playerName));
		
		Format(menuTitle, sizeof(menuTitle), "%t", "choose_credits_amount", playerName, g_eClients[target].iCredits);
		SetMenuTitle(m_hMenu, menuTitle);
		
		SetMenuExitBackButton(m_hMenu, true);
		AddMenuItem(m_hMenu, "-1000", "-1000");
		AddMenuItem(m_hMenu, "-100", "-100");
		AddMenuItem(m_hMenu, "-10", "-10");
		AddMenuItem(m_hMenu, "10", "10");
		AddMenuItem(m_hMenu, "100", "100");
		AddMenuItem(m_hMenu, "1000", "1000");
		DisplayMenu(m_hMenu, client, 0);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		RedisplayAdminMenu(g_hAdminMenu, client);
		
	return 0;
}

public int MenuHandler_GiveCredits2(Handle menu, MenuAction action,int client,int param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		char m_szData[11];
		GetMenuItem(menu, param2, STRING(m_szData));
		FakeClientCommand(client, "sm_givecredits \"%s\" %s", g_szClientData[client], m_szData);
		MenuHandler_GiveCredits(INVALID_HANDLE, MenuAction_Select, client, -1);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		AdminMenu_GiveCredits(g_hAdminMenu, TopMenuAction_SelectOption, g_eStoreAdmin, client, "", 0);
		
	return 0;
}

//////////////////////////////
//		View inventory		//
//////////////////////////////

public void AdminMenu_ViewInventory(Handle topmenu, TopMenuAction action, TopMenuObject object_id,int client, char[] buffer,int maxlength)
{
	if (action == TopMenuAction_DisplayOption)
	{
		char translated[128];
		Format(translated, sizeof(translated), "%t", "View inventory");
		strcopy(buffer, maxlength, translated);
	}
	else if (action == TopMenuAction_SelectOption)
	{
		g_iMenuNum[client] = 4;
		Handle m_hMenu = CreateMenu(MenuHandler_ViewInventory);
		
		char menuTitle[128];
		Format(menuTitle, sizeof(menuTitle), "%t", "choose_player_inventory");
		SetMenuTitle(m_hMenu, menuTitle);
		
		SetMenuExitBackButton(m_hMenu, true);
		LoopAuthorizedPlayers(i)
		{
			char m_szName[64];
			char m_szAuthId[32];
			GetClientName(i, STRING(m_szName));
			GetLegacyAuthString(i, STRING(m_szAuthId));
			AddMenuItem(m_hMenu, m_szAuthId, m_szName);
		}
		DisplayMenu(m_hMenu, client, 0);
	}
}

public int MenuHandler_ViewInventory(Handle menu, MenuAction action,int client,int param2)
{
	if (action == MenuAction_End)
		CloseHandle(menu);
	else if (action == MenuAction_Select)
	{
		GetMenuItem(menu, param2, g_szClientData[client], sizeof(g_szClientData[]));
		int target = GetClientBySteamID(g_szClientData[client]);
		if(target == 0)
		{
			AdminMenu_ViewInventory(g_hAdminMenu, TopMenuAction_SelectOption, g_eStoreAdmin, client, "", 0);
			return 0;
		}

		g_bInvMode[client]=true;
		g_iMenuClient[client]=target;
		DisplayStoreMenu(client);
	}
	else if (action == MenuAction_Cancel && param2 == MenuCancel_ExitBack)
		RedisplayAdminMenu(g_hAdminMenu, client);
		
	return 0;
}