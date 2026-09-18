extends Node
## Windowed screenshots of the main menu only (quicker than capture_screens for layout work).
## godot --path . res://tools/capture_menu.tscn -- <output_dir>

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

func _centre(w: Widget) -> Vector2i:
	return Vector2i(w.x + w.width / 2, w.y + w.height / 2)

func _run() -> void:
	while not App.loading_thread_completed:
		_pump(10)
		App._draw_frame()
		await get_tree().process_frame
	var original: PlayerInfo = App.player_info
	var made_profile := false
	if original == null:
		App.player_info = App.profile_mgr.add_profile("Smoketest")
		made_profile = true
	App.widget_manager.on_mouse_move(-100, -100)
	App.loading_completed()
	_pump(25)
	await _shot("menu_01_intro")
	_pump(200)
	await _shot("menu_02_idle")

	var gs: GameSelector = App.game_selector
	var p := _centre(gs.adventure_button)
	App.widget_manager.on_mouse_move(p.x, p.y)
	_pump(2)
	await _shot("menu_03_hover_adventure")
	p = _centre(gs.quit_button)
	App.widget_manager.on_mouse_move(p.x, p.y)
	_pump(2)
	await _shot("menu_04_hover_quit")
	App.widget_manager.on_mouse_move(-100, -100)

	var fresh := App.profile_mgr.add_profile("MenuCaptureFresh")
	App.player_info = fresh
	gs.sync_profile(false)
	_pump(2)
	await _shot("menu_05_fresh_profile")
	App.player_info = original if not made_profile else App.player_info
	App.profile_mgr.delete_profile("MenuCaptureFresh")
	if made_profile:
		App.player_info = App.profile_mgr.get_profile("Smoketest")
	gs.sync_profile(false)

	gs.button_depress(GameSelector.GAMESELECTOR_ACHIEVEMENT)
	_pump(38)
	await _shot("menu_06_achievements_slide")
	App.kill_achievement_screen()

	if made_profile:
		App.profile_mgr.delete_profile("Smoketest")
		App.player_info = null
