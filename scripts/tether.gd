class_name Tether
extends Node3D
## The lash hooked on the clockwork spider: a taut rope from you (a, the reel) to the spider (b).
## It runs straight and only bends around level features (walls, ledges, gears, seed cubes); when the way
## around a bend clears, the bend lets go. It reels in any slack, so it's always under tension.
## At max_len, whoever is being steered (lead) drags the other end along the rope.
## Rope sliding past a gear turns it like a belt (see Gear.turn).

const LIFT := Vector3.UP * 0.1 ## the rope hangs from just above each body's middle
const MASK := 1 | 1 << 4 ## level features and props (seed cubes); bars and grates let it through
const OFF := 0.12 ## bends sit this far out from the surface they wrap
const STRAIGHT := 0.14 ## a bend turning less than this (radians, about 8 degrees) is let go: the rope is nearly straight there

var a: Node3D ## your end: the reel
var b: Node3D ## the spider's end
var lead: Node3D ## the end being steered this frame; the other one gets dragged
var max_len := 16.0
var skip_h := 0.8 ## the rope passes over anything it clears this far higher up (Tuning.rope_skip_height)
var skip_w := 0.4 ## and past anything it clears this far to either side (Tuning.rope_skip_width)
var points: Array[Vector3] = [] ## a's end first, then the bends, then b's end
var turns: Array[float] = [] ## per point: which way the rope turns at that bend (+1 / -1; 0 at the ends)
var color := Color(0.85, 0.7, 0.4)
var _mesh: ImmediateMesh
var _gear_len := {} ## gear -> [its first bend, rope from you to it, whole rope], last frame
var _last_end := {} ## 0 / 1 -> where a's / b's end was at the end of last frame
var _carry_a := {} ## Machinery.carried memory for each end
var _carry_b := {}
var _carried_a := Vector3.ZERO ## how far a moving floor carried each end this frame (not rope paid out by you)
var _carried_b := Vector3.ZERO

static func make(parent: Node, from: Node3D, to: Node3D, length: float, col: Color) -> Tether:
	var t := Tether.new()
	t.a = from
	t.b = to
	t.lead = from
	t.max_len = length
	t.color = col
	t.points = [from.global_position + LIFT, to.global_position + LIFT]
	t.turns = [0.0, 0.0]
	if from is Player:
		t.skip_h = (from as Player).t.rope_skip_height
		t.skip_w = (from as Player).t.rope_skip_width
	parent.add_child(t)
	return t

func _ready() -> void:
	top_level = true
	process_physics_priority = 100 # after both ends have moved this frame
	_mesh = ImmediateMesh.new()
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = color
	mi.material_override = m
	add_child(mi)

func length() -> float:
	var l := 0.0
	for i in points.size() - 1:
		l += points[i].distance_to(points[i + 1])
	return l

## Rope length from point i to b's end.
func _to_b(i: int) -> float:
	var l := 0.0
	for k in range(i, points.size() - 1):
		l += points[k].distance_to(points[k + 1])
	return l

func _physics_process(dt: float) -> void:
	if not is_instance_valid(a) or not is_instance_valid(b):
		queue_free()
		return
	_carried_a = Machinery.carried(a, _carry_a)
	_carried_b = Machinery.carried(b, _carry_b)
	_follow()
	_wrap()
	var over := length() - max_len
	if over > 0.0:
		var dragged := b if lead == a else a
		_pull(dragged, over, dt)
		_follow()
		_wrap()
		over = length() - max_len
		if over > 0.02:
			_pull(lead, over, dt) # the dragged end is stuck: the lead can't go further
			_follow()
	_turn_gears()
	_draw()

func _follow() -> void:
	points[0] = a.global_position + LIFT
	points[points.size() - 1] = b.global_position + LIFT

func _raw_ray(from: Vector3, to: Vector3, skip: Array[RID]) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(from, to, MASK, skip)
	return get_world_3d().direct_space_state.intersect_ray(q)

## The first thing that really blocks the rope between two points, or {}. Small details don't (jovi,
## 2026-10-01: the rope and what it leashes shouldn't catch on corners and small details): creatures and small
## loose things (monsters, you, the spider, bombs, pots), anything low enough that the rope passes skip_h
## above it, and anything thin enough that the rope is clear skip_w to either side of it. Gears and posts
## always count: the rope is meant to wrap them.
func _ray(from: Vector3, to: Vector3) -> Dictionary:
	var ex: Array[RID] = []
	for n in [a, b]:
		if n is CollisionObject3D:
			ex.append((n as CollisionObject3D).get_rid())
	for _k in 6:
		var hit := _raw_ray(from, to, ex)
		if hit.is_empty():
			return hit
		var c: Object = hit["collider"]
		if not _detail(c, from, to, ex):
			return hit
		ex.append(hit["rid"])
	return {}

