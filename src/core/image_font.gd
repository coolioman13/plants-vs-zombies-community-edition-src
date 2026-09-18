class_name ImageFont
extends RefCounted
## Port of Sexy::ImageFont + FontData + DescParser.

class CharData:
	var image_rect := Rect2i()
	var offset := Vector2i()
	var width := 0
	var order := 0
	var kerning: Dictionary = {}   # next char code -> offset

class FontLayer:
	var chars: Array = []          # 256 CharData
	var image: PvzImage
	var draw_mode := -1
	var offset := Vector2i()
	var spacing := 0
	var min_point_size := -1
	var max_point_size := -1
	var point_size := 0
	var ascent := 0
	var ascent_padding := 0
	var height := 0
	var default_height := 0
	var color_mult := Color.WHITE
	var color_add := Color(0, 0, 0, 0)
	var line_spacing_offset := 0
	var base_order := 0
	var required_tags: Array = []
	var excluded_tags: Array = []

	func _init() -> void:
		chars.resize(256)
		for i in 256:
			chars[i] = CharData.new()

	func clone() -> FontLayer:
		var l := FontLayer.new()
		for i in 256:
			var s: CharData = chars[i]
			var d: CharData = l.chars[i]
			d.image_rect = s.image_rect
			d.offset = s.offset
			d.width = s.width
			d.order = s.order
			d.kerning = s.kerning.duplicate()
		l.image = image; l.draw_mode = draw_mode; l.offset = offset; l.spacing = spacing
		l.min_point_size = min_point_size; l.max_point_size = max_point_size; l.point_size = point_size
		l.ascent = ascent; l.ascent_padding = ascent_padding; l.height = height; l.default_height = default_height
		l.color_mult = color_mult; l.color_add = color_add; l.line_spacing_offset = line_spacing_offset
		l.base_order = base_order; l.required_tags = required_tags.duplicate(); l.excluded_tags = excluded_tags.duplicate()
		return l

var layers: Array = []           # FontLayer in creation order
var layer_map: Dictionary = {}   # upper name -> FontLayer
var defines: Dictionary = {}
var char_map := PackedInt32Array()
var default_point_size := 0
var point_size := 0
var scale := 1.0
var tags: Array = []
var active: Array = []           # active FontLayer list
var active_valid := false
var initialized := false
var source_file := ""

var ascent := 0
var ascent_padding := 0
var height := 0
var line_spacing_offset := 0

func _init() -> void:
	char_map.resize(256)
	for i in 256:
		char_map[i] = i

func duplicate_font() -> ImageFont:
	var f := ImageFont.new()
	f.layers = layers
	f.layer_map = layer_map
	f.char_map = char_map
	f.default_point_size = default_point_size
	f.point_size = point_size
	f.scale = scale
	f.tags = tags.duplicate()
	f.initialized = initialized
	return f

# ================================================================ descriptor parsing
func load_descriptor(path: String) -> bool:
	source_file = path.replace("\\", "/")
	var text := Res.read_text_latin1(source_file)
	if text == "":
		push_error("Font descriptor not found: " + path)
		return false
	var cur_line := ""
	var i := 0
	var n := text.length()
	var ok := true
	while i < n:
		var at_line_start := true
		var skip_line := false
		var in_sq := false
		var in_dq := false
		var escaped := false
		while i < n:
			var ch := text[i]
			i += 1
			if ch == "\r":
				continue
			if not at_line_start or (ch != " " and ch != "\t" and ch != "\n"):
				if at_line_start:
					if ch == "#":
						skip_line = true
					at_line_start = false
				if ch == "\n":
					at_line_start = true
				if ch == "\n" and skip_line:
					skip_line = false
				elif not skip_line:
					if ch == "\\" and (in_sq or in_dq) and not escaped:
						escaped = true
					else:
						if ch == "'" and not in_dq and not escaped:
							in_sq = not in_sq
						if ch == "\"" and not in_sq and not escaped:
							in_dq = not in_dq
						if ch == ";" and not in_sq and not in_dq:
							break
						if escaped:
							cur_line += "\\"
							escaped = false
						cur_line += ch
		if cur_line.length() > 0:
			if not _parse_descriptor_line(cur_line):
				push_error("Font descriptor error in %s: %s" % [path, cur_line.substr(0, 80)])
				ok = false
				break
			cur_line = ""
	initialized = ok
	point_size = default_point_size
	active_valid = false
	return ok

