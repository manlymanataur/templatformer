class_name CrackedWall
extends StaticBody3D
## A cracked wall. Roll into it at normal size and it bursts. Small, you just bounce off.

var size := Vector3(2, 3, 0.5)
var smashed := false

## pos is the middle of the wall's base.
static func make(parent: Node, pos: Vector3, wall: Vector3) -> CrackedWall:
	var w := CrackedWall.new()
	w.size = wall
	parent.add_child(w)
	w.global_position = pos + Vector3.UP * wall.y / 2.0
	return w

func _ready() -> void:
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	add_child(c)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.6, 0.52, 0.44)
	mi.material_override = m
	add_child(mi)
	var crack := StandardMaterial3D.new()
	crack.albedo_color = Color(0.15, 0.12, 0.1)
	var long := size.x >= size.z
	for face in [-1.0, 1.0]:
		for k in 4:
			var line := MeshInstance3D.new()
			var lm := BoxMesh.new()
			lm.size = Vector3(0.06, size.y * 0.45, 0.02) if long else Vector3(0.02, size.y * 0.45, 0.06)
			line.mesh = lm
			line.material_override = crack
			var off: float = face * ((size.z if long else size.x) / 2.0 + 0.005)
			var along := (k - 1.5) * 0.4
			line.position = Vector3(along, (k % 2 - 0.5) * 0.6, off) if long else Vector3(off, (k % 2 - 0.5) * 0.6, along)
			line.rotation = Vector3(0, 0, 0.5 - k * 0.35) if long else Vector3(0.5 - k * 0.35, 0, 0)
			add_child(line)

func smash() -> void:
	if smashed:
		return
	smashed = true
	for k in 8: # a burst of rubble that drops and fades
		var chunk := RigidBody3D.new()
		chunk.collision_layer = 0
		chunk.collision_mask = 1
		var c := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = Vector3(0.35, 0.35, 0.35)
		c.shape = s
		chunk.add_child(c)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = s.size
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.6, 0.52, 0.44)
		mi.material_override = m
		chunk.add_child(mi)
		get_parent().add_child(chunk)
		chunk.global_position = global_position + Vector3(randf_range(-0.5, 0.5) * size.x, randf_range(-0.4, 0.4) * size.y, randf_range(-0.5, 0.5) * size.z)
		chunk.linear_velocity = Vector3(randf_range(-3, 3), randf_range(1, 4), randf_range(-3, 3))
		get_tree().create_timer(1.5).timeout.connect(chunk.queue_free)
	queue_free()
