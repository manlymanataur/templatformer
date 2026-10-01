class_name CombatYard
extends RefCounted
## The combat yard, west of the quarter pipe (x -116..-58, z -64..-14). One station per part of the poleaxe kit.
## Each station's monsters come back a few seconds after you clear it (Station).
## Downhill: a 6 m hill with a 24 m slope down into a pack of blobs. Run down it for a running blade above
##   fast_blade_speed, or surf down on your shield and bump through them. One of them has spikes on its head.
## Spiked row: three spiked blobs beside the slope. Pounding or homing onto them hurts; jump off the slope
##   holding guard and land on them to pogo along the row.
## Pillars: a wolf pack among four pillars. Knock wolves into a pillar (hammer, running blade) to splat them.
## Wall court: a rusher, a shield blob, a brute and an archer in front of a wall. Brace against the rusher, or
##   dodge so it crashes into the wall; smash the shield with the hammer or a bash; perfect-guard arrows back.

const STONE := Color(0.62, 0.6, 0.55)
const SAND := Color(0.78, 0.72, 0.55)

## A group of monsters that comes back RESPAWN seconds after the last one falls, while you're nearby.
class Station extends Node3D:
	const RESPAWN := 4.0
	var spawns: Array = [] ## [kind, spiked, position]
	var alive: Array = []
	var _wait := 0.0
	func _ready() -> void:
		add_to_group("spawners")
		_spawn()
	func _spawn() -> void:
		alive.clear()
		for s in spawns:
			var m := Monster.spawn(get_parent(), s[2], s[0], s[1])
			m.drop_heart = randf() < 0.3
			alive.append(m)
	func _physics_process(dt: float) -> void:
		for m in alive:
			if is_instance_valid(m):
				return
		var ps := get_tree().get_nodes_in_group("player")
		if ps.is_empty() or (ps[0] as Node3D).global_position.distance_to(global_position) > 45.0:
			return
		_wait += dt
		if _wait >= RESPAWN:
			_wait = 0.0
			_spawn()

static func station(lv: Node3D, at: Vector3, spawns: Array) -> Station:
	var s := Station.new()
	s.spawns = spawns
	s.position = at
	lv.add_child(s)
	return s

static func build(lv: Node3D) -> void:
	var marks: Dictionary = lv.marks
	var rect := func(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, c: Color) -> StaticBody3D:
		return lv.box(Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0, y1 - y0, z1 - z0), Basis(), c)

	lv.label(Vector3(-87, 6, -12), "combat yard")

	# the downhill: a 6 m hill and a 24 m slope down to the east, into a pack
	rect.call(-116, -104, -34, -20, 0, 6, STONE)
	var run := 24.0
	var drop := 6.0
	var a := atan2(drop, run)
	var len := sqrt(run * run + drop * drop)
	var slope := Basis(Vector3.BACK, -a) # falls toward +x
	lv.box(Vector3(-104 + run / 2.0, drop / 2.0 - 0.25 * cos(a), -27), Vector3(len, 0.5, 14), slope, SAND)
	# the slope's sides are walled so it doesn't read as a ledge onto the ground beside it
	for z in [-34.25, -19.75]:
		lv.box(Vector3(-104 + run / 2.0, drop / 2.0 + 0.3, z), Vector3(len, 1.2, 0.5), slope, STONE)
	lv.label(Vector3(-108, 8.5, -27), "run or shield-surf (hold C in the air, land holding it) down into them", 32)
	marks["combat_hill_top"] = Vector3(-110, 6.6, -27)
	marks["combat_hill_foot"] = Vector3(-79, 0.6, -27)
	station(lv, Vector3(-70, 0, -27), [["blob", false, Vector3(-72, 0.6, -29)], ["blob", false, Vector3(-72, 0.6, -25)],
		["blob", true, Vector3(-68, 0.6, -27)], ["shield", false, Vector3(-66, 0.6, -24)]])

	# spiked row by the slope's foot: pogo along it on your shield
	station(lv, Vector3(-94, 0, -16), [["blob", true, Vector3(-98, 0.6, -16)], ["blob", true, Vector3(-94, 0.6, -16)],
		["blob", true, Vector3(-90, 0.6, -16)]])
	lv.label(Vector3(-94, 3.5, -14), "spikes on their heads: only a shield surf (C in the air) lands on them", 32)
	marks["combat_spiked"] = Vector3(-104, 0.6, -16)

	# pillars and a wolf pack
	for p in [Vector2(-106, -48), Vector2(-96, -48), Vector2(-106, -58), Vector2(-96, -58)]:
		rect.call(p.x - 1, p.x + 1, p.y - 1, p.y + 1, 0, 5, STONE)
	station(lv, Vector3(-101, 0, -53), [["wolf", false, Vector3(-101, 0.6, -50)], ["wolf", false, Vector3(-104, 0.6, -53)],
		["wolf", false, Vector3(-98, 0.6, -55)]])
	lv.label(Vector3(-101, 6.5, -44), "wolves: knock them into the pillars", 32)
	marks["combat_wolves"] = Vector3(-101, 0.6, -42)

	# the wall court
	rect.call(-86, -58, -64, -63, 0, 4, STONE)
	station(lv, Vector3(-72, 0, -50), [["rusher", false, Vector3(-72, 0.6, -44)], ["shield", false, Vector3(-64, 0.6, -52)],
		["brute", false, Vector3(-80, 0.6, -54)], ["archer", false, Vector3(-62, 0.6, -46)]])
	lv.label(Vector3(-72, 5.5, -62), "brace (guard, stand still) against the rusher, or let it hit the wall", 32)
	marks["combat_court"] = Vector3(-72, 0.6, -55)
	SpiderPens.build(lv) # the spider & lash pens, south of the yard
