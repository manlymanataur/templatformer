class_name Power
extends Node
## Lodestone power. Batteries (group "power_source") power any iron (group "conductor") touching them
## face to face, and power flows on through iron touching iron. Anything in group "power_sink"
## (doors, powered pads) is on while it touches a battery or powered iron. Every piece provides power_box(),
## a world AABB. Touching means the boxes meet on a side: a small gap on one horizontal axis and real
## overlap on the other and vertically, so corners (diagonals) never connect.

const GAP := 0.15

static func touching(a: AABB, b: AABB) -> bool:
	var ov := func(a0: float, a1: float, b0: float, b1: float) -> float:
		return minf(a1, b1) - maxf(a0, b0)
	var ox: float = ov.call(a.position.x, a.end.x, b.position.x, b.end.x)
	var oy: float = ov.call(a.position.y, a.end.y, b.position.y, b.end.y)
	var oz: float = ov.call(a.position.z, a.end.z, b.position.z, b.end.z)
	if oy < 0.3:
		return false
	return (ox > -GAP and ox <= GAP and oz > 0.5) or (oz > -GAP and oz <= GAP and ox > 0.5)

func _physics_process(_dt: float) -> void:
	var tree := get_tree()
	var live: Array = []
	var queue: Array = []
	for src in tree.get_nodes_in_group("power_source"):
		live.append(src)
		queue.append(src)
	var wires := tree.get_nodes_in_group("conductor")
	while not queue.is_empty():
		var n = queue.pop_back()
		var nb: AABB = n.power_box()
		for w in wires:
			if not live.has(w) and touching(nb, w.power_box()):
				live.append(w)
				queue.append(w)
	for w in wires:
		w.powered = live.has(w)
	for sink in tree.get_nodes_in_group("power_sink"):
		var sb: AABB = sink.power_box()
		var on := false
		for n in live:
			if touching(sb, n.power_box()):
				on = true
				break
		sink.set_powered(on)
