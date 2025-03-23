#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

#if defined REQUIRE_PLUGIN
#undef REQUIRE_PLUGIN
#endif
#include <hidetrails>

enum struct Trail
{
    char szMaterial[PLATFORM_MAX_PATH];
    char szWidth[16];
    char szColor[16];
    float fWidth;
    int iColor[4];
    int iSlot;
    int iCacheID;
}

ArrayList g_eTrails;

int g_iTrails = 0;
int g_iClientTrails[MAXPLAYERS+1][STORE_MAX_SLOTS];

bool g_bSpawnTrails[MAXPLAYERS+1];

float g_fClientCounters[MAXPLAYERS+1];
float g_fLastPosition[MAXPLAYERS+1][3];

ConVar g_cvarPadding;
ConVar g_cvarMaxColumns;
ConVar g_cvarTrailLife;

int g_iTrailOwners[2048] = {-1};

#if defined STANDALONE_BUILD
public void OnPluginStart()
#else
public void Trails_OnPluginStart()
#endif
{
    g_cvarPadding = CreateConVar("sm_store_trails_padding", "30.0", "Space between two trails", FCVAR_NONE, true, 0.0);
    g_cvarMaxColumns = CreateConVar("sm_store_trails_columns", "3", "Number of columns before starting to increase altitude", FCVAR_NONE, true, 1.0);
    g_cvarTrailLife = CreateConVar("sm_store_trails_life", "1.0", "Life of a trail in seconds", FCVAR_NONE, true, 0.0);
    
    Store_RegisterHandler("trail", "material", Trails_OnMapStart, Trails_Reset, Trails_Config, Trails_Equip, Trails_Remove, true);
    
    HookEvent("player_spawn", Trails_PlayerSpawn);
    HookEvent("player_death", Trails_PlayerDeath);
    
    g_eTrails = new ArrayList(sizeof(Trail));
}

public void Trails_OnMapStart()
{
    for (int a = 0; a <= MaxClients; ++a)
        for (int b = 0; b < STORE_MAX_SLOTS; ++b)
            g_iClientTrails[a][b] = 0;

    for (int i = 0; i < g_iTrails; ++i)
    {
        Trail trail;
        g_eTrails.GetArray(i, trail);
        trail.iCacheID = PrecacheModel(trail.szMaterial, true);
        g_eTrails.SetArray(i, trail);
        AddFileToDownloadsTable(trail.szMaterial);
    }
}

public void Trails_Reset()
{
    g_iTrails = 0;
    g_eTrails.Clear();
}

public bool Trails_Config(KeyValues kv, int itemid)
{
    Trail trail;
    kv.GetString("material", trail.szMaterial, PLATFORM_MAX_PATH);
    kv.GetString("width", trail.szWidth, 16, "10.0");
    trail.fWidth = kv.GetFloat("width", 10.0);
    kv.GetString("color", trail.szColor, 16, "255 255 255");
    kv.GetColor("color", trail.iColor[0], trail.iColor[1], trail.iColor[2], trail.iColor[3]);
    trail.iSlot = kv.GetNum("slot");
    
    if (FileExists(trail.szMaterial, true))
    {
        g_eTrails.PushArray(trail);
        g_iTrails++;
        return true;
    }
    
    return false;
}

public int Trails_Equip(int client, int id)
{
    if (!IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) < 2)
        return -1;
    
    CreateTimer(0.0, Timer_CreateTrails, GetClientUserId(client));
    return g_eTrails.Get(Store_GetDataIndex(id), Trail::iSlot);
}

public int Trails_Remove(int client, int id)
{
    CreateTimer(0.0, Timer_CreateTrails, GetClientUserId(client));
    return g_eTrails.Get(Store_GetDataIndex(id), Trail::iSlot);
}

public Action Timer_CreateTrails(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (!client || !IsClientInGame(client))
        return Plugin_Stop;
    
    for (int i = 0; i < STORE_MAX_SLOTS; ++i)
    {
        RemoveTrail(client, i);
        CreateTrail(client, -1, i);
    }
    
    return Plugin_Stop;
}

public Action Trails_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsClientInGame(client) || !IsPlayerAlive(client) || GetClientTeam(client) < 2)
        return Plugin_Continue;
    
    CreateTimer(0.0, Timer_CreateTrails, GetClientUserId(client));
    
    return Plugin_Continue;
}

public Action Trails_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    if (!IsPlayerAlive(client))
        for (int i = 0; i < STORE_MAX_SLOTS; ++i)
            RemoveTrail(client, i);
    
    return Plugin_Continue;
}

