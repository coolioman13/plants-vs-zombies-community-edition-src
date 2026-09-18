class_name PanelFiles
extends EditorPanel
## The level browser: every custom level on this machine, with new / open / copy / delete and
## import / export so levels can be shared as a single .pvzlvl file.

const L_LEVELS := 1
const B_NEW := 10
const B_OPEN := 11
const B_COPY := 12
const B_DELETE := 13
const B_EXPORT := 14
const B_IMPORT := 15
const B_PLAY := 16
const B_FOLDER := 17
const B_CONFIRM := 18
const B_CANCEL := 19
const F_NEW_NAME := 20

const LIST_W := 420

var list: EditorUi.ScrollList
var entries: Array = []
var selected := 0
var confirming := ""       ## "" | "delete"

func build() -> void:
	entries = CustomLevels.list_levels()
	selected = clampi(selected, 0, maxi(0, entries.size() - 1))
	list = add_list(L_LEVELS, PAD, 44, LIST_W, height - 110, 46)
	list.count = entries.size()
	list.selected = selected
	list.empty_text = "No custom levels yet - press New."
	list.draw_row = Callable(self, "_draw_level_row")
	list.ensure_visible(selected)

	if confirming == "delete":
		add_button_row([[B_CONFIRM, "Yes, delete it"], [B_CANCEL, "Keep it"]],
			PAD, height - 56, PAD + LIST_W, 32)
		return

	add_button_row([[B_NEW, "New"], [B_COPY, "Copy"], [B_DELETE, "Delete"],
		[B_IMPORT, "Import..."]], PAD, height - 56, PAD + LIST_W, 32)

	var rx := PAD * 2 + LIST_W
	var rw := width - rx - PAD
	add_button(B_OPEN, "Open in the editor", rx, height - 132, rw, 32)
	add_button(B_PLAY, "Play it now", rx, height - 96, rw, 32)
	add_button_row([[B_EXPORT, "Export to a file"], [B_FOLDER, "Show folder"]],
		rx, height - 56, width - PAD, 32)

func _selected_entry() -> Dictionary:
	if selected < 0 or selected >= entries.size():
		return {}
	return entries[selected]

# ================================================================ drawing
func _draw_level_row(g: Graphics, index: int, r: Rect2, hovered: bool, sel: bool) -> void:
	if index >= entries.size():
		return
	var e: Dictionary = entries[index]
	EditorUi.draw_slot(g, r, hovered, sel)
	var f := EditorUi.font_body()
	var sf := EditorUi.font_small()
	var open := str(e.id) == level().id
	EditorUi.draw_text(g, EditorUi.elide(str(e.name), f, int(r.size.x - 160)),
		int(r.position.x + 10), int(r.position.y + 18), f,
		EditorUi.TEXT_GOLD if open else EditorUi.TEXT_CREAM)
	var sub := "%d wave%s, %d zombies" % [int(e.waves), "" if int(e.waves) == 1 else "s", int(e.zombies)]
	if int(e.custom_plants) > 0 or int(e.custom_zombies) > 0:
		sub += "  -  %d custom plant%s, %d custom zombie%s" % [
			int(e.custom_plants), "" if int(e.custom_plants) == 1 else "s",
			int(e.custom_zombies), "" if int(e.custom_zombies) == 1 else "s"]
	if str(e.author) != "":
		sub += "  -  by " + str(e.author)
	EditorUi.draw_text(g, EditorUi.elide(sub, sf, int(r.size.x - 20)), int(r.position.x + 10),
		int(r.position.y + 36), sf, EditorUi.TEXT_DIM)
	if open:
		EditorUi.draw_text(g, "open", int(r.end.x - 10), int(r.position.y + 18), sf,
			EditorUi.TEXT_GREEN, TodStrings.DS_ALIGN_RIGHT)

