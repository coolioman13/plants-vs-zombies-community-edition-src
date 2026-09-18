class_name ContinueDialog
extends LawnDialog
## Port of ContinueDialog (continue / restart a saved game).

const CONTINUE_DIALOG_CONTINUE := 0
const CONTINUE_DIALOG_NEW_GAME := 1

var continue_button: LawnStoneButton
var new_game_button: LawnStoneButton

func _init() -> void:
	super._init(PvZ.DIALOG_CONTINUE, true, "[CONTINUE_GAME_HEADER]", "", "[DIALOG_BUTTON_CANCEL]", BUTTONS_FOOTER)
	if App.is_adventure_mode():
		dialog_lines = "[CONTINUE_GAME_OR_RESTART]"
		continue_button = LawnButtons.make_button(CONTINUE_DIALOG_CONTINUE, self, "[CONTINUE_BUTTON]")
		new_game_button = LawnButtons.make_button(CONTINUE_DIALOG_NEW_GAME, self, "[RESTART_LEVEL_BUTTON]")
	else:
		dialog_lines = "[CONTINUE_GAME]"
		continue_button = LawnButtons.make_button(CONTINUE_DIALOG_CONTINUE, self, "[CONTINUE_BUTTON]")
		new_game_button = LawnButtons.make_button(CONTINUE_DIALOG_NEW_GAME, self, "[NEW_GAME_BUTTON]")
	tall_bottom = true
	calc_size(10, 60)

func get_preferred_height(w: int) -> int:
	return super.get_preferred_height(w) + 40

func resize(nx: int, ny: int, w: int, h: int) -> void:
	super.resize(nx, ny, w, h)
	if continue_button == null:
		return  # called from the base constructor before the buttons exist
	var btn_w := Res.get_image("IMAGE_BUTTON_LEFT").width + Res.get_image("IMAGE_BUTTON_MIDDLE").width * 3 + Res.get_image("IMAGE_BUTTON_RIGHT").width
	var btn_h := lawn_yes_button.height
	continue_button.resize(lawn_yes_button.x - 20, lawn_yes_button.y - btn_h, btn_w, btn_h)
	new_game_button.resize(lawn_yes_button.x + lawn_yes_button.width - btn_w + 20, continue_button.y, btn_w, btn_h)

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	add_widget(continue_button)
	add_widget(new_game_button)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	remove_widget(continue_button)
	remove_widget(new_game_button)

func restart_looping_sounds() -> void:
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_RAINING_SEEDS or App.is_stormy_night_level():
		App.play_foley(PvZ.FOLEY_RAIN)
	for z in App.board.zombies:
		if not z.dead and z.playing_song:
			z.start_zombie_sound()

func button_depress(bid: int) -> void:
	if bid == CONTINUE_DIALOG_CONTINUE:
		if App.board.next_survival_stage_counter != 1:
			SaveGame.erase_saved_game(App.game_mode, App.player_info.id)
		restart_looping_sounds()
		App.kill_dialog(id)
	elif bid == CONTINUE_DIALOG_NEW_GAME:
		var d: LawnDialog
		if App.is_adventure_mode():
			d = App.do_dialog(PvZ.DIALOG_RESTARTCONFIRM, true, "[RESTART_LEVEL_HEADER]", "[RESTART_LEVEL]", "", BUTTONS_OK_CANCEL)
			d.lawn_yes_button.label = "[RESTART_BUTTON]"
		else:
			d = App.do_dialog(PvZ.DIALOG_RESTARTCONFIRM, true, "[NEW_GAME_HEADER]", "[NEW_GAME]", "", BUTTONS_OK_CANCEL)
			d.lawn_yes_button.label = "[NEW_GAME_BUTTON]"
	else:
		App.kill_dialog(id)
		if App.is_adventure_mode():
			App.show_game_selector()
		elif App.is_survival_mode():
			App.kill_board()
			App.show_challenge_screen(PvZ.CHALLENGE_PAGE_SURVIVAL)
		elif App.is_puzzle_mode():
			App.kill_board()
			App.show_challenge_screen(PvZ.CHALLENGE_PAGE_PUZZLE)
		else:
			App.kill_board()
			App.show_challenge_screen(PvZ.CHALLENGE_PAGE_CHALLENGE)
