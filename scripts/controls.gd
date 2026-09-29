extends Node
## Registers input actions in code so the bindings live in one readable place.

const KEYS := {
	"move_left": [KEY_A, KEY_LEFT], "move_right": [KEY_D, KEY_RIGHT],
	"move_forward": [KEY_W, KEY_UP], "move_back": [KEY_S, KEY_DOWN],
	"jump": [KEY_SPACE], "target": [KEY_SHIFT, KEY_Z],
	"cam_left": [KEY_J], "cam_right": [KEY_L], "cam_up": [KEY_I], "cam_down": [KEY_K],
	"respawn": [KEY_R],
}
const PAD_AXES := {
	"move_left": [JOY_AXIS_LEFT_X, -1.0], "move_right": [JOY_AXIS_LEFT_X, 1.0],
	"move_forward": [JOY_AXIS_LEFT_Y, -1.0], "move_back": [JOY_AXIS_LEFT_Y, 1.0],
	"cam_left": [JOY_AXIS_RIGHT_X, -1.0], "cam_right": [JOY_AXIS_RIGHT_X, 1.0],
	"cam_up": [JOY_AXIS_RIGHT_Y, -1.0], "cam_down": [JOY_AXIS_RIGHT_Y, 1.0],
	"target": [JOY_AXIS_TRIGGER_LEFT, 1.0],
}
const PAD_BUTTONS := {"jump": JOY_BUTTON_A, "respawn": JOY_BUTTON_BACK}

func _ready() -> void:
	for action in KEYS:
		if not InputMap.has_action(action):
			InputMap.add_action(action, 0.2)
		for k in KEYS[action]:
			var e := InputEventKey.new()
			e.physical_keycode = k
			InputMap.action_add_event(action, e)
	for action in PAD_AXES:
		var m := InputEventJoypadMotion.new()
		m.axis = PAD_AXES[action][0]
		m.axis_value = PAD_AXES[action][1]
		InputMap.action_add_event(action, m)
	for action in PAD_BUTTONS:
		var b := InputEventJoypadButton.new()
		b.button_index = PAD_BUTTONS[action]
		InputMap.action_add_event(action, b)
