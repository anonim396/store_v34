#if STORE_MODULE_MISC_LOOTBOX

#include <logging>

#define MAX_LOOTBOXES 8
#define LEVEL_GREY 0
#define LEVEL_BLUE 1
#define LEVEL_PURPLE 2
#define LEVEL_RED 3
#define LEVEL_GOLD 4
#define LEVEL_AMOUNT 5

ConVar gc_LBVisible, gc_LBItemSellable;
float g_fLBSellRatio;

char g_sLBPickUpSound[MAX_LOOTBOXES][PLATFORM_MAX_PATH];
char g_sLBModel[MAX_LOOTBOXES][PLATFORM_MAX_PATH];
char g_sLBEfxFile[MAX_LOOTBOXES][PLATFORM_MAX_PATH];
char g_sLBEfxName[MAX_LOOTBOXES][PLATFORM_MAX_PATH];
char g_sLBLootboxItems[MAX_LOOTBOXES][STORE_MAX_ITEMS / 4][LEVEL_AMOUNT][PLATFORM_MAX_PATH];
float g_fLBChance[MAX_LOOTBOXES][LEVEL_AMOUNT];
int g_iLBTime[STORE_MAX_ITEMS];
int g_iLBPriceBack[STORE_MAX_ITEMS];
float g_fLBSellRatioArr[STORE_MAX_ITEMS];

int g_iLBEntityRef[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};
Handle g_hLBTimerColor[MAXPLAYERS + 1];
int g_iLBClientSpeed[MAXPLAYERS + 1];
int g_iLBClientLevel[MAXPLAYERS + 1];
int g_iLBClientBox[MAXPLAYERS + 1];
int g_iLBItemID[MAX_LOOTBOXES];
int g_iLBBoxCount = 0;
int g_iLBItemLevelCount[MAX_LOOTBOXES][LEVEL_AMOUNT];
bool g_bLBRoundEnd = false;
bool g_bLBMapEnd = false;
int g_iLBOpenProp[MAXPLAYERS+1] = {-1, ...};
Handle g_hLBPreviewItem;

void Lootbox_OnPluginStart()
{
	g_hLBPreviewItem = CreateGlobalForward("Store_OnPreviewItem", ET_Ignore, Param_Cell, Param_String, Param_Cell);
	Store_RegisterHandler("lootbox","lootbox", Lootbox_OnMapStart, Lootbox_Reset, Lootbox_Config, Lootbox_Equip, _, false);
	HookEvent("round_end", LB_Event_RoundEnd);
	HookEvent("round_start", LB_Event_RoundStart);
	HookEvent("round_end", LB_Event_End);
	AddGameLogHook(LB_OnLogAction);
	gc_LBVisible = CreateConVar("store_lootbox_visible_for_all", "1", "1 - visible for all / 0 - only owner");
	gc_LBItemSellable = CreateConVar("store_lootbox_item_sellable", "1", "1 - sellable / 0 - nonsellable");
	Store_BeginModuleConfig("sourcemod/store", "lootbox");
	STORE_CFG("store_lootbox_visible_for_all", "1");
	STORE_CFG("store_lootbox_item_sellable", "1");
	Store_EndModuleConfig("sourcemod/store", "lootbox");
}

void Lootbox_OnConfigExecuted()
{
	g_fLBSellRatio = FindConVar("sm_store_sell_ratio").FloatValue;
	if (g_fLBSellRatio < 0.1)
		g_fLBSellRatio = 0.6;
}

void Lootbox_OnMapEnd()
{
	g_bLBMapEnd = false;
}

void Lootbox_OnClientDisconnect(int client)
{
	g_iLBClientBox[client] = -1;
	RequestFrame(LB_Frame_DeleteBox, client);
}

void Lootbox_OnClientPostAdminCheck(int client)
{
	g_iLBOpenProp[client] = -1;
}

public Action LB_OnLogAction(const char[] message)
{
	if( StrContains( message , "changed map to" ) != -1)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (g_iLBEntityRef[i] != INVALID_ENT_REFERENCE)
			{
				Store_GiveItem(i, g_iLBItemID[g_iLBClientBox[i]], 0, 0, 0);
				#if defined _clientmod_included
					MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "You haven't opend the box in given time CM");
					C_PrintToChat(i, "%s %t", g_sChatPrefix, "You haven't opend the box in given time");
				#else
					PrintToChat(i, "%s %t", g_sChatPrefix, "You haven't opend the box in given time");
				#endif
			}
			g_iLBClientBox[i] = -1;
			RequestFrame(LB_Frame_DeleteBox, i);
		}
		g_bLBMapEnd = true;
	}
	return Plugin_Continue;
}

