enum struct Jihad
{
	float flRadius;
	float flDamage;
	bool bSilent;
	float flDelay;
	float flFailrate;
}

Jihad g_eJihads[STORE_MAX_ITEMS];

int g_iJihads = 0;
int g_iExplosion = -1;

int g_cvarJihadTK;
int g_cvarJihadTeam;
int g_cvarJihadExplosionSound;
int g_cvarJihadBeforeSound;

public void Jihad_OnPluginStart()
{
	Store_RegisterHandler("jihad", "", Jihad_OnMapStart, Jihad_Reset, Jihad_Config, Jihad_Equip, Jihad_Remove, false);

	g_cvarJihadTK = RegisterConVar("sm_store_jihad_teamkill", "0", "Defines whether the bombs kill teammates or not.", TYPE_INT);
	g_cvarJihadTeam = RegisterConVar("sm_store_jihad_team", "0", "Team that can use the bomb. 0=Any 2=Terrorist 3=Counter-Terrorist", TYPE_INT);
	g_cvarJihadExplosionSound = RegisterConVar("sm_store_jihad_explosion_sound", "ambient/explosions/explode_1.wav", "Path to the explosion sound", TYPE_STRING);
	g_cvarJihadBeforeSound = RegisterConVar("sm_store_jihad_activation_sound", "npc/roller/mine/combine_mine_active_loop1.wav", "Path to the activation sound", TYPE_STRING);
}

public void Jihad_OnConfigsExecuted()
{
	char m_szSound[PLATFORM_MAX_PATH];
	if(g_eCvars[g_cvarJihadExplosionSound].sCache[0] != 0 && FileExists(g_eCvars[g_cvarJihadExplosionSound].sCache, true))
	{
		PrecacheSound(g_eCvars[g_cvarJihadExplosionSound].sCache);
		Format(m_szSound, sizeof(m_szSound), "sound/%s", g_eCvars[g_cvarJihadExplosionSound].sCache);
		AddFileToDownloadsTable(m_szSound);
	}
	
	if(g_eCvars[g_cvarJihadBeforeSound].sCache[0] != 0 && FileExists(g_eCvars[g_cvarJihadBeforeSound].sCache, true))
	{
		PrecacheSound(g_eCvars[g_cvarJihadBeforeSound].sCache);
		Format(m_szSound, sizeof(m_szSound), "sound/%s", g_eCvars[g_cvarJihadBeforeSound].sCache);
		AddFileToDownloadsTable(m_szSound);
	}
}

public void Jihad_OnMapStart()
{
	g_iExplosion = PrecacheModel2("materials/effects/fire_cloud1.vmt", false);
}

public void Jihad_Reset()
{
	g_iJihads = 0;
}

public bool Jihad_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iJihads);
	
	g_eJihads[g_iJihads].flRadius = kv.GetFloat("radius");
	g_eJihads[g_iJihads].flDamage = kv.GetFloat("damage");
	g_eJihads[g_iJihads].bSilent = (kv.GetNum("silent") ? true : false);
	g_eJihads[g_iJihads].flDelay = kv.GetFloat("delay");
	g_eJihads[g_iJihads].flFailrate = kv.GetFloat("failrate");

	++g_iJihads;
	return true;
}

public int Jihad_Equip(int client, int id)
{
	int m_iData = Store_GetDataIndex(id);
	
	if(g_eCvars[g_cvarJihadTeam].aCache != 0 && g_eCvars[g_cvarJihadTeam].aCache != GetClientTeam(client))
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Jihad Wrong Team CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Jihad Wrong Team");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Jihad Wrong Team");
		#endif
		return 1;
	}

	if(!g_eJihads[m_iData].bSilent)
		if(g_eCvars[g_cvarJihadBeforeSound].sCache[0] != 0)
			EmitAmbientSound(g_eCvars[g_cvarJihadBeforeSound].sCache, NULL_VECTOR, client);
	
	DataPack data = new DataPack();
	data.WriteCell(GetClientUserId(client));
	data.WriteCell(m_iData);
	data.Reset();

	CreateTimer(g_eJihads[m_iData].flDelay, Jihad_TriggerBomb, data);

	return 0;
}

public int Jihad_Remove(int client)
{
	return 0;
}

public Action Jihad_TriggerBomb(Handle timer, DataPack data)
{
	data.Reset();
	int userid = data.ReadCell();
	int m_iData = data.ReadCell();
	delete data;

	int client = GetClientOfUserId(userid);
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Stop;

	if(GetRandomFloat() <= g_eJihads[m_iData].flFailrate)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Jihad Failed CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Jihad Failed");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Jihad Failed");
		#endif
		return Plugin_Stop;
	}
	
	if(g_eCvars[g_cvarJihadBeforeSound].sCache[0] != 0)
		EmitAmbientSound(g_eCvars[g_cvarJihadExplosionSound].sCache, NULL_VECTOR, client);
	
	float m_flPos[3];
	float m_flPos2[3];
	float m_flPush[3];

	GetClientAbsOrigin(client, m_flPos);

	TE_SetupSmoke(m_flPos, g_iExplosion, 10.0, 10);
	TE_SendToAll();

	DataPack m_hData = new DataPack();
	m_hData.WriteCell(0);
	m_hData.WriteCell(client);
	m_hData.WriteFloat(float(GetClientHealth(client)) * 10);
	m_hData.WriteFloat(0.0);
	m_hData.WriteFloat(0.0);
	m_hData.WriteFloat(100.0);
	m_hData.Reset();

	CreateTimer(0.0, ExplodePlayer, m_hData);
	
	float m_flDistance;
	LoopAlivePlayers(i)
	{
		if(!g_eCvars[g_cvarJihadTK].aCache && GetClientTeam(i) == GetClientTeam(client))
			continue;
		
		GetClientAbsOrigin(i, m_flPos2);
		m_flDistance = GetVectorDistance(m_flPos, m_flPos2);
		
		if(m_flDistance <= g_eJihads[m_iData].flRadius)
		{
			MakeVectorFromPoints(m_flPos, m_flPos2, m_flPush);
			ScaleVector(m_flPush, 50.0);
			m_flPush[2] += 50.0;

			m_hData = new DataPack();
			m_hData.WriteCell(client);
			m_hData.WriteCell(i);
			m_hData.WriteFloat(g_eJihads[m_iData].flDamage * ((g_eJihads[m_iData].flRadius - m_flDistance) / g_eJihads[m_iData].flRadius));
			m_hData.WriteFloat(m_flPush[0]);
			m_hData.WriteFloat(m_flPush[1]);
			m_hData.WriteFloat(m_flPush[2]);
			m_hData.Reset();

			CreateTimer(0.0, ExplodePlayer, m_hData);
		}
	}

	return Plugin_Stop;
}

public Action ExplodePlayer(Handle timer, DataPack data)
{
	data.Reset();
	int attacker = data.ReadCell();
	int victim = data.ReadCell();
	float damage = data.ReadFloat();
	float vec[3];
	vec[0] = data.ReadFloat();
	vec[1] = data.ReadFloat();
	vec[2] = data.ReadFloat();
	delete data;

	SDKHooks_TakeDamage(victim, attacker, attacker, damage, DMG_BLAST, -1, vec);
	return Plugin_Stop;
}