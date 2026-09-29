class_name ShadowHall
extends RefCounted
## The Ember & Umbra wing: a roofed, dark hall up a ramp behind the start, x -12..8, z 61..121, floor at y 4.
## Room A (z 61-76): the candle hat. Burn the vine wall, walk the candle through the grass, melt the ice
##   around the brazier and light it to open the gate.
## Room B (z 76-96): Umbra. The ledge with the moon plate is across a dark chasm. Take the hat off, call
##   Umbra, and walk away from the chasm: mirrored, it drifts over the chasm to the plate.
## Room C (z 96-116): your shadow. A lantern lights this chasm, so Umbra can only cross inside your shadow.
##   Stand on the lantern's line at the railing with the hat off, face across, call Umbra in front of you and
##   keep pushing forward: the railing holds you while Umbra drifts on across, inside your shadow.
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
	rect.call(-12, 8, 94, 100, 0, FLOOR, STONE)
	rect.call(4, 8, 100, 110, 0, FLOOR, STONE) # room C walkway
	rect.call(-12, 8, 110, 121, 0, FLOOR, STONE)

	# shell: side walls, roof, south wall with the door, north wall with the way out
	rect.call(-12.5, -12, 60.5, 121.5, FLOOR, ROOF, WALL)
	rect.call(8, 8.5, 60.5, 121.5, FLOOR, ROOF, WALL)
	rect.call(-12.5, 8.5, 60.5, 121.5, ROOF, ROOF + 0.5, WALL)
	_cross_wall(rect, 61, -2, 2, false)
	_cross_wall(rect, 121, 2, 6, false)

	# Room A
	Burnable.make(lv, "vines", Vector3(-2, FLOOR, 65), Vector3(20, ROOF - FLOOR, 0.6))
	lv.label(Vector3(0, FLOOR + 3, 63), "wear the hat (put it on a quick slot)", 28)
	for gx in 4:
		for gz in 3:
			Burnable.make(lv, "grass", Vector3(-3 + gx * 2, FLOOR, 68 + gz * 2), Vector3(2, 0.3, 2))
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
	_pit(lv, Vector3(-6, 0, 87), Vector3(12, 1.5, 14), Vector3(4, FLOOR + 0.6, 78))
	marks["hall_b"] = Vector3(0.8, FLOOR + 0.6, 86)
	marks["hall_b_plate"] = plate_b
	marks["hall_b_gate"] = gate_b

	# Room C: the lantern lights the chasm x -12..4, z 100..110. Umbra can only cross it in your shadow.
	# The moon plate sits in a walled bay; bars close its side toward the lantern. Light and Umbra pass bars, you don't.
	rect.call(-12, -2, 113.5, 114, FLOOR, ROOF, WALL)
	rect.call(-2.5, -2, 110, 113.5, FLOOR, ROOF, WALL)
	fence(lv, Vector3(-7.25, FLOOR, 110.1), Vector3(9.5, ROOF - FLOOR, 0.1))
	var lantern := Brazier.make(lv, Vector3(-6, FLOOR, 97.5), true, 0.5)
	var line := MeshInstance3D.new() # a dark inlay on the floor marks the lantern's line
	var lm := BoxMesh.new()
	lm.size = Vector3(0.3, 0.02, 2.2)
	line.mesh = lm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.1, 0.2)
	line.material_override = m
	lv.add_child(line)
	line.global_position = Vector3(-6, FLOOR + 0.01, 98.9)
	fence(lv, Vector3(-4, FLOOR, 100), Vector3(16, 1.1, 0.1))
	var plate_c := MoonPlate.make(lv, Vector3(-6, FLOOR, 111.8), Vector3(3.5, 0.1, 3.3))
	var gate_c := _cross_wall(rect, 116, 2, 6, true)
	plate_c.pressed.connect(gate_c.open)
	lv.label(Vector3(-4, FLOOR + 3, 99), "in your shadow it floats", 28)
	_pit(lv, Vector3(-4, 0, 105), Vector3(16, 1.5, 10), Vector3(4, FLOOR + 0.6, 98))
	Pickup.spawn(lv, "heart", 1, Vector3(4, FLOOR + 0.8, 119))
	marks["hall_c"] = Vector3(-6, FLOOR + 0.6, 99) # on the lantern line, just short of the railing
	marks["hall_c_plate"] = plate_c
	marks["hall_c_gate"] = gate_c
	marks["hall_lantern"] = lantern

## A railing or bars: it stops you (and anything else on collision layer 2's mask) but light and Umbra pass through it.
## pos is the middle of its base.
static func fence(parent: Node, pos: Vector3, size: Vector3) -> StaticBody3D:
	var b := StaticBody3D.new()
	b.collision_layer = 1 << 1
	b.collision_mask = 0
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	c.position.y = size.y / 2.0
	b.add_child(c)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.24, 0.3)
	mat.metallic = 0.6
	var long := size.x >= size.z
	var length := maxf(size.x, size.z)
	var rail := MeshInstance3D.new()
	var rm := BoxMesh.new()
	rm.size = Vector3(size.x, 0.08, size.z)
	rail.mesh = rm
	rail.material_override = mat
	rail.position.y = size.y - 0.04
	b.add_child(rail)
	var n := int(length / 0.8)
	for k in n + 1:
		var post := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(0.06, size.y, 0.06)
		post.mesh = pm
		post.material_override = mat
		var along := -length / 2.0 + length * float(k) / float(maxi(n, 1))
		post.position = Vector3(along if long else 0.0, size.y / 2.0, 0.0 if long else along)
		b.add_child(post)
	parent.add_child(b)
	b.global_position = pos
	return b

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
static func _pit(lv: Node3D, centre: Vector3, size: Vector3, back_to: Vector3) -> void:
	var a := Area3D.new()
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	a.add_child(c)
	lv.add_child(a)
	a.global_position = centre + Vector3.UP * size.y / 2.0
	a.body_entered.connect(func(b):
		if b is Player:
			b.global_position = back_to
			b.velocity = Vector3.ZERO)
