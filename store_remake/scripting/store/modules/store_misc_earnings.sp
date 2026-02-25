#if STORE_MODULE_MISC_EARNINGS

#define MAX_OBJECTIVES 10
#define EARN_ACTIVE 0
#define EARN_INACTIVE 1

char g_szEarnName[MAX_OBJECTIVES][32];
bool g_bEarnBots[MAX_OBJECTIVES];
char g_szEarnNick[MAX_OBJECTIVES][32], g_szEarnTag[MAX_OBJECTIVES][32];
float g_fEarnNick[MAX_OBJECTIVES], g_fEarnTag[MAX_OBJECTIVES], g_fEarnGroup[MAX_OBJECTIVES], g_fEarnTimer[MAX_OBJECTIVES];
int g_iEarnFlagBits[MAX_OBJECTIVES], g_iEarnMsg[MAX_OBJECTIVES], g_iEarnMinPlayer[MAX_OBJECTIVES], g_iEarnPlay[MAX_OBJECTIVES];
int g_iEarnInactive[MAX_OBJECTIVES], g_iEarnKill[MAX_OBJECTIVES], g_iEarnTK[MAX_OBJECTIVES], g_iEarnSuicide[MAX_OBJECTIVES];
int g_iEarnAssist[MAX_OBJECTIVES], g_iEarnHeadshot[MAX_OBJECTIVES], g_iEarnNoScope[MAX_OBJECTIVES], g_iEarnBackstab[MAX_OBJECTIVES];
int g_iEarnKnife[MAX_OBJECTIVES], g_iEarnHE[MAX_OBJECTIVES], g_iEarnFlash[MAX_OBJECTIVES], g_iEarnSmoke[MAX_OBJECTIVES];
int g_iEarnWin[MAX_OBJECTIVES], g_iEarnPlant[MAX_OBJECTIVES], g_iEarnDefuse[MAX_OBJECTIVES], g_iEarnExplode[MAX_OBJECTIVES];
int g_iEarnRescued[MAX_OBJECTIVES], g_iEarnVIPkill[MAX_OBJECTIVES], g_iEarnVIPescape[MAX_OBJECTIVES], g_iEarnGroup[MAX_OBJECTIVES];
int g_iEarnDaily[MAX_OBJECTIVES][7];

int g_iEarnSum[MAXPLAYERS + 1];
float g_fEarnClientMulti[MAXPLAYERS + 1];
char g_sEarnSteam[256];
bool g_bEarnGroupMember[MAXPLAYERS + 1];
ConVar gc_EarnDB;
Cookie g_cEarnDate, g_cEarnDay;
Database g_hEarnDB;
char g_sEarnDBBuffer[400];
int g_iEarnDailyDate[MAXPLAYERS + 1];
int g_iEarnDailyDay[MAXPLAYERS + 1];
bool g_bEarnDailyCached[MAXPLAYERS + 1];
int g_iEarnActive[MAXPLAYERS + 1];
int g_iEarnCount;
StringMap g_hEarnSnipers;
StringMap g_hEarnSum[MAXPLAYERS + 1];
int g_iEarnTime[MAXPLAYERS + 1][2];
char g_sEarnCurrentDate[20];

void Earnings_OnPluginStart()
{
	RegConsoleCmd("sm_daily", Earn_Command_Daily, "Receive your daily credits");
	HookEvent("round_end", Earn_Event_RoundEnd, EventHookMode_Post);
	HookEvent("player_death", Earn_Event_PlayerDeath);
	HookEvent("bomb_planted", Earn_Event_BombPlanted);
	HookEvent("bomb_defused", Earn_Event_BombDefused);
	HookEvent("bomb_exploded", Earn_Event_BombExploded);
	HookEvent("hostage_rescued", Earn_Event_HostageRescued);
	HookEvent("vip_killed", Earn_Event_VipKilled);
	HookEvent("vip_escaped", Earn_Event_VipEscaped);
	g_hEarnSnipers = new StringMap();
	g_hEarnSnipers.SetValue("awp", 1);
	g_hEarnSnipers.SetValue("scout", 1);
	g_hEarnSnipers.SetValue("sg550", 1);
	g_hEarnSnipers.SetValue("sg552", 1);
	g_hEarnSnipers.SetValue("g3sg1", 1);
	g_cEarnDate = new Cookie("store_date", "Store Daily Date", CookieAccess_Protected);
	g_cEarnDay = new Cookie("store_day", "Store Daily Day", CookieAccess_Protected);
	gc_EarnDB = CreateConVar("sm_store_earning_database", "", "Keep empty to use local storage (clientprefs)");
	Store_BeginModuleConfig("sourcemod/store", "earnings");
	STORE_CFG("sm_store_earning_database", "");
	Store_EndModuleConfig("sourcemod/store", "earnings");
	Earn_LoadConfig();
}

