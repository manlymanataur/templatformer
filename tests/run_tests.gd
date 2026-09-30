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
	await _rules_tests() # first, before any test moves iron or opens gates

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
	p.drop_holds()
	p.magnet_push = false
	if p.small:
		p.set_small(false, true)
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
	var arena := Vector3(-80, 0.6, -90) # empty floor far from everything else

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
	inv.add("candle")
	inv.add("potion")
	inv.add("spear")
	check("items fill quick slots in order", inv.slots == (["candle", "potion", ""] as Array[String]), "%s" % [inv.slots])
	inv.assign(0, "potion")
	check("assigning swaps slots", inv.slots == (["potion", "candle", ""] as Array[String]), "%s" % [inv.slots])
	var used_full := inv.use(0, p)
	p.hp = 2
	var used_hurt := inv.use(0, p)
	check("potion: refused at full health, full heal when hurt", not used_full and used_hurt and p.hp == p.max_hp and inv.count("potion") == 0,
		"full %s, hurt %s, hp %d, left %d" % [used_full, used_hurt, p.hp, inv.count("potion")])

	# 18. Bombs: 2 damage to everything within 3.5 m after the fuse, you included
	await _fresh_player(arena)
	mon = _monster_ahead(2.5)
	mon.stun = 10.0
	var far_mon := _monster_ahead(8.0)
	far_mon.stun = 10.0
	var plant := await _pull_bomb()
	var pulled := p.carrying != null and not plant.ripe()
	p.ai_context = true # standing still: set it down in front
	await frames(3)
	p.ai_move = Vector2(0, 1) # walk away from the bomb
	await frames(40)
	p.ai_move = Vector2.ZERO
	await frames(130)
	check("bomb hurts a blob in range", is_instance_valid(mon) and mon.hp == 1, "hp %d" % (mon.hp if is_instance_valid(mon) else 0))
	check("bomb spares a blob out of range", far_mon.hp == 3, "hp %d" % far_mon.hp)
	check("you escaped your own bomb", p.hp == p.max_hp, "hp %d" % p.hp)
	await frames(int(level.t.bomb_regrow * 60.0) - 170 + 5)
	check("context button pulls a bomb off its plant, which grows another in %.0f s" % level.t.bomb_regrow, pulled and plant.ripe(), "pulled %s, ripe again %s" % [pulled, plant.ripe()])
	plant.queue_free()
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
	await _scale_tests(arena)
	await _tool_tests(arena)
	await _rootworks_tests(arena)
	await _moves_yard_tests(arena)
	await _combo_tests(arena)
	await _challenge_tests(arena)
	await _colossus_tests()

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

	# 25. Roll (holding target, a quick forward tap; there's no roll button): covers ground fast and dodges a hit early on
	await _fresh_player(arena)
	await _tap(Vector3.FORWARD)
	await frames(10)
	var rolled_free := p.roll_t > 0.0
	await _fresh_player(arena)
	p.ai_target = true
	await frames(3)
	var x0 := p.global_position
	await _tap(Vector3.FORWARD)
	check("without target a tap just steps; holding target it rolls", not rolled_free and p.roll_t > 0.0 and p.roll_kind == "roll",
		"rolled without target %s, rolling with %s" % [rolled_free, p.roll_t > 0.0])
	p.hurt(1, p.global_position + Vector3.FORWARD)
	var dodged := p.hp == p.max_hp
	await frames(24)
	var dist := (p.global_position - x0).length()
	p.ai_target = false
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
	p.ai_target = true # locked on, the air attack is the spear's (without lock-on it's a ground pound)
	p.ai_attack = true
	await frames(40)
	p.ai_target = false
	check("air slash", p.spear.move == "air" and mon.hp == 1, "move %s, blob hp %d" % [p.spear.move, mon.hp])
	mon.queue_free()

	# 33. Bombs: thrown while moving lands a few metres away, set down while still lands at your feet
	await _fresh_player(Vector3(90, 0.6, -60))
	var bp := await _pull_bomb()
	bp.queue_free()
	var held := p.carrying
	p.ai_move = Vector2(0, -1)
	await frames(10)
	var throw_from := p.global_position
	p.ai_context = true
	await frames(3)
	p.ai_move = Vector2.ZERO
	await frames(60)
	var throw_dist := Vector2(held.global_position.x - throw_from.x, held.global_position.z - throw_from.z).length()
	check("thrown bomb lands a few metres ahead", throw_dist > 3.5 and throw_dist < 9.0, "%.1f m" % throw_dist)
	await frames(120) # let it go off
	await _fresh_player(Vector3(90, 0.6, -80))
	bp = await _pull_bomb()
	bp.queue_free()
	held = p.carrying
	p.ai_context = true
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
	var spot := Vector3(-3, 4.5, 106)
	await _fresh_player(m["hall_c"] + Vector3(0, 0, -4))
	var open_lit := Lighting.is_lit(spot, p)
	await _fresh_player(Vector3(3, 4.6, 106))
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

	# 39. Umbra floats over the dark chasm, mirrored, to the moon plate
	await _fresh_player(m["hall_b"])
	var u := _summon_facing_north()
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
	p.ai_move = Vector2(0, 1)
	await frames(12)
	p.ai_move = Vector2.ZERO
	var dz: float = u.global_position.z - (m["hall_b"] as Vector3).z
	check("walking +Z moves Umbra +Z too", dz > 0.8, "Umbra moved %.1f m" % dz)

	# 40. Light makes Umbra fall: over the chasm, putting the candle on drops it and it fades
	await _fresh_player(m["hall_b"])
	u = _summon_facing_north()
	p.ai_move = Vector2(1, 0)
	await frames(12)
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

	# 42. Across the lit chasm Umbra only floats inside your shadow
	var gate_c: Gate = m["hall_c_gate"]
	await _fresh_player(m["hall_c"] + Vector3(0, 0, -3.0)) # well off the lantern's line
	u = _summon_facing_north()
	p.ai_move = Vector2(1, 0)
	for i in 90:
		await physics_frame
	p.ai_move = Vector2.ZERO
	var fell := p.umbra == null
	await _fresh_player(m["hall_c"]) # on the line: your body shades it all the way
	u = _summon_facing_north()
	p.ai_move = Vector2(1, 0)
	for i in 150:
		await physics_frame
		if p.umbra == null:
			break
	p.ai_move = Vector2.ZERO
	check("off the lantern's line Umbra falls", fell, "fell %s" % fell)
	check("in your shadow Umbra crosses the lit chasm and opens the gate", p.umbra != null and gate_c.opened,
		"Umbra out %s, gate open %s" % [p.umbra != null, gate_c.opened])

	# 43b. Umbra appears 1.5 m beside you on the mirror line, or short of a wall
	await _fresh_player(arena)
	var ub := _summon_facing_north()
	var off := ub.global_position - p.global_position
	check("Umbra appears 1.5 m beside you", absf(absf(off.x) - 1.5) < 0.05 and absf(off.z) < 0.05, "offset %s" % [off])
	p.toggle_umbra()
	var wallb: StaticBody3D = level.box(p.global_position + Vector3(off.x * 0.6, 0.5, 0), Vector3(0.3, 3, 3), Basis(), Color.GRAY)
	await frames(3)
	p.toggle_umbra()
	await frames(2)
	var ub2 := p.umbra
	var through := signf(ub2.global_position.x - wallb.global_position.x) == signf(off.x)
	check("Umbra doesn't appear through a wall", not through, "appeared at x %.2f, wall at x %.2f" % [ub2.global_position.x, wallb.global_position.x])
	p.toggle_umbra()
	wallb.queue_free()


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

	# 49. Iron is 4.5 m tall: a running double jump hits its side, a running triple jump clears it
	var face := 63.0 # the cube's near face; the run goes north (-Z) from z 100
	var cube := IronCube.make(level, Vector3(90, 0, face - 1.0))
	await frames(3)
	var ends := []
	for chain in [2, 3]:
		await _fresh_player(Vector3(90, 0.6, 100))
		p.velocity = Vector3(0, 0, -t.top_speed)
		p.ai_move = Vector2(0, -1)
		# first hop so the last jump takes off about 6 m short of the face (a single covers ~9.6 m, a double ~12 m)
		var first := face + (27.8 if chain == 3 else 15.6)
		var hops := 0
		for i in 300:
			await physics_frame
			if p.is_on_floor() and not p.ai_jump and hops < chain:
				if hops == 0 and p.global_position.z < first or hops > 0:
					p.ai_jump = true
					hops += 1
			elif not p.is_on_floor() and p.ai_jump and p.velocity.y < 0.0:
				p.ai_jump = false
			if hops >= chain and p.is_on_floor() and p.global_position.z < face - 3.5:
				break
		p.ai_jump = false
		p.ai_move = Vector2.ZERO
		ends.append(p.global_position.z)
	check("a running double jump can't get over 4.5 m iron", ends[0] > face, "stopped at z %.1f, face at %.1f" % [ends[0], face])
	check("a running triple jump clears 4.5 m iron", ends[1] < face - 3.5, "landed at z %.1f, far side at %.1f" % [ends[1], face - 2.0])
	cube.queue_free()


