class_name MessageWidget
extends RefCounted
## Port of MessageWidget (advice bar, "A huge wave of zombies is approaching!" reanimated text...).

const MAX_MESSAGE_LENGTH := 128

var label := ""
var display_time := 0
var duration := 0
var message_style := PvZ.MESSAGE_STYLE_OFF
var text_reanims: Array = []
var reanim_type := PvZ.REANIM_NONE
var slide_off_time := 100
var label_next := ""
var message_style_next := PvZ.MESSAGE_STYLE_OFF

func clear_reanim() -> void:
	for r in text_reanims:
		if r != null and not r.freed:
			r.die()
	text_reanims.clear()

func clear_label() -> void:
	if reanim_type != PvZ.REANIM_NONE:
		duration = mini(duration, 100 + slide_off_time + 1)
	else:
		duration = 0

func is_being_displayed() -> bool:
	return duration != 0

func set_label(new_label: String, style: int) -> void:
	var text := TodStrings.translate(new_label)
	if reanim_type != PvZ.REANIM_NONE and duration > 0:
		message_style_next = style
		label_next = text
		clear_label()
		return
	clear_reanim()
	label = text
	message_style = style
	reanim_type = PvZ.REANIM_NONE
	match style:
		PvZ.MESSAGE_STYLE_HINT_LONG, PvZ.MESSAGE_STYLE_BIG_MIDDLE, PvZ.MESSAGE_STYLE_ZEN_GARDEN_LONG, PvZ.MESSAGE_STYLE_HINT_TALL_LONG:
			duration = 1500
		PvZ.MESSAGE_STYLE_HINT_TALL_UNLOCKMESSAGE:
			duration = 500
		PvZ.MESSAGE_STYLE_HINT_FAST, PvZ.MESSAGE_STYLE_HINT_TALL_FAST, PvZ.MESSAGE_STYLE_BIG_MIDDLE_FAST, \
		PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL1, PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL2, PvZ.MESSAGE_STYLE_TUTORIAL_LATER:
			duration = 500
		PvZ.MESSAGE_STYLE_HINT_STAY, PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL1_STAY, PvZ.MESSAGE_STYLE_TUTORIAL_LATER_STAY:
			duration = 10000
		PvZ.MESSAGE_STYLE_HOUSE_NAME:
			duration = 250
		PvZ.MESSAGE_STYLE_HUGE_WAVE:
			duration = 750
			reanim_type = PvZ.REANIM_TEXT_FADE_ON
		PvZ.MESSAGE_STYLE_SLOT_MACHINE:
			duration = 750
	if reanim_type != PvZ.REANIM_NONE:
		layout_reanim_text()
	display_time = duration

func layout_reanim_text() -> void:
	var font := get_font()
	var n := label.length()
	slide_off_time = n + 100
	var line_widths: Array = []
	var cur_pos := 0
	for pos in n + 1:
		if pos == n or label[pos] == "\n":
			line_widths.append(float(font.string_width(label.substr(cur_pos, pos - cur_pos))))
			cur_pos = pos + 1
	var cur_line := 0
	var py := 0.0
	var px: float = -line_widths[0] * 0.5
	text_reanims.clear()
	for pos in n:
		var r := App.add_reanimation(px, py, 0, reanim_type)
		r.is_attachment = true
		r.play_reanim("anim_enter", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 0.0)
		text_reanims.append(r)
		px += font.char_width(label.unicode_at(pos))
		if label[pos] == "\n":
			cur_line += 1
			px = -line_widths[cur_line] * 0.5
			py += font.get_line_spacing()

func update() -> void:
	if App.board == null or App.board.paused:
		return
	if duration < 10000 and duration > 0:
		duration -= 1
		if duration == 0:
			message_style = PvZ.MESSAGE_STYLE_OFF
			if message_style_next != PvZ.MESSAGE_STYLE_OFF:
				set_label(label_next, message_style_next)
				message_style_next = PvZ.MESSAGE_STYLE_OFF
	for pos in text_reanims.size():
		var r: Reanimation = text_reanims[pos]
		if r == null or r.freed:
			break
		var speed := 100 if reanim_type == PvZ.REANIM_TEXT_FADE_ON else 1
		if duration > slide_off_time:
			if reanim_type == PvZ.REANIM_TEXT_FADE_ON:
				r.anim_rate = 60.0
			else:
				r.anim_rate = Tod.animate_curve_float(0, 50, (display_time - duration) * speed - pos, 0.0, 40.0, Tod.CURVE_LINEAR)
		else:
			if duration == slide_off_time:
				r.play_reanim("anim_leave", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 0.0)
			r.anim_rate = Tod.animate_curve_float(0, 50, (slide_off_time - duration) * speed - pos, 0.0, 40.0, Tod.CURVE_LINEAR)
		r.update()

