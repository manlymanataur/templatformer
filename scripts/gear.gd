class_name Gear
extends StaticBody3D
## A big gear on a vertical axle, from Winch. Rope sliding past its rim turns it like a belt (see Tether),
## and so does the spider walking along it: its legs catch the teeth.
## The gear drives a lift: a gate or platform that moves along `travel` as the gear winds.
## It keeps its angle when the rope goes slack or is dropped, so you can wind it over several trips.
## Wound backwards past the start, or forwards past the end of the lift's travel, it stops there.
## Gears are machinery (see Machinery): gears that touch mesh and turn each other the opposite way, a gear
## beside a rack slides it, and a train asked to turn two ways at once jams. A turn is measured in metres
## of rim; STEP metres (a quarter turn of a 1 m gear) is one notch, the unit screws and arms count in.

const STEP := PI / 2.0 ## metres of rim per notch (tooth pitch is the same on every gear, so it's the same for all)

var radius := 1.0
var lift: Node3D = null
var travel := Vector3.UP * 4.0 ## how far the lift moves from where it starts, fully wound
var limited := true ## false: no lift and no stops, it turns forever (machinery gears)
var wound := 0.0 ## metres of rim it has turned; limited gears keep it within the lift's travel
var spun := 0.0 ## every turn ever asked of it, signed and unclamped (for tests)
var jams := 0 ## how many times a turn of its train was refused because the train would have to turn two ways
var _base := Vector3.ZERO
var _teeth: Node3D
var _jam_fx := 0.0
var t: Tuning

static func make(parent: Node, pos: Vector3, r: float, drives: Node3D, move: Vector3, tuning: Tuning) -> Gear:
	var g := Gear.new()
	g.radius = r
	g.lift = drives
	g.travel = move
	g.t = tuning
	g.position = pos
	parent.add_child(g)
	g.global_position = pos
	if drives != null:
		g._base = drives.global_position
	return g

## A free machinery gear: no lift, no stops.
static func cog(parent: Node, pos: Vector3, r: float, tuning: Tuning) -> Gear:
	var g := make(parent, pos, r, null, Vector3.ZERO, tuning)
	g.limited = false
	return g

func _ready() -> void:
	add_to_group("gears")
	add_to_group("cogs")
	process_physics_priority = 50 # after the spider has stepped (0), before the rope (100) and Machinery (150)
	_build()

func _build() -> void:
	var c := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = radius
	s.height = 1.2
	c.shape = s
	c.position.y = 0.6
	add_child(c)
	_teeth = Node3D.new()
	add_child(_teeth)
	_teeth_ring(_teeth, 0.6, 1.2, Color(0.7, 0.55, 0.3))

## Hub and ten teeth, centred at height y.
func _teeth_ring(parent: Node3D, y: float, h: float, col: Color) -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.metallic = 0.7
	var hub := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = radius - 0.15
	hm.bottom_radius = radius - 0.15
	hm.height = h
	hub.mesh = hm
	hub.material_override = m
	hub.position.y = y
	parent.add_child(hub)
	var n := maxi(10, int(round(radius * 10.0)))
	for k in n:
		var tooth := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.3, h - 0.2, 0.3)
		tooth.mesh = bm
		tooth.material_override = m
		var a := TAU * k / float(n)
		tooth.position = Vector3(cos(a) * (radius - 0.05), y, sin(a) * (radius - 0.05))
		tooth.rotation.y = -a
		parent.add_child(tooth)

func _physics_process(dt: float) -> void:
	# a spider walking along the rim turns the gear by how far it walked past it, like rope sliding past.
	# Only its own steps count (Spider.own_step): not the floor carrying it, so a gear never turns itself by what
	# it moves (a spider riding an arm bridge or a rack), and not the gear riding past a still spider.
	for n in get_tree().get_nodes_in_group("spiders"):
		var sp := n as Spider
		if sp == null:
			continue
		var at := sp.global_position
		var d := sp.own_step
		d.y = 0.0
		var off := Vector3(at.x - global_position.x, 0, at.z - global_position.z)
		if d.length() > 0.0001 and off.length() < radius + 0.9 and absf(at.y - global_position.y - 0.6) < 1.5:
			turn(d.length() * signf(off.cross(d).y))
	if _jam_fx > 0.0:
		_jam_fx -= dt

func max_wind() -> float:
	return travel.length() / maxf(t.gear_ratio, 0.01)

## Rope slid past the rim by metres (sign = direction). The turn goes through Machinery, which turns the
## whole train this gear meshes with this frame, or refuses it (a jam) or stops it short (something at its stop).
func turn(metres: float) -> void:
	spun += metres
	Machinery.demand(self, metres)

## Machinery: how far this gear can turn in direction dir (+1 / -1) before it reaches a stop.
func cog_room(dir: float) -> float:
	if not limited:
		return INF
	return max_wind() - wound if dir > 0.0 else wound

## Machinery: turn by metres of rim (already checked against cog_room).
func cog_apply(metres: float) -> void:
	var before := wound
	wound = clampf(wound + metres, 0.0, max_wind()) if limited else wound + metres
	_teeth.rotation.y += (wound - before) / radius
	if lift != null:
		lift.global_position = _base + travel.normalized() * wound * t.gear_ratio

## Machinery: the train this gear is in was asked to turn two ways at once.
func cog_jam() -> void:
	jams += 1
	if _jam_fx <= 0.0 and is_inside_tree():
		_jam_fx = 0.4
		Hitfx.sparks(get_tree(), global_position + Vector3.UP * 0.8, 0.6)

## The gear's angle in notches (quarter turns), rounded.
func notch() -> int:
	return roundi(wound / STEP)

## How far the lift has moved, 0 to 1.
func progress() -> float:
	return wound / max_wind()
