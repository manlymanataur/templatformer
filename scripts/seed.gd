class_name Seed
extends CharacterBody3D
## A propagule from Propagule: a 2 m cube, one grid cell, big enough to jump on. Carry it, plant it, and it
## grows a trunk and roots.
## - Pick it up with the context button when you're next to it, or fetch it from afar with the lash. Your
##   hands are full while you carry it: no poleaxe, no lash.
## - Context button while carrying: set down in front of you on soil, mud or roots, it plants; anywhere else
##   you throw it (moving) or set it down (standing still), like a bomb.
## - A seed that falls spear_drop metres or more onto mud spears in and plants itself.
## - Planted, the cube sinks out of sight (no mesh, no collision: jovi wanted the base gone) and a trunk
##   TRUNK_R wide grows from the ground straight up (trunk_height, or to the ceiling) that you can climb, stand
##   on top of, and lash to, and four roots along the ground on the grid axes, each until something blocks it
##   (root_length at most). Roots are ROOT_DEPTH deep, reaching down from just above the ground, and run
##   straight out over gaps, so they bridge them.
## - Context button next to a planted seed pulls it back up: the trunk and roots go and the seed is in your hands.
##   Roots of other planted seeds that it blocked grow on into the space it freed (up to root_length).
## - You can climb vines and trunks with a seed in your hands. Let go of it while climbing and it drops
##   behind you: from spear_drop or higher onto mud it spears in.
## - It's carryable (group "carryable": hold, set_down, throw), so the clockwork spider can carry it too.
## - The trunk and roots are wood (Plants): climbable and lash posts.

const SIZE := 2.0
const HALF := 1.0
const TRUNK_R := 0.75 ## the trunk is 1.5 m across: room to stand on its top
const ROOT_DEPTH := 1.2 ## roots reach this far down from their top (0.12 m above the ground)
const ROOT_TOP := 0.12

var t: Tuning
var holder: Node3D = null ## the player or the spider carrying it (anything with radius())
var planted := false
var trunk: StaticBody3D = null
var roots: Array[StaticBody3D] = []
var _root_dirs: Array[Vector3] = [] ## roots[k] grows along _root_dirs[k]
var _regrow_in := -1 ## frames until the roots try to grow on (after a neighbour is uprooted)
var _peak := 0.0 ## highest point since it last rested, to measure a fall
var _col: CollisionShape3D
var _mesh: MeshInstance3D
var _wood: StandardMaterial3D

static func make(parent: Node, pos: Vector3, tuning: Tuning) -> Seed:
	var s := Seed.new()
	s.t = tuning
	s.position = pos # before add_child, so nothing standing at the origin rides it here (see Monster.spawn)
	parent.add_child(s)
	s._peak = pos.y
	return s

func _ready() -> void:
	add_to_group("seeds")
	add_to_group("targets")
	add_to_group("carryable")
	collision_layer = 1 << 4
	collision_mask = 1
	collision_mask = 1 | 1 << 1 | 1 << 2 | 1 << 4
	floor_max_angle = deg_to_rad(50)
	_col = CollisionShape3D.new()
	var sh := BoxShape3D.new()
	sh.size = Vector3.ONE * (SIZE - 0.02)
	_col.shape = sh
	add_child(_col)
	_mesh = MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3.ONE * SIZE
	_mesh.mesh = cm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.45, 0.6, 0.25)
	_mesh.material_override = m
	add_child(_mesh)
	var sprout := MeshInstance3D.new() # a curl on top so it reads as a seed, not a crate
	var sm := CapsuleMesh.new()
	sm.radius = 0.15
	sm.height = 0.7
	sprout.mesh = sm
	var sg := StandardMaterial3D.new()
	sg.albedo_color = Color(0.3, 0.75, 0.3)
	sprout.material_override = sg
	sprout.position = Vector3(0, HALF + 0.25, 0)
	sprout.rotation.z = 0.5
	_mesh.add_child(sprout)
	_wood = StandardMaterial3D.new()
	_wood.albedo_color = Color(0.45, 0.32, 0.2)

