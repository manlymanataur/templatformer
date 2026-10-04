class_name MountainClimb
extends Node3D
## The mountain climb (jovi, 2026-10-04): the ski run's opposite. Parkour up a floating mountain north of the ski
## run (x -210..-144, z -345..-220, y 110 up to 170) and its summit is the ski run's top: climb up, ski down.
## A station per move (marks and warps mountain_<name>):
##   base     a 20 m runway to a 5 m cliff: a triple jump (or a double and a ledge grab)
##   trees    two 14 m trees 5 m apart before a 9 m cliff: bounce from tree to tree (you cling to a trunk
##            whichever way the stick points, and a kick bends toward the next tree), then kick onto the ledge
##            holding the stick toward it
##   chimney  a 6 m wide slot up a 10 m cliff: wall-jump side to side
##   vines    an 8 m vine face: climb it
##   gaps     east along a 20 m runway: a 10 m gap, a 12.5 m crumbling platform (it gives way behind you), then
##            an 8 m gap
##   launch   a launch pad up 12 m onto the next shelf
##   rail     shield up, a boost pad sends you up an 11 m uphill rail (only the shield surf grinds, and slow
##            too much on it and you slide back down)
##   summit   a 5 m cliff (double jump and grab) onto the ski run's top
## Fall off and you're put back at the nearest station at or below where you last stood.

const ROCK := Color(0.52, 0.5, 0.55)
const LEDGE := Color(0.62, 0.6, 0.58)
const SNOW := Color(0.93, 0.95, 1.0)
const X := -200.0

var lv: Node3D
var stations: Array = [] ## [name, respawn point]
var _reached := -1 ## the station a fall puts you back at (-1: not on the mountain yet)
var _prev_at := Vector3.ZERO

static func build(level: Node3D) -> MountainClimb:
	var c := MountainClimb.new()
	c.lv = level
	level.add_child(c)
	c._build()
	return c

## A block from (x0, y0, z0) to (x1, y1, z1).
func rect(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, col := ROCK) -> StaticBody3D:
	return lv.box(Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0, y1 - y0, z1 - z0), Basis(), col)

func station(name: String, at: Vector3, text: String) -> void:
	lv.marks["mountain_" + name] = at
	stations.append([name, at])
	lv.label(at + Vector3(0, 3.5, 0), text, 40)

## A tall tree to bounce off (group trees): a trunk h metres tall standing on at.
func tree(at: Vector3, h: float) -> StaticBody3D:
	var trunk := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.45
	cs.height = h
	c.shape = cs
	trunk.add_child(c)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.38
	cm.bottom_radius = 0.45
	cm.height = h
	mi.mesh = cm
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.28, 0.18)
	mi.material_override = wood
	trunk.add_child(mi)
	for k in 2:
		var crown := MeshInstance3D.new()
		var cone := CylinderMesh.new()
		cone.top_radius = 0.0
		cone.bottom_radius = 1.6 - k * 0.4
		cone.height = 3.0
		crown.mesh = cone
		var green := StandardMaterial3D.new()
		green.albedo_color = Color(0.18, 0.42, 0.28)
		crown.material_override = green
		crown.position.y = h / 2.0 + 0.5 + k * 1.6
		trunk.add_child(crown)
	trunk.add_to_group("trees")
	lv.add_child(trunk)
	trunk.global_position = at + Vector3.UP * h / 2.0
	return trunk

