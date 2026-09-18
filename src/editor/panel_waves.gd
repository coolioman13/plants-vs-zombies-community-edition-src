class_name PanelWaves
extends EditorPanel
## The wave schedule. Waves down the left, the selected wave's contents on the right, and a picker
## for adding zombies (built-in or this level's own).

const L_WAVES := 1
const L_ENTRIES := 2
const G_PICK := 3
const B_ADD_WAVE := 10
const B_DEL_WAVE := 11
const B_DUP_WAVE := 12
const B_MOVE_UP := 13
const B_MOVE_DOWN := 14
const B_ADD_ZOMBIE := 15
const B_DEL_ENTRY := 16
const B_AUTOFILL := 17
const B_CLOSE_PICK := 18
const S_DELAY := 20
const S_TRIGGER := 21
const S_COUNT := 22
const S_ROW := 23
const T_FLAG := 24
const F_MESSAGE := 25
const F_EVENT := 26

const LIST_W := 208

var wave_list: EditorUi.ScrollList
var entry_list: EditorUi.ScrollList
var pick_grid: EditorUi.IconGrid
var selected_wave := 0
var selected_entry := 0
var picking := false
var pick_entries: Array = []      ## [{"zombie": int, "custom": int, "label": String}]

func build() -> void:
	var l := level()
	selected_wave = clampi(selected_wave, 0, maxi(0, l.waves.size() - 1))
	add_button_row_bottom([[B_ADD_WAVE, "Add"], [B_DUP_WAVE, "Copy"], [B_DEL_WAVE, "Delete"],
		[B_MOVE_UP, "Up"], [B_MOVE_DOWN, "Down"]], PAD, PAD + LIST_W)
	wave_list = add_list(L_WAVES, PAD, 40, LIST_W, bottom_row_y - 50, 30)
	wave_list.count = l.waves.size()
	wave_list.selected = selected_wave
	wave_list.empty_text = "No waves yet."
	wave_list.draw_row = Callable(self, "_draw_wave_row")
	wave_list.ensure_visible(selected_wave)

	if picking:
		_build_picker()
		return
	if l.waves.is_empty():
		return

	var rx := PAD * 2 + LIST_W
	var rw := width - rx - PAD
	var wave: Dictionary = l.waves[selected_wave]
	var y := 40
	add_toggle(T_FLAG, "Flag wave (huge wave banner and siren)", bool(wave.flag), rx, y, rw)
	y += 30
	var d := add_stepper(S_DELAY, "Delay before it", float(wave.delay) / 100.0, 0, 120, 0.5, rx, y, rw, 170)
	d.decimals = 1
	d.suffix = "s (0 = default)"
	y += ROW_H
	var tr := add_stepper(S_TRIGGER, "Release at", float(wave.health_trigger) * 100.0, 0, 100, 5, rx, y, rw, 170)
	tr.suffix = "% of the previous wave left"
	y += ROW_H
	add_field(F_MESSAGE, "On-screen message", str(wave.message), rx, y, rw, 170)
	y += ROW_H
	add_field(F_EVENT, "Broadcast event", str(wave.event), rx, y, rw, 170)
	y += ROW_H + 10

	entries_y = y
	entry_list = add_list(L_ENTRIES, rx, y + 24, rw, height - y - 116, 34)
	entry_list.count = (wave.entries as Array).size()
	entry_list.selected = selected_entry
	entry_list.empty_text = "This wave is empty. Add a zombie."
	entry_list.draw_row = Callable(self, "_draw_entry_row")

	var ey := height - 84
	add_button_row([[B_ADD_ZOMBIE, "Add zombie"], [B_DEL_ENTRY, "Remove"],
		[B_AUTOFILL, "Auto-build waves"]], rx, ey, width - PAD)
	var entries: Array = wave.entries
	if selected_entry >= 0 and selected_entry < entries.size():
		var e: Dictionary = entries[selected_entry]
		add_stepper(S_COUNT, "How many", int(e.count), 1, 40, 1, rx, ey + 36, Tod.idiv(rw, 2) - 6, 100)
		var rows: Array = ["Any lane"]
		for i in BoardCore.MAX_GRID_SIZE_Y:
			rows.append("Lane %d" % (i + 1))
		add_choice(S_ROW, "Lane", int(e.row) + 1, rows, rx + Tod.idiv(rw, 2), ey + 36, Tod.idiv(rw, 2), 60)

var entries_y := 0

