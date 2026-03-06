# CS:GO IGL Mode

**1v1 tactical showdown where each player commands a 4-bot squad.**

Turn CS:GO into an IGL simulator. You're not just fragging—you're calling strats, assigning positions, controlling utility usage, and leading your team to victory.

## The Concept

- **1v1 format** — Two human players face off
- **5v5 gameplay** — Each player controls 4 AI bots
- **Full tactical control** — Assign positions, call rotates, manage economy, dictate utility usage
- **IGL experience** — Open the map, draw executes, coordinate your squad

Think chess meets CS:GO. Your mechanical skill matters, but your reads and calls win rounds.

## Planned Features

### Core Bot Control
- [ ] Assign bots to specific map positions (hold A ramp, watch mid, etc.)
- [ ] Call rotates in real-time
- [ ] Trigger fallback positions
- [ ] Set aggression levels (passive hold vs active peek)

### Economy & Loadouts
- [ ] Control bot weapon purchases
- [ ] Assign specific utility (smoke A, flash for entry, molly default)
- [ ] Force eco/force buy/full buy commands
- [ ] Manage team economy as IGL

### Tactical Interface
- [ ] Map overlay for issuing commands
- [ ] Draw execute routes
- [ ] Set waypoints and timings
- [ ] Pre-program strat sequences

### Game Modes
- [ ] **Ranked 1v1** — Competitive ladder
- [ ] **Practice Mode** — Test strats against bot team
- [ ] **Replay Review** — Analyze your calls

## Technical Stack

| Component | Technology |
|-----------|------------|
| Server Framework | SourceMod + MetaMod:Source |
| Bot AI | CS:GO Behavior Trees (.kv3) |
| Game Logic | VScript (Squirrel) |
| UI | Scaleform / External Overlay |
| Base Game | CS:GO (standalone, March 2025) |

## Project Structure

```
csgo-igl-mode/
├── docs/                    # Documentation
│   ├── ARCHITECTURE.md      # System design
│   ├── SETUP.md             # Dev environment setup
│   ├── FEATURES.md          # Feature specifications
│   └── BOT_BEHAVIOR.md      # Behavior tree reference
├── src/
│   ├── sourcemod/           # SourceMod plugins (.sp)
│   ├── vscripts/            # VScript files (.nut)
│   └── behavior_trees/      # Custom bot AI (.kv3)
├── assets/                  # UI assets, radar overlays
└── examples/                # Example configs and strats
```

## Why CS:GO (not CS2)?

CS2 runs on Source 2, which doesn't yet support:
- SourceMod (waiting on Source2Mod)
- Behavior Trees for bots
- Full VScript capabilities

**Good news:** As of March 2025, Valve re-released CS:GO as a [standalone download](https://store.steampowered.com/app/730/CounterStrike_Global_Offensive/) (unlisted but accessible). No more `csgo_legacy` beta workaround needed.

Note: Official matchmaking is disabled, but community servers work perfectly—which is exactly what we need for this mod.

## Getting Started

See [docs/SETUP.md](docs/SETUP.md) for development environment setup.

## Status

**Phase: Research & Documentation**

Currently documenting the technical approach and gathering references from existing bot mods.

## References

- [CS:GO Bot Behavior Trees](https://developer.valvesoftware.com/wiki/Counter-Strike:_Global_Offensive/Bot_Behavior_Trees) — Valve documentation
- [BOT Improver](https://forums.alliedmods.net/showthread.php?t=320719) — SourceMod plugin for enhanced bots
- [Flying Fox AI](https://steamcommunity.com/sharedfiles/filedetails/?id=2887812541) — Advanced bot behavior example
- [ProBots](https://www.moddb.com/mods/probots) — Community bot enhancement mod
- [VScript Examples](https://developer.valvesoftware.com/wiki/CS:GO_VScript_Examples) — Valve VScript reference

## License

MIT
