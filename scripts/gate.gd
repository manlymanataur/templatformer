class_name Gate
extends StaticBody3D
## Bars across a doorway. open() drops them into the floor. Blocks light while closed.

var size := Vector3(4, 4, 0.4)
var opened := false
var _mesh: MeshInstance3D
var _shape: CollisionShape3D

static func make(parent: Node, pos: Vector3, sz: Vector3, color: Color) -> Gate:
	var g := Gate.new()
	g.size = sz
	parent.add_child(g)
	g.global_position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.6
	g._mesh.material_override = m
	return g

func _init() -> void:
	_mesh = MeshInstance3D.new()
	add_child(_mesh)
	_shape = CollisionShape3D.new()
	add_child(_shape)

func _ready() -> void:
	var bm := BoxMesh.new()
	bm.size = size
	_mesh.mesh = bm
	var s := BoxShape3D.new()
	s.size = size
	_shape.shape = s

func open() -> void:
	if opened:
		return
	opened = true
	_shape.set_deferred("disabled", true)
	create_tween().tween_property(_mesh, "position:y", -size.y + 0.05, 0.6)
