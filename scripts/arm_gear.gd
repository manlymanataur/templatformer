class_name ArmGear
extends Gear
## An arm gear, from Winch: a gear with a long arm that carries a bridge. The arm points one of four ways and
## swings a quarter turn for each notch the gear turns (it settles on the nearest notch, so a half-wound gear
## doesn't leave the bridge askew). Point it across a pit and the bridge spans it. A positive turn swings it
## anticlockwise seen from above. It never stops: wind it on and it keeps going round.

var arm_len := 16.0 ## from the axle to the bridge's tip
var arm_width := 2.0
var a0 := 0.0 ## the arm's angle when built (radians about +Y; 0 points along +X)
var bridge: AnimatableBody3D
var _shown := 0.0 ## the angle the bridge shows, easing toward the notch angle

## dir0: which way the arm points when built (horizontal).
static func make_arm(parent: Node3D, pos: Vector3, r: float, dir0: Vector3, length: float, width: float, tuning: Tuning) -> ArmGear:
	var g := ArmGear.new()
	g.radius = r
	g.arm_len = length
	g.arm_width = width
	g.t = tuning
	g.limited = false
	g.a0 = atan2(-dir0.z, dir0.x)
	g._shown = g.a0
	g.position = pos
	parent.add_child(g)
	g.global_position = pos
	return g

func _build() -> void:
	super._build()
	bridge = AnimatableBody3D.new()
	bridge.sync_to_physics = false
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = Vector3(arm_len, 0.3, arm_width)
	c.shape = s
	c.position = Vector3(arm_len / 2.0, -0.1, 0)
	bridge.add_child(c)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.6, 0.42, 0.24)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = s.size
	mi.mesh = bm
	mi.material_override = wood
	mi.position = c.position
	bridge.add_child(mi)
	# planks across, so you can see which way it lies
	var dark := StandardMaterial3D.new()
	dark.albedo_color = Color(0.42, 0.28, 0.14)
	for k in int(arm_len / 1.0):
		var seam := MeshInstance3D.new()
		var sm := BoxMesh.new()
		sm.size = Vector3(0.06, 0.32, arm_width)
		seam.mesh = sm
		seam.material_override = dark
		seam.position = Vector3(radius + 0.5 + k, -0.1, 0)
		bridge.add_child(seam)
	bridge.top_level = true
	add_child(bridge)
	_place_bridge()

## The arm's angle at the notch it's wound to.
func arm_angle() -> float:
	return a0 + notch() * PI / 2.0

## Which way the arm points (where it has settled).
func arm_dir() -> Vector3:
	return Vector3(cos(_shown), 0, -sin(_shown))

func _place_bridge() -> void:
	# the bridge's top sits 5 cm above the floor the gear stands on
	bridge.global_transform = Transform3D(Basis(Vector3.UP, _shown), global_position)

func _physics_process(dt: float) -> void:
	super._physics_process(dt)
	var want := arm_angle()
	if absf(want - _shown) > 0.0001:
		_shown = move_toward(_shown, want, 3.0 * dt)
		_place_bridge()
