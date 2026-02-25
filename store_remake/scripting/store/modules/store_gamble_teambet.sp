#if STORE_MODULE_GAMBLE_TEAMBET

ConVar gc_TBBetPeriod, gc_TBMinPlayer, gc_TBMin, gc_TBMax, gc_TBAlive;

int g_iTBTeamBetStart = 0;
int g_iTBBet[MAXPLAYERS + 1];
int g_iTBTeam[MAXPLAYERS + 1];
int g_iTBBetOnT = 0;
int g_iTBBetOnCT = 0;

int TB_PlayerCount()
{
	int count;
	for (int i=1;i<=MaxClients;i++)
		if(IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i))
			count++;
	return count;
}

void TeamBet_OnPluginStart()
{
	gc_TBBetPeriod = CreateConVar("store_teambet_period", "35", "Seconds teambet enabled after round start", _, true, 5.0);
	gc_TBMinPlayer = CreateConVar("store_teambet_player", "4", "Min players for teambet", _, true, 0.0);
	gc_TBAlive = CreateConVar("store_teambet_alive", "1", "0 - Only dead. 1 - Allow alive.", _, true, 0.0);
	gc_TBMin = CreateConVar("store_teambet_min", "20", "Min credits", _, true, 1.0);
	gc_TBMax = CreateConVar("store_teambet_max", "2000", "Max credits", _, true, 2.0);
	Store_BeginModuleConfig("sourcemod/store", "gamble");
	STORE_CFG("store_teambet_period", "35");
	STORE_CFG("store_teambet_player", "4");
	STORE_CFG("store_teambet_alive", "1");
	STORE_CFG("store_teambet_min", "20");
	STORE_CFG("store_teambet_max", "2000");
	Store_EndModuleConfig("sourcemod/store", "gamble");
	HookEvent("round_start", TeamBet_RoundStart);
	HookEvent("round_end", TeamBet_RoundEnd);
	RegConsoleCmd("sm_bet", TB_Command);
}

void TeamBet_OnClientDisconnect(int client)
{
	if (g_iTBBet[client] < 1)
		return;
	Store_SetClientCredits(client, Store_GetClientCredits(client) + g_iTBBet[client]);
	g_iTBBet[client] = 0;
	g_iTBTeam[client] = 0;
}

public Action TB_Command(int client, int args)
{
	int count;
	count = TB_PlayerCount();
	// Command comes from console
	if (!client)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Command is in-game only");

		return Plugin_Handled;
	}

	if (!gc_TBAlive.BoolValue && IsPlayerAlive(client))
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Must be dead");

		return Plugin_Handled;
	}

	if (g_iTBTeamBetStart + gc_TBBetPeriod.IntValue < GetTime())
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "TeamBet Period Over CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "TeamBet Period Over");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "TeamBet Period Over");
		#endif

		return Plugin_Handled;
	}

	if (count < gc_TBMinPlayer.IntValue)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Min Player", gc_TBMinPlayer.IntValue);

		return Plugin_Handled;
	}

	if (args < 1 || args > 2)
	{
		TB_Panel_TeamBet(client);
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Type in chat !bet");

		return Plugin_Handled;
	}

	char sBuffer[32];
	GetCmdArg(1, sBuffer, 32);
	int iBet;
	int iCredits = Store_GetClientCredits(client);


	if (g_iTBBet[client] > 0)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "TeamBet Already Placed CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "TeamBet Already Placed");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "TeamBet Already Placed");
		#endif
		return Plugin_Handled;
	}

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

	if (iBet < gc_TBMin.IntValue)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "You have to spend at least x credits.", gc_TBMin.IntValue, g_sCreditsName);

		return Plugin_Handled;
	}
	else if (iBet > gc_TBMax.IntValue)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "You can't spend that much credits", gc_TBMax.IntValue, g_sCreditsName);

		return Plugin_Handled;
	}

	if (iBet > iCredits)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Not enough Credits");

		return Plugin_Handled;
	}

	g_iTBBet[client] = iBet;

	if (args == 1)
	{
		TB_Panel_ChooseTeam(client);
	}
	else if (args == 2)
	{
		GetCmdArg(2, sBuffer, 32);
		if (StrEqual(sBuffer, "t") || StrEqual(sBuffer, "terror"))
		{
			g_iTBTeam[client] = CS_TEAM_T;
			g_iTBBetOnT += g_iTBBet[client];
		}
		else if (StrEqual(sBuffer, "ct") || StrEqual(sBuffer, "counter"))
		{
			g_iTBTeam[client] = CS_TEAM_CT;
			g_iTBBetOnCT += g_iTBBet[client];
		}
		else
		{
			ReplyToCommand(client, "%s %t", g_sChatPrefix, "Type in chat !bet");

			return Plugin_Handled;
		}
		TB_Panel_TeamBet(client);
		Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iTBBet[client]);

		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "TeamBet Placed CM", g_iTBBet[client]);
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "TeamBet Placed", g_iTBBet[client]);
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "TeamBet Placed", g_iTBBet[client]);
		#endif
	}

	return Plugin_Handled;
}