public void LB_Event_End(Event event, const char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iLBEntityRef[i] != INVALID_ENT_REFERENCE)
		{
			Store_GiveItem(i, g_iLBItemID[g_iLBClientBox[i]], 0, 0, 0);
			#if defined _clientmod_included
				MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "You haven't opend the box in given time CM");
				C_PrintToChat(i, "%s %t", g_sChatPrefix, "You haven't opend the box in given time");
			#else
				PrintToChat(i, "%s %t", g_sChatPrefix, "You haven't opend the box in given time");
			#endif
		}
		g_iLBClientBox[i] = -1;
		RequestFrame(LB_Frame_DeleteBox, i);
	}
	g_bLBMapEnd = true;
}

public void Lootbox_OnMapStart()
{
	g_bLBMapEnd = false;
	char sBuffer[128];

	for (int i = 0; i < g_iLBBoxCount; i++)
	{
		PrecacheModel(g_sLBModel[i], true);
		AddFileToDownloadsTable(g_sLBModel[i]);

		if (!g_sLBEfxName[i][0])
			continue;

		PrecacheParticleSystem(g_sLBEfxName[i]);
		if (FileExists(g_sLBEfxFile[i], true) && g_sLBEfxFile[i][0])
		{
			AddFileToDownloadsTable(g_sLBEfxFile[i]);
			PrecacheGeneric(g_sLBEfxFile[i], true);
		}

		FormatEx(sBuffer, sizeof(sBuffer), "sound/%s", g_sLBPickUpSound[i]);
		if (FileExists(sBuffer, true) && g_sLBPickUpSound[i][0])
		{
			AddFileToDownloadsTable(sBuffer);
			PrecacheSound(g_sLBPickUpSound[i], true);
		}
	}

	PrecacheSound("ui/csgo_ui_crate_item_scroll.wav", true);
}

public void Lootbox_Reset()
{
	g_iLBBoxCount = 0;

	for (int i = 0; i < g_iLBBoxCount; i++)
	{
		for (int j = 0; j < LEVEL_AMOUNT; j++)
		{
			g_iLBItemLevelCount[i][j] = 0;
		}
	}
}

public bool Lootbox_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iLBBoxCount);

	kv.GetString("model", g_sLBModel[g_iLBBoxCount], PLATFORM_MAX_PATH);

	if (!FileExists(g_sLBModel[g_iLBBoxCount], true))
	{
		Store_SQLLogMessage(0, LOG_ERROR, "Can't find model %s.", g_sLBModel[g_iLBBoxCount]);
		return false;
	}

	kv.GetString("file", g_sLBEfxFile[g_iLBBoxCount], PLATFORM_MAX_PATH);
	kv.GetString("name", g_sLBEfxName[g_iLBBoxCount], PLATFORM_MAX_PATH);
	kv.GetString("sound", g_sLBPickUpSound[g_iLBBoxCount], PLATFORM_MAX_PATH, "");
	g_iLBTime[g_iLBBoxCount] = kv.GetNum("time", 0);
	g_iLBPriceBack[g_iLBBoxCount] = kv.GetNum("price_back", 0);
	g_fLBSellRatioArr[g_iLBBoxCount] = kv.GetFloat("sell_ratio", 0.5);

	float percent = 0.0;
	g_fLBChance[g_iLBBoxCount][LEVEL_GREY] = kv.GetFloat("grey", 60.0);
	g_fLBChance[g_iLBBoxCount][LEVEL_BLUE] = kv.GetFloat("blue", 22.0);
	g_fLBChance[g_iLBBoxCount][LEVEL_PURPLE] = kv.GetFloat("purple", 10.0);
	g_fLBChance[g_iLBBoxCount][LEVEL_RED] = kv.GetFloat("red", 6.0);
	g_fLBChance[g_iLBBoxCount][LEVEL_GOLD] = kv.GetFloat("gold", 2.0);

	for (int i = 0; i < LEVEL_AMOUNT; i++)
	{
		percent += g_fLBChance[g_iLBBoxCount][i];
	}
	if (percent != 100.0)
	{
		Store_SQLLogMessage(0, LOG_ERROR, "Lootbox #%i - Sum of levels is not 100%", g_iLBBoxCount + 1);
		return false;
	}

	g_iLBItemID[g_iLBBoxCount] = itemid;

	kv.JumpToKey("Items");
	kv.GotoFirstSubKey(false);
	do
	{
		char sBuffer[16];
		int lvlindex = -1;

		kv.GetSectionName(sBuffer, sizeof(sBuffer));
		if (StrEqual(sBuffer,"grey", false))
		{
			lvlindex = LEVEL_GREY;
		}
		else if (StrEqual(sBuffer,"blue", false))
		{
			lvlindex = LEVEL_BLUE;
		}
		else if (StrEqual(sBuffer,"purple", false))
		{
			lvlindex = LEVEL_PURPLE;
		}
		else if (StrEqual(sBuffer,"red", false))
		{
			lvlindex = LEVEL_RED;
		}
		else if (StrEqual(sBuffer,"gold", false))
		{
			lvlindex = LEVEL_GOLD;
		}

		if (lvlindex == -1)
		{
			Store_SQLLogMessage(0, LOG_ERROR, "Lootbox #%i - unknown level color: %s", sBuffer);
			return false;
		}

		kv.GetString(NULL_STRING, g_sLBLootboxItems[g_iLBBoxCount][g_iLBItemLevelCount[g_iLBBoxCount][lvlindex]][lvlindex], PLATFORM_MAX_PATH);
		g_iLBItemLevelCount[g_iLBBoxCount][lvlindex]++;
	}
	while (kv.GotoNextKey(false));

	kv.GoBack();
	kv.GoBack();

	g_iLBBoxCount++;

	return true;
}

