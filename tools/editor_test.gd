extends Node
## End-to-end check for the level editor:
##   godot --headless --path . res://tools/editor_test.tscn
## Builds a level with custom lanes, a custom plant, a custom zombie and a script, saves it,
## exports and re-imports it, drives every editor tab, then plays it and reports what actually
## happened on the board. Any SCRIPT ERROR in the log is a failure, as is any "FAIL:" line.

const TEST_PROFILE := "Editortest"

var failures := 0

func _ready() -> void:
	# App's own _process also ticks; stop it so this script controls the update count.
	App.set_process(false)
	await get_tree().process_frame
	_run()
	print("=== %s ===" % ("ALL CHECKS PASSED" if failures == 0 else "%d CHECK(S) FAILED" % failures))
	get_tree().quit(1 if failures > 0 else 0)

func fail(msg: String) -> void:
	failures += 1
	print("FAIL: ", msg)

func check(cond: bool, msg: String) -> void:
	print(("  ok   " if cond else "  ---  "), msg)
	if not cond:
		failures += 1

func _pump(updates: int) -> void:
	for i in updates:
		App._run_loading_tasks()
		App.update_frames()
		if i % 5 == 0:
			App._draw_frame()

## Moves the mouse over the whole screen so hover, tooltip and hit-test code runs for every widget.
func _sweep() -> void:
	var wm: WidgetManager = App.widget_manager
	for py in range(10, PvZ.BOARD_HEIGHT, 55):
		for px in range(10, PvZ.BOARD_WIDTH, 55):
			wm.on_mouse_move(px, py)
		_pump(1)
	wm.on_mouse_move(PvZ.BOARD_WIDTH / 2, PvZ.BOARD_HEIGHT / 2)

func _step(title: String) -> void:
	print("--- ", title)

