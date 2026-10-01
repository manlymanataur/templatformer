class_name Works
extends RefCounted
## The Works: Winch's machinery and two Lodestone rules, east of the Powers yard (x 159..244, z -44..16, plus a
## far island at x 258..266). The magnet, the lash and the clockwork spider lie at the west entrance.
## Iron room (north-west, its own 2 m grid, see cell()): a 2 m pit, as deep as iron is tall, sits in the row
##   that leads to the battery by the door. Push the near iron north into the pit: it fills it flush and is
##   floor. Push the far iron west over it until the battery stops it: it powers the door. Walk in, stand on
##   the dead launch pad and pull the iron in after you. As it leaves the battery the power goes, but the door
##   stays open while the iron is in the doorway, and the iron stops next to you, between the pad and the
##   room's battery: the pad throws you onto the pillar with the heart.
## Rack ferry (north): a 14 m pit across a walled corridor. A 6 m deck rack sits in it at the near end, with a
##   crank gear on top geared to it. Walk the spider onto the deck and round the crank, and the deck carries it
##   across to the gear that lifts the nook's gate. Your weight pins a rack, so you can't ride along.
## Arm bridge (east): a 14 m chasm. An arm gear on the edge carries a 17 m bridge lying along the bank; a
##   quarter turn (one notch) swings it across to the island with the heart.
## Screws (south-west): a 6 m ledge with two flush screws in front of it. Wind the near one up 2 notches and
##   the one against the ledge up 4, and they're 2 m steps up.
## Gear train (south): the input gear meshes a flush screw (it only rises, so the input only turns one way)
##   and a clutch rack between the input and the gate's gear. One clutch gear between them turns the gate gear
##   the wrong way (against its stop), so nothing moves; wind the crank to slide the clutch over and two gears
##   in a row turn it the right way.

const X0 := 174.0 ## iron room grid
const Z0 := -42.0
const STONE := Color(0.5, 0.48, 0.45)
const WALL := Color(0.42, 0.4, 0.38)
const HOLES := [Rect2(184, -30, 2, 2), Rect2(208, -30, 14, 6)] ## the iron pit and the ferry pit
const SLAB := Rect2(159, -44, 85, 60)

## Ground-level centre of iron room cell (i, j).
static func cell(i: int, j: int) -> Vector3:
	return Vector3(X0 + 1.0 + 2.0 * i, 0.0, Z0 + 1.0 + 2.0 * j)

static func build(lv: Node3D) -> void:
	var marks: Dictionary = lv.marks
	var t: Tuning = lv.t
	var rect := func(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, c: Color) -> StaticBody3D:
		return lv.box(Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0, y1 - y0, z1 - z0), Basis(), c)
	_slab(lv)
	ScaleGarden.basin(lv, HOLES[0], -IronCube.H)
	ScaleGarden.basin(lv, HOLES[1], -2.0)

	lv.label(Vector3(174, 4, 8), "The Works")
	Pickup.spawn(lv, "magnet", 1, Vector3(174, 0.8, 10))
	Pickup.spawn(lv, "lash", 1, Vector3(176, 0.8, 10))
	Pickup.spawn(lv, "spider", 1, Vector3(178, 0.8, 10))
	marks["works_start"] = Vector3(172, 0.6, 8)

	_iron_room(lv, rect)
	_ferry(lv, rect)
	_arm(lv, rect)
	_screws(lv, rect)
	_train(lv, rect)

## The Works floor: a 1 m slab, top at y 0, leaving out HOLES.
static func _slab(lv: Node3D) -> void:
	var xs := _cuts(true)
	var zs := _cuts(false)
	for j in zs.size() - 1:
		var z0: float = zs[j]
		var z1: float = zs[j + 1]
		var run := -1 # solid cells along x merge into one box per row
		for i in xs.size():
			var solid := i < xs.size() - 1
			if solid:
				var mid := Vector2((float(xs[i]) + float(xs[i + 1])) / 2.0, (z0 + z1) / 2.0)
				for h in HOLES:
					solid = solid and not (h as Rect2).has_point(mid)
			if solid and run < 0:
				run = i
			elif not solid and run >= 0:
				var xa: float = xs[run]
				var xb: float = xs[i]
				lv.box(Vector3((xa + xb) / 2.0, -0.5, (z0 + z1) / 2.0), Vector3(xb - xa, 1, z1 - z0), Basis(), Color(0.55, 0.62, 0.5))
				run = -1

