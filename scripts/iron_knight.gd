class_name IronKnight
extends Monster
## An iron knight (Power Combat Sketchbook II, Lodestone). A shield monster in iron armour that feels your
## magnet the way iron blocks do, but it's free to move, so the rule is aim instead of the grid: a knight
## within t.knight_magnet_range in front of you (where you face; lock on to aim), with a clear line, is moved.
##   Pull (negative): it slides to you at t.knight_pull_speed, stunned, and its shield stays down for
##     t.knight_open_time: hit it from the front.
##   Push (positive): it's blown away at t.knight_push_knock, splatting on walls and bowling into the pack.
## After the magnet has moved it, it ignores the magnet for t.knight_magnet_cd. Iron blocks shoved into it
## (IronCube._plough) knock it like any monster.

var shield_down := 0.0 ## seconds left with the shield down
var pulled := false ## sliding toward you right now
var _mag_cd := 0.0

static func make(parent: Node, pos: Vector3) -> IronKnight:
	var k := IronKnight.new()
	k.kind = "shield"
	k.position = pos
	parent.add_child(k)
	k.global_position = pos
	k.home = pos
	return k

func _ready() -> void:
	super._ready()
	add_to_group("iron_knights")
	max_hp = 5
	hp = max_hp
	_base = Color(0.55, 0.58, 0.64)
	_mat.metallic = 0.7
	_mat.roughness = 0.35
	_mat.albedo_color = _base

func _physics_process(dt: float) -> void:
	shield_down = maxf(shield_down - dt * Hitfx.world, 0.0)
	_mag_cd = maxf(_mag_cd - dt * Hitfx.world, 0.0)
	_magnet()
	if _shield != null:
		_shield.position = Vector3(0, -0.45, -0.6) if shield_down > 0.0 else Vector3(0, 0.05, -0.75)
		_shield.rotation.x = -1.1 if shield_down > 0.0 else 0.0
	super._physics_process(dt)

func _magnet() -> void:
	pulled = false
	var p := _player()
	if p == null or _mag_cd > 0.0 or hp <= 0 or not p.inventory.equipped("magnet") or p.small:
		return
	var d := global_position - p.global_position
	d.y = 0.0
	var dist := d.length()
	if dist < 0.1 or dist > p.t.knight_magnet_range or absf(global_position.y - p.global_position.y) > 2.0:
		return
	if p._flat_facing().dot(d / dist) < 0.8:
		return # not in front of you
	var q := PhysicsRayQueryParameters3D.create(p.global_position, global_position, 1, [get_rid(), p.get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		return # something solid between you shields it
	if p.magnet_push:
		_mag_cd = p.t.knight_magnet_cd
		shield_down = maxf(shield_down, 0.8)
		strike(1, p.global_position, {"knock": p.t.knight_push_knock, "stagger": true, "above": true})
		return
	if dist > 1.4 + _r + p.radius():
		pulled = true
		shield_down = maxf(shield_down, p.t.knight_open_time)
		stun = maxf(stun, 0.3)
		state = "move"
		velocity.x = -d.x / dist * p.t.knight_pull_speed
		velocity.z = -d.z / dist * p.t.knight_pull_speed
	else:
		# it's arrived in front of you: the magnet lets go and its guard is open
		_mag_cd = p.t.knight_magnet_cd
		shield_down = maxf(shield_down, p.t.knight_open_time)
		velocity.x = 0.0
		velocity.z = 0.0

## With its shield down every hit lands as if from above the shield.
func strike(amount: int, from: Vector3, info: Dictionary) -> int:
	if shield_down > 0.0 and not info.get("above", false):
		var open := info.duplicate()
		open["above"] = true
		return super.strike(amount, from, open)
	return super.strike(amount, from, info)
