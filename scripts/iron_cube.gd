class_name IronCube
extends AnimatableBody3D
## A 2 m iron block on the room's 2 m grid. It only ever slides along the grid's axes, one cell at a time.
## Your magnet moves it only when you stand at one of its sides (inside its row or column band),
## never from a diagonal, and only the nearest iron in each straight line feels you: anything solid
## in between, including other iron, shields it. Pull (negative) draws it toward you until it's
## next to you; push (positive) drives it away until something blocks it. Iron carries power (see Power).
## Pushed off an edge, it drops.

const CELL := 2.0
var powered := false
var _moving := false
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _k := 0.0
var _fall := 0.0
var _mat: StandardMaterial3D

static func make(parent: Node3D, pos: Vector3) -> IronCube:
	var c := IronCube.new()
	parent.add_child(c)
	c.global_position = pos
	return c

func _ready() -> void:
	add_to_group("conductor")
	sync_to_physics = false
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.96, 1.96, 1.96)
	mi.mesh = bm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.54, 0.59, 0.64)
	_mat.metallic = 0.7
	_mat.roughness = 0.4
	mi.material_override = _mat
	mi.position.y = 1.0
	add_child(mi)
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(2, 2, 2)
	c.shape = s
	c.position.y = 1.0
	add_child(c)

func power_box() -> AABB:
	return AABB(global_position - Vector3(1, 0, 1), Vector3(2, 2, 2))

func _physics_process(dt: float) -> void:
	_mat.emission_enabled = powered
	_mat.emission = Color(0.37, 0.89, 1.0)
	_mat.emission_energy_multiplier = 0.35
	if _moving:
		var t: Tuning = _player().t if _player() != null else null
		_k += dt * (t.iron_speed if t != null else 6.0) / CELL
		global_position = _from.lerp(_to, minf(_k, 1.0))
		if _k >= 1.0:
			_moving = false
		return
	if not _grounded():
		_fall += 30.0 * dt
		global_position += Vector3.DOWN * _fall * dt
		return
	_fall = 0.0
	var p := _player()
	if p == null or not p.inventory.has("magnet"):
		return
	var dir := _pull_axis(p)
	if dir == Vector3.ZERO:
		return
	var step := -dir if p.magnet_push else dir # dir points from the cube toward you
	if not p.magnet_push:
		var gap := Vector2(p.global_position.x - global_position.x, p.global_position.z - global_position.z).length()
		if gap - CELL < 1.5: # one more cell would run into you
			return
	var dest := global_position + step * CELL
	if _free(dest):
		_from = global_position
		_to = dest
		_k = 0.0
		_moving = true

func _player() -> Player:
	var ps := get_tree().get_nodes_in_group("player")
	return ps[0] as Player if not ps.is_empty() else null

## The axis direction from this cube toward you, or zero if you're diagonal, out of range, or shielded.
func _pull_axis(p: Player) -> Vector3:
	var d := p.global_position - (global_position + Vector3.UP)
	if absf(d.y) > 1.6 or Vector2(d.x, d.z).length() > p.t.magnet_range:
		return Vector3.ZERO
	var dir := Vector3.ZERO
	if absf(d.x) < 1.0: # inside the cube's column: you're off its north or south side
		dir = Vector3(0, 0, signf(d.z))
	elif absf(d.z) < 1.0: # inside its row: east or west side
		dir = Vector3(signf(d.x), 0, 0)
	else:
		return Vector3.ZERO # diagonal
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP, p.global_position, 1, [get_rid(), p.get_rid()])
	if not space.intersect_ray(q).is_empty():
		return Vector3.ZERO
	return dir

func _free(dest: Vector3) -> bool:
	var q := PhysicsShapeQueryParameters3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(1.9, 1.8, 1.9)
	q.shape = s
	q.transform = Transform3D(Basis(), dest + Vector3.UP * 1.05)
	q.exclude = [get_rid()]
	return get_world_3d().direct_space_state.intersect_shape(q, 1).is_empty()

func _grounded() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 0.1, 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
