#if STORE_MODULE_ROLL

int g_iRollMinPrize, g_iRollMaxPrize, g_iRollMinPlayers, g_iRollTimeToRoll, g_iRollInterval;
int g_iRollPrize, g_iRollHost, g_iRollCountdown, g_iRollNextTime;
bool g_bRollActive, g_bRollWaitingRound, g_bRollMapChange;
bool g_bRollSayCmd[MAXPLAYERS+1];
ArrayList g_hRollParticipants;
ConVar g_cvarRollMinPrize, g_cvarRollMaxPrize, g_cvarRollMinPlayers, g_cvarRollTimeToRoll, g_cvarRollInterval, g_cvarRollNow;

void Roll_OnPluginStart()
{
	LoadTranslations("store.phrases");
	g_hRollParticipants = new ArrayList(ByteCountToCells(32));
	RegConsoleCmd("sm_roll", Roll_Command);
	AddCommandListener(Roll_OnSay, "say");
	AddCommandListener(Roll_OnSay, "say_team");
	HookEvent("round_end", Roll_OnRoundEnd);
	g_cvarRollMinPrize = CreateConVar("sm_store_roll_min_prize", "20", "Min credits for roll", _, true, 1.0, true, 999999.0);
	g_cvarRollMaxPrize = CreateConVar("sm_store_roll_max_prize", "100", "Max credits for roll", _, true, 1.0, true, 9999999.0);
	g_cvarRollMinPlayers = CreateConVar("sm_store_roll_min_players", "2", "Min players to start roll", _, true, 1.0, true, 64.0);
	g_cvarRollTimeToRoll = CreateConVar("sm_store_roll_time", "20", "Seconds to participate", _, true, 1.0, true, 60.0);
	g_cvarRollInterval = CreateConVar("sm_store_roll_interval", "60", "Seconds between rolls", _, true, 1.0, true, 3600.0);
	g_cvarRollNow = CreateConVar("sm_store_roll_now", "1", "1 = start immediately, 0 = after round end", _, true, 0.0, true, 1.0);
	g_cvarRollMinPrize.AddChangeHook(Roll_OnCvarChange);
	g_cvarRollMaxPrize.AddChangeHook(Roll_OnCvarChange);
	g_cvarRollMinPlayers.AddChangeHook(Roll_OnCvarChange);
	g_cvarRollTimeToRoll.AddChangeHook(Roll_OnCvarChange);
	g_cvarRollInterval.AddChangeHook(Roll_OnCvarChange);
	g_cvarRollNow.AddChangeHook(Roll_OnCvarChange);
	Roll_RefreshCvars();
	Store_BeginModuleConfig("sourcemod/store", "store_roll");
	STORE_CFG("sm_store_roll_min_prize", "20");
	STORE_CFG("sm_store_roll_max_prize", "100");
	STORE_CFG("sm_store_roll_min_players", "2");
	STORE_CFG("sm_store_roll_time", "20");
	STORE_CFG("sm_store_roll_interval", "60");
	STORE_CFG("sm_store_roll_now", "1");
	Store_EndModuleConfig("sourcemod/store", "store_roll");
}

public void Roll_OnCvarChange(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	Roll_RefreshCvars();
}

void Roll_RefreshCvars()
{
	g_iRollMinPrize = g_cvarRollMinPrize.IntValue;
	g_iRollMaxPrize = g_cvarRollMaxPrize.IntValue;
	g_iRollMinPlayers = g_cvarRollMinPlayers.IntValue;
	g_iRollTimeToRoll = g_cvarRollTimeToRoll.IntValue;
	g_iRollInterval = g_cvarRollInterval.IntValue;
}

void Roll_OnMapStart()
{
	g_bRollMapChange = false;
	g_bRollActive = false;
}

void Roll_OnMapEnd()
{
	g_bRollMapChange = true;
}

