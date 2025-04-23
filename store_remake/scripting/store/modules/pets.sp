enum struct PetData 
{
    char model[PLATFORM_MAX_PATH];
    char run[64];
    char idle[64];
    char idle2[64];
    char spawn[64];
    char death[64];
    float position[3];
    float angles[3];
    float spawnTimeDelay;
	int ModelIndex;
}

PetData g_ePetsData[STORE_MAX_ITEMS];

int g_iPetCount = 0;
int g_bPetEnable;

int g_iClientPet[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};
int g_iSelectedPet[MAXPLAYERS + 1] = {-1,...};
int g_iLastAnimation[MAXPLAYERS + 1] = {-1,...};
static int g_iLastIdleTimes[MAXPLAYERS+1] = {-1,...};
static int g_iLastSpawnTime[MAXPLAYERS+1] = {-1,...};

public void Pets_OnPluginStart()
{
	Store_RegisterHandler("pet", "model", Pets_OnMapStart, Pets_Reset, Pets_Config, Pets_Equip, Pets_Remove, true);
	g_bPetEnable = RegisterConVar("sm_store_pets_enable", "1", "Enable the pet module", TYPE_INT);

	HookEvent("player_spawn", Pets_PlayerSpawn);
	HookEvent("player_death", Pets_PlayerDeath);
}


public void Pets_OnMapStart()
{
	for (int i = 0; i < g_iPetCount; i++)
	{
		g_ePetsData[i].ModelIndex = PrecacheModel(g_ePetsData[i].model, true);
		Downloader_AddFileToDownloadsTable(g_ePetsData[i].model);
	}
}

public void Pets_Reset()
{
	g_iPetCount = 0;
}

public bool Pets_Config(KeyValues &kv, int itemid) 
{
	Store_SetDataIndex(itemid, g_iPetCount);
	int currentIndex = g_iPetCount;
	bool configValid = true;

	if(!kv.JumpToKey("model"))
	{
		LogError("Missing required key 'model' for pet %d", itemid);
		return false;
	}
	kv.GoBack();

	if(!kv.GetString("model", g_ePetsData[currentIndex].model, sizeof(g_ePetsData[].model)) || !g_ePetsData[currentIndex].model[0])
	{
		LogError("Missing or empty 'model' value for pet %d", itemid);
		configValid = false;
	}

	if(!kv.GetString("idle", g_ePetsData[currentIndex].idle, sizeof(g_ePetsData[].idle)) || !g_ePetsData[currentIndex].idle[0])
		LogError("Warning: Missing or empty 'idle' animation for pet %d", itemid);

	if(!kv.GetString("idle2", g_ePetsData[currentIndex].idle2, sizeof(g_ePetsData[].idle2)) || !g_ePetsData[currentIndex].idle2[0])
		LogMessage("Optional 'idle2' animation not specified for pet %d", itemid);

	if(!kv.GetString("run", g_ePetsData[currentIndex].run, sizeof(g_ePetsData[].run)) || !g_ePetsData[currentIndex].run[0])
	{
		LogError("Missing or empty 'run' animation for pet %d", itemid);
		configValid = false;
	}

	if(!kv.GetString("spawn", g_ePetsData[currentIndex].spawn, sizeof(g_ePetsData[].spawn)) || !g_ePetsData[currentIndex].spawn[0])
		LogMessage("Optional 'spawn' animation not specified for pet %d", itemid);

	if(!kv.GetString("death", g_ePetsData[currentIndex].death, sizeof(g_ePetsData[].death)) || !g_ePetsData[currentIndex].death[0])
		LogMessage("Optional 'death' animation not specified for pet %d", itemid);

	if(!kv.GetVector("position", g_ePetsData[currentIndex].position))
	{
		LogError("Missing or invalid 'position' for pet %d", itemid);
		g_ePetsData[currentIndex].position = {0.0, 0.0, 0.0};
		configValid = false;
	}

	if(!kv.GetVector("angles", g_ePetsData[currentIndex].angles))
	{
		LogError("Missing or invalid 'angles' for pet %d", itemid);
		g_ePetsData[currentIndex].angles = {0.0, 0.0, 0.0};
		configValid = false;
	}

	g_ePetsData[currentIndex].spawnTimeDelay = kv.GetFloat("spawn_delay", 1.0);

	if(!FileExists(g_ePetsData[currentIndex].model, true))
	{
		LogError("Model file not found for pet %d: %s", itemid, g_ePetsData[currentIndex].model);
		configValid = false;
	}

	if(configValid)
	{
		g_iPetCount++;
		return true;
	}
	
	LogError("Pet configuration failed for item %d due to missing required fields", itemid);
	return false;
}

