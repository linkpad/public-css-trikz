#include <shavit/core>
#include <morecolors>

#include <shavit/partner>

#undef REQUIRE_PLUGIN
#include <shavit/rankings>

#pragma semicolon 1
#pragma newdecls required

char gS_CMD_Partner[][] = {"sm_partner"};
char gS_CMD_UnPartner[][] = {"sm_unpartner", "sm_breakup"};
int gI_Partner[MAXPLAYERS + 1] = {-1, ...};

// forwards
Handle gH_Forwards_OnPartner = null;
Handle gH_Forwards_OnBreakPartner = null;

public Plugin myinfo =
{
	name = "[shavit] Trikz partner",
	author = "Linkpad",
	description = "trikz Partner for shavit timer",
	version = "0.1",
	url = ""
};

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	CreateNative("Timer_GetPartner", Native_GetPartner);
	CreateNative("Timer_SetPartner", Native_SetPartner);

	// forwards
	gH_Forwards_OnPartner = CreateGlobalForward("Trikz_OnPartner", ET_Event, Param_Cell, Param_Cell);
	gH_Forwards_OnBreakPartner = CreateGlobalForward("Trikz_OnBreakPartner", ET_Event, Param_Cell, Param_Cell);

	RegPluginLibrary("shavit-partner");

	return APLRes_Success;
}

public void OnPluginStart()
{	
	for(int i = 0; i < sizeof(gS_CMD_Partner); i++)
	{
		RegConsoleCmd(gS_CMD_Partner[i], Command_Partner, "Select your partner.");
	}
	
	for(int i = 0; i < sizeof(gS_CMD_UnPartner); i++)
	{
		RegConsoleCmd(gS_CMD_UnPartner[i], Command_UnPartner, "Disable your partnership.");
	}

	HookEvent("player_death", Event_PlayerDeath);
	HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Post);
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	
	int iPartner = gI_Partner[client];
	
	if(gI_Partner[client] != -1 && gI_Partner[iPartner] != -1)
	{
		Call_StartForward(gH_Forwards_OnBreakPartner);
		Call_PushCell(client);
		Call_PushCell(iPartner);
		Call_Finish();
		
		gI_Partner[client] = -1;
		gI_Partner[iPartner] = -1;
		
		if(Shavit_GetTimerStatus(client) == Timer_Running || Shavit_GetTimerStatus(client) == Timer_Paused)
		{
			Shavit_StopTimer(client);
			Shavit_StopTimer(iPartner);
		}
	}
}

public void OnClientDisconnect(int client)
{
	if (IsFakeClient(client)) {
		int iPartner = gI_Partner[client];

		if(gI_Partner[client] != -1 && gI_Partner[iPartner] != -1)
		{
			Call_StartForward(gH_Forwards_OnBreakPartner);
			Call_PushCell(client);
			Call_PushCell(iPartner);
			Call_Finish();

			gI_Partner[client] = -1;
			gI_Partner[iPartner] = -1;
		}
	}
}

public void Event_PlayerDisconnect(Event event, char[] name, bool dontBroadcast)
{
	int client = GetClientOfUserId(event.GetInt("userid"));
	if (gI_Partner[client] != -1)
	{
		if (IsValidEdict(gI_Partner[client]))
		{
			CPrintToChat(gI_Partner[client], "{default}[{red}Trikz{default}] Your team has been cancelled.");
		}

		Call_StartForward(gH_Forwards_OnBreakPartner);
		Call_PushCell(client);
		Call_PushCell(gI_Partner[client]);
		Call_Finish();

		Shavit_StopTimer(gI_Partner[client]);
		Shavit_StopTimer(client);

		gI_Partner[gI_Partner[client]] = -1;
		gI_Partner[client] = -1;
    }
}

Action Command_Partner(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	if(!IsPlayerAlive(client))
	{
		CPrintToChat(client, "{white}You must be alive to use this feature!");
		
		return Plugin_Handled;
	}
	
	if(gI_Partner[client] != -1)
	{
		CPrintToChat(client, "{white}You already have a partner.");
		
		return Plugin_Handled;
	}
	
	PartnerMenu(client);
	
	return Plugin_Handled;
}

void PartnerMenu(int client)
{
	Menu menu = new Menu(PartnerAsk_MenuHandler);
	menu.SetTitle("Select your partner:\n ");
	
	char sDisplay[MAX_NAME_LENGTH];
	char sClientID[8];
	
	for(int i = 1; i <= MaxClients; i++)
	{
		if(i == client)
		{
			continue;
		}
		
		if(IsValidClient(i, true) && !IsFakeClient(i) && !IsClientSourceTV(i) && gI_Partner[i] == -1)
		{
			GetClientName(i, sDisplay, MAX_NAME_LENGTH);
			ReplaceString(sDisplay, MAX_NAME_LENGTH, "#", "?");
			IntToString(i, sClientID, sizeof(sClientID));
			menu.AddItem(sClientID, sDisplay);
		}
	}
	
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	
	if(menu.ItemCount > 0)
	{
		DisplayMenu(menu, client, MENU_TIME_FOREVER);
	}
	
	else
	{
		CPrintToChat(client, "{white}No partners are available.");
		
		delete menu;
	}
}

