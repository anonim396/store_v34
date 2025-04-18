//////////////////////////////
//			INCLUDES		//
//////////////////////////////

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

#tryinclude <clientmod>          
#tryinclude <clientmod/multicolors>

#undef REQUIRE_EXTENSIONS
#undef REQUIRE_PLUGIN
#include <store>
#include <zephstocks>
#include <adminmenu>


#pragma semicolon 1
#pragma newdecls required

//////////////////////////////
//		CHANGE IF YOU WANT	//
//////////////////////////////

char g_sChatPrefix[128]		=	"\x04[Store] \x01";

#if defined _clientmod_included
char g_sChatPrefix_CM[128]	=	"{forestgreen}[Store] {snow}";
#endif

//////////////////////////////
//		GLOBAL VARIABLES	//
//////////////////////////////

char g_szGameDir[64];

Handle g_hCustomCredits = INVALID_HANDLE;

int g_iItems = 0;
int g_iTypeHandlers = 0;
int g_iMenuHandlers = 0;
int g_iMenuBack[MAXPLAYERS+1];
int g_iLastSelection[MAXPLAYERS+1];
int g_iSelectedItem[MAXPLAYERS+1];
int g_iSelectedPlan[MAXPLAYERS+1];
int g_iMenuClient[MAXPLAYERS+1];
int g_iMenuNum[MAXPLAYERS+1];
int g_iSpam[MAXPLAYERS+1];
int g_iPackageHandler = -1;
int g_iDatabaseRetries = 0;

bool g_bInvMode[MAXPLAYERS+1];
bool g_bIsInRecurringMenu[MAXPLAYERS + 1] = {false, ...};

char g_iPublicChatTrigger;
//int SilentChatTrigger = 0;
int hTime;

Handle ReloadTimer = INVALID_HANDLE;

//////////////////////////////
//	Core Dependence Files	//
//////////////////////////////
#include "store/api.sp"
#include "store/cvars.sp"
#include "store/db.sp"
#include "store/admin.sp"
#include "store/menus.sp"
#include "store/configs.sp"
#include "store/events.sp"
#include "store/commands.sp"
#include "store/forwards.sp"
#include "store/store_functions.sp"
#include "store/natives.sp"

//////////////////////////////
//			MODULES			//
//////////////////////////////
//#include "store/modules/hats.sp"
//#include "store/modules/tracers.sp"
//#include "store/modules/playerskins.sp"
//#include "store/modules/trails.sp"
//#include "store/modules/grenskins.sp"
//#include "store/modules/grentrails.sp"
//#include "store/modules/weaponcolors.sp"
//#include "store/modules/paintball.sp"
//#include "store/modules/betting.sp"
//#include "store/modules/watergun.sp"
//#include "store/modules/gifts.sp"
//#include "store/modules/scpsupport.sp"
//#include "store/modules/weapons.sp"
//#include "store/modules/help.sp"
//#include "store/modules/jetpack.sp"
//#include "store/modules/bunnyhop.sp"
//#include "store/modules/lasersight.sp"
//#include "store/modules/health.sp"
//#include "store/modules/speed.sp"
//#include "store/modules/gravity.sp"
//#include "store/modules/invisibility.sp"
//#include "store/modules/commands.sp"
//#include "store/modules/doors.sp"
//#include "store/modules/zrclass.sp"
//#include "store/modules/jihad.sp"
//#include "store/modules/godmode.sp"
//#include "store/modules/sounds.sp"
//#include "store/modules/attributes.sp"
//#include "store/modules/respawn.sp"
//#include "store/modules/pets.sp"
//#include "store/modules/sprays.sp"
//#include "store/modules/admin.sp"
//#include "store_misc_voucher.sp"
//#include "store/modules/store_misc_toplists.sp"

//////////////////////////////
//		PLUGIN DEFINITION	//
//////////////////////////////

public Plugin myinfo = 
{
	name = "Store - The Resurrection with preview system",
	author = "Zephyrus, nuclear silo, AiDN, anonim396",
	description = "A completely new Store system with preview rewritten by nuclear silo, ported to v34 anonim396",
	version = "7.1.3",
	url = "https://github.com/nuclearsilo583/zephyrus-store-preview-new-syntax"
};

//////////////////////////////
//		PLUGIN FORWARDS		//
//////////////////////////////

