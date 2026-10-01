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
	for sp in get_nodes_in_group("spawners"):
		sp.queue_free()
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
	p.poleaxe.busy = 0.0
	p.poleaxe.combo_step = 0
	p.poleaxe.frozen = false
	p.poleaxe.stuck_t = 0.0
	p.ai_guard = false
	p.guard_t = -1.0
	p.guard_break_t = 0.0
	p.parry_t = 0.0
	p.surfing = false
	p.focus_meter = 0.0
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

	# 12. Poleaxe: each thrust hits once (not once per frame), 3 thrusts kill a blob
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
	var mon := _monster_ahead(1.6)
	var hits := []
	for k in 3:
		mon.global_position = p.global_position + Vector3(0, 0.1, -1.6)
		mon.velocity = Vector3.ZERO
		mon.stun = 5.0 # hold still so only the poleaxe matters
		p.ai_attack = true
		await frames(24)
		hits.append(mon.hp if is_instance_valid(mon) else 0)
	check("poleaxe: 3 thrusts, 1 damage each", hits == [2, 1, 0], "hp after each thrust %s" % [hits])
	await frames(2)
	check("dead blob is removed", not is_instance_valid(mon), "")

	# 13. No poleaxe, no attack
	await _fresh_player(arena)
	mon = _monster_ahead(1.6)
	mon.stun = 5.0
	p.ai_attack = true
	await frames(24)
	check("can't attack before finding the poleaxe", mon.hp == 3, "blob hp %d" % mon.hp)
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
	Pickup.spawn(level, "poleaxe", 1, p.global_position + Vector3(0, 0.3, -3))
	p.ai_move = Vector2(0, -1)
	await frames(30)
	p.ai_move = Vector2.ZERO
	check("walking into the poleaxe picks it up", p.inventory.has("poleaxe"), "")

	# 17. Inventory: pickups go on free quick slots; assign swaps; potion only works when hurt
	await _fresh_player(arena)
	var inv := p.inventory
	inv.add("candle")
	inv.add("potion")
	inv.add("poleaxe")
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
	await _plants_tests(arena)
	await _moves_yard_tests(arena)
	await _combo_tests(arena)
	await _challenge_tests(arena)
	await _colossus_tests()
	await _feel_fix_tests()
	await _poleaxe_tests()
	await _works_tests(arena)
	await _powers_tests()
	await _cellar_tests()
	await _spider_lash_tests(arena)

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
	p.inventory.add("poleaxe")
	mon = _monster_ahead(1.6)
	mon.hp = 10
	var seq := []
	for k in 3:
		mon.global_position = p.global_position + Vector3(0, 0.1, -1.6)
		mon.velocity = Vector3.ZERO
		mon.stun = 5.0
		p.ai_attack = true
		await frames(int(Poleaxe.MOVES[Poleaxe.COMBO[k]]["dur"] * 60.0) + 4)
		seq.append(mon.hp)
	check("quick combo: jab, jab, sweep", seq == [9, 8, 6], "hp after each %s" % [seq])

	# 29. Waiting too long restarts the combo at a jab
	await frames(40)
	mon.global_position = p.global_position + Vector3(0, 0.1, -1.6)
	var before: int = mon.hp
	p.ai_attack = true
	await frames(20)
	check("combo resets after a pause", before - mon.hp == 1 and p.poleaxe.move == "thrust", "took %d, move %s" % [before - mon.hp, p.poleaxe.move])
	mon.queue_free()

	# 30. Charged spin hits in front and behind
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
	var front := _monster_ahead(2.0)
	var back := _monster_ahead(-2.0)
	for mm in [front, back]:
		mm.stun = 20.0
		mm.hp = 10
	p.ai_attack = true
	p.ai_attack_held = true
	await frames(int(t.spin_charge_time * 60.0) + 5)
	var held_back: bool = p.poleaxe.frozen and front.hp == 10 # the thrust waits while you hold
	p.ai_attack_held = false
	await frames(40)
	check("hold attack %.1f s and let go: a spin hits all around" % t.spin_charge_time, held_back and front.hp == 8 and back.hp == 8,
		"held back %s, front %d, back %d" % [held_back, front.hp, back.hp])
	front.queue_free()
	back.queue_free()

	# 31. Long slash: attacking at full speed lunges and hits from further away
	await _fresh_player(Vector3(90, 0.6, -20))
	p.inventory.add("poleaxe")
	p.velocity = Vector3(0, 0, -t.top_speed)
	p.ai_move = Vector2(0, -1)
	await frames(5)
	mon = _monster_ahead(4.5)
	mon.stun = 20.0
	p.ai_move = Vector2.ZERO
	p.ai_attack = true
	await frames(30)
	check("running long slash", p.poleaxe.move == "run" and mon.hp == 1, "move %s, blob hp %d" % [p.poleaxe.move, mon.hp])
	mon.queue_free()

	# 32. Air slash hits a blob below and in front
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
	mon = _monster_ahead(1.5)
	mon.stun = 20.0
	p.ai_jump = true
	await frames(12)
	p.ai_jump = false
	p.ai_target = true # locked on, the air attack is the poleaxe's (without lock-on it's a ground pound)
	p.ai_attack = true
	await frames(40)
	p.ai_target = false
	check("air slash", p.poleaxe.move == "air" and mon.hp == 1, "move %s, blob hp %d" % [p.poleaxe.move, mon.hp])
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
	check("thrown bomb (walking) stops 2-4.5 m ahead (shorter throw, jovi)", throw_dist > 2.0 and throw_dist < 4.5, "%.1f m" % throw_dist)
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
	check("grass fire spreads, melts the ice, lights the brazier, opens the gate", far == 48 and gate_a.opened, "%d of 48 patches burnt, gate open %s" % [far, gate_a.opened])

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
	p.inventory.add("poleaxe")
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
	p.inventory.add("poleaxe")
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
		p.inventory.add("poleaxe")
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

	# 67d. The spider is small (the small player's size): it slips through a grate, the gear cage's fine mesh
	# stops it, and the context button picks it up
	await _fresh_player(arena)
	var grate := Grate.make(level, arena + Vector3(3.0, -0.6, 0), Vector3(0.2, 2.0, 4.0))
	p.inventory.add("spider")
	p.facing = Vector3.RIGHT
	await _use("spider")
	p.ai_move = Vector2(1, 0)
	await frames(60)
	p.ai_move = Vector2.ZERO
	var through: bool = p.spider.global_position.x > arena.x + 3.5
	await _use("spider")
	p.stow_spider()
	grate.queue_free()
	await _fresh_player(Vector3(44, 0.6, 66)) # west of the gear cage
	p.inventory.add("spider")
	p.facing = Vector3.RIGHT
	await _use("spider")
	p.ai_move = Vector2(1, 0)
	await frames(90)
	p.ai_move = Vector2.ZERO
	var sx := p.spider.global_position.x
	await _use("spider")
	await place(p.spider.global_position + Vector3(-1.0, 0.4, 0))
	p.ai_context = true
	await frames(3)
	check("the spider is %.2f m across (the small player's size): it slips through a grate, the gear cage's mesh stops it, context picks it up" % (Spider.RADIUS * 2.0),
		through and sx < 47.5 and p.spider == null, "through the grate %s, stopped at x %.1f (cage at 47.5), picked up %s" % [through, sx, p.spider == null])

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


## Plants are congruent; climbing and spearing with seeds; uprooting frees roots; the small spider carries things.
func _plants_tests(arena: Vector3) -> void:
	var m: Dictionary = level.marks
	var t: Tuning = level.t

	# P2. The moves yard's vines: the lash pulls you to them, the candle burns them, and they grow back
	var vine: Burnable = null
	for n in get_nodes_in_group("plant_vine"):
		if (n as Burnable).regrow > 0.0:
			vine = n
	await _fresh_player(m["moves_climb"])
	p.inventory.add("lash")
	p.facing = Vector3.FORWARD
	await _use("lash")
	var pulled := p.grapple_t > 0.0
	await frames(40)
	p.set_candle(true)
	p.ai_move = Vector2(0, -1)
	await frames(20)
	p.ai_move = Vector2.ZERO
	p.set_candle(false)
	await frames(int(Burnable.BURN["vines"] * 60.0) + 10)
	var burnt := vine.burnt and is_instance_valid(vine)
	vine._regrow_t = vine.regrow - 0.05 # skip the wait
	await frames(6)
	check("the lash pulls you to vines, fire burns them, and the moves yard's grow back in %.0f s" % vine.regrow, pulled and burnt and not vine.burnt,
		"pulled %s, burnt %s, grown back %s" % [pulled, burnt, not vine.burnt])

	# P3. Climb the vine shelf holding a seed, plant it on the soil up top, and the cube and a ledge grab reach the
	# 4.5 m pillar
	await _fresh_player(Vector3(73.2, 0.6, 57))
	p.facing = Vector3.LEFT
	await frames(2)
	p.ai_context = true # next to the seed: pick it up
	await frames(3)
	var sd: Seed = p.held_seed
	p.ai_move = Vector2(1, 0)
	var climbed_with := 0.0
	var y_start := p.global_position.y
	for i in 240:
		await physics_frame
		if p.climbing != null and p.held_seed != null:
			climbed_with = maxf(climbed_with, p.global_position.y - y_start)
		if p.is_on_floor() and p.global_position.y > 6.3:
			break
	p.ai_move = Vector2.ZERO
	await frames(40)
	var on_shelf := p.global_position.y > 6.3 and p.held_seed != null
	p.facing = Vector3.LEFT # back toward the vines: the soil is behind you
	await frames(2)
	p.ai_context = true # set it down on the soil: it plants
	await frames(3)
	var planted_up := sd != null and sd.planted
	p.ai_move = Vector2(-1, 0) # onto the cube
	for i in 120:
		await physics_frame
		if p.is_on_floor() and not p.ai_jump:
			p.ai_jump = true
		elif p.ai_jump and p.velocity.y < 0.0:
			p.ai_jump = false
		if p.is_on_floor() and p.global_position.y > 8.3:
			break
	p.ai_jump = false
	p.ai_move = Vector2(1, 0) # and up to the pillar
	for i in 400:
		await physics_frame
		if p.is_on_floor() and not p.ai_jump:
			p.ai_jump = true
		elif p.ai_jump and p.velocity.y < 0.0:
			p.ai_jump = false
		if p.is_on_floor() and p.global_position.y > 10.8:
			break
	p.ai_move = Vector2.ZERO
	p.ai_jump = false
	await frames(20)
	check("you climb %.1f m of vines holding a seed (4 or more), plant it on the shelf, and reach the 4.5 m pillar" % climbed_with,
		climbed_with >= 4.0 and on_shelf and planted_up and p.global_position.y > 10.8, "climbed %.1f m holding it, on the shelf %s, planted %s, ended y %.1f" % [climbed_with, on_shelf, planted_up, p.global_position.y])
	if sd != null:
		sd.queue_free()

	# P4. Let go of a seed on the vines 3 m up: it drops behind you and spears into the mud
	await _fresh_player(m["root_vine"])
	var sd2 := Seed.make(level, p.global_position + Vector3.UP * 2.0, t)
	await physics_frame
	sd2.hold(p)
	p.held_seed = sd2
	p.ai_move = Vector2(1, 0)
	var y0 := p.global_position.y
	for i in 180:
		await physics_frame
		if p.climbing != null and p.global_position.y - y0 >= 3.0:
			break
	var up := p.global_position.y - y0
	var climbing_then := p.climbing != null
	var from_y := sd2.global_position.y
	p.ai_context = true
	await frames(2)
	p.ai_move = Vector2.ZERO
	await frames(90)
	var fell := from_y - sd2.global_position.y
	check("let go of a seed %.1f m up the vines: it falls %.1f m (spear_drop %.0f) and spears into the mud" % [up, fell, t.spear_drop],
		climbing_then and up >= 3.0 and sd2.planted and fell >= t.spear_drop and sd2.global_position.x < 78.0, "climbing %s, planted %s, at x %.1f" % [climbing_then, sd2.planted, sd2.global_position.x])
	sd2.queue_free()

	# P5. Uproot a plant and the root it blocked grows on into the freed space
	await _fresh_player(arena)
	var a := Seed.make(level, arena + Vector3(-4, Seed.HALF - 0.55, -6), t)
	var b := Seed.make(level, arena + Vector3(2, Seed.HALF - 0.55, -3), t) # 6 m east of it and a cell and a half south
	await frames(10)
	a.plant()
	await frames(2)
	b.plant()
	await frames(2)
	var before := b.root_reach(Vector3.LEFT)
	await place(a.global_position + Vector3(-1.7, -0.4, 0))
	p.ai_context = true # next to it: pull it up
	await frames(3)
	var uprooted := not a.planted and p.held_seed == a
	await frames(5)
	var after := b.root_reach(Vector3.LEFT)
	check("uprooting a plant lets the root it blocked grow on %.1f m (%d cells of 2 m), to %.0f m" % [after - before, int((after - before) / 2.0), after],
		uprooted and before < 6.0 and after >= t.root_length - 0.1, "uprooted %s, root %.1f m then %.1f m" % [uprooted, before, after])
	p.drop_holds()
	a.queue_free()
	b.queue_free()

	# P6. The spider carries: steering it, context picks up a seed, carries it, sets it down; then picks you up,
	# carries you and sets you down
	await _fresh_player(arena)
	var cube := Seed.make(level, arena + Vector3(3.0, Seed.HALF - 0.55, 0), t)
	await frames(10)
	var cube_at := cube.global_position
	p.inventory.add("spider")
	p.facing = Vector3.RIGHT
	await _use("spider")
	p.ai_move = Vector2(1, 0) # up to the seed's side
	for i in 60:
		await physics_frame
		if p.spider.global_position.x > cube_at.x - Seed.HALF - 0.5:
			break
	p.ai_move = Vector2.ZERO
	await frames(20)
	p.ai_context = true
	await frames(3)
	var lifted_seed: bool = p.spider.held == cube and cube.holder == p.spider
	p.ai_move = Vector2(0, -1)
	await frames(40)
	p.ai_move = Vector2.ZERO
	await frames(30)
	var carried_m := Vector2(cube.global_position.x - cube_at.x, cube.global_position.z - cube_at.z).length()
	p.ai_context = true # standing still: set it down in front
	await frames(30)
	var put_down: bool = cube.holder == null and p.spider.held == null and cube.is_on_floor()
	p.spider.global_position = p.global_position + Vector3(1.0, -0.3, 0)
	await frames(5)
	p.ai_context = true
	await frames(3)
	var lifted_you := p.carried_by == p.spider
	var you_at := p.global_position
	p.ai_move = Vector2(1, 0)
	await frames(60)
	p.ai_move = Vector2.ZERO
	await frames(20)
	var rode := Vector2(p.global_position.x - you_at.x, p.global_position.z - you_at.z).length()
	var above: bool = p.global_position.y > p.spider.global_position.y + 0.5
	p.ai_context = true
	await frames(40)
	var set_you_down := p.carried_by == null and p.is_on_floor()
	check("the spider carries a seed %.1f m and sets it down, then carries you %.1f m and sets you down" % [carried_m, rode],
		lifted_seed and carried_m > 3.0 and put_down and lifted_you and rode > 3.0 and above and set_you_down,
		"seed lifted %s, put down %s; you lifted %s, rode overhead %s, set down %s" % [lifted_seed, put_down, lifted_you, above, set_you_down])
	await _use("spider")
	p.stow_spider()
	cube.queue_free()

	# P6b. Carrying a seed, the spider is as big as its load: a grate it slips through empty-handed stops it
	await _fresh_player(arena)
	var load_seed := Seed.make(level, arena + Vector3(1.0, Seed.HALF - 0.55, -3.0), t)
	var grate := Grate.make(level, arena + Vector3(4.5, -0.6, -3.0), Vector3(0.2, 3.0, 6.0))
	await frames(10)
	p.inventory.add("spider")
	p.facing = Vector3.FORWARD
	await _use("spider")
	p.spider.global_position = load_seed.global_position + Vector3(Seed.HALF + 0.4, -0.8, 0)
	await frames(10)
	p.ai_context = true
	await frames(3)
	var loaded: bool = p.spider.held == load_seed
	p.ai_move = Vector2(1, 0)
	await frames(90)
	p.ai_move = Vector2.ZERO
	var held_back: bool = p.spider.global_position.x < arena.x + 4.5
	check("carrying a seed the spider is as big as its load: a grate stops it", loaded and held_back,
		"loaded %s, spider at x %.1f (grate at %.1f)" % [loaded, p.spider.global_position.x, arena.x + 4.5])
	await _use("spider")
	p.stow_spider()
	load_seed.queue_free()
	grate.queue_free()

	# P7. The spider cage on plateau A: the spider slips through the grate, carries the seed to the soil and it
	# plants; its root bridges the chasm
	await _fresh_player(m["root_cage_stand"])
	var caged: Seed = null
	for n in get_nodes_in_group("seeds"):
		if (n as Seed).global_position.distance_to(m["root_cage_seed"]) < 0.5:
			caged = n
	p.inventory.add("spider")
	p.facing = Vector3.RIGHT
	await _use("spider")
	p.ai_move = Vector2(1, 0) # east through the grate (x 72) to beside the seed
	for i in 120:
		await physics_frame
		if p.spider.global_position.x > 73.0:
			break
	p.ai_move = Vector2.ZERO
	await frames(15)
	p.ai_context = true
	await frames(3)
	var took: bool = caged != null and p.spider.held == caged
	p.ai_move = Vector2(1, 0) # over to x ~74.5
	for i in 60:
		await physics_frame
		if p.spider.global_position.x > 74.0:
			break
	p.ai_move = Vector2.ZERO
	await frames(20)
	p.ai_move = Vector2(0, 1) # north towards the soil, until it's just in front
	for i in 60:
		await physics_frame
		if p.spider.global_position.z > 73.1:
			break
	p.ai_move = Vector2.ZERO
	await frames(30)
	p.ai_context = true
	await frames(3)
	var span := 0.0
	if caged != null and caged.planted:
		span = caged.global_position.z + Seed.HALF + caged.root_reach(Vector3.BACK)
	check("the spider takes the caged seed through the grate to the soil; it plants and its root spans the chasm to z %.1f" % span,
		took and caged.planted and span > 90.3, "took it %s, planted %s" % [took, caged != null and caged.planted])
	await _use("spider")
	p.stow_spider()
	await _fresh_player(arena)

	# P8. Every plant follows the plant rules (Plants): vines climb, burn and take the lash; wood climbs and takes
	# the lash; grass burns
	var bad: Array[String] = []
	var counts := {"vine": 0, "wood": 0, "grass": 0}
	for n in get_nodes_in_group("plants"):
		var miss := Plants.missing(n)
		if not miss.is_empty():
			bad.append("%s missing %s" % [n.name, miss])
		counts[n.get_meta("plant")] += 1
	for n in get_nodes_in_group("flammable"):
		if n is Burnable and not n.is_in_group("plants"):
			bad.append("%s burns but isn't a plant" % n.name)
	for n in get_nodes_in_group("trunks") + get_nodes_in_group("roots"):
		if not n.is_in_group("plant_wood"):
			bad.append("%s isn't wood" % n.name)
	check("every plant follows the rules: %d vines (climb, burn, lash), %d trunks and roots (climb, lash), %d grass (burn)" % [counts["vine"], counts["wood"], counts["grass"]],
		bad.is_empty() and counts["vine"] > 0 and counts["wood"] > 0 and counts["grass"] > 0, "%s" % [bad])

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
	p.inventory.add("poleaxe")
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
	p.inventory.add("poleaxe")
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

	# 74. Hit feel: a poleaxe hit freezes the game briefly, then it runs again
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
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
	check("a poleaxe hit stops the game for %.2f s, then it resumes" % t.hitstop, froze and Engine.time_scale == 1.0, "froze %s, time scale now %.2f" % [froze, Engine.time_scale])
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
	p.inventory.add("poleaxe")
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
	var landed_speed := 0.0
	for i in 120:
		await physics_frame
		left = left or not p.is_on_floor()
		if left and p.is_on_floor():
			await frames(2) # the landing trims the boost on the next step
			landed_speed = p.flat_speed()
			break
	p.ai_move = Vector2.ZERO
	var dist := Vector2(p.global_position.x - from.x, p.global_position.z - from.z).length()
	var keep := t.top_speed + (t.long_jump_speed - t.top_speed) * t.long_jump_keep
	check("landing a long jump keeps only %.0f%% of its boost: %.1f m/s, not %.0f" % [t.long_jump_keep * 100.0, keep, t.long_jump_speed],
		landed_speed > t.top_speed and landed_speed < keep + 0.5, "%.1f m/s on landing" % landed_speed)
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

	# 90. The back plate shrugs off the poleaxe; a ground pound cracks it off, and a second pound strikes the sigil
	p.inventory.add("poleaxe")
	var fwd := -col.global_basis.z
	await _hover(col.to_global(Vector3(0, 14.2, 3.2)))
	p.facing = fwd
	await frames(20)
	p.ai_attack = true
	await frames(30)
	var plate_after_axe := col.plate != null
	await _hover(col.to_global(Vector3(0, 16.5, 1)))
	p.ai_attack = true
	await frames(60)
	var cracked := col.plate == null and col.sigils[0].opened
	await _hover(col.to_global(Vector3(0, 16.0, 1)))
	p.ai_attack = true
	await frames(60)
	check("a pound cracks the colossus's back plate (the poleaxe can't), and a second pound strikes the sigil under it",
		plate_after_axe and cracked and col.sigils[0].struck and not col.felled,
		"plate survived the poleaxe %s, cracked by the pound %s, sigil struck %s" % [plate_after_axe, cracked, col.sigils[0].struck])

	# 91. A bomb blast breaks a front shin; with both gone it kneels, its forehead opens low enough to strike, and it falls
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
	p.inventory.add("poleaxe")
	p.facing = -face
	await frames(5)
	p.ai_attack = true
	await frames(30)
	check("bombs break both front shins, it kneels with its forehead sigil %.1f m up, and striking it fells the colossus" % low,
		broke == [true, true] and col.kneel == 1.0 and low < 2.5 and col.felled,
		"shins broken %s, kneel %.1f, forehead at %.1f m, felled %s" % [broke, col.kneel, low, col.felled])
	await _fresh_player(m["colossus_arena"])

