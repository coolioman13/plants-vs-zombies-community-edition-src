class_name NewOptionsDialog
extends Dialog
## Port of NewOptionsDialog (the stone options menu, plus the four QE "advanced options" pages).

enum {
	NEW_OPTIONS_ALMANAC, NEW_OPTIONS_MAIN_MENU, NEW_OPTIONS_RESTART, NEW_OPTIONS_MUSIC_VOLUME, NEW_OPTIONS_SOUND_VOLUME,
	NEW_OPTIONS_FULLSCREEN, NEW_OPTIONS_HARDWARE_ACCELERATION, NEW_OPTIONS_ADVANCED, NEW_OPTIONS_RELOAD_LANGUAGES,
	NEW_OPTIONS_LANGUAGE, NEW_OPTIONS_RELOAD_RESOURCE_PACKS, NEW_OPTIONS_RESOURCE_PACK, NEW_OPTIONS_REAL_HARDWARE_ACCELERATION,
	NEW_OPTIONS_CUSTOM_CURSOR, NEW_OPTIONS_LEFT_PAGE, NEW_OPTIONS_RIGHT_PAGE, NEW_OPTIONS_BACK,
}

const TEXT_COLOR := Color8(107, 109, 145)

var music_volume_slider: SexySlider
var sfx_volume_slider: SexySlider
var fullscreen_checkbox: Checkbox
var hardware_acceleration_checkbox: Checkbox
var debug_mode_checkbox: Checkbox
var discord_checkbox: Checkbox
var bank_keybinds_checkbox: Checkbox
var zero_nine_format_checkbox: Checkbox
var auto_collect_suns_checkbox: Checkbox
var auto_collect_coins_checkbox: Checkbox
var zombie_healthbars_checkbox: Checkbox
var plant_healthbars_checkbox: Checkbox
var almanac_button: LawnStoneButton
var back_to_main_button: LawnStoneButton
var restart_button: LawnStoneButton
var back_to_game_button: NewLawnButton
var advanced_button: LawnStoneButton
var game_advanced_button: NewLawnButton
var right_page_button: NewLawnButton
var left_page_button: NewLawnButton
var from_game_selector := false
var advanced_mode := false
var advanced_page := 0
var speed_edit_widget: EditWidget
var speed_edit_prev_text := ""
var reload_languages_button: LawnStoneButton
var language_button: NewLawnButton
var reload_resource_packs_button: LawnStoneButton
var resource_pack_button: NewLawnButton
var real_hardware_acceleration_checkbox: Checkbox
var custom_cursor_checkbox: Checkbox

func _new_hidden_checkbox(cid: int, value: bool) -> Checkbox:
	var c := LawnButtons.make_new_checkbox(cid, self, value)
	c.set_visible(false)
	return c

