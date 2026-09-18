extends Node
## Side-by-side proof of the mobile presentation: the same level drawn in a desktop window and in
## a 4:3 "tablet" window with the phone layout forced on.
## godot --path . res://tools/capture_mobile.tscn -- <output_dir>

var out_dir := "user://captures"
var _pumped := 0

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
		if _pumped % 5 == 0:
			App._draw_frame()
		_pumped += 1

func _shot(file_name: String) -> void:
	App._draw_frame()
	await RenderingServer.frame_post_draw
	App._draw_frame()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file_name + ".png"))
	print("captured ", file_name, "  crop=", App.board_view_crop,
		"  window=", get_window().size, "  fitted=", get_window().content_scale_size)

func _run() -> void:
	while not App.loading_thread_completed:
		_pump(10)
		App._draw_frame()
		await get_tree().process_frame
	var made := false
	if App.player_info == null:
		App.player_info = App.profile_mgr.add_profile("MobileShots")
		made = true
	App.widget_manager.on_mouse_move(-100, -100)
	App.loading_completed()
	_pump(60)

	await _shot("00_menu_desktop")
	await _start_level()
	await _shot("01_lawn_desktop")

	# now the same thing as a tablet: 4:3 window, phone layout on
	Platform.force_mobile = true
	get_window().size = Vector2i(960, 720)
	App.apply_presentation()
	_pump(30)
	await _shot("02_lawn_mobile")
	App.kill_board()
	_pump(30)
	App.show_game_selector()
	_pump(120)
	await _shot("03_menu_mobile")
	App.kill_game_selector()

	Platform.force_mobile = false
	get_window().size = Vector2i(1280, 720)
	App.apply_presentation()
	if made:
		App.profile_mgr.delete_profile("MobileShots")
		App.player_info = null

func _start_level() -> void:
	App.kill_game_selector()
	App.quick_level = 4
	App.start_quick_play()
	var picked := false
	for i in 1000:
		_pump(10)
		if not picked and App.seed_chooser_screen != null and App.board.cut_scene.cutscene_time > 3000:
			picked = true
			App.seed_chooser_screen.pick_random_seeds()
		if App.game_scene == PvZ.SCENE_PLAYING:
			break
	_pump(300)
	# picking the seeds straight out of the chooser skips the slide-on, so put the tray where a
	# player would see it
	App.board.seed_bank.move(PvZ.SEED_BANK_OFFSET_X_END, 0)
