# Bot Behavior Trees Reference

## Overview

CS:GO uses Behavior Trees (BTs) for bot AI. These are defined in `.kv3` files and describe decision-making logic as a tree of nodes.

**Location:** `csgo/scripts/ai/`
**Default tree:** `bt_default.kv3`
**Custom tree ConVar:** `mp_bot_ai_bt "scripts/ai/your_tree.kv3"`

## KV3 Syntax

```kv3
<!-- kv3 encoding:text:version{e21c7f3c-8a33-41c5-9977-a76d3a32aa0d} format:generic:version{7412167c-06e9-4698-aff2-e63eb59037e7} -->
{
    type = "sequencer"
    children =
    [
        {
            type = "action"
            action = "BotActionMoveTo"
        }
    ]
}
```

## Node Types

### Control Flow Nodes

#### Sequencer
Executes children in order. Fails if any child fails.
```kv3
{
    type = "sequencer"
    children = [
        { type = "action", action = "FirstAction" },
        { type = "action", action = "SecondAction" }
    ]
}
```

#### Selector
Tries children in order until one succeeds.
```kv3
{
    type = "selector"
    children = [
        { type = "condition", condition = "CanSeeEnemy" },
        { type = "action", action = "SearchForEnemy" }
    ]
}
```

#### Decorator
Modifies child behavior.
```kv3
{
    type = "decorator_repeat"
    child = { type = "action", action = "Patrol" }
}
```

### Condition Nodes

Check game state, return success/failure.

| Condition | Description |
|-----------|-------------|
| `ShouldHurry` | Time pressure (bomb, round time) |
| `IsLowOnHealth` | Health below threshold |
| `CanSeeEnemy` | Has visual on enemy |
| `HasPath` | Navigation path exists |
| `IsReloading` | Currently reloading |
| `HasPrimary` | Has primary weapon |
| `IsBombPlanted` | Bomb is down |
| `IsDefuser` | Bot has defuse kit |
| `IsLastAlive` | Last bot on team |

### Action Nodes

Execute behavior, return success/failure/running.

| Action | Description |
|--------|-------------|
| `MoveTo` | Navigate to position |
| `Attack` | Engage visible enemy |
| `Reload` | Reload weapon |
| `PlantBomb` | Plant at bombsite |
| `DefuseBomb` | Defuse bomb |
| `BuyEquipment` | Purchase gear |
| `ThrowGrenade` | Use grenade |
| `Wait` | Wait for duration |
| `LookAround` | Scan surroundings |
| `Hide` | Take cover |
| `Follow` | Follow target entity |

## Example: Hold Position

```kv3
<!-- kv3 encoding:text:version{e21c7f3c-8a33-41c5-9977-a76d3a32aa0d} format:generic:version{7412167c-06e9-4698-aff2-e63eb59037e7} -->
{
    // Root: Selector tries options until one works
    type = "selector"
    children =
    [
        // Priority 1: Engage enemy if visible
        {
            type = "sequencer"
            children =
            [
                { type = "condition", condition = "CanSeeEnemy" },
                { type = "action", action = "Attack" }
            ]
        },
        // Priority 2: Navigate to hold position if not there
        {
            type = "sequencer"
            children =
            [
                { type = "condition", condition = "HasOrderPosition" },
                { type = "decorator_not", child = { type = "condition", condition = "IsAtOrderPosition" } },
                { type = "action", action = "MoveToOrderPosition" }
            ]
        },
        // Priority 3: Hold current angle
        {
            type = "sequencer"
            children =
            [
                { type = "action", action = "FaceOrderAngle" },
                { type = "action", action = "Wait", duration = 0.5 }
            ]
        }
    ]
}
```

## Custom Conditions for IGL Mode

We'll need to add custom conditions to check order state:

### Order Checking
```kv3
// Check if bot has an active order
{ type = "condition", condition = "HasIGLOrder" }

// Check specific order type
{ type = "condition", condition = "IGLOrderIs", order_type = "hold" }
{ type = "condition", condition = "IGLOrderIs", order_type = "push" }
{ type = "condition", condition = "IGLOrderIs", order_type = "rotate" }

// Check if at ordered position
{ type = "condition", condition = "IsAtIGLPosition" }
```

### Order Actions
```kv3
// Move to ordered position
{ type = "action", action = "MoveToIGLPosition" }

// Face ordered angle
{ type = "action", action = "FaceIGLAngle" }

// Execute ordered utility
{ type = "action", action = "ThrowIGLUtility" }
```

## IGL Bot Behavior Tree

Full tree for IGL-controlled bots:

