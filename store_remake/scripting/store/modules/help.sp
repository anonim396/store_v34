#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

char g_szHelpTitle[STORE_MAX_ITEMS][256];
char g_szHelp[STORE_MAX_ITEMS][256];

int g_iHelp = 0;

#if defined STANDALONE_BUILD
public void OnPluginStart()
#else
public void Help_OnPluginStart()
#endif
{
	Store_RegisterHandler("help", "", Help_OnMapStart, Help_Reset, Help_Config, Help_Equip, Help_Remove, false, true);
}

public void Help_OnMapStart()
{
}

public void Help_Reset()
{
	g_iHelp = 0;
}

public bool Help_Config(KeyValues kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iHelp);
	
	kv.GetSectionName(g_szHelpTitle[g_iHelp], sizeof(g_szHelpTitle[]));
	kv.GetString("text", g_szHelp[g_iHelp], sizeof(g_szHelp[]));

	ReplaceString(g_szHelp[g_iHelp], sizeof(g_szHelp[]), "\\n", "\n");
	
	g_iHelp++;
	return true;
}

public int Help_Equip(int client, int id)
{
	int m_iData = Store_GetDataIndex(id);

	Panel m_hPanel = new Panel();
	m_hPanel.SetTitle(g_szHelpTitle[m_iData]);

	m_hPanel.DrawText(g_szHelp[m_iData]);

	m_hPanel.CurrentKey = 8;
	m_hPanel.DrawItem("%t", "Help_Back", ITEMDRAW_DEFAULT);

	m_hPanel.CurrentKey = 10;
	m_hPanel.DrawItem("%t", "Help_Exit", ITEMDRAW_DEFAULT);
 
	m_hPanel.Send(client, PanelHandler_Help, 0);
	delete m_hPanel;

	return 0;
}

public int PanelHandler_Help(Menu menu, MenuAction action, int client, int param2)
{
	if (action == MenuAction_Select)
	{
		if (param2 == 8)
		{
			Store_DisplayPreviousMenu(client);
		}
	}
}

public int Help_Remove(int client)
{
	return 0;
}