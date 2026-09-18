class_name Defs
## Loads PopCap "definition" files: compiled reanims/particles/trails (*.compiled, zlib memory dumps)
## plus uncompiled XML .reanim files for custom content.

const COOKIE := 0xDEADFED4

# ================================================================ data classes
class FloatTrack:
	## Flattened nodes: time, low, high, curve, distribution
	var nodes := PackedFloat32Array()

	func count() -> int:
		return nodes.size() / 5

	func is_set() -> bool:
		return nodes.size() > 0 and int(nodes[3]) != Tod.CURVE_CONSTANT

	func is_constant_zero() -> bool:
		return nodes.size() == 0 or (nodes.size() == 5 and nodes[1] == 0.0 and nodes[2] == 0.0)

	func set_default(v: float) -> void:
		if nodes.size() == 0 and v != 0.0:
			nodes = PackedFloat32Array([0.0, v, v, Tod.CURVE_CONSTANT, Tod.CURVE_LINEAR])

	func evaluate(t: float, interp: float) -> float:
		var n := nodes.size()
		if n == 0:
			return 0.0
		if t < nodes[0]:
			return Tod.curve_evaluate(interp, nodes[1], nodes[2], int(nodes[4]))
		var i := 5
		while i < n:
			if t <= nodes[i]:
				var frac := (t - nodes[i - 5]) / (nodes[i] - nodes[i - 5])
				var lv := Tod.curve_evaluate(interp, nodes[i - 4], nodes[i - 3], int(nodes[i - 1]))
				var rv := Tod.curve_evaluate(interp, nodes[i + 1], nodes[i + 2], int(nodes[i + 4]))
				return Tod.curve_evaluate(frac, lv, rv, int(nodes[i - 2]))
			i += 5
		return Tod.curve_evaluate(interp, nodes[n - 4], nodes[n - 3], int(nodes[n - 1]))

	func evaluate_from_last_time(t: float, interp: float) -> float:
		return 0.0 if t < 0.0 else evaluate(t, interp)

class ReanimTrackDef:
	var name := ""
	var x := PackedFloat32Array()
	var y := PackedFloat32Array()
	var kx := PackedFloat32Array()
	var ky := PackedFloat32Array()
	var sx := PackedFloat32Array()
	var sy := PackedFloat32Array()
	var f := PackedFloat32Array()
	var a := PackedFloat32Array()
	var images: Array = []   # PvzImage or null
	var fonts: Array = []    # ImageFont or null
	var texts := PackedStringArray()
	var frame_count := 0
	var is_attacher := false
	var is_fullscreen := false  # the "fullscreen" colour-fill track (precomputed so drawing never lowercases names)
	var can_draw := true        # false when no frame ever shows anything, so drawing can skip the track

class ReanimDef:
	var fps := 12.0
	var tracks: Array = []           # ReanimTrackDef
	var track_index: Dictionary = {} # lower name -> index
	var path := ""
	var attacher_tracks := PackedInt32Array()  # indices of "attacher__" tracks
	var ground_track := -1                     # index of the "_ground" track, -1 if none

	func find_track(name: String) -> int:
		return track_index.get(name.to_lower(), -1)

class ParticleField:
	var type := 0
	var x := FloatTrack.new()
	var y := FloatTrack.new()

class EmitterDef:
	var image: PvzImage
	var image_col := 0
	var image_row := 0
	var image_frames := 1
	var animated := 0
	var flags := 0
	var emitter_type := 1
	var name := ""
	var on_duration := ""
	var system_duration := FloatTrack.new()
	var cross_fade_duration := FloatTrack.new()
	var spawn_rate := FloatTrack.new()
	var spawn_min_active := FloatTrack.new()
	var spawn_max_active := FloatTrack.new()
	var spawn_max_launched := FloatTrack.new()
	var emitter_radius := FloatTrack.new()
	var emitter_offset_x := FloatTrack.new()
	var emitter_offset_y := FloatTrack.new()
	var emitter_box_x := FloatTrack.new()
	var emitter_box_y := FloatTrack.new()
	var emitter_path := FloatTrack.new()
	var emitter_skew_x := FloatTrack.new()
	var emitter_skew_y := FloatTrack.new()
	var particle_duration := FloatTrack.new()
	var system_red := FloatTrack.new()
	var system_green := FloatTrack.new()
	var system_blue := FloatTrack.new()
	var system_alpha := FloatTrack.new()
	var system_brightness := FloatTrack.new()
	var launch_speed := FloatTrack.new()
	var launch_angle := FloatTrack.new()
	var particle_fields: Array = []
	var system_fields: Array = []
	var particle_red := FloatTrack.new()
	var particle_green := FloatTrack.new()
	var particle_blue := FloatTrack.new()
	var particle_alpha := FloatTrack.new()
	var particle_brightness := FloatTrack.new()
	var particle_spin_angle := FloatTrack.new()
	var particle_spin_speed := FloatTrack.new()
	var particle_scale := FloatTrack.new()
	var particle_stretch := FloatTrack.new()
	var collision_reflect := FloatTrack.new()
	var collision_spin := FloatTrack.new()
	var clip_top := FloatTrack.new()
	var clip_bottom := FloatTrack.new()
	var clip_left := FloatTrack.new()
	var clip_right := FloatTrack.new()
	var animation_rate := FloatTrack.new()

