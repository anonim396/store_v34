#if STORE_MODULE_MISC_BALL

ConVar g_hBallCvarModel;
ConVar g_cvarBallPickupSound;
char g_sBallPickupSound[PLATFORM_MAX_PATH] = "items/itempickup.wav";
int g_iBallExplosionCount = 8;
char g_sBallDefaultModel[PLATFORM_MAX_PATH] = "models/items/cs_gift.mdl";

char g_sBallExplosionSound[PLATFORM_MAX_PATH] = "weapons/hegrenade/explode3.wav";
char g_sBallRewardSound[PLATFORM_MAX_PATH] = "laspegas/item/zaslyjil.wav";
Handle g_hBallVolumeCookie;
int g_iBallClientVolume[MAXPLAYERS + 1];
ConVar g_cvarBallDefaultVolume;
ConVar g_cvarBallExplosionSound;
ConVar g_cvarBallRewardSound;

float g_fBallPos[3];
bool g_bBallSupportedMap;
bool g_bBallOnlyOnceDuringMap;
bool g_bBallPlaySounds;
bool g_bBallPlayEffects;

bool g_bBallPreviewCancelled[MAXPLAYERS + 1];

int g_iBallPositionCredits[MAXPLAYERS+1];

char g_sBallCfgFile[PLATFORM_MAX_PATH];
int g_iBallCurrentPosition;
int g_iBallExplosionSprite;

ArrayList g_hBallSteamArrayRound;
ArrayList g_hBallSteamArrayMap;
KeyValues g_hBallKvCfg;

char g_sBallCurrentMap[34];

int g_iBallPreviewEntity = -1;
bool g_bBallInPreviewMode[MAXPLAYERS+1];
float g_fBallPreviewPos[MAXPLAYERS+1][3];
int g_iBallPreviewColor[4] = {255, 255, 255, 128};

int g_iBallEntity = -1;
int g_iBallRotator = -1;
int g_iBallTrigger = -1;

bool g_bBallMenuNeedsRefresh[MAXPLAYERS+1];
bool g_bBallShowingCreditsMenu[MAXPLAYERS+1];
float g_fBallLastMenuPos[MAXPLAYERS+1][3];
int g_iBallCreditsPosition[MAXPLAYERS+1] = {-1, ...};
bool g_bBallWaitingForCredits[MAXPLAYERS+1];

