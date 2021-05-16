#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <multicolors>
#include <zombiereloaded>
#include <allpropshealthmore>
#pragma tabsize 0

#define PL_VERSION "1.7.7.1"
#define PREFIX "[ZProps]"
#define INFO "[INFO]"
#define MAXENTITIES 2048
#define WARNING "[WARNING]"
#define MAXIMUM_PROP_CONFIGS 128
#define MAXIMUM_PROP_PLAYER 64

/////OWNER PROP/////
//#define FSOLID_COLLIDE_WITH_OWNER 0x0400	// Can hit our m_hOwner
// FSOLID_MAX_BITS = 11
////////////////////////

public Plugin:myinfo =
{
	name = "Prop Health(ZR mode)",
	author = "Roy (Christian Deacon) & Doshik (Owner system)",
	description = "Props now have health + owner system! (Thanks: Killik, Ire, Grey83, tonline_kms65_1)",
	version = PL_VERSION,
	url = "GFLClan.com && https://steamcommunity.com/id/doshikplayer"
};

enum struct Props
{
	float fHealth;
	float fMultiplier;
	float fMaxHealth;
	int iOwner;
}

enum struct Player
{
	int iClientPropsOwned[MAXIMUM_PROP_PLAYER];
	int iCountProps;
}

// ConVars
Handle g_hConfigPath = INVALID_HANDLE,
	g_hDefaultHealth = INVALID_HANDLE,
	g_hDefaultMultiplier = INVALID_HANDLE,
	g_hColorRed = INVALID_HANDLE,
	g_hColorGreen = INVALID_HANDLE,
	g_hColorBlue = INVALID_HANDLE,
	g_hColorAlpha = INVALID_HANDLE,
	g_hPrint = INVALID_HANDLE,
	g_hCostRepairTools = INVALID_HANDLE,
	g_hStatusRepairTools = INVALID_HANDLE,
	g_hDebug = INVALID_HANDLE,
	HudMessage,
	g_hTimer = INVALID_HANDLE,
	g_hChangeColorHp = INVALID_HANDLE,
//zprops
	g_hEnabled = INVALID_HANDLE,
	g_hCreditsMax = INVALID_HANDLE,
	g_hCreditsConnect = INVALID_HANDLE,
	g_hCreditsHuman = INVALID_HANDLE,
	g_hCreditsZombie = INVALID_HANDLE,
	g_hCreditsInfect = INVALID_HANDLE,
	g_hCreditsKill = INVALID_HANDLE,
	g_hCreditsRound = INVALID_HANDLE,
	g_hLocation = INVALID_HANDLE,
	g_hRoundStartRestrict = INVALID_HANDLE,
	g_hRoundStartRestrictTime = INVALID_HANDLE;
	
//new Handle:g_hPrintMessage = INVALID_HANDLE;

int g_iCostRepairTools,
	g_iPropCosts[MAXIMUM_PROP_CONFIGS],
	g_iCredits[MAXPLAYERS + 1],
	g_iNumProps,
	g_iCreditsMax,
	g_iCreditsConnect,
	g_iCreditsHuman,
	g_iCreditsZombie,
	g_iCreditsInfect,
	g_iCreditsKill,
	g_iCreditsRound,
	g_iUnique,
	g_iColorRed,
	g_iColorGreen,
	g_iColorBlue,
	g_iColorAlpha,
	g_iRoundStartTime;

// ConVar Values
float g_iDefaultHealth, 
	g_fDefaultMultiplier;
//new String:g_sPrintMessage[256];
char admsteam[16],
	plysteam[16],
	g_sConfigPath[PLATFORM_MAX_PATH],
	sWeapon[32],
	Clientname[32];

bool zbout_run = false,
	g_bEnabled,
	g_bDebug,
	g_bPrint,
	g_bChangeColorHp,
	g_bStatusRepairTools,
	g_bInfection = false,
	g_bLateLoad,
	g_bGivenCredits[MAXPLAYERS +1] = {false, ...},
	g_bRoundStartRestriction;

// Other Variables
Props PropsInfo[MAXENTITIES + 1];
Player PlayerInfo[MAXPLAYERS + 1];
ArrayList ClientsRepairTools;

new String:g_sLogFile[PLATFORM_MAX_PATH],
	String:g_sLogDel[PLATFORM_MAX_PATH],
	String:g_sLogRes[PLATFORM_MAX_PATH],
	String:g_sLogSetHP[PLATFORM_MAX_PATH],
	String:g_sPropPaths[MAXIMUM_PROP_CONFIGS][PLATFORM_MAX_PATH],
	String:g_sPropTypes[MAXIMUM_PROP_CONFIGS][32],
	String:g_sPropNames[MAXIMUM_PROP_CONFIGS][64],
	String:g_sLocation[PLATFORM_MAX_PATH];

char g_Str[] = "[ZPROPS] Authors of the plugin Roy and Doshik.                                   Special Thanks: Killik, Ire, Grey83, tonline_kms65_1                                   ";
new g_CurrentIndex, g_MaxIndex;

public OnPluginStart()
{
	ClientsRepairTools = new ArrayList(ByteCountToCells(64));
	LoadTranslations("allpropshealth.phrases");
	// ConVars
	CreateConVar("sm_ph_version", PL_VERSION, "Prop Health's version.");
	
	g_hConfigPath = CreateConVar("sm_ph_config_path", "configs/prophealth.props.cfg", "The path to the Prop Health config.");
	HookConVarChange(g_hConfigPath, CVarChanged);
	
	g_hDefaultHealth = CreateConVar("sm_ph_default_health", "1337", "A prop's default health if not defined in the config file. -1 = Doesn't break.");
	HookConVarChange(g_hDefaultHealth, CVarChanged);	
	
	g_hDefaultMultiplier = CreateConVar("sm_ph_default_multiplier", "0.00", "Default multiplier based on the player count (for zombies/humans). Default: 65 * 5 (65 damage by right-click knife with 5 hits)");
	HookConVarChange(g_hDefaultMultiplier, CVarChanged);	
	
	g_hColorRed = CreateConVar("sm_ph_colorRed", "-1", "If a prop has a color, set it to this color. -1 = no color.");
	HookConVarChange(g_hColorRed, CVarChanged);

	g_hColorGreen = CreateConVar("sm_ph_colorGreen", "-1", "If a prop has a color, set it to this color. -1 = no color.");
	HookConVarChange(g_hColorGreen, CVarChanged);

	g_hColorBlue = CreateConVar("sm_ph_colorBlue", "-1", "If a prop has a color, set it to this color. -1 = no color.");
	HookConVarChange(g_hColorBlue, CVarChanged);

	g_hColorAlpha = CreateConVar("sm_ph_colorAlpha", "-1", "If a prop has a color, set it to this color. -1 = no color.");
	HookConVarChange(g_hColorAlpha, CVarChanged);

	g_hChangeColorHp = CreateConVar("sm_ph_colorhp", "1", "Change the color of the prop according to its health (0 - Disable, 1 - Enable)");
	HookConVarChange(g_hChangeColorHp, CVarChanged);	
	
	g_hPrint = CreateConVar("sm_ph_print", "1", "Print the prop's health when damaged to the attacker's chat?");
	HookConVarChange(g_hPrint, CVarChanged);		
	
	//g_hPrintMessage = CreateConVar("sm_ph_print_message", "Prop Health: %i", "The message to send to the client. Multicolors supported only for PrintToChat. %i = health value. %N = name owner");
	//HookConVarChange(g_hPrintMessage, CVarChanged);	
	
	g_hDebug = CreateConVar("sm_ph_debug", "1", "Enable debugging (logging will go to logs/prophealth-debug.log).");
	HookConVarChange(g_hDebug, CVarChanged);
	
	g_hCostRepairTools = CreateConVar("sm_ph_repair_tools", "5000", "Cost for repair tools.");
	HookConVarChange(g_hCostRepairTools, CVarChanged);

	g_hStatusRepairTools = CreateConVar("sm_ph_status_repair_tools", "1", "Enable/Disable reapir tools. (0 - Disable, 1 - Enable)");
	HookConVarChange(g_hStatusRepairTools, CVarChanged);

	LoadTranslations("common.phrases.txt");
	
	g_hEnabled = CreateConVar("zprop_enabled", "1", "Disable or enable plugin (1: Enabled 0: Disabled)");
	HookConVarChange(g_hEnabled, CVarChanged);
	g_hCreditsMax = CreateConVar("zprop_credits_max", "15", "Max credits that can be attained (0: No limit).");
	HookConVarChange(g_hCreditsMax, CVarChanged);
	g_hCreditsConnect = CreateConVar("zprop_credits_connect", "4", "The number of free credits a player received when they join the game.");
	HookConVarChange(g_hCreditsConnect, CVarChanged);
	g_hCreditsHuman = CreateConVar("zprop_credits_spawn_human", "1", "The number of free credits when spawning as a Human.");
	HookConVarChange(g_hCreditsHuman, CVarChanged);
	g_hCreditsZombie = CreateConVar("zprop_credits_spawn_zombie", "1", "The number of free credits when spawning as a Zombie.");
	HookConVarChange(g_hCreditsZombie, CVarChanged);
	g_hCreditsInfect = CreateConVar("zprop_credits_infect", "1", "The number of credits given for infecting a human as zombie.");
	HookConVarChange(g_hCreditsInfect, CVarChanged);
	g_hCreditsKill = CreateConVar("zprop_credits_kill", "5", "The number of credits given for killing a zombie as human.");
	HookConVarChange(g_hCreditsKill, CVarChanged);
	g_hCreditsRound = CreateConVar("zprop_credits_roundstart", "2", "The number of free credits given on start of the round.");
	HookConVarChange(g_hCreditsRound, CVarChanged);
	g_hRoundStartRestrict = CreateConVar("zprop_roundstart", "1", "Disable zprops during round start.");
	HookConVarChange(g_hRoundStartRestrict, CVarChanged);
	g_hRoundStartRestrictTime = CreateConVar("zprop_roundstarttime", "30.0", "Enable zprops how many seconds after round start.");
	HookConVarChange(g_hRoundStartRestrictTime, CVarChanged);
	g_hLocation = CreateConVar("zprop_config", "configs/zprop.defines.txt", "The desired configuration file to use.");
	HookConVarChange(g_hLocation, CVarChanged);
	
	AutoExecConfig(true, "zprop");
	AutoExecConfig(true, "plugin.prop-health");
	HudMessage = CreateHudSynchronizer();

	//Events
	//HookEvent("round_start", OnRoundStart, EventHookMode_PostNoCopy);
	HookEvent("player_death", OnPlayerDeath, EventHookMode_Pre);
	HookEvent("player_spawn", Event_OnPlayerSpawn);
	HookEvent("player_team", Event_OnPlayerTeam);
	HookEvent("round_start", Event_OnRoundStart);
	HookEvent("round_start", Event_OnRoundEnd);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
	
	// Commands
	RegConsoleCmd("sm_getpropinfo", Command_GetPropInfo);
	RegConsoleCmd("sm_zabout", Command_ZAbout);
	RegConsoleCmd("sm_zprops", Command_Zprops);
	RegConsoleCmd("sm_zprop", Command_Zprops);
	RegConsoleCmd("sm_props", Command_Zprops);
	RegConsoleCmd("sm_prop", Command_Zprops);
	RegConsoleCmd("sm_repair", Command_RepairProp);
	RegAdminCmd("sm_sethpprop", Command_SetHpProp, ADMFLAG_RCON, "[Debug] Allows an administrator to set health any prop.");
	RegAdminCmd("sm_deleteprop", Command_DeleteProp, ADMFLAG_SLAY, "Allows an administrator to delete any props.");
	RegAdminCmd("sm_resetprop", Command_ResetProp, ADMFLAG_SLAY, "Allows an administrator to reset any props.");
	RegAdminCmd("sm_getprops", Command_GetPropsFromPlayer, ADMFLAG_SLAY, "[Debug] Allows an developer get array list any players.");
	RegAdminCmd("sm_zprop_credits", Command_Credits, ADMFLAG_CONVARS, "Gives player credits for zprops");
}

