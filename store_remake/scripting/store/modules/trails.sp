#if STORE_MODULE_TRAILS

enum struct Trail
{
	char szMaterial[PLATFORM_MAX_PATH];
	char szWidth[16];
	char szColor[16];
	float fWidth;
	int iColor[4];
	int iSlot;
	int iCacheID;
}
Trail g_eTrails[STORE_MAX_ITEMS];

int g_iTrails = 0;
int g_iClientTrails[MAXPLAYERS+1][STORE_MAX_SLOTS];

bool g_bSpawnTrails[MAXPLAYERS+1];

float g_fClientCounters[MAXPLAYERS+1];
float g_fLastPosition[MAXPLAYERS+1][3];

int g_cvarTrailLife = -1;

int g_iTrailOwners[2048]={-1};

bool g_bHideTrail[MAXPLAYERS + 1];
Cookie g_hHideTrailsCookie;

Handle g_hTimerPreviewTrail[MAXPLAYERS + 1];
int g_iPreviewEntityTrail[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

public void Trails_OnPluginStart()
{
	g_cvarTrailLife = RegisterConVar("sm_store_trails_life", "1.0", "Life of a trail in seconds", TYPE_FLOAT);
	
	Store_RegisterHandler("trail", "material", Trails_OnMapStart, Trails_Reset, Trails_Config, Trails_Equip, Trails_Remove, true);
	
	RegConsoleCmd("sm_hidetrail", Command_HideTrail, "Hides the Trails");
	
	HookEvent("player_spawn", Trails_PlayerSpawn);
	HookEvent("player_death", Trails_PlayerDeath);
	HookEvent("player_team", Trails_PlayerTeam);
	
	g_hHideTrailsCookie = new Cookie("Trails_Hide_Cookie", "Cookie to check if Trails are blocked", CookieAccess_Private);
	SetCookieMenuItem(PrefMenu, 0, "");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
			continue;

		Trails_OnClientCookiesCached(i);
	}
}

public void PrefMenu(int client, CookieMenuAction actions, any info, char[] buffer, int maxlen)
{
	if (actions == CookieMenuAction_DisplayOption)
	{
		if (g_bHideTrail[client])
			FormatEx(buffer, maxlen, "[Store] %T", "Show trails", client);
		else
			FormatEx(buffer, maxlen, "[Store] %T", "Hide trails", client);
	}

	if (actions == CookieMenuAction_SelectOption)
	{
		Command_HideTrail(client, 0);
		ShowCookieMenu(client);
	}
}

public void Trails_OnClientCookiesCached(int client)
{
	char sValue[4];
	g_hHideTrailsCookie.Get(client, sValue, sizeof(sValue));

	if (sValue[0] == '\0' || sValue[0] == '0')
		g_bHideTrail[client] = false;
	else
		g_bHideTrail[client] = true;
}

Action Command_HideTrail(int client, int args)
{
	g_bHideTrail[client] = !g_bHideTrail[client];
	if (g_bHideTrail[client])
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Item hidden CM", "trail");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Item hidden", "trail");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Item hidden", "trail");
		#endif
		g_hHideTrailsCookie.Set(client, "1");
	}
	else
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Item visible CM", "trail");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Item visible", "trail");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Item visible", "trail");
		#endif
		g_hHideTrailsCookie.Set(client, "0");
	}

	return Plugin_Handled;
}

public void Trails_OnClientDisconnect(int client)
{
	g_bHideTrail[client] = false;
}

public void Trails_OnMapStart()
{
	for (int i = 0; i < g_iTrails; ++i)
	{
		g_eTrails[i].iCacheID = PrecacheModel(g_eTrails[i].szMaterial, true);
		AddFileToDownloadsTable(g_eTrails[i].szMaterial);
	}
}

public void Trails_Reset()
{
	g_iTrails = 0;
}

