class_name NetMenuDialog
extends LawnDialog
## In-game menu for online matches. The game can't pause, so this only offers going back or leaving.

func _init() -> void:
	super._init(NetSession.DIALOG_MENU, true, "[MENU_BUTTON]",
		"The match keeps going while this menu is open.\nLeaving ends the match and closes the lobby for everyone.",
		"", BUTTONS_YES_NO)
	lawn_yes_button.label = "Back to Game"
	lawn_no_button.label = "Leave Match"
	calc_size(60, 0)

func button_depress(bid: int) -> void:
	if update_cnt <= button_delay:
		return
	App.kill_dialog(id)
	if bid == ID_NO:
		App.net.leave()

func key_down(key: int) -> void:
	if key == WidgetManager.KEYCODE_ESCAPE:
		App.kill_dialog(id)
