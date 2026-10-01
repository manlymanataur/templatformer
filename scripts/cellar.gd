class_name Cellar
extends RefCounted
## The Cellar (Honey & Wine): four roofed rooms off the east edge of the map (x 136..172, z -150..-102,
## floors at y 0, pits and channels 4 m deep), reached by warp. One idea per room; rooms connect by doorways.
## R1 Candy trap (z -114..-102): a 13 m pit. Fill a pot at the hive, run and throw it across so the honey lands
##   by the brazier. The blob comes for the honey, gets stuck, the heat hardens it into rock candy, and the
##   swap charm trades you across. (The water pipe washes a blob stuck in the wrong place.)
## R2 Last call (z -126..-114): a brute holds a 2 m bridge over a pit. Throw wine onto the bridge: it drinks,
##   staggers and falls off. Then throw water on the bridge to wash the wine away before you cross.
## R3 Raft (z -138..-126): a dry 14 m channel (a Basin). One pot of water fills it, with a current toward the far
##   bank. Push the crate in: it floats, and you ride it over.
## R4 Fire door (z -150..-138): burning wine fills the trough under a low doorway, and the brazier beside it
##   relights it. Splash water on it (or on the runnel from the shelf, which carries it down into the trough):
##   the fire's out and the trough stays wet for wet_time. Cross in time.
## Marks start with cellar_.

const FLOOR := 0.0
const PIT := -4.0
const ROOF := 8.0
const WALL := Color(0.36, 0.3, 0.28)
const STONE := Color(0.55, 0.5, 0.45)
const WOOD := Color(0.5, 0.36, 0.22)

