class_name Board
extends BoardInput
## Board part 4: rendering (render list sorted by z, backdrop, UI, fog, ice, progress meter...).

enum {
	RENDER_ITEM_PLANT, RENDER_ITEM_PLANT_OVERLAY, RENDER_ITEM_PLANT_MAGNET_ITEMS, RENDER_ITEM_MOWER, RENDER_ITEM_ZOMBIE,
	RENDER_ITEM_ZOMBIE_SHADOW, RENDER_ITEM_ZOMBIE_BUNGEE_TARGET, RENDER_ITEM_BOSS_PART, RENDER_ITEM_COIN, RENDER_ITEM_PROJECTILE,
	RENDER_ITEM_PROJECTILE_SHADOW, RENDER_ITEM_CURSOR_PREVIEW, RENDER_ITEM_GRID_ITEM, RENDER_ITEM_GRID_ITEM_OVERLAY, RENDER_ITEM_ICE,
	RENDER_ITEM_PARTICLE, RENDER_ITEM_REANIMATION, RENDER_ITEM_COIN_BANK, RENDER_ITEM_BACKDROP, RENDER_ITEM_DOOR_MASK,
	RENDER_ITEM_BOTTOM_UI, RENDER_ITEM_TOP_UI, RENDER_ITEM_BUSH, RENDER_ITEM_COVER, RENDER_ITEM_FOG, RENDER_ITEM_STORM,
	RENDER_ITEM_SCREEN_FADE, RENDER_ITEM_HEALTHBAR_ZOMBIE, RENDER_ITEM_HEALTHBAR_PLANT,
}

var coin_bank_x := 0
var coin_bank_y := 0

# Render items are [z, seq, type, obj, extra]; seq keeps the sort stable like the pointer tiebreak in the original.
var _render_list: Array = []
## Sort keys: render order in the high bits, insertion index in the low 20 bits. A native sort of these gives the
## same stable order as comparing [order, index] pairs, much faster than sort_custom on big waves.
var _render_keys := PackedInt64Array()
var _seq := 0
const RENDER_SEQ_BITS := 20

func _add(z: int, type: int, obj = null, extra = 0) -> void:
	_render_list.append([z, _seq, type, obj, extra])
	_render_keys.append(z * (1 << RENDER_SEQ_BITS) + _seq)  # multiply, not shift: orders can be negative
	_seq += 1

func get_ice_z_pos(the_row: int) -> int:
	return make_render_order(PvZ.RENDER_LAYER_GROUND, the_row, 2)

func draw_ice(g: Graphics, gy: int) -> void:
	var img := Res.get_image("IMAGE_ICE")
	var py := grid_to_pixel_y(8, gy) + 20
	var h := img.height
	var w := img.width
	var alpha := clampi(Tod.idiv(255 * ice_timer[gy], 10), 0, 255)
	if alpha < 255:
		g.colorize_images = true
		g.color = Color8(255, 255, 255, alpha)
	var begin_x: int = ice_min_x[gy] + 13
	var px := begin_x
	while px < PvZ.BOARD_ICE_START:
		var dx: int
		if px == begin_x:
			dx = (PvZ.BOARD_ICE_START - begin_x) % w
			if dx == 0:
				dx = w
		else:
			dx = w
		g.draw_image_stretch(img, Rect2(px, py, dx, h), Rect2(w - dx, 0, dx, h))
		px += dx
	g.draw_image(Res.get_image("IMAGE_ICE_CAP"), ice_min_x[gy], py)
	g.colorize_images = false

func draw_backdrop(g: Graphics) -> void:
	var cl := custom_level()
	if cl != null and cl.level.uses_custom_background():
		draw_custom_backdrop(g, cl)
		return
	var bg: PvzImage = null
	match background:
		PvZ.BACKGROUND_1_DAY: bg = Res.get_image("IMAGE_BACKGROUND1")
		PvZ.BACKGROUND_2_NIGHT: bg = Res.get_image("IMAGE_BACKGROUND2")
		PvZ.BACKGROUND_3_POOL: bg = Res.get_image("IMAGE_BACKGROUND3")
		PvZ.BACKGROUND_4_FOG: bg = Res.get_image("IMAGE_BACKGROUND4")
		PvZ.BACKGROUND_5_ROOF: bg = Res.get_image("IMAGE_BACKGROUND5")
		PvZ.BACKGROUND_6_BOSS: bg = Res.get_image("IMAGE_BACKGROUND6BOSS")
		PvZ.BACKGROUND_MUSHROOM_GARDEN: bg = Res.get_image("IMAGE_BACKGROUND_MUSHROOMGARDEN")
		PvZ.BACKGROUND_GREENHOUSE: bg = Res.get_image("IMAGE_BACKGROUND_GREENHOUSE")
		PvZ.BACKGROUND_ZOMBIQUARIUM: bg = Res.get_image("IMAGE_AQUARIUM1")
	var first_time := App.is_first_time_adventure_mode()
	var ox := -PvZ.BOARD_OFFSET_X
	if level == 1 and first_time:
		g.draw_image(Res.get_image("IMAGE_BACKGROUND1UNSODDED"), ox, 0)
		var sod := Res.get_image("IMAGE_SOD1ROW")
		var w := Tod.animate_curve(0, 1000, sod_position, 0, sod.width, Tod.CURVE_LINEAR)
		g.draw_image_src(sod, 239 + ox + PvZ.BOARD_ADDITIONAL_WIDTH, 265 + PvZ.BOARD_OFFSET_Y, Rect2(0, 0, w, sod.height))
	elif ((level == 2 or level == 3) and first_time) or App.game_mode == PvZ.GAMEMODE_CHALLENGE_RESODDED:
		g.draw_image(Res.get_image("IMAGE_BACKGROUND1UNSODDED"), ox, 0)
		g.draw_image(Res.get_image("IMAGE_SOD1ROW"), 239 + ox + PvZ.BOARD_ADDITIONAL_WIDTH, 265 + PvZ.BOARD_OFFSET_Y)
		var sod3 := Res.get_image("IMAGE_SOD3ROW")
		var w := Tod.animate_curve(0, 1000, sod_position, 0, sod3.width, Tod.CURVE_LINEAR)
		g.draw_image_src(sod3, 235 + ox + PvZ.BOARD_ADDITIONAL_WIDTH, 149 + PvZ.BOARD_OFFSET_Y, Rect2(0, 0, w, sod3.height))
	elif level == 4 and first_time:
		g.draw_image(Res.get_image("IMAGE_BACKGROUND1UNSODDED"), ox, 0)
		g.draw_image(Res.get_image("IMAGE_SOD3ROW"), 235 + ox + PvZ.BOARD_ADDITIONAL_WIDTH, 149 + PvZ.BOARD_OFFSET_Y)
		var w := Tod.animate_curve(0, 1000, sod_position, 0, 773, Tod.CURVE_LINEAR)
		var bg1 := Res.get_image("IMAGE_BACKGROUND1")
		g.draw_image_src(bg1, 232 + ox, 0, Rect2(232, 0, w + PvZ.BOARD_ADDITIONAL_WIDTH, bg1.height))
	elif bg:
		if background == PvZ.BACKGROUND_MUSHROOM_GARDEN or background == PvZ.BACKGROUND_GREENHOUSE or background == PvZ.BACKGROUND_ZOMBIQUARIUM:
			g.draw_image(bg, 0, 0)
		else:
			g.draw_image(bg, ox, 0)
	if App.game_scene == PvZ.SCENE_ZOMBIES_WON:
		draw_house_door_bottom(g)
	if stage_draws_pool_water():
		g.trans_x += PvZ.BOARD_ADDITIONAL_WIDTH
		g.trans_y += PvZ.BOARD_OFFSET_Y
		App.pool_effect.pool_effect_draw(g, stage_is_night())
		g.trans_x -= PvZ.BOARD_ADDITIONAL_WIDTH
		g.trans_y -= PvZ.BOARD_OFFSET_Y
	if tutorial_state == PvZ.TUTORIAL_LEVEL_1_PLANT_PEASHOOTER:
		var cg := g.copy()
		cg.colorize_images = true
		cg.color = Tod.get_flashing_color(main_counter, 75)
		cg.draw_image(Res.get_image("IMAGE_SOD1ROW"), 239 + ox + PvZ.BOARD_ADDITIONAL_WIDTH, 265 + PvZ.BOARD_OFFSET_Y)
	challenge.draw_backdrop(g)
	if App.game_scene == PvZ.SCENE_LEVEL_INTRO and stage_has_grave_stones():
		g.draw_image(Res.get_image("IMAGE_NIGHT_GRAVE_GRAPHIC"), 1092 + PvZ.BOARD_ADDITIONAL_WIDTH, 30 + PvZ.BOARD_OFFSET_Y)

