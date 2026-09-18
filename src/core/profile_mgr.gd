class_name ProfileMgr
extends RefCounted
## Port of ProfileMgr (case-insensitive profile names, most recently used ordering).

var profiles: Dictionary = {}   # lower name -> PlayerInfo
var next_profile_id := 1
var next_profile_use_seq := 1

const USERS_PATH := "user://userdata/users.json"

func clear() -> void:
	profiles.clear()
	next_profile_id = 1
	next_profile_use_seq = 1

func load() -> void:
	if not FileAccess.file_exists(USERS_PATH):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(USERS_PATH))
	if not (parsed is Dictionary):
		clear()
		return
	profiles.clear()
	var max_id := 0
	var max_seq := 0
	for e in parsed.get("profiles", []):
		var p := PlayerInfo.new()
		p.name = e.name
		p.use_seq = int(e.use_seq)
		p.id = int(e.id)
		max_id = maxi(max_id, p.id)
		max_seq = maxi(max_seq, p.use_seq)
		profiles[p.name.to_lower()] = p
	next_profile_id = max_id + 1
	next_profile_use_seq = max_seq + 1

func save() -> void:
	DirAccess.make_dir_recursive_absolute("user://userdata")
	var arr: Array = []
	for k in _sorted_keys():
		var p: PlayerInfo = profiles[k]
		arr.append({"name": p.name, "use_seq": p.use_seq, "id": p.id})
	var f := FileAccess.open(USERS_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"version": 14, "profiles": arr}))

func _sorted_keys() -> Array:
	var keys := profiles.keys()
	keys.sort()
	return keys

func get_profile(name: String) -> PlayerInfo:
	var p: PlayerInfo = profiles.get(name.to_lower())
	if p != null:
		p.load_details()
		p.use_seq = next_profile_use_seq
		next_profile_use_seq += 1
	return p

func get_any_profile() -> PlayerInfo:
	if profiles.is_empty():
		return null
	var p: PlayerInfo = profiles[_sorted_keys()[0]]
	p.load_details()
	p.use_seq = next_profile_use_seq
	next_profile_use_seq += 1
	return p

func add_profile(name: String) -> PlayerInfo:
	if profiles.has(name.to_lower()):
		return null
	var p := PlayerInfo.new()
	p.name = name
	p.id = next_profile_id
	next_profile_id += 1
	p.use_seq = next_profile_use_seq
	next_profile_use_seq += 1
	profiles[name.to_lower()] = p
	while profiles.size() > 200:
		_delete_oldest()
	return p

func delete_profile(name: String) -> bool:
	var p: PlayerInfo = profiles.get(name.to_lower())
	if p == null:
		return false
	p.delete_user_files()
	profiles.erase(name.to_lower())
	return true

func _delete_oldest() -> void:
	var oldest: PlayerInfo = null
	for p in profiles.values():
		if oldest == null or p.use_seq < oldest.use_seq:
			oldest = p
	if oldest:
		delete_profile(oldest.name)

func rename_profile(old_name: String, new_name: String) -> bool:
	var p: PlayerInfo = profiles.get(old_name.to_lower())
	if p == null:
		return false
	if old_name.to_lower() == new_name.to_lower():
		p.name = new_name
		return true
	if profiles.has(new_name.to_lower()):
		return false
	profiles.erase(old_name.to_lower())
	p.name = new_name
	profiles[new_name.to_lower()] = p
	return true

## Names sorted by most recent use first (UserDialog order).
func get_names_by_use() -> Array:
	var list := profiles.values()
	list.sort_custom(func(a, b): return a.use_seq > b.use_seq)
	return list.map(func(p): return p.name)

func num_profiles() -> int:
	return profiles.size()
