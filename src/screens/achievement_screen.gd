class_name AchievementScreen
extends Widget
## Port of AchievementScreen (the QE achievement shaft below the main menu).

const BASE_SCROLL_SPEED := 5.5
const SCROLL_ACCEL := 0.2

var back_button: NewLawnButton
var rock_button: NewLawnButton
var scroll_position := 0.0
var scroll_amount := 0.0
var max_scroll_position := 0.0
var tween_timer := 0
var goes_down := false

func _init() -> void:
	back_button = LawnButtons.make_new_button(0, self, "", null, Res.get_image("IMAGE_BLANK"),
		Res.get_image("IMAGE_ACHIEVEMENT_BACK_GLOW"), Res.get_image("IMAGE_ACHIEVEMENT_BACK_GLOW"))
	back_button.resize(18 + PvZ.BOARD_ADDITIONAL_WIDTH, int(568 + scroll_position - PvZ.BOARD_OFFSET_Y), 111, 26)
	var more := Res.get_image("IMAGE_ACHIEVEMENT_MORE")
	rock_button = LawnButtons.make_new_button(1, self, "", null, more,
		Res.get_image("IMAGE_ACHIEVEMENT_MORE_HIGHLIGHT"), Res.get_image("IMAGE_ACHIEVEMENT_MORE_HIGHLIGHT"))
	rock_button.resize(710 + PvZ.BOARD_ADDITIONAL_WIDTH, int(470 + scroll_position - PvZ.BOARD_OFFSET_Y), more.width, more.height)

func draw(g: Graphics) -> void:
	var sp := int(scroll_position)
	var aw := PvZ.BOARD_ADDITIONAL_WIDTH
	g.draw_image(Res.get_image("IMAGE_ACHIEVEMENT_SELECTOR_TILE"), 0, -PvZ.BOARD_OFFSET_Y + scroll_position + 30)
	var tile := Res.get_image("IMAGE_ACHIEVEMENT_TILE")
	var china := Res.get_image("IMAGE_ACHIEVEMENT_TILE_CHINA")
	for i in range(1, 71):
		if i == 70:
			g.draw_image(china, 0, china.height * i + sp - 40 - PvZ.BOARD_OFFSET_Y)
		else:
			g.draw_image(tile, 0, tile.height * i + sp - 100)
	g.draw_image(Res.get_image("IMAGE_ACHIEVEMENT_ROCK"), rock_button.x, rock_button.y)

	g.draw_image(Res.get_image("IMAGE_ACHIEVEMENT_BOOKWORM"), aw, 1125 + sp)
	g.draw_image(Res.get_image("IMAGE_ACHIEVEMENT_BEJEWELED"), aw, 2250 + sp)
	g.draw_image(Res.get_image("IMAGE_ACHIEVEMENT_CHUZZLE"), aw, 4500 + sp)
	g.draw_image(Res.get_image("IMAGE_ACHIEVEMENT_PEGGLE"), aw, 6750 + sp)
	g.draw_image(Res.get_image("IMAGE_ACHIEVEMENT_PIPE"), aw, 9000 + sp)
	g.draw_image(Res.get_image("IMAGE_ACHIEVEMENT_ZUMA"), aw, 11250 + sp)

	var title_font := Res.get_font("FONT_DWARVENTODCRAFT15")
	var desc_font := Res.get_font("FONT_DWARVENTODCRAFT12")
	var portraits := Res.get_image("IMAGE_ACHIEVEMENTS_PORTRAITS")
	for i in PvZ.NUM_ACHIEVEMENTS:
		var ach_name := Achievements.return_achievement_name(i)
		var y_pos := 138 + 57 * (i / 2) + sp
		var x_pos := (380 if i % 2 != 0 else 90) + aw + 120
		TodStrings.draw_string(g, "[ACHIEVEMENT_%s_TITLE]" % ach_name, x_pos - 20, y_pos + 16, title_font, Color8(21, 175, 0), PvZ.DS_ALIGN_LEFT)
		g.color = Color.WHITE
		g.font = desc_font
		TextWriter.draw_string_word_wrapped(g, TodStrings.translate("[ACHIEVEMENT_%s_DESCRIPTION]" % ach_name), x_pos - 20, y_pos + 30, 215, 12)
		g.colorize_images = true
		g.color = Color8(255, 255, 255) if App.player_info.earned_achievements[i] else Color8(255, 255, 255, 32)
		var img_x := x_pos - 90
		g.set_scale(0.8, 0.8, img_x, y_pos)
		g.draw_image_cel(portraits, img_x, y_pos, i)
		g.set_scale(1, 1, 0, 0)
		g.colorize_images = false