public bool Trails_Config(Handle &kv,int itemid)
{
	Store_SetDataIndex(itemid, g_iTrails);
	
	KvGetString(kv, "material", g_eTrails[g_iTrails].szMaterial, PLATFORM_MAX_PATH);
	
	if(!FileExists(g_eTrails[g_iTrails].szMaterial, true))
	{
		LogError("Trail material not found: %s", g_eTrails[g_iTrails].szMaterial);
		return false;
	}
	
	KvGetString(kv, "width", g_eTrails[g_iTrails].szWidth, 16, "10.0");
	g_eTrails[g_iTrails].fWidth = KvGetFloat(kv, "width", 10.0);
	KvGetString(kv, "color", g_eTrails[g_iTrails].szColor, 16, "255 255 255");
	KvGetColor(kv, "color", g_eTrails[g_iTrails].iColor[0], g_eTrails[g_iTrails].iColor[1], g_eTrails[g_iTrails].iColor[2], g_eTrails[g_iTrails].iColor[3]);
	g_eTrails[g_iTrails].iSlot = KvGetNum(kv, "slot");
	
	++g_iTrails;
	return true;
}

public int Trails_Equip(int client,int id)
{
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return -1;
	
	Trails_KillPreview(client);
	CreateTimer(0.0, Timer_CreateTrails, GetClientUserId(client));
	return g_eTrails[Store_GetDataIndex(id)].iSlot;
}

public int Trails_Remove(int client,int id)
{
	Trails_KillPreview(client);
	CreateTimer(0.0, Timer_CreateTrails, GetClientUserId(client));
	return  g_eTrails[Store_GetDataIndex(id)].iSlot;
}

public Action Timer_CreateTrails(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client))
		return Plugin_Stop;
	for(int i=0;i<STORE_MAX_SLOTS;++i)
	{
		RemoveTrail(client, i);
		CreateTrail(client, -1, i);
	}
	return Plugin_Stop;
}

public Action Trails_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return Plugin_Continue;
	
	CreateTimer(0.0, Timer_CreateTrails, GetClientUserId(client));
	
	return Plugin_Continue;
}

public Action Trails_PlayerDeath(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(client && !IsPlayerAlive(client))
		for(int i=0;i<STORE_MAX_SLOTS;++i)
			RemoveTrail(client, i);
	return Plugin_Continue;
}

public void Trails_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!client || !IsClientInGame(client))
		return;
	
	CreateTimer(0.1, Timer_CheckTeamChange, GetClientUserId(client));
}

public Action Timer_CheckTeamChange(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if (!client || !IsClientInGame(client))
		return Plugin_Stop;
	
	int team = GetClientTeam(client);
	if (team < 2 || !IsPlayerAlive(client))
	{
		for(int i = 0; i < STORE_MAX_SLOTS; ++i)
			RemoveTrail(client, i);
	}
	
	return Plugin_Stop;
}

