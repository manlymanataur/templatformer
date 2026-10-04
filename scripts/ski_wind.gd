class_name SkiWind
extends Area3D
## A gust across the slope: while you ski through it, it pushes you along push (m/s per s). Carve into it to
## hold your line. Snow drifts along it so you can see it coming.

var push := Vector3.ZERO
var size := Vector3(10, 4, 10)

static func make(parent: Node, centre: Vector3, size_: Vector3, push_: Vector3, basis_ := Basis()) -> SkiWind:
	var w := SkiWind.new()
	w.push = push_
	w.size = size_
	parent.add_child(w)
	w.global_transform = Transform3D(basis_, centre)
	return w

func _ready() -> void:
	add_to_group("ski_wind")
	monitorable = false
	var c := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	c.shape = bs
	add_child(c)
	var drift := CPUParticles3D.new()
	drift.amount = 60
	drift.lifetime = 2.0
	drift.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	drift.emission_box_extents = size / 2.0
	drift.direction = push.normalized()
	drift.spread = 5.0
	drift.gravity = Vector3.ZERO
	drift.initial_velocity_min = push.length() * 0.8
	drift.initial_velocity_max = push.length() * 1.2
	var m := SphereMesh.new()
	m.radius = 0.05
	m.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1, 1, 1, 0.8)
	m.material = mat
	drift.mesh = m
	drift.local_coords = false
	add_child(drift)
