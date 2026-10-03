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
## Liquids (see Liquids): honey slows you (small, it holds you), wine sways your steering, wading into water
## puts the candle out. The context button picks up pots and throws or sets them down.
## The poleaxe comes with a shield (the guard button). Guarding you walk at guard_speed; a hit from in front is
## blocked (it pushes you back, harder for heavy hits, and a heavy hit with a wall right behind you breaks your
## guard). Raising the shield just as a hit lands is a perfect guard: the attacker reels open, arrows fly back,
## and your next sweet-spot hit is stronger. Guard and stand still for brace_time to brace: something charging
## onto your point faster than impale_speed is impaled. Guard in the air and land holding it to shield surf.
## Locked on at the poleaxe's measure (focus_near to focus_far), focus builds; full, the next attack is a flash step.

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
var ai_guard := false ## holds the guard button
var _ai_jump_prev := false

var coyote := 0.0
var _wall_n := Vector3.ZERO ## the last wall you were on, for a late wall jump (wall_coyote)
var _wall_t := 0.0
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
var poleaxe: Poleaxe
var guard_t := -1.0 ## seconds since the shield went up, -1 while it's down
var still_t := 0.0 ## seconds guarding without moving: brace_time of it braces
var parry_t := 0.0 ## after a perfect guard: the next sweet-spot hit is stronger
var guard_break_t := 0.0 ## a heavy hit broke your guard: you're reeling
var surfing := false ## riding your shield down the ground
var focus_meter := 0.0 ## 0-1, builds while locked on at the poleaxe's measure
var flash_t := 0.0 ## the flash step's dash
var _guard_held := false
var _surf_hit := {} ## monsters a surf bumped recently, and when
var _shield: MeshInstance3D
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
var held_pot: Pot = null ## a pot over your head (Pot)
var carried_by: Node3D = null ## the spider carrying you overhead (you're carryable while you steer it)
var grapple_to := Vector3.ZERO ## the lash is pulling you here
var grapple_t := 0.0
var climbing: Node3D = null ## the climbable wall or trunk you're on
var _vault_to := Vector3.ZERO ## pulling yourself over the top of a climb onto this spot (ZERO when not)
var _vault_t := 0.0
var _vault_hold := 0.0 ## just vaulted onto a top: a stick still held the way you climbed is ignored (up to this long)
var _vault_dir := Vector3.ZERO ## the way you climbed
var _vault_on_trunk := false
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
var roll_speed_now := 0.0 ## a roll keeps the speed you rolled at (and gains downhill)
var pound_t := -1.0 ## ground pound: >= 0 while pounding (time since it started)
var pound_land := 99.0 ## seconds since a pound landed on flat ground (a jump now is a high jump)
var long_jumping := false ## in the air from a long jump; landing trims the speed boost (long_jump_keep)
var boost_t := 0.0 ## time left before a boost pad's overspeed starts to bleed off
var _ledge_up_t := 99.0 ## seconds since you pulled up out of a ledge hang
var _pound_ledge := false ## this pound started right after a ledge pull-up
var _ledge_roll := false ## this roll came out of such a pound: its long jump is stronger
var _pogo_last: Node3D = null ## what you last bounced off; homing skips it until you land
var _flick: MeshInstance3D
var _flick_t := 0.0
var small := false ## shrunk on a shrink pad
var _last_slots: Array[String] = ["", "", ""] ## the quick slots last frame (_drop_unslotted)
var magnet_flying := false ## small, and the magnet is carrying you along an iron's line
var _col: CollisionShape3D
const RADIUS := 0.5

func _ready() -> void:
	add_to_group("player")
	add_to_group("hurtable")
	add_to_group("carryable") # the spider can carry you while you steer it
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
	poleaxe = Poleaxe.new()
	poleaxe.player = self
	visual.add_child(poleaxe)
	_shield = MeshInstance3D.new()
	var shm := BoxMesh.new()
	shm.size = Vector3(0.75, 0.8, 0.1)
	_shield.mesh = shm
	var sm := _mat(Color(0.35, 0.45, 0.7))
	sm.metallic = 0.5
	_shield.material_override = sm
	visual.add_child(_shield)
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
	boost_t = t.boost_hold

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
	if small and held_pot != null: # too small to hold it up
		held_pot.set_down(global_position + Vector3.UP * 0.2)
		held_pot = null
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

## Items only stay on while they're on the quick bar (jovi): one moved off the three slots switches off.
## (Watches the slots change, so a hat lit some other way, by a pin or a test, isn't put out.)
func _drop_unslotted() -> void:
	var now := inventory.slots
	for id in _last_slots:
		if id != "" and not now.has(id):
			match id:
				"candle":
					if candle_lit:
						set_candle(false)
				"umbra":
					if umbra != null:
						umbra.fade()
				"spider":
					if pilot != null:
						pilot.let_go()
						pilot = null
				"lash":
					if leash != null and is_instance_valid(leash):
						leash.queue_free()
					leash = null
				"magnet":
					magnet_flying = false
	_last_slots = now.duplicate()

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
	_vault_to = Vector3.ZERO
	platform_on_leave = CharacterBody3D.PLATFORM_ON_LEAVE_DO_NOTHING
	_teleported = 2