func _parse_to_list(s: String, pos: Array, expect_end: bool) -> Variant:
	var lst: Array = []
	var in_sq := false
	var in_dq := false
	var escaped := false
	var cur_idx := -1
	while pos[0] < s.length():
		var add := false
		var ch := s[pos[0]]
		pos[0] += 1
		var is_sep := ch == " " or ch == "\t" or ch == "\n" or ch == ","
		if escaped:
			add = true
			escaped = false
		else:
			if ch == "'" and not in_dq:
				in_sq = not in_sq
			elif ch == "\"" and not in_sq:
				in_dq = not in_dq
			if ch == "\\":
				escaped = true
			elif not in_sq and not in_dq:
				if ch == ")":
					if expect_end:
						return lst
					return null
				elif ch == "(":
					if cur_idx != -1:
						return null
					var child = _parse_to_list(s, pos, true)
					if child == null:
						return null
					lst.append(child)
				elif is_sep:
					cur_idx = -1
				else:
					add = true
			else:
				add = true
		if add:
			if cur_idx == -1:
				lst.append("")
				cur_idx = lst.size() - 1
			lst[cur_idx] = str(lst[cur_idx]) + ch
	if in_sq or in_dq or expect_end:
		return null
	return lst

static func _is_immediate(s: String) -> bool:
	if s.is_empty():
		return false
	var c := s[0]
	return (c >= "0" and c <= "9") or c == "-" or c == "+" or c == "'" or c == "\""

static func _unquote(s: String) -> String:
	if s.is_empty() or (s[0] != "'" and s[0] != "\""):
		return s
	var q := s[0]
	var out := ""
	var last_q := false
	for ch in s:
		if ch == q:
			if last_q:
				out += q
			last_q = true
		else:
			out += ch
			last_q = false
	return out

func _get_values(src: Array) -> Variant:
	var out: Array = []
	for e in src:
		if e is Array:
			var c = _get_values(e)
			if c == null:
				return null
			out.append(c)
		else:
			var s: String = e
			if s.length() > 0:
				if s[0] == "'" or s[0] == "\"":
					out.append(_unquote(s))
				elif _is_immediate(s):
					out.append(s)
				else:
					var k := s.to_upper()
					if not defines.has(k):
						return null
					out.append(_dup(defines[k]))
	return out

static func _dup(v: Variant) -> Variant:
	return v.duplicate(true) if v is Array else v

func _data_to_string(v: Variant) -> Variant:
	if v is Array:
		return null
	var d = defines.get(str(v).to_upper())
	if d != null:
		if d is Array:
			return null
		return _unquote(d)
	return _unquote(v)

func _data_to_string_vector(v: Variant) -> Variant:
	var values
	if v is Array:
		values = _get_values(v)
		if values == null:
			return null
	else:
		values = defines.get(str(v).to_upper())
		if values == null or not (values is Array):
			return null
	var out: Array = []
	for e in values:
		if e is Array:
			return null
		out.append(e)
	return out

func _data_to_list(v: Variant) -> Variant:
	if v is Array:
		return _get_values(v)
	var d = defines.get(str(v).to_upper())
	if d == null or not (d is Array):
		return null
	return d

func _data_to_int_vector(v: Variant) -> Variant:
	var sv = _data_to_string_vector(v)
	if sv == null:
		return null
	var out: Array = []
	for s in sv:
		out.append(_string_to_int(s))
	return out

static func _string_to_int(s: String) -> int:
	s = s.strip_edges()
	if s.begins_with("0x") or s.begins_with("0X"):
		return s.substr(2).hex_to_int()
	return s.to_int()

func _data_to_layer(v: Variant) -> FontLayer:
	if v is Array:
		return null
	return layer_map.get(str(v).to_upper())

func _color_from(v: Variant) -> Variant:
	if v is Array:
		var vals = _get_values(v)
		if vals == null or vals.size() != 4:
			return null
		return Color8(int(float(vals[0]) * 255), int(float(vals[1]) * 255), int(float(vals[2]) * 255), int(float(vals[3]) * 255))
	var iv := _string_to_int(str(v))
	var a := (iv >> 24) & 0xFF
	return Color8((iv >> 16) & 0xFF, (iv >> 8) & 0xFF, iv & 0xFF, 0xFF if a == 0 else a)

func _single_int(v: Variant) -> Variant:
	if v is Array:
		return null
	return _string_to_int(str(v))

