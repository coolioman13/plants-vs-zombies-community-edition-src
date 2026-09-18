class_name ZenGarden
extends RefCounted
## Port of ZenGarden (ZenGarden.cpp): the greenhouse, mushroom garden, aquarium, stinky and zen tools.

const ZEN_MAX_GRIDSIZE_X := 8
const ZEN_MAX_GRIDSIZE_Y := 4
const STINKY_SLEEP_POS_Y := 461.0
const PURCHASE_COUNT_OFFSET := 1000
const NUM_MOTION_TRAIL_FRAMES := 12

## [pixel_x, pixel_y, grid_x, grid_y]
const GREENHOUSE_GRID_PLACEMENT := [
	[313, 133, 0, 0], [395, 131, 1, 0], [479, 128, 2, 0], [561, 133, 3, 0],
	[646, 131, 4, 0], [724, 127, 5, 0], [806, 130, 6, 0], [888, 132, 7, 0],
	[307, 228, 0, 1], [390, 225, 1, 1], [472, 230, 2, 1], [554, 235, 3, 1],
	[656, 233, 4, 1], [737, 230, 5, 1], [818, 224, 6, 1], [900, 228, 7, 1],
	[281, 328, 0, 2], [370, 326, 1, 2], [459, 320, 2, 2], [550, 326, 3, 2],
	[656, 327, 4, 2], [744, 321, 5, 2], [834, 325, 6, 2], [924, 329, 7, 2],
	[277, 431, 0, 3], [364, 429, 1, 3], [451, 428, 2, 3], [542, 429, 3, 3],
	[665, 435, 4, 3], [752, 428, 5, 3], [842, 425, 6, 3], [931, 428, 7, 3],
]
const MUSHROOM_GRID_PLACEMENT := [
	[350, 501, 0, 0], [477, 420, 1, 0], [538, 518, 2, 0], [595, 356, 3, 0],
	[627, 263, 4, 0], [700, 445, 5, 0], [726, 538, 6, 0], [792, 343, 7, 0],
]
const AQUARIUM_GRID_PLACEMENT := [
	[353, 245, 0, 0], [546, 180, 1, 0], [596, 330, 2, 0], [862, 180, 3, 0],
	[909, 330, 4, 0], [362, 415, 5, 0], [605, 518, 6, 0], [744, 477, 7, 0],
]

var board: Board = null
var garden_type := PvZ.GARDEN_MAIN

static func _now() -> int:
	return int(Time.get_unix_time_from_system())

## Local calendar [year, day-of-year] of a unix time (for the localtime comparisons).
static func _local_year_yday(t: int) -> Array:
	var bias: int = Time.get_time_zone_from_system().get("bias", 0) * 60
	var d := Time.get_date_dict_from_unix_time(t + bias)
	var jan1 := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": 1, "day": 1, "hour": 0, "minute": 0, "second": 0})
	var day := Time.get_unix_time_from_datetime_dict({"year": d.year, "month": d.month, "day": d.day, "hour": 0, "minute": 0, "second": 0})
	return [d.year, int((day - jan1) / 86400)]

func _purchases() -> Array:
	return App.player_info.purchases

# ================================================================ drawing potted plants
func draw_potted_plant_icon(g: Graphics, x: float, y: float, pp: PlayerInfo.PottedPlant) -> void:
	draw_potted_plant(g, x, y, pp, 0.7, true)

func draw_potted_plant(g: Graphics, x: float, y: float, pp: PlayerInfo.PottedPlant, scale: float, draw_pot: bool) -> void:
	var pg := g.copy()
	pg.scale_x = scale
	pg.scale_y = scale

	var variation := PvZ.VARIATION_NORMAL
	var st := pp.seed_type
	if pp.plant_age == PvZ.PLANTAGE_SPROUT:
		st = PvZ.SEED_SPROUT
		if pp.seed_type != PvZ.SEED_MARIGOLD:
			variation = PvZ.VARIATION_SPROUT_NO_FLOWER
	elif (st == PvZ.SEED_TANGLEKELP or st == PvZ.SEED_SEASHROOM) and pp.which_zen_garden == PvZ.GARDEN_AQUARIUM:
		variation = PvZ.VARIATION_AQUARIUM
	else:
		variation = pp.draw_variation

	var ox := 0.0
	var oy := Plant.plant_draw_height_offset(board, null, st, -1, -1)
	if draw_pot:
		var pot_oy := Plant.plant_draw_height_offset(board, null, PvZ.SEED_FLOWERPOT, -1, -1)
		var pot_var := PvZ.VARIATION_ZEN_GARDEN_WATER if Plant.is_aquatic(st) else PvZ.VARIATION_ZEN_GARDEN
		Plant.draw_seed_type(pg, PvZ.SEED_FLOWERPOT, PvZ.SEED_NONE, pot_var, x, y + pot_oy * scale)

	if pp.facing == PlayerInfo.PottedPlant.FACING_LEFT:
		pg.scale_x = -scale
		ox += 80.0 * scale

	if pp.plant_age == PvZ.PLANTAGE_SMALL:
		ox += 20.0 * pg.scale_x
		oy += 40.0 * pg.scale_y
		pg.scale_x *= 0.5
		pg.scale_y *= 0.5
	elif pp.plant_age == PvZ.PLANTAGE_MEDIUM:
		ox += 10.0 * pg.scale_x
		oy += 20.0 * pg.scale_y
		pg.scale_x *= 0.75
		pg.scale_y *= 0.75

	if draw_pot:
		oy += Plant.plant_flower_pot_height_offset(st, scale)
	oy += plant_potted_draw_height_offset(st, pg.scale_y)
	Plant.draw_seed_type(pg, st, PvZ.SEED_NONE, variation, x + ox, y + oy)

# ================================================================ placing plants
func plant_set_launch_counter(plant: Plant) -> void:
	var t := plant_get_minutes_since_happy(plant)
	var counter_max := Tod.animate_curve(5, 30, t, 3000, 15000, Tod.CURVE_LINEAR)
	plant.launch_counter = Tod.rand_range_int(1800, counter_max)

func place_potted_plant(index: int) -> Plant:
	var pp := potted_plant_from_index(index)
	var st := pp.seed_type
	if pp.plant_age == PvZ.PLANTAGE_SPROUT:
		st = PvZ.SEED_SPROUT

	var need_pot := true
	if garden_type == PvZ.GARDEN_MUSHROOM and not Plant.is_aquatic(st):
		need_pot = false
	elif garden_type == PvZ.GARDEN_AQUARIUM:
		need_pot = false

	if need_pot:
		var pot := board.new_plant(pp.x, pp.y, PvZ.SEED_FLOWERPOT, PvZ.SEED_NONE)
		pot.render_order = Board.make_render_order(PvZ.RENDER_LAYER_PLANT, 0, pot.y)
		pot.state_countdown = 0
		if pot.body_reanim:
			pot.body_reanim.set_frames_for_layer("anim_waterplants" if Plant.is_aquatic(st) else "anim_zengarden")

	var plant := board.new_plant(pp.x, pp.y, st, PvZ.SEED_NONE)
	plant.potted_plant_index = index
	plant.render_order = Board.make_render_order(PvZ.RENDER_LAYER_PLANT, 0, plant.y + 1)
	plant.state_countdown = 0

	var r := plant.body_reanim
	if r and not r.dead:
		if st == PvZ.SEED_SPROUT:
			if pp.seed_type != PvZ.SEED_MARIGOLD:
				r.set_frames_for_layer("anim_idle_noflower")
		elif (st == PvZ.SEED_TANGLEKELP or st == PvZ.SEED_SEASHROOM) and garden_type == PvZ.GARDEN_AQUARIUM:
			r.set_frames_for_layer("anim_idle_aquarium")
		elif pp.draw_variation != PvZ.VARIATION_NORMAL:
			ReanimatorCache.update_reanimation_for_variation(r, pp.draw_variation)
		plant.update_reanim()
		r.update()

	plant_set_launch_counter(plant)
	update_plant_effect_state(plant)
	return plant

func remove_potted_plant(plant: Plant) -> void:
	plant.die()
	var pot := board.get_top_plant_at(plant.plant_col, plant.row, PvZ.TOPPLANT_ONLY_UNDER_PLANT)
	if pot:
		pot.die()

func potted_plant_from_index(index: int) -> PlayerInfo.PottedPlant:
	return App.player_info.potted_plants[index]

func zen_garden_init_level(_just_switching_gardens: bool) -> void:
	board = App.board
	board.show_shovel = false
	for i in App.player_info.num_potted_plants():
		if potted_plant_from_index(i).which_zen_garden == garden_type:
			place_potted_plant(i)
	board.challenge.challenge_state_counter = 3000
	add_stinky()
	App.music.start_game_music()

func zen_garden_start() -> void:
	pass

func plant_can_have_chocolate(plant: Plant) -> bool:
	var pp := potted_plant_from_index(plant.potted_plant_index)
	return pp.plant_age == PvZ.PLANTAGE_FULL and was_plant_need_fulfilled_today(pp) and not plant_high_on_chocolate(pp)

