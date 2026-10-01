class_name Spider
extends CharacterBody3D
## The clockwork spider, Winch's walker. It's as big as you: bars and grates stop it, and you can stand on it.
## - The spider item switches who you steer: the first press sends it out and you steer it while you stand
##   still; each press after that swaps between it and you. Walking past a gear, its legs catch the teeth
##   and turn it (Gear).
## - Unhooked, it runs on its own clockwork. More than spider_break metres from you it breaks apart and
##   climbs back into your pack in pieces; send it out again.
## - Hook it with the lash and the lash becomes a taut rope (Tether). At full length, whichever of you is
##   being steered drags the other.
## - Context button next to it (while you're steering yourself) picks it up.

const RADIUS := 0.5

var player: Player
var t: Tuning
var wish := Vector3.ZERO ## steering from the player while piloted
var piloted := false
var _legs: Array[MeshInstance3D] = []
var _t := 0.0
var _body: Node3D

static func deploy(p: Player) -> Spider:
	var s := Spider.new()
	s.player = p
	s.t = p.t
	var f := p._flat_facing()
	var at := p.global_position + f * (p.radius() + RADIUS + 0.4)
	var q := PhysicsRayQueryParameters3D.create(p.global_position, at + f * RADIUS, 1 | 1 << 1 | 1 << 2, [p.get_rid()])
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		at = (hit["position"] as Vector3) - f * (RADIUS + 0.05)
	s.position = at + Vector3.UP * (RADIUS - p.radius() + 0.05)
	p.get_parent().add_child(s)
	return s

func _ready() -> void:
	add_to_group("spiders")
	add_to_group("targets") # lock on to aim the lash at it
	collision_layer = 1 << 4
	collision_mask = 1 | 1 << 1 | 1 << 2 | 1 << 4 # the world, bars, grates and props (seed cubes)
	floor_snap_length = 0.4
	floor_max_angle = deg_to_rad(50)
	var c := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = RADIUS
	c.shape = sh
	add_child(c)
	_body = Node3D.new()
	add_child(_body)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.55, 0.5, 0.45)
	metal.metallic = 0.8
	metal.roughness = 0.35
	var shell := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 1.3
	shell.mesh = sm
	shell.material_override = metal
	_body.add_child(shell)
	var eye := MeshInstance3D.new()
	var em := SphereMesh.new()
	em.radius = 0.1
	em.height = 0.2
	eye.mesh = em
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.35, 0.2)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.35, 0.2)
	eye.material_override = glow
	eye.position = Vector3(0, 0.08, -RADIUS * 0.9)
	_body.add_child(eye)
	for k in 8:
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.08, 0.08, 0.75)
		leg.mesh = lm
		leg.material_override = metal
		_body.add_child(leg)
		_legs.append(leg)

func take_control() -> void:
	piloted = true

func let_go() -> void:
	piloted = false
	wish = Vector3.ZERO

func lashed() -> bool:
	return player != null and player.leash != null and player.leash.b == self

func _physics_process(dt: float) -> void:
	if Liquids.frozen_step(self, dt): # rock candy
		return
	_t += dt
	var target := wish * t.spider_speed if piloted else Vector3.ZERO
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(target, 40.0 * dt)
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= t.gravity * dt
	Liquids.creature_after(self) # honey holds it fast
	move_and_slide()
	if global_position.y < -30.0:
		player.stow_spider() # fell off the world: it climbs back into your pack
		return
	if not lashed() and global_position.distance_to(player.global_position) > t.spider_break:
		Hitfx.sparks(get_tree(), global_position, 2.0)
		player.stow_spider() # out of range of its clockwork: it breaks, and you have to send it out again
		return
	if hv.length() > 0.3:
		_body.basis = Basis.looking_at(hv.normalized(), Vector3.UP)
	# legs: four a side, scuttling while it moves
	var stride := sin(_t * 14.0) * 0.4 if hv.length() > 0.3 else 0.0
	for k in 8:
		var side := -1.0 if k < 4 else 1.0
		var a := (k % 4 - 1.5) * 0.45 + (stride if (k % 2 == 0) == (side > 0) else -stride)
		var leg := _legs[k]
		leg.basis = Basis(Vector3.UP, side * (PI / 2.0) + a) * Basis(Vector3.RIGHT, 0.5)
		leg.position = Vector3(side * RADIUS * 0.8, -0.1, (k % 4 - 1.5) * 0.2)
