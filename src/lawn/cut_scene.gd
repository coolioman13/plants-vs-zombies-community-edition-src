class_name CutScene
extends RefCounted
## Port of CutScene: level intro (pan to the street, seed chooser, sod roll, Crazy Dave),
## zombies-won sequence, upsell and intro movies.

const TIME_PAN_RIGHT_START := 1500
const TIME_PAN_RIGHT_END := 3500
const TIME_EARLY_DAVE_ENTER_START := 2000
const TIME_EARLY_DAVE_ENTER_END := 2750
const TIME_EARLY_DAVE_LEAVE_START := 3250
const TIME_EARLY_DAVE_LEAVE_END := 4000
const TIME_SEED_CHOOSER_SLIDE_ON_START := 4000
const TIME_SEED_CHOOSER_SLIDE_ON_END := 4250
const TIME_SEED_CHOOSER_SLIDE_OFF_START := 4500
const TIME_SEED_CHOOSER_SLIDE_OFF_END := 4750
const TIME_SEED_BANK_ON_START := 4000
const TIME_SEED_BANK_ON_END := 4250
const TIME_PAN_LEFT_START := 4500
const TIME_PAN_LEFT_END := 6000
const TIME_SEED_BANK_RIGHT_START := 4750
const TIME_SEED_BANK_RIGHT_END := 6000
const TIME_ROLL_SOD_START := 6000
const TIME_ROLL_SOD_END := 8000
const TIME_GRAVE_STONE_START := 6000
const TIME_GRAVE_STONE_END := 7000
const TIME_READY_SET_PLANT_START := 6000
const TIME_READY_SET_PLANT_END := 7830
const TIME_FOG_ROLL_IN := 5950
const TIME_CRAZY_DAVE_ENTER_START := 6500
const TIME_CRAZY_DAVE_ENTER_END := 7250
const TIME_CRAZY_DAVE_LEAVE_START := 7750
const TIME_CRAZY_DAVE_LEAVE_END := 8500
const TIME_INTRO_END := 6000
const LOST_TIME_PAN_RIGHT_START := 1500
const LOST_TIME_PAN_RIGHT_END := 3500
const LOST_TIME_BRAIN_GRAPHIC_START := 6000
const LOST_TIME_BRAIN_GRAPHIC_SHAKE := 7000
const LOST_TIME_BRAIN_GRAPHIC_CANCEL_SHAKE := 8000
const LOST_TIME_BRAIN_GRAPHIC_END := 11000
const LOST_TIME_END := 11000
const TIME_INTRO_PRESENTS_FADE_IN := 1000
const TIME_INTRO_LOGO_START := 5500
const TIME_INTRO_LOGO_END := 5900
const TIME_INTRO_PAN_RIGHT_START := 5890
const TIME_INTRO_PAN_RIGHT_END := 11890
const TIME_INTRO_FADE_OUT := 10890
const TIME_INTRO_FADE_OUT_END := 11890
const TIME_INTRO_END_MOVIE := 13890
const TIME_LAWN_MOWER_DURATION := 250
const TIME_LAWN_MOWER_START := [6300, 6250, 6200, 6150, 6100, 6050]
const PURCHASE_COUNT_OFFSET := 1000

var board: Board
var cutscene_time := 0
var sod_time := 0
var grave_stone_time := 0
var ready_set_plant_time := 0
var fog_time := 0
var boss_time := 0
var crazy_dave_time := 0
var lawn_mower_time := 0
var crazy_dave_dialog_start := -1
var seed_choosing := false
var zombies_won_reanim: Reanimation = null
var preloaded := false
var placed_zombies := false
var placed_lawn_items := false
var crazy_dave_count_down := 0
var crazy_dave_last_talk_index := -1
var upsell_hide_board := false
var upsell_challenge_screen: ChallengeScreen = null
var pre_updating_board := false

func _init() -> void:
	board = App.board

func place_a_zombie(zombie_type: int, gx: int, gy: int) -> void:
	var ducky := false
	if zombie_type == PvZ.ZOMBIE_DUCKY_TUBE and App.game_mode == PvZ.GAMEMODE_CHALLENGE_WAR_AND_PEAS_2:
		zombie_type = PvZ.ZOMBIE_PEA_HEAD
		ducky = true
	var z := board.add_zombie_in_row(zombie_type, gy, Zombie.ZOMBIE_WAVE_CUTSCENE)
	if z == null:
		return
	var roof := board.stage_has_roof()
	z.pos_x = gx * PvZ.STREET_ZOMBIE_GRID_SIZE_X + (PvZ.STREET_ZOMBIE_ROOF_START_X if roof else PvZ.STREET_ZOMBIE_START_X) + PvZ.BOARD_ADDITIONAL_WIDTH
	z.pos_y = gy * PvZ.STREET_ZOMBIE_GRID_SIZE_Y + PvZ.STREET_ZOMBIE_START_Y + PvZ.BOARD_OFFSET_Y
	if gx % 2 == 1:
		z.pos_y += 30.0
	if ducky:
		z.body_reanim.assign_render_group_to_track("Zombie_duckytube", Reanimation.RENDER_GROUP_NORMAL)
	if roof:
		z.pos_y -= gy * 2 - gx * 7 + PvZ.STREET_ZOMBIE_ROOF_OFFSET
		z.pos_x -= 5.0
	if zombie_type == PvZ.ZOMBIE_ZAMBONI:
		z.pos_y -= 10.0
		z.pos_x -= 30.0
	elif App.is_little_trouble_level():
		z.pos_y += Tod.rand_int(50) - 25
		z.pos_x += Tod.rand_int(50) - 25
	elif is_2x2_zombie(zombie_type):
		z.pos_x += Tod.rand_int(15) - 20
	elif gy == 4 and (App.can_show_almanac() or App.can_show_store()):
		z.pos_x += Tod.rand_int(15)
	else:
		z.pos_y += Tod.rand_int(15)
		z.pos_x += Tod.rand_int(15)
	z.render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_LAWN, 0, (gx % 2) * 2 + gy * 4)
	if zombie_type == PvZ.ZOMBIE_BUNGEE:
		z.render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_GROUND, 0, 0)
		z.row = 0
		z.pos_x = gx * 50.0 + 950.0 + PvZ.BOARD_ADDITIONAL_WIDTH
		z.pos_y = 50.0 + PvZ.BOARD_OFFSET_Y
	elif zombie_type == PvZ.ZOMBIE_BOBSLED:
		z.render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_LAWN, 0, 1000)
		z.row = 0
		z.pos_x = 1105.0 + PvZ.BOARD_ADDITIONAL_WIDTH
		z.pos_y = 480.0 + PvZ.BOARD_OFFSET_Y

func can_zombie_go_in_grid_spot(zombie_type: int, gx: int, gy: int, grid: Array) -> bool:
	if grid[gx][gy]:
		return false
	if is_2x2_zombie(zombie_type):
		if gx == 0 or gy == 0:
			return false
		if grid[gx - 1][gy] or grid[gx][gy - 1] or grid[gx - 1][gy - 1]:
			return false
	if gx == 4:
		if gy == 0:
			return false
	else:
		if zombie_type == PvZ.ZOMBIE_ZAMBONI:
			return false
		if gx == 0 and board.stage_has_pool():
			return false
	if board.stage_has_roof() and gx == 0 and gy == 0:
		return false
	if gx == 4 and board.stage_has_fog() and zombie_type == PvZ.ZOMBIE_BALLOON:
		return false
	if is_2x2_zombie(zombie_type) or zombie_type == PvZ.ZOMBIE_ZAMBONI or zombie_type == PvZ.ZOMBIE_BOBSLED or zombie_type == PvZ.ZOMBIE_POLEVAULTER:
		if gx == 0:
			return false
		if gx == 1 and (board.stage_has_pool() or gy == 0):
			return false
	return true

func find_place_for_street_zombies(zombie_type: int, grid: Array) -> Vector2i:
	if zombie_type == PvZ.ZOMBIE_BUNGEE:
		return Vector2i(0, 0)
	var picks: Array = []
	for gx in 5:
		for gy in 5:
			if can_zombie_go_in_grid_spot(zombie_type, gx, gy, grid):
				picks.append({"x": gx, "y": gy, "weight": 1})
	if picks.is_empty():
		return Vector2i(2, 2)
	var cell: Dictionary = Tod.pick_from_weighted_grid_array(picks)
	return Vector2i(cell.x, cell.y)

func find_and_place_zombie(zombie_type: int, grid: Array) -> void:
	var p := find_place_for_street_zombies(zombie_type, grid)
	if zombie_type != PvZ.ZOMBIE_BUNGEE:
		grid[p.x][p.y] = true
	if is_2x2_zombie(zombie_type) and p.x > 0 and p.y > 0:
		grid[p.x - 1][p.y] = true
		grid[p.x][p.y - 1] = true
		grid[p.x - 1][p.y - 1] = true
	place_a_zombie(zombie_type, p.x, p.y)
	if zombie_type == PvZ.ZOMBIE_BUNGEE and App.is_bungee_blitz_level():
		place_a_zombie(PvZ.ZOMBIE_BUNGEE, 1, p.y)
		place_a_zombie(PvZ.ZOMBIE_BUNGEE, 2, p.y)

