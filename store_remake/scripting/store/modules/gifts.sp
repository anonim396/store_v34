// Если Gifts не найден, выдаем ошибку компиляции
#if !defined _gifts_included
	#error "This module requires Chat Processor. Please install it from: https://github.com/azalty/sm-zeph-gifts"
#endif

#include <sourcemod>
#include <gifts>

int g_cvarGiftsEnabled;
int g_cvarGiftsMinimum;
int g_cvarGiftsMaximum;
int g_cvarGiftsFlag;

public void Gifts_OnPluginStart()
{
	if(FindPluginByFile("gifts.smx") == null)
	{
		LogError("Gifts! isn't installed or failed to load. Gifts support will be disabled. Please install Gifts. (http://forums.alliedmods.net/showthread.php?t=175185)");
		return;
	}

	g_cvarGiftsEnabled = RegisterConVar("sm_store_gifts_enabled", "1", "Enable/disable gifts support", TYPE_INT);
	g_cvarGiftsMinimum = RegisterConVar("sm_store_gifts_minimum", "1", "Minimum amount of credits to be given", TYPE_INT);
	g_cvarGiftsMaximum = RegisterConVar("sm_store_gifts_maximum", "100", "Maximum amount of credits to be given", TYPE_INT);
	g_cvarGiftsFlag = RegisterConVar("sm_store_gifts_flag", "", "Flag for gifts. Leave blank to disable.", TYPE_FLAG);

	RegConsoleCmd("sm_drop", Command_Drop);

	Store_RegisterMenuHandler("gifts", Gifts_OnMenu, Gifts_OnHandler);
	Gifts_RegisterPlugin(Gifts_OnPickUp);
}

public Action Command_Drop(int client, int args)
{
	if(client && !GetClientPrivilege(client, g_eCvars[g_cvarGiftsFlag].aCache))
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "You dont have permission CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "You dont have permission");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix_CM, "You dont have permission");
		#endif
		return Plugin_Handled;
	}

	if(!g_eCvars[g_cvarGiftsEnabled].aCache)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Gift Disabled CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Gift Disabled");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Gift Disabled");
		#endif
		return Plugin_Handled;
	}

	if(!IsPlayerAlive(client))
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Must be Alive CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Must be Alive");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Must be Alive");
		#endif
		return Plugin_Handled;
	}

	char m_szTmp[64];
	GetCmdArg(1, m_szTmp, sizeof(m_szTmp));
	
	int m_iCredits = StringToInt(m_szTmp);
	if(g_eClients[client].iCredits < m_iCredits || m_iCredits <= 0)
	{
		#if defined _clientmod_included
			MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Invalid Amount CM");
			C_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Invalid Amount");
		#else
			PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Invalid Amount");
		#endif
		return Plugin_Handled;
	}

	float pos[3];
	GetClientAbsOrigin(client, pos);
	pos[2] += 20.0;
	Gifts_SpawnGift(Gifts_OnPickUpCredit, "", -1.0, pos, m_iCredits, client);

	Store_SetClientCredits(client, Store_GetClientCredits(client) - m_iCredits);

	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Gift Dropped CM", m_iCredits);
		C_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Gift Dropped", m_iCredits);
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Credit Gift Dropped", m_iCredits);
	#endif

	Store_LogMessage(client, -m_iCredits, "Dropped %d credits on the ground", m_iCredits);

	return Plugin_Handled;
}

public void Gifts_OnMenu(Menu menu, int client, int itemid)
{
	if(!g_eCvars[g_cvarGiftsEnabled].aCache)
		return;
	if(client && !GetClientPrivilege(client, g_eCvars[g_cvarGiftsFlag].aCache))
		return;

	int target = Store_GetClientTarget(client);
	char sBuffer[128];
	if(!Store_IsClientVIP(target) && !Store_IsItemInBoughtPackage(target, itemid))
	{
		Format(sBuffer, sizeof(sBuffer), "%t", "Drop Gift");
		menu.AddItem("drop_gift", sBuffer, ITEMDRAW_DEFAULT);
	}
}