## jovi's playtest notes (2026-09-30): camera on locked-on chains, the ledge-pound long jump, boost pads.
func _feel_fix_tests() -> void:
	var m: Dictionary = level.marks
	var t: Tuning = level.t

	# 92. A locked-on homing chain up the pogo spikes doesn't turn the camera round
	var rig: CameraRig = get_nodes_in_group("camera_rig")[0]
	await _fresh_player(m["moves_pogo"])
	p.inventory.add("poleaxe")
	rig.yaw = 0.0 # looking -z, up the spikes
	p.ai_target = true
	await frames(20)
	var yaw0 := rig.yaw
	var swing := 0.0
	p.ai_move = Vector2(0, -0.4)
	p.ai_jump = true
	var bounces := 0
	var was_homing := false
	for i in 300:
		await physics_frame
		swing = maxf(swing, absf(angle_difference(yaw0, rig.yaw)))
		if p.homing != null:
			was_homing = true
		elif was_homing:
			was_homing = false
			bounces += 1
		p.ai_attack = not p.is_on_floor() and p.velocity.y < 1.0 and p.homing == null and bounces < 2
		if bounces >= 2:
			break
	p.ai_attack = false
	p.ai_jump = false
	p.ai_move = Vector2.ZERO
	await frames(40)
	swing = maxf(swing, absf(angle_difference(yaw0, rig.yaw)))
	p.ai_target = false
	check("a locked-on homing chain keeps the camera facing ahead (turned under 45°)", bounces == 2 and swing < deg_to_rad(45.0),
		"bounces %d, camera turned %.0f°" % [bounces, rad_to_deg(swing)])

	# 93. Ledge grab, pull up, pound onto the ledge, roll out, long jump: ledge_long_mult stronger
	await _fresh_player(m["moves_ledge"])
	p.ai_move = Vector2(0, -1)
	var jumped := false
	var pounded := false
	var launched := Vector3.ZERO
	for i in 300:
		await physics_frame
		if not jumped and p.global_position.z < -73.8:
			p.ai_jump = true
			jumped = true
		elif jumped and p.hang == Vector3.ZERO and p.velocity.y < 0.0 and not pounded:
			p.ai_jump = false
		if jumped and not pounded and p._ledge_up_t < 0.5 and not p.is_on_floor() and p.global_position.z < -76.6:
			p.ai_jump = false
			p.ai_attack = true # right out of the pull-up, over the ledge: pound onto it
			pounded = true
		if pounded and p.roll_t > 0.0 and p.roll_kind == "roll" and p.is_on_floor() and not p.ai_jump:
			p.ai_jump = true # jump out of the roll
		if p.long_jumping:
			launched = p.velocity
			break
	p.ai_jump = false
	p.ai_move = Vector2.ZERO
	var want_h := t.long_jump_speed * t.ledge_long_mult
	var want_up := t.long_jump_up * t.ledge_long_mult
	var h := Vector2(launched.x, launched.z).length()
	check("ledge grab, pound, roll, long jump launches at %.0f m/s and %.1f m/s up (a plain long jump: %.0f and %.0f)" % [want_h, want_up, t.long_jump_speed, t.long_jump_up],
		pounded and absf(h - want_h) < 0.6 and absf(launched.y - want_up) < 0.6, "pounded %s, launched %.1f m/s forward, %.1f up" % [pounded, h, launched.y])
	await _fresh_player(m["moves_ledge"])

	# 94. The boost pad's speed lasts boost_hold before bleeding, so you reach the quarter pipe at full speed
	await place(m["pipe_start"])
	p.ai_move = Vector2(0, -1)
	var at_pipe := 0.0
	for i in 240:
		await physics_frame
		if p.global_position.z < -48.0:
			at_pipe = p.flat_speed()
			break
	p.ai_move = Vector2.ZERO
	await frames(120)
	check("a boost pad holds %.0f m/s for %.1f s: you reach the quarter pipe still going %.0f" % [t.boost_pad_speed, t.boost_hold, t.boost_pad_speed],
		at_pipe > t.boost_pad_speed - 1.0, "%.1f m/s at the pipe" % at_pipe)

## A monster that stands still for the test: no AI, no drop.
func _dummy(pos: Vector3, kind := "blob", spiked := false, hp := 10) -> Monster:
	var mon := Monster.spawn(level, pos, kind, spiked)
	mon.drop_heart = false
	mon.home = pos
	mon.max_hp = hp
	mon.stun = 60.0
	await physics_frame
	mon.hp = hp
	mon.state = "move"
	return mon

## Press attack and hold it for secs, then let go.
func _hold_attack(secs: float) -> void:
	p.ai_attack = true
	p.ai_attack_held = true
	await frames(int(secs * 60.0))
	p.ai_attack_held = false

