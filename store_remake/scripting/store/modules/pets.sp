#if STORE_MODULE_PETS
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
	float follow_speed;
	float follow_distance;
	float scale;
}

enum struct ClientPetData
{
	int entityRegular;
	int entityCM;
	int petIndex;
	bool isFollowing;
	float lastThinkTime;
}

PetData g_ePetsData[STORE_MAX_ITEMS];
ClientPetData g_ClientPets[MAXPLAYERS + 1];

int g_iPetCount = 0;
int g_bPetEnable;

bool g_bHide[MAXPLAYERS + 1];
bool g_bFollowMode[MAXPLAYERS + 1] = {false, ...};

int g_iClientPet[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};
int g_iSelectedPet[MAXPLAYERS + 1] = {-1, ...};
int g_iLastAnimation[MAXPLAYERS + 1] = {-1, ...};
static int g_iLastIdleTimes[MAXPLAYERS+1] = {-1, ...};
static int g_iLastSpawnTime[MAXPLAYERS+1] = {-1, ...};

Handle g_hTimerPreviewPet[MAXPLAYERS + 1];
int g_iPreviewPetEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

Cookie g_hHidePetCookie;
Cookie g_hFollowCookie;

public void Pets_OnPluginStart()
{   
	Store_RegisterHandler("pet", "model", Pets_OnMapStart, Pets_Reset, Pets_Config, Pets_Equip, Pets_Remove, true);
	g_bPetEnable = RegisterConVar("sm_store_pets_enable", "1", "Enable the pet module", TYPE_INT);
	
	RegConsoleCmd("sm_hidepet", Command_Hide, "Hides the Pets");
	RegConsoleCmd("sm_hidepets", Command_Hide, "Hides the Pets");
	RegConsoleCmd("sm_followpet", Command_FollowPet, "Toggle pet follow mode");
	RegConsoleCmd("sm_petfollow", Command_FollowPet, "Toggle pet follow mode");

	HookEvent("player_spawn", Pets_PlayerSpawn);
	HookEvent("player_death", Pets_PlayerDeath);
	
	g_hHidePetCookie = new Cookie("Pets_Hide_Cookie", "Cookie to check if Pets are hidden", CookieAccess_Private);
	g_hFollowCookie = new Cookie("Pets_Follow_Cookie", "Cookie to check pet follow mode", CookieAccess_Private);
	
	SetCookieMenuItem(PrefMenuPets, 0, "");
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!AreClientCookiesCached(i))
			continue;

		Pets_OnClientCookiesCached(i);
	}
}

public void PrefMenuPets(int client, CookieMenuAction actions, any info, char[] buffer, int maxlen)
{
	if (actions == CookieMenuAction_DisplayOption)
	{
		FormatEx(buffer, maxlen, "[Store] %T", "Pet Settings", client);
	}

	if (actions == CookieMenuAction_SelectOption)
	{
		ShowPetSettingsMenu(client);
	}
}

void ShowPetSettingsMenu(int client)
{
	Menu menu = new Menu(PetSettingsMenuHandler);
	
	char title[128];
	FormatEx(title, sizeof(title), "%T\n \n", "Pet Settings", client);
	menu.SetTitle(title);
	
	char hideText[64], followText[64], backText[64];
	
	if (g_bHide[client])
		FormatEx(hideText, sizeof(hideText), "%T", "Show Pets", client);
	else
		FormatEx(hideText, sizeof(hideText), "%T", "Hide Pets", client);
	
	if (g_bFollowMode[client])
		FormatEx(followText, sizeof(followText), "%T", "Pet Follow Mode: Enabled", client);
	else
		FormatEx(followText, sizeof(followText), "%T", "Pet Follow Mode: Disabled", client);
	
	FormatEx(backText, sizeof(backText), "%T", "Back", client);
	
	menu.AddItem("hide", hideText);
	menu.AddItem("follow", followText);
	menu.AddItem("", "", ITEMDRAW_SPACER);
	menu.AddItem("back", backText);
	
	menu.Display(client, MENU_TIME_FOREVER);
}

public int PetSettingsMenuHandler(Menu menu, MenuAction action, int client, int itemNum)
{
	if (action == MenuAction_Select)
	{
		char info[32];
		menu.GetItem(itemNum, info, sizeof(info));
		
		if (StrEqual(info, "hide"))
		{
			g_bHide[client] = !g_bHide[client];
			
			if (g_bHide[client])
			{
				g_hHidePetCookie.Set(client, "1");
				#if defined _clientmod_included
					MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Item hidden CM", "pet");
					C_PrintToChat(client, "%s %t", g_sChatPrefix, "Item hidden", "pet");
				#else
					PrintToChat(client, "%s %t", g_sChatPrefix, "Item hidden", "pet");
				#endif
				ResetPet(client);
			}
			else
			{
				g_hHidePetCookie.Set(client, "0");
				#if defined _clientmod_included
					MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Item visible CM", "pet");
					C_PrintToChat(client, "%s %t", g_sChatPrefix, "Item visible", "pet");
				#else
					PrintToChat(client, "%s %t", g_sChatPrefix, "Item visible", "pet");
				#endif
				if (IsPlayerAlive(client) && g_iSelectedPet[client] >= 0)
				{
					RequestFrame(RequestFrame_CreatePetPost, client);
				}
			}
			
			ShowPetSettingsMenu(client);
		}
		else if (StrEqual(info, "follow"))
		{
			g_bFollowMode[client] = !g_bFollowMode[client];
			
			if (g_bFollowMode[client])
			{
				g_hFollowCookie.Set(client, "1");
				#if defined _clientmod_included
					MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Pet follow mode enabled CM");
					C_PrintToChat(client, "%s %t", g_sChatPrefix, "Pet follow mode enabled");
				#else
					PrintToChat(client, "%s %t", g_sChatPrefix, "Pet follow mode enabled");
				#endif
			}
			else
			{
				g_hFollowCookie.Set(client, "0");
				#if defined _clientmod_included
					MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Pet follow mode disabled CM");
					C_PrintToChat(client, "%s %t", g_sChatPrefix, "Pet follow mode disabled");
				#else
					PrintToChat(client, "%s %t", g_sChatPrefix, "Pet follow mode disabled");
				#endif
			}
			
			if (IsPlayerAlive(client) && g_iSelectedPet[client] >= 0)
			{
				ResetPet(client);
				RequestFrame(RequestFrame_CreatePetPost, client);
			}
			
			ShowPetSettingsMenu(client);
		}
		else if (StrEqual(info, "back"))
		{
			ShowCookieMenu(client);
		}
	}
	else if (action == MenuAction_End)
	{
		delete menu;
	}
	
	return 0;
}

