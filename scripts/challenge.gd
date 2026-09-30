class_name Challenge
extends Node3D
## Short challenge rooms, each a floating course far above the world that tests one move combo.
## A door in the moves yard sends you in; the goal (a spinning star) sends you back out beside the door and
## marks it cleared (the door turns gold). Fall off a course and you start it again.
## The rooms:
##   Pogo chain  pound (attack in the air) onto four spike balls in a row to bounce across a 25 m drop
##   Rail run    two downhill rails, each kicking you across a 10 m gap
##   Long jump   three 10 m gaps with 4 m platforms: no runway, so pound, roll out and long-jump

const BASE := 200.0 ## rooms float this high
const STONE := Color(0.62, 0.6, 0.7)
const GOLD := Color(1.0, 0.8, 0.25)

var lv: Node3D
var room := "" ## name
var door_at := Vector3.ZERO
var start := Vector3.ZERO
var goal := Vector3.ZERO
var floor_y := 0.0 ## below this you start over
var cleared := false
var inside := false
var _door_mat: StandardMaterial3D
var _star: MeshInstance3D
var _cool := 0.0

static func build(level: Node3D) -> void:
	var names := ["pogo", "rail", "long"]
	var titles := ["Pogo chain", "Rail run", "Long jump"]
	for i in names.size():
		var c := Challenge.new()
		c.lv = level
		c.room = names[i]
		c.door_at = Vector3(8 + i * 5, 0, -62)
		level.add_child(c)
		c._door(titles[i])
		var o := Vector3(300 + i * 80, BASE, 0)
		match names[i]:
			"pogo":
				c._pogo(o)
			"rail":
				c._rail(o)
			"long":
				c._long(o)
		c.floor_y = o.y - 15.0
		c._goal()
		level.marks["challenge_" + names[i]] = c
	level.marks["challenge_doors"] = Vector3(13, 0.6, -58)

func _rect(x0: float, x1: float, z0: float, z1: float, y0: float, y1: float, col: Color) -> void:
	lv.box(Vector3((x0 + x1) / 2.0, (y0 + y1) / 2.0, (z0 + z1) / 2.0), Vector3(x1 - x0, y1 - y0, z1 - z0), Basis(), col)

func _door(title: String) -> void:
	var frame := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(2.2, 3.2, 0.3)
	frame.mesh = bm
	_door_mat = StandardMaterial3D.new()
	_door_mat.albedo_color = Color(0.5, 0.4, 0.9)
	_door_mat.emission_enabled = true
	_door_mat.emission = Color(0.3, 0.2, 0.8)
	frame.material_override = _door_mat
	add_child(frame)
	frame.global_position = door_at + Vector3.UP * 1.6
	lv.label(door_at + Vector3.UP * 3.8, title, 32)

func _goal() -> void:
	_star = MeshInstance3D.new()
	var sm := PrismMesh.new()
	sm.size = Vector3(0.9, 0.9, 0.2)
	_star.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = GOLD
	m.emission_enabled = true
	m.emission = GOLD
	_star.material_override = m
	add_child(_star)
	_star.global_position = goal + Vector3.UP * 0.8

## Pound onto four spike balls in a row, 5 m apart and 2 m below the ledges, across a 25 m drop.
func _pogo(o: Vector3) -> void:
	_rect(o.x - 3, o.x + 3, o.z - 3, o.z + 3, o.y, o.y + 6, STONE)
	for k in 4:
		Spikes.make(lv, o + Vector3(0, 4, -5.0 - k * 5.0))
	_rect(o.x - 3, o.x + 3, o.z - 28, o.z - 22, o.y, o.y + 6, STONE)
	start = o + Vector3(0, 6.6, 1.5)
	goal = o + Vector3(0, 6.0, -25)

## Downhill rail, kicker, 10 m gap to a platform; again from there.
func _rail(o: Vector3) -> void:
	_rect(o.x - 3, o.x + 3, o.z - 3, o.z + 3, o.y, o.y + 10, STONE)
	Rail.make(lv, PackedVector3Array([o + Vector3(0, 10.3, -3.5), o + Vector3(0, 5.3, -24), o + Vector3(0, 6.3, -28)]))
	_rect(o.x - 3, o.x + 3, o.z - 44, o.z - 38, o.y, o.y + 6, STONE)
	Rail.make(lv, PackedVector3Array([o + Vector3(0, 6.3, -44.5), o + Vector3(0, 1.3, -65), o + Vector3(0, 2.3, -69)]))
	_rect(o.x - 3, o.x + 3, o.z - 85, o.z - 79, o.y, o.y + 2, STONE)
	start = o + Vector3(0, 10.6, 1.5)
	goal = o + Vector3(0, 2.0, -82)

## 4 m platforms with 10 m gaps: too short a run-up for a triple jump.
func _long(o: Vector3) -> void:
	for k in 4:
		var z0 := o.z - k * 14.0
		_rect(o.x - 3, o.x + 3, z0 - 4, z0, o.y, o.y + 4, STONE)
	start = o + Vector3(0, 4.6, -1)
	goal = o + Vector3(0, 4.0, -44)

func _physics_process(dt: float) -> void:
	_star.rotate_y(dt * 2.0)
	_cool = maxf(_cool - dt, 0.0)
	var p: Player = lv.player
	if p == null or _cool > 0.0:
		return
	var here := p.global_position
	if not inside and Vector2(here.x - door_at.x, here.z - door_at.z).length() < 1.2 and absf(here.y - door_at.y - 0.6) < 1.0:
		enter()
	elif inside and here.y < BASE - 60.0:
		inside = false # left some other way (respawn, a warp)
	elif inside:
		if here.distance_to(goal + Vector3.UP * 0.6) < 1.3:
			finish()
		elif here.y < floor_y:
			p.teleport(start) # fell off: from the top

func enter() -> void:
	var p: Player = lv.player
	p.drop_holds()
	p.stow_spider()
	inside = true
	p.teleport(start)
	p.facing = Vector3.FORWARD
	_cool = 0.3

func finish() -> void:
	var p: Player = lv.player
	inside = false
	cleared = true
	_door_mat.albedo_color = GOLD
	_door_mat.emission = GOLD * 0.6
	Hitfx.sparks(get_tree(), p.global_position, 3.0)
	p.teleport(door_at + Vector3(0, 0.6, 2.0))
	_cool = 0.5