func _init(the_from_game_selector: bool, the_advanced: bool) -> void:
	super._init(PvZ.DIALOG_NEWOPTIONS, true, "", "", "", BUTTONS_NONE)
	from_game_selector = the_from_game_selector
	advanced_mode = the_advanced
	advanced_page = 0
	set_color(COLOR_BUTTON_TEXT, Color8(255, 255, 100))
	almanac_button = LawnButtons.make_button(NEW_OPTIONS_ALMANAC, self, "[VIEW_ALMANAC_BUTTON]")
	restart_button = LawnButtons.make_button(NEW_OPTIONS_RESTART, self, "[RESTART_LEVEL_BUTTON]")
	back_to_main_button = LawnButtons.make_button(NEW_OPTIONS_MAIN_MENU, self, "[MAIN_MENU_BUTTON]")
	advanced_button = LawnButtons.make_button(NEW_OPTIONS_ADVANCED, self, "[ADVANCED_OPTIONS_BUTTON]")

	var back0 := Res.get_image("IMAGE_OPTIONS_BACKTOGAMEBUTTON0")
	back_to_game_button = LawnButtons.make_new_button(ID_YES, self, "[BACK_TO_GAME]", null, back0, back0, Res.get_image("IMAGE_OPTIONS_BACKTOGAMEBUTTON2"))
	back_to_game_button.translate_x = 0
	back_to_game_button.translate_y = 0
	back_to_game_button.text_offset_x = -2
	back_to_game_button.text_offset_y = -5
	back_to_game_button.text_down_offset_x = 0
	back_to_game_button.text_down_offset_y = 1
	back_to_game_button.set_font(Res.get_font("FONT_DWARVENTODCRAFT36GREENINSET"))
	back_to_game_button.set_color(ButtonWidget.COLOR_LABEL, Color.WHITE)
	back_to_game_button.set_color(ButtonWidget.COLOR_LABEL_HILITE, Color.WHITE)
	back_to_game_button.hilite_font = Res.get_font("FONT_DWARVENTODCRAFT36BRIGHTGREENINSET")

	music_volume_slider = SexySlider.new(Res.get_image("IMAGE_OPTIONS_SLIDERSLOT"), Res.get_image("IMAGE_OPTIONS_SLIDERKNOB2"), NEW_OPTIONS_MUSIC_VOLUME, self)
	music_volume_slider.set_value(clampf(App.get_music_volume(), 0.0, 1.0))
	sfx_volume_slider = SexySlider.new(Res.get_image("IMAGE_OPTIONS_SLIDERSLOT"), Res.get_image("IMAGE_OPTIONS_SLIDERKNOB2"), NEW_OPTIONS_SOUND_VOLUME, self)
	sfx_volume_slider.set_value(App.get_sfx_volume())

	fullscreen_checkbox = LawnButtons.make_new_checkbox(NEW_OPTIONS_FULLSCREEN, self, not App.is_windowed)
	hardware_acceleration_checkbox = LawnButtons.make_new_checkbox(NEW_OPTIONS_HARDWARE_ACCELERATION, self, App.is_3d_accel())
	debug_mode_checkbox = _new_hidden_checkbox(-1, App.tod_cheat_keys)
	discord_checkbox = _new_hidden_checkbox(-1, App.discord_presence)
	bank_keybinds_checkbox = _new_hidden_checkbox(-1, App.bank_keybinds)
	zero_nine_format_checkbox = _new_hidden_checkbox(-1, App.zero_nine_bank_format)
	auto_collect_suns_checkbox = _new_hidden_checkbox(-1, App.auto_collect_suns)
	auto_collect_coins_checkbox = _new_hidden_checkbox(-1, App.auto_collect_coins)
	zombie_healthbars_checkbox = _new_hidden_checkbox(-1, App.zombie_healthbars)
	plant_healthbars_checkbox = _new_hidden_checkbox(-1, App.plant_healthbars)

	left_page_button = LawnButtons.make_new_button(NEW_OPTIONS_LEFT_PAGE, self, "", null, Res.get_image("IMAGE_QUICKPLAY_LEFT_BUTTON"),
		Res.get_image("IMAGE_QUICKPLAY_LEFT_BUTTON_HIGHLIGHT"), Res.get_image("IMAGE_QUICKPLAY_LEFT_BUTTON_HIGHLIGHT"))
	left_page_button.set_visible(false)
	right_page_button = LawnButtons.make_new_button(NEW_OPTIONS_RIGHT_PAGE, self, "", null, Res.get_image("IMAGE_QUICKPLAY_RIGHT_BUTTON"),
		Res.get_image("IMAGE_QUICKPLAY_RIGHT_BUTTON_HIGHLIGHT"), Res.get_image("IMAGE_QUICKPLAY_RIGHT_BUTTON_HIGHLIGHT"))
	right_page_button.set_visible(false)

	speed_edit_widget = EditWidget.create_lawn(-1, self, self)
	speed_edit_widget.max_chars = 1
	speed_edit_widget.font = Res.get_font("FONT_DWARVENTODCRAFT18GREENINSET")
	speed_edit_widget.add_width_check_font(Res.get_font("FONT_DWARVENTODCRAFT18GREENINSET"), Res.get_image("IMAGE_OPTIONS_CHECKBOX0").width)
	speed_edit_widget.set_text("%d" % App.speed_modifier)
	speed_edit_widget.set_color(ButtonWidget.COLOR_LIGHT_OUTLINE, Color8(1, 233, 1))
	speed_edit_widget.set_visible(false)

	game_advanced_button = LawnButtons.make_new_button(NEW_OPTIONS_ADVANCED, self, "[ADVANCED_OPTIONS_BUTTON_SHORT]", null, Res.get_image("IMAGE_BUTTON_SMALL"),
		Res.get_image("IMAGE_BUTTON_SMALL"), Res.get_image("IMAGE_BUTTON_DOWN_SMALL"))
	game_advanced_button.set_font(Res.get_font("FONT_DWARVENTODCRAFT18GREENINSET"))
	game_advanced_button.set_color(ButtonWidget.COLOR_LABEL, Color.WHITE)
	game_advanced_button.set_color(ButtonWidget.COLOR_LABEL_HILITE, Color.WHITE)
	game_advanced_button.hilite_font = Res.get_font("FONT_DWARVENTODCRAFT18BRIGHTGREENINSET")
	game_advanced_button.set_visible(false)

	reload_languages_button = LawnButtons.make_button(NEW_OPTIONS_RELOAD_LANGUAGES, self, "[OPTIONS_RELOAD_LANGUAGES]")
	reload_languages_button.set_visible(false)
	var blank := Res.get_image("IMAGE_BLANK")
	language_button = LawnButtons.make_new_button(NEW_OPTIONS_LANGUAGE, self, "[LANGUAGE_NAME]", null, blank, blank, blank)
	language_button.set_font(Res.get_font("FONT_DWARVENTODCRAFT18"))
	language_button.colors[ButtonWidget.COLOR_LABEL] = TEXT_COLOR
	language_button.colors[ButtonWidget.COLOR_LABEL_HILITE] = Color8(1, 233, 1)
	language_button.set_visible(false)

	reload_resource_packs_button = LawnButtons.make_button(NEW_OPTIONS_RELOAD_RESOURCE_PACKS, self, "[OPTIONS_RELOAD_RESOURCE_PACKS]")
	reload_resource_packs_button.set_visible(false)
	resource_pack_button = LawnButtons.make_new_button(NEW_OPTIONS_RESOURCE_PACK, self, App.get_resource_pack_string(), null, blank, blank, blank)
	resource_pack_button.set_font(Res.get_font("FONT_DWARVENTODCRAFT18"))
	resource_pack_button.colors[ButtonWidget.COLOR_LABEL] = TEXT_COLOR
	resource_pack_button.colors[ButtonWidget.COLOR_LABEL_HILITE] = Color8(1, 233, 1)
	resource_pack_button.set_visible(false)

	real_hardware_acceleration_checkbox = _new_hidden_checkbox(NEW_OPTIONS_REAL_HARDWARE_ACCELERATION, App.is_3d_accelerated())
	custom_cursor_checkbox = _new_hidden_checkbox(NEW_OPTIONS_CUSTOM_CURSOR, App.custom_cursor)

	if from_game_selector:
		restart_button.set_visible(false)
		back_to_game_button.label = "[DIALOG_BUTTON_OK]"
		if App.has_finished_adventure() and not App.is_trial_stage_locked():
			back_to_main_button.set_visible(false)
			back_to_main_button.label = "[CREDITS]"
	else:
		advanced_button.set_visible(false)
		game_advanced_button.set_visible(true)

	if advanced_mode:
		advanced_page = 1
		restart_button.set_visible(false)
		almanac_button.set_visible(false)
		back_to_main_button.set_visible(false)
		advanced_button.set_visible(false)
		game_advanced_button.set_visible(false)
		back_to_game_button.label = "[DIALOG_BUTTON_BACK]"
		back_to_game_button.id = NEW_OPTIONS_BACK

	if App.game_mode in [PvZ.GAMEMODE_CHALLENGE_ICE, PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN, PvZ.GAMEMODE_TREE_OF_WISDOM]:
		restart_button.set_visible(false)
	if App.game_scene == PvZ.SCENE_LEVEL_INTRO and not App.board.cut_scene.is_survival_repick():
		restart_button.set_visible(false)
	if not App.can_show_almanac() or App.game_scene == PvZ.SCENE_LEVEL_INTRO \
			or App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN or App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM or from_game_selector:
		almanac_button.set_visible(false)
	if (not restart_button.visible or not almanac_button.visible) and not from_game_selector and not advanced_mode:
		advanced_button.set_visible(true)
		game_advanced_button.set_visible(false)