static func is_2x2_zombie(zombie_type: int) -> bool:
	return zombie_type == PvZ.ZOMBIE_GARGANTUAR or zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR

## Definitions are cached on first use, so preloading only has to place the street zombies.
func preload_resources() -> void:
	if preloaded:
		return
	preloaded = true
	for wave in board.num_waves:
		var arr: PackedInt32Array = board.zombies_in_wave[wave]
		for i in BoardCore.MAX_ZOMBIES_IN_WAVE:
			if arr[i] == PvZ.ZOMBIE_INVALID:
				break
			var rt: int = LawnCommon.zombie_def(arr[i])[LawnCommon.ZDEF_REANIM]
			if rt >= 0:
				ReanimTypes.get_def(rt)
	place_street_zombies()

func place_street_zombies() -> void:
	if placed_zombies:
		return
	placed_zombies = true
	if board.is_versus():
		return
	if App.is_final_boss_level() or (not board.choose_seeds_on_current_level() and is_non_scrolling_cutscene()):
		return
	var total_count := 0
	var type_count := PackedInt32Array()
	type_count.resize(PvZ.NUM_ZOMBIE_TYPES)
	for wave in board.num_waves:
		var arr: PackedInt32Array = board.zombies_in_wave[wave]
		for i in BoardCore.MAX_ZOMBIES_IN_WAVE:
			var zt := arr[i]
			if zt == PvZ.ZOMBIE_INVALID:
				break
			if zt == PvZ.ZOMBIE_FLAG:
				continue
			if zt == PvZ.ZOMBIE_YETI and not App.is_stormy_night_level():
				continue
			if zt == PvZ.ZOMBIE_BOBSLED and App.game_mode != PvZ.GAMEMODE_CHALLENGE_BOBSLED_BONANZA:
				continue
			type_count[zt] += 1
			total_count += 1
			if zt == PvZ.ZOMBIE_BUNGEE or zt == PvZ.ZOMBIE_BOBSLED:
				type_count[zt] = 1
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_LAST_STAND:
		for zt in PvZ.NUM_ZOMBIE_TYPES:
			if zt != PvZ.ZOMBIE_YETI and board.zombie_allowed[zt]:
				type_count[zt] = maxi(type_count[zt], 1)
	if board.stage_has_pool():
		type_count[PvZ.ZOMBIE_DUCKY_TUBE] = 1
	var grid: Array = []
	for i in 5:
		var col: Array = [false, false, false, false, false]
		grid.append(col)
	var capacity := 10
	if App.is_little_trouble_level():
		capacity = 15
	elif (App.is_stormy_night_level() and App.is_adventure_mode()) or App.is_mini_boss_level():
		capacity = 18
	for zt in range(PvZ.ZOMBIE_NORMAL, PvZ.NUM_ZOMBIE_TYPES):
		if type_count[zt] != 0 and (is_2x2_zombie(zt) or zt == PvZ.ZOMBIE_ZAMBONI):
			find_and_place_zombie(zt, grid)
	for zt in range(PvZ.ZOMBIE_NORMAL, PvZ.NUM_ZOMBIE_TYPES):
		if type_count[zt] != 0 and not is_2x2_zombie(zt) and zt != PvZ.ZOMBIE_ZAMBONI:
			var n := type_count[zt]
			var preview := clampi(Tod.idiv(n * capacity, maxi(total_count, 1)), 1, n)
			for i in preview:
				find_and_place_zombie(zt, grid)

func place_lawn_items() -> void:
	if placed_lawn_items:
		return
	placed_lawn_items = true
	if not is_survival_repick():
		board.init_lawn_mowers()
		add_flower_pots()
	if not is_survival_repick():
		board.place_rake()

func is_survival_repick() -> bool:
	return App.is_survival_mode() and board.challenge.survival_stage > 0 and App.game_scene == PvZ.SCENE_LEVEL_INTRO

func is_non_scrolling_cutscene() -> bool:
	var gm := App.game_mode
	return gm == PvZ.GAMEMODE_CHALLENGE_ICE or gm == PvZ.GAMEMODE_UPSELL or gm == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN \
		or gm == PvZ.GAMEMODE_TREE_OF_WISDOM or gm == PvZ.GAMEMODE_CHALLENGE_ZOMBIQUARIUM or App.is_scary_potter_level() \
		or App.is_izombie_level() or App.is_whack_a_zombie_level() or App.is_shovel_level() or App.is_squirrel_level() \
		or App.is_wallnut_bowling_level()

func is_scrolled_left_at_start() -> bool:
	if board.challenge.survival_stage > 0 and App.is_survival_mode():
		return false
	return not is_non_scrolling_cutscene()

func can_get_packet_upgrade() -> bool:
	var cost := StoreScreen.get_item_cost(PvZ.STORE_ITEM_PACKET_UPGRADE)
	var pi := App.player_info
	return pi.purchases[PvZ.STORE_ITEM_PACKET_UPGRADE] == 0 and pi.coins >= cost and pi.didnt_purchase_packet_upgrade < 2

func can_get_second_packet_upgrade() -> bool:
	var cost := StoreScreen.get_item_cost(PvZ.STORE_ITEM_PACKET_UPGRADE)
	var pi := App.player_info
	return pi.purchases[PvZ.STORE_ITEM_PACKET_UPGRADE] == 1 and pi.coins >= cost and pi.didnt_purchase_packet_upgrade < 2