func _scale_tests(arena: Vector3) -> void:
	var t: Tuning = level.t
	var m: Dictionary = level.marks

	# 50. Pads: stepping on the shrink pad makes you small, the grow pad makes you normal again.
	# Small: a third the size, slower, lower jumps
	await _fresh_player(Vector3(-58, 0.6, 42))
	p.ai_move = Vector2(-1, 0)
	await frames(25)
	p.ai_move = Vector2.ZERO
	var shrank := p.small
	p.ai_move = Vector2(1, 0)
	await frames(50)
	p.ai_move = Vector2.ZERO
	check("the shrink pad makes you small and the grow pad normal", shrank and not p.small, "small after shrink pad %s, after grow pad %s" % [shrank, p.small])
	await _fresh_player(arena)
	p.set_small(true)
	await frames(3)
	var r := p.radius()
	p.ai_move = Vector2(0, -1)
	await frames(90)
	var run := p.flat_speed()
	p.ai_move = Vector2.ZERO
	await frames(40)
	var hop := await _apex_of_next_jump()
	var want_hop := pow(t.jump_speed * t.small_jump_mult, 2) / (2.0 * t.gravity)
	check("shrink: small runs at %.1f m/s and jumps %.1f m" % [t.top_speed * t.small_speed_mult, want_hop],
		p.small and absf(r - 0.5 * t.small_scale) < 0.01 and absf(run - t.top_speed * t.small_speed_mult) < 0.2 and absf(hop - want_hop) < 0.15,
		"radius %.2f, speed %.1f, jump %.2f m" % [r, run, hop])

	# 51. Grates stop you at normal size; small you slip through
	var ends := []
	for shrunk in [false, true]:
		# small: walk over the shrink pad at the ramp's foot; normal: start past it
		await _fresh_player(m["garden_grate_ramp"] if shrunk else Vector3(-65, 0.6, 65.5))
		p.ai_move = Vector2(0, -1)
		await frames(200)
		p.ai_move = Vector2.ZERO
		ends.append(p.global_position.z)
	check("a grate stops you at normal size", ends[0] > 56.7, "stopped at z %.1f" % ends[0])
	check("small, you slip through the grate", ends[1] < 55.0, "got to z %.1f" % ends[1])

	# 52. No room to grow inside a grate
	await _fresh_player(m["garden_grate_door"])
	p.set_small(true)
	await frames(2)
	var grew := p.set_small(false)
	check("you can't grow inside a grate", not grew and p.small, "grew %s" % grew)

	# 53. Small crosses the cracked floor without breaking it; the island's grow pad makes you normal,
	# and a locked-on roll bursts the cracked wall (a small one doesn't)
	var wall: CrackedWall = m["garden_cracked_wall"]
	await _fresh_player(m["garden_grate_in"])
	p.set_small(true)
	p.ai_move = Vector2(0, -1)
	await frames(90)
	p.ai_move = Vector2.ZERO
	var grown_on_pad := not p.small
	var broken := 0
	for c in level.get_children():
		if c is CrackedFloor and (c as CrackedFloor).broken:
			broken += 1
	var crossed := p.global_position.z < 50.0 and p.global_position.y > 2.0
	p.set_small(true)
	p.ai_target = true
	await frames(3)
	await _tap(Vector3.FORWARD) # a small roll into the wall
	await frames(30)
	var small_bounced := is_instance_valid(wall) and not wall.smashed
	var grew2 := p.set_small(false)
	await frames(10)
	await _tap(Vector3.FORWARD)
	await frames(20)
	p.ai_target = false
	check("small, you cross the cracked floor without breaking it", crossed and broken == 0, "crossed %s, %d tiles broken" % [crossed, broken])
	check("the island's grow pad makes you normal", grown_on_pad, "normal %s" % grown_on_pad)
	check("a normal-size roll bursts the cracked wall; a small one doesn't", small_bounced and grew2 and not is_instance_valid(wall),
		"small bounced %s, grew %s, wall gone %s" % [small_bounced, grew2, not is_instance_valid(wall)])

	# 53b. A bomb blows up a cracked wall too
	await _fresh_player(arena)
	var wall2 := CrackedWall.make(level, arena + Vector3(0, -0.6, -2.0), Vector3(2, 2.5, 0.5))
	var bp := await _pull_bomb()
	bp.queue_free()
	p.ai_context = true # standing still: set it down at your feet
	await frames(3)
	p.ai_move = Vector2(0, 1) # walk clear
	await frames(40)
	p.ai_move = Vector2.ZERO
	await frames(int(Bomb.FUSE * 60.0))
	check("a bomb blows up a cracked wall", not is_instance_valid(wall2), "wall still there %s" % is_instance_valid(wall2))

	# 54. At normal size your weight breaks a cracked floor and you drop through
	await _fresh_player(m["garden_grate_mid"])
	await frames(60)
	check("normal size, the cracked floor crumbles under you", p.global_position.y < 1.5, "y %.1f" % p.global_position.y)

	# 55. The pond: normal you sink and are put back on the bank; small you float across
	var bank: Vector3 = m["garden_pond_bank"]
	await _fresh_player(bank)
	p.ai_move = Vector2(0, -1)
	var furthest := bank.z
	var sank := false
	for i in 120:
		await physics_frame
		furthest = minf(furthest, p.global_position.z)
		sank = sank or p.global_position.x < -94.0 # put back on the bank, off to the side
	p.ai_move = Vector2.ZERO
	check("normal size you sink in the pond and are put back on the bank", sank and furthest > 64.0, "furthest z %.1f, put back %s" % [furthest, sank])
	await _fresh_player(m["garden_pond_shrink"]) # walk over the bank's shrink pad into the water
	p.ai_move = Vector2(0, -1)
	var low := 99.0
	for i in 420:
		await physics_frame
		if p.global_position.z < 67.0 and p.global_position.z > 53.0:
			low = minf(low, p.global_position.y)
		if p.global_position.z < 52.8 and p.global_position.y < 0.1:
			p.ai_jump = not p.ai_jump # climb out onto the island
		if p.global_position.z < 51.0 and p.is_on_floor():
			break
	p.ai_jump = false
	p.ai_move = Vector2.ZERO
	check("small, you float across the 16 m pond", p.global_position.z < 51.0 and p.global_position.y > -0.1 and low > -0.2,
		"ended z %.1f y %.2f, lowest %.2f" % [p.global_position.z, p.global_position.y, low])

	# 56. The vent: small is too light to break its cover; normal breaks it; small again, the updraft lifts you onto the 8 m tower
	var cover: CrackedFloor = m["garden_vent_cover"]
	var tower: float = m["garden_tower_y"]
	await _fresh_player(m["garden_island"])
	p.set_small(true)
	p.global_position = (m["garden_vent"] as Vector3) + Vector3.DOWN * 0.3 # step onto the cover already small
	await frames(60)
	var held := not cover.broken and p.global_position.y < 1.0
	var held_detail := "cover broken %s, y %.1f" % [cover.broken, p.global_position.y]
	p.set_small(false)
	await frames(45)
	var dropped := cover.broken and p.small # fell through onto the vent's shrink pad
	var dropped_y := p.global_position.y
	var top := 0.0
	var on_tower := false
	for i in 300:
		await physics_frame
		top = maxf(top, p.global_position.y)
		if p.global_position.y > tower + 1.0:
			p.ai_move = Vector2(-1, 0)
		if p.is_on_floor() and p.global_position.y > tower:
			on_tower = true
			break
	p.ai_move = Vector2.ZERO
	check("small, you don't break the vent's cover", held, held_detail)
	check("normal size, your weight breaks the cover; you drop onto the vent's shrink pad", dropped, "small %s, y %.1f" % [p.small, dropped_y])
	check("small in the updraft, you rise onto the %.0f m tower" % tower, on_tower, "peak %.1f, ended y %.1f" % [top, p.global_position.y])

	# 57. The ferry: small with the magnet you fly along the iron's line, but only within magnet_fly_range of it
	var iron: IronCube = m["garden_ferry_iron"]
	var edge: Vector3 = m["garden_ferry_edge"]
	await _fresh_player(edge)
	p.inventory.add("magnet")
	p.magnet_push = true
	p.set_small(true)
	var flew := false
	for i in 150:
		await physics_frame
		flew = flew or p.magnet_flying
	var fell_short := p.global_position.z > 99.0 # dropped into the chasm and was put back on the near side
	check("with the iron 9 m back, pushing off it falls short of the 16 m chasm", flew and fell_short and iron.global_position.z > 108.9,
		"flew %s, fell short %s, iron at z %.1f" % [flew, fell_short, iron.global_position.z])
	await _fresh_player(edge)
	p.inventory.add("magnet")
	await frames(90) # normal size, pull: the iron slides up to you
	var iron_z := iron.global_position.z
	var pad: Vector3 = m["garden_ferry_shrink"]
	p.ai_move = Vector2(1, (pad.z - p.global_position.z) / (pad.x - p.global_position.x)).normalized() # step aside onto the shrink pad
	for i in 90:
		await physics_frame
		if p.small:
			break
	p.ai_move = Vector2(-1, 0) # and back into the iron's line: pull draws you to it and you cling
	for i in 120:
		await physics_frame
		if p.magnet_flying:
			p.ai_move = Vector2.ZERO
	await frames(30)
	var clung := p.magnet_flying and absf(p.global_position.z - (iron_z - 1.0 - p.radius())) < 0.2
	var clung_z := p.global_position.z
	p.magnet_push = true
	var landed := false
	for i in 240:
		await physics_frame
		if p.global_position.z < 84.0 and p.is_on_floor():
			landed = p.global_position.y > -0.5
			break
	check("normal size, you pull the iron to the edge", absf(iron_z - 103.0) < 0.05, "iron at z %.1f" % iron_z)
	check("small, pull draws you to the iron and you cling to its side", clung, "at z %.1f" % clung_z)
	check("small, push flies you across the 16 m chasm", landed and absf(iron.global_position.z - iron_z) < 0.05,
		"ended z %.1f y %.1f, iron at z %.1f" % [p.global_position.z, p.global_position.y, iron.global_position.z])
	await _fresh_player(m["garden_ferry_far"])
	p.inventory.add("magnet")
	p.set_small(true)
	for i in 180:
		await physics_frame
	check("small, pull flies you back across to the iron", p.global_position.z > 100.5 and p.global_position.z < 102.0 and p.global_position.y > -0.5,
		"ended z %.1f y %.1f" % [p.global_position.z, p.global_position.y])

	# 58. Overspeed bleeds back to top speed on the flat, but running downhill still builds speed
	await _fresh_player(arena)
	p.velocity = Vector3(24.0, 0, 0) # east: open floor for 50 m
	p.ai_move = Vector2(1, 0)
	await frames(60)
	var after1 := p.flat_speed()
	await frames(120)
	var after3 := p.flat_speed()
	p.ai_move = Vector2.ZERO
	check("on the flat, overspeed decays at %.0f m/s² to top speed" % t.overspeed_decay,
		absf(after1 - (24.0 - t.overspeed_decay)) < 0.6 and absf(after3 - t.top_speed) < 0.2, "24 -> %.1f after 1 s, %.1f after 3 s" % [after1, after3])
	await _fresh_player(Vector3(32, 6.4, -15.0)) # near the top of the 30° ramp, facing down it
	p.ai_move = Vector2(0, 1)
	var fastest := 0.0
	for i in 90:
		await physics_frame
		fastest = maxf(fastest, p.velocity.length())
	p.ai_move = Vector2.ZERO
	check("running down the 30° ramp builds speed past top speed", fastest > t.top_speed + 4.0, "fastest %.1f m/s" % fastest)