func can_drop_chocolate() -> bool:
	return has_purchased_stinky() and _purchases()[PvZ.STORE_ITEM_CHOCOLATE] - PURCHASE_COUNT_OFFSET < 10

func is_zen_garden_full(include_dropped_presents: bool) -> bool:
	var dropped := 0
	if board and App.board == board and include_dropped_presents:
		dropped += board.count_coin_by_type(PvZ.COIN_AWARD_PRESENT)
		dropped += board.count_coin_by_type(PvZ.COIN_PRESENT_PLANT)
	var in_garden := 0
	for pp in App.player_info.potted_plants:
		if pp.which_zen_garden == PvZ.GARDEN_MAIN:
			in_garden += 1
	return dropped + in_garden >= ZEN_MAX_GRIDSIZE_X * ZEN_MAX_GRIDSIZE_Y

func can_drop_potted_plant_loot() -> bool:
	return App.has_finished_adventure() and not is_zen_garden_full(true)

func find_open_zen_garden_spot() -> Vector2i:
	var picks: Array = []
	for x in ZEN_MAX_GRIDSIZE_X:
		for y in ZEN_MAX_GRIDSIZE_Y:
			if App.crazy_dave_message_index != -1 and (x < 2 or y < 1):
				continue
			var occupied := false
			for pp in App.player_info.potted_plants:
				if pp.which_zen_garden == PvZ.GARDEN_MAIN and pp.x == x and pp.y == y:
					occupied = true
					break
			if not occupied:
				picks.append({"x": x, "y": y, "weight": 1})
	var spot = Tod.pick_from_weighted_grid_array(picks)
	if spot == null:
		return Vector2i.ZERO
	return Vector2i(spot.x, spot.y)

func add_potted_plant(src: PlayerInfo.PottedPlant) -> void:
	var pi := App.player_info
	if pi.num_potted_plants() >= PlayerInfo.MAX_POTTED_PLANTS:
		return
	var index := pi.num_potted_plants()
	var pp := PlayerInfo.PottedPlant.new()
	pp.from_dict(src.to_dict())
	pp.which_zen_garden = PvZ.GARDEN_MAIN
	pp.last_watered_time = 0
	var spot := find_open_zen_garden_spot()
	pp.x = spot.x
	pp.y = spot.y
	pi.potted_plants.append(pp)

	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN and board and App.board == board and pp.which_zen_garden == garden_type:
		var plant := place_potted_plant(index)
		if App.get_dialog(PvZ.DIALOG_STORE) == null:
			board.do_planting_effects(pp.x, pp.y, plant)

func get_plant_sell_price(plant: Plant) -> int:
	var pp := potted_plant_from_index(plant.potted_plant_index)
	if pp.seed_type == PvZ.SEED_MARIGOLD:
		match pp.plant_age:
			PvZ.PLANTAGE_SPROUT: return 150
			PvZ.PLANTAGE_SMALL: return 200
			PvZ.PLANTAGE_MEDIUM: return 250
			PvZ.PLANTAGE_FULL: return 300
	match pp.plant_age:
		PvZ.PLANTAGE_SPROUT: return 150
		PvZ.PLANTAGE_SMALL: return 300
		PvZ.PLANTAGE_MEDIUM: return 500
		PvZ.PLANTAGE_FULL:
			if Plant.is_nocturnal(pp.seed_type) or Plant.is_aquatic(pp.seed_type):
				return 1000
			return 800
	return 0

func mouse_down_with_money_sign(plant: Plant) -> void:
	board.clear_cursor()
	var header := TodStrings.translate("[ZEN_SELL_HEADER]")
	var lines := TodStrings.translate("[ZEN_SELL_LINES]")
	var price := get_plant_sell_price(plant)
	if App.crazy_dave_state == PvZ.CRAZY_DAVE_OFF:
		App.crazy_dave_enter()

	var pp := potted_plant_from_index(plant.potted_plant_index)
	var msg := App.get_crazy_dave_text(1700)
	msg = Tod.replace_number_string(msg, "{SELL_PRICE}", price)
	var plant_name: String
	if plant.seed_type == PvZ.SEED_SPROUT and pp.seed_type == PvZ.SEED_MARIGOLD:
		plant_name = TodStrings.translate("[MARIGOLD_SPROUT]")
	else:
		plant_name = Plant.get_name_string(plant.seed_type, plant.imitater_type)
	msg = Tod.replace_string(msg, "{PLANT_TYPE}", plant_name)

	App.crazy_dave_talk_message(msg)
	var dave := App.crazy_dave_reanim
	if dave and not dave.dead:
		dave.play_reanim("anim_blahblah", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 12.0)

	var dialog := App.do_dialog(PvZ.DIALOG_ZEN_SELL, true, header, lines, "", Dialog.BUTTONS_YES_NO)
	dialog.x += 120
	dialog.y += 60
	board.show_coin_bank()
	var result := await dialog.wait_for_result(true)
	App.crazy_dave_leave()

	if result == Dialog.ID_YES:
		App.player_info.add_coins(price)
		board.coins_collected += price
		var sold_index := plant.potted_plant_index
		App.player_info.potted_plants.remove_at(sold_index)
		for p in board.plants:
			if not p.dead and p.potted_plant_index > sold_index:
				p.potted_plant_index -= 1
		App.play_foley(PvZ.FOLEY_USE_SHOVEL)
		remove_potted_plant(plant)

func plant_fertilized(plant: Plant) -> void:
	var pp := potted_plant_from_index(plant.potted_plant_index)
	pp.last_fertilized_time = _now()
	pp.plant_age += 1
	pp.plant_need = PvZ.PLANTNEED_NONE
	pp.times_fed = 0

	if pp.plant_age == PvZ.PLANTAGE_SMALL:
		remove_potted_plant(plant)
		place_potted_plant(plant.potted_plant_index)
		App.play_sample("SOUND_LOADINGBAR_FLOWER")
	else:
		plant.state_countdown = 100
		App.play_foley(PvZ.FOLEY_PLANTGROW)

	App.play_foley(PvZ.FOLEY_SPAWN_SUN)
	if pp.plant_age == PvZ.PLANTAGE_SMALL:
		board.add_coin(plant.x + 40, plant.y, PvZ.COIN_GOLD, PvZ.COIN_MOTION_COIN)
	elif pp.plant_age == PvZ.PLANTAGE_MEDIUM:
		board.add_coin(plant.x + 30, plant.y, PvZ.COIN_GOLD, PvZ.COIN_MOTION_COIN)
		board.add_coin(plant.x + 50, plant.y, PvZ.COIN_GOLD, PvZ.COIN_MOTION_COIN)
	elif pp.plant_age == PvZ.PLANTAGE_FULL:
		if pp.seed_type == PvZ.SEED_MARIGOLD:
			board.add_coin(plant.x + 40, plant.y, PvZ.COIN_DIAMOND, PvZ.COIN_MOTION_COIN)
		else:
			board.add_coin(plant.x + 10, plant.y, PvZ.COIN_DIAMOND, PvZ.COIN_MOTION_COIN)
			board.add_coin(plant.x + 70, plant.y, PvZ.COIN_DIAMOND, PvZ.COIN_MOTION_COIN)

func plant_fulfill_need(plant: Plant) -> void:
	var pp := potted_plant_from_index(plant.potted_plant_index)
	pp.last_need_fulfilled_time = _now()
	pp.plant_need = PvZ.PLANTNEED_NONE
	pp.times_fed = 0
	App.play_foley(PvZ.FOLEY_PRIZE)
	App.play_foley(PvZ.FOLEY_SPAWN_SUN)
	board.add_coin(plant.x + 40, plant.y, PvZ.COIN_GOLD, PvZ.COIN_MOTION_COIN)
	if Plant.is_nocturnal(plant.seed_type) or Plant.is_aquatic(plant.seed_type):
		board.add_coin(plant.x + 10, plant.y, PvZ.COIN_GOLD, PvZ.COIN_MOTION_COIN)
		board.add_coin(plant.x + 70, plant.y, PvZ.COIN_GOLD, PvZ.COIN_MOTION_COIN)

func plants_need_water() -> bool:
	for pp in App.player_info.potted_plants:
		if get_plants_need(pp) == PvZ.PLANTNEED_WATER:
			return true
	return false

func plant_can_be_watered(plant: Plant) -> bool:
	if plant.potted_plant_index == -1:
		return false
	return get_plants_need(potted_plant_from_index(plant.potted_plant_index)) == PvZ.PLANTNEED_WATER

func count_plants_needing_fertilizer() -> int:
	var n := 0
	for pp in App.player_info.potted_plants:
		if get_plants_need(pp) == PvZ.PLANTNEED_FERTILIZER:
			n += 1
	return n

func all_plants_have_been_fertilized() -> bool:
	for pp in App.player_info.potted_plants:
		if pp.plant_age == PvZ.PLANTAGE_SPROUT:
			return false
	return true

