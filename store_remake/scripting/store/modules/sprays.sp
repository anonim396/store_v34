#if defined STANDALONE_BUILD
#include <sourcemod>
#include <sdktools>

#include <store>
#include <zephstocks>
#endif

// Массивы для хранения путей к спреям, их прекеширования и кэширования для игроков
char g_szSprays[STORE_MAX_ITEMS][PLATFORM_MAX_PATH];
int g_iSprayPrecache[STORE_MAX_ITEMS] = {-1, ...};
int g_iSprayCache[MAXPLAYERS + 1] = {-1, ...};
int g_iSprayLimit[MAXPLAYERS + 1] = {0, ...};
int g_iSprays = 0;

// Переменные для хранения значений консольных переменных
ConVar g_cvarSprayLimit;
ConVar g_cvarSprayDistance;

#if defined STANDALONE_BUILD
public void OnPluginStart()
#else
public void Sprays_OnPluginStart()
#endif
{
	// Регистрация консольных переменных
	g_cvarSprayLimit = CreateConVar("sm_store_spray_limit", "30", "Количество секунд между использованием спреев", FCVAR_NONE, true, 0.0);
	g_cvarSprayDistance = CreateConVar("sm_store_spray_distance", "115", "Расстояние от стены для нанесения спрея", FCVAR_NONE, true, 0.0);
}

public void Sprays_OnMapStart()
{
	char m_szDecal[PLATFORM_MAX_PATH];

	// Прекеширование спреев и добавление их в таблицу загрузок
	for (int i = 0; i < g_iSprays; ++i)
	{
		if (FileExists(g_szSprays[i], true))
		{
			strcopy(m_szDecal, sizeof(m_szDecal), g_szSprays[i][10]);
			PrintToServer("%s (%d)", m_szDecal, strlen(m_szDecal) - 4);
			m_szDecal[strlen(m_szDecal) - 4] = 0;

			g_iSprayPrecache[i] = PrecacheDecal(m_szDecal, true);
			AddFileToDownloadsTable(g_szSprays[i]);
		}
	}

	// Прекеширование звука спрея
	PrecacheSound("player/sprayer.wav", true);
}

public void Sprays_OnClientConnected(int client)
{
	// Сброс кэша спрея при подключении игрока
	g_iSprayCache[client] = -1;
}

public void Sprays_OnPlayerRunCmd(int client, int buttons)
{
	// Проверка, нажал ли игрок кнопку USE и может ли использовать спрей
	if ((buttons & IN_USE) && g_iSprayCache[client] != -1 && g_iSprayLimit[client] <= GetTime())
	{
		Sprays_Create(client);
	}
}

public void Sprays_Reset()
{
	// Сброс количества спреев
	g_iSprays = 0;
}

public bool Sprays_Config(KeyValues kv, int itemid)
{
	// Загрузка конфигурации спрея из файла
	Store_SetDataIndex(itemid, g_iSprays);
	kv.GetString("material", g_szSprays[g_iSprays], sizeof(g_szSprays[]));

	if (FileExists(g_szSprays[g_iSprays], true))
	{
		g_iSprays++;
		return true;
	}
	return false;
}

public int Sprays_Equip(int client, int id)
{
	// Установка спрея для игрока
	int m_iData = Store_GetDataIndex(id);
	g_iSprayCache[client] = m_iData;
	return 0;
}

public int Sprays_Remove(int client)
{
	// Удаление спрея у игрока
	g_iSprayCache[client] = -1;
	return 0;
}

public void Sprays_Create(int client)
{
	// Проверка, жив ли игрок
	if (!IsPlayerAlive(client))
		return;

	float m_flEye[3];
	GetClientEyePosition(client, m_flEye);

	float m_flView[3];
	GetPlayerEyeViewPoint(client, m_flView);

	// Проверка расстояния до стены
	if (GetVectorDistance(m_flEye, m_flView) > g_cvarSprayDistance.FloatValue)
		return;

	// Создание спрея
	TE_Start("World Decal");
	TE_WriteVector("m_vecOrigin", m_flView);
	TE_WriteNum("m_nIndex", g_iSprayPrecache[g_iSprayCache[client]]);
	TE_SendToAll();

	// Воспроизведение звука спрея
	EmitSoundToAll("player/sprayer.wav", client, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, 0.6);

	// Установка лимита времени для следующего использования спрея
	g_iSprayLimit[client] = GetTime() + g_cvarSprayLimit.IntValue;
}

stock void GetPlayerEyeViewPoint(int client, float m_fPosition[3])
{
	if (!client)
    {
        return;
    }

    int size = g_hArrayMaterials.Length;
    if (!size)
    {
        return;
    }

    float bulletDestination[3];
    bulletDestination[0] = event.GetFloat("x");
    bulletDestination[1] = event.GetFloat("y");
    bulletDestination[2] = event.GetFloat("z");

    int index = g_hArrayMaterials.Get(Math_GetRandomInt(0, size - 1));
    TE_SetupWorldDecal(bulletDestination, index);
    TE_SendToAll();
}

stock void TE_SetupWorldDecal(const float vecOrigin[3], int index)
{
    TE_Start("World Decal");
    TE_WriteVector("m_vecOrigin", vecOrigin);
    TE_WriteNum("m_nIndex", index);
}