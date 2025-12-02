enum struct Sound
{
	char szSound[PLATFORM_MAX_PATH];
	char szShortcut_Sound[64];
	int unPrice;
}

Sound g_eSounds[STORE_MAX_ITEMS];
int g_iSounds = 0;

public void Sounds_OnPluginStart()
{
	Store_RegisterHandler("sound", "path", Sounds_OnMapStart, Sounds_Reset, Sounds_Config, Sounds_Equip, Sounds_Remove, false);

	HookEvent("player_say", Sounds_PlayerSay);
}

public void Sounds_OnMapStart()
{
	char tmp[PLATFORM_MAX_PATH];
	for(int i = 0; i < g_iSounds; ++i)
	{
		strcopy(tmp, sizeof(tmp), g_eSounds[i].szSound);
		PrecacheSound(tmp[6], true);
		Downloader_AddFileToDownloadsTable(g_eSounds[i].szSound);
	}
}

public void Sounds_Reset()
{
	g_iSounds = 0;
}

public bool Sounds_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iSounds);
	
	kv.GetString("path", g_eSounds[g_iSounds].szSound, PLATFORM_MAX_PATH);
	kv.GetString("trigger", g_eSounds[g_iSounds].szShortcut_Sound, 64);
	g_eSounds[g_iSounds].unPrice = kv.GetNum("price");
	
	if(FileExists(g_eSounds[g_iSounds].szSound, true))
	{
		++g_iSounds;
		return true;
	}
	
	return false;
}

public int Sounds_Equip(int client, int id)
{
	int m_iData = Store_GetDataIndex(id);
	LoopIngamePlayers(i)
	{
		ClientCommand(i, "play %s", g_eSounds[m_iData].szSound[6]);
	}
	return 1;
}

public int Sounds_Remove(int client, int id)
{
	return 0;
}

public Action Sounds_PlayerSay(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));
	if (!client || !IsClientInGame(client))
		return Plugin_Continue;
	
	char msg[256];
	GetEventString(event, "text", msg, sizeof(msg));

	for(int i = 0; i < g_iSounds; ++i)
	{
		if(strcmp(msg, g_eSounds[i].szShortcut_Sound) == 0)
		{
			int c = Store_GetClientCredits(client);
			if(c >= g_eSounds[i].unPrice)
			{
				Store_SetClientCredits(client, c - g_eSounds[i].unPrice);
				char tmp[PLATFORM_MAX_PATH];
				strcopy(tmp, sizeof(tmp), g_eSounds[i].szSound);
				LoopIngamePlayers(a)
				{
					ClientCommand(a, "play %s", tmp[6]);
				}
			}
			else
			{
				#if defined _clientmod_included
					MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Not Enough CM");
					C_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Not Enough");
				#else
					PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Not Enough");
				#endif
			}
			break;
		}
	}

	return Plugin_Continue;
}