# Fractured Reality - Godot Multiplayer Game

## Project Overview
Asymmetric 5-player multiplayer game (4 Repairers vs 1 Corruptor) with time manipulation mechanics and 5-8 minute sessions. Players navigate glitched 2D/2.5D environments with temporal ghost trails.

## Tech Stack
- **Engine**: Godot 4.3+
- **Language**: GDScript
- **Networking**: Godot High-Level Multiplayer API (ENetMultiplayerPeer)
- **Version Control**: Git

## Project Structure
- `scenes/` - Game scenes (main menu, game levels, UI)
  - `scenes/levels/` - Playable level scenes
  - `scenes/ui/` - HUD, menus, overlays
  - `scenes/characters/` - Player and ghost prefabs
- `scripts/` - GDScript files organized by system
  - `scripts/player/` - Player movement, abilities, input
  - `scripts/networking/` - Multiplayer synchronization
  - `scripts/game_logic/` - Time loops, scoring, win conditions
  - `scripts/managers/` - Game state, scene management
- `assets/` - Sprites, audio, shaders
  - `assets/shaders/` - Glitch effects, ghost transparency
  - `assets/audio/` - SFX and music
  - `assets/sprites/` - Character and environment sprites
- `autoload/` - Singleton scripts (NetworkManager, GameManager, etc.)

## Core Game Systems

### Multiplayer Architecture
- Use `MultiplayerAPI` with ENet for peer-to-peer connections
- Host-based architecture (one player = server + client)
- Max 5 players (4 Repairers + 1 Corruptor)
- RPCs for ability activation, ghost trail sync, fragment collection
- Authority pattern: server validates all critical actions

### Time Loop & Ghost System
- Record player positions every 0.1s during gameplay
- On death, create ghost node with recorded path for 10s playback
- Ghost nodes use shader with transparency and trail particles
- Ghosts sync via RPC to all clients

### Player Abilities
**Repairers** (collaborative):
- Short teleport (dash)
- Wall vision (temporary)
- Time speed boost (self)

**Corruptor** (solo power):
- Local time slowdown zone
- Gravity inversion area
- Obstacle duplication

### Progression System
- Track stats locally (encrypted save file)
- Unlock new maps every 10 games played
- Cosmetic rewards (skins, particle effects) via point system
- Weekly modifier events (speed x2, invisibility mode)

## Code Style & Conventions

### Task Management with TodoWrite Tool

**CRITICAL: ALWAYS use the TodoWrite tool to track tasks and progress.**

Claude Code provides a TodoWrite tool that you MUST use for any non-trivial work:

**When to Use:**
- ✅ **Multi-step tasks** - Any task requiring 3+ distinct steps
- ✅ **Complex features** - New systems, UI components, networking code
- ✅ **User requests with multiple parts** - Lists, numbered items, comma-separated tasks
- ✅ **Bug fixes with investigation** - When you need to search, analyze, then fix
- ✅ **At the START of work** - Create todos immediately when beginning
- ✅ **Throughout work** - Update status (pending → in_progress → completed) as you go

**When NOT to Use:**
- ❌ Single trivial tasks (e.g., "fix this typo")
- ❌ Simple questions with no action required
- ❌ Tasks completable in 1-2 trivial steps

**Best Practices:**
1. **Create todos FIRST** - Before starting work, write out all tasks
2. **Use descriptive names** - "Fix player synchronization" not "Fix bug"
3. **Mark in_progress BEFORE working** - Only ONE task in_progress at a time
4. **Complete immediately** - Mark completed as soon as task is done, don't batch
5. **Update regularly** - Keep the list current throughout the session
6. **Clean up** - Remove or complete stale todos

**Example Workflow:**
```
User: "Add a pause menu with options and quit buttons"

Claude: [Creates todos]
1. [pending] Create pause menu scene
2. [pending] Add resume button functionality
3. [pending] Add options button functionality
4. [pending] Add quit button functionality
5. [pending] Test pause menu in-game

Claude: [Starts work]
TodoWrite: Mark task 1 as in_progress
[Works on pause menu scene]
TodoWrite: Mark task 1 as completed, task 2 as in_progress
[Implements resume button]
TodoWrite: Mark task 2 as completed, task 3 as in_progress
...
```

**Remember:** The TodoWrite tool is your task tracker. Use it religiously to stay organized and show progress!

---

