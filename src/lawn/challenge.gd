class_name Challenge
extends RefCounted
## Port of Challenge (Challenge.cpp). Adventure-relevant logic is ported fully (conveyor levels,
## wall-nut bowling, whack-a-zombie, vasebreaker, stormy night, bungee blitz, boss, tree of wisdom).
## Minigame / puzzle / survival-only code paths are stubs that return safe values for now.

const BEGHOULED_WINNING_SCORE := 75
const SLOT_MACHINE_WINNING_SCORE := 2000
const ZOMBIQUARIUM_WINNING_SCORE := 1000
const I_ZOMBIE_WINNING_SCORE := 5
const MAX_PORTALS := 4
const MAX_SQUIRRELS := 7
const MAX_SCARY_POTS := 54
const STORM_FLASH_TIME := 150
const MAX_GRID_SIZE_X := 9
const MAX_GRID_SIZE_Y := 6

const ZOMBIE_WAVES := [
	4,  6,  8,  10, 8,  10, 20, 10, 20, 20,
	10, 20, 10, 20, 10, 10, 20, 10, 20, 20,
	10, 20, 20, 30, 20, 20, 30, 20, 30, 30,
	10, 20, 10, 20, 20, 10, 20, 10, 20, 20,
	10, 20, 20, 30, 20, 20, 30, 20, 30, 30,
]

var board: Board
var beghouled_mouse_capture := false
var beghouled_mouse_down_x := 0
var beghouled_mouse_down_y := 0
var beghouled_eated: Array = []          # [x][y] bool
var beghouled_purcased_upgrade := [false, false, false]
var beghouled_matches_this_move := 0
var challenge_state := PvZ.STATECHALLENGE_NORMAL
var challenge_state_counter := 0
var conveyor_belt_counter := 0
var challenge_score := 0
var show_bowling_line := false
var last_conveyor_seed_type := PvZ.SEED_NONE
var survival_stage := 0
var slot_machine_roll_count := 0
var reanim_challenge: Reanimation = null
var reanim_clouds: Array = [null, null, null, null, null, null]
var clouds_counter := [0, 0, 0, 0, 0, 0]
var challenge_grid_x := 0
var challenge_grid_y := 0
var scary_potter_pots := 0
var rain_counter := 0
var tree_of_wisdom_talk_index := 0

func _init() -> void:
	board = App.board
	for x in MAX_GRID_SIZE_X:
		var col: Array = []
		col.resize(MAX_GRID_SIZE_Y)
		col.fill(false)
		beghouled_eated.append(col)

static func _rv(r: Reanimation) -> Reanimation:
	return r if r != null and not r.dead else null

# ================================================================ level setup
func init_level() -> void:
	var custom := board.custom_level()
	if custom != null and custom.uses_conveyor():
		# start with a few packets already on the belt, the way the stock conveyor levels do
		for i in 3:
			var st := custom.next_conveyor_seed(board)
			if st == PvZ.SEED_NONE:
				break
			board.seed_bank.add_seed(st)
		conveyor_belt_counter = int(200 * custom.conveyor_interval_scale())
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_RAINING_SEEDS:
		challenge_state_counter = 100
		App.play_foley(PvZ.FOLEY_RAIN)
	if App.is_stormy_night_level():
		challenge_state = PvZ.STATECHALLENGE_STORM_FLASH_2
		challenge_state_counter = 100
		App.play_foley(PvZ.FOLEY_RAIN)
	if App.is_final_boss_level():
		board.seed_bank.add_seed(PvZ.SEED_CABBAGEPULT)
		board.seed_bank.add_seed(PvZ.SEED_JALAPENO)
		board.seed_bank.add_seed(PvZ.SEED_CABBAGEPULT)
		board.seed_bank.add_seed(PvZ.SEED_ICESHROOM)
		conveyor_belt_counter = 1000
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
		App.zen_garden.garden_type = PvZ.GARDEN_MAIN
		App.zen_garden.zen_garden_init_level(false)
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_COLUMN:
		for st in [PvZ.SEED_POTATOMINE, PvZ.SEED_TALLNUT, PvZ.SEED_MELONPULT, PvZ.SEED_MAGNETSHROOM, PvZ.SEED_INSTANT_COFFEE, PvZ.SEED_MELONPULT]:
			board.seed_bank.add_seed(st)
		conveyor_belt_counter = 1000
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_INVISIGHOUL:
		board.seed_bank.add_seed(PvZ.SEED_PEASHOOTER)
		board.seed_bank.add_seed(PvZ.SEED_ICESHROOM)
		conveyor_belt_counter = 1000
	if App.is_izombie_level():
		izombie_init_level()
	if App.is_scary_potter_level():
		scary_potter_populate()
	if App.is_first_time_adventure_mode() and board.level == 5:
		board.new_plant(5, 1, PvZ.SEED_PEASHOOTER, PvZ.SEED_NONE)
		board.new_plant(7, 2, PvZ.SEED_PEASHOOTER, PvZ.SEED_NONE)
		board.new_plant(6, 3, PvZ.SEED_PEASHOOTER, PvZ.SEED_NONE)
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_BEGHOULED_TWIST:
		challenge_grid_x = -1
		challenge_grid_y = -1
	if App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
		tree_of_wisdom_init()

func start_level() -> void:
	var mode := App.game_mode
	if App.is_whack_a_zombie_level():
		board.cursor_object.cursor_type = PvZ.CURSOR_TYPE_HAMMER
		for co in board.net_cursors:  # online: every player swings a hammer, not just this machine's cursor
			co.cursor_type = PvZ.CURSOR_TYPE_HAMMER
		board.zombie_count_down = 200
		board.zombie_count_down_start = board.zombie_count_down
	if App.is_stormy_night_level():
		challenge_state = PvZ.STATECHALLENGE_STORM_FLASH_1
		challenge_state_counter = 400
	if mode == PvZ.GAMEMODE_CHALLENGE_BOBSLED_BONANZA:
		for i in MAX_GRID_SIZE_Y:
			if board.plant_row[i] != PvZ.PLANTROW_POOL:
				board.ice_min_x[i] = 400 + PvZ.BOARD_ADDITIONAL_WIDTH
				board.ice_timer[i] = 0x7FFFFFFF
	if App.is_wallnut_bowling_level():
		board.zombie_count_down = 200
		board.zombie_count_down_start = board.zombie_count_down
		board.seed_bank.add_seed(PvZ.SEED_WALLNUT)
		conveyor_belt_counter = 400
		show_bowling_line = true
	if mode == PvZ.GAMEMODE_CHALLENGE_SHOVEL or mode == PvZ.GAMEMODE_CHALLENGE_SQUIRREL:
		shovel_add_wallnuts()
	if App.is_scary_potter_level():
		scary_potter_start()
	if App.is_little_trouble_level() or App.is_stormy_night_level() or App.is_bungee_blitz_level() or mode == PvZ.GAMEMODE_CHALLENGE_INVISIGHOUL:
		board.zombie_count_down = 200
		board.zombie_count_down_start = board.zombie_count_down
		conveyor_belt_counter = 200
	if App.is_survival_mode() and survival_stage == 0:
		var msg: String
		if App.is_survival_normal(mode):
			msg = Tod.replace_number_string("[ADVICE_SURVIVE_FLAGS]", "{FLAGS}", PvZ.SURVIVAL_NORMAL_FLAGS)
		elif App.is_survival_hard(mode):
			msg = Tod.replace_number_string("[ADVICE_SURVIVE_FLAGS]", "{FLAGS}", PvZ.SURVIVAL_HARD_FLAGS)
		else:
			msg = "[ADVICE_SURVIVE_ENDLESS]"
		board.display_advice(msg, PvZ.MESSAGE_STYLE_HINT_FAST, PvZ.ADVICE_SURVIVE_FLAGS)
	if mode == PvZ.GAMEMODE_CHALLENGE_LAST_STAND and survival_stage == 0:
		board.display_advice(Tod.replace_number_string("[ADVICE_SURVIVE_FLAGS]", "{FLAGS}", PvZ.LAST_STAND_FLAGS), PvZ.MESSAGE_STYLE_BIG_MIDDLE_FAST, PvZ.ADVICE_SURVIVE_FLAGS)
	if mode == PvZ.GAMEMODE_CHALLENGE_ART_CHALLENGE_WALLNUT:
		board.display_advice("[ADVICE_FILL_IN_WALLNUTS]", PvZ.MESSAGE_STYLE_HINT_FAST, PvZ.ADVICE_NONE)
	if mode == PvZ.GAMEMODE_CHALLENGE_ART_CHALLENGE_SUNFLOWER:
		board.display_advice("[ADVICE_FILL_IN_SPACES]", PvZ.MESSAGE_STYLE_HINT_FAST, PvZ.ADVICE_NONE)
	if mode == PvZ.GAMEMODE_CHALLENGE_SEEING_STARS:
		board.display_advice("[ADVICE_FILL_IN_STARFRUIT]", PvZ.MESSAGE_STYLE_HINT_FAST, PvZ.ADVICE_NONE)
	if App.is_slot_machine_level():
		board.set_tutorial_state(PvZ.TUTORIAL_SLOT_MACHINE_PULL)
	if mode == PvZ.GAMEMODE_CHALLENGE_BEGHOULED or mode == PvZ.GAMEMODE_CHALLENGE_BEGHOULED_TWIST:
		board.zombie_count_down = 200
		board.zombie_count_down_start = board.zombie_count_down
		challenge_state_counter = 1500
	if App.is_mini_boss_level():
		board.zombie_count_down = 100
		board.zombie_count_down_start = board.zombie_count_down
		conveyor_belt_counter = 200
	if mode == PvZ.GAMEMODE_CHALLENGE_COLUMN:
		board.current_wave = 9
		board.zombie_count_down = 2400
	if mode == PvZ.GAMEMODE_CHALLENGE_AIR_RAID or mode == PvZ.GAMEMODE_CHALLENGE_BOBSLED_BONANZA:
		board.zombie_count_down = 4500
	if mode == PvZ.GAMEMODE_CHALLENGE_POGO_PARTY:
		board.zombie_count_down = 5500

# ================================================================ input
func mouse_move(_x: int, _y: int) -> bool:
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN and App.active:
		if challenge_state == PvZ.STATECHALLENGE_ZEN_FADING:
			challenge_state = PvZ.STATECHALLENGE_NORMAL
		challenge_state_counter = 3000
	return false

func update_tool_tip(_x: int, _y: int) -> bool:
	return false  # slot machine only

