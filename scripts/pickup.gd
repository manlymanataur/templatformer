class_name Pickup
extends Area3D
## A spinning item in the world. id is an inventory item, or "heart" (heals 1 heart).

var id := ""
var amount := 1
var _t := 0.0
var _mesh: MeshInstance3D

static func spawn(parent: Node, item_id: String, n: int, pos: Vector3) -> Pickup:
	var p := Pickup.new()
	p.id = item_id
	p.amount = n
	parent.add_child(p)
	p.global_position = pos
	return p

func _ready() -> void:
	add_to_group("pickups")
	var c := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.8
	c.shape = s
	add_child(c)
	_mesh = MeshInstance3D.new()
	var m := StandardMaterial3D.new()
	if id == "heart":
		var bm := SphereMesh.new()
		bm.radius = 0.25
		bm.height = 0.5
		_mesh.mesh = bm
		m.albedo_color = Color(1, 0.3, 0.4)
	elif id == "poleaxe":
		var bm := BoxMesh.new()
		bm.size = Vector3(0.08, 0.08, 1.6)
		_mesh.mesh = bm
		m.albedo_color = Inventory.ITEMS[id]["color"]
	else:
		var bm := BoxMesh.new()
		bm.size = Vector3(0.45, 0.45, 0.45)
		_mesh.mesh = bm
		m.albedo_color = Inventory.ITEMS[id]["color"]
	m.emission_enabled = true
	m.emission = m.albedo_color * 0.4
	_mesh.material_override = m
	add_child(_mesh)
	body_entered.connect(_on_body)

func _process(dt: float) -> void:
	_t += dt
	_mesh.rotation.y = _t * 2.0
	_mesh.position.y = sin(_t * 3.0) * 0.12

func _on_body(b: Node) -> void:
	if not b is Player:
		return
	var p := b as Player
	if id == "heart":
		p.hp = mini(p.hp + 2 * amount, p.max_hp)
	else:
		p.inventory.add(id, amount)
	queue_free()