func start_level_intro() -> void:
	cutscene_time = 0
	board.seed_bank.move(PvZ.SEED_BANK_OFFSET_X, -Res.get_image("IMAGE_SEEDBANK").height)
	board.menu_button.btn_no_draw = true
	board.fast_button.btn_no_draw = true
	if App.seed_chooser_screen:
		App.seed_chooser_screen.mouse_visible = false
		App.seed_chooser_screen.move(0, PvZ.SEED_CHOOSER_OFFSET_Y)
		App.seed_chooser_screen.menu_button.btn_no_draw = true
	board.show_shovel = false
	board.seed_bank.cut_scene_darken = 255
	placed_zombies = false
	preloaded = false
	placed_lawn_items = false
	App.widget_manager.set_focus(board)
	var lvl := board.level
	if App.is_first_time_adventure_mode() and (lvl == 1 or lvl == 2 or lvl == 4):
		sod_time = TIME_ROLL_SOD_END - TIME_ROLL_SOD_START
		board.sod_position = 0
	else:
		sod_time = 0
		board.sod_position = 1000
	grave_stone_time = 0
	board.enable_grave_stones = false
	if board.stage_has_grave_stones():
		if App.is_adventure_mode() and App.is_whack_a_zombie_level():
			grave_stone_time = 0
		elif not is_survival_repick():
			grave_stone_time = TIME_GRAVE_STONE_END - TIME_GRAVE_STONE_START
	if App.is_first_time_adventure_mode() and lvl <= 2:
		ready_set_plant_time = 0
	elif App.is_shovel_level() or App.is_squirrel_level() or App.is_wallnut_bowling_level() \
			or App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZOMBIQUARIUM or App.game_mode == PvZ.GAMEMODE_CHALLENGE_LAST_STAND \
			or App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM or App.is_izombie_level() or App.is_whack_a_zombie_level() \
			or App.is_scary_potter_level():
		ready_set_plant_time = 0
	else:
		ready_set_plant_time = TIME_READY_SET_PLANT_END - TIME_READY_SET_PLANT_START
	lawn_mower_time = 0
	if not is_survival_repick():
		lawn_mower_time = 550
	var is_restart := board.prev_board_result == PvZ.BOARDRESULT_LOST or board.prev_board_result == PvZ.BOARDRESULT_RESTART
	var first := App.is_first_time_adventure_mode()
	if first and lvl == 11:
		crazy_dave_dialog_start = 201
	elif first and lvl == 12:
		crazy_dave_dialog_start = 1401
	elif first and lvl >= 13 and lvl <= 24 and lvl != 15 and lvl != 20 and lvl != 21 and can_get_packet_upgrade():
		crazy_dave_dialog_start = 1501
	elif first and lvl >= 16 and lvl <= 24 and lvl != 20 and lvl != 21 and can_get_second_packet_upgrade():
		crazy_dave_dialog_start = 1551
	elif App.is_wallnut_bowling_level() and App.is_adventure_mode():
		if first:
			crazy_dave_dialog_start = 2400
		else:
			crazy_dave_dialog_start = 2411
			board.challenge.show_bowling_line = true
		board.show_shovel = true
	elif first and lvl == 21:
		crazy_dave_dialog_start = 501
	elif App.is_whack_a_zombie_level() and App.is_adventure_mode():
		crazy_dave_dialog_start = 401
	elif App.is_little_trouble_level() and App.is_adventure_mode():
		crazy_dave_dialog_start = 701
	elif first and lvl == 31:
		crazy_dave_dialog_start = 801
	elif App.is_scary_potter_level() and App.is_adventure_mode():
		crazy_dave_dialog_start = 2500
	elif App.is_stormy_night_level() and App.is_adventure_mode():
		crazy_dave_dialog_start = 1101
	elif first and lvl == 41:
		crazy_dave_dialog_start = 1201
	elif App.is_bungee_blitz_level() and App.is_adventure_mode():
		crazy_dave_dialog_start = 1301 if first else 1304
	elif not first and lvl == 1 and (not App.playing_quickplay or App.crazy_seeds):
		crazy_dave_dialog_start = 1601
	elif App.game_mode == PvZ.GAMEMODE_PUZZLE_I_ZOMBIE_1:
		crazy_dave_dialog_start = 2200
	elif App.game_mode == PvZ.GAMEMODE_UPSELL:
		crazy_dave_dialog_start = 3300
		upsell_hide_board = true
		board.menu_button.btn_no_draw = false
	elif App.game_mode == PvZ.GAMEMODE_SCARY_POTTER_1 and not App.has_beaten_challenge(PvZ.GAMEMODE_SCARY_POTTER_1):
		crazy_dave_dialog_start = 3000
	elif App.is_final_boss_level() and App.is_adventure_mode() and not is_restart:
		crazy_dave_dialog_start = 2300
	elif App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
		if App.player_info.purchases[PvZ.STORE_ITEM_TREE_FOOD] < PURCHASE_COUNT_OFFSET:
			crazy_dave_dialog_start = 3200
			board.store_button.btn_no_draw = true
	# A custom level supplies its own dialogue, addressed from App.CUSTOM_DAVE_BASE up.
	var custom := CustomRuntime.active
	if custom != null:
		App.custom_dave_lines = custom.intro_lines()
		crazy_dave_dialog_start = App.CUSTOM_DAVE_BASE if not App.custom_dave_lines.is_empty() else -1
	else:
		App.custom_dave_lines = []
	if crazy_dave_dialog_start != -1:
		crazy_dave_time = TIME_EARLY_DAVE_LEAVE_END - TIME_PAN_RIGHT_START
		if App.is_final_boss_level() and App.is_adventure_mode():
			crazy_dave_time += 4000
	if board.stage_has_fog():
		fog_time = TIME_FOG_ROLL_IN - sod_time - lawn_mower_time - TIME_READY_SET_PLANT_START + 2000
	else:
		fog_time = 0
	boss_time = 4000 if App.is_final_boss_level() else 0
	if is_scrolled_left_at_start():
		board.move(PvZ.BOARD_OFFSET_X, 0)
	if is_non_scrolling_cutscene() and crazy_dave_time == 0:
		cancel_intro()
		return
	if App.is_final_boss_level() or App.is_scary_potter_level() or App.is_wallnut_bowling_level():
		preload_resources()
		place_lawn_items()
	var house := ""
	if crazy_dave_time <= 0 and App.game_mode != PvZ.GAMEMODE_INTRO:
		if App.is_survival_mode():
			house = App.get_current_challenge_name()
		elif App.is_adventure_mode():
			match board.background:
				PvZ.BACKGROUND_1_DAY, PvZ.BACKGROUND_2_NIGHT: house = TodStrings.translate("[PLAYERS_HOUSE]")
				PvZ.BACKGROUND_3_POOL, PvZ.BACKGROUND_4_FOG: house = TodStrings.translate("[PLAYERS_BACKYARD]")
				PvZ.BACKGROUND_5_ROOF, PvZ.BACKGROUND_6_BOSS: house = TodStrings.translate("[PLAYERS_ROOF]")
		else:
			house = App.get_current_challenge_name()
	house = Tod.replace_string(house, "{PLAYER}", App.player_info.name)
	if board.is_versus():
		house = "Versus!"
	if not house.is_empty():
		board.display_advice(house, PvZ.MESSAGE_STYLE_HOUSE_NAME, PvZ.ADVICE_NONE)
	if App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
		App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_ZEN_GARDEN)
	elif App.game_mode == PvZ.GAMEMODE_UPSELL:
		App.music.stop_all_music()
	elif App.game_mode == PvZ.GAMEMODE_INTRO:
		App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_POOL_WATERYGRAVES)
	elif crazy_dave_time > 0:
		App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_TITLE_CRAZY_DAVE_MAIN_THEME)
	elif App.is_final_boss_level():
		App.music.stop_all_music()
	else:
		App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_CHOOSE_YOUR_SEEDS)

func is_before_preloading() -> bool:
	return App.game_scene == PvZ.SCENE_LEVEL_INTRO and not preloaded

func cancel_intro() -> void:
	preload_resources()
	place_street_zombies()
	if cutscene_time < crazy_dave_time + TIME_PAN_RIGHT_END:
		cutscene_time = TIME_SEED_CHOOSER_SLIDE_ON_END + crazy_dave_time - 20
		if not is_non_scrolling_cutscene():
			board.move(PvZ.BOARD_WIDTH - PvZ.BOARD_IMAGE_WIDTH_OFFSET - PvZ.BOARD_ADDITIONAL_WIDTH, 0)
			board.roof_pole_offset = PvZ.ROOF_POLE_END
			board.roof_tree_offset = PvZ.ROOF_TREE_END
		if board.advice.message_style == PvZ.MESSAGE_STYLE_HOUSE_NAME:
			board.clear_advice(PvZ.ADVICE_NONE)
		if not App.is_challenge_without_seed_bank():
			board.seed_bank.move(PvZ.SEED_BANK_OFFSET_X_END, 0)
		if crazy_dave_dialog_start != -1:
			if App.crazy_dave_state == PvZ.CRAZY_DAVE_OFF:
				App.crazy_dave_enter()
			App.crazy_dave_message_index = crazy_dave_dialog_start
		while App.crazy_dave_message_index != -1:
			advance_crazy_dave_dialog(true)
		if board.level == 5:
			for p in board.plants:
				if not p.dead:
					p.die()
			board.challenge.show_bowling_line = true
	App.crazy_dave_die()
	if cutscene_time > crazy_dave_time + TIME_PAN_LEFT_START or not board.choose_seeds_on_current_level():
		cutscene_time = TIME_INTRO_END + lawn_mower_time + sod_time + grave_stone_time + crazy_dave_time + fog_time + boss_time + ready_set_plant_time - 20
		place_lawn_items()
		if not App.is_challenge_without_seed_bank():
			board.seed_bank.move(PvZ.SEED_BANK_OFFSET_X_END, 0)
		if App.is_stormy_night_level():
			board.challenge.challenge_state_counter = 0
		if App.is_final_boss_level():
			board.challenge.play_boss_enter()
		board.enable_grave_stones = true
		show_shovel()
		if App.is_final_boss_level():
			App.music.start_game_music()
		if board.fog_blown_count_down > 0:
			board.fog_blown_count_down = 0
			board.fog_offset = 0
		if board.tutorial_state != PvZ.TUTORIAL_ZEN_GARDEN_PICKUP_WATER:
			board.menu_button.btn_no_draw = false
		App.sound_system.stop_foley(PvZ.FOLEY_DIGGER)

func add_grave_stone_particles() -> void:
	for gi in board.grid_items:
		if not gi.dead and gi.grid_item_type == PvZ.GRIDITEM_GRAVESTONE:
			gi.add_grave_stone_particles()

func add_flower_pots() -> void:
	var cols := 0
	if board.level == 41:
		cols = 5
	elif board.level == 42:
		cols = 4
	elif board.level >= 43 and board.level <= 50:
		cols = 3
	elif App.game_mode == PvZ.GAMEMODE_CHALLENGE_COLUMN:
		cols = 8
	elif board.stage_has_roof():
		cols = 3
	for gx in cols:
		for gy in BoardCore.MAX_GRID_SIZE_Y:
			if board.can_plant_at(gx, gy, PvZ.SEED_FLOWERPOT) == PvZ.PLANTING_OK:
				board.new_plant(gx, gy, PvZ.SEED_FLOWERPOT, PvZ.SEED_NONE)

func calc_position(t_start: int, t_end: int, p_start: int, p_end: int) -> int:
	return Tod.animate_curve(t_start, t_end, cutscene_time, p_start, p_end, Tod.CURVE_EASE_IN_OUT)

