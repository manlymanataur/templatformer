extends SceneTree
## Headless feel tests. Run: godot --headless --fixed-fps 60 --path . -s res://tests/run_tests.gd
## Each test drives the player with scripted input in the real test room and checks a feel number.

var level
var p: Player
var fails := 0

func _initialize() -> void:
	level = load("res://scenes/test_room.tscn").instantiate()
	level.use_defaults = true
	root.add_child(level)
	_run.call_deferred()

func frames(n: int) -> void:
	for i in n:
		await physics_frame

func place(pos: Vector3, vel := Vector3.ZERO) -> void:
	p.ai = true
	p.ai_move = Vector2.ZERO
	p.ai_jump = false
	p.ai_target = false
	p.global_position = pos
	p.velocity = vel
	p.up_direction = Vector3.UP
	await frames(3)
	for i in 30: # settle onto the ground before the test starts
		if p.is_on_floor():
			break
		await physics_frame
	p.velocity = vel

func check(name: String, ok: bool, detail: String) -> void:
	print(("PASS  " if ok else "FAIL  ") + name + "  (" + detail + ")")
	if not ok:
		fails += 1

func _run() -> void:
	p = level.player
	var t: Tuning = level.t
	var m: Dictionary = level.marks
	# the arena's monsters would wander into other tests; each combat test spawns its own
	for mon in get_nodes_in_group("monsters"):
		mon.queue_free()
	for pk in get_nodes_in_group("pickups"):
		pk.queue_free()
	await frames(5)

	# 1. Standing jump height matches jump_speed^2 / 2g
	await place(Vector3(0, 0.6, 5))
	await frames(20)
	var y0 := p.global_position.y
	var top := y0
	p.ai_jump = true
	for i in 90:
		await physics_frame
		top = maxf(top, p.global_position.y)
	p.ai_jump = false
	var want := t.jump_speed * t.jump_speed / (2.0 * t.gravity)
	check("full jump height", absf(top - y0 - want) < 0.25, "%.2f m, expected %.2f" % [top - y0, want])

	# 2. Short hop: tap jump for 3 frames
	await place(Vector3(0, 0.6, 5))
	await frames(20)
	y0 = p.global_position.y
	top = y0
	p.ai_jump = true
	await frames(3)
	p.ai_jump = false
	for i in 60:
		await physics_frame
		top = maxf(top, p.global_position.y)
	check("short hop is lower than full jump", top - y0 < want * 0.6, "%.2f m" % (top - y0))

	# 3. Reach top speed on flat ground
	await place(Vector3(70, 0.6, -60))
	p.ai_move = Vector2(0, 1)
	var tt := 0.0
	while p.speed() < t.top_speed - 0.1 and tt < 3.0:
		await physics_frame
		tt += 1.0 / 60.0
	check("reach top speed", tt < 1.0, "%.2f s to %.0f m/s" % [tt, t.top_speed])

	# 4-6. Ramps: 30° climbable from a run, 60° is not climbable by walking up from rest
	for a in [30, 45, 60]:
		await place(m["ramp%d" % a], Vector3(0, 0, -t.top_speed))
		p.ai_move = Vector2(0, -1)
		var hi := 0.0
		for i in 150:
			await physics_frame
			hi = maxf(hi, p.global_position.y)
		var need: float = m["ramp%d_top" % a]
		if a == 60:
			await place(m["ramp60"] + Vector3(0, 0, -5.5))
			p.ai_move = Vector2(0, -1)
			hi = 0.0
			for i in 150:
				await physics_frame
				hi = maxf(hi, p.global_position.y)
			check("60° ramp can't be walked up from rest", hi < need * 0.5, "reached %.1f of %.1f m" % [hi, need])
		else:
			check("%d° ramp climbable from a run" % a, hi > need * 0.9, "reached %.1f of %.1f m" % [hi, need])

	# 7. Step heights: jump straight up next to the step, drift on once above it. 2 m clears, 3 m doesn't.
	for h in [2.0, 3.0]:
		await place(m["step%.1f" % h] + Vector3(0, 0, -1.6))
		p.ai_jump = true
		for i in 70:
			await physics_frame
			p.ai_move = Vector2(0, -1) if p.global_position.y > h + 0.55 and p.global_position.z > -8.0 else Vector2.ZERO
		p.ai_jump = false
		p.ai_move = Vector2.ZERO
		await frames(30)
		var on_top: bool = p.global_position.y > h
		check("jump onto %.1f m step" % h, on_top == (h <= want - 0.3), "ended at y %.1f" % p.global_position.y)

	# 8. Running gaps: at top speed, 8 m clears, 12 m doesn't
	for g in [8, 12]:
		var start: Vector3 = m["gap%d" % g]
		await place(start, Vector3(-t.top_speed, 0, 0))
		p.ai_move = Vector2(-1, 0)
		# jump when 0.6 m from the edge
		var edge_x: float = m["gap%d_edge" % g]
		var flying := false
		for i in 240:
			await physics_frame
			if p.global_position.x < edge_x + 0.6 and not p.ai_jump:
				p.ai_jump = true
			if p.ai_jump and not p.is_on_floor():
				flying = true
			elif flying:
				break # landed: brake so we don't run off the far end
		p.ai_move = Vector2(1, 0)
		p.ai_jump = false
		await frames(15)
		p.ai_move = Vector2.ZERO
		await frames(30)
		var made: bool = p.global_position.y > m["gap_y"]
		check("running jump over %d m gap" % g, made == (g <= 8), "ended at y %.1f" % p.global_position.y)

	# 11. Quarter pipe: launched up, comes back down
	await place(m["pipe_start"])
	p.ai_move = Vector2(0, -1)
	var hi := 0.0
	for i in 240:
		await physics_frame
		hi = maxf(hi, p.global_position.y)
	p.ai_move = Vector2.ZERO
	await frames(120)
	check("quarter pipe launches and lands", hi > 7.0 and p.global_position.y < 1.5, "peak %.1f m, ended y %.1f" % [hi, p.global_position.y])

	# 12. Lock-on picks a target and faces it
	await place(m["targets"])
	p.ai_target = true
	await frames(30)
	var ok: bool = p.target != null
	var face := 0.0
	if ok:
		var d: Vector3 = p.target.global_position - p.global_position
		d.y = 0
		face = p.facing.dot(d.normalized())
	check("lock-on faces target", ok and face > 0.9, "facing dot %.2f" % face)

	await _combat_tests()
	print("\n%d failed" % fails)
	quit(1 if fails else 0)

