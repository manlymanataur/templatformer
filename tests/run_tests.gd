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
		var edge_x := start.x - 6.0
		var flying := false
		for i in 120:
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

func _monster_ahead(dist: float) -> Monster:
	var mon := Monster.spawn(level, p.global_position + Vector3(0, 0.2, -dist))
	mon.drop_heart = false
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
	p.ai_item = 0
	await frames(3)
	p.ai_move = Vector2(0, 1) # walk away from the bomb
	await frames(40)
	p.ai_move = Vector2.ZERO
	await frames(100)
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