## The original returns the back image's width here (not its height); kept as-is.
func get_preferred_height(_w: int) -> int:
	return Res.get_image("IMAGE_OPTIONS_MENUBACK").width

func _children() -> Array:
	return [almanac_button, restart_button, back_to_main_button, advanced_button, music_volume_slider, sfx_volume_slider,
		hardware_acceleration_checkbox, debug_mode_checkbox, discord_checkbox, bank_keybinds_checkbox, zero_nine_format_checkbox,
		fullscreen_checkbox, back_to_game_button, left_page_button, right_page_button, speed_edit_widget, game_advanced_button,
		auto_collect_suns_checkbox, auto_collect_coins_checkbox, zombie_healthbars_checkbox, plant_healthbars_checkbox,
		reload_languages_button, language_button, reload_resource_packs_button, resource_pack_button,
		real_hardware_acceleration_checkbox, custom_cursor_checkbox]

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	for w in _children():
		add_widget(w)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	for w in _children():
		remove_widget(w)

func resize(nx: int, ny: int, w: int, h: int) -> void:
	super.resize(nx, ny, w, h)
	if music_volume_slider == null:
		return
	music_volume_slider.resize(199, 116, 135, 40)
	sfx_volume_slider.resize(199, 143, 135, 40)
	hardware_acceleration_checkbox.resize(284, 175, 46, 39)
	fullscreen_checkbox.resize(284, 206, 46, 39)
	almanac_button.resize(107, 241, 209, 46)
	restart_button.resize(almanac_button.x, almanac_button.y + 43, 209, 46)
	back_to_main_button.resize(restart_button.x, restart_button.y + 43, 209, 46)
	advanced_button.resize(restart_button.x, restart_button.y + 43, 209, 46)
	back_to_game_button.resize(30, 381, back_to_game_button.width, back_to_game_button.height)
	var left_img := Res.get_image("IMAGE_QUICKPLAY_LEFT_BUTTON")
	var right_img := Res.get_image("IMAGE_QUICKPLAY_RIGHT_BUTTON")
	left_page_button.resize(100, PvZ.ADVANCEDOPTIONS_PAGE_Y - 25, left_img.width, left_img.height)
	right_page_button.resize(280, PvZ.ADVANCEDOPTIONS_PAGE_Y - 25, right_img.width, right_img.height)
	var small := Res.get_image("IMAGE_BUTTON_SMALL")
	game_advanced_button.resize(width - small.width - 9, restart_button.y, small.width, small.height)

	# page 1
	debug_mode_checkbox.resize(284, 148, 46, 39)
	discord_checkbox.resize(debug_mode_checkbox.x, debug_mode_checkbox.y + 40, 46, 39)
	bank_keybinds_checkbox.resize(discord_checkbox.x, discord_checkbox.y + 40, 46, 39)
	zero_nine_format_checkbox.resize(bank_keybinds_checkbox.x, bank_keybinds_checkbox.y + 40, 46, 39)
	# page 2
	var cb0 := Res.get_image("IMAGE_OPTIONS_CHECKBOX0")
	speed_edit_widget.resize(PvZ.ADVANCEDOPTIONS_SPEED_X + 9, PvZ.ADVANCEDOPTIONS_SPEED_Y - 4, cb0.width, cb0.height + 4)
	auto_collect_suns_checkbox.resize(discord_checkbox.x, discord_checkbox.y - 20, 46, 39)
	auto_collect_coins_checkbox.resize(auto_collect_suns_checkbox.x, auto_collect_suns_checkbox.y + 40, 46, 39)
	zombie_healthbars_checkbox.resize(auto_collect_coins_checkbox.x, auto_collect_coins_checkbox.y + 40, 46, 39)
	plant_healthbars_checkbox.resize(zombie_healthbars_checkbox.x, zombie_healthbars_checkbox.y + 40, 46, 39)
	# page 3
	var font18_h := Res.get_font("FONT_DWARVENTODCRAFT18").get_height()
	var packs_w := 260
	reload_resource_packs_button.resize(Tod.idiv(width, 2) - packs_w / 2, PvZ.ADVANCEDOPTIONS_SPEED_Y, packs_w, 46)
	resource_pack_button.resize(Tod.idiv(width, 2) + 15, reload_resource_packs_button.y + 50, 0, font18_h)
	resize_resource_pack_button()
	var langs_w := 225
	reload_languages_button.resize(Tod.idiv(width, 2) - langs_w / 2, resource_pack_button.y + 50, langs_w, 46)
	language_button.resize(Tod.idiv(width, 2) + 15, reload_languages_button.y + 50, 0, font18_h)
	resize_language_button()
	# page 4
	real_hardware_acceleration_checkbox.resize(PvZ.ADVANCEDOPTIONS_SPEED_X, PvZ.ADVANCEDOPTIONS_SPEED_Y, 46, 39)
	custom_cursor_checkbox.resize(real_hardware_acceleration_checkbox.x, real_hardware_acceleration_checkbox.y + 40, 46, 39)

	if (not restart_button.visible or not almanac_button.visible) and not from_game_selector and not advanced_mode:
		var b := restart_button if not restart_button.visible else almanac_button
		advanced_button.resize(b.x, b.y, b.width, b.height)
	if from_game_selector:
		music_volume_slider.y += 5
		sfx_volume_slider.y += 10
		hardware_acceleration_checkbox.y += 15
		fullscreen_checkbox.y += 20
	if advanced_mode:
		music_volume_slider.set_visible(false)
		sfx_volume_slider.set_visible(false)
		hardware_acceleration_checkbox.set_visible(false)
		fullscreen_checkbox.set_visible(false)
		left_page_button.set_visible(true)
		right_page_button.set_visible(true)
		update_advanced_page()
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN or App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
		almanac_button.y += 43

