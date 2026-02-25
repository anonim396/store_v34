#if STORE_MODULE_JETPACK
enum struct JetpackData
{
	float fuel;
	float regen;
	float force;
	float minimum;
}

JetpackData g_JetpackData[STORE_MAX_ITEMS];
int g_iJetpackCount = 0;

float g_fFuel[MAXPLAYERS + 1];
float g_fLastUsage[MAXPLAYERS + 1];
float g_fLastHUDTime[MAXPLAYERS + 1];
bool g_bJetpacking[MAXPLAYERS + 1] = {false, ...};
int g_iCurrentJetpack[MAXPLAYERS + 1] = {-1, ...};

int g_cvarFuel;
int g_cvarRegen;
int g_cvarMinimum;
int g_cvarForce;
int g_cvarCommand;

public void Jetpack_OnPluginStart()
{
	Store_RegisterHandler("jetpack", "", Jetpack_OnMapStart, Jetpack_Reset, Jetpack_Config, Jetpack_Equip, Jetpack_Remove, true);

	g_cvarFuel = RegisterConVar("sm_store_jetpack_fuel", "2.0", "A full fuel tank, in seconds.", TYPE_FLOAT);
	g_cvarRegen = RegisterConVar("sm_store_jetpack_regen", "0.2", "Fuel in seconds regenerated per second.", TYPE_FLOAT);
	g_cvarMinimum = RegisterConVar("sm_store_jetpack_minimum", "0.2", "Minimum amount of fuel in seconds needed to start the jetpack.", TYPE_FLOAT);
	g_cvarForce = RegisterConVar("sm_store_jetpack_force", "15.0", "Lifting velocity.", TYPE_FLOAT);
	g_cvarCommand = RegisterConVar("sm_store_jetpack_command", "jetpack", "Command for the jetpack. +/- will be applied to it for toggling", TYPE_STRING);
	
	HookEvent("player_spawn", Jetpack_PlayerSpawn);
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
	g_iJetpackCount = 0;
}

public void Jetpack_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if (!IsValidClient(client, true))
		return;
	
	int equipped = Store_GetEquippedItem(client, "jetpack");
	if (equipped >= 0)
	{
		int jetpackIndex = Store_GetDataIndex(equipped);
		if (jetpackIndex >= 0 && jetpackIndex < g_iJetpackCount)
		{
			g_iCurrentJetpack[client] = jetpackIndex;
			g_fFuel[client] = g_JetpackData[jetpackIndex].fuel;
		}
	}
	else
	{
		g_iCurrentJetpack[client] = -1;
		g_fFuel[client] = 0.0;
	}
	
	g_bJetpacking[client] = false;
	g_fLastUsage[client] = GetGameTime();
}

public void Jetpack_OnClientConnected(int client)
{
	g_bJetpacking[client] = false;
	g_fFuel[client] = 0.0;
	g_fLastUsage[client] = GetGameTime();
	g_fLastHUDTime[client] = 0.0;
	g_iCurrentJetpack[client] = -1;
}

public bool Jetpack_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iJetpackCount);
	
	g_JetpackData[g_iJetpackCount].fuel = kv.GetFloat("fuel", g_eCvars[g_cvarFuel].aCache);
	g_JetpackData[g_iJetpackCount].regen = kv.GetFloat("regen", g_eCvars[g_cvarRegen].aCache);
	g_JetpackData[g_iJetpackCount].force = kv.GetFloat("force", g_eCvars[g_cvarForce].aCache);
	g_JetpackData[g_iJetpackCount].minimum = kv.GetFloat("minimum", g_eCvars[g_cvarMinimum].aCache);
	
	g_iJetpackCount++;
	return true;
}

public int Jetpack_Equip(int client, int id)
{
	int jetpackIndex = Store_GetDataIndex(id);
	if (jetpackIndex >= 0 && jetpackIndex < g_iJetpackCount)
	{
		g_iCurrentJetpack[client] = jetpackIndex;
		g_fFuel[client] = g_JetpackData[jetpackIndex].fuel;
		g_fLastUsage[client] = GetGameTime();
	}
	
	return 0;
}

public int Jetpack_Remove(int client, int id)
{
	g_iCurrentJetpack[client] = -1;
	g_fFuel[client] = 0.0;
	g_bJetpacking[client] = false;
	return 0;
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
	if(!client || !IsValidClient(client))
			return;
	
	if (g_iCurrentJetpack[client] == -1)
		return;
	
	int jetpackIndex = g_iCurrentJetpack[client];
	if (jetpackIndex < 0 || jetpackIndex >= g_iJetpackCount)
		return;
	
	float currentTime = GetGameTime();
	float frameTime = currentTime - g_fLastUsage[client];
	
	if (frameTime > 0.5)
	{
		g_fLastUsage[client] = currentTime;
		return;
	}
	
	if (g_bJetpacking[client])
	{
		if (g_fFuel[client] >= g_JetpackData[jetpackIndex].minimum)
		{
			float velocity[3];
			GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
			
			velocity[2] += g_JetpackData[jetpackIndex].force;
			
			float maxSpeed = 500.0;
			if (velocity[2] > maxSpeed)
				velocity[2] = maxSpeed;
			
			TeleportEntity(client, NULL_VECTOR, NULL_VECTOR, velocity);
			
			g_fFuel[client] -= frameTime;
			if (g_fFuel[client] < 0.0)
				g_fFuel[client] = 0.0;
		}
		else
		{
			g_bJetpacking[client] = false;
			g_fFuel[client] = 0.0;
		}
	}
	
	if (!g_bJetpacking[client] && g_fFuel[client] < g_JetpackData[jetpackIndex].fuel)
	{
		g_fFuel[client] += frameTime * g_JetpackData[jetpackIndex].regen;
		
		if (g_fFuel[client] > g_JetpackData[jetpackIndex].fuel)
			g_fFuel[client] = g_JetpackData[jetpackIndex].fuel;
	}
	
	if (g_fLastHUDTime[client] + 0.1 < currentTime)
	{
		if (g_bJetpacking[client] || g_fFuel[client] < g_JetpackData[jetpackIndex].fuel)
		{
			float percent = (g_fFuel[client] / g_JetpackData[jetpackIndex].fuel) * 100.0;
			
			char progress[32];
			int bars = RoundToFloor(percent / 10.0);
			for (int i = 0; i < 10; i++)
			{
				if (i < bars)
					Format(progress, sizeof(progress), "%s█", progress);
				else
					Format(progress, sizeof(progress), "%s░", progress);
			}
			
			//PrintHintText(client, "Джетпак: %s (%.0f%%)", progress, percent);
			PrintHintText(client, "%t", "Jetpack Fuel", percent);
		}
		
		g_fLastHUDTime[client] = currentTime;
	}
	
	g_fLastUsage[client] = currentTime;
}

#else

void Jetpack_OnPluginStart() {}
void Jetpack_OnConfigsExecuted() {}
void Jetpack_OnClientConnected(int client)
{
	#pragma unused client
}
void Jetpack_OnPlayerRunCmd(int client, int &buttons)
{
	#pragma unused client
	#pragma unused buttons
}

#endif