func loose() -> bool:
	return not planted and holder == null

func _physics_process(dt: float) -> void:
	if planted:
		if _regrow_in >= 0:
			_regrow_in -= 1
			if _regrow_in < 0:
				regrow_roots()
		return
	if holder != null and not is_instance_valid(holder):
		throw(Vector3.ZERO) # whoever carried it is gone: it drops
	if holder != null:
		global_position = holder.global_position + Vector3.UP * (holder.radius() + HALF + 0.1)
		velocity = Vector3.ZERO
		_peak = global_position.y
		return
	var was_air := not is_on_floor()
	velocity.y -= t.gravity * dt
	if is_on_floor():
		var hv := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, 20.0 * dt)
		velocity.x = hv.x
		velocity.z = hv.z
	move_and_slide()
	_peak = maxf(_peak, global_position.y)
	if is_on_floor():
		if was_air and _peak - global_position.y >= t.spear_drop and _ground_kind() == "mud":
			plant()
		_peak = global_position.y
	if global_position.y < -30.0:
		queue_free()

## What it rests on: "soil", "mud", "roots", or "" for anything you can't plant in.
func _ground_kind() -> String:
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * (HALF + 0.5), 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return ""
	var c: Node = hit["collider"]
	for kind in ["mud", "soil", "roots"]:
		if c.is_in_group(kind):
			return kind
	return ""

func can_plant() -> bool:
	return _ground_kind() != ""

## How big it is to carry (the spider's load shape).
func carry_size() -> Vector3:
	return Vector3.ONE * SIZE

## Pick it up (or have the lash put it in your hands). p is the player or the spider.
func hold(p: Node3D) -> void:
	holder = p
	velocity = Vector3.ZERO
	remove_from_group("targets")
	_col.set_deferred("disabled", true) # it rides over your head without bumping anything

func throw(v: Vector3) -> void:
	holder = null
	velocity = v
	add_to_group("targets")
	_col.set_deferred("disabled", false)

func set_down(pos: Vector3) -> void:
	holder = null
	add_to_group("targets")
	global_position = pos
	velocity = Vector3.ZERO
	_col.set_deferred("disabled", false)

