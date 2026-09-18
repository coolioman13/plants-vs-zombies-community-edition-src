class_name PanelScript
extends EditorPanel
## Block scripting, Scratch style. A palette of blocks on the left, the level's scripts in the
## middle, and the selected block's inputs underneath.
##
## Click a command block in the palette to drop it into the open script. Click a reporter block
## while an input slot is selected to plug it into that slot instead of a plain number.

const S_CATEGORY := 1
const L_PALETTE := 2
const L_STACKS := 3
const B_NEW_STACK := 10
const B_DEL_STACK := 11
const B_DEL_BLOCK := 12
const B_UP := 13
const B_DOWN := 14
const B_CLEAR_SLOT := 15
const B_INTO_BODY := 16
const ARG_BASE := 100

const PALETTE_W := 252
const STACK_W := 186
const INDENT := 18
const BLOCK_H := 26

var palette_list: EditorUi.ScrollList
var stack_list: EditorUi.ScrollList
var category := 0
var palette_ops: Array = []
var stack_index := 0
## Flattened view of the open script: [{block, depth, path, is_body2_header}]
var flat: Array = []
var selected_path: Array = []
var selected_slot := ""
var canvas_scroll := 0
var hover_block := -1

func stacks() -> Array:
	return level().script_data.get("stacks", [])

func build() -> void:
	_refresh_palette()
	add_choice(S_CATEGORY, "", category, LevelScript.categories(), PAD, 38, PALETTE_W, 0)
	palette_list = add_list(L_PALETTE, PAD, 72, PALETTE_W, height - 122, 30)
	palette_list.count = palette_ops.size()
	palette_list.empty_text = "-"
	palette_list.draw_row = Callable(self, "_draw_palette_row")

	var sx := width - STACK_W - PAD
	stack_list = add_list(L_STACKS, sx, 38, STACK_W, height - 128, 30)
	stack_list.count = stacks().size()
	stack_list.selected = stack_index
	stack_list.empty_text = "No scripts yet."
	stack_list.draw_row = Callable(self, "_draw_stack_row")
	add_button(B_NEW_STACK, "New script", sx, height - 80, STACK_W, 28)
	add_button(B_DEL_STACK, "Delete script", sx, height - 46, STACK_W, 28)

	_reflatten()
	var cx := PAD * 2 + PALETTE_W
	var cw := sx - cx - PAD
	var by := height - 46
	var bx := cx
	for spec in [[B_DEL_BLOCK, "Remove block"], [B_UP, "Up"], [B_DOWN, "Down"], [B_CLEAR_SLOT, "Clear input"]]:
		var btn := add_button(int(spec[0]), str(spec[1]), bx, by, 0, 28)
		bx += btn.width + 6

	_build_arg_editors(cx, cw)

func _refresh_palette() -> void:
	palette_ops = LevelScript.palette_for(LevelScript.categories()[clampi(category, 0, 7)])

func _reflatten() -> void:
	flat = []
	var st := _current_stack()
	if st.is_empty():
		return
	flat.append({"block": st, "depth": 0, "path": [], "kind": "hat"})
	_flatten_body(st.get("body", []), 1, [])

func _flatten_body(body: Array, depth: int, path: Array) -> void:
	for i in body.size():
		var b = body[i]
		if typeof(b) != TYPE_DICTIONARY:
			continue
		var p := path.duplicate()
		p.append(i)
		flat.append({"block": b, "depth": depth, "path": p, "kind": "block"})
		var def := LevelScript.block_def(str(b.get("op", "")))
		if bool(def.get("has_body", false)):
			_flatten_body(b.get("body", []), depth + 1, p + ["body"])
			if bool(def.get("has_body2", false)):
				flat.append({"block": b, "depth": depth, "path": p, "kind": "else"})
				_flatten_body(b.get("body2", []), depth + 1, p + ["body2"])

