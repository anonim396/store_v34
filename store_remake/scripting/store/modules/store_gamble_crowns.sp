#if STORE_MODULE_GAMBLE_CROWNS

ConVar gc_CrownsMin;
ConVar gc_CrownsMax;
ConVar gc_CrownsAutoStop;
ConVar gc_CrownsSpeed;
ConVar gc_CrownsAlive;
ConVar gc_CrownsBar;
ConVar gc_CrownsCrown;
ConVar gc_CrownsSmily;

Handle g_hCrownsTimerRun[MAXPLAYERS+1] = {null, ...};
Handle g_hCrownsTimerRollStop[MAXPLAYERS+1] = {null, ...};

int g_iCrownsRoll[MAXPLAYERS+1][3];
int g_iCrownsBet[MAXPLAYERS+1] = {-1, ...};
int g_iCrownsRollStopped[MAXPLAYERS+1] = {-1, ...};

void Crowns_OnPluginStart()
{
	RegConsoleCmd("sm_crowns", Crowns_Command_Crowns, "Open the Simple Crowns casino game");
	gc_CrownsSpeed = CreateConVar("store_crowns_speed", "0.1", "Speed the wheel spin", _, true, 0.1, true, 0.80);
	gc_CrownsAutoStop = CreateConVar("store_crowns_stop", "4.0", "Seconds a roll should auto stop", _, true, 0.0);
	gc_CrownsAlive = CreateConVar("store_crowns_alive", "1", "0 - Only dead player can start a game. 1 - Allow alive player to start a game.", _, true, 0.0);
	gc_CrownsMin = CreateConVar("store_crowns_min", "20", "Minium amount of credits to spend", _, true, 1.0);
	gc_CrownsMax = CreateConVar("store_crowns_max", "2000", "Maximum amount of credits to spend", _, true, 2.0);
	gc_CrownsSmily = CreateConVar("store_crowns_win_smily", "5", "Multiplier when win '㋛  ㋛  ㋛'", _, true, 1.0);
	gc_CrownsBar = CreateConVar("store_crowns_win_bar", "10", "Multiplier when win '㍴  ㍴  ㍴'", _, true, 1.0);
	gc_CrownsCrown = CreateConVar("store_crowns_win_crown", "25", "Multiplier when win '♛  ♛  ♛'", _, true, 1.0);
	Store_BeginModuleConfig("sourcemod/store", "gamble_crowns");
	STORE_CFG("store_crowns_speed", "0.1");
	STORE_CFG("store_crowns_stop", "4.0");
	STORE_CFG("store_crowns_alive", "1");
	STORE_CFG("store_crowns_min", "20");
	STORE_CFG("store_crowns_max", "2000");
	STORE_CFG("store_crowns_win_smily", "5");
	STORE_CFG("store_crowns_win_bar", "10");
	STORE_CFG("store_crowns_win_crown", "25");
	Store_EndModuleConfig("sourcemod/store", "gamble_crowns");
}

void Crowns_OnClientAuthorized(int client, const char[] auth)
{
	#pragma unused auth
	g_iCrownsRoll[client][0] = -1;
	g_iCrownsRoll[client][1] = -1;
	g_iCrownsRoll[client][2] = -1;
	g_iCrownsRollStopped[client] = -1;
	g_iCrownsBet[client] = 0;
}

void Crowns_OnClientDisconnect(int client)
{
	delete g_hCrownsTimerRun[client];
	delete g_hCrownsTimerRollStop[client];
}

public Action Crowns_Command_Crowns(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Command is in-game only");
		return Plugin_Handled;
	}
	if (g_hCrownsTimerRun[client] != null)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Game in progress CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Game in progress");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Game in progress");
		#endif
		return Plugin_Handled;
	}

	//if (args < 1|| args > 1)
	//{
	Crowns_Panel_Crowns(client);
	return Plugin_Handled;
}

