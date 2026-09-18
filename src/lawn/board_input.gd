class_name BoardInput
extends BoardUpdate
## Board part 3: mouse / keyboard handling, cursor, hit testing, planting and tool usage.

const PURCHASE_COUNT_OFFSET := 1000

func update_cursor() -> void:
	if not net_exec_is_local():
		return
	var mx: int = App.widget_manager.last_mouse_x - x
	var my: int = App.widget_manager.last_mouse_y - y
	var show_finger := false
	var hide_cursor := false
	if App.seed_chooser_screen and App.seed_chooser_screen.contains(mx + x, my + y):
		return
	if App.get_dialog_count() > 0:
		return
	if paused or board_fade_out_counter >= 0 or time_stop_counter > 0 or App.game_scene == PvZ.SCENE_ZOMBIES_WON:
		App.set_cursor(App.CURSOR_POINTER)
		return
	var hit := HitResult.new()
	mouse_hit_test(mx, my, hit)
	match hit.object_type:
		PvZ.OBJECT_TYPE_MENU_BUTTON, PvZ.OBJECT_TYPE_FASTMODE_BUTTON, PvZ.OBJECT_TYPE_STORE_BUTTON, PvZ.OBJECT_TYPE_SHOVEL, PvZ.OBJECT_TYPE_WATERING_CAN, \
		PvZ.OBJECT_TYPE_FERTILIZER, PvZ.OBJECT_TYPE_BUG_SPRAY, PvZ.OBJECT_TYPE_PHONOGRAPH, PvZ.OBJECT_TYPE_CHOCOLATE, \
		PvZ.OBJECT_TYPE_GLOVE, PvZ.OBJECT_TYPE_MONEY_SIGN, PvZ.OBJECT_TYPE_NEXT_GARDEN, PvZ.OBJECT_TYPE_WHEELBARROW, \
		PvZ.OBJECT_TYPE_SLOT_MACHINE_HANDLE, PvZ.OBJECT_TYPE_TREE_FOOD, PvZ.OBJECT_TYPE_STINKY, PvZ.OBJECT_TYPE_TREE_OF_WISDOM, \
		PvZ.OBJECT_TYPE_COIN, PvZ.OBJECT_TYPE_PROJECTILE:
			show_finger = true
		PvZ.OBJECT_TYPE_SEEDPACKET:
			show_finger = hit.object.can_pick_up()
		PvZ.OBJECT_TYPE_SCARY_POT:
			if cursor_object.cursor_type == PvZ.CURSOR_TYPE_NORMAL:
				show_finger = true
			elif cursor_object.cursor_type == PvZ.CURSOR_TYPE_HAMMER:
				hide_cursor = true
		PvZ.OBJECT_TYPE_PLANT:
			if hit.object.state == PvZ.STATE_COBCANNON_READY:
				show_finger = true
		_:
			if cursor_object.cursor_type == PvZ.CURSOR_TYPE_HAMMER:
				hide_cursor = true
	if show_finger:
		App.set_cursor(App.CURSOR_HAND)
	elif hide_cursor:
		App.set_cursor(App.CURSOR_NONE)
	else:
		App.set_cursor(App.CURSOR_POINTER)

func mouse_move(mx: int, my: int) -> void:
	super.mouse_move(mx, my)
	challenge.mouse_move(mx, my)

func mouse_drag(mx: int, my: int) -> void:
	super.mouse_drag(mx, my)
	challenge.mouse_move(mx, my)

func is_plant_in_gold_watering_can_range(mx: int, my: int, plant: Plant) -> bool:
	if get_top_plant_at(plant.plant_col, plant.row, PvZ.TOPPLANT_ZEN_TOOL_ORDER) == plant:
		return plant.x + 40 >= mx - 70 and plant.x + 40 < mx + 90 and plant.y + 40 >= my - 80 and plant.y + 40 < my + 80
	return false

func highlight_plants_for_mouse(mx: int, my: int) -> void:
	if cursor_object.cursor_type == PvZ.CURSOR_TYPE_WATERING_CAN and App.player_info.purchases[PvZ.STORE_ITEM_GOLD_WATERINGCAN] != 0:
		for p in plants:
			if not p.dead and is_plant_in_gold_watering_can_range(mx, my, p):
				p.highlighted = true
				var pot := get_top_plant_at(p.plant_col, p.row, PvZ.TOPPLANT_ONLY_UNDER_PLANT)
				if pot:
					pot.highlighted = true
	else:
		var p := tool_hit_test(mx, my)
		if p:
			p.highlighted = true
			if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
				var pot := get_top_plant_at(p.plant_col, p.row, PvZ.TOPPLANT_ONLY_UNDER_PLANT)
				if pot:
					pot.highlighted = true

func update_mouse_position() -> void:
	update_cursor()
	update_tool_tip()
	for p in plants:
		p.highlighted = false
	var cursor_seed := get_seed_type_in_cursor()
	var mx: int = App.widget_manager.last_mouse_x - x
	var my: int = App.widget_manager.last_mouse_y - y
	if App.is_scary_potter_level():
		for gi in grid_items:
			if gi.grid_item_type == PvZ.GRIDITEM_SCARY_POT:
				gi.highlighted = false
		var hit := HitResult.new()
		mouse_hit_test(mx, my, hit)
		if hit.object_type == PvZ.OBJECT_TYPE_SCARY_POT:
			hit.object.highlighted = true
			return
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
		var stinky = App.zen_garden.get_stinky()
		if stinky:
			var hit2 := HitResult.new()
			mouse_hit_test(mx, my, hit2)
			stinky.highlighted = hit2.object_type == PvZ.OBJECT_TYPE_STINKY
	var ct := cursor_object.cursor_type
	if ct == PvZ.CURSOR_TYPE_SHOVEL or ct == PvZ.CURSOR_TYPE_WATERING_CAN or ct == PvZ.CURSOR_TYPE_FERTILIZER \
			or ct == PvZ.CURSOR_TYPE_BUG_SPRAY or ct == PvZ.CURSOR_TYPE_PHONOGRAPH or ct == PvZ.CURSOR_TYPE_CHOCOLATE \
			or ct == PvZ.CURSOR_TYPE_GLOVE or ct == PvZ.CURSOR_TYPE_MONEY_SIGN \
			or (ct == PvZ.CURSOR_TYPE_WHEEELBARROW and App.zen_garden.get_potted_plant_in_wheelbarrow() == null):
		highlight_plants_for_mouse(mx, my)
		return
	if cursor_seed == PvZ.SEED_INSTANT_COFFEE:
		var gx := planting_pixel_to_grid_x(mx, my, cursor_seed)
		var gy := planting_pixel_to_grid_y(mx, my, cursor_seed)
		var p := get_top_plant_at(gx, gy, PvZ.TOPPLANT_ONLY_NORMAL_POSITION)
		if p and p.is_asleep and can_plant_at(gx, gy, PvZ.SEED_INSTANT_COFFEE) == PvZ.PLANTING_OK:
			p.highlighted = true
	elif cursor_seed == PvZ.SEED_WALLNUT or cursor_seed == PvZ.SEED_TALLNUT:
		var gx := planting_pixel_to_grid_x(mx, my, cursor_seed)
		var gy := planting_pixel_to_grid_y(mx, my, cursor_seed)
		# (original uses ONLY_PUMPKIN priority here, so the nut is never highlighted; kept for accuracy)
		var p := get_top_plant_at(gx, gy, PvZ.TOPPLANT_ONLY_PUMPKIN)
		if p and p.seed_type == cursor_seed and can_plant_at(gx, gy, cursor_seed) == PvZ.PLANTING_OK:
			p.highlighted = true
	elif cursor_seed == PvZ.SEED_PUMPKINSHELL:
		var gx := planting_pixel_to_grid_x(mx, my, cursor_seed)
		var gy := planting_pixel_to_grid_y(mx, my, cursor_seed)
		var p := get_top_plant_at(gx, gy, PvZ.TOPPLANT_ONLY_NORMAL_POSITION)
		if p and p.seed_type == PvZ.SEED_PUMPKINSHELL and can_plant_at(gx, gy, PvZ.SEED_PUMPKINSHELL) == PvZ.PLANTING_OK:
			p.highlighted = true

const _TOOL_TOOLTIPS := {
	PvZ.OBJECT_TYPE_WATERING_CAN: "[WATERING_CAN_TOOLTIP]",
	PvZ.OBJECT_TYPE_FERTILIZER: "[FERTILIZER_TOOLTIP]",
	PvZ.OBJECT_TYPE_BUG_SPRAY: "[BUG_SPRAY_TOOLTIP]",
	PvZ.OBJECT_TYPE_PHONOGRAPH: "[PHONOGRAPH_TOOLTIP]",
	PvZ.OBJECT_TYPE_CHOCOLATE: "[CHOCOLATE_TOOLTIP]",
	PvZ.OBJECT_TYPE_GLOVE: "[GLOVE_TOOLTIP]",
	PvZ.OBJECT_TYPE_MONEY_SIGN: "[MONEY_SIGN_TOOLTIP]",
	PvZ.OBJECT_TYPE_WHEELBARROW: "[WHEELBARROW_TOOLTIP]",
	PvZ.OBJECT_TYPE_TREE_FOOD: "[TREE_FERTILIZER_TOOLTIP]",
}