func _current_stack() -> Dictionary:
	var s := stacks()
	if stack_index < 0 or stack_index >= s.size():
		return {}
	return s[stack_index]

func _selected_block() -> Dictionary:
	for e in flat:
		if e.path == selected_path and str(e.kind) != "else":
			return e.block
	return {}

# ================================================================ argument editors
func _build_arg_editors(cx: int, cw: int) -> void:
	var b := _selected_block()
	if b.is_empty():
		return
	var def := LevelScript.block_def(str(b.get("op", "")))
	var args: Array = def.get("args", [])
	if args.is_empty():
		return
	var y := height - 86 - args.size() * ROW_H
	arg_area_y = y - 22
	for i in args.size():
		var a: Dictionary = args[i]
		var name := str(a.name)
		var value = (b.get("args", {}) as Dictionary).get(name, a.default)
		if typeof(value) == TYPE_DICTIONARY:
			continue   # a reporter is plugged in; it is edited by selecting it in the canvas
		var w := cw - 20
		match int(a.kind):
			LevelScript.ARG_ZOMBIE:
				var names: Array = []
				for zt in all_zombie_types():
					names.append(zombie_name(zt))
				add_choice(ARG_BASE + i, name, all_zombie_types().find(int(value)), names, cx, y, w, 120)
			LevelScript.ARG_PLANT:
				var pnames: Array = []
				var seeds := all_seed_types()
				for st in seeds:
					pnames.append(seed_name(st))
				add_choice(ARG_BASE + i, name, maxi(0, seeds.find(int(value))), pnames, cx, y, w, 120)
			LevelScript.ARG_ROW:
				var rows: Array = ["any"]
				for r in BoardCore.MAX_GRID_SIZE_Y:
					rows.append("lane %d" % (r + 1))
				add_choice(ARG_BASE + i, name, int(value) + 1, rows, cx, y, w, 120)
			LevelScript.ARG_COL:
				add_stepper(ARG_BASE + i, name, int(value) + 1, 1, BoardCore.MAX_GRID_SIZE_X, 1, cx, y, w, 120)
			LevelScript.ARG_LANE_TYPE:
				add_choice(ARG_BASE + i, name, int(value), LevelDef.ROW_TYPE_NAMES, cx, y, w, 120)
			LevelScript.ARG_MUSIC:
				add_choice(ARG_BASE + i, name, maxi(0, PanelLevel.MUSIC_VALUES.find(int(value))),
					PanelLevel.MUSIC_NAMES, cx, y, w, 120)
			LevelScript.ARG_GRIDITEM:
				add_choice(ARG_BASE + i, name, _griditem_index(int(value)),
					["gravestone", "crater", "ladder"], cx, y, w, 120)
			LevelScript.ARG_BOOL:
				add_toggle(ARG_BASE + i, name, bool(value), cx, y, w)
			LevelScript.ARG_TEXT, LevelScript.ARG_VAR, LevelScript.ARG_EVENT, LevelScript.ARG_SOUND:
				add_field(ARG_BASE + i, name, str(value), cx, y, w, 120)
			_:
				add_stepper(ARG_BASE + i, name, float(value), -100000, 100000, 1, cx, y, w, 120)
		y += ROW_H

var arg_area_y := 0

static func _griditem_index(v: int) -> int:
	match v:
		PvZ.GRIDITEM_CRATER: return 1
		PvZ.GRIDITEM_LADDER: return 2
	return 0

static func _griditem_value(i: int) -> int:
	match i:
		1: return PvZ.GRIDITEM_CRATER
		2: return PvZ.GRIDITEM_LADDER
	return PvZ.GRIDITEM_GRAVESTONE

