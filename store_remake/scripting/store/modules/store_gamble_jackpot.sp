#if STORE_MODULE_GAMBLE_JACKPOT

ConVar gc_JPTime, gc_JPCooldown, gc_JPMin, gc_JPMax, gc_JPFee;
ArrayList g_hJPJackPot;
Handle g_hJPTimer;
bool g_bJPActive = false;
bool g_bJPUsed[MAXPLAYERS + 1] = {false, ...};
int g_iJPBet[MAXPLAYERS + 1] = {0, ...};
int g_iJPPauseEnd = 0;
int g_iJPPlayer = 0;

void Jackpot_OnPluginStart()
{
	RegConsoleCmd("sm_jackpot", JP_Command_JackPot, "Open the jackpot menu and/or set a bet");
	gc_JPTime = CreateConVar("store_jackpot_time", "60", "Seconds until winner", _, true, 10.0);
	gc_JPCooldown = CreateConVar("store_jackpot_cooldown", "120", "Cooldown until new game", _, true, 10.0);
	gc_JPMin = CreateConVar("store_jackpot_min", "20", "Min credits", _, true, 1.0);
	gc_JPMax = CreateConVar("store_jackpot_max", "2000", "Max credits", _, true, 2.0);
	gc_JPFee = CreateConVar("store_jackpot_fee", "5", "Fee percent", _, true, 0.0);
	Store_BeginModuleConfig("sourcemod/store", "gamble_jackpot");
	STORE_CFG("store_jackpot_time", "60");
	STORE_CFG("store_jackpot_cooldown", "120");
	STORE_CFG("store_jackpot_min", "20");
	STORE_CFG("store_jackpot_max", "2000");
	STORE_CFG("store_jackpot_fee", "5");
	Store_EndModuleConfig("sourcemod/store", "gamble_jackpot");
	g_hJPJackPot = new ArrayList();
}

void Jackpot_OnMapStart()
{
	g_hJPJackPot.Clear();
}

void Jackpot_OnMapEnd()
{
	if (!g_bJPActive) return;
	delete g_hJPTimer;
	JP_PayOut_JackPot();
}

void JP_Panel_JackPot(int client)
{
	char sBuffer[255];
	int iCredits = Store_GetClientCredits(client); // Get credits
	Panel panel = new Panel();

	Format(sBuffer, sizeof(sBuffer), "%t\n%t", "jackpot","Title Credits", iCredits);
	panel.SetTitle(sBuffer);
	panel.DrawText(" ");
	if (g_iJPPauseEnd > GetTime())
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Jackpot paused");
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
		Format(sBuffer, sizeof(sBuffer), "%t", "You can start a new Jackpot");
		panel.DrawText(sBuffer);

		JP_SecToTime(g_iJPPauseEnd - GetTime(), sBuffer, sizeof(sBuffer));
		Format(sBuffer, sizeof(sBuffer), "%t", "in x time", sBuffer);
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
		panel.CurrentKey = 1;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_JPMin.IntValue);
		panel.DrawItem(sBuffer, ITEMDRAW_DISABLED);
		panel.CurrentKey = 2;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_JPMax.IntValue ? gc_JPMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, ITEMDRAW_DISABLED);
		panel.CurrentKey = 3;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_JPMin.IntValue, iCredits > gc_JPMax.IntValue ? gc_JPMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, ITEMDRAW_DISABLED);
	}
	else if (!g_bJPActive)
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "No active Jackpot");
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
		Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Type in chat !jackpot", "or use buttons below");
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
		panel.CurrentKey = 1;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_JPMin.IntValue);
		panel.DrawItem(sBuffer, iCredits < gc_JPMin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		panel.CurrentKey = 2;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_JPMax.IntValue ? gc_JPMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, iCredits < gc_JPMin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		panel.CurrentKey = 3;
		Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_JPMin.IntValue, iCredits > gc_JPMax.IntValue ? gc_JPMax.IntValue : iCredits);
		panel.DrawItem(sBuffer, iCredits < gc_JPMin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	}
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Jackpot: x Credits", g_hJPJackPot.Length, g_sCreditsName);
		panel.DrawText(sBuffer);

		if (g_bJPUsed[client])
		{
			Format(sBuffer, sizeof(sBuffer), "%t", "Your Bet - Chance", g_iJPBet[client], g_sCreditsName, JP_GetChance(client));
			panel.DrawText(sBuffer);
		}
		panel.DrawText(" ");

		for (int i = 0; i <= MaxClients; i++)
		{
			if (!IsValidClient(i, false, true) || !g_bJPUsed[i])
				continue;

			if (client == i)
				continue;

			Format(sBuffer, sizeof(sBuffer), "%t", "Jackpot chances", i, JP_GetChance(i), g_iJPBet[i], g_sCreditsName);
			panel.DrawText(sBuffer);
		}
		panel.DrawText(" ");

		if (!g_bJPUsed[client])
		{
			Format(sBuffer, sizeof(sBuffer), "%t\n%t", "Type in chat !jackpot", "or use buttons below");
			panel.DrawText(sBuffer);
			panel.CurrentKey = 1;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", gc_JPMin.IntValue);
			panel.DrawItem(sBuffer, iCredits < gc_JPMin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			panel.CurrentKey = 2;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", iCredits > gc_JPMax.IntValue ? gc_JPMax.IntValue : iCredits);
			panel.DrawItem(sBuffer, iCredits < gc_JPMin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
			panel.CurrentKey = 3;
			Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", gc_JPMin.IntValue, iCredits > gc_JPMax.IntValue ? gc_JPMax.IntValue : iCredits);
			panel.DrawItem(sBuffer, iCredits < gc_JPMin.IntValue ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
		}
	}
	panel.DrawText(" ");
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.DrawItem("", ITEMDRAW_SPACER);
	panel.CurrentKey = 10;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, JP_PanelHandler_Info, 5);
}

