class_name ListWidget
extends Widget
## Port of Sexy::ListWidget. PvZ only uses single-column lists without a scrollbar
## (the user picker), so the parent/child column chaining and ScrollbarWidget hookup are left out.

enum { JUSTIFY_LEFT, JUSTIFY_CENTER, JUSTIFY_RIGHT }
enum { COLOR_BKG, COLOR_OUTLINE, COLOR_TEXT, COLOR_HILITE, COLOR_SELECT, COLOR_SELECT_TEXT }

var id := 0
var font: ImageFont
var justify := JUSTIFY_LEFT
var lines: Array = []
var line_colors: Array = []
var position := 0.0
var page_size := 0.0
var hilite_idx := -1
var select_idx := -1
var list_listener: Object
var draw_outline := true
var item_height := -1
var draw_select_when_hilited := false
var do_finger_when_hilited := true

func _init(the_id: int = 0, the_font: ImageFont = null, the_listener: Object = null) -> void:
	id = the_id
	font = the_font
	list_listener = the_listener
	item_height = the_font.get_height() if the_font != null else -1
	set_colors([[255, 255, 255], [255, 255, 255], [0, 0, 0], [0, 192, 0], [0, 0, 128], [255, 255, 255]])

func _item_height() -> int:
	return item_height if item_height != -1 else font.get_height()

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	if list_listener and list_listener.has_method("list_closed"):
		list_listener.list_closed(id)

func get_string_at(idx: int) -> String:
	return lines[idx]

func resize(nx: int, ny: int, w: int, h: int) -> void:
	super.resize(nx, ny, w, h)
	var ih := _item_height()
	page_size = (height - 8.0) / ih if height > ih + 8 else 1.0

func add_line(line: String, alphabetical: bool) -> int:
	if alphabetical:
		for i in lines.size():
			if line < lines[i]:
				lines.insert(i, line)
				line_colors.insert(i, colors[COLOR_TEXT])
				return i
	lines.append(line)
	line_colors.append(colors[COLOR_TEXT])
	return lines.size() - 1

func set_line(idx: int, s: String) -> void:
	lines[idx] = s

func get_line_count() -> int:
	return lines.size()

func get_line_idx(line: String) -> int:
	return lines.find(line)

func set_line_color(idx: int, c: Color) -> void:
	if idx >= 0 and idx < lines.size():
		line_colors[idx] = c

func remove_line(idx: int) -> void:
	if idx != -1:
		lines.remove_at(idx)
		line_colors.remove_at(idx)

func remove_all() -> void:
	lines.clear()
	line_colors.clear()
	select_idx = -1
	hilite_idx = -1

func get_optimal_width() -> int:
	var w := 0
	for l in lines:
		w = maxi(w, font.string_width(l))
	return w + 16

func get_optimal_height() -> int:
	return _item_height() * lines.size() + 8

func draw(g: Graphics) -> void:
	g.color = colors[COLOR_BKG]
	g.fill_rect(0, 0, width, height)
	var clip_g := g.copy()
	clip_g.clip_rect(4, 4, width - 8, height - 8)
	var select_g := g.copy()
	select_g.clip_rect(0, 4, width, height - 8)
	clip_g.font = font

	var first := int(position)
	var last := mini(lines.size() - 1, int(position) + int(page_size) + 1)
	var ih := _item_height()
	var offset := Tod.idiv(ih - font.get_height(), 2) if item_height != -1 else 0
	for i in range(first, last + 1):
		var dy := 4 + int((i - position) * ih)
		if i == select_idx or (i == hilite_idx and draw_select_when_hilited):
			select_g.color = colors[COLOR_SELECT]
			select_g.fill_rect(0, dy, width, ih)
		if i == hilite_idx:
			clip_g.color = colors[COLOR_HILITE]
		elif i == select_idx and colors.size() > COLOR_SELECT_TEXT:
			clip_g.color = colors[COLOR_SELECT_TEXT]
		else:
			clip_g.color = line_colors[i]
		var s := TodStrings.translate(lines[i])
		var fx: int
		match justify:
			JUSTIFY_LEFT: fx = 4
			JUSTIFY_CENTER: fx = Tod.idiv(width - font.string_width(s), 2)
			_: fx = width - font.string_width(s) - 4
		clip_g.draw_string(s, fx, dy + font.get_ascent() + offset)

	if draw_outline:
		g.color = colors[COLOR_OUTLINE]
		g.draw_rect(0, 0, width - 1, height - 1)

func scroll_position(_sid: int, pos: float) -> void:
	position = pos

func set_hilite(idx: int, notify_listener: bool = false) -> void:
	var old := hilite_idx
	hilite_idx = idx
	if old != hilite_idx and notify_listener and list_listener and list_listener.has_method("list_hilite_changed"):
		list_listener.list_hilite_changed(id, old, hilite_idx)

func mouse_move(_mx: int, my: int) -> void:
	var new_hilite := int((my - 4) / float(_item_height()) + position)
	if new_hilite < 0 or new_hilite >= lines.size():
		new_hilite = -1
	if new_hilite != hilite_idx:
		set_hilite(new_hilite, true)
		if hilite_idx == -1 or not do_finger_when_hilited:
			App.set_cursor(App.CURSOR_POINTER)
		else:
			App.set_cursor(App.CURSOR_HAND)

func mouse_down_btn(_mx: int, _my: int, _btn: int, count: int) -> void:
	if hilite_idx != -1 and list_listener and list_listener.has_method("list_clicked"):
		list_listener.list_clicked(id, hilite_idx, count)

func mouse_leave() -> void:
	set_hilite(-1, true)
	App.set_cursor(App.CURSOR_POINTER)

func set_select(idx: int) -> void:
	select_idx = idx
