# IGL Mode — Feature Tickets

## Milestones

### M1: Proof of Concept
Basic bot control working. One player can issue simple orders to bots.

### M2: Core Game Loop
Full 1v1 match playable with squad control, economy, and basic tactics.

### M3: Tactical Interface
Visual command system — map overlay, drawing, real-time orders.

### M4: Polish & Modes
Ranked mode, practice mode, replays, quality of life.

---

## Epic 1: Bot Squad System

### T-001: Bot Ownership Assignment
**Priority**: P0 (Critical)
**Milestone**: M1

Automatically assign bots to human players at round start.

**Acceptance Criteria**:
- [ ] On round start, detect all human players and bots per team
- [ ] Distribute bots evenly (4 per player in 1v1 mode)
- [ ] Store bot→commander mapping in plugin state
- [ ] Handle edge cases: mid-round joins, disconnects, team switches
- [ ] Notify players of their squad assignment

**Technical Notes**:
- Use `IsFakeClient()` to detect bots
- Hook `round_start` and `player_spawn` events
- Consider using ArrayList per commander

---

### T-002: Squad Info Display
**Priority**: P0
**Milestone**: M1

Players can view their current squad status.

**Acceptance Criteria**:
- [ ] `!squad` command shows list of assigned bots
- [ ] Display bot name, health, alive/dead status
- [ ] Show current active order
- [ ] Update in real-time

---

### T-003: Bot Death Handling
**Priority**: P1
**Milestone**: M1

Handle squad member elimination gracefully.

**Acceptance Criteria**:
- [ ] Notify commander when their bot dies
- [ ] Remove dead bot from active squad
- [ ] Show killer info if applicable
- [ ] Update squad count display

---

### T-004: Commander Death Behavior
**Priority**: P1
**Milestone**: M2

Define what happens when the human commander dies.

**Acceptance Criteria**:
- [ ] Bots default to "hold position" when commander dies
- [ ] Option: Allow spectating through bot eyes
- [ ] Option: Allow limited orders while dead

---

## Epic 2: Order System

### T-010: Basic Movement Orders
**Priority**: P0
**Milestone**: M1

Commander can order bots to move to positions.

**Acceptance Criteria**:
- [ ] `!follow` — Bots follow commander
- [ ] `!hold` — Bots stop and hold current position
- [ ] `!regroup` — Bots group tightly on commander
- [ ] Orders apply to all squad bots

---

### T-011: Combat Orders
**Priority**: P1
**Milestone**: M2

Orders that affect combat behavior.

**Acceptance Criteria**:
- [ ] `!attack` — Aggressive push, engage on sight
- [ ] `!defend` — Defensive positioning, hold angles
- [ ] Bots adjust aggression level based on order

---

### T-012: Named Position Orders
**Priority**: P1
**Milestone**: M2

Order bots to specific map callouts.

**Acceptance Criteria**:
- [ ] `!order <bot> <position>` syntax (e.g., `!order 2 a_ramp`)
- [ ] Position database for each competitive map
- [ ] Bots navigate to named position
- [ ] Bots face appropriate angle for that position

**Maps to Support**:
- [ ] de_dust2
- [ ] de_mirage
- [ ] de_inferno
- [ ] de_overpass
- [ ] de_nuke
- [ ] de_ancient
- [ ] de_anubis

---

### T-013: Individual Bot Orders
**Priority**: P2
**Milestone**: M2

Order specific bots instead of whole squad.

**Acceptance Criteria**:
- [ ] `!order 1 hold` — Order bot 1 only
- [ ] `!order 2,3 push` — Order bots 2 and 3
- [ ] Bots numbered 1-4 in squad display

---

### T-014: Order Cooldown System
**Priority**: P2
**Milestone**: M2

Prevent order spam.

**Acceptance Criteria**:
- [ ] Configurable cooldown between orders
- [ ] Show remaining cooldown to player
- [ ] Emergency override option (costs money?)

---

### T-015: Order Queue / Waypoints
**Priority**: P3
**Milestone**: M3

Queue multiple orders for execution.

**Acceptance Criteria**:
- [ ] `!order 1 goto a_long then hold` syntax
- [ ] Bots execute orders in sequence
- [ ] Cancel queue with `!cancel`

---

## Epic 3: Economy System

### T-020: Squad Money Pool
**Priority**: P1
**Milestone**: M2

Shared economy per squad.

**Acceptance Criteria**:
- [ ] All bots share commander's money pool
- [ ] Loss bonus calculated for squad
- [ ] Display total squad money in HUD