void Ball_OnPluginStart()
{
	LoadTranslations("store.phrases");

	g_hBallSteamArrayRound = new ArrayList(ByteCountToCells(22));
	g_hBallSteamArrayMap = new ArrayList(ByteCountToCells(22));

	for (int i = 0; i <= MAXPLAYERS; i++)
	{
		g_iBallPositionCredits[i] = 50;
	}

	g_hBallCvarModel = CreateConVar("sm_ball_model", g_sBallDefaultModel, "Model file for the ball");
	g_cvarBallPickupSound = CreateConVar("sm_ball_pickup_sound", "items/itempickup.wav", "Sound when player picks up the ball");
	g_cvarBallExplosionSound = CreateConVar("sm_ball_explosion_sound", "weapons/hegrenade/explode3.wav", "Explosion sound path");
	g_cvarBallRewardSound = CreateConVar("sm_ball_reward_sound", "laspegas/item/zaslyjil.wav", "Reward sound path");
	g_cvarBallDefaultVolume = CreateConVar("sm_ball_default_volume", "100", "Default volume for ball sounds (0-100)", _, true, 0.0, true, 100.0);
	g_hBallVolumeCookie = RegClientCookie("ball_sound_volume", "Gift sound volume", CookieAccess_Protected);

	for (int i = 1; i <= MaxClients; i++)
	{
		g_iBallClientVolume[i] = GetConVarInt(g_cvarBallDefaultVolume);
		if (AreClientCookiesCached(i))
			Ball_LoadClientVolume(i);
	}

	HookEvent("round_start", Ball_Event_RoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_spawn", Ball_Event_PlayerSpawn, EventHookMode_PostNoCopy);

	RegAdminCmd("sm_ball", Ball_Command_Ball, ADMFLAG_ROOT, "Interactive ball position editor");
	RegAdminCmd("sm_ballreload", Ball_Command_Reload, ADMFLAG_ROOT, "Reloads configurations");

	AddCommandListener(Ball_Command_Say, "say");
	AddCommandListener(Ball_Command_Say, "say_team");
	Store_BeginModuleConfig("sourcemod/store", "ball");
	STORE_CFG("sm_ball_model", "models/items/cs_gift.mdl");
	STORE_CFG("sm_ball_pickup_sound", "items/itempickup.wav");
	STORE_CFG("sm_ball_explosion_sound", "weapons/hegrenade/explode3.wav");
	STORE_CFG("sm_ball_reward_sound", "laspegas/item/zaslyjil.wav");
	STORE_CFG("sm_ball_default_volume", "100");
	Store_EndModuleConfig("sourcemod/store", "ball");

	Ball_CreateConfigFile();
	SetCookieMenuItem(Ball_SoundSettingsHandler, 0, "Ball sound settings");
}

void Ball_OnClientPostAdminCheck(int client)
{
	if (IsFakeClient(client))
		return;
	
	if (AreClientCookiesCached(client))
	{
		Ball_LoadClientVolume(client);
	}
}

public void Ball_SoundSettingsHandler(int client, CookieMenuAction action, any info, char[] buffer, int maxlen)
{
	switch(action)
	{
		case CookieMenuAction_DisplayOption:
		{
			SetGlobalTransTarget(client);
			Format(buffer, maxlen, "%t", "Ball volume display", g_iBallClientVolume[client]);
		}
		case CookieMenuAction_SelectOption:
		{
			Ball_ShowSoundMenu(client);
		}
	}
}

void Ball_ShowSoundMenu(int client)
{
	char buf[128], opt[64];
	SetGlobalTransTarget(client);
	Format(buf, sizeof(buf), "%t", "Volume menu title", g_iBallClientVolume[client]);
	Menu menu = new Menu(Ball_SoundMenuHandler);
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

int Ball_SoundMenuHandler(Menu menu, MenuAction action, int client, int param)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[16];
			menu.GetItem(param, info, sizeof(info));

			if (StrEqual(info, "up"))
			{
				g_iBallClientVolume[client] += 10;
				if (g_iBallClientVolume[client] > 100)
					g_iBallClientVolume[client] = 100;

				Ball_SaveClientVolume(client);
				Ball_ShowSoundMenu(client);
			}
			else if (StrEqual(info, "down"))
			{
				g_iBallClientVolume[client] -= 10;
				if (g_iBallClientVolume[client] < 0)
					g_iBallClientVolume[client] = 0;

				Ball_SaveClientVolume(client);
				Ball_ShowSoundMenu(client);
			}
			else if (StrEqual(info, "test"))
			{
				Ball_StopTestSound(client);
				Ball_PlayTestSound(client);
				Ball_ShowSoundMenu(client);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}

	return 0;
}

void Ball_StopTestSound(int client)
{
	g_cvarBallExplosionSound.GetString(g_sBallExplosionSound, sizeof(g_sBallExplosionSound));
	g_cvarBallRewardSound.GetString(g_sBallRewardSound, sizeof(g_sBallRewardSound));
	
	StopSound(client, SNDCHAN_STATIC, g_sBallExplosionSound);
	StopSound(client, SNDCHAN_AUTO, g_sBallExplosionSound);
	StopSound(client, SNDCHAN_VOICE, g_sBallExplosionSound);
	StopSound(client, SNDCHAN_ITEM, g_sBallExplosionSound);
	StopSound(client, SNDCHAN_WEAPON, g_sBallExplosionSound);
	
	StopSound(client, SNDCHAN_STATIC, g_sBallRewardSound);
	StopSound(client, SNDCHAN_AUTO, g_sBallRewardSound);
	StopSound(client, SNDCHAN_VOICE, g_sBallRewardSound);
	StopSound(client, SNDCHAN_ITEM, g_sBallRewardSound);
	StopSound(client, SNDCHAN_WEAPON, g_sBallRewardSound);
}

void Ball_OnClientCookiesCached(int client)
{
	if (!IsClientInGame(client) || IsFakeClient(client))
		return;
	
	Ball_LoadClientVolume(client);
}

void Ball_LoadClientVolume(int client)
{
	char sCookie[12];
	GetClientCookie(client, g_hBallVolumeCookie, sCookie, sizeof(sCookie));
	
	if (sCookie[0] != '\0')
	{
		int volume = StringToInt(sCookie);
		if (volume >= 0 && volume <= 100)
			g_iBallClientVolume[client] = volume;
		else
			g_iBallClientVolume[client] = GetConVarInt(g_cvarBallDefaultVolume);
	}
	else
	{
		g_iBallClientVolume[client] = GetConVarInt(g_cvarBallDefaultVolume);
		char sDefault[12];
		IntToString(g_iBallClientVolume[client], sDefault, sizeof(sDefault));
		SetClientCookie(client, g_hBallVolumeCookie, sDefault);
	}
}

void Ball_SaveClientVolume(int client)
{
	char sCookie[12];
	IntToString(g_iBallClientVolume[client], sCookie, sizeof(sCookie));
	SetClientCookie(client, g_hBallVolumeCookie, sCookie);
}

void Ball_PlayTestSound(int client)
{
	float volume = float(g_iBallClientVolume[client]) / 100.0;
	
	g_cvarBallExplosionSound.GetString(g_sBallExplosionSound, sizeof(g_sBallExplosionSound));
	g_cvarBallRewardSound.GetString(g_sBallRewardSound, sizeof(g_sBallRewardSound));
	
	EmitSoundToClient(client, g_sBallExplosionSound, _, _, _, _, volume);
	EmitSoundToClient(client, g_sBallRewardSound, _, _, _, _, volume);
}

void Ball_CreateConfigFile()
{
	char sPath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/store");
	
	if (!DirExists(sPath))
	{
		CreateDirectory(sPath, 511);
	}
	
	BuildPath(Path_SM, g_sBallCfgFile, sizeof(g_sBallCfgFile), "configs/store/ball.txt");
	
	if (!FileExists(g_sBallCfgFile))
	{
		KeyValues kv = new KeyValues("Ball");
		
		kv.SetNum("once_during_map", 0);
		kv.SetNum("emit_sounds", 1);
		kv.SetNum("emit_effects", 1);
		kv.SetNum("explosion_count", 8);
		kv.SetNum("0", 50);
		
		kv.Rewind();
		
		kv.ExportToFile(g_sBallCfgFile);
		delete kv;
	}
}

void Ball_OnMapStart()
{
	g_cvarBallPickupSound.GetString(g_sBallPickupSound, sizeof(g_sBallPickupSound));
	g_cvarBallExplosionSound.GetString(g_sBallExplosionSound, sizeof(g_sBallExplosionSound));
	g_cvarBallRewardSound.GetString(g_sBallRewardSound, sizeof(g_sBallRewardSound));
	
	PrecacheSound(g_sBallPickupSound, true);
	PrecacheSound(g_sBallExplosionSound, true);
	PrecacheSound(g_sBallRewardSound, true);
	PrecacheModel("models/items/car_battery01.mdl", true);
	g_iBallExplosionSprite = PrecacheModel("materials/sprites/zerogxplode.vmt", true);
	
	GetCurrentMap(g_sBallCurrentMap, sizeof(g_sBallCurrentMap));
	
	g_hBallSteamArrayRound.Clear();
	g_hBallSteamArrayMap.Clear();
	
	Ball_DestroyPreviewEntity();
	
	for (int i = 1; i <= MaxClients; i++)
	{
		g_bBallInPreviewMode[i] = false;
		g_bBallMenuNeedsRefresh[i] = false;
		g_bBallShowingCreditsMenu[i] = false;
		g_iBallCreditsPosition[i] = -1;
		g_bBallWaitingForCredits[i] = false;
		g_bBallPreviewCancelled[i] = false;
	}
	
	Ball_LoadBallConfig();
}

void Ball_OnClientDisconnect(int client)
{
	g_bBallInPreviewMode[client] = false;
	g_bBallMenuNeedsRefresh[client] = false;
	g_bBallShowingCreditsMenu[client] = false;
	g_iBallCreditsPosition[client] = -1;
	g_bBallWaitingForCredits[client] = false;
	g_bBallPreviewCancelled[client] = false;
	if (!IsFakeClient(client))
		Ball_SaveClientVolume(client);
}

void Ball_LoadBallConfig()
{
	if (g_sBallCfgFile[0] == '\0')
	{
		BuildPath(Path_SM, g_sBallCfgFile, sizeof(g_sBallCfgFile), "configs/store/ball.txt");
	}
	
	if (!FileExists(g_sBallCfgFile))
	{
		g_bBallSupportedMap = false;
		return;
	}
	
	if (g_hBallKvCfg != null)
	{
		delete g_hBallKvCfg;
		g_hBallKvCfg = null;
	}
	
	g_hBallKvCfg = new KeyValues("Ball");
	if (!g_hBallKvCfg.ImportFromFile(g_sBallCfgFile))
	{
		g_bBallSupportedMap = false;
		delete g_hBallKvCfg;
		g_hBallKvCfg = null;
		return;
	}
	
	g_bBallOnlyOnceDuringMap = view_as<bool>(g_hBallKvCfg.GetNum("once_during_map", 0));
	g_bBallPlaySounds = view_as<bool>(g_hBallKvCfg.GetNum("emit_sounds", 1));
	g_bBallPlayEffects = view_as<bool>(g_hBallKvCfg.GetNum("emit_effects", 1));
	g_iBallExplosionCount = g_hBallKvCfg.GetNum("explosion_count", 8);
	if (g_iBallExplosionCount < 1) g_iBallExplosionCount = 1;
	if (g_iBallExplosionCount > 16) g_iBallExplosionCount = 16;
	
	for (int i = 0; i <= MAXPLAYERS; i++)
	{
		g_iBallPositionCredits[i] = 50;
	}
	
	g_bBallSupportedMap = g_hBallKvCfg.JumpToKey(g_sBallCurrentMap, false);
	
	if (g_bBallSupportedMap)
	{
		if (g_hBallKvCfg.GetVector("pos", g_fBallPos))
		{
			g_bBallOnlyOnceDuringMap = view_as<bool>(g_hBallKvCfg.GetNum("once_during_map", g_bBallOnlyOnceDuringMap));
			g_bBallPlaySounds = view_as<bool>(g_hBallKvCfg.GetNum("emit_sounds", g_bBallPlaySounds));
			g_bBallPlayEffects = view_as<bool>(g_hBallKvCfg.GetNum("emit_effects", g_bBallPlayEffects));
			g_iBallExplosionCount = g_hBallKvCfg.GetNum("explosion_count", 8);
			if (g_iBallExplosionCount < 1) g_iBallExplosionCount = 1;
			if (g_iBallExplosionCount > 16) g_iBallExplosionCount = 16;
			
			g_iBallPositionCredits[0] = g_hBallKvCfg.GetNum("0", 50);
			
			for (int i = 1; i <= MAXPLAYERS; i++)
			{
				char sPos[12];
				IntToString(i, sPos, sizeof(sPos));
				g_iBallPositionCredits[i] = g_hBallKvCfg.GetNum(sPos, g_iBallPositionCredits[0]);
			}
		}
		else
		{
			g_bBallSupportedMap = false;
		}
	}
	
	g_hBallKvCfg.Rewind();
}

void Ball_OnConfigsExecuted()
{
	char modelPath[PLATFORM_MAX_PATH];
	g_hBallCvarModel.GetString(modelPath, sizeof(modelPath));
	
	if (modelPath[0] == '\0')
	{
		strcopy(modelPath, sizeof(modelPath), g_sBallDefaultModel);
		g_hBallCvarModel.SetString(modelPath);
	}
	
	int dotPos = FindCharInString(modelPath, '.', true);
	if (dotPos == -1 || !StrEqual(modelPath[dotPos], ".mdl", false))
	{
		strcopy(modelPath, sizeof(modelPath), g_sBallDefaultModel);
		g_hBallCvarModel.SetString(modelPath);
	}
	
	PrecacheModel(modelPath, true);
}

public void Ball_Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	CreateTimer(0.0, Ball_Timer_SpawnPlayer, event.GetInt("userid"));
}

