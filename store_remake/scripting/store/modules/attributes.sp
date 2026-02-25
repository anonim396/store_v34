#if STORE_MODULE_ATTRIBUTES

public void Attributes_OnPluginStart()
{
	HookEvent("player_spawn", Attributes_PlayerSpawn);
}

public Action Attributes_PlayerSpawn(Handle event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!client || !IsClientInGame(client) || !IsPlayerAlive(client))
		return Plugin_Continue;

	int totalHealth = 0;
	int totalArmor = 0;
	
	float finalGravity = 1.0;

	int idx = -1;
	int item_idx = -1;
	Store_Item item;
	char m_szValue[16];
	
	while((item_idx = Store_IterateEquippedItems(client, idx, true)) != -1)
	{
		Store_GetItem(item_idx, item);
		
		if(GetTrieString(item.hAttributes, "health", STRING(m_szValue)))
		{
			totalHealth += StringToInt(m_szValue);
		}
		
		if(GetTrieString(item.hAttributes, "gravity", STRING(m_szValue)))
		{
			float gravity = StringToFloat(m_szValue);
			finalGravity = gravity;
		}
		
		if(GetTrieString(item.hAttributes, "armor", STRING(m_szValue)))
		{
			totalArmor += StringToInt(m_szValue);
		}
		
		if(GetTrieString(item.hAttributes, "speed", STRING(m_szValue)))
		{
			SetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue", 
				GetEntPropFloat(client, Prop_Data, "m_flLaggedMovementValue") * StringToFloat(m_szValue));
		}
	}
	
	if(totalHealth > 0)
	{
		int currentHealth = GetClientHealth(client);
		int maxHealth = GetEntProp(client, Prop_Data, "m_iMaxHealth");
		
		int newHealth = currentHealth + totalHealth;
		if(newHealth > maxHealth)
			newHealth = maxHealth;
			
		SetEntityHealth(client, newHealth);
	}
	
	SetEntityGravity(client, finalGravity);
	
	if(totalArmor > 0)
	{
		int currentArmor = GetEntProp(client, Prop_Send, "m_ArmorValue");
		SetEntProp(client, Prop_Send, "m_ArmorValue", currentArmor + totalArmor);
	}

	return Plugin_Continue;
}

#else
void Attributes_OnPluginStart() {}
#endif