func mouse_down_whack_a_zombie(x: int, y: int) -> void:
	var cr: Reanimation = _rv(board.cursor_object.reanim_cursor)
	if cr:
		cr.anim_time = 0.2
	App.play_foley(PvZ.FOLEY_SWING)

	var top: Zombie = null
	for z in board.zombies:
		if z.dead or z.is_dead_or_dying():
			continue
		if LawnCommon.get_circle_rect_overlap(x, y - 20, 45, z.get_zombie_rect()):
			if top == null or z.render_order >= top.render_order:
				top = z

	if top:
		if top.helm_type != PvZ.HELMTYPE_NONE:
			if top.helm_type == PvZ.HELMTYPE_PAIL:
				App.play_foley(PvZ.FOLEY_SHIELD_HIT)
			elif top.helm_type == PvZ.HELMTYPE_TRAFFIC_CONE:
				App.play_foley(PvZ.FOLEY_PLASTIC_HIT)
			top.take_helm_damage(900, 0)
		else:
			App.play_foley(PvZ.FOLEY_BONK)
			App.add_tod_particle(x - 3, y + 9, PvZ.RENDER_LAYER_ABOVE_UI, PvZ.PARTICLE_POW)
			top.die_with_loot()
			board.clear_cursor()

func advance_crazy_dave_dialog() -> void:
	if not board.is_scary_potter_dave_talking() or App.crazy_dave_message_index == -1:
		return
	if not App.advance_crazy_dave_text():
		App.crazy_dave_leave()
		return
	if App.crazy_dave_message_index == 2702 or App.crazy_dave_message_index == 2801:
		scary_potter_populate()
		App.play_foley(PvZ.FOLEY_PLANT)
		board.place_rake()

func mouse_down(x: int, y: int, click_count: int, hit: HitResult) -> bool:
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
		return App.zen_garden.mouse_down_zen_garden(x, y, click_count, hit)
	if App.game_scene != PvZ.SCENE_PLAYING:
		return false
	if board.is_scary_potter_dave_talking() and App.crazy_dave_message_index != -1:
		advance_crazy_dave_dialog()
		return true
	if hit.object_type == PvZ.OBJECT_TYPE_COIN and click_count >= 0:
		return false
	if App.is_whack_a_zombie_level() and hit.object_type == PvZ.OBJECT_TYPE_NONE \
			and board.cursor_object.cursor_type == PvZ.CURSOR_TYPE_HAMMER and click_count >= 0:
		mouse_down_whack_a_zombie(x, y)
		return true
	if App.is_scary_potter_level() and hit.object_type == PvZ.OBJECT_TYPE_SCARY_POT:
		scary_potter_mallet_pot(hit.object)
		return true
	return false

func mouse_up(_x: int, _y: int) -> bool:
	return false

func clear_cursor() -> void:
	if App.is_whack_a_zombie_level() and not board.has_level_award_dropped():
		board.cursor_object.cursor_type = PvZ.CURSOR_TYPE_HAMMER

# ================================================================ update
func update() -> void:
	if App.is_stormy_night_level():
		update_stormy_night()
	if board.paused:
		if App.game_mode == PvZ.GAMEMODE_CHALLENGE_BEGHOULED_TWIST:
			challenge_grid_x = -1
			challenge_grid_y = -1
		return
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_RAINING_SEEDS or App.is_stormy_night_level():
		update_rain()
	if App.game_scene != PvZ.SCENE_PLAYING and App.game_mode != PvZ.GAMEMODE_TREE_OF_WISDOM:
		return

	if board.has_conveyor_belt_seed_bank():
		update_conveyor_belt()
	if App.is_scary_potter_level():
		scary_potter_update()
	if App.can_show_seed_bank_after_sun() and board.seed_bank.y < 0:
		if board.sun_money + board.count_sun_being_collected() > 0 or board.seed_bank.y > Res.get_image("IMAGE_SEEDBANK").width:
			board.seed_bank.y += 2
			if board.seed_bank.y > 0:
				board.seed_bank.y = 0
	if App.is_whack_a_zombie_level():
		whack_a_zombie_update()
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_RAINING_SEEDS:
		update_raining_seeds()
	if App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
		tree_of_wisdom_update()
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ICE and board.main_counter == 3000:
		App.play_foley(PvZ.FOLEY_FLOOP)
		App.play_sample("SOUND_LOSEMUSIC")

	var r := _rv(reanim_challenge)
	if r and r.is_attachment:
		r.update()

func zombie_ate_plant(_zombie: Zombie, _plant: Plant) -> void:
	pass  # beghouled only

# ================================================================ conveyor belt
func update_conveyor_belt() -> void:
	if board.has_level_award_dropped():
		return
	board.seed_bank.update_conveyor_belt()
	conveyor_belt_counter -= 1
	if conveyor_belt_counter > 0:
		return

	var cl := board.custom_level()
	if cl != null:
		var n_custom := board.seed_bank.get_num_seeds_on_conveyor_belt()
		conveyor_belt_counter = int(cl.conveyor_interval_scale()
			* (1000 if n_custom > 8 else 500 if n_custom > 6 else 425 if n_custom > 4 else 400))
		var st := cl.next_conveyor_seed(board)
		if st != PvZ.SEED_NONE:
			board.seed_bank.add_seed(st)
			last_conveyor_seed_type = st
		return

	var mult := 1.0
	if App.is_final_boss_level():
		mult = 0.875
	elif App.is_shovel_level() or App.game_mode == PvZ.GAMEMODE_CHALLENGE_PORTAL_COMBAT:
		mult = 1.5
	elif App.game_mode == PvZ.GAMEMODE_CHALLENGE_INVISIGHOUL:
		mult = 2.0
	elif App.game_mode == PvZ.GAMEMODE_CHALLENGE_COLUMN:
		mult = 3.0
	var n := board.seed_bank.get_num_seeds_on_conveyor_belt()
	conveyor_belt_counter = int(mult * (1000 if n > 8 else 500 if n > 6 else 425 if n > 4 else 400))

	var picks: Array = []  # [seed, weight]
	if board.level == 10:
		picks = [[PvZ.SEED_PEASHOOTER, 20], [PvZ.SEED_CHERRYBOMB, 20], [PvZ.SEED_WALLNUT, 15], [PvZ.SEED_REPEATER, 20],
			[PvZ.SEED_SNOWPEA, 10], [PvZ.SEED_CHOMPER, 5], [PvZ.SEED_POTATOMINE, 10]]
	elif board.level == 20:
		picks = [[PvZ.SEED_GRAVEBUSTER, 20], [PvZ.SEED_ICESHROOM, 15], [PvZ.SEED_DOOMSHROOM, 15], [PvZ.SEED_HYPNOSHROOM, 10],
			[PvZ.SEED_SCAREDYSHROOM, 15], [PvZ.SEED_FUMESHROOM, 15], [PvZ.SEED_PUFFSHROOM, 10]]
	elif board.level == 30:
		picks = [[PvZ.SEED_LILYPAD, 25], [PvZ.SEED_SQUASH, 5], [PvZ.SEED_THREEPEATER, 25], [PvZ.SEED_TANGLEKELP, 5],
			[PvZ.SEED_JALAPENO, 10], [PvZ.SEED_SPIKEWEED, 10], [PvZ.SEED_TORCHWOOD, 10], [PvZ.SEED_TALLNUT, 10]]
	elif board.level == 40:
		picks = [[PvZ.SEED_LILYPAD, 25], [PvZ.SEED_SEASHROOM, 10], [PvZ.SEED_MAGNETSHROOM, 5], [PvZ.SEED_BLOVER, 5],
			[PvZ.SEED_CACTUS, 15], [PvZ.SEED_STARFRUIT, 25], [PvZ.SEED_SPLITPEA, 5], [PvZ.SEED_PUMPKINSHELL, 10]]
	elif App.is_final_boss_level():
		picks = [[PvZ.SEED_FLOWERPOT, 55], [PvZ.SEED_MELONPULT, 10], [PvZ.SEED_JALAPENO, 12], [PvZ.SEED_CABBAGEPULT, 10],
			[PvZ.SEED_KERNELPULT, 5], [PvZ.SEED_ICESHROOM, 8]]
	elif App.is_shovel_level():
		picks = [[PvZ.SEED_PEASHOOTER, 100]]
	elif App.game_mode == PvZ.GAMEMODE_CHALLENGE_WALLNUT_BOWLING_2:
		picks = [[PvZ.SEED_WALLNUT, 85], [PvZ.SEED_EXPLODE_O_NUT, 15], [PvZ.SEED_GIANT_WALLNUT, 15]]
	elif App.is_wallnut_bowling_level():
		picks = [[PvZ.SEED_WALLNUT, 85], [PvZ.SEED_EXPLODE_O_NUT, 15]]
	elif App.is_little_trouble_level():
		picks = [[PvZ.SEED_LILYPAD, 25], [PvZ.SEED_WALLNUT, 15], [PvZ.SEED_PEASHOOTER, 25], [PvZ.SEED_CHERRYBOMB, 35]]
	elif App.is_stormy_night_level():
		picks = [[PvZ.SEED_LILYPAD, 30], [PvZ.SEED_CACTUS, 10], [PvZ.SEED_PEASHOOTER, 20], [PvZ.SEED_PUFFSHROOM, 15], [PvZ.SEED_CHERRYBOMB, 25]]
	elif App.is_bungee_blitz_level():
		picks = [[PvZ.SEED_FLOWERPOT, 50], [PvZ.SEED_CHOMPER, 25], [PvZ.SEED_PUMPKINSHELL, 15], [PvZ.SEED_CHERRYBOMB, 10]]
	elif App.game_mode == PvZ.GAMEMODE_CHALLENGE_PORTAL_COMBAT:
		picks = [[PvZ.SEED_PEASHOOTER, 25], [PvZ.SEED_REPEATER, 20], [PvZ.SEED_TORCHWOOD, 10], [PvZ.SEED_CACTUS, 15],
			[PvZ.SEED_WALLNUT, 15], [PvZ.SEED_CHERRYBOMB, 15]]
	elif App.game_mode == PvZ.GAMEMODE_CHALLENGE_COLUMN:
		picks = [[PvZ.SEED_FLOWERPOT, 155], [PvZ.SEED_MELONPULT, 5], [PvZ.SEED_CHOMPER, 5], [PvZ.SEED_PUMPKINSHELL, 15],
			[PvZ.SEED_JALAPENO, 10], [PvZ.SEED_SQUASH, 10]]
	elif App.game_mode == PvZ.GAMEMODE_CHALLENGE_INVISIGHOUL:
		picks = [[PvZ.SEED_PEASHOOTER, 25], [PvZ.SEED_WALLNUT, 15], [PvZ.SEED_KERNELPULT, 5], [PvZ.SEED_SQUASH, 15],
			[PvZ.SEED_LILYPAD, 30], [PvZ.SEED_ICESHROOM, 10]]
	else:
		push_error("update_conveyor_belt: unknown conveyor level")
		return

	for pick in picks:
		var st: int = pick[0]
		var in_bank := board.seed_bank.count_of_type_on_conveyor_belt(st)
		var total := board.count_plant_by_type(st) + in_bank
		if st == PvZ.SEED_GRAVEBUSTER:
			if board.get_grave_stones_count() <= total:
				pick[1] = 0
				continue
		elif st == PvZ.SEED_LILYPAD:
			pick[1] = Tod.animate_curve(0, 18, total, pick[1], 1, Tod.CURVE_LINEAR)
		elif st == PvZ.SEED_FLOWERPOT:
			pick[1] = Tod.animate_curve(0, 45 if App.game_mode == PvZ.GAMEMODE_CHALLENGE_COLUMN else 35, total, pick[1], 1, Tod.CURVE_LINEAR)

		if App.is_final_boss_level():
			if st == PvZ.SEED_MELONPULT or st == PvZ.SEED_KERNELPULT or st == PvZ.SEED_CABBAGEPULT:
				var empty := board.count_empty_pots_or_lilies(PvZ.SEED_FLOWERPOT)
				if empty <= 2:
					pick[1] = pick[1] / 5
				elif empty <= 5:
					pick[1] = pick[1] / 3
			if st == PvZ.SEED_FLOWERPOT:
				var boss := board.get_boss_zombie()
				if boss and boss.zombie_phase == PvZ.PHASE_BOSS_DROP_RV:
					pick[1] = 500

		if picks.size() > 2:
			if in_bank >= 4:
				pick[1] = 1
			elif in_bank >= 3:
				pick[1] = 5
			elif st == last_conveyor_seed_type:
				pick[1] = pick[1] / 2

	var chosen = Tod.pick_from_weighted_array(picks)
	if chosen == null:
		return
	board.seed_bank.add_seed(chosen)
	last_conveyor_seed_type = chosen

