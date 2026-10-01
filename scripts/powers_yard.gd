class_name PowersYard
extends RefCounted
## The Powers yard (Power Combat Sketchbook II, jovi 2026-10-01): east of the ground slab, x 120..159, z -43..43,
## floor at y 0. A walkway strip (x 120..126) runs past four rooms, each one encounter for one power. The item
## for each room lies on the strip at its door. Monsters come back while you're near (Squad).
##   Shade room (z -42..-23, roofed and dark): shades and blobs, one brazier pool by the door. Your poleaxe
##     passes through shades in the dark; call Umbra and its greatsword cuts them. Hit one together for a pincer.
##   Knight court (z -21..-2, open): iron knights among iron blocks. Face a knight to pull it in (shield down)
##     or flip the magnet to blow it into the wall; slide blocks into the pack.
##   Fire room (z 2..21, roofed and dark): shades and blobs over fields of 1 m grass patches. The candle
##     exposes shades; swing with it on and the grass catches and spreads, burning them but never you.
##   Bomb court (z 23..42, open): a plated brute and blobs, bomb flowers by the walls. Only blasts crack its
##     plates. Bat bombs with the poleaxe; pound onto one for a bomb jump.

const X0 := 126.0 ## rooms run from here (their west wall, with the door) ...
const X1 := 158.0 ## ... to here
const ROOF := 6.0
const WALL := Color(0.32, 0.3, 0.42)
const STONE := Color(0.6, 0.58, 0.55)
const FLOOR := Color(0.55, 0.6, 0.5)

## A group of powers-book monsters that comes back RESPAWN seconds after the last one falls, while you're near.
class Squad extends Node3D:
	const RESPAWN := 5.0
	var spawns: Array = [] ## [kind, position]
	var alive: Array = []
	var _wait := 0.0
	func _ready() -> void:
		add_to_group("spawners")
		_spawn()
	func _spawn() -> void:
		alive.clear()
		for s in spawns:
			var m := PowersYard.foe(get_parent(), s[0], s[1])
			m.drop_heart = randf() < 0.3
			alive.append(m)
	func _physics_process(dt: float) -> void:
		for m in alive:
			if is_instance_valid(m):
				return
		var ps := get_tree().get_nodes_in_group("player")
		if ps.is_empty() or (ps[0] as Node3D).global_position.distance_to(global_position) > 30.0:
			return
		_wait += dt
		if _wait >= RESPAWN:
			_wait = 0.0
			_spawn()

## shade, knight and plated are the powers-book kinds; anything else is a plain Monster kind.
static func foe(parent: Node, kind: String, pos: Vector3) -> Monster:
	match kind:
		"shade":
			return Shade.make(parent, pos)
		"knight":
			return IronKnight.make(parent, pos)
		"plated":
			return PlatedBrute.make(parent, pos)
	return Monster.spawn(parent, pos, kind)

static func squad(lv: Node3D, at: Vector3, spawns: Array) -> Squad:
	var s := Squad.new()
	s.spawns = spawns
	s.position = at
	lv.add_child(s)
	return s

