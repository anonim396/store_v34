#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

int g_iPlayerPot[MAXPLAYERS + 1] = {0};
int g_iPlayerTeam[MAXPLAYERS + 1] = {0};
int g_iBettingStart = 0;

ConVar g_cvarEnableBetting;
ConVar g_cvarBettingPeriod;

#if defined STANDALONE_BUILD
public void OnPluginStart()
#else
public void Betting_OnPluginStart()
#endif
{
    g_cvarEnableBetting = CreateConVar("sm_store_betting", "1", "Enable/disable betting of credits", _, true, 0.0, true, 1.0);
    g_cvarBettingPeriod = CreateConVar("sm_store_betting_period", "15", "How many seconds betting should be enabled for after round start", _, true, 1.0);

    HookEvent("round_start", Betting_RoundStart);
    HookEvent("round_end", Betting_RoundEnd);
    RegConsoleCmd("sm_bet", Command_Bet);
    LoadTranslations("store.phrases");
}

#if defined STANDALONE_BUILD
public void OnClientDisconnect(int client)
#else
public void Betting_OnClientDisconnect(int client)
#endif
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
        Chat(client, "%t", "Betting Period Over");
        return Plugin_Handled;
    }

    if (g_iPlayerPot[client] > 0)
    {
        Chat(client, "%t", "Betting Already Placed");
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
        Chat(client, "%t", "Credit Invalid Amount");
        return Plugin_Handled;
    }

    if (StrEqual(m_szTeam, "t", false) || StrEqual(m_szTeam, "red", false))
        g_iPlayerTeam[client] = 2;
    else if (StrEqual(m_szTeam, "ct", false) || StrEqual(m_szTeam, "blu", false))
        g_iPlayerTeam[client] = 3;
    else
    {
        Chat(client, "%t", "Betting Invalid Team");
        return Plugin_Handled;
    }

    g_iPlayerPot[client] = m_iCredits;
    Store_SetClientCredits(client, Store_GetClientCredits(client) - m_iCredits);
    Chat(client, "%t", "Betting Placed", m_iCredits);

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
                Chat(i, "%t", "Betting Won", winnings);
            }
            else
                Chat(i, "%t", "Betting Lost", g_iPlayerPot[i]);
        }
        g_iPlayerPot[i] = 0;
        g_iPlayerTeam[i] = 0;
    }
    return Plugin_Continue;
}