func update_raining_seeds() -> void:
	if board.has_level_award_dropped():
		return
	challenge_state_counter -= 1
	if challenge_state_counter != 0:
		return
	challenge_state_counter = Tod.rand_range_int(500, 999)
	var coin := board.add_coin(Tod.rand_range_int(100 + PvZ.BOARD_ADDITIONAL_WIDTH, 649 + PvZ.BOARD_ADDITIONAL_WIDTH), 60, PvZ.COIN_USABLE_SEED_PACKET, PvZ.COIN_MOTION_FROM_SKY_SLOW)
	var st: int
	while true:
		st = Tod.rand_int(App.get_seeds_available())
		if board.seed_not_recommended_for_level(st) or not App.seed_type_available(st) or Plant.is_upgrade(st) \
				or st in [PvZ.SEED_SUNFLOWER, PvZ.SEED_TWINSUNFLOWER, PvZ.SEED_INSTANT_COFFEE, PvZ.SEED_UMBRELLA, PvZ.SEED_SUNSHROOM, PvZ.SEED_IMITATER]:
			continue
		break
	if Tod.rand_int(100) < Tod.animate_curve(0, 18, board.count_plant_by_type(PvZ.SEED_LILYPAD), 30, 1, Tod.CURVE_LINEAR):
		st = PvZ.SEED_LILYPAD
	coin.usable_seed_type = st

# ================================================================ stormy night / rain
func update_stormy_night() -> void:
	if board.paused:
		if challenge_state_counter == 1:
			return
		if challenge_state_counter == 150 and challenge_state == PvZ.STATECHALLENGE_STORM_FLASH_1:
			challenge_state_counter = 1
			return

	challenge_state_counter -= 1
	if (challenge_state_counter == 300 and (challenge_state == PvZ.STATECHALLENGE_STORM_FLASH_1 or challenge_state == PvZ.STATECHALLENGE_STORM_FLASH_2)) \
			or (challenge_state_counter == 150 and (challenge_state == PvZ.STATECHALLENGE_STORM_FLASH_1 or challenge_state == PvZ.STATECHALLENGE_STORM_FLASH_3)):
		App.play_foley(PvZ.FOLEY_THUNDER)
	if challenge_state_counter > 0:
		return

	if App.game_scene == PvZ.SCENE_ZOMBIES_WON:
		challenge_state_counter = STORM_FLASH_TIME + Tod.rand_range_int(-50, 50)
		challenge_state = PvZ.STATECHALLENGE_STORM_FLASH_3
	elif App.game_scene != PvZ.SCENE_PLAYING:
		challenge_state = PvZ.STATECHALLENGE_NORMAL
		challenge_state_counter = 0
	else:
		if board.count_zombie_by_type(PvZ.ZOMBIE_YETI):
			challenge_state_counter = STORM_FLASH_TIME + Tod.rand_range_int(200, 300)
		else:
			var max_dur := 400 if Tod.rand_int(2) else 750
			challenge_state_counter = STORM_FLASH_TIME + Tod.rand_range_int(300, max_dur)
		challenge_state = Tod.rand_range_int(PvZ.STATECHALLENGE_STORM_FLASH_1, PvZ.STATECHALLENGE_STORM_FLASH_3)

func update_rain() -> void:
	rain_counter -= 1
	if rain_counter < 0 and not board.cut_scene.is_before_preloading():
		var px := Tod.rand_range_float(40.0, 740.0) + PvZ.BOARD_ADDITIONAL_WIDTH
		var py := Tod.rand_range_float(90.0, 240.0) + PvZ.BOARD_OFFSET_Y
		var splash := App.add_reanimation(px, py, PvZ.RENDER_LAYER_GROUND, PvZ.REANIM_RAIN_SPLASH)
		splash.color_override = Tod.rgba(255, 255, 255, Tod.rand_range_int(100, 200))
		var sc := Tod.rand_range_float(0.7, 1.2)
		splash.override_scale(sc, sc)

		# The decomp keeps applying the colour/scale to the first splash (original bug).
		px = Tod.rand_range_float(40.0, 740.0) + PvZ.BOARD_ADDITIONAL_WIDTH
		py = Tod.rand_range_float(290.0, 410.0) + PvZ.BOARD_OFFSET_Y
		App.add_reanimation(px, py, PvZ.RENDER_LAYER_GROUND, PvZ.REANIM_RAIN_CIRCLE)
		splash.color_override = Tod.rgba(255, 255, 255, Tod.rand_range_int(50, 150))
		sc = Tod.rand_range_float(0.7, 1.1)
		splash.override_scale(sc, sc)

		px = Tod.rand_range_float(40.0, 740.0) + PvZ.BOARD_ADDITIONAL_WIDTH
		py = Tod.rand_range_float(450.0, 580.0) + PvZ.BOARD_OFFSET_Y
		App.add_reanimation(px, py, PvZ.RENDER_LAYER_GROUND, PvZ.REANIM_RAIN_SPLASH)
		splash.color_override = Tod.rgba(255, 255, 255, Tod.rand_range_int(100, 200))
		sc = Tod.rand_range_float(0.7, 1.2)
		splash.override_scale(sc, sc)

		rain_counter = Tod.rand_range_int(10, 20)

func draw_storm_flash(g: Graphics, time: int, max_amount: int) -> void:
	var draw_rand := RandomNumberGenerator.new()
	draw_rand.seed = board.main_counter / 6
	var darkness := Tod.animate_curve(150, 0, time, 255 - max_amount, 255, Tod.CURVE_LINEAR) + int(draw_rand.randi() % 64) - 32
	g.set_color(Tod.rgba(0, 0, 0, clampi(darkness, 0, 255)))
	g.fill_rect(-1000, -1000, 2800, 2600)
	g.set_color(Tod.rgba(255, 255, 255, Tod.animate_curve(150, 75, time, max_amount, 0, Tod.CURVE_LINEAR)))
	g.fill_rect(-1000, -1000, 2800, 2600)

func draw_weather(g: Graphics) -> void:
	if App.is_stormy_night_level() or App.game_mode == PvZ.GAMEMODE_CHALLENGE_RAINING_SEEDS:
		draw_rain(g)
	if App.is_stormy_night_level():
		draw_storm_night(g)

func draw_rain(g: Graphics) -> void:
	if board.cut_scene.is_before_preloading() or not App.is_3d_accel():
		return
	# The decomp tests an uninitialised local here; for board.x <= 0 both branches agree.
	var board_offset_x: int = -100 * int(board.x / 100)
	var rain := Res.get_image("IMAGE_RAIN")

	var t := board.effect_counter % 100
	var ox := Tod.animate_curve(0, 100, t, 0, -100, Tod.CURVE_LINEAR)
	var oy := Tod.animate_curve(0, 20, t % 20, -100, 0, Tod.CURVE_LINEAR)
	for h in range(9, 0, -1):
		for v in range(7, 0, -1):
			g.draw_image(rain, h * 100 + ox + board_offset_x, v * 100 + oy)

	t = board.effect_counter
	var oxc := float(Tod.animate_curve(0, 161, t % 161, 0, -100, Tod.CURVE_LINEAR))
	var oyc := float(Tod.animate_curve(0, 33, t % 33, -100, 0, Tod.CURVE_LINEAR))
	for h in 9:
		for v in 7:
			var s := 1.5
			g.tod_draw_image_scaled_f(rain, (h * 100 + oxc) * s + board_offset_x, (v * 100 + oyc) * s, s, s)

func draw_storm_night(g: Graphics) -> void:
	if challenge_state == PvZ.STATECHALLENGE_STORM_FLASH_1 and challenge_state_counter < 300:
		if challenge_state_counter > STORM_FLASH_TIME:
			draw_storm_flash(g, challenge_state_counter - STORM_FLASH_TIME, 255)
		else:
			draw_storm_flash(g, challenge_state_counter, 92)
	elif challenge_state == PvZ.STATECHALLENGE_STORM_FLASH_2 and challenge_state_counter < 300:
		draw_storm_flash(g, challenge_state_counter / 2, 255)
	elif challenge_state == PvZ.STATECHALLENGE_STORM_FLASH_3 and challenge_state_counter < 150:
		draw_storm_flash(g, challenge_state_counter, 255)
	else:
		g.set_color(Color.BLACK)
		g.fill_rect(-1000, -1000, PvZ.BOARD_WIDTH + 2000, PvZ.BOARD_HEIGHT + 2000)
	board.draw_ui_bottom(g)
	board.draw_top_right_ui(g)