func respawn() -> void:
	teleport(spawn)
	up_direction = Vector3.UP
	target = null
	hp = max_hp
	invuln = 0.0
	roll_t = 0.0
	surfing = false
	guard_break_t = 0.0
	focus_meter = 0.0
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
	if held_pot != null:
		held_pot.set_down(global_position + Vector3.UP * 0.2)
		held_pot = null
	if leash != null:
		leash.queue_free()
		leash = null
	if pilot != null:
		pilot.let_go()
		pilot = null
	if carried_by != null and is_instance_valid(carried_by) and carried_by.has_method("_drop_shape"):
		carried_by._drop_shape()
	_end_carried()
	grapple_t = 0.0
	climbing = null
	_vault_to = Vector3.ZERO
	homing = null
	hang = Vector3.ZERO
	rail = null
	pound_t = -1.0

## Where the camera looks: the spider while you steer it, otherwise you.
func focus() -> Node3D:
	return pilot if pilot != null else self

func hands_full() -> bool:
	return held_seed != null or carrying != null or held_pot != null

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
		if Sling.yank(self): # a monster on the leash: yank it to your feet (Sling)
			return
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
	elif c is Monster:
		Sling.hook(self, c as Monster) # sting and leash it (Lash & Sling)
	elif c.is_in_group("hurtable") and c != self:
		c.hurt(1, global_position)
		if "velocity" in c:
			c.velocity = (global_position - (c as Node3D).global_position).normalized() * 9.0 + Vector3.UP * 3.0

func _show_flick(a: Vector3, b: Vector3) -> void:
	Whip.crack(get_parent(), a, b) # the lash cracks like a whip (jovi): the cord rolls out and snaps at the tip

## Context button with a seed in your hands: set down in front of you on soil, mud or roots, it plants;
## otherwise you throw it (moving) or set it down (standing still).
func release_seed() -> void:
	var sd := held_seed
	var f := _flat_facing()
	if climbing != null:
		# on a vine or trunk: let go and it drops straight down behind you (from spear_drop up onto mud, it spears in)
		var behind := global_position - f * (radius() + Seed.HALF + 0.15) + Vector3.UP * (Seed.HALF - radius() + 0.05)
		if not _room_for_cube(behind):
			return
		held_seed = null
		sd.set_down(behind)
		return
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
		sd.throw(f * t.seed_throw_speed + Vector3.UP * t.seed_throw_up + Vector3(velocity.x, 0, velocity.z) * 0.3)

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
## (The ground pound is the air attack without lock-on, not this button.)
func context() -> void:
	if pilot != null:
		pilot.context() # steering the spider, it's the spider's hands
	elif held_seed != null:
		release_seed()
	elif held_pot != null:
		release_pot()
	elif carrying != null:
		release_bomb()
	elif _grab_seed():
		pass
	elif _grab_pot():
		pass
	elif _pick_bomb():
		pass
	elif spider != null and is_instance_valid(spider) and spider.global_position.distance_to(global_position) < radius() + Spider.RADIUS + 0.8:
		stow_spider()

## Context button next to a pot picks it up (not when you're small: it's too heavy).
func _grab_pot() -> bool:
	if small:
		return false
	var best: Pot = null
	var best_d := radius() + Pot.R + 0.9
	for n in get_tree().get_nodes_in_group("pots"):
		var pt := n as Pot
		if pt.holder != null or pt.flying:
			continue
		var d := pt.global_position - global_position
		if absf(d.y) < 1.2 and Vector2(d.x, d.z).length() < best_d:
			best = pt
			best_d = Vector2(d.x, d.z).length()
	if best == null:
		return false
	held_pot = best
	best.hold(self)
	return true

## Context button with a pot overhead: moving, you throw it (faster the faster you run); standing still, a
## full pot is lobbed a short way and an empty one is set down in front of you.
func release_pot() -> void:
	var pt := held_pot
	var f := _flat_facing()
	var moving := _wish().length() > 0.2 or flat_speed() > 2.0
	held_pot = null
	if not moving and pt.liquid == "":
		pt.set_down(global_position + f * (radius() + Pot.R + 0.3) + Vector3.UP * (Pot.R - radius() + 0.05))
		return
	var sp := t.pot_throw_speed + (t.pot_throw_run * flat_speed() if moving else 0.0)
	pt.throw(f * sp + Vector3.UP * t.pot_throw_up, self)

func _pick_bomb() -> bool:
	for n in get_tree().get_nodes_in_group("bomb_flowers"):
		var fl := n as BombFlower
		if fl.ripe() and fl.global_position.distance_to(global_position) < radius() + 1.3:
			fl.pick()
			pull_bomb()
			return true
	return false