void Earnings_OnMapStart()
{
	CreateTimer(1.0, Earn_Timer_Timer, _, TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
}

void Earnings_OnClientConnected(int client)
{
	g_iEarnDailyDate[client] = 0;
	g_iEarnDailyDay[client] = 0;
	g_bEarnDailyCached[client] = false;
}

void Earnings_OnClientDisconnect(int client)
{
	if (IsFakeClient(client)) return;
	g_bEarnGroupMember[client] = false;
	g_iEarnDailyDate[client] = 0;
	g_iEarnDailyDay[client] = 0;
	g_bEarnDailyCached[client] = false;
}

void Earnings_OnClientPostAdminCheck(int client)
{
	SDKHook(client, SDKHook_OnTakeDamage, Earn_OnTakeDamage);
	if (IsFakeClient(client)) return;
	g_iEarnActive[client] = 0;
	g_iEarnSum[client] = 0;
	g_fEarnClientMulti[client] = 1.0;
	g_iEarnTime[client][EARN_INACTIVE] = 0;
	g_iEarnTime[client][EARN_ACTIVE] = 0;
	for (int i = 0; i < g_iEarnCount; i++)
	{
		if (!Earn_CheckFlagBits(client, g_iEarnFlagBits[i])) continue;
		g_iEarnActive[client] = i;
	}
	g_bEarnGroupMember[client] = false;
	delete g_hEarnSum[client];
	g_hEarnSum[client] = new StringMap();
	if (g_hEarnDB && !g_bEarnDailyCached[client])
		Earn_GetDailyVarsFromDB(client);
}

static bool g_bEarnConfigExecuted;
void Earnings_OnConfigExecuted()
{
	if (g_bEarnConfigExecuted) return;
	char buffer[60];
	gc_EarnDB.GetString(buffer, sizeof(buffer));
	if (buffer[0] == '\0')
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (!IsClientInGame(i) || !AreClientCookiesCached(i)) continue;
			Earnings_OnClientCookiesCached(i);
		}
		g_bEarnConfigExecuted = true;
		return;
	}
	if (!SQL_CheckConfig(buffer))
	{
		LogError("The database config name '%s' doesn't exist, check the cvar sm_store_earning_database");
		g_bEarnConfigExecuted = true;
		return;
	}
	Database.Connect(Earn_OnSQLConnect, buffer);
	g_bEarnConfigExecuted = true;
}

void Earnings_OnClientCookiesCached(int client)
{
	if (g_hEarnDB) return;
	char sBuffer[16];
	g_cEarnDate.Get(client, sBuffer, sizeof(sBuffer));
	g_iEarnDailyDate[client] = StringToInt(sBuffer);
	g_cEarnDay.Get(client, sBuffer, sizeof(sBuffer));
	g_iEarnDailyDay[client] = StringToInt(sBuffer);
	g_bEarnDailyCached[client] = true;
}

void Earn_OnSQLConnect(Database db, const char[] error, any data)
{
	if (!db)
	{
		LogError("Couldn't connect to the database: %s", error);
		return;
	}
	g_hEarnDB = db;
	
	g_hEarnDB.Query(SQL_NullCallback, "CREATE TABLE IF NOT EXISTS store_daily_rewards("
				... "steamid varchar(32) PRIMARY KEY NOT NULL, "
				... "store_date INTEGER, "
				... "store_day INTEGER);")
				
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !AreClientCookiesCached(i))
			continue;
		Earn_GetDailyVarsFromDB(i);
	}
}


void Earn_GetDailyVarsFromDB(int client)
{
	char steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	pack.WriteString(steamid);
	
	FormatEx(g_sEarnDBBuffer, sizeof(g_sEarnDBBuffer), "SELECT store_date, store_day FROM store_daily_rewards WHERE steamid = '%s'", steamid);
	g_hEarnDB.Query(Earn_OnDailyRewardsLoaded, g_sEarnDBBuffer, pack);
}

void Earn_OnDailyRewardsLoaded(Database db, DBResultSet results, const char[] error, DataPack pack)
{
	if (!results)
	{
		LogError("OnDailyRewardsLoaded query failure: %s", error);
		return;
	}
	
	char steamid[32];

	pack.Reset();
	
	int client = GetClientOfUserId(pack.ReadCell());
	pack.ReadString(steamid, sizeof(steamid));
	
	if (!client)
		return;
	
	if (results.FetchRow())
	{
		g_iEarnDailyDate[client] = results.FetchInt(0);
		g_iEarnDailyDay[client] = results.FetchInt(1);
	}
	else
	{
		char query[255];
		FormatTime(g_sEarnCurrentDate, sizeof(g_sEarnCurrentDate), "%Y%m%d");
		FormatEx(query, sizeof(query), "INSERT INTO store_daily_rewards(steamid, store_date, store_day) VALUES('%s', %i, %i);",
														steamid, StringToInt(g_sEarnCurrentDate), 0);
		g_hEarnDB.Query(SQL_NullCallback, query);
	}
	
	g_bEarnDailyCached[client] = true;
}

