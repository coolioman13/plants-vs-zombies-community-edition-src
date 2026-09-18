class_name Tod
## Port of TodCommon: curves, random helpers, color math and matrix helpers.

const SECONDS_PER_UPDATE := 0.01
const DEFAULT_FIELD_PLACEHOLDER := -10000.0
const FLT_EPSILON := 1.192092896e-07

enum { CURVE_CONSTANT, CURVE_LINEAR, CURVE_EASE_IN, CURVE_EASE_OUT, CURVE_EASE_IN_OUT, CURVE_EASE_IN_OUT_WEAK,
	CURVE_FAST_IN_OUT, CURVE_FAST_IN_OUT_WEAK, CURVE_WEAK_FAST_IN_OUT, CURVE_BOUNCE, CURVE_BOUNCE_FAST_MIDDLE,
	CURVE_BOUNCE_SLOW_MIDDLE, CURVE_SIN_WAVE, CURVE_EASE_SIN_WAVE }

static var rng := RandomNumberGenerator.new()

# ---------------------------------------------------------------- random
## Sexy::Rand(int): 0..n-1
static func rand_int(n: int) -> int:
	if n <= 0:
		return 0
	return rng.randi() % n

## Sexy::Rand(float): [0, n)
static func rand_float(n: float) -> float:
	return rng.randf() * n

static func rand_range_int(lo: int, hi: int) -> int:
	return rand_int(hi - lo + 1) + lo

static func rand_range_float(lo: float, hi: float) -> float:
	return rand_float(hi - lo) + lo

static func pick_from_array(arr: Array) -> Variant:
	return arr[rand_int(arr.size())]

## arr: Array of [item, weight]
static func pick_from_weighted_array(arr: Array) -> Variant:
	var total := 0
	for e in arr:
		total += e[1]
	if total <= 0:
		return null
	var r := rand_int(total)
	for e in arr:
		r -= e[1]
		if r < 0:
			return e[0]
	return null

## arr: Array of Dictionary {x, y, weight}; returns the chosen dictionary
static func pick_from_weighted_grid_array(arr: Array) -> Variant:
	var total := 0
	for e in arr:
		total += e.weight
	if total <= 0:
		return null
	var r := rand_int(total)
	for e in arr:
		r -= e.weight
		if r < 0:
			return e
	return null

static func calc_smooth_weight(weight: float, last_picked: float, second_last_picked: float) -> float:
	if weight < 1e-6:
		return 0.0
	var exp1 := 1.0 / weight
	var exp2 := exp1 * 2.0
	var adv1 := last_picked + 1.0 - exp1
	var adv2 := second_last_picked + 1.0 - exp2
	var f1 := 1.0 + adv1 / exp1 * 2.0
	var f2 := 1.0 + adv2 / exp2 * 2.0
	return weight * clampf(f1 * 0.75 + f2 * 0.25, 0.01, 100.0)

## arr: Array of Dictionary {item, weight, last, second_last}
static func pick_from_smooth_array(arr: Array) -> int:
	var total := 0.0
	for e in arr:
		total += e.weight
	var norm := 1.0 / total
	var total_adj := 0.0
	for e in arr:
		total_adj += calc_smooth_weight(e.weight * norm, e.last, e.second_last)
	var r := rand_float(total_adj)
	var acc := 0.0
	var k := 0
	while k < arr.size() - 1:
		acc += calc_smooth_weight(arr[k].weight * norm, arr[k].last, arr[k].second_last)
		if r <= acc:
			break
		k += 1
	update_smooth_array_pick(arr, k)
	return arr[k].item

static func update_smooth_array_pick(arr: Array, pick: int) -> void:
	for e in arr:
		if e.weight > 0.0:
			e.last += 1.0
			e.second_last += 1.0
	arr[pick].second_last = arr[pick].last
	arr[pick].last = 0.0

# ---------------------------------------------------------------- curves
static func curve_quad(t: float) -> float: return t * t
static func curve_inv_quad(t: float) -> float: return 2.0 * t - t * t
static func curve_s(t: float) -> float: return 3.0 * t * t - 2.0 * t * t * t
static func curve_bounce(t: float) -> float: return 1.0 - absf(2.0 * t - 1.0)

static func curve_inv_quad_s(t: float) -> float:
	if t <= 0.5:
		return curve_inv_quad(t * 2.0) * 0.5
	return curve_quad((t - 0.5) * 2.0) * 0.5 + 0.5

static func curve_evaluate(t: float, start: float, end: float, curve: int) -> float:
	var w := 0.0
	match curve:
		CURVE_CONSTANT: w = 0.0
		CURVE_LINEAR: w = t
		CURVE_EASE_IN: w = curve_quad(t)
		CURVE_EASE_OUT: w = curve_inv_quad(t)
		CURVE_EASE_IN_OUT: w = curve_s(curve_s(t))
		CURVE_EASE_IN_OUT_WEAK: w = curve_s(t)
		CURVE_FAST_IN_OUT: w = curve_inv_quad_s(curve_inv_quad_s(t))
		CURVE_FAST_IN_OUT_WEAK: w = curve_inv_quad_s(t)
		CURVE_BOUNCE: w = curve_bounce(t)
		CURVE_BOUNCE_FAST_MIDDLE: w = curve_quad(curve_bounce(t))
		CURVE_BOUNCE_SLOW_MIDDLE: w = curve_inv_quad(curve_bounce(t))
		CURVE_SIN_WAVE: w = sin(2.0 * PI * t)
		CURVE_EASE_SIN_WAVE: w = sin(2.0 * PI * curve_s(t))
	return (end - start) * w + start

