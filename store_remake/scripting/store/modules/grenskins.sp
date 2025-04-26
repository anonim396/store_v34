enum struct GrenadeSkin
{
	char szModel_Grenade[PLATFORM_MAX_PATH];
	char szWeapon[64];
	int iLength;
	int iSlot_Grenade;
	int nModelIndex;
}

GrenadeSkin g_eGrenadeSkins[STORE_MAX_ITEMS];
char g_szSlots[16][64];
int g_iGrenadeSkins = 0;
int g_iSlot_Grenades = 0;

public void GrenadeSkins_OnPluginStart()
{
	Store_RegisterHandler("grenadeskin", "model", GrenadeSkins_OnMapStart, GrenadeSkins_Reset, GrenadeSkins_Config, GrenadeSkins_Equip, GrenadeSkins_Remove, true);
}

public void GrenadeSkins_OnMapStart()
{
	for (int i = 0; i < g_iGrenadeSkins; ++i)
	{
		g_eGrenadeSkins[i].nModelIndex = PrecacheModel2(g_eGrenadeSkins[i].szModel_Grenade, true);
		Downloader_AddFileToDownloadsTable(g_eGrenadeSkins[i].szModel_Grenade);
		PrecacheModel(g_eGrenadeSkins[i].szModel_Grenade);
	}
}

public void GrenadeSkins_Reset()
{
	g_iGrenadeSkins = 0;
}

public bool GrenadeSkins_Config(KeyValues &kv, int itemid)
{
    if (g_iGrenadeSkins >= STORE_MAX_ITEMS)
    {
        LogError("GrenadeSkin: Exceeded max grenade skins items (%d)", STORE_MAX_ITEMS);
        return false;
    }

    Store_SetDataIndex(itemid, g_iGrenadeSkins);
    bool configValid = true;
    GrenadeSkin grenadeSkin;

    // Логирование получения модели
    if (!kv.GetString("model", grenadeSkin.szModel_Grenade, PLATFORM_MAX_PATH) || !grenadeSkin.szModel_Grenade[0])
    {
        LogError("Missing or empty 'model' value for grenade skin %d", itemid);
        configValid = false;
    }

    // Проверка наличия файла
    if (!FileExists(grenadeSkin.szModel_Grenade, true))
    {
        LogError("GrenadeSkin %d: File not found '%s'", itemid, grenadeSkin.szModel_Grenade);
        configValid = false;
    }

    // Проверка наличия ключа "grenade"
    if (!kv.JumpToKey("grenade"))
    {
        LogError("GrenadeSkin %d: Missing 'grenade'", itemid);
        configValid = false;
    }

    kv.GoBack();

    // Логирование получения значения для "grenade"
    kv.GetString("grenade", grenadeSkin.szWeapon, sizeof(grenadeSkin.szWeapon));
    grenadeSkin.iSlot_Grenade = GrenadeSkins_GetSlot(grenadeSkin.szWeapon);
    grenadeSkin.iLength = strlen(grenadeSkin.szWeapon);

    if (configValid)
    {
		//FIX ME
        GrenadeSkins_OnMapStart();
		//
        g_eGrenadeSkins[g_iGrenadeSkins] = grenadeSkin;
        g_iGrenadeSkins++;
        return true;
    }

    LogError("GrenadeSkin %d: Config invalid", itemid);  // Логирование ошибки, если конфиг неверный
    return false;
}

public int GrenadeSkins_Equip(int client, int id)
{
	return g_eGrenadeSkins[Store_GetDataIndex(id)].iSlot_Grenade;
}

public int GrenadeSkins_Remove(int client, int id)
{
	return g_eGrenadeSkins[Store_GetDataIndex(id)].iSlot_Grenade;
}

public int GrenadeSkins_GetSlot(char[] weapon)
{
	for (int i = 0; i < g_iSlot_Grenades; ++i)
		if (strcmp(weapon, g_szSlots[i]) == 0)
			return i;

	strcopy(g_szSlots[g_iSlot_Grenades], sizeof(g_szSlots[]), weapon);
	return g_iSlot_Grenades++;
}

public void GrenadeSkins_OnEntityCreated(int entity, const char[] classname)
{
	if (g_iGrenadeSkins == 0)
		return;
	if (StrContains(classname, "_projectile") > 0)
		SDKHook(entity, SDKHook_SpawnPost, GrenadeSkins_OnEntitySpawnedPost);
}

public void GrenadeSkins_OnEntitySpawnedPost(int entity)
{
	int client = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");

	if (!(0 < client <= MaxClients))
		return;

	char m_szClassname[64];
	GetEdictClassname(entity, m_szClassname, sizeof(m_szClassname));

	any m_iSlot_Grenade;

	for (int i = 0; i < strlen(m_szClassname); ++i)
		if (m_szClassname[i] == '_')
		{
			m_szClassname[i] = 0;
			break;
		}

	m_iSlot_Grenade = GrenadeSkins_GetSlot(m_szClassname);

	int m_iEquipped = Store_GetEquippedItem(client, "grenadeskin", m_iSlot_Grenade);

	if (m_iEquipped < 0)
		return;

	int m_iData = Store_GetDataIndex(m_iEquipped);
	SetEntityModel(entity, g_eGrenadeSkins[m_iData].szModel_Grenade);
}
