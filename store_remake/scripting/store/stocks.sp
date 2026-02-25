#if defined _store_stocks_included
	#endinput
#endif
#define _store_stocks_included

#define STRING(%1) %1, sizeof(%1)
#define LoopConnectedClients(%1) for(int %1=1;%1<=MaxClients;++%1) if(IsClientConnected(%1))
#define LoopIngameClients(%1) for(int %1=1;%1<=MaxClients;++%1) if(IsClientInGame(%1))
#define LoopIngamePlayers(%1) for(int %1=1;%1<=MaxClients;++%1) if(IsClientInGame(%1) && !IsFakeClient(%1))
#define LoopAuthorizedPlayers(%1) for(int %1=1;%1<=MaxClients;++%1) if(IsClientConnected(%1) && IsClientAuthorized(%1))
#define LoopAlivePlayers(%1) for(int %1=1;%1<=MaxClients;++%1) if(IsClientInGame(%1) && IsPlayerAlive(%1))

#define CVAR_LENGTH 128
#define MAX_CVARS 128

enum VAR_TYPE
{
	TYPE_INT = 0,
	TYPE_FLOAT,
	TYPE_STRING,
	TYPE_FLAG
}

enum struct CVAR_CACHE
{
	Handle hCvar;
	any eType;
	any aCache;
	char sCache[CVAR_LENGTH];
	Function fnCallback;
}

CVAR_CACHE g_eCvars[MAX_CVARS];
int g_iCvars = 0;

stock int HookConVar(char[] name, any type, Function callback=INVALID_FUNCTION)
{
	Handle cvar = FindConVar(name);
	if(cvar == INVALID_HANDLE)
		return -1;
	HookConVarChange(cvar, GlobalConVarChanged);
	g_eCvars[g_iCvars].hCvar = cvar;
	g_eCvars[g_iCvars].eType = type;
	g_eCvars[g_iCvars].fnCallback = callback;
	CacheCvarValue(g_iCvars);
	return g_iCvars++;
}

stock int RegisterConVar(char[] name, char[] value, char[] description, any type, Function callback=INVALID_FUNCTION, int flags=0, bool hasMin=false, float min=0.0, bool hasMax=false, float max=0.0)
{
	Handle cvar = CreateConVar(name, value, description, flags, hasMin, min, hasMax, max);
	HookConVarChange(cvar, GlobalConVarChanged);
	g_eCvars[g_iCvars].hCvar = cvar;
	g_eCvars[g_iCvars].eType = type;
	g_eCvars[g_iCvars].fnCallback = callback;
	CacheCvarValue(g_iCvars);
	return g_iCvars++;
}

public void GlobalConVarChanged(Handle convar, const char[] oldValue, const char[] newValue)
{
	for(int i=0;i<g_iCvars;++i)
		if(g_eCvars[i].hCvar==convar)
		{
			CacheCvarValue(i);
			if(g_eCvars[i].fnCallback!=INVALID_FUNCTION)
			{
				Call_StartFunction(INVALID_HANDLE, g_eCvars[i].fnCallback);
				Call_PushCell(i);
				Call_Finish();
			}
			return;
		}
}

public void CacheCvarValue(int index)
{
	GetConVarString(g_eCvars[index].hCvar, g_eCvars[index].sCache, CVAR_LENGTH);
	if(g_eCvars[index].eType==TYPE_INT)
		g_eCvars[index].aCache = GetConVarInt(g_eCvars[index].hCvar);
	else if(g_eCvars[index].eType==TYPE_FLOAT)
		g_eCvars[index].aCache = GetConVarFloat(g_eCvars[index].hCvar);
	else if(g_eCvars[index].eType==TYPE_FLAG)
		g_eCvars[index].aCache = ReadFlagString(g_eCvars[index].sCache);
}

stock void ClearTimer(Handle &timer)
{
	if(timer != null)
	{
		KillTimer(timer);
		timer = null;
	}
}

stock bool GetClientPrivilege(int client, int flag, int flags=-1)
{
	if(flags==-1)
		flags = GetUserFlagBits(client);
	if(flag == 0 || (flags & flag) || (flags & ADMFLAG_ROOT))
		return true;
	return false;
}