## Root and grow where it rests.
func plant() -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position, global_position + Vector3.DOWN * 3.0, 1, [get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if hit.is_empty():
		return false
	holder = null
	planted = true
	velocity = Vector3.ZERO
	var base: Vector3 = hit["position"]
	global_position = base + Vector3.UP * HALF # the seed stays here (uprooting finds it), out of sight
	_col.set_deferred("disabled", true) # the trunk stands in its place
	_mesh.visible = false
	remove_from_group("targets")
	var space := get_world_3d().direct_space_state
	# trunk: straight up until the ceiling
	var h := t.trunk_height
	var up := PhysicsRayQueryParameters3D.create(base + Vector3.UP * 0.1, base + Vector3.UP * t.trunk_height, 1, [get_rid()])
	var roof := space.intersect_ray(up)
	if not roof.is_empty():
		h = (roof["position"] as Vector3).y - base.y - 0.1
	trunk = _part(base + Vector3.UP * (h / 2.0), Vector3(TRUNK_R * 2.0, h, TRUNK_R * 2.0), true)
	Plants.mark(trunk, "wood") # climbable, a lash post
	trunk.add_to_group("trunks")
	trunk.set_meta("seed", self)
	# roots: out along each axis at ground level until something is in the way
	for d in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var root := _grow_root(d)
		if root != null:
			roots.append(root)
			_root_dirs.append(d)
	return true

func _base() -> Vector3:
	return global_position + Vector3.DOWN * HALF

## How far a root along d can run from the stump before something (layer 1) is in the way.
func _root_reach(d: Vector3) -> float:
	var skip: Array[RID] = [get_rid()]
	for tr in get_tree().get_nodes_in_group("trunks"): # trunks stand where the cubes did, which roots ran past
		skip.append((tr as CollisionObject3D).get_rid())
	for r in roots:
		if is_instance_valid(r):
			skip.append(r.get_rid())
	var from := _base() + Vector3.UP * 0.06 + d * HALF
	var rq := PhysicsRayQueryParameters3D.create(from, from + d * t.root_length, 1, skip)
	var r := get_world_3d().direct_space_state.intersect_ray(rq)
	return t.root_length if r.is_empty() else from.distance_to(r["position"])

func _grow_root(d: Vector3) -> StaticBody3D:
	var reach := _root_reach(d)
	if reach < 0.3:
		return null
	var base := _base()
	var mid := base + d * (HALF + reach / 2.0)
	var size := Vector3(0.8, ROOT_DEPTH, 0.8) + d.abs() * (reach - 0.8)
	var root := _part(Vector3(mid.x, base.y + ROOT_TOP - ROOT_DEPTH / 2.0, mid.z), size, false)
	root.add_to_group("roots")
	Plants.mark(root, "wood")
	root.set_meta("reach", reach)
	return root

## How far the root along d reaches from the stump's side (0 if there's none).
func root_reach(d: Vector3) -> float:
	for k in roots.size():
		if _root_dirs[k].is_equal_approx(d) and is_instance_valid(roots[k]):
			return roots[k].get_meta("reach")
	return 0.0

## Roots that stopped short grow on into whatever space has opened up, to root_length at most.
## (Called a couple of frames after another plant is uprooted, once its parts have left the world.)
func regrow_roots() -> void:
	if not planted:
		return
	for d in [Vector3.FORWARD, Vector3.BACK, Vector3.LEFT, Vector3.RIGHT]:
		var had := root_reach(d)
		if had >= t.root_length - 0.01 or _root_reach(d) < maxf(had, 0.3) + 0.05:
			continue
		var k := -1
		for i in roots.size():
			if _root_dirs[i].is_equal_approx(d):
				k = i
		if k >= 0:
			roots[k].free() # out of the world now, so it doesn't block its own regrowth
			roots.remove_at(k)
			_root_dirs.remove_at(k)
		var root := _grow_root(d)
		if root != null:
			roots.append(root)
			_root_dirs.append(d)

func _part(pos: Vector3, size: Vector3, round_: bool) -> StaticBody3D:
	var b := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var mi := MeshInstance3D.new()
	if round_:
		var cs := CylinderShape3D.new()
		cs.radius = size.x / 2.0
		cs.height = size.y
		c.shape = cs
		var cm := CylinderMesh.new()
		cm.top_radius = size.x / 2.0 * 0.8
		cm.bottom_radius = size.x / 2.0
		cm.height = size.y
		mi.mesh = cm
	else:
		var bs := BoxShape3D.new()
		bs.size = size
		c.shape = bs
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
	mi.material_override = _wood
	b.add_child(c)
	b.add_child(mi)
	get_parent().add_child(b)
	b.global_position = pos
	return b

## Top of the trunk, for climbing.
func trunk_top() -> float:
	var s := (trunk.get_child(0) as CollisionShape3D).shape as CylinderShape3D
	return trunk.global_position.y + s.height / 2.0

## Pull it back up: the trunk and roots go, and the seed goes into p's hands.
func uproot(p: Node3D) -> void:
	if trunk != null:
		trunk.queue_free()
		trunk = null
	for r in roots:
		r.queue_free()
	roots.clear()
	_root_dirs.clear()
	planted = false
	_mesh.visible = true
	add_to_group("targets")
	hold(p)
	# whatever this plant held back grows on once its parts are out of the world
	for n in get_tree().get_nodes_in_group("seeds"):
		if n != self and (n as Seed).planted:
			(n as Seed)._regrow_in = 2

func _exit_tree() -> void:
	if trunk != null and is_instance_valid(trunk):
		trunk.queue_free()
	for r in roots:
		if is_instance_valid(r):
			r.queue_free()
