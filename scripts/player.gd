class_name Player
extends CharacterBody3D
## Momentum runner. On the ground, speed follows the surface: slopes add or take away speed.
## In the air, gravity is always world-down.
## Jumps chain Mario-style: land and jump again quickly, while moving, for a higher double and triple jump.
## Push into a wall while falling to slide down it, press jump to kick off it.
## Roll to dodge (brief invincibility). While holding target: locked onto a target you circle it,
## with nothing to lock you strafe facing one way; rolling sideways or back becomes a side hop or backflip.
## Health is counted in half hearts; getting hurt gives knockback and a second of invincibility.

var t: Tuning
var cam_basis := Basis() ## yaw-only camera basis; stick input is read relative to it
var spawn := Vector3.ZERO

# Scripted input for headless tests: when ai is true, ai_move is a world-space XZ direction.
# ai_jump / ai_attack_held are held buttons; ai_attack, ai_roll and ai_item press for one frame.
var ai := false
var ai_move := Vector2.ZERO
var ai_jump := false
var ai_target := false
var ai_attack := false
var ai_attack_held := false
var ai_roll := false
var ai_item := -1
var _ai_jump_prev := false

var coyote := 0.0
var buffer := 0.0
var jumping := false
var target: Node3D = null
var target_held := false
var strafing := false ## holding target with nothing to lock: facing stays put
var lock_dir := Vector3.FORWARD
var facing := Vector3.FORWARD
var visual: Node3D

# jump chain: 0 single, 1 double, 2 triple
var jump_chain := 0
var land_time := 99.0 ## seconds on the ground since the last landing
var _was_on_floor := true
var wall_lock := 0.0 ## after a wall jump, air control is off briefly so you don't steer back into the wall

var roll_t := 0.0 ## time left in a roll
var roll_buffer := 0.0 ## roll pressed slightly before landing still counts
var air_lock := 0.0 ## after a launch, hop or knockback, ignore the ground briefly so it can't cancel the upward kick
var roll_dir := Vector3.ZERO
var roll_kind := "" ## "roll", "sidehop" or "backflip"

var max_hp := 6 ## half hearts: 6 = 3 hearts
var hp := 6
var invuln := 0.0
const INVULN_TIME := 1.0
var inventory := Inventory.new()
var spear: Spear
var carrying: Bomb = null
var attack_held_t := 0.0

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

func flat_speed() -> float:
	return Vector2(velocity.x, velocity.z).length()

func boost(dir: Vector3) -> void:
	velocity = dir.normalized() * t.boost_pad_speed

## Launch pads: replace your velocity outright. Counts as a fresh jump for the chain.
func launch(v: Vector3) -> void:
	velocity = v
	up_direction = Vector3.UP
	jumping = false
	jump_chain = 0
	roll_t = 0.0
	air_lock = 0.15
	global_position += Vector3.UP * 0.1

func dodging() -> bool:
	return roll_t > 0.0 and (t.roll_time - roll_t) < t.roll_invuln

func respawn() -> void:
	global_position = spawn
	velocity = Vector3.ZERO
	up_direction = Vector3.UP
	target = null
	hp = max_hp
	invuln = 0.0
	roll_t = 0.0
	if carrying != null:
		carrying.queue_free()
		carrying = null

func hurt(amount: int, from: Vector3) -> void:
	if invuln > 0.0 or hp <= 0 or dodging():
		return
	hp -= amount
	invuln = INVULN_TIME
	roll_t = 0.0
	var away := global_position - from
	away.y = 0
	away = away.normalized() if away.length() > 0.01 else -facing
	up_direction = Vector3.UP
	velocity = away * 8.0 + Vector3.UP * 6.0
	global_position += Vector3.UP * 0.05
	air_lock = 0.1
	if hp <= 0:
		respawn()

func _flat_facing() -> Vector3:
	var f := Vector3(facing.x, 0, facing.z)
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD

## Bombs: the first press pulls one out and holds it overhead (the fuse is already burning).
## The next press throws it if you're moving, or sets it down in front of you if you're standing still.
func pull_bomb() -> void:
	carrying = Bomb.new()
	carrying.holder = self
	get_parent().add_child(carrying)
	carrying.global_position = global_position + Vector3.UP * 1.0

func release_bomb() -> void:
	if carrying == null:
		return
	var f := _flat_facing()
	var moving := _wish().length() > 0.2 or flat_speed() > 2.0
	if moving:
		carrying.throw(f * t.bomb_throw_speed + Vector3.UP * t.bomb_throw_up + Vector3(velocity.x, 0, velocity.z) * 0.3)
	else:
		carrying.set_down(global_position + f * 1.0 + Vector3.DOWN * 0.2)
	carrying = null

func _wish() -> Vector3:
	if ai:
		return Vector3(ai_move.x, 0, ai_move.y).limit_length(1.0)
	var m := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	return (cam_basis * Vector3.RIGHT) * m.x + (cam_basis * Vector3.FORWARD) * -m.y

