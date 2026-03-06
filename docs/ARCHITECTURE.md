# Architecture

## System Overview

```
┌─────────────────────────────────────────────────────────────────────┐
│                         CS:GO IGL Mode                               │
├─────────────────────────────────────────────────────────────────────┤
│                                                                      │
│  ┌──────────────────┐    ┌──────────────────┐    ┌───────────────┐ │
│  │   Command Layer  │    │   Bot AI Layer   │    │   UI Layer    │ │
│  │   (SourceMod)    │◄──►│  (Behavior Trees)│◄──►│  (Scaleform)  │ │
│  └────────┬─────────┘    └────────┬─────────┘    └───────┬───────┘ │
│           │                       │                       │         │
│           ▼                       ▼                       ▼         │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                    Game State Manager                         │  │
│  │                       (VScript)                               │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                │                                    │
│                                ▼                                    │
│  ┌──────────────────────────────────────────────────────────────┐  │
│  │                     CS:GO Server                              │  │
│  │              (Source Engine + Game Rules)                     │  │
│  └──────────────────────────────────────────────────────────────┘  │
│                                                                      │
└─────────────────────────────────────────────────────────────────────┘
```

## Core Components

### 1. Command Layer (SourceMod Plugin)

**Purpose:** Handle player inputs, route commands to bots, manage game state.

**Responsibilities:**
- Player authentication and squad assignment
- Command parsing (move, hold, rotate, buy)
- Bot ownership tracking (which bots belong to which player)
- Round state management
- Economy tracking per squad

**Key Files:**
- `src/sourcemod/igl_core.sp` — Main plugin
- `src/sourcemod/igl_commands.sp` — Command handlers
- `src/sourcemod/igl_economy.sp` — Buy system
- `src/sourcemod/igl_squads.sp` — Bot-player assignment

**Example Command Flow:**
```
Player Input: "Bot 2, hold A ramp"
      │
      ▼
SourceMod parses command
      │
      ▼
Looks up Bot 2 in player's squad
      │
      ▼
Sets bot's current_order = "hold"
Sets bot's target_position = "a_ramp"
      │
      ▼
Bot's Behavior Tree reads order
      │
      ▼
Bot navigates to A ramp, enters hold state
```

### 2. Bot AI Layer (Behavior Trees)

**Purpose:** Execute tactical behaviors based on received orders.

**Key Concepts:**

CS:GO bots use Behavior Trees (`.kv3` files) that define decision-making logic:

```
Selector (try each until success)
├── Sequence: Execute Order
│   ├── Condition: HasOrder?
│   ├── Action: NavigateToOrderPosition
│   └── Action: ExecuteOrderBehavior
├── Sequence: Default Behavior
│   ├── Action: FollowSquadLeader
│   └── Action: EngageEnemies
└── Action: Idle
```

**Order Types:**
| Order | Behavior |
|-------|----------|
| `hold` | Navigate to position, face angle, hold until enemy or rotate call |
| `push` | Aggressive movement toward position, engage on sight |
| `rotate` | Fast movement to new position, ignore minor contacts |
| `fallback` | Retreat to defensive position |
| `support` | Follow squad leader at distance, trade kills |

**Key Files:**
- `src/behavior_trees/igl_bot.kv3` — Main behavior tree
- `src/behavior_trees/orders/hold.kv3` — Hold position logic
- `src/behavior_trees/orders/execute.kv3` — Site execute logic

### 3. UI Layer

**Purpose:** Tactical map interface for issuing commands.

**Options (ranked by complexity):**

#### Option A: Radio Menu (Simplest)
Use SourceMod's built-in menu system:
```
[1] Squad Commands
    [1] Bot 1: Hold
    [2] Bot 2: Hold
    [3] Bot 3: Push
    [4] Bot 4: Support
[2] Call Rotate
[3] Call Execute
[4] Economy
```
- **Pros:** Works out of box, no custom UI
- **Cons:** Clunky, not visual

#### Option B: Console Commands
```
/order bot1 hold a_ramp
/order bot2 hold a_site
/rotate all b
/execute a_split
```
- **Pros:** Fast for power users
- **Cons:** High learning curve

#### Option C: External Overlay (Recommended MVP)
Separate application that:
- Reads game state via RCON
- Displays interactive map
- Sends commands back to server

```
┌─────────────────────────────────┐
│        Tactical Map             │
│  ┌───────────────────────────┐  │
│  │        [A Site]           │  │
│  │    ●1        ●2           │  │
│  │         [Mid]             │  │
│  │              ●3           │  │
│  │        [B Site]           │  │
│  │    ●4                     │  │
│  └───────────────────────────┘  │
│  [Hold] [Push] [Rotate] [Fall]  │
└─────────────────────────────────┘
● = Your bots (clickable)
```
- **Pros:** Best UX, visual tactics
- **Cons:** Requires external app development

#### Option D: Custom Scaleform UI (Advanced)
Modify CS:GO's Flash-based UI system.
- **Pros:** Fully integrated
- **Cons:** Complex, fragile, limited documentation

### 4. Game State Manager (VScript)

**Purpose:** Bridge between SourceMod and Behavior Trees, track positions.

**Responsibilities:**
- Named position registry (map landmarks → coordinates)
- Bot state tracking
- Order queue management
- Strat sequences (timed multi-bot actions)

