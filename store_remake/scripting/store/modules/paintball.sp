char g_szPaintballDecals[STORE_MAX_ITEMS][32][PLATFORM_MAX_PATH];
int g_iPaintballDecalIDs[STORE_MAX_ITEMS][32];
int g_iPaintballDecals[STORE_MAX_ITEMS] = {0};
int g_iPaintballItems = 0;

public void Paintball_OnPluginStart()
{
    Store_RegisterHandler("paintball", "", Paintball_OnMapStart, Paintball_Reset, Paintball_Config, Paintball_Equip, Paintball_Remove, true);
    HookEvent("bullet_impact", Paintball_BulletImpact);
}

public void Paintball_OnMapStart()
{
    char m_szFullPath[PLATFORM_MAX_PATH];
    for (int iItem = 0; iItem < g_iPaintballItems; ++iItem)
    {
        for (int iDecal = 0; iDecal < g_iPaintballDecals[iItem]; ++iDecal)
        {
            g_iPaintballDecalIDs[iItem][iDecal] = PrecacheDecal(g_szPaintballDecals[iItem][iDecal], true);
            Format(m_szFullPath, sizeof(m_szFullPath), "materials/%s", g_szPaintballDecals[iItem][iDecal]);
            Downloader_AddFileToDownloadsTable(m_szFullPath);
        }
    }
}

public void Paintball_Reset()
{
    for (int i = 0; i < STORE_MAX_ITEMS; ++i)
    {
        g_iPaintballDecals[i] = 0;
    }
    g_iPaintballItems = 0;
}

public bool Paintball_Config(KeyValues &kv, int itemid)
{
	if (g_iPaintballItems >= STORE_MAX_ITEMS)
	{
		LogError("Paintball: Превышен лимит предметов (%d)", STORE_MAX_ITEMS);
		return false;
	}

	Store_SetDataIndex(itemid, g_iPaintballItems);
	int currentIndex = g_iPaintballItems;
	bool configValid = true;

	if (!KvJumpToKey(kv, "Decals"))
	{
		LogError("Paintball: Предмет %d без секции 'Decals'", itemid);
		return false;
	}

	if (!KvGotoFirstSubKey(kv))
	{
		LogError("Paintball: Секция 'Decals' пуста для предмета %d", itemid);
		KvGoBack(kv);
		return false;
	}

	do
	{
		if (g_iPaintballDecals[currentIndex] >= 32)
		{
			LogError("Paintball: Слишком много декалей у предмета %d (максимум 32)", itemid);
			configValid = false;
			break;
		}

		KvGetString(kv, "material", g_szPaintballDecals[currentIndex][g_iPaintballDecals[currentIndex]], PLATFORM_MAX_PATH);

		if (!g_szPaintballDecals[currentIndex][g_iPaintballDecals[currentIndex]][0])
		{
			LogError("Paintball: Пустое имя материала у предмета %d", itemid);
			configValid = false;
		}
		else
		{
			char fullPath[PLATFORM_MAX_PATH];
			Format(fullPath, sizeof(fullPath), "materials/%s", g_szPaintballDecals[currentIndex][g_iPaintballDecals[currentIndex]]);

			if (!FileExists(fullPath, true))
			{
				LogError("Paintball: Файл материала не найден: %s", fullPath);
				configValid = false;
			}
		}

		++g_iPaintballDecals[currentIndex];
	} while (KvGotoNextKey(kv));

	KvGoBack(kv);
	KvGoBack(kv);

	if (configValid)
	{
		++g_iPaintballItems;
		//FIX ME
		Paintball_OnMapStart();
		return true;
	}

	return false;
}

public int Paintball_Equip(int client, int id)
{
    return -1;
}

public int Paintball_Remove(int client, int id)
{
    return 0;
}

public Action Paintball_BulletImpact(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(GetEventInt(event, "userid"));
    int m_iEquipped = Store_GetEquippedItem(client, "paintball");
    
    if (m_iEquipped >= 0)
    {
        int m_iData = Store_GetDataIndex(m_iEquipped);
        float m_fImpact[3];
        
        m_fImpact[0] = GetEventFloat(event, "x");
        m_fImpact[1] = GetEventFloat(event, "y");
        m_fImpact[2] = GetEventFloat(event, "z");
        
        TE_Start("World Decal");
        TE_WriteVector("m_vecOrigin", m_fImpact);
        TE_WriteNum("m_nIndex", g_iPaintballDecalIDs[m_iData][GetRandomInt(0, g_iPaintballDecals[m_iData] - 1)]);
        TE_SendToAll();
    }
    
    return Plugin_Continue;
}