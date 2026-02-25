#if STORE_MODULE_GRENSKINS
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
int g_iGrenadeSkinPreviewEnt[MAXPLAYERS+1] = {INVALID_ENT_REFERENCE, ...};
Handle g_hGrenadeSkinPreviewTimer[MAXPLAYERS+1];

public void GrenadeSkins_OnPluginStart()
{
	Store_RegisterHandler("grenadeskin", "model", GrenadeSkins_OnMapStart, GrenadeSkins_Reset, GrenadeSkins_Config, GrenadeSkins_Equip, GrenadeSkins_Remove, true);
}

public void GrenadeSkins_OnMapStart()
{
	for (int i = 0; i < g_iGrenadeSkins; ++i)
	{
		g_eGrenadeSkins[i].nModelIndex = PrecacheModel(g_eGrenadeSkins[i].szModel_Grenade, true);
		AddFileToDownloadsTable(g_eGrenadeSkins[i].szModel_Grenade);
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

	if (!(0 < client && client <= MaxClients))
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

public void GrenadeSkins_OnPreviewItem(int client, const char[] type, int index)
{
	if (!StrEqual(type, "grenadeskin") || index < 0 || index >= g_iGrenadeSkins)
		return;
	if (g_iGrenadeSkinPreviewEnt[client] != INVALID_ENT_REFERENCE)
	{
		int ent = EntRefToEntIndex(g_iGrenadeSkinPreviewEnt[client]);
		if (ent > 0 && IsValidEntity(ent))
			AcceptEntityInput(ent, "Kill");
		g_iGrenadeSkinPreviewEnt[client] = INVALID_ENT_REFERENCE;
	}
	if (g_hGrenadeSkinPreviewTimer[client] != null)
	{
		delete g_hGrenadeSkinPreviewTimer[client];
		g_hGrenadeSkinPreviewTimer[client] = null;
	}
	int iPreview = CreateEntityByName("prop_dynamic_override");
	if (iPreview <= 0)
		return;
	DispatchKeyValue(iPreview, "spawnflags", "64");
	DispatchKeyValue(iPreview, "model", g_eGrenadeSkins[index].szModel_Grenade);
	DispatchSpawn(iPreview);
	SetEntProp(iPreview, Prop_Send, "m_CollisionGroup", 11);
	AcceptEntityInput(iPreview, "Enable");
	float fOri[3], fAng[3], fRad[2], fPos[3];
	GetClientAbsOrigin(client, fOri);
	GetClientAbsAngles(client, fAng);
	fRad[0] = DegToRad(fAng[0]);
	fRad[1] = DegToRad(fAng[1]);
	fPos[0] = fOri[0] + 64.0 * Cosine(fRad[0]) * Cosine(fRad[1]);
	fPos[1] = fOri[1] + 64.0 * Cosine(fRad[0]) * Sine(fRad[1]);
	fPos[2] = fOri[2] + 55.0 + 4.0 * Sine(fRad[0]);
	fAng[0] *= -1.0;
	fAng[1] += 180.0;
	TeleportEntity(iPreview, fPos, fAng, NULL_VECTOR);
	g_iGrenadeSkinPreviewEnt[client] = EntIndexToEntRef(iPreview);
	SDKHook(iPreview, SDKHook_SetTransmit, GrenadeSkins_Preview_SetTransmit);
	g_hGrenadeSkinPreviewTimer[client] = CreateTimer(45.0, GrenadeSkins_Timer_KillPreview, client);
	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Spawn Preview CM");
		C_PrintToChat(client, "%s %t", g_sChatPrefix, "Spawn Preview");
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix, "Spawn Preview");
	#endif
}

public Action GrenadeSkins_Preview_SetTransmit(int ent, int client)
{
	if (g_iGrenadeSkinPreviewEnt[client] == INVALID_ENT_REFERENCE)
		return Plugin_Handled;
	if (ent == EntRefToEntIndex(g_iGrenadeSkinPreviewEnt[client]))
		return Plugin_Continue;
	return Plugin_Handled;
}

public Action GrenadeSkins_Timer_KillPreview(Handle timer, int client)
{
	g_hGrenadeSkinPreviewTimer[client] = null;
	if (g_iGrenadeSkinPreviewEnt[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iGrenadeSkinPreviewEnt[client]);
		if (entity > 0 && IsValidEntity(entity))
		{
			SDKUnhook(entity, SDKHook_SetTransmit, GrenadeSkins_Preview_SetTransmit);
			AcceptEntityInput(entity, "Kill");
		}
		g_iGrenadeSkinPreviewEnt[client] = INVALID_ENT_REFERENCE;
	}
	return Plugin_Stop;
}

public void GrenadeSkins_OnClientDisconnect(int client)
{
	if (g_hGrenadeSkinPreviewTimer[client] != null)
	{
		delete g_hGrenadeSkinPreviewTimer[client];
		g_hGrenadeSkinPreviewTimer[client] = null;
	}
	if (g_iGrenadeSkinPreviewEnt[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iGrenadeSkinPreviewEnt[client]);
		if (entity > 0 && IsValidEntity(entity))
			AcceptEntityInput(entity, "Kill");
		g_iGrenadeSkinPreviewEnt[client] = INVALID_ENT_REFERENCE;
	}
}

#else

void GrenadeSkins_OnPluginStart() {}
void GrenadeSkins_OnClientDisconnect(int client)
{
	#pragma unused client
}
void GrenadeSkins_OnEntityCreated(int entity, const char[] classname)
{
	#pragma unused entity
	#pragma unused classname
}

#endif