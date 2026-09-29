# Templatformer

3D platformer in the vein of Zelda: Ocarina of Time (lock-on, item-gated dungeons) and Sonic (momentum, slopes, loops). Godot 4.5, GDScript, Compatibility renderer so it runs on the web.

## Commands

- `bash tools/setup_godot.sh` installs Godot to `~/.local/bin/godot` and imports the project. The SessionStart hook runs it.
- `bash tools/test.sh` runs the headless feel tests (`tests/run_tests.gd`). Run it before every push.
- `bash tools/export_web.sh` builds `build/web/`. The first run downloads the 1.3 GB template bundle and keeps only the web templates.
- CI (`.github/workflows/web.yml`) runs the tests and export on every PR and deploys `main` to GitHub Pages.

## How the code is laid out

- `scripts/player.gd` is the momentum controller. Speed follows the surface: slopes add or remove speed, and above `stick_speed` you stay on walls and ceilings.
- `scripts/camera_rig.gd` is the orbit camera. It recenters behind your motion and frames the target while you're locked on.
- `scripts/tuning.gd` holds every feel number. New feel values go here and into `Tuning.EDITABLE` so they show up in the live panel.
- `scripts/level.gd` builds the test room in code. Tests start from positions it records in `marks`.
- Loops use Sonic's layer trick. The way up is on collision layer 2 and the way down on layer 3. Zones switch the player's mask at the top and reset it at either end.

## Working rules

- Nobody can feel the game from here. Every change to feel ships with a test in `tests/run_tests.gd` that states the number it guarantees (jump height, clearable gap, loop speed), plus the web build for the owner to play.
- Tests drive the player with `ai`, `ai_move`, `ai_jump` and `ai_target`, never with real input.
- Use `absf`, `maxf` and typed vars. Godot's parser rejects `:=` on Variant-typed expressions.
- Keep the web build working: no threads, no GDExtension.
