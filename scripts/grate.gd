class_name Grate
extends StaticBody3D
## Bars too close together for you to fit through, until you shrink. Grates sit on collision layer 3:
## at normal size you bump into them, small you slip through. Light and Umbra pass them, iron doesn't.
## A thick grate is a trap for growing: inside it there's no room, so you stay small (see Player.set_small).

const SPACING := 0.3

## pos is the middle of the grate's base.
static func make(parent: Node, pos: Vector3, size: Vector3) -> Grate:
	var g := Grate.new()
	g.collision_layer = 1 << 2
	g.collision_mask = 0
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	c.position.y = size.y / 2.0
	g.add_child(c)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.3, 0.3, 0.33)
	mat.metallic = 0.7
	mat.roughness = 0.35
	var long := size.x >= size.z # bars run across the longer side
	var width := size.x if long else size.z
	var depth := size.z if long else size.x
	for face in [-1.0, 1.0]:
		var off: float = face * (depth / 2.0 - 0.03)
		var n := int(width / SPACING)
		for k in n + 1:
			var along := -width / 2.0 + width * float(k) / float(maxi(n, 1))
			_bar(g, mat, Vector3(along if long else off, size.y / 2.0, off if long else along), Vector3(0.05, size.y, 0.05))
		for k in int(size.y / 0.6) + 1:
			var y := minf(size.y - 0.03, 0.03 + 0.6 * float(k))
			_bar(g, mat, Vector3(0.0 if long else off, y, off if long else 0.0), Vector3(width if long else 0.06, 0.06, 0.06 if long else width))
	parent.add_child(g)
	g.global_position = pos
	return g

static func _bar(g: Node3D, mat: Material, at: Vector3, size: Vector3) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = at
	g.add_child(mi)