public Action Roll_Command(int client, int args)
{
	if (!client || IsFakeClient(client))
		return Plugin_Handled;
	if (g_bRollActive)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "ROLL_ALREADY_COMING");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "ROLL_ALREADY_COMING");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "ROLL_ALREADY_COMING");
		#endif
		return Plugin_Handled;
	}
	if (GetClientCount(true) < g_iRollMinPlayers)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "ROLL_NEED_MIN_PLAYERS", g_iRollMinPlayers);
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "ROLL_NEED_MIN_PLAYERS", g_iRollMinPlayers);
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "ROLL_NEED_MIN_PLAYERS", g_iRollMinPlayers);
		#endif
		return Plugin_Handled;
	}
	int nextRoll = Roll_GetNextRollTime();
	if (nextRoll > 0)
	{
		#if defined _clientmod_included
			if (nextRoll >= 60)
			{
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "ROLL_INTERVAL_MIN", nextRoll / 60);
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "ROLL_INTERVAL_MIN", nextRoll / 60);
			}
			else
			{
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "ROLL_INTERVAL_SEC", nextRoll);
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "ROLL_INTERVAL_SEC", nextRoll);
			}
		#else
			if (nextRoll >= 60)
				PrintToChat(client, "%s %t", g_sChatPrefix, "ROLL_INTERVAL_MIN", nextRoll / 60);
			else
				PrintToChat(client, "%s %t", g_sChatPrefix, "ROLL_INTERVAL_SEC", nextRoll);
		#endif
		return Plugin_Handled;
	}
	g_bRollSayCmd[client] = true;
	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "ROLL_PRE_START_1", g_iRollMinPrize, g_iRollMaxPrize);
		C_PrintToChat(client, "%s %t", g_sChatPrefix, "ROLL_PRE_START_1", g_iRollMinPrize, g_iRollMaxPrize);
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "ROLL_PRE_START_2");
		C_PrintToChat(client, "%s %t", g_sChatPrefix, "ROLL_PRE_START_2");
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix, "ROLL_PRE_START_1", g_iRollMinPrize, g_iRollMaxPrize);
		PrintToChat(client, "%s %t", g_sChatPrefix, "ROLL_PRE_START_2");
	#endif
	return Plugin_Handled;
}

int Roll_GetNextRollTime()
{
	if (g_iRollNextTime <= 0)
		return 0;
	int left = g_iRollNextTime - GetTime();
	return (left > 0) ? left : 0;
}

public Action Roll_OnSay(int client, const char[] command, int argc)
{
	if (!g_bRollSayCmd[client] || g_bRollActive)
		return Plugin_Continue;
	char msg[32];
	GetCmdArgString(msg, sizeof(msg));
	TrimString(msg);
	StripQuotes(msg);
	g_bRollSayCmd[client] = false;
	int amount = StringToInt(msg);
	for (int i = 0; msg[i] != '\0'; i++)
		if (!IsCharNumeric(msg[i]) && (i > 0 || msg[i] != '-'))
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "PRE_ROLL_INVALID_NUMBER");
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "PRE_ROLL_INVALID_NUMBER");
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "PRE_ROLL_INVALID_NUMBER");
			#endif
			return Plugin_Handled;
		}
	if (amount < g_iRollMinPrize || amount > g_iRollMaxPrize)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "PRE_ROLL_INVALID_NUMBER");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "PRE_ROLL_INVALID_NUMBER");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "PRE_ROLL_INVALID_NUMBER");
		#endif
		return Plugin_Handled;
	}
	if (Store_GetClientCredits(client) < amount)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "PRE_ROLL_NO_MONEY");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "PRE_ROLL_NO_MONEY");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "PRE_ROLL_NO_MONEY");
		#endif
		return Plugin_Handled;
	}
	g_bRollActive = true;
	g_iRollHost = client;
	g_iRollPrize = amount;
	Store_SetClientCredits(client, Store_GetClientCredits(client) - amount);
	char name[MAX_NAME_LENGTH];
	GetClientName(client, name, sizeof(name));
	#if defined _clientmod_included
		MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "ROLL_START_1", name, amount);
		C_PrintToChatAll("%s %t", g_sChatPrefix, "ROLL_START_1", name, amount);
	#else
		PrintToChatAll("%s %t", g_sChatPrefix, "ROLL_START_1", name, amount);
	#endif
	if (g_cvarRollNow.BoolValue)
		Roll_StartPanel();
	else
	{
		g_bRollWaitingRound = true;
		#if defined _clientmod_included
			MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "ROLL_START_2");
			C_PrintToChatAll("%s %t", g_sChatPrefix, "ROLL_START_2");
		#else
			PrintToChatAll("%s %t", g_sChatPrefix, "ROLL_START_2");
		#endif
	}
	return Plugin_Handled;
}

public Action Roll_OnRoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	if (g_bRollWaitingRound)
	{
		g_bRollWaitingRound = false;
		Roll_StartPanel();
	}
	return Plugin_Continue;
}