void Crowns_Panel_Crowns(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "crowns","Title Credits" , iCredits);
	panel.SetTitle(sBuffer);

	if (g_iCrownsRoll[client][0] < 2)
	{
		g_iCrownsRoll[client][0] = GetRandomInt(2, 6);
	}
	if (g_iCrownsRoll[client][1] < 2)
	{
		g_iCrownsRoll[client][1] = GetRandomInt(2, 6);
	}
	if (g_iCrownsRoll[client][2] < 2)
	{
		g_iCrownsRoll[client][2] = GetRandomInt(2, 6);
	}

	panel.DrawText(" ");
	// define roll symbols and order
	char sSymbolsRoll1[9][9] = {"㍴", "♛", "㋛", "☠", "㍴", "♛", "㋛", "☠", "㍴"};
	char sSymbolsRoll2[9][9] = {"♛", "☠", "㍴", "㋛", "♛", "☠", "㍴", "㋛", "♛"};
	char sSymbolsRoll3[9][9] = {"☠", "♛", "㋛", "㍴", "☠", "♛", "㋛", "㍴", "☠"};
								//0	1	2	 3	4	5	 6	7	 8

	// draw slot machine
	Format(sBuffer, sizeof(sBuffer), "	|  %s   %s   %s	| ", sSymbolsRoll1[g_iCrownsRoll[client][0] - 2], sSymbolsRoll2[g_iCrownsRoll[client][1] - 2], sSymbolsRoll3[g_iCrownsRoll[client][2] - 2]);
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "	|  %s   %s   %s	| ", sSymbolsRoll1[g_iCrownsRoll[client][0] - 1], sSymbolsRoll2[g_iCrownsRoll[client][1] - 1], sSymbolsRoll3[g_iCrownsRoll[client][2] - 1]);
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "	-  %s   %s   %s	- ", sSymbolsRoll1[g_iCrownsRoll[client][0]], sSymbolsRoll2[g_iCrownsRoll[client][1]], sSymbolsRoll3[g_iCrownsRoll[client][2]]);
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "	|  %s   %s   %s	| ", sSymbolsRoll1[g_iCrownsRoll[client][0] + 1], sSymbolsRoll2[g_iCrownsRoll[client][1] + 1], sSymbolsRoll3[g_iCrownsRoll[client][2] + 1]);
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "	|  %s   %s   %s	| ", sSymbolsRoll1[g_iCrownsRoll[client][0] + 2], sSymbolsRoll2[g_iCrownsRoll[client][1] + 2], sSymbolsRoll3[g_iCrownsRoll[client][2] + 2]);
	panel.DrawText(sBuffer);

	// draw slot machine buttons
	panel.DrawText(" ");

	if (!gc_CrownsAlive.BoolValue && IsPlayerAlive(client))
	{
		Format(sBuffer, sizeof(sBuffer), "	\n	%t", "Must be dead");
		panel.DrawText(sBuffer);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "	%t\n	%t", "Type in chat !crowns", "or use buttons below");
		panel.DrawText(sBuffer);
	}

	panel.CurrentKey = 1;
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_CrownsMin.IntValue);
	panel.DrawItem(sBuffer, iCredits < gc_CrownsMin.IntValue || !gc_CrownsAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 2;
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_CrownsMax.IntValue ? gc_CrownsMax.IntValue : iCredits);
	panel.DrawItem(sBuffer, iCredits < gc_CrownsMin.IntValue || !gc_CrownsAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 3;
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_CrownsMin.IntValue, iCredits > gc_CrownsMax.IntValue ? gc_CrownsMax.IntValue : iCredits);
	panel.DrawItem(sBuffer, iCredits < gc_CrownsMin.IntValue || !gc_CrownsAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	
	panel.DrawText(" ");
	
	//Draw item rerun when already have bet - Panel line #14 - Panel item #4
	panel.CurrentKey = 5;
	Format(sBuffer, sizeof(sBuffer), "%t", "Rerun x Credits", g_iCrownsBet[client], g_sCreditsName);
	panel.DrawItem(sBuffer, g_iCrownsBet[client] > iCredits || g_iCrownsBet[client] == 0 || !gc_CrownsAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	
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

	panel.Send(client, Crowns_Handler_Crowns, MENU_TIME_FOREVER);

	delete panel;
}

public int Crowns_Handler_Crowns(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 1, 2, 3:
			{
				// Decline when player come back to life
				if (!gc_CrownsAlive.BoolValue && IsPlayerAlive(client))
				{
					Crowns_Panel_Crowns(client);

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
					int credits = Store_GetClientCredits(client);

					switch(itemNum)
					{
						case 1: g_iCrownsBet[client] = gc_CrownsMin.IntValue;
						case 2: g_iCrownsBet[client] = credits > gc_CrownsMax.IntValue ? gc_CrownsMax.IntValue : credits;
						case 3: g_iCrownsBet[client] = GetRandomInt(gc_CrownsMin.IntValue, credits > gc_CrownsMax.IntValue ? gc_CrownsMax.IntValue : credits);
					}
					
					if(g_iCrownsBet[client] <= credits && g_iCrownsBet[client] >= gc_CrownsMin.IntValue)
					{
						Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iCrownsBet[client]);
						Crowns_Start_Crowns(client);

						//FakeClientCommandEx(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);
					}
					else
					{
						g_iCrownsBet[client] = 0;
						EmitSoundToClient(client, g_sMenuItem);
						Crowns_Panel_Crowns(client);

						#if defined _clientmod_included
							MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Not enough Credits CM");
							C_PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
						#else
							PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
						#endif
					}
				}
			}
			case 5:
			{
				// Decline when player come back to life
				if (!gc_CrownsAlive.BoolValue && IsPlayerAlive(client))
				{
					Crowns_Panel_Crowns(client);
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
					if (Store_GetClientCredits(client) >= g_iCrownsBet[client])
					{
						Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iCrownsBet[client]);
						Crowns_Start_Crowns(client);

						//FakeClientCommandEx(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);
					}
					else
					{
						EmitSoundToClient(client, g_sMenuItem);
						Crowns_Panel_Crowns(client);

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
				Crowns_Panel_GameInfo(client);
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

void Crowns_Start_Crowns(int client)
{
	g_iCrownsRollStopped[client] = -1;

	// end possible still running timers
	delete g_hCrownsTimerRollStop[client];
	delete g_hCrownsTimerRun[client];

	//Store_SetClientRecurringMenu(client, true);

	//play a start sound
	//FakeClientCommandEx(client, "play %s", g_sMenuItem);
	EmitSoundToClient(client, g_sMenuItem);

	g_hCrownsTimerRun[client] = CreateTimer(gc_CrownsSpeed.FloatValue, Crowns_Timer_Run, GetClientUserId(client), TIMER_REPEAT); // run speed for all rolls
	TriggerTimer(g_hCrownsTimerRun[client]);

	g_hCrownsTimerRollStop[client] = CreateTimer(Crowns_GetAutoStopTime(), Crowns_Timer_StopRoll, GetClientUserId(client)); // stop first roll
}

void Crowns_Panel_RunAndWin(int client)
{
	char sBuffer[128];
	bool bMatch = false;
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "crowns", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// When bowl is running step postion by one
	if (g_iCrownsRollStopped[client] < 1)
	{
		g_iCrownsRoll[client][0]++;
		if (g_iCrownsRoll[client][0] >= 6)
		{
			g_iCrownsRoll[client][0] = 2;
		}
	}
	if (g_iCrownsRollStopped[client] < 2)
	{
		g_iCrownsRoll[client][1]++;
		if (g_iCrownsRoll[client][1] >= 6)
		{
			g_iCrownsRoll[client][1] = 2;
		}
	}
	if (g_iCrownsRollStopped[client] < 3)
	{
		g_iCrownsRoll[client][2]++;
		if (g_iCrownsRoll[client][2] >= 6)
		{
			g_iCrownsRoll[client][2] = 2;
		}
	}

	char sSymbolsRoll1[9][] = {"㍴", "♛", "㋛", "☠", "㍴", "♛", "㋛", "☠", "㍴"};
	char sSymbolsRoll2[9][] = {"♛", "☠", "㍴", "㋛", "♛", "☠", "㍴", "㋛", "♛"};
	char sSymbolsRoll3[9][] = {"☠", "♛", "㋛", "㍴", "☠", "♛", "㋛", "㍴", "☠"};
							// 0	1	2	 3	4	5	 6	7	 8

	if (g_iCrownsRollStopped[client] > 2)
	{
		if (StrEqual(sSymbolsRoll1[g_iCrownsRoll[client][0]], sSymbolsRoll2[g_iCrownsRoll[client][1]]) && StrEqual(sSymbolsRoll3[g_iCrownsRoll[client][1]], sSymbolsRoll2[g_iCrownsRoll[client][2]]))
		{
			bMatch = true;
		}
		else
		{
			Crowns_Panel_Crowns(client);
			delete panel;
			return;
		}

		g_iCrownsRollStopped[client] = 4;
	}

	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "	|  %s   %s   %s	| ", sSymbolsRoll1[g_iCrownsRoll[client][0] - 2], sSymbolsRoll2[g_iCrownsRoll[client][1] - 2], sSymbolsRoll3[g_iCrownsRoll[client][2] - 2]);
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "	|  %s   %s   %s	| ", sSymbolsRoll1[g_iCrownsRoll[client][0] - 1], sSymbolsRoll2[g_iCrownsRoll[client][1] - 1], sSymbolsRoll3[g_iCrownsRoll[client][2] - 1]);
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "	-  %s   %s   %s	- ", sSymbolsRoll1[g_iCrownsRoll[client][0]], sSymbolsRoll2[g_iCrownsRoll[client][1]], sSymbolsRoll3[g_iCrownsRoll[client][2]]);
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "	|  %s   %s   %s	| ", sSymbolsRoll1[g_iCrownsRoll[client][0] + 1], sSymbolsRoll2[g_iCrownsRoll[client][1] + 1], sSymbolsRoll3[g_iCrownsRoll[client][2] + 1]);
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "	|  %s   %s   %s	| ", sSymbolsRoll1[g_iCrownsRoll[client][0] + 2], sSymbolsRoll2[g_iCrownsRoll[client][1] + 2], sSymbolsRoll3[g_iCrownsRoll[client][2] + 2]);
	panel.DrawText(sBuffer);
	panel.DrawText(" ");

	// When bowl is still running
	if (g_iCrownsRollStopped[client] < 3)
	{
		panel.DrawText(" ");
		panel.DrawText(" ");

		Format(sBuffer, sizeof(sBuffer), "	%t", "Your bet", g_iCrownsBet[client], g_sCreditsName);
		panel.DrawText(sBuffer);
		panel.DrawText(" ");


		panel.DrawText(" ");
		panel.CurrentKey = 4;
		Format(sBuffer, sizeof(sBuffer), "%t", "Press to Stop");
		panel.DrawItem(sBuffer);
	}
	else if (bMatch)
	{
		panel.DrawText(" ");
		if (StrEqual(sSymbolsRoll1[g_iCrownsRoll[client][0]], "♛", true))
		{
			Crowns_ProcessWin(client, g_iCrownsBet[client], gc_CrownsCrown.IntValue);

			panel.DrawText("	!!  ♛  ♛  ♛  !! ");
			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "	%t", "You win x Credits", g_iCrownsBet[client] * gc_CrownsCrown.IntValue, g_sCreditsName);
			panel.DrawText(sBuffer);
		}
		else if (StrEqual(sSymbolsRoll1[g_iCrownsRoll[client][0]], "㍴", true))
		{
			Crowns_ProcessWin(client, g_iCrownsBet[client], gc_CrownsBar.IntValue);

			panel.DrawText("	!!  ㍴  ㍴  ㍴  !! ");
			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "	%t", "You win x Credits", g_iCrownsBet[client] * gc_CrownsBar.IntValue, g_sCreditsName);
			panel.DrawText(sBuffer);
		}
		else if (StrEqual(sSymbolsRoll1[g_iCrownsRoll[client][0]], "㋛", true))
		{
			Crowns_ProcessWin(client, g_iCrownsBet[client], gc_CrownsSmily.IntValue);

			panel.DrawText("	!!  ㋛  ㋛  ㋛  !! ");
			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "	%t", "You win x Credits", g_iCrownsBet[client] * gc_CrownsSmily.IntValue, g_sCreditsName);
			panel.DrawText(sBuffer);
		}
		else if (StrEqual(sSymbolsRoll1[g_iCrownsRoll[client][0]], "☠", true))
		{
			FakeClientCommandEx(client, "play %s", g_sMenuItem);

			panel.DrawText("	!!  ☠  ☠  ☠  !! ");
			panel.DrawText(" ");
			Format(sBuffer, sizeof(sBuffer), "	%t", "Lost bet");
			panel.DrawText(sBuffer);
		}
		
		panel.DrawText(" ");
		
		//Draw item rerun when already have bet - Panel line #14 - Panel item #4
		panel.CurrentKey = 5;
		Format(sBuffer, sizeof(sBuffer), "%t", "Rerun x Credits", g_iCrownsBet[client], g_sCreditsName);
		panel.DrawItem(sBuffer, g_iCrownsBet[client] > iCredits || g_iCrownsRollStopped[client] < 3 || !gc_CrownsAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	}
	//Draw item info - Panel line #15 - Panel item #5
	panel.DrawText(" ");
	panel.CurrentKey = 6;
	Format(sBuffer, sizeof(sBuffer), "%t", "Game Info");
	panel.DrawItem(sBuffer, g_iCrownsRollStopped[client] < 3 ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	
	panel.DrawText(" ");
	
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, g_iCrownsRollStopped[client] < 3 ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);
	panel.CurrentKey = 10;
	Format(sBuffer, sizeof(sBuffer), "%t", g_iCrownsRollStopped[client] < 3 ? "Cancel" : "Exit");
	panel.DrawItem(sBuffer);

	panel.Send(client, Crowns_Handler_WheelRun, MENU_TIME_FOREVER);

	delete panel;
}

