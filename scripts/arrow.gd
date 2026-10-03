class_name Arrow
extends Node3D
## An archer's arrow. It flies straight and fast (Monster.ARROW_SPEED) and hurts you on touch (a block stops it).
## A perfect guard sends it back faster and harder at whoever shot it, or at your lock-on target, and then it
## hits monsters instead.

const DAMAGE := 1
const BACK_DAMAGE := 3
const BACK_SPEED := 1.6 ## times faster once reflected
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

## A perfect guard: at your lock-on target if you have one, else back at whoever shot it, faster.
func reflect(p: Player = null, perfect := true) -> void:
	if reflected:
		return
	reflected = true
	var sp := vel.length() * BACK_SPEED
	var aim: Node3D = null
	if perfect and p != null and p.target != null and is_instance_valid(p.target) and p.target != shooter:
		aim = p.target
	elif shooter != null and is_instance_valid(shooter):
		aim = shooter
	vel = (aim.global_position - global_position).normalized() * sp if aim != null else -vel.normalized() * sp
	_life = LIFE
	_aim()

func _physics_process(dt: float) -> void:
	dt *= Hitfx.world
	_life -= dt
	if _life <= 0.0:
		queue_free()
		return
	var to := global_position + vel * dt
	var q := PhysicsRayQueryParameters3D.create(global_position, to, 1)
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		if reflected and hit.collider is Monster:
			_strike(hit.collider as Monster)
			return
		if not (hit.collider is CharacterBody3D):
			queue_free()
			return
	global_position = to
	if reflected:
		for n in get_tree().get_nodes_in_group("monsters"):
			var m := n as Monster
			if m.global_position.distance_to(global_position) < m._r + 0.35:
				_strike(m)
				return
		return
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p.global_position.distance_to(global_position) < p.radius() + 0.3:
			p.hurt(DAMAGE, global_position - vel.normalized(), self)
			if not reflected:
				queue_free()
			return

func _strike(m: Monster) -> void:
	m.strike(BACK_DAMAGE, global_position - vel.normalized(), {"stagger": true, "knock": 7.0})
	queue_free()
