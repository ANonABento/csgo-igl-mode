/**
 * =============================================================================
 * IGL Mode - Squad-Based Bot Control for CS:GO
 * =============================================================================
 *
 * A SourceMod plugin that allows players to control squads of bots,
 * simulating an In-Game Leader (IGL) experience.
 *
 * Features:
 * - Automatic bot-to-player squad assignment
 * - Console commands for squad orders (/order, /squad)
 * - VScript communication bridge
 * - Round-based squad management
 *
 * Installation:
 * 1. Compile this .sp file using spcomp
 * 2. Place the resulting .smx file in addons/sourcemod/plugins/
 * 3. Restart server or use "sm plugins load igl_mode"
 *
 * =============================================================================
 */

#pragma semicolon 1
#pragma newdecls required

// =============================================================================
// INCLUDES
// =============================================================================

#include <sourcemod>
#include <sdktools>
#include <sdkhooks>
#include <cstrike>

// =============================================================================
// PLUGIN INFO
// =============================================================================

#define PLUGIN_VERSION "1.0.0"
#define PLUGIN_PREFIX "[IGL]"

public Plugin myinfo = {
    name = "IGL Mode",
    author = "Your Name",
    description = "Squad-based bot control system for CS:GO",
    version = PLUGIN_VERSION,
    url = "https://github.com/yourusername/csgo-igl-mode"
};

// =============================================================================
// CONSTANTS
// =============================================================================

#define MAX_SQUAD_SIZE 4
#define MAX_PLAYERS 64
#define INVALID_PLAYER -1

// Order types for squad commands
enum OrderType {
    Order_None = 0,
    Order_Follow,
    Order_Hold,
    Order_Attack,
    Order_Defend,
    Order_Regroup
}

// Squad formation types
enum FormationType {
    Formation_Default = 0,
    Formation_Line,
    Formation_Wedge,
    Formation_Stack
}

// =============================================================================
// GLOBAL VARIABLES
// =============================================================================

// ConVars for configuration
ConVar g_cvEnabled;
ConVar g_cvSquadSize;
ConVar g_cvDebugMode;
ConVar g_cvAutoAssign;
ConVar g_cvOrderCooldown;

// Squad assignments: maps bot client index -> commander client index
int g_iSquadCommander[MAX_PLAYERS + 1];

// Current order for each player's squad
OrderType g_eCurrentOrder[MAX_PLAYERS + 1];

// Squad member tracking: for each commander, store their bot indices
ArrayList g_hSquadMembers[MAX_PLAYERS + 1];

// Order cooldown tracking
float g_fLastOrderTime[MAX_PLAYERS + 1];

// VScript communication handle
Handle g_hVScriptTimer;

// =============================================================================
// PLUGIN LIFECYCLE
// =============================================================================

public void OnPluginStart()
{
    // Load translations (if you have a phrases file)
    // LoadTranslations("igl_mode.phrases");

    // Create ConVars for configuration
    CreateConVars();

    // Register console commands
    RegisterCommands();

    // Hook game events
    HookEvents();

    // Initialize squad member arrays
    for (int i = 0; i <= MAX_PLAYERS; i++)
    {
        g_hSquadMembers[i] = new ArrayList();
        g_iSquadCommander[i] = INVALID_PLAYER;
        g_eCurrentOrder[i] = Order_None;
        g_fLastOrderTime[i] = 0.0;
    }

    // Auto-generate config file in cfg/sourcemod/
    AutoExecConfig(true, "igl_mode");

    LogMessage("%s Plugin loaded successfully (v%s)", PLUGIN_PREFIX, PLUGIN_VERSION);
}

public void OnPluginEnd()
{
    // Clean up squad member ArrayLists
    for (int i = 0; i <= MAX_PLAYERS; i++)
    {
        if (g_hSquadMembers[i] != null)
        {
            delete g_hSquadMembers[i];
        }
    }

    // Stop VScript communication timer
    if (g_hVScriptTimer != null)
    {
        KillTimer(g_hVScriptTimer);
        g_hVScriptTimer = null;
    }

    LogMessage("%s Plugin unloaded", PLUGIN_PREFIX);
}

public void OnMapStart()
{
    // Reset all squad assignments on map change
    ResetAllSquads();

    // Start VScript communication timer
    g_hVScriptTimer = CreateTimer(0.5, Timer_VScriptSync, _, TIMER_REPEAT | TIMER_FLAG_NO_MAPCHANGE);
}