Action Earn_Command_Daily(int client, int args)
{
	FormatTime(g_sEarnCurrentDate, sizeof(g_sEarnCurrentDate), "%Y%m%d");
	
	char steamid[32];
	GetClientAuthId(client, AuthId_Steam2, steamid, sizeof(steamid));
	
	if (g_iEarnDaily[g_iEarnActive[client]][0] == -1 || !Earn_CheckSteamAuth(client, g_sEarnSteam[client]))
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "You dont have permission CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "You dont have permission");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "You dont have permission");
		#endif
		return Plugin_Handled;
	}
	
	if (!g_bEarnDailyCached[client])
		return Plugin_Handled;
	
	char sBuffer[64];
	if (!g_hEarnDB)
	{
		if (!AreClientCookiesCached(client))
			return Plugin_Handled;
		
		g_cEarnDate.Get(client, sBuffer, sizeof(sBuffer));
		g_iEarnDailyDate[client] = StringToInt(sBuffer);
		g_cEarnDay.Get(client, sBuffer, sizeof(sBuffer));
		g_iEarnDailyDay[client] = StringToInt(sBuffer);
	}
	
	int iNow = StringToInt(g_sEarnCurrentDate);
	
	if (iNow - g_iEarnDailyDate[client] == 0)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Wait until next daily 2 CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Wait until next daily 2");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Wait until next daily 2");
		#endif
	}
	else
	{
		if (iNow - g_iEarnDailyDate[client] >=2 || g_iEarnDailyDay[client] < 1)
		{
			if(g_iEarnDailyDate[client])
			{
				#if defined _clientmod_included
					MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Lose Streak Of CM", (iNow - g_iEarnDailyDate[client]))
					C_PrintToChat(client, "%s %t", g_sChatPrefix, "Lose Streak Of", (iNow - g_iEarnDailyDate[client]))
				#else
					PrintToChat(client, "%s %t", g_sChatPrefix, "Lose Streak Of", (iNow - g_iEarnDailyDate[client]))
				#endif
			}
				
			g_iEarnDailyDay[client] = 1;
		}

		Store_SetClientCredits(client, Store_GetClientCredits(client) + g_iEarnDaily[g_iEarnActive[client]][g_iEarnDailyDay[client] - 1]);

		switch(g_iEarnDailyDay[client])
		{
			case 2, 3, 4, 5, 6: 
			{
				#if defined _clientmod_included
					MC_PrintToChat(client, "%s %t%t", g_sChatPrefix_CM, "You earned x Credits for CM", g_iEarnDaily[g_iEarnActive[client]][g_iEarnDailyDay[client] - 1], g_sCreditsName, "playing x on our server in row CM", g_iEarnDailyDay[client]);
					C_PrintToChat(client, "%s %t%t", g_sChatPrefix, "You earned x Credits for", g_iEarnDaily[g_iEarnActive[client]][g_iEarnDailyDay[client] - 1], g_sCreditsName, "playing x on our server in row", g_iEarnDailyDay[client]);
				#else
					PrintToChat(client, "%s %t%t", g_sChatPrefix, "You earned x Credits for", g_iEarnDaily[g_iEarnActive[client]][g_iEarnDailyDay[client] - 1], g_sCreditsName, "playing x on our server in row", g_iEarnDailyDay[client]);
				#endif
			}
			case 7:
			{
				#if defined _clientmod_included
					MC_PrintToChat(client, "%s %t%t", g_sChatPrefix_CM, "You earned x Credits for CM", g_iEarnDaily[g_iEarnActive[client]][g_iEarnDailyDay[client] - 1], g_sCreditsName, "playing x on our server in row CM", g_iEarnDailyDay[client]);
					C_PrintToChat(client, "%s %t%t", g_sChatPrefix, "You earned x Credits for", g_iEarnDaily[g_iEarnActive[client]][g_iEarnDailyDay[client] - 1], g_sCreditsName, "playing x on our server in row", g_iEarnDailyDay[client]);
					MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "You mastered the daily challange CM");
					C_PrintToChat(client, "%s %t", g_sChatPrefix, "You mastered the daily challange");
				#else
					PrintToChat(client, "%s %t%t", g_sChatPrefix, "You earned x Credits for", g_iEarnDaily[g_iEarnActive[client]][g_iEarnDailyDay[client] - 1], g_sCreditsName, "playing x on our server in row", g_iEarnDailyDay[client]);
					PrintToChat(client, "%s %t", g_sChatPrefix, "You mastered the daily challange");
				#endif	
				Store_SQLLogMessage(client, LOG_EVENT, "Mastered the daily challange (7days) for %i credits'", g_iEarnDaily[g_iEarnActive[client]][g_iEarnDailyDay[client] - 1]);
				g_iEarnDailyDay[client] = 0;
			}
			default:
			{
				#if defined _clientmod_included
					MC_PrintToChat(client, "%s %t%t", g_sChatPrefix_CM, "You earned x Credits for CM", g_iEarnDaily[g_iEarnActive[client]][0], g_sCreditsName, "start daily challange CM");
					C_PrintToChat(client, "%s %t%t", g_sChatPrefix, "You earned x Credits for", g_iEarnDaily[g_iEarnActive[client]][0], g_sCreditsName, "start daily challange");
				#else
					PrintToChat(client, "%s %t%t", g_sChatPrefix, "You earned x Credits for", g_iEarnDaily[g_iEarnActive[client]][0], g_sCreditsName, "start daily challange");
				#endif
			}
		}

		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "You'll earn x Credits tomorrow CM", g_iEarnDaily[g_iEarnActive[client]][g_iEarnDailyDay[client]], g_sCreditsName);
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "You'll earn x Credits tomorrow", g_iEarnDaily[g_iEarnActive[client]][g_iEarnDailyDay[client]], g_sCreditsName);
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "You'll earn x Credits tomorrow", g_iEarnDaily[g_iEarnActive[client]][g_iEarnDailyDay[client]], g_sCreditsName);
		#endif
		
		if (!g_hEarnDB)
		{
			IntToString(g_iEarnDailyDay[client] + 1, sBuffer, sizeof(sBuffer));
			g_cEarnDay.Set(client, sBuffer);
			
			IntToString(iNow, sBuffer, sizeof(sBuffer));
			g_cEarnDate.Set(client, sBuffer);
		}
		else
		{
			FormatEx(g_sEarnDBBuffer, sizeof(g_sEarnDBBuffer), "REPLACE INTO store_daily_rewards(steamid, store_date, store_day) VALUES('%s', %i, %i);",
														steamid, iNow, g_iEarnDailyDay[client] + 1);
			g_hEarnDB.Query(SQL_NullCallback, g_sEarnDBBuffer);
		}
		
		g_iEarnDailyDay[client] += 1;
		g_iEarnDailyDate[client] = iNow;
	}

	return Plugin_Handled;
}