public int Lootbox_Equip(int client, int itemid)
{
	if (GameRules_GetProp("m_bWarmupPeriod")) // Check if client open in warm up ? This will cause massive error log when they are open at the same time warm up end.
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Lootbox warm up CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Lootbox warm up");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Lootbox warm up");
		#endif
		return 1;
	}
	if (g_bLBRoundEnd) // Check if client open in after round end has call ? This also cause massive error log on next round since case's prop are invalid.
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Lootbox round ended CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Lootbox round ended");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Lootbox round ended");
		#endif
		return 1;
	}
	if (g_bLBMapEnd) // Check if client open in after round end has call ? This also cause massive error log on next round since case's prop are invalid.
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Lootbox map ended CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Lootbox map ended");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Lootbox map ended");
		#endif
		return 1;
	}
	if (!IsPlayerAlive(client))
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Must be Alive CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Must be Alive");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Must be Alive");
		#endif
		return 1;
	}

	if (g_iLBEntityRef[client] != INVALID_ENT_REFERENCE) // Prevent spam. The previous case wont be killed.
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Lootbox case is opening CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Lootbox case is opening");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Lootbox case is opening");
		#endif
		return 1;
	}
	

	if (DropLootbox(client, Store_GetDataIndex(itemid)))
		return 0;

	return 1;
	
}

bool DropLootbox(int client, int index)
{
	int iLootbox = CreateEntityByName("prop_dynamic_override"); //prop_dynamic_override

	if (!iLootbox)
		return false;

//	char sBuffer[32];
//	FormatEx(sBuffer, 32, "lootbox_%d", iLootbox);

	float fOri[3], fAng[3], fRad[2], fPos[3];

	GetClientAbsOrigin(client, fOri);
	GetClientAbsAngles(client, fAng);

	fRad[0] = DegToRad(fAng[0]);
	fRad[1] = DegToRad(fAng[1]);

	fPos[0] = fOri[0] + 64 * Cosine(fRad[0]) * Cosine(fRad[1]);
	fPos[1] = fOri[1] + 64 * Cosine(fRad[0]) * Sine(fRad[1]);
	fPos[2] = fOri[2] + 4 * Sine(fRad[0]);

	fAng[0] *= -1.0;
	fAng[1] *= -1.0;

	fPos[2] += 35;

//	SetEntPropString(iLootbox, Prop_Data, "m_iName", sBuffer);

	DispatchKeyValue(iLootbox, "model", g_sLBModel[index]);
	DispatchSpawn(iLootbox);
	SetVariantString("fall");
	AcceptEntityInput(iLootbox, "SetAnimation");
	AcceptEntityInput(iLootbox, "Enable");
	ActivateEntity(iLootbox);
	
	//EmitAmbientSound("ui/panorama/case_drop_01.wav", fPos, _, _, _, _, _, _);
	EmitSoundToClient(client, "ui/panorama/case_drop_01.wav", iLootbox, _, _, _, _, _, _);

	TeleportEntity(iLootbox, fPos, fAng, NULL_VECTOR);
	
	LB_CreateGlow(iLootbox);
	int iLight = CreateLight(iLootbox, fPos);
	int iRotator = CreateRotator(iLootbox, fPos);

	DataPack pack = new DataPack();
	g_iLBClientBox[client] = index;
	pack.WriteCell(client);
	pack.WriteCell(iLootbox);
	pack.WriteCell(iRotator);
	pack.WriteCell(iLight);
	g_iLBClientSpeed[client] = 235;
	g_hLBTimerColor[client] = CreateTimer(0.2, Timer_Color, pack, TIMER_REPEAT);

	if(!gc_LBVisible.BoolValue)
	{
		SDKHook(iLootbox, SDKHook_SetTransmit, LB_Hook_SetTransmit);
		SDKHook(iLight, SDKHook_SetTransmit, LB_Hook_SetTransmit);
	}
	
	HookSingleEntityOutput(iLootbox, "OnAnimationDone", Case_OnAnimationDone, true);

	g_iLBEntityRef[client] = EntIndexToEntRef(iLootbox);

	return true;
}

