#if STORE_MODULE_CREDITS_MULTIPLIER

#define CREDITS_MULTIPLIER_MAX_SLOTS 64

int g_iCreditsMultiplierCount;
float g_fCreditsMultiplierValue[CREDITS_MULTIPLIER_MAX_SLOTS];

void CreditsMultiplier_OnPluginStart()
{
	Store_RegisterHandler("credits_multiplier", "multiplier", INVALID_FUNCTION, CreditsMultiplier_Reset, CreditsMultiplier_Config, CreditsMultiplier_Equip, CreditsMultiplier_Remove, true);
	Store_AddCreditsGivenCallback(GetMyHandle(), CreditsMultiplier_OnCreditsGiven);
}

public void CreditsMultiplier_Reset()
{
	g_iCreditsMultiplierCount = 0;
}

public bool CreditsMultiplier_Config(KeyValues &kv, int itemid)
{
	if (g_iCreditsMultiplierCount >= CREDITS_MULTIPLIER_MAX_SLOTS)
		return false;
	Store_SetDataIndex(itemid, g_iCreditsMultiplierCount);
	float mult = 1.5;
	if (KvJumpToKey(kv, "Attributes", false))
	{
		char buf[16];
		KvGetString(kv, "multiplier", buf, sizeof(buf), "1.5");
		KvGoBack(kv);
		mult = StringToFloat(buf);
		if (mult < 1.0) mult = 1.0;
		if (mult > 10.0) mult = 10.0;
	}
	g_fCreditsMultiplierValue[g_iCreditsMultiplierCount] = mult;
	g_iCreditsMultiplierCount++;
	return true;
}

public int CreditsMultiplier_Equip(int client, int id)
{
	return 0;
}

public int CreditsMultiplier_Remove(int client)
{
	return 0;
}

public void CreditsMultiplier_OnCreditsGiven(int client, int &delta)
{
	if (delta <= 0)
		return;
	int itemid = Store_GetEquippedItem(client, "credits_multiplier", 0);
	if (itemid < 0)
		return;
	int idx = Store_GetDataIndex(itemid);
	if (idx < 0 || idx >= g_iCreditsMultiplierCount)
		return;
	float mult = g_fCreditsMultiplierValue[idx];
	if (mult <= 1.0)
		return;
	delta = RoundToCeil(float(delta) * mult);
}

#else
void CreditsMultiplier_OnPluginStart() {}
#endif
