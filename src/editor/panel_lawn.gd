class_name PanelLawn
extends EditorPanel
## The lawn: background, lane metrics, per-lane and per-cell rules, and what starts on the board.
##
## Lane type is deliberately separate from how the lane looks. With a custom background nothing is
## painted for it at all - marking a lane as water only changes the rules (what can be planted
## there, which zombies use it, whether plants drown), and the background image supplies the look.

const S_BG_MODE := 1
const S_BG_BUILTIN := 2
const S_BG_IMAGE := 3
const S_GEOM := 4
const S_MOWERS := 5
const S_BG_X := 6
const S_BG_Y := 7
const S_BG_SCALE := 8
const S_FOG_COL := 9
const T_NIGHT := 20
const T_WATER := 21
const T_FOG := 22
const T_BUSHES := 23
const T_GRAVES := 24
const T_WALK_RIGHT := 25
const B_TOOL_BASE := 100
const B_CLEAR_CELLS := 60
const B_CLEAR_ITEMS := 61
const B_PICK_PLANT := 62

## Painting tools. `kind` is what a click does to a cell.
const TOOLS := [
	{"kind": "lane", "value": PvZ.PLANTROW_NORMAL, "name": "Ground", "color": Color8(96, 170, 70)},
	{"kind": "lane", "value": PvZ.PLANTROW_POOL, "name": "Water", "color": Color8(70, 136, 208)},
	{"kind": "lane", "value": PvZ.PLANTROW_HIGH_GROUND, "name": "High ground", "color": Color8(198, 150, 74)},
	{"kind": "lane", "value": PvZ.PLANTROW_DIRT, "name": "Blocked", "color": Color8(120, 96, 72)},
	{"kind": "cell", "value": PvZ.GRIDSQUARE_GRASS, "name": "Cell: ground", "color": Color8(126, 200, 96)},
	{"kind": "cell", "value": PvZ.GRIDSQUARE_POOL, "name": "Cell: water", "color": Color8(96, 168, 236)},
	{"kind": "cell", "value": PvZ.GRIDSQUARE_HIGH_GROUND, "name": "Cell: high", "color": Color8(226, 180, 96)},
	{"kind": "cell", "value": PvZ.GRIDSQUARE_DIRT, "name": "Cell: blocked", "color": Color8(150, 120, 92)},
	{"kind": "cell", "value": -1, "name": "Cell: follow lane", "color": Color8(170, 170, 170)},
	{"kind": "plant", "value": 0, "name": "Place plant", "color": Color8(120, 210, 90)},
	{"kind": "item", "value": PvZ.GRIDITEM_GRAVESTONE, "name": "Gravestone", "color": Color8(160, 160, 176)},
	{"kind": "item", "value": PvZ.GRIDITEM_CRATER, "name": "Crater", "color": Color8(110, 92, 72)},
	{"kind": "item", "value": PvZ.GRIDITEM_LADDER, "name": "Ladder", "color": Color8(190, 172, 120)},
	{"kind": "erase", "value": 0, "name": "Erase", "color": Color8(214, 96, 80)},
]

const SIDE_W := 330

var tool := 0
var plant_to_place := PvZ.SEED_PEASHOOTER
var hover_cell := Vector2i(-1, -1)
var picking_plant := false
var plant_grid: EditorUi.IconGrid
var seed_list: Array = []
var bg_image_keys: Array = []
var tool_buttons: Array = []
var tool_strip_y := 0

