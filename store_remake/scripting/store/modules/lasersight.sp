#if STORE_MODULE_LASERSIGHT
int g_cvarLaserSightMaterial;
int g_cvarLaserDotMaterial;

int g_aLaserColors[STORE_MAX_ITEMS][4];

int g_iLaserColors = 0;
int g_iLaserBeam = -1;
int g_iLaserDot = -1;

bool g_bLaserPreview[MAXPLAYERS+1];
int g_iLaserPreviewIndex[MAXPLAYERS+1];
Handle g_hLaserPreviewTimer[MAXPLAYERS+1];

StringMap g_hSnipers;

public void LaserSight_OnPluginStart()
{
	g_cvarLaserSightMaterial = RegisterConVar("sm_store_lasersight_material", "materials/sprites/laserbeam.vmt", "Material to be used with laser sights", TYPE_STRING);
	g_cvarLaserDotMaterial = RegisterConVar("sm_store_lasersight_dot_material", "materials/sprites/redglow1.vmt", "Material to be used with the dot of the laser sights", TYPE_STRING);
	
	Store_RegisterHandler("lasersight", "color", LaserSight_OnMapStart, LaserSight_Reset, LaserSight_Config, LaserSight_Equip, LaserSight_Remove, true);

	g_hSnipers = new StringMap();
	g_hSnipers.SetValue("awp", 1);
	g_hSnipers.SetValue("scout", 1);
	g_hSnipers.SetValue("sg550", 1);
	g_hSnipers.SetValue("sg552", 1);
	g_hSnipers.SetValue("sg556", 1);
	g_hSnipers.SetValue("g3sg1", 1);
	g_hSnipers.SetValue("aug", 1);
	g_hSnipers.SetValue("scar17", 1);
	g_hSnipers.SetValue("scar20", 1);
	g_hSnipers.SetValue("ssg08", 1);
	g_hSnipers.SetValue("spring", 1);
	g_hSnipers.SetValue("k98s", 1);
}

public void LaserSight_OnMapStart()
{
	g_iLaserBeam = PrecacheModel(g_eCvars[g_cvarLaserSightMaterial].sCache, true);
	g_iLaserDot = PrecacheModel(g_eCvars[g_cvarLaserDotMaterial].sCache, true);
}

public void LaserSight_Reset()
{
	g_iLaserColors = 0;
}

public bool LaserSight_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iLaserColors);
	
	kv.GetColor("color", g_aLaserColors[g_iLaserColors][0], g_aLaserColors[g_iLaserColors][1], g_aLaserColors[g_iLaserColors][2], g_aLaserColors[g_iLaserColors][3]);
	if(g_aLaserColors[g_iLaserColors][3] == 0)
		g_aLaserColors[g_iLaserColors][3] = 255;
	
	++g_iLaserColors;
	
	return true;
}

public int LaserSight_Equip(int client, int id)
{
	return -1;
}

public void LaserSight_Remove(int client, int id)
{
}

public void LaserSight_OnPlayerRunCmd(int client)
{
	float m_fOrigin[3];
	float m_fImpact[3];
	int m_iData;
	int list[1];
	list[0] = client;

	if (g_bLaserPreview[client])
	{
		GetClientEyePosition(client, m_fOrigin);
		GetClientSightEnd(client, m_fImpact);
		m_iData = g_iLaserPreviewIndex[client];
		if (m_iData >= 0 && m_iData < g_iLaserColors)
		{
			TE_SetupBeamPoints(m_fOrigin, m_fImpact, g_iLaserBeam, 0, 0, 0, 0.1, 0.12, 0.0, 1, 0.0, g_aLaserColors[m_iData], 0);
			TE_Send(list, 1, 0.0);
			TE_SetupGlowSprite(m_fImpact, g_iLaserDot, 0.1, 0.25, g_aLaserColors[m_iData][3]);
			TE_Send(list, 1, 0.0);
		}
		return;
	}

	int m_iEquipped = Store_GetEquippedItem(client, "lasersight");
	if(m_iEquipped < 0)
		return;

	int m_unFOV = GetEntProp(client, Prop_Data, "m_iFOV");
	if(m_unFOV == 0 || m_unFOV == 90)
		return;

	char m_szWeapon[64];
	GetClientWeapon(client, m_szWeapon, sizeof(m_szWeapon));

	int m_iTmp;
	if(!g_hSnipers.GetValue(m_szWeapon[7], m_iTmp))
		return;

	GetClientEyePosition(client, m_fOrigin);
	GetClientSightEnd(client, m_fImpact);
	m_iData = Store_GetDataIndex(m_iEquipped);

	TE_SetupBeamPoints(m_fOrigin, m_fImpact, g_iLaserBeam, 0, 0, 0, 0.1, 0.12, 0.0, 1, 0.0, g_aLaserColors[m_iData], 0);
	TE_SendToAll();

	TE_SetupGlowSprite(m_fImpact, g_iLaserDot, 0.1, 0.25, g_aLaserColors[m_iData][3]);
	TE_SendToAll();
}

public void LaserSight_OnPreviewItem(int client, const char[] type, int index)
{
	if (!StrEqual(type, "lasersight") || index < 0 || index >= g_iLaserColors)
		return;
	if (g_hLaserPreviewTimer[client] != null)
	{
		delete g_hLaserPreviewTimer[client];
		g_hLaserPreviewTimer[client] = null;
	}
	g_bLaserPreview[client] = true;
	g_iLaserPreviewIndex[client] = index;
	g_hLaserPreviewTimer[client] = CreateTimer(10.0, LaserSight_Timer_StopPreview, client, TIMER_FLAG_NO_MAPCHANGE);
	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Spawn Preview CM");
		C_PrintToChat(client, "%s %t", g_sChatPrefix, "Spawn Preview");
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix, "Spawn Preview");
	#endif
}

public Action LaserSight_Timer_StopPreview(Handle timer, int client)
{
	g_hLaserPreviewTimer[client] = null;
	g_bLaserPreview[client] = false;
	return Plugin_Stop;
}

public void LaserSight_OnClientDisconnect(int client)
{
	g_bLaserPreview[client] = false;
	if (g_hLaserPreviewTimer[client] != null)
	{
		delete g_hLaserPreviewTimer[client];
		g_hLaserPreviewTimer[client] = null;
	}
}

#else

void LaserSight_OnPluginStart() {}
void LaserSight_OnPlayerRunCmd(int client)
{
	#pragma unused client
}
void LaserSight_OnClientDisconnect(int client)
{
	#pragma unused client
}

#endif