public void Case_OnAnimationDone(const char[] output, int caller, int activator, float delay) 
{
	if(IsValidEntity(caller))
	{
		SetVariantString("open");
		AcceptEntityInput(caller, "SetAnimation");
	}
}

void LB_CreateGlow(int ent)
{
	int iOffset = GetEntSendPropOffs(ent, "m_clrGlow");
	SetEntProp(ent, Prop_Send, "m_bShouldGlow", true, true);
	SetEntProp(ent, Prop_Send, "m_nGlowStyle", 0);
	SetEntPropFloat(ent, Prop_Send, "m_flGlowMaxDist", 2000.0);

	SetEntData(ent, iOffset, 250, _, true);
	SetEntData(ent, iOffset + 1, 210, _, true);
	SetEntData(ent, iOffset + 2, 0, _, true);
	SetEntData(ent, iOffset + 3, 255, _, true);
}

int CreateRotator(int ent, float pos[3])
{
	int iRotator = CreateEntityByName("func_rotating");
	DispatchKeyValueVector(iRotator, "origin", pos);

	DispatchKeyValue(iRotator, "spawnflags", "64");
	DispatchKeyValue(iRotator, "maxspeed", "200");
	DispatchSpawn(iRotator);

	SetVariantString("!activator");
	AcceptEntityInput(ent, "SetParent", iRotator, iRotator);
	AcceptEntityInput(iRotator, "Start");

	return iRotator;
}

int CreateLight(int ent, float pos[3])
{
	int iLight = CreateEntityByName("light_dynamic");

	DispatchKeyValue(iLight, "_light", "255 210 0 255");
	DispatchKeyValue(iLight, "brightness", "7");
	DispatchKeyValueFloat(iLight, "spotlight_radius", 260.0);
	DispatchKeyValueFloat(iLight, "distance", 100.0);
	DispatchKeyValue(iLight, "style", "0");

	DispatchSpawn(iLight); 
	TeleportEntity(iLight, pos, NULL_VECTOR, NULL_VECTOR);

	SetVariantString("!activator");
	AcceptEntityInput(iLight, "SetParent", ent, iLight, 0);

	return iLight;
}

