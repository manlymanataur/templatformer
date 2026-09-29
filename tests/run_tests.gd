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
	await place(Vector3(40, 0.6, 20))
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

	# 9. Loop: boost pad then hold forward, go all the way round and exit in the shifted lane
	await place(m["loop_start"])
	p.ai_move = Vector2(0, -1)
	var hi := 0.0
	for i in 360:
		await physics_frame
		hi = maxf(hi, p.global_position.y)
	var pos := p.global_position
	check("loop completed", hi > 2.0 * level.LOOP_R - 1.5 and pos.z < -75.0,
		"top %.1f m, ended at z %.1f" % [hi, pos.z])

	# 10. Loop without the boost: too slow, you fall off and don't finish
	await place(Vector3(0, 0.6, -45), Vector3(0, 0, -t.top_speed))
	p.ai_move = Vector2(0, -1)
	var hi2 := 0.0
	for i in 300:
		await physics_frame
		hi2 = maxf(hi2, p.global_position.y)
	pos = p.global_position
	check("loop needs the boost", hi2 < 2.0 * level.LOOP_R - 1.5, "top %.1f m" % hi2)

	# 11. Quarter pipe: launched up, comes back down
	await place(m["pipe_start"])
	p.ai_move = Vector2(0, -1)
	hi = 0.0
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
	var ok := p.target != null
	var face := 0.0
	if ok:
		var d: Vector3 = p.target.global_position - p.global_position
		d.y = 0
		face = p.facing.dot(d.normalized())
	check("lock-on faces target", ok and face > 0.9, "facing dot %.2f" % face)

	print("\n%d failed" % fails)
	quit(1 if fails else 0)
