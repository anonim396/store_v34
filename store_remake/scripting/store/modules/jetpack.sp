int g_cvarFuel;
int g_cvarRegen;
int g_cvarMinimum;
int g_cvarForce;
int g_cvarCommand;

float g_fFuel[MAXPLAYERS + 1];
float g_fTime[MAXPLAYERS + 1];
float g_fLastHUDTime[MAXPLAYERS + 1];

bool g_bJetpacking[MAXPLAYERS + 1] = {false, ...};

public void Jetpack_OnPluginStart()
{
	Store_RegisterHandler("jetpack", "", Jetpack_OnMapStart, Jetpack_Reset, Jetpack_Config, Jetpack_Equip, Jetpack_Remove, true);

	g_cvarFuel = RegisterConVar("sm_store_jetpack_fuel", "1.0", "A full fuel tank, in seconds.", TYPE_FLOAT);
	g_cvarRegen = RegisterConVar("sm_store_jetpack_regen", "0.1", "Fuel in seconds regenerated per second.", TYPE_FLOAT);
	g_cvarMinimum = RegisterConVar("sm_store_jetpack_minimum", "0.1", "Minimum amount of fuel in seconds needed to start the jetpack.", TYPE_FLOAT);
	g_cvarForce = RegisterConVar("sm_store_jetpack_force", "12.0", "Lifting velocity.", TYPE_FLOAT);
	g_cvarCommand = RegisterConVar("sm_store_jetpack_command", "jetpack", "Command for the jetpack. +/- will be applied to it for toggling", TYPE_STRING);
}

public void Jetpack_OnMapStart()
{
}

public void Jetpack_OnConfigsExecuted()
{
	char m_szCommand[64];
	strcopy(m_szCommand[1], sizeof(m_szCommand) - 1, g_eCvars[g_cvarCommand].sCache);
	m_szCommand[0] = '+';
	RegConsoleCmd(m_szCommand, Command_JetpackOn);
	m_szCommand[0] = '-';
	RegConsoleCmd(m_szCommand, Command_JetpackOff);
}

public void Jetpack_Reset()
{
}

public void Jetpack_OnClientConnected(int client)
{
	g_bJetpacking[client] = false;
}

public bool Jetpack_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, 0);
	return true;
}

public int Jetpack_Equip(int client, int id)
{
	return -1;
}

public void Jetpack_Remove(int client, int id)
{
}

public Action Command_JetpackOn(int client, int args)
{
	g_bJetpacking[client] = true;
	return Plugin_Handled;
}

public Action Command_JetpackOff(int client, int args)
{
	g_bJetpacking[client] = false;
	return Plugin_Handled;
}

public void Jetpack_OnPlayerRunCmd(int client, int &buttons)
{
	int m_iEquipped = Store_GetEquippedItem(client, "jetpack");
	if(m_iEquipped < 0)
		return;

	float m_fTime = GetGameTime();	 
	if(g_bJetpacking[client])
	{
		if(g_fFuel[client] > g_eCvars[g_cvarMinimum].aCache)
		{
			float m_fVelocity[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", m_fVelocity);
	 
			m_fVelocity[2] += g_eCvars[g_cvarForce].aCache;
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, m_fVelocity);
	 
			g_fFuel[client] -= m_fTime - g_fTime[client];
			if(g_fFuel[client] < 0.0)
				g_fFuel[client] = 0.0;
		}
		else
			g_fFuel[client] = 0.0;
	}
		 
	if(g_fFuel[client] < g_eCvars[g_cvarFuel].aCache)
	{
		g_fFuel[client] += (m_fTime - g_fTime[client]) * g_eCvars[g_cvarRegen].aCache;
		if(g_fFuel[client] > g_eCvars[g_cvarFuel].aCache)
			g_fFuel[client] = g_eCvars[g_cvarFuel].aCache;
	}
	 
	if(g_fFuel[client] != g_eCvars[g_cvarFuel].aCache && g_fLastHUDTime[client] + 0.1 < m_fTime)
	{
		PrintHintText(client, "%t", "Jetpack Fuel", g_fFuel[client]);
		g_fLastHUDTime[client] = m_fTime;
	}
	 
	g_fTime[client] = m_fTime;
}