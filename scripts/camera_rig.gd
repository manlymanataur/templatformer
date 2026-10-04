class_name CameraRig
extends Node3D
## Third-person orbit camera. Mouse or right stick to orbit; after a while with your hands off it (cam_recenter_delay)
## it swings behind your motion. Locked on, it frames you and the target like Ocarina's Z-targeting.
##
## The camera overhaul (jovi, 2026-10-04). Every move goes through a spring, so nothing snaps (critically damped:
## SpringF and SpringV). Each frame _compose reads the situation and picks:
## - where on screen you sit (anchor, -1..1 each way, up is +), using a photography guide per situation:
##   - walking: the golden section (THIRD's softer cousin GOLDEN), with lead room: you sit on the side away from
##     where you're heading, so there's room to run into
##   - fast, skiing or boosting: the rule of thirds, low in the frame, so the speed lines radiate from the
##     vanishing point ahead of you
##   - in the air: the golden spiral's eye, lead room along your arc
##   - locked on: the golden triangle. You sit low on one side, the target up the diagonal; the view tilts to
##     take in a target above or below you (an archer on a perch, the colossus)
##   - climbing, wall sliding, bouncing up trees: you sit low and the view tilts up (headroom)
##   - a pack: the camera frames you and every monster within cam_pack_range
##   - frame within a frame: just past a doorway, arch or the chimney's mouth (CamFrame), the camera stays on the
##     near side looking through it
## - the angle: low (looking up) near a powerful foe (brutes, the colossus), high (looking down) when you're small
##   or hanging from a ledge
## - the lens: long near a powerful foe (the camera backs off to keep your size), wide at speed and high up, and a
##   dolly zoom (wider while the camera closes in) at a cliff edge, off a big launch and over a big drop
## - how far out: closer in tight rooms, further out in the open (open, from a few probe rays)
## - looking ahead of you at speed (cam_look_ahead, more skiing and boosting)
## Walls push the camera in quickly and it eases back out (cam_ease_out); thin things (trees, posts, poles, rails,
## bars, creatures) never push it in: they fade instead. Hidden behind something, you show as an outline.
## Also: a dip on hard landings, a kick along big hits (punch), a roll with banked ground and rails, a light Dutch
## tilt drunk or on your last heart, a blob shadow under you in the air, and first-person look (hold Q / d-pad
## up, like Ocarina's C-up), where items aim where you look. Not locked on, the lash aims at the reticle.
## Speed shows (jovi, 2026-10-04): past top_speed the view widens (ski_fov), the camera rises (ski_cam_rise) and
## pulls back, speed lines stream past and the view trembles, all on one dial (speed_k). Skiing, it follows
## behind your line at once and rolls a little with your lean. Speed lines start at speed_lines_from.

const THIRD := 1.0 / 3.0 ## the rule of thirds' lines, in screen units (-1..1)
const GOLDEN := 0.236 ## the golden section's lines (0.618 of the way across), in screen units
const BASE_FOV := 70.0
const PITCH_MIN := -1.2
const PITCH_MAX := 0.4

## A critically damped spring: x chases a target without overshoot, starting and stopping gently.
class SpringF:
	var x := 0.0
	var v := 0.0
	func step(target: float, omega: float, dt: float) -> float:
		var f := 1.0 + 2.0 * dt * omega
		var hoo := dt * omega * omega
		var inv := 1.0 / (f + dt * hoo)
		var nx := (f * x + dt * v + dt * hoo * target) * inv
		v = (v + hoo * (target - x)) * inv
		x = nx
		return x

class SpringV:
	var x := Vector3.ZERO
	var v := Vector3.ZERO
	func step(target: Vector3, omega: float, dt: float) -> Vector3:
		var f := 1.0 + 2.0 * dt * omega
		var hoo := dt * omega * omega
		var inv := 1.0 / (f + dt * hoo)
		var nx := (f * x + dt * v + dt * hoo * target) * inv
		v = (v + hoo * (target - x)) * inv
		x = nx
		return x

var player: Player
var t: Tuning
var yaw := 0.0
var pitch := -0.3
var idle := 99.0 ## seconds since you last moved the camera
var zoom := 1.0
var arm: SpringArm3D ## the boom; spring_length is the camera's distance right now (walls counted)
var cam: Camera3D
var shake := 0.0 ## metres of random jitter, decaying (see Hitfx.shake)
var speed_k := 0.0 ## 0 at top_speed or slower, 1 at boost_speed: drives the view, height, pull-back and speed lines
var lines: CPUParticles3D
var overlay: CameraOverlay