# ================================================================ drawing
func _draw_palette_row(g: Graphics, index: int, r: Rect2, hovered: bool, _sel: bool) -> void:
	if index >= palette_ops.size():
		return
	var op := str(palette_ops[index])
	var def := LevelScript.block_def(op)
	var col: Color = LevelScript.CATEGORY_COLORS.get(str(def.cat), Color8(120, 120, 120))
	_draw_block_shape(g, r, col, int(def.kind), hovered)
	var f := EditorUi.font_small()
	EditorUi.draw_text(g, EditorUi.elide(LevelScript.describe_template(op), f, int(r.size.x - 16)),
		int(r.position.x + 8), int(r.position.y + r.size.y * 0.5 + f.get_ascent() * 0.5) - 1, f, Color.WHITE)

func _draw_stack_row(g: Graphics, index: int, r: Rect2, hovered: bool, sel: bool) -> void:
	var s := stacks()
	if index >= s.size():
		return
	EditorUi.draw_slot(g, r, hovered, sel)
	var st: Dictionary = s[index]
	var f := EditorUi.font_small()
	EditorUi.draw_text(g, EditorUi.elide(LevelScript.describe(st), f, int(r.size.x - 14)),
		int(r.position.x + 7), int(r.position.y + r.size.y * 0.5 + f.get_ascent() * 0.5) - 1, f,
		EditorUi.TEXT_CREAM)

static func _draw_block_shape(g: Graphics, r: Rect2, col: Color, kind: int, hovered: bool) -> void:
	var c := col
	if hovered:
		c = Color(minf(col.r + 0.12, 1.0), minf(col.g + 0.12, 1.0), minf(col.b + 0.12, 1.0))
	g.color = Color(c.r * 0.55, c.g * 0.55, c.b * 0.55)
	g.fill_rect(r.position.x + 1, r.position.y + 2, r.size.x, r.size.y)
	g.color = c
	g.fill_rect_r(r)
	g.color = Color(c.r * 0.7, c.g * 0.7, c.b * 0.7)
	g.draw_rect(r.position.x, r.position.y, r.size.x - 1, r.size.y - 1)
	if kind == LevelScript.KIND_HAT:
		g.color = c
		g.fill_rect(r.position.x + 6, r.position.y - 4, r.size.x - 12, 5)

func canvas_rect() -> Rect2:
	var cx := PAD * 2 + PALETTE_W
	var cw := width - STACK_W - PAD * 2 - cx + PAD
	var bottom := arg_area_y if arg_area_y > 0 else height - 58
	return Rect2(cx, 38, cw, maxf(60.0, bottom - 46))

func draw_content(g: Graphics) -> void:
	section(g, "Blocks", PAD, 14, PALETTE_W)
	var sx := width - STACK_W - PAD
	section(g, "Scripts", sx, 14, STACK_W)
	var cr := canvas_rect()
	if _current_stack().is_empty():
		section(g, "Script", int(cr.position.x), 14, int(cr.size.x))
		hint(g, "Start a script with \"New script\", then pick a hat block on the left to say when " + "it runs. Everything you click after that is added underneath it.\n\n" + "Reporter blocks (the rounded ones) go into input slots: select a block here, click the " + "slot you want under the canvas, then click the reporter in the palette.",
			int(cr.position.x), 46, int(cr.size.x))
		return
	section(g, "Script %d" % (stack_index + 1), int(cr.position.x), 14, int(cr.size.x))
	EditorUi.draw_shade(g, cr, 0.32)
	var cg := g.copy()
	cg.clip_rect(cr.position.x, cr.position.y, cr.size.x, cr.size.y)
	var max_rows := maxi(1, Tod.idiv(int(cr.size.y), BLOCK_H))
	canvas_scroll = clampi(canvas_scroll, 0, maxi(0, flat.size() - max_rows))
	for i in range(canvas_scroll, mini(flat.size(), canvas_scroll + max_rows + 1)):
		var e: Dictionary = flat[i]
		var y := cr.position.y + (i - canvas_scroll) * BLOCK_H
		var depth := int(e.depth)
		var x := cr.position.x + 6 + depth * INDENT
		var w := cr.size.x - 12 - depth * INDENT
		var b: Dictionary = e.block
		var def := LevelScript.block_def(str(b.get("op", "")))
		var col: Color = LevelScript.CATEGORY_COLORS.get(str(def.get("cat", "")), Color8(120, 120, 120))
		var text := "else" if str(e.kind) == "else" else LevelScript.describe(b)
		var rect := Rect2(x, y + 2, w, BLOCK_H - 4)
		_draw_block_shape(cg, rect, col, int(def.get("kind", 0)), i == hover_block)
		if e.path == selected_path and str(e.kind) != "else":
			cg.color = EditorUi.SELECT_EDGE
			cg.draw_rect(rect.position.x - 1, rect.position.y - 1, rect.size.x + 1, rect.size.y + 1)
		var f := EditorUi.font_small()
		EditorUi.draw_text(cg, EditorUi.elide(text, f, int(w - 12)), int(x + 8),
			int(y + BLOCK_H * 0.5 + f.get_ascent() * 0.5) - 1, f, Color.WHITE)
	if flat.size() > max_rows:
		hint(g, "Scroll the script with the mouse wheel.", int(cr.position.x), int(cr.end.y + 2), int(cr.size.x))
	_draw_slot_bar(g)