## by is what hit you (a monster, an arrow), if anything; heavy hits push a block back hard and can break it.
func hurt(amount: int, from: Vector3, by: Node = null, heavy := false) -> void:
	if dodging() and hp > 0:
		Hitfx.slow(get_tree(), t) # a perfect dodge: the world slows down while you don't
		return
	if god or invuln > 0.0 or hp <= 0:
		return
	if guarding() and _guard(from, by, heavy):
		return
	hp -= amount
	focus_meter = 0.0
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

## Can the shield go up right now? (The poleaxe and shield come together.)
func can_guard() -> bool:
	return inventory.has("poleaxe") and not hands_full() and guard_break_t <= 0.0 and roll_t <= 0.0 and pound_t < 0.0 \
		and homing == null and pilot == null and rail == null and hang == Vector3.ZERO and climbing == null and grapple_t <= 0.0
func guarding() -> bool:
	return guard_t >= 0.0
func braced() -> bool:
	return guarding() and still_t >= t.brace_time and is_on_floor() and not surfing

## A hit coming at your shield. Returns true if the shield took it.
func _guard(from: Vector3, by: Node, heavy: bool) -> bool:
	var dir := from - global_position
	dir.y = 0.0
	dir = dir.normalized() if dir.length() > 0.01 else _flat_facing()
	if _flat_facing().dot(dir) < 0.3:
		return false # from the side or behind: the shield doesn't cover it
	if braced() and by is Monster and Vector2((by as Monster).velocity.x, (by as Monster).velocity.z).length() > t.impale_speed:
		# it ran onto your point
		(by as Monster).strike(int(t.impale_damage), global_position, {"head": "point", "stagger": true, "knock": 3.0})
		if is_instance_valid(by):
			(by as Monster).stun = maxf((by as Monster).stun, t.impale_stun)
		poleaxe.stuck_t = t.stuck_time
		Hitfx.hit(get_tree(), (by as Node3D).global_position if is_instance_valid(by) else from, t, 1.6, by, t.hitstop)
		return true
	if guard_t < t.perfect_guard:
		parry_t = t.parry_time
		if by != null and by.has_method("reflect"):
			by.reflect(self, true) # arrows and orbs fly back (at your lock-on target, if you have one)
		elif by != null and by.has_method("parried"):
			by.parried()
		Hitfx.hit(get_tree(), global_position + dir * 0.6, t, 1.2, null, t.hitstop)
		return true
	var push := t.guard_push_heavy if heavy else t.guard_push
	if heavy:
		var q := PhysicsRayQueryParameters3D.create(global_position, global_position - dir * (radius() + t.guard_wall), 1, [get_rid()])
		if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
			# nowhere to give ground: the guard breaks
			guard_break_t = t.guard_break
			guard_t = -1.0
			velocity = Vector3(0, velocity.y, 0)
			Hitfx.shake(get_tree(), 0.2)
			return true
	velocity.x = -dir.x * push
	velocity.z = -dir.z * push
	Hitfx.sparks(get_tree(), global_position + dir * 0.6, 0.7)
	return true

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
		carrying.throw(f * t.bomb_throw_speed + Vector3.UP * t.bomb_throw_up + Vector3(velocity.x, 0, velocity.z) * t.bomb_throw_keep)
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
	var guard_held: bool
	if ai:
		jump_pressed = ai_jump and not _ai_jump_prev
		jump_held = ai_jump
		target_held = ai_target
		_ai_jump_prev = ai_jump
		attack_pressed = ai_attack
		attack_held = ai_attack or ai_attack_held
		item_pressed = ai_item
		context_pressed = ai_context
		guard_held = ai_guard
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
		guard_held = Input.is_action_pressed("guard")
		for i in Inventory.SLOTS:
			if Input.is_action_just_pressed("item_%d" % (i + 1)):
				item_pressed = i
		if Input.is_action_just_pressed("respawn"):
			respawn()
	_flick_t -= dt
	_flick.visible = _flick_t > 0.0
	_drop_unslotted()
	Hitfx.tick(dt, t)
	_rail_cool = maxf(_rail_cool - dt, 0.0)
	if is_on_floor():
		_pogo_last = null
	if pilot != null and not is_instance_valid(pilot):
		pilot = null
	if pilot != null:
		# you sit still and the stick steers the spider
		pilot.wish = _wish()
		if attack_pressed:
			pilot.bite() # steering the spider, attack is its bite
		jump_pressed = false
		jump_held = false
		attack_pressed = false
		attack_held = false
		target_held = false
		guard_held = false
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
	if carried_by != null and _carried_step():
		return
	if carrying != null and attack_pressed:
		release_bomb()
	elif held_seed != null or held_pot != null:
		pass
	elif attack_pressed and Sling.leashed(self) != null and Sling.swing(self):
		pass # a monster on the leash: attack swings it round you (Sling)
	elif pound_t >= 0.0:
		pass # mid-pound: the attack button waits until you land or bounce
	elif attack_pressed and not is_on_floor() and not target_held and _can_pound():
		pound_t = 0.0 # air attack without lock-on: ground pound (no poleaxe needed)
		_pound_ledge = _ledge_up_t < 0.5
	elif inventory.has("poleaxe") and carrying == null and guard_break_t <= 0.0:
		if attack_pressed and not is_on_floor() and not guarding() and _start_homing():
			pass
		elif attack_pressed and focus_meter >= 1.0 and is_on_floor() and not guarding() and _focus_target() != null:
			_flash_step()
		elif attack_pressed:
			poleaxe.press()
		# hold attack and the swing waits; let go after hammer_hold for the hammer, after spin_charge_time to spin
		attack_held_t = attack_held_t + dt if attack_held else 0.0
	poleaxe.button = attack_held and pilot == null

	# the shield
	guard_break_t = maxf(guard_break_t - dt, 0.0)
	parry_t = maxf(parry_t - dt, 0.0)
	if guard_held and can_guard():
		guard_t = guard_t + dt if guard_t >= 0.0 else 0.0
	else:
		guard_t = -1.0
		surfing = false
	_guard_held = guard_held
	still_t = still_t + dt if guarding() and flat_speed() < 0.5 and _wish().length() < 0.2 else 0.0
	_update_focus(dt)

	# targeting and strafing
	var had_strafe := strafing
	_update_target(target_held)
	strafing = target_held and target == null
	if strafing and not had_strafe:
		lock_dir = _flat_facing()

	var wish := _wish() if pilot == null and guard_break_t <= 0.0 else Vector3.ZERO
	wish = Liquids.player_wish(self, wish, dt) # wine sways it
	last_wish = wish
	if candle_lit:
		Lighting.spread_heat(global_position, t.candle_touch, dt, self)
	_read_tap(dt, wish)
	buffer = t.jump_buffer if jump_pressed else maxf(buffer - dt, 0.0)
	var on_floor := is_on_floor() and air_lock <= 0.0
	if on_floor and not _was_on_floor:
		land_time = 0.0
		if long_jumping:
			# a long jump carries you far, but only part of its speed boost survives the landing
			var hv := Vector3(velocity.x, 0, velocity.z)
			var top := t.top_speed * _size_mult()
			if hv.length() > top:
				hv = hv.normalized() * (top + (hv.length() - top) * t.long_jump_keep)
				velocity.x = hv.x
				velocity.z = hv.z
	elif on_floor:
		land_time += dt
	pound_land += dt
	_ledge_up_t += dt
	boost_t = maxf(boost_t - dt, 0.0)
	if on_floor and roll_t <= 0.0:
		long_jumping = false

	roll_buffer = maxf(roll_buffer - dt, 0.0)
	if roll_buffer > 0.0 and roll_t <= 0.0 and on_floor and carrying == null:
		roll_buffer = 0.0
		_start_roll(_roll_wish if _roll_wish != Vector3.ZERO else wish)
		_roll_wish = Vector3.ZERO

	var water := _water()
	var fly := _magnet_line() if small and inventory.equipped("magnet") else Vector3.ZERO
	magnet_flying = fly != Vector3.ZERO
	if not on_floor and guarding() and velocity.y < 0.0 and homing == null:
		_surf_pogo()
	if on_floor and guarding() and not _was_on_floor and flat_speed() > t.surf_min:
		surfing = true # landed holding the shield: ride it
	if flash_t > 0.0:
		flash_t -= dt # the flash step's dash carries you
	elif homing != null:
		_homing_step(dt)
	elif pound_t >= 0.0:
		_pound_step(dt, on_floor, wish)
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
		_roll_step(dt, on_floor, jump_pressed or buffer > 0.0)
	elif surfing and on_floor:
		_surf_step(dt, wish)
	elif on_floor:
		_ground_step(dt, wish)
	else:
		_air_step(dt, wish, jump_held)
	if small and not magnet_flying:
		_blow(dt, on_floor)

	_was_on_floor = on_floor
	# running fast up a slope, a light snap lets you fly off its top edge instead of being pulled over it
	floor_snap_length = 0.1 if on_floor and velocity.y > 3.0 else 0.7
	Liquids.player_drag(self) # honey
	if on_floor and flash_t <= 0.0 and homing == null and pound_t < 0.0 and rail == null and grapple_t <= 0.0 \
			and hang == Vector3.ZERO and climbing == null and not magnet_flying and velocity.dot(up_direction) < 1.0:
		StepUp.try(self, dt, t.step_height * (t.small_scale if small else 1.0), radius()) # walk over bumps
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
	_wall_t = 0.0
	if _vault_hold > 0.0:
		# still holding the stick the way you climbed: stay on top until you let go or steer another way
		_vault_hold -= dt
		if wish.dot(_vault_dir) > 0.5:
			wish = Vector3.ZERO
		else:
			_vault_hold = 0.0
	var n := get_floor_normal()
	if n == Vector3.ZERO: # the very first frame can report a floor without its normal
		n = Vector3.UP
	var v := velocity - n * velocity.dot(n)
	var g := Vector3.DOWN * t.gravity
	v += (g - n * g.dot(n)) * t.slope_factor * dt
	var sp := v.length()
	var w := wish - n * wish.dot(n)
	var top := (t.strafe_speed if target_held else t.top_speed) * _size_mult()
	if guarding():
		top = t.guard_speed * _size_mult()
	elif poleaxe.frozen:
		top = minf(top, t.charge_speed * _size_mult())
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
	if v.length() > top and absf(slope_pull) < 1.0 and boost_t <= 0.0: # on the flat, overspeed bleeds back (not right after a boost pad); slopes act as usual
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
	_wall_t -= dt
	if wall:
		_wall_n = wn
		_wall_t = t.wall_coyote
	if wall and buffer > 0.0:
		_wall_jump(wn, wish)
	elif buffer > 0.0 and coyote > 0.0:
		_ground_jump(Vector3.UP)
	elif buffer > 0.0 and _wall_t > 0.0:
		_wall_jump(_wall_n, wish) # just left the wall: still counts
	elif wall and velocity.y < -t.wall_slide_speed and wish.dot(-wn) > 0.3:
		velocity.y = -t.wall_slide_speed
	if jumping and not jump_held and velocity.y > t.jump_cut:
		velocity.y = t.jump_cut
	if velocity.y <= 0.0:
		jumping = false

