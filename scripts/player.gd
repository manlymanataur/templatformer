class_name Player
extends CharacterBody3D
## Momentum runner. On the ground, speed follows the surface: slopes add or take away speed.
## In the air, gravity is always world-down.
## Jumps chain Mario-style: land and jump again quickly, while moving, for a higher double and triple jump.
## Push into a wall while falling to slide down it, press jump to kick off it.
## While holding target: locked onto a target you circle it, with nothing to lock you strafe facing one way.
## Holding target, a quick tap of the stick (out of neutral and back) dodges that way with brief invincibility:
## forward rolls, sideways side hops, back backflips. There's no roll button; without target a tap just steps.
## Speed above top_speed (from slopes, pads, launches) bleeds back down at overspeed_decay on flat ground.
## The candle hat (a quick-slot item) makes you a light source and sets fire to what you touch.
## While you aren't giving off light, your body blocks light like any solid thing: see Lighting.
## A shrink pad makes you small and a grow pad normal again. Small you're slower and jump lower, but you slip
## through grates and bars, float on water and ride the wind. With the magnet, iron moves you instead of you
## moving it: pull flies you to the nearest iron in line, push flies you away from it. Growing back needs room.
## Health is counted in half hearts; getting hurt gives knockback and a second of invincibility.

var t: Tuning
var cam_basis := Basis() ## yaw-only camera basis; stick input is read relative to it
var spawn := Vector3.ZERO

# Scripted input for headless tests: when ai is true, ai_move is a world-space XZ direction.
# ai_jump / ai_attack_held are held buttons; ai_attack and ai_item press for one frame. Rolls come from tapping ai_move.
var ai := false
var ai_move := Vector2.ZERO
var ai_jump := false
var ai_target := false
var ai_attack := false
var ai_attack_held := false
var ai_item := -1
var ai_context := false ## presses the context button for one frame
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
var god := false ## debug menu: nothing hurts you
const INVULN_TIME := 1.0
var inventory := Inventory.new()
var spear: Spear
var carrying: Bomb = null
var attack_held_t := 0.0
var candle_lit := false ## wearing the lit candle hat
var magnet_push := false ## magnet polarity: false = negative (pull), true = positive (push)
var umbra: Umbra = null
var last_wish := Vector3.ZERO ## this frame's movement input, which Umbra mirrors
var _tap_t := -1.0 ## how long the stick has been out of neutral in the current tap, -1 when not tapping
var _tap_dir := Vector3.ZERO
var _prev_wish_len := 0.0
var _roll_wish := Vector3.ZERO ## direction of a tap dodge waiting to start
var _hat: Node3D
var _candle_light: OmniLight3D
var spider: Spider = null ## the clockwork spider, once it's out of your pack
var pilot: Spider = null ## the spider you're steering; you sit still meanwhile
var leash: Tether = null ## the lash hooked on the spider
var held_seed: Seed = null
var grapple_to := Vector3.ZERO ## the lash is pulling you here
var grapple_t := 0.0
var climbing: Node3D = null ## the climbable wall or trunk you're on
var homing: Node3D = null ## the air attack is flying you at this
var homing_t := 0.0
var hang := Vector3.ZERO ## hanging from a ledge: the ledge's top edge point (ZERO when not hanging)
var hang_n := Vector3.ZERO ## the ledge wall's normal
var rail: Rail = null ## grinding this rail
var rail_s := 0.0 ## distance along it
var rail_dir := 1.0
var rail_speed := 0.0
var _rail_cool := 0.0
var _teleported := 0 ## frames until moving floors pass their motion on again
var _pogo_last: Node3D = null ## what you last bounced off; homing skips it until you land
var _flick: MeshInstance3D
var _flick_t := 0.0
var small := false ## shrunk on a shrink pad
var magnet_flying := false ## small, and the magnet is carrying you along an iron's line
var _col: CollisionShape3D
const RADIUS := 0.5

