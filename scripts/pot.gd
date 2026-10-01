class_name Pot
extends CharacterBody3D
## A clay pot. Pick it up with the context button and it rides over your head (hands full, like a seed).
## - Carried empty into a pool or deep water, or under a spout (honey hive, wine cask, water pipe), it fills.
## - Context while moving throws it: pot_throw_speed plus pot_throw_run times your running speed, up at
##   pot_throw_up. Standing still, a full pot is lobbed (about 5 m) and an empty one is set down in front of you.
## - A thrown pot smashes on whatever it touches first and spills (Liquids.spill): on a monster, honey sticks to
##   it. Poleaxe hits and bomb blasts smash a pot where it stands (it's hurtable). Pots fly through bars.
## - In group "carryable": anything that carries things uses hold / set_down / throw, like a seed.
## A PotShelf puts out a new pot after its pot smashes.

signal smashed(at: Vector3)

const R := 0.35

var t: Tuning
var liquid := "" ## "", "water", "wine" or "honey"
var holder: Node3D = null
var flying := false
var _gone := false
var _col: CollisionShape3D
var _fill: MeshInstance3D
var _fill_mat: StandardMaterial3D

static func make(parent: Node, pos: Vector3, tuning: Tuning, k := "") -> Pot:
	var p := Pot.new()
	p.t = tuning
	p.liquid = k
	p.position = pos
	parent.add_child(p)
	return p

func _ready() -> void:
	if t == null:
		t = Liquids.tuning(get_tree())
	add_to_group("pots")
	add_to_group("carryable")
	add_to_group("hurtable")
	collision_layer = 1 << 4 # a prop: you bump into it
	collision_mask = 1 | 1 << 2 | 1 << 3 | 1 << 4 # the world (and bodies), grates, Umbra, props; not bars
	floor_max_angle = deg_to_rad(50)
	_col = CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = R
	_col.shape = sh
	add_child(_col)
	var clay := StandardMaterial3D.new()
	clay.albedo_color = Color(0.72, 0.4, 0.25)
	var belly := MeshInstance3D.new()
	var bm := SphereMesh.new()
	bm.radius = R + 0.02
	bm.height = (R + 0.02) * 1.8
	belly.mesh = bm
	belly.material_override = clay
	add_child(belly)
	var neck := MeshInstance3D.new()
	var nm := CylinderMesh.new()
	nm.top_radius = 0.2
	nm.bottom_radius = 0.16
	nm.height = 0.2
	neck.mesh = nm
	neck.material_override = clay
	neck.position.y = R * 0.85
	add_child(neck)
	_fill = MeshInstance3D.new()
	var fm := CylinderMesh.new()
	fm.top_radius = 0.17
	fm.bottom_radius = 0.17
	fm.height = 0.03
	_fill.mesh = fm
	_fill_mat = StandardMaterial3D.new()
	_fill_mat.emission_enabled = true
	_fill.material_override = _fill_mat
	_fill.position.y = R * 0.85 + 0.09
	add_child(_fill)
	_show()

func _show() -> void:
	_fill.visible = liquid != ""
	if liquid != "":
		var c: Color = Puddle.COLORS[liquid]
		_fill_mat.albedo_color = Color(c.r, c.g, c.b)
		_fill_mat.emission = Color(c.r, c.g, c.b) * 0.4

func fill(k: String) -> void:
	liquid = k
	_show()

func _holder_r() -> float:
	return holder.radius() if holder.has_method("radius") else 0.5

## Its box for carriers (the spider) that need one.
func carry_size() -> Vector3:
	return Vector3.ONE * R * 2.0

## Pick it up (a player, or anything else that carries).
func hold(h: Node3D) -> void:
	holder = h
	flying = false
	velocity = Vector3.ZERO
	_col.set_deferred("disabled", true) # it rides over your head without bumping anything

func set_down(pos: Vector3) -> void:
	holder = null
	flying = false
	global_position = pos
	velocity = Vector3.ZERO
	_col.set_deferred("disabled", false)

## Throw it: it smashes on the first thing it touches. by (whoever threw it) doesn't count.
func throw(v: Vector3, by: Node = null) -> void:
	if by == null:
		by = holder
	holder = null
	flying = true
	velocity = v
	if by is PhysicsBody3D:
		add_collision_exception_with(by)
	_col.set_deferred("disabled", false)

func _physics_process(dt: float) -> void:
	if _gone:
		return
	if holder != null:
		if not is_instance_valid(holder):
			holder = null
			_col.set_deferred("disabled", false)
			return
		global_position = holder.global_position + Vector3.UP * (_holder_r() + R + 0.15)
		velocity = Vector3.ZERO
		if liquid == "":
			var k := Liquids.source_at(get_tree(), global_position)
			if k != "":
				fill(k)
		return
	velocity.y -= t.gravity * dt
	if is_on_floor() and not flying:
		var hv := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, 20.0 * dt)
		velocity.x = hv.x
		velocity.z = hv.z
	move_and_slide()
	if flying and get_slide_collision_count() > 0:
		smash(get_slide_collision(0).get_collider() as Node)
		return
	if global_position.y < -30.0:
		_gone = true
		smashed.emit(global_position)
		queue_free()

## Hit by the poleaxe, a bomb or anything else that hurts: it breaks where it is.
func hurt(_amount: int, _from: Vector3) -> void:
	smash(null)

## Break and spill. hit is what it broke on, if anything.
func smash(hit: Node = null) -> void:
	if _gone:
		return
	_gone = true
	if holder != null and "held_pot" in holder and holder.held_pot == self:
		holder.held_pot = null
	holder = null
	var at := global_position
	Hitfx.sparks(get_tree(), at, 0.8)
	_shards(at)
	var k := liquid
	liquid = ""
	smashed.emit(at)
	if k != "":
		Liquids.spill(get_parent(), k, at, hit)
	queue_free()

## A few clay pieces that fall and fade.
func _shards(at: Vector3) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = 10
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.direction = Vector3.UP
	p.spread = 70.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 5.0
	var bm := BoxMesh.new()
	bm.size = Vector3.ONE * 0.12
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.72, 0.4, 0.25)
	bm.material = m
	p.mesh = bm
	get_parent().add_child(p)
	p.global_position = at
	p.emitting = true
	get_tree().create_timer(1.0, false).timeout.connect(p.queue_free)
