class_name Bomb
extends CharacterBody3D
## Bomb. Pulled out overhead with its fuse already lit, then thrown in an arc or set down.
## After FUSE seconds it hurts everything hurtable within RADIUS, you included (even if you're still holding it).
## It's carryable (hold, set_down, throw), so the clockwork spider can pick up one that's lying about.
## Powers book: on the ground it stops quickly (t.bomb_friction). An attack whose hit shape reaches it bats it
## away at t.bomb_bat_speed, and a bomb flying faster than BAT_FUSE_SPEED goes off on the first monster it hits.
## Pound onto it and it goes off under you: a bomb jump (t.bomb_jump_speed up) that doesn't hurt you.
## A blast is a "blast" strike on monsters, the only thing that cracks a PlatedBrute's plates.

const FUSE := 2.5
const RADIUS := 3.5
const DAMAGE := 2
const GRAVITY := 30.0
const BAT_FUSE_SPEED := 6.0 ## flying faster than this, it goes off on contact with a monster

var holder: Node3D = null ## the player or the spider carrying it
var _t := 0.0
var _mat: StandardMaterial3D
var _exploded := false
var _bat_cd := 0.0
var _spare: Node = null ## a bomb jump: the one riding the blast isn't hurt by it

func _ready() -> void:
	add_to_group("carryable")
	collision_layer = 0 # nothing bumps into a bomb
	collision_mask = 1
	var p := _player()
	if p != null:
		add_collision_exception_with(p) # nor does it bump into you: you can run through your own throw
	var c := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = 0.3
	c.shape = s
	add_child(c)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.35
	sm.height = 0.7
	mi.mesh = sm
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = Color(0.15, 0.15, 0.2)
	mi.material_override = _mat
	add_child(mi)

func carry_size() -> Vector3:
	return Vector3.ONE * 0.7

func hold(by: Node3D) -> void:
	holder = by
	velocity = Vector3.ZERO

func throw(v: Vector3) -> void:
	holder = null
	velocity = v

func set_down(pos: Vector3) -> void:
	holder = null
	global_position = pos
	velocity = Vector3.ZERO

func _physics_process(dt: float) -> void:
	if _exploded:
		return
	_t += dt
	var blink := fmod(_t * (3.0 + _t * 6.0), 1.0) < 0.5
	_mat.albedo_color = Color(0.9, 0.3, 0.2) if blink else Color(0.15, 0.15, 0.2)
	if holder != null and not is_instance_valid(holder):
		holder = null
	if holder != null:
		global_position = holder.global_position + Vector3.UP * (holder.radius() + 0.5)
	else:
		var p := _player()
		_bat_cd -= dt
		if p != null and _bomb_jump(p):
			return
		if p != null and _bat_cd <= 0.0:
			_bat(p)
		velocity.y -= GRAVITY * dt
		if is_on_floor():
			var fr := p.t.bomb_friction if p != null else 20.0
			var hv := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, fr * dt)
			velocity.x = hv.x
			velocity.z = hv.z
		var fast := Vector2(velocity.x, velocity.z).length() > BAT_FUSE_SPEED
		move_and_slide()
		if fast:
			for i in get_slide_collision_count():
				if get_slide_collision(i).get_collider() is Monster:
					explode()
					return
	if _t >= FUSE:
		explode()

func _player() -> Player:
	var ps := get_tree().get_nodes_in_group("player")
	return ps[0] as Player if not ps.is_empty() else null

## Your poleaxe's hit shape reaching the bomb during the move's active frames bats it the way you face.
func _bat(p: Player) -> void:
	var pa := p.poleaxe
	if pa == null or pa.busy <= 0.0 or pa.frozen or not Poleaxe.MOVES.has(pa.move):
		return
	var def: Dictionary = Poleaxe.MOVES[pa.move]
	var el := float(def["dur"]) - pa.busy
	if el < float(def["from"]) or el > float(def["to"]):
		return
	var rel := global_position - p.global_position
	var fwd := p._flat_facing()
	if def.has("sphere"):
		if rel.length() > float(def["sphere"]) + 0.3:
			return
		fwd = Vector3(rel.x, 0, rel.z).normalized() if Vector2(rel.x, rel.z).length() > 0.1 else fwd
	else:
		var box: Vector3 = def["box"]
		var along := rel.dot(fwd) - float(def["fwd"])
		var side := rel.dot(fwd.cross(Vector3.UP))
		if absf(along) > box.z / 2.0 + 0.3 or absf(side) > box.x / 2.0 + 0.3 or absf(rel.y) > box.y / 2.0 + 0.8:
			return
	_bat_cd = 0.4
	velocity = fwd * p.t.bomb_bat_speed + Vector3.UP * p.t.bomb_bat_up
	global_position.y += 0.05
	Hitfx.sparks(get_tree(), global_position, 0.6)

## A ground pound landing on the bomb sets it off under you and throws you up, unhurt.
func _bomb_jump(p: Player) -> bool:
	if not (p.pound_t >= p.t.pound_hover or p.pound_land < 0.1):
		return false
	var rel := global_position - p.global_position
	if Vector2(rel.x, rel.z).length() > p.radius() + 0.6 or rel.y > 0.3 or rel.y < -(p.radius() + 1.6):
		return false
	_spare = p
	explode()
	p.pound_t = -1.0
	p.pound_land = 99.0
	p.launch(Vector3.UP * p.t.bomb_jump_speed)
	return true

func explode() -> void:
	_exploded = true
	Hitfx.shake(get_tree(), 0.35)
	if holder != null and not is_instance_valid(holder):
		holder = null
	if holder is Player and (holder as Player).carrying == self:
		(holder as Player).carrying = null
	elif holder is Spider and (holder as Spider).held == self:
		(holder as Spider).held = null
	for n in get_tree().get_nodes_in_group("hurtable"):
		var node := n as Node3D
		if node == _spare:
			continue
		if node.global_position.distance_to(global_position) <= RADIUS:
			if node is Monster:
				(node as Monster).strike(DAMAGE, global_position, {"blast": true, "stagger": true})
			else:
				node.hurt(DAMAGE, global_position)
	for n in get_tree().get_nodes_in_group("blastable"): # things only a blast breaks (a colossus's shins)
		var node := n as Node3D
		if node.global_position.distance_to(global_position) <= RADIUS:
			node.blast(global_position)
	var flash := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = RADIUS
	sm.height = RADIUS * 2.0
	flash.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1, 0.6, 0.2, 0.5)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	flash.material_override = m
	add_child(flash)
	get_tree().create_timer(0.25, false).timeout.connect(queue_free)