public void OnMapEnd()
{
    if (g_hVScriptTimer != null)
    {
        KillTimer(g_hVScriptTimer);
        g_hVScriptTimer = null;
    }
}

// =============================================================================
// CONVAR CREATION
// =============================================================================

void CreateConVars()
{
    g_cvEnabled = CreateConVar(
        "igl_enabled",
        "1",
        "Enable/disable IGL Mode",
        FCVAR_NOTIFY,
        true, 0.0,
        true, 1.0
    );

    g_cvSquadSize = CreateConVar(
        "igl_squad_size",
        "4",
        "Maximum number of bots per squad",
        FCVAR_NOTIFY,
        true, 1.0,
        true, float(MAX_SQUAD_SIZE)
    );

    g_cvDebugMode = CreateConVar(
        "igl_debug",
        "0",
        "Enable debug logging",
        FCVAR_NONE,
        true, 0.0,
        true, 1.0
    );

    g_cvAutoAssign = CreateConVar(
        "igl_auto_assign",
        "1",
        "Automatically assign bots to players on round start",
        FCVAR_NONE,
        true, 0.0,
        true, 1.0
    );

    g_cvOrderCooldown = CreateConVar(
        "igl_order_cooldown",
        "1.0",
        "Cooldown between orders in seconds",
        FCVAR_NONE,
        true, 0.0,
        true, 10.0
    );

    // Hook ConVar changes for runtime updates
    g_cvEnabled.AddChangeHook(OnConVarChanged);
    g_cvSquadSize.AddChangeHook(OnConVarChanged);
}

public void OnConVarChanged(ConVar convar, const char[] oldValue, const char[] newValue)
{
    if (convar == g_cvEnabled)
    {
        if (StringToInt(newValue) == 0)
        {
            ResetAllSquads();
            PrintToChatAll("%s IGL Mode disabled", PLUGIN_PREFIX);
        }
        else
        {
            PrintToChatAll("%s IGL Mode enabled", PLUGIN_PREFIX);
        }
    }
    else if (convar == g_cvSquadSize)
    {
        // Re-assign squads with new size
        if (g_cvAutoAssign.BoolValue)
        {
            AssignBotsToPlayers();
        }
    }
}

// =============================================================================
// COMMAND REGISTRATION
// =============================================================================

void RegisterCommands()
{
    // Squad order commands (accessible via chat: !order, /order, or console: sm_order)
    RegConsoleCmd("sm_order", Command_Order, "Issue an order to your squad");
    RegConsoleCmd("sm_squad", Command_Squad, "View your current squad members");
    RegConsoleCmd("sm_follow", Command_Follow, "Order squad to follow you");
    RegConsoleCmd("sm_hold", Command_Hold, "Order squad to hold position");
    RegConsoleCmd("sm_attack", Command_Attack, "Order squad to attack");
    RegConsoleCmd("sm_defend", Command_Defend, "Order squad to defend current position");
    RegConsoleCmd("sm_regroup", Command_Regroup, "Order squad to regroup on you");

    // Admin commands
    RegAdminCmd("sm_igl_assign", Command_AssignBot, ADMFLAG_SLAY, "Manually assign a bot to a player");
    RegAdminCmd("sm_igl_reset", Command_ResetSquads, ADMFLAG_SLAY, "Reset all squad assignments");
    RegAdminCmd("sm_igl_debug", Command_Debug, ADMFLAG_ROOT, "Debug squad information");
}

// =============================================================================
// EVENT HOOKS
// =============================================================================

void HookEvents()
{
    // Round events
    HookEvent("round_start", Event_RoundStart, EventHookMode_PostNoCopy);
    HookEvent("round_end", Event_RoundEnd, EventHookMode_Post);
    HookEvent("round_freeze_end", Event_FreezeEnd, EventHookMode_PostNoCopy);

    // Player events
    HookEvent("player_spawn", Event_PlayerSpawn, EventHookMode_Post);
    HookEvent("player_death", Event_PlayerDeath, EventHookMode_Post);
    HookEvent("player_disconnect", Event_PlayerDisconnect, EventHookMode_Pre);
    HookEvent("player_team", Event_PlayerTeam, EventHookMode_Post);

    // Bot-specific events
    HookEvent("bot_takeover", Event_BotTakeover, EventHookMode_Post);
}

// =============================================================================
// EVENT HANDLERS
// =============================================================================

