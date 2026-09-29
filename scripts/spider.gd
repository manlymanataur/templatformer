class_name Spider
extends CharacterBody3D
## The clockwork spider, a remote-control quick-slot item. It plays Winch's roles:
## - Piloting it, you sit still like Winch's dog and steer the spider. A cable pays out behind it from you
##   (spider_cable long) and turns any gear it runs past. At full length the spider can't go further.
## - Hook it with the lash and the roles swap: the spider is the dog and you walk. The lash becomes a leash
##   (leash_length long) that turns gears the same way, and at full length it tows the spider after you.
## It's small: grates, bars and railings don't stop it. It can't jump.
## The spider item button: out of your pack it scuttles out ahead and you take control. Pressed while piloting,
## you let go and it waits where it is (the cable drops, gears keep their angle). Pressed while it waits,
## you pick it up if you're close, or take control again.

const RADIUS := 0.3

var player: Player
var t: Tuning
var wish := Vector3.ZERO ## steering from the player while piloted
var piloted := false
var cable: Tether = null
var _legs: Array[MeshInstance3D] = []
var _t := 0.0
var _body: Node3D

static func deploy(p: Player) -> Spider:
	var s := Spider.new()
	s.player = p
	s.t = p.t
	p.get_parent().add_child(s)
	var f := p._flat_facing()
	var at := p.global_position + f * 1.2
	var q := PhysicsRayQueryParameters3D.create(p.global_position, at, 1, [p.get_rid()])
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		at = (hit["position"] as Vector3) - f * 0.4
	s.global_position = at + Vector3.DOWN * (p.radius() - RADIUS)
	return s

func _ready() -> void:
	add_to_group("spiders")
	add_to_group("targets") # lock on to aim the lash at it
	collision_layer = 1 << 4
	collision_mask = 1 # small: bars (layer 2) and grates (layer 3) don't stop it
	floor_snap_length = 0.4
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
	em.radius = 0.07
	em.height = 0.14
	eye.mesh = em
	var glow := StandardMaterial3D.new()
	glow.albedo_color = Color(1.0, 0.35, 0.2)
	glow.emission_enabled = true
	glow.emission = Color(1.0, 0.35, 0.2)
	eye.material_override = glow
	eye.position = Vector3(0, 0.05, -RADIUS * 0.9)
	_body.add_child(eye)
	for k in 8:
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.05, 0.05, 0.45)
		leg.mesh = lm
		leg.material_override = metal
		_body.add_child(leg)
		_legs.append(leg)

## Start piloting: you sit still and the cable runs from you to the spider.
func take_control() -> void:
	piloted = true
	_drop_cable()
	cable = Tether.make(get_parent(), player, self, t.spider_cable, false, Color(0.75, 0.75, 0.8))

## Let go: the spider waits here, and its cable drops (gears keep their angle).
func let_go() -> void:
	piloted = false
	wish = Vector3.ZERO
	_drop_cable()

func _drop_cable() -> void:
	if cable != null:
		cable.queue_free()
		cable = null

func _exit_tree() -> void:
	_drop_cable()

func _physics_process(dt: float) -> void:
	_t += dt
	var target := wish * t.spider_speed if piloted else Vector3.ZERO
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(target, 40.0 * dt)
	velocity.x = hv.x
	velocity.z = hv.z
	if is_on_floor():
		velocity.y = -0.5
	else:
		velocity.y -= t.gravity * dt
	move_and_slide()
	if cable != null:
		cable.update()
	if global_position.y < -30.0:
		# fell off the world: it climbs back into your pack
		player.stow_spider()
		return
	if hv.length() > 0.3:
		_body.basis = Basis.looking_at(hv.normalized(), Vector3.UP)
	# legs: four a side, scuttling while it moves
	var stride := sin(_t * 18.0) * 0.4 if hv.length() > 0.3 else 0.0
	for k in 8:
		var side := -1.0 if k < 4 else 1.0
		var a := (k % 4 - 1.5) * 0.45 + (stride if (k % 2 == 0) == (side > 0) else -stride)
		var leg := _legs[k]
		leg.basis = Basis(Vector3.UP, side * (PI / 2.0) + a) * Basis(Vector3.RIGHT, 0.5)
		leg.position = Vector3(side * RADIUS * 0.8, -0.05, (k % 4 - 1.5) * 0.12)