# ================================================================
func _run() -> void:
	_step("loading")
	var guard := 0
	while not App.loading_thread_completed and guard < 20000:
		_pump(10)
		guard += 10
	if App.player_info == null:
		App.player_info = App.profile_mgr.add_profile(TEST_PROFILE)
	App.loading_completed()
	_pump(60)

	_step("building a level")
	var level := _build_level()
	check(CustomLevels.save_level(level), "level saves")
	check(CustomLevels.exists(level.id), "level.json exists on disk")

	_step("round trip through JSON")
	var again := LevelDef.from_json(level.to_json())
	check(again != null, "re-parses")
	if again != null:
		check(again.level_name == level.level_name, "name survives")
		check(again.waves.size() == level.waves.size(), "waves survive")
		check(again.lane_type(2) == PvZ.PLANTROW_POOL, "lane rules survive")
		check(again.lane_type(4) == PvZ.PLANTROW_HIGH_GROUND, "high ground lane survives")
		check(again.custom_plants.size() == 1, "custom plant survives")
		check(again.custom_zombies.size() == 1, "custom zombie survives")
		check((again.script_data.get("stacks", []) as Array).size() == 2, "scripts survive")

	_step("export and import")
	var exported := CustomLevels.export_level(level.id)
	check(exported != "", "exports to a file")
	if exported != "":
		var imported_id := CustomLevels.import_level(exported)
		check(imported_id != "", "imports again")
		if imported_id != "":
			var imported := CustomLevels.load_level(imported_id)
			check(imported != null and imported.waves.size() == level.waves.size(), "imported copy matches")
			CustomLevels.delete_level(imported_id)

	_step("editor screen")
	App.show_level_editor(level.id)
	_pump(30)
	check(App.editor_screen != null, "editor opens")
	if App.editor_screen != null:
		for t in EditorScreen.TABS:
			App.editor_screen.set_tab(int(t.id))
			_pump(10)
			_sweep()
			check(App.editor_screen.panel != null, "tab \"%s\" builds and draws" % str(t.name))
		App.editor_screen.set_tab(EditorScreen.TAB_LAWN)
		_pump(5)
		var lawn := App.editor_screen.panel as PanelLawn
		lawn.tool = 1                      # the "Water" lane tool
		lawn.apply_tool(3, 1, false)
		check(App.editor_screen.level.lane_type(1) == PvZ.PLANTROW_POOL, "painting a lane works")
		lawn.tool = 0
		lawn.apply_tool(3, 1, false)
		check(App.editor_screen.level.lane_type(1) == PvZ.PLANTROW_NORMAL, "painting it back works")
		check(App.editor_screen.validate() == "", "level validates: \"%s\"" % App.editor_screen.validate())
		App.editor_screen.save_level(true)

	_step("playing it")
	App.play_custom_level(CustomLevels.load_level(level.id), false)
	_pump(20)
	check(App.board != null, "board created")
	check(CustomRuntime.active != null, "runtime installed")
	if App.board == null or CustomRuntime.active == null:
		return
	var b: Board = App.board
	check(b.num_waves == level.waves.size(), "board has %d waves" % level.waves.size())
	check(b.plant_row[2] == PvZ.PLANTROW_POOL, "lane 3 counts as water on the board")
	check(b.grid_square_type[0][4] == PvZ.GRIDSQUARE_HIGH_GROUND, "lane 5 counts as high ground")
	check(b.grid_square_type[0][5] == PvZ.GRIDSQUARE_GRASS, "lane 6 counts as ground (not blocked)")
	check(b.stage_has_pool(), "the board knows it has water lanes")
	check(not b.stage_draws_pool_water(), "but the water overlay stays off for a custom background")
	check(not b.stage_uses_pool_metrics(), "and the lanes keep grass spacing")
	check(b.sun_money == level.start_sun, "starting sun is %d" % level.start_sun)
	check(b.seed_bank.num_packets == 3, "the preset seed bank has 3 packets")

	# skip the intro and start the level for real
	b.cut_scene.cancel_intro()
	_pump(20)
	App.start_playing()
	_pump(30)
	check(App.game_scene == PvZ.SCENE_PLAYING, "level is playing")
	check(b.plants.size() >= 2, "preset plants placed (%d on the lawn)" % b.plants.size())

	var custom_seed := CustomDefs.seed_type_for_cid(0)
	check(custom_seed != PvZ.SEED_NONE, "custom plant got its own seed type")
	if custom_seed != PvZ.SEED_NONE:
		check(Plant.get_cost(custom_seed) == 175, "custom plant costs what the editor said (%d)" % Plant.get_cost(custom_seed))
		var planted := b.add_plant(1, 0, custom_seed)
		check(planted != null, "custom plant can be planted")
		if planted != null:
			check(planted.seed_type == PvZ.SEED_SNOWPEA, "it behaves like its template")
			check(planted.custom_seed == custom_seed, "it keeps its custom identity")
			check(planted.plant_health == 450, "it uses the health the editor set (%d)" % planted.plant_health)

	var seen_custom_zombie := false
	var custom_health := 0
	for i in 3000:
		_pump(1)
		for z in b.zombies:
			if not z.dead and z.custom_id == 0:
				seen_custom_zombie = true
				custom_health = maxi(custom_health, z.body_max_health)
	check(b.total_spawned_waves >= 3, "waves keep coming (%d of 4 spawned)" % b.total_spawned_waves)
	check(seen_custom_zombie, "the custom zombie spawned")
	check(custom_health == 900, "the custom zombie uses the health the editor set (%d)" % custom_health)
	var spawned = CustomRuntime.active.machine.vars.get("spawned", 0)
	check(float(spawned) > 0.0, "the script ran (spawned = %s)" % str(spawned))

	_step("leaving")
	App.finish_custom_level()
	_pump(30)
	check(CustomRuntime.active == null, "runtime unloaded")
	check(LawnDefs.PLANT_DEFS.size() == PvZ.NUM_SEED_TYPES, "plant table restored (%d)" % LawnDefs.PLANT_DEFS.size())
	check(not CustomAssets.is_active(), "custom art unloaded")
	check(App.game_selector != null, "back at the main menu")

	CustomLevels.delete_level(level.id)
	_test_scrolling()
	await _test_all_water_lanes()
	await _test_conveyor()
	await _test_chooser_custom_plant()
	await _test_custom_reanim()

