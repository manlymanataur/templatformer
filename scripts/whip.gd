class_name Whip
extends MeshInstance3D
## The lash's crack, drawn as a whip motion (jovi: "The lashing should be a whip motion. It doesn't need to be
## strong."): the cord rolls out from your hand in a loop that travels down it, snaps straight at the tip with a
## spark, and falls slack. Only a look: the lash's effect is decided by Player.use_lash the moment you crack it.

const OUT := 0.13 ## seconds for the loop to roll out to the tip
const LIFE := 0.3 ## seconds it's drawn
const SEGS := 24

var a := Vector3.ZERO
var b := Vector3.ZERO
var _t := 0.0
var _side := Vector3.RIGHT
var _cracked := false
var _im: ImmediateMesh

static func crack(parent: Node, from: Vector3, to: Vector3) -> Whip:
	var w := Whip.new()
	w.a = from
	w.b = to
	parent.add_child(w)
	return w

func _ready() -> void:
	top_level = true
	global_transform = Transform3D.IDENTITY
	_im = ImmediateMesh.new()
	mesh = _im
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(0.85, 0.7, 0.4)
	material_override = m
	var d := b - a
	_side = Vector3(d.z, 0, -d.x).normalized()
	if _side.length() < 0.01:
		_side = Vector3.RIGHT
	_draw()

func _process(dt: float) -> void:
	_t += dt
	if _t >= LIFE:
		queue_free()
		return
	if not _cracked and _t >= OUT:
		_cracked = true
		if is_inside_tree():
			Hitfx.sparks(get_tree(), b, 0.35)
	_draw()

## Where the cord is at u (0 hand .. 1 tip) right now.
func point(u: float) -> Vector3:
	var reach := clampf(_t / OUT, 0.0, 1.0) # how far out the cord has rolled
	var along := a.lerp(b, u * reach)
	var len := a.distance_to(b)
	# the travelling loop: a bump that rides out along the cord as it unrolls, then dies away
	var wave := sin(PI * clampf(u * 1.0, 0.0, 1.0)) * sin(TAU * (u * 1.5 - _t / OUT))
	var amp := minf(len * 0.08, 0.7) * (1.0 - clampf((_t - OUT) / (LIFE - OUT), 0.0, 1.0))
	var sag := Vector3.DOWN * maxf(_t - OUT, 0.0) * 3.0 * sin(PI * u) # slack once it has cracked
	return along + (_side * 0.6 + Vector3.UP * 0.8) * wave * amp + sag

func _draw() -> void:
	_im.clear_surfaces()
	_im.surface_begin(Mesh.PRIMITIVE_LINE_STRIP)
	for k in SEGS + 1:
		_im.surface_add_vertex(point(k / float(SEGS)))
	_im.surface_end()