public Action Ball_Timer_SpawnPlayer(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client) || IsClientObserver(client))
	{
		return Plugin_Stop;
	}
	
	return Plugin_Continue;
}

void Ball_OnPlayerSpawn(int client)
{
	#pragma unused client
}

public void Ball_Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	if (!g_bBallOnlyOnceDuringMap)
	{
		g_hBallSteamArrayRound.Clear();
	}
	
	g_iBallCurrentPosition = 0;
	
	// Defer spawn to next frame to avoid script timeout (SetEntityModel etc. can block).
	CreateTimer(0.0, Ball_Timer_SpawnBall);
}

public Action Ball_Timer_SpawnBall(Handle timer)
{
	Ball_SpawnBall();
	return Plugin_Stop;
}

public Action Ball_Command_Ball(int client, int argc)
{
	if (!client || !IsClientInGame(client))
	{
		return Plugin_Handled;
	}
	
	Ball_StartPreviewMode(client);
	
	return Plugin_Handled;
}

void Ball_StartPreviewMode(int client)
{
	g_bBallPreviewCancelled[client] = false;
	
	float pos[3];
	if (Ball_GetPlayerEye(client, pos))
	{
		g_bBallInPreviewMode[client] = true;
		g_fBallPreviewPos[client] = pos;
		g_fBallPreviewPos[client][2] += 30.0;
		
		g_fBallPreviewPos[client][0] = float(RoundFloat(g_fBallPreviewPos[client][0]));
		g_fBallPreviewPos[client][1] = float(RoundFloat(g_fBallPreviewPos[client][1]));
		g_fBallPreviewPos[client][2] = float(RoundFloat(g_fBallPreviewPos[client][2]));
		
		Ball_CreatePreviewEntity(pos);
		
		Ball_ShowBallMenu(client);
		g_fBallLastMenuPos[client][0] = pos[0];
		g_fBallLastMenuPos[client][1] = pos[1];
		g_fBallLastMenuPos[client][2] = pos[2];
		
		CreateTimer(0.1, Ball_Timer_UpdatePreview, GetClientUserId(client), TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	}
}

void Ball_ShowBallMenu(int client)
{
	g_bBallShowingCreditsMenu[client] = false;
	char buffer[384];
	char displayText[128];
	Menu menu = new Menu(Ball_BallMenuHandler);
	SetGlobalTransTarget(client);

	int defaultCredits = g_iBallPositionCredits[0];
	float posX = g_fBallPreviewPos[client][0];
	float posY = g_fBallPreviewPos[client][1];
	float posZ = g_fBallPreviewPos[client][2];

	Format(buffer, sizeof(buffer), "%t", "Ball Position Editor Title", posX, posY, posZ, defaultCredits);
	bool ballOnMap = (g_iBallEntity != -1 && IsValidEntity(g_iBallEntity));
	float ballPos[3];
	if (ballOnMap)
		GetEntPropVector(g_iBallEntity, Prop_Send, "m_vecOrigin", ballPos);
	if (ballOnMap)
		Format(displayText, sizeof(displayText), "%t", "Ball on map at", ballPos[0], ballPos[1], ballPos[2]);
	else
		Format(displayText, sizeof(displayText), "%t", "Ball not on map");
	StrCat(buffer, sizeof(buffer), displayText);
	menu.SetTitle(buffer);

	Format(displayText, sizeof(displayText), "%t", "Place Ball Here");
	menu.AddItem("spawn", displayText);

	if (ballOnMap)
	{
		Format(displayText, sizeof(displayText), "%t", "Remove ball from map");
		menu.AddItem("remove", displayText);
	}

	Format(displayText, sizeof(displayText), "%t", "Set Credits Menu");
	menu.AddItem("credits", displayText);

	Format(displayText, sizeof(displayText), "%t", "Reload Config Menu");
	menu.AddItem("reload", displayText);

	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
	g_bBallMenuNeedsRefresh[client] = false;
}

public int Ball_BallMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, "spawn"))
			{
				if (Ball_SaveBallPosition(client, g_fBallPreviewPos[client]))
				{
					Ball_DestroyCurrentBall();
					
					g_fBallPos = g_fBallPreviewPos[client];
					g_bBallSupportedMap = true;
					Ball_SpawnBall();
					
					CreateTimer(0.2, Ball_Timer_RefreshMenu, GetClientUserId(client));
				}
			}
			else if (StrEqual(info, "remove"))
			{
				Ball_DestroyCurrentBall();
				#if defined _clientmod_included
					MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Ball removed from map CM");
					C_PrintToChat(client, "%s %t", g_sChatPrefix, "Ball removed from map");
				#else
					PrintToChat(client, "%s %t", g_sChatPrefix, "Ball removed from map");
				#endif
				CreateTimer(0.2, Ball_Timer_RefreshMenu, GetClientUserId(client));
			}
			else if (StrEqual(info, "credits"))
			{
				g_bBallMenuNeedsRefresh[client] = false;
				Ball_ShowCreditsMenu(client);
				return 0;
			}
			else if (StrEqual(info, "reload"))
			{
				Ball_LoadBallConfig();
				#if defined _clientmod_included
					MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Configuration reloaded CM");
					C_PrintToChat(client, "%s %t", g_sChatPrefix, "Configuration reloaded");
				#else
					PrintToChat(client, "%s %t", g_sChatPrefix, "Configuration reloaded");
				#endif
				
				CreateTimer(0.2, Ball_Timer_RefreshMenu, GetClientUserId(client));
			}
		}
		case MenuAction_Cancel:
		{
			if (param2 == MenuCancel_Exit || param2 == MenuCancel_Timeout)
			{
				Ball_CancelPreviewMode(client);
			}
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}