# what the composer decided this frame (tests read these)
var mode := "free" ## free, run, air, climb, hang, lock, pack, frame, look
var anchor := Vector2.ZERO ## where on screen you sit (-1..1 each way, up is +), eased
var tilt := 0.0 ## radians added to your pitch (up is +), eased
var open := 0.6 ## 0 in a tight room .. 1 out in the open
var dolly := 0.0 ## 0..1, eased
var powerful: Node3D = null ## the powerful foe the camera is looking up at
var pack := 0 ## monsters framed with you
var want_len := 0.0 ## how far out the camera wants to be before walls
var occluded := false ## something stands between the camera and you (the outline shows)
var faded := {} ## thin things between the camera and you: node -> how faded (0..1)
var looking := false ## first-person look
var look_held := false ## tests: hold first-person look without the button
var aim_always := false ## tests: aim the reticle even though the player is AI-driven
var aim_ok := false ## the reticle is on something the lash can catch
var drop := 0.0 ## metres to the ground below you (in the air)
var roll := 0.0 ## the camera's roll right now

var _pos := SpringV.new() ## where the camera looks from, across (y unused)
var _py := SpringF.new() ## ...and its height
var _len := SpringF.new()
var _fov := SpringF.new()
var _tilt := SpringF.new()
var _roll := SpringF.new()
var _anchor := SpringV.new()
var _open := SpringF.new()
var _dolly := SpringF.new()
var _dip := 0.0
var _dip_v := 0.0
var _punch := Vector3.ZERO
var _punch_v := Vector3.ZERO
var _was_floor := true
var _fall_v := 0.0
var _probe_n := 0
var _probe_open := 0.6
var _launch_pulse := 0.0
var _saved_pitch := -0.3
var _lock_side := 1.0
var _prev_yaw := 0.0
var _pan := 0.0 ## how fast the view is turning (radians per second)
var _prev_heading := 0.0
var _ball: SphereShape3D
var _thin_cache := {}
var _shadow: MeshInstance3D
var _ghost: MeshInstance3D
var _time := 0.0

func _ready() -> void:
	add_to_group("camera_rig")
	arm = SpringArm3D.new()
	arm.collision_mask = 0 # the rig does its own wall test (_cast): thin things don't count
	add_child(arm)
	cam = Camera3D.new()
	cam.fov = BASE_FOV
	arm.add_child(cam)
	_ball = SphereShape3D.new()
	_ball.radius = 0.3
	lines = CPUParticles3D.new() # speed lines: thin streaks rushing past the lens
	lines.emitting = false
	lines.amount = LINES
	lines.lifetime = 0.35
	lines.local_coords = true
	lines.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	lines.emission_ring_axis = Vector3.BACK
	lines.emission_ring_radius = 3.2
	lines.emission_ring_inner_radius = 1.6
	lines.emission_ring_height = 0.1
	lines.direction = Vector3.BACK
	lines.spread = 0.0
	lines.gravity = Vector3.ZERO
	lines.initial_velocity_min = 30.0
	lines.initial_velocity_max = 45.0
	var lm := BoxMesh.new()
	lm.size = Vector3(0.025, 0.025, 1.6)
	var lmat := StandardMaterial3D.new()
	lmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	lmat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	lmat.albedo_color = Color(1, 1, 1, 0.35)
	lm.material = lmat
	lines.mesh = lm
	lines.position = Vector3(0, 0, -6)
	cam.add_child(lines)
	_make_shadow()
	_make_ghost()
	overlay = CameraOverlay.new()
	overlay.rig = self
	add_child(overlay)
	_len.x = t.cam_distance
	_fov.x = BASE_FOV
	snap()

## Put the camera straight behind where it should be (warps and pins call this).
func snap() -> void:
	var f := player.focus()
	var at := f.global_position + Vector3.UP * zoom
	_pos.x = Vector3(at.x, 0.0, at.z)
	_pos.v = Vector3.ZERO
	_py.x = at.y
	_py.v = 0.0
	global_position = at

## How many speed lines stream at this speed_k: none below from, then from a handful up to LINES at 1, in steps
## of 8 (changing the count restarts the stream, so it changes rarely).
const LINES := 48
static func line_count(k: float, from: float) -> int:
	if k < from:
		return 0
	var f := clampf((k - from) / maxf(1.0 - from, 0.01), 0.0, 1.0)
	return clampi(8 * roundi(lerpf(1.0, LINES / 8.0, f * f)), 8, LINES)

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * 0.004
		pitch = clampf(pitch - e.relative.y * 0.004, _pitch_min(), _pitch_max())
		idle = 0.0

func _pitch_min() -> float:
	return -1.3 if looking else PITCH_MIN
func _pitch_max() -> float:
	return 1.3 if looking else PITCH_MAX

## A big hit: kick the camera along dir (Hitfx.punch).
func punch(dir: Vector3, amount: float) -> void:
	if dir.length() < 0.01:
		return
	_punch_v += dir.normalized() * amount * t.cam_punch * 8.0
	_roll.v += dir.normalized().dot(global_basis.x) * amount * 0.25