## A custom level paints its own lawn: one image, positioned and scaled by the level, with
## the optional water overlay on top only when the level asked for it.
func draw_custom_backdrop(g: Graphics, cl: CustomRuntime) -> void:
	var img := CustomAssets.get_image(cl.level.bg_image)
	if img == null:
		g.color = Color8(24, 40, 20)
		g.fill_rect(-PvZ.BOARD_OFFSET_X, 0, PvZ.BOARD_WIDTH + PvZ.BOARD_OFFSET_X * 2, PvZ.BOARD_HEIGHT)
	else:
		var sc: float = maxf(0.05, cl.level.bg_scale)
		var ox := float(-PvZ.BOARD_OFFSET_X + cl.level.bg_offset.x)
		var oy := float(cl.level.bg_offset.y)
		g.draw_image_scaled_size(img, ox, oy, img.width * sc, img.height * sc)
	if App.game_scene == PvZ.SCENE_ZOMBIES_WON:
		draw_house_door_bottom(g)
	if stage_draws_pool_water():
		g.trans_x += PvZ.BOARD_ADDITIONAL_WIDTH
		g.trans_y += PvZ.BOARD_OFFSET_Y
		App.pool_effect.pool_effect_draw(g, stage_is_night())
		g.trans_x -= PvZ.BOARD_ADDITIONAL_WIDTH
		g.trans_y -= PvZ.BOARD_OFFSET_Y
	challenge.draw_backdrop(g)

func _add_boss_render_items(boss: Zombie) -> void:
	var back_leg_row := 1
	var front_leg_row := 3
	var back_arm_row := 4
	if boss.is_dead_or_dying():
		back_arm_row = 1
	elif boss.zombie_phase == PvZ.PHASE_BOSS_STOMPING:
		var r: Reanimation = boss.body_reanim
		if r and r.anim_time > 0.25 and r.anim_time < 0.75:
			if boss.target_row == 1:
				back_leg_row = 2
			elif boss.target_row == 3:
				front_leg_row = 4
	_add(make_render_order(PvZ.RENDER_LAYER_BOSS, back_leg_row, 2), RENDER_ITEM_BOSS_PART, boss, PvZ.BOSS_PART_BACK_LEG)
	_add(make_render_order(PvZ.RENDER_LAYER_BOSS, front_leg_row, 2), RENDER_ITEM_BOSS_PART, boss, PvZ.BOSS_PART_FRONT_LEG)
	_add(make_render_order(PvZ.RENDER_LAYER_BOSS, 4, 2), RENDER_ITEM_BOSS_PART, boss, PvZ.BOSS_PART_MAIN)
	_add(make_render_order(PvZ.RENDER_LAYER_BOSS, back_arm_row, 3), RENDER_ITEM_BOSS_PART, boss, PvZ.BOSS_PART_BACK_ARM)
	var ball: Reanimation = BoardCore.try_get(boss.boss_fire_ball_reanim)
	if ball:
		_add(ball.render_order, RENDER_ITEM_BOSS_PART, boss, PvZ.BOSS_PART_FIREBALL)

