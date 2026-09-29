class_name Tether
extends Node3D
## A rope from Winch: it lies along the path the walker took from the anchor.
## Walk out and it pays out behind you; walk back along it and it reels in. It can't pay out past max_len:
## a walker that can tow (the lash on the spider) drags the anchor along the rope instead; one that can't
## (the spider's cable) stops at full length.
## The rope slides as it pays out, reels in or tows, and every Gear it runs past turns like a belt.
## Used two ways: the spider's cable (anchor = you sitting still, walker = the spider) and the lash hooked
## on the spider (anchor = the spider, walker = you).

const SPACING := 0.5 ## a new rope point every half metre walked

var anchor: Node3D
var walker: Node3D
var max_len := 14.0
var tows := false ## at full length, drag the anchor instead of stopping the walker
var points: Array[Vector3] = [] ## anchor end first; the last point is the walker
var color := Color(0.85, 0.7, 0.4)
var _mesh: ImmediateMesh
var _prev_len := 0.0

static func make(parent: Node, from: Node3D, to: Node3D, length: float, towing: bool, col: Color) -> Tether:
	var t := Tether.new()
	t.anchor = from
	t.walker = to
	t.max_len = length
	t.tows = towing
	t.color = col
	t.points = [from.global_position, to.global_position]
	t._prev_len = t.length()
	parent.add_child(t)
	return t

func _ready() -> void:
	top_level = true
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

## Length of the rope that's laid down, not counting the last stretch to the walker.
func _laid() -> float:
	var l := 0.0
	for i in points.size() - 2:
		l += points[i].distance_to(points[i + 1])
	return l

## Call after the walker has moved this frame.
func update() -> void:
	if not is_instance_valid(anchor) or not is_instance_valid(walker):
		return
	var tow := 0.0
	points[0] = anchor.global_position
	var w := walker.global_position
	# walking back over the rope reels it in
	while points.size() >= 3 and w.distance_to(points[points.size() - 3]) < SPACING * 0.9:
		points.remove_at(points.size() - 2)
	if w.distance_to(points[points.size() - 2]) >= SPACING:
		points.insert(points.size() - 1, w)
	points[points.size() - 1] = w
	var over := length() - max_len
	if over > 0.0:
		if tows:
			tow = _drag_anchor(over)
		else:
			# the cable is at full length: hold the walker at the end of it
			var last := points[points.size() - 2]
			var room := max_len - _laid()
			var d := w - last
			if d.length() > room and d.length() > 0.001:
				var body := walker as CharacterBody3D
				var fixed := last + d.normalized() * maxf(room, 0.0)
				walker.global_position = Vector3(fixed.x, w.y, fixed.z)
				if body != null:
					var out := d.normalized()
					var v := body.velocity
					var along := Vector3(v.x, 0, v.z).dot(Vector3(out.x, 0, out.z).normalized())
					if along > 0.0:
						body.velocity -= Vector3(out.x, 0, out.z).normalized() * along
				points[points.size() - 1] = walker.global_position
	var len_now := length()
	var slide := (len_now - _prev_len) + tow
	_prev_len = len_now
	if absf(slide) > 0.0001:
		_turn_gears(slide)
	_draw()

## Towing: move the anchor forward along the rope by dist. Returns how far it went.
func _drag_anchor(dist: float) -> float:
	var left := dist
	while left > 0.0 and points.size() > 2:
		var seg := points[1] - points[0]
		if seg.length() <= left:
			left -= seg.length()
			points.remove_at(0)
		else:
			points[0] += seg.normalized() * left
			left = 0.0
	var a := points[0]
	anchor.global_position = Vector3(a.x, maxf(a.y, anchor.global_position.y), a.z)
	return dist - left

## Every gear the rope runs past turns by how far the rope slid, one way or the other depending on
## which side of the gear the rope passes.
func _turn_gears(slide: float) -> void:
	for n in get_tree().get_nodes_in_group("gears"):
		var g := n as Gear
		var c := g.global_position
		for i in points.size() - 1:
			var a := points[i]
			var b := points[i + 1]
			if absf((a.y + b.y) / 2.0 - c.y) > 2.0:
				continue
			var ab := Vector3(b.x - a.x, 0, b.z - a.z)
			if ab.length() < 0.001:
				continue
			var k := clampf(Vector3(c.x - a.x, 0, c.z - a.z).dot(ab) / ab.length_squared(), 0.0, 1.0)
			var near := Vector3(a.x, 0, a.z) + ab * k
			var off := Vector3(near.x - c.x, 0, near.z - c.z)
			if off.length() > g.radius + 0.7 or k <= 0.0 or k >= 1.0:
				continue
			# rope moving toward the walker along ab, on side off of the centre: + is counter-clockwise from above
			var side := signf(off.cross(ab).y)
			g.turn(slide * side)
			break

func _draw() -> void:
	_mesh.clear_surfaces()
	_mesh.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for p in points:
		_mesh.surface_add_vertex(p + Vector3.UP * 0.1)
	_mesh.surface_end()
