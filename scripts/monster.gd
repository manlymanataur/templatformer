class_name Monster
extends CharacterBody3D
## Enemies. One body, several kinds (AI variants), all lock-on targets and hurtable:
##   blob    chases you, winds up (it flashes) and lunges. Touching it hurts too.
##   wolf    circles you at bite range and bites from outside your front, or anyway after WOLF_PATIENCE.
##   rusher  telegraphs, then charges in a straight line at RUSH_SPEED. Heavy: a block pushes you far, a wall
##           behind you breaks your guard, and a brace impales it. Charging into a wall dazes it.
##   archer  keeps its distance and shoots arrows. A perfect guard sends them back.
##   shield  a blob with a shield in front: the point glances off it, the blade cracks it, the hammer or a
##           shield bash smashes it.
##   brute   armoured: only the hammer, or the opening a perfect guard makes, staggers it. Its swing is heavy.
## Any kind can be spiked (spikes on its head): a ground pound or homing attack onto it hurts you, and only a
## shield surf onto it pogos you off.
## Hits from the poleaxe go through strike(), which knows the move: sweet spots, counters (hit in its windup),
## whiff punishes (hit while it recovers from a miss), launches and juggles, spikes, splats and bowling.
## Liquids: honey draws blobs and wolves and holds them (bigger kinds are slowed), wine draws brutes and rushers
## and makes anything drunk (it wanders, and stops avoiding ledges), heat hardens honey into rock candy.

const AGGRO := 9.0
const SPEED := 3.2
const TOUCH := 1.1
const GRAVITY := 30.0
const AIR_GRAVITY := 20.0 ## launched: it hangs a little longer so you can follow it up
const LAUNCH_UP := 10.0 ## a launcher throws it about 2.5 m up
const JUGGLE_LIFT := 8.0 ## each air hit lifts it less: 8, 6, 4, then only a spike (hammer or pound) works
const JUGGLE_MAX := 3
const SPIKE_SPEED := 26.0
const KNOCK_HEAVY := 9.0 ## knockback this strong sends it sliding (low friction): splats and bowling
const SPLAT_SPEED := 4.0
const WOLF_PATIENCE := 2.5
const WOLF_RING := 3.2
const RUSH_SPEED := 14.0
const ARROW_SPEED := 16.0

var kind := "blob"
var spiked := false
var max_hp := 3
var hp := 3
var stun := 0.0
var home := Vector3.ZERO
var drop_heart := true
var state := "move" ## move, windup, attack, recover
var state_t := 0.0
var whiffed := false ## its last attack missed: hits during the recovery punish it (+1)
var air := false ## launched and juggled
var juggle := 0
var slammed := false ## spiked down: its landing bursts on those around it
var knocked_t := 0.0 ## sliding from a heavy hit
var open_t := 0.0 ## a perfect guard opened it up: hits do double
var shield_hp := 0 ## shield kind: blade hits crack it (2), the hammer or a bash smashes it
var armored := false
var _t := 0.0
var _air_t := 0.0
var _wait := 0.0
var _charge_dir := Vector3.ZERO
var _hit_you := false
var _base := Color(0.35, 0.75, 0.3)
var _mat: StandardMaterial3D
var _shield: MeshInstance3D
var _r := 0.55

static func spawn(parent: Node, pos: Vector3, kind_ := "blob", spiked_ := false) -> Monster:
	var m := Monster.new()
	m.kind = kind_
	m.spiked = spiked_
	m.position = pos # placed before it enters the tree, so the physics never sees it jump from the origin
	parent.add_child(m)
	m.global_position = pos
	m.home = pos
	return m