const _REQUIRES_WARNING := {
	PvZ.SEED_GATLINGPEA: "[REQUIRES_REPEATER]",
	PvZ.SEED_WINTERMELON: "[REQUIRES_MELONPULT]",
	PvZ.SEED_TWINSUNFLOWER: "[REQUIRES_SUNFLOWER]",
	PvZ.SEED_SPIKEROCK: "[REQUIRES_SPIKEWEED]",
	PvZ.SEED_COBCANNON: "[REQUIRES_KERNELPULTS]",
	PvZ.SEED_GOLD_MAGNET: "[REQUIRES_MAGNETSHROOM]",
	PvZ.SEED_GLOOMSHROOM: "[REQUIRES_FUMESHROOM]",
	PvZ.SEED_CATTAIL: "[REQUIRES_LILY_PAD]",
}

func update_tool_tip() -> void:
	var wm: WidgetManager = App.widget_manager
	if not wm.mouse_in or not App.active or time_stop_counter > 0 or App.get_dialog_count() > 0 \
			or App.game_scene == PvZ.SCENE_ZOMBIES_WON or App.game_scene != PvZ.SCENE_PLAYING:
		tool_tip.visible = false
		return
	var mx: int = wm.last_mouse_x - x
	var my: int = wm.last_mouse_y - y
	if not can_interact_with_board_buttons():
		tool_tip.visible = false
		return
	tool_tip.set_title("")
	tool_tip.set_label("")
	tool_tip.set_warning_text("")
	tool_tip.center = false
	if challenge.update_tool_tip(mx, my):
		return
	var hit := HitResult.new()
	mouse_hit_test(mx, my, hit)
	if hit.object_type == PvZ.OBJECT_TYPE_SHOVEL:
		tool_tip.set_label("[SHOVEL_TOOLTIP]")
		var r := get_shovel_button_rect()
		tool_tip.x = r.position.x + 35
		tool_tip.y = r.position.y + 72
		tool_tip.center = true
		tool_tip.visible = true
		return
	if hit.object_type == PvZ.OBJECT_TYPE_NEXT_GARDEN:
		tool_tip.set_label("[NEXT_GARDEN_TOOLTIP]")
		var r := get_shovel_button_rect()
		tool_tip.x = 599 + PvZ.BOARD_ADDITIONAL_WIDTH
		tool_tip.y = r.position.y + 52
		tool_tip.center = true
		tool_tip.visible = true
		return
	if _TOOL_TOOLTIPS.has(hit.object_type):
		tool_tip.set_label(_TOOL_TOOLTIPS[hit.object_type])
		var r := get_zen_button_rect(hit.object_type, get_shovel_button_rect())
		tool_tip.x = r.position.x + 35
		tool_tip.y = r.position.y + 72
		tool_tip.center = true
		tool_tip.visible = true
		return
	if hit.object_type != PvZ.OBJECT_TYPE_SEEDPACKET:
		tool_tip.visible = false
		return
	var packet: SeedPacket = hit.object
	var use_seed := packet.packet_type
	if packet.packet_type == PvZ.SEED_IMITATER and packet.imitater_type != PvZ.SEED_NONE:
		use_seed = packet.imitater_type
	tool_tip.set_label(Plant.get_name_string(packet.packet_type, packet.imitater_type))
	var cost := get_current_plant_cost(packet.packet_type, packet.imitater_type)
	if App.easy_planting_cheat:
		tool_tip.set_warning_text("FREE_PLANTING_CHEAT")
	elif not packet.active:
		tool_tip.set_warning_text("[WAITING_FOR_SEED]")
	elif not can_take_sun_money(cost) and not has_conveyor_belt_seed_bank() and not App.is_slot_machine_level():
		tool_tip.set_warning_text("[NOT_ENOUGH_SUN]")
	elif _REQUIRES_WARNING.has(use_seed):
		if not planting_requirements_met(use_seed):
			tool_tip.set_warning_text(_REQUIRES_WARNING[use_seed])
	tool_tip.x = Tod.idiv(PvZ.SEED_PACKET_WIDTH - tool_tip.width, 2) + seed_bank.x + packet.offset_x + packet.x
	tool_tip.y = seed_bank.y + packet.y + 70
	tool_tip.visible = true

func mouse_down_cobcannon_fire(mx: int, my: int, click_count: int) -> void:
	if click_count >= 0 and my >= 80:
		if cob_cannon_cursor_delay_counter > 0 and Tod.distance_2d(mx, my, cob_cannon_mouse_x, cob_cannon_mouse_y) < 100.0:
			return
		if cursor_object.cursor_type != PvZ.CURSOR_TYPE_PLANT_FROM_DUPLICATOR:
			var cob: Plant = BoardCore.try_get(cursor_object.cob_cannon_plant)
			if cob:
				cob.cob_cannon_fire(mx, my)
	clear_cursor()

const _UPGRADE_ADVICE := {
	PvZ.SEED_GATLINGPEA: ["[ADVICE_ONLY_ON_REPEATERS]", PvZ.ADVICE_PLANT_ONLY_ON_REPEATERS],
	PvZ.SEED_TWINSUNFLOWER: ["[ADVICE_ONLY_ON_SUNFLOWER]", PvZ.ADVICE_PLANT_ONLY_ON_SUNFLOWER],
	PvZ.SEED_GLOOMSHROOM: ["[ADVICE_ONLY_ON_FUMESHROOM]", PvZ.ADVICE_PLANT_ONLY_ON_FUMESHROOM],
	PvZ.SEED_CATTAIL: ["[ADVICE_ONLY_ON_LILYPAD]", PvZ.ADVICE_PLANT_ONLY_ON_LILYPAD],
	PvZ.SEED_WINTERMELON: ["[ADVICE_ONLY_ON_MELONPULT]", PvZ.ADVICE_PLANT_ONLY_ON_MELONPULT],
	PvZ.SEED_GOLD_MAGNET: ["[ADVICE_ONLY_ON_MAGNETSHROOM]", PvZ.ADVICE_PLANT_ONLY_ON_MAGNETSHROOM],
	PvZ.SEED_SPIKEROCK: ["[ADVICE_ONLY_ON_SPIKEWEED]", PvZ.ADVICE_PLANT_ONLY_ON_SPIKEWEED],
	PvZ.SEED_COBCANNON: ["[ADVICE_ONLY_ON_KERNELPULT]", PvZ.ADVICE_PLANT_ONLY_ON_KERNELPULT],
}

