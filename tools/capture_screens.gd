extends Node
## Windowed screenshot pass over the menus/dialogs, for eyeballing layout against the original.
## godot --path . res://tools/capture_screens.tscn -- <output_dir>

var out_dir := "user://captures"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	App.set_process(false)
	await get_tree().process_frame
	await _run()
	get_tree().quit()

func _pump(updates: int) -> void:
	for i in updates:
		App._run_loading_tasks()
		App.update_frames()

func _shot(file_name: String) -> void:
	App._draw_frame()
	await RenderingServer.frame_post_draw
	App._draw_frame()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file_name + ".png"))
	print("captured ", file_name)

func _run() -> void:
	while not App.loading_thread_completed:
		_pump(10)
		App._draw_frame()
		await get_tree().process_frame
	var made_profile := false
	if App.player_info == null:
		App.player_info = App.profile_mgr.add_profile("Smoketest")
		made_profile = true
	App.widget_manager.on_mouse_move(-100, -100)

	App.loading_completed()
	_pump(500)
	await _shot("01_game_selector")

	App.do_new_options(true)
	_pump(30)
	await _shot("02_options")
	App.kill_new_options_dialog()
	App.do_advanced_options(true, -1, -1)
	var adv = App.get_dialog(PvZ.DIALOG_NEWOPTIONS)
	App.center_dialog(adv, adv.width, adv.height)
	_pump(30)
	await _shot("03_advanced_options_p1")
	adv.button_depress(NewOptionsDialog.NEW_OPTIONS_RIGHT_PAGE)
	_pump(10)
	await _shot("04_advanced_options_p2")
	App.kill_new_options_dialog()

	App.do_user_dialog()
	_pump(30)
	await _shot("05_user_dialog")
	App.kill_dialog(PvZ.DIALOG_USERDIALOG)

	var almanac: AlmanacDialog = App.do_almanac_dialog()
	_pump(60)
	await _shot("06_almanac_index")
	almanac.show_plant(PvZ.SEED_PEASHOOTER)
	_pump(60)
	await _shot("07_almanac_plants")
	almanac.show_zombie(PvZ.ZOMBIE_NORMAL)
	_pump(60)
	await _shot("08_almanac_zombies")
	App.kill_almanac_dialog()

	App.show_achievement_screen()
	_pump(60)
	await _shot("09_achievements")
	App.kill_achievement_screen()

	App.kill_game_selector()
	App.show_challenge_screen(PvZ.CHALLENGE_PAGE_CHALLENGE)
	_pump(60)
	await _shot("10_challenge_screen")
	App.do_challenge_pages_dialog()
	_pump(20)
	await _shot("11_challenge_pages")
	App.kill_dialog(PvZ.DIALOG_CHALLENGE_PAGES)
	App.kill_challenge_screen()

	App.show_mini_credit_screen()
	_pump(30)
	await _shot("12_mini_credits")
	App.kill_mini_credit_screen()

	App.show_credit_screen()
	_pump(1)
	App._draw_frame()
	_pump(400)
	await _shot("13_credits_main1")
	App.credit_screen.jump_to_frame(CreditScreen.CREDITS_MAIN2, 200.0)
	_pump(60)
	await _shot("14_credits_main2")
	App.credit_screen.jump_to_frame(CreditScreen.CREDITS_END, 0.0)
	_pump(200)
	await _shot("15_credits_end")
	App.kill_credit_screen()
	App.music.stop_all_music()

	if made_profile:
		App.profile_mgr.delete_profile("Smoketest")
		App.player_info = null
