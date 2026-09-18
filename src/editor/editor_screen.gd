class_name EditorScreen
extends Widget
## The level editor. A stone tab rail down the left, one panel at a time on the right, and a
## header with the level name plus Save / Test / Levels / Back, all drawn from the game's own art.

const TAB_LEVEL := 0
const TAB_LAWN := 1
const TAB_WAVES := 2
const TAB_SEEDS := 3
const TAB_DAVE := 4
const TAB_ART := 5
const TAB_PLANTS := 6
const TAB_ZOMBIES := 7
const TAB_BOSS := 8
const TAB_SCRIPT := 9
const TAB_FILES := 10

const TABS := [
	{"id": TAB_FILES, "name": "Levels"},
	{"id": TAB_LEVEL, "name": "Level"},
	{"id": TAB_LAWN, "name": "Lawn"},
	{"id": TAB_WAVES, "name": "Waves"},
	{"id": TAB_SEEDS, "name": "Seeds"},
	{"id": TAB_DAVE, "name": "Crazy Dave"},
	{"id": TAB_ART, "name": "Art & Reskins"},
	{"id": TAB_PLANTS, "name": "Plant Maker"},
	{"id": TAB_ZOMBIES, "name": "Zombie Maker"},
	{"id": TAB_BOSS, "name": "Boss Maker"},
	{"id": TAB_SCRIPT, "name": "Scripting"},
]

const BTN_TAB_BASE := 1000
const BTN_SAVE := 1
const BTN_TEST := 2
const BTN_BACK := 3

const RAIL_W := 176
const HEADER_H := 62
const MARGIN := 12

var level: LevelDef
var current_tab := TAB_LEVEL
var tab_buttons: Array = []
var save_button: EditorUi.StoneButton
var test_button: EditorUi.StoneButton
var back_button: EditorUi.StoneButton
var panel: EditorPanel = null
var dirty := false
var toast := ""
var toast_timer := 0
var toast_color := EditorUi.TEXT_GREEN
var clouds_x := 0.0
var header_buttons_left := PvZ.BOARD_WIDTH

func _init(level_id: String = "") -> void:
	CustomLevels.ensure_root()
	if level_id != "":
		level = CustomLevels.load_level(level_id)
	if level == null:
		var list := CustomLevels.list_levels()
		if not list.is_empty():
			level = CustomLevels.load_level(str(list[0].id))
	if level == null:
		level = LevelDef.new()
		level.level_name = "My First Level"
		level.author = App.player_info.name if App.player_info else ""
		CustomLevels.save_level(level)
	CustomAssets.install(level)
	CustomDefs.install(level)

	for t in TABS:
		var b := EditorUi.TabButton.new(BTN_TAB_BASE + int(t.id), self, str(t.name))
		b.resize(MARGIN, 0, RAIL_W - MARGIN * 2, 34)
		tab_buttons.append(b)
	save_button = EditorUi.StoneButton.new(BTN_SAVE, self, "Save", true)
	test_button = EditorUi.StoneButton.new(BTN_TEST, self, "Test Level", true)
	back_button = EditorUi.StoneButton.new(BTN_BACK, self, "Main Menu", true)
	# right-aligned and sized to their own labels, so nothing is ever clipped
	var bx := PvZ.BOARD_WIDTH - 18
	for b in [back_button, test_button, save_button]:
		var bw := EditorUi.button_width(b.label)
		bx -= bw
		b.resize(bx, 14, bw, 32)
		bx -= 8
	header_buttons_left = bx

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	var y := HEADER_H + 8
	for b in tab_buttons:
		b.move(MARGIN, y)
		add_widget(b)
		y += 38
	add_widget(save_button)
	add_widget(test_button)
	add_widget(back_button)
	set_tab(current_tab)

func removed_from_manager(wm: WidgetManager) -> void:
	_close_panel()
	super.removed_from_manager(wm)
	for b in tab_buttons:
		remove_widget(b)
	remove_widget(save_button)
	remove_widget(test_button)
	remove_widget(back_button)

# ================================================================ tabs
func content_rect() -> Rect2i:
	return Rect2i(RAIL_W + MARGIN, HEADER_H + 8,
		PvZ.BOARD_WIDTH - RAIL_W - MARGIN * 2, PvZ.BOARD_HEIGHT - HEADER_H - 20)

func _close_panel() -> void:
	if panel != null:
		panel.teardown()
		remove_widget(panel)
		panel = null

func set_tab(tab: int) -> void:
	current_tab = tab
	for i in tab_buttons.size():
		(tab_buttons[i] as EditorUi.TabButton).active = int(TABS[i].id) == tab
	_close_panel()
	panel = _make_panel(tab)
	if panel == null:
		return
	var r := content_rect()
	panel.screen = self
	panel.resize(r.position.x, r.position.y, r.size.x, r.size.y)
	add_widget(panel)
	panel.build()
	_refresh_badges()