func mouse_down_with_plant(mx: int, my: int, click_count: int) -> void:
	if click_count < 0:
		refresh_seed_packet_from_cursor()
		App.play_foley(PvZ.FOLEY_DROP)
		return
	if is_versus() and NetVersus.is_zombie_side_seed(get_seed_type_in_cursor()):
		NetVersus.mouse_down_with_zombie(self, mx, my, get_seed_type_in_cursor())
		return
	var seed_type := get_seed_type_in_cursor()
	var gx := planting_pixel_to_grid_x(mx, my, seed_type)
	var gy := planting_pixel_to_grid_y(mx, my, seed_type)
	if gx < 0 or gx >= MAX_GRID_SIZE_X or gy < 0 or gy > MAX_GRID_SIZE_Y:
		refresh_seed_packet_from_cursor()
		App.play_foley(PvZ.FOLEY_DROP)
		return
	var reason := can_plant_at(gx, gy, seed_type)
	if reason != PvZ.PLANTING_OK:
		var hint := PvZ.MESSAGE_STYLE_HINT_FAST
		if reason == PvZ.PLANTING_ONLY_ON_GRAVES:
			display_advice("[ADVICE_GRAVEBUSTERS_ON_GRAVES]", hint, PvZ.ADVICE_PLANT_GRAVEBUSTERS_ON_GRAVES)
		elif seed_type == PvZ.SEED_LILYPAD:
			if reason == PvZ.PLANTING_ONLY_IN_POOL:
				display_advice("[ADVICE_LILYPAD_ON_WATER]", hint, PvZ.ADVICE_PLANT_LILYPAD_ON_WATER)
		elif seed_type == PvZ.SEED_TANGLEKELP:
			if reason == PvZ.PLANTING_ONLY_IN_POOL:
				display_advice("[ADVICE_TANGLEKELP_ON_WATER]", hint, PvZ.ADVICE_PLANT_TANGLEKELP_ON_WATER)
		elif seed_type == PvZ.SEED_SEASHROOM:
			if reason == PvZ.PLANTING_ONLY_IN_POOL:
				display_advice("[ADVICE_SEASHROOM_ON_WATER]", hint, PvZ.ADVICE_PLANT_SEASHROOM_ON_WATER)
		elif reason == PvZ.PLANTING_ONLY_ON_GROUND:
			display_advice("[ADVICE_POTATO_MINE_ON_LILY]", hint, PvZ.ADVICE_PLANT_POTATOE_MINE_ON_LILY)
		elif reason == PvZ.PLANTING_NOT_PASSED_LINE:
			display_advice("[ADVICE_NOT_PASSED_LINE]", hint, PvZ.ADVICE_PLANT_NOT_PASSED_LINE)
		elif reason == PvZ.PLANTING_NEEDS_UPGRADE:
			if _UPGRADE_ADVICE.has(seed_type):
				display_advice(_UPGRADE_ADVICE[seed_type][0], hint, _UPGRADE_ADVICE[seed_type][1])
		elif reason == PvZ.PLANTING_NEEDS_POT:
			if App.is_first_time_adventure_mode() and level == 41:
				display_advice("[ADVICE_PLANT_NEED_POT1]", hint, PvZ.ADVICE_PLANT_NEED_POT)
			else:
				display_advice("[ADVICE_PLANT_NEED_POT2]", hint, PvZ.ADVICE_PLANT_NEED_POT)
		elif reason == PvZ.PLANTING_NOT_ON_GRAVE:
			display_advice("[ADVICE_PLANT_NOT_ON_GRAVE]", hint, PvZ.ADVICE_PLANT_NOT_ON_GRAVE)
		elif reason == PvZ.PLANTING_NOT_ON_CRATER:
			if is_pool_square(gx, gy):
				display_advice("[ADVICE_CANT_PLANT_THERE]", hint, PvZ.ADVICE_CANT_PLANT_THERE)
			else:
				display_advice("[ADVICE_PLANT_NOT_ON_CRATER]", hint, PvZ.ADVICE_PLANT_NOT_ON_CRATER)
		elif reason == PvZ.PLANTING_NOT_ON_WATER:
			if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN and App.zen_garden.garden_type == PvZ.GARDEN_AQUARIUM:
				display_advice("[ZEN_ONLY_AQUATIC_PLANTS]", hint, PvZ.ADVICE_NONE)
			elif seed_type == PvZ.SEED_POTATOMINE:
				display_advice("[ADVICE_POTATO_MINE_ON_LILY]", hint, PvZ.ADVICE_PLANT_POTATOE_MINE_ON_LILY)
			else:
				display_advice("[ADVICE_PLANT_NOT_ON_WATER]", hint, PvZ.ADVICE_PLANT_NOT_ON_WATER)
		elif reason == PvZ.PLANTING_NEEDS_GROUND:
			display_advice("[ADVICE_PLANTING_NEEDS_GROUND]", hint, PvZ.ADVICE_PLANTING_NEEDS_GROUND)
		elif reason == PvZ.PLANTING_NEEDS_SLEEPING:
			display_advice("[ADVICE_PLANTING_NEED_SLEEPING]", hint, PvZ.ADVICE_PLANTING_NEED_SLEEPING)
		if cursor_object.cursor_type == PvZ.CURSOR_TYPE_PLANT_FROM_GLOVE or App.is_whack_a_zombie_level():
			refresh_seed_packet_from_cursor()
			App.play_foley(PvZ.FOLEY_DROP)
		return
	for adv in [PvZ.ADVICE_PLANTING_NEED_SLEEPING, PvZ.ADVICE_CANT_PLANT_THERE, PvZ.ADVICE_PLANTING_NEEDS_GROUND,
			PvZ.ADVICE_PLANT_NOT_ON_WATER, PvZ.ADVICE_PLANT_NOT_ON_CRATER, PvZ.ADVICE_PLANT_NOT_ON_GRAVE, PvZ.ADVICE_PLANT_NEED_POT,
			PvZ.ADVICE_PLANT_WRONG_ART_TYPE, PvZ.ADVICE_PLANT_ONLY_ON_LILYPAD, PvZ.ADVICE_PLANT_ONLY_ON_MAGNETSHROOM,
			PvZ.ADVICE_PLANT_ONLY_ON_FUMESHROOM, PvZ.ADVICE_PLANT_ONLY_ON_KERNELPULT, PvZ.ADVICE_PLANT_ONLY_ON_SUNFLOWER,
			PvZ.ADVICE_PLANT_ONLY_ON_SPIKEWEED, PvZ.ADVICE_PLANT_ONLY_ON_MELONPULT, PvZ.ADVICE_PLANT_ONLY_ON_REPEATERS,
			PvZ.ADVICE_PLANT_NOT_PASSED_LINE, PvZ.ADVICE_PLANT_GRAVEBUSTERS_ON_GRAVES, PvZ.ADVICE_PLANT_LILYPAD_ON_WATER,
			PvZ.ADVICE_PLANT_TANGLEKELP_ON_WATER, PvZ.ADVICE_PLANT_SEASHROOM_ON_WATER, PvZ.ADVICE_PLANT_POTATOE_MINE_ON_LILY,
			PvZ.ADVICE_SURVIVE_FLAGS]:
		clear_advice(adv)
	if not App.easy_planting_cheat and cursor_object.cursor_type == PvZ.CURSOR_TYPE_PLANT_FROM_BANK and not has_conveyor_belt_seed_bank():
		if not take_sun_money(get_current_plant_cost(seed_type, PvZ.SEED_NONE)):
			return
	var is_awake := false
	var wake_up_counter := 0
	var lawn := get_plants_on_lawn(gx, gy)
	var normal := lawn.normal_plant
	var pumpkin := lawn.pumpkin_plant
	if normal and normal.is_upgradable_to(seed_type):
		if seed_type == PvZ.SEED_GLOOMSHROOM:
			is_awake = not normal.is_asleep
			wake_up_counter = normal.wake_up_counter
		normal.die()
	if (seed_type == PvZ.SEED_WALLNUT or seed_type == PvZ.SEED_TALLNUT) and normal:
		if normal.seed_type == seed_type:
			normal.die()
	if seed_type == PvZ.SEED_PUMPKINSHELL and pumpkin:
		if pumpkin.seed_type == PvZ.SEED_PUMPKINSHELL:
			pumpkin.die()
	if seed_type == PvZ.SEED_COBCANNON:
		var right := get_top_plant_at(gx + 1, gy, PvZ.TOPPLANT_ONLY_NORMAL_POSITION)
		if right:
			right.die()
	if seed_type == PvZ.SEED_CATTAIL:
		if lawn.under_plant:
			lawn.under_plant.die()
		if normal:
			normal.die()
	match cursor_object.cursor_type:
		PvZ.CURSOR_TYPE_PLANT_FROM_GLOVE:
			App.zen_garden.move_plant(BoardCore.try_get(cursor_object.glove_plant), gx, gy)
		PvZ.CURSOR_TYPE_PLANT_FROM_WHEEL_BARROW:
			App.zen_garden.mouse_down_with_full_wheel_barrow(mx, my)
		PvZ.CURSOR_TYPE_PLANT_FROM_USABLE_COIN:
			add_plant(gx, gy, cursor_object.type, cursor_object.imitater_type)
			var coin: Coin = BoardCore.try_get(cursor_object.coin)
			cursor_object.coin = null
			if coin:
				coin.die()
		PvZ.CURSOR_TYPE_PLANT_FROM_BANK:
			var plant := add_plant(gx, gy, cursor_object.type, cursor_object.imitater_type)
			if is_awake:
				plant.set_sleeping(false)
			else:
				plant.wake_up_counter = wake_up_counter
			seed_bank.seed_packets[cursor_object.seed_bank_index].was_planted()
	if tutorial_state == PvZ.TUTORIAL_LEVEL_1_PLANT_PEASHOOTER:
		set_tutorial_state(PvZ.TUTORIAL_LEVEL_1_COMPLETED if plants.size() >= 2 else PvZ.TUTORIAL_LEVEL_1_REFRESH_PEASHOOTER)
	elif tutorial_state == PvZ.TUTORIAL_LEVEL_2_PLANT_SUNFLOWER:
		var suns := count_sun_flowers()
		if seed_type == PvZ.SEED_SUNFLOWER and suns == 2:
			display_advice("[ADVICE_MORE_SUNFLOWERS]", PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL2, PvZ.ADVICE_NONE)
			if not seed_bank.seed_packets[1].can_pick_up():
				set_tutorial_state(PvZ.TUTORIAL_LEVEL_2_REFRESH_SUNFLOWER)
			else:
				set_tutorial_state(PvZ.TUTORIAL_LEVEL_2_PICK_UP_SUNFLOWER)
		elif suns >= 3:
			set_tutorial_state(PvZ.TUTORIAL_LEVEL_2_COMPLETED)
		elif not seed_bank.seed_packets[1].can_pick_up():
			set_tutorial_state(PvZ.TUTORIAL_LEVEL_2_REFRESH_SUNFLOWER)
		else:
			set_tutorial_state(PvZ.TUTORIAL_LEVEL_2_PICK_UP_SUNFLOWER)
	elif tutorial_state == PvZ.TUTORIAL_MORESUN_PLANT_SUNFLOWER:
		if count_sun_flowers() >= 3:
			set_tutorial_state(PvZ.TUTORIAL_MORESUN_COMPLETED)
			display_advice("[ADVICE_PLANT_SUNFLOWER5]", PvZ.MESSAGE_STYLE_TUTORIAL_LATER, PvZ.ADVICE_PLANT_SUNFLOWER5)
			tutorial_timer = -1
		elif not seed_bank.seed_packets[1].can_pick_up():
			set_tutorial_state(PvZ.TUTORIAL_MORESUN_REFRESH_SUNFLOWER)
		else:
			set_tutorial_state(PvZ.TUTORIAL_MORESUN_PICK_UP_SUNFLOWER)
	if App.is_wallnut_bowling_level():
		App.play_sample("SOUND_BOWLING")
	clear_cursor()

func tool_hit_test(mx: int, my: int) -> Plant:
	var hit := HitResult.new()
	mouse_hit_test(mx, my, hit)
	if hit.object_type == PvZ.OBJECT_TYPE_PLANT:
		var p: Plant = hit.object
		if p.seed_type != PvZ.SEED_GRAVEBUSTER or App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
			return p
	return null

