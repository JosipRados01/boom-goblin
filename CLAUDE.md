# BOOM GOBLIN

GMTK jam game, theme "Count down". Godot 4.7, GL Compatibility, Jolt. 3D third-person stealth:
a goblin with a lit bomb strapped to his back must be standing next to Count Dracula when the
fuse runs out. Enemies grab him → fail. Kenney Graveyard + Mini Dungeon kits.

Run the editor/game with: `/Users/josiprados/Downloads/Godot 2.app/Contents/MacOS/Godot`
(the user calls it "godot 2" — it is the newer of two copies on disk).

## Working style

- **The user keeps the editor open and edits scenes while you work.** Always re-read a `.tscn`
  immediately before editing it; their save will clobber disk edits otherwise.
- **Verify by running, not by reading.** Write a temporary `debug_shot.gd` + `debug_shot.tscn`
  at the project root, run `Godot res://debug_shot.tscn` (add `--headless` if you only need
  prints), simulate input with `Input.action_press/release`, save viewport PNGs to the scratchpad,
  read the images back, then delete the debug files.
- Tell the user to reload affected scenes in the editor after you write a `.tscn`.

## Structure

- `game_env.tscn` — main scene, the shell that never reloads: sky, DirectionalLight, `player.tscn`,
  `game_env.gd`. That script loads the current level, drops the goblin on its spawn, builds the
  HUD (fuse clock + "LEVEL n / m", red pulse under 10s) and the intro banner. Debug keys: **R**
  restart level, **N** skip level.
- `game.gd` — autoloaded as **`Game`**. `LEVELS` array, `finish_round(win)`, `retry`, `goto`,
  `skip`. Survives `reload_current_scene()`, which is how a level restarts. **Win advances, loss
  repeats the same level**; beating the last sets `run_complete` and wraps to level 1.
- `level_1/2/3.tscn` — self-contained, run `level.gd` (exports `title`, `fuse_time`, default 30s).
  Each holds a grid instance, a `PlayerSpawn` Marker3D, `target.tscn`, enemies, and its own
  `LevelCollision` node. Add a level = duplicate one, swap the grid, drag the markers, append the
  path to `LEVELS`.
- `player.gd` — movement, camera, anim crossfades, dash (a real hop: velocity.y pop, jump anim up
  / fall anim down), `spawn_at()`, `caught_by()`, `_on_exploded()` (blast radius check → win/lose).
- `tnt.gd` — fuse visibly slides into the stick; `exploded` signal, `defuse()`, `time_left()`.
- `target.gd` — group `"target"`; builds a billboarded speech-bubble in code, jokes are an
  `@export` array, cycled by a **Timer** (not `await`) so being blown up mid-joke can't resume a
  coroutine on a freed node.
- `enemy_ghost.gd` — intangible, group `"no_autocol"`, hovers a lane, `patrol_axis` dropdown (X/Z).
- `enemy_skeleton.gd` — patrols spawn↔spawn+`patrol_offset`, cone + LOS raycast; its Eye
  SpotLight **is** the vision cone (yellow patrol / red chase).
- `add_level_collision.gd` — runtime trimesh collision for plain GLB meshes. GridMaps don't need
  it (collision is baked into each level's embedded MeshLibrary).
- Unused leftovers: `first_dungeon.tscn`, `level_test.tscn`, `main.tscn`, `night_env.tres`,
  `tools/build_level.gd`.

## Conventions and gotchas

- **Models face +Z.** The camera rig hangs off the pivot's +Z, so `spawn_at()` sets the camera yaw
  to facing + PI. A `PlayerSpawn` marker's +Z is the direction the goblin faces.
- Kenney floor tiles pivot at their **walk surface**; props and walls pivot at their **base** —
  paint both at the same cell level. Tiles are scaled 2x. Stairs are unclimbable for the capsule
  at that scale; use 1m pits a dash can escape.
- `class_name` is not in the CLI's class cache (only the editor builds it) — headless runs fail on
  it. Duck-type instead.
- `Game.goto()` reloads the *current* scene. Correct in game (always `game_env`), but a debug
  harness that calls it from its own `_ready` will reload-loop — guard with a meta flag.
- The ghost's `pingpong` lane is not centered on its spawn point (span 10 → −3..+5).
- Levels: 1 = 38×58, pits, target on a raised platform up stairs. 2 = 30×54 open yard, crypt at the
  far end. 3 = 50×74, wall gap at x 24–33 is the chokepoint, target behind a T-wall. All 30s fuse;
  level 3 is ~18s of pure running, so it may need more time.
- **`LEVELS[0]` is currently pointed at `level_3.tscn` for testing** — restore it to `level_1.tscn`
  before shipping.