public CVarChanged(Handle:hCVar, const String:sOldV[], const String:sNewV[])
{
	OnConfigsExecuted();
}

public OnConfigsExecuted()
{
	GetConVarString(g_hConfigPath, g_sConfigPath, sizeof(g_sConfigPath));
	g_iDefaultHealth = GetConVarFloat(g_hDefaultHealth);
	g_fDefaultMultiplier = GetConVarFloat(g_hDefaultMultiplier);
	g_iColorRed = GetConVarInt(g_hColorRed);
	g_iColorGreen = GetConVarInt(g_hColorGreen);
	g_iColorBlue = GetConVarInt(g_hColorBlue);
	g_iColorAlpha = GetConVarInt(g_hColorAlpha);
	g_bChangeColorHp = GetConVarBool(g_hChangeColorHp);
	g_bPrint = GetConVarBool(g_hPrint);
	//GetConVarString(g_hPrintMessage, g_sPrintMessage, sizeof(g_sPrintMessage));
	g_bDebug = GetConVarBool(g_hDebug);
	g_iCostRepairTools = GetConVarInt(g_hCostRepairTools);
	g_bStatusRepairTools = GetConVarBool(g_hStatusRepairTools);
	
	BuildPath(Path_SM, g_sLogFile, sizeof(g_sLogFile), "logs/zprops/prophealth-debug.log");
	BuildPath(Path_SM, g_sLogDel, sizeof(g_sLogDel), "logs/zprops/zprops-del.log");
	BuildPath(Path_SM, g_sLogRes, sizeof(g_sLogRes), "logs/zprops/zprops-res.log");
	BuildPath(Path_SM, g_sLogSetHP, sizeof(g_sLogSetHP), "logs/zprops/zprops-set-hp.log");

	g_bEnabled = GetConVarBool(g_hEnabled);
	g_iCreditsMax = GetConVarInt(g_hCreditsMax);
	g_iCreditsConnect = GetConVarInt(g_hCreditsConnect);
	g_iCreditsHuman = GetConVarInt(g_hCreditsHuman);
	g_iCreditsZombie = GetConVarInt(g_hCreditsZombie);
	g_iCreditsInfect = GetConVarInt(g_hCreditsInfect);
	g_iCreditsKill = GetConVarInt(g_hCreditsKill);
	g_iCreditsRound = GetConVarInt(g_hCreditsRound);
	g_iCreditsConnect = GetConVarInt(g_hCreditsConnect);
	GetConVarString(g_hLocation, g_sLocation, sizeof(g_sLocation));
	g_bRoundStartRestriction = GetConVarBool(g_hRoundStartRestrict);

	for (new i = 1; i <= MaxClients; i++)
	{
		if(IsClientInGame(i))
		{
			if(ZRIsClientValid(i))
			{
				g_iCredits[i] = g_iCreditsConnect;
			}
		}
	}

	g_bLateLoad = false;

	CheckConfig();
}

public OnMapStart()
{
	//PrecacheSound("physics/metal/metal_box_break1.wav");
	//PrecacheSound("physics/metal/metal_box_break2.wav");
	g_bInfection = false;
}

CheckConfig()
{
	g_iNumProps = 0;
	decl String:sPath[PLATFORM_MAX_PATH];
	new Handle:hTemp = CreateKeyValues("zprops.defines");
	BuildPath(Path_SM, sPath, sizeof(sPath), g_sLocation);
	if (!FileToKeyValues(hTemp, sPath))
		SetFailState("[ZPROP] - Configuration '%s' missing from server!", g_sLocation);
	else
	{
		KvGotoFirstSubKey(hTemp);
		do
		{
			KvGetSectionName(hTemp, g_sPropNames[g_iNumProps], sizeof(g_sPropNames[]));
			KvGetString(hTemp, "model", g_sPropPaths[g_iNumProps], sizeof(g_sPropPaths[]));
			KvGetString(hTemp, "type", g_sPropTypes[g_iNumProps], sizeof(g_sPropTypes[]), "prop_physics");
			g_iPropCosts[g_iNumProps] = KvGetNum(hTemp, "cost");

			PrecacheModel(g_sPropPaths[g_iNumProps]);
			g_iNumProps++;
		}
		while (KvGotoNextKey(hTemp));
		CloseHandle(hTemp);
	}
}

public Action:Event_OnRoundStart(Handle:event, const String:name[], bool:dontBroadcast)
{
	ClientsRepairTools.Clear();
	g_iUnique = 0;
	g_bInfection = false;

	for(new i = 1; i <= MaxClients; i++)
	{
		if(!ZRIsClientValid(i))
		{
			continue;
		}
			
		CheckCredits(i, g_iCreditsRound);
	}
	
	if(g_bRoundStartRestriction)
	{
		g_iRoundStartTime = GetTime() + GetConVarInt(g_hRoundStartRestrictTime);
		g_bRoundStartRestriction = true;
		CreateTimer(GetConVarFloat(g_hRoundStartRestrictTime), ZProp_Timer);
	}
	
	return Plugin_Continue;
}

public Action ZProp_Timer(Handle timer)
{
    g_bRoundStartRestriction = false;
}

public Action:Event_OnRoundEnd(Handle:event, const String:name[], bool:dontBroadcast)
{
	ClientsRepairTools.Clear();
	g_bInfection = false;
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(!ZRIsClientValid(i))
		{
			continue;
		}

		if(PlayerInfo[i].iCountProps != 0)
		{
			RemoveOwnerFromAllProps(i);
		}
			
		if(g_bGivenCredits[i])
		{
			g_bGivenCredits[i] = false;
		}
	}
	
	return Plugin_Continue;
}

public OnClientDisconnect(client)
{
	RemoveOwnerFromAllProps(client);
	g_iCredits[client] = 0;
	g_bGivenCredits[client] = false;
}

public Action:Event_OnPlayerSpawn(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
	if(!ZRIsClientValid(client))
	{
		return Plugin_Continue;
	}

	RemoveOwnerFromAllProps(client);

	if(!g_bInfection || ZR_IsClientHuman(client))
	{
		CheckCredits(client, g_iCreditsHuman);
	}
	return Plugin_Handled;
}

