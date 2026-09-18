extends Node
## Autoload "App": port of LawnApp + the SexyAppBase services the game relies on
## (fixed 100 Hz update loop, input routing, dialogs, cursor, settings, loading).

const NUM_CHALLENGE_MODES := PvZ.NUM_GAME_MODES - 1
const UPDATE_MS := 10.0

enum { CURSOR_POINTER, CURSOR_HAND, CURSOR_DRAGGING, CURSOR_TEXT, CURSOR_CIRCLE_SLASH, CURSOR_SIZEALL, CURSOR_SIZENESW,
	CURSOR_SIZENS, CURSOR_SIZENWSE, CURSOR_SIZEWE, CURSOR_WAIT, CURSOR_NONE, CURSOR_CUSTOM }

const SETTINGS_PATH := "user://settings.cfg"

# ---------------------------------------------------------------- screens / systems
var board: Board = null
var title_screen: TitleScreen = null
var game_selector: GameSelector = null
var seed_chooser_screen: SeedChooserScreen = null
var award_screen: AwardScreen = null
var credit_screen: CreditScreen = null
var challenge_screen: ChallengeScreen = null
var mini_credits_screen: MiniCreditsScreen = null
var achievement_screen: AchievementScreen = null
var quick_play_screen: QuickPlayScreen = null
## Community edition level editor (main menu > Level Editor).
var editor_screen: EditorScreen = null
var quick_level := 1
var crazy_seeds := false
var sound_system: TodFoley = null
var music: Music = null
var widget_manager: WidgetManager = null
var pool_effect: PoolEffect = null
var zen_garden: ZenGarden = null
var profile_mgr: ProfileMgr = null
var player_info: PlayerInfo = null
var achievements: Achievements = null
## Online multiplayer (community edition).
var net: NetSession = null

# ---------------------------------------------------------------- LawnApp state
var game_mode := PvZ.GAMEMODE_ADVENTURE
var game_scene := PvZ.SCENE_LOADING
var first_time_game_selector := true
var easy_planting_cheat := false
var tod_cheat_keys := false
var debug_keys_enabled := false
var close_request := false
var app_counter := 0
var crazy_dave_reanim: Reanimation = null
var crazy_dave_state := PvZ.CRAZY_DAVE_OFF
var crazy_dave_blink_counter := 0
var crazy_dave_blink_reanim: Reanimation = null
var crazy_dave_message_index := -1
## Lines a custom level wants Crazy Dave to read, addressed from CUSTOM_DAVE_BASE up.
const CUSTOM_DAVE_BASE := 900000
var custom_dave_lines: Array = []
var crazy_dave_message_text := ""
var app_rand_seed := 0
var session_id := 0
var play_time_active_session := 0
var play_time_inactive_session := 0
var board_result := PvZ.BOARDRESULT_NONE
var saw_yeti := false
var konami_check: TypingCheck
var mustache_check: TypingCheck
var moustache_check: TypingCheck
var super_mower_check: TypingCheck
var super_mower_check2: TypingCheck
var future_check: TypingCheck
var pinata_check: TypingCheck
var dance_check: TypingCheck
var daisy_check: TypingCheck
var sukhbir_check: TypingCheck
var mustache_mode := false
var super_mower_mode := false
var future_mode := false
var pinata_mode := false
var dance_mode := false
var daisy_mode := false
var sukhbir_mode := false
var trial_type := PvZ.TRIALTYPE_NONE
var debug_trial_locked := false
var mute_sounds_for_cutscene := false
var is_fast_mode := false
var playing_quickplay := false
var last_level_stats_unused_lawn_mowers := 0

# ---------------------------------------------------------------- options (QE extras default to the classic game)
var speed_modifier := 2
var auto_collect_suns := false
var auto_collect_coins := false
var zombie_healthbars := false
var plant_healthbars := false
var bank_keybinds := false
var zero_nine_bank_format := false
var custom_cursor := false
var cursor_widget: CursorWidget = null
var discord_presence := false   # stored for parity with QE; there is no Discord integration
var force_fullscreen := false
const RECON_VERSION := "QETweaks wide-v4.3"
## SexyAppBase language list: language name (file stem) -> string table, iterated in sorted order like std::map.
var languages: Dictionary = {}
var language := "english"
var language_index := 0
## No resource packs ship with the port; index -1 means "none", as in SexyAppBase.
var resource_packs: Array = []
var resource_pack := ""
var resource_pack_index := -1
var accel_3d := true
var is_windowed := true
var music_volume := 0.85
var sfx_volume := 0.85

# ---------------------------------------------------------------- SexyAppBase state
var active := true
var has_focus := true
var dialog_map: Dictionary = {}
var dialog_list: Array = []
var cursor_num := CURSOR_POINTER
var update_count := 0
var loading_thread_completed := false
var loading_failed := false
var num_loading_thread_tasks := 0
var completed_loading_thread_tasks := 0
var _loading_tasks: Array = []
var _loading_started := false
var _update_acc := 0.0
var _canvas: Node2D
var _target: RenderTarget
## Logical pixels trimmed off the right of the 1280-wide picture by the mobile view. Zero on a
## desktop window, which letterboxes the whole thing instead. The HUD that hugs the right edge
## moves in by this much so it stays on screen.
var board_view_crop := 0
var _settings := ConfigFile.new()
var _last_click_time := {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Engine.max_fps = 0
	app_rand_seed = int(Time.get_unix_time_from_system())
	Tod.rng.seed = app_rand_seed
	session_id = app_rand_seed
	_canvas = Node2D.new()
	_canvas.name = "Screen"
	add_child(_canvas)
	_target = RenderTarget.new(_canvas.get_canvas_item())
	music = Music.new()
	music.name = "Music"
	add_child(music)
	sound_system = TodFoley.new()
	sound_system.name = "TodFoley"
	add_child(sound_system)
	widget_manager = WidgetManager.new(self)
	cursor_widget = CursorWidget.new()
	widget_manager.add_widget(cursor_widget)
	profile_mgr = ProfileMgr.new()
	if OS.get_cmdline_args().has("--mobile") or OS.get_cmdline_user_args().has("mobile"):
		Platform.force_mobile = true   # preview the phone layout from a desktop build
	apply_presentation()
	get_window().size_changed.connect(update_presentation)
	net = NetSession.new()
	net.name = "Net"
	add_child(net)
	_init_app()

# ================================================================ LawnApp::Init
func _init_app() -> void:
	Res.init()
	reload_languages()
	_read_settings()
	if not languages.has(language):
		language = _sorted_language_names()[0] if not languages.is_empty() else ""
	language_index = maxi(0, _sorted_language_names().find(language))
	load_current_language()
	profile_mgr.load()
	var cur_user := str(_settings.get_value("app", "CurUser", ""))
	if player_info == null and cur_user != "":
		player_info = profile_mgr.get_profile(cur_user)
	if player_info == null:
		player_info = profile_mgr.get_any_profile()
	title_screen = TitleScreen.new()
	title_screen.resize(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	widget_manager.add_widget(title_screen)
	widget_manager.set_focus(title_screen)
	achievements = Achievements.new()
	achievements.init_achievement()
	konami_check = TypingCheck.new()
	for k in [WidgetManager.KEYCODE_UP, WidgetManager.KEYCODE_UP, WidgetManager.KEYCODE_DOWN, WidgetManager.KEYCODE_DOWN,
			WidgetManager.KEYCODE_LEFT, WidgetManager.KEYCODE_RIGHT, WidgetManager.KEYCODE_LEFT, WidgetManager.KEYCODE_RIGHT]:
		konami_check.add_key_code(k)
	konami_check.add_char("b")
	konami_check.add_char("a")
	mustache_check = TypingCheck.new("mustache")
	moustache_check = TypingCheck.new("moustache")
	super_mower_check = TypingCheck.new("trickedout")
	super_mower_check2 = TypingCheck.new("tricked out")
	future_check = TypingCheck.new("future")
	pinata_check = TypingCheck.new("pinata")
	dance_check = TypingCheck.new("dance")
	daisy_check = TypingCheck.new("daisies")
	sukhbir_check = TypingCheck.new("sukhbir")

func _read_settings() -> void:
	_settings.load(SETTINGS_PATH)
	music_volume = float(_settings.get_value("app", "MusicVolume", 0.85))
	sfx_volume = float(_settings.get_value("app", "SfxVolume", 0.85))
	accel_3d = bool(_settings.get_value("app", "Is3D", true))
	is_windowed = bool(_settings.get_value("app", "ScreenMode", true))
	speed_modifier = clampi(int(_settings.get_value("app", "SpeedModifier", 2)), PvZ.SPEED_MODIFIER_MIN, PvZ.SPEED_MODIFIER_MAX)
	auto_collect_suns = bool(_settings.get_value("app", "AutoCollectSuns", false))
	auto_collect_coins = bool(_settings.get_value("app", "AutoCollectCoins", false))
	zombie_healthbars = bool(_settings.get_value("app", "ZombieHealthbars", false))
	plant_healthbars = bool(_settings.get_value("app", "PlantHealthbars", false))
	bank_keybinds = bool(_settings.get_value("app", "BankKeybinds", false))
	language = str(_settings.get_value("app", "Language", "english"))
	custom_cursor = bool(_settings.get_value("app", "CustomCursor", false))
	tod_cheat_keys = bool(_settings.get_value("app", "DebugMode", tod_cheat_keys))
	# LawnApp::ToggleDebugMode keeps both flags in step: the cheat keys and the debug keys (menu U, board keys...).
	debug_keys_enabled = tod_cheat_keys
	zero_nine_bank_format = bool(_settings.get_value("app", "ZeroNineBankFormat", false))
	quick_level = clampi(int(_settings.get_value("app", "QE_QuickLevel", 1)), 1, 50)
	crazy_seeds = bool(_settings.get_value("app", "QE_CrazyDaveSeeds", false))
	set_music_volume(music_volume)
	set_sfx_volume(sfx_volume)
	_apply_window_mode()

func write_to_registry() -> void:
	if player_info:
		_settings.set_value("app", "CurUser", player_info.name)
		player_info.save_details()
	_settings.set_value("app", "MusicVolume", music_volume)
	_settings.set_value("app", "SfxVolume", sfx_volume)
	_settings.set_value("app", "Is3D", accel_3d)
	_settings.set_value("app", "ScreenMode", is_windowed)
	_settings.set_value("app", "SpeedModifier", speed_modifier)
	_settings.set_value("app", "AutoCollectSuns", auto_collect_suns)
	_settings.set_value("app", "AutoCollectCoins", auto_collect_coins)
	_settings.set_value("app", "ZombieHealthbars", zombie_healthbars)
	_settings.set_value("app", "PlantHealthbars", plant_healthbars)
	_settings.set_value("app", "BankKeybinds", bank_keybinds)
	_settings.set_value("app", "ZeroNineBankFormat", zero_nine_bank_format)
	_settings.set_value("app", "Language", language)
	_settings.set_value("app", "CustomCursor", custom_cursor)
	_settings.set_value("app", "DebugMode", tod_cheat_keys)
	_settings.set_value("app", "QE_QuickLevel", quick_level)
	_settings.set_value("app", "QE_CrazyDaveSeeds", crazy_seeds)
	_settings.save(SETTINGS_PATH)

func write_current_user_config() -> bool:
	if player_info:
		player_info.save_details()
	return true

func set_music_volume(v: float) -> void:
	music_volume = v
	if music:
		music.set_music_volume(v)
	if sound_system:
		sound_system.music_volume = v
		sound_system.rehookup_sound_with_music_volume()

func set_sfx_volume(v: float) -> void:
	sfx_volume = v
	if sound_system:
		sound_system.sfx_volume = v

func get_music_volume() -> float:
	return music_volume

func get_sfx_volume() -> float:
	return sfx_volume

func switch_screen_mode(want_windowed: bool, is3d: bool, _force: bool = false) -> void:
	is_windowed = want_windowed
	accel_3d = is3d
	_apply_window_mode()
	var d = get_dialog(PvZ.DIALOG_NEWOPTIONS)
	if d and d.fullscreen_checkbox:
		d.fullscreen_checkbox.set_checked(not is_windowed, false)

func _apply_window_mode() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if is_windowed:
		if DisplayServer.window_get_mode() == DisplayServer.WINDOW_MODE_FULLSCREEN:
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
	else:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)

func is_3d_accel_on() -> bool:
	return accel_3d

func is_3d_accel() -> bool:
	return accel_3d

func is_3d_accelerated() -> bool:
	return accel_3d

func is_3d_acceleration_recommended() -> bool:
	return true

# ================================================================ languages / resource packs (SexyAppBase, QE)
func _sorted_language_names() -> Array:
	var names := languages.keys()
	names.sort()
	return names

func reload_languages() -> void:
	languages.clear()
	var d := DirAccess.open("res://languages")
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".lang"):
			TodStrings.strings = {}
			if TodStrings.load_file("res://languages/" + f):
				languages[f.get_basename()] = TodStrings.strings
	TodStrings.strings = {}