Action Earn_OnTakeDamage(int victim, int &attacker, int &inflictor, float &damage, int &damagetype, int &weapon, float damageForce[3], const float damagePosition[3])
{
	char Buffer[255];
	
	int count = Earn_PlayerCount();

	if (!(damagetype & DMG_SLASH))
		return Plugin_Continue;

	if (!IsValidClient(victim, true, true) || attacker == victim || !IsValidClient(attacker, true, false))
		return Plugin_Continue;

	if (count < g_iEarnMinPlayer[g_iEarnActive[attacker]])
		return Plugin_Continue;

	if (g_iEarnBackstab[g_iEarnActive[attacker]] < 1 && g_iEarnKnife[g_iEarnActive[attacker]] < 1)
		return Plugin_Continue;

	if (!Earn_CheckSteamAuth(attacker, g_sEarnSteam[attacker]))
		return Plugin_Continue;

	if (IsFakeClient(victim) && !g_bEarnBots[g_iEarnActive[attacker]])
		return Plugin_Continue;

	char sWeapon[32];
	GetClientWeapon(attacker, sWeapon, sizeof(sWeapon));
	if (StrContains(sWeapon, "knife") != -1)
	{
		if (damage > 99.0)
		{
			Format(Buffer, sizeof(Buffer), "%s", "backstab kill");
			if(GetClientTeam(attacker) != GetClientTeam(victim))
			{
				Earn_GiveCredits(attacker, g_iEarnBackstab[g_iEarnActive[attacker]], Buffer);
			}
		}
		else if (damage > GetClientHealth(victim))
		{
			if(GetClientTeam(attacker) != GetClientTeam(victim))
			{
				Format(Buffer, sizeof(Buffer), "%s", "knife kill");
				Earn_GiveCredits(attacker, g_iEarnKnife[g_iEarnActive[attacker]], Buffer);
			}
		}
	}

	return Plugin_Continue;
}

void Earn_GiveCredits(int client, int credits, char[] reason)
{
	float multi[3] = {1.0, ...};
	char sBuffer[64];

	GetClientName(client, sBuffer, sizeof(sBuffer));
	if (StrContains(sBuffer, g_szEarnNick[g_iEarnActive[client]], false) != -1 && g_szEarnNick[g_iEarnActive[client]][0])
	{
		multi[0] = g_fEarnNick[g_iEarnActive[client]];
	}

	if (StrEqual(sBuffer, g_szEarnTag[g_iEarnActive[client]]) && g_szEarnTag[g_iEarnActive[client]][0])
	{
		multi[1] = g_fEarnTag[g_iEarnActive[client]];
	}

	if (g_bEarnGroupMember[client])
	{
		multi[2] = g_fEarnGroup[g_iEarnActive[client]];
	}

	credits = RoundToNearest(credits * multi[0] * multi[1] * multi[2] * g_fEarnClientMulti[client]);

	Store_SetClientCredits(client, Store_GetClientCredits(client) + credits);

	switch(g_iEarnMsg[g_iEarnActive[client]])
	{
		case 1: 
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t%t", g_sChatPrefix_CM, "You earned x Credits for CM", credits, g_sCreditsName, reason);
				C_PrintToChat(client, "%s %t%t", g_sChatPrefix, "You earned x Credits for", credits, g_sCreditsName, reason);
			#else
				PrintToChat(client, "%s %t%t", g_sChatPrefix, "You earned x Credits for", credits, g_sCreditsName, reason);
			#endif
		}
		case 2: g_iEarnSum[client] += credits;
		case 3:
		{
			int iBuffer;
			if (g_hEarnSum[client].GetValue(reason, iBuffer))
			{
				g_hEarnSum[client].SetValue(reason, credits + iBuffer);
			}
			else
			{
				g_hEarnSum[client].SetValue(reason, credits);
			}
		}
	}
}

Action Earn_Timer_Timer(Handle timer)
{
	char Buffer[255];
	int count = Earn_PlayerCount();

	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || IsFakeClient(i))
			continue;

		if (count < g_iEarnMinPlayer[g_iEarnActive[i]])
			continue;

		if (!Earn_CheckSteamAuth(i, g_sEarnSteam[i]))
			continue;

		if (CS_TEAM_T <= GetClientTeam(i) <= CS_TEAM_CT)
		{
			g_iEarnTime[i][EARN_ACTIVE]++;
		}
		else
		{
			g_iEarnTime[i][EARN_INACTIVE]++;
		}

		if (g_iEarnTime[i][EARN_ACTIVE] >= g_fEarnTimer[g_iEarnActive[i]])
		{
			g_iEarnTime[i][EARN_ACTIVE] = 0;
			if(g_iEarnPlay[g_iEarnActive[i]] > 0)
			{
				Format(Buffer, sizeof(Buffer), "%s", "playing on the server");
				Earn_GiveCredits(i, g_iEarnPlay[g_iEarnActive[i]], Buffer);
			}
		}
		else if (g_iEarnTime[i][EARN_INACTIVE] >= g_fEarnTimer[g_iEarnActive[i]])
		{
			g_iEarnTime[i][EARN_INACTIVE] = 0;
			if(g_iEarnInactive[g_iEarnActive[i]] > 0)
			{
				Format(Buffer, sizeof(Buffer), "%s", "idle on the server");
				Earn_GiveCredits(i, g_iEarnInactive[g_iEarnActive[i]], Buffer);
			}
		}
	}

	return Plugin_Continue;
}

