class_name Gate
extends StaticBody3D
## Bars across a doorway. open() drops them into the floor. Blocks light while closed.
## A powered door (needs_power) opens when power reaches it (see Power). When the power goes, it stays open
## while something stands in the doorway (iron, you, the spider, a monster) and closes once it's clear.

var size := Vector3(4, 4, 0.4)
var opened := false
var needs_power := false
var powered := false
var held := false ## unpowered, but held open by something in the doorway
var _mesh: MeshInstance3D
var _shape: CollisionShape3D

static func make(parent: Node, pos: Vector3, sz: Vector3, color: Color) -> Gate:
	var g := Gate.new()
	g.size = sz
	parent.add_child(g)
	g.global_position = pos
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.metallic = 0.6
	g._mesh.material_override = m
	return g

func _init() -> void:
	_mesh = MeshInstance3D.new()
	add_child(_mesh)
	_shape = CollisionShape3D.new()
	add_child(_shape)

func _ready() -> void:
	var bm := BoxMesh.new()
	bm.size = size
	_mesh.mesh = bm
	var s := BoxShape3D.new()
	s.size = size
	_shape.shape = s

func open() -> void:
	if opened:
		return
	opened = true
	_shape.set_deferred("disabled", true)
	create_tween().tween_property(_mesh, "position:y", -size.y + 0.05, 0.4)

func close() -> void:
	if not opened:
		return
	opened = false
	_shape.set_deferred("disabled", false)
	create_tween().tween_property(_mesh, "position:y", 0.0, 0.4)

## Make this a powered door: it joins the power grid and opens only while powered.
func wire() -> void:
	needs_power = true
	add_to_group("power_sink")

func set_powered(on: bool) -> void:
	powered = on
	if on:
		held = false
		open()
	elif opened and occupied():
		held = true
	else:
		held = false
		close()

## Is anything standing in the doorway? Iron counts once it overlaps it at all; bodies once their middle is in it.
func occupied() -> bool:
	var door := power_box()
	var inner := door.grow(-0.01)
	for n in get_tree().get_nodes_in_group("conductor"):
		if n.has_method("power_box") and inner.intersects(n.power_box()):
			return true
	var reach := AABB(door.position - Vector3(0.2, 0, 0.2), door.size + Vector3(0.4, 0, 0.4))
	for g in ["player", "spiders", "monsters"]:
		for n in get_tree().get_nodes_in_group(g):
			if reach.has_point((n as Node3D).global_position):
				return true
	return false

func power_box() -> AABB:
	return AABB(global_position - size / 2.0, size)
