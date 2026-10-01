class_name Liquids
extends RefCounted
## Honey & Wine: the rules for water, wine and honey, and the swap charm. Pots carry them (Pot), spouts and
## pools give them (Spout, Puddle.pool), and a pot that breaks spills its liquid (spill).
## - Liquid only goes where the level plans for it (spill): a fixed-size puddle on the ground where it lands,
##   down a Runnel to its low end, or filling a Basin to the brim from one pot. Honey that hits a thing sticks.
## - Water washes honey, rock candy and wine away, puts out fire (burning grass and vines, burning wine,
##   burning crates, braziers, the candle hat of whoever it splashes) and leaves the ground wet for wet_time.
##   Wet ground won't take wine or fire. Wading into deep water or a water pool also puts the candle out.
## - Wine washes honey off, makes whatever steps in it drunk (the player's steering sways for drunk_time,
##   monsters wander for drunk_monster_time and stop avoiding edges) and burns (see Puddle).
## - Honey: big things (the player at normal size, rushers, shields, brutes, archers) are slowed to honey_slow;
##   small things (the player when small, blobs, wolves, the spider, Umbra) are stuck. Things standing in it
##   for honey_cover get coated, and heat hardens a coat into rock candy (Coat).
## - Honey draws blobs and wolves, wine draws brutes and rushers, from lure_range. Sober monsters don't walk off
##   ledges; drunk ones do.
## - The swap charm trades places with rock candy you can see: your lock-on target, or else the nearest piece in
##   front of you within swap_range. Each of you keeps your own velocity.

const SPLASH := 1.6 ## a breaking pot splashes everything this close
const RADIUS := {"water": 1.8, "wine": 1.8, "honey": 1.2} ## a puddle's size (fixed)
const MONSTER_HONEY_SPEED := 1.2
const DRUNK_SPEED := 2.5
const SMALL_KINDS := ["blob", "wolf"]
const HONEY_LURES := ["blob", "wolf"]
const WINE_LURES := ["brute", "rusher"]

static var _fallback: Tuning
static var _wading := false

static func tuning(tree: SceneTree) -> Tuning:
	if tree != null:
		var ps := tree.get_nodes_in_group("player")
		if not ps.is_empty():
			return (ps[0] as Player).t
	if _fallback == null:
		_fallback = Tuning.new()
	return _fallback

## How far a body's centre sits above its feet.
static func bottom(b: Node) -> float:
	if b is Player:
		return (b as Player).radius()
	if b is Monster:
		return (b as Monster)._r
	if b is Crate:
		return Crate.HALF
	if b is Pot:
		return Pot.R
	if b is Seed:
		return Seed.HALF
	if b is Spider:
		return Spider.RADIUS
	if b is Umbra:
		return 0.4
	return 0.5

## Small things are stuck in honey; big things are only slowed.
static func small(b: Node) -> bool:
	if b is Player:
		return (b as Player).small
	if b is Monster:
		return (b as Monster).kind in SMALL_KINDS
	return b is Spider or b is Umbra

## Everything liquids act on: you, monsters, the spider, Umbra.
static func bodies(tree: SceneTree) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for g in ["player", "monsters", "spiders"]:
		for n in tree.get_nodes_in_group(g):
			out.append(n as Node3D)
	for n in tree.get_nodes_in_group("player"):
		var u: Umbra = (n as Player).umbra
		if u != null and is_instance_valid(u):
			out.append(u)
	return out

## The liquid under a body's feet: "honey", "wine", "water" or "". Honey wins, then wine.
## Also notes whether it's deep enough to wade in (a pool or deep water), for the candle.
static func under(b: Node3D) -> String:
	var feet := b.global_position - Vector3.UP * bottom(b)
	var found := ""
	_wading = false
	for n in b.get_tree().get_nodes_in_group("puddles"):
		var pd := n as Puddle
		if pd.is_queued_for_deletion() or not pd.covers(feet):
			continue
		if pd.kind == "water" and pd.permanent:
			_wading = true
		var k := pd.kind
		if k == "wine" and pd.wet > 0.0:
			k = "water" # doused wine is watered down: it no longer makes you drunk
		if k == "honey" or (k == "wine" and found != "honey") or found == "":
			found = k
	for n in b.get_tree().get_nodes_in_group("water"):
		if (n as Water).holds(b.global_position):
			_wading = true
			if found == "":
				found = "water"
	return found

