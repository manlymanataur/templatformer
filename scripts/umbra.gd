class_name Umbra
extends CharacterBody3D
## Umbra, the mirrored ghost. It moves when you move: along the mirror line the same way you go,
## across it the opposite way (the line is the camera's left-right when you call it, snapped to the room's axes).
## Walls stop it separately from you, so you can pin yourself against a wall and keep steering it.
## In the dark it floats, holding its height, and can drift out over a chasm. In light it goes limp:
## it drops to the ground and crawls slowly. Once light knocks it out of the air it falls all the way down,
## even if it falls back into shadow. If it drops into a chasm it fades, and you can call it again.

var player: Player
var t: Tuning
var mirror := Vector3.RIGHT ## movement along this axis is reversed
var lit := false
var falling := false
var home_y := 0.0 ## the height it was called at; falling well below it means it fell into a chasm
var _vis: Node3D
var _mat: StandardMaterial3D
var _t := 0.0
var _scale := Vector3.ONE
var _dir := Vector3.FORWARD

static func summon(p: Player) -> Umbra:
	var u := Umbra.new()
	u.player = p
	u.t = p.t
	var r := p.cam_basis * Vector3.RIGHT
	u.mirror = Vector3(signf(r.x), 0, 0) if absf(r.x) >= absf(r.z) else Vector3(0, 0, signf(r.z))
	p.get_parent().add_child(u)
	u.global_position = p.global_position + u.mirror * 1.5
	u.home_y = u.global_position.y
	return u

func _ready() -> void:
	collision_layer = 1 << 3 # only moon plates notice it; it doesn't block you or the light
	collision_mask = 1
	floor_snap_length = 0.3
	var c := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.4
	c.shape = s
	add_child(c)
	_vis = Node3D.new()
	add_child(_vis)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.35, 0.27, 0.7, 0.85)
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.emission_enabled = true
	_mat.emission = Color(0.45, 0.38, 1.0)
	_mat.emission_energy_multiplier = 0.6
	var head := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.4
	hm.height = 0.8
	head.mesh = hm
	head.material_override = _mat
	_vis.add_child(head)
	var tail := MeshInstance3D.new()
	var tm := CylinderMesh.new()
	tm.top_radius = 0.4
	tm.bottom_radius = 0.05
	tm.height = 0.6
	tail.mesh = tm
	tail.material_override = _mat
	tail.position.y = -0.35
	_vis.add_child(tail)
	var eyes := StandardMaterial3D.new()
	eyes.albedo_color = Color(0.9, 0.88, 1.0)
	eyes.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	for sx in [-0.14, 0.14]:
		var e := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.07
		em.height = 0.14
		e.mesh = em
		e.material_override = eyes
		e.position = Vector3(sx, 0.08, -0.34)
		_vis.add_child(e)

## Your movement, mirrored across the mirror axis.
func mirrored(v: Vector3) -> Vector3:
	return v - 2.0 * mirror * v.dot(mirror)

func _physics_process(dt: float) -> void:
	_t += dt
	lit = Lighting.is_lit(global_position, self, [get_rid()])
	var wish := mirrored(player.last_wish)
	var top := t.umbra_crawl_speed if lit else t.umbra_speed
	var hv := Vector3(velocity.x, 0, velocity.z).move_toward(wish * top, 60.0 * dt)
	velocity.x = hv.x
	velocity.z = hv.z
	# light knocks it out of the air, and once it's falling it keeps falling until it lands
	if lit and not is_on_floor():
		falling = true
	if lit or falling:
		velocity.y -= t.gravity * dt
	else:
		velocity.y = 0.0 # floats: holds whatever height it has
	move_and_slide()
	if is_on_floor():
		falling = false
	if global_position.y < home_y - 2.5:
		fade()
		return
	# look: floats and bobs in the dark, squashed flat and dim in light
	var want := Vector3(1.5, 0.45, 1.5) if lit else Vector3.ONE
	_scale = _scale.lerp(want, 10.0 * dt)
	if hv.length() > 0.3:
		_dir = hv.normalized()
	_vis.basis = Basis.looking_at(_dir, Vector3.UP).scaled(_scale)
	_vis.position.y = -0.2 if lit else sin(_t * 3.0) * 0.08
	_mat.emission_energy_multiplier = 0.15 if lit else 0.6

func fade() -> void:
	if player != null and player.umbra == self:
		player.umbra = null
		player.inventory.changed.emit()
	queue_free()