func draw_game_objects(g: Graphics) -> void:
	_render_list.clear()
	_render_keys.clear()
	_seq = 0
	for p in plants:
		if p.dead or p.on_bungee_state != PvZ.NOT_ON_BUNGEE:
			continue
		_add(p.render_order, RENDER_ITEM_PLANT, p)
		if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN and p.potted_plant_index != -1:
			_add(make_render_order(PvZ.RENDER_LAYER_PARTICLE, 0, y), RENDER_ITEM_PLANT_OVERLAY, p)
		if (p.seed_type == PvZ.SEED_MAGNETSHROOM or p.seed_type == PvZ.SEED_GOLD_MAGNET) and p.draw_magnet_items_on_top():
			_add(make_render_order(PvZ.RENDER_LAYER_TOP, 0, -1), RENDER_ITEM_PLANT_MAGNET_ITEMS, p)
		var no_bar_plant: bool = p.seed_type == PvZ.SEED_INSTANT_COFFEE or p.imitater_type == PvZ.SEED_INSTANT_COFFEE 			or p.seed_type == PvZ.SEED_FLOWERPOT or p.imitater_type == PvZ.SEED_FLOWERPOT 			or p.seed_type == PvZ.SEED_LILYPAD or p.imitater_type == PvZ.SEED_LILYPAD
		if App.plant_healthbars and App.game_mode != PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN and not no_bar_plant:
			_add(p.render_order + 1, RENDER_ITEM_HEALTHBAR_PLANT, p)
	for c in coins:
		if not c.dead:
			_add(c.render_order, RENDER_ITEM_COIN, c)
	for b in bush_list:
		_add(b.render_order, RENDER_ITEM_BUSH, b)
	for z in zombies:
		if z.dead:
			continue
		if z.zombie_type == PvZ.ZOMBIE_BOSS:
			_add_boss_render_items(z)
		else:
			_add(z.render_order, RENDER_ITEM_ZOMBIE, z)
			if z.has_shadow():
				_add(make_render_order(PvZ.RENDER_LAYER_GROUND, z.row, 3), RENDER_ITEM_ZOMBIE_SHADOW, z)
			if z.zombie_type == PvZ.ZOMBIE_BUNGEE:
				_add(make_render_order(PvZ.RENDER_LAYER_PROJECTILE, z.row, 1), RENDER_ITEM_ZOMBIE_BUNGEE_TARGET, z)
			if App.zombie_healthbars and App.game_mode != PvZ.GAMEMODE_CHALLENGE_INVISIGHOUL:
				_add(z.render_order + 1, RENDER_ITEM_HEALTHBAR_ZOMBIE, z)
	for pr in projectiles:
		if pr.dead:
			continue
		_add(pr.render_order, RENDER_ITEM_PROJECTILE, pr)
		_add(make_render_order(PvZ.RENDER_LAYER_GROUND, pr.row, 3), RENDER_ITEM_PROJECTILE_SHADOW, pr)
	for m in lawn_mowers:
		if not m.dead:
			_add(m.render_order, RENDER_ITEM_MOWER, m)
	for ps in EffectSystem.particle_systems:
		if not ps.dead and not ps.is_attachment:
			_add(ps.render_order, RENDER_ITEM_PARTICLE, ps)
	for r in EffectSystem.reanimations:
		if not r.dead and not r.is_attachment:
			_add(r.render_order, RENDER_ITEM_REANIMATION, r)
	for gi in grid_items:
		if gi.dead:
			continue
		_add(gi.render_order, RENDER_ITEM_GRID_ITEM, gi)
		if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN and gi.grid_item_type == PvZ.GRIDITEM_STINKY:
			_add(make_render_order(PvZ.RENDER_LAYER_PARTICLE, 0, int(gi.pos_y - 30.0)), RENDER_ITEM_GRID_ITEM_OVERLAY, gi)
	for i in MAX_GRID_SIZE_Y:
		if ice_timer[i] != 0:
			_add(get_ice_z_pos(i), RENDER_ITEM_ICE, null, i)
	var bottom_z: int
	if time_stop_counter > 0 or (App.game_scene == PvZ.SCENE_LEVEL_INTRO and cut_scene.is_panning_left() and tutorial_state == PvZ.TUTORIAL_OFF):
		bottom_z = make_render_order(PvZ.RENDER_LAYER_ABOVE_UI, 0, 0)
	elif App.game_scene == PvZ.SCENE_PLAYING or App.game_scene == PvZ.SCENE_ZOMBIES_WON or cut_scene.is_after_seed_chooser() \
			or cut_scene.is_in_shovel_tutorial() or help_index == PvZ.ADVICE_CLICK_TO_CONTINUE:
		bottom_z = make_render_order(PvZ.RENDER_LAYER_UI_BOTTOM, 0, 1)
	else:
		bottom_z = make_render_order(PvZ.RENDER_LAYER_ABOVE_UI, 0, 0)
	_add(make_render_order(PvZ.RENDER_LAYER_UI_BOTTOM, 0, 0), RENDER_ITEM_BACKDROP)
	_add(bottom_z, RENDER_ITEM_BOTTOM_UI)
	_add(make_render_order(PvZ.RENDER_LAYER_TOP, 0, 0), RENDER_ITEM_COVER)
	_add(make_render_order(PvZ.RENDER_LAYER_COIN_BANK, 0, 0), RENDER_ITEM_COIN_BANK)
	_add(make_render_order(PvZ.RENDER_LAYER_UI_TOP, 0, 0), RENDER_ITEM_TOP_UI)
	_add(make_render_order(PvZ.RENDER_LAYER_SCREEN_FADE, 0, 0), RENDER_ITEM_SCREEN_FADE)
	if App.game_scene == PvZ.SCENE_ZOMBIES_WON:
		if stage_has_roof():
			_add(make_render_order(PvZ.RENDER_LAYER_GRAVE_STONE, 0, 4), RENDER_ITEM_DOOR_MASK)
		else:
			_add(make_render_order(PvZ.RENDER_LAYER_GRAVE_STONE, 3, 2), RENDER_ITEM_DOOR_MASK)
	if stage_has_fog():
		_add(make_render_order(PvZ.RENDER_LAYER_FOG, 0, 0), RENDER_ITEM_FOG)
	if App.is_stormy_night_level():
		_add(make_render_order(PvZ.RENDER_LAYER_FOG, 0, 3), RENDER_ITEM_STORM)
	_add(cursor_preview.render_order, RENDER_ITEM_CURSOR_PREVIEW, cursor_preview)
	_render_keys.sort()

	var seq_mask := (1 << RENDER_SEQ_BITS) - 1
	for key in _render_keys:
		var item: Array = _render_list[key & seq_mask]
		var obj = item[3]
		match item[2]:
			RENDER_ITEM_PLANT:
				if obj.begin_draw(g):
					obj.draw(g)
					obj.end_draw(g)
			RENDER_ITEM_PLANT_OVERLAY:
				if obj.begin_draw(g):
					App.zen_garden.draw_plant_overlay(g, obj)
					obj.end_draw(g)
			RENDER_ITEM_PLANT_MAGNET_ITEMS:
				if obj.begin_draw(g):
					obj.draw_magnet_items(g)
					obj.end_draw(g)
			RENDER_ITEM_MOWER:
				obj.draw(g)
			RENDER_ITEM_ZOMBIE:
				if obj.begin_draw(g):
					obj.draw(g)
					obj.end_draw(g)
			RENDER_ITEM_ZOMBIE_SHADOW:
				if obj.begin_draw(g):
					obj.draw_shadow(g)
					obj.end_draw(g)
			RENDER_ITEM_ZOMBIE_BUNGEE_TARGET:
				obj.draw_bungee_target(g)
			RENDER_ITEM_BOSS_PART:
				var boss := get_boss_zombie()
				if boss and boss.begin_draw(g):
					boss.draw_boss_part(g, item[4])
					boss.end_draw(g)
			RENDER_ITEM_COIN, RENDER_ITEM_PROJECTILE, RENDER_ITEM_CURSOR_PREVIEW, RENDER_ITEM_BUSH:
				if obj.begin_draw(g):
					obj.draw(g)
					obj.end_draw(g)
			RENDER_ITEM_PROJECTILE_SHADOW:
				if obj.begin_draw(g):
					obj.draw_shadow(g)
					obj.end_draw(g)
			RENDER_ITEM_GRID_ITEM:
				obj.draw_grid_item(g)
			RENDER_ITEM_GRID_ITEM_OVERLAY:
				obj.draw_grid_item_overlay(g)
			RENDER_ITEM_ICE:
				draw_ice(g, item[4])
			RENDER_ITEM_PARTICLE, RENDER_ITEM_REANIMATION:
				obj.draw(g)
			RENDER_ITEM_COIN_BANK:
				draw_ui_coin_bank(g)
			RENDER_ITEM_BACKDROP:
				draw_backdrop(g)
			RENDER_ITEM_DOOR_MASK:
				draw_house_door_top(g)
			RENDER_ITEM_BOTTOM_UI:
				draw_ui_bottom(g)
			RENDER_ITEM_TOP_UI:
				draw_ui_top(g)
			RENDER_ITEM_COVER:
				draw_cover(g)
			RENDER_ITEM_FOG:
				draw_fog(g)
			RENDER_ITEM_STORM:
				challenge.draw_weather(g)
			RENDER_ITEM_SCREEN_FADE:
				draw_fade_out(g)
			RENDER_ITEM_HEALTHBAR_ZOMBIE:
				draw_zombie_healthbars(g, obj)
			RENDER_ITEM_HEALTHBAR_PLANT:
				draw_plant_healthbar(g, obj)

