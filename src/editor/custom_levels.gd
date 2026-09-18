class_name CustomLevels
## Storage for custom levels. Each level is a folder under user://custom_levels/<id>/ holding
## level.json plus an assets/ subfolder with everything the level skins or reskins.
## Levels export to a single .pvzlvl file (a zip) that can be dropped back in on any machine.

const ROOT := "user://custom_levels"
const EXPORT_DIR := "user://exported_levels"
const LEVEL_FILE := "level.json"
const ASSET_DIR := "assets"
const EXPORT_EXT := "pvzlvl"

## Cached list of {"id", "name", "author", "path", "modified", "waves", "zombies"}.
static var _index: Array = []
static var _index_valid := false

# ================================================================ paths
static func ensure_root() -> void:
	for d in [ROOT, EXPORT_DIR]:
		if not DirAccess.dir_exists_absolute(d):
			DirAccess.make_dir_recursive_absolute(d)

static func level_dir(id: String) -> String:
	return ROOT + "/" + id

static func level_file(id: String) -> String:
	return level_dir(id) + "/" + LEVEL_FILE

static func asset_dir(id: String) -> String:
	return level_dir(id) + "/" + ASSET_DIR

## Absolute path of an asset key inside a level ("assets/foo.png" -> user://.../assets/foo.png).
static func asset_path(id: String, rel: String) -> String:
	if rel == "":
		return ""
	return level_dir(id) + "/" + rel

static func slugify(name: String) -> String:
	var out := ""
	for ch in name.to_lower():
		if (ch >= "a" and ch <= "z") or (ch >= "0" and ch <= "9"):
			out += ch
		elif ch == " " or ch == "-" or ch == "_":
			out += "_"
	out = out.strip_edges().substr(0, 40)
	while out.contains("__"):
		out = out.replace("__", "_")
	out = out.lstrip("_").rstrip("_")
	return out if out != "" else "level"

static func unique_id(base: String) -> String:
	ensure_root()
	var slug := slugify(base)
	var candidate := slug
	var n := 2
	while DirAccess.dir_exists_absolute(level_dir(candidate)):
		candidate = "%s_%d" % [slug, n]
		n += 1
	return candidate

# ================================================================ listing
static func invalidate() -> void:
	_index_valid = false

static func list_levels() -> Array:
	if _index_valid:
		return _index
	ensure_root()
	_index = []
	var d := DirAccess.open(ROOT)
	if d != null:
		for sub in d.get_directories():
			var info := peek(sub)
			if not info.is_empty():
				_index.append(info)
	_index.sort_custom(func(a, b): return int(a.modified) > int(b.modified))
	_index_valid = true
	return _index

## Reads only the header fields of a level, for the browser list.
static func peek(id: String) -> Dictionary:
	var path := level_file(id)
	if not FileAccess.file_exists(path):
		return {}
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return {}
	var parsed = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(parsed) != TYPE_DICTIONARY:
		return {}
	var d: Dictionary = parsed
	var wave_count: int = (d.get("waves", []) as Array).size()
	var zombie_count := 0
	for w in (d.get("waves", []) as Array):
		if typeof(w) == TYPE_DICTIONARY:
			for e in (w.get("entries", []) as Array):
				if typeof(e) == TYPE_DICTIONARY:
					zombie_count += int(e.get("count", 1))
	return {
		"id": id,
		"name": str(d.get("name", id)),
		"author": str(d.get("author", "")),
		"description": str(d.get("description", "")),
		"modified": int(d.get("modified", d.get("created", 0))),
		"waves": wave_count,
		"zombies": zombie_count,
		"custom_plants": (d.get("custom_plants", []) as Array).size(),
		"custom_zombies": (d.get("custom_zombies", []) as Array).size(),
	}

static func exists(id: String) -> bool:
	return FileAccess.file_exists(level_file(id))

# ================================================================ load / save
static func load_level(id: String) -> LevelDef:
	var path := level_file(id)
	if not FileAccess.file_exists(path):
		return null
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return null
	var text := f.get_as_text()
	f.close()
	var l := LevelDef.from_json(text)
	if l != null:
		l.id = id
	return l

static func save_level(level: LevelDef) -> bool:
	ensure_root()
	if level.id == "":
		level.id = unique_id(level.level_name)
	var dir := level_dir(level.id)
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	if not DirAccess.dir_exists_absolute(asset_dir(level.id)):
		DirAccess.make_dir_recursive_absolute(asset_dir(level.id))
	level.modified_unix = int(Time.get_unix_time_from_system())
	var f := FileAccess.open(level_file(level.id), FileAccess.WRITE)
	if f == null:
		push_error("Could not write custom level " + level.id)
		return false
	f.store_string(level.to_json())
	f.close()
	invalidate()
	return true

static func delete_level(id: String) -> bool:
	var dir := level_dir(id)
	if not DirAccess.dir_exists_absolute(dir):
		return false
	_remove_recursive(dir)
	invalidate()
	return true

