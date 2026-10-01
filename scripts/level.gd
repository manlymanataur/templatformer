extends Node3D
## Movement and camera test room, built in code so every measurement is explicit.
## Stations: ramps (10-60°), step heights, gap widths, boost pad into a quarter pipe, lock-on targets,
## item pickups and a monster arena.

var t: Tuning
var player: Player
var use_defaults := false ## tests set this so saved tuning doesn't change results
var marks := {} ## named positions the tests start from
var checker: ImageTexture
var dev: Node ## the playtest tools (dev_menu.gd): warps, pins, god mode


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
	var game_hud = preload("res://scripts/game_hud.gd").new()
	game_hud.player = player
	add_child(game_hud)
	var hud = preload("res://scripts/debug_hud.gd").new()
	hud.t = t
	hud.player = player
	add_child(hud)
	dev = preload("res://scripts/dev_menu.gd").new()
	dev.level = self
	dev.player = player
	dev.rig = rig
	add_child(dev)

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
	sun.add_to_group("sun") # the sun counts as light for Umbra (see Lighting)
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

func label(pos: Vector3, text: String, size := 64) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = size
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.outline_size = 12
	l.position = pos
	add_child(l)

func boost_pad(pos: Vector3, dir: Vector3) -> void:
	Pad.make(self, "boost", pos, dir, Vector3(4, 1, 3))

func launch_pad(pos: Vector3, v: Vector3) -> void:
	Pad.make(self, "launch", pos, v, Vector3(2.4, 1, 2.4))

## Curved track: an arc of the circle with this centre, in the plane of fwd and up,
## from angle a0 to a1 (0 = bottom, 90 = far wall, 180 = top), drifting sideways by shift over a full turn.
func arc(center: Vector3, r: float, a0: float, a1: float, fwd: Vector3, shift: float, width: float, color: Color) -> void:
	var side := fwd.cross(Vector3.UP).normalized()
	var steps := int(ceil(absf(a1 - a0) / 7.5))
	for k in steps:
		var th := deg_to_rad(lerpf(a0, a1, (k + 0.5) / steps))
		var inward := Vector3.UP * cos(th) + fwd * -sin(th) # points at the centre
		var p := center - inward * r + side * shift * th / TAU
		var tangent := fwd * cos(th) + Vector3.UP * sin(th)
		var seg := 2.0 * PI * r * absf(a1 - a0) / 360.0 / steps * 1.12
		var b := Basis(side, inward, -tangent)
		box(p - inward * 0.25, Vector3(width, 0.5, seg), b.orthonormalized(), color)

## The 240 m ground slab (1 m thick, top at y 0), leaving out the holes (x, z, width, depth).
func _ground(holes: Array) -> void:
	var xs := _cuts(holes, true)
	var zs := _cuts(holes, false)
	for j in zs.size() - 1:
		var z0: float = zs[j]
		var z1: float = zs[j + 1]
		var run := -1 # solid cells along x merge into one box per row
		for i in xs.size():
			var solid := i < xs.size() - 1
			if solid:
				var mid := Vector2((xs[i] + xs[i + 1]) / 2.0, (z0 + z1) / 2.0)
				for h in holes:
					solid = solid and not (h as Rect2).has_point(mid)
			if solid and run < 0:
				run = i
			elif not solid and run >= 0:
				var xa: float = xs[run]
				var xb: float = xs[i]
				box(Vector3((xa + xb) / 2.0, -0.5, (z0 + z1) / 2.0), Vector3(xb - xa, 1, z1 - z0), Basis(), Color(0.55, 0.75, 0.5))
				run = -1

## Sorted, de-duplicated edges of the holes along x (or z), plus the slab's own edges.
func _cuts(holes: Array, along_x: bool) -> Array:
	var v := [-120.0, 120.0]
	for h in holes:
		var r: Rect2 = h
		v.append(r.position.x if along_x else r.position.y)
		v.append(r.end.x if along_x else r.end.y)
	v.sort()
	var out := []
	for x in v:
		if out.is_empty() or float(x) - float(out[-1]) > 0.01:
			out.append(x)
	return out