func _make_panel(tab: int) -> EditorPanel:
	match tab:
		TAB_FILES: return PanelFiles.new()
		TAB_LEVEL: return PanelLevel.new()
		TAB_LAWN: return PanelLawn.new()
		TAB_WAVES: return PanelWaves.new()
		TAB_SEEDS: return PanelSeeds.new()
		TAB_DAVE: return PanelDave.new()
		TAB_ART: return PanelArt.new()
		TAB_PLANTS: return PanelPlants.new()
		TAB_ZOMBIES: return PanelZombies.new()
		TAB_BOSS: return PanelBoss.new()
		TAB_SCRIPT: return PanelScript.new()
	return null

func _refresh_badges() -> void:
	for i in tab_buttons.size():
		var b: EditorUi.TabButton = tab_buttons[i]
		match int(TABS[i].id):
			TAB_WAVES: b.badge = str(level.waves.size())
			TAB_PLANTS: b.badge = str(level.custom_plants.size()) if not level.custom_plants.is_empty() else ""
			TAB_ZOMBIES: b.badge = str(level.custom_zombies.size()) if not level.custom_zombies.is_empty() else ""
			TAB_SCRIPT: b.badge = str((level.script_data.get("stacks", []) as Array).size()) if not (level.script_data.get("stacks", []) as Array).is_empty() else ""
			TAB_ART:
				var n := level.reanim_skins.size() + level.part_skins.size() + level.image_skins.size()
				b.badge = str(n) if n > 0 else ""
			TAB_BOSS: b.badge = "on" if bool(level.boss.get("enabled", false)) else ""
			_: b.badge = ""

# ================================================================ level lifecycle
func mark_dirty() -> void:
	dirty = true
	_refresh_badges()

func save_level(quiet: bool = false) -> void:
	if CustomLevels.save_level(level):
		dirty = false
		if not quiet:
			show_toast("Saved \"%s\"." % level.level_name, EditorUi.TEXT_GREEN)
	else:
		show_toast("Could not save this level.", EditorUi.TEXT_RED)

func load_level(id: String) -> void:
	var l := CustomLevels.load_level(id)
	if l == null:
		show_toast("That level could not be read.", EditorUi.TEXT_RED)
		return
	level = l
	CustomAssets.install(level)
	CustomDefs.install(level)
	dirty = false
	set_tab(current_tab)
	show_toast("Opened \"%s\"." % level.level_name, EditorUi.TEXT_GREEN)

func new_level(name: String) -> void:
	var l := LevelDef.new()
	l.level_name = name
	l.author = App.player_info.name if App.player_info else ""
	l.id = CustomLevels.unique_id(name)
	CustomLevels.save_level(l)
	load_level(l.id)

## Reinstalls the custom asset and definition tables after the level's art or entities changed,
## so previews in the editor match what the level will actually look like.
func reinstall() -> void:
	CustomAssets.install(level)
	CustomDefs.install(level)

func show_toast(text: String, color: Color = EditorUi.TEXT_GREEN) -> void:
	toast = text
	toast_color = color
	toast_timer = 320

func test_level() -> void:
	save_level(true)
	var validation := validate()
	if validation != "":
		show_toast(validation, EditorUi.TEXT_RED)
		return
	App.play_sample("SOUND_GRAVEBUTTON")
	App.play_custom_level(level, true)

## Returns "" when the level is playable, or the first problem found.
func validate() -> String:
	if level.waves.is_empty():
		return "Add at least one wave before testing."
	var playable := 0
	for gy in BoardCore.MAX_GRID_SIZE_Y:
		if level.lane_type(gy) != PvZ.PLANTROW_DIRT:
			playable += 1
	if playable == 0:
		return "Every lane is blocked - give the zombies somewhere to walk."
	if level.seed_mode == LevelDef.SEEDS_PRESET and level.preset_seeds.is_empty():
		return "The preset seed bank is empty."
	if level.bg_mode == LevelDef.BG_CUSTOM and level.bg_image == "":
		return "Pick a custom background image, or switch back to a built-in one."
	return ""

# ================================================================ widget callbacks
func button_press(bid: int, _count: int = 1) -> void:
	if bid >= BTN_TAB_BASE:
		App.play_sample("SOUND_TAP")
	else:
		App.play_sample("SOUND_GRAVEBUTTON")

