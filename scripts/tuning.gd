class_name Tuning
extends Resource
## Every feel number in one place. The debug HUD edits these live and saves them to user://tuning.tres.

@export var top_speed := 12.0 ## running speed you reach by holding a direction
@export var boost_speed := 32.0 ## hard cap; slopes and boost pads can take you past top_speed up to this
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
@export var stick_speed := 8.0 ## below this you peel off walls and ceilings
@export var boost_pad_speed := 30.0
@export var cam_distance := 7.0
@export var cam_lag := 10.0
@export var cam_recenter_delay := 0.8

const EDITABLE: Array[String] = ["top_speed", "boost_speed", "accel", "friction", "brake", "turn_rate", "turn_rate_fast",
	"air_accel", "gravity", "jump_speed", "jump_cut", "coyote_time", "jump_buffer", "slope_factor", "stick_speed",
	"boost_pad_speed", "cam_distance", "cam_lag", "cam_recenter_delay"]
