class_name CameraRig
extends Node3D
## Third-person orbit camera. Mouse or right stick to orbit; after a short idle it swings behind
## your motion. While locked on, it frames you and the target like Ocarina's Z-targeting.
## Speed shows (jovi, 2026-10-04): past top_speed the view widens (ski_fov), the camera rises (ski_cam_rise) and
## pulls back, speed lines stream past and the view trembles, all on one dial (speed_k). Skiing, it follows
## behind your line at once and rolls a little with your lean.

var player: Player
var t: Tuning
var yaw := 0.0
var pitch := -0.3
var idle := 0.0
var zoom := 1.0
var arm: SpringArm3D
var cam: Camera3D
var shake := 0.0 ## metres of random jitter, decaying (see Hitfx.shake)
var speed_k := 0.0 ## 0 at top_speed or slower, 1 at boost_speed: drives the view, height, pull-back and speed lines
var lines: CPUParticles3D

func _ready() -> void:
	add_to_group("camera_rig")
	arm = SpringArm3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.3
	arm.shape = s
	arm.add_excluded_object(player.get_rid())
	add_child(arm)
	cam = Camera3D.new()
	cam.fov = 70.0
	arm.add_child(cam)
	lines = CPUParticles3D.new() # speed lines: thin streaks rushing past the lens
	lines.emitting = false
	lines.amount = 48
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
	global_position = player.global_position

func _unhandled_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif e is InputEventKey and e.pressed and e.physical_keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif e is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= e.relative.x * 0.004
		pitch = clampf(pitch - e.relative.y * 0.004, -1.2, 0.4)
		idle = 0.0

func _physics_process(dt: float) -> void:
	var look := Input.get_vector("cam_left", "cam_right", "cam_up", "cam_down")
	if look.length() > 0.1:
		yaw -= look.x * 2.5 * dt
		pitch = clampf(pitch - look.y * 2.0 * dt, -1.2, 0.4)
		idle = 0.0
	else:
		idle += dt
	var small := player.small or player.pilot != null # pull in close when you're small or steering the spider
	zoom = lerpf(zoom, t.small_scale * 1.6 if small else 1.0, clampf(4.0 * dt, 0.0, 1.0))
	var f := player.focus() as CharacterBody3D
	var k := clampf((f.velocity.length() - t.top_speed) / maxf(t.boost_speed - t.top_speed, 0.1), 0.0, 1.0)
	speed_k = lerpf(speed_k, k, clampf(3.0 * dt, 0.0, 1.0))
	global_position = global_position.lerp(f.global_position + Vector3.UP * (zoom + t.ski_cam_rise * speed_k), clampf(t.cam_lag * dt, 0.0, 1.0))
	var hv := Vector3(f.velocity.x, 0, f.velocity.z)
	var to_target := Vector3.ZERO
	if player.target != null:
		to_target = player.target.global_position - player.global_position
		to_target.y = 0.0
	if player.target != null and to_target.length() < 2.0:
		pass # right above or below the target (bouncing off it): hold still rather than spin round
	elif player.target != null:
		yaw = lerp_angle(yaw, atan2(-to_target.x, -to_target.z), clampf(8.0 * dt, 0.0, 1.0))
	elif player.strafing:
		# Ocarina's parallel targeting: swing behind the way you're locked facing
		yaw = lerp_angle(yaw, atan2(-player.lock_dir.x, -player.lock_dir.z), clampf(10.0 * dt, 0.0, 1.0))
	elif player.surfing and hv.length() > 4.0 and idle > 0.3:
		yaw = lerp_angle(yaw, atan2(-hv.x, -hv.z), clampf(4.0 * dt, 0.0, 1.0)) # skiing: stay behind your line
	elif idle > t.cam_recenter_delay and hv.length() > 4.0:
		yaw = lerp_angle(yaw, atan2(-hv.x, -hv.z), clampf(1.5 * dt, 0.0, 1.0))
	rotation = Vector3(pitch - 0.12 * speed_k, yaw, 0)
	arm.spring_length = t.cam_distance * zoom * (1.0 + speed_k / 3.0)
	cam.fov = 70.0 + t.ski_fov * speed_k
	cam.rotation.z = lerpf(cam.rotation.z, -player.ski_lean * 0.06 if player.surfing else 0.0, clampf(6.0 * dt, 0.0, 1.0))
	lines.emitting = speed_k > 0.15
	shake = maxf(shake, 0.03 * maxf(speed_k - 0.5, 0.0))
	player.cam_basis = Basis(Vector3.UP, yaw)
	shake = maxf(shake - dt * 0.8, 0.0)
	cam.h_offset = randf_range(-1.0, 1.0) * shake
	cam.v_offset = randf_range(-1.0, 1.0) * shake
