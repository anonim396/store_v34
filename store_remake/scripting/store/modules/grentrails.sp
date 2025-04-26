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

public void GrenadeTrails_OnPluginStart()
{
    Store_RegisterHandler("grenadetrail", "material", GrenadeTrails_OnMapStart, GrenadeTrails_Reset, GrenadeTrails_Config, GrenadeTrails_Equip, GrenadeTrails_Remove, true);
}

public void GrenadeTrails_OnMapStart()
{
    for (int i = 0; i < g_iGrenadeTrails; ++i)
    {
        g_eGrenadeTrails[i].iCacheID = PrecacheModel2(g_eGrenadeTrails[i].szMaterial, true);
        Downloader_AddFileToDownloadsTable(g_eGrenadeTrails[i].szMaterial);
    }
}

public void GrenadeTrails_Reset()
{
    g_iGrenadeTrails = 0;
}

public bool GrenadeTrails_Config(KeyValues &kv, int itemid)
{
	if (g_iGrenadeTrails >= STORE_MAX_ITEMS)
	{
		LogError("GrenadeTrail: Max grenade trail items reached (%d)", STORE_MAX_ITEMS);
		return false;
	}

	int index = g_iGrenadeTrails;
	Store_SetDataIndex(itemid, index);
	bool configValid = true;

	kv.GetString("material", g_eGrenadeTrails[index].szMaterial, PLATFORM_MAX_PATH);
	if (!FileExists(g_eGrenadeTrails[index].szMaterial, true))
	{
		LogError("GrenadeTrail %d: Material file not found '%s'", itemid, g_eGrenadeTrails[index].szMaterial);
		configValid = false;
	}

	g_eGrenadeTrails[index].fWidth = kv.GetFloat("width", 10.0);
	FloatToString(g_eGrenadeTrails[index].fWidth, g_eGrenadeTrails[index].szWidth, sizeof(GrenadeTrail::szWidth));
	kv.GetString("color", g_eGrenadeTrails[index].szColor, sizeof(GrenadeTrail::szColor), "255 255 255 255");
	if (!kv.GetColor("color", g_eGrenadeTrails[index].iColor[0], g_eGrenadeTrails[index].iColor[1], g_eGrenadeTrails[index].iColor[2], g_eGrenadeTrails[index].iColor[3]))
	{
		LogError("GrenadeTrail %d: Invalid color", itemid);
		configValid = false;
	}

	g_eGrenadeTrails[index].iSlot = kv.GetNum("slot");

	if (configValid)
	{
		//FIX ME
		GrenadeTrails_OnMapStart();
		//
		++g_iGrenadeTrails;
		return true;
	}

	LogError("GrenadeTrail %d: Configuration invalid", itemid);
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
    
    if (StrContains(classname, "_projectile") != -1)
	{
        SDKHook(entity, SDKHook_SpawnPost, GrenadeTrails_OnEntitySpawnedPost);
	}
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
    m_iColor[0] = g_eGrenadeTrails[m_iData].iColor[0];
    m_iColor[1] = g_eGrenadeTrails[m_iData].iColor[1];
    m_iColor[2] = g_eGrenadeTrails[m_iData].iColor[2];
    m_iColor[3] = g_eGrenadeTrails[m_iData].iColor[3];

    TE_SetupBeamFollow(entity, g_eGrenadeTrails[m_iData].iCacheID, 0, 2.0, g_eGrenadeTrails[m_iData].fWidth, g_eGrenadeTrails[m_iData].fWidth, 10, m_iColor);
    TE_SendToAll();
}