func _build() -> void:
	var m: Dictionary = lv.marks
	# base: a 20 m runway to a 5 m cliff
	rect(-210, -190, -345, -325, 100, 110, LEDGE)
	station("base", Vector3(X, 110.8, -342), "Mountain climb: up to the ski run's top.\nRun and triple jump up the 5 m cliff.")
	rect(-210, -190, -325, -305, 100, 115, LEDGE)
	m["mountain_cliff1"] = 115.0

	# trees: bounce between two trees up past a 9 m cliff
	station("trees", Vector3(X, 115.8, -320), "Bounce from tree to tree (jump as you touch one),\nthen kick toward the cliff holding the stick at it.")
	for dx in [-2.5, 2.5]:
		tree(Vector3(X + dx, 115, -308), 14.0)
	m["mountain_tree_l"] = Vector3(X - 2.5, 115, -308)
	m["mountain_tree_r"] = Vector3(X + 2.5, 115, -308)
	rect(-210, -190, -305, -293, 100, 124, LEDGE)
	m["mountain_cliff2"] = 124.0

	# chimney: a 5 m slot up the 10 m cliff, its floor the ledge you're on
	station("chimney", Vector3(X, 124.8, -298), "Wall-jump up the slot: kick side to side.")
	rect(-203, -197, -293, -287, 100, 124, LEDGE) # the slot's floor
	rect(-210, -203, -293, -279, 100, 134)
	rect(-197, -190, -293, -279, 100, 134)
	rect(-203, -197, -287, -279, 100, 134)
	m["mountain_slot"] = Vector3(X, 124.8, -290)
	CamFrame.make(lv, Vector3(X, 129, -293), Vector2(6, 10), Vector3.FORWARD, false, 7.0) # the camera looks up the slot through its mouth
	m["mountain_cliff3"] = 134.0

	# vines: an 8 m vine face
	station("vines", Vector3(-206, 134.8, -284), "Push into the vines to climb.")
	rect(-210, -190, -279, -265, 100, 142, LEDGE)
	Burnable.make(lv, "vines", Vector3(X, 134.05, -279.15), Vector3(6, 7.95, 0.3), 20.0)
	m["mountain_vine_foot"] = Vector3(X, 134.8, -281)
	m["mountain_cliff4"] = 142.0

	# gaps: east along the 20 m shelf, a 10 m gap, an 8 m platform, an 8 m gap
	station("gaps", Vector3(-208, 142.8, -272), "Run east: a 10 m gap, then 8 m.\nThe middle platform crumbles: keep moving.")
	for i in 5: # crumbling ledges (jovi, 2026-10-04): each gives way crumble_delay after you step on it
		var x0 := -180.0 + i * 2.5
		CrumbleLedge.make(lv, Vector3(x0 + 1.25, 141.25, -272), Vector3(2.5, 1.5, 14), lv.t)
	m["mountain_crumble"] = Vector3(-173.75, 142.8, -272)
	rect(-159.5, -144, -279, -265, 136, 142, LEDGE)
	m["mountain_gap1"] = Vector2(-190, -180) # x from, x to
	m["mountain_gap2"] = Vector2(-167.5, -159.5)

	# launch: a pad up 12 m onto the shelf to the south
	station("launch", Vector3(-152, 142.8, -276), "Launch pad up to the next shelf.")
	Pad.make(lv, "launch", Vector3(-152, 142, -268), Vector3(0, 28, 8), Vector3(2.4, 1, 2.4))
	m["mountain_launch_pad"] = Vector3(-152, 142.6, -268)
	var shelf := rect(-160, -144, -260, -244, 148, 154, SNOW)
	shelf.add_to_group("snow")
	m["mountain_cliff6"] = 154.0

	# rail: shield up, the boost pad sends you up the uphill rail onto the summit ledge
	station("rail", Vector3(-145.5, 154.8, -252), "Shield up (C) and hit the boost pad:\nthe rail climbs if you're fast enough.")
	Pad.make(lv, "boost", Vector3(-149, 154, -252), Vector3.LEFT, Vector3(2, 1, 3))
	var r0 := Vector3(-160.3, 154.3, -252)
	var r1 := Vector3(-194, 165.3, -252)
	Rail.make(lv, PackedVector3Array([r0, r1]))
	m["mountain_rail_a"] = r0
	m["mountain_rail_b"] = r1
	rect(-206, -194, -258, -246, 159, 165, LEDGE)
	rect(-207, -206, -258, -246, 159, 168, ROCK) # a back wall so the rail's end doesn't throw you off

	# summit: a 5 m cliff onto the ski run's top
	station("summit", Vector3(X, 165.8, -256), "Double jump and grab the ledge: the summit.")
	rect(-210, -190, -246, -220, 160, 170, SNOW).add_to_group("snow")
	m["mountain_top"] = Vector3(X, 170.8, -228)
	lv.label(Vector3(X, 175, -226), "Summit: the ski run starts here", 64)

func _physics_process(_dt: float) -> void:
	var ps := get_tree().get_nodes_in_group("player")
	if ps.is_empty():
		return
	var p := ps[0] as Player
	var at := p.global_position
	var jumped := at.distance_to(_prev_at) > 3.0 # a warp or a teleport: wait for the next floor
	_prev_at = at
	if at.x < -230.0 or at.x > -130.0 or at.z < -360.0 or at.z > -220.0 or jumped:
		_reached = -1
		return
	if p.is_on_floor():
		# standing anywhere on the mountain: the nearest station at or below you is where a fall puts you back
		var best := INF
		for i in stations.size():
			var s: Vector3 = stations[i][1]
			if s.y <= at.y + 1.0 and s.distance_to(at) < best:
				best = s.distance_to(at)
				_reached = i
	if _reached < 0:
		return
	var back: Vector3 = stations[_reached][1]
	if at.y < back.y - 15.0:
		p.teleport(back)
		p.surfing = false
		_prev_at = back
