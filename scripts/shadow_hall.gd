class_name ShadowHall
extends RefCounted
## The Ember & Umbra wing: a roofed, dark hall up a ramp behind the start, x -12..8, z 61..121, floor at y 4.
## Room A (z 61-76): the candle hat. Burn the vine wall, walk the candle through the grass, melt the ice
##   around the brazier and light it to open the gate.
## Room B (z 76-96): Umbra. The ledge with the moon plate is across a dark chasm. Take the hat off, call
##   Umbra, and walk away from the chasm: mirrored, it drifts over the chasm to the plate.
## Room C (z 96-116): your shadow. A lantern lights this chasm, so Umbra can only cross inside your shadow.
##   Stand on the lantern's line with the hat off, then walk toward the lantern and keep pushing.
## Fall into a chasm and you're put back at the room's entrance.

const FLOOR := 4.0
const ROOF := 10.0
const WALL := Color(0.3, 0.32, 0.42)
const STONE := Color(0.42, 0.42, 0.5)

static func build(lv: Node3D) -> void:
	var marks: Dictionary = lv.marks
	var rect := func(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, c: Color) -> StaticBody3D:
		return lv.box(Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0, y1 - y0, z1 - z0), Basis(), c)

	# ramp up from the ground to the door
	var a := atan2(FLOOR, 13.0)
	var L := sqrt(FLOOR * FLOOR + 13.0 * 13.0)
	lv.box(Vector3(0, L / 2.0 * sin(a) - 0.25 * cos(a), 48.0 + L / 2.0 * cos(a)), Vector3(4, 0.5, L), Basis(Vector3.RIGHT, -a), STONE)
	lv.label(Vector3(0, 3.5, 44), "Ember & Umbra")
	Pickup.spawn(lv, "candle", 1, Vector3(0, 0.8, 42))
	lv.label(Vector3(0, 2.4, 42), "candle hat")
	marks["hall_ramp"] = Vector3(0, 0.6, 40)

	# floors (the gaps between them are the chasms, 4 m deep)
	rect.call(-12, 8, 61, 80, 0, FLOOR, STONE) # entry, room A, start of room B
	rect.call(0, 8, 80, 94, 0, FLOOR, STONE) # room B walkway
	rect.call(-12, -8, 85, 89, 0, FLOOR, STONE) # room B ledge
	rect.call(-12, 8, 94, 98, 0, FLOOR, STONE)
	rect.call(0, 8, 98, 114, 0, FLOOR, STONE) # room C walkway
	rect.call(-12, -6, 104, 108, 0, FLOOR, STONE) # room C ledge
	rect.call(-12, 8, 114, 121, 0, FLOOR, STONE)

	# shell: side walls, roof, south wall with the door, north wall with the way out
	rect.call(-12.5, -12, 60.5, 121.5, FLOOR, ROOF, WALL)
	rect.call(8, 8.5, 60.5, 121.5, FLOOR, ROOF, WALL)
	rect.call(-12.5, 8.5, 60.5, 121.5, ROOF, ROOF + 0.5, WALL)
	_cross_wall(rect, 61, -2, 2, false)
	_cross_wall(rect, 121, 2, 6, false)

	# Room A
	Burnable.make(lv, "vines", Vector3(-2, FLOOR, 65), Vector3(20, ROOF - FLOOR, 0.6))
	lv.label(Vector3(0, FLOOR + 3, 63), "wear the hat (put it on a quick slot)", 28)
	Burnable.field(lv, Vector3(-4, FLOOR, 67), 8, 6) # 1 m patches: the fire visibly walks across
	var brazier_a := Brazier.make(lv, Vector3(5, FLOOR, 72))
	IceBlock.make(lv, Vector3(5, FLOOR, 72), Vector3(2.2, 2, 2.2))
	var gate_a := _cross_wall(rect, 76, 0, 4, true)
	brazier_a.lit_up.connect(gate_a.open)
	marks["hall_a_gate"] = gate_a
	marks["hall_a"] = Vector3(0, FLOOR + 0.6, 62.5)
	marks["hall_vines"] = 65.0
	marks["hall_grass_far"] = Vector3(3, FLOOR, 72)
	marks["hall_brazier"] = Vector3(5, FLOOR + 0.6, 69.5)

	# Room B: dark chasm x -12..0, z 80..94, with the moon plate ledge across it
	Pickup.spawn(lv, "umbra", 1, Vector3(4, FLOOR + 0.8, 78))
	lv.label(Vector3(4, FLOOR + 2.4, 78), "Umbra (Enter: put it on a quick slot)", 28)
	rect.call(-12, -8, 84.5, 85, FLOOR, FLOOR + 2.0, WALL)
	rect.call(-12, -8, 89, 89.5, FLOOR, FLOOR + 2.0, WALL)
	var plate_b := MoonPlate.make(lv, Vector3(-10, FLOOR, 87), Vector3(3.5, 0.1, 3.5))
	var gate_b := _cross_wall(rect, 96, 2, 6, true)
	plate_b.pressed.connect(gate_b.open)
	lv.label(Vector3(4, FLOOR + 3, 87), "in the dark Umbra floats", 28)
	pit(lv, Vector3(-6, 0, 87), Vector3(12, 1.5, 14), Vector3(4, FLOOR + 0.6, 78))
	marks["hall_b"] = Vector3(0.8, FLOOR + 0.6, 87)
	marks["hall_b_plate"] = plate_b
	marks["hall_b_gate"] = gate_b

	# Room C: the lantern lights the chasm x -12..0, z 98..114. Umbra can only cross in your shadow.
	rect.call(-12, -6, 103.5, 104, FLOOR, FLOOR + 2.0, WALL)
	rect.call(-12, -6, 108, 108.5, FLOOR, FLOOR + 2.0, WALL)
	var lantern := Brazier.make(lv, Vector3(7.4, FLOOR, 106), true, 0.5)
	var line := MeshInstance3D.new() # a dark inlay on the floor marks the lantern's line
	var lm := BoxMesh.new()
	lm.size = Vector3(6.5, 0.02, 0.3)
	line.mesh = lm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.1, 0.2)
	line.material_override = m
	lv.add_child(line)
	line.global_position = Vector3(3.6, FLOOR + 0.01, 106)
	var plate_c := MoonPlate.make(lv, Vector3(-9.5, FLOOR, 106), Vector3(3.5, 0.1, 3.5))
	var gate_c := _cross_wall(rect, 116, 2, 6, true)
	plate_c.pressed.connect(gate_c.open)
	lv.label(Vector3(4, FLOOR + 3, 101), "in your shadow it floats", 28)
	pit(lv, Vector3(-6, 0, 106), Vector3(12, 1.5, 16), Vector3(4, FLOOR + 0.6, 99))
	Pickup.spawn(lv, "heart", 1, Vector3(4, FLOOR + 0.8, 119))
	marks["hall_c"] = Vector3(0.8, FLOOR + 0.6, 106)
	marks["hall_c_plate"] = plate_c
	marks["hall_c_gate"] = gate_c
	marks["hall_lantern"] = lantern