void TB_Panel_TeamBet(int client)
{
	char sBuffer[255];
	
	int count;
	count = TB_PlayerCount();
	
	int iCredits = Store_GetClientCredits(client); // Get credits
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "teambet", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);
	panel.DrawText(" ");
	if ((g_iTBBetOnT == 0 && g_iTBBetOnCT == 0) && (g_iTBTeamBetStart + gc_TBBetPeriod.IntValue < GetTime() || count < gc_TBMinPlayer.IntValue))
	{
		panel.DrawText(" ");
		if (count < gc_TBMinPlayer.IntValue)
		{
			Format(sBuffer, sizeof(sBuffer), "	%t", "Min Player", gc_TBMinPlayer.IntValue);
		}
		else
		{
			Format(sBuffer, sizeof(sBuffer), "	%t", "TeamBet Period Over");
		}
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
		panel.DrawText(" ");
		panel.DrawText(" ");
		panel.CurrentKey = 3;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_TBMin.IntValue);
		panel.DrawItem(sBuffer, g_iTBBet[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		panel.CurrentKey = 4;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_TBMax.IntValue ? gc_TBMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, g_iTBBet[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		panel.CurrentKey = 5;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_TBMin.IntValue, iCredits > gc_TBMax.IntValue ? gc_TBMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, g_iTBBet[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	else if (g_iTBBetOnT == 0 && g_iTBBetOnCT == 0)
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "No active TeamBet");
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
		if (!gc_TBAlive.BoolValue && IsPlayerAlive(client))
		{
			Format(sBuffer, sizeof(sBuffer), "	\n	%t", "Must be dead");
			panel.DrawText(sBuffer);
		}
		else
		{
			Format(sBuffer, sizeof(sBuffer), "	%t\n	%t", "Type in chat !bet", "or use buttons below");
			panel.DrawText(sBuffer);
		}
		panel.DrawText(" ");
		panel.CurrentKey = 3;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_TBMin.IntValue);
		panel.DrawItem(sBuffer, iCredits < gc_TBMin.IntValue || !gc_TBAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		panel.CurrentKey = 4;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_TBMax.IntValue ? gc_TBMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, iCredits < gc_TBMin.IntValue || !gc_TBAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		panel.CurrentKey = 5;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_TBMin.IntValue, iCredits > gc_TBMax.IntValue ? gc_TBMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, iCredits < gc_TBMin.IntValue || !gc_TBAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "	%t", "Bet CT win: x Credits", g_iTBBetOnCT, g_sCreditsName);
		panel.DrawText(sBuffer);
		Format(sBuffer, sizeof(sBuffer), "	%t", "Bet T win: x Credits", g_iTBBetOnT, g_sCreditsName);
		panel.DrawText(sBuffer);
		panel.DrawText(" ");

		if (g_iTBBet[client] > 0)
		{
			Format(sBuffer, sizeof(sBuffer), "	%t", "Your bet", g_iTBBet[client], g_sCreditsName);
			panel.DrawText(sBuffer);
			panel.DrawText(" ");
			panel.DrawText(" ");
			panel.CurrentKey = 3;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_TBMin.IntValue);
			panel.DrawItem(sBuffer, g_iTBBet[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			panel.CurrentKey = 4;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_TBMax.IntValue ? gc_TBMax.IntValue : iCredits);
			panel.DrawItem(sBuffer, g_iTBBet[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			panel.CurrentKey = 5;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_TBMin.IntValue, iCredits > gc_TBMax.IntValue ? gc_TBMax.IntValue : iCredits);
			panel.DrawItem(sBuffer, g_iTBBet[client] > 0 ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		}
		else if (g_iTBBet[client] == 0)
		{
			if (!gc_TBAlive.BoolValue && IsPlayerAlive(client))
			{
				Format(sBuffer, sizeof(sBuffer), "	\n	%t", "Must be dead");
				panel.DrawText(sBuffer);
			}
			else
			{
				Format(sBuffer, sizeof(sBuffer), "	%t\n	%t", "Type in chat !bet", "or use buttons below");
				panel.DrawText(sBuffer);
			}
			panel.DrawText(" ");
			panel.CurrentKey = 3;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_TBMin.IntValue);
			panel.DrawItem(sBuffer, iCredits < gc_TBMin.IntValue || !gc_TBAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			panel.CurrentKey = 4;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_TBMax.IntValue ? gc_TBMax.IntValue : iCredits);
			panel.DrawItem(sBuffer, iCredits < gc_TBMin.IntValue || !gc_TBAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			panel.CurrentKey = 5;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_TBMin.IntValue, iCredits > gc_TBMax.IntValue ? gc_TBMax.IntValue : iCredits);
			panel.DrawItem(sBuffer, iCredits < gc_TBMin.IntValue || !gc_TBAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		}
	}
	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.CurrentKey = 7;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Game Info");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.CurrentKey = 9;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, TB_Handler_TeamBet, MENU_TIME_FOREVER);
}


public int TB_Handler_TeamBet(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 3, 4, 5:
			{
				// Decline when player come back to life
				if (!gc_TBAlive.BoolValue && IsPlayerAlive(client))
				{
					TB_Panel_TeamBet(client);

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
						case 3: g_iTBBet[client] = gc_TBMin.IntValue;
						case 4: g_iTBBet[client] = credits > gc_TBMax.IntValue ? gc_TBMax.IntValue : credits;
						case 5: g_iTBBet[client] = GetRandomInt(gc_TBMin.IntValue, credits > gc_TBMax.IntValue ? gc_TBMax.IntValue : credits);
					}

					TB_Panel_ChooseTeam(client);

					//ClientCommand(client, "play sound/%s", g_sMenuItem);
					EmitSoundToClient(client, g_sMenuItem);
				}
			}
			case 7:
			{
				//ClientCommand(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuExit);
				Store_DisplayPreviousMenu(client);
			}
			case 8:
			{
				TB_Panel_GameInfo(client);
				//ClientCommand(client, "play sound/%s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			case 9: 
			{
				//ClientCommand(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
	
	return 0;
}

// Open the choose color panel
void TB_Panel_ChooseTeam(int client)
{
	char sBuffer[128];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "teambet", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);
	panel.DrawText(" ");

	if (g_iTBBetOnT == 0 && g_iTBBetOnCT == 0)
	{
		Format(sBuffer, sizeof(sBuffer), "	%t", "No active TeamBet");
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "	%t", "Bet CT win: x Credits", g_iTBBetOnCT, g_sCreditsName);
		panel.DrawText(sBuffer);
		Format(sBuffer, sizeof(sBuffer), "	%t", "Bet T win: x Credits", g_iTBBetOnT, g_sCreditsName);
		panel.DrawText(sBuffer);
	}
	panel.DrawText(" ");

	if (!gc_TBAlive.BoolValue && IsPlayerAlive(client))
	{
		Format(sBuffer, sizeof(sBuffer), "	\n	%t", "Must be dead");
		panel.DrawText(sBuffer);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "	%t\n	%t", "Type in chat !bet", "or use buttons below");
		panel.DrawText(sBuffer);
	}

	panel.DrawText(" ");
	panel.CurrentKey = 3;
	Format(sBuffer, sizeof(sBuffer), "%t %t", "Bet on", "Terrorist");
	panel.DrawItem(sBuffer, !gc_TBAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.CurrentKey = 4;
	Format(sBuffer, sizeof(sBuffer), "%t %t", "Bet on", "Counter-Terrorist");
	panel.DrawItem(sBuffer, !gc_TBAlive.BoolValue && IsPlayerAlive(client) ? ITEMDRAW_SPACER : ITEMDRAW_DEFAULT);

	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.CurrentKey = 7;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.CurrentKey = 9;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, TB_Handler_ChooseTeam, MENU_TIME_FOREVER);

	delete panel;
}