# ================================================================ backdrop / planting
func spawn_level_award(gx: int, gy: int) -> void:
	if board.has_level_award_dropped():
		return
	var px := board.grid_to_pixel_x(gx, gy) + 40
	var py := board.grid_to_pixel_y(gx, gy) + 40
	var coin_type: int
	if App.is_first_time_adventure_mode():
		coin_type = PvZ.COIN_FINAL_SEED_PACKET
	elif App.is_adventure_mode() or App.has_beaten_challenge(App.game_mode):
		coin_type = PvZ.COIN_AWARD_MONEY_BAG
	else:
		coin_type = PvZ.COIN_TROPHY

	board.level_award_spawned = true
	App.board_result = PvZ.BOARDRESULT_WON
	App.play_foley(PvZ.FOLEY_SPAWN_SUN)
	var coin := board.add_coin(px, py, coin_type, PvZ.COIN_MOTION_COIN)
	App.add_tod_particle(PvZ.BOARD_WIDTH / 2, PvZ.BOARD_HEIGHT / 2, PvZ.RENDER_LAYER_TOP, PvZ.PARTICLE_SCREEN_FLASH)

	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZOMBIQUARIUM:
		coin.collect()
	elif not App.is_izombie_level():
		for z in board.zombies:
			if not z.dead and not z.is_dead_or_dying():
				z.take_damage(1800, 0)

func draw_backdrop(g: Graphics) -> void:
	if App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
		tree_of_wisdom_draw(g)
	if App.is_wallnut_bowling_level() and show_bowling_line:
		g.draw_image(Res.get_image("IMAGE_WALLNUT_BOWLINGSTRIPE"), 268 + PvZ.BOARD_ADDITIONAL_WIDTH, 77 + PvZ.BOARD_OFFSET_Y)
	if board.is_versus():
		NetVersus.draw_line(board, g)
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
		App.zen_garden.draw_backdrop(g)

func plant_added(_plant: Plant) -> void:
	pass  # art challenges only

func can_plant_at(gx: int, _gy: int, _seed_type: int) -> int:
	if CustomRuntime.active != null:
		return PvZ.PLANTING_OK
	if App.is_wallnut_bowling_level():
		return PvZ.PLANTING_NOT_PASSED_LINE if gx > 2 else PvZ.PLANTING_OK
	elif App.is_final_boss_level() and gx >= 8:
		return PvZ.PLANTING_NOT_HERE
	return PvZ.PLANTING_OK

# ================================================================ zombie waves
func init_zombie_waves() -> void:
	if CustomRuntime.active != null:
		for zt in range(PvZ.ZOMBIE_NORMAL, PvZ.NUM_ZOMBIE_TYPES):
			board.zombie_allowed[zt] = true
		return
	var mode := App.game_mode
	var a: Array = board.zombie_allowed
	if App.is_survival_mode():
		a[PvZ.ZOMBIE_NORMAL] = true
		a[PvZ.ZOMBIE_TRAFFIC_CONE] = true
		if not App.is_survival_normal(mode):
			a[PvZ.ZOMBIE_PAIL] = true
	elif mode == PvZ.GAMEMODE_CHALLENGE_SPEED:
		for t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_DOLPHIN_RIDER, PvZ.ZOMBIE_POLEVAULTER]: a[t] = true
	elif mode == PvZ.GAMEMODE_CHALLENGE_POGO_PARTY:
		a[PvZ.ZOMBIE_POGO] = true
	elif App.is_bungee_blitz_level():
		for t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_PAIL, PvZ.ZOMBIE_LADDER]: a[t] = true
	elif mode == PvZ.GAMEMODE_CHALLENGE_SUNNY_DAY:
		for t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_PAIL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_FOOTBALL, PvZ.ZOMBIE_POLEVAULTER, PvZ.ZOMBIE_JACK_IN_THE_BOX]: a[t] = true
	elif mode == PvZ.GAMEMODE_CHALLENGE_PORTAL_COMBAT:
		for t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_PAIL, PvZ.ZOMBIE_FOOTBALL, PvZ.ZOMBIE_BALLOON]: a[t] = true
	elif App.is_little_trouble_level():
		for t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_FOOTBALL, PvZ.ZOMBIE_SNORKEL]: a[t] = true
	elif mode == PvZ.GAMEMODE_CHALLENGE_BIG_TIME:
		for t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_PAIL, PvZ.ZOMBIE_DOOR, PvZ.ZOMBIE_FOOTBALL, PvZ.ZOMBIE_JACK_IN_THE_BOX]: a[t] = true
	elif mode == PvZ.GAMEMODE_CHALLENGE_RAINING_SEEDS:
		for t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_PAIL, PvZ.ZOMBIE_DOOR, PvZ.ZOMBIE_FOOTBALL, PvZ.ZOMBIE_NEWSPAPER, PvZ.ZOMBIE_JACK_IN_THE_BOX, PvZ.ZOMBIE_BUNGEE]: a[t] = true
	elif mode == PvZ.GAMEMODE_CHALLENGE_HIGH_GRAVITY:
		for t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_PAIL, PvZ.ZOMBIE_DOOR, PvZ.ZOMBIE_BALLOON]: a[t] = true
	elif App.is_whack_a_zombie_level():
		for t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_PAIL]: a[t] = true
	elif mode == PvZ.GAMEMODE_CHALLENGE_BOBSLED_BONANZA:
		for t in [PvZ.ZOMBIE_BOBSLED, PvZ.ZOMBIE_ZAMBONI]: a[t] = true
	elif mode == PvZ.GAMEMODE_CHALLENGE_AIR_RAID:
		a[PvZ.ZOMBIE_BALLOON] = true
	elif mode == PvZ.GAMEMODE_CHALLENGE_BEGHOULED or mode == PvZ.GAMEMODE_CHALLENGE_BEGHOULED_TWIST:
		for t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_PAIL, PvZ.ZOMBIE_DOOR, PvZ.ZOMBIE_FOOTBALL, PvZ.ZOMBIE_NEWSPAPER]: a[t] = true
	elif mode == PvZ.GAMEMODE_CHALLENGE_LAST_STAND:
		for t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_PAIL, PvZ.ZOMBIE_DOOR, PvZ.ZOMBIE_FOOTBALL, PvZ.ZOMBIE_NEWSPAPER,
				PvZ.ZOMBIE_JACK_IN_THE_BOX, PvZ.ZOMBIE_POLEVAULTER, PvZ.ZOMBIE_DOLPHIN_RIDER, PvZ.ZOMBIE_LADDER]: a[t] = true
	elif mode == PvZ.GAMEMODE_CHALLENGE_COLUMN:
		for t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_PAIL, PvZ.ZOMBIE_FOOTBALL]: a[t] = true
	elif mode == PvZ.GAMEMODE_CHALLENGE_INVISIGHOUL:
		for t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_PAIL, PvZ.ZOMBIE_DOLPHIN_RIDER, PvZ.ZOMBIE_ZAMBONI, PvZ.ZOMBIE_JACK_IN_THE_BOX]: a[t] = true
	elif mode == PvZ.GAMEMODE_CHALLENGE_WAR_AND_PEAS:
		for t in [PvZ.ZOMBIE_PEA_HEAD, PvZ.ZOMBIE_WALLNUT_HEAD]: a[t] = true
	elif mode == PvZ.GAMEMODE_CHALLENGE_WAR_AND_PEAS_2:
		for t in [PvZ.ZOMBIE_PEA_HEAD, PvZ.ZOMBIE_WALLNUT_HEAD, PvZ.ZOMBIE_JALAPENO_HEAD, PvZ.ZOMBIE_GATLING_HEAD, PvZ.ZOMBIE_SQUASH_HEAD, PvZ.ZOMBIE_TALLNUT_HEAD]: a[t] = true
	elif App.is_shovel_level():
		for t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE]: a[t] = true
	elif App.is_wallnut_bowling_level():
		if mode == PvZ.GAMEMODE_CHALLENGE_WALLNUT_BOWLING or App.is_adventure_mode():
			for t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_PAIL, PvZ.ZOMBIE_POLEVAULTER, PvZ.ZOMBIE_NEWSPAPER]: a[t] = true
		elif mode == PvZ.GAMEMODE_CHALLENGE_WALLNUT_BOWLING_2:
			for t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_PAIL, PvZ.ZOMBIE_POLEVAULTER, PvZ.ZOMBIE_NEWSPAPER, PvZ.ZOMBIE_DANCER, PvZ.ZOMBIE_DOOR]: a[t] = true
	elif App.is_stormy_night_level():
		for t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_DOLPHIN_RIDER, PvZ.ZOMBIE_BALLOON]: a[t] = true
	else:
		for t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_PAIL]: a[t] = true

	if App.can_spawn_yetis() and not App.is_whack_a_zombie_level() and not App.is_little_trouble_level():
		a[PvZ.ZOMBIE_YETI] = true

# ================================================================ whack a zombie
func whack_a_zombie_place_graves(grave_count: int) -> void:
	var picks: Array = []
	for col in range(3, MAX_GRID_SIZE_X):
		for row in MAX_GRID_SIZE_Y:
			if not board.can_add_grave_stone_at(col, row):
				continue
			# WIDETWEAK: fix graves prioritizing growing over plants
			picks.append({"x": col, "y": row, "weight": 1 if board.get_top_plant_at(col, row, PvZ.TOPPLANT_ANY) else 100000})
	grave_count = mini(grave_count, picks.size())
	if picks.is_empty() or grave_count <= 0:
		return
	for i in grave_count:
		var pick = Tod.pick_from_weighted_grid_array(picks)
		if pick == null:
			break
		for p in board.plants:
			if not p.dead and p.plant_col == pick.x and p.row == pick.y:
				p.die()
		board.add_a_grave_stone(pick.x, pick.y)
		pick.weight = 0

