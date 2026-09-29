class_name Fan
extends Node3D
## A fan blowing along wind (world direction and speed) through the box lane. Small, the wind carries you:
## inside the lane your velocity along the wind is pulled up to its speed and gravity lets go, so a sideways
## lane floats you across a pit and an upward one lifts you. At normal size you're too heavy to notice.
## A fan with a cover (a CrackedFloor over its vent) is still until the cover breaks.

var wind := Vector3.UP * 8.0
var lane := AABB()
var cover: CrackedFloor
var _blades: Node3D
var _streak: MeshInstance3D

func blowing() -> bool:
	return cover == null or cover.broken

## The wind at p, or zero outside the lane.
func wind_at(p: Vector3) -> Vector3:
	return wind if blowing() and lane.has_point(p) else Vector3.ZERO

## base is the middle of the fan's housing, which sits at the lane's upwind end.
static func make(parent: Node, base: Vector3, lane_box: AABB, w: Vector3) -> Fan:
	var f := Fan.new()
	f.wind = w
	f.lane = lane_box
	f.add_to_group("wind")
	parent.add_child(f)
	f.global_position = base
	var d := w.normalized()
	var housing := MeshInstance3D.new()
	var hm := CylinderMesh.new()
	hm.top_radius = 0.95
	hm.bottom_radius = 0.95
	hm.height = 0.3
	housing.mesh = hm
	var metal := StandardMaterial3D.new()
	metal.albedo_color = Color(0.4, 0.42, 0.48)
	metal.metallic = 0.6
	housing.material_override = metal
	f.add_child(housing)
	f._blades = Node3D.new()
	f.add_child(f._blades)
	for k in 3:
		var blade := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.8, 0.05, 0.25)
		blade.mesh = bm
		blade.material_override = metal
		blade.position = Vector3(cos(TAU * k / 3.0), 0.0, sin(TAU * k / 3.0)) * 0.45
		blade.rotation.y = -TAU * k / 3.0
		blade.rotation.x = 0.4
		f._blades.add_child(blade)
	f._blades.position.y = 0.2
	# a faint column shows the lane while it blows
	f._streak = MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = lane_box.size
	f._streak.mesh = sm
	var sm_mat := StandardMaterial3D.new()
	sm_mat.albedo_color = Color(0.85, 0.95, 1.0, 0.08)
	sm_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sm_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	f._streak.material_override = sm_mat
	parent.add_child(f._streak)
	f._streak.global_position = lane_box.get_center()
	if absf(d.y) < 0.9: # lay the housing on its side, facing along the wind
		f.basis = Basis.looking_at(d, Vector3.UP) * Basis(Vector3.RIGHT, -PI / 2.0)
	return f

func _process(dt: float) -> void:
	_streak.visible = blowing()
	if blowing():
		_blades.rotate_y(dt * 14.0)
