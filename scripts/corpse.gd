class_name Corpse
extends Node3D
## A dead monster's body: a cheap ragdoll (jovi, 2026-10-03). No physics body: it falls, bounces on layer 1
## with two rays and tumbles, and touches nothing else. The killing blow sets where it flies (harder hits throw
## it further), and how it died shapes it:
##   point   punched straight back        hammer, pound, spike, splat   flattened, a low bounce
##   blade   cut in two, the halves part   spin   spun away              fire (candle hat)   charred
## Then each kind goes its own way over the last moments: burst (it swells and pops), dissolve (it sinks and
## fades) or disintegrate (it crumbles into rising motes). Every corpse is gone within LIFE, and at most MAX
## lie around at once: a new one pops the oldest.

const LIFE := 1.5
const MAX := 4
const GRAVITY := 30.0
const FADE := 0.7 ## the death style plays over the last this many seconds
const STYLE := {"blob": "burst", "rusher": "burst", "wolf": "dissolve", "brute": "dissolve",
	"archer": "disintegrate", "shield": "disintegrate", "caster": "disintegrate"}

static var live: Array = []

var style := "burst"
var head := ""
var vel := Vector3.ZERO
var t := 0.0
var rest := 0.55 ## its centre sits this high over the floor
var color := Color.WHITE
var _axis := Vector3.RIGHT
var _rate := 0.0
var _parts: Array[Node3D] = []
var _part_vel: Array[Vector3] = []
var _part_scale: Array[Vector3] = []
var _popped := false
var _moted := false

static func spawn(m: Monster, how: Dictionary) -> Corpse:
	var c := Corpse.new()
	c.style = STYLE.get(m.kind, "dissolve")
	c.head = how.get("head", "")
	c.rest = m._r
	c.color = m._base
	m.get_parent().add_child(c)
	c.global_transform = m.global_transform
	var vis: Node3D = m._vis
	vis.reparent(c, true)
	vis.scale = Vector3.ONE
	var away: Vector3 = how.get("away", Vector3.ZERO)
	away.y = 0.0
	away = away.normalized() if away.length() > 0.01 else Vector3.ZERO
	var knock: float = how.get("knock", 9.0)
	c.vel = away * clampf(knock * 0.9, 3.0, 18.0) + Vector3.UP * clampf(knock * 0.4, 2.5, 7.0)
	if away != Vector3.ZERO:
		c._axis = away.cross(Vector3.DOWN).normalized() # tumbles head over heels along the hit
	c._rate = clampf(knock * 0.6, 2.0, 9.0)
	var shape := Vector3.ONE
	match c.head:
		"point":
			c.vel.y = 2.0 # punched flat back
			c._rate *= 0.4
		"hammer", "pound", "spike", "splat":
			shape = Vector3(1.35, 0.35, 1.35) # flattened
			c.vel = away * clampf(knock * 0.3, 0.0, 5.0) + Vector3.UP * 1.5
			c._rate = 0.0
	if how.get("spin", false):
		c._axis = Vector3.UP
		c._rate = 20.0
	if how.get("fire", false):
		_char(vis)
	c._add_part(vis, shape, Vector3.ZERO)
	if c.head == "blade":
		# cut in two: each half keeps one side and they part
		var other := vis.duplicate() as Node3D
		c.add_child(other)
		other.transform = vis.transform
		var side := away.cross(Vector3.UP).normalized() if away != Vector3.ZERO else Vector3.RIGHT
		var half := Vector3(0.55, 1.0, 1.0)
		c._part_scale[0] = half
		c._part_vel[0] = side * 2.5 + Vector3.UP * 1.5
		var off := c.global_basis.inverse() * (side * 0.3)
		vis.position += off
		other.position -= off
		c._add_part(other, half, -side * 2.5 + Vector3.UP * 1.5)
	live.append(c)
	while live.size() > MAX:
		var old: Corpse = live.pop_front()
		if is_instance_valid(old):
			old._finish()
	return c

## Burnt: every material darkened (duplicated so the living don't share it).
static func _char(n: Node) -> void:
	for ch in n.get_children():
		if ch is MeshInstance3D:
			var mi := ch as MeshInstance3D
			if mi.material_override is StandardMaterial3D:
				var m := (mi.material_override as StandardMaterial3D).duplicate() as StandardMaterial3D
				m.albedo_color = m.albedo_color.darkened(0.75)
				mi.material_override = m
		_char(ch)

