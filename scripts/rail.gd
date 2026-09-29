class_name Rail
extends Node3D
## A grind rail: a polyline you land on from above and slide along (see Player._rail_step).
## Downhill stretches speed you up, uphill ones slow you down. Jump hops off; at an end you fly off.
## It has no collision: you can only be on it by grinding, and it never blocks light.

var points: PackedVector3Array = [] ## in global space
var length := 0.0
var _acc: PackedFloat32Array = [] ## distance along the rail at each point

static func make(parent: Node, pts: PackedVector3Array) -> Rail:
	var r := Rail.new()
	r.points = pts
	parent.add_child(r)
	return r

func _ready() -> void:
	add_to_group("rails")
	_acc.resize(points.size())
	length = 0.0
	for i in points.size():
		if i > 0:
			length += points[i].distance_to(points[i - 1])
		_acc[i] = length
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.75, 0.78, 0.85)
	m.metallic = 0.9
	m.roughness = 0.3
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var bar := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 0.08
		cm.bottom_radius = 0.08
		cm.height = a.distance_to(b)
		bar.mesh = cm
		bar.material_override = m
		add_child(bar)
		bar.global_position = (a + b) / 2.0
		var d := (b - a).normalized()
		var ax := Vector3.UP.cross(d)
		if ax.length() > 0.001:
			bar.global_basis = Basis(ax.normalized(), Vector3.UP.angle_to(d))
		# a post under each joint so it reads as a rail, not a floating line
		var post := MeshInstance3D.new()
		var pm := CylinderMesh.new()
		pm.top_radius = 0.05
		pm.bottom_radius = 0.05
		pm.height = 0.6
		post.mesh = pm
		post.material_override = m
		add_child(post)
		post.global_position = a + Vector3.DOWN * 0.3

## Distance along the rail of the point closest to pos.
func closest(pos: Vector3) -> float:
	var best := 0.0
	var best_d := INF
	for i in range(1, points.size()):
		var a := points[i - 1]
		var b := points[i]
		var ab := b - a
		var k := clampf((pos - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d := pos.distance_to(a + ab * k)
		if d < best_d:
			best_d = d
			best = _acc[i - 1] + ab.length() * k
	return best

func _seg(s: float) -> int:
	for i in range(1, points.size()):
		if s <= _acc[i]:
			return i
	return points.size() - 1

func point(s: float) -> Vector3:
	var i := _seg(s)
	var a := points[i - 1]
	var b := points[i]
	var k := clampf((s - _acc[i - 1]) / maxf(_acc[i] - _acc[i - 1], 0.0001), 0.0, 1.0)
	return a.lerp(b, k)

func tangent(s: float) -> Vector3:
	var i := _seg(s)
	return (points[i] - points[i - 1]).normalized()
