class_name PanelSeeds
extends EditorPanel
## What the player gets to plant: the seed chooser and its allow-list, a fixed bank, a conveyor
## belt, or nothing at all.

const S_MODE := 1
const S_NUM_CHOOSE := 2
const S_CONVEYOR_SPEED := 3
const G_ALL := 4
const L_PICKED := 5
const B_ALL_ON := 10
const B_ALL_OFF := 11
const B_CLEAR := 12
const B_UP := 13
const B_DOWN := 14
const B_REMOVE := 15
const S_WEIGHT := 16
const S_MAX := 17

const GRID_W := 470

var grid: EditorUi.IconGrid
var picked_list: EditorUi.ScrollList
var seed_list: Array = []
var selected_slot := 0

func build() -> void:
	var l := level()
	seed_list = all_seed_types()
	add_choice(S_MODE, "Seed bank", l.seed_mode, LevelDef.SEEDS_NAMES, PAD, 40, 380, 110)
	if l.seed_mode == LevelDef.SEEDS_CHOOSER:
		add_stepper(S_NUM_CHOOSE, "Slots to pick", l.num_choose, 1, PvZ.SEEDBANK_MAX, 1, PAD + 396, 40, 300, 130)
	elif l.seed_mode == LevelDef.SEEDS_CONVEYOR:
		add_stepper(S_CONVEYOR_SPEED, "Belt speed", l.conveyor_speed, 1, 16, 1, PAD + 396, 40, 300, 130).suffix = "x"

	if l.seed_mode == LevelDef.SEEDS_NONE:
		return

	grid = add_grid(G_ALL, PAD, 106, GRID_W, height - 168, Vector2i(54, 72))
	grid.count = seed_list.size()
	grid.draw_cell = Callable(self, "_draw_seed_cell")

	add_button_row([[B_ALL_ON, "Allow all"], [B_ALL_OFF, "Allow none"], [B_CLEAR, "Reset"]],
		PAD, height - 46, PAD + GRID_W)

	var rx := PAD * 2 + GRID_W
	var rw := width - rx - PAD
	picked_list = add_list(L_PICKED, rx, 132, rw, height - 222, 32)
	picked_list.count = _slots().size()
	picked_list.selected = selected_slot
	picked_list.empty_text = _empty_text()
	picked_list.draw_row = Callable(self, "_draw_slot_row")

	if l.seed_mode != LevelDef.SEEDS_CHOOSER:
		add_button_row([[B_UP, "Up"], [B_DOWN, "Down"], [B_REMOVE, "Remove"]],
			rx, height - 80, width - PAD)
	if l.seed_mode == LevelDef.SEEDS_CONVEYOR and selected_slot < l.conveyor_seeds.size():
		var e: Dictionary = l.conveyor_seeds[selected_slot]
		var half := Tod.idiv(rw - 10, 2)
		add_stepper(S_WEIGHT, "Chance", int(e.get("weight", 100)), 0, 1000, 10, rx, height - 46, half, 100)
		add_stepper(S_MAX, "Max at once", int(e.get("max", 0)), 0, PvZ.SEEDBANK_MAX, 1,
			rx + half + 10, height - 46, half, 120).zero_text = "no limit"

func _slots() -> Array:
	var l := level()
	match l.seed_mode:
		LevelDef.SEEDS_PRESET: return l.preset_seeds
		LevelDef.SEEDS_CONVEYOR: return l.conveyor_seeds
		LevelDef.SEEDS_CHOOSER: return l.allowed_seeds
	return []

func _empty_text() -> String:
	match level().seed_mode:
		LevelDef.SEEDS_PRESET: return "Click plants on the left to fill the bank."
		LevelDef.SEEDS_CONVEYOR: return "Click plants on the left to put them on the belt."
	return "Every plant the player owns is allowed."

