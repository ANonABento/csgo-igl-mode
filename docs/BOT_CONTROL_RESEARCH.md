# Bot Control Research - CS:GO IGL Mode

## Executive Summary

After researching existing CS:GO mods, SourceMod APIs, behavior trees, and bot commands, here are the key findings:

### What Works
| Method | Reliability | Use Case |
|--------|-------------|----------|
| `TeleportEntity()` | **Excellent** | Positioning bots at exact locations |
| `OnPlayerRunCmd()` | **Good** | Direct movement/button control |
| `bot_stop 1` | **Excellent** | Freezing bot AI completely |
| `bot_goto_mark` | **Good** | Nav mesh pathfinding |
| Behavior Trees + ConVars | **Good** | Decision logic via `@cvar` syntax |

### What Doesn't Work
| Method | Issue |
|--------|-------|
| `FakeClientCommand("bot_goto")` | Bots ignore it |
| `FakeClientCommand("+forward")` | Not a console command |
| `angles[]` in OnPlayerRunCmd | Doesn't control view angles |
| Custom BT conditions | Node types are hardcoded |

### Recommended Approach
**Hybrid: OnPlayerRunCmd + bot_stop + TeleportEntity**

1. Use `bot_stop 1` to freeze native bot AI
2. Control movement via `OnPlayerRunCmd` (buttons, velocity)
3. Set view angles via `TeleportEntity()`
4. Use nav mesh for pathfinding reference

---

## Research Findings

### 1. How Existing Mods Control Bots

#### Retakes (splewis/csgo-retakes)
- **Bots not supported** - automatically moved to spectate
- Uses `TeleportEntity()` for player positioning only
- Spawn positions stored in KeyValues config files

#### Practice Mode (splewis/csgo-practice-mode)
- **Bots are static props** - stand in place, don't move or fight
- Uses `TeleportEntity()` for positioning
- Grenade throwing **bypasses bot AI entirely**:
  ```sourcepawn
  // Creates grenade entity directly, no bot throwing animation
  int entity = CreateEntityByName("smokegrenade_projectile");
  TeleportEntity(entity, origin, NULL_VECTOR, velocity);
  DispatchSpawn(entity);
  ```

#### BotMimic (peace-maker/botmimic)
- **Most sophisticated bot control**
- Records human input via `OnPlayerRunCmdPost()`
- Replays to bots via `OnPlayerRunCmd()`
- Stores: buttons, velocity, angles, weapon switches, teleports
- Uses periodic position snapshots to prevent drift

**Key code pattern:**
```sourcepawn
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse,
                              float vel[3], float angles[3], ...) {
    if (g_hBotMimicsRecord[client] == null) return Plugin_Continue;

    // Get recorded frame
    int iFrame[FrameInfo];
    g_hBotMimicsRecord[client].GetArray(g_iBotMimicTick[client], iFrame, ...);

    // Apply recorded inputs
    buttons = iFrame[playerButtons];
    Array_Copy(iFrame[predictedVelocity], vel, 3);

    // Handle teleportation for angles (not via angles[] param!)
    TeleportEntity(client, NULL_VECTOR, frame.angles, NULL_VECTOR);

    return Plugin_Changed;
}
```

**Takeaway:** No existing mod uses behavior trees. All use TeleportEntity + OnPlayerRunCmd.

---

### 2. OnPlayerRunCmd for Bot Control

#### Function Signature
```sourcepawn
forward Action OnPlayerRunCmd(
    int client,           // Player index
    int &buttons,         // Modifiable - movement/action bitflags
    int &impulse,         // Modifiable - impulse command
    float vel[3],         // Desired velocity vector (NOT world velocity!)
    float angles[3],      // Movement angles (NOT view angles!)
    int &weapon,          // Weapon being switched to
    int &subtype,         // Weapon subtype
    int &cmdnum,          // Command number
    int &tickcount,       // Tick count
    int &seed,            // Random seed
    int mouse[2]          // Mouse delta
);
```

