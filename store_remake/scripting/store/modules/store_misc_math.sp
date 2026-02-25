#if STORE_MODULE_MISC_MATH

bool g_bMathInQuizz;
int g_iMathNbrMin, g_iMathNbrMax, g_iMathMaxCredits, g_iMathMinCredits, g_iMathQuestionResult, g_iMathCredits, g_iMathMinPlayers, g_iMathOpType;

Handle g_hMathQuestionEnd = INVALID_HANDLE;
Handle g_hMathQuestionTimer = INVALID_HANDLE;

ConVar gc_MathMinNumber, gc_MathMaxNumber, gc_MathMaxCredits, gc_MathMinCredits, gc_MathTimeBetween, gc_MathTimeAnswer, gc_MathMinPlayers;

void Math_OnPluginStart()
{
	RegAdminCmd("sm_math", Math_Command_StartQuestion, ADMFLAG_ROOT);
	AddCommandListener(Math_Command_Say, "say");
	AddCommandListener(Math_Command_Say, "say_team");
	g_bMathInQuizz = false;
	gc_MathMinNumber = CreateConVar("store_math_minimum_number", "1", "Minimum number for questions");
	gc_MathMaxNumber = CreateConVar("store_math_maximum_number", "100", "Maximum number for questions");
	gc_MathMinCredits = CreateConVar("store_math_minimum_credits", "10", "Minimum credits for correct answer");
	gc_MathMaxCredits = CreateConVar("store_math_maximum_credits", "50", "Maximum credits for correct answer");
	gc_MathTimeBetween = CreateConVar("store_math_time_between_questions", "120", "Seconds between questions");
	gc_MathTimeAnswer = CreateConVar("store_math_time_answer_questions", "20", "Seconds to answer");
	gc_MathMinPlayers = CreateConVar("store_math_min_players", "0", "Minimum players for math (0 = no minimum, always run)");
	Store_BeginModuleConfig("sourcemod/store", "math");
	STORE_CFG("store_math_minimum_number", "1");
	STORE_CFG("store_math_maximum_number", "100");
	STORE_CFG("store_math_minimum_credits", "10");
	STORE_CFG("store_math_maximum_credits", "50");
	STORE_CFG("store_math_time_between_questions", "120");
	STORE_CFG("store_math_time_answer_questions", "20");
	STORE_CFG("store_math_min_players", "0");
	Store_EndModuleConfig("sourcemod/store", "math");
}

void Math_OnConfigExecuted()
{
	g_iMathNbrMin = gc_MathMinNumber.IntValue;
	g_iMathNbrMax = gc_MathMaxNumber.IntValue;
	g_iMathMaxCredits = gc_MathMaxCredits.IntValue;
	g_iMathMinCredits = gc_MathMinCredits.IntValue;
	g_iMathMinPlayers = gc_MathMinPlayers.IntValue;
	// Avoid 0*0 and 0 credits: ensure at least 1
	if (g_iMathNbrMin < 1) g_iMathNbrMin = 1;
	if (g_iMathMinCredits < 1) g_iMathMinCredits = 1;
	if (g_hMathQuestionTimer == INVALID_HANDLE)
		Math_RestartQuestionTimer();
}

void Math_OnMapStart()
{
	// Don't KillTimer here: on map change the handle may already be invalid (stale from previous map).
	g_hMathQuestionTimer = INVALID_HANDLE;
	Math_RestartQuestionTimer();
}

