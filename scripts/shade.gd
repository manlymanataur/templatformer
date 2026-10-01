class_name Shade
extends Monster
## A shade (Power Combat Sketchbook II). It fights like a blob, but in the dark it has no body to hit: your
## poleaxe, bombs and the pound pass through it. Only Umbra's greatsword hurts it there. Light exposes it
## (the candle hat, a lit brazier, burning grass, the sun: anything Lighting.is_lit counts): exposed it turns
## solid, slows to half speed and takes every hit. It won't step into light that isn't yours, so a brazier's
## pool is a safe spot, but your candle doesn't scare it off: it comes to you and gets exposed.

var exposed := false
var _eyes_mat: StandardMaterial3D

static func make(parent: Node, pos: Vector3) -> Shade:
	var s := Shade.new()
	s.kind = "blob" # a blob's lunge
	s.position = pos
	parent.add_child(s)
	s.global_position = pos
	s.home = pos
	return s

func _ready() -> void:
	super._ready()
	add_to_group("shades")
	max_hp = 4
	hp = max_hp
	_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_mat.emission_enabled = true
	_mat.emission = Color(0.4, 0.3, 0.9)
	_mat.emission_energy_multiplier = 0.4
	_set_look()

func _set_look() -> void:
	_base = Color(0.42, 0.3, 0.75, 1.0) if exposed else Color(0.25, 0.18, 0.5, 0.35)

func _physics_process(dt: float) -> void:
	exposed = Lighting.is_lit(global_position, self, [get_rid()])
	_set_look()
	super._physics_process(dt)

func _think(dt: float, p: Player) -> void:
	super._think(dt, p)
	if state != "move":
		return
	if exposed:
		velocity.x *= 0.5
		velocity.z *= 0.5
	var hv := Vector3(velocity.x, 0, velocity.z)
	if hv.length() > 0.1:
		var ahead := global_position + hv.normalized() * 0.8
		if static_lit(ahead) and not static_lit(global_position):
			velocity.x = 0.0 # a pool of light it won't enter
			velocity.z = 0.0

## Lit by something other than you (braziers, burning grass, the sun).
func static_lit(at: Vector3) -> bool:
	var space := get_world_3d().direct_space_state
	for s in get_tree().get_nodes_in_group("light_sources"):
		if s is Player or not s.is_shining():
			continue
		var o: Vector3 = s.light_origin()
		if o.distance_to(at) > s.light_reach():
			continue
		var ex: Array[RID] = [get_rid()]
		if s is CollisionObject3D:
			ex.append((s as CollisionObject3D).get_rid())
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(o, at, 1, ex)).is_empty():
			return true
	for sun in get_tree().get_nodes_in_group("sun"):
		var toward_sun: Vector3 = (sun as Node3D).global_transform.basis.z
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + toward_sun * 120.0, 1, [get_rid()])).is_empty():
			return true
	return false

## In the dark only the twin's blade lands; light makes it fair game.
func strike(amount: int, from: Vector3, info: Dictionary) -> int:
	if not exposed and not info.get("twin", false):
		Hitfx.sparks(get_tree(), global_position, 0.4) # it passes through
		return 0
	return super.strike(amount, from, info)
