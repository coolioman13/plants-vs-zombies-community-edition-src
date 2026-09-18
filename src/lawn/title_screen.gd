class_name TitleScreen
extends Widget
## Port of TitleScreen (loading screen with the sod roll bar).

enum { TITLESTATE_WAITING_FOR_FIRST_DRAW, TITLESTATE_POPCAP_LOGO, TITLESTATE_PARTNER_LOGO, TITLESTATE_SCREEN }
enum { TITLESCREEN_START, TITLESCREEN_REGISTER }
const KEYCODE_UNKNOWN := 0
const KEYCODE_ASCIIEND := 0x7F

var start_button: HyperlinkWidget
var cur_bar_width := 0.0
var total_bar_width := 314.0
var bar_vel := 0.2
var bar_start_progress := 0.0
var register_clicked := false
var loading_thread_complete := false
var title_age := 0
var quick_load_key := KEYCODE_UNKNOWN
var need_register := false
var need_show_register_box := false
var drawn_yet := false
var need_to_init := true
var prev_loading_percent := 0.0
var title_state := TITLESTATE_WAITING_FOR_FIRST_DRAW
var title_state_counter := 0
var title_state_duration := 0
var display_partner_logo := false
var loader_screen_is_loaded := false

func _init() -> void:
	start_button = HyperlinkWidget.new(TITLESCREEN_START, self)
	start_button.color = Color8(218, 184, 33)
	start_button.over_color = Color8(250, 90, 15)
	start_button.underline_size = 0
	start_button.disabled = true
	start_button.visible = false

func draw_to_preload(g: Graphics) -> void:
	g.draw_image_f(Res.get_image("IMAGE_PLANTSHADOW"), 1000.0, -50.0)

func draw(g: Graphics) -> void:
	g.set_linear_blend(true)
	if title_state == TITLESTATE_WAITING_FOR_FIRST_DRAW:
		g.set_color(Color.BLACK)
		g.fill_rect(0, 0, width, height)
		drawn_yet = true
		return

	if title_state == TITLESTATE_POPCAP_LOGO:
		g.set_color(Color.BLACK)
		g.fill_rect(0, 0, width, height)
		var alpha := 255
		if title_state_counter < title_state_duration - 50:
			if not display_partner_logo:
				alpha = Tod.animate_curve(50, 0, title_state_counter, 255, 0, Tod.CURVE_LINEAR)
		else:
			alpha = Tod.animate_curve(title_state_duration, title_state_duration - 50, title_state_counter, 0, 255, Tod.CURVE_LINEAR)
		var logo := Res.get_image("IMAGE_POPCAP_LOGO")
		g.set_colorize_images(true)
		g.set_color(Tod.rgba(255, 255, 255, alpha))
		g.draw_image(logo, Tod.idiv(width - logo.width, 2), Tod.idiv(height - logo.height, 2))
		g.set_colorize_images(false)
		return

	if title_state == TITLESTATE_PARTNER_LOGO:
		g.set_color(Color.BLACK)
		g.fill_rect(0, 0, width, height)
		g.set_colorize_images(true)
		var alpha := 255
		var logo := Res.get_image("IMAGE_POPCAP_LOGO")
		if title_state_counter >= title_state_duration - 35:
			alpha = Tod.animate_curve(title_state_duration, title_state_duration - 35, title_state_counter, 0, 255, Tod.CURVE_LINEAR)
			g.set_color(Tod.rgba(255, 255, 255, 255 - alpha))
			g.draw_image(logo, Tod.idiv(width - logo.width, 2), Tod.idiv(height - logo.height, 2))
		else:
			alpha = Tod.animate_curve(35, 0, title_state_counter, 255, 0, Tod.CURVE_LINEAR)
		var partner := Res.get_image("IMAGE_PARTNER_LOGO")
		g.set_color(Tod.rgba(255, 255, 255, alpha))
		if partner:
			g.draw_image(partner, Tod.idiv(width - partner.width, 2), Tod.idiv(height - partner.height, 2))
		g.set_colorize_images(false)
		return

	if not loader_screen_is_loaded:
		g.set_color(Color.BLACK)
		g.fill_rect(0, 0, width, height)
		return

	g.draw_image(Res.get_image("IMAGE_TITLESCREEN"), 0, 0)
	if need_to_init:
		return

	var logo := Res.get_image("IMAGE_PVZ_LOGO")
	var logo_y: int
	if title_state_counter > 60:
		logo_y = Tod.animate_curve(100, 60, title_state_counter, -logo.height, 10 + PvZ.BOARD_OFFSET_Y, Tod.CURVE_EASE_IN)
	else:
		logo_y = Tod.animate_curve(60, 50, title_state_counter, 10 + PvZ.BOARD_OFFSET_Y, 15 + PvZ.BOARD_OFFSET_Y, Tod.CURVE_BOUNCE)
	g.draw_image(logo, Tod.idiv(width, 2) - Tod.idiv(logo.width, 2), logo_y)

	var grass_x := start_button.x
	var grass_y := start_button.y - 17
	var grass := Res.get_image("IMAGE_LOADBAR_GRASS")
	g.draw_image(Res.get_image("IMAGE_LOADBAR_DIRT"), grass_x, grass_y + 18)

	if cur_bar_width >= total_bar_width:
		g.draw_image(grass, grass_x, grass_y)
		if loading_thread_complete:
			draw_to_preload(g)
	else:
		var cg := g.copy()
		cg.clip_rect(240 + PvZ.BOARD_ADDITIONAL_WIDTH, grass_y, cur_bar_width, grass.height)
		cg.draw_image(grass, grass_x, grass_y)

		var roll_len := cur_bar_width * 0.94
		var rotation := -roll_len / 180.0 * PI * 2.0
		var scale := Tod.animate_curve_float_time(0, total_bar_width, cur_bar_width, 1.0, 0.5, Tod.CURVE_LINEAR)
		var cap := Res.get_image("IMAGE_REANIM_SODROLLCAP")
		var xf := Tod.scale_rotate_matrix(grass_x + 11.0 + roll_len, grass_y - 3.0 - 35.0 * scale + 35.0, rotation, scale, scale)
		g.blt_matrix(cap, xf, g.clip, Color.WHITE, g.draw_mode, Rect2(0, 0, cap.width, cap.height))

	for r in EffectSystem.reanimations:
		if not r.freed:
			r.draw(g)