void CreateTrail(int client, int itemid = -1, int slot = 0)
{
    int m_iEquipped = (itemid == -1 ? Store_GetEquippedItem(client, "trail", slot) : itemid);
    if (m_iEquipped >= 0)
    {
        int m_iData = Store_GetDataIndex(m_iEquipped);
        Trail trail;
        g_eTrails.GetArray(m_iData, trail);
        
        int m_aEquipped[STORE_MAX_SLOTS] = {-1, ...};
        int m_iNumEquipped = 0;
        int m_iCurrent = 0;
        
        for (int i = 0; i < STORE_MAX_SLOTS; ++i)
        {
            m_aEquipped[m_iNumEquipped] = Store_GetEquippedItem(client, "trail", i);
            if (m_aEquipped[m_iNumEquipped] >= 0)
            {
                if (i == trail.iSlot)
                    m_iCurrent = m_iNumEquipped;
                m_iNumEquipped++;
            }
        }
        
        int m_iEnt = CreateEntityByName("env_spritetrail");
        SetEntPropFloat(m_iEnt, Prop_Send, "m_flTextureRes", 0.05);

        DispatchKeyValue(m_iEnt, "renderamt", "255");
        DispatchKeyValue(m_iEnt, "rendercolor", trail.szColor);
        DispatchKeyValue(m_iEnt, "lifetime", g_cvarTrailLife.FloatValue);
        DispatchKeyValue(m_iEnt, "rendermode", "5");
        DispatchKeyValue(m_iEnt, "spritename", trail.szMaterial);
        DispatchKeyValue(m_iEnt, "startwidth", trail.szWidth);
        DispatchKeyValue(m_iEnt, "endwidth", trail.szWidth);
        DispatchSpawn(m_iEnt);
        
        AttachTrail(m_iEnt, client, m_iCurrent, m_iNumEquipped);
        
        g_iClientTrails[client][trail.iSlot] = m_iEnt;
        SDKHook(m_iEnt, SDKHook_SetTransmit, Hook_TrailSetTransmit);
        
        g_iTrailOwners[m_iEnt] = client;
    }
}

void RemoveTrail(int client, int slot)
{
    if (g_iClientTrails[client][slot] != 0 && IsValidEntity(g_iClientTrails[client][slot]))
    {
        g_iTrailOwners[g_iClientTrails[client][slot]] = -1;

        char m_szClassname[64];
        GetEntityClassname(g_iClientTrails[client][slot], m_szClassname, sizeof(m_szClassname));
        if (StrEqual(m_szClassname, "env_spritetrail"))
        {
            SDKUnhook(g_iClientTrails[client][slot], SDKHook_SetTransmit, Hook_TrailSetTransmit);
            AcceptEntityInput(g_iClientTrails[client][slot], "Kill");
        }
    }
    g_iClientTrails[client][slot] = 0;
}

void AttachTrail(int ent, int client, int current, int num)
{
    float m_fOrigin[3], m_fAngle[3];
    float m_fTemp[3] = {0.0, 90.0, 0.0};
    GetEntPropVector(client, Prop_Data, "m_angAbsRotation", m_fAngle);
    SetEntPropVector(client, Prop_Data, "m_angAbsRotation", m_fTemp);
    float m_fX = (g_cvarPadding.FloatValue * ((num - 1) % g_cvarMaxColumns.IntValue)) / 2 - (g_cvarPadding.FloatValue * (current % g_cvarMaxColumns.IntValue));
    float m_fPosition[3];
    m_fPosition[0] = m_fX;
    m_fPosition[1] = 0.0;
    m_fPosition[2] = 5.0 + (current / g_cvarMaxColumns.IntValue) * g_cvarPadding.FloatValue;
    GetClientAbsOrigin(client, m_fOrigin);
    AddVectors(m_fOrigin, m_fPosition, m_fOrigin);
    TeleportEntity(ent, m_fOrigin, m_fTemp, NULL_VECTOR);
    SetVariantString("!activator");
    AcceptEntityInput(ent, "SetParent", client, ent);
    SetEntPropVector(client, Prop_Data, "m_angAbsRotation", m_fAngle);
}

#if defined STANDALONE_BUILD
public void OnGameFrame()
#else
public void Trails_OnGameFrame()
#endif
{
    if (GetGameTickCount() % 6 != 0)
        return;

    float m_fTime = GetEngineTime();
    float m_fPosition[3];
    for (int i = 1; i <= MaxClients; ++i)
    {
        if (!IsClientInGame(i) || !IsPlayerAlive(i))
            continue;

        GetClientAbsOrigin(i, m_fPosition);
        if (GetVectorDistance(g_fLastPosition[i], m_fPosition) <= 5.0)
        {
            if (!g_bSpawnTrails[i])
                if (m_fTime - g_fClientCounters[i] >= g_cvarTrailLife.FloatValue / 2)
                    g_bSpawnTrails[i] = true;
        }
        else
        {
            if (g_bSpawnTrails[i])
            {
                g_bSpawnTrails[i] = false;
                TE_Start("KillPlayerAttachments");
                TE_WriteNum("m_nPlayer", i);
                TE_SendToAll();
                for (int a = 0; a < STORE_MAX_SLOTS; ++a)
                    CreateTrail(i, -1, a);
            }
            else
                g_fClientCounters[i] = m_fTime;
            g_fLastPosition[i] = m_fPosition;
        }
    }
}

public Action Hook_TrailSetTransmit(int ent, int client)
{
    int Hide = ShouldHideTrail(client, ent);
    if (Hide)
    {
        if (Hide == 2)
            return Plugin_Handled;
        else if (Hide == 1)
        {
            for (int i = 0; i < STORE_MAX_SLOTS; ++i)
                if (g_iClientTrails[client][i] == ent)
                    return Plugin_Continue;
            return Plugin_Handled;
        }
    }
    
    return Plugin_Continue;
}

int ShouldHideTrail(int client, int ent)
{
    static int Available = -1;
    if (Available == -1)
        Available = GetFeatureStatus(FeatureType_Native, "HideTrails_ShouldHide") == FeatureStatus_Available ? 1 : 0;

    if (Available == 1)
    {
        return HideTrails_ShouldHide(client);
    }
    return 0;
}