func mouse_down_with_tool(mx: int, my: int, click_count: int, cursor_type: int) -> void:
	if click_count < 0:
		clear_cursor()
		App.play_foley(PvZ.FOLEY_DROP)
		return
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
		App.zen_garden.mouse_down_with_tool(mx, my, cursor_type)
		return
	if App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
		challenge.tree_of_wisdom_tool(mx, my)
		return
	var p := tool_hit_test(mx, my)
	if p == null:
		App.play_foley(PvZ.FOLEY_DROP)
	elif cursor_type == PvZ.CURSOR_TYPE_SHOVEL:
		App.play_foley(PvZ.FOLEY_USE_SHOVEL)
		plants_shoveled += 1
		p.die()
		if p.seed_type == PvZ.SEED_CATTAIL and get_top_plant_at(p.plant_col, p.row, PvZ.TOPPLANT_ONLY_PUMPKIN):
			new_plant(p.plant_col, p.row, PvZ.SEED_LILYPAD, PvZ.SEED_NONE)
		if tutorial_state == PvZ.TUTORIAL_SHOVEL_DIG or tutorial_state == PvZ.TUTORIAL_SHOVEL_KEEP_DIGGING:
			set_tutorial_state(PvZ.TUTORIAL_SHOVEL_COMPLETED if count_plant_by_type(PvZ.SEED_PEASHOOTER) == 0 else PvZ.TUTORIAL_SHOVEL_KEEP_DIGGING)
	clear_cursor()

func special_plant_hit_test(mx: int, my: int) -> Plant:
	for p in plants:
		if p.dead:
			continue
		if p.seed_type == PvZ.SEED_PUMPKINSHELL:
			var min_dist := 25.0 if get_top_plant_at(p.plant_col, p.row, PvZ.TOPPLANT_ONLY_NORMAL_POSITION) else 0.0
			var dist := Tod.distance_2d(mx, my, p.x + 40, p.y + 40)
			if dist >= min_dist and dist <= 50 and my > p.y + 25:
				return p
		elif Plant.is_flying(p.seed_type):
			if Tod.distance_2d(mx, my, p.x + 40, p.y) < 15:
				return p
	return null

func mouse_hit_test_plant(mx: int, my: int, hit: HitResult) -> bool:
	if is_versus() and net_active_team() == NetSession.TEAM_ZOMBIES:
		return false
	if cursor_object.cursor_type == PvZ.CURSOR_TYPE_COBCANNON_TARGET or cursor_object.cursor_type == PvZ.CURSOR_TYPE_HAMMER:
		return false
	var p := special_plant_hit_test(mx, my)
	if p:
		hit.object = p
		hit.object_type = PvZ.OBJECT_TYPE_PLANT
		return true
	var gx := pixel_to_grid_x(mx, my)
	var gy := pixel_to_grid_y(mx, my)
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
		p = get_top_plant_at(gx, gy, PvZ.TOPPLANT_ZEN_TOOL_ORDER)
		if cursor_object.cursor_type == PvZ.CURSOR_TYPE_WATERING_CAN and (p == null or not App.zen_garden.plant_can_be_watered(p)):
			var top := get_top_plant_at(pixel_to_grid_x(mx - 30, my - 20), pixel_to_grid_y(mx - 30, my - 20), PvZ.TOPPLANT_ZEN_TOOL_ORDER)
			if top and App.zen_garden.plant_can_be_watered(top):
				p = top
	else:
		p = get_top_plant_at(gx, gy, PvZ.TOPPLANT_DIGGING_ORDER)
		if p and (p.seed_type == PvZ.SEED_LILYPAD or p.seed_type == PvZ.SEED_FLOWERPOT):
			if get_top_plant_at(gx, gy, PvZ.TOPPLANT_ONLY_PUMPKIN):
				return false
	if p == null:
		return false
	if cursor_object.cursor_type == PvZ.CURSOR_TYPE_CHOCOLATE and not App.zen_garden.plant_can_have_chocolate(p):
		hit.clear()
		return false
	hit.object = p
	hit.object_type = PvZ.OBJECT_TYPE_PLANT
	return true

func mouse_hit_test(mx: int, my: int, hit: HitResult) -> bool:
	if board_fade_out_counter >= 0 or is_scary_potter_dave_talking():
		hit.clear()
		return false
	if not net_replaying and menu_button.is_mouse_over() and can_interact_with_board_buttons():
		hit.object_type = PvZ.OBJECT_TYPE_MENU_BUTTON
		return true
	if not net_replaying and fast_button.is_mouse_over() and can_interact_with_board_buttons():
		hit.object_type = PvZ.OBJECT_TYPE_FASTMODE_BUTTON
		return true
	elif not net_replaying and store_button and store_button.is_mouse_over() and can_interact_with_board_buttons():
		hit.object_type = PvZ.OBJECT_TYPE_STORE_BUTTON
		return true
	var shovel_rect := get_shovel_button_rect()
	if seed_bank.mouse_hit_test(mx, my, hit):
		var ct := cursor_object.cursor_type
		if ct == PvZ.CURSOR_TYPE_NORMAL or ct == PvZ.CURSOR_TYPE_COBCANNON_TARGET or ct == PvZ.CURSOR_TYPE_HAMMER:
			return true
	var zombie_team := is_versus() and net_active_team() == NetSession.TEAM_ZOMBIES
	if show_shovel and not zombie_team and shovel_rect.has_point(Vector2i(mx, my)) and can_interact_with_board_buttons():
		hit.object_type = PvZ.OBJECT_TYPE_SHOVEL
		return true
	if cursor_object.cursor_type == PvZ.CURSOR_TYPE_NORMAL or cursor_object.cursor_type == PvZ.CURSOR_TYPE_HAMMER:
		var top_coin: Coin = null
		for coin in coins:
			if coin.dead or (is_versus() and coin.vs_zombie_sun != zombie_team):
				continue
			var ch := HitResult.new()
			if coin.mouse_hit_test(mx, my, ch):
				if top_coin == null or coin.render_order >= top_coin.render_order:
					hit.object_type = ch.object_type
					hit.object = coin
					top_coin = coin
		if top_coin:
			return true
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
		var can_click := false
		if cursor_object.cursor_type == PvZ.CURSOR_TYPE_CHOCOLATE and not App.zen_garden.is_stinky_high_on_chocolate():
			can_click = true
		elif cursor_object.cursor_type == PvZ.CURSOR_TYPE_NORMAL and App.zen_garden.is_stinky_sleeping():
			can_click = true
		var stinky = App.zen_garden.get_stinky()
		if can_click and stinky:
			if Rect2i(int(stinky.pos_x) - 6, int(stinky.pos_y) - 10, 84, 90).has_point(Vector2i(mx, my)):
				hit.object_type = PvZ.OBJECT_TYPE_STINKY
				return true
	if App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
		if cursor_object.cursor_type == PvZ.CURSOR_TYPE_TREE_FOOD and challenge.tree_of_wisdom_hit_test(mx, my, hit):
			return true
	if (App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN or App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM) and can_interact_with_board_buttons():
		for tool in range(PvZ.OBJECT_TYPE_WATERING_CAN, PvZ.OBJECT_TYPE_NEXT_GARDEN + 1):
			if can_use_game_object(tool) and (tool != PvZ.OBJECT_TYPE_TREE_FOOD or challenge.tree_of_wisdom_can_feed()):
				var r := get_shovel_button_rect()
				if tool == PvZ.OBJECT_TYPE_NEXT_GARDEN:
					r.position.x = 564 + PvZ.BOARD_ADDITIONAL_WIDTH
				else:
					r = get_zen_button_rect(tool, r)
				if r.has_point(Vector2i(mx, my)):
					hit.object_type = tool
					return true
	if mouse_hit_test_plant(mx, my, hit):
		return true
	if App.is_scary_potter_level() and cursor_object.cursor_type == PvZ.CURSOR_TYPE_NORMAL \
			and challenge.challenge_state != PvZ.STATECHALLENGE_SCARY_POTTER_MALLETING and App.game_scene == PvZ.SCENE_PLAYING \
			and App.get_dialog(PvZ.DIALOG_GAME_OVER) == null and App.get_dialog(PvZ.DIALOG_CONTINUE) == null:
		var pot := get_grid_item_at(PvZ.GRIDITEM_SCARY_POT, pixel_to_grid_x(mx, my), pixel_to_grid_y(mx, my))
		if pot:
			hit.object = pot
			hit.object_type = PvZ.OBJECT_TYPE_SCARY_POT
			return true
	hit.clear()
	return false

