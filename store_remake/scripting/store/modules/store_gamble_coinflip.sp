#if STORE_MODULE_GAMBLE_COINFLIP
ConVar gc_CFMin;
ConVar gc_CFMax;
ConVar gc_CFAutoStop;
ConVar gc_CFSpeed;
ConVar gc_CFAlive;
ConVar gc_CFBonus, gc_CFBonusRatio, gc_CFBonusRatioAmount;

Handle g_hCFTimerRun[MAXPLAYERS+1] = {null, ...};
Handle g_hCFTimerStopFlip[MAXPLAYERS+1] = {null, ...};

bool g_bCFFlipping[MAXPLAYERS+1] = {false, ...};
bool g_bCFHead[MAXPLAYERS+1] = {false, ...};

int g_iCFBet[MAXPLAYERS+1] = {-1, ...};
int g_iCFPosition[MAXPLAYERS+1] = {-1, ...};

public void Coinflip_OnPluginStart()
{
	RegConsoleCmd("sm_coinflip", Command_CoinFlip, "Open the CoinFlip casino game");

	gc_CFSpeed = CreateConVar("store_coinflip_speed", "0.1", "Speed the wheel spin", _, true, 0.1, true, 0.80);
	gc_CFAutoStop = CreateConVar("store_coinflip_stop", "10.0", "Seconds a roll should auto stop", _, true, 0.0);
	gc_CFAlive = CreateConVar("store_coinflip_alive", "1", "0 - Only dead player can start a game. 1 - Allow alive player to start a game.", _, true, 0.0);
	gc_CFMin = CreateConVar("store_coinflip_min", "20", "Minium amount of credits to spend", _, true, 1.0);
	gc_CFMax = CreateConVar("store_coinflip_max", "2000", "Maximum amount of credits to spend", _, true, 2.0);
	gc_CFBonus = CreateConVar("store_coinflip_bonus", "1", "Enable bonus credits for betting above ratio of Max Bet.", _, true, 0.0, true, 1.0);
	gc_CFBonusRatio = CreateConVar("store_coinflip_bonus_ratio", "0.75", "Minimun pertage of max bet to be able to get bonus credits.");
	gc_CFBonusRatioAmount = CreateConVar("store_coinflip_bonus_ratio_amount", "0.5", "Ratio of bonus on betting base on Max Bet of the game.");
	Store_BeginModuleConfig("sourcemod/store", "gamble_coinflip");
	STORE_CFG("store_coinflip_speed", "0.1");
	STORE_CFG("store_coinflip_stop", "10.0");
	STORE_CFG("store_coinflip_alive", "1");
	STORE_CFG("store_coinflip_min", "20");
	STORE_CFG("store_coinflip_max", "2000");
	STORE_CFG("store_coinflip_bonus", "1");
	STORE_CFG("store_coinflip_bonus_ratio", "0.75");
	STORE_CFG("store_coinflip_bonus_ratio_amount", "0.5");
	Store_EndModuleConfig("sourcemod/store", "gamble_coinflip");
}

public void Coinflip_OnClientAuthorized(int client, const char[] auth)
{
	g_iCFPosition[client] = -1;
	g_bCFFlipping[client] = false;
	g_iCFBet[client] = 0;
}

public void Coinflip_OnClientDisconnect(int client)
{
	delete g_hCFTimerRun[client];
	delete g_hCFTimerStopFlip[client];
}

