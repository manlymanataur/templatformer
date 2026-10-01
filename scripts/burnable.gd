class_name Burnable
extends StaticBody3D
## Vines (a solid wall) and grass (ground cover you walk through). Heat sets them alight; they burn
## for a moment, shining and spreading fire to whatever they touch, then vines are gone and grass is ash.
## They follow the plant rules (Plants): vines are climbable and lash posts as well as flammable.
## With regrow > 0 burnt vines and grass grow back after that many seconds (the moves yard's climbing wall).
## Powers book: grass waits t.fire_spread_delay after catching before it spreads, so fire walks across a field
## of small patches (field() lays 1 m ones) cell by cell. Burning grass hurts monsters standing in it (1 every
## t.fire_damage_every) but never you: your own fire attacks are safe to fight in.
## Water puts a fire out (douse) and keeps them wet: wet things don't catch for wet_time.

var kind := "grass" ## "grass" or "vines"
var size := Vector3(2, 0.3, 2)
var burning := false
var burnt := false
var wet := 0.0 ## seconds left before water dries off it; wet, it won't catch
var regrow := 0.0 ## seconds until a burnt one grows back; 0 never
var _regrow_t := 0.0
var _col: CollisionShape3D
var _warm := 0.0
var _left := 0.0
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _flames: Node3D
var _age := 0.0 ## seconds since it caught
var _sear := 0.0 ## countdown to the next burn on monsters standing in it

const IGNITE := {"grass": 0.05, "vines": 0.15} ## seconds of heat before it catches
const BURN := {"grass": 2.0, "vines": 1.5}
const SPREAD_REACH := 0.6

static func make(parent: Node, k: String, pos: Vector3, sz: Vector3, regrow_after := 0.0) -> Burnable:
	var b := Burnable.new()
	b.kind = k
	b.size = sz
	b.regrow = regrow_after
	parent.add_child(b)
	b.global_position = pos
	return b

## A field of nx by nz grass patches, cell metres square, from its min corner (y is the ground).
static func field(parent: Node, corner: Vector3, nx: int, nz: int, cell := 1.0) -> Array[Burnable]:
	var out: Array[Burnable] = []
	for i in nx:
		for j in nz:
			out.append(make(parent, "grass", corner + Vector3((i + 0.5) * cell, 0, (j + 0.5) * cell), Vector3(cell, 0.3, cell)))
	return out

static func flame_mesh(h: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PrismMesh.new()
	pm.size = Vector3(h * 0.5, h, h * 0.5)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.55, 0.15)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.5, 0.1)
	m.emission_energy_multiplier = 3.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	return mi

func _ready() -> void:
	Plants.mark(self, "vine" if kind == "vines" else "grass") # flammable; vines also climbable and lash posts
	add_to_group("light_sources")
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	_mesh.mesh = bm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.3, 0.6, 0.25) if kind == "grass" else Color(0.18, 0.42, 0.22)
	_mesh.material_override = _mat
	_mesh.position.y = size.y / 2.0
	add_child(_mesh)
	if kind == "vines":
		_col = CollisionShape3D.new()
		var s := BoxShape3D.new()
		s.size = size
		_col.shape = s
		_col.position.y = size.y / 2.0
		add_child(_col)
	else:
		collision_layer = 0 # you walk through grass, and it doesn't block light
		collision_mask = 0
	_flames = Node3D.new()
	_flames.visible = false
	add_child(_flames)
	var n := maxi(1, int(size.x * size.z / 2.0))
	for i in n:
		var f := flame_mesh(0.9 if kind == "grass" else 1.4)
		f.position = Vector3(randf_range(-0.4, 0.4) * size.x, (0.45 if kind == "grass" else size.y * randf_range(0.2, 0.8)), randf_range(-0.4, 0.4) * size.z)
		_flames.add_child(f)

func heat(dt: float) -> void:
	if burning or burnt or wet > 0.0:
		return
	_warm += dt
	if _warm >= IGNITE[kind]:
		ignite()

func ignite() -> void:
	if burning or burnt:
		return
	burning = true
	_left = BURN[kind]
	_age = 0.0
	_sear = 0.0
	_flames.visible = true

## Water on it: a fire goes out (what's burnt stays burnt), and it stays wet for a while.
func douse() -> void:
	if burning:
		burning = false
		_flames.visible = false
	_warm = 0.0
	wet = Liquids.tuning(get_tree()).wet_time

func _physics_process(dt: float) -> void:
	if wet > 0.0:
		wet -= dt
	if burnt and regrow > 0.0:
		_regrow_t += dt
		if _regrow_t >= regrow:
			_grow_back()
		return
	if not burning:
		return
	_age += dt
	var tn := _tuning()
	if kind == "vines" or _age >= (tn.fire_spread_delay if tn != null else 0.0):
		Lighting.spread_heat(global_position + Vector3.UP * 0.3, SPREAD_REACH + maxf(size.x, size.z) / 2.0, dt, self, self)
	if kind == "grass":
		_sear -= dt
		if _sear <= 0.0:
			_sear = tn.fire_damage_every if tn != null else 0.5
			_burn_monsters()
	_left -= dt
	if _left <= 0.0:
		burning = false
		burnt = true
		_regrow_t = 0.0
		if kind == "vines" and regrow > 0.0:
			_mesh.visible = false
			_col.set_deferred("disabled", true)
			_flames.visible = false
		elif kind == "vines":
			queue_free()
		else:
			_flames.visible = false
			_mat.albedo_color = Color(0.15, 0.13, 0.12)

func _grow_back() -> void:
	burnt = false
	_warm = 0.0
	_mesh.visible = true
	_mat.albedo_color = Color(0.3, 0.6, 0.25) if kind == "grass" else Color(0.18, 0.42, 0.22)
	if _col != null:
		_col.set_deferred("disabled", false)

# light source: burning things light the room
func is_shining() -> bool:
	return burning
func light_origin() -> Vector3:
	return global_position + Vector3.UP * (0.8 if kind == "grass" else size.y * 0.5)
func light_reach() -> float:
	return 6.0

func heat_box() -> AABB:
	return AABB(global_position - Vector3(size.x / 2.0, 0, size.z / 2.0), size)

func _tuning() -> Tuning:
	var ps := get_tree().get_nodes_in_group("player")
	return (ps[0] as Player).t if not ps.is_empty() else null

## Monsters standing in the flames take 1 (once per t.fire_damage_every however many patches they stand on).
## The player is never burnt by fire.
func _burn_monsters() -> void:
	var box := heat_box().grow(0.3)
	box.size.y = 2.0
	var now := Engine.get_physics_frames()
	var tn := _tuning()
	var every := int((tn.fire_damage_every if tn != null else 0.5) * Engine.physics_ticks_per_second)
	for n in get_tree().get_nodes_in_group("monsters"):
		var m := n as Monster
		if m == null or not box.has_point(m.global_position):
			continue
		if now - int(m.get_meta("burnt_f", -100000)) < every:
			continue
		m.set_meta("burnt_f", now)
		m.strike(1, global_position, {"knock": 2.0, "fire": true})