## The poleaxe kit (combat sketchbook VII), the spin on a longer hold, and spiked monsters.
func _poleaxe_tests() -> void:
	var t: Tuning = level.t
	var m: Dictionary = level.marks
	var arena := Vector3(-80, 0.6, -90)

	# 95. Tipper: a thrust landed with the last stretch of its reach does double
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
	var mon := await _dummy(p.global_position + Vector3(0, 0.1, -2.7 * Poleaxe.REACH))
	p.ai_attack = true
	await frames(24)
	check("a thrust's tip (%.2f m or more out, the doubled poleaxe) does double: 2" % Poleaxe.TIP_FROM, mon.hp == 8, "blob hp %d of 10" % mon.hp)
	mon.queue_free()

	# 95b. The poleaxe is twice the size: the thrust reaches 6.2 m (it was 3.1)
	var reach: float = float(Poleaxe.MOVES["thrust"]["fwd"]) + (Poleaxe.MOVES["thrust"]["box"] as Vector3).z / 2.0
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
	mon = await _dummy(p.global_position + Vector3(0, 0.1, -(reach - 0.2)))
	p.ai_attack = true
	await frames(24)
	check("the doubled poleaxe: a thrust reaches %.1f m (twice 3.1) and its tip (from %.1f m) still doubles" % [reach, Poleaxe.TIP_FROM],
		absf(reach - 6.2) < 0.01 and mon.hp == 8, "blob %.1f m out, hp %d of 10" % [reach - 0.2, mon.hp])
	mon.queue_free()

	# 96. A short hold delays the thrust; hold past hammer_hold and it's the hammer: +2 at its centre, and a stagger
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
	mon = await _dummy(p.global_position + Vector3(0, 0.1, -2.0 * Poleaxe.REACH))
	p.ai_attack = true
	p.ai_attack_held = true
	await frames(int(t.hammer_hold * 60.0) - 4)
	var waited: bool = mon.hp == 10 and p.poleaxe.frozen
	p.ai_attack_held = false
	await frames(20)
	var delayed_thrust: bool = mon.hp == 9 and p.poleaxe.move == "thrust"
	await frames(20)
	mon.hp = 10
	mon.stun = 0.6 # still reeling when the hammer lands, so the stagger shows
	mon.global_position = p.global_position + Vector3(0, 0.1, -2.0 * Poleaxe.REACH)
	await _hold_attack(t.hammer_hold + 0.1)
	await frames(20)
	check("hold attack under %.2f s: the thrust waits, then lands (1)" % t.hammer_hold, waited and delayed_thrust, "waited %s, delayed thrust %s" % [waited, delayed_thrust])
	check("hold past %.2f s: the hammer, 4 at its centre, and it staggers" % t.hammer_hold, p.poleaxe.move == "hammer" and mon.hp == 6 and mon.stun > 0.9,
		"move %s, blob hp %d, stun %.1f" % [p.poleaxe.move, mon.hp, mon.stun])
	mon.queue_free()

	# 97. The spin works in the air: charge on the ground, jump, let go; the whirl slows your fall
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
	p.ai_attack = true
	p.ai_attack_held = true
	await frames(int(t.spin_charge_time * 60.0) - 20)
	p.ai_jump = true
	await frames(22)
	p.ai_jump = false
	var aloft := not p.is_on_floor()
	p.ai_attack_held = false
	var slowest := 0.0
	var air_spin := false
	for i in 25:
		await physics_frame
		if p.poleaxe.move == "spin" and p.poleaxe.busy > 0.0 and not p.is_on_floor():
			air_spin = true
			slowest = minf(slowest, p.velocity.y)
	check("hold %.1f s, jump and let go: a spin in the air, falling no faster than 3 m/s" % t.spin_charge_time, aloft and air_spin and slowest >= -3.05,
		"in the air %s, spun %s, fell at %.1f m/s" % [aloft, air_spin, -slowest])
	await frames(30)

	# 98. The sweep launches; each air hit lifts less (8, 6, 4 m/s), then nothing does but a spike
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
	mon = await _dummy(p.global_position + Vector3(0, 0.1, -1.8 * Poleaxe.REACH))
	var combo := []
	for k in 3:
		mon.global_position = p.global_position + Vector3(0, 0.1, -1.8 * Poleaxe.REACH)
		mon.velocity = Vector3.ZERO
		p.ai_attack = true
		await frames(2)
		combo.append(p.poleaxe.move)
		for i in 60: # hitstop stretches a swing, so wait for it to end
			if p.poleaxe.busy <= 0.0:
				break
			await physics_frame
	var launched := mon.air
	var top_y := mon.global_position.y
	for i in 30:
		await physics_frame
		top_y = maxf(top_y, mon.global_position.y)
	var lifts := []
	for k in 4:
		mon.velocity.y = -1.0 # falling
		mon.strike(0, p.global_position, {"head": "blade", "air": true})
		lifts.append(snappedf(mon.velocity.y, 0.1))
	check("the sweep launches a blob %.1f m up, and juggle hits lift it 8, 6, 4 m/s, then not at all" % (top_y - p.global_position.y), launched and top_y - p.global_position.y > 1.8 and lifts == [8.0, 6.0, 4.0, -1.0],
		"moves %s, launched %s, lifts %s" % [combo, launched, lifts])
	mon.queue_free()

	# 99. A pound onto a launched blob spikes it down; its landing bursts on the blob beside it
	await _fresh_player(arena + Vector3(8, 0, 0))
	mon = await _dummy(arena + Vector3(0, 0.1, 0))
	var other := await _dummy(arena + Vector3(2.0, 0.1, 0))
	mon.stun = 0.0
	mon.strike(0, mon.global_position + Vector3.BACK, {"launch": true})
	await frames(15)
	await _hover(mon.global_position + Vector3(0, 2.2, 0))
	p.ai_attack = true
	var spiked_down := 0.0
	for i in 60:
		await physics_frame
		if is_instance_valid(mon):
			spiked_down = minf(spiked_down, mon.velocity.y)
	check("a pound spikes a launched blob down (%.0f m/s) and its landing bursts on the one beside it" % Monster.SPIKE_SPEED,
		spiked_down < -20.0 and other.hp == 9 and mon.hp < 8, "fell at %.0f m/s, neighbour hp %d, blob hp %d" % [-spiked_down, other.hp, mon.hp])
	mon.queue_free()
	other.queue_free()

	# 100. Guard: a perfect guard (the first 0.2 s) opens the attacker; later hits are blocked and push you back;
	# a heavy hit with a wall right behind you breaks the guard
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
	mon = await _dummy(p.global_position + Vector3(0, 0.1, -1.5))
	p.ai_guard = true
	await frames(4)
	p.hurt(1, mon.global_position, mon)
	var perfect: bool = p.hp == p.max_hp and mon.open_t > 0.0 and p.parry_t > 0.0
	await frames(30)
	p.hurt(1, mon.global_position, mon)
	var push := p.flat_speed()
	var blocked := p.hp == p.max_hp
	await frames(20)
	p.hurt(2, mon.global_position, mon, true)
	var push_heavy := p.flat_speed()
	check("perfect guard (first %.1f s): no damage, the attacker opens up" % t.perfect_guard, perfect, "hp %d, open %.1f, parry %.1f" % [p.hp, mon.open_t, p.parry_t])
	check("a block costs nothing and pushes you back %.0f m/s (heavy: %.0f)" % [t.guard_push, t.guard_push_heavy], blocked and p.hp == p.max_hp and absf(push - t.guard_push) < 0.6 and absf(push_heavy - t.guard_push_heavy) < 0.6,
		"hp %d, pushed %.1f then %.1f m/s" % [p.hp, push, push_heavy])
	mon.queue_free()
	await _fresh_player(m["combat_court"] + Vector3(0, 0, -7.2)) # just in front of the court wall
	p.inventory.add("poleaxe")
	p.facing = Vector3.BACK # facing away from the wall
	p.ai_guard = true
	await frames(30)
	p.hurt(2, p.global_position + Vector3(0, 0, 1.5), null, true)
	check("a heavy hit with the wall behind you breaks your guard for %.1f s (no damage)" % t.guard_break, p.guard_break_t > 0.0 and not p.guarding() and p.hp == p.max_hp,
		"broken %.1f s, hp %d" % [p.guard_break_t, p.hp])
	p.ai_guard = false

	# 101. After a perfect guard the next sweet-spot hit is +2 and staggers
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
	mon = await _dummy(p.global_position + Vector3(0, 0.1, -2.7 * Poleaxe.REACH))
	p.ai_guard = true
	await frames(3)
	p.hurt(1, mon.global_position, null)
	p.ai_guard = false
	await frames(3)
	mon.stun = 0.4
	mon.open_t = 0.0
	p.ai_attack = true
	await frames(24)
	check("after a perfect guard a tip thrust does 2 + 2 and staggers", mon.hp == 6 and mon.stun > 0.9, "blob hp %d, stun %.1f" % [mon.hp, mon.stun])
	mon.queue_free()

	# 102. Arrows: a perfect guard sends one back into the archer; a later block just stops it
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
	var archer := await _dummy(p.global_position + Vector3(0, 0.3, -12), "archer", false, 2)
	var arrow := Arrow.shoot(level, p.global_position + Vector3(0, 0.3, -5), Vector3(0, 0, Monster.ARROW_SPEED), archer)
	await frames(10)
	p.ai_guard = true
	for i in 90:
		await physics_frame
	var sent_back := not is_instance_valid(archer) and p.hp == p.max_hp
	arrow = Arrow.shoot(level, p.global_position + Vector3(0, 0.3, -5), Vector3(0, 0, Monster.ARROW_SPEED), null)
	await frames(30)
	check("a perfect guard sends an arrow back and it kills the archer; a block stops the next", sent_back and not is_instance_valid(arrow) and p.hp == p.max_hp,
		"archer down %s, second arrow gone %s, hp %d" % [sent_back, not is_instance_valid(arrow), p.hp])
	p.ai_guard = false

	# 103. Brace: guard standing still, and a rusher charging onto your point is impaled (4) and the poleaxe sticks
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
	var rusher := await _dummy(p.global_position + Vector3(0, 0.1, -9), "rusher")
	rusher.stun = 0.0
	p.ai_guard = true
	var impaled := false
	var stuck := false
	for i in 150:
		await physics_frame
		if rusher.hp < 10:
			impaled = true
			stuck = p.poleaxe.stuck_t > 0.0
			break
	await frames(3)
	check("braced (%.2f s still), a rusher charging at %.0f m/s is impaled for %d and stunned; the poleaxe sticks %.1f s" % [t.brace_time, Monster.RUSH_SPEED, int(t.impale_damage), t.stuck_time],
		impaled and rusher.hp == 10 - int(t.impale_damage) and rusher.stun > 1.0 and stuck and p.hp == p.max_hp,
		"impaled %s, rusher hp %d, stun %.1f, stuck %s, your hp %d" % [impaled, rusher.hp, rusher.stun, stuck, p.hp])
	p.ai_guard = false
	rusher.queue_free()

	# 104. A rusher that misses charges on into the wall and is dazed
	await _fresh_player(m["combat_court"])
	rusher = await _dummy(m["combat_court"] + Vector3(0, 0.1, 6), "rusher")
	rusher.stun = 0.0
	var dodged_at := -1
	var dazed := false
	for i in 180:
		await physics_frame
		if dodged_at < 0 and rusher.state == "attack":
			dodged_at = i
			p.teleport(p.global_position + Vector3(6, 0, 0)) # sidestep
		if dodged_at >= 0 and rusher.stun > 1.0:
			dazed = true
			break
	check("a rusher that misses crashes into the wall and is dazed", dazed and p.hp == p.max_hp, "charged %s, dazed %s" % [dodged_at >= 0, dazed])
	rusher.queue_free()

	# 105. Shield blob: the point glances off, the hammer smashes the shield; a shield bash smashes it too
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
	mon = await _dummy(p.global_position + Vector3(0, 0.1, -2.0 * Poleaxe.REACH), "shield")
	mon.look_at(p.global_position, Vector3.UP)
	p.ai_attack = true
	await frames(24)
	var glanced := mon.hp == 10 and mon.shield_hp == 2
	await frames(20)
	mon.global_position = p.global_position + Vector3(0, 0.1, -2.0 * Poleaxe.REACH)
	await _hold_attack(t.hammer_hold + 0.1)
	await frames(20)
	var smashed := mon.shield_hp == 0 and mon.hp < 10
	mon.queue_free()
	mon = await _dummy(p.global_position + Vector3(0, 0.1, -1.4), "shield")
	mon.look_at(p.global_position, Vector3.UP)
	p.ai_guard = true
	await frames(20)
	p.ai_attack = true
	await frames(20)
	p.ai_guard = false
	check("a shield: the point glances off, the hammer smashes it, a shield bash smashes it", glanced and smashed and p.poleaxe.move == "bash" and mon.shield_hp == 0,
		"glanced %s, smashed %s, bash %s" % [glanced, smashed, mon.shield_hp == 0])
	mon.queue_free()

	# 106. Brute: armour shrugs off the stagger of a thrust; the hammer staggers it
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
	mon = await _dummy(p.global_position + Vector3(0, 0.1, -2.2 * Poleaxe.REACH), "brute")
	mon.stun = 0.0
	mon.state = "windup"
	mon.state_t = 5.0
	p.ai_attack = true
	await frames(12)
	var shrugged := mon.hp < 10 and mon.stun <= 0.0
	await frames(20)
	mon.global_position = p.global_position + Vector3(0, 0.1, -2.2 * Poleaxe.REACH)
	await _hold_attack(t.hammer_hold + 0.1)
	await frames(15)
	check("a brute takes a thrust without flinching; the hammer staggers it", shrugged and mon.stun > 0.9, "shrugged %s, stun %.1f" % [shrugged, mon.stun])
	mon.queue_free()

	# 107. Counter a windup (x1.5, rounded up) and punish a whiff (+1)
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
	mon = await _dummy(p.global_position + Vector3(0, 0.1, -1.6 * Poleaxe.REACH))
	mon.stun = 0.0
	mon.state = "windup"
	mon.state_t = 5.0
	p.ai_attack = true
	await frames(24)
	var countered := 10 - mon.hp
	await frames(20)
	mon.global_position = p.global_position + Vector3(0, 0.1, -1.6 * Poleaxe.REACH)
	mon.hp = 10
	mon.stun = 0.0
	mon.state = "recover"
	mon.state_t = 5.0
	mon.whiffed = true
	p.ai_attack = true
	await frames(24)
	check("a thrust into a windup counters for 2; into a missed attack's recovery punishes for 2", countered == 2 and mon.hp == 8,
		"counter %d, punish %d" % [countered, 10 - mon.hp])
	mon.queue_free()

	# 108. The hammer knocks a blob into a pillar (splat, +1) or into another blob (it bowls it over)
	await _fresh_player(Vector3(-93.2 + 2.0 * Poleaxe.REACH, 0.6, -48)) # the hammer's centre from the blob
	p.inventory.add("poleaxe")
	p.facing = Vector3.LEFT
	mon = await _dummy(Vector3(-93.2, 0.7, -48))
	await _hold_attack(t.hammer_hold + 0.1)
	await frames(40)
	var splat := mon.hp
	mon.queue_free()
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
	mon = await _dummy(p.global_position + Vector3(0, 0.1, -2.0 * Poleaxe.REACH))
	other = await _dummy(p.global_position + Vector3(0, 0.1, -2.0 * Poleaxe.REACH - 3.0)) # just past the hammer's reach
	await _hold_attack(t.hammer_hold + 0.1)
	await frames(40)
	check("hammered into a pillar a blob splats (4 + 1); into another blob it bowls it (1)", splat == 5 and other.hp == 9, "splat blob hp %d, bowled blob hp %d" % [splat, other.hp])
	mon.queue_free()
	other.queue_free()

	# 109. Down the combat hill you pass fast_blade_speed, and the running blade does 3 instead of 2
	await _fresh_player(m["combat_hill_top"])
	p.inventory.add("poleaxe")
	mon = await _dummy(Vector3(-74, 0.7, -27))
	p.ai_move = Vector2(1, 0)
	var at_attack := 0.0
	for i in 300:
		await physics_frame
		if at_attack == 0.0 and p.global_position.x > -79.0:
			at_attack = p.flat_speed()
			p.ai_attack = true
		if at_attack > 0.0 and mon.hp < 10:
			break
	p.ai_move = Vector2.ZERO
	await frames(30)
	check("the downhill runs you past %.0f m/s (%.1f) and the running blade does 3" % [t.fast_blade_speed, at_attack], at_attack > t.fast_blade_speed and p.poleaxe.move == "run" and mon.hp == 7,
		"%.1f m/s, move %s, blob hp %d" % [at_attack, p.poleaxe.move, mon.hp])
	mon.queue_free()

	# 110. Shield surf: jump holding guard at the hilltop, land on your shield and ride it down past top speed into a blob
	await _fresh_player(m["combat_hill_top"])
	p.inventory.add("poleaxe")
	mon = await _dummy(Vector3(-72, 0.7, -27))
	p.ai_move = Vector2(1, 0)
	p.ai_guard = true
	await frames(20)
	p.ai_jump = true
	await frames(4)
	p.ai_jump = false
	var surfed := false
	var fastest := 0.0
	for i in 300:
		await physics_frame
		surfed = surfed or p.surfing
		if p.surfing:
			fastest = maxf(fastest, p.flat_speed())
		if mon.hp < 10:
			break
	p.ai_move = Vector2.ZERO
	p.ai_guard = false
	check("shield surf down the hill reaches %.1f m/s (over top speed %.0f) and bumps a blob for 2" % [fastest, t.top_speed], surfed and fastest > t.top_speed and mon.hp == 8,
		"surfed %s, fastest %.1f m/s, blob hp %d" % [surfed, fastest, mon.hp])
	mon.queue_free()
	await frames(20)

	# 111. Spikes on its head: a pound onto it hurts you, homing skips it, and only landing on your shield pogos off it
	await _fresh_player(arena + Vector3(8, 0, 0))
	p.inventory.add("poleaxe")
	mon = await _dummy(arena + Vector3(0, 0.1, 0), "blob", true)
	await _hover(mon.global_position + Vector3(0, 3.0, 0))
	p.ai_attack = true
	for i in 40:
		await physics_frame
	var pound_hurt := p.hp < p.max_hp and mon.hp == 10
	await _fresh_player(arena + Vector3(0, 0, 4 * Poleaxe.REACH + 1.0)) # out of the air slash's reach
	p.inventory.add("poleaxe")
	p.ai_jump = true
	await frames(10)
	p.ai_jump = false
	p.ai_target = true
	p.ai_attack = true
	await frames(2)
	var no_homing := p.homing == null
	p.ai_target = false
	await frames(40)
	await _fresh_player(arena + Vector3(8, 0, 0))
	p.inventory.add("poleaxe")
	p.ai_guard = true
	await _hover(mon.global_position + Vector3(0, 3.0, 0))
	var bounced := false
	for i in 40:
		await physics_frame
		bounced = bounced or p.velocity.y > t.pogo_speed * 0.8
	p.ai_guard = false
	check("spiked head: a pound onto it hurts you, homing skips it, landing on your shield pogos off it (2 damage)", pound_hurt and no_homing and bounced and mon.hp == 8 and p.hp == p.max_hp,
		"pound hurt %s, homing skipped %s, surf bounced %s, blob hp %d, your hp %d" % [pound_hurt, no_homing, bounced, mon.hp, p.hp])
	mon.queue_free()

	# 112. Focus: locked on at the poleaxe's measure fills focus in about 2 s; the next attack is a flash step for 4
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
	mon = await _dummy(p.global_position + Vector3(0, 0.1, -(t.focus_near + t.focus_far) / 2.0))
	p.ai_target = true
	await frames(int(60.0 / t.focus_rate) + 6)
	var full := p.focus_meter >= 1.0
	p.ai_attack = true
	await frames(25)
	var gap := (mon.global_position - p.global_position)
	p.ai_target = false
	check("locked on %.0f-%.1f m away, focus fills in %.1f s; the flash step closes to tip range and does 4" % [t.focus_near, t.focus_far, 1.0 / t.focus_rate], full and p.poleaxe.move == "flash" and mon.hp == 6,
		"full %s, move %s, blob hp %d, gap %.1f m" % [full, p.poleaxe.move, mon.hp, Vector2(gap.x, gap.z).length()])
	mon.queue_free()

	# 113. Hit-cancel: a thrust that connects can go straight into the next before its recovery ends
	await _fresh_player(arena)
	p.inventory.add("poleaxe")
	mon = await _dummy(p.global_position + Vector3(0, 0.1, -1.6 * Poleaxe.REACH))
	p.ai_attack = true
	var cancelled_at := -1
	for i in 18:
		await physics_frame
		if p.poleaxe.move == "thrust" and not p.poleaxe._hit.is_empty() and p.poleaxe._elapsed() > Poleaxe.MOVES["thrust"]["to"]:
			p.ai_attack = true
		if p.poleaxe.move == "thrust2":
			cancelled_at = i
			break
	check("a thrust that hits cancels into the next before its %.2f s is up" % Poleaxe.MOVES["thrust"]["dur"], cancelled_at >= 0 and cancelled_at < int(Poleaxe.MOVES["thrust"]["dur"] * 60.0),
		"next thrust on frame %d" % cancelled_at)
	mon.queue_free()

	# 114. A wolf you keep in front of you still bites after its patience runs out (the old pack never bit)
	await _fresh_player(arena)
	var wolf := Monster.spawn(level, p.global_position + Vector3(0, 0.1, -3.5), "wolf")
	wolf.drop_heart = false
	p.facing = Vector3.FORWARD
	var bit_at := -1
	for i in int((Monster.WOLF_PATIENCE + 1.5) * 60.0):
		await physics_frame
		p.global_position.x = arena.x
		p.global_position.z = arena.z
		var to := wolf.global_position - p.global_position
		p.facing = Vector3(to.x, 0, to.z).normalized() # keep it in front
		if p.hp < p.max_hp:
			bit_at = i
			break
	check("a wolf kept in front of you bites within %.1f s anyway" % (Monster.WOLF_PATIENCE + 1.5), bit_at >= 0, "bit after %.1f s" % (bit_at / 60.0))
	wolf.queue_free()


