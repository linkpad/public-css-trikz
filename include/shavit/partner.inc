#if defined _shavit_partner_included
  #endinput
#endif
#define _shavit_partner_included

#define MAX_SOLIDS 1024
#define MAX_COUNTERS 128

enum struct timer_trigger_snapshot_t
{
	bool bPlayerSolid[MAX_SOLIDS];
	bool bWasSolid[MAX_SOLIDS];
	bool bStartTouch[MAX_SOLIDS];
	bool bNotDefault[MAX_SOLIDS];
	int iAllowedToggles[MAX_SOLIDS];
	int iOldToggles[MAX_SOLIDS];
	bool bButtonLocked[2049];
	float fButtonNextPress[2049];
	float fMathCounterValue[MAX_COUNTERS];
}

/*
* Get's a client's trikz partner.
* 
* @param client		Client index.
* 
* @return			Client index of partner, 0 if no partner or invalid client.
*/
native int Timer_GetPartner(int client);
native void Timer_SetPartner(int client, int partner);
native void Trikz_BuildTriggerSnapshot(int client, int maxCPs);
native void Trikz_LoadTriggerSnapshot(int client, int index);
native void Trikz_ResetTriggerSnapshot(int client);
native void Trikz_DeleteTriggerSnapshot(int client, int index);
native void Trikz_ResetTriggers(int client);

/*
* Gets a client's solid state to a given toggleable
* @param entity		Entity index.
* @param client		Client index.
* 
* @return			false, if the entity is not a toggleable or not colliding with the player, true otherwise.
*/
native bool Trikz_IsToggleableEnabledForPlayer(int entity, int client);

/*
* Check's a given entities existance to the plugin
* 
* @param entity		Entity index.
* 
* @return			false, if the entity is not a toggleable, true otherwise.
*/
native bool Trikz_IsEntityToggleable(int entity);

forward void Trikz_OnPartner(int client, int partner);
forward void Trikz_OnBreakPartner(int client, int partner);

public SharedPlugin __pl_shavit_partner =
{
	name = "shavit-partner",
	file = "shavit-partner.smx",
#if defined REQUIRE_PLUGIN
	required = 1
#else
	required = 0
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_shavit_partner_SetNTVOptional()
{
	MarkNativeAsOptional("Timer_GetPartner");
	MarkNativeAsOptional("Timer_SetPartner");
	MarkNativeAsOptional("Trikz_BuildTriggerSnapshot");
	MarkNativeAsOptional("Trikz_LoadTriggerSnapshot");
	MarkNativeAsOptional("Trikz_ResetTriggerSnapshot");
	MarkNativeAsOptional("Trikz_DeleteTriggerSnapshot");
	MarkNativeAsOptional("Trikz_IsToggleableEnabledForPlayer");
	MarkNativeAsOptional("Trikz_IsEntityToggleable");
	MarkNativeAsOptional("Trikz_ResetTriggers");
}
#endif