void Roll_StartPanel()
{
	g_hRollParticipants.Clear();
	char title[128], hostName[MAX_NAME_LENGTH];
	GetClientName(g_iRollHost, hostName, sizeof(hostName));
	Format(title, sizeof(title), "%t", "ROLL_PANEL_TITLE", hostName, g_iRollPrize);
	Panel panel = new Panel();
	panel.SetTitle(title);
	panel.DrawItem("", ITEMDRAW_SPACER);
	char buf[64];
	Format(buf, sizeof(buf), "%t", "ROLL_PARTICIPATE");
	panel.DrawItem(buf);
	Format(buf, sizeof(buf), "%t", "ROLL_DECLINE");
	panel.DrawItem(buf);
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i) && i != g_iRollHost)
			panel.Send(i, Roll_PanelHandler, g_iRollTimeToRoll);
	delete panel;
	g_iRollCountdown = g_iRollTimeToRoll;
	CreateTimer(1.0, Roll_CountdownTimer, _, TIMER_REPEAT);
}

public int Roll_PanelHandler(Panel panel, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		if (param2 == 1)
		{
			char auth[32];
			GetClientAuthId(client, AuthId_Steam2, auth, sizeof(auth));
			g_hRollParticipants.PushString(auth);
			char name[MAX_NAME_LENGTH];
			GetClientName(client, name, sizeof(name));
			#if defined _clientmod_included
				MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "PLAYER_ACCEPT_ROLL_PRINT_ALL", name, g_hRollParticipants.Length);
				C_PrintToChatAll("%s %t", g_sChatPrefix, "PLAYER_ACCEPT_ROLL_PRINT_ALL", name, g_hRollParticipants.Length);
			#else
				PrintToChatAll("%s %t", g_sChatPrefix, "PLAYER_ACCEPT_ROLL_PRINT_ALL", name, g_hRollParticipants.Length);
			#endif
		}
		else
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "PLAYER_CANCEL_ROLL");
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "PLAYER_CANCEL_ROLL");
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "PLAYER_CANCEL_ROLL");
			#endif
		}
	}
	else if (action == MenuAction_Cancel)
	{
		#if defined _clientmod_included
			if (param2 == MenuCancel_Timeout)
			{
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "ROLL_TIMEOUT");
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "ROLL_TIMEOUT");
			}
			else
			{
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "ROLL_INTERRUPTED");
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "ROLL_INTERRUPTED");
			}
		#else
			if (param2 == MenuCancel_Timeout)
				PrintToChat(client, "%s %t", g_sChatPrefix, "ROLL_TIMEOUT");
			else
				PrintToChat(client, "%s %t", g_sChatPrefix, "ROLL_INTERRUPTED");
		#endif
	}
	return 0;
}

