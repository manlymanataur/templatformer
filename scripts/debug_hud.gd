extends CanvasLayer
## Live tuning panel. Tab shows or hides it, [ and ] pick a value, - and = change it by 10%,
## Backspace resets it. Changes save to user://tuning.tres so they survive restarts.

var t: Tuning
var player: Player
var label: Label
var sel := 0
var shown := true

func _ready() -> void:
	label = Label.new()
	label.position = Vector2(12, 10)
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 5)
	add_child(label)

func _unhandled_key_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed):
		return
	var names := Tuning.EDITABLE
	var key := names[sel]
	match e.physical_keycode:
		KEY_TAB: shown = not shown
		KEY_BRACKETLEFT: sel = (sel - 1 + names.size()) % names.size()
		KEY_BRACKETRIGHT: sel = (sel + 1) % names.size()
		KEY_MINUS: set_value(key, t.get(key) * 0.9)
		KEY_EQUAL: set_value(key, t.get(key) * 1.1)
		KEY_BACKSPACE: set_value(key, Tuning.new().get(key))

func set_value(key: String, v: float) -> void:
	t.set(key, snappedf(v, 0.01))
	ResourceSaver.save(t, "user://tuning.tres")

func _process(_dt: float) -> void:
	label.visible = shown
	if not shown:
		return
	var s := "speed %5.1f   %s   slope %2d°%s\n" % [player.speed(), "ground" if player.is_on_floor() else "air",
		int(rad_to_deg(player.up_direction.angle_to(Vector3.UP))), "   LOCKED" if player.target else ""]
	s += "Tab hide · [ ] pick · - = change · Backspace reset · R respawn\n\n"
	for i in Tuning.EDITABLE.size():
		var n := Tuning.EDITABLE[i]
		s += ("> " if i == sel else "   ") + "%s  %.2f\n" % [n, t.get(n)]
	label.text = s