func _draw_slot_bar(g: Graphics) -> void:
	var b := _selected_block()
	if b.is_empty():
		return
	var def := LevelScript.block_def(str(b.get("op", "")))
	var args: Array = def.get("args", [])
	if args.is_empty():
		return
	var cr := canvas_rect()
	var y := arg_area_y
	label(g, "Inputs (click one, then click a rounded block to plug it in)", int(cr.position.x), y,
		EditorUi.TEXT_GOLD)
	var x := int(cr.position.x)
	var f := EditorUi.font_small()
	for a in args:
		var name := str(a.name)
		var value = (b.get("args", {}) as Dictionary).get(name, a.default)
		var plugged := typeof(value) == TYPE_DICTIONARY
		var text := name + (": " + LevelScript.describe(value) if plugged else "")
		var w := f.string_width(text) + 16
		var r := Rect2(x, y + 18, w, 18)
		EditorUi.draw_slot(g, r, false, selected_slot == name)
		EditorUi.draw_text(g, text, x + 8, y + 18 + f.get_ascent() + 2, f,
			EditorUi.TEXT_GREEN if plugged else EditorUi.TEXT_CREAM)
		x += w + 6

func _slot_at(mx: int, my: int) -> String:
	var b := _selected_block()
	if b.is_empty():
		return ""
	var def := LevelScript.block_def(str(b.get("op", "")))
	var cr := canvas_rect()
	var x := int(cr.position.x)
	var f := EditorUi.font_small()
	for a in def.get("args", []):
		var name := str(a.name)
		var value = (b.get("args", {}) as Dictionary).get(name, a.default)
		var text := name + (": " + LevelScript.describe(value) if typeof(value) == TYPE_DICTIONARY else "")
		var w := f.string_width(text) + 16
		if Rect2(x, arg_area_y + 18, w, 18).has_point(Vector2(mx, my)):
			return name
		x += w + 6
	return ""

# ================================================================ interaction
func mouse_move(mx: int, my: int) -> void:
	hover_block = -1
	var cr := canvas_rect()
	if cr.has_point(Vector2(mx, my)):
		var index := canvas_scroll + Tod.idiv(int(my - cr.position.y), BLOCK_H)
		if index >= 0 and index < flat.size():
			hover_block = index

func mouse_wheel(delta: int) -> bool:
	var before := canvas_scroll
	canvas_scroll = maxi(0, canvas_scroll - delta * 2)
	return canvas_scroll != before