class ParticleDef:
	var emitters: Array = []
	var path := ""

class TrailDef:
	var image: PvzImage
	var max_points := 2
	var min_point_distance := 1.0
	var flags := 0
	var width_over_length := FloatTrack.new()
	var width_over_time := FloatTrack.new()
	var alpha_over_length := FloatTrack.new()
	var alpha_over_time := FloatTrack.new()
	var trail_duration := FloatTrack.new()

# ================================================================ binary reader
class Reader:
	var b: PackedByteArray
	var p := 0

	func _init(buf: PackedByteArray) -> void:
		b = buf

	func i32() -> int:
		var v := b.decode_s32(p)
		p += 4
		return v

	func str_() -> String:
		var n := b.decode_s32(p)
		p += 4
		if n <= 0:
			return ""
		var s := Res.latin1_to_string(b.slice(p, p + n))
		p += n
		return s

	func track() -> FloatTrack:
		var t := FloatTrack.new()
		var n := i32()
		if n > 0:
			var arr := PackedFloat32Array()
			arr.resize(n * 5)
			for k in n:
				var o := p + k * 20
				arr[k * 5] = b.decode_float(o)
				arr[k * 5 + 1] = b.decode_float(o + 4)
				arr[k * 5 + 2] = b.decode_float(o + 8)
				arr[k * 5 + 3] = b.decode_s32(o + 12)
				arr[k * 5 + 4] = b.decode_s32(o + 16)
			p += n * 20
			t.nodes = arr
		return t

static var _reanim_cache: Dictionary = {}
static var _particle_cache: Dictionary = {}
static var _trail_cache: Dictionary = {}

static func _read_compiled(rel_path: String) -> PackedByteArray:
	var data := Res.read_bytes(rel_path)
	if data.size() < 8:
		return PackedByteArray()
	if data.decode_u32(0) != COOKIE:
		push_error("Compiled definition cookie wrong: " + rel_path)
		return PackedByteArray()
	var size := data.decode_u32(4)
	return data.slice(8).decompress(size, FileAccess.COMPRESSION_DEFLATE)

## Every compiled definition must be consumed exactly; leftover bytes mean a schema misread.
static func _check_end(r: Reader, what: String) -> void:
	if r.p != r.b.size():
		push_error("Compiled %s parse ended at %d of %d bytes" % [what, r.p, r.b.size()])

static func _image(name: String, resolver: Callable = Callable()) -> PvzImage:
	if name == "":
		return null
	if resolver.is_valid():
		var img = resolver.call(name)
		if img != null:
			return img
	return Res.get_image(name)

# ================================================================ reanim
## path like "reanim/Zombie.reanim" (compiled path is compiled/<path>.compiled)
static func load_reanim(path: String) -> ReanimDef:
	var key := path.replace("\\", "/").to_lower()
	if _reanim_cache.has(key):
		return _reanim_cache[key]
	var def: ReanimDef = null
	if Res.file_exists(key):
		def = _load_reanim_xml(key)
	if def == null:
		var buf := _read_compiled("compiled/" + key + ".compiled")
		if buf.size() > 0:
			def = _parse_compiled_reanim(buf)
	if def == null:
		push_error("Failed to load reanim " + path)
		def = ReanimDef.new()
	def.path = path
	_fill_missing(def)
	_reanim_cache[key] = def
	return def

