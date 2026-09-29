class_name IceBlock
extends StaticBody3D
## Solid ice. Blocks the way and blocks light. Hold fire against it (MELT_TIME seconds in total) and it melts away.

const MELT_TIME := 1.0
var size := Vector3(2, 2, 2)
var _warm := 0.0
var _mesh: MeshInstance3D

static func make(parent: Node, pos: Vector3, sz: Vector3) -> IceBlock:
	var b := IceBlock.new()
	b.size = sz
	parent.add_child(b)
	b.global_position = pos
	return b

func _ready() -> void:
	add_to_group("flammable")
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	_mesh.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.92, 1.0, 0.8)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	_mesh.material_override = m
	_mesh.position.y = size.y / 2.0
	add_child(_mesh)
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	c.position.y = size.y / 2.0
	add_child(c)

func heat(dt: float) -> void:
	_warm += dt
	var k := clampf(1.0 - _warm / MELT_TIME, 0.0, 1.0)
	_mesh.scale = Vector3(1.0, maxf(k, 0.05), 1.0)
	_mesh.position.y = size.y * k / 2.0
	if _warm >= MELT_TIME:
		queue_free()

func heat_box() -> AABB:
	return AABB(global_position - Vector3(size.x / 2.0, 0, size.z / 2.0), size)
