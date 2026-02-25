#if STORE_MODULE_GAMBLE_CRASH

#define INPUT_AUTO 1

ConVar gc_CrashStart, gc_CrashMax, gc_CrashMin, gc_CrashNotify, gc_CrashIncrease, gc_CrashAuto, gc_CrashCAuto;

int g_iCrashSeconds;
int g_iCrashOnmenu[MAXPLAYERS + 1];
int g_iCrashSituation[MAXPLAYERS + 1];
int g_iCrashStarted;
int g_iCrashBet[MAXPLAYERS + 1], g_iCrashTotalGained[MAXPLAYERS + 1];
float g_fCrashNumber;
float g_fCrashX;
float g_fCrashClientAuto[MAXPLAYERS + 1];
int g_iCrashClientAutoCash[MAXPLAYERS + 1];
int g_iCrashChatType[MAXPLAYERS + 1] = {-1, ...};

Handle g_hCrashCookies;

public void Crash_OnPluginStart()
{
	g_hCrashCookies = RegClientCookie("Store_Crash_AutoCashoutCookie", "[Store - Crash] Auto crash out", CookieAccess_Protected);
	gc_CrashStart = CreateConVar("store_crash_time", "30", "Seconds to start crash. Dont touch this or you may cause trouble.");
	gc_CrashMax = CreateConVar("store_crash_max", "10000", "Maximum amount of credits to spend.");
	gc_CrashMin = CreateConVar("store_crash_min", "20", "Minium amount of credits to spend.");
	gc_CrashNotify = CreateConVar("store_crash_notify_player", "0", "Wheither or not notify client on crash timer on chat.");
	gc_CrashIncrease = CreateConVar("store_crash_increase_value", "200", "How fast the multiplier in crash increase. Dont touch if you dont know what you are doing.");
	gc_CrashAuto = CreateConVar("store_crash_minimum_auto_cashout", "1.1", "Minimum value set for client");
	gc_CrashCAuto = CreateConVar("store_crash_allow_cash_out_auto", "0", "Wheither to allow player to cash out if they enable auto cashout. 1 - Enable, 0 - Disable");
	Store_BeginModuleConfig("sourcemod/store", "crash");
	STORE_CFG("store_crash_time", "30");
	STORE_CFG("store_crash_max", "10000");
	STORE_CFG("store_crash_min", "20");
	STORE_CFG("store_crash_notify_player", "0");
	STORE_CFG("store_crash_increase_value", "200");
	STORE_CFG("store_crash_minimum_auto_cashout", "1.1");
	STORE_CFG("store_crash_allow_cash_out_auto", "0");
	Store_EndModuleConfig("sourcemod/store", "crash");
	RegConsoleCmd("sm_crash", Command_Crash, "Command to see the panel");
	RegConsoleCmd("sm_crashauto", Command_CrashAuto, "Command to see the panel");
	g_iCrashSeconds = gc_CrashStart.IntValue;
	CreateTimer(1.0, Crash_maintimer, _, TIMER_REPEAT);
	AddCommandListener(Crash_Command_Say, "say");
	AddCommandListener(Crash_Command_Say, "say_team");
	HookEvent("round_end", Event_RoundEnd);
}

public void Crash_OnClientDisconnect(int client) { }

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
		g_iCrashOnmenu[i] = 0;
}

public void Crash_OnClientCookiesCached(int client)
{
	char sValue[32];
	GetClientCookie(client, g_hCrashCookies, sValue, sizeof(sValue));
	if (StrEqual(sValue, ""))
	{
		char sBuffer[12];
		Format(sBuffer, sizeof(sBuffer), "0/%f", gc_CrashAuto.FloatValue);
		g_fCrashClientAuto[client] = gc_CrashAuto.FloatValue;
		SetClientCookie(client, g_hCrashCookies, sBuffer);
	}
	else
	{
		char Explode_String[2][12];
		ExplodeString(sValue, "/", Explode_String, 2, 12);
		g_iCrashClientAutoCash[client] = view_as<int>(StringToInt(Explode_String[0]));
		g_fCrashClientAuto[client] = StringToFloat(Explode_String[1]);
	}
}

void Crash_SaveClientCookies(int client)
{
	char sValue[32];
	FormatEx(sValue, sizeof(sValue), "%b/%f", g_iCrashClientAutoCash[client], g_fCrashClientAuto[client]);
	SetClientCookie(client, g_hCrashCookies, sValue);
}