## The level rule checker: the real wings pass, and a room built to break every rule is caught.
func _rules_tests() -> void:
	var space: PhysicsDirectSpaceState3D = level.get_world_3d().direct_space_state
	var launchers := LevelRules.launchers(level)
	for area in LevelRules.AREAS:
		var found := LevelRules.check(space, LevelRules.AREAS[area], launchers)
		var texts: Array[String] = []
		for f in found:
			texts.append(f["text"])
		check("%s follows the level feel rules" % area, found.is_empty(), "none" if texts.is_empty() else ", ".join(texts))
	# a floating test strip at y 50 south of the map, running +X. Floors are 8 m deep in z.
	var y := 50.0
	var c := Color(0.8, 0.3, 0.3)
	var slab := func(x0: float, x1: float, top: float) -> void:
		level.box(Vector3((x0 + x1) / 2.0, top - 0.5, 170.0), Vector3(x1 - x0, 1.0, 8.0), Basis(), c)
	slab.call(0.0, 8.0, y)
	slab.call(12.0, 20.0, y) # 4 m gap: too short
	slab.call(20.0, 28.0, y + 1.0) # 1 m ledge: too low
	slab.call(28.0, 36.0, y + 3.0) # 2 m ledge: fine
	slab.call(43.0, 49.0, y + 3.0) # 7 m gap: fine
	slab.call(60.0, 68.0, y + 3.0) # 11 m gap after a 6 m runway: needs a longer run-up
	await frames(2) # the new boxes reach the physics space next frame
	var found := LevelRules.check(space, AABB(Vector3(-2, y - 10, 164), Vector3(72, 20, 12)))
	var kinds := {}
	for f in found:
		kinds[f["text"]] = true
	var want := ["short gap 4.0 m at (10, 170)", "low ledge 1.0 m at (20, 170)", "long gap 11.0 m at (55, 170)"]
	var got := kinds.keys()
	got.sort()
	var caught := true
	for w in want:
		caught = caught and kinds.has(w)
	check("rule checker catches a 4 m gap, a 1 m ledge and an 11 m gap with a 6 m runway, and nothing else",
		caught and found.size() == want.size(), ", ".join(got))