public void Pets_OnClientCookiesCached(int client)
{
	char sValue[4];
	
	g_hHidePetCookie.Get(client, sValue, sizeof(sValue));
	if (sValue[0] == '\0' || sValue[0] == '0')
		g_bHide[client] = false;
	else
		g_bHide[client] = true;
	
	g_hFollowCookie.Get(client, sValue, sizeof(sValue));
	if (sValue[0] == '\0')
	{
		g_bFollowMode[client] = false;
		g_hFollowCookie.Set(client, "0");
	}
	else if (sValue[0] == '0')
		g_bFollowMode[client] = false;
	else
		g_bFollowMode[client] = true;
}

Action Command_FollowPet(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;
	
	g_bFollowMode[client] = !g_bFollowMode[client];
	
	if (g_bFollowMode[client])
	{
		g_hFollowCookie.Set(client, "1");
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Pet follow mode enabled CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Pet follow mode enabled");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Pet follow mode enabled");
		#endif
	}
	else
	{
		g_hFollowCookie.Set(client, "0");
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Pet follow mode disabled CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Pet follow mode disabled");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Pet follow mode disabled");
		#endif
	}
	
	// Пересоздать питомца с новым режимом
	if (IsPlayerAlive(client) && g_iSelectedPet[client] >= 0)
	{
		ResetPet(client);
		RequestFrame(RequestFrame_CreatePetPost, client);
	}
	
	return Plugin_Handled;
}

Action Command_Hide(int client, int args)
{
	if (!IsValidClient(client))
		return Plugin_Handled;
	
	g_bHide[client] = !g_bHide[client];
	
	if (g_bHide[client])
	{
		g_hHidePetCookie.Set(client, "1");
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Item hidden CM", "pet");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Item hidden", "pet");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Item hidden", "pet");
		#endif
		ResetPet(client);
	}
	else
	{
		g_hHidePetCookie.Set(client, "0");
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Item visible CM", "pet");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Item visible", "pet");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Item visible", "pet");
		#endif
		
		if (IsPlayerAlive(client) && g_iSelectedPet[client] >= 0)
		{
			RequestFrame(RequestFrame_CreatePetPost, client);
		}
	}
	
	return Plugin_Handled;
}

public void Pets_OnMapStart()
{
	for (int i = 0; i < g_iPetCount; i++)
	{
		if(g_ePetsData[i].model[0] != '\0')
		{
			PrecacheModel(g_ePetsData[i].model, true);
			AddFileToDownloadsTable(g_ePetsData[i].model);
		}
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

	kv.GetString("model", g_ePetsData[currentIndex].model, sizeof(g_ePetsData[].model));
	
	if(g_ePetsData[currentIndex].model[0] == '\0')
	{
		LogError("No models specified for pet %d. Need at least one of: 'model'", itemid);
		configValid = false;
	}

	kv.GetString("idle", g_ePetsData[currentIndex].idle, sizeof(g_ePetsData[].idle));
	kv.GetString("idle2", g_ePetsData[currentIndex].idle2, sizeof(g_ePetsData[].idle2));
	kv.GetString("run", g_ePetsData[currentIndex].run, sizeof(g_ePetsData[].run));
	kv.GetString("spawn", g_ePetsData[currentIndex].spawn, sizeof(g_ePetsData[].spawn));
	kv.GetString("death", g_ePetsData[currentIndex].death, sizeof(g_ePetsData[].death));

	if(g_ePetsData[currentIndex].run[0] == '\0')
	{
		LogMessage("Optional 'run' animation not specified for pet %d", itemid);
	}

	if(!kv.GetVector("position", g_ePetsData[currentIndex].position))
	{
		LogError("Missing or invalid 'position' for pet %d", itemid);
		g_ePetsData[currentIndex].position = {0.0, 0.0, 0.0};
		configValid = false;
	}
	
	g_ePetsData[currentIndex].scale = kv.GetFloat("scale", 1.0);

	if(!kv.GetVector("angles", g_ePetsData[currentIndex].angles))
	{
		LogError("Missing or invalid 'angles' for pet %d", itemid);
		g_ePetsData[currentIndex].angles = {0.0, 0.0, 0.0};
		configValid = false;
	}

	g_ePetsData[currentIndex].spawnTimeDelay = kv.GetFloat("spawn_delay", 1.0);
	
	// Удален параметр follow_player из конфига
	// Вместо него используем настройки по умолчанию
	g_ePetsData[currentIndex].follow_speed = kv.GetFloat("follow_speed", 250.0);
	g_ePetsData[currentIndex].follow_distance = kv.GetFloat("follow_distance", 100.0);

	if(g_ePetsData[currentIndex].model[0] != '\0' && !FileExists(g_ePetsData[currentIndex].model, true))
	{
		LogError("Model file not found for pet %d: %s", itemid, g_ePetsData[currentIndex].model);
		configValid = false;
	}

	if(configValid)
	{
		g_iPetCount++;
		return true;
	}
	
	LogError("Pet configuration failed for item %d", itemid);
	return false;
}

public int Pets_Equip(int client, int itemid)
{
	if(!IsValidClient(client))
		return -1;
		
	if(g_eCvars[g_bPetEnable].aCache != 1)
		return -1;

	g_iSelectedPet[client] = Store_GetDataIndex(itemid);
	
	if(IsPlayerAlive(client))
	{
		RequestFrame(RequestFrame_CreatePetPost, client);
	}
	
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
	g_ClientPets[client].entityRegular = INVALID_ENT_REFERENCE;
	g_ClientPets[client].entityCM = INVALID_ENT_REFERENCE;
	g_ClientPets[client].petIndex = -1;
	g_bHide[client] = false;
	g_bFollowMode[client] = false;
}

public void Pets_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	if(!IsValidClient(client) || g_eCvars[g_bPetEnable].aCache != 1)
		return;
		
	if(GetClientTeam(client) < 2)
		return;

	RequestFrame(RequestFrame_CreatePetPost, client);
}

