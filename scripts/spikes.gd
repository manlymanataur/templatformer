class_name Spikes
extends StaticBody3D
## A spiked ball: touch it and it hurts you. A homing attack (air attack near it) bounces you off it
## unharmed instead, like a pogo, so a chain of them is a ladder (see Player._homing_step).

const R := 0.5

static func make(parent: Node, pos: Vector3) -> Spikes:
	var s := Spikes.new()
	parent.add_child(s)
	s.global_position = pos
	return s

func _ready() -> void:
	add_to_group("pogo")
	add_to_group("targets")
	add_to_group("hazards")
	var c := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = R
	c.shape = sh
	add_child(c)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.35, 0.35, 0.4)
	m.metallic = 0.8
	var ball := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = R
	sm.height = R * 2.0
	ball.mesh = sm
	ball.material_override = m
	add_child(ball)
	var tip := StandardMaterial3D.new()
	tip.albedo_color = Color(0.9, 0.25, 0.2)
	for d in [Vector3.UP, Vector3.DOWN, Vector3.LEFT, Vector3.RIGHT, Vector3.FORWARD, Vector3.BACK]:
		var spike := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.0
		cm.bottom_radius = 0.15
		cm.height = 0.4
		spike.mesh = cm
		spike.material_override = tip
		add_child(spike)
		spike.position = (d as Vector3) * (R + 0.15)
		if absf((d as Vector3).y) < 0.5:
			spike.basis = Basis((d as Vector3).cross(Vector3.UP).normalized(), -PI / 2.0)
		elif (d as Vector3).y < 0.0:
			spike.basis = Basis(Vector3.RIGHT, PI)

func _physics_process(_dt: float) -> void:
	for n in get_tree().get_nodes_in_group("hurtable"):
		var p := n as Player
		if p == null or p.homing != null:
			continue
		if p.global_position.distance_to(global_position) < R + p.radius() + 0.2:
			p.hurt(1, global_position)