public Action Command_Crash(int client, int args)
{
	if(args < 1)
	{
		g_iCrashOnmenu[client] = 1;
		CreateTimer(0.1, Crash_crashpanel, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
	else if(g_iCrashSituation[client] == 0 && args >= 1 && g_iCrashStarted == 0)
	{
		//Classical bet shits.
		char arg1[32];
		GetCmdArg(1, arg1, sizeof(arg1));
		g_iCrashBet[client] = StringToInt(arg1);
		if(Store_GetClientCredits(client) < g_iCrashBet[client])
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Not enough Credits CM");
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
			#endif
			return Plugin_Handled;
		}
		else if(g_iCrashBet[client] > gc_CrashMax.IntValue)
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "You can't spend that much credits CM", gc_CrashMax.IntValue, g_sCreditsName);
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "You can't spend that much credits", gc_CrashMax.IntValue, g_sCreditsName);
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "You can't spend that much credits", gc_CrashMax.IntValue, g_sCreditsName);
			#endif
			return Plugin_Handled;
		}
		else if(g_iCrashBet[client] < gc_CrashMin.IntValue)
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "You have to spend at least x credits CM", gc_CrashMin.IntValue, g_sCreditsName);
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "You have to spend at least x credits", gc_CrashMin.IntValue, g_sCreditsName);
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "You have to spend at least x credits", gc_CrashMin.IntValue, g_sCreditsName);
			#endif
			return Plugin_Handled;
		}
		else
		{
			Store_SetClientCredits(client, Store_GetClientCredits(client) - g_iCrashBet[client]);
			g_iCrashSituation[client] = 1;
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Betting Placed CM", g_iCrashBet[client], g_sCreditsName);
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "Betting Placed", g_iCrashBet[client], g_sCreditsName);
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "Betting Placed", g_iCrashBet[client], g_sCreditsName);
			#endif
		}   	 
	}
   	else if(g_iCrashSituation[client] != 1 )
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Crash Already Start CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Crash Already Start");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Crash Already Start");
		#endif
	}
	else if(g_iCrashStarted == 1)
	{
	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Game in progress CM");
		C_PrintToChat(client, "%s %t", g_sChatPrefix, "Game in progress");
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix, "Game in progress");
	#endif
	}
	
   	return Plugin_Stop;
}

public Action Command_CrashAuto(int client, int args)
{
	char sMessage[64];
	GetCmdArg(1, sMessage, sizeof(sMessage));
	//StripQuotes(sMessage);
	
	float auto_amount = StringToFloat(sMessage);
	
	if(auto_amount >= gc_CrashAuto.FloatValue)
	{
		//char sBuffer_cookie[32];
		//Format(sBuffer_cookie, sizeof(sBuffer_cookie), "%f", auto_amount);
		//SetClientCookie(client, g_hCrashCookies, sBuffer_cookie);
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Crash auto input set CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Crash auto input set");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Crash auto input set");
		#endif
		g_fCrashClientAuto[client] = auto_amount;
		Crash_SaveClientCookies(client);
	}
	else
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Crash Wrong input CM", gc_CrashAuto.FloatValue);
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Crash Wrong input", gc_CrashAuto.FloatValue);
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Crash Wrong input", gc_CrashAuto.FloatValue);
		#endif
		return Plugin_Handled;
	}
	
	return Plugin_Handled;
}