func plant_watered(plant: Plant) -> void:
	var pp := potted_plant_from_index(plant.potted_plant_index)
	pp.times_fed += 1
	var span := Tod.rand_range_int(0, 8)
	if board.tutorial_state == PvZ.TUTORIAL_ZEN_GARDEN_WATER_PLANT or board.tutorial_state == PvZ.TUTORIAL_ZEN_GARDEN_KEEP_WATERING:
		span = 9
	pp.last_watered_time = _now() - span

	App.play_foley(PvZ.FOLEY_SPAWN_SUN)
	board.add_coin(plant.x + 40, plant.y, PvZ.COIN_SILVER, PvZ.COIN_MOTION_COIN)
	if pp.plant_age == PvZ.PLANTAGE_FULL and pp.plant_need == PvZ.PLANTNEED_NONE:
		pp.plant_need = Tod.rand_range_int(PvZ.PLANTNEED_BUGSPRAY, PvZ.PLANTNEED_PHONOGRAPH)

	if board.tutorial_state == PvZ.TUTORIAL_ZEN_GARDEN_WATER_PLANT:
		board.tutorial_state = PvZ.TUTORIAL_ZEN_GARDEN_KEEP_WATERING
		board.display_advice("[ADVICE_ZEN_GARDEN_KEEP_WATERING]", PvZ.MESSAGE_STYLE_ZEN_GARDEN_LONG, PvZ.ADVICE_NONE)

func update_plant_effect_state(plant: Plant) -> void:
	var pp := potted_plant_from_index(plant.potted_plant_index)
	var original := plant.state
	var need := get_plants_need(pp)
	if need == PvZ.PLANTNEED_WATER:
		plant.state = PvZ.STATE_NOTREADY
	elif need == PvZ.PLANTNEED_NONE:
		if was_plant_need_fulfilled_today(pp):
			plant.state = PvZ.STATE_ZEN_GARDEN_HAPPY
		elif plant.is_asleep:
			plant.state = PvZ.STATE_NOTREADY
		else:
			plant.state = PvZ.STATE_ZEN_GARDEN_WATERED
	else:
		plant.state = PvZ.STATE_ZEN_GARDEN_NEEDY
	if original == plant.state:
		return

	var pot := board.get_top_plant_at(plant.plant_col, plant.row, PvZ.TOPPLANT_ONLY_UNDER_PLANT)
	if pot and not Plant.is_aquatic(plant.seed_type) and pot.body_reanim:
		if plant.state in [PvZ.STATE_ZEN_GARDEN_WATERED, PvZ.STATE_ZEN_GARDEN_NEEDY, PvZ.STATE_ZEN_GARDEN_HAPPY]:
			pot.body_reanim.set_image_override("Pot_top", Res.get_image("IMAGE_REANIM_POT_TOP_DARK"))
		else:
			pot.body_reanim.set_image_override("Pot_top", null)
	if original == PvZ.STATE_ZEN_GARDEN_HAPPY:
		remove_happy_effect(plant)

	if plant.state == PvZ.STATE_ZEN_GARDEN_HAPPY:
		plant.set_sleeping(false)
		add_happy_effect(plant)
	elif Plant.is_nocturnal(plant.seed_type) and not board.stage_is_night():
		plant.set_sleeping(true)

func add_happy_effect(plant: Plant) -> void:
	var pot := board.get_top_plant_at(plant.plant_col, plant.row, PvZ.TOPPLANT_ONLY_UNDER_PLANT)
	if pot == null:
		plant.add_attached_particle(plant.x + 40, plant.y + 60, plant.render_order - 1, PvZ.PARTICLE_POTTED_ZEN_GLOW)
	elif Plant.is_aquatic(plant.seed_type):
		pot.add_attached_particle(pot.x + 40, pot.y + 61, pot.render_order - 1, PvZ.PARTICLE_POTTED_WATER_PLANT_GLOW)
	else:
		pot.add_attached_particle(pot.x + 40, pot.y + 63, pot.render_order - 1, PvZ.PARTICLE_POTTED_ZEN_GLOW)

func remove_happy_effect(plant: Plant) -> void:
	var pot := board.get_top_plant_at(plant.plant_col, plant.row, PvZ.TOPPLANT_ONLY_UNDER_PLANT)
	var ps: TodParticleSystem = pot.particle if pot else plant.particle
	if ps and not ps.dead:
		ps.particle_system_die()

func was_plant_need_fulfilled_today(pp: PlayerInfo.PottedPlant) -> bool:
	var now := _now()
	if now - pp.last_need_fulfilled_time < 3600:
		return true
	var a := _local_year_yday(now)
	var b := _local_year_yday(pp.last_need_fulfilled_time)
	return a[0] <= b[0] and a[1] <= b[1]

func plant_should_refresh_need(pp: PlayerInfo.PottedPlant) -> bool:
	var now := _now()
	if now - pp.last_watered_time < 3600:
		return false
	var a := _local_year_yday(now)
	var b := _local_year_yday(pp.last_watered_time)
	return a[0] > b[0] or a[1] > b[1]

func refresh_plant_needs(pp: PlayerInfo.PottedPlant) -> void:
	if pp.plant_age != PvZ.PLANTAGE_FULL or not plant_should_refresh_need(pp):
		return
	if Plant.is_aquatic(pp.seed_type):
		pp.last_watered_time = _now()
		pp.plant_need = Tod.rand_range_int(PvZ.PLANTNEED_BUGSPRAY, PvZ.PLANTNEED_PHONOGRAPH)
	else:
		pp.times_fed = 0
		pp.plant_need = PvZ.PLANTNEED_NONE

func update_plant_needs() -> void:
	if App.player_info == null:
		return
	for pp in App.player_info.potted_plants:
		refresh_plant_needs(pp)

func was_plant_fertilized_in_last_hour(pp: PlayerInfo.PottedPlant) -> bool:
	return _now() - pp.last_fertilized_time < 3600

func get_plants_need(pp: PlayerInfo.PottedPlant) -> int:
	if pp.plant_age != PvZ.PLANTAGE_SPROUT and Plant.is_nocturnal(pp.seed_type) and pp.which_zen_garden == PvZ.GARDEN_MAIN:
		return PvZ.PLANTNEED_NONE
	if pp.which_zen_garden == PvZ.GARDEN_WHEELBARROW:
		return PvZ.PLANTNEED_NONE

	var now := _now()
	var too_long := now - pp.last_watered_time > 15
	var too_short := now - pp.last_watered_time < 3

	if was_plant_fertilized_in_last_hour(pp) or was_plant_need_fulfilled_today(pp):
		return PvZ.PLANTNEED_NONE
	if Plant.is_aquatic(pp.seed_type) and pp.plant_age != PvZ.PLANTAGE_SPROUT:
		if pp.plant_age == PvZ.PLANTAGE_FULL:
			if plant_should_refresh_need(pp):
				return PvZ.PLANTNEED_NONE
			return pp.plant_need
		if pp.which_zen_garden != PvZ.GARDEN_AQUARIUM:
			return PvZ.PLANTNEED_NONE
		return PvZ.PLANTNEED_FERTILIZER
	if not too_long:
		return PvZ.PLANTNEED_NONE
	if pp.times_fed < pp.feedings_per_grow:
		return PvZ.PLANTNEED_WATER
	if too_short:
		return PvZ.PLANTNEED_NONE
	if pp.plant_age != PvZ.PLANTAGE_FULL:
		return PvZ.PLANTNEED_FERTILIZER
	if plant_should_refresh_need(pp):
		return PvZ.PLANTNEED_NONE
	if pp.plant_need != PvZ.PLANTNEED_NONE:
		return pp.plant_need
	return PvZ.PLANTNEED_WATER

