class_name IronCube
extends AnimatableBody3D
## A 2 m wide, 4.5 m tall iron block on the room's 2 m grid: too tall for a double jump, a triple clears it. It only ever slides along the grid's axes, one cell at a time.
## Your magnet moves it only when you stand at one of its sides (inside its row or column band),
## never from a diagonal, and only the nearest iron in each straight line feels you: anything solid
## in between, including other iron, shields it. Pull (negative) draws it toward you until it's
## next to you; push (positive) drives it away until something blocks it. Iron carries power (see Power).
## Pushed off an edge, it drops. Into a pit it fits (as deep as it is tall), it drops in, settles flush with the
## floor and stays there as floor: you walk across it, other iron slides over it, and it still carries power to
## conductors touching its faces (including iron standing on it). Into anything deeper it goes back to where it started.
## While you're small the iron is too heavy for you to budge: it moves you instead (see Player._magnet_line).
## Powers book: monsters don't stop it. A sliding block ploughs the monster in its way (_plough), knocking it
## on at t.iron_plough_knock, so pinning one between iron and a wall splats it.

const CELL := 2.0
const H := 4.5
var powered := false
var _moving := false
var _from := Vector3.ZERO
var _to := Vector3.ZERO
var _k := 0.0
var _fall := 0.0
var _mat: StandardMaterial3D
var home := Vector3.ZERO
var sunk := false ## it dropped into a pit it fits and is floor now
var _drop_from := 0.0 ## the floor height it fell from
var _ploughed: Array = [] ## monsters this step already knocked

static func make(parent: Node3D, pos: Vector3) -> IronCube:
	var c := IronCube.new()
	c.position = pos # placed before it enters the tree, so the physics never sees it jump from the origin
	parent.add_child(c)
	c.global_position = pos
	c.home = pos
	return c

func _ready() -> void:
	add_to_group("conductor")
	sync_to_physics = false
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.96, H - 0.04, 1.96)
	mi.mesh = bm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.54, 0.59, 0.64)
	_mat.metallic = 0.7
	_mat.roughness = 0.4
	mi.material_override = _mat
	mi.position.y = H / 2.0
	add_child(mi)
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(2, H, 2)
	c.shape = s
	c.position.y = H / 2.0
	add_child(c)

func power_box() -> AABB:
	return AABB(global_position - Vector3(1, 0, 1), Vector3(2, H, 2))

func _physics_process(dt: float) -> void:
	_mat.emission_enabled = powered
	_mat.emission = Color(0.37, 0.89, 1.0)
	_mat.emission_energy_multiplier = 0.35
	if _moving:
		var t: Tuning = _player().t if _player() != null else null
		_k += dt * (t.iron_speed if t != null else 6.0) / CELL
		global_position = _from.lerp(_to, minf(_k, 1.0))
		_plough((_to - _from).normalized())
		if _k >= 1.0:
			_moving = false
		return
	if not _grounded():
		if _fall == 0.0:
			_drop_from = global_position.y
		_fall += 30.0 * dt
		var fall_q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * _fall * dt, 1, [get_rid()])
		var under := get_world_3d().direct_space_state.intersect_ray(fall_q)
		if not under.is_empty():
			global_position.y = (under["position"] as Vector3).y # it lands this frame, not inside what it lands on
			_fall = 0.0
			_land()
			return
		global_position += Vector3.DOWN * _fall * dt
		if global_position.y < _drop_from - H - 1.0:
			_go_home() # deeper than a block: a chasm, not a pit
		return
	if _fall > 0.0:
		_fall = 0.0
		_land()
	if sunk:
		return
	var p := _player()
	if p == null or not p.inventory.equipped("magnet") or p.small:
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
		_ploughed.clear()

## Just landed: snap onto what it landed on. Flush with the floor it fell from, it fills the pit for good.
func _land() -> void:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.6, global_position + Vector3.DOWN * 0.6, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty():
		global_position.y = (hit["position"] as Vector3).y
	var top := global_position.y + H
	if absf(top - _drop_from) <= 0.3:
		global_position.y = _drop_from - H
		sunk = true
	elif top < _drop_from - 0.3:
		_go_home() # the pit is deeper than the block: it would sit below the floor

func _go_home() -> void:
	global_position = home
	_fall = 0.0
	sunk = false

func _player() -> Player:
	var ps := get_tree().get_nodes_in_group("player")
	return ps[0] as Player if not ps.is_empty() else null

## The axis direction from this cube toward you, or zero if you're diagonal, out of range, or shielded.
func _pull_axis(p: Player) -> Vector3:
	var d := p.global_position - (global_position + Vector3.UP)
	if d.y < -1.6 or d.y > H - 1.5 or Vector2(d.x, d.z).length() > p.t.magnet_range: # beside it, not on top
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
	s.size = Vector3(1.9, H - 0.2, 1.9)
	q.shape = s
	q.transform = Transform3D(Basis(), dest + Vector3.UP * (H / 2.0 + 0.05))
	q.exclude = [get_rid()]
	q.collision_mask = 1 | 1 << 1 | 1 << 2 # walls, bars and grates stop iron
	for r in get_world_3d().direct_space_state.intersect_shape(q, 8):
		if not (r["collider"] is Monster): # monsters don't: it ploughs them (_plough)
			return false
	return true

## Knock any monster at the block's leading face along dir.
func _plough(dir: Vector3) -> void:
	var p := _player()
	if p == null:
		return
	var q := PhysicsShapeQueryParameters3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(0.8, H - 0.4, 1.9) if absf(dir.x) > 0.5 else Vector3(1.9, H - 0.4, 0.8) # a slab at the leading face
	q.shape = s
	q.transform = Transform3D(Basis(), global_position + dir * 1.3 + Vector3.UP * (H / 2.0))
	q.exclude = [get_rid()]
	for r in get_world_3d().direct_space_state.intersect_shape(q, 8):
		var m = r["collider"]
		if m is Monster and not _ploughed.has(m):
			_ploughed.append(m)
			(m as Monster).strike(1, (m as Monster).global_position - dir, {"knock": p.t.iron_plough_knock, "stagger": true, "above": true})

func _grounded() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * 0.1, 1, [get_rid()])
	return not get_world_3d().direct_space_state.intersect_ray(q).is_empty()
