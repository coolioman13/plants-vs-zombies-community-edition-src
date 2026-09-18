class_name AwardScreen
extends Widget
## Port of AwardScreen (new plant / notes / trophies / QE achievement list).

const AWARDSCREEN_START := 0
const AWARDSCREEN_MENU := 1
const AWARDSCREEN_SLIDER := 2
const ACHIEVEMENT_CLIP_RECT := Rect2i(0, 95 + PvZ.BOARD_OFFSET_Y, PvZ.BOARD_WIDTH, 405)
const BASE_SCROLL_SPEED := 1.75
const SCROLL_ACCEL := 0.1

var start_button: GameButton
var menu_button: GameButton
var fade_in_counter := 180
var achievement_counter := 360
var award_type := PvZ.AWARD_FORLEVEL
var show_achievements := false
var was_drawn := false
var state := ""
var slider: SexySlider
var scroll_position := 0.0
var scroll_amount := 0.0
var max_scroll_position := 0.0

func _init(the_award_type: int = PvZ.AWARD_FORLEVEL, has_achievement: bool = false) -> void:
	clip = false
	award_type = the_award_type
	show_achievements = has_achievement
	load_achievements()

	var lvl: int = App.player_info.level
	start_button = GameButton.new(AWARDSCREEN_START)
	start_button.button_image = Res.get_image("IMAGE_SEEDCHOOSER_BUTTON")
	start_button.over_image = null
	start_button.down_image = null
	start_button.disabled_image = Res.get_image("IMAGE_SEEDCHOOSER_BUTTON_DISABLED")
	start_button.over_overlay_image = Res.get_image("IMAGE_SEEDCHOOSER_BUTTON_GLOW")
	start_button.set_font(Res.get_font("FONT_DWARVENTODCRAFT15"))
	start_button.colors[GameButton.COLOR_LABEL] = Color8(213, 159, 43)
	start_button.colors[GameButton.COLOR_LABEL_HILITE] = Color8(213, 159, 43)
	start_button.resize(324 + PvZ.BOARD_ADDITIONAL_WIDTH, 500 + PvZ.BOARD_OFFSET_Y, 156, 42)
	start_button.text_offset_y = -1
	start_button.parent_widget = self

	menu_button = GameButton.new(AWARDSCREEN_MENU)
	menu_button.label = "[AWARD_MAIN_MENU_BUTTON]"
	menu_button.button_image = Res.get_image("IMAGE_SEEDCHOOSER_BUTTON2")
	menu_button.over_image = Res.get_image("IMAGE_SEEDCHOOSER_BUTTON2_GLOW")
	menu_button.down_image = null
	menu_button.set_font(Res.get_font("FONT_BRIANNETOD12"))
	menu_button.colors[GameButton.COLOR_LABEL] = Color8(42, 42, 90)
	menu_button.colors[GameButton.COLOR_LABEL_HILITE] = Color8(42, 42, 90)
	menu_button.resize(1157, 16, 111, 26)
	menu_button.text_offset_y = 1
	menu_button.parent_widget = self
	if not App.has_finished_adventure() and lvl <= 3:
		menu_button.btn_no_draw = true
		menu_button.disabled = true

	if award_type == PvZ.AWARD_CREDITS_ZOMBIENOTE:
		start_button.label = "[ROLL_CREDITS]"
		start_button.button_image = Res.get_image("IMAGE_CREDITS_PLAYBUTTON")
		start_button.over_image = null
		start_button.down_image = null
		start_button.disabled_image = null
		start_button.over_overlay_image = null
		start_button.set_font(Res.get_font("FONT_HOUSEOFTERROR20"))
		start_button.colors[GameButton.COLOR_LABEL] = Color8(255, 255, 255)
		start_button.colors[GameButton.COLOR_LABEL_HILITE] = Color8(213, 159, 43)
		start_button.resize(325, 505, 190, 73)
		start_button.text_offset_x = 33
		start_button.text_offset_y = -2
		start_button.button_offset_x = -2
		start_button.button_offset_y = 8
	elif award_type == PvZ.AWARD_HELP_ZOMBIENOTE or not App.is_adventure_mode():
		start_button.label = "[MAIN_MENU_BUTTON]"
		menu_button.btn_no_draw = true
		menu_button.disabled = true
	elif lvl == 1:
		start_button.label = "[CONTINUE_BUTTON]"
		menu_button.btn_no_draw = true
		menu_button.disabled = true
	elif lvl == 15:
		start_button.label = "[VIEW_ALMANAC_BUTTON]"
	elif lvl == 25 or lvl == 35 or lvl == 45:
		start_button.label = "[CONTINUE_BUTTON]"
	else:
		start_button.label = "[NEXT_LEVEL_BUTTON]"

	if App.is_first_time_adventure_mode() and lvl == 25 and App.is_trial_stage_locked() and not App.player_info.has_seen_upsell:
		menu_button.btn_no_draw = true
		menu_button.disabled = true
	elif App.has_finished_adventure():
		start_button.label = "[CONTINUE_BUTTON]"
		menu_button.btn_no_draw = true
		menu_button.disabled = true

	if not show_achievements:
		start_sounds()

	slider = SexySlider.new(Res.get_image("IMAGE_OPTIONS_SLIDERSLOT_PLANT"), Res.get_image("IMAGE_OPTIONS_SLIDERKNOB_PLANT"), AWARDSCREEN_SLIDER, self)
	slider.set_value(maxf(0.0, minf(max_scroll_position, scroll_position)))
	slider.horizontal = false
	slider.resize(180 + PvZ.BOARD_ADDITIONAL_WIDTH, ACHIEVEMENT_CLIP_RECT.position.y, 20, ACHIEVEMENT_CLIP_RECT.size.y)
	slider.thumb_offset_x = -5
	slider.no_draw = true
	was_drawn = menu_button.btn_no_draw

