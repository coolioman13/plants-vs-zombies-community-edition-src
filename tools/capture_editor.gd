extends Node
## Windowed screenshot pass over the level editor, for eyeballing the layout.
## godot --path . res://tools/capture_editor.tscn -- <output_dir>

var out_dir := "user://captures"
var level_id := ""

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

## The cut scene only advances on a board that has drawn, so keep drawing while we pump.
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
	if App.player_info == null:
		App.player_info = App.profile_mgr.add_profile("Smoketest")
	App.widget_manager.on_mouse_move(-100, -100)
	App.loading_completed()
	_pump(400)
	await _shot("00_main_menu")

	_make_demo_level()
	App.kill_game_selector()
	App.show_level_editor(level_id)
	_pump(60)
	var n := 1
	for t in EditorScreen.TABS:
		App.editor_screen.set_tab(int(t.id))
		_pump(40)
		await _shot("%02d_%s" % [n, str(t.name).to_lower().replace(" ", "_").replace("&", "and")])
		n += 1

	# the plant picker overlay on the lawn tab
	App.editor_screen.set_tab(EditorScreen.TAB_LAWN)
	_pump(20)
	var lawn := App.editor_screen.panel as PanelLawn
	lawn.picking_plant = true
	lawn.rebuild()
	_pump(20)
	await _shot("%02d_lawn_plant_picker" % n)
	n += 1

	# the zombie picker on the waves tab
	App.editor_screen.set_tab(EditorScreen.TAB_WAVES)
	_pump(20)
	var waves := App.editor_screen.panel as PanelWaves
	waves.picking = true
	waves.rebuild()
	_pump(20)
	await _shot("%02d_waves_zombie_picker" % n)
	n += 1

	# and the level actually running: skip the intro but let the cut scene pan the board back
	# itself, exactly as it does for a player who clicks through it
	App.play_custom_level(CustomLevels.load_level(level_id), false)
	_pump(30)
	App.board.cut_scene.cancel_intro()
	var picked := false
	for i in 400:
		_pump(5)
		if not picked and App.seed_chooser_screen != null:
			picked = true
			# the chooser has to show this level's own plants, so grab it before picking
			App.seed_chooser_screen.scroll_position = App.seed_chooser_screen.max_scroll_position
			_pump(10)
			await _shot("%02d_chooser" % n)
			n += 1
			App.seed_chooser_screen.pick_random_seeds()
		if App.game_scene == PvZ.SCENE_PLAYING:
			break
	_pump(900)
	await _shot("%02d_playing" % n)
	App.finish_custom_level()
	_pump(20)
	CustomLevels.delete_level(level_id)
	n += 1
	await _shot_conveyor("%02d_conveyor_level" % n)

## A second, tiny level whose seed bank is a conveyor belt, so the belt is visible in a screenshot.
func _shot_conveyor(name: String) -> void:
	var l := LevelDef.new()
	l.id = CustomLevels.unique_id("editor screenshot conveyor")
	l.level_name = "Belt Drive"
	l.author = App.player_info.name
	l.seed_mode = LevelDef.SEEDS_CONVEYOR
	l.conveyor_speed = 10
	l.conveyor_seeds = [
		{"seed": PvZ.SEED_PEASHOOTER, "weight": 100, "max": 0},
		{"seed": PvZ.SEED_WALLNUT, "weight": 60, "max": 2},
		{"seed": PvZ.SEED_CHERRYBOMB, "weight": 40, "max": 1},
		{"seed": PvZ.SEED_SUNFLOWER, "weight": 80, "max": 0},
	]
	var w := LevelDef.new_wave(false)
	w.entries = [{"zombie": PvZ.ZOMBIE_NORMAL, "custom": -1, "count": 3, "row": -1}]
	w.delay = 600
	var w2 := LevelDef.new_wave(true)
	w2.entries = [{"zombie": PvZ.ZOMBIE_TRAFFIC_CONE, "custom": -1, "count": 4, "row": -1}]
	l.waves = [w, w2]
	CustomLevels.save_level(l)
	App.play_custom_level(CustomLevels.load_level(l.id), false)
	_pump(30)
	App.board.cut_scene.cancel_intro()
	for i in 400:
		_pump(5)
		if App.game_scene == PvZ.SCENE_PLAYING:
			break
	_pump(600)
	await _shot(name)
	App.finish_custom_level()
	_pump(20)
	CustomLevels.delete_level(l.id)