## Mario-style chain: jump again within jump_combo_window of landing, while moving, to go higher.
## The third jump needs real speed (triple_min_speed). Any pause resets it to a single jump.
func _ground_jump(n: Vector3) -> void:
	if pound_land <= t.pound_jump_window:
		# high jump out of a ground pound
		pound_land = 99.0
		velocity = velocity - n * velocity.dot(n) + n * t.jump_speed * t.pound_jump_mult * (t.small_jump_mult if small else 1.0)
		global_position += n * 0.05
		jumping = true
		buffer = 0.0
		coyote = 0.0
		land_time = 99.0
		jump_chain = 2 # it counts as the top of the chain
		return
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

## Kick off the wall. Holding the stick along the wall angles the jump that way (wall_jump_side), and half the
## speed you had along the wall carries on.
func _wall_jump(wn: Vector3, wish := Vector3.ZERO) -> void:
	var side := wish - wn * wish.dot(wn)
	side.y = 0.0
	var along := Vector3(velocity.x, 0, velocity.z)
	along -= wn * along.dot(wn)
	var h := wn * t.wall_jump_speed + side * t.wall_jump_side + along * 0.5
	velocity = h + Vector3.UP * t.wall_jump_up
	facing = h.normalized()
	_wall_t = 0.0
	jumping = true
	buffer = 0.0
	wall_lock = 0.18
	jump_chain = 0