#### Button Constants
```sourcepawn
IN_ATTACK       (1 << 0)   // Primary fire
IN_JUMP         (1 << 1)   // Jump
IN_DUCK         (1 << 2)   // Crouch
IN_FORWARD      (1 << 3)   // Move forward
IN_BACK         (1 << 4)   // Move backward
IN_USE          (1 << 5)   // Use/interact
IN_MOVELEFT     (1 << 9)   // Strafe left
IN_MOVERIGHT    (1 << 10)  // Strafe right
IN_ATTACK2      (1 << 11)  // Secondary fire/scope
IN_RELOAD       (1 << 13)  // Reload
IN_SPEED        (1 << 17)  // Walk (shift)
```

#### Critical Limitation: View Angles
**The `angles[]` parameter does NOT control where the bot looks!**

```sourcepawn
// WRONG - bot won't look at target
angles[0] = targetPitch;
angles[1] = targetYaw;

// CORRECT - use TeleportEntity for view angles
TeleportEntity(bot, NULL_VECTOR, targetAngles, NULL_VECTOR);
```

#### Movement Vector
The `vel[]` array is **relative to facing direction**, not world space:
- `vel[0]` = Forward/Back (450 = full forward, -450 = full back)
- `vel[1]` = Left/Right (-450 = left, 450 = right)
- `vel[2]` = Up/Down (vertical movement)

#### Moving Bot to Specific Position
```sourcepawn
float g_vecBotDestination[MAXPLAYERS + 1][3];
bool g_bBotMoving[MAXPLAYERS + 1];

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse,
                              float move[3], float angles[3], ...) {
    if (!IsFakeClient(client) || !g_bBotMoving[client])
        return Plugin_Continue;

    float pos[3], dest[3], direction[3];
    GetClientAbsOrigin(client, pos);
    dest = g_vecBotDestination[client];

    // Check if arrived
    float distance = GetVectorDistance(pos, dest);
    if (distance < 32.0) {
        g_bBotMoving[client] = false;
        move[0] = 0.0;
        move[1] = 0.0;
        return Plugin_Changed;
    }

    // Calculate world direction
    SubtractVectors(dest, pos, direction);
    NormalizeVector(direction, direction);
    ScaleVector(direction, 450.0);

    // Convert to local movement space
    float yaw = angles[1] * (3.14159 / 180.0);
    float sin = Sine(yaw);
    float cos = Cosine(yaw);

    move[0] = cos * direction[0] - sin * direction[1];
    move[1] = sin * direction[0] + cos * direction[1];

    return Plugin_Changed;
}
```

#### Stopping a Bot
```sourcepawn
public Action OnPlayerRunCmd(int client, int &buttons, int &impulse,
                              float move[3], ...) {
    if (IsFakeClient(client) && g_bBotShouldHold[client]) {
        move[0] = 0.0;
        move[1] = 0.0;
        move[2] = 0.0;
        buttons &= ~(IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT | IN_JUMP);
        return Plugin_Changed;
    }
    return Plugin_Continue;
}
```

#### Native Bot AI Conflict
Native bots (created via `bot_add`) have their own AI that fights for control.

**Solutions:**
1. `bot_stop 1` - Freezes all bot AI (requires sv_cheats 1)
2. Zero inputs in OnPlayerRunCmd - Override every tick
3. Use `CreateFakeClient()` - No AI, but animation issues

---

### 3. Behavior Trees + ConVar Communication

#### ConVar Reading with @ Prefix
**Yes, behavior trees CAN read ConVars:**
```kv3
type = "action_choose_bomb_site_area"
input = "@mp_guardian_target_site"  // Reads ConVar value
output = "BombSiteArea"
```

#### Loading Custom Behavior Trees
```
mp_bot_ai_bt "scripts/ai/custom/igl_bot.kv3"
mp_bot_ai_bt_clear_cache  // Clear cache after editing
mp_restartgame 1          // Apply changes
```

#### Available Node Types

**Control Flow:**
- `selector` - OR logic, tries children until success
- `sequence` - AND logic, runs children in order
- `parallel` - Run all children simultaneously
- `subtree` - Include external .kv3 file

**Decorators:**
- `decorator_bot_service` - Memory management
- `decorator_buy_service` - Buy logic
- `decorator_repeat` - Loop behavior
- `decorator_succeed` - Force success
- `decorator_maybe` - Probabilistic execution

