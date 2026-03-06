# IGL Mode - Implementation Plan

## Current State Analysis

### What's Built (Working)
| Component | Status | Notes |
|-----------|--------|-------|
| Squad Assignment | **100%** | Bot→Commander mapping works |
| Event System | **100%** | Death, spawn, round events hooked |
| Command Parsing | **100%** | !order, !squad, !follow etc registered |
| Menu System | **90%** | Basic order menu functional |
| Config System | **100%** | ConVars, auto-exec config |
| VScript Bridge | **30%** | State tracking works, commands don't |

### What's Broken/Stubbed
| Component | Issue |
|-----------|-------|
| Bot Movement | Uses `FakeClientCommand("bot_goto")` - unreliable, bots ignore it |
| Behavior Trees | **0% - Completely missing** - bots use default CS:GO AI |
| Position System | **0%** - No map coordinates, no named positions |
| Bot Control | Orders are sent but bots don't respond |

### Critical Insight
The current plugin *looks* complete but **bots won't actually follow orders** because:
1. `bot_goto` command is unreliable in CS:GO
2. No custom behavior tree to make bots listen to IGL orders
3. No position database for named callouts

---

## Revised Milestone Structure

### M0: Foundation Fix (NEW - Must Do First)
**Goal:** Bots actually respond to orders

Without this, nothing else works. Current code sends orders but bots ignore them.

| Task | Priority | Est. Effort |
|------|----------|-------------|
| Research actual bot control methods | P0 | 2h |
| Create minimal behavior tree | P0 | 4h |
| Test OnPlayerRunCmd bot control | P0 | 4h |
| Verify one bot follows one order | P0 | 2h |

**Exit Criteria:** Issue `!hold` → bot stops moving. Issue `!follow` → bot follows you.

---

### M1: Proof of Concept (Revised)
**Goal:** One player commands 4 bots with basic orders

**Dependencies:** M0 complete

| ID | Task | Blocks | Status |
|----|------|--------|--------|
| M1-1 | Bot ownership assignment | - | DONE |
| M1-2 | Squad info display (!squad) | - | DONE |
| M1-3 | Bot death notifications | - | DONE |
| M1-4 | Basic behavior tree (hold/follow) | M1-5 | TODO |
| M1-5 | Movement orders work (!hold, !follow, !regroup) | - | BLOCKED |
| M1-6 | Commander death → bots hold | M1-4 | TODO |

**Exit Criteria:** Load plugin, spawn with bots, issue orders, bots respond correctly.

---

### M2: Tactical Orders
**Goal:** Full order vocabulary, position-based commands

**Dependencies:** M1 complete

| ID | Task | Blocks | Status |
|----|------|--------|--------|
| M2-1 | Position database schema | M2-2 | TODO |
| M2-2 | de_dust2 positions (10 callouts) | M2-4 | TODO |
| M2-3 | Extended behavior tree (push/rotate/support) | M2-4 | TODO |
| M2-4 | Named position orders (!order 1 a_long) | - | TODO |
| M2-5 | Individual bot selection (!order 1,2 hold) | - | TODO |
| M2-6 | Order cooldown system | - | DONE |

**Exit Criteria:** `!order 2 a_ramp` → bot 2 moves to A ramp and holds angle.

---

### M3: Economy & Loadouts
**Goal:** Control what bots buy

**Dependencies:** M2 complete (needs position system for buy zones)

| ID | Task | Blocks |
|----|------|--------|
| M3-1 | Squad money pool tracking | M3-2 |
| M3-2 | Buy commands (!buy 1 ak47) | M3-4 |
| M3-3 | Loadout presets (!fullbuy, !eco) | - |
| M3-4 | Utility assignment (!util 1 smoke) | M4-* |

---

### M4: Utility Execution
**Goal:** Bots throw grenades on command

**Dependencies:** M3 complete (needs utility in inventory)

| ID | Task | Blocks |
|----|------|--------|
| M4-1 | Smoke lineup database schema | M4-2 |
| M4-2 | de_dust2 smoke lineups (5 essential) | M4-4 |
| M4-3 | Utility behavior tree | M4-4 |
| M4-4 | Smoke execution (!smoke xbox) | - |
| M4-5 | Flash execution (!flash a_long) | - |

---

### M5: Game Mode & Polish
**Goal:** Complete 1v1 experience

| ID | Task |
|----|------|
| M5-1 | 1v1 mode rules (4 bots each) |
| M5-2 | Round-based economy |
| M5-3 | Bot callouts ("Enemy spotted A long") |
| M5-4 | HUD elements (squad health) |
| M5-5 | Practice mode (both teams) |

---

## Implementation Order (Critical Path)

