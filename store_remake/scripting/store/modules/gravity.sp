#if STORE_MODULE_GRAVITY
int g_iGravity[STORE_MAX_ITEMS];
int g_iGravityIdx = 0;
float g_fGravityTime[STORE_MAX_ITEMS];

public void Gravity_OnPluginStart()
{
	Store_RegisterHandler("gravity", "", Gravity_OnMapStart, Gravity_Reset, Gravity_Config, Gravity_Equip, Gravity_Remove, false);
}

public void Gravity_OnMapStart()
{
}

public void Gravity_Reset()
{
	g_iGravityIdx = 0;
}

public bool Gravity_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iGravityIdx);
	
	g_iGravity[g_iGravityIdx] = KvGetNum(kv, "gravity");
	g_fGravityTime[g_iGravityIdx] = KvGetFloat(kv, "duration");

	++g_iGravityIdx;
	return true;
}

public int Gravity_Equip(int client, int id)
{
	int m_iData = Store_GetDataIndex(id);
	
	// Вычисляем множитель гравитации
	float gravityMultiplier = float(g_iGravity[m_iData]) / 100.0;
	
	// Устанавливаем гравитацию для игрока
	SetEntityGravity(client, gravityMultiplier);
	
	// Проверяем длительность
	if(g_fGravityTime[m_iData] > 0.0)
	{
		CreateTimer(g_fGravityTime[m_iData], Timer_RemoveGravity, GetClientUserId(client));
	}
	
	return 0;
}

public int Gravity_Remove(int client)
{
	return 0;
}

public Action Timer_RemoveGravity(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client))
		return Plugin_Stop;

	SetEntityGravity(client, 1.0);
	return Plugin_Stop;
}

#else

void Gravity_OnPluginStart() {}

#endif