func _build() -> void:
	_ground(ScaleGarden.GROUND_HOLES)
	label(Vector3(0, 3, -4), "Hold forward: boost pad, then quarter pipe")

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
	# 2 m = a normal jump, 3 m = double jump, 4.5 m = running triple jump
	var hs := [2.0, 3.0, 4.5]
	var how := ["jump", "double jump", "triple jump"]
	for i in hs.size():
		var x := -14.0 - i * 8.0
		box(Vector3(x, hs[i] / 2.0, -8.0), Vector3(4, hs[i], 4), Basis(), Color(0.6, 0.6, 0.75))
		label(Vector3(x, hs[i] + 1.0, -8.0), "%.1f m: %s" % [hs[i], how[i]])
		marks["step%.1f" % hs[i]] = Vector3(x, 0.6, -4.0)
		marks["step%.1f_h" % hs[i]] = hs[i]

	# Gap course: 1 m tall platforms along -X at z = +24. 6 and 8 m are comfortable running jumps,
	# 10 m needs full speed, 12 m needs a running triple jump. Fall in and you can walk back out.
	var gaps := [6.0, 8.0, 10.0, 12.0]
	var x := -6.0
	box(Vector3(x, 0.5, 24.0), Vector3(6, 1, 4), Basis(), Color(0.7, 0.55, 0.8))
	label(Vector3(x, 2.5, 24.0), "gaps")
	var half := 3.0 # half length of the platform you're standing on
	for g in gaps:
		var edge := x - half
		marks["gap%d" % int(g)] = Vector3(edge + half * 2.0, 1.6, 24.0) # start at the back of the platform, running -X
		marks["gap%d_edge" % int(g)] = edge
		# the platform before the 12 m gap is a 30 m runway: room for two chain hops before the edge
		half = 15.0 if g == 10.0 else 3.0
		x = edge - g - half
		box(Vector3(x, 0.5, 24.0), Vector3(half * 2.0, 1, 4), Basis(), Color(0.7, 0.55, 0.8))
		label(Vector3(edge - g / 2.0, 2.5, 24.0), "%d m" % int(g) + (" (triple jump)" if g > 10.0 else ""))
	marks["gap_y"] = 1.0

	# Wall-jump shaft: a 3 m gap between a wall and a 10 m block. Kick back and forth to the top.
	box(Vector3(-2.0, 5.0, -40), Vector3(1, 10, 4), Basis(), Color(0.55, 0.65, 0.8))
	box(Vector3(4.5, 5.0, -40), Vector3(6, 10, 4), Basis(), Color(0.55, 0.65, 0.8))
	label(Vector3(1.0, 11.5, -40), "wall jump up")
	marks["shaft"] = Vector3(0.0, 0.6, -40)
	marks["shaft_top"] = 10.0

	# Launch pads: straight up onto a 6 m platform, and a long arc to a platform 14 m away
	launch_pad(Vector3(14, 0, -41.8), Vector3(0, 20, -4))
	box(Vector3(14, 3, -47), Vector3(6, 6, 6), Basis(), Color(0.5, 0.8, 0.8))
	label(Vector3(14, 3, -40), "launch pad")
	marks["pad_up"] = Vector3(14, 0.6, -38)
	launch_pad(Vector3(26, 0, -40), Vector3(0, 16, -16))
	box(Vector3(26, 0.5, -58), Vector3(6, 1, 6), Basis(), Color(0.5, 0.8, 0.8))
	label(Vector3(26, 3, -38), "launch across")
	marks["pad_far"] = Vector3(26, 0.6, -36)

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

	# Item pickups near the start
	Pickup.spawn(self, "poleaxe", 1, Vector3(4, 0.8, 4))
	label(Vector3(4, 2.4, 4), "poleaxe & shield")
	BombFlower.make(self, Vector3(8, 0, 4), t)
	label(Vector3(8, 2.4, 4), "bomb plant (E)")
	Pickup.spawn(self, "potion", 1, Vector3(12, 0.8, 4))
	label(Vector3(12, 2.4, 4), "potion")
	marks["pickups"] = Vector3(4, 0.6, 8)

	# Monster arena
	box(Vector3(34, 0.1, 40), Vector3(22, 0.2, 22), Basis(), Color(0.75, 0.7, 0.55))
	label(Vector3(34, 3, 28), "monsters")
	Monster.spawn(self, Vector3(30, 1, 40))
	Monster.spawn(self, Vector3(38, 1, 36), "shield")
	Monster.spawn(self, Vector3(36, 1, 45), "blob", true)

	ShadowHall.build(self)
	LodestoneYard.build(self)
	ScaleGarden.build(self)
	Rootworks.build(self)
	MovesYard.build(self)
	Challenge.build(self)
	Colossus.build(self)
	CombatYard.build(self)
	Works.build(self)
	add_child(Power.new())
	add_child(Machinery.new())
	marks["targets"] = Vector3(-2, 0.6, 5)