func button_depress(bid: int) -> void:
	if bid >= BTN_TAB_BASE:
		set_tab(bid - BTN_TAB_BASE)
		return
	match bid:
		BTN_SAVE:
			save_level()
		BTN_TEST:
			test_level()
		BTN_BACK:
			save_level(true)
			App.kill_level_editor()
			App.show_game_selector()

func key_down(key: int) -> void:
	if key == WidgetManager.KEYCODE_ESCAPE:
		save_level(true)
		App.kill_level_editor()
		App.show_game_selector()

# panels forward these through, so a panel only implements what it uses
func editor_toggle(id: int, value: bool) -> void:
	if panel: panel.editor_toggle(id, value)

func editor_stepper(id: int, value: float) -> void:
	if panel: panel.editor_stepper(id, value)

func editor_list_click(id: int, index: int, mx: int, btn: int, clicks: int) -> void:
	if panel: panel.editor_list_click(id, index, mx, btn, clicks)

func editor_grid_click(id: int, index: int, btn: int) -> void:
	if panel: panel.editor_grid_click(id, index, btn)

func editor_textarea_changed(id: int, lines: Array) -> void:
	if panel: panel.editor_textarea_changed(id, lines)

func edit_widget_text(id: int, text: String) -> void:
	if panel: panel.edit_widget_text(id, text)

# ================================================================ update / draw
func update() -> void:
	super.update()
	clouds_x = fmod(clouds_x + 0.12, 1000.0)
	if toast_timer > 0:
		toast_timer -= 1

func draw(g: Graphics) -> void:
	_draw_background(g)
	_draw_header(g)
	# tab rail
	EditorUi.draw_frame(g, Rect2(4, HEADER_H, RAIL_W - 8, PvZ.BOARD_HEIGHT - HEADER_H - 4), 0.44)
	if toast_timer > 0:
		_draw_toast(g)

func _draw_background(g: Graphics) -> void:
	var bg := Res.get_image("IMAGE_BACKGROUND1")
	if bg != null:
		var cg := g.copy()
		cg.colorize_images = true
		cg.color = Color(0.42, 0.44, 0.40)
		cg.draw_image_scaled_size(bg, -PvZ.BOARD_OFFSET_X, 0,
			bg.width * 1.0, maxf(PvZ.BOARD_HEIGHT, bg.height))
	else:
		g.color = Color8(34, 42, 30)
		g.fill_rect(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	g.color = Color(0, 0, 0, 0.35)
	g.fill_rect(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)

func _draw_header(g: Graphics) -> void:
	EditorUi.draw_frame(g, Rect2(4, 4, PvZ.BOARD_WIDTH - 8, HEADER_H - 6), 0.42)
	var title := "Level Editor"
	EditorUi.draw_text(g, title, 22, 30, EditorUi.font_title(), EditorUi.TEXT_GOLD)
	var name_text := level.level_name
	if dirty:
		name_text += "  *"
	EditorUi.draw_text(g, EditorUi.elide(name_text, EditorUi.font_body(), maxi(120, header_buttons_left - 40)),
		22, 50, EditorUi.font_body(), EditorUi.TEXT_CREAM)
	var info := "%d wave%s  -  %d zombies" % [level.waves.size(),
		"" if level.waves.size() == 1 else "s", level.total_zombie_count()]
	if not level.custom_plants.is_empty() or not level.custom_zombies.is_empty():
		info += "  -  %d custom plant%s, %d custom zombie%s" % [
			level.custom_plants.size(), "" if level.custom_plants.size() == 1 else "s",
			level.custom_zombies.size(), "" if level.custom_zombies.size() == 1 else "s"]
	var name_w := EditorUi.font_body().string_width(name_text)
	var info_x := 34 + name_w
	EditorUi.draw_text(g, EditorUi.elide(info, EditorUi.font_small(),
		maxi(60, header_buttons_left - info_x - 16)), info_x, 50, EditorUi.font_small(),
		EditorUi.TEXT_DIM)

func _draw_toast(g: Graphics) -> void:
	var f := EditorUi.font_body()
	var w := f.string_width(toast) + 48
	var x := Tod.idiv(PvZ.BOARD_WIDTH - w, 2)
	var y := PvZ.BOARD_HEIGHT - 66
	var alpha := clampf(float(toast_timer) / 60.0, 0.0, 1.0)
	var cg := g.copy()
	cg.color = Color(0, 0, 0, 0.72 * alpha)
	cg.fill_rect(x, y, w, 34)
	cg.color = Color(toast_color.r, toast_color.g, toast_color.b, alpha)
	cg.draw_rect(x, y, w - 1, 33)
	var c := toast_color
	c.a = alpha
	EditorUi.draw_text(cg, toast, Tod.idiv(PvZ.BOARD_WIDTH, 2), y + 23, f, c, TodStrings.DS_ALIGN_CENTER)
