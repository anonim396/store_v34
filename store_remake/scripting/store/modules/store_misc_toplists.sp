ConVar gc_iMaxShown;
ConVar gc_iUpdateInterval;

char g_sCreditsName[128] = "credits";
char g_sMenuItem[64];
char g_sMenuExit[64];

int g_iPage[MAXPLAYERS + 1];
int g_iList[MAXPLAYERS + 1];
int g_iUpdateTime;

#define TL_CREDITS 0
#define TL_ITEMS 1
#define TL_INV 2
#define TL_INV_CREDITS 3
#define TL_EQUIP_WORTH 4

ArrayList g_aTopLists[5];

public void TopLists_OnPluginStart()
{
	RegConsoleCmd("sm_toplists", Command_TopLists);
	RegConsoleCmd("sm_topcredits", Command_TCredits);
	RegConsoleCmd("sm_topitems", Command_Items);
	RegConsoleCmd("sm_topworth", Command_InventarWorth);
	RegConsoleCmd("sm_toptotal", Command_InventarAndCreditsWorth);
	RegConsoleCmd("sm_topequipped", Command_EquippedWorth);

	AutoExecConfig_SetFile("toplist", "sourcemod/store");
	AutoExecConfig_SetCreateFile(true);

	gc_iMaxShown = AutoExecConfig_CreateConVar("store_toplist_max", "10", "", _, true, 1.0);
	gc_iUpdateInterval = AutoExecConfig_CreateConVar("store_toplist_update_interval", "300.0", "If toplist is older thank x seconds query to database", _, true, 5.0);

	AutoExecConfig_ExecuteFile();
	AutoExecConfig_CleanFile();

	g_aTopLists[TL_CREDITS] = new ArrayList();
	g_aTopLists[TL_ITEMS] = new ArrayList();
	g_aTopLists[TL_INV] = new ArrayList();
	g_aTopLists[TL_INV_CREDITS] = new ArrayList();
	g_aTopLists[TL_EQUIP_WORTH] = new ArrayList();
}

