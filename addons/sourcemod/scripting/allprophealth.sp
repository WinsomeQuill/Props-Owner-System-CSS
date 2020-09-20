#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <zombiereloaded>
#include <multicolors>
#pragma tabsize 0

#define PL_VERSION "1.6.1"
#define MAXENTITIES 2048
#define PREFIX "[ZP]"
#define INFO "[iNFO]"
#define WARNING "[WARNING]"

public Plugin:myinfo =
{
	name = "Prop Health(ZR mode)",
	author = "Roy (Christian Deacon) & (Owner system) Doshik",
	description = "Props now have health + owner system! (Thanks: Killik, Ire, Grey83, tonline_kms65_1)",
	version = PL_VERSION,
	url = "GFLClan.com && https://steamcommunity.com/id/doshikplayer"
};

enum Props
{
	iHealth,
	Float:fMultiplier
};

// ConVars
new Handle:g_hConfigPath = INVALID_HANDLE;
new Handle:g_hDefaultHealth = INVALID_HANDLE;
new Handle:g_hDefaultMultiplier = INVALID_HANDLE;
new Handle:g_hColor = INVALID_HANDLE;
new Handle:g_hTeamRestriction = INVALID_HANDLE;
new Handle:g_hPrint = INVALID_HANDLE;
new Handle:g_hPrintType = INVALID_HANDLE;
new Handle:g_hPrintMessage = INVALID_HANDLE;
new Handle:g_hDebug = INVALID_HANDLE;

// ConVar Values
new String:g_sConfigPath[PLATFORM_MAX_PATH];
new g_iDefaultHealth;
new Float:g_fDefaultMultiplier;
new String:g_sColor[32];
new g_iTeamRestriction;
new bool:g_bPrint;
new g_iPrintType;
new String:g_sPrintMessage[256];
new bool:g_bDebug;
char zombie[] = "Zombie";
char human[] = "Human";
char spec[] = "Spectator";
new String:admsteam[32];	
new String:plysteam[32];


// Other Variables
new g_arrProp[MAXENTITIES + 1][Props];
new String:g_sLogFile[PLATFORM_MAX_PATH];
new String:g_sLogDel[PLATFORM_MAX_PATH];

new Handle:g_hTimer = INVALID_HANDLE;
new const String:g_Str[] = "Authors of the plugin Roy and Doshik.                                   Special Thanks: Killik, Ire, Grey83, tonline_kms65_1                                   ";
new g_CurrentIndex, g_MaxIndex;

public OnPluginStart()
{
	// ConVars
	CreateConVar("sm_ph_version", PL_VERSION, "Prop Health's version.");
	
	g_hConfigPath = CreateConVar("sm_ph_config_path", "configs/prophealth.props.cfg", "The path to the Prop Health config.");
	HookConVarChange(g_hConfigPath, CVarChanged);
	
	g_hDefaultHealth = CreateConVar("sm_ph_default_health", "1", "A prop's default health if not defined in the config file. -1 = Doesn't break.");
	HookConVarChange(g_hDefaultHealth, CVarChanged);	
	
	g_hDefaultMultiplier = CreateConVar("sm_ph_default_multiplier", "0.00", "Default multiplier based on the player count (for zombies/humans). Default: 65 * 5 (65 damage by right-click knife with 5 hits)");
	HookConVarChange(g_hDefaultMultiplier, CVarChanged);	
	
	g_hColor = CreateConVar("sm_ph_color", "0 0 50 255", "If a prop has a color, set it to this color. -1 = no color. uses RGBA.");
	HookConVarChange(g_hColor, CVarChanged);	
	
	g_hTeamRestriction = CreateConVar("sm_ph_team", "0", "What team are allowed to destroy props? 0 = no restriction, 1 = humans, 2 = zombies.");
	HookConVarChange(g_hTeamRestriction, CVarChanged);		
	
	g_hPrint = CreateConVar("sm_ph_print", "1", "Print the prop's health when damaged to the attacker's chat?");
	HookConVarChange(g_hPrint, CVarChanged);		
	
	g_hPrintType = CreateConVar("sm_ph_print_type", "2", "The print type (if \"sm_ph_print\" is set to 1). 1 = PrintToChat, 2 = PrintCenterText, 3 = PrintHintText.");
	HookConVarChange(g_hPrintType, CVarChanged);		
	
	g_hPrintMessage = CreateConVar("sm_ph_print_message", "Prop Health: %i", "The message to send to the client. Multicolors supported only for PrintToChat. %i = health value.");
	HookConVarChange(g_hPrintMessage, CVarChanged);	
	
	g_hDebug = CreateConVar("sm_ph_debug", "1", "Enable debugging (logging will go to logs/prophealth-debug.log).");
	HookConVarChange(g_hDebug, CVarChanged);
	
	AutoExecConfig(true, "plugin.prop-health");
	
	// Commands
	RegConsoleCmd("sm_getpropinfo", Command_GetPropInfo);
	RegConsoleCmd("sm_zabout", Command_ZAbout);
	RegAdminCmd("sm_deleteprop", Command_DeleteProp, ADMFLAG_SLAY, "Allows an administrator to delete any props.");
}