func key_down(key: int) -> void:
	if App.widget_manager.focus_widget != self:
		return
	if key == WidgetManager.KEYCODE_UP:
		scroll_position += 15
	elif key == WidgetManager.KEYCODE_DOWN:
		scroll_position -= 15
	elif key == WidgetManager.KEYCODE_ESCAPE:
		exit_screen()

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	add_widget(back_button)
	add_widget(rock_button)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	remove_widget(back_button)
	remove_widget(rock_button)

func button_press(_bid: int, _count: int = 1) -> void:
	App.play_sample("SOUND_BUTTONCLICK")

func update() -> void:
	if tween_timer > 0:
		do_button_movement(int(scroll_position), -234 if goes_down else 0)
	max_scroll_position = 19628
	var speed := BASE_SCROLL_SPEED + absf(scroll_amount) * SCROLL_ACCEL
	scroll_position = clampf(scroll_position - scroll_amount * speed, -max_scroll_position, 0)
	scroll_amount *= 1.0 - SCROLL_ACCEL
	back_button.resize(128 + PvZ.BOARD_ADDITIONAL_WIDTH, int(55 + scroll_position - PvZ.BOARD_OFFSET_Y + 30), 130, 80)
	var more := Res.get_image("IMAGE_ACHIEVEMENT_MORE")
	rock_button.resize(710 + PvZ.BOARD_ADDITIONAL_WIDTH + 90, int(470 + scroll_position - PvZ.BOARD_OFFSET_Y), more.width, more.height)

func button_depress(bid: int) -> void:
	if bid == 0:
		exit_screen()
	if bid == 1:
		tween_timer = 110
		goes_down = not goes_down
		if goes_down:
			rock_button.button_image = Res.get_image("IMAGE_ACHIEVEMENT_TOP")
			rock_button.down_image = Res.get_image("IMAGE_ACHIEVEMENT_TOP_HIGHLIGHT")
			rock_button.over_image = Res.get_image("IMAGE_ACHIEVEMENT_TOP_HIGHLIGHT")
		else:
			rock_button.button_image = Res.get_image("IMAGE_ACHIEVEMENT_MORE")
			rock_button.down_image = Res.get_image("IMAGE_ACHIEVEMENT_MORE_HIGHLIGHT")
			rock_button.over_image = Res.get_image("IMAGE_ACHIEVEMENT_MORE_HIGHLIGHT")

func do_button_movement(start: int, final: int) -> void:
	scroll_position = Tod.animate_curve(200, 0, tween_timer, start, final, Tod.CURVE_EASE_IN_OUT)
	tween_timer -= 1

func mouse_wheel(delta: int) -> bool:
	if App.game_selector.movement_timer > 0:
		return true
	scroll_amount -= BASE_SCROLL_SPEED * delta
	scroll_amount -= scroll_amount * SCROLL_ACCEL
	return true

func exit_screen() -> void:
	scroll_position = 0
	var gs := App.game_selector
	gs.movement_timer = 75
	gs.destination_y = 0
	gs.selector_state = GameSelector.SELECTOR_IDLE
	gs.enable_buttons_transition = true
	App.widget_manager.set_focus(gs)
	back_button.set_disabled(true)
	rock_button.set_disabled(true)
