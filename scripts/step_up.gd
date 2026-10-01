class_name StepUp
extends RefCounted
## Walking over small bumps and ridges (jovi: they should be walk-over-able). A body running on the ground into
## a ledge no taller than `height` is lifted onto it, without a jump. Called just before move_and_slide.
## How it works: the body's next step forward would hit something steep; from `height` higher the same step
## (at least 0.6 foot long) is clear; and coming back down from there it lands on walkable floor. Then the body
## is raised to that floor's height and move_and_slide carries it on as usual. Slopes don't need it (they're
## floors), and anything taller than `height` (every real ledge is 2 m or more) is still a wall.

## Lift `body` onto a step ahead of its horizontal velocity if there is one. Returns how far it was raised (0 if not).
## skip_group: what you mustn't step up onto (monsters, the player).
## foot: how far below the body's origin its bottom is (a sphere's radius).
static func try(body: CharacterBody3D, dt: float, height: float, foot: float, skip_group := "hurtable") -> float:
	var probe := foot * 0.6
	var hv := Vector3(body.velocity.x, 0, body.velocity.z)
	if hv.length() < 0.1 or height <= 0.0:
		return 0.0
	var step := hv.normalized() * maxf(hv.length() * dt, probe)
	var from := body.global_transform
	var col := KinematicCollision3D.new()
	if not body.test_move(from, step, col):
		return 0.0 # nothing in the way
	if col.get_normal().y > cos(body.floor_max_angle):
		return 0.0 # a walkable slope: plain movement handles it
	var c := col.get_collider()
	if c is Node and (c as Node).is_in_group(skip_group):
		return 0.0
	var up := Vector3.UP * height
	if body.test_move(from, up):
		return 0.0 # no headroom
	var raised := from.translated(up)
	if body.test_move(raised, step):
		return 0.0 # still blocked up there: a wall, not a step
	var ahead := raised.translated(step)
	var down := KinematicCollision3D.new()
	if not body.test_move(ahead, -up, down):
		return 0.0 # nothing to stand on (it was a thin rail or a gap)
	if down.get_normal().y < cos(body.floor_max_angle):
		return 0.0
	var dc := down.get_collider()
	if dc is Node and (dc as Node).is_in_group(skip_group):
		return 0.0
	# lift the bottom just over the step's top (not only to where the probe touched its corner, which would
	# leave the edge to act as a ramp and kick you into the air)
	var rise := down.get_position().y - (body.global_position.y - foot) + 0.02
	if rise < 0.04 or rise > height + 0.02:
		return 0.0
	body.global_position.y += rise
	return rise