func whack_a_zombie_spawning() -> void:
	if board.current_wave == board.num_waves and board.zombie_count_down == 0:
		return
	board.zombie_count_down -= 1
	if board.zombie_count_down == 100 and board.current_wave > 0:
		whack_a_zombie_place_graves(maxi(1, 5 - board.get_grave_stones_count()))
	if board.zombie_count_down == 5:
		board.next_wave_coming()
	if board.zombie_count_down == 0:
		board.zombie_count_down = 2000
		board.zombie_count_down_start = board.zombie_count_down
		board.current_wave += 1
		challenge_state_counter = 300 if board.current_wave == board.num_waves else 1
	elif board.zombie_count_down < 300:
		return

	challenge_state_counter -= 1
	if challenge_state_counter != 0:
		return

	var phase := clampi((board.current_wave - 1) * 6 / 12, 0, 5)
	var double_chance := [0, 30, 10, 10, 15, 18]
	var triple_chance := [0, 0, 0, 0, 10, 13]
	var pail_chance := [0, 0, 0, 10, 15, 15]
	var cone_chance := [0, 0, 30, 30, 30, 30]
	var zombie_count := 1
	var zombie_type := PvZ.ZOMBIE_NORMAL
	var num_hit := Tod.rand_int(100)
	var type_hit := Tod.rand_int(100)
	var is_final_wave := board.current_wave == board.num_waves

	if is_final_wave:
		zombie_count = 20
	elif num_hit < triple_chance[phase]:
		zombie_count = 3
	elif num_hit < triple_chance[phase] + double_chance[phase]:
		zombie_count = 2

	if type_hit < pail_chance[phase] and zombie_count < 3:
		zombie_type = PvZ.ZOMBIE_PAIL
	elif type_hit < pail_chance[phase] + cone_chance[phase]:
		zombie_type = PvZ.ZOMBIE_TRAFFIC_CONE

	var grid_picks: Array = []
	for gi in board.grid_items:
		if gi.dead or gi.grid_item_type != PvZ.GRIDITEM_GRAVESTONE:
			continue
		var p := board.get_top_plant_at(gi.grid_x, gi.grid_y, PvZ.TOPPLANT_ONLY_NORMAL_POSITION)
		if p == null or p.seed_type != PvZ.SEED_GRAVEBUSTER:
			grid_picks.append([gi, 1])
	var max_speed := Tod.animate_curve_float(1, 12, board.current_wave, 1.0, 3.0, Tod.CURVE_EASE_IN)
	zombie_count = mini(zombie_count, grid_picks.size())

	for i in zombie_count:
		var grave: GridItem = Tod.pick_from_weighted_array(grid_picks)
		if grave == null:
			break
		for e in grid_picks:
			if e[0] == grave:
				e[1] = 0
		if is_final_wave:
			zombie_type = PvZ.ZOMBIE_TRAFFIC_CONE if Tod.rand_int(2) == 0 else PvZ.ZOMBIE_PAIL
			max_speed = 2.0
		var z := board.add_zombie(zombie_type, board.current_wave, true)
		if z == null:
			break
		z.rise_from_grave(grave.grid_x, grave.grid_y)
		z.phase_counter = 50
		z.vel_x = Tod.rand_range_float(0.5, max_speed)
		z.update_anim_speed()

	var smin := Tod.animate_curve(1, 12, board.current_wave, 100, 30, Tod.CURVE_LINEAR)
	var smax := Tod.animate_curve(1, 12, board.current_wave, 200, 60, Tod.CURVE_LINEAR)
	challenge_state_counter = Tod.rand_range_int(smin, smax)
	if is_final_wave:
		board.zombie_count_down = 0
		challenge_state_counter = 0

func whack_a_zombie_update() -> void:
	if board.sun_money > 0 and board.tutorial_state == PvZ.TUTORIAL_OFF:
		board.set_tutorial_state(PvZ.TUTORIAL_WHACK_A_ZOMBIE_BEFORE_PICK_SEED)
		board.tutorial_timer = 1500
	if board.tutorial_state == PvZ.TUTORIAL_WHACK_A_ZOMBIE_BEFORE_PICK_SEED and board.tutorial_timer == 0:
		board.set_tutorial_state(PvZ.TUTORIAL_WHACK_A_ZOMBIE_PICK_SEED)
		board.tutorial_timer = 400
	if board.tutorial_state == PvZ.TUTORIAL_WHACK_A_ZOMBIE_PICK_SEED and board.tutorial_timer == 0:
		board.set_tutorial_state(PvZ.TUTORIAL_WHACK_A_ZOMBIE_COMPLETED)

func update_zombie_spawning() -> bool:
	if CustomRuntime.active != null:
		return false   # custom levels use the standard countdown with their own wave list
	if App.is_whack_a_zombie_level():
		whack_a_zombie_spawning()
		return false
	return App.is_final_boss_level() \
		or App.game_mode == PvZ.GAMEMODE_CHALLENGE_ICE \
		or App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN \
		or App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM \
		or App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZOMBIQUARIUM \
		or App.is_izombie_level() \
		or App.is_squirrel_level() \
		or App.is_scary_potter_level() \
		or (App.game_mode == PvZ.GAMEMODE_CHALLENGE_LAST_STAND and challenge_state != PvZ.STATECHALLENGE_LAST_STAND_ONSLAUGHT)

func grave_danger_spawn_grave_at(gx: int, gy: int) -> void:
	for p in board.plants:
		if not p.dead and p.plant_col == gx and p.row == gy:
			p.die()
	board.enable_grave_stones = true
	var grave := board.add_a_grave_stone(gx, gy)
	if grave:
		grave.add_grave_stone_particles()

func grave_danger_spawn_random_grave() -> void:
	var picks: Array = []
	for col in range(4, MAX_GRID_SIZE_X):
		for row in MAX_GRID_SIZE_Y:
			if board.can_add_grave_stone_at(col, row):
				picks.append({"x": col, "y": row, "weight": 1 if board.get_top_plant_at(col, row, PvZ.TOPPLANT_ANY) else 100000})
	if picks.size() > 0:
		var pick = Tod.pick_from_weighted_grid_array(picks)
		grave_danger_spawn_grave_at(pick.x, pick.y)

func spawn_zombie_wave() -> void:
	if App.is_continuous_challenge() and board.current_wave == board.num_waves:
		board.current_wave = board.num_waves - 1
		var wave: PackedInt32Array = board.zombies_in_wave[board.current_wave]
		for i in wave.size():
			if wave[i] == PvZ.ZOMBIE_INVALID:
				break
			if wave[i] == PvZ.ZOMBIE_FLAG:
				wave[i] = PvZ.ZOMBIE_NORMAL
		board.zombies_in_wave[board.current_wave] = wave

	var is_flag_wave := board.is_flag_wave(board.current_wave)
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_GRAVE_DANGER and board.current_wave != board.num_waves - 1:
		if is_flag_wave:
			board.spawn_zombies_from_graves()
		elif board.current_wave > 5:
			grave_danger_spawn_random_grave()
	if App.is_bungee_blitz_level() and is_flag_wave:
		board.display_advice("[ADVICE_BUNGEES_INCOMING]", PvZ.MESSAGE_STYLE_HINT_FAST, PvZ.ADVICE_NONE)

func play_boss_enter() -> void:
	board.add_zombie(PvZ.ZOMBIE_BOSS, 0)

func shovel_add_wallnuts() -> void:
	for col in MAX_GRID_SIZE_X:
		for row in MAX_GRID_SIZE_Y - 1:
			board.add_plant(col, row, PvZ.SEED_WALLNUT, PvZ.SEED_NONE)

# ================================================================ vasebreaker (scary potter)
func scary_potter_dont_place_in_col(col: int, grid: Array) -> void:
	for e in grid:
		if e.x == col:
			e.weight = 0

func scary_potter_fill_column_with_plant(col: int, seed_type: int, grid: Array) -> void:
	scary_potter_dont_place_in_col(col, grid)
	for i in MAX_GRID_SIZE_Y - 1:
		var p := board.new_plant(col, i, seed_type, PvZ.SEED_NONE)
		if seed_type == PvZ.SEED_POTATOMINE:
			p.state_countdown = 10

func scary_potter_place_pot(pot_type: int, zombie_type: int, seed_type: int, count: int, grid: Array) -> void:
	while count > 0:
		var cell = Tod.pick_from_weighted_grid_array(grid)
		if cell == null:
			return
		var pot := board.alloc_grid_item()
		pot.grid_item_type = PvZ.GRIDITEM_SCARY_POT
		pot.grid_item_state = PvZ.GRIDITEM_STATE_SCARY_POT_QUESTION
		pot.grid_x = cell.x
		pot.grid_y = cell.y
		cell.weight = 0
		pot.render_order = Board.make_render_order(PvZ.RENDER_LAYER_PLANT, cell.y, 0)
		pot.zombie_type = zombie_type
		pot.seed_type = seed_type
		pot.scary_pot_type = pot_type
		if pot_type == PvZ.SCARYPOT_SUN:
			pot.sun_count = Tod.rand_int(3) + 1
		count -= 1

func scary_potter_change_pot_type(pot_state: int, count: int) -> void:
	var arr: Array = []
	for gi in board.grid_items:
		if gi.dead or gi.grid_item_type != PvZ.GRIDITEM_SCARY_POT:
			continue
		if (pot_state == PvZ.GRIDITEM_STATE_SCARY_POT_LEAF and gi.scary_pot_type == PvZ.SCARYPOT_SEED) \
				or (pot_state == PvZ.GRIDITEM_STATE_SCARY_POT_ZOMBIE and gi.zombie_type == PvZ.ZOMBIE_GARGANTUAR):
			arr.append([gi, 1])
	count = mini(count, arr.size())
	for i in count:
		var gi: GridItem = Tod.pick_from_weighted_array(arr)
		if gi == null:
			break
		for e in arr:
			if e[0] == gi:
				e[1] = 0
		gi.grid_item_state = pot_state

## Each entry: [pot_type, zombie_type, seed_type, count]
func _place_pots(grid: Array, no_cols: Array, pots: Array, leaf_count: int = 2) -> void:
	for c in no_cols:
		scary_potter_dont_place_in_col(c, grid)
	for p in pots:
		scary_potter_place_pot(p[0], p[1], p[2], p[3], grid)
	if leaf_count > 0:
		scary_potter_change_pot_type(PvZ.GRIDITEM_STATE_SCARY_POT_LEAF, leaf_count)

static func _seed(st: int, n: int) -> Array: return [PvZ.SCARYPOT_SEED, PvZ.ZOMBIE_INVALID, st, n]
static func _zom(zt: int, n: int) -> Array: return [PvZ.SCARYPOT_ZOMBIE, zt, PvZ.SEED_NONE, n]