func _is_allowed(st: int) -> bool:
	var l := level()
	match l.seed_mode:
		LevelDef.SEEDS_CHOOSER:
			return l.allowed_seeds.is_empty() or l.allowed_seeds.has(st)
		LevelDef.SEEDS_PRESET:
			return l.preset_seeds.has(st)
		LevelDef.SEEDS_CONVEYOR:
			for e in l.conveyor_seeds:
				if int(e.get("seed", -1)) == st:
					return true
	return false

# ================================================================ drawing
func _draw_seed_cell(g: Graphics, index: int, r: Rect2, hovered: bool, _selected: bool) -> void:
	var st: int = seed_list[index]
	var on := _is_allowed(st)
	EditorUi.draw_slot(g, r, hovered, on)
	EditorUi.draw_seed_packet(g, st, r.position.x + 2, r.position.y + 2, (r.size.x - 4) / 50.0, not on)
	if CustomDefs.is_custom_plant(st):
		g.color = EditorUi.TEXT_GREEN
		g.fill_rect(r.position.x + 2, r.position.y + 2, 6, 6)

func _draw_slot_row(g: Graphics, index: int, r: Rect2, hovered: bool, selected: bool) -> void:
	var l := level()
	var slots := _slots()
	if index >= slots.size():
		return
	EditorUi.draw_slot(g, r, hovered, selected)
	var st: int
	var extra := ""
	if l.seed_mode == LevelDef.SEEDS_CONVEYOR:
		var e: Dictionary = slots[index]
		st = int(e.get("seed", PvZ.SEED_PEASHOOTER))
		extra = "   chance %d" % int(e.get("weight", 100))
	else:
		st = int(slots[index])
	EditorUi.draw_seed_packet(g, st, r.position.x + 4, r.position.y + 1, 0.4)
	var f := EditorUi.font_body()
	EditorUi.draw_text(g, "%d. %s%s" % [index + 1, seed_name(st), extra], int(r.position.x + 30),
		int(r.position.y + r.size.y * 0.5 + f.get_ascent() * 0.5) - 2, f, EditorUi.TEXT_CREAM)

func draw_content(g: Graphics) -> void:
	var l := level()
	section(g, "Seed bank", PAD, 14, width - PAD * 2)
	if l.seed_mode == LevelDef.SEEDS_NONE:
		hint(g, "The player gets no seed bank at all. Useful for puzzle levels where everything is " + "placed by the level or handed out by a script.", PAD, 82, width - PAD * 2)
		return
	var title := "Plants the chooser offers"
	if l.seed_mode == LevelDef.SEEDS_PRESET:
		title = "Plants to put in the bank"
	elif l.seed_mode == LevelDef.SEEDS_CONVEYOR:
		title = "Plants to put on the belt"
	section(g, title, PAD, 82, GRID_W)
	var rx := PAD * 2 + GRID_W
	var rw := width - rx - PAD
	match l.seed_mode:
		LevelDef.SEEDS_CHOOSER:
			section(g, "Allowed (empty = all)", rx, 82, rw)
			hint(g, "Leave this empty and the chooser behaves exactly like the base game: every plant " + "the profile owns, plus any plant this level defines.", rx, 106, rw)
		LevelDef.SEEDS_PRESET:
			section(g, "Bank, in order", rx, 82, rw)
			hint(g, "These packets are handed to the player with no chooser screen.", rx, 106, rw)
		LevelDef.SEEDS_CONVEYOR:
			section(g, "Belt contents", rx, 82, rw)
			hint(g, "Packets arrive on a conveyor instead of costing sun, so no sun falls whatever the " + "Level tab says. Chance weights how often each one comes, and Max at once stops the belt " + "handing out more of it than that. Leave the list empty and the belt offers everything " + "the level allows.",
				rx, 106, rw)

# ================================================================ callbacks
func editor_stepper(id: int, value: float) -> void:
	var l := level()
	match id:
		S_MODE:
			l.seed_mode = int(value)
			mark_dirty()
			rebuild()
			return
		S_NUM_CHOOSE: l.num_choose = int(value)
		S_CONVEYOR_SPEED: l.conveyor_speed = int(value)
		S_WEIGHT:
			if selected_slot < l.conveyor_seeds.size():
				l.conveyor_seeds[selected_slot]["weight"] = int(value)
		S_MAX:
			if selected_slot < l.conveyor_seeds.size():
				l.conveyor_seeds[selected_slot]["max"] = int(value)
	mark_dirty()