## The wheel has to reach whatever list or grid is under the pointer, and the bar has to drag.
func _test_scrolling() -> void:
	_step("scrolling")
	App.show_level_editor()
	_pump(20)
	var screen: EditorScreen = App.editor_screen
	screen.set_tab(EditorScreen.TAB_ART)
	_pump(20)
	var art := screen.panel as PanelArt
	var list: EditorUi.ScrollList = art.target_list
	if list == null or list.max_scroll() == 0:
		fail("the art tab has a list long enough to scroll")
		App.kill_level_editor()
		App.show_game_selector()
		return
	var wm := App.widget_manager
	var ap := list.get_abs_pos()
	var inside_x := int(ap.x + list.width * 0.4)
	var inside_y := int(ap.y + list.height * 0.5)
	wm.on_mouse_move(inside_x, inside_y)
	_pump(2)
	check(wm.over_widget == list, "the pointer lands on the list itself")
	list.scroll = 0
	wm.on_mouse_wheel(-1)
	check(list.scroll > 0, "the wheel scrolls it down (%d)" % list.scroll)
	var down := list.scroll
	wm.on_mouse_wheel(1)
	check(list.scroll < down, "and back up (%d)" % list.scroll)

	# dragging the bar itself
	list.scroll = 0
	var bar_x := int(ap.x + list.width - 4)
	wm.on_mouse_move(bar_x, int(ap.y + 4))
	wm.on_mouse_down(bar_x, int(ap.y + 4), 1)
	check(list.bar_dragging, "pressing the bar starts a drag")
	wm.on_mouse_move(bar_x, int(ap.y + list.height - 2))
	check(list.scroll == list.max_scroll(), "dragging it to the bottom scrolls all the way (%d of %d)"
		% [list.scroll, list.max_scroll()])
	wm.on_mouse_up(bar_x, int(ap.y + list.height - 2), 1)
	check(not list.bar_dragging, "and letting go ends the drag")

	# a click in the body still selects a row rather than scrolling
	var before := list.selected
	wm.on_mouse_move(inside_x, inside_y)
	wm.on_mouse_down(inside_x, inside_y, 1)
	wm.on_mouse_up(inside_x, inside_y, 1)
	check(list.selected != before or list.count == 1, "clicking the body still picks a row")

	# and the block palette on the scripting tab
	screen.set_tab(EditorScreen.TAB_SCRIPT)
	_pump(20)
	var script_panel := screen.panel as PanelScript
	var pal: EditorUi.ScrollList = script_panel.palette_list
	if pal != null and pal.max_scroll() > 0:
		var pap := pal.get_abs_pos()
		pal.scroll = 0
		wm.on_mouse_move(int(pap.x + pal.width * 0.4), int(pap.y + pal.height * 0.5))
		_pump(2)
		wm.on_mouse_wheel(-1)
		check(pal.scroll > 0, "the block palette scrolls too (%d)" % pal.scroll)
	wm.on_mouse_move(-100, -100)
	App.kill_level_editor()
	App.show_game_selector()
	_pump(20)

