#if STORE_MODULE_GAMBLE_DICE

ConVar gc_DiceMin, gc_DiceMax, gc_DiceAutoStop, gc_DiceSpeed, gc_DiceAlive;
ConVar gc_DiceBonus, gc_DiceBonusRatio, gc_DiceBonusRatioAmount;

Handle g_hDiceTimerRun[MAXPLAYERS+1] = {null, ...};
Handle g_hDiceTimerStopFlip[MAXPLAYERS+1] = {null, ...};
bool g_bDiceFlipping[MAXPLAYERS+1] = {false, ...};
int g_iDiceBet[MAXPLAYERS+1] = {-1, ...};
int g_iDicePosition[MAXPLAYERS+1] = {-1, ...};
int g_iDiceDiceBet[MAXPLAYERS+1] = {-1, ...};

void Dice_OnPluginStart()
{
	RegConsoleCmd("sm_dice", Dice_Command, "Open the Dice casino game");
	gc_DiceSpeed = CreateConVar("store_dice_speed", "0.1", "Speed the wheel spin", _, true, 0.1, true, 0.80);
	gc_DiceAutoStop = CreateConVar("store_dice_stop", "10.0", "Seconds a roll should auto stop", _, true, 0.0);
	gc_DiceAlive = CreateConVar("store_dice_alive", "1", "0 - Only dead player can start. 1 - Allow alive.", _, true, 0.0);
	gc_DiceMin = CreateConVar("store_dice_min", "20", "Min credits", _, true, 1.0);
	gc_DiceMax = CreateConVar("store_dice_max", "2000", "Max credits", _, true, 2.0);
	gc_DiceBonus = CreateConVar("store_dice_bonus", "1", "Enable bonus", _, true, 0.0, true, 1.0);
	gc_DiceBonusRatio = CreateConVar("store_dice_bonus_ratio", "0.75", "Min % of max bet for bonus");
	gc_DiceBonusRatioAmount = CreateConVar("store_dice_bonus_ratio_amount", "0.5", "Bonus ratio");
	Store_BeginModuleConfig("sourcemod/store", "gamble_dice");
	STORE_CFG("store_dice_speed", "0.1");
	STORE_CFG("store_dice_stop", "10.0");
	STORE_CFG("store_dice_alive", "1");
	STORE_CFG("store_dice_min", "20");
	STORE_CFG("store_dice_max", "2000");
	STORE_CFG("store_dice_bonus", "1");
	STORE_CFG("store_dice_bonus_ratio", "0.75");
	STORE_CFG("store_dice_bonus_ratio_amount", "0.5");
	Store_EndModuleConfig("sourcemod/store", "gamble_dice");
}

void Dice_OnClientAuthorized(int client, const char[] auth)
{
	#pragma unused auth
	g_iDicePosition[client] = -1;
	g_bDiceFlipping[client] = false;
	g_iDiceDiceBet[client] = 0;
}

void Dice_OnClientDisconnect(int client)
{
	delete g_hDiceTimerRun[client];
	delete g_hDiceTimerStopFlip[client];
}

