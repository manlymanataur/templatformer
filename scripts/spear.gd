class_name Spear
extends Node3D
## Zelda-style spear moves. Each move hits each hurtable thing at most once, during its active window.
##   Quick combo: press attack up to three times in a row. Jab, jab, then a wide sweep (2 damage).
##   Long slash: attack while running fast (not locked on). You lunge forward with a long reach.
##   Air slash: attack in the air. A downward cut in front of you.
##   Spin: hold attack until the tip glows, then let go. Hits all around you.

const COMBO_WINDOW := 0.35 ## after a move ends, press again within this to continue the combo

## name: duration, active from/to, damage, hit shape ("box" size and forward offset, or "sphere" radius)
const MOVES := {
	"jab": {"dur": 0.26, "from": 0.04, "to": 0.16, "dmg": 1, "box": Vector3(0.9, 1.2, 1.8), "fwd": 1.4},
	"jab2": {"dur": 0.26, "from": 0.04, "to": 0.16, "dmg": 1, "box": Vector3(0.9, 1.2, 1.8), "fwd": 1.4},
	"sweep": {"dur": 0.42, "from": 0.1, "to": 0.28, "dmg": 2, "box": Vector3(3.2, 1.2, 2.2), "fwd": 1.3},
	"lunge": {"dur": 0.4, "from": 0.05, "to": 0.3, "dmg": 2, "box": Vector3(1.2, 1.2, 3.2), "fwd": 2.0},
	"air": {"dur": 0.36, "from": 0.05, "to": 0.3, "dmg": 2, "box": Vector3(1.4, 2.0, 2.2), "fwd": 1.2},
	"spin": {"dur": 0.5, "from": 0.05, "to": 0.4, "dmg": 2, "sphere": 2.6},
}
const COMBO := ["jab", "jab2", "sweep"]

var player: Player
var busy := 0.0
var move := ""
var charged := false
var combo_step := 0
var since_end := 99.0
var queued := false
var _hit: Array = []
var _shaft: Node3D
var _tip_mat: StandardMaterial3D

func _ready() -> void:
	_shaft = Node3D.new()
	add_child(_shaft)
	var pole := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.07, 0.07, 1.6)
	pole.mesh = bm
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.55, 0.4, 0.25)
	pole.material_override = wood
	_shaft.add_child(pole)
	var tip := MeshInstance3D.new()
	var tm := PrismMesh.new()
	tm.size = Vector3(0.2, 0.35, 0.08)
	tip.mesh = tm
	_tip_mat = StandardMaterial3D.new()
	_tip_mat.albedo_color = Color(0.85, 0.85, 0.9)
	_tip_mat.metallic = 0.8
	tip.material_override = _tip_mat
	tip.rotation_degrees = Vector3(-90, 0, 0)
	tip.position = Vector3(0, 0, -0.95)
	_shaft.add_child(tip)
	position = Vector3(0.35, 0.05, -0.2)

## Attack button pressed: pick the move from what you're doing.
func press() -> void:
	if busy > 0.0:
		queued = move in COMBO # buffer the next combo hit
		return
	if not player.is_on_floor():
		start("air")
	elif player.flat_speed() > 9.0 and not player.target_held:
		start("lunge")
	else:
		var step := combo_step if since_end <= COMBO_WINDOW else 0
		start(COMBO[step])
		combo_step = (step + 1) % COMBO.size()

func spin() -> void:
	busy = 0.0
	start("spin")
	combo_step = 0

func start(m: String) -> void:
	move = m
	busy = MOVES[m]["dur"]
	queued = false
	_hit.clear()
	if m == "lunge":
		var f := player._flat_facing()
		player.velocity.x = f.x * 16.0
		player.velocity.z = f.z * 16.0

func _physics_process(dt: float) -> void:
	visible = player.inventory.has("spear")
	_tip_mat.emission_enabled = charged
	_tip_mat.emission = Color(0.6, 0.8, 1.0) * 2.0
	if busy <= 0.0:
		since_end += dt
		_shaft.position = Vector3.ZERO
		rotation = Vector3.ZERO
		return
	busy -= dt
	var def: Dictionary = MOVES[move]
	var dur: float = def["dur"]
	var t := dur - busy
	var k := clampf(t / dur, 0.0, 1.0)
	_animate(k)
	if busy <= 0.0:
		since_end = 0.0
		if queued and combo_step != 0:
			queued = false
			start(COMBO[combo_step])
			combo_step = (combo_step + 1) % COMBO.size()
		return
	if t < def["from"] or t > def["to"]:
		return
	_hit_query(def)

func _animate(k: float) -> void:
	_shaft.position = Vector3.ZERO
	rotation = Vector3.ZERO
	match move:
		"jab", "jab2", "lunge":
			_shaft.position.z = -sin(k * PI) * (2.0 if move == "lunge" else 1.2)
		"sweep":
			rotation.y = lerpf(1.4, -1.4, k)
			_shaft.position.z = -0.6
		"air":
			rotation.x = lerpf(0.9, -1.2, k)
			_shaft.position.z = -0.6
		"spin":
			rotation.y = k * TAU
			_shaft.position.z = -0.8

func _hit_query(def: Dictionary) -> void:
	var fwd := player._flat_facing()
	var q := PhysicsShapeQueryParameters3D.new()
	if def.has("sphere"):
		var sph := SphereShape3D.new()
		sph.radius = def["sphere"]
		q.shape = sph
		q.transform = Transform3D(Basis(), player.global_position)
	else:
		var box := BoxShape3D.new()
		box.size = def["box"]
		q.shape = box
		var centre := player.global_position + fwd * float(def["fwd"])
		if move == "air":
			centre += Vector3.DOWN * 0.6
		q.transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), centre)
	q.exclude = [player.get_rid()]
	for r in player.get_world_3d().direct_space_state.intersect_shape(q, 16):
		var c = r["collider"]
		if c != null and c.is_in_group("hurtable") and not _hit.has(c):
			_hit.append(c)
			c.hurt(int(def["dmg"]), player.global_position)
