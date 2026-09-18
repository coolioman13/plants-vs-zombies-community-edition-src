class_name Trail
extends RefCounted
## Port of TodLib Trail.

const TRAIL_FLAG_LOOPS := 0
enum { TRACK_WIDTH_OVER_LENGTH, TRACK_WIDTH_OVER_TIME, TRACK_ALPHA_OVER_LENGTH, TRACK_ALPHA_OVER_TIME }

var points: Array[Vector2] = []
var dead := false
var freed := false
var is_attachment := false
var render_order := 0
var trail_age := 0
var definition: Defs.TrailDef
var trail_duration := 0
var color_override := Color.WHITE
var trail_center := Vector2.ZERO
var interp := PackedFloat32Array([0, 0, 0, 0])

func _init() -> void:
	for i in 4:
		interp[i] = Tod.rand_range_float(0.0, 1.0)

func add_point(x: float, y: float) -> void:
	var max_points := clampi(definition.max_points, 2, 20)
	if points.size() > 0:
		var last: Vector2 = points[points.size() - 1]
		if Tod.distance_2d(x, y, last.x, last.y) < definition.min_point_distance:
			return
	if points.size() == max_points:
		points.remove_at(0)
	points.append(Vector2(x, y))

func update() -> void:
	trail_age += 1
	if trail_age >= trail_duration:
		if Tod.test_bit(definition.flags, TRAIL_FLAG_LOOPS):
			trail_age = 0
		else:
			dead = true

func _normal_at(i: int) -> Variant:
	var n := points.size()
	var dir: Vector2
	if i == 0:
		var d := points[1] - points[0]
		dir = Vector2(-d.y, d.x)
	elif i == n - 1:
		var d2 := points[i] - points[i - 1]
		dir = Vector2(-d2.y, d2.x)
	else:
		dir = (points[i + 1] - points[i]).normalized() + (points[i - 1] - points[i]).normalized()
	var mag := dir.length()
	if Tod.approx_equal(mag, 0.0):
		return null
	return dir / mag

func draw(g: Graphics) -> void:
	var n := points.size()
	if dead or n < 2:
		return
	var tv := trail_age / float(trail_duration - 1)
	var tris: Array = []
	var have_prev := false
	var normal_prev := Vector2.ZERO
	for i in n - 1:
		if not have_prev:
			var np = _normal_at(i)
			if np == null:
				continue
			normal_prev = np
			have_prev = true
		var normal_cur := normal_prev
		var normal_next: Vector2
		var nn = _normal_at(i + 1)
		if nn == null:
			normal_next = normal_prev
		else:
			normal_next = nn
			normal_prev = nn
		var u_cur := 1.0 - i / float(n - 1)
		var u_next := 1.0 - (i + 1) / float(n - 1)
		var wl_c := definition.width_over_length.evaluate(u_cur, interp[TRACK_WIDTH_OVER_LENGTH])
		var wl_n := definition.width_over_length.evaluate(u_next, interp[TRACK_WIDTH_OVER_LENGTH])
		var wt := definition.width_over_time.evaluate(tv, interp[TRACK_WIDTH_OVER_TIME])
		var al_c := definition.alpha_over_length.evaluate(u_cur, interp[TRACK_ALPHA_OVER_LENGTH])
		var al_n := definition.alpha_over_length.evaluate(u_next, interp[TRACK_ALPHA_OVER_LENGTH])
		var at := definition.alpha_over_time.evaluate(tv, interp[TRACK_ALPHA_OVER_TIME])
		var c_cur := color_override
		c_cur.a8 = clampi(Tod.round_to_int(al_c * at * color_override.a8), 0, 255)
		var c_next := color_override
		c_next.a8 = clampi(Tod.round_to_int(al_n * at * color_override.a8), 0, 255)
		var pc := points[i]
		var pn := points[i + 1]
		var p0 := trail_center + pc + normal_cur * wl_c * wt
		var p1 := trail_center + pc - normal_cur * wl_c * wt
		var p2 := trail_center + pn + normal_next * wl_n * wt
		var p3 := trail_center + pn - normal_next * wl_n * wt
		tris.append([[p0.x, p0.y, u_cur, 1.0, c_cur], [p1.x, p1.y, u_cur, 0.0, c_cur], [p2.x, p2.y, u_next, 1.0, c_next]])
		tris.append([[p2.x, p2.y, u_next, 1.0, c_next], [p1.x, p1.y, u_cur, 0.0, c_cur], [p3.x, p3.y, u_next, 0.0, c_next]])
	g.draw_triangles_tex(definition.image, tris)
