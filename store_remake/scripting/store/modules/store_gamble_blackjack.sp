#if STORE_MODULE_GAMBLE_BLACKJACK
#define SUIT_SPADES "♠"
#define SUIT_DIAMONDS "♦"
#define SUIT_HEARTS "♥"
#define SUIT_CLUBS "♣"

enum GameStatus {
	Status_None = 0,
	Status_BlackJack,
	Status_Win,
	Status_Lose,
	Status_Draw
}

ConVar gc_iMax, gc_iMin, gc_iLose, gc_iWon, gc_bBonus, gc_fBonusRatio, gc_fBonusRatioAmount;

char g_sSuits[4][5];
char g_sCards[13][3];

int iBetValue = 10;
int g_iCardValue[13] = {2,3,4,5,6,7,8,9,10,10,10,10,11};

ArrayList g_hBJPlayerCards[MAXPLAYERS+1];
ArrayList g_hBJDealerCards[MAXPLAYERS+1];
Handle g_hBJDealerThink[MAXPLAYERS+1];
int g_iBJPlayerPot[MAXPLAYERS+1];
int g_iBJBufferPlayerPot[MAXPLAYERS+1];
int g_iBJPlayerLastPot[MAXPLAYERS+1];
int g_iBJPlayerCardValue[MAXPLAYERS+1];
int g_iBJDealerCardValue[MAXPLAYERS+1];
bool g_bBJIsIngame[MAXPLAYERS+1] = {false,...};
bool g_bBJStays[MAXPLAYERS+1] = {false,...};
bool g_bBJDealerEnds[MAXPLAYERS+1] = {false,...};
GameStatus g_iBJGameStatus[MAXPLAYERS+1] = {Status_None,...};
bool g_bBJPlayerIsInMenu[MAXPLAYERS+1] = {false,...};
bool g_bBJMoneyDealt[MAXPLAYERS+1] = {false,...};
bool g_bBJPlayed[MAXPLAYERS+1] = {false,...};

public void Blackjack_OnPluginStart()
{
	gc_iMax = CreateConVar("store_blackjack_max", "2000", "Maximum amount of credits to spend", _, true, 0.0);
	gc_iMin = CreateConVar("store_blackjack_min", "20", "Minimum amount of credits to spend.", _, true, 0.0);
	gc_iLose = CreateConVar("store_blackjack_lose", "500", "Amount of credits player lost to show in public.");
	gc_iWon = CreateConVar("store_blackjack_won", "500", "Amount of credits player won to show in public.");
	gc_bBonus = CreateConVar("store_blackjack_bonus", "1", "Enable bonus credits for betting above ratio of Max Bet.", _, true, 0.0, true, 1.0);
	gc_fBonusRatio = CreateConVar("store_blackjack_bonus_ratio", "0.75", "Minimun pertage of max bet to be able to get bonus credits.");
	gc_fBonusRatioAmount = CreateConVar("store_blackjack_bonus_ratio_amount", "0.5", "Ratio of bonus on betting base on Max Bet of the game.");
	Store_BeginModuleConfig("sourcemod/store", "blackjack");
	STORE_CFG("store_blackjack_max", "2000");
	STORE_CFG("store_blackjack_min", "20");
	STORE_CFG("store_blackjack_lose", "500");
	STORE_CFG("store_blackjack_won", "500");
	STORE_CFG("store_blackjack_bonus", "1");
	STORE_CFG("store_blackjack_bonus_ratio", "0.75");
	STORE_CFG("store_blackjack_bonus_ratio_amount", "0.5");
	Store_EndModuleConfig("sourcemod/store", "blackjack");

	Format(g_sSuits[0], sizeof(g_sSuits[]), SUIT_SPADES);
	Format(g_sSuits[1], sizeof(g_sSuits[]), SUIT_DIAMONDS);
	Format(g_sSuits[2], sizeof(g_sSuits[]), SUIT_HEARTS);
	Format(g_sSuits[3], sizeof(g_sSuits[]), SUIT_CLUBS);
	Format(g_sCards[0], sizeof(g_sCards[]), "2");
	Format(g_sCards[1], sizeof(g_sCards[]), "3");
	Format(g_sCards[2], sizeof(g_sCards[]), "4");
	Format(g_sCards[3], sizeof(g_sCards[]), "5");
	Format(g_sCards[4], sizeof(g_sCards[]), "6");
	Format(g_sCards[5], sizeof(g_sCards[]), "7");
	Format(g_sCards[6], sizeof(g_sCards[]), "8");
	Format(g_sCards[7], sizeof(g_sCards[]), "9");
	Format(g_sCards[8], sizeof(g_sCards[]), "10");
	Format(g_sCards[9], sizeof(g_sCards[]), "J");
	Format(g_sCards[10], sizeof(g_sCards[]), "Q");
	Format(g_sCards[11], sizeof(g_sCards[]), "K");
	Format(g_sCards[12], sizeof(g_sCards[]), "A");

	RegConsoleCmd("sm_bj", Cmd_BlackJack, "Opens the blackjack game.");
	RegConsoleCmd("sm_blackjack", Cmd_BlackJack, "Opens the blackjack game.");
	HookEvent("player_spawn", Event_OnPlayerSpawn);
}

