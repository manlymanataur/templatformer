class_name Umbra
extends CharacterBody3D
## Umbra, the mirrored ghost. It moves when you move: along the mirror line the same way you go,
## across it the opposite way (the line is the camera's left-right when you call it, snapped to the room's axes).
## It appears 1.5 m in front of you, as the camera sees it.
## Walls stop it separately from you, so you can pin yourself against a wall and keep steering it.
## In the dark it floats, holding its height, and can drift out over a chasm. In light it goes limp:
## it drops to the ground and crawls slowly. Once light knocks it out of the air it falls all the way down,
## even if it falls back into shadow.
## It carries a greatsword and copies each of your spear moves (mirrored) while it's in the dark.
## Lit, it's too limp to swing. If it drops into a chasm it fades, and you can call it again.

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
var swing_t := 0.0 ## time left in the current greatsword swing
var swing_move := ""
var _hit: Array = []
var _sword: Node3D

const SWING_TIME := 0.45
const SWING_FROM := 0.08
const SWING_TO := 0.32
const SWING_DAMAGE := 2

static func summon(p: Player) -> Umbra:
	var u := Umbra.new()
	u.player = p
	u.t = p.t
	var r := p.cam_basis * Vector3.RIGHT
	u.mirror = Vector3(signf(r.x), 0, 0) if absf(r.x) >= absf(r.z) else Vector3(0, 0, signf(r.z))
	p.get_parent().add_child(u)
	# it appears in front of you (the camera's forward, snapped the same way), on the line you don't mirror,
	# or just short of a wall if one is closer
	var fwd := Vector3.UP.cross(u.mirror)
	var at := p.global_position + fwd * 1.5
	var q := PhysicsRayQueryParameters3D.create(p.global_position, at, 1, [p.get_rid()])
	var hit := p.get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		at = (hit["position"] as Vector3) - fwd * 0.45
	u.global_position = at
	u.home_y = u.global_position.y
	p.spear.move_started.connect(u.copy_attack)
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
	_sword = Node3D.new()
	add_child(_sword)
	var blade := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.14, 0.05, 1.9)
	blade.mesh = bm
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.55, 0.5, 0.85, 0.9)
	steel.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	steel.emission_enabled = true
	steel.emission = Color(0.5, 0.45, 1.0)
	steel.emission_energy_multiplier = 0.8
	blade.material_override = steel
	blade.position = Vector3(0, 0, -1.25)
	_sword.add_child(blade)
	var guard := MeshInstance3D.new()
	var gm := BoxMesh.new()
	gm.size = Vector3(0.45, 0.07, 0.08)
	guard.mesh = gm
	guard.material_override = steel
	guard.position = Vector3(0, 0, -0.3)
	_sword.add_child(guard)

## Umbra's mirror of the way you face.
func facing() -> Vector3:
	var f := mirrored(player._flat_facing())
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD

## Your spear started a move: swing the greatsword too, unless light has it limp.
func copy_attack(move: String) -> void:
	if lit:
		return
	swing_move = move
	swing_t = SWING_TIME
	_hit.clear()

func _swing(dt: float) -> void:
	var f := facing()
	var base := Basis.looking_at(f, Vector3.UP)
	if swing_t <= 0.0:
		# at rest: held low at its side
		_sword.basis = base * Basis(Vector3.UP, -0.9) * Basis(Vector3.RIGHT, -0.5)
		_sword.position = Vector3(0, -0.1, 0)
		return
	swing_t -= dt
	var k := 1.0 - swing_t / SWING_TIME
	var yaw := k * TAU if swing_move == "spin" else lerpf(1.6, -1.6, k)
	_sword.basis = base * Basis(Vector3.UP, yaw)
	_sword.position = Vector3.ZERO
	var t := SWING_TIME - swing_t
	if t < SWING_FROM or t > SWING_TO:
		return
	var q := PhysicsShapeQueryParameters3D.new()
	if swing_move == "spin":
		var sph := SphereShape3D.new()
		sph.radius = 2.8
		q.shape = sph
		q.transform = Transform3D(Basis(), global_position)
	else:
		var box := BoxShape3D.new()
		box.size = Vector3(3.4, 1.6, 2.6)
		q.shape = box
		q.transform = Transform3D(base, global_position + f * 1.4)
	q.exclude = [get_rid(), player.get_rid()]
	for r in get_world_3d().direct_space_state.intersect_shape(q, 16):
		var c = r["collider"]
		if c != null and c != player and c.is_in_group("hurtable") and not _hit.has(c):
			_hit.append(c)
			c.hurt(SWING_DAMAGE, global_position)

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
	if lit:
		swing_t = 0.0 # light knocks the swing out of it
	_swing(dt)

func fade() -> void:
	if player != null and player.umbra == self:
		player.umbra = null
		player.inventory.changed.emit()
	queue_free()