public void Earn_Event_PlayerDeath(Event event, char[] name, bool dontBroadcast)
{
	int victim = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int count = Earn_PlayerCount();
	
	if (!IsValidClient(victim, g_bEarnBots[g_iEarnActive[attacker]], true))
		return;

	if (!IsValidClient(attacker, true, true))
		return;

	if (count < g_iEarnMinPlayer[g_iEarnActive[attacker]])
		return;

	int assister = GetClientOfUserId(event.GetInt("assister"));
	bool headshot = event.GetBool("headshot");
	char sWeapon[32], Buffer[255];
	event.GetString("weapon", sWeapon, sizeof(sWeapon));
	
	if (IsValidClient(assister) && g_iEarnAssist[g_iEarnActive[assister]] > 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "assist a kill");
		Earn_GiveCredits(assister, g_iEarnAssist[g_iEarnActive[assister]], Buffer);
	}

	if (attacker == victim && g_iEarnSuicide[g_iEarnActive[attacker]] != 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "kill yourself");
		Earn_GiveCredits(attacker, g_iEarnSuicide[g_iEarnActive[attacker]], Buffer);
	}

	if (!IsFakeClient(victim) && g_iEarnMsg[g_iEarnActive[victim]] == 2)
	{
		if (g_iEarnSum[victim] != 0)
		{
			#if defined _clientmod_included
				MC_PrintToChat(victim, "%s %t", g_sChatPrefix_CM, "You earned x Credits this round CM", g_iEarnSum[victim], g_sCreditsName);
				C_PrintToChat(victim, "%s %t", g_sChatPrefix, "You earned x Credits this round", g_iEarnSum[victim], g_sCreditsName);
			#else
				PrintToChat(victim, "%s %t", g_sChatPrefix, "You earned x Credits this round", g_iEarnSum[victim], g_sCreditsName);
			#endif
		}
		g_iEarnSum[victim] = 0;
	}
	else if (!IsFakeClient(victim) && g_iEarnMsg[g_iEarnActive[victim]] == 3)
	{
		if (g_hEarnSum[victim].Size > 0)
		{
			StringMapSnapshot hSum = g_hEarnSum[victim].Snapshot();
			char sBuffer[32];
			int sum = 0;
			#if defined _clientmod_included
				MC_PrintToChat(victim, "%s %t", g_sChatPrefix_CM, "You earned this round CM");
				MC_PrintToChat(victim, "%s %t", g_sChatPrefix_CM, "Spacer CM");
				C_PrintToChat(victim, "%s %t", g_sChatPrefix, "You earned this round");
				C_PrintToChat(victim, "%s %t", g_sChatPrefix, "Spacer");
			#else
				PrintToChat(victim, "%s %t", g_sChatPrefix, "You earned this round");
				PrintToChat(victim, "%s %t", g_sChatPrefix, "Spacer");
			#endif
			for (int i = 0; i < hSum.Length; i++)
			{
				hSum.GetKey(i, sBuffer, sizeof(sBuffer));
				int value;
				g_hEarnSum[victim].GetValue(sBuffer, value);
				sum += value;
				#if defined _clientmod_included
					MC_PrintToChat(victim, "%s %t", g_sChatPrefix_CM, "x Credits for CM", value, g_sCreditsName, sBuffer);
					C_PrintToChat(victim, "%s %t", g_sChatPrefix, "x Credits for", value, g_sCreditsName, sBuffer);
				#else
					PrintToChat(victim, "%s %t", g_sChatPrefix, "x Credits for", value, g_sCreditsName, sBuffer);
				#endif
			}
			#if defined _clientmod_included
				MC_PrintToChat(victim, "%s %t", g_sChatPrefix_CM, "Spacer CM");
				MC_PrintToChat(victim, "%s %t", g_sChatPrefix_CM, "Total Credits CM", sum, g_sCreditsName);
				C_PrintToChat(victim, "%s %t", g_sChatPrefix, "Spacer");
				C_PrintToChat(victim, "%s %t", g_sChatPrefix, "Total Credits", sum, g_sCreditsName);
			#else
				PrintToChat(victim, "%s %t", g_sChatPrefix, "Spacer");
				PrintToChat(victim, "%s %t", g_sChatPrefix, "Total Credits", sum, g_sCreditsName);
			#endif

			delete hSum;
			g_hEarnSum[victim].Clear();
		}
		else
		{
			#if defined _clientmod_included
				MC_PrintToChat(victim, "%s %t", g_sChatPrefix_CM, "You earned no points this round CM");
				C_PrintToChat(victim, "%s %t", g_sChatPrefix, "You earned no points this round");
			#else
				PrintToChat(victim, "%s %t", g_sChatPrefix, "You earned no points this round");
			#endif
		}
	}

	if (attacker == victim)
		return;

	if (StrContains(sWeapon, "knife") != -1)
		return;

	if (GetClientTeam(attacker) == GetClientTeam(victim) && g_iEarnTK[g_iEarnActive[attacker]] != 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "teamkill");
		Earn_GiveCredits(attacker, g_iEarnTK[g_iEarnActive[attacker]], Buffer);
		return;
	}
	else if (StrContains(sWeapon, "hegrenade") != -1 && g_iEarnHE[g_iEarnActive[attacker]] > 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "HE grenade kill");
		Earn_GiveCredits(attacker, g_iEarnHE[g_iEarnActive[attacker]], Buffer);
	}
	else if (StrContains(sWeapon, "flashbang") != -1 && g_iEarnFlash[g_iEarnActive[attacker]] > 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "flashbang kill");
		Earn_GiveCredits(attacker, g_iEarnFlash[g_iEarnActive[attacker]], Buffer);
	}
	else if (StrContains(sWeapon, "smokegrenade") != -1 && g_iEarnSmoke[g_iEarnActive[attacker]] > 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "smokegrenade kill");
		Earn_GiveCredits(attacker, g_iEarnSmoke[g_iEarnActive[attacker]], Buffer);
	}
	else if ((StrContains(sWeapon, "awp") != -1 || StrContains(sWeapon, "scout") != -1 || StrContains(sWeapon, "sg550") != -1 || StrContains(sWeapon, "sg552") != -1 || StrContains(sWeapon, "g3sg1") != -1)
			&& g_iEarnNoScope[g_iEarnActive[attacker]] > 0 && !(0 < GetEntProp(attacker, Prop_Data, "m_iFOV") < GetEntProp(attacker, Prop_Data, "m_iDefaultFOV")))
	{
		Format(Buffer, sizeof(Buffer), "%s", "noscope kill");
		Earn_GiveCredits(attacker, g_iEarnNoScope[g_iEarnActive[attacker]], Buffer);
	}
	else if (headshot && g_iEarnHeadshot[g_iEarnActive[attacker]] > 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "headshot");
		Earn_GiveCredits(attacker, g_iEarnHeadshot[g_iEarnActive[attacker]], Buffer);
	}
	else if (g_iEarnKill[g_iEarnActive[attacker]] > 0)
	{
		Format(Buffer, sizeof(Buffer), "%s", "kill");
		Earn_GiveCredits(attacker, g_iEarnKill[g_iEarnActive[attacker]], Buffer);
	}
}

