char g_sSound[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
char g_sTrigger[STORE_MAX_ITEMS][64];
//int g_unPrice[STORE_MAX_ITEMS];
int g_iCooldown[STORE_MAX_ITEMS];
int g_iOrigin[STORE_MAX_ITEMS];
//float g_fVolume[STORE_MAX_ITEMS];
//int g_iPerm[STORE_MAX_ITEMS];
int g_iItemId[STORE_MAX_ITEMS];
int g_iFlagBits[STORE_MAX_ITEMS];

char g_sSteam[256];

int g_isaysoundCount = 0;
int g_isaysoundSpam[MAXPLAYERS + 1] = {0,...};

int g_iType;
int g_iMaxUses;

int g_iUses[MAXPLAYERS + 1] = {0,...};

float g_fPlayerVolume[MAXPLAYERS + 1] = {1.0, ...};
Cookie g_hHideCookie;

#define VOLUME_COOKIE_STEP 0.2


public void Sounds_OnPluginStart()
{
	Store_RegisterHandler("saysound", "sound", Sounds_OnMapStart, Sounds_Reset, Sounds_Config, Sounds_Equip, Sounds_Remove, false);
	
	g_iType = RegisterConVar("sm_store_saysound_type", "1", "Type of the max uses limit (0 = Map limit, 1 = Round limit)", TYPE_INT);
	g_iMaxUses = RegisterConVar("sm_store_saysound_max_uses", "1", "Max uses", TYPE_INT);
	
	g_hHideCookie = new Cookie("SaySound_Volume_Cookie", "Cookie to set the volume of MVP sounds", CookieAccess_Private);
	SetCookieMenuItem(PrefMenu, 0, "");

	LoadTranslations("store.phrases");

	HookEvent("player_say", Event_PlayerSay);
	//HookEvent("round_end", Reset_Count ,EventHookMode_Pre);
	HookEvent("round_start", Reset_Count);
}

public void PrefMenu(int client, CookieMenuAction actions, any info, char[] buffer, int maxlen)
{
	if (actions == CookieMenuAction_DisplayOption)
	{
		FormatEx(buffer, maxlen, "SaySound Volume: %i%%", RoundToNearest(g_fPlayerVolume[client] * 100)); // Rounding because we never know
	}
	else if (actions == CookieMenuAction_SelectOption)
	{
		CMD_Volume(client);
		ShowCookieMenu(client);
	}
}

void CMD_Volume(int client)
{
	char sCookieValue[8];
	
	g_fPlayerVolume[client] = g_fPlayerVolume[client] - VOLUME_COOKIE_STEP;
	
	if (g_fPlayerVolume[client] < 0.0)
		g_fPlayerVolume[client] = 1.0;
	
	FloatToString(g_fPlayerVolume[client], sCookieValue, sizeof(sCookieValue));
	g_hHideCookie.Set(client, sCookieValue);
	
	char buffer[20];
	FormatEx(buffer, sizeof(buffer), "%i%%", RoundToNearest(g_fPlayerVolume[client] * 100));
	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Volume set CM", "saysound CM", buffer);
		C_PrintToChat(client, "%s %t", g_sChatPrefix, "Volume set", "saysound", buffer);
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix, "Volume set", "saysound", buffer);
	#endif
}

public void Reset_Count(Handle event , const char[] name , bool dontBroadcast)
{
	for(int i=1; i<=MaxClients; i++)
	{
		if(g_eCvars[g_iType].aCache == 1)
		{
			g_iUses[i] = 0;
		}
	}
}

public void Sounds_OnMapStart()
{
	char sBuffer[256];

	for (int i = 0; i < g_isaysoundCount; i++)
	{
		PrecacheSound(g_sSound[i], true);
		FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sSound[i]);
		AddFileToDownloadsTable(sBuffer);
	}
}

public void Sounds_Reset()
{
	g_isaysoundCount = 0;
}

public bool Sounds_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_isaysoundCount);

	kv.GetString("sound", g_sSound[g_isaysoundCount], PLATFORM_MAX_PATH);

	char sBuffer[256];
	FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sSound[g_isaysoundCount]);

	if (!FileExists(sBuffer, true))
	{
		//Store_LogMessage(0, LOG_ERROR, "Can't find sound %s.", sBuffer);
		return false;
	}

	kv.GetString("trigger", g_sTrigger[g_isaysoundCount], 64);
	//g_iPerm[g_isaysoundCount] = kv.GetNum("perm", 0);
	g_iCooldown[g_isaysoundCount] = kv.GetNum("cooldown", 30);
	//g_fVolume[g_isaysoundCount] = kv.GetFloat("volume", 0.5);
	g_iOrigin[g_isaysoundCount] = kv.GetNum("origin", 1);
	//g_unPrice[g_isaysoundCount] = kv.GetNum("price");
	g_iItemId[g_isaysoundCount] = itemid;

	kv.GetString("flag", sBuffer, sizeof(sBuffer), "\0");
	g_iFlagBits[g_isaysoundCount] = ReadFlagString(sBuffer);

	kv.GetString("steam", g_sSteam[g_isaysoundCount], 64, "\0");

	if (g_iCooldown[g_isaysoundCount] < 10)
	{
		g_iCooldown[g_isaysoundCount] = 10;
	}

	/*if (g_fVolume[g_isaysoundCount] > 1.0)
	{
		g_fVolume[g_isaysoundCount] = 1.0;
	}

	if (g_fVolume[g_isaysoundCount] <= 0.0)
	{
		g_fVolume[g_isaysoundCount] = 0.05;
	}*/

	g_isaysoundCount++;

	return true;
}

