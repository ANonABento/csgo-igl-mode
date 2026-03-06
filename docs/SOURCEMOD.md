# SourceMod Plugin Development Guide

Complete reference for the IGL Mode SourceMod plugin.

## File Locations

```
csgo-igl-mode/
├── addons/sourcemod/
│   ├── scripting/
│   │   ├── igl_mode.sp              # Main plugin source
│   │   └── include/
│   │       └── igl_mode.inc         # Include file for extensions
│   └── plugins/
│       └── igl_mode.smx             # Compiled plugin (after build)
├── scripts/vscripts/
│   └── igl_bridge.nut               # VScript communication bridge
└── cfg/sourcemod/
    └── igl_mode.cfg                 # Server configuration
```

## Compilation

### Prerequisites

1. Download SourceMod scripting tools: https://www.sourcemod.net/downloads.php
2. Extract to your development folder

### Build Commands

```bash
# Windows - drag igl_mode.sp onto spcomp.exe
# Or from command line:
cd addons/sourcemod/scripting
spcomp igl_mode.sp -o../plugins/igl_mode.smx

# Linux/Mac
chmod +x spcomp
./spcomp igl_mode.sp -o../plugins/igl_mode.smx
```

### Including Custom Includes

```bash
# Make sure igl_mode.inc is in the include folder
cp include/igl_mode.inc /path/to/sourcemod/scripting/include/
```

## Plugin Structure

### Standard Includes

```sourcepawn
#pragma semicolon 1
#pragma newdecls required

#include <sourcemod>      // Core SourceMod functions
#include <sdktools>       // Entity manipulation, teleport, etc.
#include <sdkhooks>       // Hook player events (damage, spawn)
#include <cstrike>        // CS:GO specific (teams, weapons, respawn)
```

### Plugin Info Block

```sourcepawn
public Plugin myinfo = {
    name = "IGL Mode",
    author = "Your Name",
    description = "Squad-based bot control",
    version = "1.0.0",
    url = "https://github.com/..."
};
```

### Lifecycle Functions

| Function | When Called | Use For |
|----------|-------------|---------|
| `OnPluginStart()` | Plugin loads | Init, register commands, hook events |
| `OnPluginEnd()` | Plugin unloads | Cleanup handles, timers |
| `OnMapStart()` | Map loads | Reset state, start timers |
| `OnMapEnd()` | Map ends | Stop timers |
| `OnClientConnected(int client)` | Player connects | Per-player setup |
| `OnClientDisconnect(int client)` | Player disconnects | Cleanup player data |

## Event Hooks

### Registering Events

```sourcepawn
public void OnPluginStart()
{
    // Round events
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
    HookEvent("round_freeze_end", Event_FreezeEnd, EventHookMode_PostNoCopy);

    // Player events
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
}
```

### Event Callback Signature

```sourcepawn
public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    // EventHookMode_PostNoCopy - no event data available
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    // EventHookMode_Post - event data available
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));
    char weapon[64];
    event.GetString("weapon", weapon, sizeof(weapon));
}
```

### CS:GO Event Reference

| Event | Key Fields | Description |
|-------|------------|-------------|
| `round_start` | (none useful) | Round begins |
| `round_end` | `winner`, `reason` | Round ends |
| `round_freeze_end` | (none) | Buy time ends |
| `player_spawn` | `userid` | Player spawns |
| `player_death` | `userid`, `attacker`, `weapon`, `headshot` | Player dies |
| `player_hurt` | `userid`, `attacker`, `damage`, `armor` | Player damaged |
| `player_team` | `userid`, `team`, `oldteam` | Team change |
| `bot_takeover` | `userid`, `botid` | Player takes over bot |

## Bot Iteration

### Finding All Bots

```sourcepawn
void IterateBots()
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        if (!IsFakeClient(i))
            continue;  // Skip humans

        int team = GetClientTeam(i);
        if (team != CS_TEAM_CT && team != CS_TEAM_T)
            continue;  // Skip spectators

        // This is a valid bot
        char name[MAX_NAME_LENGTH];
        GetClientName(i, name, sizeof(name));
        PrintToServer("Bot: %s (Team %d)", name, team);
    }
}
```

