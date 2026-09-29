class_name ColossusSigil
extends AnimatableBody3D
## A colossus weak point. Shut, it's a dim stone slab that shrugs off hits. Once open (its plate cracked off,
## or the colossus down on its knees) it glows, you can lock on to it, and any hit strikes it.

var colossus: Colossus
var size := Vector3.ONE
var opened := false
var struck := false
var _mat: StandardMaterial3D

func _ready() -> void:
	sync_to_physics = false
	var c := CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	c.shape = s
	add_child(c)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.25, 0.35, 0.4)
	mi.material_override = _mat
	add_child(mi)

func open() -> void:
	if opened or struck:
		return
	opened = true
	add_to_group("hurtable")
	add_to_group("targets")
	_mat.albedo_color = Colossus.GLOW
	_mat.emission_enabled = true
	_mat.emission = Colossus.GLOW * 1.5

func hurt(_amount: int, _from: Vector3) -> void:
	if not opened or struck:
		return
	struck = true
	remove_from_group("hurtable")
	remove_from_group("targets")
	_mat.albedo_color = Color(0.15, 0.15, 0.15)
	_mat.emission_enabled = false
	Hitfx.sparks(get_tree(), global_position, 3.0)
	colossus.sigil_struck(self)