## A wall across the hall at z, floor to roof, with a 4 m high doorway from x d0 to d1.
## With gated, bars fill the doorway; returns the Gate.
static func _cross_wall(rect: Callable, z: float, d0: float, d1: float, gated: bool) -> Gate:
	rect.call(-12, d0, z - 0.25, z + 0.25, FLOOR, ROOF, WALL)
	rect.call(d1, 8, z - 0.25, z + 0.25, FLOOR, ROOF, WALL)
	var lintel: StaticBody3D = rect.call(d0, d1, z - 0.25, z + 0.25, FLOOR + 4.0, ROOF, WALL)
	if not gated:
		return null
	return Gate.make(lintel.get_parent(), Vector3((d0 + d1) / 2.0, FLOOR + 2.0, z), Vector3(d1 - d0, 4.0, 0.3), Color(0.2, 0.2, 0.25))

## The floor of a chasm: land here and you're put back at back_to.
static func pit(lv: Node3D, centre: Vector3, size: Vector3, back_to: Vector3) -> void:
	var a := Area3D.new()
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	a.add_child(c)
	lv.add_child(a)
	a.global_position = centre + Vector3.UP * size.y / 2.0
	var box := AABB(a.global_position - size / 2.0, size).grow(0.6)
	a.body_entered.connect(func(b):
		if b is Player and box.has_point(b.global_position): # a late signal must not yank you from elsewhere
			b.global_position = back_to
			b.velocity = Vector3.ZERO)