func scary_potter_populate() -> void:
	var grid: Array = []
	for gx in MAX_GRID_SIZE_X:
		for gy in MAX_GRID_SIZE_Y - 1:
			grid.append({"x": gx, "y": gy, "weight": 1})

	if App.is_adventure_mode() and board.level == 35:
		match survival_stage:
			0:
				_place_pots(grid, [0, 1, 2, 3, 4, 5], [_seed(PvZ.SEED_PEASHOOTER, 5), _seed(PvZ.SEED_SQUASH, 5),
					_zom(PvZ.ZOMBIE_NORMAL, 4), _zom(PvZ.ZOMBIE_PAIL, 1)], 0)
			1:
				_place_pots(grid, [0, 1, 2, 3, 4], [_seed(PvZ.SEED_PEASHOOTER, 4), _seed(PvZ.SEED_SNOWPEA, 5), _seed(PvZ.SEED_SQUASH, 4),
					_zom(PvZ.ZOMBIE_NORMAL, 5), _zom(PvZ.ZOMBIE_PAIL, 1), _zom(PvZ.ZOMBIE_FOOTBALL, 1)], 2)
			2:
				_place_pots(grid, [0, 1, 2, 3], [_seed(PvZ.SEED_PEASHOOTER, 5), _seed(PvZ.SEED_SNOWPEA, 5), _seed(PvZ.SEED_HYPNOSHROOM, 5),
					_zom(PvZ.ZOMBIE_NORMAL, 6), _zom(PvZ.ZOMBIE_PAIL, 2), _zom(PvZ.ZOMBIE_DANCER, 1), _zom(PvZ.ZOMBIE_JACK_IN_THE_BOX, 1)], 3)
	else:
		match App.game_mode:
			PvZ.GAMEMODE_SCARY_POTTER_1:
				_place_pots(grid, [0, 1, 2, 3], [_seed(PvZ.SEED_PEASHOOTER, 5), _seed(PvZ.SEED_SNOWPEA, 5), _seed(PvZ.SEED_SQUASH, 5),
					_zom(PvZ.ZOMBIE_NORMAL, 6), _zom(PvZ.ZOMBIE_PAIL, 3), _zom(PvZ.ZOMBIE_JACK_IN_THE_BOX, 1)])
			PvZ.GAMEMODE_SCARY_POTTER_2:
				_place_pots(grid, [0, 1, 2, 8], [_seed(PvZ.SEED_LEFTPEATER, 7), _seed(PvZ.SEED_SNOWPEA, 3), _seed(PvZ.SEED_WALLNUT, 3),
					_seed(PvZ.SEED_POTATOMINE, 2), _zom(PvZ.ZOMBIE_NORMAL, 6), _zom(PvZ.ZOMBIE_PAIL, 3), _zom(PvZ.ZOMBIE_JACK_IN_THE_BOX, 1)])
			PvZ.GAMEMODE_SCARY_POTTER_3:
				_place_pots(grid, [0, 1, 2], [_seed(PvZ.SEED_LEFTPEATER, 6), _seed(PvZ.SEED_SNOWPEA, 4), _seed(PvZ.SEED_SQUASH, 2),
					_seed(PvZ.SEED_HYPNOSHROOM, 3), _seed(PvZ.SEED_WALLNUT, 3), _zom(PvZ.ZOMBIE_NORMAL, 8), _zom(PvZ.ZOMBIE_PAIL, 2),
					_zom(PvZ.ZOMBIE_DANCER, 1), _zom(PvZ.ZOMBIE_JACK_IN_THE_BOX, 1)])
			PvZ.GAMEMODE_SCARY_POTTER_4:
				_place_pots(grid, [0, 1], [_seed(PvZ.SEED_PUFFSHROOM, 11), _seed(PvZ.SEED_HYPNOSHROOM, 4), _seed(PvZ.SEED_LEFTPEATER, 4),
					_zom(PvZ.ZOMBIE_JACK_IN_THE_BOX, 8), _zom(PvZ.ZOMBIE_NORMAL, 7), _zom(PvZ.ZOMBIE_FOOTBALL, 1)])
			PvZ.GAMEMODE_SCARY_POTTER_5:
				_place_pots(grid, [0, 1], [_seed(PvZ.SEED_LEFTPEATER, 6), _seed(PvZ.SEED_PUMPKINSHELL, 3), _seed(PvZ.SEED_SQUASH, 4),
					_seed(PvZ.SEED_HYPNOSHROOM, 2), _seed(PvZ.SEED_SNOWPEA, 2), _seed(PvZ.SEED_MAGNETSHROOM, 3), _zom(PvZ.ZOMBIE_NORMAL, 6),
					_zom(PvZ.ZOMBIE_PAIL, 5), _zom(PvZ.ZOMBIE_JACK_IN_THE_BOX, 1), _zom(PvZ.ZOMBIE_FOOTBALL, 3)])
			PvZ.GAMEMODE_SCARY_POTTER_6:
				_place_pots(grid, [0, 1], [_seed(PvZ.SEED_LEFTPEATER, 6), _seed(PvZ.SEED_SQUASH, 1), _seed(PvZ.SEED_TALLNUT, 4),
					_seed(PvZ.SEED_THREEPEATER, 1), _seed(PvZ.SEED_TORCHWOOD, 3), _zom(PvZ.ZOMBIE_NORMAL, 6), _zom(PvZ.ZOMBIE_POLEVAULTER, 4),
					_zom(PvZ.ZOMBIE_FOOTBALL, 5), _zom(PvZ.ZOMBIE_JACK_IN_THE_BOX, 5)])
			PvZ.GAMEMODE_SCARY_POTTER_7:
				_place_pots(grid, [0, 1, 2], [_seed(PvZ.SEED_SPIKEWEED, 13), _seed(PvZ.SEED_WALLNUT, 3), _seed(PvZ.SEED_SQUASH, 3),
					_zom(PvZ.ZOMBIE_NORMAL, 10), _zom(PvZ.ZOMBIE_PAIL, 1)])
			PvZ.GAMEMODE_SCARY_POTTER_8:
				# WIDETWEAK: tallnuts instead of wallnuts in Another Chain Reaction
				_place_pots(grid, [0, 1], [_seed(PvZ.SEED_PUFFSHROOM, 7), _seed(PvZ.SEED_TALLNUT, 3), _seed(PvZ.SEED_SQUASH, 5),
					_seed(PvZ.SEED_LEFTPEATER, 4), _zom(PvZ.ZOMBIE_JACK_IN_THE_BOX, 8), _zom(PvZ.ZOMBIE_NORMAL, 4), _zom(PvZ.ZOMBIE_POGO, 4)])
			PvZ.GAMEMODE_SCARY_POTTER_9:
				_place_pots(grid, [0, 1], [_seed(PvZ.SEED_LEFTPEATER, 6), _seed(PvZ.SEED_SNOWPEA, 2), _seed(PvZ.SEED_PEASHOOTER, 2),
					_seed(PvZ.SEED_THREEPEATER, 2), _seed(PvZ.SEED_SQUASH, 5), _seed(PvZ.SEED_POTATOMINE, 1), _seed(PvZ.SEED_WALLNUT, 1),
					_seed(PvZ.SEED_PLANTERN, 1), _zom(PvZ.ZOMBIE_NORMAL, 8), _zom(PvZ.ZOMBIE_PAIL, 5), _zom(PvZ.ZOMBIE_JACK_IN_THE_BOX, 1),
					_zom(PvZ.ZOMBIE_GARGANTUAR, 1)])
			PvZ.GAMEMODE_SCARY_POTTER_ENDLESS:
				var extra := clampi(survival_stage / 10, 0, 8)
				_place_pots(grid, [0, 1], [_seed(PvZ.SEED_LEFTPEATER, 6), _seed(PvZ.SEED_SNOWPEA, 2), _seed(PvZ.SEED_PEASHOOTER, 1),
					_seed(PvZ.SEED_THREEPEATER, 2), _seed(PvZ.SEED_SQUASH, 5), _seed(PvZ.SEED_POTATOMINE, 1), _seed(PvZ.SEED_WALLNUT, 1),
					_seed(PvZ.SEED_PLANTERN, 1), [PvZ.SCARYPOT_SUN, PvZ.ZOMBIE_INVALID, PvZ.SEED_NONE, 1], _zom(PvZ.ZOMBIE_NORMAL, 8 - extra),
					_zom(PvZ.ZOMBIE_PAIL, 5), _zom(PvZ.ZOMBIE_JACK_IN_THE_BOX, 1), _zom(PvZ.ZOMBIE_GARGANTUAR, 1 + extra)])
				if survival_stage == 15:
					App.get_achievement(PvZ.ACHIEVEMENT_CHINA_SHOP)

	scary_potter_pots = scary_potter_count_pots()

func scary_potter_start() -> void:
	if App.is_adventure_mode():
		board.display_advice("[ADVICE_USE_SHOVEL_ON_POTS]", PvZ.MESSAGE_STYLE_HINT_STAY, PvZ.ADVICE_USE_SHOVEL_ON_POTS)

func scary_potter_is_completed() -> bool:
	for gi in board.grid_items:
		if not gi.dead and gi.grid_item_type == PvZ.GRIDITEM_SCARY_POT:
			return false
	return not board.are_enemy_zombies_on_screen()

func scary_potter_update() -> void:
	if challenge_state == PvZ.STATECHALLENGE_SCARY_POTTER_MALLETING:
		var mallet := _rv(reanim_challenge)
		if mallet == null or mallet.loop_count > 0:
			var pot := board.get_grid_item_at(PvZ.GRIDITEM_SCARY_POT, challenge_grid_x, challenge_grid_y)
			if pot:
				scary_potter_open_pot(pot)
			challenge_grid_x = 0
			challenge_grid_y = 0
			if mallet:
				mallet.die()
			reanim_challenge = null
			challenge_state = PvZ.STATECHALLENGE_NORMAL

func scary_potter_mallet_pot(pot: GridItem) -> void:
	challenge_grid_x = pot.grid_x
	challenge_grid_y = pot.grid_y
	var px := board.grid_to_pixel_x(pot.grid_x, pot.grid_y)
	var py := board.grid_to_pixel_y(pot.grid_x, pot.grid_y)
	var mallet := App.add_reanimation(px, py, PvZ.RENDER_LAYER_TOP, PvZ.REANIM_HAMMER)
	mallet.play_reanim("anim_pot_open", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 40.0)
	reanim_challenge = mallet
	challenge_state = PvZ.STATECHALLENGE_SCARY_POTTER_MALLETING
	App.play_foley(PvZ.FOLEY_SWING)

func scary_potter_count_pots() -> int:
	var n := 0
	for gi in board.grid_items:
		if not gi.dead and gi.grid_item_type == PvZ.GRIDITEM_SCARY_POT:
			n += 1
	return n

func scary_potter_count_sun_in_pot(pot: GridItem) -> int:
	return pot.sun_count