public void Event_RoundStart(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnabled.BoolValue)
        return;

    DebugLog("Round started - preparing squad assignments");

    // Reset orders for new round
    for (int i = 1; i <= MaxClients; i++)
    {
        g_eCurrentOrder[i] = Order_None;
        g_fLastOrderTime[i] = 0.0;
    }

    // Auto-assign bots after a short delay (let spawns complete)
    if (g_cvAutoAssign.BoolValue)
    {
        CreateTimer(0.5, Timer_AssignSquads, _, TIMER_FLAG_NO_MAPCHANGE);
    }
}

public void Event_RoundEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnabled.BoolValue)
        return;

    int winner = event.GetInt("winner");
    int reason = event.GetInt("reason");

    DebugLog("Round ended - Winner: %d, Reason: %d", winner, reason);

    // Optionally track squad performance here
}

public void Event_FreezeEnd(Event event, const char[] name, bool dontBroadcast)
{
    if (!g_cvEnabled.BoolValue)
        return;

    // Notify players their squads are ready
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidCommander(i) && g_hSquadMembers[i].Length > 0)
        {
            PrintToChat(i, "%s Freeze time ended. Your squad (%d bots) is ready!",
                PLUGIN_PREFIX, g_hSquadMembers[i].Length);
        }
    }
}

public void Event_PlayerSpawn(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (!IsValidClient(client))
        return;

    // If a bot spawned, potentially assign to a commander
    if (IsFakeClient(client) && g_cvAutoAssign.BoolValue)
    {
        CreateTimer(0.1, Timer_AssignSingleBot, GetClientUserId(client), TIMER_FLAG_NO_MAPCHANGE);
    }
}

public void Event_PlayerDeath(Event event, const char[] name, bool dontBroadcast)
{
    int victim = GetClientOfUserId(event.GetInt("userid"));
    int attacker = GetClientOfUserId(event.GetInt("attacker"));

    if (!IsValidClient(victim))
        return;

    // If a bot in a squad died, notify the commander
    if (IsFakeClient(victim))
    {
        int commander = g_iSquadCommander[victim];
        if (IsValidCommander(commander))
        {
            char botName[MAX_NAME_LENGTH];
            GetClientName(victim, botName, sizeof(botName));
            PrintToChat(commander, "%s Squad member %s was eliminated!", PLUGIN_PREFIX, botName);

            // Remove from squad list
            int index = g_hSquadMembers[commander].FindValue(victim);
            if (index != -1)
            {
                g_hSquadMembers[commander].Erase(index);
            }
            g_iSquadCommander[victim] = INVALID_PLAYER;
        }
    }
    // If a commander died, optionally transfer command
    else if (!IsFakeClient(victim) && g_hSquadMembers[victim].Length > 0)
    {
        PrintToChat(victim, "%s You have fallen. Your squad will hold position.", PLUGIN_PREFIX);
        IssueSquadOrder(victim, Order_Hold);
    }
}

public void Event_PlayerDisconnect(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));

    if (client <= 0 || client > MaxClients)
        return;

    // Clean up squad assignments
    if (!IsFakeClient(client))
    {
        // Commander disconnected - release their bots
        ReleaseSquad(client);
    }
    else
    {
        // Bot disconnected - remove from commander's squad
        int commander = g_iSquadCommander[client];
        if (IsValidCommander(commander))
        {
            int index = g_hSquadMembers[commander].FindValue(client);
            if (index != -1)
            {
                g_hSquadMembers[commander].Erase(index);
            }
        }
        g_iSquadCommander[client] = INVALID_PLAYER;
    }
}

public void Event_PlayerTeam(Event event, const char[] name, bool dontBroadcast)
{
    int client = GetClientOfUserId(event.GetInt("userid"));
    int newTeam = event.GetInt("team");
    int oldTeam = event.GetInt("oldteam");

    if (!IsValidClient(client))
        return;

    // If a commander changed teams, release their squad
    if (!IsFakeClient(client) && oldTeam != newTeam)
    {
        ReleaseSquad(client);
    }
}

public void Event_BotTakeover(Event event, const char[] name, bool dontBroadcast)
{
    int player = GetClientOfUserId(event.GetInt("userid"));
    int bot = GetClientOfUserId(event.GetInt("botid"));

    if (!IsValidClient(player) || !IsValidClient(bot))
        return;

    // Remove bot from any squad when taken over
    int commander = g_iSquadCommander[bot];
    if (commander != INVALID_PLAYER)
    {
        int index = g_hSquadMembers[commander].FindValue(bot);
        if (index != -1)
        {
            g_hSquadMembers[commander].Erase(index);
        }
        g_iSquadCommander[bot] = INVALID_PLAYER;
    }
}

