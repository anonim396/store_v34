#if STORE_MODULE_WEAPONS
char g_szWeapons[STORE_MAX_ITEMS][64];
int g_iWeapons = 0;

/*	Я хз как этот модуль работает	*/

public void Weapons_OnPluginStart()
{
	Store_RegisterHandler("weapon", "", Weapons_OnMapStart, Weapons_Reset, Weapons_Config, Weapons_Equip, Weapons_Remove, false);
}

public void Weapons_OnMapStart()
{
}

public void Weapons_Reset()
{
	g_iWeapons = 0;
}

public bool Weapons_Config(KeyValues &kv, int itemid)
{
	if (g_iWeapons >= STORE_MAX_ITEMS)
	{
		LogError("Weapon: Max weapon items reached (%d)", STORE_MAX_ITEMS);
		return false;
	}
	
	if (kv == null)
	{
		LogError("Weapons_Config: kv is null!");
		return false;
	}

	int index = g_iWeapons;
	Store_SetDataIndex(itemid, index);

	bool configValid = true;

	if (!kv.GetString("weapon", g_szWeapons[index], sizeof(g_szWeapons[])) || !g_szWeapons[index][0])
	{
		LogError("Weapon %d: Missing or empty 'weapon' value", itemid);
		configValid = false;
	}

	if (configValid)
	{
		++g_iWeapons;
	}

	return configValid;
}

public int Weapons_Equip(int client, int id)
{
	int index = Store_GetDataIndex(id);
	GivePlayerItem(client, g_szWeapons[index]);
	return 0;
}

public int Weapons_Remove(int client)
{
	return 0;
}

#else

void Weapons_OnPluginStart() {}

#endif