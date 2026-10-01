class_name Tuning
extends Resource
## Every feel number in one place. The debug HUD edits these live and saves them to user://tuning.tres.

@export var top_speed := 12.0 ## running speed you reach by holding a direction
@export var boost_speed := 32.0 ## hard cap; slopes and boost pads can take you past top_speed up to this
@export var overspeed_decay := 6.0 ## on flat ground, speed above top_speed bleeds off this fast (m/s per s); downhill you still build speed
@export var accel := 22.0
@export var friction := 18.0 ## slow-down with no input
@export var brake := 45.0 ## slow-down when pushing against your motion
@export var turn_rate := 12.0 ## how fast you turn at low speed
@export var turn_rate_fast := 3.0 ## how fast you turn at boost speed
@export var air_accel := 14.0
@export var gravity := 30.0
@export var jump_speed := 12.0 ## apex = jump_speed^2 / (2 * gravity)
@export var jump_cut := 5.0 ## upward speed kept when you let go of jump early
@export var coyote_time := 0.1
@export var jump_buffer := 0.12
@export var slope_factor := 1.0 ## 1 = slopes speed you up and slow you down like real gravity
@export var jump_combo_window := 0.15 ## land and jump again within this to chain a double/triple jump
@export var double_jump_mult := 1.25 ## height x1.56
@export var triple_jump_mult := 1.5 ## height x2.25
@export var triple_min_speed := 8.0
@export var wall_slide_speed := 4.0
@export var wall_jump_speed := 8.0 ## away from the wall
@export var wall_jump_up := 12.0
@export var roll_speed := 13.0
@export var roll_time := 0.4
@export var roll_invuln := 0.3 ## dodge window at the start of a roll
@export var strafe_speed := 7.0 ## top speed while holding target
@export var hammer_hold := 0.25 ## hold attack this long and let go: the hammer
@export var spin_charge_time := 0.8 ## hold attack even longer and let go: the spin (ground or air)
@export var charge_speed := 5.0 ## top speed while a swing is held back
@export var run_attack_speed := 9.0 ## attack running faster than this: the running blade
@export var fast_blade_speed := 13.0 ## the running blade (and a surf bump) does +1 above this; only downhills get you there
@export var perfect_guard := 0.2 ## a hit this soon after the shield goes up is a perfect guard
@export var parry_time := 2.0 ## after a perfect guard, your next sweet-spot hit within this is +2 and staggers
@export var guard_speed := 3.5 ## walking with the shield up
@export var guard_push := 5.0 ## a blocked hit pushes you back this fast
@export var guard_push_heavy := 11.0 ## a blocked heavy hit (a rusher, a brute) pushes you back this fast
@export var guard_wall := 1.2 ## a heavy hit with a wall this close behind you breaks your guard
@export var guard_break := 0.9 ## how long a broken guard leaves you reeling
@export var brace_time := 0.35 ## guard standing still this long to brace
@export var impale_speed := 12.0 ## braced, something charging onto your point faster than this is impaled
@export var impale_damage := 4.0
@export var impale_stun := 1.6
@export var stuck_time := 0.8 ## after an impale the poleaxe is stuck this long
@export var surf_friction := 0.8 ## shield surf: slow-down on the flat (m/s per s)
@export var surf_turn := 1.8 ## shield surf: steering (radians per second)
@export var surf_min := 1.5 ## shield surf ends below this speed on the flat
@export var focus_near := 6.0 ## locked on this far from a monster (or further) builds focus (just outside the doubled poleaxe's reach)
@export var focus_far := 11.0 ## ...up to this far
@export var focus_rate := 0.45 ## focus per second (full at 1)
@export var bomb_throw_speed := 5.0 ## forward speed of a thrown bomb (jovi: shorter throws than the old 7)
@export var bomb_throw_up := 4.5
@export var dodge_tap_time := 0.2 ## a stick tap shorter than this rolls (or dodges, locked on)
@export var candle_range := 12.0 ## how far the candle hat lights
@export var candle_touch := 0.9 ## how close (from your centre) the candle sets things alight
@export var umbra_speed := 10.0 ## Umbra floating in the dark
@export var umbra_crawl_speed := 1.5 ## Umbra crawling in light
@export var magnet_range := 14.0 ## how far your magnet reaches along a line
@export var small_scale := 0.35 ## shrunk size, as a fraction of normal
@export var small_speed_mult := 0.6 ## small, run and roll speed times this
@export var small_jump_mult := 0.65 ## small, jump speed times this (height x0.42)
@export var small_swim_speed := 3.5 ## small, paddling speed on water
@export var magnet_fly_speed := 10.0 ## small, how fast the magnet carries you along an iron's line
@export var magnet_fly_range := 22.0 ## small, how far along its line an iron's field reaches you
@export var iron_speed := 6.0 ## how fast iron slides from cell to cell
@export var lash_range := 16.0 ## how far the lash reaches
@export var lash_pull_speed := 22.0 ## how fast the lash pulls you to a post or trunk
@export var leash_length := 16.0 ## lash hooked on the spider: the taut rope's length; at full length the one you steer drags the other
@export var spider_speed := 7.0
@export var gear_ratio := 0.5 ## metres a gear's lift moves per metre of rope sliding past it
@export var crank_ratio := 0.5 ## a crank geared to a rack (the Works ferry and clutch): metres the rack slides per metre of crank rim
@export var screw_notch := 1.0 ## metres a step screw (the Works) rises per notch (a quarter turn)
@export var trunk_height := 10.0 ## a planted seed's trunk grows up to this, or to the ceiling
@export var root_length := 18.0 ## roots grow sideways until blocked, up to this
@export var spear_drop := 3.0 ## a seed falling at least this far onto mud spears in and plants itself
@export var pound_speed := 30.0 ## ground pound: how fast you drop
@export var pound_hover := 0.12 ## ground pound: the pause at the top before you drop
@export var pound_jump_window := 0.25 ## jump within this of a pound landing for a high jump
@export var pound_jump_mult := 1.5 ## the high jump's speed, times jump_speed (1.5 = triple-jump height)
@export var pound_slide := 0.8 ## a pound onto a slope turns this much of the fall into downhill speed
@export var long_jump_speed := 20.0 ## jump out of a roll: forward speed
@export var long_jump_up := 9.0 ## jump out of a roll: upward speed
@export var long_jump_keep := 0.4 ## landing a long jump, you keep this share of your speed above top_speed
@export var ledge_long_mult := 1.15 ## ledge grab, pound onto the ledge, roll out, long jump: speed and height times this
@export var boost_hold := 1.5 ## seconds after a boost pad before overspeed starts to bleed off
@export var bomb_regrow := 4.0 ## seconds for a bomb plant to grow a new bomb
@export var colossus_speed := 1.8 ## how fast the test colossus walks its circle
@export var spider_break := 30.0 ## an unhooked spider further than this from you breaks and goes back in your pack
@export var ledge_reach := 1.2 ## a ledge top this far above your middle, as you fall against it, is caught
@export var climb_speed := 5.0 ## up a trunk
@export var hitstop := 0.06 ## real seconds the game freezes on a solid hit
@export var shake_hit := 0.15 ## camera shake on a hit (metres)
@export var dodge_slow_time := 1.5 ## a perfect dodge (hit during a roll's i-frames) slows the world this long
@export var dodge_slow_speed := 0.3 ## how fast monsters move during that slow-motion
@export var homing_range := 14.0 ## air attack homes in on something hittable this close in front of you
@export var homing_speed := 26.0
@export var pogo_speed := 13.0 ## bounce up off whatever the homing attack hits
@export var rail_min_speed := 10.0 ## you grind at least this fast
@export var boost_pad_speed := 30.0
@export var pot_throw_speed := 7.0 ## a pot: throw speed standing still (a full pot is lobbed about 5 m)
@export var pot_throw_run := 1.6 ## a pot thrown on the run gets this much of your speed on top
@export var pot_throw_up := 8.0 ## a thrown pot's upward speed
@export var pot_respawn := 2.0 ## seconds for a pot shelf to put out a new pot after one smashes
@export var honey_slow := 4.0 ## normal size in honey you move at most this fast (small things are stuck)
@export var honey_jump := 0.5 ## in honey your jump speed is times this (small: no jump)
@export var honey_cover := 0.5 ## seconds standing in honey before it coats a thing
@export var candy_heat_time := 0.3 ## seconds of heat that harden a honey coat into rock candy
@export var heat_reach := 3.0 ## a lit brazier warms honey and lights wine this far from it
@export var candle_heat := 3.0 ## the lit candle hat hardens honey this far from you
@export var swap_range := 24.0 ## the swap charm reaches rock candy this far away
@export var drunk_time := 6.0 ## wine: seconds your steering sways
@export var drunk_sway := 0.9 ## wine: how far (radians) your steering swings
@export var drunk_monster_time := 8.0 ## wine: seconds a monster wanders
@export var wet_time := 45.0 ## water leaves things wet this long: wet ground won't take wine or fire
@export var wine_burn := 2.5 ## a wine puddle burns this long, then it's gone
@export var lure_range := 13.0 ## honey draws blobs and wolves, wine draws brutes and rushers, from this far
@export var crate_push_speed := 2.5 ## how fast you push a crate
@export var crate_burn := 4.0 ## a burning crate burns away after this long
@export var cam_distance := 7.0
@export var cam_lag := 10.0
@export var cam_recenter_delay := 0.8
# powers combat (Power Combat Sketchbook II, jovi 2026-10-01)
@export var seed_throw_speed := 7.0 ## a thrown seed cube keeps the old bomb throw (bombs got shorter)
@export var seed_throw_up := 5.0
@export var bomb_throw_keep := 0.15 ## a thrown bomb keeps this share of your running speed (was 0.3)
@export var bomb_friction := 45.0 ## a bomb on the ground slows by this (m/s per s): it stops near where it lands
@export var bomb_bat_speed := 14.0 ## an attack that reaches a bomb on the ground bats it away this fast
@export var bomb_bat_up := 6.0 ## ...and this fast up, so a bat carries past the doubled poleaxe's reach (about 6 m before it lands)
@export var bomb_jump_speed := 20.0 ## pound onto a bomb: it goes off under you and throws you up this fast, unhurt
@export var pincer_window := 0.5 ## you and Umbra hitting the same monster within this many seconds is a pincer
@export var pincer_bonus := 2.0 ## extra damage for a pincer
@export var knight_magnet_range := 10.0 ## an iron knight this close in front of you feels your magnet
@export var knight_pull_speed := 9.0 ## pull: the knight slides to you this fast, stunned, shield down
@export var knight_open_time := 1.2 ## after a pull its shield stays down this long
@export var knight_push_knock := 14.0 ## push: the knight is blown away this fast (it splats on walls and bowls others)
@export var knight_magnet_cd := 1.0 ## after the magnet moved a knight, it ignores it this long
@export var iron_plough_knock := 12.0 ## a sliding iron block knocks the monster in its way this fast
@export var fire_spread_delay := 0.45 ## a burning grass patch starts to spread this long after it caught
@export var fire_damage_every := 0.5 ## monsters standing in fire take 1 this often (you never do)
@export var step_height := 0.5 ## running into a ledge up to this tall (x small_scale when small) walks you up onto it (StepUp)
@export var launch_up := 12.0 ## a launcher (the sweep, or thrust2, the combo's second hit) throws a monster up this fast: about 3.6 m