func _fresh_player(pos: Vector3) -> void:
	await place(pos)
	p.hp = p.max_hp
	p.invuln = 0.0
	p.inventory = Inventory.new()
	p.facing = Vector3.FORWARD
	p.target = null
	p.roll_t = 0.0
	p.jump_chain = 0
	if p.carrying != null:
		p.carrying.queue_free()
		p.carrying = null
	p.spear.busy = 0.0
	p.spear.combo_step = 0
	p.attack_held_t = 0.0
	p._tap_t = -1.0
	p._roll_wish = Vector3.ZERO
	p.magnet_push = false
	if p.candle_lit:
		p.set_candle(false)
	if p.umbra != null:
		p.umbra.fade()

func _monster_ahead(dist: float) -> Monster:
	var mon := Monster.spawn(level, p.global_position + Vector3(0, 0.2, -dist))
	mon.drop_heart = false
	mon.home = mon.global_position
	return mon

func _combat_tests() -> void:
	var arena := Vector3(-60, 0.6, 60) # empty floor far from everything else

	# 12. Spear: each thrust hits once (not once per frame), 3 thrusts kill a blob
	await _fresh_player(arena)
	p.inventory.add("spear")
	var mon := _monster_ahead(1.6)
	var hits := []
	for k in 3:
		mon.global_position = p.global_position + Vector3(0, 0.1, -1.6)
		mon.velocity = Vector3.ZERO
		mon.stun = 5.0 # hold still so only the spear matters
		p.ai_attack = true
		await frames(24)
		hits.append(mon.hp if is_instance_valid(mon) else 0)
	check("spear: 3 thrusts, 1 damage each", hits == [2, 1, 0], "hp after each thrust %s" % [hits])
	await frames(2)
	check("dead blob is removed", not is_instance_valid(mon), "")

	# 13. No spear, no attack
	await _fresh_player(arena)
	mon = _monster_ahead(1.6)
	mon.stun = 5.0
	p.ai_attack = true
	await frames(24)
	check("can't attack before finding the spear", mon.hp == 3, "blob hp %d" % mon.hp)
	mon.queue_free()

	# 14. Contact damage: half a heart per touch, then a second of invincibility
	await _fresh_player(arena)
	mon = _monster_ahead(3.0)
	var t0 := p.hp
	for i in 120: # it chases until it touches you
		await physics_frame
		if p.hp < t0:
			break
	var hit_at := p.global_position
	await frames(30) # knockback plays out
	var after_touch := p.hp
	var knocked: float = (p.global_position - hit_at).length()
	check("blob touch costs half a heart", after_touch == p.max_hp - 1, "hp %d of %d" % [after_touch, p.max_hp])
	check("hit knocks you back", knocked > 1.0, "moved %.1f m" % knocked)
	mon.queue_free()

	# 15. Invincibility: two hits inside a second only count once
	await _fresh_player(arena)
	p.hurt(1, p.global_position + Vector3.FORWARD)
	p.hurt(1, p.global_position + Vector3.FORWARD)
	var mid := p.hp
	await frames(70)
	p.hurt(1, p.global_position + Vector3.FORWARD)
	check("invincibility after a hit", mid == p.max_hp - 1 and p.hp == p.max_hp - 2, "hp %d then %d" % [mid, p.hp])

	# 16. Running out of health respawns you with full hearts
	await _fresh_player(arena)
	p.hp = 1
	p.hurt(1, p.global_position + Vector3.FORWARD)
	await frames(2)
	check("death respawns at full health", p.hp == p.max_hp and p.global_position.distance_to(p.spawn) < 1.0,
		"hp %d, %.1f m from spawn" % [p.hp, p.global_position.distance_to(p.spawn)])

	# 16b. Walking into a pickup adds it
	await _fresh_player(arena)
	Pickup.spawn(level, "spear", 1, p.global_position + Vector3(0, 0.3, -3))
	p.ai_move = Vector2(0, -1)
	await frames(30)
	p.ai_move = Vector2.ZERO
	check("walking into the spear picks it up", p.inventory.has("spear"), "")

	# 17. Inventory: pickups go on free quick slots; assign swaps; potion only works when hurt
	await _fresh_player(arena)
	var inv := p.inventory
	inv.add("bombs", 5)
	inv.add("potion")
	inv.add("spear")
	check("items fill quick slots in order", inv.slots == (["bombs", "potion", ""] as Array[String]), "%s" % [inv.slots])
	inv.assign(0, "potion")
	check("assigning swaps slots", inv.slots == (["potion", "bombs", ""] as Array[String]), "%s" % [inv.slots])
	var used_full := inv.use(0, p)
	p.hp = 2
	var used_hurt := inv.use(0, p)
	check("potion: refused at full health, full heal when hurt", not used_full and used_hurt and p.hp == p.max_hp and inv.count("potion") == 0,
		"full %s, hurt %s, hp %d, left %d" % [used_full, used_hurt, p.hp, inv.count("potion")])

	# 18. Bombs: 2 damage to everything within 3.5 m after the fuse, you included
	await _fresh_player(arena)
	p.inventory.add("bombs", 5)
	mon = _monster_ahead(2.5)
	mon.stun = 10.0
	var far_mon := _monster_ahead(8.0)
	far_mon.stun = 10.0
	p.ai_item = 0 # pull one out
	await frames(3)
	p.ai_item = 0 # standing still: set it down in front
	await frames(3)
	p.ai_move = Vector2(0, 1) # walk away from the bomb
	await frames(40)
	p.ai_move = Vector2.ZERO
	await frames(130)
	check("bomb hurts a blob in range", is_instance_valid(mon) and mon.hp == 1, "hp %d" % (mon.hp if is_instance_valid(mon) else 0))
	check("bomb spares a blob out of range", far_mon.hp == 3, "hp %d" % far_mon.hp)
	check("you escaped your own bomb", p.hp == p.max_hp, "hp %d" % p.hp)
	check("bomb count went down", p.inventory.count("bombs") == 4, "%d left" % p.inventory.count("bombs"))
	mon.queue_free()
	far_mon.queue_free()

	# 19. Lock-on includes monsters
	await _fresh_player(arena)
	mon = _monster_ahead(5.0)
	mon.stun = 10.0
	p.ai_target = true
	await frames(10)
	check("lock-on targets monsters", p.target == mon, "")
	p.ai_target = false
	mon.queue_free()

	await _move_tests(arena)
	await _hall_tests(arena)
	await _yard_tests(arena)