## Playtest tools: feedback pins restore your spot and kit, and every warp lands on a real place.
func _tool_tests(arena: Vector3) -> void:
	var m: Dictionary = level.marks
	var dev = level.dev
	# 59. A pin taken small, with the magnet on push and two hearts, brings all of that back from a link
	await _fresh_player(arena + Vector3(3, 0, 5))
	p.inventory.add("magnet")
	p.inventory.add("potion", 2)
	p.magnet_push = true
	p.set_small(true)
	p.hp = 4
	p.facing = Vector3.RIGHT
	await frames(5)
	var at := p.global_position
	var link: String = dev.pin_link("jump here is too short")
	await _fresh_player(arena)
	dev._go_to_pin("look: " + link + " thanks")
	await frames(2)
	var back := Pin.decode(link)
	check("a feedback pin link restores position, size, magnet, hearts, items and note",
		p.global_position.distance_to(at) < 0.3 and p.small and p.magnet_push and p.hp == 4 and p.inventory.count("potion") == 2
		and p.inventory.has("magnet") and p.facing.dot(Vector3.RIGHT) > 0.95 and back.get("note", "") == "jump here is too short",
		"%.2f m off, small %s, push %s, hp %d, potions %d" % [p.global_position.distance_to(at), p.small, p.magnet_push, p.hp, p.inventory.count("potion")])
	check("junk text is not a pin", Pin.decode("hello there").is_empty() and Pin.decode("").is_empty(), "")
	await _fresh_player(arena)
	# 60. Every warp in the G menu lands you on a floor
	var bad: Array[String] = []
	for w in dev.WARPS:
		var key: String = w[1]
		if not (key in ["start", "arena"]) and not (m.get(key) is Vector3):
			bad.append(key + " (no mark)")
			continue
		dev.warp(key)
		await frames(20)
		if not p.is_on_floor():
			bad.append(key)
	check("every warp lands on a floor", bad.is_empty(), "%d warps" % dev.WARPS.size() if bad.is_empty() else ", ".join(bad))
	await _fresh_player(arena)

func _use(id: String) -> void:
	p.ai_item = p.inventory.slots.find(id)
	await frames(2)

## Grow a bomb plant beside you and pull its bomb with the context button. Returns the plant.
func _pull_bomb() -> BombFlower:
	var fl := BombFlower.make(level, p.global_position + Vector3(1.2, -p.radius(), 0), level.t)
	await physics_frame
	p.ai_context = true
	await frames(3)
	return fl