### Team Constants

```sourcepawn
CS_TEAM_NONE      = 0   // Not on a team
CS_TEAM_SPECTATOR = 1   // Spectators
CS_TEAM_T         = 2   // Terrorists
CS_TEAM_CT        = 3   // Counter-Terrorists
```

## Console Commands

### Registration

```sourcepawn
public void OnPluginStart()
{
    // Player commands (anyone can use)
    RegConsoleCmd("sm_order", Command_Order, "Issue squad order");
    RegConsoleCmd("sm_squad", Command_Squad, "View squad info");

    // Admin commands (require permission)
    RegAdminCmd("sm_igl_reset", Command_Reset, ADMFLAG_SLAY, "Reset squads");
    RegAdminCmd("sm_igl_debug", Command_Debug, ADMFLAG_ROOT, "Debug info");
}
```

### Command Callback

```sourcepawn
public Action Command_Order(int client, int args)
{
    // Validate caller
    if (client == 0)
    {
        ReplyToCommand(client, "This command cannot be used from server console.");
        return Plugin_Handled;
    }

    if (!IsClientInGame(client))
        return Plugin_Handled;

    // Parse arguments
    if (args < 1)
    {
        ReplyToCommand(client, "Usage: sm_order <follow|hold|attack|defend|regroup>");
        return Plugin_Handled;
    }

    char arg[32];
    GetCmdArg(1, arg, sizeof(arg));

    // Process command...

    return Plugin_Handled;
}
```

### Chat Triggers

Commands prefixed with `sm_` automatically get chat triggers:
- `sm_order` can be used as `!order` or `/order` in chat
- `!` is public (message visible to all)
- `/` is silent (message hidden)

## ConVars (Configuration)

### Creating ConVars

```sourcepawn
ConVar g_cvEnabled;
ConVar g_cvSquadSize;

public void OnPluginStart()
{
    g_cvEnabled = CreateConVar(
        "igl_enabled",           // Name
        "1",                     // Default value
        "Enable IGL Mode",       // Description
        FCVAR_NOTIFY,            // Flags (notify = broadcast changes)
        true, 0.0,               // Has min, min value
        true, 1.0                // Has max, max value
    );

    g_cvSquadSize = CreateConVar(
        "igl_squad_size",
        "4",
        "Max bots per squad",
        FCVAR_NONE,
        true, 1.0,
        true, 4.0
    );

    // Generate config file
    AutoExecConfig(true, "igl_mode");
}
```

### Reading ConVars

```sourcepawn
// Get values
bool enabled = g_cvEnabled.BoolValue;
int size = g_cvSquadSize.IntValue;
float cooldown = g_cvCooldown.FloatValue;

// Hook changes
g_cvEnabled.AddChangeHook(OnEnabledChanged);

public void OnEnabledChanged(ConVar convar, const char[] old, const char[] new)
{
    if (StringToInt(new) == 0)
        PrintToChatAll("[IGL] Mode disabled");
    else
        PrintToChatAll("[IGL] Mode enabled");
}
```

## VScript Communication

### Method 1: ServerCommand (Simple)

```sourcepawn
void SendToVScript(int commander, int order, float pos[3])
{
    char cmd[256];
    Format(cmd, sizeof(cmd),
        "script IGL_ReceiveOrder(%d, %d, Vector(%f, %f, %f))",
        commander, order, pos[0], pos[1], pos[2]);

    ServerCommand(cmd);
}
```

### Method 2: Shared ConVar

```sourcepawn
// In SourceMod
ConVar g_cvOrderData;

public void OnPluginStart()
{
    g_cvOrderData = CreateConVar("igl_order_data", "", "Order data for VScript");
}

void SendOrderData(int commander, int order)
{
    char data[128];
    Format(data, sizeof(data), "%d;%d", commander, order);
    g_cvOrderData.SetString(data);
}
```

```squirrel
// In VScript
function IGL_ReadOrder()
{
    local data = Convars.GetStr("igl_order_data")
    // Parse data...
}
```

### Method 3: Entity Properties