func _physics_process(dt: float) -> void:
	var jump_pressed: bool
	var jump_held: bool
	var attack_pressed: bool
	var attack_held: bool
	var roll_pressed: bool
	var item_pressed := -1
	if ai:
		jump_pressed = ai_jump and not _ai_jump_prev
		jump_held = ai_jump
		target_held = ai_target
		_ai_jump_prev = ai_jump
		attack_pressed = ai_attack
		attack_held = ai_attack or ai_attack_held
		roll_pressed = ai_roll
		item_pressed = ai_item
		ai_attack = false
		ai_roll = false
		ai_item = -1
	else:
		jump_pressed = Input.is_action_just_pressed("jump")
		jump_held = Input.is_action_pressed("jump")
		target_held = Input.is_action_pressed("target")
		attack_pressed = Input.is_action_just_pressed("attack")
		attack_held = Input.is_action_pressed("attack")
		roll_pressed = Input.is_action_just_pressed("roll")
		for i in Inventory.SLOTS:
			if Input.is_action_just_pressed("item_%d" % (i + 1)):
				item_pressed = i
		if Input.is_action_just_pressed("respawn"):
			respawn()
	invuln = maxf(invuln - dt, 0.0)
	wall_lock = maxf(wall_lock - dt, 0.0)
	air_lock = maxf(air_lock - dt, 0.0)

	# items and attacks
	if item_pressed >= 0:
		inventory.use(item_pressed, self)
	if carrying != null and attack_pressed:
		release_bomb()
	elif inventory.has("spear") and carrying == null:
		if attack_pressed:
			spear.press()
		# hold attack to charge a spin; release to let it go
		if attack_held:
			attack_held_t += dt
		else:
			if attack_held_t >= t.spin_charge_time and is_on_floor():
				spear.spin()
			attack_held_t = 0.0
		spear.charged = attack_held_t >= t.spin_charge_time

	# targeting and strafing
	var had_strafe := strafing
	_update_target(target_held)
	strafing = target_held and target == null
	if strafing and not had_strafe:
		lock_dir = _flat_facing()

	var wish := _wish()
	buffer = t.jump_buffer if jump_pressed else maxf(buffer - dt, 0.0)
	var on_floor := is_on_floor() and air_lock <= 0.0
	if on_floor and not _was_on_floor:
		land_time = 0.0
	elif on_floor:
		land_time += dt

	roll_buffer = t.jump_buffer if roll_pressed else maxf(roll_buffer - dt, 0.0)
	if roll_buffer > 0.0 and roll_t <= 0.0 and on_floor and carrying == null:
		roll_buffer = 0.0
		_start_roll(wish)

	if roll_t > 0.0:
		_roll_step(dt, on_floor)
	elif on_floor:
		_ground_step(dt, wish)
	else:
		_air_step(dt, wish, jump_held)

	_was_on_floor = on_floor
	move_and_slide()
	if global_position.y < -30.0:
		respawn()
	_update_visual(dt)
	visual.visible = invuln <= 0.0 or fmod(invuln, 0.15) < 0.09

func _ground_step(dt: float, wish: Vector3) -> void:
	coyote = t.coyote_time
	var n := get_floor_normal()
	var v := velocity - n * velocity.dot(n)
	var g := Vector3.DOWN * t.gravity
	v += (g - n * g.dot(n)) * t.slope_factor * dt
	var sp := v.length()
	var w := wish - n * wish.dot(n)
	var top := t.strafe_speed if target_held else t.top_speed
	if w.length() > 0.05:
		var wd := w.normalized()
		if sp > 1.0 and v.normalized().dot(wd) < -0.3 and not target_held:
			v = v.move_toward(Vector3.ZERO, t.brake * dt)
		else:
			if sp > 0.5:
				var rate := lerpf(t.turn_rate, t.turn_rate_fast, clampf(sp / t.boost_speed, 0.0, 1.0))
				if target_held:
					rate = t.turn_rate * 2.0 # strafing is nimble
				v = _turn(v.normalized(), wd, rate * dt) * sp
			var cap := top * w.length()
			if sp < cap:
				v += wd * t.accel * dt
				if v.length() > cap:
					v = v.normalized() * cap
			elif target_held and sp > cap:
				v = v.move_toward(v.normalized() * cap, t.friction * dt)
	else:
		v = v.move_toward(Vector3.ZERO, t.friction * dt)
	v = v.limit_length(t.boost_speed)
	up_direction = n
	velocity = v
	if buffer > 0.0:
		_ground_jump(n)

