extends Node
## Headless smoke test: drives App through the menus, dialogs and screens and a level intro,
## so runtime script errors in code paths the title screen never reaches show up in the log.
## godot --headless --path . res://tools/smoke_test.tscn

const TEST_PROFILE := "Smoketest"

func _ready() -> void:
	# App's own _process also ticks; stop it so this script controls the update count.
	App.set_process(false)
	await get_tree().process_frame
	await _run()
	get_tree().quit()

func _pump(updates: int) -> void:
	for i in updates:
		App._run_loading_tasks()
		App.update_frames()
		if i % 5 == 0:
			App._draw_frame()

## Moves the mouse over the whole screen so hover, tooltip and hit-test code runs.
func _sweep() -> void:
	var wm: WidgetManager = App.widget_manager
	for py in range(10, PvZ.BOARD_HEIGHT, 45):
		for px in range(10, PvZ.BOARD_WIDTH, 45):
			wm.on_mouse_move(px, py)
		_pump(1)
	wm.on_mouse_move(PvZ.BOARD_WIDTH / 2, PvZ.BOARD_HEIGHT / 2)

func _step(title: String) -> void:
	print("--- ", title)

func _run() -> void:
	_step("loading")
	var guard := 0
	while not App.loading_thread_completed and guard < 20000:
		_pump(10)
		guard += 10
	print("loaded after ", guard, " updates: ", App.loading_thread_completed)

	var made_profile := false
	if App.player_info == null:
		App.player_info = App.profile_mgr.add_profile(TEST_PROFILE)
		made_profile = true

	_step("game selector")
	App.loading_completed()
	_pump(400)
	_sweep()

	_step("options (main menu)")
	App.do_new_options(true)
	_pump(60)
	_sweep()
	App.kill_new_options_dialog()
	_step("advanced options, all pages")
	App.do_advanced_options(true, 100, 100)
	var adv = App.get_dialog(PvZ.DIALOG_NEWOPTIONS)
	for page in 3:
		adv.button_depress(NewOptionsDialog.NEW_OPTIONS_RIGHT_PAGE)
		_pump(30)
		_sweep()
	adv.button_depress(NewOptionsDialog.NEW_OPTIONS_LANGUAGE)
	adv.button_depress(NewOptionsDialog.NEW_OPTIONS_RESOURCE_PACK)
	_pump(30)
	_sweep()
	App.kill_new_options_dialog()

	_step("user dialogs")
	App.do_user_dialog()
	_pump(40)
	_sweep()
	App.do_create_user_dialog()
	_pump(40)
	_sweep()
	App.kill_dialog(PvZ.DIALOG_CREATEUSER)
	App.kill_dialog(PvZ.DIALOG_USERDIALOG)
	App.do_cheat_dialog()
	_pump(40)
	_sweep()
	App.kill_dialog(PvZ.DIALOG_CHEAT)

	_step("achievements")
	App.show_achievement_screen()
	_pump(120)
	_sweep()
	App.kill_achievement_screen()

	_step("almanac index / plants / zombies")
	var almanac: AlmanacDialog = App.do_almanac_dialog()
	_pump(60)
	_sweep()
	almanac.set_page(PvZ.ALMANAC_PAGE_PLANTS)
	_pump(60)
	_sweep()
	for st in [PvZ.SEED_LILYPAD, PvZ.SEED_COBCANNON, PvZ.SEED_IMITATER, PvZ.SEED_GRAVEBUSTER]:
		almanac.selected_seed = st
		almanac.setup_plant()
		_pump(20)
		_sweep()
	almanac.set_page(PvZ.ALMANAC_PAGE_ZOMBIES)
	_pump(60)
	_sweep()
	for zt in [PvZ.ZOMBIE_FOOTBALL, PvZ.ZOMBIE_ZAMBONI, PvZ.ZOMBIE_BOSS, PvZ.ZOMBIE_YETI]:
		almanac.selected_zombie = zt
		almanac.setup_zombie()
		_pump(20)
		_sweep()
	App.kill_almanac_dialog()

	_step("award screen")
	App.kill_game_selector()
	App.show_award_screen(PvZ.AWARD_FORLEVEL, false)
	_pump(120)
	_sweep()
	App.kill_award_screen()

	_step("challenge screen + page dialog")
	for page in [PvZ.CHALLENGE_PAGE_CHALLENGE, PvZ.CHALLENGE_PAGE_SURVIVAL, PvZ.CHALLENGE_PAGE_PUZZLE]:
		App.show_challenge_screen(page)
		_pump(60)
		_sweep()
		App.do_challenge_pages_dialog()
		_pump(30)
		_sweep()
		App.kill_dialog(PvZ.DIALOG_CHALLENGE_PAGES)
		App.kill_challenge_screen()

	_step("mini credits")
	App.show_mini_credit_screen()
	_pump(60)
	_sweep()
	App.kill_mini_credit_screen()

	_step("credits movie")
	App.show_credit_screen()
	_pump(600)
	_sweep()
	for jump in [[CreditScreen.CREDITS_MAIN1, 304.0], [CreditScreen.CREDITS_MAIN2, 188.0], [CreditScreen.CREDITS_MAIN3, 216.0], [CreditScreen.CREDITS_END, 0.0]]:
		App.credit_screen.jump_to_frame(jump[0], jump[1])
		_pump(300)
		_sweep()
	App.kill_credit_screen()
	App.music.stop_all_music()

	_step("adventure 1-1 intro")
	var old_level: int = App.player_info.level
	App.player_info.level = 1
	App.pre_new_game(PvZ.GAMEMODE_ADVENTURE, false)
	_pump(1500)
	_sweep()
	_step("in-game options + continue dialog")
	App.do_new_options(false)
	_pump(40)
	_sweep()
	App.kill_new_options_dialog()
	App.do_continue_dialog()
	_pump(40)
	_sweep()
	App.kill_dialog(PvZ.DIALOG_CONTINUE)
	_pump(600)
	_sweep()
	print("game scene: ", App.game_scene, " zombies: ", App.board.zombies.size() if App.board else -1)
	App.player_info.level = old_level
	App.kill_board()

	_quick_play_all_levels()
	await _debug_mode_section()

	if made_profile:
		App.profile_mgr.delete_profile(TEST_PROFILE)
		App.player_info = null
	_step("done")