func _apex_of_next_jump() -> float:
	# hold jump from the moment we leave the ground until we come back down
	var y0 := p.global_position.y
	p.ai_jump = true
	var top := y0
	var left := false
	for i in 120:
		await physics_frame
		top = maxf(top, p.global_position.y)
		if not p.is_on_floor():
			left = true
		elif left:
			break
	p.ai_jump = false
	return top - y0

func _move_tests(arena: Vector3) -> void:
	var t: Tuning = level.t
	var m: Dictionary = level.marks
	var mon: Monster

	# 20. Jump chain: single, double, triple while running, each re-jumped on landing
	await _fresh_player(Vector3(90, 0.6, 100))
	p.velocity = Vector3(0, 0, -t.top_speed)
	p.ai_move = Vector2(0, -1)
	await frames(10)
	var heights := []
	for k in 3:
		heights.append(await _apex_of_next_jump())
		# jump is released on landing; press again next frame for the chain
		await physics_frame
	p.ai_move = Vector2.ZERO
	var base := t.jump_speed * t.jump_speed / (2.0 * t.gravity)
	var want := [base, base * pow(t.double_jump_mult, 2), base * pow(t.triple_jump_mult, 2)]
	var ok := true
	for k in 3:
		ok = ok and absf(heights[k] - want[k]) < 0.35
	check("running jump chain: single, double, triple", ok, "%.1f / %.1f / %.1f m, expected %.1f / %.1f / %.1f" % [heights[0], heights[1], heights[2], want[0], want[1], want[2]])

	# 21. Standing still, jumps don't chain
	await _fresh_player(Vector3(90, 0.6, 60))
	await frames(10)
	var h1 := await _apex_of_next_jump()
	await physics_frame
	var h2 := await _apex_of_next_jump()
	check("standing jumps don't chain", absf(h2 - h1) < 0.2, "%.1f then %.1f m" % [h1, h2])

	# 22. Triple jump clears the 12 m gap that a single jump can't: hop, hop on landing, triple off the edge
	var start: Vector3 = m["gap12"]
	await _fresh_player(start)
	p.velocity = Vector3(-t.top_speed, 0, 0)
	p.ai_move = Vector2(-1, 0)
	var edge_x: float = m["gap12_edge"]
	var hops := 0
	var landed_far := false
	for i in 300:
		await physics_frame
		if p.is_on_floor() and not p.ai_jump:
			# first hop 24 m out (two chain hops cover about 22 m), then re-jump on each landing
			if hops == 0 and p.global_position.x < edge_x + 24.0 or hops in [1, 2]:
				p.ai_jump = true
				hops += 1
		elif not p.is_on_floor() and p.ai_jump and p.velocity.y < 0.0:
			p.ai_jump = false
		if hops >= 3 and p.is_on_floor() and p.global_position.x < edge_x - 12.0:
			landed_far = p.global_position.y > m["gap_y"]
			break
		if p.global_position.y < -1.0:
			break
	p.ai_jump = false
	p.ai_move = Vector2.ZERO
	check("triple jump clears 12 m", landed_far, "ended x %.1f y %.1f after %d hops" % [p.global_position.x, p.global_position.y, hops])

	# 23. Wall jumps climb the 10 m shaft
	await _fresh_player(m["shaft"])
	var dir := -1.0
	p.ai_move = Vector2(dir, 0)
	p.ai_jump = true
	var hi := 0.0
	for i in 360:
		await physics_frame
		hi = maxf(hi, p.global_position.y)
		if p.is_on_wall() and not p.is_on_floor():
			if p.ai_jump:
				p.ai_jump = false
			else:
				p.ai_jump = true
				dir = -dir
				p.ai_move = Vector2(dir, 0)
		elif p.ai_jump and p.velocity.y < 0.0 and not p.is_on_floor():
			p.ai_jump = false
		if p.global_position.y > float(m["shaft_top"]) + 0.3 and p.is_on_floor():
			break
	p.ai_jump = false
	p.ai_move = Vector2.ZERO
	check("wall jumps reach the top of the 10 m shaft", hi > float(m["shaft_top"]), "peak %.1f m" % hi)

	# 24. Wall slide: pushing into a wall caps your fall speed
	await _fresh_player(m["shaft"] + Vector3(-1.0, 8.0, 0))
	p.ai_move = Vector2(-1, 0)
	var fastest := 0.0
	for i in 40:
		await physics_frame
		if i > 20:
			fastest = maxf(fastest, -p.velocity.y)
	p.ai_move = Vector2.ZERO
	check("wall slide caps fall speed", fastest <= t.wall_slide_speed + 0.5, "fastest fall %.1f m/s" % fastest)

	# 25. Roll (a quick tap of the stick, there's no roll button): covers ground fast and dodges a hit early on
	await _fresh_player(arena)
	var x0 := p.global_position
	await _tap(Vector3.FORWARD)
	check("a quick tap rolls", p.roll_t > 0.0 and p.roll_kind == "roll", "rolling %s" % (p.roll_t > 0.0))
	p.hurt(1, p.global_position + Vector3.FORWARD)
	var dodged := p.hp == p.max_hp
	await frames(24)
	var dist := (p.global_position - x0).length()
	check("roll dodges a hit", dodged, "hp %d" % p.hp)
	check("roll covers ground", dist > 4.0, "%.1f m in 0.45 s" % dist)

	# 26. Locked on: roll sideways = side hop, roll back = backflip
	await _fresh_player(arena)
	mon = _monster_ahead(6.0)
	mon.stun = 20.0
	p.ai_target = true
	await frames(10)
	x0 = p.global_position
	await _tap(p._flat_facing().cross(Vector3.UP))
	await frames(18)
	var d := p.global_position - x0
	check("locked-on side hop moves sideways", absf(d.x) > 2.0 and absf(d.z) < 1.0 and p.roll_kind == "sidehop", "moved %s" % [d.snapped(Vector3(0.1, 0.1, 0.1))])
	await frames(30)
	x0 = p.global_position
	var away := -p._flat_facing() # stick pulled back, relative to the camera that faces the target
	var top := 0.0
	await _tap(away)
	for i in 40:
		await physics_frame
		top = maxf(top, p.global_position.y - x0.y)
	d = p.global_position - x0
	var went_back := Vector3(d.x, 0, d.z).dot(away)
	check("locked-on backflip goes up and back", top > 2.0 and went_back > 1.5 and p.roll_kind == "backflip", "up %.1f, back %.1f" % [top, went_back])
	p.ai_move = Vector2.ZERO
	p.ai_target = false
	mon.queue_free()

	# 27. Strafe: holding target with nothing nearby keeps you facing forward while moving sideways
	await _fresh_player(Vector3(90, 0.6, 20))
	p.ai_target = true
	await frames(3)
	p.ai_move = Vector2(1, 0)
	var fastest_strafe := 0.0
	for i in 60:
		await physics_frame
		fastest_strafe = maxf(fastest_strafe, p.flat_speed())
	check("strafe keeps facing and uses strafe speed", p.facing.dot(Vector3.FORWARD) > 0.95 and fastest_strafe <= t.strafe_speed + 0.2,
		"facing dot %.2f, speed %.1f" % [p.facing.dot(Vector3.FORWARD), fastest_strafe])
	p.ai_move = Vector2.ZERO
	p.ai_target = false

	# 28. Quick combo: jab, jab, sweep = 1 + 1 + 2 damage
	await _fresh_player(arena)
	p.inventory.add("spear")
	mon = _monster_ahead(1.6)
	mon.hp = 10
	var seq := []
	for k in 3:
		mon.global_position = p.global_position + Vector3(0, 0.1, -1.6)
		mon.velocity = Vector3.ZERO
		mon.stun = 5.0
		p.ai_attack = true
		await frames(int(Spear.MOVES[Spear.COMBO[k]]["dur"] * 60.0) + 4)
		seq.append(mon.hp)
	check("quick combo: jab, jab, sweep", seq == [9, 8, 6], "hp after each %s" % [seq])

	# 29. Waiting too long restarts the combo at a jab
	await frames(40)
	mon.global_position = p.global_position + Vector3(0, 0.1, -1.6)
	var before: int = mon.hp
	p.ai_attack = true
	await frames(20)
	check("combo resets after a pause", before - mon.hp == 1 and p.spear.move == "jab", "took %d, move %s" % [before - mon.hp, p.spear.move])
	mon.queue_free()

	# 30. Charged spin hits in front and behind
	await _fresh_player(arena)
	p.inventory.add("spear")
	var front := _monster_ahead(2.0)
	var back := _monster_ahead(-2.0)
	for mm in [front, back]:
		mm.stun = 20.0
		mm.hp = 10
	p.ai_attack_held = true
	await frames(int(t.spin_charge_time * 60.0) + 25)
	for mm in [front, back]:
		mm.hp = 10 # ignore the opening jab
	p.ai_attack_held = false
	await frames(35)
	check("charged spin hits all around", front.hp == 8 and back.hp == 8, "front %d, back %d" % [front.hp, back.hp])
	front.queue_free()
	back.queue_free()

	# 31. Long slash: attacking at full speed lunges and hits from further away
	await _fresh_player(Vector3(90, 0.6, -20))
	p.inventory.add("spear")
	p.velocity = Vector3(0, 0, -t.top_speed)
	p.ai_move = Vector2(0, -1)
	await frames(5)
	mon = _monster_ahead(4.5)
	mon.stun = 20.0
	p.ai_move = Vector2.ZERO
	p.ai_attack = true
	await frames(30)
	check("running long slash", p.spear.move == "lunge" and mon.hp == 1, "move %s, blob hp %d" % [p.spear.move, mon.hp])
	mon.queue_free()

	# 32. Air slash hits a blob below and in front
	await _fresh_player(arena)
	p.inventory.add("spear")
	mon = _monster_ahead(1.5)
	mon.stun = 20.0
	p.ai_jump = true
	await frames(12)
	p.ai_jump = false
	p.ai_attack = true
	await frames(40)
	check("air slash", p.spear.move == "air" and mon.hp == 1, "move %s, blob hp %d" % [p.spear.move, mon.hp])
	mon.queue_free()

	# 33. Bombs: thrown while moving lands a few metres away, set down while still lands at your feet
	await _fresh_player(Vector3(90, 0.6, -60))
	p.inventory.add("bombs", 5)
	p.ai_item = 0
	await frames(3)
	var held := p.carrying
	p.ai_move = Vector2(0, -1)
	await frames(10)
	var throw_from := p.global_position
	p.ai_item = 0
	await frames(3)
	p.ai_move = Vector2.ZERO
	await frames(60)
	var throw_dist := Vector2(held.global_position.x - throw_from.x, held.global_position.z - throw_from.z).length()
	check("thrown bomb lands a few metres ahead", throw_dist > 3.5 and throw_dist < 9.0, "%.1f m" % throw_dist)
	await frames(120) # let it go off
	await _fresh_player(Vector3(90, 0.6, -80))
	p.inventory.add("bombs", 5)
	p.ai_item = 0
	await frames(3)
	held = p.carrying
	p.ai_item = 0
	await frames(30)
	var set_dist := Vector2(held.global_position.x - p.global_position.x, held.global_position.z - p.global_position.z).length()
	check("bomb set down at your feet", set_dist < 1.5, "%.1f m" % set_dist)
	await frames(150)

	# 34. Launch pads
	await _fresh_player(m["pad_up"])
	p.ai_move = Vector2(0, -1)
	hi = 0.0
	for i in 120:
		await physics_frame
		hi = maxf(hi, p.global_position.y)
		if i > 20 and p.is_on_floor():
			p.ai_move = Vector2.ZERO
	await frames(20)
	check("launch pad lifts you onto the 6 m platform", hi > 6.5 and p.global_position.y > 6.0, "peak %.1f, ended y %.1f" % [hi, p.global_position.y])
	await _fresh_player(m["pad_far"])
	p.ai_move = Vector2(0, -1)
	for i in 150:
		await physics_frame
		if i > 30 and p.is_on_floor():
			p.ai_move = Vector2.ZERO
	check("launch pad throws you onto the far platform", p.global_position.y > 1.0 and p.global_position.z < -54.0,
		"ended y %.1f z %.1f" % [p.global_position.y, p.global_position.z])


