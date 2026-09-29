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
@export var spin_charge_time := 0.6
@export var bomb_throw_speed := 7.0
@export var bomb_throw_up := 5.0
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
@export var boost_pad_speed := 30.0
@export var cam_distance := 7.0
@export var cam_lag := 10.0
@export var cam_recenter_delay := 0.8

const EDITABLE: Array[String] = ["top_speed", "boost_speed", "overspeed_decay", "accel", "friction", "brake", "turn_rate", "turn_rate_fast",
	"air_accel", "gravity", "jump_speed", "jump_cut", "coyote_time", "jump_buffer", "slope_factor",
	"jump_combo_window", "double_jump_mult", "triple_jump_mult", "triple_min_speed", "wall_slide_speed", "wall_jump_speed",
	"wall_jump_up", "roll_speed", "roll_time", "roll_invuln", "strafe_speed", "spin_charge_time", "bomb_throw_speed",
	"bomb_throw_up", "dodge_tap_time", "candle_range", "candle_touch", "umbra_speed", "umbra_crawl_speed", "magnet_range", "iron_speed", "small_scale", "small_speed_mult", "small_jump_mult", "small_swim_speed", "magnet_fly_speed", "magnet_fly_range", "boost_pad_speed", "cam_distance", "cam_lag", "cam_recenter_delay"]