public void OnPluginStart()
{
	RegPluginLibrary("store_zephyrus");
	
	// Setting default values
	for(int i=1;i<=MaxClients;++i)
	{
		g_eClients[i].iCredits = -1;
		g_eClients[i].iOriginalCredits = 0;
		g_eClients[i].iItems = -1;
		g_eClients[i].hCreditTimer = INVALID_HANDLE;
	}
	
	// Load the config file
	Store_Cvars_OnPluginStart(); // store/cvars.sp
	Store_Admin_AdminMenuOnPluginStart(); // store/admin.sp
	Store_Commands_OnPluginStart(); // store/commands.sp
	Store_Events_OnPluginStart(); // store/events.sp
	Store_Configs_ReloadConfig(); // store/configs.sp
	
	// Load the translations file
	LoadTranslations("store.phrases");
	LoadTranslations("common.phrases");
	
	// Initiaze the fake package handler
	g_iPackageHandler = Store_RegisterHandler("package", "", _, _, _, _, _);
	
	// Initialize the modules	
	
	//Hats_OnPluginStart();
	//Tracers_OnPluginStart();
	//Trails_OnPluginStart();
	//PlayerSkins_OnPluginStart();
	//GrenadeSkins_OnPluginStart();
	//GrenadeTrails_OnPluginStart();
	//WeaponColors_OnPluginStart();
	//TFSupport_OnPluginStart();
	//Paintball_OnPluginStart();
	//Watergun_OnPluginStart();
	//Betting_OnPluginStart();
	//Gifts_OnPluginStart();
	//SCPSupport_OnPluginStart();
	//Weapons_OnPluginStart();
	//Help_OnPluginStart();
	//Jetpack_OnPluginStart();
	//Bunnyhop_OnPluginStart();
	//LaserSight_OnPluginStart();
	//Health_OnPluginStart();
	//Gravity_OnPluginStart();
	//Speed_OnPluginStart();
	//Invisibility_OnPluginStart();
	//Commands_OnPluginStart();
	//Doors_OnPluginStart();
	//ZRClass_OnPluginStart();
	//Jihad_OnPluginStart();
	//Godmode_OnPluginStart();
	//Sounds_OnPluginStart();
	//Attributes_OnPluginStart();
	//Respawn_OnPluginStart();
	//Pets_OnPluginStart();
	//Sprays_OnPluginStart();
	//AdminGroup_OnPluginStart();
	//Vounchers_OnPluginStart();
	
	// Initialize handles
	g_hCustomCredits = CreateArray(3);
	
	// Read core.cfg for chat triggers
	ReadCoreCFG();
	
	LoopIngamePlayers(client)
	{
		OnClientConnected(client);
		OnClientPostAdminCheck(client);
		OnClientPutInServer(client);
	}
	
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error,int err_max)
{
	Store_Natives_OnNativeInit(); // store/natives.sp
	Store_Forward_OnForwardInit(); // store/forwards.sp
	
	MarkNativeAsOptional("HideTrails_ShouldHide");
	
	//RegPluginLibrary("store");
	
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	Store_Configs_OnAllPluginLoaded(); // store/configs.sp
	
	//if(GetFeatureStatus(FeatureType_Native, "Donate_RegisterHandler")==FeatureStatus_Available)
	//Donate_RegisterHandler("Store", Store_OnPaymentReceived);
}

public void OnPluginEnd()
{
	LoopIngamePlayers(i)
	if(g_eClients[i].bLoaded)
	OnClientDisconnect(i);
	
	//if(GetFeatureStatus(FeatureType_Native, "Donate_RemoveHandler")==FeatureStatus_Available)
	//Donate_RemoveHandler("Store");
}

public void OnLibraryAdded(const char[] name)
{
	//PlayerSkins_OnLibraryAdded(name);
	//ZRClass_OnLibraryAdded(name);
}

//////////////////////////////
//	REST OF PLUGIN FORWARDS	//
//////////////////////////////

public void OnMapStart()
{
	for(int i=0;i<g_iTypeHandlers;++i)
	{
		if(g_eTypeHandlers[i].fnMapStart != INVALID_FUNCTION)
		{
			Call_StartFunction(g_eTypeHandlers[i].hPlugin, g_eTypeHandlers[i].fnMapStart);
			Call_Finish();
		}
	}
}

public void OnMapEnd()
{
	ReloadTimer = INVALID_HANDLE;
}

public void OnConfigsExecuted()
{
	//Jetpack_OnConfigsExecuted();
	//Jihad_OnConfigsExecuted();
	
	//Store_Cvars_OnConfigsExecuted(); // store/cvars.sp
	
	// Call foward Store_OnConfigsExecuted
	Store_Forward_OnConfigsExecuted(); // store/configs.sp
	
	// Connect to the database
	Store_DB_ConfigsExecuted_ConnectDatabase(); // store/db.sp
}

public void OnGameFrame()
{
	//Trails_OnGameFrame();
	//TFWeapon_OnGameFrame();
	//TFHead_OnGameFrame();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	//GrenadeSkins_OnEntityCreated(entity, classname);
	//GrenadeTrails_OnEntityCreated(entity, classname);
}

