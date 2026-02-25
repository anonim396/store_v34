#if STORE_MODULE_GRENTRAILS
enum struct GrenadeTrail
{
	char szMaterial[PLATFORM_MAX_PATH];
	char szWidth[16];
	char szColor[16];
	float fWidth;
	int iColor[4];
	int iSlot;
	int iCacheID;
}

GrenadeTrail g_eGrenadeTrails[STORE_MAX_ITEMS];
int g_iGrenadeTrails = 0;
int g_iGrenadeTrailPreviewEnt[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...};
Handle g_hGrenadeTrailPreviewTimer[MAXPLAYERS+1];

public void GrenadeTrails_OnPluginStart()
{
	if (GetExtensionFileStatus("sdkhooks.ext") != 1)
	{
		LogError("SDKHooks isn't installed or failed to load. Grenade Trails will be disabled. Please install SDKHooks. (https://forums.alliedmods.net/showthread.php?t=106748)");
		return;
	}
	Store_RegisterHandler("grenadetrail", "material", GrenadeTrails_OnMapStart, GrenadeTrails_Reset, GrenadeTrails_Config, GrenadeTrails_Equip, GrenadeTrails_Remove, true);
}

public void GrenadeTrails_OnMapStart()
{
	for (int i = 0; i < g_iGrenadeTrails; ++i)
	{
		g_eGrenadeTrails[i].iCacheID = PrecacheModel(g_eGrenadeTrails[i].szMaterial, true);
		AddFileToDownloadsTable(g_eGrenadeTrails[i].szMaterial);
	}
}

public void GrenadeTrails_Reset()
{
	g_iGrenadeTrails = 0;
}

public bool GrenadeTrails_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iGrenadeTrails);
	KvGetString(kv, "material", g_eGrenadeTrails[g_iGrenadeTrails].szMaterial, PLATFORM_MAX_PATH);
	KvGetString(kv, "width", g_eGrenadeTrails[g_iGrenadeTrails].szWidth, 16, "10.0");
	g_eGrenadeTrails[g_iGrenadeTrails].fWidth = KvGetFloat(kv, "width", 10.0);
	KvGetString(kv, "color", g_eGrenadeTrails[g_iGrenadeTrails].szColor, 16, "255 255 255 255");
	KvGetColor(kv, "color", g_eGrenadeTrails[g_iGrenadeTrails].iColor[0], g_eGrenadeTrails[g_iGrenadeTrails].iColor[1], g_eGrenadeTrails[g_iGrenadeTrails].iColor[2], g_eGrenadeTrails[g_iGrenadeTrails].iColor[3]);
	g_eGrenadeTrails[g_iGrenadeTrails].iSlot = KvGetNum(kv, "slot");
	
	if (FileExists(g_eGrenadeTrails[g_iGrenadeTrails].szMaterial, true))
	{
		++g_iGrenadeTrails;
		return true;
	}
	return false;
}

public int GrenadeTrails_Equip(int client, int id)
{
	return 0;
}

public int GrenadeTrails_Remove(int client, int id)
{
	return 0;
}

public void GrenadeTrails_OnEntityCreated(int entity, const char[] classname)
{
	if (g_iGrenadeTrails == 0)
		return;
	
	if (StrContains(classname, "_projectile") > 0)
		SDKHook(entity, SDKHook_SpawnPost, GrenadeTrails_OnEntitySpawnedPost);
}

public void GrenadeTrails_OnEntitySpawnedPost(int entity)
{
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	if (!(0 < client && client <= MaxClients))
		return;
	
	int m_iEquipped = Store_GetEquippedItem(client, "grenadetrail", 0);
	
	if (m_iEquipped < 0)
		return;
	
	int m_iData = Store_GetDataIndex(m_iEquipped);
	
	int m_iColor[4];
	m_iColor = g_eGrenadeTrails[m_iData].iColor;
	
	TE_SetupBeamFollow(entity, g_eGrenadeTrails[m_iData].iCacheID, 0, 2.0, 
		g_eGrenadeTrails[m_iData].fWidth, g_eGrenadeTrails[m_iData].fWidth, 10, m_iColor);
	TE_SendToAll();
}

