class_name CheatDialog
extends LawnDialog
## Port of CheatDialog (debug level jump: "3-4", "25", "C<mode>", "F<area-sub>").

var level_edit_widget: EditWidget

func _init() -> void:
	super._init(PvZ.DIALOG_CHEAT, true, "CHEAT", "Enter New Level:", "", BUTTONS_OK_CANCEL)
	vertical_center_text = false
	level_edit_widget = EditWidget.create_lawn(0, self, self)
	level_edit_widget.max_chars = 12
	level_edit_widget.add_width_check_font(Res.get_font("FONT_BRIANNETOD12"), 220)
	var cheat_str: String
	if App.game_mode != PvZ.GAMEMODE_ADVENTURE:
		cheat_str = "C%d" % App.game_mode
	elif App.has_finished_adventure():
		cheat_str = "F%s" % App.get_stage_string(App.player_info.level)
	else:
		cheat_str = App.get_stage_string(App.player_info.level)
	level_edit_widget.set_text(cheat_str, true)
	calc_size(110, 40)

func resize(nx: int, ny: int, w: int, h: int) -> void:
	super.resize(nx, ny, w, h)
	if level_edit_widget:
		level_edit_widget.resize(content_insets[0] + 12, height - 155, width - content_insets[0] - content_insets[2] - 24, 28)

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	add_widget(level_edit_widget)
	wm.set_focus(level_edit_widget)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	remove_widget(level_edit_widget)

func draw(g: Graphics) -> void:
	super.draw(g)
	LawnButtons.draw_edit_box(g, level_edit_widget)

func edit_widget_text(_eid: int, _s: String) -> void:
	App.button_depress(id + 2000)

func allow_char(_eid: int, ch: String) -> bool:
	return ch.is_valid_int() or ch in ["-", "c", "C", "f", "F"]

## Minimal sscanf for "<prefix>%d" and "<prefix>%d-%d". Returns the ints that matched,
## so the array size equals sscanf's return count.
static func scan_ints(s: String, prefix: String, two: bool) -> Array:
	var num := "\\s*([+-]?\\d+)"
	var re := RegEx.new()
	re.compile("^\\s*" + prefix + num + ("-" + num if two else ""))
	var m := re.search(s)
	if m != null:
		return [int(m.get_string(1)), int(m.get_string(2))] if two else [int(m.get_string(1))]
	if two:
		return scan_ints(s, prefix, false)
	return []

func apply_cheat() -> bool:
	var s := level_edit_widget.text
	var c := scan_ints(s, "[cC]", false)
	if c.size() == 1:
		App.game_mode = clampi(c[0], 0, PvZ.NUM_GAME_MODES - 1)
		return true

	var lvl := -1
	var finished := false
	var f := scan_ints(s, "[fF]", true)
	var plain := scan_ints(s, "", true)
	if f.size() == 2:
		lvl = (f[0] - 1) * PvZ.LEVELS_PER_AREA + f[1]
		finished = true
	elif f.size() == 1:
		lvl = f[0]
		finished = true
	elif plain.size() == 2:
		lvl = (plain[0] - 1) * PvZ.LEVELS_PER_AREA + plain[1]
	elif plain.size() == 1:
		lvl = plain[0]

	if lvl <= 0:
		App.do_dialog(PvZ.DIALOG_CHEATERROR, true, "Enter Level",
			"Invalid Level. Do 'number' or 'area-subarea' or 'Cnumber' or 'Farea-subarea'.", "OK", BUTTONS_FOOTER)
		return false

	App.game_mode = PvZ.GAMEMODE_ADVENTURE
	App.player_info.level = lvl
	App.player_info.finished_adventure = 1 if finished else 0
	App.write_current_user_config()
	return true
