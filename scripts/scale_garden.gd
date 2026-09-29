class_name ScaleGarden
extends RefCounted
## The Scale garden, west of the gap course (x -100..-55, z 36..112). Shrink (a quick-slot toggle) is at its gate.
## Grate room (east): a grate door only small you fit through, a cracked floor your normal weight breaks,
##   and a cracked wall only a normal-size roll bursts. Cross small, grow on the solid island, roll through.
## Pond (west): 16 m of deep water between walls. Normal you sink; small you float across. On the island a cracked
##   cover seals a fan vent next to an 8 m tower: grow to break the cover with your weight, drop in, shrink,
##   and the updraft lifts you to the top.
## Ferry (north-west, needs the magnet from the Lodestone yard): a 16 m chasm. Small, the magnet flies you along
##   an iron's line, but only 22 m from it. The iron starts too far back: at normal size pull it up to you at the
##   edge, then shrink and push yourself across. Pull brings you back.

const GROUND_HOLES := [Rect2(-98, 52, 12, 16), Rect2(-94, 45, 2, 2), Rect2(-96, 84, 12, 16)]
const WALL := Color(0.45, 0.42, 0.36)
const STONE := Color(0.6, 0.58, 0.5)

static func build(lv: Node3D) -> void:
	var marks: Dictionary = lv.marks
	var rect := func(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, c: Color) -> StaticBody3D:
		return lv.box(Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0, y1 - y0, z1 - z0), Basis(), c)

	lv.label(Vector3(-58, 4, 40), "Scale")
	Pickup.spawn(lv, "shrink", 1, Vector3(-58, 0.8, 42))
	lv.label(Vector3(-58, 2.4, 42), "shrink", 40)
	marks["garden_shrink"] = Vector3(-58, 0.6, 45)

	# Grate room: floor 2 m up on a plinth, x -70..-60, z 46..56, door (a 1 m thick grate) at the south, ramp up to it
	var fl := 2.0
	rect.call(-70, -60, 54, 56, 0, fl, STONE) # entry strip
	rect.call(-70, -60, 46, 50, 0, fl, STONE) # the island and the prize nook behind the cracked wall
	rect.call(-70.5, -70, 45.5, 56.5, 0, 5.5, WALL)
	rect.call(-60, -59.5, 45.5, 56.5, 0, 5.5, WALL)
	rect.call(-70.5, -59.5, 45.5, 46, 0, 5.5, WALL)
	rect.call(-70.5, -66, 56, 56.5, 0, 5.5, WALL)
	rect.call(-64, -59.5, 56, 56.5, 0, 5.5, WALL)
	rect.call(-66, -64, 56, 56.5, 0, fl, WALL)
	rect.call(-66, -64, 56, 56.5, fl + 2.5, 5.5, WALL)
	rect.call(-70.5, -59.5, 45.5, 56.5, 5.5, 6.0, WALL) # roof
	Grate.make(lv, Vector3(-65, fl, 56.25), Vector3(2, 2.5, 1.0))
	var a := atan2(fl, 7.5)
	var L := sqrt(fl * fl + 7.5 * 7.5)
	lv.box(Vector3(-65, L / 2.0 * sin(a) - 0.25 * cos(a), 64.0 - L / 2.0 * cos(a)), Vector3(4, 0.5, L), Basis(Vector3.RIGHT, a), STONE)
	for cx in [-69, -67, -65, -63, -61]:
		for cz in [51, 53]:
			CrackedFloor.make(lv, Vector3(cx, fl, cz))
	rect.call(-70, -66, 47.75, 48.25, fl, 5.5, WALL)
	rect.call(-64, -60, 47.75, 48.25, fl, 5.5, WALL)
	rect.call(-66, -64, 47.75, 48.25, fl + 2.5, 5.5, WALL)
	var cracked := CrackedWall.make(lv, Vector3(-65, fl, 48), Vector3(2, 2.5, 0.5))
	Pickup.spawn(lv, "heart", 1, Vector3(-65, fl + 0.8, 46.9))
	ShadowHall.pit(lv, Vector3(-65, 0, 52), Vector3(10, 1.0, 4), Vector3(-65, 0.6, 66))
	var lamp := OmniLight3D.new() # it's roofed; a lamp so you can see the cracks
	lamp.omni_range = 9.0
	lamp.light_energy = 0.8
	lv.add_child(lamp)
	lamp.global_position = Vector3(-65, 5.0, 51)
	lv.label(Vector3(-65, 4.5, 66), "grate room", 40)
	marks["garden_grate_ramp"] = Vector3(-65, 0.6, 66)
	marks["garden_grate_in"] = Vector3(-65, fl + 0.6, 55) # just inside the grate
	marks["garden_grate_mid"] = Vector3(-65, fl + 0.6, 52) # on the cracked floor
	marks["garden_grate_island"] = Vector3(-65, fl + 0.6, 49)
	marks["garden_grate_door"] = Vector3(-65, fl + 0.3, 56.25)
	marks["garden_cracked_wall"] = cracked

	# Pond: x -98..-86, z 52..68 of deep water between 6 m walls; the island z 44..52 beyond it
	basin(lv, Rect2(-98, 52, 12, 16), -3.0)
	Water.make(lv, AABB(Vector3(-98, -3, 52), Vector3(12, 2.95, 16)), Vector3(-92, 0.6, 71))
	rect.call(-98.5, -98, 43.5, 68, 0, 6, WALL)
	rect.call(-86, -85.5, 43.5, 68, 0, 6, WALL)
	rect.call(-98.5, -85.5, 43.5, 44, 0, 6, WALL)
	rect.call(-98, -94, 44, 48, 0, 8, STONE) # the tower
	Pickup.spawn(lv, "heart", 1, Vector3(-96, 8.8, 46))
	basin(lv, Rect2(-94, 45, 2, 2), -1.0)
	var cover := CrackedFloor.make(lv, Vector3(-93, 0, 46))
	var fan := Fan.make(lv, Vector3(-93, -0.85, 46), AABB(Vector3(-94, -1, 45), Vector3(2, 10.5, 2)), Vector3.UP * 8.0)
	fan.cover = cover
	lv.label(Vector3(-92, 3.5, 70), "pond", 40)
	marks["garden_pond_bank"] = Vector3(-92, 0.6, 70)
	marks["garden_pond_y"] = -0.05
	marks["garden_island"] = Vector3(-90, 0.6, 49)
	marks["garden_vent"] = Vector3(-93, 0.6, 46)
	marks["garden_vent_cover"] = cover
	marks["garden_tower_y"] = 8.0

	# Ferry: a 16 m chasm x -96..-84, z 84..100; iron 9 m back from the near edge; the far side is walled in
	basin(lv, Rect2(-96, 84, 12, 16), -6.0)
	ShadowHall.pit(lv, Vector3(-90, -6, 92), Vector3(12, 1.5, 16), Vector3(-86, 0.6, 104)) # back out of the iron's line
	rect.call(-96.5, -96, 75.5, 100, 0, 6, WALL)
	rect.call(-84, -83.5, 75.5, 100, 0, 6, WALL)
	rect.call(-96.5, -83.5, 75.5, 76, 0, 6, WALL)
	var iron := IronCube.make(lv, Vector3(-90, 0, 109))
	Pickup.spawn(lv, "heart", 1, Vector3(-90, 0.8, 79))
	lv.label(Vector3(-90, 3.5, 104), "ferry (bring the magnet)", 40)
	marks["garden_ferry_edge"] = Vector3(-90, 0.6, 100.6)
	marks["garden_ferry_far"] = Vector3(-90, 0.6, 83.0)
	marks["garden_ferry_iron"] = iron