**Actions:**
- `action_pull_trigger` - Fire weapon
- `action_jump` - Jump
- `action_wait` - Pause
- `action_coordinated_buy` - Strategic purchasing

**Conditions:**
- `condition_out_of_ammo` - Check ammo
- `condition_is_empty` - Check existence
- Supports `negated = 1` for inverse

#### Limitation: No Custom Node Types
Node types are **hardcoded in the game engine**. You cannot create new conditions or actions through modding.

**Workarounds:**
1. Read ConVars in nodes that support it (@ prefix)
2. Use `action_set_global_counter` for state
3. Swap entire behavior trees via SourceMod based on game state

---

### 4. Bot Commands Reference

#### Reliable Commands (sv_cheats 1)
| Command | Effect |
|---------|--------|
| `bot_stop 1` | **Freezes all bot actions** - most important! |
| `bot_freeze 1` | Prevents movement only |
| `bot_dont_shoot 1` | Bots aim but don't fire |
| `bot_zombie 1` | Bots idle completely |
| `bot_crouch 1` | Forces crouch |
| `bot_place` | Spawns bot at crosshair |
| `bot_mimic 1` | Bots copy your actions |

#### Navigation Commands
| Command | Effect |
|---------|--------|
| `nav_edit 1` | Enable nav mesh editor |
| `bot_goto_mark` | Bot walks to marked nav area |
| `bot_goto_selected` | Bot goes to selected nav area |

#### Broken/Unreliable
| Command | Issue |
|---------|-------|
| `bot_difficulty` | Often ignored by dynamic difficulty |
| `bot_goto` | Not a command - only works as behavior tree action |

---

## Recommended Architecture for IGL Mode

Based on research, here's the recommended approach:

### Hybrid System

```
┌─────────────────────────────────────────────────────────────┐
│                    SourceMod Plugin                         │
│                                                             │
│  1. On round start: bot_stop 1 (freeze native AI)          │
│  2. Track squad assignments per commander                   │
│  3. Parse orders (!hold, !follow, !goto a_long)            │
│  4. Set per-bot state (g_iBotOrder[], g_vecBotTarget[])    │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    OnPlayerRunCmd Hook                       │
│                                                             │
│  For each bot every tick:                                   │
│  - If ORDER_HOLD: zero all movement                         │
│  - If ORDER_FOLLOW: calculate vel[] toward commander        │
│  - If ORDER_GOTO: calculate vel[] toward target position    │
│  - Set buttons (IN_FORWARD, IN_DUCK, etc.)                 │
│  - Use TeleportEntity() for view angles                     │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│                    Combat Override                           │
│                                                             │
│  If enemy visible:                                          │
│  - Calculate aim angles                                     │
│  - TeleportEntity(bot, NULL_VECTOR, aimAngles, NULL_VECTOR)│
│  - buttons |= IN_ATTACK                                    │
│  - Override movement orders (fight first)                  │
└─────────────────────────────────────────────────────────────┘
```

### Why Not Pure Behavior Trees?

1. **Limited ConVar support** - Only specific nodes read @ prefix
2. **No custom conditions** - Can't check "IGL order type"
3. **Hard to debug** - BT execution is opaque
4. **SourceMod integration** - Need to communicate squad state anyway

### Why Not Pure OnPlayerRunCmd?

1. **Pathfinding** - Need nav mesh for complex routes
2. **Combat AI** - Native aim/shoot logic is sophisticated
3. **Animations** - Pure OnPlayerRunCmd can break animations

### Hybrid Benefits

- `bot_stop 1` disables native AI → full control
- `OnPlayerRunCmd` → precise movement/buttons
- `TeleportEntity` → reliable view angles
- Use nav mesh queries for pathfinding hints
- Re-enable native AI (`bot_stop 0`) for combat when needed

---

## Implementation Plan