public void RequestFrame_CreatePetPost(int client)
{
	if(!IsValidClient(client) || !IsPlayerAlive(client)) 
		return;
	
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
	if (!IsValidClient(client, true))
		return Plugin_Continue;
	
	if (g_bHide[client])
		return Plugin_Handled;
	
	int time = GetTime();
	
	if (time < g_iLastSpawnTime[client])
		return Plugin_Continue;
	
	// Управление анимациями (каждые 5 тиков)
	if (tickcount % 5 == 0)
	{
		if (g_ClientPets[client].entityRegular != INVALID_ENT_REFERENCE)
		{
			int entity = EntRefToEntIndex(g_ClientPets[client].entityRegular);
			if (entity != INVALID_ENT_REFERENCE)
			{
				UpdatePetAnimation(client, entity, time);
				
				if (g_iSelectedPet[client] >= 0 && g_bFollowMode[client])
				{
					UpdatePetPosition(client, entity);
				}
			}
		}
		
		if (g_ClientPets[client].entityCM != INVALID_ENT_REFERENCE)
		{
			int entity = EntRefToEntIndex(g_ClientPets[client].entityCM);
			if (entity != INVALID_ENT_REFERENCE)
			{
				UpdatePetAnimation(client, entity, time);
				
				if (g_iSelectedPet[client] >= 0 && g_bFollowMode[client])
				{
					UpdatePetPosition(client, entity);
				}
			}
		}
		
		if (g_iClientPet[client] != INVALID_ENT_REFERENCE)
		{
			int entity = EntRefToEntIndex(g_iClientPet[client]);
			if (entity != INVALID_ENT_REFERENCE)
			{
				UpdatePetAnimation(client, entity, time);
				
				if (g_iSelectedPet[client] >= 0 && g_bFollowMode[client])
				{
					UpdatePetPosition(client, entity);
				}
			}
		}
	}
	
	if (g_iSelectedPet[client] >= 0 && g_bFollowMode[client])
	{
		ManagePetFollowing(client);
	}
	
	return Plugin_Continue;
}

void UpdatePetAnimation(int client, int entity, int time)
{
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	
	if(owner != client)
		return;

	int petIndex = g_iSelectedPet[client];
	if(petIndex < 0)
		return;
	
	if(g_iLastAnimation[client] == 3)
		return;
	
	if(g_iLastAnimation[client] == 0 && time < g_iLastSpawnTime[client])
		return;
	
	if (g_ePetsData[petIndex].run[0] == '\0' && g_ePetsData[petIndex].idle[0] == '\0')
		return;
	
	float fVec[3];
	float fDist;
	GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fVec);
	fDist = GetVectorLength(fVec);
	
	if (g_bFollowMode[client])
	{
		float ownerPos[3], petPos[3];
		GetClientAbsOrigin(client, ownerPos);
		GetEntPropVector(entity, Prop_Data, "m_vecOrigin", petPos);
		float distance = GetVectorDistance(ownerPos, petPos);
		
		if (fDist > 10.0 && distance > 50.0)
		{
			if (g_iLastAnimation[client] != 1 && g_ePetsData[petIndex].run[0] != '\0')
			{
				SetVariantString(g_ePetsData[petIndex].run);
				AcceptEntityInput(entity, "SetAnimation");
				g_iLastAnimation[client] = 1;
			}
		}
		else if (g_iLastAnimation[client] != 2 && g_ePetsData[petIndex].idle[0] != '\0')
		{
			if (g_iLastIdleTimes[client] < time && g_ePetsData[petIndex].idle2[0] != '\0')
			{
				g_iLastSpawnTime[client] = time + 2;
				g_iLastIdleTimes[client] = time + 15;
				SetVariantString(g_ePetsData[petIndex].idle2);
				AcceptEntityInput(entity, "SetAnimation");
				g_iLastAnimation[client] = 2;
			}
			else if (g_iLastAnimation[client] != 2)
			{
				SetVariantString(g_ePetsData[petIndex].idle);
				AcceptEntityInput(entity, "SetAnimation");
				g_iLastAnimation[client] = 2;
			}
		}
	}
	else
	{
		if (g_iLastAnimation[client] != 1 && fDist > 0.0 && g_ePetsData[petIndex].run[0] != '\0')
		{
			SetVariantString(g_ePetsData[petIndex].run);
			AcceptEntityInput(entity, "SetAnimation");
			g_iLastAnimation[client] = 1;
		}
		else if (g_iLastAnimation[client] != 2 && fDist == 0.0 && g_ePetsData[petIndex].idle[0] != '\0')
		{		  
			if (g_iLastIdleTimes[client] < time && g_ePetsData[petIndex].idle2[0] != '\0')
			{
				g_iLastSpawnTime[client] = time + 2;
				g_iLastIdleTimes[client] = time + 15;
				SetVariantString(g_ePetsData[petIndex].idle2);
			}
			else
			{
				SetVariantString(g_ePetsData[petIndex].idle);
			}
			AcceptEntityInput(entity, "SetAnimation");
			g_iLastAnimation[client] = 2;
		}
	}
}

void Store_ClientDeathPet(int client)
{
	DeathPet(client);
}

void DeathPet(int client)
{
	int petIndex = g_iSelectedPet[client];
	if(petIndex < 0)
		return;
	
	if (g_ClientPets[client].entityRegular != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_ClientPets[client].entityRegular);
		if(entity != INVALID_ENT_REFERENCE && IsValidEdict(entity))
		{
			if(g_ePetsData[petIndex].death[0] == '\0')
			{
				AcceptEntityInput(entity, "Kill");
				g_ClientPets[client].entityRegular = INVALID_ENT_REFERENCE;
			}
			else
			{
				SetVariantString(g_ePetsData[petIndex].death);
				AcceptEntityInput(entity, "SetAnimation");
				g_iLastAnimation[client] = 3;
				HookSingleEntityOutput(entity, "OnAnimationDone", Hook_OnAnimationDone, true);
			}
		}
	}
	
	if (g_ClientPets[client].entityCM != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_ClientPets[client].entityCM);
		if(entity != INVALID_ENT_REFERENCE && IsValidEdict(entity))
		{
			if(g_ePetsData[petIndex].death[0] == '\0')
			{
				AcceptEntityInput(entity, "Kill");
				g_ClientPets[client].entityCM = INVALID_ENT_REFERENCE;
			}
			else
			{
				SetVariantString(g_ePetsData[petIndex].death);
				AcceptEntityInput(entity, "SetAnimation");
				HookSingleEntityOutput(entity, "OnAnimationDone", Hook_OnAnimationDone, true);
			}
		}
	}
	
	if(g_iClientPet[client] == INVALID_ENT_REFERENCE)
		return;

	int entity = EntRefToEntIndex(g_iClientPet[client]);

	if(!IsValidEdict(entity))
		return;
	
	if(g_ePetsData[petIndex].death[0] == '\0')
	{
		ResetPet(client);
		return;
	}
	
	SetVariantString(g_ePetsData[petIndex].death);
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
		
		if(g_ClientPets[owner].entityRegular == iRef)
		{
			g_ClientPets[owner].entityRegular = INVALID_ENT_REFERENCE;
		}
		else if(g_ClientPets[owner].entityCM == iRef)
		{
			g_ClientPets[owner].entityCM = INVALID_ENT_REFERENCE;
		}
		else if(g_iClientPet[owner] == iRef)
		{
			g_iClientPet[owner] = INVALID_ENT_REFERENCE;
		}
	}

	AcceptEntityInput(caller, "Kill");
}

