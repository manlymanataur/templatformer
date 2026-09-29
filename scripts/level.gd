extends Node3D
## Movement and camera test room, built in code so every measurement is explicit.
## Stations: ramps (10-60°), step heights, gap widths, boost pad into a loop, quarter pipe, lock-on targets.

var t: Tuning
var player: Player
var use_defaults := false ## tests set this so saved tuning doesn't change results
var marks := {} ## named positions the tests start from
var checker: ImageTexture

const LOOP_R := 6.0

func _ready() -> void:
	t = Tuning.new()
	if not use_defaults and ResourceLoader.exists("user://tuning.tres"):
		var saved = load("user://tuning.tres")
		if saved is Tuning:
			t = saved
	checker = _make_checker()
	_environment()
	_build()
	player = Player.new()
	player.t = t
	player.spawn = Vector3(0, 1, 0)
	add_child(player)
	player.global_position = player.spawn
	var rig := CameraRig.new()
	rig.player = player
	rig.t = t
	add_child(rig)
	var hud = preload("res://scripts/debug_hud.gd").new()
	hud.t = t
	hud.player = player
	add_child(hud)

func _make_checker() -> ImageTexture:
	var img := Image.create(2, 2, false, Image.FORMAT_RGB8)
	img.set_pixel(0, 0, Color(1, 1, 1)); img.set_pixel(1, 1, Color(1, 1, 1))
	img.set_pixel(1, 0, Color(0.82, 0.82, 0.82)); img.set_pixel(0, 1, Color(0.82, 0.82, 0.82))
	return ImageTexture.create_from_image(img)

