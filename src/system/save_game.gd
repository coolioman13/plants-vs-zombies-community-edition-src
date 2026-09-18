class_name SaveGame
extends RefCounted
## Port of SaveGame (LawnSaveGame / LawnLoadGame / FixBoardAfterLoad).
## The decomp dumps the Board's data arrays byte for byte. Here the equivalent object graph
## (board state, plants, zombies, projectiles, coins, mowers, grid items, cursor, seed bank,
## challenge, cut scene and every reanimation / particle / trail / attachment) is walked
## reflectively, object identity is kept through ids, and the result is stored compressed.

const SAVE_FILE_MAGIC_NUMBER := 0xFEEDDEAD
const SAVE_FILE_VERSION := 2

## Board vars that stay as created by the fresh Board (widgets owned by the board).
const BOARD_KEEP := ["menu_button", "fast_button", "store_button", "tool_tip", "ignore_mouse_up"]

static var _script_keys: Dictionary = {}   # Script -> String
static var _key_scripts: Dictionary = {}   # String -> Script

static func get_save_path(mode: int, player_id: int) -> String:
	return "user://userdata/game%d_%d.dat" % [player_id, mode]

static func saved_game_exists(mode: int, player_id: int) -> bool:
	return FileAccess.file_exists(get_save_path(mode, player_id))

static func erase_saved_game(mode: int, player_id: int) -> void:
	var p := get_save_path(mode, player_id)
	if FileAccess.file_exists(p):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(p))

# ================================================================ script registry
static func _build_registry() -> void:
	if not _script_keys.is_empty():
		return
	for script_path in Res.list_scripts("res://src"):
		var s = load(script_path)
		if s is GDScript:
			_register(s, script_path)

static func _register(s: GDScript, key: String) -> void:
	if _script_keys.has(s):
		return
	_script_keys[s] = key
	_key_scripts[key] = s
	var consts := s.get_script_constant_map()
	for k in consts:
		var v = consts[k]
		if v is GDScript and not _script_keys.has(v):
			_register(v, key + "::" + str(k))

# ================================================================ encoding
class Writer:
	var board: Object
	var ids: Dictionary = {}
	var objects: Array = []
	var queue: Array = []

	func encode(v: Variant) -> Variant:
		match typeof(v):
			TYPE_OBJECT:
				return encode_object(v)
			TYPE_ARRAY:
				var out: Array = []
				for e in v:
					out.append(encode(e))
				return out
			TYPE_DICTIONARY:
				var pairs: Array = []
				for k in v:
					pairs.append([encode(k), encode(v[k])])
				return {"$dict": pairs}
			TYPE_RID, TYPE_CALLABLE, TYPE_SIGNAL:
				return {"$skip": true}
		return v

	func encode_object(o: Object) -> Variant:
		if o == null or not is_instance_valid(o):
			return null
		if o == board:
			return {"$board": true}
		if o is PvzImage:
			return {"$img": o.id, "r": o.num_rows, "c": o.num_cols} if o.id != "" else null
		if o is ImageFont:
			for k in Res._fonts:
				if Res._fonts[k] == o:
					return {"$font": k}
			return null
		if o is Defs.ReanimDef:
			return {"$reanimdef": SaveGame._cache_key(Defs._reanim_cache, o)}
		if o is Defs.ParticleDef:
			return {"$particledef": SaveGame._cache_key(Defs._particle_cache, o)}
		if o is Defs.TrailDef:
			return {"$traildef": SaveGame._cache_key(Defs._trail_cache, o)}
		if o is Defs.EmitterDef:
			for k in Defs._particle_cache:
				var idx: int = Defs._particle_cache[k].emitters.find(o)
				if idx >= 0:
					return {"$emitterdef": k, "i": idx}
			return null
		if o is Defs.ReanimTrackDef:
			for k in Defs._reanim_cache:
				var idx: int = Defs._reanim_cache[k].tracks.find(o)
				if idx >= 0:
					return {"$trackdef": k, "i": idx}
			return null
		if o is Node or o is Resource or o is Widget:
			return {"$skip": true}
		var s = o.get_script()
		if s == null or not SaveGame._script_keys.has(s):
			return {"$skip": true}
		if ids.has(o):
			return {"$ref": ids[o]}
		var id := objects.size()
		ids[o] = id
		objects.append(null)
		queue.append(o)
		return {"$ref": id}

	func flush() -> void:
		while not queue.is_empty():
			var o: Object = queue.pop_back()
			objects[ids[o]] = {"s": SaveGame._script_keys[o.get_script()], "p": props(o, [])}

	func props(o: Object, exclude: Array) -> Dictionary:
		var out := {}
		for p in o.get_property_list():
			if not (p.usage & PROPERTY_USAGE_SCRIPT_VARIABLE):
				continue
			var n: String = p.name
			if n in exclude:
				continue
			out[n] = encode(o.get(n))
		return out

static func _cache_key(cache: Dictionary, o: Object) -> String:
	for k in cache:
		if cache[k] == o:
			return k
	return ""

