class_name SpiderPens
extends RefCounted
## The spider & lash pens, just south of the combat yard (x -114..-62, z 0..22; marks `combat_pen_*`). Each pen's
## monsters come back a few seconds after you clear it (Pen, like CombatYard.Station). A lash and a spider lie
## at the warp spots.
## Lash pen (west): a blob pack round a shield blob, a 2 m pillar and a 0.5 m kerb. Lash a blob to leash it,
##   attack to sling it round you into the pack (it flies off where you face), lash again to yank it in. Lash the
##   shield blob to tear its shield away. Drag a leashed blob round the pillar or over the kerb: the rope doesn't
##   snag.
## Spider pen (east): a shield blob, an iron knight and a brute that keep to their spots (they don't chase). Send the
##   spider out: it bites what's next to it; steering it, attack bites harder. Walk it past their sides and it
##   turns them round like gears, backs to you.

const STONE := Color(0.62, 0.6, 0.55)

## Monsters that come back after you clear them. kinds: "knight" (IronKnight), "plated" (PlatedBrute), or a
## Monster kind. still: they keep to their spots (a 1 m `leash` meta), so the spider can walk round them.
class Pen extends Node3D:
	const RESPAWN := 4.0
	var spawns: Array = [] ## [kind, position]
	var still := false
	var alive: Array = []
	var _wait := 0.0
	func _ready() -> void:
		add_to_group("spawners")
		_spawn()
	func _spawn() -> void:
		alive.clear()
		for s in spawns:
			var at: Vector3 = s[1]
			var m: Monster
			match String(s[0]):
				"knight":
					m = IronKnight.make(get_parent(), at)
				"plated":
					m = PlatedBrute.make(get_parent(), at)
				_:
					m = Monster.spawn(get_parent(), at, s[0], false)
			m.home = at
			m.drop_heart = randf() < 0.3
			if still:
				m.set_meta("leash", 1.0) # it keeps to its spot (Liquids.monster_think), so the spider can walk round it
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

static func pen(lv: Node3D, at: Vector3, spawns: Array, still := false) -> Pen:
	var s := Pen.new()
	s.spawns = spawns
	s.still = still
	s.position = at
	lv.add_child(s)
	return s

static func build(lv: Node3D) -> void:
	var marks: Dictionary = lv.marks
	lv.label(Vector3(-88, 6, 1), "spider & lash pens", 48)

	# the lash pen: a pack, a shield blob, a pillar and a kerb
	var lx := -102.0
	pen(lv, Vector3(lx, 0, 12), [["blob", Vector3(lx - 3, 0.6, 12)], ["blob", Vector3(lx + 3, 0.6, 12)],
		["blob", Vector3(lx, 0.6, 15)], ["blob", Vector3(lx, 0.6, 9)], ["shield", Vector3(lx + 2, 0.6, 16)]])
	lv.box(Vector3(lx - 7, 1.5, 6), Vector3(2, 3, 2), Basis(), STONE) # the pillar: drag a leashed blob round it
	lv.box(Vector3(lx + 6, 0.25, 6), Vector3(0.6, 0.5, 6), Basis(), STONE) # the kerb: the rope rides over it
	lv.label(Vector3(lx, 4.5, 20), "lash a blob, then attack: it swings round you into the pack. Lash again to yank it in", 32)
	marks["combat_pen_lash"] = Vector3(lx, 0.6, 3)
	Pickup.spawn(lv, "lash", 1, Vector3(lx + 1.5, 1.0, 3))

	# the spider pen: shield blob, iron knight and brute stand still for the spider
	var sx := -76.0
	pen(lv, Vector3(sx, 0, 12), [["shield", Vector3(sx - 5, 0.6, 13)], ["knight", Vector3(sx, 0.6, 13)],
		["brute", Vector3(sx + 5, 0.9, 13)]], true)
	lv.label(Vector3(sx, 4.5, 20), "send the spider: it bites what's beside it (attack while you steer it bites harder); walk it past their sides to turn them round", 32)
	marks["combat_pen_spider"] = Vector3(sx, 0.6, 4)
	Pickup.spawn(lv, "spider", 1, Vector3(sx + 1.5, 1.0, 4))
