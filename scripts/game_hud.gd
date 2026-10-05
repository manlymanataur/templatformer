extends CanvasLayer
## Ocarina of Time's HUD and menus (jovi, 2026-10-05). Hearts top left. Top right, the button cluster: B (green,
## the attack button: what it does now), A (blue, the context button: what it would do now, like Ocarina's
## action icon) and the three yellow C buttons (the quick slots 1, 2 and 3, with their items). Enter / Start
## opens the pause menu (PauseMenu): Select Item, Map, Quest Status and Equipment.

var player: Player
var hearts: Control
var buttons: Buttons
var menu: PauseMenu
var tint: ColorRect ## blue wash while a perfect dodge slows the world

class Hearts extends Control:
	var player: Player
	func _process(_dt: float) -> void:
		queue_redraw()
	func _draw() -> void:
		for i in player.max_hp / 2:
			var fill := clampi(player.hp - i * 2, 0, 2)
			var o := Vector2(i * 34, 0)
			_heart(o, Color(0.25, 0.1, 0.12))
			if fill == 2:
				_heart(o, Color(0.95, 0.2, 0.3))
			elif fill == 1:
				_heart(o, Color(0.95, 0.2, 0.3), true)
		# focus: a thin bar under the hearts while you hold the poleaxe's measure (full: the next attack is a flash step)
		if player.focus_meter > 0.0:
			var w := 34.0 * player.max_hp / 2 - 6.0
			draw_rect(Rect2(0, 34, w, 5), Color(0, 0, 0, 0.35))
			draw_rect(Rect2(0, 34, w * player.focus_meter, 5), Color(1.0, 0.95, 0.6) if player.focus_meter >= 1.0 else Color(0.6, 0.8, 1.0, 0.8))
	func _heart(o: Vector2, c: Color, half := false) -> void:
		var pts := PackedVector2Array()
		for k in 33:
			var t := TAU * k / 32.0
			var x := 16.0 * pow(sin(t), 3)
			var y := -(13.0 * cos(t) - 5.0 * cos(2 * t) - 2.0 * cos(3 * t) - cos(4 * t))
			if half and x > 0.0:
				x = 0.0
			pts.append(o + Vector2(16 + x, 15 + y) * 0.9)
		draw_colored_polygon(pts, c)

## The button cluster, top right: B, A and the three C buttons, as in Ocarina.
class Buttons extends Control:
	var player: Player
	const B_COL := Color(0.2, 0.7, 0.3)
	const A_COL := Color(0.25, 0.45, 0.95)
	const C_COL := Color(1.0, 0.82, 0.15)
	func _process(_dt: float) -> void:
		queue_redraw()
	## Where each button sits, from the cluster's top-right corner.
	static func spot(which: String) -> Vector2:
		match which:
			"B":
				return Vector2(-232, 44)
			"A":
				return Vector2(-176, 70)
			"C1":
				return Vector2(-112, 50)
			"C2":
				return Vector2(-72, 86)
			"C3":
				return Vector2(-32, 50)
		return Vector2.ZERO
	func _draw() -> void:
		var f := get_theme_default_font()
		var o := Vector2(size.x - 14, 12)
		_button(f, o + spot("B"), 26.0, B_COL, player.attack_label(), "B")
		_button(f, o + spot("A"), 30.0, A_COL, player.context_label(), "A")
		for i in Inventory.SLOTS:
			var at := o + spot("C%d" % (i + 1))
			var id := player.inventory.slots[i]
			draw_circle(at, 21.0, Color(0, 0, 0, 0.35))
			draw_arc(at, 21.0, 0.0, TAU, 28, C_COL, 3.0)
			if id != "":
				var col: Color = Inventory.ITEMS[id]["color"]
				if Inventory.ITEMS[id].get("toggle", false) and not player.item_active(id) and id != "magnet":
					col = col.darkened(0.35)
				draw_circle(at, 14.0, col)
				if int(Inventory.ITEMS[id]["max"]) > 1:
					draw_string(f, at + Vector2(-2, 20), str(player.inventory.count(id)), HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)
				if id == "magnet":
					draw_string(f, at + Vector2(-5, 6), "+" if player.magnet_push else "−", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, Color.WHITE)
			draw_string(f, at + Vector2(-4, -24), str(i + 1), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, C_COL)
	func _button(f: Font, at: Vector2, r: float, c: Color, label: String, key: String) -> void:
		draw_circle(at, r, Color(c, 0.85) if label != "" else Color(c.darkened(0.6), 0.5))
		draw_arc(at, r, 0.0, TAU, 32, Color(1, 1, 1, 0.5), 2.0)
		if label == "":
			draw_string(f, at + Vector2(-5, 6), key, HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color(1, 1, 1, 0.4))
		else:
			draw_string(f, at + Vector2(-r, 5), label, HORIZONTAL_ALIGNMENT_CENTER, r * 2.0, 13, Color.WHITE)

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	tint = ColorRect.new()
	tint.set_anchors_preset(Control.PRESET_FULL_RECT)
	tint.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tint.color = Color(0.3, 0.5, 1.0, 0.0)
	add_child(tint)
	hearts = Hearts.new()
	hearts.player = player
	hearts.position = Vector2(14, 12)
	add_child(hearts)
	buttons = Buttons.new()
	buttons.player = player
	buttons.set_anchors_preset(Control.PRESET_FULL_RECT)
	buttons.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(buttons)
	var top := CanvasLayer.new() # over everything, the debug readout too
	top.layer = 20
	top.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(top)
	menu = PauseMenu.new()
	menu.player = player
	top.add_child(menu)

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("inventory"):
		if menu.is_open:
			menu.close()
		elif not get_tree().paused:
			menu.open()
		get_viewport().set_input_as_handled()

func _process(_dt: float) -> void:
	tint.color.a = 0.18 if Hitfx.slow_left > 0.0 else 0.0
