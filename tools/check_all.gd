extends Node
## Compile check with autoloads active:
## godot --headless --path . res://tools/check_all.tscn
func _ready() -> void:
	var files: Array = []
	_collect("res://src", files)
	var bad := 0
	for f in files:
		var s = load(f)
		if s == null or (s is GDScript and not s.can_instantiate()):
			bad += 1
			print("FAILED: ", f)
	print("checked %d scripts, %d failed" % [files.size(), bad])
	get_tree().quit()

func _collect(path: String, out: Array) -> void:
	var d := DirAccess.open(path)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(path + "/" + f)
	for sub in d.get_directories():
		_collect(path + "/" + sub, out)
