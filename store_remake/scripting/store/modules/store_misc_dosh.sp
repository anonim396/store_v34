#if STORE_MODULE_MISC_DOSH

#define DOSH_MAX_PICKUP_DISTANCE 50.0

ConVar gc_DoshAmount, gc_DoshMax, gc_DoshRemoveTime, gc_DoshRemoveType;
int g_iDoshCount;

enum struct DoshMoneyData
{
	int iCredits;
	int iOwner;
	int iEntityRef;
}

ArrayList g_hDoshMoneyList;

void Dosh_OnPluginStart()
{
	RegConsoleCmd("sm_dosh", Dosh_CMD_DropMoney);
	HookEvent("round_start", Dosh_Event_RoundStart);
	gc_DoshAmount = CreateConVar("store_dosh_amount", "100", "Credits for one dosh.", _, true, 1.0);
	gc_DoshMax = CreateConVar("store_dosh_max", "100", "Max money on ground. 0 = disable.", _, true, 0.0);
	gc_DoshRemoveTime = CreateConVar("store_dosh_remove_time", "60.0", "Seconds until remove. 0 = on round", _, true, 0.0);
	gc_DoshRemoveType = CreateConVar("store_dosh_remove_type", "1", "0 = delete / 1 = give back", _, true, 0.0, true, 1.0);
	Store_BeginModuleConfig("sourcemod/store", "dosh");
	STORE_CFG("store_dosh_amount", "100");
	STORE_CFG("store_dosh_max", "100");
	STORE_CFG("store_dosh_remove_time", "60.0");
	STORE_CFG("store_dosh_remove_type", "1");
	Store_EndModuleConfig("sourcemod/store", "dosh");
	g_hDoshMoneyList = new ArrayList(sizeof(DoshMoneyData));
}

void Dosh_OnMapStart()
{
	PrecacheModel("models/props/cs_assault/money.mdl", true);
	PrecacheSound("items/itempickup.wav", true);
}

public void Dosh_Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 0; i < g_hDoshMoneyList.Length; i++)
	{
		DoshMoneyData data;
		g_hDoshMoneyList.GetArray(i, data);
		int entity = EntRefToEntIndex(data.iEntityRef);
		if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
			AcceptEntityInput(entity, "Kill");
	}
	g_hDoshMoneyList.Clear();
	g_iDoshCount = 0;
}

public Action Dosh_CMD_DropMoney(int client, int args)
{
	if (!client)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Command is in-game only CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Command is in-game only");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Command is in-game only");
		#endif
		return Plugin_Handled;
	}
	if (!IsPlayerAlive(client))
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Must be Alive CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Must be Alive");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Must be Alive");
		#endif
		return Plugin_Handled;
	}
	int account = Store_GetClientCredits(client);
	if (account <= 0)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Not enough Credits CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Not enough Credits");
		#endif
		return Plugin_Handled;
	}
	if (g_iDoshCount >= gc_DoshMax.IntValue && gc_DoshMax.IntValue != 0)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Too many money on the ground CM", g_sCreditsName);
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Too many money on the ground", g_sCreditsName);
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Too many money on the ground", g_sCreditsName);
		#endif
		return Plugin_Handled;
	}
	int value = gc_DoshAmount.IntValue;
	if (args > 0)
	{
		char sBuffer[16];
		GetCmdArg(1, sBuffer, sizeof(sBuffer));
		value = StringToInt(sBuffer);
		if (value <= 0)
		{
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Invalid Amount CM");
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "Credit Invalid Amount");
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "Credit Invalid Amount");
			#endif
			return Plugin_Handled;
		}
	}
	if (account < value)
		value = account;

	float eye_pos[3], eye_angles[3];
	GetClientEyePosition(client, eye_pos);
	GetClientEyeAngles(client, eye_angles);

	Handle trace = TR_TraceRayFilterEx(eye_pos, eye_angles, MASK_SOLID, RayType_Infinite, Dosh_Filter_ExcludeStarter, client);
	if (!TR_DidHit(trace))
	{
		delete trace;
		return Plugin_Handled;
	}
	int entity = CreateEntityByName("prop_physics_override");
	if (!IsValidEntity(entity))
	{
		delete trace;
		return Plugin_Handled;
	}
	DispatchKeyValue(entity, "model", "models/props/cs_assault/money.mdl");
	DispatchKeyValue(entity, "rendercolor", "150 255 150");
	DispatchKeyValue(entity, "spawnflags", "4358");
	DispatchSpawn(entity);

	DoshMoneyData data;
	data.iCredits = value;
	data.iOwner = GetClientUserId(client);
	data.iEntityRef = EntIndexToEntRef(entity);
	g_hDoshMoneyList.PushArray(data);

	char scaleStr[16];
	Format(scaleStr, sizeof(scaleStr), "%f", 2.0);
	SetVariantString(scaleStr);
	AcceptEntityInput(entity, "SetModelScale");
	AcceptEntityInput(entity, "SetScale", entity, entity, 2);

	float end_pos[3];
	TR_GetEndPosition(end_pos, trace);
	delete trace;
	SubtractVectors(end_pos, eye_pos, end_pos);
	NormalizeVector(end_pos, end_pos);
	ScaleVector(end_pos, GetRandomFloat(280.0, 320.0));
	float velocity[3];
	GetEntPropVector(client, Prop_Data, "m_vecVelocity", velocity);
	AddVectors(end_pos, velocity, velocity);
	velocity[2] += 100.0;
	eye_pos[2] -= 6.0;
	eye_angles[0] = eye_angles[2] = GetRandomFloat(-20.0, 20.0);
	eye_angles[1] += GetRandomFloat(70.0, 110.0);
	TeleportEntity(entity, eye_pos, eye_angles, velocity);
	EmitSoundToAll("items/itempickup.wav", entity);
	SDKHook(entity, SDKHook_Use, Dosh_OnUse);
	CreateTimer(0.5, Dosh_Timer_Money, data.iEntityRef);
	if (gc_DoshRemoveTime.FloatValue > 0.0)
	{
		DataPack pack = new DataPack();
		pack.WriteCell(data.iEntityRef);
		pack.WriteCell(value);
		pack.WriteCell(GetClientUserId(client));
		CreateTimer(gc_DoshRemoveTime.FloatValue, Dosh_Timer_Remove, pack);
	}
	Store_SetClientCredits(client, account - value);
	g_iDoshCount++;
	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "You dropped CM", value, g_sCreditsName);
		C_PrintToChat(client, "%s %t", g_sChatPrefix, "You dropped", value, g_sCreditsName);
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix, "You dropped", value, g_sCreditsName);
	#endif
	return Plugin_Handled;
}

