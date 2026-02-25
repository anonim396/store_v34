#if STORE_MODULE_GAMBLE_HIGHORLOW

int g_iHOLRand1, g_iHOLRand2;
float g_fHOLCooldownEnd[MAXPLAYERS + 1];
int g_iHOLManualAmount[MAXPLAYERS + 1];

ConVar gc_HOLMinAmount, gc_HOLMaxAmount, gc_HOLMinNumber, gc_HOLMaxNumber, gc_HOLLose, gc_HOLWon, gc_HOLCooldownTime;

void HighOrLow_OnPluginStart()
{
	RegConsoleCmd("sm_hol", HOL_Command_HighOrLow);
	RegConsoleCmd("sm_highorlow", HOL_Command_HighOrLow);
	gc_HOLMinAmount = CreateConVar("store_hol_min_amount", "50", "Minimum credits to play High or Low", _, true, 1.0);
	gc_HOLMaxAmount = CreateConVar("store_hol_max_amount", "500", "Maximum credits to play", _, true, 1.0);
	gc_HOLMinNumber = CreateConVar("store_hol_min_number", "1", "Minimum generated number", _, true, 1.0);
	gc_HOLMaxNumber = CreateConVar("store_hol_max_number", "100", "Maximum generated number", _, true, 2.0);
	gc_HOLLose = CreateConVar("store_hol_lose", "250", "Credits lost to show in public", _, true, 1.0);
	gc_HOLWon = CreateConVar("store_hol_won", "400", "Credits won to show in public", _, true, 1.0);
	gc_HOLCooldownTime = CreateConVar("store_hol_cooldown_time", "30.0", "Cooldown for command. 0 = disable", _, true, 0.0);
	Store_BeginModuleConfig("sourcemod/store", "highorlow");
	STORE_CFG("store_hol_min_amount", "50");
	STORE_CFG("store_hol_max_amount", "500");
	STORE_CFG("store_hol_min_number", "1");
	STORE_CFG("store_hol_max_number", "100");
	STORE_CFG("store_hol_lose", "250");
	STORE_CFG("store_hol_won", "400");
	STORE_CFG("store_hol_cooldown_time", "30.0");
	Store_EndModuleConfig("sourcemod/store", "highorlow");
}

void HighOrLow_OnClientPostAdminCheck(int client)
{
	g_iHOLManualAmount[client] = gc_HOLMinAmount.IntValue;
	g_fHOLCooldownEnd[client] = 0.0;
}

public Action HOL_Command_HighOrLow(int client, int args)
{
	if (!client || !IsClientInGame(client) || IsFakeClient(client))
		return Plugin_Handled;
	float cooldown = gc_HOLCooldownTime.FloatValue;
	if (cooldown > 0.0)
	{
		float currentTime = GetGameTime();
		if (g_fHOLCooldownEnd[client] > currentTime)
		{
			int timeleft = RoundToCeil(g_fHOLCooldownEnd[client] - currentTime);
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Seconds to use command CM", timeleft);
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "Seconds to use command", timeleft);
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "Seconds to use command", timeleft);
			#endif
			return Plugin_Handled;
		}
	}
	HOL_ShowMainMenu(client);
	return Plugin_Handled;
}

