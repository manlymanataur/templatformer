class_name MoonPlate
extends Area3D
## A pale plate only Umbra can press. Once pressed it stays down.

signal pressed

var size := Vector3(3, 0.1, 3)
var down := false
var _mat: StandardMaterial3D

static func make(parent: Node, pos: Vector3, sz: Vector3) -> MoonPlate:
	var p := MoonPlate.new()
	p.size = sz
	parent.add_child(p)
	p.global_position = pos
	return p

func _ready() -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.62, 0.55, 1.0)
	_mat.emission_enabled = true
	_mat.emission = Color(0.4, 0.35, 0.9)
	_mat.emission_energy_multiplier = 0.4
	mi.material_override = _mat
	mi.position.y = size.y / 2.0
	add_child(mi)
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(size.x, 1.6, size.z)
	c.shape = s
	c.position.y = 0.8
	add_child(c)
	collision_layer = 0
	collision_mask = 1 << 3 # Umbra's layer
	body_entered.connect(_on_body)

func _on_body(b: Node) -> void:
	if b is Umbra and not down:
		down = true
		_mat.emission_energy_multiplier = 2.5
		pressed.emit()