func load_current_language() -> void:
	if languages.has(language):
		TodStrings.strings = languages[language]

func switch_language() -> void:
	if languages.is_empty():
		return
	language_index = (language_index + 1) % languages.size()
	language = _sorted_language_names()[language_index]
	load_current_language()

func get_resource_pack_string() -> String:
	if resource_pack_index == -1:
		return "[NO_RESOURCE_PACK]"
	return "[RESOURCE_PACK_%s]" % resource_pack.replace(" ", "_").to_upper()

func switch_resource_pack() -> void:
	if resource_packs.is_empty():
		return
	if resource_pack_index == -1:
		resource_pack_index = 0
	elif resource_pack_index < resource_packs.size() - 1:
		resource_pack_index += 1
	else:
		resource_pack_index = -1
	resource_pack = resource_packs[resource_pack_index] if resource_pack_index != -1 else ""

func reload_resource_packs() -> void:
	pass

# ================================================================ loading (LoadingThreadProc)
func _build_loading_tasks() -> void:
	_loading_tasks.clear()
	for group in ["LoadingImages", "LoadingFonts"]:
		for id in Res.get_group_resources(group):
			_loading_tasks.append([9, Callable(Res, "preload_resource").bind(id)])
	_loading_tasks.append([68, Callable(self, "_init_systems")])
	for rt in [PvZ.REANIM_PUFF, PvZ.REANIM_LAWN_MOWERED_ZOMBIE, PvZ.REANIM_READYSETPLANT, PvZ.REANIM_FINAL_WAVE, PvZ.REANIM_SUN,
			PvZ.REANIM_TEXT_FADE_ON, PvZ.REANIM_ZOMBIE, PvZ.REANIM_ZOMBIE_NEWSPAPER, PvZ.REANIM_SELECTOR_SCREEN, PvZ.REANIM_ZOMBIE_HAND]:
		_loading_tasks.append([68, Callable(ReanimTypes, "get_def").bind(rt)])
	for st in PvZ.NUM_SEED_TYPES:
		var rt: int = LawnCommon.plant_def(st)[LawnCommon.PDEF_REANIM]
		if rt >= 0:
			_loading_tasks.append([68, Callable(ReanimTypes, "get_def").bind(rt)])
	for zt in PvZ.NUM_ZOMBIE_TYPES:
		var zrt: int = LawnCommon.zombie_def(zt)[LawnCommon.ZDEF_REANIM]
		if zrt >= 0:
			_loading_tasks.append([68, Callable(ReanimTypes, "get_def").bind(zrt)])
	for id in Res.get_group_resources("LoadingSounds"):
		_loading_tasks.append([54, Callable(Res, "preload_resource").bind(id)])
	num_loading_thread_tasks = 0
	for t in _loading_tasks:
		num_loading_thread_tasks += t[0]
	completed_loading_thread_tasks = 0

## LawnApp::StartLoadingThread / LoadingThreadProc start: the loader bar group loads first.
func start_loading_thread() -> void:
	if _loading_started:
		return
	_loading_started = true
	for id in Res.get_group_resources("LoaderBar"):
		Res.preload_resource(id)
	_build_loading_tasks()
	if title_screen:
		title_screen.loader_screen_is_loaded = true

func get_loading_thread_progress() -> float:
	if loading_thread_completed:
		return 1.0
	if num_loading_thread_tasks == 0:
		return 0.0
	return minf(float(completed_loading_thread_tasks) / num_loading_thread_tasks, 0.99)

func _init_systems() -> void:
	pool_effect = PoolEffect.new()
	pool_effect.pool_effect_initialize()
	zen_garden = ZenGarden.new()

func _run_loading_tasks() -> void:
	if loading_thread_completed or title_screen == null or not title_screen.loader_screen_is_loaded:
		return
	var start := Time.get_ticks_usec()
	while not _loading_tasks.is_empty() and Time.get_ticks_usec() - start < 8000:
		var t: Array = _loading_tasks.pop_front()
		(t[1] as Callable).call()
		completed_loading_thread_tasks += t[0]
	if _loading_tasks.is_empty():
		completed_loading_thread_tasks = num_loading_thread_tasks
		loading_thread_completed = true

func loading_completed() -> void:
	if title_screen:
		widget_manager.remove_widget(title_screen)
		title_screen = null
	show_game_selector()

func fast_load(mode: int) -> void:
	if title_screen:
		widget_manager.remove_widget(title_screen)
		title_screen = null
	pre_new_game(mode, false)

# ================================================================ main loop
## Wall-clock time the simulation may use per rendered frame. When a huge wave makes updates slower than real time,
## the game slows down instead of spending ever longer catching up between redraws (which froze the screen).
const UPDATE_BUDGET_MS := 40.0

func _process(delta: float) -> void:
	_update_acc += delta * 1000.0
	if _update_acc > UPDATE_MS * 20:
		_update_acc = UPDATE_MS * 20
	var start := Time.get_ticks_usec()
	while _update_acc >= UPDATE_MS:
		_update_acc -= UPDATE_MS
		_run_loading_tasks()
		update_frames()
		if close_request:
			get_tree().quit()
			return
		if (Time.get_ticks_usec() - start) / 1000.0 >= UPDATE_BUDGET_MS:
			_update_acc = minf(_update_acc, UPDATE_MS)  # over budget: drop the backlog, draw, carry on next frame
			break
	_draw_frame()

## gSlowMo / gFastMo debug toggles (board keys 7 and 6).
var slow_mo := false
var fast_mo := false
var slow_mo_counter := 0

func toggle_slow_mo() -> void:
	slow_mo_counter = 0
	slow_mo = not slow_mo
	fast_mo = false

func toggle_fast_mo() -> void:
	slow_mo = false
	fast_mo = not fast_mo

func update_frames() -> void:
	update_presentation()
	var count := 1
	if slow_mo:
		slow_mo_counter += 1
		if slow_mo_counter < 4:
			count = 0
		else:
			slow_mo_counter = 0
	elif fast_mo:
		count = 20
	elif is_fast_mode:
		count = speed_modifier
	var online := net.match_active
	if online:
		count = 1  # online matches run at the host's pace (see NetSession.tick)
	var start := Time.get_ticks_usec()
	for i in count:
		if i > 0 and not online and (Time.get_ticks_usec() - start) / 1000.0 >= UPDATE_BUDGET_MS:
			break  # fast mode on a huge wave: skip the extra speed-up steps rather than stall the screen
		app_counter += 1
		if board and not online:
			board.process_delete_queue()
		update_count += 1
		net.tick()
		online = net.match_active
		if has_focus or net.is_active():
			widget_manager.update_frame()
		music.music_update()
		if loading_thread_completed and not online:
			EffectSystem.process_delete_queue()
		sound_system.release_finished_instances()
		check_for_game_end()
	if cursor_widget:
		# SexyAppBase::UpdateAppStep keeps the cursor widget on top of everything.
		widget_manager.bring_to_front(cursor_widget)
	_enforce_cursor()

func _draw_frame() -> void:
	_target.begin_frame()
	Graphics.reset_frame_state()
	var g := Graphics.new(_target)
	widget_manager.draw_screen(g)
	_target.end_frame()

