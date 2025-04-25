#define MAX_TRACER_COLOR_COMPONENT 255

enum struct TracerData
{
	int color[4];
	bool rainbow;
}

int g_cvarTracerMaterial = -1;
int g_cvarTracerLife = -1;
int g_cvarTracerWidth = -1;
int g_bTracerEnable = -1;

TracerData g_tData[STORE_MAX_ITEMS];
int g_iColors = 0;
int g_iBeam = -1;

public void Tracers_OnPluginStart()
{
	g_cvarTracerMaterial = RegisterConVar("sm_store_tracer_material", "materials/sprites/laserbeam.vmt", "Material to be used with tracers", TYPE_STRING);
	g_cvarTracerLife = RegisterConVar("sm_store_tracer_life", "0.5", "Life of a tracer in seconds", TYPE_FLOAT);
	g_cvarTracerWidth = RegisterConVar("sm_store_tracer_width", "0.5", "Width of a tracer", TYPE_FLOAT);
	g_bTracerEnable = RegisterConVar("sm_store_tracer_enable", "1", "Enable the tracer module", TYPE_INT);

	Store_RegisterHandler("tracer", "color", Tracers_OnMapStart, Tracers_Reset, Tracers_Config, Tracers_Equip, Tracers_Remove, true);

	HookEvent("bullet_impact", Tracers_BulletImpact);
}

public void Tracers_OnMapStart()
{
	g_iBeam = PrecacheModel2(g_eCvars[g_cvarTracerMaterial].sCache, true);
}

public void Tracers_Reset()
{
	g_iColors = 0;
}

public bool Tracers_Config(KeyValues &kv, int itemid)
{
	if (g_iColors >= STORE_MAX_ITEMS)
	{
		LogError("Exceeded maximum number of tracer items (%d)", STORE_MAX_ITEMS);
		return false;
	}

	int index = g_iColors;
	Store_SetDataIndex(itemid, index);
	bool configValid = true;

	if (!kv.JumpToKey("color"))
	{
		LogError("Missing required key 'color' for tracer item %d", itemid);
		return false;
	}
	kv.GoBack();

	if (!KvGetColor(kv, "color", g_tData[index].color[0], g_tData[index].color[1], g_tData[index].color[2], g_tData[index].color[3]))
	{
		LogError("Invalid or missing color for tracer item %d", itemid);
		configValid = false;
	}
	else if (g_tData[index].color[3] == 0)
	{
		g_tData[index].color[3] = MAX_TRACER_COLOR_COMPONENT;
	}

	g_tData[index].rainbow = (kv.GetNum("rainbow", 0) != 0);

	if (configValid)
	{
		++g_iColors;
		return true;
	}

	LogError("Tracer configuration failed for item %d due to missing required fields", itemid);
	return false;
}

public int Tracers_Equip(int client, int id)
{
	if (g_eCvars[g_bTracerEnable].aCache != 1)
		return -1;

	if (!IsValidClient(client, true))
		return -1;

	return 0;
}

public int Tracers_Remove(int client, int id)
{
	return 0;
}

public Action Tracers_BulletImpact(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!IsValidClient(client, true))
		return Plugin_Handled;

	if (g_eCvars[g_bTracerEnable].aCache != 1)
		return Plugin_Handled;

	int m_iEquipped = Store_GetEquippedItem(client, "tracer");
	if (m_iEquipped < 0)
		return Plugin_Handled;

	int idx = Store_GetDataIndex(m_iEquipped);
	if (idx < 0 || idx >= g_iColors)
		return Plugin_Handled;

	float m_fPosition[3], m_fImpact[3];
	GetClientEyePosition(client, m_fPosition);
	m_fImpact[0] = GetEventFloat(event, "x");
	m_fImpact[1] = GetEventFloat(event, "y");
	m_fImpact[2] = GetEventFloat(event, "z");
	
	float direction[3];
	MakeVectorFromPoints(m_fPosition, m_fImpact, direction);
	NormalizeVector(direction, direction);

	// Сдвигаем начало луча чуть дальше от игрока
	float offset = 25.0;
	m_fPosition[0] += direction[0] * offset;
	m_fPosition[1] += direction[1] * offset;
	m_fPosition[2] += direction[2] * offset;
	
	//float offsetDown = 10.0;
	//m_fPosition[2] -= offsetDown;
	
	int color[4];
	if (g_tData[idx].rainbow)
	{
		color[0] = GetRandomInt(0, 255);
		color[1] = GetRandomInt(0, 255);
		color[2] = GetRandomInt(0, 255);
		color[3] = 255;
	}
	else
	{
		color[0] = g_tData[idx].color[0];
		color[1] = g_tData[idx].color[1];
		color[2] = g_tData[idx].color[2];
		color[3] = g_tData[idx].color[3];
	}

	int clients[MAXPLAYERS + 1];
	int numClients = 0;
	for (int i = 1; i <= MaxClients; i++)
	{
		if (IsValidClient(i, true))
		{
			clients[numClients++] = i;
		}
	}

	if (numClients < 1)
		return Plugin_Handled;

	TE_SetupBeamPoints(
		m_fPosition, m_fImpact, g_iBeam, 0, 0, 0,
		view_as<float>(g_eCvars[g_cvarTracerLife].aCache),
		view_as<float>(g_eCvars[g_cvarTracerWidth].aCache),
		view_as<float>(g_eCvars[g_cvarTracerWidth].aCache),
		1, 0.0, color, 0
	);

	TE_Send(clients, numClients, 0.0);
	return Plugin_Continue;
}