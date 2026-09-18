class_name PanelPlants
extends EditorPanel
## Custom plant maker. A custom plant picks a behaviour template (what it actually does on the
## lawn), then overrides cost, recharge, health, damage, fire rate, art and colour. It becomes a
## real seed type for this level, so it shows up in the chooser, the seed bank and the almanac
## exactly like a built-in plant.

const L_PLANTS := 1
const B_ADD := 10
const B_DELETE := 11
const B_DUPLICATE := 12
const B_PICK_REANIM := 13
const B_CLEAR_REANIM := 14
const F_NAME := 20
const F_DESC := 21
const S_BASE := 22
const S_COST := 23
const S_RECHARGE := 24
const S_HEALTH := 25
const S_DAMAGE := 26
const S_RATE := 27
const S_SCALE := 28
const S_TINT_R := 29
const S_TINT_G := 30
const S_TINT_B := 31
const S_PACKET := 32
const S_REANIM := 33

const LIST_W := 230

var plant_list: EditorUi.ScrollList
var selected := 0
var reanim_keys: Array = []
var preview_plant: Reanimation = null
var preview_seed := PvZ.SEED_NONE

func current() -> Dictionary:
	var l := level()
	if selected < 0 or selected >= l.custom_plants.size():
		return {}
	return l.custom_plants[selected]

func build() -> void:
	var l := level()
	selected = clampi(selected, 0, maxi(0, l.custom_plants.size() - 1))
	add_button_row_bottom([[B_ADD, "New plant"], [B_DUPLICATE, "Copy"], [B_DELETE, "Delete"]],
		PAD, PAD + LIST_W)
	plant_list = add_list(L_PLANTS, PAD, 40, LIST_W, bottom_row_y - 50, 34)
	plant_list.count = l.custom_plants.size()
	plant_list.selected = selected
	plant_list.empty_text = "No custom plants yet."
	plant_list.draw_row = Callable(self, "_draw_plant_row")

	var p := current()
	if p.is_empty():
		return
	var rx := PAD * 2 + LIST_W
	var rw := width - rx - PAD
	var col_w := Tod.idiv(rw - 200, 1)
	var y := 40
	add_field(F_NAME, "Name", str(p.get("name", "")), rx, y, col_w, 120)
	y += ROW_H
	add_field(F_DESC, "Almanac text", str(p.get("description", "")), rx, y, col_w, 120)
	y += ROW_H
	var bases: Array = []
	var base_index := 0
	for i in CustomDefs.PLANT_TEMPLATES.size():
		bases.append(str(CustomDefs.PLANT_TEMPLATES[i].label))
		if int(CustomDefs.PLANT_TEMPLATES[i].base) == int(p.get("base", PvZ.SEED_PEASHOOTER)):
			base_index = i
	add_choice(S_BASE, "Behaves like", base_index, bases, rx, y, col_w, 120)
	y += ROW_H + 8

	stats_y = y
	y += 24
	add_stepper(S_COST, "Sun cost", int(p.get("cost", 100)), 0, 9990, 25, rx, y, col_w, 120)
	y += ROW_H
	var rc := add_stepper(S_RECHARGE, "Recharge", float(p.get("recharge", 750)) / 100.0, 0.5, 60.0, 0.5, rx, y, col_w, 120)
	rc.decimals = 1
	rc.suffix = "s"
	y += ROW_H
	add_stepper(S_HEALTH, "Health", int(p.get("health", 300)), 10, 20000, 50, rx, y, col_w, 120)
	y += ROW_H
	add_stepper(S_DAMAGE, "Damage per shot", int(p.get("damage", 20)), 0, 2000, 5, rx, y, col_w, 120)
	y += ROW_H
	var fr := add_stepper(S_RATE, "Shoots every", float(p.get("fire_rate", 150)) / 100.0, 0.1, 30.0, 0.1, rx, y, col_w, 120)
	fr.decimals = 1
	fr.suffix = "s"
	y += ROW_H + 8

	look_y = y
	y += 24
	reanim_keys = _reanim_asset_keys()
	var names: Array = ["(use the base plant's art)"]
	for k in reanim_keys:
		names.append(str(k).get_file())
	add_choice(S_REANIM, "Animation", reanim_keys.find(str(p.get("reanim", ""))) + 1, names, rx, y, col_w, 120)
	y += ROW_H
	var sc := add_stepper(S_SCALE, "Size", float(p.get("scale", 1.0)), 0.3, 3.0, 0.05, rx, y, col_w, 120)
	sc.decimals = 2
	sc.suffix = " x"
	y += ROW_H
	var tint: Array = p.get("tint", [255, 255, 255])
	add_stepper(S_TINT_R, "Colour: red", int(tint[0]), 0, 255, 5, rx, y, col_w, 120)
	y += ROW_H
	add_stepper(S_TINT_G, "Colour: green", int(tint[1]), 0, 255, 5, rx, y, col_w, 120)
	y += ROW_H
	add_stepper(S_TINT_B, "Colour: blue", int(tint[2]), 0, 255, 5, rx, y, col_w, 120)
	y += ROW_H
	add_stepper(S_PACKET, "Packet frame", int(p.get("packet_bg", -1)), -1, 40, 1, rx, y, col_w, 120)

