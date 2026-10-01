class_name Puddle
extends Node3D
## Liquid on the ground: water, wine or honey. A spilled puddle is a flat disc of fixed size (radius) lying
## where the pot broke; a pool is a permanent box of liquid you can wade through (box), like the wine trough,
## a water basin, or a Basin a pot has filled. Liquids.spill makes them; Liquids.under reads them; things
## standing in one get its effect (see Liquids). Puddles never spread or run: only a Runnel moves liquid.
## - Water puddles leave the ground wet for wet_time, then dry up. Wet ground won't take wine or fire.
## - Wine burns: heat (a lit brazier within heat_reach, the candle, burning grass, a burning crate, burning
##   wine next to it) lights it, and while it burns it warms everything it touches, so fire runs along wine.
##   A spilled wine puddle burns away after wine_burn; a wine pool burns until water puts it out.
##   Burning wine hurts whatever stands in it.
## - Honey stays where it lands.

var kind := "water"
var radius := 1.6
var box := AABB() ## a pool's volume (its top is the surface); size zero for a spilled puddle
var permanent := false
var wet := 0.0 ## water: seconds before it dries; a doused wine pool: seconds it can't catch
var burning := false
var _burn_left := 0.0
var _warm := 0.0
var _burnt_t := {} ## things burning wine has hurt recently
var _mesh: MeshInstance3D
var _mat: StandardMaterial3D
var _flames: Node3D

const COLORS := {"water": Color(0.25, 0.5, 0.9, 0.55), "wine": Color(0.5, 0.05, 0.25, 0.75), "honey": Color(0.95, 0.65, 0.1, 0.85)}

## A spilled disc of liquid lying on the ground at pos.
static func make(parent: Node, k: String, pos: Vector3, r: float) -> Puddle:
	var p := Puddle.new()
	p.kind = k
	p.radius = r
	p.position = pos
	parent.add_child(p)
	return p

## A permanent pool filling volume (a shallow basin, a trough).
static func pool(parent: Node, k: String, volume: AABB) -> Puddle:
	var p := Puddle.new()
	p.kind = k
	p.box = volume
	p.permanent = true
	p.position = Vector3(volume.get_center().x, volume.end.y, volume.get_center().z)
	parent.add_child(p)
	return p

func is_pool() -> bool:
	return box.size != Vector3.ZERO

func _ready() -> void:
	add_to_group("puddles")
	add_to_group("flammable")
	add_to_group("light_sources")
	if kind == "water" and not permanent:
		wet = Liquids.tuning(get_tree()).wet_time
	_mesh = MeshInstance3D.new()
	_mat = StandardMaterial3D.new()
	_mat.albedo_color = COLORS[kind]
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.roughness = 0.05 if kind != "honey" else 0.3
	_mesh.material_override = _mat
	if is_pool():
		var bm := BoxMesh.new()
		bm.size = box.size
		_mesh.mesh = bm
		_mesh.position.y = -box.size.y / 2.0
	else:
		_set_disc()
	add_child(_mesh)
	_flames = Node3D.new()
	_flames.visible = false
	add_child(_flames)
	var n := 4 if not is_pool() else maxi(2, int(box.size.x * box.size.z / 3.0))
	for i in n:
		var f := Burnable.flame_mesh(0.9)
		var a := TAU * i / n
		if is_pool():
			f.position = Vector3(randf_range(-0.4, 0.4) * box.size.x, 0.45, randf_range(-0.4, 0.4) * box.size.z)
		else:
			f.position = Vector3(cos(a), 0, sin(a)) * radius * 0.5 + Vector3.UP * 0.45
		_flames.add_child(f)

func _set_disc() -> void:
	var cm := CylinderMesh.new()
	cm.top_radius = radius
	cm.bottom_radius = radius
	cm.height = 0.04
	cm.radial_segments = 20
	cm.rings = 1
	_mesh.mesh = cm
	_mesh.position.y = 0.03

## Spilled again on top of itself: the same size, but fresh again.
func refresh() -> void:
	if kind == "water":
		wet = Liquids.tuning(get_tree()).wet_time