func editor_grid_click(id: int, index: int, _btn: int) -> void:
	if id != G_ALL or index < 0 or index >= seed_list.size():
		return
	var st: int = seed_list[index]
	var l := level()
	match l.seed_mode:
		LevelDef.SEEDS_CHOOSER:
			if l.allowed_seeds.is_empty():
				# "all allowed" turning into an explicit list starts from everything but this one
				l.allowed_seeds = seed_list.duplicate()
			if l.allowed_seeds.has(st):
				l.allowed_seeds.erase(st)
			else:
				l.allowed_seeds.append(st)
			if l.allowed_seeds.size() == seed_list.size():
				l.allowed_seeds.clear()
		LevelDef.SEEDS_PRESET:
			if l.preset_seeds.has(st):
				l.preset_seeds.erase(st)
			elif l.preset_seeds.size() < PvZ.SEEDBANK_MAX:
				l.preset_seeds.append(st)
			else:
				toast("The bank holds at most %d packets." % PvZ.SEEDBANK_MAX, EditorUi.TEXT_RED)
		LevelDef.SEEDS_CONVEYOR:
			var found := -1
			for i in l.conveyor_seeds.size():
				if int(l.conveyor_seeds[i].get("seed", -1)) == st:
					found = i
					break
			if found >= 0:
				l.conveyor_seeds.remove_at(found)
			else:
				l.conveyor_seeds.append({"seed": st, "weight": 100, "max": 0})
	mark_dirty()
	rebuild()

func editor_list_click(id: int, index: int, _mx: int, _btn: int, _clicks: int) -> void:
	if id == L_PICKED:
		selected_slot = index
		rebuild()

func button_depress(bid: int) -> void:
	var l := level()
	var slots := _slots()
	match bid:
		B_ALL_ON:
			match l.seed_mode:
				LevelDef.SEEDS_CHOOSER: l.allowed_seeds.clear()
				LevelDef.SEEDS_PRESET:
					l.preset_seeds = seed_list.slice(0, PvZ.SEEDBANK_MAX)
				LevelDef.SEEDS_CONVEYOR:
					l.conveyor_seeds.clear()
					for st in seed_list:
						l.conveyor_seeds.append({"seed": st, "weight": 100, "max": 0})
		B_ALL_OFF:
			match l.seed_mode:
				LevelDef.SEEDS_CHOOSER: l.allowed_seeds = [PvZ.SEED_PEASHOOTER]
				LevelDef.SEEDS_PRESET: l.preset_seeds.clear()
				LevelDef.SEEDS_CONVEYOR: l.conveyor_seeds.clear()
		B_CLEAR:
			l.allowed_seeds.clear()
			l.preset_seeds = [PvZ.SEED_PEASHOOTER, PvZ.SEED_SUNFLOWER, PvZ.SEED_CHERRYBOMB,
				PvZ.SEED_WALLNUT, PvZ.SEED_POTATOMINE, PvZ.SEED_SNOWPEA]
			l.conveyor_seeds.clear()
		B_UP:
			if selected_slot > 0 and selected_slot < slots.size():
				var v = slots.pop_at(selected_slot)
				selected_slot -= 1
				slots.insert(selected_slot, v)
		B_DOWN:
			if selected_slot >= 0 and selected_slot < slots.size() - 1:
				var v2 = slots.pop_at(selected_slot)
				selected_slot += 1
				slots.insert(selected_slot, v2)
		B_REMOVE:
			if selected_slot >= 0 and selected_slot < slots.size():
				slots.remove_at(selected_slot)
				selected_slot = clampi(selected_slot, 0, maxi(0, slots.size() - 1))
	mark_dirty()
	rebuild()
