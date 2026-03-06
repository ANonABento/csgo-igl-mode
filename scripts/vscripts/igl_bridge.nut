/**
 * =============================================================================
 * IGL Mode - VScript Bridge
 * =============================================================================
 *
 * This VScript file receives commands from the SourceMod plugin and provides
 * additional bot control capabilities using the VScript API.
 *
 * Place this file in: csgo/scripts/vscripts/igl_bridge.nut
 * Load it via: script_execute igl_bridge
 *
 * =============================================================================
 */

// =============================================================================
// CONFIGURATION
// =============================================================================

::IGL_CONFIG <- {
    debug = true,
    orderTimeout = 10.0,
    followDistance = 150.0,
    regroupDistance = 75.0,
    updateInterval = 0.1
}

// =============================================================================
// ORDER CONSTANTS (must match SourceMod enum)
// =============================================================================

::ORDER_NONE <- 0
::ORDER_FOLLOW <- 1
::ORDER_HOLD <- 2
::ORDER_ATTACK <- 3
::ORDER_DEFEND <- 4
::ORDER_REGROUP <- 5

// =============================================================================
// GLOBAL STATE
// =============================================================================

// Squad data: commander_id -> { members = [...], order = ORDER_*, position = Vector }
::IGL_Squads <- {}

// Bot states for fine-grained control
::IGL_BotStates <- {}

// =============================================================================
// SOURCEMOD BRIDGE FUNCTIONS
// These functions are called by ServerCommand from SourceMod
// =============================================================================

/**
 * Receives an order from SourceMod
 * Called via: script IGL_ReceiveOrder(commander, order, position)
 */
::IGL_ReceiveOrder <- function(commanderId, orderType, position)
{
    if (IGL_CONFIG.debug)
    {
        printl("[IGL] Received order - Commander: " + commanderId + ", Order: " + orderType)
    }

    // Update or create squad entry
    if (!(commanderId in IGL_Squads))
    {
        IGL_Squads[commanderId] <- {
            members = [],
            order = ORDER_NONE,
            position = Vector(0, 0, 0),
            lastUpdate = Time()
        }
    }

    IGL_Squads[commanderId].order = orderType
    IGL_Squads[commanderId].position = position
    IGL_Squads[commanderId].lastUpdate = Time()

    // Execute the order on all squad members
    foreach (botId in IGL_Squads[commanderId].members)
    {
        IGL_ExecuteBotOrder(botId, orderType, position)
    }
}

/**
 * Updates squad composition from SourceMod
 * Called via: script IGL_UpdateSquad("commanderId,bot1,bot2,...", orderType)
 */
::IGL_UpdateSquad <- function(squadDataStr, orderType)
{
    // Parse the squad data string
    local parts = split(squadDataStr, ",")

    if (parts.len() < 1)
        return

    local commanderId = parts[0].tointeger()

    // Create or update squad
    if (!(commanderId in IGL_Squads))
    {
        IGL_Squads[commanderId] <- {
            members = [],
            order = ORDER_NONE,
            position = Vector(0, 0, 0),
            lastUpdate = Time()
        }
    }

    // Update members list
    IGL_Squads[commanderId].members = []
    for (local i = 1; i < parts.len(); i++)
    {
        local botId = parts[i].tointeger()
        IGL_Squads[commanderId].members.append(botId)

        // Initialize bot state if needed
        if (!(botId in IGL_BotStates))
        {
            IGL_BotStates[botId] <- {
                commander = commanderId,
                currentOrder = ORDER_NONE,
                targetPosition = null,
                lastCommandTime = 0
            }
        }
        IGL_BotStates[botId].commander = commanderId
    }

    IGL_Squads[commanderId].order = orderType
    IGL_Squads[commanderId].lastUpdate = Time()

    if (IGL_CONFIG.debug)
    {
        printl("[IGL] Updated squad for commander " + commanderId + " with " + IGL_Squads[commanderId].members.len() + " members")
    }
}

// =============================================================================
// BOT CONTROL FUNCTIONS
// =============================================================================

/**
 * Executes an order on a specific bot
 */
