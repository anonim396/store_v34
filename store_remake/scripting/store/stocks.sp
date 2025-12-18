#if defined _store_stocks_included
    #endinput
#endif
#define _store_stocks_included

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