public Action Dice_Command(int client, int args)
{
	// Command comes from console
	if (!client)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Command is in-game only");

		return Plugin_Handled;
	}

	if (args < 1 || args > 2)
	{
		if(g_hDiceTimerRun[client] != INVALID_HANDLE || g_hDiceTimerStopFlip[client] != INVALID_HANDLE)
		{
			//delete g_hDiceTimerRun[client];
			//delete g_hDiceTimerStopFlip[client];
			//CReplyToCommand(client, "%sDebugged", g_sChatPrefix);
			ReplyToCommand(client, "%s %t", g_sChatPrefix, "Game in progress");
		}
		else
		{
			Panel_PreDice(client);
			ReplyToCommand(client, "%s %t", g_sChatPrefix, "Type in chat !dice");
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
	else if (StrEqual(sBuffer,"half"))
	{
		iBet = RoundFloat(iCredits / 2.0);
	}
	else if (StrEqual(sBuffer,"third"))
	{
		iBet = RoundFloat(iCredits / 3.0);
	}
	else if (StrEqual(sBuffer,"quater"))
	{
		iBet = RoundFloat(iCredits / 4.0);
	}

	if (iBet < gc_DiceMin.IntValue)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "You have to spend at least x credits.", gc_DiceMin.IntValue, g_sCreditsName);

		return Plugin_Handled;
	}
	else if (iBet > gc_DiceMax.IntValue)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "You can't spend that much credits", gc_DiceMax.IntValue, g_sCreditsName);

		return Plugin_Handled;
	}

	if (iBet > iCredits)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Not enough Credits");

		return Plugin_Handled;
	}

	//g_bDiceFlipping[client] = false;

	g_iDiceBet[client] = iBet;

	if (args == 1)
	{
		if(g_hDiceTimerRun[client] != INVALID_HANDLE || g_hDiceTimerStopFlip[client] != INVALID_HANDLE)
		{
			//delete g_hDiceTimerRun[client];
			//delete g_hDiceTimerStopFlip[client];
			//CReplyToCommand(client, "%sDebugged", g_sChatPrefix);
			ReplyToCommand(client, "%s %t", g_sChatPrefix, "Game in progress");
		}
		else
		{
			Dice_Panel_ChooseNum(client);
		}
	}
	else if (args == 2)
	{
		if(g_hDiceTimerRun[client] != INVALID_HANDLE || g_hDiceTimerStopFlip[client] != INVALID_HANDLE)
		{
			//delete g_hDiceTimerRun[client];
			//delete g_hDiceTimerStopFlip[client];
			//CReplyToCommand(client, "%sDebugged", g_sChatPrefix);
			ReplyToCommand(client, "%s %t", g_sChatPrefix, "Game in progress");
		}
		else
		{
			GetCmdArg(2, sBuffer, 32);
			int iNum = StringToInt(sBuffer);
			switch(iNum)
			{
				case 1, 2, 3, 4, 5, 6: g_iDiceDiceBet[client] = iNum;
				default:
				{
					if (sBuffer[0] == 'l')
					{
						g_iDiceDiceBet[client] = 0;
					}
					else if (sBuffer[0] == 'h')
					{
						g_iDiceDiceBet[client] = 7;
					}
					else
					{
						ReplyToCommand(client, "%s %t", g_sChatPrefix, "Type in chat !dice");

						return Plugin_Handled;
					}
				}
			}

			Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iDiceBet[client]);
			Dice_Start_Dice(client);
		}
	}

	return Plugin_Handled;
}

void Panel_PreDice(int client)
{
	// reset dice
	g_iDicePosition[client] = GetRandomInt(1,6);
	g_bDiceFlipping[client] = false;

	if (g_iDiceBet[client] == -1)
	{
		g_iDiceBet[client] = gc_DiceMin.IntValue;
	}

	Dice_Panel_Dice(client);
}

