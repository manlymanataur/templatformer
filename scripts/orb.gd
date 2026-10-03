class_name Orb
extends Node3D
## A caster's orb: slow, glowing, and it drifts after you a little. It hurts on touch, and a plain block soaks
## it up. Parry it (a perfect guard, or swing the poleaxe through it) and it flies back faster and stronger at
## whoever cast it; parry it at the last moment (a perfect guard, or a swing when it's nearly on you) while
## locked on and it goes for your lock-on target instead (jovi, 2026-10-03).

const SPEED := 5.5
const TURN := 1.2 ## radians a second it bends toward you
const BACK_SPEED := 3.0 ## times faster once parried
const BACK_TURN := 8.0
const DAMAGE := 1
const BACK_DAMAGE := 3
const LIFE := 6.0
const R := 0.35

var vel := Vector3.ZERO
var shooter: Node3D = null
var chase: Node3D = null ## what it bends toward (you, or once parried, what it was sent at)
var reflected := false
var _life := LIFE
var _mat: StandardMaterial3D

static func shoot(parent: Node, from: Vector3, at: Node3D, by: Node3D) -> Orb:
	var o := Orb.new()
	o.shooter = by
	o.chase = at
	parent.add_child(o)
	o.global_position = from
	var d := at.global_position - from
	o.vel = (d.normalized() if d.length() > 0.01 else Vector3.FORWARD) * SPEED
	return o

func _ready() -> void:
	add_to_group("parryable")
	var m := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = R
	sm.height = R * 2.0
	m.mesh = sm
	_mat = StandardMaterial3D.new()
	_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_mat.albedo_color = Color(1.0, 0.75, 0.3)
	m.material_override = _mat
	add_child(m)

## Parried: back the way it came, or at your lock-on target if it was a perfect, last-moment parry.
func reflect(p: Player, perfect := true) -> void:
	if reflected:
		return
	reflected = true
	var aim: Node3D = null
	if perfect and p.target != null and is_instance_valid(p.target) and p.target != shooter:
		aim = p.target
	elif shooter != null and is_instance_valid(shooter):
		aim = shooter
	chase = aim
	var sp := SPEED * BACK_SPEED
	if aim != null:
		vel = (aim.global_position - global_position).normalized() * sp
	else:
		vel = -vel.normalized() * sp
	_mat.albedo_color = Color(0.5, 0.9, 1.0)
	Hitfx.sparks(get_tree(), global_position, 1.0)

func _physics_process(dt: float) -> void:
	dt *= Hitfx.world
	_life -= dt
	if _life <= 0.0:
		queue_free()
		return
	if chase != null and is_instance_valid(chase):
		var want := (chase.global_position - global_position).normalized() * vel.length()
		var turn := (BACK_TURN if reflected else TURN) * dt
		vel = vel.slerp(want, clampf(turn / maxf(vel.angle_to(want), 0.001), 0.0, 1.0))
	var to := global_position + vel * dt
	var q := PhysicsRayQueryParameters3D.create(global_position, to, 1)
	q.collide_with_bodies = true
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and not (hit.collider is CharacterBody3D):
		Hitfx.sparks(get_tree(), global_position, 0.6)
		queue_free()
		return
	global_position = to
	if reflected:
		for n in get_tree().get_nodes_in_group("monsters"):
			var m := n as Monster
			if m.global_position.distance_to(global_position) < m._r + R + 0.1:
				m.strike(BACK_DAMAGE, global_position - vel.normalized(), {"stagger": true, "knock": 7.0})
				queue_free()
				return
		return
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p.global_position.distance_to(global_position) < p.radius() + R:
			p.hurt(DAMAGE, global_position - vel.normalized(), self)
			if not reflected:
				queue_free() # a hit or a block ends it; a perfect guard has sent it back
			return
