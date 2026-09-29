class_name SizePad
extends Node3D
## A flat pad on the floor. Step onto a shrink pad and you're small; step onto a grow pad and you're back to
## normal size, if there's room. It acts once each time you step on, so you can stand on it without flickering.

const HALF := 0.9 ## half the pad's width

var grow := false
var _was_on := false

## pos is the middle of the floor under the pad.
static func make(parent: Node, pos: Vector3, makes_big: bool) -> SizePad:
	var p := SizePad.new()
	p.grow = makes_big
	parent.add_child(p)
	p.global_position = pos
	return p

func _ready() -> void:
	var col := Color(1.0, 0.6, 0.25) if grow else Color(0.45, 0.9, 0.4)
	var m := StandardMaterial3D.new()
	m.albedo_color = col
	m.emission_enabled = true
	m.emission = col * 0.5
	var disc := MeshInstance3D.new()
	var dm := CylinderMesh.new()
	dm.top_radius = HALF
	dm.bottom_radius = HALF
	dm.height = 0.04
	disc.mesh = dm
	disc.material_override = m
	disc.position.y = 0.02
	add_child(disc)
	# the mark on it: a big ring for grow, a small dot for shrink
	var dark := StandardMaterial3D.new()
	dark.albedo_color = col.darkened(0.55)
	var mark := MeshInstance3D.new()
	var mm: PrimitiveMesh = TorusMesh.new() if grow else CylinderMesh.new()
	if grow:
		(mm as TorusMesh).inner_radius = 0.45
		(mm as TorusMesh).outer_radius = 0.6
	else:
		(mm as CylinderMesh).top_radius = 0.22
		(mm as CylinderMesh).bottom_radius = 0.22
		(mm as CylinderMesh).height = 0.02
	mark.mesh = mm
	mark.material_override = dark
	mark.scale = Vector3(1, 0.1, 1) if grow else Vector3.ONE
	mark.position.y = 0.05
	add_child(mark)

func _physics_process(_dt: float) -> void:
	var on := false
	var who: Player = null
	for n in get_tree().get_nodes_in_group("player"):
		var p := n as Player
		var d := p.global_position - global_position
		if absf(d.x) < HALF and absf(d.z) < HALF and d.y > -0.1 and d.y < 1.2:
			on = true
			who = p
	if on and not _was_on:
		who.set_small(not grow)
	_was_on = on
