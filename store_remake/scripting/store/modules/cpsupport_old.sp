// Если Chat Processor не найден, выдаем ошибку компиляции
#if !defined _chat_processor_included
	#error "This module requires Chat Processor. Please install it from: https://github.com/anonim396/chat_processor_v34"
#endif

char g_szNameTags[STORE_MAX_ITEMS][MAXLENGTH_NAME];
char g_szNameColors[STORE_MAX_ITEMS][32];
char g_szMessageColors[STORE_MAX_ITEMS][32];

int g_iNameTags = 0;
int g_iNameColors = 0;
int g_iMessageColors = 0;

public void CPSupport_OnPluginStart()
{	
	if(FindPluginByFile("chat-processor.smx") == null)
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

public Action CP_OnChatMessage(int &author, ArrayList recipients, char[] flagstring, char[] name, char[] message, bool &processcolors, bool &removecolors)
{
	int m_iEquippedNameTag = Store_GetEquippedItem(author, "nametag");
	int m_iEquippedNameColor = Store_GetEquippedItem(author, "namecolor");
	int m_iEquippedMsgColor = Store_GetEquippedItem(author, "msgcolor");

	if (m_iEquippedNameTag < 0 && m_iEquippedNameColor < 0 && m_iEquippedMsgColor < 0)
		return Plugin_Continue;

	#if defined _clientmod_included
		bool bAuthorIsCM = CM_IsClientModUser(author);
	#else
		bool bAuthorIsCM = false;
	#endif

	// Если автор НЕ ClientMod (Old v34), то у него нет hex-цветов
	if (!bAuthorIsCM)
	{
		char m_szName[MAXLENGTH_NAME * 2];
		char m_szNameTag[MAXLENGTH_NAME];
		char m_szNameColor[32];
		
		// ---------- ИМЕННОЙ ТЕГ ----------
		if (m_iEquippedNameTag >= 0)
		{
			int idx = Store_GetDataIndex(m_iEquippedNameTag);
			strcopy(m_szNameTag, sizeof(m_szNameTag), g_szNameTags[idx]);
			MC_RemoveTags(m_szNameTag, sizeof(m_szNameTag));// Удаляем HEX
		}
		
		// ---------- ЦВЕТ ИМЕНИ ----------
		if (m_iEquippedNameColor >= 0)
		{
			int idx = Store_GetDataIndex(m_iEquippedNameColor);
			strcopy(m_szNameColor, sizeof(m_szNameColor), g_szNameColors[idx]);
			MC_RemoveTags(m_szNameColor, sizeof(m_szNameColor));
		}
		
		Format(m_szName, sizeof(m_szName),
			"%s%s%s",
			m_szNameTag,
			strlen(m_szNameColor) > 0 ? m_szNameColor : "{teamcolor}",
			name
		);
		
		strcopy(name, MAXLENGTH_NAME, m_szName);
		
		// ---------- ЦВЕТ СООБЩЕНИЯ ----------
		if (m_iEquippedMsgColor >= 0)
		{
			int idx = Store_GetDataIndex(m_iEquippedMsgColor);
			char clearColor[32];
			strcopy(clearColor, sizeof(clearColor), g_szMessageColors[idx]);
			MC_RemoveTags(clearColor, sizeof(clearColor));
			
			Format(message, MAXLENGTH_BUFFER, "%s%s", clearColor, message);
		}
		
		return Plugin_Changed;
	}

	// Автор - ClientMod, проверяем получателей
	
	// Считаем получателей разных типов
	int cmCount = 0;
	int normalCount = 0;
	
	#if defined _clientmod_included
	for (int i = 0; i < recipients.Length; i++)
	{
		int userid = recipients.Get(i);
		int client = GetClientOfUserId(userid);
		
		if (client > 0 && IsClientInGame(client))
		{
			if (CM_IsClientModUser(client))
				cmCount++;
			else
				normalCount++;
		}
	}
	#endif
	
	// ВАЖНО: Мы не можем отправить разные сообщения разным получателям
	// Поэтому используем компромисс:
	// 1. Если есть обычные получатели -> Удаляем hex для ВСЕХ
	// 2. Если все получатели ClientMod -> Оставляем hex для ВСЕХ
	
	if (normalCount > 0)
	{
		// Есть обычные получатели -> удаляем hex для всех
		
		char m_szName[MAXLENGTH_NAME * 2];
		char m_szNameTag[MAXLENGTH_NAME];
		char m_szNameColor[32];
		
		// ---------- ИМЕННОЙ ТЕГ ----------
		if (m_iEquippedNameTag >= 0)
		{
			int idx = Store_GetDataIndex(m_iEquippedNameTag);
			strcopy(m_szNameTag, sizeof(m_szNameTag), g_szNameTags[idx]);
			MC_RemoveTags(m_szNameTag, sizeof(m_szNameTag));
		}
		
		// ---------- ЦВЕТ ИМЕНИ ----------
		if (m_iEquippedNameColor >= 0)
		{
			int idx = Store_GetDataIndex(m_iEquippedNameColor);
			strcopy(m_szNameColor, sizeof(m_szNameColor), g_szNameColors[idx]);
			MC_RemoveTags(m_szNameColor, sizeof(m_szNameColor));
		}
		
		Format(m_szName, sizeof(m_szName),
			"%s%s%s",
			m_szNameTag,
			strlen(m_szNameColor) > 0 ? m_szNameColor : "{teamcolor}",
			name
		);
		
		strcopy(name, MAXLENGTH_NAME, m_szName);
		
		// ---------- ЦВЕТ СООБЩЕНИЯ ----------
		if (m_iEquippedMsgColor >= 0)
		{
			int idx = Store_GetDataIndex(m_iEquippedMsgColor);
			char clearColor[32];
			strcopy(clearColor, sizeof(clearColor), g_szMessageColors[idx]);
			MC_RemoveTags(clearColor, sizeof(clearColor));
			
			// Также удаляем hex из сообщения автора
			char cleanMessage[MAXLENGTH_BUFFER];
			strcopy(cleanMessage, sizeof(cleanMessage), message);
			MC_RemoveTags(cleanMessage, sizeof(cleanMessage));
			
			Format(message, MAXLENGTH_BUFFER, "%s%s", clearColor, cleanMessage);
		}
		else
		{
			// Удаляем hex из сообщения автора
			MC_RemoveTags(message, MAXLENGTH_BUFFER);
		}
		
		return Plugin_Changed;
	}
	else
	{
		// Все получатели - ClientMod -> оставляем hex
		
		char m_szName[MAXLENGTH_NAME * 2];
		char m_szNameTag[MAXLENGTH_NAME];
		char m_szNameColor[32];
		
		// ---------- ИМЕННОЙ ТЕГ ----------
		if (m_iEquippedNameTag >= 0)
		{
			int idx = Store_GetDataIndex(m_iEquippedNameTag);
			strcopy(m_szNameTag, sizeof(m_szNameTag), g_szNameTags[idx]);
		}
		
		// ---------- ЦВЕТ ИМЕНИ ----------
		if (m_iEquippedNameColor >= 0)
		{
			int idx = Store_GetDataIndex(m_iEquippedNameColor);
			strcopy(m_szNameColor, sizeof(m_szNameColor), g_szNameColors[idx]);
		}
		
		Format(m_szName, sizeof(m_szName),
			"%s%s%s",
			m_szNameTag,
			strlen(m_szNameColor) > 0 ? m_szNameColor : "{teamcolor}",
			name
		);
		
		strcopy(name, MAXLENGTH_NAME, m_szName);
		
		// ---------- ЦВЕТ СООБЩЕНИЯ ----------
		if (m_iEquippedMsgColor >= 0)
		{
			int idx = Store_GetDataIndex(m_iEquippedMsgColor);
			Format(message, MAXLENGTH_BUFFER, "%s%s", g_szMessageColors[idx], message);
		}

		return Plugin_Changed;
	}
}