static func _remove_recursive(path: String) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		DirAccess.remove_absolute(path + "/" + f)
	for sub in d.get_directories():
		_remove_recursive(path + "/" + sub)
	DirAccess.remove_absolute(path)

static func duplicate_level(id: String, new_name: String) -> String:
	var src := load_level(id)
	if src == null:
		return ""
	var copy := src.duplicate_def()
	copy.level_name = new_name
	copy.id = unique_id(new_name)
	copy.created_unix = int(Time.get_unix_time_from_system())
	if not save_level(copy):
		return ""
	_copy_dir(asset_dir(id), asset_dir(copy.id))
	invalidate()
	return copy.id

static func _copy_dir(from: String, to: String) -> void:
	var d := DirAccess.open(from)
	if d == null:
		return
	if not DirAccess.dir_exists_absolute(to):
		DirAccess.make_dir_recursive_absolute(to)
	for f in d.get_files():
		var bytes := FileAccess.get_file_as_bytes(from + "/" + f)
		var out := FileAccess.open(to + "/" + f, FileAccess.WRITE)
		if out != null:
			out.store_buffer(bytes)
			out.close()
	for sub in d.get_directories():
		_copy_dir(from + "/" + sub, to + "/" + sub)

# ================================================================ assets
## Copies [param src_abs] into the level's assets folder and returns its asset key ("assets/x.png"),
## or "" if it could not be read. [param kind] is stored in the level's asset table.
static func import_asset(level: LevelDef, src_abs: String, kind: String) -> String:
	if level.id == "":
		level.id = unique_id(level.level_name)
	var dir := asset_dir(level.id)
	if not DirAccess.dir_exists_absolute(dir):
		DirAccess.make_dir_recursive_absolute(dir)
	var bytes := FileAccess.get_file_as_bytes(src_abs)
	if bytes.is_empty():
		return ""
	var base := src_abs.get_file()
	var stem := base.get_basename()
	var ext := base.get_extension().to_lower()
	var name := "%s.%s" % [slugify(stem), ext]
	var n := 2
	while FileAccess.file_exists(dir + "/" + name):
		name = "%s_%d.%s" % [slugify(stem), n, ext]
		n += 1
	var out := FileAccess.open(dir + "/" + name, FileAccess.WRITE)
	if out == null:
		return ""
	out.store_buffer(bytes)
	out.close()
	var key := ASSET_DIR + "/" + name
	level.assets[key] = {"type": kind, "file": key, "source": base}
	return key

## Imports a reanim plus every sibling image it names, so a dropped-in folder just works.
## Returns the reanim's asset key.
static func import_reanim_folder(level: LevelDef, reanim_abs: String) -> String:
	var key := import_asset(level, reanim_abs, "reanim")
	if key == "":
		return ""
	var src_dir := reanim_abs.get_base_dir()
	for img in _reanim_image_names(reanim_abs):
		var found := _find_sibling_image(src_dir, img)
		if found != "":
			var ikey := import_asset(level, found, "image")
			if ikey != "":
				level.assets[ikey]["reanim_image"] = img
	return key

## Image ids named by <i>...</i> elements in a .reanim file.
static func _reanim_image_names(abs_path: String) -> Array:
	var out: Array = []
	var f := FileAccess.open(abs_path, FileAccess.READ)
	if f == null:
		return out
	var text := f.get_as_text()
	f.close()
	var re := RegEx.new()
	re.compile("<i>\\s*([^<\\s]+)\\s*</i>")
	for m in re.search_all(text):
		var name := m.get_string(1)
		if not out.has(name):
			out.append(name)
	return out

static func _find_sibling_image(dir: String, image_id: String) -> String:
	## "IMAGE_REANIM_ZOMBIE_HEAD" -> look for ZOMBIE_HEAD.png / IMAGE_REANIM_ZOMBIE_HEAD.png / ...
	var stems := [image_id]
	for prefix in ["IMAGE_REANIM_", "IMAGE_"]:
		if image_id.begins_with(prefix):
			stems.append(image_id.substr(prefix.length()))
	var d := DirAccess.open(dir)
	if d == null:
		return ""
	var files := d.get_files()
	for stem in stems:
		for ext in ["png", "PNG", "jpg", "webp", "gif", "tga"]:
			var want := "%s.%s" % [stem, ext]
			for f in files:
				if f.to_lower() == want.to_lower():
					return dir + "/" + f
	return ""

static func remove_asset(level: LevelDef, key: String) -> void:
	level.assets.erase(key)
	var p := asset_path(level.id, key)
	if p != "" and FileAccess.file_exists(p):
		DirAccess.remove_absolute(p)

## Deletes asset files no part of the level points at any more.
static func prune_assets(level: LevelDef) -> int:
	var keep := level.referenced_assets()
	var removed := 0
	for key in level.assets.keys().duplicate():
		if not keep.has(str(key)) and not bool(level.assets[key].get("keep", false)):
			remove_asset(level, str(key))
			removed += 1
	return removed

