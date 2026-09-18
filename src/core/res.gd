class_name Res
## Resource manager: port of Sexy::ResourceManager + ImageLib alpha composition rules.
## Files are looked up case-insensitively (the original game ran on Windows).

const ASSET_DIRS := ["images", "reanim", "particles", "data", "properties", "sounds", "compiled", "languages", "music"]
const IMAGE_EXTS := ["tga", "jpg", "png", "gif", "webp"]

static var _index: Dictionary = {}          # "images/seedbank" -> {"png": "res://images/SeedBank.png"}
static var _raw_index: Dictionary = {}      # "compiled/reanim/sun.reanim.compiled" -> actual path
static var _image_defs: Dictionary = {}     # "IMAGE_SEEDBANK" -> Dictionary
static var _sound_defs: Dictionary = {}
static var _font_defs: Dictionary = {}
static var _images: Dictionary = {}         # id -> PvzImage
static var _path_images: Dictionary = {}    # lowercase path (no ext) -> PvzImage (shared image cache)
static var _fonts: Dictionary = {}
static var _sounds: Dictionary = {}
static var _initialized := false
static var _groups: Dictionary = {}     # resource group id -> Array of resource ids
## Optional "id -> PvzImage or null" callback consulted before the normal lookup.
## Custom levels install one (CustomAssets) so they can reskin any image resource.
static var image_override_hook := Callable()

static func init() -> void:
	if _initialized:
		return
	_initialized = true
	for d in ASSET_DIRS:
		_scan_dir("res://" + d)
	_parse_resources_xml()