static func _parse_compiled_reanim(buf: PackedByteArray) -> ReanimDef:
	var r := Reader.new(buf)
	r.p = 4  # schema hash
	var def := ReanimDef.new()
	var track_count := buf.decode_s32(r.p + 4)
	def.fps = buf.decode_float(r.p + 8)
	r.p += 16
	if r.i32() != 12:
		push_error("Reanim schema mismatch")
		return null
	var raw_tracks := r.p
	r.p += 12 * track_count
	for t in track_count:
		var frames := buf.decode_s32(raw_tracks + t * 12 + 8)
		var td := ReanimTrackDef.new()
		td.name = r.str_()
		if r.i32() != 44:
			push_error("Reanim transform schema mismatch")
			return null
		var base := r.p
		r.p += 44 * frames
		td.frame_count = frames
		td.x.resize(frames); td.y.resize(frames); td.kx.resize(frames); td.ky.resize(frames)
		td.sx.resize(frames); td.sy.resize(frames); td.f.resize(frames); td.a.resize(frames)
		td.images.resize(frames)
		td.fonts.resize(frames)
		td.texts.resize(frames)
		for k in frames:
			var o := base + k * 44
			td.x[k] = buf.decode_float(o)
			td.y[k] = buf.decode_float(o + 4)
			td.kx[k] = buf.decode_float(o + 8)
			td.ky[k] = buf.decode_float(o + 12)
			td.sx[k] = buf.decode_float(o + 16)
			td.sy[k] = buf.decode_float(o + 20)
			td.f[k] = buf.decode_float(o + 24)
			td.a[k] = buf.decode_float(o + 28)
			var img_name := r.str_()
			var font_name := r.str_()
			td.texts[k] = r.str_()
			td.images[k] = _image(img_name) if img_name != "" else null
			td.fonts[k] = Res.get_font(font_name) if font_name != "" else null
		def.tracks.append(td)
	_check_end(r, "reanim")
	return def

## Loads a .reanim XML from any absolute path (user:// custom content). [param resolver] takes the
## image id named by the file and returns a PvzImage, so a level can ship its own art.
static func load_reanim_external(abs_path: String, resolver: Callable) -> ReanimDef:
	var def := _parse_reanim_xml(abs_path, resolver)
	if def == null:
		return null
	def.path = abs_path
	_fill_missing(def)
	return def

static func _load_reanim_xml(rel_path: String) -> ReanimDef:
	return _parse_reanim_xml(Res.find_file(rel_path), Callable())

static func _parse_reanim_xml(p: String, resolver: Callable) -> ReanimDef:
	if p == "":
		return null
	var parser := XMLParser.new()
	if parser.open(p) != OK:
		return null
	var def := ReanimDef.new()
	var td: ReanimTrackDef = null
	var field := ""
	var in_t := false
	var fr := {}
	while parser.read() == OK:
		match parser.get_node_type():
			XMLParser.NODE_ELEMENT:
				var n := parser.get_node_name()
				if n == "track":
					td = ReanimTrackDef.new()
				elif n == "t":
					in_t = true
					fr = {}
				else:
					field = n
				if parser.is_empty() and n == "t":
					in_t = false
					_append_xml_frame(td, fr, resolver)
			XMLParser.NODE_TEXT:
				var v := parser.get_node_data().strip_edges()
				if v == "" or field == "":
					continue
				if not in_t:
					if field == "fps":
						def.fps = v.to_float()
					elif field == "name" and td != null:
						td.name = v
				else:
					fr[field] = v
			XMLParser.NODE_ELEMENT_END:
				var n2 := parser.get_node_name()
				if n2 == "t":
					in_t = false
					_append_xml_frame(td, fr, resolver)
				elif n2 == "track":
					def.tracks.append(td)
					td = null
				field = ""
	return def

static func _append_xml_frame(td: ReanimTrackDef, fr: Dictionary, resolver: Callable = Callable()) -> void:
	if td == null:
		return
	var ph := Tod.DEFAULT_FIELD_PLACEHOLDER
	td.x.append(float(fr.get("x", ph)))
	td.y.append(float(fr.get("y", ph)))
	td.kx.append(float(fr.get("kx", ph)))
	td.ky.append(float(fr.get("ky", ph)))
	td.sx.append(float(fr.get("sx", ph)))
	td.sy.append(float(fr.get("sy", ph)))
	td.f.append(float(fr.get("f", ph)))
	td.a.append(float(fr.get("a", ph)))
	td.images.append(_image(fr.get("i", ""), resolver))
	td.fonts.append(Res.get_font(fr["font"]) if fr.has("font") else null)
	td.texts.append(fr.get("text", ""))
	td.frame_count += 1