func _detail(c: Object, from: Vector3, to: Vector3, ex: Array[RID]) -> bool:
	if c is Monster or c is Player or c is Spider or c is Bomb or c is Pot:
		return true
	var n := c as Node
	if n == null or n.is_in_group("cogs") or n.is_in_group("lash_posts"):
		return false
	var rid: RID = (c as CollisionObject3D).get_rid() if c is CollisionObject3D else RID()
	var up := Vector3.UP * skip_h
	if not _hits_only(from + up, to + up, rid):
		return true # low: the rope rides over it
	var d := to - from
	var side := Vector3(d.z, 0, -d.x).normalized() * skip_w
	if side.length() > 0.001 and not _hits_only(from + side, to + side, rid) and not _hits_only(from - side, to - side, rid):
		return true # thin: a pole or a twig, not a corner to wrap
	return false

## Does the segment hit the body with this rid (looking past anything else in the way)?
func _hits_only(from: Vector3, to: Vector3, rid: RID) -> bool:
	var ex: Array[RID] = []
	for _k in 6:
		var hit := _raw_ray(from, to, ex)
		if hit.is_empty():
			return false
		if hit["rid"] == rid:
			return true
		ex.append(hit["rid"])
	return false

## Bend around whatever now blocks either end's straight run, and let go of bends the rope no longer touches.
## A new bend goes at the corner: between where the end was last frame (clear) and where it is now (blocked),
## a few halvings find the last clear line, and the bend sits just outside the obstacle on that line.
func _wrap() -> void:
	for side in [1, 0]:
		for _k in 4:
			var n := points.size()
			var end := n - 1 if side == 1 else 0
			var prev := n - 2 if side == 1 else 1
			var from := points[prev]
			var to := points[end]
			var hit := _ray(from, to)
			if hit.is_empty():
				break
			var at: Vector3 = hit["position"] + (hit["normal"] as Vector3) * OFF
			var was: Vector3 = _last_end[side] if _last_end.has(side) else to
			if _ray(from, was).is_empty():
				var lo := was
				var hi := to
				for _i in 8:
					var mid := lo.lerp(hi, 0.5)
					if _ray(from, mid).is_empty():
						lo = mid
					else:
						hi = mid
				var h := _ray(from, hi)
				var hp: Vector3 = h["position"] if not h.is_empty() else hit["position"]
				var corner := from + (lo - from).normalized() * from.distance_to(hp)
				var away := corner - hp
				if away.length() < 0.001:
					away = h["normal"] if not h.is_empty() else hit["normal"]
				at = corner + away.normalized() * OFF
			if at.distance_to(from) < 0.05 or at.distance_to(to) < 0.05:
				break
			var k := end if side == 1 else 1
			points.insert(k, at)
			turns.insert(k, _turn_at(k))
		_last_end[side] = points[points.size() - 1 if side == 1 else 0]
	# a bend lets go once the rope would turn the other way there: it has swung off whatever it wrapped
	var changed := true
	while changed and points.size() > 2:
		changed = false
		for i in range(1, points.size() - 1):
			var now := _turn_at(i)
			var swung := now != 0.0 and now != turns[i]
			if (swung or _bend_angle(i) < STRAIGHT) and _ray(points[i - 1], points[i + 1]).is_empty():
				points.remove_at(i)
				turns.remove_at(i)
				changed = true
				break

## How sharply the rope turns at point i (radians, 0 = straight on).
func _bend_angle(i: int) -> float:
	var u := points[i] - points[i - 1]
	var v := points[i + 1] - points[i]
	if u.length() < 0.001 or v.length() < 0.001:
		return 0.0
	return u.angle_to(v)

## Which way the rope turns at point i, seen from above: +1, -1, or 0 when it runs straight on.
func _turn_at(i: int) -> float:
	var u := points[i] - points[i - 1]
	var v := points[i + 1] - points[i]
	var c := u.x * v.z - u.z * v.x
	return 0.0 if absf(c) < 0.0001 else signf(c)

