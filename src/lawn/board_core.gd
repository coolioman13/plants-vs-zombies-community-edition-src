class_name BoardCore
extends Widget
## Board part 1: state, level setup, zombie wave picking, planting rules and object queries.
## (Board.cpp is split across BoardCore -> BoardUpdate -> BoardInput -> Board.)

const MAX_GRID_SIZE_X := 9
const MAX_GRID_SIZE_Y := 6
const MAX_ZOMBIES_IN_WAVE := 50
const MAX_ZOMBIE_WAVES := 100
const PROGRESS_METER_COUNTER := 150

class PlantsOnLawn:
	var under_plant: Plant
	var pumpkin_plant: Plant
	var flying_plant: Plant
	var normal_plant: Plant

class ZombiePicker:
	var zombie_count := 0
	var zombie_points := 0
	var zombie_type_count := PackedInt32Array()
	var all_waves_zombie_type_count := PackedInt32Array()

	func _init() -> void:
		zombie_type_count.resize(PvZ.NUM_ZOMBIE_TYPES)
		all_waves_zombie_type_count.resize(PvZ.NUM_ZOMBIE_TYPES)

	func init_for_wave() -> void:
		zombie_count = 0
		zombie_points = 0
		zombie_type_count.fill(0)

static var shown_more_sun_tutorial := false

var zombies: Array = []
var plants: Array = []
var projectiles: Array = []
var coins: Array = []
var lawn_mowers: Array = []
var grid_items: Array = []
var bushes: Array = []
var cursor_object: CursorObject
var cursor_preview: CursorPreview
var advice: MessageWidget
var seed_bank: SeedBank
var menu_button: GameButton
var store_button: GameButton
var fast_button: GameButton
var debug_text_mode := PvZ.DEBUG_TEXT_NONE
var debug_object_type := 0
var debug_object_selection := 0
var debug_object_limit := 0
var ignore_mouse_up := false
var tool_tip: ToolTipWidget
var cut_scene: CutScene
var challenge: Challenge
var paused := false
var grid_square_type: Array = []     # [x][y]
var grid_cel_look: Array = []
var grid_cel_offset: Array = []      # [x][y] -> Vector2i
var grid_cel_fog: Array = []         # [x][y+1]
var bush_list: Array = []
var enable_grave_stones := false
var special_grave_stone_x := -1
var special_grave_stone_y := -1
var fog_offset := 0.0
var fog_blown_count_down := 0
var plant_row := PackedInt32Array()
var wave_row_got_lawn_mowered := PackedInt32Array()
var bonus_lawn_mowers_remaining := 0
var ice_min_x := PackedInt32Array()
var ice_timer := PackedInt32Array()
var ice_particle: Array = []
var row_picking_array: Array = []
var zombies_in_wave: Array = []      # [wave] -> PackedInt32Array(MAX_ZOMBIES_IN_WAVE)
var zombie_allowed: Array = []
var sun_count_down := 0
var num_suns_fallen := 0
var shake_counter := 0
var shake_amount_x := 0
var shake_amount_y := 0
var background := PvZ.BACKGROUND_1_DAY
var level := 0
var sod_position := 0
var roof_pole_offset := 0
var roof_tree_offset := 0
var prev_mouse_x := -1
var prev_mouse_y := -1
var sun_money := 0
var num_waves := 0
var main_counter := 0
var effect_counter := 0
var draw_count := 0
var rise_from_grave_counter := 0
var out_of_money_counter := 0
var current_wave := 0
var total_spawned_waves := 0
var tutorial_state := PvZ.TUTORIAL_OFF
var tutorial_particle: TodParticleSystem = null
var tutorial_timer := -1
var last_bungee_wave := 0
var zombie_health_to_next_wave := -1
var zombie_health_wave_start := 0
var zombie_count_down := 0
var zombie_count_down_start := 0
var huge_wave_count_down := 0
var help_displayed: Array = []
var help_index := PvZ.ADVICE_NONE
var final_boss_killed := false
var show_shovel := false
var coin_bank_fade_count := 0
var level_complete := false
var board_fade_out_counter := -1
var next_survival_stage_counter := 0
var score_next_mower_counter := 0
var level_award_spawned := false
var progress_meter_width := 0
var flag_raise_counter := 0
var ice_trap_counter := 0
var board_rand_seed := 0
var pool_sparkly_particle: TodParticleSystem = null
var fwoosh: Array = []               # [row] -> Array[12] of Reanimation
var fwoosh_count_down := 0
var time_stop_counter := 0
var dropped_first_coin := false
var final_wave_sound_counter := 0
var cob_cannon_cursor_delay_counter := 0
var cob_cannon_mouse_x := 0
var cob_cannon_mouse_y := 0
var killed_yeti := false
var mustache_mode := false
var super_mower_mode := false
var future_mode := false
var pinata_mode := false
var dance_mode := false
var daisy_mode := false
var sukhbir_mode := false
var prev_board_result := PvZ.BOARDRESULT_NONE
var triggered_lawn_mowers := 0
var play_time_active_level := 0
var play_time_inactive_level := 0
var max_sun_plants := 0
var graves_cleared := 0
var plants_eaten := 0
var plants_shoveled := 0
var coins_collected := 0
var diamonds_collected := 0
var potted_plants_collected := 0
var chocolate_collected := 0
var peashooters_used := false
var catapults_used := false
var mushrooms_used := false
var mushrooms_n_coffee_used := false
var used_non_mushrooms := false
var coin_faded := false
var achievement_coin_count := 0
var gargantuars_killed := 0

# ---------------------------------------------------------------- online multiplayer (community edition)
## NetSession.MODE_* for online matches, -1 offline.
var net_mode := -1
## Per player slot: the SeedBank (one shared bank on conveyor / fixed-packet levels) and CursorObject.
var net_banks: Array = []
var net_cursors: Array = []
var net_teams: Array = []
var net_local_slot := 0
## True while a player's queued click is being applied to the simulation.
var net_replaying := false
var net_exec_slot := -1
var net_stepping := false
## Versus: true while the zombie team's sun is swapped into sun_money.
var net_zombie_context := false
var vs_zombie_sun := 0
var vs_zombie_sun_count_down := 0
var vs_zombie_suns_fallen := 0
var vs_targets: Array = []
var vs_winner := -1
var vs_end_counter := 0

func _init() -> void:
	App.board = self
	for i in MAX_GRID_SIZE_Y:
		var b := Bush.new()
		bushes.append(b)
		bush_list.append(b)
	EffectSystem.free_all()
	board_rand_seed = App.app_rand_seed
	cursor_object = CursorObject.new()
	cursor_preview = CursorPreview.new()
	seed_bank = SeedBank.new()
	cut_scene = CutScene.new()
	for gx in MAX_GRID_SIZE_X:
		var col_type: Array = []
		var col_look: Array = []
		var col_off: Array = []
		var col_fog := PackedInt32Array()
		for gy in MAX_GRID_SIZE_Y:
			col_type.append(PvZ.GRIDSQUARE_GRASS)
			col_look.append(Tod.rand_int(20))
			col_off.append(Vector2i(Tod.rand_int(10) - 5, Tod.rand_int(10) - 5))
		col_fog.resize(MAX_GRID_SIZE_Y + 1)
		grid_square_type.append(col_type)
		grid_cel_look.append(col_look)
		grid_cel_offset.append(col_off)
		grid_cel_fog.append(col_fog)
	plant_row.resize(MAX_GRID_SIZE_Y)
	wave_row_got_lawn_mowered.resize(MAX_GRID_SIZE_Y)
	ice_min_x.resize(MAX_GRID_SIZE_Y)
	ice_timer.resize(MAX_GRID_SIZE_Y)
	ice_particle.resize(MAX_GRID_SIZE_Y)
	for i in MAX_GRID_SIZE_Y:
		row_picking_array.append({"item": i, "weight": 0.0, "last": 0.0, "second_last": 0.0})
		var fw: Array = []
		fw.resize(12)
		fwoosh.append(fw)
	for w in MAX_ZOMBIE_WAVES:
		var arr := PackedInt32Array()
		arr.resize(MAX_ZOMBIES_IN_WAVE)
		arr.fill(PvZ.ZOMBIE_INVALID)
		zombies_in_wave.append(arr)
	zombie_allowed.resize(100)
	zombie_allowed.fill(false)
	help_displayed.resize(PvZ.NUM_ADVICE_TYPES)
	help_displayed.fill(false)
	mustache_mode = App.mustache_mode
	super_mower_mode = App.super_mower_mode
	future_mode = App.future_mode
	pinata_mode = App.pinata_mode
	dance_mode = App.dance_mode
	daisy_mode = App.daisy_mode
	sukhbir_mode = App.sukhbir_mode
	tool_tip = ToolTipWidget.new()
	advice = MessageWidget.new()
	challenge = Challenge.new()
	clip = false
	menu_button = GameButton.new(0)
	menu_button.draw_stone_button = true
	menu_button.parent_widget = self
	roof_pole_offset = PvZ.ROOF_POLE_START
	roof_tree_offset = PvZ.ROOF_TREE_START
	# the mobile view crops the widescreen margins, so the top-right buttons come in with them
	var button_offset_x := PvZ.BOARD_ADDITIONAL_WIDTH * 2 - App.board_view_crop
	fast_button = GameButton.new(2)
	fast_button.resize(740 + button_offset_x, 30, Res.get_image("IMAGE_FASTBUTTON").width, 46)
	fast_button.parent_widget = self
	fast_button.button_image = Res.get_image("IMAGE_FASTBUTTON")
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN or App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
		menu_button.label = "[MAIN_MENU_BUTTON]"
		menu_button.resize(628 + button_offset_x, -10, 163, 46)
		store_button = GameButton.new(1)
		store_button.button_image = Res.get_image("IMAGE_ZENSHOPBUTTON")
		store_button.over_image = Res.get_image("IMAGE_ZENSHOPBUTTON_HIGHLIGHT")
		store_button.down_image = Res.get_image("IMAGE_ZENSHOPBUTTON_HIGHLIGHT")
		store_button.resize(678 + button_offset_x, 33, store_button.button_image.width, 40)
		store_button.parent_widget = self
	else:
		menu_button.label = "[MENU_BUTTON]"
		menu_button.resize(681 + button_offset_x, -10, 117, 46)
		fast_button.btn_no_draw = true

func is_net_game() -> bool:
	return net_mode != -1

func is_versus() -> bool:
	return net_mode == NetSession.MODE_VERSUS

func net_team_of(slot: int) -> int:
	return net_teams[slot] if slot >= 0 and slot < net_teams.size() else NetSession.TEAM_PLANTS

## Team whose input is being handled: the replayed player's, otherwise the local player's.
func net_active_team() -> int:
	return net_team_of(net_exec_slot if net_replaying else net_local_slot)

func net_exec_is_local() -> bool:
	return not net_replaying or net_exec_slot == net_local_slot

## Creates the per-player banks and cursors. Called right after the board is made, before init_level.
func net_setup(mode: int, teams: Array, local_slot: int, shared_bank: bool) -> void:
	net_mode = mode
	net_teams = teams.duplicate()
	net_local_slot = local_slot
	net_banks.clear()
	net_cursors.clear()
	for i in teams.size():
		net_banks.append(seed_bank if (shared_bank or i == local_slot) else SeedBank.new())
		net_cursors.append(cursor_object if i == local_slot else CursorObject.new())

## Puts each player's chosen packets in their bank (after init_level). picks[slot] is an Array of seed types.
func net_apply_loadouts(picks: Array, shared_bank: bool) -> void:
	for i in net_banks.size():
		var bank: SeedBank = net_banks[i]
		bank.net_team = net_team_of(i)
		for p in bank.seed_packets:
			p.net_owner = -1 if shared_bank else i
		if shared_bank:
			continue
		var list: Array = picks[i] if i < picks.size() else []
		bank.num_packets = list.size()
		bank.width = Res.get_image("IMAGE_SEEDBANK").width + get_seed_bank_extra_width()
		bank.x = seed_bank.x
		bank.y = seed_bank.y
		for j in PvZ.SEEDBANK_MAX:
			var p: SeedPacket = bank.seed_packets[j]
			p.index = j
			p.x = get_seed_packet_position_x(j)
			p.y = 8
			p.packet_type = PvZ.SEED_NONE
			if j < list.size():
				p.set_packet_type(list[j])

## Restores which bank / cursor is the local player's (after a resync snapshot from the host).
func net_relink(local_slot: int) -> void:
	net_local_slot = local_slot
	seed_bank = net_banks[local_slot]
	cursor_object = net_cursors[local_slot]

func net_begin_exec(slot: int) -> void:
	net_replaying = true
	net_exec_slot = slot
	seed_bank = net_banks[slot]
	cursor_object = net_cursors[slot]
	if is_versus() and net_team_of(slot) == NetSession.TEAM_ZOMBIES:
		net_swap_sun(true)

func net_end_exec() -> void:
	net_swap_sun(false)
	seed_bank = net_banks[net_local_slot]
	cursor_object = net_cursors[net_local_slot]
	net_replaying = false
	net_exec_slot = -1