void JP_SetBet(int client, int bet)
{
	g_bJPUsed[client] = true;
	g_iJPBet[client] = bet;
	g_iJPPlayer++;

	//ClientCommand(client, "play %s", g_sMenuItem);
	EmitSoundToClient(client, g_sMenuItem);
	Store_SetClientCredits(client, Store_GetClientCredits(client) - bet);

	int iAccountID = GetSteamAccountID(client, true);
	for (int i = 0; i < bet; i++)
	{
		g_hJPJackPot.Push(iAccountID);
	}

	if (!g_bJPActive)
	{
		g_bJPActive = true;
		delete g_hJPTimer;
		g_hJPTimer = CreateTimer(gc_JPTime.FloatValue, JP_Timer_EndJackPot, TIMER_FLAG_NO_MAPCHANGE);
		#if defined _clientmod_included
			MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Player opened jackpot CM", client, bet, g_sCreditsName);
			C_PrintToChatAll("%s %t", g_sChatPrefix, "Player opened jackpot", client, bet, g_sCreditsName);
		#else
			PrintToChatAll("%s %t", g_sChatPrefix, "Player opened jackpot", client, bet, g_sCreditsName);
		#endif
		char sBuffer[64];
		JP_SecToTime(RoundFloat(gc_JPTime.FloatValue), sBuffer, sizeof(sBuffer));
		#if defined _clientmod_included
			MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "the prize will be drawn in CM", sBuffer);
			C_PrintToChatAll("%s %t", g_sChatPrefix, "the prize will be drawn in", sBuffer);
		#else
			PrintToChatAll("%s %t", g_sChatPrefix, "the prize will be drawn in", sBuffer);
		#endif
	}
	else
	{
		#if defined _clientmod_included
			MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Player added to jackpot CM", client, bet, g_sCreditsName, JP_GetChance(client), g_hJPJackPot.Length, g_sCreditsName);
			C_PrintToChatAll("%s %t", g_sChatPrefix, "Player added to jackpot", client, bet, g_sCreditsName, JP_GetChance(client), g_hJPJackPot.Length, g_sCreditsName);
		#else
			PrintToChatAll("%s %t", g_sChatPrefix, "Player added to jackpot", client, bet, g_sCreditsName, JP_GetChance(client), g_hJPJackPot.Length, g_sCreditsName);
		#endif
		for (int i = 0; i <= MaxClients; i++)
		{
			if (!IsValidClient(i, false, true) || !g_bJPUsed[i])
				continue;

			#if defined _clientmod_included
				MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "Your current winning chance has changed CM", JP_GetChance(i));
				C_PrintToChat(i, "%s %t", g_sChatPrefix, "Your current winning chance has changed", JP_GetChance(i));
			#else
				PrintToChat(i, "%s %t", g_sChatPrefix, "Your current winning chance has changed", JP_GetChance(i));
			#endif
		}
	}

	JP_Panel_JackPot(client);
}

float JP_GetChance(int client)
{
	return float(g_iJPBet[client]) / float(g_hJPJackPot.Length) * 100.0;
}

