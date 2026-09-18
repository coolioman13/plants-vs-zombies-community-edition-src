class_name ReanimatorCache
## Port of ReanimatorCache. The original pre-renders plant / mower / zombie frames into memory images;
## here the same frame is drawn directly, clipped to the bounds the cached image would have had,
## which produces the same output without render-to-texture round trips.

const MARIGOLD_VARIATIONS := [
	Color8(255, 255, 255), Color8(230, 30, 195), Color8(250, 125, 5), Color8(255, 145, 215), Color8(160, 255, 245),
	Color8(230, 30, 30), Color8(5, 130, 255), Color8(195, 55, 235), Color8(235, 210, 255), Color8(255, 245, 55),
	Color8(180, 255, 105),
]

static var _frames := {}

## Custom levels reskin the art these frames were built from, so the cache is dropped when a
## level is installed or removed.
static func clear_cache() -> void:
	_frames.clear()

static func update_reanimation_for_variation(r: Reanimation, variation: int) -> void:
	if variation >= PvZ.VARIATION_MARIGOLD_WHITE and variation <= PvZ.VARIATION_MARIGOLD_LIGHT_GREEN:
		r.get_track_instance("Marigold_petals").track_color = MARIGOLD_VARIATIONS[variation - PvZ.VARIATION_MARIGOLD_WHITE]
		return
	match variation:
		PvZ.VARIATION_IMITATER: r.filter_effect = PvZ.FILTER_EFFECT_WASHED_OUT
		PvZ.VARIATION_IMITATER_LESS: r.filter_effect = PvZ.FILTER_EFFECT_LESS_WASHED_OUT
		PvZ.VARIATION_ZEN_GARDEN: r.set_frames_for_layer("anim_zengarden")
		PvZ.VARIATION_ZEN_GARDEN_WATER: r.set_frames_for_layer("anim_waterplants")
		PvZ.VARIATION_AQUARIUM: r.set_frames_for_layer("anim_idle_aquarium")
		PvZ.VARIATION_SPROUT_NO_FLOWER: r.set_frames_for_layer("anim_idle_noflower")

## A frame is [reanimation, inner_x, inner_y, inner_scale_x, inner_scale_y, inner_color_or_null].
static func _make_frame(reanim_type: int, track: String, variation: int, px: float, py: float, sx: float = 1.0, sy: float = 1.0, col = null) -> Array:
	var r := Reanimation.new()
	r.reanim_type = reanim_type
	r.initialize(0.0, 0.0, ReanimTypes.get_def(reanim_type))
	if track != "" and r.track_exists(track):
		r.set_frames_for_layer(track)
	if reanim_type == PvZ.REANIM_KERNELPULT:
		r.assign_render_group_to_track("Cornpult_butter", Reanimation.RENDER_GROUP_HIDDEN)
	elif reanim_type == PvZ.REANIM_SUNFLOWER:
		r.anim_time = 0.15
	r.assign_render_group_to_track("anim_waterline", Reanimation.RENDER_GROUP_HIDDEN)
	if variation != PvZ.VARIATION_NORMAL:
		update_reanimation_for_variation(r, variation)
	return [r, px, py, sx, sy, col]

## Draws frames as if they were one cached image of size w*h placed at (x, y) scaled by (scale_x, scale_y).
static func _draw_frames(g: Graphics, frames: Array, x: float, y: float, w: float, h: float, scale_x: float, scale_y: float) -> void:
	var cg := g.copy()
	cg.clip_rect(x, y, w * scale_x, h * scale_y)
	var outer := g.color if g.colorize_images else Color.WHITE
	for f in frames:
		var r: Reanimation = f[0]
		var c: Color = outer
		if f[5] != null:
			c = Tod.colors_multiply(c, f[5])
		r.color_override = c
		r.overlay_matrix = Transform2D(Vector2(f[3] * scale_x, 0), Vector2(0, f[4] * scale_y), Vector2(x + f[1] * scale_x, y + f[2] * scale_y))
		r.draw(cg)

