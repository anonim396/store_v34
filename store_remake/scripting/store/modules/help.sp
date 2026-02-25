#if STORE_MODULE_HELP
char g_sInfoTitle[STORE_MAX_ITEMS][256];
char g_sInfo[STORE_MAX_ITEMS][256];

int g_iCount = 0;

public void Help_OnPluginStart()
{
	Store_RegisterHandler("info","text", _, Info_Reset, Info_Config, Info_Equip, _, false, true);
}

public void Info_Reset()
{
	g_iCount = 0;
}

public bool Info_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iCount);

	kv.GetSectionName(g_sInfoTitle[g_iCount], sizeof(g_sInfoTitle[]));
	kv.GetString("text", g_sInfo[g_iCount], sizeof(g_sInfo[]));

	ReplaceString(g_sInfo[g_iCount], sizeof(g_sInfo[]), "\\n", "\n");

	g_iCount++;

	return true;
}

public void Info_Equip(int client, int id)
{
	int iIndex = Store_GetDataIndex(id);

	Panel panel = new Panel();
	panel.SetTitle(g_sInfoTitle[iIndex]);
	
	panel.DrawText(g_sInfo[iIndex]);

	char sBuffer[64];
	Format(sBuffer, sizeof(sBuffer), "%t", "Help_Back");
	panel.CurrentKey = 8;
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);
	panel.DrawItem("", ITEMDRAW_SPACER);
	Format(sBuffer, sizeof(sBuffer), "%t", "Help_Exit");
	panel.CurrentKey = 10;
	panel.DrawItem(sBuffer, ITEMDRAW_DEFAULT);

	panel.Send(client, PanelHandler_Info, MENU_TIME_FOREVER);
}

public int PanelHandler_Info(Handle menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		if (param2 == 8)
		{
			Store_DisplayPreviousMenu(client);
		}
	}
	
	return 0;
}

#else

void Help_OnPluginStart() {}

#endif