extends CanvasLayer
## Hearts (top left), the three quick slots (bottom right) and the pause-screen inventory (Enter).
## In the inventory, Up/Down pick an item and 1, 2 or 3 put it on that quick slot.

var player: Player
var hearts: Control
var slot_panels: Array[Label] = []
var pause_panel: PanelContainer
var pause_list: Label
var sel := 0

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

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	hearts = Hearts.new()
	hearts.player = player
	hearts.position = Vector2(14, 12)
	add_child(hearts)
	var row := HBoxContainer.new()
	row.anchor_left = 1.0
	row.anchor_top = 1.0
	row.anchor_right = 1.0
	row.anchor_bottom = 1.0
	row.offset_left = -330
	row.offset_top = -86
	row.offset_right = -14
	row.offset_bottom = -14
	row.add_theme_constant_override("separation", 8)
	add_child(row)
	for i in Inventory.SLOTS:
		var p := PanelContainer.new()
		p.custom_minimum_size = Vector2(100, 70)
		var l := Label.new()
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.autowrap_mode = TextServer.AUTOWRAP_WORD
		p.add_child(l)
		row.add_child(p)
		slot_panels.append(l)
	pause_panel = PanelContainer.new()
	pause_panel.anchor_left = 0.5
	pause_panel.anchor_top = 0.5
	pause_panel.anchor_right = 0.5
	pause_panel.anchor_bottom = 0.5
	pause_panel.offset_left = -220
	pause_panel.offset_top = -150
	pause_panel.offset_right = 220
	pause_panel.offset_bottom = 150
	pause_list = Label.new()
	pause_list.add_theme_font_size_override("font_size", 20)
	pause_panel.add_child(pause_list)
	pause_panel.visible = false
	add_child(pause_panel)
	player.inventory.changed.connect(_refresh)
	_refresh()

func _refresh() -> void:
	var inv := player.inventory
	for i in Inventory.SLOTS:
		var id := inv.slots[i]
		var text := "%d\n" % (i + 1)
		if id == "magnet":
			text += "Magnet " + ("+ push" if player.magnet_push else "− pull")
		elif id != "" and Inventory.ITEMS[id].get("toggle", false):
			text += Inventory.ITEMS[id]["name"] + (" (on)" if player.item_active(id) else "")
		elif id != "":
			text += "%s ×%d" % [Inventory.ITEMS[id]["name"], inv.count(id)]
		else:
			text += "—"
		slot_panels[i].text = text
	var items := inv.owned()
	sel = clampi(sel, 0, maxi(items.size() - 1, 0))
	var s := "INVENTORY\n\n"
	if items.is_empty():
		s += "Nothing yet. Find the spear by the start.\n"
	for k in items.size():
		var id := items[k]
		var tag := ""
		if not Inventory.ITEMS[id]["slot"]:
			tag = "  (equipped: F / X to attack)"
		elif inv.slots.has(id):
			tag = "  [slot %d]" % (inv.slots.find(id) + 1)
		s += ("> " if k == sel else "   ") + "%s ×%d%s\n" % [Inventory.ITEMS[id]["name"], inv.count(id), tag]
	s += "\nUp/Down pick · 1 2 3 assign · Enter close"
	pause_list.text = s

func _unhandled_input(e: InputEvent) -> void:
	if e.is_action_pressed("inventory"):
		pause_panel.visible = not pause_panel.visible
		get_tree().paused = pause_panel.visible
		_refresh()
		get_viewport().set_input_as_handled()
		return
	if not pause_panel.visible:
		return
	var items := player.inventory.owned()
	if e.is_action_pressed("ui_up"):
		sel = maxi(sel - 1, 0)
	elif e.is_action_pressed("ui_down"):
		sel = mini(sel + 1, maxi(items.size() - 1, 0))
	else:
		for i in Inventory.SLOTS:
			if e.is_action_pressed("item_%d" % (i + 1)) and sel < items.size():
				player.inventory.assign(i, items[sel])
	_refresh()