## ReanimationLoadDefinition: carry previous values forward into placeholder slots.
static func _fill_arr(arr: PackedFloat32Array, default: float) -> PackedFloat32Array:
	var ph := Tod.DEFAULT_FIELD_PLACEHOLDER
	var prev := default
	for k in arr.size():
		if arr[k] == ph:
			arr[k] = prev
		else:
			prev = arr[k]
	return arr

static func _fill_missing(def: ReanimDef) -> void:
	for i in def.tracks.size():
		var td: ReanimTrackDef = def.tracks[i]
		def.track_index[td.name.to_lower()] = i
		td.is_attacher = td.name.to_lower().begins_with("attacher__")
		td.is_fullscreen = td.name.to_lower() == "fullscreen"
		if td.is_attacher:
			def.attacher_tracks.append(i)
		if td.name.to_lower() == "_ground":  # last one wins, like track_index
			def.ground_track = i
		td.x = _fill_arr(td.x, 0.0)
		td.y = _fill_arr(td.y, 0.0)
		td.kx = _fill_arr(td.kx, 0.0)
		td.ky = _fill_arr(td.ky, 0.0)
		td.sx = _fill_arr(td.sx, 1.0)
		td.sy = _fill_arr(td.sy, 1.0)
		td.f = _fill_arr(td.f, 0.0)
		td.a = _fill_arr(td.a, 1.0)
		var prev_img = null
		var prev_font = null
		var prev_text := ""
		for k in td.frame_count:
			if td.images[k] == null:
				td.images[k] = prev_img
			else:
				prev_img = td.images[k]
			if td.fonts[k] == null:
				td.fonts[k] = prev_font
			else:
				prev_font = td.fonts[k]
			if td.texts[k] == "":
				td.texts[k] = prev_text
			else:
				prev_text = td.texts[k]
		td.can_draw = false
		for k in td.frame_count:
			if Tod.round_to_int(td.f[k]) >= 0 and (td.is_fullscreen or td.images[k] != null or (td.fonts[k] != null and td.texts[k] != "")):
				td.can_draw = true
				break

# ================================================================ particles
static func load_particle(path: String) -> ParticleDef:
	var key := path.replace("\\", "/").to_lower()
	if _particle_cache.has(key):
		return _particle_cache[key]
	var def := ParticleDef.new()
	def.path = path
	var buf := _read_compiled("compiled/" + key + ".compiled")
	if buf.size() == 0:
		push_error("Failed to load particle " + path)
	else:
		_parse_compiled_particle(buf, def)
	for e in def.emitters:
		var ed: EmitterDef = e
		ed.system_duration.set_default(0.0)
		ed.spawn_rate.set_default(0.0)
		ed.spawn_min_active.set_default(-1.0)
		ed.spawn_max_active.set_default(-1.0)
		ed.spawn_max_launched.set_default(-1.0)
		ed.emitter_radius.set_default(0.0)
		ed.emitter_offset_x.set_default(0.0)
		ed.emitter_offset_y.set_default(0.0)
		ed.emitter_box_x.set_default(0.0)
		ed.emitter_box_y.set_default(0.0)
		ed.emitter_skew_x.set_default(0.0)
		ed.emitter_skew_y.set_default(0.0)
		ed.particle_duration.set_default(100.0)
		ed.launch_speed.set_default(0.0)
		ed.system_red.set_default(1.0)
		ed.system_green.set_default(1.0)
		ed.system_blue.set_default(1.0)
		ed.system_alpha.set_default(1.0)
		ed.system_brightness.set_default(1.0)
		ed.launch_angle.set_default(0.0)
		ed.cross_fade_duration.set_default(0.0)
		ed.particle_red.set_default(1.0)
		ed.particle_green.set_default(1.0)
		ed.particle_blue.set_default(1.0)
		ed.particle_alpha.set_default(1.0)
		ed.particle_brightness.set_default(1.0)
		ed.particle_spin_angle.set_default(0.0)
		ed.particle_spin_speed.set_default(0.0)
		ed.particle_scale.set_default(1.0)
		ed.particle_stretch.set_default(1.0)
		ed.collision_reflect.set_default(0.0)
		ed.collision_spin.set_default(0.0)
		ed.clip_top.set_default(0.0)
		ed.clip_bottom.set_default(0.0)
		ed.clip_left.set_default(0.0)
		ed.clip_right.set_default(0.0)
		ed.animation_rate.set_default(0.0)
	_particle_cache[key] = def
	return def

