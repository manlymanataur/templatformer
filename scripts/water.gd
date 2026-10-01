class_name Water
extends Node3D
## Deep water. At normal size you sink: going under puts you back at back_to, like falling in a pit.
## Small, you float with your middle at the surface and paddle at small_swim_speed; jump to climb out.
## Crates float on it and drift with its current. Carry an empty pot into it and the pot fills.

var box := AABB() ## the water's volume; its top is the surface
var back_to := Vector3.ZERO
var current := Vector3.ZERO ## floating things (crates) drift with this

func surface() -> float:
	return box.end.y

## True if p (your centre) is over this water and not far above it.
func holds(p: Vector3) -> bool:
	return p.x > box.position.x and p.x < box.end.x and p.z > box.position.z and p.z < box.end.z \
		and p.y > box.position.y and p.y < box.end.y + 0.3

static func make(parent: Node, volume: AABB, back: Vector3) -> Water:
	var w := Water.new()
	w.box = volume
	w.back_to = back
	w.add_to_group("water")
	parent.add_child(w)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = volume.size
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.2, 0.45, 0.75, 0.6)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.roughness = 0.1
	m.metallic = 0.3
	mi.material_override = m
	w.add_child(mi)
	mi.global_position = volume.get_center()
	return w