public Action:OnPlayerDeath(Handle:event, const String:name[], bool:dontBroadcast)
{
    new attacker = GetClientOfUserId(GetEventInt(event, "attacker"));
    new target = GetClientOfUserId(GetEventInt(event, "userid"));

    if(g_bDebug)
    {
    	PrintToChatAll("<EVENT> %N is death!", target);
    }

	if(attacker == target)
    {
    	return Plugin_Continue;
    }

    if(!ZRIsClientValid(target) && !ZRIsClientValid(attacker))
    {
    	return Plugin_Continue;
    }

    if(ZRIsClientValid(target))
	{
		if(ZR_GetClientTeam(target) == 3)
		{
			new ClientArrIndex = ClientsRepairTools.FindValue(target);
			if(ClientArrIndex != -1)
			{
				RemoveFromArray(ClientsRepairTools, ClientArrIndex);
				CPrintToChat(target, "%t", "YouLostRepairTools");
			}
			RemoveOwnerFromAllProps(target);
		}
	}

	if(ZRIsClientValid(attacker))
	{
		if(ZR_GetClientTeam(attacker) == 3) //If Human
	    {
			CheckCredits(attacker, g_iCreditsKill);
			if(g_bDebug)
			{
				PrintToChatAll("U GET CREDITS KILL!");
			}
	    }
	}

    return Plugin_Handled;
}

public Action:Event_OnPlayerTeam(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));

	if(!ZRIsClientValid(client))
	{
		return Plugin_Continue;
	}

	if(g_bDebug)
	{
		PrintToChatAll("<EVENT> %N change team (Oldteam: %i) (New Team: %i)!", client, GetEventInt(event, "oldteam"), GetEventInt(event, "team"));
	}

	if(GetEventInt(event, "team") == 0 || GetEventInt(event, "team") == 1)
	{
		RemoveOwnerFromAllProps(client);
	}

	if(GetEventInt(event, "oldteam") == 0)
	{
		g_iCredits[client] = g_iCreditsConnect;
		CPrintToChat(client, "%t%t", "Prefix_Chat", "Phrase_Join");
	}

	return Plugin_Handled;
}

public Action:Event_PlayerDisconnect(Handle:event, const String:name[], bool:dontBroadcast)
{
	new client = GetClientOfUserId(GetEventInt(event, "userid"));
    RemoveOwnerFromAllProps(client);
}

public ZR_OnClientInfected(iClient, iAttacker, bool:motherInfect, bool:respawnOverride, bool:respawn)
{
	if(motherInfect)
	{
		g_bInfection = true;
		if(ZRIsClientValid(iClient))
		{
			RemoveOwnerFromAllProps(iClient);
			if(g_bDebug)
			{
				PrintToChatAll("<EVENT> %N is motherInfect!", iClient);
			}
		}
	}

	if(ZRIsClientValid(iClient))
	{
		RemoveOwnerFromAllProps(iClient);
	}

	if(!ZRIsClientValid(iAttacker))
	{
		return;
	}

	CheckCredits(iAttacker, g_iCreditsInfect);
	if(g_bDebug)
	{
		PrintToChatAll("U GET CREDITS INFECT!");
	}

	//CheckCredits(iClient, g_iCreditsZombie);
	return;
}

public OnEntityCreated(iEnt, const String:sClassname[])
{
	SDKHook(iEnt, SDKHook_SpawnPost, OnEntitySpawneds);
}

public OnEntitySpawneds(iEnt)
{
	if(!IsValidEntity(iEnt))
	{
		return 0;
	}

	if (iEnt > MaxClients)
	{
		decl String:sClassname[MAX_NAME_LENGTH];
		GetEntityClassname(iEnt, sClassname, sizeof(sClassname));

		if (!StrEqual(sClassname, "prop_physics", false) && !StrEqual(sClassname, "prop_physics_override", false) && !StrEqual(sClassname, "prop_physics_multiplayer", false)) 
		{
			return 0;
		}

		decl String:sModelName[PLATFORM_MAX_PATH];
		GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));

		if(StrEqual(sModelName, "models/props_lab/tpplug.mdl", false))
		{
			CreateTimer(0.1, SetLaserOwner, iEnt);
			return 1;
		}

		PropsInfo[iEnt].iOwner = -1;
		PropsInfo[iEnt].fHealth = -1.0;
		PropsInfo[iEnt].fMaxHealth = -1.0;
		PropsInfo[iEnt].fMultiplier = 0.0;
		SetPropHealth(iEnt);


		if (g_bDebug)
		{
			LogToFile(g_sLogFile, "Prop spawned by [ SERVER ]");
		}

		if(ZRIsClientValid(PropsInfo[iEnt].iOwner))
		{
			if(ZR_GetClientTeam(PropsInfo[iEnt].iOwner) != 0)
			{
				GetClientName(PropsInfo[iEnt].iOwner, Clientname, sizeof(Clientname));
				CPrintToChat(PropsInfo[iEnt].iOwner, "%t", "YouSpawnProp", Clientname);
			}
			else
			{
				PropsInfo[iEnt].iOwner = -1;
			}
		}
	}
	return 0;
}

public Action SetLaserOwner(Handle timer, int iEnt)
{
	if(!IsValidEntity(iEnt))
	{
		return Plugin_Continue;
	}

    new laserowner = GetEntPropEnt(iEnt, Prop_Send, "m_PredictableID");
    PropsInfo[iEnt].iOwner = laserowner;
    SetPropHealth(iEnt);
    if (g_bDebug)
	{
		LogToFile(g_sLogFile, "Prop spawned by [ %i ]", PropsInfo[iEnt].iOwner);
	}

	return Plugin_Handled;
}