func _ready() -> void:
	add_to_group("player")
	add_to_group("hurtable")
	floor_max_angle = deg_to_rad(55)
	floor_snap_length = 0.7
	floor_stop_on_slope = false
	floor_block_on_wall = false
	max_slides = 6
	collision_mask = 1 | 1 << 1 | 1 << 2 | 1 << 4 # the world, bars and railings, grates (until you shrink), props (seed cubes, the spider)
	_col = CollisionShape3D.new()
	var sphere := SphereShape3D.new()
	sphere.radius = RADIUS
	_col.shape = sphere
	add_child(_col)
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
	add_to_group("light_sources")
	_hat = Node3D.new()
	_hat.position = Vector3(0, 0.45, 0)
	_hat.visible = false
	visual.add_child(_hat)
	var brim := MeshInstance3D.new()
	var brm := CylinderMesh.new()
	brm.top_radius = 0.32
	brm.bottom_radius = 0.32
	brm.height = 0.05
	brim.mesh = brm
	brim.material_override = _mat(Color(0.35, 0.25, 0.2))
	_hat.add_child(brim)
	var wax := MeshInstance3D.new()
	var wm := CylinderMesh.new()
	wm.top_radius = 0.09
	wm.bottom_radius = 0.1
	wm.height = 0.35
	wax.mesh = wm
	wax.material_override = _mat(Color(0.95, 0.92, 0.82))
	wax.position.y = 0.2
	_hat.add_child(wax)
	var flame := Burnable.flame_mesh(0.25)
	flame.position.y = 0.5
	_hat.add_child(flame)
	_candle_light = OmniLight3D.new()
	_candle_light.light_color = Color(1.0, 0.75, 0.45)
	_candle_light.light_energy = 1.4
	_candle_light.position = Vector3(0, 1.0, 0)
	_candle_light.visible = false
	add_child(_candle_light)
	_flick = MeshInstance3D.new()
	_flick.mesh = ImmediateMesh.new()
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.albedo_color = Color(0.85, 0.7, 0.4)
	_flick.material_override = fm
	_flick.top_level = true
	add_child(_flick)

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

## Candle hat: wearing it lit makes you a light source (and fire). Returns the new state.
func set_candle(on: bool) -> void:
	candle_lit = on
	_hat.visible = on
	_candle_light.visible = on
	_candle_light.omni_range = t.candle_range
	inventory.changed.emit()

## Umbra: call the ghost beside you, or send it away if it's already out.
func toggle_umbra() -> void:
	if umbra != null:
		umbra.fade()
	else:
		umbra = Umbra.summon(self)
	inventory.changed.emit()