## Is a point (something's feet) standing in it?
func covers(feet: Vector3) -> bool:
	if is_pool():
		return feet.x > box.position.x and feet.x < box.end.x and feet.z > box.position.z and feet.z < box.end.z \
			and feet.y > box.position.y - 0.3 and feet.y < box.end.y + 0.5
	var d := feet - global_position
	return Vector2(d.x, d.z).length() < radius and d.y > -0.5 and d.y < 0.6

## Is a point (something's feet) inside its flames? They reach 2 m up.
func in_fire(feet: Vector3) -> bool:
	if is_pool():
		return feet.x > box.position.x and feet.x < box.end.x and feet.z > box.position.z and feet.z < box.end.z \
			and feet.y > box.position.y - 0.3 and feet.y < box.end.y + 2.0
	var d := feet - global_position
	return Vector2(d.x, d.z).length() < radius and d.y > -0.5 and d.y < 2.0

## Does it overlap a disc of radius r around at (on about the same level)?
func touches(at: Vector3, r: float) -> bool:
	if is_pool():
		var c := Vector3(clampf(at.x, box.position.x, box.end.x), at.y, clampf(at.z, box.position.z, box.end.z))
		return Vector2(c.x - at.x, c.z - at.z).length() < r and absf(at.y - box.end.y) < 1.5
	var d := at - global_position
	return Vector2(d.x, d.z).length() < radius + r and absf(d.y) < 1.5

## Water on it. Burning wine goes out and stays wet; spilled wine and honey wash away.
func douse() -> void:
	var t := Liquids.tuning(get_tree())
	if kind == "water":
		wet = t.wet_time
		return
	burning = false
	_flames.visible = false
	_warm = 0.0
	if permanent:
		wet = t.wet_time
	else:
		queue_free()

## Light it (wine only, and not while wet).
func ignite() -> void:
	if kind != "wine" or burning or wet > 0.0 or is_queued_for_deletion():
		return
	if Liquids.wet_at(get_tree(), global_position, 0.0, self):
		return
	burning = true
	_burn_left = Liquids.tuning(get_tree()).wine_burn
	_flames.visible = true

func _physics_process(dt: float) -> void:
	var t := Liquids.tuning(get_tree())
	if wet > 0.0:
		wet -= dt
		if kind == "water" and not permanent:
			_mat.albedo_color.a = COLORS["water"].a * clampf(wet / 5.0, 0.2, 1.0)
			if wet <= 0.0:
				queue_free()
		return
	if kind != "wine":
		return
	if not burning:
		if Liquids.near_brazier(self, t):
			heat(dt)
		return
	# burning: warm what it touches, hurt what stands in it
	var reach := (maxf(box.size.x, box.size.z) / 2.0 if is_pool() else radius) + 0.4
	Lighting.spread_heat(global_position + Vector3.UP * 0.2, reach, dt, self, self)
	var now := Time.get_ticks_msec()
	for b in Liquids.bodies(get_tree()):
		if not b.has_method("hurt") or not in_fire(b.global_position - Vector3.UP * Liquids.bottom(b)):
			continue
		var from := global_position # you're thrown back out the way you came in
		from.y = b.global_position.y
		if now - int(_burnt_t.get(b.get_instance_id(), -100000)) >= 500:
			_burnt_t[b.get_instance_id()] = now
			b.hurt(1, from)
		if b is Player and is_instance_valid(b):
			# the flames won't let you through, even while a hit has you blinking
			var pl := b as Player
			var away := pl.global_position - from
			away = away.normalized() if away.length() > 0.01 else -pl._flat_facing()
			pl.velocity = away * 8.0 + Vector3.UP * 4.0
			pl.air_lock = 0.1
	if not permanent:
		_burn_left -= dt
		if _burn_left <= 0.0:
			queue_free() # the wine burnt off

# flammable: wine catches fire
func heat_box() -> AABB:
	if is_pool():
		return box
	return AABB(global_position - Vector3(radius, 0.05, radius), Vector3(radius * 2.0, 0.35, radius * 2.0))

func heat(dt: float) -> void:
	if kind != "wine" or burning or wet > 0.0:
		return
	_warm += dt
	if _warm >= 0.1:
		ignite()

# light source while burning
func is_shining() -> bool:
	return burning
func light_origin() -> Vector3:
	return global_position + Vector3.UP * 0.8
func light_reach() -> float:
	return 6.0
