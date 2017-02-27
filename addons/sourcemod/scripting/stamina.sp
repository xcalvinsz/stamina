#include <sourcemod>
#include <sdktools>
#include <tf2attributes>
#include <tf2>
#include <tf2_stocks>

#define PLUGIN_VERSION "1.1"

ConVar g_cEnabled, g_cSpeed, g_cClass, g_cDrain, g_cRegen, g_cHudX, g_cHudY, g_cTeam;
int g_iLastButton[MAXPLAYERS + 1];
int g_iButtonCount[MAXPLAYERS + 1];
int g_iClientClass[MAXPLAYERS + 1];
int g_iClientTeam[MAXPLAYERS + 1];
bool g_bAccess[MAXPLAYERS + 1];
float g_fStamina[MAXPLAYERS + 1];
Handle g_hResetTimer[MAXPLAYERS + 1];
Handle g_hStaminaTimer[MAXPLAYERS + 1];
Handle g_hHudSync;
/*
enum (<<= 1)
{
	SCOUT = 1,
	SOLDIER,
	PYRO,
	DEMOMAN,
	HEAVY,
	ENGINEER,
	MEDIC,
	SNIPER,
	SPY
}*/

public Plugin myinfo = 
{
	name = "[TF2] Stamina Sprinting",
	author = "Tak (Chaosxk)",
	description = "Allows players to sprint by double tapping forward button.",
	version = PLUGIN_VERSION,
	url = "https://github.com/xcalvinsz/stamina"
}

public void OnPluginStart()
{
	CreateConVar("sm_stamina_version", "1.0", PLUGIN_VERSION, FCVAR_SPONLY|FCVAR_REPLICATED|FCVAR_NOTIFY);
	g_cEnabled = CreateConVar("sm_stamina_enabled", "1", "Enables/Disables stamina sprinting.");
	g_cSpeed = CreateConVar("sm_stamina_speed", "1.75", "Speed increase value when sprinting.");
	g_cClass = CreateConVar("sm_stamina_class", "511", "Bit-Wise operation to determine which class can sprint.");
	g_cDrain = CreateConVar("sm_stamina_drain", "0.1", "How fast to drain stamina, 0.1 is fastest.");
	g_cRegen = CreateConVar("sm_stamina_regen", "0.5", "How fast to regenerate stamina, 0.1 is fastest.");
	g_cHudX = CreateConVar("sm_stamina_hudx", "0.0", "X coordinate of HUD display.");
	g_cHudY = CreateConVar("sm_stamina_hudy", "1.0", "Y coordinate of HUD display.");
	g_cTeam = CreateConVar("sm_stamina_team", "1", "0 - None, 1 - Both, 2 - Red, 3 - Blue");
	
	HookEvent("player_changeclass", Hook_ClassChange);
	HookEvent("player_team", Hook_TeamChange);
	
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i))
			continue;
		OnClientPostAdminCheck(i);
		g_iClientClass[i] = view_as<int>(TF2_GetPlayerClass(i)) - 1;
		g_iClientTeam[i] = GetClientTeam(i);
	}
	
	CreateTimer(0.1, Timer_Hud, _, TIMER_REPEAT);
	g_hHudSync = CreateHudSynchronizer();
	
	AutoExecConfig(false, "stamina");  
}

//Cache client class because i don't want to call this constantly under a timer/onplayerruncmd
public Action Hook_ClassChange(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_iClientClass[client] = event.GetInt("class") - 1;
}

//Cache client team because i don't want to call this constantly under a timer/onplayerruncmd
public Action Hook_TeamChange(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	g_iClientTeam[client] = event.GetInt("team");
}

//Make sure when map changes that we reset everything and close the timers properly to prevent any memory leaks
public void OnMapEnd()
{
	for (int i = 1; i <= MaxClients; i++)
	{
		delete g_hResetTimer[i];
		delete g_hStaminaTimer[i];
		g_iLastButton[i] = 0;
		g_iButtonCount[i] = 0;
		g_fStamina[i] = 100.0;
	}
}

public void OnClientPostAdminCheck(int client)
{
	g_iLastButton[client] = 0;
	g_iButtonCount[client] = 0;
	g_fStamina[client] = 100.0;
	g_bAccess[client] = CheckCommandAccess(client, "sm_stamina_override", ADMFLAG_GENERIC, false);
	delete g_hResetTimer[client];
	delete g_hStaminaTimer[client];
}

public Action Timer_Hud(Handle hTimer)
{
	if (!g_cEnabled.BoolValue)
		return Plugin_Continue;
		
	for (int i = 1; i <= MaxClients; i++)
	{
		if (!IsClientInGame(i) || !g_bAccess[i] || !IsPlayerAlive(i) || !CanClientSprint(i))
			continue;
		SetHudTextParams(g_cHudX.FloatValue, g_cHudY.FloatValue, 0.1, 0, 255, 0, 255, 0, 0.0, 0.1, 0.1);
		ShowSyncHudText(i, g_hHudSync, "Stamina: %.0f%%", g_fStamina[i]);
	}
	
	return Plugin_Continue;
}

