//////////////////////////////
//			INCLUDES		//
//////////////////////////////
// Check after compiling Stack/heap size | 16384 cells * 4 = 65536 bytes
#pragma dynamic 16384
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <cstrike>
#include <store>
#include <zephstocks>
#include <adminmenu>

#tryinclude <thirdperson>
#tryinclude <clientmod>		  
#tryinclude <clientmod/multicolors>
#tryinclude <chat-processor>

//////////////////////////////
//		GLOBAL VARIABLES	//
//////////////////////////////
Handle g_hTimerPreview[MAXPLAYERS + 1];

int g_iPreviewEntity[MAXPLAYERS + 1] = {INVALID_ENT_REFERENCE, ...};

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
int hTime;

char g_sChatPrefix[128];
#if defined _clientmod_included
char g_sChatPrefix_CM[128];
#endif

Handle ReloadTimer = INVALID_HANDLE;

//////////////////////////////
//	Core Dependence Files	//
//////////////////////////////
#include "store/stocks.sp"
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
#include "store/preview.sp"

//////////////////////////////
//			MODULES			//
//////////////////////////////
#include "store/modules/admin.sp"
#include "store/modules/attributes.sp"
#include "store/modules/betting.sp"
#include "store/modules/bunnyhop.sp"
#include "store/modules/commands.sp"
#include "store/modules/cpsupport_old.sp"
#include "store/modules/doors.sp"
//#include "store/modules/gifts.sp"
#include "store/modules/glow.sp"
#include "store/modules/godmode.sp"
#include "store/modules/gravity.sp"
#include "store/modules/grentrails.sp"
#include "store/modules/grenskins.sp"
#include "store/modules/hats.sp"
#include "store/modules/health.sp"
#include "store/modules/help.sp"
#include "store/modules/invisibility.sp"
#include "store/modules/jetpack.sp"
#include "store/modules/jihad.sp"
#include "store/modules/knife.sp"
#include "store/modules/lasersight.sp"
#include "store/modules/link.sp"
#include "store/modules/paintball.sp"
#include "store/modules/pets.sp"
#include "store/modules/playerskins.sp"
#include "store/modules/respawn.sp"
#include "store/modules/sounds.sp"
#include "store/modules/speed.sp"
#include "store/modules/sprays.sp"
#include "store/modules/trails.sp"
#include "store/modules/tracers.sp"
#include "store/modules/watergun.sp"
#include "store/modules/weaponcolors.sp"
#include "store/modules/weapons.sp"

//////////////////////////////
//		PLUGIN DEFINITION	//
//////////////////////////////

public Plugin myinfo = 
{
	name = "Store - The Resurrection with preview system",
	author = "Zephyrus, nuclear silo, AiDN, anonim396",
	description = "A completely new Store system with preview rewritten (v34)",
	version = "7.2.3",
	url = "https://github.com/anonim396/store_v34"
};

//////////////////////////////
//		PLUGIN FORWARDS		//
//////////////////////////////