void CreateTrail(int client,int itemid=-1,int slot=0)
{
	if (!IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
		return;

	int equipped = (itemid == -1 ? Store_GetEquippedItem(client, "trail", slot) : itemid);
	if (equipped < 0)
		return;

	int index = Store_GetDataIndex(equipped);
	int ent = CreateEntityByName("env_spritetrail");
	
	if (ent == -1)
	{
		LogError("Failed to create env_spritetrail");
		return;
	}
	
	SetEntPropFloat(ent, Prop_Send, "m_flTextureRes", 0.05);
	
	char szLifetime[16];
	FloatToString(view_as<float>(g_eCvars[g_cvarTrailLife].aCache), szLifetime, sizeof(szLifetime));
	
	DispatchKeyValue(ent, "renderamt", "255");
	
	char szColor[32];
	Format(szColor, sizeof(szColor), "%d %d %d", 
		g_eTrails[index].iColor[0], 
		g_eTrails[index].iColor[1], 
		g_eTrails[index].iColor[2]);
	DispatchKeyValue(ent, "rendercolor", szColor);
	
	DispatchKeyValue(ent, "lifetime", szLifetime);
	DispatchKeyValue(ent, "rendermode", "5");
	DispatchKeyValue(ent, "spritename", g_eTrails[index].szMaterial);
	DispatchKeyValue(ent, "startwidth", g_eTrails[index].szWidth);
	DispatchKeyValue(ent, "endwidth", g_eTrails[index].szWidth);
	DispatchSpawn(ent);
	
	AttachTrail(ent, client, slot);
	g_iClientTrails[client][slot] = ent;
	g_iTrailOwners[ent] = client;
	
	SDKHook(ent, SDKHook_SetTransmit, Hook_TrailSetTransmit);
}

public int RemoveTrail(int client,int slot)
{
	if(g_iClientTrails[client][slot] != 0 && IsValidEdict(g_iClientTrails[client][slot]))
	{
		g_iTrailOwners[g_iClientTrails[client][slot]]=-1;

		char m_szClassname[64];
		GetEdictClassname(g_iClientTrails[client][slot], STRING(m_szClassname));
		if(strcmp("env_spritetrail", m_szClassname)==0)
		{
			SDKUnhook(g_iClientTrails[client][slot], SDKHook_SetTransmit, Hook_TrailSetTransmit);
			AcceptEntityInput(g_iClientTrails[client][slot], "Kill");
		}
	}
	g_iClientTrails[client][slot]=0;
	
	return 0;
}

public void AttachTrail(int ent, int client, int slot)
{
	float m_fOrigin[3];
	GetClientAbsOrigin(client, m_fOrigin);
	m_fOrigin[2] += 5.0;
	
	TeleportEntity(ent, m_fOrigin, NULL_VECTOR, NULL_VECTOR);
	
	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", client, ent);
}

public void Trails_OnGameFrame()
{
	if (GetGameTickCount() % 6 != 0)
		return;	

	float m_fTime = GetEngineTime(), m_fPosition[3];	
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i) || GetClientTeam(i) < 2)
			continue;
		
		GetClientAbsOrigin(i, m_fPosition);
		if (GetVectorDistance(g_fLastPosition[i], m_fPosition) <= 5.0)
		{
			if( !g_bSpawnTrails[i] && m_fTime - g_fClientCounters[i] >= view_as<float>(g_eCvars[g_cvarTrailLife].aCache) / 2)
				g_bSpawnTrails[i] = true;
		}
		else
		{
			if (g_bSpawnTrails[i])
			{
				g_bSpawnTrails[i] = false;
				TE_Start("KillPlayerAttachments");
				TE_WriteNum("m_nPlayer", i);
				TE_SendToAll();
				for (int a = 0; a < STORE_MAX_SLOTS; ++a)
				{
					RemoveTrail(i, a);
					CreateTrail(i, -1, a);
				}
			}
			else g_fClientCounters[i] = m_fTime;
			g_fLastPosition[i] = m_fPosition;
		}
	}
}

public Action Hook_TrailSetTransmit(int ent, int client)
{
	Set_EdictFlagsTrail(ent);

	return g_bHideTrail[client] ? Plugin_Handled : Plugin_Continue;
}

void Set_EdictFlagsTrail(int edict)
{
	if (GetEdictFlags(edict) & FL_EDICT_ALWAYS)
	{
		SetEdictFlags(edict, (GetEdictFlags(edict) ^ FL_EDICT_ALWAYS));
	}
}

