class_name LodestoneYard
extends RefCounted
## The Lodestone yard, east of the ramps: a 2 m grid from x 52, z -34 (cells i 0-12 east, j 0-13 south).
## You're a magnet once you pick it up (south of the yard). Iron slides cell by cell along the grid.
## Door (west): a powered door in a walled room. Pull the iron into the cell between the battery and the door.
## Launch (middle): a dead launch pad under a 6 m block. Push the iron north until the battery stops it,
##   touching the pad, and the pad comes alive.
## Boost (east): stand on the dead boost pad and pull the iron along the south row until it stops next to you,
##   between the pad and its battery. The pad fires you over a kicker and across a 14 m gap to a 3 m ledge,
##   too far for a running jump.

const X0 := 52.0
const Z0 := -34.0

## Ground-level centre of cell (i, j).
static func cell(i: int, j: int) -> Vector3:
	return Vector3(X0 + 1.0 + 2.0 * i, 0.0, Z0 + 1.0 + 2.0 * j)

static func build(lv: Node3D) -> void:
	var marks: Dictionary = lv.marks
	var wall := Color(0.35, 0.38, 0.45)
	var block := func(i: int, j: int, h: float) -> void:
		lv.box(cell(i, j) + Vector3.UP * h / 2.0, Vector3(2, h, 2), Basis(), wall)
	lv.label(Vector3(65, 4, -2), "Lodestone")
	Pickup.spawn(lv, "magnet", 1, Vector3(65, 0.8, -1))
	lv.label(Vector3(65, 2.4, -1), "magnet: - pulls, + pushes", 40)
	marks["yard_magnet"] = Vector3(65, 0.6, 1)

	# a 2 m wall round the yard (the door room's own walls cover its corner): you can jump it, iron can't cross it
	for i in range(-1, 14):
		block.call(i, 14, 2.0)
		if i > 5 and (i < 10 or i > 12) and not (i == 7 or i == 8):
			block.call(i, -1, 2.0)
	for j in range(6, 14):
		block.call(-1, j, 2.0)
	for j in range(-1, 14):
		block.call(13, j, 2.0)

	# Door room: cells i 0-4, j 0-4, closed by row j 5 and column i 5, door at (2, 5)
	for j in range(-1, 6):
		block.call(-1, j, 4.0)
	for i in range(0, 6):
		block.call(i, -1, 4.0)
	for i in [0, 1, 3, 4]:
		block.call(i, 5, 4.0)
	for j in range(0, 6):
		block.call(5, j, 4.0)
	var door := Gate.make(lv, cell(2, 5) + Vector3.UP * 2.0, Vector3(2, 4, 2), Color(0.79, 0.64, 0.15))
	door.wire()
	Battery.make(lv, cell(2, 7))
	var iron_a := IronCube.make(lv, cell(5, 6))
	Pickup.spawn(lv, "heart", 1, cell(2, 2) + Vector3.UP * 0.8)
	lv.label(cell(2, 8) + Vector3.UP * 3.0, "power the door", 40)
	marks["yard_door"] = door
	marks["yard_iron_a"] = iron_a
	marks["yard_pull_a"] = cell(1, 6) + Vector3.UP * 0.6 # stand here and the iron stops in the gap

	# Launch: dead pad (7, 3) under the 6 m block on (7-8, 0-1); battery (8, 2) is the stop
	lv.box(Vector3(68, 3, -32), Vector3(4, 6, 4), Basis(), Color(0.5, 0.8, 0.8))
	Battery.make(lv, cell(8, 2))
	var pad := Pad.make(lv, "launch", cell(7, 3), Vector3(0, 20, -5.5), Vector3(2, 1, 2), true)
	var iron_b := IronCube.make(lv, cell(8, 7))
	Pickup.spawn(lv, "potion", 1, Vector3(68, 6.8, -32))
	lv.label(cell(7, 4) + Vector3.UP * 3.0, "dead launch pad", 40)
	marks["yard_launch"] = pad
	marks["yard_iron_b"] = iron_b
	marks["yard_push_b"] = cell(8, 10) + Vector3.UP * 0.6

	# Boost: dead pad (11, 13) facing north onto a 30° kicker, then a 14 m gap to a 3 m ledge; battery (10, 12)
	var boost := Pad.make(lv, "boost", cell(11, 13), Vector3.FORWARD, Vector3(2, 1, 2), true)
	var a := deg_to_rad(30.0)
	var kick := 3.0
	var run := kick / tan(a)
	var L := kick / sin(a)
	lv.box(Vector3(75.5, L / 2.0 * sin(a) - 0.25 * cos(a), -8.0 - L / 2.0 * cos(a)), Vector3(3, 0.5, L), Basis(Vector3.RIGHT, a), Color(0.85, 0.6, 0.45))
	var lip := -8.0 - run
	var h := 3.0
	var far := lip - 14.0
	lv.box(Vector3(75.5, h / 2.0, (far - 44.0) / 2.0), Vector3(5, h, far + 44.0), Basis(), Color(0.5, 0.8, 0.8))
	Battery.make(lv, cell(10, 12))
	var iron_c := IronCube.make(lv, cell(5, 13))
	Pickup.spawn(lv, "heart", 1, Vector3(75.5, h + 0.8, far - 4.0))
	lv.label(cell(11, 13) + Vector3.UP * 3.0, "dead boost pad", 40)
	marks["yard_boost"] = boost
	marks["yard_iron_c"] = iron_c
	marks["yard_boost_stand"] = cell(11, 13) + Vector3.UP * 0.6
	marks["yard_ledge_y"] = h
	marks["yard_kicker_lip"] = lip