# ---------------------------------------------------------------- QE health bars
const HEALTHBAR_WIDTH := 55
const HEALTHBAR_HEIGHT := 10
const HEALTHBAR_BASE_OFFSET_Y := 3
const HEALTHBAR_TEXT_OFFSET_Y := 3
const HEALTHBAR_BASE_TEXT_OFFSET_Y := 14

func draw_zombie_healthbars(g: Graphics, z: Zombie) -> void:
	var rect := z.get_zombie_rect()
	var font := Res.get_font("FONT_BRIANNETOD12")
	var red := Color8(255, 0, 0)
	var step := HEALTHBAR_BASE_OFFSET_Y + HEALTHBAR_HEIGHT + HEALTHBAR_TEXT_OFFSET_Y + HEALTHBAR_BASE_TEXT_OFFSET_Y
	var offset_y := 0
	if z.body_health > 0:
		offset_y += HEALTHBAR_BASE_OFFSET_Y
		draw_healthbar(g, rect, red, z.body_max_health, Color8(255, 255, 0), z.body_health, HEALTHBAR_WIDTH, HEALTHBAR_HEIGHT, 0, offset_y, Color.WHITE, font, HEALTHBAR_TEXT_OFFSET_Y, Color.BLACK, 1, true)
	if z.helm_health > 0:
		offset_y += step
		draw_healthbar(g, rect, red, z.helm_max_health, Color8(0, 0, 255), z.helm_health, HEALTHBAR_WIDTH, HEALTHBAR_HEIGHT, 0, offset_y, Color.WHITE, font, HEALTHBAR_TEXT_OFFSET_Y, Color.BLACK, 1, true)
	if z.shield_health > 0:
		offset_y += step
		draw_healthbar(g, rect, red, z.shield_max_health, Color8(0, 255, 255), z.shield_health, HEALTHBAR_WIDTH, HEALTHBAR_HEIGHT, 0, offset_y, Color.WHITE, font, HEALTHBAR_TEXT_OFFSET_Y, Color.BLACK, 1, true)

func draw_plant_healthbar(g: Graphics, p: Plant) -> void:
	var rect := p.get_plant_rect()
	var is_pumpkin := p.seed_type == PvZ.SEED_PUMPKINSHELL or p.imitater_type == PvZ.SEED_PUMPKINSHELL
	var base := Color8(0, 255, 0)
	if Plant.is_upgrade(p.seed_type):
		base = Color8(170, 122, 210)
	elif is_pumpkin:
		base = Color8(255, 188, 32)
	var max_color := Color8(255, 0, 0)
	if p.seed_type == PvZ.SEED_IMITATER or p.imitater_type != PvZ.SEED_NONE:
		# Imitater copies get a washed-out bar.
		base = Color8(mini(255, base.r8 + 125), mini(255, base.g8 + 125), mini(255, base.b8 + 125))
		max_color = Color8(mini(255, max_color.r8 + 125), mini(255, max_color.g8 + 125), mini(255, max_color.b8 + 125))
	if p.plant_health > 0:
		var offset_y := HEALTHBAR_BASE_OFFSET_Y
		if is_pumpkin:
			offset_y += HEALTHBAR_HEIGHT + HEALTHBAR_TEXT_OFFSET_Y + HEALTHBAR_BASE_TEXT_OFFSET_Y
		var offset_x := 10 if (p.seed_type != PvZ.SEED_IMITATER and is_pumpkin) or p.seed_type == PvZ.SEED_TALLNUT else 0
		draw_healthbar(g, rect, max_color, p.plant_max_health, base, p.plant_health, HEALTHBAR_WIDTH, HEALTHBAR_HEIGHT, offset_x, offset_y, Color.WHITE, Res.get_font("FONT_BRIANNETOD12"), HEALTHBAR_TEXT_OFFSET_Y, Color.BLACK, 1, true)

## Board::DrawHealthbar
func draw_healthbar(g: Graphics, rect: Rect2i, max_color: Color, max_number: int, base_color: Color, base_number: int, bar_w: int, bar_h: int,
		bar_offset_x: int, bar_offset_y: int, text_color: Color, font: ImageFont, text_offset_y: int, outline_color: Color, outline_offset: int, draw_outline: bool) -> void:
	var bar_x := rect.position.x + Tod.idiv(rect.size.x - bar_w, 2) - bar_offset_x
	var bar_y := rect.position.y - bar_h - bar_offset_y
	var percent := Tod.idiv(base_number * 100, max_number) if max_number != 0 else 0
	var base_w := Tod.idiv(bar_w * percent, 100)
	var text := "%d / %d" % [base_number, max_number]
	TodStrings.draw_string(g, text, bar_x + bar_w / 2 + outline_offset, bar_y - text_offset_y + outline_offset, font, outline_color, PvZ.DS_ALIGN_CENTER)
	TodStrings.draw_string(g, text, bar_x + bar_w / 2, bar_y - text_offset_y, font, text_color, PvZ.DS_ALIGN_CENTER)
	var last := g.color
	g.color = max_color
	g.fill_rect(bar_x + base_w, bar_y, bar_w - base_w, bar_h)
	g.color = base_color
	g.fill_rect(bar_x, bar_y, base_w, bar_h)
	if draw_outline:
		g.color = Color.BLACK
		g.draw_rect(bar_x - 1, bar_y - 1, bar_w + 1, bar_h + 1)
	g.color = last