func _physics_process(dt: float) -> void:
	_time += dt
	var look := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if look.length() > 0.1:
		yaw -= look.x * 2.5 * dt
		pitch = clampf(pitch - look.y * 2.0 * dt, _pitch_min(), _pitch_max())
		idle = 0.0
	else:
		idle += dt
	var f := player.focus() as CharacterBody3D
	var on_floor := f.is_on_floor()
	_update_look(f, on_floor)
	var small := player.small or player.pilot != null # pull in close when you're small or steering the spider
	zoom = lerpf(zoom, t.small_scale * 1.6 if small else 1.0, clampf(4.0 * dt, 0.0, 1.0))
	var k := clampf((f.velocity.length() - t.top_speed) / maxf(t.boost_speed - t.top_speed, 0.1), 0.0, 1.0)
	speed_k = lerpf(speed_k, k, clampf(3.0 * dt, 0.0, 1.0))
	_landing(f, on_floor, dt)
	_probe(f, dt)

	# what to frame, and how
	var c := _compose(f, on_floor, dt)
	var bias: Vector3 = c["bias"]
	var len_mult: float = c["len"]
	var lens: float = c["lens"] # degrees narrower (-) or wider (+) the lens goes, the camera moving to keep your size
	var yaw_goal: float = c["yaw"]
	var yaw_rate: float = c["rate"]
	tilt = _tilt.step(c["tilt"], 6.0, dt)
	var a := _anchor.step(Vector3(c["anchor"].x, c["anchor"].y, 0.0), 2.5, dt)
	anchor = Vector2(a.x, a.y)
	if yaw_rate > 0.0:
		yaw += angle_difference(yaw, yaw_goal) * (1.0 - exp(-yaw_rate * dt)) # eased: slow to start, slow to stop

	# follow (a spring that leads by your velocity so it doesn't trail behind at speed)
	var goal := f.global_position + Vector3.UP * (zoom + t.ski_cam_rise * speed_k) + bias
	if looking:
		goal = f.global_position + Vector3.UP * 0.45 * zoom
	if Vector3(_pos.x.x, _py.x, _pos.x.z).distance_to(goal) > 25.0:
		snap() # a warp: no swoop across the level
	var lead := f.velocity * 0.85
	var hz := _pos.step(Vector3(goal.x + lead.x * 2.0 / t.cam_follow, 0.0, goal.z + lead.z * 2.0 / t.cam_follow), t.cam_follow, dt)
	var falling := f.velocity.y < -8.0 # falling fast: keep up; otherwise up and down lag softly behind
	var wy := t.cam_follow * 1.3 if falling else t.cam_follow_y
	var yy := _py.step(goal.y + (lead.y * 2.0 / wy if falling else 0.0), wy, dt)
	_dip_v += (-60.0 * _dip - 15.0 * _dip_v) * dt # the landing dip springs back
	_dip += _dip_v * dt
	_punch_v += (-200.0 * _punch - 14.0 * _punch_v) * dt # the hit punch: a quick kick, a little bounce
	_punch += _punch_v * dt
	global_position = Vector3(hz.x, yy, hz.z) + Vector3.UP * _dip + _punch

	# angle
	var p_total := clampf(pitch + tilt - 0.12 * speed_k, -1.35, 0.75)
	if looking:
		p_total = pitch
	rotation = Vector3(p_total, yaw, 0)
	_pan = lerpf(_pan, absf(angle_difference(_prev_yaw, yaw)) / maxf(dt, 0.001), clampf(10.0 * dt, 0.0, 1.0))
	_prev_yaw = yaw

	# lens and distance
	var dg := _dolly_goal(f, on_floor, dt)
	dolly = _dolly.step(dg, 5.0 if dg > dolly else 2.5, dt)
	lens += t.cam_dolly * dolly
	var fov_goal := BASE_FOV + t.ski_fov * speed_k + lens + 8.0 * clampf((drop - 8.0) / 20.0, 0.0, 1.0)
	var comp := tan(deg_to_rad(BASE_FOV) / 2.0) / tan(deg_to_rad(BASE_FOV + lens) / 2.0) # keep your size as the lens changes
	open = _open.step(_probe_open, 2.0, dt)
	want_len = t.cam_distance * zoom * (1.0 + speed_k / 3.0) * lerpf(t.cam_open_min, t.cam_open_max, open) * len_mult * comp
	if looking:
		want_len = 0.0
		fov_goal = BASE_FOV
	cam.fov = _fov.step(fov_goal, 8.0, dt)
	var tan_v := tan(deg_to_rad(cam.fov) / 2.0)
	var vp := get_viewport().get_visible_rect().size
	var aspect := vp.x / maxf(vp.y, 1.0) if vp.y > 0.0 else 16.0 / 9.0
	var hx := -anchor.x * want_len * tan_v * aspect
	var vy := -anchor.y * want_len * tan_v
	# walls: in quickly, out gently; thin things don't count (_cast)
	var clear := want_len
	if want_len > 0.01:
		var from := global_position
		var to := global_basis * Vector3(hx, vy, want_len) + from
		clear = want_len * _cast(from, to, f)
	if looking:
		_len.step(0.0, 12.0, dt)
	elif clear < _len.x:
		_len.x = lerpf(_len.x, clear, 1.0 - exp(-20.0 * dt))
		_len.x = minf(_len.x, clear + 0.25)
		_len.v = 0.0
	else:
		_len.step(clear, t.cam_ease_out, dt)
	arm.spring_length = maxf(_len.x, 0.0)
	var share := _len.x / want_len if want_len > 0.01 else 0.0

	# roll: banked ground and rails, the ski lean, a light Dutch tilt drunk or on your last heart
	var roll_goal := 0.0
	if player.surfing:
		roll_goal = -player.ski_lean * 0.06
	if on_floor and f == player and not looking:
		var n := player.get_floor_normal()
		roll_goal += -asin(clampf(n.dot(global_basis.x), -1.0, 1.0)) * t.cam_bank
	if player.rail != null:
		var hv := Vector3(f.velocity.x, 0, f.velocity.z)
		var heading := atan2(hv.x, hv.z)
		var turn := angle_difference(_prev_heading, heading) / maxf(dt, 0.001)
		roll_goal += clampf(turn * 0.04, -0.08, 0.08) # lean into the rail's curves
	_prev_heading = atan2(f.velocity.x, f.velocity.z)
	var coat := Coat.on(player)
	if coat != null and coat.drunk > 0.0:
		roll_goal += t.cam_dutch * sin(_time * 1.1) * minf(coat.drunk, 1.0)
	elif player.hp <= 2 and player.max_hp > 2:
		roll_goal += t.cam_dutch * (0.6 + 0.15 * sin(_time * 1.7))
	roll = _roll.step(roll_goal, 6.0, dt)
	cam.rotation.z = roll

	# speed lines and shake
	var count := line_count(speed_k, t.speed_lines_from)
	lines.emitting = count > 0 and not looking
	if count > 0 and count != lines.amount:
		lines.amount = count # a few streaks just past speed_lines_from, the full stream at boost speed
	shake = maxf(shake, 0.03 * maxf(speed_k - 0.5, 0.0))
	player.cam_basis = Basis(Vector3.UP, yaw)
	shake = maxf(shake - dt * 0.8, 0.0)
	cam.h_offset = hx * share + randf_range(-1.0, 1.0) * shake
	cam.v_offset = vy * share + randf_range(-1.0, 1.0) * shake

	_fade_and_outline(f, dt)
	_update_shadow(f, on_floor)
	_update_aim(f)
	overlay.blur = speed_k * 0.025 * t.cam_blur # very light: a few percent toward the middle at boost speed
	overlay.pan = clampf((_pan - 2.5) * 0.0015, 0.0, 0.008) * t.cam_blur
	overlay.soft = (0.7 if mode == "lock" or (mode == "pack" and pack >= 2) else 0.0) * t.cam_dof

