class_name GameOverDialog
extends LawnDialog
## Port of GameOverDialog (LawnDialog.cpp).

var menu_button: LawnStoneButton = null

func _init(message: String = "", show_challenge_name: bool = false) -> void:
	super._init(PvZ.DIALOG_GAME_OVER, true, "[GAME_OVER]", message, "", BUTTONS_FOOTER)
	lawn_yes_button.label = "[TRY_AGAIN]"
	if show_challenge_name:
		dialog_header = App.get_current_challenge_def()[ChallengeDefs.NAME]
	if message.length() == 0:
		content_insets[1] += 15
	calc_size(0, 0)
	App.center_dialog(self, width, height)
	clip = false

	menu_button = LawnButtons.make_button(1, self, "[MAIN_MENU_BUTTON]")
	menu_button.resize(635 - x + PvZ.BOARD_ADDITIONAL_WIDTH * 2 - App.board_view_crop, -10 - y, 163, 46)

	App.board.show_shovel = false
	App.board.menu_button.btn_no_draw = true

func button_depress(bid: int) -> void:
	if bid == 1:
		App.kill_dialog(PvZ.DIALOG_GAME_OVER)
		App.kill_board()
		if App.is_survival_mode():
			App.show_challenge_screen(PvZ.CHALLENGE_PAGE_SURVIVAL)
		elif App.is_puzzle_mode():
			App.show_challenge_screen(PvZ.CHALLENGE_PAGE_PUZZLE)
		elif App.is_adventure_mode():
			App.show_game_selector()
		else:
			App.show_challenge_screen(PvZ.CHALLENGE_PAGE_CHALLENGE)
	elif bid == ID_FOOTER:
		App.kill_dialog(PvZ.DIALOG_GAME_OVER)
		App.end_level()

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	if menu_button:
		add_widget(menu_button)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	if menu_button:
		remove_widget(menu_button)

func mouse_drag(mx: int, my: int) -> void:
	super.mouse_drag(mx, my)
	if menu_button:
		menu_button.resize(635 - x + PvZ.BOARD_ADDITIONAL_WIDTH * 2 - App.board_view_crop, -10 - y, 163, 46)