func pick_up_tool(object_type: int) -> void:
	if paused or (App.game_scene != PvZ.SCENE_PLAYING and not cut_scene.is_in_shovel_tutorial()):
		return
	var pur: Array = App.player_info.purchases
	match object_type:
		PvZ.OBJECT_TYPE_SHOVEL:
			if tutorial_state == PvZ.TUTORIAL_SHOVEL_PICKUP:
				set_tutorial_state(PvZ.TUTORIAL_SHOVEL_DIG)
			cursor_object.cursor_type = PvZ.CURSOR_TYPE_SHOVEL
			App.play_foley(PvZ.FOLEY_SHOVEL)
		PvZ.OBJECT_TYPE_WATERING_CAN:
			if tutorial_state == PvZ.TUTORIAL_ZEN_GARDEN_PICKUP_WATER:
				tutorial_state = PvZ.TUTORIAL_ZEN_GARDEN_WATER_PLANT
				display_advice("[ADVICE_ZEN_GARDEN_WATER_PLANT]", PvZ.MESSAGE_STYLE_ZEN_GARDEN_LONG, PvZ.ADVICE_NONE)
				tutorial_arrow_remove()
			cursor_object.cursor_type = PvZ.CURSOR_TYPE_WATERING_CAN
			App.play_foley(PvZ.FOLEY_DROP)
		PvZ.OBJECT_TYPE_FERTILIZER:
			if pur[PvZ.STORE_ITEM_FERTILIZER] > PURCHASE_COUNT_OFFSET:
				cursor_object.cursor_type = PvZ.CURSOR_TYPE_FERTILIZER
			else:
				App.play_sample("SOUND_BUZZER")
		PvZ.OBJECT_TYPE_BUG_SPRAY:
			if pur[PvZ.STORE_ITEM_BUG_SPRAY] > PURCHASE_COUNT_OFFSET:
				cursor_object.cursor_type = PvZ.CURSOR_TYPE_BUG_SPRAY
			else:
				App.play_sample("SOUND_BUZZER")
		PvZ.OBJECT_TYPE_PHONOGRAPH:
			cursor_object.cursor_type = PvZ.CURSOR_TYPE_PHONOGRAPH
			App.play_foley(PvZ.FOLEY_DROP)
		PvZ.OBJECT_TYPE_CHOCOLATE:
			if pur[PvZ.STORE_ITEM_CHOCOLATE] > PURCHASE_COUNT_OFFSET:
				cursor_object.cursor_type = PvZ.CURSOR_TYPE_CHOCOLATE
			else:
				App.play_sample("SOUND_BUZZER")
		PvZ.OBJECT_TYPE_GLOVE:
			cursor_object.cursor_type = PvZ.CURSOR_TYPE_GLOVE
			App.play_foley(PvZ.FOLEY_DROP)
		PvZ.OBJECT_TYPE_MONEY_SIGN:
			cursor_object.cursor_type = PvZ.CURSOR_TYPE_MONEY_SIGN
			App.play_foley(PvZ.FOLEY_DROP)
		PvZ.OBJECT_TYPE_WHEELBARROW:
			cursor_object.cursor_type = PvZ.CURSOR_TYPE_WHEEELBARROW
			App.play_foley(PvZ.FOLEY_DROP)
		PvZ.OBJECT_TYPE_TREE_FOOD:
			if challenge.tree_of_wisdom_can_feed():
				if pur[PvZ.STORE_ITEM_TREE_FOOD] > PURCHASE_COUNT_OFFSET:
					cursor_object.cursor_type = PvZ.CURSOR_TYPE_TREE_FOOD
				else:
					App.play_sample("SOUND_BUZZER")
	cursor_object.type = PvZ.SEED_NONE

func mouse_down(mx: int, my: int, click_count: int) -> void:
	if is_net_game() and not net_replaying:
		App.net.local_board_click(self, mx, my, click_count)
		return
	super.mouse_down(mx, my, click_count)
	ignore_mouse_up = not can_interact_with_board_buttons()
	if time_stop_counter > 0:
		return
	var hit := HitResult.new()
	mouse_hit_test(mx, my, hit)
	if challenge.mouse_down(mx, my, click_count, hit):
		return
	if menu_button.is_mouse_over() and can_interact_with_board_buttons() and click_count > 0:
		App.play_sample("SOUND_GRAVEBUTTON")
	if fast_button.is_mouse_over() and can_interact_with_board_buttons() and click_count > 0:
		App.play_sample("SOUND_TAP")
	elif store_button and store_button.is_mouse_over() and can_interact_with_board_buttons() and click_count > 0:
		if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN or App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
			App.play_sample("SOUND_TAP")
	if App.game_scene == PvZ.SCENE_LEVEL_INTRO and App.seed_chooser_screen:
		App.seed_chooser_screen.cancel_lawn_view()
	if App.game_scene == PvZ.SCENE_ZOMBIES_WON:
		cut_scene.zombie_won_click()
		return
	if App.game_scene == PvZ.SCENE_LEVEL_INTRO:
		cut_scene.mouse_down(mx, my)
	# Debug mode: clicking skips the wait between survival stages.
	if App.tod_cheat_keys and not App.is_scary_potter_level() and next_survival_stage_counter > 0:
		next_survival_stage_counter = 2
		for i in MAX_GRID_SIZE_Y:
			if ice_timer[i] > 2:
				ice_timer[i] = 2
	var ct := cursor_object.cursor_type
	if hit.object_type == PvZ.OBJECT_TYPE_NONE:
		if ct == PvZ.CURSOR_TYPE_COBCANNON_TARGET:
			mouse_down_cobcannon_fire(mx, my, click_count)
			update_cursor()
			return
	elif hit.object_type == PvZ.OBJECT_TYPE_COIN and click_count >= 0:
		var coin: Coin = hit.object
		if coin.is_on_board:
			coin.mouse_down(mx, my, click_count)
		update_cursor()
		return
	if ct in [PvZ.CURSOR_TYPE_SHOVEL, PvZ.CURSOR_TYPE_WATERING_CAN, PvZ.CURSOR_TYPE_FERTILIZER, PvZ.CURSOR_TYPE_BUG_SPRAY,
			PvZ.CURSOR_TYPE_PHONOGRAPH, PvZ.CURSOR_TYPE_CHOCOLATE, PvZ.CURSOR_TYPE_GLOVE, PvZ.CURSOR_TYPE_MONEY_SIGN,
			PvZ.CURSOR_TYPE_WHEEELBARROW, PvZ.CURSOR_TYPE_TREE_FOOD]:
		mouse_down_with_tool(mx, my, click_count, ct)
	elif is_plant_in_cursor():
		mouse_down_with_plant(mx, my, click_count)
	elif hit.object_type == PvZ.OBJECT_TYPE_SEEDPACKET:
		if not paused:
			hit.object.mouse_down(mx, my, click_count)
	elif hit.object_type == PvZ.OBJECT_TYPE_NEXT_GARDEN:
		if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
			App.zen_garden.goto_next_garden()
		elif App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
			challenge.tree_of_wisdom_next_garden()
		App.play_sample("SOUND_TAP")
	elif hit.object_type in [PvZ.OBJECT_TYPE_SHOVEL, PvZ.OBJECT_TYPE_WATERING_CAN, PvZ.OBJECT_TYPE_FERTILIZER, PvZ.OBJECT_TYPE_BUG_SPRAY,
			PvZ.OBJECT_TYPE_PHONOGRAPH, PvZ.OBJECT_TYPE_CHOCOLATE, PvZ.OBJECT_TYPE_GLOVE, PvZ.OBJECT_TYPE_MONEY_SIGN,
			PvZ.OBJECT_TYPE_WHEELBARROW, PvZ.OBJECT_TYPE_TREE_FOOD]:
		pick_up_tool(hit.object_type)
	elif hit.object_type == PvZ.OBJECT_TYPE_PLANT:
		hit.object.mouse_down(mx, my, click_count)
	update_cursor()

func clear_cursor() -> void:
	if advice.duration > 0:
		if help_index in [PvZ.ADVICE_PLANT_GRAVEBUSTERS_ON_GRAVES, PvZ.ADVICE_PLANT_LILYPAD_ON_WATER, PvZ.ADVICE_PLANT_TANGLEKELP_ON_WATER,
				PvZ.ADVICE_PLANT_SEASHROOM_ON_WATER, PvZ.ADVICE_PLANT_POTATOE_MINE_ON_LILY, PvZ.ADVICE_PLANT_WRONG_ART_TYPE,
				PvZ.ADVICE_PLANT_NEED_POT, PvZ.ADVICE_PLANT_NOT_PASSED_LINE, PvZ.ADVICE_PLANT_ONLY_ON_REPEATERS,
				PvZ.ADVICE_PLANT_ONLY_ON_MELONPULT, PvZ.ADVICE_PLANT_ONLY_ON_SUNFLOWER, PvZ.ADVICE_PLANT_ONLY_ON_SPIKEWEED,
				PvZ.ADVICE_PLANT_ONLY_ON_KERNELPULT]:
			clear_advice(help_index)
	cursor_object.type = PvZ.SEED_NONE
	cursor_object.cursor_type = PvZ.CURSOR_TYPE_NORMAL
	cursor_object.seed_bank_index = -1
	cursor_object.coin = null
	cursor_object.duplicator_plant = null
	cursor_object.cob_cannon_plant = null
	cursor_object.glove_plant = null
	App.set_cursor(App.CURSOR_POINTER)
	challenge.clear_cursor()
	if tutorial_state == PvZ.TUTORIAL_LEVEL_1_PLANT_PEASHOOTER:
		set_tutorial_state(PvZ.TUTORIAL_LEVEL_1_PICK_UP_PEASHOOTER)
	elif tutorial_state == PvZ.TUTORIAL_LEVEL_2_PLANT_SUNFLOWER or tutorial_state == PvZ.TUTORIAL_LEVEL_2_REFRESH_SUNFLOWER:
		if not seed_bank.seed_packets[1].can_pick_up():
			set_tutorial_state(PvZ.TUTORIAL_LEVEL_2_REFRESH_SUNFLOWER)
		else:
			set_tutorial_state(PvZ.TUTORIAL_LEVEL_2_PICK_UP_SUNFLOWER)
	elif tutorial_state == PvZ.TUTORIAL_MORESUN_PLANT_SUNFLOWER or tutorial_state == PvZ.TUTORIAL_MORESUN_REFRESH_SUNFLOWER:
		if not seed_bank.seed_packets[1].can_pick_up():
			set_tutorial_state(PvZ.TUTORIAL_MORESUN_REFRESH_SUNFLOWER)
		else:
			set_tutorial_state(PvZ.TUTORIAL_MORESUN_PICK_UP_SUNFLOWER)
	elif tutorial_state == PvZ.TUTORIAL_SHOVEL_DIG:
		set_tutorial_state(PvZ.TUTORIAL_SHOVEL_PICKUP)

