class_name Rootworks
extends RefCounted
## Rootworks: Winch and Propagule in one wing, north-east of the monster arena (x 36..84, z 34..112).
## The lash and the clockwork spider lie at the foot of the ramp. Floors are 6 m up, above any triple jump.
## Root bridge (south): a 14 m chasm, too far to jump. Plant the seed on the soil at the edge and its root
##   grows straight across as a bridge.
## Lash ledge (north-west): a seed sits on a 4.5 m ledge. Lock on to it and lash it down, plant it in the mud
##   at the ledge's foot, and climb the trunk to the heart on top. (Drop a seed 3 m onto mud and it plants itself.)
## Lash post (north-west): a second 14 m chasm with a post on the far side. Lock on and lash it to be pulled across.
## Gear room (on the ground, west): bars you can't pass split the room, and a gear behind them lifts the gate
##   to the nook. Stand by the bars and steer the spider through them, past the gear's north side: every metre
##   of cable that slides past turns it. The gear keeps its angle when you let go, so it can be wound over trips.

const H := 6.0 ## floor height
const STONE := Color(0.55, 0.5, 0.42)
const SOIL := Color(0.4, 0.28, 0.16)
const MUD := Color(0.3, 0.24, 0.18)

static func build(lv: Node3D) -> void:
	var marks: Dictionary = lv.marks
	var t: Tuning = lv.t
	var rect := func(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, c: Color) -> StaticBody3D:
		return lv.box(Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0, y1 - y0, z1 - z0), Basis(), c)

	lv.label(Vector3(68, 4, 36), "Rootworks")
	Pickup.spawn(lv, "lash", 1, Vector3(64, 0.8, 36))
	lv.label(Vector3(64, 2.4, 36), "lash", 40)
	Pickup.spawn(lv, "spider", 1, Vector3(72, 0.8, 36))
	lv.label(Vector3(72, 2.4, 36), "clockwork spider", 40)
	marks["root_ramp"] = Vector3(68, 0.6, 34)

	# ramp up to plateau A: 6 m over 24 m
	var a := atan2(H, 24.0)
	var L := sqrt(H * H + 24.0 * 24.0)
	lv.box(Vector3(68, L / 2.0 * sin(a) - 0.25 * cos(a), 40.0 + L / 2.0 * cos(a)), Vector3(4, 0.5, L), Basis(Vector3.RIGHT, -a), STONE)

	# Root bridge: plateau A with a soil strip at its north edge, a 14 m chasm, plateau B1
	rect.call(60, 66, 64, 76, 0, H, STONE)
	rect.call(70, 76, 64, 76, 0, H, STONE)
	rect.call(66, 70, 64, 74, 0, H, STONE)
	var soil: StaticBody3D = rect.call(66, 70, 74, 76, 0, H, SOIL)
	soil.add_to_group("soil")
	Seed.make(lv, Vector3(63, H + 0.4, 68), t)
	lv.label(Vector3(68, H + 2.0, 75), "plant a seed on soil", 32)
	marks["root_seed"] = Vector3(63, H + 0.6, 70)
	marks["root_soil"] = Vector3(68, H + 0.6, 73.2)
	marks["root_far"] = Vector3(68, H + 0.6, 93)

	# B1, with the 4.5 m ledge and the mud at its foot
	rect.call(60, 84, 90, 98, 0, H, STONE)
	rect.call(68, 84, 98, 112, 0, H, STONE)
	var mud: StaticBody3D = rect.call(60, 68, 98, 104, 0, H, MUD)
	mud.add_to_group("mud")
	rect.call(60, 68, 104, 112, 0, H + 4.5, STONE)
	Seed.make(lv, Vector3(64, H + 4.9, 104.6), t)
	Pickup.spawn(lv, "heart", 1, Vector3(64, H + 5.3, 109))
	lv.label(Vector3(72, H + 2.0, 100), "lock on and lash the seed down", 32)
	marks["root_c_stand"] = Vector3(64, H + 0.6, 94)
	marks["root_mud"] = Vector3(64, H + 0.6, 99)
	marks["root_c_top"] = H + 4.5

	# Lash post: a 14 m chasm x 46..60 west of B1, B2 beyond with a post near its edge
	rect.call(36, 46, 90, 112, 0, H, STONE)
	var post: StaticBody3D = lv.box(Vector3(44.8, H + 1.5, 94), Vector3(0.5, 3.0, 0.5), Basis(), Color(0.5, 0.35, 0.25))
	post.add_to_group("lash_posts")
	post.add_to_group("targets")
	lv.label(Vector3(44.8, H + 4.0, 94), "lash the post", 32)
	marks["root_post_stand"] = Vector3(60.8, H + 0.6, 94)
	marks["root_post"] = post
	marks["root_b2_x"] = 46.0

	# Gear room, on the ground: x 36..58, z 56..76, walls 4 m, doorway west at z 64..68
	var wall := Color(0.45, 0.42, 0.4)
	rect.call(36, 58, 55.5, 56, 0, 4, wall)
	rect.call(57.5, 58, 56, 76, 0, 4, wall)
	rect.call(35.5, 36, 55.5, 64, 0, 4, wall)
	rect.call(35.5, 36, 68, 76, 0, 4, wall)
	rect.call(35.5, 40, 76, 76.5, 0, 4, wall)
	rect.call(44, 58, 76, 76.5, 0, 4, wall)
	# the nook behind the gate
	rect.call(35.5, 36, 76.5, 82, 0, 4, wall)
	rect.call(44, 44.5, 76.5, 82, 0, 4, wall)
	rect.call(35.5, 44.5, 82, 82.5, 0, 4, wall)
	Pickup.spawn(lv, "heart", 1, Vector3(40, 0.8, 79.5))
	# bars across the room at x 47: you can't pass, the spider can
	for k in 20:
		var bar := StaticBody3D.new()
		bar.collision_layer = 1 << 1
		var bc := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(0.15, 3.0, 0.15)
		bc.shape = bs
		bar.add_child(bc)
		var bmi := MeshInstance3D.new()
		var bmm := BoxMesh.new()
		bmm.size = bs.size
		bmi.mesh = bmm
		bar.add_child(bmi)
		lv.add_child(bar)
		bar.global_position = Vector3(47, 1.5, 56.5 + k * 1.0)
	var rail := StaticBody3D.new() # a tall rail over the bars, so you can't hop over
	rail.collision_layer = 1 << 1
	var rc := CollisionShape3D.new()
	var rs := BoxShape3D.new()
	rs.size = Vector3(0.3, 3.0, 20)
	rc.shape = rs
	rail.add_child(rc)
	lv.add_child(rail)
	rail.global_position = Vector3(47, 4.5, 66)
	var gate := Gate.make(lv, Vector3(42, 2, 76.25), Vector3(4, 4, 0.5), Color(0.6, 0.45, 0.25))
	var gear := Gear.make(lv, Vector3(52, 0, 62), 1.0, gate, Vector3.UP * 4.0, t)
	lv.label(Vector3(42, 3, 66), "steer the spider past the gear", 32)
	marks["root_gear_room"] = Vector3(40, 0.6, 66)
	marks["root_gear_stand"] = Vector3(46.2, 0.6, 63.5)
	marks["root_gate"] = gate
	marks["root_gear"] = gear
