#include <sourcemod>
#include <sdktools>
#include <sdkhooks>

#pragma semicolon 1
#pragma newdecls required

#define MAXENTITIES 2048
#define ZERO_VECTOR view_as<float>({ 0, 0, 0 })

public Plugin myinfo =
{
	name		= "boost-fix",
	author		= "Tengu, Linkpad (some edits)",
	description = "<insert_description_here>",
	version		= "0.1",
	url			= "http://steamcommunity.com/id/tengulawl/"
};

bool  g_lateLoaded;
int	  g_skyFrame[MAXPLAYERS + 1];
int	  g_skyStep[MAXPLAYERS + 1];
float g_skyVel[MAXPLAYERS + 1][3];
float g_fallSpeed[MAXPLAYERS + 1];
int	  g_boostStep[MAXPLAYERS + 1];
int	  g_boostEnt[MAXPLAYERS + 1];
float g_boostVel[MAXPLAYERS + 1][3];
float g_boostTime[MAXPLAYERS + 1];
float g_playerVel[MAXPLAYERS + 1][3];
int	  g_playerFlags[MAXPLAYERS + 1];
bool  g_groundBoost[MAXPLAYERS + 1];
bool  g_bouncedOff[MAXENTITIES];
bool  g_boosterDuck[MAXPLAYERS + 1];

public APLRes AskPluginLoad2(Handle myself, bool late, char[] error, int err_max)
{
	g_lateLoaded = late;
}

public void OnPluginStart()
{
	if (g_lateLoaded)
	{
		OnMapStart();
	}
}

public void OnMapStart()
{
	if (g_lateLoaded)
	{
		for (int i = 1; i <= MaxClients; i++)
		{
			if (IsClientInGame(i))
			{
				OnClientPutInServer(i);
			}
		}
		g_lateLoaded = false;
	}
}

public void OnClientPutInServer(int client)
{
	SDKHook(client, SDKHook_StartTouch, Client_StartTouch);
	SDKHook(client, SDKHook_PostThinkPost, Client_PostThinkPost);
}

public void OnClientDisconnect(int client)
{
	g_skyFrame[client]	  = 0;
	g_skyStep[client]	  = 0;
	g_boostStep[client]	  = 0;
	g_boostTime[client]	  = 0.0;
	g_playerFlags[client] = 0;
}

public Action Client_StartTouch(int client, int other)
{
	if (!IsValidClient(other, true) || g_playerFlags[other] & FL_ONGROUND || g_skyFrame[other] || g_boostStep[client] || GetGameTime() - g_boostTime[client] < 0.15)
	{
		return;
	}

	float clientOrigin[3];
	GetEntPropVector(client, Prop_Data, "m_vecOrigin", clientOrigin);

	float otherOrigin[3];
	GetEntPropVector(other, Prop_Data, "m_vecOrigin", otherOrigin);

	float clientMaxs[3];
	GetEntPropVector(client, Prop_Data, "m_vecMaxs", clientMaxs);

	float delta = otherOrigin[2] - clientOrigin[2] - clientMaxs[2];

	if (delta > 0.0 && delta < 2.0)
	{
		float velocity[3];
		GetAbsVelocity(client, velocity);

		if (velocity[2] > 0.0 && !(GetClientButtons(other) & IN_DUCK) && !(GetEntityFlags(client) & FL_ONGROUND))
		{
			if (clientMaxs[2] <= 45 && velocity[2] > 250.0)
			{
				g_boosterDuck[other] = true;
			}
			else
			{
				g_boosterDuck[other] = false;
			}
			g_skyFrame[other] = 1;

			// fix onground not being made everytime
			int prevFlags	  = GetEntityFlags(other);
			SetEntityFlags(other, prevFlags | FL_ONGROUND);
			SetEntPropEnt(other, Prop_Send, "m_hGroundEntity", client);

			if (velocity[2] <= 290)
			{
				g_skyStep[other] = 1;
			}
			else
			{
				g_skyStep[other] = 2;
			}

			g_skyVel[other] = velocity;
			GetAbsVelocity(other, velocity);
			g_fallSpeed[other] = FloatAbs(velocity[2]);
		}
	}
}