func animate_board() -> void:
	var pan_right_start := TIME_PAN_RIGHT_START + crazy_dave_time
	var pan_right_end := TIME_PAN_RIGHT_END + crazy_dave_time
	var pan_left_start := TIME_PAN_LEFT_START + crazy_dave_time
	var pan_left_end := TIME_PAN_LEFT_END + crazy_dave_time
	if crazy_dave_time > 0:
		if cutscene_time == TIME_EARLY_DAVE_ENTER_START:
			App.crazy_dave_enter()
			if App.game_mode == PvZ.GAMEMODE_UPSELL:
				var dave := App.crazy_dave_reanim
				dave.play_reanim("anim_enterup", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 12)
				dave.set_position(150, 70)
		if cutscene_time == TIME_EARLY_DAVE_ENTER_END and crazy_dave_dialog_start != -1:
			App.crazy_dave_talk_index(crazy_dave_dialog_start)
			crazy_dave_dialog_start = -1
		if cutscene_time == TIME_EARLY_DAVE_LEAVE_END and is_non_scrolling_cutscene():
			cutscene_time = pan_left_end
	var board_offset := PvZ.BOARD_OFFSET_X if is_scrolled_left_at_start() else 0
	var street_offset := PvZ.BOARD_IMAGE_WIDTH_OFFSET + PvZ.BOARD_ADDITIONAL_WIDTH - PvZ.BOARD_WIDTH
	if cutscene_time <= pan_right_start:
		board.move(board_offset, 0)
	if cutscene_time > pan_right_start and cutscene_time <= pan_right_end:
		var pan := calc_position(pan_right_start, pan_right_end, -board_offset, street_offset)
		board.roof_pole_offset = calc_position(pan_right_start, pan_right_end, PvZ.ROOF_POLE_START, PvZ.ROOF_POLE_END)
		board.roof_tree_offset = calc_position(pan_right_start, pan_right_end, PvZ.ROOF_TREE_START, PvZ.ROOF_TREE_END)
		board.move(-pan, 0)
	if board.choose_seeds_on_current_level():
		var sc: SeedChooserScreen = App.seed_chooser_screen
		var on_start := TIME_SEED_CHOOSER_SLIDE_ON_START + crazy_dave_time
		var on_end := TIME_SEED_CHOOSER_SLIDE_ON_END + crazy_dave_time
		if cutscene_time > on_start and cutscene_time <= on_end:
			sc.move(0, calc_position(on_start, on_end, PvZ.SEED_CHOOSER_OFFSET_Y, 0))
			sc.menu_button.y = calc_position(on_start, on_end, -50, -10)
			sc.menu_button.btn_no_draw = false
		var off_start := TIME_SEED_CHOOSER_SLIDE_OFF_START + crazy_dave_time
		var off_end := TIME_SEED_CHOOSER_SLIDE_OFF_END + crazy_dave_time
		if cutscene_time > off_start and cutscene_time <= off_end:
			sc.move(0, calc_position(off_start, off_end, 0, PvZ.SEED_CHOOSER_OFFSET_Y))
			sc.menu_button.disabled = true
	if cutscene_time > pan_left_start:
		var pan := calc_position(pan_left_start, pan_left_end, street_offset, 0)
		board.roof_pole_offset = calc_position(pan_left_start, pan_left_end, PvZ.ROOF_POLE_END, PvZ.ROOF_POLE_START)
		board.roof_tree_offset = calc_position(pan_left_start, pan_left_end, PvZ.ROOF_TREE_END, PvZ.ROOF_TREE_START)
		board.move(-pan, 0)
	var prepare_end := 0
	if not board.choose_seeds_on_current_level():
		prepare_end = boss_time + fog_time + grave_stone_time + sod_time - TIME_SEED_CHOOSER_SLIDE_ON_START + TIME_PAN_LEFT_END
	var bank_on_start := TIME_SEED_BANK_ON_START + prepare_end + crazy_dave_time
	var bank_on_end := TIME_SEED_BANK_ON_END + prepare_end + crazy_dave_time
	if not App.is_challenge_without_seed_bank() and cutscene_time > bank_on_start and cutscene_time <= bank_on_end:
		var by := calc_position(bank_on_start, bank_on_end, -Res.get_image("IMAGE_SEEDBANK").height, 0)
		board.seed_bank.move(PvZ.SEED_BANK_OFFSET_X, by)
	var bank_right_start := TIME_SEED_BANK_RIGHT_START + crazy_dave_time
	var bank_right_end := TIME_SEED_BANK_RIGHT_END + crazy_dave_time
	if cutscene_time > bank_right_start:
		var bx := calc_position(bank_right_start, bank_right_end, PvZ.SEED_BANK_OFFSET_X, PvZ.SEED_BANK_OFFSET_X_END)
		board.seed_bank.cut_scene_darken = Tod.animate_curve(bank_right_start, bank_right_end, cutscene_time, 255, 128, Tod.CURVE_EASE_OUT)
		board.seed_bank.move(bx, board.seed_bank.y)
	if sod_time > 0:
		var sod_start := TIME_ROLL_SOD_START + crazy_dave_time
		var sod_end := TIME_ROLL_SOD_END + crazy_dave_time
		board.sod_position = Tod.animate_curve(sod_start, sod_end, cutscene_time, 0, 1000, Tod.CURVE_LINEAR)
		if cutscene_time == sod_start:
			App.play_foley(PvZ.FOLEY_DIGGER)
			var aw := PvZ.BOARD_ADDITIONAL_WIDTH
			var oy := PvZ.BOARD_OFFSET_Y
			var z0 := BoardCore.make_render_order(PvZ.RENDER_LAYER_ZOMBIE, 0, 0)
			var z1 := BoardCore.make_render_order(PvZ.RENDER_LAYER_ZOMBIE, 0, 1)
			if board.level == 1:
				App.add_reanimation(0 + aw, 0 + oy, z0, PvZ.REANIM_SODROLL)
				App.add_tod_particle(35 + aw, 348 + oy, z1, PvZ.PARTICLE_SOD_ROLL)
			elif board.level == 2:
				App.add_reanimation(0 + aw, -102 + oy, z0, PvZ.REANIM_SODROLL)
				App.add_reanimation(0 + aw, 111 + oy, z0, PvZ.REANIM_SODROLL)
				App.add_tod_particle(35 + aw, 246 + oy, z1, PvZ.PARTICLE_SOD_ROLL)
				App.add_tod_particle(35 + aw, 459 + oy, z1, PvZ.PARTICLE_SOD_ROLL)
			elif board.level == 4:
				App.add_reanimation(-3 + aw, -198 + oy, z0, PvZ.REANIM_SODROLL)
				App.add_reanimation(-3 + aw, 203 + oy, z0, PvZ.REANIM_SODROLL)
				App.add_tod_particle(32 + aw, 150 + oy, z1, PvZ.PARTICLE_SOD_ROLL)
				App.add_tod_particle(32 + aw, 511 + oy, z1, PvZ.PARTICLE_SOD_ROLL)
		if cutscene_time == sod_end:
			App.sound_system.stop_foley(PvZ.FOLEY_DIGGER)
	if grave_stone_time > 0:
		var grave_start := sod_time + TIME_GRAVE_STONE_START + crazy_dave_time
		if cutscene_time == grave_start:
			board.enable_grave_stones = true
			add_grave_stone_particles()
	if cutscene_time == pan_left_start:
		place_lawn_items()
	if not is_survival_repick():
		for gy in BoardCore.MAX_GRID_SIZE_Y:
			var mower_start: int = TIME_LAWN_MOWER_START[gy] + sod_time + grave_stone_time + crazy_dave_time
			if cutscene_time > mower_start:
				var m := board.find_lawn_mower_in_row(gy)
				if m:
					m.visible = true
					m.pos_x = calc_position(mower_start, mower_start + TIME_LAWN_MOWER_DURATION, -80 + PvZ.BOARD_ADDITIONAL_WIDTH, -21 + PvZ.BOARD_ADDITIONAL_WIDTH)
	if board.fog_blown_count_down > 0:
		var fog_in := TIME_FOG_ROLL_IN + sod_time + grave_stone_time + crazy_dave_time
		if cutscene_time > fog_in:
			if board.fog_blown_count_down > 200:
				board.fog_blown_count_down = 200
			board.fog_blown_count_down -= 1
	if App.is_stormy_night_level() and (cutscene_time == pan_right_end - 1000 or cutscene_time == pan_left_end):
		board.challenge.challenge_state = PvZ.STATECHALLENGE_STORM_FLASH_2
		board.challenge.challenge_state_counter = 310
	if boss_time > 0:
		var boss_enter := TIME_READY_SET_PLANT_START + lawn_mower_time + crazy_dave_time
		if cutscene_time == boss_enter:
			board.challenge.play_boss_enter()
	if App.is_final_boss_level() and cutscene_time == bank_on_start:
		App.music.start_game_music()
	var ready_time := TIME_READY_SET_PLANT_START + lawn_mower_time + sod_time + grave_stone_time + crazy_dave_time + fog_time + boss_time
	if ready_set_plant_time > 0 and cutscene_time == ready_time:
		App.add_reanimation(400 + PvZ.BOARD_ADDITIONAL_WIDTH, 324 + PvZ.BOARD_OFFSET_Y, BoardCore.make_render_order(PvZ.RENDER_LAYER_SCREEN_FADE, 0, 0), PvZ.REANIM_READYSETPLANT)
		App.play_sample("SOUND_READYSETPLANT")
		if not App.is_final_boss_level():
			App.music.fade_out(150)
	if ready_set_plant_time == 0 and cutscene_time == ready_time - 2000:
		if not App.is_final_boss_level():
			App.music.fade_out(200)
	if App.seed_chooser_screen and App.seed_chooser_screen.widget_manager:
		App.widget_manager.bring_to_front(App.seed_chooser_screen)

