class_name Machinery
extends Node
## Winch machinery: gears, racks, screws and arms that turn each other. One node in the level gathers every
## turn asked this frame (the spider walking past teeth, the rope sliding over a rim) and turns the trains once,
## after the spider and the rope have moved.
## - Parts are everything in group "cogs" (Gear and its kinds, Rack). Each has cog_room(dir) (how far it can
##   go that way before a stop), cog_apply(amount) and cog_jam().
## - Meshes come from where the parts are: two gears whose rims touch turn opposite ways (factor -1); a gear
##   whose rim touches a rack's toothed side slides it one metre per metre of rim, the way that side moves.
##   A gear riding a rack doesn't mesh with that rack. link() adds a fixed mesh (a crank geared to a rack).
## - A train asked to turn two ways at once jams: nothing in it turns, and the gears spark. That's an odd ring
##   of meshed gears, or the rope and spider pushing two meshed parts the same way.
## - Otherwise the whole train turns, but only as far as its tightest stop allows (a lift at the top of its
##   travel, a screw flush with the floor, a rack at the end of its groove or pinned by your weight).

const MESH_TOL := 0.2 ## rims this close to touching mesh
const MESH_DY := 1.0 ## and only at about the same height

static var _inst: Machinery = null
static var _links: Array = [] ## [a, b, factor]: b turns factor times a

var _queue: Array = [] ## [part, amount] asked this frame

func _ready() -> void:
	add_to_group("machinery")
	process_physics_priority = 150 # after the spider (0) and the rope (100) have asked for their turns
	_inst = self

func _exit_tree() -> void:
	if _inst == self:
		_inst = null

## Ask a part to turn by amount this frame.
static func demand(part: Node, amount: float) -> void:
	if absf(amount) < 0.000001:
		return
	if _inst != null and is_instance_valid(_inst) and _inst.is_inside_tree():
		_inst._queue.append([part, amount])
	else:
		resolve([[part, amount]], part.get_tree())

## A fixed mesh outside the geometry: b turns factor times a (a crank geared to a rack under the floor).
static func link(a: Node, b: Node, factor: float) -> void:
	_links.append([a, b, factor])

func _physics_process(_dt: float) -> void:
	if _queue.is_empty():
		return
	var q := _queue
	_queue = []
	resolve(q, get_tree())

## Every part the given part meshes with, as [other, factor].
static func neighbours(part: Node, parts: Array) -> Array:
	var out: Array = []
	for o in parts:
		if o == part:
			continue
		var f := _mesh(part, o)
		if f != 0.0:
			out.append([o, f])
	for l in _links:
		if not is_instance_valid(l[0]) or not is_instance_valid(l[1]):
			continue
		if l[0] == part:
			out.append([l[1], float(l[2])])
		elif l[1] == part:
			out.append([l[0], 1.0 / float(l[2])])
	return out

## How b turns when a turns by 1 through a geometric mesh, or 0 if they don't mesh.
static func _mesh(a: Node, b: Node) -> float:
	if a is Gear and b is Gear:
		var ga := a as Gear
		var gb := b as Gear
		var d := Vector2(ga.global_position.x - gb.global_position.x, ga.global_position.z - gb.global_position.z).length()
		if absf(d - ga.radius - gb.radius) < MESH_TOL and absf(ga.global_position.y - gb.global_position.y) < MESH_DY:
			return -1.0
		return 0.0
	if a is Gear and b is Rack:
		return (b as Rack).mesh_factor(a as Gear)
	if a is Rack and b is Gear:
		return (a as Rack).mesh_factor(b as Gear) # factors are +-1, so the inverse is itself
	return 0.0

## Turn the trains asked for: each demand is [part, amount].
static func resolve(demands: Array, tree: SceneTree) -> void:
	var parts: Array = tree.get_nodes_in_group("cogs")
	var val := {} # part -> amount this frame
	var comp := {} # part -> train id
	var jammed := {} # train id -> true
	var trains: Array = [] # train id -> Array of parts
	for dmd in demands:
		var start: Node = dmd[0]
		var amount: float = dmd[1]
		if not is_instance_valid(start):
			continue
		if comp.has(start):
			# a second ask on a train already moving this frame: a different direction jams it
			var have: float = val[start]
			if signf(have) != signf(amount):
				jammed[comp[start]] = true
			continue
		var id := trains.size()
		var members: Array = [start]
		trains.append(members)
		val[start] = amount
		comp[start] = id
		var stack: Array = [start]
		while not stack.is_empty():
			var n: Node = stack.pop_back()
			for nb in neighbours(n, parts):
				var o: Node = nb[0]
				var v: float = val[n] * float(nb[1])
				if comp.has(o):
					if comp[o] != id:
						continue # a different train met this frame can't be reached (meshes are symmetric)
					var have: float = val[o]
					if absf(have - v) > 0.01 * maxf(absf(have), absf(v)) + 0.000001:
						jammed[id] = true
					continue
				val[o] = v
				comp[o] = id
				members.append(o)
				stack.append(o)
	for id in trains.size():
		var members: Array = trains[id]
		if jammed.has(id):
			for n in members:
				n.cog_jam()
			continue
		var k := 1.0
		for n in members:
			var v: float = val[n]
			if absf(v) < 0.000001:
				continue
			var room: float = n.cog_room(signf(v))
			k = minf(k, maxf(room, 0.0) / absf(v))
		if k <= 0.0:
			continue
		for n in members:
			n.cog_apply(float(val[n]) * k)
