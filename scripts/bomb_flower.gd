class_name BombFlower
extends StaticBody3D
## A bomb plant, like Ocarina's bomb flowers. Context button next to it pulls its bomb, fuse lit, into your
## hands (see Player.context). It grows a new one after t.bomb_regrow seconds.
## Bombs aren't an item you keep: you carry them from the plant, so each one is a little trip.

var t: Tuning
var _grow := 1.0 ## 0 just picked, 1 ripe
var _bud: MeshInstance3D

static func make(parent: Node, pos: Vector3, tuning: Tuning) -> BombFlower:
	var f := BombFlower.new()
	f.t = tuning
	f.position = pos
	parent.add_child(f)
	return f

func _ready() -> void:
	add_to_group("bomb_flowers")
	collision_layer = 1 << 1 # a low stalk: it stops you like a railing but doesn't block light or the rope
	var c := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.25
	cs.height = 0.6
	c.shape = cs
	c.position.y = 0.3
	add_child(c)
	var leaf := StandardMaterial3D.new()
	leaf.albedo_color = Color(0.25, 0.55, 0.25)
	for k in 4:
		var l := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.18, 0.04, 0.7)
		l.mesh = bm
		l.material_override = leaf
		l.rotation.y = k * PI / 4.0
		l.position.y = 0.08
		add_child(l)
	var stalk := MeshInstance3D.new()
	var sm := CylinderMesh.new()
	sm.top_radius = 0.05
	sm.bottom_radius = 0.08
	sm.height = 0.5
	stalk.mesh = sm
	stalk.material_override = leaf
	stalk.position.y = 0.25
	add_child(stalk)
	_bud = MeshInstance3D.new()
	var bud := SphereMesh.new()
	bud.radius = 0.3
	bud.height = 0.6
	_bud.mesh = bud
	var bmat := StandardMaterial3D.new()
	bmat.albedo_color = Color(0.15, 0.15, 0.2)
	_bud.material_override = bmat
	_bud.position.y = 0.75
	add_child(_bud)

func ripe() -> bool:
	return _grow >= 1.0

func pick() -> void:
	_grow = 0.0

func _physics_process(dt: float) -> void:
	_grow = minf(_grow + dt / maxf(t.bomb_regrow, 0.1), 1.0)
	_bud.scale = Vector3.ONE * maxf(_grow, 0.05)
	_bud.visible = _grow > 0.05
