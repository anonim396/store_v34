#if STORE_MODULE_INVISIBILITY
float g_fInvisibilityTime[STORE_MAX_ITEMS]; 
int g_iInvisibility[STORE_MAX_ITEMS];
int g_iInvisibilityIdx = 0;

public void Invisibility_OnPluginStart()
{
	Store_RegisterHandler("invisibility", "", Invisibility_OnMapStart, Invisibility_Reset, Invisibility_Config, Invisibility_Equip, Invisibility_Remove, false);
}

public void Invisibility_OnMapStart()
{
}

public void Invisibility_Reset()
{
	g_iInvisibilityIdx = 0;
}

public bool Invisibility_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iInvisibilityIdx);
	
	g_iInvisibility[g_iInvisibilityIdx] = KvGetNum(kv, "invisibility");
	g_fInvisibilityTime[g_iInvisibilityIdx] = KvGetFloat(kv, "duration");

	++g_iInvisibilityIdx;
	return true;
}

public int Invisibility_Equip(int client, int id)
{
	int m_iData = Store_GetDataIndex(id);
	
	// Пробуем оба метода
	SetEntityRenderMode(client, RENDER_TRANSCOLOR);
	SetEntityRenderColor(client, 255, 255, 255, g_iInvisibility[m_iData]);
	
	// Альтернативно через SetEntProp
	int color = (255 << 24) | (255 << 16) | (255 << 8) | g_iInvisibility[m_iData];
	SetEntProp(client, Prop_Send, "m_clrRender", color);
	SetEntProp(client, Prop_Send, "m_nRenderMode", 3);
	
	if(g_fInvisibilityTime[m_iData] > 0.0)
	{
		CreateTimer(g_fInvisibilityTime[m_iData], Timer_RemoveInvisibility, GetClientUserId(client));
	}

	return 0;
}

public int Invisibility_Remove(int client)
{
	// Восстанавливаем
	SetEntityRenderMode(client, RENDER_NORMAL);
	SetEntityRenderColor(client, 255, 255, 255, 255);
	SetEntProp(client, Prop_Send, "m_nRenderMode", 0);
	SetEntProp(client, Prop_Send, "m_clrRender", -1); // -1 = 0xFFFFFFFF
	
	return 0;
}

public Action Timer_RemoveInvisibility(Handle timer, any userid)
{
	int client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client))
		return Plugin_Stop;
	
	Invisibility_Remove(client);
	return Plugin_Stop;
}

#else

void Invisibility_OnPluginStart() {}

#endif