public CVarChanged(Handle:hCVar, const String:sOldV[], const String:sNewV[])
{
	OnConfigsExecuted();
}

public OnConfigsExecuted()
{
	GetConVarString(g_hConfigPath, g_sConfigPath, sizeof(g_sConfigPath));
	g_iDefaultHealth = GetConVarInt(g_hDefaultHealth);
	g_fDefaultMultiplier = GetConVarFloat(g_hDefaultMultiplier);
	GetConVarString(g_hColor, g_sColor, sizeof(g_sColor));
	g_iTeamRestriction = GetConVarInt(g_hTeamRestriction);
	g_bPrint = GetConVarBool(g_hPrint);
	g_iPrintType = GetConVarInt(g_hPrintType);
	GetConVarString(g_hPrintMessage, g_sPrintMessage, sizeof(g_sPrintMessage));
	g_bDebug = GetConVarBool(g_hDebug);
	
	BuildPath(Path_SM, g_sLogFile, sizeof(g_sLogFile), "logs/zprops/prophealth-debug.log");
	BuildPath(Path_SM, g_sLogDel, sizeof(g_sLogFile), "logs/zprops/zprops-del.log");
}

public OnMapStart()
{
	//PrecacheSound("physics/metal/metal_box_break1.wav");
	//PrecacheSound("physics/metal/metal_box_break2.wav");
}

public OnEntityCreated(iEnt, const String:sClassname[])
{
	SDKHook(iEnt, SDKHook_SpawnPost, OnEntitySpawned);
}

public OnEntitySpawned(iEnt, client)
{
	if (iEnt > MaxClients && IsValidEntity(iEnt))
	{
		decl String:sClassname[MAX_NAME_LENGTH];
		GetEntityClassname(iEnt, sClassname, sizeof(sClassname));
		if (!StrEqual(sClassname, "prop_physics", false) && !StrEqual(sClassname, "prop_dinamyc", false) && !StrEqual(sClassname, "prop_physics_override", false) && !StrEqual(sClassname, "prop_physics_multiplayer", false)) return;
		new owner = GetEntPropEnt(iEnt, Prop_Send, "m_PredictableID"); //получает создателя Entity
		g_arrProp[iEnt][iHealth] = -1;
		g_arrProp[iEnt][fMultiplier] = 0.0;
		SetPropHealth(iEnt);
		if (g_bDebug)
		{
			if(owner <= -1)
			{
				LogToFile(g_sLogFile, "Prop spawned by [ SERVER ]");
			}
			else
			{
				LogToFile(g_sLogFile, "Prop spawned by [ %i ]", owner);
			}
		}
	}
}