func _build_picker() -> void:
	pick_entries = []
	for zt in all_zombie_types():
		pick_entries.append({"zombie": zt, "custom": -1, "label": zombie_name(zt)})
	for cid in CustomDefs.custom_zombie_ids():
		pick_entries.append({"zombie": CustomDefs.zombie_base(cid), "custom": cid,
			"label": CustomDefs.zombie_name(cid)})
	var rx := PAD * 2 + LIST_W
	var rw := width - rx - PAD
	add_button(B_CLOSE_PICK, "Cancel", rx, height - PAD - 28, 0, 28)
	pick_grid = add_grid(G_PICK, rx, 40, rw, height - 110, Vector2i(84, 100))
	pick_grid.count = pick_entries.size()
	pick_grid.draw_cell = Callable(self, "_draw_pick_cell")

# ================================================================ row drawing
func _draw_wave_row(g: Graphics, index: int, r: Rect2, hovered: bool, selected: bool) -> void:
	var l := level()
	EditorUi.draw_slot(g, r, hovered, selected)
	var wave: Dictionary = l.waves[index]
	var f := EditorUi.font_body()
	var flag := l.wave_is_flag(index)
	var col := EditorUi.TEXT_GOLD if flag else EditorUi.TEXT_CREAM
	var n := 0
	for e in wave.entries:
		n += int(e.count)
	EditorUi.draw_text(g, "Wave %d%s" % [index + 1, "  [flag]" if flag else ""],
		int(r.position.x + 8), int(r.position.y + r.size.y * 0.5 + f.get_ascent() * 0.5) - 2, f, col)
	EditorUi.draw_text(g, "%d" % n, int(r.end.x - 8),
		int(r.position.y + r.size.y * 0.5 + f.get_ascent() * 0.5) - 2, EditorUi.font_small(),
		EditorUi.TEXT_DIM, TodStrings.DS_ALIGN_RIGHT)

func _draw_entry_row(g: Graphics, index: int, r: Rect2, hovered: bool, selected: bool) -> void:
	var wave: Dictionary = level().waves[selected_wave]
	var entries: Array = wave.entries
	if index >= entries.size():
		return
	var e: Dictionary = entries[index]
	EditorUi.draw_slot(g, r, hovered, selected)
	var zt := int(e.zombie)
	var cid := int(e.custom)
	EditorUi.draw_zombie_portrait(g, zt, r.position.x + 24, r.position.y + r.size.y + 2, 0.3)
	var f := EditorUi.font_body()
	var name := CustomDefs.zombie_name(cid) if cid >= 0 else zombie_name(zt)
	var tail := "  x%d" % int(e.count)
	if int(e.row) >= 0:
		tail += "   lane %d" % (int(e.row) + 1)
	EditorUi.draw_text(g, name + tail, int(r.position.x + 46),
		int(r.position.y + r.size.y * 0.5 + f.get_ascent() * 0.5) - 2, f,
		EditorUi.TEXT_GREEN if cid >= 0 else EditorUi.TEXT_CREAM)

func _draw_pick_cell(g: Graphics, index: int, r: Rect2, hovered: bool, selected: bool) -> void:
	var e: Dictionary = pick_entries[index]
	EditorUi.draw_slot(g, r, hovered, selected)
	EditorUi.draw_zombie_portrait(g, int(e.zombie), r.position.x + r.size.x * 0.5, r.position.y + r.size.y - 16, 0.34)
	var f := EditorUi.font_small()
	EditorUi.draw_text(g, EditorUi.elide(str(e.label), f, int(r.size.x - 6)),
		int(r.position.x + r.size.x * 0.5), int(r.end.y - 4), f,
		EditorUi.TEXT_GREEN if int(e.custom) >= 0 else EditorUi.TEXT_CREAM, TodStrings.DS_ALIGN_CENTER)

func draw_content(g: Graphics) -> void:
	section(g, "Waves", PAD, 14, LIST_W)
	var rx := PAD * 2 + LIST_W
	var rw := width - rx - PAD
	if picking:
		section(g, "Pick a zombie for wave %d" % (selected_wave + 1), rx, 14, rw)
		return
	if level().waves.is_empty():
		section(g, "No waves", rx, 14, rw)
		hint(g, "Add a wave on the left to start building the level.", rx, 44, rw)
		return
	section(g, "Wave %d of %d" % [selected_wave + 1, level().waves.size()], rx, 14, rw)
	label(g, "Zombies in this wave", rx, entries_y, EditorUi.TEXT_GOLD)

# ================================================================ callbacks
func editor_list_click(id: int, index: int, _mx: int, _btn: int, _clicks: int) -> void:
	if id == L_WAVES:
		selected_wave = index
		selected_entry = 0
		rebuild()
	elif id == L_ENTRIES:
		selected_entry = index
		rebuild()

