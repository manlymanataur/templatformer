class_name SnowBridge
extends StaticBody3D
## A crust of snow over a hole: it holds while you ski across it faster than ski_bridge_speed. Slow down (or
## stop) on it for SAG_TIME and it collapses under you. It packs back together REFORM_TIME after.

const SAG_TIME := 0.15
const REFORM_TIME := 4.0

var size := Vector3(8, 0.4, 6)
var broken := false
var _slow := 0.0
var _t := 0.0
var _col: CollisionShape3D
var _mesh: MeshInstance3D

## top is the middle of its top face; basis_ tilts it with the slope.
static func make(parent: Node, top: Vector3, size_: Vector3, basis_ := Basis()) -> SnowBridge:
	var s := SnowBridge.new()
	s.size = size_
	parent.add_child(s)
	s.global_transform = Transform3D(basis_, top - basis_ * Vector3.UP * size_.y / 2.0)
	return s

func _ready() -> void:
	add_to_group("snow")
	_col = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	_col.shape = bs
	add_child(_col)
	_mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	_mesh.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.78, 0.86, 0.95)
	m.roughness = 0.3
	_mesh.material_override = m
	add_child(_mesh)
	var crack := StandardMaterial3D.new()
	crack.albedo_color = Color(0.45, 0.55, 0.7)
	for k in 3:
		var c := MeshInstance3D.new()
		var cb := BoxMesh.new()
		cb.size = Vector3(size.x * 0.7, 0.02, 0.08)
		c.mesh = cb
		c.material_override = crack
		c.position = Vector3(0, size.y / 2.0 + 0.01, (k - 1) * size.z / 3.5)
		c.rotation.y = 0.3 * (k - 1)
		add_child(c)

func _physics_process(dt: float) -> void:
	if broken:
		_t += dt
		if _t >= REFORM_TIME and not _player_over():
			broken = false
			_col.disabled = false
			visible = true
		return
	var p := _on_me()
	if p != null and p.flat_speed() < p.t.ski_bridge_speed:
		_slow += dt
		if _slow >= SAG_TIME:
			broken = true
			_t = 0.0
			_slow = 0.0
			_col.disabled = true
			visible = false
			Hitfx.sparks(get_tree(), global_position, 2.0)
	else:
		_slow = 0.0

func _on_me() -> Player:
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if not p.is_on_floor():
			continue
		var local := global_transform.affine_inverse() * p.global_position
		if absf(local.x) < size.x / 2.0 + 0.2 and absf(local.z) < size.z / 2.0 + 0.2 and local.y > 0.0 and local.y < size.y / 2.0 + p.radius() + 0.4:
			return p
	return null

func _player_over() -> bool:
	for n in get_tree().get_nodes_in_group("player"):
		var local := global_transform.affine_inverse() * (n as Node3D).global_position
		if absf(local.x) < size.x / 2.0 + 0.6 and absf(local.z) < size.z / 2.0 + 0.6 and absf(local.y) < 3.0:
			return true
	return false
