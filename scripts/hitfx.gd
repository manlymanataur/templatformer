class_name Hitfx
extends RefCounted
## Hit feel: hitstop (the whole game freezes for a few frames), screen shake, and a burst of sparks.
## Only kills, spikes, sweet spots and parries freeze the game (jovi, 2026-10-03); plain hits don't.
## How hard a hit lands shows on what it hits: a weak monster squashes and stretches (Monster.impact), a big
## one barely gives but shakes the screen.
## Also the slow-motion after a perfect dodge (see Player.hurt): monsters crawl while you move at full speed.

static var slow_left := 0.0 ## seconds of perfect-dodge slow-motion left
static var world := 1.0 ## how fast monsters run right now (the player sets it each frame)
static var _stopping := false

## A solid hit at `at`: spark and shake. strength 1 is a normal poleaxe hit. who is what got hit: if it has
## impact(strength, t) (monsters), that squashes it and returns how much the screen shakes for it.
## freeze is real seconds of hitstop, 0 for a plain hit.
static func hit(tree: SceneTree, at: Vector3, t: Tuning, strength := 1.0, who: Node = null, freeze := 0.0) -> void:
	sparks(tree, at, strength)
	var rumble := 1.0
	if who != null and is_instance_valid(who) and who.has_method("impact"):
		rumble = who.impact(strength, t)
	shake(tree, t.shake_hit * strength * rumble)
	if freeze > 0.0 or strength >= 2.0:
		# a big hit kicks the camera along the blow
		var p := tree.get_first_node_in_group("player") as Node3D
		if p != null:
			punch(tree, at - p.global_position, strength * 0.5)
	stop(tree, freeze)

## Freeze the whole game for secs of real time.
static func stop(tree: SceneTree, secs: float) -> void:
	if secs <= 0.0 or _stopping:
		return
	_stopping = true
	Engine.time_scale = 0.02
	await tree.create_timer(secs, true, false, true).timeout
	Engine.time_scale = 1.0
	_stopping = false

## Kick the camera along dir (big hits, and when you're hit).
static func punch(tree: SceneTree, dir: Vector3, amount: float) -> void:
	for n in tree.get_nodes_in_group("camera_rig"):
		n.punch(Vector3(dir.x, dir.y * 0.3, dir.z), amount)

static func shake(tree: SceneTree, amount: float) -> void:
	for n in tree.get_nodes_in_group("camera_rig"):
		n.shake = maxf(n.shake, amount)

static func sparks(tree: SceneTree, at: Vector3, strength := 1.0) -> void:
	var root := tree.current_scene if tree.current_scene != null else tree.root
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.emitting = false
	p.amount = int(14 * strength)
	p.lifetime = 0.3
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 4.0
	p.initial_velocity_max = 9.0
	p.gravity = Vector3.DOWN * 12.0
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.0
	var m := SphereMesh.new()
	m.radius = 0.05
	m.height = 0.1
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = Color(1.0, 0.9, 0.5)
	m.material = mat
	p.mesh = m
	root.add_child(p)
	p.global_position = at
	p.emitting = true
	tree.create_timer(0.6, true, false, true).timeout.connect(p.queue_free)

## Start perfect-dodge slow-motion.
static func slow(tree: SceneTree, t: Tuning) -> void:
	slow_left = t.dodge_slow_time
	shake(tree, 0.1)

## Count down the slow-motion and set how fast the world runs. The player calls this each frame.
static func tick(dt: float, t: Tuning) -> void:
	slow_left = maxf(slow_left - dt, 0.0)
	world = t.dodge_slow_speed if slow_left > 0.0 else 1.0
