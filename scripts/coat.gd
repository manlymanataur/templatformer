class_name Coat
extends Node
## What liquids have done to one body (this node's parent): a honey coat, rock candy, wine.
## Made on demand by Coat.of(body) the first time a liquid touches it (see Liquids).
## - Honey: standing in it for honey_cover, or a honey pot hitting it, coats a thing. Heat (a lit brazier within
##   heat_reach, the lit candle hat within candle_heat, or anything Lighting.spread_heat warms, since a coat is
##   "flammable") hardens the coat into rock candy after candy_heat_time: the thing is frozen where it is (it
##   still falls), looks like pink crystal, and is the only thing the swap charm swaps with. The player is only
##   slowed or held by honey, never coated.
## - Wine makes a thing drunk for a while (see Liquids); wine and water wash honey and rock candy off.

var body: Node3D
var honey := false ## coated in honey
var candy := false ## hardened into rock candy
var in_honey := false ## standing in honey this frame
var honey_t := 0.0 ## seconds standing in honey
var heat_t := 0.0 ## seconds of heat on the coat
var drunk := 0.0 ## seconds of wine left
var _was_target := false
var _shell: MeshInstance3D
var _mat: StandardMaterial3D

static func on(b: Node) -> Coat:
	return b.get_node_or_null("Coat") as Coat if b != null else null

static func of(b: Node) -> Coat:
	var c := on(b)
	if c == null:
		c = Coat.new()
		c.name = "Coat"
		c.body = b as Node3D
		b.add_child(c)
	return c

static func is_candy(b: Node) -> bool:
	var c := on(b)
	return c != null and c.candy

func _ready() -> void:
	_shell = MeshInstance3D.new()
	var sm := SphereMesh.new()
	var r := Liquids.bottom(body) + 0.12
	sm.radius = r
	sm.height = r * 2.0
	_shell.mesh = sm
	_mat = StandardMaterial3D.new()
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.roughness = 0.05
	_mat.metallic = 0.2
	_shell.material_override = _mat
	_shell.visible = false
	body.add_child.call_deferred(_shell)

## Honey sticks to it (the player only gets slowed, so nothing sticks).
func coat_honey() -> void:
	if candy or body is Player:
		return
	honey = true
	add_to_group("flammable")
	_look()

func wash() -> void:
	if not honey and not candy:
		return
	honey = false
	heat_t = 0.0
	remove_from_group("flammable")
	if candy:
		candy = false
		body.remove_from_group("candy")
		if not _was_target:
			body.remove_from_group("targets")
	_look()

func harden() -> void:
	if candy:
		return
	candy = true
	honey = false
	remove_from_group("flammable")
	body.add_to_group("candy")
	_was_target = body.is_in_group("targets")
	body.add_to_group("targets") # lock on to it to aim the swap charm
	if "velocity" in body:
		body.velocity.x = 0.0
		body.velocity.z = 0.0
	Hitfx.sparks(body.get_tree(), body.global_position, 1.2)
	_look()

func make_drunk(secs: float) -> void:
	drunk = maxf(drunk, secs)

func _look() -> void:
	if _shell == null:
		return
	_shell.visible = honey or candy
	if candy:
		_mat.albedo_color = Color(1.0, 0.55, 0.8, 0.75)
		_mat.emission_enabled = true
		_mat.emission = Color(1.0, 0.4, 0.7)
		_mat.emission_energy_multiplier = 0.5
		_mat.metallic = 0.6
	else:
		_mat.albedo_color = Color(0.95, 0.65, 0.1, 0.5)
		_mat.emission_enabled = false
		_mat.metallic = 0.2

func _physics_process(dt: float) -> void:
	drunk = maxf(drunk - dt, 0.0)
	if honey and not candy:
		var t := Liquids.tuning(get_tree())
		if Liquids.near_fire(body, t):
			heat(dt)

# flammable (while coated in honey): heat hardens it
func heat_box() -> AABB:
	var r := Liquids.bottom(body)
	return AABB(body.global_position - Vector3.ONE * r, Vector3.ONE * r * 2.0)

func heat(dt: float) -> void:
	if not honey or candy:
		return
	heat_t += dt
	if heat_t >= Liquids.tuning(get_tree()).candy_heat_time:
		harden()