## Rootworks: seeds, trunks and roots from Propagule; the lash; the spider, its cable and gears from Winch.
func _rootworks_tests(arena: Vector3) -> void:
	var m: Dictionary = level.marks
	var t: Tuning = level.t
	# 61. Plant the seed on the soil and its root bridges the 14 m chasm
	await _fresh_player(Vector3(63, 6.6, 69.8))
	p.ai_context = true # next to the seed: pick it up
	await frames(3)
	var picked := p.held_seed != null
	await place(m["root_soil"]) # carry it to the soil at the chasm's edge
	p.facing = Vector3.BACK
	await frames(2)
	p.ai_context = true # set down on soil: it plants
	await frames(3)
	var planted_seed: Seed = null
	for n in get_nodes_in_group("seeds"):
		if (n as Seed).planted:
			planted_seed = n
	var span := 0.0
	if planted_seed != null:
		for r in planted_seed.roots:
			var sz := ((r.get_child(0) as CollisionShape3D).shape as BoxShape3D).size
			if sz.z > sz.x and r.global_position.z > planted_seed.global_position.z:
				span = r.global_position.z + sz.z / 2.0
	check("a seed picked up and planted on soil roots right across the 14 m chasm",
		picked and planted_seed != null and span > 90.3, "root reaches z %.1f, far side at 90" % span)
	await frames(2)
	await place(Vector3(68, 6.6, 76.4)) # just past the cube, on the root
	p.ai_move = Vector2(0, 1)
	await frames(150)
	p.ai_move = Vector2.ZERO
	check("you can walk the root across", p.global_position.z > 91.0 and p.global_position.y > 5.5,
		"ended z %.1f y %.1f" % [p.global_position.z, p.global_position.y])
	var tr := planted_seed.trunk_top() - (planted_seed.global_position.y - Seed.HALF) if planted_seed != null else 0.0
	check("the trunk grows %.0f m" % t.trunk_height, absf(tr - t.trunk_height) < 0.5, "%.1f m" % tr)

	# 62. Locked on, the lash fetches the seed off the 4.5 m ledge
	await _fresh_player(m["root_c_stand"])
	p.inventory.add("lash")
	p.facing = Vector3.BACK
	p.ai_target = true
	await frames(5)
	await _use("lash")
	p.ai_target = false
	check("locked on, the lash fetches a seed off a 4.5 m ledge %.1f m away" % Vector3(64, 11.5, 106).distance_to(m["root_c_stand"]),
		p.held_seed != null, "holding %s" % (p.held_seed != null))

	# 63. Plant it in the mud at the ledge's foot, then up the cube (2 m) and onto the 4.5 m ledge
	await place(Vector3(64, 6.6, 100.3))
	p.facing = Vector3.BACK
	await frames(2)
	p.ai_context = true
	await frames(3)
	var in_mud := p.held_seed == null
	p.ai_move = Vector2(0, 1)
	var top_y := 0.0
	for i in 400:
		await physics_frame
		top_y = maxf(top_y, p.global_position.y)
		if p.is_on_floor() and not p.ai_jump:
			p.ai_jump = true
		elif p.ai_jump and p.velocity.y < 0.0:
			p.ai_jump = false
		if p.global_position.z > 105.5 and p.is_on_floor() and p.global_position.y > 10.0:
			break # on the ledge: stop pushing before you run off its far side
	p.ai_move = Vector2.ZERO
	p.ai_jump = false
	await frames(30)
	check("planted in mud, the cube and a ledge grab get you onto the 4.5 m ledge",
		in_mud and p.global_position.z > 104.3 and p.global_position.y > m["root_c_top"], "peak y %.1f, ended z %.1f y %.1f" % [top_y, p.global_position.z, p.global_position.y])

	# 64. Dropped 3 m or more onto mud a seed spears in and plants itself; 2 m isn't enough
	var high := Seed.make(level, Vector3(61, 6.0 + Seed.HALF + t.spear_drop + 0.1, 99), t)
	var low := Seed.make(level, Vector3(61, 6.0 + Seed.HALF + 2.0, 101.8), t)
	await frames(90)
	check("a seed dropped %.0f m onto mud plants itself, one dropped 2 m doesn't" % t.spear_drop, high.planted and not low.planted,
		"high %s, low %s" % [high.planted, low.planted])
	high.queue_free()
	low.queue_free()

	# 65. The lash pulls you to the post across the second 14 m chasm
	await _fresh_player(Vector3(60.5, 6.6, 94))
	p.inventory.add("lash")
	p.facing = Vector3.FORWARD
	p.ai_target = true
	await frames(5)
	var locked: bool = p.target == m["root_post"]
	await _use("lash")
	p.ai_target = false
	await frames(120)
	check("locked on, the lash pulls you %.0f m across the 14 m chasm to the post" % (60.5 - 45.0),
		locked and p.global_position.x < m["root_b2_x"] and p.global_position.y > 5.5, "ended x %.1f y %.1f" % [p.global_position.x, p.global_position.y])

	# 66. Lash the spider and steer it round the caged gear: the rope wraps the gear and every metre that slides
	# past it lifts the gate; unhooked, the gear keeps its angle
	await _fresh_player(m["root_gear_stand"])
	p.inventory.add("spider")
	p.inventory.add("lash")
	p.facing = Vector3.RIGHT
	await frames(2)
	await _use("spider") # out it goes, and you steer it
	var sp: Spider = p.spider
	var steering := p.pilot == sp
	await _use("spider") # back to you
	var back_to_you := p.pilot == null and is_instance_valid(sp)
	p.ai_target = true
	await frames(5)
	await _use("lash")
	p.ai_target = false
	var hooked := p.leash != null
	await _use("spider") # steer it again: round the cage, south side first, so the rope loops the gear
	var gear: Gear = m["root_gear"]
	var gate: Gate = m["root_gate"]
	var start_p := p.global_position
	var bends := 0
	for leg in [[Vector2(0, 1), 50], [Vector2(1, 0), 90], [Vector2(0, -1), 90], [Vector2(-1, 0), 160]]:
		p.ai_move = leg[0]
		for i in leg[1]:
			await physics_frame
			if p.leash != null:
				bends = maxi(bends, p.leash.points.size() - 2)
	p.ai_move = Vector2.ZERO
	var rise := gate.global_position.y - 2.0
	var dragged := p.global_position.distance_to(start_p)
	check("the spider item swaps who you steer, you or the spider", steering and back_to_you, "steering it %s, back to you %s" % [steering, back_to_you])
	check("the rope bends round the caged gear and slides past it: the gate rises %.1f m per metre" % t.gear_ratio, hooked and bends > 0 and rise > 1.3,
		"bends %d, gate up %.1f m after %.1f m of rope (%.1f signed), you were dragged %.1f m" % [bends, rise, gear.wound, gear.spun, dragged])
	check("steering the spider at full length drags you", dragged > 2.0 and p.leash != null and p.leash.length() < t.leash_length + 0.3,
		"dragged %.1f m, rope %.1f m" % [dragged, p.leash.length() if p.leash != null else 0.0])
	await _use("spider") # back to you
	await _use("lash") # unhook
	await frames(5)
	var kept := gate.global_position.y - 2.0
	await place(Vector3(42, 0.6, 74))
	p.ai_move = Vector2(0, 1)
	await frames(90)
	p.ai_move = Vector2.ZERO
	check("unhooked, the gear keeps its angle and you walk under the gate", absf(kept - rise) < 0.01 and p.global_position.z > 77.5,
		"gate up %.1f m, you at z %.1f" % [kept, p.global_position.z])
	p.stow_spider()

	# 67. Lash the parked spider and walk away: at full length you drag it after you
	await _fresh_player(arena)
	p.inventory.add("spider")
	p.inventory.add("lash")
	p.facing = Vector3.RIGHT
	await _use("spider")
	await _use("spider") # back to you: it waits
	var spider_at: Vector3 = p.spider.global_position
	p.ai_target = true
	await frames(5)
	await _use("lash")
	p.ai_target = false
	hooked = p.leash != null
	p.ai_move = Vector2(-1, 0)
	await frames(180)
	p.ai_move = Vector2.ZERO
	var towed: float = p.spider.global_position.distance_to(spider_at)
	var rope := p.leash.length() if p.leash != null else 0.0
	check("the lash hooks the spider on a %.0f m taut rope; walking off you drag it" % t.leash_length, hooked and towed > 5.0 and rope < t.leash_length + 0.3,
		"spider dragged %.1f m, rope %.1f m" % [towed, rope])
	p.stow_spider()

	# 67b. The rope bends round a wall's corner and straightens when the way clears
	await _fresh_player(arena)
	var pillar: StaticBody3D = level.box(arena + Vector3(0, 0.9, -4), Vector3(2, 3, 2), Basis(), Color.GRAY)
	p.inventory.add("spider")
	p.inventory.add("lash")
	p.facing = Vector3.RIGHT
	await _use("spider")
	await _use("spider")
	p.ai_target = true
	await frames(5)
	await _use("lash")
	p.ai_target = false
	await _use("spider") # steer it east, north past the pillar, then west to right behind it
	p.ai_move = Vector2(1, 0)
	await frames(20)
	p.ai_move = Vector2(0, -1)
	await frames(80)
	p.ai_move = Vector2(-1, 0)
	await frames(35)
	var bent := p.leash.points.size() - 2 if p.leash != null else 0
	p.ai_move = Vector2(1, 0) # back out east, where the way to you is clear
	await frames(50)
	p.ai_move = Vector2.ZERO
	await frames(5)
	var straight := p.leash.points.size() - 2 if p.leash != null else -1
	check("the taut rope bends round a corner and lets go when the way is clear", bent >= 1 and straight == 0, "bends behind the pillar %d, after %d" % [bent, straight])
	await _use("spider")
	p.stow_spider()
	pillar.queue_free()

	# 67c. Unhooked, the spider breaks more than %.0f m from you and goes back in your pack
	await _fresh_player(arena)
	p.inventory.add("spider")
	p.facing = Vector3.RIGHT
	await _use("spider")
	p.ai_move = Vector2(1, 0)
	var farthest := 0.0
	for i in 400:
		await physics_frame
		if p.spider == null:
			break
		farthest = maxf(farthest, p.spider.global_position.distance_to(p.global_position))
	p.ai_move = Vector2.ZERO
	check("an unhooked spider breaks past %.0f m and goes back in your pack" % t.spider_break, p.spider == null and p.pilot == null and p.inventory.has("spider") and farthest < t.spider_break + 0.5,
		"spider out %s, got %.1f m away" % [p.spider != null, farthest])

	# 67d. The spider is as big as you: bars stop it, you can stand on it, and the context button picks it up
	await _fresh_player(Vector3(44, 0.6, 66)) # west of the cage
	p.inventory.add("spider")
	p.facing = Vector3.RIGHT
	await _use("spider")
	p.ai_move = Vector2(1, 0)
	await frames(90)
	p.ai_move = Vector2.ZERO
	var sx := p.spider.global_position.x
	await _use("spider")
	await place(p.spider.global_position + Vector3(0, 1.6, 0))
	await frames(20)
	var on_top := p.global_position.y > p.spider.global_position.y + 0.8
	await place(p.spider.global_position + Vector3(-1.3, 0, 0))
	p.ai_context = true
	await frames(3)
	check("bars stop the spider, you can stand on it, and the context button picks it up", sx < 47.5 and on_top and p.spider == null,
		"spider stopped at x %.1f (bars at 47.5), stood on it %s, picked up %s" % [sx, on_top, p.spider == null])

	# 67e. A seed cube is a 2 m block you can jump onto
	await _fresh_player(arena)
	var cube := Seed.make(level, arena + Vector3(0, Seed.HALF - 0.55, -2.4), t)
	await frames(20)
	p.ai_jump = true
	await frames(12)
	p.ai_move = Vector2(0, -1)
	await frames(30)
	p.ai_jump = false
	p.ai_move = Vector2.ZERO
	await frames(30)
	check("a seed cube is %.0f m tall and you can jump onto it" % Seed.SIZE, p.global_position.y > Seed.SIZE + 0.3, "you at y %.1f" % p.global_position.y)
	cube.queue_free()
	await _fresh_player(arena)


