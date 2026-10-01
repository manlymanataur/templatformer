class_name Rack
extends AnimatableBody3D
## A rack, from Winch: a toothed rail that slides along its groove. Its top is flush with the floor, so you
## walk on it. A gear whose rim touches one of its long sides meshes with it and slides it a metre per metre
## of rim (see Machinery); a crank can also be geared to it with Machinery.link.
## Whatever rides it moves with it: posts and gears put in `riders` are carried, and the spider and you ride
## it like any moving floor. But your weight pins it: while you stand on it, it can't slide, and neither can
## any gear meshed with it.
## `offset` runs from 0 (where it was built) to `travel` metres along `axis`; the groove's ends stop it.

var size := Vector3(2, 0.5, 6) ## width across, thickness, length along axis
var axis := Vector3.FORWARD ## the direction offset grows in (horizontal, unit)
var travel := 4.0
var offset := 0.0
var riders: Array[Node3D] = []
var _home := Vector3.ZERO

## top: centre of the rack's top face at offset 0. dir: slide direction; length along it, width across.
static func make(parent: Node3D, top: Vector3, dir: Vector3, length: float, width: float, travel_: float) -> Rack:
	var r := Rack.new()
	r.axis = dir.normalized()
	r.size = Vector3(width, 0.5, length)
	r.travel = travel_
	r.position = top # placed before it enters the tree, so the physics never sees it jump from the origin
	r.basis = Basis.looking_at(r.axis, Vector3.UP) # local -Z runs along the axis
	parent.add_child(r)
	r._home = top
	return r

func _ready() -> void:
	add_to_group("cogs")
	add_to_group("racks")
	sync_to_physics = false
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(size.x, size.y, size.z)
	c.shape = s
	c.position.y = -size.y / 2.0
	add_child(c)
	var brass := StandardMaterial3D.new()
	brass.albedo_color = Color(0.78, 0.57, 0.18)
	brass.metallic = 0.7
	brass.roughness = 0.4
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x - 0.04, size.y, size.z)
	mi.mesh = bm
	mi.material_override = brass
	mi.position.y = -size.y / 2.0
	add_child(mi)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.54, 0.38, 0.09)
	dark.metallic = 0.7
	var n := int(size.z / 0.5)
	for side in [-1.0, 1.0]:
		for k in n:
			var tooth := MeshInstance3D.new()
			var tm := BoxMesh.new()
			tm.size = Vector3(0.2, 0.3, 0.22)
			tooth.mesh = tm
			tooth.material_override = dark
			tooth.position = Vector3(side * (size.x / 2.0 + 0.05), -0.2, -size.z / 2.0 + 0.25 + k * 0.5)
			add_child(tooth)

## Across direction (unit): right of the axis.
func _across() -> Vector3:
	return axis.cross(Vector3.UP).normalized()

## How this rack slides when g turns by 1, or 0 if g's rim doesn't touch one of its toothed sides.
func mesh_factor(g: Gear) -> float:
	if riders.has(g):
		return 0.0 # it rides this rack: it's carried, not meshed
	var rel := g.global_position - global_position
	if absf(g.global_position.y - global_position.y) > Machinery.MESH_DY:
		return 0.0
	var along := rel.dot(axis)
	var across := rel.dot(_across())
	if absf(along) > size.z / 2.0:
		return 0.0
	if absf(absf(across) - size.x / 2.0 - g.radius) > Machinery.MESH_TOL:
		return 0.0
	# the rim point touching the rack, and which way it moves when the gear turns by +1 (see Gear: +1 turns
	# the rim at offset o toward (o.z, 0, -o.x))
	var o := -_across() * signf(across)
	var v := Vector3(o.z, 0, -o.x)
	return signf(v.dot(axis))

## Is the player standing on it?
func pinned() -> bool:
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as CharacterBody3D
		var rel := p.global_position - global_position
		var up := rel.y
		if up < -0.2 or up > 1.3 or not p.is_on_floor():
			continue
		if absf(rel.dot(axis)) <= size.z / 2.0 + 0.2 and absf(rel.dot(_across())) <= size.x / 2.0 + 0.2:
			return true
	return false

func cog_room(dir: float) -> float:
	if pinned():
		return 0.0
	return travel - offset if dir > 0.0 else offset

func cog_apply(amount: float) -> void:
	var before := offset
	offset = clampf(offset + amount, 0.0, travel)
	var d := axis * (offset - before)
	global_position = _home + axis * offset
	for r in riders:
		if is_instance_valid(r):
			r.global_position += d

func cog_jam() -> void:
	pass