func _material(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.albedo_texture = checker
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3(0.25, 0.25, 0.25) # 2 m squares
	return m

func _environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	var sky := Sky.new()
	sky.sky_material = ProceduralSkyMaterial.new()
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.shadow_enabled = true
	add_child(sun)

func box(pos: Vector3, size: Vector3, basis_: Basis, color: Color) -> StaticBody3D:
	var b := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = _material(color)
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	b.add_child(mi)
	b.add_child(c)
	add_child(b)
	b.global_transform = Transform3D(basis_, pos)
	return b

func label(pos: Vector3, text: String) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 12
	l.position = pos
	add_child(l)

func boost_pad(pos: Vector3, dir: Vector3) -> void:
	box(pos + Vector3(0, -0.49, 0), Vector3(4, 1, 3), Basis(), Color(1.0, 0.8, 0.2)) # flush with the floor
	var a := Area3D.new()
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(4, 1.5, 3)
	c.shape = s
	a.add_child(c)
	add_child(a)
	a.global_position = pos + Vector3(0, 0.5, 0)
	a.body_entered.connect(func(b): if b is Player: b.boost(dir))

func _mask_zone(pos: Vector3, size: Vector3, mask: int) -> void:
	var a := Area3D.new()
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	a.add_child(c)
	add_child(a)
	a.global_position = pos
	a.body_entered.connect(func(b): if b is Player: b.collision_mask = mask)

## Curved track: an arc of the circle with this centre, in the plane of fwd and up,
## from angle a0 to a1 (0 = bottom, 90 = far wall, 180 = top), drifting sideways by shift over a full turn.
func arc(center: Vector3, r: float, a0: float, a1: float, fwd: Vector3, shift: float, width: float, color: Color, layer := 1) -> void:
	var side := fwd.cross(Vector3.UP).normalized()
	var steps := int(ceil(absf(a1 - a0) / 7.5))
	for k in steps:
		var th := deg_to_rad(lerpf(a0, a1, (k + 0.5) / steps))
		var inward := Vector3.UP * cos(th) + fwd * -sin(th) # points at the centre
		var p := center - inward * r + side * shift * th / TAU
		var tangent := fwd * cos(th) + Vector3.UP * sin(th)
		var seg := 2.0 * PI * r * absf(a1 - a0) / 360.0 / steps * 1.12
		var b := Basis(side, inward, -tangent)
		box(p - inward * 0.25, Vector3(width, 0.5, seg), b.orthonormalized(), color).collision_layer = layer

func _build() -> void:
	box(Vector3(0, -0.5, 0), Vector3(240, 1, 240), Basis(), Color(0.55, 0.75, 0.5))
	label(Vector3(0, 3, -4), "Hold forward: boost pad, then loop")

	# Ramps along +X, rising toward -Z
	var ang := [10, 20, 30, 45, 60]
	for i in ang.size():
		var a := deg_to_rad(ang[i])
		var L := 12.0
		var x := 16.0 + i * 8.0
		var b := Basis(Vector3.RIGHT, a)
		var c := Vector3(x, L / 2.0 * sin(a) - 0.25 * cos(a), -6.0 - L / 2.0 * cos(a))
		box(c, Vector3(5, 0.5, L), b, Color(0.85, 0.6, 0.45))
		label(Vector3(x, 2.5, -4), "%d°" % ang[i])
		marks["ramp%d" % ang[i]] = Vector3(x, 0.6, 0.0)
		marks["ramp%d_top" % ang[i]] = L * sin(a)

	# Step heights along -X
	var hs := [0.5, 1.0, 1.5, 2.0, 2.5, 3.0]
	for i in hs.size():
		var x := -14.0 - i * 5.0
		box(Vector3(x, hs[i] / 2.0, -8.0), Vector3(3, hs[i], 3), Basis(), Color(0.6, 0.6, 0.75))
		label(Vector3(x, hs[i] + 1.0, -8.0), "%.1f m" % hs[i])
		marks["step%.1f" % hs[i]] = Vector3(x, 0.6, -4.0)
		marks["step%.1f_h" % hs[i]] = hs[i]

	# Gap course: 4 m tall columns along -X at z = +24, gaps grow
	var gaps := [2.0, 4.0, 6.0, 8.0, 10.0, 12.0]
	var x := -6.0
	box(Vector3(x, 2.0, 24.0), Vector3(6, 4, 4), Basis(), Color(0.7, 0.55, 0.8))
	label(Vector3(x, 5.5, 24.0), "gaps")
	for g in gaps:
		var edge := x - 3.0
		marks["gap%d" % int(g)] = Vector3(edge + 6.0, 4.6, 24.0) # start 6 m back from the edge, running -X
		x = edge - g - 3.0
		box(Vector3(x, 2.0, 24.0), Vector3(6, 4, 4), Basis(), Color(0.7, 0.55, 0.8))
		label(Vector3(x + 3.0 + g / 2.0, 5.5, 24.0), "%d m" % int(g))
	marks["gap_y"] = 4.0

	# Boost pad into a loop along -Z
	boost_pad(Vector3(0, 0, -30), Vector3.FORWARD)
	# Sonic's layer trick: the way up (layer 2) and the way down (layer 3) are solid at different times,
	# so the loop's lower back half doesn't block you on the way in, nor the front half on the way out.
	arc(Vector3(0, LOOP_R, -60), LOOP_R, 0.0, 180.0, Vector3.FORWARD, 0.0, 4.0, Color(0.5, 0.7, 0.95), 2)
	arc(Vector3(0, LOOP_R, -60), LOOP_R, 180.0, 360.0, Vector3.FORWARD, 0.0, 4.0, Color(0.45, 0.62, 0.9), 4)
	_mask_zone(Vector3(0, 2.0 * LOOP_R - 1.0, -60), Vector3(4, 2, 3), 1 | 4) # at the top: switch to the way down
	_mask_zone(Vector3(0, 1, -48), Vector3(4, 2, 2), 1 | 2) # before the loop: reset
	_mask_zone(Vector3(0, 1, -72), Vector3(4, 2, 2), 1 | 2) # after the loop: reset
	marks["loop_start"] = Vector3(0, 0.6, -20)

	# Quarter pipe facing +Z, off to the side
	boost_pad(Vector3(-40, 0, -30), Vector3.FORWARD)
	arc(Vector3(-40, 7.0, -50), 7.0, 0.0, 90.0, Vector3.FORWARD, 0.0, 6.0, Color(0.95, 0.6, 0.6))
	label(Vector3(-40, 4, -32), "quarter pipe")
	marks["pipe_start"] = Vector3(-40, 0.6, -20)

	# Lock-on targets
	for p in [Vector3(-8, 0, 10), Vector3(-2, 0, 14), Vector3(5, 0, 11)]:
		var post := box(p + Vector3(0, 0.75, 0), Vector3(0.4, 1.5, 0.4), Basis(), Color(0.5, 0.35, 0.25))
		var head := MeshInstance3D.new()
		var sm := SphereMesh.new()
		sm.radius = 0.45
		sm.height = 0.9
		head.mesh = sm
		var hm := StandardMaterial3D.new()
		hm.albedo_color = Color(0.9, 0.2, 0.2)
		head.material_override = hm
		head.position = Vector3(0, 1.0, 0)
		post.add_child(head)
		post.add_to_group("targets")
	label(Vector3(-2, 3, 12), "hold Shift / Z to lock on")
	marks["targets"] = Vector3(-2, 0.6, 5)