//////////////////////////////
//		CLIENT FORWARDS		//
//////////////////////////////

public void OnClientConnected(int client)
{
	g_iSpam[client] = 0;
	g_eClients[client].iUserId = GetClientUserId(client);
	g_eClients[client].iCredits = -1;
	g_eClients[client].iOriginalCredits = 0;
	g_eClients[client].iItems = -1;
	g_eClients[client].bLoaded = false;
	for(int i=0;i<STORE_MAX_HANDLERS;++i)
	{
		for(int a=0;a<STORE_MAX_SLOTS;++a)
		{
			g_eClients[client].aEquipment[i*STORE_MAX_SLOTS+a] = -2;
			g_eClients[client].aEquipmentSynced[i*STORE_MAX_SLOTS+a] = -2;
		}
	}
	
	//PlayerSkins_OnClientConnected(client);
	//Jetpack_OnClientConnected(client);
	//ZRClass_OnClientConnected(client);
	//Pets_OnClientConnected(client);
	//Sprays_OnClientConnected(client);
}

public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client))
	return;
	Store_LoadClientInventory(client);
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
	return;	
}

public void OnClientDisconnect(int client)
{
	if(IsFakeClient(client))
	return;
	
	//Betting_OnClientDisconnect(client);
	//Pets_OnClientDisconnect(client);
	
	Store_SaveClientData(client);
	Store_SaveClientInventory(client);
	Store_SaveClientEquipment(client);
	Store_DisconnectClient(client);
	g_bIsInRecurringMenu[client] = false;
}

public void OnClientSettingsChanged(int client)
{
	GetClientName(client, g_eClients[client].szName_Client, 64);
	if(g_hDatabase)
	SQL_EscapeString(g_hDatabase, g_eClients[client].szName_Client, g_eClients[client].szNameEscaped, 128);
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(!IsClientInGame(client))
	return Plugin_Continue;
	
	//new Action m_iRet = Plugin_Continue;
	
	//Jetpack_OnPlayerRunCmd(client, buttons);
	//LaserSight_OnPlayerRunCmd(client);
	//Pets_OnPlayerRunCmd(client, tickcount);
	//Sprays_OnPlayerRunCmd(client, buttons);
	//m_iRet = Bunnyhop_OnPlayerRunCmd(client, buttons);
	
	return Plugin_Continue;
}

public void ReadCoreCFG()
{
	char m_szFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, STRING(m_szFile), "configs/core.cfg");
	
	Handle hParser = SMC_CreateParser();
	char error[128];
	int line = 0;
	int col = 0;
	
	SMC_SetReaders(hParser, Config_NewSection, Config_KeyValue, Config_EndSection);
	SMC_SetParseEnd(hParser, Config_End);
	
	any result = SMC_ParseFile(hParser, m_szFile, line, col);
	CloseHandle(hParser);
	
	if (result != SMCError_Okay) 
	{
		SMC_GetErrorString(view_as<SMCError>(result), error, sizeof(error));
		LogError("%s on line %d, col %d of %s", error, line, col, m_szFile);
	}
	
}

public SMCResult Config_NewSection(Handle parser, const char[] section, bool quotes) 
{
	if (StrEqual(section, "Core"))
	{
		return SMCParse_Continue;
	}
	
	return SMCParse_Continue;
}

public SMCResult Config_KeyValue(Handle parser, const char[] key, const char[] value, bool key_quotes, bool value_quotes)
{
	if(StrEqual(key, "PublicChatTrigger", false))
	g_iPublicChatTrigger = value[0];
	//else if(StrEqual(key, "SilentChatTrigger", false))
	//	SilentChatTrigger = value[0];
	
	return SMCParse_Continue;
}

public SMCResult Config_EndSection(Handle parser) 
{
    return SMCParse_Continue;
}

public void Config_End(Handle parser, bool halted, bool failed) 
{
}
/*
void NotifyToChat(int client, const char[] format, any ...)
{
	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 3);

	#if defined _clientmod_included
		MC_PrintToChat(client, buffer);
		C_PrintToChat(client, buffer);
	#else
		PrintToChat(client, buffer);
	#endif
}

void NotifyToChatAll(const char[] format, any ...)
{
	char buffer[256];
	VFormat(buffer, sizeof(buffer), format, 2);

	for (int client = 1; client <= MaxClients; client++)
	{
		if (!IsClientInGame(client))
			continue;

		#if defined _clientmod_included
			MC_PrintToChat(client, buffer);
			C_PrintToChat(client, buffer);
		#else
			PrintToChat(client, buffer);
		#endif
	}
}*/