public Action:Hook_OnTakeDamage(iEnt, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	//new oldteam = GetEntProp(iEnt, Prop_Send, "m_iTeamNum");
	
	if(PropsInfo[iEnt].iOwner <= 0)
	{
		if (g_bDebug)
		{
			LogToFile(g_sLogFile, "Prop %i is SERVER!", iEnt, iAttacker);
		}
	}
	
	if (!iAttacker || iAttacker > MaxClients || !IsClientInGame(iAttacker))
	{
		if (g_bDebug)
		{
			LogToFile(g_sLogFile, "Prop %i returned. Attacker (%i) not valid.", iEnt, iAttacker);
		}
		
		return Plugin_Continue;
	}
	
	if (!IsValidEntity(iEnt) || !IsValidEdict(iEnt))
	{
		if (g_bDebug)
		{
			LogToFile(g_sLogFile, "Prop %i returned. Prop not valid.", iEnt, iAttacker);
		}
		
		return Plugin_Continue;
	}
	
	if (PropsInfo[iEnt].fHealth < 0)
	{
		if (g_bDebug)
		{
			LogToFile(g_sLogFile, "Prop %i returned. Prop health under 0.", iEnt, iAttacker);
		}
		
		return Plugin_Continue;
	}

	////////////////////LOGIC HOOK//////////////////
	if(g_bChangeColorHp)
	{
		SetPropColorHealth(iEnt, float:PropsInfo[iEnt].fHealth, float:PropsInfo[iEnt].fMaxHealth);
	}

	if(PropsInfo[iEnt].iOwner <= 0) //Если серверный проп
	{
		if (g_bDebug)
		{
			PrintToChat(iAttacker, "HP: %0.1f MaxHP: %0.1f", PropsInfo[iEnt].fHealth, PropsInfo[iEnt].fMaxHealth);
			LogToFile(g_sLogFile, "Prop %i damaged! Attacker (%i) | OWNER ( SERVER/CONSOLE ) [%i]", iEnt, iAttacker, PropsInfo[iEnt].iOwner);
		}
	}
	else
	{
		if(g_bDebug)
		{
			PrintToChat(iAttacker, "HP: %0.1f MaxHP: %0.1f", PropsInfo[iEnt].fHealth, PropsInfo[iEnt].fMaxHealth);
		}

		if(iAttacker != PropsInfo[iEnt].iOwner)
		{
			if(ZRIsClientValid(iAttacker) && ZRIsClientValid(PropsInfo[iEnt].iOwner))
			{
				if(ZR_IsClientZombie(PropsInfo[iEnt].iOwner) && ZR_IsClientZombie(iAttacker))
				//if(GetClientTeam(iAttacker) == 2 && GetClientTeam(owner) == 2) //Если Т ломает проп Т
				{
					GetClientName(PropsInfo[iEnt].iOwner, Clientname, sizeof(Clientname));
					PrintCenterText(iAttacker, "%t", "ZombieBreakProp", RoundToZero(PropsInfo[iEnt].fHealth), Clientname);
					if (g_bDebug)
					{
						LogToFile(g_sLogFile, "Prop %i returned. Attacker (%i) not OWNER(%i).", iEnt, iAttacker, PropsInfo[iEnt].iOwner);
					}
					return Plugin_Continue;
				}
				else
				{
					if(ZRIsClientValid(iAttacker) && ZRIsClientValid(PropsInfo[iEnt].iOwner))
					{

						if(ZR_IsClientHuman(PropsInfo[iEnt].iOwner) && ZR_IsClientHuman(iAttacker))
						//if(GetClientTeam(iAttacker) == 3 && GetClientTeam(owner) == 3) //Если КТ ломает проп КТ
						{
							GetClientName(PropsInfo[iEnt].iOwner, Clientname, sizeof(Clientname));
							PrintCenterText(iAttacker, "%t", "HumanBreakProp", RoundToZero(PropsInfo[iEnt].fHealth), Clientname);
							if (g_bDebug)
							{
								LogToFile(g_sLogFile, "Prop %i returned. Attacker (%i) not OWNER(%i).", iEnt, iAttacker, PropsInfo[iEnt].iOwner);
							}
							return Plugin_Continue;
						}
					}
				}
			}
		}
		else
		{
			if(iAttacker == PropsInfo[iEnt].iOwner) //Если владелец ломает свой проп
			{
				if(ZRIsClientValid(iAttacker))
				{
					if(ZR_IsClientZombie(iAttacker) && ClientsRepairTools.FindValue(iAttacker) != -1) 
					{
						RemoveFromArray(ClientsRepairTools, ClientsRepairTools.FindValue(iAttacker));
					}
				}

				if(ZRIsClientValid(iAttacker))
				{
					if(ZR_IsClientHuman(iAttacker) && ClientsRepairTools.FindValue(iAttacker) != -1)
					{
						GetClientWeapon(iAttacker, sWeapon, sizeof(sWeapon));
						if(StrContains(sWeapon, "knife") != -1)
						{
						    if(fDamage < 50)
							{
								if(PropsInfo[iEnt].fHealth > PropsInfo[iEnt].fMaxHealth)
								{
									PropsInfo[iEnt].fHealth = PropsInfo[iEnt].fMaxHealth;
									return Plugin_Continue;
								}
								PropsInfo[iEnt].fHealth += 25;
								SetHudTextParams(-1.0, 0.50, 1.0, 0, 0, 255, 255);
								ShowSyncHudText(iAttacker, HudMessage, "Prop +10HP");
							}
						}
					}
				}

				if (g_bDebug)
				{
					LogToFile(g_sLogFile, "Prop %i damaged! Attacker owner(%i) || OWNER [%i]", iEnt, iAttacker, PropsInfo[iEnt].iOwner);
				}
			}
			else
			{
				//3 = CT
				//2 = T
				//1 = SPEC
				if(ZRIsPlayerSpec(PropsInfo[iEnt].iOwner)) //Если владелец пропов ушел в спектора
				{
					if (g_bDebug)
					{
						PrintToChatAll("<Func> %N in spec! Ent - %i! Reseted!", PropsInfo[iEnt].iOwner, iEnt);
						LogToFile(g_sLogFile, "Prop %i damaged! Attacker (%i) and Prop Spectate || OWNER [%i]", iEnt, iAttacker, PropsInfo[iEnt].iOwner);
					}
					RemoveOwnerFromProp(PropsInfo[iEnt].iOwner, iEnt);
				}
				else
				{
					if(ZRIsClientValid(iAttacker) && ZRIsClientValid(PropsInfo[iEnt].iOwner))
					//if(GetClientTeam(iAttacker) == 3 && GetClientTeam(owner) == 2) //Если Человек ломаeт проп Зомби
					{
						if(ZR_IsClientHuman(iAttacker) && ZR_IsClientZombie(PropsInfo[iEnt].iOwner))
						{
							if (g_bDebug)
							{
								LogToFile(g_sLogFile, "Prop %i damaged! Attacker Human(%i) and Prop Human || OWNER [%i]", iEnt, iAttacker, PropsInfo[iEnt].iOwner);
							}
						}
					}
					else
					{
						if(ZRIsClientValid(iAttacker) && ZRIsClientValid(PropsInfo[iEnt].iOwner))
						//if(GetClientTeam(iAttacker) == 2 && GetClientTeam(owner) == 3) //Если Зомби ломает проп Человека
						{
							if(ZR_IsClientZombie(iAttacker) && ZR_IsClientHuman(PropsInfo[iEnt].iOwner))
							{
								if (g_bDebug)
								{
									LogToFile(g_sLogFile, "Prop %i damaged! Attacker Zombie(%i) and Prop Zombie || OWNER [%i]", iEnt, iAttacker, PropsInfo[iEnt].iOwner);
								}
							}
						}
					}
				}
			}
		}
	}
	//////////////////////////////////////////////////////////////////////////
	
	PropsInfo[iEnt].fHealth -= RoundToZero(fDamage);
	
	if (g_bDebug)
	{
		if(PropsInfo[iEnt].iOwner <= 0)
		{
			LogToFile(g_sLogFile, "Prop Damaged (Prop: %i) (Damage: %i) (Health: %i) (Owner: SERVER) (Attacker: %i)", iEnt, RoundToZero(fDamage), RoundToZero(PropsInfo[iEnt].fHealth), iAttacker);
		}
		else
		{
			LogToFile(g_sLogFile, "Prop Damaged (Prop: %i) (Damage: %i) (Health: %i) (Owner: %i) (Attacker: %i)", iEnt, RoundToZero(fDamage), RoundToZero(PropsInfo[iEnt].fHealth), PropsInfo[iEnt].iOwner, iAttacker);
		}
	}
	
	
	if (PropsInfo[iEnt].fHealth <= 0)
	{
		// Destroy the prop.
		if (g_bDebug)
		{
			LogToFile(g_sLogFile, "Prop Destroyed (Prop: %i) (Attacker: %i)", iEnt, iAttacker);
		}

		if(PropsInfo[iEnt].iOwner == iAttacker)
		{
			//RemoveOwnerFromProp(iAttacker, iEnt);
			CPrintToChat(iAttacker, "%t", "YouDestroyedYourProp");
		}
		else
		{
			if(PropsInfo[iEnt].iOwner >= 1)
			{
				GetClientName(PropsInfo[iEnt].iOwner, Clientname, sizeof(Clientname));
				CPrintToChat(iAttacker, "%t", "YouDestroedPlayerProp", Clientname);
			}
		}

		if(PropsInfo[iEnt].iOwner != -1)
		{
			RemoveOwnerFromProp(PropsInfo[iEnt].iOwner, iEnt);
		}
		removeprop(iEnt);
		
		PropsInfo[iEnt].fHealth = -1.0;
	}
	
	// Print To Client
	if (g_bPrint && PropsInfo[iEnt].fHealth > 0)
	{
		// Print Center Text.
		if(iAttacker >= 1)
		{
			if(PropsInfo[iEnt].iOwner <= 0) //Проп сервера
			{
				PrintCenterText(iAttacker, "%t", "OwnerPropServer", RoundToZero(PropsInfo[iEnt].fHealth));
			}
			else
			{
				if(ZRIsPlayerSpec(PropsInfo[iEnt].iOwner)) //Если владелец пропа ушел в спектаторы
				{
					//PrintToChatAll("<Func2> %N in spec! Ent - %i! Reseted!", PropsInfo[iEnt].iOwner, iEnt);
					RemoveOwnerFromProp(PropsInfo[iEnt].iOwner, iEnt);
					//PrintCenterText(iAttacker, "%t", "OwnerPropSpectate", RoundToZero(PropsInfo[iEnt].fHealth), Clientname);
				}

				if(ZRIsClientValid(iAttacker) && ZRIsClientValid(PropsInfo[iEnt].iOwner))
				{
					GetClientName(PropsInfo[iEnt].iOwner, Clientname, sizeof(Clientname));
					if(ZR_IsClientZombie(PropsInfo[iEnt].iOwner))
					//if(GetClientTeam(owner) == 2) //Проп зомби
					{
						PrintCenterText(iAttacker, "%t", "OwnerPropZombie", RoundToZero(PropsInfo[iEnt].fHealth), Clientname);
					}
					else
					{
						if(ZR_IsClientHuman(PropsInfo[iEnt].iOwner))
						//if(GetClientTeam(owner) == 3) //Проп человека
						{
							PrintCenterText(iAttacker, "%t", "OwnerPropHuman", RoundToZero(PropsInfo[iEnt].fHealth), Clientname);
						}
					}
				}
			}	
		}
		
	}
	return Plugin_Continue;
}

public Action:Command_GetPropInfo(iClient, iArgs)
{
	new iEnt = GetClientAimTarget(iClient, false);
	
	if(!IsValidEntity(iEnt))
	{
		CPrintToChat(iClient, "%t", "PropInvalid", iClient);
		return Plugin_Continue;
	}

	if (iEnt > MaxClients)
	{
		decl String:sModelName[PLATFORM_MAX_PATH];
		GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
		
		if(PropsInfo[iEnt].iOwner <= 0)
		{
			PrintToChat(iClient, "\x07FFFFFF%s (Model: %s) (Prop Health: \x0738ff3f%i\x07FFFFFF) (Prop Index: %i) (OwnerID: SERVER) (Your ID: \x07F74545%i\x07FFFFFF)", PREFIX, sModelName, RoundToZero(PropsInfo[iEnt].fHealth), iEnt, iClient);
		}
		else
		{
			if(ZRIsClientValid(PropsInfo[iEnt].iOwner))
			{
				if(ZR_IsClientZombie(PropsInfo[iEnt].iOwner))
				//if(GetClientTeam(owner) == 2)
				{
					PrintToChat(iClient, "\x07FFFFFF%s (Model: %s) (Prop Health: \x0738ff3f%i\x07FFFFFF) (Prop Index: %i) (OwnerID: \x07F74545%i\x07FFFFFF) (Owner Name: \x07F74545%N\x07FFFFFF) (Owner Team: Zombie) (Your ID: \x07F74545%i\x07FFFFFF)", PREFIX, sModelName, RoundToZero(PropsInfo[iEnt].fHealth), iEnt, PropsInfo[iEnt].iOwner, PropsInfo[iEnt].iOwner, iClient);
				}
				else
				{
					if(ZR_IsClientHuman(PropsInfo[iEnt].iOwner))
					//if(GetClientTeam(PropsInfo[iEnt].iOwner) == 3)
					{
						PrintToChat(iClient, "\x07FFFFFF%s (Model: %s) (Prop Health: \x0738ff3f%i\x07FFFFFF) (Prop Index: %i) (OwnerID: \x07F74545%i\x07FFFFFF) (Owner Name: \x07F74545%N\x07FFFFFF) (Owner Team: Human) (Your ID: \x07F74545%i\x07FFFFFF)", PREFIX, sModelName, RoundToZero(PropsInfo[iEnt].fHealth), iEnt, PropsInfo[iEnt].iOwner, PropsInfo[iEnt].iOwner, iClient);
					}
					else
					{
						PrintToChat(iClient, "\x07FFFFFF%s (Model: %s) (Prop Health: \x0738ff3f%i\x07FFFFFF) (Prop Index: %i) (OwnerID: \x07F74545%i\x07FFFFFF) (Owner Name: \x07F74545%N\x07FFFFFF) (Owner Team: Spectate/Dead/NotAuth) (Your ID: \x07F74545%i\x07FFFFFF)", PREFIX, sModelName, RoundToZero(PropsInfo[iEnt].fHealth), iEnt, PropsInfo[iEnt].iOwner, PropsInfo[iEnt].iOwner, iClient);
					}
				}
			}
		}
	}
	else
	{
		CPrintToChat(iClient, "%t", "PropInvalid", iClient);
	}
	return Plugin_Handled;
}

