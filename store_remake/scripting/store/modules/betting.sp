int g_iPlayerPot[MAXPLAYERS + 1] = {0};
int g_iPlayerTeam[MAXPLAYERS + 1] = {0};
int g_iBettingStart = 0;

ConVar g_cvarEnableBetting;
ConVar g_cvarBettingPeriod;

public void Betting_OnPluginStart()
{
    g_cvarEnableBetting = CreateConVar("sm_store_betting", "1", "Enable/disable betting of credits", _, true, 0.0, true, 1.0);
    g_cvarBettingPeriod = CreateConVar("sm_store_betting_period", "15", "How many seconds betting should be enabled for after round start", _, true, 1.0);

    HookEvent("round_start", Betting_RoundStart);
    HookEvent("round_end", Betting_RoundEnd);
    RegConsoleCmd("sm_bet", Command_Bet);
}

public void Betting_OnClientDisconnect(int client)
{
    if (g_iPlayerPot[client] > 0)
    {
        Store_SetClientCredits(client, Store_GetClientCredits(client) + g_iPlayerPot[client]);
        g_iPlayerPot[client] = 0;
        g_iPlayerTeam[client] = 0;
    }
}

public Action Command_Bet(int client, int args)
{
    if (!g_cvarEnableBetting.BoolValue)
        return Plugin_Handled;

    if (g_iBettingStart + g_cvarBettingPeriod.IntValue < GetTime())
    {
        //Chat(client, "%t", "Betting Period Over");
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Betting Period Over CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Betting Period Over");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Betting Period Over");
		#endif
        return Plugin_Handled;
    }

    if (g_iPlayerPot[client] > 0)
    {
        //Chat(client, "%t", "Betting Already Placed");
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Betting Already Placed CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Betting Already Placed");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Betting Already Placed");
		#endif
        return Plugin_Handled;
    }

    char m_szTeam[4], m_szAmount[11];
    GetCmdArg(1, m_szTeam, sizeof(m_szTeam));
    GetCmdArg(2, m_szAmount, sizeof(m_szAmount));

    int m_iCredits = StringToInt(m_szAmount);
    if (StrEqual(m_szAmount, "all", false))
        m_iCredits = Store_GetClientCredits(client);

    if (m_iCredits <= 0 || m_iCredits > Store_GetClientCredits(client))
    {
        //Chat(client, "%t", "Credit Invalid Amount");
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Invalid Amount CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Credit Invalid Amount");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Credit Invalid Amount");
		#endif
        return Plugin_Handled;
    }

    if (StrEqual(m_szTeam, "t", false) || StrEqual(m_szTeam, "red", false))
        g_iPlayerTeam[client] = 2;
    else if (StrEqual(m_szTeam, "ct", false) || StrEqual(m_szTeam, "blu", false))
        g_iPlayerTeam[client] = 3;
    else
    {
        //Chat(client, "%t", "Betting Invalid Team");
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Betting Invalid Team CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Betting Invalid Team");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Betting Invalid Team");
		#endif
        return Plugin_Handled;
    }

    g_iPlayerPot[client] = m_iCredits;
    Store_SetClientCredits(client, Store_GetClientCredits(client) - m_iCredits);
    //Chat(client, "%t", "Betting Placed", m_iCredits);
	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Betting Placed CM", m_iCredits);
		C_PrintToChat(client, "%s %t", g_sChatPrefix, "Betting Placed", m_iCredits);
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix, "Betting Placed", m_iCredits);
	#endif

    return Plugin_Handled;
}

public Action Betting_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    g_iBettingStart = GetTime();
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsClientInGame(i) && g_iPlayerPot[i])
            Store_SetClientCredits(i, Store_GetClientCredits(i) + g_iPlayerPot[i]);
        g_iPlayerPot[i] = 0;
        g_iPlayerTeam[i] = 0;
    }
    return Plugin_Continue;
}

public Action Betting_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    int m_iWinner = GetEventInt(event, "winner");
    int m_iTeam1Pot = 0, m_iTeam2Pot = 0;
    
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (g_iPlayerTeam[i] == 2)
            m_iTeam1Pot += g_iPlayerPot[i];
        else if (g_iPlayerTeam[i] == 3)
            m_iTeam2Pot += g_iPlayerPot[i];
    }

    if ((m_iTeam1Pot == 0 && m_iTeam2Pot == 0) || !(2 <= m_iWinner && m_iWinner <= 3))
    {
        for (int i = 1; i <= MaxClients; ++i)
        {
            if (IsClientInGame(i) && g_iPlayerPot[i])
                Store_SetClientCredits(i, Store_GetClientCredits(i) + g_iPlayerPot[i]);
            g_iPlayerPot[i] = 0;
            g_iPlayerTeam[i] = 0;
        }
        return Plugin_Continue;
    }

    float m_fMultiplier = (m_iTeam1Pot + m_iTeam2Pot) / float(m_iWinner == 2 ? m_iTeam1Pot : m_iTeam2Pot);

    for (int i = 1; i <= MaxClients; ++i)
    {
        if (IsClientInGame(i))
        {
            if (g_iPlayerTeam[i] == m_iWinner)
            {
                int winnings = RoundToFloor(g_iPlayerPot[i] * m_fMultiplier);
                Store_SetClientCredits(i, Store_GetClientCredits(i) + winnings);
                //Chat(i, "%t", "Betting Won", winnings);
				#if defined _clientmod_included
					MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "Betting Won CM", winnings);
					C_PrintToChat(i, "%s %t", g_sChatPrefix, "Betting Won", winnings);
				#else
					PrintToChat(i, "%s %t", g_sChatPrefix, "Betting Won", winnings);
				#endif
            }
            else
                //Chat(i, "%t", "Betting Lost", g_iPlayerPot[i]);
				#if defined _clientmod_included
					MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "Betting Lost CM", g_iPlayerPot[i]);
					C_PrintToChat(i, "%s %t", g_sChatPrefix, "Betting Lost", g_iPlayerPot[i]);
				#else
					PrintToChat(i, "%s %t", g_sChatPrefix, "Betting Lost", g_iPlayerPot[i]);
				#endif
        }
        g_iPlayerPot[i] = 0;
        g_iPlayerTeam[i] = 0;
    }
    return Plugin_Continue;
}