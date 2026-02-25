//////////////////////////////
//		MODULES LIST		//
// Enable/disable in store.sp: #define STORE_MODULE_* 1/0
// Each module checks its define internally; disabled = empty stubs.
//////////////////////////////

#include "store/modules/admin.sp"
#include "store/modules/attributes.sp"
#include "store/modules/betting.sp"
#include "store/modules/store_gamble_blackjack.sp"
#include "store/modules/store_gamble_coinflip.sp"
#include "store/modules/bunnyhop.sp"
#include "store/modules/commands.sp"
#include "store/modules/cpsupport_old.sp"
#include "store/modules/doors.sp"
#include "store/modules/gifts.sp"
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
#include "store/modules/store_misc_toplists.sp"
#include "store/modules/sprays.sp"
#include "store/modules/trails.sp"

#include "store/modules/tracers.sp"
#include "store/modules/watergun.sp"
#include "store/modules/weaponcolors.sp"
#include "store/modules/weapons.sp"
#include "store/modules/store_gamble_crash.sp"
#include "store/modules/store_gamble_crowns.sp"
#include "store/modules/store_gamble_dice.sp"
#include "store/modules/store_gamble_highorlow.sp"
#include "store/modules/store_gamble_jackpot.sp"
#include "store/modules/store_gamble_roulette.sp"
#include "store/modules/store_gamble_teambet.sp"
#include "store/modules/store_misc_ball.sp"
#include "store/modules/credits_multiplier.sp"
#include "store/modules/store_misc_dosh.sp"

#include "store/modules/jump_effect.sp"
#include "store/modules/rainbow.sp"
#include "store/modules/roll.sp"
#include "store/modules/store_misc_earnings.sp"
#include "store/modules/store_misc_giveaway.sp"
#include "store/modules/store_misc_lootbox.sp"
#include "store/modules/store_misc_math.sp"
#include "store/modules/store_misc_voucher.sp"
#include "store/modules/store_trade.sp"

//////////////////////////////
//		MODULES DISPATCH		//
//////////////////////////////

void Modules_OnPluginStart()
{
	AdminGroup_OnPluginStart();
	Attributes_OnPluginStart();
	Betting_OnPluginStart();
	Blackjack_OnPluginStart();
	Coinflip_OnPluginStart();
	Bunnyhop_OnPluginStart();
	Commands_OnPluginStart();
	CPSupport_OnPluginStart();
	Doors_OnPluginStart();
	Gifts_OnPluginStart();
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
	TopLists_OnPluginStart();
	Sprays_OnPluginStart();
	Trails_OnPluginStart();
	Tracers_OnPluginStart();
	Watergun_OnPluginStart();
	WeaponColors_OnPluginStart();
	Weapons_OnPluginStart();
	Crash_OnPluginStart();
	Crowns_OnPluginStart();
	Dice_OnPluginStart();
	HighOrLow_OnPluginStart();
	Jackpot_OnPluginStart();
	Roulette_OnPluginStart();
	TeamBet_OnPluginStart();
	Ball_OnPluginStart();
	CreditsMultiplier_OnPluginStart();
	Dosh_OnPluginStart();
	JumpEffect_OnPluginStart();
	Rainbow_OnPluginStart();
	Roll_OnPluginStart();
	Earnings_OnPluginStart();
	Giveaway_OnPluginStart();
	Lootbox_OnPluginStart();
	Math_OnPluginStart();
	Voucher_OnPluginStart();
	Trade_OnPluginStart();
}

void Modules_OnAllPluginsLoaded()
{
	Voucher_OnAllPluginsLoaded();
}

void Modules_OnMapStart()
{
	TopLists_OnMapStart();
	Crash_OnMapStart();
	Jackpot_OnMapStart();
	Math_OnMapStart();
	Dosh_OnMapStart();
	Earnings_OnMapStart();
	Ball_OnMapStart();
	JumpEffect_OnMapStart();
	Roll_OnMapStart();
}

void Modules_OnMapEnd()
{
	Jackpot_OnMapEnd();
	Lootbox_OnMapEnd();
	Roll_OnMapEnd();
}

public void Modules_OnPlayerReset(int client)
{
#if STORE_MODULE_MISC_TOPLISTS
	TopLists_OnMapStart();
#endif
}

