class_name TextWriter
## Port of Sexy::Graphics::WriteString / WriteWordWrapped (supports ^RRGGBB^ color codes).

static func write_string(g: Graphics, s: String, px: int, py: int, w: int, just: int, draw: bool, offset: int, length: int, old_color: Color, colored: bool) -> int:
	var font := g.font
	if draw:
		match just:
			0:
				px += Tod.idiv(w - write_string(g, s, px, py, w, -1, false, offset, length, old_color, colored), 2)
			1:
				px += w - write_string(g, s, px, py, w, -1, false, offset, length, old_color, colored)
	if length < 0 or offset + length > s.length():
		length = s.length()
	else:
		length = offset + length
	var cur := ""
	var x_off := 0
	var i := offset
	while i < length:
		var ch := s[i]
		if ch == "^" and colored:
			if i + 1 < length and s[i + 1] == "^":
				cur += "^"
				i += 2
				continue
			elif i > length - 8:
				break
			else:
				var col := old_color
				if s[i + 1] != "o":
					col = Color8(s.substr(i + 1, 2).hex_to_int(), s.substr(i + 3, 2).hex_to_int(), s.substr(i + 5, 2).hex_to_int(), g.color.a8)
				if draw:
					g.draw_string(cur, px + x_off, py)
					g.color = Color(col.r, col.g, col.b, g.color.a)
				i += 8
				x_off += font.string_width(cur)
				cur = ""
				continue
		cur += ch
		i += 1
	if draw:
		g.draw_string(cur, px + x_off, py)
	x_off += font.string_width(cur)
	return x_off

static func _helper(g: Graphics, s: String, px: int, py: int, w: int, just: int, draw: bool, offset: int, length: int, old_color: Color, max_chars: int, colored: bool) -> int:
	if offset + length > max_chars:
		length = max_chars - offset
		if length <= 0:
			return -1
	return write_string(g, s, px, py, w, just, draw, offset, length, old_color, colored)

static func write_word_wrapped(g: Graphics, rect: Rect2i, line: String, line_spacing: int, just: int, colored: bool = true, draw: bool = true) -> int:
	var orig := g.color
	var max_chars := line.length()
	var font := g.font
	var y_off := font.get_ascent() - font.get_ascent_padding()
	if line_spacing == -1:
		line_spacing = font.get_line_spacing()
	var cur_pos := 0
	var line_start := 0
	var cur_width := 0
	var cur_char := ""
	var prev := 0
	var space_pos := -1
	while cur_pos < line.length():
		cur_char = line[cur_pos]
		if cur_char == "^" and colored:
			if cur_pos + 1 < line.length():
				if line[cur_pos + 1] == "^":
					cur_pos += 1
				else:
					cur_pos += 8
					continue
		elif cur_char == " ":
			space_pos = cur_pos
		elif cur_char == "\n":
			cur_width = rect.size.x + 1
			space_pos = cur_pos
			cur_pos += 1
		var code := cur_char.unicode_at(0) & 0xFF
		cur_width += font.char_width_kern(code, prev)
		prev = code
		if cur_width > rect.size.x:
			var written: int
			if space_pos != -1:
				var phys := rect.position.y + y_off + int(g.trans_y)
				if draw and phys >= g.clip.position.y and phys < g.clip.position.y + g.clip.size.y + line_spacing:
					_helper(g, line, rect.position.x, rect.position.y + y_off, rect.size.x, just, true, line_start, space_pos - line_start, orig, max_chars, colored)
				written = cur_width
				if written < 0:
					break
				cur_pos = space_pos + 1
				if cur_char != "\n":
					while cur_pos < line.length() and line[cur_pos] == " ":
						cur_pos += 1
				line_start = cur_pos
			else:
				if cur_pos < line_start + 1:
					cur_pos += 1
				written = _helper(g, line, rect.position.x, rect.position.y + y_off, rect.size.x, just, draw, line_start, cur_pos - line_start, orig, max_chars, colored)
				if written < 0:
					break
			line_start = cur_pos
			space_pos = -1
			cur_width = 0
			prev = 0
			y_off += line_spacing
		else:
			cur_pos += 1
	if line_start < line.length():
		var w2 := _helper(g, line, rect.position.x, rect.position.y + y_off, rect.size.x, just, draw, line_start, line.length() - line_start, orig, max_chars, colored)
		if w2 >= 0:
			y_off += line_spacing
	elif cur_char == "\n":
		y_off += line_spacing
	g.color = orig
	return y_off + (font.get_height() - font.get_ascent()) - line_spacing

static func get_word_wrapped_height(font: ImageFont, w: int, line: String, line_spacing: int) -> int:
	var g := Graphics.new(null)
	g.font = font
	return write_word_wrapped(g, Rect2i(0, 0, w, 0), line, line_spacing, -1, true, false)

static func draw_string_word_wrapped(g: Graphics, line: String, px: int, py: int, wrap_width: int = 10000000, line_spacing: int = -1, just: int = -1) -> int:
	var y_off := g.font.get_ascent() - g.font.get_ascent_padding()
	return write_word_wrapped(g, Rect2i(px, py - y_off, wrap_width, 0), line, line_spacing, just)
