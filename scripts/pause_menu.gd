class_name PauseMenu
extends Control
## The pause menu, Ocarina of Time's (jovi, 2026-10-05): four screens on a turning box. Z (Shift, left trigger)
## and R (C, right trigger) turn it, as does running the cursor off a screen's side. Enter or Start closes it.
## - Select Item: the items you've found on a grid. 1, 2 or 3 (the C buttons) puts the one under the cursor
##   on that quick slot.
## - Map: every area of the world, the one you're in lit, and an arrow for you. The cursor picks an area to
##   name it.
## - Quest Status: the challenge stars, the colossus, heart containers and how many items you've found.
## - Equipment: the poleaxe and shield, and the moves they give you (the cursor tells you how to do each).
## GameHud owns it; tests drive it with open(), turn(), move() and assign() rather than real input.

const PAGES := ["Select Item", "Map", "Quest Status", "Equipment"]
const W := 780.0
const H := 470.0
const GOLD := Color(1.0, 0.85, 0.3)
const C_YELLOW := Color(1.0, 0.82, 0.15)
const ITEM_COLS := 4

## The world's areas for the map (x, z boxes), north (-z) up. LevelRules.AREAS plus the ones it leaves out.
const ZONES := {
	"Plains": Rect2(-120, -120, 240, 240),
	"Ember & Umbra": Rect2(-14, 34, 24, 88),
	"Lodestone": Rect2(50, -36, 30, 40),
	"Scale garden": Rect2(-100, 36, 46, 76),
	"Rootworks": Rect2(34, 53, 52, 61),
	"Moves yard": Rect2(-26, -120, 52, 56),
	"Combat yard": Rect2(-118, -66, 62, 54),
	"Spider & lash pens": Rect2(-116, -2, 56, 26),
	"Colossus arena": Rect2(56, -118, 48, 48),
	"Powers yard": Rect2(120, -43, 39, 86),
	"The Works": Rect2(160, -44, 108, 60),
	"Cellar": Rect2(134, -152, 40, 52),
	"Mountain climb": Rect2(-212, -347, 70, 128),
	"Ski run": Rect2(-232, -220, 64, 716),
}
## Moves the equipment page lists: name, what you need, how.
const MOVES := [
	["Thrust combo", "poleaxe", "Attack, attack, attack: the second and third hits launch."],
	["Running blade", "poleaxe", "Attack while running fast."],
	["Hammer", "poleaxe", "Hold attack a moment and let go: it smashes shields and armour."],
	["Spin", "poleaxe", "Hold attack longer and let go. Keep holding for up to three spins."],
	["Shield", "poleaxe", "Hold guard (C). Raise it just as a blow lands to parry."],
	["Shield bash", "poleaxe", "Attack while guarding."],
	["Shield surf", "poleaxe", "Land holding guard, or guard on snow: ski."],
	["Homing attack", "poleaxe", "Attack in the air while holding lock-on."],
	["Flash step", "poleaxe", "Locked on at the poleaxe's measure, the focus bar fills: attack."],
	["Ground pound", "", "Attack in the air without lock-on. Needs nothing."],
]

var player: Player
var page := 0
var cursor := Vector2i.ZERO ## column, row on this page
var is_open := false
var _spin := 0.0 ## the box turning between pages: -1..1, easing to 0

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	process_mode = Node.PROCESS_MODE_ALWAYS
	visible = false

func open(pause := true) -> void:
	is_open = true
	visible = true
	cursor = Vector2i.ZERO
	if pause:
		get_tree().paused = true
	queue_redraw()

func close() -> void:
	is_open = false
	visible = false
	get_tree().paused = false

## Turn the box to the next screen (1) or the one before (-1).
func turn(dir: int) -> void:
	page = posmod(page + dir, PAGES.size())
	_spin = float(dir)
	cursor = Vector2i(0 if dir > 0 else _cols() - 1, clampi(cursor.y, 0, _rows() - 1))
	queue_redraw()

## Move the cursor; off a screen's side it turns to the next one, as in Ocarina.
func move(d: Vector2i) -> void:
	var c := cursor + d
	if c.x < 0:
		turn(-1)
		return
	if c.x >= _cols():
		turn(1)
		return
	cursor = Vector2i(c.x, clampi(c.y, 0, _rows() - 1))
	queue_redraw()

## Put the item under the cursor on quick slot i (the C buttons). Only on Select Item.
func assign(i: int) -> bool:
	if page != 0:
		return false
	var id := item_at(cursor)
	if id == "" or not player.inventory.has(id):
		return false
	player.inventory.assign(i, id)
	queue_redraw()
	return true