public Action Timer_Open(Handle timer, int client)
{
	char temp[64], sUId[64], sParts[2][64], sCredits[2][64];
	strcopy(temp, sizeof(temp), g_sLBLootboxItems[g_iLBClientBox[client]][GetRandomInt(0, g_iLBItemLevelCount[g_iLBClientBox[client]][g_iLBClientLevel[client]] - 1)][g_iLBClientLevel[client]]); // sry
	
	int iCount = ExplodeString(temp, "-", sParts, 2, 64);
	sUId = sParts[0];
	int time = StringToInt(sParts[1]);
	int itemid = Store_GetItemIdbyUniqueId(sUId);
	
	char name[64];
	GetClientName(client, name, sizeof(name));
	
	if (time == 0)
		iCount = 1;

	// Items not found but second slitted string is credits (this is credits in lootbox)
	if (itemid == -1 && StrEqual(sParts[1], "credits"))
	{
		/***************
		IDK what the fuck I've done at these lines. o.o
		***************/
		int credits;
		bool g_bNegative;
		
		RequestFrame(LB_Frame_DeleteBox, client);
		
		//Slit the first part for random credit.
		//PrintToConsoleAll("%s", sParts[0]);
		ExplodeString(sParts[0], ",", sCredits, 2, 64);
		if(sCredits[1][0] == '\0') // If the second string is NULL_STRING
		{
			credits = StringToInt(sCredits[0]);
			if(credits<=0)
				g_bNegative = true;
			
			//PrintToConsoleAll("Null String");
		}
		else
		{
			int lower_bound, upper_bound;
			lower_bound = StringToInt(sCredits[0]);
			upper_bound = StringToInt(sCredits[1]);

			if(lower_bound <= 0 || upper_bound <= 0)
				g_bNegative = true;
				
			if(lower_bound>upper_bound)
				credits = GetRandomInt(upper_bound, lower_bound);
			else if (lower_bound<upper_bound)
				credits = GetRandomInt(lower_bound, upper_bound);
			else credits = lower_bound;
				
			//PrintToConsoleAll("2 Null String");
		}
		
		if(g_bNegative) // credits is negative number or 0
		{
			Store_GiveItem(client, g_iLBItemID[g_iLBClientBox[client]], 0, 0, 0);
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Error occured, item back. Inform admin log CM");
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "Error occured, item back. Inform admin log");
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "Error occured, item back. Inform admin log");
			#endif
			Store_SQLLogMessage(client, LOG_ERROR, "Can't convert credits to posible give for lootbox #%i on level #%i.", g_iLBClientBox[client], g_iLBClientLevel[client]);
			return Plugin_Stop;
		}

		Store_SetClientCredits(client, Store_GetClientCredits(client) + credits);
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Chat won lootbox item credits CM", credits);
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Chat won lootbox item credits", credits);
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Chat won lootbox item credits", credits);
		#endif
		EmitSoundToClient(client, g_sLBPickUpSound[g_iLBClientBox[client]], client, _, _, _, _, _, _);
		
		return Plugin_Stop;
	}
	else if (itemid == -1) //Item not found
	{
		RequestFrame(LB_Frame_DeleteBox, client);
		Store_GiveItem(client, g_iLBItemID[g_iLBClientBox[client]], 0, 0, 0);
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Error occured, item back. Inform admin log CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Error occured, item back. Inform admin log");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Error occured, item back. Inform admin log");
		#endif

		Store_SQLLogMessage(client, LOG_ERROR, "Can't find item uid %s for lootbox #%i on level #%i.", sUId, g_iLBClientBox[client], g_iLBClientLevel[client]);
		return Plugin_Stop;
	}
	
	Store_Item item;
	Store_GetItem(itemid, item);
	Type_Handler handler;
	Store_GetHandler(item.iHandler, handler);

	if (Store_HasClientItem(client, itemid))
	{
		if (g_iLBPriceBack[g_iLBClientBox[client]] <= 0)
		{
			Store_GiveItem(client, g_iLBItemID[g_iLBClientBox[client]], 0, 0, 0);
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Error occured, no price back. Inform admin log CM");
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "Error occured, no price back. Inform admin log");
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "Error occured, no price back. Inform admin log");
			#endif
		}
		else
		{
			Store_SetClientCredits(client, Store_GetClientCredits(client) + RoundFloat(g_iLBPriceBack[g_iLBClientBox[client]]*view_as<float>(g_fLBSellRatioArr[g_iLBClientBox[client]])));
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Already own item from box. Get Credits price back CM", item.szName, handler.szType, RoundFloat(g_iLBPriceBack[g_iLBClientBox[client]]*view_as<float>(g_fLBSellRatioArr[g_iLBClientBox[client]])), g_sCreditsName);
				C_PrintToChat(client, "%s %t", g_sChatPrefix, "Already own item from box. Get Credits price back", item.szName, handler.szType, RoundFloat(g_iLBPriceBack[g_iLBClientBox[client]]*view_as<float>(g_fLBSellRatioArr[g_iLBClientBox[client]])), g_sCreditsName);
			#else
				PrintToChat(client, "%s %t", g_sChatPrefix, "Already own item from box. Get Credits price back", item.szName, handler.szType, RoundFloat(g_iLBPriceBack[g_iLBClientBox[client]]*view_as<float>(g_fLBSellRatioArr[g_iLBClientBox[client]])), g_sCreditsName);
			#endif
			
			if (g_iLBClientLevel[client] == LEVEL_RED)
			{
				#if defined _clientmod_included
					MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Chat won lootbox item red CM", name, item.szName, handler.szType);
					C_PrintToChatAll("%s %t", g_sChatPrefix, "Chat won lootbox item red", name, item.szName, handler.szType);
				#else
					PrintToChatAll("%s %t", g_sChatPrefix, "Chat won lootbox item red", name, item.szName, handler.szType);
				#endif
			}
			if (g_iLBClientLevel[client] == LEVEL_GOLD)
			{
				#if defined _clientmod_included
					MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Chat won lootbox item gold CM", name, item.szName, handler.szType);
					C_PrintToChatAll("%s %t", g_sChatPrefix, "Chat won lootbox item gold", name, item.szName, handler.szType);
				#else
					PrintToChatAll("%s %t", g_sChatPrefix, "Chat won lootbox item gold", name, item.szName, handler.szType);
				#endif
			}
		}
	}
	else
	{
		if(g_iLBTime[g_iLBClientBox[client]] && iCount < 2)
		{
			if(gc_LBItemSellable.IntValue)
			{
				if(item.iPlans!=0)
				{
					Store_GiveItem(client, itemid, _, GetTime() + g_iLBTime[g_iLBClientBox[client]], 2);
				}
				else Store_GiveItem(client, itemid, _, GetTime() + g_iLBTime[g_iLBClientBox[client]], item.iPrice);
			}
			else Store_GiveItem(client, itemid, _, GetTime() + g_iLBTime[g_iLBClientBox[client]], 1);
		}
		else if (g_iLBTime[g_iLBClientBox[client]] && iCount > 1)
		{
			if(gc_LBItemSellable.IntValue)
			{
				if(item.iPlans!=0)
				{
					Store_GiveItem(client, itemid, _, GetTime() + time, 2);
				}
				else Store_GiveItem(client, itemid, _, GetTime() + time, item.iPrice);
			}
			else Store_GiveItem(client, itemid, _, GetTime() + time, 1);
		}
		else 
		{
			if(gc_LBItemSellable.IntValue)
			{
				if(item.iPlans!=0)
				{
					Store_GiveItem(client, itemid, _, _, 2);
				}
				else Store_GiveItem(client, itemid, _, _, item.iPrice);
			}
			else Store_GiveItem(client, itemid, _, _, 1);
		}
		char sBuffer[128];
		Format(sBuffer, sizeof(sBuffer), "%t", "You won lootbox item", item.szName, handler.szType);

		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, sBuffer);
			C_PrintToChat(client, "%s %t", g_sChatPrefix, sBuffer);
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, sBuffer);
		#endif
		Store_SQLLogMessage(client, LOG_EVENT, "Opened a lootbox #%i. Item: %s.", g_iLBClientBox[client], sUId);
		if (g_iLBClientLevel[client] == LEVEL_RED)
		{
			#if defined _clientmod_included
				MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Chat won lootbox item red CM", name, item.szName, handler.szType);
				C_PrintToChatAll("%s %t", g_sChatPrefix, "Chat won lootbox item red", name, item.szName, handler.szType);
			#else
				PrintToChatAll("%s %t", g_sChatPrefix, "Chat won lootbox item red", name, item.szName, handler.szType);
			#endif
		}
		if (g_iLBClientLevel[client] == LEVEL_GOLD)
		{
			#if defined _clientmod_included
				MC_PrintToChatAll("%s %t", g_sChatPrefix_CM, "Chat won lootbox item gold CM", name, item.szName, handler.szType);
				C_PrintToChatAll("%s %t", g_sChatPrefix, "Chat won lootbox item gold", name, item.szName, handler.szType);
			#else
				PrintToChatAll("%s %t", g_sChatPrefix, "Chat won lootbox item gold", name, item.szName, handler.szType);
			#endif
		}
		
		#if defined _clientmod_included
			CRemoveTags(sBuffer, sizeof(sBuffer));
		#else
			Store_RemoveChatTags(sBuffer, sizeof(sBuffer));
		#endif
		PrintHintText(client, sBuffer);
	}

	if (item.bPreview && IsPlayerAlive(client))
	{
		Call_StartForward(g_hLBPreviewItem);
		Call_PushCell(client);
		Call_PushString(handler.szType);
		Call_PushCell(item.iData);
		Call_Finish();
	}

	//float fVec[3];
	//GetClientAbsOrigin(client, fVec);
	//EmitAmbientSound(g_sLBPickUpSound[g_iLBClientBox[client]], fVec, _, _, _, _, _, _);
	EmitSoundToClient(client, g_sLBPickUpSound[g_iLBClientBox[client]], client, _, _, _, _, _, _);

	RequestFrame(LB_Frame_DeleteBox, client);

	return Plugin_Handled;
}