**Key Files:**
- `src/vscripts/igl_state.nut` — State management
- `src/vscripts/igl_positions.nut` — Map position definitions
- `src/vscripts/igl_strats.nut` — Pre-defined strat sequences

## Data Flow

### Issuing an Order

```
1. Player selects bot + command via UI
                │
                ▼
2. UI sends command to SourceMod
   Format: "igl_order <bot_id> <order_type> <position>"
                │
                ▼
3. SourceMod validates:
   - Is this bot in player's squad?
   - Is position valid for current map?
   - Is order allowed in current state?
                │
                ▼
4. SourceMod writes to bot's entity keyvalues:
   - "igl_order" = "hold"
   - "igl_target" = "a_ramp"
                │
                ▼
5. Bot's Behavior Tree (running continuously):
   - Checks "igl_order" keyvalue
   - Enters corresponding behavior branch
   - Navigates to target, executes behavior
                │
                ▼
6. State Manager tracks completion:
   - Bot reaches position → "holding"
   - Bot engages enemy → "engaged"
   - Bot dies → "dead"
```

### Round Flow

```
Freeze Time
    │
    ├─► Players assign positions
    ├─► Players set buy orders
    └─► Bots purchase equipment
           │
           ▼
Round Start
    │
    ├─► Bots move to assigned positions
    ├─► Players can call adjustments
    └─► Combat happens
           │
           ▼
Round End
    │
    ├─► Update economy
    ├─► Track performance stats
    └─► Reset for next round
```

## Map Position System

Each map needs a position registry:

```squirrel
// src/vscripts/maps/de_dust2.nut

IGL_POSITIONS <- {
    // A Site
    "a_site":      { origin = Vector(-1394, 2464, 96),  angle = QAngle(0, 90, 0) },
    "a_ramp":      { origin = Vector(-1150, 2750, 160), angle = QAngle(0, 180, 0) },
    "a_car":       { origin = Vector(-1580, 2300, 96),  angle = QAngle(0, 45, 0) },
    "a_long":      { origin = Vector(-1950, 2200, 64),  angle = QAngle(0, 90, 0) },

    // Mid
    "mid_doors":   { origin = Vector(-480, 1280, -64),  angle = QAngle(0, 90, 0) },
    "mid_xbox":    { origin = Vector(-420, 1750, 32),   angle = QAngle(0, 0, 0) },
    "mid_palm":    { origin = Vector(-780, 600, 32),    angle = QAngle(0, 90, 0) },

    // B Site
    "b_site":      { origin = Vector(-1472, 2560, -96), angle = QAngle(0, 0, 0) },
    "b_tuns":      { origin = Vector(-1200, 1100, -96), angle = QAngle(0, 0, 0) },
    "b_car":       { origin = Vector(-1700, 2750, -96), angle = QAngle(0, -90, 0) },

    // ... etc
}
```

## Economy System

Track money per squad, not per bot:

```
Squad Economy
├── Total: $16,000
├── Loss bonus: $1,900
└── Round result: Won (+$3,250)

Buy Phase
├── Player allocates budget
│   ├── Bot 1: AK + Vest + Flash×2 ($3,900)
│   ├── Bot 2: AK + Vest + Smoke ($3,600)
│   ├── Bot 3: AWP + Vest ($5,250)
│   └── Bot 4: Deagle + Flash ($1,050)
│
└── Remaining: $2,200
```

## Communication Protocol

### SourceMod ↔ VScript

Using `ServerCommand` and entity I/O:

```sourcepawn
// SourceMod side
public void IssueOrder(int botId, const char[] order, const char[] position) {
    ServerCommand("script IGL_SetOrder(%d, \"%s\", \"%s\")", botId, order, position);
}
```

```squirrel
// VScript side
function IGL_SetOrder(botId, order, position) {
    local bot = GetBotById(botId);
    bot.SetContextString("igl_order", order);
    bot.SetContextString("igl_target", position);
}
```

### SourceMod ↔ External UI

Via RCON or custom socket:

```
← UI connects to server RCON
→ Server authenticates
← UI requests game state: "igl_state"
→ Server responds with JSON:
  {
    "round": 5,
    "phase": "live",
    "squads": {
      "player1": {
        "bots": [
          {"id": 1, "position": "a_ramp", "status": "holding", "health": 100},
          {"id": 2, "position": "a_site", "status": "holding", "health": 75}
        ],
        "money": 12400
      }
    }
  }
← UI sends command: "igl_order 1 rotate b_site"
→ Server acknowledges
```

## Future Considerations

### Strat Scripting Language

Allow players to define reusable strats:

```yaml
# strats/a_split.yaml
name: "A Split"
timing: on_execute_call
steps:
  - bot: 1
    action: throw_smoke
    target: a_cross
    wait: 0
  - bot: 2
    action: throw_flash
    target: a_site
    wait: 1.5
  - bot: 1
    action: push
    target: a_long
    wait: 0
  - bot: 3
    action: push
    target: a_short
    wait: 0.5
```

### Machine Learning Integration

Train bot decision-making on pro match data:
- When to peek vs hold
- Trade timing
- Rotation triggers

This is future scope—start with deterministic behavior trees.
