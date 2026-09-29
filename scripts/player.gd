class_name Player
extends CharacterBody3D
## Momentum runner. On the ground, speed follows the surface: slopes add or take away speed,
## and fast enough you stick to walls and ceilings (loops). In the air, gravity is always world-down.
## Holding target locks onto the nearest target and turns movement into strafing.
## Health is counted in half hearts; getting hurt gives knockback and a second of invincibility.

var t: Tuning
var cam_basis := Basis() ## yaw-only camera basis; stick input is read relative to it
var spawn := Vector3.ZERO

# Scripted input for headless tests: when ai is true, ai_move is a world-space XZ direction.
var ai := false
var ai_move := Vector2.ZERO
var ai_jump := false
var ai_target := false
var _ai_jump_prev := false

var coyote := 0.0
var buffer := 0.0
var jumping := false
var target: Node3D = null
var facing := Vector3.FORWARD
var visual: Node3D

var max_hp := 6 ## half hearts: 6 = 3 hearts
var hp := 6
var invuln := 0.0
const INVULN_TIME := 1.0
var inventory := Inventory.new()
var spear: Spear
# Scripted input for tests: set to true for one frame to press the button
var ai_attack := false
var ai_item := -1

func _ready() -> void:
	add_to_group("player")
	add_to_group("hurtable")
	floor_max_angle = deg_to_rad(55)
	floor_snap_length = 0.7
	floor_stop_on_slope = false
	floor_block_on_wall = false
	max_slides = 6
	var col := CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = 0.5
	col.shape = sphere
	add_child(col)
	visual = Node3D.new()
	add_child(visual)
	var body := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = 0.5
	bm.height = 1.0
	body.mesh = bm
	body.material_override = _mat(Color(0.2, 0.45, 0.95))
	visual.add_child(body)
	var nose := MeshInstance3D.new()
	var nm := BoxMesh.new()
	nm.size = Vector3(0.3, 0.2, 0.45)
	nose.mesh = nm
	nose.position = Vector3(0, 0.1, -0.45)
	nose.material_override = _mat(Color(0.95, 0.85, 0.7))
	visual.add_child(nose)
	spear = Spear.new()
	spear.player = self
	visual.add_child(spear)

func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m

func speed() -> float:
	return velocity.length()

func boost(dir: Vector3) -> void:
	velocity = dir.normalized() * t.boost_pad_speed

func respawn() -> void:
	global_position = spawn
	velocity = Vector3.ZERO
	up_direction = Vector3.UP
	target = null
	hp = max_hp
	invuln = 0.0

func hurt(amount: int, from: Vector3) -> void:
	if invuln > 0.0 or hp <= 0:
		return
	hp -= amount
	invuln = INVULN_TIME
	var away := global_position - from
	away.y = 0
	away = away.normalized() if away.length() > 0.01 else -facing
	up_direction = Vector3.UP
	velocity = away * 8.0 + Vector3.UP * 6.0
	global_position += Vector3.UP * 0.05
	if hp <= 0:
		respawn()

func place_bomb() -> void:
	var f := facing - Vector3.UP * facing.dot(Vector3.UP)
	var b := Bomb.new()
	get_parent().add_child(b)
	b.global_position = global_position + (f.normalized() if f.length() > 0.01 else Vector3.FORWARD) * 1.0 + Vector3.DOWN * 0.5

func _wish() -> Vector3:
	if ai:
		return Vector3(ai_move.x, 0, ai_move.y).limit_length(1.0)
	var m := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return (cam_basis * Vector3.RIGHT) * m.x + (cam_basis * Vector3.FORWARD) * -m.y