## The Works: iron filling pits, doors held open, and Winch's racks, arm gears, screws and gear trains.
func _works_tests(arena: Vector3) -> void:
	var m: Dictionary = level.marks
	var t: Tuning = level.t

	# W1. Iron pushed into a pit it fits drops in flush with the floor and stays; you walk across it
	await _fresh_player(m["works_push_fill"])
	p.inventory.add("magnet")
	p.magnet_push = true
	var fill: IronCube = m["works_iron_fill"]
	var pit: Vector3 = m["works_pit"]
	await frames(150)
	p.inventory = Inventory.new()
	await frames(60)
	var top := fill.global_position.y + IronCube.H
	var over := Vector2(fill.global_position.x - pit.x, fill.global_position.z - pit.z).length()
	check("iron pushed into a pit as deep as it is tall (%.1f m) drops in flush and stays" % IronCube.H, fill.sunk and absf(top) < 0.02 and over < 0.05,
		"sunk %s, top at y %.2f, %.2f m off the pit" % [fill.sunk, top, over])
	await _fresh_player(Works.cell(7, 6) + Vector3.UP * 0.6)
	p.ai_move = Vector2(-1, 0)
	var low := 99.0
	for i in 120:
		await physics_frame
		low = minf(low, p.global_position.y)
		if p.global_position.x < Works.cell(4, 6).x:
			break
	p.ai_move = Vector2.ZERO
	check("you walk across iron filling a pit", p.global_position.x < Works.cell(4, 6).x and low > 0.3, "reached x %.1f, lowest y %.2f" % [p.global_position.x, low])
	check("iron standing on iron sunk in a pit conducts power; corners still don't",
		Power.touching(AABB(Vector3(0, -4.5, 0), Vector3(2, 4.5, 2)), AABB(Vector3(0, 0, 0), Vector3(2, 4.5, 2)))
		and not Power.touching(AABB(Vector3(0, -4.5, 0), Vector3(2, 4.5, 2)), AABB(Vector3(2, 0, 2), Vector3(2, 4.5, 2))), "")

	# W2. The far iron slides over the filled pit to the battery and powers the door. Pulled in from inside, it
	# takes the power with it, but the door stays open while it's in the doorway and closes once it's through
	var door: Gate = m["works_door"]
	var iron: IronCube = m["works_iron_a"]
	var x_cell := Works.cell(3, 6)
	await _fresh_player(m["works_push_a"])
	p.inventory.add("magnet")
	p.magnet_push = true
	var shut_first := not door.opened
	for i in 400:
		await physics_frame
		if p.global_position.x - iron.global_position.x > 9.0:
			p.global_position.x = iron.global_position.x + 6.0 # follow it, staying in range
		if iron.global_position.distance_to(x_cell) < 0.05 and door.opened:
			break
	var at_x := iron.global_position.distance_to(x_cell) < 0.05
	check("iron pushed over the filled pit to the battery powers the door", shut_first and at_x and door.opened and iron.powered,
		"shut at first %s, iron at the battery %s, door open %s" % [shut_first, at_x, door.opened])
	await _fresh_player(m["works_pad_stand"])
	p.inventory.add("magnet")
	var held := false
	var shut_after := false
	var hi := 0.0
	for i in 300:
		await physics_frame
		if door.opened and door.held and not door.powered and door.occupied() and not iron.powered:
			held = true
		if held and not door.opened:
			shut_after = true
		hi = maxf(hi, p.global_position.y)
	var inside := iron.global_position.distance_to(Works.cell(3, 2)) < 0.05
	check("unpowered, the door stays open while iron stands in the doorway", held, "")
	check("once the iron is through, the door closes", shut_after and inside and not door.opened, "iron in the room %s, door open %s" % [inside, door.opened])
	check("the iron powers the room's launch pad, which throws you onto the 6 m pillar", p.global_position.y > float(m["works_pillar_y"]),
		"peak %.1f, ended y %.1f" % [hi, p.global_position.y])

	# W3. A door held open by you: power gone while you stand in the doorway, it waits for you to step out
	var gate := Gate.make(level, arena + Vector3(0, 1.4, -6), Vector3(2, 4, 2), Color.GOLD)
	gate.wire()
	gate.remove_from_group("power_sink") # driven by hand here
	gate.set_powered(true)
	await _fresh_player(arena + Vector3(0, 0, -6))
	gate.set_powered(false)
	var kept := gate.opened
	await place(arena)
	gate.set_powered(false)
	check("a powered door stays open while you stand in it and closes when you step out", kept and not gate.opened, "held %s, open after %s" % [kept, gate.opened])
	gate.queue_free()

	# W4. Meshed gears turn opposite ways; three in a ring jam and the input can't be turned
	var ga := Gear.cog(level, arena + Vector3(0, -0.6, -8), 1.0, t)
	var gb := Gear.cog(level, arena + Vector3(2, -0.6, -8), 1.0, t)
	await frames(2)
	ga.turn(1.0)
	await frames(2)
	check("meshed gears turn opposite ways, tooth for tooth", absf(ga.wound - 1.0) < 0.001 and absf(gb.wound + 1.0) < 0.001, "%.2f and %.2f" % [ga.wound, gb.wound])
	var gc := Gear.cog(level, arena + Vector3(1, -0.6, -8 - sqrt(3.0)), 1.0, t)
	await frames(2)
	ga.turn(1.0)
	await frames(2)
	check("three gears meshed in a ring jam: the input can't be turned", absf(ga.wound - 1.0) < 0.001 and absf(gb.wound + 1.0) < 0.001 and absf(gc.wound) < 0.001 and ga.jams > 0,
		"wound %.2f, %.2f, %.2f, jams %d" % [ga.wound, gb.wound, gc.wound, ga.jams])
	for g in [ga, gb, gc]:
		g.queue_free()

	# W5. The Works gear train: one clutch gear between input and gate gear turns the gate the wrong way
	# (against its stop) while the flush screw only lets the input go one way: nothing moves. Crank the clutch
	# over so two gears sit in between, and the gate rises
	var inp: Gear = m["works_train_in"]
	var out: Gear = m["works_train_out"]
	var lock: Screw = m["works_train_lock"]
	var clutch: Rack = m["works_clutch"]
	var crank: Gear = m["works_clutch_crank"]
	var gate_y: float = (m["works_train_gate"] as Node3D).global_position.y
	inp.turn(-3.0)
	await frames(2)
	inp.turn(3.0)
	await frames(2)
	var stuck := absf(out.wound) < 0.001 and absf(lock.wound) < 0.001
	var stuck_at := "gate gear %.2f, screw %.2f" % [out.wound, lock.wound]
	crank.turn(20.0)
	await frames(2)
	var slid := absf(clutch.offset - clutch.travel) < 0.001
	inp.turn(-4.0)
	await frames(2)
	var rise: float = (m["works_train_gate"] as Node3D).global_position.y - gate_y
	check("with one gear between, the gate gear would turn against its stop and the flush screw won't sink: the input is stuck", stuck,
		stuck_at)
	check("the crank slides the clutch %.2f m; with two gears between, the input winds the gate up and the screw rises" % clutch.travel,
		slid and absf(out.wound - 4.0) < 0.01 and absf(lock.wound - 4.0) < 0.01 and absf(rise - 4.0 * t.gear_ratio) < 0.01,
		"clutch at %.2f, gate gear %.2f, screw %.2f, gate up %.2f m" % [clutch.offset, out.wound, lock.wound, rise])

	# W6. A rack slides its crank ratio per metre of rim: a full turn of the ferry's crank moves the deck
	# TAU * r * crank_ratio; standing on the deck pins it
	var deck: Rack = m["works_deck"]
	var dcrank: Gear = m["works_crank"]
	var x0 := deck.global_position.x
	var cx0 := dcrank.global_position.x
	dcrank.turn(TAU * dcrank.radius)
	await frames(2)
	var moved := deck.global_position.x - x0
	var want := TAU * dcrank.radius * t.crank_ratio
	check("a full turn of the crank slides the deck rack %.2f m and carries the crank" % want, absf(moved - want) < 0.01 and absf(dcrank.global_position.x - cx0 - want) < 0.01,
		"deck moved %.2f m, crank %.2f m" % [moved, dcrank.global_position.x - cx0])
	await _fresh_player(deck.global_position + Vector3(-2, 0.6, -2))
	await frames(10)
	var x1 := deck.global_position.x
	dcrank.turn(-2.0)
	await frames(2)
	check("standing on a rack pins it: its crank can't turn", absf(deck.global_position.x - x1) < 0.001, "deck moved %.2f m" % (deck.global_position.x - x1))
	await place(m["works_ferry"])
	dcrank.turn(-50.0) # back to the near bank
	await frames(2)

	# W7. The spider walks onto the deck and round the crank: the deck carries it across the 14 m pit
	await _fresh_player(m["works_ferry"])
	p.inventory.add("spider")
	p.facing = Vector3.RIGHT
	await _use("spider")
	var sp: Spider = p.spider
	var c := dcrank.global_position
	sp.global_position = Vector3(c.x, sp.global_position.y, c.z + 1.5)
	await frames(10)
	for i in 900:
		var rel := sp.global_position - dcrank.global_position
		rel.y = 0.0
		var tangent := Vector3(rel.z, 0, -rel.x).normalized()
		var dir := tangent + rel.normalized() * (1.5 - rel.length())
		p.ai_move = Vector2(dir.x, dir.z).limit_length(1.0)
		await physics_frame
		if deck.offset >= deck.travel - 0.001:
			break
	for i in 120: # keep circling (the deck is at its stop, so the crank won't turn) round to the crank's east side
		var rel := sp.global_position - dcrank.global_position
		rel.y = 0.0
		if rel.normalized().x > 0.9:
			break
		var tangent := Vector3(rel.z, 0, -rel.x).normalized()
		var dir := tangent + rel.normalized() * (1.5 - rel.length())
		p.ai_move = Vector2(dir.x, dir.z).limit_length(1.0)
		await physics_frame
	p.ai_move = Vector2(1, 0) # off the deck onto the far bank
	await frames(60)
	p.ai_move = Vector2.ZERO
	await frames(5)
	check("walked round the crank, the spider rides the deck across the pit", deck.offset >= deck.travel - 0.001 and sp.global_position.x > 222.3 and sp.global_position.y > 0.0,
		"deck at %.1f of %.1f m, spider at x %.1f y %.1f" % [deck.offset, deck.travel, sp.global_position.x, sp.global_position.y])
	await _use("spider")
	p.stow_spider()

	# W8. The arm gear: a notch (a quarter turn) swings the bridge from along the bank to across the 14 m chasm
	var arm: ArmGear = m["works_arm"]
	var lay := arm.arm_dir()
	arm.turn(Gear.STEP * 0.4) # less than half a notch: the arm stays put
	await frames(40)
	var stays := arm.arm_dir().dot(lay) > 0.999
	arm.turn(Gear.STEP * 0.6)
	await frames(60)
	check("a notch (%.2f m of rim, a quarter turn) swings the arm bridge across the chasm; less than half a notch doesn't" % Gear.STEP,
		lay.dot(Vector3.BACK) > 0.999 and stays and arm.arm_dir().dot(Vector3.RIGHT) > 0.999, "across %.2f" % arm.arm_dir().dot(Vector3.RIGHT))
	await _fresh_player(Vector3(246, 0.6, -20))
	p.ai_move = Vector2(1, 0)
	for i in 150:
		await physics_frame
		if p.global_position.x > 259.5:
			break
	p.ai_move = Vector2.ZERO
	check("you walk the arm bridge to the island", p.global_position.x > float(m["works_island_x"]) and p.global_position.y > -0.5,
		"ended x %.1f y %.1f" % [p.global_position.x, p.global_position.y])

	# W9. Screws: flush, they're floor; each notch raises one screw_notch and lifts you; flush won't sink, top won't rise
	var sl: Screw = m["works_screw_low"]
	var sh: Screw = m["works_screw_high"]
	await _fresh_player(sl.global_position + Vector3.UP * 0.6)
	var y0 := p.global_position.y
	sl.turn(-Gear.STEP)
	await frames(2)
	var no_sink := sl.height_notch() == 0
	sl.turn(Gear.STEP)
	await frames(40)
	var lift1 := p.global_position.y - y0
	check("a screw rises one notch (%.1f m) per notch it turns, lifting you; flush, it can't sink" % t.screw_notch,
		no_sink and sl.height_notch() == 1 and absf(sl.height() - t.screw_notch) < 0.01 and absf(lift1 - t.screw_notch) < 0.15,
		"notch %d, height %.2f, lifted you %.2f m" % [sl.height_notch(), sl.height(), lift1])
	sl.turn(Gear.STEP * 5.0)
	sh.turn(Gear.STEP * 9.0)
	await frames(90)
	check("wound to their tops the screws are 2 m steps up the 6 m ledge", sl.height_notch() == 2 and sh.height_notch() == 4
		and absf(sl.height() - 2.0 * t.screw_notch) < 0.01 and absf(float(m["works_ledge_y"]) - sh.height() - 2.0) < 0.01,
		"low %.1f m, high %.1f m, ledge %.1f m" % [sl.height(), sh.height(), float(m["works_ledge_y"])])
	await _fresh_player(arena)