## Versus: swaps the zombie team's sun into sun_money so the stock planting code spends / checks the right pool.
func net_swap_sun(on: bool) -> void:
	if on == net_zombie_context:
		return
	var t := sun_money
	sun_money = vs_zombie_sun
	vs_zombie_sun = t
	net_zombie_context = on

func dispose_board() -> void:
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
		App.zen_garden.leave_garden()
	if App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
		challenge.tree_of_wisdom_leave()
	App.sound_system.stop_foley(PvZ.FOLEY_RAIN)
	App.zen_garden.board = null
	App.crazy_dave_die()
	EffectSystem.free_all()

# ================================================================ counting helpers
func are_enemy_zombies_on_screen() -> bool:
	for z in zombies:
		if not z.dead and z.has_head and not z.is_dead_or_dying() and not z.mind_controlled:
			return true
	return false

func count_zombies_on_screen() -> int:
	var c := 0
	for z in zombies:
		if not z.dead and z.has_head and not z.is_dead_or_dying() and not z.mind_controlled and z.is_on_board():
			c += 1
	return c

func count_untrigger_lawn_mowers() -> int:
	var c := 0
	for m in lawn_mowers:
		if not m.dead and m.mower_state != PvZ.MOWER_TRIGGERED and m.mower_state != PvZ.MOWER_SQUISHED:
			c += 1
	return c

func need_save_game() -> bool:
	return not App.playing_quickplay and App.game_mode != PvZ.GAMEMODE_CHALLENGE_ICE and App.game_mode != PvZ.GAMEMODE_UPSELL \
		and App.game_mode != PvZ.GAMEMODE_INTRO and App.game_mode != PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN \
		and App.game_mode != PvZ.GAMEMODE_TREE_OF_WISDOM and App.game_scene == PvZ.SCENE_PLAYING

func try_to_save_game() -> void:
	if need_save_game():
		if board_fade_out_counter > 0:
			complete_end_level_sequence_for_saving()
			return
		SaveGame.save_game(self, App.game_mode, App.player_info.id)

# ================================================================ grid items
func get_grid_item_at(type: int, gx: int, gy: int) -> GridItem:
	for gi in grid_items:
		if not gi.dead and gi.grid_x == gx and gi.grid_y == gy and gi.grid_item_type == type:
			return gi
	return null

func get_rake() -> GridItem:
	for gi in grid_items:
		if not gi.dead and gi.grid_item_type == PvZ.GRIDITEM_RAKE:
			return gi
	return null

func get_crater_at(gx: int, gy: int) -> GridItem: return get_grid_item_at(PvZ.GRIDITEM_CRATER, gx, gy)
## Whether any live zombie has mind_controlled == [param controlled]. Cached per tick; mind control changes and new
## zombies bump Zombie.mind_control_version, and deaths only leave a cached "yes" that makes callers scan anyway.
var _mc_cache_version := -1
var _mc_cache_tick := -1
var _mc_cache := [false, false]  # [any not controlled, any controlled]

func any_zombie_with_mind_control(controlled: bool) -> bool:
	if _mc_cache_version != Zombie.mind_control_version or _mc_cache_tick != main_counter:
		_mc_cache_version = Zombie.mind_control_version
		_mc_cache_tick = main_counter
		var any_normal := false
		var any_controlled := false
		for z in zombies:
			if z.dead:
				continue
			if z.mind_controlled:
				any_controlled = true
			else:
				any_normal = true
			if any_normal and any_controlled:
				break
		_mc_cache = [any_normal, any_controlled]
	return _mc_cache[1] if controlled else _mc_cache[0]

func get_grave_stone_at(gx: int, gy: int) -> GridItem: return get_grid_item_at(PvZ.GRIDITEM_GRAVESTONE, gx, gy)
func get_ladder_at(gx: int, gy: int) -> GridItem: return get_grid_item_at(PvZ.GRIDITEM_LADDER, gx, gy)
func get_scary_pot_at(gx: int, gy: int) -> GridItem: return get_grid_item_at(PvZ.GRIDITEM_SCARY_POT, gx, gy)
func get_squirrel_at(gx: int, gy: int) -> GridItem: return get_grid_item_at(PvZ.GRIDITEM_SQUIRREL, gx, gy)
func get_zen_tool_at(gx: int, gy: int) -> GridItem: return get_grid_item_at(PvZ.GRIDITEM_ZEN_TOOL, gx, gy)

func can_add_grave_stone_at(gx: int, gy: int) -> bool:
	var t: int = grid_square_type[gx][gy]
	if t != PvZ.GRIDSQUARE_GRASS and t != PvZ.GRIDSQUARE_HIGH_GROUND:
		return false
	for gi in grid_items:
		if not gi.dead and gi.grid_x == gx and gi.grid_y == gy:
			if gi.grid_item_type == PvZ.GRIDITEM_GRAVESTONE or gi.grid_item_type == PvZ.GRIDITEM_CRATER or gi.grid_item_type == PvZ.GRIDITEM_LADDER:
				return false
	return true

static func make_render_order(layer: int, the_row: int, offset: int) -> int:
	return the_row * PvZ.RENDER_LAYER_ROW_OFFSET + layer + offset

func alloc_grid_item() -> GridItem:
	var gi := GridItem.new()
	grid_items.append(gi)
	return gi

func add_a_ladder(gx: int, gy: int) -> GridItem:
	var gi := alloc_grid_item()
	gi.grid_item_type = PvZ.GRIDITEM_LADDER
	gi.render_order = make_render_order(PvZ.RENDER_LAYER_PLANT, gy, 800)
	gi.grid_x = gx
	gi.grid_y = gy
	return gi

func add_a_crater(gx: int, gy: int) -> GridItem:
	var gi := alloc_grid_item()
	gi.grid_item_type = PvZ.GRIDITEM_CRATER
	gi.render_order = make_render_order(PvZ.RENDER_LAYER_GROUND, gy, 1)
	gi.grid_x = gx
	gi.grid_y = gy
	return gi

func add_a_grave_stone(gx: int, gy: int) -> GridItem:
	var gi := alloc_grid_item()
	gi.grid_item_type = PvZ.GRIDITEM_GRAVESTONE
	gi.grid_item_counter = -Tod.rand_int(50)
	gi.render_order = make_render_order(PvZ.RENDER_LAYER_GRAVE_STONE, gy, 3)
	gi.grid_x = gx
	gi.grid_y = gy
	return gi

func add_grave_stones(gx: int, count: int, rng: RandomNumberGenerator) -> void:
	var allowed := 0
	for gy in MAX_GRID_SIZE_Y:
		if can_add_grave_stone_at(gx, gy):
			allowed += 1
	count = mini(count, allowed)
	var i := 0
	while i < count:
		var gy := rng.randi() % MAX_GRID_SIZE_Y
		if can_add_grave_stone_at(gx, gy):
			add_a_grave_stone(gx, gy)
			i += 1

func get_grave_stone_count() -> int:
	var c := 0
	for gi in grid_items:
		if not gi.dead and gi.grid_item_type == PvZ.GRIDITEM_GRAVESTONE:
			c += 1
	return c

# ================================================================ waves
func get_num_waves_per_flag() -> int:
	var cl := custom_level()
	if cl != null:
		return maxi(1, cl.level.waves_per_flag)
	return num_waves if (App.is_first_time_adventure_mode() and num_waves < 10) else 10

func is_flag_wave(wave: int) -> bool:
	var cl := custom_level()
	if cl != null:
		return cl.wave_is_flag(wave)
	if App.is_first_time_adventure_mode() and level == 1:
		return false
	var wpf := get_num_waves_per_flag()
	return wave % wpf == wpf - 1

func put_zombie_in_wave(zombie_type: int, wave: int, picker: ZombiePicker) -> void:
	var arr: PackedInt32Array = zombies_in_wave[wave]
	arr[picker.zombie_count] = zombie_type
	picker.zombie_count += 1
	if picker.zombie_count < MAX_ZOMBIES_IN_WAVE:
		arr[picker.zombie_count] = PvZ.ZOMBIE_INVALID
	zombies_in_wave[wave] = arr
	picker.zombie_points -= LawnCommon.zombie_def(zombie_type)[LawnCommon.ZDEF_VALUE]
	picker.zombie_type_count[zombie_type] += 1
	picker.all_waves_zombie_type_count[zombie_type] += 1

func put_in_missing_zombies(wave: int, picker: ZombiePicker) -> void:
	for zt in range(PvZ.ZOMBIE_NORMAL, PvZ.NUM_ZOMBIE_TYPES):
		if picker.zombie_type_count[zt] <= 0 and zt != PvZ.ZOMBIE_YETI and can_zombie_spawn_on_level(zt, level):
			put_zombie_in_wave(zt, wave, picker)

func pick_zombie_waves() -> void:
	var cl := custom_level()
	if cl != null:
		num_waves = cl.level.waves.size()
		return   # a custom level spells its waves out, so nothing is rolled here
	if App.is_adventure_mode():
		if App.is_whack_a_zombie_level():
			num_waves = 8
		else:
			num_waves = LawnDefs.ZOMBIE_WAVES[clampi(level - 1, 0, PvZ.NUM_LEVELS - 1)]
			if not App.is_first_time_adventure_mode() and not App.is_mini_boss_level():
				num_waves = 20 if num_waves < 10 else num_waves + 10
	elif App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN or App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
		num_waves = 0
	else:
		num_waves = 40
	var picker := ZombiePicker.new()
	var intro_type := get_introduced_zombie_type()
	for wave in num_waves:
		picker.init_for_wave()
		var arr0: PackedInt32Array = zombies_in_wave[wave]
		arr0[0] = PvZ.ZOMBIE_INVALID
		zombies_in_wave[wave] = arr0
		var flag_wave := is_flag_wave(wave)
		var final_wave := wave == num_waves - 1
		if App.is_bungee_blitz_level() and flag_wave:
			for i in 5:
				put_zombie_in_wave(PvZ.ZOMBIE_BUNGEE, wave, picker)
			if not final_wave:
				continue
		if App.is_adventure_mode() and App.has_finished_adventure() and level != 5:
			picker.zombie_points = Tod.idiv(wave * 2, 5) + 1
		else:
			picker.zombie_points = Tod.idiv(wave, 3) + 1
		if flag_wave:
			var plain := mini(picker.zombie_points, 8)
			picker.zombie_points = int(picker.zombie_points * 2.5)
			for i in plain:
				put_zombie_in_wave(PvZ.ZOMBIE_NORMAL, wave, picker)
			put_zombie_in_wave(PvZ.ZOMBIE_FLAG, wave, picker)
		if App.is_little_trouble_level() or App.is_wallnut_bowling_level():
			picker.zombie_points *= 4
		elif App.is_mini_boss_level():
			picker.zombie_points *= 3
		elif App.is_stormy_night_level() and App.is_adventure_mode():
			picker.zombie_points *= 3
		elif App.is_bungee_blitz_level():
			picker.zombie_points *= 2
		if intro_type != PvZ.ZOMBIE_INVALID and intro_type != PvZ.ZOMBIE_DUCKY_TUBE:
			var spawn_intro := false
			if intro_type == PvZ.ZOMBIE_DIGGER or intro_type == PvZ.ZOMBIE_BALLOON:
				if wave + 1 == 7 or final_wave:
					spawn_intro = true
			elif intro_type == PvZ.ZOMBIE_YETI:
				if wave == Tod.idiv(num_waves, 2) and not App.saw_yeti:
					spawn_intro = true
			elif wave == Tod.idiv(num_waves, 2) or final_wave:
				spawn_intro = true
			if spawn_intro:
				put_zombie_in_wave(intro_type, wave, picker)
		if level == 50 and final_wave:
			put_zombie_in_wave(PvZ.ZOMBIE_GARGANTUAR, wave, picker)
		if App.is_adventure_mode() and final_wave:
			put_in_missing_zombies(wave, picker)
		while picker.zombie_points > 0 and picker.zombie_count < MAX_ZOMBIES_IN_WAVE:
			var zt := pick_zombie_type(picker.zombie_points, wave, picker)
			put_zombie_in_wave(zt, wave, picker)

func get_level_rand_seed() -> int:
	var s: int = App.player_info.id + board_rand_seed
	if App.is_adventure_mode():
		s += App.player_info.finished_adventure * 101 + level
	else:
		s += challenge.survival_stage * 101 + App.game_mode
	return s