## The slot items in grid order (the poleaxe is equipment, not an item).
static func grid_items() -> Array[String]:
	var r: Array[String] = []
	for id in Inventory.ITEMS:
		if Inventory.ITEMS[id]["slot"]:
			r.append(id)
	return r

func item_at(c: Vector2i) -> String:
	var items := grid_items()
	var k := c.y * ITEM_COLS + c.x
	return items[k] if k < items.size() else ""

func _cols() -> int:
	match page:
		0:
			return ITEM_COLS
		2:
			return 1
		3:
			return 2
	return 1

func _rows() -> int:
	match page:
		0:
			return ceili(grid_items().size() / float(ITEM_COLS))
		1:
			return ZONES.size()
		3:
			return ceili(MOVES.size() / 2.0) + 1
	return 1

## The area you're in (the smallest box holding you), or "" out in the wilds.
static func zone_of(at: Vector3) -> String:
	var best := ""
	var area := INF
	for z in ZONES:
		var r: Rect2 = ZONES[z]
		if r.has_point(Vector2(at.x, at.z)) and r.get_area() < area:
			best = z
			area = r.get_area()
	return best

## The challenges (Challenge nodes in the level's marks), in order.
func challenges() -> Array:
	var r := []
	var lv := player.get_parent()
	if lv != null and "marks" in lv:
		var m: Dictionary = lv.get("marks")
		for k in m:
			if str(k).begins_with("challenge_") and m[k] is Challenge:
				r.append(m[k])
	return r

func colossus_felled() -> bool:
	var lv := player.get_parent()
	if lv != null and "marks" in lv:
		var c = (lv.get("marks") as Dictionary).get("colossus")
		if c is Colossus:
			return (c as Colossus).felled
	return false

## What the bottom bar says about what's under the cursor.
func caption() -> String:
	match page:
		0:
			var id := item_at(cursor)
			if id == "" :
				return ""
			if not player.inventory.has(id):
				return "???"
			var s: String = Inventory.ITEMS[id]["name"]
			var on := player.inventory.slots.find(id)
			return s + ("   (on C%d)" % (on + 1) if on >= 0 else "   1 2 3: set it to a C button")
		1:
			var z: String = ZONES.keys()[clampi(cursor.y, 0, ZONES.size() - 1)]
			return z + ("   (you are here)" if zone_of(player.global_position) == z else "")
		2:
			var done := 0
			for c in challenges():
				if c.cleared:
					done += 1
			return "Challenge stars %d / %d" % [done, challenges().size()]
		3:
			var k := _move_index()
			if k < 0:
				return "Poleaxe & Shield: one weapon, the move picks the head." if player.inventory.has("poleaxe") else "???"
			var mv: Array = MOVES[k]
			if mv[1] != "" and not player.inventory.has(mv[1]):
				return "???"
			return "%s: %s" % [mv[0], mv[2]]
	return ""

func _move_index() -> int:
	if cursor.y == 0:
		return -1
	var k := (cursor.y - 1) * 2 + cursor.x
	return k if k < MOVES.size() else -1

func _unhandled_input(e: InputEvent) -> void:
	if not is_open:
		return
	if e.is_action_pressed("target"):
		turn(-1)
	elif e.is_action_pressed("guard"):
		turn(1)
	elif e.is_action_pressed("ui_left"):
		move(Vector2i(-1, 0))
	elif e.is_action_pressed("ui_right"):
		move(Vector2i(1, 0))
	elif e.is_action_pressed("ui_up"):
		move(Vector2i(0, -1))
	elif e.is_action_pressed("ui_down"):
		move(Vector2i(0, 1))
	else:
		for i in Inventory.SLOTS:
			if e.is_action_pressed("item_%d" % (i + 1)):
				assign(i)
		return
	get_viewport().set_input_as_handled()

func _process(dt: float) -> void:
	if not is_open:
		return
	_spin = move_toward(_spin, 0.0, dt * 4.0)
	queue_redraw()

# --- drawing -----------------------------------------------------------------------------------------------