## Call Umbra with the camera facing +Z (the way into the hall), so its mirror line is the X axis.
## A quick flick of the stick one way and back to neutral; returns once the roll has started.
func _tap(dir: Vector3) -> void:
	p.ai_move = Vector2(dir.x, dir.z)
	await frames(5)
	p.ai_move = Vector2.ZERO
	await frames(2)

func _summon_facing_north() -> Umbra:
	p.cam_basis = Basis(Vector3.UP, PI)
	p.toggle_umbra()
	return p.umbra

func _hall_tests(arena: Vector3) -> void:
	var t: Tuning = level.t
	var m: Dictionary = level.marks
	var mon: Monster

	# 35. Locked on, a quick tap of the stick dodges; holding it just strafes
	mon = await _monster_ahead(6.0)
	mon.stun = 60.0
	p.ai_target = true
	await frames(10)
	var f := p._flat_facing()
	var side := f.cross(Vector3.UP)
	var kinds := []
	for k in 3:
		f = p._flat_facing() # taps are read relative to where you face, like a stick relative to the camera
		side = f.cross(Vector3.UP)
		var dir: Vector3 = [side, -f, f][k]
		p.ai_move = Vector2(dir.x, dir.z)
		await frames(5)
		p.ai_move = Vector2.ZERO
		await frames(4)
		kinds.append(p.roll_kind if p.roll_t > 0.0 else "none")
		await frames(50)
	check("tap dodges: side hop, backflip, roll", kinds == ["sidehop", "backflip", "roll"], str(kinds))
	var dodged := false
	p.ai_move = Vector2(side.x, side.z)
	for i in 40:
		await physics_frame
		dodged = dodged or p.roll_t > 0.0
	p.ai_move = Vector2.ZERO
	for i in 20:
		await physics_frame
		dodged = dodged or p.roll_t > 0.0
	check("holding the stick strafes without dodging", not dodged, "dodged %s" % dodged)
	p.ai_target = false
	mon.queue_free()

	# 36. Light: the lantern lights its chasm, your body shadows it, and wearing the candle you shine instead
	var spot := Vector3(-6, 4.5, 104)
	await _fresh_player(Vector3(6, 4.6, 104))
	var open_lit := Lighting.is_lit(spot, p)
	await _fresh_player(m["hall_c"])
	var shadowed := not Lighting.is_lit(spot, p)
	p.set_candle(true)
	var candle_lit := Lighting.is_lit(spot, p)
	check("lantern lights the chasm, your body shadows it, the candle doesn't", open_lit and shadowed and candle_lit,
		"lit %s, in your shadow %s, with candle %s" % [open_lit, shadowed, candle_lit])
	var dark_spot := Vector3(-4, 4.5, 84)
	var far_spot := Vector3(-4, 4.5, 92) # about 15 m away, same dark room, clear line
	await _fresh_player(Vector3(0.8, 4.6, 78))
	var dark := not Lighting.is_lit(dark_spot, p)
	p.inventory.add("candle")
	p.ai_item = p.inventory.slots.find("candle")
	await frames(2)
	var by_candle := Lighting.is_lit(dark_spot, p) and p.candle_lit
	var out_of_reach := not Lighting.is_lit(far_spot, p)
	check("candle hat lights %.0f m around you in the dark hall" % t.candle_range, dark and by_candle and out_of_reach,
		"dark %s, lit by candle %s, dark past reach %s" % [dark, by_candle, out_of_reach])

	# 37. The candle burns the vine wall; without it you're stuck
	var vines: float = m["hall_vines"]
	await _fresh_player(m["hall_a"])
	p.ai_move = Vector2(0, 1)
	await frames(60)
	var stuck := p.global_position.z < vines
	p.set_candle(true)
	await frames(150)
	p.ai_move = Vector2.ZERO
	check("candle burns through the vine wall", stuck and p.global_position.z > vines + 1.0, "stuck without %s, got to z %.1f" % [stuck, p.global_position.z])

	# 38. Grass fire spreads, melts the ice round the brazier and lights it, which opens the gate
	await frames(300)
	var gate_a: Gate = m["hall_a_gate"]
	var far := 0
	for g in get_nodes_in_group("flammable"):
		if g is Burnable and g.kind == "grass" and g.burnt:
			far += 1
	check("grass fire spreads, melts the ice, lights the brazier, opens the gate", far == 12 and gate_a.opened, "%d of 12 patches burnt, gate open %s" % [far, gate_a.opened])

	# 39. Umbra appears in front of you, then floats over the dark chasm, mirrored, to the moon plate
	await _fresh_player(m["hall_b"])
	var u := _summon_facing_north()
	var ahead := u.global_position - p.global_position
	check("Umbra appears 1.5 m in front of you", absf(ahead.z - 1.5) < 0.05 and absf(ahead.x) < 0.05, "offset %s" % [ahead])
	var ux0 := u.global_position.x
	var y_start := u.global_position.y
	var low := y_start
	p.ai_move = Vector2(1, 0)
	for i in 120:
		await physics_frame
		if is_instance_valid(u):
			low = minf(low, u.global_position.y)
	p.ai_move = Vector2.ZERO
	var gate_b: Gate = m["hall_b_gate"]
	var ok := is_instance_valid(u) and u.global_position.x < ux0 - 8.0
	check("walking +X sends Umbra -X across the dark chasm", ok and y_start - low < 0.1, "Umbra x %.1f, dipped %.2f m" % [u.global_position.x if ok else 0.0, y_start - low])
	check("Umbra on the moon plate opens the gate", gate_b.opened, "open %s" % gate_b.opened)
	await _fresh_player(m["hall_b"])
	u = _summon_facing_north()
	var uz0 := u.global_position.z
	p.ai_move = Vector2(0, 1)
	await frames(20)
	p.ai_move = Vector2.ZERO
	var dz: float = u.global_position.z - uz0
	check("walking +Z moves Umbra +Z too", dz > 0.8, "Umbra moved %.1f m" % dz)

	# 40. Light makes Umbra fall: over the chasm, putting the candle on drops it and it fades
	await _fresh_player(m["hall_b"])
	u = _summon_facing_north()
	p.ai_move = Vector2(1, 0)
	await frames(30)
	p.ai_move = Vector2.ZERO
	var over := u.global_position.x < -1.5
	p.set_candle(true)
	await frames(45)
	check("candle light drops Umbra into the chasm", over and p.umbra == null, "was over chasm %s, still out %s" % [over, p.umbra != null])

	# 41. In light Umbra crawls
	await _fresh_player(arena)
	u = _summon_facing_north()
	p.ai_move = Vector2(0, 1)
	await frames(30)
	var crawl := Vector2(u.velocity.x, u.velocity.z).length()
	var on_ground := u.is_on_floor()
	p.ai_move = Vector2.ZERO
	check("in sunlight Umbra crawls on the ground", u.lit and on_ground and crawl <= t.umbra_crawl_speed + 0.1, "lit %s, on ground %s, %.1f m/s" % [u.lit, on_ground, crawl])

	# 42. Across the lit chasm Umbra only floats inside your shadow: pinned at the railing on the lantern's line,
	# push forward and Umbra drifts through the bars onto the plate
	var gate_c: Gate = m["hall_c_gate"]
	await _fresh_player(m["hall_c"] + Vector3(3.5, 0, 0)) # well off the lantern's line
	u = _summon_facing_north()
	p.ai_move = Vector2(0, 1)
	for i in 90:
		await physics_frame
	p.ai_move = Vector2.ZERO
	var fell := p.umbra == null
	await _fresh_player(m["hall_c"])
	u = _summon_facing_north()
	p.ai_move = Vector2(0, 1)
	var held := true
	for i in 150:
		await physics_frame
		held = held and p.global_position.z < 100.0
		if p.umbra == null or gate_c.opened:
			break
	p.ai_move = Vector2.ZERO
	check("off the lantern's line Umbra falls", fell, "fell %s" % fell)
	check("in your shadow Umbra crosses the lit chasm and opens the gate", p.umbra != null and gate_c.opened and held,
		"Umbra out %s, gate open %s, railing held you %s" % [p.umbra != null, gate_c.opened, held])
	# the bay is barred: you can't walk in and call Umbra onto the plate yourself
	await _fresh_player(Vector3(-6, 4.6, 115))
	p.ai_move = Vector2(0, -1)
	await frames(60)
	p.ai_move = Vector2.ZERO
	check("the plate's bay keeps you out", p.global_position.z > 113.5, "reached z %.1f" % p.global_position.z)
	await _fresh_player(Vector3(-1.4, 4.6, 112))
	p.cam_basis = Basis(Vector3.UP, PI / 2.0) # facing west, at the bay's side wall
	p.toggle_umbra()
	check("Umbra doesn't appear through a wall", p.umbra.global_position.x > -2.0, "appeared at x %.1f" % p.umbra.global_position.x)
	p.toggle_umbra()