## An all-water lawn with a land zombie in its waves: nothing may end up in a lane the level does
## not have, and the whole lawn being blocked has to mean no zombies at all rather than row 5.
func _test_all_water_lanes() -> void:
	_step("a lawn with nowhere for a land zombie")
	var l := LevelDef.new()
	l.id = CustomLevels.unique_id("editor self test water")
	l.level_name = "All Water"
	l.geometry = LevelDef.GEOM_POOL
	l.row_type = [PvZ.PLANTROW_POOL, PvZ.PLANTROW_POOL, PvZ.PLANTROW_POOL,
		PvZ.PLANTROW_POOL, PvZ.PLANTROW_DIRT, PvZ.PLANTROW_DIRT]
	l.pool_water = true
	l.seed_mode = LevelDef.SEEDS_PRESET
	l.preset_seeds = [PvZ.SEED_LILYPAD, PvZ.SEED_PEASHOOTER]
	var w := LevelDef.new_wave(false)
	w.entries = [{"zombie": PvZ.ZOMBIE_NORMAL, "custom": -1, "count": 6, "row": -1}]
	w.delay = 100
	l.waves = [w]
	CustomLevels.save_level(l)

	App.play_custom_level(CustomLevels.load_level(l.id), false)
	_pump(20)
	var b: Board = App.board
	if b == null:
		fail("all-water board created")
		return
	check(not b.row_can_have_zombies(4), "the blocked lane 5 takes no zombies")
	check(not b.row_can_have_zombies(5), "the blocked lane 6 takes no zombies")
	b.cut_scene.cancel_intro()
	_pump(20)
	App.start_playing()
	var bad := 0
	var total := 0
	for i in 1200:
		_pump(1)
		for z in b.zombies:
			if z.dead:
				continue
			total += 1
			if not b.row_can_have_zombies(z.row):
				bad += 1
	check(total > 0, "zombies did spawn (%d seen)" % total)
	check(bad == 0, "none of them landed in a lane the level does not have (%d bad)" % bad)
	App.finish_custom_level()
	_pump(20)
	CustomLevels.delete_level(l.id)

	# and with every lane blocked there is simply nowhere to put one
	_step("a lawn with no lanes at all")
	l = LevelDef.new()
	l.id = CustomLevels.unique_id("editor self test blocked")
	l.level_name = "No Lanes"
	l.row_type = [PvZ.PLANTROW_DIRT, PvZ.PLANTROW_DIRT, PvZ.PLANTROW_DIRT,
		PvZ.PLANTROW_DIRT, PvZ.PLANTROW_DIRT, PvZ.PLANTROW_DIRT]
	l.seed_mode = LevelDef.SEEDS_NONE
	l.can_lose = false
	var w2 := LevelDef.new_wave(false)
	w2.entries = [{"zombie": PvZ.ZOMBIE_NORMAL, "custom": -1, "count": 4, "row": -1}]
	w2.delay = 100
	l.waves = [w2]
	CustomLevels.save_level(l)
	App.play_custom_level(CustomLevels.load_level(l.id), false)
	_pump(20)
	b = App.board
	if b == null:
		fail("blocked board created")
		return
	check(b.pick_row_for_new_zombie(PvZ.ZOMBIE_NORMAL) == -1, "picking a row gives up instead of guessing")
	check(b.add_zombie_in_row(PvZ.ZOMBIE_NORMAL, -1, 0) == null, "and adding one in row -1 is refused")
	b.cut_scene.cancel_intro()
	_pump(20)
	App.start_playing()
	_pump(600)
	var alive := 0
	for z in b.zombies:
		if not z.dead:
			alive += 1
	check(alive == 0, "no zombies were forced onto the lawn (%d alive)" % alive)
	App.finish_custom_level()
	_pump(20)
	CustomLevels.delete_level(l.id)