## The moves yard: climbing, ledge grabs, grind rails, homing pogo, perfect dodges and hit feel.
func _moves_yard_tests(arena: Vector3) -> void:
	var m: Dictionary = level.marks
	var t: Tuning = level.t

	# 68. Push into the vines and you climb the whole 8 m face, then pull yourself over the top
	await _fresh_player(m["moves_climb"])
	p.ai_move = Vector2(0, -1)
	var climbed := false
	for i in 300:
		await physics_frame
		climbed = climbed or p.climbing != null
		if p.is_on_floor() and p.global_position.y > 7.0:
			break
	p.ai_move = Vector2.ZERO
	var top: float = m["moves_climb_top"]
	check("vines climb all %.0f m at %.0f m/s and you pull over the top" % [top, t.climb_speed],
		climbed and p.global_position.y > top + 0.3 and p.global_position.z < -68.5, "climbed %s, ended y %.1f z %.1f" % [climbed, p.global_position.y, p.global_position.z])

	# 69. A single jump (2.4 m) against the 3.5 m block catches the ledge; pushing on pulls you up
	await _fresh_player(m["moves_ledge"])
	p.ai_move = Vector2(0, -1)
	var hung := false
	var jumped := false
	for i in 240:
		await physics_frame
		if not jumped and p.global_position.z < -73.8:
			p.ai_jump = true
			jumped = true
		elif jumped and p.velocity.y < 0.0:
			p.ai_jump = false
		hung = hung or p.hang != Vector3.ZERO
		if p.is_on_floor() and p.global_position.y > 3.0:
			break
	p.ai_jump = false
	p.ai_move = Vector2.ZERO
	var ledge: float = m["moves_ledge_top"]
	check("a single jump catches a %.1f m ledge (reach %.1f m) and pulls up" % [ledge, t.ledge_reach],
		hung and p.global_position.y > ledge + 0.3, "hung %s, ended y %.1f" % [hung, p.global_position.y])
	# iron stays smooth: see test 49, a double jump still can't get over it

	# 70. Walk onto the rail: grinding 4 m downhill builds speed and the kicker throws you across a 10 m gap
	await _fresh_player(m["moves_rail"])
	p.ai_move = Vector2(0, -1)
	var fastest := 0.0
	var ground := false
	for i in 300:
		await physics_frame
		if p.rail != null:
			ground = true
			fastest = maxf(fastest, p.rail_speed)
		if ground and p.rail == null and p.is_on_floor():
			break
	p.ai_move = Vector2.ZERO
	var land: float = m["moves_rail_land"]
	var want := sqrt(t.rail_min_speed * t.rail_min_speed + 2.0 * t.gravity * 4.0)
	check("a 4 m downhill rail builds you to %.0f m/s" % want, ground and absf(fastest - want) < 1.5, "grinding at %.1f m/s" % fastest)
	check("the rail's kicker throws you across the 10 m gap", p.global_position.z < land - 0.3 and p.global_position.y > 2.3,
		"landed z %.1f y %.1f, platform from z %.0f at 2 m" % [p.global_position.z, p.global_position.y, land])

	# 71. Spikes hurt to touch
	await _fresh_player(Vector3(0, 0.6, -74))
	p.ai_jump = true
	await frames(30)
	p.ai_jump = false
	await frames(30)
	check("jumping into spikes hurts", p.hp < p.max_hp, "hp %d of %d" % [p.hp, p.max_hp])

	# 72. Homing attack: a locked-on air attack near spikes homes in and pogos you up unharmed; two climb the
	# 8 m ledge. The lock-on stays on the first spike ball, and the second air attack still chains to the next.
	await _fresh_player(m["moves_pogo"])
	p.inventory.add("spear")
	p.ai_move = Vector2(0, -0.4)
	p.ai_jump = true
	p.ai_target = true
	var bounces := 0
	var was_homing := false
	for i in 360:
		await physics_frame
		if p.homing != null:
			was_homing = true
		elif was_homing:
			was_homing = false
			bounces += 1
		p.ai_attack = not p.is_on_floor() and p.velocity.y < 1.0 and p.homing == null and bounces < 2
		if bounces >= 2:
			p.ai_move = Vector2(0, -1)
			p.ai_jump = false
			p.ai_target = false
		if bounces >= 2 and p.is_on_floor():
			break
	p.ai_attack = false
	p.ai_target = false
	p.ai_move = Vector2.ZERO
	check("homing pogo: two spikes (%.0f m/s bounce) reach the 8 m ledge unharmed" % t.pogo_speed,
		bounces == 2 and p.global_position.y > 8.3 and p.hp == p.max_hp, "bounces %d, ended y %.1f, hp %d" % [bounces, p.global_position.y, p.hp])

	# 73. Homing onto a blob hits it once for 2 and bounces you
	await _fresh_player(arena)
	p.inventory.add("spear")
	var mon := _monster_ahead(4.0)
	mon.stun = 20.0
	mon.hp = 10
	p.ai_jump = true
	await frames(10)
	p.ai_jump = false
	p.ai_target = true
	p.ai_attack = true
	var rose := false
	for i in 60:
		await physics_frame
		rose = rose or (mon.hp < 10 and p.velocity.y > t.pogo_speed * 0.8)
	p.ai_attack = false
	p.ai_target = false
	check("homing onto a blob 4 m away hits it once and bounces", mon.hp == 8 and rose, "blob hp %d, bounced %s" % [mon.hp, rose])
	mon.queue_free()

	# 74. Hit feel: a spear hit freezes the game briefly, then it runs again
	await _fresh_player(arena)
	p.inventory.add("spear")
	mon = _monster_ahead(1.6)
	mon.stun = 20.0
	mon.hp = 10
	p.ai_attack = true
	var froze := false
	for i in 20:
		await physics_frame
		froze = froze or Engine.time_scale < 0.5
	p.ai_attack = false
	await create_timer(0.3, true, false, true).timeout
	check("a spear hit stops the game for %.2f s, then it resumes" % t.hitstop, froze and Engine.time_scale == 1.0, "froze %s, time scale now %.2f" % [froze, Engine.time_scale])
	mon.queue_free()

	# 75. Perfect dodge: a hit that lands during a roll's i-frames slows the world instead
	await _fresh_player(arena)
	mon = _monster_ahead(6.0)
	mon.stun = 60.0
	p.ai_target = true
	await frames(10)
	var f := p._flat_facing()
	p.ai_move = Vector2(f.x, f.z)
	await frames(5)
	p.ai_move = Vector2.ZERO
	await frames(2)
	var rolling := p.dodging()
	p.hurt(1, mon.global_position)
	await frames(2)
	var slowed := Hitfx.world
	check("a hit during a roll is a perfect dodge: no damage, monsters at x%.1f for %.1f s" % [t.dodge_slow_speed, t.dodge_slow_time],
		rolling and p.hp == p.max_hp and absf(slowed - t.dodge_slow_speed) < 0.01, "rolling %s, hp %d, world speed %.2f" % [rolling, p.hp, slowed])
	p.ai_target = false
	Hitfx.slow_left = 0.0
	mon.queue_free()

	# 76. The spider turns a gear by walking past it, with no cable at all
	await _fresh_player(arena)
	var g := Gear.make(level, arena + Vector3(6, -0.6, 0), 1.0, null, Vector3.UP * 40.0, t)
	p.inventory.add("spider")
	await _use("spider")
	await _use("spider") # back to you: it waits, unhooked
	var sp: Spider = p.spider
	var had_cable := p.leash != null
	var walked := 0.0
	var at := arena + Vector3(4.4, 0.0, -3.0)
	sp.global_position = at
	await frames(3)
	for i in 60:
		var nxt := at + Vector3(0, 0, 0.1)
		sp.global_position = Vector3(nxt.x, sp.global_position.y, nxt.z)
		walked += 0.1
		at = nxt
		await physics_frame
	check("the spider walking past a gear turns it, no cable needed", not had_cable and g.wound > 1.5 and g.wound <= walked + 0.01,
		"cable %s, wound %.1f m over %.1f m walked" % [had_cable, g.wound, walked])
	p.stow_spider()
	g.queue_free()



