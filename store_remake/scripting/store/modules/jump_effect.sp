#if STORE_MODULE_JUMP_EFFECT

bool g_bJumpEffectClient[MAXPLAYERS+1];
int g_iJumpBeamSprite;
int g_iJumpHaloSprite;
float g_fJumpStart, g_fJumpEnd, g_fJumpLife, g_fJumpWidth, g_fJumpAmplitude[3], g_fJumpHeight;
ConVar g_cvarJumpTeamOnly;
Handle g_hJumpEffectPreviewTimer[MAXPLAYERS+1];
Handle g_hJumpEffectPreviewStopTimer[MAXPLAYERS+1];
float g_fJumpEffectPreviewPos[MAXPLAYERS+1][3];
#define JUMP_EFFECT_PREVIEW_DURATION 45.0
#define JUMP_EFFECT_PREVIEW_DISTANCE 120.0
#define JUMP_EFFECT_PREVIEW_INTERVAL 2.5

void JumpEffect_OnPluginStart()
{
	Store_RegisterHandler("jump_effect", "jump_effect", JumpEffect_OnMapStart, INVALID_FUNCTION, JumpEffect_Config, JumpEffect_Equip, JumpEffect_Remove, true);
	HookEvent("player_jump", JumpEffect_OnPlayerJump);
	g_cvarJumpTeamOnly = CreateConVar("sm_store_jump_effect_team_only", "1", "1 = only teammates see effect, 0 = everyone", _, true, 0.0, true, 1.0);
	ConVar cvar = CreateConVar("sm_store_jump_effect_start", "1.0", "Beam ring start radius");
	cvar.AddChangeHook(JumpEffect_CvarChanged);
	g_fJumpStart = cvar.FloatValue;
	cvar = CreateConVar("sm_store_jump_effect_end", "80.0", "Beam ring end radius");
	cvar.AddChangeHook(JumpEffect_CvarChanged);
	g_fJumpEnd = cvar.FloatValue;
	cvar = CreateConVar("sm_store_jump_effect_life", "0.8", "Effect lifetime");
	cvar.AddChangeHook(JumpEffect_CvarChanged);
	g_fJumpLife = cvar.FloatValue;
	cvar = CreateConVar("sm_store_jump_effect_width", "8.0", "Beam width");
	cvar.AddChangeHook(JumpEffect_CvarChanged);
	g_fJumpWidth = cvar.FloatValue;
	cvar = CreateConVar("sm_store_jump_effect_amplitude1", "4.0", "Amplitude 1");
	cvar.AddChangeHook(JumpEffect_CvarChanged);
	g_fJumpAmplitude[0] = cvar.FloatValue;
	cvar = CreateConVar("sm_store_jump_effect_amplitude2", "20.0", "Amplitude 2");
	cvar.AddChangeHook(JumpEffect_CvarChanged);
	g_fJumpAmplitude[1] = cvar.FloatValue;
	cvar = CreateConVar("sm_store_jump_effect_amplitude3", "8.0", "Amplitude 3");
	cvar.AddChangeHook(JumpEffect_CvarChanged);
	g_fJumpAmplitude[2] = cvar.FloatValue;
	cvar = CreateConVar("sm_store_jump_effect_height", "10.0", "Effect height offset");
	cvar.AddChangeHook(JumpEffect_CvarChanged);
	g_fJumpHeight = cvar.FloatValue;
	Store_BeginModuleConfig("sourcemod/store", "store_jump_effect");
	STORE_CFG("sm_store_jump_effect_team_only", "1");
	STORE_CFG("sm_store_jump_effect_start", "1.0");
	STORE_CFG("sm_store_jump_effect_end", "80.0");
	STORE_CFG("sm_store_jump_effect_life", "0.8");
	STORE_CFG("sm_store_jump_effect_width", "8.0");
	STORE_CFG("sm_store_jump_effect_amplitude1", "4.0");
	STORE_CFG("sm_store_jump_effect_amplitude2", "20.0");
	STORE_CFG("sm_store_jump_effect_amplitude3", "8.0");
	STORE_CFG("sm_store_jump_effect_height", "10.0");
	Store_EndModuleConfig("sourcemod/store", "store_jump_effect");
}

public void JumpEffect_CvarChanged(ConVar cvar, const char[] oldVal, const char[] newVal)
{
	g_fJumpStart = FindConVar("sm_store_jump_effect_start").FloatValue;
	g_fJumpEnd = FindConVar("sm_store_jump_effect_end").FloatValue;
	g_fJumpLife = FindConVar("sm_store_jump_effect_life").FloatValue;
	g_fJumpWidth = FindConVar("sm_store_jump_effect_width").FloatValue;
	g_fJumpAmplitude[0] = FindConVar("sm_store_jump_effect_amplitude1").FloatValue;
	g_fJumpAmplitude[1] = FindConVar("sm_store_jump_effect_amplitude2").FloatValue;
	g_fJumpAmplitude[2] = FindConVar("sm_store_jump_effect_amplitude3").FloatValue;
	g_fJumpHeight = FindConVar("sm_store_jump_effect_height").FloatValue;
}

public void JumpEffect_OnMapStart()
{
	g_iJumpBeamSprite = PrecacheModel("materials/sprites/laserbeam.vmt");
	g_iJumpHaloSprite = PrecacheModel("materials/sprites/halo.vmt");
}

public bool JumpEffect_Config(KeyValues &kv, int itemid)
{
	return true;
}

public int JumpEffect_Equip(int client, int id)
{
	g_bJumpEffectClient[client] = true;
	return 0;
}

public int JumpEffect_Remove(int client)
{
	g_bJumpEffectClient[client] = false;
	return 0;
}