func build() -> void:
	var l := level()
	var y := 40
	add_choice(S_BG_MODE, "Background", l.bg_mode, ["Built-in", "Custom image"], PAD, y, SIDE_W, 120)
	y += ROW_H
	if l.bg_mode == LevelDef.BG_BUILTIN:
		add_choice(S_BG_BUILTIN, "Which", l.bg_builtin, LevelDef.BG_NAMES, PAD, y, SIDE_W, 120)
		y += ROW_H
	else:
		bg_image_keys = _image_asset_keys()
		var names: Array = ["(none)"]
		for k in bg_image_keys:
			names.append(str(k).get_file())
		var index := bg_image_keys.find(l.bg_image) + 1
		add_choice(S_BG_IMAGE, "Image", index, names, PAD, y, SIDE_W, 120)
		y += ROW_H
		add_stepper(S_BG_X, "Offset X", l.bg_offset.x, -600, 600, 5, PAD, y, SIDE_W, 120)
		y += ROW_H
		add_stepper(S_BG_Y, "Offset Y", l.bg_offset.y, -400, 400, 5, PAD, y, SIDE_W, 120)
		y += ROW_H
		var sc := add_stepper(S_BG_SCALE, "Scale", l.bg_scale, 0.2, 4.0, 0.05, PAD, y, SIDE_W, 120)
		sc.decimals = 2
		sc.suffix = " x"
		y += ROW_H
	add_choice(S_GEOM, "Lane metrics", l.geometry, LevelDef.GEOM_NAMES, PAD, y, SIDE_W, 120)
	y += ROW_H
	add_choice(S_MOWERS, "Lawn mowers", l.mowers, LevelDef.MOWER_NAMES, PAD, y, SIDE_W, 120)
	y += ROW_H + 10

	flags_y = y
	y += 22
	add_toggle(T_NIGHT, "Night (mushrooms awake, no sun)", l.night, PAD, y, SIDE_W)
	y += 26
	add_toggle(T_WATER, "Paint the animated water overlay", l.pool_water, PAD, y, SIDE_W)
	y += 26
	add_toggle(T_FOG, "Fog rolls in", l.fog, PAD, y, SIDE_W)
	y += 26
	add_stepper(S_FOG_COL, "Fog starts at column", l.fog_column, 0, 8, 1, PAD + 20, y, SIDE_W - 20, 150)
	y += ROW_H
	add_toggle(T_BUSHES, "Bushes rustle at the edge", l.bushes, PAD, y, SIDE_W)
	y += 26
	add_toggle(T_GRAVES, "Gravestones and rising zombies", l.graves, PAD, y, SIDE_W)
	y += 26
	add_toggle(T_WALK_RIGHT, "Zombies walk in from the right", l.walk_in_from_right, PAD, y, SIDE_W)
	y += 32

	add_button_row([[B_CLEAR_CELLS, "Clear cell overrides"], [B_CLEAR_ITEMS, "Clear board items"]],
		PAD, y, PAD + SIDE_W)

	_build_tool_buttons()
	if picking_plant:
		_build_plant_picker()

var flags_y := 0

func _build_tool_buttons() -> void:
	var specs: Array = []
	for i in TOOLS.size():
		specs.append([B_TOOL_BASE + i, str(TOOLS[i].name)])
	# anchored to the bottom of the sheet so the palette never wraps off the panel
	var x := SIDE_W + PAD * 2
	var rows := button_row_rows(specs, x, width - PAD)
	tool_strip_y = height - PAD - rows * 32 + 4
	tool_buttons = add_button_row(specs, x, tool_strip_y, width - PAD)

func _build_plant_picker() -> void:
	seed_list = all_seed_types()
	plant_grid = add_grid(B_PICK_PLANT, SIDE_W + PAD * 2, 40, width - SIDE_W - PAD * 3,
		maxi(120, tool_strip_y - 70), Vector2i(54, 72))
	plant_grid.count = seed_list.size()
	plant_grid.selected = seed_list.find(plant_to_place)
	plant_grid.draw_cell = Callable(self, "_draw_plant_cell")

func _draw_plant_cell(g: Graphics, index: int, r: Rect2, hovered: bool, selected: bool) -> void:
	EditorUi.draw_slot(g, r, hovered, selected)
	var st: int = seed_list[index]
	EditorUi.draw_seed_packet(g, st, r.position.x + 2, r.position.y + 2, (r.size.x - 4) / 50.0)

func _image_asset_keys() -> Array:
	var out: Array = []
	for k in level().assets:
		if str(level().assets[k].get("type", "")) == "image":
			out.append(str(k))
	out.sort()
	return out

