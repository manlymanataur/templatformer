class_name Bomb
extends CharacterBody3D
## Bomb. Pulled out overhead with its fuse already lit, then thrown in an arc or set down.
## After FUSE seconds it hurts everything hurtable within RADIUS, you included (even if you're still holding it).
## It's carryable (hold, set_down, throw), so the clockwork spider can pick up one that's lying about.

const FUSE := 2.5
const RADIUS := 3.5
const DAMAGE := 2
const GRAVITY := 30.0

var holder: Node3D = null ## the player or the spider carrying it
var _t := 0.0
var _mat: StandardMaterial3D
var _exploded := false

func _ready() -> void:
	add_to_group("carryable")
	collision_layer = 0 # nothing bumps into a bomb
	collision_mask = 1
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
		velocity.y -= GRAVITY * dt
		if is_on_floor():
			var hv := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, 20.0 * dt)
			velocity.x = hv.x
			velocity.z = hv.z
		move_and_slide()
	if _t >= FUSE:
		explode()

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
		if node.global_position.distance_to(global_position) <= RADIUS:
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
