class_name SkiGate
extends Node3D
## A slalom gate: two flags (a and b). Skiing through between them adds ski_gate_boost to your speed; crossing
## the gate's line outside the flags (within GATE_REACH widths of them) is a miss and costs you ski_gate_miss.

const GATE_REACH := 1.5 ## a crossing this many gate widths outside a flag still counts as a miss; further out, it's another line

var a := Vector3.ZERO
var b := Vector3.ZERO
var red := true
var _side := 0.0
var _cool := 0.0
var _mat: StandardMaterial3D

static func make(parent: Node, a_: Vector3, b_: Vector3, red_ := true) -> SkiGate:
	var g := SkiGate.new()
	g.a = a_
	g.b = b_
	g.red = red_
	parent.add_child(g)
	g.global_position = (a_ + b_) / 2.0
	return g

func _ready() -> void:
	add_to_group("ski_gates")
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.9, 0.2, 0.2) if red else Color(0.2, 0.35, 0.95)
	for p in [a, b]:
		var pole := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.06
		cm.bottom_radius = 0.06
		cm.height = 2.2
		pole.mesh = cm
		pole.material_override = _mat
		add_child(pole)
		pole.global_position = p + Vector3.UP * 1.1
		var flag := MeshInstance3D.new()
		var fm := BoxMesh.new()
		fm.size = Vector3(0.7, 0.5, 0.03)
		flag.mesh = fm
		flag.material_override = _mat
		add_child(flag)
		var inward: Vector3 = ((b - a) if p == a else (a - b)).normalized()
		flag.global_position = p + Vector3.UP * 1.9 + inward * 0.38
		flag.look_at(flag.global_position + inward.cross(Vector3.UP), Vector3.UP)

func _physics_process(dt: float) -> void:
	_cool -= dt
	var ps := get_tree().get_nodes_in_group("player")
	if ps.is_empty():
		return
	var p := ps[0] as Player
	var ab := Vector2(b.x - a.x, b.z - a.z)
	var ap := Vector2(p.global_position.x - a.x, p.global_position.z - a.z)
	var side := signf(ab.cross(ap))
	var crossed := _side != 0.0 and side != 0.0 and side != _side
	_side = side
	if not crossed or _cool > 0.0 or not p.surfing or absf(p.global_position.y - global_position.y) > 4.0:
		return
	var s := ap.dot(ab) / ab.length_squared()
	if s >= 0.0 and s <= 1.0:
		_cool = 1.0
		p.ski_gate(true)
		Hitfx.sparks(get_tree(), p.global_position, 0.8)
		_mat.emission_enabled = true
		_mat.emission = _mat.albedo_color
	elif s > -GATE_REACH and s < 1.0 + GATE_REACH:
		_cool = 1.0
		p.ski_gate(false)