func _ready() -> void:
	add_to_group("monsters")
	add_to_group("targets")
	add_to_group("hurtable")
	var size := Vector3(1.2, 0.9, 1.2)
	match kind:
		"wolf":
			max_hp = 3
			_base = Color(0.55, 0.55, 0.6)
			size = Vector3(0.8, 0.8, 1.4)
		"rusher":
			max_hp = 4
			_base = Color(0.8, 0.35, 0.25)
			size = Vector3(1.3, 1.1, 1.4)
		"archer":
			max_hp = 2
			_base = Color(0.6, 0.4, 0.8)
			size = Vector3(0.8, 1.4, 0.8)
		"shield":
			max_hp = 4
			shield_hp = 2
			_base = Color(0.3, 0.6, 0.55)
		"brute":
			max_hp = 8
			armored = true
			_base = Color(0.35, 0.3, 0.3)
			size = Vector3(1.7, 1.5, 1.7)
			_r = 0.8
	hp = max_hp
	var c := CollisionShape3D.new()
	var s := SphereShape3D.new()
	s.radius = _r
	c.shape = s
	add_child(c)
	var body := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = size.x / 2.0
	sm.height = size.y
	body.mesh = sm
	body.scale = Vector3(1, 1, size.z / size.x)
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = _base
	body.material_override = _mat
	add_child(body)
	for side in [-0.2, 0.2]:
		var eye := MeshInstance3D.new()
		var em := SphereMesh.new()
		em.radius = 0.09
		em.height = 0.18
		eye.mesh = em
		var emat := StandardMaterial3D.new()
		emat.albedo_color = Color(0.05, 0.05, 0.05)
		eye.material_override = emat
		eye.position = Vector3(side, 0.15, -size.z / 2.0 + 0.1)
		add_child(eye)
	if kind == "shield":
		_shield = MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(1.1, 1.0, 0.12)
		_shield.mesh = bm
		var shm := StandardMaterial3D.new()
		shm.albedo_color = Color(0.7, 0.6, 0.35)
		shm.metallic = 0.6
		_shield.material_override = shm
		_shield.position = Vector3(0, 0.05, -0.75)
		add_child(_shield)
	if armored:
		var plate := MeshInstance3D.new()
		var pm := BoxMesh.new()
		pm.size = Vector3(1.3, 0.35, 1.3)
		plate.mesh = pm
		var am := StandardMaterial3D.new()
		am.albedo_color = Color(0.5, 0.5, 0.55)
		am.metallic = 0.8
		plate.material_override = am
		plate.position.y = 0.45
		add_child(plate)
	if spiked:
		var tip := StandardMaterial3D.new()
		tip.albedo_color = Color(0.9, 0.25, 0.2)
		tip.metallic = 0.5
		for k in 5:
			var spike := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.0
			cm.bottom_radius = 0.12
			cm.height = 0.45
			spike.mesh = cm
			spike.material_override = tip
			var a := TAU * k / 5.0
			var lean := 0.0 if k == 0 else 0.5
			spike.position = Vector3(cos(a) * 0.25 * signf(lean), size.y / 2.0 + 0.1, sin(a) * 0.25 * signf(lean))
			spike.rotation = Vector3(sin(a) * lean, 0, -cos(a) * lean)
			add_child(spike)

func _player() -> Player:
	var ps := get_tree().get_nodes_in_group("player")
	return ps[0] as Player if ps.size() > 0 else null

func _fwd() -> Vector3:
	var f := -global_basis.z
	f.y = 0.0
	return f.normalized() if f.length() > 0.01 else Vector3.FORWARD

func _face(dir: Vector3) -> void:
	var d := Vector3(dir.x, 0, dir.z)
	if d.length() > 0.05:
		look_at(global_position + d, Vector3.UP)