static func build(lv: Node3D) -> void:
	var marks: Dictionary = lv.marks
	var t: Tuning = lv.t
	var rect := func(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, c: Color) -> StaticBody3D:
		return lv.box(Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0, y1 - y0, z1 - z0), Basis(), c)

	# the yard's own slab, flush with the ground slab's east edge (x 120)
	rect.call(120, 159, -43, 43, -1, 0, FLOOR)
	lv.label(Vector3(123, 4, 0), "Powers yard")
	Pickup.spawn(lv, "poleaxe", 1, Vector3(122, 0.8, 0))
	marks["power_yard"] = Vector3(121.5, 0.6, 0)

	# --- shade room: dark, Umbra's greatsword is the only blade that cuts a shade there
	_room(rect, -42, -23, true)
	lv.label(Vector3(123, 3, -32.5), "shades: only Umbra's greatsword cuts them in the dark", 28)
	Pickup.spawn(lv, "umbra", 1, Vector3(123, 0.8, -30))
	var pool := Brazier.make(lv, Vector3(130, 0, -28), true)
	pool.reach = 5.0 # a small safe pool: shades won't enter it, but Umbra can't fight in it either
	squad(lv, Vector3(148, 0, -32.5), [["shade", Vector3(150, 0.6, -36)], ["shade", Vector3(152, 0.6, -29)],
		["blob", Vector3(146, 0.6, -33)], ["blob", Vector3(154, 0.6, -33)]])
	marks["power_twin"] = Vector3(124, 0.6, -32.5)
	marks["power_twin_room"] = Vector3(140, 0.6, -38) # inside, in the dark

	# --- knight court: iron knights and iron blocks
	_room(rect, -21, -2, false)
	lv.label(Vector3(123, 3, -11.5), "iron knights: face one to pull it in, flip the magnet to blow it away", 28)
	Pickup.spawn(lv, "magnet", 1, Vector3(123, 0.8, -9))
	for c in [Vector3(137, 0, -15), Vector3(137, 0, -7), Vector3(145, 0, -11)]:
		IronCube.make(lv, c)
	squad(lv, Vector3(150, 0, -11.5), [["knight", Vector3(151, 0.6, -16)], ["knight", Vector3(153, 0.6, -11)],
		["knight", Vector3(151, 0.6, -6)], ["blob", Vector3(155, 0.6, -11)]])
	marks["power_iron"] = Vector3(124, 0.6, -11.5)
	marks["power_iron_room"] = Vector3(132, 0.6, -11.5)

	# --- fire room: dark, grass in 1 m patches so you can watch the fire walk
	_room(rect, 2, 21, true)
	lv.label(Vector3(123, 3, 11.5), "fire: the candle shows shades; swing it to light the grass", 28)
	Pickup.spawn(lv, "candle", 1, Vector3(123, 0.8, 9))
	Burnable.field(lv, Vector3(135, 0, 4), 8, 6)
	Burnable.field(lv, Vector3(146, 0, 13), 8, 6)
	Burnable.field(lv, Vector3(135, 0, 15), 5, 4)
	Brazier.make(lv, Vector3(156, 0, 4))
	Brazier.make(lv, Vector3(156, 0, 19))
	squad(lv, Vector3(148, 0, 11.5), [["shade", Vector3(140, 0.6, 7)], ["shade", Vector3(150, 0.6, 16)],
		["shade", Vector3(154, 0.6, 9)], ["blob", Vector3(139, 0.6, 17)], ["blob", Vector3(149, 0.6, 7)]])
	marks["power_fire"] = Vector3(124, 0.6, 11.5)
	marks["power_fire_room"] = Vector3(130, 0.6, 11.5)

	# --- bomb court: a plated brute, blobs and bomb flowers by the walls
	_room(rect, 23, 42, false)
	lv.label(Vector3(123, 3, 32.5), "plated brute: only bombs crack its plates; bat them, or pound onto one", 28)
	for f in [Vector3(130, 0, 25), Vector3(130, 0, 40), Vector3(156, 0, 25), Vector3(156, 0, 40)]:
		BombFlower.make(lv, f, t)
	squad(lv, Vector3(148, 0, 32.5), [["plated", Vector3(150, 0.6, 32.5)], ["blob", Vector3(146, 0.6, 28)],
		["blob", Vector3(146, 0.6, 37)], ["blob", Vector3(154, 0.6, 30)]])
	marks["power_bombs"] = Vector3(124, 0.6, 32.5)
	marks["power_bombs_room"] = Vector3(132, 0.6, 32.5)

## Walls round a room from X0 to X1 between z0 and z1, with a 4 m door in the west wall. Roofed rooms are dark.
static func _room(rect: Callable, z0: float, z1: float, roofed: bool) -> void:
	var h := ROOF if roofed else 4.0
	var zc := (z0 + z1) / 2.0
	rect.call(X0 - 0.5, X0, z0, zc - 2.0, 0, h, WALL)
	rect.call(X0 - 0.5, X0, zc + 2.0, z1, 0, h, WALL)
	if roofed:
		rect.call(X0 - 0.5, X0, zc - 2.0, zc + 2.0, 4.0, h, WALL) # lintel: the door is 4 m high
	rect.call(X1, X1 + 0.5, z0, z1, 0, h, WALL)
	rect.call(X0 - 0.5, X1 + 0.5, z0 - 0.5, z0, 0, h, WALL)
	rect.call(X0 - 0.5, X1 + 0.5, z1, z1 + 0.5, 0, h, WALL)
	if roofed:
		rect.call(X0 - 0.5, X1 + 0.5, z0 - 0.5, z1 + 0.5, h, h + 0.5, WALL)