public Action Dosh_Timer_Money(Handle timer, int entityRef)
{
	int entity = EntRefToEntIndex(entityRef);
	if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
	{
		float money_pos[3], client_pos[3];
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", money_pos);
		for (int c = 1; c <= MaxClients; c++)
		{
			if (IsClientInGame(c) && IsPlayerAlive(c))
			{
				GetClientAbsOrigin(c, client_pos);
				client_pos[2] += 32.0;
				if (GetVectorDistance(client_pos, money_pos) <= DOSH_MAX_PICKUP_DISTANCE)
					Dosh_PickUpMoney(c, entity);
			}
		}
		CreateTimer(0.2, Dosh_Timer_Money, entityRef);
	}
	return Plugin_Continue;
}

public Action Dosh_Timer_Remove(Handle timer, DataPack pack)
{
	pack.Reset();
	int entityRef = pack.ReadCell();
	int value = pack.ReadCell();
	int ownerUserId = pack.ReadCell();
	delete pack;
	int entity = EntRefToEntIndex(entityRef);
	if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
	{
		int index = Dosh_FindMoneyByEntity(entityRef);
		if (index != -1)
			g_hDoshMoneyList.Erase(index);
		AcceptEntityInput(entity, "Kill");
		g_iDoshCount--;
		int dropper = GetClientOfUserId(ownerUserId);
		if (dropper > 0 && IsClientInGame(dropper))
		{
			if (gc_DoshRemoveType.IntValue == 1)
			{
				Store_SetClientCredits(dropper, Store_GetClientCredits(dropper) + value);
				#if defined _clientmod_included
					MC_PrintToChat(dropper, "%s %t", g_sChatPrefix_CM, "No pick up - back to you CM");
					C_PrintToChat(dropper, "%s %t", g_sChatPrefix, "No pick up - back to you");
				#else
					PrintToChat(dropper, "%s %t", g_sChatPrefix, "No pick up - back to you");
				#endif
			}
			else
			{
				#if defined _clientmod_included
					MC_PrintToChat(dropper, "%s %t", g_sChatPrefix_CM, "No pick up - removed CM");
					C_PrintToChat(dropper, "%s %t", g_sChatPrefix, "No pick up - removed");
				#else
					PrintToChat(dropper, "%s %t", g_sChatPrefix, "No pick up - removed");
				#endif
			}
		}
	}
	return Plugin_Continue;
}

public Action Dosh_OnUse(int entity, int client)
{
	if (IsClientInGame(client) && IsPlayerAlive(client))
		Dosh_PickUpMoney(client, entity);
	return Plugin_Handled;
}

void Dosh_PickUpMoney(int client, int entity)
{
	int index = Dosh_FindMoneyByEntity(EntIndexToEntRef(entity));
	if (index != -1)
	{
		DoshMoneyData data;
		g_hDoshMoneyList.GetArray(index, data);
		Dosh_GiveMoneyToClient(client, entity, data.iCredits);
		g_hDoshMoneyList.Erase(index);
	}
}

void Dosh_GiveMoneyToClient(int client, int entity, int value)
{
	if (value <= 0) return;
	Store_SetClientCredits(client, Store_GetClientCredits(client) + value);
	EmitSoundToAll("items/itempickup.wav", entity);
	AcceptEntityInput(entity, "Kill");
	g_iDoshCount--;
	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "You collected CM", value, g_sCreditsName);
		C_PrintToChat(client, "%s %t", g_sChatPrefix, "You collected", value, g_sCreditsName);
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix, "You collected", value, g_sCreditsName);
	#endif
}

int Dosh_FindMoneyByEntity(int entityRef)
{
	for (int i = 0; i < g_hDoshMoneyList.Length; i++)
	{
		DoshMoneyData data;
		g_hDoshMoneyList.GetArray(i, data);
		if (data.iEntityRef == entityRef) return i;
	}
	return -1;
}

public bool Dosh_Filter_ExcludeStarter(int entity, int contentsMask, int data)
{
	return (data != entity);
}

#else
void Dosh_OnPluginStart() {}
void Dosh_OnMapStart() {}
#endif