func can_interact_with_board_buttons() -> bool:
	if paused or (App.get_dialog_count() > 0 and not net_replaying):
		return false
	var ct := cursor_object.cursor_type
	if ct != PvZ.CURSOR_TYPE_NORMAL and ct != PvZ.CURSOR_TYPE_HAMMER and ct != PvZ.CURSOR_TYPE_COBCANNON_TARGET:
		return false
	if challenge.challenge_state == PvZ.STATECHALLENGE_ZEN_FADING:
		return false
	return App.game_mode == PvZ.GAMEMODE_UPSELL or App.crazy_dave_state == PvZ.CRAZY_DAVE_OFF

func mouse_up(mx: int, my: int, click_count: int) -> void:
	super.mouse_up(mx, my, click_count)
	if is_net_game():
		return  # the online menu opens on mouse down (NetSession.local_board_click)
	if ignore_mouse_up:
		ignore_mouse_up = false
		return
	if can_interact_with_board_buttons() and click_count > 0:
		if menu_button.is_mouse_over() and App.get_dialog(PvZ.DIALOG_GAME_OVER) == null and App.get_dialog(PvZ.DIALOG_LEVEL_COMPLETE) == null:
			menu_button.is_over = false
			menu_button.is_down = false
			update_cursor()
			clear_cursor()
			if tutorial_state == PvZ.TUTORIAL_ZEN_GARDEN_COMPLETED:
				App.finish_zen_garden_tutorial()
			elif App.game_mode != PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN and App.game_mode != PvZ.GAMEMODE_TREE_OF_WISDOM and App.game_mode != PvZ.GAMEMODE_UPSELL:
				App.play_sample("SOUND_PAUSE")
				App.do_new_options(false)
			else:
				App.board_result = PvZ.BOARDRESULT_QUIT
				App.do_back_to_main()
		if fast_button.is_mouse_over() and App.get_dialog(PvZ.DIALOG_GAME_OVER) == null and App.get_dialog(PvZ.DIALOG_LEVEL_COMPLETE) == null and board_fade_out_counter < 0:
			fast_button.is_over = false
			fast_button.is_down = false
			update_cursor()
			App.is_fast_mode = not App.is_fast_mode
		elif store_button and store_button.is_mouse_over():
			if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
				clear_advice_immediately()
				App.zen_garden.open_store()
			elif App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
				challenge.tree_of_wisdom_open_store()

# ================================================================ keyboard
func set_mustache_mode(enable: bool) -> void:
	App.play_foley(PvZ.FOLEY_POLEVAULT)
	mustache_mode = enable
	App.mustache_mode = enable
	if enable:
		App.get_achievement(PvZ.ACHIEVEMENT_MUSTACHE_MODE)
	for z in zombies:
		if not z.dead:
			z.enable_mustache(enable)

func set_future_mode(enable: bool) -> void:
	App.play_sample("SOUND_BOING")
	future_mode = enable
	App.future_mode = enable
	for z in zombies:
		if not z.dead:
			z.enable_future(enable)

func set_pinata_mode(enable: bool) -> void:
	App.play_foley(PvZ.FOLEY_JUICY)
	pinata_mode = enable
	App.pinata_mode = enable

func set_dance_mode(enable: bool) -> void:
	App.play_foley(PvZ.FOLEY_DANCER)
	dance_mode = enable
	App.dance_mode = enable
	for z in zombies:
		if not z.dead:
			z.enable_dance(enable)

func set_super_mower_mode(enable: bool) -> void:
	App.play_foley(PvZ.FOLEY_ZAMBONI)
	super_mower_mode = enable
	App.super_mower_mode = enable
	for m in lawn_mowers:
		if not m.dead:
			m.enable_super_mower(enable)

func set_daisy_mode(enable: bool) -> void:
	App.play_sample("SOUND_LOADINGBAR_FLOWER")
	daisy_mode = enable
	App.daisy_mode = enable

func set_sukhbir_mode(enable: bool) -> void:
	App.play_sample("SOUND_SUKHBIR")
	sukhbir_mode = enable
	App.sukhbir_mode = enable

func _cant_use_code() -> void:
	if App.game_scene == PvZ.SCENE_PLAYING:
		display_advice("[CANT_USE_CODE]", PvZ.MESSAGE_STYLE_BIG_MIDDLE_FAST, PvZ.ADVICE_NONE)
	App.play_sample("SOUND_BUZZER")

func do_typing_check(key: int) -> void:
	if App.konami_check.check(key):
		App.play_foley(PvZ.FOLEY_DROP)
		return
	if App.mustache_check.check(key) or App.moustache_check.check(key):
		set_mustache_mode(not mustache_mode)
		return
	if App.super_mower_check.check(key) or App.super_mower_check2.check(key):
		set_super_mower_mode(not super_mower_mode)
		return
	if App.future_check.check(key):
		set_future_mode(not future_mode)
		return
	if App.pinata_check.check(key):
		if App.can_do_pinata_mode():
			set_pinata_mode(not pinata_mode)
		else:
			_cant_use_code()
		return
	if App.dance_check.check(key):
		if App.can_do_dance_mode():
			set_dance_mode(not dance_mode)
		else:
			_cant_use_code()
		return
	if App.daisy_check.check(key):
		if App.can_do_daisy_mode():
			set_daisy_mode(not daisy_mode)
		else:
			_cant_use_code()
		return
	if App.sukhbir_check.check(key):
		set_sukhbir_mode(not sukhbir_mode)
		return

## Board::KeyChar (QE seed bank keybinds and shovel key).
func key_char(ch: String) -> void:
	if is_net_game():
		App.net.board_key_char(self, ch)
		return
	var can_use_keybinds := App.bank_keybinds and (not paused or App.game_scene == PvZ.SCENE_PLAYING or App.crazy_dave_state != PvZ.CRAZY_DAVE_OFF)
	if ch.length() == 1 and ch >= "0" and ch <= "9" and can_use_keybinds and seed_bank.y >= 0:
		# WIDETWEAK: fix last seed packet not being choosable when using keybinds
		for i in seed_bank.num_packets + 1:
			var seed_index := i
			if ch.unicode_at(0) == 0x30 + seed_index and seed_bank.num_packets >= seed_index:
				if App.zero_nine_bank_format:
					if seed_index == 0:
						seed_index = 9
					else:
						seed_index -= 1
				var packet: SeedPacket = seed_bank.seed_packets[seed_index]
				if packet.packet_type == PvZ.SEED_NONE:
					break
				if cursor_object.seed_bank_index == seed_index:
					refresh_seed_packet_from_cursor()
					App.play_foley(PvZ.FOLEY_DROP)
				else:
					if cursor_object.cursor_type != PvZ.CURSOR_TYPE_PLANT_FROM_BANK or cursor_object.seed_bank_index != seed_index:
						if cursor_object.cursor_type == PvZ.CURSOR_TYPE_PLANT_FROM_BANK:
							refresh_seed_packet_from_cursor()
						else:
							clear_cursor()
					packet.mouse_down(0, 0, 0)
				break
	elif ch.to_lower() == "s" and can_use_keybinds and show_shovel:
		if cursor_object.cursor_type != PvZ.CURSOR_TYPE_SHOVEL:
			if cursor_object.cursor_type == PvZ.CURSOR_TYPE_PLANT_FROM_BANK:
				refresh_seed_packet_from_cursor()
			pick_up_tool(PvZ.OBJECT_TYPE_SHOVEL)
		else:
			clear_cursor()
			App.play_foley(PvZ.FOLEY_DROP)
	if App.debug_keys_enabled:
		debug_key_char(ch)

# ================================================================ debug keys (Board::KeyChar, enabled by Advanced Options > Debug Mode)
const COIN_NAMES := ["NONE", "SILVER_COIN", "GOLD_COIN", "DIAMOND", "SUN", "SMALL_SUN", "LARGE_SUN", "SEED_PACKET", "TROPHY", "SHOVEL",
	"ALMANAC", "CAR_KEYS", "VASE", "WATERING_CAN", "TACO", "NOTE", "USABLE_PACKET", "PRESENT_PLANT", "MONEY_BAG", "PRESENT",
	"DIAMOND_BAG", "SILVER_FLOWER", "GOLD_FLOWER", "CHOCOLATE", "AWARD_CHOCOLATE", "MINIGAMES_PRESENT", "PUZZLE_PRESENT", "SURVIVAL_PRESENT"]
const BACKGROUND_NAMES := ["DAY", "NIGHT", "POOL", "FOG", "ROOF", "NIGHT_ROOF"]
const GRID_ITEM_NAMES := ["NONE", "GRAVESTONE", "CRATER", "LADDER", "PORTAL1", "PORTAL2", "BRAIN", "SCARY_POT", "SQUIRREL",
	"ZEN_TOOL", "STINKY", "RAKE", "IZOMBIE_BRAIN"]