func draw_reanimated_text(g: Graphics, font: ImageFont, color: Color, pos_y: float) -> void:
	var t := Reanimation.Transform.new()
	for pos in text_reanims.size():
		var r: Reanimation = text_reanims[pos]
		if r == null or r.freed:
			break
		r.get_current_transform(2, t)
		var alpha := clampi(Tod.round_to_int(color.a8 * t.alpha), 0, 255)
		if alpha <= 0:
			break
		var fc := color
		fc.a8 = alpha
		t.tx += r.overlay_matrix.origin.x + PvZ.BOARD_ADDITIONAL_WIDTH
		t.ty = pos_y
		if reanim_type == PvZ.REANIM_TEXT_FADE_ON and display_time - duration < slide_off_time:
			var stretch := 1.0 - r.anim_time
			t.tx += stretch * r.overlay_matrix.origin.x
		var m := Reanimation.matrix_from_transform(t)
		font.draw_string_matrix(g, m, label[pos], fc)

func get_font() -> ImageFont:
	if message_style == PvZ.MESSAGE_STYLE_SLOT_MACHINE:
		return Res.get_font("FONT_HOUSEOFTERROR16")
	return Res.get_font("FONT_HOUSEOFTERROR28")

func draw(g: Graphics) -> void:
	if duration <= 0:
		return
	var font := get_font()
	var px := Tod.idiv(PvZ.BOARD_WIDTH, 2)
	var py := PvZ.BOARD_HEIGHT - 4
	var text_offset_y := 0
	var rect_height := 0
	var min_alpha := 255
	var color := Color8(250, 250, 0, 255)
	var outline_color := Color8(0, 0, 0, 255)
	var fade_out := false
	match message_style:
		PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL1, PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL1_STAY:
			py = PvZ.BOARD_HEIGHT - 200; rect_height = 110; text_offset_y = -4
			color = Color8(253, 245, 173); min_alpha = 192
		PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL2, PvZ.MESSAGE_STYLE_TUTORIAL_LATER, PvZ.MESSAGE_STYLE_TUTORIAL_LATER_STAY, \
		PvZ.MESSAGE_STYLE_HINT_TALL_FAST, PvZ.MESSAGE_STYLE_HINT_TALL_UNLOCKMESSAGE, PvZ.MESSAGE_STYLE_HINT_TALL_LONG:
			py = PvZ.BOARD_HEIGHT - 124; rect_height = 100; text_offset_y = -4
			color = Color8(253, 245, 173); min_alpha = 192
		PvZ.MESSAGE_STYLE_HINT_LONG, PvZ.MESSAGE_STYLE_HINT_FAST, PvZ.MESSAGE_STYLE_HINT_STAY:
			py = PvZ.BOARD_HEIGHT - 73; rect_height = 55; text_offset_y = -4
			color = Color8(253, 245, 173); min_alpha = 192
		PvZ.MESSAGE_STYLE_BIG_MIDDLE, PvZ.MESSAGE_STYLE_BIG_MIDDLE_FAST:
			py = Tod.idiv(PvZ.BOARD_HEIGHT, 2); rect_height = 110
			color = Color8(253, 245, 173); min_alpha = 192
		PvZ.MESSAGE_STYLE_HOUSE_NAME:
			py = PvZ.BOARD_HEIGHT - 50
			color = Color8(255, 255, 255, 255)
			fade_out = true
		PvZ.MESSAGE_STYLE_HUGE_WAVE:
			py = Tod.idiv(PvZ.BOARD_HEIGHT, 2) + 15
			color = Color8(255, 0, 0)
		PvZ.MESSAGE_STYLE_SLOT_MACHINE:
			py = 93; px = 340; min_alpha = 64
		PvZ.MESSAGE_STYLE_ZEN_GARDEN_LONG:
			py = PvZ.BOARD_HEIGHT - 86; rect_height = 55; text_offset_y = -4
			color = Color8(253, 245, 173); min_alpha = 192
	if reanim_type != PvZ.REANIM_NONE:
		draw_reanimated_text(g, font, color, py)
		return
	if min_alpha != 255:
		color.a8 = Tod.animate_curve(75, 0, App.board.main_counter % 75, min_alpha, 255, Tod.CURVE_BOUNCE_SLOW_MIDDLE)
		outline_color.a8 = color.a8
	if fade_out:
		color.a8 = clampi(duration * 15, 0, 255)
		outline_color.a8 = color.a8
	if rect_height > 0:
		outline_color = Color8(0, 0, 0, 128)
		var r := Rect2i(0, py, PvZ.BOARD_WIDTH, rect_height)
		g.color = outline_color
		g.fill_rect(r.position.x, r.position.y, r.size.x, r.size.y)
		r.position.y += text_offset_y
		TodStrings.draw_string_wrapped(g, label, r, font, color, TodStrings.DS_ALIGN_CENTER_VERTICAL_MIDDLE)
	else:
		var r := Rect2i(px - App.board.x - Tod.idiv(PvZ.BOARD_WIDTH, 2), py - font.get_ascent(), PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
		TodStrings.draw_string_wrapped(g, label, r, font, color, TodStrings.DS_ALIGN_CENTER)