public Action:Hook_OnTakeDamage(iEnt, &iAttacker, &iInflictor, &Float:fDamage, &iDamageType)
{
	new owner = GetEntPropEnt(iEnt, Prop_Send, "m_PredictableID"); //получает создателя Entity
	
	if(owner <= 0)
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
	
	if (g_arrProp[iEnt][iHealth] < 0)
	{
		if (g_bDebug)
		{
			LogToFile(g_sLogFile, "Prop %i returned. Prop health under 0.", iEnt, iAttacker);
		}
		
		return Plugin_Continue;
	}
	
	if (g_iTeamRestriction == 1 && ZR_IsClientZombie(iAttacker))
	{
		if (g_bDebug)
		{
			LogToFile(g_sLogFile, "Prop %i returned. Attacker (%i) not on the right team.", iEnt, iAttacker);
		}
		
		return Plugin_Continue;
	}
	
	if (g_iTeamRestriction == 2)
	{
		////////////////////LOGIC HOOK//////////////////
		if(owner <= 0) //Если серверный проп
		{
			if (g_bDebug)
			{
				LogToFile(g_sLogFile, "Prop %i damaged! Attacker (%i) | OWNER ( SERVER/CONSOLE ) [%i]", iEnt, iAttacker, owner);
			}
		}
		else
		{
			if(owner != 400) //Если владелец пропа жив
			{
				if(iAttacker != owner)
				{
					if(GetClientTeam(iAttacker) == 2 && GetClientTeam(owner) == 2) //Если Т ломает проп Т
					{
						PrintCenterText(iAttacker, "Health: [%i] Owner: [%N] (Zombie)", g_arrProp[iEnt][iHealth], owner);
						if (g_bDebug)
						{
							LogToFile(g_sLogFile, "Prop %i returned. Attacker (%i) not OWNER(%i).", iEnt, iAttacker, owner);
						}
						return Plugin_Continue;
					}
					else
					{
						if(GetClientTeam(iAttacker) == 3 && GetClientTeam(owner) == 3) //Если КТ ломает проп КТ
						{
							PrintCenterText(iAttacker, "Health: [%i] Owner: [%N] (Human)", g_arrProp[iEnt][iHealth], owner);
							if (g_bDebug)
							{
								LogToFile(g_sLogFile, "Prop %i returned. Attacker (%i) not OWNER(%i).", iEnt, iAttacker, owner);
							}
							return Plugin_Continue;
						}
					}
				}
				else
				{
					if(iAttacker == owner) //Если владелец ломает свой проп
					{
						if (g_bDebug)
						{
							LogToFile(g_sLogFile, "Prop %i damaged! Attacker owner(%i) || OWNER [%i]", iEnt, iAttacker, owner);
						}
					}
					else
					{
						//3 = CT
						//2 = T
						//1 = SPEC
						if(GetClientTeam(owner) == 2 && GetClientTeam(iAttacker) == 3) //Если Человек ломат проп Зомби
						{
							if (g_bDebug)
							{
								LogToFile(g_sLogFile, "Prop %i damaged! Attacker Human(%i) and Prop Human || OWNER [%i]", iEnt, iAttacker, owner);
							}
						}
						else
						{
							if(GetClientTeam(owner) == 3 && GetClientTeam(iAttacker) == 2) //Если Зомби ломает проп Человека
							{
								if (g_bDebug)
								{
									LogToFile(g_sLogFile, "Prop %i damaged! Attacker Zombie(%i) and Prop Zombie || OWNER [%i]", iEnt, iAttacker, owner);
								}
							}
							else
							{
								if(GetClientTeam(owner) == 1 && GetClientTeam(iAttacker) == 2 || GetClientTeam(owner) == 1 && GetClientTeam(iAttacker) == 3) //Если владелец пропов ушел в спектора
								{
									if (g_bDebug)
									{
										LogToFile(g_sLogFile, "Prop %i damaged! Attacker (%i) and Prop Spectate || OWNER [%i]", iEnt, iAttacker, owner);
									}
								}
							}
						}
					}
				}
			}
			else //Все игроки могут ломать пропы мертвого владельца
			{
				if(GetClientTeam(iAttacker) == 2 || GetClientTeam(iAttacker) == 3)
				{
					PrintCenterText(iAttacker, "Health: [%i] Owner: [%N] (DEATH)", g_arrProp[iEnt][iHealth], owner);
					if (g_bDebug)
					{
						LogToFile(g_sLogFile, "Prop %i damaged! Attacker (%i) and Prop Owner DEATH || OWNER [%i] (DEATH)", iEnt, iAttacker, owner);
					}
				}
			}
		}
		//////////////////////////////////////////////////////////////////////////
	}
	
	g_arrProp[iEnt][iHealth] -= RoundToZero(fDamage);
	
	if (g_bDebug)
	{
		if(owner <= 0)
		{
			LogToFile(g_sLogFile, "Prop Damaged (Prop: %i) (Damage: %f) (Health: %i) (Owner: SERVER) (Attacker: %i)", iEnt, fDamage, g_arrProp[iEnt][iHealth], iAttacker);
		}
		else
		{
			LogToFile(g_sLogFile, "Prop Damaged (Prop: %i) (Damage: %f) (Health: %i) (Owner: %i) (Attacker: %i)", iEnt, fDamage, g_arrProp[iEnt][iHealth], owner, iAttacker);
		}
	}
	
	
	if (g_arrProp[iEnt][iHealth] < 1)
	{
		// Destroy the prop.
		if (g_bDebug)
		{
			LogToFile(g_sLogFile, "Prop Destroyed (Prop: %i) (Attacker: %i)", iEnt, iAttacker);
		}
		if(owner == iAttacker) PrintToChat(iAttacker, "\x07FFFFFF%s You destroyed \x07FFFF38Your\x07FFFFFF object!", PREFIX);
		else if(owner >= 1) PrintToChat(iAttacker, "\x07FFFFFF%s You destroyed prop player \x07FFFF38%N\x07FFFFFF!", PREFIX, owner);
		
		decl String:buffer[32];
		Format(buffer, sizeof(buffer), "dissolve%f", GetRandomFloat());
		DispatchKeyValue(iEnt, "targetname", buffer);
		iEnt = CreateEntityByName("env_entity_dissolver");
		DispatchKeyValue(iEnt, "dissolvetype", "3");
		DispatchKeyValue(iEnt, "target", buffer);
		AcceptEntityInput(iEnt, "dissolve");
		AcceptEntityInput(iEnt, "Kill");
		
		g_arrProp[iEnt][iHealth] = -1;
	}
	
	// Play a sound.
	/*new iRand = GetRandomInt(1, 2);
	switch (iRand)
	{
		case 1:
		{
			new Float:fPos[3];
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fPos);
			//EmitSoundToAll("physics/metal/metal_box_break1.wav", SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, fPos);
		}
		case 2:
		{
			new Float:fPos[3];
			GetEntPropVector(iEnt, Prop_Send, "m_vecOrigin", fPos);
			//EmitSoundToAll("physics/metal/metal_box_break2.wav", SOUND_FROM_WORLD, SNDCHAN_AUTO, SNDLEVEL_NORMAL, SND_NOFLAGS, SNDVOL_NORMAL, SNDPITCH_NORMAL, -1, fPos);
		}
	}*/
	
	// Print To Client
	if (g_bPrint && g_arrProp[iEnt][iHealth] > 0)
	{
		if (g_iPrintType == 1)
		{
			// Print To Chat.
			CPrintToChat(iAttacker, g_sPrintMessage, g_arrProp[iEnt][iHealth]);
		}
		else if (g_iPrintType == 2)
		{
			// Print Center Text.
			if(iAttacker >= 1)
			{
				if(owner <= 0) //Проп сервера
				{
					PrintCenterText(iAttacker, "Health: [%i] Owner: [Server]", g_arrProp[iEnt][iHealth]);
				}
				else
				{
					if(GetClientTeam(owner) == 2) //Проп зомби
					{
						PrintCenterText(iAttacker, g_sPrintMessage, g_arrProp[iEnt][iHealth], owner, zombie);
					}
					else
					{
						if(GetClientTeam(owner) == 3) //Проп человека
						{
							PrintCenterText(iAttacker, g_sPrintMessage, g_arrProp[iEnt][iHealth], owner, human);
						}
						else
						{
							if(GetClientTeam(owner) == 1) //Если владелец пропа ушел в спектаторы
							{
								PrintCenterText(iAttacker, g_sPrintMessage, g_arrProp[iEnt][iHealth], owner, spec);
							}
						}
					}
				}
				
			}
		}
		else if (g_iPrintType == 3)
		{
			// Print Hint Text.
			PrintHintText(iAttacker, g_sPrintMessage, g_arrProp[iEnt][iHealth]);
		}
	}
	
	return Plugin_Continue;
}

