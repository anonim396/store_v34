//////////////////////////////
//			INCLUDES		//
//////////////////////////////
// Check after compiling Stack/heap size | 16384 cells * 4 = 65536 bytes
#pragma dynamic 32768
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <clientprefs>
#include <cstrike>
#include <store>
#include <adminmenu>


#tryinclude <thirdperson>
#tryinclude <clientmod>		  
#tryinclude <clientmod/multicolors>
#tryinclude <chat-processor>
#tryinclude <UTF-8-string>


// Module flags: set to 0 to disable
#define STORE_MODULE_ADMIN				1
#define STORE_MODULE_ATTRIBUTES			1
#define STORE_MODULE_BETTING			1
#define STORE_MODULE_BUNNYHOP			1
#define STORE_MODULE_COMMANDS			1
#define STORE_MODULE_CPSUPPORT			1
#define STORE_MODULE_CREDITS_MULTIPLIER	1
#define STORE_MODULE_DOORS				1
#define STORE_MODULE_GIFTS				0
#define STORE_MODULE_GLOW				1
#define STORE_MODULE_GODMODE			1
#define STORE_MODULE_GRAVITY			1
#define STORE_MODULE_GRENSKINS			1
#define STORE_MODULE_GRENTRAILS			1
#define STORE_MODULE_HATS				1
#define STORE_MODULE_HEALTH				1
#define STORE_MODULE_HELP				1
#define STORE_MODULE_INVISIBILITY		1
#define STORE_MODULE_JETPACK			1
#define STORE_MODULE_JIHAD				1
#define STORE_MODULE_JUMP_EFFECT		1
#define STORE_MODULE_KNIFE				1
#define STORE_MODULE_LASERSIGHT			1
#define STORE_MODULE_LINK				1
#define STORE_MODULE_PAINTBALL			1
#define STORE_MODULE_PETS				1
#define STORE_MODULE_PLAYERSKINS		1
#define STORE_MODULE_RAINBOW			1
#define STORE_MODULE_RESPAWN			1
#define STORE_MODULE_ROLL				1
#define STORE_MODULE_SOUNDS				1
#define STORE_MODULE_SPEED				1
#define STORE_MODULE_SPRAYS				1
#define STORE_MODULE_TRACERS			1
#define STORE_MODULE_TRAILS				1
#define STORE_MODULE_WATERGUN			1
#define STORE_MODULE_WEAPONCOLORS		1
#define STORE_MODULE_WEAPONS			1

#define STORE_MODULE_GAMBLE_BLACKJACK	1
#define STORE_MODULE_GAMBLE_COINFLIP	1
#define STORE_MODULE_GAMBLE_CRASH		1
#define STORE_MODULE_GAMBLE_CROWNS		1
#define STORE_MODULE_GAMBLE_DICE		1
#define STORE_MODULE_GAMBLE_HIGHORLOW	1
#define STORE_MODULE_GAMBLE_JACKPOT		1
#define STORE_MODULE_GAMBLE_ROULETTE	1
#define STORE_MODULE_GAMBLE_TEAMBET		1

#define STORE_MODULE_MISC_BALL			1
#define STORE_MODULE_MISC_DOSH			1
#define STORE_MODULE_MISC_EARNINGS		1
#define STORE_MODULE_MISC_GIVEAWAY		1
#define STORE_MODULE_MISC_LOOTBOX		1
#define STORE_MODULE_MISC_MATH			1
#define STORE_MODULE_MISC_PROMO			1
#define STORE_MODULE_MISC_TOPLISTS		1
#define STORE_MODULE_MISC_VOUCHER		1

#define STORE_MODULE_TRADE			1

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

int hTime;

char g_sChatPrefix[128];
#if defined _clientmod_included
char g_sChatPrefix_CM[128];
#endif

char g_sCreditsName[64] = "битс";

char g_sMenuItem[64];
char g_sMenuExit[64];

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
// Enable/disable: #define STORE_MODULE_* 1/0 above.
// Each module checks its define inside; disabled = empty stubs.
//////////////////////////////
#include "store/modules.sp"

//////////////////////////////
//		PLUGIN DEFINITION	//
//////////////////////////////

public Plugin myinfo = 
{
	name = "Store - The Resurrection with preview system",
	author = "Zephyrus, nuclear silo, AiDN, anonim396",
	description = "A completely new Store system with preview rewritten (v34)",
	version = "7.2.6",
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
	
	FixWarnings();
	
	LoadTranslations("store.phrases");
	LoadTranslations("common.phrases");
	
	g_iPackageHandler = Store_RegisterHandler("package", "", _, _, _, _, _);

	Modules_OnPluginStart();

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
	Modules_OnAllPluginsLoaded();
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
	Modules_OnMapStart();
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
	Modules_OnMapEnd();
}

public void OnConfigsExecuted()
{
	Modules_OnConfigsExecutedPre();
	Modules_OnConfigsExecuted();
	Store_Cvars_OnConfigsExecuted();
	Store_Forward_OnConfigsExecuted();
	Store_DB_ConfigsExecuted_ConnectDatabase();
}

public void OnGameFrame()
{
	Modules_OnGameFrame();
}

public void OnEntityCreated(int entity, const char[] classname)
{
	Modules_OnEntityCreated(entity, classname);
}

//////////////////////////////
//		CLIENT FORWARDS		//
//////////////////////////////
public void OnClientCookiesCached(int client)
{
	Modules_OnClientCookiesCached(client);
}

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
	
	Modules_OnClientConnected(client);
}

public void OnClientAuthorized(int client, const char[] auth)
{
	Modules_OnClientAuthorized(client, auth);
}

public void OnClientPostAdminCheck(int client)
{
	if(IsFakeClient(client))
		return;
	Store_LoadClientInventory(client);
	Modules_OnClientPostAdminCheck(client);
}

public void OnClientPutInServer(int client)
{
	if(IsFakeClient(client))
		return;
	Modules_OnClientPutInServer(client);
}

public void OnClientDisconnect(int client)
{
	if(IsFakeClient(client))
		return;
	Modules_OnClientDisconnect(client);
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
	Modules_OnPlayerRunCmd(client, buttons, tickcount);
	return Plugin_Continue;
}

public void PlayerSpawn(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(IsValidClient(client))
		Modules_PlayerSpawn(client);
}

public void PlayerDeath(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(IsValidClient(client))
		Modules_PlayerDeath(client);
}

public void PlayerTeam(Handle hEvent, char[] sEvName, bool bDontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(hEvent, "userid"));
	
	if(IsValidClient(client))
		Modules_PlayerTeam(client);
}

void FixWarnings()
{
	if(g_hTimerPreview[0] || g_iPreviewEntity[0] || g_sCreditsName[0])
	{
		// If anyone can make it more beautiful, please do.
	}
}