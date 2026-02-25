#if STORE_MODULE_SOUNDS
char g_sSound[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
char g_sTrigger[STORE_MAX_ITEMS][64];
int g_iCooldown[STORE_MAX_ITEMS];
int g_iOrigin[STORE_MAX_ITEMS];
int g_iItemId[STORE_MAX_ITEMS];
int g_iFlagBits[STORE_MAX_ITEMS];

char g_sSteam[256];

int g_isaysoundCount = 0;
int g_isaysoundSpam[MAXPLAYERS + 1] = {0,...};

int g_iType;
int g_iMaxUses;
int g_cvarDefaultVolume;

int g_iUses[MAXPLAYERS + 1] = {0,...};

int g_iPlayerVolume[MAXPLAYERS + 1] = {100, ...};
Cookie g_hVolumeCookie;

public void Sounds_OnPluginStart()
{
	Store_RegisterHandler("saysound", "sound", Sounds_OnMapStart, Sounds_Reset, Sounds_Config, Sounds_Equip, Sounds_Remove, false);
	
	g_iType = RegisterConVar("sm_store_saysound_type", "1", "Type of the max uses limit (0 = Map limit, 1 = Round limit)", TYPE_INT);
	g_iMaxUses = RegisterConVar("sm_store_saysound_max_uses", "1", "Max uses", TYPE_INT);
	g_cvarDefaultVolume = RegisterConVar("sm_store_saysound_default", "100", "Default volume for say sounds (0-100)", TYPE_INT);
	
	g_hVolumeCookie = new Cookie("saysound_volume_cookie", "Volume for say sounds", CookieAccess_Private);

	LoadTranslations("store.phrases");

	HookEvent("player_say", Event_PlayerSay);
	HookEvent("round_start", Reset_Count);
}

public void Sounds_OnAllPluginsLoaded()
{
	CreateTimer(1.0, Timer_AddMenu, _, TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_AddMenu(Handle timer)
{
	if (g_isaysoundCount > 0)
	{
		SetCookieMenuItem(VolumeSettingsHandler, 0, "Say sound volume");
	}
	
	return Plugin_Stop;
}

public void Sounds_OnClientPostAdminCheck(int client)
{
	if (IsFakeClient(client))
		return;
	
	if (AreClientCookiesCached(client))
	{
		LoadClientVolume(client);
	}
}

public void VolumeSettingsHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	if (g_isaysoundCount == 0)
		return;
	
	if (action == CookieMenuAction_DisplayOption)
	{
		SetGlobalTransTarget(client);
		Format(buffer, maxlen, "%t", "Say sound volume display", g_iPlayerVolume[client]);
	}
	else if (action == CookieMenuAction_SelectOption)
	{
		ShowVolumeMenu(client);
	}
}

void ShowVolumeMenu(int client)
{
	if (g_isaysoundCount == 0)
		return;

	char buf[128], opt[64];
	SetGlobalTransTarget(client);
	Format(buf, sizeof(buf), "%t", "Volume menu title", g_iPlayerVolume[client]);
	Menu menu = new Menu(VolumeMenuHandler);
	menu.SetTitle(buf);
	Format(opt, sizeof(opt), "%t", "Volume increase");
	menu.AddItem("up", opt);
	Format(opt, sizeof(opt), "%t", "Volume decrease");
	menu.AddItem("down", opt);
	Format(opt, sizeof(opt), "%t", "Volume test");
	menu.AddItem("test", opt);
	menu.ExitButton = true;
	menu.Display(client, 20);
}

int VolumeMenuHandler(Menu menu, MenuAction action, int client, int param)
{
	if (action == MenuAction_Select)
	{
		char info[16];
		menu.GetItem(param, info, sizeof(info));

		if (StrEqual(info, "up"))
		{
			g_iPlayerVolume[client] += 10;
			if (g_iPlayerVolume[client] > 100)
				g_iPlayerVolume[client] = 100;

			SaveClientVolume(client);
			ShowVolumeMenu(client);
		}
		else if (StrEqual(info, "down"))
		{
			g_iPlayerVolume[client] -= 10;
			if (g_iPlayerVolume[client] < 0)
				g_iPlayerVolume[client] = 0;

			SaveClientVolume(client);
			ShowVolumeMenu(client);
		}
		else if (StrEqual(info, "test"))
		{
			StopTestSound(client);
			PlayTestSound(client);
			ShowVolumeMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}

	return 0;
}

void SaveClientVolume(int client)
{
	char sCookie[12];
	IntToString(g_iPlayerVolume[client], sCookie, sizeof(sCookie));
	g_hVolumeCookie.Set(client, sCookie);
}

public void Sounds_OnClientCookiesCached(int client)
{
	if (!IsClientInGame(client) || IsFakeClient(client))
		return;
	
	LoadClientVolume(client);
}

void LoadClientVolume(int client)
{
	char sCookie[12];
	g_hVolumeCookie.Get(client, sCookie, sizeof(sCookie));
	
	if (sCookie[0] != '\0')
	{
		int volume = StringToInt(sCookie);
		if (volume >= 0 && volume <= 100)
			g_iPlayerVolume[client] = volume;
		else
			g_iPlayerVolume[client] = g_cvarDefaultVolume;
	}
	else
	{
		g_iPlayerVolume[client] = g_cvarDefaultVolume;
		char sDefault[12];
		IntToString(g_iPlayerVolume[client], sDefault, sizeof(sDefault));
		g_hVolumeCookie.Set(client, sDefault);
	}
}

public void Sounds_OnClientDisconnect(int client)
{
	if (!IsFakeClient(client))
		SaveClientVolume(client);
}

void StopTestSound(int client)
{
	if (!g_isaysoundCount)
		return;
	
	int randomSound = GetRandomInt(0, g_isaysoundCount - 1);
	
	StopSound(client, SNDCHAN_STATIC, g_sSound[randomSound]);
	StopSound(client, SNDCHAN_AUTO, g_sSound[randomSound]);
	StopSound(client, SNDCHAN_VOICE, g_sSound[randomSound]);
	StopSound(client, SNDCHAN_ITEM, g_sSound[randomSound]);
	StopSound(client, SNDCHAN_WEAPON, g_sSound[randomSound]);
}

void PlayTestSound(int client)
{
	if (!g_isaysoundCount)
		return;
	
	int randomSound = GetRandomInt(0, g_isaysoundCount - 1);
	float volume = float(g_iPlayerVolume[client]) / 100.0;
	
	EmitSoundToClient(client, g_sSound[randomSound], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, volume);
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
		return false;
	}

	kv.GetString("trigger", g_sTrigger[g_isaysoundCount], 64);
	g_iCooldown[g_isaysoundCount] = kv.GetNum("cooldown", 30);
	g_iOrigin[g_isaysoundCount] = kv.GetNum("origin", 1);
	g_iItemId[g_isaysoundCount] = itemid;

	kv.GetString("flag", sBuffer, sizeof(sBuffer), "\0");
	g_iFlagBits[g_isaysoundCount] = ReadFlagString(sBuffer);

	kv.GetString("steam", g_sSteam[g_isaysoundCount], 64, "\0");

	if (g_iCooldown[g_isaysoundCount] < 10)
	{
		g_iCooldown[g_isaysoundCount] = 10;
	}

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
			case 1:
			{
				for (int i = 1; i <= MaxClients; i++)
				{
					if (!IsClientInGame(i) || IsFakeClient(i))
						continue;

					if(g_iPlayerVolume[i]!=0)
					{
						float volume = float(g_iPlayerVolume[i]) / 100.0;
						EmitSoundToClient(i, g_sSound[iIndex], SOUND_FROM_WORLD, _, SNDLEVEL_RAIDSIREN, _, volume);
					}
				}
			}
			case 2:
			{
				for (int i = 1; i <= MaxClients; i++)
				{
					if (!IsClientInGame(i) || IsFakeClient(i))
						continue;
						
					if(g_iPlayerVolume[i]!=0)
					{
						float volume = float(g_iPlayerVolume[i]) / 100.0;
						EmitSoundToClient(i, g_sSound[iIndex], client, SOUND_FROM_PLAYER, SNDLEVEL_RAIDSIREN, _, volume);
					}
				}
			}
			case 3:
			{
				float fPos[3], fAgl[3];
				GetClientEyePosition(client, fPos);
				GetClientEyeAngles(client, fAgl);

				fPos[2] -= 3.0;
				
				for (int i = 1; i <= MaxClients; i++)
				{
					if (!IsClientInGame(i) || IsFakeClient(i))
						continue;
						
					if(g_iPlayerVolume[i]!=0)
					{
						float volume = float(g_iPlayerVolume[i]) / 100.0;
						EmitSoundToClient(i, g_sSound[iIndex], client, SNDCHAN_VOICE, SNDLEVEL_NORMAL, SND_NOFLAGS, volume, SNDPITCH_NORMAL, client, fPos, fAgl, true);
					}
				}
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
	
	Store_DisplayPreviousMenu(client);

	return 1;
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

				if (!CheckFlagBits(client, g_iFlagBits[i]) || !CheckSteamAuth(client, g_sSteam[i]))
					return;

				if (Store_HasClientItem(client, g_iItemId[i]))
				{
					switch (g_iOrigin[i])
					{
						case 1:
						{
							for (int z = 1; z <= MaxClients; z++)
							{
								if (!IsClientInGame(z) || IsFakeClient(z))
									continue;

								if(g_iPlayerVolume[z]!=0)
								{
									float volume = float(g_iPlayerVolume[z]) / 100.0;
									EmitSoundToClient(z, g_sSound[i], SOUND_FROM_WORLD, _, SNDLEVEL_RAIDSIREN, _, volume);
								}
							}
						}
						case 2:
						{
							for (int z = 1; z <= MaxClients; z++)
							{
								if (!IsClientInGame(z) || IsFakeClient(z))
									continue;
									
								if(g_iPlayerVolume[z]!=0)
								{
									float volume = float(g_iPlayerVolume[z]) / 100.0;
									EmitSoundToClient(z, g_sSound[i], client, SOUND_FROM_PLAYER, SNDLEVEL_RAIDSIREN, _, volume);
								}
							}
						}
						case 3:
						{
							float fPos[3], fAgl[3];
							GetClientEyePosition(client, fPos);
							GetClientEyeAngles(client, fAgl);

							fPos[2] -= 3.0;
							
							for (int z = 1; z <= MaxClients; z++)
							{
								if (!IsClientInGame(z) || IsFakeClient(z))
									continue;
									
								if(g_iPlayerVolume[z]!=0)
								{
									float volume = float(g_iPlayerVolume[z]) / 100.0;
									EmitSoundToClient(z, g_sSound[i], client, SNDCHAN_VOICE, SNDLEVEL_NORMAL, SND_NOFLAGS, volume, SNDPITCH_NORMAL, client, fPos, fAgl, true);
								}
							}
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

	float volume = float(g_iPlayerVolume[client]) / 100.0;
	EmitSoundToClient(client, g_sSound[index], client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, volume);

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

#else

void Sounds_OnPluginStart() {}
void Sounds_OnClientCookiesCached(int client)
{
	#pragma unused client
}
void Sounds_OnClientPostAdminCheck(int client)
{
	#pragma unused client
}
void Sounds_OnClientDisconnect(int client)
{
	#pragma unused client
}

#endif