func mouse_down_btn(mx: int, my: int, _btn: int, _count: int) -> void:
	var slot := _slot_at(mx, my)
	if slot != "":
		selected_slot = slot
		App.play_sample("SOUND_TAP")
		return
	var cr := canvas_rect()
	if not cr.has_point(Vector2(mx, my)):
		return
	var index := canvas_scroll + Tod.idiv(int(my - cr.position.y), BLOCK_H)
	if index < 0 or index >= flat.size():
		return
	var e: Dictionary = flat[index]
	if str(e.kind) == "else":
		return
	selected_path = (e.path as Array).duplicate()
	selected_slot = ""
	App.play_sample("SOUND_TAP")
	rebuild()

# ================================================================ callbacks
func editor_stepper(id: int, value: float) -> void:
	if id == S_CATEGORY:
		category = int(value)
		_refresh_palette()
		rebuild()
		return
	if id >= ARG_BASE:
		_set_arg(id - ARG_BASE, value)

func editor_toggle(id: int, value: bool) -> void:
	if id >= ARG_BASE:
		_set_arg(id - ARG_BASE, value)

func _set_arg(index: int, value) -> void:
	var b := _selected_block()
	if b.is_empty():
		return
	var def := LevelScript.block_def(str(b.get("op", "")))
	var args: Array = def.get("args", [])
	if index < 0 or index >= args.size():
		return
	var a: Dictionary = args[index]
	var name := str(a.name)
	var out = value
	match int(a.kind):
		LevelScript.ARG_ZOMBIE:
			var list := all_zombie_types()
			out = int(list[clampi(int(value), 0, list.size() - 1)])
		LevelScript.ARG_PLANT:
			var seeds := all_seed_types()
			out = int(seeds[clampi(int(value), 0, seeds.size() - 1)])
		LevelScript.ARG_ROW:
			out = int(value) - 1
		LevelScript.ARG_COL:
			out = int(value) - 1
		LevelScript.ARG_MUSIC:
			out = int(PanelLevel.MUSIC_VALUES[clampi(int(value), 0, PanelLevel.MUSIC_VALUES.size() - 1)])
		LevelScript.ARG_GRIDITEM:
			out = _griditem_value(int(value))
		LevelScript.ARG_BOOL:
			out = bool(value)
		LevelScript.ARG_NUMBER, LevelScript.ARG_LANE_TYPE:
			out = int(value) if is_equal_approx(value, round(value)) else value
	(b.get("args", {}) as Dictionary)[name] = out
	mark_dirty()

func update() -> void:
	super.update()
	var b := _selected_block()
	if b.is_empty():
		return
	var def := LevelScript.block_def(str(b.get("op", "")))
	var args: Array = def.get("args", [])
	for c in _controls:
		if c is EditorUi.TextField and c.has_focus and c.id >= ARG_BASE:
			var i: int = c.id - ARG_BASE
			if i < args.size():
				var name := str(args[i].name)
				if str((b.get("args", {}) as Dictionary).get(name, "")) != c.text:
					(b.get("args", {}) as Dictionary)[name] = c.text
					mark_dirty()

func editor_list_click(id: int, index: int, _mx: int, _btn: int, _clicks: int) -> void:
	match id:
		L_STACKS:
			stack_index = index
			selected_path = []
			selected_slot = ""
			canvas_scroll = 0
			rebuild()
		L_PALETTE:
			_add_from_palette(index)

func _add_from_palette(index: int) -> void:
	if index < 0 or index >= palette_ops.size():
		return
	var op := str(palette_ops[index])
	var def := LevelScript.block_def(op)
	var kind := int(def.kind)
	if kind == LevelScript.KIND_HAT:
		var st := LevelScript.make_block(op)
		st["body"] = []
		stacks().append(st)
		stack_index = stacks().size() - 1
		selected_path = []
		mark_dirty()
		rebuild()
		return
	if _current_stack().is_empty():
		toast("Start a script with a hat block first.", EditorUi.TEXT_RED)
		return
	if kind == LevelScript.KIND_REPORTER or kind == LevelScript.KIND_BOOLEAN:
		_plug_reporter(op)
		return
	_insert_command(LevelScript.make_block(op))

