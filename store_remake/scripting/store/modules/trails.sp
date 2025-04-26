enum struct TrailData
{
	char szMaterial[PLATFORM_MAX_PATH];
	char szWidth[16];
	char szColor[16];
	float fWidth;
	int iColor[4];
	int iSlot;
	int iCacheID;
}

TrailData g_TrailData[STORE_MAX_ITEMS];
int g_iTrailCount = 0;
int g_cvarTrailLife;
int g_cvarPadding;
int g_cvarMaxColumns;
int g_iClientTrails[MAXPLAYERS + 1][STORE_MAX_SLOTS];
bool g_bSpawnTrails[MAXPLAYERS + 1];
float g_fClientCounters[MAXPLAYERS + 1];
float g_fLastPosition[MAXPLAYERS + 1][3];
int g_iTrailOwners[2048] = { -1 };
public void Trails_OnPluginStart()
{
	g_cvarTrailLife = RegisterConVar("sm_store_trails_life", "1.0", "Life of a trail", TYPE_FLOAT);
	g_cvarPadding = RegisterConVar("sm_store_trails_padding", "30.0", "Space between trails", TYPE_FLOAT);
	g_cvarMaxColumns = RegisterConVar("sm_store_trails_columns", "3", "Columns before stacking trails", TYPE_INT);
	Store_RegisterHandler("trail", "material", Trails_OnMapStart, Trails_Reset, Trails_Config, Trails_Equip, Trails_Remove, true);
	HookEvent("player_spawn", Trails_PlayerSpawn);
}
public void Trails_OnMapStart()
{
	for (int i = 0; i < g_iTrailCount; ++i)
	{
		g_TrailData[i].iCacheID = PrecacheModel(g_TrailData[i].szMaterial, true);
		AddFileToDownloadsTable(g_TrailData[i].szMaterial);
	}
}
public void Trails_Reset()
{
	g_iTrailCount = 0;
}
public bool Trails_Config(KeyValues &kv, int itemid)
{
	if (g_iTrailCount >= STORE_MAX_ITEMS)
	{
		LogError("Trail: Max trail items reached (%d)", STORE_MAX_ITEMS);
		return false;
	}
	int index = g_iTrailCount;
	Store_SetDataIndex(itemid, index);
	bool configValid = true;
	kv.GetString("material", g_TrailData[index].szMaterial, PLATFORM_MAX_PATH);
	if (!FileExists(g_TrailData[index].szMaterial, true))
	{
		LogError("Trail %d: Material file not found '%s'", itemid, g_TrailData[index].szMaterial);
		configValid = false;
	}
	g_TrailData[index].fWidth = kv.GetFloat("width", 10.0);
	FloatToString(g_TrailData[index].fWidth, g_TrailData[index].szWidth, sizeof(TrailData::szWidth));
	kv.GetString("iColor", g_TrailData[index].szColor, sizeof(TrailData::szColor), "255 255 255");
	if (!kv.GetColor("iColor", g_TrailData[index].iColor[0], g_TrailData[index].iColor[1], g_TrailData[index].iColor[2], g_TrailData[index].iColor[3]))
	{
		LogError("Trail %d: Invalid iColor", itemid);
		configValid = false;
	}
	g_TrailData[index].iSlot = kv.GetNum("slot");
	if (configValid)
	{
		++g_iTrailCount;
		return true;
	}
	LogError("Trail %d: Configuration invalid", itemid);
	return false;
}
public int Trails_Equip(int client, int itemid)
{
	if (!IsValidClient(client, true) || GetClientTeam(client) < 2)
		return -1;
	RequestFrame(RequestFrame_CreateTrails, client);
	return g_TrailData[Store_GetDataIndex(itemid)].iSlot;
}
public int Trails_Remove(int client, int itemid)
{
	RemoveTrail(client, g_TrailData[Store_GetDataIndex(itemid)].iSlot);
	return 0;
}
public Action Trails_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) < 2)
		return Plugin_Continue;
	RequestFrame(RequestFrame_CreateTrails, client);
	return Plugin_Continue;
}
public void RequestFrame_CreateTrails(int client)
{
	if (!IsValidClient(client, true))
		return;
	for (int i = 0; i < STORE_MAX_SLOTS; ++i)
	{
		RemoveTrail(client, i);
		CreateTrail(client, -1, i);
	}
}
public void CreateTrail(int client, int itemid, int slot)
{
	int equipped = (itemid == -1 ? Store_GetEquippedItem(client, "trail", slot) : itemid);
	if (equipped < 0)
		return;
	int index = Store_GetDataIndex(equipped);
	int ent = CreateEntityByName("env_spritetrail");
	SetEntPropFloat(ent, Prop_Send, "m_flTextureRes", 0.05);
	char szLifetime[16];
	FloatToString(view_as<float>(g_eCvars[g_cvarTrailLife].aCache), szLifetime, sizeof(szLifetime));
	DispatchKeyValue(ent, "renderamt", "255");
	DispatchKeyValue(ent, "rendercolor", g_TrailData[index].szColor);
	DispatchKeyValue(ent, "lifetime", szLifetime);
	DispatchKeyValue(ent, "rendermode", "5");
	DispatchKeyValue(ent, "spritename", g_TrailData[index].szMaterial);
	DispatchKeyValue(ent, "startwidth", g_TrailData[index].szWidth);
	DispatchKeyValue(ent, "endwidth", g_TrailData[index].szWidth);
	DispatchSpawn(ent);
	AttachTrail(ent, client, slot);
	g_iClientTrails[client][slot] = ent;
	g_iTrailOwners[ent] = client;
}
public void RemoveTrail(int client, int slot)
{
	int ent = g_iClientTrails[client][slot];
	if (ent != 0 && IsValidEntity(ent))
	{
		g_iTrailOwners[ent] = -1;
		char cls[64];
		GetEntityClassname(ent, cls, sizeof(cls));
		if (StrEqual(cls, "env_spritetrail"))
		{
			AcceptEntityInput(ent, "Kill");
		}
	}
	g_iClientTrails[client][slot] = 0;
}
void AttachTrail(int ent, int client, int slot)
{
	float m_fOrigin[3], m_fAngle[3];
	float m_fTemp[3] = { 0.0, 90.0, 0.0 };
	GetEntPropVector(client, Prop_Data, "m_angAbsRotation", m_fAngle);
	SetEntPropVector(client, Prop_Data, "m_angAbsRotation", m_fTemp);
	float m_fX = (view_as<float>(g_eCvars[g_cvarPadding].aCache) * (slot % view_as<int>(g_eCvars[g_cvarMaxColumns].aCache))) / 2;
	float m_fPosition[3];
	m_fPosition[0] = m_fX;
	m_fPosition[1] = 0.0;
	m_fPosition[2] = 5.0 + (slot / view_as<int>(g_eCvars[g_cvarMaxColumns].aCache) * view_as<float>(g_eCvars[g_cvarPadding].aCache));
	GetClientAbsOrigin(client, m_fOrigin);
	AddVectors(m_fOrigin, m_fPosition, m_fOrigin);
	TeleportEntity(ent, m_fOrigin, m_fTemp, NULL_VECTOR);
	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", client, ent);
	SetEntPropVector(client, Prop_Data, "m_angAbsRotation", m_fAngle);
}
public void Trails_OnGameFrame()
{
	if (GetGameTickCount() % 6 != 0)
		return;
	float now = GetEngineTime(), pos[3];
	for (int i = 1; i <= MaxClients; ++i)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;
		GetClientAbsOrigin(i, pos);
		if (GetVectorDistance(g_fLastPosition[i], pos) <= 5.0)
		{
			if (!g_bSpawnTrails[i] && now - g_fClientCounters[i] >= view_as<float>(g_eCvars[g_cvarTrailLife].aCache) / 2)
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
			else g_fClientCounters[i] = now;
			g_fLastPosition[i] = pos;
		}
	}
}