func _parse_descriptor_line(line: String) -> bool:
	var params = _parse_to_list(line, [0], false)
	if params == null:
		return false
	if params.is_empty():
		return true
	if params[0] is Array:
		return false
	var cmd: String = str(params[0]).to_lower()
	var np: int = params.size()
	match cmd:
		"define":
			if np != 3 or params[1] is Array:
				return false
			var name := str(params[1]).to_upper()
			if params[2] is Array:
				var vals = _get_values(params[2])
				if vals == null:
					return false
				defines[name] = vals
			else:
				var deref = defines.get(str(params[2]).to_upper())
				defines[name] = _dup(deref) if deref != null else params[2]
		"createhorzspanrectlist":
			var rect = _data_to_int_vector(params[2])
			var widths = _data_to_int_vector(params[3])
			if rect == null or widths == null or rect.size() != 4:
				return false
			var xp := 0
			var lst: Array = []
			for w in widths:
				lst.append([str(rect[0] + xp), str(rect[1]), str(w), str(rect[3])])
				xp += w
			defines[str(params[1]).to_upper()] = lst
		"setdefaultpointsize":
			var ps = _single_int(params[1])
			if ps == null:
				return false
			default_point_size = ps
		"setcharmap":
			var from = _data_to_string_vector(params[1])
			var to = _data_to_string_vector(params[2])
			if from == null or to == null or from.size() != to.size():
				return false
			for k in from.size():
				char_map[_latin1(from[k])] = _latin1(to[k])
		"createlayer":
			var l := FontLayer.new()
			layers.append(l)
			layer_map[str(params[1]).to_upper()] = l
		"createlayerfrom":
			var srcl := _data_to_layer(params[2])
			if srcl == null:
				return false
			var l2 := srcl.clone()
			layers.append(l2)
			layer_map[str(params[1]).to_upper()] = l2
		"layerrequiretags", "layerexcludetags":
			var layer := _data_to_layer(params[1])
			var sv = _data_to_string_vector(params[2])
			if layer == null or sv == null:
				return false
			for t in sv:
				if cmd == "layerrequiretags":
					layer.required_tags.append(str(t).to_upper())
				else:
					layer.excluded_tags.append(str(t).to_upper())
		"layerpointrange":
			var layer := _data_to_layer(params[1])
			if layer == null:
				return false
			layer.min_point_size = _single_int(params[2])
			layer.max_point_size = _single_int(params[3])
		"layersetpointsize", "layersetheight", "layersetascent", "layersetascentpadding", "layersetlinespacingoffset", "layersetspacing", "layersetbaseorder", "layersetdrawmode":
			var layer := _data_to_layer(params[1])
			var v = _single_int(params[2]) if np == 3 else null
			if layer == null or v == null:
				return false
			match cmd:
				"layersetpointsize": layer.point_size = v
				"layersetheight": layer.height = v
				"layersetascent": layer.ascent = v
				"layersetascentpadding": layer.ascent_padding = v
				"layersetlinespacingoffset": layer.line_spacing_offset = v
				"layersetspacing": layer.spacing = v
				"layersetbaseorder": layer.base_order = v
				"layersetdrawmode": layer.draw_mode = v
		"layersetimage":
			var layer := _data_to_layer(params[1])
			var fname = _data_to_string(params[2])
			if layer == null or fname == null:
				return false
			var dir := source_file.get_base_dir()
			var p: String = fname
			if not (p.begins_with("/") or p.contains(":")):
				p = dir + "/" + p
			layer.image = Res.load_image_path(p)
			if layer.image == null:
				push_error("Font image not found: " + p)
				return false
		"layersetcolormult", "layersetcoloradd":
			var layer := _data_to_layer(params[1])
			var c = _color_from(params[2])
			if layer == null or c == null:
				return false
			if cmd == "layersetcolormult":
				layer.color_mult = c
			else:
				layer.color_add = c
		"layersetoffset":
			var layer := _data_to_layer(params[1])
			var off = _data_to_int_vector(params[2])
			if layer == null or off == null or off.size() != 2:
				return false
			layer.offset = Vector2i(off[0], off[1])
		"layersetcharwidths", "layersetcharorders":
			var layer := _data_to_layer(params[1])
			var cs = _data_to_string_vector(params[2])
			var vs = _data_to_int_vector(params[3])
			if layer == null or cs == null or vs == null or cs.size() != vs.size():
				return false
			for k in cs.size():
				var cd: CharData = layer.chars[_latin1(cs[k])]
				if cmd == "layersetcharwidths":
					cd.width = vs[k]
				else:
					cd.order = vs[k]
		"layersetimagemap":
			var layer := _data_to_layer(params[1])
			var cs = _data_to_string_vector(params[2])
			var rects = _data_to_list(params[3])
			if layer == null or cs == null or rects == null or cs.size() != rects.size() or layer.image == null:
				return false
			for k in cs.size():
				var r = _data_to_int_vector(rects[k])
				if r == null or r.size() != 4:
					return false
				(layer.chars[_latin1(cs[k])] as CharData).image_rect = Rect2i(r[0], r[1], r[2], r[3])
			layer.default_height = 0
			for cd in layer.chars:
				if cd.image_rect.size.y + cd.offset.y > layer.default_height:
					layer.default_height = cd.image_rect.size.y + cd.offset.y
		"layersetcharoffsets":
			var layer := _data_to_layer(params[1])
			var cs = _data_to_string_vector(params[2])
			var offs = _data_to_list(params[3])
			if layer == null or cs == null or offs == null or cs.size() != offs.size():
				return false
			for k in cs.size():
				var o = _data_to_int_vector(offs[k])
				if o == null or o.size() != 2:
					return false
				(layer.chars[_latin1(cs[k])] as CharData).offset = Vector2i(o[0], o[1])
		"layersetkerningpairs":
			var layer := _data_to_layer(params[1])
			var pairs = _data_to_string_vector(params[2])
			var vals = _data_to_int_vector(params[3])
			if layer == null or pairs == null or vals == null or pairs.size() != vals.size():
				return false
			for k in pairs.size():
				var pstr: String = pairs[k]
				if pstr.length() == 2:
					(layer.chars[_latin1(pstr[0])] as CharData).kerning[_latin1(pstr[1])] = vals[k]
		_:
			push_warning("Unknown font command: " + cmd)
			return false
	return true

