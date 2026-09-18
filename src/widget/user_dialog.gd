class_name UserDialog
extends LawnDialog
## Port of UserDialog ("Who are you?" profile picker).

const USER_DIALOG_RENAME_USER := 0
const USER_DIALOG_DELETE_USER := 1

var user_list: ListWidget
var rename_button: LawnStoneButton
var delete_button: LawnStoneButton
var num_users := 0

func _init() -> void:
	super._init(PvZ.DIALOG_USERDIALOG, true, "[WHO_ARE_YOU]", "", "", BUTTONS_OK_CANCEL)
	vertical_center_text = false
	user_list = ListWidget.new(0, Res.get_font("FONT_BRIANNETOD16"), self)
	user_list.set_colors([[23, 24, 35], [0, 0, 0], [235, 225, 180], [255, 255, 255], [20, 180, 15]])
	user_list.draw_outline = true
	user_list.justify = ListWidget.JUSTIFY_CENTER
	user_list.item_height = 24
	rename_button = LawnButtons.make_button(USER_DIALOG_RENAME_USER, self, "[RENAME_BUTTON]")
	delete_button = LawnButtons.make_button(USER_DIALOG_DELETE_USER, self, "[DELETE_BUTTON]")

	num_users = 0
	if App.player_info:
		user_list.set_select(user_list.add_line(App.player_info.name, false))
		num_users += 1
	# ProfileMap is a std::map ordered case-insensitively.
	for k in App.profile_mgr._sorted_keys():
		var p: PlayerInfo = App.profile_mgr.profiles[k]
		if App.player_info and p.name == App.player_info.name:
			continue
		user_list.add_line(p.name, false)
		num_users += 1
	if num_users < 8:
		user_list.add_line("[CREATE_NEW_USER]", false)

	tall_bottom = true
	calc_size(210, 270)

## LawnDialog::GetLeft / GetTop / GetWidth
func get_left() -> int:
	return content_insets[0] + background_insets[0]

func get_top() -> int:
	return content_insets[1] + background_insets[1] + 99

func get_inner_width() -> int:
	return width - content_insets[0] - content_insets[2] - background_insets[0] - background_insets[2]

func resize(nx: int, ny: int, w: int, h: int) -> void:
	super.resize(nx, ny, w, h)
	if user_list == null:
		return
	user_list.resize(get_left() + 30, get_top() + 4, get_inner_width() - 60, 200)
	rename_button.layout(LAY_SAME_LEFT | LAY_ABOVE | LAY_SAME_HEIGHT | LAY_SAME_WIDTH, lawn_yes_button)
	delete_button.layout(LAY_SAME_LEFT | LAY_ABOVE | LAY_SAME_HEIGHT | LAY_SAME_WIDTH, lawn_no_button)

func get_preferred_height(w: int) -> int:
	return super.get_preferred_height(w) + 190

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	add_widget(user_list)
	add_widget(delete_button)
	add_widget(rename_button)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	remove_widget(user_list)
	remove_widget(delete_button)
	remove_widget(rename_button)

func get_sel_name() -> String:
	if user_list.select_idx < 0 or user_list.select_idx >= num_users:
		return ""
	return user_list.get_string_at(user_list.select_idx)

func finish_delete_user() -> void:
	var sel := user_list.select_idx
	user_list.remove_line(user_list.select_idx)
	sel = maxi(sel - 1, 0)
	if user_list.get_line_count() > 0:
		user_list.set_select(sel)
	num_users -= 1
	if num_users == 7:
		user_list.add_line("[CREATE_NEW_USER]", false)

func finish_rename_user(new_name: String) -> void:
	if user_list.select_idx < num_users:
		user_list.set_line(user_list.select_idx, new_name)

func list_clicked(_lid: int, idx: int, click_count: int) -> void:
	if idx == num_users:
		App.do_create_user_dialog()
	else:
		user_list.set_select(idx)
		if click_count == 2:
			App.finish_user_dialog(true)

func button_depress(bid: int) -> void:
	super.button_depress(bid)
	var sel := get_sel_name()
	if not sel.is_empty():
		match bid:
			USER_DIALOG_RENAME_USER:
				App.do_rename_user_dialog(sel)
			USER_DIALOG_DELETE_USER:
				App.do_confirm_delete_user_dialog(sel)

func edit_widget_text(_eid: int, _s: String) -> void:
	App.button_depress(id + 2000)

func allow_char(_eid: int, ch: String) -> bool:
	return ch.is_valid_int()
