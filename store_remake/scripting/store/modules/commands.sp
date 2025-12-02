char g_szCommands[STORE_MAX_ITEMS][256];
char g_szCommandsOff[STORE_MAX_ITEMS][256];
int g_unCommandsTime[STORE_MAX_ITEMS];

int g_iCommands = 0;

public void Commands_OnPluginStart()
{
	Store_RegisterHandler("command", "", Commands_OnMapStart, Commands_Reset, Commands_Config, Commands_Equip, Commands_Remove, false);
}

public void Commands_OnMapStart()
{
}

public void Commands_Reset()
{
	g_iCommands = 0;
}

public bool Commands_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iCommands);
	
	kv.GetString("command", g_szCommands[g_iCommands], sizeof(g_szCommands[]));
	kv.GetString("command_off", g_szCommandsOff[g_iCommands], sizeof(g_szCommandsOff[]));
	g_unCommandsTime[g_iCommands] = kv.GetNum("time", -1);
	
	++g_iCommands;
	return true;
}

public int Commands_Equip(int client, int id)
{
	int m_iData = Store_GetDataIndex(id);
	
	char m_szCommand[512];
	strcopy(m_szCommand, sizeof(m_szCommand), g_szCommands[m_iData]);
	
	char m_szClientID[16];
	char m_szUserID[16];
	char m_szSteamID[64];
	char m_szName[128];
	char m_szEscapedName[256];
	
	IntToString(client, m_szClientID, sizeof(m_szClientID));
	IntToString(GetClientUserId(client), m_szUserID, sizeof(m_szUserID));
	GetClientAuthId(client, AuthId_Steam2, m_szSteamID, sizeof(m_szSteamID));
	
	GetClientName(client, m_szName, sizeof(m_szName));
	
	strcopy(m_szEscapedName, sizeof(m_szEscapedName), m_szName);
	ReplaceString(m_szEscapedName, sizeof(m_szEscapedName), "\"", "\\\"");
	
	ReplaceString(m_szCommand, sizeof(m_szCommand), "{clientid}", m_szClientID, false);
	ReplaceString(m_szCommand, sizeof(m_szCommand), "{userid}", m_szUserID, false);
	ReplaceString(m_szCommand, sizeof(m_szCommand), "{steamid}", m_szSteamID, false);
	ReplaceString(m_szCommand, sizeof(m_szCommand), "{name}", m_szEscapedName, false);
	
	ServerCommand("%s", m_szCommand);
	
	if(g_unCommandsTime[m_iData] > 0)
	{
		DataPack pack = new DataPack();
		pack.WriteCell(GetClientUserId(client));
		pack.WriteCell(m_iData);
		
		CreateTimer(float(g_unCommandsTime[m_iData]), Timer_CommandOff, pack);
	}
	
	return 0;
}

public Action Timer_CommandOff(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = GetClientOfUserId(pack.ReadCell());
	int m_iData = pack.ReadCell();
	delete pack;
	
	if(!g_szCommandsOff[m_iData][0])
		return Plugin_Stop;
	
	char m_szCommand[512];
	strcopy(m_szCommand, sizeof(m_szCommand), g_szCommandsOff[m_iData]);
	
	char m_szClientID[16] = "0";
	char m_szUserID[16] = "0";
	char m_szSteamID[64] = "STEAM_0:0:0";
	char m_szName[128] = "Disconnected";
	char m_szEscapedName[256] = "Disconnected";
	
	if(client && IsClientInGame(client))
	{
		IntToString(client, m_szClientID, sizeof(m_szClientID));
		IntToString(GetClientUserId(client), m_szUserID, sizeof(m_szUserID));
		GetClientAuthId(client, AuthId_Steam2, m_szSteamID, sizeof(m_szSteamID));
		
		GetClientName(client, m_szName, sizeof(m_szName));
		strcopy(m_szEscapedName, sizeof(m_szEscapedName), m_szName);
		ReplaceString(m_szEscapedName, sizeof(m_szEscapedName), "\"", "\\\"");
	}
	
	ReplaceString(m_szCommand, sizeof(m_szCommand), "{clientid}", m_szClientID, false);
	ReplaceString(m_szCommand, sizeof(m_szCommand), "{userid}", m_szUserID, false);
	ReplaceString(m_szCommand, sizeof(m_szCommand), "{steamid}", m_szSteamID, false);
	ReplaceString(m_szCommand, sizeof(m_szCommand), "{name}", m_szEscapedName, false);
	
	ServerCommand("%s", m_szCommand);
	
	return Plugin_Stop;
}

public int Commands_Remove(int client)
{
	return 0;
}