static func build(lv: Node3D) -> void:
	var marks: Dictionary = lv.marks
	var t: Tuning = lv.t
	var rect := func(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, c: Color) -> StaticBody3D:
		return lv.box(Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0, y1 - y0, z1 - z0), Basis(), c)

	# shell: pit floor, outer walls, roof, the walls between the rooms (each with a doorway)
	rect.call(136, 172, -150, -102, PIT - 0.5, PIT, STONE)
	rect.call(135.5, 136, -150.5, -101.5, PIT, ROOF, WALL)
	rect.call(172, 172.5, -150.5, -101.5, PIT, ROOF, WALL)
	rect.call(135.5, 172.5, -102, -101.5, PIT, ROOF, WALL)
	rect.call(135.5, 172.5, -150.5, -150, PIT, ROOF, WALL)
	rect.call(135.5, 172.5, -150.5, -101.5, ROOF, ROOF + 0.5, WALL)
	_cross(rect, -114.0, 168.0, 172.0)
	_cross(rect, -126.0, 136.0, 140.0)
	_cross(rect, -138.0, 168.0, 172.0)
	for z in [-108.0, -120.0, -132.0, -144.0]:
		var lamp := OmniLight3D.new() # roofed: lamps so you can see (they don't count as light, see Lighting)
		lamp.omni_range = 22.0
		lamp.light_energy = 0.9
		lv.add_child(lamp)
		lamp.global_position = Vector3(154, ROOF - 1.0, z)

	# R1 Candy trap: near floor x 136..150, a 13 m pit 150..163, far floor 163..172
	rect.call(136, 150, -114, -102, PIT, FLOOR, STONE)
	rect.call(163, 172, -114, -102, PIT, FLOOR, STONE)
	ShadowHall.pit(lv, Vector3(156.5, PIT, -108), Vector3(13, 1.5, 12), Vector3(146, 0.6, -108))
	lv.label(Vector3(140, 4.5, -108), "The Cellar: Honey & Wine", 48)
	lv.label(Vector3(144, 3.0, -103), "fill a pot at the hive (E picks up), run and E to throw it far", 26)
	Spout.make(lv, Vector3(139, 3.0, -104), "honey")
	Spout.make(lv, Vector3(139, 3.0, -113), "water")
	PotShelf.make(lv, Vector3(142, FLOOR, -104.5), t)
	PotShelf.make(lv, Vector3(144, FLOOR, -104.5), t)
	PotShelf.make(lv, Vector3(142, FLOOR, -111.5), t)
	Pickup.spawn(lv, "swap", 1, Vector3(137.5, 0.8, -108))
	lv.label(Vector3(137.5, 2.2, -108), "swap charm", 28)
	Pickup.spawn(lv, "candle", 1, Vector3(137.5, 0.8, -111))
	var brazier1 := Brazier.make(lv, Vector3(164.5, FLOOR, -106), true)
	lv.label(Vector3(166, 3.5, -108), "honey + heat = rock candy: only rock candy swaps", 26)
	var blob := Monster.spawn(lv, Vector3(169, 0.6, -109), "blob")
	blob.drop_heart = false
	marks["cellar_candy"] = Vector3(140, 0.6, -108)
	marks["cellar_candy_edge"] = Vector3(148.5, 0.6, -108)
	marks["cellar_candy_blob"] = Vector3(169, 0.6, -109)
	marks["cellar_candy_far"] = Vector3(168, 0.6, -108)
	marks["cellar_candy_brazier"] = brazier1

	# R2 Last call: near floor x 158..172 (east), a 2 m bridge 144..158, far floor 136..144
	rect.call(158, 172, -126, -114, PIT, FLOOR, STONE)
	rect.call(136, 144, -126, -114, PIT, FLOOR, STONE)
	rect.call(144, 158, -121, -119, FLOOR - 0.5, FLOOR, WOOD)
	ShadowHall.pit(lv, Vector3(151, PIT, -120), Vector3(14, 1.5, 12), Vector3(162, 0.6, -120))
	Spout.make(lv, Vector3(170, 3.0, -124.5), "wine")
	Puddle.pool(lv, "water", AABB(Vector3(164, FLOOR, -117.5), Vector3(3, 0.25, 2.5)))
	PotShelf.make(lv, Vector3(168, FLOOR, -117), t)
	PotShelf.make(lv, Vector3(166, FLOOR, -122.5), t)
	lv.label(Vector3(165, 3.5, -120), "wine draws brutes and makes them drunk; water washes it away", 26)
	var brute := Monster.spawn(lv, Vector3(151, 0.9, -120), "brute")
	brute.drop_heart = false
	brute.set_meta("leash", 5.0) # it keeps to its bridge
	marks["cellar_bridge"] = Vector3(169, 0.6, -120)
	marks["cellar_bridge_end"] = Vector3(159.2, 0.6, -120)
	marks["cellar_bridge_mid"] = Vector3(151, 0.9, -120)
	marks["cellar_bridge_far"] = Vector3(140, 0.6, -120)

	# R3 Raft: near floor x 136..148, a dry channel 148..162 (a basin: one pot of water fills it 3 m deep, with a
	# current toward the far bank), far floor 162..172
	rect.call(136, 148, -138, -126, PIT, FLOOR, STONE)
	rect.call(162, 172, -138, -126, PIT, FLOOR, STONE)
	var channel := Basin.make(lv, AABB(Vector3(148, PIT, -138), Vector3(14, 3.0, 12)), Vector3(145, 0.6, -132), Vector3(2.0, 0, 0))
	ShadowHall.pit(lv, Vector3(155, PIT, -132), Vector3(14, 1.0, 12), Vector3(145, 0.6, -132)) # the dry bottom
	Spout.make(lv, Vector3(138, 3.0, -136.5), "water")
	PotShelf.make(lv, Vector3(140, FLOOR, -136.5), t)
	PotShelf.make(lv, Vector3(140, FLOOR, -127.5), t)
	var crate := Crate.make(lv, Vector3(145, FLOOR, -132), t, true)
	lv.label(Vector3(142, 3.5, -132), "one pot of water fills the channel; push the crate in and it floats across", 26)
	marks["cellar_raft"] = Vector3(138, 0.6, -132)
	marks["cellar_raft_push"] = Vector3(142.6, 0.6, -132)
	marks["cellar_raft_far"] = Vector3(166, 0.6, -132)
	marks["cellar_raft_crate"] = crate
	marks["cellar_raft_channel"] = channel

	# R4 Fire door: one floor, a wall at x 152 with a low doorway (z -146..-142, 2.5 m high) over a wine trough
	rect.call(136, 172, -150, -138, PIT, FLOOR, STONE)
	rect.call(151.75, 152.25, -150, -146, FLOOR, ROOF, WALL)
	rect.call(151.75, 152.25, -142, -138, FLOOR, ROOF, WALL)
	rect.call(151.75, 152.25, -146, -142, FLOOR + 2.5, ROOF, WALL)
	var trough := Puddle.pool(lv, "wine", AABB(Vector3(149, FLOOR, -146), Vector3(6, 0.2, 4)))
	trough.ignite.call_deferred()
	var brazier4 := Brazier.make(lv, Vector3(155.5, FLOOR, -147.5), true)
	rect.call(158, 162, -147, -143, FLOOR, FLOOR + 2.0, STONE) # a shelf with a runnel down to the trough
	var runnel := Runnel.make(lv, Vector3(158, FLOOR + 2.0, -145), Vector3(155.5, FLOOR + 0.3, -145), 1.2)
	Spout.make(lv, Vector3(170, 3.0, -148.5), "water")
	PotShelf.make(lv, Vector3(166, FLOOR, -148.5), t)
	PotShelf.make(lv, Vector3(166, FLOOR, -140), t)
	lv.label(Vector3(160, 3.5, -144), "water puts fire out, and wet things won't burn for a while", 26)
	Pickup.spawn(lv, "heart", 1, Vector3(140, 0.8, -144))
	lv.label(Vector3(140, 2.5, -144), "the end of the Cellar", 32)
	marks["cellar_fire"] = Vector3(168, 0.6, -144)
	marks["cellar_fire_near"] = Vector3(157.5, 0.6, -144)
	marks["cellar_fire_far"] = Vector3(146, 0.6, -144)
	marks["cellar_trough"] = trough
	marks["cellar_fire_brazier"] = brazier4
	marks["cellar_runnel"] = runnel

## A wall between two rooms at z, floor to roof (and down into the pits), with a 4 m doorway from x d0 to d1.
static func _cross(rect: Callable, z: float, d0: float, d1: float) -> void:
	if d0 > 136.0:
		rect.call(136, d0, z - 0.25, z + 0.25, PIT, ROOF, STONE.darkened(0.3))
	if d1 < 172.0:
		rect.call(d1, 172, z - 0.25, z + 0.25, PIT, ROOF, STONE.darkened(0.3))
	rect.call(d0, d1, z - 0.25, z + 0.25, FLOOR + 4.0, ROOF, STONE.darkened(0.3))
	rect.call(d0, d1, z - 0.25, z + 0.25, PIT, FLOOR, STONE.darkened(0.3))