void CreatePet(int client)
{   
	if(!IsValidClient(client))
		return;
		
	ResetPet(client);
	
	if (g_iSelectedPet[client] < 0)
		return;
	
	if (!IsPlayerAlive(client) || GetClientTeam(client) < 2)
		return;
	
	int petIndex = g_iSelectedPet[client];
	
	char modelToUse[PLATFORM_MAX_PATH];
	strcopy(modelToUse, sizeof(modelToUse), g_ePetsData[petIndex].model);
	
	if (modelToUse[0] == '\0')
		return;
	
	int entity = CreatePetEntity(client, petIndex, modelToUse, false);
	if (entity == -1)
		return;
	
	g_ClientPets[client].entityRegular = EntIndexToEntRef(entity);
	g_iClientPet[client] = g_ClientPets[client].entityRegular;
	g_ClientPets[client].petIndex = petIndex;
}

int CreatePetEntity(int client, int petIndex, const char[] model, bool hideFromOwner = false)
{
	int iEntity = CreateEntityByName("prop_dynamic_override");
	if (!IsValidEntity(iEntity))
		return -1;
	
	DispatchKeyValue(iEntity, "model", model);
	DispatchKeyValue(iEntity, "spawnflags", "256");
	DispatchKeyValue(iEntity, "solid", "0");
	
	SetEntPropEnt(iEntity, Prop_Send, "m_hOwnerEntity", client);
	
	bool followMode = g_bFollowMode[client];
	
	if (!followMode)
	{	   
		float fPos[3], fAng[3], fOri[3], flClientAngles[3];
		
		GetClientAbsOrigin(client, fOri);
		GetClientAbsAngles(client, flClientAngles);
		
		fPos[0] = g_ePetsData[petIndex].position[0];
		fPos[1] = g_ePetsData[petIndex].position[1];
		fPos[2] = g_ePetsData[petIndex].position[2];
		fAng[0] = g_ePetsData[petIndex].angles[0];
		fAng[1] = g_ePetsData[petIndex].angles[1];
		fAng[2] = g_ePetsData[petIndex].angles[2];
		
		float fForward[3], fRight[3], fUp[3];
		GetAngleVectors(flClientAngles, fForward, fRight, fUp);
		
		fOri[0] += fRight[0] * fPos[0] + fForward[0] * fPos[1] + fUp[0] * fPos[2];
		fOri[1] += fRight[1] * fPos[0] + fForward[1] * fPos[1] + fUp[1] * fPos[2];
		fOri[2] += fRight[2] * fPos[0] + fForward[2] * fPos[1] + fUp[2] * fPos[2];
		
		fAng[1] += flClientAngles[1];
		
		DispatchSpawn(iEntity);  
		AcceptEntityInput(iEntity, "TurnOn", iEntity, iEntity, 0);
		
		if (g_ePetsData[petIndex].scale != 1.0)
		{
			char scaleStr[16];
			Format(scaleStr, sizeof(scaleStr), "%f", g_ePetsData[petIndex].scale);
			
			SetVariantString(scaleStr);
			AcceptEntityInput(iEntity, "SetModelScale");
			
			char kv[64];
			Format(kv, sizeof(kv), "modelscale %s", scaleStr);
			SetVariantString(kv);
			AcceptEntityInput(iEntity, "AddOutput");
			
			DispatchKeyValue(iEntity, "modelscale", scaleStr);
		}
		
		// Teleport the pet to the right fPosition and attach it
		TeleportEntity(iEntity, fOri, fAng, NULL_VECTOR); 
		
		/*------------------------------------------------------------------------*/
		SetVariantString("!activator");
		AcceptEntityInput(iEntity, "SetParent", client, iEntity, 0);
		
		float localOffset[3];
		localOffset[0] = g_ePetsData[petIndex].position[0];
		localOffset[1] = g_ePetsData[petIndex].position[1];
		localOffset[2] = g_ePetsData[petIndex].position[2];
		
		float localAngles[3];
		localAngles[0] = g_ePetsData[petIndex].angles[0];
		localAngles[1] = g_ePetsData[petIndex].angles[1];
		localAngles[2] = g_ePetsData[petIndex].angles[2];
		
		DispatchKeyValueVector(iEntity, "origin", fOri);
		DispatchKeyValueVector(iEntity, "angles", fAng);
		
		SetVariantVector3D(localOffset);
		AcceptEntityInput(iEntity, "SetParentAttachmentOffset");
		
		SetVariantVector3D(localAngles);
		AcceptEntityInput(iEntity, "SetParentAttachmentAngles");
		
		//SetVariantString("primary");
		//AcceptEntityInput(iEntity, "SetParentAttachment");
		/*------------------------------------------------------------------------*/
		
		g_ClientPets[client].isFollowing = false;
		g_iLastAnimation[client] = -1;
	}
	else
	{
		float ownerPos[3], ownerAng[3], spawnPos[3];
		
		GetClientAbsOrigin(client, ownerPos);
		GetClientAbsAngles(client, ownerAng);
		
		float offset = g_ePetsData[petIndex].follow_distance;

		spawnPos[0] = ownerPos[0] - (offset * Sine(DegToRad(ownerAng[1])));
		spawnPos[1] = ownerPos[1] + (offset * Cosine(DegToRad(ownerAng[1])));
		spawnPos[2] = ownerPos[2];
		
		float traceEnd[3];
		traceEnd[0] = spawnPos[0];
		traceEnd[1] = spawnPos[1];
		traceEnd[2] = spawnPos[2] + 10.0;
		
		TR_TraceRayFilter(ownerPos, traceEnd, MASK_SOLID, RayType_EndPoint, TraceFilter_IgnorePlayers, client);
		
		if (TR_DidHit())
		{
			TR_GetEndPosition(spawnPos);
			spawnPos[2] += 5.0;
		}
		else
		{
			TR_TraceRayFilter(spawnPos, view_as<float>({90.0, 0.0, 0.0}), MASK_SOLID, RayType_Infinite, TraceFilter_IgnorePlayers, client);
			if (TR_DidHit())
			{
				float groundPos[3];
				TR_GetEndPosition(groundPos);
				
				spawnPos[2] = groundPos[2] + 10.0;
			}
		}
		
		DispatchSpawn(iEntity);
		AcceptEntityInput(iEntity, "TurnOn", iEntity, iEntity, 0);
		
		if (g_ePetsData[petIndex].scale != 1.0)
		{
			char scaleStr[16];
			Format(scaleStr, sizeof(scaleStr), "%f", g_ePetsData[petIndex].scale);
			SetVariantString(scaleStr);
			AcceptEntityInput(iEntity, "SetModelScale");
		}
		
		TeleportEntity(iEntity, spawnPos, ownerAng, NULL_VECTOR);

		g_ClientPets[client].isFollowing = true;
		g_ClientPets[client].lastThinkTime = GetGameTime();
	}
	
	char entityInfo[64];
	if (hideFromOwner)
	{
		Format(entityInfo, sizeof(entityInfo), "pet_%d_hide", petIndex);
	}
	else
	{
		Format(entityInfo, sizeof(entityInfo), "pet_%d", petIndex);
	}

	DispatchKeyValue(iEntity, "targetname", entityInfo);
	
	Set_EdictFlags(iEntity);
	
	if (g_ePetsData[petIndex].spawn[0] != '\0')
	{
		g_iLastSpawnTime[client] = GetTime() + view_as<int>(RoundToCeil(g_ePetsData[petIndex].spawnTimeDelay));
		SetVariantString(g_ePetsData[petIndex].spawn);
		AcceptEntityInput(iEntity, "SetAnimation");
		g_iLastAnimation[client] = 0;
	}
	else if (g_ePetsData[petIndex].idle[0] != '\0')
	{
		SetVariantString(g_ePetsData[petIndex].idle);
		AcceptEntityInput(iEntity, "SetAnimation");
		g_iLastAnimation[client] = 2;
	}
	else
	{
		g_iLastAnimation[client] = -1;
	}
	
	SDKHook(iEntity, SDKHook_SetTransmit, Hook_PetSetTransmit);
	
	return iEntity;
}

