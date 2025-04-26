#define MAX_WEAPONS_IN_INVENTORY 48

int g_eWeaponColors[STORE_MAX_ITEMS][4];
int g_iWeaponColors = 0;
bool g_bColored[2048];
bool g_bClearColorOnDrop[STORE_MAX_ITEMS];

public void WeaponColors_OnPluginStart()
{
    Store_RegisterHandler("weaponcolor", "color", WeaponColors_OnMapStart, WeaponColors_Reset, WeaponColors_Config, WeaponColors_Equip, WeaponColors_Remove, true);
}

public void WeaponColors_OnClientPutInServer(int client)
{
    SDKHook(client, SDKHook_WeaponCanUse, WeaponColors_WeaponCanUse);
}

public void WeaponColors_OnMapStart() {}

public void WeaponColors_Reset()
{
    g_iWeaponColors = 0;
}

public bool WeaponColors_Config(KeyValues &kv, int itemid)
{
	if (g_iWeaponColors >= STORE_MAX_ITEMS)
	{
		LogError("WeaponColor: Max weapon color items reached (%d)", STORE_MAX_ITEMS);
		return false;
	}
	int index = g_iWeaponColors;
	Store_SetDataIndex(itemid, index);
	bool configValid = true;
	kv.GetColor("color", g_eWeaponColors[index][0], g_eWeaponColors[index][1], g_eWeaponColors[index][2], g_eWeaponColors[index][3]);
	if (g_eWeaponColors[index][0] == -1 || g_eWeaponColors[index][1] == -1 || g_eWeaponColors[index][2] == -1 || g_eWeaponColors[index][3] == -1)
	{
		LogError("WeaponColor %d: Invalid color", itemid);
		configValid = false;
	}
	else
	{
		if (g_eWeaponColors[index][3] == 0)
		{
			g_eWeaponColors[index][3] = 255;
		}
	}
	char clearColorOnDrop[2];
	kv.GetString("clearcolorondrop", clearColorOnDrop, sizeof(clearColorOnDrop));
	g_bClearColorOnDrop[index] = (clearColorOnDrop[0] == '1');
	++g_iWeaponColors;
	return configValid;
}

public int WeaponColors_Equip(int client, int id)
{
	if (!IsValidEdict(client))
		return 0;
	for (int i = 0; i < MAX_WEAPONS_IN_INVENTORY; ++i)
	{
		int m_iEntity = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
		if (m_iEntity != -1)
		{
			WeaponColors_WeaponCanUse(client, m_iEntity);
		}
	}
	return 0;
}

public int WeaponColors_Remove(int client)
{
	for (int i = 0; i < MAX_WEAPONS_IN_INVENTORY; ++i)
	{
		int m_iEntity = GetEntPropEnt(client, Prop_Send, "m_hMyWeapons", i);
		if (IsValidEntity(m_iEntity) && m_iEntity < sizeof(g_bColored))
		{
			SetEntityRenderColor(m_iEntity, 255, 255, 255, 255);
			g_bColored[m_iEntity] = false;
		}
	}
	return 0;
}

public Action CS_OnCSWeaponDrop(int client, int weaponIndex)
{
	if (g_iWeaponColors == 0)
		return Plugin_Continue;
	if (g_bClearColorOnDrop[Store_GetDataIndex(Store_GetEquippedItem(client, "weaponcolor", 0))])
	{
		SetEntityRenderColor(weaponIndex, 255, 255, 255, 255);
	}
	else
	{
		SetEntityRenderColor(weaponIndex, g_eWeaponColors[Store_GetDataIndex(Store_GetEquippedItem(client, "weaponcolor", 0))][0], g_eWeaponColors[Store_GetDataIndex(Store_GetEquippedItem(client, "weaponcolor", 0))][1], g_eWeaponColors[Store_GetDataIndex(Store_GetEquippedItem(client, "weaponcolor", 0))][2], g_eWeaponColors[Store_GetDataIndex(Store_GetEquippedItem(client, "weaponcolor", 0))][3]);
	}
	return Plugin_Continue;
}

public Action WeaponColors_WeaponCanUse(int client, int weapon)
{
	if (g_iWeaponColors == 0 || g_bColored[weapon])
		return Plugin_Continue;
	Handle data = CreateDataPack();
	WritePackCell(data, GetClientUserId(client));
	WritePackCell(data, weapon);
	ResetPack(data);
	RequestFrame(RequestFrame_ColorWeapon, data);
	return Plugin_Continue;
}

public void RequestFrame_ColorWeapon(any data)
{
	int userid = ReadPackCell(data);
	int weapon = ReadPackCell(data);
	CloseHandle(data);
	int client = GetClientOfUserId(userid);
	if (!client || !IsValidEdict(weapon))
	{
		return;
	}
	int m_iEquipped = Store_GetEquippedItem(client, "weaponcolor", 0);
	if (m_iEquipped < 0)
	{
		return;
	}
	int m_iData = Store_GetDataIndex(m_iEquipped);
	SetEntityRenderMode(weapon, RENDER_TRANSCOLOR); //CSS v34 TEST ME
	SetEntityRenderColor(weapon, g_eWeaponColors[m_iData][0], g_eWeaponColors[m_iData][1], g_eWeaponColors[m_iData][2], g_eWeaponColors[m_iData][3]);
	g_bColored[weapon] = true;
}