func pick_background() -> void:
	var cl := custom_level()
	if cl != null:
		background = cl.level.bg_builtin
		cl.apply_grid(self)
		if stage_has_grave_stones():
			pick_special_grave_stone()
		if stage_has_bushes():
			add_bushes()
		return
	match App.game_mode:
		PvZ.GAMEMODE_ADVENTURE:
			if level <= 1 * PvZ.LEVELS_PER_AREA:
				background = PvZ.BACKGROUND_1_DAY
			elif level <= 2 * PvZ.LEVELS_PER_AREA:
				background = PvZ.BACKGROUND_2_NIGHT
			elif level <= 3 * PvZ.LEVELS_PER_AREA:
				background = PvZ.BACKGROUND_3_POOL
			elif App.is_scary_potter_level():
				background = PvZ.BACKGROUND_2_NIGHT
			elif level <= 4 * PvZ.LEVELS_PER_AREA:
				background = PvZ.BACKGROUND_4_FOG
			elif level < PvZ.FINAL_LEVEL:
				background = PvZ.BACKGROUND_5_ROOF
			elif level == PvZ.FINAL_LEVEL:
				background = PvZ.BACKGROUND_6_BOSS
			else:
				background = PvZ.BACKGROUND_1_DAY
		PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
			background = PvZ.BACKGROUND_GREENHOUSE
		PvZ.GAMEMODE_TREE_OF_WISDOM:
			background = PvZ.BACKGROUND_TREEOFWISDOM
		PvZ.GAMEMODE_INTRO, PvZ.GAMEMODE_UPSELL:
			background = PvZ.BACKGROUND_3_POOL
		_:
			background = PvZ.BACKGROUND_1_DAY
	if background == PvZ.BACKGROUND_1_DAY or background == PvZ.BACKGROUND_GREENHOUSE or background == PvZ.BACKGROUND_TREEOFWISDOM:
		plant_row = PackedInt32Array([PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_DIRT])
		if App.is_adventure_mode() and App.is_first_time_adventure_mode():
			if level == 1:
				plant_row[0] = PvZ.PLANTROW_DIRT
				plant_row[1] = PvZ.PLANTROW_DIRT
				plant_row[3] = PvZ.PLANTROW_DIRT
				plant_row[4] = PvZ.PLANTROW_DIRT
			elif level == 2 or level == 3:
				plant_row[0] = PvZ.PLANTROW_DIRT
				plant_row[4] = PvZ.PLANTROW_DIRT
	elif background == PvZ.BACKGROUND_2_NIGHT:
		plant_row = PackedInt32Array([PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_DIRT])
	elif background == PvZ.BACKGROUND_3_POOL or background == PvZ.BACKGROUND_ZOMBIQUARIUM or background == PvZ.BACKGROUND_4_FOG:
		plant_row = PackedInt32Array([PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_POOL, PvZ.PLANTROW_POOL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL])
	else:
		plant_row = PackedInt32Array([PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_DIRT])
	for gx in MAX_GRID_SIZE_X:
		for gy in MAX_GRID_SIZE_Y:
			if plant_row[gy] == PvZ.PLANTROW_DIRT:
				grid_square_type[gx][gy] = PvZ.GRIDSQUARE_DIRT
			elif plant_row[gy] == PvZ.PLANTROW_POOL and gx >= 0 and gx <= 8:
				grid_square_type[gx][gy] = PvZ.GRIDSQUARE_POOL
			elif plant_row[gy] == PvZ.PLANTROW_HIGH_GROUND and gx >= 4 and gx <= 8:
				grid_square_type[gx][gy] = PvZ.GRIDSQUARE_HIGH_GROUND
	var rng := RandomNumberGenerator.new()
	rng.seed = get_level_rand_seed()
	if stage_has_grave_stones():
		if App.is_whack_a_zombie_level():
			challenge.whack_a_zombie_place_graves(9)
		elif background == PvZ.BACKGROUND_2_NIGHT:
			if not App.is_adventure_mode():
				add_grave_stones(4, 1, rng); add_grave_stones(5, 1, rng); add_grave_stones(6, 2, rng)
				add_grave_stones(7, 2, rng); add_grave_stones(8, 3, rng)
			elif level == 11 or level == 12 or level == 13:
				add_grave_stones(6, 1, rng); add_grave_stones(7, 1, rng); add_grave_stones(8, 2, rng)
			elif level == 14 or level == 16:
				add_grave_stones(5, 1, rng); add_grave_stones(6, 1, rng); add_grave_stones(7, 2, rng); add_grave_stones(8, 3, rng)
			elif level == 17 or level == 18 or level == 19:
				add_grave_stones(4, 1, rng); add_grave_stones(5, 2, rng); add_grave_stones(6, 2, rng)
				add_grave_stones(7, 3, rng); add_grave_stones(8, 3, rng)
			elif level >= 20:
				add_grave_stones(3, 1, rng); add_grave_stones(4, 2, rng); add_grave_stones(5, 2, rng)
				add_grave_stones(6, 2, rng); add_grave_stones(7, 3, rng); add_grave_stones(8, 3, rng)
	pick_special_grave_stone()
	if stage_has_bushes():
		add_bushes()

func add_bushes() -> void:
	for i in MAX_GRID_SIZE_Y:
		bush_list[i].bush_initialize(i, stage_is_night())

func init_zombie_waves_for_level(for_level: int) -> void:
	if App.is_whack_a_zombie_level() or (App.is_wallnut_bowling_level() and not App.is_first_time_adventure_mode()):
		challenge.init_zombie_waves()
		return
	for zt in range(PvZ.ZOMBIE_NORMAL, PvZ.NUM_ZOMBIE_TYPES):
		zombie_allowed[zt] = can_zombie_spawn_on_level(zt, for_level)

func init_zombie_waves() -> void:
	zombie_allowed.fill(false)
	if App.is_adventure_mode():
		init_zombie_waves_for_level(level)
	else:
		challenge.init_zombie_waves()
	pick_zombie_waves()
	current_wave = 0
	total_spawned_waves = 0
	App.saw_yeti = false
	if App.is_first_time_adventure_mode() and level == 2:
		zombie_count_down = PvZ.ZOMBIE_COUNTDOWN * 2
	else:
		zombie_count_down = PvZ.ZOMBIE_COUNTDOWN_FIRST_WAVE
	zombie_health_wave_start = 0
	last_bungee_wave = 0
	progress_meter_width = 0
	huge_wave_count_down = 0
	level_award_spawned = false
	zombie_count_down_start = zombie_count_down
	zombie_health_to_next_wave = -1

func freeze_effects_for_cutscene(freeze: bool) -> void:
	for r in EffectSystem.reanimations:
		if not r.freed and r.reanim_type == PvZ.REANIM_SLEEPING:
			r.anim_rate = 0.0 if freeze else Tod.rand_range_float(6, 8)

## Re-places the parts of the lawn HUD that hug the screen edges. Called when the mobile view
## changes how much of the widescreen margin is on screen (a rotation, or a resized browser tab).
func relayout_hud() -> void:
	var button_offset_x := PvZ.BOARD_ADDITIONAL_WIDTH * 2 - App.board_view_crop
	if fast_button:
		fast_button.x = 740 + button_offset_x
	if menu_button:
		if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN or App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
			menu_button.x = 628 + button_offset_x
		else:
			menu_button.x = 681 + button_offset_x
	if store_button:
		store_button.x = 678 + button_offset_x

func get_shovel_button_rect() -> Rect2i:
	var r := Rect2i(get_seed_bank_extra_width() + 456, 0, Res.get_image("IMAGE_SHOVELBANK").width, Res.get_image("IMAGE_SEEDBANK").height)
	return r

func get_zen_button_rect(object_type: int, r: Rect2i) -> Rect2i:
	r.position.x = 30
	var usable := true
	for obj in range(PvZ.OBJECT_TYPE_WATERING_CAN, PvZ.OBJECT_TYPE_NEXT_GARDEN + 1):
		if not can_use_game_object(obj):
			usable = false
	if usable:
		r.position.x = 0
	for obj in range(PvZ.OBJECT_TYPE_WATERING_CAN, object_type):
		if can_use_game_object(obj):
			r.position.x += 70
	return r

func init_level() -> void:
	main_counter = 0
	enable_grave_stones = false
	sod_position = 0
	prev_board_result = App.board_result
	if App.playing_quickplay:
		level = App.quick_level
	else:
		level = App.player_info.level if App.is_adventure_mode() else 0
	if App.is_whack_a_zombie_level():
		var hammer := App.add_reanimation(-25.0, 16.0, 0, PvZ.REANIM_HAMMER)
		hammer.is_attachment = true
		hammer.play_reanim("anim_whack_zombie", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 24.0)
		hammer.anim_time = 1.0
		cursor_object.reanim_cursor = hammer
	var gm := App.game_mode
	if gm != PvZ.GAMEMODE_TREE_OF_WISDOM and gm != PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
		App.music.stop_all_music()
	pick_background()
	init_zombie_waves()
	var custom := custom_level()
	if custom != null:
		custom.init_level(self)   # waves, grid, starting sun and the wave countdown
	elif App.is_scary_potter_level() or App.is_whack_a_zombie_level():
		sun_money = 0
	elif App.is_first_time_adventure_mode() and level == 1:
		sun_money = 150
	else:
		sun_money = 50
	for r in MAX_GRID_SIZE_Y:
		wave_row_got_lawn_mowered[r] = -100
		ice_min_x[r] = PvZ.BOARD_ICE_START
		ice_timer[r] = 0
		ice_particle[r] = null
		row_picking_array[r] = {"item": r, "weight": 0.0, "last": 0.0, "second_last": 0.0}
	num_suns_fallen = 0
	if custom != null:
		sun_count_down = custom.level.sun_drop_first if custom.level.sun_drop else 0
	elif not stage_is_night():
		sun_count_down = Tod.rand_range_int(425, 700)
	help_displayed.fill(false)
	seed_bank.num_packets = get_num_seeds_in_bank()
	seed_bank.update_width()
	for i in PvZ.SEEDBANK_MAX:
		var p: SeedPacket = seed_bank.seed_packets[i]
		p.index = i
		p.x = get_seed_packet_position_x(i)
		p.y = 8
		p.packet_type = PvZ.SEED_NONE
	if custom != null:
		custom.setup_seed_bank(self)
	elif App.is_scary_potter_level():
		seed_bank.seed_packets[0].set_packet_type(PvZ.SEED_CHERRYBOMB)
	elif App.is_whack_a_zombie_level():
		seed_bank.seed_packets[0].set_packet_type(PvZ.SEED_POTATOMINE)
		seed_bank.seed_packets[1].set_packet_type(PvZ.SEED_GRAVEBUSTER)
		seed_bank.seed_packets[2].set_packet_type(PvZ.SEED_CHERRYBOMB if App.is_adventure_mode() else PvZ.SEED_ICESHROOM)
	elif not choose_seeds_on_current_level() and not has_conveyor_belt_seed_bank():
		seed_bank.num_packets = get_num_seeds_in_bank()
		for i in seed_bank.num_packets:
			seed_bank.seed_packets[i].set_packet_type(i)
	paused = false
	out_of_money_counter = 0
	if stage_has_fog():
		fog_blown_count_down = 200
		fog_offset = 1065 - left_fog_column() * 70
	challenge.init_level()

func create_rake_reanim(rake_x: float, rake_y: float, order: int) -> Reanimation:
	var r := App.add_reanimation(grid_to_pixel_x(int(rake_x), int(rake_y)) + 20, grid_to_pixel_y(int(rake_x), int(rake_y)), order, PvZ.REANIM_RAKE)
	r.anim_rate = 0
	r.loop_type = Reanimation.REANIM_PLAY_ONCE_AND_HOLD
	r.is_attachment = true
	return r

func place_rake() -> void:
	if App.player_info.purchases[PvZ.STORE_ITEM_RAKE] == 0:
		return
	var gx := 7
	if App.is_scary_potter_level():
		for gi in grid_items:
			if not gi.dead and gi.grid_item_type == PvZ.GRIDITEM_SCARY_POT and gi.grid_x <= gx and gi.grid_x > 0:
				gx = gi.grid_x - 1
	elif not stage_has_zombie_walk_in_from_right():
		return
	var picks: Array = []
	for r in MAX_GRID_SIZE_Y:
		if r != 5 and plant_row[r] == PvZ.PLANTROW_NORMAL:
			picks.append([r, 1])
	if picks.is_empty():
		return
	var gy: int = Tod.pick_from_weighted_array(picks)
	App.player_info.purchases[PvZ.STORE_ITEM_RAKE] -= 1
	var rake := alloc_grid_item()
	rake.grid_item_type = PvZ.GRIDITEM_RAKE
	rake.grid_x = gx
	rake.grid_y = gy
	rake.pos_x = grid_to_pixel_x(gx, gy)
	rake.pos_y = grid_to_pixel_y(gx, gy)
	rake.render_order = make_render_order(PvZ.RENDER_LAYER_GRAVE_STONE, gy, 9)
	rake.grid_item_reanim = create_rake_reanim(gx, gy, 0)
	rake.grid_item_state = PvZ.GRIDITEM_STATE_RAKE_ATTRACTING

func init_lawn_mowers() -> void:
	var cl := custom_level()
	if cl != null:
		for r in MAX_GRID_SIZE_Y:
			if cl.level.mower_type_for_row(r) < 0 or not cl.row_playable(r):
				continue
			var cm := LawnMower.new()
			lawn_mowers.append(cm)
			cm.lawn_mower_initialize(r)
			cm.mower_type = cl.level.mower_type_for_row(r)
			cm.visible = false
		return
	var gm := App.game_mode
	if gm == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN or gm == PvZ.GAMEMODE_TREE_OF_WISDOM \
			or (stage_has_roof() and App.player_info.purchases[PvZ.STORE_ITEM_ROOF_CLEANER] == 0):
		return
	for r in MAX_GRID_SIZE_Y:
		if (not App.is_scary_potter_level() or (App.is_adventure_mode() and level == 35)) and plant_row[r] != PvZ.PLANTROW_DIRT:
			var m := LawnMower.new()
			lawn_mowers.append(m)
			m.lawn_mower_initialize(r)
			m.visible = false