public void Blackjack_OnClientDisconnect(int client)
{
	if (g_hBJPlayerCards[client] != null)
	{
		delete g_hBJPlayerCards[client];
		g_hBJPlayerCards[client] = null;
	}
	if (g_hBJDealerCards[client] != null)
	{
		delete g_hBJDealerCards[client];
		g_hBJDealerCards[client] = null;
	}
	if (g_hBJDealerThink[client] != null)
	{
		delete g_hBJDealerThink[client];
		g_hBJDealerThink[client] = null;
	}
	g_iBJPlayerPot[client] = 0;
	g_iBJBufferPlayerPot[client] = 0;
	g_iBJPlayerLastPot[client] = 0;
	g_iBJPlayerCardValue[client] = 0;
	g_iBJDealerCardValue[client] = 0;
	g_bBJIsIngame[client] = false;
	g_bBJStays[client] = false;
	g_bBJDealerEnds[client] = false;
	g_bBJPlayerIsInMenu[client] = false;
	g_bBJMoneyDealt[client] = false;
	g_iBJGameStatus[client] = Status_None;
	g_bBJPlayed[client] = false;
}

public Action Event_OnPlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (g_bBJPlayerIsInMenu[client])
		CancelClientMenu(client);
	return Plugin_Continue;
}

public Action Cmd_BlackJack(int client, int args)
{
	g_bBJPlayed[client] = true;
	if (args == 0)
	{
		if (g_bBJIsIngame[client])
			ShowGamePanel(client);
		else
			ShowBetPanel(client);
	}
	else if (args == 1)
	{
		char buffer[256];
		GetCmdArg(1, buffer, sizeof(buffer));
		int argument = StringToInt(buffer);
		int iAccount = Store_GetClientCredits(client);

		if (iAccount < argument || (gc_iMax.IntValue != 0 && argument > gc_iMax.IntValue))
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "You can't spend that much credits CM", gc_iMax.IntValue, g_sCreditsName);
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "You can't spend that much credits", gc_iMax.IntValue, g_sCreditsName);
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "You can't spend that much credits", gc_iMax.IntValue, g_sCreditsName);
			#endif
			return Plugin_Handled;
		}
		if (iAccount < argument || argument < gc_iMin.IntValue)
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "You have to spend at least x credits CM", gc_iMin.IntValue, g_sCreditsName);
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "You have to spend at least x credits", gc_iMin.IntValue, g_sCreditsName);
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "You have to spend at least x credits", gc_iMin.IntValue, g_sCreditsName);
			#endif
			return Plugin_Handled;
		}
		if (iAccount < argument)
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Not enough Credits CM");
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
			#endif
			return Plugin_Handled;
		}
		if (g_bBJIsIngame[client])
			ShowGamePanel(client);
		else
		{
			g_iBJBufferPlayerPot[client] = argument;
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Betting Placed CM", g_iBJBufferPlayerPot[client]);
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "Betting Placed", g_iBJBufferPlayerPot[client]);
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "Betting Placed", g_iBJBufferPlayerPot[client]);
			#endif
			ShowBetPanel(client);
		}
	}
	else if (args > 1)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Type in chat !blackjack CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Type in chat !blackjack");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Type in chat !blackjack");
		#endif
	}
	return Plugin_Handled;
}

