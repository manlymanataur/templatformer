class_name PlatedBrute
extends Monster
## A brute in plate armour (Power Combat Sketchbook II, bomb flowers). While it has plates, nothing but a
## bomb blast touches it: the poleaxe, the pound and fire just clank. Each blast cracks one plate (and still
## hurts); with both gone it's a plain brute that any stagger rocks, not only the hammer.

const PLATES := 2
var plates := PLATES
var _plates: Array[MeshInstance3D] = []

static func make(parent: Node, pos: Vector3) -> PlatedBrute:
	var b := PlatedBrute.new()
	b.kind = "brute"
	b.position = pos
	parent.add_child(b)
	b.global_position = pos
	b.home = pos
	return b

func _ready() -> void:
	super._ready()
	add_to_group("plated")
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.72, 0.68, 0.55)
	steel.metallic = 0.9
	steel.roughness = 0.3
	for k in PLATES:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.9, 0.3, 1.9) if k == 0 else Vector3(1.5, 0.3, 1.5)
		mi.mesh = bm
		mi.material_override = steel
		mi.position.y = 0.15 + 0.35 * k
		add_child(mi)
		_plates.append(mi)

func strike(amount: int, from: Vector3, info: Dictionary) -> int:
	if plates > 0:
		if not info.get("blast", false):
			Hitfx.sparks(get_tree(), global_position + Vector3.UP * 0.4, 0.5) # clank
			return 0
		plates -= 1
		_plates[plates].visible = false
		Hitfx.sparks(get_tree(), global_position, 1.6)
		if plates == 0:
			armored = false
	return super.strike(amount, from, info)