public Action Hook_PetSetTransmit(int entity, int client)
{   
	// Базовые проверки
	if (!IsValidClient(client) || !IsClientInGame(client))
		return Plugin_Handled;
	
	if (g_bHide[client])
		return Plugin_Handled;
	
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (owner <= 0 || owner > MaxClients)
		return Plugin_Continue;
	
	int petIndex = g_iSelectedPet[owner];
	if (petIndex < 0)
		return Plugin_Handled;
	
	char entityInfo[64];
	GetEntPropString(entity, Prop_Data, "m_iName", entityInfo, sizeof(entityInfo));
	bool hideFromOwner = (StrContains(entityInfo, "_hide") != -1);
	
	// 1. Проверка для владельца
	if (client == owner)
	{
		// Владелец не видит свой питомец в 1 лице
		// Проверяем ThirdPerson
		#if defined _thirdperson_included_
			if (GetFeatureStatus(FeatureType_Native, "IsPlayerInTP") == FeatureStatus_Available)
			{
				if (IsPlayerInTP(client))
				{
					// В 3 лице - видит
					return hideFromOwner ? Plugin_Handled : Plugin_Continue;
				}
				else
				{
					// В 1 лице - не видит (кроме следующих питомцев)
					if (g_bFollowMode[client])
					{
						// Следующие питомцы могут быть видны
						return hideFromOwner ? Plugin_Handled : Plugin_Continue;
					}
					return Plugin_Handled;
				}
			}
		#endif
		
		// Если ThirdPerson не подключен, используем FOV проверку
		int fov = GetEntProp(client, Prop_Send, "m_iFOV");
		if (fov == 90 || fov == 0) // Стандартный FOV - 1 лицо
		{
			if (g_bFollowMode[client])
			{
				return hideFromOwner ? Plugin_Handled : Plugin_Continue;
			}
			return Plugin_Handled;
		}
		else // Нестандартный FOV - возможно 3 лицо
		{
			return hideFromOwner ? Plugin_Handled : Plugin_Continue;
		}
	}
	
	// 2. Проверка для других игроков
	// Проверяем режим наблюдения
	int observerMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
	
	// Если игрок мертв и наблюдает
	if (!IsPlayerAlive(client))
	{
		int observerTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
		
		// Если наблюдает за владельцем питомца
		if (observerTarget == owner)
		{
			// 4 = First Person наблюдение, 5 = Third Person наблюдение
			if (observerMode == 4) // First Person
			{
				return Plugin_Handled;
			}
			else if (observerMode == 5) // Third Person
			{
				return Plugin_Continue;
			}
		}
	}
	
	// Все остальные случаи - показываем
	return Plugin_Continue;
}

void UpdatePetPosition(int client, int entity)
{
	if (!IsValidEntity(entity))
		return;
	
	int petIndex = g_iSelectedPet[client];
	if(petIndex < 0)
		return;
	
	if(g_bFollowMode[client])
		return;
	
	if(g_iLastAnimation[client] == 3 || g_iLastAnimation[client] == 0)
		return;
	
	int owner = GetEntPropEnt(entity, Prop_Send, "m_hOwnerEntity");
	if (owner != client)
		return;
	
	float fPos[3], fAng[3], fOri[3], flClientAngles[3];
	
	GetClientAbsOrigin(client, fOri);
	GetClientAbsAngles(client, flClientAngles);
	
	fPos[0] = g_ePetsData[petIndex].position[0];
	fPos[1] = g_ePetsData[petIndex].position[1];
	fPos[2] = g_ePetsData[petIndex].position[2];
	fAng[0] = g_ePetsData[petIndex].angles[0];
	fAng[1] = g_ePetsData[petIndex].angles[1];
	fAng[2] = g_ePetsData[petIndex].angles[2];
	
	float fForward[3], fRight[3], fUp[3];
	GetAngleVectors(flClientAngles, fForward, fRight, fUp);
	
	fOri[0] += fRight[0] * fPos[0] + fForward[0] * fPos[1] + fUp[0] * fPos[2];
	fOri[1] += fRight[1] * fPos[0] + fForward[1] * fPos[1] + fUp[1] * fPos[2];
	fOri[2] += fRight[2] * fPos[0] + fForward[2] * fPos[1] + fUp[2] * fPos[2];
	
	fAng[1] += flClientAngles[1];
	
	float currentPos[3], currentAng[3];
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", currentPos);
	GetEntPropVector(entity, Prop_Data, "m_angRotation", currentAng);
	
	if(GetVectorDistance(currentPos, fOri) > 5.0 || FloatAbs(currentAng[1] - fAng[1]) > 5.0)
	{
		TeleportEntity(entity, fOri, fAng, NULL_VECTOR);
	}
}

