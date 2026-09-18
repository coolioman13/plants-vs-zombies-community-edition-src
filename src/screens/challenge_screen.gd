class_name ChallengeScreen
extends Widget
## Port of ChallengeScreen (mini-game / puzzle / survival / limbo pick screen).
## The modes themselves are out of scope for now, but the screen is needed for menus and the upsell cutscene.

const CHALLENGE_SCREEN_BACK := 0
const CHALLENGE_SCREEN_SELECTOR := 1
const CHALLENGE_SCREEN_MODE := 100
const NUM_CHALLENGE_MODES := PvZ.NUM_GAME_MODES - 1
const CHALLENGE_RECT := Rect2i(0, 91 + PvZ.BOARD_OFFSET_Y, PvZ.BOARD_WIDTH, 480)
const BUTTON_HEIGHT := 118
const BASE_SCROLL_SPEED := 1.5
const SCROLL_ACCEL := 0.1

var back_button: NewLawnButton
var challenges_button: NewLawnButton
var challenge_buttons: Array = []
var tool_tip: ToolTipWidget
var page_index := PvZ.CHALLENGE_PAGE_CHALLENGE
var cheat_enable_challenges := false
var unlock_state := PvZ.UNLOCK_OFF
var unlock_state_counter := 0
var unlock_challenge_index := -1
var lock_shake_x := 0.0
var lock_shake_y := 0.0
var scroll_position := 0.0
var scroll_amount := 0.0
var max_scroll_position := 0.0
var slider: SexySlider
var button_y_start_offset := 0
var button_y_offset := 0

func _init(page: int) -> void:
	page_index = page
	clip = false

	var btn2 := Res.get_image("IMAGE_SEEDCHOOSER_BUTTON2")
	var btn2_glow := Res.get_image("IMAGE_SEEDCHOOSER_BUTTON2_GLOW")
	back_button = LawnButtons.make_new_button(CHALLENGE_SCREEN_BACK, self, "[BACK_TO_MENU_BUTTON]", null, btn2, btn2_glow, btn2_glow)
	back_button.text_down_offset_x = 1
	back_button.text_down_offset_y = 1
	back_button.colors[ButtonWidget.COLOR_LABEL] = Color8(42, 42, 90)
	back_button.colors[ButtonWidget.COLOR_LABEL_HILITE] = Color8(42, 42, 90)
	back_button.resize(18 + PvZ.BOARD_OFFSET_X + 35, 568 + PvZ.BOARD_OFFSET_Y, 111, 26)

	challenges_button = LawnButtons.make_new_button(CHALLENGE_SCREEN_SELECTOR, self, "[PAGE_SELECTION_BUTTON]", null, btn2, btn2_glow, btn2_glow)
	challenges_button.text_down_offset_x = 1
	challenges_button.text_down_offset_y = 1
	challenges_button.colors[ButtonWidget.COLOR_LABEL] = Color8(42, 42, 90)
	challenges_button.colors[ButtonWidget.COLOR_LABEL_HILITE] = Color8(42, 42, 90)
	challenges_button.resize(618 + PvZ.BOARD_OFFSET_X + 111 / 2, 568 + PvZ.BOARD_OFFSET_Y, 111, 26)

	for mode in NUM_CHALLENGE_MODES:
		var b := ButtonWidget.new(CHALLENGE_SCREEN_MODE + mode, self)
		challenge_buttons.append(b)
		b.do_finger = more_trophies_needed(mode) == 0
		b.disabled = more_trophies_needed(mode) != 0
		b.frame_no_draw = true
		b.resize(0, 0, 104, BUTTON_HEIGHT)

	tool_tip = ToolTipWidget.new()
	tool_tip.center = true
	tool_tip.visible = false
	update_buttons()

	if App.game_mode != PvZ.GAMEMODE_UPSELL or App.game_scene != PvZ.SCENE_LEVEL_INTRO:
		App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_CHOOSE_YOUR_SEEDS)

	var pi := App.player_info
	if not page_has_content(page_index):
		pass  # nothing on this page to play an unlock animation on
	elif page_index == PvZ.CHALLENGE_PAGE_SURVIVAL and pi.has_new_survival:
		set_unlock_challenge_index(page_index, false)
		pi.has_new_survival = 0
	elif page_index == PvZ.CHALLENGE_PAGE_CHALLENGE and pi.has_new_mini_game:
		set_unlock_challenge_index(page_index, false)
		pi.has_new_mini_game = 0
	elif page_index == PvZ.CHALLENGE_PAGE_PUZZLE:
		if pi.has_new_scary_potter:
			set_unlock_challenge_index(page_index, false)
			pi.has_new_scary_potter = 0
		elif pi.has_new_izombie:
			set_unlock_challenge_index(page_index, true)
			pi.has_new_izombie = 0

	slider = SexySlider.new(Res.get_image("IMAGE_OPTIONS_SLIDERSLOT_PLANT"), Res.get_image("IMAGE_OPTIONS_SLIDERKNOB_PLANT"), 0, self)
	slider.set_value(maxf(0.0, minf(max_scroll_position, scroll_position)))
	slider.horizontal = false
	slider.resize(775 + PvZ.BOARD_OFFSET_X + 19, CHALLENGE_RECT.position.y, 20, CHALLENGE_RECT.size.y)
	slider.thumb_offset_x = -4