public int Pets_Equip(int client, int itemid)
{
	if(g_eCvars[g_bPetEnable].aCache != 1)
		return -1;

	g_iSelectedPet[client] = Store_GetDataIndex(itemid);
	ResetPet(client);
	if(IsPlayerAlive(client))
		CreatePet(client);

	return 0;
}

public int Pets_Remove(int client, int itemid)
{
	ResetPet(client);
	g_iSelectedPet[client] = -1;

	return 0;
}

public void Pets_OnClientConnected(int client)
{
	g_iSelectedPet[client] = -1;
}

public void Pets_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(!IsValidClient(client, true) || GetClientTeam(client) < 2 || g_eCvars[g_bPetEnable].aCache != 1)
		return;

	RequestFrame(RequestFrame_CreatePetPost, client);
}

public void RequestFrame_CreatePetPost(int client)
{
	ResetPet(client);
	CreatePet(client);
}

public void Pets_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (!IsValidClient(client, true))
		return;
	
	Store_ClientDeathPet(client);
}

public Action Pets_OnPlayerRunCmd(int client, int &tickcount)
{
	if (!IsValidClient(client, true) || g_iClientPet[client] == INVALID_ENT_REFERENCE || tickcount % 5 != 0)
		return Plugin_Continue;

	int time = GetTime();

	if (time < g_iLastSpawnTime[client])
        return Plugin_Continue;
	
	if (tickcount % 5 == 0 && EntRefToEntIndex(g_iClientPet[client]) != -1)
	{
		float fVec[3];
		float fDist;
		GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVec);
		fDist = GetVectorLength(fVec);
		if (g_iLastAnimation[client] != 1 && fDist > 0.0)
		{
			SetVariantString(g_ePetsData[g_iSelectedPet[client]].run);
			AcceptEntityInput(EntRefToEntIndex(g_iClientPet[client]), "SetAnimation");

			g_iLastAnimation[client] = 1;
		}
		else if (g_iLastAnimation[client] != 2 && fDist == 0.0 && g_ePetsData[g_iSelectedPet[client]].idle[0])
		{			
			if (g_iLastIdleTimes[client] < time && g_ePetsData[g_iSelectedPet[client]].idle2[0])
			{
				g_iLastSpawnTime[client] = time + 2;
				g_iLastIdleTimes[client] = time + 15;
				SetVariantString(g_ePetsData[g_iSelectedPet[client]].idle2);
			}
			else
			{
				SetVariantString(g_ePetsData[g_iSelectedPet[client]].idle);
			}
			AcceptEntityInput(EntRefToEntIndex(g_iClientPet[client]), "SetAnimation");
			g_iLastAnimation[client] = 2;
		}
	}

	return Plugin_Continue;
}

void Store_ClientDeathPet(int client)
{
	DeathPet(client);
}

void DeathPet(int client)
{
    if(g_iClientPet[client] == INVALID_ENT_REFERENCE)
        return;

    int entity = EntRefToEntIndex(g_iClientPet[client]);

    if(!IsValidEdict(entity))
        return;
    
    int m_iData = Store_GetDataIndex(Store_GetEquippedItem(client, "pet"));
    
    if(g_ePetsData[m_iData].death[0] == '\0')
    {
        ResetPet(client);
        return;
    }
    
    SetVariantString(g_ePetsData[m_iData].death);
    AcceptEntityInput(EntRefToEntIndex(g_iClientPet[client]), "SetAnimation");
    g_iLastAnimation[client] = 3;
    HookSingleEntityOutput(entity, "OnAnimationDone", Hook_OnAnimationDone, true);
}

