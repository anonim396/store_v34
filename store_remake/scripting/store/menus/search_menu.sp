void Store_ItemName(int client, char[] sItemName)
{
	int iItemCount = 0;
	//	iItemIndex = -1;
		
	for(int i = 0; i<g_iItems; i++)
	{
		if(StrContains(g_eItems[i].szName, sItemName, false) != -1 || StrContains(g_eItems[i].szUniqueId, sItemName, false) != -1)
		{
			iItemCount++;
		}
	}
	if(iItemCount <= 0)
	{
		//Not Found
		#if defined _clientmod_included && defined _chat_modern_included
			MC_PrintToChat(client, "%s%t", g_sChatPrefix, "Item not found");
			if (!CM_IsClientModUser(client))
				chatm.CPrintToChat(client, "%s%t", g_sChatPrefix, "Item not found");
		#else
			#if defined _clientmod_included
				MC_PrintToChat(client, "%s%t", g_sChatPrefix, "Item not found");
				C_PrintToChat(client, "%s%t", g_sChatPrefix, "Item not found");
			#else
				#if defined _chat_modern_included
					chatm.CPrintToChat(client, "%s%t", g_sChatPrefix, "Item not found");
				#else
					PrintToChat(client, "%s%t", g_sChatPrefix, "Item not found");
				#endif
			#endif
		#endif
	}
	else
	{
		//More than 1 item
		int m_iFlags = GetUserFlagBits(client);
		
		Menu hEdictMenu = CreateMenu(Store_ItemNameMenu_Handler);
		char sMenuTemp[1024], sIndexTemp[128];
		FormatEx(sMenuTemp, sizeof(sMenuTemp), "%t", "Search Info Title", sItemName);
		hEdictMenu.SetTitle(sMenuTemp);

		for(int i = 0; i<g_iItems; i++)
		{
			if((StrContains(g_eItems[i].szName, sItemName, false) != -1 || StrContains(g_eItems[i].szUniqueId, sItemName, false) != -1))
			{
				FormatEx(sIndexTemp, sizeof(sIndexTemp), "%i", i);
				int iStyle = ITEMDRAW_DEFAULT;

				if (g_eItems[i].iPlans != 0 /*&& g_eItems[i][bPreview]*/)
				{
					if(!Store_HasClientItem(client, i))
						FormatEx(sMenuTemp, sizeof(sMenuTemp), "%s (%s)", g_eItems[i].szName, g_eTypeHandlers[g_eItems[i].iHandler].szType, client);
					else FormatEx(sMenuTemp, sizeof(sMenuTemp), "%s (%s) %t", g_eItems[i].szName, g_eTypeHandlers[g_eItems[i].iHandler].szType, "Owned", client);
				}
				
				else if(!CheckSteamAuth(client, g_eItems[i].szSteam) && !g_eItems[i].bPreview)
				{
					FormatEx(sMenuTemp, sizeof(sMenuTemp), "%s (%s) (%t)", g_eItems[i].szName, g_eTypeHandlers[g_eItems[i].iHandler].szType, 
																			"Cant be bought", client);
					iStyle = ITEMDRAW_DISABLED;
				}
				else if (!GetClientPrivilege(client, g_eItems[i].iFlagBits, m_iFlags) && !g_eItems[i].bPreview)
				{
					FormatEx(sMenuTemp, sizeof(sMenuTemp), "%s (%s) (%t)", g_eItems[i].szName, g_eTypeHandlers[g_eItems[i].iHandler].szType, 
																			"Cant be bought", client);
					iStyle = ITEMDRAW_DISABLED;
				}
				else if(Store_HasClientItem(client, i))
				{
					FormatEx(sMenuTemp, sizeof(sMenuTemp), "%s (%s) %t", g_eItems[i].szName, g_eTypeHandlers[g_eItems[i].iHandler].szType, "Owned", client);
				}
				else if(!g_eItems[i].bBuyable)
				{
					FormatEx(sMenuTemp, sizeof(sMenuTemp), "%s (%s) (%t)", g_eItems[i].szName, g_eTypeHandlers[g_eItems[i].iHandler].szType, 
																			"Cant be bought", client);
					iStyle = ITEMDRAW_DISABLED;
				}
				else if (g_eClients[client].iCredits<g_eItems[i].iPrice)
				{
					FormatEx(sMenuTemp, sizeof(sMenuTemp), "%s (%s) - %t", g_eItems[i].szName, g_eTypeHandlers[g_eItems[i].iHandler].szType, 
																					"Price", g_eItems[i].iPrice, client);
					iStyle = ITEMDRAW_DISABLED;
				}
				else 
				{
					FormatEx(sMenuTemp, sizeof(sMenuTemp), "%s (%s) - %t", g_eItems[i].szName, g_eTypeHandlers[g_eItems[i].iHandler].szType, 
																					"Price", g_eItems[i].iPrice, client);
				}
				
				hEdictMenu.AddItem(sIndexTemp, sMenuTemp, iStyle);
			}
		}
		hEdictMenu.ExitButton = true;
		hEdictMenu.Display(client, MENU_TIME_FOREVER);
	}
}

