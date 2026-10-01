class_name Spider
extends CharacterBody3D
## The clockwork spider, Winch's walker. It's small, about your size when you shrink (jovi, 2026-10-01): it
## slips through bars and grates (layers 2 and 3). Only the fine mesh on layer 6 (the gear cage) stops it.
## - While you steer it, the context button picks up anything carryable next to it (group "carryable": seeds,
##   bombs, pots, and you yourself, sitting still while you steer it) and holds it overhead. Context again throws
##   it if the spider is moving, or sets it down in front if it's standing still; a seed set down on soil, mud
##   or roots plants, like yours. Carrying, it's as big as its load: bars and grates stop it again.
## - The spider item switches who you steer: the first press sends it out and you steer it while you stand
##   still; each press after that swaps between it and you. Walking past a gear, its legs catch the teeth
##   and turn it (Gear).
## - Unhooked, it runs on its own clockwork. More than spider_break metres from you it breaks apart and
##   climbs back into your pack in pieces; send it out again.
## - Hook it with the lash and the lash becomes a taut rope (Tether). At full length, whichever of you is
##   being steered drags the other.
## - Context button next to it (while you're steering yourself) picks it up.

const RADIUS := 0.175 ## the small player's size (Player.RADIUS x small_scale 0.35)
const MASK := 1 | 1 << 4 | 1 << 5 ## the world, props (seed cubes) and spider mesh; not bars or grates

var player: Player
var t: Tuning
var wish := Vector3.ZERO ## steering from the player while piloted
var piloted := false
var _legs: Array[MeshInstance3D] = []
var _t := 0.0
var _body: Node3D
var held: Node3D = null ## what it's carrying overhead
var facing := Vector3.FORWARD
var _load: CollisionShape3D ## the carried thing's size, so a loaded spider can't squeeze through

static func deploy(p: Player) -> Spider:
	var s := Spider.new()
	s.player = p
	s.t = p.t
	var f := p._flat_facing()
	var at := p.global_position + f * (p.radius() + RADIUS + 0.4)
	var q := PhysicsRayQueryParameters3D.create(p.global_position, at + f * RADIUS, MASK, [p.get_rid()])
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		at = (hit["position"] as Vector3) - f * (RADIUS + 0.05)
	s.position = at + Vector3.UP * (RADIUS - p.radius() + 0.05)
	s.facing = f
	p.get_parent().add_child(s)
	return s

func _ready() -> void:
	add_to_group("spiders")
	add_to_group("targets") # lock on to aim the lash at it
	collision_layer = 1 << 4
	collision_mask = MASK
	floor_snap_length = 0.3
	floor_max_angle = deg_to_rad(50)
	var c := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = RADIUS
	c.shape = sh
	add_child(c)
	_load = CollisionShape3D.new()
	_load.disabled = true
	add_child(_load)
	_body = Node3D.new()
	_body.scale = Vector3.ONE * (RADIUS / 0.5) # the parts below are drawn at the old 0.5 m size
	add_child(_body)
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.55, 0.5, 0.45)
	metal.metallic = 0.8
	metal.roughness = 0.35
	var shell := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 0.5 * 1.3
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
	eye.position = Vector3(0, 0.08, -0.5 * 0.9)
	_body.add_child(eye)
	for k in 8:
		var leg := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.08, 0.08, 0.75)
		leg.mesh = lm
		leg.material_override = metal
		_body.add_child(leg)
		_legs.append(leg)

