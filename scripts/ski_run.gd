class_name SkiRun
extends Node3D
## The ski run (jovi, 2026-10-04): a practice mountain west of everything (x -230..-170, z -220 down to about
## 400), floating on its own. Skiing is the shield surf: hold guard on snow to drop in. One long run, top to
## bottom, a station per idea (marks and warps ski_<name>):
##   start     flat top, the poleaxe & shield to pick up
##   gates     15°: four slalom gates (through adds speed, a miss costs it). Weave to fill the carve meter.
##   trees     18°: trunks in the lane; clip one and you stumble
##   boost     a boost pad on a flat, then two tilted (off-camber) stretches, one each way: carve against the tilt
##   gap       a 20° tuck run to a 10 m rock gap: pop a jump at the lip
##   kicker    a ramp up, then a 25° landing slope (land on the downslope: a boost)
##   logs      12°: a log to hop, a duck bar to tuck under, another log
##   ice       a sheet of ice (no steering, no brakes), then a crosswind to carve into
##   rail      a fallen-trunk grind rail down the left of a 12° slope
##   cliff     a 7 m drop onto a 30° slope (it keeps your speed), then a runout
##   launch    a launch pad over a 14 m gap onto a landing slope
##   fork      a ridge splits the lane: left is fast with a snow bridge (cross it fast), right has gates and monsters
##   finish    the flat bottom with a lash post: lash it skiing and swing round the hairpin
## Fall off (a gap, a cliff, the launch) and you're put back at the last station you reached.

const X := -200.0
const W := 20.0
const SNOW := Color(0.93, 0.95, 1.0)
const ICE := Color(0.62, 0.82, 1.0)
const ROCK := Color(0.5, 0.48, 0.52)
const TOP := Vector3(X, 170.0, -220.0) ## the top of the run

var lv: Node3D
var z := TOP.z
var y := TOP.y
var stations: Array = [] ## [z, respawn point], top to bottom
var profile: Array = [] ## [z0, z1, y0, y1] of every snow piece, to tell how far below the run you've fallen
var _reached := 0

static func build(level: Node3D) -> SkiRun:
	var r := SkiRun.new()
	r.lv = level
	level.add_child(r)
	r._build()
	return r

## Height of the run's surface down the middle at this z (NAN off the run).
func surface_at(at_z: float) -> float:
	for p in profile:
		if at_z >= p[0] and at_z <= p[1]:
			return lerpf(p[2], p[3], (at_z - p[0]) / maxf(p[1] - p[0], 0.01))
	return NAN

## A straight piece of run, len metres along z, falling at deg (negative rises). Banked by bank degrees
## (positive: the right side, +x, is higher). Walls along both sides unless walls is false.
func seg(len_: float, deg: float, kind := "snow", x := X, w := W, bank := 0.0, walls := true) -> StaticBody3D:
	var a := deg_to_rad(deg)
	var dy := len_ * tan(a)
	var b := _basis(deg, bank)
	var n := b * Vector3.UP
	var mid := Vector3(x, y - dy / 2.0, z + len_ / 2.0)
	var length := sqrt(len_ * len_ + dy * dy)
	var body: StaticBody3D = lv.box(mid - n * 0.5, Vector3(w, 1, length + 0.3), b, ICE if kind == "ice" else SNOW)
	body.add_to_group(kind)
	if walls:
		for s in [-1.0, 1.0]:
			lv.box(mid + b * Vector3(s * (w / 2.0 + 0.5), 2.0, 0), Vector3(1, 5, length + 0.3), b, ROCK)
	profile.append([z, z + len_, y, y - dy])
	z += len_
	y -= dy
	return body

func _basis(deg: float, bank := 0.0) -> Basis:
	var b := Basis(Vector3.RIGHT, deg_to_rad(deg))
	if bank != 0.0:
		b = b * Basis(Vector3.BACK, deg_to_rad(bank))
	return b

