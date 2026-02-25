Handle gf_hPreviewItem;
Handle gf_hOnConfigExecuted;
Handle gf_hCreditsGiven;
#if defined _clientmod_included
Handle gf_hOnConfigExecutedCM;
#endif

void Store_Forward_OnForwardInit()
{
	gf_hPreviewItem = CreateGlobalForward("Store_OnPreviewItem", ET_Ignore, Param_Cell, Param_String, Param_Cell);
	gf_hOnConfigExecuted = CreateGlobalForward("Store_OnConfigExecuted", ET_Ignore, Param_String);
	gf_hCreditsGiven = CreateForward(ET_Ignore, Param_Cell, Param_CellByRef);
	#if defined _clientmod_included
	gf_hOnConfigExecutedCM = CreateGlobalForward("Store_OnConfigExecutedCM", ET_Ignore, Param_String);
	#endif
}

void Store_Forward_CreditsGiven(int client, int &delta)
{
	if (delta <= 0 || !gf_hCreditsGiven)
		return;
	Call_StartForward(gf_hCreditsGiven);
	Call_PushCell(client);
	Call_PushCellRef(delta);
	Call_Finish();
}

void Store_Forward_PreviewForward(int client, char[] Type, int iData)
{
	Call_StartForward(gf_hPreviewItem);
	Call_PushCell(client);
	Call_PushString(Type);
	Call_PushCell(iData);
	Call_Finish();
}

/*
"Keys"
{
	"MenuItemSound"			"buttons/button14.wav"

	"MenuExitSound"			"buttons/combine_button7.wav"
	
	"MenuExitBackSound"		"buttons/combine_button7.wav"
}
*/

void Store_Modules_LoadCoreSounds()
{
	char sBuffer[256];
	char sPath[PLATFORM_MAX_PATH];
	bool bHaveMenuItem = false;
	bool bHaveMenuExit = false;

	// Older SourceMod: try addons/sourcemod/configs/core.cfg first (Keys.MenuItemSound / MenuExitSound)
	BuildPath(Path_SM, sPath, sizeof(sPath), "configs/core.cfg");
	KeyValues kv = new KeyValues("");
	if (kv.ImportFromFile(sPath) && kv.JumpToKey("Keys", false))
	{
		kv.GetString("MenuItemSound", sBuffer, sizeof(sBuffer), "");
		if (sBuffer[0])
		{
			strcopy(g_sMenuItem, sizeof(g_sMenuItem), sBuffer);
			bHaveMenuItem = true;
		}
		kv.GetString("MenuExitSound", sBuffer, sizeof(sBuffer), "");
		if (sBuffer[0])
		{
			strcopy(g_sMenuExit, sizeof(g_sMenuExit), sBuffer);
			bHaveMenuExit = true;
		}
	}
	delete kv;

	// Fallback: core.games/common.games (newer SM or when core.cfg is empty/missing)
	GameData hGameData = LoadGameConfigFile("core.games/common.games");
	if (hGameData != null)
	{
		if (!bHaveMenuItem)
		{
			if (GameConfGetKeyValue(hGameData, "MenuItemSound", sBuffer, sizeof(sBuffer)) && sBuffer[0])
				strcopy(g_sMenuItem, sizeof(g_sMenuItem), sBuffer);
			else
				strcopy(g_sMenuItem, sizeof(g_sMenuItem), "buttons/button14.wav");
		}
		if (!bHaveMenuExit)
		{
			if (GameConfGetKeyValue(hGameData, "MenuExitSound", sBuffer, sizeof(sBuffer)) && sBuffer[0])
				strcopy(g_sMenuExit, sizeof(g_sMenuExit), sBuffer);
			else
				strcopy(g_sMenuExit, sizeof(g_sMenuExit), "buttons/combine_button7.wav");
		}
		/*
		if (GameConfGetKeyValue(hGameData, "MenuExitBackSound", sBuffer, sizeof(sBuffer)) && sBuffer[0])
			strcopy(g_sMenuExitBack, sizeof(g_sMenuExitBack), sBuffer);
		else
			strcopy(g_sMenuExitBack, sizeof(g_sMenuExitBack), "buttons/combine_button7.wav");
		*/
		delete hGameData;
	}
	else if (!bHaveMenuItem || !bHaveMenuExit)
	{
		if (!bHaveMenuItem)
			strcopy(g_sMenuItem, sizeof(g_sMenuItem), "buttons/button14.wav");
		if (!bHaveMenuExit)
			strcopy(g_sMenuExit, sizeof(g_sMenuExit), "buttons/combine_button7.wav");
	}
}

void Store_Forward_OnConfigsExecuted()
{
	Store_Modules_LoadCoreSounds();

	Call_StartForward(gf_hOnConfigExecuted);
	Call_PushString(g_sChatPrefix);
	Call_Finish();

	Store_Modules_OnConfigExecuted();

	#if defined _clientmod_included
	Call_StartForward(gf_hOnConfigExecutedCM);
	Call_PushString(g_sChatPrefix_CM);
	Call_Finish();
	Store_Modules_OnConfigExecutedCM();
	#endif
}

void Store_Modules_OnConfigExecuted()
{
	Modules_OnConfigExecuted();
}

#if defined _clientmod_included
void Store_Modules_OnConfigExecutedCM()
{
	Modules_OnConfigExecutedCM();
}
#endif