## Put the player in mid-air at pos, still.
func _hover(pos: Vector3) -> void:
	p.global_position = pos
	p.velocity = Vector3.ZERO
	await physics_frame
	p.global_position = pos
	p.velocity = Vector3.ZERO

## Ground pound and the combos between moves.
func _combo_tests(arena: Vector3) -> void:
	var m: Dictionary = level.marks
	var t: Tuning = level.t

	# 78. Ground pound: attack in the air without lock-on drops you at pound_speed; jumping right after is a high jump
	await _fresh_player(arena)
	p.ai_jump = true
	await frames(20)
	p.ai_jump = false
	p.ai_attack = true
	var fastest := 0.0
	for i in 60:
		await physics_frame
		fastest = maxf(fastest, -p.velocity.y)
		if p.pound_land < 0.05:
			break
	var y0 := p.global_position.y
	p.ai_jump = true
	var top := y0
	for i in 60:
		await physics_frame
		top = maxf(top, p.global_position.y)
	p.ai_jump = false
	var want := pow(t.jump_speed * t.pound_jump_mult, 2) / (2.0 * t.gravity)
	check("ground pound drops at %.0f m/s" % t.pound_speed, absf(fastest - t.pound_speed) < 0.5, "%.1f m/s" % fastest)
	check("a jump right out of a pound goes %.1f m high (triple-jump height)" % want, absf(top - y0 - want) < 0.3, "%.2f m" % (top - y0))
	await frames(30)

	# 79. Pound onto a blob: it takes 2 and you bounce; the air attack then homes onto the next blob
	await _fresh_player(arena + Vector3(6, 0, 6))
	var b1 := Monster.spawn(level, arena + Vector3(0, 0.2, 0))
	var b2 := Monster.spawn(level, arena + Vector3(0, 0.2, -5))
	for b in [b1, b2]:
		b.stun = 60.0
		b.hp = 10
		b.drop_heart = false
	await _hover(arena + Vector3(0, 4, 0))
	p.ai_attack = true
	var bounced := false
	var up := 0.0
	for i in 60:
		await physics_frame
		up = maxf(up, p.velocity.y)
		bounced = bounced or (b1.hp < 10 and p.velocity.y > t.pogo_speed)
		if bounced:
			break
	p.inventory.add("spear")
	p.facing = Vector3.FORWARD
	await frames(8)
	p.ai_target = true # locked on, the air attack homes, and not only on the lock-on target
	p.ai_attack = true
	await frames(40)
	p.ai_target = false
	check("pound onto a blob hits it and bounces; the locked-on air attack chains onto the next", bounced and b1.hp == 8 and b2.hp == 8,
		"bounced %s (up %.1f m/s), first blob %d, second %d" % [bounced, up, b1.hp, b2.hp])
	b1.queue_free()
	b2.queue_free()

	# 80. Pound onto spikes bounces you off them unharmed
	await _fresh_player(Vector3(0, 0.6, -70))
	await _hover(Vector3(0, 7.0, -74))
	p.ai_attack = true
	bounced = false
	for i in 60:
		await physics_frame
		bounced = bounced or p.velocity.y > t.pogo_speed
	check("pound onto spikes bounces you unharmed", bounced and p.hp == p.max_hp, "bounced %s, hp %d" % [bounced, p.hp])

	# 81. Pound while holding a direction rolls you out on landing; jumping out of the roll is a long jump
	await _fresh_player(arena)
	p.ai_jump = true
	await frames(15)
	p.ai_jump = false
	p.ai_attack = true
	await frames(5)
	p.ai_move = Vector2(0, -1)
	var rolled := false
	for i in 60:
		await physics_frame
		if p.roll_t > 0.0 and p.roll_kind == "roll":
			rolled = true
			break
	await frames(3)
	var from := p.global_position
	p.ai_jump = true
	await frames(3)
	p.ai_jump = false
	var left := false
	for i in 120:
		await physics_frame
		left = left or not p.is_on_floor()
		if left and p.is_on_floor():
			break
	p.ai_move = Vector2.ZERO
	var dist := Vector2(p.global_position.x - from.x, p.global_position.z - from.z).length()
	var want_long := 2.0 * t.long_jump_up / t.gravity * t.long_jump_speed
	check("pound + direction rolls, and a jump out of the roll is a %.1f m long jump" % want_long, rolled and dist > want_long - 1.0,
		"rolled %s, jumped %.1f m" % [rolled, dist])

	# 82. Pound onto a slope: the fall becomes speed downhill
	await _fresh_player(arena)
	await _hover(Vector3(m["ramp30"].x, 7.0, -11.0))
	p.ai_attack = true
	var slide := 0.0
	for i in 60:
		await physics_frame
		if p.pound_t < 0.0 and p.is_on_floor():
			slide = maxf(slide, p.velocity.length())
	check("pound onto a 30° slope sends you downhill faster than you run (%.0f m/s)" % t.top_speed, slide > t.top_speed + 4.0, "%.1f m/s" % slide)
	await frames(60)

	# 83. Rolling downhill gains speed
	await _fresh_player(Vector3(m["ramp30"].x, 5.5, -15.0))
	await frames(10)
	p.facing = Vector3.BACK # facing downhill, so a forward tap rolls downhill
	p.ai_target = true
	await frames(3)
	await _tap(Vector3.BACK)
	var roll_top := 0.0
	for i in 30:
		await physics_frame
		if p.roll_t > 0.0:
			roll_top = maxf(roll_top, p.velocity.length())
	p.ai_target = false
	check("a roll down a 30° slope speeds up past roll speed %.0f" % t.roll_speed, roll_top > t.roll_speed + 1.5, "%.1f m/s" % roll_top)
	await frames(60)

	# 84. A wall kick counts as the first jump of the chain: land and jump for a double
	await _fresh_player(arena)
	var wall: StaticBody3D = level.box(arena + Vector3(0, 2.4, -1.4), Vector3(4, 6, 0.6), Basis(), Color.GRAY)
	p.ai_move = Vector2(0, -1)
	p.ai_jump = true
	await frames(12)
	p.ai_jump = false
	await frames(8)
	p.ai_jump = true # into the wall: kick off it
	await frames(3)
	p.ai_jump = false
	var kicked := p.velocity.z > 4.0
	p.ai_move = Vector2(0, 1)
	var chain := -1
	for i in 90:
		await physics_frame
		if p.is_on_floor() and p.land_time < 0.05 and not p.ai_jump:
			p.ai_jump = true
			await frames(2)
			chain = p.jump_chain
			break
	p.ai_jump = false
	p.ai_move = Vector2.ZERO
	check("a wall kick then a jump on landing is a double jump", kicked and chain == 1, "kicked %s, chain %d" % [kicked, chain])
	wall.queue_free()
	await frames(60)


## Walk into a challenge door. Returns once you're in the room.
func _enter_room(c: Challenge) -> void:
	await _fresh_player(c.door_at + Vector3(0, 0.6, 2.5))
	p.ai_move = Vector2(0, -1)
	for i in 60:
		await physics_frame
		if c.inside:
			break
	p.ai_move = Vector2.ZERO
	await frames(10)

