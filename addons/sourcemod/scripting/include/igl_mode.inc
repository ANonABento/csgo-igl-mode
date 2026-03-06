/**
 * =============================================================================
 * IGL Mode - Include File
 * =============================================================================
 *
 * Include this file in other plugins to interact with IGL Mode.
 *
 * =============================================================================
 */

#if defined _igl_mode_included
    #endinput
#endif
#define _igl_mode_included

// =============================================================================
// CONSTANTS
// =============================================================================

#define IGL_VERSION "1.0.0"
#define IGL_MAX_SQUAD_SIZE 4

// Order types (must match main plugin)
enum IGLOrderType
{
    IGL_Order_None = 0,
    IGL_Order_Follow,
    IGL_Order_Hold,
    IGL_Order_Attack,
    IGL_Order_Defend,
    IGL_Order_Regroup
}

// Formation types
enum IGLFormationType
{
    IGL_Formation_Default = 0,
    IGL_Formation_Line,
    IGL_Formation_Wedge,
    IGL_Formation_Stack
}

// =============================================================================
// FORWARDS
// =============================================================================

/**
 * Called when a squad is assigned to a commander.
 *
 * @param commander     Client index of the commander (human player)
 * @param squadSize     Number of bots in the squad
 */
forward void IGL_OnSquadAssigned(int commander, int squadSize);

/**
 * Called when a commander issues an order to their squad.
 *
 * @param commander     Client index of the commander
 * @param order         The order type being issued
 * @param position      The target position for the order
 */
forward void IGL_OnOrderIssued(int commander, IGLOrderType order, const float position[3]);

/**
 * Called when a squad member (bot) dies.
 *
 * @param commander     Client index of the commander
 * @param bot           Client index of the bot that died
 * @param attacker      Client index of the attacker (0 if world)
 */
forward void IGL_OnSquadMemberDeath(int commander, int bot, int attacker);

/**
 * Called when a commander's entire squad is eliminated.
 *
 * @param commander     Client index of the commander
 */
forward void IGL_OnSquadEliminated(int commander);

// =============================================================================
// NATIVES
// =============================================================================

/**
 * Checks if IGL Mode is currently enabled.
 *
 * @return              True if enabled, false otherwise
 */
native bool IGL_IsEnabled();

/**
 * Gets the commander of a bot.
 *
 * @param bot           Client index of the bot
 * @return              Client index of commander, or -1 if not in a squad
 */
native int IGL_GetBotCommander(int bot);

/**
 * Gets the number of bots in a commander's squad.
 *
 * @param commander     Client index of the commander
 * @return              Number of bots in squad, or 0 if invalid
 */
native int IGL_GetSquadSize(int commander);

/**
 * Gets all bots in a commander's squad.
 *
 * @param commander     Client index of the commander
 * @param bots          Array to store bot client indices
 * @param maxSize       Maximum size of the array
 * @return              Number of bots stored in array
 */
native int IGL_GetSquadMembers(int commander, int[] bots, int maxSize);

/**
 * Gets the current order for a commander's squad.
 *
 * @param commander     Client index of the commander
 * @return              Current order type
 */
native IGLOrderType IGL_GetCurrentOrder(int commander);

/**
 * Manually assigns a bot to a commander.
 *
 * @param bot           Client index of the bot
 * @param commander     Client index of the commander
 * @return              True if successful, false otherwise
 */
native bool IGL_AssignBot(int bot, int commander);

/**
 * Releases a bot from its current squad.
 *
 * @param bot           Client index of the bot
 * @return              True if successful, false otherwise
 */
native bool IGL_ReleaseBot(int bot);

/**
 * Issues an order to a commander's squad programmatically.
 *
 * @param commander     Client index of the commander
 * @param order         Order to issue
 * @param position      Target position (can be NULL_VECTOR for some orders)
 * @return              True if successful, false otherwise
 */
native bool IGL_IssueOrder(int commander, IGLOrderType order, const float position[3]);

// =============================================================================
// STOCKS (Helper functions)
// =============================================================================

/**
 * Checks if a client is a valid commander (human, in-game, not a bot)
 *
 * @param client        Client index to check
 * @return              True if valid commander, false otherwise
 */
stock bool IGL_IsValidCommander(int client)
{
    return (client > 0 && client <= MaxClients &&
            IsClientInGame(client) && !IsFakeClient(client));
}

/**
 * Checks if a client is a valid squad bot
 *
 * @param client        Client index to check
 * @return              True if valid bot, false otherwise
 */
stock bool IGL_IsValidSquadBot(int client)
{
    return (client > 0 && client <= MaxClients &&
            IsClientInGame(client) && IsFakeClient(client) &&
            IGL_GetBotCommander(client) != -1);
}

/**
 * Gets the order name as a string
 *
 * @param order         Order type
 * @param buffer        Buffer to store the name
 * @param maxlen        Maximum length of buffer
 */
stock void IGL_GetOrderName(IGLOrderType order, char[] buffer, int maxlen)
{
    switch (order)
    {
        case IGL_Order_None:     strcopy(buffer, maxlen, "None");
        case IGL_Order_Follow:   strcopy(buffer, maxlen, "Follow");
        case IGL_Order_Hold:     strcopy(buffer, maxlen, "Hold");
        case IGL_Order_Attack:   strcopy(buffer, maxlen, "Attack");
        case IGL_Order_Defend:   strcopy(buffer, maxlen, "Defend");
        case IGL_Order_Regroup:  strcopy(buffer, maxlen, "Regroup");
        default:                 strcopy(buffer, maxlen, "Unknown");
    }
}

// =============================================================================
// LIBRARY REGISTRATION
// =============================================================================

public SharedPlugin __pl_igl_mode =
{
    name = "igl_mode",
    file = "igl_mode.smx",
#if defined REQUIRE_PLUGIN
    required = 1,
#else
    required = 0,
#endif
};

#if !defined REQUIRE_PLUGIN
public void __pl_igl_mode_SetNTVOptional()
{
    MarkNativeAsOptional("IGL_IsEnabled");
    MarkNativeAsOptional("IGL_GetBotCommander");
    MarkNativeAsOptional("IGL_GetSquadSize");
    MarkNativeAsOptional("IGL_GetSquadMembers");
    MarkNativeAsOptional("IGL_GetCurrentOrder");
    MarkNativeAsOptional("IGL_AssignBot");
    MarkNativeAsOptional("IGL_ReleaseBot");
    MarkNativeAsOptional("IGL_IssueOrder");
}
#endif
