extends SceneTree
## Headless check that every compiled reanim/particle decompresses and parses exactly:
## godot --headless --path . -s tools/verify_defs.gd
func _init() -> void:
	Res.init()
	var out := FileAccess.open("user://defs_summary.txt", FileAccess.WRITE)
	var n := 0
	for f in DirAccess.get_files_at("res://compiled/reanim"):
		if not f.ends_with(".compiled"):
			continue
		var d := Defs.load_reanim("reanim/" + f.trim_suffix(".compiled"))
		var frames := 0
		var names := PackedStringArray()
		for t in d.tracks:
			frames += t.frame_count
			names.append(t.name)
		out.store_line("R %s fps=%s tracks=%d frames=%d %s" % [f.to_lower(), d.fps, d.tracks.size(), frames, ",".join(names)])
		n += 1
	for f in DirAccess.get_files_at("res://compiled/particles"):
		if not f.ends_with(".compiled"):
			continue
		if f.to_lower().ends_with(".trail.compiled"):
			var t := Defs.load_trail("particles/" + f.trim_suffix(".compiled"))
			out.store_line("T %s points=%d dist=%s image=%s" % [f.to_lower(), t.max_points, t.min_point_distance, t.image != null])
			n += 1
			continue
		var p := Defs.load_particle("particles/" + f.trim_suffix(".compiled"))
		var names := PackedStringArray()
		for e in p.emitters:
			names.append("%s/%d/%d" % [e.name, e.particle_fields.size(), e.system_fields.size()])
		out.store_line("P %s emitters=%d %s" % [f.to_lower(), p.emitters.size(), ",".join(names)])
		n += 1
	out.close()
	print("parsed %d definitions -> %s" % [n, ProjectSettings.globalize_path("user://defs_summary.txt")])
	quit()