## Hold Q (d-pad up) standing still to look round in first person. Letting go leaves the camera behind
## where you looked.
func _update_look(f: CharacterBody3D, on_floor: bool) -> void:
	var held := look_held or (not player.ai and Input.is_action_pressed("look"))
	var can := player.pilot == null and player.hang == Vector3.ZERO and player.climbing == null and player.rail == null \
		and not player.surfing and f == player and on_floor
	if held and can and not looking:
		looking = true
		_saved_pitch = pitch
		var fw := player._flat_facing()
		yaw = atan2(-fw.x, -fw.z)
		pitch = 0.0
	elif looking and not (held and can):
		looking = false
		pitch = _saved_pitch
		idle = 0.0
	player.looking = looking
	var fwd := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	player.look_dir = fwd if looking else Vector3.ZERO

## The composer: picks the anchor, tilt, pivot bias, distance, lens and yaw goal for this situation.
func _compose(f: CharacterBody3D, on_floor: bool, _dt: float) -> Dictionary:
	var c := {"anchor": Vector2(0.0, -GOLDEN * 0.6), "tilt": 0.0, "bias": Vector3.ZERO, "len": 1.0, "lens": 0.0,
		"yaw": yaw, "rate": 0.0}
	pack = 0
	powerful = null
	if looking:
		mode = "look"
		c["anchor"] = Vector2.ZERO
		return c
	var hv := Vector3(f.velocity.x, 0, f.velocity.z)
	var top := maxf(t.top_speed * (t.small_scale if player.small else 1.0), 1.0)
	var right := Basis(Vector3.UP, yaw) * Vector3.RIGHT
	var lat := clampf(hv.dot(right) / top, -1.0, 1.0)
	var fast := clampf(hv.length() / top, 0.0, 1.0)
	var tilt_goal := 0.0
	# look ahead along your motion (further skiing and boosting)
	# (along the view only: across it, lead room on screen does the job)
	var fwd := Basis(Vector3.UP, yaw) * Vector3.FORWARD
	var ahead := fwd * hv.normalized().dot(fwd) * t.cam_look_ahead * zoom * (fast + speed_k * (1.6 if player.surfing else 1.0)) if hv.length() > 0.5 else Vector3.ZERO
	var bias := ahead
	mode = "run" if fast > 0.6 else "free"
	# the golden section walking, the rule of thirds fast (speed lines radiate from ahead of you); lead room
	var side_k := lerpf(GOLDEN, THIRD, maxf(speed_k, fast * 0.5))
	var anc := Vector2(-lat * side_k, -lerpf(GOLDEN * 0.6, THIRD, maxf(speed_k, fast * 0.4)))
	if not on_floor and f == player:
		mode = "air"
		anc = Vector2(-lat * GOLDEN, -GOLDEN) # the golden spiral's eye; your arc sweeps out along it
	var climbing := f == player and (player.climbing != null or (not on_floor and player._wall_t > 0.0 and player.wall_lock <= 0.0))
	if climbing:
		mode = "climb"
		tilt_goal += t.cam_climb_tilt # look up the wall, trunk or vines: headroom above you
		anc = Vector2(0.0, -THIRD)
		bias = Vector3.UP * 1.0
	if player.hang != Vector3.ZERO and f == player:
		mode = "hang"
		tilt_goal -= t.cam_high_angle # look down on you and the drop, over the ledge you're pulling onto
		anc = Vector2(0.0, -GOLDEN * 0.5)
		bias = Vector3.UP * 0.8
		var n := player.hang_n
		c["yaw"] = atan2(n.x, n.z)
		c["rate"] = 3.0 if idle > 0.4 else 0.0
	if player.small:
		tilt_goal -= t.cam_high_angle # small: a high angle shows how small you are
	var len_mult := 1.0
	var lens := 0.0
	# yaw: recenter behind your motion once you've left the camera alone a while (eased in, eased out)
	var ease_in := clampf((idle - t.cam_recenter_delay) / 1.0, 0.0, 1.0)
	if player.target == null and not player.strafing and player.hang == Vector3.ZERO:
		if player.surfing and hv.length() > 4.0 and idle > 0.3:
			c["yaw"] = atan2(-hv.x, -hv.z) # skiing: stay behind your line
			c["rate"] = 4.0
		elif hv.length() > 4.0 and ease_in > 0.0:
			c["yaw"] = atan2(-hv.x, -hv.z)
			c["rate"] = 1.5 * ease_in * ease_in * (3.0 - 2.0 * ease_in)
	elif player.strafing:
		c["yaw"] = atan2(-player.lock_dir.x, -player.lock_dir.z) # Ocarina's parallel targeting
		c["rate"] = 10.0
	# a pack: frame you and every monster near you
	var mons: Array[Node3D] = []
	var sum := f.global_position
	for m in get_tree().get_nodes_in_group("monsters"):
		var mn := m as Node3D
		if mn == null or not is_instance_valid(mn) or mn.is_queued_for_deletion():
			continue
		if "hp" in mn and int(mn.get("hp")) <= 0:
			continue
		var d := mn.global_position.distance_to(f.global_position)
		if d < t.cam_pack_range:
			mons.append(mn)
			sum += mn.global_position
		if d < t.cam_pack_range + 4.0 and "kind" in mn and mn.get("kind") == "brute":
			if powerful == null or d < powerful.global_position.distance_to(f.global_position):
				powerful = mn
	for g in get_tree().get_nodes_in_group("powerful"):
		var gn := g as Node3D
		var gp := gn.global_position
		if Vector2(gp.x - f.global_position.x, gp.z - f.global_position.z).length() < 30.0:
			powerful = gn
	pack = mons.size()
	if pack >= 2 and player.target == null:
		mode = "pack"
		var cen := sum / float(pack + 1)
		var spread := 0.0
		for mn in mons:
			spread = maxf(spread, mn.global_position.distance_to(cen))
		spread = maxf(spread, f.global_position.distance_to(cen))
		var off := cen - f.global_position
		off.y *= 0.5
		bias = bias * 0.3 + off * 0.45
		len_mult = maxf(len_mult, (spread * 1.3 + 3.0) / maxf(t.cam_distance, 1.0))
		anc = Vector2(anc.x * 0.5, -GOLDEN * 0.8)
	# locked on: the golden triangle, with the target's height
	var tg := player.target
	if tg != null and is_instance_valid(tg):
		mode = "lock"
		var to := tg.global_position - player.global_position
		var hd := Vector2(to.x, to.z).length()
		if hd >= 2.0:
			c["yaw"] = atan2(-to.x, -to.z)
			c["rate"] = 8.0
			var s := signf(to.dot(right))
			if s != 0.0 and absf(to.normalized().dot(right)) > 0.3:
				_lock_side = -s
		tilt_goal += clampf(atan2(to.y, maxf(hd, 2.0)) * 0.6, -0.45, 0.55) # look up at a perch, down into a pit
		bias = Vector3(to.x, to.y * 0.6, to.z) * 0.3
		len_mult = maxf(len_mult, 1.0 + clampf(hd / 14.0, 0.0, 0.6))
		anc = Vector2(_lock_side * GOLDEN * 1.3, -THIRD * 0.8) # you low on one side, the target up the diagonal
	# a powerful foe: a low angle looking up, and a long lens
	if powerful != null and not player.small:
		tilt_goal += t.cam_low_angle
		bias += Vector3.DOWN * 0.6 * zoom
		lens -= t.cam_long_lens
	# frame within a frame: just past a doorway, arch or the chimney's mouth, look through it
	var fr := _frame_for(f)
	if fr.size() > 0:
		mode = "frame"
		c["yaw"] = fr["yaw"]
		c["rate"] = 3.0
		len_mult = maxf(len_mult, fr["len"] / maxf(t.cam_distance * zoom, 0.1))
		anc.x = 0.0
	c["anchor"] = anc
	c["tilt"] = tilt_goal
	c["bias"] = bias
	c["len"] = len_mult
	c["lens"] = lens
	return c