static func _scan_dir(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		var name := f
		if name.ends_with(".import"):
			name = name.trim_suffix(".import")
		elif name.ends_with(".remap"):
			name = name.trim_suffix(".remap")
		elif name.ends_with(".uid"):
			continue
		var full := path + "/" + name
		var rel := full.trim_prefix("res://").to_lower()
		_raw_index[rel] = full
		var dot := rel.rfind(".")
		var slash := rel.rfind("/")
		if dot > slash:
			var base := rel.substr(0, dot)
			var ext := rel.substr(dot + 1)
			if not _index.has(base):
				_index[base] = {}
			_index[base][ext] = full
	for sub in dir.get_directories():
		_scan_dir(path + "/" + sub)

## Every GDScript under [param path] as "res://.../name.gd", also in exported builds where scripts are stored
## as .gdc / .gd.remap.
static func list_scripts(path: String) -> Array:
	var out: Array = []
	_list_scripts(path, out)
	out.sort()
	return out

static func _list_scripts(path: String, out: Array) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		var name := f
		if name.ends_with(".gd.remap"):
			name = name.trim_suffix(".remap")
		elif name.ends_with(".gdc"):
			name = name.trim_suffix("c")
		if name.ends_with(".gd") and not out.has(path + "/" + name):
			out.append(path + "/" + name)
	for sub in dir.get_directories():
		_list_scripts(path + "/" + sub, out)

static func find_file(rel_path: String) -> String:
	return _raw_index.get(rel_path.replace("\\", "/").to_lower(), "")

static func file_exists(rel_path: String) -> bool:
	return find_file(rel_path) != ""

static func read_bytes(rel_path: String) -> PackedByteArray:
	var p := find_file(rel_path)
	if p == "":
		return PackedByteArray()
	return FileAccess.get_file_as_bytes(p)

## Returns the text of a file decoded as latin-1 (PopCap data files are 8 bit).
static func read_text_latin1(rel_path: String) -> String:
	return latin1_to_string(read_bytes(rel_path))

static func latin1_to_string(b: PackedByteArray) -> String:
	var buf := PackedByteArray()
	buf.resize(b.size() * 4)
	for i in b.size():
		buf[i * 4] = b[i]
	return buf.get_string_from_utf32()

# ---------------------------------------------------------------- resources.xml
static func _parse_resources_xml() -> void:
	var p := find_file("properties/resources.xml")
	if p == "":
		push_error("resources.xml not found")
		return
	var parser := XMLParser.new()
	parser.open(p)
	var def_path := ""
	var def_prefix := ""
	var group := ""
	while parser.read() == OK:
		if parser.get_node_type() != XMLParser.NODE_ELEMENT:
			continue
		var tag := parser.get_node_name()
		var attrs := {}
		for i in parser.get_attribute_count():
			attrs[parser.get_attribute_name(i)] = parser.get_attribute_value(i)
		match tag:
			"Resources":
				group = attrs.get("id", "")
				if not _groups.has(group):
					_groups[group] = []
			"SetDefaults":
				if attrs.has("path"):
					def_path = str(attrs.path).trim_suffix("/").trim_suffix("\\") + "/"
				if attrs.has("idprefix"):
					def_prefix = attrs.idprefix
			"Image":
				var id: String = def_prefix + (attrs.id if attrs.has("id") else str(attrs.path).get_file())
				var d := {
					"path": def_path + attrs.path,
					"rows": int(attrs.get("rows", "1")),
					"cols": int(attrs.get("cols", "1")),
					"alphaimage": (def_path + attrs.alphaimage) if attrs.has("alphaimage") else "",
					"alphagrid": (def_path + attrs.alphagrid) if attrs.has("alphagrid") else "",
					"alphacolor": ("%s" % attrs.alphacolor).hex_to_int() if attrs.has("alphacolor") else 0xFFFFFF,
					"noalpha": attrs.has("noalpha"),
				}
				_image_defs[id] = d
				if group != "":
					_groups[group].append(id)
			"Sound":
				var sid: String = def_prefix + (attrs.id if attrs.has("id") else str(attrs.path).get_file())
				_sound_defs[sid] = {"path": def_path + attrs.path, "volume": float(attrs.get("volume", "-1")), "pan": int(attrs.get("pan", "0"))}
				if group != "":
					_groups[group].append(sid)
			"Font":
				var fid: String = def_prefix + (attrs.id if attrs.has("id") else str(attrs.path).get_file())
				_font_defs[fid] = {"path": def_path + attrs.path}
				if group != "":
					_groups[group].append(fid)

# ---------------------------------------------------------------- images
static func _find_image_file(path_no_ext: String) -> String:
	var key := path_no_ext.replace("\\", "/").to_lower()
	# If an extension was given explicitly, respect it.
	var dot := key.rfind(".")
	if dot > key.rfind("/"):
		var ext := key.substr(dot + 1)
		if ext in IMAGE_EXTS:
			var e: Dictionary = _index.get(key.substr(0, dot), {})
			if e.has(ext):
				return e[ext]
			if ext == "gif" and e.has("png"):
				return e["png"]
			return ""
	var entry: Dictionary = _index.get(key, {})
	for ext in IMAGE_EXTS:
		if entry.has(ext):
			return entry[ext]
	return ""

static func _load_raw_image(file: String) -> Image:
	var tex = load(file)
	if tex is Texture2D:
		var img: Image = tex.get_image()
		if img == null:
			return null
		if img.is_compressed():
			img.decompress()
		return img
	return null

## ImageLib::GetImage(theFilename, lookForAlphaImage)
static func _get_image_data(path_no_ext: String, look_for_alpha: bool, alpha_color: int = 0xFFFFFF) -> Array:
	# returns [Texture2D or null, Image or null (only when composed)]
	var file := _find_image_file(path_no_ext)
	var alpha_file := ""
	if look_for_alpha:
		var slash := path_no_ext.rfind("/")
		var dir := path_no_ext.substr(0, slash + 1)
		var fname := path_no_ext.substr(slash + 1)
		alpha_file = _find_image_file(dir + "_" + fname)
		if alpha_file == "":
			alpha_file = _find_image_file(path_no_ext + "_")
	if alpha_file == "":
		if file == "":
			return [null, null]
		return [load(file), null]
	var mask := _load_raw_image(alpha_file)
	if mask == null:
		return [load(file) if file != "" else null, null]
	mask.convert(Image.FORMAT_RGBA8)
	var md := mask.get_data()
	if file != "":
		var base := _load_raw_image(file)
		if base.get_width() != mask.get_width() or base.get_height() != mask.get_height():
			return [load(file), null]
		base.convert(Image.FORMAT_RGBA8)
		var bd := base.get_data()
		var n := base.get_width() * base.get_height()
		for i in n:
			bd[i * 4 + 3] = md[i * 4 + 2]
		var out := Image.create_from_data(base.get_width(), base.get_height(), false, Image.FORMAT_RGBA8, bd)
		out.fix_alpha_edges()
		return [ImageTexture.create_from_image(out), out]
	var r := (alpha_color >> 16) & 0xFF
	var g := (alpha_color >> 8) & 0xFF
	var b := alpha_color & 0xFF
	var n2 := mask.get_width() * mask.get_height()
	var out2 := PackedByteArray()
	out2.resize(n2 * 4)
	for i in n2:
		out2[i * 4] = r
		out2[i * 4 + 1] = g
		out2[i * 4 + 2] = b
		out2[i * 4 + 3] = md[i * 4 + 2]
	var img2 := Image.create_from_data(mask.get_width(), mask.get_height(), false, Image.FORMAT_RGBA8, out2)
	return [ImageTexture.create_from_image(img2), img2]

## SexyAppBase::GetSharedImage(path) — cached by path; always looks for alpha images.
static func load_image_path(path_no_ext: String, rows: int = 1, cols: int = 1) -> PvzImage:
	var key := path_no_ext.replace("\\", "/").to_lower()
	if _path_images.has(key):
		var cached: PvzImage = _path_images[key]
		return cached
	var data := _get_image_data(path_no_ext.replace("\\", "/"), true)
	if data[0] == null:
		return null
	var img := PvzImage.new(data[0], rows, cols)
	img.path = path_no_ext
	_path_images[key] = img
	return img

static func _apply_alpha_image(img: PvzImage, alpha_path: String, grid: bool) -> void:
	var adata := _get_image_data(alpha_path, true)
	if adata[0] == null:
		return
	var mask: Image = adata[1] if adata[1] != null else (adata[0] as Texture2D).get_image()
	mask.convert(Image.FORMAT_RGBA8)
	var base: Image = img.texture.get_image()
	base.convert(Image.FORMAT_RGBA8)
	var bd := base.get_data()
	var md := mask.get_data()
	var w := base.get_width()
	if not grid:
		if mask.get_width() != w or mask.get_height() != base.get_height():
			return
		for i in w * base.get_height():
			bd[i * 4 + 3] = md[i * 4 + 2]
	else:
		var cw := img.get_cel_width()
		var ch := img.get_cel_height()
		if mask.get_width() != cw or mask.get_height() != ch:
			return
		for row in img.num_rows:
			for col in img.num_cols:
				for y in ch:
					var dst_row := (row * ch + y) * w + col * cw
					var src_row := y * cw
					for x in cw:
						bd[(dst_row + x) * 4 + 3] = md[(src_row + x) * 4 + 2]
	var out := Image.create_from_data(w, base.get_height(), false, Image.FORMAT_RGBA8, bd)
	out.fix_alpha_edges()
	img.set_texture(ImageTexture.create_from_image(out))

## Looks up an image resource by id (e.g. "IMAGE_SEEDBANK", "IMAGE_REANIM_SUN1").
static func get_image(id: String) -> PvzImage:
	if image_override_hook.is_valid():
		var skinned = image_override_hook.call(id)
		if skinned != null:
			return skinned
	if _images.has(id):
		return _images[id]
	var img: PvzImage = null
	var d: Dictionary = _image_defs.get(id, {})
	if not d.is_empty():
		img = _load_def_image(d)
	else:
		img = _definition_load_image(id)
	if img != null:
		img.id = id
	else:
		push_warning("Missing image resource: " + id)
	_images[id] = img
	return img

static func has_image(id: String) -> bool:
	return get_image(id) != null

static func _load_def_image(d: Dictionary) -> PvzImage:
	var look: bool = (d.alphaimage == "" and d.alphagrid == "" and not d.noalpha)
	var data := _get_image_data(str(d.path), look, d.alphacolor)
	if data[0] == null:
		return null
	var img := PvzImage.new(data[0], d.rows, d.cols)
	img.path = d.path
	if d.alphaimage != "":
		_apply_alpha_image(img, d.alphaimage, false)
	if d.alphagrid != "":
		_apply_alpha_image(img, d.alphagrid, true)
	return img

## DefinitionLoadImage fallback path rules for images named inside reanim/particle definitions.
static func _definition_load_image(name: String) -> PvzImage:
	var rules := [["IMAGE_", ""], ["IMAGE_", "particles/"], ["IMAGE_REANIM_", "reanim/"], ["IMAGE_REANIM_", "images/"]]
	for r in rules:
		var prefix: String = r[0]
		if prefix.length() < name.length() and name.begins_with(prefix):
			var p: String = r[1] + name.substr(prefix.length())
			var img := load_image_path(p)
			if img != null:
				return img
	return null

## Creates a private copy of an image with a different grid (Sexy images store rows/cols per instance).
static func image_with_grid(id: String, rows: int, cols: int) -> PvzImage:
	var base := get_image(id)
	return base.duplicate_grid(rows, cols) if base else null

# ---------------------------------------------------------------- fonts
static func get_font(id: String) -> ImageFont:
	if _fonts.has(id):
		return _fonts[id]
	var d: Dictionary = _font_defs.get(id, {})
	if d.is_empty():
		push_warning("Missing font: " + id)
		return null
	var f := ImageFont.new()
	f.load_descriptor(d.path)
	_fonts[id] = f
	return f

# ---------------------------------------------------------------- sounds
static func get_sound(id: String) -> AudioStream:
	if _sounds.has(id):
		return _sounds[id]
	var d: Dictionary = _sound_defs.get(id, {})
	var stream: AudioStream = null
	if not d.is_empty():
		var base := str(d.path).replace("\\", "/").to_lower()
		var entry: Dictionary = _index.get(base, {})
		for ext in ["ogg", "wav", "mp3"]:
			if entry.has(ext):
				stream = load(entry[ext])
				break
	if stream == null:
		push_warning("Missing sound: " + id)
	_sounds[id] = stream
	return stream

static func load_sound_path(path_no_ext: String) -> AudioStream:
	var entry: Dictionary = _index.get(path_no_ext.to_lower(), {})
	for ext in ["ogg", "wav", "mp3"]:
		if entry.has(ext):
			return load(entry[ext])
	return null

# ---------------------------------------------------------------- groups
static func get_group_resources(group: String) -> Array:
	return _groups.get(group, [])

## Loads a resource by id ahead of time (ResourceManager::LoadNextResource).
static func preload_resource(id: String) -> void:
	if _image_defs.has(id):
		get_image(id)
	elif _sound_defs.has(id):
		get_sound(id)
	elif _font_defs.has(id):
		get_font(id)