```kv3
<!-- kv3 encoding:text:version{e21c7f3c-8a33-41c5-9977-a76d3a32aa0d} format:generic:version{7412167c-06e9-4698-aff2-e63eb59037e7} -->
{
    type = "selector"
    children =
    [
        // === IMMEDIATE THREATS ===
        // Always handle combat first
        {
            type = "sequencer"
            name = "combat"
            children =
            [
                { type = "condition", condition = "CanSeeEnemy" },
                { type = "action", action = "Attack" }
            ]
        },

        // === IGL ORDERS ===
        // Execute player commands
        {
            type = "sequencer"
            name = "execute_order"
            children =
            [
                { type = "condition", condition = "HasIGLOrder" },
                {
                    type = "selector"
                    children =
                    [
                        // HOLD ORDER
                        {
                            type = "sequencer"
                            children =
                            [
                                { type = "condition", condition = "IGLOrderIs", order_type = "hold" },
                                {
                                    type = "selector"
                                    children =
                                    [
                                        // Move to position if not there
                                        {
                                            type = "sequencer"
                                            children =
                                            [
                                                { type = "decorator_not", child = { type = "condition", condition = "IsAtIGLPosition" } },
                                                { type = "action", action = "MoveToIGLPosition" }
                                            ]
                                        },
                                        // Hold angle
                                        {
                                            type = "sequencer"
                                            children =
                                            [
                                                { type = "action", action = "FaceIGLAngle" },
                                                { type = "action", action = "Wait", duration = 0.5 },
                                                { type = "action", action = "LookAround", range = 30 }
                                            ]
                                        }
                                    ]
                                }
                            ]
                        },

                        // PUSH ORDER
                        {
                            type = "sequencer"
                            children =
                            [
                                { type = "condition", condition = "IGLOrderIs", order_type = "push" },
                                { type = "action", action = "MoveToIGLPosition", style = "aggressive" },
                                { type = "action", action = "ClearArea" }
                            ]
                        },

                        // ROTATE ORDER
                        {
                            type = "sequencer"
                            children =
                            [
                                { type = "condition", condition = "IGLOrderIs", order_type = "rotate" },
                                { type = "action", action = "MoveToIGLPosition", style = "fast" }
                            ]
                        },

                        // SUPPORT ORDER
                        {
                            type = "sequencer"
                            children =
                            [
                                { type = "condition", condition = "IGLOrderIs", order_type = "support" },
                                { type = "action", action = "FollowSquadLead", distance = 300 }
                            ]
                        },

                        // FALLBACK ORDER
                        {
                            type = "sequencer"
                            children =
                            [
                                { type = "condition", condition = "IGLOrderIs", order_type = "fallback" },
                                { type = "action", action = "MoveToIGLPosition", style = "careful" },
                                { type = "action", action = "FaceEnemyDirection" }
                            ]
                        },

                        // UTILITY ORDER
                        {
                            type = "sequencer"
                            children =
                            [
                                { type = "condition", condition = "IGLOrderIs", order_type = "utility" },
                                { type = "action", action = "MoveToIGLUtilitySpot" },
                                { type = "action", action = "ThrowIGLUtility" },
                                { type = "action", action = "ClearIGLOrder" }
                            ]
                        }
                    ]
                }
            ]
        },

        // === DEFAULT BEHAVIOR ===
        // No order: follow squad lead
        {
            type = "sequencer"
            name = "default"
            children =
            [
                { type = "action", action = "FollowSquadLead", distance = 200 }
            ]
        }
    ]
}
```

## Implementing Custom Actions

Custom actions require C++ extension or SourceMod hooks. For MVP, use existing actions with VScript bridges:

### VScript Bridge Pattern

```squirrel
// In VScript: Set entity context that BT can read
function IGL_SetOrder(botIndex, orderType, positionName) {
    local bot = GetBotByIndex(botIndex);
    local pos = IGL_POSITIONS[positionName];

    // Store order in entity context
    bot.SetContext("igl_order", orderType, 0);
    bot.SetContextVector("igl_target_pos", pos.origin);
    bot.SetContextVector("igl_target_ang", pos.angle);

    // Use built-in BT actions by setting bot goals
    bot.SetGoalEntity(CreateGoalEntity(pos.origin));
}
```

The BT then uses standard `MoveTo` action with the goal entity set by VScript.

## Debugging

### Console Commands

```
bot_debug 1              // Show decision tree
bot_debug_target <name>  // Debug specific bot
mp_bot_ai_bt ""          // Reset to default BT
nav_edit 1               // See navigation mesh
```

### Adding Debug Output

```kv3
{
    type = "action"
    action = "DebugPrint"
    message = "Executing hold behavior"
}
```

## References

- [Valve BT Documentation](https://developer.valvesoftware.com/wiki/Counter-Strike:_Global_Offensive/Bot_Behavior_Trees)
- [bt_default.kv3](file://csgo/scripts/ai/bt_default.kv3) - Default bot behavior
- [bt_coop.kv3](file://csgo/scripts/ai/bt_coop.kv3) - Co-op mission behavior
- [bt_guardian.kv3](file://csgo/scripts/ai/bt_guardian.kv3) - Guardian mode behavior