# ================================================================ tools
func mouse_down_with_feeding_tool(x: int, y: int, cursor_type: int) -> void:
	var to_feed: Plant = null
	for p in board.plants:
		if not p.dead and p.highlighted and p.potted_plant_index != -1:
			to_feed = p
			break

	if cursor_type == PvZ.CURSOR_TYPE_CHOCOLATE:
		var stinky := get_stinky()
		if stinky and stinky.highlighted:
			wake_stinky()
			App.add_tod_particle(stinky.pos_x + 40.0, stinky.pos_y + 40.0, stinky.render_order + 1, PvZ.PARTICLE_PRESENT_PICKUP)
			App.player_info.last_stinky_chocolate_time = _now()
			_purchases()[PvZ.STORE_ITEM_CHOCOLATE] -= 1
			App.play_foley(PvZ.FOLEY_WAKEUP)
			App.play_sample("SOUND_MINDCONTROLLED")
		if to_feed:
			_purchases()[PvZ.STORE_ITEM_CHOCOLATE] -= 1
			feed_chocolate_to_plant(to_feed)
			App.play_foley(PvZ.FOLEY_WAKEUP)

	if to_feed:
		var tool := board.alloc_grid_item()
		tool.grid_item_type = PvZ.GRIDITEM_ZEN_TOOL
		tool.grid_x = to_feed.plant_col
		tool.grid_y = to_feed.row
		tool.pos_x = to_feed.x + 40
		tool.pos_y = to_feed.y + 40
		tool.render_order = Board.make_render_order(PvZ.RENDER_LAYER_ABOVE_UI, 0, 0)

		if cursor_type == PvZ.CURSOR_TYPE_WATERING_CAN:
			if _purchases()[PvZ.STORE_ITEM_GOLD_WATERINGCAN]:
				tool.pos_x = x
				tool.pos_y = y
				var r := App.add_reanimation(x, y, 0, PvZ.REANIM_ZENGARDEN_WATERINGCAN)
				r.play_reanim("anim_water_area", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 8.0)
				tool.grid_item_reanim = r
				tool.grid_item_state = PvZ.GRIDITEM_STATE_ZEN_TOOL_GOLD_WATERING_CAN
			else:
				var r := App.add_reanimation(to_feed.x + 32, to_feed.y, 0, PvZ.REANIM_ZENGARDEN_WATERINGCAN)
				r.play_reanim("anim_water", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 0.0)
				tool.grid_item_reanim = r
				tool.grid_item_state = PvZ.GRIDITEM_STATE_ZEN_TOOL_WATERING_CAN
			App.play_foley(PvZ.FOLEY_WATERING)
		elif cursor_type == PvZ.CURSOR_TYPE_FERTILIZER:
			var r := App.add_reanimation(to_feed.x, to_feed.y, 0, PvZ.REANIM_ZENGARDEN_FERTILIZER)
			r.loop_type = Reanimation.REANIM_PLAY_ONCE_AND_HOLD
			tool.grid_item_reanim = r
			tool.grid_item_state = PvZ.GRIDITEM_STATE_ZEN_TOOL_FERTILIZER
			App.play_foley(PvZ.FOLEY_FERTILIZER)
			_purchases()[PvZ.STORE_ITEM_FERTILIZER] -= 1
		elif cursor_type == PvZ.CURSOR_TYPE_BUG_SPRAY:
			var r := App.add_reanimation(to_feed.x + 54, to_feed.y, 0, PvZ.REANIM_ZENGARDEN_BUGSPRAY)
			r.loop_type = Reanimation.REANIM_PLAY_ONCE_AND_HOLD
			tool.grid_item_reanim = r
			tool.grid_item_state = PvZ.GRIDITEM_STATE_ZEN_TOOL_BUG_SPRAY
			App.play_foley(PvZ.FOLEY_BUGSPRAY)
			_purchases()[PvZ.STORE_ITEM_BUG_SPRAY] -= 1
		elif cursor_type == PvZ.CURSOR_TYPE_PHONOGRAPH:
			var r := App.add_reanimation(to_feed.x + 20, to_feed.y + 34, 0, PvZ.REANIM_ZENGARDEN_PHONOGRAPH)
			r.anim_rate = 20.0
			r.loop_type = Reanimation.REANIM_LOOP
			tool.grid_item_reanim = r
			tool.grid_item_state = PvZ.GRIDITEM_STATE_ZEN_TOOL_PHONOGRAPH
			App.play_foley(PvZ.FOLEY_PHONOGRAPH)

	board.clear_cursor()

func feed_chocolate_to_plant(plant: Plant) -> void:
	var pp := potted_plant_from_index(plant.potted_plant_index)
	pp.last_chocolate_time = _now()
	plant.launch_counter = 60
	App.add_tod_particle(plant.x + 40.0, plant.y + 40.0, plant.render_order + 1, PvZ.PARTICLE_PRESENT_PICKUP)

func do_feeding_tool(x: int, y: int, tool_type: int) -> void:
	if tool_type == PvZ.GRIDITEM_STATE_ZEN_TOOL_GOLD_WATERING_CAN:
		for p in board.plants.duplicate():
			if not p.dead and board.is_plant_in_gold_watering_can_range(x, y, p):
				if get_plants_need(potted_plant_from_index(p.potted_plant_index)) == PvZ.PLANTNEED_WATER:
					plant_watered(p)
		return

	var gx := pixel_to_grid_x(x, y)
	var gy := pixel_to_grid_y(x, y)
	var plant := board.get_top_plant_at(gx, gy, PvZ.TOPPLANT_ZEN_TOOL_ORDER)
	if plant == null:
		return
	var need := get_plants_need(potted_plant_from_index(plant.potted_plant_index))
	if need == PvZ.PLANTNEED_WATER and tool_type == PvZ.GRIDITEM_STATE_ZEN_TOOL_WATERING_CAN:
		plant_watered(plant)
	elif need == PvZ.PLANTNEED_FERTILIZER and tool_type == PvZ.GRIDITEM_STATE_ZEN_TOOL_FERTILIZER:
		plant_fertilized(plant)
	elif need == PvZ.PLANTNEED_BUGSPRAY and tool_type == PvZ.GRIDITEM_STATE_ZEN_TOOL_BUG_SPRAY:
		plant_fulfill_need(plant)
	elif need == PvZ.PLANTNEED_PHONOGRAPH and tool_type == PvZ.GRIDITEM_STATE_ZEN_TOOL_PHONOGRAPH:
		plant_fulfill_need(plant)

	if board.tutorial_state == PvZ.TUTORIAL_ZEN_GARDEN_FERTILIZE_PLANTS and tool_type == PvZ.GRIDITEM_STATE_ZEN_TOOL_FERTILIZER:
		if all_plants_have_been_fertilized():
			App.board.tutorial_state = PvZ.TUTORIAL_ZEN_GARDEN_COMPLETED
			App.board.display_advice("[ADVICE_ZEN_GARDEN_CONTINUE_ADVENTURE]", PvZ.MESSAGE_STYLE_HINT_TALL_FAST, PvZ.ADVICE_NONE)
			board.menu_button.disabled = false
			board.menu_button.btn_no_draw = false
		elif _purchases()[PvZ.STORE_ITEM_FERTILIZER] == PURCHASE_COUNT_OFFSET:
			_purchases()[PvZ.STORE_ITEM_FERTILIZER] = PURCHASE_COUNT_OFFSET + 5
			App.board.display_advice("[ADVICE_ZEN_GARDEN_NEED_MORE_FERTILIZER]", PvZ.MESSAGE_STYLE_HINT_TALL_FAST, PvZ.ADVICE_NONE)

func mouse_down_with_tool(x: int, y: int, cursor_type: int) -> void:
	if cursor_type == PvZ.CURSOR_TYPE_WHEEELBARROW and get_potted_plant_in_wheelbarrow():
		mouse_down_with_full_wheel_barrow(x, y)
		board.clear_cursor()
		return
	if cursor_type in [PvZ.CURSOR_TYPE_WATERING_CAN, PvZ.CURSOR_TYPE_FERTILIZER, PvZ.CURSOR_TYPE_BUG_SPRAY, PvZ.CURSOR_TYPE_PHONOGRAPH, PvZ.CURSOR_TYPE_CHOCOLATE]:
		mouse_down_with_feeding_tool(x, y, cursor_type)
		return

	var plant := board.tool_hit_test(x, y)
	if plant == null or plant.potted_plant_index == -1:
		App.play_foley(PvZ.FOLEY_DROP)
		board.clear_cursor()
		return

	if cursor_type == PvZ.CURSOR_TYPE_MONEY_SIGN:
		mouse_down_with_money_sign(plant)
	elif cursor_type == PvZ.CURSOR_TYPE_WHEEELBARROW:
		mouse_down_with_empty_wheel_barrow(plant)
		board.clear_cursor()
	elif cursor_type == PvZ.CURSOR_TYPE_GLOVE:
		board.cursor_object.type = plant.seed_type
		board.cursor_object.imitater_type = plant.imitater_type
		board.cursor_object.cursor_type = PvZ.CURSOR_TYPE_PLANT_FROM_GLOVE
		board.cursor_object.glove_plant = plant
		App.play_sample("SOUND_TAP")

func move_plant(plant: Plant, gx: int, gy: int) -> void:
	if App.game_mode != PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
		return
	var px := board.grid_to_pixel_x(gx, gy)
	var py := board.grid_to_pixel_y(gx, gy)

	plant.set_sleeping(false)
	var pot := board.get_top_plant_at(plant.plant_col, plant.row, PvZ.TOPPLANT_ONLY_UNDER_PLANT)
	if pot:
		pot.x = px
		pot.y = py
		pot.plant_col = gx
		pot.row = gy
		pot.render_order = Board.make_render_order(PvZ.RENDER_LAYER_PLANT, 0, py)
	var dx := float(px - plant.x)
	var dy := float(py - plant.y)
	plant.x = px
	plant.y = py
	plant.plant_col = gx
	plant.row = gy
	plant.render_order = Board.make_render_order(PvZ.RENDER_LAYER_PLANT, 0, py + 1)

	var ps := plant.particle
	if ps and not ps.dead and ps.emitters.size() > 0:
		var em = ps.emitters[0]
		ps.system_move(em.system_center.x + dx, em.system_center.y + dy)

	var pp := potted_plant_from_index(plant.potted_plant_index)
	pp.x = gx
	pp.y = gy
	if plant.state == PvZ.STATE_ZEN_GARDEN_HAPPY:
		remove_happy_effect(plant)
		add_happy_effect(plant)

	board.do_planting_effects(gx, gy, pot if pot else plant)