public void Client_PostThinkPost(int client)
{
	if (g_skyFrame[client])
	{
		if (g_boostStep[client] || (++g_skyFrame[client] >= 5 && g_skyStep[client] != 2 && g_skyStep[client] != 3))
		{
			g_skyFrame[client] = 0;
			g_skyStep[client]  = 0;
		}
	}

	if (g_boostStep[client] == 1)
	{
		int entity = EntRefToEntIndex(g_boostEnt[client]);

		if (entity != INVALID_ENT_REFERENCE)
		{
			float velocity[3];
			GetAbsVelocity(entity, velocity);

			if (velocity[2] > 0.0)
			{
				velocity[0] = g_boostVel[client][0] * 0.135;
				velocity[1] = g_boostVel[client][1] * 0.135;
				velocity[2] = g_boostVel[client][2] * -0.135;

				DumbSetVelocity(entity, velocity);
			}
		}

		g_boostStep[client] = 2;
	}
}

public Action OnPlayerRunCmd(int client, int& buttons, int& impulse, float vel[3], float angles[3], int& weapon, int& subtype, int& cmdnum, int& tickcount, int& seed, int mouse[2])
{
	g_playerFlags[client] = GetEntityFlags(client);

	if (g_skyFrame[client] && g_boostStep[client])
	{
		g_skyFrame[client] = 0;
		g_skyStep[client]  = 0;
	}

	if (!g_skyStep[client] && !g_boostStep[client])
	{
		if (GetGameTime() - g_boostTime[client] < 0.15)
		{
			float basevel[3];
			SetBaseVelocity(client, basevel);
		}
		return Plugin_Continue;
	}

	float velocity[3];
	SetBaseVelocity(client, velocity);

	if (g_skyStep[client])
	{
		if (g_skyStep[client] == 1)
		{
			int flags = g_playerFlags[client];
			if (flags & FL_ONGROUND && buttons & IN_JUMP)
			{
				g_skyStep[client] = 2;
			}
		}
		else if (g_skyStep[client] == 2)
		{
			if (g_skyVel[client][2] > 250.0 && g_skyVel[client][2] <= 290.0)
			{
				float testing = g_skyVel[client][2] - 250;

				if (testing > 5.0)
					testing = 5.0;

				if (g_skyVel[client][2] > 280.0)
					testing = 10.0;

				g_skyVel[client][2] = 250.0 + testing;
			}

			float vecabsvel[3];
			GetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", vecabsvel);

			// no z speed so we set it to the correct value it should be
			if (vecabsvel[2] <= 1.0)
			{
				if (g_fallSpeed[client] < 300)
				{
					vecabsvel[2] = g_skyVel[client][2] * 0.9745;
				}
				else {
					vecabsvel[2] = 290.113403; // thats the capped value u can get after hitting partner, magic number :D
				}
				SetAbsVelocity(client, vecabsvel);
			}

			GetAbsVelocity(client, velocity);

			velocity[0] -= g_skyVel[client][0];
			velocity[1] -= g_skyVel[client][1];
			velocity[2] += g_skyVel[client][2];

			DumbSetVelocity(client, velocity);

			g_skyStep[client] = 3;
		}
		else if (g_skyStep[client] == 3)
		{
			GetAbsVelocity(client, velocity);

			if (g_boosterDuck[client])
			{
				if (g_fallSpeed[client] < 300.0)
				{
					g_skyVel[client][2] *= g_fallSpeed[client] / 300.0;
				}
			}

			velocity[0] += g_skyVel[client][0];
			velocity[1] += g_skyVel[client][1];
			if (g_skyVel[client][2] > 290)
			{
				velocity[2] = g_skyVel[client][2];
			}
			else
			{
				velocity[2] += g_skyVel[client][2];
			}

			DumbSetVelocity(client, velocity);

			g_boosterDuck[client] = false;
			g_skyStep[client]	  = 0;
		}
	}

	// flashboost
	if (g_boostStep[client])
	{
		if (g_boostStep[client] == 2)
		{
			velocity[0] = g_playerVel[client][0] - g_boostVel[client][0];
			velocity[1] = g_playerVel[client][1] - g_boostVel[client][1];
			velocity[2] = g_boostVel[client][2];

			DumbSetVelocity(client, velocity);

			g_boostStep[client] = 3;
		}
		else if (g_boostStep[client] == 3)
		{
			GetAbsVelocity(client, velocity);

			if (g_groundBoost[client])
			{
				velocity[0] += g_boostVel[client][0];
				velocity[1] += g_boostVel[client][1];
				velocity[2] += g_boostVel[client][2];
			}
			else
			{
				velocity[0] += g_boostVel[client][0] * 0.135;
				velocity[1] += g_boostVel[client][1] * 0.135;
			}

			DumbSetVelocity(client, velocity);

			g_boostStep[client] = 0;
		}
	}

	return Plugin_Continue;
}