## Drag the body at one end along the rope, toward its first bend, by dist. It slides like it walked there
## (so floor seams and slopes don't snag it), and loses any speed away from the rope.
func _pull(body: Node3D, dist: float, dt: float) -> void:
	var here := body.global_position + LIFT
	var at_a := body == a
	var k := 1 if at_a else points.size() - 2
	var toward := points[k]
	# at the corner already (it can't reach the bend itself, the wall is in the way): aim past it, round the corner
	var r: float = body.radius() if body.has_method("radius") else 0.5
	var flat := Vector3(toward.x - here.x, 0, toward.z - here.z)
	if points.size() > 2 and flat.length() < r + 0.35:
		toward = points[k + 1] if at_a else points[k - 1]
	var dir := (toward - here).normalized()
	var start := body.global_position
	var cb := body as CharacterBody3D
	if cb == null:
		body.global_position += dir * dist
	else:
		var v := cb.velocity
		cb.velocity = dir * dist / maxf(dt, 0.001)
		cb.move_and_slide()
		var got := (cb.global_position - start).length()
		if got < dist * 0.5 and _low_ahead(cb, dir):
			# a kerb or low ledge in the way (the rope rode over it): hop the body up onto it and on
			cb.move_and_collide(Vector3.UP * skip_h)
			cb.velocity = Vector3(dir.x, 0, dir.z).normalized() * (dist - got) / maxf(dt, 0.001)
			cb.move_and_slide()
			got = dist
		if got < dist * 0.5:
			# stuck on something head-on: slide sideways along it, the way that keeps closer to the rope
			for i in cb.get_slide_collision_count():
				var n := cb.get_slide_collision(i).get_normal()
				if absf(n.y) > 0.6:
					continue
				var side := Vector3(n.z, 0, -n.x).normalized()
				if side.dot(dir) < 0.0:
					side = -side
				if side.dot(dir) < 0.05:
					var beyond := (points[mini(k + 1, points.size() - 1)] if at_a else points[maxi(k - 1, 0)]) - here
					side = side if side.dot(beyond) >= 0.0 else -side
				cb.velocity = side * (dist - got) / maxf(dt, 0.001)
				cb.move_and_slide()
				break
		var along := v.dot(-dir)
		cb.velocity = v + dir * along if along > 0.0 else v
	if body.has_method("shoved"):
		body.shoved(body.global_position - start)

## Is what stops this body low enough to hop (clear skip_h higher up, the way it's dragged)?
func _low_ahead(cb: CharacterBody3D, dir: Vector3) -> bool:
	var flat := Vector3(dir.x, 0, dir.z)
	if flat.length() < 0.01:
		return false
	var r: float = cb.radius() if cb.has_method("radius") else 0.5
	var low := cb.global_position + Vector3.UP * 0.05
	var reach := flat.normalized() * (r + 0.4)
	var ex: Array[RID] = [cb.get_rid()]
	var space := get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(low, low + reach, cb.collision_mask, ex)
	if space.intersect_ray(q).is_empty():
		return false # nothing low ahead: it's stuck on something else
	var high := low + Vector3.UP * skip_h
	q = PhysicsRayQueryParameters3D.create(high, high + reach, cb.collision_mask, ex)
	return space.intersect_ray(q).is_empty()

## A gear the rope is wrapped round (a bend sits on its rim) turns by how far the rope slid over it, one way
## or the other depending on which side the rope passes. The rope pays out from your reel, so what slides
## over the gear is what the reel paid out minus what stayed between you and the gear.
##
## What the moving floor under either end carried it doesn't count (jovi, 2026-10-01): a spider riding a lift
## the gear drives would otherwise pay rope over the gear and wind it on by itself.
func _turn_gears() -> void:
	var total := length()
	var n_pts := points.size()
	var ua := (points[1] - points[0]).normalized()
	var ub := (points[n_pts - 2] - points[n_pts - 1]).normalized()
	var carry_a := _carried_a.dot(ua) # how much the carried move shortened the first run (rope reeled by the floor)
	var carry_b := _carried_b.dot(ub)
	var seen := {}
	for n in get_tree().get_nodes_in_group("gears"):
		var g := n as Gear
		var c := g.global_position
		var la := 0.0
		for i in range(1, points.size() - 1):
			la += points[i - 1].distance_to(points[i])
			var pv := points[i]
			var off := Vector3(pv.x - c.x, 0, pv.z - c.z)
			if off.length() > g.radius + OFF + 0.3 or absf(pv.y - (c.y + 0.6)) > 1.2:
				continue
			var st: Array = _gear_len.get(g, [])
			if not st.is_empty() and (st[0] as Vector3).distance_to(pv) < 0.3:
				var slid := (total + carry_a + carry_b - float(st[2])) - (la + carry_a - float(st[1]))
				var travel := points[i + 1] - pv
				g.turn(slid * signf(off.cross(Vector3(travel.x, 0, travel.z)).y))
			_gear_len[g] = [pv, la, total]
			seen[g] = true
			break
	for g in _gear_len.keys():
		if not seen.has(g):
			_gear_len.erase(g)

func _draw() -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in points:
		_mesh.surface_add_vertex(p)
	_mesh.surface_end()