public Action:Command_GetPropInfo(iClient, iArgs)
{
	new iEnt = GetClientAimTarget(iClient, false);
	new owner = GetEntPropEnt(iEnt, Prop_Send, "m_PredictableID"); //получает создателя Entity
	
	if (iEnt > MaxClients && IsValidEntity(iEnt))
	{
		decl String:sModelName[PLATFORM_MAX_PATH];
		GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName));
		
		if(owner <= 0)
		{
			PrintToChat(iClient, "\x07FFFFFF%s (Model: %s) (Prop Health: \x0738ff3f%i\x07FFFFFF) (Prop Index: %i) (OwnerID: SERVER) (Your ID: \x07F74545%i\x07FFFFFF)", PREFIX, sModelName, g_arrProp[iEnt][iHealth], iEnt, iClient);
		}
		else
		{
			PrintToChat(iClient, "\x07FFFFFF%s (Model: %s) (Prop Health: \x0738ff3f%i\x07FFFFFF) (Prop Index: %i) (OwnerID: \x07F74545%i\x07FFFFFF) (Owner Name: \x07F74545%N\x07FFFFFF) (Your ID: \x07F74545%i\x07FFFFFF)", PREFIX, sModelName, g_arrProp[iEnt][iHealth], iEnt, owner, owner, iClient);
		}
	}
	else
	{
		PrintToChat(iClient, "\x07FFFFFF%s \x07F74545Prop is either a player or invalid. (Prop Index: %i)", PREFIX, iEnt);
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
	AcceptEntityInput(iEnt, "Kill");
}