func draw_progress_meter(g: Graphics) -> void:
	if not has_progress_meter():
		return
	var meter := Res.get_image("IMAGE_FLAGMETER")
	var parts := Res.get_image("IMAGE_FLAGMETERPARTS")
	var ix := PvZ.BOARD_WIDTH - 200
	var iy := PvZ.BOARD_HEIGHT - 25
	g.draw_image_cel(meter, ix, iy, 0)
	var cw := meter.get_cel_width()
	var ch := meter.get_cel_height()
	var clip_w := Tod.animate_curve(0, PROGRESS_METER_COUNTER, progress_meter_width, 0, 143, Tod.CURVE_LINEAR)
	g.draw_image_stretch(meter, Rect2(cw - clip_w + ix - 7, iy, clip_w, ch), Rect2(cw - clip_w - 7, ch, clip_w, ch))
	if progress_meter_has_flags():
		var wpf := get_num_waves_per_flag()
		var flag_waves := Tod.idiv(num_waves, wpf)
		var flags_end := ix + cw - 10
		for fw in range(1, flag_waves + 1):
			var h := 0
			var total := fw * wpf
			if total < current_wave:
				h = 14
			elif total == current_wave:
				h = Tod.animate_curve(100, 0, flag_raise_counter, 0, 14, Tod.CURVE_LINEAR)
			var px := Tod.animate_curve(0, num_waves, total, flags_end, ix + 6, Tod.CURVE_LINEAR)
			g.draw_image_cel_rc(parts, px, iy - 4, 1, 0)
			g.draw_image_cel_rc(parts, px, iy - h - 3, 2, 0)
	g.draw_image(Res.get_image("IMAGE_FLAGMETERLEVELPROGRESS"), ix + 38, iy + 14)
	if App.is_final_boss_level():
		return
	var head := Tod.animate_curve(0, 150, progress_meter_width, 0, 135, Tod.CURVE_LINEAR)
	g.draw_image_cel_rc(parts, cw - head + ix - 20, iy - 3, 0, 0)

func draw_house_door_bottom(g: Graphics) -> void:
	var aw := PvZ.BOARD_ADDITIONAL_WIDTH
	var oy := PvZ.BOARD_OFFSET_Y
	match background:
		PvZ.BACKGROUND_1_DAY: g.draw_image(Res.get_image("IMAGE_BACKGROUND1_GAMEOVER_INTERIOR_OVERLAY"), -126 + aw, 225 + oy)
		PvZ.BACKGROUND_2_NIGHT: g.draw_image(Res.get_image("IMAGE_BACKGROUND2_GAMEOVER_INTERIOR_OVERLAY"), -125 + aw, 196 + oy)
		PvZ.BACKGROUND_3_POOL: g.draw_image(Res.get_image("IMAGE_BACKGROUND3_GAMEOVER_INTERIOR_OVERLAY"), -171 + aw, 241 + oy)
		PvZ.BACKGROUND_4_FOG: g.draw_image(Res.get_image("IMAGE_BACKGROUND4_GAMEOVER_INTERIOR_OVERLAY"), -172 + aw, 246 + oy)

func draw_house_door_top(g: Graphics) -> void:
	var aw := PvZ.BOARD_ADDITIONAL_WIDTH
	var oy := PvZ.BOARD_OFFSET_Y
	match background:
		PvZ.BACKGROUND_1_DAY: g.draw_image(Res.get_image("IMAGE_BACKGROUND1_GAMEOVER_MASK"), -130 + aw, 202 + oy)
		PvZ.BACKGROUND_2_NIGHT: g.draw_image(Res.get_image("IMAGE_BACKGROUND2_GAMEOVER_MASK"), -128 + aw, 207 + oy)
		PvZ.BACKGROUND_3_POOL: g.draw_image(Res.get_image("IMAGE_BACKGROUND3_GAMEOVER_MASK"), -172 + aw, 234 + oy)
		PvZ.BACKGROUND_4_FOG: g.draw_image(Res.get_image("IMAGE_BACKGROUND4_GAMEOVER_MASK"), -173 + aw, 133 + oy)
		PvZ.BACKGROUND_5_ROOF: g.draw_image(Res.get_image("IMAGE_BACKGROUND5_GAMEOVER_MASK"), -220 + aw, 81 + oy)
		PvZ.BACKGROUND_6_BOSS: g.draw_image(Res.get_image("IMAGE_BACKGROUND6_GAMEOVER_MASK"), -220 + aw, 81 + oy)

func draw_level(g: Graphics) -> void:
	if is_versus():
		return  # the Versus HUD replaces the level name
	var level_str: String
	var cl := custom_level()
	if cl != null:
		level_str = cl.level.level_name
	elif App.is_adventure_mode():
		level_str = Tod.replace_string("[QUICK_PLAY_LEVEL]" if App.playing_quickplay else "[LEVEL]", "{LEVEL}", App.get_stage_string(level).substr(1))
	else:
		level_str = App.get_current_challenge_name()
	var px := PvZ.BOARD_WIDTH - 20 - App.board_view_crop
	var py := PvZ.BOARD_HEIGHT - 5
	if has_progress_meter():
		px = PvZ.BOARD_WIDTH - 207 - App.board_view_crop
	if challenge.challenge_state == PvZ.STATECHALLENGE_ZEN_FADING:
		py += Tod.animate_curve(50, 0, challenge.challenge_state_counter, 0, 50, Tod.CURVE_EASE_IN_OUT)
	TodStrings.draw_string(g, level_str, px, py, Res.get_font("FONT_HOUSEOFTERROR16"), Color8(224, 187, 98), TodStrings.DS_ALIGN_RIGHT)

func draw_zen_wheel_barrow_button(g: Graphics, offset_y: int) -> void:
	var r := get_zen_button_rect(PvZ.OBJECT_TYPE_WHEELBARROW, get_shovel_button_rect())
	var pp = App.zen_garden.get_potted_plant_in_wheelbarrow()
	var wb := Res.get_image("IMAGE_ZEN_WHEELBARROW")
	var bx := r.position.x
	var by := r.position.y
	if pp and cursor_object.cursor_type != PvZ.CURSOR_TYPE_PLANT_FROM_WHEEL_BARROW:
		if challenge.challenge_state == PvZ.STATECHALLENGE_ZEN_FADING:
			g.draw_image(wb, bx - 7, by + offset_y - 3)
		else:
			g.draw_image(wb, bx - 7, by + offset_y + 4)
		if pp.plant_age == PvZ.PLANTAGE_SMALL:
			App.zen_garden.draw_potted_plant(g, bx + 23, by + offset_y - 8, pp, 0.6, true)
		elif pp.plant_age == PvZ.PLANTAGE_MEDIUM:
			App.zen_garden.draw_potted_plant(g, bx + 28, by + offset_y + 2, pp, 0.5, true)
		else:
			App.zen_garden.draw_potted_plant(g, bx + 34, by + offset_y + 12, pp, 0.4, true)
	else:
		g.draw_image(wb, bx - 7, by + offset_y - 3)

func _draw_charges(g: Graphics, charges: int, r: Rect2i, offset_y: int) -> void:
	TodStrings.draw_string(g, "x%d" % charges, r.position.x + 64, r.position.y + offset_y + 65, Res.get_font("FONT_HOUSEOFTERROR16"), Color.WHITE, TodStrings.DS_ALIGN_RIGHT)