func _yard_tests(arena: Vector3) -> void:
	var t: Tuning = level.t
	var m: Dictionary = level.marks
	var mon: Monster

	# 43. Magnet: iron moves only when you're at its side, only the nearest in a line, one cell at a time
	await _fresh_player(arena)
	var a := IronCube.make(level, Vector3(arena.x, 0, arena.z - 8)) # in your column, 8 m north
	var b := IronCube.make(level, Vector3(arena.x, 0, arena.z - 14)) # behind it, shielded
	var d := IronCube.make(level, Vector3(arena.x + 4, 0, arena.z - 4)) # diagonal
	await frames(3) # let the new blocks register with physics before the magnet looks for them
	p.inventory.add("magnet")
	await frames(100)
	var az := a.global_position.z - arena.z
	var bz := b.global_position.z - arena.z
	var dmoved := d.global_position.distance_to(Vector3(arena.x + 4, 0, arena.z - 4))
	check("pull draws the nearest iron in line until it's beside you", absf(az + 2.0) < 0.05, "stopped %.1f m away" % -az)
	check("iron behind other iron is shielded", absf(bz + 14.0) < 0.05, "moved to %.1f" % bz)
	check("diagonal iron doesn't move", dmoved < 0.05, "moved %.2f m" % dmoved)
	p.inventory.slots[0] = "magnet"
	p.ai_item = 0
	await frames(120)
	az = a.global_position.z - arena.z
	check("push drives it away until something blocks it", p.magnet_push and absf(az + 12.0) < 0.05, "now %.1f m away" % -az)
	for c in [a, b, d]:
		c.queue_free()

	# 44. Power: iron between battery and door opens it; take it away and the door shuts
	var door: Gate = m["yard_door"]
	var iron_a: IronCube = m["yard_iron_a"]
	var closed_first := not door.opened
	await _fresh_player(m["yard_pull_a"])
	p.inventory.add("magnet")
	for i in 150:
		await physics_frame
	var in_gap := iron_a.global_position.distance_to(LodestoneYard.cell(2, 6)) < 0.05
	check("pulled iron stops in the gap and powers the door", closed_first and in_gap and door.opened and iron_a.powered,
		"door shut at first %s, iron in gap %s, door open %s" % [closed_first, in_gap, door.opened])
	p.magnet_push = true
	await frames(60)
	check("pushing the iron away cuts the power and shuts the door", not door.opened, "door open %s" % door.opened)

	# 45. Dead launch pad does nothing; push iron against it and its battery and it launches you onto the 6 m block
	var pad: Pad = m["yard_launch"]
	await _fresh_player(LodestoneYard.cell(7, 3) + Vector3.UP * 0.6)
	await frames(40)
	var dead_ok := p.global_position.y < 1.0 and not pad.powered
	await _fresh_player(m["yard_push_b"])
	p.inventory.add("magnet")
	p.magnet_push = true
	await frames(120)
	var iron_b: IronCube = m["yard_iron_b"]
	var b_at := iron_b.global_position.distance_to(LodestoneYard.cell(8, 3)) < 0.05
	await _fresh_player(LodestoneYard.cell(7, 6) + Vector3.UP * 0.6) # walk north onto the pad
	p.ai_move = Vector2(0, -1)
	var hi := 0.0
	for i in 150:
		await physics_frame
		hi = maxf(hi, p.global_position.y)
		if p.global_position.y > 1.0:
			p.ai_move = Vector2.ZERO # the pad does the rest
	p.ai_move = Vector2.ZERO
	check("dead launch pad does nothing", dead_ok, "y %.1f" % p.global_position.y)
	check("pushed iron powers the pad and it launches you onto the 6 m block", b_at and pad.powered and p.global_position.y > 6.0,
		"iron in place %s, powered %s, peak %.1f, ended y %.1f" % [b_at, pad.powered, hi, p.global_position.y])

	# 46. Boost: a running jump off the kicker can't clear the 14 m gap to the ledge; the booster can
	var ledge: float = m["yard_ledge_y"]
	var lip: float = m["yard_kicker_lip"]
	await _fresh_player(Vector3(75.5, 0.6, -6.5)) # the dead pad; start at full running speed, the best a run-up gives
	p.velocity = Vector3(0, 0, -t.top_speed)
	p.ai_move = Vector2(0, -1)
	for i in 240:
		await physics_frame
		if p.global_position.z < lip + 0.6 and not p.ai_jump:
			p.ai_jump = true
	p.ai_move = Vector2.ZERO
	p.ai_jump = false
	var reached := p.global_position.z
	check("a full-speed jump off the kicker falls short of the ledge", p.global_position.y < ledge - 0.5 and reached < lip,
		"ended y %.1f z %.1f" % [p.global_position.y, reached])
	var boost: Pad = m["yard_boost"]
	await _fresh_player(m["yard_boost_stand"])
	p.inventory.add("magnet")
	var fired := false
	hi = 0.0
	for i in 300:
		await physics_frame
		if boost.powered and not fired:
			fired = true
			p.ai_move = Vector2(0, -1)
		hi = maxf(hi, p.global_position.y)
		if fired and p.global_position.z < lip - 14.0 and p.is_on_floor():
			p.ai_move = Vector2.ZERO # landed: stop before running off the far end
	p.ai_move = Vector2.ZERO
	check("pulled iron powers the booster and it fires you across to the ledge", fired and p.global_position.y > ledge,
		"powered %s, peak %.1f, ended y %.1f" % [fired, hi, p.global_position.y])

	# 47. Umbra copies your attacks with its greatsword in the dark, not in light
	await _fresh_player(Vector3(6, 4.6, 88))
	p.inventory.add("spear")
	var u := _summon_facing_north()
	mon = Monster.spawn(level, u.global_position + Vector3(0, 0.2, -1.4))
	mon.drop_heart = false
	mon.home = mon.global_position
	mon.stun = 60.0
	await frames(5)
	var hp0 := mon.hp
	p.ai_attack = true
	await frames(30)
	var dark_hit := hp0 - mon.hp
	mon.queue_free()
	await _fresh_player(arena)
	p.inventory.add("spear")
	u = _summon_facing_north()
	mon = Monster.spawn(level, u.global_position + Vector3(0, 0.2, -1.4))
	mon.drop_heart = false
	mon.home = mon.global_position
	mon.stun = 60.0
	await frames(5)
	hp0 = mon.hp
	p.ai_attack = true
	await frames(30)
	var lit_hit := hp0 - mon.hp
	mon.queue_free()
	check("in the dark Umbra's greatsword copies your attack", dark_hit == Umbra.SWING_DAMAGE, "did %d damage" % dark_hit)
	check("in light Umbra doesn't swing", lit_hit == 0, "did %d damage" % lit_hit)

	# 48. With the candle hat on, your attacks are on fire
	var burned := []
	for lit in [false, true]:
		await _fresh_player(arena)
		p.inventory.add("spear")
		var grass := Burnable.make(level, "grass", arena + Vector3(0, -0.6, -1.8), Vector3(2, 0.3, 2))
		if lit:
			p.set_candle(true)
		await frames(3)
		p.ai_attack = true
		await frames(20)
		burned.append(grass.burning or grass.burnt)
		grass.queue_free()
	check("attacks set grass alight only while you wear the candle", burned == [false, true], "without %s, with %s" % [burned[0], burned[1]])