static func plant_potted_draw_height_offset(st: int, scale: float) -> float:
	var fix := 0.0
	var height := 0.0
	if st == PvZ.SEED_GRAVEBUSTER:
		height += 50.0; fix += 15.0
	elif st == PvZ.SEED_PUFFSHROOM:
		height += 10.0; fix += 24.0
	elif st == PvZ.SEED_SUNSHROOM:
		height += 10.0; fix += 17.0
	elif st == PvZ.SEED_SCAREDYSHROOM:
		height += 5.0; fix += 5.0
	elif st == PvZ.SEED_TANGLEKELP:
		height -= 18.0; fix += 20.0
	elif st == PvZ.SEED_SEASHROOM:
		height -= 20.0; fix += 15.0
	elif st == PvZ.SEED_LILYPAD:
		height -= 10.0; fix += 30.0
	elif st == PvZ.SEED_CHOMPER:
		fix += 0.0
	elif st in [PvZ.SEED_HYPNOSHROOM, PvZ.SEED_MARIGOLD, PvZ.SEED_PEASHOOTER, PvZ.SEED_REPEATER, PvZ.SEED_LEFTPEATER,
			PvZ.SEED_SNOWPEA, PvZ.SEED_THREEPEATER, PvZ.SEED_SUNFLOWER]:
		fix += 10.0
	elif st == PvZ.SEED_STARFRUIT:
		height += 10.0; fix += 24.0
	elif st == PvZ.SEED_CABBAGEPULT or st == PvZ.SEED_MELONPULT:
		fix += 10.0; height += 3.0
	elif st == PvZ.SEED_POTATOMINE:
		fix += 5.0
	elif st == PvZ.SEED_TORCHWOOD:
		fix += 3.0
	elif st == PvZ.SEED_SPIKEWEED:
		fix += 10.0; height -= 13.0
	elif st == PvZ.SEED_BLOVER:
		fix += 10.0
	elif st == PvZ.SEED_PUMPKINSHELL:
		fix += 20.0
	elif st == PvZ.SEED_PLANTERN:
		fix -= 1.0
	return height + (fix * scale - fix)

static func zen_plant_offset_x(pp: PlayerInfo.PottedPlant) -> float:
	var ox := 0
	if pp.facing == PlayerInfo.PottedPlant.FACING_LEFT and pp.seed_type == PvZ.SEED_POTATOMINE:
		ox -= 6
	return ox

# ================================================================ stinky
func has_purchased_stinky() -> bool:
	return _purchases()[PvZ.STORE_ITEM_STINKY_THE_SNAIL] != 0

func add_stinky() -> void:
	if not has_purchased_stinky() or garden_type != PvZ.GARDEN_MAIN:
		return
	var pi := App.player_info
	if not pi.has_seen_stinky:
		pi.has_seen_stinky = 1
		_purchases()[PvZ.STORE_ITEM_STINKY_THE_SNAIL] = _now()

	var stinky := board.alloc_grid_item()
	stinky.grid_item_type = PvZ.GRIDITEM_STINKY
	stinky.pos_x = pi.stinky_pos_x
	stinky.pos_y = pi.stinky_pos_y
	stinky.goal_x = stinky.pos_x
	stinky.goal_y = stinky.pos_y
	var r := App.add_reanimation(stinky.pos_x, stinky.pos_y, 0, PvZ.REANIM_STINKY)
	r.override_scale(0.8, 0.8)
	stinky.grid_item_reanim = r

	if pi.stinky_pos_x == 0:
		stinky_pick_goal(stinky)
		stinky.pos_x = stinky.goal_x
		stinky.pos_y = stinky.goal_y

	if should_stinky_be_awake():
		r.play_reanim("anim_crawl", Reanimation.REANIM_LOOP, 0, 6.0)
		stinky.grid_item_state = PvZ.GRIDITEM_STINKY_WALKING_LEFT
	else:
		stinky.pos_y = STINKY_SLEEP_POS_Y
		stinky_finish_falling_asleep(stinky, 0)

	stinky.render_order = Board.make_render_order(PvZ.RENDER_LAYER_PLANT, 0, int(stinky.pos_y - 30.0))
	r.set_position(stinky.pos_x, stinky.pos_y)

func stinky_pick_goal(stinky: GridItem) -> void:
	var cur_dist := Tod.distance_2d(stinky.goal_x, stinky.goal_y, stinky.pos_x, stinky.pos_y)
	var best: Coin = null
	var best_weight := 0.0
	for c in board.coins:
		if c.dead or c.is_being_collected or c.pos_y != c.ground_y:
			continue
		var w := Tod.distance_2d(c.pos_x, c.pos_y + 30.0, stinky.pos_x, stinky.pos_y)
		if c.type == PvZ.COIN_GOLD:
			w -= 40.0
		elif c.type == PvZ.COIN_DIAMOND:
			w -= 80.0
		if Tod.distance_2d(c.pos_x, c.pos_y + 30.0, stinky.goal_x, stinky.goal_y) < 5.0:
			w -= 20.0
			w += Tod.animate_curve(3000, 6000, c.disappear_counter, 0, -40, Tod.CURVE_LINEAR)
		if best == null or w < best_weight:
			best = c
			best_weight = w

	if best:
		stinky.goal_x = best.pos_x
		stinky.goal_y = best.pos_y + 30.0
	else:
		if cur_dist > 10.0:
			return
		var picks: Array = []
		for g in get_special_grid_placements():
			var p := board.get_top_plant_at(g[2], g[3], PvZ.TOPPLANT_ANY)
			var pick := {"x": g[0] + 15, "y": g[1] + 80, "weight": 1}
			if p:
				pick.weight = 2000 - absi(int(pick.y - stinky.pos_y))
			picks.append(pick)
		var target = Tod.pick_from_weighted_grid_array(picks)
		if target == null:
			return
		stinky.goal_x = target.x
		stinky.goal_y = target.y

	stinky.grid_item_counter = 100
	var r := stinky.grid_item_reanim
	if stinky.goal_x < stinky.pos_x and stinky.grid_item_state == PvZ.GRIDITEM_STINKY_WALKING_RIGHT:
		stinky.grid_item_state = PvZ.GRIDITEM_STINKY_TURNING_LEFT
		r.play_reanim("turn", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 10, 6.0)
		stinky.motion_trail_count = 0
	elif stinky.goal_x > stinky.pos_x and stinky.grid_item_state == PvZ.GRIDITEM_STINKY_WALKING_LEFT:
		stinky.grid_item_state = PvZ.GRIDITEM_STINKY_TURNING_RIGHT
		r.play_reanim("turn", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 10, 6.0)
		stinky.motion_trail_count = 0

func stinky_wake_up(stinky: GridItem) -> void:
	var r := stinky.grid_item_reanim
	r.play_reanim("anim_out", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 6.0)
	stinky.grid_item_state = PvZ.GRIDITEM_STINKY_WAKING_UP
	var sleeping := Attachment.find_reanim_attachment(r.get_track_instance("shell"))
	if sleeping:
		sleeping.die()
	App.player_info.has_woken_stinky = 1

func stinky_start_falling_asleep(stinky: GridItem) -> void:
	stinky.grid_item_reanim.play_reanim("anim_in", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 6.0)
	stinky.grid_item_state = PvZ.GRIDITEM_STINKY_FALLING_ASLEEP

func stinky_finish_falling_asleep(stinky: GridItem, blend_time: int) -> void:
	var r := stinky.grid_item_reanim
	r.play_reanim("anim_out", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, blend_time, 0.0)
	r.anim_rate = 0.0
	var sleeping := App.add_reanimation(0.0, 0.0, 0, PvZ.REANIM_SLEEPING)
	sleeping.anim_rate = 3.0
	sleeping.loop_type = Reanimation.REANIM_LOOP
	Attachment.attach_reanim(r.get_track_instance("shell"), sleeping, 34.0, 39.0)
	stinky.grid_item_state = PvZ.GRIDITEM_STINKY_SLEEPING
	if not App.player_info.has_woken_stinky:
		App.board.display_advice("[ADVICE_STINKY_SLEEPING]", PvZ.MESSAGE_STYLE_HINT_LONG, PvZ.ADVICE_STINKY_SLEEPING)

func update_stinky_motion_trail(stinky: GridItem, high_on_chocolate: bool) -> void:
	if not high_on_chocolate or (stinky.grid_item_state != PvZ.GRIDITEM_STINKY_WALKING_RIGHT and stinky.grid_item_state != PvZ.GRIDITEM_STINKY_WALKING_LEFT):
		stinky.motion_trail_count = 0
		return
	while stinky.motion_trail_count >= NUM_MOTION_TRAIL_FRAMES:
		stinky.motion_trail_count -= 1
	for i in range(stinky.motion_trail_count, 0, -1):
		stinky.motion_trail_frames[i] = stinky.motion_trail_frames[i - 1].duplicate()
	stinky.motion_trail_frames[0] = [stinky.pos_x, stinky.pos_y, stinky.grid_item_reanim.anim_time]
	stinky.motion_trail_count += 1