# ================================================================ preview geometry
func preview_rect() -> Rect2:
	var x := SIDE_W + PAD * 2
	var w := width - x - PAD
	var h := int(w * float(PvZ.BOARD_HEIGHT) / float(PvZ.BOARD_WIDTH))
	return Rect2(x, 40, w, h)

func preview_scale() -> float:
	return preview_rect().size.x / float(PvZ.BOARD_WIDTH)

## Cell rectangle in board pixels, mirroring BoardCore's own grid maths for this level's metrics.
func cell_board_rect(gx: int, gy: int) -> Rect2:
	var l := level()
	var px := gx * 80 + PvZ.LAWN_XMIN + PvZ.BOARD_ADDITIONAL_WIDTH
	var py: int
	var ch := 100
	match l.geometry:
		LevelDef.GEOM_ROOF:
			py = gy * 85 + ((5 - gx) * 20 if gx < 5 else 0) + PvZ.LAWN_YMIN - 10
			ch = 85
		LevelDef.GEOM_POOL:
			py = gy * 85 + PvZ.LAWN_YMIN
			ch = 85
		_:
			py = gy * 100 + PvZ.LAWN_YMIN
	if l.cell_square_type(gx, gy) == PvZ.GRIDSQUARE_HIGH_GROUND:
		py -= PvZ.HIGH_GROUND_HEIGHT
	return Rect2(px, py + PvZ.BOARD_OFFSET_Y, 80, ch)

func cell_screen_rect(gx: int, gy: int) -> Rect2:
	var s := preview_scale()
	var pr := preview_rect()
	var b := cell_board_rect(gx, gy)
	return Rect2(pr.position.x + b.position.x * s, pr.position.y + b.position.y * s, b.size.x * s, b.size.y * s)

func cell_at(mx: int, my: int) -> Vector2i:
	for gy in level().row_count():
		for gx in BoardCore.MAX_GRID_SIZE_X:
			if cell_screen_rect(gx, gy).has_point(Vector2(mx, my)):
				return Vector2i(gx, gy)
	return Vector2i(-1, -1)

# ================================================================ drawing
func draw_content(g: Graphics) -> void:
	section(g, "Background and lanes", PAD, 14, SIDE_W)
	section(g, "Stage rules", PAD, flags_y, SIDE_W)
	if picking_plant:
		section(g, "Pick a plant to place, then click the lawn", SIDE_W + PAD * 2, 14, width - SIDE_W - PAD * 3)
		_draw_tool_strip(g)
		return
	section(g, "Lawn preview - click a cell with the selected tool", SIDE_W + PAD * 2, 14, width - SIDE_W - PAD * 3)
	_draw_preview(g)
	_draw_tool_strip(g)