public Action Ball_Timer_RefreshMenu(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (client && IsClientInGame(client) && g_bBallInPreviewMode[client])
	{
		Ball_ShowBallMenu(client);
	}
	return Plugin_Stop;
}

void Ball_ShowCreditsMenu(int client)
{
	g_bBallShowingCreditsMenu[client] = true;
	char buffer[256];
	char displayText[64];
	Menu menu = new Menu(Ball_CreditsMenuHandler);
	
	Format(buffer, sizeof(buffer), "%t", "Set Credits for Positions Title", g_iBallPositionCredits[0]);
	menu.SetTitle(buffer);
	
	Format(buffer, sizeof(buffer), "%d credits", g_iBallPositionCredits[0]);
	menu.AddItem("0", buffer);
	
	Format(displayText, sizeof(displayText), "%t", "Back");
	menu.AddItem("back", displayText);
	
	menu.ExitButton = false;
	menu.Display(client, MENU_TIME_FOREVER);
}

public int Ball_CreditsMenuHandler(Menu menu, MenuAction action, int client, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if (StrEqual(info, "back"))
			{
				if (g_bBallInPreviewMode[client])
				{
					Ball_ShowBallMenu(client);
				}
				return 0;
			}
			
			g_bBallMenuNeedsRefresh[client] = false;
			int position = StringToInt(info);
			g_iBallCreditsPosition[client] = position;
			if (position == 0)
				Ball_AskForCredits(client, position);
			else if (g_bBallInPreviewMode[client])
				Ball_ShowCreditsMenu(client);
		}
		case MenuAction_End:
		{
			delete menu;
		}
	}
	
	return 0;
}