public void Earn_Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	int winner = event.GetInt("winner");
	int count = Earn_PlayerCount();
	char Buffer[255];
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsValidClient(i, false, false))
			continue;

		if (GetClientTeam(i) == winner)
		{
			if (count >= g_iEarnMinPlayer[g_iEarnActive[i]] && g_iEarnWin[g_iEarnActive[i]] > 0)
			{
				Format(Buffer, sizeof(Buffer), "%s", "win the round");
				Earn_GiveCredits(i, g_iEarnWin[g_iEarnActive[i]], Buffer);
			}
		}

		if (g_iEarnMsg[g_iEarnActive[i]] == 2)
		{
			if (g_iEarnSum[i] == 0)
				continue;

			#if defined _clientmod_included
				MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "You earned x Credits this round CM", g_iEarnSum[i], g_sCreditsName);
				C_PrintToChat(i, "%s %t", g_sChatPrefix, "You earned x Credits this round", g_iEarnSum[i], g_sCreditsName);
			#else
				PrintToChat(i, "%s %t", g_sChatPrefix, "You earned x Credits this round", g_iEarnSum[i], g_sCreditsName);
			#endif
			g_iEarnSum[i] = 0;
		}
		else if (g_iEarnMsg[g_iEarnActive[i]] == 3)
		{
			if (g_hEarnSum[i].Size > 0)
			{
				StringMapSnapshot hSum = g_hEarnSum[i].Snapshot();
				char sBuffer[32];
				int sum = 0;
				#if defined _clientmod_included
					MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "You earned this round CM");
					MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "Spacer CM");
					C_PrintToChat(i, "%s %t", g_sChatPrefix, "You earned this round");
					C_PrintToChat(i, "%s %t", g_sChatPrefix, "Spacer");
				#else
					PrintToChat(i, "%s %t", g_sChatPrefix, "You earned this round");
					PrintToChat(i, "%s %t", g_sChatPrefix, "Spacer");
				#endif
				for (int j = 0; j < hSum.Length; j++)
				{
					hSum.GetKey(j, sBuffer, sizeof(sBuffer));
					int value;
					g_hEarnSum[i].GetValue(sBuffer, value);
					sum += value;
					#if defined _clientmod_included
						MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "x Credits for CM", value, g_sCreditsName, sBuffer);
						C_PrintToChat(i, "%s %t", g_sChatPrefix, "x Credits for", value, g_sCreditsName, sBuffer);
					#else
						PrintToChat(i, "%s %t", g_sChatPrefix, "x Credits for", value, g_sCreditsName, sBuffer);
					#endif
				}
				#if defined _clientmod_included
					MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "Spacer CM");
					MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "Total Credits CM", sum, g_sCreditsName);
					C_PrintToChat(i, "%s %t", g_sChatPrefix, "Spacer");
					C_PrintToChat(i, "%s %t", g_sChatPrefix, "Total Credits", sum, g_sCreditsName);
				#else
					PrintToChat(i, "%s %t", g_sChatPrefix, "Spacer");
					PrintToChat(i, "%s %t", g_sChatPrefix, "Total Credits", sum, g_sCreditsName);
				#endif

				delete hSum;
				g_hEarnSum[i].Clear();
			}
			else
			{
				#if defined _clientmod_included
					MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "You earned no points this round CM");
					C_PrintToChat(i, "%s %t", g_sChatPrefix, "You earned no points this round");
				#else
					PrintToChat(i, "%s %t", g_sChatPrefix, "You earned no points this round");
				#endif
			}
		}
	}
}