public bool TraceRayDontHitSelf(int entity, int mask, any data)
{
	return entity != data;
}

public bool TraceRayDontHitPlayers(int entity, int mask, any data)
{
	return (entity <= 0 || entity > MaxClients);
}

stock void GetClientSightEnd(int client, float out[3])
{
	float m_fEyes[3], m_fAngles[3];
	GetClientEyePosition(client, m_fEyes);
	GetClientEyeAngles(client, m_fAngles);
	TR_TraceRayFilter(m_fEyes, m_fAngles, MASK_PLAYERSOLID, RayType_Infinite, TraceRayDontHitPlayers);
	if(TR_DidHit())
		TR_GetEndPosition(out);
}

stock int GetClientBySteamID(const char[] steamid)
{
	char authid[32];
	for(int i=1;i<=MaxClients;++i)
	{
		if(!IsClientInGame(i) || !IsClientAuthorized(i))
			continue;
		GetClientAuthId(i, AuthId_Steam2, authid, sizeof(authid));
		if(StrEqual(authid, steamid) || (strlen(authid)>8 && strlen(steamid)>8 && strcmp(authid[8], steamid[8])==0))
			return i;
	}
	return 0;
}

stock bool GetLegacyAuthString(int client, char[] out, int maxlen, bool validate=true)
{
	char m_szSteamID[32];
	if(!GetClientAuthId(client, AuthId_Steam2, m_szSteamID, sizeof(m_szSteamID), validate))
		return false;
	if(m_szSteamID[0]=='[')
	{
		int m_unAccountID = StringToInt(m_szSteamID[5]);
		int m_unMod = m_unAccountID % 2;
		Format(out, maxlen, "STEAM_0:%d:%d", m_unMod, (m_unAccountID-m_unMod)/2);
	}
	else
		strcopy(out, maxlen, m_szSteamID);
	return true;
}

stock int ToAccountID(const char[] auth)
{
	if(strlen(auth)<11)
		return 0;
	return StringToInt(auth[10])*2 + (auth[8]-48);
}

stock int GetFriendID(int client, bool validate=true)
{
	char auth[32];
	GetLegacyAuthString(client, auth, sizeof(auth), validate);
	return ToAccountID(auth);
}

stock bool AddMenuItemEx(Handle menu, int style, const char[] info, const char[] display, any ...)
{
	char buf[256];
	VFormat(buf, sizeof(buf), display, 5);
	return AddMenuItem(menu, info, buf, style);
}

stock bool InsertMenuItemEx(Handle menu, int position, int style, const char[] info, const char[] display, any ...)
{
	char buf[256];
	VFormat(buf, sizeof(buf), display, 6);
	if(GetMenuItemCount(menu) == position)
		return AddMenuItem(menu, info, buf, style);
	return InsertMenuItem(menu, position, info, buf, style);
}

stock bool IsValidClient(int client, bool bots = true, bool dead = true)
{
	if (client <= 0)
		return false;

	if (client > MaxClients)
		return false;

	if (!IsClientInGame(client))
		return false;

	if (IsFakeClient(client) && !bots)
		return false;

	if (IsClientSourceTV(client))
		return false;

	if (IsClientReplay(client))
		return false;

	if (!IsPlayerAlive(client) && !dead)
		return false;

	return true;
}

stock void CreateDirectories()
{
	char sPath[PLATFORM_MAX_PATH];
	char sGamePath[PLATFORM_MAX_PATH];
	
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/store");
	if (!DirExists(sPath))
	{
		CreateDirectory(sPath, 511);
	}
	
	BuildPath(Path_SM, sGamePath, sizeof(sGamePath), "../../");
	
	Format(sPath, sizeof(sPath), "%s/cfg/sourcemod/store", sGamePath);
	
	ReplaceString(sPath, sizeof(sPath), "\\", "/");
	
	if (!DirExists(sPath))
	{
		CreateDirectory(sPath, 511);
	}
}