static func get_plant_image_size(seed_type: int) -> Rect2i:
	var r := Rect2i(-20, -20, 120, 120)
	if seed_type == PvZ.SEED_TALLNUT:
		r.position.y = -40
		r.size.y += 40
	elif seed_type == PvZ.SEED_MELONPULT or seed_type == PvZ.SEED_WINTERMELON:
		r.position.x = -40
		r.size.x += 40
	elif seed_type == PvZ.SEED_COBCANNON:
		r.size.x += 80
	return r

static func _plant_frames(seed_type: int, variation: int) -> Array:
	var key := "p%d_%d" % [seed_type, variation]
	if _frames.has(key):
		return _frames[key]
	var sz := get_plant_image_size(seed_type)
	var ox := sz.position.x
	var oy := sz.position.y
	var rt: int = LawnCommon.plant_def(seed_type)[LawnCommon.PDEF_REANIM]
	var list: Array = []
	if rt >= 0:
		if seed_type == PvZ.SEED_POTATOMINE:
			list.append(_make_frame(rt, "anim_armed", variation, -int(ox - 12.0), -int(oy - 12.0), 0.85, 0.85))
		elif seed_type == PvZ.SEED_INSTANT_COFFEE:
			list.append(_make_frame(rt, "anim_idle", variation, -int(ox - 12.0), -int(oy - 12.0), 0.8, 0.8))
		elif seed_type == PvZ.SEED_EXPLODE_O_NUT:
			list.append(_make_frame(rt, "anim_idle", variation, -ox, -oy, 1.0, 1.0, Color8(255, 64, 64)))
		else:
			list.append(_make_frame(rt, "anim_idle", variation, -ox, -oy + (5 if seed_type == PvZ.SEED_IMITATER else 0)))
			if seed_type in [PvZ.SEED_PEASHOOTER, PvZ.SEED_SNOWPEA, PvZ.SEED_REPEATER, PvZ.SEED_LEFTPEATER, PvZ.SEED_GATLINGPEA]:
				list.append(_make_frame(rt, "anim_head_idle", variation, -ox, -oy))
			elif seed_type == PvZ.SEED_SPLITPEA:
				list.append(_make_frame(rt, "anim_head_idle", variation, -ox, -oy))
				list.append(_make_frame(rt, "anim_splitpea_idle", variation, -ox, -oy))
			elif seed_type == PvZ.SEED_THREEPEATER:
				list.append(_make_frame(rt, "anim_head_idle1", variation, -ox, -oy))
				list.append(_make_frame(rt, "anim_head_idle3", variation, -ox, -oy))
				list.append(_make_frame(rt, "anim_head_idle2", variation, -ox, -oy))
	_frames[key] = list
	return list

static func draw_cached_plant(g: Graphics, px: float, py: float, seed_type: int, variation: int) -> void:
	var sz := get_plant_image_size(seed_type)
	var frames := _plant_frames(seed_type, variation)
	_draw_frames(g, frames, px + sz.position.x * g.scale_x, py + sz.position.y * g.scale_y, sz.size.x, sz.size.y, g.scale_x, g.scale_y)

static func draw_cached_mower(g: Graphics, px: float, py: float, mower_type: int) -> void:
	var key := "m%d" % mower_type
	if not _frames.has(key):
		var list: Array = []
		match mower_type:
			PvZ.LAWNMOWER_LAWN: list.append(_make_frame(PvZ.REANIM_LAWNMOWER, "anim_normal", PvZ.VARIATION_NORMAL, 10.0, 0.0, 0.85, 0.85))
			PvZ.LAWNMOWER_POOL: list.append(_make_frame(PvZ.REANIM_POOL_CLEANER, "", PvZ.VARIATION_NORMAL, 10.0, 25.0, 0.8, 0.8))
			PvZ.LAWNMOWER_ROOF: list.append(_make_frame(PvZ.REANIM_ROOF_CLEANER, "", PvZ.VARIATION_NORMAL, 10.0, 0.0, 0.85, 0.85))
			PvZ.LAWNMOWER_SUPER_MOWER: list.append(_make_frame(PvZ.REANIM_LAWNMOWER, "anim_tricked", PvZ.VARIATION_NORMAL, 10.0, 0.0, 0.85, 0.85))
		_frames[key] = list
	_draw_frames(g, _frames[key], px - 20.0, py, 90, 100, g.scale_x, g.scale_y)