func choose_seeds_on_current_level() -> bool:
	var cl := custom_level()
	if cl != null:
		return cl.uses_chooser()
	if is_net_game():
		return false  # online loadouts are picked in the lobby
	if App.is_challenge_without_seed_bank() or has_conveyor_belt_seed_bank():
		return false
	return not App.is_first_time_adventure_mode() or level > 7

func start_level() -> void:
	coin_bank_fade_count = 0
	App.last_level_stats_unused_lawn_mowers = 0
	challenge.start_level()
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN or App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM \
			or App.game_mode == PvZ.GAMEMODE_UPSELL or App.game_mode == PvZ.GAMEMODE_INTRO or App.is_final_boss_level():
		return
	App.music.start_game_music()

func get_bottom_lawn_mower() -> LawnMower:
	var bottom: LawnMower = null
	for m in lawn_mowers:
		if m.dead or m.mower_state == PvZ.MOWER_TRIGGERED or m.mower_state == PvZ.MOWER_SQUISHED:
			continue
		if bottom == null or bottom.row < m.row:
			bottom = m
	return bottom

func update_level_end_sequence() -> void:
	if next_survival_stage_counter > 0:
		if not is_scary_potter_dave_talking():
			next_survival_stage_counter -= 1
			if App.is_adventure_mode() and App.is_scary_potter_level() and next_survival_stage_counter == 300:
				App.crazy_dave_enter()
				App.crazy_dave_talk_index(2700 if challenge.survival_stage == 0 else 2800)
				challenge.puzzle_next_stage_clear()
				next_survival_stage_counter = 100
		if next_survival_stage_counter == 0:
			if App.is_scary_potter_level():
				if App.is_adventure_mode():
					return
			else:
				level_complete = true
				remove_zombies_for_repick()
			return
	if board_fade_out_counter < 0:
		return
	board_fade_out_counter -= 1
	if board_fade_out_counter == 0:
		if App.playing_quickplay and level != 50:
			var d := App.do_dialog(PvZ.DIALOG_MESSAGE, true, "[QUICK_PLAY_HEADER]", "[QUICK_PLAY]", "", Dialog.BUTTONS_YES_NO)
			if await d.wait_for_result(true) == Dialog.ID_YES:
				App.quick_level += 1
				App.start_quick_play()
		level_complete = true
		return
	if board_fade_out_counter == 300:
		if not (level == 9 or level == 19 or level == 29 or level == 39 or level == 49):
			App.play_sample("SOUND_LIGHTFILL")
	if score_next_mower_counter > 0:
		score_next_mower_counter -= 1
		if score_next_mower_counter != 0:
			return
	if can_drop_loot() and not is_survival_stage_with_repick() and not App.playing_quickplay:
		score_next_mower_counter = 40
		var m := get_bottom_lawn_mower()
		if m != null:
			add_coin(int(m.pos_x) + 40, int(m.pos_y) + 40, PvZ.COIN_GOLD, PvZ.COIN_MOTION_LAWNMOWER_COIN)
			App.play_sample_pitch("SOUND_POINTS", clampf(6 - count_untrigger_lawn_mowers(), 0.0, 6.0))
			m.die()

func complete_end_level_sequence_for_saving() -> void:
	if can_drop_loot():
		for m in lawn_mowers:
			if not m.dead and m.mower_state != PvZ.MOWER_TRIGGERED and m.mower_state != PvZ.MOWER_SQUISHED:
				var v := Coin.get_coin_value(PvZ.COIN_GOLD)
				App.player_info.add_coins(v)
				coins_collected += v
	for c in coins:
		if c.dead:
			continue
		if c.is_being_collected:
			c.score_coin()
		else:
			c.die()
	App.update_player_profile_for_finishing_level()

func fade_out_level() -> void:
	if App.game_scene != PvZ.SCENE_PLAYING:
		refresh_seed_packet_from_cursor()
		App.last_level_stats_unused_lawn_mowers = 0
		level_complete = true
	var need_sound := true
	if App.is_scary_potter_level() and not is_final_scary_potter_stage():
		need_sound = false
	if need_sound:
		App.music.stop_all_music()
		if App.is_adventure_mode() and level == 50:
			App.play_foley(PvZ.FOLEY_FINAL_FANFARE)
		else:
			App.play_foley(PvZ.FOLEY_WINMUSIC)
	if App.is_scary_potter_level() and not is_final_scary_potter_stage():
		next_survival_stage_counter = 500
		clear_advice(PvZ.ADVICE_NONE)
		return
	refresh_seed_packet_from_cursor()
	App.last_level_stats_unused_lawn_mowers = count_untrigger_lawn_mowers()
	board_fade_out_counter = 600
	if level == 9 or level == 19 or level == 29 or level == 39 or level == 49:
		board_fade_out_counter = 500
	if can_drop_loot():
		score_next_mower_counter = 200
	for c in coins:
		if not c.dead:
			c.try_auto_collect_after_level_award()
	App.is_fast_mode = false
	App.set_cursor(App.CURSOR_POINTER)

# ================================================================ advice
func display_advice(text: String, style: int, the_help_index: int) -> void:
	if not net_exec_is_local():
		return  # hints caused by another player's click only show on their screen
	if the_help_index != PvZ.ADVICE_NONE:
		if help_displayed[the_help_index]:
			return
		help_displayed[the_help_index] = true
	advice.set_label(text, style)
	help_index = the_help_index

func display_advice_again(text: String, style: int, the_help_index: int) -> void:
	if the_help_index != PvZ.ADVICE_NONE:
		help_displayed[the_help_index] = false
	display_advice(text, style, the_help_index)

func clear_advice_immediately() -> void:
	clear_advice(PvZ.ADVICE_NONE)
	advice.duration = 0

func clear_advice(the_help_index: int) -> void:
	if the_help_index == PvZ.ADVICE_NONE or the_help_index == help_index:
		advice.clear_label()
		help_index = PvZ.ADVICE_NONE

# ================================================================ object creation
func add_coin(px: int, py: int, coin_type: int, motion: int) -> Coin:
	var c := Coin.new()
	coins.append(c)
	c.coin_initialize(px, py, coin_type, motion)
	if App.is_first_time_adventure_mode() and level == 1:
		display_advice("[ADVICE_CLICK_ON_SUN]", PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL1_STAY, PvZ.ADVICE_CLICK_ON_SUN)
	return c

func is_plant_in_cursor() -> bool:
	var t := cursor_object.cursor_type
	return t == PvZ.CURSOR_TYPE_PLANT_FROM_BANK or t == PvZ.CURSOR_TYPE_PLANT_FROM_USABLE_COIN or t == PvZ.CURSOR_TYPE_PLANT_FROM_GLOVE \
		or t == PvZ.CURSOR_TYPE_PLANT_FROM_DUPLICATOR or t == PvZ.CURSOR_TYPE_PLANT_FROM_WHEEL_BARROW

func get_seed_type_in_cursor() -> int:
	if cursor_object.cursor_type == PvZ.CURSOR_TYPE_WHEEELBARROW:
		var pp = App.zen_garden.get_potted_plant_in_wheelbarrow()
		if pp != null:
			return pp.seed_type
	if not is_plant_in_cursor():
		return PvZ.SEED_NONE
	return cursor_object.imitater_type if cursor_object.type == PvZ.SEED_IMITATER else cursor_object.type

func refresh_seed_packet_from_cursor() -> void:
	if cursor_object.cursor_type == PvZ.CURSOR_TYPE_PLANT_FROM_USABLE_COIN:
		if cursor_object.coin != null and not cursor_object.coin.dead:
			cursor_object.coin.dropped_usable_seed()
	elif cursor_object.cursor_type == PvZ.CURSOR_TYPE_PLANT_FROM_BANK:
		seed_bank.seed_packets[cursor_object.seed_bank_index].activate()
	clear_cursor()

func is_pool_square(gx: int, gy: int) -> bool:
	if gx >= 0 and gy >= 0 and gx < MAX_GRID_SIZE_X and gy < MAX_GRID_SIZE_Y:
		return grid_square_type[gx][gy] == PvZ.GRIDSQUARE_POOL
	return false

func new_plant(gx: int, gy: int, seed_type: int, imitater_type: int = PvZ.SEED_NONE) -> Plant:
	var p := Plant.create(seed_type)
	plants.append(p)
	p.is_on_board = true
	p.plant_initialize(gx, gy, seed_type, imitater_type)
	return p

func do_planting_effects(gx: int, gy: int, plant: Plant) -> void:
	if CustomRuntime.active != null:
		CustomRuntime.active.notify_plant_placed(plant)
	var xp := grid_to_pixel_x(gx, gy) + 41
	var yp := grid_to_pixel_y(gx, gy) + 74
	if plant:
		if plant.seed_type == PvZ.SEED_LILYPAD:
			yp += 15
		elif plant.seed_type == PvZ.SEED_FLOWERPOT:
			yp += 30
	if background == PvZ.BACKGROUND_GREENHOUSE:
		App.play_foley(PvZ.FOLEY_CERAMIC)
		return
	if background == PvZ.BACKGROUND_ZOMBIQUARIUM:
		App.play_foley(PvZ.FOLEY_PLANT_WATER)
		return
	if Plant.is_flying(plant.seed_type):
		App.play_foley(PvZ.FOLEY_PLANT)
		return
	if is_pool_square(gx, gy):
		App.play_foley(PvZ.FOLEY_PLANT_WATER)
		App.add_tod_particle(xp, yp, PvZ.RENDER_LAYER_TOP, PvZ.PARTICLE_PLANTING_POOL)
	else:
		App.play_foley(PvZ.FOLEY_PLANT)
		App.add_tod_particle(xp, yp, PvZ.RENDER_LAYER_TOP, PvZ.PARTICLE_PLANTING)

func add_plant(gx: int, gy: int, seed_type: int, imitater_type: int = PvZ.SEED_NONE) -> Plant:
	var p := new_plant(gx, gy, seed_type, imitater_type)
	do_planting_effects(gx, gy, p)
	challenge.plant_added(p)
	var sun_plants := count_plant_by_type(PvZ.SEED_SUNSHROOM) + count_plant_by_type(PvZ.SEED_SUNFLOWER)
	if sun_plants > max_sun_plants:
		max_sun_plants = sun_plants
	if seed_type in [PvZ.SEED_PEASHOOTER, PvZ.SEED_SNOWPEA, PvZ.SEED_REPEATER, PvZ.SEED_THREEPEATER, PvZ.SEED_SPLITPEA, PvZ.SEED_GATLINGPEA]:
		peashooters_used = true
	if seed_type in [PvZ.SEED_CABBAGEPULT, PvZ.SEED_KERNELPULT, PvZ.SEED_MELONPULT, PvZ.SEED_WINTERMELON]:
		catapults_used = true
	var fungi := Plant.is_nocturnal(seed_type)
	if Plant.is_flying(seed_type) and lawn_has_nocturnal():
		mushrooms_n_coffee_used = true
	if fungi:
		mushrooms_used = true
	if not fungi and seed_type != PvZ.SEED_INSTANT_COFFEE:
		used_non_mushrooms = true
	return p

func get_pumpkin_at(gx: int, gy: int) -> Plant:
	for p in plants:
		if not p.dead and p.plant_col == gx and p.row == gy and not p.not_on_ground() and p.seed_type == PvZ.SEED_PUMPKINSHELL:
			return p
	return null

func get_flower_pot_at(gx: int, gy: int) -> Plant:
	for p in plants:
		if not p.dead and p.plant_col == gx and p.row == gy and not p.not_on_ground() and p.seed_type == PvZ.SEED_FLOWERPOT:
			return p
	return null

func lawn_has_nocturnal() -> bool:
	for p in plants:
		if not p.dead and Plant.is_nocturnal(p.seed_type):
			return true
	return false

func get_plants_on_lawn(gx: int, gy: int) -> PlantsOnLawn:
	var r := PlantsOnLawn.new()
	if gx < 0 or gx >= MAX_GRID_SIZE_X or gy < 0 or gy >= MAX_GRID_SIZE_Y:
		return r
	if App.is_wallnut_bowling_level() and not cut_scene.is_in_shovel_tutorial():
		return r
	for p in plants:
		if p.dead:
			continue
		var st: int = p.seed_type
		if st == PvZ.SEED_IMITATER and p.imitater_type != PvZ.SEED_NONE:
			st = p.imitater_type
		if p.row != gy:
			continue
		if st == PvZ.SEED_COBCANNON:
			if p.plant_col < gx - 1 or p.plant_col > gx:
				continue
		elif p.plant_col != gx:
			continue
		if p.not_on_ground():
			continue
		if Plant.is_flying(p.seed_type):
			r.flying_plant = p
		elif st == PvZ.SEED_FLOWERPOT or (st == PvZ.SEED_LILYPAD and App.game_mode != PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN):
			r.under_plant = p
		elif st == PvZ.SEED_PUMPKINSHELL:
			r.pumpkin_plant = p
		else:
			r.normal_plant = p
	return r