// =============================================================================
// CONSOLE COMMAND HANDLERS
// =============================================================================

public Action Command_Order(int client, int args)
{
    if (!IsValidCommander(client))
    {
        ReplyToCommand(client, "%s This command is only available to players.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }

    if (!g_cvEnabled.BoolValue)
    {
        ReplyToCommand(client, "%s IGL Mode is currently disabled.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }

    if (args < 1)
    {
        // Show order menu
        DisplayOrderMenu(client);
        return Plugin_Handled;
    }

    char orderArg[32];
    GetCmdArg(1, orderArg, sizeof(orderArg));

    OrderType order = ParseOrderString(orderArg);
    if (order == Order_None)
    {
        ReplyToCommand(client, "%s Invalid order. Use: follow, hold, attack, defend, regroup", PLUGIN_PREFIX);
        return Plugin_Handled;
    }

    IssueSquadOrder(client, order);
    return Plugin_Handled;
}

public Action Command_Squad(int client, int args)
{
    if (!IsValidCommander(client))
    {
        ReplyToCommand(client, "%s This command is only available to players.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }

    DisplaySquadInfo(client);
    return Plugin_Handled;
}

public Action Command_Follow(int client, int args)
{
    return IssueQuickOrder(client, Order_Follow);
}

public Action Command_Hold(int client, int args)
{
    return IssueQuickOrder(client, Order_Hold);
}

public Action Command_Attack(int client, int args)
{
    return IssueQuickOrder(client, Order_Attack);
}

public Action Command_Defend(int client, int args)
{
    return IssueQuickOrder(client, Order_Defend);
}

public Action Command_Regroup(int client, int args)
{
    return IssueQuickOrder(client, Order_Regroup);
}

Action IssueQuickOrder(int client, OrderType order)
{
    if (!IsValidCommander(client))
    {
        ReplyToCommand(client, "%s This command is only available to players.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }

    if (!g_cvEnabled.BoolValue)
    {
        ReplyToCommand(client, "%s IGL Mode is currently disabled.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }

    IssueSquadOrder(client, order);
    return Plugin_Handled;
}

public Action Command_AssignBot(int client, int args)
{
    if (args < 2)
    {
        ReplyToCommand(client, "Usage: sm_igl_assign <bot_name> <commander_name>");
        return Plugin_Handled;
    }

    char botName[MAX_NAME_LENGTH];
    char commanderName[MAX_NAME_LENGTH];
    GetCmdArg(1, botName, sizeof(botName));
    GetCmdArg(2, commanderName, sizeof(commanderName));

    int bot = FindTargetByName(botName, true);
    int commander = FindTargetByName(commanderName, false);

    if (bot == -1 || commander == -1)
    {
        ReplyToCommand(client, "%s Could not find specified bot or commander.", PLUGIN_PREFIX);
        return Plugin_Handled;
    }

    AssignBotToCommander(bot, commander);
    ReplyToCommand(client, "%s Assigned %s to %s's squad.", PLUGIN_PREFIX, botName, commanderName);

    return Plugin_Handled;
}

public Action Command_ResetSquads(int client, int args)
{
    ResetAllSquads();
    ReplyToCommand(client, "%s All squad assignments have been reset.", PLUGIN_PREFIX);

    if (g_cvAutoAssign.BoolValue)
    {
        AssignBotsToPlayers();
        ReplyToCommand(client, "%s Squads have been re-assigned.", PLUGIN_PREFIX);
    }

    return Plugin_Handled;
}

public Action Command_Debug(int client, int args)
{
    ReplyToCommand(client, "=== IGL Mode Debug Info ===");
    ReplyToCommand(client, "Enabled: %s", g_cvEnabled.BoolValue ? "Yes" : "No");
    ReplyToCommand(client, "Squad Size: %d", g_cvSquadSize.IntValue);
    ReplyToCommand(client, "Auto-Assign: %s", g_cvAutoAssign.BoolValue ? "Yes" : "No");

    int botCount = 0;
    int humanCount = 0;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        if (IsFakeClient(i))
            botCount++;
        else
            humanCount++;
    }

    ReplyToCommand(client, "Players: %d humans, %d bots", humanCount, botCount);

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidCommander(i))
            continue;

        if (g_hSquadMembers[i].Length > 0)
        {
            char name[MAX_NAME_LENGTH];
            GetClientName(i, name, sizeof(name));
            ReplyToCommand(client, "  %s: %d squad members", name, g_hSquadMembers[i].Length);
        }
    }

    return Plugin_Handled;
}

// =============================================================================
// SQUAD MANAGEMENT
// =============================================================================

void AssignBotsToPlayers()
{
    if (!g_cvEnabled.BoolValue)
        return;

    // Get all human players and bots per team
    ArrayList ctHumans = new ArrayList();
    ArrayList tHumans = new ArrayList();
    ArrayList ctBots = new ArrayList();
    ArrayList tBots = new ArrayList();

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        int team = GetClientTeam(i);

        if (team == CS_TEAM_CT)
        {
            if (IsFakeClient(i))
                ctBots.Push(i);
            else
                ctHumans.Push(i);
        }
        else if (team == CS_TEAM_T)
        {
            if (IsFakeClient(i))
                tBots.Push(i);
            else
                tHumans.Push(i);
        }
    }

    // Distribute bots to CT players
    DistributeBotsToCommanders(ctBots, ctHumans);

    // Distribute bots to T players
    DistributeBotsToCommanders(tBots, tHumans);

    // Clean up
    delete ctHumans;
    delete tHumans;
    delete ctBots;
    delete tBots;

    DebugLog("Squad assignment complete");
}

void DistributeBotsToCommanders(ArrayList bots, ArrayList commanders)
{
    if (commanders.Length == 0 || bots.Length == 0)
        return;

    int maxSquadSize = g_cvSquadSize.IntValue;
    int botsPerCommander = bots.Length / commanders.Length;
    int extraBots = bots.Length % commanders.Length;

    int botIndex = 0;

    for (int i = 0; i < commanders.Length && botIndex < bots.Length; i++)
    {
        int commander = commanders.Get(i);
        int botsToAssign = botsPerCommander;

        // Give extra bots to first commanders
        if (i < extraBots)
            botsToAssign++;

        // Cap at max squad size
        if (botsToAssign > maxSquadSize)
            botsToAssign = maxSquadSize;

        for (int j = 0; j < botsToAssign && botIndex < bots.Length; j++)
        {
            int bot = bots.Get(botIndex);
            AssignBotToCommander(bot, commander);
            botIndex++;
        }
    }
}

void AssignBotToCommander(int bot, int commander)
{
    if (!IsValidClient(bot) || !IsValidClient(commander))
        return;

    if (!IsFakeClient(bot) || IsFakeClient(commander))
        return;

    // Remove from previous commander if any
    int prevCommander = g_iSquadCommander[bot];
    if (prevCommander != INVALID_PLAYER && prevCommander != commander)
    {
        int index = g_hSquadMembers[prevCommander].FindValue(bot);
        if (index != -1)
        {
            g_hSquadMembers[prevCommander].Erase(index);
        }
    }

    // Assign to new commander
    g_iSquadCommander[bot] = commander;

    if (g_hSquadMembers[commander].FindValue(bot) == -1)
    {
        g_hSquadMembers[commander].Push(bot);
    }

    char botName[MAX_NAME_LENGTH];
    GetClientName(bot, botName, sizeof(botName));

    DebugLog("Assigned bot %s to commander %d", botName, commander);
}

void ReleaseSquad(int commander)
{
    if (commander <= 0 || commander > MaxClients)
        return;

    // Clear all bot assignments
    for (int i = 0; i < g_hSquadMembers[commander].Length; i++)
    {
        int bot = g_hSquadMembers[commander].Get(i);
        if (bot > 0 && bot <= MaxClients)
        {
            g_iSquadCommander[bot] = INVALID_PLAYER;
        }
    }

    g_hSquadMembers[commander].Clear();
    g_eCurrentOrder[commander] = Order_None;

    DebugLog("Released squad for commander %d", commander);
}

void ResetAllSquads()
{
    for (int i = 0; i <= MAX_PLAYERS; i++)
    {
        g_iSquadCommander[i] = INVALID_PLAYER;
        g_eCurrentOrder[i] = Order_None;
        if (g_hSquadMembers[i] != null)
        {
            g_hSquadMembers[i].Clear();
        }
    }

    DebugLog("All squads reset");
}

// =============================================================================
// ORDER SYSTEM
// =============================================================================

void IssueSquadOrder(int commander, OrderType order)
{
    if (!IsValidCommander(commander))
        return;

    // Check cooldown
    float currentTime = GetGameTime();
    float cooldown = g_cvOrderCooldown.FloatValue;

    if (currentTime - g_fLastOrderTime[commander] < cooldown)
    {
        float remaining = cooldown - (currentTime - g_fLastOrderTime[commander]);
        PrintToChat(commander, "%s Order cooldown: %.1f seconds remaining", PLUGIN_PREFIX, remaining);
        return;
    }

    if (g_hSquadMembers[commander].Length == 0)
    {
        PrintToChat(commander, "%s You have no squad members to command.", PLUGIN_PREFIX);
        return;
    }

    g_eCurrentOrder[commander] = order;
    g_fLastOrderTime[commander] = currentTime;

    char orderName[32];
    GetOrderName(order, orderName, sizeof(orderName));

    // Get commander position for positional orders
    float commanderPos[3];
    float commanderAng[3];
    GetClientAbsOrigin(commander, commanderPos);
    GetClientEyeAngles(commander, commanderAng);

    // Execute order on each squad member
    for (int i = 0; i < g_hSquadMembers[commander].Length; i++)
    {
        int bot = g_hSquadMembers[commander].Get(i);

        if (!IsValidClient(bot) || !IsPlayerAlive(bot))
            continue;

        ExecuteBotOrder(bot, order, commanderPos, commanderAng);
    }

    PrintToChat(commander, "%s Order issued: %s (%d bots)",
        PLUGIN_PREFIX, orderName, g_hSquadMembers[commander].Length);

    // Sync with VScript
    SyncOrderToVScript(commander, order, commanderPos);
}

void ExecuteBotOrder(int bot, OrderType order, float commanderPos[3], float commanderAng[3])
{
    if (!IsValidClient(bot) || !IsFakeClient(bot))
        return;

    switch (order)
    {
        case Order_Follow:
        {
            // Make bot follow - could use navmesh or teleport nearby
            // For now, use a simple approach
            float targetPos[3];
            targetPos[0] = commanderPos[0] + GetRandomFloat(-100.0, 100.0);
            targetPos[1] = commanderPos[1] + GetRandomFloat(-100.0, 100.0);
            targetPos[2] = commanderPos[2];

            // Use FakeClientCommand to make bot move
            // Note: This has limitations - see VScript integration for better control
            FakeClientCommand(bot, "bot_goto %f %f %f", targetPos[0], targetPos[1], targetPos[2]);
        }
        case Order_Hold:
        {
            // Make bot hold position
            FakeClientCommand(bot, "bot_stop 1");
        }
        case Order_Attack:
        {
            // Make bot aggressive
            FakeClientCommand(bot, "bot_stop 0");
            FakeClientCommand(bot, "bot_knives_only 0");
        }
        case Order_Defend:
        {
            // Make bot defensive at current position
            float botPos[3];
            GetClientAbsOrigin(bot, botPos);
            // Bot will defend current area
            FakeClientCommand(bot, "bot_place");
        }
        case Order_Regroup:
        {
            // Similar to follow but tighter grouping
            float targetPos[3];
            targetPos[0] = commanderPos[0] + GetRandomFloat(-50.0, 50.0);
            targetPos[1] = commanderPos[1] + GetRandomFloat(-50.0, 50.0);
            targetPos[2] = commanderPos[2];

            FakeClientCommand(bot, "bot_goto %f %f %f", targetPos[0], targetPos[1], targetPos[2]);
        }
    }
}

// =============================================================================
// VSCRIPT COMMUNICATION
// =============================================================================

/**
 * Syncs order data to VScript via game events or server commands
 *
 * Methods for SourceMod <-> VScript communication:
 * 1. Game Events (recommended) - Fire custom events that VScript listens to
 * 2. Server Commands - Use ServerCommand() to execute VScript functions
 * 3. Entity Properties - Store data in entity keyvalues
 * 4. ConVars - Use shared ConVars for simple data
 * 5. File I/O - Write to a shared file (slow but reliable)
 */

void SyncOrderToVScript(int commander, OrderType order, float position[3])
{
    // Method 1: ServerCommand to execute VScript directly
    // The VScript must have a global function to receive this
    char vscriptCmd[256];
    Format(vscriptCmd, sizeof(vscriptCmd),
        "script IGL_ReceiveOrder(%d, %d, Vector(%f, %f, %f))",
        commander, view_as<int>(order), position[0], position[1], position[2]);

    ServerCommand(vscriptCmd);

    // Method 2: Set a ConVar that VScript can read
    // Create a hidden convar for data transfer
    char orderData[128];
    Format(orderData, sizeof(orderData), "%d;%d;%f;%f;%f",
        commander, view_as<int>(order), position[0], position[1], position[2]);

    // You would need to create this ConVar first
    // SetConVarString(g_cvOrderData, orderData);

    DebugLog("Synced order to VScript: commander=%d, order=%d", commander, order);
}

public Action Timer_VScriptSync(Handle timer)
{
    if (!g_cvEnabled.BoolValue)
        return Plugin_Continue;

    // Periodic sync of squad states to VScript
    // This allows VScript to query current squad status

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidCommander(i))
            continue;

        if (g_hSquadMembers[i].Length == 0)
            continue;

        // Build squad data string
        char squadData[512];
        Format(squadData, sizeof(squadData), "%d", i);

        for (int j = 0; j < g_hSquadMembers[i].Length; j++)
        {
            int bot = g_hSquadMembers[i].Get(j);
            if (IsValidClient(bot))
            {
                Format(squadData, sizeof(squadData), "%s,%d", squadData, bot);
            }
        }

        // Send to VScript
        char vscriptCmd[512];
        Format(vscriptCmd, sizeof(vscriptCmd),
            "script IGL_UpdateSquad(\"%s\", %d)",
            squadData, view_as<int>(g_eCurrentOrder[i]));

        ServerCommand(vscriptCmd);
    }

    return Plugin_Continue;
}

/**
 * Native function to allow VScript to request data
 * This would require the VScript extension to be fully functional
 */
// public int Native_GetSquadMembers(Handle plugin, int numParams)
// {
//     int commander = GetNativeCell(1);
//     // Return squad member data...
// }

// =============================================================================
// MENU SYSTEM
// =============================================================================

void DisplayOrderMenu(int client)
{
    Menu menu = new Menu(MenuHandler_Order);
    menu.SetTitle("Squad Orders");

    menu.AddItem("follow", "Follow Me");
    menu.AddItem("hold", "Hold Position");
    menu.AddItem("attack", "Attack");
    menu.AddItem("defend", "Defend Here");
    menu.AddItem("regroup", "Regroup on Me");

    menu.Display(client, 20);
}

public int MenuHandler_Order(Menu menu, MenuAction action, int param1, int param2)
{
    switch (action)
    {
        case MenuAction_Select:
        {
            char info[32];
            menu.GetItem(param2, info, sizeof(info));

            OrderType order = ParseOrderString(info);
            if (order != Order_None)
            {
                IssueSquadOrder(param1, order);
            }
        }
        case MenuAction_End:
        {
            delete menu;
        }
    }
    return 0;
}

void DisplaySquadInfo(int client)
{
    if (g_hSquadMembers[client].Length == 0)
    {
        PrintToChat(client, "%s You have no squad members.", PLUGIN_PREFIX);
        return;
    }

    char orderName[32];
    GetOrderName(g_eCurrentOrder[client], orderName, sizeof(orderName));

    PrintToChat(client, "%s === Your Squad ===", PLUGIN_PREFIX);
    PrintToChat(client, "%s Current Order: %s", PLUGIN_PREFIX, orderName);
    PrintToChat(client, "%s Members (%d):", PLUGIN_PREFIX, g_hSquadMembers[client].Length);

    for (int i = 0; i < g_hSquadMembers[client].Length; i++)
    {
        int bot = g_hSquadMembers[client].Get(i);

        if (!IsValidClient(bot))
            continue;

        char botName[MAX_NAME_LENGTH];
        GetClientName(bot, botName, sizeof(botName));

        int health = IsPlayerAlive(bot) ? GetClientHealth(bot) : 0;
        char status[16];

        if (!IsPlayerAlive(bot))
            Format(status, sizeof(status), "DEAD");
        else if (health > 50)
            Format(status, sizeof(status), "HP: %d", health);
        else
            Format(status, sizeof(status), "LOW: %d", health);

        PrintToChat(client, "%s   - %s [%s]", PLUGIN_PREFIX, botName, status);
    }
}

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

bool IsValidClient(int client)
{
    return (client > 0 && client <= MaxClients && IsClientInGame(client));
}

bool IsValidCommander(int client)
{
    return (IsValidClient(client) && !IsFakeClient(client));
}

OrderType ParseOrderString(const char[] orderStr)
{
    if (StrEqual(orderStr, "follow", false))
        return Order_Follow;
    if (StrEqual(orderStr, "hold", false))
        return Order_Hold;
    if (StrEqual(orderStr, "attack", false))
        return Order_Attack;
    if (StrEqual(orderStr, "defend", false))
        return Order_Defend;
    if (StrEqual(orderStr, "regroup", false))
        return Order_Regroup;

    return Order_None;
}

void GetOrderName(OrderType order, char[] buffer, int maxlen)
{
    switch (order)
    {
        case Order_None:     strcopy(buffer, maxlen, "None");
        case Order_Follow:   strcopy(buffer, maxlen, "Follow");
        case Order_Hold:     strcopy(buffer, maxlen, "Hold Position");
        case Order_Attack:   strcopy(buffer, maxlen, "Attack");
        case Order_Defend:   strcopy(buffer, maxlen, "Defend");
        case Order_Regroup:  strcopy(buffer, maxlen, "Regroup");
        default:             strcopy(buffer, maxlen, "Unknown");
    }
}

int FindTargetByName(const char[] name, bool botOnly)
{
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsClientInGame(i))
            continue;

        if (botOnly && !IsFakeClient(i))
            continue;

        char clientName[MAX_NAME_LENGTH];
        GetClientName(i, clientName, sizeof(clientName));

        if (StrContains(clientName, name, false) != -1)
            return i;
    }
    return -1;
}

void DebugLog(const char[] format, any ...)
{
    if (!g_cvDebugMode.BoolValue)
        return;

    char buffer[512];
    VFormat(buffer, sizeof(buffer), format, 2);

    LogMessage("%s DEBUG: %s", PLUGIN_PREFIX, buffer);

    // Also print to admin chat if debug is on
    for (int i = 1; i <= MaxClients; i++)
    {
        if (IsValidClient(i) && !IsFakeClient(i) && CheckCommandAccess(i, "sm_igl_debug", ADMFLAG_ROOT))
        {
            PrintToChat(i, "%s DEBUG: %s", PLUGIN_PREFIX, buffer);
        }
    }
}

// =============================================================================
// TIMER CALLBACKS
// =============================================================================

public Action Timer_AssignSquads(Handle timer)
{
    AssignBotsToPlayers();

    // Notify commanders
    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidCommander(i))
            continue;

        if (g_hSquadMembers[i].Length > 0)
        {
            PrintToChat(i, "%s You have been assigned %d squad members. Use !order or !squad for commands.",
                PLUGIN_PREFIX, g_hSquadMembers[i].Length);
        }
    }

    return Plugin_Stop;
}

