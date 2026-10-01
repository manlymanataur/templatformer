class_name Brazier
extends StaticBody3D
## A stone bowl. Touch it with fire (the candle hat, or burning grass next to it) and it burns for good,
## lighting everything it can see within reach. A lantern is a brazier that starts lit.
## Water puts it out (put_out); fire or the candle lights it again.

signal lit_up

var lit := false
var reach := 14.0
var height := 1.0 ## flame height above the base
var _flame: MeshInstance3D
var _light: OmniLight3D

static func make(parent: Node, pos: Vector3, start_lit := false, h := 1.0) -> Brazier:
	var b := Brazier.new()
	b.height = h
	parent.add_child(b)
	b.global_position = pos
	if start_lit:
		b.light()
	return b

func _ready() -> void:
	add_to_group("flammable")
	add_to_group("light_sources")
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.4, 0.37, 0.34)
	var post := MeshInstance3D.new()
	var pm := CylinderMesh.new()
	pm.top_radius = 0.15
	pm.bottom_radius = 0.25
	pm.height = height - 0.2
	post.mesh = pm
	post.material_override = stone
	post.position.y = (height - 0.2) / 2.0
	add_child(post)
	var bowl := MeshInstance3D.new()
	var bm := CylinderMesh.new()
	bm.top_radius = 0.45
	bm.bottom_radius = 0.2
	bm.height = 0.3
	bowl.mesh = bm
	bowl.material_override = stone
	bowl.position.y = height - 0.1
	add_child(bowl)
	var c := CollisionShape3D.new()
	var s := CylinderShape3D.new()
	s.radius = 0.45
	s.height = height
	c.shape = s
	c.position.y = height / 2.0
	add_child(c)
	_flame = Burnable.flame_mesh(0.5)
	_flame.position.y = height + 0.2
	_flame.visible = lit
	add_child(_flame)
	_light = OmniLight3D.new()
	_light.light_color = Color(1.0, 0.7, 0.4)
	_light.omni_range = reach
	_light.light_energy = 1.6
	_light.shadow_enabled = true
	_light.position.y = height + 0.3
	_light.visible = lit
	add_child(_light)

func light() -> void:
	if lit:
		return
	lit = true
	if _flame != null:
		_flame.visible = true
		_light.visible = true
	lit_up.emit()

## Water on it: the fire's out until something lights it again.
func put_out() -> void:
	if not lit:
		return
	lit = false
	if _flame != null:
		_flame.visible = false
		_light.visible = false

# light source
func is_shining() -> bool:
	return lit
func light_origin() -> Vector3:
	return global_position + Vector3.UP * (height + 0.1)
func light_reach() -> float:
	return reach

# flammable
func heat_box() -> AABB:
	return AABB(global_position + Vector3(-0.45, 0, -0.45), Vector3(0.9, height + 0.3, 0.9))
func heat(_dt: float) -> void:
	light()