## Liquid to fill a pot held at `at`: a spout overhead, or a pool or deep water you're wading in.
static func source_at(tree: SceneTree, at: Vector3) -> String:
	for n in tree.get_nodes_in_group("spouts"):
		if (n as Spout).fills(at):
			return (n as Spout).kind
	for n in tree.get_nodes_in_group("puddles"):
		var pd := n as Puddle
		if pd.permanent and pd.is_pool() and not pd.burning:
			var bx := pd.box
			if at.x > bx.position.x and at.x < bx.end.x and at.z > bx.position.z and at.z < bx.end.z and at.y < bx.end.y + 2.4 and at.y > bx.position.y - 1.0:
				return pd.kind
	for n in tree.get_nodes_in_group("water"):
		var bx := (n as Water).box
		if at.x > bx.position.x and at.x < bx.end.x and at.z > bx.position.z and at.z < bx.end.z and at.y < bx.end.y + 2.4 and at.y > bx.position.y:
			return "water"
	return ""

## Is the ground at `at` wet (a water puddle within r of it)?
static func wet_at(tree: SceneTree, at: Vector3, r: float, skip: Node = null) -> bool:
	for n in tree.get_nodes_in_group("puddles"):
		var pd := n as Puddle
		if pd == skip or pd.is_queued_for_deletion():
			continue
		if (pd.kind == "water" and pd.touches(at, r)) or (pd.kind == "wine" and pd.permanent and pd.wet > 0.0 and pd.touches(at, r)):
			return true
	return false

## A lit brazier within heat_reach of this node (measured flat, from the brazier's axis).
static func near_brazier(n: Node3D, t: Tuning) -> bool:
	var r := 0.0
	if n is Puddle:
		var pd := n as Puddle
		r = maxf(pd.box.size.x, pd.box.size.z) / 2.0 if pd.is_pool() else pd.radius
	for b in n.get_tree().get_nodes_in_group("flammable"):
		if b is Brazier and (b as Brazier).lit:
			var d := (b as Node3D).global_position - n.global_position
			if Vector2(d.x, d.z).length() <= t.heat_reach + r and absf(d.y) < 3.0:
				return true
	return false

## Heat on a honey-coated body: a lit brazier close by, or the lit candle hat within candle_heat.
static func near_fire(b: Node3D, t: Tuning) -> bool:
	if near_brazier(b, t):
		return true
	for n in b.get_tree().get_nodes_in_group("player"):
		var p := n as Player
		if p != b and p.candle_lit and p.global_position.distance_to(b.global_position) <= t.candle_heat:
			return true
	return false

# ---------- spilling ----------

## A pot broke at `at` (hit: what it broke on, if anything). It splashes what's close, then the liquid does
## one of three things, all planned by the level, never a simulation:
## 1. lands in a basin (Basin): one pot fills it to the brim;
## 2. lands on a runnel (Runnel): it runs down to the low end and lands there (on a basin, or a puddle);
## 3. lands anywhere else: a puddle of fixed size (RADIUS) lies on the ground where it fell.
## Honey that hits a monster, the spider or Umbra sticks to it instead.
static func spill(world: Node, kind: String, at: Vector3, hit: Node = null) -> void:
	if kind == "":
		return
	var tree := world.get_tree()
	splash(tree, kind, at, SPLASH)
	if kind == "honey" and hit != null and hit != world and _coatable(hit):
		Coat.of(hit).coat_honey() # honey sticks to what it hits
		return
	land(world, kind, at, 2)

## Liquid comes down at `at`: into a basin, down a runnel, or into a puddle on the ground below.
static func land(world: Node, kind: String, at: Vector3, runs_left := 2) -> void:
	var tree := world.get_tree()
	for n in tree.get_nodes_in_group("basins"):
		var b := n as Basin
		if b.catches(at):
			b.fill(kind)
			return
	var g := ground(world as Node3D, at + Vector3.UP * 0.4, 8.0)
	if g.is_empty():
		return
	var pos: Vector3 = g["position"]
	for n in tree.get_nodes_in_group("basins"):
		var b := n as Basin
		if b.catches(pos):
			b.fill(kind)
			return
	if g["collider"] is Runnel and runs_left > 0:
		var r := g["collider"] as Runnel
		for p in r.course():
			splash(tree, kind, p, r.width)
		land(world, kind, r.pour(kind) + Vector3.UP * 0.5, runs_left - 1)
		return
	if (g["normal"] as Vector3).y < 0.6:
		return # too steep to hold a puddle
	place(world, kind, pos, RADIUS[kind])

static func _coatable(n: Node) -> bool:
	return n is Monster or n is Spider or n is Umbra