func slider_val(sid: int, v: float) -> void:
	if sid == 0:
		scroll_position = v * max_scroll_position

static func get_challenge_definition(mode: int) -> Array:
	return ChallengeDefs.get_def(mode)

static func is_scary_potter_level(mode: int) -> bool:
	return mode >= PvZ.GAMEMODE_SCARY_POTTER_1 and mode <= PvZ.GAMEMODE_SCARY_POTTER_ENDLESS

static func is_i_zombie_level(mode: int) -> bool:
	return mode >= PvZ.GAMEMODE_PUZZLE_I_ZOMBIE_1 and mode <= PvZ.GAMEMODE_PUZZLE_I_ZOMBIE_ENDLESS

func set_unlock_challenge_index(page: int, is_i_zombie: bool = false) -> void:
	unlock_state = PvZ.UNLOCK_SHAKING
	unlock_state_counter = 100
	unlock_challenge_index = 0
	for mode in NUM_CHALLENGE_MODES:
		var d := get_challenge_definition(mode)
		if d[ChallengeDefs.PAGE] != page:
			continue
		var m: int = d[ChallengeDefs.MODE]
		if page != PvZ.CHALLENGE_PAGE_PUZZLE or (not is_i_zombie and is_scary_potter_level(m)) or (is_i_zombie and is_i_zombie_level(m)):
			if accomplishments_needed(mode) <= 0:
				unlock_challenge_index = mode

func _count_beaten(pred: Callable) -> int:
	var n := 0
	for d in ChallengeDefs.DEFS:
		if pred.call(d[ChallengeDefs.MODE]) and App.has_beaten_challenge(d[ChallengeDefs.MODE]):
			n += 1
	return n