## The CamFrame you're just past, if any: {yaw, len} for a camera on its near side looking through it.
func _frame_for(f: Node3D) -> Dictionary:
	for n in get_tree().get_nodes_in_group("cam_frames"):
		var fr := n as CamFrame
		var out := fr.out_dir(cam.global_position)
		var lp := f.global_position - fr.global_position
		var depth := -lp.dot(out)
		var side := out.cross(Vector3.UP).normalized()
		if depth > -0.5 and depth < fr.depth and absf(lp.dot(side)) < fr.size.x / 2.0 + 0.5 \
				and absf(lp.dot(Vector3.UP)) < fr.size.y / 2.0 + 2.0:
			return {"yaw": atan2(out.x, out.z), "len": depth + fr.reach}
	return {}

## Landing: a dip scaled by the fall.
func _landing(f: CharacterBody3D, on_floor: bool, _dt: float) -> void:
	if not on_floor:
		_fall_v = minf(f.velocity.y, 0.0) if _was_floor else minf(_fall_v, f.velocity.y)
	elif not _was_floor:
		var hard := -_fall_v - 10.0
		if hard > 0.0:
			_dip_v -= hard * t.cam_dip * 8.0
		_fall_v = 0.0
	_was_floor = on_floor

## Openness: a few rays out from you, every few frames.
func _probe(f: Node3D, _dt: float) -> void:
	_probe_n -= 1
	if _probe_n > 0:
		return
	_probe_n = 8
	var space := get_world_3d().direct_space_state
	var from := f.global_position + Vector3.UP * 1.0
	var sum := 0.0
	for i in 8:
		var a := TAU * i / 8.0
		sum += _ray_frac(space, from, from + Vector3(cos(a), 0, sin(a)) * 24.0, f)
	sum += 2.0 * _ray_frac(space, from, from + Vector3.UP * 20.0, f) # a roof counts double
	_probe_open = sum / 10.0
	# how far down the ground is (wider lens high up)
	var down := PhysicsRayQueryParameters3D.create(f.global_position, f.global_position + Vector3.DOWN * 80.0, 1, [player.get_rid(), (f as CollisionObject3D).get_rid()])
	var h := space.intersect_ray(down)
	drop = 80.0 if h.is_empty() else f.global_position.y - (h["position"] as Vector3).y