func draw_zen_buttons(g: Graphics) -> void:
	var offset_y := 0
	if challenge.challenge_state == PvZ.STATECHALLENGE_ZEN_FADING:
		offset_y = Tod.animate_curve(50, 0, challenge.challenge_state_counter, 0, -72, Tod.CURVE_EASE_IN_OUT)
	var pur: Array = App.player_info.purchases
	for tool in range(PvZ.OBJECT_TYPE_WATERING_CAN, PvZ.OBJECT_TYPE_NEXT_GARDEN + 1):
		if not can_use_game_object(tool):
			continue
		var r := get_shovel_button_rect()
		if tool == PvZ.OBJECT_TYPE_NEXT_GARDEN:
			r.position.x = 564 + PvZ.BOARD_ADDITIONAL_WIDTH
			if not menu_button.btn_no_draw:
				g.draw_image(Res.get_image("IMAGE_ZEN_NEXTGARDEN"), r.position.x + 2, r.position.y + offset_y)
			continue
		r = get_zen_button_rect(tool, r)
		var bx := r.position.x
		var by := r.position.y + offset_y
		g.draw_image(Res.get_image("IMAGE_SHOVELBANK"), bx, by)
		if cursor_object.cursor_type == PvZ.CURSOR_TYPE_WATERING_CAN + tool - 6:
			continue
		match tool:
			PvZ.OBJECT_TYPE_WATERING_CAN:
				if pur[PvZ.STORE_ITEM_GOLD_WATERINGCAN] != 0:
					g.draw_image(Res.get_image("IMAGE_WATERINGCANGOLD"), bx - 2, by - 6)
				else:
					g.draw_image(Res.get_image("IMAGE_WATERINGCAN"), bx - 2, by - 6)
			PvZ.OBJECT_TYPE_FERTILIZER:
				var charges: int = pur[PvZ.STORE_ITEM_FERTILIZER] - PURCHASE_COUNT_OFFSET
				if charges == 0:
					g.colorize_images = true
					g.color = Color8(96, 96, 96)
				elif tutorial_state == PvZ.TUTORIAL_ZEN_GARDEN_FERTILIZE_PLANTS:
					g.colorize_images = true
					g.color = Tod.get_flashing_color(main_counter, 75)
				g.draw_image(Res.get_image("IMAGE_FERTILIZER"), bx - 6, by - 7)
				g.colorize_images = false
				_draw_charges(g, charges, r, offset_y)
			PvZ.OBJECT_TYPE_BUG_SPRAY:
				var charges: int = pur[PvZ.STORE_ITEM_BUG_SPRAY] - PURCHASE_COUNT_OFFSET
				if charges == 0:
					g.colorize_images = true
					g.color = Color8(128, 128, 128)
				g.draw_image(Res.get_image("IMAGE_BUG_SPRAY"), bx, by - 1)
				g.colorize_images = false
				_draw_charges(g, charges, r, offset_y)
			PvZ.OBJECT_TYPE_PHONOGRAPH:
				g.draw_image(Res.get_image("IMAGE_PHONOGRAPH"), bx + 2, by + 2)
			PvZ.OBJECT_TYPE_CHOCOLATE:
				var charges: int = pur[PvZ.STORE_ITEM_CHOCOLATE] - PURCHASE_COUNT_OFFSET
				if charges == 0:
					g.colorize_images = true
					g.color = Color8(128, 128, 128)
				g.draw_image(Res.get_image("IMAGE_CHOCOLATE"), bx + 6, by + 4)
				g.colorize_images = false
				_draw_charges(g, charges, r, offset_y)
			PvZ.OBJECT_TYPE_GLOVE:
				if cursor_object.cursor_type != PvZ.CURSOR_TYPE_PLANT_FROM_GLOVE and cursor_object.cursor_type != PvZ.CURSOR_TYPE_PLANT_FROM_WHEEL_BARROW:
					g.draw_image(Res.get_image("IMAGE_ZEN_GARDENGLOVE"), bx - 6, by - 4)
			PvZ.OBJECT_TYPE_MONEY_SIGN:
				g.draw_image(Res.get_image("IMAGE_ZEN_MONEYSIGN"), bx - 5, by - 4)
			PvZ.OBJECT_TYPE_WHEELBARROW:
				draw_zen_wheel_barrow_button(g, offset_y)
			PvZ.OBJECT_TYPE_TREE_FOOD:
				var charges: int = pur[PvZ.STORE_ITEM_TREE_FOOD] - PURCHASE_COUNT_OFFSET
				if charges <= 0:
					g.colorize_images = true
					g.color = Color8(128, 128, 128)
					charges = 0
				if not challenge.tree_of_wisdom_can_feed():
					g.colorize_images = true
					g.color = Color8(128, 128, 128)
				g.draw_image(Res.get_image("IMAGE_TREEFOOD"), bx - 6, by - 7)
				g.colorize_images = false
				_draw_charges(g, charges, r, offset_y)

func draw_shovel(g: Graphics) -> void:
	var r := get_shovel_button_rect()
	g.draw_image(Res.get_image("IMAGE_SHOVELBANK"), r.position.x, r.position.y)
	if cursor_object.cursor_type != PvZ.CURSOR_TYPE_SHOVEL:
		g.draw_image(Res.get_image("IMAGE_SHOVEL"), r.position.x - 7, r.position.y - 3)

func draw_fade_out(g: Graphics) -> void:
	if board_fade_out_counter < 0 or is_survival_stage_with_repick():
		return
	var alpha := Tod.animate_curve(200, 0, board_fade_out_counter, 0, 255, Tod.CURVE_LINEAR)
	if level == 9 or level == 19 or level == 29 or level == 39 or level == 49:
		g.color = Color8(0, 0, 0, alpha)
	else:
		g.color = Color8(255, 255, 255, alpha)
	g.fill_rect(0, 0, width, height)

func draw_cover(g: Graphics) -> void:
	var aw := PvZ.BOARD_ADDITIONAL_WIDTH
	var oy := PvZ.BOARD_OFFSET_Y
	match background:
		PvZ.BACKGROUND_1_DAY: g.draw_image(Res.get_image("IMAGE_BACKGROUND1_COVER"), 685 + aw, 557 + oy)
		PvZ.BACKGROUND_2_NIGHT: g.draw_image(Res.get_image("IMAGE_BACKGROUND2_COVER"), 685 + aw, 557 + oy)
		PvZ.BACKGROUND_3_POOL: g.draw_image(Res.get_image("IMAGE_BACKGROUND3_COVER"), 671 + aw, 613 + oy)
		PvZ.BACKGROUND_4_FOG: g.draw_image(Res.get_image("IMAGE_BACKGROUND4_COVER"), 671 + aw, 613 + oy)
		PvZ.BACKGROUND_5_ROOF:
			g.draw_image(Res.get_image("IMAGE_BACKGROUND5_TREES"), roof_tree_offset, 0)
			g.draw_image(Res.get_image("IMAGE_BACKGROUND5_POLE"), roof_pole_offset, 0)
		PvZ.BACKGROUND_6_BOSS:
			g.draw_image(Res.get_image("IMAGE_BACKGROUND6_TREES"), roof_tree_offset, 0)
			g.draw_image(Res.get_image("IMAGE_BACKGROUND6_POLE"), roof_pole_offset, 0)