func _pending_achievement(i: int) -> bool:
	var pi := App.player_info
	return pi.earned_achievements[i] and not pi.shown_achievements[i] and Achievements.return_show_in_awards(i)

func load_achievements() -> void:
	if show_achievements:
		for i in PvZ.NUM_ACHIEVEMENTS:
			if _pending_achievement(i):
				show_achievements = true
				break
			else:
				show_achievements = false
		App.write_current_user_config()

func is_paper_note() -> bool:
	if award_type == PvZ.AWARD_CREDITS_ZOMBIENOTE or award_type == PvZ.AWARD_HELP_ZOMBIENOTE:
		return true
	var lvl: int = App.player_info.level
	return App.is_adventure_mode() and lvl in [10, 20, 30, 40, 50]

func draw_bottom(g: Graphics, title: String, award: String, message: String) -> void:
	g.draw_image(Res.get_image("IMAGE_AWARDSCREEN_BACK"), 0, 0)
	TodStrings.draw_string(g, title, PvZ.BOARD_WIDTH / 2, 58 + PvZ.BOARD_OFFSET_Y, Res.get_font("FONT_DWARVENTODCRAFT24"), Color8(213, 159, 43), PvZ.DS_ALIGN_CENTER)
	TodStrings.draw_string(g, award, PvZ.BOARD_WIDTH / 2, 326 + PvZ.BOARD_OFFSET_Y, Res.get_font("FONT_DWARVENTODCRAFT18YELLOW"), Color.WHITE, PvZ.DS_ALIGN_CENTER)
	TodStrings.draw_string_wrapped(g, message, Rect2i(285 + PvZ.BOARD_ADDITIONAL_WIDTH, 360 + PvZ.BOARD_OFFSET_Y, 230, 90), Res.get_font("FONT_BRIANNETOD16"), Color8(40, 50, 90), PvZ.DS_ALIGN_CENTER_VERTICAL_MIDDLE)
	state = award

func draw_award_seed(g: Graphics) -> void:
	var st := App.get_award_seed_for_level(App.player_info.level - 1)
	var award := Plant.get_name_string(st, PvZ.SEED_NONE)
	var message: String
	if App.is_trial_stage_locked() and st >= PvZ.SEED_SQUASH and st != PvZ.SEED_TANGLEKELP:
		message = "[AVAILABLE_IN_FULL_VERSION]"
	else:
		message = Plant.get_tool_tip(st)
	draw_bottom(g, "[NEW_PLANT]", award, message)
	var sg := g.copy()
	sg.set_scale(2, 2, 350, 129)
	SeedPacket.draw_seed_packet(sg, 350 + PvZ.BOARD_ADDITIONAL_WIDTH, 129 + PvZ.BOARD_OFFSET_Y, st, PvZ.SEED_NONE, 0, 255, true, false)