public void OnEntityCreated(int entity, const char[] classname)
{
	if (StrContains(classname, "_projectile") != -1)
	{
		g_bouncedOff[entity] = false;
		SDKHook(entity, SDKHook_StartTouch, Projectile_StartTouch);
		SDKHook(entity, SDKHook_EndTouch, Projectile_EndTouch);
	}
}

public Action Projectile_StartTouch(int entity, int client)
{
	if (!IsValidClient(client, true))
	{
		return Plugin_Continue;
	}

	CreateTimer(0.25, Timer_RemoveEntity, EntIndexToEntRef(entity), TIMER_FLAG_NO_MAPCHANGE);

	if (g_boostStep[client] || g_playerFlags[client] & FL_ONGROUND)
	{
		return Plugin_Continue;
	}

	float entityOrigin[3];
	GetEntityAbsOrigin(entity, entityOrigin);

	float clientOrigin[3];
	GetClientAbsOrigin(client, clientOrigin);

	float entityMaxs[3];
	GetEntityMaxs(entity, entityMaxs);

	float delta = clientOrigin[2] - entityOrigin[2] - entityMaxs[2];

	if (delta > 0.0 && delta < 2.0)
	{
		g_boostStep[client] = 1;
		g_boostEnt[client]	= EntIndexToEntRef(entity);
		GetAbsVelocity(entity, g_boostVel[client]);
		GetAbsVelocity(client, g_playerVel[client]);
		g_groundBoost[client] = g_bouncedOff[entity];
		g_boostTime[client]	  = GetGameTime();
	}

	return Plugin_Continue;
}

public Action Projectile_EndTouch(int entity, int other)
{
	if (!other)
	{
		g_bouncedOff[entity] = true;
	}
}

public Action Timer_RemoveEntity(Handle timer, any entref)
{
	int entity = EntRefToEntIndex(entref);

	if (entity != INVALID_ENT_REFERENCE)
	{
		AcceptEntityInput(entity, "Kill");
	}
}

bool IsValidClient(int client, bool alive = false)
{
	return client > 0 && client <= MaxClients && IsClientInGame(client) && (!alive || IsPlayerAlive(client));
}

void GetEntityAbsOrigin(int entity, float vec[3])
{
	GetEntPropVector(entity, Prop_Send, "m_vecOrigin", vec);
}

void GetAbsVelocity(int entity, float vec[3])
{
	GetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vec);
}

void GetEntityMaxs(int entity, float vec[3])
{
	GetEntPropVector(entity, Prop_Send, "m_vecMaxs", vec);
}

void SetBaseVelocity(int entity, const float vec[3])
{
	SetEntPropVector(entity, Prop_Data, "m_vecBaseVelocity", vec);
}

void SetAbsVelocity(int entity, const float vec[3])
{
	SetEntPropVector(entity, Prop_Data, "m_vecAbsVelocity", vec);
}

void DumbSetVelocity(int client, float fSpeed[3])
{
	SetEntPropVector(client, Prop_Data, "m_vecBaseVelocity", ZERO_VECTOR);
	SetEntPropVector(client, Prop_Data, "m_vecVelocity", fSpeed);
	SetEntPropVector(client, Prop_Data, "m_vecAbsVelocity", fSpeed);
}