const DEBUG_OBJECT_TYPE_NAMES := ["Zombie", "Plant", "Coin", "Projectile", "Background", "Hypno Zombie", "Grid Item"]
const DEBUG_SELECTION_PREFIXES := ["Selected Zombie Type ", "Selected Plant Type ", "Selected Coin Type ", "Selected Projectile Type ",
	"Selected Background Type ", "Selected Hypno Zombie Type ", "Selected Grid Item Type "]
const TREE_OF_WISDOM_HEIGHTS := {"0": 0, "1": 9, "2": 19, "3": 29, "4": 39, "5": 49, "6": 98, "7": 498, "8": 998}

func _debug_object_name(index: int) -> String:
	match debug_object_type:
		0, 5: return LawnDefs.ZOMBIE_DEFS[index][6] if index < LawnDefs.ZOMBIE_DEFS.size() else str(index)
		1: return LawnDefs.PLANT_DEFS[index][7] if index < LawnDefs.PLANT_DEFS.size() else str(index)
		2: return COIN_NAMES[index] if index < COIN_NAMES.size() else str(index)
		3: return LawnDefs.PROJECTILE_DEFS[index][3] if index < LawnDefs.PROJECTILE_DEFS.size() else str(index)
		4: return BACKGROUND_NAMES[index] if index < BACKGROUND_NAMES.size() else str(index)
		6: return GRID_ITEM_NAMES[index] if index < GRID_ITEM_NAMES.size() else str(index)
	return ""

## '!' and '+' (complete the level); they only differ in survival modes.
func _debug_win_level(plus_key: bool) -> void:
	App.board_result = PvZ.BOARDRESULT_CHEAT
	if is_last_stand_stage_with_repick():
		if next_survival_stage_counter == 0:
			current_wave = num_waves
			remove_all_zombies()
			fade_out_level()
	elif (App.is_scary_potter_level() and not is_final_scary_potter_stage()) or App.is_endless_izombie(App.game_mode):
		if next_survival_stage_counter == 0:
			remove_all_zombies()
			fade_out_level()
	elif plus_key and App.is_survival_endless(App.game_mode):
		if App.game_scene == PvZ.SCENE_LEVEL_INTRO:
			return
		current_wave = num_waves
		remove_all_zombies()
		fade_out_level()
	elif App.is_survival_mode():
		if plus_key:
			challenge.survival_stage = 5
			remove_all_zombies()
			fade_out_level()
			board_fade_out_counter = 200
		else:
			if App.game_scene == PvZ.SCENE_LEVEL_INTRO:
				return
			current_wave = num_waves
			remove_all_zombies()
			fade_out_level()
	else:
		remove_all_zombies()
		fade_out_level()
		board_fade_out_counter = 200

func _debug_zen_garden_key(ch: String) -> bool:
	var zg: ZenGarden = App.zen_garden
	var pi: PlayerInfo = App.player_info
	match ch:
		"m":
			if not zg.is_zen_garden_full(true):
				var pp := PlayerInfo.PottedPlant.new()
				pp.initialize_potted_plant(PvZ.SEED_MARIGOLD)
				pp.draw_variation = Tod.rand_range_int(PvZ.VARIATION_MARIGOLD_WHITE, PvZ.VARIATION_MARIGOLD_LIGHT_GREEN)
				zg.add_potted_plant(pp)
			return true
		"+", "a":
			if not zg.is_zen_garden_full(true):
				var pp2 := PlayerInfo.PottedPlant.new()
				pp2.initialize_potted_plant(zg.pick_random_seed_type())
				if ch == "a":
					pp2.plant_age = PvZ.PLANTAGE_FULL
				zg.add_potted_plant(pp2)
			return true
		"f":
			for p in plants:
				if p.dead or get_zen_tool_at(p.plant_col, p.row) != null or p.potted_plant_index < 0:
					continue
				var need: int = zg.get_plants_need(zg.potted_plant_from_index(p.potted_plant_index))
				var tool := -1
				match need:
					PvZ.PLANTNEED_WATER:
						tool = PvZ.CURSOR_TYPE_WATERING_CAN
					PvZ.PLANTNEED_FERTILIZER:
						if pi.purchases[PvZ.STORE_ITEM_FERTILIZER] <= PURCHASE_COUNT_OFFSET:
							pi.purchases[PvZ.STORE_ITEM_FERTILIZER] = PURCHASE_COUNT_OFFSET + 1
						tool = PvZ.CURSOR_TYPE_FERTILIZER
					PvZ.PLANTNEED_BUGSPRAY:
						if pi.purchases[PvZ.STORE_ITEM_BUG_SPRAY] <= PURCHASE_COUNT_OFFSET:
							pi.purchases[PvZ.STORE_ITEM_BUG_SPRAY] = PURCHASE_COUNT_OFFSET + 1
						tool = PvZ.CURSOR_TYPE_BUG_SPRAY
					PvZ.PLANTNEED_PHONOGRAPH:
						tool = PvZ.CURSOR_TYPE_PHONOGRAPH
				if tool != -1:
					p.highlighted = true
					zg.mouse_down_with_feeding_tool(p.x, p.y, tool)
					return true
			return true
		"r":
			for p in plants:
				if not p.dead and p.potted_plant_index >= 0:
					zg.reset_plant_timers(pi.potted_plants[p.potted_plant_index])
			return true
		"s":
			if zg.is_stinky_sleeping():
				zg.wake_stinky()
			else:
				zg.reset_stinky_timers()
			return true
		"c":
			if pi.purchases[PvZ.STORE_ITEM_CHOCOLATE] < PURCHASE_COUNT_OFFSET:
				pi.purchases[PvZ.STORE_ITEM_CHOCOLATE] = PURCHASE_COUNT_OFFSET + 1
			else:
				pi.purchases[PvZ.STORE_ITEM_CHOCOLATE] += 1
			return true
		"]":
			var wheel = zg.get_potted_plant_in_wheelbarrow()
			if wheel:
				wheel.seed_type += 1
				if wheel.seed_type == PvZ.SEED_GATLINGPEA:
					wheel.seed_type = PvZ.SEED_PEASHOOTER
				if wheel.seed_type == PvZ.SEED_FLOWERPOT:
					wheel.seed_type = PvZ.SEED_KERNELPULT
			return true
	return false