//This whole logic was annoying to figure out (^);;)>
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3], float angles[3], int &weapon)
{
	if (!g_cEnabled.BoolValue || !g_bAccess[client] || !IsPlayerAlive(client) || !CanClientSprint(client))
		return Plugin_Continue;
		
	if ((buttons & IN_FORWARD))
	{
		if (!(g_iLastButton[client] & IN_FORWARD))
		{
			//Pressed how many times
			g_iButtonCount[client]++;
			
			if (g_iButtonCount[client] == 1)
			{
				delete g_hResetTimer[client];
				g_hResetTimer[client] = CreateTimer(0.2, Timer_ResetButtonCount, GetClientUserId(client));
			}
			else if (g_iButtonCount[client] == 2)
			{
				delete g_hResetTimer[client];
				delete g_hStaminaTimer[client];
				float offset = GetSpeedOffset(client);
				AddAttribute(client, 107, g_cSpeed.FloatValue/offset);
				g_iButtonCount[client] = -1;
				g_hStaminaTimer[client] = CreateTimer(g_cDrain.FloatValue, Timer_Drain, GetClientUserId(client), TIMER_REPEAT);
			}
		}
	}
	else if ((g_iLastButton[client] & IN_FORWARD))
	{
		//-1 says that client press button twice, 0 from timer meaning he didn't press twice and it resets the count
		if (g_iButtonCount[client] == -1)
		{
			delete g_hStaminaTimer[client];
			RemoveAttribute(client, 107);
			g_iButtonCount[client] = 0;
			g_hStaminaTimer[client] = CreateTimer(g_cRegen.FloatValue, Timer_Regenerate, GetClientUserId(client), TIMER_REPEAT);
	}
	}
	
	//Cache old buttons so that we can use it to execute our code 1 at a time instead of 66 FPS
	g_iLastButton[client] = buttons;
	return Plugin_Continue;
}

public Action Timer_ResetButtonCount(Handle hTimer, int userid)
{
	int client = GetClientOfUserId(userid);
	g_iButtonCount[client] = 0;
	g_hResetTimer[client] = null;
}

//Timer callback to drain stamina from client
public Action Timer_Drain(Handle hTimer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (g_fStamina[client] <= 0.0)
	{
		RemoveAttribute(client, 107);
		//TF2_RemoveCondition(client, TFCond_SpeedBuffAlly);
		g_hStaminaTimer[client] = CreateTimer(g_cRegen.FloatValue, Timer_Regenerate, userid, TIMER_REPEAT);
		return Plugin_Stop;
	}
	g_fStamina[client] -= 2.0;
	return Plugin_Continue;
}

//Timer callback to regenerate stamina to client
public Action Timer_Regenerate(Handle hTimer, int userid)
{
	int client = GetClientOfUserId(userid);
	if (g_fStamina[client] >= 100.0)
	{
		g_hStaminaTimer[client] = null;
		return Plugin_Stop;
	}
	g_fStamina[client]++;
	return Plugin_Continue;
}

//Sets players speed then reset their cache by adding a small condition?
void AddAttribute(int client, int index, float value)
{
	TF2Attrib_SetByDefIndex(client, index, value);
	TF2_AddCondition(client, TFCond_SpeedBuffAlly, TFCondDuration_Infinite);
}

//Remove the speed attribute and the speedbuffally effect
void RemoveAttribute(int client, int index)
{
	TF2Attrib_RemoveByDefIndex(client, index);
	TF2_RemoveCondition(client, TFCond_SpeedBuffAlly);
}

//Bit-Wise operation to determine if player class can sprint
bool CanClientSprint(int client)
{
	int bit = 1 << g_iClientClass[client];
	return (g_cClass.IntValue & bit) && (g_cTeam.IntValue == 1 || g_cTeam.IntValue == g_iClientTeam[client]) ? true : false;
}

//Gets the offset speed that TFCond_SpeedBuffAlly adds so we can offset it
float GetSpeedOffset(int client)
{
	switch(TF2_GetPlayerClass(client))
	{
		case TFClass_Scout:
			return 1.2625;
		case TFClass_Soldier:
			return 1.4;
		case TFClass_Pyro:
			return 1.35;
		case TFClass_DemoMan:
			return 1.375;
		case TFClass_Heavy:
			return 1.4;
		case TFClass_Engineer:
			return 1.35;
		case TFClass_Medic:
			return 1.328125;
		case TFClass_Sniper:
			return 1.35;
		case TFClass_Spy:
			return 1.328125;
	}
	return -1.0;
}