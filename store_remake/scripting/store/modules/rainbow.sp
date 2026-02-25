#if STORE_MODULE_RAINBOW

bool g_bRainbowClient[MAXPLAYERS+1];
bool g_bRainbowPreview[MAXPLAYERS+1];
Handle g_hRainbowPreviewTimer[MAXPLAYERS+1];
int g_iRainbowRGB[3];
int g_iRainbowDirection;

void Rainbow_OnPluginStart()
{
	Store_RegisterHandler("rainbow_models", "rainbow", INVALID_FUNCTION, INVALID_FUNCTION, Rainbow_Config, Rainbow_Equip, Rainbow_Remove, true);
	g_iRainbowRGB[0] = 255; g_iRainbowRGB[1] = 0; g_iRainbowRGB[2] = 0;
	g_iRainbowDirection = 0;
}

public bool Rainbow_Config(KeyValues &kv, int itemid)
{
	return true;
}

public int Rainbow_Equip(int client, int id)
{
	g_bRainbowClient[client] = true;
	return 0;
}

public int Rainbow_Remove(int client)
{
	g_bRainbowClient[client] = false;
	SetEntityRenderColor(client, 255, 255, 255, 255);
	return 0;
}

void Rainbow_OnGameFrame()
{
	if ((GetGameTickCount() % 5) != 0)
		return;
	Rainbow_UpdateCycle();
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !IsPlayerAlive(i))
			continue;
		if (g_bRainbowClient[i] || g_bRainbowPreview[i])
			SetEntityRenderColor(i, g_iRainbowRGB[0], g_iRainbowRGB[1], g_iRainbowRGB[2], 255);
		else
			SetEntityRenderColor(i, 255, 255, 255, 255);
	}
}

void Rainbow_UpdateCycle()
{
	switch (g_iRainbowDirection)
	{
		case 0:
		{
			g_iRainbowRGB[2] += 15;
			if (g_iRainbowRGB[2] >= 255) { g_iRainbowRGB[2] = 255; g_iRainbowDirection = 1; }
		}
		case 1:
		{
			g_iRainbowRGB[0] -= 15;
			if (g_iRainbowRGB[0] <= 0) { g_iRainbowRGB[0] = 0; g_iRainbowDirection = 2; }
		}
		case 2:
		{
			g_iRainbowRGB[1] += 15;
			if (g_iRainbowRGB[1] >= 255) { g_iRainbowRGB[1] = 255; g_iRainbowDirection = 3; }
		}
		case 3:
		{
			g_iRainbowRGB[2] -= 15;
			if (g_iRainbowRGB[2] <= 0) { g_iRainbowRGB[2] = 0; g_iRainbowDirection = 4; }
		}
		case 4:
		{
			g_iRainbowRGB[0] += 15;
			if (g_iRainbowRGB[0] >= 255) { g_iRainbowRGB[0] = 255; g_iRainbowDirection = 5; }
		}
		case 5:
		{
			g_iRainbowRGB[1] -= 15;
			if (g_iRainbowRGB[1] <= 0) { g_iRainbowRGB[1] = 0; g_iRainbowDirection = 0; }
		}
	}
}

void Rainbow_OnClientDisconnect(int client)
{
	g_bRainbowClient[client] = false;
	g_bRainbowPreview[client] = false;
	if (g_hRainbowPreviewTimer[client] != null)
	{
		delete g_hRainbowPreviewTimer[client];
		g_hRainbowPreviewTimer[client] = null;
	}
}

public Action Rainbow_Timer_StopPreview(Handle timer, int client)
{
	g_hRainbowPreviewTimer[client] = null;
	g_bRainbowPreview[client] = false;
	if (client && IsClientInGame(client) && IsPlayerAlive(client))
		SetEntityRenderColor(client, 255, 255, 255, 255);
	return Plugin_Stop;
}

public void Rainbow_OnPreviewItem(int client, const char[] type, int index)
{
	if (g_hRainbowPreviewTimer[client] != null)
	{
		delete g_hRainbowPreviewTimer[client];
		g_hRainbowPreviewTimer[client] = null;
	}
	g_bRainbowPreview[client] = true;
	g_hRainbowPreviewTimer[client] = CreateTimer(15.0, Rainbow_Timer_StopPreview, client, TIMER_FLAG_NO_MAPCHANGE);
	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Spawn Preview CM");
		C_PrintToChat(client, "%s %t", g_sChatPrefix, "Spawn Preview");
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix, "Spawn Preview");
	#endif
}

#else

void Rainbow_OnPluginStart() {}
void Rainbow_OnGameFrame() {}
void Rainbow_OnClientDisconnect(int client) 
{
	#pragma unused client
}

#endif