static func _latin1(s: String) -> int:
	if s.is_empty():
		return 0
	return s.unicode_at(0) & 0xFF

# ================================================================ metrics
func prepare() -> void:
	if active_valid:
		return
	active_valid = true
	active.clear()
	ascent = 0
	ascent_padding = 0
	height = 0
	line_spacing_offset = 0
	var first := true
	for l in layers:
		var layer: FontLayer = l
		if point_size >= layer.min_point_size and (point_size <= layer.max_point_size or layer.max_point_size == -1):
			var on := true
			for t in layer.required_tags:
				if not tags.has(t):
					on = false
			for t in tags:
				if layer.excluded_tags.has(t):
					on = false
			if not on:
				continue
			active.append(layer)
			var layer_ps := 1.0
			var ps := scale
			if layer.point_size != 0 and not (scale == 1.0 and point_size == layer.point_size):
				layer_ps = layer.point_size
				ps = point_size * scale
			var la := int(layer.ascent * ps / layer_ps)
			ascent = maxi(ascent, la)
			var lh := int((layer.height if layer.height != 0 else layer.default_height) * ps / layer_ps)
			height = maxi(height, lh)
			var ap := int(layer.ascent_padding * ps / layer_ps)
			if first or ap < ascent_padding:
				ascent_padding = ap
			var lso := int(layer.line_spacing_offset * ps / layer_ps)
			if first or lso > line_spacing_offset:
				line_spacing_offset = lso
			first = false

func get_ascent() -> int:
	prepare()
	return ascent

func get_ascent_padding() -> int:
	prepare()
	return ascent_padding

func get_height() -> int:
	prepare()
	return height

func get_line_spacing() -> int:
	prepare()
	return height + line_spacing_offset

func set_point_size(ps: int) -> void:
	point_size = ps
	active_valid = false

func set_scale(s: float) -> void:
	scale = s
	active_valid = false

func add_tag(t: String) -> void:
	if not tags.has(t.to_upper()):
		tags.append(t.to_upper())
		active_valid = false

func mapped(code: int) -> int:
	return char_map[code & 0xFF]

func char_width_kern(ch: int, prev: int) -> int:
	prepare()
	var max_x := 0
	var ps := point_size * scale
	ch = char_map[ch & 0xFF]
	if prev != 0:
		prev = char_map[prev & 0xFF]
	for l in active:
		var layer: FontLayer = l
		var cw: int
		var sp := 0
		if layer.point_size == 0:
			cw = int((layer.chars[ch] as CharData).width * scale)
			if prev != 0:
				sp = int((layer.spacing + (layer.chars[prev] as CharData).kerning.get(ch, 0)) * scale)
		else:
			cw = int((layer.chars[ch] as CharData).width * ps / layer.point_size)
			if prev != 0:
				sp = int((layer.spacing + (layer.chars[prev] as CharData).kerning.get(ch, 0)) * ps / layer.point_size)
		max_x = maxi(max_x, cw + sp)
	return max_x

