class_name MovesYard
extends RefCounted
## The moves yard, south of the start (x -26..26, z -64..-118): one station per new move.
## Climb tower: a vine face you can climb as high as it goes (8 m), then pull yourself over the top. Burn it
##   and it grows back in 20 s.
## Rail: from the tower top a rail runs 4 m downhill. Grinding it builds speed, and the kicker at its end throws
##   you across a 10 m gap to a 2 m platform.
## Pogo spikes: spiked balls hurt to touch, but a locked-on air attack homes in and bounces you off them. Two of them
##   climb to an 8 m ledge.
## Ledge: a 3.5 m block, over a single jump (2.4 m). Catch the edge as you fall against it and pull yourself up.

const STONE := Color(0.6, 0.58, 0.52)

static func build(lv: Node3D) -> void:
	var marks: Dictionary = lv.marks
	var rect := func(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, c: Color) -> StaticBody3D:
		return lv.box(Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0, y1 - y0, z1 - z0), Basis(), c)

	lv.label(Vector3(0, 5, -64), "moves yard")

	# climb tower, vines on its north face
	rect.call(-24, -16, -76, -68, 0, 8, STONE)
	# a Burnable vine like every other (Plants): climbable, a lash post, and it burns, but it grows back here
	Burnable.make(lv, "vines", Vector3(-20, 0, -67.85), Vector3(6, 8, 0.3), 20.0)
	lv.label(Vector3(-20, 3, -66), "push into vines to climb", 32)
	marks["moves_climb"] = Vector3(-20, 0.6, -64)
	marks["moves_climb_top"] = 8.0

	# rail off the tower's south edge: 4 m down over 22 m, then a kicker up 1.5 m over 4 m
	Rail.make(lv, PackedVector3Array([Vector3(-20, 8.3, -75), Vector3(-20, 4.3, -97), Vector3(-20, 5.8, -101)]))
	rect.call(-24, -16, -119, -111, 0, 2, STONE)
	lv.label(Vector3(-20, 10, -76), "grind rail: jump on", 32)
	marks["moves_rail"] = Vector3(-20, 8.6, -72)
	marks["moves_rail_land"] = -111.0 # 10 m past the rail's end

	# pogo spikes up to an 8 m ledge
	rect.call(-4, 4, -90, -82, 0, 8, STONE)
	Spikes.make(lv, Vector3(0, 3.5, -74))
	Spikes.make(lv, Vector3(0, 6.5, -78))
	lv.label(Vector3(0, 2, -66), "hold lock-on and attack in the air to home onto spikes, or attack without lock-on to ground pound them", 32)
	marks["moves_pogo"] = Vector3(0, 0.6, -68)
	marks["moves_pogo_top"] = 8.0

	# ledge-grab block
	rect.call(14, 22, -84, -76, 0, 3.5, STONE)
	lv.label(Vector3(18, 5.5, -74), "jump, then catch the ledge", 32)
	marks["moves_ledge"] = Vector3(18, 0.6, -71)
	marks["moves_ledge_top"] = 3.5