func _label(g: Graphics, key: String, px: int, py: int, just: int = PvZ.DS_ALIGN_RIGHT) -> void:
	TodStrings.draw_string(g, TodStrings.translate(key), px, py, Res.get_font("FONT_DWARVENTODCRAFT18"), TEXT_COLOR, just)

func draw(g: Graphics) -> void:
	g.draw_image(Res.get_image("IMAGE_OPTIONS_MENUBACK"), 0, 0)
	var music_off := 5 if from_game_selector else 0
	var sfx_off := 10 if from_game_selector else 0
	var accel_off := 15 if from_game_selector else 0
	var full_off := 20 if from_game_selector else 0
	var f18 := Res.get_font("FONT_DWARVENTODCRAFT18")
	if not advanced_mode:
		_label(g, "[OPTIONS_MUSIC]", 186, 140 + music_off)
		TodStrings.draw_string(g, str(int(music_volume_slider.val * 100)), 203 + music_volume_slider.width, 143 + music_off, f18, TEXT_COLOR, PvZ.DS_ALIGN_LEFT)
		_label(g, "[OPTIONS_SOUND]", 186, 167 + sfx_off)
		TodStrings.draw_string(g, str(int(sfx_volume_slider.val * 100)), 203 + sfx_volume_slider.width, 170 + sfx_off, f18, TEXT_COLOR, PvZ.DS_ALIGN_LEFT)
		_label(g, "[OPTIONS_ACCELERATION]", 274, 197 + accel_off)
		_label(g, "[OPTIONS_FULLSCREEN]", 274, 229 + full_off)
		return

	match advanced_page:
		1:
			TodStrings.draw_string(g, App.RECON_VERSION, Tod.idiv(width, 2), 137, f18, TEXT_COLOR, PvZ.DS_ALIGN_CENTER)
			_label(g, "[OPTIONS_DEBUG_MODE]", debug_mode_checkbox.x - 6, debug_mode_checkbox.y + 22)
			_label(g, "[OPTIONS_DISCORD_PRESENCE]", discord_checkbox.x - 6, discord_checkbox.y + 22)
			_label(g, "[OPTIONS_SEED_BANK_KEYBINDS]", bank_keybinds_checkbox.x - 6, bank_keybinds_checkbox.y + 22)
			var keybind := Tod.replace_string(TodStrings.translate("[OPTIONS_SEED_BANK_KEYBIND]"), "{KEYBIND}", "1-0" if zero_nine_format_checkbox.checked else "0-9")
			TodStrings.draw_string(g, keybind, zero_nine_format_checkbox.x - 6, zero_nine_format_checkbox.y + 22, f18, TEXT_COLOR, PvZ.DS_ALIGN_RIGHT)
			_label(g, "[OPTIONS_SHOVEL_KEYBIND]", Tod.idiv(width, 2), zero_nine_format_checkbox.y + 55, PvZ.DS_ALIGN_CENTER)
		2:
			_label(g, "[OPTIONS_SPEED_MODIFIER]", PvZ.ADVANCEDOPTIONS_SPEED_X - 6, PvZ.ADVANCEDOPTIONS_SPEED_Y + 22)
			_label(g, "[OPTIONS_AUTO_COLLECT_SUNS]", auto_collect_suns_checkbox.x - 6, auto_collect_suns_checkbox.y + 22)
			_label(g, "[OPTIONS_AUTO_COLLECT_COINS]", auto_collect_coins_checkbox.x - 6, auto_collect_coins_checkbox.y + 22)
			_label(g, "[OPTIONS_ZOMBIE_HEALTHBARS]", zombie_healthbars_checkbox.x - 6, zombie_healthbars_checkbox.y + 22)
			_label(g, "[OPTIONS_PLANT_HEALTHBARS]", plant_healthbars_checkbox.x - 6, plant_healthbars_checkbox.y + 22)
			g.draw_image(Res.get_image("IMAGE_OPTIONS_CHECKBOX0"), PvZ.ADVANCEDOPTIONS_SPEED_X, PvZ.ADVANCEDOPTIONS_SPEED_Y)
		3:
			_label(g, "[OPTIONS_LANGUAGE]", language_button.x - 6, language_button.y + 23)
			_label(g, "[OPTIONS_RESOURCE_PACK]", resource_pack_button.x - 6, resource_pack_button.y + 23)
		4:
			_label(g, "[OPTIONS_ACTUAL_ACCELERATION]", real_hardware_acceleration_checkbox.x - 6, real_hardware_acceleration_checkbox.y + 22)
			_label(g, "[OPTIONS_CUSTOM_CURSOR]", custom_cursor_checkbox.x - 6, custom_cursor_checkbox.y + 22)
	TodStrings.draw_string(g, Tod.replace_number_string(TodStrings.translate("[OPTIONS_PAGE]"), "{PAGE}", advanced_page),
		Tod.idiv(width, 2), PvZ.ADVANCEDOPTIONS_PAGE_Y, Res.get_font("FONT_DWARVENTODCRAFT18GREENINSET"), Color.WHITE, PvZ.DS_ALIGN_CENTER)

