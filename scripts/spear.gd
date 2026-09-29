class_name Spear
extends Node3D
## Thrust attack. The tip hurts each hurtable thing once per thrust during the active window.

const DURATION := 0.32
const ACTIVE_FROM := 0.05
const ACTIVE_TO := 0.22
const REACH := 1.2 ## extra length at full thrust
const DAMAGE := 1

var player: Player
var busy := 0.0
var _hit: Array = []
var _shaft: Node3D

func _ready() -> void:
	_shaft = Node3D.new()
	add_child(_shaft)
	var pole := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.07, 1.6)
	pole.mesh = bm
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.4, 0.25)
	pole.material_override = wood
	_shaft.add_child(pole)
	var tip := MeshInstance3D.new()
	var tm := PrismMesh.new()
	tm.size = Vector3(0.2, 0.35, 0.08)
	tip.mesh = tm
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.85, 0.85, 0.9)
	steel.metallic = 0.8
	tip.material_override = steel
	tip.rotation_degrees = Vector3(-90, 0, 0)
	tip.position = Vector3(0, 0, -0.95)
	_shaft.add_child(tip)
	position = Vector3(0.35, 0.05, -0.2)

func attack() -> bool:
	if busy > 0.0:
		return false
	busy = DURATION
	_hit.clear()
	return true

func _physics_process(dt: float) -> void:
	visible = player.inventory.has("spear")
	if busy <= 0.0:
		_shaft.position.z = 0.0
		return
	busy -= dt
	var t := DURATION - busy
	_shaft.position.z = -sin(clampf(t / DURATION, 0.0, 1.0) * PI) * REACH
	if t < ACTIVE_FROM or t > ACTIVE_TO:
		return
	var fwd := player.facing - Vector3.UP * player.facing.dot(Vector3.UP)
	if fwd.length() < 0.01:
		return
	fwd = fwd.normalized()
	var q := PhysicsShapeQueryParameters3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(0.9, 1.2, 1.8)
	q.shape = box
	q.transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), player.global_position + fwd * 1.4)
	q.exclude = [player.get_rid()]
	for r in player.get_world_3d().direct_space_state.intersect_shape(q, 16):
		var c = r["collider"]
		if c != null and c.is_in_group("hurtable") and not _hit.has(c):
			_hit.append(c)
			c.hurt(DAMAGE, player.global_position)