public int TB_Handler_ChooseTeam(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		// Item 1 - Roll roulette on red
		switch(itemNum)
		{
			case 3, 4:
			{
				// Decline when player come back to life
				if (!gc_TBAlive.BoolValue && IsPlayerAlive(client))
				{
					TB_Panel_TeamBet(client);

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
					int iCredits = Store_GetClientCredits(client);
					if (iCredits >= g_iTBBet[client])
					{
						switch(itemNum)
						{
							case 3:
							{
								g_iTBTeam[client] = CS_TEAM_T;
								g_iTBBetOnT += g_iTBBet[client];
							}
							case 4:
							{
								g_iTBTeam[client] = CS_TEAM_CT;
								g_iTBBetOnCT += g_iTBBet[client];
							}
						}

						Store_SetClientCredits(client, iCredits - g_iTBBet[client]);
						#if defined _clientmod_included
							MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "TeamBet Placed CM", g_iTBBet[client]);
							C_PrintToChat(client, "%s %t", g_sChatPrefix, "TeamBet Placed", g_iTBBet[client]);
						#else
							PrintToChat(client, "%s %t", g_sChatPrefix, "TeamBet Placed", g_iTBBet[client]);
						#endif
						//ClientCommand(client, "play sound/%s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);
						TB_Panel_TeamBet(client);
					}
					// when player has yet had not enough Credits (double check)
					else
					{
						//ClientCommand(client, "play %s", g_sMenuItem);
						EmitSoundToClient(client, g_sMenuItem);
						TB_Panel_TeamBet(client);

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
				TB_Panel_TeamBet(client);
				//ClientCommand(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
			case 9: 
			{
				//ClientCommand(client, "play %s", g_sMenuItem);
				EmitSoundToClient(client, g_sMenuItem);
			}
		}
	}

	delete panel;
	
	return 0;
}

public Action TeamBet_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	g_iTBTeamBetStart = GetTime();

	// Give back any credits that left in the pot for whatever reason
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || g_iTBBet[i] == 0)
			continue;

		Store_SetClientCredits(i, Store_GetClientCredits(i) + g_iTBBet[i]);

		g_iTBBet[i] = 0;
		g_iTBTeam[i] = 0;
	}

	return Plugin_Continue;
}

