class_name Basin
extends Node3D
## A planned empty space (a dry channel, a hollow) that one pot of liquid fills completely: spill any liquid
## into it and it becomes a full pool of that liquid up to its brim (box). A basin filled with water at least
## 1 m deep is deep water (Water): crates float on it and drift with `current`, and you sink at normal size.
## Once full it stays full; the same liquid poured in changes nothing, another liquid replaces what's there.

var box := AABB() ## the empty space; its top is the brim
var current := Vector3.ZERO ## for deep water: what floating things drift with
var back_to := Vector3.ZERO ## for deep water: where you're put back if you sink
var kind := "" ## what it's full of, "" while dry
var water: Water = null
var pool: Puddle = null ## the liquid in it when it isn't deep water

static func make(parent: Node, volume: AABB, back: Vector3, flow := Vector3.ZERO) -> Basin:
	var b := Basin.new()
	b.box = volume
	b.back_to = back
	b.current = flow
	parent.add_child(b)
	return b

func _ready() -> void:
	add_to_group("basins")

## Does liquid landing at `at` fall into it?
func catches(at: Vector3) -> bool:
	return at.x > box.position.x and at.x < box.end.x and at.z > box.position.z and at.z < box.end.z \
		and at.y < box.end.y + 0.3 and at.y > box.position.y - 0.5

## Fill it with k. Already full of another liquid, the new one replaces it (jovi): out goes the old pool.
func fill(k: String) -> void:
	if k == "" or k == kind:
		return
	_drain(water)
	water = null
	_drain(pool)
	pool = null
	kind = k
	if k == "water" and box.size.y >= 1.0:
		water = Water.make(get_parent(), box, back_to)
		water.current = current
	else:
		pool = Puddle.pool(get_parent(), k, box)

## Take the old liquid out of the world now (out of its groups too, so nothing reads it this frame).
static func _drain(n: Node) -> void:
	if n == null or not is_instance_valid(n):
		return
	for g in n.get_groups():
		n.remove_from_group(g)
	n.queue_free()
