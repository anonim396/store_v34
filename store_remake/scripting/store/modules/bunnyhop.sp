#if STORE_MODULE_BUNNYHOP
public void Bunnyhop_OnPluginStart()
{
	Store_RegisterHandler("bunnyhop", "", Bunnyhop_OnMapStart, Bunnyhop_Reset, Bunnyhop_Config, Bunnyhop_Equip, Bunnyhop_Remove, true);
}

public void Bunnyhop_OnMapStart()
{
}

public void Bunnyhop_Reset()
{
}

public bool Bunnyhop_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, 0);
	return true;
}

public int Bunnyhop_Equip(int client, int id)
{
	return -1;
}

public void Bunnyhop_Remove(int client, int id)
{
}

public Action Bunnyhop_OnPlayerRunCmd(int client, int &buttons)
{
	int m_iEquipped = Store_GetEquippedItem(client, "bunnyhop");
	if(m_iEquipped < 0)
		return Plugin_Continue;

	int m_iWater = GetEntProp(client, Prop_Data, "m_nWaterLevel");
	if (IsPlayerAlive(client))
		if (buttons & IN_JUMP)
			if (m_iWater <= 1)
				if (!(GetEntityMoveType(client) & MOVETYPE_LADDER))
				{
					SetEntPropFloat(client, Prop_Send, "m_flStamina", 0.0);
					if (!(GetEntityFlags(client) & FL_ONGROUND))
						buttons &= ~IN_JUMP;
				}

	return Plugin_Continue;
}

#else

void Bunnyhop_OnPluginStart() {}
void Bunnyhop_OnPlayerRunCmd(int client, int &buttons)
{
	#pragma unused client
	#pragma unused buttons
}

#endif