public void OnPluginStart()
{
	RegPluginLibrary("store_zephyrus");
	
	CreateDirectories();
	
	HookEvent("player_spawn", PlayerSpawn);
	HookEvent("player_death", PlayerDeath);
	HookEvent("player_team", PlayerTeam);
	
	for(int i = 1; i <= MaxClients; ++i)
	{
		g_eClients[i].iCredits = -1;
		g_eClients[i].iOriginalCredits = 0;
		g_eClients[i].iItems = -1;
		g_eClients[i].hCreditTimer = INVALID_HANDLE;
	}
	
	Store_Cvars_OnPluginStart();			// store/cvars.sp
	Store_Admin_AdminMenuOnPluginStart();	// store/admin.sp
	Store_Commands_OnPluginStart();			// store/commands.sp
	Store_Events_OnPluginStart();			// store/events.sp
	Store_Configs_ReloadConfig();			// store/configs.sp
	
	LoadTranslations("store.phrases");
	LoadTranslations("common.phrases");
	
	g_iPackageHandler = Store_RegisterHandler("package", "", _, _, _, _, _);
	
	// Initialize the modules
	
	AdminGroup_OnPluginStart();
	Attributes_OnPluginStart();
	Betting_OnPluginStart();
	Bunnyhop_OnPluginStart();
	Commands_OnPluginStart();
	CPSupport_OnPluginStart();
	Doors_OnPluginStart();
	//Gifts_OnPluginStart();
	Glow_OnPluginStart();
	Godmode_OnPluginStart();
	Gravity_OnPluginStart();
	GrenadeTrails_OnPluginStart();
	GrenadeSkins_OnPluginStart();
	Hats_OnPluginStart();
	Health_OnPluginStart();
	Help_OnPluginStart();
	Invisibility_OnPluginStart();
	Jetpack_OnPluginStart();
	Jihad_OnPluginStart();
	Knives_OnPluginStart();
	LaserSight_OnPluginStart();
	Link_OnPluginStart();
	Paintball_OnPluginStart();
	Pets_OnPluginStart();
	PlayerSkins_OnPluginStart();
	Respawn_OnPluginStart();
	Sounds_OnPluginStart();
	Speed_OnPluginStart();
	Sprays_OnPluginStart();
	Trails_OnPluginStart();
	Tracers_OnPluginStart();
	Watergun_OnPluginStart();
	WeaponColors_OnPluginStart();
	Weapons_OnPluginStart();
	
	g_hCustomCredits = CreateArray(3);
	
	LoopIngamePlayers(client)
	{
		OnClientConnected(client);
		OnClientPostAdminCheck(client);
		OnClientPutInServer(client);
	}
}

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	Store_Natives_OnNativeInit(); // store/natives.sp
	Store_Forward_OnForwardInit(); // store/forwards.sp
	
	RegPluginLibrary("store");
	
	return APLRes_Success;
}

public void OnAllPluginsLoaded()
{
	Store_Configs_OnAllPluginLoaded(); // store/configs.sp
}

public void OnPluginEnd()
{
	LoopIngamePlayers(i)
		if(g_eClients[i].bLoaded)
			OnClientDisconnect(i);
}

public void OnLibraryAdded(const char[] name)
{
	
}

//////////////////////////////
//	REST OF PLUGIN FORWARDS	//
//////////////////////////////

public void OnMapStart()
{
	for(int i = 0; i < g_iTypeHandlers; ++i)
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
	Jetpack_OnConfigsExecuted();
	Jihad_OnConfigsExecuted();
	
	Store_Cvars_OnConfigsExecuted();			// store/cvars.sp
	Store_Forward_OnConfigsExecuted();			// store/configs.sp
	Store_DB_ConfigsExecuted_ConnectDatabase();	// store/db.sp
}

public void OnGameFrame()
{
	Trails_OnGameFrame();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	GrenadeSkins_OnEntityCreated(entity, classname);
	GrenadeTrails_OnEntityCreated(entity, classname);
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
	for(int i = 0; i < STORE_MAX_HANDLERS; ++i)
	{
		for(int a = 0; a < STORE_MAX_SLOTS; ++a)
		{
			g_eClients[client].aEquipment[i * STORE_MAX_SLOTS + a] = -2;
			g_eClients[client].aEquipmentSynced[i * STORE_MAX_SLOTS + a] = -2;
		}
	}
	
	Jetpack_OnClientConnected(client);
	Pets_OnClientConnected(client);
	Sprays_OnClientConnected(client);
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
	
	Knives_OnClientPutInServer(client);
}

public void OnClientDisconnect(int client)
{
	if(IsFakeClient(client))
		return;
	
	Betting_OnClientDisconnect(client);
	Pets_OnClientDisconnect(client);
	
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
	
	Jetpack_OnPlayerRunCmd(client, buttons);
	LaserSight_OnPlayerRunCmd(client);
	Pets_OnPlayerRunCmd(client, tickcount);
	Sprays_OnPlayerRunCmd(client, buttons);
	Bunnyhop_OnPlayerRunCmd(client, buttons);
	
	return Plugin_Continue;
}

public void PlayerSpawn(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(IsValidClient(client))
	{
		Glow_PlayerSpawn(client);
		Godmode_OnPlayerSpawn(client);
		Health_OnPlayerSpawn(client);
		Respawn_OnPlayerSpawn(client);
	}
}

public void PlayerDeath(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(IsValidClient(client))
	{
		Glow_PlayerDeath(client);
	}
}

public void PlayerTeam(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(IsValidClient(client))
	{
		Glow_PlayerTeam(client);
	}
}