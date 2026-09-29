class_name Bomb
extends Node3D
## Lit bomb. After FUSE seconds it hurts everything hurtable within RADIUS, you included.

const FUSE := 2.0
const RADIUS := 3.5
const DAMAGE := 2

var _t := 0.0
var _mat: StandardMaterial3D
var _exploded := false

func _ready() -> void:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	mi.mesh = sm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.15, 0.15, 0.2)
	mi.material_override = _mat
	mi.position.y = 0.35
	add_child(mi)

func _physics_process(dt: float) -> void:
	if _exploded:
		return
	_t += dt
	var blink := fmod(_t * (3.0 + _t * 6.0), 1.0) < 0.5
	_mat.albedo_color = Color(0.9, 0.3, 0.2) if blink else Color(0.15, 0.15, 0.2)
	if _t >= FUSE:
		explode()

func explode() -> void:
	_exploded = true
	for n in get_tree().get_nodes_in_group("hurtable"):
		var node := n as Node3D
		if node.global_position.distance_to(global_position) <= RADIUS:
			node.hurt(DAMAGE, global_position)
	var flash := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2.0
	flash.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.6, 0.2, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.material_override = m
	add_child(flash)
	get_tree().create_timer(0.25, false).timeout.connect(queue_free)