func _start_roll(wish: Vector3) -> void:
	_ledge_roll = false
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
	roll_speed_now = maxf(t.roll_speed, flat_speed() / _size_mult())
	match roll_kind:
		"roll":
			velocity = dir * roll_speed_now * _size_mult()
		"sidehop":
			velocity = dir * t.roll_speed * _size_mult() * 0.8 + Vector3.UP * 5.0
			global_position += Vector3.UP * 0.05
			air_lock = 0.1
		"backflip":
			velocity = dir * 5.0 + Vector3.UP * t.jump_speed * 1.1
			global_position += Vector3.UP * 0.05
			air_lock = 0.1

func _roll_step(dt: float, on_floor: bool, jump_pressed := false) -> void:
	roll_t -= dt
	if roll_kind == "roll" and jump_pressed and on_floor:
		# long jump: out of a roll you fly forward, low and far
		roll_t = 0.0
		var mult := t.ledge_long_mult if _ledge_roll else 1.0
		velocity = (roll_dir * maxf(t.long_jump_speed, roll_speed_now) * _size_mult() + Vector3.UP * t.long_jump_up) * mult
		long_jumping = true
		_ledge_roll = false
		global_position += Vector3.UP * 0.05
		jumping = false
		buffer = 0.0
		air_lock = 0.1
		land_time = 99.0
		return
	if roll_kind == "roll":
		if on_floor:
			# rolling keeps its speed, and downhill adds to it
			var n := get_floor_normal()
			if n != Vector3.ZERO:
				var g := Vector3.DOWN * t.gravity
				roll_speed_now = clampf(roll_speed_now + (g - n * g.dot(n)).dot(roll_dir) * t.slope_factor * dt, t.roll_speed * 0.5, t.boost_speed)
		var v := roll_dir * roll_speed_now * _size_mult()
		velocity.x = v.x
		velocity.z = v.z
		if not on_floor:
			velocity.y -= t.gravity * dt
		if roll_t <= 0.0:
			# come out of the roll at running speed
			var out := roll_speed_now if roll_speed_now > t.roll_speed else minf(t.roll_speed, t.top_speed)
			velocity.x = roll_dir.x * out * _size_mult()
			velocity.z = roll_dir.z * out * _size_mult()
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
	_shield.visible = inventory.has("poleaxe")
	if surfing and is_on_floor():
		_shield.position = Vector3(0, -0.5, 0) # underfoot
		_shield.rotation = Vector3(-PI / 2.0, 0, 0)
	elif guarding():
		_shield.position = Vector3(-0.1, 0.05, -0.55) # up in front
		_shield.rotation = Vector3(0, 0, 0.3 if braced() else 0.0)
	else:
		_shield.position = Vector3(-0.5, 0.0, 0.05) # at your side
		_shield.rotation = Vector3(0, PI / 2.0, 0.4 if guard_break_t > 0.0 else 0.0)
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
	if _vault_to != Vector3.ZERO:
		return _vault_step()
	if carrying != null or small or wish.length() < 0.3: # a seed overhead doesn't stop you (jovi), a lit bomb does
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
		if not _start_vault(n, climbing):
			velocity = -n * 3.0 + Vector3.UP * 7.0
		return true
	var side := wish - (-n) * into
	velocity = Vector3.UP * t.climb_speed * into + side * t.climb_speed - n * 1.0
	return true