void Ball_AskForCredits(int client, int position)
{
	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Ball enter credits position", position);
		C_PrintToChat(client, "%s %t", g_sChatPrefix, "Ball enter credits position", position);
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix, "Ball enter credits position", position);
	#endif
	
	g_bBallWaitingForCredits[client] = true;
	g_iBallCreditsPosition[client] = position;
	
	DataPack pack = new DataPack();
	pack.WriteCell(GetClientUserId(client));
	CreateTimer(30.0, Ball_Timer_ClearCreditsRequest, pack);
}

public Action Ball_Command_Say(int client, const char[] command, int argc)
{
	char sArgs[256];
	GetCmdArgString(sArgs, sizeof(sArgs));
	TrimString(sArgs);
	StripQuotes(sArgs);
	Store_RemoveChatTags(sArgs, sizeof(sArgs));
	TrimString(sArgs);
	
	if (!g_bBallWaitingForCredits[client])
		return Plugin_Continue;
	
	if (g_iBallCreditsPosition[client] == -1)
		return Plugin_Continue;
	
	if (g_iBallCreditsPosition[client] != 0)
		return Plugin_Continue;
	
	if (!Ball_String_IsNumeric(sArgs))
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "NumbersOnly CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "NumbersOnly");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "NumbersOnly");
		#endif
		return Plugin_Handled;
	}
	
	int credits = StringToInt(sArgs);
	int position = g_iBallCreditsPosition[client];
	
	Ball_SetPositionCredits(client, position, credits);
	
	if (g_bBallInPreviewMode[client])
	{
		Ball_ShowCreditsMenu(client);
	}
	
	g_iBallCreditsPosition[client] = -1;
	g_bBallWaitingForCredits[client] = false;
	
	return Plugin_Handled;
}

public Action Ball_Timer_ClearCreditsRequest(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	delete pack;
	
	if (client && IsClientInGame(client))
	{
		if (g_bBallWaitingForCredits[client])
		{
			g_iBallCreditsPosition[client] = -1;
			g_bBallWaitingForCredits[client] = false;
			
			if (g_bBallInPreviewMode[client])
			{
				Ball_ShowCreditsMenu(client);
			}
		}
	}
	
	return Plugin_Stop;
}