## A powers-book monster that holds still for the test: no AI, no drop.
func _foe(kind: String, pos: Vector3, hp := 10) -> Monster:
	var mon := PowersYard.foe(level, kind, pos)
	mon.drop_heart = false
	mon.home = pos
	mon.stun = 60.0
	await physics_frame
	mon.max_hp = hp
	mon.hp = hp
	mon.state = "move"
	return mon

func _hp(mon: Monster) -> int:
	return mon.hp if is_instance_valid(mon) else 0

## Power Combat Sketchbook II in the game: the Umbra twin, Lodestone knights, ember and light, bomb flowers.
func _powers_tests() -> void:
	var t: Tuning = level.t
	var m: Dictionary = level.marks
	var dark: Vector3 = m["power_twin_room"] # deep in the roofed shade room
	var court: Vector3 = m["power_bombs_room"] # the open bomb court, empty while the tests run

	# P1. Umbra mirrors your stick, not your motion: pressed into a wall, you still steer it
	await _fresh_player(Vector3(157.3, 0.6, -36))
	var u := _summon_facing_north()
	await frames(2)
	var u0 := u.global_position
	var p0 := p.global_position
	p.ai_move = Vector2(1, 0) # into the east wall
	await frames(60)
	p.ai_move = Vector2.ZERO
	var umoved := u0.x - u.global_position.x
	var pmoved := p.global_position.x - p0.x
	check("pushing into a wall, Umbra still mirrors your stick: it floats %.1f m in 1 s" % umoved,
		pmoved < 0.5 and umoved > 5.0 and not u.lit, "you moved %.2f m, Umbra %.1f m, lit %s" % [pmoved, umoved, u.lit])

	# P2. Shades in the dark: the poleaxe passes through, Umbra's greatsword cuts them
	await _fresh_player(dark)
	p.inventory.add("poleaxe")
	var sh := await _foe("shade", p.global_position + Vector3(0, 0.1, -1.6), 4)
	for k in 3:
		p.ai_attack = true
		await frames(45) # one thrust at a time, no combo
	var after_you := _hp(sh)
	u = _summon_facing_north()
	await frames(2)
	var swings := 0
	for k in 3:
		if not is_instance_valid(sh):
			break
		sh.global_position = u.global_position + Vector3(0, 0.1, -1.4)
		sh.velocity = Vector3.ZERO
		p.ai_attack = true
		swings += 1
		await frames(45)
	check("in the dark a shade takes 0 from 3 poleaxe thrusts and dies to %d of Umbra's greatsword swings" % swings,
		after_you == 4 and not is_instance_valid(sh) and swings == 2, "hp %d after your thrusts, alive after Umbra %s" % [after_you, is_instance_valid(sh)])

	# P3. The candle exposes a shade: your poleaxe hurts it
	await _fresh_player(dark)
	p.inventory.add("poleaxe")
	sh = await _foe("shade", p.global_position + Vector3(0, 0.1, -1.6), 4)
	await frames(2)
	var hidden := not (sh as Shade).exposed
	p.set_candle(true)
	await frames(3)
	var shown := (sh as Shade).exposed
	p.ai_attack = true
	await frames(30)
	check("candle light exposes a shade and the poleaxe hurts it", hidden and shown and _hp(sh) < 4,
		"dark %s, exposed %s, hp %d" % [hidden, shown, _hp(sh)])
	if is_instance_valid(sh):
		sh.queue_free()

	# P4. Pincer: you and Umbra striking the same monster together add t.pincer_bonus
	var dealt := []
	for with_twin in [false, true]:
		await _fresh_player(dark + Vector3(-6, 0, 0))
		p.inventory.add("poleaxe")
		u = _summon_facing_north()
		p.ai_move = Vector2(1, 0) # you go east, it goes west: an enemy fits between
		await frames(15)
		p.ai_move = Vector2.ZERO
		await frames(30)
		var ux := u.global_position
		if not with_twin:
			p.toggle_umbra()
		p.facing = Vector3.LEFT # facing Umbra, so it faces you
		var mid := (p.global_position + ux) / 2.0
		mid.y = p.global_position.y + 0.1
		var mon := await _foe("blob", mid, 20)
		p.ai_attack = true
		await frames(40)
		dealt.append(20 - _hp(mon))
		mon.queue_free()
	var bonus: int = dealt[1] - dealt[0] - Umbra.SWING_DAMAGE
	check("pincer: you and Umbra hitting one monster together add %d" % int(t.pincer_bonus), bonus == int(t.pincer_bonus),
		"you alone %d, with Umbra %d" % [dealt[0], dealt[1]])

	# P5. Iron knight: its shield stops a thrust; pulled with the magnet it slides to you, shield down
	await _fresh_player(court)
	p.inventory.add("poleaxe")
	var kn := await _foe("knight", p.global_position + Vector3(0, 0.1, -1.8))
	kn.look_at(p.global_position + Vector3(0, 0.1, 0), Vector3.UP) # shield toward you
	p.ai_attack = true
	await frames(40)
	var blocked := _hp(kn) == 10
	kn.queue_free()
	await _fresh_player(court)
	p.inventory.add("poleaxe")
	p.inventory.add("magnet")
	kn = await _foe("knight", p.global_position + Vector3(8, 0.1, 0))
	var k0: float = (kn.global_position - p.global_position).length()
	p.ai_target = true
	await frames(60)
	var k1: float = (kn.global_position - p.global_position).length()
	var open := (kn as IronKnight).shield_down > 0.0
	p.ai_attack = true
	await frames(30)
	p.ai_target = false
	check("magnet pull: an iron knight %.0f m away is pulled %.1f m to you, shield down, and a thrust lands" % [k0, k0 - k1],
		blocked and k0 - k1 > 5.0 and open and _hp(kn) < 10, "shield blocked first %s, ended %.1f m away, open %s, hp %d" % [blocked, k1, open, _hp(kn)])
	kn.queue_free()

	# P6. Push: the knight is blown away
	await _fresh_player(court)
	p.inventory.add("magnet")
	p.magnet_push = true
	kn = await _foe("knight", p.global_position + Vector3(3, 0.1, 0))
	k0 = (kn.global_position - p.global_position).length()
	p.ai_target = true
	await frames(40)
	p.ai_target = false
	k1 = (kn.global_position - p.global_position).length()
	check("magnet push blows an iron knight %.1f m away (1 damage)" % (k1 - k0), k1 - k0 > 4.0 and _hp(kn) == 9, "%.1f m to %.1f m, hp %d" % [k0, k1, _hp(kn)])
	kn.queue_free()

	# P7. A pushed iron block ploughs the monster in its way
	await _fresh_player(court + Vector3(2, 0, -2.5))
	p.inventory.add("magnet")
	p.magnet_push = true
	var cube := IronCube.make(level, Vector3(p.global_position.x + 6.0, 0, p.global_position.z))
	var bl := await _foe("blob", cube.global_position + Vector3(2.6, 0.6, 0))
	var b0 := bl.global_position
	await frames(90)
	var shoved: float = (bl.global_position - b0).x if is_instance_valid(bl) else 99.0
	check("a pushed iron block ploughs a blob %.1f m on (1 damage, not stopped by it)" % shoved, shoved > 3.0 and _hp(bl) < 10 and cube.global_position.x > b0.x - 2.6,
		"blob moved %.1f m, hp %d, block at x %.1f" % [shoved, _hp(bl), cube.global_position.x])
	cube.queue_free()
	if is_instance_valid(bl):
		bl.queue_free()

	# P8. Bombs: shorter throw, less momentum. Measured at a run, against the old numbers.
	var dists := []
	var saved := [t.bomb_throw_speed, t.bomb_throw_up, t.bomb_throw_keep, t.bomb_friction]
	for old in [true, false]:
		if old:
			t.bomb_throw_speed = 7.0
			t.bomb_throw_up = 5.0
			t.bomb_throw_keep = 0.3
			t.bomb_friction = 20.0
		else:
			t.bomb_throw_speed = saved[0]
			t.bomb_throw_up = saved[1]
			t.bomb_throw_keep = saved[2]
			t.bomb_friction = saved[3]
		await _fresh_player(Vector3(122.5, 0.6, 40))
		var bf := await _pull_bomb()
		bf.queue_free()
		var held := p.carrying
		p.ai_move = Vector2(0, -1) # the way you face
		await frames(50) # at top speed
		var from := p.global_position
		p.ai_context = true
		await frames(2)
		p.ai_move = Vector2.ZERO
		await frames(70)
		dists.append(Vector2(held.global_position.x - from.x, held.global_position.z - from.z).length())
		await frames(90)
	check("a bomb thrown at a run stops %.1f m ahead (was %.1f m)" % [dists[1], dists[0]], dists[1] < 6.0 and dists[1] < dists[0] * 0.7,
		"old %.1f m, now %.1f m" % [dists[0], dists[1]])

	# P9. Bat a bomb with the poleaxe: it flies and goes off on the first monster it hits
	await _fresh_player(court)
	p.inventory.add("poleaxe")
	var bomb := Bomb.new()
	level.add_child(bomb)
	bomb.set_down(p.global_position + Vector3(0, -0.2, -1.6))
	var target := await _foe("blob", p.global_position + Vector3(0, 0.1, -8.0)) # out of the doubled poleaxe's reach (6.5 m)
	await frames(3)
	var bomb_at := bomb.global_position
	p.ai_attack = true
	var top_speed := 0.0
	var gone_at := -1.0
	var flew := 0.0
	for i in 90:
		await physics_frame
		if not is_instance_valid(bomb) or bomb._exploded:
			gone_at = i / 60.0
			break
		flew = (bomb.global_position - bomb_at).length()
		top_speed = maxf(top_speed, Vector2(bomb.velocity.x, bomb.velocity.z).length())
	check("a thrust bats a bomb at %.0f m/s and it goes off on the blob %.1f m on, before its fuse" % [top_speed, flew],
		top_speed > t.bomb_bat_speed - 1.0 and gone_at > 0.0 and _hp(target) < 10, "flew at %.1f m/s, went off after %.2f s, blob hp %d" % [top_speed, gone_at, _hp(target)])
	await frames(20)
	if is_instance_valid(target):
		target.queue_free()

	# P10. Bomb jump: pound onto a bomb and it throws you up, unhurt
	await _fresh_player(court)
	bomb = Bomb.new()
	level.add_child(bomb)
	bomb.set_down(p.global_position + Vector3(0, -0.2, 0))
	var ground := p.global_position.y
	p.ai_jump = true
	await frames(10)
	p.ai_jump = false
	p.ai_attack = true # in the air, no lock-on: ground pound
	var peak := ground
	var launched := false
	for i in 120:
		await physics_frame
		peak = maxf(peak, p.global_position.y)
		launched = launched or p.velocity.y > t.bomb_jump_speed - 2.0
	check("bomb jump: pounding onto a bomb throws you %.1f m up, unhurt" % (peak - ground), launched and peak - ground > 5.5 and p.hp == p.max_hp,
		"peak %.1f m, hp %d" % [peak - ground, p.hp])
	await frames(30)

	# P11. A plated brute: only blasts crack its plates
	await _fresh_player(court)
	p.inventory.add("poleaxe")
	var brute := await _foe("plated", p.global_position + Vector3(0, 0.1, -1.8), 12)
	var spot := brute.global_position
	p.ai_attack = true
	await frames(45)
	var clank := _hp(brute) == 12
	var plates := [(brute as PlatedBrute).plates]
	for k in 2:
		brute.global_position = spot
		brute.velocity = Vector3.ZERO
		var b := Bomb.new()
		level.add_child(b)
		b.global_position = spot + Vector3(0, 0, -2.4) # past it, out of your reach
		await physics_frame
		b.explode()
		await frames(30)
		plates.append((brute as PlatedBrute).plates)
	brute.global_position = spot
	brute.velocity = Vector3.ZERO
	var before := _hp(brute)
	p.ai_attack = true
	await frames(45)
	check("plated brute: the poleaxe clanks off, each blast cracks a plate, then the poleaxe hurts it",
		clank and plates == [2, 1, 0] and _hp(brute) < before and p.hp == p.max_hp, "clank %s, plates %s, hp %d -> %d" % [clank, plates, before, _hp(brute)])
	if is_instance_valid(brute):
		brute.queue_free()

	# P12. Fire walks across 1 m grass patches: one catches its neighbour after t.fire_spread_delay
	await _fresh_player(court)
	var row := Burnable.field(level, Vector3(court.x + 4, 0, court.z + 4), 8, 1)
	await physics_frame
	row[0].ignite()
	var next_at := -1.0
	var last_at := -1.0
	for i in 600:
		await physics_frame
		if next_at < 0.0 and row[1].burning:
			next_at = (i + 1) / 60.0
		if row[7].burning or row[7].burnt:
			last_at = (i + 1) / 60.0
			break
	check("a burning 1 m grass patch lights its neighbour in %.2f s; an 8 m row burns end to end in %.1f s" % [next_at, last_at],
		next_at >= t.fire_spread_delay and next_at < t.fire_spread_delay + 0.3 and last_at > 3.0, "neighbour %.2f s, row %.1f s" % [next_at, last_at])
	for g in row:
		g.queue_free()

	# P13. Your fire attack lights the grass you stand in: it burns a monster in it, never you
	await _fresh_player(court)
	p.inventory.add("poleaxe")
	var lawn := Burnable.field(level, Vector3(court.x - 3, 0, court.z - 6), 6, 8)
	var burner := await _foe("blob", p.global_position + Vector3(0, 0.1, -4))
	p.set_candle(true)
	p.ai_attack = true
	await frames(240)
	var burnt := 0
	for g in lawn:
		if g.burning or g.burnt:
			burnt += 1
	check("fighting in your own fire: %d of 48 patches burn, a blob in them takes %d, you take 0" % [burnt, 10 - _hp(burner)],
		burnt > 30 and _hp(burner) < 10 and p.hp == p.max_hp, "burnt %d, blob hp %d, your hp %d" % [burnt, _hp(burner), p.hp])
	for g in lawn:
		g.queue_free()
	if is_instance_valid(burner):
		burner.queue_free()
	await _fresh_player(court)

