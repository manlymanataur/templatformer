class_name Screw
extends Gear
## A screw, from Winch: a round post on a threaded gear. Turned anticlockwise (seen from above: a positive
## turn) it rises one notch per notch it turns, and clockwise it sinks. Flush, its top is floor; risen, you
## stand on top of it and it lifts you. It can't sink below flush or rise past `top` notches: there the train
## it's in stops. The spider and the rope turn it at its base like any gear, and it meshes with gears beside it.

var notch_h := 1.0 ## metres it rises per notch
var top := 4 ## highest notch
var post: AnimatableBody3D
var _h := 0.0 ## shown height, easing toward the notch height

static func make_screw(parent: Node3D, pos: Vector3, r: float, notch_height: float, top_notch: int, start_notch: int, tuning: Tuning) -> Screw:
	var s := Screw.new()
	s.radius = r
	s.notch_h = notch_height
	s.top = top_notch
	s.t = tuning
	s.limited = true
	s.wound = start_notch * STEP
	s._h = start_notch * notch_height
	s.position = pos
	parent.add_child(s)
	s.global_position = pos
	return s

func _build() -> void:
	# the threaded ring at the base, flush with the floor (visual only: the post is the solid part)
	_teeth = Node3D.new()
	add_child(_teeth)
	_teeth_ring(_teeth, -0.15, 0.3, Color(0.55, 0.57, 0.6))
	post = AnimatableBody3D.new()
	post.sync_to_physics = false
	var depth := top * notch_h + 1.0
	var c := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = radius - 0.1
	cs.height = depth
	c.shape = cs
	c.position.y = -depth / 2.0
	post.add_child(c)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.62, 0.64, 0.68)
	steel.metallic = 0.75
	steel.roughness = 0.35
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = radius - 0.1
	cm.bottom_radius = radius - 0.1
	cm.height = depth
	mi.mesh = cm
	mi.material_override = steel
	mi.position.y = -depth / 2.0
	post.add_child(mi)
	# a slot across the top shows which way it's turned
	var slot := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(radius * 1.4, 0.06, 0.2)
	slot.mesh = sm
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.2, 0.2, 0.22)
	slot.material_override = dark
	slot.position.y = 0.01
	post.add_child(slot)
	post.position = global_position + Vector3.UP * (_h + 0.02)
	post.top_level = true
	add_child(post)
	post.global_position = global_position + Vector3.UP * (_h + 0.02)

## The notch it's at, 0 (flush) to top.
func height_notch() -> int:
	return clampi(roundi(wound / STEP), 0, top)

## How high its top stands above the floor right now (metres; it eases between notches).
func height() -> float:
	return _h

func max_wind() -> float:
	return top * STEP

func cog_apply(metres: float) -> void:
	super.cog_apply(metres)
	post.rotation.y = _teeth.rotation.y

func _physics_process(dt: float) -> void:
	super._physics_process(dt)
	var want := height_notch() * notch_h
	_h = move_toward(_h, want, 4.0 * dt)
	post.global_position = global_position + Vector3.UP * (_h + 0.02)