void Ball_SetPositionCredits(int client, int position, int credits)
{
	if (g_hBallKvCfg == null)
	{
		Ball_LoadBallConfig();
		if (g_hBallKvCfg == null)
		{
			return;
		}
	}
	
	if (!g_hBallKvCfg.JumpToKey(g_sBallCurrentMap, true))
	{
		return;
	}
	
	char sPos[12];
	IntToString(position, sPos, sizeof(sPos));
	
	g_hBallKvCfg.SetNum(sPos, credits);
	
	g_iBallPositionCredits[position] = credits;
	
	if (position == 0)
	{
		for (int i = 1; i <= MAXPLAYERS; i++)
		{
			char sOtherPos[12];
			IntToString(i, sOtherPos, sizeof(sOtherPos));
			
			if (g_hBallKvCfg.GetNum(sOtherPos, -1) == -1)
			{
				g_iBallPositionCredits[i] = credits;
			}
		}
	}
	
	g_hBallKvCfg.Rewind();
	
	if (g_hBallKvCfg.ExportToFile(g_sBallCfgFile))
	{
		Ball_LoadBallConfig();
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credits saved CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Credits saved");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Credits saved");
		#endif
	}
}

void Ball_CancelPreviewMode(int client)
{
	if (g_bBallPreviewCancelled[client])
		return;
		
	g_bBallPreviewCancelled[client] = true;
	g_bBallInPreviewMode[client] = false;
	g_bBallMenuNeedsRefresh[client] = false;
	g_iBallCreditsPosition[client] = -1;
	g_bBallWaitingForCredits[client] = false;
	Ball_DestroyPreviewEntity();
}

void Ball_CreatePreviewEntity(float pos[3])
{
	Ball_DestroyPreviewEntity();
	
	char modelPath[PLATFORM_MAX_PATH];
	g_hBallCvarModel.GetString(modelPath, sizeof(modelPath));
	
	int ent = CreateEntityByName("prop_dynamic");
	if (ent == -1)
		return;
	
	SetEntityModel(ent, modelPath);
	
	SetEntityRenderMode(ent, RENDER_TRANSCOLOR);
	SetEntityRenderColor(ent, g_iBallPreviewColor[0], g_iBallPreviewColor[1], g_iBallPreviewColor[2], g_iBallPreviewColor[3]);
	
	SetEntProp(ent, Prop_Send, "m_nSolidType", 0);
	SetEntProp(ent, Prop_Send, "m_usSolidFlags", 4);
	SetEntProp(ent, Prop_Send, "m_CollisionGroup", 1);
	
	DispatchSpawn(ent);
	TeleportEntity(ent, pos, NULL_VECTOR, NULL_VECTOR);
	
	g_iBallPreviewEntity = ent;
}

public Action Ball_Timer_UpdatePreview(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	
	if (!client || !IsClientInGame(client) || !g_bBallInPreviewMode[client] || 
		g_bBallPreviewCancelled[client] || g_iBallPreviewEntity == -1 || !IsValidEntity(g_iBallPreviewEntity))
	{
		return Plugin_Stop;
	}
	
	float pos[3];
	if (Ball_GetPlayerEye(client, pos))
	{
		pos[2] += 30.0;
		
		pos[0] = float(RoundFloat(pos[0]));
		pos[1] = float(RoundFloat(pos[1]));
		pos[2] = float(RoundFloat(pos[2]));
		
		TeleportEntity(g_iBallPreviewEntity, pos, NULL_VECTOR, NULL_VECTOR);
		
		g_fBallPreviewPos[client] = pos;
		
		if (g_fBallLastMenuPos[client][0] != pos[0] || g_fBallLastMenuPos[client][1] != pos[1] || g_fBallLastMenuPos[client][2] != pos[2])
		{
			g_fBallLastMenuPos[client][0] = pos[0];
			g_fBallLastMenuPos[client][1] = pos[1];
			g_fBallLastMenuPos[client][2] = pos[2];
			if (g_bBallShowingCreditsMenu[client])
				Ball_ShowCreditsMenu(client);
			else
				Ball_ShowBallMenu(client);
		}
		
		return Plugin_Continue;
	}
	
	return Plugin_Stop;
}

void Ball_DestroyPreviewEntity()
{
	if (g_iBallPreviewEntity != -1 && IsValidEntity(g_iBallPreviewEntity))
	{
		RemoveEntity(g_iBallPreviewEntity);
		g_iBallPreviewEntity = -1;
	}
}

bool Ball_SaveBallPosition(int client, float pos[3])
{
	if (g_hBallKvCfg == null)
	{
		Ball_LoadBallConfig();
		if (g_hBallKvCfg == null)
		{
			return false;
		}
	}
	
	g_hBallKvCfg.JumpToKey(g_sBallCurrentMap, true);
	g_hBallKvCfg.SetVector("pos", pos);
	g_hBallKvCfg.Rewind();
	
	if (g_hBallKvCfg.ExportToFile(g_sBallCfgFile))
	{
		g_fBallPos = pos;
		g_bBallSupportedMap = true;
		
		int roundedX = RoundFloat(pos[0]);
		int roundedY = RoundFloat(pos[1]);
		int roundedZ = RoundFloat(pos[2]);
		
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Position saved CM", roundedX, roundedY, roundedZ);
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Position saved", roundedX, roundedY, roundedZ);
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Position saved", roundedX, roundedY, roundedZ);
		#endif
		
		return true;
	}
	else
	{
		return false;
	}
}

public Action Ball_Command_Reload(int client, int argc)
{
	Ball_LoadBallConfig();
	ReplyToCommand(client, "Configuration reloaded!");
	return Plugin_Handled;
}