func _draw_preview(g: Graphics) -> void:
	var l := level()
	var pr := preview_rect()
	var s := preview_scale()
	var cg := g.copy()
	cg.clip_rect(pr.position.x, pr.position.y, pr.size.x, pr.size.y)
	cg.color = Color8(16, 22, 14)
	cg.fill_rect_r(pr)
	# background
	var bg: PvzImage = null
	var bx := pr.position.x + (-PvZ.BOARD_OFFSET_X) * s
	var by := pr.position.y
	var bscale := s
	if l.uses_custom_background():
		bg = CustomAssets.get_image(l.bg_image)
		bx += l.bg_offset.x * s
		by += l.bg_offset.y * s
		bscale = s * l.bg_scale
	else:
		bg = Res.get_image(_builtin_background_id(l.bg_builtin))
	if bg != null:
		cg.draw_image_scaled_size(bg, bx, by, bg.width * bscale, bg.height * bscale)
	else:
		cg.color = Color8(60, 76, 52)
		cg.fill_rect_r(pr)
		EditorUi.draw_text(cg, "No background image picked yet", int(pr.position.x + pr.size.x * 0.5),
			int(pr.position.y + pr.size.y * 0.5), EditorUi.font_body(), EditorUi.TEXT_DIM, TodStrings.DS_ALIGN_CENTER)

	# lane and cell rules
	var f := EditorUi.font_small()
	for gy in l.row_count():
		for gx in BoardCore.MAX_GRID_SIZE_X:
			var r := cell_screen_rect(gx, gy)
			var kind := l.cell_square_type(gx, gy)
			var col := _square_color(kind)
			cg.color = Color(col.r, col.g, col.b, 0.24)
			cg.fill_rect_r(r)
			cg.color = Color(0, 0, 0, 0.35)
			cg.draw_rect(r.position.x, r.position.y, r.size.x - 1, r.size.y - 1)
			if int(l.cell_type[gx][gy]) >= 0:
				cg.color = EditorUi.SELECT_EDGE
				cg.draw_rect(r.position.x + 1, r.position.y + 1, r.size.x - 3, r.size.y - 3)
			if hover_cell == Vector2i(gx, gy):
				cg.color = Color(1, 1, 1, 0.28)
				cg.fill_rect_r(r)
	# preset plants and items
	for p in l.preset_plants:
		var gx2 := int(p.get("x", 0))
		var gy2 := int(p.get("y", 0))
		var r2 := cell_screen_rect(gx2, gy2)
		EditorUi.draw_plant_portrait(cg, int(p.get("seed", PvZ.SEED_PEASHOOTER)),
			r2.position.x + r2.size.x * 0.5, r2.position.y + r2.size.y * 0.9, s * 0.92)
	for item in l.preset_items:
		var r3 := cell_screen_rect(int(item.get("x", 0)), int(item.get("y", 0)))
		var icon := _item_icon(int(item.get("type", PvZ.GRIDITEM_GRAVESTONE)))
		if icon[0] != null:
			cg.draw_image_stretch(icon[0], Rect2(r3.position.x + 4, r3.position.y + 4,
				r3.size.x - 8, r3.size.y - 8), icon[1])
		else:
			cg.color = Color8(200, 200, 210, 200)
			cg.fill_rect(r3.position.x + 6, r3.position.y + 6, r3.size.x - 12, r3.size.y - 12)

	# lane legend, drawn inside the preview so it never crowds the settings column
	for gy in l.row_count():
		var lr := cell_screen_rect(0, gy)
		var lane_name: String = LevelDef.ROW_TYPE_NAMES[clampi(l.lane_type(gy), 0, 3)]
		var text := "%d  %s" % [gy + 1, lane_name]
		var tw := f.string_width(text) + 10
		var ty := int(lr.position.y + lr.size.y * 0.5 - 8)
		cg.color = Color(0, 0, 0, 0.55)
		cg.fill_rect(pr.position.x + 2, ty, tw, 16)
		EditorUi.draw_text(cg, text, int(pr.position.x + 7), ty + 12, f,
			_square_color(l.cell_square_type(0, gy)))

	var note := "Lane rules never draw anything here." if l.uses_custom_background() \
		else "Built-in backgrounds already draw their own lanes, so keep the rules matching the picture."
	hint(g, note, int(pr.position.x), int(pr.end.y + 6), int(pr.size.x))

func _draw_tool_strip(g: Graphics) -> void:
	var tx := SIDE_W + PAD * 2
	var ty := tool_strip_y - 24
	label(g, "Tool: " + str(TOOLS[tool].name) + ("  (" + seed_name(plant_to_place) + ")" if str(TOOLS[tool].kind) == "plant" else ""),
		tx, ty, Color(TOOLS[tool].color))
	for i in tool_buttons.size():
		var b: EditorUi.StoneButton = tool_buttons[i]
		if i == tool:
			g.color = Color(TOOLS[i].color)
			g.draw_rect(b.x - 2, b.y - 2, b.width + 3, b.height + 3)

static func _square_color(kind: int) -> Color:
	match kind:
		PvZ.GRIDSQUARE_POOL: return Color8(70, 150, 230)
		PvZ.GRIDSQUARE_HIGH_GROUND: return Color8(226, 176, 80)
		PvZ.GRIDSQUARE_DIRT: return Color8(128, 102, 78)
	return Color8(110, 200, 86)