# ================================================================ presentation
## Desktop keeps the letterboxed 1280x720 the game was drawn for. A phone or tablet fills the
## height instead, so a screen narrower than 16:9 shows less of the widescreen margins and
## everything on the lawn gets bigger - the non-widescreen look of the mobile port - while a
## landscape phone wider than 16:9 still sees the whole picture.
func apply_presentation() -> void:
	get_window().content_scale_size = Vector2i(PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	if Platform.wants_mobile_view() and Platform.is_android():
		DisplayServer.screen_set_orientation(DisplayServer.SCREEN_SENSOR_LANDSCAPE)
	update_presentation()

## On a screen narrower than 16:9 the engine fits the 1280x720 picture by width and leaves bars
## above and below it. The menus are drawn corner to corner so they need every one of those pixels,
## but the lawn has widescreen scenery to spare at the sides - so on a phone or tablet the board
## scales up until it fills those bars, trading margin the game never puts anything on for a
## bigger, clearer lawn. On a landscape phone (wider than 16:9) there are no bars and nothing
## changes. Cheap enough to re-check every frame.
func update_presentation() -> void:
	var mobile_lawn := Platform.wants_mobile_view() and board != null
	var crop := PvZ.MOBILE_VIEW_CROP if mobile_lawn else 0
	# Shrinking the box the engine fits to the window is what makes the picture bigger: 1040x720
	# scales up about 23% where 1280x720 would letterbox, which is the non-widescreen framing of
	# the mobile port. What falls off the right is street the board never puts anything on, and the
	# HUD that hugs that edge moves in with it. The engine puts content_scale_size back to the
	# project setting whenever the window resizes, so this re-asserts it rather than setting once.
	var w := get_window()
	var want := Vector2i(PvZ.BOARD_WIDTH - crop, PvZ.BOARD_HEIGHT)
	if w.content_scale_size != want:
		w.content_scale_size = want
	if crop == board_view_crop:
		return
	board_view_crop = crop
	# the lawn HUD reads the crop when it lays itself out, so move it where it already exists
	if board != null:
		board.relayout_hud()

# ================================================================ input
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT:
			if has_focus:
				has_focus = false
				widget_manager.on_lost_focus()
				lost_focus()
		NOTIFICATION_APPLICATION_FOCUS_IN:
			if not has_focus:
				has_focus = true
				widget_manager.on_got_focus()
				got_focus()
		NOTIFICATION_WM_MOUSE_EXIT:
			widget_manager.on_mouse_exit()
		NOTIFICATION_WM_CLOSE_REQUEST:
			shutdown()

func got_focus() -> void:
	pass

func lost_focus() -> void:
	if net.is_active():
		return  # online games can't be paused
	if not tod_cheat_keys and can_pause_now():
		do_pause_dialog()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var p: Vector2 = _canvas.get_global_transform_with_canvas().affine_inverse() * event.position
		if widget_manager.down_buttons != 0:
			widget_manager.on_mouse_drag(int(p.x), int(p.y))
		else:
			widget_manager.on_mouse_move(int(p.x), int(p.y))
	elif event is InputEventMouseButton:
		var p: Vector2 = _canvas.get_global_transform_with_canvas().affine_inverse() * event.position
		var mx := int(p.x)
		var my := int(p.y)
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP:
				if event.pressed:
					widget_manager.on_mouse_wheel(1)
				return
			MOUSE_BUTTON_WHEEL_DOWN:
				if event.pressed:
					widget_manager.on_mouse_wheel(-1)
				return
		var count := 1
		match event.button_index:
			MOUSE_BUTTON_LEFT: count = 2 if event.double_click else 1
			MOUSE_BUTTON_RIGHT: count = -2 if event.double_click else -1
			MOUSE_BUTTON_MIDDLE: count = 3
			_: return
		if event.pressed:
			widget_manager.on_mouse_down(mx, my, count)
		else:
			widget_manager.on_mouse_up(mx, my, count)
	elif event is InputEventKey:
		var vk := _to_vk(event.physical_keycode if event.keycode == KEY_NONE else event.keycode)
		if event.pressed:
			if event.keycode == KEY_D and event.ctrl_pressed and event.alt_pressed:
				debug_keys_enabled = not debug_keys_enabled  # SexyAppBase: Ctrl+Alt+D
			if vk != 0:
				widget_manager.on_key_down(vk)
			if event.unicode >= 32 and event.unicode != 127:
				widget_manager.on_key_char(String.chr(event.unicode))
			elif event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				widget_manager.on_key_char("
")
			elif event.keycode == KEY_ESCAPE:
				widget_manager.on_key_char(String.chr(27))
			if event.keycode == KEY_ENTER and event.alt_pressed:
				switch_screen_mode(not is_windowed, accel_3d)
		elif vk != 0:
			widget_manager.on_key_up(vk)

static func _to_vk(k: int) -> int:
	if k >= KEY_A and k <= KEY_Z:
		return k
	if k >= KEY_0 and k <= KEY_9:
		return k
	if k >= KEY_F1 and k <= KEY_F12:
		return 0x70 + (k - KEY_F1)
	match k:
		KEY_SPACE: return 0x20
		KEY_ENTER, KEY_KP_ENTER: return 0x0D
		KEY_ESCAPE: return 0x1B
		KEY_BACKSPACE: return 0x08
		KEY_TAB: return 0x09
		KEY_SHIFT: return 0x10
		KEY_CTRL: return 0x11
		KEY_ALT: return 0x12
		KEY_PAGEUP: return 0x21
		KEY_PAGEDOWN: return 0x22
		KEY_END: return 0x23
		KEY_HOME: return 0x24
		KEY_LEFT: return 0x25
		KEY_UP: return 0x26
		KEY_RIGHT: return 0x27
		KEY_DOWN: return 0x28
		KEY_INSERT: return 0x2D
		KEY_DELETE: return 0x2E
		KEY_PERIOD: return 0xBE
		KEY_COMMA: return 0xBC
		KEY_MINUS: return 0xBD
		KEY_EQUAL: return 0xBB
	return 0

# ================================================================ cursor
func set_cursor(num: int) -> void:
	cursor_num = num

func _enforce_cursor() -> void:
	if DisplayServer.get_name() == "headless":
		return
	if custom_cursor:
		# LawnApp::EnforceCursor: the in-game CursorWidget draws the pointer instead of the OS.
		if Input.mouse_mode != Input.MOUSE_MODE_HIDDEN:
			Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
		return
	match cursor_num:
		CURSOR_NONE, CURSOR_CUSTOM:
			if Input.mouse_mode != Input.MOUSE_MODE_HIDDEN:
				Input.mouse_mode = Input.MOUSE_MODE_HIDDEN
			return
		CURSOR_HAND:
			Input.set_default_cursor_shape(Input.CURSOR_POINTING_HAND)
		CURSOR_DRAGGING:
			Input.set_default_cursor_shape(Input.CURSOR_DRAG)
		CURSOR_TEXT:
			Input.set_default_cursor_shape(Input.CURSOR_IBEAM)
		CURSOR_WAIT:
			Input.set_default_cursor_shape(Input.CURSOR_WAIT)
		_:
			Input.set_default_cursor_shape(Input.CURSOR_ARROW)
	if Input.mouse_mode != Input.MOUSE_MODE_VISIBLE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

# ================================================================ dialogs (SexyAppBase)
func get_dialog(dialog_id: int) -> Dialog:
	return dialog_map.get(dialog_id)

func get_dialog_count() -> int:
	return dialog_map.size()

func add_dialog(dialog_id: int, d: Dialog) -> void:
	kill_dialog(dialog_id)
	if d.width == 0:
		var w := Tod.idiv(PvZ.BOARD_WIDTH, 2)
		d.resize(Tod.idiv(PvZ.BOARD_WIDTH - w, 2), Tod.idiv(PvZ.BOARD_HEIGHT, 5), w, d.get_preferred_height(w))
	d.id = dialog_id
	dialog_map[dialog_id] = d
	dialog_list.append(d)
	widget_manager.add_widget(d)
	if d.is_modal:
		widget_manager.add_base_modal(d)
		modal_open()

func kill_dialog(dialog_id: int) -> bool:
	if not dialog_map.has(dialog_id):
		return false
	var d: Dialog = dialog_map[dialog_id]
	if d.result == -1:
		d.result = 0
	dialog_list.erase(d)
	dialog_map.erase(dialog_id)
	widget_manager.remove_widget(d)
	if d.is_modal:
		modal_close()
		widget_manager.remove_base_modal(d)
	d.dialog_killed()
	if dialog_map.size() == 0:
		if seed_chooser_screen:
			widget_manager.set_focus(seed_chooser_screen)
		elif board:
			widget_manager.set_focus(board)
		elif game_selector:
			widget_manager.set_focus(game_selector)
		elif challenge_screen:
			widget_manager.set_focus(challenge_screen)
		elif net.screen:
			widget_manager.set_focus(net.screen)
	if board and not need_pause_game():
		board.pause(false)
	return true

func new_dialog(dialog_id: int, modal: bool, header: String, lines: String, footer: String, button_mode: int) -> Dialog:
	var d := LawnDialog.new(dialog_id, modal, header, lines, footer, button_mode)
	center_dialog(d, d.width, d.height)
	return d

func do_dialog(dialog_id: int, modal: bool, header: String, lines: String, footer: String, button_mode: int) -> Dialog:
	kill_dialog(dialog_id)
	var d := new_dialog(dialog_id, modal, TodStrings.translate(header), TodStrings.translate(lines), TodStrings.translate(footer), button_mode)
	add_dialog(dialog_id, d)
	if widget_manager.focus_widget == null:
		widget_manager.focus_widget = d
	return d

func do_dialog_delay(dialog_id: int, modal: bool, header: String, lines: String, footer: String, button_mode: int) -> Dialog:
	var d: LawnDialog = do_dialog(dialog_id, modal, header, lines, footer, button_mode)
	d.set_button_delay(30)
	return d

## LawnMessageBox. Returns the pressed button id once the dialog closes (use with await).
func lawn_message_box(dialog_id: int, header: String, lines: String, button1: String, button2: String, button_mode: int) -> int:
	var old_focus := widget_manager.focus_widget
	var d: LawnDialog = do_dialog(dialog_id, true, header, lines, button1, button_mode)
	if d.lawn_yes_button:
		d.lawn_yes_button.label = TodStrings.translate(button1)
	if d.lawn_no_button:
		d.lawn_no_button.label = TodStrings.translate(button2)
	widget_manager.set_focus(d)
	var r: int = await d.wait_for_result(true)
	widget_manager.set_focus(old_focus)
	return r

static func center_dialog(d: Widget, w: int, h: int) -> void:
	d.resize(Tod.idiv(PvZ.BOARD_WIDTH - w, 2), Tod.idiv(PvZ.BOARD_HEIGHT - h, 2), w, h)

func dialog_button_press(dialog_id: int, button_id: int) -> void:
	if button_id == Dialog.ID_YES:
		button_press(2000 + dialog_id)
	elif button_id == Dialog.ID_NO:
		button_press(3000 + dialog_id)

func dialog_button_depress(dialog_id: int, button_id: int) -> void:
	if button_id == Dialog.ID_YES:
		button_depress(2000 + dialog_id)
	elif button_id == Dialog.ID_NO:
		button_depress(3000 + dialog_id)

func need_pause_game() -> bool:
	if board and board.is_net_game():
		return false
	if dialog_list.is_empty():
		return false
	if dialog_list.size() == 1 and (dialog_list[0] as Dialog).id != PvZ.DIALOG_NEW_GAME:
		var did: int = (dialog_list[0] as Dialog).id
		if did == PvZ.DIALOG_CHOOSER_WARNING or did == PvZ.DIALOG_PURCHASE_PACKET_SLOT or did == PvZ.DIALOG_IMITATER:
			return false
	return (board == null or game_mode != PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN) and (board == null or game_mode != PvZ.GAMEMODE_TREE_OF_WISDOM)

func modal_open() -> void:
	if board and need_pause_game():
		board.pause(true)

func modal_close() -> void:
	pass

func button_press(_id: int) -> void:
	pass

func button_depress(the_id: int) -> void:
	if the_id % 10000 >= 2000 and the_id % 10000 < 3000:
		var did := the_id - 2000
		match did:
			PvZ.DIALOG_NEW_GAME:
				kill_dialog(PvZ.DIALOG_NEW_GAME)
				show_game_selector()
			PvZ.DIALOG_NEWOPTIONS:
				kill_new_options_dialog()
			PvZ.DIALOG_QUIT:
				kill_dialog(PvZ.DIALOG_QUIT)
				close_request = true
			PvZ.DIALOG_INFO, PvZ.DIALOG_PAUSED, PvZ.DIALOG_BONUS:
				kill_dialog(did)
			PvZ.DIALOG_NO_MORE_MONEY:
				kill_dialog(PvZ.DIALOG_NO_MORE_MONEY)
				board.add_sun_money(100)
			PvZ.DIALOG_CONFIRM_BACK_TO_MAIN:
				kill_dialog(PvZ.DIALOG_CONFIRM_BACK_TO_MAIN)
				board_result = PvZ.BOARDRESULT_QUIT
				board.try_to_save_game()
				do_back_to_main(true)
			PvZ.DIALOG_USERDIALOG:
				finish_user_dialog(true)
			PvZ.DIALOG_CREATEUSER:
				finish_create_user_dialog(true)
			PvZ.DIALOG_CONFIRMDELETEUSER:
				finish_confirm_delete_user_dialog(true)
			PvZ.DIALOG_RENAMEUSER:
				finish_rename_user_dialog(true)
			PvZ.DIALOG_CREATEUSERERROR, PvZ.DIALOG_RENAMEUSERERROR:
				finish_name_error(did)
			PvZ.DIALOG_CHEAT:
				finish_cheat_dialog(true)
			PvZ.DIALOG_RESTARTCONFIRM:
				finish_restart_confirm_dialog()
			PvZ.DIALOG_TIMESUP:
				kill_dialog(PvZ.DIALOG_TIMESUP)
			_:
				kill_dialog(did)
		return
	if the_id % 10000 >= 3000 and the_id < 4000:
		var did := the_id - 3000
		match did:
			PvZ.DIALOG_USERDIALOG:
				finish_user_dialog(false)
			PvZ.DIALOG_CREATEUSER:
				finish_create_user_dialog(false)
			PvZ.DIALOG_CONFIRMDELETEUSER:
				finish_confirm_delete_user_dialog(false)
			PvZ.DIALOG_RENAMEUSER:
				finish_rename_user_dialog(false)
			PvZ.DIALOG_CHEAT:
				finish_cheat_dialog(false)
			PvZ.DIALOG_TIMESUP:
				kill_dialog(PvZ.DIALOG_TIMESUP)
			_:
				kill_dialog(did)

# ================================================================ screens
func kill_board() -> void:
	kill_seed_chooser_screen()
	if board:
		board.dispose_board()
		widget_manager.remove_widget(board)
		board = null
	set_cursor(CURSOR_POINTER)

func can_pause_now() -> bool:
	if board == null:
		return false
	if seed_chooser_screen and seed_chooser_screen.mouse_visible:
		return false
	if board.board_fade_out_counter >= 0:
		return false
	if crazy_dave_state != PvZ.CRAZY_DAVE_OFF:
		return false
	if game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN or game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
		return false
	return get_dialog_count() <= 0

func pre_new_game(mode: int, look_for_saved_game: bool) -> void:
	game_mode = mode
	if look_for_saved_game and try_load_game():
		return
	SaveGame.erase_saved_game(game_mode, player_info.id)
	new_game()

func start_quick_play() -> void:
	playing_quickplay = true
	game_mode = PvZ.GAMEMODE_ADVENTURE
	new_game()

func make_new_board() -> void:
	kill_board()
	board = Board.new()
	board.resize(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	widget_manager.add_widget(board)
	widget_manager.bring_to_back(board)
	widget_manager.set_focus(board)

func start_playing() -> void:
	kill_seed_chooser_screen()
	board.start_level()
	game_scene = PvZ.SCENE_PLAYING
	if CustomRuntime.active != null:
		CustomRuntime.active.place_board_items(board)
		CustomRuntime.active.notify_level_start()

func save_file_exists() -> bool:
	return SaveGame.saved_game_exists(PvZ.GAMEMODE_ADVENTURE, player_info.id)

func try_load_game() -> bool:
	music.stop_all_music()
	if SaveGame.saved_game_exists(game_mode, player_info.id):
		make_new_board()
		if SaveGame.load_game(board, game_mode, player_info.id):
			first_time_game_selector = false
			do_continue_dialog()
			return true
		kill_board()
	return false

func new_game() -> void:
	first_time_game_selector = false
	make_new_board()
	board.init_level()
	board_result = PvZ.BOARDRESULT_NONE
	game_scene = PvZ.SCENE_LEVEL_INTRO
	show_seed_chooser_screen()
	board.cut_scene.start_level_intro()

func show_game_selector() -> void:
	kill_board()
	playing_quickplay = false
	if game_selector:
		widget_manager.remove_widget(game_selector)
	game_scene = PvZ.SCENE_MENU
	game_selector = GameSelector.new()
	game_selector.resize(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	widget_manager.add_widget(game_selector)
	widget_manager.bring_to_back(game_selector)
	widget_manager.set_focus(game_selector)

func kill_game_selector() -> void:
	if game_selector:
		widget_manager.remove_widget(game_selector)
		game_selector = null

func show_award_screen(award_type: int, show_achievements: bool) -> void:
	game_scene = PvZ.SCENE_AWARD
	award_screen = AwardScreen.new(award_type, show_achievements)
	award_screen.resize(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	widget_manager.add_widget(award_screen)
	widget_manager.bring_to_back(award_screen)
	widget_manager.set_focus(award_screen)

func kill_award_screen() -> void:
	if award_screen:
		widget_manager.remove_widget(award_screen)
		award_screen = null

func show_credit_screen() -> void:
	credit_screen = CreditScreen.new()
	credit_screen.resize(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	widget_manager.add_widget(credit_screen)
	widget_manager.bring_to_back(credit_screen)
	widget_manager.set_focus(credit_screen)

func kill_credit_screen() -> void:
	if credit_screen:
		widget_manager.remove_widget(credit_screen)
		credit_screen = null

func show_mini_credit_screen() -> void:
	game_scene = PvZ.SCENE_CREDIT
	mini_credits_screen = MiniCreditsScreen.new()
	mini_credits_screen.resize(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	widget_manager.add_widget(mini_credits_screen)
	widget_manager.bring_to_back(mini_credits_screen)
	widget_manager.set_focus(mini_credits_screen)

func kill_mini_credit_screen() -> void:
	if mini_credits_screen:
		widget_manager.remove_widget(mini_credits_screen)
		mini_credits_screen = null

func show_achievement_screen() -> void:
	if achievement_screen:
		kill_achievement_screen()
	game_scene = PvZ.SCENE_MENU
	achievement_screen = AchievementScreen.new()
	achievement_screen.resize(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT + 1)
	widget_manager.add_widget(achievement_screen)
	widget_manager.bring_to_front(achievement_screen)
	widget_manager.set_focus(achievement_screen)

func kill_achievement_screen() -> void:
	if achievement_screen:
		widget_manager.remove_widget(achievement_screen)
		achievement_screen = null

func show_quick_play_screen() -> void:
	if quick_play_screen:
		kill_quick_play_screen()
	game_scene = PvZ.SCENE_MENU
	quick_play_screen = QuickPlayScreen.new()
	quick_play_screen.resize(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	widget_manager.add_widget(quick_play_screen)
	widget_manager.bring_to_front(quick_play_screen)
	widget_manager.set_focus(quick_play_screen)

func kill_quick_play_screen() -> void:
	if quick_play_screen:
		widget_manager.remove_widget(quick_play_screen)
		quick_play_screen = null

# ---------------------------------------------------------------- level editor
func show_level_editor(level_id: String = "") -> void:
	kill_board()
	kill_game_selector()
	CustomRuntime.stop()
	playing_quickplay = false
	game_scene = PvZ.SCENE_MENU
	if editor_screen:
		widget_manager.remove_widget(editor_screen)
	editor_screen = EditorScreen.new(level_id)
	editor_screen.resize(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	widget_manager.add_widget(editor_screen)
	widget_manager.bring_to_back(editor_screen)
	widget_manager.set_focus(editor_screen)
	music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_CHOOSE_YOUR_SEEDS)

func kill_level_editor() -> void:
	if editor_screen:
		widget_manager.remove_widget(editor_screen)
		editor_screen = null

## Plays a custom level. [param from_editor] sends the player back to the editor afterwards.
func play_custom_level(level: LevelDef, from_editor: bool) -> void:
	kill_level_editor()
	kill_game_selector()
	custom_dave_lines = []
	CustomRuntime.start(level, CustomRuntime.RETURN_EDITOR if from_editor else CustomRuntime.RETURN_BROWSER)

## Tears a custom level down and returns to wherever it was started from.
func finish_custom_level() -> void:
	var rt := CustomRuntime.active
	var back_to_editor := rt != null and rt.return_to == CustomRuntime.RETURN_EDITOR
	var level_id := rt.level.id if rt != null else ""
	if rt != null:
		rt.stop_custom_music()
	music.stop_all_music()
	sound_system.cancel_paused_foley()
	kill_new_options_dialog()
	crazy_dave_die()
	custom_dave_lines = []
	kill_board()
	CustomRuntime.stop()
	playing_quickplay = false
	board_result = PvZ.BOARDRESULT_NONE
	if back_to_editor:
		show_level_editor(level_id)
	else:
		show_game_selector()

func is_ice_demo() -> bool:
	return false

func show_challenge_screen(page: int) -> void:
	game_scene = PvZ.SCENE_CHALLENGE
	challenge_screen = ChallengeScreen.new(page)
	challenge_screen.resize(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	widget_manager.add_widget(challenge_screen)
	widget_manager.bring_to_back(challenge_screen)
	widget_manager.set_focus(challenge_screen)

func do_challenge_pages_dialog() -> void:
	if challenge_screen == null:
		return
	kill_dialog(PvZ.DIALOG_CHALLENGE_PAGES)
	var d := ChallengePagesDialog.new()
	center_dialog(d, d.width, d.height)
	add_dialog(PvZ.DIALOG_CHALLENGE_PAGES, d)
	widget_manager.set_focus(d)

func kill_challenge_screen() -> void:
	if challenge_screen:
		widget_manager.remove_widget(challenge_screen)
		challenge_screen = null

func show_store_screen() -> StoreScreen:
	var s := StoreScreen.new()
	add_dialog(PvZ.DIALOG_STORE, s)
	widget_manager.set_focus(s)
	return s

func kill_store_screen() -> void:
	if get_dialog(PvZ.DIALOG_STORE):
		kill_dialog(PvZ.DIALOG_STORE)

func show_seed_chooser_screen() -> void:
	seed_chooser_screen = SeedChooserScreen.new()
	seed_chooser_screen.resize(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	widget_manager.add_widget(seed_chooser_screen)
	widget_manager.bring_to_back(seed_chooser_screen)

func kill_seed_chooser_screen() -> void:
	if seed_chooser_screen:
		widget_manager.remove_widget(seed_chooser_screen)
		seed_chooser_screen = null

func end_level() -> void:
	kill_board()
	if is_adventure_mode():
		new_game()
	first_time_game_selector = true
	make_new_board()
	board.init_level()
	board_result = PvZ.BOARDRESULT_NONE
	game_scene = PvZ.SCENE_LEVEL_INTRO
	show_seed_chooser_screen()
	board.cut_scene.start_level_intro()

func do_back_to_main(has_sound: bool = false) -> void:
	if CustomRuntime.active != null:
		finish_custom_level()
		if has_sound:
			play_sample("SOUND_BUTTONCLICK")
		return
	music.stop_all_music()
	sound_system.cancel_paused_foley()
	write_current_user_config()
	kill_new_options_dialog()
	kill_board()
	playing_quickplay = false
	show_game_selector()
	if has_sound:
		play_sample("SOUND_BUTTONCLICK")

func do_confirm_back_to_main() -> void:
	var d: LawnDialog = do_dialog(PvZ.DIALOG_CONFIRM_BACK_TO_MAIN, true, "[LEAVE_GAME]", "[LEAVE_GAME_HEADER]", "", Dialog.BUTTONS_YES_NO)
	d.lawn_yes_button.label = TodStrings.translate("[LEAVE_BUTTON]")
	d.lawn_no_button.label = TodStrings.translate("[DIALOG_BUTTON_CANCEL]")

func do_new_options(from_game_selector: bool, px: int = -1, py: int = -1) -> void:
	var d := NewOptionsDialog.new(from_game_selector, false)
	var back := Res.get_image("IMAGE_OPTIONS_MENUBACK")
	center_dialog(d, back.width, back.height)
	if px != -1 and py != -1:
		d.resize(px, py, d.width, d.height)
	add_dialog(PvZ.DIALOG_NEWOPTIONS, d)
	widget_manager.set_focus(d)

func do_advanced_options(from_game_selector: bool, px: int, py: int) -> void:
	var d := NewOptionsDialog.new(from_game_selector, true)
	var back := Res.get_image("IMAGE_OPTIONS_MENUBACK")
	center_dialog(d, back.width, back.height)
	d.resize(px, py, d.width, d.height)
	add_dialog(PvZ.DIALOG_NEWOPTIONS, d)
	widget_manager.set_focus(d)

func do_almanac_dialog(seed_type: int = PvZ.SEED_NONE, zombie_type: int = PvZ.ZOMBIE_INVALID) -> AlmanacDialog:
	var d := AlmanacDialog.new()
	add_dialog(PvZ.DIALOG_ALMANAC, d)
	widget_manager.set_focus(d)
	if seed_type != PvZ.SEED_NONE:
		d.show_plant(seed_type)
	elif zombie_type != PvZ.ZOMBIE_INVALID:
		d.show_zombie(zombie_type)
	return d

func kill_almanac_dialog() -> bool:
	if get_dialog(PvZ.DIALOG_ALMANAC):
		kill_dialog(PvZ.DIALOG_ALMANAC)
		return true
	return false

func do_continue_dialog() -> void:
	var d := ContinueDialog.new()
	center_dialog(d, d.width, d.height)
	add_dialog(PvZ.DIALOG_CONTINUE, d)

func do_pause_dialog() -> void:
	board.pause(true)
	var d: LawnDialog = do_dialog(PvZ.DIALOG_PAUSED, true, "[GAME_PAUSED]", "[GAME_PAUSED_HEADER]", "[RESUME_GAME]", Dialog.BUTTONS_FOOTER)
	d.reanimation.add_reanimation(72.0, 42.0, PvZ.REANIM_ZOMBIE_NEWSPAPER)
	d.space_after_header = 155
	d.calc_size(0, 10)
	center_dialog(d, d.width, d.height)

func do_user_dialog() -> void:
	kill_dialog(PvZ.DIALOG_USERDIALOG)
	var d := UserDialog.new()
	center_dialog(d, d.width, d.height)
	add_dialog(PvZ.DIALOG_USERDIALOG, d)
	widget_manager.set_focus(d)

func finish_user_dialog(is_yes: bool) -> void:
	var d = get_dialog(PvZ.DIALOG_USERDIALOG)
	if d:
		if is_yes:
			var p := profile_mgr.get_profile(d.get_sel_name())
			if p:
				player_info = p
				if game_selector:
					game_selector.sync_profile(true)
		kill_dialog(PvZ.DIALOG_USERDIALOG)

func do_create_user_dialog() -> void:
	kill_dialog(PvZ.DIALOG_CREATEUSER)
	var d := NewUserDialog.new(false)
	center_dialog(d, d.width, d.height)
	add_dialog(PvZ.DIALOG_CREATEUSER, d)

func finish_create_user_dialog(is_yes: bool) -> void:
	var d = get_dialog(PvZ.DIALOG_CREATEUSER)
	if d == null:
		return
	var n: String = d.get_name()
	if (is_yes and n.is_empty()) or (player_info == null and (not is_yes or n.is_empty())):
		do_dialog(PvZ.DIALOG_CREATEUSERERROR, true, "[ENTER_YOUR_NAME]", "[ENTER_NEW_USER]", "[DIALOG_BUTTON_OK]", Dialog.BUTTONS_FOOTER)
	elif not is_yes:
		kill_dialog(PvZ.DIALOG_CREATEUSER)
	else:
		var p := profile_mgr.add_profile(n)
		if p == null:
			do_dialog(PvZ.DIALOG_CREATEUSERERROR, true, "[NAME_CONFLICT]", "[ENTER_UNIQUE_PLAYER_NAME]", "[DIALOG_BUTTON_OK]", Dialog.BUTTONS_FOOTER)
		else:
			profile_mgr.save()
			player_info = p
			write_to_registry()
			kill_dialog(PvZ.DIALOG_USERDIALOG)
			kill_dialog(PvZ.DIALOG_CREATEUSER)
			if game_selector:
				game_selector.sync_profile(true)

func do_confirm_delete_user_dialog(the_name: String) -> void:
	kill_dialog(PvZ.DIALOG_CONFIRMDELETEUSER)
	do_dialog(PvZ.DIALOG_CONFIRMDELETEUSER, true, "[ARE_YOU_SURE]",
		Tod.replace_string(TodStrings.translate("[DELETE_USER_WARNING]"), "{NAME}", the_name), "", Dialog.BUTTONS_YES_NO)

func finish_confirm_delete_user_dialog(is_yes: bool) -> void:
	kill_dialog(PvZ.DIALOG_CONFIRMDELETEUSER)
	var ud = get_dialog(PvZ.DIALOG_USERDIALOG)
	if ud == null:
		return
	widget_manager.set_focus(ud)
	if not is_yes:
		return
	var cur_name := player_info.name if player_info else ""
	var sel: String = ud.get_sel_name()
	if sel == cur_name:
		player_info = null
	profile_mgr.delete_profile(sel)
	ud.finish_delete_user()
	if player_info == null:
		player_info = profile_mgr.get_profile(ud.get_sel_name())
		if player_info == null:
			player_info = profile_mgr.get_any_profile()
	profile_mgr.save()
	if player_info == null:
		do_create_user_dialog()
	if game_selector:
		game_selector.sync_profile(true)

func do_rename_user_dialog(the_name: String) -> void:
	kill_dialog(PvZ.DIALOG_RENAMEUSER)
	var d := NewUserDialog.new(true)
	center_dialog(d, d.width, d.height)
	d.set_name(the_name)
	add_dialog(PvZ.DIALOG_RENAMEUSER, d)

func finish_rename_user_dialog(is_yes: bool) -> void:
	var ud = get_dialog(PvZ.DIALOG_USERDIALOG)
	if not is_yes:
		kill_dialog(PvZ.DIALOG_RENAMEUSER)
		widget_manager.set_focus(ud)
		return
	var nd = get_dialog(PvZ.DIALOG_RENAMEUSER)
	if ud == null or nd == null:
		return
	var old_name: String = ud.get_sel_name()
	var new_name: String = nd.get_name()
	if new_name.is_empty():
		return
	var is_current := profile_mgr.get_profile(old_name) == player_info
	if not profile_mgr.rename_profile(old_name, new_name):
		do_dialog(PvZ.DIALOG_RENAMEUSERERROR, true, "[NAME_CONFLICT]", "[ENTER_UNIQUE_PLAYER_NAME]", "[DIALOG_BUTTON_OK]", Dialog.BUTTONS_FOOTER)
		return
	profile_mgr.save()
	if is_current:
		player_info = profile_mgr.get_profile(new_name)
	ud.finish_rename_user(new_name)
	kill_dialog(PvZ.DIALOG_RENAMEUSER)
	widget_manager.set_focus(ud)

func finish_name_error(dialog_id: int) -> void:
	kill_dialog(dialog_id)
	var nd = get_dialog(PvZ.DIALOG_CREATEUSER if dialog_id == PvZ.DIALOG_CREATEUSERERROR else PvZ.DIALOG_RENAMEUSER)
	if nd:
		widget_manager.set_focus(nd.name_edit_widget)

func finish_restart_confirm_dialog() -> void:
	saw_yeti = board.killed_yeti
	kill_dialog(PvZ.DIALOG_CONTINUE)
	kill_dialog(PvZ.DIALOG_RESTARTCONFIRM)
	kill_board()
	pre_new_game(game_mode, false)

func do_cheat_dialog() -> void:
	kill_dialog(PvZ.DIALOG_CHEAT)
	var d := CheatDialog.new()
	center_dialog(d, d.width, d.height)
	add_dialog(PvZ.DIALOG_CHEAT, d)

func finish_cheat_dialog(is_yes: bool) -> void:
	var d = get_dialog(PvZ.DIALOG_CHEAT)
	if d == null:
		return
	if is_yes and not d.apply_cheat():
		return
	kill_dialog(PvZ.DIALOG_CHEAT)
	if is_yes:
		music.stop_all_music()
		board_result = PvZ.BOARDRESULT_CHEAT
		pre_new_game(game_mode, false)

func do_confirm_sell_dialog(message: String) -> Dialog:
	var d: LawnDialog = do_dialog(PvZ.DIALOG_ZEN_SELL, true, "[ZEN_SELL_HEADER]", message, "", Dialog.BUTTONS_YES_NO)
	d.lawn_yes_button.label = TodStrings.translate("[DIALOG_BUTTON_YES]")
	d.lawn_no_button.label = TodStrings.translate("[DIALOG_BUTTON_NO]")
	return d

func do_confirm_purchase_dialog(message: String) -> Dialog:
	var d: LawnDialog = do_dialog(PvZ.DIALOG_STORE_PURCHASE, true, "[STORE_PURCHASE_HEADER]", message, "", Dialog.BUTTONS_YES_NO)
	d.lawn_yes_button.label = TodStrings.translate("[DIALOG_BUTTON_YES]")
	d.lawn_no_button.label = TodStrings.translate("[DIALOG_BUTTON_NO]")
	return d

func kill_new_options_dialog() -> bool:
	var d = get_dialog(PvZ.DIALOG_NEWOPTIONS)
	if d == null:
		return false
	d.apply_options()
	kill_dialog(PvZ.DIALOG_NEWOPTIONS)
	write_to_registry()
	return true

func confirm_quit() -> void:
	var d: LawnDialog = do_dialog(PvZ.DIALOG_QUIT, true, "[QUIT_HEADER]", "[QUIT_MESSAGE]", "", Dialog.BUTTONS_OK_CANCEL)
	d.lawn_yes_button.label = TodStrings.translate("[QUIT_BUTTON]")
	center_dialog(d, d.width, d.height)

func shutdown() -> void:
	if net.is_active():
		net.shutdown()
		if board and board.is_net_game():
			kill_board()
		if net._saved.has("player_info"):
			player_info = net._saved.player_info
	if board:
		board_result = PvZ.BOARDRESULT_QUIT_APP
		board.try_to_save_game()
		kill_board()
	write_current_user_config()
	write_to_registry()
	profile_mgr.save()
	get_tree().quit()

# ================================================================ end of level
func update_player_profile_for_finishing_level() -> bool:
	var unlocked := false
	if is_adventure_mode():
		if board.level == PvZ.FINAL_LEVEL:
			player_info.level = 1
			player_info.finished_adventure += 1
			if player_info.finished_adventure == 1:
				player_info.needs_message_on_game_selector = 1
		else:
			player_info.level = board.level + 1
		if not has_finished_adventure() and board.level == 34:
			player_info.needs_magic_taco_reward = 1
		var challenge_level := is_wallnut_bowling_level() or is_whack_a_zombie_level() or is_little_trouble_level() \
			or is_bungee_blitz_level() or is_stormy_night_level() or board.has_conveyor_belt_seed_bank()
		if board.background == PvZ.BACKGROUND_3_POOL and not board.peashooters_used and not challenge_level:
			get_achievement(PvZ.ACHIEVEMENT_DONT_PEA_IN_POOL)
		if board.stage_has_roof() and not board.catapults_used and not challenge_level:
			get_achievement(PvZ.ACHIEVEMENT_GROUNDED)
		if board.stage_is_night() and not board.mushrooms_used and not challenge_level:
			get_achievement(PvZ.ACHIEVEMENT_NO_FUNGUS_AMONG_US)
		if board.background == PvZ.BACKGROUND_1_DAY and board.mushrooms_n_coffee_used and not board.used_non_mushrooms and not challenge_level:
			get_achievement(PvZ.ACHIEVEMENT_GOOD_MORNING)
	elif is_survival_mode():
		if board.is_final_survival_stage():
			unlocked = not has_beaten_challenge(game_mode)
			board.survival_save_score()
			if unlocked and has_finished_adventure():
				var n := get_num_trophies(PvZ.CHALLENGE_PAGE_SURVIVAL)
				if n != 8 and n != 9:
					player_info.has_new_survival = 1
	elif is_puzzle_mode():
		unlocked = not has_beaten_challenge(game_mode)
		player_info.challenge_records[get_current_challenge_index()] += 1
		if not has_finished_adventure() and (game_mode == PvZ.GAMEMODE_SCARY_POTTER_3 or game_mode == PvZ.GAMEMODE_PUZZLE_I_ZOMBIE_3):
			unlocked = false
		if unlocked:
			if is_scary_potter_level():
				player_info.has_new_scary_potter = 1
			else:
				player_info.has_new_izombie = 1
	else:
		unlocked = not has_beaten_challenge(game_mode)
		player_info.challenge_records[get_current_challenge_index()] += 1
		if unlocked and has_finished_adventure():
			var n := get_num_trophies(PvZ.CHALLENGE_PAGE_CHALLENGE)
			if n <= 17:
				player_info.has_new_mini_game = 1
			elif n >= get_total_trophies(PvZ.CHALLENGE_PAGE_CHALLENGE):
				get_achievement(PvZ.ACHIEVEMENT_BEYOND_THE_GRAVE)
	write_current_user_config()
	return unlocked

func check_for_game_end() -> void:
	if board and board.is_net_game():
		return  # NetSession takes the players back to the lobby
	if board == null or not board.level_complete:
		return
	is_fast_mode = false
	if CustomRuntime.active != null:
		finish_custom_level()
		return
	if playing_quickplay:
		show_game_selector()
		return
	if earned_gold_trophy():
		get_achievement(PvZ.ACHIEVEMENT_NOBEL_PEAS_PRIZE)
	var unlocked := update_player_profile_for_finishing_level()
	var force_achievements := false
	for a in PvZ.NUM_ACHIEVEMENTS:
		if player_info.earned_achievements[a] and not player_info.shown_achievements[a] and Achievements.return_show_in_awards(a):
			force_achievements = true
	if is_adventure_mode():
		var lvl := board.level
		kill_board()
		if is_first_time_adventure_mode() and lvl < 50:
			show_award_screen(PvZ.AWARD_FORLEVEL, true)
		elif lvl == PvZ.FINAL_LEVEL:
			get_achievement(PvZ.ACHIEVEMENT_HOME_SECURITY)
			if player_info.finished_adventure == 1:
				show_award_screen(PvZ.AWARD_FORLEVEL, true)
			else:
				show_award_screen(PvZ.AWARD_CREDITS_ZOMBIENOTE, true)
		elif lvl == 9 or lvl == 19 or lvl == 29 or lvl == 39 or lvl == 49:
			show_award_screen(PvZ.AWARD_FORLEVEL, true)
		else:
			pre_new_game(game_mode, false)
	elif is_survival_mode():
		if board.is_final_survival_stage():
			kill_board()
			if unlocked and has_finished_adventure():
				show_award_screen(PvZ.AWARD_FORLEVEL, true)
			elif not force_achievements:
				show_challenge_screen(PvZ.CHALLENGE_PAGE_SURVIVAL)
			else:
				show_award_screen(PvZ.AWARD_ACHIEVEMENTONLY, true)
		else:
			board.challenge.survival_stage += 1
			kill_game_selector()
			board.init_survival_stage()
	elif is_puzzle_mode():
		kill_board()
		if unlocked:
			show_award_screen(PvZ.AWARD_FORLEVEL, true)
		elif not force_achievements:
			show_challenge_screen(PvZ.CHALLENGE_PAGE_PUZZLE)
		else:
			show_award_screen(PvZ.AWARD_ACHIEVEMENTONLY, true)
	else:
		kill_board()
		if unlocked and has_finished_adventure():
			show_award_screen(PvZ.AWARD_FORLEVEL, true)
		elif not force_achievements:
			show_challenge_screen(PvZ.CHALLENGE_PAGE_CHALLENGE)
		else:
			show_award_screen(PvZ.AWARD_ACHIEVEMENTONLY, true)

# ================================================================ sound helpers
func play_foley(foley: int) -> void:
	if not mute_sounds_for_cutscene:
		sound_system.play_foley(foley)

func play_foley_pitch(foley: int, pitch: float) -> void:
	if not mute_sounds_for_cutscene:
		sound_system.play_foley_pitch(foley, pitch)

func play_sample(sound_id: String) -> void:
	if not mute_sounds_for_cutscene:
		sound_system.play_sample(sound_id)

func play_sample_pitch(sound_id: String, pitch: float) -> void:
	if not mute_sounds_for_cutscene:
		sound_system.play_sample_pitch(sound_id, pitch)

# ================================================================ effect helpers
func add_reanimation(px: float, py: float, order: int, rt: int) -> Reanimation:
	return EffectSystem.alloc_reanimation(px, py, order, rt)

func add_tod_particle(px: float, py: float, order: int, effect: int) -> TodParticleSystem:
	return EffectSystem.alloc_particle_system(px, py, order, effect)

func remove_reanimation(r: Reanimation) -> void:
	if r != null and not r.freed:
		r.die()

func remove_particle(p: TodParticleSystem) -> void:
	if p != null and not p.freed:
		p.particle_system_die()

# ================================================================ mode queries
static func get_stage_string(lvl: int) -> String:
	var area := clampi(Tod.idiv(lvl - 1, PvZ.LEVELS_PER_AREA) + 1, 1, PvZ.ADVENTURE_AREAS + 1)
	var sub := lvl - (area - 1) * PvZ.LEVELS_PER_AREA
	return " %d-%d" % [area, sub]

func is_adventure_mode() -> bool: return game_mode == PvZ.GAMEMODE_ADVENTURE
func is_survival_mode() -> bool: return game_mode >= PvZ.GAMEMODE_SURVIVAL_NORMAL_STAGE_1 and game_mode <= PvZ.GAMEMODE_SURVIVAL_ENDLESS_STAGE_5
func is_puzzle_mode() -> bool: return game_mode >= PvZ.GAMEMODE_SCARY_POTTER_1 and game_mode <= PvZ.GAMEMODE_PUZZLE_I_ZOMBIE_ENDLESS
func is_challenge_mode() -> bool: return not is_adventure_mode() and not is_puzzle_mode() and not is_survival_mode()

static func is_survival_normal(mode: int) -> bool:
	var l := mode - PvZ.GAMEMODE_SURVIVAL_NORMAL_STAGE_1
	return l >= 0 and l <= 4

static func is_survival_hard(mode: int) -> bool:
	var l := mode - PvZ.GAMEMODE_SURVIVAL_HARD_STAGE_1
	return l >= 0 and l <= 4

static func is_survival_endless(mode: int) -> bool:
	var l := mode - PvZ.GAMEMODE_SURVIVAL_ENDLESS_STAGE_1
	return l >= 0 and l <= 4

static func is_endless_scary_potter(mode: int) -> bool: return mode == PvZ.GAMEMODE_SCARY_POTTER_ENDLESS
static func is_endless_izombie(mode: int) -> bool: return mode == PvZ.GAMEMODE_PUZZLE_I_ZOMBIE_ENDLESS

func is_continuous_challenge() -> bool:
	return is_art_challenge() or is_slot_machine_level() or is_final_boss_level() or game_mode == PvZ.GAMEMODE_CHALLENGE_BEGHOULED \
		or game_mode == PvZ.GAMEMODE_UPSELL or game_mode == PvZ.GAMEMODE_INTRO or game_mode == PvZ.GAMEMODE_CHALLENGE_BEGHOULED_TWIST

func is_art_challenge() -> bool:
	return board != null and (game_mode == PvZ.GAMEMODE_CHALLENGE_ART_CHALLENGE_WALLNUT or game_mode == PvZ.GAMEMODE_CHALLENGE_ART_CHALLENGE_SUNFLOWER \
		or game_mode == PvZ.GAMEMODE_CHALLENGE_SEEING_STARS)

func is_squirrel_level() -> bool: return board != null and game_mode == PvZ.GAMEMODE_CHALLENGE_SQUIRREL
func is_izombie_level() -> bool: return board != null and game_mode >= PvZ.GAMEMODE_PUZZLE_I_ZOMBIE_1 and game_mode <= PvZ.GAMEMODE_PUZZLE_I_ZOMBIE_ENDLESS
func is_shovel_level() -> bool: return board != null and game_mode == PvZ.GAMEMODE_CHALLENGE_SHOVEL
func is_slot_machine_level() -> bool: return board != null and game_mode == PvZ.GAMEMODE_CHALLENGE_SLOT_MACHINE

func is_wallnut_bowling_level() -> bool:
	if board == null:
		return false
	if game_mode == PvZ.GAMEMODE_CHALLENGE_WALLNUT_BOWLING or game_mode == PvZ.GAMEMODE_CHALLENGE_WALLNUT_BOWLING_2:
		return true
	return is_adventure_mode() and board.level == 5

func is_whack_a_zombie_level() -> bool:
	if board == null:
		return false
	if game_mode == PvZ.GAMEMODE_CHALLENGE_WHACK_A_ZOMBIE:
		return true
	return is_adventure_mode() and board.level == 15

func is_little_trouble_level() -> bool:
	if board == null:
		return false
	if game_mode == PvZ.GAMEMODE_CHALLENGE_LITTLE_TROUBLE:
		return true
	return is_adventure_mode() and board.level == 25

func is_scary_potter_level() -> bool:
	if game_mode >= PvZ.GAMEMODE_SCARY_POTTER_1 and game_mode <= PvZ.GAMEMODE_SCARY_POTTER_ENDLESS:
		return true
	if board == null:
		return false
	return is_adventure_mode() and board.level == 35

func is_stormy_night_level() -> bool:
	if board == null:
		return false
	if game_mode == PvZ.GAMEMODE_CHALLENGE_STORMY_NIGHT:
		return true
	return is_adventure_mode() and board.level == 40

func is_bungee_blitz_level() -> bool:
	if board == null:
		return false
	if game_mode == PvZ.GAMEMODE_CHALLENGE_BUNGEE_BLITZ:
		return true
	return is_adventure_mode() and board.level == 45

func is_mini_boss_level() -> bool:
	if board == null or not is_adventure_mode():
		return false
	return board.level == 10 or board.level == 20 or board.level == 30

func is_final_boss_level() -> bool:
	if board == null:
		return false
	if game_mode == PvZ.GAMEMODE_CHALLENGE_FINAL_BOSS:
		return true
	return is_adventure_mode() and board.level == 50

func is_challenge_without_seed_bank() -> bool:
	return game_mode == PvZ.GAMEMODE_CHALLENGE_RAINING_SEEDS or game_mode == PvZ.GAMEMODE_UPSELL or game_mode == PvZ.GAMEMODE_INTRO \
		or is_whack_a_zombie_level() or is_squirrel_level() or is_scary_potter_level() or game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN \
		or game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM

func can_show_seed_bank_after_sun() -> bool:
	return is_challenge_without_seed_bank() and (is_scary_potter_level() or is_whack_a_zombie_level())

func is_night() -> bool:
	if player_info == null:
		return false
	if playing_quickplay:
		return (quick_level >= 11 and quick_level <= 20) or (quick_level >= 31 and quick_level <= 40) or quick_level == 50
	var l := player_info.level
	return (l >= 11 and l <= 20) or (l >= 31 and l <= 40) or l == 50

func get_current_challenge_index() -> int:
	return game_mode - PvZ.GAMEMODE_SURVIVAL_NORMAL_STAGE_1

func get_current_challenge_def() -> Array:
	return ChallengeDefs.get_def(get_current_challenge_index())

func get_current_challenge_name() -> String:
	return TodStrings.translate(get_current_challenge_def()[ChallengeDefs.NAME])

func get_potted_plant_by_index(index: int):
	return player_info.potted_plants[index]

static func get_award_seed_for_level(lvl: int) -> int:
	var area := Tod.idiv(lvl - 1, PvZ.LEVELS_PER_AREA) + 1
	var sub := (lvl - 1) % PvZ.LEVELS_PER_AREA + 1
	var got := (area - 1) * 8 + sub
	if sub >= 10:
		got -= 2
	elif sub >= 5:
		got -= 1
	return mini(got, 40)

func get_seeds_available() -> int:
	var l := player_info.level
	if has_finished_adventure() or l > 50:
		return 49
	return mini(49, get_award_seed_for_level(l))

func has_seed_type(st: int) -> bool:
	if CustomDefs.is_custom_plant(st):
		return true
	if is_trial_stage_locked() and st >= PvZ.SEED_JALAPENO:
		return false
	var pur: Array = player_info.purchases
	match st:
		PvZ.SEED_GATLINGPEA: return pur[PvZ.STORE_ITEM_PLANT_GATLINGPEA] > 0
		PvZ.SEED_TWINSUNFLOWER: return pur[PvZ.STORE_ITEM_PLANT_TWINSUNFLOWER] > 0
		PvZ.SEED_GLOOMSHROOM: return pur[PvZ.STORE_ITEM_PLANT_GLOOMSHROOM] > 0
		PvZ.SEED_CATTAIL: return pur[PvZ.STORE_ITEM_PLANT_CATTAIL] > 0
		PvZ.SEED_WINTERMELON: return pur[PvZ.STORE_ITEM_PLANT_WINTERMELON] > 0
		PvZ.SEED_GOLD_MAGNET: return pur[PvZ.STORE_ITEM_PLANT_GOLD_MAGNET] > 0
		PvZ.SEED_SPIKEROCK: return pur[PvZ.STORE_ITEM_PLANT_SPIKEROCK] > 0
		PvZ.SEED_COBCANNON: return pur[PvZ.STORE_ITEM_PLANT_COBCANNON] > 0
		PvZ.SEED_IMITATER: return pur[PvZ.STORE_ITEM_PLANT_IMITATER] > 0
	if tod_cheat_keys:
		if st == PvZ.SEED_EXPLODE_O_NUT or st == PvZ.SEED_GIANT_WALLNUT or st == PvZ.SEED_SPROUT or st == PvZ.SEED_LEFTPEATER:
			return true
	return st < get_seeds_available()

func seed_type_available(st: int) -> bool:
	return (st == PvZ.SEED_GATLINGPEA and player_info.purchases[PvZ.STORE_ITEM_PLANT_GATLINGPEA] != 0) or has_seed_type(st)

func has_all_upgrades() -> bool:
	var n := 0
	for st in range(PvZ.SEED_GATLINGPEA, PvZ.SEED_IMITATER + 1):
		if seed_type_available(st):
			n += 1
	return n == 9

func can_show_almanac() -> bool:
	return player_info != null and (has_finished_adventure() or player_info.level >= 15)

func can_show_store() -> bool:
	return player_info != null and (has_finished_adventure() or player_info.has_seen_upsell != 0 or player_info.level >= 25)

func can_show_zen_garden() -> bool:
	if player_info == null or is_trial_stage_locked():
		return false
	return has_finished_adventure() or player_info.level >= 45

func can_spawn_yetis() -> bool:
	return has_finished_adventure() and (player_info.finished_adventure >= 2 or player_info.level >= LawnCommon.zombie_def(PvZ.ZOMBIE_YETI)[LawnCommon.ZDEF_STARTING_LEVEL])

func has_beaten_challenge(mode: int) -> bool:
	if player_info == null:
		return false
	var idx := mode - PvZ.GAMEMODE_SURVIVAL_NORMAL_STAGE_1
	if is_survival_normal(mode):
		return player_info.challenge_records[idx] >= PvZ.SURVIVAL_NORMAL_FLAGS
	if is_survival_hard(mode):
		return player_info.challenge_records[idx] >= PvZ.SURVIVAL_HARD_FLAGS
	if is_survival_endless(mode) or is_endless_scary_potter(mode) or is_endless_izombie(mode):
		return false
	return player_info.challenge_records[idx] > 0

func has_finished_adventure() -> bool:
	return player_info != null and player_info.finished_adventure > 0

func is_first_time_adventure_mode() -> bool:
	if CustomRuntime.active != null:
		return false
	return is_adventure_mode() and not has_finished_adventure()

func is_trial_stage_locked() -> bool:
	return debug_trial_locked or trial_type == PvZ.TRIALTYPE_STAGELOCKED

func get_num_trophies(page: int) -> int:
	var n := 0
	for i in NUM_CHALLENGE_MODES:
		var d := ChallengeDefs.get_def(i)
		if d[ChallengeDefs.PAGE] == page and d[ChallengeDefs.HAS_TROPHY] and has_beaten_challenge(d[ChallengeDefs.MODE]):
			n += 1
	return n

func get_total_trophies(page: int) -> int:
	var n := 0
	for i in NUM_CHALLENGE_MODES:
		var d := ChallengeDefs.get_def(i)
		if d[ChallengeDefs.PAGE] == page and d[ChallengeDefs.HAS_TROPHY]:
			n += 1
	return n

func trophies_need_for_gold_sunflower() -> int:
	var num := 0
	var total := 0
	for p in PvZ.MAX_CHALLENGE_PAGES:
		num += get_num_trophies(p)
		total += get_total_trophies(p)
	return total - num

func earned_gold_trophy() -> bool:
	return has_finished_adventure() and trophies_need_for_gold_sunflower() <= 0

func finish_zen_garden_tutorial() -> void:
	board_result = PvZ.BOARDRESULT_WON
	kill_board()
	pre_new_game(PvZ.GAMEMODE_ADVENTURE, false)

func can_do_pinata_mode() -> bool:
	return player_info != null and player_info.challenge_records[PvZ.GAMEMODE_TREE_OF_WISDOM - PvZ.GAMEMODE_SURVIVAL_NORMAL_STAGE_1] >= 1000

func can_do_dance_mode() -> bool:
	return player_info != null and player_info.challenge_records[PvZ.GAMEMODE_TREE_OF_WISDOM - PvZ.GAMEMODE_SURVIVAL_NORMAL_STAGE_1] >= 500

func can_do_daisy_mode() -> bool:
	return player_info != null and player_info.challenge_records[PvZ.GAMEMODE_TREE_OF_WISDOM - PvZ.GAMEMODE_SURVIVAL_NORMAL_STAGE_1] >= 100

func get_achievement(type: int) -> void:
	if board and board.is_net_game():
		return
	if achievements:
		achievements.give_achievement(type)

static func get_money_string(amount: int) -> String:
	var v := amount * 10
	var money := TodStrings.translate("[CURRENCY_STRING]")
	if v > 999999:
		money = Tod.replace_string(money, "{AMOUNT}", "%d,%03d,%03d" % [Tod.idiv(v, 1000000), Tod.idiv(v - Tod.idiv(v, 1000000) * 1000000, 1000), v - Tod.idiv(v, 1000) * 1000])
	elif v > 999:
		money = Tod.replace_string(money, "{AMOUNT}", "%d,%03d" % [Tod.idiv(v, 1000), v - Tod.idiv(v, 1000) * 1000])
	else:
		money = Tod.replace_string(money, "{AMOUNT}", "%d" % v)
	return money

static func pluralize(count: int, singular: String, plural: String) -> String:
	if count == 1:
		return Tod.replace_number_string(TodStrings.translate(singular), "{COUNT}", count)
	return Tod.replace_number_string(TodStrings.translate(plural), "{COUNT}", count)

# ================================================================ Crazy Dave
func advance_crazy_dave_text() -> bool:
	if custom_dave_lines.size() > 0 and crazy_dave_message_index >= CUSTOM_DAVE_BASE:
		var next := crazy_dave_message_index + 1
		if next - CUSTOM_DAVE_BASE >= custom_dave_lines.size():
			return false
		crazy_dave_talk_index(next)
		return true
	var n := "[CRAZY_DAVE_%d]" % (crazy_dave_message_index + 1)
	if not TodStrings.exists(n):
		return false
	crazy_dave_talk_index(crazy_dave_message_index + 1)
	return true

func get_crazy_dave_text(index: int) -> String:
	if custom_dave_lines.size() > 0 and index >= CUSTOM_DAVE_BASE:
		var i := index - CUSTOM_DAVE_BASE
		return str(custom_dave_lines[i]) if i < custom_dave_lines.size() else ""
	var msg := TodStrings.translate("[CRAZY_DAVE_%d]" % index)
	msg = Tod.replace_string(msg, "{PLAYER_NAME}", player_info.name)
	msg = Tod.replace_string(msg, "{MONEY}", get_money_string(player_info.coins))
	msg = Tod.replace_string(msg, "{UPGRADE_COST}", get_money_string(StoreScreen.get_item_cost(PvZ.STORE_ITEM_PACKET_UPGRADE)))
	return msg

func crazy_dave_enter() -> void:
	var r := add_reanimation(PvZ.BOARD_ADDITIONAL_WIDTH, PvZ.BOARD_OFFSET_Y, 0, PvZ.REANIM_CRAZY_DAVE)
	r.is_attachment = true
	r.set_base_pose_from_anim("anim_idle_handing")
	crazy_dave_reanim = r
	r.play_reanim("anim_enter", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 24.0)
	crazy_dave_state = PvZ.CRAZY_DAVE_ENTERING
	crazy_dave_message_index = -1
	crazy_dave_message_text = ""
	crazy_dave_blink_counter = Tod.rand_range_int(400, 800)
	if game_scene == PvZ.SCENE_LEVEL_INTRO and is_stormy_night_level():
		r.color_override = Color8(64, 64, 64)

func _dave() -> Reanimation:
	if crazy_dave_reanim == null or crazy_dave_reanim.freed:
		return null
	return crazy_dave_reanim

func crazy_dave_die() -> void:
	var r := _dave()
	if r:
		r.die()
		crazy_dave_state = PvZ.CRAZY_DAVE_OFF
		crazy_dave_reanim = null
		crazy_dave_message_index = -1
		crazy_dave_message_text = ""
		crazy_dave_stop_sound()

func crazy_dave_leave() -> void:
	var r := _dave()
	if r:
		if crazy_dave_state == PvZ.CRAZY_DAVE_HANDING_TALKING or crazy_dave_state == PvZ.CRAZY_DAVE_HANDING_IDLING:
			crazy_dave_done_handing()
		r.play_reanim("anim_leave", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 24.0)
		r.set_image_override("Dave_mouths", null)
		crazy_dave_state = PvZ.CRAZY_DAVE_LEAVING
		crazy_dave_message_index = -1
		crazy_dave_message_text = ""
		crazy_dave_stop_sound()

func crazy_dave_talk_index(index: int) -> void:
	crazy_dave_message_index = index
	crazy_dave_talk_message(get_crazy_dave_text(index))

func crazy_dave_done_handing() -> void:
	var r := _dave()
	if r:
		Attachment.die_on(r.get_track_instance("Dave_handinghand"))

func crazy_dave_stop_sound() -> void:
	sound_system.stop_foley(PvZ.FOLEY_CRAZY_DAVE_SHORT)
	sound_system.stop_foley(PvZ.FOLEY_CRAZY_DAVE_LONG)
	sound_system.stop_foley(PvZ.FOLEY_CRAZY_DAVE_EXTRA_LONG)
	sound_system.stop_foley(PvZ.FOLEY_CRAZY_DAVE_CRAZY)

func _hand_item(r: Reanimation, item: Reanimation, ox: float, oy: float, scale: float) -> void:
	var eff := Attachment.attach_reanim(r.get_track_instance("Dave_handinghand"), item, ox, oy)
	if scale != 1.0:
		eff.offset.x.x = scale
		eff.offset.y.y = scale
	r.update()

func crazy_dave_talk_message(message: String) -> void:
	var r := _dave()
	if r == null:
		return
	var handing := message.contains("{HANDING}")
	if (crazy_dave_state == PvZ.CRAZY_DAVE_HANDING_TALKING or crazy_dave_state == PvZ.CRAZY_DAVE_HANDING_IDLING) and not handing:
		crazy_dave_done_handing()
	var do_sound := true
	if message.contains("{NO_SOUND}"):
		do_sound = false
	else:
		crazy_dave_stop_sound()
	var words := 0
	var control := false
	for ch in message:
		if ch == "{":
			control = true
		elif ch == "}":
			control = false
		elif not control:
			words += 1
	r.set_image_override("Dave_mouths", null)
	if crazy_dave_state != PvZ.CRAZY_DAVE_TALKING or do_sound:
		if handing:
			r.play_reanim("anim_talk_handing", Reanimation.REANIM_LOOP, 50, 12.0)
			if do_sound:
				if message.contains("{SHORT_SOUND}"):
					play_foley(PvZ.FOLEY_CRAZY_DAVE_SHORT)
				elif message.contains("{SCREAM}"):
					play_foley(PvZ.FOLEY_CRAZY_DAVE_SCREAM)
				else:
					play_foley(PvZ.FOLEY_CRAZY_DAVE_LONG)
			crazy_dave_state = PvZ.CRAZY_DAVE_HANDING_TALKING
		elif message.contains("{SHAKE}"):
			r.play_reanim("anim_crazy", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 50, 12.0)
			if do_sound:
				play_foley(PvZ.FOLEY_CRAZY_DAVE_CRAZY)
			crazy_dave_state = PvZ.CRAZY_DAVE_TALKING
		elif message.contains("{SCREAM}"):
			r.play_reanim("anim_smalltalk", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 50, 12.0)
			if do_sound:
				play_foley(PvZ.FOLEY_CRAZY_DAVE_SCREAM)
			crazy_dave_state = PvZ.CRAZY_DAVE_TALKING
		elif message.contains("{SCREAM2}"):
			r.play_reanim("anim_mediumtalk", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 50, 12.0)
			if do_sound:
				play_foley(PvZ.FOLEY_CRAZY_DAVE_SCREAM_2)
			crazy_dave_state = PvZ.CRAZY_DAVE_TALKING
		elif message.contains("{SHOW_WALLNUT}"):
			r.play_reanim("anim_talk_handing", Reanimation.REANIM_LOOP, 50, 12.0)
			var nut := add_reanimation(0.0, 0.0, 0, PvZ.REANIM_WALLNUT)
			nut.play_reanim("anim_idle", Reanimation.REANIM_LOOP, 0, 12.0)
			_hand_item(r, nut, 100.0, 393.0, 1.2)
			if do_sound:
				play_foley(PvZ.FOLEY_CRAZY_DAVE_SCREAM_2)
			crazy_dave_state = PvZ.CRAZY_DAVE_HANDING_TALKING
		elif message.contains("{SHOW_HAMMER}"):
			r.play_reanim("anim_talk_handing", Reanimation.REANIM_LOOP, 50, 12.0)
			var hammer := add_reanimation(0.0, 0.0, 0, PvZ.REANIM_HAMMER)
			hammer.play_reanim("anim_whack_zombie", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 24.0)
			hammer.anim_time = 1.0
			_hand_item(r, hammer, 62.0, 445.0, 1.5)
			if do_sound:
				play_foley(PvZ.FOLEY_CRAZY_DAVE_LONG)
			crazy_dave_state = PvZ.CRAZY_DAVE_HANDING_TALKING
		elif message.contains("{SHOW_FERTILIZER}"):
			r.play_reanim("anim_talk_handing", Reanimation.REANIM_LOOP, 50, 12.0)
			var fert := add_reanimation(0.0, 0.0, 0, PvZ.REANIM_ZENGARDEN_FERTILIZER)
			fert.play_reanim("bag", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 24.0)
			fert.anim_rate = 0.0
			_hand_item(r, fert, 102.0, 412.0, 1.0)
			if do_sound:
				play_foley(PvZ.FOLEY_CRAZY_DAVE_LONG)
			crazy_dave_state = PvZ.CRAZY_DAVE_HANDING_TALKING
		elif message.contains("{SHOW_TREE_FOOD}"):
			r.play_reanim("anim_talk_handing", Reanimation.REANIM_LOOP, 50, 12.0)
			var food := add_reanimation(0.0, 0.0, 0, PvZ.REANIM_TREEOFWISDOM_TREEFOOD)
			food.play_reanim("bag", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 24.0)
			food.anim_rate = 0.0
			_hand_item(r, food, 102.0, 412.0, 1.0)
			if do_sound:
				play_foley(PvZ.FOLEY_CRAZY_DAVE_LONG)
			crazy_dave_state = PvZ.CRAZY_DAVE_HANDING_TALKING
		elif message.contains("{SHOW_MONEYBAG}"):
			r.play_reanim("anim_talk_handing", Reanimation.REANIM_LOOP, 50, 12.0)
			var bag := add_reanimation(0.0, 0.0, 0, PvZ.REANIM_ZENGARDEN_FERTILIZER)
			bag.play_reanim("bag", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 24.0)
			bag.anim_rate = 0.0
			bag.set_image_override("bag", Res.get_image("IMAGE_MONEYBAG"))
			_hand_item(r, bag, 90.0, 405.0, 1.0)
			if do_sound:
				play_foley(PvZ.FOLEY_CRAZY_DAVE_LONG)
			crazy_dave_state = PvZ.CRAZY_DAVE_HANDING_TALKING
		else:
			if words < 23:
				r.play_reanim("anim_smalltalk", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 50, 12.0)
				if do_sound:
					play_foley(PvZ.FOLEY_CRAZY_DAVE_SHORT)
			elif words < 52:
				r.play_reanim("anim_mediumtalk", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 50, 12.0)
				if do_sound:
					play_foley(PvZ.FOLEY_CRAZY_DAVE_LONG)
			else:
				r.play_reanim("anim_blahblah", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 50, 12.0)
				if do_sound:
					play_foley(PvZ.FOLEY_CRAZY_DAVE_EXTRA_LONG)
			crazy_dave_state = PvZ.CRAZY_DAVE_TALKING
	crazy_dave_message_text = message

func crazy_dave_stop_talking() -> void:
	var done_handing := game_mode != PvZ.GAMEMODE_UPSELL
	if done_handing and crazy_dave_state == PvZ.CRAZY_DAVE_HANDING_TALKING:
		crazy_dave_done_handing()
	var r := _dave()
	if r == null:
		return
	r.set_image_override("Dave_mouths", null)
	if crazy_dave_state == PvZ.CRAZY_DAVE_HANDING_TALKING and not done_handing:
		r.play_reanim("anim_idle_handing", Reanimation.REANIM_LOOP, 20, 12.0)
		crazy_dave_state = PvZ.CRAZY_DAVE_HANDING_IDLING
	elif crazy_dave_state == PvZ.CRAZY_DAVE_TALKING or crazy_dave_state == PvZ.CRAZY_DAVE_HANDING_TALKING:
		r.play_reanim("anim_idle", Reanimation.REANIM_LOOP, 20, 12.0)
		crazy_dave_state = PvZ.CRAZY_DAVE_IDLING
	crazy_dave_message_index = -1
	crazy_dave_message_text = ""
	crazy_dave_stop_sound()

func update_crazy_dave() -> void:
	var r := _dave()
	if r == null:
		return
	if crazy_dave_state == PvZ.CRAZY_DAVE_ENTERING or crazy_dave_state == PvZ.CRAZY_DAVE_TALKING:
		if r.loop_count > 0:
			r.play_reanim("anim_idle", Reanimation.REANIM_LOOP, 20, 12.0)
			crazy_dave_state = PvZ.CRAZY_DAVE_IDLING
	elif crazy_dave_state == PvZ.CRAZY_DAVE_HANDING_TALKING:
		if r.loop_count > 0:
			r.play_reanim("anim_idle_handing", Reanimation.REANIM_LOOP, 20, 12.0)
			crazy_dave_state = PvZ.CRAZY_DAVE_HANDING_IDLING
	elif crazy_dave_state == PvZ.CRAZY_DAVE_LEAVING and r.loop_count > 0:
		crazy_dave_die()
		return
	if crazy_dave_state == PvZ.CRAZY_DAVE_IDLING or crazy_dave_state == PvZ.CRAZY_DAVE_HANDING_IDLING:
		if crazy_dave_message_text.contains("{MOUTH_BIG_SMILE}"):
			r.set_image_override("Dave_mouths", Res.get_image("IMAGE_REANIM_CRAZYDAVE_MOUTH1"))
		elif crazy_dave_message_text.contains("{MOUTH_SMALL_SMILE}"):
			r.set_image_override("Dave_mouths", Res.get_image("IMAGE_REANIM_CRAZYDAVE_MOUTH5"))
		elif crazy_dave_message_text.contains("{MOUTH_BIG_OH}"):
			r.set_image_override("Dave_mouths", Res.get_image("IMAGE_REANIM_CRAZYDAVE_MOUTH4"))
		elif crazy_dave_message_text.contains("{MOUTH_SMALL_OH}"):
			r.set_image_override("Dave_mouths", Res.get_image("IMAGE_REANIM_CRAZYDAVE_MOUTH6"))
	if crazy_dave_state in [PvZ.CRAZY_DAVE_IDLING, PvZ.CRAZY_DAVE_TALKING, PvZ.CRAZY_DAVE_HANDING_TALKING, PvZ.CRAZY_DAVE_HANDING_IDLING]:
		crazy_dave_blink_counter -= 1
		if crazy_dave_blink_counter <= 0:
			crazy_dave_blink_counter = Tod.rand_range_int(400, 800)
			var blink := add_reanimation(0.0, 0.0, 0, PvZ.REANIM_CRAZY_DAVE)
			blink.set_frames_for_layer("anim_blink")
			blink.loop_type = Reanimation.REANIM_PLAY_ONCE_FULL_LAST_FRAME_AND_HOLD
			blink.anim_rate = 15.0
			blink.attach_to_another_reanimation(r, "Dave_head")
			blink.color_override = r.color_override
			r.assign_render_group_to_track("Dave_eye", Reanimation.RENDER_GROUP_HIDDEN)
			crazy_dave_blink_reanim = blink
	var b := crazy_dave_blink_reanim
	if b != null and not b.freed and b.loop_count > 0:
		r.assign_render_group_to_track("Dave_eye", Reanimation.RENDER_GROUP_NORMAL)
		b.die()
		crazy_dave_blink_reanim = null
	r.update()

func draw_crazy_dave(g: Graphics) -> void:
	var r := _dave()
	if r == null:
		return
	if crazy_dave_message_text.length() > 0:
		var bubble := Res.get_image("IMAGE_STORE_SPEECHBUBBLE2")
		var px := 285 + PvZ.BOARD_ADDITIONAL_WIDTH
		var py := 20 + PvZ.BOARD_OFFSET_Y
		if get_dialog(PvZ.DIALOG_STORE):
			bubble = Res.get_image("IMAGE_STORE_SPEECHBUBBLE")
			px -= 180
			py -= 78
		elif game_mode == PvZ.GAMEMODE_UPSELL:
			px += 130 - PvZ.BOARD_ADDITIONAL_WIDTH
			py += 70 - PvZ.BOARD_OFFSET_Y
		g.draw_image(bubble, px, py)
		var text := crazy_dave_message_text
		var rect := Rect2i(px + 25, py + 6, 233, 144)
		if text.contains("{SHAKE}"):
			text = Tod.replace_string(text, "{SHAKE}", "")
			rect.position.x += randi() % 2
			rect.position.y += randi() % 2
		var click := true
		if game_mode == PvZ.GAMEMODE_UPSELL:
			click = false
		elif text.contains("{NO_CLICK}"):
			text = Tod.replace_string(text, "{NO_CLICK}", "")
			click = false
		TodStrings.draw_string_wrapped(g, text, rect, Res.get_font("FONT_BRIANNETOD16"), Color.BLACK, TodStrings.DS_ALIGN_CENTER_VERTICAL_MIDDLE)
		if click:
			TodStrings.draw_string(g, "click to continue", px + 139, py + 140, Res.get_font("FONT_PICO129"), Color.BLACK, TodStrings.DS_ALIGN_CENTER)
	r.draw(g)