### GDScript Standards
- Use `snake_case` for variables, functions, and file names
- Use `PascalCase` for class names and scene node types
- Prefix private functions with underscore: `_internal_function()`
- Group exports at top of script: `@export var speed: float = 200.0`
- Add type hints everywhere: `func move_player(direction: Vector2) -> void:`
- Use signals for decoupled communication: `signal player_died(player_id: int)`

### Node Structure
- Prefer scene composition over deep inheritance
- Use `@onready var` for node references: `@onready var sprite = $Sprite2D`
- Keep scene trees shallow (max 4-5 levels deep)
- Name nodes descriptively: `PlayerSprite`, `AbilityCooldownTimer`

### Networking Best Practices
- ALWAYS validate input on authority side (prevent cheating)
- Use `@rpc("any_peer", "call_remote")` for client→server actions
- Use `@rpc("authority", "call_remote")` for server→client updates
- Minimize RPC calls - batch data when possible
- Never trust client-reported positions for critical gameplay

### Performance
- Use object pooling for ghost nodes and particles
- Limit active ghosts to 3 per player maximum
- Use `VisibleOnScreenNotifier2D` for culling inactive elements
- Profile with Godot profiler before optimizing

## Common Commands

### Run & Test
- `godot --path . scenes/main_menu.tscn` - Launch game from CLI
- `godot --path . --debug` - Run with debug console
- `godot --path . --remote-debug tcp://127.0.0.1:6007` - Remote debugging

### Version Control
- Branch naming: `feature/ability-system`, `fix/ghost-sync-bug`
- Commit format: `[Type] Brief description`
  - Types: `[Feature]`, `[Fix]`, `[Refactor]`, `[Art]`, `[Sound]`
- Always test multiplayer before pushing (minimum 2 clients)

### MCP Godot Tools
Claude has access to MCP (Model Context Protocol) tools for Godot automation. Use these when appropriate:

**Project Management**
- `mcp__godot__launch_editor` - Launch Godot editor for the project
  - Use when: Need to open project in Godot GUI for manual testing/editing
- `mcp__godot__get_project_info` - Get project metadata (version, features, settings)
  - Use when: Need to check project configuration or Godot version compatibility
- `mcp__godot__list_projects` - List Godot projects in a directory
  - Use when: Searching for project files or validating project structure
- `mcp__godot__get_godot_version` - Get installed Godot version
  - Use when: Verifying Godot installation or compatibility checks

**Running & Debugging**
- `mcp__godot__run_project` - Run the project and capture output
  - Use when: Testing game functionality, validating changes, or reproducing bugs
  - Can specify specific scene to run with `scene` parameter
- `mcp__godot__get_debug_output` - Get current debug output and errors
  - Use when: Checking for runtime errors or console output during execution
- `mcp__godot__stop_project` - Stop currently running project
  - Use when: Terminating test runs or freeing resources

**Scene Manipulation**
- `mcp__godot__create_scene` - Create new scene file with root node
  - Use when: Setting up new levels, UI screens, or character prefabs
  - Specify `rootNodeType` (Node2D, Node3D, Control, etc.)
- `mcp__godot__add_node` - Add node to existing scene
  - Use when: Building scene hierarchy programmatically
  - Can set properties and parent node path
- `mcp__godot__load_sprite` - Load sprite into Sprite2D node
  - Use when: Setting up character sprites or environment art
- `mcp__godot__save_scene` - Save scene changes
  - Use when: Persisting scene modifications made via MCP tools

**Advanced Operations**
- `mcp__godot__export_mesh_library` - Export scene as MeshLibrary resource
  - Use when: Creating tile/mesh libraries for GridMap systems
- `mcp__godot__get_uid` - Get UID for a file (Godot 4.4+)
  - Use when: Debugging resource references or UID issues
- `mcp__godot__update_project_uids` - Update UID references (Godot 4.4+)
  - Use when: Fixing broken UIDs after file moves/renames

**Best Practices**
- Prefer MCP tools for batch scene creation and testing automation
- Always use `run_project` + `get_debug_output` to validate changes
- Use manual CLI commands (`godot --path .`) for interactive debugging
- MCP tools are headless - use `launch_editor` when GUI needed

### UI/UX Development Agent - MANDATORY WORKFLOW ⚠️

**CRITICAL: All UI/UX work MUST be developed by the `uiux-reviewer` agent.**