func more_trophies_needed(index: int) -> int:
	var d := get_challenge_definition(index)
	var mode: int = d[ChallengeDefs.MODE]
	var page: int = d[ChallengeDefs.PAGE]
	if App.game_mode == PvZ.GAMEMODE_UPSELL and App.game_scene == PvZ.SCENE_LEVEL_INTRO:
		return 1 if mode == PvZ.GAMEMODE_CHALLENGE_FINAL_BOSS else 0

	if App.is_trial_stage_locked():
		if page_index == PvZ.CHALLENGE_PAGE_PUZZLE and mode >= PvZ.GAMEMODE_SCARY_POTTER_4:
			return 1 if mode == PvZ.GAMEMODE_SCARY_POTTER_4 else 2
		elif page_index == PvZ.CHALLENGE_PAGE_CHALLENGE and mode >= PvZ.GAMEMODE_CHALLENGE_RAINING_SEEDS:
			return 1 if mode == PvZ.GAMEMODE_CHALLENGE_RAINING_SEEDS else 2
		elif page_index == PvZ.CHALLENGE_PAGE_SURVIVAL and mode >= PvZ.GAMEMODE_SURVIVAL_NORMAL_STAGE_4:
			return 1 if mode == PvZ.GAMEMODE_SURVIVAL_NORMAL_STAGE_4 else 2

	if page == PvZ.CHALLENGE_PAGE_PUZZLE:
		if is_scary_potter_level(mode):
			var done := _count_beaten(is_scary_potter_level)
			if mode < PvZ.GAMEMODE_SCARY_POTTER_4 or App.has_finished_adventure() or done < 3:
				return clampi(mode - PvZ.GAMEMODE_SCARY_POTTER_1 - done, 0, 9)
			return 1 if mode == PvZ.GAMEMODE_SCARY_POTTER_4 else 2
		elif is_i_zombie_level(mode):
			var done2 := _count_beaten(is_i_zombie_level)
			if mode < PvZ.GAMEMODE_PUZZLE_I_ZOMBIE_4 or App.has_finished_adventure() or done2 < 3:
				return clampi(mode - PvZ.GAMEMODE_PUZZLE_I_ZOMBIE_1 - done2, 0, 9)
			return 1 if mode == PvZ.GAMEMODE_PUZZLE_I_ZOMBIE_4 else 2
		return 0  # falls off the end in the original; never reached for puzzle-page modes

	var idx_in_page: int = d[ChallengeDefs.COL] * 5 + d[ChallengeDefs.ROW]
	if (page == PvZ.CHALLENGE_PAGE_CHALLENGE or page == PvZ.CHALLENGE_PAGE_SURVIVAL) and not App.has_finished_adventure():
		return 0 if idx_in_page < 3 else 1 if idx_in_page == 3 else 2
	var trophies := App.get_num_trophies(page)
	if page == PvZ.CHALLENGE_PAGE_LIMBO:
		return 0
	if App.is_survival_endless(mode):
		return 10 - trophies
	trophies += 3
	return idx_in_page - trophies + 1 if idx_in_page >= trophies else 0

func show_page_buttons() -> bool:
	return App.tod_cheat_keys and page_index != PvZ.CHALLENGE_PAGE_SURVIVAL and page_index != PvZ.CHALLENGE_PAGE_PUZZLE

## Community edition: the original mini-games, puzzles and survival levels are hidden (most are broken), so these
## pages open empty until the mod adds its own modes. The upsell cutscene still needs its buttons.
static func page_has_content(page: int) -> bool:
	if App.game_mode == PvZ.GAMEMODE_UPSELL and App.game_scene == PvZ.SCENE_LEVEL_INTRO:
		return true
	return page != PvZ.CHALLENGE_PAGE_CHALLENGE and page != PvZ.CHALLENGE_PAGE_PUZZLE and page != PvZ.CHALLENGE_PAGE_SURVIVAL

func update_buttons() -> void:
	var has_content := page_has_content(page_index)
	for mode in NUM_CHALLENGE_MODES:
		(challenge_buttons[mode] as ButtonWidget).visible = has_content and get_challenge_definition(mode)[ChallengeDefs.PAGE] == page_index

func accomplishments_needed(index: int) -> int:
	var needed := more_trophies_needed(index)
	var mode: int = get_challenge_definition(index)[ChallengeDefs.MODE]
	if App.is_survival_endless(mode) and needed <= 3 and App.get_num_trophies(PvZ.CHALLENGE_PAGE_SURVIVAL) < 10 \
			and App.has_finished_adventure() and not App.is_trial_stage_locked():
		needed = 1
	return 0 if cheat_enable_challenges else needed

