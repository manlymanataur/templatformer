class_name Monster
extends CharacterBody3D
## Basic blob. Wanders near home, chases you inside AGGRO range, hurts on contact.
## Takes knockback and a short stun when hit. Can be locked onto.

const AGGRO := 9.0
const SPEED := 3.2
const TOUCH := 1.1
const GRAVITY := 30.0

var max_hp := 3
var hp := 3
var stun := 0.0
var home := Vector3.ZERO
var drop_heart := true
var _t := 0.0
var _mat: StandardMaterial3D

static func spawn(parent: Node, pos: Vector3) -> Monster:
	var m := Monster.new()
	parent.add_child(m)
	m.global_position = pos
	m.home = pos
	return m

func _ready() -> void:
	add_to_group("monsters")
	add_to_group("targets")
	add_to_group("hurtable")
	var c := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.55
	c.shape = s
	add_child(c)
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.6
	sm.height = 0.9
	body.mesh = sm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.35, 0.75, 0.3)
	body.material_override = _mat
	add_child(body)
	for side in [-0.2, 0.2]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.09
		em.height = 0.18
		eye.mesh = em
		var emat := StandardMaterial3D.new()
		emat.albedo_color = Color(0.05, 0.05, 0.05)
		eye.material_override = emat
		eye.position = Vector3(side, 0.15, -0.5)
		body.add_child(eye)

func _player() -> Player:
	var ps := get_tree().get_nodes_in_group("player")
	return ps[0] as Player if ps.size() > 0 else null

func _physics_process(dt: float) -> void:
	_t += dt
	velocity.y -= GRAVITY * dt
	var p := _player()
	if stun > 0.0:
		stun -= dt
		var hv := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, 12.0 * dt)
		velocity.x = hv.x
		velocity.z = hv.z
	else:
		_mat.albedo_color = Color(0.35, 0.75, 0.3)
		var dir := Vector3.ZERO
		var to := Vector3.ZERO
		if p != null:
			to = p.global_position - global_position
		var flat := Vector3(to.x, 0, to.z)
		if p != null and flat.length() < AGGRO:
			dir = flat.normalized()
		else:
			# drift around home in a slow circle
			var goal := home + Vector3(cos(_t * 0.5), 0, sin(_t * 0.5)) * 2.5
			var g := goal - global_position
			g.y = 0
			if g.length() > 0.3:
				dir = g.normalized() * 0.5
		velocity.x = dir.x * SPEED
		velocity.z = dir.z * SPEED
		if dir.length() > 0.1:
			look_at(global_position + Vector3(dir.x, 0, dir.z), Vector3.UP)
		if p != null and flat.length() < TOUCH and absf(to.y) < 1.2 and p.invuln <= 0.0:
			p.hurt(1, global_position)
			# recoil after landing a hit so it doesn't grind against you
			stun = 0.6
			velocity = -flat.normalized() * 5.0 + Vector3.UP * 2.0
	move_and_slide()
	if global_position.y < -30.0:
		queue_free()

func hurt(amount: int, from: Vector3) -> void:
	if hp <= 0:
		return
	hp -= amount
	stun = 0.5
	_mat.albedo_color = Color(1, 0.3, 0.3)
	var away := global_position - from
	away.y = 0
	away = away.normalized() if away.length() > 0.01 else Vector3.FORWARD
	velocity = away * 9.0 + Vector3.UP * 4.0
	if hp <= 0:
		_die()

func _die() -> void:
	if drop_heart:
		Pickup.spawn(get_parent(), "heart", 1, global_position + Vector3.UP * 0.5)
	queue_free()
