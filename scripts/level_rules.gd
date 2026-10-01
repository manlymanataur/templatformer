class_name LevelRules
extends RefCounted
## Checks built rooms against jovi's feel rules (CLAUDE.md, "Level feel rules").
## It samples the top surface every 0.5 m with downward rays, joins neighbouring samples into flat or sloped
## regions, then looks at where regions meet:
##   low ledge   a ledge under 2 m between two real floors (pointless, just a speed bump)
##   short gap   a pit you must jump that is under 6 m wide (pointless and tedious)
##   long gap    a 10-12 m jump with less than 12 m of runway before it and no pad nearby
##   3 m norm    more than half of an area's ledges are the situational 3 m height
## Only floors count: a region must hold a 2.5 m square somewhere, so wall tops, props and gate tops are skipped.
## Rays start at the top of each area's box, so a roofed area's box stops under the roof.
## Gaps wider than 12 m (past a running triple jump) are treated as chasms you aren't meant to jump (Umbra, magnet, launchers).

const STEP := 0.5
const SAME := 0.55 ## neighbours closer than this in height are one region (ramps up to about 47°)
const WALL := 1e9 ## height stored where the ray starts inside something or meets a steep face: never a pit
const OPEN := 2 ## a floor holds a (2 * OPEN + 1) cell square: 2.5 m
const MASK := 1 | 1 << 2 ## world and grates; bars and railings (layer 2) are fences, not floors

## Areas that are real level design. The test stations by the start show off numbers on purpose.
const AREAS := {
	"Ember & Umbra": AABB(Vector3(-14, -4, 34), Vector3(24, 13.5, 88)), # stops under the 10 m roof
	"Lodestone": AABB(Vector3(50, -4, -36), Vector3(30, 20, 40)),
	"Scale": AABB(Vector3(-100, -8, 36), Vector3(46, 24, 76)),
	"Rootworks": AABB(Vector3(34, -4, 53), Vector3(52, 24, 61)), # the ramp foot is left out: it runs by the arena
	"Moves yard": AABB(Vector3(-26, -4, -120), Vector3(52, 16, 56)),
	"Combat yard": AABB(Vector3(-118, -4, -66), Vector3(62, 14, 54)),
	# the Works, less its iron room (x 122..152, z -44..-14): that pit is for iron, 2 m wide on purpose
	"Works": AABB(Vector3(152, -6, -44), Vector3(66, 16, 60)),
	"Works (screws)": AABB(Vector3(120, -6, -14), Vector3(32, 16, 30)),
}

class Grid:
	var o: Vector3
	var nx: int
	var nz: int
	var h: PackedFloat32Array ## NAN where there is no floor
	var region: PackedInt32Array
	var floor_region := {} ## region ids that are real floors (see OPEN)
	func idx(i: int, j: int) -> int:
		return j * nx + i
	func at(i: int, j: int) -> Vector3:
		return Vector3(o.x + (i + 0.5) * STEP, h[idx(i, j)], o.z + (j + 0.5) * STEP)

static func sample(space: PhysicsDirectSpaceState3D, box: AABB) -> Grid:
	var g := Grid.new()
	g.o = box.position
	g.nx = int(box.size.x / STEP)
	g.nz = int(box.size.z / STEP)
	g.h.resize(g.nx * g.nz)
	for j in g.nz:
		for i in g.nx:
			var x := g.o.x + (i + 0.5) * STEP
			var z := g.o.z + (j + 0.5) * STEP
			var q := PhysicsRayQueryParameters3D.create(Vector3(x, box.end.y, z), Vector3(x, box.position.y, z), MASK)
			q.hit_from_inside = true
			var hit := space.intersect_ray(q)
			var y := NAN
			if not hit.is_empty():
				var n: Vector3 = hit["normal"]
				if n.y <= 0.7:
					y = WALL # inside something, or a face too steep to stand on
				elif n.y > 0.7:
					y = (hit["position"] as Vector3).y
			g.h[g.idx(i, j)] = y
	_regions(g)
	return g

static func _regions(g: Grid) -> void:
	g.region.resize(g.nx * g.nz)
	g.region.fill(-1)
	var next := 0
	for start in g.h.size():
		if g.region[start] >= 0 or is_nan(g.h[start]) or g.h[start] == WALL:
			continue
		var id := next
		next += 1
		var stack: Array[int] = [start]
		g.region[start] = id
		while not stack.is_empty():
			var c: int = stack.pop_back()
			var ci := c % g.nx
			var cj := c / g.nx
			for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
				var ni: int = ci + d.x
				var nj: int = cj + d.y
				if ni < 0 or nj < 0 or ni >= g.nx or nj >= g.nz:
					continue
				var k := g.idx(ni, nj)
				if g.region[k] < 0 and not is_nan(g.h[k]) and g.h[k] != WALL and absf(g.h[k] - g.h[c]) < SAME:
					g.region[k] = id
					stack.append(k)
	for j in range(OPEN, g.nz - OPEN):
		for i in range(OPEN, g.nx - OPEN):
			var r := g.region[g.idx(i, j)]
			if r < 0 or g.floor_region.has(r):
				continue
			var whole := true
			for dj in range(-OPEN, OPEN + 1):
				for di in range(-OPEN, OPEN + 1):
					whole = whole and g.region[g.idx(i + di, j + dj)] == r
			if whole:
				g.floor_region[r] = true