## Sorted, de-duplicated edges of the slab and its holes along x (or z).
static func _cuts(along_x: bool) -> Array:
	var v := [SLAB.position.x, SLAB.end.x] if along_x else [SLAB.position.y, SLAB.end.y]
	for h in HOLES:
		var r: Rect2 = h
		v.append(r.position.x if along_x else r.position.y)
		v.append(r.end.x if along_x else r.end.y)
	v.sort()
	var out := []
	for x in v:
		if out.is_empty() or float(x) - float(out[-1]) > 0.01:
			out.append(x)
	return out

static func _iron_room(lv: Node3D, rect: Callable) -> void:
	var marks: Dictionary = lv.marks
	var block := func(i: int, j: int, h: float) -> void:
		lv.box(cell(i, j) + Vector3.UP * h / 2.0, Vector3(2, h, 2), Basis(), Color(0.35, 0.38, 0.45))
	# a 2 m wall round the room's yard: you can jump it, iron can't cross it (open at the south-east corner)
	for i in range(-1, 14):
		block.call(i, -1, 2.0)
		if i < 11:
			block.call(i, 13, 2.0)
	for j in range(0, 13):
		block.call(-1, j, 2.0)
		block.call(13, j, 2.0)
	# the room: cells i 1-5, j 1-4, 4 m walls, the door at (3, 5)
	for i in range(0, 7):
		block.call(i, 0, 4.0)
		if i != 3:
			block.call(i, 5, 4.0)
	for j in range(1, 5):
		block.call(0, j, 4.0)
		block.call(6, j, 4.0)
	var door := Gate.make(lv, cell(3, 5) + Vector3.UP * 2.0, Vector3(2, 4, 2), Color(0.79, 0.64, 0.15))
	door.wire()
	Battery.make(lv, cell(2, 6))
	# inside: the pillar with the heart, the dead pad and its battery
	rect.call(176, 180, -40, -36, 0, 6, Color(0.5, 0.8, 0.8))
	Pickup.spawn(lv, "heart", 1, Vector3(178, 6.8, -38))
	var pad := Pad.make(lv, "launch", cell(3, 1), Vector3(-3.4, 20, 1.1), Vector3(2, 1, 2), true)
	Battery.make(lv, cell(4, 2))
	# the pit, and the two irons
	var filler := IronCube.make(lv, cell(5, 10))
	var iron := IronCube.make(lv, cell(9, 6))
	lv.label(cell(5, 7) + Vector3.UP * 2.5, "iron fills a pit it fits", 40)
	lv.label(cell(3, 7) + Vector3.UP * 4.5, "a powered door stays open while something stands in it", 32)
	marks["works_iron"] = cell(7, 11) + Vector3.UP * 0.6
	marks["works_iron_fill"] = filler
	marks["works_iron_a"] = iron
	marks["works_push_fill"] = cell(5, 12) + Vector3.UP * 0.6
	marks["works_push_a"] = cell(12, 6) + Vector3.UP * 0.6
	marks["works_pit"] = cell(5, 6)
	marks["works_door"] = door
	marks["works_room_pad"] = pad
	marks["works_pad_stand"] = cell(3, 1) + Vector3.UP * 0.6
	marks["works_pillar_y"] = 6.0

static func _ferry(lv: Node3D, rect: Callable) -> void:
	var marks: Dictionary = lv.marks
	var t: Tuning = lv.t
	# corridor z -30..-24 from x 154 to the end wall at 177; the pit is x 158..172
	rect.call(204, 223.5, -31, -30, 0, 4, WALL)
	rect.call(225.5, 228, -31, -30, 0, 4, WALL)
	rect.call(204, 228, -24, -23, 0, 4, WALL)
	rect.call(227, 228, -30, -24, 0, 4, WALL)
	# the nook behind the gate, walled high
	rect.call(221.5, 223.5, -36, -31, 0, 6, WALL)
	rect.call(225.5, 227.5, -36, -31, 0, 6, WALL)
	rect.call(221.5, 227.5, -37, -36, 0, 6, WALL)
	Pickup.spawn(lv, "heart", 1, Vector3(224.5, 0.8, -33.5))
	var gate := Gate.make(lv, Vector3(224.5, 2, -30.5), Vector3(2, 4, 1), Color(0.6, 0.45, 0.25))
	var far_gear := Gear.make(lv, Vector3(224.5, 0, -27), 1.0, gate, Vector3.UP * 4.0, t)
	# the deck: a rack that fills the corridor's width, flush with the banks, with a crank gear riding it
	var deck := Rack.make(lv, Vector3(211, 0, -27), Vector3.RIGHT, 6.0, 5.9, 8.0)
	var crank := Gear.cog(lv, Vector3(211, 0, -27), 1.0, t)
	deck.riders.append(crank)
	Machinery.link(crank, deck, t.crank_ratio)
	lv.label(Vector3(206, 3.5, -27), "walk the spider round the deck's crank: the rack carries it across", 32)
	marks["works_ferry"] = Vector3(205.5, 0.6, -27)
	marks["works_deck"] = deck
	marks["works_crank"] = crank
	marks["works_ferry_gear"] = far_gear
	marks["works_ferry_gate"] = gate

