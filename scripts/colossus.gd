class_name Colossus
extends Node3D
## The test colossus: a 13 m stone beast that walks a slow circle in its own arena (x 56..104, z -118..-70).
## - Climb it. Its rear legs have fur on their outer sides, running all the way up to its back (13 m).
##   Push into the fur to climb, and pull yourself over the top. It stands still while you're on it.
## - Its front shins are breakable: a bomb blast shatters one (bomb plants grow at the arena's north edge).
##   With one shin gone it limps; with both gone it falls to its knees and its head comes down to the ground.
## - Two weak points (glowing sigils). One is on its back under a bone plate: ground pound the plate to crack
##   it off, then hit the sigil. The other is on its forehead, and it only opens once it kneels.
##   Hit both and it's felled.
## - Its feet hurt when it steps on you.

const CENTER := Vector3(80, 0, -94)
const PATROL := 10.0 ## radius of the circle it walks
const STONE := Color(0.55, 0.52, 0.48)
const FUR := Color(0.45, 0.35, 0.25)
const GLOW := Color(0.3, 0.9, 1.0)
const HIP := Vector3(0, 9, 6) ## the rear hips: it kneels by pitching forward around them
const KNEEL_ANGLE := 22.0

var lv: Node3D
var t: Tuning
var pivot: Node3D
var parts: Array[AnimatableBody3D] = []
var fur: Array[AnimatableBody3D] = []
var shins: Array[AnimatableBody3D] = []
var plate: AnimatableBody3D
var sigils: Array[ColossusSigil] = []
var feet: Array[Vector3] = [] ## local, at ground level
var angle := 0.0 ## where it is on its circle
var kneel := 0.0 ## 0 standing, 1 on its knees
var felled := false
var stopped := false ## this frame: someone is riding it
var _bob := 0.0
var _shake := 0.0

static func build(level: Node3D) -> Colossus:
	var c := Colossus.new()
	c.lv = level
	c.t = level.t
	c._place()
	level.add_child(c)
	c._make()
	level.marks["colossus"] = c
	level.marks["colossus_arena"] = CENTER + Vector3(0, 0.6, 20)
	level.label(CENTER + Vector3(0, 3, 22), "test colossus: climb its furry back legs, bomb its front shins", 32)
	BombFlower.make(level, CENTER + Vector3(-6, 0, 21), level.t)
	BombFlower.make(level, CENTER + Vector3(6, 0, 21), level.t)
	return c

## Put it on its circle, facing along it (counter-clockwise from above).
func _place() -> void:
	position = CENTER + Vector3(cos(angle), 0, sin(angle)) * PATROL
	var ahead := Vector3(-sin(angle), 0, cos(angle))
	basis = Basis.looking_at(ahead, Vector3.UP) # its head is at local -z

func _make() -> void:
	pivot = Node3D.new()
	pivot.position = HIP
	add_child(pivot)
	_part(Vector3(0, 11, 0), Vector3(7, 4, 16), STONE) # torso, top at 13
	_part(Vector3(0, 11, 10.5), Vector3(1.6, 1.6, 5), STONE) # tail
	_part(Vector3(0, 9.8, -8.8), Vector3(2.6, 2.6, 2.6), STONE) # neck
	var head := _part(Vector3(0, 8.5, -11.5), Vector3(3.4, 3.4, 3.4), STONE)
	for eye in [-0.9, 0.9]:
		var e := MeshInstance3D.new()
		var em := BoxMesh.new()
		em.size = Vector3(0.5, 0.3, 0.1)
		e.mesh = em
		e.material_override = _glow(Color(1.0, 0.4, 0.2))
		e.position = Vector3(eye, 0.6, -1.72)
		head.add_child(e)
	for side in [-1.0, 1.0]:
		_part(Vector3(side * 2.3, 4.5, 5.5), Vector3(2.4, 9, 2.4), STONE) # rear leg
		var f := _part(Vector3(side * 3.65, 6.5, 5.5), Vector3(0.3, 13, 2.8), FUR) # fur up the rear leg to the back
		f.add_to_group("climbable")
		fur.append(f)
		_part(Vector3(side * 2.3, 6.75, -5.5), Vector3(2.4, 4.5, 2.4), STONE) # front thigh
		var shin := ColossusShin.new()
		shin.colossus = self
		_part(Vector3(side * 2.3, 2.25, -5.5), Vector3(2.4, 4.5, 2.4), Color(0.62, 0.5, 0.35), shin)
		var band := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(2.6, 0.6, 2.6)
		band.mesh = bm
		var bronze := StandardMaterial3D.new()
		bronze.albedo_color = Color(0.7, 0.45, 0.2)
		bronze.metallic = 0.6
		band.material_override = bronze
		band.position.y = 0.8
		shin.add_child(band)
		shins.append(shin)
		feet.append(Vector3(side * 2.3, 0, 5.5))
		feet.append(Vector3(side * 2.3, 0, -5.5))
	plate = _part(Vector3(0, 13.3, 1), Vector3(3, 0.6, 3), Color(0.9, 0.87, 0.78))
	plate.add_to_group("poundable")
	plate.set_meta("on_pound", pounded.bind(plate))
	sigils.append(_sigil(Vector3(0, 13.1, 1), Vector3(1.4, 0.2, 1.4), false))
	sigils.append(_sigil(Vector3(0, 8.5, -13.35), Vector3(1.2, 1.2, 0.3), false))