## The ground under `from` (layer 1, looking past bodies that move): {position, normal, collider}, or empty.
static func ground(world: Node3D, from: Vector3, depth: float) -> Dictionary:
	var space := world.get_world_3d().direct_space_state
	var ex: Array[RID] = []
	for i in 6:
		var q := PhysicsRayQueryParameters3D.create(from, from + Vector3.DOWN * depth, 1, ex)
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			return {}
		var c: Object = hit["collider"]
		if c is CharacterBody3D and not c is Crate:
			ex.append((c as CollisionObject3D).get_rid())
			continue
		return hit
	return {}

## Leave a puddle of kind at pos (fixed size), or freshen one already there. What it lands on changes it.
static func place(world: Node, kind: String, pos: Vector3, r: float) -> void:
	var tree := world.get_tree()
	if kind == "wine" and wet_at(tree, pos, r * 0.5):
		return # wet ground won't take wine
	for n in tree.get_nodes_in_group("puddles"):
		var pd := n as Puddle
		if pd.is_queued_for_deletion() or not pd.touches(pos, r * 0.8):
			continue
		if pd.permanent:
			if kind == "water":
				pd.douse()
			continue
		if pd.kind == kind and pd.touches(pos, 0.0):
			pd.refresh()
			if kind == "water":
				splash(tree, kind, pos, pd.radius)
			return
		if kind == "water" and pd.kind != "water":
			pd.douse() # water washes wine and honey away
		elif kind != "water" and pd.kind != "water" and pd.kind != kind:
			pd.queue_free() # wine takes honey's place and honey takes wine's
	Puddle.make(world, kind, pos, r)
	if kind != "honey":
		splash(tree, kind, pos, r)

## Everything within r of `at` gets the liquid on it.
static func splash(tree: SceneTree, kind: String, at: Vector3, r: float) -> void:
	var t := tuning(tree)
	for b in bodies(tree):
		var feet := b.global_position - Vector3.UP * bottom(b)
		var d := b.global_position - at
		if Vector2(d.x, d.z).length() > r + bottom(b) or feet.y > at.y + 1.5 or b.global_position.y < at.y - 1.5:
			continue
		douse_body(b, kind, t)
	if kind != "water":
		return
	for n in tree.get_nodes_in_group("flammable"):
		if n is Coat or n is Puddle:
			continue
		var box: AABB = n.heat_box()
		var c := at.clamp(box.position, box.end)
		if Vector2(c.x - at.x, c.z - at.z).length() > r or absf(c.y - at.y) > 2.5:
			continue
		if n.has_method("douse"):
			n.douse()
		elif n is Brazier:
			(n as Brazier).put_out()
	for n in tree.get_nodes_in_group("crates"):
		var cr := n as Crate
		if cr.global_position.distance_to(at) < r + Crate.HALF:
			cr.douse()
	for n in tree.get_nodes_in_group("puddles"):
		var pd := n as Puddle
		if pd.kind == "wine" and pd.touches(at, r * 0.8):
			pd.douse()

## What a splash of kind does to one body.
static func douse_body(b: Node, kind: String, t: Tuning) -> void:
	if kind == "honey":
		if _coatable(b):
			Coat.of(b).coat_honey()
		return
	var c := Coat.on(b)
	if c != null:
		c.wash()
	if kind == "wine" and b is Monster:
		Coat.of(b).make_drunk(t.drunk_monster_time)
	if kind == "water" and b is Player and (b as Player).candle_lit:
		(b as Player).set_candle(false)

# ---------- standing in it: hooks the bodies call each frame ----------

## Work out what this body stands in and let it act. Call once a frame.
static func soak(b: Node3D, dt: float) -> String:
	var k := under(b)
	var c := Coat.on(b)
	if k == "":
		if c != null:
			c.in_honey = false
			c.honey_t = 0.0
		return ""
	var t := tuning(b.get_tree())
	c = Coat.of(b)
	c.in_honey = k == "honey"
	if k == "honey":
		if not c.candy:
			c.honey_t += dt
			if c.honey_t >= t.honey_cover:
				c.coat_honey()
		return k
	c.honey_t = 0.0
	c.wash()
	if k == "wine":
		c.make_drunk(t.drunk_time if b is Player else t.drunk_monster_time)
	elif b is Player and _wading and (b as Player).candle_lit:
		(b as Player).set_candle(false) # waded in: the candle's out
	return k