## A pit in the ground (one of GROUND_HOLES) lined with walls down to a floor at depth.
static func basin(lv: Node3D, r: Rect2, depth: float) -> void:
	var c := Color(0.4, 0.36, 0.3)
	var x0 := r.position.x
	var x1 := r.end.x
	var z0 := r.position.y
	var z1 := r.end.y
	var h := -1.0 - depth # from the floor up to the underside of the ground slab
	lv.box(Vector3((x0 + x1) / 2.0, depth - 0.25, (z0 + z1) / 2.0), Vector3(r.size.x + 1.0, 0.5, r.size.y + 1.0), Basis(), c)
	if h > 0.0:
		var y := depth + h / 2.0
		lv.box(Vector3(x0 - 0.25, y, (z0 + z1) / 2.0), Vector3(0.5, h, r.size.y + 1.0), Basis(), c)
		lv.box(Vector3(x1 + 0.25, y, (z0 + z1) / 2.0), Vector3(0.5, h, r.size.y + 1.0), Basis(), c)
		lv.box(Vector3((x0 + x1) / 2.0, y, z0 - 0.25), Vector3(r.size.x, h, 0.5), Basis(), c)
		lv.box(Vector3((x0 + x1) / 2.0, y, z1 + 0.25), Vector3(r.size.x, h, 0.5), Basis(), c)