void Ball_DestroyCurrentBall()
{
	if (g_iBallEntity != -1 && IsValidEntity(g_iBallEntity))
	{
		RemoveEntity(g_iBallEntity);
		g_iBallEntity = -1;
	}
	
	if (g_iBallRotator != -1 && IsValidEntity(g_iBallRotator))
	{
		RemoveEntity(g_iBallRotator);
		g_iBallRotator = -1;
	}
	
	if (g_iBallTrigger != -1 && IsValidEntity(g_iBallTrigger))
	{
		UnhookSingleEntityOutput(g_iBallTrigger, "OnStartTouch", Ball_OnStartTouch);
		RemoveEntity(g_iBallTrigger);
		g_iBallTrigger = -1;
	}
}

void Ball_SpawnBall()
{
	if (!g_bBallSupportedMap)
		return;
	
	Ball_DestroyCurrentBall();
	
	g_iBallEntity = CreateEntityByName("prop_physics_override");
	if (g_iBallEntity == -1)
		return;
	
	char modelPath[PLATFORM_MAX_PATH];
	g_hBallCvarModel.GetString(modelPath, sizeof(modelPath));
	
	char tmp[64];
	FormatEx(tmp, sizeof(tmp), "gift_%i", g_iBallEntity);
	
	DispatchKeyValue(g_iBallEntity, "model", modelPath);
	DispatchKeyValue(g_iBallEntity, "physicsmode", "2");
	DispatchKeyValue(g_iBallEntity, "massScale", "1.0");
	DispatchKeyValue(g_iBallEntity, "targetname", tmp);
	DispatchSpawn(g_iBallEntity);
	
	SetEntProp(g_iBallEntity, Prop_Send, "m_usSolidFlags", 8);
	SetEntProp(g_iBallEntity, Prop_Send, "m_CollisionGroup", 1);
	
	TeleportEntity(g_iBallEntity, g_fBallPos, NULL_VECTOR, NULL_VECTOR);
	
	g_iBallRotator = CreateEntityByName("func_rotating");
	if (g_iBallRotator == -1)
	{
		RemoveEntity(g_iBallEntity);
		g_iBallEntity = -1;
		return;
	}
	
	FormatEx(tmp, sizeof(tmp), "gift_rot_%i", g_iBallRotator);
	DispatchKeyValueVector(g_iBallRotator, "origin", g_fBallPos);
	DispatchKeyValue(g_iBallRotator, "targetname", tmp);
	DispatchKeyValue(g_iBallRotator, "maxspeed", "200");
	DispatchKeyValue(g_iBallRotator, "friction", "0");
	DispatchKeyValue(g_iBallRotator, "dmg", "0");
	DispatchKeyValue(g_iBallRotator, "solid", "0");
	DispatchKeyValue(g_iBallRotator, "spawnflags", "64");
	DispatchSpawn(g_iBallRotator);
	
	Format(tmp, sizeof(tmp), "%s,Kill,,0,-1", tmp);
	DispatchKeyValue(g_iBallEntity, "OnKilled", tmp);
	
	SetVariantString("!activator");
	AcceptEntityInput(g_iBallEntity, "SetParent", g_iBallRotator, g_iBallRotator);
	
	g_iBallTrigger = CreateEntityByName("trigger_multiple");
	if (g_iBallTrigger == -1)
	{
		RemoveEntity(g_iBallEntity);
		RemoveEntity(g_iBallRotator);
		g_iBallEntity = -1;
		g_iBallRotator = -1;
		return;
	}
	
	FormatEx(tmp, sizeof(tmp), "gift_trigger_%i", g_iBallTrigger);
	DispatchKeyValueVector(g_iBallTrigger, "origin", g_fBallPos);
	DispatchKeyValue(g_iBallTrigger, "targetname", tmp);
	DispatchKeyValue(g_iBallTrigger, "wait", "0");
	DispatchKeyValue(g_iBallTrigger, "spawnflags", "64");
	DispatchSpawn(g_iBallTrigger);
	
	Format(tmp, sizeof(tmp), "%s,Kill,,0,-1", tmp);
	DispatchKeyValue(g_iBallRotator, "OnKilled", tmp);
	
	ActivateEntity(g_iBallTrigger);
	SetEntProp(g_iBallTrigger, Prop_Data, "m_spawnflags", 64);
	SetEntityModel(g_iBallTrigger, "models/items/car_battery01.mdl");
	
	float fMins[3], fMaxs[3];
	GetEntPropVector(g_iBallEntity, Prop_Send, "m_vecMins", fMins);
	GetEntPropVector(g_iBallEntity, Prop_Send, "m_vecMaxs", fMaxs);
	
	SetEntPropVector(g_iBallTrigger, Prop_Send, "m_vecMins", fMins);
	SetEntPropVector(g_iBallTrigger, Prop_Send, "m_vecMaxs", fMaxs);
	SetEntProp(g_iBallTrigger, Prop_Send, "m_nSolidType", 2);
	
	int iEffects = GetEntProp(g_iBallTrigger, Prop_Send, "m_fEffects");
	iEffects |= 32;
	SetEntProp(g_iBallTrigger, Prop_Send, "m_fEffects", iEffects);
	
	SetVariantString("!activator");
	AcceptEntityInput(g_iBallTrigger, "SetParent", g_iBallRotator, g_iBallRotator);
	AcceptEntityInput(g_iBallRotator, "Start");
	
	HookSingleEntityOutput(g_iBallTrigger, "OnStartTouch", Ball_OnStartTouch);
}

