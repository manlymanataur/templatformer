class_name Pad
extends Area3D
## Launch pads (set your velocity outright) and boost pads (send you along the ground at boost speed).
## A pad built with needs_power only works while power reaches it (see Power): it sits dark until then,
## and if you're already standing on it when the power arrives, it fires.

var kind := "launch" ## "launch" or "boost"
var vec := Vector3.UP ## launch velocity, or boost direction
var needs_power := false
var powered := false
var size := Vector3(2.4, 1.0, 2.4)
var _mat: StandardMaterial3D
var _cool := 0.0

static func make(parent: Node3D, k: String, pos: Vector3, v: Vector3, sz: Vector3, power := false) -> Pad:
	var p := Pad.new()
	p.kind = k
	p.vec = v
	p.size = sz
	p.needs_power = power
	parent.add_child(p)
	p.global_position = pos
	return p

func _ready() -> void:
	# the slab: top flush with the ground at the pad's position
	var body := StaticBody3D.new()
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(size.x, 1.0, size.z)
	mi.mesh = bm
	_mat = StandardMaterial3D.new()
	mi.material_override = _mat
	body.add_child(mi)
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(size.x, 1.0, size.z)
	c.shape = s
	body.add_child(c)
	body.position.y = -0.5
	add_child(body)
	var ac := CollisionShape3D.new()
	var as_ := BoxShape3D.new()
	as_.size = Vector3(size.x, 1.2, size.z)
	ac.shape = as_
	ac.position.y = 0.6
	add_child(ac)
	if needs_power:
		add_to_group("power_sink")
	_refresh()

func works() -> bool:
	return powered or not needs_power

func set_powered(on: bool) -> void:
	if on == powered:
		return
	powered = on
	_refresh()

func _refresh() -> void:
	if _mat == null:
		return
	var col := Color(0.3, 0.9, 0.95) if kind == "launch" else Color(1.0, 0.8, 0.2)
	_mat.albedo_color = col if works() else col.darkened(0.7)
	_mat.emission_enabled = works() and needs_power
	_mat.emission = col
	_mat.emission_energy_multiplier = 0.6

func _physics_process(dt: float) -> void:
	_cool = maxf(_cool - dt, 0.0)
	if not works() or _cool > 0.0:
		return
	for b in get_overlapping_bodies():
		if b is Player:
			_cool = 0.4
			if kind == "launch":
				b.launch(vec)
			else:
				b.boost(vec)

## The cell above the pad, so iron beside it counts as touching.
func power_box() -> AABB:
	return AABB(global_position - Vector3(size.x / 2.0, 0, size.z / 2.0), Vector3(size.x, 2.0, size.z))