## Skip over open air: a gap len long whose far side is drop lower.
func gap(len_: float, drop: float) -> void:
	z += len_
	y -= drop

## A station: its mark, warp spot and respawn point, a little way down from here.
func station(name: String, text: String, dx := 0.0) -> void:
	var at := Vector3(X + dx, y + 0.8, z + 2.0)
	lv.marks["ski_" + name] = at
	stations.append([z, at])
	lv.label(Vector3(X, y + 4.5, z + 1.0), text, 40)

## A spot on the current piece's surface: dz metres down it, dx across, at the given slope.
func on_slope(dz: float, dx: float, deg: float) -> Vector3:
	return Vector3(X + dx, y - dz * tan(deg_to_rad(deg)), z + dz)

func tree(at: Vector3) -> void:
	var trunk := StaticBody3D.new()
	var c := CollisionShape3D.new()
	var cs := CylinderShape3D.new()
	cs.radius = 0.45
	cs.height = 6.0
	c.shape = cs
	trunk.add_child(c)
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.4
	cm.bottom_radius = 0.45
	cm.height = 6.0
	mi.mesh = cm
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.28, 0.18)
	mi.material_override = wood
	trunk.add_child(mi)
	var crown := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 1.8
	cone.height = 4.0
	crown.mesh = cone
	var green := StandardMaterial3D.new()
	green.albedo_color = Color(0.18, 0.42, 0.28)
	crown.material_override = green
	crown.position.y = 3.5
	trunk.add_child(crown)
	trunk.add_to_group("ski_stumble")
	lv.add_child(trunk)
	trunk.global_position = at + Vector3.UP * 2.5

## A log across the lane (dz down the current piece of slope deg): hop it.
func log_across(dz: float, deg: float) -> void:
	var b := _basis(deg)
	var at := on_slope(dz, 0, deg)
	var l: StaticBody3D = lv.box(at + b * Vector3(0, 0.45, 0), Vector3(W - 0.2, 0.9, 0.8), b, Color(0.45, 0.3, 0.2))
	l.add_to_group("ski_stumble")

## A duck bar across the lane: its underside 0.55 m over the snow. Tucked you pass under it (it's on layer 7,
## which a tuck leaves out); upright you clip it.
func duck_bar(dz: float, deg: float) -> void:
	var b := _basis(deg)
	var at := on_slope(dz, 0, deg)
	var bar: StaticBody3D = lv.box(at + b * Vector3(0, 0.55 + 0.35, 0), Vector3(W - 0.2, 0.7, 0.5), b, Color(0.85, 0.35, 0.2))
	bar.collision_layer = 1 << 6
	bar.add_to_group("ski_stumble")
	for s in [-1.0, 1.0]:
		lv.box(at + b * Vector3(s * (W / 2.0 - 0.3), 1.2, 0), Vector3(0.4, 2.4, 0.4), b, ROCK)

func post(at: Vector3) -> StaticBody3D:
	var p: StaticBody3D = lv.box(at + Vector3.UP * 1.5, Vector3(0.6, 3.0, 0.6), Basis(), Color(0.5, 0.35, 0.25))
	p.add_to_group("lash_posts")
	return p