# ================================================================ decoding
class Reader:
	var board: Object
	var data: Array
	var objects: Array = []

	func create_all() -> bool:
		objects.resize(data.size())
		for i in data.size():
			var s: GDScript = SaveGame._key_scripts.get(data[i].s)
			if s == null:
				push_error("SaveGame: unknown script " + str(data[i].s))
				return false
			objects[i] = s.new()
		for i in data.size():
			apply(objects[i], data[i].p)
		return true

	func apply(o: Object, props: Dictionary) -> void:
		for n in props:
			var raw = props[n]
			if raw is Dictionary and raw.has("$skip"):
				continue
			var v = decode(raw)
			var cur = o.get(n)
			if cur is Array and v is Array and cur.is_typed():
				cur.clear()
				cur.assign(v)
			elif cur is Dictionary and v is Dictionary and cur.is_typed():
				cur.clear()
				cur.assign(v)
			else:
				o.set(n, v)

	func decode(v: Variant) -> Variant:
		if v is Array:
			var out: Array = []
			for e in v:
				out.append(decode(e))
			return out
		if not (v is Dictionary):
			return v
		if v.has("$ref"):
			return objects[v["$ref"]]
		if v.has("$board"):
			return board
		if v.has("$dict"):
			var d := {}
			for pair in v["$dict"]:
				d[decode(pair[0])] = decode(pair[1])
			return d
		if v.has("$img"):
			var img := Res.get_image(v["$img"])
			if img and (img.num_rows != v.r or img.num_cols != v.c):
				img = Res.image_with_grid(v["$img"], v.r, v.c)
			return img
		if v.has("$font"):
			return Res.get_font(v["$font"])
		if v.has("$reanimdef"):
			return Defs.load_reanim(v["$reanimdef"])
		if v.has("$particledef"):
			return Defs.load_particle(v["$particledef"])
		if v.has("$traildef"):
			return Defs.load_trail(v["$traildef"])
		if v.has("$emitterdef"):
			return Defs.load_particle(v["$emitterdef"]).emitters[v.i]
		if v.has("$trackdef"):
			return Defs.load_reanim(v["$trackdef"]).tracks[v.i]
		if v.has("$skip"):
			return null
		return v

# ================================================================ board sync
static func _board_exclude() -> Array:
	var ex: Array = BOARD_KEEP.duplicate()
	for p in (load("res://src/widget/widget.gd") as GDScript).get_script_property_list():
		ex.append(p.name)
	return ex

## The board graph as a Variant (also used by the multiplayer resync).
static func build_snapshot(board: Board) -> Dictionary:
	_build_registry()
	var w := Writer.new()
	w.board = board
	var root := {
		"magic": SAVE_FILE_MAGIC_NUMBER,
		"version": SAVE_FILE_VERSION,
		"board": w.props(board, _board_exclude()),
		"particle_systems": w.encode(EffectSystem.particle_systems),
		"trails": w.encode(EffectSystem.trails),
		"reanimations": w.encode(EffectSystem.reanimations),
		"attachments": w.encode(EffectSystem.attachments),
		"music_tune": App.music.cur_music_tune,
		"music_burst_override": App.music.burst_override,
	}
	w.flush()
	root["objects"] = w.objects
	return root

## Applies a snapshot from build_snapshot to a freshly made board. Scene/music handling stays with the caller.
static func apply_snapshot(board: Board, root: Variant) -> bool:
	_build_registry()
	if not (root is Dictionary) or root.get("magic", 0) != SAVE_FILE_MAGIC_NUMBER or root.get("version", 0) != SAVE_FILE_VERSION:
		return false
	var r := Reader.new()
	r.board = board
	r.data = root.objects
	if not r.create_all():
		return false
	r.apply(board, root.board)
	EffectSystem.particle_systems = r.decode(root.particle_systems)
	EffectSystem.trails = r.decode(root.trails)
	EffectSystem.reanimations = r.decode(root.reanimations)
	EffectSystem.attachments = r.decode(root.attachments)
	for re in EffectSystem.reanimations:
		re._attach_gen = -1  # the attachment generation counter isn't saved; make every reanim rescan
	board._mc_cache_version = -1  # same for the mind control counter
	return true

static func snapshot_to_bytes(board: Board) -> PackedByteArray:
	var raw := var_to_bytes(build_snapshot(board))
	var packed := raw.compress(FileAccess.COMPRESSION_ZSTD)
	var out := PackedByteArray()
	out.resize(4)
	out.encode_u32(0, raw.size())
	out.append_array(packed)
	return out

static func snapshot_from_bytes(bytes: PackedByteArray) -> Variant:
	if bytes.size() < 4:
		return null
	var raw := bytes.slice(4).decompress(bytes.decode_u32(0), FileAccess.COMPRESSION_ZSTD)
	return bytes_to_var(raw)

## LawnSaveGame
static func save_game(board: Board, mode: int, player_id: int) -> bool:
	var root := build_snapshot(board)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://userdata"))
	var f := FileAccess.open_compressed(get_save_path(mode, player_id), FileAccess.WRITE, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return false
	f.store_var(root, false)
	f.close()
	return true

## LawnLoadGame + FixBoardAfterLoad
static func load_game(board: Board, mode: int, player_id: int) -> bool:
	var f := FileAccess.open_compressed(get_save_path(mode, player_id), FileAccess.READ, FileAccess.COMPRESSION_ZSTD)
	if f == null:
		return false
	var root = f.get_var(false)
	f.close()
	if not apply_snapshot(board, root):
		return false
	App.game_scene = PvZ.SCENE_PLAYING
	board.fast_button.btn_no_draw = false  # Board::LoadGame
	App.music.burst_override = root.get("music_burst_override", -1)
	var tune: int = root.get("music_tune", PvZ.MUSIC_TUNE_NONE)
	if tune != PvZ.MUSIC_TUNE_NONE:
		App.music.make_sure_music_is_playing(tune)
	return true