public Action Crash_Command_Say(int client, const char[] command, int argc)
{
	//Vouncher
	if (g_iCrashChatType[client] == -1)
		return Plugin_Continue;
		
	char sMessage[64];
	GetCmdArgString(sMessage, sizeof(sMessage));
	StripQuotes(sMessage);
		
	switch(g_iCrashChatType[client])
	{
		case INPUT_AUTO:
		{
			float auto_amount = StringToFloat(sMessage);
			
			if(auto_amount >= gc_CrashAuto.FloatValue)
			{
				//char sBuffer_cookie[32];
				//Format(sBuffer_cookie, sizeof(sBuffer_cookie), "%f", auto_amount);
				//SetClientCookie(client, g_hCrashCookies, sBuffer_cookie);
				#if defined _clientmod_included
					MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Crash auto input set CM");
					C_PrintToChat(client, "%s %t", g_sChatPrefix, "Crash auto input set");
				#else
					PrintToChat(client, "%s %t", g_sChatPrefix, "Crash auto input set");
				#endif
				g_fCrashClientAuto[client] = auto_amount;
				Crash_SaveClientCookies(client);
				g_iCrashChatType[client] = -1;
				return Plugin_Handled;
			}
			else
			{
				#if defined _clientmod_included
					MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Crash Wrong input CM", gc_CrashAuto.FloatValue);
					C_PrintToChat(client, "%s %t", g_sChatPrefix, "Crash Wrong input", gc_CrashAuto.FloatValue);
				#else
					PrintToChat(client, "%s %t", g_sChatPrefix, "Crash Wrong input", gc_CrashAuto.FloatValue);
				#endif
				g_iCrashChatType[client] = -1;
				return Plugin_Handled;
			}
		}
	}
	
	return Plugin_Continue;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
public Action Crash_maintimer(Handle timer)
{
	g_iCrashSeconds--;
	if(g_iCrashSeconds == 600 || g_iCrashSeconds == 300 || g_iCrashSeconds == 60 || g_iCrashSeconds == 30 || g_iCrashSeconds == 10 || g_iCrashSeconds <= 3  && g_iCrashSeconds > 0)
	{
		for(int i = 1; i <= MaxClients; i++)
		{
			if(g_iCrashOnmenu[i] == 0 && IsClientInGame(i) && !IsFakeClient(i))
			{
				if(gc_CrashNotify.BoolValue)
				{
					if(g_iCrashSeconds > 60)
					{
						int minutes = g_iCrashSeconds / 60;
						#if defined _clientmod_included
							MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "Last x mins CM", minutes);
							C_PrintToChat(i, "%s %t", g_sChatPrefix, "Last x mins", minutes);
						#else
							PrintToChat(i, "%s %t", g_sChatPrefix, "Last x mins", minutes);
						#endif
					}
					else if(g_iCrashSeconds == 60)
					{
						int minutes = 1;
						#if defined _clientmod_included
							MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "Last x mins CM", minutes);
							C_PrintToChat(i, "%s %t", g_sChatPrefix, "Last x mins", minutes);
						#else
							PrintToChat(i, "%s %t", g_sChatPrefix, "Last x mins", minutes);
						#endif
					}
					else
					{
						if(g_iCrashSeconds == 3)
						{
							if(IsClientInGame(i) && !IsFakeClient(i) && g_iCrashSituation[i] != 0 && g_iCrashOnmenu[i] == 0)
							{
								g_iCrashOnmenu[i] = 1;
								CreateTimer(0.1, Crash_crashpanel, i, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
							}
						}			
						#if defined _clientmod_included
							MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "Last x secs CM", g_iCrashSeconds);
							C_PrintToChat(i, "%s %t", g_sChatPrefix, "Last x secs", g_iCrashSeconds);
						#else
							PrintToChat(i, "%s %t", g_sChatPrefix, "Last x secs", g_iCrashSeconds);
						#endif						
					}
				}
			}
		}
	}
	else if(g_iCrashSeconds == 0)
	{
		Crash_StartTheGame();
	}
	
	return Plugin_Continue;
}

public void Crash_StartTheGame()
{
	g_iCrashStarted = 1, g_fCrashNumber = 1.00; //Boring things.
	
	//Gets the X
	int luckynumber = GetRandomInt(1, 100);
	if(luckynumber <= 15)
	{
	 g_fCrashX = GetRandomFloat(1.00, 1.25);
	}
	else if(luckynumber <= 70 && luckynumber > 15)
	{
	 g_fCrashX = GetRandomFloat(1.25, 2.00);
	}
	else if(luckynumber <= 98 && luckynumber > 70)
	{
	 g_fCrashX = GetRandomFloat(2.00, 10.00);
	}
	else if (luckynumber <= 100 && luckynumber > 98)
	{
	 g_fCrashX = GetRandomFloat(6.00, 100.00);
	}

	CreateTimer(0.1, Crash_makeithigher, _, TIMER_REPEAT); // That boi will increase the number.
}

public Action Crash_makeithigher(Handle timer)
{
	if(g_fCrashNumber < g_fCrashX)
	{
		//g_fCrashNumber = g_fCrashNumber + number/200; //Didn't want to increase it for the same number everytime. With this way its gets faster every second.
		g_fCrashNumber = g_fCrashNumber + g_fCrashNumber/(gc_CrashIncrease.IntValue); 
	}
	else
	{
		g_fCrashNumber = 0.0; //We need that for the loop.
		Crash_ResetIt();
		return Plugin_Stop;
	}
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if(g_iCrashSituation[i] == 1 && g_fCrashNumber != 0)
		{
			if(g_iCrashClientAutoCash[i])
			{
				if (g_fCrashClientAuto[i] <= g_fCrashNumber)
				{
					g_iCrashTotalGained[i] = RoundToFloor(g_iCrashBet[i] * g_fCrashClientAuto[i]);
					g_iCrashSituation[i] = 2;
					int newcredits = Store_GetClientCredits(i) + g_iCrashTotalGained[i];
					Store_SetClientCredits(i, newcredits);
					EmitSoundToClient(i, "physics/metal/chain_impact_soft1.wav");
					#if defined _clientmod_included
						MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "You won x Credits with X CM", g_iCrashTotalGained[i], g_fCrashNumber);
						C_PrintToChat(i, "%s %t", g_sChatPrefix, "You won x Credits with X", g_iCrashTotalGained[i], g_fCrashNumber);
					#else
						PrintToChat(i, "%s %t", g_sChatPrefix, "You won x Credits with X", g_iCrashTotalGained[i], g_fCrashNumber);
					#endif	
				}
			}
		}
	}
	
	return Plugin_Continue;
}