func slider_val(sid: int, v: float) -> void:
	match sid:
		NEW_OPTIONS_MUSIC_VOLUME:
			App.set_music_volume(v)
			App.sound_system.rehookup_sound_with_music_volume()
		NEW_OPTIONS_SOUND_VOLUME:
			App.set_sfx_volume(v)
			App.sound_system.rehookup_sound_with_music_volume()
			if not sfx_volume_slider.dragging:
				App.play_sample("SOUND_BUTTONCLICK")

func checkbox_checked(cid: int, checked: bool) -> void:
	match cid:
		NEW_OPTIONS_FULLSCREEN:
			if not checked and App.force_fullscreen:
				App.do_dialog(PvZ.DIALOG_COLORDEPTH_EXP, true, "[NO_WINDOWED_MODE_HEADER]", "[NO_WINDOWED_MODE]", "[DIALOG_BUTTON_OK]", BUTTONS_FOOTER)
				fullscreen_checkbox.set_checked(true, false)
		NEW_OPTIONS_HARDWARE_ACCELERATION, NEW_OPTIONS_REAL_HARDWARE_ACCELERATION:
			if checked and not App.is_3d_acceleration_recommended():
				App.do_dialog(PvZ.DIALOG_INFO, true, "[NOT_RECOMMENDED_ACCELERATION_HEADER]", "[NOT_RECOMMENDED_ACCELERATION]", "[DIALOG_BUTTON_OK]", BUTTONS_FOOTER)