void Set_EdictFlags(int edict)
{
	if (GetEdictFlags(edict) & FL_EDICT_ALWAYS)
	{
		SetEdictFlags(edict, (GetEdictFlags(edict) ^ FL_EDICT_ALWAYS));
	}
}

void ManagePetFollowing(int client)
{
	if (!IsValidClient(client, true) || g_iSelectedPet[client] < 0)
		return;
	
	int petIndex = g_iSelectedPet[client];
	
	if (!g_bFollowMode[client])
		return;
	
	float currentTime = GetGameTime();
	
	if (currentTime - g_ClientPets[client].lastThinkTime < 0.05)
		return;
	
	g_ClientPets[client].lastThinkTime = currentTime;
	
	int entities[2];
	entities[0] = g_ClientPets[client].entityRegular;
	entities[1] = g_ClientPets[client].entityCM;
	
	for (int i = 0; i < 2; i++)
	{
		if (entities[i] != INVALID_ENT_REFERENCE)
		{
			int entity = EntRefToEntIndex(entities[i]);
			if (entity != INVALID_ENT_REFERENCE && IsValidEntity(entity))
			{
				char entityInfo[64];
				GetEntPropString(entity, Prop_Data, "m_iName", entityInfo, sizeof(entityInfo));
				
				UpdateFollowingPet(client, entity, petIndex);
			}
		}
	}
}

void UpdateFollowingPet(int client, int entity, int petIndex)
{
	float ownerPos[3], petPos[3], petAng[3], ownerAng[3];
	
	GetClientAbsOrigin(client, ownerPos);
	GetClientAbsAngles(client, ownerAng);
	GetEntPropVector(entity, Prop_Data, "m_vecOrigin", petPos);
	GetEntPropVector(entity, Prop_Data, "m_angRotation", petAng);
	
	float distance = GetVectorDistance(ownerPos, petPos);
	
	float minDistance = 3.0;
	float idealDistance = g_ePetsData[petIndex].follow_distance;
	
	if (distance < minDistance)
	{
		return;
	}
	
	if (distance > 400.0)
	{
		TeleportPetToIdealDistance(client, entity, ownerPos, ownerAng, idealDistance);
		return;
	}
	
	if (distance > (idealDistance + 50.0))
	{
		MovePetToOwner(client, entity, ownerPos, petPos, ownerAng, 350.0, true, idealDistance);
		return;
	}
	
	if (distance > idealDistance + 10.0 || distance < idealDistance - 10.0)
	{
		MovePetToIdealDistance(client, entity, ownerPos, petPos, ownerAng, idealDistance);
		return;
	}
	
	if (distance > 5.0)
	{
		float direction[3], lookAtAng[3];
		SubtractVectors(ownerPos, petPos, direction);
		NormalizeVector(direction, direction);
		GetVectorAngles(direction, lookAtAng);
		
		float smoothAng[3];
		smoothAng[0] = LerpAngle(petAng[0], lookAtAng[0], 0.3);
		smoothAng[1] = LerpAngle(petAng[1], lookAtAng[1], 0.3);
		smoothAng[2] = LerpAngle(petAng[2], lookAtAng[2], 0.3);
		
		TeleportEntity(entity, NULL_VECTOR, smoothAng, NULL_VECTOR);
		return;
	}
}

void TeleportPetToIdealDistance(int client, int entity, float ownerPos[3], float ownerAng[3], float idealDistance)
{
	float spawnPos[3];
	

	float offset = idealDistance;
	
	spawnPos[0] = ownerPos[0] - (offset * Sine(DegToRad(ownerAng[1])));
	spawnPos[1] = ownerPos[1] + (offset * Cosine(DegToRad(ownerAng[1])));
	spawnPos[2] = ownerPos[2];
	
	spawnPos[0] += 20.0 * Cosine(DegToRad(ownerAng[1]));
	spawnPos[1] += -20.0 * Sine(DegToRad(ownerAng[1]));
	
	float validatedPos[3];
	ValidatePetPosition(client, ownerPos, spawnPos, validatedPos);
	
	float direction[3], lookAtAng[3];
	SubtractVectors(ownerPos, validatedPos, direction);
	NormalizeVector(direction, direction);
	GetVectorAngles(direction, lookAtAng);
	
	TeleportEntity(entity, validatedPos, lookAtAng, NULL_VECTOR);
}

void MovePetToIdealDistance(int client, int entity, float ownerPos[3], float petPos[3], float ownerAng[3], float idealDistance)
{
	float currentDistance = GetVectorDistance(ownerPos, petPos);
	
	float targetDistance = idealDistance;
	float distanceDiff = currentDistance - targetDistance;
	
	if (FloatAbs(distanceDiff) < 5.0)
		return;
	
	float speedMultiplier = Math_Clamp(FloatAbs(distanceDiff) / 50.0, 0.3, 1.0);
	float baseSpeed = g_ePetsData[g_iSelectedPet[client]].follow_speed;
	float speed = baseSpeed * speedMultiplier;
	
	float direction[3];
	
	if (ownerAng[0])
		return;
	
	if (distanceDiff > 0)
	{
		// Питомец слишком далеко - двигаем к игроку
		SubtractVectors(ownerPos, petPos, direction);
	}
	
	NormalizeVector(direction, direction);
	
	float frameSpeed = speed * 0.05;
	
	float newPos[3];
	newPos[0] = petPos[0] + (direction[0] * frameSpeed);
	newPos[1] = petPos[1] + (direction[1] * frameSpeed);
	newPos[2] = petPos[2];
	
	float lookDirection[3], lookAtAng[3];
	SubtractVectors(ownerPos, newPos, lookDirection);
	NormalizeVector(lookDirection, lookDirection);
	GetVectorAngles(lookDirection, lookAtAng);
	
	float currentAng[3];
	GetEntPropVector(entity, Prop_Data, "m_angRotation", currentAng);
	
	float smoothAng[3];
	smoothAng[0] = LerpAngle(currentAng[0], lookAtAng[0], 0.5);
	smoothAng[1] = LerpAngle(currentAng[1], lookAtAng[1], 0.5);
	smoothAng[2] = LerpAngle(currentAng[2], lookAtAng[2], 0.5);
	
	if (CheckCollision(petPos, newPos, client))
	{
		float alternativePos[3];
		FindAlternativePath(client, petPos, newPos, frameSpeed, alternativePos);
		newPos[0] = alternativePos[0];
		newPos[1] = alternativePos[1];
		newPos[2] = alternativePos[2];
	}
	
	AdjustPetHeight(client, newPos);
	
	TeleportEntity(entity, newPos, smoothAng, NULL_VECTOR);
}

