class_name Gear
extends StaticBody3D
## A big gear on a vertical axle, from Winch. Rope sliding past its rim turns it like a belt (see Tether),
## and so does the spider walking along it: its legs catch the teeth.
## The gear drives a lift: a gate or platform that moves along `travel` as the gear winds.
## It keeps its angle when the rope goes slack or is dropped, so you can wind it over several trips.
## Wound backwards past the start, or forwards past the end of the lift's travel, it just slips.

var radius := 1.0
var lift: Node3D = null
var travel := Vector3.UP * 4.0 ## how far the lift moves from where it starts, fully wound
var wound := 0.0 ## metres of rope that have turned it, clamped to the lift's travel
var _base := Vector3.ZERO
var _teeth: Node3D
var t: Tuning

static func make(parent: Node, pos: Vector3, r: float, drives: Node3D, move: Vector3, tuning: Tuning) -> Gear:
	var g := Gear.new()
	g.radius = r
	g.lift = drives
	g.travel = move
	g.t = tuning
	parent.add_child(g)
	g.global_position = pos
	if drives != null:
		g._base = drives.global_position
	return g

func _ready() -> void:
	add_to_group("gears")
	var c := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = 1.2
	c.shape = s
	c.position.y = 0.6
	add_child(c)
	_teeth = Node3D.new()
	add_child(_teeth)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.7, 0.55, 0.3)
	m.metallic = 0.7
	var hub := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = radius - 0.15
	hm.bottom_radius = radius - 0.15
	hm.height = 1.2
	hub.mesh = hm
	hub.material_override = m
	hub.position.y = 0.6
	_teeth.add_child(hub)
	for k in 10:
		var tooth := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, 1.0, 0.3)
		tooth.mesh = bm
		tooth.material_override = m
		var a := TAU * k / 10.0
		tooth.position = Vector3(cos(a) * (radius - 0.05), 0.6, sin(a) * (radius - 0.05))
		tooth.rotation.y = -a
		_teeth.add_child(tooth)

var _last := {} ## spider -> where it was last frame

func _physics_process(_dt: float) -> void:
	# a spider walking along the rim turns the gear by how far it walked, like rope sliding past
	var seen := {}
	for n in get_tree().get_nodes_in_group("spiders"):
		var sp := n as Node3D
		var at := sp.global_position
		seen[sp] = true
		if _last.has(sp):
			var d: Vector3 = at - _last[sp]
			d.y = 0.0
			var off := Vector3(at.x - global_position.x, 0, at.z - global_position.z)
			if d.length() > 0.0001 and off.length() < radius + 0.9 and absf(at.y - global_position.y - 0.6) < 1.5:
				turn(d.length() * signf(off.cross(d).y))
		_last[sp] = at
	for k in _last.keys():
		if not seen.has(k):
			_last.erase(k)

func max_wind() -> float:
	return travel.length() / maxf(t.gear_ratio, 0.01)

## Rope slid past the rim by metres (sign = direction).
func turn(metres: float) -> void:
	var before := wound
	wound = clampf(wound + metres, 0.0, max_wind())
	_teeth.rotation.y += (wound - before) / radius
	if lift != null:
		lift.global_position = _base + travel.normalized() * wound * t.gear_ratio

## How far the lift has moved, 0 to 1.
func progress() -> float:
	return wound / max_wind()