static func _builtin_background_id(bg: int) -> String:
	match bg:
		PvZ.BACKGROUND_1_DAY: return "IMAGE_BACKGROUND1"
		PvZ.BACKGROUND_2_NIGHT: return "IMAGE_BACKGROUND2"
		PvZ.BACKGROUND_3_POOL: return "IMAGE_BACKGROUND3"
		PvZ.BACKGROUND_4_FOG: return "IMAGE_BACKGROUND4"
		PvZ.BACKGROUND_5_ROOF: return "IMAGE_BACKGROUND5"
		PvZ.BACKGROUND_6_BOSS: return "IMAGE_BACKGROUND6BOSS"
		PvZ.BACKGROUND_MUSHROOM_GARDEN: return "IMAGE_BACKGROUND_MUSHROOMGARDEN"
		PvZ.BACKGROUND_GREENHOUSE: return "IMAGE_BACKGROUND_GREENHOUSE"
		PvZ.BACKGROUND_ZOMBIQUARIUM: return "IMAGE_AQUARIUM1"
	return "IMAGE_BACKGROUND1"

## [image, source rect] for a board item's preview icon, or [null, Rect2()].
static func _item_icon(kind: int) -> Array:
	match kind:
		PvZ.GRIDITEM_GRAVESTONE:
			var tomb := Res.get_image("IMAGE_TOMBSTONES")
			return [tomb, tomb.get_cel_rect(0, 0)] if tomb != null else [null, Rect2()]
		PvZ.GRIDITEM_CRATER:
			var crater := Res.get_image("IMAGE_CRATER")
			return [crater, Rect2(0, 0, crater.width, crater.height)] if crater != null else [null, Rect2()]
		PvZ.GRIDITEM_LADDER:
			var lad := Res.get_image("IMAGE_LADDER_ZOMBIE")
			return [lad, Rect2(0, 0, lad.width, lad.height)] if lad != null else [null, Rect2()]
	return [null, Rect2()]

# ================================================================ interaction
func mouse_move(mx: int, my: int) -> void:
	hover_cell = Vector2i(-1, -1) if picking_plant else cell_at(mx, my)

func mouse_leave() -> void:
	hover_cell = Vector2i(-1, -1)

func mouse_down_btn(mx: int, my: int, btn: int, _count: int) -> void:
	if picking_plant:
		return
	var cell := cell_at(mx, my)
	if cell.x < 0:
		return
	apply_tool(cell.x, cell.y, btn == 1)

func mouse_drag(mx: int, my: int) -> void:
	if picking_plant:
		return
	var cell := cell_at(mx, my)
	if cell.x < 0:
		return
	var kind := str(TOOLS[tool].kind)
	if kind == "lane" or kind == "cell":
		apply_tool(cell.x, cell.y, false)

func apply_tool(gx: int, gy: int, secondary: bool) -> void:
	var l := level()
	var t: Dictionary = TOOLS[tool]
	App.play_sample("SOUND_TAP")
	match str(t.kind):
		"lane":
			l.row_type[gy] = int(t.value)
		"cell":
			l.cell_type[gx][gy] = int(t.value)
		"plant":
			_erase_at(gx, gy)
			if not secondary:
				var entry := {"x": gx, "y": gy, "seed": plant_to_place, "custom": -1, "imitater": PvZ.SEED_NONE}
				if CustomDefs.is_custom_plant(plant_to_place):
					entry.custom = int(CustomDefs.plant_profile(plant_to_place).get("cid", -1))
				l.preset_plants.append(entry)
		"item":
			_erase_at(gx, gy)
			if not secondary:
				l.preset_items.append({"x": gx, "y": gy, "type": int(t.value)})
		"erase":
			_erase_at(gx, gy)
	mark_dirty()