## A level that shows the features off: custom lanes on a stock background, a custom plant and
## zombie, dialogue, a boss and a script.
func _make_demo_level() -> void:
	var l := LevelDef.new()
	l.id = CustomLevels.unique_id("editor screenshot demo")
	level_id = l.id
	l.level_name = "Backyard Breach"
	l.author = App.player_info.name
	l.description = "A demo level built for the editor screenshots."
	l.bg_builtin = PvZ.BACKGROUND_3_POOL
	l.geometry = LevelDef.GEOM_POOL
	l.row_type = [PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_POOL,
		PvZ.PLANTROW_POOL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL]
	l.pool_water = true
	l.start_sun = 250
	l.dave_enabled = true
	l.dave_intro = ["They're coming through the pool!", "Take the sea-shrooms, kid. {HANDING}"]
	l.dave_wave_lines = [{"wave": 4, "text": "Here comes the big one!"}]
	l.boss["enabled"] = true
	l.boss["health"] = 25000

	var plant := CustomDefs.default_plant(0)
	plant["name"] = "Frostpea"
	plant["base"] = PvZ.SEED_SNOWPEA
	plant["cost"] = 175
	plant["health"] = 400
	plant["tint"] = [170, 215, 255]
	l.custom_plants = [plant]

	var zombie := CustomDefs.default_zombie(0)
	zombie["name"] = "Tide Brute"
	zombie["base"] = PvZ.ZOMBIE_SNORKEL
	zombie["health"] = 800
	zombie["scale"] = 1.15
	zombie["tint"] = [140, 200, 220]
	l.custom_zombies = [zombie]

	l.waves = []
	for i in 8:
		var w := LevelDef.new_wave(i == 4 or i == 7)
		w.entries = [{"zombie": PvZ.ZOMBIE_NORMAL, "custom": -1, "count": 1 + i, "row": -1}]
		if i >= 2:
			(w.entries as Array).append({"zombie": PvZ.ZOMBIE_TRAFFIC_CONE, "custom": -1, "count": 1 + Tod.idiv(i, 2), "row": -1})
		if i >= 3:
			(w.entries as Array).append({"zombie": PvZ.ZOMBIE_SNORKEL, "custom": 0, "count": 1, "row": -1})
		w.delay = 300 if i == 0 else 500
		l.waves.append(w)

	l.preset_plants = [
		{"x": 0, "y": 0, "seed": PvZ.SEED_SUNFLOWER, "custom": -1, "imitater": PvZ.SEED_NONE},
		{"x": 0, "y": 1, "seed": PvZ.SEED_SUNFLOWER, "custom": -1, "imitater": PvZ.SEED_NONE},
		{"x": 1, "y": 0, "seed": PvZ.SEED_PEASHOOTER, "custom": -1, "imitater": PvZ.SEED_NONE},
	]

	var on_wave := LevelScript.make_block("when_any_wave")
	on_wave["body"] = [
		_block("change_var", {"name": "waves seen", "value": 1}),
		_block("if", {"cond": _block("gt", {"a": _block("get_var", {"name": "waves seen"}), "b": 3})},
			[_block("add_sun", {"amount": 50}),
			 _block("message", {"text": "Sun bonus!"})]),
	]
	var on_flag := LevelScript.make_block("when_flag_wave")
	on_flag["body"] = [
		_block("shake", {}),
		_block("play_sound", {"sound": "SOUND_SIREN"}),
		_block("wait", {"seconds": 2}),
		_block("spawn_zombie", {"count": 3, "zombie": PvZ.ZOMBIE_PAIL, "row": -1}),
	]
	l.script_data = {"stacks": [on_wave, on_flag], "vars": {"waves seen": 0}}
	CustomLevels.save_level(l)

func _block(op: String, args: Dictionary, body: Array = []) -> Dictionary:
	var b := LevelScript.make_block(op)
	for k in args:
		(b["args"] as Dictionary)[k] = args[k]
	if not body.is_empty():
		b["body"] = body
	return b