func _ray_frac(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, f: Node3D) -> float:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1, [player.get_rid(), (f as CollisionObject3D).get_rid()])
	var h := space.intersect_ray(q)
	return 1.0 if h.is_empty() else a.distance_to(h["position"]) / a.distance_to(b)

## Dolly zoom: at a cliff edge, off a big launch, over a big drop.
func _dolly_goal(f: CharacterBody3D, on_floor: bool, dt: float) -> float:
	if looking:
		return 0.0
	if player.launch_t < 0.05 and f.velocity.y > 18.0:
		_launch_pulse = 1.0
	_launch_pulse = maxf(_launch_pulse - dt / 1.2, 0.0)
	var goal := _launch_pulse
	if on_floor and Vector3(f.velocity.x, 0, f.velocity.z).length() < 6.0:
		var fw := player._flat_facing() if f == player else Vector3(f.velocity.x, 0, f.velocity.z).normalized()
		if fw != Vector3.ZERO:
			var at := f.global_position + fw * 1.6
			var q := PhysicsRayQueryParameters3D.create(at, at + Vector3.DOWN * 16.0, 1, [player.get_rid(), f.get_rid()])
			if get_world_3d().direct_space_state.intersect_ray(q).is_empty():
				goal = 1.0 # a sheer drop just ahead
	elif not on_floor and f.velocity.y < -4.0 and drop > 20.0:
		goal = maxf(goal, 0.5)
	return goal

