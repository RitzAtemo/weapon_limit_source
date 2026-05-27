#include <sourcemod>
#include <cstrike>
#include <sdktools>

#pragma semicolon 1
#pragma newdecls required

#define PLUGIN  "Weapon Kill Limit"
#define VERSION "1.0"
#define AUTHOR  "RitzAtemo"

// ------------------------------------------------------------------
// Weapon limit data (from config)
// ------------------------------------------------------------------
#define MAX_WEAPONS 32

char g_sWeaponName[MAX_WEAPONS][32];
int  g_iWeaponLimit[MAX_WEAPONS];
int  g_iWeaponCount = 0;

// ------------------------------------------------------------------
// Per-player tracking
// ------------------------------------------------------------------
int g_iKillRounds[MAXPLAYERS + 1][MAX_WEAPONS];  // rounds where player got a kill with this weapon
bool g_bKilledThisRound[MAXPLAYERS + 1][MAX_WEAPONS]; // already counted this round
bool g_bWeaponBlocked[MAXPLAYERS + 1][MAX_WEAPONS];   // weapon permanently blocked for this player

// ------------------------------------------------------------------
// Plugin info
// ------------------------------------------------------------------
public Plugin myinfo =
{
    name        = PLUGIN,
    author      = AUTHOR,
    description = "Limits weapon usage by kill count",
    version     = VERSION,
    url         = ""
};

// ==================================================================
// Plugin start
// ==================================================================
public void OnPluginStart()
{
    HookEvent("round_start",  OnRoundStart);
    HookEvent("player_death", OnPlayerDeath);

    // Block buying for restricted weapons
    AddCommandListener(BlockBuy, "buy");
    AddCommandListener(BlockBuy, "buyammo1");
    AddCommandListener(BlockBuy, "buyammo2");
    AddCommandListener(BlockBuy, "buyequip");
    AddCommandListener(BlockBuy, "rebuy");
}

public void OnConfigsExecuted()
{
    LoadWeaponConfig();
}

// ==================================================================
// Load weapon config from cfg/sourcemod/weapon_limit.cfg
// ==================================================================
void LoadWeaponConfig()
{
    g_iWeaponCount = 0;

    char path[PLATFORM_MAX_PATH];
    BuildPath(Path_SM, path, sizeof(path), "configs/weapon_limit.cfg");

    KeyValues kv = new KeyValues("WeaponLimits");
    if (!kv.ImportFromFile(path))
    {
        delete kv;
        PrintToServer("[WeaponLimit] Config not found: %s", path);
        return;
    }

    if (!kv.GotoFirstSubKey())
    {
        delete kv;
        return;
    }

    do
    {
        kv.GetSectionName(g_sWeaponName[g_iWeaponCount], 32);
        g_iWeaponLimit[g_iWeaponCount] = kv.GetNum("limit", 0);

        if (g_iWeaponLimit[g_iWeaponCount] > 0)
        {
            PrintToServer("[WeaponLimit] %s -> limit %d", g_sWeaponName[g_iWeaponCount], g_iWeaponLimit[g_iWeaponCount]);
            g_iWeaponCount++;
        }
    }
    while (kv.GotoNextKey());

    delete kv;
}

// ==================================================================
// Round start — reset per-round kill tracking
// ==================================================================
public void OnRoundStart(Event event, const char[] name, bool dontBroadcast)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        for (int w = 0; w < g_iWeaponCount; w++)
            g_bKilledThisRound[i][w] = false;
    }
}

// ==================================================================
// Player death — track kills with restricted weapons
// ==================================================================
public void OnPlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    if (attacker == 0 || attacker > MaxClients || !IsClientInGame(attacker))
        return;
    if (attacker == GetClientOfUserId(event.GetInt("userid")))
        return; // suicide

    char weapon[32];
    event.GetString("weapon", weapon, sizeof(weapon));
    if (strlen(weapon) == 0)
        return;

    int weaponIdx = FindWeaponIndex(weapon);
    if (weaponIdx == -1)
        return;

    // Already counted this round
    if (g_bKilledThisRound[attacker][weaponIdx])
        return;

    g_bKilledThisRound[attacker][weaponIdx] = true;
    g_iKillRounds[attacker][weaponIdx]++;

    PrintToChat(attacker, " \x04[WeaponLimit]\x01 %s kills in %d rounds (limit: %d)",
        weapon, g_iKillRounds[attacker][weaponIdx], g_iWeaponLimit[weaponIdx]);

    if (g_iKillRounds[attacker][weaponIdx] >= g_iWeaponLimit[weaponIdx])
    {
        g_bWeaponBlocked[attacker][weaponIdx] = true;
        StripWeapon(attacker, weaponIdx);
        PrintToChat(attacker, " \x04[WeaponLimit]\x01 You reached the limit for \x03%s\x04! Weapon removed and blocked.", g_sWeaponName[weaponIdx]);
    }
}

// ==================================================================
// Block buying when weapon limit reached
// ==================================================================
public Action BlockBuy(int client, const char[] command, int args)
{
    if (client == 0 || client > MaxClients || !IsClientInGame(client))
        return Plugin_Continue;

    char arg[32];
    if (args > 0)
    {
        GetCmdArg(1, arg, sizeof(arg));
    }
    else
    {
        // "buy" without args — menu, allow
        return Plugin_Continue;
    }

    int weaponIdx = FindWeaponIndex(arg);
    if (weaponIdx == -1)
        return Plugin_Continue;

    if (g_bWeaponBlocked[client][weaponIdx])
    {
        PrintToChat(client, " \x04[WeaponLimit]\x01 You cannot buy \x03%s\x01 — limit reached.", g_sWeaponName[weaponIdx]);
        return Plugin_Handled;
    }

    return Plugin_Continue;
}

// ==================================================================
// Find weapon index by name (buy name or entity name)
// ==================================================================
int FindWeaponIndex(const char[] name)
{
    for (int i = 0; i < g_iWeaponCount; i++)
    {
        if (StrEqual(name, g_sWeaponName[i], false))
            return i;

        // Also match entity weapon names (e.g., "awp" -> "weapon_awp")
        char fullName[48];
        Format(fullName, sizeof(fullName), "weapon_%s", g_sWeaponName[i]);
        if (StrEqual(name, fullName, false))
            return i;
    }
    return -1;
}

// ==================================================================
// Strip a specific weapon from a player
// ==================================================================
void StripWeapon(int client, int weaponIdx)
{
    char fullName[48];
    Format(fullName, sizeof(fullName), "weapon_%s", g_sWeaponName[weaponIdx]);

    int weapon = -1;
    for (int slot = 0; slot < 5; slot++)
    {
        int w = GetPlayerWeaponSlot(client, slot);
        if (w != -1)
        {
            char className[32];
            GetEntityClassname(w, className, sizeof(className));
            if (StrEqual(className, fullName, false))
            {
                weapon = w;
                break;
            }
        }
    }

    if (weapon != -1)
    {
        RemovePlayerItem(client, weapon);
        AcceptEntityInput(weapon, "Kill");
    }
}

// ==================================================================
// Reset tracking on client disconnect
// ==================================================================
public void OnClientDisconnect(int client)
{
    for (int w = 0; w < g_iWeaponCount; w++)
    {
        g_iKillRounds[client][w] = 0;
        g_bKilledThisRound[client][w] = false;
        g_bWeaponBlocked[client][w] = false;
    }
}