static func _arm(lv: Node3D, _rect: Callable) -> void:
	var marks: Dictionary = lv.marks
	var t: Tuning = lv.t
	# the slab ends at x 194: a 14 m chasm, then the island
	lv.box(Vector3(262, -0.5, -20), Vector3(8, 1, 16), Basis(), STONE)
	Pickup.spawn(lv, "heart", 1, Vector3(262, 0.8, -20))
	ShadowHall.pit(lv, Vector3(251, -12, -14), Vector3(14, 2, 64), Vector3(240, 0.6, -24))
	var arm := ArmGear.make_arm(lv, Vector3(242.8, 0, -20), 1.0, Vector3.BACK, 17.0, 3.0, t)
	lv.label(Vector3(240, 3.5, -24), "the spider turns the arm gear: a notch swings the bridge a quarter turn", 32)
	marks["works_arm"] = arm
	marks["works_arm_stand"] = Vector3(239, 0.6, -24)
	marks["works_island_x"] = 258.0

static func _screws(lv: Node3D, rect: Callable) -> void:
	var marks: Dictionary = lv.marks
	var t: Tuning = lv.t
	rect.call(180, 196, -12, -4, 0, 6, STONE)
	Pickup.spawn(lv, "heart", 1, Vector3(188, 6.8, -8))
	var high := Screw.make_screw(lv, Vector3(188, 0, -2.5), 1.5, t.screw_notch, 4, 0, t)
	var low := Screw.make_screw(lv, Vector3(188, 0, 1.5), 1.5, t.screw_notch, 2, 0, t)
	lv.label(Vector3(188, 3.0, 5), "screws: the spider winds them up a notch at a time", 32)
	marks["works_screws"] = Vector3(184, 0.6, 4)
	marks["works_screw_low"] = low
	marks["works_screw_high"] = high
	marks["works_ledge_y"] = 6.0

static func _train(lv: Node3D, rect: Callable) -> void:
	var marks: Dictionary = lv.marks
	var t: Tuning = lv.t
	# the gate's room: x 171..177, z -6..0, the gate in its west wall
	rect.call(220, 221, -7, -4, 0, 6, WALL)
	rect.call(220, 221, -2, 1, 0, 6, WALL)
	rect.call(227, 228, -7, 1, 0, 6, WALL)
	rect.call(221, 227, -7, -6, 0, 6, WALL)
	rect.call(221, 227, 0, 1, 0, 6, WALL)
	Pickup.spawn(lv, "heart", 1, Vector3(224, 0.8, -3))
	var gate := Gate.make(lv, Vector3(220.5, 2, -3), Vector3(1, 4, 2), Color(0.6, 0.45, 0.25))
	var input := Gear.cog(lv, Vector3(210, 0, 2), 1.0, t)
	var lock := Screw.make_screw(lv, Vector3(208, 0, 2), 1.0, 0.5, 6, 0, t)
	var out := Gear.make(lv, Vector3(214, 0, 2), 1.0, gate, Vector3.UP * 4.0, t)
	# the clutch: a rack running south carrying one gear between input and output, and two more north of them.
	# Slid 2.27 m (a crank on the east side drives it), the pair bridges input and output instead.
	var clutch := Rack.make(lv, Vector3(212, 0.03, 0), Vector3.BACK, 6.0, 1.0, 4.0 - sqrt(3.0))
	for at in [Vector3(212, 0, 2), Vector3(211, 0, -2), Vector3(213, 0, -2)]:
		var g := Gear.cog(lv, at, 1.0, t)
		clutch.riders.append(g)
	var crank := Gear.cog(lv, Vector3(218, 0, 8), 1.0, t)
	Machinery.link(crank, clutch, t.crank_ratio)
	lv.label(Vector3(212, 3.5, 6), "meshed gears turn opposite ways: count the gears between", 32)
	lv.label(Vector3(218, 2.5, 8), "clutch crank", 32)
	marks["works_train"] = Vector3(210, 0.6, 7)
	marks["works_train_in"] = input
	marks["works_train_out"] = out
	marks["works_train_lock"] = lock
	marks["works_clutch"] = clutch
	marks["works_clutch_crank"] = crank
	marks["works_train_gate"] = gate
