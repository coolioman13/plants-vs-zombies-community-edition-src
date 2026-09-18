class_name TodStrings
## Port of TodStringFile: string table loading, [KEY] translation and formatted word-wrapped text.

enum { DS_ALIGN_LEFT, DS_ALIGN_RIGHT, DS_ALIGN_CENTER, DS_ALIGN_LEFT_VERTICAL_MIDDLE, DS_ALIGN_RIGHT_VERTICAL_MIDDLE, DS_ALIGN_CENTER_VERTICAL_MIDDLE }
const TOD_FORMAT_IGNORE_NEWLINES := 0
const TOD_FORMAT_HIDE_UNTIL_MAGNETSHROOM := 1

static var strings: Dictionary = {}

## name, color (alpha 0 = keep), line spacing offset, flags
static var formats := [
	["NORMAL", Color8(40, 50, 90, 255), 0, 0],
	["FLAVOR", Color8(143, 67, 27, 255), 0, 1],
	["KEYWORD", Color8(143, 67, 27, 255), 0, 0],
	["NOCTURNAL", Color8(136, 50, 170, 255), 0, 0],
	["AQUATIC", Color8(11, 161, 219, 255), 0, 0],
	["STAT", Color8(204, 36, 29, 255), 0, 0],
	["METAL", Color8(204, 36, 29, 255), 0, 2],
	["KEYMETAL", Color8(143, 67, 27, 255), 0, 2],
	["SHORTLINE", Color8(0, 0, 0, 0), -9, 0],
	["EXTRASHORTLINE", Color8(0, 0, 0, 0), -14, 0],
	["CREDITS1", Color8(0, 0, 0, 0), 3, 0],
	["CREDITS2", Color8(0, 0, 0, 0), 2, 0],
]

static func load_dir(dir_path: String) -> void:
	var d := DirAccess.open(dir_path)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".lang"):
			load_file(dir_path + "/" + f)

static func load_file(path: String) -> bool:
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		push_error("Failed to load string list file " + path)
		return false
	var text := bytes.get_string_from_utf8()
	if text.is_empty():
		text = Res.latin1_to_string(bytes)
	var pos := 0
	while true:
		var ns := text.find("[", pos)
		if ns == -1:
			return true
		var ne := text.find("]", ns + 1)
		if ne == -1:
			return false
		var name := text.substr(ns + 1, ne - ns - 1).strip_edges()
		pos = ne + 1
		var ve := text.find("[", pos)
		var value := text.substr(pos, (ve - pos) if ve != -1 else -1)
		value = value.strip_edges().replace("\r", "")
		strings[name.to_upper()] = value
		if ve == -1:
			return true
		pos = ve
	return true

static func find(name: String) -> String:
	if strings.has(name):
		return strings[name]
	return "<Missing %s>" % name

static func exists(s: String) -> bool:
	return s.length() >= 3 and s[0] == "[" and strings.has(s.substr(1, s.length() - 2))

static func translate(s: String) -> String:
	if s.length() >= 3 and s[0] == "[" and s[s.length() - 1] == "]":
		return find(s.substr(1, s.length() - 2))
	return s

# ---------------------------------------------------------------- formatted drawing
class Fmt:
	var font: ImageFont
	var color: Color
	var line_spacing_offset := 0
	var flags := 0

static func _set_format(text: String, at: int, f: Fmt) -> void:
	for fm in formats:
		var nm: String = fm[0]
		if text.substr(at, nm.length()) == nm:
			if fm[1] != Color8(0, 0, 0, 0):
				f.color = fm[1]
			f.line_spacing_offset = fm[2]
			f.flags = fm[3]
			return

static func _is_space(ch: String, f: Fmt) -> bool:
	return ch == " " or (Tod.test_bit(f.flags, TOD_FORMAT_IGNORE_NEWLINES) and ch == "\n")

static func write_string(g: Graphics, s: String, x: int, y: int, f: Fmt, width: int, just: int, draw: bool, offset: int, length: int) -> int:
	var font := f.font
	if draw:
		var spare := width - write_string(g, s, x, y, f, width, DS_ALIGN_LEFT, false, offset, length)
		if just == DS_ALIGN_RIGHT or just == DS_ALIGN_RIGHT_VERTICAL_MIDDLE:
			x += spare
		elif just == DS_ALIGN_CENTER or just == DS_ALIGN_CENTER_VERTICAL_MIDDLE:
			x += Tod.idiv(spare, 2)
	if length < 0 or offset + length > s.length():
		length = s.length()
	else:
		length = offset + length
	var cur := ""
	var x_off := 0
	var prev_space := false
	var i := offset
	while i < length:
		var ch := s[i]
		if ch == "{":
			var fe := s.find("}", i + 1)
			if fe != -1:
				var fstart := i + 1
				i = fe
				if draw:
					font.draw_string(g, x + x_off, y, cur, f.color, g.clip)
				x_off += font.string_width(cur)
				cur = ""
				_set_format(s, fstart, f)
				i += 1
				continue
		if Tod.test_bit(f.flags, TOD_FORMAT_IGNORE_NEWLINES):
			if _is_space(ch, f):
				if not prev_space:
					cur += " "
				i += 1
				continue
			else:
				prev_space = false
		cur += ch
		i += 1
	if draw:
		font.draw_string(g, x + x_off, y, cur, f.color, g.clip)
	return x_off + font.string_width(cur)