## Puts a reporter into the selected input slot.
func _plug_reporter(op: String) -> void:
	var b := _selected_block()
	if b.is_empty() or selected_slot == "":
		toast("Select a block, then click the input you want to fill.", EditorUi.TEXT_RED)
		return
	(b.get("args", {}) as Dictionary)[selected_slot] = LevelScript.make_block(op)
	mark_dirty()
	rebuild()

## Inserts after the selected block, or into its body when it is a C-shaped block.
func _insert_command(block: Dictionary) -> void:
	var target := _body_for_insert()
	var body: Array = target[0]
	var at: int = target[1]
	body.insert(at, block)
	var path: Array = target[2]
	path.append(at)
	selected_path = path
	selected_slot = ""
	mark_dirty()
	rebuild()

## Returns [body array, index, path prefix] for the next insertion.
func _body_for_insert() -> Array:
	var st := _current_stack()
	if selected_path.is_empty():
		return [st.get("body", []), (st.get("body", []) as Array).size(), []]
	var b := _selected_block()
	var def := LevelScript.block_def(str(b.get("op", "")))
	if bool(def.get("has_body", false)):
		var body: Array = b.get("body", [])
		return [body, body.size(), selected_path.duplicate() + ["body"]]
	# after the selected block, inside whatever body it lives in
	var parent_path: Array = selected_path.slice(0, selected_path.size() - 1)
	var body2 := _resolve_body(parent_path)
	var at := int(selected_path[selected_path.size() - 1]) + 1
	return [body2, at, parent_path]

func _resolve_body(path: Array) -> Array:
	var st := _current_stack()
	var body: Array = st.get("body", [])
	var i := 0
	while i < path.size():
		var key = path[i]
		if typeof(key) == TYPE_STRING:
			i += 1
			continue
		var b = body[int(key)]
		var which := "body"
		if i + 1 < path.size() and typeof(path[i + 1]) == TYPE_STRING:
			which = str(path[i + 1])
			i += 1
		body = b.get(which, [])
		i += 1
	return body

func button_depress(bid: int) -> void:
	match bid:
		B_NEW_STACK:
			var st := LevelScript.make_block("when_level_start")
			st["body"] = []
			stacks().append(st)
			stack_index = stacks().size() - 1
			selected_path = []
		B_DEL_STACK:
			if stack_index >= 0 and stack_index < stacks().size():
				stacks().remove_at(stack_index)
				stack_index = clampi(stack_index, 0, maxi(0, stacks().size() - 1))
				selected_path = []
		B_DEL_BLOCK:
			_remove_selected()
		B_UP:
			_move_selected(-1)
		B_DOWN:
			_move_selected(1)
		B_CLEAR_SLOT:
			var b := _selected_block()
			if not b.is_empty() and selected_slot != "":
				var def := LevelScript.block_def(str(b.get("op", "")))
				for a in def.get("args", []):
					if str(a.name) == selected_slot:
						(b.get("args", {}) as Dictionary)[selected_slot] = a.default
	mark_dirty()
	rebuild()

func _remove_selected() -> void:
	if selected_path.is_empty():
		return
	var parent_path: Array = selected_path.slice(0, selected_path.size() - 1)
	var body := _resolve_body(parent_path)
	var at := int(selected_path[selected_path.size() - 1])
	if at >= 0 and at < body.size():
		body.remove_at(at)
	selected_path = []
	selected_slot = ""

func _move_selected(delta: int) -> void:
	if selected_path.is_empty():
		return
	var parent_path: Array = selected_path.slice(0, selected_path.size() - 1)
	var body := _resolve_body(parent_path)
	var at := int(selected_path[selected_path.size() - 1])
	var to := at + delta
	if at < 0 or at >= body.size() or to < 0 or to >= body.size():
		return
	var b = body.pop_at(at)
	body.insert(to, b)
	selected_path = parent_path.duplicate()
	selected_path.append(to)
