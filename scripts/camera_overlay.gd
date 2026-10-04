class_name CameraOverlay
extends CanvasLayer
## What the camera draws over the view (CameraRig makes it): the reticle (where the lash goes when you're not
## locked on), arrows at the screen's edge for threats and the lock-on target off screen, and one light
## screen shader: motion blur at speed and on fast pans, and softened edges in combat (the web renderer has no
## real depth of field, so the edges soften instead and the middle, where you and your target are, stays sharp).

var rig: CameraRig
var blur := 0.0 ## radial streaks toward the vanishing point (share of the distance to the middle)
var pan := 0.0 ## sideways streaks while the view turns fast
var soft := 0.0 ## 0..1 softened edges
var arrows: Array = [] ## this frame's off-screen arrows: [screen position, angle, colour]
var _fx: ColorRect
var _mat: ShaderMaterial
var _marks: Marks

const SHADER := """shader_type canvas_item;
uniform sampler2D screen: hint_screen_texture, filter_linear;
uniform float blur = 0.0;
uniform float pan = 0.0;
uniform float soft = 0.0;
void fragment() {
	vec2 uv = SCREEN_UV;
	vec2 d = uv - vec2(0.5);
	float edge = smoothstep(0.2, 0.65, length(d * vec2(1.0, 0.7)));
	vec4 acc = texture(screen, uv);
	float n = 1.0;
	for (int i = 1; i <= 4; i++) {
		float k = float(i) / 4.0;
		acc += texture(screen, uv - d * blur * k * edge - vec2(pan * k, 0.0));
		n += 1.0;
	}
	float r = soft * edge * 0.005;
	if (r > 0.0) {
		acc += texture(screen, uv + vec2(r, 0.0)) + texture(screen, uv - vec2(r, 0.0));
		acc += texture(screen, uv + vec2(0.0, r)) + texture(screen, uv - vec2(0.0, r));
		acc += texture(screen, uv + vec2(r, r) * 0.7) + texture(screen, uv - vec2(r, r) * 0.7);
		n += 6.0;
	}
	COLOR = acc / n;
}
"""

class Marks extends Control:
	var o: CameraOverlay
	func _process(_dt: float) -> void:
		queue_redraw()
	func _draw() -> void:
		var r := o.rig
		var p := r.player
		if p.cam_aim != Vector3.ZERO and (r.looking or p.inventory.equipped("lash")) and not r.cam.is_position_behind(p.cam_aim):
			var sp := r.cam.unproject_position(p.cam_aim)
			var col := Color(1.0, 0.85, 0.3, 0.95) if r.aim_ok else Color(1, 1, 1, 0.55)
			draw_arc(sp, 10.0 if r.aim_ok else 7.0, 0.0, TAU, 24, col, 2.0)
			draw_circle(sp, 2.0, col)
		for a in o.arrows:
			var at: Vector2 = a[0]
			var ang: float = a[1]
			var c: Color = a[2]
			var tip := at + Vector2.from_angle(ang) * 14.0
			var l := at + Vector2.from_angle(ang + 2.5) * 10.0
			var rr := at + Vector2.from_angle(ang - 2.5) * 10.0
			draw_colored_polygon(PackedVector2Array([tip, l, rr]), c)

func _ready() -> void:
	layer = -1 # under the HUD, so the blur never touches the hearts
	_fx = ColorRect.new()
	_fx.set_anchors_preset(Control.PRESET_FULL_RECT)
	_fx.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = SHADER
	_mat = ShaderMaterial.new()
	_mat.shader = sh
	_fx.material = _mat
	_fx.visible = false
	add_child(_fx)
	_marks = Marks.new()
	_marks.o = self
	_marks.set_anchors_preset(Control.PRESET_FULL_RECT)
	_marks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_marks)

func _physics_process(_dt: float) -> void:
	_fx.visible = blur > 0.0005 or pan > 0.0005 or soft > 0.01
	if _fx.visible:
		_mat.set_shader_parameter("blur", blur)
		_mat.set_shader_parameter("pan", pan)
		_mat.set_shader_parameter("soft", soft)
	update_arrows()

## Arrows at the screen's edge for what's off screen: monsters winding up or attacking near you (red) and the
## lock-on target (gold).
func update_arrows() -> void:
	arrows.clear()
	var p := rig.player
	var cam := rig.cam
	var size := rig.get_viewport().get_visible_rect().size
	if size.x < 2.0 or rig.looking:
		return
	var want := []
	if p.target != null and is_instance_valid(p.target):
		want.append([p.target, Color(1.0, 0.85, 0.3, 0.9)])
	for m in rig.get_tree().get_nodes_in_group("monsters"):
		var mn := m as Monster
		if mn == null or mn == p.target or not is_instance_valid(mn) or mn.hp <= 0:
			continue
		if (mn.state == "windup" or mn.state == "attack") and mn.global_position.distance_to(p.global_position) < 25.0:
			want.append([mn, Color(1.0, 0.25, 0.2, 0.9)])
	var mid := size / 2.0
	var half := mid - Vector2(36, 36)
	for w in want:
		var n := w[0] as Node3D
		var at := n.global_position + Vector3.UP * 0.8
		var behind := cam.is_position_behind(at)
		var sp := cam.unproject_position(at)
		if not behind and Rect2(Vector2.ZERO, size).grow(-12.0).has_point(sp):
			continue
		var d := sp - mid
		if behind:
			d = -d
		if d.length() < 1.0:
			d = Vector2(0, 1)
		var k := minf(half.x / maxf(absf(d.x), 0.001), half.y / maxf(absf(d.y), 0.001))
		arrows.append([mid + d * k, d.angle(), w[1]])