## Is this collider thin (a tree, post, pole, rail, bar, a creature or a loose thing)? Thin things don't push
## the camera in; they fade.
func _thin(c: Object) -> bool:
	if c == null:
		return true
	var id := c.get_instance_id()
	if _thin_cache.has(id):
		return _thin_cache[id]
	var thin := false
	if c is CharacterBody3D or c is RigidBody3D:
		thin = true
	elif c is Node:
		var n := c as Node
		for g in ["trees", "trunks", "lash_posts", "rails", "carryable"]:
			if n.is_in_group(g):
				thin = true
		if not thin and c is CollisionObject3D:
			var co := c as CollisionObject3D
			if co.collision_layer & 1 == 0:
				thin = true # bars, railings, grates, props
			var shapes := 0
			var narrow := 0
			for ch in n.get_children():
				var cs := ch as CollisionShape3D
				if cs == null or cs.shape == null:
					continue
				shapes += 1
				var sh := cs.shape
				if sh is CylinderShape3D and (sh as CylinderShape3D).radius < 1.0:
					narrow += 1
				elif sh is CapsuleShape3D and (sh as CapsuleShape3D).radius < 1.0:
					narrow += 1
				elif sh is SphereShape3D and (sh as SphereShape3D).radius < 0.8:
					narrow += 1
				elif sh is BoxShape3D:
					var s := (sh as BoxShape3D).size
					var dims := [s.x, s.y, s.z]
					dims.sort()
					if dims[1] < 1.2:
						narrow += 1 # a pole or a beam: thin two ways
			if shapes > 0 and narrow == shapes:
				thin = true
	_thin_cache[id] = thin
	return thin

## How much of the way from a to b the camera's ball gets before hitting something solid (thin things skipped).
func _cast(a: Vector3, b: Vector3, f: CharacterBody3D) -> float:
	var space := get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _ball
	q.collision_mask = 1
	var ex: Array[RID] = [player.get_rid(), f.get_rid()]
	q.exclude = ex
	q.transform = Transform3D(Basis(), a)
	q.motion = b - a
	for i in 5:
		var r := space.cast_motion(q)
		if r[1] >= 1.0:
			return 1.0
		var at := PhysicsShapeQueryParameters3D.new()
		at.shape = _ball
		at.collision_mask = 1
		at.exclude = q.exclude
		at.transform = Transform3D(Basis(), a + (b - a) * r[1])
		var info := space.get_rest_info(at)
		if info.is_empty():
			return r[0]
		var col := instance_from_id(info["collider_id"])
		if _thin(col):
			ex.append(info["rid"])
			q.exclude = ex
			continue
		return r[0]
	return 1.0

## Thin things between the camera and you fade; anything there at all shows your outline.
func _fade_and_outline(f: Node3D, dt: float) -> void:
	var now := {}
	occluded = false
	if not looking and _len.x > 0.5:
		var space := get_world_3d().direct_space_state
		var ex: Array[RID] = [player.get_rid(), (f as CollisionObject3D).get_rid()]
		var from := cam.global_position
		var to := f.global_position
		for i in 4:
			var q := PhysicsRayQueryParameters3D.create(from, to, 1 | 1 << 1 | 1 << 2 | 1 << 4, ex)
			var h := space.intersect_ray(q)
			if h.is_empty():
				break
			var col := h["collider"] as Node
			ex.append(h["rid"])
			if col is CharacterBody3D or col is RigidBody3D:
				continue # creatures and loose things in the way don't count
			occluded = true
			if col != null and (_thin(col) or (col is CollisionObject3D and (col as CollisionObject3D).collision_layer & 1 == 0)):
				now[col] = true
	for n in now:
		if not faded.has(n):
			faded[n] = 0.0
	for n in faded.keys():
		if not is_instance_valid(n):
			faded.erase(n)
			continue
		var goal := 0.7 if now.has(n) else 0.0
		faded[n] = move_toward(faded[n], goal, dt * 4.0)
		_set_fade(n, faded[n])
		if faded[n] <= 0.0 and goal == 0.0:
			faded.erase(n)
	_ghost.visible = occluded and not looking
	if _ghost.visible:
		_ghost.global_position = f.global_position
		var r := player.radius() if f == player else Spider.RADIUS
		_ghost.scale = Vector3.ONE * r * 2.1