void HOL_ShowMainMenu(int client)
{
	int iCredits = Store_GetClientCredits(client);
	int minBet = gc_HOLMinAmount.IntValue;
	int maxBet = gc_HOLMaxAmount.IntValue;
	if (iCredits < minBet)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Not enough Credits CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
		#endif
		return;
	}
	char sBuffer[128];
	Menu HolMenu = new Menu(HOL_MenuHandler_Main);
	Format(sBuffer, sizeof(sBuffer), "%t", "high or low");
	HolMenu.SetTitle(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Minium", minBet);
	HolMenu.AddItem("min", sBuffer, iCredits < minBet ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	int actualMax = iCredits > maxBet ? maxBet : iCredits;
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Maximum", actualMax);
	HolMenu.AddItem("max", sBuffer, actualMax < minBet ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	Format(sBuffer, sizeof(sBuffer), "%t", "Bet Random", minBet, actualMax);
	HolMenu.AddItem("random", sBuffer, actualMax < minBet ? ITEMDRAW_DISABLED : ITEMDRAW_DEFAULT);
	Format(sBuffer, sizeof(sBuffer), "%t", "Game Info");
	HolMenu.AddItem("info", sBuffer);
	HolMenu.ExitButton = true;
	HolMenu.Display(client, MENU_TIME_FOREVER);
}

public int HOL_MenuHandler_Main(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(itemNum, info, sizeof(info));
		int iCredits = Store_GetClientCredits(client);
		int minBet = gc_HOLMinAmount.IntValue;
		int maxBet = gc_HOLMaxAmount.IntValue;
		int actualMax = iCredits > maxBet ? maxBet : iCredits;
		if (StrEqual(info, "min"))
		{
			g_iHOLManualAmount[client] = minBet;
			HOL_StartGame(client);
		}
		else if (StrEqual(info, "max"))
		{
			g_iHOLManualAmount[client] = actualMax;
			HOL_StartGame(client);
		}
		else if (StrEqual(info, "random"))
		{
			if (actualMax >= minBet)
			{
				g_iHOLManualAmount[client] = GetRandomInt(minBet, actualMax);
				HOL_StartGame(client);
			}
			else
			{
				#if defined _clientmod_included
					MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Not enough Credits CM");
					C_PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
				#else
					PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
				#endif
			}
		}
		else if (StrEqual(info, "info"))
			HOL_Panel_GameInfo(client);
	}
	else if (action == MenuAction_End)
		delete menu;
	return 0;
}

void HOL_StartGame(int client)
{
	int betAmount = g_iHOLManualAmount[client];
	int credits = Store_GetClientCredits(client);
	if (betAmount < gc_HOLMinAmount.IntValue)
	{
		betAmount = gc_HOLMinAmount.IntValue;
		g_iHOLManualAmount[client] = betAmount;
	}
	if (betAmount > gc_HOLMaxAmount.IntValue)
	{
		betAmount = gc_HOLMaxAmount.IntValue;
		g_iHOLManualAmount[client] = betAmount;
	}
	if (credits < betAmount)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Not enough Credits CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
		#endif
		return;
	}
	float cooldown = gc_HOLCooldownTime.FloatValue;
	if (cooldown > 0.0)
		g_fHOLCooldownEnd[client] = GetGameTime() + cooldown;
	int minNumber = gc_HOLMinNumber.IntValue;
	int maxNumber = gc_HOLMaxNumber.IntValue;
	g_iHOLRand1 = GetRandomInt(minNumber, maxNumber);
	g_iHOLRand2 = GetRandomInt(minNumber, maxNumber);
	while (g_iHOLRand1 == g_iHOLRand2)
		g_iHOLRand2 = GetRandomInt(minNumber, maxNumber);
	Store_SetClientCredits(client, credits - betAmount);
	char sBuffer[256];
	Format(sBuffer, sizeof(sBuffer), "%t", "Hint chosen number", g_iHOLRand1);
	PrintCenterText(client, sBuffer);
	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "The chosen number CM", g_iHOLRand1);
		C_PrintToChat(client, "%s %t", g_sChatPrefix, "The chosen number", g_iHOLRand1);
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix, "The chosen number", g_iHOLRand1);
	#endif
	HOL_ShowChoiceMenu(client, betAmount);
}