---

### T-021: Buy Commands
**Priority**: P1
**Milestone**: M2

Commander controls bot loadouts.

**Acceptance Criteria**:
- [ ] `!buy <bot> <weapon>` — Give specific weapon
- [ ] `!fullbuy` — Full buy for all bots
- [ ] `!forcebuy` — Best available with current money
- [ ] `!eco` — Pistols only
- [ ] Respect weapon prices

---

### T-022: Utility Assignment
**Priority**: P2
**Milestone**: M2

Assign grenades to specific bots.

**Acceptance Criteria**:
- [ ] `!util <bot> smoke` — Buy smoke for bot
- [ ] `!util <bot> flash flash` — Buy 2 flashes
- [ ] Budget tracking per bot

---

### T-023: Auto-Buy Presets
**Priority**: P2
**Milestone**: M3

Save and load buy configurations.

**Acceptance Criteria**:
- [ ] `!savebuy <name>` — Save current loadout
- [ ] `!loadbuy <name>` — Apply saved loadout
- [ ] Default presets: rifle_round, eco_round, force_round

---

## Epic 4: Utility Execution

### T-030: Smoke Lineups
**Priority**: P2
**Milestone**: M2

Bots can throw pre-defined smokes.

**Acceptance Criteria**:
- [ ] `!smoke <target>` — Order bot to smoke location
- [ ] Bot moves to throw position
- [ ] Bot executes lineup (position + angle)
- [ ] Smoke lands at target

**Lineups to Implement (per map)**:
- [ ] 5-10 essential smokes per map
- [ ] Cross smokes, site smokes, connector smokes

---

### T-031: Flash Execution
**Priority**: P2
**Milestone**: M2

Pop flashes for entries.

**Acceptance Criteria**:
- [ ] `!flash <target>` — Flash specific area
- [ ] `!popflash` — Pop flash for commander's push
- [ ] Coordinate timing with entry

---

### T-032: Molotov/Incendiary
**Priority**: P3
**Milestone**: M3

Area denial utility.

**Acceptance Criteria**:
- [ ] `!molly <target>` — Molly default positions
- [ ] Common spots: corners, plants, rushes

---

### T-033: Execute Sequences
**Priority**: P2
**Milestone**: M3

Coordinated multi-bot utility execution.

**Acceptance Criteria**:
- [ ] `!exec a_default` — Run pre-defined execute
- [ ] Multiple bots throw utility in sequence
- [ ] Timing between throws
- [ ] Entry bots push after util

---

## Epic 5: Behavior Trees

### T-040: Hold Behavior Tree
**Priority**: P1
**Milestone**: M2

Bot holds position intelligently.

**Acceptance Criteria**:
- [ ] Navigate to position
- [ ] Face specified angle
- [ ] Engage enemies that appear
- [ ] Don't abandon position unless ordered
- [ ] Slight look-around for realism

---

### T-041: Push Behavior Tree
**Priority**: P1
**Milestone**: M2

Aggressive entry behavior.

**Acceptance Criteria**:
- [ ] Move toward target aggressively
- [ ] Pre-aim common angles
- [ ] Wide peek / jiggle peek mechanics
- [ ] Trade with teammates

---

### T-042: Support Behavior Tree
**Priority**: P2
**Milestone**: M2

Follow and trade.

**Acceptance Criteria**:
- [ ] Stay behind entry fragger
- [ ] Maintain tradeable distance
- [ ] React to teammate death
- [ ] Flash for entry

---

### T-043: Rotate Behavior Tree
**Priority**: P2
**Milestone**: M2

Fast rotation ignoring minor threats.

**Acceptance Criteria**:
- [ ] Sprint to destination
- [ ] Ignore enemies unless blocking path
- [ ] Callout enemies spotted during rotate

---

### T-044: Post-Plant Behavior Tree
**Priority**: P2
**Milestone**: M3

Positioning after bomb plant.

**Acceptance Criteria**:
- [ ] Spread to post-plant positions
- [ ] Crossfire setup
- [ ] Time-based aggression (play time vs peek)

---

## Epic 6: Tactical Interface

### T-050: Order Menu (In-Game)
**Priority**: P1
**Milestone**: M2

Radio-style menu for orders.

**Acceptance Criteria**:
- [ ] Key bind opens order menu
- [ ] Navigate with number keys
- [ ] Submenus for bot selection
- [ ] Quick orders accessible

---

### T-051: Map Overlay (External App)
**Priority**: P2
**Milestone**: M3

2D tactical map for issuing orders.