func get_top_plant_at(gx: int, gy: int, priority: int) -> Plant:
	if gx < 0 or gx >= MAX_GRID_SIZE_X or gy < 0 or gy >= MAX_GRID_SIZE_Y:
		return null
	if App.is_wallnut_bowling_level() and not cut_scene.is_in_shovel_tutorial():
		return null
	var l := get_plants_on_lawn(gx, gy)
	match priority:
		PvZ.TOPPLANT_EATING_ORDER:
			if l.pumpkin_plant: return l.pumpkin_plant
			if l.normal_plant: return l.normal_plant
			return l.under_plant
		PvZ.TOPPLANT_DIGGING_ORDER:
			if l.normal_plant: return l.normal_plant
			return l.under_plant
		PvZ.TOPPLANT_BUNGEE_ORDER, PvZ.TOPPLANT_CATAPULT_ORDER, PvZ.TOPPLANT_ANY:
			if l.flying_plant: return l.flying_plant
			if l.normal_plant: return l.normal_plant
			if l.pumpkin_plant: return l.pumpkin_plant
			return l.under_plant
		PvZ.TOPPLANT_ZEN_TOOL_ORDER:
			if l.flying_plant: return l.flying_plant
			if l.pumpkin_plant: return l.pumpkin_plant
			if l.normal_plant: return l.normal_plant
			return l.under_plant
		PvZ.TOPPLANT_ONLY_NORMAL_POSITION: return l.normal_plant
		PvZ.TOPPLANT_ONLY_FLYING: return l.flying_plant
		PvZ.TOPPLANT_ONLY_PUMPKIN: return l.pumpkin_plant
		PvZ.TOPPLANT_ONLY_UNDER_PLANT: return l.under_plant
	return null

func count_sun_flowers() -> int:
	var c := 0
	for p in plants:
		if not p.dead and p.makes_sun():
			c += 1
	return c

func count_plant_by_type(seed_type: int) -> int:
	var c := 0
	for p in plants:
		if not p.dead and p.seed_type == seed_type:
			c += 1
	return c

func count_empty_pots_or_lilies(seed_type: int) -> int:
	var c := 0
	for p in plants:
		if not p.dead and p.seed_type == seed_type and get_top_plant_at(p.plant_col, p.row, PvZ.TOPPLANT_ONLY_NORMAL_POSITION) == null:
			c += 1
	return c

func is_valid_cob_cannon_spot_helper(gx: int, gy: int) -> bool:
	var l := get_plants_on_lawn(gx, gy)
	if l.pumpkin_plant:
		return false
	if l.normal_plant and l.normal_plant.seed_type == PvZ.SEED_KERNELPULT:
		return true
	return App.easy_planting_cheat and can_plant_at(gx, gy, PvZ.SEED_KERNELPULT) == PvZ.PLANTING_OK

func is_valid_cob_cannon_spot(gx: int, gy: int) -> bool:
	if not is_valid_cob_cannon_spot_helper(gx, gy) or not is_valid_cob_cannon_spot_helper(gx + 1, gy):
		return false
	return (get_flower_pot_at(gx, gy) == null) == (get_flower_pot_at(gx + 1, gy) == null)

func has_valid_cob_cannon_spot() -> bool:
	for p in plants:
		if not p.dead and p.seed_type == PvZ.SEED_KERNELPULT and is_valid_cob_cannon_spot(p.plant_col, p.row):
			return true
	return false

func add_projectile(px: int, py: int, order: int, the_row: int, projectile_type: int) -> Projectile:
	var p := Projectile.new()
	projectiles.append(p)
	p.projectile_initialize(px, py, order, the_row, projectile_type)
	return p

# ================================================================ zombie picking
static func can_zombie_spawn_on_level(zombie_type: int, for_level: int) -> bool:
	var zd := LawnCommon.zombie_def(zombie_type)
	if zombie_type == PvZ.ZOMBIE_YETI:
		return App.can_spawn_yetis()
	if for_level < zd[LawnCommon.ZDEF_STARTING_LEVEL] or zd[LawnCommon.ZDEF_PICK_WEIGHT] == 0:
		return false
	return LawnDefs.ZOMBIE_ALLOWED_LEVELS[zombie_type][clampi(for_level - 1, 0, PvZ.NUM_LEVELS - 1)] != 0

func get_introduced_zombie_type() -> int:
	if not App.is_adventure_mode() or level == 1:
		return PvZ.ZOMBIE_INVALID
	for zt in range(PvZ.ZOMBIE_NORMAL, PvZ.NUM_ZOMBIE_TYPES):
		var zd := LawnCommon.zombie_def(zt)
		if (zt != PvZ.ZOMBIE_YETI or App.can_spawn_yetis()) and zd[LawnCommon.ZDEF_STARTING_LEVEL] == level:
			return zt
	return PvZ.ZOMBIE_INVALID

func pick_grave_rising_zombie_type(_zombie_points: int) -> int:
	var arr: Array = [[PvZ.ZOMBIE_NORMAL, LawnCommon.zombie_def(PvZ.ZOMBIE_NORMAL)[LawnCommon.ZDEF_PICK_WEIGHT]],
		[PvZ.ZOMBIE_TRAFFIC_CONE, LawnCommon.zombie_def(PvZ.ZOMBIE_TRAFFIC_CONE)[LawnCommon.ZDEF_PICK_WEIGHT]]]
	if not stage_has_grave_stones():
		arr.append([PvZ.ZOMBIE_PAIL, LawnCommon.zombie_def(PvZ.ZOMBIE_PAIL)[LawnCommon.ZDEF_PICK_WEIGHT]])
	for e in arr:
		var zt: int = e[0]
		var zd := LawnCommon.zombie_def(zt)
		if (App.is_first_time_adventure_mode() and level < zd[LawnCommon.ZDEF_STARTING_LEVEL]) or (not zombie_allowed[zt] and zt != PvZ.ZOMBIE_NORMAL):
			e[1] = 0
	return Tod.pick_from_weighted_array(arr)

func pick_zombie_type(zombie_points: int, wave: int, _picker: ZombiePicker) -> int:
	var arr: Array = []
	for zt in range(PvZ.ZOMBIE_NORMAL, PvZ.NUM_ZOMBIE_TYPES):
		if not zombie_allowed[zt]:
			continue
		var zd := LawnCommon.zombie_def(zt)
		if wave + 1 < zd[LawnCommon.ZDEF_FIRST_ALLOWED_WAVE] or zombie_points < zd[LawnCommon.ZDEF_VALUE]:
			continue
		arr.append([zt, zd[LawnCommon.ZDEF_PICK_WEIGHT]])
	return Tod.pick_from_weighted_array(arr)

static func is_zombie_type_pool_only(zombie_type: int) -> bool:
	return zombie_type == PvZ.ZOMBIE_SNORKEL or zombie_type == PvZ.ZOMBIE_DOLPHIN_RIDER

func row_can_have_zombie_type(the_row: int, zombie_type: int) -> bool:
	if not row_can_have_zombies(the_row):
		return false
	if plant_row[the_row] == PvZ.PLANTROW_POOL and not Zombie.zombie_type_can_go_in_pool(zombie_type):
		return false
	if plant_row[the_row] == PvZ.PLANTROW_HIGH_GROUND and not Zombie.zombie_type_can_go_on_high_ground(zombie_type):
		return false
	if plant_row[the_row] == PvZ.PLANTROW_POOL:
		if current_wave < 5 and not is_zombie_type_pool_only(zombie_type):
			return false
	elif is_zombie_type_pool_only(zombie_type):
		return false
	if zombie_type == PvZ.ZOMBIE_BOBSLED and ice_timer[the_row] == 0:
		return false
	if the_row == 0:
		if zombie_type == PvZ.ZOMBIE_GARGANTUAR or zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR:
			return false
	if zombie_type != PvZ.ZOMBIE_DANCER or stage_has_pool():
		return true
	return row_can_have_zombies(the_row - 1) and row_can_have_zombies(the_row + 1)

func pick_row_for_new_zombie(zombie_type: int) -> int:
	var rake := get_rake()
	if rake != null and rake.grid_item_state == PvZ.GRIDITEM_STATE_RAKE_ATTRACTING and row_can_have_zombie_type(rake.grid_y, zombie_type):
		rake.grid_item_state = PvZ.GRIDITEM_STATE_RAKE_WAITING
		Tod.update_smooth_array_pick(row_picking_array, rake.grid_y)
		return rake.grid_y
	var any := false
	for r in MAX_GRID_SIZE_Y:
		var e: Dictionary = row_picking_array[r]
		if not row_can_have_zombie_type(r, zombie_type):
			e.weight = 0.0
		else:
			any = true
			var waves_mowered: int = current_wave - wave_row_got_lawn_mowered[r]
			if App.is_continuous_challenge() and current_wave == num_waves - 1:
				waves_mowered = 100
			if waves_mowered <= 1:
				e.weight = 0.01
			elif waves_mowered <= 2:
				e.weight = 0.5
			else:
				e.weight = 1.0
	if not any:
		# The stock levels always leave this zombie somewhere to go, but a custom level can ask for
		# one that fits nowhere (a land zombie on an all-water lawn). Weighting every row at zero
		# makes the smooth pick divide by zero and land on the last row - a lane the player may not
		# even have - so relax the per-type rules first, and refuse the spawn if that still fails.
		return pick_any_row_for_zombie()
	return Tod.pick_from_smooth_array(row_picking_array)

## Any row that takes zombies at all, ignoring what the type would normally allow. -1 if the lawn
## has no such row.
func pick_any_row_for_zombie() -> int:
	var rows: Array[int] = []
	for r in MAX_GRID_SIZE_Y:
		if row_can_have_zombies(r):
			rows.append(r)
	if rows.is_empty():
		return -1
	var pick: int = rows[Tod.rand_int(rows.size())]
	Tod.update_smooth_array_pick(row_picking_array, pick)
	return pick

func can_add_bob_sled() -> bool:
	for r in MAX_GRID_SIZE_Y:
		if ice_timer[r] > 0 and ice_min_x[r] < 700 + PvZ.BOARD_ADDITIONAL_WIDTH:
			return true
	return false

func alloc_zombie() -> Zombie:
	var z := Zombie.new()
	zombies.append(z)
	Zombie.mind_control_version += 1
	return z

func add_zombie_in_row(zombie_type: int, the_row: int, from_wave: int, skip_bush_animation: bool = false) -> Zombie:
	if zombies.size() >= 1023:
		return null
	if the_row < 0 or the_row >= MAX_GRID_SIZE_Y:
		return null
	if zombie_type == PvZ.ZOMBIE_YETI and not App.playing_quickplay:
		App.get_achievement(PvZ.ACHIEVEMENT_ZOMBOLOGIST)
	var variant := Tod.rand_int(5) == 0
	var z := alloc_zombie()
	z.zombie_initialize(the_row, zombie_type, variant, null, from_wave, not skip_bush_animation and stage_has_bushes() and App.game_scene == PvZ.SCENE_PLAYING)
	if zombie_type == PvZ.ZOMBIE_BOBSLED and z.is_on_board():
		for i in 3:
			alloc_zombie().zombie_initialize(the_row, PvZ.ZOMBIE_BOBSLED, false, z, from_wave)
	return z

func add_zombie(zombie_type: int, from_wave: int, skip_bush_animation: bool = false) -> Zombie:
	return add_zombie_in_row(zombie_type, pick_row_for_new_zombie(zombie_type), from_wave, skip_bush_animation)

func animate_bush(the_row: int) -> void:
	if the_row < 0 or the_row >= bush_list.size():
		return
	var b: Bush = bush_list[the_row]
	if b == null or not stage_has_bushes():
		return
	b.animate_bush()
	if not stage_has_6_rows() and the_row == 4:
		(bush_list[the_row + 1] as Bush).animate_bush()

func remove_all_zombies() -> void:
	for z in zombies.duplicate():
		if not z.dead and not z.is_dead_or_dying():
			z.die_no_loot()

func remove_zombies_for_repick() -> void:
	for z in zombies.duplicate():
		if not z.dead and not z.is_dead_or_dying() and z.mind_controlled and z.pos_x > PvZ.BOARD_WIDTH - 80:
			z.die_no_loot()

func remove_cutscene_zombies() -> void:
	for z in zombies.duplicate():
		if not z.dead and z.from_wave == Zombie.ZOMBIE_WAVE_CUTSCENE:
			z.die_no_loot()

func is_ice_at(gx: int, gy: int) -> bool:
	if ice_timer[gy] == 0 or ice_min_x[gy] > 750 + PvZ.BOARD_ADDITIONAL_WIDTH:
		return false
	return gx >= pixel_to_grid_x_keep_on_board(ice_min_x[gy] + 12, 0)

