class_name EditWidget
extends Widget
## Port of Sexy::EditWidget + LawnEditWidget behaviour (auto capitalised first letter, escape forwarding).

enum { COLOR_BKG, COLOR_OUTLINE, COLOR_TEXT, COLOR_HILITE, COLOR_HILITE_TEXT }

var id := 0
var listener: Object
var dialog: Widget
var text := ""
var font: ImageFont
var cursor_pos := 0
var hilite_pos := -1
var left_pos := 0
var blink_acc := 0
var blink_delay := 40
var showing_cursor := false
var max_chars := -1
var max_pixels := -1
var auto_cap_first_letter := true
var width_check_font: ImageFont
var width_check_width := 0

func _init(the_id: int = 0, the_listener: Object = null, the_dialog: Widget = null) -> void:
	id = the_id
	listener = the_listener
	dialog = the_dialog
	wants_focus = true
	do_finger = false

## CreateEditWidget from LawnCommon
static func create_lawn(the_id: int, the_listener: Object, the_dialog: Widget) -> EditWidget:
	var e := EditWidget.new(the_id, the_listener, the_dialog)
	e.font = Res.get_font("FONT_BRIANNETOD16")
	e.set_colors([[0, 0, 0, 0], [0, 0, 0, 0], [240, 240, 255, 255], [255, 255, 255, 255], [0, 0, 0, 255]])
	e.blink_delay = 14
	return e

func set_text(s: String, leave_cursor: bool = false) -> void:
	text = s
	if not leave_cursor:
		cursor_pos = text.length()
		hilite_pos = -1

func add_width_check_font(f: ImageFont, w: int) -> void:
	width_check_font = f
	width_check_width = w

func got_focus() -> void:
	super.got_focus()
	showing_cursor = true
	blink_acc = 0

func lost_focus() -> void:
	super.lost_focus()
	showing_cursor = false

func update() -> void:
	super.update()
	if has_focus:
		blink_acc += 1
		if blink_acc > blink_delay:
			blink_acc = 0
			showing_cursor = not showing_cursor

func draw(g: Graphics) -> void:
	if font == null:
		return
	g.color = colors[COLOR_BKG]
	g.fill_rect(0, 0, width, height)
	for i in 2:
		var cg := g.copy()
		cg.font = font
		if i == 1:
			var cursor_x := font.string_width(text.substr(0, cursor_pos)) - font.string_width(text.substr(0, left_pos))
			var hilite_x := cursor_x + 2
			if hilite_pos != -1 and cursor_pos != hilite_pos:
				hilite_x = font.string_width(text.substr(0, hilite_pos)) - font.string_width(text.substr(0, left_pos))
			if not showing_cursor:
				cursor_x += 2
			cursor_x = mini(maxi(0, cursor_x), width - 8)
			hilite_x = mini(maxi(0, hilite_x), width - 8)
			cg.clip_rect(4 + mini(cursor_x, hilite_x), Tod.idiv(height - font.get_height(), 2), absi(hilite_x - cursor_x), font.get_height())
		else:
			cg.clip_rect(4, 0, width - 8, height)
		if i == 1 and has_focus:
			cg.color = colors[COLOR_HILITE]
			cg.fill_rect(0, 0, width, height)
		cg.color = colors[COLOR_TEXT] if (i == 0 or not has_focus) else colors[COLOR_HILITE_TEXT]
		cg.draw_string(text.substr(left_pos), 4, Tod.idiv(height - font.get_height(), 2) + font.get_ascent())
	g.color = colors[COLOR_OUTLINE]
	g.draw_rect(0, 0, width - 1, height - 1)

func _delete_selection() -> bool:
	if hilite_pos != -1 and hilite_pos != cursor_pos:
		var a := mini(cursor_pos, hilite_pos)
		var b := maxi(cursor_pos, hilite_pos)
		text = text.substr(0, a) + text.substr(b)
		cursor_pos = a
		hilite_pos = -1
		return true
	return false

func key_down(key: int) -> void:
	var shift := widget_manager != null and widget_manager.is_key_down(WidgetManager.KEYCODE_SHIFT)
	match key:
		WidgetManager.KEYCODE_LEFT:
			if shift and hilite_pos == -1:
				hilite_pos = cursor_pos
			elif not shift:
				hilite_pos = -1
			cursor_pos = maxi(cursor_pos - 1, 0)
		WidgetManager.KEYCODE_RIGHT:
			if shift and hilite_pos == -1:
				hilite_pos = cursor_pos
			elif not shift:
				hilite_pos = -1
			cursor_pos = mini(cursor_pos + 1, text.length())
		WidgetManager.KEYCODE_HOME:
			hilite_pos = -1
			cursor_pos = 0
		WidgetManager.KEYCODE_END:
			hilite_pos = -1
			cursor_pos = text.length()
		WidgetManager.KEYCODE_BACK:
			if not _delete_selection() and cursor_pos > 0:
				text = text.substr(0, cursor_pos - 1) + text.substr(cursor_pos)
				cursor_pos -= 1
		WidgetManager.KEYCODE_DELETE:
			if not _delete_selection() and cursor_pos < text.length():
				text = text.substr(0, cursor_pos) + text.substr(cursor_pos + 1)
		WidgetManager.KEYCODE_RETURN:
			if listener and listener.has_method("edit_widget_text"):
				listener.edit_widget_text(id, text)
		WidgetManager.KEYCODE_ESCAPE:
			if dialog != null:
				dialog.key_down(WidgetManager.KEYCODE_ESCAPE)
	showing_cursor = true
	blink_acc = 0
	_fix_left_pos()

func key_char(ch: String) -> void:
	if ch.is_empty():
		return
	var code := ch.unicode_at(0)
	if code < 32 or code == 127:
		return
	if listener and listener.has_method("allow_char") and not listener.allow_char(id, ch):
		return
	if auto_cap_first_letter and ch.to_upper() != ch.to_lower():
		ch = ch.to_upper()
		auto_cap_first_letter = false
	_delete_selection()
	var candidate := text.substr(0, cursor_pos) + ch + text.substr(cursor_pos)
	if max_chars >= 0 and candidate.length() > max_chars:
		return
	if width_check_font != null and width_check_font.string_width(candidate) > width_check_width:
		return
	text = candidate
	cursor_pos += 1
	showing_cursor = true
	blink_acc = 0
	_fix_left_pos()

func _fix_left_pos() -> void:
	if font == null:
		return
	if cursor_pos < left_pos:
		left_pos = cursor_pos
	while left_pos < cursor_pos and font.string_width(text.substr(left_pos, cursor_pos - left_pos)) > width - 8:
		left_pos += 1

func mouse_down_btn(mx: int, _my: int, _btn: int, _count: int) -> void:
	hilite_pos = -1
	cursor_pos = text.length()
	if font != null:
		for i in range(left_pos, text.length() + 1):
			if 4 + font.string_width(text.substr(left_pos, i - left_pos)) >= mx:
				cursor_pos = i
				break
	showing_cursor = true