func _draw() -> void:
	if not is_open:
		return
	var view := get_viewport_rect().size
	draw_rect(Rect2(Vector2.ZERO, view), Color(0, 0, 0, 0.55))
	var mid := view / 2.0
	# the box turning: the screen squeezes in from the side it's coming from
	var squeeze := cos(_spin * PI / 2.0)
	var w := W * maxf(squeeze, 0.05)
	var box := Rect2(mid.x - w / 2.0 + _spin * W * 0.25, mid.y - H / 2.0, w, H)
	draw_rect(box, Color(0.12, 0.1, 0.16, 0.94))
	draw_rect(box, Color(0.75, 0.62, 0.3), false, 3.0)
	if squeeze < 0.6:
		return
	var f := get_theme_default_font()
	_text(f, Vector2(box.position.x, box.position.y + 34), box.size.x, PAGES[page].to_upper(), 26, GOLD)
	# the turn markers, Z and R
	var prev: String = PAGES[posmod(page - 1, PAGES.size())]
	var next: String = PAGES[posmod(page + 1, PAGES.size())]
	_text(f, Vector2(box.position.x + 12, box.position.y + 30), 200, "◀ Z  " + prev, 14, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_LEFT)
	_text(f, Vector2(box.end.x - 212, box.position.y + 30), 200, next + "  R ▶", 14, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_RIGHT)
	var inner := Rect2(box.position + Vector2(24, 52), box.size - Vector2(48, 110))
	match page:
		0:
			_draw_items(f, inner)
		1:
			_draw_map(f, inner)
		2:
			_draw_quest(f, inner)
		3:
			_draw_equipment(f, inner)
	# the bottom bar: what's under the cursor
	var bar := Rect2(box.position.x + 24, box.end.y - 50, box.size.x - 48, 34)
	draw_rect(bar, Color(0, 0, 0, 0.35))
	_text(f, Vector2(bar.position.x, bar.position.y + 23), bar.size.x, caption(), 17, Color.WHITE)