public int JP_PanelHandler_Info(Handle menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		int credits = Store_GetClientCredits(client);
		switch(param2)
		{
			case 1: JP_SetBet(client, gc_JPMin.IntValue);
			case 2: JP_SetBet(client, credits > gc_JPMax.IntValue ? gc_JPMax.IntValue : credits);
			case 3: JP_SetBet(client, GetRandomInt(gc_JPMin.IntValue, credits > gc_JPMax.IntValue ? gc_JPMax.IntValue : credits));
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

	delete menu;
	
	return 0;
}

public Action JP_Command_JackPot(int client, int args)
{
	if (!client)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Command is in-game only");

		return Plugin_Handled;
	}

	if (g_iJPPauseEnd > GetTime())
	{
		char sBuffer[64];
		JP_SecToTime(g_iJPPauseEnd - GetTime(), sBuffer, sizeof(sBuffer));
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t %t", g_sChatPrefix_CM, "Jackpot paused CM", "You can start a new Jackpot in CM", sBuffer);
			C_PrintToChat(client, "%s %t %t", g_sChatPrefix, "Jackpot paused", "You can start a new Jackpot in", sBuffer);
		#else
			PrintToChat(client, "%s %t %t", g_sChatPrefix, "Jackpot paused", "You can start a new Jackpot in", sBuffer);
		#endif

		return Plugin_Handled;
	}

	JP_Panel_JackPot(client);

	if (g_bJPUsed[client])
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "You already cashed in", g_iJPBet[client], g_sCreditsName, JP_GetChance(client), g_hJPJackPot.Length, g_sCreditsName);

		return Plugin_Handled;
	}

	if (args != 1)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Type in chat !jackpot");

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

	if (iBet < gc_JPMin.IntValue)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "You have to spend at least x credits", gc_JPMin.IntValue, g_sCreditsName);

		return Plugin_Handled;
	}
	else if (iBet > gc_JPMax.IntValue)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "You can't spend that much credits", gc_JPMax.IntValue, g_sCreditsName);

		return Plugin_Handled;
	}

	if (iBet > iCredits)
	{
		ReplyToCommand(client, "%s %t", g_sChatPrefix, "Not enough Credits");

		return Plugin_Handled;
	}

	JP_SetBet(client, iBet);

	return Plugin_Handled;
}

public Action JP_Timer_EndJackPot(Handle timer)
{
	g_hJPTimer = null;

	JP_PayOut_JackPot();

	return Plugin_Stop;
}

int JP_GetClientOfSteamAccountID(int accountID)
{
	for (int i = 0; i <= MaxClients; i++)
	{
		if (!IsValidClient(i, false, true))
			continue;

		if (accountID == GetSteamAccountID(i, true))
		{
			return i;
		}
	}

	return -1;
}

