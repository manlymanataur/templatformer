class_name Poleaxe
extends Node3D
## The poleaxe: one attack button, and what you're doing picks which of its three heads you use.
##   Point (the spike on top): standing or walking, attack is a thrust, thrust, then a blade sweep that
##     launches. The tip is the sweet spot: hit with the last stretch of its reach (TIP_FROM) for double.
##   Blade (the axe): the sweep (its edge is the sweet spot: EDGE_FROM out, +1), the running blade (attack while
##     running faster than run_attack_speed; it keeps your speed, knocks back by it, and does +1 above
##     fast_blade_speed, which only downhills reach), the air slash and the spin.
##   Hammer (the back of the head): hold attack. The swing freezes at the end of its startup (a delay), and
##     let go after hammer_hold it comes out as the hammer: it staggers, breaks shields and armour, and spikes
##     airborne monsters down. Its centre (HAMMER_BAND) is the sweet spot: +2.
##   Spin: hold even longer (spin_charge_time) and let go for a whirl all around you, on the ground or in the
##     air (a charge carries through a jump, and a spin in the air slows your fall).
## After a hit connects you can cancel the rest of the swing into the next attack. There is no whiff penalty.
## A perfect guard (see Player) makes your next sweet-spot hit +2 and a stagger.
## Wearing the lit candle hat sets the poleaxe on fire: every move also sets alight whatever it sweeps
## (grass, vines, braziers, ice). Umbra copies each move with its greatsword (move_started).

signal move_started(move: String)

const COMBO_WINDOW := 0.35 ## after a move ends, press again within this to continue the combo
const REACH := 2.0 ## the weapon's size: jovi doubled it (2026-10-01). Every range and hit shape below scales with it.
const TIP_FROM := 2.25 * REACH ## a point hit this far out (centre to centre) is a tipper: double damage
const EDGE_FROM := 2.0 * REACH ## a blade hit this far out is on the edge: +1
const HAMMER_BAND := Vector2(1.4, 2.6) * REACH ## a hammer hit in this band lands the head's centre: +2

## name: duration, active from/to, damage, head, hit shape ("box" size and forward offset, or "sphere"
## radius), knockback speed, and whether it launches, staggers or spikes. The bash is the shield's, so it
## doesn't grow with REACH.
const MOVES := {
	"thrust": {"dur": 0.3, "from": 0.08, "to": 0.18, "dmg": 1, "head": "point", "box": Vector3(0.9, 1.3, 2.8) * REACH, "fwd": 1.7 * REACH, "knock": 6.0},
	"thrust2": {"dur": 0.3, "from": 0.08, "to": 0.18, "dmg": 1, "head": "point", "box": Vector3(0.9, 1.3, 2.8) * REACH, "fwd": 1.7 * REACH, "knock": 6.0},
	"sweep": {"dur": 0.44, "from": 0.12, "to": 0.28, "dmg": 2, "head": "blade", "box": Vector3(3.6, 1.3, 2.6) * REACH, "fwd": 1.4 * REACH, "knock": 5.0, "launch": true},
	"run": {"dur": 0.4, "from": 0.06, "to": 0.28, "dmg": 2, "head": "blade", "box": Vector3(3.0, 1.3, 2.8) * REACH, "fwd": 1.5 * REACH, "knock": 8.0},
	"hammer": {"dur": 0.42, "from": 0.06, "to": 0.2, "dmg": 2, "head": "hammer", "box": Vector3(1.6, 2.2, 2.6) * REACH, "fwd": 1.8 * REACH, "knock": 13.0, "stagger": true, "spike": true},
	"spin": {"dur": 0.55, "from": 0.05, "to": 0.45, "dmg": 2, "head": "blade", "sphere": 2.9 * REACH, "knock": 8.0},
	"air": {"dur": 0.36, "from": 0.05, "to": 0.3, "dmg": 2, "head": "blade", "box": Vector3(1.6, 2.2, 2.4) * REACH, "fwd": 1.3 * REACH, "knock": 5.0},
	"bash": {"dur": 0.3, "from": 0.04, "to": 0.14, "dmg": 1, "head": "shield", "box": Vector3(1.6, 1.4, 1.6), "fwd": 1.0, "knock": 10.0},
	"flash": {"dur": 0.3, "from": 0.1, "to": 0.2, "dmg": 4, "head": "point", "box": Vector3(0.9, 1.4, 2.8) * REACH, "fwd": 1.7 * REACH, "knock": 8.0, "stagger": true},
}
const COMBO := ["thrust", "thrust2", "sweep"]
const HOLDABLE := ["thrust", "thrust2", "sweep", "run"] ## these freeze at the end of their startup while you hold attack