func can_plant_at(gx: int, gy: int, seed_type: int) -> int:
	if gx < 0 or gx >= MAX_GRID_SIZE_X or gy < 0 or gy >= MAX_GRID_SIZE_Y:
		return PvZ.PLANTING_NOT_HERE
	# A custom plant is placed by the rules of the plant it behaves like.
	if CustomDefs.is_custom_plant(seed_type):
		seed_type = CustomDefs.plant_base(seed_type)
	if is_versus():
		var vs_reason := NetVersus.plant_restriction(self, gx, gy, seed_type)
		if vs_reason != PvZ.PLANTING_OK or NetVersus.is_zombie_side_seed(seed_type):
			return vs_reason
	var reason := challenge.can_plant_at(gx, gy, seed_type)
	if reason != PvZ.PLANTING_OK:
		return reason
	var l := get_plants_on_lawn(gx, gy)
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
		if l.under_plant or l.pumpkin_plant or l.flying_plant or l.normal_plant:
			return PvZ.PLANTING_NOT_HERE
		if App.zen_garden.garden_type == PvZ.GARDEN_AQUARIUM and not Plant.is_aquatic(seed_type):
			return PvZ.PLANTING_NOT_ON_WATER
		return PvZ.PLANTING_OK
	var has_grave := get_grave_stone_at(gx, gy) != null
	if seed_type == PvZ.SEED_GRAVEBUSTER:
		if l.normal_plant:
			return PvZ.PLANTING_NOT_HERE
		return PvZ.PLANTING_OK if has_grave else PvZ.PLANTING_ONLY_ON_GRAVES
	if seed_type == PvZ.SEED_INSTANT_COFFEE:
		if l.flying_plant:
			return PvZ.PLANTING_NOT_HERE
		if l.normal_plant == null or not l.normal_plant.is_asleep or l.normal_plant.wake_up_counter > 0 \
				or l.normal_plant.on_bungee_state == PvZ.GETTING_GRABBED_BY_BUNGEE:
			return PvZ.PLANTING_NEEDS_SLEEPING
		return PvZ.PLANTING_OK
	if has_grave:
		return PvZ.PLANTING_OK if Plant.is_flying(seed_type) else PvZ.PLANTING_NOT_ON_GRAVE
	var under := l.under_plant
	var has_lilypad := false
	var has_flower_pot := false
	if under != null and under.on_bungee_state != PvZ.GETTING_GRABBED_BY_BUNGEE:
		has_lilypad = under.seed_type == PvZ.SEED_LILYPAD
		has_flower_pot = under.seed_type == PvZ.SEED_FLOWERPOT
	if get_crater_at(gx, gy):
		return PvZ.PLANTING_NOT_ON_CRATER
	if get_scary_pot_at(gx, gy) or is_ice_at(gx, gy):
		return PvZ.PLANTING_NOT_HERE
	var sq: int = grid_square_type[gx][gy]
	if sq == PvZ.GRIDSQUARE_DIRT or sq == PvZ.GRIDSQUARE_NONE:
		return PvZ.PLANTING_NOT_HERE
	var normal := l.normal_plant
	if seed_type == PvZ.SEED_LILYPAD or seed_type == PvZ.SEED_TANGLEKELP or seed_type == PvZ.SEED_SEASHROOM:
		if not is_pool_square(gx, gy):
			return PvZ.PLANTING_ONLY_IN_POOL
		return PvZ.PLANTING_NOT_HERE if (normal or under) else PvZ.PLANTING_OK
	if Plant.is_flying(seed_type):
		return PvZ.PLANTING_NOT_HERE if l.flying_plant else PvZ.PLANTING_OK
	if seed_type == PvZ.SEED_SPIKEWEED or seed_type == PvZ.SEED_SPIKEROCK:
		if sq == PvZ.GRIDSQUARE_POOL or stage_has_roof() or under:
			return PvZ.PLANTING_NEEDS_GROUND
	var pumpkin := l.pumpkin_plant
	if sq == PvZ.GRIDSQUARE_POOL and not has_lilypad and seed_type != PvZ.SEED_CATTAIL:
		if normal == null or normal.seed_type != PvZ.SEED_CATTAIL or seed_type != PvZ.SEED_PUMPKINSHELL:
			return PvZ.PLANTING_NOT_ON_WATER
	if seed_type == PvZ.SEED_FLOWERPOT:
		return PvZ.PLANTING_NOT_HERE if (normal or under or pumpkin) else PvZ.PLANTING_OK
	if stage_has_roof() and not has_flower_pot:
		return PvZ.PLANTING_NEEDS_POT
	var aid: bool = App.player_info.purchases[PvZ.STORE_ITEM_FIRSTAID] > 0
	if seed_type == PvZ.SEED_PUMPKINSHELL:
		if normal and normal.seed_type == PvZ.SEED_COBCANNON:
			return PvZ.PLANTING_NOT_HERE
		if pumpkin == null:
			return PvZ.PLANTING_OK
		if aid and pumpkin.plant_health < Tod.idiv(pumpkin.plant_max_health * 2, 3) and pumpkin.seed_type == PvZ.SEED_PUMPKINSHELL \
				and pumpkin.on_bungee_state != PvZ.GETTING_GRABBED_BY_BUNGEE:
			return PvZ.PLANTING_OK
		return PvZ.PLANTING_NOT_HERE
	if has_lilypad and seed_type == PvZ.SEED_POTATOMINE:
		return PvZ.PLANTING_ONLY_ON_GROUND
	if under:
		if seed_type == PvZ.SEED_CATTAIL:
			if normal:
				return PvZ.PLANTING_NOT_HERE
			if under.is_upgradable_to(seed_type) and under.on_bungee_state != PvZ.GETTING_GRABBED_BY_BUNGEE:
				return PvZ.PLANTING_OK
			if Plant.is_upgrade(seed_type):
				return PvZ.PLANTING_NEEDS_UPGRADE
		elif under.seed_type == PvZ.SEED_IMITATER:
			return PvZ.PLANTING_NOT_HERE
	if normal:
		if normal.is_upgradable_to(seed_type) and normal.on_bungee_state != PvZ.GETTING_GRABBED_BY_BUNGEE:
			return PvZ.PLANTING_OK
		if Plant.is_upgrade(seed_type):
			return PvZ.PLANTING_NEEDS_UPGRADE
		if (seed_type == PvZ.SEED_WALLNUT or seed_type == PvZ.SEED_TALLNUT) and aid:
			if normal.plant_health < Tod.idiv(normal.plant_max_health * 2, 3) and normal.seed_type == seed_type \
					and normal.on_bungee_state != PvZ.GETTING_GRABBED_BY_BUNGEE:
				return PvZ.PLANTING_OK
		return PvZ.PLANTING_NOT_HERE
	if not App.easy_planting_cheat and Plant.is_upgrade(seed_type):
		return PvZ.PLANTING_NEEDS_UPGRADE
	if seed_type == PvZ.SEED_COBCANNON and not is_valid_cob_cannon_spot(gx, gy):
		return PvZ.PLANTING_NEEDS_UPGRADE
	elif seed_type == PvZ.SEED_CATTAIL and sq != PvZ.GRIDSQUARE_POOL:
		return PvZ.PLANTING_NOT_HERE
	return PvZ.PLANTING_OK

# ================================================================ sun / money
func add_sun_money(amount: int) -> void:
	sun_money = mini(sun_money + amount, 9990)

func count_sun_being_collected() -> int:
	var c := 0
	for coin in coins:
		if coin.vs_zombie_sun != net_zombie_context:
			continue
		if not coin.dead and coin.is_being_collected and coin.is_sun():
			c += coin.get_sun_value()
	return c

func count_coins_being_collected() -> int:
	var c := 0
	for coin in coins:
		if not coin.dead and coin.is_being_collected and coin.is_money():
			c += Coin.get_coin_value(coin.type)
	return c

func take_sun_money(amount: int) -> bool:
	if can_take_sun_money(amount):
		sun_money -= amount
		return true
	App.play_sample("SOUND_BUZZER")
	out_of_money_counter = 70
	return false

func can_take_sun_money(amount: int) -> bool:
	return amount <= sun_money + count_sun_being_collected()

func process_delete_queue() -> void:
	for arr in [plants, zombies, projectiles, coins, lawn_mowers, grid_items]:
		var i := 0
		while i < arr.size():
			if arr[i].dead:
				arr[i].freed = true
				arr.remove_at(i)
			else:
				i += 1

## Equivalent of DataArrayTryToGet: returns the object while it is still allocated.
static func try_get(obj):
	if obj == null or obj.freed:
		return null
	return obj

# ================================================================ stage queries
func has_conveyor_belt_seed_bank() -> bool:
	var cl := custom_level()
	if cl != null:
		return cl.uses_conveyor()
	return App.is_final_boss_level() or App.is_mini_boss_level() or App.is_shovel_level() or App.is_wallnut_bowling_level() \
		or App.is_little_trouble_level() or App.is_stormy_night_level() or App.is_bungee_blitz_level() \
		or App.game_mode == PvZ.GAMEMODE_CHALLENGE_PORTAL_COMBAT or App.game_mode == PvZ.GAMEMODE_CHALLENGE_COLUMN \
		or App.game_mode == PvZ.GAMEMODE_CHALLENGE_INVISIGHOUL

func get_num_seeds_in_bank() -> int:
	var cl := custom_level()
	if cl != null:
		return cl.num_seeds_in_bank()
	if App.is_scary_potter_level():
		return 1
	if App.is_whack_a_zombie_level():
		return 3
	if App.is_challenge_without_seed_bank():
		return 0
	if has_conveyor_belt_seed_bank():
		return 10
	var n: int = App.player_info.purchases[PvZ.STORE_ITEM_PACKET_UPGRADE] + 6
	return mini(n, App.get_seeds_available())

## The custom level being played, or null. Every stage rule below asks this first, so a custom
## level decides what a lane counts as without the background picture having to agree.
func custom_level() -> CustomRuntime:
	return CustomRuntime.active

func stage_is_night() -> bool:
	var cl := custom_level()
	if cl != null:
		return cl.is_night()
	return background == PvZ.BACKGROUND_2_NIGHT or background == PvZ.BACKGROUND_4_FOG or background == PvZ.BACKGROUND_6_BOSS \
		or background == PvZ.BACKGROUND_MUSHROOM_GARDEN or background == PvZ.BACKGROUND_ZOMBIQUARIUM

func stage_has_grave_stones() -> bool:
	var cl := custom_level()
	if cl != null:
		return cl.has_graves()
	if App.is_wallnut_bowling_level() or App.is_scary_potter_level() or App.is_izombie_level():
		return false
	var gm: int = App.game_mode
	if gm == PvZ.GAMEMODE_CHALLENGE_POGO_PARTY or gm == PvZ.GAMEMODE_CHALLENGE_BEGHOULED or gm == PvZ.GAMEMODE_CHALLENGE_BEGHOULED_TWIST \
			or gm == PvZ.GAMEMODE_CHALLENGE_PORTAL_COMBAT or gm == PvZ.GAMEMODE_CHALLENGE_LAST_STAND:
		return false
	return background == PvZ.BACKGROUND_2_NIGHT

func stage_has_roof() -> bool:
	var cl := custom_level()
	if cl != null:
		return cl.has_roof()
	return background == PvZ.BACKGROUND_5_ROOF or background == PvZ.BACKGROUND_6_BOSS

## True when the lawn has water lanes at all (aquatic plants, pool spawns, dancer rules).
func stage_has_pool() -> bool:
	var cl := custom_level()
	if cl != null:
		for gy in MAX_GRID_SIZE_Y:
			if cl.lane_type(gy) == PvZ.PLANTROW_POOL:
				return true
		return false
	return background == PvZ.BACKGROUND_3_POOL or background == PvZ.BACKGROUND_4_FOG

## Lane metrics only: six 85px rows instead of five 100px rows. Never about what a lane counts as.
func stage_uses_pool_metrics() -> bool:
	var cl := custom_level()
	if cl != null:
		return cl.has_six_rows()
	return background == PvZ.BACKGROUND_3_POOL or background == PvZ.BACKGROUND_4_FOG

## Whether the animated water overlay is painted. A custom background paints its own water, so
## marking a lane as water there stays a pure gameplay rule unless the level asks for the overlay.
func stage_draws_pool_water() -> bool:
	var cl := custom_level()
	if cl != null:
		return cl.has_pool_water()
	return stage_has_pool()

func stage_has_6_rows() -> bool:
	var cl := custom_level()
	if cl != null:
		return cl.has_six_rows()
	return background == PvZ.BACKGROUND_3_POOL or background == PvZ.BACKGROUND_4_FOG

func stage_has_bushes() -> bool:
	var cl := custom_level()
	if cl != null:
		return cl.has_bushes()
	return background == PvZ.BACKGROUND_1_DAY or background == PvZ.BACKGROUND_2_NIGHT \
		or background == PvZ.BACKGROUND_3_POOL or background == PvZ.BACKGROUND_4_FOG