## Shrink or grow back. Your feet stay where they are. Growing needs room for your full size: pressed against
## a wall you're nudged clear of it, but inside a grate or under something low it fails and you stay small.
## Returns whether you ended up the size you asked for. force skips the room check (tests resetting you).
func set_small(on: bool, force := false) -> bool:
	if on == small:
		return true
	var r_new := RADIUS * (t.small_scale if on else 1.0)
	var at := global_position + Vector3.UP * (r_new - radius())
	if not on and not force:
		var q := PhysicsShapeQueryParameters3D.new()
		var s := SphereShape3D.new()
		s.radius = r_new - 0.02
		q.shape = s
		q.collision_mask = 1 | 1 << 1 | 1 << 2
		q.exclude = [get_rid()]
		var room := false
		for nudge in [Vector3.ZERO, Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
			q.transform = Transform3D(Basis(), at + (nudge as Vector3) * (r_new - radius()))
			if get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty():
				at = q.transform.origin
				room = true
				break
		if not room:
			return false
	small = on
	(_col.shape as SphereShape3D).radius = r_new
	global_position = at
	collision_mask = (1 if small else 1 | 1 << 1 | 1 << 2) | 1 << 4 # small, grates, fences and bars don't stop you; props (seed cubes, the spider) always do
	magnet_flying = false
	inventory.changed.emit()
	return true

func radius() -> float:
	return RADIUS * (t.small_scale if small else 1.0)

func _size_mult() -> float:
	return t.small_speed_mult if small else 1.0

func item_active(id: String) -> bool:
	match id:
		"candle":
			return candle_lit
		"umbra":
			return umbra != null
		"spider":
			return pilot != null
		"lash":
			return leash != null
	return false

# light source (see Lighting)
func is_shining() -> bool:
	return candle_lit
func light_origin() -> Vector3:
	return global_position + Vector3.UP * 1.0
func light_reach() -> float:
	return t.candle_range

func dodging() -> bool:
	return roll_t > 0.0 and (t.roll_time - roll_t) < t.roll_invuln

## Move straight to pos, standing still. Whatever you stood on doesn't pass its motion on (a monster that was
## just placed looks to the physics like it moved 50 m in a frame, and you'd be flung with it).
func teleport(pos: Vector3) -> void:
	global_position = pos
	velocity = Vector3.ZERO
	up_direction = Vector3.UP
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	_teleported = 2

func respawn() -> void:
	teleport(spawn)
	up_direction = Vector3.UP
	target = null
	hp = max_hp
	invuln = 0.0
	roll_t = 0.0
	if carrying != null:
		carrying.queue_free()
		carrying = null
	if small:
		set_small(false)
	drop_holds()

## Let go of everything: the seed you carry, the leash, the spider you're steering.
func drop_holds() -> void:
	if held_seed != null:
		held_seed.set_down(global_position + Vector3.UP * 0.2)
		held_seed = null
	if leash != null:
		leash.queue_free()
		leash = null
	if pilot != null:
		pilot.let_go()
		pilot = null
	grapple_t = 0.0
	climbing = null
	homing = null
	hang = Vector3.ZERO
	rail = null

## Where the camera looks: the spider while you steer it, otherwise you.
func focus() -> Node3D:
	return pilot if pilot != null else self

func hands_full() -> bool:
	return held_seed != null or carrying != null

## The spider item: the first press sends it out and you steer it; every press after swaps between steering
## it and steering yourself. (Pick it back up with the context button next to it.)
func use_spider() -> void:
	if pilot != null:
		pilot.let_go()
		pilot = null
		return
	if spider == null or not is_instance_valid(spider):
		if not is_on_floor() or hands_full():
			return
		spider = Spider.deploy(self)
	velocity = Vector3(0, velocity.y, 0)
	pilot = spider
	spider.take_control()

## The spider climbs back into your pack.
func stow_spider() -> void:
	if leash != null:
		leash.queue_free()
		leash = null
	if spider != null and is_instance_valid(spider):
		spider.queue_free()
	spider = null
	pilot = null
	inventory.changed.emit()

## The lash: crack it straight ahead, or at what you're locked on to. It pulls you to a post or trunk,
## fetches a loose seed into your hands, stings and yanks a monster, or hooks the spider as a leash.
## With the spider already hooked, it lets go. Your hands must be empty.
func use_lash() -> void:
	if leash != null:
		leash.queue_free()
		leash = null
		return
	if hands_full() or pilot != null:
		return
	var from := global_position + Vector3.UP * 0.1
	var dir := _flat_facing()
	if target != null and is_instance_valid(target):
		dir = (target.global_position - from).normalized()
	var to := from + dir * t.lash_range
	var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 1 << 4, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	var end := to if hit.is_empty() else (hit["position"] as Vector3)
	_show_flick(from, end)
	if hit.is_empty():
		return
	var c: Node = hit["collider"]
	if c is Spider:
		leash = Tether.make(get_parent(), self, c, t.leash_length, Color(0.85, 0.7, 0.4))
	elif c is Seed and (c as Seed).loose():
		held_seed = c
		held_seed.hold(self)
	elif c.is_in_group("lash_posts"):
		var flat := Vector3(dir.x, 0, dir.z).normalized()
		grapple_to = end - flat * 0.7
		grapple_t = from.distance_to(end) / t.lash_pull_speed + 0.3
		jumping = false
		air_lock = 0.2
	elif c.is_in_group("hurtable") and c != self:
		c.hurt(1, global_position)
		if "velocity" in c:
			c.velocity = (global_position - (c as Node3D).global_position).normalized() * 9.0 + Vector3.UP * 3.0

func _show_flick(a: Vector3, b: Vector3) -> void:
	var m := _flick.mesh as ImmediateMesh
	m.clear_surfaces()
	m.surface_begin(Mesh.PRIMITIVE_LINES)
	m.surface_add_vertex(a)
	m.surface_add_vertex(b)
	m.surface_end()
	_flick_t = 0.18
	_flick.visible = true

## Context button with a seed in your hands: set down in front of you on soil, mud or roots, it plants;
## otherwise you throw it (moving) or set it down (standing still).
func release_seed() -> void:
	var sd := held_seed
	var f := _flat_facing()
	var front := global_position + f * (radius() + Seed.HALF + 0.1) + Vector3.UP * (Seed.HALF - radius() + 0.05)
	var moving := _wish().length() > 0.2 or flat_speed() > 2.0
	var room := _room_for_cube(front)
	if not moving and not room:
		return # no room in front: keep holding it
	held_seed = null
	if room:
		sd.set_down(front)
		if sd.can_plant():
			sd.plant()
			return
	if moving:
		sd.set_down(global_position + Vector3.UP * (radius() + Seed.HALF + 0.1))
		sd.throw(f * t.bomb_throw_speed + Vector3.UP * t.bomb_throw_up + Vector3(velocity.x, 0, velocity.z) * 0.3)

func _room_for_cube(at: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var b := BoxShape3D.new()
	b.size = Vector3.ONE * (Seed.SIZE - 0.1)
	q.shape = b
	q.transform = Transform3D(Basis(), at + Vector3.UP * 0.05)
	q.collision_mask = 1 | 1 << 1 | 1 << 2 | 1 << 4
	q.exclude = [get_rid()] + ([held_seed.get_rid()] if held_seed != null else [])
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

## Context button with empty hands next to a seed picks it up, and next to a planted one pulls it up.
## Returns true if it was used that way.
func _grab_seed() -> bool:
	for n in get_tree().get_nodes_in_group("seeds"):
		var sd := n as Seed
		var d := sd.global_position - global_position
		if (sd.loose() or sd.planted) and _next_to_cube(d):
			if sd.planted:
				sd.uproot(self)
			else:
				sd.hold(self)
			held_seed = sd
			return true
	return false

## d is from you to a cube's centre: are you touching one of its sides?
func _next_to_cube(d: Vector3) -> bool:
	return maxf(absf(d.x), absf(d.z)) < Seed.HALF + radius() + 0.4 and absf(d.y) < Seed.HALF + 0.3

## The context button: whatever makes sense where you are. Holding something, you put it down (a seed
## plants on soil, mud or roots). Otherwise you pick up a seed or the spider, or pull a bomb off a plant.
func context() -> void:
	if held_seed != null:
		release_seed()
	elif carrying != null:
		release_bomb()
	elif pilot != null:
		return
	elif _grab_seed():
		pass
	elif _pick_bomb():
		pass
	elif spider != null and is_instance_valid(spider) and spider.global_position.distance_to(global_position) < radius() + Spider.RADIUS + 0.8:
		stow_spider()

func _pick_bomb() -> bool:
	for n in get_tree().get_nodes_in_group("bomb_flowers"):
		var fl := n as BombFlower
		if fl.ripe() and fl.global_position.distance_to(global_position) < radius() + 1.3:
			fl.pick()
			pull_bomb()
			return true
	return false

func hurt(amount: int, from: Vector3) -> void:
	if dodging() and hp > 0:
		Hitfx.slow(get_tree(), t) # a perfect dodge: the world slows down while you don't
		return
	if god or invuln > 0.0 or hp <= 0:
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
	var item_pressed := -1
	var context_pressed := false
	if ai:
		jump_pressed = ai_jump and not _ai_jump_prev
		jump_held = ai_jump
		target_held = ai_target
		_ai_jump_prev = ai_jump
		attack_pressed = ai_attack
		attack_held = ai_attack or ai_attack_held
		item_pressed = ai_item
		context_pressed = ai_context
		ai_attack = false
		ai_item = -1
		ai_context = false
	else:
		jump_pressed = Input.is_action_just_pressed("jump")
		jump_held = Input.is_action_pressed("jump")
		target_held = Input.is_action_pressed("target")
		attack_pressed = Input.is_action_just_pressed("attack")
		attack_held = Input.is_action_pressed("attack")
		context_pressed = Input.is_action_just_pressed("context")
		for i in Inventory.SLOTS:
			if Input.is_action_just_pressed("item_%d" % (i + 1)):
				item_pressed = i
		if Input.is_action_just_pressed("respawn"):
			respawn()
	_flick_t -= dt
	_flick.visible = _flick_t > 0.0
	Hitfx.tick(dt, t)
	_rail_cool = maxf(_rail_cool - dt, 0.0)
	if is_on_floor():
		_pogo_last = null
	if pilot != null and not is_instance_valid(pilot):
		pilot = null
	if pilot != null:
		# you sit still and the stick steers the spider
		pilot.wish = _wish()
		jump_pressed = false
		jump_held = false
		attack_pressed = false
		attack_held = false
		target_held = false
	if leash != null and is_instance_valid(leash):
		leash.lead = pilot if pilot != null else self # whoever you steer drags the other at full length
	invuln = maxf(invuln - dt, 0.0)
	wall_lock = maxf(wall_lock - dt, 0.0)
	air_lock = maxf(air_lock - dt, 0.0)

	# items and attacks
	if item_pressed >= 0:
		inventory.use(item_pressed, self)
	if context_pressed:
		context()
	if carrying != null and attack_pressed:
		release_bomb()
	elif held_seed != null:
		pass
	elif inventory.has("spear") and carrying == null:
		if attack_pressed and not is_on_floor() and _start_homing():
			pass
		elif attack_pressed:
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

	var wish := _wish() if pilot == null else Vector3.ZERO
	last_wish = wish
	if candle_lit:
		Lighting.spread_heat(global_position, t.candle_touch, dt, self)
	_read_tap(dt, wish)
	buffer = t.jump_buffer if jump_pressed else maxf(buffer - dt, 0.0)
	var on_floor := is_on_floor() and air_lock <= 0.0
	if on_floor and not _was_on_floor:
		land_time = 0.0
	elif on_floor:
		land_time += dt

	roll_buffer = maxf(roll_buffer - dt, 0.0)
	if roll_buffer > 0.0 and roll_t <= 0.0 and on_floor and carrying == null:
		roll_buffer = 0.0
		_start_roll(_roll_wish if _roll_wish != Vector3.ZERO else wish)
		_roll_wish = Vector3.ZERO

	var water := _water()
	var fly := _magnet_line() if small and inventory.has("magnet") else Vector3.ZERO
	magnet_flying = fly != Vector3.ZERO
	if homing != null:
		_homing_step(dt)
	elif rail != null or _catch_rail():
		_rail_step(dt, jump_pressed)
	elif grapple_t > 0.0:
		_grapple_step(dt)
	elif hang != Vector3.ZERO:
		_hang_step(wish, jump_pressed)
	elif _climb_step(wish, jump_pressed):
		pass
	elif magnet_flying:
		_fly_step(wish, fly)
	elif water != null and small and global_position.y <= water.surface() + 0.05 and velocity.y <= 0.0:
		_swim_step(dt, wish, water)
	elif roll_t > 0.0:
		_roll_step(dt, on_floor)
	elif on_floor:
		_ground_step(dt, wish)
	else:
		_air_step(dt, wish, jump_held)
	if small and not magnet_flying:
		_blow(dt, on_floor)

	_was_on_floor = on_floor
	# running fast up a slope, a light snap lets you fly off its top edge instead of being pulled over it
	floor_snap_length = 0.1 if on_floor and velocity.y > 3.0 else 0.7
	move_and_slide()
	_touch_after_move()
	if _teleported > 0:
		_teleported -= 1
		if _teleported == 0:
			platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_ADD_VELOCITY
	if leash != null and not is_instance_valid(leash):
		leash = null
	if water != null:
		if small and global_position.y < water.surface() and velocity.y <= 0.0:
			global_position.y = water.surface() # bob at the surface
			velocity.y = 0.0
		elif not small and global_position.y < water.surface() - 0.4:
			global_position = water.back_to # too heavy: under you go, and you're put back on the bank
			velocity = Vector3.ZERO
	if global_position.y < -30.0:
		respawn()
	_update_visual(dt)
	visual.visible = invuln <= 0.0 or fmod(invuln, 0.15) < 0.09

## Holding target, a quick tap of the stick (out of neutral and back within dodge_tap_time) dodges that way.
## Holding the stick longer just strafes or circles.
func _read_tap(dt: float, wish: Vector3) -> void:
	var m := wish.length()
	if m >= 0.5:
		if _tap_t < 0.0 and _prev_wish_len < 0.3:
			_tap_t = 0.0
		if _tap_t >= 0.0:
			_tap_t += dt
			_tap_dir = wish
	elif m < 0.3:
		if target_held and _tap_t >= 0.0 and _tap_t <= t.dodge_tap_time:
			roll_buffer = t.jump_buffer
			_roll_wish = _tap_dir
		_tap_t = -1.0
	_prev_wish_len = m

func _ground_step(dt: float, wish: Vector3) -> void:
	coyote = t.coyote_time
	var n := get_floor_normal()
	if n == Vector3.ZERO: # the very first frame can report a floor without its normal
		n = Vector3.UP
	var v := velocity - n * velocity.dot(n)
	var g := Vector3.DOWN * t.gravity
	v += (g - n * g.dot(n)) * t.slope_factor * dt
	var sp := v.length()
	var w := wish - n * wish.dot(n)
	var top := (t.strafe_speed if target_held else t.top_speed) * _size_mult()
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
	var slope_pull := (g - n * g.dot(n)).dot(v.normalized())
	if v.length() > top and absf(slope_pull) < 1.0: # on the flat, overspeed bleeds back; slopes act as usual
		v = v.move_toward(v.normalized() * top, t.overspeed_decay * dt)
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
		var cap := maxf(t.top_speed * _size_mult(), hv.length())
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
	if wall and velocity.y < 0.0 and wish.dot(-wn) > 0.3 and carrying == null and held_seed == null and _grab_ledge(wn):
		return
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
	velocity = velocity - n * velocity.dot(n) + n * t.jump_speed * mult * (t.small_jump_mult if small else 1.0)
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
			velocity = dir * t.roll_speed * _size_mult()
		"sidehop":
			velocity = dir * t.roll_speed * _size_mult() * 0.8 + Vector3.UP * 5.0
			global_position += Vector3.UP * 0.05
			air_lock = 0.1
		"backflip":
			velocity = dir * 5.0 + Vector3.UP * t.jump_speed * 1.1
			global_position += Vector3.UP * 0.05
			air_lock = 0.1

func _roll_step(dt: float, on_floor: bool) -> void:
	roll_t -= dt
	if roll_kind == "roll":
		var v := roll_dir * t.roll_speed * _size_mult()
		velocity.x = v.x
		velocity.z = v.z
		if not on_floor:
			velocity.y -= t.gravity * dt
		if roll_t <= 0.0:
			# come out of the roll at running speed
			velocity.x = roll_dir.x * minf(t.roll_speed * _size_mult(), t.top_speed)
			velocity.z = roll_dir.z * minf(t.roll_speed * _size_mult(), t.top_speed)
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
	visual.global_basis = Basis.looking_at(fwd.normalized(), up).scaled(Vector3.ONE * (t.small_scale if small else 1.0))
	if roll_t > 0.0 and roll_kind != "sidehop":
		var spin := (1.0 - roll_t / t.roll_time) * TAU * (1.0 if roll_kind == "roll" else -1.0)
		visual.rotate_object_local(Vector3.RIGHT, -spin)

## After moving: a normal-size roll bursts cracked walls; your weight cracks cracked floors.
func _touch_after_move() -> void:
	if small:
		return
	if is_on_floor(): # standing still reports no collisions, so look at what's underfoot
		var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * (radius() + 0.15), 1, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and hit["collider"] is CrackedFloor:
			(hit["collider"] as CrackedFloor).step()
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var o := c.get_collider()
		if o is CrackedWall and roll_t > 0.0 and roll_kind == "roll":
			(o as CrackedWall).smash()
		elif o is CrackedFloor and c.get_normal().y > 0.7:
			(o as CrackedFloor).step()

func _water() -> Water:
	for w in get_tree().get_nodes_in_group("water"):
		if (w as Water).holds(global_position):
			return w
	return null

## Small, you paddle along the surface; jump to climb out.
func _swim_step(dt: float, wish: Vector3, w: Water) -> void:
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(wish * t.small_swim_speed, t.accel * dt)
	velocity = hv
	up_direction = Vector3.UP
	global_position.y = w.surface()
	roll_t = 0.0
	jump_chain = 0
	if buffer > 0.0:
		velocity.y = t.jump_speed * t.small_jump_mult
		global_position.y += 0.05
		jumping = true
		buffer = 0.0

## Small, fans carry you: inside a lane, your speed along the wind is pulled to the wind's, and gravity lets go.
func _blow(dt: float, on_floor: bool) -> void:
	var w := Vector3.ZERO
	for f in get_tree().get_nodes_in_group("wind"):
		w += (f as Fan).wind_at(global_position)
	if w == Vector3.ZERO:
		return
	if not on_floor:
		velocity.y += t.gravity * dt # undo this frame's gravity: the wind holds you up
	var d := w.normalized()
	var grip := clampf(6.0 * dt, 0.0, 1.0)
	velocity += d * (w.length() - velocity.dot(d)) * grip
	if absf(d.y) < 0.5:
		velocity.y = move_toward(velocity.y, 0.0, t.gravity * 2.0 * dt) # a sideways lane floats you along
	if d.y > 0.5:
		air_lock = 0.05 # lift you off the floor

## Small with the magnet, the nearest iron you're lined up with (at its side, not a diagonal, clear line, in reach)
## moves you: pull flies you to it, push flies you away. Returns the velocity to fly at, or zero.
## Lined up against it while pulling, you cling to its side.
func _magnet_line() -> Vector3:
	var best: IronCube = null
	var best_d := INF
	var best_dir := Vector3.ZERO
	var space := get_world_3d().direct_space_state
	for n in get_tree().get_nodes_in_group("conductor"):
		if not n is IronCube:
			continue
		var c := n as IronCube
		var d := global_position - c.global_position
		if d.y < -0.6 or d.y > IronCube.H - 0.5:
			continue
		var dir := Vector3.ZERO
		if absf(d.x) < 1.0:
			dir = Vector3(0, 0, signf(d.z))
		elif absf(d.z) < 1.0:
			dir = Vector3(signf(d.x), 0, 0)
		else:
			continue
		var along := absf(d.dot(dir))
		if along > t.magnet_fly_range or along >= best_d:
			continue
		var q := PhysicsRayQueryParameters3D.create(c.global_position + Vector3.UP * minf(d.y + 0.2, IronCube.H - 0.3), global_position, 1, [c.get_rid(), get_rid()])
		if not space.intersect_ray(q).is_empty():
			continue
		best = c
		best_d = along
		best_dir = dir # from the iron toward you
	if best == null:
		return Vector3.ZERO
	if magnet_push:
		return best_dir * t.magnet_fly_speed
	if best_d <= IronCube.CELL / 2.0 + radius() + 0.1:
		return -best_dir * 0.001 # clinging: held in place against its side
	return -best_dir * t.magnet_fly_speed

## Carried along the iron's line at your height. You can edge sideways, which is how you slip out of the line.
func _fly_step(wish: Vector3, fly: Vector3) -> void:
	var d := fly.normalized()
	var side := wish - d * wish.dot(d)
	side.y = 0.0
	velocity = (fly if fly.length() > 0.01 else Vector3.ZERO) + side * t.top_speed * _size_mult() * 0.6
	velocity.y = 0.0
	up_direction = Vector3.UP
	roll_t = 0.0
	jumping = false

## The lash is pulling you to a post or trunk. At the end you get a little hop up and over.
func _grapple_step(dt: float) -> void:
	grapple_t -= dt
	var d := grapple_to - global_position
	if d.length() < 0.6 or grapple_t <= 0.0 or (get_slide_collision_count() > 0 and d.length() < 2.0):
		grapple_t = 0.0
		var flat := Vector3(d.x, 0, d.z)
		velocity = (flat.normalized() if flat.length() > 0.05 else _flat_facing()) * 4.0 + Vector3.UP * 7.0
		air_lock = 0.1
		return
	velocity = d.normalized() * t.lash_pull_speed
	facing = Vector3(d.x, 0, d.z).normalized() if Vector2(d.x, d.z).length() > 0.1 else facing

## Push into anything climbable (vine walls, trunks) to climb it, as long as you like. The stick into the
## wall climbs, sideways moves along it; let go and you drop. At the top you pull yourself over. Jump kicks off.
## Returns true while climbing.
func _climb_step(wish: Vector3, jump_pressed: bool) -> bool:
	climbing = null
	if hands_full() or small or wish.length() < 0.3:
		return false
	var space := get_world_3d().direct_space_state
	var dir := Vector3(wish.x, 0, wish.z).normalized()
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + dir * (radius() + 0.45), 1, [get_rid()])
	var hit := space.intersect_ray(q)
	if hit.is_empty() or not (hit["collider"] as Node).is_in_group("climbable"):
		return false
	var n: Vector3 = hit["normal"]
	n.y = 0.0
	if n.length() < 0.5:
		return false
	n = n.normalized()
	var into := wish.dot(-n)
	if into < 0.3:
		return false
	climbing = hit["collider"]
	facing = -n
	if jump_pressed:
		velocity = n * t.wall_jump_speed + Vector3.UP * t.wall_jump_up
		wall_lock = 0.2
		climbing = null
		return true
	# at the top: nothing climbable in front of your head any more, so pull up and over
	var head := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.9, global_position + Vector3.UP * 0.9 - n * (radius() + 0.6), 1, [get_rid()])
	if space.intersect_ray(head).is_empty():
		velocity = -n * 3.0 + Vector3.UP * 7.0
		return true
	var side := wish - (-n) * into
	velocity = Vector3.UP * t.climb_speed * into + side * t.climb_speed - n * 1.0
	return true