public int Sounds_Equip(int client, int itemid)
{
	int iIndex = Store_GetDataIndex(itemid);

	if (g_isaysoundSpam[client] > GetTime())
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Spam Cooldown CM", g_isaysoundSpam[client] - GetTime());
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Spam Cooldown", g_isaysoundSpam[client] - GetTime());
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Spam Cooldown", g_isaysoundSpam[client] - GetTime());
		#endif
		Store_DisplayPreviousMenu(client);
		return 1;
	}

	if (!IsPlayerAlive(client) && g_iOrigin[iIndex] > 1)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Must be Alive CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Must be Alive");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Must be Alive");
		#endif
		return 1;
	}

	if(g_iUses[client]<view_as<int>(g_eCvars[g_iMaxUses].aCache))
	{
		g_iUses[client]++;
		switch (g_iOrigin[iIndex])
		{
			// Sound From global world
			case 1:
			{
				for (int i = 1; i <= MaxClients; i++)
				{
					if (!IsClientInGame(i) || IsFakeClient(i))
						continue;

					if(g_fPlayerVolume[i]!=0.0)
						EmitSoundToClient(i, g_sSound[iIndex], SOUND_FROM_WORLD, _, SNDLEVEL_RAIDSIREN, _, g_fPlayerVolume[i]);
				}
				
				//EmitSoundToAll(g_sSound[iIndex], SOUND_FROM_WORLD, _, SNDLEVEL_RAIDSIREN, _, g_fPlayerVolume[i]);
			}
			// Sound From local player
			case 2:
			{
				//float fVec[3];
				//GetClientAbsOrigin(client, fVec);
				
				for (int i = 1; i <= MaxClients; i++)
				{
					if (!IsClientInGame(i) || IsFakeClient(i))
						continue;
						
					if(g_fPlayerVolume[i]!=0.0)
						EmitSoundToClient(i, g_sSound[iIndex], client, SOUND_FROM_PLAYER, SNDLEVEL_RAIDSIREN, _, g_fPlayerVolume[i]);
				}
		
				//EmitAmbientSound(g_sSound[iIndex], fVec, SOUND_FROM_PLAYER, SNDLEVEL_RAIDSIREN, _, g_fPlayerVolume[i]);
			}
			// Sound From player voice
			case 3:
			{
				float fPos[3], fAgl[3];
				GetClientEyePosition(client, fPos);
				GetClientEyeAngles(client, fAgl);

				// player`s mouth
				fPos[2] -= 3.0;
				
				for (int i = 1; i <= MaxClients; i++)
				{
					if (!IsClientInGame(i) || IsFakeClient(i))
						continue;
						
					if(g_fPlayerVolume[i]!=0.0)
						EmitSoundToClient(i, g_sSound[iIndex], client, SNDCHAN_VOICE, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fPlayerVolume[i], SNDPITCH_NORMAL, client, fPos, fAgl, true);
				}
				
				//EmitSoundToAll(g_sSound[iIndex], client, SNDCHAN_VOICE, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fPlayerVolume[i], SNDPITCH_NORMAL, client, fPos, fAgl, true);
			}
		}
	}
	else
	{
		if (g_eCvars[g_iType].aCache == 0)
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "say sound map max uses CM", view_as<int>(g_eCvars[g_iMaxUses].aCache));
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "say sound map max uses", view_as<int>(g_eCvars[g_iMaxUses].aCache));
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "say sound map max uses", view_as<int>(g_eCvars[g_iMaxUses].aCache));
			#endif
		}
		else 
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "say sound round max uses CM", view_as<int>(g_eCvars[g_iMaxUses].aCache));
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "say sound round max uses", view_as<int>(g_eCvars[g_iMaxUses].aCache));
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "say sound round max uses", view_as<int>(g_eCvars[g_iMaxUses].aCache));
			#endif
		}
	}
	g_isaysoundSpam[client] = GetTime() + g_iCooldown[iIndex];
	
	//Store_SetClientPreviousMenu(client, MENU_PARENT);
	Store_DisplayPreviousMenu(client);

	return 1; // 1 ITEM_EQUIP_KEEP / 0 ITEM_EQUIP_REMOVE
}

public int Sounds_Remove(int client, int itemid)
{
	return 0;
}