Claude has access to a specialized `uiux-reviewer` agent that **directly designs, implements, and validates** all UI/UX work according to UIUX.md standards. This agent has full development authority for anything visual or interactive.

**MANDATORY Usage - The Agent MUST Develop:**
- ✅ **ALL UI scenes** - Menus, HUD, dialogs, overlays, pause screens
- ✅ **ALL UI components** - Buttons, panels, labels, inputs, sliders, tabs
- ✅ **ALL visual feedback** - Ability indicators, progress bars, notifications, status displays
- ✅ **ALL UI scripts** - Menu logic, interaction handlers, animation controllers
- ✅ **ALL theme resources** - StyleBox, fonts, colors, icons
- ✅ **ALL shaders for UI** - Glitch effects, transitions, visual distortions
- ✅ **ALL accessibility features** - Keyboard navigation, focus indicators, color-blind modes
- ✅ **ANY UI fixes or refinements** - Layout adjustments, color corrections, contrast fixes

**How It Works:**
The agent doesn't just review - it **actively develops** UI/UX features:
1. **Designs** the UI according to UIUX.md standards
2. **Implements** scenes, scripts, and resources directly
3. **Validates** against accessibility and consistency guidelines
4. **Self-reviews** and iterates until perfect
5. **Delivers** production-ready, WCAG AA compliant UI