::IGL_ExecuteBotOrder <- function(botId, orderType, targetPosition)
{
    local bot = PlayerInstanceFromIndex(botId)

    if (bot == null)
    {
        if (IGL_CONFIG.debug)
            printl("[IGL] Bot " + botId + " not found")
        return
    }

    // Update bot state
    if (botId in IGL_BotStates)
    {
        IGL_BotStates[botId].currentOrder = orderType
        IGL_BotStates[botId].targetPosition = targetPosition
        IGL_BotStates[botId].lastCommandTime = Time()
    }

    switch (orderType)
    {
        case ORDER_FOLLOW:
            IGL_OrderFollow(bot, targetPosition)
            break

        case ORDER_HOLD:
            IGL_OrderHold(bot)
            break

        case ORDER_ATTACK:
            IGL_OrderAttack(bot)
            break

        case ORDER_DEFEND:
            IGL_OrderDefend(bot, targetPosition)
            break

        case ORDER_REGROUP:
            IGL_OrderRegroup(bot, targetPosition)
            break
    }
}

/**
 * Order: Follow the commander
 */
::IGL_OrderFollow <- function(bot, targetPosition)
{
    if (bot == null)
        return

    // Calculate offset position (don't stack on commander)
    local offset = Vector(
        RandomFloat(-IGL_CONFIG.followDistance, IGL_CONFIG.followDistance),
        RandomFloat(-IGL_CONFIG.followDistance, IGL_CONFIG.followDistance),
        0
    )

    local destination = targetPosition + offset

    // Use bot_goto command via SendToConsole
    // Note: SendToConsole only works server-side in CS:GO
    local cmd = format("bot_goto %.1f %.1f %.1f", destination.x, destination.y, destination.z)
    SendToConsole(cmd)

    if (IGL_CONFIG.debug)
        printl("[IGL] Bot following to " + destination)
}

/**
 * Order: Hold current position
 */
::IGL_OrderHold <- function(bot)
{
    if (bot == null)
        return

    SendToConsole("bot_stop 1")

    if (IGL_CONFIG.debug)
        printl("[IGL] Bot holding position")
}

/**
 * Order: Attack aggressively
 */
::IGL_OrderAttack <- function(bot)
{
    if (bot == null)
        return

    SendToConsole("bot_stop 0")

    if (IGL_CONFIG.debug)
        printl("[IGL] Bot attacking")
}

/**
 * Order: Defend position
 */
::IGL_OrderDefend <- function(bot, defendPosition)
{
    if (bot == null)
        return

    // Move to defend position and hold
    local cmd = format("bot_goto %.1f %.1f %.1f", defendPosition.x, defendPosition.y, defendPosition.z)
    SendToConsole(cmd)

    // After a delay, stop moving
    // Note: Would need a think function for delayed commands

    if (IGL_CONFIG.debug)
        printl("[IGL] Bot defending at " + defendPosition)
}

/**
 * Order: Regroup on commander (tighter than follow)
 */
::IGL_OrderRegroup <- function(bot, targetPosition)
{
    if (bot == null)
        return

    local offset = Vector(
        RandomFloat(-IGL_CONFIG.regroupDistance, IGL_CONFIG.regroupDistance),
        RandomFloat(-IGL_CONFIG.regroupDistance, IGL_CONFIG.regroupDistance),
        0
    )

    local destination = targetPosition + offset

    local cmd = format("bot_goto %.1f %.1f %.1f", destination.x, destination.y, destination.z)
    SendToConsole(cmd)

    if (IGL_CONFIG.debug)
        printl("[IGL] Bot regrouping to " + destination)
}

// =============================================================================
// UTILITY FUNCTIONS
// =============================================================================

/**
 * Get a player entity from their client index
 */
::PlayerInstanceFromIndex <- function(index)
{
    local player = null

    while ((player = Entities.FindByClassname(player, "player")) != null)
    {
        if (player.entindex() == index)
            return player
    }

    // Also check for bots
    while ((player = Entities.FindByClassname(player, "cs_bot")) != null)
    {
        if (player.entindex() == index)
            return player
    }

    return null
}

/**
 * Get the current time
 */
::Time <- function()
{
    return Entities.FindByClassname(null, "cs_gamerules").GetScriptScope().Time()
}

/**
 * Generate random float between min and max
 */
::RandomFloat <- function(min, max)
{
    return min + (rand() % 1000) * (max - min) / 1000.0
}