public int Crowns_Handler_WheelRun(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			// Item 4 - Rerun bet
			case 4:
			{
				// Decline when player come back to life
				if (g_iCrownsRollStopped[client] < 3)
				{
					delete g_hCrownsTimerRollStop[client];

					if (g_iCrownsRollStopped[client] == -1) // when all rolls roll
					{
						g_iCrownsRollStopped[client] = 1; // stop first roll

						//FakeClientCommandEx(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);

						delete g_hCrownsTimerRollStop[client];
						g_hCrownsTimerRollStop[client] = CreateTimer(Crowns_GetAutoStopTime(), Crowns_Timer_StopRoll, GetClientUserId(client)); // stop second roll
					}
					else if (g_iCrownsRollStopped[client] == 1) // when first roll stopped
					{
						g_iCrownsRollStopped[client] = 2; // stop second roll

						//FakeClientCommandEx(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);

						delete g_hCrownsTimerRollStop[client];
						g_hCrownsTimerRollStop[client] = CreateTimer(Crowns_GetAutoStopTime(), Crowns_Timer_StopRoll, GetClientUserId(client)); // stop third roll
					}
					else if (g_iCrownsRollStopped[client] == 2) // when first and second roll stopped
					{
						g_iCrownsRollStopped[client] = 3; // stop third roll

						//FakeClientCommandEx(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);

						delete g_hCrownsTimerRun[client];
						delete g_hCrownsTimerRollStop[client];
						//Store_SetClientRecurringMenu(client, false);

						Crowns_Panel_RunAndWin(client);  // show result
					}
				}
				else
				{
					if (!gc_CrownsAlive.BoolValue && IsPlayerAlive(client))
					{
						Crowns_Panel_Crowns(client);
						#if defined _clientmod_included
							MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Must be dead CM");
							C_PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
						#else
							PrintToChat(client, "%s %t", g_sChatPrefix, "Must be dead");
						#endif

						//FakeClientCommandEx(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);
					}
					// rerun
					else
					{
						Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iCrownsBet[client]);
						Crowns_Start_Crowns(client);
						//FakeClientCommandEx(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);
					}
				}
			}
			case 6:
			{
				Crowns_Panel_GameInfo(client);
				//FakeClientCommandEx(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			// Item 6 - go back to casino
			case 8:
			{
				Crowns_Panel_Crowns(client);

				//FakeClientCommandEx(client, "play %s", g_sMenuExit);
				EmitSoundToClient(client, g_sMenuExit);
			}
			// Item 9 - exit cancel
			case 10:
			{
				delete g_hCrownsTimerRun[client];
				delete g_hCrownsTimerRollStop[client];
				//Store_SetClientRecurringMenu(client, false);

				if (g_iCrownsRollStopped[client] < 3)
				{
					Crowns_Panel_Crowns(client);
				}

				g_iCrownsRollStopped[client] = -1;
				//FakeClientCommandEx(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
		}
	}

	delete panel;
	
	return 0;
}

