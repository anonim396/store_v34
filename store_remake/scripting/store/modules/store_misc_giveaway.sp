#if STORE_MODULE_MISC_GIVEAWAY

ConVar gc_GWCredits, gc_GWMinPlayer, gc_GWTimeInfo, gc_GWAdmin;
ConVar g_cvGWCenterTag;

char g_sGWCenterPrefix[128];
char g_sGWAdmins[MAX_NAME_LENGTH];
int g_iGWNumber, g_iGWCredits, g_iGWCreatorID;
Handle g_hGWTimers;

void Giveaway_OnPluginStart()
{
	gc_GWCredits = CreateConVar("sm_giveaway_credits", "1000", "Number of credits given.");
	gc_GWMinPlayer = CreateConVar("sm_giveaway_minplayers", "5", "Minimum players for giveaway.");
	gc_GWTimeInfo = CreateConVar("sm_giveaway_time_info", "10", "Time in seconds of giveaway announcement. Min 10.");
	gc_GWAdmin = CreateConVar("sm_giveaway_count_admin", "1", "Can admin join [0 - no, 1 - yes]");
	RegAdminCmd("sm_giveaway", Giveaway_CommandGiveaway, ADMFLAG_ROOT, "Start giveaway");
	Store_BeginModuleConfig("sourcemod/store", "giveaway");
	STORE_CFG("sm_giveaway_credits", "1000");
	STORE_CFG("sm_giveaway_minplayers", "5");
	STORE_CFG("sm_giveaway_time_info", "10");
	STORE_CFG("sm_giveaway_count_admin", "1");
	Store_EndModuleConfig("sourcemod/store", "giveaway");
}

void Giveaway_OnConfigExecuted()
{
	g_cvGWCenterTag = FindConVar("sm_store_center_tag");
	if (g_cvGWCenterTag != null)
		g_cvGWCenterTag.GetString(g_sGWCenterPrefix, sizeof(g_sGWCenterPrefix));
}

static int Giveaway_PlayerCount()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i))
			count++;
	return count;
}

static int Giveaway_PlayerCountNoAdmin()
{
	int count = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && IsClientConnected(i) && !IsFakeClient(i) && !CheckCommandAccess(i, "sm_giveaway_flag_overwrite", ADMFLAG_GENERIC))
			count++;
	return count;
}

public Action Giveaway_CommandGiveaway(int client, int args)
{
	int count = gc_GWAdmin.BoolValue ? Giveaway_PlayerCount() : Giveaway_PlayerCountNoAdmin();
	if (!args)
	{
		g_iGWNumber = gc_GWTimeInfo.IntValue;
		g_iGWCredits = gc_GWCredits.IntValue;
		if (count > gc_GWMinPlayer.IntValue)
		{
			char name[MAX_NAME_LENGTH];
			GetClientName(client, name, MAX_NAME_LENGTH);
			Giveaway_CountDown(name);
			strcopy(g_sGWAdmins, sizeof(g_sGWAdmins), name);
			g_iGWCreatorID = client;
			return Plugin_Continue;
		}
		#if defined _clientmod_included
			MC_PrintToChat(client, "%t ", "Giveaway Minimum Players CM", g_sChatPrefix_CM, gc_GWMinPlayer.IntValue);
			C_PrintToChat(client, "%t ", "Giveaway Minimum Players", g_sChatPrefix, gc_GWMinPlayer.IntValue);
		#else
			PrintToChat(client, "%t ", "Giveaway Minimum Players", g_sChatPrefix, gc_GWMinPlayer.IntValue);
		#endif
	}
	else if (args == 1)
	{
		char temp[64];
		GetCmdArg(1, temp, sizeof(temp));
		g_iGWCredits = StringToInt(temp);
		g_iGWNumber = gc_GWTimeInfo.IntValue;
		if (count > gc_GWMinPlayer.IntValue)
		{
			char name[MAX_NAME_LENGTH];
			GetClientName(client, name, MAX_NAME_LENGTH);
			Giveaway_CountDown(name);
			strcopy(g_sGWAdmins, sizeof(g_sGWAdmins), name);
			g_iGWCreatorID = client;
			return Plugin_Continue;
		}
		#if defined _clientmod_included
			MC_PrintToChat(client, "%t ", "Giveaway Minimum Players CM", g_sChatPrefix_CM, gc_GWMinPlayer.IntValue);
			C_PrintToChat(client, "%t ", "Giveaway Minimum Players", g_sChatPrefix, gc_GWMinPlayer.IntValue);
		#else
			PrintToChat(client, "%t ", "Giveaway Minimum Players", g_sChatPrefix, gc_GWMinPlayer.IntValue);
		#endif
	}
	else
		ReplyToCommand(client, "%s Usage: sm_giveaway <credits>", g_sChatPrefix);
	return Plugin_Handled;
}