public void GrenadeTrails_OnPreviewItem(int client, const char[] type, int index)
{
	if (!StrEqual(type, "grenadetrail") || index < 0 || index >= g_iGrenadeTrails)
		return;
	if (g_iGrenadeTrailPreviewEnt[client] != INVALID_ENT_REFERENCE)
	{
		int ent = EntRefToEntIndex(g_iGrenadeTrailPreviewEnt[client]);
		if (ent > 0 && IsValidEntity(ent))
			AcceptEntityInput(ent, "Kill");
		g_iGrenadeTrailPreviewEnt[client] = INVALID_ENT_REFERENCE;
	}
	if (g_hGrenadeTrailPreviewTimer[client] != null)
	{
		delete g_hGrenadeTrailPreviewTimer[client];
		g_hGrenadeTrailPreviewTimer[client] = null;
	}
	int iPreview = CreateEntityByName("env_spritetrail");
	if (iPreview == -1)
		return;
	SetEntPropFloat(iPreview, Prop_Send, "m_flTextureRes", 0.05);
	DispatchKeyValue(iPreview, "renderamt", "255");
	char szColor[32];
	Format(szColor, sizeof(szColor), "%d %d %d", g_eGrenadeTrails[index].iColor[0], g_eGrenadeTrails[index].iColor[1], g_eGrenadeTrails[index].iColor[2]);
	DispatchKeyValue(iPreview, "rendercolor", szColor);
	DispatchKeyValue(iPreview, "lifetime", "0.5");
	DispatchKeyValue(iPreview, "rendermode", "5");
	DispatchKeyValue(iPreview, "spritename", g_eGrenadeTrails[index].szMaterial);
	DispatchKeyValue(iPreview, "startwidth", g_eGrenadeTrails[index].szWidth);
	DispatchKeyValue(iPreview, "endwidth", g_eGrenadeTrails[index].szWidth);
	DispatchSpawn(iPreview);
	float fOrigin[3];
	GetClientAbsOrigin(client, fOrigin);
	fOrigin[2] += 5.0;
	TeleportEntity(iPreview, fOrigin, NULL_VECTOR, NULL_VECTOR);
	SetVariantString("!activator");
	AcceptEntityInput(iPreview, "SetParent", client, iPreview);
	g_iGrenadeTrailPreviewEnt[client] = EntIndexToEntRef(iPreview);
	SDKHook(iPreview, SDKHook_SetTransmit, GrenadeTrails_Preview_SetTransmit);
	g_hGrenadeTrailPreviewTimer[client] = CreateTimer(45.0, GrenadeTrails_Timer_KillPreview, client);
	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Spawn Preview CM");
		C_PrintToChat(client, "%s %t", g_sChatPrefix, "Spawn Preview");
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix, "Spawn Preview");
	#endif
}

public Action GrenadeTrails_Preview_SetTransmit(int ent, int client)
{
	if (!IsPlayerAlive(client))
		return Plugin_Handled;
	if (g_iGrenadeTrailPreviewEnt[client] == INVALID_ENT_REFERENCE)
		return Plugin_Handled;
	if (ent == EntRefToEntIndex(g_iGrenadeTrailPreviewEnt[client]))
		return Plugin_Continue;
	return Plugin_Handled;
}

public Action GrenadeTrails_Timer_KillPreview(Handle timer, int client)
{
	g_hGrenadeTrailPreviewTimer[client] = null;
	if (g_iGrenadeTrailPreviewEnt[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iGrenadeTrailPreviewEnt[client]);
		if (entity > 0 && IsValidEntity(entity))
		{
			SDKUnhook(entity, SDKHook_SetTransmit, GrenadeTrails_Preview_SetTransmit);
			AcceptEntityInput(entity, "Kill");
		}
		g_iGrenadeTrailPreviewEnt[client] = INVALID_ENT_REFERENCE;
	}
	return Plugin_Stop;
}

public void GrenadeTrails_OnClientDisconnect(int client)
{
	if (g_hGrenadeTrailPreviewTimer[client] != null)
	{
		delete g_hGrenadeTrailPreviewTimer[client];
		g_hGrenadeTrailPreviewTimer[client] = null;
	}
	if (g_iGrenadeTrailPreviewEnt[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iGrenadeTrailPreviewEnt[client]);
		if (entity > 0 && IsValidEntity(entity))
			AcceptEntityInput(entity, "Kill");
		g_iGrenadeTrailPreviewEnt[client] = INVALID_ENT_REFERENCE;
	}
}

#else

void GrenadeTrails_OnPluginStart() {}
void GrenadeTrails_OnClientDisconnect(int client)
{
	#pragma unused client
}
void GrenadeTrails_OnEntityCreated(int entity, const char[] classname)
{
	#pragma unused entity
	#pragma unused classname
}

#endif