static func _big(g: Grid, k: int) -> bool:
	return g.region[k] >= 0 and g.floor_region.has(g.region[k])

## Every rule break in one area, one entry per pair of regions: {kind, at, size, text}.
static func check(space: PhysicsDirectSpaceState3D, box: AABB, launchers: Array[Vector3] = []) -> Array[Dictionary]:
	var g := sample(space, box)
	var found := {} # "kind a-b" -> {kind, sum, n, size}
	var ledges := {} # region pair -> height
	for j in g.nz:
		for i in g.nx:
			var k := g.idx(i, j)
			if not _big(g, k):
				continue
			# ledges: a big region right next to another big region at a different height
			for d in [Vector2i(1, 0), Vector2i(0, 1)]:
				var ni: int = i + d.x
				var nj: int = j + d.y
				if ni >= g.nx or nj >= g.nz:
					continue
				var nk := g.idx(ni, nj)
				if not _big(g, nk) or g.region[nk] == g.region[k]:
					continue
				var dh := absf(g.h[nk] - g.h[k])
				var pair := _pair(g.region[k], g.region[nk])
				ledges[pair] = dh
				if dh < 1.9:
					_add(found, "low ledge", pair, (g.at(i, j) + g.at(ni, nj)) / 2.0, dh)
			# gaps: step off this floor over a drop and look for floor to land on
			for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(-1, 0), Vector2i(0, -1)]:
				var ni: int = i + d.x
				var nj: int = j + d.y
				if ni < 0 or nj < 0 or ni >= g.nx or nj >= g.nz:
					continue
				var nk := g.idx(ni, nj)
				if not (is_nan(g.h[nk]) or g.h[nk] < g.h[k] - 1.9):
					continue
				var steps := 1
				while steps < int(15.0 / STEP):
					var fi: int = i + d.x * (steps + 1)
					var fj: int = j + d.y * (steps + 1)
					if fi < 0 or fj < 0 or fi >= g.nx or fj >= g.nz:
						steps = 999
						break
					var fk := g.idx(fi, fj)
					if g.h[fk] == WALL:
						break # a wall across the drop: a pit, not a jump
					if not is_nan(g.h[fk]) and g.h[fk] >= g.h[k] - 1.9:
						if _big(g, fk) and g.h[fk] <= g.h[k] + 1.5:
							var width := steps * STEP
							var mid := (g.at(i, j) + g.at(fi, fj)) / 2.0
							var pair := _pair(g.region[k], g.region[fk])
							if width >= 1.0 and width < 6.0:
								_add(found, "short gap", pair, mid, width)
							elif width >= 10.0 and width <= 12.0 and _runway(g, i, j, -d) < 12.0 and not _near(launchers, g.at(i, j), 20.0):
								_add(found, "long gap", pair, mid, width)
						break
					steps += 1
	var out: Array[Dictionary] = []
	for key in found:
		var f: Dictionary = found[key]
		var at: Vector3 = f["sum"] / float(f["n"])
		out.append({"kind": f["kind"], "at": at, "size": f["size"],
			"text": "%s %.1f m at (%d, %d)" % [f["kind"], f["size"], roundi(at.x), roundi(at.z)]})
	var three := 0
	for pair in ledges:
		if ledges[pair] >= 2.5 and ledges[pair] <= 3.5:
			three += 1
	if ledges.size() >= 4 and three * 2 > ledges.size():
		out.append({"kind": "3 m norm", "at": box.get_center(), "size": float(three),
			"text": "3 m norm: %d of %d ledges are 3 m" % [three, ledges.size()]})
	return out

static func _pair(a: int, b: int) -> String:
	return "%d-%d" % [mini(a, b), maxi(a, b)]

static func _add(found: Dictionary, kind: String, pair: String, at: Vector3, size: float) -> void:
	var key := kind + " " + pair
	if not found.has(key):
		found[key] = {"kind": kind, "sum": Vector3.ZERO, "n": 0, "size": size}
	var f: Dictionary = found[key]
	f["sum"] += at
	f["n"] += 1
	f["size"] = minf(f["size"], size) if kind == "low ledge" else maxf(f["size"], size) if kind == "long gap" else minf(f["size"], size)

## Metres of floor behind (i, j), walking along dir, that stay within 1 m of its height or run downhill into it.
static func _runway(g: Grid, i: int, j: int, dir: Vector2i) -> float:
	var n := 0
	var prev := g.h[g.idx(i, j)]
	while true:
		var fi: int = i + dir.x * (n + 1)
		var fj: int = j + dir.y * (n + 1)
		if fi < 0 or fj < 0 or fi >= g.nx or fj >= g.nz:
			break
		var y := g.h[g.idx(fi, fj)]
		if is_nan(y) or y < prev - SAME or y > prev + SAME * 3.0:
			break
		prev = y
		n += 1
	return n * STEP

static func _near(points: Array[Vector3], at: Vector3, r: float) -> bool:
	for p in points:
		if Vector2(p.x - at.x, p.z - at.z).length() < r:
			return true
	return false

## Positions of everything that throws you (launch and boost pads, fans), so long gaps next to them pass.
static func launchers(root: Node) -> Array[Vector3]:
	var out: Array[Vector3] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Pad or n is Fan:
			out.append((n as Node3D).global_position)
		stack.append_array(n.get_children())
	return out