func draw_button(g: Graphics, index: int) -> void:
	var b: ButtonWidget = challenge_buttons[index]
	if not b.visible:
		return
	var wm := App.widget_manager
	b.mouse_visible = CHALLENGE_RECT.has_point(Vector2i(wm.last_mouse_x, wm.last_mouse_y))
	var d := get_challenge_definition(index)
	var page: int = d[ChallengeDefs.PAGE]
	b.x = 38 + d[ChallengeDefs.ROW] * 155 + PvZ.BOARD_OFFSET_X + 19
	button_y_start_offset = CHALLENGE_RECT.position.y + (34 if page == PvZ.CHALLENGE_PAGE_SURVIVAL else 2)
	button_y_offset = BUTTON_HEIGHT + (30 if page == PvZ.CHALLENGE_PAGE_SURVIVAL else 2)
	b.y = int(button_y_start_offset + d[ChallengeDefs.COL] * button_y_offset - scroll_position)
	var px := b.x
	var py := b.y
	if b.is_down:
		px += 1
		py += 1

	if accomplishments_needed(index) > 1:
		g.draw_image(Res.get_image("IMAGE_CHALLENGE_BLANK"), px, py)
		return

	if b.disabled:
		g.color = Color8(92, 92, 92)
		g.colorize_images = true
	if index == unlock_challenge_index:
		if unlock_state == PvZ.UNLOCK_SHAKING:
			g.color = Color8(92, 92, 92)
		elif unlock_state == PvZ.UNLOCK_FADING:
			var c := Tod.animate_curve(50, 25, unlock_state_counter, 92, 255, Tod.CURVE_LINEAR)
			g.color = Color8(c, c, c)
		g.colorize_images = true
	g.set_clip_rect_r(Rect2(CHALLENGE_RECT))
	g.set_scale(0.5, 0.5, px + 13, py + 4)
	var thumbs := Res.get_image("IMAGE_SURVIVAL_THUMBNAILS" if page_index == PvZ.CHALLENGE_PAGE_SURVIVAL else "IMAGE_CHALLENGE_THUMBNAILS")
	g.draw_image_cel(thumbs, px + 13, py + 4, d[ChallengeDefs.IMAGE])
	g.set_scale(1.0, 1.0, px + 13, py + 4)

	var highlight := b.is_over and index != unlock_challenge_index
	g.colorize_images = false
	g.draw_image(Res.get_image("IMAGE_CHALLENGE_WINDOW_HIGHLIGHT" if highlight else "IMAGE_CHALLENGE_WINDOW"), px - 6, py - 2)

	var text_color := Color8(250, 40, 40) if highlight else Color8(42, 42, 90)
	var the_name := TodStrings.translate(d[ChallengeDefs.NAME])
	if b.disabled or (index == unlock_challenge_index and unlock_state == PvZ.UNLOCK_SHAKING):
		the_name = "?"
	TodStrings.draw_string_wrapped(g, the_name, Rect2i(px + 6, py + 74, 94, 33), Res.get_font("FONT_BRIANNETOD12"), text_color, PvZ.DS_ALIGN_CENTER_VERTICAL_MIDDLE)

	var record: int = App.player_info.challenge_records[index]
	var mode: int = d[ChallengeDefs.MODE]
	if index == unlock_challenge_index:
		var lock := Res.get_image("IMAGE_LOCK")
		if unlock_state == PvZ.UNLOCK_FADING:
			lock = Res.get_image("IMAGE_LOCK_OPEN")
			g.color = Color8(255, 255, 255, Tod.animate_curve(25, 0, unlock_state_counter, 255, 0, Tod.CURVE_LINEAR))
			g.colorize_images = true
		g.tod_draw_image_scaled_f(lock, px + 24 + lock_shake_x, py + 9 + lock_shake_y, 0.7, 0.7)
		g.colorize_images = false
	elif record > 0:
		if App.has_beaten_challenge(mode):
			g.draw_image(Res.get_image("IMAGE_MINIGAME_TROPHY"), px - 6, py - 2)
		elif App.is_endless_scary_potter(mode) or App.is_endless_izombie(mode):
			var streak := Tod.replace_number_string(TodStrings.translate("[LONGEST_STREAK]"), "{STREAK}", record)
			var r := Rect2i(px, py + 15, 96, 200)
			TodStrings.draw_string_wrapped(g, streak, r, Res.get_font("FONT_CONTINUUMBOLD14OUTLINE"), Color.WHITE, PvZ.DS_ALIGN_CENTER)
			TodStrings.draw_string_wrapped(g, streak, r, Res.get_font("FONT_CONTINUUMBOLD14"), Color8(255, 0, 0), PvZ.DS_ALIGN_CENTER)
		elif App.is_survival_endless(mode):
			var flags := App.pluralize(record, "[ONE_FLAG]", "[COUNT_FLAGS]")
			TodStrings.draw_string(g, flags, px + 48, py + 48, Res.get_font("FONT_CONTINUUMBOLD14OUTLINE"), Color.WHITE, PvZ.DS_ALIGN_CENTER)
			TodStrings.draw_string(g, flags, px + 48, py + 48, Res.get_font("FONT_CONTINUUMBOLD14"), Color8(255, 0, 0), PvZ.DS_ALIGN_CENTER)
	elif b.disabled:
		g.tod_draw_image_scaled_f(Res.get_image("IMAGE_LOCK"), px + 24, py + 9, 0.7, 0.7)

