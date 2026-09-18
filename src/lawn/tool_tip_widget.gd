class_name ToolTipWidget
extends RefCounted
## Port of ToolTipWidget (seed packet / tool tooltips).

var title := ""
var label := ""
var warning_text := ""
var x := 0
var y := 0
var width := 0
var height := 0
var visible := true
var center := false
var min_left := 0
var max_bottom := PvZ.BOARD_HEIGHT
var gets_lines_width := 0
var warning_flash_counter := 0

static func _font() -> ImageFont: return Res.get_font("FONT_BRIANNETOD12")
static func _title_font() -> ImageFont: return Res.get_font("FONT_BRIANNETOD16")

func get_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	var font := _font()
	var text := TodStrings.translate(label)
	var line_width := 0
	var start := 0
	var i := 0
	var n := text.length()
	while i != n:
		while i < n and text[i] != " " and text[i] != "\n":
			line_width += font.char_width(text.unicode_at(i))
			i += 1
		if i != n and line_width < gets_lines_width and text[i] != "\n":
			line_width += font.char_width(text.unicode_at(i))
			i += 1
		else:
			lines.append(text.substr(start, i - start))
			line_width = 0
			if i < n and text[i] == "\n":
				i += 1
			while i < n and text[i] == " ":
				i += 1
			start = i
	return lines

func calculate_size() -> void:
	var t := TodStrings.translate(title)
	var w := TodStrings.translate(warning_text)
	var tf := _title_font()
	var font := _font()
	var max_w := maxi(tf.string_width(t), font.string_width(w))
	gets_lines_width = maxi(max_w - 30, 100)
	var lines := get_lines()
	for l in lines:
		max_w = maxi(max_w, font.string_width(l))
	var h := 6
	if not t.is_empty():
		h = tf.get_ascent() + 8
	if not w.is_empty():
		h += font.get_ascent() + 2
	h += lines.size() * font.get_ascent()
	width = max_w + 10
	height = h + lines.size() * 2 - 2

func set_label(s: String) -> void:
	label = s
	calculate_size()

func set_title(s: String) -> void:
	title = s
	calculate_size()

func set_warning_text(s: String) -> void:
	warning_text = s
	calculate_size()

func flash_warning() -> void:
	warning_flash_counter = 70

func update() -> void:
	if warning_flash_counter > 0:
		warning_flash_counter -= 1

func set_position(px: int, py: int) -> void:
	x = px
	y = py

func draw(g: Graphics) -> void:
	if not visible:
		return
	var px := x
	if center:
		px -= Tod.idiv(width, 2)
	if min_left - g.trans_x > px:
		px = min_left - int(g.trans_x)
	elif px + width + g.trans_x > PvZ.BOARD_WIDTH:
		px = int(PvZ.BOARD_WIDTH - g.trans_x - width)
	var py := y
	if -g.trans_y > py:
		py = int(-g.trans_y)
	elif max_bottom < y + height + g.trans_y:
		py = max_bottom - int(g.trans_y) - height
	g.color = Color8(255, 255, 200, 255)
	g.fill_rect(px, py, width, height)
	g.color = Color.BLACK
	g.draw_rect(px, py, width - 1, height - 1)
	py += 1
	var tf := _title_font()
	var t := TodStrings.translate(title)
	if not t.is_empty():
		g.font = tf
		g.draw_string(t, px + Tod.idiv(width - tf.string_width(t), 2), py + tf.get_ascent())
		py += tf.get_ascent() + 2
	var font := _font()
	var w := TodStrings.translate(warning_text)
	if not w.is_empty():
		g.font = font
		var wc := Color8(255, 0, 0)
		if warning_flash_counter > 0 and warning_flash_counter % 20 < 10:
			wc = Color.BLACK
		g.color = wc
		g.draw_string(w, px + Tod.idiv(width - font.string_width(w), 2), py + font.get_ascent())
		g.color = Color.BLACK
		py += font.get_ascent() + 2
	g.font = font
	for l in get_lines():
		g.draw_string(l, px + Tod.idiv(width - font.string_width(l), 2), py + font.get_ascent())
		py += font.get_ascent() + 2