**What The Agent Ensures:**
- ✅ Color palette compliance (Void Black #000000, Electric Purple #7F00FF, Neon Cyan #00FFFF, Glitch Red #FF4136)
- ✅ Typography hierarchy (48pt/28pt/16pt with Orbitron fonts)
- ✅ WCAG AA accessibility (4.5:1 contrast ratios minimum)
- ✅ Keyboard navigation with visible focus states
- ✅ Glitch aesthetic integration (shaders, animations, distortions)
- ✅ Component consistency across all scenes
- ✅ Responsive design and proper layouts
- ✅ Network status displays for multiplayer
- ✅ Diegetic UI integration (feels part of game world)

**Workflow Pattern:**
Whenever UI/UX work is needed, immediately delegate to the agent:

```
user: "Create a settings menu with graphics and audio options"
assistant: [Launches uiux-reviewer agent to develop the feature]

user: "The button colors don't match the theme"
assistant: [Launches uiux-reviewer agent to fix and ensure UIUX.md compliance]

user: "Add a friend request notification system"
assistant: [Launches uiux-reviewer agent to design and implement the UI]
```

**DO NOT:**
- ❌ Implement UI/UX without the agent
- ❌ Make visual changes without UIUX.md validation
- ❌ Create scenes/components that bypass agent review
- ❌ Use colors, fonts, or layouts not approved by UIUX.md

**ALWAYS:**
- ✅ Let the uiux-reviewer agent develop ALL UI/UX features
- ✅ Trust the agent's implementation decisions
- ✅ Use the agent for even small UI tweaks
- ✅ Allow the agent to maintain visual consistency

**Reference Documents:**
- `/home/ubuntu/Fractured-Reality/UIUX.md` - Complete UI/UX design standards (the agent's bible)
- `/home/ubuntu/Fractured-Reality/assets/ui/fractured_reality_theme.tres` - Global theme resource
- `/home/ubuntu/Fractured-Reality/assets/shaders/` - UI shader library

## Development Workflow

### When Adding New Features
1. Create test scene in `scenes/tests/` to isolate feature
2. Implement and test locally first
3. Add multiplayer sync if needed (test with 2+ instances)
4. Integrate into main game scenes
5. Update relevant manager scripts (GameManager, NetworkManager)
6. Test full game loop with feature enabled

### Testing Multiplayer
- Launch 2+ Godot instances: `godot --path . & godot --path .`
- Use `--position x,y` flag to position windows side-by-side
- Test with host + client minimum (ideally 5 players)
- Check authority validation (try "cheating" as client)

### Adding New Abilities
1. Define ability data in `scripts/abilities/ability_data.gd`
2. Implement client-side visual/logic in player script
3. Add server-side validation in NetworkManager
4. Create RPC for ability activation + cooldown sync
5. Add UI indicator (cooldown timer, ability icon)
6. Test with lag simulation (`--debug-collisions`)

## Important Files & Utilities
- `autoload/network_manager.gd` - Handles all multiplayer sync (READ THIS FIRST)
- `autoload/game_manager.gd` - Game state, round timers, win conditions
- `scripts/player/player_controller.gd` - Main player input + movement
- `scripts/game_logic/ghost_recorder.gd` - Records/plays ghost trails
- `scripts/game_logic/fragment_spawner.gd` - Spawns collectible fragments
- `assets/shaders/glitch_effect.gdshader` - Main visual style shader

## Critical Rules ⚠️

### DO NOT
- ❌ Modify `network_manager.gd` without understanding authority pattern
- ❌ Add RPCs that send data every frame (performance killer)
- ❌ Trust client input for gameplay-critical values (positions, scores)
- ❌ Create deep node hierarchies (keeps scenes manageable)
- ❌ Use `get_node()` in `_ready()` - use `@onready` instead

### ALWAYS
- ✅ Test with multiple game instances before committing networking changes
- ✅ Add authority checks: `if multiplayer.is_server()` before modifying game state
- ✅ Use signals instead of direct function calls between systems
- ✅ Profile performance when adding particle effects or shaders
- ✅ Validate ability usage server-side (cooldowns, range, line-of-sight)
- ✅ Clean up nodes properly: `queue_free()` instead of manual deletion

## Debugging Tips
- Use `print_debug()` with `multiplayer.get_unique_id()` to trace RPC flow
- Enable "Visible Collision Shapes" in Debug menu for hitbox issues
- Check "Synchronize Scene" in MultiplayerSynchronizer for auto-sync issues
- Use breakpoints in VS Code with Godot LSP extension
- Monitor "Network Profiler" tab for bandwidth usage

## Special Godot Behaviors
- Autoload singletons initialize BEFORE scene tree is ready
- `_physics_process()` runs at fixed 60 FPS (use for movement)
- `_process()` runs every frame (use for visuals/UI only)
- Signals in multiplayer sync automatically if nodes exist on all peers
- `queue_free()` defers deletion to end of frame (safe for iteration)

## Environment Setup
- Godot 4.3 or later required (uses new MultiplayerAPI features)
- Git LFS recommended for large assets (sprites, audio)
- Optional: Godot LSP + VS Code for better autocomplete
- Recommended: Dual monitor setup for testing multiplayer side-by-side

## Review Checklist
Before committing, verify:
- [ ] Multiplayer tested with 2+ clients
- [ ] No console errors or warnings
- [ ] Authority validation for new gameplay code
- [ ] Ghost trails render correctly with new changes
- [ ] Performance stable (60 FPS with 5 players + ghosts)
- [ ] Code follows snake_case convention
- [ ] All functions have type hints
- [ ] Signals used instead of tight coupling

## End-of-Session Workflow

### ALWAYS Push Changes at End of Work Session

After completing a work session, **ALWAYS** push your changes to the remote repository:

1. **Stage all changes:**
   ```bash
   git add .
   ```

2. **Create commit with descriptive message:**
   ```bash
   git commit -m "[Type] Brief description

   🤖 Generated with Claude Code

   Co-Authored-By: Claude <noreply@anthropic.com>"
   ```

3. **Push to remote:**
   ```bash
   git push
   ```

### Pre-Push Checklist
- [ ] All new files are tracked by git
- [ ] No sensitive data (passwords, API keys) in commit
- [ ] Commit message follows `[Type] Description` format
- [ ] Changes have been tested (at minimum, game runs without errors)
- [ ] No work-in-progress code that breaks the build

### Commit Message Types
- `[Feature]` - New functionality added
- `[Fix]` - Bug fixes
- `[Refactor]` - Code restructuring without behavior change
- `[Multiplayer]` - Networking/multiplayer changes
- `[UI]` - User interface updates
- `[Art]` - Visual assets, shaders, effects
- `[Sound]` - Audio implementation
- `[Docs]` - Documentation updates

**Example:**
```bash
git add .
git commit -m "[Multiplayer] Implement internet multiplayer with lobby system

- Added NetworkManager autoload for ENet peer-to-peer
- Created lobby scene with player list UI
- Implemented player synchronization and spawning
- Added role assignment (Corruptor vs Repairers)

🤖 Generated with Claude Code

Co-Authored-By: Claude <noreply@anthropic.com>"
git push
```

**IMPORTANT:** Never end a work session without pushing. This ensures:
- Work is backed up remotely
- Team members have latest changes
- Progress is tracked in version history
- Recovery is possible if local files are lost