public void Event_PlayerSay(Event event, char[] name, bool dontBroadcast)
{

	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client)
		return;

	char sBuffer[32];
	GetEventString(event, "text", sBuffer, sizeof(sBuffer));

	for (int i = 0; i < g_isaysoundCount; i++)
	{
		if (strcmp(sBuffer, g_sTrigger[i]) == 0)
		{
			if (g_iUses[client] < g_eCvars[g_iMaxUses].aCache)
			{
				if (g_isaysoundSpam[client] > GetTime())
				{
					#if defined _clientmod_included
						MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Spam Cooldown CM", g_isaysoundSpam[client] - GetTime());
						C_PrintToChat(client, "%s %t", g_sChatPrefix, "Spam Cooldown", g_isaysoundSpam[client] - GetTime());
					#else
						PrintToChat(client, "%s %t", g_sChatPrefix, "Spam Cooldown", g_isaysoundSpam[client] - GetTime());
					#endif
					return;
				}

				if (!CheckFlagBits(client, g_iFlagBits[i]) /*|| !Store_HasClientAccess(client) */|| !CheckSteamAuth(client, g_sSteam[i]))
					return;

				if (Store_HasClientItem(client, g_iItemId[i]))
				{
					switch (g_iOrigin[i])
					{
						// Sound From global world
						case 1:
						{
							for (int z = 1; z <= MaxClients; z++)
							{
								if (!IsClientInGame(z) || IsFakeClient(z))
									continue;

								if(g_fPlayerVolume[z]!=0.0)
									EmitSoundToClient(z, g_sSound[i], SOUND_FROM_WORLD, _, SNDLEVEL_RAIDSIREN, _, g_fPlayerVolume[i]);
							}
							
							//EmitSoundToAll(g_sSound[i], SOUND_FROM_WORLD, _, SNDLEVEL_RAIDSIREN, _, g_fVolume[i]);
						}
						// Sound From local player
						case 2:
						{
							//float fVec[3];
							//GetClientAbsOrigin(client, fVec);
							
							for (int z = 1; z <= MaxClients; z++)
							{
								if (!IsClientInGame(z) || IsFakeClient(z))
									continue;
									
								if(g_fPlayerVolume[z]!=0.0)
									EmitSoundToClient(z, g_sSound[i], client, SOUND_FROM_PLAYER, SNDLEVEL_RAIDSIREN, _, g_fPlayerVolume[i]);
							}
					
							//EmitAmbientSound(g_sSound[i], fVec, SOUND_FROM_PLAYER, SNDLEVEL_RAIDSIREN, _, g_fVolume[i]);
						}
						// Sound From player voice
						case 3:
						{
							float fPos[3], fAgl[3];
							GetClientEyePosition(client, fPos);
							GetClientEyeAngles(client, fAgl);

							// player`s mouth
							fPos[2] -= 3.0;
							
							for (int z = 1; z <= MaxClients; z++)
							{
								if (!IsClientInGame(z) || IsFakeClient(z))
									continue;
									
								if(g_fPlayerVolume[z]!=0.0)
									EmitSoundToClient(z, g_sSound[i], client, SNDCHAN_VOICE, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fPlayerVolume[i], SNDPITCH_NORMAL, client, fPos, fAgl, true);
							}
							
							//EmitSoundToAll(g_sSound[i], client, SNDCHAN_VOICE, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fVolume[i], SNDPITCH_NORMAL, client, fPos, fAgl, true);
						}
					}


					g_isaysoundSpam[client] = GetTime() + g_iCooldown[i];
					g_iUses[client]++;
				}
			}
			else
			{
				if (g_eCvars[g_iType].aCache == 0)
				{
					#if defined _clientmod_included
						MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "say sound map max uses CM", view_as<int>(g_eCvars[g_iMaxUses].aCache));
						C_PrintToChat(client, "%s %t", g_sChatPrefix, "say sound map max uses", view_as<int>(g_eCvars[g_iMaxUses].aCache));
					#else
						PrintToChat(client, "%s %t", g_sChatPrefix, "say sound map max uses", view_as<int>(g_eCvars[g_iMaxUses].aCache));
					#endif
				}
				else 
				{
					#if defined _clientmod_included
						MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "say sound round max uses CM", view_as<int>(g_eCvars[g_iMaxUses].aCache));
						C_PrintToChat(client, "%s %t", g_sChatPrefix, "say sound round max uses", view_as<int>(g_eCvars[g_iMaxUses].aCache));
					#else
						PrintToChat(client, "%s %t", g_sChatPrefix, "say sound round max uses", view_as<int>(g_eCvars[g_iMaxUses].aCache));
					#endif
				}
			}
			break;
		}
	}
}

public void Saysound_OnPreviewItem(int client, char[] type, int index)
{
	if (!StrEqual(type, "saysound"))
		return;

	EmitSoundToClient(client, g_sSound[index], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, g_fPlayerVolume[index]);

	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Play Preview CM", client);
		C_PrintToChat(client, "%s %t", g_sChatPrefix, "Play Preview", client);
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix, "Play Preview", client);
	#endif
}

bool CheckFlagBits(int client, int flagsNeed, int flags = -1)
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