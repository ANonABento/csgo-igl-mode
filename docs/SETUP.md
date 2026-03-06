# Development Setup

## Prerequisites

- Steam with CS:GO ownership
- Basic knowledge of SourceMod plugin development (SourcePawn)
- Familiarity with command line

## 1. Install CS:GO Legacy

CS2 replaced CS:GO, but the legacy version is still accessible:

1. Open Steam → Library → Counter-Strike 2
2. Right-click → Properties
3. Go to "Betas" tab
4. Select `csgo_legacy - Legacy Version of CS:GO`
5. Wait for download (~25GB)

Verify installation:
```bash
ls ~/Library/Application\ Support/Steam/steamapps/common/Counter-Strike\ Global\ Offensive/
# Should see: csgo/ folder with game files
```

## 2. Set Up Local Server

### Option A: Listen Server (Simplest)

Launch CS:GO with:
```
-console -insecure +map de_dust2
```

Then in console:
```
sv_cheats 1
mp_autoteambalance 0
mp_limitteams 0
bot_quota 8
```

### Option B: Dedicated Server (Recommended for Development)

```bash
# Install SteamCMD
brew install steamcmd

# Download CS:GO dedicated server
steamcmd +login anonymous +force_install_dir ~/csgo-server +app_update 740 validate +quit

# Start server
cd ~/csgo-server
./srcds_run -game csgo -console -usercon +game_type 0 +game_mode 0 +map de_dust2 -insecure
```

## 3. Install MetaMod:Source

MetaMod is required for SourceMod.

1. Download from: https://www.sourcemm.net/downloads.php?branch=stable
2. Select "Counter-Strike: Global Offensive" and your OS
3. Extract to your server's `csgo/` folder

Verify:
```
csgo/
└── addons/
    └── metamod/
        └── metaplugins.ini
```

Add to `csgo/addons/metamod.vdf`:
```vdf
"Plugin"
{
    "file"    "../csgo/addons/metamod/bin/server"
}
```

## 4. Install SourceMod

1. Download from: https://www.sourcemod.net/downloads.php?branch=stable
2. Select "Counter-Strike: Global Offensive" build
3. Extract to your server's `csgo/` folder (merges with existing addons/)

Verify:
```
csgo/
└── addons/
    ├── metamod/
    └── sourcemod/
        ├── plugins/
        ├── scripting/
        └── configs/
```

Test in-game:
```
sm version
# Should show SourceMod version
```

## 5. Install SourceMod Compiler

For writing plugins, you need the `spcomp` compiler.

```bash
# Already included in SourceMod download
# Located at: csgo/addons/sourcemod/scripting/spcomp

# Add to PATH (optional)
export PATH="$PATH:~/csgo-server/csgo/addons/sourcemod/scripting"

# Test
spcomp --version
```

## 6. Project Setup

Clone this repo into the server's scripting folder:

```bash
cd ~/csgo-server/csgo/addons/sourcemod/scripting
git clone https://github.com/YOUR_USERNAME/csgo-igl-mode.git

# Symlink source files
ln -s csgo-igl-mode/src/sourcemod/*.sp .

# Compile
spcomp igl_core.sp -o ../plugins/igl_core.smx
```

For behavior trees:
```bash
# Copy to game scripts folder
cp -r csgo-igl-mode/src/behavior_trees/* ~/csgo-server/csgo/scripts/ai/
```

For VScripts:
```bash
# Copy to vscripts folder
cp -r csgo-igl-mode/src/vscripts/* ~/csgo-server/csgo/scripts/vscripts/
```

## 7. Development Workflow

### Editing SourceMod Plugins

```bash
# Edit plugin
vim src/sourcemod/igl_core.sp

# Compile
spcomp igl_core.sp -o ../plugins/igl_core.smx

# Reload in-game (no server restart needed)
sm plugins reload igl_core
```

### Editing Behavior Trees

```bash
# Edit behavior tree
vim src/behavior_trees/igl_bot.kv3

# Reload in-game
mp_bot_ai_bt "scripts/ai/igl_bot.kv3"

# Restart round to apply
mp_restartgame 1
```

### Editing VScripts

```bash
# Edit script
vim src/vscripts/igl_state.nut

# Reload in-game
script_reload_code
# Or restart map
changelevel de_dust2
```

## 8. Useful Commands

### Bot Management
```
bot_add_t                    # Add T bot
bot_add_ct                   # Add CT bot
bot_kick                     # Kick all bots
bot_stop 1                   # Freeze bots (useful for testing)
bot_mimic 1                  # Bots mimic your inputs
bot_dont_shoot 1             # Bots won't shoot
```

### Navigation Mesh
```
nav_edit 1                   # Enter nav edit mode
nav_mark                     # Mark current nav area
nav_save                     # Save nav changes
nav_generate                 # Generate nav mesh (takes time)
```

### Behavior Tree Debugging
```
mp_bot_ai_bt "path/to/tree.kv3"   # Load custom BT
bot_debug 1                        # Show bot decision debug
bot_show_nav 1                     # Show navigation
```

### VScript Debugging
```
script_debug 1               # Enable script debugging
developer 1                  # Show developer messages
script <code>                # Execute inline script
```

## 9. Directory Reference

```
csgo-server/
└── csgo/
    ├── addons/
    │   ├── metamod/                    # MetaMod
    │   └── sourcemod/
    │       ├── plugins/                # Compiled .smx files
    │       ├── scripting/              # Source .sp files
    │       │   └── csgo-igl-mode/      # This repo
    │       └── configs/                # Plugin configs
    ├── scripts/
    │   ├── ai/                         # Behavior trees
    │   │   └── igl_bot.kv3
    │   └── vscripts/                   # VScripts
    │       └── igl_state.nut
    └── cfg/
        └── server.cfg                  # Server config
```

## 10. Troubleshooting

### "Unknown command: sm"
SourceMod not loaded. Check:
- MetaMod installed correctly
- `metamod.vdf` exists and has correct path
- Server running with `-insecure` flag

### Behavior tree not loading
- Check file path is correct (relative to csgo/)
- Verify `.kv3` syntax is valid
- Check console for parse errors

### VScript errors
- Run `script_debug 1` for detailed errors
- Check Squirrel syntax (it's not JavaScript!)
- Verify file is in `scripts/vscripts/`

### Bots not following orders
- Ensure bot has the custom BT loaded
- Check entity keyvalues are being set
- Use `bot_debug 1` to see decision-making

## Next Steps

Once your environment is set up:

1. Study `csgo/scripts/ai/bt_default.kv3` for BT syntax
2. Look at existing SourceMod plugins in `scripting/`
3. Read [ARCHITECTURE.md](ARCHITECTURE.md) for system design
4. Start with a minimal proof-of-concept (one bot, one order)