func stinky_anim_rate_update(stinky: GridItem) -> void:
	if stinky.grid_item_state in [PvZ.GRIDITEM_STINKY_WALKING_LEFT, PvZ.GRIDITEM_STINKY_WALKING_RIGHT,
			PvZ.GRIDITEM_STINKY_TURNING_RIGHT, PvZ.GRIDITEM_STINKY_TURNING_LEFT]:
		stinky.grid_item_reanim.anim_rate = 12.0 if is_stinky_high_on_chocolate() else 6.0

func reset_stinky_timers() -> void:
	_purchases()[PvZ.STORE_ITEM_STINKY_THE_SNAIL] = 2
	App.player_info.last_stinky_chocolate_time = 0

func stinky_update(stinky: GridItem) -> void:
	var r := stinky.grid_item_reanim
	if r == null or r.dead:
		return
	var now := _now()
	if App.player_info.last_stinky_chocolate_time > now or _purchases()[PvZ.STORE_ITEM_STINKY_THE_SNAIL] > now:
		reset_stinky_timers()

	var high := is_stinky_high_on_chocolate()
	update_stinky_motion_trail(stinky, high)

	if stinky.grid_item_state == PvZ.GRIDITEM_STINKY_FALLING_ASLEEP:
		if r.loop_count > 0:
			stinky_finish_falling_asleep(stinky, 20)
		return

	if stinky.grid_item_state == PvZ.GRIDITEM_STINKY_SLEEPING:
		var sleeping := Attachment.find_reanim_attachment(r.get_track_instance("shell"))
		if sleeping:
			if board.cursor_object.cursor_type == PvZ.CURSOR_TYPE_CHOCOLATE:
				sleeping.assign_render_group_to_prefix("z", Reanimation.RENDER_GROUP_HIDDEN)
			else:
				sleeping.assign_render_group_to_prefix("z", Reanimation.RENDER_GROUP_NORMAL)
		if should_stinky_be_awake():
			stinky_wake_up(stinky)
		return

	if stinky.grid_item_state == PvZ.GRIDITEM_STINKY_WAKING_UP:
		if r.loop_count > 0:
			stinky.grid_item_state = PvZ.GRIDITEM_STINKY_WALKING_LEFT
			r.play_reanim("anim_crawl", Reanimation.REANIM_LOOP, 10, 6.0)
			stinky_pick_goal(stinky)
		return

	if not should_stinky_be_awake():
		if stinky.pos_y < STINKY_SLEEP_POS_Y:
			if stinky.goal_y != STINKY_SLEEP_POS_Y:
				stinky.goal_y = STINKY_SLEEP_POS_Y + 10.0
		else:
			if stinky.grid_item_state == PvZ.GRIDITEM_STINKY_WALKING_LEFT:
				stinky_start_falling_asleep(stinky)
				return
			elif stinky.grid_item_state == PvZ.GRIDITEM_STINKY_WALKING_RIGHT:
				stinky.grid_item_state = PvZ.GRIDITEM_STINKY_TURNING_LEFT
				r.play_reanim("turn", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 10, 6.0)
				stinky.motion_trail_count = 0
				stinky.goal_x = stinky.pos_x
				stinky.goal_y = stinky.pos_y
				return

	if stinky.grid_item_counter > 0:
		stinky.grid_item_counter -= 1

	for c in board.coins.duplicate():
		if not c.dead and not c.is_being_collected and Tod.distance_2d(c.pos_x, c.pos_y + 30.0, stinky.pos_x, stinky.pos_y) < 20.0:
			c.play_collect_sound()
			c.collect()

	if stinky.grid_item_state == PvZ.GRIDITEM_STINKY_WALKING_LEFT or stinky.grid_item_state == PvZ.GRIDITEM_STINKY_WALKING_RIGHT:
		if board.cursor_object.cursor_type == PvZ.CURSOR_TYPE_CHOCOLATE and not is_stinky_high_on_chocolate():
			if not r.is_anim_playing("anim_idle"):
				r.play_reanim("anim_idle", Reanimation.REANIM_LOOP, 10, 6.0)
		elif not r.is_anim_playing("anim_crawl"):
			r.play_reanim("anim_crawl", Reanimation.REANIM_LOOP, 10, 6.0)

	var dx := stinky.pos_x - stinky.goal_x
	var dy := stinky.pos_y - stinky.goal_y
	var speed_y := 0.5
	var speed_x := r.get_track_velocity("_ground") * 15.0
	if high:
		speed_y = 1.0
		speed_x = maxf(speed_x, 0.5)
	elif board.cursor_object.cursor_type == PvZ.CURSOR_TYPE_CHOCOLATE:
		speed_y = 0.0
		speed_x = 0.0
	speed_y *= Tod.animate_curve_float_time(20.0, 5.0, absf(dy), 1.0, 0.2, Tod.CURVE_LINEAR)
	if stinky.grid_item_state == PvZ.GRIDITEM_STINKY_WALKING_LEFT:
		stinky.pos_x -= speed_x
		if stinky.pos_x < stinky.goal_x:
			stinky.pos_x = stinky.goal_x
	elif stinky.grid_item_state == PvZ.GRIDITEM_STINKY_WALKING_RIGHT:
		stinky.pos_x += speed_x
		if stinky.pos_x > stinky.goal_x:
			stinky.pos_x = stinky.goal_x

	if stinky.grid_item_state == PvZ.GRIDITEM_STINKY_WALKING_LEFT or stinky.grid_item_state == PvZ.GRIDITEM_STINKY_WALKING_RIGHT:
		if absf(dy) < speed_y:
			stinky.pos_y = stinky.goal_y
		elif dy > 0.0:
			stinky.pos_y -= speed_y
		else:
			stinky.pos_y += speed_y
		if absf(dx) < 5.0 and absf(dy) < 5.0:
			stinky_pick_goal(stinky)
		elif stinky.grid_item_counter == 0:
			stinky_pick_goal(stinky)

	if stinky.grid_item_state == PvZ.GRIDITEM_STINKY_TURNING_LEFT:
		if r.loop_count > 0:
			stinky.grid_item_state = PvZ.GRIDITEM_STINKY_WALKING_LEFT
			r.play_reanim("anim_crawl", Reanimation.REANIM_LOOP, 10, 6.0)
	elif stinky.grid_item_state == PvZ.GRIDITEM_STINKY_TURNING_RIGHT:
		if r.loop_count > 0:
			stinky.grid_item_state = PvZ.GRIDITEM_STINKY_WALKING_RIGHT
			r.play_reanim("anim_crawl", Reanimation.REANIM_LOOP, 10, 6.0)

	stinky_anim_rate_update(stinky)
	if stinky.grid_item_state == PvZ.GRIDITEM_STINKY_WALKING_RIGHT or stinky.grid_item_state == PvZ.GRIDITEM_STINKY_TURNING_LEFT:
		r.override_scale(-0.8, 0.8)
		r.set_position(stinky.pos_x + 69.0, stinky.pos_y)
	else:
		r.override_scale(0.8, 0.8)
		r.set_position(stinky.pos_x, stinky.pos_y)
	stinky.render_order = Board.make_render_order(PvZ.RENDER_LAYER_PLANT, 0, int(stinky.pos_y - 30.0))

func zen_tool_update(tool: GridItem) -> void:
	var r := tool.grid_item_reanim
	if r == null or r.dead:
		return
	var play_time := 2 if tool.grid_item_state == PvZ.GRIDITEM_STATE_ZEN_TOOL_PHONOGRAPH else 1
	if r.loop_count >= play_time:
		do_feeding_tool(int(tool.pos_x), int(tool.pos_y), tool.grid_item_state)
		tool.grid_item_die()

func zen_garden_update() -> void:
	if App.get_dialog(PvZ.DIALOG_STORE):
		return
	App.update_crazy_dave()
	var ch := board.challenge
	if board.cursor_object.cursor_type != PvZ.CURSOR_TYPE_NORMAL:
		ch.challenge_state = PvZ.STATECHALLENGE_NORMAL
		ch.challenge_state_counter = 3000
	elif App.board.tutorial_state == PvZ.TUTORIAL_OFF:
		if ch.challenge_state_counter > 0:
			ch.challenge_state_counter -= 1
		if ch.challenge_state == PvZ.STATECHALLENGE_NORMAL and ch.challenge_state_counter == 0:
			ch.challenge_state = PvZ.STATECHALLENGE_ZEN_FADING
			ch.challenge_state_counter = 50

	update_plant_needs()
	for p in board.plants.duplicate():
		if not p.dead and p.potted_plant_index != -1:
			potted_plant_update(p)
	for gi in board.grid_items.duplicate():
		if gi.dead:
			continue
		if gi.grid_item_type == PvZ.GRIDITEM_ZEN_TOOL:
			zen_tool_update(gi)
		elif gi.grid_item_type == PvZ.GRIDITEM_STINKY:
			stinky_update(gi)

	if board.tutorial_state == PvZ.TUTORIAL_ZEN_GARDEN_KEEP_WATERING and count_plants_needing_fertilizer() > 0:
		board.display_advice("[ADVICE_ZEN_GARDEN_VISIT_STORE]", PvZ.MESSAGE_STYLE_HINT_TALL_LONG, PvZ.ADVICE_NONE)
		board.tutorial_state = PvZ.TUTORIAL_ZEN_GARDEN_VISIT_STORE
		board.store_button.disabled = false
		board.store_button.btn_no_draw = false