void Menu_TopLists(int client)
{
	Menu menu = new Menu(Handler_TopLists, MENU_ACTIONS_ALL);

	char sBuffer[256];
	int i_Credits = Store_GetClientCredits(client);
	
	Format(sBuffer, sizeof(sBuffer), "%t - %s\n%t", "Title Store", "toplists", "Title Credits", i_Credits);
	menu.SetTitle(sBuffer);

	Format(sBuffer, sizeof(sBuffer), "%t", "Top Credits");
	menu.AddItem("0", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Top Most Items");
	menu.AddItem("1", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Top Inv Worth");
	menu.AddItem("2", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Top Credits Inv Worth");
	menu.AddItem("3", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Top Equipped Worth");
	menu.AddItem("4", sBuffer);

	menu.ExitButton = true;
	menu.ExitBackButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Handler_TopLists(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		g_iList[client] = param2;
		g_iPage[client] = 0;
		Panel_Credits(client, param2);
	}
	else if (action == MenuAction_Cancel)
	{
		if (param2 == MenuCancel_ExitBack)
		{
			Store_DisplayPreviousMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

public Action Command_TopLists(int client, int args)
{
	//Buisness as usual
	if (!client)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Command is in-game only");
		return Plugin_Handled;
	}

	//Check if we should update the toplists "mystore_toplist_update_interval"
	if (gc_iUpdateInterval.IntValue < GetTime() - g_iUpdateTime)
	{
		TopLists_OnMapStart();
	}

	Menu_TopLists(client);

	return Plugin_Handled;
}

public Action Command_TCredits(int client, int args)
{
	//Buisness as usual
	if (!client)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Command is in-game only");
		return Plugin_Handled;
	}

	//Check if we should update the toplists "mystore_toplist_update_interval"
	if (gc_iUpdateInterval.IntValue < GetTime() - g_iUpdateTime)
	{
		TopLists_OnMapStart();
	}

	//Save selection & display toplist
	g_iList[client] = TL_CREDITS;
	Panel_Credits(client, TL_CREDITS);

	return Plugin_Handled;
}

public Action Command_Items(int client, int args)
{
	//Buisness as usual
	if (!client)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Command is in-game only");
		return Plugin_Handled;
	}

	//Check if we should update the toplists "mystore_toplist_update_interval"
	if (gc_iUpdateInterval.IntValue < GetTime() - g_iUpdateTime)
	{
		TopLists_OnMapStart();
	}

	//Save selection & display toplist
	g_iList[client] = TL_ITEMS;
	Panel_Credits(client, TL_ITEMS);

	return Plugin_Handled;
}

public Action Command_InventarWorth(int client, int args)
{
	//Buisness as usual
	if (!client)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Command is in-game only");
		return Plugin_Handled;
	}

	//Check if we should update the toplists "mystore_toplist_update_interval"
	if (gc_iUpdateInterval.IntValue < GetTime() - g_iUpdateTime)
	{
		TopLists_OnMapStart();
	}

	//Save selection & display toplist
	g_iList[client] = TL_INV;
	Panel_Credits(client, TL_INV);

	return Plugin_Handled;
}

public Action Command_InventarAndCreditsWorth(int client, int args)
{
	//Buisness as usual
	if (!client)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Command is in-game only");
		return Plugin_Handled;
	}

	//Check if we should update the toplists "mystore_toplist_update_interval"
	if (gc_iUpdateInterval.IntValue < GetTime() - g_iUpdateTime)
	{
		TopLists_OnMapStart();
	}

	//Save selection & display toplist
	g_iList[client] = TL_INV_CREDITS;
	Panel_Credits(client, TL_INV_CREDITS);

	return Plugin_Handled;
}

public Action Command_EquippedWorth(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Command is in-game only");
		return Plugin_Handled;
	}

	if (gc_iUpdateInterval.IntValue < GetTime() - g_iUpdateTime)
	{
		TopLists_OnMapStart();
	}

	g_iList[client] = TL_EQUIP_WORTH;
	Panel_Credits(client, TL_EQUIP_WORTH);

	return Plugin_Handled;
}

public void TopLists_OnMapStart()
{
	Transaction tnx = new Transaction();

	char sDriver[16];
	SQL_ReadDriver(g_hDatabase, sDriver, sizeof(sDriver));

	char sBuffer[512];
	int maxShown = gc_iMaxShown.IntValue;

	Format(sBuffer, sizeof(sBuffer), 
		"SELECT name, credits FROM store_players ORDER BY credits DESC LIMIT %d;",
		maxShown);
	tnx.AddQuery(sBuffer);

	Format(sBuffer, sizeof(sBuffer), 
		"SELECT player.name, COUNT(*) AS amount FROM store_players AS player "
		... "INNER JOIN store_items AS item ON player.id = item.player_id "
		... "GROUP BY player.name ORDER BY amount DESC LIMIT %d;",
		maxShown);
	tnx.AddQuery(sBuffer);

	Format(sBuffer, sizeof(sBuffer), 
		"SELECT player.name, SUM(item.price_of_purchase) AS worth, COUNT(*) AS amount "
		... "FROM store_players AS player "
		... "INNER JOIN store_items AS item ON player.id = item.player_id "
		... "GROUP BY player.name ORDER BY worth DESC LIMIT %d;",
		maxShown);
	tnx.AddQuery(sBuffer);

	if (StrEqual(sDriver, "mysql", false) || StrEqual(sDriver, "sqlite", false))
	{
		Format(sBuffer, sizeof(sBuffer), 
			"SELECT player.name, "
			... "(player.credits + IFNULL(SUM(item.price_of_purchase), 0)) AS worth, "
			... "COUNT(item.id) AS amount "
			... "FROM store_players AS player "
			... "LEFT JOIN store_items AS item ON player.id = item.player_id "
			... "GROUP BY player.name, player.credits ORDER BY worth DESC LIMIT %d;",
			maxShown);
	}
	else if (StrEqual(sDriver, "postgresql", false))
	{
		Format(sBuffer, sizeof(sBuffer), 
			"SELECT player.name, "
			... "(player.credits + COALESCE(SUM(item.price_of_purchase), 0)) AS worth, "
			... "COUNT(item.id) AS amount "
			... "FROM store_players AS player "
			... "LEFT JOIN store_items AS item ON player.id = item.player_id "
			... "GROUP BY player.name, player.credits ORDER BY worth DESC LIMIT %d;",
			maxShown);
	}
	tnx.AddQuery(sBuffer);

	Format(sBuffer, sizeof(sBuffer),
        "SELECT player.name, SUM(items.price_of_purchase) AS worth, "
        ... "COUNT(*) AS amount FROM store_players AS player "
        ... "INNER JOIN store_items AS items ON player.id = items.player_id "
        ... "INNER JOIN store_equipment AS equip ON items.player_id = equip.player_id "
        ... "AND items.type = equip.type AND items.unique_id = equip.unique_id "
        ... "WHERE items.date_of_expiration = 0 OR items.date_of_expiration > %d "
        ... "GROUP BY player.name ORDER BY worth DESC LIMIT %d;",
        GetTime(), maxShown);
    tnx.AddQuery(sBuffer);

	Store_SQLTransaction(tnx, SQLTXNCallback_Success, 0);

	g_iUpdateTime = GetTime();
}

public void SQLTXNCallback_Success(Database db, any data, int numQueries, DBResultSet[] results, any[] queryData)
{
	//Loop through the results array for all types of toplists
	for (int i = 0; i < numQueries; i++)
	{
		if (results[i] == null)
		{
			Store_SQLLogMessage(0, LOG_ERROR, "SQLTXNCallback_Success: Error: No results for toplist #%i", i);
		}
		else
		{
			char sName[64];

			// Delete the DataPacks & clear the ArrayList
			if (g_aTopLists[i].Length > 0)
			{
				for (int j = 0; j < g_aTopLists[i].Length; j++)
				{
					DataPack pack = g_aTopLists[i].Get(j);
					delete pack;
				}
			}
			g_aTopLists[i].Clear();

			int fieldCount = results[i].FieldCount;
			
			//Loop through the result rows and write them into DataPacks
			while (results[i].FetchRow())
			{
				DataPack pack = new DataPack();

				results[i].FetchString(0, sName, sizeof(sName));
				pack.WriteCell(results[i].FetchInt(1));
				pack.WriteString(sName);
				
				if (fieldCount > 2)
				{
					pack.WriteCell(results[i].FetchInt(2));
				}

				//Push these DataPacks to ArrayList
				g_aTopLists[i].Push(pack);
			}
		}
	}
}

void Panel_Credits(int client, int type)
{
	Panel panel = new Panel();

	char sName[256];
	char sBuffer[256], sBuffer2[256];

	int i_Credits = Store_GetClientCredits(client);

	//Choose right Title for toplist
	switch(type)
	{
		case TL_CREDITS: Format(sBuffer, sizeof(sBuffer), "%t", "Top Credits");
		case TL_ITEMS: Format(sBuffer, sizeof(sBuffer), "%t", "Top Most Items");
		case TL_INV: Format(sBuffer, sizeof(sBuffer), "%t", "Top Inv Worth"); 
		case TL_INV_CREDITS: Format(sBuffer, sizeof(sBuffer), "%t", "Top Credits Inv Worth");
		case TL_EQUIP_WORTH: Format(sBuffer, sizeof(sBuffer), "%t", "Top Equipped Worth");
	}

	//Display title
	Format(sBuffer, sizeof(sBuffer), "%t - %s\n%t", "Title Store", sBuffer, "Title Credits", i_Credits);
	panel.SetTitle(sBuffer);
	panel.DrawText(" ");

	//Loop and display 5 players for actual page
	for (int i = g_iPage[client]; i < g_iPage[client] + 5 && i < g_aTopLists[type].Length; i++)
	{
		//Get DataPack with Player Data for toplist
		DataPack pack = g_aTopLists[type].Get(i);
		pack.Reset();
		int credits = pack.ReadCell();
		pack.ReadString(sName, sizeof(sName));

		//Format by types for display
		switch(type)
		{
			case TL_INV, TL_INV_CREDITS:
			{
				int items = pack.ReadCell();
				//Format(sBuffer, sizeof(sBuffer), "%t", "items");
				//Format(sBuffer, sizeof(sBuffer), "%t", "inv and inv credits", i + 1, sName, credits, g_sCreditsName, items, sBuffer);
				Format(sBuffer, sizeof(sBuffer), "%t", "items");
				Format(sBuffer2, sizeof(sBuffer2), "%t", "creditstoplist", g_sCreditsName);
				Format(sBuffer, sizeof(sBuffer), "%i. %s:   %i %s", i + 1, sName, credits, type == TL_CREDITS ? sBuffer2 : sBuffer, items, sBuffer);
			}
			case TL_EQUIP_WORTH:
			{
				int items = pack.ReadCell();				
				Format(sBuffer, sizeof(sBuffer), "%t", "items");
				Format(sBuffer2, sizeof(sBuffer2), "%t", "creditstoplist", g_sCreditsName);
				Format(sBuffer, sizeof(sBuffer), "%i. %s:   %i %s", i + 1, sName, credits, type == TL_CREDITS ? sBuffer2 : sBuffer, items, sBuffer);
			}
			case TL_CREDITS, TL_ITEMS:
			{
				Format(sBuffer, sizeof(sBuffer), "%t", "items");
				Format(sBuffer2, sizeof(sBuffer2), "%t", "creditstoplist", g_sCreditsName);
				Format(sBuffer, sizeof(sBuffer), "%i. %s:   %i %s", i + 1, sName, credits, type == TL_CREDITS ? sBuffer2 : sBuffer);
			}
		}
		panel.DrawText(sBuffer);
	}

	panel.DrawText(" ");
	panel.CurrentKey = 7;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	if (g_iPage[client] + 5 < g_aTopLists[type].Length)
	{
		panel.CurrentKey = 8;
		Format(sBuffer, sizeof(sBuffer), "%t", "Next");
		panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	}
	else
	{
		SecToTime(GetTime() - g_iUpdateTime, sBuffer, sizeof(sBuffer));
		Format(sBuffer, sizeof(sBuffer), "%t", "last update", sBuffer);
		panel.DrawText(sBuffer);

		//When last update older than "mystore_toplist_update_interval"
		if (gc_iUpdateInterval.IntValue < GetTime() - g_iUpdateTime)
		{
			TopLists_OnMapStart();
		}
	}
	panel.CurrentKey = 9;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.Send(client, Handler_Credits, MENU_TIME_FOREVER);

	delete panel;
}

public int Handler_Credits(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 9:
			{
				g_iPage[client] = 0;
				EmitSoundToClient(client, g_sMenuExit);
			}
			
			case 7:
			{
				EmitSoundToClient(client, g_sMenuExit);
				if (g_iPage[client] > 0)
				{
					g_iPage[client] -= 5;
					Panel_Credits(client, g_iList[client]);
				}
				else
				{
					Menu_TopLists(client);
				}
			}
			
			case 8:
			{
				g_iPage[client] += 5;
				Panel_Credits(client, g_iList[client]);
				EmitSoundToClient(client, g_sMenuItem);
			}
		}
	}
	else if (action == MenuAction_Cancel)
	{
		if (itemNum == MenuCancel_ExitBack)
		{
			Store_DisplayPreviousMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		delete panel;
	}
	
	return 0;
}

//Format integer of N seconds into string of n hours, n minutes & n seconds
int SecToTime(int time, char[] buffer, int size)
{
	int iHours = 0;
	int iMinutes = 0;
	int iSeconds = time;

	while (iSeconds > 3600)
	{
		iHours++;
		iSeconds -= 3600;
	}
	while (iSeconds > 60)
	{
		iMinutes++;
		iSeconds -= 60;
	}

	if (iHours >= 1)
	{
		Format(buffer, size, "%t", "x hours, x minutes, x seconds toplist", iHours, iMinutes, iSeconds);
	}
	else if (iMinutes >= 1)
	{
		Format(buffer, size, "%t", "x minutes, x seconds toplist", iMinutes, iSeconds);
	}
	else
	{
		Format(buffer, size, "%t", "x seconds toplist", iSeconds);
	}
	
	return 0;
}