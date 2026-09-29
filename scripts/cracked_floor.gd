class_name CrackedFloor
extends StaticBody3D
## A cracked tile. At normal size your weight breaks it: a moment after you stand on it, it crumbles away.
## Small, you're too light to crack it. It sets again a few seconds later once you're clear of it.

const CRUMBLE_TIME := 0.35
const REFORM_TIME := 6.0

var size := Vector3(2, 0.4, 2)
var broken := false
var _t := -1.0 ## counts down to crumbling once cracked, then up to reforming
var _col: CollisionShape3D
var _vis: Node3D

## top is the middle of the tile's top face.
static func make(parent: Node, top: Vector3, tile := Vector3(2, 0.4, 2)) -> CrackedFloor:
	var f := CrackedFloor.new()
	f.size = tile
	parent.add_child(f)
	f.global_position = top - Vector3.UP * tile.y / 2.0
	return f

func _ready() -> void:
	_col = CollisionShape3D.new()
	var s := BoxShape3D.new()
	s.size = size
	_col.shape = s
	add_child(_col)
	_vis = Node3D.new()
	add_child(_vis)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size - Vector3(0.04, 0, 0.04)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.62, 0.55, 0.46)
	mi.material_override = m
	_vis.add_child(mi)
	var crack := StandardMaterial3D.new()
	crack.albedo_color = Color(0.18, 0.15, 0.12)
	for k in 3: # dark crack lines on the top
		var line := MeshInstance3D.new()
		var lm := BoxMesh.new()
		lm.size = Vector3(size.x * 0.7, 0.02, 0.05)
		line.mesh = lm
		line.material_override = crack
		line.position = Vector3(0, size.y / 2.0 + 0.005, (k - 1) * size.z * 0.25)
		line.rotation.y = 0.5 + k * 0.9
		_vis.add_child(line)

## Something heavy is standing on it.
func step() -> void:
	if not broken and _t < 0.0:
		_t = CRUMBLE_TIME

func _physics_process(dt: float) -> void:
	if _t < 0.0:
		return
	if not broken:
		_t -= dt
		_vis.position.x = sin(_t * 90.0) * 0.03 # it shudders before it goes
		if _t <= 0.0:
			broken = true
			_t = 0.0
			_col.set_deferred("disabled", true)
			_vis.visible = false
		return
	_t += dt
	var ps := get_tree().get_nodes_in_group("player")
	var clear := true
	for p in ps:
		var d: Vector3 = (p as Node3D).global_position - global_position
		clear = clear and Vector2(d.x, d.z).length() > 2.5 # not while you're over it, even high up in a fan's lane
	if _t >= REFORM_TIME and clear:
		broken = false
		_t = -1.0
		_col.set_deferred("disabled", false)
		_vis.visible = true
		_vis.position.x = 0.0