public Action Timer_RemoveEfx(Handle timer, int reference)
{
	int iEnt = EntRefToEntIndex(reference);

	if (IsValidEdict(iEnt))
	{
		AcceptEntityInput(iEnt, "kill");
	}
	
	return Plugin_Continue;
}

int PrecacheParticleSystem(const char[] particleSystem)
{
	static int particleEffectNames = INVALID_STRING_TABLE;

	if (particleEffectNames == INVALID_STRING_TABLE)
	{
		if ((particleEffectNames = FindStringTable("ParticleEffectNames")) == INVALID_STRING_TABLE)
			return INVALID_STRING_INDEX;
	}

	int index = FindStringIndex2(particleEffectNames, particleSystem);
	if (index == INVALID_STRING_INDEX)
	{
		int numStrings = GetStringTableNumStrings(particleEffectNames);
		if (numStrings >= GetStringTableMaxStrings(particleEffectNames))
			return INVALID_STRING_INDEX;

		AddToStringTable(particleEffectNames, particleSystem);
		index = numStrings;
	}

	return index;
}

int FindStringIndex2(int tableidx, const char[] str)
{
	char buf[1024];

	int numStrings = GetStringTableNumStrings(tableidx);
	for (int i = 0; i < numStrings; i++)
	{
		ReadStringTable(tableidx, i, buf, sizeof(buf));

		if (StrEqual(buf, str))
			return i;
	}

	return INVALID_STRING_INDEX;
}

