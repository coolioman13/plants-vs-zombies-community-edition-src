class_name ChallengePagesDialog
extends LawnDialog
## Port of ChallengePagesDialog (QE page picker opened from the challenge screen).

const BASE_SCROLL_SPEED := 1.5
const SCROLL_ACCEL := 0.1

var slider: SexySlider
var page_buttons: Array = []
var page_button_rects: Array = []
var scroll_position := 0.0
var scroll_amount := 0.0
var max_scroll_position := 0.0
var clip_rect := Rect2i()

func _init() -> void:
	super._init(PvZ.DIALOG_CHALLENGE_PAGES, true, "[PAGE_SELECTION_HEADER]", "", "[CLOSE_PAGE_SELECTION]", BUTTONS_FOOTER)
	calc_size(150, 350)
	clip_rect = Rect2i(45, 120, width - 100, height - 230)

	slider = SexySlider.new(Res.get_image("IMAGE_CHALLENGE_SLIDERSLOT"), Res.get_image("IMAGE_OPTIONS_SLIDERKNOB2"), -1, self)
	slider.set_value(maxf(0.0, minf(max_scroll_position, scroll_position)))
	slider.horizontal = false
	slider.resize(width - 70, clip_rect.position.y, 20, clip_rect.size.y)
	slider.thumb_offset_x = -1
	slider.no_draw = true

	for page in PvZ.MAX_CHALLENGE_PAGES:
		var b := LawnButtons.make_button(page, self, ChallengeScreen.get_page_title(page))
		b.btn_no_draw = true
		page_buttons.append(b)
		page_button_rects.append(Rect2i())

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	add_widget(slider)
	for b in page_buttons:
		add_widget(b)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	remove_widget(slider)
	for b in page_buttons:
		remove_widget(b)

func draw(g: Graphics) -> void:
	super.draw(g)
	g.set_clip_rect_r(Rect2(clip_rect))
	var cs := App.challenge_screen
	var total_hidden := 0
	var max_scroll := 0
	for page in PvZ.MAX_CHALLENGE_PAGES:
		var selected := page == cs.page_index
		var b: LawnStoneButton = page_buttons[page]
		b.disabled = selected
		b.mouse_visible = clip_rect.has_point(Vector2i(widget_manager.last_mouse_x - x, widget_manager.last_mouse_y - y))
		b.visible = cs.is_page_unlocked(page)
		var h := 46
		var gap := 3
		var r := Rect2i(clip_rect.position.x, int(clip_rect.position.y + (page - total_hidden) * (h + gap) - scroll_position),
			clip_rect.size.x - (slider.width if slider.visible else 0), h)
		page_button_rects[page] = r
		b.resize(r.position.x, r.position.y, r.size.x, r.size.y)
		if b.visible:
			LawnButtons.draw_stone_button(g, r.position.x, r.position.y, r.size.x, r.size.y,
				(b.is_down and b.is_over and not b.disabled) != b.inverted, b.is_over, TodStrings.translate(b.label), 175 if selected else 255)
			max_scroll += h + gap
		else:
			total_hidden += 1
	max_scroll_position = maxi(0, max_scroll - clip_rect.size.y)
	g.clear_clip_rect()
	slider.slider_draw(g)

func update() -> void:
	# The original skips LawnDialog::Update here, so the footer button has no delay.
	scroll_position = clampf(scroll_position + scroll_amount * (BASE_SCROLL_SPEED + absf(scroll_amount) * SCROLL_ACCEL), 0, max_scroll_position)
	scroll_amount *= 1.0 - SCROLL_ACCEL
	slider.set_value(maxf(0.0, minf(max_scroll_position, scroll_position)) / max_scroll_position if max_scroll_position != 0 else 0.0)
	slider.visible = max_scroll_position != 0

func button_depress(bid: int) -> void:
	if bid == ID_YES:
		App.kill_dialog(PvZ.DIALOG_CHALLENGE_PAGES)
		App.play_sample("SOUND_BUTTONCLICK")
	else:
		var cs := App.challenge_screen
		cs.page_index = bid
		cs.slider.set_value(0)
		cs.scroll_position = 0
		cs.update_buttons()
		for b in page_buttons:
			b.is_over = false
		App.set_cursor(App.CURSOR_POINTER)

func slider_val(sid: int, v: float) -> void:
	if sid == -1:
		scroll_position = v * max_scroll_position

func mouse_wheel(delta: int) -> bool:
	scroll_amount -= BASE_SCROLL_SPEED * delta
	scroll_amount -= scroll_amount * SCROLL_ACCEL
	return true

func key_down(key: int) -> void:
	if key == WidgetManager.KEYCODE_ESCAPE:
		App.kill_dialog(PvZ.DIALOG_CHALLENGE_PAGES)
		App.play_sample("SOUND_BUTTONCLICK")