// Open the start dice panel
void Dice_Panel_Dice(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%s:%i", "dice", g_sCreditsName, iCredits);
	panel.SetTitle(sBuffer);

	Dice_PanelInject_Dice(panel, client);
	panel.DrawText(" ");

	if (!gc_DiceAlive.BoolValue && IsPlayerAlive(client))
	{
		Format(sBuffer, sizeof(sBuffer), "	\n	%t", "Must be dead");
		panel.DrawText(sBuffer);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "	%t\n	%t", "Type in chat !dice", "or use buttons below");
		panel.DrawText(sBuffer);
	}
	panel.DrawText(" ");

	panel.CurrentKey = 1;
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_DiceMin.IntValue);
	panel.DrawItem(sBuffer, iCredits < gc_DiceMin.IntValue || !gc_DiceAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 2;
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_DiceMax.IntValue ? gc_DiceMax.IntValue : iCredits);
	panel.DrawItem(sBuffer, iCredits < gc_DiceMin.IntValue || !gc_DiceAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 3;
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_DiceMin.IntValue, iCredits > gc_DiceMax.IntValue ? gc_DiceMax.IntValue : iCredits);
	panel.DrawItem(sBuffer, iCredits < gc_DiceMin.IntValue || !gc_DiceAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	
	panel.DrawText(" ");
	
	panel.CurrentKey = 5;
	Format(sBuffer, sizeof(sBuffer), "%t", "Rerun x Credits", g_iDiceBet[client], g_sCreditsName);
	panel.DrawItem(sBuffer, g_iDiceBet[client] > iCredits || g_iDiceBet[client] > 0 || !gc_DiceAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

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

	panel.Send(client, Dice_Handler_Dice, MENU_TIME_FOREVER);

	delete panel;
}

public int Dice_Handler_Dice(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 1, 2, 3:
			{
				// Decline when player come back to life
				int credits = Store_GetClientCredits(client);
				if (!gc_DiceAlive.BoolValue && IsPlayerAlive(client))
				{
					Dice_Panel_Dice(client);

					#if defined _clientmod_included
						MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Must be dead CM");
						C_PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#else
						PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#endif


					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
				else
				{
					switch(itemNum)
					{
						case 1: g_iDiceBet[client] = gc_DiceMin.IntValue;
						case 2: g_iDiceBet[client] = credits > gc_DiceMax.IntValue ? gc_DiceMax.IntValue : credits;
						case 3: g_iDiceBet[client] = GetRandomInt(gc_DiceMin.IntValue, credits > gc_DiceMax.IntValue ? gc_DiceMax.IntValue : credits);
					}

					Dice_Panel_ChooseNum(client);

					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
			}
			case 5:
			{
				// Decline when player come back to life
				if (!gc_DiceAlive.BoolValue && IsPlayerAlive(client))
				{
					Dice_Panel_Dice(client);
					#if defined _clientmod_included
						MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Must be dead CM");
						C_PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#else
						PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#endif


					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
				// show place color panel
				else
				{
					Dice_Panel_ChooseNum(client);
					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
			}
			case 6:
			{
				Dice_Panel_GameInfo(client);
				//FakeClientCommandEx(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			case 8:
			{
				//FakeClientCommandEx(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
				Store_DisplayPreviousMenu(client);
			}
			case 10: 
			{
				//FakeClientCommandEx(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
	
	return 0;
}

// Open the choose color panel
void Dice_Panel_ChooseNum(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "dice", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	Dice_PanelInject_Dice(panel, client);	
	panel.DrawText(" ");
	if (!gc_DiceAlive.BoolValue && IsPlayerAlive(client))
	{
		Format(sBuffer, sizeof(sBuffer), "	\n	%t", "Must be dead");
		panel.DrawText(sBuffer);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "	%t\n	%t", "Type in chat !dice", "or use buttons below");
		panel.DrawText(sBuffer);
	}
	panel.DrawText(" ");

	panel.CurrentKey = 1;
	Format(sBuffer, sizeof(sBuffer), "%t %t", "Bet on", "Low - #1-3 (1:2)");
	panel.DrawItem(sBuffer, !gc_DiceAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 2;
	Format(sBuffer, sizeof(sBuffer), "%t %t", "Bet on", "High - #4-6 (1:2)");
	panel.DrawItem(sBuffer, !gc_DiceAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT); //translate

	panel.CurrentKey = 3;
	Format(sBuffer, sizeof(sBuffer), "%t", "Choose Number (1:6)");
	panel.DrawItem(sBuffer, !gc_DiceAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

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

	panel.Send(client, Dice_Handler_PlaceColor, MENU_TIME_FOREVER);

	delete panel;
}

public int Dice_Handler_PlaceColor(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 1, 2:
			{
				// Decline when player come back to life
				if (!gc_DiceAlive.BoolValue && IsPlayerAlive(client))
				{
					Dice_Panel_Dice(client);

					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
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
					int iCredits = Store_GetClientCredits(client);
					if (iCredits >= g_iDiceBet[client])
					{
						switch(itemNum)
						{
							case 1: g_iDiceDiceBet[client] = 0;
							case 2: g_iDiceDiceBet[client] = 7;
						}

						Store_SetClientCredits(client, iCredits - g_iDiceBet[client]);
						Dice_Start_Dice(client);
					}
					// when player has yet had not enough Credits (double check)
					else
					{
						//FakeClientCommandEx(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);
						Dice_Panel_Dice(client);

						#if defined _clientmod_included
							MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Not enough Credits CM");
							C_PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
						#else
							PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
						#endif

					}
				}
			}
			case 3:
			{
				Dice_Panel_ChooseNumber(client);
				//FakeClientCommandEx(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			case 6:
			{
				Dice_Panel_GameInfo(client);
				//FakeClientCommandEx(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			case 8:
			{
				Dice_Panel_Dice(client);
				//FakeClientCommandEx(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
			}
			case 10: 
			{
				//FakeClientCommandEx(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
	
	return 0;
}

// Open the choose color panel
void Dice_Panel_ChooseNumber(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "dice", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	Dice_PanelInject_Dice(panel, client);

	if (!gc_DiceAlive.BoolValue && IsPlayerAlive(client))
	{
		Format(sBuffer, sizeof(sBuffer), "	\n	%t", "Must be dead");
		panel.DrawText(sBuffer);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "	%t\n	%t", "Type in chat !dice", "or use buttons below");
		panel.DrawText(sBuffer);
	}

	panel.CurrentKey = 1;
	Format(sBuffer, sizeof(sBuffer), "%t #1", "Bet on");
	panel.DrawItem(sBuffer, !gc_DiceAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 2;
	Format(sBuffer, sizeof(sBuffer), "%t #2", "Bet on");
	panel.DrawItem(sBuffer, !gc_DiceAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 3;
	Format(sBuffer, sizeof(sBuffer), "%t #3", "Bet on");
	panel.DrawItem(sBuffer, !gc_DiceAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 4;
	Format(sBuffer, sizeof(sBuffer), "%t #4", "Bet on");
	panel.DrawItem(sBuffer, !gc_DiceAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 5;
	Format(sBuffer, sizeof(sBuffer), "%t #5", "Bet on");
	panel.DrawItem(sBuffer, !gc_DiceAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 6;
	Format(sBuffer, sizeof(sBuffer), "%t #6", "Bet on");
	panel.DrawItem(sBuffer, !gc_DiceAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	panel.DrawText(" ");
	panel.CurrentKey = 7;
	Format(sBuffer, sizeof(sBuffer), "%t", "Game Info");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.CurrentKey = 10;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, Dice_Handler_Num, MENU_TIME_FOREVER);

	delete panel;
}

public int Dice_Handler_Num(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		// Item 1 - Roll dice on red
		switch(itemNum)
		{
			case 1, 2, 3, 4, 5, 6:
			{
				// Decline when player come back to life
				if (!gc_DiceAlive.BoolValue && IsPlayerAlive(client))
				{
					Dice_Panel_Dice(client);

					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
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
					if (Store_GetClientCredits(client) >= g_iDiceBet[client])
					{
						g_iDiceDiceBet[client] = itemNum;

						Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iDiceBet[client]);
						Dice_Start_Dice(client);
					}
					// when player has yet had not enough Credits (double check)
					else
					{
						//FakeClientCommandEx(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);
						Dice_Panel_Dice(client);

						#if defined _clientmod_included
							MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Not enough Credits CM");
							C_PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
						#else
							PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
						#endif
					}
				}
			}
			case 7:
			{
				Dice_Panel_GameInfo(client);
				//FakeClientCommandEx(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			case 8:
			{
				Dice_Panel_Dice(client);
				//FakeClientCommandEx(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
			}
			case 10:
			{
				//FakeClientCommandEx(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
	
	return 0;
}

void Dice_Start_Dice(int client)
{
	g_bDiceFlipping[client] = true;

	// end possible still running timers
	delete g_hDiceTimerStopFlip[client];
	delete g_hDiceTimerRun[client];
	Store_SetClientRecurringMenu(client, true);

	//play a start sound
	//FakeClientCommandEx(client, "play %s", g_sMenuItem);
	EmitSoundToClient(client, g_sMenuItem);

	g_hDiceTimerRun[client] = CreateTimer(gc_DiceSpeed.FloatValue, Dice_Timer_Run, GetClientUserId(client), TIMER_REPEAT); // run speed for all rolls
	TriggerTimer(g_hDiceTimerRun[client]);

	g_hDiceTimerStopFlip[client] = CreateTimer(Dice_GetAutoStopTime(), Dice_Timer_StopDice, GetClientUserId(client)); // stop first roll
}

void Dice_Panel_RunAndWin(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "dice", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// When dice is running step postion by one
	if (g_bDiceFlipping[client])
	{
		int random = GetRandomInt(1,6);
		while (random == g_iDicePosition[client])
		{
			random = GetRandomInt(1,6);
		}
		g_iDicePosition[client] = random;
	}

	Dice_PanelInject_Dice(panel, client);
	panel.DrawText(" ");
	// When dice is still running
	if (g_bDiceFlipping[client])
	{
		// Draw the placed bet
		Format(sBuffer, sizeof(sBuffer), "	%t", "Your bet", g_iDiceBet[client], g_sCreditsName);
		panel.DrawText(sBuffer);

		panel.DrawText(" ");


		switch(g_iDiceDiceBet[client])
		{
			case 0: Format(sBuffer, sizeof(sBuffer), "	%t %t", "Bet on", "Low #1-3");
			case 1, 2, 3, 4, 5, 6: Format(sBuffer, sizeof(sBuffer), "	%t #%i", "Bet on", g_iDiceDiceBet[client]);
			case 7: Format(sBuffer, sizeof(sBuffer), "	%t %t", "Bet on", "High #4-6");
		}
		panel.DrawText(sBuffer);
		panel.DrawText(" ");

		panel.DrawText(" ");
	}
	else
	{
		// If indicator is on choosen color -> WIN
		if ((g_iDiceDiceBet[client] == 0 && g_iDicePosition[client] < 4) || (g_iDiceDiceBet[client] == 7 && g_iDicePosition[client] > 3))
		{
			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "	%t %s", "You won with", g_iDiceDiceBet[client] < 4 ? "Low" : "High");
			panel.DrawText(sBuffer);

			panel.DrawText(" ");

			Format(sBuffer, sizeof(sBuffer), "	%t", "You win x Credits", g_iDiceBet[client] * 2, g_sCreditsName);
			panel.DrawText(sBuffer);

			panel.DrawText(" ");
			panel.DrawText(" ");
			// Process the won Credits & remaining notfiction
			Dice_ProcessWin(client, g_iDiceBet[client], 2);
		}
		else if (g_iDiceDiceBet[client] == g_iDicePosition[client])
		{
			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "	%t #%i", "You won with", g_iDiceDiceBet[client]);
			panel.DrawText(sBuffer);

			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "	%t", "You win x Credits", g_iDiceBet[client] * 6, g_sCreditsName);
			panel.DrawText(sBuffer);
			panel.DrawText(" ");
			panel.DrawText(" ");

			// Process the won token & remaining notfiction
			Dice_ProcessWin(client, g_iDiceBet[client], 6);

			panel.DrawItem(sBuffer, ITEMDRAW_SPACER);
		}
		// Player has not won -> Show start panel
		else
		{
			//Dice_Panel_Dice(client);

			//delete panel;
			//return;
			panel.DrawText(" ");
			switch(g_iDiceDiceBet[client])
			{
				case 0: Format(sBuffer, sizeof(sBuffer), "	%t %t", "You lost with", "Low #1-3");
				case 1, 2, 3, 4, 5, 6: Format(sBuffer, sizeof(sBuffer), "	%t #%i", "You lost with", g_iDiceDiceBet[client]);
				case 7: Format(sBuffer, sizeof(sBuffer), "	%t %t", "You lost with", "High #4-6");
			}
			panel.DrawText(sBuffer);
			
			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "	%t", "You lost x Credits", g_iDiceBet[client], g_sCreditsName);
			panel.DrawText(sBuffer);
			panel.DrawText(" ");
			panel.DrawText(" ");

			// Process the won token & remaining notfiction
			//Dice_ProcessWin(client, g_iDiceBet[client], 6);

			panel.DrawItem(sBuffer, ITEMDRAW_SPACER);
			
			Format(sBuffer, sizeof(sBuffer), "%t", "dice");
			#if defined _clientmod_included
				MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Player lost x Credits CM", client, g_iDiceBet[client], g_sCreditsName, sBuffer);
				C_PrintToChatAll("%s %t", g_sChatPrefix, "Player lost x Credits", client, g_iDiceBet[client], g_sCreditsName, sBuffer);
			#else
				PrintToChatAll("%s %t", g_sChatPrefix, "Player lost x Credits", client, g_iDiceBet[client], g_sCreditsName, sBuffer);
			#endif
		}
	}

	panel.CurrentKey = 5;
	Format(sBuffer, sizeof(sBuffer), "%t", "Rerun x Credits", g_iDiceBet[client], g_sCreditsName);
	panel.DrawItem(sBuffer, g_iDiceBet[client] > iCredits || g_bDiceFlipping[client] || !gc_DiceAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	
	panel.DrawText(" ");

	panel.CurrentKey = 6;
	Format(sBuffer, sizeof(sBuffer), "%t", "Game Info");
	panel.DrawItem(sBuffer, g_bDiceFlipping[client] ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, g_bDiceFlipping[client] ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 10;
	Format(sBuffer, sizeof(sBuffer), "%t", g_bDiceFlipping[client] ? "Cancel" : "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT); // ITEMDRAW_DISABLED ???

	panel.Send(client, Dice_Handler_RunWin, MENU_TIME_FOREVER);

	delete panel;
}

public int Dice_Handler_RunWin(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			// Item 4 - Rerun bet
			case 6:
			{
				// Decline when player come back to life
				if (!gc_DiceAlive.BoolValue && IsPlayerAlive(client))
				{
					Dice_Panel_Dice(client);
					#if defined _clientmod_included
						MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Must be dead CM");
						C_PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#else
						PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
					#endif


					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
				// show place color panel
				else
				{
					Dice_Panel_ChooseNum(client);
					//FakeClientCommandEx(client, "play %s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
			}
			case 7:
			{
				Dice_Panel_GameInfo(client);
				//FakeClientCommandEx(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			// Item 6 - go back to casino
			case 8:
			{
				Dice_Panel_Dice(client);

				//FakeClientCommandEx(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
			}
			// Item 9 - exit cancel
			case 10:
			{
				delete g_hDiceTimerRun[client];
				delete g_hDiceTimerStopFlip[client];
				Store_SetClientRecurringMenu(client, false);

				if (g_bDiceFlipping[client])
				{
					Dice_Panel_Dice(client);
				}

				g_bDiceFlipping[client] = false;

				//FakeClientCommandEx(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
	
	return 0;
}

// Inject the dice into panels
void Dice_PanelInject_Dice(Panel panel, int client)
{
	char sBuffer[32];
	panel.DrawText("   ──────");
	Format(sBuffer, sizeof(sBuffer), "  │ %s	%s │", g_iDicePosition[client] > 3 ? "•" : "  ", g_iDicePosition[client] > 1 ? "•" : "  ");
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "  │ %s %s %s │	%i", g_iDicePosition[client] == 6 ? "•" : "  ", g_iDicePosition[client] & 1 ? "•" : "  ", g_iDicePosition[client] == 6 ? "•" : "  ", g_iDicePosition[client]);
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "  │ %s	%s │", g_iDicePosition[client] > 1 ? "•" : "  ", g_iDicePosition[client] > 3 ? "•" : "  ");
	panel.DrawText(sBuffer);
	panel.DrawText("   ──────");
}

/******************************************************************************
				   functions
******************************************************************************/

//Randomize the stop time to the next number isn't predictable
float Dice_GetAutoStopTime()
{
	return GetRandomFloat(gc_DiceAutoStop.FloatValue/2 - 0.8, gc_DiceAutoStop.FloatValue/2 + 1.2);
}

void Dice_ProcessWin(int client, int bet, int multiply)
{
	char sBuffer[255];
	int iProfit;
	if(gc_DiceBonus.BoolValue && (bet >= RoundToCeil((gc_DiceMax.IntValue*gc_DiceBonusRatio.FloatValue))))
		iProfit = bet * multiply + RoundToCeil(bet*gc_DiceBonusRatioAmount.FloatValue);
	else iProfit = bet * multiply;

	// Add profit to balance
	Store_SetClientCredits(client, Store_GetClientCredits(client) + iProfit);

	// Play sound and notify other player abot this win
	Format(sBuffer, sizeof(sBuffer), "%t", "dice");
	if(gc_DiceBonus.BoolValue && (bet >= RoundToCeil((gc_DiceMax.IntValue*gc_DiceBonusRatio.FloatValue))))
	{
		#if defined _clientmod_included
			MC_PrintToChatAll("%s %t - %t", g_sChatPrefix_CM, "Player won x Credits CM", client, bet * multiply, g_sCreditsName, sBuffer, "Bet Bonus CM", RoundToCeil(bet*gc_DiceBonusRatioAmount.FloatValue));
			C_PrintToChatAll("%s %t - %t", g_sChatPrefix, "Player won x Credits", client, bet * multiply, g_sCreditsName, sBuffer, "Bet Bonus", RoundToCeil(bet*gc_DiceBonusRatioAmount.FloatValue));
		#else
			PrintToChatAll("%s %t - %t", g_sChatPrefix, "Player won x Credits", client, bet * multiply, g_sCreditsName, sBuffer, "Bet Bonus", RoundToCeil(bet*gc_DiceBonusRatioAmount.FloatValue));
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
	//FakeClientCommandEx(client, "play %s", g_sMenuItem);
	EmitSoundToClient(client, g_sMenuItem);
}

/******************************************************************************
				   Panel
******************************************************************************/

//Show the games info panel
void Dice_Panel_GameInfo(int client)
{
	char sBuffer[255];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "dice", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	panel.DrawText(" ");
	panel.DrawText(" ");


	Format(sBuffer, sizeof(sBuffer), "	%t", "Bet on a number");
	panel.DrawText(" ");
	panel.DrawText(" ");

	Format(sBuffer, sizeof(sBuffer), "	%t %t %i", "Low #1-3' = ", "bet x", 2);
	panel.DrawText(sBuffer);

	panel.DrawText(" ");
	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "	%t %t %i", "High #4-6 = ", "bet x", 2);
	panel.DrawText(sBuffer);

	panel.DrawText(" ");
	panel.DrawText(" ");

	Format(sBuffer, sizeof(sBuffer), "	%t %t %i", "Exact #x  = ", "bet x", 6);
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

	panel.Send(client, Dice_Handler_RunWin, 14);

	delete panel;
}

/******************************************************************************
				   Timer
******************************************************************************/

// The game runs and roll the dice
public Action Dice_Timer_Run(Handle tmr, int userid)
{
	int client = GetClientOfUserId(userid);

	// When client disconnected end timer
	if (!client || !IsClientInGame(client) || !IsClientConnected(client))
	{
		g_hDiceTimerRun[client] = null;

		return Plugin_Handled;
	}

	// Rebuild panel with new position
	Dice_Panel_RunAndWin(client);

	// When dice stopped end timer
	if (!g_bDiceFlipping[client])
	{
		g_hDiceTimerRun[client] = null;
		Store_SetClientRecurringMenu(client, false);

		return Plugin_Handled;
	}

	return Plugin_Continue;
}

// Timer to slow and stop dice
public Action Dice_Timer_StopDice(Handle tmr, int userid)
{
	int client = GetClientOfUserId(userid);

	// When client disconnected end timer
	if (!client || !IsClientInGame(client) || !IsClientConnected(client))
	{
		g_hDiceTimerStopFlip[client] = null;

		return Plugin_Handled;
	}

	// When dice stopped
	if (g_bDiceFlipping[client])
	{
		g_bDiceFlipping[client] = false;

		delete g_hDiceTimerRun[client];
		Store_SetClientRecurringMenu(client, false);

		g_hDiceTimerStopFlip[client] = null;

		// Show results
		Dice_Panel_RunAndWin(client);
	}
	else g_hDiceTimerStopFlip[client] = null;

	return Plugin_Handled;
}

#else
void Dice_OnPluginStart() {}
void Dice_OnClientAuthorized(int client, const char[] auth)
{
	#pragma unused client
	#pragma unused auth
}
void Dice_OnClientDisconnect(int client)
{
	#pragma unused client
}
#endif