class_name LawnDialog
extends Dialog
## Port of LawnDialog (stone-framed dialogs) + ReanimationWidget.

const DIALOG_HEADER_OFFSET := 45

class ReanimationWidget:
	extends Widget
	var reanim: Reanimation
	var pos_x := 0.0
	var pos_y := 0.0
	var lawn_dialog: LawnDialog

	func _init() -> void:
		mouse_visible = false
		clip = false

	func add_reanimation(px: float, py: float, type: int) -> void:
		pos_x = px
		pos_y = py
		reanim = EffectSystem.alloc_reanimation(px, py, 0, type)
		reanim.loop_type = Reanimation.REANIM_LOOP
		reanim.is_attachment = true
		if reanim.track_exists("anim_idle"):
			reanim.set_frames_for_layer("anim_idle")
		resize(int(px), int(py), 10, 10)

	func dispose() -> void:
		if reanim != null:
			reanim.die()
			reanim = null

	func draw(g: Graphics) -> void:
		if reanim != null:
			reanim.draw(g)

	func update() -> void:
		super.update()
		if reanim != null:
			reanim.update()

var button_delay := -1
var reanimation := ReanimationWidget.new()
var draw_standard_back := true
var tall_bottom := false
var vertical_center_text := true
var lawn_yes_button: DialogButton
var lawn_no_button: DialogButton

func _init(the_id: int = 0, modal: bool = true, header: String = "", lines: String = "", footer: String = "", mode: int = BUTTONS_NONE) -> void:
	super._init(the_id, modal, header, lines, "", BUTTONS_NONE)
	reanimation.lawn_dialog = self
	set_color(0, Color8(0xE0, 0xBB, 0x62))
	set_color(1, Color8(0xE0, 0xBB, 0x62))
	header_font = Res.get_font("FONT_DWARVENTODCRAFT24")
	lines_font = Res.get_font("FONT_DWARVENTODCRAFT15")
	content_insets = [36, 35, 46, 36]
	match mode:
		BUTTONS_YES_NO:
			lawn_yes_button = LawnButtons.make_button(1000, self, "[DIALOG_BUTTON_YES]")
			lawn_no_button = LawnButtons.make_button(1001, self, "[DIALOG_BUTTON_NO]")
		BUTTONS_OK_CANCEL:
			lawn_yes_button = LawnButtons.make_button(1000, self, "[DIALOG_BUTTON_OK]")
			lawn_no_button = LawnButtons.make_button(1001, self, "[DIALOG_BUTTON_CANCEL]")
		BUTTONS_FOOTER:
			lawn_yes_button = LawnButtons.make_button(1000, self, footer)
	App.set_cursor(App.CURSOR_POINTER)
	calc_size(0, 0)

func calc_size(extra_x: int, extra_y: int) -> void:
	var header := TodStrings.translate(dialog_header)
	var lines := TodStrings.translate(dialog_lines)
	var w: int = background_insets[0] + background_insets[2] + content_insets[0] + content_insets[2] + extra_x
	if header.length() > 0:
		w += header_font.string_width(header)
	var top_mid := Res.get_image("IMAGE_DIALOG_TOPMIDDLE").width
	var img_w := Res.get_image("IMAGE_DIALOG_TOPLEFT").width + Res.get_image("IMAGE_DIALOG_TOPRIGHT").width + top_mid
	if w <= img_w:
		w = img_w
	elif top_mid > 0:
		var extra := (w - img_w) % top_mid
		if extra:
			w += top_mid - extra
	var h: int = background_insets[1] + background_insets[3] + content_insets[1] + content_insets[3] + extra_y + DIALOG_HEADER_OFFSET
	if header.length() > 0:
		h += -header_font.get_ascent_padding() + header_font.get_height() + space_after_header
	if lines.length() > 0:
		w += top_mid
		var basic_w: int = w - background_insets[0] - background_insets[2] - content_insets[0] - content_insets[2] - 4
		h += TextWriter.get_word_wrapped_height(lines_font, basic_w, lines, lines_font.get_line_spacing() + line_spacing_offset) + 30
	h += button_height
	var bottom_h := Res.get_image("IMAGE_DIALOG_BIGBOTTOMLEFT" if tall_bottom else "IMAGE_DIALOG_BOTTOMLEFT").height
	var img_h := Res.get_image("IMAGE_DIALOG_TOPLEFT").height + bottom_h + DIALOG_HEADER_OFFSET
	if h < img_h:
		h = img_h
	else:
		var ch := Res.get_image("IMAGE_DIALOG_CENTERLEFT").height
		var extra_h := (h - img_h) % ch
		if extra_h:
			h += ch - extra_h
	resize(x, y, w, h)

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	add_widget(reanimation)
	if lawn_yes_button:
		add_widget(lawn_yes_button)
	if lawn_no_button:
		add_widget(lawn_no_button)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	if lawn_yes_button:
		remove_widget(lawn_yes_button)
	if lawn_no_button:
		remove_widget(lawn_no_button)
	remove_widget(reanimation)
	reanimation.dispose()