public Action Giveaway_TimerGiveaway(Handle timer, any data)
{
	static int Number = 0;
	char sBuffer[254];
	if (Number >= 100)
	{
		Number = 0;
		char name[MAX_NAME_LENGTH];
		int randomNumber = gc_GWAdmin.BoolValue ? Giveaway_GetRandomPlayer() : Giveaway_GetRandomPlayerNoAdmin();
		GetClientName(randomNumber, name, MAX_NAME_LENGTH);
		Format(sBuffer, sizeof(sBuffer), "%t", "Giveaway winner hint text", g_sGWCenterPrefix, name);
		PrintCenterTextAll(sBuffer);
		#if defined _clientmod_included
			MC_PrintToChatAll("%t ", "Giveaway winner chat CM", g_sChatPrefix_CM, name, g_iGWCredits);
			C_PrintToChatAll("%t ", "Giveaway winner chat", g_sChatPrefix, name, g_iGWCredits);
		#else
			PrintToChatAll("%t ", "Giveaway winner chat", g_sChatPrefix, name, g_iGWCredits);
		#endif
		Store_SetClientCredits(randomNumber, Store_GetClientCredits(randomNumber) + g_iGWCredits);
		Store_SQLLogMessage(g_iGWCreatorID, LOG_EVENT, "The admin %s did a giveaway and %s won", g_sGWAdmins, name);
		return Plugin_Stop;
	}
	char name[MAX_NAME_LENGTH];
	int randomNumber = gc_GWAdmin.BoolValue ? Giveaway_GetRandomPlayer() : Giveaway_GetRandomPlayerNoAdmin();
	GetClientName(randomNumber, name, MAX_NAME_LENGTH);
	Format(sBuffer, sizeof(sBuffer), "%t", "Giveaway winner in progress", name);
	PrintCenterTextAll(sBuffer);
	Number++;
	return Plugin_Continue;
}

void Giveaway_CountDown(char[] admin)
{
	char sBuffer[254];
	if (g_hGWTimers != INVALID_HANDLE)
	{
		KillTimer(g_hGWTimers);
		g_hGWTimers = INVALID_HANDLE;
	}
	g_hGWTimers = CreateTimer(1.0, Giveaway_Repeater, _, TIMER_REPEAT);
	Format(sBuffer, sizeof(sBuffer), "%t", "Giveaway announcement", admin, g_iGWCredits);
	PrintCenterTextAll(sBuffer);
}

public Action Giveaway_Repeater(Handle timer)
{
	char sBuffer[254];
	g_iGWNumber--;
	if (g_iGWNumber <= 0)
	{
		CreateTimer(0.1, Giveaway_TimerGiveaway, _, TIMER_REPEAT);
		if (g_hGWTimers != INVALID_HANDLE)
		{
			KillTimer(g_hGWTimers);
			g_hGWTimers = INVALID_HANDLE;
		}
		return Plugin_Stop;
	}
	if (0 < g_iGWNumber < 6)
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Giveaway remaining time", g_iGWNumber);
		PrintCenterTextAll(sBuffer);
	}
	return Plugin_Continue;
}

static int Giveaway_GetRandomPlayer()
{
	int[] clients = new int[MaxClients];
	int clientCount = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i))
			clients[clientCount++] = i;
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount - 1)];
}

static int Giveaway_GetRandomPlayerNoAdmin()
{
	int[] clients = new int[MaxClients];
	int clientCount = 0;
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i) && !CheckCommandAccess(i, "sm_giveaway_flag_overwrite", ADMFLAG_GENERIC))
			clients[clientCount++] = i;
	return (clientCount == 0) ? -1 : clients[GetRandomInt(0, clientCount - 1)];
}

#else
void Giveaway_OnPluginStart() {}
void Giveaway_OnConfigExecuted() {}
#endif