### Phase 1: Basic Hold/Follow
```sourcepawn
// Global state
int g_iBotOrder[MAXPLAYERS + 1];
float g_vecBotTarget[MAXPLAYERS + 1][3];
int g_iBotCommander[MAXPLAYERS + 1];

public void OnPluginStart() {
    HookEvent("round_start", Event_RoundStart);
    RegConsoleCmd("sm_hold", Command_Hold);
    RegConsoleCmd("sm_follow", Command_Follow);
}

public void Event_RoundStart(Event event, ...) {
    ServerCommand("bot_stop 1");  // Freeze native AI
}

public Action OnPlayerRunCmd(int client, int &buttons, int &impulse,
                              float move[3], float angles[3], ...) {
    if (!IsFakeClient(client)) return Plugin_Continue;

    switch (g_iBotOrder[client]) {
        case ORDER_HOLD: {
            move[0] = 0.0;
            move[1] = 0.0;
            buttons &= ~(IN_FORWARD | IN_BACK | IN_MOVELEFT | IN_MOVERIGHT);
            return Plugin_Changed;
        }
        case ORDER_FOLLOW: {
            int commander = g_iBotCommander[client];
            if (IsValidClient(commander)) {
                float cmdPos[3];
                GetClientAbsOrigin(commander, cmdPos);
                CalculateMovement(client, cmdPos, move, angles);
                return Plugin_Changed;
            }
        }
    }
    return Plugin_Continue;
}
```

### Phase 2: Combat Override
```sourcepawn
// Check for visible enemies each tick
int enemy = GetVisibleEnemy(client);
if (enemy > 0) {
    // Aim at enemy
    float aimAngles[3];
    CalculateAimAngles(client, enemy, aimAngles);
    TeleportEntity(client, NULL_VECTOR, aimAngles, NULL_VECTOR);

    // Fire
    buttons |= IN_ATTACK;
}
```

### Phase 3: Position Database
```json
// data/positions/de_dust2.json
{
  "a_long": {
    "origin": [1200, 500, 0],
    "angles": [0, 180, 0]
  },
  "a_ramp": {
    "origin": [800, 300, 64],
    "angles": [0, 135, 0]
  }
}
```

```sourcepawn
// Load positions on map start
public void OnMapStart() {
    char mapName[64];
    GetCurrentMap(mapName, sizeof(mapName));
    LoadPositionDatabase(mapName);
}

// !goto a_long
public Action Command_Goto(int client, int args) {
    char posName[32];
    GetCmdArg(1, posName, sizeof(posName));

    float pos[3];
    if (GetPositionByName(posName, pos)) {
        for (int bot : GetSquadBots(client)) {
            g_iBotOrder[bot] = ORDER_GOTO;
            g_vecBotTarget[bot] = pos;
        }
    }
}
```

---

## Key References

### Plugins to Study
- [peace-maker/botmimic](https://github.com/peace-maker/botmimic) - Best OnPlayerRunCmd example
- [splewis/csgo-practice-mode](https://github.com/splewis/csgo-practice-mode) - Bot positioning
- [1ci/replay-bots](https://github.com/1ci/replay-bots) - Movement replay

### Documentation
- [SourceMod OnPlayerRunCmd API](https://sm.alliedmods.net/new-api/sdktools_hooks/OnPlayerRunCmd)
- [Valve Bot Behavior Trees](https://developer.valvesoftware.com/wiki/Counter-Strike:_Global_Offensive/Bot_Behavior_Trees)
- [Navigation Mesh Editing](https://developer.valvesoftware.com/wiki/Nav_Mesh_Editing)

### AlliedModders Threads
- [Fake Client Movement](https://forums.alliedmods.net/archive/index.php/t-263420.html)
- [Velocity to Walk Toward Point](https://forums.alliedmods.net/archive/index.php/t-271835.html)
- [BOT Improver](https://forums.alliedmods.net/archive/index.php/t-320719.html)

---

## Summary

| Question | Answer |
|----------|--------|
| Use FakeClientCommand for movement? | **No** - doesn't work |
| Use behavior trees? | **Partially** - good for decisions, limited communication |
| Use OnPlayerRunCmd? | **Yes** - primary control method |
| Use TeleportEntity? | **Yes** - for positioning and view angles |
| Disable native AI? | **Yes** - `bot_stop 1` on round start |
| Handle combat? | Detect visible enemies, override movement with aim/shoot |