## At the top of a climb: find the top surface over the edge (a trunk's middle, or just past a wall's edge) and
## pull yourself onto it (_vault_step). False if there's nowhere to stand.
func _start_vault(n: Vector3, on: Node3D) -> bool:
	var over := global_position - n * (radius() + 1.0)
	if on != null and on.is_in_group("trunks"):
		over = Vector3(on.global_position.x, global_position.y, on.global_position.z) # its middle
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(over + Vector3.UP * 1.6, over + Vector3.DOWN * 0.6, 1 | 1 << 4, [get_rid()])
	var hit := space.intersect_ray(q)
	if hit.is_empty() or (hit["normal"] as Vector3).y < 0.7:
		return false
	var top: Vector3 = hit["position"]
	var room := PhysicsRayQueryParameters3D.create(top + Vector3.UP * 0.05, top + Vector3.UP * (radius() * 2.0 + 0.1), 1, [get_rid()])
	if not space.intersect_ray(room).is_empty():
		return false
	_vault_to = top + Vector3.UP * (radius() + 0.05)
	_vault_t = 0.0
	_vault_dir = -n
	_vault_on_trunk = on != null and on.is_in_group("trunks")
	return true

## Vaulting over the top of a climb: straight up until you're clear of the top, then across onto it, then a
## stick still held into the climb doesn't walk you on (off a trunk's far side) until you let go or steer elsewhere.
func _vault_step() -> bool:
	_vault_t += get_physics_process_delta_time()
	if _vault_t > 0.8:
		_vault_to = Vector3.ZERO # something's in the way: give up
		return false
	if global_position.y < _vault_to.y:
		velocity = Vector3.UP * 9.0
		return true
	var d := Vector3(_vault_to.x - global_position.x, 0, _vault_to.z - global_position.z)
	if d.length() > 0.12:
		velocity = d.normalized() * minf(7.0, d.length() * 60.0)
		velocity.y = 0.0
		return true
	velocity = Vector3.ZERO
	_vault_to = Vector3.ZERO
	_vault_hold = 2.0 if _vault_on_trunk else 0.0 # a wall's top has room to walk on; a trunk's doesn't
	jump_chain = 0
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
		_ledge_up_t = 0.0
	elif into < -0.5:
		velocity = hang_n * 2.0
		hang = Vector3.ZERO

## Shield surf: on your shield there's almost no friction, slopes speed you up as they would a roll, and the
## stick only steers (surf_turn). Jump hops with your speed, walls bounce you, and whatever you run into takes
## a bump. Let go of guard, or slow to surf_min on the flat, and you step off.
func _surf_step(dt: float, wish: Vector3) -> void:
	coyote = t.coyote_time
	var n := get_floor_normal()
	if n == Vector3.ZERO:
		n = Vector3.UP
	var v := velocity - n * velocity.dot(n)
	var g := Vector3.DOWN * t.gravity
	var down := (g - n * g.dot(n)) * t.slope_factor
	v += down * dt
	v = v.move_toward(Vector3.ZERO, t.surf_friction * dt)
	var w := wish - n * wish.dot(n)
	if w.length() > 0.2 and v.length() > 0.5:
		var ang := v.signed_angle_to(w, n)
		v = v.rotated(n, clampf(ang, -t.surf_turn * dt, t.surf_turn * dt))
	if is_on_wall():
		var wn := get_wall_normal()
		wn.y = 0.0
		if wn.length() > 0.5 and v.dot(wn.normalized()) < 0.0:
			wn = wn.normalized()
			v = (v - wn * 2.0 * v.dot(wn)) * 0.7 # bounce off
			Hitfx.shake(get_tree(), 0.08)
	v = v.limit_length(t.boost_speed)
	up_direction = n
	velocity = v
	facing = v.normalized() if v.length() > 0.5 else facing
	if down.length() < 1.0 and v.length() < t.surf_min:
		surfing = false
	# bump whatever you surf into
	var now := Time.get_ticks_msec()
	for m in get_tree().get_nodes_in_group("monsters"):
		var mn := m as Monster
		var d := mn.global_position - global_position
		if d.length() < radius() + 1.0 and v.length() > 4.0 and now - int(_surf_hit.get(mn.get_instance_id(), -100000)) > 500:
			_surf_hit[mn.get_instance_id()] = now
			mn.strike(1 + (1 if v.length() > t.fast_blade_speed else 0), global_position, {"head": "shield", "knock": v.length() * 0.8, "above": true})
			Hitfx.hit(get_tree(), mn.global_position, t, 1.0, mn)
	if buffer > 0.0:
		_ground_jump(n)