func _physics_process(dt: float) -> void:
	var world := Hitfx.world
	dt *= world # a perfect dodge slows monsters down
	if Liquids.frozen_step(self, dt): # rock candy (and liquids under it: see Liquids)
		return
	_t += dt
	knocked_t -= dt
	open_t -= dt
	var g := GRAVITY
	if air:
		_air_t += dt
		g = AIR_GRAVITY * (1.0 + 0.6 * juggle)
	velocity.y -= g * dt
	var p := _player()
	if stun > 0.0 or air:
		stun -= dt
		var fr := 2.0 if knocked_t > 0.0 else 12.0
		var hv := Vector3(velocity.x, 0, velocity.z).move_toward(Vector3.ZERO, fr * dt)
		velocity.x = hv.x
		velocity.z = hv.z
		_mat.albedo_color = Color(1, 0.3, 0.3) if stun > 0.3 else _base
		if open_t > 0.0:
			_mat.albedo_color = Color(1.0, 0.85, 0.3)
	elif not Liquids.monster_think(self, dt, p): # drunk, or drawn to honey or wine
		_think(dt, p)
	Liquids.monster_after(self) # honey holds it; sober, it won't walk off a ledge
	var before := velocity
	velocity *= world
	move_and_slide()
	velocity /= world
	_after_move(before)
	if air and _air_t > 0.1 and is_on_floor():
		_land()
	if global_position.y < -30.0:
		queue_free()

## What it does when it isn't stunned or in the air.
func _think(dt: float, p: Player) -> void:
	var to := Vector3.ZERO
	if p != null:
		to = p.global_position - global_position
	var flat := Vector3(to.x, 0, to.z)
	var dist := flat.length()
	var near := p != null and dist < (14.0 if kind in ["archer", "rusher"] else AGGRO)
	state_t -= dt
	var dir := Vector3.ZERO
	var speed := SPEED
	match state:
		"move":
			_mat.albedo_color = _base
			if not near:
				var goal := home + Vector3(cos(_t * 0.5), 0, sin(_t * 0.5)) * 2.5
				var gd := goal - global_position
				gd.y = 0
				if gd.length() > 0.3:
					dir = gd.normalized() * 0.5
			else:
				dir = flat.normalized()
				match kind:
					"blob", "shield":
						speed = SPEED * (0.8 if kind == "shield" else 1.0)
						if dist < 2.4:
							_begin("windup", 0.45)
					"wolf":
						speed = 6.0
						if dist < WOLF_RING + 1.5:
							# circle at bite range, waiting for a gap in your guard
							var side := flat.normalized().cross(Vector3.UP)
							var ring := (dist - WOLF_RING) * 1.5
							dir = (side * 1.0 + flat.normalized() * ring).normalized()
							speed = 4.0
							_wait += dt
							var front := p._flat_facing().dot(-flat.normalized()) # 1 = right in front of you
							if front < 0.35 or _wait > WOLF_PATIENCE:
								_begin("windup", 0.35)
					"rusher":
						if dist < 12.0:
							_begin("windup", 0.7)
					"archer":
						speed = 3.0
						if dist < 7.0:
							dir = -flat.normalized()
						elif dist < 12.0:
							dir = Vector3.ZERO
							_begin("windup", 0.9)
					"brute":
						speed = 2.2
						if dist < 2.6:
							_begin("windup", 0.8)
			velocity.x = dir.x * speed
			velocity.z = dir.z * speed
			if near:
				_face(flat)
			elif dir.length() > 0.1:
				_face(dir)
		"windup":
			velocity.x = 0.0
			velocity.z = 0.0
			if kind != "rusher" or state_t > 0.25:
				_face(flat) # a rusher's aim sets just before it goes
			_mat.albedo_color = _base.lerp(Color(1, 1, 0.5), 0.5 + 0.5 * sin(_t * 40.0))
			if state_t <= 0.0:
				_strike_out(p, flat)
		"attack":
			_mat.albedo_color = _base.lerp(Color.WHITE, 0.4)
			if kind == "rusher" and _hit_wall():
				# crashed: dazed, wide open
				Hitfx.shake(get_tree(), 0.15)
				stun = 1.5
				state = "recover"
				state_t = 1.5
				whiffed = true
				velocity = -_charge_dir * 3.0 + Vector3.UP * 3.0
				return
			if state_t <= 0.0:
				_begin("recover", 0.9 if kind == "rusher" else 0.6)
				whiffed = not _hit_you
		"recover":
			velocity.x = move_toward(velocity.x, 0.0, 20.0 * dt)
			velocity.z = move_toward(velocity.z, 0.0, 20.0 * dt)
			_mat.albedo_color = _base.darkened(0.25)
			if state_t <= 0.0:
				state = "move"
				whiffed = false
	# touching you hurts (a lunge or charge hits harder when it's the heavy kind)
	if p != null and dist < TOUCH + (_r - 0.55) and absf(to.y) < 1.2 and p.invuln <= 0.0 and not _hit_you:
		var heavy := kind == "rusher" and state == "attack"
		p.hurt(2 if heavy else 1, global_position, self, heavy)
		if state == "attack":
			_hit_you = true
		if stun <= 0.0: # (a brace may have just impaled it)
			stun = 0.6 # recoil after landing a hit so it doesn't grind against you
			velocity = -flat.normalized() * 5.0 + Vector3.UP * 2.0
			state = "move"