void MovePetToOwner(int client, int entity, float ownerPos[3], float petPos[3], float ownerAng[3], float speedMultiplier, bool ignoreCollisions, float targetDistance)
{
	int petIndex = g_iSelectedPet[client];
	if (petIndex < 0) return;
	if (ownerAng[0]) return;
	
	float baseSpeed = g_ePetsData[petIndex].follow_speed;
	float speed = baseSpeed * speedMultiplier / 250.0;
	
	float direction[3];
	SubtractVectors(ownerPos, petPos, direction);
	NormalizeVector(direction, direction);
	
	float currentDistance = GetVectorDistance(ownerPos, petPos);
	float distanceToTarget = currentDistance - targetDistance;
	
	if (distanceToTarget < 30.0)
	{
		speed *= Math_Clamp(distanceToTarget / 30.0, 0.3, 1.0);
	}
	
	float frameSpeed = speed * 0.05;
	
	float newPos[3];
	newPos[0] = petPos[0] + (direction[0] * frameSpeed);
	newPos[1] = petPos[1] + (direction[1] * frameSpeed);
	newPos[2] = petPos[2] + (direction[2] * frameSpeed);
	
	float newDistance = GetVectorDistance(ownerPos, newPos);
	if (newDistance < targetDistance)
	{
		float finalDirection[3];
		SubtractVectors(newPos, ownerPos, finalDirection);
		NormalizeVector(finalDirection, finalDirection);
		
		newPos[0] = ownerPos[0] + finalDirection[0] * targetDistance;
		newPos[1] = ownerPos[1] + finalDirection[1] * targetDistance;
		newPos[2] = ownerPos[2];
	}
	
	float lookAtDirection[3], lookAtAng[3];
	SubtractVectors(ownerPos, newPos, lookAtDirection);
	NormalizeVector(lookAtDirection, lookAtDirection);
	GetVectorAngles(lookAtDirection, lookAtAng);
	
	float currentAng[3];
	GetEntPropVector(entity, Prop_Data, "m_angRotation", currentAng);
	
	float smoothAng[3];
	smoothAng[0] = LerpAngle(currentAng[0], lookAtAng[0], 0.5);
	smoothAng[1] = LerpAngle(currentAng[1], lookAtAng[1], 0.5);
	smoothAng[2] = LerpAngle(currentAng[2], lookAtAng[2], 0.5);
	
	if (!ignoreCollisions && CheckCollision(petPos, newPos, client))
	{
		float alternativePos[3];
		FindAlternativePath(client, petPos, newPos, frameSpeed, alternativePos);
		newPos[0] = alternativePos[0];
		newPos[1] = alternativePos[1];
		newPos[2] = alternativePos[2];
	}
	
	AdjustPetHeight(client, newPos);
	
	TeleportEntity(entity, newPos, smoothAng, NULL_VECTOR);
}

float LerpAngle(float start, float end, float fraction)
{
	float difference = end - start;
	
	if (difference > 180.0)
		difference -= 360.0;
	else if (difference < -180.0)
		difference += 360.0;
	
	return start + (difference * fraction);
}

bool CheckCollision(float startPos[3], float endPos[3], int client)
{
	TR_TraceRayFilter(startPos, endPos, MASK_SOLID, RayType_EndPoint, TraceFilter_IgnorePlayersAndOwner, client);
	return TR_DidHit();
}

void FindAlternativePath(int client, float startPos[3], float targetPos[3], float moveDistance, float result[3])
{
	result[0] = startPos[0];
	result[1] = startPos[1];
	result[2] = startPos[2];
	
	float angles[] = {0.0, 45.0, -45.0, 90.0, -90.0};
	
	for (int i = 0; i < sizeof(angles); i++)
	{
		float testPos[3];
		float direction[3];
		
		SubtractVectors(targetPos, startPos, direction);
		NormalizeVector(direction, direction);
		
		float rotatedDir[3];
		RotateVector(direction, angles[i], rotatedDir);
		
		testPos[0] = startPos[0] + rotatedDir[0] * moveDistance;
		testPos[1] = startPos[1] + rotatedDir[1] * moveDistance;
		testPos[2] = startPos[2];
		
		if (!CheckCollision(startPos, testPos, client))
		{
			result[0] = testPos[0];
			result[1] = testPos[1];
			result[2] = testPos[2];
			break;
		}
	}
}

void AdjustPetHeight(int client, float position[3])
{
	float groundPos[3];
	
	TR_TraceRayFilter(position, view_as<float>({90.0, 0.0, 0.0}), MASK_SOLID, RayType_Infinite, TraceFilter_IgnorePlayersAndOwner, client);
	
	if (TR_DidHit())
	{
		TR_GetEndPosition(groundPos);
		
		position[2] = groundPos[2] + 1.0; // +1.0 чтобы не было Z-fighting
	}
}

void ValidatePetPosition(int client, float ownerPos[3], float desiredPos[3], float validatedPos[3])
{
	validatedPos[0] = desiredPos[0];
	validatedPos[1] = desiredPos[1];
	validatedPos[2] = desiredPos[2];
	
	TR_TraceRayFilter(ownerPos, desiredPos, MASK_SOLID, RayType_EndPoint, TraceFilter_IgnorePlayersAndOwner, client);
	
	if (TR_DidHit())
	{
		validatedPos[0] = ownerPos[0];
		validatedPos[1] = ownerPos[1];
		validatedPos[2] = ownerPos[2] + 10.0;
	}
	
	AdjustPetHeight(client, validatedPos);
}