func _key(ch: String) -> void:
	App.widget_manager.on_key_char(ch)
	_pump(2)

func _check(label: String, ok: bool) -> void:
	print(("PASS " if ok else "FAIL ") + label)

## Advanced options / debug mode. Uses a throwaway profile and in-memory flags only; nothing is written to settings.
func _debug_mode_section() -> void:
	_step("debug mode: advanced options apply")
	var saved_player: PlayerInfo = App.player_info
	var saved := [App.tod_cheat_keys, App.debug_keys_enabled, App.auto_collect_suns, App.auto_collect_coins,
		App.zombie_healthbars, App.plant_healthbars, App.speed_modifier, App.custom_cursor]
	var temp := App.profile_mgr.add_profile("SmokeDebug")
	App.player_info = temp

	App.show_game_selector()
	_pump(300)
	App.do_advanced_options(true, -1, -1)
	var adv: NewOptionsDialog = App.get_dialog(PvZ.DIALOG_NEWOPTIONS)
	adv.debug_mode_checkbox.set_checked(true, false)
	adv.auto_collect_suns_checkbox.set_checked(true, false)
	adv.zombie_healthbars_checkbox.set_checked(true, false)
	adv.plant_healthbars_checkbox.set_checked(true, false)
	adv.custom_cursor_checkbox.set_checked(true, false)
	adv.speed_edit_widget.text = "5"
	adv.apply_options()
	App.kill_dialog(PvZ.DIALOG_NEWOPTIONS)
	_check("debug mode sets tod_cheat_keys", App.tod_cheat_keys)
	_check("debug mode sets debug_keys_enabled", App.debug_keys_enabled)
	_check("auto-collect suns applied", App.auto_collect_suns)
	_check("health bars applied", App.zombie_healthbars and App.plant_healthbars)
	_check("speed modifier applied", App.speed_modifier == 5)
	_pump(20)
	_sweep()

	_step("debug mode: menu U unlock")
	App.widget_manager.set_focus(App.game_selector)
	_key("u")
	_check("U finishes adventure twice", temp.finished_adventure == 2)
	_check("U unlocks minigames/puzzle/survival", temp.has_unlocked_minigames == 1 and temp.has_unlocked_puzzle_mode == 1 and temp.has_unlocked_survival_mode == 1)
	_check("U gives trophies", temp.challenge_records[0] == 20)
	_key("c")
	_key("a")
	_key("a")

	_step("debug mode: board keys in 1-1")
	temp.level = 1
	temp.finished_adventure = 0
	App.pre_new_game(PvZ.GAMEMODE_ADVENTURE, false)
	_pump(1500)
	var b: Board = App.board
	App.widget_manager.set_focus(b)
	_check("fast button visible when playing", not b.fast_button.btn_no_draw)
	var sun_before := b.sun_money
	_key("0")
	_check("0 adds 100 sun", b.sun_money == mini(sun_before + 100, 9990))
	_key("9")
	_check("9 maxes sun", b.sun_money == 9990)
	_key("8")
	_check("8 toggles easy planting", App.easy_planting_cheat)
	_key("8")
	App.widget_manager.on_mouse_move(600, 400)
	for type in 7:
		for i in 3:
			_key("w")
			_key("d")
		_key("s")
	_pump(120)
	_sweep()
	for i in 5:
		_key("z")
		_pump(10)
	_key("6")
	_pump(50)
	_key("6")
	_key("7")
	_pump(50)
	_key("7")
	App.is_fast_mode = true
	_pump(60)
	App.is_fast_mode = false
	_key("?")
	_key("q")
	_pump(200)
	_sweep()
	_key("!")
	_pump(900)
	print("after !: profile level=", temp.level, " board_fade_out_counter=", App.board.board_fade_out_counter if App.board else -99, " scene=", App.game_scene)
	_check("! completes the level", temp.level == 2)
	App.kill_award_screen()
	App.kill_board()

	App.player_info = saved_player
	App.profile_mgr.delete_profile("SmokeDebug")
	App.tod_cheat_keys = saved[0]; App.debug_keys_enabled = saved[1]; App.auto_collect_suns = saved[2]; App.auto_collect_coins = saved[3]
	App.zombie_healthbars = saved[4]; App.plant_healthbars = saved[5]; App.speed_modifier = saved[6]; App.custom_cursor = saved[7]
	App.easy_planting_cheat = false