void ShowBetPanel(int client)
{
	int iAccount = Store_GetClientCredits(client);
	Panel panel = new Panel();
	char betValueBuffer[64], betValueAmount[64], sBuffer[64], sBuffer2[64];

	if (g_iBJBufferPlayerPot[client] > 0 && iAccount >= g_iBJBufferPlayerPot[client])
	{
		iAccount -= g_iBJBufferPlayerPot[client];
		g_iBJPlayerPot[client] = g_iBJBufferPlayerPot[client];
		g_iBJBufferPlayerPot[client] = 0;
		Store_SetClientCredits(client, iAccount);
	}
	else if (g_iBJPlayerPot[client] == 0 && iAccount >= g_iBJPlayerPot[client])
	{
		iAccount -= g_iBJPlayerPot[client];
		Store_SetClientCredits(client, iAccount);
	}

	Format(sBuffer, sizeof(sBuffer), "%t", "blackjack");
	panel.SetTitle(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Credits and Pot", iAccount, g_iBJPlayerPot[client]);
	panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
	panel.DrawItem("", ITEMDRAW_SPACER | ITEMDRAW_RAWLINE);
	Format(betValueBuffer, sizeof(betValueBuffer), "%t", "Deal+-", iBetValue, iBetValue);
	panel.DrawItem(betValueBuffer, ITEMDRAW_RAWLINE);
	Format(sBuffer, sizeof(sBuffer), "%t", "Press");
	if (g_iBJPlayerPot[client] > 0)
		Format(sBuffer, sizeof(sBuffer), "%s:	   1		2		  3", sBuffer);
	else
		Format(sBuffer, sizeof(sBuffer), "%s:				 2		 3", sBuffer);
	panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
	panel.DrawItem("", ITEMDRAW_SPACER | ITEMDRAW_RAWLINE);
	panel.DrawItem("", ITEMDRAW_SPACER | ITEMDRAW_RAWLINE);
	Format(betValueAmount, sizeof(betValueAmount), "%t", "Amount", iBetValue);
	panel.DrawItem(betValueAmount, ITEMDRAW_RAWLINE);
	panel.DrawItem("", ITEMDRAW_SPACER | ITEMDRAW_RAWLINE);
	Format(sBuffer, sizeof(sBuffer), "%t\n", "Edit Amount");
	if (iBetValue == 10)
	{
		Format(sBuffer2, sizeof(sBuffer2), "%t", "Up");
		Format(sBuffer, sizeof(sBuffer), "%s4 %s", sBuffer, sBuffer2);
		panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
		panel.DrawItem("", ITEMDRAW_SPACER | ITEMDRAW_RAWLINE);
	}
	else if (iBetValue == 100)
	{
		Format(sBuffer2, sizeof(sBuffer2), "%t", "Up");
		Format(sBuffer, sizeof(sBuffer), "%s4 %s", sBuffer, sBuffer2);
		panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
		Format(sBuffer, sizeof(sBuffer), "%t", "Down2");
		panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
	}
	else if (iBetValue == 1000)
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Edit Amount");
		panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
		Format(sBuffer, sizeof(sBuffer), "%t", "Down2");
		panel.DrawItem("", ITEMDRAW_SPACER | ITEMDRAW_RAWLINE);
		panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
	}
	panel.DrawItem("", ITEMDRAW_SPACER | ITEMDRAW_RAWLINE);
	panel.CurrentKey = 6;
	Format(sBuffer, sizeof(sBuffer), "%t", "Game Info");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.DrawItem("", ITEMDRAW_SPACER | ITEMDRAW_RAWLINE);
	panel.CurrentKey = 10;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_CONTROL);
	panel.SetKeys(((1<<0)|(1<<1)|(1<<2)|(1<<3)|(1<<4)|(1<<5)|(1<<9)|(1<<10)));
	if (panel.Send(client, Menu_Betting, MENU_TIME_FOREVER))
		g_bBJPlayerIsInMenu[client] = true;
	delete panel;
}