## Rock candy: no will of its own, it only falls. Returns true (and has moved it) when it's candy.
## Every coatable body calls this first thing each physics frame; it also soaks the body.
static func frozen_step(b: CharacterBody3D, dt: float) -> bool:
	soak(b, dt)
	var c := Coat.on(b)
	if c == null or not c.candy:
		return false
	b.velocity.y -= tuning(b.get_tree()).gravity * dt
	if b.is_on_floor():
		b.velocity.x = 0.0
		b.velocity.z = 0.0
	b.move_and_slide()
	if b.global_position.y < -30.0:
		if b is Umbra:
			(b as Umbra).fade()
		elif b is Spider:
			(b as Spider).player.stow_spider()
		else:
			b.queue_free()
	return true

## Honey under the spider or Umbra holds it fast. Call just before it moves.
static func creature_after(b: CharacterBody3D) -> void:
	var c := Coat.on(b)
	if c != null and c.in_honey:
		b.velocity.x = 0.0
		b.velocity.z = 0.0

## Wine sways your steering; also soaks you. Returns the wish to use.
static func player_wish(p: Player, wish: Vector3, dt: float) -> Vector3:
	soak(p, dt)
	for n in p.get_tree().get_nodes_in_group("spouts"):
		var s := n as Spout
		if s.kind == "water" and p.candle_lit and s.fills(p.global_position + Vector3.UP * 0.5):
			p.set_candle(false) # standing under the pipe
	var c := Coat.on(p)
	if c == null or c.drunk <= 0.0 or wish.length() < 0.05:
		return wish
	var k := c.drunk # its own clock, so the sway is the same every run
	var a := p.t.drunk_sway * (sin(k * 2.1) + 0.55 * sin(k * 5.3))
	return wish.rotated(Vector3.UP, a)

## Honey drags at you: normal size you're held to honey_slow and jump low; small you're stuck.
static func player_drag(p: Player) -> void:
	var c := Coat.on(p)
	if c == null or not c.in_honey:
		return
	var hv := Vector2(p.velocity.x, p.velocity.z)
	var cap := 0.0 if p.small else p.t.honey_slow
	if hv.length() > cap:
		hv = hv.normalized() * cap if cap > 0.0 else Vector2.ZERO
		p.velocity.x = hv.x
		p.velocity.z = hv.y
	var up := 0.0 if p.small else p.t.jump_speed * p.t.honey_jump
	if p.velocity.y > up and p.air_lock <= 0.0:
		p.velocity.y = up

## A monster's own plans when liquids are about: drunk, it staggers about; otherwise honey or wine draws
## it. A monster with a "leash" meta stays within that many metres of home. Returns true if it took over.
static func monster_think(m: Monster, dt: float, p: Player) -> bool:
	var t := tuning(m.get_tree())
	var c := Coat.on(m)
	if c != null and c.drunk > 0.0:
		# a heading that turns slowly round while it lurches up to 2 rad either side of it: it reels well off
		# any narrow path. The phase comes from where it spawned, so a run plays the same every time.
		var ph := fposmod(m.home.x * 1.7 + m.home.z * 0.9, TAU)
		var base: float = m.get_meta("wobble", ph) + 0.6 * dt
		m.set_meta("wobble", base)
		var a := base + 2.0 * sin(m._t * 1.3 + ph)
		var d := Vector3(cos(a), 0, sin(a))
		m.velocity.x = d.x * DRUNK_SPEED
		m.velocity.z = d.z * DRUNK_SPEED
		m._face(d)
		m.state = "move"
		m._mat.albedo_color = m._base.lerp(Color(0.7, 0.2, 0.55), 0.5)
		return true
	var lure := "honey" if m.kind in HONEY_LURES else "wine" if m.kind in WINE_LURES else ""
	if lure != "" and m.state == "move":
		var goal: Variant = _nearest(m, lure, t.lure_range)
		if goal != null:
			var d: Vector3 = (goal as Vector3) - m.global_position
			d.y = 0.0
			if d.length() > 0.3:
				m.velocity.x = d.normalized().x * Monster.SPEED
				m.velocity.z = d.normalized().z * Monster.SPEED
				m._face(d)
			else:
				m.velocity.x = 0.0
				m.velocity.z = 0.0
			m._mat.albedo_color = m._base
			return true
	if m.has_meta("leash") and m.state == "move":
		var h := m.home - m.global_position
		h.y = 0.0
		if h.length() > float(m.get_meta("leash")):
			m.velocity.x = h.normalized().x * Monster.SPEED
			m.velocity.z = h.normalized().z * Monster.SPEED
			m._face(h)
			return true
	return false

