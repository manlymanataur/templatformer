extends CanvasLayer
## Playtest tools. They pause the game while open.
## G: the warp and debug menu. Up/Down pick, Enter or Space choose, G or Esc close.
## P: drop a feedback pin. Type what's wrong (or leave it blank), Enter copies a link that brings anyone
##   back to this exact spot with your items, size and facing. Esc cancels.
## O: load a pin. Paste a pin link or code, Enter goes there.
## Opening the web build with #pin=CODE in the address loads that pin on start.

const WARPS := [
	["Start", "start"],
	["Ramps", "ramp10"],
	["Step heights", "step2.0"],
	["Gap course", "gap6"],
	["Wall-jump shaft", "shaft"],
	["Launch pads", "pad_up"],
	["Quarter pipe", "pipe_start"],
	["Lock-on targets", "targets"],
	["Item pickups", "pickups"],
	["Monster arena", "arena"],
	["Ember & Umbra: ramp", "hall_ramp"],
	["Ember & Umbra: candle room", "hall_a"],
	["Ember & Umbra: dark chasm", "hall_b"],
	["Ember & Umbra: lantern chasm", "hall_c"],
	["Lodestone: magnet", "yard_magnet"],
	["Lodestone: door", "yard_pull_a"],
	["Lodestone: launch pad", "yard_push_b"],
	["Lodestone: boost pad", "yard_boost_stand"],
	["Scale: grate room", "garden_grate_ramp"],
	["Scale: pond", "garden_pond_bank"],
	["Scale: ferry", "garden_ferry_edge"],
	["Rootworks: root bridge", "root_seed"],
	["Rootworks: lash ledge", "root_c_stand"],
	["Rootworks: lash post", "root_post_stand"],
	["Rootworks: gear room", "root_gear_room"],
	["Moves: climb tower", "moves_climb"],
	["Moves: grind rail", "moves_rail"],
	["Moves: pogo spikes", "moves_pogo"],
	["Moves: ledge grab", "moves_ledge"],
	["Challenge room doors", "challenge_doors"],
	["Combat: downhill", "combat_hill_top"],
	["Combat: spiked row", "combat_spiked"],
	["Combat: wolves", "combat_wolves"],
	["Combat: wall court", "combat_court"],
	["Test colossus", "colossus_arena"],
]
const SHOWN := 12 ## rows the menu shows at once
const ACTIONS := ["Give every item", "God mode", "Heal", "Shrink / grow"]

var level: Node3D
var player: Player
var rig: CameraRig
var menu: PanelContainer
var menu_text: Label
var sel := 0
var entry: PanelContainer
var entry_title: Label
var entry_line: LineEdit
var entry_mode := "" ## "pin" or "load"
var toast: Label
var toast_t := 0.0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 5
	menu = _panel(Vector2(420, 420))
	menu_text = Label.new()
	menu_text.add_theme_font_size_override("font_size", 17)
	menu.add_child(menu_text)
	entry = _panel(Vector2(640, 130))
	var box := VBoxContainer.new()
	entry.add_child(box)
	entry_title = Label.new()
	entry_title.autowrap_mode = TextServer.AUTOWRAP_WORD
	box.add_child(entry_title)
	entry_line = LineEdit.new()
	entry_line.custom_minimum_size = Vector2(600, 36)
	entry_line.text_submitted.connect(_submit)
	box.add_child(entry_line)
	toast = Label.new()
	toast.anchor_left = 0.5
	toast.anchor_right = 0.5
	toast.offset_left = -400
	toast.offset_right = 400
	toast.offset_top = 16
	toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast.autowrap_mode = TextServer.AUTOWRAP_WORD
	toast.add_theme_font_size_override("font_size", 18)
	toast.add_theme_color_override("font_outline_color", Color.BLACK)
	toast.add_theme_constant_override("outline_size", 6)
	add_child(toast)
	_load_start_pin.call_deferred()

func _panel(size: Vector2) -> PanelContainer:
	var p := PanelContainer.new()
	p.anchor_left = 0.5
	p.anchor_top = 0.5
	p.anchor_right = 0.5
	p.anchor_bottom = 0.5
	p.offset_left = -size.x / 2.0
	p.offset_top = -size.y / 2.0
	p.offset_right = size.x / 2.0
	p.offset_bottom = size.y / 2.0
	p.visible = false
	add_child(p)
	return p

## A pin in the page address (#pin=...) or on the command line (-- --pin=...) loads on start.
func _load_start_pin() -> void:
	var text := ""
	if OS.has_feature("web"):
		var h = JavaScriptBridge.eval("window.location.hash", true)
		if h is String:
			text = h
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--pin="):
			text = a
	if text.contains("pin="):
		_go_to_pin(text)

