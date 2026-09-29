# Templatformer

3D platformer in the vein of Zelda: Ocarina of Time (lock-on, item-gated dungeons) and Sonic (momentum, slopes, speed). Godot 4.5, GDScript, Compatibility renderer so it runs on the web.

## Commands

- `bash tools/setup_godot.sh` installs Godot to `~/.local/bin/godot` and imports the project. The SessionStart hook runs it.
- `bash tools/test.sh` runs the headless feel tests (`tests/run_tests.gd`). Run it before every push.
- `bash tools/export_web.sh` builds `build/web/`. The first run downloads the 1.3 GB template bundle and keeps only the web templates.
- CI (`.github/workflows/web.yml`) runs the tests and export on every PR and deploys `main` to GitHub Pages.

## How the code is laid out

- `scripts/player.gd` is the momentum controller. Speed follows the surface: slopes add or remove speed. It also holds the moves:
  - Mario jump chain: re-jump within `jump_combo_window` of landing while running for a double, then a triple (needs `triple_min_speed`).
  - Wall slide and wall jump: push into a wall in the air to slide, press jump to kick off.
  - Roll (i-frames for `roll_invuln`). Holding lock-on turns the roll into a side hop (stick left/right) or backflip (stick back).
  - Holding lock-on with nothing to target is a strafe: facing is fixed and speed is capped at `strafe_speed`.
  - `launch(v)` is how launch pads and other launchers throw you; `air_lock` stops floor snapping from eating the launch.
- `scripts/camera_rig.gd` is the orbit camera. It recenters behind your motion and frames the target while you're locked on.
- `scripts/tuning.gd` holds every feel number. New feel values go here and into `Tuning.EDITABLE` so they show up in the live panel.
- `scripts/level.gd` builds the test room in code. Tests start from positions it records in `marks`.
- Health is in half hearts (`Player.max_hp` 6 = 3 hearts). Anything that can be damaged is in group `hurtable` and has `hurt(amount, from_pos)`. That's the player, monsters, and whatever bombs and the spear hit.
- `scripts/inventory.gd` holds item definitions (`ITEMS`), counts and the three quick slots (keys 1-3, like Ocarina's C buttons). The spear is equipment: owning it enables the attack button. New items go in `ITEMS` and in the `match` in `use()`.
- `scripts/spear.gd` holds the attacks in `MOVES`: a jab, jab, sweep combo; a lunge (long slash) when running fast; an air slash; and a spin when you release a held attack. Each move hits each hurtable once, using a shape query during its active window.
- `scripts/bomb.gd`: using bombs pulls one out overhead with the fuse lit. Attack or the item button again throws it if you're moving, or sets it down if you're standing still.
- `scripts/lighting.gd` makes light a rule. `Lighting.is_lit(point)` is true if a shining node in group `light_sources` (the player wearing the candle hat, lit braziers, burning grass or vines) is within reach with a clear line on collision layer 1, or the sun (group `sun`) has a clear line. Bodies block light, so the player casts a shadow unless they're the source. `Lighting.spread_heat` warms nodes in group `flammable` (`Burnable` grass/vines, `Brazier`, `IceBlock`).
- `scripts/umbra.gd` is the mirrored ghost from the Umbra item. It reads `player.last_wish` and mirrors it across an axis snapped from the camera's right. Dark: floats at its height. Lit: falls and crawls at `umbra_crawl_speed`. Once light knocks it out of the air it falls until it lands. It's on collision layer 4, so it doesn't block the player or light, and only `MoonPlate` sees it.
- `scripts/shadow_hall.gd` builds the Ember & Umbra wing (candle room, dark chasm, lantern chasm). Its marks start with `hall_`. `Gate` opens from a brazier's `lit_up` or a moon plate's `pressed`.
- `scripts/monster.gd` is the basic blob. It's in groups `monsters`, `targets` (lock-on) and `hurtable`, and it recoils after touching you.
- `scripts/game_hud.gd` draws the hearts, the quick slots and the pause inventory (Enter). It runs while the game is paused.
- jovi dropped loops (2026-09-29). Don't bring them back without asking.

## Level feel rules (jovi, 2026-09-29)

- Gaps: 6 and 8 m feel nice. Under 6 m is pointless and tedious. 10 m is good because it needs speed and build-up. Anything bigger needs a runway long enough to build it up.
- Heights: under 2 m is pointless. 3 m is situational and slows play, so don't make it the norm.

## Working rules

- Nobody can feel the game from here. Every change to feel ships with a test in `tests/run_tests.gd` that states the number it guarantees (jump height, clearable gap, launch height), plus the web build for the owner to play.
- Tests drive the player with `ai`, `ai_move`, `ai_jump`, `ai_target`, `ai_attack`, `ai_attack_held`, `ai_roll` and `ai_item`, never with real input. While locked on, give `ai_move` relative to the player's facing, the way a real stick is read relative to the camera.
- Use `absf`, `maxf` and typed vars. Godot's parser rejects `:=` on Variant-typed expressions.
- Keep the web build working: no threads, no GDExtension.