/**
 * Get distance between two vectors
 */
::VectorDistance <- function(v1, v2)
{
    local diff = v2 - v1
    return diff.Length()
}

// =============================================================================
// QUERY FUNCTIONS (called by external scripts)
// =============================================================================

/**
 * Get the current order for a commander's squad
 */
::IGL_GetSquadOrder <- function(commanderId)
{
    if (commanderId in IGL_Squads)
        return IGL_Squads[commanderId].order
    return ORDER_NONE
}

/**
 * Get squad member count
 */
::IGL_GetSquadSize <- function(commanderId)
{
    if (commanderId in IGL_Squads)
        return IGL_Squads[commanderId].members.len()
    return 0
}

/**
 * Check if a bot belongs to a squad
 */
::IGL_IsBotInSquad <- function(botId)
{
    return (botId in IGL_BotStates && IGL_BotStates[botId].commander != null)
}

/**
 * Get a bot's commander
 */
::IGL_GetBotCommander <- function(botId)
{
    if (botId in IGL_BotStates)
        return IGL_BotStates[botId].commander
    return null
}

// =============================================================================
// THINK FUNCTION (for continuous updates)
// =============================================================================

/**
 * Main think loop - called periodically to update bot behaviors
 * To enable, add this entity think to a logic_script
 */
::IGL_Think <- function()
{
    local currentTime = Time()

    // Update each bot based on their current orders
    foreach (botId, state in IGL_BotStates)
    {
        if (state.currentOrder == ORDER_NONE)
            continue

        // Check if order has timed out
        if (currentTime - state.lastCommandTime > IGL_CONFIG.orderTimeout)
        {
            state.currentOrder = ORDER_NONE
            continue
        }

        local bot = PlayerInstanceFromIndex(botId)
        if (bot == null)
            continue

        // Continuous behavior updates
        switch (state.currentOrder)
        {
            case ORDER_FOLLOW:
            {
                // Check distance to commander and move if too far
                local commander = PlayerInstanceFromIndex(state.commander)
                if (commander != null)
                {
                    local distance = VectorDistance(bot.GetOrigin(), commander.GetOrigin())
                    if (distance > IGL_CONFIG.followDistance * 2)
                    {
                        IGL_OrderFollow(bot, commander.GetOrigin())
                    }
                }
                break
            }
            // Add other continuous behaviors as needed
        }
    }

    return IGL_CONFIG.updateInterval
}

// =============================================================================
// INITIALIZATION
// =============================================================================

::IGL_Initialize <- function()
{
    printl("=================================")
    printl("IGL Mode VScript Bridge Loaded")
    printl("=================================")

    // Clear any existing state
    IGL_Squads <- {}
    IGL_BotStates <- {}

    printl("[IGL] Ready to receive commands from SourceMod")
}

// Auto-initialize on script load
IGL_Initialize()

// =============================================================================
// EVENT LISTENERS (using vs_library pattern if available)
// =============================================================================

/**
 * To listen for game events, you would typically use logic_eventlistener
 * entities in your map, or use the vs_library if available.
 *
 * Example with vs_library:
 *
 * if ("VS" in getroottable() && "ListenToGameEvent" in VS)
 * {
 *     VS.ListenToGameEvent("round_start", function(event) {
 *         IGL_Initialize()
 *     })
 *
 *     VS.ListenToGameEvent("player_death", function(event) {
 *         local victim = event.userid
 *         // Handle squad member death
 *     })
 * }
 */

// =============================================================================
// DEBUG COMMANDS
// =============================================================================

/**
 * Print debug info about all squads
 * Call via: script IGL_DebugPrint()
 */
::IGL_DebugPrint <- function()
{
    printl("=== IGL Debug Info ===")
    printl("Squads: " + IGL_Squads.len())

    foreach (commanderId, squad in IGL_Squads)
    {
        printl("  Commander " + commanderId + ":")
        printl("    Members: " + squad.members.len())
        printl("    Order: " + squad.order)
        printl("    Position: " + squad.position)
    }

    printl("Bot States: " + IGL_BotStates.len())
    foreach (botId, state in IGL_BotStates)
    {
        printl("  Bot " + botId + ":")
        printl("    Commander: " + state.commander)
        printl("    Current Order: " + state.currentOrder)
    }
}