## A custom zombie that brings its own .reanim has to actually wear it on the lawn, not fall back
## to whatever its base type uses.
func _test_custom_reanim() -> void:
	_step("a custom zombie's own reanim")
	var dir := "user://editor_test_art"
	DirAccess.make_dir_recursive_absolute(dir)
	var src := dir + "/TestBrute.reanim"
	var f := FileAccess.open(src, FileAccess.WRITE)
	if f == null:
		fail("wrote a test .reanim")
		return
	f.store_string("""<?xml version="1.0"?>
<fps>12</fps>
<track><name>test_marker_body</name>
<t><x>0</x><y>0</y><sx>1</sx><sy>1</sy><a>1</a><i>IMAGE_REANIM_ZOMBIE_BODY</i></t>
<t><x>0</x><y>0</y></t>
</track>
<track><name>anim_walk</name>
<t><f>0</f></t>
<t><f>-1</f></t>
</track>
""")
	f.close()

	var l := LevelDef.new()
	l.id = CustomLevels.unique_id("editor self test reanim")
	l.level_name = "Reskin Level"
	l.seed_mode = LevelDef.SEEDS_NONE
	l.can_lose = false
	var key := CustomLevels.import_asset(l, ProjectSettings.globalize_path(src), "reanim")
	check(key != "", "the .reanim imported into the level (%s)" % key)
	var zombie := CustomDefs.default_zombie(0)
	zombie["name"] = "Marker Brute"
	zombie["base"] = PvZ.ZOMBIE_NORMAL
	zombie["reanim"] = key
	l.custom_zombies = [zombie]
	var w := LevelDef.new_wave(false)
	w.entries = [{"zombie": PvZ.ZOMBIE_NORMAL, "custom": 0, "count": 2, "row": -1}]
	w.delay = 100
	l.waves = [w]
	CustomLevels.save_level(l)

	App.play_custom_level(CustomLevels.load_level(l.id), false)
	_pump(20)
	var b: Board = App.board
	if b == null:
		fail("reskin board created")
		return
	check(CustomDefs.zombie_reanim_type(0, PvZ.REANIM_ZOMBIE) != PvZ.REANIM_ZOMBIE,
		"the level registers a reanim type of its own")
	b.cut_scene.cancel_intro()
	_pump(20)
	App.start_playing()
	var wearing := 0
	var plain := 0
	for i in 900:
		_pump(1)
		for z in b.zombies:
			if z.dead:
				continue
			var r := Zombie.rv(z.body_reanim)
			if r == null:
				continue
			if z.custom_id == 0:
				if r.track_exists("test_marker_body"):
					wearing += 1
				else:
					plain += 1
	check(wearing > 0, "the custom zombie wears its own reanim (%d frames)" % wearing)
	check(plain == 0, "and never falls back to the base zombie art (%d frames)" % plain)
	App.finish_custom_level()
	_pump(20)
	CustomLevels.delete_level(l.id)
	DirAccess.remove_absolute(src)

## A plant made in the editor has to show up in the seed chooser, already unlocked, and be
## pickable into the bank like any other packet.
func _test_chooser_custom_plant() -> void:
	_step("a custom plant in the seed chooser")
	var l := LevelDef.new()
	l.id = CustomLevels.unique_id("editor self test chooser")
	l.level_name = "Chooser Level"
	l.seed_mode = LevelDef.SEEDS_CHOOSER
	l.num_choose = 3
	var plant := CustomDefs.default_plant(0)
	plant["name"] = "Testpea"
	plant["base"] = PvZ.SEED_PEASHOOTER
	plant["cost"] = 125
	l.custom_plants = [plant]
	var w := LevelDef.new_wave(false)
	w.delay = 3000
	l.waves = [w, LevelDef.new_wave(false)]
	CustomLevels.save_level(l)

	App.play_custom_level(CustomLevels.load_level(l.id), false)
	_pump(20)
	var b: Board = App.board
	if b == null:
		fail("chooser board created")
		return
	var custom_seed := CustomDefs.seed_type_for_cid(0)
	check(custom_seed != PvZ.SEED_NONE, "the level defines a custom seed type")
	check(App.seed_type_available(custom_seed), "it counts as unlocked without owning anything")

	var guard := 0
	while App.seed_chooser_screen == null and guard < 4000:
		_pump(5)
		guard += 5
	var sc: SeedChooserScreen = App.seed_chooser_screen
	if sc == null:
		fail("the seed chooser opened")
		App.finish_custom_level()
		CustomLevels.delete_level(l.id)
		return
	check(sc.chooser_seeds.has(custom_seed), "the chooser offers it")
	check(sc.chooser_slot.has(custom_seed), "and gives it a slot in the grid")
	var pos := sc.get_seed_position_in_chooser(custom_seed)
	check(pos.x >= 0 and pos.y > 0, "with a real position (%d, %d)" % [pos.x, pos.y])
	check(not sc.seed_not_allowed_to_pick(custom_seed), "it is not greyed out")

	var before := sc.seeds_in_bank
	sc.clicked_seed_in_chooser(sc.chosen_seeds[custom_seed])
	check(sc.seeds_in_bank == before + 1, "clicking it puts it in the bank")
	sc.pick_random_seeds()
	_pump(120)
	check(App.game_scene == PvZ.SCENE_PLAYING or App.game_scene == PvZ.SCENE_LEVEL_INTRO,
		"the level carries on after picking")
	var in_bank := false
	for i in b.seed_bank.num_packets:
		if b.seed_bank.seed_packets[i].packet_type == custom_seed:
			in_bank = true
	check(in_bank, "the custom packet reached the seed bank")
	App.finish_custom_level()
	_pump(20)
	CustomLevels.delete_level(l.id)

