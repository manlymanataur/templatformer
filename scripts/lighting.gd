class_name Lighting
extends RefCounted
## Light as a game rule, not just a look. A point is lit when a shining source in group "light_sources"
## is within its reach and nothing solid (collision layer 1) blocks the straight line to it, or when the
## sun (group "sun") has a clear line down to it. Bodies block light too, so the player casts a shadow
## unless they are the one giving off light (a source never blocks itself).
##
## A light source provides is_shining(), light_origin() and light_reach().
## Anything in group "flammable" provides heat_box() (a world AABB) and heat(dt). Fire and the candle
## call spread_heat() to warm whatever they touch.

static func is_lit(at: Vector3, world: Node3D, exclude: Array[RID] = []) -> bool:
	var space := world.get_world_3d().direct_space_state
	for s in world.get_tree().get_nodes_in_group("light_sources"):
		if not s.is_shining():
			continue
		var o: Vector3 = s.light_origin()
		if o.distance_to(at) > s.light_reach():
			continue
		var ex: Array[RID] = exclude.duplicate()
		if s is CollisionObject3D:
			ex.append((s as CollisionObject3D).get_rid())
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(o, at, 1, ex)).is_empty():
			return true
	for sun in world.get_tree().get_nodes_in_group("sun"):
		var toward_sun: Vector3 = (sun as Node3D).global_transform.basis.z
		if space.intersect_ray(PhysicsRayQueryParameters3D.create(at, at + toward_sun * 120.0, 1, exclude)).is_empty():
			return true
	return false

## Warm every flammable thing within reach of this point (measured to its surface).
static func spread_heat(from: Vector3, reach: float, dt: float, world: Node, skip: Node = null) -> void:
	for n in world.get_tree().get_nodes_in_group("flammable"):
		if n == skip:
			continue
		var box: AABB = n.heat_box()
		var closest := from.clamp(box.position, box.end)
		if closest.distance_to(from) <= reach:
			n.heat(dt)