## A fresh player for the liquid tests: sober, not in honey.
func _liquid_player(pos: Vector3) -> void:
	await _fresh_player(pos)
	var c := Coat.on(p)
	if c != null:
		c.drunk = 0.0
		c.in_honey = false
		c.honey_t = 0.0

## Put a pot of kind in the player's hands.
func _hand_pot(kind: String) -> Pot:
	var pt := Pot.make(level, p.global_position + Vector3.UP * 1.0, level.t, kind)
	await physics_frame
	p.held_pot = pt
	pt.hold(p)
	await physics_frame
	return pt

## Spilled puddles from a test (not the level's pools) go away.
func _mop() -> void:
	for n in get_nodes_in_group("puddles"):
		if not (n as Puddle).permanent:
			n.queue_free()
	await physics_frame

## Throw what you hold with the context button and wait for it to break. Returns where it broke.
func _release_and_wait(pt: Pot, secs := 1.5) -> Vector3:
	var landed := {}
	pt.smashed.connect(func(at: Vector3) -> void: landed["at"] = at)
	p.ai_context = true
	for i in int(secs * 60.0):
		await physics_frame
		if landed.has("at"):
			break
	return landed.get("at", Vector3.INF)

## Honey & Wine (the Cellar): pots, puddles, honey and rock candy, the swap charm, wine, water, crates.
func _cellar_tests() -> void:
	var t: Tuning = level.t
	var m: Dictionary = level.marks
	var L := Vector3(-95, 0.6, -95) # open floor, nothing else within 20 m

	# 115. A pot carried under the hive fills with honey
	await _liquid_player(L)
	var hive := Spout.make(level, Vector3(L.x, 3.0, L.z), "honey")
	var pot := Pot.make(level, Vector3(L.x, 0.4, L.z - 1.2), t)
	await frames(3)
	p.ai_context = true
	await frames(5)
	check("context picks up a pot, and under the hive it fills with honey", p.held_pot == pot and pot.liquid == "honey",
		"held %s, liquid '%s'" % [p.held_pot == pot, pot.liquid])
	hive.queue_free()

	# 116. Throw distances: standing still a full pot is lobbed about 5 m; at a run it flies much further
	var from := p.global_position
	var at := await _release_and_wait(pot)
	var lob := Vector2(at.x - from.x, at.z - from.z).length()
	check("standing still, a full pot is lobbed 4-5.5 m (%.0f m/s, up %.0f)" % [t.pot_throw_speed, t.pot_throw_up], lob > 4.0 and lob < 5.5, "%.1f m" % lob)
	await _mop()
	await _liquid_player(L + Vector3(-5, 0, 10))
	pot = await _hand_pot("water")
	p.ai_move = Vector2(1, 0)
	await frames(80)
	var run_speed := p.flat_speed()
	from = p.global_position
	at = await _release_and_wait(pot)
	p.ai_move = Vector2.ZERO
	var far := Vector2(at.x - from.x, at.z - from.z).length()
	check("thrown at a run (%.0f m/s), a pot flies at least 15 m" % run_speed, far >= 15.0 and far < 21.0, "%.1f m" % far)
	await _mop()
	await _liquid_player(L)
	pot = await _hand_pot("")
	p.ai_context = true
	await frames(10)
	check("standing still, an empty pot is set down in front of you", is_instance_valid(pot) and pot.holder == null and not pot.flying
		and p.held_pot == null and (pot.global_position - p.global_position).dot(Vector3.FORWARD) > 0.8, "")
	if is_instance_valid(pot):
		pot.queue_free()

	# 117. Liquid stays where the level plans: a puddle of fixed size where it lands
	await _liquid_player(L + Vector3(0, 0, 12))
	Liquids.spill(level, "water", Vector3(L.x, 1.0, L.z))
	await frames(2)
	var found: Array = []
	for n in get_nodes_in_group("puddles"):
		if not (n as Puddle).permanent:
			found.append(n)
	var one_ok: bool = found.size() == 1 and absf((found[0] as Puddle).radius - Liquids.RADIUS["water"]) < 0.01 \
		and Vector2((found[0] as Puddle).global_position.x - L.x, (found[0] as Puddle).global_position.z - L.z).length() < 0.3
	Liquids.spill(level, "water", Vector3(L.x + 0.5, 1.0, L.z))
	await frames(2)
	var still := 0
	for n in get_nodes_in_group("puddles"):
		if not (n as Puddle).permanent and not n.is_queued_for_deletion():
			still += 1
	check("a spill lies where it lands as one %.1f m puddle, and a second on top doesn't spread it" % Liquids.RADIUS["water"],
		one_ok and still == 1 and absf((found[0] as Puddle).radius - Liquids.RADIUS["water"]) < 0.01, "%d puddles, then %d" % [found.size(), still])
	await _mop()

	# 118. Honey: normal size it holds you to honey_slow and a low jump; small it holds you fast
	await _liquid_player(L)
	var honey := Puddle.make(level, "honey", Vector3(L.x, 0, L.z), 6.0)
	await frames(2)
	p.ai_move = Vector2(1, 0)
	await frames(60)
	var big_speed := p.flat_speed()
	p.ai_move = Vector2.ZERO
	await frames(30)
	var y0 := p.global_position.y
	var top := y0
	p.ai_jump = true
	for i in 50:
		await physics_frame
		top = maxf(top, p.global_position.y)
	p.ai_jump = false
	check("normal size in honey you move at most %.0f m/s and jump under 1 m" % t.honey_slow, big_speed > 2.0 and big_speed <= t.honey_slow + 0.05 and top - y0 < 1.0,
		"%.1f m/s, jump %.2f m" % [big_speed, top - y0])
	await _liquid_player(L)
	p.set_small(true)
	await frames(30)
	var small_at := p.global_position
	p.ai_move = Vector2(1, 0)
	await frames(60)
	p.ai_move = Vector2.ZERO
	p.ai_jump = true
	top = p.global_position.y
	for i in 30:
		await physics_frame
		top = maxf(top, p.global_position.y)
	p.ai_jump = false
	var moved := Vector2(p.global_position.x - small_at.x, p.global_position.z - small_at.z).length()
	check("small, honey holds you fast: no steps, no jump", moved < 0.1 and top - small_at.y < 0.1, "moved %.2f m, rose %.2f m" % [moved, top - small_at.y])
	p.set_small(false, true)

	# 119. Honey draws a blob from 9 m and holds it, even with you close; a brute in honey is slowed
	await _liquid_player(L + Vector3(0, 0, 25))
	var blob := Monster.spawn(level, Vector3(L.x + 9.0, 0.6, L.z), "blob")
	blob.drop_heart = false
	var drawn := -1.0
	for i in 360:
		await physics_frame
		var bc := Coat.on(blob)
		if bc != null and bc.in_honey and Vector2(blob.velocity.x, blob.velocity.z).length() < 0.05:
			drawn = i / 60.0
			break
	p.teleport(blob.global_position + Vector3(0, 0, 3.0))
	var held_at := blob.global_position
	await frames(90)
	var blob_moved := Vector2(blob.global_position.x - held_at.x, blob.global_position.z - held_at.z).length()
	check("honey %.0f m away draws a blob, and it stays stuck with you 3 m away" % 9.0, drawn > 0.0 and blob_moved < 0.3 and Coat.on(blob).honey,
		"stuck after %.1f s, then moved %.2f m, coated %s" % [drawn, blob_moved, Coat.on(blob).honey if Coat.on(blob) != null else false])
	blob.queue_free()
	await _liquid_player(L + Vector3(4.5, 0, 0))
	var brute := Monster.spawn(level, Vector3(L.x - 3.0, 0.9, L.z), "brute")
	brute.drop_heart = false
	await frames(30)
	var b0 := brute.global_position
	await frames(60)
	var brute_speed := Vector2(brute.global_position.x - b0.x, brute.global_position.z - b0.z).length()
	check("a brute in honey is slowed to %.1f m/s" % Liquids.MONSTER_HONEY_SPEED, brute_speed > 0.3 and brute_speed < Liquids.MONSTER_HONEY_SPEED + 0.1, "%.2f m/s" % brute_speed)
	brute.queue_free()
	honey.queue_free()
	await _mop()

	# 120. Honey on a blob plus heat: rock candy. The swap charm trades places with it; you keep your speed
	await _liquid_player(L + Vector3(0, 0, 12))
	p.inventory.add("swap")
	var brazier := Brazier.make(level, Vector3(L.x + 2.0, 0, L.z), true)
	var dummy := await _dummy(Vector3(L.x, 0.6, L.z))
	var early := p.inventory.use(p.inventory.slots.find("swap"), p)
	var splat := Pot.make(level, dummy.global_position + Vector3(0, 2.0, 0), t, "honey")
	splat.throw(Vector3.DOWN * 4.0)
	var candy_t := -1.0
	for i in 120:
		await physics_frame
		if Coat.is_candy(dummy):
			candy_t = i / 60.0
			break
	check("a honey pot coats a blob, and a lit brazier 2 m away hardens it into rock candy (%.1f s of heat) within a second" % t.candy_heat_time,
		not early and candy_t >= t.candy_heat_time and candy_t <= 1.0, "swap refused before: %s, candy after %.2f s" % [not early, candy_t])
	p.ai_move = Vector2(0, -1)
	await frames(30)
	var pv := p.velocity
	var was := p.global_position
	var candy_at := dummy.global_position
	await _use("swap")
	var swapped: bool = Vector2(p.global_position.x - candy_at.x, p.global_position.z - candy_at.z).length() < 0.6 \
		and Vector2(dummy.global_position.x - was.x, dummy.global_position.z - was.z).length() < 1.0
	var kept := Vector2(p.velocity.x - pv.x, p.velocity.z - pv.z).length()
	check("swap charm: you and the rock candy trade places and each keeps its own velocity", swapped and kept < 1.5
		and Vector2(dummy.velocity.x, dummy.velocity.z).length() < 0.1, "swapped %s, your speed %.1f -> %.1f m/s" % [swapped, Vector2(pv.x, pv.z).length(), p.flat_speed()])
	p.ai_move = Vector2.ZERO
	Liquids.spill(level, "water", dummy.global_position + Vector3.UP * 1.0)
	await frames(2)
	check("water washes rock candy off", not Coat.is_candy(dummy), "")
	dummy.queue_free()
	brazier.queue_free()
	await _mop()

	# 121. Sober monsters don't step off a ledge
	await _liquid_player(L)
	var plat := level.box(Vector3(L.x, 1.5, L.z - 8.0), Vector3(6, 3, 6), Basis(), Color(0.5, 0.5, 0.5)) as StaticBody3D
	await frames(2)
	var perch := Monster.spawn(level, Vector3(L.x, 3.6, L.z - 8.0), "blob")
	perch.drop_heart = false
	await frames(180)
	check("a sober blob chasing you stops at the edge of a 3 m drop", is_instance_valid(perch) and perch.global_position.y > 2.5, "y %.1f" % (perch.global_position.y if is_instance_valid(perch) else -99.0))
	if is_instance_valid(perch):
		perch.queue_free()
	plat.queue_free()

	# 122. Last call: wine on the bridge makes the brute drunk and it staggers off; water washes the wine away
	await _liquid_player(m["cellar_bridge"])
	var bridge_brute := Monster.spawn(level, m["cellar_bridge_mid"], "brute")
	bridge_brute.drop_heart = false
	bridge_brute.set_meta("leash", 5.0)
	await frames(30)
	p.teleport(m["cellar_bridge_end"])
	p.facing = Vector3.LEFT
	await frames(5)
	pot = await _hand_pot("wine")
	var wine_at := await _release_and_wait(pot)
	var fell := -1.0
	for i in 720:
		await physics_frame
		if not is_instance_valid(bridge_brute) or bridge_brute.global_position.y < -1.0:
			fell = i / 60.0
			break
	check("wine lobbed onto the bridge: the brute drinks, staggers and falls off within 12 s", fell >= 0.0, "fell after %.1f s" % fell)
	var wine_left := func() -> int:
		var n := 0
		for pd in get_nodes_in_group("puddles"):
			if (pd as Puddle).kind == "wine" and not (pd as Puddle).permanent and not pd.is_queued_for_deletion() and (pd as Puddle).touches(wine_at, 1.0):
				n += 1
		return n
	var before_wash: int = wine_left.call()
	p.teleport(m["cellar_bridge_end"])
	p.facing = Vector3.LEFT
	await frames(5)
	pot = await _hand_pot("water")
	await _release_and_wait(pot)
	await frames(2)
	check("a pot of water washes the wine off the bridge", before_wash == 1 and wine_left.call() == 0, "wine puddles %d then %d" % [before_wash, wine_left.call()])
	if is_instance_valid(bridge_brute):
		bridge_brute.queue_free()
	await _mop()

	# 123. Fire runs along wine: a brazier lights the first puddle and three in a row burn, then the grass past them
	await _liquid_player(L + Vector3(0, 0, 15))
	var wines: Array[Puddle] = []
	for k in 3:
		wines.append(Puddle.make(level, "wine", Vector3(L.x + k * 3.0, 0, L.z), 1.8))
	var grass := Burnable.make(level, "grass", Vector3(L.x + 8.0, 0, L.z), Vector3(2, 0.3, 2))
	var fire := Brazier.make(level, Vector3(L.x - 4.0, 0, L.z), true)
	var burned := [false, false, false]
	for i in 240:
		await physics_frame
		for k in 3:
			if is_instance_valid(wines[k]) and wines[k].burning:
				burned[k] = true
	check("a lit brazier lights wine %.0f m away and fire runs along three puddles to the grass" % (4.0 - 1.8), burned == [true, true, true] and (grass.burning or grass.burnt),
		"burned %s, grass %s" % [burned, grass.burning or grass.burnt])
	grass.queue_free()
	fire.queue_free()
	await _mop()

	# 124. Water puts fire out: burning grass, a brazier, the candle hat; wet grass and wet ground won't take fire or wine
	await _liquid_player(L)
	var g2 := Burnable.make(level, "grass", Vector3(L.x, 0, L.z - 4.0), Vector3(2, 0.3, 2))
	g2.ignite()
	var br2 := Brazier.make(level, Vector3(L.x + 3.0, 0, L.z - 4.0), true)
	await frames(2)
	Liquids.spill(level, "water", Vector3(L.x + 1.5, 0.5, L.z - 4.0))
	await frames(2)
	var out := not g2.burning and not br2.lit
	g2.heat(1.0)
	Liquids.place(level, "wine", Vector3(L.x + 1.5, 0, L.z - 4.0), Liquids.RADIUS["wine"])
	await frames(2)
	var wine_on_wet := 0
	for n in get_nodes_in_group("puddles"):
		if (n as Puddle).kind == "wine" and not (n as Puddle).permanent:
			wine_on_wet += 1
	check("a water splash puts out burning grass and a brazier; wet, the grass won't catch and the ground won't take wine",
		out and not g2.burning and wine_on_wet == 0, "out %s, grass relit %s, wine puddles %d" % [out, g2.burning, wine_on_wet])
	p.inventory.add("candle")
	p.set_candle(true)
	p.teleport(Vector3(L.x + 4.2, 0.6, L.z - 4.0))
	await frames(10)
	check("the candle lights the doused brazier again", br2.lit, "")
	p.teleport(Vector3(L.x, 0.6, L.z + 6.0))
	await frames(5)
	Liquids.spill(level, "water", p.global_position + Vector3(0.6, 0.6, 0))
	await frames(2)
	var splashed_out := not p.candle_lit
	p.set_candle(true)
	var basin_pool := Puddle.pool(level, "water", AABB(Vector3(L.x - 1.5, 0, L.z + 10.0), Vector3(3, 0.3, 3)))
	p.teleport(Vector3(L.x, 0.6, L.z + 11.5))
	await frames(5)
	check("the candle hat goes out when you're splashed and when you wade into water", splashed_out and not p.candle_lit,
		"splashed %s, waded %s" % [splashed_out, not p.candle_lit])
	basin_pool.queue_free()
	g2.queue_free()
	br2.queue_free()
	await _mop()

	# 125. Crates: one catches from burning grass and burns away; water saves another; a crate casts a shadow
	await _liquid_player(L + Vector3(0, 0, 12))
	var c1 := Crate.make(level, Vector3(L.x + 4.0, 0, L.z), t)
	var g3 := Burnable.make(level, "grass", Vector3(L.x + 6.0, 0, L.z), Vector3(2, 0.3, 2))
	var c2 := Crate.make(level, Vector3(L.x - 4.0, 0, L.z), t)
	await frames(2)
	g3.ignite()
	c2.ignite()
	var caught := false
	for i in 60:
		await physics_frame
		caught = caught or (is_instance_valid(c1) and c1.burning)
	Liquids.spill(level, "water", c2.global_position + Vector3.UP * 1.3)
	await frames(2)
	var saved := is_instance_valid(c2) and not c2.burning
	c2.heat(1.0)
	await frames(int(t.crate_burn * 60.0))
	check("a crate next to burning grass catches and burns away in %.0f s" % t.crate_burn, caught and not is_instance_valid(c1), "caught %s, gone %s" % [caught, not is_instance_valid(c1)])
	check("water puts a burning crate out, and wet it won't catch again", saved and is_instance_valid(c2) and not c2.burning, "")
	c2.queue_free()
	g3.queue_free()
	var lamp: Brazier = m["cellar_candy_brazier"]
	var spot := Vector3(lamp.global_position.x + 3.5, 0.5, lamp.global_position.z)
	var lit_before := Lighting.is_lit(spot, level)
	var shade := Crate.make(level, Vector3(lamp.global_position.x + 1.8, 0, lamp.global_position.z), t)
	await frames(3)
	check("a crate blocks light: the spot behind it is in shadow", lit_before and not Lighting.is_lit(spot, level, [p.get_rid()]), "lit before %s" % lit_before)
	shade.queue_free()
	await _mop()

	# 126. Pots and crates smash from a poleaxe hit; a bomb blast smashes a pot
	await _liquid_player(L)
	p.inventory.add("poleaxe")
	var sp := Pot.make(level, Vector3(L.x, 0.4, L.z - 1.6), t, "honey")
	await frames(10)
	p.ai_attack = true
	await frames(24)
	var spilt := 0
	for n in get_nodes_in_group("puddles"):
		if (n as Puddle).kind == "honey" and not (n as Puddle).permanent:
			spilt += 1
	check("a poleaxe thrust smashes a pot and it spills where it stood", not is_instance_valid(sp) and spilt == 1, "honey puddles %d" % spilt)
	await _mop()
	var box := Crate.make(level, Vector3(L.x, 0, L.z - 2.3), t)
	await frames(10)
	p.ai_attack = true
	await frames(30)
	check("a poleaxe thrust smashes a crate", not is_instance_valid(box), "")
	var bp := Pot.make(level, Vector3(L.x + 6.0, 0.4, L.z), t)
	await frames(5)
	var bomb := Bomb.new()
	level.add_child(bomb)
	bomb.global_position = bp.global_position + Vector3(1.0, 0.3, 0)
	bomb.explode()
	await frames(2)
	check("a bomb blast smashes a pot", not is_instance_valid(bp), "")
	await _mop()

	# 127. Raft: one pot of water fills the dry channel; the crate pushed in floats and carries you across
	var channel: Basin = m["cellar_raft_channel"]
	var crate: Crate = m["cellar_raft_crate"]
	await _liquid_player(Vector3(147.0, 0.6, -132.0))
	p.facing = Vector3.RIGHT
	pot = await _hand_pot("water")
	await _release_and_wait(pot)
	await frames(5)
	check("one pot of water fills the dry 14 x 12 x 3 m channel to the brim", channel.kind == "water" and channel.water != null, "full of '%s'" % channel.kind)
	await _liquid_player(m["cellar_raft_push"])
	p.ai_move = Vector2(1, 0)
	for i in 300:
		await physics_frame
		if crate.global_position.x > 149.3:
			break
	p.ai_move = Vector2.ZERO
	await frames(90)
	var surface := channel.water.surface() if channel.water != null else 0.0
	var floats := crate.floating and absf(crate.global_position.y - (surface + Crate.FLOAT)) < 0.25
	p.teleport(crate.global_position + Vector3.UP * (Crate.HALF + p.radius() + 0.05))
	var rode := false
	for i in 600:
		await physics_frame
		if p.global_position.x > 158.0 and p.global_position.y > surface:
			rode = true
			break
	check("pushed in, the crate floats %.1f m over the surface and the current carries you across on it" % Crate.FLOAT, floats and rode,
		"floats %s (y %.2f, surface %.2f), rode to x %.1f" % [floats, crate.global_position.y, surface, p.global_position.x])

	# 128. Fire door: burning wine in the trough throws you back; a pot of water puts it out and you walk through
	var trough: Puddle = m["cellar_trough"]
	await _liquid_player(m["cellar_fire_near"])
	var was_burning := trough.burning
	p.ai_move = Vector2(-1, 0)
	await frames(90)
	p.ai_move = Vector2.ZERO
	var blocked: bool = p.hp < p.max_hp and p.global_position.x > 150.0
	await _liquid_player(m["cellar_fire_near"])
	p.facing = Vector3.LEFT
	pot = await _hand_pot("water")
	await _release_and_wait(pot)
	await frames(2)
	var doused := not trough.burning
	p.ai_move = Vector2(-1, 0)
	await frames(120)
	var sober := Coat.on(p) == null or Coat.on(p).drunk <= 0.0
	p.ai_move = Vector2.ZERO
	check("the burning trough throws you back; a pot of water puts it out and you walk through unhurt and sober",
		was_burning and blocked and doused and sober and p.global_position.x < 148.0 and p.hp == p.max_hp,
		"burning %s, blocked %s, doused %s, sober %s, reached x %.1f with hp %d" % [was_burning, blocked, doused, sober, p.global_position.x, p.hp])
	await _mop()
	var runnel: Runnel = m["cellar_runnel"]
	Liquids.spill(level, "water", runnel.top.lerp(runnel.bottom, 0.2) + Vector3.UP * 1.0)
	await frames(2)
	var end := runnel.bottom + Vector3(runnel.bottom.x - runnel.top.x, 0, runnel.bottom.z - runnel.top.z).normalized() * 0.6
	var at_end := 0
	var on_runnel := 0
	for n in get_nodes_in_group("puddles"):
		var pd := n as Puddle
		if pd.permanent or pd.kind != "water":
			continue
		if Vector2(pd.global_position.x - end.x, pd.global_position.z - end.z).length() < 0.8:
			at_end += 1
		else:
			on_runnel += 1
	check("water poured on a runnel runs down it and puddles only at its low end", at_end == 1 and on_runnel == 0, "%d at the end, %d elsewhere" % [at_end, on_runnel])
	await _mop()

	# 129. Candy trap: a running throw of honey lands by the brazier across the 13 m pit, the blob comes for it
	# and turns to rock candy, and the swap charm takes you across
	await _liquid_player(Vector3(137.0, 0.6, -108.0))
	p.inventory.add("swap")
	var trap_blob := Monster.spawn(level, m["cellar_candy_blob"], "blob")
	trap_blob.drop_heart = false
	pot = await _hand_pot("honey")
	p.ai_move = Vector2(1, 0)
	for i in 120:
		await physics_frame
		if p.global_position.x >= 147.5:
			break
	var landed := {}
	pot.smashed.connect(func(a: Vector3) -> void: landed["at"] = a)
	p.ai_context = true
	await physics_frame
	p.ai_move = Vector2(-1, 0)
	await frames(25)
	p.ai_move = Vector2.ZERO
	await frames(40)
	var honey_at: Vector3 = landed.get("at", Vector3.INF)
	var by_fire := Vector2(honey_at.x - lamp.global_position.x, honey_at.z - lamp.global_position.z).length()
	var candied := -1.0
	for i in 600:
		await physics_frame
		if is_instance_valid(trap_blob) and Coat.is_candy(trap_blob):
			candied = i / 60.0
			break
	await _liquid_player(m["cellar_candy_edge"])
	p.inventory.add("swap")
	p.facing = Vector3.RIGHT
	await _use("swap")
	await frames(10)
	check("candy trap: run-thrown honey lands %.1f m from the brazier across the pit, the blob turns to rock candy, and you swap across" % by_fire,
		honey_at.x > 163.0 and by_fire <= t.heat_reach and candied >= 0.0 and p.global_position.x > 160.0 and p.global_position.y > -0.5,
		"honey at x %.1f, candy after %.1f s, you at x %.1f" % [honey_at.x, candied, p.global_position.x])
	if is_instance_valid(trap_blob):
		trap_blob.queue_free()
	await _mop()
	await _liquid_player(L)


