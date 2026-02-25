#if STORE_MODULE_CPSUPPORT
#if !defined _chat_processor_included
	#warning "This module requires Chat Processor. Please install it from: https://github.com/anonim396/chat_processor_v34"
	public void CPSupport_OnPluginStart(){} public void SCPSupport_OnMapStart(){} public void SCPSupport_Reset(){} public void SCPSupport_Equip(){} public void SCPSupport_Remove(){}
#else

char g_szNameTags[STORE_MAX_ITEMS][MAXLENGTH_NAME];
char g_szNameColors[STORE_MAX_ITEMS][32];
char g_szMessageColors[STORE_MAX_ITEMS][32];

int g_iNameTags = 0;
int g_iNameColors = 0;
int g_iMessageColors = 0;

static void StripColorsForNormalClient(char[] buffer, int maxlen)
{
	Store_RemoveHexColors(buffer, maxlen);
	#if defined _clientmod_included
	MC_RemoveTags(buffer, maxlen);
	#else
	Store_RemoveChatTags(buffer, maxlen);
	#endif
}

public void CPSupport_OnPluginStart()
{
	if (FindPluginByFile("chat-processor.smx") == null)
	{
		LogError("Chat Processor isn't installed or failed to load. SCP support will be disabled. (https://github.com/anonim396/chat_processor_v34)");
		return;
	}
	Store_RegisterHandler("nametag", "tag", SCPSupport_OnMapStart, SCPSupport_Reset, NameTags_Config, SCPSupport_Equip, SCPSupport_Remove, true);
	Store_RegisterHandler("namecolor", "color", SCPSupport_OnMapStart, SCPSupport_Reset, NameColors_Config, SCPSupport_Equip, SCPSupport_Remove, true);
	Store_RegisterHandler("msgcolor", "color", SCPSupport_OnMapStart, SCPSupport_Reset, MsgColors_Config, SCPSupport_Equip, SCPSupport_Remove, true);
}

public void SCPSupport_OnMapStart()
{
}

public void SCPSupport_Reset()
{
	g_iNameTags = 0;
	g_iNameColors = 0;
	g_iMessageColors = 0;
}

public bool NameTags_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iNameTags);
	kv.GetString("tag", g_szNameTags[g_iNameTags], sizeof(g_szNameTags[]));
	g_iNameTags++;
	return true;
}

public bool NameColors_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iNameColors);
	kv.GetString("color", g_szNameColors[g_iNameColors], sizeof(g_szNameColors[]));
	g_iNameColors++;
	return true;
}

public bool MsgColors_Config(KeyValues &kv, int itemid)
{
	Store_SetDataIndex(itemid, g_iMessageColors);
	kv.GetString("color", g_szMessageColors[g_iMessageColors], sizeof(g_szMessageColors[]));
	g_iMessageColors++;
	return true;
}

public int SCPSupport_Equip(int client, int id)
{
	return -1;
}

public int SCPSupport_Remove(int client, int id)
{
	return 0;
}

public Action CP_OnChatMessageSendPre(int sender, int reciever, char[] flag, char[] buffer, int maxlength)
{
	#if defined _clientmod_included
	if (CM_IsClientModUser(reciever, true))
		return Plugin_Continue;
	#endif
	StripColorsForNormalClient(buffer, maxlength);
	int colonPos = StrContains(buffer, " : ");
	if (colonPos != -1)
	{
		char namePart[MAXLENGTH_NAME * 2];
		strcopy(namePart, sizeof(namePart), buffer);
		namePart[colonPos] = '\0';
		char fixedName[MAXLENGTH_NAME * 2];
		FormatEx(fixedName, sizeof(fixedName), "{teamcolor}%s", namePart);
		char messagePart[MAXLENGTH_BUFFER];
		strcopy(messagePart, sizeof(messagePart), buffer[colonPos]);
		FormatEx(buffer, maxlength, "%s%s", fixedName, messagePart);
	}
	return Plugin_Changed;
}

public Action CP_OnChatMessage(int &author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool &processcolors, bool &removecolors)
{
	int m_iEquippedNameTag = Store_GetEquippedItem(author, "nametag");
	int m_iEquippedNameColor = Store_GetEquippedItem(author, "namecolor");
	int m_iEquippedMsgColor = Store_GetEquippedItem(author, "msgcolor");
	if (m_iEquippedNameTag < 0 && m_iEquippedNameColor < 0 && m_iEquippedMsgColor < 0)
		return Plugin_Continue;

	char m_szName[MAXLENGTH_NAME * 2];
	char m_szNameTag[MAXLENGTH_NAME] = "";
	char m_szNameColor[32] = "";

	if (m_iEquippedNameTag >= 0)
	{
		int idx = Store_GetDataIndex(m_iEquippedNameTag);
		strcopy(m_szNameTag, sizeof(m_szNameTag), g_szNameTags[idx]);
	}
	if (m_iEquippedNameColor >= 0)
	{
		int idx = Store_GetDataIndex(m_iEquippedNameColor);
		strcopy(m_szNameColor, sizeof(m_szNameColor), g_szNameColors[idx]);
	}
	Format(m_szName, sizeof(m_szName), "%s%s%s",
		m_szNameTag,
		strlen(m_szNameColor) > 0 ? m_szNameColor : "{teamcolor}",
		name);
	strcopy(name, MAXLENGTH_NAME, m_szName);

	if (m_iEquippedMsgColor >= 0)
	{
		int idx = Store_GetDataIndex(m_iEquippedMsgColor);
		Format(message, MAXLENGTH_BUFFER, "%s%s", g_szMessageColors[idx], message);
	}
	processcolors = true;
	removecolors = false;
	return Plugin_Changed;
}
#endif

#else
public void CPSupport_OnPluginStart(){} public void SCPSupport_OnMapStart(){} public void SCPSupport_Reset(){} public void SCPSupport_Equip(){} public void SCPSupport_Remove(){}
#endif