func radius() -> float:
	return RADIUS

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
		facing = hv.normalized()
	_body.basis = Basis.looking_at(facing, Vector3.UP).scaled(Vector3.ONE * (RADIUS / 0.5))
	if held != null and not is_instance_valid(held):
		_drop_shape()
	# legs: four a side, scuttling while it moves
	var stride := sin(_t * 14.0) * 0.4 if hv.length() > 0.3 else 0.0
	for k in 8:
		var side := -1.0 if k < 4 else 1.0
		var a := (k % 4 - 1.5) * 0.45 + (stride if (k % 2 == 0) == (side > 0) else -stride)
		var leg := _legs[k]
		leg.basis = Basis(Vector3.UP, side * (PI / 2.0) + a) * Basis(Vector3.RIGHT, 0.5)
		leg.position = Vector3(side * 0.5 * 0.8, -0.1, (k % 4 - 1.5) * 0.2)

## The context button while you steer it: pick up what's next to it, or put down what it carries.
func context() -> void:
	if held != null:
		release()
		return
	var best: Node3D = null
	var best_d := INF
	for n in get_tree().get_nodes_in_group("carryable"):
		var c := n as Node3D
		if c == null or c == self or not _can_take(c):
			continue
		var size := _size_of(c)
		var d := c.global_position - global_position
		var gap := maxf(absf(d.x) - size.x / 2.0, absf(d.z) - size.z / 2.0)
		if gap < RADIUS + 0.45 and absf(d.y) < size.y / 2.0 + 0.6 and gap < best_d:
			best = c
			best_d = gap
	if best != null:
		pick_up(best)

func _can_take(c: Node3D) -> bool:
	if c.has_method("loose"):
		return c.loose()
	if "holder" in c:
		return c.get("holder") == null
	return true

static func _size_of(c: Node3D) -> Vector3:
	return c.carry_size() if c.has_method("carry_size") else Vector3.ONE * 0.6

func pick_up(c: Node3D) -> void:
	held = c
	c.hold(self)
	var size := _size_of(c)
	var box := BoxShape3D.new()
	box.size = size - Vector3.ONE * 0.05
	_load.shape = box
	_load.position = Vector3.UP * (RADIUS + size.y / 2.0 + 0.1)
	_load.set_deferred("disabled", false)
	if size.x > 0.4 or size.z > 0.4:
		collision_mask = MASK | 1 << 1 | 1 << 2 # too big for the gaps: bars and grates stop it while it carries

## Throw it if moving, set it down in front if standing still (only where there's room). force sets it down
## next to the spider wherever it is (you let go of the spider while it carries you).
func release(force := false) -> void:
	var c := held
	if c == null:
		return
	var size := _size_of(c)
	var moving := wish.length() > 0.2 or Vector2(velocity.x, velocity.z).length() > 2.0
	var front := global_position + facing * (RADIUS + maxf(size.x, size.z) / 2.0 + 0.15) + Vector3.UP * (size.y / 2.0 - RADIUS + 0.05)
	if not moving and not force and not _room_for(c, front, size):
		return # no room in front: keep holding it
	_drop_shape()
	if moving and not force:
		c.throw(facing * t.bomb_throw_speed + Vector3.UP * t.bomb_throw_up + Vector3(velocity.x, 0, velocity.z) * 0.3)
		return
	if force and not _room_for(c, front, size):
		front = c.global_position
	c.set_down(front)
	if c is Seed and (c as Seed).can_plant():
		(c as Seed).plant()

func _drop_shape() -> void:
	held = null
	_load.set_deferred("disabled", true)
	collision_mask = MASK

func _room_for(c: Node3D, at: Vector3, size: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var b := BoxShape3D.new()
	b.size = size - Vector3.ONE * 0.1
	q.shape = b
	q.transform = Transform3D(Basis(), at + Vector3.UP * 0.05)
	q.collision_mask = 1 | 1 << 1 | 1 << 2 | 1 << 4
	var ex: Array[RID] = [get_rid()]
	if c is CollisionObject3D:
		ex.append((c as CollisionObject3D).get_rid())
	q.exclude = ex
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

func _exit_tree() -> void:
	if held != null and is_instance_valid(held):
		var c := held
		_drop_shape()
		c.set_down(c.global_position) # stowed or broken: what it carried drops where it is