func draw(g: Graphics) -> void:
	g.set_linear_blend(true)
	g.draw_image(Res.get_image("IMAGE_CHALLENGE_BACKGROUND"), 0, 0)
	TodStrings.draw_string(g, get_page_title(page_index), 400 + PvZ.BOARD_OFFSET_X + 19, 58 + PvZ.BOARD_OFFSET_Y, Res.get_font("FONT_HOUSEOFTERROR28"), Color8(220, 220, 220), PvZ.DS_ALIGN_CENTER)

	if not page_has_content(page_index):
		TodStrings.draw_string(g, "Coming soon!", 400 + PvZ.BOARD_OFFSET_X + 19, CHALLENGE_RECT.position.y + CHALLENGE_RECT.size.y / 2, Res.get_font("FONT_HOUSEOFTERROR28"), Color8(220, 220, 220), PvZ.DS_ALIGN_CENTER)
		max_scroll_position = 0
		tool_tip.draw(g)
		return

	var got := App.get_num_trophies(page_index)
	var total := App.get_total_trophies(page_index)
	var trophy_text := "%d/%d" % [got, total] if total > 0 else TodStrings.translate("[TROPHY_NONE]")
	TodStrings.draw_string(g, trophy_text, 739 + PvZ.BOARD_ADDITIONAL_WIDTH, 73 + PvZ.BOARD_OFFSET_Y, Res.get_font("FONT_DWARVENTODCRAFT12"), Color8(255, 240, 0), PvZ.DS_ALIGN_CENTER)
	g.tod_draw_image_scaled_f(Res.get_image("IMAGE_TROPHY"), 718 + PvZ.BOARD_ADDITIONAL_WIDTH, 26 + PvZ.BOARD_OFFSET_Y, 0.5, 0.5)

	var highest_col := 0
	for mode in NUM_CHALLENGE_MODES:
		# Each button sets its own clip and colour state, like the shared Graphics in the original.
		draw_button(g, mode)
		var d := get_challenge_definition(mode)
		if d[ChallengeDefs.COL] >= highest_col and d[ChallengeDefs.PAGE] == page_index:
			highest_col = d[ChallengeDefs.COL]
	max_scroll_position = maxi(0, highest_col * button_y_offset + BUTTON_HEIGHT + (button_y_start_offset - CHALLENGE_RECT.position.y) - CHALLENGE_RECT.size.y)
	tool_tip.draw(g)

func update() -> void:
	super.update()
	update_tool_tip()
	scroll_position = clampf(scroll_position + scroll_amount * (BASE_SCROLL_SPEED + absf(scroll_amount) * SCROLL_ACCEL), 0, max_scroll_position)
	scroll_amount *= 1.0 - SCROLL_ACCEL
	slider.set_value(maxf(0.0, minf(max_scroll_position, scroll_position)) / max_scroll_position if max_scroll_position != 0 else 0.0)
	slider.visible = max_scroll_position != 0

	if unlock_state_counter > 0:
		unlock_state_counter -= 1
	if unlock_state == PvZ.UNLOCK_SHAKING:
		if unlock_state_counter == 0:
			App.play_foley(PvZ.FOLEY_PAPER)
			unlock_state = PvZ.UNLOCK_FADING
			unlock_state_counter = 50
			lock_shake_x = 0
			lock_shake_y = 0
		else:
			lock_shake_x = Tod.rand_range_float(-2, 2)
			lock_shake_y = Tod.rand_range_float(-2, 2)
	elif unlock_state == PvZ.UNLOCK_FADING and unlock_state_counter == 0:
		unlock_state = PvZ.UNLOCK_OFF
		unlock_state_counter = 0
		unlock_challenge_index = -1

func mouse_wheel(delta: int) -> bool:
	scroll_amount -= BASE_SCROLL_SPEED * delta
	scroll_amount -= scroll_amount * SCROLL_ACCEL
	return true