public Action:Command_DeleteProp(iClient, iArgs)
{
	new iEnt = GetClientAimTarget(iClient, false);
	new owner = GetEntPropEnt(iEnt, Prop_Send, "m_PredictableID"); //получает создателя Entity
	
	decl String:sModelName[PLATFORM_MAX_PATH];
	GetEntPropString(iEnt, Prop_Data, "m_ModelName", sModelName, sizeof(sModelName)); //model
	
	GetClientAuthId(iClient, AuthIdType:1, admsteam, 64, true); //Admin SteamID
	
	
	decl String:sClassname[MAX_NAME_LENGTH];
	GetEntityClassname(iEnt, sClassname, sizeof(sClassname));
	
	if (!StrEqual(sClassname, "prop_physics", false) && !StrEqual(sClassname, "prop_dinamyc", false) && !StrEqual(sClassname, "prop_physics_override", false) && !StrEqual(sClassname, "prop_physics_multiplayer", false))
	{
		PrintToChat(iClient, "\x07FFFF00%s\x07F74545 This Prop cannot be deleted! (Model: %s)", INFO, sModelName);
		return Plugin_Continue;
	}
	
	if(iEnt > MaxClients && IsValidEntity(iEnt)) //Если проп не является игроком
	{
		if(owner <= 0) //Если проп сервера
		{
			PrintToChat(iClient, "\x07FFFFFF%s You deleted prop! (Model: %s) (OwnerID: SERVER) (Your ID: \x07F74545%i\x07FFFFFF)", PREFIX, sModelName, iClient);
			LogToFile(g_sLogDel, "%s Admin (%N) (SteamID: %s) delete prop (Owner: SERVER) (Model: %s)", PREFIX, iClient, admsteam, sModelName);
			CPrintToChatAll("\x07FFFF00%s\x07FFFFFF Admin \x07F74545%N\x07FFFFFF deleted \x07F74545SERVER\x07FFFFFF prop!", INFO, iClient, owner);
			removeprop(iEnt);
		}
		else
		{	
			if(owner >= 1) //Если проп игрока
			{
				GetClientAuthId(owner, AuthIdType:1, plysteam, 64, true); //Admin SteamID
				PrintToChat(iClient, "\x07FFFFFF%s You deleted prop! (Model: %s) (OwnerID: \x07F74545%i\x07FFFFFF) (Owner Name: \x07F74545%N\x07FFFFFF) (Your ID: \x07F74545%i\x07FFFFFF)", PREFIX, sModelName, owner, owner, iClient);
				LogToFile(g_sLogDel, "%s Admin (%N) (SteamID: %s) delete prop (Owner: %N) (SteamID: %s) (Model: %s)", PREFIX, iClient, admsteam, owner, plysteam, sModelName);
				CPrintToChatAll("\x07FFFF00%s \x07FFFFFFAdmin \x07F74545%N\x07FFFFFF deleted player prop \x07F74545%N\x07FFFFFF!", INFO, iClient, owner);
				removeprop(iEnt);
			}
			else
			{
				if(owner == iClient) //Если админ удаляет свой проп
				{
					LogToFile(g_sLogDel, "%s Admin (%N) (SteamID: %s) delete prop (Owner: %N) (SteamID: %s) (Model: %s)", PREFIX, iClient, admsteam, owner, plysteam, sModelName);
					PrintToChat(iClient, "\x07FFFFFF%s You deleted prop! (Model: %s) (OwnerID: \x07F74545%i\x07FFFFFF) (Owner Name: \x07F74545%N\x07FFFFFF) (Your ID: \x07F74545%i\x07FFFFFF)", PREFIX, sModelName, owner, owner, iClient);
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
		PrintToChat(iClient, "\x07FFFFFF%s \x07F74545Prop is either a player or invalid. (Prop Index: %i)", PREFIX, iEnt);
	}
	return Plugin_Handled;
}

////////////////ABOUT/////////////////
public Action:Command_ZAbout(iClient, iArgs)
{
    /*if (g_hTimer != INVALID_HANDLE)
    {
        KillTimer(g_hTimer);
        g_hTimer = INVALID_HANDLE;
    }
    else*/ if ((g_MaxIndex = (strlen(g_Str) - 1)) > 0)
    {
        g_CurrentIndex = -1;
        msg(iClient);
        g_hTimer = CreateTimer(0.1, g_hTimer_CallBack, iClient, TIMER_REPEAT);
    }
    //return Plugin_Handled;
}

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
    }
    
    PrintCenterText(iClient, s);
}
//////////////////////////////////////
stock SetPropHealth(iEnt)
{
	decl String:sClassname[MAX_NAME_LENGTH];
	GetEntityClassname(iEnt, sClassname, sizeof(sClassname));
	
	if (!StrEqual(sClassname, "prop_physics", false) && !StrEqual(sClassname, "prop_dinamyc", false) && !StrEqual(sClassname, "prop_physics_override", false) && !StrEqual(sClassname, "prop_physics_multiplayer", false))
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
				
				g_arrProp[iEnt][iHealth] = KvGetNum(hKV, "health");
				
				new Float: fMultiplier2 = KvGetFloat(hKV, "multiplier");
				new iClientCount = GetRealClientCount();
				new Float:fAddHealth = float(iClientCount) * fMultiplier2;
				
				g_arrProp[iEnt][iHealth] += RoundToZero(fAddHealth);
				g_arrProp[iEnt][fMultiplier] = fMultiplier2;
				
				if (g_bDebug)
				{
					LogToFile(g_sLogFile, "Custom prop's health set. (Prop: %i) (Prop Health: %i) (Multiplier: %f) (Added Health: %i) (Client Count: %i)", iEnt, g_arrProp[iEnt][iHealth], fMultiplier2, RoundToZero(fAddHealth), iClientCount);
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
	
	if (g_arrProp[iEnt][iHealth] < 1)
	{
		g_arrProp[iEnt][iHealth] = g_iDefaultHealth;
		g_arrProp[iEnt][fMultiplier] = g_fDefaultMultiplier;
		
		new iClientCount = GetRealClientCount();
		new Float:fAddHealth = float(iClientCount) * g_fDefaultMultiplier;
		
		g_arrProp[iEnt][iHealth] += RoundToZero(fAddHealth);
		if (g_bDebug)
		{
			LogToFile(g_sLogFile, "Prop is being set to default health. (Prop: %i) (O - Default Health: %i) (Default Multiplier: %f) (Added Health: %i) (Health: %i) (Client Count: %i)", iEnt, g_iDefaultHealth, g_fDefaultMultiplier, RoundToZero(fAddHealth), g_arrProp[iEnt][iHealth], iClientCount);
		}
	}
	else
	{
		if (g_bDebug)
		{
			LogToFile(g_sLogFile, "Prop already has a health value! (Prop: %i) (Health: %i)", iEnt, g_arrProp[iEnt][iHealth]);
		}
	}
	
	if (g_arrProp[iEnt][iHealth] > 0 && !StrEqual(g_sColor, "-1", false))
	{
		if (g_bDebug)
		{
			LogToFile(g_sLogFile, "Prop is being colored! (Prop: %i)", iEnt);
		}
		
		// Set the entities color.
		decl String:sBit[4][32];
		
		ExplodeString(g_sColor, " ", sBit, sizeof (sBit), sizeof (sBit[]));
		SetEntityRenderColor(iEnt, StringToInt(sBit[0]), StringToInt(sBit[1]), StringToInt(sBit[2]), StringToInt(sBit[3]));
	}
	
	if (g_arrProp[iEnt][iHealth] > 0)
	{
		SDKHook(iEnt, SDKHook_OnTakeDamage, Hook_OnTakeDamage);
	}
}

stock GetRealClientCount()
{
	new iCount;
	
	for (new i = 1; i <= MaxClients; i++)
	{
		if (IsClientInGame(i) && GetClientTeam(i) != 1)
		{
			iCount++;
		}
	}
	
	return iCount;
}
