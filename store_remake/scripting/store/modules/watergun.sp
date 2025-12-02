public void Watergun_OnPluginStart()
{
	Store_RegisterHandler("watergun", "", Watergun_OnMapStart, Watergun_Reset, Watergun_Config, Watergun_Equip, Watergun_Remove, true);
	
	HookEvent("player_hurt", Watergun_PlayerHurt);
}

public void Watergun_OnMapStart()
{
}

public void Watergun_Reset()
{
}

public bool Watergun_Config(Handle kv, int itemid)
{
	Store_SetDataIndex(itemid, 0);
	return true;
}

public int Watergun_Equip(int client, int id)
{
	return -1;
}

public void Watergun_Remove(int client, int id)
{
}

public Action Watergun_PlayerHurt(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	int attacker = GetClientOfUserId(event.GetInt("attacker"));

	if (client == attacker || attacker == 0)
	{
		return Plugin_Continue;
	}

	int m_iEquipped = Store_GetEquippedItem(attacker, "watergun");
	if (m_iEquipped >= 0)
	{
		SetVariantString("WaterSurfaceExplosion");
		AcceptEntityInput(client, "DispatchEffect");
	}
	
	return Plugin_Continue;
}