## The conveyor has to hand out the plants the level asked for, honour the per-plant cap, and
## never offer anything that is not on the list.
func _test_conveyor() -> void:
	_step("the conveyor belt")
	var l := LevelDef.new()
	l.id = CustomLevels.unique_id("editor self test conveyor")
	l.level_name = "Belt Level"
	l.seed_mode = LevelDef.SEEDS_CONVEYOR
	l.conveyor_speed = 16          # fastest, so the test does not have to wait
	l.conveyor_seeds = [
		{"seed": PvZ.SEED_WALLNUT, "weight": 100, "max": 2},
		{"seed": PvZ.SEED_PEASHOOTER, "weight": 100, "max": 0},
	]
	var w := LevelDef.new_wave(false)
	w.entries = [{"zombie": PvZ.ZOMBIE_NORMAL, "custom": -1, "count": 1, "row": -1}]
	w.delay = 3000
	l.waves = [w]
	CustomLevels.save_level(l)

	App.play_custom_level(CustomLevels.load_level(l.id), false)
	_pump(20)
	var b: Board = App.board
	if b == null:
		fail("conveyor board created")
		return
	check(b.has_conveyor_belt_seed_bank(), "the board is on a conveyor")
	check(b.seed_bank.get_num_seeds_on_conveyor_belt() > 0, "the belt starts with packets on it (%d)"
		% b.seed_bank.get_num_seeds_on_conveyor_belt())
	b.cut_scene.cancel_intro()
	_pump(20)
	App.start_playing()
	var worst_wallnut := 0
	var off_list := 0
	var seen := {}
	for i in 2500:
		_pump(1)
		for j in b.seed_bank.get_num_seeds_on_conveyor_belt():
			var st: int = b.seed_bank.seed_packets[j].packet_type
			seen[st] = true
			if st != PvZ.SEED_WALLNUT and st != PvZ.SEED_PEASHOOTER:
				off_list += 1
		worst_wallnut = maxi(worst_wallnut, b.seed_bank.count_of_type_on_conveyor_belt(PvZ.SEED_WALLNUT))
	check(b.seed_bank.get_num_seeds_on_conveyor_belt() > 1, "the belt keeps filling (%d packets)"
		% b.seed_bank.get_num_seeds_on_conveyor_belt())
	check(seen.has(PvZ.SEED_PEASHOOTER) and seen.has(PvZ.SEED_WALLNUT), "both listed plants arrived")
	check(off_list == 0, "nothing the level did not list turned up (%d)" % off_list)
	check(worst_wallnut <= 2, "the wall-nut cap of 2 held (worst was %d)" % worst_wallnut)
	App.finish_custom_level()
	_pump(20)
	CustomLevels.delete_level(l.id)