func _set_fade(n: Node, a: float) -> void:
	if n is GeometryInstance3D:
		(n as GeometryInstance3D).transparency = a
	for ch in n.get_children():
		if ch is GeometryInstance3D:
			(ch as GeometryInstance3D).transparency = a

## Blob shadow under you in the air, so you can tell where you'll land.
func _make_shadow() -> void:
	_shadow = MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(1, 1)
	_shadow.mesh = pm
	var g := Gradient.new()
	g.set_color(0, Color(0, 0, 0, 0.55))
	g.set_color(1, Color(0, 0, 0, 0.0))
	var gt := GradientTexture2D.new()
	gt.gradient = g
	gt.fill = GradientTexture2D.FILL_RADIAL
	gt.fill_from = Vector2(0.5, 0.5)
	gt.fill_to = Vector2(1.0, 0.5)
	gt.width = 64
	gt.height = 64
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = gt
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	_shadow.material_override = m
	_shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_shadow.top_level = true
	_shadow.visible = false
	add_child(_shadow)

func _update_shadow(f: CharacterBody3D, on_floor: bool) -> void:
	_shadow.visible = false
	if on_floor or looking:
		return
	var q := PhysicsRayQueryParameters3D.create(f.global_position, f.global_position + Vector3.DOWN * 60.0, 1, [player.get_rid(), f.get_rid()])
	var h := get_world_3d().direct_space_state.intersect_ray(q)
	if h.is_empty():
		return
	var n: Vector3 = h["normal"]
	var at: Vector3 = h["position"]
	var r := player.radius() if f == player else Spider.RADIUS
	var size := r * 2.2 * clampf(1.0 - (f.global_position.y - at.y) / 60.0, 0.4, 1.0)
	var x := n.cross(Vector3.FORWARD)
	if x.length() < 0.1:
		x = n.cross(Vector3.RIGHT)
	x = x.normalized()
	_shadow.global_transform = Transform3D(Basis(x, n, x.cross(n)).orthonormalized().scaled(Vector3(size, 1, size)), at + n * 0.04)
	_shadow.visible = true

## Your outline, drawn through walls while you're hidden.
func _make_ghost() -> void:
	_ghost = MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 16
	sm.rings = 8
	_ghost.mesh = sm
	var sh := Shader.new()
	sh.code = """shader_type spatial;
render_mode unshaded, depth_test_disabled, cull_back, blend_mix;
void fragment() {
	float rim = 1.0 - abs(dot(NORMAL, VIEW));
	ALBEDO = vec3(0.55, 0.8, 1.0);
	ALPHA = 0.12 + 0.75 * rim * rim;
}
"""
	var m := ShaderMaterial.new()
	m.shader = sh
	m.render_priority = 10
	_ghost.material_override = m
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_ghost.top_level = true
	_ghost.visible = false
	add_child(_ghost)

## The reticle: where the lash goes when you're not locked on. In third person the aim runs level when the
## camera sits at its usual angle; in first person it's straight where you look. It snaps to something the
## lash can catch near the middle of the screen.
func _update_aim(f: Node3D) -> void:
	aim_ok = false
	if (player.ai and not aim_always) or player.target != null or f != player:
		player.cam_aim = Vector3.ZERO
		return
	var ap := pitch if looking else clampf(pitch + tilt + 0.3, -0.6, 0.9)
	var dir := Basis(Vector3.UP, yaw) * Basis(Vector3.RIGHT, ap) * Vector3.FORWARD
	var from := cam.global_position if looking else f.global_position + Vector3.UP * 0.3 # third person: from you, the camera's way
	var reach := t.lash_range
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(from, from + dir * reach, 1 | 1 << 4, [player.get_rid()])
	var h := space.intersect_ray(q)
	var aim := from + dir * reach
	if not h.is_empty():
		aim = h["position"]
		aim_ok = _lashable(h["collider"])
	if not aim_ok:
		# snap to the catchable thing nearest the middle of the screen
		var best := deg_to_rad(6.0)
		for g in ["lash_posts", "monsters"]:
			for n in get_tree().get_nodes_in_group(g):
				var nn := n as Node3D
				if nn == null or not is_instance_valid(nn):
					continue
				var d := nn.global_position - from
				if d.length() > reach or d.length() < 0.5:
					continue
				var ang := d.angle_to(dir)
				if ang < best:
					best = ang
					aim = nn.global_position
					aim_ok = true
	player.cam_aim = aim

func _lashable(c: Object) -> bool:
	if c == null or not (c is Node):
		return false
	var n := c as Node
	return n.is_in_group("lash_posts") or n is Monster or n is Spider or (n is Seed and (n as Seed).loose())