func stage_has_zombie_walk_in_from_right() -> bool:
	var cl := custom_level()
	if cl != null:
		return cl.walks_in_from_right()
	var gm: int = App.game_mode
	if App.is_whack_a_zombie_level() or gm == PvZ.GAMEMODE_CHALLENGE_ICE or gm == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN \
			or gm == PvZ.GAMEMODE_TREE_OF_WISDOM or gm == PvZ.GAMEMODE_CHALLENGE_ZOMBIQUARIUM or App.is_final_boss_level() \
			or App.is_izombie_level() or App.is_squirrel_level() or App.is_scary_potter_level():
		return false
	return true

func stage_has_fog() -> bool:
	var cl := custom_level()
	if cl != null:
		return cl.has_fog()
	return not App.is_stormy_night_level() and App.game_mode != PvZ.GAMEMODE_CHALLENGE_INVISIGHOUL and background == PvZ.BACKGROUND_4_FOG

func left_fog_column() -> int:
	var cl := custom_level()
	if cl != null:
		return cl.level.fog_column
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_AIR_RAID:
		return 6
	if not App.is_adventure_mode():
		return 5
	if level == 31:
		return 6
	if level >= 32 and level <= 36:
		return 5
	return 4

func get_seed_packet_position_x(index: int) -> int:
	if App.is_slot_machine_level():
		return index * 59 + 247
	if has_conveyor_belt_seed_bank():
		return index * 50 + 91
	if seed_bank.num_packets <= 7:
		return index * 59 + 85
	elif seed_bank.num_packets == 8:
		return index * 54 + 81
	elif seed_bank.num_packets == 9:
		return index * 52 + 80
	return index * 51 + 79

func get_seed_bank_extra_width() -> int:
	var n := seed_bank.num_packets
	return 0 if n <= 6 else 60 if n == 7 else 76 if n == 8 else 112 if n == 9 else 153

func offset_y_for_planting(py: int, seed_type: int) -> int:
	if Plant.is_flying(seed_type) or seed_type == PvZ.SEED_GRAVEBUSTER:
		py += 15
	if seed_type == PvZ.SEED_SPIKEWEED or seed_type == PvZ.SEED_SPIKEROCK:
		py -= 15
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN and background == PvZ.BACKGROUND_GREENHOUSE:
		py -= 25
	return py

func planting_pixel_to_grid_x(px: int, py: int, seed_type: int) -> int:
	return pixel_to_grid_x(px, offset_y_for_planting(py, seed_type))

func planting_pixel_to_grid_y(px: int, py: int, seed_type: int) -> int:
	py = offset_y_for_planting(py, seed_type)
	var gy := pixel_to_grid_y(px, py)
	if seed_type == PvZ.SEED_INSTANT_COFFEE:
		var gx := pixel_to_grid_x(px, py)
		var p := get_top_plant_at(gx, gy, PvZ.TOPPLANT_ONLY_NORMAL_POSITION)
		if p and p.is_asleep:
			return gy
		var gy_down := pixel_to_grid_y(px, py + 30)
		if gy_down != gy:
			var pd := get_top_plant_at(gx, gy_down, PvZ.TOPPLANT_ONLY_NORMAL_POSITION)
			if pd and pd.is_asleep:
				return gy_down
		var gy_up := pixel_to_grid_y(px, py - 50)
		if gy_up != gy:
			var pu := get_top_plant_at(gx, gy_up, PvZ.TOPPLANT_ONLY_NORMAL_POSITION)
			if pu and pu.is_asleep:
				return gy_up
	return gy

func _zen_grid() -> bool:
	return App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN and (background == PvZ.BACKGROUND_GREENHOUSE \
		or background == PvZ.BACKGROUND_MUSHROOM_GARDEN or background == PvZ.BACKGROUND_ZOMBIQUARIUM)

func pixel_to_grid_x(px: int, py: int) -> int:
	if _zen_grid():
		return App.zen_garden.pixel_to_grid_x(px, py)
	if px < PvZ.LAWN_XMIN + PvZ.BOARD_ADDITIONAL_WIDTH or px > PvZ.BOARD_WIDTH - PvZ.BOARD_ADDITIONAL_WIDTH - PvZ.LAWN_XMIN:
		return -1
	return clampi(Tod.idiv(px - PvZ.LAWN_XMIN - PvZ.BOARD_ADDITIONAL_WIDTH, 80), 0, MAX_GRID_SIZE_X - 1)

func pixel_to_grid_x_keep_on_board(px: int, py: int) -> int:
	return maxi(pixel_to_grid_x(px, py), 0)

func pixel_to_grid_y(px: int, py: int) -> int:
	if _zen_grid():
		return App.zen_garden.pixel_to_grid_y(px, py)
	var gx := pixel_to_grid_x(px, py)
	if gx == -1 or py < PvZ.LAWN_YMIN + PvZ.BOARD_OFFSET_Y - 30 or py > PvZ.BOARD_HEIGHT - PvZ.LAWN_YMIN + 50:
		return -1
	if stage_has_roof():
		if gx < 5:
			py -= (4 - gx) * 20
		return clampi(Tod.idiv(py - PvZ.LAWN_YMIN - PvZ.BOARD_OFFSET_Y, 85), 0, MAX_GRID_SIZE_Y - 2)
	elif stage_uses_pool_metrics():
		return clampi(Tod.idiv(py - PvZ.LAWN_YMIN - PvZ.BOARD_OFFSET_Y, 85), 0, MAX_GRID_SIZE_Y - 1)
	return clampi(Tod.idiv(py - PvZ.LAWN_YMIN - PvZ.BOARD_OFFSET_Y, 100), 0, MAX_GRID_SIZE_Y - 2)

func pixel_to_grid_y_keep_on_board(px: int, py: int) -> int:
	return maxi(pixel_to_grid_y(maxi(px, 80), py), 0)

func grid_to_pixel_x(gx: int, gy: int) -> int:
	if _zen_grid():
		return App.zen_garden.grid_to_pixel_x(gx, gy)
	return gx * 80 + PvZ.LAWN_XMIN + PvZ.BOARD_ADDITIONAL_WIDTH

func get_pos_y_based_on_row(pos_x: float, the_row: int) -> float:
	if stage_has_roof():
		var slope := 0.0
		if pos_x < 440.0 + PvZ.BOARD_ADDITIONAL_WIDTH:
			slope = (440.0 - pos_x) * 0.25 + PvZ.BOARD_OFFSET_Y
		return grid_to_pixel_y(8, the_row) + slope
	return grid_to_pixel_y(0, the_row)

func grid_to_pixel_y(gx: int, gy: int) -> int:
	if _zen_grid():
		return App.zen_garden.grid_to_pixel_y(gx, gy)
	var py: int
	if stage_has_roof():
		var slope := (5 - gx) * 20 if gx < 5 else 0
		py = gy * 85 + slope + PvZ.LAWN_YMIN - 10
	elif stage_uses_pool_metrics():
		py = gy * 85 + PvZ.LAWN_YMIN
	else:
		py = gy * 100 + PvZ.LAWN_YMIN
	if gx >= 0 and gx < MAX_GRID_SIZE_X and gy >= 0 and gy < MAX_GRID_SIZE_Y and grid_square_type[gx][gy] == PvZ.GRIDSQUARE_HIGH_GROUND:
		py -= PvZ.HIGH_GROUND_HEIGHT
	return py + PvZ.BOARD_OFFSET_Y

# ================================================================ misc queries
func kill_all_plants_in_radius(px: int, py: int, radius: int) -> void:
	for p in plants.duplicate():
		if not p.dead and LawnCommon.get_circle_rect_overlap(px, py, radius, p.get_plant_rect()):
			plants_eaten += 1
			p.die()

func seed_not_recommended_for_level(seed_type: int) -> int:
	if CustomDefs.is_custom_plant(seed_type):
		seed_type = CustomDefs.plant_base(seed_type)
	var nr := 0
	if Plant.is_nocturnal(seed_type) and not stage_is_night():
		nr = Tod.set_bit(nr, PvZ.NOT_RECOMMENDED_NOCTURNAL, true)
	if seed_type == PvZ.SEED_INSTANT_COFFEE and stage_is_night():
		nr = Tod.set_bit(nr, PvZ.NOT_RECOMMENDED_AT_NIGHT, true)
	if seed_type == PvZ.SEED_GRAVEBUSTER and not stage_has_grave_stones():
		nr = Tod.set_bit(nr, PvZ.NOT_RECOMMENDED_NEEDS_GRAVES, true)
	if seed_type == PvZ.SEED_PLANTERN and not stage_has_fog():
		nr = Tod.set_bit(nr, PvZ.NOT_RECOMMENDED_NEEDS_FOG, true)
	if seed_type == PvZ.SEED_FLOWERPOT and not stage_has_roof():
		nr = Tod.set_bit(nr, PvZ.NOT_RECOMMENDED_NEEDS_ROOF, true)
	if stage_has_roof() and (seed_type == PvZ.SEED_SPIKEWEED or seed_type == PvZ.SEED_SPIKEROCK):
		nr = Tod.set_bit(nr, PvZ.NOT_RECOMMENDED_ON_ROOF, true)
	if not stage_has_pool() and Plant.is_aquatic(seed_type):
		nr = Tod.set_bit(nr, PvZ.NOT_RECOMMENDED_NEEDS_POOL, true)
	return nr

func count_coin_by_type(coin_type: int) -> int:
	var c := 0
	for coin in coins:
		if not coin.dead and coin.type == coin_type:
			c += 1
	return c

func drop_loot_piece(px: int, py: int, drop_factor: int) -> void:
	if App.is_first_time_adventure_mode():
		if level == 22 and current_wave > 5 and not App.player_info.has_unlocked_minigames and count_coin_by_type(PvZ.COIN_PRESENT_MINIGAMES) == 0:
			App.play_foley(PvZ.FOLEY_ART_CHALLENGE)
			add_coin(px, py, PvZ.COIN_PRESENT_MINIGAMES, PvZ.COIN_MOTION_COIN)
			return
		if level == 36 and current_wave > 5 and not App.player_info.has_unlocked_puzzle_mode and count_coin_by_type(PvZ.COIN_PRESENT_PUZZLE_MODE) == 0:
			App.play_foley(PvZ.FOLEY_ART_CHALLENGE)
			add_coin(px, py, PvZ.COIN_PRESENT_PUZZLE_MODE, PvZ.COIN_MOTION_COIN)
			return
	var hit := Tod.rand_int(30000)
	if App.is_first_time_adventure_mode() and level == 11 and not dropped_first_coin and current_wave > 5:
		hit = 1000
	if App.is_whack_a_zombie_level():
		var smin := 2500
		var smax := 2800 if sun_money > 500 else 3100 if sun_money > 350 else 3700 if sun_money > 200 else 5000
		if hit >= smin * drop_factor and hit <= smax * drop_factor:
			App.play_foley(PvZ.FOLEY_SPAWN_SUN)
			add_coin(px - 20, py, PvZ.COIN_SUN, PvZ.COIN_MOTION_COIN)
			add_coin(px - 40, py, PvZ.COIN_SUN, PvZ.COIN_MOTION_COIN)
			add_coin(px - 60, py, PvZ.COIN_SUN, PvZ.COIN_MOTION_COIN)
			return
	if App.playing_quickplay:
		return
	if total_spawned_waves > 70:
		return
	var potted := 0
	if not App.zen_garden.can_drop_potted_plant_loot():
		potted = 0
	elif App.is_adventure_mode() and not App.is_first_time_adventure_mode():
		potted = 24
	else:
		potted = 12
	var choc := potted
	if App.zen_garden.can_drop_chocolate():
		choc = potted + (72 if App.is_adventure_mode() and not App.is_first_time_adventure_mode() else 36)
	var diamond := choc + 14
	var gold := choc + 250
	var silver := choc + 2500
	var ct: int
	if hit < potted * drop_factor:
		ct = PvZ.COIN_PRESENT_PLANT
	elif hit < choc * drop_factor:
		ct = PvZ.COIN_CHOCOLATE
	elif hit < diamond * drop_factor:
		ct = PvZ.COIN_GOLD if App.player_info.purchases[PvZ.STORE_ITEM_PACKET_UPGRADE] < 1 else PvZ.COIN_DIAMOND
	elif hit < gold * drop_factor:
		ct = PvZ.COIN_GOLD
	elif hit < silver * drop_factor:
		ct = PvZ.COIN_SILVER
	else:
		return
	if App.is_wallnut_bowling_level() and Coin.is_money_type(ct):
		return
	if App.is_first_time_adventure_mode() and level == 11:
		var money := Coin.get_coin_value(PvZ.COIN_GOLD) * lawn_mowers.size()
		var cost := StoreScreen.get_item_cost(PvZ.STORE_ITEM_PACKET_UPGRADE)
		money += App.player_info.coins + count_coins_being_collected()
		if Coin.get_coin_value(ct) + money >= cost:
			return
	App.play_foley(PvZ.FOLEY_SPAWN_SUN)
	add_coin(px - 40, py, ct, PvZ.COIN_MOTION_COIN)
	dropped_first_coin = true

func can_drop_loot() -> bool:
	if custom_level() != null:
		return false
	if is_versus():
		return false
	return not cut_scene.should_run_upsell_board() and (not App.is_first_time_adventure_mode() or level >= 11)