func debug_key_char(ch: String) -> void:
	if ch == "e":
		for i in PvZ.NUM_ACHIEVEMENTS:
			App.get_achievement(i)

	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN and _debug_zen_garden_key(ch):
		return

	if App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
		if ch == "f":
			var pur: Array = App.player_info.purchases
			if pur[PvZ.STORE_ITEM_TREE_FOOD] <= PURCHASE_COUNT_OFFSET:
				pur[PvZ.STORE_ITEM_TREE_FOOD] = PURCHASE_COUNT_OFFSET + 1
			challenge.tree_of_wisdom_fertilize()
		elif ch == "g":
			challenge.tree_of_wisdom_grow()
		elif ch == "b":
			challenge.challenge_state_counter = 1
		elif TREE_OF_WISDOM_HEIGHTS.has(ch):
			App.player_info.challenge_records[App.get_current_challenge_index()] = TREE_OF_WISDOM_HEIGHTS[ch]
			challenge.tree_of_wisdom_grow()
		return

	match ch:
		"<":
			App.do_new_options(false)
		"l":
			App.do_cheat_dialog()
		"#":
			if App.is_survival_mode():
				if App.game_scene == PvZ.SCENE_LEVEL_INTRO:
					return
				current_wave = num_waves
				challenge.survival_stage += 5
				remove_all_zombies()
				fade_out_level()
		"!":
			_debug_win_level(false)
		"+":
			_debug_win_level(true)
		"8":
			App.easy_planting_cheat = not App.easy_planting_cheat
		"7":
			App.toggle_slow_mo()
		"6":
			App.toggle_fast_mo()
		"z":
			debug_text_mode += 1
			if debug_text_mode > PvZ.DEBUG_TEXT_COLLISION:
				debug_text_mode = PvZ.DEBUG_TEXT_NONE

	if App.game_scene != PvZ.SCENE_PLAYING:
		return

	var boss := get_boss_zombie()
	if boss and not boss.is_dead_or_dying():
		match ch:
			"b":
				boss.boss_bungee_counter = 0
				return
			"u":
				boss.summon_counter = 0
				return
			"s":
				boss.boss_stomp_counter = 0
				return
			"r":
				boss.boss_rv_attack()
				return
			"h":
				boss.boss_head_counter = 0
				return
			"D":
				boss.take_damage(10000, 0)
				return

	match debug_object_type:
		0, 5: debug_object_limit = PvZ.NUM_ZOMBIE_TYPES - 1
		1: debug_object_limit = PvZ.NUM_SEED_TYPES - 1
		2: debug_object_limit = PvZ.NUM_COIN_TYPES - 1
		3: debug_object_limit = PvZ.NUM_PROJECTILES - 1
		4: debug_object_limit = PvZ.BACKGROUND_6_BOSS
		6: debug_object_limit = PvZ.NUM_GRID_ITEM_TYPES - 1

	var mx: int = App.widget_manager.last_mouse_x - x
	var my: int = App.widget_manager.last_mouse_y - y
	var gx := pixel_to_grid_x_keep_on_board(mx, my)
	var gy := pixel_to_grid_y_keep_on_board(mx, my)

	if ch == "d" or ch == "a":
		debug_object_selection += 1 if ch == "d" else -1
		if debug_object_selection > debug_object_limit:
			debug_object_selection = 0
		if debug_object_selection < 0:
			debug_object_selection = debug_object_limit
		display_advice(DEBUG_SELECTION_PREFIXES[debug_object_type] + _debug_object_name(debug_object_selection), PvZ.MESSAGE_STYLE_HINT_LONG, PvZ.ADVICE_NONE)
		return
	if ch == "s":
		debug_object_type += 1
		if debug_object_type > 6:
			debug_object_type = 0
		display_advice("Selected Object Type " + DEBUG_OBJECT_TYPE_NAMES[debug_object_type], PvZ.MESSAGE_STYLE_HINT_LONG, PvZ.ADVICE_NONE)
		return
	if ch == "w":
		_debug_spawn_selected(mx, my, gx, gy)
		return

	if ch == "q":
		if App.is_survival_endless(App.game_mode):
			App.easy_planting_cheat = true
			# The original iterates x over the row count and y over the column count; kept as-is.
			for yy in MAX_GRID_SIZE_X:
				for xx in MAX_GRID_SIZE_Y:
					if can_plant_at(xx, yy, PvZ.SEED_LILYPAD) == PvZ.PLANTING_OK:
						add_plant(xx, yy, PvZ.SEED_LILYPAD, PvZ.SEED_NONE)
					if can_plant_at(xx, yy, PvZ.SEED_PUMPKINSHELL) == PvZ.PLANTING_OK and (xx <= 6 or is_pool_square(xx, yy)):
						add_plant(xx, yy, PvZ.SEED_PUMPKINSHELL, PvZ.SEED_NONE)
					if can_plant_at(xx, yy, PvZ.SEED_GATLINGPEA) == PvZ.PLANTING_OK:
						if xx < 5:
							add_plant(xx, yy, PvZ.SEED_GATLINGPEA, PvZ.SEED_NONE)
						elif xx == 5:
							add_plant(xx, yy, PvZ.SEED_TORCHWOOD, PvZ.SEED_NONE)
						elif xx == 6:
							add_plant(xx, yy, PvZ.SEED_SPLITPEA, PvZ.SEED_NONE)
						elif yy == 2 or yy == 3:
							add_plant(xx, yy, PvZ.SEED_GLOOMSHROOM, PvZ.SEED_NONE)
							if can_plant_at(xx, yy, PvZ.SEED_INSTANT_COFFEE) == PvZ.PLANTING_OK:
								add_plant(xx, yy, PvZ.SEED_INSTANT_COFFEE, PvZ.SEED_NONE)
		elif App.is_izombie_level():
			App.easy_planting_cheat = true
			if challenge.has_method("i_zombie_place_zombie"):
				for i in 5:
					challenge.call("i_zombie_place_zombie", PvZ.ZOMBIE_FOOTBALL, 6, i)
		else:
			App.easy_planting_cheat = true
			for yy in MAX_GRID_SIZE_Y:
				for xx in MAX_GRID_SIZE_X:
					if stage_has_roof() and can_plant_at(xx, yy, PvZ.SEED_FLOWERPOT) == PvZ.PLANTING_OK:
						add_plant(xx, yy, PvZ.SEED_FLOWERPOT, PvZ.SEED_NONE)
					if can_plant_at(xx, yy, PvZ.SEED_LILYPAD) == PvZ.PLANTING_OK:
						add_plant(xx, yy, PvZ.SEED_LILYPAD, PvZ.SEED_NONE)
					if can_plant_at(xx, yy, PvZ.SEED_THREEPEATER) == PvZ.PLANTING_OK:
						add_plant(xx, yy, PvZ.SEED_THREEPEATER, PvZ.SEED_NONE)
			if not challenge.update_zombie_spawning():
				var remaining := mini(num_waves - current_wave, 20)
				while remaining > 0:
					spawn_zombie_wave()
					remaining -= 1
			if App.is_scary_potter_level():
				for gi in grid_items.duplicate():
					if not gi.dead and gi.grid_item_type == PvZ.GRIDITEM_SCARY_POT:
						challenge.scary_potter_open_pot(gi)
		return

	if ch == "O":
		App.easy_planting_cheat = true
		for yy in MAX_GRID_SIZE_Y:
			for xx in 3:
				if can_plant_at(xx, yy, PvZ.SEED_FLOWERPOT) == PvZ.PLANTING_OK:
					add_plant(xx, yy, PvZ.SEED_FLOWERPOT, PvZ.SEED_NONE)
		return

	match ch:
		"?", "/":
			if huge_wave_count_down > 0:
				huge_wave_count_down = 1
			else:
				zombie_count_down = 6
		"1":
			var top := get_top_plant_at(0, 0, PvZ.TOPPLANT_ANY)
			if top:
				top.die()
				challenge.zombie_ate_plant(null, top)
		"B":
			fog_blown_count_down = 2200
		"r":
			spawn_zombies_from_graves()
		"0":
			add_sun_money(100)
			App.play_sample("SOUND_BUTTONCLICK")
		"9":
			add_sun_money(999999)
			App.play_sample("SOUND_BUTTONCLICK")
		"$":
			App.player_info.add_coins(100)
			App.play_sample("SOUND_BUTTONCLICK")
			show_coin_bank()
		"-":
			sun_money = maxi(sun_money - 100, 0)
		"%":
			App.switch_screen_mode(App.is_windowed, not App.is_3d_accelerated(), false)
		"M":
			App.music.burst_override = 2 - (1 if App.music.burst_override != 1 else 0)

func _debug_spawn_selected(mx: int, my: int, gx: int, gy: int) -> void:
	var sel := debug_object_selection
	match debug_object_type:
		0:
			add_zombie_in_row(sel, gy, Zombie.ZOMBIE_WAVE_DEBUG)
		1:
			var imitater := PvZ.SEED_NONE
			if sel == PvZ.SEED_IMITATER:
				imitater = Tod.rand_range_int(0, PvZ.NUM_SEED_TYPES - 1)
			add_plant(gx, gy, sel, imitater)
		2:
			add_coin(mx, my - 70, sel, PvZ.COIN_MOTION_COIN)
		3:
			var pr := add_projectile(mx, my, PvZ.RENDER_LAYER_PLANT, gy, sel)
			pr.damage_range_flags = 1
			pr.motion_type = PvZ.MOTION_STRAIGHT
			if pr.projectile_type == PvZ.PROJECTILE_FIREBALL:
				pr.convert_to_fireball(gx)
		4:
			load_background_debug(sel)
		5:
			var z := add_zombie_in_row(sel, gy, Zombie.ZOMBIE_WAVE_DEBUG)
			if z:
				z.pos_x = mx
				z.start_mind_controlled()
		6:
			var gi := alloc_grid_item()
			gi.grid_item_type = sel
			gi.render_order = make_render_order(PvZ.RENDER_LAYER_PLANT, gy, 800)
			gi.grid_item_counter = -Tod.rand_int(50)
			gi.grid_x = gx
			gi.grid_y = gy
			match sel:
				PvZ.GRIDITEM_CRATER:
					gi.render_order = make_render_order(PvZ.RENDER_LAYER_GROUND, gy, 1)
					gi.grid_item_counter = 18000
				PvZ.GRIDITEM_PORTAL_CIRCLE, PvZ.GRIDITEM_PORTAL_SQUARE:
					gi.render_order = make_render_order(PvZ.RENDER_LAYER_PARTICLE, gy, 0)
					gi.open_portal()
				PvZ.GRIDITEM_GRAVESTONE:
					gi.render_order = make_render_order(PvZ.RENDER_LAYER_GRAVE_STONE, gy, 3)
					gi.add_grave_stone_particles()
				PvZ.GRIDITEM_SCARY_POT:
					gi.scary_pot_type = Tod.rand_range_int(PvZ.SCARYPOT_SEED, PvZ.SCARYPOT_SUN)
					gi.seed_type = Tod.rand_range_int(0, PvZ.NUM_SEED_TYPES - 1)
					gi.zombie_type = Tod.rand_range_int(0, PvZ.NUM_ZOMBIE_TYPES - 1)
					gi.grid_item_state = PvZ.GRIDITEM_STATE_SCARY_POT_ZOMBIE
					gi.sun_count = 5

func key_down(key: int) -> void:
	if is_net_game():
		App.net.board_key_down(self, key)
		return
	do_typing_check(key)
	if App.game_scene == PvZ.SCENE_LEVEL_INTRO and App.game_mode != PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN and App.game_mode != PvZ.GAMEMODE_TREE_OF_WISDOM:
		cut_scene.key_down(key)
	elif key == WidgetManager.KEYCODE_RETURN or key == WidgetManager.KEYCODE_SPACE:
		if is_scary_potter_dave_talking() and App.crazy_dave_message_index != -1:
			challenge.advance_crazy_dave_dialog()
		elif App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN or App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
			App.zen_garden.advance_crazy_dave_dialog()
		elif key == WidgetManager.KEYCODE_SPACE and App.can_pause_now():
			App.play_sample("SOUND_PAUSE")
			App.do_pause_dialog()
	elif key == WidgetManager.KEYCODE_ESCAPE:
		if cursor_object.cursor_type != PvZ.CURSOR_TYPE_NORMAL and cursor_object.cursor_type != PvZ.CURSOR_TYPE_HAMMER:
			refresh_seed_packet_from_cursor()
		elif can_interact_with_board_buttons() and App.game_scene != PvZ.SCENE_ZOMBIES_WON:
			App.set_cursor(App.CURSOR_POINTER)
			App.do_new_options(false)