public Action LB_Hook_SetTransmit(int ent, int client)
{
	if (g_iLBEntityRef[client] == INVALID_ENT_REFERENCE)
		return Plugin_Handled;

	if (ent == EntRefToEntIndex(g_iLBEntityRef[client]))
		return Plugin_Continue;

	return Plugin_Handled;
}

public Action Timer_Color(Handle timer, DataPack pack)
{
	pack.Reset();
	int client = pack.ReadCell();

	if (g_iLBClientBox[client] == -1)
		return Plugin_Stop;

	int lootbox = pack.ReadCell();
	int rotator = pack.ReadCell();
	int light = pack.ReadCell();

	int index = g_iLBClientBox[client];
	float fPos[3];
	GetEntPropVector(lootbox, Prop_Send, "m_vecOrigin", fPos);
	fPos[2] -= 0.2;
	TeleportEntity(lootbox, fPos, NULL_VECTOR, NULL_VECTOR);
	g_iLBClientSpeed[client] -= 5;
	//EmitAmbientSound("ui/csgo_ui_crate_item_scroll.wav", fPos, _, _, _, _, _, _);
	EmitSoundToClient(client, "ui/csgo_ui_crate_item_scroll.wav", lootbox, _, _, _, _, _, _);

	char sBuffer[128];
	IntToString(g_iLBClientSpeed[client], sBuffer, sizeof(sBuffer));
	DispatchKeyValue(rotator, "maxspeed", sBuffer);
	AcceptEntityInput(rotator, "Start");

	if (g_iLBClientSpeed[client] < 1)
	{

		if (g_sLBEfxName[g_iLBClientBox[client]][0])
		{
			CreateEffect(client, fPos);
		}

		CreateTimer(0.5, Timer_Open, client);

		return Plugin_Stop;
	}

	switch(g_iLBClientSpeed[client])
	{
		case 120:
		{
			g_hLBTimerColor[client] = CreateTimer(0.31, Timer_Color, pack, TIMER_REPEAT);
			return Plugin_Stop;
		}
		case 60:
		{
			g_hLBTimerColor[client] = CreateTimer(0.35, Timer_Color, pack, TIMER_REPEAT);
			return Plugin_Stop;
		}
		case 40:
		{
			g_hLBTimerColor[client] = CreateTimer(0.4, Timer_Color, pack, TIMER_REPEAT);
			return Plugin_Stop;
		}
		case 10:
		{
			g_hLBTimerColor[client] = CreateTimer(0.5, Timer_Color, pack, TIMER_REPEAT); //0.6
			return Plugin_Stop;
		}
	}

	int iOffset = GetEntSendPropOffs(lootbox, "m_clrGlow");
	float percent = GetRandomFloat(0.0001, 100.0);

	if (percent < g_fLBChance[index][LEVEL_GREY])
	{
		SetEntityRenderColor(lootbox, 155, 255, 255, 255);
		g_iLBClientLevel[client] = LEVEL_GREY;
		SetEntData(lootbox, iOffset, 155, _, true);
		SetEntData(lootbox, iOffset + 1, 255, _, true);
		SetEntData(lootbox, iOffset + 2, 255, _, true);
		SetEntData(lootbox, iOffset + 3, 255, _, true);
		DispatchKeyValue(light, "_light", "155 255 255 255");
		return Plugin_Continue;
	}

	percent -= g_fLBChance[index][LEVEL_GREY];
	if (percent < g_fLBChance[index][LEVEL_BLUE])
	{
		SetEntityRenderColor(lootbox, 0, 0, 255, 255);
		SetEntData(lootbox, iOffset, 0, _, true);
		SetEntData(lootbox, iOffset + 1, 0, _, true);
		SetEntData(lootbox, iOffset + 2, 255, _, true);
		SetEntData(lootbox, iOffset + 3, 255, _, true);
		DispatchKeyValue(light, "_light", "0 0 255 255");
		g_iLBClientLevel[client] = LEVEL_BLUE;
		return Plugin_Continue;
	}

	percent -= g_fLBChance[index][LEVEL_BLUE];
	if (percent < g_fLBChance[index][LEVEL_PURPLE])
	{
		SetEntityRenderColor(lootbox, 255, 0, 255, 255);
		SetEntData(lootbox, iOffset, 255, _, true);
		SetEntData(lootbox, iOffset + 1, 0, _, true);
		SetEntData(lootbox, iOffset + 2, 255, _, true);
		SetEntData(lootbox, iOffset + 3, 255, _, true);
		DispatchKeyValue(light, "_light", "255 0 255 255");
		g_iLBClientLevel[client] = LEVEL_PURPLE;
		return Plugin_Continue;
	}

	percent -= g_fLBChance[index][LEVEL_PURPLE];
	if (percent < g_fLBChance[index][LEVEL_RED])
	{
		SetEntityRenderColor(lootbox, 255, 0, 0, 255);
		SetEntData(lootbox, iOffset, 255, _, true);
		SetEntData(lootbox, iOffset + 1, 0, _, true);
		SetEntData(lootbox, iOffset + 2, 0, _, true);
		SetEntData(lootbox, iOffset + 3, 255, _, true);
		DispatchKeyValue(light, "_light", "255 0 0 255");
		g_iLBClientLevel[client] = LEVEL_RED;
		return Plugin_Continue;
	}
	

	percent -= g_fLBChance[index][LEVEL_RED];
	if (percent < g_fLBChance[index][LEVEL_GOLD])
	{
		SetEntityRenderColor(lootbox, 255, 255, 0, 255);
		SetEntData(lootbox, iOffset, 255, _, true);
		SetEntData(lootbox, iOffset + 1, 255, _, true);
		SetEntData(lootbox, iOffset + 2, 0, _, true);
		SetEntData(lootbox, iOffset + 3, 255, _, true);
		DispatchKeyValue(light, "_light", "255 255 0 255");
		g_iLBClientLevel[client] = LEVEL_GOLD;
		return Plugin_Continue;
	}

	return Plugin_Continue;
}

