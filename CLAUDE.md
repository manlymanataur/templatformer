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
  - Roll (i-frames for `roll_invuln`) comes only from a quick stick tap while holding lock-on (out of neutral and back within `dodge_tap_time`); there is no roll button, and without lock-on a tap just steps (jovi: rolling on every tap made positioning tedious). Stick left/right gives a side hop, back a backflip.
  - Speed above top speed bleeds back at `overspeed_decay` on flat ground only; slopes act by physics, so running downhill builds speed. Use that in level design (runways can be downhills).
  - Size (`set_small`) changes only on `SizePad`s (shrink and grow pads); there is no shrink item. Small: radius x`small_scale`, slower, lower jumps, and grates, fences and bars (layers 2 and 3) don't stop you. Growing needs room (fails inside a grate). Small with the magnet, `_magnet_line` flies you along an iron's line instead of moving the iron.
  - Holding lock-on with nothing to target is a strafe: facing is fixed and speed is capped at `strafe_speed`.
  - `launch(v)` is how launch pads and other launchers throw you; `air_lock` stops floor snapping from eating the launch.
- `scripts/camera_rig.gd` is the orbit camera. It recenters behind your motion and frames the target while you're locked on.
- `scripts/tuning.gd` holds every feel number. New feel values go here and into `Tuning.EDITABLE` so they show up in the live panel.
- `scripts/level.gd` builds the test room in code. Tests start from positions it records in `marks`.
- Health is in half hearts (`Player.max_hp` 6 = 3 hearts). Anything that can be damaged is in group `hurtable` and has `hurt(amount, from_pos)`. That's the player, monsters, and whatever bombs and the spear hit.
- `scripts/inventory.gd` holds item definitions (`ITEMS`), counts and the three quick slots (keys 1-3, like Ocarina's C buttons). The spear is equipment: owning it enables the attack button. New items go in `ITEMS` and in the `match` in `use()`.
- `scripts/spear.gd` holds the attacks in `MOVES`: a jab, jab, sweep combo; a lunge (long slash) when running fast; an air slash; and a spin when you release a held attack. Each move hits each hurtable once, using a shape query during its active window.
- `scripts/bomb.gd`: bombs aren't an item (jovi). The context button next to a `BombFlower` (`scripts/bomb_flower.gd`, regrows in `bomb_regrow`) pulls one out overhead with the fuse lit; context again throws it if you're moving, or sets it down if you're standing still.
- The context button (`context` action: E, gamepad B; `Player.context()`, tests use `ai_context`) picks up, pulls, plants and puts down. It's the one button for carried things.
- `scripts/lighting.gd` makes light a rule. `Lighting.is_lit(point)` is true if a shining node in group `light_sources` (the player wearing the candle hat, lit braziers, burning grass or vines) is within reach with a clear line on collision layer 1, or the sun (group `sun`) has a clear line. Bodies block light, so the player casts a shadow unless they're the source. `Lighting.spread_heat` warms nodes in group `flammable` (`Burnable` grass/vines, `Brazier`, `IceBlock`).
- `scripts/umbra.gd` is the mirrored ghost from the Umbra item. It appears 1.5 m beside you on the mirror line, or short of a wall. It reads `player.last_wish` and mirrors it across an axis snapped from the camera's right. Dark: floats at its height. Lit: falls and crawls at `umbra_crawl_speed`. Once light knocks it out of the air it falls until it lands. It's on collision layer 4, so it doesn't block the player or light, and only `MoonPlate` sees it. It copies spear moves (`Spear.move_started`) with a greatsword while dark.
- `scripts/shadow_hall.gd` builds the Ember & Umbra wing (candle room, dark chasm, lantern chasm). Its marks start with `hall_`. `Gate` opens from a brazier's `lit_up` or a moon plate's `pressed`.
- `scripts/iron_cube.gd`, `battery.gd`, `power.gd` and `pad.gd` are Lodestone. Iron blocks are 2 m wide and 4.5 m tall (`IronCube.H`), on a 2 m grid. Each moves a cell at a time when the player's magnet (`magnet_push`: false pulls, true pushes) is in its row or column band, within `magnet_range`, with a clear ray. `Power` (one node in the level) floods power each frame from `power_source` through `conductor` iron to `power_sink` (a `Gate` after `wire()`, or a `Pad` made with `needs_power`). Touching means face to face (`Power.touching`), never corner to corner.
- `scripts/lodestone_yard.gd` builds the yard. `LodestoneYard.cell(i, j)` gives cell centres. Its marks start with `yard_`.
- `scripts/scale_garden.gd` builds the Scale garden (marks start with `garden_`). Its pieces: `SizePad`, `Grate` (collision layer 3: stops you at normal size only), `Water`, `Fan` (wind lanes that carry you only when small), `CrackedFloor`, `CrackedWall` (a normal-size roll or a bomb bursts it). The ground slab is cut around `ScaleGarden.GROUND_HOLES`; `ScaleGarden.basin` lines a hole.
- Collision layers: 1 world (blocks light), 2 bars and railings (stop you at normal size, not light or Umbra), 3 grates, 4 Umbra.
- Level pads are `Pad`s. `level.launch_pad` / `level.boost_pad` make always-on ones.
- `scripts/monster.gd` is the basic blob. It's in groups `monsters`, `targets` (lock-on) and `hurtable`, and it recoils after touching you.
- `scripts/dev_menu.gd` holds the playtest tools, which pause the game:
  - G opens the warp and debug menu (`WARPS` names level marks; give every item, god mode, heal, shrink).
  - P drops a feedback pin: jovi types a note and gets a link with `#pin=CODE`.
  - O loads a pasted pin. The web build loads `#pin=` from the address on start; desktop takes `-- --pin=CODE`.
  - `Pin` (`scripts/pin.gd`) captures and restores position, facing, camera, size, magnet, hearts, items and slots. A code is URL-safe base64 JSON, so decode it (`base64 -d` after swapping `-_` for `+/`) to read jovi's note and spot, and start a test there.
- `scripts/level_rules.gd` checks built areas (`LevelRules.AREAS`) against the level feel rules: ledges under 2 m, gaps under 6 m, 10-12 m gaps without a 12 m runway or a pad nearby, and 3 m ledges as the norm. The first tests run it on every area. Add each new wing's box to `AREAS`, and stop a roofed wing's box under its roof.
- Rootworks (`scripts/rootworks.gd`, marks start with `root_`) holds Winch and Propagule:
  - `Seed` (Propagule) is a 2 m cube (`Seed.SIZE`) on layer 5 (props), which the player, spider and cubes collide with. Carry one (hands full: no spear, no lash), set it down on soil, mud or roots (groups `soil`, `mud`, `roots`) to plant, or drop it `spear_drop` onto mud. Planted, the cube stays as a stump and grows a trunk from its top (groups `trunks`, `climbable`, `lash_posts`) and grid-axis roots until blocked. Context next to a planted one uproots it. There is no glide (jovi).
  - The Lash item (`Player.use_lash`) is Winch's leash plus Propagule's lash. It grapples to `lash_posts`, fetches loose seeds, stings hurtables, and hooks the spider on a taut rope.
  - The Clockwork Spider (`Spider`, player-sized, bars and grates stop it) is Winch's walker and the other main character (jovi). The spider item swaps who you steer (`Player.pilot`); piloted, inputs go to `Spider.wish`. Unhooked, it breaks past `spider_break` from you. It turns gears it walks past (`Gear._physics_process`).
  - `Tether` is the taut rope from you (a, the reel) to the spider (b). It bends only around layer 1 and props, finding corners by halving between last frame's end and this frame's; a bend lets go when the rope would turn the other way there. At `max_len` the steered end (`lead`) drags the other by sliding it. A gear with a bend on its rim turns by the rope slid over it. `Gear` drives a lift by `gear_ratio` and keeps its angle.
- `scripts/moves_yard.gd` (marks `moves_`) shows the acclaimed moves in `player.gd`:
  - Climbing: push into anything in group `climbable` (vines, trunks), no grip limit (jovi). `_climb_step` vaults at the top.
  - Ledge grab: falling against a wall with its top within `ledge_reach` hangs you (`hang`). Iron (`IronCube`) can't be grabbed, so it still needs a triple jump.
  - Grind rails (`scripts/rail.gd`, group `rails`, no collision): gravity along the rail, jump hops off.
  - Homing attack: air attack homes on the nearest `hurtable` or `pogo` node ahead, hits it once (it shares the spear's hit list) and bounces you straight up off its top. `Spikes` (group `pogo`) hurt on touch.
  - Ground pound (`_pound_step`, context in the air with empty hands): onto `hurtable`/`pogo` it hits and bounces (homing can chain after); flat landing opens `pound_land` for a high jump, or rolls out if you hold a direction; onto a slope it becomes downhill speed. Jumping out of a ground roll is a long jump. Rolls keep `roll_speed_now` and gain it downhill. A wall kick leaves `jump_chain` at 0, so the next landing jump is a double.
  - Perfect dodge: a hit during a roll calls `Hitfx.slow`; `Hitfx.world` slows monsters (they multiply their dt by it).
  - `scripts/hitfx.gd`: hitstop (`Engine.time_scale`), camera shake (group `camera_rig`), sparks.
- `scripts/challenge.gd` builds the challenge rooms (`Challenge.build`): doors in the moves yard, courses floating at y 200+ from x 300. Marks `challenge_<name>` hold each `Challenge` node (`start`, `goal`, `cleared`); walking into a door calls `enter()`, falling below `floor_y` restarts, the star calls `finish()`.
- `scripts/colossus.gd` is the test colossus (mark `colossus`, warp `colossus_arena`, arena x 56..104, z -118..-70). Its parts are `AnimatableBody3D`s under a pivot at the rear hips (don't use `sync_to_physics`: parts moved by a parent then don't collide). It walks at `colossus_speed` unless `ridden()`. `ColossusShin` is in group `blastable` (only `Bomb.explode` calls `blast`); the back plate is in group `poundable` (a pound landing calls its `on_pound` meta). `ColossusSigil` weak points turn `hurtable` and `targets` only once open. Losing both shins kneels it (pivot pitch) and opens the forehead sigil.
- `scripts/game_hud.gd` draws the hearts, the quick slots and the pause inventory (Enter). It runs while the game is paused.
- jovi dropped loops (2026-09-29). Don't bring them back without asking.

## Level feel rules (jovi, 2026-09-29)

- Gaps: 6 and 8 m feel nice. Under 6 m is pointless and tedious. 10 m is good because it needs speed and build-up. Anything bigger needs a runway long enough to build it up.
- Heights: under 2 m is pointless. 3 m is situational and slows play, so don't make it the norm.

## Working rules

- Don't spend long proving a level has only one solution (jovi, 2026-09-29). Check the intended route and the obvious skips. jovi and playtesters report cheese.
- Nobody can feel the game from here. Every change to feel ships with a test in `tests/run_tests.gd` that states the number it guarantees (jump height, clearable gap, launch height), plus the web build for the owner to play.
- Tests drive the player with `ai`, `ai_move`, `ai_jump`, `ai_target`, `ai_attack`, `ai_attack_held` and `ai_item`, never with real input. Rolls are a quick `ai_move` tap (the test helper `_tap`). While locked on, give `ai_move` relative to the player's facing, the way a real stick is read relative to the camera.
- Use `absf`, `maxf` and typed vars. Godot's parser rejects `:=` on Variant-typed expressions.
- Keep the web build working: no threads, no GDExtension.
