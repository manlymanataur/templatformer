class_name Battery
extends StaticBody3D
## A 2 m power block. Powers iron touching its sides.

static func make(parent: Node3D, pos: Vector3) -> Battery:
	var b := Battery.new()
	parent.add_child(b)
	b.global_position = pos
	return b

func _ready() -> void:
	add_to_group("power_source")
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2, 2, 2)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.1, 0.25, 0.3)
	m.emission_enabled = true
	m.emission = Color(0.37, 0.89, 1.0)
	m.emission_energy_multiplier = 0.5
	mi.material_override = m
	mi.position.y = 1.0
	add_child(mi)
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(2, 2, 2)
	c.shape = s
	c.position.y = 1.0
	add_child(c)

func power_box() -> AABB:
	return AABB(global_position - Vector3(1, 0, 1), Vector3(2, 2, 2))
