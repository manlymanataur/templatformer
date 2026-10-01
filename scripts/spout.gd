class_name Spout
extends Node3D
## Where pots fill: a honey hive, a wine cask or a water pipe, with a thin stream running down to the floor.
## Carry an empty pot under the stream and it fills (see Pot). The stream itself never runs out or pools.

var kind := "honey"
var drop := 3.0 ## how far the stream falls to the floor

static func make(parent: Node, mouth: Vector3, k: String, fall := 3.0) -> Spout:
	var s := Spout.new()
	s.kind = k
	s.drop = fall
	s.position = mouth
	parent.add_child(s)
	return s

## Is a pot held at `at` under the stream?
func fills(at: Vector3) -> bool:
	var d := at - global_position
	return Vector2(d.x, d.z).length() < 1.1 and d.y < 0.2 and d.y > -drop - 0.5

func _ready() -> void:
	add_to_group("spouts")
	var body := MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	match kind:
		"honey":
			var sm := SphereMesh.new() # a hive
			sm.radius = 0.7
			sm.height = 1.2
			body.mesh = sm
			m.albedo_color = Color(0.85, 0.65, 0.2)
			body.position.y = 0.6
			for k in 3:
				var band := MeshInstance3D.new()
				var tm := TorusMesh.new()
				tm.inner_radius = 0.55 - absf(k - 1) * 0.15
				tm.outer_radius = tm.inner_radius + 0.12
				band.mesh = tm
				var bm := StandardMaterial3D.new()
				bm.albedo_color = Color(0.55, 0.38, 0.1)
				band.material_override = bm
				band.position.y = 0.3 + k * 0.3
				add_child(band)
		"wine":
			var cm := CylinderMesh.new() # a cask on its side
			cm.top_radius = 0.75
			cm.bottom_radius = 0.75
			cm.height = 1.4
			body.mesh = cm
			body.rotation.x = PI / 2.0
			m.albedo_color = Color(0.45, 0.28, 0.15)
			body.position.y = 0.75
		_:
			var cm := CylinderMesh.new() # a pipe out of the wall
			cm.top_radius = 0.2
			cm.bottom_radius = 0.2
			cm.height = 1.6
			body.mesh = cm
			body.rotation.z = PI / 2.0
			m.albedo_color = Color(0.45, 0.48, 0.5)
			m.metallic = 0.7
			body.position = Vector3(0.6, 0.2, 0)
	body.material_override = m
	add_child(body)
	var stream := MeshInstance3D.new()
	var st := CylinderMesh.new()
	st.top_radius = 0.08 if kind == "honey" else 0.12
	st.bottom_radius = st.top_radius
	st.height = drop
	stream.mesh = st
	var sm2 := StandardMaterial3D.new()
	sm2.albedo_color = Puddle.COLORS[kind]
	sm2.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	sm2.emission_enabled = true
	sm2.emission = Color(Puddle.COLORS[kind]) * 0.3
	stream.material_override = sm2
	stream.position.y = -drop / 2.0
	add_child(stream)