func _erase_at(gx: int, gy: int) -> void:
	var l := level()
	l.preset_plants = l.preset_plants.filter(func(p): return int(p.get("x", -1)) != gx or int(p.get("y", -1)) != gy)
	l.preset_items = l.preset_items.filter(func(p): return int(p.get("x", -1)) != gx or int(p.get("y", -1)) != gy)

# ================================================================ callbacks
func editor_stepper(id: int, value: float) -> void:
	var l := level()
	match id:
		S_BG_MODE:
			l.bg_mode = int(value)
			mark_dirty()
			rebuild()
			return
		S_BG_BUILTIN:
			l.bg_builtin = int(value)
			# a built-in background comes with its own lane layout; offer it as a starting point
			_apply_builtin_lane_defaults()
		S_BG_IMAGE:
			var index := int(value) - 1
			l.bg_image = str(bg_image_keys[index]) if index >= 0 and index < bg_image_keys.size() else ""
		S_BG_X: l.bg_offset.x = int(value)
		S_BG_Y: l.bg_offset.y = int(value)
		S_BG_SCALE: l.bg_scale = value
		S_GEOM: l.geometry = int(value)
		S_MOWERS: l.mowers = int(value)
		S_FOG_COL: l.fog_column = int(value)
	mark_dirty()

## Picking a built-in background lines the lane rules up with what that picture actually shows,
## which is almost always what someone wants; every lane can still be changed afterwards.
func _apply_builtin_lane_defaults() -> void:
	var l := level()
	match l.bg_builtin:
		PvZ.BACKGROUND_3_POOL, PvZ.BACKGROUND_4_FOG:
			l.geometry = LevelDef.GEOM_POOL
			l.row_type = [PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_POOL,
				PvZ.PLANTROW_POOL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL]
			l.pool_water = true
			l.night = l.bg_builtin == PvZ.BACKGROUND_4_FOG
			l.fog = l.bg_builtin == PvZ.BACKGROUND_4_FOG
			l.bushes = true
			l.graves = false
		PvZ.BACKGROUND_5_ROOF, PvZ.BACKGROUND_6_BOSS:
			l.geometry = LevelDef.GEOM_ROOF
			l.row_type = [PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL,
				PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_DIRT]
			l.pool_water = false
			l.night = l.bg_builtin == PvZ.BACKGROUND_6_BOSS
			l.fog = false
			l.bushes = false
			l.graves = false
		PvZ.BACKGROUND_2_NIGHT:
			l.geometry = LevelDef.GEOM_GRASS
			l.row_type = [PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL,
				PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_DIRT]
			l.pool_water = false
			l.night = true
			l.fog = false
			l.bushes = true
			l.graves = true
		_:
			l.geometry = LevelDef.GEOM_GRASS
			l.row_type = [PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL,
				PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_DIRT]
			l.pool_water = false
			l.night = false
			l.fog = false
			l.bushes = true
			l.graves = false
	l.cell_type = LevelDef.make_empty_cells()
	rebuild()

func editor_toggle(id: int, value: bool) -> void:
	var l := level()
	match id:
		T_NIGHT: l.night = value
		T_WATER: l.pool_water = value
		T_FOG: l.fog = value
		T_BUSHES: l.bushes = value
		T_GRAVES: l.graves = value
		T_WALK_RIGHT: l.walk_in_from_right = value
	mark_dirty()

func editor_grid_click(id: int, index: int, _btn: int) -> void:
	if id == B_PICK_PLANT and index >= 0 and index < seed_list.size():
		plant_to_place = int(seed_list[index])
		picking_plant = false
		rebuild()

func button_depress(bid: int) -> void:
	if bid >= B_TOOL_BASE:
		tool = bid - B_TOOL_BASE
		if str(TOOLS[tool].kind) == "plant":
			picking_plant = true
			rebuild()
		return
	match bid:
		B_CLEAR_CELLS:
			level().cell_type = LevelDef.make_empty_cells()
			mark_dirty()
			toast("Cell overrides cleared - every cell follows its lane again.")
		B_CLEAR_ITEMS:
			level().preset_plants.clear()
			level().preset_items.clear()
			mark_dirty()
			toast("Board cleared.")