static func _zombie_frames(zombie_type: int) -> Array:
	var key := "z%d" % zombie_type
	if _frames.has(key):
		return _frames[key]
	var use_type := zombie_type
	if zombie_type == PvZ.ZOMBIE_CACHED_POLEVAULTER_WITH_POLE:
		use_type = PvZ.ZOMBIE_POLEVAULTER
	var rt: int = LawnCommon.zombie_def(use_type)[LawnCommon.ZDEF_REANIM]
	var list: Array = []
	var px := 40.0
	var py := 40.0
	if rt == PvZ.REANIM_ZOMBIE:
		if zombie_type == PvZ.ZOMBIE_FLAG:
			list.append(_make_frame(PvZ.REANIM_FLAG, "Zombie_flag", PvZ.VARIATION_NORMAL, px, py))
		var body := _make_frame(rt, "anim_idle", PvZ.VARIATION_NORMAL, px, py)
		var r: Reanimation = body[0]
		# DrawReanimatorFrame hides anim_waterline, but the cached zombie builds its reanimation by hand.
		r.assign_render_group_to_track("anim_waterline", Reanimation.RENDER_GROUP_NORMAL)
		Zombie.setup_reanim_layers(r, use_type)
		if zombie_type == PvZ.ZOMBIE_DOOR:
			r.assign_render_group_to_track("anim_screendoor", Reanimation.RENDER_GROUP_NORMAL)
		list.append(body)
	elif rt == PvZ.REANIM_BOSS:
		list.append(_make_frame(rt, "anim_head_idle", PvZ.VARIATION_NORMAL, -524.0, -88.0))
		list.append(_make_frame(PvZ.REANIM_BOSS_DRIVER, "anim_idle", PvZ.VARIATION_NORMAL, 46.0, 22.0))
		var head2 := _make_frame(rt, "anim_head_idle", PvZ.VARIATION_NORMAL, -524.0, -88.0)
		for t in ["boss_body1", "boss_neck", "boss_head2"]:
			head2[0].assign_render_group_to_track(t, Reanimation.RENDER_GROUP_HIDDEN)
		list.append(head2)
	elif rt == PvZ.REANIM_GARGANTUAR and zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR:
		var f1 := _make_frame(rt, "anim_idle", PvZ.VARIATION_NORMAL, px, py)
		Zombie.setup_reanim_layers(f1[0], use_type)
		list.append(f1)
		var f2 := _make_frame(rt, "anim_idle", PvZ.VARIATION_NORMAL, px, py)
		Zombie.setup_reanim_layers(f2[0], use_type)
		f2[0].set_image_override("anim_head1", Res.get_image("IMAGE_REANIM_ZOMBIE_GARGANTUAR_HEAD_REDEYE"))
		list.append(f2)
	else:
		var track := "anim_idle"
		if zombie_type == PvZ.ZOMBIE_POGO:
			track = "anim_pogo"
		elif zombie_type == PvZ.ZOMBIE_POLEVAULTER:
			track = "anim_walk"
		elif zombie_type == PvZ.ZOMBIE_GARGANTUAR:
			py = 60.0
		list.append(_make_frame(rt, track, PvZ.VARIATION_NORMAL, px, py))
	_frames[key] = list
	return list

static func draw_cached_zombie(g: Graphics, px: float, py: float, zombie_type: int) -> void:
	_draw_frames(g, _zombie_frames(zombie_type), px, py, 200, 210, g.scale_x, g.scale_y)