const EDITABLE: Array[String] = ["top_speed", "boost_speed", "overspeed_decay", "accel", "friction", "brake", "turn_rate", "turn_rate_fast",
	"air_accel", "gravity", "jump_speed", "jump_cut", "coyote_time", "jump_buffer", "slope_factor",
	"jump_combo_window", "double_jump_mult", "triple_jump_mult", "triple_min_speed", "wall_slide_speed", "wall_jump_speed",
	"wall_jump_up", "roll_speed", "roll_time", "roll_invuln", "strafe_speed", "hammer_hold", "spin_charge_time", "charge_speed", "run_attack_speed", "fast_blade_speed", "perfect_guard", "parry_time", "guard_speed", "guard_push", "guard_push_heavy", "guard_wall", "guard_break", "brace_time", "impale_speed", "impale_damage", "impale_stun", "stuck_time", "surf_friction", "surf_turn", "surf_min", "focus_near", "focus_far", "focus_rate", "bomb_throw_speed",
	"bomb_throw_up", "dodge_tap_time", "candle_range", "candle_touch", "umbra_speed", "umbra_crawl_speed", "magnet_range", "iron_speed", "small_scale", "small_speed_mult", "small_jump_mult", "small_swim_speed", "magnet_fly_speed", "magnet_fly_range", "lash_range", "lash_pull_speed", "leash_length", "spider_speed", "gear_ratio", "crank_ratio", "screw_notch", "trunk_height", "root_length", "spear_drop", "climb_speed", "ledge_reach", "bomb_regrow", "spider_break", "colossus_speed", "pound_speed", "pound_hover", "pound_jump_window", "pound_jump_mult", "pound_slide", "long_jump_speed", "long_jump_up", "long_jump_keep", "ledge_long_mult", "hitstop", "shake_hit", "dodge_slow_time", "dodge_slow_speed", "homing_range", "homing_speed", "pogo_speed", "rail_min_speed", "boost_pad_speed", "boost_hold", "cam_distance", "cam_lag", "cam_recenter_delay",
	"seed_throw_speed", "seed_throw_up", "bomb_throw_keep", "bomb_friction", "bomb_bat_speed", "bomb_bat_up", "bomb_jump_speed", "pincer_window", "pincer_bonus", "knight_magnet_range",
	"knight_pull_speed", "knight_open_time", "knight_push_knock", "knight_magnet_cd", "iron_plough_knock", "fire_spread_delay", "fire_damage_every",
	"pot_throw_speed", "pot_throw_run", "pot_throw_up", "pot_respawn", "honey_slow", "honey_jump", "honey_cover", "candy_heat_time", "heat_reach", "candle_heat", "swap_range", "drunk_time", "drunk_sway", "drunk_monster_time", "wet_time", "wine_burn", "lure_range", "crate_push_speed", "crate_burn",
	"step_height", "launch_up"]