func update() -> void:
	super.update()
	App.accel_3d = true  # WIDETWEAK: 3D acceleration fix
	if not drawn_yet:
		return

	if title_state == TITLESTATE_WAITING_FOR_FIRST_DRAW:
		App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_TITLE_CRAZY_DAVE_MAIN_THEME)
		App.start_loading_thread()
		title_state = TITLESTATE_POPCAP_LOGO
		title_state_duration = 150 if display_partner_logo else 200
		title_state_counter = title_state_duration

	if quick_load_key != KEYCODE_UNKNOWN and title_state != TITLESTATE_SCREEN:
		title_state = TITLESTATE_SCREEN
		title_state_duration = 0
		title_state_counter = 100

	title_age += 1
	if title_state_counter > 0:
		title_state_counter -= 1

	if title_state == TITLESTATE_POPCAP_LOGO:
		if title_state_counter == 0:
			title_state = TITLESTATE_SCREEN
			title_state_duration = 200 if display_partner_logo else 100
			title_state_counter = title_state_duration
		return
	elif title_state == TITLESTATE_PARTNER_LOGO:
		if title_state_counter == 0:
			title_state = TITLESTATE_SCREEN
			title_state_duration = 100
			title_state_counter = 100
		return

	if not loader_screen_is_loaded:
		return

	var progress := App.get_loading_thread_progress()
	if need_to_init:
		need_to_init = false
		start_button.label = TodStrings.translate("[LOADING]")
		start_button.set_font(Res.get_font("FONT_BRIANNETOD16"))
		start_button.resize(Tod.idiv(width, 2) - Tod.idiv(Res.get_image("IMAGE_LOADBAR_DIRT").width, 2), 650, int(total_bar_width), 50)
		start_button.visible = true
		var est_total := title_age / progress if progress > 0.000001 else 3000.0
		var load_time := clampf(est_total * (1.0 - progress), 100.0, 3000.0)
		bar_vel = total_bar_width / load_time
		bar_start_progress = minf(progress, 0.9)

	var loading_percent := (progress - bar_start_progress) / (1.0 - bar_start_progress)

	var button_y: int
	if title_state_counter > 10:
		button_y = Tod.animate_curve(60, 10, title_state_counter, PvZ.BOARD_HEIGHT + PvZ.BOARD_OFFSET_Y, 534 + PvZ.BOARD_OFFSET_Y, Tod.CURVE_EASE_IN)
	else:
		button_y = Tod.animate_curve(10, 0, title_state_counter, 534 + PvZ.BOARD_OFFSET_Y, 529 + PvZ.BOARD_OFFSET_Y, Tod.CURVE_BOUNCE)
	start_button.resize(start_button.x, button_y, int(total_bar_width), start_button.height)

	if title_state_counter > 0:
		return

	EffectSystem.update()

	var prev_width := cur_bar_width
	cur_bar_width += bar_vel
	if not loading_thread_complete:
		if cur_bar_width > total_bar_width * 0.99:
			cur_bar_width = total_bar_width * 0.99
	elif cur_bar_width > total_bar_width:
		start_button.label = TodStrings.translate("[CLICK_TO_START]")
		cur_bar_width = total_bar_width

	if loading_percent > prev_loading_percent + 0.01 or loading_thread_complete:
		var bar_w := Tod.animate_curve_float_time(0, 1, loading_percent, 0, total_bar_width, Tod.CURVE_EASE_IN)
		var diff := bar_w - cur_bar_width
		var accel := Tod.animate_curve_float_time(0, 1, loading_percent, 0.0001, 0.00001, Tod.CURVE_LINEAR)
		if loading_thread_complete:
			accel = 0.0001
		bar_vel += diff * absf(diff) * accel
		var min_vel := Tod.animate_curve_float_time(0, 1, loading_percent, 0.2, 0.01, Tod.CURVE_LINEAR)
		var max_vel := 2.0
		if App.tod_cheat_keys:
			min_vel = 0.0
			max_vel = 100.0
		bar_vel = clampf(bar_vel, min_vel, max_vel)
		prev_loading_percent = loading_percent

	if not loading_thread_complete and App.loading_thread_completed:
		loading_thread_complete = true
		start_button.set_disabled(false)
		match quick_load_key:
			KEYCODE_ASCIIEND:
				App.fast_load(PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN)
				return
			0x4D:
				App.loading_completed()
				return
			0x53:
				App.loading_completed()
				App.kill_game_selector()
				App.show_challenge_screen(PvZ.CHALLENGE_PAGE_SURVIVAL)
				return
			0x43:
				App.loading_completed()
				App.kill_game_selector()
				App.show_challenge_screen(PvZ.CHALLENGE_PAGE_CHALLENGE)
				return
			0x55:
				App.loading_completed()
				App.kill_game_selector()
				App.pre_new_game(PvZ.GAMEMODE_UPSELL, false)
				return
			0x49:
				App.loading_completed()
				App.kill_game_selector()
				App.pre_new_game(PvZ.GAMEMODE_INTRO, false)
				return
			0x50:
				App.loading_completed()
				App.kill_game_selector()
				App.show_challenge_screen(PvZ.CHALLENGE_PAGE_PUZZLE)
				return
			0x52:
				App.loading_completed()
				App.kill_game_selector()
				App.show_credit_screen()
				return
			_:
				if App.tod_cheat_keys and App.player_info and quick_load_key == 0x54:
					App.fast_load(PvZ.GAMEMODE_ADVENTURE)
					return
				start_button.set_visible(true)

	var triggers := [total_bar_width * 0.11, total_bar_width * 0.32, total_bar_width * 0.54, total_bar_width * 0.72, total_bar_width * 0.91]
	for i in triggers.size():
		if prev_width < triggers[i] and cur_bar_width >= triggers[i]:
			var rt := PvZ.REANIM_LOADBAR_ZOMBIEHEAD if i == 4 else PvZ.REANIM_LOADBAR_SPROUT
			var px: float = triggers[i] + 480.0
			var py := 511.0
			var sprout := App.add_reanimation(px, py + PvZ.BOARD_OFFSET_Y, 0, rt)
			sprout.anim_rate = 18.0
			sprout.loop_type = Reanimation.REANIM_PLAY_ONCE_AND_HOLD
			if i == 1 or i == 3:
				sprout.override_scale(-1.0, 1.0)
			elif i == 2:
				sprout.set_position(px, py - 5.0 + PvZ.BOARD_OFFSET_Y)
				sprout.override_scale(1.1, 1.3)
			elif i == 4:
				sprout.set_position(px - 20.0, py + PvZ.BOARD_OFFSET_Y)
			App.play_sample("SOUND_LOADINGBAR_FLOWER")
			if i == 4:
				App.play_sample("SOUND_LOADINGBAR_ZOMBIE")

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	wm.add_widget(start_button)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	wm.remove_widget(start_button)

func button_press(_bid: int, _count: int = 1) -> void:
	App.play_sample("SOUND_BUTTONCLICK")

func button_depress(bid: int) -> void:
	match bid:
		TITLESCREEN_START:
			App.loading_completed()
		TITLESCREEN_REGISTER:
			register_clicked = true

func mouse_down(_mx: int, _my: int, _click_count: int) -> void:
	if loading_thread_complete:
		App.play_sample("SOUND_BUTTONCLICK")
		App.loading_completed()

func key_down(key: int) -> void:
	if loading_thread_complete:
		App.play_sample("SOUND_BUTTONCLICK")
		App.loading_completed()
	if App.tod_cheat_keys and App.player_info:
		quick_load_key = key