func key_down(key: int) -> void:
	if App.board:
		App.board.do_typing_check(key)
	if key == WidgetManager.KEYCODE_SPACE or key == WidgetManager.KEYCODE_RETURN:
		if advanced_mode:
			button_depress(NEW_OPTIONS_BACK)
		else:
			super.button_depress(ID_YES)
			App.play_sample("SOUND_BUTTONCLICK")
	elif key == WidgetManager.KEYCODE_ESCAPE:
		super.button_depress(ID_NO)

func update_advanced_page() -> void:
	left_page_button.set_visible(advanced_page != 1)
	right_page_button.set_visible(advanced_page != PvZ.ADVANCEDOPTIONS_MAX_PAGES)
	var pages := [
		[debug_mode_checkbox, discord_checkbox, bank_keybinds_checkbox, zero_nine_format_checkbox],
		[speed_edit_widget, auto_collect_suns_checkbox, auto_collect_coins_checkbox, zombie_healthbars_checkbox, plant_healthbars_checkbox],
		[reload_languages_button, language_button, reload_resource_packs_button, resource_pack_button],
		[real_hardware_acceleration_checkbox, custom_cursor_checkbox],
	]
	for i in pages.size():
		for w in pages[i]:
			w.set_visible(false)
	if advanced_page >= 1 and advanced_page <= pages.size():
		for w in pages[advanced_page - 1]:
			w.set_visible(true)