## Falling against a wall whose top is within ledge_reach above your middle: catch the edge and hang there.
func _grab_ledge(wn: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	var over := global_position - wn * (radius() + 0.35)
	var q := PhysicsRayQueryParameters3D.create(over + Vector3.UP * t.ledge_reach, over + Vector3.UP * 0.1, 1 | 1 << 4, [get_rid()]) # walls and seed cubes
	var hit := space.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7 or hit["collider"] is IronCube:
		return false # iron is too smooth to grip: its 4.5 m still needs a triple jump
	var top: Vector3 = hit["position"]
	# room to stand up there
	var room := PhysicsRayQueryParameters3D.create(top + Vector3.UP * 0.1, top + Vector3.UP * 1.1, 1, [get_rid()])
	if not space.intersect_ray(room).is_empty():
		return false
	hang = top
	hang_n = wn
	velocity = Vector3.ZERO
	global_position = Vector3(global_position.x, top.y - 0.55, global_position.z)
	facing = -wn
	jump_chain = 0
	return true

## Hanging from a ledge: push toward it or jump to pull yourself up; pull away to drop.
func _hang_step(wish: Vector3, jump_pressed: bool) -> void:
	velocity = Vector3.ZERO
	global_position.y = hang.y - 0.55
	var into := wish.dot(-hang_n)
	if jump_pressed or into > 0.5:
		velocity = -hang_n * 3.5 + Vector3.UP * 8.0
		hang = Vector3.ZERO
		air_lock = 0.1
	elif into < -0.5:
		velocity = hang_n * 2.0
		hang = Vector3.ZERO

## Air attack: home in on the nearest thing to hit ahead of you (what you're locked on to comes first).
## Returns false if there's nothing in reach, and the spear does an air slash instead.
func _start_homing() -> bool:
	var best: Node3D = null
	var best_d := t.homing_range
	var f := _flat_facing()
	var cands: Array = []
	if target != null and is_instance_valid(target) and (target.is_in_group("hurtable") or target.is_in_group("pogo")):
		cands = [target]
	else:
		cands = get_tree().get_nodes_in_group("hurtable") + get_tree().get_nodes_in_group("pogo")
	for n in cands:
		var node := n as Node3D
		if node == self or node is Player or node is CrackedWall or node == _pogo_last:
			continue
		var d := node.global_position - global_position
		var ahead := Vector2(d.x, d.z).length() < 1.5 or Vector3(d.x, 0, d.z).normalized().dot(f) >= 0.3 # right overhead counts
		if d.length() > best_d or (target != node and not ahead):
			continue
		var q := PhysicsRayQueryParameters3D.create(global_position, node.global_position, 1, [get_rid()])
		var hit := get_world_3d().direct_space_state.intersect_ray(q)
		if not hit.is_empty() and hit["collider"] != node:
			continue
		best = node
		best_d = d.length()
	if best == null:
		return false
	homing = best
	homing_t = best_d / t.homing_speed + 0.25
	spear.start("air")
	return true

## Flying at the homing target. Reaching it hits it (enemies take damage, spikes don't hurt you) and
## pogos you back up into the air, ready to home in on the next one.
func _homing_step(dt: float) -> void:
	homing_t -= dt
	if not is_instance_valid(homing) or homing_t <= 0.0:
		homing = null
		return
	var d := homing.global_position - global_position
	if d.length() < radius() + 0.9:
		if homing.is_in_group("hurtable") and not spear._hit.has(homing): # the air slash may have hit it already
			spear._hit.append(homing)
			homing.hurt(2, global_position)
		Hitfx.hit(get_tree(), homing.global_position, t, 1.2)
		# you strike it and come off its top, even if you flew in from below
		var over := homing.global_position + Vector3.UP * (radius() + 0.8)
		var q := PhysicsRayQueryParameters3D.create(homing.global_position, over + Vector3.UP * radius(), 1, [get_rid(), homing.get_rid()] if homing is CollisionObject3D else [get_rid()])
		if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			global_position = over
		velocity = Vector3.UP * t.pogo_speed # straight up: steer with air control to the next one
		_pogo_last = homing # not the same one again until you land
		jumping = false
		jump_chain = 0
		air_lock = 0.1
		homing = null
		return
	velocity = d.normalized() * t.homing_speed
	facing = Vector3(d.x, 0, d.z).normalized() if Vector2(d.x, d.z).length() > 0.1 else facing

## Landing on or near a rail from above starts a grind.
func _catch_rail() -> bool:
	if _rail_cool > 0.0 or velocity.y > 3.0:
		return false
	for n in get_tree().get_nodes_in_group("rails"):
		var r := n as Rail
		var s := r.closest(global_position)
		var at := r.point(s)
		var d := global_position - at
		if Vector2(d.x, d.z).length() < 0.7 and d.y > -0.2 and d.y < radius() + 0.9:
			var tan := r.tangent(s)
			rail = r
			rail_s = s
			var along := velocity.dot(tan)
			rail_dir = 1.0 if along >= 0.0 else -1.0
			if absf(along) < 0.5: # dropped straight on: go downhill
				rail_dir = -1.0 if tan.y > 0.0 else 1.0
			rail_speed = maxf(absf(along), t.rail_min_speed)
			return true
	return false

## Grinding: you ride the rail, gaining speed downhill and losing it uphill. Jump hops off; at the end
## you fly off with your speed.
func _rail_step(dt: float, jump_pressed: bool) -> void:
	var tan := rail.tangent(rail_s) * rail_dir
	rail_speed = clampf(rail_speed - t.gravity * tan.y * t.slope_factor * dt, 3.0, t.boost_speed)
	rail_s += rail_speed * rail_dir * dt
	velocity = tan * rail_speed
	if jump_pressed or rail_s <= 0.0 or rail_s >= rail.length:
		if jump_pressed:
			velocity.y = maxf(velocity.y, 0.0) + t.jump_speed
		rail = null
		_rail_cool = 0.3
		air_lock = 0.1
		return
	global_position = rail.point(rail_s) + Vector3.UP * (radius() + 0.1) - velocity * dt # move_and_slide adds this frame's step
	facing = Vector3(tan.x, 0, tan.z).normalized() if Vector2(tan.x, tan.z).length() > 0.1 else facing
