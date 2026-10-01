class_name Runnel
extends StaticBody3D
## A sloped stone gutter a designer lays down: liquid that lands on it runs straight down to its low end and
## puddles (or fills a basin) there. That is the only way liquid flows; anywhere else it stays where it lands.

var top := Vector3.ZERO ## the high end, on its surface
var bottom := Vector3.ZERO ## the low end, on its surface
var width := 1.0
var _stream: MeshInstance3D
var _stream_mat: StandardMaterial3D
var _show_t := 0.0

static func make(parent: Node, from: Vector3, to: Vector3, w := 1.0) -> Runnel:
	var r := Runnel.new()
	r.top = from
	r.bottom = to
	r.width = w
	var d := to - from
	var fwd := d.normalized()
	var side := fwd.cross(Vector3.UP).normalized()
	var up := side.cross(fwd).normalized()
	r.transform = Transform3D(Basis(side, up, -fwd), (from + to) / 2.0 - up * 0.15)
	parent.add_child(r)
	return r

func _ready() -> void:
	add_to_group("runnels")
	var length := top.distance_to(bottom)
	var c := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(width, 0.3, length)
	c.shape = bs
	add_child(c)
	var stone := StandardMaterial3D.new()
	stone.albedo_color = Color(0.5, 0.48, 0.45)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bs.size
	mi.mesh = bm
	mi.material_override = stone
	add_child(mi)
	for s in [-1.0, 1.0]: # low lips along its sides
		var lip := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(0.12, 0.2, length)
		lip.mesh = lm
		lip.material_override = stone
		lip.position = Vector3(s * (width / 2.0 - 0.06), 0.25, 0)
		add_child(lip)
	_stream = MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(width * 0.6, 0.04, length)
	_stream.mesh = sm
	_stream_mat = StandardMaterial3D.new()
	_stream_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_stream.material_override = _stream_mat
	_stream.position.y = 0.17
	_stream.visible = false
	add_child(_stream)

## Liquid poured on it: show it running down. Returns where it ends up (just past the low end).
func pour(kind: String) -> Vector3:
	_stream_mat.albedo_color = Puddle.COLORS[kind]
	_stream.visible = true
	_show_t = 1.0
	var flat := Vector3(bottom.x - top.x, 0, bottom.z - top.z).normalized()
	return bottom + flat * 0.6

## The points along it that the running liquid passes over.
func course() -> Array[Vector3]:
	var out: Array[Vector3] = []
	for k in 4:
		out.append(top.lerp(bottom, k / 3.0))
	return out

func _process(dt: float) -> void:
	if _show_t > 0.0:
		_show_t -= dt
		_stream.visible = _show_t > 0.0
