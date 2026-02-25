#if STORE_MODULE_GAMBLE_ROULETTE

ConVar gc_RoulMin, gc_RoulMax, gc_RoulAutoStop, gc_RoulSpeed, gc_RoulAlive;

Handle g_hRoulTimerRun[MAXPLAYERS+1] = {null, ...};
Handle g_hRoulTimerBowlStop[MAXPLAYERS+1] = {null, ...};
int g_iRoulBet[MAXPLAYERS+1] = {-1, ...};
int g_iRoulBowlPosition[MAXPLAYERS+1] = {-1, ...};
int g_iRoulBowlSlowStop[MAXPLAYERS+1] = {-1, ...};
int g_iRoulSide[MAXPLAYERS+1] = {-1, ...};

void Roulette_OnPluginStart()
{
	RegConsoleCmd("sm_roulette", Roul_Command, "Open the Simple Roulette casino game");
	gc_RoulSpeed = CreateConVar("store_roulette_speed", "0.1", "Speed the wheel spin", _, true, 0.1, true, 0.80);
	gc_RoulAutoStop = CreateConVar("store_roulette_stop", "10.0", "Seconds a roll should auto stop", _, true, 0.0);
	gc_RoulAlive = CreateConVar("store_roulette_alive", "1", "0 - Only dead. 1 - Allow alive.", _, true, 0.0);
	gc_RoulMin = CreateConVar("store_roulette_min", "20", "Min credits", _, true, 1.0);
	gc_RoulMax = CreateConVar("store_roulette_max", "2000", "Max credits", _, true, 2.0);
	Store_BeginModuleConfig("sourcemod/store", "gamble_roulette");
	STORE_CFG("store_roulette_speed", "0.1");
	STORE_CFG("store_roulette_stop", "10.0");
	STORE_CFG("store_roulette_alive", "1");
	STORE_CFG("store_roulette_min", "20");
	STORE_CFG("store_roulette_max", "2000");
	Store_EndModuleConfig("sourcemod/store", "gamble_roulette");
}

void Roulette_OnClientAuthorized(int client, const char[] auth)
{
	#pragma unused auth
	g_iRoulBowlPosition[client] = -1;
	g_iRoulBowlSlowStop[client] = -1;
	g_iRoulBet[client] = 0;
}

void Roulette_OnClientDisconnect(int client)
{
	delete g_hRoulTimerRun[client];
	delete g_hRoulTimerBowlStop[client];
}

public Action Roul_Command(int client, int args)
{
	// Command comes from console
	if (!client)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Command is in-game only");

		return Plugin_Handled;
	}


	if (args < 1 || args > 2)
	{
		if(g_hRoulTimerRun[client] != INVALID_HANDLE || g_hRoulTimerBowlStop[client] != INVALID_HANDLE)
		{
			//delete g_hRoulTimerRun[client];
			//delete g_hTimerStopFlip[client];
			//ReplyToCommand(client, "%sDebugged", g_sChatPrefix);
			ReplyToCommand(client, "%s %t", g_sChatPrefix, "Game in progress");
		}
		else
		{
			Roul_Panel_PreRoulette(client);
			ReplyToCommand(client, "%s %t", g_sChatPrefix, "Type in chat !roulette");
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
	else if (strcmp(sBuffer,"third"))
	{
		iBet = RoundFloat(iCredits / 3.0);
	}
	else if (StrEqual(sBuffer,"quater"))
	{
		iBet = RoundFloat(iCredits / 4.0);
	}

	if (iBet < gc_RoulMin.IntValue)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "You have to spend at least x credits.", gc_RoulMin.IntValue, g_sCreditsName);

		return Plugin_Handled;
	}
	else if (iBet > gc_RoulMax.IntValue)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "You can't spend that much credits", gc_RoulMax.IntValue, g_sCreditsName);

		return Plugin_Handled;
	}

	if (iBet > iCredits)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Not enough Credits");

		return Plugin_Handled;
	}

	g_iRoulBowlPosition[client] = -1;
	g_iRoulBowlSlowStop[client] = -1;

	if (g_iRoulBowlPosition[client] < 0)
	{
		g_iRoulBowlPosition[client] = GetRandomInt(0, 184);
	}

	g_iRoulBet[client] = iBet;

	if (args == 1)
	{
		if(g_hRoulTimerRun[client] != INVALID_HANDLE || g_hRoulTimerBowlStop[client] != INVALID_HANDLE)
		{
			//delete g_hRoulTimerRun[client];
			//delete g_hTimerStopFlip[client];
			//ReplyToCommand(client, "%sDebugged", g_sChatPrefix);
			ReplyToCommand(client, "%s %t", g_sChatPrefix, "Game in progress");
		}
		else
		{
			Roul_Panel_PlaceColor(client);
		}
	}
	else if (args == 2)
	{
		if(g_hRoulTimerRun[client] != INVALID_HANDLE || g_hRoulTimerBowlStop[client] != INVALID_HANDLE)
		{
			//delete g_hRoulTimerRun[client];
			//delete g_hTimerStopFlip[client];
			//ReplyToCommand(client, "%sDebugged", g_sChatPrefix);
			ReplyToCommand(client, "%s %t", g_sChatPrefix, "Game in progress");
		}
		else
		{
			GetCmdArg(2, sBuffer, 32);
			if (StrEqual(sBuffer, "r") || StrEqual(sBuffer, "red"))
			{
				g_iRoulSide[client] = 1;
			}
			else if (StrEqual(sBuffer, "g") || StrEqual(sBuffer, "green"))
			{
				g_iRoulSide[client] = 3;
			}
			else if (StrEqual(sBuffer, "b") || StrEqual(sBuffer, "black"))
			{
				g_iRoulSide[client] = 2;
			}
			else
			{
				ReplyToCommand(client, "%s %t", g_sChatPrefix, "No matching color");

				return Plugin_Handled;
			}

			Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iRoulBet[client]);
			Roul_Start_Roulette(client);
		}
	}

	return Plugin_Handled;
}