func editor_grid_click(id: int, index: int, _btn: int) -> void:
	if id != G_PICK or index < 0 or index >= pick_entries.size():
		return
	var e: Dictionary = pick_entries[index]
	var wave: Dictionary = level().waves[selected_wave]
	(wave.entries as Array).append({"zombie": int(e.zombie), "custom": int(e.custom), "count": 1, "row": -1})
	selected_entry = (wave.entries as Array).size() - 1
	picking = false
	mark_dirty()
	rebuild()

func editor_toggle(id: int, value: bool) -> void:
	if id == T_FLAG:
		level().waves[selected_wave].flag = value
		mark_dirty()

func editor_stepper(id: int, value: float) -> void:
	var wave: Dictionary = level().waves[selected_wave]
	match id:
		S_DELAY:
			wave.delay = int(value * 100.0)
		S_TRIGGER:
			wave.health_trigger = value / 100.0
		S_COUNT:
			(wave.entries as Array)[selected_entry].count = int(value)
		S_ROW:
			(wave.entries as Array)[selected_entry].row = int(value) - 1
	mark_dirty()

func update() -> void:
	super.update()
	if level().waves.is_empty():
		return
	var wave: Dictionary = level().waves[selected_wave]
	for c in _controls:
		if c is EditorUi.TextField and c.has_focus:
			var f: EditorUi.TextField = c
			if f.id == F_MESSAGE and str(wave.message) != f.text:
				wave.message = f.text
				mark_dirty()
			elif f.id == F_EVENT and str(wave.event) != f.text:
				wave.event = f.text
				mark_dirty()

func edit_widget_text(_id: int, _text: String) -> void:
	pass

func button_depress(bid: int) -> void:
	var l := level()
	match bid:
		B_ADD_WAVE:
			l.waves.insert(selected_wave + 1 if not l.waves.is_empty() else 0, LevelDef.new_wave())
			selected_wave = mini(selected_wave + 1, l.waves.size() - 1)
			selected_entry = 0
		B_DUP_WAVE:
			if l.waves.is_empty():
				return
			l.waves.insert(selected_wave + 1, (l.waves[selected_wave] as Dictionary).duplicate(true))
			selected_wave += 1
		B_DEL_WAVE:
			if l.waves.size() <= 1:
				toast("A level needs at least one wave.", EditorUi.TEXT_RED)
				return
			l.waves.remove_at(selected_wave)
			selected_wave = clampi(selected_wave, 0, l.waves.size() - 1)
			selected_entry = 0
		B_MOVE_UP:
			if selected_wave > 0:
				var w = l.waves.pop_at(selected_wave)
				selected_wave -= 1
				l.waves.insert(selected_wave, w)
		B_MOVE_DOWN:
			if selected_wave < l.waves.size() - 1:
				var w2 = l.waves.pop_at(selected_wave)
				selected_wave += 1
				l.waves.insert(selected_wave, w2)
		B_ADD_ZOMBIE:
			picking = true
		B_DEL_ENTRY:
			var entries: Array = l.waves[selected_wave].entries
			if selected_entry >= 0 and selected_entry < entries.size():
				entries.remove_at(selected_entry)
				selected_entry = clampi(selected_entry, 0, maxi(0, entries.size() - 1))
		B_AUTOFILL:
			_autofill()
		B_CLOSE_PICK:
			picking = false
	mark_dirty()
	rebuild()

## Fills every wave with a sensible ramp of whatever zombie types the level already mentions,
## so a rough schedule is one click away and can then be edited by hand.
func _autofill() -> void:
	var l := level()
	var palette: Array = []
	for w in l.waves:
		for e in w.entries:
			var key := [int(e.zombie), int(e.custom)]
			if not palette.has(key):
				palette.append(key)
	if palette.is_empty():
		palette = [[PvZ.ZOMBIE_NORMAL, -1]]
	var n := l.waves.size()
	for i in n:
		var wave: Dictionary = l.waves[i]
		var entries: Array = []
		var strength := 1 + Tod.idiv(i * 3, maxi(1, n - 1))
		var variety := 1 + Tod.idiv(i * (palette.size() - 1), maxi(1, n - 1)) if palette.size() > 1 else 1
		for k in mini(variety, palette.size()):
			var pick: Array = palette[k]
			entries.append({"zombie": pick[0], "custom": pick[1],
				"count": maxi(1, strength - k), "row": -1})
		wave.entries = entries
	toast("Waves rebuilt from the zombie types this level already uses.")