```
┌─────────────────────────────────────────────────────────────┐
│                    CURRENT BLOCKER                          │
│                                                             │
│   Bot control doesn't work. FakeClientCommand is ignored.  │
│   Must fix this before ANY feature works.                  │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ M0-1: Research Bot Control Options                          │
│                                                             │
│ Options to investigate:                                     │
│ 1. OnPlayerRunCmd hook (force buttons/angles)              │
│ 2. Custom behavior tree with ConVar-driven conditions      │
│ 3. Entity manipulation (SetGoalEntity)                     │
│ 4. NavMesh hiding spots + bot_goto to specific coords      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ M0-2: Create Minimal Behavior Tree                          │
│                                                             │
│ File: scripts/ai/igl_bot.kv3                               │
│                                                             │
│ Must implement:                                             │
│ - Read order from ConVar (igl_bot_X_order)                 │
│ - ORDER_HOLD: Stop moving, face current angle              │
│ - ORDER_FOLLOW: Move toward commander position             │
│ - Still engage enemies when visible                        │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ M0-3: Update Plugin to Use ConVars for Orders               │
│                                                             │
│ Instead of: FakeClientCommand(bot, "bot_goto...")          │
│ Do:         SetConVarInt(igl_bot_5_order, ORDER_HOLD)      │
│                                                             │
│ BT reads: @igl_bot_5_order (@ prefix reads ConVar)         │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
┌─────────────────────────────────────────────────────────────┐
│ M1: Orders Actually Work                                    │
│                                                             │
│ Test: !hold → all squad bots stop                          │
│ Test: !follow → bots follow commander                      │
│ Test: !regroup → bots cluster tightly                      │
└─────────────────────────────────────────────────────────────┘
                              │
                              ▼
                    [Continue to M2...]
```

---

## Technical Approach: Bot Control

### Option A: Behavior Tree + ConVars (Recommended)

**How it works:**
1. Plugin sets ConVar: `igl_bot_5_order 2` (bot index 5, order HOLD)
2. Behavior tree condition checks: `@igl_bot_5_order == 2`
3. If true, execute HOLD subtree (stop moving, hold angle)

**Pros:** Clean, uses Valve's system, bots make own decisions
**Cons:** Need to learn KV3 syntax, limited action vocabulary

### Option B: OnPlayerRunCmd Hook

**How it works:**
```sourcepawn
public Action OnPlayerRunCmd(int client, int &buttons, ...)
{
    if (!IsFakeClient(client)) return Plugin_Continue;

    int order = g_iBotOrder[client];
    if (order == ORDER_HOLD) {
        buttons &= ~IN_FORWARD;  // Stop moving
        buttons &= ~IN_BACK;
    }
    return Plugin_Changed;
}
```

**Pros:** Direct control, works immediately
**Cons:** Fighting against bot AI, janky movement

### Option C: Hybrid (Best)

Use **behavior tree for decisions**, **OnPlayerRunCmd for fine control**:
- BT decides: "I should hold position"
- OnPlayerRunCmd: Force exact facing angle, prevent unwanted movement

---

## File Structure (To Create)

```
csgo-igl-mode/
├── scripts/ai/
│   ├── igl_bot.kv3              # Main IGL behavior tree
│   ├── igl_hold.kv3             # Hold position subtree
│   ├── igl_follow.kv3           # Follow subtree
│   └── igl_push.kv3             # Aggressive push subtree
├── data/positions/
│   ├── de_dust2.json            # Position database
│   ├── de_mirage.json
│   └── _schema.json             # Position format spec
├── data/lineups/
│   ├── de_dust2_smokes.json     # Smoke lineup data
│   └── _schema.json
└── addons/sourcemod/scripting/
    ├── igl_mode.sp              # Main plugin (exists)
    ├── igl_bot_control.sp       # NEW: OnPlayerRunCmd hooks
    └── igl_positions.sp         # NEW: Position database
```

---

## Next Actions

### Immediate (Today)
1. **Research**: Look at existing CS:GO BT mods that actually work
2. **Test**: Try OnPlayerRunCmd with a simple "stop bot" command
3. **Verify**: Does `mp_bot_ai_bt` actually load custom trees?

### This Week
1. Create `igl_bot.kv3` with hold/follow behaviors
2. Update plugin to use ConVar communication
3. Test one bot following one order

### Blockers to Resolve
- [ ] Do we have a CS:GO server to test on? (macOS can't run SourceMod)
- [ ] Need to find/study a working bot control mod for reference
- [ ] Verify KV3 syntax works in CS:GO (vs CS2)

---

## Reference: Working Bot Mods to Study

1. **Retakes** - Bots position at bombsites, hold angles
2. **PugSetup** - Bot placeholder system
3. **Practice Mode** - Bot grenade throw commands
4. **BotMimic** - Records/replays bot movement (different approach)

These prove bot control is possible - need to study their techniques.

---

## Risk Assessment

| Risk | Impact | Mitigation |
|------|--------|------------|
| Custom BTs don't work in CS:GO | High | Fall back to OnPlayerRunCmd |
| Bot pathfinding too dumb | Medium | Use simpler orders, named positions |
| No macOS testing | High | Docker/VM with CS:GO server |
| Valve breaks API | Low | CS:GO is "finished", unlikely to change |

---

## Success Metrics

### M0 Complete When:
- [ ] `!hold` makes bots stop moving
- [ ] `!follow` makes bots follow commander
- [ ] Bots still shoot enemies

### M1 Complete When:
- [ ] Full squad responds to orders
- [ ] Dead bots removed from squad
- [ ] Commander can see squad status

### MVP Complete When:
- [ ] Two players can 1v1 with 4 bots each
- [ ] Named position orders work on de_dust2
- [ ] Basic economy/buying works