func bungee_is_targeting_cell(gx: int, gy: int) -> bool:
	for z in zombies:
		if not z.dead and not z.is_dead_or_dying() and z.zombie_type == PvZ.ZOMBIE_BUNGEE and z.row == gy and z.target_col == gx:
			return true
	return false

func get_boss_zombie() -> Zombie:
	for z in zombies:
		if not z.dead and z.zombie_type == PvZ.ZOMBIE_BOSS:
			return z
	return null

func find_umbrella_plant(gx: int, gy: int) -> Plant:
	for p in plants:
		if not p.dead and p.seed_type == PvZ.SEED_UMBRELLA and not p.not_on_ground() and LawnCommon.grid_in_range(gx, gy, p.plant_col, p.row, 1, 1):
			return p
	return null

func do_fwoosh(the_row: int) -> void:
	var order := make_render_order(PvZ.RENDER_LAYER_PARTICLE, the_row, 1)
	for i in 12:
		var ori: Reanimation = fwoosh[the_row][i]
		if ori != null and not ori.freed:
			ori.die()
		var px := 750.0 * i / 11.0 + 10.0 + PvZ.BOARD_ADDITIONAL_WIDTH
		var py := get_pos_y_based_on_row(px + 10.0, the_row) - 10.0
		var f := App.add_reanimation(px, py, order, PvZ.REANIM_JALAPENO_FIRE)
		f.set_frames_for_layer("anim_flame")
		f.loop_type = Reanimation.REANIM_LOOP_FULL_LAST_FRAME
		f.anim_rate *= Tod.rand_range_float(0.7, 1.3)
		var sc := Tod.rand_range_float(0.9, 1.1)
		var flip := 1.0 if Tod.rand_int(2) != 0 else -1.0
		f.override_scale(sc * flip, 1.0)
		fwoosh[the_row][i] = f
	fwoosh_count_down = 100

func update_fwoosh() -> void:
	if fwoosh_count_down == 0:
		return
	fwoosh_count_down -= 1
	var remaining := Tod.animate_curve(50, 0, fwoosh_count_down, 12, 0, Tod.CURVE_LINEAR)
	for r in MAX_GRID_SIZE_Y:
		for i in 12 - remaining:
			var f: Reanimation = fwoosh[r][i]
			if f != null and not f.freed:
				f.set_frames_for_layer("anim_done")
				f.anim_rate = 15
				f.loop_type = Reanimation.REANIM_PLAY_ONCE_FULL_LAST_FRAME
			fwoosh[r][i] = null

func update_grid_items() -> void:
	for gi in grid_items.duplicate():
		if gi.dead:
			continue
		if (enable_grave_stones or gi.vs_grave) and gi.grid_item_type == PvZ.GRIDITEM_GRAVESTONE and gi.grid_item_counter < 100:
			gi.grid_item_counter += 1
		if gi.grid_item_type == PvZ.GRIDITEM_CRATER and App.game_scene == PvZ.SCENE_PLAYING:
			if gi.grid_item_counter > 0:
				gi.grid_item_counter -= 1
			if gi.grid_item_counter == 0:
				gi.grid_item_die()
		gi.update()

func planting_requirements_met(seed_type: int) -> bool:
	if CustomDefs.is_custom_plant(seed_type):
		seed_type = CustomDefs.plant_base(seed_type)
	match seed_type:
		PvZ.SEED_GATLINGPEA: return count_plant_by_type(PvZ.SEED_REPEATER) > 0
		PvZ.SEED_TWINSUNFLOWER: return count_plant_by_type(PvZ.SEED_SUNFLOWER) > 0
		PvZ.SEED_GLOOMSHROOM: return count_plant_by_type(PvZ.SEED_FUMESHROOM) > 0
		PvZ.SEED_CATTAIL: return count_empty_pots_or_lilies(PvZ.SEED_LILYPAD) > 0
		PvZ.SEED_WINTERMELON: return count_plant_by_type(PvZ.SEED_MELONPULT) > 0
		PvZ.SEED_GOLD_MAGNET: return count_plant_by_type(PvZ.SEED_MAGNETSHROOM) > 0
		PvZ.SEED_SPIKEROCK: return count_plant_by_type(PvZ.SEED_SPIKEWEED) > 0
		PvZ.SEED_COBCANNON: return has_valid_cob_cannon_spot()
	return true

func kill_all_zombies_in_radius(the_row: int, px: int, py: int, radius: int, row_range: int, burn: bool, damage_flags: int) -> void:
	for z in zombies.duplicate():
		if z.dead or not z.effected_by_damage(damage_flags):
			continue
		var zr: Rect2i = z.get_zombie_rect()
		var rd: int = z.row - the_row
		if z.zombie_type == PvZ.ZOMBIE_BOSS:
			rd = 0
		if rd <= row_range and rd >= -row_range and LawnCommon.get_circle_rect_overlap(px, py, radius, zr):
			if burn:
				z.apply_burn()
			else:
				z.take_damage(1800, 18)
	var gx := pixel_to_grid_x_keep_on_board(px, py)
	var gy := pixel_to_grid_y_keep_on_board(px, py)
	for gi in grid_items:
		if not gi.dead and gi.grid_item_type == PvZ.GRIDITEM_LADDER and LawnCommon.grid_in_range(gi.grid_x, gi.grid_y, gx, gy, row_range, row_range):
			gi.grid_item_die()

func get_all_zombies_in_radius(the_row: int, px: int, py: int, radius: int, row_range: int, damage_flags: int) -> int:
	var total := 0
	for z in zombies:
		if z.dead or not z.effected_by_damage(damage_flags):
			continue
		var rd: int = z.row - the_row
		if z.zombie_type == PvZ.ZOMBIE_BOSS:
			rd = 0
		if rd <= row_range and rd >= -row_range and LawnCommon.get_circle_rect_overlap(px, py, radius, z.get_zombie_rect()):
			total += 1
	return total

func remove_particle_by_type(effect: int) -> void:
	for ps in EffectSystem.particle_systems:
		if not ps.dead and ps.effect_type == effect:
			ps.particle_system_die()

func get_current_plant_cost(seed_type: int, imitater_type: int) -> int:
	return Plant.get_cost(seed_type, imitater_type)

func can_use_game_object(obj: int) -> bool:
	if App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
		return obj == PvZ.OBJECT_TYPE_TREE_FOOD or obj == PvZ.OBJECT_TYPE_NEXT_GARDEN
	if App.game_mode != PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
		return false
	var pur: Array = App.player_info.purchases
	match obj:
		PvZ.OBJECT_TYPE_WATERING_CAN: return true
		PvZ.OBJECT_TYPE_NEXT_GARDEN:
			return pur[PvZ.STORE_ITEM_MUSHROOM_GARDEN] != 0 or pur[PvZ.STORE_ITEM_AQUARIUM_GARDEN] != 0 or pur[PvZ.STORE_ITEM_TREE_OF_WISDOM] != 0
		PvZ.OBJECT_TYPE_FERTILIZER: return pur[PvZ.STORE_ITEM_FERTILIZER] > 0
		PvZ.OBJECT_TYPE_BUG_SPRAY: return pur[PvZ.STORE_ITEM_BUG_SPRAY] > 0
		PvZ.OBJECT_TYPE_PHONOGRAPH: return pur[PvZ.STORE_ITEM_PHONOGRAPH] > 0
		PvZ.OBJECT_TYPE_CHOCOLATE: return pur[PvZ.STORE_ITEM_CHOCOLATE] > 0
		PvZ.OBJECT_TYPE_WHEELBARROW: return pur[PvZ.STORE_ITEM_WHEEL_BARROW] > 0
		PvZ.OBJECT_TYPE_GLOVE: return pur[PvZ.STORE_ITEM_GARDENING_GLOVE] > 0
		PvZ.OBJECT_TYPE_MONEY_SIGN: return App.has_finished_adventure()
	return false

func shake_board(ax: int, ay: int) -> void:
	shake_counter = 12
	shake_amount_x = ax
	shake_amount_y = ay

func find_lawn_mower_in_row(the_row: int) -> LawnMower:
	for m in lawn_mowers:
		if not m.dead and m.row == the_row:
			return m
	return null

func get_winning_zombie() -> Zombie:
	for z in zombies:
		if not z.dead and z.from_wave == Zombie.ZOMBIE_WAVE_WINNER:
			return z
	return null

func count_zombie_by_type(zombie_type: int) -> int:
	var c := 0
	for z in zombies:
		if not z.dead and z.zombie_type == zombie_type:
			c += 1
	return c

func number_zombies_in_wave(wave: int) -> int:
	var arr: PackedInt32Array = zombies_in_wave[wave]
	for i in MAX_ZOMBIES_IN_WAVE:
		if arr[i] == PvZ.ZOMBIE_INVALID:
			return i
	return 0

static func is_zombie_type_spawned_only(zombie_type: int) -> bool:
	return zombie_type == PvZ.ZOMBIE_BACKUP_DANCER or zombie_type == PvZ.ZOMBIE_BOBSLED or zombie_type == PvZ.ZOMBIE_IMP

# ================================================================ virtuals implemented by later Board layers
func clear_cursor() -> void: pass
func update_cursor() -> void: pass
func is_final_scary_potter_stage() -> bool: return false
func is_scary_potter_dave_talking() -> bool: return false
func row_can_have_zombies(_the_row: int) -> bool: return false
func pick_special_grave_stone() -> void: pass
func tutorial_arrow_remove() -> void: pass
func can_interact_with_board_buttons() -> bool: return false
func update_mouse_position() -> void: pass

## Survival is out of scope for now, so no stage ever repicks seeds.
func is_survival_stage_with_repick() -> bool:
	return false

func get_num_waves_per_survival_stage() -> int:
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_LAST_STAND or App.is_survival_normal(App.game_mode):
		return 10
	if App.is_survival_hard(App.game_mode) or App.is_survival_endless(App.game_mode):
		return 20
	return 0

func get_survival_flags_completed() -> int:
	var waves_per_flag := get_num_waves_per_flag()
	var flags_completed: int = challenge.survival_stage * get_num_waves_per_survival_stage() / waves_per_flag
	var wave := current_wave
	if is_flag_wave(wave - 1) and board_fade_out_counter < 0 and next_survival_stage_counter == 0:
		wave -= 1
	return wave / waves_per_flag + flags_completed

func is_last_stand_final_stage() -> bool:
	return App.game_mode == PvZ.GAMEMODE_CHALLENGE_LAST_STAND and challenge.survival_stage == PvZ.LAST_STAND_FLAGS - 1

func is_last_stand_stage_with_repick() -> bool:
	return App.game_mode == PvZ.GAMEMODE_CHALLENGE_LAST_STAND and not is_last_stand_final_stage()

## Board::LoadBackgroundDebug (debug object type "Background"): swaps the lawn and its row layout in place.
func load_background_debug(the_background: int) -> void:
	background = the_background
	if background == PvZ.BACKGROUND_1_DAY or background == PvZ.BACKGROUND_GREENHOUSE or background == PvZ.BACKGROUND_TREEOFWISDOM:
		plant_row = PackedInt32Array([PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_DIRT])
		if App.is_adventure_mode() and App.is_first_time_adventure_mode():
			if level == 1:
				plant_row[0] = PvZ.PLANTROW_DIRT
				plant_row[1] = PvZ.PLANTROW_DIRT
				plant_row[3] = PvZ.PLANTROW_DIRT
				plant_row[4] = PvZ.PLANTROW_DIRT
			elif level == 2 or level == 3:
				plant_row[0] = PvZ.PLANTROW_DIRT
				plant_row[4] = PvZ.PLANTROW_DIRT
		elif App.game_mode == PvZ.GAMEMODE_CHALLENGE_RESODDED:
			plant_row[0] = PvZ.PLANTROW_DIRT
			plant_row[4] = PvZ.PLANTROW_DIRT
	elif background == PvZ.BACKGROUND_2_NIGHT or background == PvZ.BACKGROUND_5_ROOF or background == PvZ.BACKGROUND_6_BOSS:
		plant_row = PackedInt32Array([PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_DIRT])
	elif background == PvZ.BACKGROUND_3_POOL or background == PvZ.BACKGROUND_ZOMBIQUARIUM or background == PvZ.BACKGROUND_4_FOG:
		plant_row = PackedInt32Array([PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_POOL, PvZ.PLANTROW_POOL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL])
	for gx in MAX_GRID_SIZE_X:
		for gy in MAX_GRID_SIZE_Y:
			if plant_row[gy] == PvZ.PLANTROW_DIRT:
				grid_square_type[gx][gy] = PvZ.GRIDSQUARE_DIRT
			elif plant_row[gy] == PvZ.PLANTROW_POOL and gx >= 0 and gx <= 8:
				grid_square_type[gx][gy] = PvZ.GRIDSQUARE_POOL
			elif plant_row[gy] == PvZ.PLANTROW_HIGH_GROUND and gx >= 4 and gx <= 8:
				grid_square_type[gx][gy] = PvZ.GRIDSQUARE_HIGH_GROUND