public void Hook_OnAnimationDone(const char[] output, int caller, int activator, float delay)
{
    if(!IsValidEdict(caller))
        return;

    int owner = GetEntPropEnt(caller, Prop_Send, "m_hOwnerEntity");

    if(1 <= owner <= MaxClients && IsClientInGame(owner))
    {
        int iRef = EntIndexToEntRef(caller);
        for(int slot = 0; slot < STORE_MAX_SLOTS; ++slot)
            if(g_iClientPet[owner] == iRef)
                g_iClientPet[owner] = INVALID_ENT_REFERENCE;
    }

    AcceptEntityInput(caller, "Kill");
}

void CreatePet(int client)
{	
	if (g_iClientPet[client] != INVALID_ENT_REFERENCE || g_iSelectedPet[client] < 0)
		return;
	
	if(!IsValidClient(client, true) || GetClientTeam(client) < 2)
		return;
	
	int iIndex = g_iSelectedPet[client];

	int iEntity = CreateEntityByName("prop_dynamic_override");//prop_dynamic_override
	if (IsValidEntity(iEntity))
	{
		float fPos[3];
		float fAng[3];
		float fOri[3];
		float flClientAngles[3];
		GetClientAbsOrigin(client, fOri);
		GetClientAbsAngles(client, flClientAngles);
		
		fPos[0] = g_ePetsData[iIndex].position[0];
		fPos[1] = g_ePetsData[iIndex].position[1];
		fPos[2] = g_ePetsData[iIndex].position[2];
		fAng[0] = g_ePetsData[iIndex].angles[0];
		fAng[1] = g_ePetsData[iIndex].angles[1];
		fAng[2] = g_ePetsData[iIndex].angles[2];

		float fForward[3];
		float fRight[3];
		float fUp[3];
		GetAngleVectors(flClientAngles, fForward, fRight, fUp);

		fOri[0] += fRight[0] * fPos[0] + fForward[0] * fPos[1] + fUp[0] * fPos[2];
		fOri[1] += fRight[1] * fPos[0] + fForward[1] * fPos[1] + fUp[1] * fPos[2];
		fOri[2] += fRight[2] * fPos[0] + fForward[2] * fPos[1] + fUp[2] * fPos[2];
		
		fAng[1] += flClientAngles[1];

		DispatchKeyValue(iEntity, "model", g_ePetsData[iIndex].model);
		DispatchKeyValue(iEntity, "spawnflags", "256");
		DispatchKeyValue(iEntity, "solid", "0");		
		SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", client);

		DispatchSpawn(iEntity);
		AcceptEntityInput(iEntity, "TurnOn", iEntity, iEntity, 0);
		
		// Teleport the pet to the right fPosition and attach it
		TeleportEntity(iEntity, fOri, fAng, NULL_VECTOR); 
		
		/*------------------------------------------------------------------------*/
		SetVariantString("!activator");
		AcceptEntityInput(iEntity, "SetParent", client, iEntity, 0);
		/*------------------------------------------------------------------------*/
		
		/*SDKHook(client, SDKHook_PreThink, PetThink);	This lag animations -_-	  */
		
		g_iClientPet[client] = EntIndexToEntRef(iEntity);
		g_iLastAnimation[client] = -1;
		
		Set_EdictFlags(iEntity);
		
		if (g_ePetsData[iIndex].spawn[0])
	    {
	    	g_iLastSpawnTime[client] = GetTime() + view_as<int>(RoundToCeil(g_ePetsData[iIndex].spawnTimeDelay));
	        SetVariantString(g_ePetsData[iIndex].spawn);
	        AcceptEntityInput(EntRefToEntIndex(g_iClientPet[client]), "SetAnimation");
	    }
	}
}

