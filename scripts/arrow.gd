class_name Arrow
extends Node3D
## An archer's arrow. It flies straight and hurts you on touch (a block stops it). A perfect guard sends it
## back the way it came, and then it hits monsters instead.

const DAMAGE := 1
const LIFE := 3.0

var vel := Vector3.ZERO
var shooter: Node3D = null
var reflected := false
var _life := LIFE

static func shoot(parent: Node, from: Vector3, v: Vector3, by: Node3D) -> Arrow:
	var a := Arrow.new()
	a.vel = v
	a.shooter = by
	parent.add_child(a)
	a.global_position = from
	return a

func _ready() -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.06, 0.06, 0.8)
	m.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.9, 0.85, 0.6)
	mat.emission_enabled = true
	mat.emission = Color(0.5, 0.4, 0.2)
	m.material_override = mat
	add_child(m)
	_aim()

func _aim() -> void:
	if vel.length() > 0.01:
		look_at(global_position + vel, Vector3.UP if absf(vel.normalized().y) < 0.95 else Vector3.RIGHT)

## A perfect guard: back at whoever shot it, a little faster.
func reflect() -> void:
	reflected = true
	var back := -vel * 1.2
	if shooter != null and is_instance_valid(shooter):
		back = (shooter.global_position - global_position).normalized() * vel.length() * 1.2
	vel = back
	_aim()

func _physics_process(dt: float) -> void:
	dt *= Hitfx.world
	_life -= dt
	if _life <= 0.0:
		queue_free()
		return
	var to := global_position + vel * dt
	var q := PhysicsRayQueryParameters3D.create(global_position, to, 1)
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		queue_free()
		return
	global_position = to
	if reflected:
		for n in get_tree().get_nodes_in_group("monsters"):
			var m := n as Monster
			if m.global_position.distance_to(global_position) < 0.9:
				m.strike(2, global_position - vel.normalized(), {"stagger": true, "knock": 6.0})
				queue_free()
				return
		return
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p.global_position.distance_to(global_position) < p.radius() + 0.3:
			p.hurt(DAMAGE, global_position - vel.normalized(), self)
			if not reflected:
				queue_free()
			return