func get_stinky() -> GridItem:
	if board == null:
		return null
	for gi in board.grid_items:
		if not gi.dead and gi.grid_item_type == PvZ.GRIDITEM_STINKY:
			return gi
	return null

# ================================================================ gardens
func goto_next_garden() -> void:
	leave_garden()
	board.clear_advice(PvZ.ADVICE_NONE)
	for p in board.plants:
		p.dead = true
	board.plants.clear()
	for c in board.coins:
		c.dead = true
	board.coins.clear()
	EffectSystem.free_all()

	var go_to_tree := false
	var pur := _purchases()
	if garden_type == PvZ.GARDEN_MAIN:
		if pur[PvZ.STORE_ITEM_MUSHROOM_GARDEN]:
			garden_type = PvZ.GARDEN_MUSHROOM
			board.background = PvZ.BACKGROUND_MUSHROOM_GARDEN
		elif pur[PvZ.STORE_ITEM_AQUARIUM_GARDEN]:
			garden_type = PvZ.GARDEN_AQUARIUM
			board.background = PvZ.BACKGROUND_ZOMBIQUARIUM
		elif pur[PvZ.STORE_ITEM_TREE_OF_WISDOM]:
			go_to_tree = true
	elif garden_type == PvZ.GARDEN_MUSHROOM:
		if pur[PvZ.STORE_ITEM_AQUARIUM_GARDEN]:
			garden_type = PvZ.GARDEN_AQUARIUM
			board.background = PvZ.BACKGROUND_ZOMBIQUARIUM
		elif pur[PvZ.STORE_ITEM_TREE_OF_WISDOM]:
			go_to_tree = true
		else:
			garden_type = PvZ.GARDEN_MAIN
			board.background = PvZ.BACKGROUND_GREENHOUSE
	elif garden_type == PvZ.GARDEN_AQUARIUM:
		if pur[PvZ.STORE_ITEM_TREE_OF_WISDOM]:
			go_to_tree = true
		else:
			garden_type = PvZ.GARDEN_MAIN
			board.background = PvZ.BACKGROUND_GREENHOUSE
	if go_to_tree:
		App.kill_board()
		App.pre_new_game(PvZ.GAMEMODE_TREE_OF_WISDOM, false)
		return

	if board.background == PvZ.BACKGROUND_MUSHROOM_GARDEN or board.background == PvZ.BACKGROUND_ZOMBIQUARIUM:
		if not pur[PvZ.STORE_ITEM_WHEEL_BARROW]:
			board.display_advice("[ADVICE_NEED_WHEELBARROW]", PvZ.MESSAGE_STYLE_HINT_TALL_FAST, PvZ.ADVICE_NEED_WHEELBARROW)
	zen_garden_init_level(true)

func mouse_down_with_full_wheel_barrow(x: int, y: int) -> void:
	var pp := get_potted_plant_in_wheelbarrow()
	if pp == null:
		return
	if App.zen_garden.garden_type == PvZ.GARDEN_AQUARIUM and not Plant.is_aquatic(pp.seed_type):
		board.display_advice("[ZEN_ONLY_AQUATIC_PLANTS]", PvZ.MESSAGE_STYLE_HINT_TALL_FAST, PvZ.ADVICE_NONE)
		return
	var gx := board.pixel_to_grid_x(x, y)
	var gy := board.pixel_to_grid_y(x, y)
	if gx == -1 or gy == -1 or board.can_plant_at(gx, gy, pp.seed_type) != PvZ.PLANTING_OK:
		return
	pp.which_zen_garden = garden_type
	pp.x = gx
	pp.y = gy
	var index := App.player_info.potted_plants.find(pp)
	var plant := place_potted_plant(index)
	board.do_planting_effects(pp.x, pp.y, plant)

func mouse_down_with_empty_wheel_barrow(plant: Plant) -> void:
	var pp := potted_plant_from_index(plant.potted_plant_index)
	remove_potted_plant(plant)
	pp.which_zen_garden = PvZ.GARDEN_WHEELBARROW
	pp.x = 0
	pp.y = 0
	App.play_foley(PvZ.FOLEY_PLANT)

func get_potted_plant_in_wheelbarrow() -> PlayerInfo.PottedPlant:
	for pp in App.player_info.potted_plants:
		if pp.which_zen_garden == PvZ.GARDEN_WHEELBARROW:
			return pp
	return null

func get_special_grid_placements() -> Array:
	match board.background:
		PvZ.BACKGROUND_MUSHROOM_GARDEN: return MUSHROOM_GRID_PLACEMENT
		PvZ.BACKGROUND_ZOMBIQUARIUM: return AQUARIUM_GRID_PLACEMENT
		PvZ.BACKGROUND_GREENHOUSE: return GREENHOUSE_GRID_PLACEMENT
	return []

func pixel_to_grid_x(x: int, y: int) -> int:
	for g in get_special_grid_placements():
		if x >= g[0] and x <= g[0] + 80 and y >= g[1] and y <= g[1] + 85:
			return g[2]
	return -1

func pixel_to_grid_y(x: int, y: int) -> int:
	for g in get_special_grid_placements():
		if x >= g[0] and x <= g[0] + 80 and y >= g[1] and y <= g[1] + 85:
			return g[3]
	return -1

func grid_to_pixel_x(gx: int, gy: int) -> int:
	for g in get_special_grid_placements():
		if gx == g[2] and gy == g[3]:
			return g[0]
	return -1

func grid_to_pixel_y(gx: int, gy: int) -> int:
	for g in get_special_grid_placements():
		if gx == g[2] and gy == g[3]:
			return g[1]
	return -1

func draw_backdrop(g: Graphics) -> void:
	if garden_type != PvZ.GARDEN_AQUARIUM:
		return
	var ct := board.cursor_object.cursor_type
	if ct == PvZ.CURSOR_TYPE_PLANT_FROM_WHEEL_BARROW or ct == PvZ.CURSOR_TYPE_WHEEELBARROW or ct == PvZ.CURSOR_TYPE_PLANT_FROM_GLOVE:
		for sg in get_special_grid_placements():
			if board.get_top_plant_at(sg[2], sg[3], PvZ.TOPPLANT_ZEN_TOOL_ORDER) == null:
				g.tod_draw_image_cel_scaled(Res.get_image("IMAGE_PLANTSHADOW"), sg[0] - 35, sg[1] + 33, 0, 0, 1.7, 1.7)

func show_tutorial_arrow_on_watering_can() -> void:
	var r := board.get_zen_button_rect(PvZ.OBJECT_TYPE_WATERING_CAN, board.get_shovel_button_rect())
	board.tutorial_arrow_show(r.position.x + 10, r.position.y + 10)
	board.display_advice("[ADVICE_ZEN_GARDEN_PICK_UP_WATER]", PvZ.MESSAGE_STYLE_ZEN_GARDEN_LONG, PvZ.ADVICE_NONE)
	board.tutorial_state = PvZ.TUTORIAL_ZEN_GARDEN_PICKUP_WATER

func advance_crazy_dave_dialog() -> void:
	if App.crazy_dave_message_index == -1 or App.get_dialog(PvZ.DIALOG_STORE) or App.get_dialog(PvZ.DIALOG_ZEN_SELL):
		return
	if App.crazy_dave_message_index == 2104:
		show_tutorial_arrow_on_watering_can()
	if not App.advance_crazy_dave_text():
		App.crazy_dave_leave()
		return
	if App.crazy_dave_message_index == 2102 and App.player_info.num_potted_plants() == 0:
		for i in 2:
			var pp := PlayerInfo.PottedPlant.new()
			pp.initialize_potted_plant(PvZ.SEED_MARIGOLD)
			pp.draw_variation = Tod.rand_range_int(PvZ.VARIATION_MARIGOLD_WHITE, PvZ.VARIATION_MARIGOLD_LIGHT_GREEN)
			pp.feedings_per_grow = 3
			add_potted_plant(pp)