public Action Timer_AssignSingleBot(Handle timer, int userid)
{
    int bot = GetClientOfUserId(userid);

    if (!IsValidClient(bot) || !IsFakeClient(bot))
        return Plugin_Stop;

    // Find a commander on the same team with space in their squad
    int team = GetClientTeam(bot);
    int maxSquadSize = g_cvSquadSize.IntValue;

    for (int i = 1; i <= MaxClients; i++)
    {
        if (!IsValidCommander(i))
            continue;

        if (GetClientTeam(i) != team)
            continue;

        if (g_hSquadMembers[i].Length >= maxSquadSize)
            continue;

        AssignBotToCommander(bot, i);

        char botName[MAX_NAME_LENGTH];
        GetClientName(bot, botName, sizeof(botName));
        PrintToChat(i, "%s %s has joined your squad.", PLUGIN_PREFIX, botName);

        break;
    }

    return Plugin_Stop;
}

// =============================================================================
// SDKHOOKS CALLBACKS (Optional - for advanced bot control)
// =============================================================================

/**
 * Hook player movement for fine-grained bot control
 * Uncomment and modify as needed
 */
/*
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse, float vel[3],
    float angles[3], int &weapon, int &subtype, int &cmdnum, int &tickcount, int &seed, int mouse[2])
{
    if (!g_cvEnabled.BoolValue)
        return Plugin_Continue;

    if (!IsFakeClient(client))
        return Plugin_Continue;

    int commander = g_iSquadCommander[client];
    if (commander == INVALID_PLAYER)
        return Plugin_Continue;

    OrderType order = g_eCurrentOrder[commander];

    switch (order)
    {
        case Order_Follow:
        {
            // Calculate direction to commander
            float botPos[3], commanderPos[3];
            GetClientAbsOrigin(client, botPos);
            GetClientAbsOrigin(commander, commanderPos);

            float dist = GetVectorDistance(botPos, commanderPos);

            if (dist > 200.0)
            {
                // Move towards commander
                buttons |= IN_FORWARD;

                // Calculate aim angles
                float direction[3];
                MakeVectorFromPoints(botPos, commanderPos, direction);

                float newAngles[3];
                GetVectorAngles(direction, newAngles);

                TeleportEntity(client, NULL_VECTOR, newAngles, NULL_VECTOR);
            }
        }
        case Order_Hold:
        {
            // Remove movement
            buttons &= ~(IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT);
        }
    }

    return Plugin_Changed;
}
*/