public int Store_ItemNameMenu_Handler(Menu hEdictMenu, MenuAction hAction, int client, int iParam2)
{
	switch (hAction)
	{
		case MenuAction_End:delete hEdictMenu;
		case MenuAction_Select:
		{
			char sSelected[32];
			GetMenuItem(hEdictMenu, iParam2, sSelected, sizeof(sSelected));
			g_iSelectedItem[client] = StringToInt(sSelected);
			
			g_iMenuBack[client]=g_eItems[StringToInt(sSelected)].iParent;
			g_iMenuClient[client]=client;
			g_iMenuNum[client] = 1;

			if(g_eItems[StringToInt(sSelected)].iHandler == g_iPackageHandler)
				DisplayStoreMenu(client, g_iSelectedItem[client]);
			else 
			{

				if (g_eItems[StringToInt(sSelected)].bPreview && g_eItems[StringToInt(sSelected)].iPlans == 0 && !Store_HasClientItem(client, StringToInt(sSelected)))
					DisplayPreviewMenu(client, g_iSelectedItem[client]);
				else if (g_eItems[StringToInt(sSelected)].bPreview && g_eItems[StringToInt(sSelected)].iPlans != 0 && !Store_HasClientItem(client, StringToInt(sSelected)))
					DisplayPlanMenu(client, StringToInt(sSelected));
				else if (!g_eItems[StringToInt(sSelected)].bPreview && g_eItems[StringToInt(sSelected)].iPlans != 0 && !Store_HasClientItem(client, StringToInt(sSelected)))
					DisplayPlanMenu(client, StringToInt(sSelected));
				else if (Store_HasClientItem(client, StringToInt(sSelected)))
					DisplayItemMenu(client, StringToInt(sSelected));
				else 
				{
					g_iSelectedPlan[client] = -1;
					//DisplayStoreMenu(client, g_eItems[StringToInt(sSelected)].iParent);
					char sTitle[128];
					Format(sTitle, sizeof(sTitle), "%t", "Confirm_Buy", g_eItems[g_iSelectedItem[client]].szName, g_eTypeHandlers[g_eItems[g_iSelectedItem[client]].iHandler].szType);
					Store_DisplayConfirmMenu(client, sTitle, MenuHandler_Store, 0);
					
					//CPrintToChatAll("This item is %s %s with itemid is %i and price is %i", g_eItems[g_iSelectedItem[client]].szName, g_eTypeHandlers[g_eItems[g_iSelectedItem[client]].iHandler].szType, g_iSelectedItem[client], g_eItems[g_iSelectedItem[client]].iPrice)
				}
			}
		}
	}
	
	return 0;
}