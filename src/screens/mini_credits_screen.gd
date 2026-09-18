class_name MiniCreditsScreen
extends Widget
## Port of MiniCreditsScreen (QE static credits page reached from the main menu).
## The text block is copied from the decomp as-is, including its "insert your mod name" template lines.

var back_button: NewLawnButton
var music_button: NewLawnButton

func _init() -> void:
	App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_CHOOSE_YOUR_SEEDS)

	var btn2 := Res.get_image("IMAGE_SEEDCHOOSER_BUTTON2")
	var btn2_glow := Res.get_image("IMAGE_SEEDCHOOSER_BUTTON2_GLOW")
	back_button = LawnButtons.make_new_button(0, self, "[BACK_TO_MENU_BUTTON]", null, btn2, btn2_glow, btn2_glow)
	back_button.text_down_offset_x = 1
	back_button.text_down_offset_y = 1
	back_button.colors[ButtonWidget.COLOR_LABEL] = Color8(42, 42, 90)
	back_button.colors[ButtonWidget.COLOR_LABEL_HILITE] = Color8(42, 42, 90)
	back_button.resize(18 + PvZ.BOARD_ADDITIONAL_WIDTH, 568 + PvZ.BOARD_OFFSET_Y, btn2.width, btn2.height)

	var play := Res.get_image("IMAGE_CREDITS_PLAYBUTTON")
	music_button = LawnButtons.make_new_button(1, self, "[CREDITS_BUTTON]", null, play, play, play)
	music_button.set_font(Res.get_font("FONT_HOUSEOFTERROR20"))
	music_button.colors[ButtonWidget.COLOR_LABEL] = Color8(255, 255, 255)
	music_button.colors[ButtonWidget.COLOR_LABEL_HILITE] = Color8(213, 159, 43)
	music_button.resize(500 + PvZ.BOARD_ADDITIONAL_WIDTH, 520 + PvZ.BOARD_OFFSET_Y, 400, 73)
	music_button.text_offset_x = -30
	music_button.text_offset_y = -2
	music_button.button_offset_y = 8

const _CREDIT_LINES := [
	["'insert your mod name' Team \n", 400, 120], ["Insert Name\n", 400, 140], ["Insert Name\n", 400, 160],
	["Insert Name\n", 400, 180], ["Insert Name\n", 400, 200],
	["Plants Vs. Zombies Team \n", 120, 420], ["George Fan\n", 120, 440], ["Rich Werner\n", 120, 460],
	["Stephen Notley\n", 120, 480], ["Laura Shigihara", 120, 500], ["Tod Semple", 120, 520],
	["Enhanced Team \n", 400, 380], ["BULLETBOT\n", 400, 400],
	["QEWide-Tweaks Credits \n", 400, 440], ["Cardboard\n", 400, 460], ["BoneL (bug hunting forum)\n", 400, 480],
	["Sandy (LawnTweaks debug UI)\n", 400, 500], ["PvZ MA Members\n", 400, 520],
	["Special Thanks \n", 630, 420], ["Electr0Gunner\n", 630, 440], ["Ultra Wide Expansion Team\n", 630, 460],
	["Fruko\n", 630, 480],
]

func draw(g: Graphics) -> void:
	g.draw_image(Res.get_image("IMAGE_BACKGROUND6BOSS"), 0, 0)
	TodStrings.draw_string(g, "CREDITS", PvZ.BOARD_WIDTH / 2, 58, Res.get_font("FONT_HOUSEOFTERROR28"), Color8(220, 220, 220), PvZ.DS_ALIGN_CENTER)
	g.translate(PvZ.BOARD_ADDITIONAL_WIDTH, PvZ.BOARD_OFFSET_Y)
	var f := Res.get_font("FONT_HOUSEOFTERROR16")
	for l in _CREDIT_LINES:
		TodStrings.draw_string(g, l[0], l[1], l[2], f, Color.WHITE, PvZ.DS_ALIGN_CENTER)
	g.translate(-PvZ.BOARD_ADDITIONAL_WIDTH, -PvZ.BOARD_OFFSET_Y)

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	add_widget(back_button)
	if App.has_finished_adventure():
		add_widget(music_button)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	remove_widget(back_button)
	if App.has_finished_adventure():
		remove_widget(music_button)

func button_press(_bid: int, _count: int = 1) -> void:
	App.play_sample("SOUND_BUTTONCLICK")

func button_depress(bid: int) -> void:
	if bid == 0:
		App.kill_mini_credit_screen()
		App.do_back_to_main()
	if bid == 1:
		App.kill_mini_credit_screen()
		App.show_credit_screen()
