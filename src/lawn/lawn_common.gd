class_name LawnCommon
## Port of LawnCommon + definition accessors.

# Plant definition field indices
const PDEF_SEED := 0
const PDEF_REANIM := 1
const PDEF_PACKET := 2
const PDEF_COST := 3
const PDEF_REFRESH := 4
const PDEF_SUBCLASS := 5
const PDEF_LAUNCH_RATE := 6
const PDEF_NAME := 7
# Zombie definition field indices
const ZDEF_TYPE := 0
const ZDEF_REANIM := 1
const ZDEF_VALUE := 2
const ZDEF_STARTING_LEVEL := 3
const ZDEF_FIRST_ALLOWED_WAVE := 4
const ZDEF_PICK_WEIGHT := 5
const ZDEF_NAME := 6

static func plant_def(seed_type: int) -> Array:
	return LawnDefs.PLANT_DEFS[seed_type]

static func zombie_def(zombie_type: int) -> Array:
	return LawnDefs.ZOMBIE_DEFS[zombie_type]

static func projectile_damage(projectile_type: int) -> int:
	return LawnDefs.PROJECTILE_DEFS[projectile_type][2]

static func mod_in_range(number: int, mod: int, the_range: int = 0) -> bool:
	the_range = absi(the_range)
	for i in range(number - the_range, number + the_range + 1):
		if i % mod == 0:
			return true
	return false

static func grid_in_range(x1: int, y1: int, x2: int, y2: int, range_x: int = 1, range_y: int = 1) -> bool:
	return x1 >= x2 - range_x and x1 <= x2 + range_x and y1 >= y2 - range_y and y1 <= y2 + range_y

static func tile_image_horizontally(g: Graphics, img: PvzImage, px: int, py: int, w: int) -> void:
	while w > 0:
		var iw := mini(w, img.width)
		g.draw_image_src(img, px, py, Rect2(0, 0, iw, img.height))
		px += iw
		w -= iw

static func tile_image_vertically(g: Graphics, img: PvzImage, px: int, py: int, h: int) -> void:
	while h > 0:
		var ih := mini(h, img.height)
		g.draw_image_src(img, px, py, Rect2(0, 0, img.width, ih))
		py += ih
		h -= ih

static func get_current_days_since_2000() -> int:
	var d := Time.get_datetime_dict_from_system()
	var dy: int = d.year - 2000
	var yday := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day}) - Time.get_unix_time_from_datetime_dict({"year": d.year, "month": 1, "day": 1})
	@warning_ignore("integer_division")
	return dy * 365 + (dy - 1) / 400 - (dy - 1) / 100 + (dy - 1) / 4 + int(yday / 86400) + 1

static func get_rect_overlap(r1: Rect2i, r2: Rect2i) -> int:
	var xmax: int
	var rmin: int
	var rmax: int
	if r1.position.x < r2.position.x:
		rmin = r1.position.x + r1.size.x
		rmax = r2.position.x + r2.size.x
		xmax = r2.position.x
	else:
		rmin = r2.position.x + r2.size.x
		rmax = r1.position.x + r1.size.x
		xmax = r1.position.x
	if rmin > xmax and rmin > rmax:
		rmin = rmax
	return rmin - xmax

static func get_circle_rect_overlap(cx: int, cy: int, radius: int, r: Rect2i) -> bool:
	var dx := 0
	var dy := 0
	var in_x := false
	var in_y := false
	if cx < r.position.x:
		dx = r.position.x - cx
	elif cx > r.position.x + r.size.x:
		dx = cx - r.position.x - r.size.x
	else:
		in_x = true
	if cy < r.position.y:
		dy = r.position.y - cy
	elif cy > r.position.y + r.size.y:
		dy = cy - r.position.y - r.size.y
	else:
		in_y = true
	if in_x and in_y:
		return true
	if in_x:
		return dy <= radius
	if in_y:
		return dx <= radius
	return dx * dx + dy * dy <= radius * radius
