enum struct Glow
{
	char GlowColor[16];
	char GlowBrightness[8];
	char GlowStyle[4];
	float GlowflRadius;
	float GlowflDistance;
}

Glow g_eGlow[STORE_MAX_ITEMS];
int g_iGlow = 0;
int g_unClientGlow[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};
int g_unSelectedGlow[MAXPLAYERS + 1] = {-1, ...};

public void Glow_OnPluginStart()
{
	Store_RegisterHandler("glow", "color", Glow_OnMapStart, Glow_Reset, Glow_Config, Glow_Equip, Glow_Remove, true);
}

public void Glow_OnMapStart()
{
}

public void Glow_Reset()
{
	g_iGlow = 0;
}

public bool Glow_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iGlow);
	
	kv.GetString("color", g_eGlow[g_iGlow].GlowColor, sizeof(Glow::GlowColor));
	kv.GetString("brightness", g_eGlow[g_iGlow].GlowBrightness, sizeof(Glow::GlowBrightness), "5");
	kv.GetString("style", g_eGlow[g_iGlow].GlowStyle, sizeof(Glow::GlowStyle), "0");
	g_eGlow[g_iGlow].GlowflDistance = kv.GetFloat("distance", 200.0);
	g_eGlow[g_iGlow].GlowflRadius = kv.GetFloat("radius", 100.0);
	
	++g_iGlow;
	return true;
}

public int Glow_Equip(int client, int id)
{
	g_unSelectedGlow[client] = Store_GetDataIndex(id);
	ResetGlow(client);
	CreateGlow(client);
	return 0;
}

public int Glow_Remove(int client)
{
	ResetGlow(client);
	g_unSelectedGlow[client] = -1;
	return 0;
}

public void Glow_OnClientConnected(int client)
{
	g_unSelectedGlow[client] = -1;
}

public void Glow_OnClientDisconnect(int client)
{
	g_unSelectedGlow[client] = -1;
}

public Action Glow_PlayerSpawn(int client)
{
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client) || !(2 <= GetClientTeam(client) <= 3))
		return Plugin_Continue;

	CreateTimer(0.1, Glow_PlayerSpawn_Post, GetClientUserId(client));

	return Plugin_Continue;
}

public Action Glow_PlayerSpawn_Post(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client) || !(2 <= GetClientTeam(client) <= 3))
		return Plugin_Stop;

	ResetGlow(client);
	CreateGlow(client);
	return Plugin_Stop;
}

public Action Glow_PlayerDeath(int client)
{
	if(!client || !IsClientInGame(client))
		return Plugin_Continue;

	ResetGlow(client);

	return Plugin_Continue;
}

public Action Glow_PlayerTeam(int client)
{
	if(!client || !IsClientInGame(client))
		return Plugin_Continue;

	ResetGlow(client);

	return Plugin_Continue;
}

public void CreateGlow(int client)
{
	if(g_unClientGlow[client] != INVALID_ENT_REFERENCE)
		return;

	if(g_unSelectedGlow[client] == -1)
		return;

	int m_iData = g_unSelectedGlow[client];

	int m_unEnt = CreateEntityByName("light_dynamic");
	if(IsValidEntity(m_unEnt))
	{
		float m_flClientOrigin[3];
		GetClientAbsOrigin(client, m_flClientOrigin);
		m_flClientOrigin[2] += 5.0;

		DispatchKeyValue(m_unEnt, "_light", g_eGlow[m_iData].GlowColor); 
		DispatchKeyValue(m_unEnt, "brightness", g_eGlow[m_iData].GlowBrightness); 
		DispatchKeyValueFloat(m_unEnt, "spotlight_radius", g_eGlow[m_iData].GlowflRadius); 
		DispatchKeyValueFloat(m_unEnt, "distance", g_eGlow[m_iData].GlowflDistance); 
		DispatchKeyValue(m_unEnt, "style", g_eGlow[m_iData].GlowStyle);  

		DispatchSpawn(m_unEnt); 
		TeleportEntity(m_unEnt, m_flClientOrigin, NULL_VECTOR, NULL_VECTOR); 
		
		// Teleport the pet to the right position and attach it
		TeleportEntity(m_unEnt, m_flClientOrigin, NULL_VECTOR, NULL_VECTOR); 
		
		SetVariantString("!activator");
		AcceptEntityInput(m_unEnt, "SetParent", client, m_unEnt, 0);
		
		SetVariantString("letthehungergamesbegin");
		AcceptEntityInput(m_unEnt, "SetParentAttachmentMaintainOffset", m_unEnt, m_unEnt, 0);
	  
		g_unClientGlow[client] = EntIndexToEntRef(m_unEnt);
		// Note: g_unLastAnimation is not defined in this module, возможно нужно убрать эту строку
		// g_unLastAnimation[client] = -1;
	}
}

public void ResetGlow(int client)
{
	if(g_unClientGlow[client] == INVALID_ENT_REFERENCE)
		return;

	int m_unEnt = EntRefToEntIndex(g_unClientGlow[client]);
	g_unClientGlow[client] = INVALID_ENT_REFERENCE;
	if(m_unEnt == INVALID_ENT_REFERENCE)
		return;

	AcceptEntityInput(m_unEnt, "Kill");
}