func _go_to_pin(text: String) -> void:
	var d := Pin.decode(text)
	if Pin.apply(player, d, rig):
		var note: String = d.get("note", "")
		say("Loaded pin" + (": " + note if note != "" else ""), 6.0)
	else:
		say("That isn't a pin code.", 3.0)

func say(text: String, secs: float) -> void:
	toast.text = text
	toast_t = secs

func _process(dt: float) -> void:
	toast_t -= dt
	toast.visible = toast_t > 0.0

func _open(on: bool) -> void:
	if on:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	get_tree().paused = on

func _unhandled_input(e: InputEvent) -> void:
	if not (e is InputEventKey and e.pressed and not e.echo):
		return
	var k: int = e.physical_keycode
	if entry.visible:
		if k == KEY_ESCAPE:
			_close_entry()
			get_viewport().set_input_as_handled()
		return
	if menu.visible:
		match k:
			KEY_UP: sel = (sel - 1 + _count()) % _count()
			KEY_DOWN: sel = (sel + 1) % _count()
			KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: _choose(sel)
			KEY_G, KEY_ESCAPE: _show_menu(false)
		_draw_menu()
		get_viewport().set_input_as_handled()
		return
	if get_tree().paused:
		return # the inventory screen is open
	match k:
		KEY_G:
			_show_menu(true)
			get_viewport().set_input_as_handled()
		KEY_P:
			_open_entry("pin", "Feedback pin: what's wrong or worth noting here? (Enter copies the link, Esc cancels)")
			get_viewport().set_input_as_handled()
		KEY_O:
			_open_entry("load", "Paste a pin link or code, then Enter. (Esc cancels)")
			get_viewport().set_input_as_handled()

func _count() -> int:
	return WARPS.size() + ACTIONS.size()

func _show_menu(on: bool) -> void:
	menu.visible = on
	_open(on)
	_draw_menu()

func _draw_menu() -> void:
	var s := "WARP AND DEBUG  (G to close)\n\n"
	# a window of rows around the selection, so the list fits a small screen
	var first := clampi(sel - SHOWN / 2, 0, maxi(_count() - SHOWN, 0))
	s += ("   ...\n" if first > 0 else "\n")
	for i in range(first, mini(first + SHOWN, _count())):
		var item: String
		if i < WARPS.size():
			item = WARPS[i][0]
		else:
			item = ACTIONS[i - WARPS.size()]
			if item == "God mode":
				item += ": " + ("on" if player.god else "off")
		if i == WARPS.size() and i > first:
			s += "   ---\n"
		s += ("> " if i == sel else "   ") + item + "\n"
	s += ("   ..." if first + SHOWN < _count() else "")
	menu_text.text = s

func _choose(i: int) -> void:
	if i < WARPS.size():
		warp(WARPS[i][1])
		_show_menu(false)
		return
	match ACTIONS[i - WARPS.size()]:
		"Give every item":
			for id in Inventory.ITEMS:
				player.inventory.add(id, int(Inventory.ITEMS[id]["max"]))
			say("Every item added. Enter opens the inventory to set quick slots.", 3.0)
		"God mode":
			player.god = not player.god
		"Heal":
			player.hp = player.max_hp
		"Shrink / grow":
			if not player.set_small(not player.small):
				say("No room to grow here.", 2.0)

## Where each warp puts you: a level mark, or a spot the menu names itself.
func warp_pos(key: String) -> Vector3:
	match key:
		"start":
			return player.spawn
		"arena":
			return Vector3(34, 0.6, 32)
	var m = level.marks.get(key)
	return m if m is Vector3 else player.spawn

func warp(key: String) -> void:
	player.teleport(warp_pos(key) + Vector3.UP * 0.4)
	player.up_direction = Vector3.UP
	player.target = null
	if rig != null:
		rig.global_position = player.global_position

func _open_entry(mode: String, title: String) -> void:
	entry_mode = mode
	entry_title.text = title
	entry_line.text = ""
	entry.visible = true
	_open(true)
	entry_line.grab_focus()

func _close_entry() -> void:
	entry.visible = false
	entry_line.release_focus()
	_open(false)

func _submit(text: String) -> void:
	_close_entry()
	if entry_mode == "load":
		_go_to_pin(text)
		return
	var link := pin_link(text.strip_edges())
	DisplayServer.clipboard_set(link)
	say("Pin copied to the clipboard. Paste it in the project chat.", 6.0)

func pin_link(note: String) -> String:
	var code := Pin.encode(Pin.capture(player, rig.yaw if rig != null else 0.0, note))
	var base := "https://manlymanataur.github.io/templatformer/"
	if OS.has_feature("web"):
		var here = JavaScriptBridge.eval("window.location.origin + window.location.pathname", true)
		if here is String and here != "":
			base = here
	return base + "#pin=" + code