func show_shovel() -> void:
	if App.is_whack_a_zombie_level() or App.is_wallnut_bowling_level() or App.game_mode == PvZ.GAMEMODE_CHALLENGE_BEGHOULED \
			or App.game_mode == PvZ.GAMEMODE_CHALLENGE_BEGHOULED_TWIST or App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZOMBIQUARIUM \
			or App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN or App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM or App.is_izombie_level():
		return
	if not App.is_first_time_adventure_mode() or board.level > 4:
		board.show_shovel = true

func is_in_shovel_tutorial() -> bool:
	return board.tutorial_state == PvZ.TUTORIAL_SHOVEL_PICKUP or board.tutorial_state == PvZ.TUTORIAL_SHOVEL_DIG \
		or board.tutorial_state == PvZ.TUTORIAL_SHOVEL_KEEP_DIGGING

func start_seed_chooser() -> void:
	App.seed_chooser_screen.mouse_visible = true
	seed_choosing = true
	App.widget_manager.set_focus(App.seed_chooser_screen)

func end_seed_chooser() -> void:
	App.seed_chooser_screen.mouse_visible = false
	seed_choosing = false
	cutscene_time = crazy_dave_time + TIME_SEED_CHOOSER_SLIDE_ON_END + 10
	App.widget_manager.set_focus(board)

func is_showing_crazy_dave() -> bool:
	return App.game_scene == PvZ.SCENE_LEVEL_INTRO and crazy_dave_time > 0 and cutscene_time < TIME_PAN_RIGHT_END + crazy_dave_time

func update() -> void:
	if pre_updating_board:
		return
	if is_showing_crazy_dave() and (not board.paused or App.game_mode != PvZ.GAMEMODE_UPSELL):
		App.update_crazy_dave()
	if board.paused:
		return
	if App.game_scene == PvZ.SCENE_ZOMBIES_WON:
		cutscene_time += 10
		update_zombies_won()
		return
	if App.game_scene != PvZ.SCENE_LEVEL_INTRO or board.draw_count == 0:
		return
	if not preloaded:
		preload_resources()
	if not placed_zombies:
		place_street_zombies()
	if is_non_scrolling_cutscene() or not board.choose_seeds_on_current_level():
		place_lawn_items()
	var time_stop := seed_choosing or App.crazy_dave_message_index != -1 or is_in_shovel_tutorial()
	if App.game_mode == PvZ.GAMEMODE_UPSELL:
		update_upsell()
		if App.crazy_dave_state != PvZ.CRAZY_DAVE_OFF and App.crazy_dave_state != PvZ.CRAZY_DAVE_ENTERING:
			time_stop = true
	if App.game_mode == PvZ.GAMEMODE_INTRO:
		cutscene_time += 10
		update_intro()
		return
	if not time_stop:
		cutscene_time += 10
		if cutscene_time == TIME_SEED_CHOOSER_SLIDE_ON_END + crazy_dave_time and board.choose_seeds_on_current_level():
			start_seed_chooser()
	var start_time := TIME_INTRO_END + lawn_mower_time + sod_time + grave_stone_time + crazy_dave_time + fog_time + boss_time + ready_set_plant_time
	if cutscene_time >= start_time:
		board.remove_cutscene_zombies()
		if board.tutorial_state != PvZ.TUTORIAL_ZEN_GARDEN_PICKUP_WATER:
			board.menu_button.btn_no_draw = false
		show_shovel()
		App.start_playing()
		if board.fast_button and App.game_mode != PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN and App.game_mode != PvZ.GAMEMODE_TREE_OF_WISDOM \
				and not board.is_net_game():
			board.fast_button.btn_no_draw = false
		return
	animate_board()

func start_zombies_won() -> void:
	cutscene_time = 0
	board.menu_button.btn_no_draw = true
	board.fast_button.btn_no_draw = true
	board.show_shovel = false
	App.music.stop_all_music()
	board.stop_all_zombie_sounds()
	App.play_sample("SOUND_LOSEMUSIC")

func update_zombies_won() -> void:
	if cutscene_time > LOST_TIME_PAN_RIGHT_START and cutscene_time <= LOST_TIME_PAN_RIGHT_END:
		board.move(calc_position(LOST_TIME_PAN_RIGHT_START, LOST_TIME_PAN_RIGHT_END, 0, PvZ.BOARD_OFFSET_X), 0)
	if cutscene_time == LOST_TIME_BRAIN_GRAPHIC_START - 400 or cutscene_time == LOST_TIME_BRAIN_GRAPHIC_START - 900:
		App.play_foley(PvZ.FOLEY_CHOMP)
	if cutscene_time == LOST_TIME_BRAIN_GRAPHIC_START:
		var order := BoardCore.make_render_order(PvZ.RENDER_LAYER_SCREEN_FADE, 0, 0)
		var r := App.add_reanimation(-PvZ.BOARD_OFFSET_X + PvZ.BOARD_ADDITIONAL_WIDTH, PvZ.BOARD_OFFSET_Y, order, PvZ.REANIM_ZOMBIES_WON)
		r.anim_rate = 12.0
		r.loop_type = Reanimation.REANIM_PLAY_ONCE_AND_HOLD
		r.get_track_instance("fullscreen").track_color = Color.BLACK
		zombies_won_reanim = r
		r.set_frames_for_layer("ZombiesWon")
		App.play_foley(PvZ.FOLEY_SCREAM)
	if cutscene_time == LOST_TIME_BRAIN_GRAPHIC_SHAKE and zombies_won_reanim:
		zombies_won_reanim.set_shake_override("ZombiesWon", 1.0)
	if cutscene_time == LOST_TIME_BRAIN_GRAPHIC_CANCEL_SHAKE and zombies_won_reanim:
		zombies_won_reanim.set_shake_override("ZombiesWon", 0.0)
	if cutscene_time == LOST_TIME_BRAIN_GRAPHIC_END and zombies_won_reanim:
		zombies_won_reanim.set_frames_for_layer("anim_screen")
	if cutscene_time == LOST_TIME_END:
		if board.is_net_game():
			return  # NetSession takes everyone back to the lobby
		if App.is_survival_mode():
			var flags := board.get_survival_flags_completed()
			var flags_str := App.pluralize(flags, "[ONE_FLAG]", "[COUNT_FLAGS]")
			var s := Tod.replace_string(TodStrings.translate("[SURVIVAL_DEATH_MESSAGE]"), "{FLAGS}", flags_str)
			App.add_dialog(PvZ.DIALOG_GAME_OVER, GameOverDialog.new(s, true))
		else:
			App.add_dialog(PvZ.DIALOG_GAME_OVER, GameOverDialog.new("", false))

func is_cut_scene_over() -> bool:
	return cutscene_time >= LOST_TIME_END

func zombie_won_click() -> void:
	if board.is_net_game():
		return
	if is_cut_scene_over() or App.tod_cheat_keys:
		App.end_level()

func advance_crazy_dave_dialog(just_skipping: bool) -> void:
	if App.game_mode == PvZ.GAMEMODE_UPSELL or App.crazy_dave_message_index == -1:
		return
	if App.crazy_dave_message_index == 2406 and not just_skipping:
		board.set_tutorial_state(PvZ.TUTORIAL_SHOVEL_PICKUP)
		App.crazy_dave_leave()
		return
	if App.crazy_dave_message_index == 3200:
		App.player_info.purchases[PvZ.STORE_ITEM_TREE_FOOD] = PURCHASE_COUNT_OFFSET + 5
		board.menu_button.btn_no_draw = false
		board.store_button.btn_no_draw = false
	if not App.advance_crazy_dave_text():
		App.crazy_dave_leave()
		if App.is_final_boss_level() and App.is_adventure_mode():
			var dave := App.crazy_dave_reanim
			if dave:
				dave.play_reanim("anim_grab", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 18.0)
			App.music.fade_out(50)
			if not just_skipping:
				App.play_sample("SOUND_BUNGEE_SCREAM")
		elif App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
			App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_ZEN_GARDEN)
		elif board.choose_seeds_on_current_level():
			App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_CHOOSE_YOUR_SEEDS)
		elif is_non_scrolling_cutscene():
			App.music.fade_out(50)
		return
	var index := App.crazy_dave_message_index
	if index == 107 or index == 2407:
		board.challenge.shovel_add_wallnuts()
	if index == 405 or index == 2411:
		board.challenge.show_bowling_line = true
	if (index == 1503 or index == 1553) and not just_skipping:
		var cost := StoreScreen.get_item_cost(PvZ.STORE_ITEM_PACKET_UPGRADE)
		var packets: int = App.player_info.purchases[PvZ.STORE_ITEM_PACKET_UPGRADE]
		var body := Tod.replace_number_string(TodStrings.translate("[UPGRADE_DIALOG_BODY]"), "{SLOTS}", packets + 7)
		var amount := App.get_money_string(App.player_info.coins)
		var d := App.do_dialog(PvZ.DIALOG_PURCHASE_PACKET_SLOT, true, amount, body, "", Dialog.BUTTONS_YES_NO)
		d.move(d.x + 120, d.y + 130)
		board.show_coin_bank(100)
		var result: int = await d.wait_for_result()
		if result == Dialog.ID_YES:
			App.player_info.add_coins(-cost)
			App.player_info.purchases[PvZ.STORE_ITEM_PACKET_UPGRADE] += 1
			App.write_current_user_config()
			board.seed_bank.update_width()
			if index == 1503:
				App.crazy_dave_talk_index(1510)
			elif index == 1533:
				App.crazy_dave_talk_index(1560)
		else:
			App.player_info.didnt_purchase_packet_upgrade += 1
			if index == 1503:
				App.crazy_dave_talk_index(1520)
			elif index == 1553:
				App.crazy_dave_talk_index(1570)
	if index == 406:
		board.enable_grave_stones = true
		add_grave_stone_particles()