func _add_part(n: Node3D, shape: Vector3, v: Vector3) -> void:
	_parts.append(n)
	_part_scale.append(shape)
	_part_vel.append(v)
	n.scale = shape

func _physics_process(dt: float) -> void:
	t += dt
	if t >= LIFE:
		_finish()
		return
	_move(dt)
	var k := clampf((t - (LIFE - FADE)) / FADE, 0.0, 1.0)
	for i in _parts.size():
		var part := _parts[i]
		var v := _part_vel[i]
		part.global_position += v * dt
		_part_vel[i] = v.move_toward(Vector3.ZERO, 6.0 * dt)
		var mult := 1.0
		match style:
			"burst":
				mult = 1.0 + 0.5 * k * k
			"disintegrate":
				mult = 1.0 - k
			"dissolve":
				part.global_position.y -= 0.9 * k * dt
				_fade(part, k)
		part.scale = _part_scale[i] * maxf(mult, 0.01)
	if style == "burst" and k > 0.75 and not _popped:
		_popped = true
		for part in _parts:
			part.visible = false
		_puff(color, 26, 7.0, 0.4)
	if style == "disintegrate" and k > 0.0 and not _moted:
		_moted = true
		_puff(color.lightened(0.3), 18, 2.0, FADE, true)

func _move(dt: float) -> void:
	vel.y -= GRAVITY * dt
	var space := get_world_3d().direct_space_state
	var step := vel * dt
	var flat := Vector3(step.x, 0, step.z)
	if flat.length() > 0.0001:
		var q := PhysicsRayQueryParameters3D.create(global_position, global_position + flat + flat.normalized() * rest * 0.8, 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and not (hit.collider is CharacterBody3D):
			var n: Vector3 = hit.normal
			vel = (vel - 2.0 * vel.dot(n) * n) * 0.3 # a dull knock off the wall
			flat = Vector3.ZERO
	global_position += flat
	var down := PhysicsRayQueryParameters3D.create(global_position + Vector3.UP * 0.2, global_position + Vector3.DOWN * (rest + maxf(-step.y, 0.0)), 1)
	var floor_hit := space.intersect_ray(down)
	if not floor_hit.is_empty() and not (floor_hit.collider is CharacterBody3D) and vel.y <= 0.0:
		var fy: float = floor_hit.position.y
		global_position.y = fy + rest * (0.35 if head in ["hammer", "pound", "spike", "splat"] else 0.8)
		var landing := vel.y < -3.0
		vel.y = -vel.y * 0.3 if landing else 0.0
		var hv := Vector2(vel.x, vel.z).move_toward(Vector2.ZERO, 14.0 * dt) * (0.8 if landing else 1.0) # it skids
		vel.x = hv.x
		vel.z = hv.y
		_rate = move_toward(_rate, 0.0, 12.0 * dt)
	else:
		global_position.y += step.y
	if _rate > 0.05:
		rotate(_axis, _rate * dt)

func _fade(n: Node, k: float) -> void:
	for ch in n.get_children():
		if ch is GeometryInstance3D:
			(ch as GeometryInstance3D).transparency = k
		_fade(ch, k)

func _puff(c: Color, amount: int, speed: float, life: float, rise := false) -> void:
	var p := CPUParticles3D.new()
	p.one_shot = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.2 if rise else 1.0
	p.direction = Vector3.UP
	p.spread = 30.0 if rise else 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3.UP * 2.0 if rise else Vector3.DOWN * 14.0
	var m := SphereMesh.new()
	m.radius = 0.07 if rise else 0.12
	m.height = m.radius * 2.0
	var mat := StandardMaterial3D.new()
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mat.albedo_color = c
	m.material = mat
	p.mesh = m
	get_parent().add_child(p)
	p.global_position = global_position
	p.emitting = true
	get_tree().create_timer(life + 0.3, true, false, true).timeout.connect(p.queue_free)

## Gone: a last puff if it was cut short.
func _finish() -> void:
	live.erase(self)
	if t < LIFE and is_inside_tree():
		_puff(color, 10, 4.0, 0.3)
	queue_free()