public void Ball_OnStartTouch(const char[] output, int caller, int activator, float delay)
{
	if (activator < 1 || activator > MaxClients)
	{
		return;
	}
	
	char auth[22];
	GetClientAuthId(activator, AuthId_Steam2, auth, sizeof(auth), false);
	
	if (g_bBallOnlyOnceDuringMap)
	{
		if (g_hBallSteamArrayMap.FindString(auth) != -1)
		{
			return;
		}
		g_hBallSteamArrayMap.PushString(auth);
	}
	else
	{
		if (g_hBallSteamArrayRound.FindString(auth) != -1)
		{
			return;
		}
		g_hBallSteamArrayRound.PushString(auth);
	}
	
	g_iBallCurrentPosition++;
	
	if (g_iBallCurrentPosition > MAXPLAYERS)
	{
		g_iBallCurrentPosition = MAXPLAYERS;
	}
	
	int credits = g_iBallPositionCredits[g_iBallCurrentPosition];
	
	if (credits < 1)
	{
		return;
	}
	
	float pos_ent[3];
	pos_ent = g_fBallPos;
	
	int currentCredits = Store_GetClientCredits(activator);
	int newCredits = currentCredits + credits;
	Store_SetClientCredits(activator, newCredits);
	
	g_cvarBallPickupSound.GetString(g_sBallPickupSound, sizeof(g_sBallPickupSound));
	EmitSoundToAll(g_sBallPickupSound, activator);
	
	if (g_bBallPlayEffects)
	{
		Ball_CreateExplosionEffects(pos_ent);
	}
	
	if (g_bBallPlaySounds)
	{
		g_cvarBallExplosionSound.GetString(g_sBallExplosionSound, sizeof(g_sBallExplosionSound));
		g_cvarBallRewardSound.GetString(g_sBallRewardSound, sizeof(g_sBallRewardSound));
		
		EmitAmbientSound(g_sBallExplosionSound, pos_ent, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
		EmitAmbientSound(g_sBallRewardSound, pos_ent, SOUND_FROM_WORLD, SNDLEVEL_NORMAL, SND_NOFLAGS, 1.0, 100);
	}
	
	#if defined _clientmod_included
		MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "PlayerFinished CM", activator, credits, g_sCreditsName);
		C_PrintToChatAll("%s %t", g_sChatPrefix, "PlayerFinished", activator, credits, g_sCreditsName);
	#else
		PrintToChatAll("%s %t", g_sChatPrefix, "PlayerFinished", activator, credits, g_sCreditsName);
	#endif
}

void Ball_CreateExplosionEffects(float pos[3])
{
	float work[3];
	work[0] = pos[0]; work[1] = pos[1]; work[2] = pos[2];
	
	static const float offsets[8][3] = {
		{ 150.0, 0.0, 0.0 }, { -150.0, 0.0, 0.0 },
		{ 0.0, 150.0, 0.0 }, { 0.0, -150.0, 0.0 },
		{ 150.0, 150.0, 0.0 }, { -150.0, -150.0, 0.0 },
		{ 150.0, -150.0, 0.0 }, { -150.0, 150.0, 0.0 }
	};
	static const float delays[8] = { 0.0, 0.0, 1.0, 1.0, 2.0, 2.0, 2.0, 2.0 };
	
	int n = (g_iBallExplosionCount > 8) ? 8 : g_iBallExplosionCount;
	for (int i = 0; i < n; i++)
	{
		work[0] = pos[0] + offsets[i][0];
		work[1] = pos[1] + offsets[i][1];
		work[2] = pos[2] + offsets[i][2];
		TE_SetupExplosion(work, g_iBallExplosionSprite, 10.0, 1, 0, 275, 160);
		TE_SendToAll(delays[i]);
	}
}

bool Ball_GetPlayerEye(int client, float pos[3])
{
	float vAngles[3], vOrigin[3];

	GetClientEyePosition(client, vOrigin);
	GetClientEyeAngles(client, vAngles);

	Handle trace = TR_TraceRayFilterEx(vOrigin, vAngles, MASK_SOLID, RayType_Infinite, TraceEntityFilterPlayers);

	if (TR_DidHit(trace))
	{
		TR_GetEndPosition(pos, trace);
		delete trace;
		return true;
	}

	delete trace;
	return false;
}

public bool TraceEntityFilterPlayers(int entity, int contentsMask)
{
	return (!(0 < entity <= MaxClients));
}

bool Ball_String_IsNumeric(const char[] str)
{	
	int x = 0;
	int numbersFound = 0;

	if (str[x] == '+' || str[x] == '-')
		x++;

	while (str[x] != '\0')
	{
		if (IsCharNumeric(str[x]))
			numbersFound++;
		else
			return false;
		x++;
	}
	
	return (numbersFound > 0);
}

#else
void Ball_OnPluginStart() {}
void Ball_OnMapStart() {}
void Ball_OnConfigsExecuted() {}
void Ball_OnClientDisconnect(int client)
{
	#pragma unused client
}
void Ball_OnClientPostAdminCheck(int client)
{
	#pragma unused client
}
void Ball_OnClientCookiesCached(int client)
{
	#pragma unused client
}
void Ball_OnPlayerSpawn(int client)
{
	#pragma unused client
}
#endif