func mouse_down(_mx: int, _my: int) -> void:
	if App.tod_cheat_keys and App.game_mode == PvZ.GAMEMODE_UPSELL:
		if crazy_dave_count_down > 1:
			crazy_dave_count_down = 1
	elif is_showing_crazy_dave():
		advance_crazy_dave_dialog(false)
	elif App.tod_cheat_keys:
		cancel_intro()

func key_down(key: int) -> void:
	if App.game_mode == PvZ.GAMEMODE_UPSELL:
		if App.tod_cheat_keys and key == WidgetManager.KEYCODE_ESCAPE:
			crazy_dave_last_talk_index = 3316
			crazy_dave_count_down = 1
		elif key == WidgetManager.KEYCODE_SPACE or key == WidgetManager.KEYCODE_RETURN or key == WidgetManager.KEYCODE_ESCAPE:
			App.crazy_dave_stop_sound()
			App.play_sample("SOUND_PAUSE")
			App.music.game_music_pause(true)
			var result: int = await App.lawn_message_box(PvZ.DIALOG_MESSAGE, "[UPSELL_PAUSE_HEADER]", "[UPSELL_PAUSE_BODY]",
				"[UPSELL_RESUME_BUTTON]", "[MAIN_MENU_BUTTON]", Dialog.BUTTONS_YES_NO)
			if result == Dialog.ID_NO:
				App.kill_credit_screen()
				App.do_back_to_main()
			App.music.game_music_pause(false)
	elif (key == WidgetManager.KEYCODE_SPACE or key == WidgetManager.KEYCODE_RETURN) and is_showing_crazy_dave():
		advance_crazy_dave_dialog(false)
	elif App.tod_cheat_keys and (key == WidgetManager.KEYCODE_SPACE or key == WidgetManager.KEYCODE_RETURN or key == WidgetManager.KEYCODE_ESCAPE):
		cancel_intro()

func parse_delay_time_from_message() -> int:
	var text := App.get_crazy_dave_text(crazy_dave_last_talk_index)
	var i := text.find("{DELAY_")
	if i != -1:
		crazy_dave_count_down = int(text.substr(i + 7, text.find("}") - i - 7))
		return crazy_dave_count_down
	return 100

func parse_talk_time_from_message() -> int:
	var text := App.get_crazy_dave_text(crazy_dave_last_talk_index)
	var i := text.find("{TIME_")
	if i != -1:
		crazy_dave_count_down = int(text.substr(i + 6, text.find("}") - i - 6))
		return crazy_dave_count_down
	return 100

# ================================================================ upsell / intro movie
func clear_upsell_board() -> void:
	for i in BoardCore.MAX_GRID_SIZE_Y:
		board.ice_timer[i] = 0
		board.ice_min_x[i] = PvZ.BOARD_ICE_START
	for arr in [board.zombies, board.plants, board.coins, board.projectiles, board.grid_items, board.lawn_mowers]:
		for o in arr:
			o.dead = true
			o.freed = true
		arr.clear()
	for ps in EffectSystem.particle_systems:
		if not ps.dead:
			ps.particle_system_die()
	for r in EffectSystem.reanimations:
		if not r.dead and r.reanim_type != PvZ.REANIM_CRAZY_DAVE:
			r.die()
	board.pool_sparkly_particle = null
	upsell_challenge_screen = null

func add_upsell_zombie(zombie_type: int, px: int, gy: int) -> void:
	var z := board.add_zombie_in_row(zombie_type, gy, 0)
	if z == null:
		return
	z.pos_x = px
	z.pos_y = z.get_pos_y_based_on_row(gy)
	z.set_row(gy)
	z.x = int(z.pos_x)
	z.y = int(z.pos_y)

func _plants(list: Array) -> void:
	for e in list:
		board.new_plant(e[0], e[1], e[2], PvZ.SEED_NONE)

func _zombies(list: Array) -> void:
	for e in list:
		add_upsell_zombie(e[0], e[1] + PvZ.BOARD_ADDITIONAL_WIDTH, e[2])

func _pre_update_board() -> void:
	if board.stage_has_bushes():
		board.add_bushes()
	pre_updating_board = true
	for i in 100:
		board.update()
	pre_updating_board = false

func load_intro_board() -> void:
	clear_upsell_board()
	App.mute_sounds_for_cutscene = true
	var S := PvZ
	_plants([[0, 1, S.SEED_THREEPEATER], [0, 2, S.SEED_LILYPAD], [0, 2, S.SEED_PEASHOOTER], [0, 3, S.SEED_LILYPAD], [0, 3, S.SEED_PEASHOOTER],
		[0, 4, S.SEED_SUNFLOWER], [1, 0, S.SEED_THREEPEATER], [1, 1, S.SEED_SUNFLOWER], [1, 2, S.SEED_LILYPAD], [1, 2, S.SEED_SUNFLOWER],
		[1, 4, S.SEED_THREEPEATER], [1, 5, S.SEED_THREEPEATER], [2, 0, S.SEED_SUNFLOWER], [2, 1, S.SEED_PEASHOOTER], [2, 3, S.SEED_LILYPAD],
		[2, 3, S.SEED_PEASHOOTER], [2, 4, S.SEED_SUNFLOWER], [2, 5, S.SEED_SUNFLOWER], [3, 0, S.SEED_TORCHWOOD], [3, 4, S.SEED_THREEPEATER],
		[4, 2, S.SEED_LILYPAD], [4, 2, S.SEED_TORCHWOOD], [5, 1, S.SEED_TORCHWOOD], [5, 4, S.SEED_TORCHWOOD], [5, 5, S.SEED_TORCHWOOD],
		[6, 0, S.SEED_SPIKEWEED], [6, 4, S.SEED_SPIKEWEED], [7, 1, S.SEED_SPIKEWEED]])
	_zombies([[S.ZOMBIE_NORMAL, 460, 0], [S.ZOMBIE_FOOTBALL, 680, 0], [S.ZOMBIE_TRAFFIC_CONE, 730, 0], [S.ZOMBIE_NORMAL, 810, 0],
		[S.ZOMBIE_TRAFFIC_CONE, 670, 1], [S.ZOMBIE_NORMAL, 740, 1], [S.ZOMBIE_NORMAL, 880, 1], [S.ZOMBIE_NORMAL, 500, 2],
		[S.ZOMBIE_TRAFFIC_CONE, 680, 2], [S.ZOMBIE_PAIL, 604, 3], [S.ZOMBIE_SNORKEL, 880, 3], [S.ZOMBIE_NORMAL, 600, 4],
		[S.ZOMBIE_PAIL, 690, 4], [S.ZOMBIE_NORMAL, 780, 4], [S.ZOMBIE_CATAPULT, 730, 5], [S.ZOMBIE_NORMAL, 590, 5]])
	_pre_update_board()