public void Earn_Event_BombPlanted(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int count = Earn_PlayerCount();
	char Buffer[255];

	if (!IsValidClient(client, false, true))
		return;

	if (!Earn_CheckSteamAuth(client, g_sEarnSteam[client]))
		return;

	if (count < g_iEarnMinPlayer[g_iEarnActive[client]])
		return;

	if (g_iEarnPlant[g_iEarnActive[client]] < 1)
		return;

	Format(Buffer, sizeof(Buffer), "%s", "bomb planted");
	Earn_GiveCredits(client, g_iEarnPlant[g_iEarnActive[client]], Buffer);
}

public void Earn_Event_BombDefused(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int count = Earn_PlayerCount();
	
	char Buffer[255];
	Format(Buffer, sizeof(Buffer), "%s", "bomb defused");

	if (!IsValidClient(client, false, true))
		return;

	if (!Earn_CheckSteamAuth(client, g_sEarnSteam[client]))
		return;

	if (count < g_iEarnMinPlayer[g_iEarnActive[client]])
		return;

	if (g_iEarnDefuse[g_iEarnActive[client]] < 1)
		return;

	Earn_GiveCredits(client, g_iEarnDefuse[g_iEarnActive[client]], Buffer);
}

public void Earn_Event_BombExploded(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int count = Earn_PlayerCount();
	
	char Buffer[255];
	Format(Buffer, sizeof(Buffer), "%s", "bomb explode");

	if (!IsValidClient(client, false, true))
		return;

	if (!Earn_CheckSteamAuth(client, g_sEarnSteam[client]))
		return;

	if (count < g_iEarnMinPlayer[g_iEarnActive[client]])
		return;

	if (g_iEarnExplode[g_iEarnActive[client]] < 1)
		return;

	Earn_GiveCredits(client, g_iEarnExplode[g_iEarnActive[client]], Buffer);
}

public void Earn_Event_HostageRescued(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int count = Earn_PlayerCount();
	
	char Buffer[255];
	Format(Buffer, sizeof(Buffer), "%s", "hostage rescued");

	if (!IsValidClient(client, false, true))
		return;

	if (!Earn_CheckSteamAuth(client, g_sEarnSteam[client]))
		return;

	if (count < g_iEarnMinPlayer[g_iEarnActive[client]])
		return;

	if (g_iEarnRescued[g_iEarnActive[client]] < 1)
		return;

	Earn_GiveCredits(client, g_iEarnRescued[g_iEarnActive[client]], Buffer);
}

public void Earn_Event_VipKilled(Event event, const char[] name, bool dontBroadcast)
{
	int attacker = GetClientOfUserId(event.GetInt("attacker"));
	int count = Earn_PlayerCount();
	
	char Buffer[255];
	Format(Buffer, sizeof(Buffer), "%s", "kill the VIP");

	if (!IsValidClient(attacker, false, true))
		return;

	if (!Earn_CheckSteamAuth(attacker, g_sEarnSteam[attacker]))
		return;

	if (count < g_iEarnMinPlayer[g_iEarnActive[attacker]])
		return;

	if (g_iEarnVIPkill[g_iEarnActive[attacker]] < 1)
		return;

	Earn_GiveCredits(attacker, g_iEarnVIPkill[g_iEarnActive[attacker]], Buffer);
}

public void Earn_Event_VipEscaped(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int count = Earn_PlayerCount();
	
	char Buffer[255];
	Format(Buffer, sizeof(Buffer), "%s", "escape as VIP");

	if (!IsValidClient(client, false, true))
		return;

	if (!Earn_CheckSteamAuth(client, g_sEarnSteam[client]))
		return;

	if (count < g_iEarnMinPlayer[g_iEarnActive[client]])
		return;

	if (g_iEarnVIPescape[g_iEarnActive[client]] < 1)
		return;

	Earn_GiveCredits(client, g_iEarnVIPescape[g_iEarnActive[client]], Buffer);
}

void Earn_LoadConfig()
{
	char sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, sizeof(sFile), "configs/store/earnings.txt");
	KeyValues kv = new KeyValues("Earnings");
	kv.ImportFromFile(sFile);
	if (!kv.GotoFirstSubKey())
	{
		LogError("Locate \"addons/sourcemod/configs/store/earnings.txt\" not found or not configured");
		SetFailState("Failed to read configs/store/earnings.txt");
	}

	GoThroughConfig(kv);
	delete kv;
}