func char_width(ch: int) -> int:
	return char_width_kern(ch, 0)

func string_width(s: String) -> int:
	var w := 0
	var prev := 0
	for i in s.length():
		var c := s.unicode_at(i) & 0xFF
		w += char_width_kern(c, prev)
		prev = c
	return w

# ================================================================ drawing
func _layer_color(layer: FontLayer, c: Color) -> Color:
	return Color8(
		mini(Tod.idiv(c.r8 * layer.color_mult.r8, 255) + layer.color_add.r8, 255),
		mini(Tod.idiv(c.g8 * layer.color_mult.g8, 255) + layer.color_add.g8, 255),
		mini(Tod.idiv(c.b8 * layer.color_mult.b8, 255) + layer.color_add.b8, 255),
		mini(Tod.idiv(c.a8 * layer.color_mult.a8, 255) + layer.color_add.a8, 255))

## Builds render commands: Array of [order, image, dest Vector2, src Rect2, Color, mode]; returns width.
func _build_commands(x: int, y: int, s: String, c: Color, cmds: Array) -> int:
	prepare()
	var cur_x := x
	var n := s.length()
	for i in n:
		var ch := char_map[s.unicode_at(i) & 0xFF]
		var nxt := 0
		if i < n - 1:
			nxt = char_map[s.unicode_at(i + 1) & 0xFF]
		var max_x := cur_x
		for l in active:
			var layer: FontLayer = l
			var cd: CharData = layer.chars[ch]
			var lscale := scale
			if layer.point_size != 0:
				lscale *= float(point_size) / layer.point_size
			var ix: int
			var iy: int
			var cw: int
			var sp := 0
			if lscale == 1.0:
				ix = cur_x + layer.offset.x + cd.offset.x
				iy = y - (layer.ascent - layer.offset.y - cd.offset.y)
				cw = cd.width
				if nxt != 0:
					sp = layer.spacing + cd.kerning.get(nxt, 0)
			else:
				ix = cur_x + int((layer.offset.x + cd.offset.x) * lscale)
				iy = y - int((layer.ascent - layer.offset.y - cd.offset.y) * lscale)
				cw = int(cd.width * lscale)
				if nxt != 0:
					sp = int((layer.spacing + cd.kerning.get(nxt, 0)) * lscale)
			var order := clampi(layer.base_order + cd.order + 128, 0, 255)
			cmds.append([order, cmds.size(), layer.image, Vector2(ix, iy), Rect2(cd.image_rect), _layer_color(layer, c), layer.draw_mode, lscale])
			max_x = maxi(max_x, cur_x + cw + sp)
		cur_x = max_x
	cmds.sort_custom(func(a, b): return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	return cur_x - x

func draw_string(g: Graphics, x: int, y: int, s: String, c: Color, _clip: Rect2 = Rect2()) -> void:
	if not initialized or s.is_empty():
		return
	var cmds: Array = []
	_build_commands(x, y, s, c, cmds)
	var old_color := g.color
	var old_mode := g.draw_mode
	var old_colorize := g.colorize_images
	g.colorize_images = true
	for cmd in cmds:
		if cmd[2] == null:
			continue
		g.draw_mode = old_mode if cmd[6] == -1 else cmd[6]
		g.color = cmd[5]
		var src: Rect2 = cmd[4]
		if src.size.x <= 0:
			continue
		if cmd[7] == 1.0:
			g.draw_image_src(cmd[2], cmd[3].x, cmd[3].y, src)
		else:
			g.draw_image_stretch(cmd[2], Rect2(cmd[3].x, cmd[3].y, src.size.x * cmd[7], src.size.y * cmd[7]), src)
	g.draw_mode = old_mode
	g.color = old_color
	g.colorize_images = old_colorize

## TodDrawStringMatrix
func draw_string_matrix(g: Graphics, xf: Transform2D, s: String, c: Color) -> void:
	if not initialized or s.is_empty():
		return
	var cmds: Array = []
	_build_commands(0, 0, s, c, cmds)
	for cmd in cmds:
		if cmd[2] == null:
			continue
		var src: Rect2 = cmd[4]
		if src.size.x <= 0:
			continue
		var mode: int = g.draw_mode if cmd[6] == -1 else cmd[6]
		var local := Transform2D(Vector2(1, 0), Vector2(0, 1), Vector2(src.size.x * 0.5 + cmd[3].x, src.size.y * 0.5 + cmd[3].y))
		g.blt_matrix(cmd[2], xf * local, g.clip, cmd[5], mode, src)