func set_button_delay(delay: int) -> void:
	button_delay = delay
	if lawn_yes_button:
		lawn_yes_button.disabled = true
	if lawn_no_button:
		lawn_no_button.disabled = true

func update() -> void:
	super.update()
	if button_delay == update_cnt:
		if lawn_yes_button:
			lawn_yes_button.disabled = false
		if lawn_no_button:
			lawn_no_button.disabled = false

func button_press(_bid: int, _count: int = 1) -> void:
	App.play_sample("SOUND_GRAVEBUTTON")

func button_depress(bid: int) -> void:
	if update_cnt > button_delay:
		super.button_depress(bid)

func checkbox_checked(_cid: int, _checked: bool) -> void:
	App.play_sample("SOUND_BUTTONCLICK")

func key_down(key: int) -> void:
	if id == PvZ.DIALOG_PAUSED and App.board:
		App.board.do_typing_check(key)
	if id != PvZ.DIALOG_ALMANAC:
		if key == WidgetManager.KEYCODE_SPACE or key == WidgetManager.KEYCODE_RETURN or key == 0x59:
			super.button_depress(ID_YES)
		elif (key == WidgetManager.KEYCODE_ESCAPE or key == 0x4E) and lawn_no_button:
			super.button_depress(ID_NO)

func resize(nx: int, ny: int, w: int, h: int) -> void:
	super.resize(nx, ny, w, h)
	var bl := Res.get_image("IMAGE_BUTTON_LEFT")
	var br := Res.get_image("IMAGE_BUTTON_RIGHT")
	var bm := Res.get_image("IMAGE_BUTTON_MIDDLE")
	var area_x: int = content_insets[0] + background_insets[0] - 5
	var area_y: int = height - content_insets[3] - background_insets[3] - bl.height + 2
	var area_w: int = width - content_insets[2] - background_insets[2] - background_insets[0] - content_insets[0] + 8
	var min_w := bl.width + br.width
	var mid_w := bm.width
	var extra := Tod.idiv(area_w - 10, 2) - mid_w - min_w + 1
	if extra <= 0:
		extra = 0
	elif mid_w > 0:
		var e2 := extra % mid_w
		if e2:
			extra += mid_w - e2
	var bw := min_w + extra
	if tall_bottom:
		area_y += 5
	if lawn_yes_button and lawn_no_button:
		lawn_yes_button.resize(area_x, area_y, bw, bl.height)
		lawn_no_button.resize(area_w - bw + area_x, area_y, bw, bl.height)
	elif lawn_yes_button:
		extra = area_w - mid_w - min_w + 1
		if extra <= 0:
			extra = 0
		elif mid_w > 0:
			var e3 := extra % mid_w
			if e3:
				extra += mid_w - e3
		var bw2 := min_w + extra
		lawn_yes_button.resize(area_x + Tod.idiv(area_w - bw2, 2), area_y, bw2, bl.height)
	if reanimation.reanim:
		reanimation.resize(int(reanimation.pos_x), int(reanimation.pos_y) + DIALOG_HEADER_OFFSET, reanimation.width, reanimation.height)