## Coming down on something with your shield under you: it's a pogo, even on a spiked monster's head.
func _surf_pogo() -> void:
	for n in get_tree().get_nodes_in_group("monsters"):
		var node := n as Monster
		if node == _pogo_last:
			continue
		var d := node.global_position - global_position
		if d.y < -0.2 and d.y > -(radius() + 1.3) and Vector2(d.x, d.z).length() < radius() + 0.8:
			node.strike(2, global_position, {"head": "shield", "knock": 3.0, "above": true, "air": true})
			Hitfx.hit(get_tree(), node.global_position, t, 1.3, node)
			velocity = Vector3(velocity.x, t.pogo_speed, velocity.z)
			global_position.y = maxf(global_position.y, node.global_position.y + radius() + 0.7)
			_pogo_last = node
			air_lock = 0.1
			jumping = false
			jump_chain = 0
			return

## The monster you're locked on to, if it's a monster.
func _focus_target() -> Monster:
	if target_held and target != null and is_instance_valid(target) and target is Monster:
		return target as Monster
	return null

## Locked on at the poleaxe's measure (focus_near to focus_far: just outside its reach), focus builds. Anywhere else it drains.
func _update_focus(dt: float) -> void:
	var m := _focus_target()
	if m == null:
		focus_meter = 0.0
		return
	var d := m.global_position - global_position
	var dist := Vector2(d.x, d.z).length()
	if dist >= t.focus_near and dist <= t.focus_far:
		focus_meter = minf(focus_meter + t.focus_rate * dt, 1.0)
	else:
		focus_meter = maxf(focus_meter - t.focus_rate * dt, 0.0)

## Full focus: the attack steps you in to exactly tip range and thrusts (the flash move: 4 damage and a stagger).
func _flash_step() -> void:
	var m := _focus_target()
	var d := m.global_position - global_position
	d.y = 0.0
	var dist := d.length()
	flash_t = 0.1
	velocity = d.normalized() * maxf(dist - (Poleaxe.TIP_FROM + 0.35), 0.0) / flash_t
	facing = d.normalized()
	focus_meter = 0.0
	poleaxe.flash()

func _can_pound() -> bool:
	return pound_t < 0.0 and not hands_full() and homing == null and rail == null and hang == Vector3.ZERO \
		and climbing == null and grapple_t <= 0.0 and not magnet_flying

