enum struct PlayerSkin
{
	char szModel[PLATFORM_MAX_PATH];
	int iSkin;
	int iBody;
	int iTeam;
	int nModelIndex;
}

PlayerSkin g_ePlayerSkins[STORE_MAX_ITEMS];

int g_iPlayerSkins = 0;
int g_bSkinEnable;

public void PlayerSkins_OnPluginStart()
{
	Store_RegisterHandler("playerskin", "model", PlayerSkins_OnMapStart, PlayerSkins_Reset, PlayerSkins_Config, PlayerSkins_Equip, PlayerSkins_Remove, true);
	g_bSkinEnable = RegisterConVar("sm_store_playerskin_enable", "1", "Enable the player skin module", TYPE_INT);
	
	HookEvent("player_spawn", PlayerSkins_PlayerSpawn);
}

public void PlayerSkins_OnMapStart()
{
	for(int i=0;i<g_iPlayerSkins;++i)
	{
		g_ePlayerSkins[i].nModelIndex = PrecacheModel2(g_ePlayerSkins[i].szModel, true);
		Downloader_AddFileToDownloadsTable(g_ePlayerSkins[i].szModel);
	}
}

public void PlayerSkins_Reset()
{
	g_iPlayerSkins = 0;
}

public bool PlayerSkins_Config(KeyValues &kv, int itemid) 
{
	Store_SetDataIndex(itemid, g_iPlayerSkins);
	int currentIndex = g_iPlayerSkins;
	bool configValid = true;

	if(!kv.GetString("model", g_ePlayerSkins[currentIndex].szModel, PLATFORM_MAX_PATH) || !g_ePlayerSkins[currentIndex].szModel[0])
	{
		LogError("Missing or empty 'model' value for player skin %d", itemid);
		configValid = false;
	}

	g_ePlayerSkins[currentIndex].iSkin = kv.GetNum("skin", 0);
	g_ePlayerSkins[currentIndex].iBody = kv.GetNum("body", -1);
	g_ePlayerSkins[currentIndex].iTeam = kv.GetNum("team", 0);

	if(!FileExists(g_ePlayerSkins[currentIndex].szModel, true))
	{
		LogError("Model file not found for player skin %d: %s", itemid, g_ePlayerSkins[currentIndex].szModel);
		configValid = false;
	}

	if(configValid)
	{
		g_iPlayerSkins++;
		return true;
	}
	
	return false;
}

public int PlayerSkins_Equip(int client, int id)
{
	int m_iData = Store_GetDataIndex(id);

	int Team = g_ePlayerSkins[m_iData].iTeam;
	int clientTeam = GetClientTeam(client);
	
	if (g_eCvars[g_bSkinEnable].aCache == 1)
	{	
		if(IsPlayerAlive(client) && IsValidClient(client, true) && (Team == 4 || clientTeam == Team))
		{
			Store_SetClientModel(client, g_ePlayerSkins[m_iData].szModel, g_ePlayerSkins[m_iData].iSkin, g_ePlayerSkins[m_iData].iBody);
		}
		
		else if(Store_IsClientLoaded(client))
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s%t", g_sChatPrefix_CM, "PlayerSkins Settings Changed CM");
				C_PrintToChat(client, "%s%t", g_sChatPrefix, "PlayerSkins Settings Changed");
			#else
				PrintToChat(client, "%s%t", g_sChatPrefix, "PlayerSkins Settings Changed");
			#endif
		}
	}
	
	else
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s%t", g_sChatPrefix_CM, "Player Skin module disabled CM");
			C_PrintToChat(client, "%s%t", g_sChatPrefix, "Player Skin module disabled");
		#else
			PrintToChat(client, "%s%t", g_sChatPrefix, "Player Skin module disabled");
		#endif
		return -1;
	}
	
	return (g_ePlayerSkins[Store_GetDataIndex(id)].iTeam)-2;
}

public int PlayerSkins_Remove(int client, int id)
{
	if (g_eCvars[g_bSkinEnable].aCache != 1)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s%t", g_sChatPrefix_CM, "Player Skin module disabled CM");
			C_PrintToChat(client, "%s%t", g_sChatPrefix, "Player Skin module disabled");
		#else
			PrintToChat(client, "%s%t", g_sChatPrefix, "Player Skin module disabled");
		#endif
	}
	
	if (Store_IsClientLoaded(client) && IsValidClient(client, true) && IsPlayerAlive(client) && IsClientInGame(client))
	{
		CS_UpdateClientModel(client);
	}
	else
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s%t", g_sChatPrefix_CM, "PlayerSkins Settings Changed CM");
			C_PrintToChat(client, "%s%t", g_sChatPrefix, "PlayerSkins Settings Changed");
		#else
			PrintToChat(client, "%s%t", g_sChatPrefix, "PlayerSkins Settings Changed");
		#endif
	}
	
	return view_as<int>(g_ePlayerSkins[Store_GetDataIndex(id)].iTeam)-2;
}

public Action PlayerSkins_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (g_eCvars[g_bSkinEnable].aCache == 1)
	{
		if(!IsClientInGame(client) || !IsPlayerAlive(client) || !(2<=GetClientTeam(client)<=3))
			return Plugin_Continue;
		
		RequestFrame(RequestFrame_PlayerSkins_PlayerSpawnPost, client);
	}
	
	else
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s%t", g_sChatPrefix_CM, "Player Skin module disabled CM");
			C_PrintToChat(client, "%s%t", g_sChatPrefix, "Player Skin module disabled");
		#else
			PrintToChat(client, "%s%t", g_sChatPrefix, "Player Skin module disabled");
		#endif
	}
	
	return Plugin_Continue;
}

