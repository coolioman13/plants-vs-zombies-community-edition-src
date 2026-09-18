extends Node
## Windowed, seeded screenshots of a crowded lawn (chilled, mind-controlled, shielded and eating zombies), used to
## check that rendering / performance changes draw the same picture and simulate the same way.
## godot --path . res://tools/capture_wave.tscn -- <output_dir>
## Add "dump" for a per-tick state dump instead of screenshots (and "verbose" for every object), e.g.
## godot --headless --path . res://tools/capture_wave.tscn -- <output_dir> dump
## Note: the game is not bit-deterministic across runs for long; two runs of the same build drift after ~100 ticks.

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

var _pumped := 0
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
	print("captured ", file_name)

func _run() -> void:
	while not App.loading_thread_completed:
		_pump(10)
		App._draw_frame()
		await get_tree().process_frame
	var made_profile := false
	if App.player_info == null:
		App.player_info = App.profile_mgr.add_profile("CaptureWave")
		made_profile = true
	App.widget_manager.on_mouse_move(-100, -100)
	App.loading_completed()
	_pump(50)

	App.kill_game_selector()
	_pumped = 0
	Tod.rng.seed = 424242
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
	var board: Board = App.board
	App.widget_manager.on_mouse_move(-100, -100)

	Tod.rng.seed = 434343
	_pumped = 0
	var plant_types := [PvZ.SEED_REPEATER, PvZ.SEED_SNOWPEA, PvZ.SEED_PEASHOOTER, PvZ.SEED_WALLNUT, PvZ.SEED_SUNFLOWER]
	for gy in 5:
		for gx in 4:
			board.new_plant(gx, gy, plant_types[(gx + gy) % plant_types.size()], PvZ.SEED_NONE)
	var zombie_types := [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_PAIL, PvZ.ZOMBIE_FOOTBALL, PvZ.ZOMBIE_DOOR,
		PvZ.ZOMBIE_NEWSPAPER, PvZ.ZOMBIE_POLEVAULTER, PvZ.ZOMBIE_FLAG]
	for i in 60:
		var z := board.add_zombie_in_row(zombie_types[i % zombie_types.size()], i % 5, 1, true)
		if z:
			z.pos_x = 330.0 + (i * 37) % 520 + PvZ.BOARD_ADDITIONAL_WIDTH
			z.x = int(z.pos_x)
			if i % 7 == 3:
				z.apply_chill(false)
			if i % 11 == 5:
				z.start_mind_controlled()
	if OS.get_cmdline_user_args().has("dump"):
		for f in 400:
			_pump(1)
			_dump(board, f + 1)
		App.kill_board()
		return
	_pump(180)
	await _shot("wave_a")
	_pump(170)
	await _shot("wave_b")
	App.kill_board()
	if made_profile:
		App.profile_mgr.delete_profile("CaptureWave")
		App.player_info = null

func _dump(board: Board, frame: int) -> void:
	var parts: Array = [Tod.rng.state, board.main_counter, board.sun_money]
	for z in board.zombies:
		if not z.dead:
			var r: Reanimation = z.body_reanim
			parts.append([z.zombie_type, z.row, snappedf(z.pos_x, 0.0001), z.body_health, z.helm_health, z.shield_health, z.zombie_phase, z.is_eating, z.mind_controlled, snappedf(r.anim_time, 0.00001) if r else -1.0, r.anim_rate if r else 0.0])
	for p in board.plants:
		if not p.dead:
			parts.append([p.seed_type, p.plant_col, p.row, p.plant_health])
	var cnt := 0
	for pr in board.projectiles:
		if not pr.dead:
			cnt += 1
	parts.append(cnt)
	print("DUMP %d %d" % [frame, hash(parts)])
	if OS.get_cmdline_user_args().has("verbose"):
		for x in parts:
			print("D%d %s" % [frame, str(x)])