public void Crash_ResetIt()
{
	CreateTimer(5.0, Crash_resettimer);
	for(int i = 1; i <= MaxClients; i++)
	{
		if(g_iCrashOnmenu[i] == 1 && IsClientInGame(i) && !IsFakeClient(i))
		{
			EmitSoundToClient(i, "physics/metal/metal_popcan_impact_hard1.wav"); //The sound that will make players break their keyboards. Yea that happened.
		}
	}
}

public Action Crash_resettimer(Handle timer)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		g_iCrashBet[i] = 0;
		g_iCrashSituation[i] = 0;
	}
	g_iCrashSeconds = gc_CrashStart.IntValue;
	g_iCrashStarted = 0;
	
	return Plugin_Continue;
}
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
///////////////////////////////////////		PANELS		//////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
public Action Crash_crashpanel(Handle timer, any client)
{
	char crashtext[64];
	int iCredits = Store_GetClientCredits(client);
	//I dont have any idea about this part.
	if(g_iCrashOnmenu[client] == 1 && IsClientInGame(client) && !IsFakeClient(client))
	{
		char gainedcredits[64];
		Format(gainedcredits, sizeof(gainedcredits), "%t", "Gained");
		// The game is pending
		if(g_iCrashStarted == 0)
		{
			char startingtext[32];
			Format(startingtext, sizeof(startingtext), "|	  %t: %d", "Starting", g_iCrashSeconds);
			Panel crashmenu_baslamadan = new Panel();
			Format(crashtext, sizeof(crashtext), "%t" ,"crash");
			crashmenu_baslamadan.SetTitle(crashtext);
			crashmenu_baslamadan.DrawText("---------------------------------");
			crashmenu_baslamadan.DrawText("^");
			//crashmenu_baslamadan.DrawText("|  ");
			crashmenu_baslamadan.DrawText("|  ");
			crashmenu_baslamadan.DrawText("|"); 
			crashmenu_baslamadan.DrawText(startingtext);
			crashmenu_baslamadan.DrawText("|  ");
			//crashmenu_baslamadan.DrawText("|  ");
			crashmenu_baslamadan.DrawText("| __ __ __ __ __ __ __ __ ");
			crashmenu_baslamadan.DrawText("---------------------------------");
			if(g_iCrashSituation[client] == 0)
			{
				//char command[32];
				//Format(crashtext, sizeof(crashtext), "	%t", "Type in chat !crash");
				//crashmenu_baslamadan.DrawText(crashtext);
				switch(g_iCrashClientAutoCash[client])
				{
					case 0:
					{
						Format(crashtext, sizeof(crashtext), "%t %t", "Client Auto Cashout pref", g_iCrashClientAutoCash[client] ? "Crash Auto On":"Crash Auto Off");
						crashmenu_baslamadan.DrawText(crashtext);
					}
					case 1:
					{
						Format(crashtext, sizeof(crashtext), "%t %t", "Client Auto Cashout pref", g_iCrashClientAutoCash[client] ? "Crash Auto On":"Crash Auto Off");
						crashmenu_baslamadan.DrawText(crashtext);
						Format(crashtext, sizeof(crashtext), "%t %0.2fx", "Client Auto Cashout pref", g_fCrashClientAuto[client]);
						crashmenu_baslamadan.DrawText(crashtext);
					}
				}
				//crashmenu_baslamadan.DrawText("---------------------------------");
				crashmenu_baslamadan.DrawText(" ");
			}
			else if(g_iCrashSituation[client] == 1)
			{
				//char buffer[64];
				Format(crashtext, sizeof(crashtext), "%s: -",gainedcredits);
				crashmenu_baslamadan.DrawText(crashtext);
				Format(crashtext, sizeof(crashtext), "%t", "Your bet", g_iCrashBet[client], g_sCreditsName);
				crashmenu_baslamadan.DrawText(crashtext);
				switch(g_iCrashClientAutoCash[client])
				{
					case 0:
					{
						Format(crashtext, sizeof(crashtext), "%t %t", "Client Auto Cashout pref", g_iCrashClientAutoCash[client] ? "Crash Auto On":"Crash Auto Off");
						crashmenu_baslamadan.DrawText(crashtext);
					}
					case 1:
					{
						Format(crashtext, sizeof(crashtext), "%t %t", "Client Auto Cashout pref", g_iCrashClientAutoCash[client] ? "Crash Auto On":"Crash Auto Off");
						crashmenu_baslamadan.DrawText(crashtext);
						Format(crashtext, sizeof(crashtext), "%t %0.2fx", "Client Auto Cashout pref", g_fCrashClientAuto[client]);
						crashmenu_baslamadan.DrawText(crashtext);
					}
				}
				//crashmenu_baslamadan.DrawText("---------------------------------");
				crashmenu_baslamadan.DrawText(" ");
			}
			//SetPanelCurrentKey(crashmenu_baslamadan, 9);
			
			crashmenu_baslamadan.CurrentKey = 2;
			Format(crashtext, sizeof(crashtext), "%t", "Game Info");
			crashmenu_baslamadan.DrawItem(crashtext);
			
			crashmenu_baslamadan.CurrentKey = 3;
			Format(crashtext, sizeof(crashtext), "%t", "Bet Minium", gc_CrashMin.IntValue);
			crashmenu_baslamadan.DrawItem(crashtext, iCredits < gc_CrashMin.IntValue || g_iCrashSituation[client]!=0 ? ITEMDRAW_IGNORE : ITEMDRAW_DEFAULT);
			
			crashmenu_baslamadan.CurrentKey = 4;
			Format(crashtext, sizeof(crashtext), "%t", "Bet Maximum", iCredits > gc_CrashMax.IntValue ? gc_CrashMax.IntValue : iCredits);
			crashmenu_baslamadan.DrawItem(crashtext, iCredits < gc_CrashMin.IntValue || g_iCrashSituation[client]!=0 ? ITEMDRAW_IGNORE  : ITEMDRAW_DEFAULT);
			
			crashmenu_baslamadan.CurrentKey = 5;
			Format(crashtext, sizeof(crashtext), "%t", "Bet Random", gc_CrashMin.IntValue, iCredits > gc_CrashMax.IntValue ? gc_CrashMax.IntValue : iCredits);
			crashmenu_baslamadan.DrawItem(crashtext, iCredits < gc_CrashMin.IntValue || g_iCrashSituation[client]!=0 ? ITEMDRAW_IGNORE : ITEMDRAW_DEFAULT);
			
			crashmenu_baslamadan.CurrentKey = 6;
			Format(crashtext, sizeof(crashtext), "%t", g_iCrashClientAutoCash[client] ? "Crash Auto Off Panel":"Crash Auto On Panel");
			crashmenu_baslamadan.DrawItem(crashtext, ITEMDRAW_DEFAULT);
			
			crashmenu_baslamadan.CurrentKey = 7;
			Format(crashtext, sizeof(crashtext), "%t", "Crash set auto");
			crashmenu_baslamadan.DrawItem(crashtext, g_iCrashClientAutoCash[client] ? ITEMDRAW_DEFAULT : ITEMDRAW_IGNORE);	
			
			
			crashmenu_baslamadan.DrawText("---------------------------------");
			
			crashmenu_baslamadan.CurrentKey = 10;
			Format(crashtext, sizeof(crashtext), "%t", "Close");
			crashmenu_baslamadan.DrawItem(crashtext);
			
			crashmenu_baslamadan.Send(client, crashmenu_handler, 1);
			delete crashmenu_baslamadan;
		}
		// The game has started
		else if(g_iCrashStarted == 1)
		{
			char numberZ[32], betZ[32], gainedZ[32];
			if(g_fCrashNumber != 0.0)
			{
				Format(numberZ, sizeof(numberZ), "|				x%3.2f", g_fCrashNumber);
			}
			else
			{
				Format(numberZ, sizeof(numberZ), "|				x%3.2f", g_fCrashX);
			}
			Format(betZ, sizeof(betZ), "%t", "Your bet", g_iCrashBet[client], g_sCreditsName);
			Format(gainedZ, sizeof(gainedZ), "%t", "Gained x Credits", RoundToFloor(g_iCrashBet[client] * g_fCrashNumber), g_sCreditsName);
			Panel crashmenu_aktif = new Panel();
			//crashmenu_aktif.SetTitle("Crash");
			Format(crashtext, sizeof(crashtext), "%t" ,"crash");
			crashmenu_aktif.SetTitle(crashtext);
			crashmenu_aktif.DrawText("---------------------------------");
			crashmenu_aktif.DrawText("^");
			//crashmenu_aktif.DrawText("|  ");
			crashmenu_aktif.DrawText("|  ");
			crashmenu_aktif.DrawText("|"); 
			crashmenu_aktif.DrawText(numberZ);
			if(g_fCrashNumber != 0)
			{
				crashmenu_aktif.DrawText("|  ");
			}
			else
			{
				Format(crashtext, sizeof(crashtext), "|			  %t", "Crash!");
				crashmenu_aktif.DrawText(crashtext);
			}
			//crashmenu_aktif.DrawText("|  ");
			crashmenu_aktif.DrawText("| __ __ __ __ __ __ __ __ ");
			crashmenu_aktif.DrawText("---------------------------------");
			if(g_iCrashSituation[client] == 0)
			{
				//SetPanelCurrentKey(crashmenu_aktif, 9);
				crashmenu_aktif.CurrentKey = 2;
				Format(crashtext, sizeof(crashtext), "%t", "Game Info");	
				crashmenu_aktif.DrawItem(crashtext);
				crashmenu_aktif.DrawText("---------------------------------");
				crashmenu_aktif.CurrentKey = 10;
				Format(crashtext, sizeof(crashtext), "%t", "Close");
				crashmenu_aktif.DrawItem(crashtext);
				if(g_fCrashNumber != 0.0)
				{
					crashmenu_aktif.Send(client, crashmenu_handler, 1);
				}
				else
				{
					crashmenu_aktif.Send(client, crashmenu_handler, 5);					 	
				}
				delete crashmenu_aktif;
			}
			else if(g_iCrashSituation[client] == 1 || g_iCrashSituation[client] == 2)
			{
				if(g_iCrashSituation[client] == 1)
				{
					crashmenu_aktif.DrawText(gainedZ);
					switch(g_iCrashClientAutoCash[client])
					{
						case 0:
						{
							Format(crashtext, sizeof(crashtext), "%t %t", "Client Auto Cashout pref", g_iCrashClientAutoCash[client] ? "Crash Auto On":"Crash Auto Off");
							crashmenu_aktif.DrawText(crashtext);
						}
						case 1:
						{
							Format(crashtext, sizeof(crashtext), "%t %t", "Client Auto Cashout pref", g_iCrashClientAutoCash[client] ? "Crash Auto On":"Crash Auto Off");
							crashmenu_aktif.DrawText(crashtext);
							Format(crashtext, sizeof(crashtext), "%t %0.2f", "Client Auto Cashout pref", g_fCrashClientAuto[client]);
							crashmenu_aktif.DrawText(crashtext);
						}
					}
					
				}
				else if(g_iCrashSituation[client] == 2)
				{
					char lastgain[32];
					Format(lastgain, sizeof(lastgain), "%t", "Gained x Credits", g_iCrashTotalGained[client], g_sCreditsName);
					crashmenu_aktif.DrawText(lastgain);
					switch(g_iCrashClientAutoCash[client])
					{
						case 0:
						{
							Format(crashtext, sizeof(crashtext), "%t %t", "Client Auto Cashout pref", g_iCrashClientAutoCash[client] ? "Crash Auto On":"Crash Auto Off");
							crashmenu_aktif.DrawText(crashtext);
						}
						case 1:
						{
							Format(crashtext, sizeof(crashtext), "%t %t", "Client Auto Cashout pref", g_iCrashClientAutoCash[client] ? "Crash Auto On":"Crash Auto Off");
							crashmenu_aktif.DrawText(crashtext);
							Format(crashtext, sizeof(crashtext), "%t %0.2f", "Client Auto Cashout pref", g_fCrashClientAuto[client]);
							crashmenu_aktif.DrawText(crashtext);
						}
					}
				}
				crashmenu_aktif.DrawText(betZ);
				crashmenu_aktif.DrawText("---------------------------------");
				if(g_iCrashSituation[client] == 1)
				{
					if(g_fCrashNumber != 0.0)
					{
						crashmenu_aktif.CurrentKey = 1;
						Format(crashtext, sizeof(crashtext), "%t", "Cash out");
						if (g_iCrashClientAutoCash[client] && !gc_CrashCAuto.BoolValue)
						{
							crashmenu_aktif.DrawItem(crashtext, ITEMDRAW_DISABLED);
						}
						else crashmenu_aktif.DrawItem(crashtext);
						//SetPanelCurrentKey(crashmenu_aktif, 9);
						//crashmenu_aktif.CurrentKey = 1;
						//crashmenu_aktif.DrawItem("Withdraw");
						crashmenu_aktif.DrawText("---------------------------------");
						crashmenu_aktif.Send(client, crashmenu_go_handler, 1);
						delete crashmenu_aktif;
					}
					else
					{
						//SetPanelCurrentKey(crashmenu_aktif, 9);
						crashmenu_aktif.CurrentKey = 2;
						Format(crashtext, sizeof(crashtext), "%t", "Game Info");	
						crashmenu_aktif.DrawItem(crashtext);
						crashmenu_aktif.DrawText("---------------------------------");
						crashmenu_aktif.CurrentKey = 10;
						Format(crashtext, sizeof(crashtext), "%t", "Close");
						crashmenu_aktif.DrawItem(crashtext);
						crashmenu_aktif.Send(client, crashmenu_go_handler, 5);  
						delete crashmenu_aktif;
					}
				}
				else if(g_iCrashSituation[client] == 2)
				{
					//SetPanelCurrentKey(crashmenu_aktif, 9);
					crashmenu_aktif.CurrentKey = 2;
					Format(crashtext, sizeof(crashtext), "%t", "Game Info");	
					crashmenu_aktif.DrawItem(crashtext);
					crashmenu_aktif.DrawText("---------------------------------");
					crashmenu_aktif.CurrentKey = 10;
					Format(crashtext, sizeof(crashtext), "%t", "Close");
					crashmenu_aktif.DrawItem(crashtext);
					if(g_fCrashNumber != 0.0)
					{
						crashmenu_aktif.Send(client, crashmenu_go_handler, 1);
						delete crashmenu_aktif;
					}
					else
					{
						crashmenu_aktif.Send(client, crashmenu_go_handler, 5);
						delete crashmenu_aktif;
					}
				}	
			}	
		}
	}
	else
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

public int crashmenu_go_handler(Menu menu, MenuAction action, int param1, int itemNum)
{
	char sBuffer[255];
	if(action == MenuAction_Select)
	{
		
		switch(itemNum)
		{
			case 1: // 10?
			{
				if(g_iCrashSituation[param1] == 1 && g_fCrashNumber == 0)
				{
					g_iCrashOnmenu[param1] = 0;
				}
				else if(g_iCrashSituation[param1] == 1 && g_fCrashNumber != 0)
				{
					g_iCrashTotalGained[param1] = RoundToFloor(g_iCrashBet[param1] * g_fCrashNumber);
					g_iCrashSituation[param1] = 2;
					int newcredits = Store_GetClientCredits(param1) + g_iCrashTotalGained[param1];
					Store_SetClientCredits(param1, newcredits);
					if(g_fCrashNumber > 4)
					{
						Format(sBuffer, sizeof(sBuffer), "%t", "crash");
						#if defined _clientmod_included
							MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Player won x Credits with X CM", param1, g_iCrashTotalGained[param1], g_sCreditsName, g_fCrashNumber, sBuffer);
							C_PrintToChatAll("%s %t", g_sChatPrefix, "Player won x Credits with X", param1, g_iCrashTotalGained[param1], g_sCreditsName, g_fCrashNumber, sBuffer);
						#else
							PrintToChatAll("%s %t", g_sChatPrefix, "Player won x Credits with X", param1, g_iCrashTotalGained[param1], g_sCreditsName, g_fCrashNumber, sBuffer);
						#endif	
					}
					else
					{
						EmitSoundToClient(param1, "physics/metal/chain_impact_soft1.wav");
						#if defined _clientmod_included
							MC_PrintToChat(param1, "%s %t", g_sChatPrefix_CM, "You won x Credits with X CM", g_iCrashTotalGained[param1], g_fCrashNumber);
							C_PrintToChat(param1, "%s %t", g_sChatPrefix, "You won x Credits with X", g_iCrashTotalGained[param1], g_fCrashNumber);
						#else
							PrintToChat(param1, "%s %t", g_sChatPrefix, "You won x Credits with X", g_iCrashTotalGained[param1], g_fCrashNumber);
						#endif
					}
				}
				else if(g_iCrashSituation[param1] == 2)
				{
					g_iCrashOnmenu[param1] = 0;
				}
				EmitSoundToClient(param1, g_sMenuExit);
			}
			case 2:
			{
				g_iCrashOnmenu[param1] = 0;
				Crash_Panel_GameInfo(param1);
				EmitSoundToClient(param1, g_sMenuItem);
			}
		}
	}
	else if(action == MenuAction_End)
	{
	}
	else if(action == MenuAction_Cancel)
	{
	}
	
	return 0;
}

public int crashmenu_handler(Menu menu, MenuAction action, int param1, int itemNum)
{
	if(action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 2:
			{
				g_iCrashOnmenu[param1] = 0;
				Crash_Panel_GameInfo(param1);
				EmitSoundToClient(param1, g_sMenuItem);
			}
			case 3, 4, 5:
			{
				// Decline when player come back to life
				int credits = Store_GetClientCredits(param1);
				switch(itemNum)
				{
					case 3:
					{
						g_iCrashBet[param1] = gc_CrashMin.IntValue;
						g_iCrashSituation[param1] = 1;
						Store_SetClientCredits(param1, credits - g_iCrashBet[param1]);
					}
					case 4: 
					{
						g_iCrashBet[param1] = credits > gc_CrashMax.IntValue ? gc_CrashMax.IntValue : credits;
						g_iCrashSituation[param1] = 1;
						Store_SetClientCredits(param1, credits - g_iCrashBet[param1]);
					}
					case 5: 
					{
						g_iCrashBet[param1] = GetRandomInt(gc_CrashMin.IntValue, credits > gc_CrashMax.IntValue ? gc_CrashMax.IntValue : credits);
						g_iCrashSituation[param1] = 1;
						Store_SetClientCredits(param1, credits - g_iCrashBet[param1]);
					}
				}

				//Panel_PlaceColor(client);
				//ClientCommand(param1, "sm_crash");

				//ClientCommand(client, "play %s", g_sMenuItem);
				EmitSoundToClient(param1, g_sMenuItem);
			}
			case 6:
			{
				switch(g_iCrashClientAutoCash[param1])
				{
					case 0:
					{
						g_iCrashClientAutoCash[param1] = true;
						Crash_SaveClientCookies(param1);
					}
					case 1:
					{
						g_iCrashClientAutoCash[param1] = false;
						Crash_SaveClientCookies(param1);
					}
				}
				EmitSoundToClient(param1, g_sMenuItem);
			}
			case 7:
			{
				g_iCrashChatType[param1] = INPUT_AUTO;
				#if defined _clientmod_included
					MC_PrintToChat(param1, "%s %t", g_sChatPrefix_CM, "Crash auto input CM");
					C_PrintToChat(param1, "%s %t", g_sChatPrefix, "Crash auto input");
				#else
					PrintToChat(param1, "%s %t", g_sChatPrefix, "Crash auto input");
				#endif
				EmitSoundToClient(param1, g_sMenuItem);
			}
			case 10:
			{
				g_iCrashOnmenu[param1] = 0;
				EmitSoundToClient(param1, g_sMenuExit);
			}
		}
	}
	else if(action == MenuAction_End)
	{
	}
	else if(action == MenuAction_Cancel)
	{	
	}
	
	return 0;
}