public Action JumpEffect_OnPlayerJump(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client || !IsClientInGame(client) || !g_bJumpEffectClient[client])
		return Plugin_Continue;
	float pos[3];
	GetClientAbsOrigin(client, pos);
	pos[2] += g_fJumpHeight;
	int ver = GetRandomInt(0, 2);
	int clr[4];
	clr[0] = GetRandomInt(1, 255);
	clr[1] = GetRandomInt(1, 255);
	clr[2] = GetRandomInt(1, 255);
	clr[3] = 255;
	int list[MAXPLAYERS]; int n;
	int team = GetClientTeam(client);
	for (int i = 1; i <= MaxClients; i++)
		if (IsClientInGame(i) && !IsFakeClient(i) && (!g_cvarJumpTeamOnly.BoolValue || GetClientTeam(i) == team))
			list[n++] = i;
	if (n == 0) return Plugin_Continue;
	TE_SetupBeamRingPoint(pos, g_fJumpStart, g_fJumpEnd, g_iJumpBeamSprite, g_iJumpHaloSprite, 0, 0, g_fJumpLife, g_fJumpWidth, g_fJumpAmplitude[ver], clr, 50, 0);
	TE_Send(list, n);
	return Plugin_Continue;
}

void JumpEffect_OnClientDisconnect(int client)
{
	g_bJumpEffectClient[client] = false;
	if (g_hJumpEffectPreviewTimer[client] != null)
	{
		delete g_hJumpEffectPreviewTimer[client];
		g_hJumpEffectPreviewTimer[client] = null;
	}
	if (g_hJumpEffectPreviewStopTimer[client] != null)
	{
		delete g_hJumpEffectPreviewStopTimer[client];
		g_hJumpEffectPreviewStopTimer[client] = null;
	}
}

/** Draws the ring at a fixed position for one client (preview: cyclic, in front of player, does not follow). */
static void JumpEffect_ShowPreviewRingAt(int client, const float pos[3])
{
	if (!IsClientInGame(client))
		return;
	int ver = GetRandomInt(0, 2);
	int clr[4];
	clr[0] = GetRandomInt(1, 255);
	clr[1] = GetRandomInt(1, 255);
	clr[2] = GetRandomInt(1, 255);
	clr[3] = 255;
	int list[1];
	list[0] = client;
	TE_SetupBeamRingPoint(pos, g_fJumpStart, g_fJumpEnd, g_iJumpBeamSprite, g_iJumpHaloSprite, 0, 0, g_fJumpLife, g_fJumpWidth, g_fJumpAmplitude[ver], clr, 50, 0);
	TE_Send(list, 1);
}

public Action JumpEffect_Timer_PreviewRepeat(Handle timer, int client)
{
	if (client < 1 || client > MaxClients || g_hJumpEffectPreviewTimer[client] != timer)
		return Plugin_Stop;
	if (!IsClientInGame(client))
	{
		g_hJumpEffectPreviewTimer[client] = null;
		return Plugin_Stop;
	}
	JumpEffect_ShowPreviewRingAt(client, g_fJumpEffectPreviewPos[client]);
	return Plugin_Continue;
}

public Action JumpEffect_Timer_StopPreview(Handle timer, int client)
{
	g_hJumpEffectPreviewStopTimer[client] = null;
	if (g_hJumpEffectPreviewTimer[client] != null)
	{
		delete g_hJumpEffectPreviewTimer[client];
		g_hJumpEffectPreviewTimer[client] = null;
	}
	return Plugin_Stop;
}

public void JumpEffect_OnPreviewItem(int client, const char[] type, int index)
{
	g_hJumpEffectPreviewTimer[client] = null;
	if (g_hJumpEffectPreviewStopTimer[client] != null)
	{
		delete g_hJumpEffectPreviewStopTimer[client];
		g_hJumpEffectPreviewStopTimer[client] = null;
	}
	if (!IsPlayerAlive(client))
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Spawn Preview CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix, "Spawn Preview");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix, "Spawn Preview");
		#endif
		return;
	}
	float eyePos[3], eyeAng[3], fwd[3];
	GetClientEyePosition(client, eyePos);
	GetClientEyeAngles(client, eyeAng);
	GetAngleVectors(eyeAng, fwd, NULL_VECTOR, NULL_VECTOR);
	g_fJumpEffectPreviewPos[client][0] = eyePos[0] + fwd[0] * JUMP_EFFECT_PREVIEW_DISTANCE;
	g_fJumpEffectPreviewPos[client][1] = eyePos[1] + fwd[1] * JUMP_EFFECT_PREVIEW_DISTANCE;
	g_fJumpEffectPreviewPos[client][2] = eyePos[2] + fwd[2] * JUMP_EFFECT_PREVIEW_DISTANCE;
	JumpEffect_ShowPreviewRingAt(client, g_fJumpEffectPreviewPos[client]);
	g_hJumpEffectPreviewTimer[client] = CreateTimer(JUMP_EFFECT_PREVIEW_INTERVAL, JumpEffect_Timer_PreviewRepeat, client, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
	g_hJumpEffectPreviewStopTimer[client] = CreateTimer(JUMP_EFFECT_PREVIEW_DURATION, JumpEffect_Timer_StopPreview, client, TIMER_FLAG_NO_MAPCHANGE);
	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Spawn Preview CM");
		C_PrintToChat(client, "%s %t", g_sChatPrefix, "Spawn Preview");
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix, "Spawn Preview");
	#endif
}

#else

void JumpEffect_OnPluginStart() {}
void JumpEffect_OnClientDisconnect(int client) 
{
	#pragma unused client
}
public void JumpEffect_OnMapStart() {}

#endif