var player: Player
var busy := 0.0
var move := ""
var combo_step := 0
var since_end := 99.0
var queued := false
var button := false ## the attack button is down (the player sets it each frame)
var charge := 0.0 ## how long attack has been held since the press that started this move
var frozen := false ## held at the end of the startup, waiting for you to let go
var stuck_t := 0.0 ## after a brace impales something the poleaxe is stuck in it for a moment
var _hit: Array = []
var _shaft: Node3D
var _tip_mat: StandardMaterial3D
var _fire: MeshInstance3D

func _ready() -> void:
	_shaft = Node3D.new()
	_shaft.scale = Vector3.ONE * REACH # the parts below are the old size; the whole weapon is REACH times bigger
	add_child(_shaft)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.32, 0.2)
	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.8, 0.82, 0.88)
	steel.metallic = 0.8
	_part(Vector3(0.07, 0.07, 2.2), Vector3(0, 0, -0.3), wood)
	# the head: a spike on top, the axe blade on one side, the hammer on the other
	var tip := MeshInstance3D.new()
	var tm := PrismMesh.new()
	tm.size = Vector3(0.16, 0.4, 0.06)
	tip.mesh = tm
	_tip_mat = steel.duplicate()
	tip.material_override = _tip_mat
	tip.rotation_degrees = Vector3(-90, 0, 0)
	tip.position = Vector3(0, 0, -1.6)
	_shaft.add_child(tip)
	_part(Vector3(0.36, 0.05, 0.34), Vector3(-0.22, 0, -1.25), steel) # blade
	_part(Vector3(0.2, 0.16, 0.16), Vector3(0.14, 0, -1.25), steel) # hammer
	_fire = Burnable.flame_mesh(0.35)
	_fire.position = Vector3(0, 0, -1.5)
	_fire.rotation_degrees = Vector3(-90, 0, 0)
	_shaft.add_child(_fire)
	position = Vector3(0.35, 0.05, -0.2)

func _part(size: Vector3, at: Vector3, mat: Material) -> void:
	var m := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	m.mesh = bm
	m.material_override = mat
	m.position = at
	_shaft.add_child(m)

## Attack button pressed: pick the move from what you're doing.
func press() -> void:
	if stuck_t > 0.0:
		return
	if busy > 0.0:
		if not _hit.is_empty() and move != "spin" and _elapsed() > float(MOVES[move]["to"]):
			busy = 0.0 # hit-cancel: a swing that connected can go straight into the next
		else:
			queued = move in COMBO # buffer the next combo hit
			return
	if player.guarding():
		start("bash")
	elif not player.is_on_floor():
		start("air")
	elif player.flat_speed() > player.t.run_attack_speed and not player.target_held:
		start("run")
	else:
		var step := combo_step if since_end <= COMBO_WINDOW else 0
		start(COMBO[step])
		combo_step = (step + 1) % COMBO.size()
	charge = 0.0

## Measure focus spent: a step in to exactly tip range, and a thrust for flash damage.
func flash() -> void:
	start("flash")
	combo_step = 0

func start(m: String) -> void:
	move = m
	busy = MOVES[m]["dur"]
	queued = false
	frozen = false
	_hit.clear()
	move_started.emit(m)

func _elapsed() -> float:
	return float(MOVES[move]["dur"]) - busy

## How far into its charge the held swing is: 0 none, 1 hammer, 2 spin.
func charge_level() -> int:
	if not frozen:
		return 0
	if charge >= player.t.spin_charge_time:
		return 2
	return 1 if charge >= player.t.hammer_hold else 0

func _physics_process(dt: float) -> void:
	visible = player.inventory.has("poleaxe")
	_fire.visible = player.candle_lit
	stuck_t = maxf(stuck_t - dt, 0.0)
	var lvl := charge_level()
	_tip_mat.emission_enabled = lvl > 0
	_tip_mat.emission = (Color(1.0, 0.8, 0.4) if lvl == 1 else Color(0.6, 0.8, 1.0)) * 2.0
	if busy <= 0.0:
		since_end += dt
		_shaft.position = Vector3.ZERO
		rotation = Vector3.ZERO
		return
	if button:
		charge += dt
	var def: Dictionary = MOVES[move]
	if frozen:
		if button:
			_animate(0.0)
			return
		# let go: the swing goes on, or turns into the hammer or the spin
		frozen = false
		if charge >= player.t.spin_charge_time:
			start("spin")
			combo_step = 0
			return
		if charge >= player.t.hammer_hold:
			start("hammer")
			combo_step = 0
			return
	elif button and move in HOLDABLE and _elapsed() + dt >= float(def["from"]) and _hit.is_empty():
		frozen = true
		return
	busy -= dt
	var dur: float = def["dur"]
	var t := dur - busy
	_animate(clampf(t / dur, 0.0, 1.0))
	if move == "spin" and not player.is_on_floor():
		player.velocity.y = maxf(player.velocity.y, -3.0) # a whirl in the air hangs
	if busy <= 0.0:
		since_end = 0.0
		if queued and combo_step != 0:
			queued = false
			start(COMBO[combo_step])
			combo_step = (combo_step + 1) % COMBO.size()
			charge = 0.0
		return
	if t < def["from"] or t > def["to"]:
		return
	_hit_query(def)
	if player.candle_lit:
		_burn(def, dt)