removeprop(iEnt)
{
	decl String:buffer[32];
	Format(buffer, sizeof(buffer), "dissolve%f", GetRandomFloat());
	DispatchKeyValue(iEnt, "targetname", buffer);
	iEnt = CreateEntityByName("env_entity_dissolver");
	DispatchKeyValue(iEnt, "dissolvetype", "3");
	DispatchKeyValue(iEnt, "target", buffer);
	AcceptEntityInput(iEnt, "dissolve");
	RemoveEntity(iEnt);
}

/////////////
SetPropColorHealth(iEnt, hp, maxhp)
{
	new blue, red;
	if(hp < 1) red = 255;
	else if(hp >= maxhp) blue = 255;
	else
	{
		new state;
		if((state = RoundToNearest(((Float:hp / Float:maxhp) * 510.0))) > 255)
		{
			red		= 510 - state;
			blue	= 255;
		}
		else
		{
			red		= 255;
			blue	= state;
		}
	}

	SetEntityRenderColor(iEnt, red, 0, blue, 255);
}

TakeMoney(iClient, amount) 
{
    new clientMoney = GetEntProp(iClient, Prop_Send, "m_iAccount"); // Get player's current cash
    clientMoney -= amount;
    SetEntProp(iClient, Prop_Send, "m_iAccount", clientMoney); // Set player's money to the new amount
}

public Action:Command_RepairProp(iClient, iArgs)
{
	if(g_bStatusRepairTools)
	{
		if(ClientsRepairTools.FindValue(iClient) == -1)
		{
			if(GetClientTeam(iClient) == 1)
			{
				CPrintToChat(iClient, "%t", "RepairToolsOnlyForHumans");
			}
			else
			{
				if(ZRIsClientValid(iClient))
				{
					if(ZR_IsClientHuman(iClient))
					//if(ZRIsClientValid(iClient) == true && ZR_IsClientHuman(iClient) == true)
					{
						new clientMoney = GetEntProp(iClient, Prop_Send, "m_iAccount");
						if (clientMoney >= 5000)
						{
							TakeMoney(iClient, 5000);
							CPrintToChat(iClient, "%t", "YouBuyRepairTools");
							ClientsRepairTools.Push(iClient);
						}
						else
						{
							CPrintToChat(iClient, "%t", "NeedMoreMoneyForRepair");
						}
					}
					else
					{
						CPrintToChat(iClient, "%t", "RepairToolsOnlyForHumans");
					}
				}
			}
		}
		else
		{
			CPrintToChat(iClient, "%t", "RepairToolsIsAlreadyThere");
		}
	}
	else
	{
		CPrintToChat(iClient, "%t", "RepairToolsIsDisabled");
	}
	return Plugin_Handled;
}

public Action:Command_Credits(int client, int args)
{
    if(args != 2)
	{
	    CPrintToChat(client, "[ZP] Usage: sm_zprop_credits <name> <amount>");
	    return Plugin_Handled;
	}
    char TargetName[64], CreditAmount[64];
    GetCmdArg(1, TargetName, sizeof(TargetName));
	GetCmdArg(2, CreditAmount, sizeof(CreditAmount));
	
	int Target = FindTarget(client, TargetName);
	if(Target == -1)
	{
	    return Plugin_Handled;
	}
	
	int g_iCreditAmount = StringToInt(CreditAmount);
	g_iCredits[Target] += g_iCreditAmount;
	g_bGivenCredits[Target] = true;
	
	CPrintToChat(client, "[ZP] You gave %d credits for props to %N.", g_iCreditAmount, Target);
	CPrintToChat(Target, "[ZP] Admin gave you %d credits for props.", g_iCreditAmount);
	
	return Plugin_Handled;
}

public Action:Command_SetHpProp(iClient, args)
{
	if (args <= 0)
    {
        PrintToChat(iClient, "\x07FFFF00%s\x07FFFFFF Usage: !sm_sethpprop <number>", PREFIX)
        return Plugin_Stop;
    }
    
	new iEnt = GetClientAimTarget(iClient, false);
	if(!IsValidEntity(iEnt))
	{
		CPrintToChat(iClient, "%t", "PropInvalid", iClient);
		return Plugin_Stop;
	}

	decl String:sModelName[PLATFORM_MAX_PATH];
	GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName)); //model
	GetClientAuthId(iClient, AuthIdType:1, admsteam, 64, true); //Admin SteamID
	
	
	decl String:sClassname[MAX_NAME_LENGTH];
	GetEntityClassname(iEnt, sClassname, sizeof(sClassname));
	
	if (!StrEqual(sClassname, "prop_physics", false) && !StrEqual(sClassname, "prop_physics_override", false) && !StrEqual(sClassname, "prop_physics_multiplayer", false))
	{
		CPrintToChat(iClient, "%t", "PropInvalid", iClient);
		return Plugin_Stop;
	}
	
	if(iEnt > MaxClients) //Если проп не является игроком
	{
		char arg[8];
	    GetCmdArg(1, arg, sizeof(arg));
	    float arg_health = StringToFloat(arg);
		if(PropsInfo[iEnt].iOwner <= 0) //Если проп сервера
		{
			PropsInfo[iEnt].fHealth = arg_health;
			if(arg_health > PropsInfo[iEnt].fMaxHealth)
			{
				PropsInfo[iEnt].fMaxHealth = arg_health;
			}
			if(g_bChangeColorHp)
			{
				SetPropColorHealth(iEnt, float:PropsInfo[iEnt].fHealth, float:PropsInfo[iEnt].fMaxHealth);
			}
			PrintToChat(iClient, "\x07FFFFFF%s You set \x07F74545%i\x07FFFFFF health this prop! (Model: %s) (Owner: SERVER) (Your ID: \x07F74545%i\x07FFFFFF)", PREFIX, RoundToZero(arg_health), sModelName, iClient);
			LogToFile(g_sLogSetHP, "%s Admin (%N) (SteamID: %s) set %i health this prop (Owner: SERVER) (Model: %s)", PREFIX, iClient, admsteam, RoundToZero(arg_health), sModelName);
		}
		else
		{	
			if(PropsInfo[iEnt].iOwner >= 1) //Если проп игрока
			{
				PropsInfo[iEnt].fHealth = arg_health;
				if(arg_health > PropsInfo[iEnt].fMaxHealth)
				{
					PropsInfo[iEnt].fMaxHealth = arg_health;
				}

				if(g_bChangeColorHp)
				{
					SetPropColorHealth(iEnt, float:PropsInfo[iEnt].fHealth, float:PropsInfo[iEnt].fMaxHealth);
				}

				GetClientAuthId(PropsInfo[iEnt].iOwner, AuthIdType:1, plysteam, 64, true); //Player SteamID
				PrintToChat(iClient, "\x07FFFFFF%s You set \x07F74545%i\x07FFFFFF health this prop! (Model: %s) (OwnerID: \x07F74545%i\x07FFFFFF) (Owner Name: \x07F74545%N\x07FFFFFF) (Your ID: \x07F74545%i\x07FFFFFF)", PREFIX, RoundToZero(arg_health), sModelName, PropsInfo[iEnt].iOwner, PropsInfo[iEnt].iOwner, iClient);
				LogToFile(g_sLogSetHP, "%s Admin (%N) (SteamID: %s) set %i health this prop (Owner: %N) (SteamID: %s) (Model: %s)", PREFIX, iClient, admsteam, RoundToZero(arg_health), PropsInfo[iEnt].iOwner, plysteam, sModelName);
				CPrintToChatAll("\x07FFFF00%s \x07FFFFFFAdmin \x07F74545%N\x07FFFFFF change health this prop \x07F74545%N\x07FFFFFF!", INFO, iClient, PropsInfo[iEnt].iOwner);
			}
			else
			{
				if(PropsInfo[iEnt].iOwner == iClient)
				{
					GetClientAuthId(PropsInfo[iEnt].iOwner, AuthIdType:1, plysteam, 64, true); //Player SteamID
					PropsInfo[iEnt].fHealth = arg_health;

					if(arg_health > PropsInfo[iEnt].fMaxHealth)
					{
						PropsInfo[iEnt].fMaxHealth = arg_health;
					}

					if(g_bChangeColorHp)
					{
						SetPropColorHealth(iEnt, float:PropsInfo[iEnt].fHealth, float:PropsInfo[iEnt].fMaxHealth);
					}

					PrintToChat(iClient, "\x07FFFFFF%s You set \x07F74545%i\x07FFFFFF health this prop (Model: %s) (OwnerID: \x07F74545%i\x07FFFFFF) (Owner Name: \x07F74545%N\x07FFFFFF) (Your ID: \x07F74545%i\x07FFFFFF)", PREFIX, sModelName, PropsInfo[iEnt].iOwner, PropsInfo[iEnt].iOwner, iClient);
					LogToFile(g_sLogSetHP, "%s Admin (%N) (SteamID: %s) set %i health this prop (Owner: %N) (SteamID: %s) (Model: %s)", PREFIX, RoundToZero(arg_health), iClient, admsteam, PropsInfo[iEnt].iOwner, plysteam, sModelName);
				}
				else
				{
					LogToFile(g_sLogSetHP, "ERROR FUNCTION SET HEALTH PROP!"); //Репорт ошибки
				}
			}
		}
	}
	else
	{
		CPrintToChat(iClient, "%t", "PropInvalid", iClient);
	}
	return Plugin_Handled;
}

