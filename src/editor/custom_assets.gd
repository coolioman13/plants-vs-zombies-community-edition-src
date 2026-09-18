class_name CustomAssets
## Loads a custom level's own art (images, reanims, sounds) from user:// and applies it to the game.
##
## Three layers of reskinning, all scoped to the level that is loaded:
##   * reanim skins  - a whole PvZ.REANIM_* slot is replaced by a custom .reanim file
##   * part skins    - individual tracks inside a reanim get a different image
##   * image skins   - any resources.xml image id is replaced wholesale (backgrounds, UI, packets)
##
## Everything funnels through two engine hooks: Res.get_image() for image ids and
## EffectSystem.alloc_reanimation() for reanims, so no gameplay code needs to know about skins.

static var level: LevelDef = null
static var _images: Dictionary = {}        ## asset key -> PvzImage
static var _reanim_defs: Dictionary = {}   ## asset key -> Defs.ReanimDef
static var _sounds: Dictionary = {}        ## asset key -> AudioStream
## PvZ.REANIM_* -> Defs.ReanimDef replacement.
static var _reanim_by_type: Dictionary = {}
## PvZ.REANIM_* -> {track name (lower) -> PvzImage}.
static var _parts_by_type: Dictionary = {}
## image resource id -> PvzImage.
static var _image_overrides: Dictionary = {}
static var _installed := false

# ================================================================ lifecycle
static func install(l: LevelDef) -> void:
	uninstall()
	level = l
	if l == null:
		return
	_build_image_overrides()
	_build_reanim_skins()
	Res.image_override_hook = Callable(CustomAssets, "image_override")
	_installed = true
	# Cached plant / zombie / mower frames were built from the stock art.
	ReanimatorCache.clear_cache()

static func uninstall() -> void:
	level = null
	_images.clear()
	_reanim_defs.clear()
	_sounds.clear()
	_reanim_by_type.clear()
	_parts_by_type.clear()
	_image_overrides.clear()
	if _installed:
		Res.image_override_hook = Callable()
		ReanimatorCache.clear_cache()
	_installed = false

static func is_active() -> bool:
	return level != null

# ================================================================ raw loading
static func abs_path(key: String) -> String:
	if level == null or key == "":
		return ""
	return CustomLevels.asset_path(level.id, key)

## A custom image by asset key, cached. Returns null when the file is missing or unreadable.
static func get_image(key: String) -> PvzImage:
	if key == "":
		return null
	if _images.has(key):
		return _images[key]
	var img := load_image_file(abs_path(key))
	_images[key] = img
	return img

## Loads any image file from disk into a PvzImage (used by the editor's previews too).
static func load_image_file(path: String) -> PvzImage:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	if img.load(path) != OK:
		push_warning("Custom asset is not a readable image: " + path)
		return null
	if img.is_compressed():
		img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var tex := ImageTexture.create_from_image(img)
	var out := PvzImage.new(tex)
	out.path = path
	return out

static func get_sound(key: String) -> AudioStream:
	if key == "":
		return null
	if _sounds.has(key):
		return _sounds[key]
	var stream := load_sound_file(abs_path(key))
	_sounds[key] = stream
	return stream

static func load_sound_file(path: String) -> AudioStream:
	if path == "" or not FileAccess.file_exists(path):
		return null
	var bytes := FileAccess.get_file_as_bytes(path)
	if bytes.is_empty():
		return null
	match path.get_extension().to_lower():
		"ogg":
			return AudioStreamOggVorbis.load_from_buffer(bytes)
		"mp3":
			var mp3 := AudioStreamMP3.new()
			mp3.data = bytes
			return mp3
		"wav":
			# Godot cannot build an AudioStreamWAV straight from a file buffer, so go through
			# ResourceLoader, which handles .wav imports when one exists.
			if ResourceLoader.exists(path):
				return load(path)
	return null

## A custom reanim definition by asset key. Images named inside it resolve against this level's
## assets first (by asset key, by file name or by reanim image id) and then the base game.
static func get_reanim_def(key: String) -> Defs.ReanimDef:
	if key == "":
		return null
	if _reanim_defs.has(key):
		return _reanim_defs[key]
	var path := abs_path(key)
	var def: Defs.ReanimDef = null
	if path != "" and FileAccess.file_exists(path):
		def = Defs.load_reanim_external(path, Callable(CustomAssets, "resolve_reanim_image"))
	if def == null:
		push_warning("Custom reanim failed to load: " + key)
	_reanim_defs[key] = def
	return def

