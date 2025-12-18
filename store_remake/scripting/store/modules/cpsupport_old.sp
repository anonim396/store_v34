// Если Chat Processor не найден, выдаем предупреждение
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

#if !defined _clientmod_included
stock void MC_RemoveTags(char[] message, int maxlen)
{
	if (message[0] == '\0' || maxlen <= 0)
		return;
	
	// Простая заглушка, которая не делает ничего
	// или можно реализовать базовое удаление тегов, если нужно
}
#endif

// НОВАЯ ФУНКЦИЯ: Удаляет HEX цветовые коды (\x07RRGGBB и \x08RRGGBBAA)
stock void RemoveHexColors(char[] message, int maxlen)
{
	if (message[0] == '\0' || maxlen <= 0)
		return;
	
	char buffer[MAXLENGTH_BUFFER];
	int buffer_pos = 0;
	int len = strlen(message);
	
	for (int i = 0; i < len && buffer_pos < maxlen - 1; i++)
	{
		// Проверяем на HEX цвет (\x07RRGGBB или \x08RRGGBBAA)
		if (message[i] == '\x07' || message[i] == '\x08')
		{
			// Пропускаем 7 символов после \x07 (6 hex цифр) или 9 после \x08 (8 hex цифр)
			if (message[i] == '\x07')
			{
				// Пропускаем 6 hex символов
				i += 6;
				if (i >= len) break;
			}
			else if (message[i] == '\x08')
			{
				// Пропускаем 8 hex символов
				i += 8;
				if (i >= len) break;
			}
			continue;
		}
		
		// Копируем символ в буфер
		buffer[buffer_pos++] = message[i];
	}
	
	buffer[buffer_pos] = '\0';
	strcopy(message, maxlen, buffer);
}

// Функция для удаления всех цветовых кодов для обычных клиентов
stock void RemoveAllColorsForNormalClient(char[] message, int maxlen)
{
	// Сначала удаляем HEX цвета
	RemoveHexColors(message, maxlen);
	
	// Затем удаляем стандартные цветовые теги
	#if defined _clientmod_included
	MC_RemoveTags(message, maxlen);
	#else
	// Если ClientMod не подключен, просто удаляем {} теги
	char buffer[MAXLENGTH_BUFFER];
	int buffer_pos = 0;
	int len = strlen(message);
	bool in_tag = false;
	
	for (int i = 0; i < len && buffer_pos < maxlen - 1; i++)
	{
		if (message[i] == '{')
		{
			in_tag = true;
			continue;
		}
		else if (message[i] == '}' && in_tag)
		{
			in_tag = false;
			continue;
		}
		
		if (!in_tag)
		{
			buffer[buffer_pos++] = message[i];
		}
	}
	
	buffer[buffer_pos] = '\0';
	strcopy(message, maxlen, buffer);
	#endif
	
	/* Также удаляем оставшиеся управляющие символы цветов
	ReplaceString(message, maxlen, "\x01", ""); // Default
	ReplaceString(message, maxlen, "\x02", ""); // Dark Red
	ReplaceString(message, maxlen, "\x03", ""); // Light Green/Team Color
	ReplaceString(message, maxlen, "\x04", ""); // Dark Green
	ReplaceString(message, maxlen, "\x05", ""); // Light Green
	ReplaceString(message, maxlen, "\x06", ""); // Green
	ReplaceString(message, maxlen, "\x07", ""); // Red
	ReplaceString(message, maxlen, "\x08", ""); // Grey
	ReplaceString(message, maxlen, "\x09", ""); // Yellow
	ReplaceString(message, maxlen, "\x0A", ""); // Light Grey
	ReplaceString(message, maxlen, "\x0B", ""); // Blue
	ReplaceString(message, maxlen, "\x0C", ""); // Dark Blue
	ReplaceString(message, maxlen, "\x0E", ""); // Light Red
	ReplaceString(message, maxlen, "\x0F", ""); // Purple
	*/
}

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

public Action CP_OnChatMessageSendPre(int sender, int reciever, char[] flag, char[] buffer, int maxlength)
{
	#if defined _clientmod_included
	// Если получатель - ClientMod, не трогаем сообщение
	if (CM_IsClientModUser(reciever, true))
	{
		return Plugin_Continue;
	}
	#endif
	
	// Для обычных клиентов просто удаляем все цвета
	// Это удалит и HEX цвета, и цветные теги
	RemoveAllColorsForNormalClient(buffer, maxlength);
	
	// Теперь нужно добавить teamcolor к имени
	// Ищем разделитель
	int colonPos = StrContains(buffer, " : ");
	if (colonPos != -1)
	{
		// Извлекаем чистое имя (без тегов)
		char namePart[MAXLENGTH_NAME * 2];
		strcopy(namePart, sizeof(namePart), buffer);
		namePart[colonPos] = '\0';
		
		// Добавляем teamcolor к имени
		char fixedName[MAXLENGTH_NAME * 2];
		FormatEx(fixedName, sizeof(fixedName), "{teamcolor}%s", namePart);
		
		// Часть с сообщением
		char messagePart[MAXLENGTH_BUFFER];
		strcopy(messagePart, sizeof(messagePart), buffer[colonPos]);
		
		// Объединяем
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

	// Формируем имя с цветом (для ClientMod получателей)
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
		name
	);
	
	strcopy(name, MAXLENGTH_NAME, m_szName);
	
	// Цвет сообщения
	if (m_iEquippedMsgColor >= 0)
	{
		int idx = Store_GetDataIndex(m_iEquippedMsgColor);
		
		// CP_OnChatMessageSendPre удалит HEX для обычных получателей
		Format(message, MAXLENGTH_BUFFER, "%s%s", g_szMessageColors[idx], message);
	}
	
	processcolors = true;
	removecolors = false;
	
	return Plugin_Changed;
}
#endif