func draw_content(g: Graphics) -> void:
	section(g, "Your levels", PAD, 14, LIST_W)
	var rx := PAD * 2 + LIST_W
	var rw := width - rx - PAD
	var e := _selected_entry()
	if confirming == "delete":
		section(g, "Delete this level?", rx, 14, rw)
		hint(g, "\"%s\" and everything in its folder - art, reanims, music - will be removed for good." %
			str(e.get("name", "")), rx, 48, rw)
		return
	if e.is_empty():
		section(g, "Nothing selected", rx, 14, rw)
		hint(g, "Press New to start a level, or Import to bring in a .pvzlvl someone sent you.", rx, 48, rw)
		return
	section(g, str(e.name), rx, 14, rw)
	var y := 48
	var f := EditorUi.font_body()
	var lines := []
	if str(e.author) != "":
		lines.append("by " + str(e.author))
	lines.append("%d wave%s" % [int(e.waves), "" if int(e.waves) == 1 else "s"])
	lines.append("%d zombies in total" % int(e.zombies))
	if int(e.custom_plants) > 0:
		lines.append("%d custom plant%s" % [int(e.custom_plants), "" if int(e.custom_plants) == 1 else "s"])
	if int(e.custom_zombies) > 0:
		lines.append("%d custom zombie%s" % [int(e.custom_zombies), "" if int(e.custom_zombies) == 1 else "s"])
	if int(e.modified) > 0:
		var d := Time.get_datetime_dict_from_unix_time(int(e.modified))
		lines.append("last saved %04d-%02d-%02d %02d:%02d" % [d.year, d.month, d.day, d.hour, d.minute])
	for line in lines:
		EditorUi.draw_text(g, line, rx, y + f.get_ascent(), f, EditorUi.TEXT_CREAM)
		y += 22
	if str(e.description) != "":
		y += 8
		y += EditorUi.draw_wrapped(g, str(e.description), Rect2i(rx, y, rw, height - y - 150),
			EditorUi.font_small(), EditorUi.TEXT_DIM)

# ================================================================ callbacks
func editor_list_click(id: int, index: int, _mx: int, _btn: int, clicks: int) -> void:
	if id != L_LEVELS:
		return
	selected = index
	if clicks >= 2:
		_open()
	else:
		rebuild()

func button_depress(bid: int) -> void:
	var e := _selected_entry()
	match bid:
		B_NEW:
			screen.save_level(true)
			screen.new_level("Level %d" % (entries.size() + 1))
			entries = CustomLevels.list_levels()
			selected = 0
			rebuild()
		B_OPEN:
			_open()
		B_COPY:
			if e.is_empty():
				return
			screen.save_level(true)
			var id := CustomLevels.duplicate_level(str(e.id), str(e.name) + " copy")
			if id == "":
				toast("Could not copy that level.", EditorUi.TEXT_RED)
				return
			entries = CustomLevels.list_levels()
			for i in entries.size():
				if str(entries[i].id) == id:
					selected = i
			rebuild()
			toast("Copied.")
		B_DELETE:
			if e.is_empty():
				return
			confirming = "delete"
			rebuild()
		B_CONFIRM:
			if not e.is_empty():
				var was_open := str(e.id) == level().id
				CustomLevels.delete_level(str(e.id))
				entries = CustomLevels.list_levels()
				selected = clampi(selected, 0, maxi(0, entries.size() - 1))
				toast("Deleted.")
				confirming = ""
				if was_open:
					if entries.is_empty():
						screen.new_level("My First Level")
					else:
						screen.load_level(str(entries[0].id))
					return
			confirming = ""
			rebuild()
		B_CANCEL:
			confirming = ""
			rebuild()
		B_EXPORT:
			if e.is_empty():
				return
			screen.save_level(true)
			var path := CustomLevels.export_level(str(e.id))
			if path == "":
				toast("Export failed.", EditorUi.TEXT_RED)
			else:
				toast("Exported to %s" % path)
		B_IMPORT:
			_import()
		B_PLAY:
			if e.is_empty():
				return
			screen.save_level(true)
			var l := CustomLevels.load_level(str(e.id))
			if l == null:
				toast("That level could not be read.", EditorUi.TEXT_RED)
				return
			App.play_sample("SOUND_GRAVEBUTTON")
			App.play_custom_level(l, true)
		B_FOLDER:
			if e.is_empty():
				return
			OS.shell_open(ProjectSettings.globalize_path(CustomLevels.level_dir(str(e.id))))

func _open() -> void:
	var e := _selected_entry()
	if e.is_empty() or str(e.id) == level().id:
		return
	screen.save_level(true)
	screen.load_level(str(e.id))

func _import() -> void:
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Import a level", CustomLevels.start_browse_dir(), "", false,
			DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
			PackedStringArray(["*.pvzlvl,*.json;Plants vs. Zombies levels"]),
			Callable(self, "_on_import_chosen"))
		return
	# No native picker: import whatever is sitting in the usual drop folders.
	var found := CustomLevels.find_importable()
	if found.is_empty():
		toast("Put a .pvzlvl in your Downloads folder and try again.", EditorUi.TEXT_RED)
		return
	_do_import(str(found[0].path))

func _on_import_chosen(ok: bool, paths: PackedStringArray, _index: int) -> void:
	if ok and not paths.is_empty():
		_do_import(paths[0])

func _do_import(path: String) -> void:
	var id := CustomLevels.import_level(path)
	if id == "":
		toast("That file is not a level.", EditorUi.TEXT_RED)
		return
	entries = CustomLevels.list_levels()
	for i in entries.size():
		if str(entries[i].id) == id:
			selected = i
	rebuild()
	toast("Imported \"%s\"." % str(CustomLevels.peek(id).get("name", id)))