## A box part hung off the pivot, given in the colossus's own frame (ground at y 0, head toward -z).
func _part(at: Vector3, size: Vector3, col: Color, b: AnimatableBody3D = null) -> AnimatableBody3D:
	if b == null:
		b = AnimatableBody3D.new()
	b.sync_to_physics = false
	b.position = at - HIP
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	b.add_child(c)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	mi.material_override = m
	b.add_child(mi)
	pivot.add_child(b)
	parts.append(b)
	return b

func _glow(col: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col
	return m

func _sigil(at: Vector3, size: Vector3, open: bool) -> ColossusSigil:
	var s := ColossusSigil.new()
	s.colossus = self
	s.size = size
	s.position = at - HIP
	pivot.add_child(s)
	if open:
		s.open()
	return s

## Called by Player when a ground pound lands on the bone plate.
func pounded(part: Node3D) -> void:
	if part != plate or plate == null:
		return
	_crumble(plate, Color(0.9, 0.87, 0.78))
	plate = null
	sigils[0].open()
	_shake = 0.5

## A bomb blast broke a front shin (ColossusShin.blast).
func shin_broken(shin: AnimatableBody3D) -> void:
	if not shins.has(shin):
		return
	shins.erase(shin)
	_crumble(shin, Color(0.62, 0.5, 0.35))
	_shake = 0.6
	if shins.is_empty():
		sigils[1].open() # down on its knees, its forehead opens

func sigil_struck(_s: ColossusSigil) -> void:
	_shake = 0.6
	for s in sigils:
		if not s.struck:
			return
	fall()

## Both weak points are struck: it breaks apart.
func fall() -> void:
	if felled:
		return
	felled = true
	Hitfx.sparks(get_tree(), global_position + Vector3.UP * 10, 4.0)
	Hitfx.shake(get_tree(), 0.8)
	for b in parts.duplicate():
		if is_instance_valid(b):
			_crumble(b, STONE)
	for s in sigils:
		s.queue_free()
	lv.label(global_position + Vector3.UP * 4, "felled", 64)

## Shatter a part into falling rubble.
func _crumble(b: Node3D, col: Color) -> void:
	var at := b.global_position
	for k in 10:
		var chunk := RigidBody3D.new()
		chunk.collision_layer = 0
		chunk.collision_mask = 1
		var c := CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = Vector3(0.7, 0.7, 0.7)
		c.shape = s
		chunk.add_child(c)
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = s.size
		mi.mesh = bm
		var m := StandardMaterial3D.new()
		m.albedo_color = col
		mi.material_override = m
		chunk.add_child(mi)
		chunk.position = at + Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1))
		lv.add_child(chunk)
		chunk.linear_velocity = Vector3(randf_range(-4, 4), randf_range(1, 5), randf_range(-4, 4))
		get_tree().create_timer(2.0).timeout.connect(chunk.queue_free)
	Hitfx.sparks(get_tree(), at, 2.0)
	parts.erase(b)
	fur.erase(b)
	b.queue_free()

## Is the player on it: climbing its fur, or standing somewhere on top of it?
func ridden() -> bool:
	var p: Player = lv.player
	if p == null or felled:
		return false
	if is_instance_valid(p.climbing) and p.climbing is AnimatableBody3D and fur.has(p.climbing):
		return true
	if not p.is_on_floor():
		return false
	for i in p.get_slide_collision_count():
		var col := p.get_slide_collision(i)
		var n := col.get_collider()
		if n is AnimatableBody3D and (parts.has(n) or n is ColossusSigil) and col.get_normal().y > 0.5:
			return true
	return false

func _physics_process(dt: float) -> void:
	if felled:
		return
	kneel = move_toward(kneel, 1.0 if shins.is_empty() else 0.0, dt)
	stopped = ridden()
	var moving := not stopped and kneel == 0.0
	if moving:
		var speed := t.colossus_speed * (0.6 if shins.size() < 2 else 1.0)
		angle += speed / PATROL * dt
		_bob += dt * speed * 1.6
		_place()
	_shake = maxf(_shake - dt, 0.0)
	var jitter := Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.08 * (1.0 if _shake > 0.0 else 0.0)
	pivot.position = HIP + Vector3.UP * (absf(sin(_bob)) * 0.15 if moving else 0.0) + jitter
	pivot.rotation.x = -deg_to_rad(KNEEL_ANGLE) * kneel
	if moving:
		_stomp()

## Its feet come down hard on anything under them.
func _stomp() -> void:
	var p: Player = lv.player
	if p == null or p.global_position.y > 2.5:
		return
	for i in feet.size():
		if i % 2 == 1 and not shins_has_side(i):
			continue
		var f := to_global(feet[i])
		if Vector2(f.x - p.global_position.x, f.z - p.global_position.z).length() < 1.2 + p.radius():
			p.hurt(1, f)

## Front feet are gone once their shin breaks.
func shins_has_side(i: int) -> bool:
	var side := -1.0 if i < 2 else 1.0
	for s in shins:
		if signf(s.position.x) == side:
			return true
	return false

## World point just outside a rear leg's fur, at the ground, for walking up to it (side -1 left, +1 right).
func fur_foot(side: float) -> Vector3:
	return to_global(Vector3(side * 4.6, 0.6, 5.5))