void HOL_ShowChoiceMenu(int client, int betAmount)
{
	char sBuffer[256], sBuffer2[256];
	Menu HolMenu1 = new Menu(HOL_MenuHandler_Choice);
	Format(sBuffer, sizeof(sBuffer), "%t", "high or low");
	Format(sBuffer2, sizeof(sBuffer2), "%t", "Credits and Pot", Store_GetClientCredits(client), betAmount);
	Format(sBuffer, sizeof(sBuffer), "%s\n%s", sBuffer, sBuffer2);
	HolMenu1.SetTitle(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Higher");
	HolMenu1.AddItem("higher", sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Lower");
	HolMenu1.AddItem("lower", sBuffer);
	HolMenu1.ExitButton = false;
	HolMenu1.Display(client, MENU_TIME_FOREVER);
}

public int HOL_MenuHandler_Choice(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(itemNum, info, sizeof(info));
		int betAmount = g_iHOLManualAmount[client];
		bool won = false;
		char sBuffer[256];
		if (StrEqual(info, "higher"))
			won = (g_iHOLRand2 > g_iHOLRand1);
		else if (StrEqual(info, "lower"))
			won = (g_iHOLRand2 < g_iHOLRand1);
		if (won)
		{
			int winAmount = betAmount * 2;
			Store_SetClientCredits(client, Store_GetClientCredits(client) + winAmount);
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "You win x Credits CM", winAmount, g_sCreditsName);
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "You win x Credits", winAmount, g_sCreditsName);
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "You win x Credits", winAmount, g_sCreditsName);
			#endif
			if (winAmount >= gc_HOLWon.IntValue)
			{
				Format(sBuffer, sizeof(sBuffer), "%t", "high or low");
				#if defined _clientmod_included
					MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Player won x Credits CM", client, winAmount, g_sCreditsName, sBuffer);
					C_PrintToChatAll("%s %t", g_sChatPrefix, "Player won x Credits", client, winAmount, g_sCreditsName, sBuffer);
				#else
					PrintToChatAll("%s %t", g_sChatPrefix, "Player won x Credits", client, winAmount, g_sCreditsName, sBuffer);
				#endif
			}
		}
		else
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Lost next number CM", g_iHOLRand2);
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "Lost next number", g_iHOLRand2);
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "Lost next number", g_iHOLRand2);
			#endif
			if (betAmount >= gc_HOLLose.IntValue)
			{
				Format(sBuffer, sizeof(sBuffer), "%t", "high or low");
				#if defined _clientmod_included
					MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Player lost x Credits CM", client, betAmount, g_sCreditsName, sBuffer);
					C_PrintToChatAll("%s %t", g_sChatPrefix, "Player lost x Credits", client, betAmount, g_sCreditsName, sBuffer);
				#else
					PrintToChatAll("%s %t", g_sChatPrefix, "Player lost x Credits", client, betAmount, g_sCreditsName, sBuffer);
				#endif
			}
		}
		Format(sBuffer, sizeof(sBuffer), "%t", "Hint next number", g_iHOLRand2);
		PrintCenterText(client, sBuffer);
	}
	else if (action == MenuAction_End)
		delete menu;
	return 0;
}

void HOL_Panel_GameInfo(int client)
{
	char sBuffer[1024];
	Panel panel = new Panel();
	Format(sBuffer, sizeof(sBuffer), "%t", "high or low");
	panel.SetTitle(sBuffer);
	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "%t", "Hol Info 1", gc_HOLMinNumber.IntValue, gc_HOLMaxNumber.IntValue);
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "%t", "Hol Info 2");
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	float cooldown = gc_HOLCooldownTime.FloatValue;
	if (cooldown > 0.0)
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Hol Info 3", cooldown);
		panel.DrawText(sBuffer);
		panel.DrawText(" ");
	}
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.DrawText(" ");
	panel.CurrentKey = 10;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.Send(client, HOL_Handler_WheelRun, 30);
	delete panel;
}

public int HOL_Handler_WheelRun(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch (itemNum)
		{
			case 8:
			{
				ClientCommand(client, "sm_hol");
				EmitSoundToClient(client, g_sMenuItem);
			}
			case 10:
			{
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}
	delete panel;
	return 0;
}

#else
void HighOrLow_OnPluginStart() {}
void HighOrLow_OnClientPostAdminCheck(int client)
{
	#pragma unused client
}
#endif
