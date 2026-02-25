#if STORE_MODULE_SPEED
int g_iSpeedIdx = 0;

float g_fSpeed[STORE_MAX_ITEMS];
float g_fSpeedTime[STORE_MAX_ITEMS];

public void 
Speed_OnPluginStart()
{
	Store_RegisterHandler("speed", "", Speed_OnMapStart, Speed_Reset, Speed_Config, Speed_Equip, Speed_Remove, false);
}

public void Speed_OnMapStart()
{
}

public void Speed_Reset()
{
	g_iSpeedIdx = 0;
}

public bool Speed_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iSpeedIdx);
	
	g_fSpeed[g_iSpeedIdx] = kv.GetFloat("speed");
	g_fSpeedTime[g_iSpeedIdx] = kv.GetFloat("duration");

	++g_iSpeedIdx;
	return true;
}

public int Speed_Equip(int client, int id)
{
	int m_iData = Store_GetDataIndex(id);
	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", g_fSpeed[m_iData]);
	if(g_fSpeedTime[m_iData] != 0.0)
		CreateTimer(g_fSpeedTime[m_iData], Timer_RemoveSpeed, GetClientUserId(client));
	return 0;
}

public int Speed_Remove(int client)
{
	return 0;
}

public Action Timer_RemoveSpeed(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client))
		return Plugin_Stop;

	SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 1.0);

	return Plugin_Stop;
}

#else

void Speed_OnPluginStart() {}

#endif