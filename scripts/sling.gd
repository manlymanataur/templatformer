class_name Sling
extends Node
## Lash & Sling (Combat Sketchbook I, jovi: "Great, and part of the Lash"). The lash at a monster stings it
## (1, a whip crack: it doesn't need to be strong) and leashes it on a lash_leash rope (a Tether: at full length
## you drag it, and it slides round corners like the spider). No new buttons:
## - Attack with a monster leashed: you swing it round you (sling_radius, sling_spin) for at least sling_time,
##   and it hits everything it sweeps through (sling_damage, knocked away hard: they splat on walls and bowl
##   into each other). It flies off the first moment it's heading where you aim (your lock-on target, or
##   where you faced), at sling_speed, and bowls or splats whatever it meets.
## - The lash again: you yank it to your feet at yank_speed, bowling over anything in the way, and let go.
## - A shield monster's shield is torn away for good by the lash. A brute (armoured, or plated) is too heavy:
##   the lash pulls you in to it instead, like a post.
## One Sling node runs a swing or a yank and frees itself (and the leash) when it's done.

var p: Player
var m: Monster
var mode := "swing"
var t := 0.0
var _a := 0.0 ## swing angle round you (radians, about +Y, measured from +X toward +Z)
var _r := 0.0
var _aim := Vector3.FORWARD
var _hit := {}
var swept := 0 ## monsters hit while it swung or was yanked (for tests)

static func heavy(mon: Monster) -> bool:
	return mon.armored or mon is PlatedBrute

## The lash hit a monster: sting it, tear a shield, and leash it (or, too heavy, pull you in). Returns true.
static func hook(pl: Player, mon: Monster) -> bool:
	var tt := pl.t
	var to := mon.global_position - pl.global_position
	var flat := Vector3(to.x, 0, to.z)
	if heavy(mon):
		mon.strike(1, pl.global_position, {"knock": 0.0})
		var dir := flat.normalized() if flat.length() > 0.01 else pl._flat_facing()
		pl.grapple_to = mon.global_position - dir * (mon._r + pl.radius() + 0.4)
		pl.grapple_to.y = pl.global_position.y
		pl.grapple_t = flat.length() / tt.lash_pull_speed + 0.3
		pl.jumping = false
		pl.air_lock = 0.2
		return true
	if mon.shield_hp > 0 and not (mon is IronKnight):
		mon.shield_hp = 0
		if mon._shield != null:
			mon._shield.visible = false # torn away for good
		Hitfx.sparks(pl.get_tree(), mon.global_position, 1.2)
	mon.strike(1, pl.global_position, {"knock": 2.0})
	if mon.hp <= 0 or not is_instance_valid(mon):
		return true
	pl.leash = Tether.make(pl.get_parent(), pl, mon, tt.lash_leash, Color(0.85, 0.7, 0.4))
	return true

## The leashed monster, if the leash holds one.
static func leashed(pl: Player) -> Monster:
	if pl.leash == null or not is_instance_valid(pl.leash) or not is_instance_valid(pl.leash.b):
		return null
	return pl.leash.b as Monster

static func busy(pl: Player) -> bool:
	for n in pl.get_tree().get_nodes_in_group("slings"):
		if (n as Sling).p == pl:
			return true
	return false

## Attack with a monster leashed: swing it. Returns true if a swing started (or one is going).
static func swing(pl: Player) -> bool:
	var mon := leashed(pl)
	if mon == null:
		return false
	if busy(pl):
		return true
	var s := _make(pl, mon, "swing")
	var off := mon.global_position - pl.global_position
	s._a = atan2(off.z, off.x)
	s._r = Vector2(off.x, off.z).length()
	s._aim = pl._flat_facing()
	if pl.target != null and is_instance_valid(pl.target) and pl.target != mon:
		var d := pl.target.global_position - pl.global_position
		d.y = 0.0
		if d.length() > 0.1:
			s._aim = d.normalized()
	return true

## The lash again with a monster leashed: yank it in. Returns true if it did.
static func yank(pl: Player) -> bool:
	var mon := leashed(pl)
	if mon == null:
		return false
	if not busy(pl):
		_make(pl, mon, "yank")
	return true

static func _make(pl: Player, mon: Monster, how: String) -> Sling:
	var s := Sling.new()
	s.p = pl
	s.m = mon
	s.mode = how
	pl.get_parent().add_child(s)
	return s

func _ready() -> void:
	add_to_group("slings")
	process_physics_priority = -10 # before the monster moves: it moves where the sling puts it this frame

func _physics_process(dt: float) -> void:
	if not is_instance_valid(p) or not is_instance_valid(m) or m.hp <= 0:
		_done()
		return
	t += dt
	var tt := p.t
	m.stun = maxf(m.stun, 0.25)
	m.state = "move"
	m.knocked_t = 0.0
	m.air = false
	var here := m.global_position
	if mode == "swing":
		var spin := tt.sling_spin
		_a += spin * dt
		_r = move_toward(_r, tt.sling_radius, 8.0 * dt)
		var want := p.global_position + Vector3(cos(_a), 0, sin(_a)) * _r
		m.velocity = Vector3(want.x - here.x, 0, want.z - here.z) / maxf(dt, 0.001)
		_sweep(tt, Vector3(-sin(_a), 0, cos(_a)))
		var tangent := Vector3(-sin(_a), 0, cos(_a))
		var late := t >= tt.sling_time + TAU / maxf(spin, 0.1)
		if (t >= tt.sling_time and tangent.dot(_aim) >= 0.96) or late:
			m.velocity = tangent * tt.sling_speed + Vector3.UP * 3.0
			m.knocked_t = 0.8
			m.stun = maxf(m.stun, 1.0)
			Hitfx.shake(get_tree(), 0.1)
			_done()
	else:
		var to := p.global_position - here
		to.y = 0.0
		var gap := to.length() - m._r - p.radius()
		if gap <= 0.6 or t > 1.2:
			m.velocity = Vector3.ZERO
			m.stun = maxf(m.stun, 0.8)
			_done()
			return
		var dir := to.normalized()
		m.velocity = dir * minf(tt.yank_speed, (gap - 0.5) / maxf(dt, 0.001) + 1.0)
		_sweep(tt, dir)

## Everything the swung (or yanked) monster touches is knocked away from you, once each.
func _sweep(tt: Tuning, moving: Vector3) -> void:
	for n in get_tree().get_nodes_in_group("monsters"):
		var o := n as Monster
		if o == null or o == m or _hit.has(o) or o.hp <= 0:
			continue
		if o.global_position.distance_to(m.global_position) > o._r + m._r + 0.3:
			continue
		_hit[o] = true
		swept += 1
		var away := o.global_position - p.global_position
		away.y = 0.0
		var push := (away.normalized() + moving * 0.5).normalized()
		o.strike(int(tt.sling_damage), o.global_position - push, {"knock": 11.0, "stagger": true})
		Hitfx.hit(get_tree(), o.global_position, tt, 0.8)

func _done() -> void:
	if is_instance_valid(p) and p.leash != null and is_instance_valid(p.leash) and p.leash.b == m:
		p.leash.queue_free()
		p.leash = null
	queue_free()