static func _parse_compiled_particle(buf: PackedByteArray, def: ParticleDef) -> void:
	var r := Reader.new(buf)
	r.p = 4
	var emitter_count := buf.decode_s32(r.p + 4)
	r.p += 8
	if emitter_count == 0:
		return
	if r.i32() != 0x164:
		push_error("Emitter schema mismatch")
		return
	var raw := r.p
	r.p += 0x164 * emitter_count
	for i in emitter_count:
		var o := raw + i * 0x164
		var ed := EmitterDef.new()
		ed.image_col = buf.decode_s32(o + 0x4)
		ed.image_row = buf.decode_s32(o + 0x8)
		ed.image_frames = buf.decode_s32(o + 0xC)
		ed.animated = buf.decode_s32(o + 0x10)
		ed.flags = buf.decode_s32(o + 0x14)
		ed.emitter_type = buf.decode_s32(o + 0x18)
		var field_count := buf.decode_s32(o + 0xD8)
		var sys_field_count := buf.decode_s32(o + 0xE0)
		# Field read order follows gEmitterDefFields declaration order.
		ed.image = _image(r.str_())
		ed.name = r.str_()
		ed.system_duration = r.track()
		ed.on_duration = r.str_()
		ed.cross_fade_duration = r.track()
		ed.spawn_rate = r.track()
		ed.spawn_min_active = r.track()
		ed.spawn_max_active = r.track()
		ed.spawn_max_launched = r.track()
		ed.emitter_radius = r.track()
		ed.emitter_offset_x = r.track()
		ed.emitter_offset_y = r.track()
		ed.emitter_box_x = r.track()
		ed.emitter_box_y = r.track()
		ed.emitter_path = r.track()
		ed.emitter_skew_x = r.track()
		ed.emitter_skew_y = r.track()
		ed.particle_duration = r.track()
		ed.system_red = r.track()
		ed.system_green = r.track()
		ed.system_blue = r.track()
		ed.system_alpha = r.track()
		ed.system_brightness = r.track()
		ed.launch_speed = r.track()
		ed.launch_angle = r.track()
		ed.particle_fields = _read_field_array(r, buf, field_count)
		ed.system_fields = _read_field_array(r, buf, sys_field_count)
		ed.particle_red = r.track()
		ed.particle_green = r.track()
		ed.particle_blue = r.track()
		ed.particle_alpha = r.track()
		ed.particle_brightness = r.track()
		ed.particle_spin_angle = r.track()
		ed.particle_spin_speed = r.track()
		ed.particle_scale = r.track()
		ed.particle_stretch = r.track()
		ed.collision_reflect = r.track()
		ed.collision_spin = r.track()
		ed.clip_top = r.track()
		ed.clip_bottom = r.track()
		ed.clip_left = r.track()
		ed.clip_right = r.track()
		ed.animation_rate = r.track()
		def.emitters.append(ed)
	_check_end(r, "particle")

static func _read_field_array(r: Reader, buf: PackedByteArray, count: int) -> Array:
	var out: Array = []
	var size := r.i32()
	if size != 20:
		push_error("Particle field schema mismatch")
		return out
	if count == 0:
		return out
	var raw := r.p
	r.p += 20 * count
	for i in count:
		var pf := ParticleField.new()
		pf.type = buf.decode_s32(raw + i * 20)
		pf.x = r.track()
		pf.y = r.track()
		out.append(pf)
	return out

# ================================================================ trails
static func load_trail(path: String) -> TrailDef:
	var key := path.replace("\\", "/").to_lower()
	if _trail_cache.has(key):
		return _trail_cache[key]
	var def := TrailDef.new()
	var buf := _read_compiled("compiled/" + key + ".compiled")
	if buf.size() > 0:
		var r := Reader.new(buf)
		r.p = 4
		var raw := r.p
		r.p += 0x38
		def.max_points = buf.decode_s32(raw + 4)
		def.min_point_distance = buf.decode_float(raw + 8)
		def.flags = buf.decode_s32(raw + 0xC)
		def.image = _image(r.str_())
		def.width_over_length = r.track()
		def.width_over_time = r.track()
		def.alpha_over_length = r.track()
		def.alpha_over_time = r.track()
		def.trail_duration = r.track()
		_check_end(r, "trail")
		def.width_over_length.set_default(1.0)
		def.width_over_time.set_default(1.0)
		def.trail_duration.set_default(100.0)
		def.alpha_over_length.set_default(1.0)
		def.alpha_over_time.set_default(1.0)
	else:
		push_error("Failed to load trail " + path)
	_trail_cache[key] = def
	return def