/******************************************************************************
				   functions
******************************************************************************/

//Randomize the stop time to the next number isn't predictable
float Crowns_GetAutoStopTime()
{
	return GetRandomFloat(gc_CrownsAutoStop.FloatValue/2 - 0.8, gc_CrownsAutoStop.FloatValue/2 + 1.2);
}

void Crowns_ProcessWin(int client, int bet, int multiply)
{
	char sBuffer[255];
	int iProfit = bet * multiply;

	// Add profit to balance
	Store_SetClientCredits(client, Store_GetClientCredits(client) + iProfit);

	// Play sound and notify other player abot this win
	Format(sBuffer, sizeof(sBuffer), "%t", "crowns");
	#if defined _clientmod_included
		MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Player won x Credits CM", client, iProfit, g_sCreditsName, sBuffer);
		C_PrintToChatAll("%s %t", g_sChatPrefix, "Player won x Credits", client, iProfit, g_sCreditsName, sBuffer);
	#else
		PrintToChatAll("%s %t", g_sChatPrefix, "Player won x Credits", client, iProfit, g_sCreditsName, sBuffer);
	#endif

	//FakeClientCommandEx(client, "play %s", g_sMenuItem);
	EmitSoundToClient(client, g_sMenuItem);
}

/******************************************************************************
				   Panel
******************************************************************************/