func _air_step(dt: float, wish: Vector3, jump_held: bool) -> void:
	coyote -= dt
	up_direction = _turn(up_direction, Vector3.UP, 8.0 * dt)
	velocity += Vector3.DOWN * t.gravity * dt
	var hv := Vector3(velocity.x, 0, velocity.z)
	if wish.length() > 0.05 and wall_lock <= 0.0:
		var cap := maxf(t.top_speed, hv.length())
		hv = (hv + wish * t.air_accel * dt).limit_length(cap)
		velocity.x = hv.x
		velocity.z = hv.z
	# walls: slide down slowly while pushing into one, kick off with jump
	var wall := is_on_wall()
	var wn := Vector3.ZERO
	if wall:
		wn = get_wall_normal()
		wn.y = 0
		wall = wn.length() > 0.7
		wn = wn.normalized()
	if wall and buffer > 0.0:
		_wall_jump(wn)
	elif buffer > 0.0 and coyote > 0.0:
		_ground_jump(Vector3.UP)
	elif wall and velocity.y < -t.wall_slide_speed and wish.dot(-wn) > 0.3:
		velocity.y = -t.wall_slide_speed
	if jumping and not jump_held and velocity.y > t.jump_cut:
		velocity.y = t.jump_cut
	if velocity.y <= 0.0:
		jumping = false

## Mario-style chain: jump again within jump_combo_window of landing, while moving, to go higher.
## The third jump needs real speed (triple_min_speed). Any pause resets it to a single jump.
func _ground_jump(n: Vector3) -> void:
	var chained := land_time <= t.jump_combo_window and flat_speed() > 2.0
	if chained and jump_chain < 2:
		jump_chain += 1
		if jump_chain == 2 and flat_speed() < t.triple_min_speed:
			jump_chain = 1
	else:
		jump_chain = 0
	var mult: float = [1.0, t.double_jump_mult, t.triple_jump_mult][jump_chain]
	velocity = velocity - n * velocity.dot(n) + n * t.jump_speed * mult
	global_position += n * 0.05 # clear the floor so this frame's move can't read as grounded
	jumping = true
	buffer = 0.0
	coyote = 0.0
	land_time = 99.0

func _wall_jump(wn: Vector3) -> void:
	velocity = wn * t.wall_jump_speed + Vector3.UP * t.wall_jump_up
	facing = wn
	jumping = true
	buffer = 0.0
	wall_lock = 0.18
	jump_chain = 0

func _start_roll(wish: Vector3) -> void:
	var dir := wish.normalized() if wish.length() > 0.2 else _flat_facing()
	roll_kind = "roll"
	if target_held:
		var f := lock_dir if strafing else _flat_facing()
		var side := f.cross(Vector3.UP)
		# pick whichever of back / left / right the stick is closest to
		var back := dir.dot(-f)
		var across := absf(dir.dot(side))
		if wish.length() > 0.2 and back > 0.5 and back >= across:
			roll_kind = "backflip"
			dir = -f
		elif wish.length() > 0.2 and across > 0.5 and across > back:
			roll_kind = "sidehop"
			dir = side * signf(dir.dot(side))
	roll_dir = dir
	roll_t = t.roll_time
	match roll_kind:
		"roll":
			velocity = dir * t.roll_speed
		"sidehop":
			velocity = dir * t.roll_speed * 0.8 + Vector3.UP * 5.0
			global_position += Vector3.UP * 0.05
			air_lock = 0.1
		"backflip":
			velocity = dir * 5.0 + Vector3.UP * t.jump_speed * 1.1
			global_position += Vector3.UP * 0.05
			air_lock = 0.1

func _roll_step(dt: float, on_floor: bool) -> void:
	roll_t -= dt
	if roll_kind == "roll":
		var v := roll_dir * t.roll_speed
		velocity.x = v.x
		velocity.z = v.z
		if not on_floor:
			velocity.y -= t.gravity * dt
		if roll_t <= 0.0:
			# come out of the roll at running speed
			velocity.x = roll_dir.x * minf(t.roll_speed, t.top_speed)
			velocity.z = roll_dir.z * minf(t.roll_speed, t.top_speed)
	else:
		velocity.y -= t.gravity * dt
		if (on_floor and roll_t < t.roll_time - 0.1) or roll_t <= -0.6:
			roll_t = 0.0

## Blend unit vector a toward b by k (0-1). Lerp-and-normalize stays stable when a and b are nearly parallel.
func _turn(a: Vector3, b: Vector3, k: float) -> Vector3:
	var r := a.lerp(b, clampf(k, 0.0, 1.0))
	return r.normalized() if r.length() > 0.001 else b

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
	elif strafing:
		f = lock_dir
	elif roll_t > 0.0 and roll_kind == "roll":
		f = roll_dir
	elif wall_lock > 0.0:
		f = facing
	else:
		f = velocity
	f = f - up * f.dot(up)
	if f.length() > 0.5 or (strafing and f.length() > 0.01):
		facing = _turn(facing, f.normalized(), 12.0 * dt)
	var fwd := facing - up * facing.dot(up)
	if fwd.length() < 0.01:
		return
	visual.global_basis = Basis.looking_at(fwd.normalized(), up)
	if roll_t > 0.0 and roll_kind != "sidehop":
		var spin := (1.0 - roll_t / t.roll_time) * TAU * (1.0 if roll_kind == "roll" else -1.0)
		visual.rotate_object_local(Vector3.RIGHT, -spin)