public Action Command_CoinFlip(int client, int args)
{
	// Command comes from console
	if (!client)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Command is in-game only");

		return Plugin_Handled;
	}

	if (args < 1 || args > 2)
	{
		if(g_hCFTimerRun[client] != null || g_hCFTimerStopFlip[client] != null)
		{
			//delete g_hCFTimerRun[client];
			//delete g_hCFTimerStopFlip[client];
			//CReplyToCommand(client, "%sDebugged", g_sChatPrefix);
			ReplyToCommand(client, "%s %t", g_sChatPrefix, "Game in progress");
		}
		else
		{
			Panel_PreCoinFlip(client);
			ReplyToCommand(client, "%s %t", g_sChatPrefix, "Type in chat !coinflip");
		}

		return Plugin_Handled;
	}

	char sBuffer[32];
	GetCmdArg(1, sBuffer, 32);
	int iBet;
	int iCredits = Store_GetClientCredits(client);

	if (IsCharNumeric(sBuffer[0]))
	{
		iBet = StringToInt(sBuffer);
	}
	else if (StrEqual(sBuffer,"all"))
	{
		iBet = iCredits;
	}
	else if (strcmp(sBuffer,"half"))
	{
		iBet = RoundFloat(iCredits / 2.0);
	}
	else if (StrEqual(sBuffer,"third"))
	{
		iBet = RoundFloat(iCredits / 3.0);
	}
	else if (strcmp(sBuffer,"quater"))
	{
		iBet = RoundFloat(iCredits / 4.0);
	}

	if (iBet < gc_CFMin.IntValue)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "You have to spend at least x credits.", gc_CFMin.IntValue, g_sCreditsName);

		return Plugin_Handled;
	}
	else if (iBet > gc_CFMax.IntValue)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "You can't spend that much credits", gc_CFMax.IntValue, g_sCreditsName);

		return Plugin_Handled;
	}

	if (iBet > iCredits)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Not enough Credits");

		return Plugin_Handled;
	}
	
	//g_bCFFlipping[client] = false;
	
	/*if(g_hCFTimerRun[client] != null || g_hCFTimerStopFlip[client] != null || g_bCFFlipping[client])
	{
		delete g_hCFTimerRun[client];
		delete g_hCFTimerStopFlip[client];
		
		CReplyToCommand(client, "%sDebugged", g_sChatPrefix);

		return Plugin_Stop;
	}*/

	g_iCFBet[client] = iBet;

	if (args == 1)
	{
		if(g_hCFTimerRun[client] != null || g_hCFTimerStopFlip[client] != null)
		{
			//delete g_hCFTimerRun[client];
			//delete g_hCFTimerStopFlip[client];
			//CReplyToCommand(client, "%sDebugged", g_sChatPrefix);
			ReplyToCommand(client, "%s %t", g_sChatPrefix, "Game in progress");
		}
		else
		{
			Panel_ChooseSide(client);
		}
	}
	else if (args == 2)
	{
		if(g_hCFTimerRun[client] != null || g_hCFTimerStopFlip[client] != null)
		{
			//delete g_hCFTimerRun[client];
			//delete g_hCFTimerStopFlip[client];
			//CReplyToCommand(client, "%sDebugged", g_sChatPrefix);
			ReplyToCommand(client, "%s %t", g_sChatPrefix, "Game in progress");
		}
		else
		{
			GetCmdArg(2, sBuffer, 32);

			if (StrEqual(sBuffer, "h") || StrEqual(sBuffer, "head"))
			{
				g_bCFHead[client] = true;
			}
			else if (StrEqual(sBuffer, "t") || StrEqual(sBuffer, "tail"))
			{
				g_bCFHead[client] = false;
			}
			else
			{
				ReplyToCommand(client, "%s %t", g_sChatPrefix, "Type in chat !coinflip");

				return Plugin_Handled;
			}

			Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iCFBet[client]);
			Start_CoinFlip(client);
		}
	}

	return Plugin_Handled;
}

void Panel_PreCoinFlip(int client)
{
	// reset coinflip
	g_iCFPosition[client] = GetRandomInt(1,6);
	g_bCFFlipping[client] = false;

	if (g_iCFBet[client] == -1)
	{
		g_iCFBet[client] = gc_CFMin.IntValue;
	}

	Panel_CoinFlip(client);
}

