class_name Basin
extends Node3D
## A planned empty space (a dry channel, a hollow) that one pot of liquid fills completely: spill any liquid
## into it and it becomes a full pool of that liquid up to its brim (box). A basin filled with water at least
## 1 m deep is deep water (Water): crates float on it and drift with `current`, and you sink at normal size.
## Once full it stays full; more liquid poured in just mixes in.

var box := AABB() ## the empty space; its top is the brim
var current := Vector3.ZERO ## for deep water: what floating things drift with
var back_to := Vector3.ZERO ## for deep water: where you're put back if you sink
var kind := "" ## what it's full of, "" while dry
var water: Water = null

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

func fill(k: String) -> void:
	if kind != "":
		return
	kind = k
	if k == "water" and box.size.y >= 1.0:
		water = Water.make(get_parent(), box, back_to)
		water.current = current
	else:
		Puddle.pool(get_parent(), k, box)
