
#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <zombiereloaded>
#include <multicolors>

#define PL_VERSION "1.5"
#define MAXENTITIES 2048

public Plugin:myinfo =
{
	name = "[All] Prop Health(ZR mode)",
	author = "Roy (Christian Deacon | Author) & Doshik (Added Owner system)",
	description = "Props now have health + owner system!",
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

// Other Variables
new g_arrProp[MAXENTITIES + 1][Props];
new String:g_sLogFile[PLATFORM_MAX_PATH];

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
	
	BuildPath(Path_SM, g_sLogFile, sizeof(g_sLogFile), "logs/prophealth-debug.log");
}

public OnMapStart()
{
	PrecacheSound("physics/metal/metal_box_break1.wav");
	PrecacheSound("physics/metal/metal_box_break2.wav");
}

public OnEntityCreated(iEnt, const String:sClassname[])
{
	SDKHook(iEnt, SDKHook_SpawnPost, OnEntitySpawned);
}

public OnEntitySpawned(iEnt, client)
{
	if (iEnt > MaxClients && IsValidEntity(iEnt))
	{
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
			if(iAttacker != owner)
			{
				if(GetClientTeam(iAttacker) == 2 && GetClientTeam(owner) == 2 || GetClientTeam(iAttacker) == 3 && GetClientTeam(owner) == 3) //Если КТ ломает проп КТ или Т проп Т
				{
					PrintCenterText(iAttacker, "Health: [%i] Owner: [%N]", g_arrProp[iEnt][iHealth], owner);
					if (g_bDebug)
					{
						LogToFile(g_sLogFile, "Prop %i returned. Attacker (%i) not OWNER(%i).", iEnt, iAttacker, owner);
					}
					return Plugin_Continue;
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
					if(!ZR_IsClientHuman(owner)) //Проп зомби
					{
						PrintCenterText(iAttacker, g_sPrintMessage, g_arrProp[iEnt][iHealth], owner, zombie);
					}
					else
					{
						if(!ZR_IsClientZombie(owner)) //Проп человека
						{
							PrintCenterText(iAttacker, g_sPrintMessage, g_arrProp[iEnt][iHealth], owner, human);
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
		
		decl String:sClassname[MAX_NAME_LENGTH];
		new sPropdebug = GetEntityClassname(iEnt, sClassname, sizeof(sClassname));
		if(owner <= 0)
		{
			PrintToChat(iClient, "\x03[PH]\x02(Model: %s) (Prop Health: %i) (Prop Index: %i) (Prop Class: %s) (Owner: SERVER) (You: %i)", sModelName, g_arrProp[iEnt][iHealth], iEnt, sPropdebug, iClient);
		}
		else
		{
			PrintToChat(iClient, "\x03[PH]\x02(Model: %s) (Prop Health: %i) (Prop Index: %i) (Prop Class: %s) (Owner: %i) (You: %i)", sModelName, g_arrProp[iEnt][iHealth], iEnt, sPropdebug, owner, iClient);
		}
	}
	else
	{
		PrintToChat(iClient, "\x03[PH]\x02Prop is either a player or invalid. (Prop Index: %i)", iEnt);
	}
	return Plugin_Handled;
}

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