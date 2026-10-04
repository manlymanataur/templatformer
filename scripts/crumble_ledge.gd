class_name CrumbleLedge
extends StaticBody3D
## A crumbling ledge (jovi, 2026-10-04): it shakes when you (or the spider) step on it, gives way crumble_delay
## later and drops away, then comes back crumble_regrow after (once nobody's in its space). Keep moving.

var size := Vector3(2, 1, 2)
var t: Tuning
var state := "solid" ## solid, shaking, fallen
var _t := 0.0
var _mesh: MeshInstance3D
var _shape: CollisionShape3D
var _bits: CPUParticles3D

static func make(parent: Node, at: Vector3, sz: Vector3, tuning: Tuning, color := Color(0.6, 0.52, 0.42)) -> CrumbleLedge:
	var c := CrumbleLedge.new()
	c.size = sz
	c.t = tuning
	c._mesh = MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = sz
	c._mesh.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	c._mesh.material_override = m
	c.add_child(c._mesh)
	# cracks: a darker band on top so it reads as different from rock
	var crack := MeshInstance3D.new()
	var cm := BoxMesh.new()
	cm.size = Vector3(sz.x * 0.98, 0.04, sz.z * 0.2)
	crack.mesh = cm
	var dm := StandardMaterial3D.new()
	dm.albedo_color = color.darkened(0.45)
	crack.material_override = dm
	crack.position = Vector3(0, sz.y / 2.0 + 0.01, 0)
	c._mesh.add_child(crack)
	c._shape = CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = sz
	c._shape.shape = bs
	c.add_child(c._shape)
	c._bits = CPUParticles3D.new()
	c._bits.emitting = false
	c._bits.one_shot = true
	c._bits.amount = 24
	c._bits.lifetime = 1.0
	c._bits.explosiveness = 0.9
	c._bits.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	c._bits.emission_box_extents = sz / 2.0
	c._bits.gravity = Vector3.DOWN * 20.0
	var pm := BoxMesh.new()
	pm.size = Vector3(0.25, 0.25, 0.25)
	pm.material = dm
	c._bits.mesh = pm
	c.add_child(c._bits)
	c.add_to_group("crumble")
	parent.add_child(c)
	c.global_position = at
	return c

## Is anyone standing on it?
func _stood_on() -> bool:
	for g in ["player", "spiders"]:
		for n in get_tree().get_nodes_in_group(g):
			var b := n as CharacterBody3D
			if b == null or not b.is_on_floor():
				continue
			if _over(b.global_position, 1.2):
				return true
	return false

func _over(p: Vector3, up: float) -> bool:
	var l := p - global_position
	var top := size.y / 2.0
	return absf(l.x) < size.x / 2.0 + 0.3 and absf(l.z) < size.z / 2.0 + 0.3 and l.y > top - 0.2 and l.y < top + up

func _physics_process(dt: float) -> void:
	_t += dt
	match state:
		"solid":
			if _stood_on():
				state = "shaking"
				_t = 0.0
		"shaking":
			_mesh.position = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1)) * 0.05 * (_t / t.crumble_delay)
			if _t >= t.crumble_delay:
				state = "fallen"
				_t = 0.0
				_shape.set_deferred("disabled", true)
				_bits.restart()
				_bits.emitting = true
				var tw := create_tween()
				tw.tween_property(_mesh, "position", Vector3(0, -6, 0), 0.6).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
				tw.parallel().tween_property(_mesh.material_override, "albedo_color:a", 0.0, 0.6)
		"fallen":
			if _t >= t.crumble_regrow and not _occupied():
				state = "solid"
				_t = 0.0
				_shape.set_deferred("disabled", false)
				_mesh.position = Vector3.ZERO
				var tw := create_tween()
				tw.tween_property(_mesh.material_override, "albedo_color:a", 1.0, 0.4)

## Something's where it would come back (it waits rather than shove you).
func _occupied() -> bool:
	for g in ["player", "spiders", "monsters"]:
		for n in get_tree().get_nodes_in_group(g):
			var b := n as Node3D
			var l := b.global_position - global_position
			if absf(l.x) < size.x / 2.0 + 0.6 and absf(l.z) < size.z / 2.0 + 0.6 and absf(l.y) < size.y / 2.0 + 1.0:
				return true
	return false