// Open the start coinflip panel
void Panel_CoinFlip(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\nCredits:%i", "coinflip", iCredits);
	panel.SetTitle(sBuffer);

	PanelInject_CoinFlip(panel, client);
	panel.DrawText(" ");

	if (!gc_CFAlive.BoolValue && IsPlayerAlive(client))
	{
		Format(sBuffer, sizeof(sBuffer), "	\n	%t", "Must be dead");
		panel.DrawText(sBuffer);
	}
	else
	{
		//Format(sBuffer, sizeof(sBuffer), "	%t\n	%t", "Type in chat !coinflip", "or use buttons below");
		//panel.DrawText(sBuffer);
	}
	panel.DrawText(" ");

	panel.CurrentKey = 1;
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_CFMin.IntValue);
	panel.DrawItem(sBuffer, iCredits < gc_CFMin.IntValue || !gc_CFAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 2;
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_CFMax.IntValue ? gc_CFMax.IntValue : iCredits);
	panel.DrawItem(sBuffer, iCredits < gc_CFMin.IntValue || !gc_CFAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 3;
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_CFMin.IntValue, iCredits > gc_CFMax.IntValue ? gc_CFMax.IntValue : iCredits);
	panel.DrawItem(sBuffer, iCredits < gc_CFMin.IntValue || !gc_CFAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	
	panel.DrawText(" ");
	
	//Draw item rerun when already have bet - Panel line #14 - Panel item #4
	panel.CurrentKey = 5;
	Format(sBuffer, sizeof(sBuffer), "%t", "Rerun x Credits", g_iCFBet[client], g_sCreditsName);
	panel.DrawItem(sBuffer, g_iCFBet[client] > iCredits || g_iCFBet[client] == 0 || !gc_CFAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.DrawText(" ");
	
	panel.CurrentKey = 7;
	Format(sBuffer, sizeof(sBuffer), "%t", "Game Info");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	
	panel.DrawText(" ");
	
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.CurrentKey = 10;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, Handler_CoinFlip, MENU_TIME_FOREVER);

	delete panel;
}