public Action TeamBet_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	int iWinner = event.GetInt("winner");
	if (g_iTBBetOnT == 0 || g_iTBBetOnCT == 0)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || g_iTBBet[i] == 0)
				continue;

			Store_SetClientCredits(i, Store_GetClientCredits(i) + g_iTBBet[i]);
			
			#if defined _clientmod_included
				MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "TeamBet not betted CM");
				C_PrintToChat(i, "%s %t", g_sChatPrefix, "TeamBet not betted");
			#else
				PrintToChat(i, "%s %t", g_sChatPrefix, "TeamBet not betted");
			#endif

			g_iTBBet[i] = 0;
			g_iTBTeam[i] = 0;
		}

		return Plugin_Continue;
	}

	float fMulti;
	if (iWinner == CS_TEAM_T)
	{
		fMulti = (g_iTBBetOnT + g_iTBBetOnCT) / float(g_iTBBetOnT);
	}
	else
	{
		fMulti = (g_iTBBetOnT + g_iTBBetOnCT) / float(g_iTBBetOnCT);
	}

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;

		if (g_iTBTeam[i] == iWinner)
		{
			Store_SetClientCredits(i, Store_GetClientCredits(i) + RoundFloat(g_iTBBet[i] * fMulti));
			#if defined _clientmod_included
				MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "TeamBet Won CM", RoundFloat(g_iTBBet[i] * fMulti), g_sCreditsName);
				C_PrintToChat(i, "%s %t", g_sChatPrefix, "TeamBet Won", RoundFloat(g_iTBBet[i] * fMulti), g_sCreditsName);
			#else
				PrintToChat(i, "%s %t", g_sChatPrefix, "TeamBet Won", RoundFloat(g_iTBBet[i] * fMulti), g_sCreditsName);
			#endif
		}
		else if (g_iTBBet[i] >= 1)
		{
			#if defined _clientmod_included
				MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "TeamBet Lost CM", g_iTBBet[i], g_sCreditsName);
				C_PrintToChat(i, "%s %t", g_sChatPrefix, "TeamBet Lost", g_iTBBet[i], g_sCreditsName);
			#else
				PrintToChat(i, "%s %t", g_sChatPrefix, "TeamBet Lost", g_iTBBet[i], g_sCreditsName);
			#endif
		}

		g_iTBBet[i] = 0;
		g_iTBTeam[i] = 0;
		g_iTBBetOnT = 0;
		g_iTBBetOnCT = 0;
	}

	return Plugin_Continue;
}

