# Feature Roadmap

## Phase 1: Proof of Concept

**Goal:** One player can give basic orders to one bot.

### P1.1 - Bot Ownership
- [ ] SourceMod plugin tracks which bots belong to which player
- [ ] Console command: `/squad` shows your bots
- [ ] Bots auto-assigned on round start (4 per player)

### P1.2 - Basic Movement Orders
- [ ] Console command: `/order <bot_id> <position>`
- [ ] Bot navigates to named position
- [ ] Position registry for de_dust2 (10-15 key spots)

### P1.3 - Hold Behavior
- [ ] Bot reaches position and holds angle
- [ ] Basic engagement when enemy spotted
- [ ] Doesn't abandon position unless ordered

**Success Criteria:** Player types `/order 1 a_ramp`, bot walks to A ramp and holds.

---

## Phase 2: Core IGL Loop

**Goal:** Full round can be played with tactical control.

### P2.1 - Order Types
- [ ] `hold` - Stay at position, engage threats
- [ ] `push` - Aggressive movement, entry frag style
- [ ] `support` - Follow squad lead at distance
- [ ] `fallback` - Retreat to defensive position
- [ ] `rotate` - Fast rotate, ignore minor contacts

### P2.2 - Team Commands
- [ ] `/all hold` - All bots hold current positions
- [ ] `/rotate <site>` - All bots rotate to site
- [ ] `/execute` - Begin site take (pre-defined per map)
- [ ] `/fall` - Everyone fall back to default positions

### P2.3 - Round Phases
- [ ] Freeze time: Accept position assignments
- [ ] Live: Orders executable in real-time
- [ ] Post-round: Stats summary

### P2.4 - Basic Economy
- [ ] Squad money pool (shared economy)
- [ ] `/buy ak 2` - Give bot 2 an AK
- [ ] Automatic eco detection (low money = pistols)
- [ ] Loss bonus tracking

**Success Criteria:** Play a full 15-round half with tactical control.

---

## Phase 3: Utility Control

**Goal:** Control bot utility usage like a real IGL.

### P3.1 - Utility Assignment
- [ ] `/util <bot_id> smoke <target>` - Bot will smoke that spot
- [ ] `/util <bot_id> flash <target>` - Pop flash for teammate
- [ ] `/util <bot_id> molly <target>` - Molotov lineup
- [ ] Utility queuing (throw in sequence)

### P3.2 - Execute Sequences
- [ ] Pre-program utility sequences
- [ ] `/exec a_default` triggers:
  - Bot 1: Smoke CT
  - Bot 2: Smoke cross
  - Bot 3: Flash site
  - Bot 4: Entry
- [ ] Timing delays between actions

### P3.3 - Lineup System
- [ ] Map-specific utility lineups stored
- [ ] Bots know where to stand + aim for each smoke/flash
- [ ] Visual indicator when bot is ready to throw

**Success Criteria:** Execute a coordinated A take with smokes and flashes.

---

## Phase 4: Visual Tactical Interface

**Goal:** Replace console commands with interactive map.

### P4.1 - Map Overlay (MVP)
- [ ] External app reads game state via RCON
- [ ] Displays 2D map with bot positions
- [ ] Click bot → click position = move order
- [ ] Status indicators (health, weapon, utility)

### P4.2 - Drawing System
- [ ] Draw paths for bots to follow
- [ ] Mark positions with icons
- [ ] Save drawings as "strats"

### P4.3 - In-Game Integration
- [ ] Minimal HUD showing bot status
- [ ] Quick command wheel (hold key + direction)
- [ ] Voice command support (stretch goal)

**Success Criteria:** Issue all commands without opening console.

---

## Phase 5: Game Modes

**Goal:** Structured competitive experience.

### P5.1 - 1v1 Ranked Mode
- [ ] Matchmaking system
- [ ] ELO/ranking
- [ ] Map pool selection
- [ ] Match history

### P5.2 - Practice Mode
- [ ] Control both teams
- [ ] Pause/rewind
- [ ] Test strats in isolation

### P5.3 - Spectator Mode
- [ ] Watch live 1v1 games
- [ ] See both players' commands
- [ ] Educational for learning IGLing

---

## Phase 6: Advanced AI

**Goal:** Bots that feel like real teammates.

### P6.1 - Intelligent Defaults
- [ ] Bots make reasonable decisions when no orders given
- [ ] Trade kills automatically
- [ ] Call out enemy positions
- [ ] Eco round behavior (save weapons)

### P6.2 - Adaptive Behavior
- [ ] Bots learn opponent patterns
- [ ] Adjust aggression based on round situation
- [ ] Man advantage = more aggressive
- [ ] Bomb planted = post-plant positioning

### P6.3 - Personality System
- [ ] Aggressive vs passive bots
- [ ] Rifler vs AWPer tendencies
- [ ] Entry fragger vs support player

---

## Stretch Goals

### Strat Editor
- Visual strat builder
- Share strats with community
- Import pro team strats from demos

### Voice Commands
- "Bot one, hold A ramp"
- Speech-to-text integration
- Natural language processing

### Replay System
- Record matches
- Review your calls vs outcomes
- AI coaching suggestions

### CS2 Port
- When Source2Mod matures
- CounterStrikeSharp integration
- Behavior tree alternatives

---

## Priority Matrix

| Feature | Impact | Effort | Priority |
|---------|--------|--------|----------|
| Bot ownership | High | Low | P0 |
| Basic movement | High | Low | P0 |
| Hold behavior | High | Medium | P0 |
| Order types | High | Medium | P1 |
| Team commands | Medium | Low | P1 |
| Economy | Medium | Medium | P1 |
| Utility assignment | High | High | P2 |
| Execute sequences | High | High | P2 |
| Map overlay | Very High | High | P2 |
| Drawing system | Medium | High | P3 |
| Ranked mode | Medium | Very High | P3 |
| Advanced AI | Medium | Very High | P4 |

---

## Non-Goals (For Now)

- Mobile companion app
- Cross-platform (Windows only initially)
- Integration with FACEIT/ESEA
- Anti-cheat (community servers only)
- 2v2 or larger team sizes (maybe later)