**Acceptance Criteria**:
- [ ] External app reads game state via RCON/GSI
- [ ] Display radar-style map
- [ ] Show bot positions in real-time
- [ ] Click to select bot
- [ ] Click to set destination
- [ ] Drag to draw routes

---

### T-052: Drawing System
**Priority**: P3
**Milestone**: M3

Draw execute routes on map.

**Acceptance Criteria**:
- [ ] Draw paths for each bot
- [ ] Set timing markers
- [ ] Save drawings as "strats"
- [ ] Share strats with community

---

### T-053: Quick Command Wheel
**Priority**: P3
**Milestone**: M3

Hold key + direction for fast orders.

**Acceptance Criteria**:
- [ ] Hold key shows radial menu
- [ ] Mouse direction selects order
- [ ] Release executes
- [ ] Customizable binds

---

## Epic 7: Game Modes

### T-060: 1v1 Mode
**Priority**: P1
**Milestone**: M2

Core competitive mode.

**Acceptance Criteria**:
- [ ] Two human players
- [ ] 4 bots each (5v5 total)
- [ ] Standard competitive rules
- [ ] MR12 or MR15 format

---

### T-061: Practice Mode
**Priority**: P2
**Milestone**: M3

Solo practice against bots.

**Acceptance Criteria**:
- [ ] Control both teams
- [ ] Unlimited money
- [ ] Round restart commands
- [ ] Grenade trajectory visualization

---

### T-062: Replay System
**Priority**: P3
**Milestone**: M4

Review matches.

**Acceptance Criteria**:
- [ ] Record all orders issued
- [ ] Playback with timeline scrubbing
- [ ] See both teams' orders (post-match)
- [ ] Analyze decision-making

---

### T-063: Ranked Mode
**Priority**: P3
**Milestone**: M4

Competitive ladder.

**Acceptance Criteria**:
- [ ] ELO-based matchmaking
- [ ] Rank display
- [ ] Season resets
- [ ] Leaderboards

---

## Epic 8: Polish & UX

### T-070: Bot Callouts
**Priority**: P2
**Milestone**: M3

Bots communicate to commander.

**Acceptance Criteria**:
- [ ] "Enemy spotted at [location]"
- [ ] "Taking damage"
- [ ] "Bomb spotted"
- [ ] Text or audio callouts

---

### T-071: HUD Elements
**Priority**: P2
**Milestone**: M3

Custom HUD for squad info.

**Acceptance Criteria**:
- [ ] Squad health bars
- [ ] Current order indicator
- [ ] Utility remaining
- [ ] Money display

---

### T-072: Sound Design
**Priority**: P3
**Milestone**: M4

Audio feedback for orders.

**Acceptance Criteria**:
- [ ] Order confirmation sounds
- [ ] Bot acknowledgment voice lines
- [ ] Alert sounds for squad events

---

### T-073: Tutorial Mode
**Priority**: P3
**Milestone**: M4

Teach new players.

**Acceptance Criteria**:
- [ ] Interactive tutorial
- [ ] Explain each order type
- [ ] Practice scenarios
- [ ] Tips and strategies

---

## Epic 9: Infrastructure

### T-080: Server Configuration
**Priority**: P0
**Milestone**: M1

Proper server setup.

**Acceptance Criteria**:
- [ ] MetaMod + SourceMod installation guide
- [ ] Config files for IGL Mode
- [ ] Map rotation setup
- [ ] Bot difficulty settings

---

### T-081: Map Position Database
**Priority**: P1
**Milestone**: M2

Position data for all maps.

**Acceptance Criteria**:
- [ ] JSON/KV file format for positions
- [ ] Position name, coordinates, facing angle
- [ ] Utility lineup data
- [ ] Tools to add new positions in-game

---

### T-082: Workshop Integration
**Priority**: P3
**Milestone**: M4

Steam Workshop support.

**Acceptance Criteria**:
- [ ] Publish mod to Workshop
- [ ] Auto-update mechanism
- [ ] Custom map support

---

### T-083: Docker Development Environment
**Priority**: P2
**Milestone**: M2

Containerized dev setup.

**Acceptance Criteria**:
- [ ] Dockerfile for CS:GO server
- [ ] MetaMod + SourceMod pre-installed
- [ ] Volume mounts for plugin development
- [ ] Works on Mac/Windows/Linux

---

## Priority Key

- **P0**: Must have for milestone
- **P1**: Should have for milestone
- **P2**: Nice to have for milestone
- **P3**: Future / stretch goal