func _physics_process(dt: float) -> void:
	var jump_pressed: bool
	var jump_held: bool
	var target_held: bool
	if ai:
		jump_pressed = ai_jump and not _ai_jump_prev
		jump_held = ai_jump
		target_held = ai_target
		_ai_jump_prev = ai_jump
	else:
		jump_pressed = Input.is_action_just_pressed("jump")
		jump_held = Input.is_action_pressed("jump")
		target_held = Input.is_action_pressed("target")
		if Input.is_action_just_pressed("respawn"):
			respawn()
		if Input.is_action_just_pressed("attack") and inventory.has("spear"):
			spear.attack()
		for i in Inventory.SLOTS:
			if Input.is_action_just_pressed("item_%d" % (i + 1)):
				inventory.use(i, self)
	if ai:
		if ai_attack and inventory.has("spear"):
			spear.attack()
		if ai_item >= 0:
			inventory.use(ai_item, self)
		ai_attack = false
		ai_item = -1
	invuln = maxf(invuln - dt, 0.0)
	_update_target(target_held)
	var wish := _wish()
	buffer = t.jump_buffer if jump_pressed else maxf(buffer - dt, 0.0)

	if is_on_floor():
		coyote = t.coyote_time
		var n := get_floor_normal()
		var v := velocity - n * velocity.dot(n)
		var g := Vector3.DOWN * t.gravity
		v += (g - n * g.dot(n)) * t.slope_factor * dt
		var sp := v.length()
		var w := wish - n * wish.dot(n)
		if n.y < 0.7 and sp > 1.0:
			# on walls and ceilings "forward" means "keep going the way you are going"
			w = v.normalized() * wish.length()
		if w.length() > 0.05:
			var wd := w.normalized()
			if sp > 1.0 and v.normalized().dot(wd) < -0.3:
				v = v.move_toward(Vector3.ZERO, t.brake * dt)
			else:
				if sp > 0.5:
					var rate := lerpf(t.turn_rate, t.turn_rate_fast, clampf(sp / t.boost_speed, 0.0, 1.0))
					v = _turn(v.normalized(), wd, rate * dt) * sp
				var cap := t.top_speed * w.length()
				if sp < cap:
					v += wd * t.accel * dt
					if v.length() > cap:
						v = v.normalized() * cap
		else:
			v = v.move_toward(Vector3.ZERO, t.friction * dt)
		v = v.limit_length(t.boost_speed)
		if n.y < 0.3 and v.length() < t.stick_speed:
			# too slow for a wall or ceiling: peel off
			up_direction = Vector3.UP
			velocity = v + n * 2.0
		else:
			up_direction = n
			# press into steep surfaces so fast curves hold; flat ground relies on floor snap
			velocity = v - n * (2.0 if n.y < 0.7 else 0.0)
		if buffer > 0.0:
			_jump(n)
	else:
		coyote -= dt
		up_direction = _turn(up_direction, Vector3.UP, 8.0 * dt)
		velocity += Vector3.DOWN * t.gravity * dt
		var hv := Vector3(velocity.x, 0, velocity.z)
		if wish.length() > 0.05:
			var cap := maxf(t.top_speed, hv.length())
			hv = (hv + wish * t.air_accel * dt).limit_length(cap)
			velocity.x = hv.x
			velocity.z = hv.z
		if buffer > 0.0 and coyote > 0.0:
			_jump(Vector3.UP)
		if jumping and not jump_held and velocity.y > t.jump_cut:
			velocity.y = t.jump_cut
		if velocity.y <= 0.0:
			jumping = false

	move_and_slide()
	if global_position.y < -30.0:
		respawn()
	_update_visual(dt)
	visual.visible = invuln <= 0.0 or fmod(invuln, 0.15) < 0.09

## Blend unit vector a toward b by k (0-1). Lerp-and-normalize stays stable when a and b are nearly parallel.
func _turn(a: Vector3, b: Vector3, k: float) -> Vector3:
	var r := a.lerp(b, clampf(k, 0.0, 1.0))
	return r.normalized() if r.length() > 0.001 else b

func _jump(n: Vector3) -> void:
	velocity = velocity - n * velocity.dot(n) + n * t.jump_speed
	global_position += n * 0.05 # clear the floor so this frame's move can't read as grounded
	jumping = true
	buffer = 0.0
	coyote = 0.0

func _update_target(held: bool) -> void:
	if not held:
		target = null
		return
	if target != null and is_instance_valid(target) and target.global_position.distance_to(global_position) < 25.0:
		return
	target = null
	var best := 20.0
	for n in get_tree().get_nodes_in_group("targets"):
		var d: float = (n as Node3D).global_position.distance_to(global_position)
		if d < best:
			best = d
			target = n

func _update_visual(dt: float) -> void:
	var up := up_direction
	var f: Vector3
	if target != null:
		f = target.global_position - global_position
	else:
		f = velocity
	f = f - up * f.dot(up)
	if f.length() > 0.5:
		facing = _turn(facing, f.normalized(), 12.0 * dt)
	var fwd := facing - up * facing.dot(up)
	if fwd.length() < 0.01:
		return
	visual.global_basis = Basis.looking_at(fwd.normalized(), up)
