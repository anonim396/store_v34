#if STORE_MODULE_KNIFE
char g_szKnives[STORE_MAX_ITEMS][64];
int g_unDefIndex[STORE_MAX_ITEMS];
bool g_bGivingKnife[MAXPLAYERS + 1] = {false, ...};
bool g_bBlockEquipHook[MAXPLAYERS + 1] = {false, ...};
int g_iKnives = 0;

public void Knives_OnPluginStart()
{
	Store_RegisterHandler("knife", "entity", Knives_OnMapStart, Knives_Reset, Knives_Config, Knives_Equip, Knives_Remove, true);
}

public void Knives_OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_WeaponEquipPost, Knives_OnPostWeaponEquip);
}

public void Knives_OnMapStart()
{
}

public void Knives_Reset()
{
	g_iKnives = 0;
}

public bool Knives_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iKnives);
	
	kv.GetString("entity", g_szKnives[g_iKnives], sizeof(g_szKnives[]));
	g_unDefIndex[g_iKnives] = kv.GetNum("defindex");
	
	++g_iKnives;
	return true;
}

public int Knives_Equip(int client, int id)
{
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		CreateTimer(0.1, Knives_CheckKnife, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
	}

	return 0;
}

public int Knives_Remove(int client)
{
	if(IsClientInGame(client) && IsPlayerAlive(client))
	{
		g_bBlockEquipHook[client] = true;
		
		int knife = GetPlayerWeaponSlot(client, 2);
		if(knife != -1)
		{
			RemovePlayerItem(client, knife);
			AcceptEntityInput(knife, "Kill");
		}
		
		int newKnife = GivePlayerItem(client, "weapon_knife");
		if(newKnife != -1)
		{
			EquipPlayerWeapon(client, newKnife);
		}
		
		CreateTimer(0.5, Timer_ResetBlockHook, GetClientUserId(client));
	}
	
	return 0;
}

public Action Timer_ResetBlockHook(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(client && IsClientInGame(client))
	{
		g_bBlockEquipHook[client] = false;
	}
	return Plugin_Stop;
}

stock void Knives_GiveClient(int client)
{
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client) || !(2 <= GetClientTeam(client) <= 3))
		return;

	int m_iItem = Store_GetEquippedItem(client, "knife", 0);
	if(m_iItem < 0) 
	{
		g_bGivingKnife[client] = false;
		return;
	}
	
	int m_iData = Store_GetDataIndex(m_iItem);
	
	int m_iKnife = GetPlayerWeaponSlot(client, 2);
	
	if(m_iKnife != -1)
	{
		char classname[64];
		GetEntityClassname(m_iKnife, classname, sizeof(classname));
		
		if(StrEqual(classname, g_szKnives[m_iData]))
		{
			g_bGivingKnife[client] = false;
			return;
		}
		
		g_bBlockEquipHook[client] = true;
		
		RemovePlayerItem(client, m_iKnife);
		AcceptEntityInput(m_iKnife, "Kill");
	}
	
	g_bGivingKnife[client] = true;
	int newKnife = GivePlayerItem(client, g_szKnives[m_iData]);
	if(newKnife != -1)
	{
		EquipPlayerWeapon(client, newKnife);
		
		if(g_unDefIndex[m_iData] != 0)
		{
			SetEntProp(newKnife, Prop_Send, "m_iItemDefinitionIndex", g_unDefIndex[m_iData]);
		}
	}
	
	CreateTimer(0.2, Timer_ResetFlags, GetClientUserId(client));
}

public Action Timer_ResetFlags(Handle timer, int userid)
{
	int client = GetClientOfUserId(userid);
	if(client && IsClientInGame(client))
	{
		g_bGivingKnife[client] = false;
		g_bBlockEquipHook[client] = false;
	}
	return Plugin_Stop;
}

public void Knives_OnPostWeaponEquip(int client, int weapon)
{ 
	if(g_bBlockEquipHook[client])
		return;
		
	char edict[64];
	GetEdictClassname(weapon, edict, sizeof(edict));
	
	if(StrContains(edict, "knife") == -1 && StrContains(edict, "bayonet") == -1)
		return;

	if(StrEqual(edict, "weapon_knife"))
	{
		int m_iItem = Store_GetEquippedItem(client, "knife", 0);
		if(m_iItem >= 0)
		{
			if(!g_bGivingKnife[client])
			{
				CreateTimer(0.1, Knives_CheckKnife, GetClientSerial(client), TIMER_FLAG_NO_MAPCHANGE);
			}
		}
	}
	else if(g_bGivingKnife[client])
	{
		int m_iItem = Store_GetEquippedItem(client, "knife", 0);
		if(m_iItem < 0) return;
		
		int m_iData = Store_GetDataIndex(m_iItem);
		
		if(g_unDefIndex[m_iData] != 0)
		{
			SetEntProp(weapon, Prop_Send, "m_iItemDefinitionIndex", g_unDefIndex[m_iData]);
		}
	}
}

public Action Knives_CheckKnife(Handle timer, int serial)
{
	int client = GetClientFromSerial(serial);
	
	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Handled;
	
	Knives_GiveClient(client);
	
	return Plugin_Handled;
}

#else

void Knives_OnPluginStart() {}
void Knives_OnClientPutInServer(int client)
{
	#pragma unused client
}

#endif