public Action:Command_ResetProp(iClient, iArgs)
{
	new iEnt = GetClientAimTarget(iClient, false);
	
	if(!IsValidEntity(iEnt))
	{
		CPrintToChat(iClient, "%t", "PropInvalid", iClient);
		return Plugin_Stop;
	}

	decl String:sModelName[PLATFORM_MAX_PATH];
	GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName)); //model
	
	GetClientAuthId(iClient, AuthIdType:1, admsteam, 64, true); //Admin SteamID
	
	
	decl String:sClassname[MAX_NAME_LENGTH];
	GetEntityClassname(iEnt, sClassname, sizeof(sClassname));
	
	if (!StrEqual(sClassname, "prop_physics", false) && !StrEqual(sClassname, "prop_physics_override", false) && !StrEqual(sClassname, "prop_physics_multiplayer", false)) 
	{
		PrintToChat(iClient, "\x07FFFF00%s\x07F74545 This Prop cannot be reseted! (Model: %s)", INFO, sModelName);
		return Plugin_Continue;
	}
	
	if(iEnt > MaxClients) //Если проп не является игроком
	{
		if(PropsInfo[iEnt].iOwner <= 0) //Если проп сервера
		{
			PrintToChat(iClient, "\x07FFFFFF%s This prop has no owner! (Model: %s) (OwnerID: SERVER) (Your ID: \x07F74545%i\x07FFFFFF)", PREFIX, sModelName, iClient);
			return Plugin_Continue;
		}
		else
		{	
			if(PropsInfo[iEnt].iOwner >= 1) //Если проп игрока
			{
				GetClientAuthId(PropsInfo[iEnt].iOwner, AuthIdType:1, plysteam, 64, true); //Player SteamID
				PrintToChat(iClient, "\x07FFFFFF%s You reseted prop! (Model: %s) (OwnerID: \x07F74545%i\x07FFFFFF) (Owner Name: \x07F74545%N\x07FFFFFF) (Your ID: \x07F74545%i\x07FFFFFF)", PREFIX, sModelName, PropsInfo[iEnt].iOwner, PropsInfo[iEnt].iOwner, iClient);
				LogToFile(g_sLogRes, "%s Admin (%N) (SteamID: %s) reseted prop (Owner: %N) (SteamID: %s) (Model: %s)", PREFIX, iClient, admsteam, PropsInfo[iEnt].iOwner, plysteam, sModelName);
				CPrintToChatAll("\x07FFFF00%s\x07FFFFFF Admin \x07F74545%N\x07FFFFFF reseted player prop \x07F74545%N\x07FFFFFF!", INFO, iClient, PropsInfo[iEnt].iOwner);
				RemoveOwnerFromProp(PropsInfo[iEnt].iOwner, iEnt);
			}
			else
			{
				if(PropsInfo[iEnt].iOwner == iClient) //Если свой проп
				{
					GetClientAuthId(PropsInfo[iEnt].iOwner, AuthIdType:1, plysteam, 64, true); //Player SteamID
					LogToFile(g_sLogRes, "%s Admin (%N) (SteamID: %s) reseted prop (Owner: %N) (SteamID: %s) (Model: %s)", PREFIX, iClient, admsteam, PropsInfo[iEnt].iOwner, plysteam, sModelName);
					PrintToChat(iClient, "\x07FFFFFF%s You reseted prop! (Model: %s) (OwnerID: \x07F74545%i\x07FFFFFF) (Owner Name: \x07F74545%N\x07FFFFFF) (Your ID: \x07F74545%i\x07FFFFFF)", PREFIX, sModelName, PropsInfo[iEnt].iOwner, PropsInfo[iEnt].iOwner, iClient);
					RemoveOwnerFromProp(PropsInfo[iEnt].iOwner, iEnt);
				}
				else
				{
					LogToFile(g_sLogRes, "ERROR FUNCTION RESETED PROP!"); //Репорт ошибки
				}
			}
		}
	}
	else
	{
		PrintToChat(iClient, "\x07FFFFFF%s \x07F74545Prop is either a player or invalid.", PREFIX);
	}
	return Plugin_Handled;
}

public Action:Command_DeleteProp(iClient, iArgs)
{
	new iEnt = GetClientAimTarget(iClient, false);

	if(!IsValidEntity(iEnt))
	{
		CPrintToChat(iClient, "%t", "PropInvalid", iClient);
		return Plugin_Stop;
	}

	decl String:sModelName[PLATFORM_MAX_PATH];
	GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName)); //model
	
	GetClientAuthId(iClient, AuthIdType:1, admsteam, 64, true); //Admin SteamID
	
	decl String:sClassname[MAX_NAME_LENGTH];
	GetEntityClassname(iEnt, sClassname, sizeof(sClassname));
	
	if (!StrEqual(sClassname, "prop_physics", false) && !StrEqual(sClassname, "prop_physics_override", false) && !StrEqual(sClassname, "prop_physics_multiplayer", false))
	{
		PrintToChat(iClient, "\x07FFFF00%s\x07F74545 This Prop cannot be deleted! (Model: %s)", INFO, sModelName);
		return Plugin_Stop;
	}
	
	if(iEnt > MaxClients) //Если проп не является игроком
	{
		if(PropsInfo[iEnt].iOwner <= 0) //Если проп сервера
		{
			PrintToChat(iClient, "\x07FFFFFF%s You deleted prop! (Model: %s) (OwnerID: SERVER) (Your ID: \x07F74545%i\x07FFFFFF)", PREFIX, sModelName, iClient);
			LogToFile(g_sLogDel, "%s Admin (%N) (SteamID: %s) delete prop (Owner: SERVER) (Model: %s)", PREFIX, iClient, admsteam, sModelName);
			CPrintToChatAll("\x07FFFF00%s\x07FFFFFF Admin \x07F74545%N\x07FFFFFF deleted \x07F74545SERVER\x07FFFFFF prop!", INFO, iClient, PropsInfo[iEnt].iOwner);
			removeprop(iEnt);
		}
		else
		{	
			if(PropsInfo[iEnt].iOwner >= 1) //Если проп игрока
			{
				GetClientAuthId(PropsInfo[iEnt].iOwner, AuthIdType:1, plysteam, 64, true); //Player SteamID
				PrintToChat(iClient, "\x07FFFFFF%s You deleted prop! (Model: %s) (OwnerID: \x07F74545%i\x07FFFFFF) (Owner Name: \x07F74545%N\x07FFFFFF) (Your ID: \x07F74545%i\x07FFFFFF)", PREFIX, sModelName, PropsInfo[iEnt].iOwner, PropsInfo[iEnt].iOwner, iClient);
				LogToFile(g_sLogDel, "%s Admin (%N) (SteamID: %s) delete prop (Owner: %N) (SteamID: %s) (Model: %s)", PREFIX, iClient, admsteam, PropsInfo[iEnt].iOwner, plysteam, sModelName);
				CPrintToChatAll("\x07FFFF00%s \x07FFFFFFAdmin \x07F74545%N\x07FFFFFF deleted player prop \x07F74545%N\x07FFFFFF!", INFO, iClient, PropsInfo[iEnt].iOwner);
				RemoveOwnerFromProp(PropsInfo[iEnt].iOwner, iEnt);
				removeprop(iEnt);
			}
			else
			{
				if(PropsInfo[iEnt].iOwner == iClient) //Если админ удаляет свой проп
				{
					GetClientAuthId(PropsInfo[iEnt].iOwner, AuthIdType:1, plysteam, 64, true); //Player SteamID
					LogToFile(g_sLogDel, "%s Admin (%N) (SteamID: %s) delete prop (Owner: %N) (SteamID: %s) (Model: %s)", PREFIX, iClient, admsteam, PropsInfo[iEnt].iOwner, plysteam, sModelName);
					PrintToChat(iClient, "\x07FFFFFF%s You deleted prop! (Model: %s) (OwnerID: \x07F74545%i\x07FFFFFF) (Owner Name: \x07F74545%N\x07FFFFFF) (Your ID: \x07F74545%i\x07FFFFFF)", PREFIX, sModelName, PropsInfo[iEnt].iOwner, PropsInfo[iEnt].iOwner, iClient);
					RemoveOwnerFromProp(PropsInfo[iEnt].iOwner, iEnt);
					removeprop(iEnt);
				}
				else
				{
					LogToFile(g_sLogDel, "ERROR FUNCTION DELETE PROP!"); //Репорт ошибки
				}
			}
		}
	}
	else
	{
		PrintToChat(iClient, "\x07FFFFFF%s \x07F74545Prop is either a player or invalid.", PREFIX);
	}
	return Plugin_Handled;
}