func load_upsell_board_pool() -> void:
	clear_upsell_board()
	App.mute_sounds_for_cutscene = true
	var S := PvZ
	_plants([[0, 1, S.SEED_THREEPEATER], [0, 2, S.SEED_LILYPAD], [0, 2, S.SEED_PEASHOOTER], [0, 3, S.SEED_LILYPAD], [0, 3, S.SEED_PEASHOOTER],
		[0, 4, S.SEED_SUNFLOWER], [1, 0, S.SEED_THREEPEATER], [1, 1, S.SEED_SUNFLOWER], [1, 2, S.SEED_LILYPAD], [1, 2, S.SEED_SUNFLOWER],
		[1, 4, S.SEED_THREEPEATER], [1, 5, S.SEED_THREEPEATER], [2, 0, S.SEED_SUNFLOWER], [2, 1, S.SEED_PEASHOOTER], [2, 3, S.SEED_LILYPAD],
		[2, 3, S.SEED_PEASHOOTER], [2, 4, S.SEED_SUNFLOWER], [2, 5, S.SEED_SUNFLOWER], [3, 4, S.SEED_THREEPEATER], [4, 0, S.SEED_TORCHWOOD],
		[4, 2, S.SEED_LILYPAD], [4, 2, S.SEED_TORCHWOOD], [5, 1, S.SEED_TORCHWOOD], [5, 4, S.SEED_TORCHWOOD], [5, 5, S.SEED_TORCHWOOD],
		[6, 0, S.SEED_SPIKEWEED], [6, 3, S.SEED_TANGLEKELP], [6, 4, S.SEED_SPIKEWEED], [6, 5, S.SEED_SQUASH], [7, 1, S.SEED_SPIKEWEED]])
	_zombies([[S.ZOMBIE_NORMAL, 460, 0], [S.ZOMBIE_ZAMBONI, 680, 0], [S.ZOMBIE_TRAFFIC_CONE, 670, 1], [S.ZOMBIE_NORMAL, 740, 1],
		[S.ZOMBIE_NORMAL, 500, 2], [S.ZOMBIE_TRAFFIC_CONE, 680, 2], [S.ZOMBIE_NORMAL, 604, 3], [S.ZOMBIE_NORMAL, 690, 4],
		[S.ZOMBIE_NORMAL, 740, 4], [S.ZOMBIE_PAIL, 730, 5], [S.ZOMBIE_NORMAL, 590, 5]])
	_pre_update_board()
	App.mute_sounds_for_cutscene = false

func load_upsell_board_fog() -> void:
	clear_upsell_board()
	App.mute_sounds_for_cutscene = true
	board.background = PvZ.BACKGROUND_4_FOG
	var S := PvZ
	_plants([[0, 1, S.SEED_SUNSHROOM], [0, 4, S.SEED_SUNSHROOM], [1, 0, S.SEED_SUNSHROOM], [1, 1, S.SEED_SUNSHROOM], [1, 2, S.SEED_LILYPAD],
		[1, 2, S.SEED_CACTUS], [1, 4, S.SEED_SUNSHROOM], [1, 5, S.SEED_SUNSHROOM], [2, 0, S.SEED_CACTUS], [2, 4, S.SEED_CACTUS],
		[2, 5, S.SEED_FUMESHROOM], [3, 1, S.SEED_FUMESHROOM], [3, 2, S.SEED_LILYPAD], [3, 3, S.SEED_LILYPAD], [3, 3, S.SEED_CACTUS],
		[3, 5, S.SEED_PUFFSHROOM], [4, 0, S.SEED_PUFFSHROOM], [4, 1, S.SEED_MAGNETSHROOM], [4, 2, S.SEED_SEASHROOM], [4, 5, S.SEED_PUFFSHROOM],
		[5, 1, S.SEED_PUFFSHROOM], [5, 2, S.SEED_LILYPAD], [5, 2, S.SEED_PLANTERN], [5, 3, S.SEED_SEASHROOM], [6, 2, S.SEED_SEASHROOM],
		[6, 3, S.SEED_SEASHROOM]])
	_zombies([[S.ZOMBIE_NORMAL, 460, 0], [S.ZOMBIE_NORMAL, 680, 0], [S.ZOMBIE_BALLOON, 780, 0], [S.ZOMBIE_TRAFFIC_CONE, 670, 1],
		[S.ZOMBIE_BALLOON, 640, 1], [S.ZOMBIE_PAIL, 640, 2], [S.ZOMBIE_TRAFFIC_CONE, 780, 3], [S.ZOMBIE_BALLOON, 704, 4],
		[S.ZOMBIE_NORMAL, 690, 4], [S.ZOMBIE_PAIL, 590, 5], [S.ZOMBIE_NORMAL, 740, 5]])
	_pre_update_board()
	App.mute_sounds_for_cutscene = false

func load_upsell_challenge_screen() -> void:
	clear_upsell_board()
	upsell_challenge_screen = ChallengeScreen.new(PvZ.CHALLENGE_PAGE_CHALLENGE)

func load_upsell_board_roof() -> void:
	clear_upsell_board()
	App.mute_sounds_for_cutscene = true
	board.background = PvZ.BACKGROUND_5_ROOF
	for r in 5:
		board.plant_row[r] = PvZ.PLANTROW_NORMAL
	board.plant_row[5] = PvZ.PLANTROW_DIRT
	for gx in BoardCore.MAX_GRID_SIZE_X:
		for gy in BoardCore.MAX_GRID_SIZE_Y:
			board.grid_square_type[gx][gy] = PvZ.GRIDSQUARE_DIRT if board.plant_row[gy] == PvZ.PLANTROW_DIRT else PvZ.GRIDSQUARE_GRASS
	var S := PvZ
	var list: Array = []
	for e in [[0, 0, S.SEED_CABBAGEPULT], [0, 1, S.SEED_CABBAGEPULT], [0, 2, S.SEED_SUNFLOWER], [0, 3, S.SEED_SUNFLOWER], [0, 4, S.SEED_CABBAGEPULT],
			[1, 0, S.SEED_CABBAGEPULT], [1, 1, S.SEED_SUNFLOWER], [1, 2, S.SEED_CABBAGEPULT], [1, 3, S.SEED_CABBAGEPULT], [1, 4, S.SEED_SUNFLOWER],
			[2, 0, S.SEED_CABBAGEPULT], [2, 1, S.SEED_CABBAGEPULT], [2, 2, S.SEED_CABBAGEPULT], [2, 3, S.SEED_SUNFLOWER], [2, 4, S.SEED_CABBAGEPULT],
			[3, 1, S.SEED_CABBAGEPULT], [3, 2, S.SEED_CABBAGEPULT], [3, 3, S.SEED_SUNFLOWER], [3, 4, S.SEED_CABBAGEPULT],
			[4, 0, S.SEED_CHOMPER], [4, 1, S.SEED_CHOMPER], [4, 2, S.SEED_REPEATER], [4, 3, -1],
			[5, 2, S.SEED_WALLNUT], [5, 3, S.SEED_THREEPEATER], [5, 4, S.SEED_WALLNUT]]:
		list.append([e[0], e[1], S.SEED_FLOWERPOT])
		if e[2] != -1:
			list.append(e)
	_plants(list)
	_zombies([[S.ZOMBIE_NORMAL, 460, 0], [S.ZOMBIE_NORMAL, 680, 0], [S.ZOMBIE_CATAPULT, 780, 1], [S.ZOMBIE_TRAFFIC_CONE, 670, 1],
		[S.ZOMBIE_NORMAL, 580, 0], [S.ZOMBIE_NORMAL, 540, 1], [S.ZOMBIE_PAIL, 500, 1], [S.ZOMBIE_PAIL, 640, 2],
		[S.ZOMBIE_TRAFFIC_CONE, 780, 3], [S.ZOMBIE_NORMAL, 380, 3], [S.ZOMBIE_CATAPULT, 704, 4], [S.ZOMBIE_NORMAL, 690, 4],
		[S.ZOMBIE_NORMAL, 590, 4]])
	_pre_update_board()
	App.mute_sounds_for_cutscene = false