func puzzle_is_award_stage() -> bool:
	if App.is_adventure_mode():
		return false
	var goal := 3 if App.game_mode == PvZ.GAMEMODE_PUZZLE_I_ZOMBIE_ENDLESS else 10 if App.game_mode == PvZ.GAMEMODE_SCARY_POTTER_ENDLESS else 1
	return survival_stage % goal == 0

func puzzle_phase_complete(gx: int, gy: int) -> void:
	if puzzle_is_award_stage():
		var coin_type: int
		var hit := Tod.rand_int(100)
		if hit < 15:
			coin_type = PvZ.COIN_AWARD_PRESENT if App.zen_garden.can_drop_potted_plant_loot() else PvZ.COIN_AWARD_MONEY_BAG
		elif hit < 30:
			coin_type = PvZ.COIN_CHOCOLATE if App.zen_garden.can_drop_chocolate() else PvZ.COIN_AWARD_MONEY_BAG
		else:
			coin_type = PvZ.COIN_AWARD_BAG_DIAMOND
		board.add_coin(board.grid_to_pixel_x(gx, gy) + 40, board.grid_to_pixel_y(gx, gy) + 40, coin_type, PvZ.COIN_MOTION_COIN)
	else:
		board.fade_out_level()

func scary_potter_open_pot(pot: GridItem) -> void:
	var px := board.grid_to_pixel_x(pot.grid_x, pot.grid_y)
	var py := board.grid_to_pixel_y(pot.grid_x, pot.grid_y)
	match pot.scary_pot_type:
		PvZ.SCARYPOT_SEED:
			board.add_coin(px + 20, py, PvZ.COIN_USABLE_SEED_PACKET, PvZ.COIN_MOTION_FROM_PLANT).usable_seed_type = pot.seed_type
		PvZ.SCARYPOT_ZOMBIE:
			var z := board.add_zombie_in_row(pot.zombie_type, pot.grid_y, 0, true)
			if z:
				z.pos_x = px
		PvZ.SCARYPOT_SUN:
			for i in scary_potter_count_sun_in_pot(pot):
				board.add_coin(px + 15 * i, py, PvZ.COIN_SUN, PvZ.COIN_MOTION_FROM_PLANT)

	pot.grid_item_die()

	if board.help_index == PvZ.ADVICE_USE_SHOVEL_ON_POTS:
		board.display_advice("[ADVICE_DESTROY_POTS_TO_FINISH_LEVEL]", PvZ.MESSAGE_STYLE_HINT_FAST, PvZ.ADVICE_DESTORY_POTS_TO_FINISIH_LEVEL)
	if scary_potter_is_completed():
		if App.is_scary_potter_level() and not board.is_final_scary_potter_stage():
			puzzle_phase_complete(pot.grid_x, pot.grid_y)
		else:
			spawn_level_award(pot.grid_x, pot.grid_y)

	App.play_sample("SOUND_BONK")
	App.play_foley(PvZ.FOLEY_VASE_BREAKING)
	var effect := PvZ.PARTICLE_VASE_SHATTER
	if pot.grid_item_state == PvZ.GRIDITEM_STATE_SCARY_POT_LEAF:
		effect = PvZ.PARTICLE_VASE_SHATTER_LEAF
	elif pot.grid_item_state == PvZ.GRIDITEM_STATE_SCARY_POT_ZOMBIE:
		effect = PvZ.PARTICLE_VASE_SHATTER_ZOMBIE
	App.add_tod_particle(px + 20, py, PvZ.RENDER_LAYER_TOP, effect)

func scary_potter_jack_explode(pos_x: int, pos_y: int) -> void:
	var gx := board.pixel_to_grid_x(pos_x, pos_y)
	var gy := board.pixel_to_grid_y(pos_x, pos_y)
	for gi in board.grid_items.duplicate():
		if not gi.dead and gi.grid_item_type == PvZ.GRIDITEM_SCARY_POT and LawnCommon.grid_in_range(gi.grid_x, gi.grid_y, gx, gy, 1, 1):
			scary_potter_open_pot(gi)

func puzzle_next_stage_clear() -> void:
	App.play_sample("SOUND_HUGE_WAVE")
	board.next_survival_stage_counter = 0
	board.progress_meter_width = 0
	for z in board.zombies:
		if not z.dead and z.is_on_board():
			z.die_no_loot()
	for p in board.plants:
		if not p.dead and p.is_on_board_check():
			p.die()
	board.refresh_seed_packet_from_cursor()
	for c in board.coins:
		if c.dead:
			continue
		if c.type == PvZ.COIN_USABLE_SEED_PACKET:
			c.die()
		else:
			c.try_auto_collect_after_level_award()
	for gi in board.grid_items:
		if not gi.dead:
			gi.grid_item_die()
	survival_stage += 1
	board.clear_advice_immediately()
	board.level_award_spawned = false
	App.add_tod_particle(PvZ.BOARD_WIDTH / 2, PvZ.BOARD_HEIGHT / 2, PvZ.RENDER_LAYER_TOP, PvZ.PARTICLE_SCREEN_FLASH)

# ================================================================ I, Zombie (puzzle, out of scope: stubs)
static func is_zombie_seed_type(st: int) -> bool:
	return st >= PvZ.SEED_ZOMBIE_NORMAL and st < PvZ.NUM_ZOMBIE_SEEDS

static func izombie_seed_type_to_zombie_type(st: int) -> int:
	match st:
		PvZ.SEED_ZOMBIE_NORMAL: return PvZ.ZOMBIE_NORMAL
		PvZ.SEED_ZOMBIE_TRAFFIC_CONE: return PvZ.ZOMBIE_TRAFFIC_CONE
		PvZ.SEED_ZOMBIE_POLEVAULTER: return PvZ.ZOMBIE_POLEVAULTER
		PvZ.SEED_ZOMBIE_PAIL: return PvZ.ZOMBIE_PAIL
		PvZ.SEED_ZOMBIE_LADDER: return PvZ.ZOMBIE_LADDER
		PvZ.SEED_ZOMBIE_DIGGER: return PvZ.ZOMBIE_DIGGER
		PvZ.SEED_ZOMBIE_BUNGEE: return PvZ.ZOMBIE_BUNGEE
		PvZ.SEED_ZOMBIE_FOOTBALL: return PvZ.ZOMBIE_FOOTBALL
		PvZ.SEED_ZOMBIE_BALLOON: return PvZ.ZOMBIE_BALLOON
		PvZ.SEED_ZOMBIE_SCREEN_DOOR: return PvZ.ZOMBIE_DOOR
		PvZ.SEED_ZOMBONI: return PvZ.ZOMBIE_ZAMBONI
		PvZ.SEED_ZOMBIE_POGO: return PvZ.ZOMBIE_POGO
		PvZ.SEED_ZOMBIE_DANCER: return PvZ.ZOMBIE_DANCER
		PvZ.SEED_ZOMBIE_GARGANTUAR: return PvZ.ZOMBIE_GARGANTUAR
		PvZ.SEED_ZOMBIE_IMP: return PvZ.ZOMBIE_IMP
	return PvZ.ZOMBIE_INVALID

func izombie_init_level() -> void: pass
func izombie_get_brain_target(_zombie: Zombie) -> GridItem: return null
func izombie_eat_brain(_zombie: Zombie) -> bool: return false
func izombie_squish_brain(brain: GridItem) -> void:
	if brain:
		brain.grid_item_die()
func izombie_plant_drop_remaining_sun(_plant: Plant) -> void: pass

# ================================================================ tree of wisdom
func tree_of_wisdom_mouse_on(x: int, y: int) -> bool:
	var hit := HitResult.new()
	board.mouse_hit_test(x, y, hit)
	return hit.object_type == PvZ.OBJECT_TYPE_TREE_OF_WISDOM and board.cursor_object.cursor_type == PvZ.CURSOR_TYPE_TREE_FOOD

func tree_of_wisdom_get_size() -> int:
	return App.player_info.challenge_records[App.get_current_challenge_index()]

func tree_of_wisdom_draw(g: Graphics) -> void:
	var mouse_on := tree_of_wisdom_mouse_on(App.widget_manager.last_mouse_x, App.widget_manager.last_mouse_y)
	var tree := _rv(reanim_challenge)
	if tree == null:
		return
	tree.enable_extra_overlay_draw = false
	tree.override_scale(1.25, 1.25)
	tree.set_position(PvZ.BOARD_ADDITIONAL_WIDTH / 2, 0)
	tree.draw_render_group(g, 1)
	for i in 6:
		var cloud := _rv(reanim_clouds[i])
		if cloud:
			cloud.set_position(PvZ.BOARD_ADDITIONAL_WIDTH / 2, 0)
			cloud.draw_render_group(g, 0)

	var height := tree_of_wisdom_get_size()
	if mouse_on:
		tree.extra_overlay_color = Tod.rgba(255, 255, 255, 128 if height < 18 else 48)
		tree.enable_extra_overlay_draw = true
	else:
		tree.enable_extra_overlay_draw = false
	tree.draw_render_group(g, 2)

	tree.enable_extra_overlay_draw = false
	tree.draw_render_group(g, 3)

	if mouse_on:
		tree.extra_overlay_color = Tod.rgba(255, 255, 255, 32)
		tree.enable_extra_overlay_draw = true
	else:
		tree.enable_extra_overlay_draw = false
	tree.draw_render_group(g, 4)

	if challenge_state == PvZ.STATECHALLENGE_TREE_GIVE_WISDOM or challenge_state == PvZ.STATECHALLENGE_TREE_BABBLING:
		var px: int
		var py: int
		if height < 7:
			px = 400; py = 152
		elif height < 12:
			px = 395; py = 60
		else:
			px = 390; py = 40
		px += PvZ.BOARD_ADDITIONAL_WIDTH
		py += PvZ.BOARD_OFFSET_Y
		g.draw_image(Res.get_image("IMAGE_STORE_SPEECHBUBBLE2"), px, py)
		var text := "[TREE_OF_WISDOM_%d]" % tree_of_wisdom_talk_index
		TodStrings.draw_string_wrapped(g, text, Rect2i(px + 25, py + 6, 233, 144), Res.get_font("FONT_BRIANNETOD16"), Color.BLACK, PvZ.DS_ALIGN_CENTER_VERTICAL_MIDDLE)

	var cur_size := height
	var scale := 1.0
	if challenge_state == PvZ.STATECHALLENGE_TREE_JUST_GREW:
		if challenge_state_counter > 30:
			cur_size -= 1
		scale = Tod.animate_curve_float(55, 20, challenge_state_counter, 1.0, 1.2, Tod.CURVE_BOUNCE)
	if cur_size >= 50:
		var font := Res.get_font("FONT_HOUSEOFTERROR16")
		var size_str := Tod.replace_number_string(TodStrings.translate("[TREE_OF_WISDOM_HIEGHT]"), "{HEIGHT}", cur_size)
		var sw := font.string_width(size_str) * scale
		var sh := font.ascent * scale
		var m := Tod.scale_matrix(400.0 - sw * 0.5 + PvZ.BOARD_ADDITIONAL_WIDTH - 15, 20.0 + sh * 0.5, scale, scale)
		font.draw_string_matrix(g, m, size_str, Color.WHITE)