public Action:Command_Zprops(iClient, iArgs)
{
	if(!ZRIsClientValid(iClient))
	{
		return Plugin_Handled;
	}
	
	if(g_bRoundStartRestriction)
	{
		PrintToChat(iClient, "[ZP] Props will be enabled in %d seconds.", g_iRoundStartTime - GetTime());
		return Plugin_Handled;
	}
	
	if(!g_bEnabled)
	{
		PrintToChat(iClient, "[ZP] Props are disabled.");
		return Plugin_Handled;
	}
	
	Menu_ZProp(iClient);
	
	return Plugin_Handled;
}


Menu_ZProp(client, pos = 0)
{
	decl String:sTemp[8], String:sBuffer[128];
	new Handle:hMenu = CreateMenu(Menu_ZPropHandle);
	Format(sBuffer, sizeof(sBuffer), "%T", "Menu_Title", client, g_iCredits[client]);
	SetMenuTitle(hMenu, sBuffer);

	for(new i = 0; i < g_iNumProps; i++)
	{
		IntToString(i, sTemp, sizeof(sTemp));
		Format(sBuffer, sizeof(sBuffer), "%T", "Menu_Prop", client, g_sPropNames[i], g_iPropCosts[i]);
		AddMenuItem(hMenu, sTemp, sBuffer,(g_iCredits[client] >= g_iPropCosts[i]) ? ITEMDRAW_DEFAULT : ITEMDRAW_DISABLED);
	}

	DisplayMenuAtItem(hMenu, client, pos, MENU_TIME_FOREVER);
}

public Menu_ZPropHandle(Handle:hMenu, MenuAction:action, client, param2)
{
	switch(action)
	{
		case MenuAction_End:
			CloseHandle(hMenu);
		case MenuAction_Select:
		{
			decl String:sChoice[8];
			GetMenuItem(hMenu, param2, sChoice, sizeof(sChoice));
			new iIndex = StringToInt(sChoice);
		
			if(g_iCredits[client] < g_iPropCosts[iIndex])
			{
				CPrintToChat(client, "%t%t", "Prefix_Chat", "Phrase_Insufficient_Credits", g_iCredits[client], g_iPropCosts[iIndex]);
				Menu_ZProp(client);
				
				return;
			}

			if(GetClientTeam(client) == 1)
			{
				return;
			}

			if(PlayerInfo[client].iCountProps >= MAXIMUM_PROP_PLAYER)
			{
				PrintToChat(client, "<ERROR> Limit props!");
				return;
			}

			new iEnt = CreateEntityByName(g_sPropTypes[iIndex]);
			if(iEnt >= 0)
			{
						
				decl Float:fLocation[3], Float:fAngles[3], Float:fOrigin[3], Float:fTemp[3];
				GetClientEyeAngles(client, fTemp);
				GetClientAbsOrigin(client, fLocation);
				GetClientAbsAngles(client, fAngles);

				fAngles[0] = fTemp[0];
				fLocation[2] += 50;
				AddInFrontOf(fLocation, fAngles, 35, fOrigin);

				decl String:sBuffer[24];
				Format(sBuffer, sizeof(sBuffer), "ZProp %d %d", GetClientUserId(client), g_iUnique);
				DispatchKeyValue(iEnt, "targetname", sBuffer);

				SetEntityModel(iEnt, g_sPropPaths[iIndex]);
				//SetEntProp(iEnt, Prop_Send, "m_nSolidType", FSOLID_COLLIDE_WITH_OWNER);
				//SetEntProp(iEnt, Prop_Send, "m_usSolidFlags", FSOLID_COLLIDE_WITH_OWNER);
				DispatchSpawn(iEnt);
				
				TeleportEntity(iEnt, fOrigin, NULL_VECTOR, NULL_VECTOR);
				g_iCredits[client] -= g_iPropCosts[iIndex];
				
				//PropsInfo[iEnt].iOwner = client;
				//PlayerInfo[client].iClientPropsOwned[64] = iEnt;

				AddOwnerInProp(client, iEnt);
				if(g_bDebug)
				{
					LogToFile(g_sLogFile, "Prop spawned by [ %i ]", PropsInfo[iEnt].iOwner);
					PrintToChat(client, "Ent - %i", iEnt);
					PrintToChat(client, "Player - %i %i", client, PropsInfo[iEnt].iOwner);
					PrintToChat(client, "Count - %i", PlayerInfo[client].iCountProps);
				}
				GetClientName(PropsInfo[iEnt].iOwner, Clientname, sizeof(Clientname));
				PrintHintText(client, "%t%t", "Prefix_Hint", "Hint_Credits_Buy", g_iPropCosts[iIndex], g_iCredits[client]);
				CPrintToChat(client, "%t%t", "Prefix_Chat", "Phrase_Spawn_Prop", g_sPropNames[iIndex], Clientname);
				g_iUnique++;
			}
			
			Menu_ZProp(client, GetMenuSelectionPosition());
		}
	}
}

AddInFrontOf(Float:vecOrigin[3], Float:vecAngle[3], units, Float:output[3])
{
	decl Float:vecView[3];
	GetViewVector(vecAngle, vecView);

	output[0] = vecView[0] * units + vecOrigin[0];
	output[1] = vecView[1] * units + vecOrigin[1];
	output[2] = vecView[2] * units + vecOrigin[2];
}

GetViewVector(Float:vecAngle[3], Float:output[3])
{
	output[0] = Cosine(vecAngle[1] / (180 / FLOAT_PI));
	output[1] = Sine(vecAngle[1] / (180 / FLOAT_PI));
	output[2] = -Sine(vecAngle[0] / (180 / FLOAT_PI));
}


CheckCredits(client, amount)
{
	g_iCredits[client] += amount;
	if(g_iCredits[client] < g_iCreditsMax)
	{
		PrintHintText(client, "%t%t", "Prefix_Hint", "Hint_Credits_Gain", amount, g_iCredits[client]);
	}
	else 
	{
		if(g_iCredits[client] > g_iCreditsMax)
		{
		    if(!g_bGivenCredits[client])
			{
			    g_iCredits[client] = g_iCreditsMax;
			}
			PrintHintText(client, "%t%t", "Prefix_Hint", "Hint_Credits_Maximum", g_iCreditsHuman, g_iCredits[client]);
		}
	}
}
////////////////ABOUT/////////////////
public Action:Command_ZAbout(iClient, iArgs)
{
	if(zbout_run)
	{
		return Plugin_Continue;
	}

    if ((g_MaxIndex = (strlen(g_Str) - 1)) > 0)
    {
    	zbout_run = true;
        g_CurrentIndex = -1;
        msg(iClient);
        g_hTimer = CreateTimer(0.1, g_hTimer_CallBack, iClient, TIMER_REPEAT);
    }
    return Plugin_Handled;
}
//////////////////////////////////////
public Action:g_hTimer_CallBack(Handle:timer, any:iClient)
{
    if (IsClientInGame(iClient))
    {
        msg(iClient);
        return Plugin_Continue;
		//return Plugin_Stop;
    }
    //g_hTimer = INVALID_HANDLE;
    return Plugin_Stop;
}

msg(iClient)
{
    static String:s[256];
    strcopy(s, sizeof(s), g_Str);

    if (++g_CurrentIndex < g_MaxIndex) {
        s[g_CurrentIndex + 1] = 0;
    }
    else {
        g_CurrentIndex = -1;
		KillTimer(g_hTimer);
		zbout_run = false;
    }
    
    PrintCenterText(iClient, s);
}
//////////////////////////////////////



