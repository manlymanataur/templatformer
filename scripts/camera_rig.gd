class_name CameraRig
extends Node3D
## Third-person orbit camera. Mouse or right stick to orbit; after a short idle it swings behind
## your motion. While locked on, it frames you and the target like Ocarina's Z-targeting.

var player: Player
var t: Tuning
var yaw := 0.0
var pitch := -0.3
var idle := 0.0
var arm: SpringArm3D
var cam: Camera3D

func _ready() -> void:
	arm = SpringArm3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.3
	arm.shape = s
	arm.add_excluded_object(player.get_rid())
	add_child(arm)
	cam = Camera3D.new()
	cam.fov = 70.0
	arm.add_child(cam)
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
	global_position = global_position.lerp(player.global_position + Vector3.UP * 1.0, clampf(t.cam_lag * dt, 0.0, 1.0))
	var hv := Vector3(player.velocity.x, 0, player.velocity.z)
	if player.target != null:
		var d := player.target.global_position - player.global_position
		yaw = lerp_angle(yaw, atan2(-d.x, -d.z), clampf(8.0 * dt, 0.0, 1.0))
	elif idle > t.cam_recenter_delay and hv.length() > 4.0:
		yaw = lerp_angle(yaw, atan2(-hv.x, -hv.z), clampf(1.5 * dt, 0.0, 1.0))
	rotation = Vector3(pitch, yaw, 0)
	arm.spring_length = t.cam_distance
	player.cam_basis = Basis(Vector3.UP, yaw)
