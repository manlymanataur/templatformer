class_name CamFrame
extends Node3D
## A doorway, arch or chimney mouth the camera frames you through (frame within a frame, CameraRig): while you're
## just past it (within depth beyond it, inside its opening) the camera stays on the near side looking through
## it, so the opening's edges frame you.

var size := Vector2(4, 4) ## the opening's width and height
var depth := 10.0 ## how far past it you can be
var reach := 3.0 ## how far outside it the camera waits
var two_way := false ## a doorway: the camera keeps to whichever side it's on
var axis := Vector3.BACK ## one way: the side the camera waits on; two way: either side of this

## A frame centred at `at` whose opening faces `out` (one way: the camera waits on that side).
static func make(parent: Node, at: Vector3, opening: Vector2, out: Vector3, two := false, deep := 10.0) -> CamFrame:
	var f := CamFrame.new()
	f.size = opening
	f.axis = out.normalized()
	f.two_way = two
	f.depth = deep
	parent.add_child(f)
	f.global_position = at
	f.add_to_group("cam_frames")
	return f

## The direction from the frame toward the side the camera waits on.
func out_dir(cam_at: Vector3) -> Vector3:
	if not two_way:
		return axis
	return axis if (cam_at - global_position).dot(axis) >= 0.0 else -axis