int PartnerAsk_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{	
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			int client = StringToInt(info);
			
			if(IsValidClient(client, true) && IsValidClient(param1, true) && gI_Partner[client] == -1)
			{
				Menu menuask = new Menu(Partner_MenuHandler);
				menuask.SetTitle("%N wants to be your partner\n ", param1);
				char sDisplay[32];
				char sMenuInfo[32];
				IntToString(param1, sMenuInfo, sizeof(sMenuInfo));
				FormatEx(sDisplay, MAX_NAME_LENGTH, "Accept");
				menuask.AddItem(sMenuInfo, "Accept\n ");
				FormatEx(sDisplay, MAX_NAME_LENGTH, "Deny");
				menuask.AddItem(sMenuInfo, "Deny");
				menuask.ExitButton = false;
				menuask.Display(client, MENU_TIME_FOREVER);
			}
			
			else if(gI_Partner[client] != -1)
			{
				CPrintToChat(client, "{orange}%N {white}wants to be your partner.", param1);
			}
		}
		
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				FakeClientCommand(param1, "sm_trikz");
			}
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

int Partner_MenuHandler(Menu menuask, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menuask.GetItem(param2, info, sizeof(info));
			
			int client = StringToInt(info);
			
			if(gI_Partner[client] == -1)
			{
				switch(param2)
				{
					case 0:
					{
						gI_Partner[client] = param1; //partner = param1
						gI_Partner[param1] = client; //client = client
						
						Call_StartForward(gH_Forwards_OnPartner);
						Call_PushCell(client);
						Call_PushCell(param1);
						Call_Finish();
						
						Shavit_StopTimer(client);
						Shavit_StopTimer(param1);

						CPrintToChat(client, "{orange}%N {white}has accepted your partnership request.", param1);
						CPrintToChat(param1, "{white}You accepted partnership request with {orange}%N.", client);
					}
					
					case 1:
					{
						CPrintToChat(client, "{orange}%N {white}has denied your partnership request.", param1);
						CPrintToChat(param1, "{white}You denied partnership request with {orange}%N.", client);
					}
				}
			}
			
			else
			{
				CPrintToChat(param1, "{orange}%N {white}already have a partner.", client);
			}
		}
		
		case MenuAction_End:
		{
			delete menuask;
		}
	}
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	if(!IsPlayerAlive(client) && GetEntProp(client, Prop_Data, "m_afButtonPressed") & IN_USE)
	{
		int nObserverMode = GetEntProp(client, Prop_Send, "m_iObserverMode");
		int nObserverTarget = GetEntPropEnt(client, Prop_Send, "m_hObserverTarget");
	
		if(4 <= nObserverMode <= 6 && !IsFakeClient(nObserverTarget))
		{
			int iPartner = Timer_GetPartner(nObserverTarget);
			
			if(iPartner != -1)
			{
				SetEntPropEnt(client, Prop_Send, "m_hObserverTarget", iPartner);
			}
		}
	}
}

Action Command_UnPartner(int client, int args)
{
	if(!IsValidClient(client))
	{
		return Plugin_Handled;
	}
	
	if(gI_Partner[client] == -1)
	{
		CPrintToChat(client, "{white}You need a partner to cancel your partnership with the current one.");
		
		return Plugin_Handled;
	}
	
	UnPartnerMenu(client);
	
	return Plugin_Handled;
}

void UnPartnerMenu(int client)
{
	Menu menu = new Menu(UnPartnerAsk_MenuHandler);
	menu.SetTitle("Do you want to cancel your partnership with %N\n ", gI_Partner[client]);
	menu.AddItem("sm_accept", "Accept\n ");
	menu.AddItem("sm_deny", "Deny");
	menu.ExitBackButton = true;
	menu.ExitButton = true;
	menu.Display(client, MENU_TIME_FOREVER);
}

int UnPartnerAsk_MenuHandler(Menu menu, MenuAction action, int param1, int param2)
{
	switch(action)
	{
		case MenuAction_Select:
		{
			char info[32];
			menu.GetItem(param2, info, sizeof(info));
			
			if(StrEqual(info, "sm_accept"))
			{
				int iPartner = gI_Partner[param1];
				
				if(gI_Partner[param1] != -1 && gI_Partner[iPartner] != -1)
				{
					gI_Partner[param1] = -1; //client
					gI_Partner[iPartner] = -1; //partner
					Call_StartForward(gH_Forwards_OnBreakPartner);
					Call_PushCell(param1);
					Call_PushCell(iPartner);
					Call_Finish();
					Shavit_StopTimer(param1);
					Shavit_StopTimer(iPartner);
					CPrintToChat(param1, "{orange}%N {white}is not your partner anymore.", iPartner);
					CPrintToChat(iPartner, "{orange}%N {white}has disabled his partnership with you.", param1);
				}
				
				else if(gI_Partner[param1] == -1)
				{
					CPrintToChat(param1, "{white}You don't have partner anymore.");
				}
			}
			
			if(StrEqual(info, "sm_deny"))
			{
				if(gI_Partner[param1] == -1)
				{
					CPrintToChat(param1, "{white}You don't have partner anymore.");
				}
			}
		}
		
		case MenuAction_Cancel:
		{
			if(param2 == MenuCancel_ExitBack)
			{
				FakeClientCommand(param1, "sm_trikz");
			}
		}
		
		case MenuAction_End:
		{
			delete menu;
		}
	}
}

int Native_GetPartner(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	
	if(!IsValidClient(client))
	{
		return 0;
	}

	if(gI_Partner[client] != -1 && client == gI_Partner[gI_Partner[client]])
	{
		return gI_Partner[client];
	}
	
	return 0;
}

int Native_SetPartner(Handle handler, int numParams)
{
	int client = GetNativeCell(1);
	int partner = GetNativeCell(2);

	gI_Partner[client] = partner;
	gI_Partner[partner] = client;

	Call_StartForward(gH_Forwards_OnPartner);
	Call_PushCell(client);
	Call_PushCell(partner);
	Call_Finish();
}