//Show the games info panel
void Crowns_Panel_GameInfo(int client)
{
	char sBuffer[255];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	//Build the panel title three lines high - Panel line #1-3
	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "crowns", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// Draw Spacer Line - Panel line #4
	panel.DrawText(" ");
	panel.DrawText(" ");


	Format(sBuffer, sizeof(sBuffer), "	%t", "Get three on a kind");
	panel.DrawText(" ");
	panel.DrawText(" ");

	// Draw info Line 1 - Panel line #7
	Format(sBuffer, sizeof(sBuffer), "	%s %t %i", "  ♛  ♛  ♛  = ", "bet x", gc_CrownsCrown.IntValue);
	panel.DrawText(sBuffer);
	panel.DrawText(" ");

	panel.DrawText(" ");
	// Draw info Line 2 - Panel line #8
	Format(sBuffer, sizeof(sBuffer), "	%s %t %i", "  ㍴  ㍴  ㍴  = ", "bet x", gc_CrownsBar.IntValue);
	panel.DrawText(sBuffer);

	panel.DrawText(" ");
	panel.DrawText(" ");
	// Draw info Line 3 - Panel line #9
	Format(sBuffer, sizeof(sBuffer), "	%s %t %i", "  ㋛  ㋛  ㋛  = ", "bet x", gc_CrownsSmily.IntValue);
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	// Draw info Line 3 - Panel line #9
	Format(sBuffer, sizeof(sBuffer), "	%s %t", "  ☠  ☠  ☠  = ", "wasted");
	panel.DrawText(sBuffer);


	// Draw Spacer item - Panel line #11 - Panel item #1

	panel.DrawText(" ");
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.DrawText(" ");
	panel.CurrentKey = 10;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, Crowns_Handler_WheelRun, 14);

	delete panel;
}

