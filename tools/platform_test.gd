extends Node
## Checks the platform gates: what multiplayer is allowed on, and that the mobile view reframes the
## lawn without pushing any of the HUD off screen.
## godot --headless --path . res://tools/platform_test.tscn

var failures := 0

func _ready() -> void:
	await get_tree().process_frame
	await _run()
	print("=== %s ===" % ("ALL CHECKS PASSED" if failures == 0 else "%d CHECK(S) FAILED" % failures))
	get_tree().quit(0 if failures == 0 else 1)

func check(cond: bool, msg: String) -> void:
	if cond:
		print("  ok   ", msg)
	else:
		failures += 1
		print("  FAIL ", msg)

func _pump(updates: int) -> void:
	for i in updates:
		App._run_loading_tasks()
		App.update_frames()

func _run() -> void:
	var guard := 0
	while not App.loading_thread_completed and guard < 20000:
		_pump(10)
		guard += 10
	if App.player_info == null:
		App.player_info = App.profile_mgr.add_profile("PlatformTest")
	App.loading_completed()
	_pump(60)

	print("--- device gates")
	Platform.force_mobile = false
	check(Platform.supports_multiplayer() == Platform.is_windows(),
		"multiplayer follows the platform (windows=%s)" % str(Platform.is_windows()))
	Platform.force_mobile = true
	check(not Platform.supports_multiplayer(), "a phone never gets multiplayer")
	check(Platform.is_mobile(), "and reports itself as mobile")
	check(Platform.multiplayer_unavailable_reason() != "", "with a reason to show the player")
	check(TodStrings.translate(Platform.multiplayer_unavailable_reason()).find("Missing") == -1,
		"and that reason is a real string: \"%s\"" % TodStrings.translate(Platform.multiplayer_unavailable_reason()).replace("\n", " "))
	Platform.force_mobile = false

	print("--- the main menu locks Social off Windows")
	App.show_game_selector()
	_pump(60)
	var gs: GameSelector = App.game_selector
	if gs == null:
		check(false, "the game selector opened")
		return
	Platform.force_mobile = true
	check(gs.social_locked(), "Social greys out on a phone")
	Platform.force_mobile = false
	App.kill_game_selector()
	_pump(20)

	print("--- the mobile view reframes the lawn")
	App.quick_level = 4
	App.start_quick_play()
	for i in 1000:
		_pump(10)
		if App.seed_chooser_screen != null and App.board.cut_scene.cutscene_time > 3000:
			App.seed_chooser_screen.pick_random_seeds()
		if App.game_scene == PvZ.SCENE_PLAYING:
			break
	var b: Board = App.board
	if b == null:
		check(false, "a level is running")
		return
	check(App.board_view_crop == 0, "a desktop window crops nothing")
	var desktop_menu_x: int = b.menu_button.x
	Platform.force_mobile = true
	App.update_presentation()
	_pump(5)
	check(App.board_view_crop == PvZ.MOBILE_VIEW_CROP,
		"the phone view trims the widescreen margin (%d)" % App.board_view_crop)
	check(App.get_window().content_scale_size.x == PvZ.BOARD_WIDTH - PvZ.MOBILE_VIEW_CROP,
		"and fits the narrower picture to the window (%d)" % App.get_window().content_scale_size.x)
	var visible_w := PvZ.BOARD_WIDTH - App.board_view_crop
	check(b.menu_button.x < desktop_menu_x, "the menu button moved in (%d -> %d)" % [desktop_menu_x, b.menu_button.x])
	check(b.menu_button.x + b.menu_button.width <= visible_w,
		"and still fits (%d <= %d)" % [b.menu_button.x + b.menu_button.width, visible_w])
	check(b.fast_button.x + b.fast_button.width <= visible_w, "so does the fast-forward button")
	var shovel := b.get_shovel_button_rect()
	check(shovel.position.x + shovel.size.x <= visible_w, "the shovel stays on screen")
	check(b.seed_bank.x >= 0 and b.seed_bank.x + b.seed_bank.width <= visible_w,
		"and the whole seed bank fits (%d..%d of %d)" % [b.seed_bank.x, b.seed_bank.x + b.seed_bank.width, visible_w])
	check(b.grid_to_pixel_x(8, 0) + 80 <= visible_w, "the last lawn column is still on screen")

	Platform.force_mobile = false
	App.update_presentation()
	_pump(5)
	check(App.board_view_crop == 0, "and going back to a desktop window restores the full picture")
	check(b.menu_button.x == desktop_menu_x, "with the HUD where it was")
	App.kill_board()
	_pump(20)
	App.profile_mgr.delete_profile("PlatformTest")