func draw(g: Graphics) -> void:
	if not draw_standard_back:
		return
	var bl := Res.get_image("IMAGE_DIALOG_BIGBOTTOMLEFT" if tall_bottom else "IMAGE_DIALOG_BOTTOMLEFT")
	var bm := Res.get_image("IMAGE_DIALOG_BIGBOTTOMMIDDLE" if tall_bottom else "IMAGE_DIALOG_BOTTOMMIDDLE")
	var br := Res.get_image("IMAGE_DIALOG_BIGBOTTOMRIGHT" if tall_bottom else "IMAGE_DIALOG_BOTTOMRIGHT")
	var tl := Res.get_image("IMAGE_DIALOG_TOPLEFT")
	var tm := Res.get_image("IMAGE_DIALOG_TOPMIDDLE")
	var tr := Res.get_image("IMAGE_DIALOG_TOPRIGHT")
	var cl := Res.get_image("IMAGE_DIALOG_CENTERLEFT")
	var cm := Res.get_image("IMAGE_DIALOG_CENTERMIDDLE")
	var cr := Res.get_image("IMAGE_DIALOG_CENTERRIGHT")
	var repeat_x := Tod.idiv(width - tr.width - tl.width, tm.width)
	var repeat_y := Tod.idiv(height - tl.height - bl.height - DIALOG_HEADER_OFFSET, cl.height)
	var px := 0
	var py := DIALOG_HEADER_OFFSET
	g.draw_image(tl, px, py)
	px += tl.width
	for i in repeat_x:
		g.draw_image(tm, px, py)
		px += tm.width
	g.draw_image(tr, px, py)
	py += tr.height
	for yy in repeat_y:
		px = 0
		g.draw_image(cl, px, py)
		px += cl.width
		for xx in repeat_x:
			g.draw_image(cm, px, py)
			px += cm.width
		g.draw_image(cr, px, py)
		py += cl.height
	px = 0
	g.draw_image(bl, px, py)
	px += bl.width
	for i in repeat_x:
		g.draw_image(bm, px, py)
		px += bm.width
	g.draw_image(br, px, py)
	var hdr := Res.get_image("IMAGE_DIALOG_HEADER")
	g.draw_image(hdr, Tod.idiv(width - hdr.width, 2) - 5, 0)
	var header := TodStrings.translate(dialog_header)
	var lines := TodStrings.translate(dialog_lines)
	var font_y: int = content_insets[1] + background_insets[1] + DIALOG_HEADER_OFFSET
	if header.length() > 0:
		var off_y := font_y - header_font.get_ascent_padding() + header_font.get_ascent()
		g.font = header_font
		g.color = colors[COLOR_HEADER]
		write_centered_line(g, off_y, header)
		font_y = off_y - header_font.get_ascent() + header_font.get_height() + space_after_header
	g.font = lines_font
	g.color = colors[COLOR_LINES]
	var area_w: int = width - content_insets[0] - content_insets[2] - background_insets[0] - background_insets[2] - 4
	var rect := Rect2i(background_insets[0] + content_insets[0] + 2, font_y, area_w, 0)
	if vertical_center_text:
		var lh := get_word_wrapped_height(g, area_w, lines, lines_font.get_line_spacing() + line_spacing_offset)
		var area_h: int = height - content_insets[3] - background_insets[3] - button_height - font_y - 55
		if tall_bottom:
			area_h -= 36
		rect.position.y += Tod.idiv(area_h - lh, 2)
	write_word_wrapped(g, rect, lines, lines_font.get_line_spacing() + line_spacing_offset, text_align)