func draw_top_right_ui(g: Graphics) -> void:
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
		var box := PvZ.BOARD_ADDITIONAL_WIDTH * 2
		if challenge.challenge_state == PvZ.STATECHALLENGE_ZEN_FADING:
			menu_button.y = Tod.animate_curve(50, 0, challenge.challenge_state_counter, -10, -50, Tod.CURVE_EASE_IN_OUT)
			store_button.x = Tod.animate_curve(50, 0, challenge.challenge_state_counter, 678 + box, PvZ.BOARD_WIDTH, Tod.CURVE_EASE_IN_OUT)
		else:
			menu_button.y = -10
			store_button.x = 678 + box
	g.colorize_images = false
	if store_button and App.game_mode != PvZ.GAMEMODE_CHALLENGE_LAST_STAND:
		if tutorial_state == PvZ.TUTORIAL_ZEN_GARDEN_VISIT_STORE:
			g.colorize_images = true
			g.color = Tod.get_flashing_color(main_counter, 75)
		store_button.draw(g)
		g.colorize_images = false

func draw_ui_bottom(g: Graphics) -> void:
	if background == PvZ.BACKGROUND_ZOMBIQUARIUM:
		var wave_time := absi(Tod.idiv(main_counter, 8) % 22 - 11)
		g.draw_mode = Graphics.DRAWMODE_ADDITIVE
		var w := 160
		var waves := Tod.idiv(PvZ.BOARD_WIDTH, w)
		for i in waves + 1:
			var img := Res.get_image("IMAGE_WAVESIDE" if (i == 0 or i == waves) else "IMAGE_WAVECENTER")
			g.tod_draw_image_cel_scaled_f(img, i * w - 80 + (w if i == waves else 0), 40, 0, wave_time, -1.0 if i == waves else 1.0, 1.0)
		g.draw_mode = Graphics.DRAWMODE_NORMAL
	if background == PvZ.BACKGROUND_GREENHOUSE or background == PvZ.BACKGROUND_ZOMBIQUARIUM:
		var ov := Res.get_image("IMAGE_BACKGROUND_GREENHOUSE_OVERLAY")
		g.draw_mode = Graphics.DRAWMODE_ADDITIVE
		g.draw_image_stretch(ov, Rect2(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT), Rect2(0, 0, ov.width, ov.height))
		g.draw_mode = Graphics.DRAWMODE_NORMAL
	if App.game_scene != PvZ.SCENE_ZOMBIES_WON:
		if seed_bank.begin_draw(g):
			seed_bank.draw(g)
			seed_bank.end_draw(g)
		if advice.message_style == PvZ.MESSAGE_STYLE_SLOT_MACHINE:
			advice.draw(g)
	if show_shovel and not (is_versus() and net_team_of(net_local_slot) == NetSession.TEAM_ZOMBIES):
		draw_shovel(g)
	if not stage_has_fog():
		draw_top_right_ui(g)
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN or App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
		draw_zen_buttons(g)

func draw_ui_coin_bank(g: Graphics) -> void:
	var bank := Res.get_image("IMAGE_COINBANK")
	coin_bank_x = 57
	coin_bank_y = PvZ.BOARD_HEIGHT - bank.height - 1
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN or App.crazy_dave_state != PvZ.CRAZY_DAVE_OFF:
		coin_bank_x = PvZ.BOARD_WIDTH - 350 - x
	if App.game_scene != PvZ.SCENE_PLAYING and App.crazy_dave_state == PvZ.CRAZY_DAVE_OFF:
		return
	if coin_bank_fade_count <= 0:
		return
	g.colorize_images = true
	var alpha := clampi(Tod.idiv(255 * coin_bank_fade_count, 15), 0, 255)
	g.color = Color8(255, 255, 255, alpha)
	g.draw_image(bank, coin_bank_x, coin_bank_y)
	g.color = Color8(180, 255, 90, alpha)
	var font := Res.get_font("FONT_CONTINUUMBOLD14")
	g.font = font
	var label: String = App.get_money_string(App.player_info.coins)
	g.draw_string(label, coin_bank_x + 116 - font.string_width(label), coin_bank_y + 24)
	g.colorize_images = false

func draw_fog(g: Graphics) -> void:
	var fog := Res.get_image("IMAGE_FOG")
	var left := left_fog_column()
	for gx in MAX_GRID_SIZE_X:
		for gy in MAX_GRID_SIZE_Y + 1:
			var fade: int = grid_cel_fog[gx][gy]
			if fade == 0:
				continue
			var look: int = grid_cel_look[gx][gy % MAX_GRID_SIZE_Y]
			var cel := look % 8
			var px := gx * 80 + fog_offset - 15 + PvZ.BOARD_ADDITIONAL_WIDTH
			var py := gy * 85 + 20 + PvZ.BOARD_OFFSET_Y
			var t := main_counter * PI * 2
			var phase_x := 6 * PI * gx / MAX_GRID_SIZE_X
			var phase_y := 6 * PI * gy / (MAX_GRID_SIZE_Y + 1)
			var motion := 13 + 4 * sin(t / 900 + phase_y) + 8 * sin(t / 500 + phase_x)
			var cv := int(255 - look * 1.5 - motion * 1.5)
			var lv := int(255 - look - motion)
			g.colorize_images = true
			g.color = Color8(cv, cv, lv, fade)
			g.draw_image_cel_rc(fog, px, py, cel, 0)
			if gx == MAX_GRID_SIZE_X - 1:
				for i in range(1, MAX_GRID_SIZE_X - left + 2):
					look += i
					cel = look % 8
					phase_x = 6 * PI * (gx + i) / MAX_GRID_SIZE_X
					phase_y = 6 * PI * (gy + i) / (MAX_GRID_SIZE_Y + 1)
					motion = 13 + 4 * sin(t / 900 + phase_y) + 8 * sin(t / 500 + phase_x)
					cv = int(255 - look * 1.5 - motion * 1.5)
					lv = int(255 - look - motion)
					g.color = Color8(clampi(cv, 0, 255), clampi(cv, 0, 255), clampi(lv, 0, 255), fade)
					g.draw_image_cel_rc(fog, px + 80 * i, py, cel, 0)
			g.colorize_images = false