```sourcepawn
void StoreInEntity(int entity, const char[] key, const char[] value)
{
    SetEntPropString(entity, Prop_Data, "m_iName", value);
}
```

## Bot Control

### FakeClientCommand

```sourcepawn
// Make bot "type" a command
FakeClientCommand(bot, "drop");              // Drop weapon
FakeClientCommand(bot, "use weapon_ak47");   // Switch weapon
FakeClientCommand(bot, "bot_stop 1");        // Stop moving
```

**Limitations**: Many commands don't work. Use for simple actions only.

### Movement Control via OnPlayerRunCmd

```sourcepawn
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse,
    float vel[3], float angles[3], int &weapon)
{
    if (!IsFakeClient(client))
        return Plugin_Continue;

    // Force movement
    buttons |= IN_FORWARD;  // Move forward
    buttons &= ~IN_BACK;    // Don't move back

    // Force aim
    float targetAngles[3];
    // Calculate angles to target...
    TeleportEntity(client, NULL_VECTOR, targetAngles, NULL_VECTOR);

    return Plugin_Changed;
}
```

### Teleportation

```sourcepawn
void MoveBot(int bot, float destination[3])
{
    // Get current angles
    float angles[3];
    GetClientEyeAngles(bot, angles);

    // Teleport to new position
    TeleportEntity(bot, destination, angles, NULL_VECTOR);
}
```

## Utility Functions

### Client Validation

```sourcepawn
bool IsValidClient(int client)
{
    return (client > 0 &&
            client <= MaxClients &&
            IsClientInGame(client));
}

bool IsValidCommander(int client)
{
    return (IsValidClient(client) &&
            !IsFakeClient(client) &&
            IsPlayerAlive(client));
}
```

### Position Helpers

```sourcepawn
void GetClientPosition(int client, float pos[3])
{
    GetClientAbsOrigin(client, pos);
}

float GetDistance(int client1, int client2)
{
    float pos1[3], pos2[3];
    GetClientAbsOrigin(client1, pos1);
    GetClientAbsOrigin(client2, pos2);
    return GetVectorDistance(pos1, pos2);
}
```

## Timers

### Creating Timers

```sourcepawn
Handle g_hSyncTimer;

public void OnMapStart()
{
    // Repeating timer
    g_hSyncTimer = CreateTimer(0.5, Timer_Sync, _,
        TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Sync(Handle timer)
{
    // Do periodic work...
    return Plugin_Continue;  // Keep timer running
}

public void OnMapEnd()
{
    if (g_hSyncTimer != null)
    {
        KillTimer(g_hSyncTimer);
        g_hSyncTimer = null;
    }
}
```

### One-Shot Timer with Data

```sourcepawn
void DelayedAction(int client)
{
    CreateTimer(1.0, Timer_Delayed, GetClientUserId(client),
        TIMER_FLAG_NO_MAPCHANGE);
}

public Action Timer_Delayed(Handle timer, int userid)
{
    int client = GetClientOfUserId(userid);
    if (client == 0)
        return Plugin_Stop;  // Client disconnected

    // Do action...
    return Plugin_Stop;
}
```

## Debug Logging

```sourcepawn
ConVar g_cvDebug;

void DebugLog(const char[] format, any ...)
{
    if (!g_cvDebug.BoolValue)
        return;

    char buffer[512];
    VFormat(buffer, sizeof(buffer), format, 2);

    // Log to file
    LogMessage("[IGL DEBUG] %s", buffer);

    // Print to admins
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsClientInGame(i) && CheckCommandAccess(i, "", ADMFLAG_ROOT))
        {
            PrintToChat(i, "[IGL DEBUG] %s", buffer);
        }
    }
}
```

## Resources

- [AlliedModders Wiki](https://wiki.alliedmods.net/)
- [SourceMod API Reference](https://sm.alliedmods.net/new-api/)
- [CS:GO Game Events](https://wiki.alliedmods.net/Game_Events_(Source))
- [SDKTools](https://wiki.alliedmods.net/SDKTools_(SourceMod_Scripting))
- [SDKHooks](https://github.com/alliedmodders/sourcemod/blob/master/plugins/include/sdkhooks.inc)