void ShowGamePanel(int client)
{
	int iCountHigh = GetCardCount(client, true);
	int iCountLow = GetCardCount(client, false);
	if (iCountHigh > 21 && iCountLow > 21)
		g_iBJGameStatus[client] = Status_Lose;
	g_iBJPlayerCardValue[client] = iCountHigh <= 21 ? iCountHigh : iCountLow;

	Panel panel = new Panel();
	char sBuffer[64], sBuffer2[64];
	Format(sBuffer, sizeof(sBuffer), "%t", "blackjack");
	panel.SetTitle(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Credits and Pot", Store_GetClientCredits(client), g_iBJPlayerPot[client]);
	panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
	panel.DrawItem("_______________", ITEMDRAW_RAWLINE);

	Format(sBuffer, sizeof(sBuffer), "");
	int iSize = g_hBJDealerCards[client].Length;
	int cards[2];
	for (int i = 0; i < iSize; i++)
	{
		g_hBJDealerCards[client].GetArray(i, cards, 2);
		if (strlen(sBuffer) == 0)
			Format(sBuffer, sizeof(sBuffer), "[%s%s]", g_sCards[cards[1]], g_sSuits[cards[0]]);
		else
			Format(sBuffer, sizeof(sBuffer), "%s [%s%s]", sBuffer, g_sCards[cards[1]], g_sSuits[cards[0]]);
	}
	Format(sBuffer2, sizeof(sBuffer2), "%t", "Dealer");
	if (!g_bBJStays[client])
		Format(sBuffer, sizeof(sBuffer), "%s  %s", sBuffer2, sBuffer);
	else
	{
		Format(sBuffer, sizeof(sBuffer), "%s  %s = ", sBuffer2, sBuffer);
		if (g_bBJDealerEnds[client])
		{
			if (g_iBJGameStatus[client] == Status_Lose && g_hBJDealerCards[client].Length == 2 && g_iBJDealerCardValue[client] == 21)
				Format(sBuffer, sizeof(sBuffer), "%t", "21Blackjack", sBuffer);
			else
				Format(sBuffer, sizeof(sBuffer), "%s%d", sBuffer, g_iBJDealerCardValue[client]);
		}
		else
		{
			int iDealerCards1 = GetCardCount(client, false, true);
			int iDealerCards2 = GetCardCount(client, true, true);
			if (iDealerCards1 == iDealerCards2 || iDealerCards1 > 21 || iDealerCards2 > 21)
				Format(sBuffer, sizeof(sBuffer), "%s%d", sBuffer, g_iBJDealerCardValue[client]);
			else
				Format(sBuffer, sizeof(sBuffer), "%s%d/%d", sBuffer, iDealerCards1, iDealerCards2);
		}
	}
	panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
	panel.DrawItem("", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

	Format(sBuffer, sizeof(sBuffer), "");
	iSize = g_hBJPlayerCards[client].Length;
	for (int i = 0; i < iSize; i++)
	{
		g_hBJPlayerCards[client].GetArray(i, cards, 2);
		if (strlen(sBuffer) == 0)
			Format(sBuffer, sizeof(sBuffer), "[%s%s]", g_sCards[cards[1]], g_sSuits[cards[0]]);
		else
			Format(sBuffer, sizeof(sBuffer), "%s [%s%s]", sBuffer, g_sCards[cards[1]], g_sSuits[cards[0]]);
	}
	Format(sBuffer2, sizeof(sBuffer2), "%t", "You");
	Format(sBuffer, sizeof(sBuffer), "%s  %s = ", sBuffer2, sBuffer);
	if (g_bBJStays[client])
	{
		if (g_iBJGameStatus[client] == Status_BlackJack)
			Format(sBuffer, sizeof(sBuffer), "%t", "21Blackjack", sBuffer);
		else
			Format(sBuffer, sizeof(sBuffer), "%s%d", sBuffer, g_iBJPlayerCardValue[client]);
	}
	else
	{
		if (g_iBJGameStatus[client] != Status_None || iCountHigh == iCountLow || iCountHigh > 21 || iCountLow > 21)
			Format(sBuffer, sizeof(sBuffer), "%s%d", sBuffer, g_iBJPlayerCardValue[client]);
		else
			Format(sBuffer, sizeof(sBuffer), "%s%d/%d", sBuffer, iCountHigh, iCountLow);
	}
	panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
	panel.DrawItem("", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	panel.DrawItem("", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);

	if (g_iBJGameStatus[client] == Status_None && !g_bBJStays[client])
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Hit");
		panel.DrawItem(sBuffer);
		Format(sBuffer, sizeof(sBuffer), "%t", "Stay");
		panel.DrawItem(sBuffer);
		Format(sBuffer, sizeof(sBuffer), "%t", "Double");
		panel.DrawItem(sBuffer);
		panel.DrawItem("", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	}
	else if (g_iBJGameStatus[client] != Status_None)
	{
		switch (g_iBJGameStatus[client])
		{
			case Status_Lose:
			{
				Format(sBuffer, sizeof(sBuffer), "%t", "You lose");
				panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
				g_bBJIsIngame[client] = false;
				if (g_bBJDealerEnds[client] && g_iBJPlayerPot[client] >= gc_iLose.IntValue)
				{
					Format(sBuffer, sizeof(sBuffer), "%t", "blackjack");
					#if defined _clientmod_included
						MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Player lost x Credits CM", client, g_iBJPlayerPot[client], g_sCreditsName, sBuffer);
						C_PrintToChatAll("%s %t", g_sChatPrefix, "Player lost x Credits", client, g_iBJPlayerPot[client], g_sCreditsName, sBuffer);
					#else
						PrintToChatAll("%s %t", g_sChatPrefix, "Player lost x Credits", client, g_iBJPlayerPot[client], g_sCreditsName, sBuffer);
					#endif
				}
				else if (!g_bBJDealerEnds[client] && g_iBJPlayerPot[client] > gc_iLose.IntValue)
				{
					Format(sBuffer, sizeof(sBuffer), "%t", "blackjack");
					#if defined _clientmod_included
						MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Player lost x Credits CM", client, g_iBJPlayerPot[client], g_sCreditsName, sBuffer);
						C_PrintToChatAll("%s %t", g_sChatPrefix, "Player lost x Credits", client, g_iBJPlayerPot[client], g_sCreditsName, sBuffer);
					#else
						PrintToChatAll("%s %t", g_sChatPrefix, "Player lost x Credits", client, g_iBJPlayerPot[client], g_sCreditsName, sBuffer);
					#endif
				}
			}
			case Status_BlackJack:
			{
				Format(sBuffer, sizeof(sBuffer), "%t", "You won");
				panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
				g_bBJIsIngame[client] = false;
				if (!g_bBJMoneyDealt[client])
				{
					if (gc_bBonus.BoolValue && (g_iBJPlayerPot[client] >= RoundToCeil((gc_iMax.IntValue*gc_fBonusRatio.FloatValue))))
						Store_SetClientCredits(client, Store_GetClientCredits(client)+RoundToCeil(g_iBJPlayerPot[client]*2.5+(g_iBJPlayerPot[client]*gc_fBonusRatioAmount.FloatValue)));
					else
						Store_SetClientCredits(client, Store_GetClientCredits(client)+RoundToCeil(g_iBJPlayerPot[client]*2.5));
					if (g_iBJPlayerPot[client] > gc_iWon.IntValue)
					{
						Format(sBuffer, sizeof(sBuffer), "%t", "blackjack");
						if (gc_bBonus.BoolValue && (g_iBJPlayerPot[client] >= RoundToCeil((gc_iMax.IntValue*gc_fBonusRatio.FloatValue))))
						{
							#if defined _clientmod_included
								MC_PrintToChat(client, "%s %t - %t", g_sChatPrefix_CM, "Player won x Credits CM", client, RoundToCeil(g_iBJPlayerPot[client]*2.5), g_sCreditsName, sBuffer, "Bet Bonus CM", RoundToCeil(g_iBJPlayerPot[client]*gc_fBonusRatioAmount.FloatValue));
								C_PrintToChat(client, "%s %t - %t", g_sChatPrefix, "Player won x Credits", client, RoundToCeil(g_iBJPlayerPot[client]*2.5), g_sCreditsName, sBuffer, "Bet Bonus", RoundToCeil(g_iBJPlayerPot[client]*gc_fBonusRatioAmount.FloatValue));
							#else
								PrintToChat(client, "%s %t - %t", g_sChatPrefix, "Player won x Credits", client, RoundToCeil(g_iBJPlayerPot[client]*2.5), g_sCreditsName, sBuffer, "Bet Bonus", RoundToCeil(g_iBJPlayerPot[client]*gc_fBonusRatioAmount.FloatValue));
							#endif
						}
						else
						{
							#if defined _clientmod_included
								MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Player won x Credits CM", client, RoundToCeil(g_iBJPlayerPot[client]*2.5), g_sCreditsName, sBuffer);
								C_PrintToChatAll("%s %t", g_sChatPrefix, "Player won x Credits", client, RoundToCeil(g_iBJPlayerPot[client]*2.5), g_sCreditsName, sBuffer);
							#else
								PrintToChatAll("%s %t", g_sChatPrefix, "Player won x Credits", client, RoundToCeil(g_iBJPlayerPot[client]*2.5), g_sCreditsName, sBuffer);
							#endif
						}
					}
				}
			}
			case Status_Win:
			{
				Format(sBuffer, sizeof(sBuffer), "%t", "You won");
				panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
				g_bBJIsIngame[client] = false;
				if (g_iBJPlayerPot[client] > gc_iWon.IntValue)
				{
					Format(sBuffer, sizeof(sBuffer), "%t", "blackjack");
					if (gc_bBonus.BoolValue && (g_iBJPlayerPot[client] >= RoundToCeil((gc_iMax.IntValue*gc_fBonusRatio.FloatValue))))
					{
						#if defined _clientmod_included
							MC_PrintToChat(client, "%s %t - %t", g_sChatPrefix_CM, "Player won x Credits CM", client, g_iBJPlayerPot[client]*2, g_sCreditsName, sBuffer, "Bet Bonus CM", RoundToCeil(g_iBJPlayerPot[client]*gc_fBonusRatioAmount.FloatValue));
							C_PrintToChat(client, "%s %t - %t", g_sChatPrefix, "Player won x Credits", client, g_iBJPlayerPot[client]*2, g_sCreditsName, sBuffer, "Bet Bonus", RoundToCeil(g_iBJPlayerPot[client]*gc_fBonusRatioAmount.FloatValue));
						#else
							PrintToChat(client, "%s %t - %t", g_sChatPrefix, "Player won x Credits", client, g_iBJPlayerPot[client]*2, g_sCreditsName, sBuffer, "Bet Bonus", RoundToCeil(g_iBJPlayerPot[client]*gc_fBonusRatioAmount.FloatValue));
						#endif
					}
					else
					{
						#if defined _clientmod_included
							MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Player won x Credits CM", client, g_iBJPlayerPot[client]*2, g_sCreditsName, sBuffer);
							C_PrintToChatAll("%s %t", g_sChatPrefix, "Player won x Credits", client, g_iBJPlayerPot[client]*2, g_sCreditsName, sBuffer);
						#else
							PrintToChatAll("%s %t", g_sChatPrefix, "Player won x Credits", client, g_iBJPlayerPot[client]*2, g_sCreditsName, sBuffer);
						#endif
					}
				}
				if (!g_bBJMoneyDealt[client])
				{
					if (gc_bBonus.BoolValue && (g_iBJPlayerPot[client] >= RoundToCeil((gc_iMax.IntValue*gc_fBonusRatio.FloatValue))))
						Store_SetClientCredits(client, Store_GetClientCredits(client)+RoundToCeil(g_iBJPlayerPot[client]*2+(g_iBJPlayerPot[client]*gc_fBonusRatioAmount.FloatValue)));
					else
						Store_SetClientCredits(client, Store_GetClientCredits(client)+g_iBJPlayerPot[client]*2);
				}
			}
			case Status_Draw:
			{
				Format(sBuffer, sizeof(sBuffer), "%t", "Dead heat");
				panel.DrawItem(sBuffer, ITEMDRAW_RAWLINE);
				g_bBJIsIngame[client] = false;
				if (!g_bBJMoneyDealt[client])
					Store_SetClientCredits(client, Store_GetClientCredits(client)+g_iBJPlayerPot[client]);
			}
		}
		panel.DrawItem("", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
		panel.CurrentKey = 4;
		Format(sBuffer, sizeof(sBuffer), "%t", "Try again");
		panel.DrawItem(sBuffer);
		g_bBJMoneyDealt[client] = true;
	}
	else
	{
		panel.DrawItem("", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
		panel.DrawItem("", ITEMDRAW_SPACER|ITEMDRAW_RAWLINE);
	}
	panel.CurrentKey = 10;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer);
	if (panel.Send(client, Menu_GameHandler, MENU_TIME_FOREVER))
		g_bBJPlayerIsInMenu[client] = true;
	delete panel;
}

public int Menu_Betting(Menu menu, MenuAction action, int param1, int param2)
{
	g_bBJPlayerIsInMenu[param1] = false;
	if (action == MenuAction_Select)
	{
		if (param2 == 1)
		{
			if (g_iBJPlayerPot[param1] == 0)
			{
				ShowBetPanel(param1);
				return 0;
			}
			if (g_hBJPlayerCards[param1] == null)
				g_hBJPlayerCards[param1] = new ArrayList(2);
			else
				g_hBJPlayerCards[param1].Clear();
			if (g_hBJDealerCards[param1] == null)
				g_hBJDealerCards[param1] = new ArrayList(2);
			else
				g_hBJDealerCards[param1].Clear();
			if (g_hBJDealerThink[param1] != null)
			{
				delete g_hBJDealerThink[param1];
				g_hBJDealerThink[param1] = null;
			}
			g_bBJIsIngame[param1] = true;
			g_bBJDealerEnds[param1] = false;
			g_iBJGameStatus[param1] = Status_None;
			g_bBJStays[param1] = false;
			g_bBJMoneyDealt[param1] = false;
			g_iBJPlayerCardValue[param1] = 0;
			g_iBJDealerCardValue[param1] = 0;
			PullPlayerCard(param1);
			PullPlayerCard(param1);
			PullDealerCard(param1);
			ShowGamePanel(param1);
		}
		else if (param2 == 2)
		{
			int iAccount = Store_GetClientCredits(param1);
			if (iAccount >= iBetValue && (gc_iMax.IntValue == 0 || (g_iBJPlayerPot[param1]+iBetValue) <= gc_iMax.IntValue))
			{
				g_iBJPlayerPot[param1] += iBetValue;
				Store_SetClientCredits(param1, iAccount-iBetValue);
			}
			ShowBetPanel(param1);
		}
		else if (param2 == 3)
		{
			if ((g_iBJPlayerPot[param1]-iBetValue) >= 0)
			{
				int iAccount = Store_GetClientCredits(param1);
				g_iBJPlayerPot[param1] -= iBetValue;
				Store_SetClientCredits(param1, iAccount+iBetValue);
			}
			ShowBetPanel(param1);
		}
		else if (param2 == 4)
		{
			if (iBetValue == 10) iBetValue = 100;
			else if (iBetValue == 100) iBetValue = 1000;
			ShowBetPanel(param1);
		}
		else if (param2 == 5)
		{
			if (iBetValue == 100) iBetValue = 10;
			else if (iBetValue == 1000) iBetValue = 100;
			ShowBetPanel(param1);
		}
		else if (param2 == 6)
			Panel_GameInfo(param1);
		else if (param2 == 10)
		{
			int iAccount = Store_GetClientCredits(param1);
			Store_SetClientCredits(param1, iAccount + g_iBJPlayerPot[param1]);
			g_iBJPlayerPot[param1] = 0;
			g_iBJBufferPlayerPot[param1] = 0;
			g_iBJPlayerLastPot[param1] = 0;
			g_iBJPlayerCardValue[param1] = 0;
			g_iBJDealerCardValue[param1] = 0;
			g_bBJIsIngame[param1] = false;
			g_bBJStays[param1] = false;
			g_bBJDealerEnds[param1] = false;
			g_bBJPlayerIsInMenu[param1] = false;
			g_bBJMoneyDealt[param1] = false;
			g_iBJGameStatus[param1] = Status_None;
			g_bBJPlayed[param1] = false;
		}
	}
	else if (action == MenuAction_End)
		delete menu;
	return 0;
}

public int Menu_GameHandler(Menu menu, MenuAction action, int param1, int param2)
{
	g_bBJPlayerIsInMenu[param1] = false;
	if (action == MenuAction_Select)
	{
		if (param2 == 4 && g_iBJGameStatus[param1] != Status_None)
		{
			g_iBJPlayerPot[param1] = 0;
			g_iBJGameStatus[param1] = Status_None;
			g_bBJIsIngame[param1] = false;
			ShowBetPanel(param1);
		}
		else if (param2 == 1 && g_iBJGameStatus[param1] != Status_Lose)
		{
			PullPlayerCard(param1);
			ShowGamePanel(param1);
		}
		else if (param2 == 2 && g_iBJGameStatus[param1] != Status_Lose)
		{
			g_bBJStays[param1] = true;
			g_hBJDealerThink[param1] = CreateTimer(0.7, Timer_DealerThink, GetClientUserId(param1), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
			TriggerTimer(g_hBJDealerThink[param1]);
		}
		else if (param2 == 3 && g_iBJGameStatus[param1] != Status_Lose)
		{
			int iAccount = Store_GetClientCredits(param1);
			int iLimit = gc_iMax.IntValue;
			if (iAccount >= g_iBJPlayerPot[param1] && (iLimit == 0 || (g_iBJPlayerPot[param1]*2) <= iLimit))
			{
				Store_SetClientCredits(param1, iAccount-g_iBJPlayerPot[param1]);
				g_iBJPlayerPot[param1] *= 2;
				g_iBJGameStatus[param1] = Status_None;
				PullPlayerCard(param1);
				g_bBJStays[param1] = true;
				ShowGamePanel(param1);
				if (g_iBJGameStatus[param1] == Status_None)
				{
					g_hBJDealerThink[param1] = CreateTimer(0.7, Timer_DealerThink, GetClientUserId(param1), TIMER_REPEAT|TIMER_FLAG_NO_MAPCHANGE);
					g_bBJDealerEnds[param1] = false;
				}
				return 0;
			}
			ShowGamePanel(param1);
		}
		else if (param2 == 10)
		{
			if (g_iBJGameStatus[param1] != Status_None)
			{
				g_iBJPlayerPot[param1] = 0;
				g_iBJBufferPlayerPot[param1] = 0;
				g_iBJPlayerLastPot[param1] = 0;
				g_iBJPlayerCardValue[param1] = 0;
				g_iBJDealerCardValue[param1] = 0;
				g_bBJIsIngame[param1] = false;
				g_bBJStays[param1] = false;
				g_bBJPlayerIsInMenu[param1] = false;
				g_iBJGameStatus[param1] = Status_None;
				g_bBJPlayed[param1] = false;
				#if defined _clientmod_included
					MC_PrintToChat(param1, "%s %t", g_sChatPrefix_CM, "Type in chat !blackjack CM");
					C_PrintToChat(param1, "%s %t", g_sChatPrefix, "Type in chat !blackjack");
				#else
					PrintToChat(param1, "%s %t", g_sChatPrefix, "Type in chat !blackjack");
				#endif
			}
			else
			{
				#if defined _clientmod_included
					MC_PrintToChat(param1, "%s %t", g_sChatPrefix_CM, "Type in chat !blackjack CM");
					C_PrintToChat(param1, "%s %t", g_sChatPrefix, "Type in chat !blackjack");
				#else
					PrintToChat(param1, "%s %t", g_sChatPrefix, "Type in chat !blackjack");
				#endif
			}
		}
	}
	else if (action == MenuAction_End)
		delete menu;
	return 0;
}

void Panel_GameInfo(int client)
{
	char sBuffer[1024];
	Panel panel = new Panel();
	Format(sBuffer, sizeof(sBuffer), "%t", "blackjack");
	panel.SetTitle(sBuffer);
	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "%t", "Blackjack Info 1");
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "%t", "Blackjack Info 2");
	panel.DrawText(sBuffer);
	Format(sBuffer, sizeof(sBuffer), "%t", "Blackjack Info 3");
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	Format(sBuffer, sizeof(sBuffer), "%t", "Blackjack Info 4");
	panel.DrawText(sBuffer);
	panel.DrawItem("", ITEMDRAW_SPACER | ITEMDRAW_RAWLINE);
	panel.CurrentKey = 8;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.CurrentKey = 10;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.Send(client, Handler_WheelRun, 30);
	delete panel;
}

public int Handler_WheelRun(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		if (itemNum == 8)
		{
			ClientCommand(client, "sm_bj");
			EmitSoundToClient(client, g_sMenuItem);
		}
		else if (itemNum == 10)
			EmitSoundToClient(client, g_sMenuExit);
	}
	else if (action == MenuAction_End)
		delete panel;
	return 0;
}

public Action Timer_DealerThink(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client)
		return Plugin_Stop;
	PullDealerCard(client);
	int iCountHigh = GetCardCount(client, true, true);
	int iCountLow = GetCardCount(client, false, true);

	if (g_hBJDealerCards[client].Length == 2 && iCountHigh == 21)
	{
		g_iBJDealerCardValue[client] = 21;
		g_bBJDealerEnds[client] = true;
		if (g_hBJPlayerCards[client].Length == 2 && g_iBJPlayerCardValue[client] == 21)
			g_iBJGameStatus[client] = Status_Draw;
		else
			g_iBJGameStatus[client] = Status_Lose;
	}
	else if (iCountHigh > 21 && iCountLow > 21)
	{
		g_iBJDealerCardValue[client] = iCountHigh;
		g_bBJDealerEnds[client] = true;
		if (g_hBJPlayerCards[client].Length == 2 && g_iBJPlayerCardValue[client] == 21)
			g_iBJGameStatus[client] = Status_BlackJack;
		else
			g_iBJGameStatus[client] = Status_Win;
	}
	else if (iCountHigh == 21 || iCountLow == 21)
	{
		g_iBJDealerCardValue[client] = 21;
		g_bBJDealerEnds[client] = true;
		if (g_hBJPlayerCards[client].Length == 2 && g_iBJPlayerCardValue[client] == 21)
			g_iBJGameStatus[client] = Status_BlackJack;
		else if (g_iBJPlayerCardValue[client] == 21)
			g_iBJGameStatus[client] = Status_Draw;
		else
			g_iBJGameStatus[client] = Status_Lose;
	}
	else
		g_iBJDealerCardValue[client] = iCountHigh <= 21 ? iCountHigh : iCountLow;

	if (g_iBJDealerCardValue[client] >= 17 && !g_bBJDealerEnds[client])
	{
		g_bBJDealerEnds[client] = true;
		if (g_iBJDealerCardValue[client] < g_iBJPlayerCardValue[client])
		{
			if (g_hBJPlayerCards[client].Length == 2 && g_iBJPlayerCardValue[client] == 21)
				g_iBJGameStatus[client] = Status_BlackJack;
			else
				g_iBJGameStatus[client] = Status_Win;
		}
		else if (g_iBJDealerCardValue[client] == g_iBJPlayerCardValue[client])
			g_iBJGameStatus[client] = Status_Draw;
		else
			g_iBJGameStatus[client] = Status_Lose;
	}
	ShowGamePanel(client);
	if (g_bBJDealerEnds[client])
	{
		g_hBJDealerThink[client] = null;
		return Plugin_Stop;
	}
	return Plugin_Continue;
}

void PullPlayerCard(int client)
{
	int newCard[2];
	newCard[0] = GetURandomIntRange(0, 3);
	newCard[1] = GetURandomIntRange(0, 12);
	g_hBJPlayerCards[client].PushArray(newCard, 2);
}

void PullDealerCard(int client)
{
	int newCard[2];
	newCard[0] = GetURandomIntRange(0, 3);
	newCard[1] = GetURandomIntRange(0, 12);
	g_hBJDealerCards[client].PushArray(newCard, 2);
}

int GetCardCount(int client, bool highace = true, bool dealer = false)
{
	int iSize = dealer ? g_hBJDealerCards[client].Length : g_hBJPlayerCards[client].Length;
	if (iSize == 0)
		return 0;
	int iCount, cards[2];
	bool multipleAces = false;
	for (int i = 0; i < iSize; i++)
	{
		if (!dealer)
			g_hBJPlayerCards[client].GetArray(i, cards, 2);
		else
			g_hBJDealerCards[client].GetArray(i, cards, 2);
		if (cards[1] == 12 && (!highace || multipleAces))
			iCount += 1;
		else
		{
			iCount += g_iCardValue[cards[1]];
			if (cards[1] == 12)
				multipleAces = true;
		}
	}
	return iCount;
}

int GetURandomIntRange(int min, int max)
{
	return (GetURandomInt() % (max-min+1)) + min;
}

#else

void Blackjack_OnPluginStart() {}
void Blackjack_OnClientDisconnect(int client)
{
	#pragma unused client
}

#endif