public void Trails_OnPreviewItem(int client, char[] type, int index)
{
	if (!StrEqual(type, "trail"))
		return;

	if (g_iPreviewEntityTrail[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iPreviewEntityTrail[client]);
		if (entity > 0 && IsValidEntity(entity))
		{
			AcceptEntityInput(entity, "Kill");
		}
		g_iPreviewEntityTrail[client] = INVALID_ENT_REFERENCE;
	}

	if (g_hTimerPreviewTrail[client] != null)
	{
		delete g_hTimerPreviewTrail[client];
		g_hTimerPreviewTrail[client] = null;
	}

	int iPreview = CreateEntityByName("env_spritetrail");
	if (iPreview == -1)
		return;
	
	SetEntPropFloat(iPreview, Prop_Send, "m_flTextureRes", 0.05);
	
	DispatchKeyValue(iPreview, "renderamt", "255");
	
	char szColor[32];
	Format(szColor, sizeof(szColor), "%d %d %d", 
		g_eTrails[index].iColor[0], 
		g_eTrails[index].iColor[1], 
		g_eTrails[index].iColor[2]);
	DispatchKeyValue(iPreview, "rendercolor", szColor);
	
	DispatchKeyValue(iPreview, "lifetime", "0.5");
	DispatchKeyValue(iPreview, "rendermode", "5");
	DispatchKeyValue(iPreview, "spritename", g_eTrails[index].szMaterial);
	DispatchKeyValue(iPreview, "startwidth", g_eTrails[index].szWidth);
	DispatchKeyValue(iPreview, "endwidth", g_eTrails[index].szWidth);
	DispatchSpawn(iPreview);
	
	float fOrigin[3];
	GetClientAbsOrigin(client, fOrigin);
	fOrigin[2] += 5.0;
	
	TeleportEntity(iPreview, fOrigin, NULL_VECTOR, NULL_VECTOR);
	
	SetVariantString("!activator");
	AcceptEntityInput(iPreview, "SetParent", client, iPreview);
	
	g_iPreviewEntityTrail[client] = EntIndexToEntRef(iPreview);
	
	SDKHook(iPreview, SDKHook_SetTransmit, Hook_SetTransmit_Preview);
	
	g_hTimerPreviewTrail[client] = CreateTimer(45.0, Trails_Timer_KillPreview, client);
	
	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Spawn Preview CM");
		C_PrintToChat(client, "%s %t", g_sChatPrefix, "Spawn Preview");
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix, "Spawn Preview");
	#endif
}

public Action Hook_SetTransmit_Preview(int ent, int client)
{
	if (!IsPlayerAlive(client))
		return Plugin_Handled;
	
	if (g_iPreviewEntityTrail[client] == INVALID_ENT_REFERENCE)
		return Plugin_Handled;
	
	int owner = GetEntPropEnt(ent, Prop_Send, "m_hOwnerEntity");
	if (owner == client)
		return Plugin_Continue;
	
	if (ent == EntRefToEntIndex(g_iPreviewEntityTrail[client]))
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action Trails_Timer_KillPreview(Handle timer, int client)
{
	g_hTimerPreviewTrail[client] = null;

	if (g_iPreviewEntityTrail[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iPreviewEntityTrail[client]);

		if (entity > 0 && IsValidEdict(entity))
		{
			SDKUnhook(entity, SDKHook_SetTransmit, Hook_SetTransmit_Preview);
			AcceptEntityInput(entity, "Kill");
		}
	}
	g_iPreviewEntityTrail[client] = INVALID_ENT_REFERENCE;

	return Plugin_Stop;
}

void Trails_KillPreview(int client)
{
	if (g_iPreviewEntityTrail[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iPreviewEntityTrail[client]);
		if (entity > 0 && IsValidEntity(entity))
		{
			AcceptEntityInput(entity, "Kill");
		}
		g_iPreviewEntityTrail[client] = INVALID_ENT_REFERENCE;
	}

	if (g_hTimerPreviewTrail[client] != null)
	{
		delete g_hTimerPreviewTrail[client];
		g_hTimerPreviewTrail[client] = null;
	}
}

#else
void Trails_OnPluginStart() {}
void Trails_OnClientDisconnect(int client)
{
	#pragma unused client
}
void Trails_OnGameFrame() {}
void Trails_OnClientCookiesCached(int client)
{
	#pragma unused client
}
#endif