func update() -> void:
	var down := game_advanced_button.is_down
	game_advanced_button.text_down_offset_x = 1 if down else 0
	game_advanced_button.text_down_offset_y = 1 if down else 0
	if not advanced_mode:
		return
	var bright := Res.get_font("FONT_DWARVENTODCRAFT18BRIGHTGREENINSET")
	if speed_edit_widget.has_focus and speed_edit_widget.font != bright:
		speed_edit_widget.font = bright
	if speed_edit_prev_text != speed_edit_widget.text:
		if speed_edit_widget.text == "" or speed_edit_widget.text == " ":
			speed_edit_widget.text = speed_edit_prev_text
		if not speed_edit_widget.text.strip_edges().is_valid_int():
			speed_edit_widget.text = speed_edit_prev_text
			return
		var num := int(speed_edit_widget.text)
		if num < PvZ.SPEED_MODIFIER_MIN:
			speed_edit_widget.text = str(PvZ.SPEED_MODIFIER_MIN)
		elif num > PvZ.SPEED_MODIFIER_MAX:
			speed_edit_widget.text = str(PvZ.SPEED_MODIFIER_MAX)
		speed_edit_prev_text = speed_edit_widget.text

func resize_language_button() -> void:
	language_button.resize(language_button.x, language_button.y, language_button.font.string_width(TodStrings.translate(language_button.label)), language_button.height)

func resize_resource_pack_button() -> void:
	resource_pack_button.resize(resource_pack_button.x, resource_pack_button.y, resource_pack_button.font.string_width(TodStrings.translate(resource_pack_button.label)), resource_pack_button.height)

func button_press(_bid: int, _count: int = 1) -> void:
	App.play_sample("SOUND_GRAVEBUTTON")

## LawnApp::KillNewOptionsDialog reads the widgets back into the app before the dialog dies.
func apply_options() -> void:
	var want_3d := real_hardware_acceleration_checkbox.is_checked()
	var want_windowed := not fullscreen_checkbox.is_checked()
	if advanced_mode:
		App.discord_presence = discord_checkbox.is_checked()
		App.bank_keybinds = bank_keybinds_checkbox.is_checked()
		App.zero_nine_bank_format = zero_nine_format_checkbox.is_checked()
		App.speed_modifier = int(speed_edit_widget.text) if speed_edit_widget.text.is_valid_int() else App.speed_modifier
		App.auto_collect_suns = auto_collect_suns_checkbox.is_checked()
		App.auto_collect_coins = auto_collect_coins_checkbox.is_checked()
		App.zombie_healthbars = zombie_healthbars_checkbox.is_checked()
		App.plant_healthbars = plant_healthbars_checkbox.is_checked()
		# LawnApp::ToggleDebugMode
		App.tod_cheat_keys = debug_mode_checkbox.is_checked()
		App.debug_keys_enabled = App.tod_cheat_keys
		if App.tod_cheat_keys and App.player_info:
			App.player_info.has_used_cheat_keys = 1  # LawnApp::UpdatePlayTimeStats
		App.switch_screen_mode(want_windowed, want_3d, false)
		var cc := custom_cursor_checkbox.is_checked()
		if App.custom_cursor != cc:
			App.custom_cursor = cc
			App.set_cursor(App.cursor_num)
	else:
		App.accel_3d = hardware_acceleration_checkbox.is_checked()
		App.switch_screen_mode(want_windowed, want_3d, false)