## Starts every adventure level through Quick Play (the path that crashed on 5-10 with a short table row).
func _quick_play_all_levels() -> void:
	_step("quick play: every level 1-1 .. 5-10")
	var saved_level: int = App.quick_level
	var failed := 0
	for lvl in range(1, 51):
		App.quick_level = lvl
		App.start_quick_play()
		if lvl == 50:
			for chunk in 40:
				_pump(150)
				if App.crazy_dave_state != PvZ.CRAZY_DAVE_OFF:
					App.widget_manager.on_mouse_down(640, 400, 1)
					App.widget_manager.on_mouse_up(640, 400, 1)
				if App.game_scene == PvZ.SCENE_PLAYING and App.board.get_boss_zombie() != null:
					break
			print("5-10 cutscene_time=", App.board.cut_scene.cutscene_time, " crazy_dave=", App.crazy_dave_state)
		else:
			_pump(80)
		if App.board == null or App.board.level != lvl:
			failed += 1
			print("FAIL quick play level ", lvl)
		elif lvl == 50:
			var boss := App.board.get_boss_zombie()
			print("5-10 scene=", App.game_scene, " boss=", boss != null)
			_check("5-10 reaches the Zomboss fight", App.game_scene == PvZ.SCENE_PLAYING and boss != null)
		App.kill_board()
	App.playing_quickplay = false
	App.quick_level = saved_level
	App.music.stop_all_music()
	_check("all 50 quick play levels start", failed == 0)