## The nearest puddle of kind (its centre) within reach of m and about level with it, or null.
static func _nearest(m: Node3D, kind: String, reach: float) -> Variant:
	var best: Variant = null
	var bd := reach
	for n in m.get_tree().get_nodes_in_group("puddles"):
		var pd := n as Puddle
		if pd.kind != kind or pd.is_queued_for_deletion():
			continue
		var at := pd.global_position
		if pd.is_pool():
			at = Vector3(clampf(m.global_position.x, pd.box.position.x + 0.5, pd.box.end.x - 0.5), pd.box.end.y, clampf(m.global_position.z, pd.box.position.z + 0.5, pd.box.end.z - 0.5))
		var d := at - m.global_position
		if absf(d.y) > 3.0:
			continue
		var fd := Vector2(d.x, d.z).length()
		if fd < bd:
			bd = fd
			best = at
	return best

## After a monster decides how to move: honey holds or slows it, and a sober monster won't step off a ledge.
static func monster_after(m: Monster) -> void:
	var c := Coat.on(m)
	if c != null and c.in_honey:
		if small(m):
			m.velocity.x = 0.0
			m.velocity.z = 0.0
		else:
			var hv := Vector2(m.velocity.x, m.velocity.z).limit_length(MONSTER_HONEY_SPEED)
			m.velocity.x = hv.x
			m.velocity.z = hv.y
	var drunk := c != null and c.drunk > 0.0
	if drunk or m.stun > 0.0 or m.air or m.knocked_t > 0.0 or not m.is_on_floor():
		return
	var hv3 := Vector3(m.velocity.x, 0, m.velocity.z)
	if hv3.length() < 0.1:
		return
	var ahead := m.global_position + hv3.normalized() * (m._r + 0.4)
	var q := PhysicsRayQueryParameters3D.create(ahead + Vector3.UP * 0.3, ahead + Vector3.DOWN * (m._r + 2.0), 1, [m.get_rid()])
	if m.get_world_3d().direct_space_state.intersect_ray(q).is_empty():
		m.velocity.x = 0.0 # a ledge: it stops at the edge
		m.velocity.z = 0.0

# ---------- the swap charm ----------

## What the swap charm would swap with: your lock-on target if it's rock candy in reach with a clear line,
## else the nearest such piece in front of you.
static func swap_target(p: Player) -> Node3D:
	var t := p.t
	if p.target != null and is_instance_valid(p.target) and Coat.is_candy(p.target) and _can_swap(p, p.target, t):
		return p.target
	var best: Node3D = null
	var bd := t.swap_range
	var f := p._flat_facing()
	for n in p.get_tree().get_nodes_in_group("candy"):
		var c := n as Node3D
		var d := c.global_position - p.global_position
		var fd := Vector2(d.x, d.z)
		if d.length() > bd or (fd.length() > 0.5 and Vector3(d.x, 0, d.z).normalized().dot(f) < 0.5):
			continue
		if not _can_swap(p, c, t):
			continue
		best = c
		bd = d.length()
	return best

static func _can_swap(p: Player, c: Node3D, t: Tuning) -> bool:
	if c.global_position.distance_to(p.global_position) > t.swap_range:
		return false
	var ex: Array[RID] = [p.get_rid()]
	if c is CollisionObject3D:
		ex.append((c as CollisionObject3D).get_rid())
	var q := PhysicsRayQueryParameters3D.create(p.global_position + Vector3.UP * 0.3, c.global_position + Vector3.UP * 0.2, 1, ex)
	return p.get_world_3d().direct_space_state.intersect_ray(q).is_empty()

## Trade places with rock candy. Returns false if there's nothing to swap with.
static func swap(p: Player) -> bool:
	var c := swap_target(p)
	if c == null:
		return false
	var pv := p.velocity
	var my_feet := p.global_position - Vector3.UP * p.radius()
	var its_feet := c.global_position - Vector3.UP * bottom(c)
	Hitfx.sparks(p.get_tree(), p.global_position, 1.0)
	Hitfx.sparks(p.get_tree(), c.global_position, 1.0)
	# For this frame the physics still sees each of you where the other now is: without this you'd land on top
	# of each other's old spot and ride it as a moving floor.
	var body := c as PhysicsBody3D
	if body != null:
		p.add_collision_exception_with(body)
		var pid := p.get_instance_id()
		var bid := body.get_instance_id()
		p.get_tree().create_timer(0.1, false, true).timeout.connect(func() -> void:
			var a := instance_from_id(pid) as PhysicsBody3D
			var b := instance_from_id(bid) as PhysicsBody3D
			if a != null and b != null:
				a.remove_collision_exception_with(b))
	p.teleport(its_feet + Vector3.UP * (p.radius() + 0.05))
	p.velocity = pv
	c.global_position = my_feet + Vector3.UP * (bottom(c) + 0.05)
	if p.target == c:
		p.target = null
	return true