static func _write_wrapped_helper(g: Graphics, s: String, x: int, y: int, f: Fmt, width: int, just: int, draw: bool, offset: int, length: int, max_chars: int) -> int:
	if offset + length > max_chars:
		length = max_chars - offset
		if length <= 0:
			return -1
	return write_string(g, s, x, y, f, width, just, draw, offset, length)

static func _draw_wrapped_helper(g: Graphics, text: String, rect: Rect2i, font: ImageFont, color: Color, just: int, draw: bool) -> int:
	var max_chars := text.length()
	var f := Fmt.new()
	f.font = font
	f.color = color
	var y_off := font.get_ascent() - font.get_ascent_padding()
	var line_spacing := font.get_line_spacing() + f.line_spacing_offset
	var line_feed_pos := 0
	var cur_pos := 0
	var cur_width := 0
	var cur_char := ""
	var prev_char := 0
	var space_pos := -1
	var max_width := 0
	while cur_pos < text.length():
		cur_char = text[cur_pos]
		if cur_char == "{":
			var fe := text.find("}", cur_pos + 1)
			if fe != -1:
				var fstart := cur_pos + 1
				cur_pos = fe + 1
				var old_asc := font.get_ascent() - font.get_ascent_padding()
				_set_format(text, fstart, f)
				var new_asc := f.font.get_ascent() - f.font.get_ascent_padding()
				line_spacing = f.font.get_line_spacing() + f.line_spacing_offset
				y_off += new_asc - old_asc
				continue
		elif _is_space(cur_char, f):
			space_pos = cur_pos
			cur_char = " "
		elif cur_char == "\n":
			space_pos = cur_pos
			cur_width = rect.size.x + 1
			cur_pos += 1
		var code := cur_char.unicode_at(0) & 0xFF
		cur_width += f.font.char_width_kern(code, prev_char)
		prev_char = code
		if cur_width > rect.size.x:
			var line_width: int
			if space_pos != -1:
				var cur_y := int(g.trans_y) + rect.position.y + y_off
				if cur_y >= g.clip.position.y and cur_y <= g.clip.position.y + g.clip.size.y + line_spacing:
					_write_wrapped_helper(g, text, rect.position.x, rect.position.y + y_off, f, rect.size.x, just, draw, line_feed_pos, space_pos - line_feed_pos, max_chars)
				line_width = cur_width
				if line_width < 0:
					break
				cur_pos = space_pos + 1
				if cur_char != "\n":
					while cur_pos < text.length() and _is_space(text[cur_pos], f):
						cur_pos += 1
			else:
				if cur_pos < line_feed_pos + 1:
					cur_pos += 1
				line_width = _write_wrapped_helper(g, text, rect.position.x, rect.position.y + y_off, f, rect.size.x, just, draw, line_feed_pos, cur_pos - line_feed_pos, max_chars)
				if line_width < 0:
					break
			max_width = maxi(max_width, line_width)
			y_off += line_spacing
			line_feed_pos = cur_pos
			space_pos = -1
			cur_width = 0
			prev_char = 0
		else:
			cur_pos += 1
	if line_feed_pos < text.length():
		var last := _write_wrapped_helper(g, text, rect.position.x, rect.position.y + y_off, f, rect.size.x, just, draw, line_feed_pos, text.length() - line_feed_pos, max_chars)
		if last >= 0:
			y_off += line_spacing
	else:
		y_off += line_spacing
	return (f.font.get_height() - f.font.get_ascent()) + y_off - line_spacing

static func draw_string_wrapped(g: Graphics, text: String, rect: Rect2i, font: ImageFont, color: Color, just: int) -> void:
	var t := translate(text)
	var r := rect
	if just == DS_ALIGN_LEFT_VERTICAL_MIDDLE or just == DS_ALIGN_RIGHT_VERTICAL_MIDDLE or just == DS_ALIGN_CENTER_VERTICAL_MIDDLE:
		r.position.y += Tod.idiv(r.size.y - _draw_wrapped_helper(g, t, r, font, color, just, false), 2)
	_draw_wrapped_helper(g, t, r, font, color, just, true)

## TodDrawString
static func draw_string(g: Graphics, text: String, x: int, y: int, font: ImageFont, color: Color, just: int) -> void:
	var s := translate(text)
	var px := x
	if just == DS_ALIGN_RIGHT or just == DS_ALIGN_RIGHT_VERTICAL_MIDDLE:
		px -= font.string_width(s)
	elif just == DS_ALIGN_CENTER or just == DS_ALIGN_CENTER_VERTICAL_MIDDLE:
		px -= Tod.idiv(font.string_width(s), 2)
	font.draw_string(g, px, y, s, color, g.clip)