public int Handler_CoinFlip(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 1, 2, 3:
			{
				// Decline when player come back to life
				int credits = Store_GetClientCredits(client);
				if (!gc_CFAlive.BoolValue && IsPlayerAlive(client))
				{
					Panel_CoinFlip(client);

					#if defined _clientmod_included
						MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Must be dead CM");
						C_PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#else
						PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#endif

					//ClientCommand(client, "play %s", g_sMenuExit);
					EmitSoundToClient(client, g_sMenuExit);
				}
				else
				{
					switch(itemNum)
					{
						case 1: g_iCFBet[client] = gc_CFMin.IntValue;
						case 2: g_iCFBet[client] = credits > gc_CFMax.IntValue ? gc_CFMax.IntValue : credits;
						case 3: g_iCFBet[client] = GetRandomInt(gc_CFMin.IntValue, credits > gc_CFMax.IntValue ? gc_CFMax.IntValue : credits);
					}

					Panel_ChooseSide(client);

					//ClientCommand(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
			}
			case 5:
			{
				// Decline when player come back to life
				if (!gc_CFAlive.BoolValue && IsPlayerAlive(client))
				{
					Panel_CoinFlip(client);
					#if defined _clientmod_included
						MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Must be dead CM");
						C_PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#else
						PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#endif

					//ClientCommand(client, "play %s", g_sMenuExit);
					EmitSoundToClient(client, g_sMenuExit);
				}
				// show place color panel
				else
				{
					Panel_ChooseSide(client);
					//ClientCommand(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
			}
			case 7:
			{
				Panel_CFGameInfo(client);
				//ClientCommand(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			case 8:
			{
				//ClientCommand(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
				Store_DisplayPreviousMenu(client);
			}
			case 10: 
			{
				//ClientCommand(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
	
	return 0;
}

// Open the choose color panel
void Panel_ChooseSide(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "coinflip", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// Show the coinflip - Panel line #5-9
	PanelInject_CoinFlip(panel, client);	
	panel.DrawText(" ");
	if (!gc_CFAlive.BoolValue && IsPlayerAlive(client))
	{
		Format(sBuffer, sizeof(sBuffer), "	\n	%t", "Must be dead");
		panel.DrawText(sBuffer);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "	%t\n	%t", "Type in chat !coinflip", "or use buttons below");
		panel.DrawText(sBuffer);
	}
	panel.DrawText(" ");

	panel.CurrentKey = 1;
	Format(sBuffer, sizeof(sBuffer), "%t '████' - %t", "Bet on", "Head");
	panel.DrawItem(sBuffer, !gc_CFAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 2;
	Format(sBuffer, sizeof(sBuffer), "%t '▓▓▓▓' - %t", "Bet on", "Tail");
	panel.DrawItem(sBuffer, !gc_CFAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.CurrentKey = 6;
	Format(sBuffer, sizeof(sBuffer), "%t", "Game Info");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	
	panel.DrawText(" ");
	
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.CurrentKey = 10;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, Handler_PlaceColor, MENU_TIME_FOREVER);

	delete panel;
}

public int Handler_PlaceColor(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 1, 2:
			{
				// Decline when player come back to life
				if (!gc_CFAlive.BoolValue && IsPlayerAlive(client))
				{
					Panel_CoinFlip(client);

					//ClientCommand(client, "play %s", g_sMenuExit);
					EmitSoundToClient(client, g_sMenuExit);

					#if defined _clientmod_included
						MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Must be dead CM");
						C_PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#else
						PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#endif
				}
				// Remove Credits & start the game
				else
				{
					int iCredits = Store_GetClientCredits(client);
					if (iCredits >= g_iCFBet[client])
					{
						switch(itemNum)
						{
							case 1: g_bCFHead[client] = true;
							case 2: g_bCFHead[client] = false;
						}

						Store_SetClientCredits(client, iCredits - g_iCFBet[client]);
						Start_CoinFlip(client);
					}
					// when player has yet had not enough Credits (double check)
					else
					{
						//ClientCommand(client, "play %s", g_sMenuExit);
						EmitSoundToClient(client, g_sMenuExit);
						Panel_CoinFlip(client);

						#if defined _clientmod_included
							MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Not enough Credits CM");
							C_PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
						#else
							PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
						#endif
					}
				}
			}
			case 6:
			{
				Panel_CFGameInfo(client);
				//ClientCommand(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			case 8:
			{
				Panel_CoinFlip(client);
				//ClientCommand(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
			}
			case 10: 
			{
				//ClientCommand(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
	
	return 0;
}

void Start_CoinFlip(int client)
{
	g_bCFFlipping[client] = true;
	Store_SetClientRecurringMenu(client, true);

	// end possible still running timers
	delete g_hCFTimerStopFlip[client];
	delete g_hCFTimerRun[client];

	//play a start sound
	//ClientCommand(client, "play %s", g_sMenuItem);
	EmitSoundToClient(client, g_sMenuItem);

	g_hCFTimerRun[client] = CreateTimer(gc_CFSpeed.FloatValue, Timer_Run, GetClientUserId(client), TIMER_REPEAT); // run speed for all rolls
	TriggerTimer(g_hCFTimerRun[client]);

	g_hCFTimerStopFlip[client] = CreateTimer(GetAutoStopTime(), Timer_StopCoinFlip, GetClientUserId(client)); // stop first roll
}

void Panel_RunAndWin(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "coinflip", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// When coinflip is running step postion by one
	if (g_bCFFlipping[client])
	{
		g_iCFPosition[client]++;
		if (g_iCFPosition[client] > 12)
		{
			g_iCFPosition[client] = 1;
		}
	}

	// Show the coinflip - Panel line #5-9
	PanelInject_CoinFlip(panel, client);
	panel.DrawText(" ");
	// When coinflip is still running
	if (g_bCFFlipping[client])
	{
		// Draw the placed bet
		panel.DrawText(" ");
		Format(sBuffer, sizeof(sBuffer), "	%t", "Your bet", g_iCFBet[client], g_sCreditsName);
		panel.DrawText(sBuffer);

		// Draw Spacer item - Panel line #12 - Panel item #3
		panel.DrawText(" ");

		// Draw the placed color

		if (g_bCFHead[client])
		{
			Format(sBuffer, sizeof(sBuffer), "	%t '████' - %t", "Bet on", "Head");
		}
		else
		{
			Format(sBuffer, sizeof(sBuffer), "	%t '▓▓▓▓' - %t", "Bet on", "Tail");
		}

		panel.DrawText(sBuffer);
		panel.DrawText(" ");
		panel.DrawText(" ");
	}
	// When coinflip has stopped
	else
	{
		if (g_iCFPosition[client] != 3 && g_iCFPosition[client] != 9)
		{
			if (g_iCFPosition[client] < 7)
			{
				g_iCFPosition[client] = 3;
				g_bCFFlipping[client] = false;

				Panel_RunAndWin(client);

				delete panel;
				return;
			}
			else if (g_iCFPosition[client] > 6)
			{
				g_iCFPosition[client] = 9;
				g_bCFFlipping[client] = false;

				Panel_RunAndWin(client);

				delete panel;
				return;
			}
		}

		// If indicator is on choosen color -> WIN
		if ((g_bCFHead[client] && g_iCFPosition[client] < 7) || (!g_bCFHead[client] && g_iCFPosition[client] > 6))
		{
			// Build & draw won text - Panel line #12
			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "	%t %t", "You won with", g_bCFHead[client] ? "Head" : "Tail");
			panel.DrawText(sBuffer);

			// Draw Spacer Line - Panel line #13
			panel.DrawText(" ");

			// Build & draw text - Panel line #14
			Format(sBuffer, sizeof(sBuffer), "	%t", "You win x Credits", g_iCFBet[client] * 2, g_sCreditsName);
			panel.DrawText(sBuffer);

			panel.DrawText(" ");
			panel.DrawText(" ");
			// Process the won Credits & remaining notfiction
			ProcessWin(client, g_iCFBet[client], 2);
		}
		else
		{
			//Panel_CoinFlip(client);
			// Build & draw won text - Panel line #12
			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "	%t %t", "You lost with", g_bCFHead[client] ? "Head" : "Tail");
			panel.DrawText(sBuffer);

			// Draw Spacer Line - Panel line #13
			panel.DrawText(" ");

			// Build & draw text - Panel line #14
			Format(sBuffer, sizeof(sBuffer), "	%t", "You lost x Credits", g_iCFBet[client], g_sCreditsName);
			panel.DrawText(sBuffer);

			panel.DrawText(" ");
			panel.DrawText(" ");
			
			Format(sBuffer, sizeof(sBuffer), "%t", "coinflip");
			#if defined _clientmod_included
				MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Player lost x Credits CM", client, g_iCFBet[client], g_sCreditsName, sBuffer);
				C_PrintToChatAll("%s %t", g_sChatPrefix, "Player lost x Credits", client, g_iCFBet[client], g_sCreditsName, sBuffer);
			#else
				PrintToChatAll("%s %t", g_sChatPrefix, "Player lost x Credits", client, g_iCFBet[client], g_sCreditsName, sBuffer);
			#endif
			//delete panel;
			//return;
		}
	}
	panel.CurrentKey = 5;
	//Draw item rerun when already have bet - Panel line #14 - Panel item #4
	Format(sBuffer, sizeof(sBuffer), "%t", "Rerun x Credits", g_iCFBet[client], g_sCreditsName);
	panel.DrawItem(sBuffer, g_iCFBet[client] > iCredits || g_bCFFlipping[client] || !gc_CFAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	
	panel.DrawText(" ");
	
	//Draw item info - Panel line #15 - Panel item #5
	panel.CurrentKey = 6;
	Format(sBuffer, sizeof(sBuffer), "%t", "Game Info");
	panel.DrawItem(sBuffer, g_bCFFlipping[client] ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	
	panel.DrawText(" ");
	
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, g_bCFFlipping[client] ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 10;
	Format(sBuffer, sizeof(sBuffer), "%t", g_bCFFlipping[client] ? "Cancel" : "Exit");
	panel.DrawItem(sBuffer);

	panel.Send(client, Handler_RunWin, MENU_TIME_FOREVER);

	delete panel;
}

public int Handler_RunWin(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			// Item 4 - Rerun bet
			case 5:
			{
				// Decline when player come back to life
				if (!gc_CFAlive.BoolValue && IsPlayerAlive(client))
				{
					Panel_CoinFlip(client);
					#if defined _clientmod_included
						MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Must be dead CM");
						C_PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#else
						PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#endif

					//ClientCommand(client, "play %s", g_sMenuExit);
					EmitSoundToClient(client, g_sMenuExit);
				}
				// show place color panel
				else
				{
					Panel_ChooseSide(client);
					//ClientCommand(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
			}
			case 6:
			{
				Panel_CFGameInfo(client);
				//ClientCommand(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			// Item 6 - go back to casino
			case 8:
			{
				Panel_CoinFlip(client);

				//ClientCommand(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
			}
			// Item 9 - exit cancel
			case 10:
			{
				delete g_hCFTimerRun[client];
				delete g_hCFTimerStopFlip[client];

				Store_SetClientRecurringMenu(client, false);

				if (g_bCFFlipping[client])
				{
					Panel_CoinFlip(client);
				}

				g_bCFFlipping[client] = false;
				//ClientCommand(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
	
	return 0;
}

// Inject the coin into panels
void PanelInject_CoinFlip(Panel panel, int client)
{
	panel.DrawText(" ");
	switch(g_iCFPosition[client])
	{
		case 1:
		{
			panel.DrawText("			  ██");
			panel.DrawText("			████");
			panel.DrawText("		  ██████");
			panel.DrawText("			████");
			panel.DrawText("			  ██");
		}
		case 2:
		{
			panel.DrawText("			████");
			panel.DrawText("		  ██████");
			panel.DrawText("		████████");
			panel.DrawText("		  ██████");
			panel.DrawText("			████");
		}
		case 3:
		{
			panel.DrawText("		  ██████");
			panel.DrawText("		██  ██  ██");
			panel.DrawText("	  ███		███");
			panel.DrawText("		██  ██  ██");
			panel.DrawText("		  ██████");
		}
		case 4:
		{
			panel.DrawText("			████");
			panel.DrawText("		  ██████");
			panel.DrawText("		████████");
			panel.DrawText("		  ██████");
			panel.DrawText("			████");
		}
		case 5:
		{
			panel.DrawText("			  ██");
			panel.DrawText("			████");
			panel.DrawText("		  ██████");
			panel.DrawText("			████");
			panel.DrawText("			  ██");
		}
		case 6:
		{
			panel.DrawText("			  ██");
			panel.DrawText("			  ██");
			panel.DrawText("			  ██");
			panel.DrawText("			  ██");
			panel.DrawText("			  ██");
		}
		case 7:
		{
			panel.DrawText("			  ▓▓");
			panel.DrawText("			▓▓▓▓");
			panel.DrawText("		  ▓▓▓▓▓▓");
			panel.DrawText("			▓▓▓▓");
			panel.DrawText("			  ▓▓");
		}
		case 8:
		{
			panel.DrawText("			▓▓▓▓");
			panel.DrawText("		  ▓▓▓▓▓▓");
			panel.DrawText("		▓▓▓▓▓▓▓▓");
			panel.DrawText("		  ▓▓▓▓▓▓");
			panel.DrawText("			▓▓▓▓");
		}
		case 9:
		{
			panel.DrawText("		  ▓▓▓▓▓▓");
			panel.DrawText("		▓▓		▓▓");  // two spaces '  ' has size of one block '█'
			panel.DrawText("	  ▓▓▓▓	▓▓▓▓");
			panel.DrawText("		▓▓▓	▓▓▓");
			panel.DrawText("		  ▓▓▓▓▓▓");
		}
		case 10:
		{
			panel.DrawText("			▓▓▓▓");
			panel.DrawText("		  ▓▓▓▓▓▓");
			panel.DrawText("		▓▓▓▓▓▓▓▓");
			panel.DrawText("		  ▓▓▓▓▓▓");
			panel.DrawText("			▓▓▓▓");
		}
		case 11:
		{
			panel.DrawText("			  ▓▓");
			panel.DrawText("			▓▓▓▓");
			panel.DrawText("		  ▓▓▓▓▓▓");
			panel.DrawText("			▓▓▓▓");
			panel.DrawText("			  ▓▓");
		}
		case 12:
		{
			panel.DrawText("			  ▓▓");
			panel.DrawText("			  ▓▓");
			panel.DrawText("			  ▓▓");
			panel.DrawText("			  ▓▓");
			panel.DrawText("			  ▓▓");
		}
		default:
		{
			panel.DrawText("	   ██████	  |	  ▓▓▓▓▓▓");
			panel.DrawText("	 ██  ██  ██	|	▓▓		▓▓");
			panel.DrawText("   ███		███  |  ▓▓▓▓	▓▓▓▓");
			panel.DrawText("	 ██  ██  ██	|	▓▓▓	▓▓▓");
			panel.DrawText("	   ██████	  |	  ▓▓▓▓▓▓");
		}
	}
}

/******************************************************************************
				   functions
******************************************************************************/

//Randomize the stop time to the next number isn't predictable
float GetAutoStopTime()
{
	return GetRandomFloat(gc_CFAutoStop.FloatValue/2 - 0.8, gc_CFAutoStop.FloatValue/2 + 1.2);
}

void ProcessWin(int client, int bet, int multiply)
{
	char sBuffer[255];
	int iProfit;
	if(gc_CFBonus.BoolValue && (bet >= RoundToCeil((gc_CFMax.IntValue*gc_CFBonusRatio.FloatValue))))
		iProfit = bet * multiply + RoundToCeil(bet*gc_CFBonusRatioAmount.FloatValue);
	else iProfit = bet * multiply;

	// Add profit to balance
	Store_SetClientCredits(client, Store_GetClientCredits(client) + iProfit);

	// Play sound and notify other player abot this win
	Format(sBuffer, sizeof(sBuffer), "%t", "coinflip");
	if(gc_CFBonus.BoolValue && (bet >= RoundToCeil((gc_CFMax.IntValue*gc_CFBonusRatio.FloatValue))))
	{
		#if defined _clientmod_included
			MC_PrintToChatAll("%s %t - %t", g_sChatPrefix_CM, "Player won x Credits CM", client, bet * multiply, g_sCreditsName, sBuffer, "Bet Bonus CM", RoundToCeil(bet*gc_CFBonusRatioAmount.FloatValue));
			C_PrintToChatAll("%s %t - %t", g_sChatPrefix, "Player won x Credits", client, bet * multiply, g_sCreditsName, sBuffer, "Bet Bonus", RoundToCeil(bet*gc_CFBonusRatioAmount.FloatValue));
		#else
			PrintToChatAll("%s %t - %t", g_sChatPrefix, "Player won x Credits", client, bet * multiply, g_sCreditsName, sBuffer, "Bet Bonus", RoundToCeil(bet*gc_CFBonusRatioAmount.FloatValue));
		#endif
	}
	else 
	{
		#if defined _clientmod_included
			MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Player won x Credits CM", client, bet * multiply, g_sCreditsName, sBuffer);
			C_PrintToChatAll("%s %t", g_sChatPrefix, "Player won x Credits", client, bet * multiply, g_sCreditsName, sBuffer);
		#else
			PrintToChatAll("%s %t", g_sChatPrefix, "Player won x Credits", client, bet * multiply, g_sCreditsName, sBuffer);
		#endif
	}
	
	//ClientCommand(client, "play %s", g_sMenuItem);
	EmitSoundToClient(client, g_sMenuItem);
}

/******************************************************************************
				   Panel
******************************************************************************/

//Show the games info panel
void Panel_CFGameInfo(int client)
{
	char sBuffer[255];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	//Build the panel title three lines high - Panel line #1-3
	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "coinflip", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// Draw Spacer Line - Panel line #4
	panel.DrawText(" ");
	panel.DrawText(" ");


	Format(sBuffer, sizeof(sBuffer), "	%t", "Bet on a Head/Tail");
	panel.DrawText(" ");
	panel.DrawText(" ");

	panel.DrawText(sBuffer);

	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "	%t %t %i", "Win = ", "bet x", 2);
	panel.DrawText(sBuffer);

	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.DrawText(sBuffer);


	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.DrawText(" ");
	panel.CurrentKey = 10;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, Handler_RunWin, 14);

	delete panel;
}

/******************************************************************************
				   Timer
******************************************************************************/

// The game runs and roll the coinflip
public Action Timer_Run(Handle tmr, int userid)
{
	int client = GetClientOfUserId(userid);

	// When client disconnected end timer
	if (!client || !IsClientInGame(client) || !IsClientConnected(client))
	{
		g_hCFTimerRun[client] = null;

		return Plugin_Handled;
	}

	// Rebuild panel with new position
	Panel_RunAndWin(client);

	// When coinflip stopped end timer
	if (!g_bCFFlipping[client])
	{
		g_hCFTimerRun[client] = null;

		Store_SetClientRecurringMenu(client, false);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

// Timer to slow and stop coinflip
public Action Timer_StopCoinFlip(Handle tmr, int userid)
{
	int client = GetClientOfUserId(userid);

	// When client disconnected end timer
	if (!client || !IsClientInGame(client) || !IsClientConnected(client))
	{
		g_hCFTimerStopFlip[client] = null;

		return Plugin_Handled;
	}

	// When coinflip stopped
	if (g_bCFFlipping[client])
	{
		g_bCFFlipping[client] = false;

		delete g_hCFTimerRun[client];

		Store_SetClientRecurringMenu(client, false);

		g_hCFTimerStopFlip[client] = null;

		// Show results
		Panel_RunAndWin(client);
	}
	else g_hCFTimerStopFlip[client] = null;

	return Plugin_Handled;
}

#else

void Coinflip_OnPluginStart() {}
void Coinflip_OnClientAuthorized(int client, const char[] auth)
{
	#pragma unused client
	#pragma unused auth
}
void Coinflip_OnClientDisconnect(int client)
{
	#pragma unused client
}

#endif