int g_iLinkCount = 0;
char g_sLinkCommand[STORE_MAX_ITEMS][64];

public void Link_OnPluginStart()
{
	Store_RegisterHandler("link", "link", _, Link_Reset, Link_Config, Link_Equip, _, false, true);
}

public void Link_Reset()
{
	g_iLinkCount = 0;
}

public bool Link_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iLinkCount);

	kv.GetString("command", g_sLinkCommand[g_iLinkCount], 64);

	g_iLinkCount++;

	return true;
}

public int Link_Equip(int client, int itemid)
{
	int iIndex = Store_GetDataIndex(itemid);
	
	if (iIndex < 0 || iIndex >= g_iLinkCount)
		return 0;

	char sCommand[256];
	strcopy(sCommand, sizeof(sCommand), g_sLinkCommand[iIndex]);

	FakeClientCommandEx(client, sCommand);

	return 0;
}