static func get_page_title(page: int) -> String:
	match page:
		PvZ.CHALLENGE_PAGE_CHALLENGE: return "[PICK_CHALLENGE]"
		PvZ.CHALLENGE_PAGE_PUZZLE: return "[SCARY_POTTER]"
		PvZ.CHALLENGE_PAGE_SURVIVAL: return "[PICK_AREA]"
		PvZ.CHALLENGE_PAGE_LIMBO: return "[LIMBO_PAGE]"
	return "[UNKNOWN_PAGE]"

func is_page_unlocked(page: int) -> bool:
	var pi := App.player_info
	match page:
		PvZ.CHALLENGE_PAGE_CHALLENGE: return App.has_finished_adventure() or pi.has_unlocked_minigames != 0
		PvZ.CHALLENGE_PAGE_PUZZLE: return App.has_finished_adventure() or pi.has_unlocked_puzzle_mode != 0
		PvZ.CHALLENGE_PAGE_SURVIVAL: return App.has_finished_adventure() or pi.has_unlocked_survival_mode != 0
		PvZ.CHALLENGE_PAGE_LIMBO: return App.has_finished_adventure()
	return false

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	add_widget(back_button)
	if PvZ.HAS_PAGE_SELECTOR:
		add_widget(challenges_button)
	for b in challenge_buttons:
		add_widget(b)
	add_widget(slider)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	remove_widget(back_button)
	if PvZ.HAS_PAGE_SELECTOR:
		remove_widget(challenges_button)
	for b in challenge_buttons:
		remove_widget(b)
	remove_widget(slider)

func button_press(_bid: int, _count: int = 1) -> void:
	App.play_sample("SOUND_BUTTONCLICK")

func button_depress(bid: int) -> void:
	if bid == CHALLENGE_SCREEN_BACK:
		App.kill_challenge_screen()
		App.do_back_to_main()
	elif bid == CHALLENGE_SCREEN_SELECTOR:
		App.do_challenge_pages_dialog()
	var mode := bid - CHALLENGE_SCREEN_MODE
	if mode >= 0 and mode < NUM_CHALLENGE_MODES and (challenge_buttons[mode] as ButtonWidget).visible:
		App.kill_challenge_screen()
		App.pre_new_game(mode + 1, true)

func update_tool_tip() -> void:
	var wm := App.widget_manager
	if not wm.mouse_in or not App.active:
		tool_tip.visible = false
		return
	for mode in NUM_CHALLENGE_MODES:
		var d := get_challenge_definition(mode)
		var b: ButtonWidget = challenge_buttons[mode]
		if not (b.visible and b.disabled and b.contains(wm.last_mouse_x, wm.last_mouse_y) and accomplishments_needed(mode) <= 1):
			continue
		tool_tip.x = b.width / 2 + b.x
		tool_tip.y = b.y
		if more_trophies_needed(mode) <= 0:
			continue
		var m: int = d[ChallengeDefs.MODE]
		var label := ""
		if page_index == PvZ.CHALLENGE_PAGE_PUZZLE:
			if is_scary_potter_level(m):
				label = "[FINISH_ADVENTURE_TOOLTIP]" if not App.has_finished_adventure() and m == PvZ.GAMEMODE_SCARY_POTTER_4 else "[ONE_MORE_SCARY_POTTER_TOOLTIP]"
			elif is_i_zombie_level(m):
				label = "[FINISH_ADVENTURE_TOOLTIP]" if not App.has_finished_adventure() and m == PvZ.GAMEMODE_PUZZLE_I_ZOMBIE_4 else "[ONE_MORE_IZOMBIE_TOOLTIP]"
		elif not App.has_finished_adventure() or App.is_trial_stage_locked():
			label = "[FINISH_ADVENTURE_TOOLTIP]"
		elif App.is_survival_endless(m):
			label = "[10_SURVIVAL_TOOLTIP]"
		elif page_index == PvZ.CHALLENGE_PAGE_SURVIVAL:
			label = "[ONE_MORE_SURVIVAL_TOOLTIP]"
		elif page_index == PvZ.CHALLENGE_PAGE_CHALLENGE:
			label = "[ONE_MORE_CHALLENGE_TOOLTIP]"
		else:
			continue
		tool_tip.set_label(label)
		tool_tip.visible = true
		return
	tool_tip.visible = false