void GoThroughConfig(KeyValues &kv)
{
	char sBuffer[64];

	g_iEarnCount = 0;

	do
	{
		if (g_iEarnCount == MAX_OBJECTIVES)
			break;

		kv.GetSectionName(g_szEarnName[g_iEarnCount], 64);

		kv.GetString("flags", sBuffer, sizeof(sBuffer), "");
		g_iEarnFlagBits[g_iEarnCount] = ReadFlagString(sBuffer);
		g_iEarnMinPlayer[g_iEarnCount] = kv.GetNum("player", 0);
		g_bEarnBots[g_iEarnCount] = kv.GetNum("bots", 0) ? true : false;
		g_fEarnTimer[g_iEarnCount] = kv.GetFloat("timer", 10.0);
		g_iEarnPlay[g_iEarnCount] = kv.GetNum("active", 0);
		g_iEarnInactive[g_iEarnCount] = kv.GetNum("inactive", 0);
		g_iEarnKill[g_iEarnCount] = kv.GetNum("kill", 0);
		g_iEarnTK[g_iEarnCount] = kv.GetNum("tk", 0);
		g_iEarnSuicide[g_iEarnCount] = kv.GetNum("suicide", 0);
		g_iEarnAssist[g_iEarnCount] = kv.GetNum("assist", 0);
		g_iEarnHeadshot[g_iEarnCount] = kv.GetNum("headshot", 0);
		g_iEarnNoScope[g_iEarnCount] = kv.GetNum("noscope", 0);
		g_iEarnBackstab[g_iEarnCount] = kv.GetNum("backstab", 0);
		g_iEarnKnife[g_iEarnCount] = kv.GetNum("knife", 0);
		g_iEarnHE[g_iEarnCount] = kv.GetNum("he", 0);
		g_iEarnFlash[g_iEarnCount] = kv.GetNum("flash", 0);
		g_iEarnSmoke[g_iEarnCount] = kv.GetNum("smoke", 0);
		g_iEarnWin[g_iEarnCount] = kv.GetNum("win", 0);
		g_iEarnPlant[g_iEarnCount] = kv.GetNum("plant", 0);
		g_iEarnDefuse[g_iEarnCount] = kv.GetNum("defuse", 0);
		g_iEarnExplode[g_iEarnCount] = kv.GetNum("explode", 0);
		g_iEarnRescued[g_iEarnCount] = kv.GetNum("rescued", 0);
		g_iEarnVIPkill[g_iEarnCount] = kv.GetNum("vip_kill", 0);
		g_iEarnVIPescape[g_iEarnCount] = kv.GetNum("vip_escape", 0);
		g_iEarnMsg[g_iEarnCount] = kv.GetNum("msg", 0);
		kv.GetString("nick", g_szEarnNick[g_iEarnCount], 64, "");
		g_fEarnNick[g_iEarnCount] = kv.GetFloat("nick_multi", 1.0);
		kv.GetString("clantag", g_szEarnTag[g_iEarnCount], 64, "");
		g_fEarnTag[g_iEarnCount] = kv.GetFloat("clantag_multi", 1.0);
		g_iEarnGroup[g_iEarnCount] = kv.GetNum("groupid", 0);
		g_fEarnGroup[g_iEarnCount] = kv.GetFloat("groupid_multi", 1.0);
		if (kv.JumpToKey("Dailys"))
		{
			kv.GotoFirstSubKey();
			do
			{
				g_iEarnDaily[g_iEarnCount][0] = kv.GetNum("1", -1);
				g_iEarnDaily[g_iEarnCount][1] = kv.GetNum("2", 0);
				g_iEarnDaily[g_iEarnCount][2] = kv.GetNum("3", 0);
				g_iEarnDaily[g_iEarnCount][3] = kv.GetNum("4", 0);
				g_iEarnDaily[g_iEarnCount][4] = kv.GetNum("5", 0);
				g_iEarnDaily[g_iEarnCount][5] = kv.GetNum("6", 0);
				g_iEarnDaily[g_iEarnCount][6] = kv.GetNum("7", 0);
			}
			while (kv.GotoNextKey());

			kv.GoBack();
		}

		g_iEarnCount++;

	}
	while (kv.GotoNextKey());
}

bool Earn_CheckFlagBits(int client, int flagsNeed, int flags = -1)
{
	if (flags==-1)
	{
		flags = GetUserFlagBits(client);
	}

	if (flagsNeed == 0 || flags & flagsNeed || flags & ADMFLAG_ROOT)
	{
		return true;
	}

	return false;
}

bool Earn_CheckSteamAuth(int client, char[] steam)
{
	if (!steam[0])
		return true;

	char sSteam[32];
	if (!GetClientAuthId(client, AuthId_Steam2, sSteam, 32))
		return false;

	if (StrContains(steam, sSteam) == -1)
		return false;

	return true;
}

public int Earn_PlayerCount()
{
	int count;
	for (int i=1;i<=MaxClients;i++)
		if(IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i))
			count++;
	
	return count;
}

#if !defined _store_stocks_included
bool IsValidClient(int client, bool bots = true, bool dead = true)
{
	if (client <= 0)
		return false;

	if (client > MaxClients)
		return false;

	if (!IsClientInGame(client))
		return false;

	if (IsFakeClient(client) && !bots)
		return false;

	if (IsClientSourceTV(client))
		return false;

	if (IsClientReplay(client))
		return false;

	if (!IsPlayerAlive(client) && !dead)
		return false;

	return true;
}
#endif

void SQL_NullCallback(Database db, DBResultSet results, const char[] error, any data)
{
	if (!results)
		LogError("Query failure: %s", error);
}

#else
void Earnings_OnPluginStart() {}
void Earnings_OnMapStart() {}
void Earnings_OnClientConnected(int client)
{
	#pragma unused client
}
void Earnings_OnClientDisconnect(int client)
{
	#pragma unused client
}
void Earnings_OnClientPostAdminCheck(int client)
{
	#pragma unused client
}
void Earnings_OnConfigExecuted() {}
void Earnings_OnClientCookiesCached(int client)
{
	#pragma unused client
}
#endif