/******************************************************************************
				   Timer
******************************************************************************/

// The game runs and roll the bowl
public Action Crowns_Timer_Run(Handle tmr, int userid)
{
	int client = GetClientOfUserId(userid);

	// When client disconnected end timer
	if (!client || !IsClientConnected(client))
	{
		g_hCrownsTimerRun[client] = null;

		return Plugin_Stop;
	}

	// Rebuild panel with new position
	Crowns_Panel_RunAndWin(client);

	// When bowl stopped end timer
	if (g_iCrownsRollStopped[client] > 2)
	{
		g_hCrownsTimerRun[client] = null;
		//Store_SetClientRecurringMenu(client, false);

		return Plugin_Stop;
	}

	return Plugin_Continue;
}

// Timer to slow and stop bowl
public Action Crowns_Timer_StopRoll(Handle tmr, int userid)
{
	int client = GetClientOfUserId(userid);

	if (gc_CrownsAutoStop.FloatValue == 0)
	{
		g_hCrownsTimerRollStop[client] = null;

		return Plugin_Stop;
	}

	// When client disconnected end timer
	if (!client || !IsClientConnected(client))
	{
		g_hCrownsTimerRollStop[client] = null;

		return Plugin_Stop;
	}

	switch(g_iCrownsRollStopped[client])
	{
		// When Bowl is running, slow down bowl
		case -1:
		{
			g_iCrownsRollStopped[client] = 1;

			g_hCrownsTimerRollStop[client] = null;
			g_hCrownsTimerRollStop[client] = CreateTimer(Crowns_GetAutoStopTime(), Crowns_Timer_StopRoll, GetClientUserId(client)); // stop second roll
		}
		// When Bowl is still running and was already slowed, slow down bowl
		case 1: // when first roll stopped
		{
			g_iCrownsRollStopped[client] = 2;


			g_hCrownsTimerRollStop[client] = null;
			g_hCrownsTimerRollStop[client] = CreateTimer(Crowns_GetAutoStopTime(), Crowns_Timer_StopRoll, GetClientUserId(client)); // stop third roll
		}
		// When Bowl is running and was already slowed twice, end bowl
		case 2:
		{
			// Stop bowl
			g_iCrownsRollStopped[client] = 3;

			delete g_hCrownsTimerRun[client];

			g_hCrownsTimerRollStop[client] = null;
			//Store_SetClientRecurringMenu(client, false);

			// Show results
			Crowns_Panel_RunAndWin(client);
		}
		default: g_hCrownsTimerRollStop[client] = null;
	}

	return Plugin_Stop;
}

#else
void Crowns_OnPluginStart() {}
void Crowns_OnClientAuthorized(int client, const char[] auth)
{
	#pragma unused client
	#pragma unused auth
}
void Crowns_OnClientDisconnect(int client)
{
	#pragma unused client
}
#endif
