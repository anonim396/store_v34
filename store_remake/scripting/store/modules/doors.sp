char g_szDoors[STORE_MAX_ITEMS][64];
int g_iDoorsIdx = 0;

public void Doors_OnPluginStart()
{
	Store_RegisterHandler("door", "", Doors_OnMapStart, Doors_Reset, Doors_Config, Doors_Equip, Doors_Remove, false);
}

public void Doors_OnMapStart()
{
}

public void Doors_Reset()
{
	g_iDoorsIdx = 0;
}

public bool Doors_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iDoorsIdx);
	
	KvGetString(kv, "targetname", g_szDoors[g_iDoorsIdx], sizeof(g_szDoors[]));

	++g_iDoorsIdx;
	return true;
}

public int Doors_Equip(int client, int id)
{
	int m_iData = Store_GetDataIndex(id);

	char m_szName[64];
	m_szName[0] = 0;

	for(int i = MaxClients + 1; i < 2048; ++i)
	{
		if(!IsValidEdict(i) || !IsValidEntity(i))
			continue;
		
		GetEntPropString(i, Prop_Data, "m_iName", m_szName, sizeof(m_szName));
		if(strcmp(m_szName, g_szDoors[m_iData]) == 0)
		{
			AcceptEntityInput(i, "Open");
			break;
		}
	}
	
	return -2;
}

public int Doors_Remove(int client)
{
	return 0;
}