func draw_ui_top(g: Graphics) -> void:
	if stage_has_fog():
		draw_top_right_ui(g)
	menu_button.draw(g)
	fast_button.draw(g)
	if time_stop_counter > 0:
		g.color = Color8(200, 200, 200, 210)
		g.fill_rect(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	if App.game_scene == PvZ.SCENE_PLAYING or App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
		draw_progress_meter(g)
		draw_level(g)
	if App.game_scene == PvZ.SCENE_LEVEL_INTRO or App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN \
			or App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM or is_scary_potter_dave_talking():
		var sg := g.copy()
		sg.trans_x -= x
		sg.trans_y -= y
		App.draw_crazy_dave(sg)
	if advice.message_style != PvZ.MESSAGE_STYLE_SLOT_MACHINE:
		advice.draw(g)
	if time_stop_counter == 0 and cursor_object.begin_draw(g):
		cursor_object.draw(g)
		cursor_object.end_draw(g)
	if is_net_game():
		App.net.draw_board_overlay(self, g)
	tool_tip.draw(g)
	draw_debug_text(g)
	draw_debug_object_rects(g)

# ---------------------------------------------------------------- debug overlays (debug key 'z')
## Board::DrawDebugText. The original uses a system Arial font; the port uses the game's small font.
func draw_debug_text(g: Graphics) -> void:
	var text := ""
	match debug_text_mode:
		PvZ.DEBUG_TEXT_NONE:
			return
		PvZ.DEBUG_TEXT_ZOMBIE_SPAWN:
			var t := zombie_count_down_start - zombie_count_down
			var frac := float(t) / float(zombie_count_down_start) if zombie_count_down_start != 0 else 0.0
			text += "ZOMBIE SPAWNING DEBUG\n"
			text += "CurrentWave: %d of %d\n" % [current_wave, num_waves]
			text += "TimeSinseLastSpawn: %d %s\n" % [t, "" if t > 400 else "(too soon)"]
			text += "ZombieCountDown: %d/%d (%.0f%%)\n" % [zombie_count_down, zombie_count_down_start, frac]
			if zombie_health_to_next_wave != -1:
				var total := total_zombies_health_in_wave(current_wave - 1)
				var health_range := maxi(zombie_health_wave_start - zombie_health_to_next_wave, 1)
				var health_frac := float(zombie_health_to_next_wave - total + health_range) / float(health_range)
				text += "ZombieHealth: CurZombieHealth %d trigger %d (%.0f%%)\n" % [total, zombie_health_to_next_wave, health_frac * 100]
			else:
				text += "ZombieHealth: before first wave\n"
			if huge_wave_count_down > 0:
				text += "HugeWaveCountDown: %d\n" % huge_wave_count_down
			var boss := get_boss_zombie()
			if boss:
				text += "\nSpawn: %d\n" % boss.summon_counter
				text += "Stomp: %d\n" % boss.boss_stomp_counter
				text += "Bungee: %d\n" % boss.boss_bungee_counter
				text += "Head: %d\n" % boss.boss_head_counter
				text += "Health: %d of %d\n" % [boss.body_health, boss.body_max_health]
		PvZ.DEBUG_TEXT_MUSIC:
			var m: Music = App.music
			text += "MUSIC DEBUG\n"
			text += "CurrentWave: %d of %d\n" % [current_wave, num_waves]
			if m.cur_file_main == Music.MUSIC_FILE_NONE:
				text += "No music"
			else:
				text += "Music Burst: "
				match m.music_burst_state:
					Music.MUSIC_BURST_OFF: text += "Off"
					Music.MUSIC_BURST_STARTING: text += "Starting %d/%d" % [m.burst_state_counter, 400]
					Music.MUSIC_BURST_ON: text += "On at least until %d/%d" % [m.burst_state_counter, 800]
					Music.MUSIC_BURST_FINISHING: text += "Finishing %d/%d" % [m.burst_state_counter, 400]
				match m.music_drums_state:
					Music.MUSIC_DRUMS_OFF: text += ", Drums off"
					Music.MUSIC_DRUMS_ON_QUEUED: text += ", Drums queued on"
					Music.MUSIC_DRUMS_ON: text += ", Drums on"
					Music.MUSIC_DRUMS_OFF_QUEUED: text += ", Drums queued off"
					Music.MUSIC_DRUMS_FADING: text += ", Drums fading off %d/%d" % [m.drums_state_counter, 50]
				text += "\n"
				var order := m.get_music_order(m.cur_file_main)
				text += "Music order %02d row %02d\n" % [order & 0xFFFF, ((order >> 16) & 0xFFFF) / 4]
		PvZ.DEBUG_TEXT_MEMORY:
			text += "MEMORY DEBUG\n"
			text += "attachments %d\n" % EffectSystem.attachments.size()
			text += "particles %d\n" % TodParticleSystem.total_particles
			text += "particle systems %d\n" % EffectSystem.particle_systems.size()
			text += "trails %d\n" % EffectSystem.trails.size()
			text += "reanimation %d\n" % EffectSystem.reanimations.size()
			text += "zombies %d\n" % zombies.size()
			text += "plants %d\n" % plants.size()
			text += "projectiles %d\n" % projectiles.size()
			text += "coins %d\n" % coins.size()
			text += "lawn mowers %d\n" % lawn_mowers.size()
			text += "grid items %d\n" % grid_items.size()
			text += "bushes %d\n" % bush_list.size()
		PvZ.DEBUG_TEXT_COLLISION:
			text += "COLLISION DEBUG\n"
	g.font = Res.get_font("FONT_BRIANNETOD12")
	g.color = Color.BLACK
	for o in [Vector2i(10, 89), Vector2i(11, 91), Vector2i(9, 90), Vector2i(11, 90)]:
		TextWriter.draw_string_word_wrapped(g, text, o.x, o.y)
	g.color = Color.WHITE
	TextWriter.draw_string_word_wrapped(g, text, 10, 90)

## Board::DrawDebugObjectRects: plant/zombie hit boxes (green) and attack boxes (red).
func draw_debug_object_rects(g: Graphics) -> void:
	if debug_text_mode != PvZ.DEBUG_TEXT_COLLISION:
		return
	for p in plants:
		if p.dead:
			continue
		g.color = Color8(0, 255, 0)
		g.draw_rect_r(Rect2(p.get_plant_rect()))
		var attack: Rect2i = p.get_plant_attack_rect(PvZ.WEAPON_PRIMARY)
		if attack.size.x < PvZ.BOARD_WIDTH:
			g.color = Color8(255, 0, 0)
			g.draw_rect_r(Rect2(attack))
		var secondary: Rect2i = p.get_plant_attack_rect(PvZ.WEAPON_SECONDARY)
		if secondary.size.x < PvZ.BOARD_WIDTH:
			g.color = Color8(255, 0, 128)
			g.draw_rect_r(Rect2(secondary))
	for z in zombies:
		if z.dead or z.is_dead_or_dying():
			continue
		g.color = Color8(0, 255, 0)
		g.draw_rect_r(Rect2(z.get_zombie_rect()))
		g.color = Color8(255, 0, 0)
		g.draw_rect_r(Rect2(z.get_zombie_attack_rect()))
	for mower in lawn_mowers:
		if mower.dead:
			continue
		g.color = Color8(255, 0, 0)
		g.draw_rect_r(Rect2(mower.get_lawn_mower_attack_rect()))
	for pr in projectiles:
		if pr.dead:
			continue
		g.color = Color8(255, 0, 0)
		g.draw_rect_r(Rect2(pr.get_projectile_rect()))

func draw(g: Graphics) -> void:
	if App.get_dialog(PvZ.DIALOG_STORE) or App.get_dialog(PvZ.DIALOG_ALMANAC):
		return
	draw_count += 1
	draw_game_objects(g)