## Spider & lash (jovi, 2026-10-01): gears never turn themselves by what they move; the rope ignores small
## details; the lash leashes and slings monsters; the spider bites and turns shielded monsters.
func _spider_lash_tests(arena: Vector3) -> void:
	var m: Dictionary = level.marks
	var t: Tuning = level.t

	# SL1. A spider sitting on the arm gear's bridge rides the swing, and the gear doesn't wind itself on
	var arm: ArmGear = m["works_arm"]
	await _fresh_player(m["works_arm_stand"])
	p.inventory.add("spider")
	p.facing = Vector3.RIGHT
	await _use("spider")
	var sp: Spider = p.spider
	await _use("spider") # back to you: it sits still
	var n0 := arm.notch()
	var on_arm := arm.global_position + arm.arm_dir() * (arm.radius + 0.6) + Vector3.UP * (Spider.RADIUS + 0.1)
	sp.global_position = on_arm
	sp.velocity = Vector3.ZERO
	await frames(10)
	arm.turn(Gear.STEP)
	await frames(180)
	var rode := sp.global_position.distance_to(on_arm)
	check("a spider riding the arm bridge round doesn't wind the gear on: one notch asked, one notch turned",
		arm.notch() - n0 == 1 and rode > 1.0, "turned %d notches, spider carried %.1f m" % [arm.notch() - n0, rode])
	arm.turn(-Gear.STEP)
	await frames(60)
	p.stow_spider()

	# SL2. Rope wrapped on a gear whose lift carries the spider away: a 1 m turn moves the lift gear_ratio x 1 m
	# and no further (the carried spider pays out rope over the gear, but that rope isn't a driver)
	await _fresh_player(Vector3(-74, 0.6, -97.12))
	var deck_body := AnimatableBody3D.new()
	deck_body.sync_to_physics = false
	var dcs := CollisionShape3D.new()
	var dbox := BoxShape3D.new()
	dbox.size = Vector3(3, 0.4, 3)
	dcs.shape = dbox
	deck_body.add_child(dcs)
	deck_body.position = Vector3(-81.12, 0.05, -90)
	level.add_child(deck_body)
	var lift_gear := Gear.make(level, Vector3(-80, 0, -96), 1.0, deck_body, Vector3(0, 0, 4), t)
	p.inventory.add("spider")
	p.facing = Vector3.LEFT
	await _use("spider")
	sp = p.spider
	await _use("spider")
	sp.global_position = Vector3(-81.12, 0.25 + Spider.RADIUS + 0.05, -90)
	await frames(10)
	var rope := Tether.make(level, p, sp, t.leash_length, Color.WHITE)
	p.leash = rope
	rope.points = [p.global_position + Tether.LIFT, Vector3(-80, 0.6, -97.12), Vector3(-81.12, 0.6, -96), sp.global_position + Tether.LIFT]
	rope.turns = [0.0, rope._turn_at(1), rope._turn_at(2), 0.0]
	await frames(5)
	var z0 := deck_body.global_position.z
	var sz0 := sp.global_position.z
	lift_gear.turn(1.0)
	await frames(120)
	var lifted := deck_body.global_position.z - z0
	check("a gear's lift carrying the spider away doesn't wind the gear on through the rope: 1 m turned moves it %.1f m" % t.gear_ratio,
		absf(lifted - t.gear_ratio) < 0.05 and absf(lift_gear.wound - 1.0) < 0.05 and sp.global_position.z - sz0 > 0.3 and rope.points.size() >= 3,
		"lift moved %.2f m, gear wound %.2f m, spider carried %.2f m, bends %d" % [lifted, lift_gear.wound, sp.global_position.z - sz0, rope.points.size() - 2])
	p.stow_spider()
	lift_gear.queue_free()
	deck_body.queue_free()

	# SL3. Dragged on the rope across a 0.5 m kerb and past a thin pole, the spider takes no bends and follows over
	await _fresh_player(arena)
	p.inventory.add("spider")
	p.inventory.add("lash")
	p.facing = Vector3.RIGHT
	await _use("spider")
	sp = p.spider
	await _use("spider")
	sp.global_position = arena + Vector3(9, -0.6 + Spider.RADIUS + 0.05, 0)
	await frames(5)
	p.ai_target = true
	await frames(5)
	await _use("lash")
	p.ai_target = false
	var hooked := p.leash != null
	var kerb: StaticBody3D = level.box(arena + Vector3(5, -0.35, 0), Vector3(0.6, 0.5, 4), Basis(), Color.GRAY)
	var pole: StaticBody3D = level.box(arena + Vector3(2.5, 0.9, 0.35), Vector3(0.3, 3, 0.3), Basis(), Color.GRAY)
	var bends := 0
	p.ai_move = Vector2(-1, 0)
	for i in 300:
		await physics_frame
		if p.leash != null:
			bends = maxi(bends, p.leash.points.size() - 2)
		if sp.global_position.x < arena.x + 1.0 or p.global_position.x < arena.x - 30.0:
			break
	p.ai_move = Vector2.ZERO
	check("the rope rides over a 0.5 m kerb and past a 0.3 m pole without bending: the dragged spider follows over them",
		hooked and bends == 0 and sp.global_position.x < arena.x + 2.0, "hooked %s, bends %d, spider at x %+.1f from the start" % [hooked, bends, sp.global_position.x - arena.x])
	p.stow_spider()
	kerb.queue_free()
	pole.queue_free()

	# SL4. Dragged round a 2 m pillar's corner, the spider slides past it instead of sticking, and the bend lets go
	await _fresh_player(arena)
	var pil: StaticBody3D = level.box(arena + Vector3(3, 0.9, -1.6), Vector3(2, 3, 2), Basis(), Color.GRAY)
	p.inventory.add("spider")
	p.inventory.add("lash")
	p.facing = Vector3.RIGHT
	await _use("spider")
	sp = p.spider
	await _use("spider")
	sp.global_position = arena + Vector3(6, -0.6 + Spider.RADIUS + 0.05, 0)
	await frames(5)
	p.ai_target = true
	await frames(5)
	await _use("lash")
	p.ai_target = false
	hooked = p.leash != null
	bends = 0
	p.ai_move = Vector2(0, -1)
	for i in 300:
		await physics_frame
		if p.leash != null:
			bends = maxi(bends, p.leash.points.size() - 2)
		if p.global_position.z < arena.z - 24.0:
			break
	p.ai_move = Vector2.ZERO
	await frames(5)
	var left := p.leash.points.size() - 2 if p.leash != null else -1
	check("dragged round a 2 m pillar's corner the spider slides past it (no sticking) and the bend lets go",
		hooked and bends >= 1 and left == 0 and sp.global_position.z < arena.z - 3.0 and p.global_position.z < arena.z - 23.0,
		"bends %d then %d, spider %.1f m north, you %.1f m north" % [bends, left, arena.z - sp.global_position.z, arena.z - p.global_position.z])
	p.stow_spider()
	pil.queue_free()

	# SL5. The spider bites a monster next to it on its own, every spider_bite_every
	await _fresh_player(arena)
	p.inventory.add("spider")
	p.facing = Vector3.RIGHT
	await _use("spider")
	sp = p.spider
	await _use("spider") # back to you: it sits
	var blob := await _dummy(sp.global_position + Vector3(0, 0.4, -(Spider.RADIUS + 0.55 + 0.3)), "blob", false, 10)
	var b0 := sp.bites
	await frames(int(t.spider_bite_every * 2.5 * 60.0))
	var own_bites := sp.bites - b0
	check("the spider bites a monster next to it on its own every %.1f s (%.0f each)" % [t.spider_bite_every, t.spider_bite_damage],
		own_bites >= 2 and own_bites <= 3 and _hp(blob) == 10 - own_bites * int(t.spider_bite_damage), "%d bites in %.1f s, blob at %d of 10" % [own_bites, t.spider_bite_every * 2.5, _hp(blob)])
	if is_instance_valid(blob):
		blob.queue_free()

	# SL6. A shield monster facing it: its own bite glances off the shield, a steered bite (attack) cracks it; walking
	# past along its side turns it round (like a gear), and then the spider's own bite gets its back
	var guard := await _dummy(sp.global_position + Vector3(0, 0.4, -(Spider.RADIUS + 0.55 + 0.3)), "shield", false, 10)
	guard.look_at(sp.global_position + Vector3.UP * 0.4, Vector3.UP)
	sp._bite_cd = 0.0
	await frames(5)
	var glanced := _hp(guard) == 10
	await _use("spider") # steer it
	sp.facing = Vector3.FORWARD
	p.ai_attack = true
	await frames(3)
	var cracked := guard.shield_hp < 2 and _hp(guard) == 10
	await frames(20)
	# walk east past its south side, close in
	var g0 := guard._fwd()
	sp.global_position = guard.global_position + Vector3(-1.6, -0.4, Spider.RADIUS + 0.55 + 0.15)
	sp.velocity = Vector3.ZERO
	await frames(3)
	var t0 := sp.turned
	p.ai_move = Vector2(1, 0)
	await frames(30)
	p.ai_move = Vector2.ZERO
	var turn_deg := rad_to_deg(sp.turned - t0)
	var g1 := guard._fwd()
	var to_sp := sp.global_position - guard.global_position
	to_sp.y = 0.0
	var back_turned := g1.dot(to_sp.normalized()) < 0.0
	var hp_before := _hp(guard)
	sp._bite_cd = 0.0
	for i in 40: # straight at it (no walking past, so no more turning): its own bite finds the open side
		var at := guard.global_position - sp.global_position
		p.ai_move = Vector2(at.x, at.z).normalized() * 0.4
		await physics_frame
		if _hp(guard) < hp_before:
			break
	p.ai_move = Vector2.ZERO
	check("its own bite glances off a shield's front; a steered bite cracks it; walking past it turns the shield monster %.0f degrees (its back to the spider) and the next bite lands" % turn_deg,
		glanced and cracked and turn_deg > 120.0 and back_turned and _hp(guard) < hp_before,
		"glanced %s, shield %d, turned %.0f deg (front %.2f -> %.2f), hp %d -> %d" % [glanced, guard.shield_hp, turn_deg, g0.dot(g1), g1.dot(to_sp.normalized()), hp_before, _hp(guard)])
	if is_instance_valid(guard):
		guard.queue_free()
	await _use("spider")
	p.stow_spider()

	# SL7. The lash at a monster cracks like a whip, stings it (1) and leashes it; walk off and you drag it
	await _fresh_player(arena)
	p.inventory.add("lash")
	var mob := await _dummy(arena + Vector3(5, 0, 0), "blob", false, 10)
	p.facing = Vector3.RIGHT
	await frames(2)
	await _use("lash")
	var whips := 0
	for n in level.get_children():
		if n is Whip:
			whips += 1
	var leashed := p.leash != null and p.leash.b == mob
	var stung := _hp(mob) == 9
	var mob0 := mob.global_position
	p.ai_move = Vector2(-1, 0)
	await frames(90)
	p.ai_move = Vector2.ZERO
	var rope_len := p.leash.length() if p.leash != null else 0.0
	check("the lash cracks (a whip), stings a monster for 1 and leashes it on a %.0f m rope; walking off you drag it" % t.lash_leash,
		whips >= 1 and leashed and stung and mob.global_position.distance_to(mob0) > 3.0 and rope_len < t.lash_leash + 0.3,
		"whip %d, leashed %s, hp %d, dragged %.1f m, rope %.1f m" % [whips, leashed, _hp(mob), mob.global_position.distance_to(mob0), rope_len])

	# SL8. Attack with it leashed: it swings round you, hits everything it sweeps through, and flies off where you face
	await place(arena)
	p.facing = Vector3.RIGHT
	mob.global_position = arena + Vector3(-2.5, 0, 0)
	mob.velocity = Vector3.ZERO
	var near_a := await _dummy(arena + Vector3(0, 0, 2.6), "blob", false, 10)
	var near_b := await _dummy(arena + Vector3(0, 0, -2.6), "blob", false, 10)
	await frames(3)
	p.ai_attack = true
	await frames(2)
	var fly := Vector3.ZERO
	for i in 120:
		await physics_frame
		if p.leash == null:
			fly = mob.velocity
			break
	var flat_fly := Vector3(fly.x, 0, fly.z)
	check("attack swings a leashed monster round you: it hits both monsters beside you (%.0f each) and flies off at %.0f m/s where you face" % [t.sling_damage, t.sling_speed],
		_hp(near_a) == 10 - int(t.sling_damage) and _hp(near_b) == 10 - int(t.sling_damage) and flat_fly.length() > t.sling_speed * 0.8 and flat_fly.normalized().dot(Vector3.RIGHT) > 0.9,
		"hp %d and %d, flew %.1f m/s, %.2f along your facing" % [_hp(near_a), _hp(near_b), flat_fly.length(), flat_fly.normalized().dot(Vector3.RIGHT)])
	for mon in [mob, near_a, near_b]:
		if is_instance_valid(mon):
			mon.queue_free()

	# SL9. The lash again with one leashed yanks it to your feet, bowling over one in the way
	await _fresh_player(arena)
	p.inventory.add("lash")
	var far := await _dummy(arena + Vector3(6, 0, 0), "blob", false, 10)
	p.facing = Vector3.RIGHT
	await _use("lash")
	var hooked_far := p.leash != null
	var between := await _dummy(arena + Vector3(3, 0, 0.3), "blob", false, 10)
	await _use("lash")
	await frames(60)
	var gap := Vector2(far.global_position.x - p.global_position.x, far.global_position.z - p.global_position.z).length()
	check("the lash again yanks a leashed monster to your feet at %.0f m/s, knocking one in the way, and lets go" % t.yank_speed,
		hooked_far and gap < 2.5 and _hp(between) < 10 and p.leash == null, "ended %.1f m from you, the one between at %d, leash %s" % [gap, _hp(between), p.leash != null])
	for mon in [far, between]:
		if is_instance_valid(mon):
			mon.queue_free()

	# SL10. The lash tears a shield monster's shield away for good; a brute is too heavy, so it pulls you in
	await _fresh_player(arena)
	p.inventory.add("lash")
	var shielded := await _dummy(arena + Vector3(5, 0, 0), "shield", false, 10)
	shielded.look_at(p.global_position, Vector3.UP)
	p.facing = Vector3.RIGHT
	await _use("lash")
	var torn := shielded.shield_hp == 0 and _hp(shielded) == 9
	var torn_at := "shield %d, hp %d" % [shielded.shield_hp, _hp(shielded)]
	if p.leash != null:
		p.leash.queue_free()
		p.leash = null
	shielded.queue_free()
	var brute := await _dummy(arena + Vector3(8, 0.3, 0), "brute", false, 10)
	await frames(2)
	var x_start := p.global_position.x
	await _use("lash")
	await frames(40)
	var pulled_in := p.global_position.x - x_start
	check("the lash tears a shield away for good; a brute is too heavy and pulls you in %.1f m" % pulled_in,
		torn and pulled_in > 4.0 and p.leash == null, "%s, pulled %.1f m" % [torn_at, pulled_in])
	if is_instance_valid(brute):
		brute.queue_free()

	# SL11. A leashed monster dragged round a 2 m pillar's corner slides past it too, and the bend lets go
	await _fresh_player(arena)
	p.inventory.add("lash")
	var pil2: StaticBody3D = level.box(arena + Vector3(3, 0.9, -1.8), Vector3(2, 3, 2), Basis(), Color.GRAY)
	var towed := await _dummy(arena + Vector3(5.5, 0, 0), "blob", false, 10)
	p.facing = Vector3.RIGHT
	await _use("lash")
	hooked = p.leash != null
	bends = 0
	p.ai_move = Vector2(0, -1)
	for i in 300:
		await physics_frame
		if p.leash != null:
			bends = maxi(bends, p.leash.points.size() - 2)
		if p.global_position.z < arena.z - 16.0:
			break
	p.ai_move = Vector2.ZERO
	await frames(5)
	left = p.leash.points.size() - 2 if p.leash != null else -1
	check("a leashed monster dragged round a 2 m pillar's corner slides past it and the bend lets go",
		hooked and bends >= 1 and left == 0 and towed.global_position.z < arena.z - 3.5,
		"bends %d then %d, monster %.1f m north" % [bends, left, arena.z - towed.global_position.z])
	if p.leash != null:
		p.leash.queue_free()
		p.leash = null
	towed.queue_free()
	pil2.queue_free()

	# SL12. The spider pen's monsters keep to their spots for the spider while you stand at the warp
	await _fresh_player(m["combat_pen_spider"])
	var pen := SpiderPens.pen(level, Vector3(-76, 0, 12), [["shield", Vector3(-81, 0.6, 13)], ["knight", Vector3(-76, 0.6, 13)], ["brute", Vector3(-71, 0.9, 13)]], true)
	await frames(180)
	var strayed := 0.0
	for mon in pen.alive:
		if is_instance_valid(mon):
			var d: Vector3 = (mon as Monster).global_position - (mon as Monster).home
			strayed = maxf(strayed, Vector2(d.x, d.z).length())
	check("the spider pen's shield blob, iron knight and brute keep to their spots (within 1.5 m) while you watch from the warp",
		pen.alive.size() == 3 and strayed < 1.5, "%d monsters, strayed up to %.1f m" % [pen.alive.size(), strayed])
	for mon in pen.alive:
		if is_instance_valid(mon):
			mon.queue_free()
	pen.queue_free()
	await _fresh_player(arena)
