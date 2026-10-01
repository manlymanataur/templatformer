class_name Crate
extends CharacterBody3D
## A 2 m wooden crate (Ember & Umbra, and the Cellar). It's solid on layer 1, so it blocks you, monsters and
## light (it casts a shadow), and you can stand on it.
## - Push it: walk into one of its faces on the ground and it slides away from you at crate_push_speed.
## - In deep water (Water) it floats with its top 1.2 m over the surface and drifts with the water's current,
##   carrying whoever stands on it: a raft. Floating it's always wet.
## - It burns (group "flammable"): heat sets it alight, it burns for crate_burn warming what it touches, then
##   it's gone. Water puts it out and keeps it wet for wet_time.
## - A poleaxe hit or a bomb smashes it (it's hurtable). Too big to carry.
## With respawns, a lost crate comes back home a few seconds later, and so does a raft left idle at the far side.

const SIZE := 2.0
const HALF := 1.0
const FLOAT := 0.2 ## a floating crate's centre sits this far over the surface

var t: Tuning
var home := Vector3.ZERO ## where it respawns (its centre)
var respawns := false
var burning := false
var wet := 0.0
var floating := false
var _left := 0.0
var _warm := 0.0
var _idle := 0.0
var _gone := false
var _flames: Node3D
var _mat: StandardMaterial3D

## A crate standing on the floor at `foot` (the middle of its bottom face).
static func make(parent: Node, foot: Vector3, tuning: Tuning, respawn := false) -> Crate:
	var c := Crate.new()
	c.t = tuning
	c.respawns = respawn
	c.position = foot + Vector3.UP * HALF
	c.home = c.position
	parent.add_child(c)
	return c

func _ready() -> void:
	if t == null:
		t = Liquids.tuning(get_tree())
	add_to_group("crates")
	add_to_group("flammable")
	add_to_group("hurtable")
	add_to_group("light_sources")
	collision_layer = 1 # solid like a wall: blocks light too
	collision_mask = 1 | 1 << 4
	floor_max_angle = deg_to_rad(40)
	var col := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3.ONE * (SIZE - 0.02)
	col.shape = bs
	add_child(col)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * SIZE
	mi.mesh = bm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.62, 0.45, 0.26)
	mi.material_override = _mat
	add_child(mi)
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.4, 0.28, 0.16)
	for s in [-1.0, 1.0]: # cross planks so it reads as a crate
		for ax in 2:
			var plank := MeshInstance3D.new()
			var pm := BoxMesh.new()
			pm.size = Vector3(0.25, SIZE * 1.3, 0.04) if ax == 0 else Vector3(0.04, SIZE * 1.3, 0.25)
			plank.mesh = pm
			plank.material_override = dark
			if ax == 0:
				plank.position = Vector3(0, 0, s * (HALF + 0.01))
				plank.rotation.z = PI / 4.0
			else:
				plank.position = Vector3(s * (HALF + 0.01), 0, 0)
				plank.rotation.x = PI / 4.0
			plank.scale = Vector3(1, 0.98, 1)
			add_child(plank)
	_flames = Node3D.new()
	_flames.visible = false
	add_child(_flames)
	for i in 4:
		var f := Burnable.flame_mesh(1.2)
		f.position = Vector3(randf_range(-0.6, 0.6), HALF + 0.4, randf_range(-0.6, 0.6))
		_flames.add_child(f)

## Afloat: move by velocity one axis at a time, stopping at walls and banks but not at whoever rides on top.
func _float_move(dt: float) -> void:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3.ONE * (SIZE - 0.06)
	q.shape = bs
	q.collision_mask = collision_mask
	var ex: Array[RID] = [get_rid()]
	for n in get_tree().get_nodes_in_group("player"):
		ex.append((n as CollisionObject3D).get_rid())
	q.exclude = ex
	for axis in [Vector3.RIGHT, Vector3.BACK, Vector3.UP]:
		var step: Vector3 = (axis as Vector3) * velocity.dot(axis) * dt
		if step.length() < 0.00001:
			continue
		q.transform = Transform3D(Basis(), global_position + step)
		if space.intersect_shape(q, 1).is_empty():
			global_position += step
		else:
			velocity -= (axis as Vector3) * velocity.dot(axis)

func _water() -> Water:
	for n in get_tree().get_nodes_in_group("water"):
		var w := n as Water
		var b := w.box
		var p := global_position
		if p.x > b.position.x and p.x < b.end.x and p.z > b.position.z and p.z < b.end.z and p.y - HALF < b.end.y and p.y > b.position.y:
			return w
	return null