public void RequestFrame_PlayerSkins_PlayerSpawnPost(int client)
{
	if(!client || !IsClientInGame(client) || (IsValidClient(client, true) && !IsPlayerAlive(client)))
		return;
		
	int m_iEquipped = Store_GetEquippedItem(client, "playerskin", 2);
	if(m_iEquipped < 0)
		m_iEquipped = Store_GetEquippedItem(client, "playerskin", GetClientTeam(client)-2);
	
	if(m_iEquipped >= 0)
	{
		int m_iData = Store_GetDataIndex(m_iEquipped);
		Store_SetClientModel(client, g_ePlayerSkins[m_iData].szModel, g_ePlayerSkins[m_iData].iSkin, g_ePlayerSkins[m_iData].iBody);
	}

	return;
}

void Store_SetClientModel(int client, const char[] model, const int skin=0, const int body=0)
{

	SetEntityModel(client, model);

	SetEntProp(client, Prop_Send, "m_nSkin", skin);
	
	if (body > 0)
    {
        // set?
		SetEntProp(client, Prop_Send, "m_nBody", body);
    }
}

public void PlayerSkin_OnPreviewItem(int client, char[] type, int index)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}
	
	if (!StrEqual(type, "playerskin"))
		return;

	int iPreview = CreateEntityByName("prop_dynamic_override"); //prop_physics_multiplayer
	
	if (iPreview == -1)
	{
		LogError("Failed to create preview entity for client %d", client);
		return;
	}
	
	if (g_hTimerPreview[client] != null) 
	{
        delete g_hTimerPreview[client];
        g_hTimerPreview[client] = null;
	} 

	DispatchKeyValue(iPreview, "spawnflags", "64");
	DispatchKeyValue(iPreview, "model", g_ePlayerSkins[index].szModel);

	DispatchSpawn(iPreview);

	SetEntProp(iPreview, Prop_Send, "m_CollisionGroup", 11);

	AcceptEntityInput(iPreview, "Enable");

	SetEntProp(iPreview, Prop_Send, "m_nSkin", g_ePlayerSkins[index].iSkin);
	
	if (g_ePlayerSkins[index].iBody > 0)
	{
		SetEntProp(iPreview, Prop_Send, "m_nBody", g_ePlayerSkins[index].iBody);
	}

	float fOrigin[3], fAngles[3], fRad[2], fPosition[3];

	GetClientAbsOrigin(client, fOrigin);
	GetClientAbsAngles(client, fAngles);

	fRad[0] = DegToRad(fAngles[0]);
	fRad[1] = DegToRad(fAngles[1]);

	fPosition[0] = fOrigin[0] + 64 * Cosine(fRad[0]) * Cosine(fRad[1]);
	fPosition[1] = fOrigin[1] + 64 * Cosine(fRad[0]) * Sine(fRad[1]);
	fPosition[2] = fOrigin[2] + 4 * Sine(fRad[0]);

	fAngles[0] *= -1.0;
	fAngles[1] *= -1.0;

	fPosition[2] += 5;

	TeleportEntity(iPreview, fPosition, fAngles, NULL_VECTOR);

	g_iPreviewEntity[client] = EntIndexToEntRef(iPreview);

	int iRotator = CreateEntityByName("func_rotating");
	DispatchKeyValueVector(iRotator, "origin", fPosition);

	DispatchKeyValue(iRotator, "maxspeed", "20");
	DispatchKeyValue(iRotator, "spawnflags", "64");
	DispatchSpawn(iRotator);

	SetVariantString("!activator");
	AcceptEntityInput(iPreview, "SetParent", iRotator, iRotator);
	AcceptEntityInput(iRotator, "Start");

	SDKHook(iPreview, SDKHook_SetTransmit, PlayerSkin_Hook_SetTransmit_Preview);

	g_hTimerPreview[client] = CreateTimer(45.0, PlayerSkin_Timer_KillPreview, client);

	#if defined _clientmod_included
		MC_PrintToChat(client, "%s%t", g_sChatPrefix_CM, "Spawn Preview CM");
		C_PrintToChat(client, "%s%t", g_sChatPrefix, "Spawn Preview");
	#else
		PrintToChat(client, "%s%t", g_sChatPrefix, "Spawn Preview");
	#endif
}

public Action PlayerSkin_Hook_SetTransmit_Preview(int ent, int client)
{
	if (g_iPreviewEntity[client] == INVALID_ENT_REFERENCE)
		return Plugin_Handled;

	if (ent == EntRefToEntIndex(g_iPreviewEntity[client]))
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action PlayerSkin_Timer_KillPreview(Handle timer, int client)
{
	g_hTimerPreview[client] = null;

	if (g_iPreviewEntity[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iPreviewEntity[client]);

		if (entity > 0 && IsValidEdict(entity))
		{
			SDKUnhook(entity, SDKHook_SetTransmit, PlayerSkin_Hook_SetTransmit_Preview);
			AcceptEntityInput(entity, "Kill");
		}
		else
		{
			LogError("PlayerSkin_Timer_KillPreview: Invalid or non-existent entity for client %d", client);
			return Plugin_Stop;
		}
	}
	g_iPreviewEntity[client] = INVALID_ENT_REFERENCE;

	return Plugin_Stop;
}