func button_depress(bid: int) -> void:
	super.button_depress(bid)
	match bid:
		NEW_OPTIONS_ALMANAC:
			var almanac := App.do_almanac_dialog(PvZ.SEED_NONE, PvZ.ZOMBIE_INVALID)
			await almanac.wait_for_result(true)
		NEW_OPTIONS_ADVANCED:
			App.kill_new_options_dialog()
			App.do_advanced_options(from_game_selector, x, y)
			App.play_sample("SOUND_BUTTONCLICK")
		NEW_OPTIONS_MAIN_MENU:
			if App.board and App.board.need_save_game():
				App.do_confirm_back_to_main()
			elif App.board and App.board.cut_scene and App.board.cut_scene.is_survival_repick():
				App.do_confirm_back_to_main()
			else:
				App.board_result = PvZ.BOARDRESULT_QUIT
				App.do_back_to_main(true)
		NEW_OPTIONS_RESTART:
			if App.board:
				var title := "[RESTART_LEVEL_HEADER]"
				var message := "[RESTART_LEVEL_BODY]"
				if App.is_puzzle_mode():
					title = "[RESTART_PUZZLE_HEADER]"
					message = "[RESTART_PUZZLE_BODY]"
				elif App.is_challenge_mode():
					title = "[RESTART_CHALLENGE_HEADER]"
					message = "[RESTART_CHALLENGE_BODY]"
				elif App.is_survival_mode():
					title = "[RESTART_SURVIVAL_HEADER]"
					message = "[RESTART_SURVIVAL_BODY]"
				var d: LawnDialog = App.do_dialog(PvZ.DIALOG_CONFIRM_RESTART, true, title, message, "", BUTTONS_YES_NO)
				d.lawn_yes_button.label = "[RESTART_BUTTON]"
				d.lawn_no_button.label = "[DIALOG_BUTTON_CANCEL]"
				if await d.wait_for_result(true) == ID_YES:
					App.music.stop_all_music()
					App.sound_system.cancel_paused_foley()
					App.kill_new_options_dialog()
					App.board_result = PvZ.BOARDRESULT_RESTART
					App.saw_yeti = App.board.killed_yeti
					if App.playing_quickplay:
						App.start_quick_play()
					else:
						App.pre_new_game(App.game_mode, false)
					App.play_sample("SOUND_BUTTONCLICK")
		NEW_OPTIONS_RELOAD_LANGUAGES:
			App.reload_languages()
			if not App.languages.has(App.language):
				App.language = App._sorted_language_names()[0]
				App.language_index = 0
			App.load_current_language()
			resize_language_button()
		NEW_OPTIONS_LANGUAGE:
			App.switch_language()
			resize_language_button()
		NEW_OPTIONS_RELOAD_RESOURCE_PACKS:
			App.reload_resource_packs()
			resource_pack_button.label = App.get_resource_pack_string()
			resize_resource_pack_button()
		NEW_OPTIONS_RESOURCE_PACK:
			App.switch_resource_pack()
			resource_pack_button.label = App.get_resource_pack_string()
			resize_resource_pack_button()
		NEW_OPTIONS_LEFT_PAGE:
			advanced_page -= 1
			update_advanced_page()
		NEW_OPTIONS_RIGHT_PAGE:
			advanced_page += 1
			update_advanced_page()
		NEW_OPTIONS_BACK:
			App.kill_new_options_dialog()
			App.do_new_options(from_game_selector, x, y)
			App.play_sample("SOUND_BUTTONCLICK")
		ID_YES:
			App.play_sample("SOUND_BUTTONCLICK")