stock SetPropHealth(iEnt)
{
	decl String:sClassname[MAX_NAME_LENGTH];
	GetEntityClassname(iEnt, sClassname, sizeof(sClassname));
	
	if (!StrEqual(sClassname, "prop_physics", false) && !StrEqual(sClassname, "prop_physics_override", false) && !StrEqual(sClassname, "prop_physics_multiplayer", false))
	{
		return;
	}

	decl String:sFile[PLATFORM_MAX_PATH];
	BuildPath(Path_SM, sFile, sizeof(sFile), g_sConfigPath);
	
	new Handle:hKV = CreateKeyValues("Props");
	FileToKeyValues(hKV, sFile);
	
	decl String:sPropModel[PLATFORM_MAX_PATH];
	GetEntPropString(iEnt, Prop_Data, "m_ModelName", sPropModel, sizeof(sPropModel));
	if (g_bDebug)
	{
		LogToFile(g_sLogFile, "Prop model found! (Prop: %i) (Prop Model: %s)", iEnt, sPropModel);
	}
	
	if (KvGotoFirstSubKey(hKV))
	{
		decl String:sBuffer[PLATFORM_MAX_PATH];
		do
		{
			KvGetSectionName(hKV, sBuffer, sizeof(sBuffer));
			if (g_bDebug)
			{
				LogToFile(g_sLogFile, "Checking prop model. (Prop: %i) (Prop Model: %s) (Section Model: %s)", iEnt, sPropModel, sBuffer);
			}
			
			if (StrEqual(sBuffer, sPropModel, false))
			{
				if (g_bDebug)
				{
					LogToFile(g_sLogFile, "Prop model matches. (Prop: %i) (Prop Model: %s)", iEnt, sPropModel);
				}
				
				PropsInfo[iEnt].fHealth = KvGetFloat(hKV, "health");
				PropsInfo[iEnt].fMaxHealth = KvGetFloat(hKV, "maxhealth");
				
				new Float: fMultiplier2 = KvGetFloat(hKV, "multiplier");
				new iClientCount = GetRealClientCount();
				new Float:fAddHealth = float(iClientCount) * fMultiplier2;
				
				PropsInfo[iEnt].fHealth += RoundToZero(fAddHealth);
				PropsInfo[iEnt].fMultiplier = fMultiplier2;
				
				if (g_bDebug)
				{
					LogToFile(g_sLogFile, "Custom prop's health set. (Prop: %i) (Prop Health: %f) (Multiplier: %f) (Added Health: %i) (Client Count: %i)", iEnt, PropsInfo[iEnt].fHealth, fMultiplier2, RoundToZero(fAddHealth), iClientCount);
				}
			}
		} while (KvGotoNextKey(hKV));
	}
	
	if (hKV != INVALID_HANDLE)
	{
		CloseHandle(hKV);
	}
	else
	{			
		if (g_bDebug)
		{
			LogToFile(g_sLogFile, "hKV was never valid.");
		}
	}
	
	if (PropsInfo[iEnt].fHealth < 1)
	{
		PropsInfo[iEnt].fHealth = g_iDefaultHealth;
		PropsInfo[iEnt].fMaxHealth = g_iDefaultHealth;
		PropsInfo[iEnt].fMultiplier = g_fDefaultMultiplier;
		
		new iClientCount = GetRealClientCount();
		new Float:fAddHealth = float(iClientCount) * g_fDefaultMultiplier;
		
		PropsInfo[iEnt].fHealth += RoundToZero(fAddHealth);
		if (g_bDebug)
		{
			LogToFile(g_sLogFile, "Prop is being set to default health. (Prop: %i) (O - Default Health: %i) (Default Multiplier: %f) (Added Health: %i) (Health: %f) (Client Count: %i)", iEnt, RoundToZero(g_iDefaultHealth), g_fDefaultMultiplier, RoundToZero(fAddHealth), RoundToZero(PropsInfo[iEnt].fHealth), iClientCount);
		}
	}
	else
	{
		if (g_bDebug)
		{
			LogToFile(g_sLogFile, "Prop already has a health value! (Prop: %i) (Health: %f)", iEnt, PropsInfo[iEnt].fHealth);
		}
	}
	
	if (g_iColorRed != -1 && g_iColorGreen != -1 && g_iColorBlue != -1 && g_iColorAlpha != -1)
	{
		if(PropsInfo[iEnt].fHealth > 0)
		{
			if (g_bDebug)
			{
				LogToFile(g_sLogFile, "Prop is being colored! (Prop: %i)", iEnt);
			}
			
			// Set the entities color.
			//decl String:sBit[4][32];
			
			//ExplodeString(g_sColor, " ", sBit, sizeof(sBit), sizeof(sBit[]));
			if(g_bDebug)
			{
				PrintToChatAll("<SetPropHealth Func> Ent: %i | R: %i | G: | %i B: %i", iEnt, g_iColorRed, g_iColorGreen, g_iColorBlue, g_iColorAlpha);
			}
			SetEntityRenderColor(iEnt, g_iColorRed, g_iColorGreen, g_iColorBlue, g_iColorAlpha);
		}
	}
	
	if (PropsInfo[iEnt].fHealth > 0)
	{
		SDKHook(iEnt, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	}
}

public Action:Command_GetPropsFromPlayer(client, iArgs)
{
	if(iArgs <= 0)
	{
	    PrintToChat(client, "[Dev] Usage: sm_getprops <name>");
	    return Plugin_Handled;
	}
    decl String:TargetName[64];
    GetCmdArg(1, TargetName, sizeof(TargetName));
	
	int Target = FindTarget(client, TargetName);
	if(!ZRIsClientValid(Target))
	{
		PrintToChat(client, "[Dev] Invalid player! Maybe is bot?");
	    return Plugin_Continue;
	}

	for(int i = 0; i < MAXIMUM_PROP_PLAYER; i++)
	{
		if(PlayerInfo[Target].iClientPropsOwned[i] != 0)
		{
			LogToFile(g_sLogFile, "<PROPS ALL> PropIndex: %i From: %N", PlayerInfo[Target].iClientPropsOwned[i], Target);
			PrintToChat(client, "<PROPS ALL> PropIndex: %i From: %N", PlayerInfo[Target].iClientPropsOwned[i], Target);
		}
	}
	return Plugin_Handled;
}

RemoveOwnerFromAllProps(client)
{
	if(g_bDebug && ZRIsClientValid(client))
	{
		PrintToChat(client, "<RemoveOwnerFromAllProps> INPUT client: %i", client);
	}

	if(PlayerInfo[client].iCountProps >= 1)
	{
		if(g_bDebug)
		{
			PrintToChat(client, "Count(Before): %i", PlayerInfo[client].iCountProps);
		}
		decl iEnt;

		for(int i = 0; i < MAXIMUM_PROP_PLAYER; i++)
		{
			if(PlayerInfo[client].iClientPropsOwned[i] != 0)
			{
				iEnt = PlayerInfo[client].iClientPropsOwned[i];
				if(g_bDebug)
				{
					LogToFile(g_sLogFile, "<REMOVED ALL> PropIndex: %i From: %N", PlayerInfo[client].iClientPropsOwned[i], client);
					PrintToChat(client, "<REMOVED ALL> PropIndex: %i From: %N", PlayerInfo[client].iClientPropsOwned[i], client);
				}
				PlayerInfo[client].iClientPropsOwned[i] = 0;
				PropsInfo[iEnt].iOwner = -1;
			}
		}
		PlayerInfo[client].iCountProps = 0;

		if(g_bDebug)
		{
			PrintToChat(client, "Count(After): %i", PlayerInfo[client].iCountProps);
		}
	}
}

RemoveOwnerFromProp(client, iEnt)
{
	if(g_bDebug && ZRIsClientValid(client))
	{
		PrintToChat(client, "<RemoveOwnerFromProp> INPUT client: %i ent: %i", client, iEnt);
	}

	if(PlayerInfo[client].iCountProps >= 1)
	{
		if(g_bDebug)
		{
			PrintToChat(client, "Count(Before): %i", PlayerInfo[client].iCountProps);
		}

		for(int i = 0; i < MAXIMUM_PROP_PLAYER; i++)
		{
			if(PlayerInfo[client].iClientPropsOwned[i] == iEnt)
			{
				if(g_bDebug)
				{
					LogToFile(g_sLogFile, "<REMOVED> PropIndex: %i From: %N", PlayerInfo[client].iClientPropsOwned[i], client);
					PrintToChat(client, "<REMOVED> PropIndex: %i From: %N", PlayerInfo[client].iClientPropsOwned[i], client);
				}
				//PrintToChat(client, "INDEX: %i", PlayerInfo[client].iClientPropsOwned[i]);
				PlayerInfo[client].iClientPropsOwned[i] = 0;
				PropsInfo[iEnt].iOwner = -1;
				PlayerInfo[client].iCountProps--;

			}
		}

		if(g_bDebug)
		{
			PrintToChat(client, "Count(After): %i", PlayerInfo[client].iCountProps);
		}
	}
}

AddOwnerInProp(client, iEnt)
{
	if(g_bDebug)
	{
		PrintToChat(client, "Count(Before): %i", PlayerInfo[client].iCountProps);
	}

	for(int i = 0; i < MAXIMUM_PROP_PLAYER; i++)
	{
		if(PlayerInfo[client].iClientPropsOwned[i] == 0)
		{
			PlayerInfo[client].iClientPropsOwned[i] = iEnt;
			PropsInfo[iEnt].iOwner = client;
			PlayerInfo[client].iCountProps++;

			if(g_bDebug)
			{
				LogToFile(g_sLogFile, "<ADDED> PropIndex: %i Owner: %N", PlayerInfo[client].iClientPropsOwned[i], client);
				PrintToChat(client, "<ADDED> PropIndex: %i Owner: %N", PlayerInfo[client].iClientPropsOwned[i], client);
			}
			break;
		}
	}

	if(g_bDebug)
	{
		PrintToChat(client, "Count(After): %i", PlayerInfo[client].iCountProps);
	}
}