# ================================================================ import / export
## Writes <EXPORT_DIR>/<id>.pvzlvl and returns the absolute path ("" on failure).
static func export_level(id: String) -> String:
	ensure_root()
	var src := level_dir(id)
	if not DirAccess.dir_exists_absolute(src):
		return ""
	var out_path := "%s/%s.%s" % [EXPORT_DIR, id, EXPORT_EXT]
	var zip := ZIPPacker.new()
	if zip.open(out_path, ZIPPacker.APPEND_CREATE) != OK:
		push_error("Could not create " + out_path)
		return ""
	_zip_dir(zip, src, "")
	zip.close()
	return ProjectSettings.globalize_path(out_path)

static func _zip_dir(zip: ZIPPacker, dir: String, prefix: String) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		var bytes := FileAccess.get_file_as_bytes(dir + "/" + f)
		zip.start_file(prefix + f)
		zip.write_file(bytes)
		zip.close_file()
	for sub in d.get_directories():
		_zip_dir(zip, dir + "/" + sub, prefix + sub + "/")

## Reads a .pvzlvl (or a bare level.json) and installs it as a new level. Returns its id, or "".
static func import_level(abs_path: String) -> String:
	ensure_root()
	if abs_path.get_extension().to_lower() == "json":
		var text := FileAccess.get_file_as_string(abs_path)
		var l := LevelDef.from_json(text)
		if l == null:
			return ""
		l.id = unique_id(l.level_name)
		return l.id if save_level(l) else ""
	var zip := ZIPReader.new()
	if zip.open(abs_path) != OK:
		return ""
	var files := zip.get_files()
	var json_entry := ""
	for f in files:
		if f.get_file() == LEVEL_FILE:
			json_entry = f
			break
	if json_entry == "":
		zip.close()
		return ""
	var root_prefix := json_entry.substr(0, json_entry.length() - LEVEL_FILE.length())
	var level := LevelDef.from_json(zip.read_file(json_entry).get_string_from_utf8())
	if level == null:
		zip.close()
		return ""
	level.id = unique_id(level.level_name)
	var dest := level_dir(level.id)
	DirAccess.make_dir_recursive_absolute(dest)
	for f in files:
		if not f.begins_with(root_prefix) or f.ends_with("/"):
			continue
		var rel := f.substr(root_prefix.length())
		if rel == "" or rel == LEVEL_FILE:
			continue
		var target := dest + "/" + rel
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var out := FileAccess.open(target, FileAccess.WRITE)
		if out != null:
			out.store_buffer(zip.read_file(f))
			out.close()
	zip.close()
	save_level(level)
	return level.id

## Everything importable found in the user's usual drop folders, for the in-game import browser.
static func find_importable() -> Array:
	var out: Array = []
	var seen: Dictionary = {}
	var dirs: Array = [ProjectSettings.globalize_path(EXPORT_DIR),
		OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS),
		OS.get_system_dir(OS.SYSTEM_DIR_DESKTOP),
		OS.get_system_dir(OS.SYSTEM_DIR_DOCUMENTS)]
	for d_any in dirs:
		var dir := str(d_any)
		if dir == "":
			continue
		var d := DirAccess.open(dir)
		if d == null:
			continue
		for f in d.get_files():
			var ext := f.get_extension().to_lower()
			if ext != EXPORT_EXT and not (ext == "json" and f.begins_with("level")):
				continue
			var full := dir + "/" + f
			if seen.has(full):
				continue
			seen[full] = true
			out.append({"name": f, "path": full, "dir": dir})
	return out

## Files under a directory usable as a custom asset, for the in-game asset browser.
static func browse_assets(dir: String) -> Array:
	var out: Array = []
	var d := DirAccess.open(dir)
	if d == null:
		return out
	for sub in d.get_directories():
		if sub.begins_with("."):
			continue
		out.append({"name": sub, "path": dir + "/" + sub, "kind": "dir"})
	for f in d.get_files():
		var ext := f.get_extension().to_lower()
		var kind := ""
		if ext in ["png", "jpg", "jpeg", "webp", "bmp", "tga"]:
			kind = "image"
		elif ext == "reanim":
			kind = "reanim"
		elif ext in ["ogg", "wav", "mp3"]:
			kind = "sound"
		elif ext in [EXPORT_EXT, "json"]:
			kind = "level"
		if kind != "":
			out.append({"name": f, "path": dir + "/" + f, "kind": kind})
	out.sort_custom(func(a, b):
		if a.kind == "dir" and b.kind != "dir":
			return true
		if b.kind == "dir" and a.kind != "dir":
			return false
		return str(a.name).nocasecmp_to(str(b.name)) < 0)
	return out

static func start_browse_dir() -> String:
	var dl := OS.get_system_dir(OS.SYSTEM_DIR_DOWNLOADS)
	return dl if dl != "" else OS.get_user_data_dir()