func update_upsell() -> void:
	if not board.menu_button.is_over and not (board.store_button and board.store_button.is_over):
		App.set_cursor(App.CURSOR_POINTER)
	if App.crazy_dave_state == PvZ.CRAZY_DAVE_OFF or App.crazy_dave_state == PvZ.CRAZY_DAVE_ENTERING:
		return
	if crazy_dave_last_talk_index == -1:
		App.crazy_dave_talk_index(crazy_dave_dialog_start)
		crazy_dave_last_talk_index = crazy_dave_dialog_start
		crazy_dave_count_down = parse_talk_time_from_message()
		return
	if crazy_dave_count_down > 0:
		crazy_dave_count_down -= 1
	if crazy_dave_last_talk_index == 3317:
		if crazy_dave_count_down == 0 and board.store_button:
			board.store_button.resize(510 + PvZ.BOARD_ADDITIONAL_WIDTH, 420 + PvZ.BOARD_OFFSET_Y, 210, 46)
			board.menu_button.resize(510 + PvZ.BOARD_ADDITIONAL_WIDTH, 480 + PvZ.BOARD_OFFSET_Y, 210, 46)
			board.menu_button.btn_no_draw = false
			board.store_button.btn_no_draw = false
		return
	if crazy_dave_last_talk_index == 3311 and crazy_dave_count_down == 90:
		App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_MINIGAME_LOONBOON)
	if crazy_dave_count_down != 0:
		return
	if App.crazy_dave_message_index != -1:
		crazy_dave_count_down = parse_delay_time_from_message()
		App.crazy_dave_stop_talking()
		return
	App.crazy_dave_talk_index(crazy_dave_last_talk_index + 1)
	crazy_dave_last_talk_index += 1
	crazy_dave_count_down = parse_talk_time_from_message()
	var dave := App.crazy_dave_reanim
	match crazy_dave_last_talk_index:
		3305:
			var squash := App.add_reanimation(0, 0, 0, PvZ.REANIM_SQUASH)
			squash.play_reanim("anim_idle", Reanimation.REANIM_LOOP, 0, 15.0)
			var eff := Attachment.attach_reanim(dave.get_track_instance("Dave_handinghand"), squash, 92.0, 387.0)
			eff.offset.y.y = 1.2
			dave.update()
		3306:
			var three := App.add_reanimation(0, 0, 0, PvZ.REANIM_THREEPEATER)
			three.play_reanim("anim_idle", Reanimation.REANIM_LOOP, 0, 15.0)
			for i in range(1, 4):
				var head := App.add_reanimation(0, 0, 0, PvZ.REANIM_THREEPEATER)
				head.loop_type = Reanimation.REANIM_LOOP
				head.anim_rate = three.anim_rate
				head.set_frames_for_layer("anim_head_idle%d" % i)
				head.attach_to_another_reanimation(three, "anim_head%d" % i)
			var eff := Attachment.attach_reanim(dave.get_track_instance("Dave_body1"), three, 0.0, 0.0)
			eff.offset = Tod.scale_rotate_matrix(-50, 230, 0.5, 1.2, 1.2)
			dave.update()
			three.update()
		3307:
			var magnet := App.add_reanimation(0, 0, 0, PvZ.REANIM_MAGNETSHROOM)
			magnet.play_reanim("anim_idle", Reanimation.REANIM_LOOP, 0, 15.0)
			magnet.overlay_matrix = Tod.scale_rotate_matrix(0, 0, 0.3, 1, 1)
			var eff := Attachment.attach_reanim(dave.get_track_instance("Dave_pot"), magnet, 49.0, 25.0)
			eff.offset.y.y = 1.2
			dave.update()
		3309:
			var t := dave.find_sub_reanim(PvZ.REANIM_THREEPEATER)
			if t:
				t.die()
			var m := dave.find_sub_reanim(PvZ.REANIM_MAGNETSHROOM)
			if m:
				m.die()
		3312:
			App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_MINIGAME_LOONBOON)
			load_upsell_board_pool()
			App.play_sample("SOUND_FINALWAVE")
			upsell_hide_board = false
		3313:
			load_upsell_board_fog()
			App.play_sample("SOUND_HUGE_WAVE")
			upsell_hide_board = false
		3314:
			load_upsell_challenge_screen()
			App.play_sample("SOUND_FINALWAVE")
			upsell_hide_board = false
		3315:
			clear_upsell_board()
			App.play_sample("SOUND_FINALWAVE")
			upsell_hide_board = true
			App.add_tod_particle(592 + PvZ.BOARD_ADDITIONAL_WIDTH, 240 + PvZ.BOARD_OFFSET_Y, BoardCore.make_render_order(PvZ.RENDER_LAYER_SCREEN_FADE, 0, 0), PvZ.PARTICLE_PERSENT_PICK_UP_ARROW)
		3316:
			load_upsell_board_roof()
			App.play_sample("SOUND_HUGE_WAVE")
			upsell_hide_board = false
		3317:
			clear_upsell_board()
			board.menu_button.btn_no_draw = true
			upsell_hide_board = true

func draw_upsell(g: Graphics) -> void:
	if crazy_dave_last_talk_index == 3315:
		var r := Reanimation.new()
		r.reanim_type = PvZ.REANIM_FLOWER_POT
		r.initialize(565 + PvZ.BOARD_ADDITIONAL_WIDTH, 360 + PvZ.BOARD_OFFSET_Y, ReanimTypes.get_def(PvZ.REANIM_FLOWER_POT))
		r.set_frames_for_layer("anim_zengarden")
		r.override_scale(1.3, 1.3)
		r.draw(g)
	if upsell_challenge_screen:
		upsell_challenge_screen.draw(g)
		g.clear_clip_rect()
	g.trans_x += PvZ.BOARD_ADDITIONAL_WIDTH
	App.draw_crazy_dave(g)
	g.trans_x -= PvZ.BOARD_ADDITIONAL_WIDTH
	board.menu_button.draw(g)

func update_intro() -> void:
	board.move(Tod.animate_curve(TIME_INTRO_PAN_RIGHT_START, TIME_INTRO_PAN_RIGHT_END, cutscene_time, 100, -100, Tod.CURVE_LINEAR), 0)
	if cutscene_time == 10:
		load_intro_board()
	if cutscene_time == TIME_INTRO_FADE_OUT:
		App.music.fade_out(250)
	if cutscene_time == TIME_INTRO_LOGO_END:
		App.add_tod_particle(400, 300, BoardCore.make_render_order(PvZ.RENDER_LAYER_TOP, 0, 0), PvZ.PARTICLE_SCREEN_FLASH)
		App.mute_sounds_for_cutscene = false
		App.play_sample("SOUND_HUGE_WAVE")
		App.mute_sounds_for_cutscene = true
	if cutscene_time == TIME_INTRO_FADE_OUT - 200:
		App.mute_sounds_for_cutscene = false
		App.play_sample("SOUND_SIREN")
		App.mute_sounds_for_cutscene = true
	if cutscene_time == TIME_INTRO_END_MOVIE:
		App.mute_sounds_for_cutscene = false
		App.pre_new_game(PvZ.GAMEMODE_ADVENTURE, false)

func draw_intro(g: Graphics) -> void:
	if cutscene_time <= TIME_INTRO_PAN_RIGHT_START or cutscene_time > TIME_INTRO_FADE_OUT_END:
		g.color = Color.BLACK
		g.fill_rect(-board.x, -board.y, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	var pan_start := TIME_INTRO_PAN_RIGHT_START - TIME_INTRO_PRESENTS_FADE_IN
	if cutscene_time > TIME_INTRO_PRESENTS_FADE_IN and cutscene_time <= pan_start:
		var alpha: int
		if cutscene_time < pan_start - 600:
			alpha = Tod.animate_curve(TIME_INTRO_PRESENTS_FADE_IN, TIME_INTRO_PRESENTS_FADE_IN + 300, cutscene_time, 0, 255, Tod.CURVE_LINEAR)
		else:
			alpha = Tod.animate_curve(pan_start - 600, pan_start - 300, cutscene_time, 255, 0, Tod.CURVE_LINEAR)
		TodStrings.draw_string(g, "[INTRO_PRESENTS]", Tod.idiv(PvZ.BOARD_WIDTH, 2) - board.x, 310 + PvZ.BOARD_OFFSET_Y - board.y,
			Res.get_font("FONT_BRIANNETOD16"), Color8(255, 255, 255, alpha), TodStrings.DS_ALIGN_CENTER)
	if cutscene_time > TIME_INTRO_LOGO_START and cutscene_time <= TIME_INTRO_PAN_RIGHT_END:
		var sc := Tod.animate_curve_float(TIME_INTRO_LOGO_START, TIME_INTRO_LOGO_END, cutscene_time, 5, 1, Tod.CURVE_EASE_OUT)
		var center := sc * 0.5
		var ox := Tod.idiv(PvZ.BOARD_WIDTH, 2) - board.x
		var oy := Tod.idiv(PvZ.BOARD_HEIGHT, 2) - board.y
		g.color = Color8(0, 0, 0, 128)
		g.fill_rect(int(ox - PvZ.BOARD_WIDTH * center), int(oy - 75 * sc), int(PvZ.BOARD_WIDTH * sc), int(150 * sc))
		var logo := Res.get_image("IMAGE_PVZ_LOGO")
		g.tod_draw_image_scaled_f(logo, ox - logo.width * center, oy - logo.height * center, sc, sc)
	if cutscene_time > TIME_INTRO_FADE_OUT and cutscene_time <= TIME_INTRO_FADE_OUT_END:
		g.color = Color8(0, 0, 0, Tod.animate_curve(TIME_INTRO_FADE_OUT, TIME_INTRO_FADE_OUT_END, cutscene_time, 0, 255, Tod.CURVE_LINEAR))
		g.fill_rect(-board.x, -board.y, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)

func should_run_upsell_board() -> bool:
	return (App.game_mode == PvZ.GAMEMODE_UPSELL or App.game_mode == PvZ.GAMEMODE_INTRO) and not upsell_hide_board

func is_after_seed_chooser() -> bool:
	return cutscene_time > TIME_SEED_CHOOSER_SLIDE_OFF_START + crazy_dave_time

func show_zombie_walking() -> bool:
	return cutscene_time > LOST_TIME_PAN_RIGHT_START

func is_panning_left() -> bool:
	return cutscene_time <= TIME_PAN_LEFT_END + crazy_dave_time