void Modules_OnConfigsExecutedPre()
{
	Jetpack_OnConfigsExecuted();
	Jihad_OnConfigsExecuted();
}

void Modules_OnConfigsExecuted()
{
	Ball_OnConfigsExecuted();
}

void Modules_OnConfigExecuted()
{
	TopLists_OnConfigExecuted();
	Lootbox_OnConfigExecuted();
	Math_OnConfigExecuted();
	Giveaway_OnConfigExecuted();
	Earnings_OnConfigExecuted();
	Voucher_OnConfigExecuted();
}

#if defined _clientmod_included
void Modules_OnConfigExecutedCM()
{
}
#endif

void Modules_OnGameFrame()
{
	Trails_OnGameFrame();
	Rainbow_OnGameFrame();
}

void Modules_OnEntityCreated(int entity, const char[] classname)
{
	GrenadeSkins_OnEntityCreated(entity, classname);
	GrenadeTrails_OnEntityCreated(entity, classname);
}

void Modules_OnClientCookiesCached(int client)
{
	Trails_OnClientCookiesCached(client);
	Sounds_OnClientCookiesCached(client);
	Crash_OnClientCookiesCached(client);
	Ball_OnClientCookiesCached(client);
	Earnings_OnClientCookiesCached(client);
}

void Modules_OnClientConnected(int client)
{
	Jetpack_OnClientConnected(client);
	Pets_OnClientConnected(client);
	Sprays_OnClientConnected(client);
	Earnings_OnClientConnected(client);
	Trade_OnClientConnected(client);
}

void Modules_OnClientAuthorized(int client, const char[] auth)
{
	Coinflip_OnClientAuthorized(client, auth);
	Crowns_OnClientAuthorized(client, auth);
	Dice_OnClientAuthorized(client, auth);
	Roulette_OnClientAuthorized(client, auth);
}

void Modules_OnClientPostAdminCheck(int client)
{
	Sounds_OnClientPostAdminCheck(client);
	Ball_OnClientPostAdminCheck(client);
	HighOrLow_OnClientPostAdminCheck(client);
	Lootbox_OnClientPostAdminCheck(client);
	Earnings_OnClientPostAdminCheck(client);
}

void Modules_OnClientPutInServer(int client)
{
	Knives_OnClientPutInServer(client);
}

void Modules_OnClientDisconnect(int client)
{
	Betting_OnClientDisconnect(client);
	Blackjack_OnClientDisconnect(client);
	Coinflip_OnClientDisconnect(client);
	Dice_OnClientDisconnect(client);
	Roulette_OnClientDisconnect(client);
	TeamBet_OnClientDisconnect(client);
	Lootbox_OnClientDisconnect(client);
	Pets_OnClientDisconnect(client);
	Sounds_OnClientDisconnect(client);
	Trails_OnClientDisconnect(client);
	Crash_OnClientDisconnect(client);
	Crowns_OnClientDisconnect(client);
	Ball_OnClientDisconnect(client);
	Earnings_OnClientDisconnect(client);
	Trade_OnClientDisconnect(client);
	Glow_OnClientDisconnect(client);
	GrenadeTrails_OnClientDisconnect(client);
	GrenadeSkins_OnClientDisconnect(client);
	JumpEffect_OnClientDisconnect(client);
	LaserSight_OnClientDisconnect(client);
	Rainbow_OnClientDisconnect(client);
}

void Modules_OnPlayerRunCmd(int client, int &buttons, int tickcount)
{
	Jetpack_OnPlayerRunCmd(client, buttons);
	LaserSight_OnPlayerRunCmd(client);
	Pets_OnPlayerRunCmd(client, tickcount);
	Sprays_OnPlayerRunCmd(client, buttons);
	Bunnyhop_OnPlayerRunCmd(client, buttons);
}

void Modules_PlayerSpawn(int client)
{
	Glow_PlayerSpawn(client);
	Godmode_OnPlayerSpawn(client);
	Health_OnPlayerSpawn(client);
	Respawn_OnPlayerSpawn(client);
	Ball_OnPlayerSpawn(client);
}

void Modules_PlayerDeath(int client)
{
	Glow_PlayerDeath(client);
}

void Modules_PlayerTeam(int client)
{
	Glow_PlayerTeam(client);
}