## Ran into something that isn't you or another monster.
func _hit_wall() -> bool:
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		if not (c.get_collider() is Player or c.get_collider() is Monster) and absf(c.get_normal().y) < 0.5:
			return true
	return false

func _begin(s: String, secs: float) -> void:
	state = s
	state_t = secs
	_wait = 0.0

## The windup is over: the attack itself.
func _strike_out(p: Player, flat: Vector3) -> void:
	_hit_you = false
	var d := flat.normalized() if flat.length() > 0.01 else _fwd()
	match kind:
		"blob", "shield":
			velocity = d * 9.0 + Vector3.UP * 2.0
			_begin("attack", 0.25)
		"wolf":
			velocity = d * 11.0 + Vector3.UP * 2.5
			_begin("attack", 0.25)
		"rusher":
			_charge_dir = _fwd()
			velocity = _charge_dir * RUSH_SPEED
			_begin("attack", 1.2)
		"archer":
			if p != null:
				var from := global_position + Vector3.UP * 0.4
				var aim := (p.global_position - from).normalized()
				Arrow.shoot(get_parent(), from + aim * 0.8, aim * ARROW_SPEED, self)
			_begin("recover", 1.0)
		"brute":
			# a heavy swing in front
			if p != null and flat.length() < 3.0 and _fwd().dot(d) > 0.3 and p.invuln <= 0.0:
				p.hurt(2, global_position, self, true)
				_hit_you = true
			Hitfx.shake(get_tree(), 0.12)
			_begin("recover", 0.9)
			whiffed = not _hit_you

func _after_move(before: Vector3) -> void:
	if kind == "rusher" and state == "attack" and stun <= 0.0:
		velocity.x = _charge_dir.x * RUSH_SPEED
		velocity.z = _charge_dir.z * RUSH_SPEED
	if knocked_t <= 0.0:
		return
	var sp := Vector2(before.x, before.z).length()
	if sp < SPLAT_SPEED:
		return
	for i in get_slide_collision_count():
		var c := get_slide_collision(i)
		var o := c.get_collider()
		if o is Monster and o != self:
			# bowling: it knocks into the next one
			knocked_t = 0.0
			var hv := Vector3(before.x, 0, before.z)
			(o as Monster).strike(1, global_position - hv.normalized(), {"knock": sp * 0.8})
			Hitfx.sparks(get_tree(), c.get_position(), 1.0)
			return
		if absf(c.get_normal().y) < 0.5:
			# splat against a wall or pillar
			knocked_t = 0.0
			velocity = c.get_normal() * 2.0
			stun = maxf(stun, 1.0)
			_take(1)
			Hitfx.hit(get_tree(), c.get_position(), _tuning(), 1.2)
			return

func _land() -> void:
	air = false
	juggle = 0
	_air_t = 0.0
	if slammed:
		slammed = false
		Hitfx.shake(get_tree(), 0.2)
		Hitfx.sparks(get_tree(), global_position, 1.5)
		for n in get_tree().get_nodes_in_group("monsters"):
			var m := n as Monster
			if m != self and m.global_position.distance_to(global_position) < 3.0:
				m.strike(1, global_position, {"knock": 7.0})
		_take(1)
		stun = maxf(stun, 0.8)

func _tuning() -> Tuning:
	var p := _player()
	return p.t if p != null else Tuning.new()