void CreateEffect(int client, float fPos[3])
{
	int iEfx = CreateEntityByName("info_particle_system");
	DispatchKeyValue(iEfx, "start_active", "0");
	DispatchKeyValue(iEfx, "effect_name", g_sLBEfxName[g_iLBClientBox[client]]);
	DispatchSpawn(iEfx);
	ActivateEntity(iEfx);
	TeleportEntity(iEfx, fPos, NULL_VECTOR, NULL_VECTOR);
	AcceptEntityInput(iEfx, "Start");

	if(!gc_LBVisible.BoolValue)
	{
		SDKHook(iEfx, SDKHook_SetTransmit, LB_Hook_SetTransmit);
	}

	CreateTimer(1.5, Timer_RemoveEfx, EntIndexToEntRef(iEfx));
//	PrintToServer("fired %s", g_sLBEfxName[g_iLBClientBox[client]]);
}


public void LB_Event_RoundEnd(Event event, char[] name, bool dontBroadcast)
{
	for (int i = 1; i <= MaxClients; i++)
	{
		if (g_iLBEntityRef[i] != INVALID_ENT_REFERENCE)
		{
			Store_GiveItem(i, g_iLBItemID[g_iLBClientBox[i]], 0, 0, 0);

			#if defined _clientmod_included
				MC_PrintToChat(i, "%s %t", g_sChatPrefix_CM, "You haven't opend the box in given time CM");
				C_PrintToChat(i, "%s %t", g_sChatPrefix, "You haven't opend the box in given time");
			#else
				PrintToChat(i, "%s %t", g_sChatPrefix, "You haven't opend the box in given time");
			#endif
		}
		g_iLBClientBox[i] = -1;

		RequestFrame(LB_Frame_DeleteBox, i);
	}
	g_bLBRoundEnd = true;
}

public void LB_Event_RoundStart(Event event, char[] name, bool dontBroadcast)
{
	g_bLBRoundEnd = false;
}

public void LB_Frame_DeleteBox(int client)
{
	if (g_iLBEntityRef[client] != INVALID_ENT_REFERENCE)
	{
		int entity = EntRefToEntIndex(g_iLBEntityRef[client]);

		if (entity > 0 && IsValidEdict(entity))
		{
			SDKUnhook(entity, SDKHook_SetTransmit, LB_Hook_SetTransmit);
			AcceptEntityInput(entity, "Kill");
		}
	}
	g_iLBEntityRef[client] = INVALID_ENT_REFERENCE;
}

stock int GetPlayerFromOpenEntity(int entity)
{
	for (int i = 1; i <= MaxClients; ++i)
	{
		if(!IsValidClient(i)) continue;

		if(g_iLBOpenProp[i] == entity) return i;
	}

	return -1;
}
#if !defined _store_stocks_included
stock bool IsValidClient(int client, bool nobots = true)
{ 
	if (client <= 0 || client > MaxClients || !IsClientConnected(client) || (nobots && IsFakeClient(client)))
	{
		return false; 
	}
	return IsClientInGame(client); 
}
#endif

#else
void Lootbox_OnPluginStart() {}
void Lootbox_OnConfigExecuted()
{
}
void Lootbox_OnMapEnd() {}
void Lootbox_OnClientDisconnect(int client)
{
	#pragma unused client
}
void Lootbox_OnClientPostAdminCheck(int client)
{
	#pragma unused client
}
#endif