## Ground pound (attack in the air without lock-on, hands empty): a short pause, then straight down at pound_speed.
## - Onto a monster or spikes: it hits (2) and bounces you up, ready to pound or home in on the next. A monster in
##   the air (launched) is spiked down. A monster with spikes on its head hurts you instead: surf onto those.
## - Onto flat ground: a shockwave hurts what's right around you, and jumping within pound_jump_window is a
##   high jump. Holding a direction as you land rolls you out instead (jump out of the roll: long jump).
## - Onto a slope: the fall turns into speed downhill.
func _pound_step(dt: float, on_floor: bool, wish: Vector3) -> void:
	pound_t += dt
	jumping = false
	roll_t = 0.0
	if pound_t < t.pound_hover:
		velocity = Vector3.ZERO
		return
	# something to bounce off right below?
	for n in get_tree().get_nodes_in_group("hurtable") + get_tree().get_nodes_in_group("pogo"):
		var node := n as Node3D
		if node == self or node is CrackedWall:
			continue
		var d := node.global_position - global_position
		if d.y < 0.2 and d.y > -(radius() + 1.2) and Vector2(d.x, d.z).length() < radius() + 0.7:
			pound_t = -1.0
			if node is Monster and (node as Monster).spiked:
				velocity = Vector3.UP * t.pogo_speed * 0.6
				hurt(1, node.global_position + Vector3.UP * 0.5, node)
				return
			if node is Monster:
				(node as Monster).strike(2, global_position, {"head": "pound", "spike": true, "above": true, "knock": 4.0})
			elif node.is_in_group("hurtable"):
				node.hurt(2, global_position)
			Hitfx.hit(get_tree(), node.global_position, t, 1.4, node)
			velocity = Vector3.UP * t.pogo_speed * 1.2
			global_position.y = maxf(global_position.y, node.global_position.y + radius() + 0.6)
			_pogo_last = node
			air_lock = 0.1
			jump_chain = 0
			return
	if on_floor and pound_t > t.pound_hover + 0.02:
		pound_t = -1.0
		var fall := t.pound_speed
		var n := get_floor_normal()
		Hitfx.shake(get_tree(), 0.25)
		for h in get_tree().get_nodes_in_group("hurtable"):
			var hn := h as Node3D
			if hn != self and not (hn is CrackedWall) and hn.global_position.distance_to(global_position) < 2.2:
				hn.hurt(1, global_position)
		for pn in get_tree().get_nodes_in_group("poundable"): # things only a pound cracks (a colossus's back plate)
			if (pn as Node3D).global_position.distance_to(global_position) < 2.5:
				(pn.get_meta("on_pound") as Callable).call()
		var down := Vector3.DOWN - n * Vector3.DOWN.dot(n)
		if n.y < 0.97 and down.length() > 0.05:
			velocity = down.normalized() * maxf(flat_speed(), fall * t.pound_slide)
			return
		velocity = Vector3.ZERO
		if wish.length() > 0.5:
			_start_roll(wish)
			_ledge_roll = _pound_ledge # ledge pull-up, pound, roll: its long jump gets ledge_long_mult
			return
		pound_land = 0.0
		return
	velocity = Vector3.DOWN * t.pound_speed

## Air attack while holding lock-on: home in on the nearest thing to hit ahead of you. It doesn't stick to
## your lock-on target, so after a bounce it chains on to the next one. Returns false if there's nothing in
## reach, and the poleaxe does an air slash instead. Monsters with spikes on their heads are skipped. (Without lock-on the air attack is a ground pound.)
func _start_homing() -> bool:
	var best: Node3D = null
	var best_d := t.homing_range
	var f := _flat_facing()
	var cands: Array = get_tree().get_nodes_in_group("hurtable") + get_tree().get_nodes_in_group("pogo")
	for n in cands:
		var node := n as Node3D
		if node == self or node is Player or node is CrackedWall:
			continue
		if node is Monster and (node as Monster).spiked:
			continue # spikes on its head: homing onto it would hurt (surf onto it instead)
		if node == _pogo_last and not (node is Monster and (node as Monster).air and (node as Monster).juggle < Monster.JUGGLE_MAX):
			continue # not the same one again until you land, unless you're juggling it
		var d := node.global_position - global_position
		var ahead := Vector2(d.x, d.z).length() < 1.5 or Vector3(d.x, 0, d.z).normalized().dot(f) >= 0.3 # right overhead counts
		if d.length() > best_d or not ahead:
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
	if target_held and best.is_in_group("targets"):
		target = best # the lock-on follows the chain, so the camera looks ahead, not back at the last one
	homing_t = best_d / t.homing_speed + 0.25
	poleaxe.start("air")
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
		if homing.is_in_group("hurtable") and not poleaxe._hit.has(homing): # the air slash may have hit it already
			poleaxe._hit.append(homing)
			if homing is Monster:
				(homing as Monster).strike(2, global_position, {"head": "blade", "air": true, "knock": 5.0})
			else:
				homing.hurt(2, global_position)
		Hitfx.hit(get_tree(), homing.global_position, t, 1.2, homing)
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

# --- carried by the spider (Spider.context) ---

## The spider can pick you up while you steer it (you sit still meanwhile).
func loose() -> bool:
	return carried_by == null and pilot != null and spider == pilot

func carry_size() -> Vector3:
	return Vector3.ONE * radius() * 2.0

func hold(by: Node3D) -> void:
	carried_by = by
	velocity = Vector3.ZERO
	_col.set_deferred("disabled", true) # you ride over its back without bumping anything

func set_down(pos: Vector3) -> void:
	_end_carried()
	global_position = pos
	velocity = Vector3.ZERO

func throw(v: Vector3) -> void:
	_end_carried()
	velocity = v
	air_lock = 0.15
	jumping = false

func _end_carried() -> void:
	if carried_by == null:
		return
	carried_by = null
	_col.set_deferred("disabled", false)

## Riding the spider: you go where it goes. Steer yourself again (the spider item) and it sets you down.
## Returns true while you ride.
func _carried_step() -> bool:
	if not is_instance_valid(carried_by):
		_end_carried()
		return false
	if pilot == null:
		if carried_by.has_method("release"):
			carried_by.release(true)
		_end_carried()
		return false
	global_position = carried_by.global_position + Vector3.UP * (carried_by.radius() + radius() + 0.1)
	velocity = Vector3.ZERO
	return true