func _animate(k: float) -> void:
	_shaft.position = Vector3.ZERO
	rotation = Vector3.ZERO
	_animate_at(k)
	_shaft.position *= REACH

func _animate_at(k: float) -> void:
	match move:
		"thrust", "thrust2", "flash":
			_shaft.position.z = 0.5 - sin(k * PI) * 1.4
		"bash":
			_shaft.position.z = 0.5
			rotation.x = 0.6
		"sweep", "run":
			rotation.y = lerpf(1.4, -1.4, k)
			_shaft.position.z = -0.2
		"hammer":
			rotation.x = lerpf(1.3, -0.9, k)
			rotation.z = -1.4
			_shaft.position.z = -0.2
		"air":
			rotation.x = lerpf(0.9, -1.2, k)
			_shaft.position.z = -0.2
		"spin":
			rotation.y = k * TAU
			_shaft.position.z = -0.3
	if frozen:
		rotation.x += 0.5 # drawn back, waiting

## Fire along the move's reach: heat anything flammable the hit shape covers.
func _burn(def: Dictionary, dt: float) -> void:
	dt *= 4.0 # a strike is brief, so it heats hard: one hit catches vines, a few melt ice
	if def.has("sphere"):
		Lighting.spread_heat(player.global_position, def["sphere"], dt, player)
	else:
		var box: Vector3 = def["box"]
		var fwd := player._flat_facing()
		# a few points along the head's reach, each warming what's within half the box width
		for k in 3:
			var p := player.global_position + fwd * (float(def["fwd"]) + (k - 1) * box.z / 3.0)
			Lighting.spread_heat(p, box.x / 2.0, dt, player)

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
		if move == "air" or (move == "hammer" and not player.is_on_floor()):
			centre += Vector3.DOWN * 0.6 * REACH
		q.transform = Transform3D(Basis.looking_at(fwd, Vector3.UP), centre)
	q.exclude = [player.get_rid()]
	for r in player.get_world_3d().direct_space_state.intersect_shape(q, 16):
		var c = r["collider"]
		if c != null and c.is_in_group("hurtable") and not _hit.has(c):
			_hit.append(c)
			var dealt := strike(c, def)
			Hitfx.hit(get_tree(), (c as Node3D).global_position, player.t, 1.3 if dealt > 1 else 1.0)

## One hit on c: work out the sweet spot and what the move does to it.
func strike(c: Node, def: Dictionary) -> int:
	var d := (c as Node3D).global_position - player.global_position
	var dist := Vector2(d.x, d.z).length()
	var head: String = def["head"]
	var dmg := int(def["dmg"])
	var sweet := false
	match head:
		"point":
			sweet = dist >= TIP_FROM and move != "flash"
			if sweet:
				dmg *= 2
		"blade":
			sweet = dist >= EDGE_FROM and move == "sweep"
			if sweet:
				dmg += 1
		"hammer":
			sweet = dist >= HAMMER_BAND.x and dist <= HAMMER_BAND.y
			if sweet:
				dmg += 2
	var sp := player.flat_speed()
	var knock: float = def["knock"]
	if move == "run":
		knock = maxf(knock, sp * 0.9) # knockback scales with your speed
		if sp > player.t.fast_blade_speed:
			dmg += 1
	elif move == "hammer":
		knock += sp * 0.4
	var stagger: bool = def.get("stagger", false)
	if sweet and player.parry_t > 0.0:
		dmg += 2 # a sweet spot right after a perfect guard
		stagger = true
		player.parry_t = 0.0
	var air := not player.is_on_floor()
	if air:
		player.velocity.y = maxf(player.velocity.y, 4.0) # hitting in the air holds you up for the next
	if not c.has_method("strike"):
		c.hurt(dmg, player.global_position)
		return dmg
	return c.strike(dmg, player.global_position, {"head": head, "knock": knock, "launch": def.get("launch", false) and not air,
		"spike": def.get("spike", false), "stagger": stagger, "air": air, "sweet": sweet})