/** Opens cfg/<folder>/<filename>.cfg for writing only if the file does not exist. Creates directory if needed. Returns handle or null. */
stock File Store_OpenConfigForWriteIfMissing(const char[] folder, const char[] filename)
{
	char sPath[PLATFORM_MAX_PATH];
	char sGamePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sGamePath, sizeof(sGamePath), "../../");
	Format(sPath, sizeof(sPath), "%s/cfg/%s/%s%s", sGamePath, folder, filename, (StrContains(filename, ".cfg") >= 0) ? "" : ".cfg");
	ReplaceString(sPath, sizeof(sPath), "\\", "/");
	if (FileExists(sPath))
		return null;
	for (int i = 0; sPath[i]; i++)
	{
		if (sPath[i] == '/')
		{
			sPath[i] = '\0';
			if (sPath[0] && !DirExists(sPath))
				CreateDirectory(sPath, 511);
			sPath[i] = '/';
		}
	}
	return OpenFile(sPath, "w");
}

/** Writes a convar line: name "value" */
stock void Store_WriteConfigLine(File f, const char[] cvarName, const char[] defaultValue)
{
	if (f == null) return;
	char line[512];
	Format(line, sizeof(line), "%s \"%s\"", cvarName, defaultValue);
	WriteFileLine(f, line);
}

static File g_hStoreConfigFile = null;

/** Start writing module config (if file missing). Call STORE_CFG for each convar, then Store_EndModuleConfig. */
stock void Store_BeginModuleConfig(const char[] folder, const char[] filename)
{
	g_hStoreConfigFile = Store_OpenConfigForWriteIfMissing(folder, filename);
	if (g_hStoreConfigFile != null)
		WriteFileLine(g_hStoreConfigFile, "// Store module config");
}

#define STORE_CFG(%0,%1) Store_WriteConfigConvar(%0, %1)

stock void Store_WriteConfigConvar(const char[] name, const char[] value)
{
	if (g_hStoreConfigFile != null)
		Store_WriteConfigLine(g_hStoreConfigFile, name, value);
}

/** Finish and exec config. */
stock void Store_EndModuleConfig(const char[] folder, const char[] filename)
{
	Store_EnsureModuleConfig(folder, filename, g_hStoreConfigFile);
	g_hStoreConfigFile = null;
}

/** Creates module config file if missing, then executes it (cfg/<folder>/<filename>.cfg). */
stock void Store_EnsureModuleConfig(const char[] folder, const char[] filename, File f)
{
	if (f != null)
		delete f;
	char sPath[PLATFORM_MAX_PATH];
	char sGamePath[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sGamePath, sizeof(sGamePath), "../../");
	Format(sPath, sizeof(sPath), "%s/cfg/%s/%s%s", sGamePath, folder, filename, (StrContains(filename, ".cfg") >= 0) ? "" : ".cfg");
	ReplaceString(sPath, sizeof(sPath), "\\", "/");
	if (!FileExists(sPath))
		return;
	char sExec[PLATFORM_MAX_PATH];
	Format(sExec, sizeof(sExec), "exec %s/%s%s", folder, filename, (StrContains(filename, ".cfg") >= 0) ? "" : ".cfg");
	ReplaceString(sExec, sizeof(sExec), "\\", "/");
	ServerCommand(sExec);
}

stock void Store_RemoveChatTags(char[] message, int maxlen)
{
	int len = strlen(message);
	if (len <= 0)
		return;
	int w = 0;
	for (int i = 0; i < len && w < maxlen - 1; i++)
	{
		char c = message[i];
		if (c >= '\x01' && c <= '\x0F')
			continue;
		if (c == '{')
		{
			int j = i + 1;
			while (j < len && message[j] != '}')
				j++;
			if (j < len)
			{
				i = j;
				continue;
			}
		}
		message[w++] = c;
	}
	message[w] = '\0';
}

stock void Store_RemoveHexColors(char[] message, int maxlen)
{
	int len = strlen(message);
	if (len <= 0)
		return;
	char buffer[1024];
	int w = 0;
	int cap = maxlen < sizeof(buffer) ? maxlen - 1 : sizeof(buffer) - 1;
	for (int i = 0; i < len && w < cap; i++)
	{
		if (message[i] == '\x07' && i + 6 < len)
		{
			i += 6;
			continue;
		}
		if (message[i] == '\x08' && i + 8 < len)
		{
			i += 8;
			continue;
		}
		buffer[w++] = message[i];
	}
	buffer[w] = '\0';
	strcopy(message, maxlen, buffer);
}