var stats_y := 0
var look_y := 0

func teardown() -> void:
	_kill_preview()
	super.teardown()

func _kill_preview() -> void:
	if preview_plant != null and not preview_plant.freed:
		preview_plant.die()
	preview_plant = null
	preview_seed = PvZ.SEED_NONE

func _reanim_asset_keys() -> Array:
	var out: Array = []
	for k in level().assets:
		if str(level().assets[k].get("type", "")) == "reanim":
			out.append(str(k))
	out.sort()
	return out

# ================================================================ drawing
func _draw_plant_row(g: Graphics, index: int, r: Rect2, hovered: bool, sel: bool) -> void:
	var l := level()
	if index >= l.custom_plants.size():
		return
	EditorUi.draw_slot(g, r, hovered, sel)
	var p: Dictionary = l.custom_plants[index]
	var st := CustomDefs.seed_type_for_cid(int(p.get("cid", -1)))
	if st != PvZ.SEED_NONE:
		EditorUi.draw_seed_packet(g, st, r.position.x + 3, r.position.y + 2, 0.42)
	var f := EditorUi.font_body()
	EditorUi.draw_text(g, EditorUi.elide(str(p.get("name", "")), f, int(r.size.x - 40)),
		int(r.position.x + 30), int(r.position.y + r.size.y * 0.5 + f.get_ascent() * 0.5) - 2, f,
		EditorUi.TEXT_CREAM)

func draw_content(g: Graphics) -> void:
	section(g, "Custom plants", PAD, 14, LIST_W)
	var rx := PAD * 2 + LIST_W
	var rw := width - rx - PAD
	if current().is_empty():
		section(g, "Plant maker", rx, 14, rw)
		hint(g, "Make a plant, choose what it behaves like, then change everything else about it: " + "what it costs, how tough it is, how hard it hits, how often it fires, what animation it " + "uses and what colour it is.\n\nCustom plants are part of this level only. They appear in " + "the seed chooser, can be dropped straight onto the lawn from the Lawn tab, and can be " + "handed out by scripts.", rx, 48, rw)
		return
	section(g, "Identity and behaviour", rx, 14, rw)
	section(g, "Numbers", rx, stats_y, rw - 210)
	section(g, "Looks", rx, look_y, rw - 210)
	_draw_preview(g, rx + rw - 200, stats_y)