# ================================================================
func _build_level() -> LevelDef:
	var l := LevelDef.new()
	l.id = CustomLevels.unique_id("editor self test")
	l.level_name = "Editor Self Test"
	l.author = "tools/editor_test.gd"
	l.description = "Built by the automated check."
	# A custom background with lane rules that deliberately disagree with what any built-in
	# background would draw: water in the middle of a grass-spaced lawn, and a sixth playable
	# lane. Nothing is painted for either - that is the point of the feature.
	l.bg_mode = LevelDef.BG_CUSTOM
	l.bg_image = "assets/not_shipped.png"
	l.geometry = LevelDef.GEOM_GRASS
	l.row_type = [PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_POOL,
		PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_HIGH_GROUND, PvZ.PLANTROW_NORMAL]
	l.pool_water = false
	l.bushes = false
	l.start_sun = 500
	l.seed_mode = LevelDef.SEEDS_PRESET
	l.preset_seeds = [PvZ.SEED_PEASHOOTER, PvZ.SEED_SUNFLOWER, PvZ.SEED_WALLNUT]
	l.dave_enabled = true
	l.dave_intro = ["Welcome to the test lawn!", "Mind the water lane."]

	var plant := CustomDefs.default_plant(0)
	plant["name"] = "Test Pea"
	plant["base"] = PvZ.SEED_SNOWPEA
	plant["cost"] = 175
	plant["health"] = 450
	plant["tint"] = [180, 220, 255]
	l.custom_plants = [plant]

	var zombie := CustomDefs.default_zombie(0)
	zombie["name"] = "Test Brute"
	zombie["base"] = PvZ.ZOMBIE_TRAFFIC_CONE
	zombie["health"] = 900
	zombie["speed"] = 1.4
	zombie["scale"] = 1.2
	l.custom_zombies = [zombie]

	l.waves = []
	for i in 4:
		var w := LevelDef.new_wave(i == 3)
		w.entries = [{"zombie": PvZ.ZOMBIE_NORMAL, "custom": -1, "count": 1 + i, "row": -1}]
		if i >= 1:
			(w.entries as Array).append({"zombie": PvZ.ZOMBIE_TRAFFIC_CONE, "custom": 0, "count": 1, "row": -1})
		w.delay = 120 if i == 0 else 300
		l.waves.append(w)

	l.preset_plants = [
		{"x": 0, "y": 0, "seed": PvZ.SEED_SUNFLOWER, "custom": -1, "imitater": PvZ.SEED_NONE},
		{"x": 0, "y": 1, "seed": PvZ.SEED_WALLNUT, "custom": -1, "imitater": PvZ.SEED_NONE},
	]

	# Two scripts: one counts wave starts and drops sun, one reacts to its broadcast.
	var on_wave := LevelScript.make_block("when_any_wave")
	on_wave["body"] = [
		_block("change_var", {"name": "spawned", "value": 1}),
		_block("add_sun", {"amount": 25}),
		_block("broadcast", {"event": "wave_started"}),
	]
	var on_event := LevelScript.make_block("when_event")
	(on_event["args"] as Dictionary)["event"] = "wave_started"
	on_event["body"] = [
		_block("if", {"cond": _block("gt", {"a": _block("get_var", {"name": "spawned"}), "b": 2})},
			[_block("message", {"text": "Halfway there!"})]),
	]
	l.script_data = {"stacks": [on_wave, on_event], "vars": {"spawned": 0}}
	return l

func _block(op: String, args: Dictionary, body: Array = []) -> Dictionary:
	var b := LevelScript.make_block(op)
	for k in args:
		(b["args"] as Dictionary)[k] = args[k]
	if not body.is_empty():
		b["body"] = body
	return b