func tree_of_wisdom_init() -> void:
	board.show_shovel = false
	var tree := App.add_reanimation(0.5, 0.5, 0, PvZ.REANIM_TREEOFWISDOM)
	tree.is_attachment = true
	tree.assign_render_group_to_prefix("bg", 1)
	tree.assign_render_group_to_prefix("tree", 2)
	tree.assign_render_group_to_prefix("grass", 3)
	tree.assign_render_group_to_prefix("overlay", 4)
	tree.assign_render_group_to_prefix("leaf", 4)
	tree.assign_render_group_to_prefix("bunch", 4)
	tree.set_truncate_disappearing_frames("", false)
	reanim_challenge = tree

	var tree_size := clampi(tree_of_wisdom_get_size(), 1, 50)
	tree.play_reanim("anim_grow%d" % tree_size, Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 18.0)
	if tree_size == 1 and App.player_info.purchases[PvZ.STORE_ITEM_TREE_FOOD] < BoardInput.PURCHASE_COUNT_OFFSET:
		tree.frame_count += tree.frame_start
		tree.frame_start = 0
	else:
		tree.anim_time = 0.99

	for i in 6:
		var cloud := App.add_reanimation(0, 0, 0, PvZ.REANIM_TREEOFWISDOM_CLOUDS)
		cloud.play_reanim("Cloud%d" % (i + 1), Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 0)
		reanim_clouds[i] = cloud
		var cc := Tod.rand_range_int(-6000, 2000)
		clouds_counter[i] = cc
		if cc < 0:
			cloud.anim_time = -cc / 6000.0
			cloud.anim_rate = 0.2
			clouds_counter[i] = 0
		else:
			cloud.anim_rate = 0

	challenge_state = PvZ.STATECHALLENGE_TREE_WAITING_TO_BABBLE
	challenge_state_counter = Tod.rand_range_int(700, 1500)

func tree_of_wisdom_grow() -> void:
	App.player_info.challenge_records[App.get_current_challenge_index()] += 1
	var tree_size := tree_of_wisdom_get_size()
	var tree := _rv(reanim_challenge)
	if tree:
		tree.play_reanim("anim_grow%d" % clampi(tree_size, 1, 51), Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 8.0)
	App.play_foley(PvZ.FOLEY_PLANTGROW)
	if tree_size > 1:
		challenge_state = PvZ.STATECHALLENGE_TREE_JUST_GREW
		challenge_state_counter = 120
	else:
		challenge_state = PvZ.STATECHALLENGE_NORMAL
	if tree_size == 100:
		App.get_achievement(PvZ.ACHIEVEMENT_TOWERING_WISDOM)

func tree_of_wisdom_fertilize() -> void:
	var food := board.alloc_grid_item()
	food.pos_x = 340.0 + PvZ.BOARD_ADDITIONAL_WIDTH
	food.pos_y = 300.0 + PvZ.BOARD_OFFSET_Y
	food.grid_item_type = PvZ.GRIDITEM_ZEN_TOOL
	food.grid_x = 0
	food.grid_y = 0
	food.render_order = Board.make_render_order(PvZ.RENDER_LAYER_ABOVE_UI, 0, 0)
	var r := App.add_reanimation(food.pos_x, food.pos_y, 0, PvZ.REANIM_TREEOFWISDOM_TREEFOOD)
	r.loop_type = Reanimation.REANIM_PLAY_ONCE_AND_HOLD
	food.grid_item_reanim = r
	food.grid_item_state = PvZ.GRIDITEM_STATE_ZEN_TOOL_FERTILIZER

	App.play_foley(PvZ.FOLEY_FERTILIZER)
	App.player_info.purchases[PvZ.STORE_ITEM_TREE_FOOD] -= 1
	challenge_state = PvZ.STATECHALLENGE_NORMAL
	board.clear_cursor()

func tree_of_wisdom_babble() -> void:
	challenge_state = PvZ.STATECHALLENGE_TREE_BABBLING
	challenge_state_counter = 400
	var tree_size := tree_of_wisdom_get_size()
	var babble_hit := Tod.rand_range_int(0, 2)
	if tree_size <= 1:
		tree_of_wisdom_talk_index = 600
	elif babble_hit == 0 and tree_size >= 5:
		tree_of_wisdom_talk_index = 500
	elif babble_hit == 1:
		tree_of_wisdom_talk_index = Tod.rand_range_int(101, 110)
	else:
		tree_of_wisdom_talk_index = Tod.rand_int(4) + (201 if tree_size < 12 else 301 if tree_size < 50 else 401)

func tree_of_wisdom_give_wisdom() -> void:
	challenge_state = PvZ.STATECHALLENGE_TREE_GIVE_WISDOM
	challenge_state_counter = 1000
	var tree_size := tree_of_wisdom_get_size()
	if tree_size == 100:
		tree_of_wisdom_talk_index = 800
	elif tree_size == 500:
		tree_of_wisdom_talk_index = 900
	elif tree_size == 1000:
		tree_of_wisdom_talk_index = 1000
	elif tree_size > 1000:
		tree_of_wisdom_talk_index = 1100
	else:
		tree_of_wisdom_talk_index = clampi(tree_size - 1, 1, 49)

func tree_of_wisdom_say_repeat() -> void:
	var tree_size := tree_of_wisdom_get_size()
	if tree_size >= 100 and Tod.rand_int(47) == 0:
		tree_of_wisdom_talk_index = 800
	elif tree_size >= 500 and Tod.rand_int(47) == 0:
		tree_of_wisdom_talk_index = 900
	elif tree_size >= 1000 and Tod.rand_int(47) == 0:
		tree_of_wisdom_talk_index = 1000
	else:
		tree_of_wisdom_talk_index = Tod.rand_range_int(2, clampi(tree_size, 3, 49))
	challenge_state_counter = 600

func tree_of_wisdom_tool_update(tool: GridItem) -> void:
	var r := _rv(tool.grid_item_reanim)
	if r and r.loop_count > 0:
		tree_of_wisdom_grow()
		tool.grid_item_die()

func tree_of_wisdom_update() -> void:
	for gi in board.grid_items.duplicate():
		if not gi.dead:
			tree_of_wisdom_tool_update(gi)

	if App.game_scene == PvZ.SCENE_PLAYING and challenge_state_counter > 0:
		challenge_state_counter -= 1
	if challenge_state_counter == 0:
		if challenge_state == PvZ.STATECHALLENGE_TREE_JUST_GREW:
			tree_of_wisdom_give_wisdom()
		elif challenge_state == PvZ.STATECHALLENGE_TREE_WAITING_TO_BABBLE:
			tree_of_wisdom_babble()
		elif challenge_state == PvZ.STATECHALLENGE_TREE_BABBLING or challenge_state == PvZ.STATECHALLENGE_TREE_GIVE_WISDOM:
			if tree_of_wisdom_talk_index == 500:
				tree_of_wisdom_say_repeat()
			else:
				challenge_state = PvZ.STATECHALLENGE_TREE_WAITING_TO_BABBLE
				challenge_state_counter = Tod.rand_range_int(700, 1000)

	for i in range(5, -1, -1):
		var cloud := _rv(reanim_clouds[i])
		if cloud == null:
			continue
		if clouds_counter[i] > 0:
			clouds_counter[i] -= 1
			if clouds_counter[i] == 0:
				cloud.loop_count = 0
				cloud.anim_time = 0.0
				cloud.anim_rate = 0.2
		elif cloud.loop_count > 0:
			clouds_counter[i] = Tod.rand_range_int(2000, 4000)
		cloud.update()

func tree_of_wisdom_leave() -> void:
	for gi in board.grid_items.duplicate():
		if not gi.dead and gi.grid_item_type == PvZ.GRIDITEM_ZEN_TOOL:
			tree_of_wisdom_grow()
			gi.grid_item_die()

func tree_of_wisdom_next_garden() -> void:
	tree_of_wisdom_leave()
	App.kill_board()
	App.pre_new_game(PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN, false)

func tree_of_wisdom_open_store() -> void:
	tree_of_wisdom_leave()
	var store := App.show_store_screen()
	store.back_button.label = "[STORE_BACK_TO_GAME]"
	store.page = PvZ.STORE_PAGE_ZEN2
	await store.wait_for_result(true)
	App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_ZEN_GARDEN)

func tree_of_wisdom_tool(x: int, y: int) -> void:
	if tree_of_wisdom_mouse_on(x, y):
		tree_of_wisdom_fertilize()
	board.clear_cursor()

func tree_of_wisdom_hit_test(x: int, y: int, hit: HitResult) -> bool:
	var tree_size := tree_of_wisdom_get_size()
	var oy := PvZ.BOARD_OFFSET_Y * 2
	var r: Rect2i
	if tree_size <= 1:
		r = Rect2i(310 + PvZ.BOARD_ADDITIONAL_WIDTH, 275 - oy, 175, 175 + oy)
	elif tree_size < 7:
		r = Rect2i(290 + PvZ.BOARD_ADDITIONAL_WIDTH, 255 - oy, 205, 195 + oy)
	elif tree_size < 12:
		r = Rect2i(290 + PvZ.BOARD_ADDITIONAL_WIDTH, 215 - oy, 205, 225 + oy)
	else:
		r = Rect2i(280 + PvZ.BOARD_ADDITIONAL_WIDTH, 155 - oy, 225, 305 + oy)
	hit.object = null
	if r.has_point(Vector2i(x, y)):
		hit.object_type = PvZ.OBJECT_TYPE_TREE_OF_WISDOM
		return true
	hit.object_type = PvZ.OBJECT_TYPE_NONE
	return false

func tree_of_wisdom_can_feed() -> bool:
	if challenge_state == PvZ.STATECHALLENGE_TREE_JUST_GREW:
		return false
	for gi in board.grid_items:
		if not gi.dead and gi.grid_item_type == PvZ.GRIDITEM_ZEN_TOOL:
			return false
	return true