func _build() -> void:
	var m: Dictionary = lv.marks
	# start: a flat top with the shield
	seg(16, 0)
	z -= 16
	station("start", "Ski run: hold guard (C) on snow to ski.\nStick sideways steers, forward tucks, back brakes.")
	Pickup.spawn(lv, "poleaxe", 1, Vector3(X + 3, y + 0.8, z + 4))
	z += 16
	m["ski_top"] = TOP

	# gates: weave through four slalom gates down 15°
	station("gates", "Gates: through for speed, a miss costs it.\nHold a turn, then let go: the carve pays out.")
	for k in 4:
		var dx := -4.0 if k % 2 == 0 else 4.0
		var c := on_slope(12.0 + k * 14.0, dx, 15.0)
		SkiGate.make(lv, c + Vector3(-2.5, 0, 0), c + Vector3(2.5, 0, 0), k % 2 == 0)
	m["ski_gate_first"] = on_slope(12.0, -4.0, 15.0)
	seg(70, 15)

	# trees: a slalom between trunks down 18°
	station("trees", "Trees: clip one and you stumble.")
	var trees := [[10, -5], [16, 4], [23, -2], [30, 6], [36, -6], [42, 1]]
	for tr in trees:
		tree(on_slope(tr[0], tr[1], 18.0))
	m["ski_tree_line"] = on_slope(10.0, -5.0, 18.0)
	seg(48, 18)

	# boost: a boost pad on a flat, then banked bends one way and the other (tilts)
	station("boost", "Boost pad, then tilted snow: carve against the tilt.")
	Pad.make(lv, "boost", Vector3(X, y, z + 6), Vector3.BACK, Vector3(6, 1, 3))
	seg(14, 0)
	m["ski_bank"] = Vector3(X, y + 0.8, z + 1)
	seg(28, 10, "snow", X, W, 15.0)
	seg(28, 10, "snow", X, W, -15.0)

	# gap: tuck down 20°, pop at the lip, clear the 10 m rock gap
	station("gap", "Tuck (stick forward) and jump right at the lip:\na 10 m gap.")
	seg(30, 20)
	m["ski_gap_lip_z"] = z
	m["ski_gap_lip_y"] = y
	gap(10, 1.5)
	m["ski_gap_far_z"] = z
	seg(26, 20)

	# kicker: a ramp up, then a steep landing slope (a big drop onto a downslope pays out)
	station("kicker", "Kicker: land on the downslope for a boost.")
	seg(16, 14)
	seg(5, -14)
	m["ski_kicker_lip_z"] = z
	gap(6, 1.0)
	seg(30, 25)
	seg(10, 8)

	# logs: hop a log, tuck under a duck bar, hop another
	station("logs", "Hop the logs. Tuck under the bar.")
	log_across(10, 12)
	duck_bar(26, 12)
	log_across(42, 12)
	m["ski_duck_z"] = on_slope(26, 0, 12).z
	m["ski_duck"] = on_slope(12, 0, 12) + Vector3.UP * 0.6
	seg(56, 12)

	# ice: no steering and no brakes; then a crosswind to carve into
	station("ice", "Ice: line up first, you can't steer on it.\nThen a crosswind.")
	seg(8, 10)
	m["ski_ice"] = Vector3(X, y + 0.6, z + 2)
	seg(18, 10, "ice")
	seg(4, 10)
	var wind_c := on_slope(14, 0, 10)
	SkiWind.make(lv, wind_c + Vector3.UP * 1.5, Vector3(W, 4, 26), Vector3(9, 0, 0), _basis(10))
	m["ski_wind"] = on_slope(1, 0, 10) + Vector3.UP * 0.6
	seg(28, 10)

	# rail: a fallen trunk down the left of the slope to grind
	station("rail", "Grind the fallen trunk (land on it).")
	var r0 := on_slope(4, -6, 12) + Vector3.UP * 0.7
	var r1 := on_slope(36, -6, 12) + Vector3.UP * 0.7
	Rail.make(lv, PackedVector3Array([r0, r1]))
	m["ski_rail_a"] = r0
	seg(42, 12)

	# cliff: a 7 m drop onto a 30° slope, then a runout
	station("cliff", "Cliff: a 7 m drop onto a steep slope keeps your speed.")
	seg(8, 0)
	m["ski_cliff_lip_z"] = z
	gap(1, 7.0)
	seg(22, 30)
	seg(24, 12)

	# launch: a launch pad over a 14 m gap onto a landing slope
	station("launch", "Launch pad over the gap.")
	seg(12, 0)
	Pad.make(lv, "launch", Vector3(X, y, z - 4), Vector3(0, 13, 22), Vector3(W - 2, 1, 3))
	m["ski_launch_pad"] = Vector3(X, y + 0.6, z - 4)
	m["ski_launch_lip_z"] = z
	gap(14, 3.0)
	seg(28, 20)
	seg(10, 6)

	# fork: a ridge splits the lane. Left: fast, over a snow bridge you must cross fast. Right: gates and monsters.
	station("fork", "Fork: left is fast over a snow bridge (don't stop on it).\nRight has gates and monsters.", -5.5)
	var z0 := z
	var y0 := y
	var deg := 14.0
	var lx := X - 5.5
	var rx := X + 5.5
	# the ridge
	lv.box(Vector3(X, y0 - 25.0 * tan(deg_to_rad(deg)) + 2.0, z0 + 25.0), Vector3(1.0, 8.0, 50.0), _basis(deg), ROCK)
	# left lane: snow, a hole bridged by snow, snow
	seg(16, deg, "snow", lx, 9.0)
	m["ski_bridge_z"] = z
	var bridge_top := Vector3(lx, y - 4.0 * tan(deg_to_rad(deg)), z + 4.0)
	SnowBridge.make(lv, bridge_top, Vector3(9.0, 0.4, 8.3), _basis(deg))
	m["ski_bridge"] = bridge_top
	profile.append([z, z + 8.0, y, y - 8.0 * tan(deg_to_rad(deg))])
	z += 8.0
	y -= 8.0 * tan(deg_to_rad(deg))
	seg(26, deg, "snow", lx, 9.0)
	# right lane, from the same top
	var z_end := z
	var y_end := y
	z = z0
	y = y0
	m["ski_fork_right"] = on_slope(2, 5.5, deg) + Vector3.UP * 0.6
	for k in 2:
		var c := on_slope(12.0 + k * 18.0, 5.5 + (-1.5 if k == 0 else 1.5), deg)
		SkiGate.make(lv, c + Vector3(-2.0, 0, 0), c + Vector3(2.0, 0, 0), k == 0)
	var monsters := []
	for k in 3:
		monsters.append(["blob", false, on_slope(20.0 + k * 9.0, 5.5 + (k - 1) * 2.5, deg) + Vector3.UP * 0.7])
	CombatYard.station(lv, on_slope(25, 5.5, deg), monsters)
	CombatYard.station(lv, on_slope(30, 12.0, deg), [["archer", false, on_slope(30, 12.5, deg) + Vector3.UP * 6.5]])
	lv.box(on_slope(30, 12.5, deg) + Vector3.UP * 3.0, Vector3(3, 6, 3), Basis(), ROCK) # the archer's perch
	seg(50, deg, "snow", rx, 9.0)
	z = z_end
	y = y_end

	# finish: the flat bottom, with a post to lash and swing round
	station("finish", "Lash the post while skiing to swing round it.")
	seg(14, 6)
	seg(40, 0, "snow", X, 40.0)
	z -= 40
	var p := post(Vector3(X + 6, y, z + 20))
	m["ski_post"] = p.global_position
	m["ski_post_run"] = Vector3(X - 2, y + 0.6, z + 2)
	z += 40
	lv.label(Vector3(X, y + 5, z - 4), "Finish", 64)

func _physics_process(_dt: float) -> void:
	var ps := get_tree().get_nodes_in_group("player")
	if ps.is_empty():
		return
	var p := ps[0] as Player
	var at := p.global_position
	if at.x < X - 40.0 or at.x > X + 40.0 or at.z < TOP.z - 10.0 or at.z > z + 10.0:
		return
	_reached = 0
	for i in stations.size():
		if at.z >= float(stations[i][0]):
			_reached = i
	var s := surface_at(at.z)
	if is_nan(s):
		# over a gap: measure from the nearest piece
		var best := INF
		for q in profile:
			var d := minf(absf(at.z - float(q[0])), absf(at.z - float(q[1])))
			if d < best:
				best = d
				s = minf(float(q[2]), float(q[3]))
	if at.y < s - 12.0:
		p.teleport(stations[_reached][1])
		p.surfing = false