void RotateVector(float vector[3], float angle, float result[3])
{
	float radAngle = DegToRad(angle);
	float cosAngle = Cosine(radAngle);
	float sinAngle = Sine(radAngle);
	
	result[0] = vector[0] * cosAngle - vector[1] * sinAngle;
	result[1] = vector[0] * sinAngle + vector[1] * cosAngle;
	result[2] = vector[2];
}

public bool TraceFilter_IgnorePlayersAndOwner(int entity, int mask, any data)
{
	if (entity == data || (entity >= 1 && entity <= MaxClients))
	{
		return false;
	}
	return true;
}

public bool TraceFilter_IgnorePlayers(int entity, int mask, any data)
{
	if (entity == data || (entity >= 1 && entity <= MaxClients))
	{
		return false;
	}
	return true;
}

void ResetPet(int client)
{
	int entities[4];
	entities[0] = g_ClientPets[client].entityRegular;
	entities[1] = g_ClientPets[client].entityCM;
	entities[2] = g_iClientPet[client];
	entities[3] = g_iPreviewPetEntity[client];
	
	for (int i = 0; i < sizeof(entities); i++)
	{
		if (entities[i] != INVALID_ENT_REFERENCE)
		{
			int iEntity = EntRefToEntIndex(entities[i]);
			if (iEntity != INVALID_ENT_REFERENCE && IsValidEntity(iEntity))
			{
				SetVariantString("");
				AcceptEntityInput(iEntity, "ClearParent");
				
				if(IsValidEntity(iEntity))
				{
					AcceptEntityInput(iEntity, "Kill");
				}
			}
			
			switch(i)
			{
				case 0: g_ClientPets[client].entityRegular = INVALID_ENT_REFERENCE;
				case 1: g_ClientPets[client].entityCM = INVALID_ENT_REFERENCE;
				case 2: g_iClientPet[client] = INVALID_ENT_REFERENCE;
				case 3: g_iPreviewPetEntity[client] = INVALID_ENT_REFERENCE;
			}
		}
	}

	g_ClientPets[client].isFollowing = false;
	g_ClientPets[client].lastThinkTime = 0.0;
	g_ClientPets[client].petIndex = -1;
	g_iLastAnimation[client] = -1;
	g_iLastSpawnTime[client] = -1;
	g_iLastIdleTimes[client] = -1;
}

public bool TraceRayNoPlayers(int entity, int mask, any data)
{
	if (entity == data || (entity >= 1 && entity <= MaxClients))
	{
		return false;
	}

	return true;
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
	ResetPet(client);
	
	g_iSelectedPet[client] = -1;
	g_bHide[client] = false;
	g_bFollowMode[client] = false;
	g_iLastAnimation[client] = -1;
	g_iLastSpawnTime[client] = -1;
	g_iLastIdleTimes[client] = -1;
	
	g_ClientPets[client].entityRegular = INVALID_ENT_REFERENCE;
	g_ClientPets[client].entityCM = INVALID_ENT_REFERENCE;
	g_ClientPets[client].petIndex = -1;
	g_ClientPets[client].isFollowing = false;
	g_ClientPets[client].lastThinkTime = 0.0;
	
	if (g_hTimerPreview[client] != null)
	{
		TriggerTimer(g_hTimerPreview[client], false);
		g_hTimerPreview[client] = null;
	}
}

public void Pets_OnPreviewItem(int client, char[] type, int index)
{
	if (g_hTimerPreviewPet[client] != null)
	{
		TriggerTimer(g_hTimerPreviewPet[client], false);
	}

	if (!StrEqual(type, "pet"))
		return;

	int iPreview = CreateEntityByName("prop_dynamic_override");
	
	if (g_hTimerPreviewPet[client] != null) 
	{
		delete g_hTimerPreviewPet[client];
		g_hTimerPreviewPet[client] = null;
	}
	
	char previewModel[PLATFORM_MAX_PATH];
	if(g_ePetsData[index].model[0] != '\0')
	{
		strcopy(previewModel, sizeof(previewModel), g_ePetsData[index].model);
	}
	else
	{
		LogError("No model for preview pet %d", index);
		return;
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

	g_iPreviewPetEntity[client] = EntIndexToEntRef(iPreview);

	int iRotator = CreateEntityByName("func_rotating");
	DispatchKeyValueVector(iRotator, "origin", fPos);

	DispatchKeyValue(iRotator, "maxspeed", "20");
	DispatchKeyValue(iRotator, "spawnflags", "64");
	DispatchSpawn(iRotator);

	SetVariantString("!activator");
	AcceptEntityInput(iPreview, "SetParent", iRotator, iRotator);
	AcceptEntityInput(iRotator, "Start");

	SDKHook(iPreview, SDKHook_SetTransmit, Pets_Hook_SetTransmit_Preview);

	g_hTimerPreviewPet[client] = CreateTimer(45.0, Timer_KillPreview, client);

	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Spawn Preview CM", client);
		C_PrintToChat(client, "%s %t", g_sChatPrefix, "Spawn Preview", client);
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix, "Spawn Preview", client);
	#endif
}

public Action Pets_Hook_SetTransmit_Preview(int ent, int client)
{
	if (g_iPreviewPetEntity[client] == INVALID_ENT_REFERENCE)
		return Plugin_Handled;

	if (ent == EntRefToEntIndex(g_iPreviewPetEntity[client]))
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action Timer_KillPreview(Handle timer, int client)
{
	g_hTimerPreviewPet[client] = null;

	if (g_iPreviewPetEntity[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iPreviewPetEntity[client]);

		if (entity > 0 && IsValidEdict(entity))
		{
			SDKUnhook(entity, SDKHook_SetTransmit, Pets_Hook_SetTransmit_Preview);
			AcceptEntityInput(entity, "Kill");
		}
	}
	g_iPreviewPetEntity[client] = INVALID_ENT_REFERENCE;

	return Plugin_Stop;
}

#else

void Pets_OnPluginStart() {}
void Pets_OnClientConnected(int client)
{
	#pragma unused client
}
void Pets_OnClientDisconnect(int client)
{
	#pragma unused client
}
void Pets_OnPlayerRunCmd(int client, int &tickcount)
{
	#pragma unused client
	#pragma unused tickcount
}

#endif