func _draw_preview(g: Graphics, px: int, py: int) -> void:
	var p := current()
	var st := CustomDefs.seed_type_for_cid(int(p.get("cid", -1)))
	var box := Rect2(px, py, 190, height - py - 30)
	EditorUi.draw_shade(g, box, 0.3)
	if st == PvZ.SEED_NONE:
		EditorUi.draw_text(g, "Save to preview", int(px + 95), int(py + 60), EditorUi.font_small(),
			EditorUi.TEXT_DIM, TodStrings.DS_ALIGN_CENTER)
		return
	EditorUi.draw_seed_packet(g, st, px + 62, py + 12, 1.3)
	var cg := g.copy()
	cg.clip_rect(box.position.x, box.position.y + 120, box.size.x, box.size.y - 130)
	var tint: Array = p.get("tint", [255, 255, 255])
	EditorUi.draw_plant_portrait(cg, st, px + 95, py + 260, 1.0,
		Color8(int(tint[0]), int(tint[1]), int(tint[2])))
	var base := int(p.get("base", PvZ.SEED_PEASHOOTER))
	EditorUi.draw_text(g, "acts like " + seed_name(base), int(px + 95), int(box.end.y - 8),
		EditorUi.font_small(), EditorUi.TEXT_DIM, TodStrings.DS_ALIGN_CENTER)

func update() -> void:
	super.update()
	var p := current()
	if p.is_empty():
		return
	for c in _controls:
		if c is EditorUi.TextField and c.has_focus:
			var f: EditorUi.TextField = c
			if f.id == F_NAME and str(p.get("name", "")) != f.text:
				p["name"] = f.text
				mark_dirty()
			elif f.id == F_DESC and str(p.get("description", "")) != f.text:
				p["description"] = f.text
				mark_dirty()

# ================================================================ callbacks
func editor_list_click(id: int, index: int, _mx: int, _btn: int, _clicks: int) -> void:
	if id == L_PLANTS:
		selected = index
		_kill_preview()
		rebuild()

func editor_stepper(id: int, value: float) -> void:
	var p := current()
	if p.is_empty():
		return
	var tint: Array = p.get("tint", [255, 255, 255])
	match id:
		S_BASE:
			p["base"] = int(CustomDefs.PLANT_TEMPLATES[clampi(int(value), 0, CustomDefs.PLANT_TEMPLATES.size() - 1)].base)
		S_COST: p["cost"] = int(value)
		S_RECHARGE: p["recharge"] = int(value * 100.0)
		S_HEALTH: p["health"] = int(value)
		S_DAMAGE: p["damage"] = int(value)
		S_RATE: p["fire_rate"] = int(value * 100.0)
		S_SCALE: p["scale"] = value
		S_PACKET: p["packet_bg"] = int(value)
		S_TINT_R: tint[0] = int(value)
		S_TINT_G: tint[1] = int(value)
		S_TINT_B: tint[2] = int(value)
		S_REANIM:
			var index := int(value) - 1
			p["reanim"] = str(reanim_keys[index]) if index >= 0 and index < reanim_keys.size() else ""
	p["tint"] = tint
	_apply()

func button_depress(bid: int) -> void:
	var l := level()
	match bid:
		B_ADD:
			var p := CustomDefs.default_plant(l.next_custom_id(l.custom_plants))
			p["name"] = "Custom Plant %d" % (l.custom_plants.size() + 1)
			l.custom_plants.append(p)
			selected = l.custom_plants.size() - 1
		B_DUPLICATE:
			var src := current()
			if src.is_empty():
				return
			var copy := src.duplicate(true)
			copy["cid"] = l.next_custom_id(l.custom_plants)
			copy["name"] = str(src.get("name", "Plant")) + " copy"
			l.custom_plants.append(copy)
			selected = l.custom_plants.size() - 1
		B_DELETE:
			if current().is_empty():
				return
			var cid := int(current().get("cid", -1))
			l.custom_plants.remove_at(selected)
			_forget_plant(cid)
			selected = clampi(selected, 0, maxi(0, l.custom_plants.size() - 1))
	_apply()

## Removes a deleted plant from anywhere the level referenced it.
func _forget_plant(cid: int) -> void:
	var l := level()
	var st := CustomDefs.seed_type_for_cid(cid)
	l.preset_plants = l.preset_plants.filter(func(p): return int(p.get("custom", -1)) != cid)
	if st != PvZ.SEED_NONE:
		l.preset_seeds.erase(st)
		l.allowed_seeds.erase(st)
		l.conveyor_seeds = l.conveyor_seeds.filter(func(e): return int(e.get("seed", -1)) != st)

func _apply() -> void:
	screen.reinstall()
	_kill_preview()
	mark_dirty()
	rebuild()