func _text(f: Font, at: Vector2, width: float, s: String, fs: int, c: Color, align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	draw_string(f, at, s, align, width, fs, c)

func _cell(r: Rect2, selected: bool) -> void:
	draw_rect(r, Color(1, 1, 1, 0.06))
	draw_rect(r, GOLD if selected else Color(1, 1, 1, 0.18), false, 3.0 if selected else 1.0)

func _draw_items(f: Font, inner: Rect2) -> void:
	var items := grid_items()
	var cw := inner.size.x / ITEM_COLS
	var ch := minf(inner.size.y / maxf(_rows(), 1.0), 130.0)
	for k in items.size():
		var c := Vector2i(k % ITEM_COLS, k / ITEM_COLS)
		var r := Rect2(inner.position + Vector2(c.x * cw, c.y * ch) + Vector2(8, 8), Vector2(cw - 16, ch - 16))
		_cell(r, c == cursor)
		var id := items[k]
		if not player.inventory.has(id):
			continue
		var ic := r.get_center() + Vector2(0, -12)
		draw_circle(ic, 24.0, Inventory.ITEMS[id]["color"])
		draw_arc(ic, 24.0, 0.0, TAU, 32, Color(0, 0, 0, 0.5), 2.0)
		var n := player.inventory.count(id)
		if int(Inventory.ITEMS[id]["max"]) > 1:
			_text(f, ic + Vector2(4, 22), 30, str(n), 14, Color.WHITE)
		_text(f, Vector2(r.position.x, r.end.y - 10), r.size.x, Inventory.ITEMS[id]["name"], 14, Color(1, 1, 1, 0.85))
		var on := player.inventory.slots.find(id)
		if on >= 0: # which C button it's on
			var tag := r.position + Vector2(r.size.x - 18, 18)
			draw_circle(tag, 12.0, C_YELLOW)
			_text(f, tag + Vector2(-12, 5), 24, str(on + 1), 14, Color(0.2, 0.15, 0.0))

func _draw_map(f: Font, inner: Rect2) -> void:
	# fit every zone in, north (-z) up
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	for z in ZONES:
		var r: Rect2 = ZONES[z]
		lo = lo.min(r.position)
		hi = hi.max(r.end)
	var list_w := 200.0
	var area := Rect2(inner.position, inner.size - Vector2(list_w + 12, 0))
	var k := minf(area.size.x / (hi.x - lo.x), area.size.y / (hi.y - lo.y))
	var off := area.position + (area.size - (hi - lo) * k) / 2.0
	var here := zone_of(player.global_position)
	var picked: String = ZONES.keys()[clampi(cursor.y, 0, ZONES.size() - 1)]
	for z in ZONES:
		var r: Rect2 = ZONES[z]
		var sr := Rect2(off + (r.position - lo) * k, r.size * k)
		var col := Color(0.35, 0.5, 0.35, 0.55)
		if z == here:
			col = Color(0.4, 0.75, 1.0, 0.7)
		draw_rect(sr, col)
		draw_rect(sr, GOLD if z == picked else Color(1, 1, 1, 0.3), false, 2.0 if z == picked else 1.0)
	# you: an arrow pointing the way you face
	var p := player.global_position
	var at := off + (Vector2(p.x, p.z) - lo) * k
	var fw := Vector2(player.facing.x, player.facing.z).normalized() if Vector2(player.facing.x, player.facing.z).length() > 0.01 else Vector2(0, -1)
	var tip := at + fw * 9.0
	var side := Vector2(-fw.y, fw.x) * 5.0
	draw_colored_polygon(PackedVector2Array([tip, at - fw * 4.0 + side, at - fw * 4.0 - side]), Color(1.0, 0.3, 0.2))
	# the area list
	var lx := inner.end.x - list_w
	var y := inner.position.y + 14.0
	var step := minf(inner.size.y / ZONES.size(), 22.0)
	var i := 0
	for z in ZONES:
		var c := GOLD if i == cursor.y else (Color(0.5, 0.85, 1.0) if z == here else Color(1, 1, 1, 0.75))
		_text(f, Vector2(lx, y), list_w, ("▸ " if i == cursor.y else "  ") + z, 15, c, HORIZONTAL_ALIGNMENT_LEFT)
		y += step
		i += 1

func _draw_quest(f: Font, inner: Rect2) -> void:
	# challenge stars, like the medallions
	var cs := challenges()
	var cx := inner.position.x + inner.size.x * 0.3
	var cy := inner.position.y + inner.size.y * 0.42
	_text(f, Vector2(inner.position.x, inner.position.y + 20), inner.size.x * 0.6, "Challenges", 17, Color(1, 1, 1, 0.75))
	for i in cs.size():
		var a := -PI / 2.0 + TAU * i / maxf(cs.size(), 1.0)
		var at := Vector2(cx, cy) + Vector2(cos(a), sin(a)) * 80.0
		_star(at, 26.0, GOLD if cs[i].cleared else Color(0.3, 0.3, 0.35))
		_text(f, at + Vector2(-60, 46), 120, cs[i].title, 13, Color(1, 1, 1, 0.8))
	# the colossus, like a spiritual stone
	var col := Vector2(inner.position.x + inner.size.x * 0.78, cy - 40)
	var felled := colossus_felled()
	draw_circle(col, 34.0, Color(0.3, 0.9, 1.0) if felled else Color(0.25, 0.25, 0.3))
	draw_arc(col, 34.0, 0.0, TAU, 32, Color(0.75, 0.62, 0.3), 3.0)
	_text(f, col + Vector2(-80, 56), 160, "Colossus" + (" felled" if felled else ""), 15, Color(1, 1, 1, 0.85))
	# hearts and items found
	var found := 0
	for id in Inventory.ITEMS:
		if player.inventory.has(id):
			found += 1
	_text(f, Vector2(col.x - 120, col.y + 110), 240, "Heart containers  %d" % (player.max_hp / 2), 16, Color(1.0, 0.45, 0.5))
	_text(f, Vector2(col.x - 120, col.y + 136), 240, "Items found  %d / %d" % [found, Inventory.ITEMS.size()], 16, Color.WHITE)

func _star(at: Vector2, r: float, c: Color) -> void:
	var pts := PackedVector2Array()
	for k in 10:
		var a := -PI / 2.0 + TAU * k / 10.0
		pts.append(at + Vector2(cos(a), sin(a)) * (r if k % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, c)

func _draw_equipment(f: Font, inner: Rect2) -> void:
	var has := player.inventory.has("poleaxe")
	var top := Rect2(inner.position + Vector2(8, 4), Vector2(inner.size.x - 16, 70))
	_cell(top, cursor.y == 0)
	if has:
		draw_line(top.position + Vector2(40, 58), top.position + Vector2(110, 12), Color(0.85, 0.75, 0.45), 6.0)
		draw_rect(Rect2(top.position + Vector2(140, 14), Vector2(36, 44)), Color(0.35, 0.45, 0.7))
		_text(f, top.position + Vector2(200, 44), 400, "Poleaxe & Shield", 20, Color.WHITE, HORIZONTAL_ALIGNMENT_LEFT)
	var rows := ceili(MOVES.size() / 2.0)
	var ch := (inner.size.y - 84.0) / rows
	var cw := inner.size.x / 2.0
	for k in MOVES.size():
		var c := Vector2i(k % 2, k / 2 + 1)
		var r := Rect2(inner.position + Vector2(c.x * cw + 8, 84.0 + (c.y - 1) * ch), Vector2(cw - 16, ch - 6))
		_cell(r, c == cursor)
		var mv: Array = MOVES[k]
		var known: bool = mv[1] == "" or player.inventory.has(mv[1])
		_text(f, r.position + Vector2(14, r.size.y / 2.0 + 6), r.size.x - 20, mv[0] if known else "???", 16,
			Color.WHITE if known else Color(1, 1, 1, 0.3), HORIZONTAL_ALIGNMENT_LEFT)