public bool Gifts_OnHandler(int client, char[] info, int itemid)
{
	if(!g_eCvars[g_cvarGiftsEnabled].aCache)
		return false;

	if(strcmp(info, "drop_gift") == 0)
	{
		Store_Item m_eItem;
		Type_Handler m_eHandler;
		Store_GetItem(itemid, m_eItem);
		Store_GetHandler(m_eItem.iHandler, m_eHandler);
		char m_szTitle[128];
		Format(m_szTitle, sizeof(m_szTitle), "%t", "Confirm_Gift_Drop", m_eItem.szName, m_eHandler.szType);
		Store_SetClientMenu(client, 2);
		if(Store_ShouldConfirm())
			Store_DisplayConfirmMenu(client, m_szTitle, Gifts_MenuHandler, itemid);
		else
		{
			Gifts_MenuHandler(null, MenuAction_Select, client, itemid);
			Store_DisplayPreviousMenu(client);
		}
	}
	return false;
}

public void Gifts_MenuHandler(Handle menu, MenuAction action, int client, int param2)
{
	if(!g_eCvars[g_cvarGiftsEnabled].aCache)
		return;
	
	if(action == MenuAction_Select)
	{
		if(menu == null)
		{
			int target = Store_GetClientTarget(client);
			float pos[3];
			GetClientAbsOrigin(target, pos);
			pos[2] += 20.0;

			Client_Item output;
			Store_GetClientItem(client, param2, output);

			DataPack data = new DataPack();
			data.WriteCell(param2);
			data.WriteCell(output.iDateOfPurchase);
			data.WriteCell(output.iDateOfExpiration);
			data.WriteCell(output.iPriceOfPurchase);
			data.Reset();

			Gifts_SpawnGift(Gifts_OnPickUpItem, "", -1.0, pos, view_as<int>(data), target);
			Store_RemoveItem(target, param2);
		}
	}
}

public void Gifts_OnPickUp(int client)
{
	if(!g_eCvars[g_cvarGiftsEnabled].aCache)
		return;
	
	int m_iCredits = GetRandomInt(view_as<int>(g_eCvars[g_cvarGiftsMinimum].aCache), view_as<int>(g_eCvars[g_cvarGiftsMaximum].aCache));
	Store_SetClientCredits(client, Store_GetClientCredits(client) + m_iCredits);
	
	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Gift Credit Picked CM", m_iCredits);
		C_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Gift Credit Picked", m_iCredits);
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Gift Credit Picked", m_iCredits);
	#endif
	
}

public void Gifts_OnPickUpItem(int client, int data, int owner)
{
	if(!g_eCvars[g_cvarGiftsEnabled].aCache)
		return;
	
	DataPack m_hData = view_as<DataPack>(data);

	int itemid = m_hData.ReadCell();
	int purchase = m_hData.ReadCell();
	int expiration = m_hData.ReadCell();
	int price = m_hData.ReadCell();

	delete m_hData;

	Store_Item m_eItem;
	Type_Handler m_eHandler;
	Store_GetItem(itemid, m_eItem);
	Store_GetHandler(m_eItem.iHandler, m_eHandler);

	Store_GiveItem(client, itemid, purchase, expiration, price);
	
	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Gift Item Picked CM", m_eItem.szName, m_eHandler.szType);
		C_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Gift Item Picked", m_eItem.szName, m_eHandler.szType);
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Gift Item Picked", m_eItem.szName, m_eHandler.szType);
	#endif

	Store_LogMessage(client, 0, "Picked up a gift containing the following item: %s", m_eItem.szName);
}

public void Gifts_OnPickUpCredit(int client, int data, int owner)
{
	if(!g_eCvars[g_cvarGiftsEnabled].aCache)
		return;
	
	Store_SetClientCredits(client, Store_GetClientCredits(client) + data);
	
	#if defined _clientmod_included
		MC_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Gift Credit Picked CM", data);
		C_PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Gift Credit Picked", data);
	#else
		PrintToChat(client, "%s %t", g_sChatPrefix_CM, "Gift Credit Picked", data);
	#endif

	Store_LogMessage(client, data, "Picked up a gift containing %d credits", data);
}