class_name NewUserDialog
extends LawnDialog
## Port of NewUserDialog (create / rename a profile).

var name_edit_widget: EditWidget

func _init(is_rename: bool) -> void:
	super._init(PvZ.DIALOG_RENAMEUSER if is_rename else PvZ.DIALOG_CREATEUSER, true,
		"[RENAME_USER]" if is_rename else "[NEW_USER]", "[PLEASE_ENTER_NAME]", "[DIALOG_BUTTON_OK]", BUTTONS_OK_CANCEL)
	vertical_center_text = false
	name_edit_widget = EditWidget.create_lawn(0, self, self)
	name_edit_widget.max_chars = 12
	name_edit_widget.add_width_check_font(Res.get_font("FONT_BRIANNETOD16"), 220)
	calc_size(110, 40)

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	add_widget(name_edit_widget)
	wm.set_focus(name_edit_widget)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	remove_widget(name_edit_widget)

func get_preferred_height(w: int) -> int:
	return super.get_preferred_height(w) + 40

func resize(nx: int, ny: int, w: int, h: int) -> void:
	super.resize(nx, ny, w, h)
	if name_edit_widget:
		name_edit_widget.resize(content_insets[0] + 12, height - 155, width - content_insets[0] - content_insets[2] - 24, 28)

func draw(g: Graphics) -> void:
	super.draw(g)
	LawnButtons.draw_edit_box(g, name_edit_widget)

func edit_widget_text(_eid: int, _s: String) -> void:
	App.button_depress(id + 2000)

func allow_char(_eid: int, ch: String) -> bool:
	var c := ch.unicode_at(0)
	return c == 0x20 or (c >= 0x30 and c <= 0x39) or (c >= 0x41 and c <= 0x5A) or (c >= 0x61 and c <= 0x7A)

## Collapses runs of spaces and drops a trailing space.
func get_name() -> String:
	var out := ""
	var last := " "
	for ch in name_edit_widget.text:
		if ch != " ":
			out += ch
		elif ch != last:
			out += " "
		last = ch
	if out.ends_with(" "):
		out = out.substr(0, out.length() - 1)
	return out

func set_name(the_name: String) -> void:
	name_edit_widget.set_text(the_name, true)
	name_edit_widget.cursor_pos = the_name.length()
	name_edit_widget.hilite_pos = 0