public Action Roll_CountdownTimer(Handle timer, any unused)
{
	if (g_bRollMapChange)
	{
		if (g_iRollHost && IsClientInGame(g_iRollHost))
		{
			Store_SetClientCredits(g_iRollHost, Store_GetClientCredits(g_iRollHost) + g_iRollPrize);
			#if defined _clientmod_included
				MC_PrintToChat(g_iRollHost, "%s %t", g_sChatPrefix_CM, "MONEY_BACK", g_iRollPrize);
				C_PrintToChat(g_iRollHost, "%s %t", g_sChatPrefix, "MONEY_BACK", g_iRollPrize);
				MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "ROLL_END_REASON_MAPCHANGE");
				C_PrintToChatAll("%s %t", g_sChatPrefix, "ROLL_END_REASON_MAPCHANGE");
			#else
				PrintToChat(g_iRollHost, "%s %t", g_sChatPrefix, "MONEY_BACK", g_iRollPrize);
				PrintToChatAll("%s %t", g_sChatPrefix, "ROLL_END_REASON_MAPCHANGE");
			#endif
		}
		g_bRollActive = false;
		g_iRollHost = 0;
		return Plugin_Stop;
	}
	g_iRollCountdown--;
	if (g_iRollCountdown <= 0)
	{
		int n = g_hRollParticipants.Length;
		if (n < g_iRollMinPlayers)
		{
			#if defined _clientmod_included
				if (n == 0)
				{
					MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "ROLL_STOP_NO_PLAYER");
					C_PrintToChatAll("%s %t", g_sChatPrefix, "ROLL_STOP_NO_PLAYER");
				}
				else
				{
					MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "ROLL_NO_MIN_PLAYERS", g_iRollMinPlayers);
					C_PrintToChatAll("%s %t", g_sChatPrefix, "ROLL_NO_MIN_PLAYERS", g_iRollMinPlayers);
				}
			#else
				if (n == 0)
					PrintToChatAll("%s %t", g_sChatPrefix, "ROLL_STOP_NO_PLAYER");
				else
					PrintToChatAll("%s %t", g_sChatPrefix, "ROLL_NO_MIN_PLAYERS", g_iRollMinPlayers);
			#endif
			if (g_iRollHost && IsClientInGame(g_iRollHost))
			{
				Store_SetClientCredits(g_iRollHost, Store_GetClientCredits(g_iRollHost) + g_iRollPrize);
				#if defined _clientmod_included
					MC_PrintToChat(g_iRollHost, "%s %t", g_sChatPrefix_CM, "MONEY_BACK", g_iRollPrize);
					C_PrintToChat(g_iRollHost, "%s %t", g_sChatPrefix, "MONEY_BACK", g_iRollPrize);
				#else
					PrintToChat(g_iRollHost, "%s %t", g_sChatPrefix, "MONEY_BACK", g_iRollPrize);
				#endif
			}
		}
		else
		{
			#if defined _clientmod_included
				MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "ROLL_START_PLAYER", n);
				C_PrintToChatAll("%s %t", g_sChatPrefix, "ROLL_START_PLAYER", n);
			#else
				PrintToChatAll("%s %t", g_sChatPrefix, "ROLL_START_PLAYER", n);
			#endif
			int idx = GetRandomInt(0, n - 1);
			char auth[32];
			g_hRollParticipants.GetString(idx, auth, sizeof(auth));
			int winner = 0;
			for (int i = 1; i <= MaxClients; i++)
				if (IsClientInGame(i) && !IsFakeClient(i))
				{
					char buf[32];
					GetClientAuthId(i, AuthId_Steam2, buf, sizeof(buf));
					if (StrEqual(buf, auth))
					{
						winner = i;
						break;
					}
				}
			if (winner)
			{
				Store_SetClientCredits(winner, Store_GetClientCredits(winner) + g_iRollPrize);
				char name[MAX_NAME_LENGTH];
				GetClientName(winner, name, sizeof(name));
				#if defined _clientmod_included
					MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "ROLL_WIN_TICKET", idx + 1, name, g_iRollPrize);
					C_PrintToChatAll("%s %t", g_sChatPrefix, "ROLL_WIN_TICKET", idx + 1, name, g_iRollPrize);
				#else
					PrintToChatAll("%s %t", g_sChatPrefix, "ROLL_WIN_TICKET", idx + 1, name, g_iRollPrize);
				#endif
			}
			else
			{
				if (g_iRollHost && IsClientInGame(g_iRollHost))
				{
					Store_SetClientCredits(g_iRollHost, Store_GetClientCredits(g_iRollHost) + g_iRollPrize);
					#if defined _clientmod_included
						MC_PrintToChat(g_iRollHost, "%s %t", g_sChatPrefix_CM, "MONEY_BACK", g_iRollPrize);
						C_PrintToChat(g_iRollHost, "%s %t", g_sChatPrefix, "MONEY_BACK", g_iRollPrize);
					#else
						PrintToChat(g_iRollHost, "%s %t", g_sChatPrefix, "MONEY_BACK", g_iRollPrize);
					#endif
				}
				#if defined _clientmod_included
					MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "ROLL_DONT_WIN_PLAYER", idx + 1);
					C_PrintToChatAll("%s %t", g_sChatPrefix, "ROLL_DONT_WIN_PLAYER", idx + 1);
				#else
					PrintToChatAll("%s %t", g_sChatPrefix, "ROLL_DONT_WIN_PLAYER", idx + 1);
				#endif
			}
		}
		g_bRollActive = false;
		g_iRollHost = 0;
		Roll_SetNextRollTime();
		return Plugin_Stop;
	}
	PrintHintTextToAll("%t", "ROLL_TIMER", g_iRollCountdown);
	return Plugin_Continue;
}

void Roll_SetNextRollTime()
{
	g_iRollNextTime = GetTime() + g_iRollInterval;
}

#else
void Roll_OnPluginStart() {}
void Roll_OnMapStart() {}
void Roll_OnMapEnd() {}
#endif