void Set_EdictFlags(int edict)
{
	if (GetEdictFlags(edict) & FL_EDICT_ALWAYS)
	{
		SetEdictFlags(edict, (GetEdictFlags(edict) ^ FL_EDICT_ALWAYS));
	}
}

public void PetThink(int client)
{
	int iIndex = g_iSelectedPet[client];
	int iEntity = EntRefToEntIndex(g_iClientPet[client]);
	if (!IsValidEntity(iEntity))
	{
		SDKUnhook(client, SDKHook_PreThink, PetThink);
		return;
	}

	float pos[3];
	float ang[3];
	float clientPos[3];
	GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", pos);
	GetEntPropVector(iEntity, Prop_Data, "m_angRotation", ang);
	GetClientAbsOrigin(client, clientPos);

	float fDist = GetVectorDistance(clientPos, pos);
	float distX = clientPos[0] - pos[0];
	float distY = clientPos[1] - pos[1];
	float speed = (fDist - 64.0) / 54;
	Math_Clamp(speed, -4.0, 4.0);
	if (FloatAbs(speed) < 0.3)
		speed *= 0.1;

	// Teleport to owner if too far
	if (fDist > 1024.0)
	{
		float posTmp[3];
		GetClientAbsOrigin(client, posTmp);
		OffsetLocation(posTmp);
		TeleportEntity(iEntity, posTmp, NULL_VECTOR, NULL_VECTOR);
		GetEntPropVector(iEntity, Prop_Data, "m_vecOrigin", pos);
	}

	// Set new location data
	if (pos[0] < (clientPos[0] + g_ePetsData[iIndex].position[0]))pos[0] += speed;
	if (pos[0] > (clientPos[0] - g_ePetsData[iIndex].position[0]))pos[0] -= speed;
	if (pos[1] < (clientPos[1] + g_ePetsData[iIndex].position[1]))pos[1] += speed;
	if (pos[1] > (clientPos[1] - g_ePetsData[iIndex].position[1]))pos[1] -= speed;

	// Height
	int selectedPet = g_iSelectedPet[client];
	float petoff = g_ePetsData[selectedPet].position[2];

	pos[2] = clientPos[2] + 100.0;
	float distZ = GetClientDistanceToGround(iEntity, client, pos[2]); 
	if (distZ < 300 && distZ > -300)
		pos[2] -= distZ;
	pos[2] += petoff;

	// Look at owner
	ang[1] = ((ArcTangent2(distY, distX) * 180) / 3.14) + g_ePetsData[iIndex].angles[1];

	TeleportEntity(iEntity, pos, ang, NULL_VECTOR);
}

void ResetPet(int client)
{
	if (g_iClientPet[client] == INVALID_ENT_REFERENCE)
		return;

	int iEntity = EntRefToEntIndex(g_iClientPet[client]);
	g_iClientPet[client] = INVALID_ENT_REFERENCE;
	if (iEntity == INVALID_ENT_REFERENCE)
		return;

	AcceptEntityInput(iEntity, "Kill");
}

float GetClientDistanceToGround(int ent, int client, float pos2)
{
	float fOri[3];
	float fGround[3];
	GetEntPropVector(ent, Prop_Data, "m_vecOrigin", fOri);
	fOri[2] = pos2;
	fOri[2] += 100.0;
	float anglePos[3];
	anglePos[0] = 90.0;
	anglePos[1] = 0.0;
	anglePos[2] = 0.0;

	TR_TraceRayFilter(fOri, anglePos, MASK_PLAYERSOLID, RayType_Infinite, TraceRayNoPlayers, client);
	if (TR_DidHit()) {
		TR_GetEndPosition(fGround);
		fOri[2] -= 100.0;
		return GetVectorDistance(fOri, fGround);
	}

	return 0.0;
}

public bool TraceRayNoPlayers(int entity, int mask, any data)
{
	if (entity == data || (entity >= 1 && entity <= MaxClients))
	{
		return false;
	}

	return true;
}