void Math_RestartQuestionTimer()
{
	if (g_hMathQuestionTimer != INVALID_HANDLE)
	{
		KillTimer(g_hMathQuestionTimer);
		g_hMathQuestionTimer = INVALID_HANDLE;
	}
	if (gc_MathTimeBetween == null || gc_MathTimeAnswer == null)
		return;
	float interval = gc_MathTimeBetween.FloatValue + gc_MathTimeAnswer.FloatValue;
	if (interval < 5.0) interval = 5.0;
	g_hMathQuestionTimer = CreateTimer(interval, Math_CreateQuestion, 0, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Math_Command_StartQuestion(int client, int args)
{
	CreateTimer(0.5, Math_CreateQuestion, client);
	return Plugin_Handled;
}

int Math_PlayerCountFast()
{
	return GetClientCount(true);
}

public Action Math_CreateQuestion(Handle timer, any data)
{
	if (g_bMathInQuizz)
		return Plugin_Continue;
	// When admin runs !math, data = client index: allow question even if fewer than min players
	bool forceByAdmin = (data > 0 && data <= MaxClients && IsClientInGame(data));
	if (!forceByAdmin && g_iMathMinPlayers > 0 && Math_PlayerCountFast() < g_iMathMinPlayers)
		return Plugin_Continue;

	int nbr1 = GetRandomInt(g_iMathNbrMin, g_iMathNbrMax);
	int nbr2 = GetRandomInt(g_iMathNbrMin, g_iMathNbrMax);
	g_iMathCredits = GetRandomInt(g_iMathMinCredits, g_iMathMaxCredits);
	g_iMathOpType = GetRandomInt(0, 3);

	switch (g_iMathOpType)
	{
		case 0: g_iMathQuestionResult = nbr1 + nbr2;
		case 1:
		{
			if (nbr1 < nbr2) { nbr1 ^= nbr2; nbr2 ^= nbr1; nbr1 ^= nbr2; }
			g_iMathQuestionResult = nbr1 - nbr2;
		}
		case 2:
		{
			int tries = 0;
			do {
				nbr1 = GetRandomInt(g_iMathNbrMin, g_iMathNbrMax);
				nbr2 = GetRandomInt(g_iMathNbrMin, g_iMathNbrMax);
				if (++tries >= 100) {
					g_iMathOpType = 0;
					nbr1 = GetRandomInt(g_iMathNbrMin, g_iMathNbrMax);
					nbr2 = GetRandomInt(g_iMathNbrMin, g_iMathNbrMax);
					g_iMathQuestionResult = nbr1 + nbr2;
					break;
				}
			} while (nbr2 == 0 || nbr1 % nbr2 != 0);
			if (g_iMathOpType == 2)
				g_iMathQuestionResult = nbr1 / nbr2;
		}
		case 3: g_iMathQuestionResult = nbr1 * nbr2;
	}

	char opChar = (g_iMathOpType == 0) ? '+' : (g_iMathOpType == 1) ? '-' : (g_iMathOpType == 2) ? '/' : '*';
	#if defined _clientmod_included
		MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "QuizzGenerated CM", nbr1, opChar, nbr2, g_iMathCredits, g_sCreditsName);
		C_PrintToChatAll("%s %t", g_sChatPrefix, "QuizzGenerated", nbr1, opChar, nbr2, g_iMathCredits, g_sCreditsName);
	#else
		PrintToChatAll("%s %t", g_sChatPrefix, "QuizzGenerated", nbr1, opChar, nbr2, g_iMathCredits, g_sCreditsName);
	#endif

	g_bMathInQuizz = true;
	g_hMathQuestionEnd = CreateTimer(gc_MathTimeAnswer.FloatValue, Math_EndQuestion, -1);
	return Plugin_Continue;
}

public Action Math_EndQuestion(Handle timer, any data)
{
	g_hMathQuestionEnd = INVALID_HANDLE;
	Math_SendEndQuestion(-1);
	g_bMathInQuizz = false;
	return Plugin_Stop;
}

public Action Math_Command_Say(int client, const char[] command, int args)
{
	if (!g_bMathInQuizz)
		return Plugin_Continue;
	char sRaw[64];
	GetCmdArgString(sRaw, sizeof(sRaw));
	TrimString(sRaw);
	StripQuotes(sRaw);
	char sNum[16];
	int j = 0;
	for (int i = 0; i < 64 && sRaw[i] != '\0' && j < 15; i++)
	{
		if (sRaw[i] == ' ' || sRaw[i] == '\t')
			break;
		sNum[j++] = sRaw[i];
	}
	sNum[j] = '\0';
	int len = strlen(sNum);
	if (len == 0 || len > 10)
		return Plugin_Continue;
	for (int i = 0; i < len; i++)
		if (!IsCharNumeric(sNum[i]) && (i > 0 || sNum[i] != '-'))
			return Plugin_Continue;
	int num = StringToInt(sNum);
	if (num == g_iMathQuestionResult)
		Math_SendEndQuestion(client);
	return Plugin_Continue;
}

void Math_SendEndQuestion(int client)
{
	if (g_hMathQuestionEnd != INVALID_HANDLE)
	{
		KillTimer(g_hMathQuestionEnd);
		g_hMathQuestionEnd = INVALID_HANDLE;
	}
	if (client != -1)
	{
		Store_SetClientCredits(client, Store_GetClientCredits(client) + g_iMathCredits);
		char name[64];
		GetClientName(client, name, sizeof(name));
		#if defined _clientmod_included
			MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "CorrectAnswer CM", name, g_iMathCredits, g_sCreditsName);
			C_PrintToChatAll("%s %t", g_sChatPrefix, "CorrectAnswer", name, g_iMathCredits, g_sCreditsName);
		#else
			PrintToChatAll("%s %t", g_sChatPrefix, "CorrectAnswer", name, g_iMathCredits, g_sCreditsName);
		#endif
		Store_SQLLogMessage(client, LOG_EVENT, "%s won %i credits on Math", name, g_iMathCredits);
	}
	else
	{
		#if defined _clientmod_included
			MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "NoAnswer CM", g_iMathQuestionResult);
			C_PrintToChatAll("%s %t", g_sChatPrefix, "NoAnswer", g_iMathQuestionResult);
		#else
			PrintToChatAll("%s %t", g_sChatPrefix, "NoAnswer", g_iMathQuestionResult);
		#endif
	}
	g_bMathInQuizz = false;
}

#else
void Math_OnPluginStart() {}
void Math_OnConfigExecuted()
{
}
void Math_OnMapStart() {}
#endif