## Challenge rooms: each door leads to a course, and its star brings you back with the door cleared.
func _challenge_tests(arena: Vector3) -> void:
	var m: Dictionary = level.marks
	var t: Tuning = level.t

	# 85. Rail run: two downhill rails, each kicking you over a 10 m gap
	var c: Challenge = m["challenge_rail"]
	await _enter_room(c)
	var entered := c.inside and p.global_position.distance_to(c.start) < 1.0
	p.ai_move = Vector2(0, -1)
	for i in 900:
		await physics_frame
		if c.cleared:
			break
	p.ai_move = Vector2.ZERO
	check("a door takes you in; the rail run's two rails and 10 m gaps reach the star", entered and c.cleared and not c.inside
		and p.global_position.distance_to(c.door_at) < 3.5, "entered %s, cleared %s, back by the door %s" % [entered, c.cleared, p.global_position.distance_to(c.door_at) < 3.5])

	# 86. Pogo chain: pound each of four spike balls to bounce across the 25 m drop
	c = m["challenge_pogo"]
	await _enter_room(c)
	p.ai_move = Vector2(0, -1)
	var bounces := 0
	var jumped := false
	var spikes := [c.start.z - 1.5 - 5.0, c.start.z - 1.5 - 10.0, c.start.z - 1.5 - 15.0, c.start.z - 1.5 - 20.0]
	for i in 900:
		await physics_frame
		if c.cleared:
			break
		var z := p.global_position.z
		if p.is_on_floor() and not jumped and z < c.start.z - 3.5:
			p.ai_jump = true
			jumped = true
		elif p.ai_jump and p.velocity.y < 0.0:
			p.ai_jump = false
		if p.pound_t < 0.0 and not p.is_on_floor() and bounces < 4 and absf(z - spikes[bounces]) < 0.6:
			p.ai_attack = true
			bounces += 1
	p.ai_jump = false
	p.ai_move = Vector2.ZERO
	check("pogo chain: four ground pounds on spikes carry you across to the star unharmed", c.cleared and p.hp == p.max_hp and bounces == 4,
		"cleared %s, pounds %d, hp %d" % [c.cleared, bounces, p.hp])

	# 87. Long jump: 10 m gaps between 4 m platforms. Pound onto each, roll out and long-jump
	c = m["challenge_long"]
	await _enter_room(c)
	p.ai_move = Vector2(0, -1)
	var longs := 0
	var o := c.start - Vector3(0, 4.6, -1)
	p.ai_jump = true
	await frames(8)
	p.ai_jump = false
	p.ai_attack = true # pound on the start platform
	for i in 900:
		await physics_frame
		if c.cleared:
			break
		var z := p.global_position.z
		var edge := o.z - floorf((o.z - z) / 14.0) * 14.0 - 4.0
		if p.roll_t > 0.0 and p.is_on_floor() and not p.ai_jump and z < edge + 0.7:
			p.ai_jump = true # jump out of the roll at the edge: long jump
			longs += 1
		elif p.ai_jump and not p.is_on_floor():
			p.ai_jump = false
		for k in range(1, 4):
			var mid := o.z - k * 14.0 - 2.0
			if p.pound_t < 0.0 and p.velocity.y < 0.0 and not p.is_on_floor() and absf(z - mid) < 0.8 and p.global_position.y > o.y + 4.5:
				p.ai_attack = true # over the next platform: pound down onto it
	p.ai_jump = false
	p.ai_move = Vector2.ZERO
	check("long jump room: pound, roll, long-jump over three %.0f m gaps to the star" % 10.0, c.cleared and longs >= 3, "cleared %s, long jumps %d" % [c.cleared, longs])
	await _fresh_player(arena)

## The test colossus: it walks until you're on it, you climb its fur, a pound cracks its back plate, bombs break
## its shins, and two struck weak points fell it.
func _colossus_tests() -> void:
	var m: Dictionary = level.marks
	var t: Tuning = level.t
	var col: Colossus = m["colossus"]

	# 88. It walks its circle, and stands still while you ride it
	await _fresh_player(m["colossus_arena"])
	var a0 := col.angle
	await frames(60)
	var walked := (col.angle - a0) * Colossus.PATROL
	await _hover(col.to_global(Vector3(0, 13.8, -3)))
	await frames(20)
	var a1 := col.angle
	await frames(60)
	var still := absf(col.angle - a1) * Colossus.PATROL
	check("the colossus walks (%.1f m/s) and stops while you're on its back" % t.colossus_speed, walked > t.colossus_speed * 0.8 and still < 0.05 and p.global_position.y > 13.0,
		"walked %.1f m in 1 s, then %.2f m with you on it (you at y %.1f)" % [walked, still, p.global_position.y])

	# 89. Climb the fur on a rear leg from the ground up onto its 13 m back
	await _fresh_player(m["colossus_arena"])
	await frames(5)
	await _hover(col.fur_foot(-1.0))
	await frames(10)
	var climbed := false
	for i in 600:
		var aim := col.to_global(Vector3(-3.65, 0, 5.5)) - p.global_position
		aim.y = 0.0
		aim = aim.normalized()
		p.ai_move = Vector2(aim.x, aim.z)
		await physics_frame
		climbed = climbed or p.climbing != null
		if p.is_on_floor() and p.global_position.y > 12.9:
			break
	p.ai_move = Vector2.ZERO
	await frames(40)
	check("climb the colossus's fur from the ground onto its 13 m back", climbed and p.global_position.y > 12.9 and col.ridden(),
		"climbed %s, ended at y %.1f, riding %s" % [climbed, p.global_position.y, col.ridden()])

	# 90. The back plate shrugs off the spear; a ground pound cracks it off, and a second pound strikes the sigil
	p.inventory.add("spear")
	var fwd := -col.global_basis.z
	await _hover(col.to_global(Vector3(0, 14.2, 3.2)))
	p.facing = fwd
	await frames(20)
	p.ai_attack = true
	await frames(30)
	var plate_after_spear := col.plate != null
	await _hover(col.to_global(Vector3(0, 16.5, 1)))
	p.ai_attack = true
	await frames(60)
	var cracked := col.plate == null and col.sigils[0].opened
	await _hover(col.to_global(Vector3(0, 16.0, 1)))
	p.ai_attack = true
	await frames(60)
	check("a pound cracks the colossus's back plate (the spear can't), and a second pound strikes the sigil under it",
		plate_after_spear and cracked and col.sigils[0].struck and not col.felled,
		"plate survived the spear %s, cracked by the pound %s, sigil struck %s" % [plate_after_spear, cracked, col.sigils[0].struck])

	# 91. A bomb blast breaks a front shin; with both gone it kneels, its forehead opens low enough to spear, and it falls
	await _fresh_player(m["colossus_arena"])
	var broke := []
	for k in 2:
		var shin: ColossusShin = col.shins[0]
		await _pull_bomb()
		var b: Bomb = p.carrying
		p.ai_context = true # standing still: set it down
		await frames(3)
		b._t = Bomb.FUSE - 0.1
		b.global_position = shin.global_position + col.global_basis.x * signf(shin.position.x) * 2.0 + Vector3.DOWN * 1.7
		await frames(20)
		broke.append(not is_instance_valid(shin) or not col.shins.has(shin))
	await frames(90)
	var head: ColossusSigil = col.sigils[1]
	var low := head.global_position.y
	var face := -col.global_basis.z
	face.y = 0.0
	face = face.normalized()
	await _fresh_player(Vector3(head.global_position.x, 0.6, head.global_position.z) + face * 1.7)
	p.inventory.add("spear")
	p.facing = -face
	await frames(5)
	p.ai_attack = true
	await frames(30)
	check("bombs break both front shins, it kneels with its forehead sigil %.1f m up, and striking it fells the colossus" % low,
		broke == [true, true] and col.kneel == 1.0 and low < 2.5 and col.felled,
		"shins broken %s, kneel %.1f, forehead at %.1f m, felled %s" % [broke, col.kneel, low, col.felled])
	await _fresh_player(m["colossus_arena"])