void Roul_Panel_PreRoulette(int client)
{
	// reset bowl
	g_iRoulBowlPosition[client] = -1;
	g_iRoulBowlSlowStop[client] = -1;

	if (g_iRoulBet[client] == -1)
	{
		g_iRoulBet[client] = gc_RoulMin.IntValue;
	}

	Roul_Panel_Roulette(client);
}

// Open the start roulette panel
void Roul_Panel_Roulette(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "roulette", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// When player is first time on this game set a random bowl position
	if (g_iRoulBowlPosition[client] < 0)
	{
		g_iRoulBowlPosition[client] = GetRandomInt(0, 184);
	}

	// Show the bowl - Panel line #5-9
	Roul_PanelInject_Bowl(panel, client);


	if (!gc_RoulAlive.BoolValue && IsPlayerAlive(client))
	{
		Format(sBuffer, sizeof(sBuffer), "	\n	%t", "Must be dead");
		panel.DrawText(sBuffer);
	}
	else
	{
		//Format(sBuffer, sizeof(sBuffer), "	%t\n	%t", "Type in chat !roulette", "or use buttons below");
		//panel.DrawText(sBuffer);
	}

	panel.CurrentKey = 1;
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_RoulMin.IntValue);
	panel.DrawItem(sBuffer, iCredits < gc_RoulMin.IntValue || !gc_RoulAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 2;
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_RoulMax.IntValue ? gc_RoulMax.IntValue : iCredits);
	panel.DrawItem(sBuffer, iCredits < gc_RoulMin.IntValue || !gc_RoulAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 3;
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_RoulMin.IntValue, iCredits > gc_RoulMax.IntValue ? gc_RoulMax.IntValue : iCredits);
	panel.DrawItem(sBuffer, iCredits < gc_RoulMin.IntValue || !gc_RoulAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	
	panel.DrawText(" ");
	
	panel.CurrentKey = 5;
	//Draw item rerun when already have bet - Panel line #14 - Panel item #4
	Format(sBuffer, sizeof(sBuffer), "%t", "Rerun x Credits", g_iRoulBet[client], g_sCreditsName);
	panel.DrawItem(sBuffer, g_iRoulBet[client] > iCredits || g_iRoulBet[client] == 0 || !gc_RoulAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	
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

	panel.Send(client, Roul_Handler_Roulette, MENU_TIME_FOREVER);

	delete panel;
}

public int Roul_Handler_Roulette(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 1, 2, 3:
			{
				// Decline when player come back to life
				if (!gc_RoulAlive.BoolValue && IsPlayerAlive(client))
				{
					Roul_Panel_Roulette(client);

					#if defined _clientmod_included
						MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Must be dead CM");
						C_PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#else
						PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#endif

					//ClientCommand(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
				// show place color panel
				else
				{
					int credits = Store_GetClientCredits(client);
					switch(itemNum)
					{
						case 1: g_iRoulBet[client] = gc_RoulMin.IntValue;
						case 2: g_iRoulBet[client] = credits > gc_RoulMax.IntValue ? gc_RoulMax.IntValue : credits;
						case 3: g_iRoulBet[client] = GetRandomInt(gc_RoulMin.IntValue, credits > gc_RoulMax.IntValue ? gc_RoulMax.IntValue : credits);
					}

					Roul_Panel_PlaceColor(client);

					//ClientCommand(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
			}
			case 5:
			{
				// Decline when player come back to life
				if (!gc_RoulAlive.BoolValue && IsPlayerAlive(client))
				{
					Roul_Panel_Roulette(client);
					#if defined _clientmod_included
						MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Must be dead CM");
						C_PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#else
						PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#endif

					//ClientCommand(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
				// show place color panel
				else
				{
					Roul_Panel_PlaceColor(client);
					//ClientCommand(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
			}
			case 6:
			{
				Roul_Panel_GameInfo(client);
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
void Roul_Panel_PlaceColor(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "roulette", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// Show the bowl - Panel line #5-9
	Roul_PanelInject_Bowl(panel, client);	

	if (!gc_RoulAlive.BoolValue && IsPlayerAlive(client))
	{
		Format(sBuffer, sizeof(sBuffer), "	\n	%t", "Must be dead");
		panel.DrawText(sBuffer);
	}
	else
	{
		//Format(sBuffer, sizeof(sBuffer), "	%t\n	%t", "Type in chat !roulette", "or use buttons below");
		//panel.DrawText(sBuffer);
	}

	panel.CurrentKey = 1;
	Format(sBuffer, sizeof(sBuffer), "'████' - %t %t", "Bet on", "Red");
	panel.DrawItem(sBuffer, !gc_RoulAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 2;
	Format(sBuffer, sizeof(sBuffer), "'▒▒▒▒' - %t %t", "Bet on", "Black");
	panel.DrawItem(sBuffer, !gc_RoulAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 3;
	Format(sBuffer, sizeof(sBuffer), "'▁▁▁▁' - %t %t", "Bet on", "Green");
	panel.DrawItem(sBuffer, !gc_RoulAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	
	panel.DrawText(" ");
	panel.DrawText(" ");
	
	panel.CurrentKey = 6;
	Format(sBuffer, sizeof(sBuffer), "%t", "Game Info");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.CurrentKey = 10;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, Roul_Handler_PlaceColor, MENU_TIME_FOREVER);

	delete panel;
}

public int Roul_Handler_PlaceColor(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		// Item 1 - Roll roulette on red
		switch(itemNum)
		{
			case 1, 2, 3:
			{
				// Decline when player come back to life
				if (!gc_RoulAlive.BoolValue && IsPlayerAlive(client))
				{
					Roul_Panel_Roulette(client);

					//ClientCommand(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);

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
					if (Store_GetClientCredits(client) >= g_iRoulBet[client])
					{
						switch(itemNum)
						{
							case 1: g_iRoulSide[client] = 1;
							case 2: g_iRoulSide[client] = 2;
							case 3: g_iRoulSide[client] = 3;
						}

						Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iRoulBet[client]);
						Roul_Start_Roulette(client);
					}
					// when player has yet had not enough Credits (double check)
					else
					{
						//ClientCommand(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);
						Roul_Panel_Roulette(client);

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
				Roul_Panel_GameInfo(client);
				//ClientCommand(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			case 8:
			{
				Roul_Panel_Roulette(client);
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

void Roul_Start_Roulette(int client)
{
	g_iRoulBowlSlowStop[client] = -1;

	// end possible still running timers
	delete g_hRoulTimerBowlStop[client];
	delete g_hRoulTimerRun[client];
	//Store_SetClientRecurringMenu(client, true);

	//play a start sound
	//ClientCommand(client, "play %s", g_sMenuItem);
	EmitSoundToClient(client, g_sMenuItem);

	g_hRoulTimerRun[client] = CreateTimer(gc_RoulSpeed.FloatValue, Roul_Timer_Run, GetClientUserId(client), TIMER_REPEAT); // run speed for all rolls
	TriggerTimer(g_hRoulTimerRun[client]);

	g_hRoulTimerBowlStop[client] = CreateTimer(Roul_GetAutoStopTime(), Roul_Timer_StopBowl, GetClientUserId(client)); // stop first roll
}

void Roul_Panel_RunAndWin(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "roulette", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// When bowl is running step postion by one
	if (g_iRoulBowlSlowStop[client] < 3)
	{
		switch(g_iRoulBowlSlowStop[client])
		{
			case -1: g_iRoulBowlPosition[client] += 4;
			case 1: g_iRoulBowlPosition[client] += 2;
			case 2: g_iRoulBowlPosition[client] += 1;
		}

		if (g_iRoulBowlPosition[client] > 184)
		{
			g_iRoulBowlPosition[client] = 0;
		}
	}

	// Show the bowl - Panel line #5-9
	Roul_PanelInject_Bowl(panel, client);

	// When bowl is still running
	if (g_iRoulBowlSlowStop[client] < 3)
	{
		// Draw the placed bet
		Format(sBuffer, sizeof(sBuffer), "	%t", "Your bet", g_iRoulBet[client], g_sCreditsName);
		panel.DrawText(sBuffer);

		// Draw Spacer item - Panel line #12 - Panel item #3
		panel.DrawText(" ");

		// Draw the placed color
		switch(g_iRoulSide[client])
		{
			case 1: Format(sBuffer, sizeof(sBuffer), "	%t '████' %t", "Bet on", "Red");
			case 2: Format(sBuffer, sizeof(sBuffer), "	%t '▒▒▒▒' %t", "Bet on", "Black");
			case 3: Format(sBuffer, sizeof(sBuffer), "	%t '▁▁▁▁' %t", "Bet on", "Green");
		}
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
	}
	// When bowl has stopped
	else
	{
		// Set color order - like above
		char sColor[256] = "==== #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** ==== #### **** #### ****";

		// Get postion of mid indicator
		char short[2];
		Format(short, sizeof(short), sColor[g_iRoulBowlPosition[client]+12]);

		// When indicator is between two fields turn the bowl one 'tick'(character) forward and show panel again.
		if (StrEqual(short, " "))
		{
			g_iRoulBowlPosition[client]++;
			if (g_iRoulBowlPosition[client] > 184)
			{
				g_iRoulBowlPosition[client] = 0;
			}

			Roul_Panel_RunAndWin(client);

			delete panel;
			return;
		}

		// If indicator is on choosen color -> WIN
		if ((StrEqual(short, "*") && g_iRoulSide[client] == 1) || (StrEqual(short, "#") && g_iRoulSide[client] == 2) || (StrEqual(short, "=") && g_iRoulSide[client] == 3) )
		{
			//Replace indicator position with prettier prompt
			char shorti[24];
			Format(shorti, sizeof(shorti), short);
			ReplaceString(shorti, sizeof(shorti), "=", "'▁▁▁▁' green", false);
			ReplaceString(shorti, sizeof(shorti), "*", "'████' red", false);
			ReplaceString(shorti, sizeof(shorti), "#", "'▒▒▒▒' black", false);

			// Build & draw won text - Panel line #12
			Format(sBuffer, sizeof(sBuffer), "	%t %s", "You won with", shorti);
			panel.DrawText(sBuffer);

			// Draw Spacer Line - Panel line #13
			panel.DrawText(" ");

			// Build & draw text - Panel line #14
			Format(sBuffer, sizeof(sBuffer), "	%t", "You win x Credits", g_iRoulSide[client] < 3 ? (g_iRoulBet[client] * 2) : (g_iRoulBet[client] * 14), g_sCreditsName);
			panel.DrawText(sBuffer);

			panel.DrawText(" ");
			// Process the won Credits & remaining notfiction
			Roul_ProcessWin(client, g_iRoulBet[client], g_iRoulSide[client] < 3 ? 2 : 14);


		}
		// Player has not won -> Show start panel
		else
		{
			//Roul_Panel_Roulette(client);

			//delete panel;
			//return;
			
			switch(g_iRoulSide[client])
			{
				case 1: Format(sBuffer, sizeof(sBuffer), "	%t '████' %t", "You lost with", "Red");
				case 2: Format(sBuffer, sizeof(sBuffer), "	%t '▒▒▒▒' %t", "You lost with", "Black");
				case 3: Format(sBuffer, sizeof(sBuffer), "	%t '▁▁▁▁' %t", "You lost with", "Green");
			}

			// Build & draw won text - Panel line #12
			//Format(sBuffer, sizeof(sBuffer), "	%t %s", "You lost with", shorti);
			panel.DrawText(sBuffer);

			// Draw Spacer Line - Panel line #13
			panel.DrawText(" ");

			// Build & draw text - Panel line #14
			Format(sBuffer, sizeof(sBuffer), "	%t", "You lost x Credits", g_iRoulBet[client], g_sCreditsName);
			panel.DrawText(sBuffer);

			panel.DrawText(" ");
			
			Format(sBuffer, sizeof(sBuffer), "%t", "roulette");
			#if defined _clientmod_included
				MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Player lost x Credits CM", client, g_iRoulBet[client], g_sCreditsName, sBuffer);
				C_PrintToChatAll("%s %t", g_sChatPrefix, "Player lost x Credits", client, g_iRoulBet[client], g_sCreditsName, sBuffer);
			#else
				PrintToChatAll("%s %t", g_sChatPrefix, "Player lost x Credits", client, g_iRoulBet[client], g_sCreditsName, sBuffer);
			#endif
		}
	}
	panel.DrawText(" ");
	panel.CurrentKey = 5;
	//Draw item rerun when already have bet - Panel line #14 - Panel item #4
	Format(sBuffer, sizeof(sBuffer), "%t", "Rerun x Credits", g_iRoulBet[client], g_sCreditsName);
	panel.DrawItem(sBuffer, g_iRoulBet[client] > iCredits || g_iRoulBowlSlowStop[client] < 3 || !gc_RoulAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	//Draw item info - Panel line #15 - Panel item #5
	
	panel.DrawText(" ");
	
	panel.CurrentKey = 6;
	Format(sBuffer, sizeof(sBuffer), "%t", "Game Info");
	panel.DrawItem(sBuffer, g_iRoulBowlSlowStop[client] < 3 ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, g_iRoulBowlSlowStop[client] < 3 ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 10;
	Format(sBuffer, sizeof(sBuffer), "%t", g_iRoulBowlSlowStop[client] < 3 ? "Cancel" : "Exit");
	panel.DrawItem(sBuffer);

	panel.Send(client, Roul_Handler_WheelRun, MENU_TIME_FOREVER);

	delete panel;
}

public int Roul_Handler_WheelRun(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			// Item 4 - Rerun bet
			case 5:
			{
				// Decline when player come back to life
				if (!gc_RoulAlive.BoolValue && IsPlayerAlive(client))
				{
					Roul_Panel_Roulette(client);
					#if defined _clientmod_included
						MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Must be dead CM");
						C_PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#else
						PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#endif

					//ClientCommand(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
				// show place color panel
				else
				{
					Roul_Panel_PlaceColor(client);
					//ClientCommand(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
			}
			case 6:
			{
				Roul_Panel_GameInfo(client);
				//ClientCommand(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			// Item 8 - go back to casino
			case 8:
			{
				Roul_Panel_Roulette(client);

				//ClientCommand(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
			}
			// Item 10 - exit cancel
			case 10:
			{
				delete g_hRoulTimerRun[client];
				delete g_hRoulTimerBowlStop[client];
				//Store_SetClientRecurringMenu(client, false);

				if (g_iRoulBowlSlowStop[client] < 3)
				{
					Roul_Panel_Roulette(client);
				}

				g_iRoulBowlSlowStop[client] = -1;
				//ClientCommand(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
	
	return 0;
}

// Inject the bowl into panels
void Roul_PanelInject_Bowl(Panel panel, int client)
{
	char sBuffer[256];
	
	// This are your roulette fields. We need '=' '*' & '#' as placeholder cause the '▁' '█' & '▒' ascii symbols would screw up the bowl postion due to their bigger size in arrays
	char sNumber[PLATFORM_MAX_PATH];
	Format(sNumber, sizeof(sNumber), "==0= #26# **3* #35# *12* #28# **7* #29# *18* #22# **9* #31# *14* #20# **1* #33# *16* #24# **5* #10# *23* ##8# *30* #11# *36* #13# *27* ##6# *34* #17# *25* ##2# *21* ##4# *19* #15# *32* ==0= #26# **3* #35# *12*");
	
	char sColor[PLATFORM_MAX_PATH];
	Format(sColor, sizeof(sColor), "==== #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** #### **** ==== #### **** #### ****");
	
	panel.DrawText(" ");
	// Draw the position indicator in top mid
	Format(sBuffer, sizeof(sBuffer), "						 ⮟");
	panel.DrawText(sBuffer);

	// Set the buffer at players bowlposition and cut the remaining fields
	char sShortener[26];
	Format(sShortener, sizeof(sShortener), sColor[g_iRoulBowlPosition[client]]);
	Format(sBuffer, sizeof(sBuffer), sShortener);

	// Replace the = * # placeholder in buffer
	ReplaceString(sBuffer, sizeof(sBuffer), "=", "▁", false);
	ReplaceString(sBuffer, sizeof(sBuffer), "*", "█", false);
	ReplaceString(sBuffer, sizeof(sBuffer), "#", "▒", false);

	//Draw the first line with color
	Format(sBuffer, sizeof(sBuffer), "   |%s|", sBuffer);
	panel.DrawText(sBuffer);

	// Set the buffer at players bowlposition and cut the remaining fields
	Format(sShortener, sizeof(sShortener), sNumber[g_iRoulBowlPosition[client]]);
	Format(sBuffer, sizeof(sBuffer), sShortener);

	// Replace the '=' '*' & '#' placeholder in buffer
	ReplaceString(sBuffer, sizeof(sBuffer), "=", "▁", false);
	ReplaceString(sBuffer, sizeof(sBuffer), "*", "█", false);
	ReplaceString(sBuffer, sizeof(sBuffer), "#", "▒", false);

	//Draw the second line with numbers
	Format(sBuffer, sizeof(sBuffer), "   |%s|", sBuffer);
	panel.DrawText(sBuffer);

	// Set the buffer at players bowlposition and cut the remaining fields
	Format(sShortener, sizeof(sShortener), sColor[g_iRoulBowlPosition[client]]);
	Format(sBuffer, sizeof(sBuffer), sShortener);

	// Replace the '=' '*' & '#' placeholder in buffer
	ReplaceString(sBuffer, sizeof(sBuffer), "=", "▁", false);
	ReplaceString(sBuffer, sizeof(sBuffer), "*", "█", false);
	ReplaceString(sBuffer, sizeof(sBuffer), "#", "▒", false);

	//Draw the third line with color
	Format(sBuffer, sizeof(sBuffer), "   |%s|", sBuffer);
	panel.DrawText(sBuffer);

	// Draw the position indicator in bottom mid
	Format(sBuffer, sizeof(sBuffer), "						 ⮝");
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
}


/******************************************************************************
				   functions
******************************************************************************/

//Randomize the stop time to the next number isn't predictable
float Roul_GetAutoStopTime()
{
	return GetRandomFloat(gc_RoulAutoStop.FloatValue/2 - 0.8, gc_RoulAutoStop.FloatValue/2 + 1.2);
}

void Roul_ProcessWin(int client, int bet, int multiply)
{
	char sBuffer[255];
	int iProfit = bet * multiply;

	// Add profit to balance
	Store_SetClientCredits(client, Store_GetClientCredits(client) + iProfit);

	// Play sound and notify other player abot this win
	Format(sBuffer, sizeof(sBuffer), "%t", "roulette");
	#if defined _clientmod_included
		MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Player won x Credits CM", client, iProfit, g_sCreditsName, sBuffer);
		C_PrintToChatAll("%s %t", g_sChatPrefix, "Player won x Credits", client, iProfit, g_sCreditsName, sBuffer);
	#else
		PrintToChatAll("%s %t", g_sChatPrefix, "Player won x Credits", client, iProfit, g_sCreditsName, sBuffer);
	#endif

	//ClientCommand(client, "play %s", g_sMenuItem);
	EmitSoundToClient(client, g_sMenuItem);
}

/******************************************************************************
				   Panel
******************************************************************************/

//Show the games info panel
void Roul_Panel_GameInfo(int client)
{
	char sBuffer[255];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	//Build the panel title three lines high - Panel line #1-3
	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "roulette", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// Draw Spacer Line - Panel line #4
	panel.DrawText(" ");
	panel.DrawText(" ");


	Format(sBuffer, sizeof(sBuffer), "	%t", "Bet on a color");
	panel.DrawText(" ");
	panel.DrawText(" ");

	// Draw info Line 1 - Panel line #7
	Format(sBuffer, sizeof(sBuffer), "	%s %t %i", "  '▒▒▒▒' black = ", "bet x", 2);
	panel.DrawText(sBuffer);
	panel.DrawText(" ");

	panel.DrawText(" ");
	// Draw info Line 2 - Panel line #8
	Format(sBuffer, sizeof(sBuffer), "	%s %t %i", "  '████' red = ", "bet x", 2);
	panel.DrawText(sBuffer);

	panel.DrawText(" ");
	panel.DrawText(" ");
	// Draw info Line 3 - Panel line #9
	Format(sBuffer, sizeof(sBuffer), "	%s %t %i", "  '▁▁▁▁' green = ", "bet x", 14);
	panel.DrawText(sBuffer);


	// Draw Spacer item - Panel line #11 - Panel item #1
	panel.DrawText(" ");

	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.CurrentKey = 10;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, Roul_Handler_WheelRun, 14);

	delete panel;
}

/******************************************************************************
				   Timer
******************************************************************************/

// The game runs and roll the bowl
public Action Roul_Timer_Run(Handle tmr, int userid)
{
	int client = GetClientOfUserId(userid);

	// When client disconnected end timer
	if (!client || !IsClientInGame(client) || !IsClientConnected(client))
	{
		g_hRoulTimerRun[client] = null;

		return Plugin_Handled;
	}

	// Rebuild panel with new position
	Roul_Panel_RunAndWin(client);

	// When bowl stopped end timer
	if (g_iRoulBowlSlowStop[client] > 2)
	{
		g_hRoulTimerRun[client] = null;
		////Store_SetClientRecurringMenu(client, false);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

// Timer to slow and stop bowl
public Action Roul_Timer_StopBowl(Handle tmr, int userid)
{
	int client = GetClientOfUserId(userid);

	// When client disconnected end timer
	if (!client || !IsClientInGame(client) || !IsClientConnected(client))
	{
		g_hRoulTimerBowlStop[client] = null;

		return Plugin_Handled;
	}

	switch(g_iRoulBowlSlowStop[client])
	{
		// When Bowl is running, slow down bowl
		case -1:
		{
			g_iRoulBowlSlowStop[client] = 1;

			delete g_hRoulTimerRun[client];

			g_hRoulTimerRun[client] = CreateTimer(gc_RoulSpeed.FloatValue, Roul_Timer_Run, GetClientUserId(client), TIMER_REPEAT); // run speed for all rolls
			g_hRoulTimerBowlStop[client] = CreateTimer(Roul_GetAutoStopTime(), Roul_Timer_StopBowl, GetClientUserId(client)); // stop second roll
		}
		// When Bowl is still running and was already slowed, slow down bowl
		case 1: // when first roll stopped
		{
			g_iRoulBowlSlowStop[client] = 2;

			delete g_hRoulTimerRun[client];

			g_hRoulTimerRun[client] = CreateTimer(gc_RoulSpeed.FloatValue, Roul_Timer_Run, GetClientUserId(client), TIMER_REPEAT); // run speed for all rolls
			g_hRoulTimerBowlStop[client] = CreateTimer(Roul_GetAutoStopTime(), Roul_Timer_StopBowl, GetClientUserId(client)); // stop third roll
		}
		// When Bowl is running and was already slowed twice, end bowl
		case 2:
		{
			// Stop bowl
			g_iRoulBowlSlowStop[client] = 3;

			delete g_hRoulTimerRun[client];
			////Store_SetClientRecurringMenu(client, false);

			g_hRoulTimerBowlStop[client] = null;

			// Show results
			Roul_Panel_RunAndWin(client);
		}
		default: g_hRoulTimerBowlStop[client] = null;
	}

	return Plugin_Handled;
}

#else
void Roulette_OnPluginStart() {}
void Roulette_OnClientAuthorized(int client, const char[] auth)
{
	#pragma unused client
	#pragma unused auth
}
void Roulette_OnClientDisconnect(int client)
{
	#pragma unused client
}
#endif