## Resolver handed to Defs while parsing a custom reanim.
static func resolve_reanim_image(image_id: String) -> PvzImage:
	if image_id == "" or level == null:
		return Res.get_image(image_id) if image_id != "" else null
	var want := image_id.to_lower()
	var stems := [want]
	for prefix in ["image_reanim_", "image_"]:
		if want.begins_with(prefix):
			stems.append(want.substr(prefix.length()))
	for key in level.assets:
		var entry: Dictionary = level.assets[key]
		if str(entry.get("type", "")) != "image":
			continue
		var declared := str(entry.get("reanim_image", "")).to_lower()
		if declared != "" and declared == want:
			return get_image(str(key))
		var file_stem := str(key).get_file().get_basename().to_lower()
		if stems.has(file_stem):
			return get_image(str(key))
	return Res.get_image(image_id)

# ================================================================ skin tables
static func _build_image_overrides() -> void:
	for id in level.image_skins:
		var img := get_image(str(level.image_skins[id]))
		if img != null:
			img.id = str(id)
			_image_overrides[str(id)] = img

static func _build_reanim_skins() -> void:
	for key in level.reanim_skins:
		var rt := int(str(key))
		var def := get_reanim_def(str(level.reanim_skins[key]))
		if def != null:
			_reanim_by_type[rt] = def
	for key in level.part_skins:
		var rt := int(str(key))
		var tracks: Dictionary = level.part_skins[key]
		var built: Dictionary = {}
		for track in tracks:
			var img := get_image(str(tracks[track]))
			if img != null:
				built[str(track).to_lower()] = img
		if not built.is_empty():
			_parts_by_type[rt] = built
	# Custom zombies and the boss can name their own reanim and part skins too.
	for z in level.custom_zombies:
		var rkey := str(z.get("reanim", ""))
		if rkey != "":
			get_reanim_def(rkey)   # warm the cache so spawning never stalls mid-wave

# ================================================================ engine hooks
## Called from Res.get_image() for every image id.
static func image_override(id: String) -> PvzImage:
	return _image_overrides.get(id, null)

## Called from EffectSystem.alloc_reanimation(): the definition a reanim type should use.
static func reanim_def_for(reanim_type: int) -> Defs.ReanimDef:
	if _reanim_by_type.has(reanim_type):
		return _reanim_by_type[reanim_type]
	return ReanimTypes.get_def(reanim_type)

static func has_part_skins(reanim_type: int) -> bool:
	return _parts_by_type.has(reanim_type)

## Applies per-track image overrides to a freshly built reanimation.
static func apply_part_skins(r: Reanimation, reanim_type: int) -> void:
	var tracks: Dictionary = _parts_by_type.get(reanim_type, {})
	for i in r.definition.tracks.size():
		var name: String = (r.definition.tracks[i] as Defs.ReanimTrackDef).name.to_lower()
		if tracks.has(name):
			r.track_instances[i].image_override = tracks[name]

## Applies one custom entity's own part skins (custom zombies/plants), by track name.
static func apply_part_dict(r: Reanimation, part_keys: Dictionary) -> void:
	if r == null or part_keys.is_empty():
		return
	var resolved: Dictionary = {}
	for track in part_keys:
		var img := get_image(str(part_keys[track]))
		if img != null:
			resolved[str(track).to_lower()] = img
	if resolved.is_empty():
		return
	for i in r.definition.tracks.size():
		var name: String = (r.definition.tracks[i] as Defs.ReanimTrackDef).name.to_lower()
		if resolved.has(name):
			r.track_instances[i].image_override = resolved[name]

# ================================================================ editor helpers
## Track names of a reanim type, for the reskin picker.
static func track_names(reanim_type: int) -> Array:
	var def := reanim_def_for(reanim_type)
	var out: Array = []
	if def == null:
		return out
	for t in def.tracks:
		var td: Defs.ReanimTrackDef = t
		if td.name != "" and td.can_draw and not td.name.begins_with("_"):
			out.append(td.name)
	out.sort()
	return out

## The image a track currently shows, so the reskin picker can preview "before" and "after".
static func track_preview_image(reanim_type: int, track: String) -> PvzImage:
	var def := reanim_def_for(reanim_type)
	if def == null:
		return null
	var idx := def.find_track(track)
	if idx < 0:
		return null
	var td: Defs.ReanimTrackDef = def.tracks[idx]
	var skins: Dictionary = _parts_by_type.get(reanim_type, {})
	if skins.has(track.to_lower()):
		return skins[track.to_lower()]
	for img in td.images:
		if img != null:
			return img
	return null

## Reanim slots worth offering in the reskin picker, grouped for the UI.
static func skinnable_reanims() -> Array:
	var out: Array = []
	for i in ReanimTypes.files.size():
		var file: String = ReanimTypes.files[i]
		var label := file.get_file().get_basename()
		var group := "Other"
		var lower := label.to_lower()
		if lower.begins_with("zombie") or lower.contains("zombie"):
			group = "Zombies"
		elif lower.begins_with("credits"):
			continue
		elif lower.begins_with("zengarden"):
			group = "Zen garden"
		elif lower.begins_with("loadbar") or lower.begins_with("selector"):
			group = "Screens"
		out.append({"type": i, "label": label, "group": group, "file": file})
	return out