static func curve_evaluate_clamped(t: float, start: float, end: float, curve: int) -> float:
	if t <= 0.0:
		return start
	if t >= 1.0:
		if curve == CURVE_BOUNCE or curve == CURVE_BOUNCE_FAST_MIDDLE or curve == CURVE_BOUNCE_SLOW_MIDDLE \
				or curve == CURVE_SIN_WAVE or curve == CURVE_EASE_SIN_WAVE:
			return start
		return end
	return curve_evaluate(t, start, end, curve)

static func animate_curve_float(time_start: int, time_end: int, age: int, pos_start: float, pos_end: float, curve: int) -> float:
	var w := float(age - time_start) / float(time_end - time_start)
	return curve_evaluate_clamped(w, pos_start, pos_end, curve)

static func animate_curve_float_time(time_start: float, time_end: float, age: float, pos_start: float, pos_end: float, curve: int) -> float:
	var w := (age - time_start) / (time_end - time_start)
	return curve_evaluate_clamped(w, pos_start, pos_end, curve)

static func animate_curve(time_start: int, time_end: int, age: int, pos_start: int, pos_end: int, curve: int) -> int:
	return round_to_int(animate_curve_float(time_start, time_end, age, pos_start, pos_end, curve))

# ---------------------------------------------------------------- math
static func round_to_int(v: float) -> int:
	return int(v + 0.5) if v > 0.0 else int(v - 0.5)

static func approx_equal(a: float, b: float) -> bool:
	return absf(a - b) < FLT_EPSILON

static func distance_2d(x1: float, y1: float, x2: float, y2: float) -> float:
	return sqrt((x2 - x1) * (x2 - x1) + (y2 - y1) * (y2 - y1))

static func deg_to_rad_f(d: float) -> float:
	return d * 0.017453292

static func rad_to_deg_f(r: float) -> float:
	return r * 57.29578

static func test_bit(v: int, idx: int) -> bool:
	return (v & (1 << idx)) != 0

static func set_bit(v: int, idx: int, on: bool) -> int:
	return (v | (1 << idx)) if on else (v & ~(1 << idx))

## C integer division truncating toward zero
static func idiv(a: int, b: int) -> int:
	@warning_ignore("integer_division")
	return a / b

# ---------------------------------------------------------------- colors (0..255 ints like Sexy::Color)
static func color_component_multiply(a: int, b: int) -> int:
	return clampi(idiv(a * b, 255), 0, 255)

## Colors are Color objects in 0..1 space; multiply matches ColorsMultiply rounding closely.
static func colors_multiply(a: Color, b: Color) -> Color:
	return Color8(
		color_component_multiply(a.r8, b.r8), color_component_multiply(a.g8, b.g8),
		color_component_multiply(a.b8, b.b8), color_component_multiply(a.a8, b.a8))

static func color_add(a: Color, b: Color) -> Color:
	return Color8(clampi(a.r8 + b.r8, 0, 255), clampi(a.g8 + b.g8, 0, 255), clampi(a.b8 + b.b8, 0, 255), clampi(a.a8 + b.a8, 0, 255))

static func rgba(r: int, g: int, b: int, a: int = 255) -> Color:
	return Color8(clampi(r, 0, 255), clampi(g, 0, 255), clampi(b, 0, 255), clampi(a, 0, 255))

static func get_flashing_color(counter: int, flash_time: int) -> Color:
	var age := counter % flash_time
	var inf := idiv(flash_time, 2)
	var grey := clampi(55 + idiv(200 * absi(inf - age), inf), 0, 255)
	return Color8(grey, grey, grey, 255)

# ---------------------------------------------------------------- matrices
## PopCap SexyMatrix3 (m00 m01 m02 / m10 m11 m12) maps to Transform2D(x=(m00,m10), y=(m01,m11), origin=(m02,m12)).
static func scale_rotate_matrix(x: float, y: float, rad: float, sx: float, sy: float) -> Transform2D:
	return Transform2D(Vector2(cos(rad) * sx, -sin(rad) * sx), Vector2(sin(rad) * sy, cos(rad) * sy), Vector2(x, y))

static func scale_matrix(x: float, y: float, sx: float, sy: float) -> Transform2D:
	return Transform2D(Vector2(sx, 0), Vector2(0, sy), Vector2(x, y))

static func is_point_in_polygon(points: Array, p: Vector2) -> bool:
	var n := points.size()
	for i in n:
		var cur: Vector2 = points[i]
		var nex: Vector2 = points[0 if i == n - 1 else i + 1]
		var d := nex - cur
		var u := Vector2(-d.y, d.x)
		if u.dot(p - cur) < 0:
			return false
	return true

static func replace_string(text: String, find: String, sub: String) -> String:
	var a := TodStrings.translate(text)
	var pos := a.find(find)
	if pos != -1:
		a = a.substr(0, pos) + TodStrings.translate(sub) + a.substr(pos + find.length())
	return a

static func replace_number_string(text: String, find: String, num: int) -> String:
	var a := TodStrings.translate(text)
	var pos := a.find(find)
	if pos != -1:
		a = a.substr(0, pos) + str(num) + a.substr(pos + find.length())
	return a