func _physics_process(dt: float) -> void:
	if _gone:
		return
	wet = maxf(wet - dt, 0.0)
	var before := global_position
	var w := _water()
	floating = w != null
	if floating:
		wet = t.wet_time
		if burning:
			douse()
		var target := w.surface() + FLOAT
		if global_position.y < target:
			velocity.y = (target - global_position.y) * 4.0
		else:
			velocity.y -= t.gravity * dt
		var hv := Vector3(velocity.x, 0, velocity.z).move_toward(w.current, 3.0 * dt)
		velocity.x = hv.x
		velocity.z = hv.z
	else:
		velocity.y -= t.gravity * dt
		var push := _push_dir()
		if is_on_floor():
			velocity.x = push.x * t.crate_push_speed
			velocity.z = push.z * t.crate_push_speed
	if floating:
		_float_move(dt)
	else:
		move_and_slide()
	_carry(global_position - before)
	if burning:
		Lighting.spread_heat(global_position, HALF + 0.6, dt, self, self)
		_left -= dt
		_mat.albedo_color = Color(0.62, 0.45, 0.26).lerp(Color(0.12, 0.1, 0.08), 1.0 - _left / t.crate_burn)
		if _left <= 0.0:
			_destroy()
			return
	if respawns and (floating or global_position.y < home.y - 2.0) and Vector2(velocity.x, velocity.z).length() < 0.2 and not _ridden():
		_idle += dt
		if _idle > 6.0:
			_destroy() # left at the far side, or down a hole: back home for another go
			return
	else:
		_idle = 0.0
	if global_position.y < -30.0:
		_destroy()

## The direction the player is pushing it, if they're pushing a face on the same floor.
func _push_dir() -> Vector3:
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p.small or not p.is_on_floor() or p.hands_full():
			continue
		var d := global_position - p.global_position
		if absf((p.global_position.y - p.radius()) - (global_position.y - HALF)) > 0.6:
			continue
		var along_x := absf(d.x) >= absf(d.z)
		var into := absf(d.x) if along_x else absf(d.z)
		var side := absf(d.z) if along_x else absf(d.x)
		if into > HALF + p.radius() + 0.25 or side > HALF:
			continue
		var dir := Vector3(signf(d.x), 0, 0) if along_x else Vector3(0, 0, signf(d.z))
		if p.last_wish.dot(dir) > 0.5:
			return dir
	return Vector3.ZERO

func _ridden() -> bool:
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		var d := p.global_position - global_position
		if absf(d.x) < HALF + 0.2 and absf(d.z) < HALF + 0.2 and d.y > HALF and d.y < HALF + p.radius() + 0.4:
			return true
	return false

## Whoever stands on top moves with it.
func _carry(delta: Vector3) -> void:
	if Vector2(delta.x, delta.z).length() < 0.0001:
		return
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		var d := p.global_position - (global_position - delta)
		if absf(d.x) < HALF + 0.2 and absf(d.z) < HALF + 0.2 and d.y > HALF and d.y < HALF + p.radius() + 0.4:
			p.global_position += Vector3(delta.x, 0, delta.z)

# flammable
func heat_box() -> AABB:
	return AABB(global_position - Vector3.ONE * HALF, Vector3.ONE * SIZE)

func heat(dt: float) -> void:
	if burning or wet > 0.0 or _gone:
		return
	_warm += dt
	if _warm >= 0.3:
		ignite()

func ignite() -> void:
	if burning or wet > 0.0:
		return
	burning = true
	_left = t.crate_burn
	_flames.visible = true

## Water on it: the fire's out and it stays wet for wet_time.
func douse() -> void:
	burning = false
	_warm = 0.0
	_flames.visible = false
	wet = t.wet_time

# light source while burning
func is_shining() -> bool:
	return burning
func light_origin() -> Vector3:
	return global_position + Vector3.UP * (HALF + 0.6)
func light_reach() -> float:
	return 7.0

## A poleaxe hit or a bomb smashes it.
func hurt(_amount: int, _from: Vector3) -> void:
	_splinter()
	_destroy()

func _splinter() -> void:
	Hitfx.sparks(get_tree(), global_position, 1.5)
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 16
	p.lifetime = 0.8
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 80.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 7.0
	var bm := BoxMesh.new()
	bm.size = Vector3(0.5, 0.08, 0.15)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.45, 0.26)
	bm.material = m
	p.mesh = bm
	get_parent().add_child(p)
	p.global_position = global_position
	p.emitting = true
	get_tree().create_timer(1.2, false).timeout.connect(p.queue_free)

func _destroy() -> void:
	if _gone:
		return
	_gone = true
	if respawns:
		var parent := get_parent()
		var foot := home - Vector3.UP * HALF
		var tt := t
		get_tree().create_timer(3.0, false).timeout.connect(func() -> void:
			if is_instance_valid(parent):
				Crate.make(parent, foot, tt, true))
	queue_free()