void OffsetLocation(float pos[3])
{
	pos[0] += GetRandomFloat(-128.0, 128.0);
	pos[1] += GetRandomFloat(-128.0, 128.0);
}

any Math_Clamp(any value, any min, any max)
{
	value = Math_Min(value, min);
	value = Math_Max(value, max);

	return value;
}

any Math_Min(any value, any min)
{
	if (value < min)
	{
		value = min;
	}

	return value;
}

any Math_Max(any value, any max)
{
	if (value > max)
	{
		value = max;
	}

	return value;
}

public void Pets_OnClientDisconnect(int client)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}
}

public void Pets_OnPreviewItem(int client, char[] type, int index)
{
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
	}

	if (!StrEqual(type, "pet"))
		return;

	int iPreview = CreateEntityByName("prop_dynamic_override"); //prop_dynamic_override
	
	if (g_hTimerPreview[client] != null) 
	{
        delete g_hTimerPreview[client];
        g_hTimerPreview[client] = null;
	} 
	
	DispatchKeyValue(iPreview, "spawnflags", "64");
	DispatchKeyValue(iPreview, "model", g_ePetsData[index].model);

	DispatchSpawn(iPreview);

	SetEntProp(iPreview, Prop_Send, "m_CollisionGroup", 11);

	AcceptEntityInput(iPreview, "Enable");

	float fOri[3];
	float fAng[3];
	float fRad[2];
	float fPos[3];

	GetClientAbsOrigin(client, fOri);
	GetClientAbsAngles(client, fAng);

	fRad[0] = DegToRad(fAng[0]);
	fRad[1] = DegToRad(fAng[1]);

	fPos[0] = fOri[0] + 64 * Cosine(fRad[0]) * Cosine(fRad[1]);
	fPos[1] = fOri[1] + 64 * Cosine(fRad[0]) * Sine(fRad[1]);
	fPos[2] = fOri[2] + 4 * Sine(fRad[0]);

	fAng[0] *= -1.0;
	fAng[1] *= -1.0;

	fPos[2] += 55;

	TeleportEntity(iPreview, fPos, fAng, NULL_VECTOR);

	g_iPreviewEntity[client] = EntIndexToEntRef(iPreview);

	int iRotator = CreateEntityByName("func_rotating");
	DispatchKeyValueVector(iRotator, "origin", fPos);

	DispatchKeyValue(iRotator, "maxspeed", "20");
	DispatchKeyValue(iRotator, "spawnflags", "64");
	DispatchSpawn(iRotator);

	SetVariantString("!activator");
	AcceptEntityInput(iPreview, "SetParent", iRotator, iRotator);
	AcceptEntityInput(iRotator, "Start");

	SDKHook(iPreview, SDKHook_SetTransmit, Pets_Hook_SetTransmit_Preview);

	g_hTimerPreview[client] = CreateTimer(45.0, Timer_KillPreview, client);

	#if defined _clientmod_included
		MC_PrintToChat(client, "%s%t", g_sChatPrefix_CM, "Spawn Preview CM", client);
		C_PrintToChat(client, "%s%t", g_sChatPrefix, "Spawn Preview", client);
	#else
		PrintToChat(client, "%s%t", g_sChatPrefix, "Spawn Preview", client);
	#endif
}

public Action Pets_Hook_SetTransmit_Preview(int ent, int client)
{
	if (g_iPreviewEntity[client] == INVALID_ENT_REFERENCE)
		return Plugin_Handled;

	if (ent == EntRefToEntIndex(g_iPreviewEntity[client]))
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action Timer_KillPreview(Handle timer, int client)
{
	g_hTimerPreview[client] = null;

	if (g_iPreviewEntity[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iPreviewEntity[client]);

		if (entity > 0 && IsValidEdict(entity))
		{
			SDKUnhook(entity, SDKHook_SetTransmit, Pets_Hook_SetTransmit_Preview);
			AcceptEntityInput(entity, "Kill");
		}
	}
	g_iPreviewEntity[client] = INVALID_ENT_REFERENCE;

	return Plugin_Stop;
}