//Show the games info panel
void Crash_Panel_GameInfo(int client)
{
	char sBuffer[1024];
	Panel panel = new Panel();

	//Build the panel title three lines high - Panel line #1-3
	Format(sBuffer, sizeof(sBuffer), "%t" ,"crash");
	panel.SetTitle(sBuffer);

	// Draw Spacer Line - Panel line #4
	panel.DrawText(" ");

	Format(sBuffer, sizeof(sBuffer), "	%t", "Crash Info 1");
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	
	Format(sBuffer, sizeof(sBuffer), "%t", "Crash Info 2");
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	
	Format(sBuffer, sizeof(sBuffer), "%t", "Crash Info 3");
	panel.DrawText(sBuffer);
	panel.DrawText(" ");
	
	Format(sBuffer, sizeof(sBuffer), "%t", "Crash Info 4", gc_CrashMin.IntValue, g_sCreditsName, gc_CrashMax.IntValue, g_sCreditsName);
	panel.DrawText(sBuffer);

	// Draw Spacer item - Panel line #11 - Panel item #1
	panel.DrawText(" ");
	panel.DrawText(" ");
	panel.CurrentKey = 1;
	Format(sBuffer, sizeof(sBuffer), "%t", "Back");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.DrawText(" ");
	panel.CurrentKey = 10;
	Format(sBuffer, sizeof(sBuffer), "%t", "Exit");
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, Crash_Handler_WheelRun, 20);

	delete panel;
}

public int Crash_Handler_WheelRun(Menu panel, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		switch(itemNum)
		{
			case 1:
			{
				ClientCommand(client, "sm_crash");
				EmitSoundToClient(client, g_sMenuItem);
			}
			// Item 9 - exit cancel
			case 10:
			{
				EmitSoundToClient(client, g_sMenuExit);
			}
		}
	}

	delete panel;
	
	return 0;
}

//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////
//////////////////////////////////////////////////////////////////////////////////////////////////////////////////////////

void Crash_OnMapStart()
{
	PrecacheSound("physics/metal/metal_popcan_impact_hard1.wav");
	PrecacheSound("physics/metal/chain_impact_soft1.wav");
}

#else
void Crash_OnPluginStart() {}
void Crash_OnClientDisconnect(int client)
{
	#pragma unused client
}
void Crash_OnMapStart() {}
void Crash_OnClientCookiesCached(int client)
{
	#pragma unused client
}
#endif