void JP_PayOut_JackPot()
{
	int jackpot = g_hJPJackPot.Length;
	int winner_accountID = g_hJPJackPot.Get(GetRandomInt(0, jackpot - 1));
	int winner = JP_GetClientOfSteamAccountID(winner_accountID);

	if (g_iJPPlayer < 2)
	{
		if (winner == -1)
		{
			#if defined _clientmod_included
				MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "All players disconnect CM", jackpot, g_sCreditsName);
				C_PrintToChatAll("%s %t", g_sChatPrefix, "All players disconnect", jackpot, g_sCreditsName);
			#else
				PrintToChatAll("%s %t", g_sChatPrefix, "All players disconnect", jackpot, g_sCreditsName);
			#endif

			JP_Reset_JackPot();

			return;
		}

		Store_SetClientCredits(winner, Store_GetClientCredits(winner) + jackpot);

		JP_Reset_JackPot();

		#if defined _clientmod_included
			MC_PrintToChat(winner, "%s %t", g_sChatPrefix_CM, "Noone else cashed in CM", jackpot, g_sCreditsName);
			C_PrintToChat(winner, "%s %t", g_sChatPrefix, "Noone else cashed in", jackpot, g_sCreditsName);
		#else
			PrintToChat(winner, "%s %t", g_sChatPrefix, "Noone else cashed in", jackpot, g_sCreditsName);
		#endif
		return;
	}

	if (winner == -1)
	{
		#if defined _clientmod_included
			MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Winner is not in game anymore CM");
			C_PrintToChatAll("%s %t", g_sChatPrefix, "Winner is not in game anymore");
		#else
			PrintToChatAll("%s %t", g_sChatPrefix, "Winner is not in game anymore");
		#endif

		int iIndex;
		while ((iIndex = g_hJPJackPot.FindValue(winner_accountID)) != -1)
		{
			g_hJPJackPot.Erase(iIndex);
		}

		winner_accountID = g_hJPJackPot.Get(GetRandomInt(0, g_hJPJackPot.Length - 1));
		winner = JP_GetClientOfSteamAccountID(winner_accountID);

		if (winner == -1)
		{
			#if defined _clientmod_included
				MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Second Winner is not in game anymore CM");
				C_PrintToChatAll("%s %t", g_sChatPrefix, "Second Winner is not in game anymore");
			#else
				PrintToChatAll("%s %t", g_sChatPrefix, "Second Winner is not in game anymore");
			#endif
			for (int i = 0; i <= MaxClients; i++)
			{
				if (!IsValidClient(i, false, true) || !g_bJPUsed[i])
					continue;

				winner = i;
				break;
			}
		
		}
	}

	if (winner == -1)
	{
		#if defined _clientmod_included
			MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "All players disconnect CM", jackpot, g_sCreditsName);
			C_PrintToChatAll("%s %t", g_sChatPrefix, "All players disconnect", jackpot, g_sCreditsName);
		#else
			PrintToChatAll("%s %t", g_sChatPrefix, "All players disconnect", jackpot, g_sCreditsName);
		#endif

		JP_Reset_JackPot();

		return;
	}

	#if defined _clientmod_included
		MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Player won the Jackpot CM", winner, jackpot, g_sCreditsName);
		C_PrintToChatAll("%s %t", g_sChatPrefix, "Player won the Jackpot", winner, jackpot, g_sCreditsName);
	#else
		PrintToChatAll("%s %t", g_sChatPrefix, "Player won the Jackpot", winner, jackpot, g_sCreditsName);
	#endif

	if (gc_JPFee.IntValue != 0)
	{
		int fee = jackpot * gc_JPFee.IntValue / 100;
		#if defined _clientmod_included
			MC_PrintToChat(winner, "%s %t", g_sChatPrefix_CM, "You won the Jackpot - Fee CM", jackpot, g_sCreditsName, fee, g_sCreditsName, gc_JPFee.IntValue);
			C_PrintToChat(winner, "%s %t", g_sChatPrefix, "You won the Jackpot - Fee", jackpot, g_sCreditsName, fee, g_sCreditsName, gc_JPFee.IntValue);
		#else
			PrintToChat(winner, "%s %t", g_sChatPrefix, "You won the Jackpot - Fee", jackpot, g_sCreditsName, fee, g_sCreditsName, gc_JPFee.IntValue);
		#endif
		jackpot -= fee;
	}
	else
	{
		#if defined _clientmod_included
			MC_PrintToChat(winner, "%s %t", g_sChatPrefix_CM, "You won the Jackpot CM", jackpot, g_sCreditsName);
			C_PrintToChat(winner, "%s %t", g_sChatPrefix, "You won the Jackpot", jackpot, g_sCreditsName);
		#else
			PrintToChat(winner, "%s %t", g_sChatPrefix, "You won the Jackpot", jackpot, g_sCreditsName);
		#endif
	}

	Store_SetClientCredits(winner, Store_GetClientCredits(winner) + jackpot);

	JP_Reset_JackPot();
}

void JP_Reset_JackPot()
{
	for (int i = 0; i <= MaxClients; i++)
	{
		g_bJPUsed[i] = false;
		g_iJPBet[i] = 0;
	}

	g_iJPPlayer = 0;
	g_bJPActive = false;

	g_hJPJackPot.Clear();
	g_iJPPauseEnd = gc_JPCooldown.IntValue + GetTime();
}

void JP_SecToTime(int time, char[] buffer, int size)
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
		Format(buffer, size, "%t", "x hours, x minutes, x seconds", iHours, iMinutes, iSeconds);
	}
	else if (iMinutes >= 1)
	{
		Format(buffer, size, "%t", "x minutes, x seconds", iMinutes, iSeconds);
	}
	else
	{
		Format(buffer, size, "%t", "x seconds", iSeconds);
	}
}

#if !defined _store_stocks_included
bool IsValidClient(int client, bool bots = true, bool dead = true)
{
	if (client <= 0 || client > MaxClients || !IsClientInGame(client))
		return false;
	if (IsFakeClient(client) && !bots) return false;
	if (IsClientSourceTV(client) || IsClientReplay(client)) return false;
	if (!IsPlayerAlive(client) && !dead) return false;
	return true;
}
#endif

#else
void Jackpot_OnPluginStart() {}
void Jackpot_OnMapStart() {}
void Jackpot_OnMapEnd() {}
#endif