func _draw_note(g: Graphics, bg: String, bg_x: int, bg_y: int, note: String, nx: int, ny: int) -> void:
	g.draw_image_scaled_size(Res.get_image(bg), bg_x, bg_y, 2800, 1200)
	g.draw_image(Res.get_image("IMAGE_ZOMBIE_NOTE"), 80 + PvZ.BOARD_ADDITIONAL_WIDTH, 80 + PvZ.BOARD_OFFSET_Y)
	g.draw_image(Res.get_image(note), nx, ny)
	TodStrings.draw_string(g, "[FOUND_NOTE]", PvZ.BOARD_WIDTH / 2, 70 + PvZ.BOARD_OFFSET_Y, Res.get_font("FONT_DWARVENTODCRAFT24"), Color8(255, 200, 0, 255), PvZ.DS_ALIGN_CENTER)

func draw(g: Graphics) -> void:
	g.set_linear_blend(true)
	var lvl: int = App.player_info.level
	var aw := PvZ.BOARD_ADDITIONAL_WIDTH
	var oy := PvZ.BOARD_OFFSET_Y
	if award_type == PvZ.AWARD_CREDITS_ZOMBIENOTE:
		g.set_color(Color8(125, 200, 255, 255))
		g.set_colorize_images(true)
		g.draw_image_scaled_size(Res.get_image("IMAGE_BACKGROUND6BOSS"), -900, -400, 2800, 1200)
		g.set_colorize_images(false)
		g.set_color(Color8(0, 0, 0, 64))
		g.fill_rect(0, 525, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
		g.draw_image(Res.get_image("IMAGE_ZOMBIE_NOTE"), 75 + aw, 60 + oy)
		g.draw_image_scaled_size(Res.get_image("IMAGE_CREDITS_ZOMBIENOTE"), 149 + aw, 103 + oy, 475, 325)
		state = "[DISCORD_CREDITS_NOTE]"
	elif award_type == PvZ.AWARD_HELP_ZOMBIENOTE:
		g.draw_image_scaled_size(Res.get_image("IMAGE_BACKGROUND1"), -700, -300, 2800, 1200)
		g.draw_image(Res.get_image("IMAGE_ZOMBIE_NOTE"), 80 + aw, 80 + oy)
		g.draw_image(Res.get_image("IMAGE_ZOMBIE_NOTE_HELP"), 131 + aw, 132 + oy)
		state = "[DISCORD_HELP_NOTE]"
	elif not App.is_adventure_mode():
		if App.earned_gold_trophy():
			draw_bottom(g, "[BEAT_GAME_MESSAGE1]", "[GOLD_SUNFLOWER_TROPHY]", "[BEAT_GAME_MESSAGE2]")
			g.tod_draw_image_cel_center_scaled_f(Res.get_image("IMAGE_SUNFLOWER_TROPHY"), 325 + aw, 65 + oy, 1, 0.6, 0.6)
		else:
			var msg: String
			if App.is_survival_mode():
				var n := App.get_num_trophies(PvZ.CHALLENGE_PAGE_SURVIVAL)
				msg = "[YOU_UNLOCKED_A_SURVIVAL]" if n <= 7 else "[YOU_UNLOCKED_ENDLESS_SURVIVAL]" if n == 10 else "[EARN_MORE_TROPHIES_FOR_ENDLESS_SURVIVAL]"
			elif App.is_scary_potter_level():
				msg = "[UNLOCKED_VASEBREAKER_LEVEL]"
			elif App.is_puzzle_mode():
				msg = "[UNLOCKED_I_ZOMBIE_LEVEL]"
			else:
				msg = "[CHALLENGE_UNLOCKED]" if App.get_num_trophies(PvZ.CHALLENGE_PAGE_CHALLENGE) <= 17 else "[GET_MORE_TROPHIES]"
			draw_bottom(g, "[GOT_TROPHY]", "[TROPHY]", msg)
			var trophy := Res.get_image("IMAGE_TROPHY_HI_RES")
			g.draw_image(trophy, PvZ.BOARD_WIDTH / 2 - trophy.width / 2, 137 + oy)
	elif lvl == 5:
		draw_bottom(g, "[GOT_SHOVEL]", "[SHOVEL]", "[SHOVEL_DESCRIPTION]")
		var img := Res.get_image("IMAGE_SHOVEL_HI_RES")
		g.draw_image(img, PvZ.BOARD_WIDTH / 2 - img.width / 2, 137 + oy)
	elif lvl == 10:
		_draw_note(g, "IMAGE_BACKGROUND1", -700 + aw, -300 + oy, "IMAGE_ZOMBIE_NOTE1", 131 + aw, 132 + oy)
		state = _zombie_note_state(lvl)
	elif lvl == 15:
		draw_bottom(g, "[FOUND_SUBURBAN_ALMANAC]", "[SUBURBAN_ALMANAC]", "[SUBURBAN_ALMANAC_DESCRIPTION]")
		var img := Res.get_image("IMAGE_ALMANAC")
		g.draw_image(img, PvZ.BOARD_WIDTH / 2 - img.width / 2, 160 + oy)
	elif lvl == 20:
		_draw_note(g, "IMAGE_BACKGROUND2", -700 + aw, -300 + oy, "IMAGE_ZOMBIE_NOTE2", 133 + aw, 127 + oy)
		state = _zombie_note_state(lvl)
	elif lvl == 25:
		draw_bottom(g, "[FOUND_KEYS]", "[KEYS]", "[KEYS_DESCRIPTION]")
		var img := Res.get_image("IMAGE_CARKEYS")
		g.draw_image(img, PvZ.BOARD_WIDTH / 2 - img.width / 2, 160 + oy)
	elif lvl == 30:
		_draw_note(g, "IMAGE_BACKGROUND1", -700 + aw, -300 + oy, "IMAGE_ZOMBIE_NOTE3", 120 + aw, 117 + oy)
		state = _zombie_note_state(lvl)
	elif lvl == 35:
		draw_bottom(g, "[FOUND_TACO]", "[TACO]", "[TACO_DESCRIPTION]")
		var img := Res.get_image("IMAGE_TACO")
		g.draw_image(img, PvZ.BOARD_WIDTH / 2 - img.width / 2, 160 + oy)
	elif lvl == 40:
		# The decomp passes BOARD_OFFSET_Y to the width here instead of the y position.
		_draw_note(g, "IMAGE_BACKGROUND2", -700 + aw, -300, "IMAGE_ZOMBIE_NOTE4", 102 + aw, 117 + oy)
		state = _zombie_note_state(lvl)
	elif lvl == 45:
		draw_bottom(g, "[FOUND_WATERING_CAN]", "[WATERING_CAN]", "[WATERING_CAN_DESCRIPTION]")
		var img := Res.get_image("IMAGE_WATERINGCAN")
		g.draw_image(img, PvZ.BOARD_WIDTH / 2 - img.width / 2, 160 + oy)
	elif lvl == 50:
		_draw_note(g, "IMAGE_BACKGROUND1", -700 + aw, -300 + oy, "IMAGE_ZOMBIE_FINAL_NOTE", 114 + aw, 138 + oy)
		state = _zombie_note_state(lvl)
	elif lvl == 1 and App.has_finished_adventure():
		draw_bottom(g, "[WIN_MESSAGE1]", "[SILVER_SUNFLOWER_TROPHY]", "[WIN_MESSAGE2]")
		g.tod_draw_image_cel_center_scaled_f(Res.get_image("IMAGE_SUNFLOWER_TROPHY"), 325 + aw, 65 + oy, 0, 0.6, 0.6)
	else:
		draw_award_seed(g)

	if show_achievements:
		g.draw_image(Res.get_image("IMAGE_CHALLENGE_BACKGROUND"), 0, 0)
		start_button.label = "[CONTINUE_BUTTON]"
		TodStrings.draw_string(g, "ACHIEVEMENTS", 400 + aw, 58 + oy, Res.get_font("FONT_HOUSEOFTERROR28"), Color8(220, 220, 220), PvZ.DS_ALIGN_CENTER)
		menu_button.btn_no_draw = true
		var cg := g.copy()
		cg.set_clip_rect_r(Rect2(ACHIEVEMENT_CLIP_RECT))
		var total_shown := 0
		var max_scroll := 0
		var portraits := Res.get_image("IMAGE_ACHIEVEMENTS_PORTRAITS")
		for i in PvZ.NUM_ACHIEVEMENTS:
			if _pending_achievement(i):
				total_shown += 1
				var ach_name := "[ACHIEVEMENT_%s_TITLE]" % Achievements.return_achievement_name(i)
				var ach_desc := "[ACHIEVEMENT_%s_DESCRIPTION]" % Achievements.return_achievement_name(i)
				var text_rect := Rect2i(80, 30, 320, 230)
				var px := PvZ.BOARD_WIDTH / 2 - text_rect.size.x / 2 - 35
				var offset := 75
				var py := int(20 + total_shown * offset - scroll_position + oy)
				text_rect.position.x += px
				text_rect.position.y += py - 2
				cg.draw_image_cel(portraits, px, py, i)
				TodStrings.draw_string(cg, ach_name, text_rect.position.x, py + 23, Res.get_font("FONT_DWARVENTODCRAFT24"), Color8(255, 200, 0, 255), PvZ.DS_ALIGN_LEFT)
				TodStrings.draw_string_wrapped(cg, ach_desc, text_rect, Res.get_font("FONT_DWARVENTODCRAFT12"), Color8(255, 255, 255), PvZ.DS_ALIGN_LEFT)
				max_scroll += offset
		max_scroll_position = maxf(0, max_scroll - ACHIEVEMENT_CLIP_RECT.size.y - 5)
		slider.slider_draw(g)
	else:
		if award_type == PvZ.AWARD_HELP_ZOMBIENOTE or not App.is_adventure_mode():
			start_button.label = "[MAIN_MENU_BUTTON]"
		elif lvl == 1:
			start_button.label = "[CONTINUE_BUTTON]"
		elif lvl == 15:
			start_button.label = "[VIEW_ALMANAC_BUTTON]"
		elif lvl == 25 or lvl == 35 or lvl == 45:
			start_button.label = "[CONTINUE_BUTTON]"
		else:
			start_button.label = "[NEXT_LEVEL_BUTTON]"
		if App.has_finished_adventure():
			start_button.label = "[CONTINUE_BUTTON]"
		menu_button.btn_no_draw = was_drawn
	menu_button.draw(g)
	start_button.draw(g)

	var fade_alpha := Tod.animate_curve(180, 0, fade_in_counter, 255, 0, Tod.CURVE_LINEAR)
	g.set_color(Tod.rgba(0, 0, 0, fade_alpha) if is_paper_note() else Tod.rgba(255, 255, 255, fade_alpha))
	g.fill_rect(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)

func _zombie_note_state(lvl: int) -> String:
	return Tod.replace_string("[DISCORD_ZOMBIE_NOTE]", "{LEVEL}", App.get_stage_string(lvl).substr(1))

func update() -> void:
	super.update()
	if App.get_dialog_count() > 0:
		return
	start_button.update()
	menu_button.update()
	if not (slider.is_over or slider.dragging):
		App.set_cursor(App.CURSOR_HAND if (start_button.is_mouse_over() or menu_button.is_mouse_over()) else App.CURSOR_POINTER)
	if fade_in_counter > 0:
		fade_in_counter -= 1
	if achievement_counter > 0:
		achievement_counter -= 1
	scroll_position = clampf(scroll_position + scroll_amount * (BASE_SCROLL_SPEED + absf(scroll_amount) * SCROLL_ACCEL), 0, max_scroll_position)
	scroll_amount *= (1.0 - SCROLL_ACCEL)
	if max_scroll_position != 0:
		slider.set_value(maxf(0.0, minf(max_scroll_position, scroll_position)) / max_scroll_position)
	slider.visible = max_scroll_position != 0 and show_achievements

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	add_widget(slider)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	remove_widget(slider)

func key_char(ch: String) -> void:
	if ch == " " or ch == "\r" or ch == "":
		start_button_pressed()

func exit_screen() -> void:
	if App.playing_quickplay:
		App.kill_game_selector()
		App.show_game_selector()
	elif award_type == PvZ.AWARD_CREDITS_ZOMBIENOTE:
		App.kill_award_screen()
		App.show_credit_screen()
	elif award_type == PvZ.AWARD_HELP_ZOMBIENOTE:
		App.kill_award_screen()
		App.show_game_selector()
	elif App.is_survival_mode():
		App.kill_award_screen()
		App.show_challenge_screen(PvZ.CHALLENGE_PAGE_SURVIVAL)
	elif App.is_puzzle_mode():
		App.kill_award_screen()
		App.show_challenge_screen(PvZ.CHALLENGE_PAGE_PUZZLE)
	elif App.is_challenge_mode():
		App.kill_award_screen()
		App.show_challenge_screen(PvZ.CHALLENGE_PAGE_CHALLENGE)
	else:
		var lvl: int = App.player_info.level
		if lvl == 1:
			App.kill_award_screen()
			if App.has_finished_adventure():
				App.show_award_screen(PvZ.AWARD_CREDITS_ZOMBIENOTE, true)
			else:
				App.pre_new_game(PvZ.GAMEMODE_ADVENTURE, false)
		else:
			if lvl == 15:
				var almanac := App.do_almanac_dialog()
				await almanac.wait_for_result()
			elif lvl == 25:
				var store := App.show_store_screen()
				store.setup_for_intro(301)
				await store.wait_for_result(true)
				if store.purchased_full_version:
					App.kill_award_screen()
					App.show_game_selector()
					return
				if App.is_trial_stage_locked():
					App.kill_award_screen()
					App.pre_new_game(PvZ.GAMEMODE_UPSELL, false)
					if not App.player_info.has_seen_upsell:
						App.board.store_button.btn_no_draw = true
						App.player_info.has_seen_upsell = 1
					return
			elif lvl == 35:
				var store := App.show_store_screen()
				store.setup_for_intro(601)
				await store.wait_for_result(true)
			elif lvl == 42:
				var store := App.show_store_screen()
				store.setup_for_intro(3100)
				await store.wait_for_result(true)
			elif lvl == 45:
				App.kill_award_screen()
				App.pre_new_game(PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN, false)
				App.zen_garden.setup_for_zen_tutorial()
				return
			App.kill_award_screen()
			App.pre_new_game(PvZ.GAMEMODE_ADVENTURE, false)

func start_button_pressed() -> void:
	if App.get_dialog(PvZ.DIALOG_STORE):
		return
	if show_achievements:
		var pi := App.player_info
		for i in PvZ.NUM_ACHIEVEMENTS:
			if pi.earned_achievements[i] and not pi.shown_achievements[i]:
				pi.shown_achievements[i] = true
		show_achievements = false
		fade_in_counter = 180
		if award_type == PvZ.AWARD_ACHIEVEMENTONLY:
			exit_screen()
		else:
			start_sounds()
		return
	exit_screen()

func mouse_down(_mx: int, _my: int, click_count: int) -> void:
	if click_count == 1 and (start_button.is_mouse_over() or menu_button.is_mouse_over()):
		App.play_sample("SOUND_TAP")

func mouse_up(_mx: int, _my: int, click_count: int) -> void:
	if click_count == 1:
		if start_button.is_mouse_over():
			start_button_pressed()
		if menu_button.is_mouse_over():
			var pi := App.player_info
			for i in PvZ.NUM_ACHIEVEMENTS:
				if pi.earned_achievements[i] and not pi.shown_achievements[i]:
					pi.shown_achievements[i] = true
			App.kill_award_screen()
			App.show_game_selector()

func slider_val(sid: int, v: float) -> void:
	if not show_achievements:
		return
	if sid == AWARDSCREEN_SLIDER:
		scroll_position = v * max_scroll_position

func mouse_wheel(delta: int) -> bool:
	if not show_achievements:
		return false
	scroll_amount -= BASE_SCROLL_SPEED * delta
	scroll_amount -= scroll_amount * SCROLL_ACCEL
	return true

func start_sounds() -> void:
	if is_paper_note():
		App.music.stop_all_music()
		start_button.y += 20
		App.play_foley(PvZ.FOLEY_PAPER)
	else:
		App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_ZEN_GARDEN)