## A perfect guard: it reels, open to hits (double damage) for a moment.
func parried() -> void:
	stun = maxf(stun, 1.2)
	open_t = 1.2
	state = "recover"
	state_t = 1.2
	velocity = -_fwd() * 3.0

## Anything but the poleaxe (bombs, the lash, Umbra's sword, a pound's shockwave).
func hurt(amount: int, from: Vector3) -> void:
	strike(amount, from, {})

## A hit. info (all optional): head ("point", "blade", "hammer", "shield", "pound"), knock (knockback speed),
## launch (throws it up), air (you hit it while you're in the air: a juggle), spike (slams it down if it's
## airborne), stagger, above (from on top: shields don't cover it). Returns the damage it took.
func strike(amount: int, from: Vector3, info: Dictionary) -> int:
	if hp <= 0:
		return 0
	var away := global_position - from
	away.y = 0
	away = away.normalized() if away.length() > 0.01 else -_fwd()
	var head: String = info.get("head", "")
	var from_front := _fwd().dot(-away) > 0.3
	if shield_hp > 0 and from_front and open_t <= 0.0 and not info.get("above", false) and head != "":
		match head:
			"hammer", "shield":
				shield_hp = 0
				_shield.visible = false
				Hitfx.sparks(get_tree(), global_position, 1.5)
				if head == "shield":
					stun = maxf(stun, 1.0)
					open_t = 1.0 # bashed open: follow up
					velocity = away * 4.0 + Vector3.UP * 2.0
					return 0
			"blade":
				shield_hp -= 1
				if shield_hp <= 0:
					_shield.visible = false
				velocity = away * 3.0
				Hitfx.sparks(get_tree(), global_position - away * 0.7, 0.8)
				return 0
			_:
				velocity = away * 2.0
				Hitfx.sparks(get_tree(), global_position - away * 0.7, 0.6) # the point glances off
				return 0
	var dmg := amount + Umbra.pincer(self, info) # you and Umbra together: a pincer
	var stagger: bool = info.get("stagger", false) or open_t > 0.0 or head == "hammer"
	if state == "windup":
		dmg = ceili(dmg * 1.5) # counter: hit it as it winds up and the attack never comes
	elif state == "recover" and whiffed:
		dmg += 1 # punish a miss
	if open_t > 0.0:
		dmg *= 2
		open_t = 0.0
	_take(dmg)
	if hp <= 0:
		return dmg
	if armored and not stagger:
		return dmg # it shrugs off anything lighter than the hammer
	state = "move"
	_hit_you = false
	var knock: float = info.get("knock", 9.0)
	if air or info.get("launch", false):
		if air and info.get("spike", false):
			velocity = Vector3(away.x, 0, away.z) * 2.0 + Vector3.DOWN * SPIKE_SPEED
			slammed = true
			return dmg
		if not air:
			# launched: up it goes, nearly straight, for you to follow
			air = true
			juggle = 0
			_air_t = 0.0
			velocity = away * 1.5 + Vector3.UP * LAUNCH_UP
			global_position.y += 0.05
			stun = maxf(stun, 0.2)
			return dmg
		if info.get("air", false):
			juggle += 1
			if juggle <= JUGGLE_MAX:
				velocity = away * 1.0 + Vector3.UP * JUGGLE_LIFT * (1.0 - 0.25 * (juggle - 1))
			return dmg
		velocity.x = away.x * 3.0
		velocity.z = away.z * 3.0
		return dmg
	stun = maxf(stun, 1.2 if stagger else 0.5)
	velocity = away * knock + Vector3.UP * (4.0 if knock >= KNOCK_HEAVY else 3.0)
	if knock >= KNOCK_HEAVY:
		knocked_t = 0.6
	return dmg

func _take(dmg: int) -> void:
	hp -= dmg
	_mat.albedo_color = Color(1, 0.3, 0.3)
	if hp <= 0:
		_die()

func _die() -> void:
	if drop_heart:
		Pickup.spawn(get_parent(), "heart", 1, global_position + Vector3.UP * 0.5)
	queue_free()