func mouse_down_zen_garden(x: int, y: int, click_count: int, hit: HitResult) -> bool:
	var ch := board.challenge
	if ch.challenge_state == PvZ.STATECHALLENGE_ZEN_FADING:
		ch.challenge_state = PvZ.STATECHALLENGE_NORMAL
	ch.challenge_state_counter = 3000

	var ct := board.cursor_object.cursor_type
	if hit.object_type == PvZ.OBJECT_TYPE_STINKY and ct == PvZ.CURSOR_TYPE_NORMAL:
		wake_stinky()
	elif ct == PvZ.CURSOR_TYPE_GLOVE:
		if board.can_use_game_object(PvZ.OBJECT_TYPE_WHEELBARROW):
			var r := board.get_zen_button_rect(PvZ.OBJECT_TYPE_WHEELBARROW, board.get_shovel_button_rect())
			var pp := get_potted_plant_in_wheelbarrow()
			if r.has_point(Vector2i(x, y)) and pp:
				board.clear_cursor()
				board.cursor_object.type = pp.seed_type
				board.cursor_object.imitater_type = PvZ.SEED_NONE
				board.cursor_object.cursor_type = PvZ.CURSOR_TYPE_PLANT_FROM_WHEEL_BARROW
				return true
	elif ct == PvZ.CURSOR_TYPE_PLANT_FROM_GLOVE:
		if board.can_use_game_object(PvZ.OBJECT_TYPE_WHEELBARROW):
			var r := board.get_zen_button_rect(PvZ.OBJECT_TYPE_WHEELBARROW, board.get_shovel_button_rect())
			var plant: Plant = board.cursor_object.glove_plant
			if plant and not plant.dead and r.has_point(Vector2i(x, y)) and get_potted_plant_in_wheelbarrow() == null:
				mouse_down_with_empty_wheel_barrow(plant)
				board.clear_cursor()
				return true
	elif hit.object_type == PvZ.OBJECT_TYPE_NONE and ct == PvZ.CURSOR_TYPE_NORMAL and garden_type == PvZ.GARDEN_AQUARIUM and click_count <= -1:
		App.play_sample("SOUND_TAPGLASS")

	if App.crazy_dave_message_index != -1:
		advance_crazy_dave_dialog()
		return true
	return false

# ================================================================ plant production
func set_plant_anim_speed(plant: Plant) -> void:
	var body := plant.body_reanim
	if body == null or body.dead:
		return
	var pp := potted_plant_from_index(plant.potted_plant_index)
	var high := plant_high_on_chocolate(pp)
	var at_high_rate := body.anim_rate >= 25.0
	if at_high_rate == high:
		return
	var rate: float
	if plant.seed_type in [PvZ.SEED_PEASHOOTER, PvZ.SEED_SNOWPEA, PvZ.SEED_REPEATER, PvZ.SEED_LEFTPEATER, PvZ.SEED_GATLINGPEA,
			PvZ.SEED_SPLITPEA, PvZ.SEED_THREEPEATER, PvZ.SEED_MARIGOLD]:
		rate = Tod.rand_range_float(15.0, 20.0)
	elif plant.seed_type == PvZ.SEED_POTATOMINE:
		rate = 12.0
	else:
		rate = Tod.rand_range_float(10.0, 15.0)
	if high:
		rate = maxf(25.0, rate * 2.0)
	body.anim_rate = rate
	for h in [plant.head_reanim, plant.head_reanim2, plant.head_reanim3]:
		if h and not h.dead:
			h.anim_rate = body.anim_rate
			h.anim_time = body.anim_time

func plant_get_minutes_since_happy(plant: Plant) -> int:
	var pp := potted_plant_from_index(plant.potted_plant_index)
	var minutes := int((_now() - pp.last_need_fulfilled_time) / 60)
	if plant_high_on_chocolate(pp):
		minutes = 0
	return minutes

func plant_update_production(plant: Plant) -> void:
	plant.launch_counter -= 1
	set_plant_anim_speed(plant)
	var pp := potted_plant_from_index(plant.potted_plant_index)
	if plant_high_on_chocolate(pp):
		plant.launch_counter -= 1
	if plant.launch_counter <= 0:
		plant_set_launch_counter(plant)
		App.play_foley(PvZ.FOLEY_SPAWN_SUN)
		var hit := Tod.rand_int(1000)
		hit += Tod.animate_curve(5, 30, plant_get_minutes_since_happy(plant), 0, 80, Tod.CURVE_LINEAR)
		var coin_type := PvZ.COIN_GOLD if hit < 100 else PvZ.COIN_SILVER
		board.add_coin(plant.x, plant.y, coin_type, PvZ.COIN_MOTION_COIN)

func reset_plant_timers(pp: PlayerInfo.PottedPlant) -> void:
	pp.last_watered_time = 0
	pp.last_need_fulfilled_time = 0
	pp.last_fertilized_time = 0
	pp.last_chocolate_time = 0

func potted_plant_update(plant: Plant) -> void:
	var pp := potted_plant_from_index(plant.potted_plant_index)
	var now := _now()
	if pp.last_watered_time > now or pp.last_need_fulfilled_time > now or pp.last_fertilized_time > now or pp.last_chocolate_time > now:
		reset_plant_timers(pp)
	if plant.is_asleep:
		return
	if plant.state_countdown > 0:
		plant.state_countdown -= 1
	if pp.plant_age == PvZ.PLANTAGE_FULL and was_plant_need_fulfilled_today(pp):
		plant_update_production(plant)
	update_plant_effect_state(plant)

func draw_plant_overlay(g: Graphics, plant: Plant) -> void:
	if plant.potted_plant_index == -1:
		return
	var need := get_plants_need(potted_plant_from_index(plant.potted_plant_index))
	if need == PvZ.PLANTNEED_NONE:
		return
	g.draw_image(Res.get_image("IMAGE_PLANTSPEECHBUBBLE"), 50, 0)
	var icons := Res.get_image("IMAGE_ZEN_NEED_ICONS")
	match need:
		PvZ.PLANTNEED_FERTILIZER: g.draw_image_cel_rc(icons, 61, 7, 0, 0)
		PvZ.PLANTNEED_BUGSPRAY: g.draw_image_cel_rc(icons, 61, 7, 1, 0)
		PvZ.PLANTNEED_PHONOGRAPH: g.draw_image_cel_rc(icons, 60, 7, 2, 0)
		PvZ.PLANTNEED_WATER: g.draw_image(Res.get_image("IMAGE_WATERDROP"), 67, 9)

func wake_stinky() -> void:
	_purchases()[PvZ.STORE_ITEM_STINKY_THE_SNAIL] = _now()
	App.play_sample("SOUND_TAP")
	board.clear_advice(PvZ.ADVICE_STINKY_SLEEPING)
	App.player_info.has_woken_stinky = 1

func is_stinky_high_on_chocolate() -> bool:
	return _now() - App.player_info.last_stinky_chocolate_time < 3600

func plant_high_on_chocolate(pp: PlayerInfo.PottedPlant) -> bool:
	return _now() - pp.last_chocolate_time < 300

func is_stinky_sleeping() -> bool:
	var s := get_stinky()
	return s != null and s.grid_item_state == PvZ.GRIDITEM_STINKY_SLEEPING

func should_stinky_be_awake() -> bool:
	if is_stinky_high_on_chocolate():
		return true
	return _now() - _purchases()[PvZ.STORE_ITEM_STINKY_THE_SNAIL] < 180

func open_store() -> void:
	leave_garden()
	var store := App.show_store_screen()
	if board.tutorial_state == PvZ.TUTORIAL_ZEN_GARDEN_VISIT_STORE:
		store.setup_for_intro(2600)
		_purchases()[PvZ.STORE_ITEM_FERTILIZER] = PURCHASE_COUNT_OFFSET + 5
	store.back_button.label = "[STORE_BACK_TO_GAME]"
	store.page = PvZ.STORE_PAGE_ZEN1
	await store.wait_for_result(true)

	if store.go_to_tree_now:
		App.kill_board()
		App.pre_new_game(PvZ.GAMEMODE_TREE_OF_WISDOM, false)
	else:
		App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_ZEN_GARDEN)
		if board.tutorial_state == PvZ.TUTORIAL_ZEN_GARDEN_VISIT_STORE:
			board.display_advice("[ADVICE_ZEN_GARDEN_FERTILIZE]", PvZ.MESSAGE_STYLE_ZEN_GARDEN_LONG, PvZ.ADVICE_NONE)
			board.tutorial_state = PvZ.TUTORIAL_ZEN_GARDEN_FERTILIZE_PLANTS
		add_stinky()

func setup_for_zen_tutorial() -> void:
	board.menu_button.label = "[CONTINUE_BUTTON]"
	board.store_button.disabled = true
	board.store_button.btn_no_draw = true
	board.menu_button.disabled = true
	board.menu_button.btn_no_draw = true
	App.crazy_dave_enter()
	App.crazy_dave_talk_index(2100)

static func pick_random_seed_type() -> int:
	var seeds: Array = []
	for i in 40:
		if i != PvZ.SEED_MARIGOLD and i != PvZ.SEED_FLOWERPOT:
			seeds.append(i)
	return Tod.pick_from_array(seeds)

func leave_garden() -> void:
	for gi in board.grid_items.duplicate():
		if gi.dead:
			continue
		if gi.grid_item_type == PvZ.GRIDITEM_ZEN_TOOL:
			do_feeding_tool(int(gi.pos_x), int(gi.pos_y), gi.grid_item_state)
			gi.grid_item_die()
		elif gi.grid_item_type == PvZ.GRIDITEM_STINKY:
			App.player_info.stinky_pos_x = int(gi.pos_x)
			App.player_info.stinky_pos_y = int(gi.pos_y)
			gi.grid_item_die()
	for c in board.coins.duplicate():
		if c.dead:
			continue
		if c.is_being_collected:
			c.score_coin()
		else:
			c.die()
