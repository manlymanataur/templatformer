class_name PotShelf
extends Node3D
## A board on the floor that keeps a pot on it: pot_respawn seconds after its pot smashes, a new empty one
## appears here.

var t: Tuning
var pot: Pot = null
var _wait := -1.0

static func make(parent: Node, pos: Vector3, tuning: Tuning) -> PotShelf:
	var s := PotShelf.new()
	s.t = tuning
	s.position = pos
	parent.add_child(s)
	return s

func _ready() -> void:
	add_to_group("pot_shelves")
	var board := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(1.1, 0.08, 1.1)
	board.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.5, 0.35, 0.22)
	board.material_override = m
	board.position.y = 0.04
	add_child(board)
	_new_pot.call_deferred()

func _new_pot() -> void:
	pot = Pot.make(get_parent(), global_position + Vector3.UP * (Pot.R + 0.1), t)
	pot.smashed.connect(_on_smashed)

func _on_smashed(_at: Vector3) -> void:
	_wait = t.pot_respawn

func _physics_process(dt: float) -> void:
	if _wait < 0.0:
		return
	_wait -= dt
	if _wait < 0.0:
		_new_pot()