//Show the games info panel
void TB_Panel_GameInfo(int client)
{
	char sBuffer[255];
	int iCredits = Store_GetClientCredits(client);
	Panel panel = new Panel();

	//Build the panel title three lines high - Panel line #1-3
	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "teambet", "Title Credits", iCredits);
	panel.SetTitle(sBuffer);

	// Draw Spacer Line - Panel line #4
	panel.DrawText(" ");
	panel.DrawText(" ");

	Format(sBuffer, sizeof(sBuffer), "	%t", "Bet on a team");
	panel.DrawText(" ");
	panel.DrawText(" ");

	Format(sBuffer, sizeof(sBuffer), "	%t", "Mutli = PotCT + PotT / PotWinningTeam");
	panel.DrawText(sBuffer);

	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "	%t", "Bet * Multi = Your Win");
	panel.DrawText(sBuffer);

	panel.DrawText(" ");
	panel.DrawText(" ");

	// Draw Spacer item - Panel line #11 - Panel item #1
	panel.DrawText(" ");

	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.CurrentKey = 7;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.DrawText(" ");
	panel.CurrentKey = 9;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, TB_Handler_WheelRun, MENU_TIME_FOREVER);

	delete panel;
}

public int TB_Handler_WheelRun(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 7:
			{
				ClientCommand(client, "sm_bet");
				EmitSoundToClient(client, g_sMenuItem);
			}
			// Item 9 - exit cancel
			case 9:
			{
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
	
	return 0;
}

#else
void TeamBet_OnPluginStart() {}
void TeamBet_OnClientDisconnect(int client)
{
	#pragma unused client
}
#endif