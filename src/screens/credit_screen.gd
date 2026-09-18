class_name CreditScreen
extends Widget
## Port of CreditScreen (the "Zombies on Your Lawn" music video and final credits).

enum { CREDITS_MAIN1, CREDITS_MAIN2, CREDITS_MAIN3, CREDITS_END }
enum { WORD_AA, WORD_EE, WORD_AW, WORD_OH, WORD_OFF }
enum { BRAIN_FLY_ON, BRAIN_FAST_ON, BRAIN_NEXT_WORD, BRAIN_FAST_OFF, BRAIN_FLY_OFF, BRAIN_OFF }
enum { CREDITS_BUTTON_REPLAY, CREDITS_BUTTON_MAIN_MENU }
const T_FRAME := 0
const T_WORD := 1
const T_WORD_X := 2
const T_BRAIN := 3

## [frame, word_type, word_x, brain_type] (gCreditsTiming)
const CREDITS_TIMING := [
	[128.5, WORD_AW, 0, BRAIN_OFF], [133.0, WORD_OH, 0, BRAIN_OFF], [136.5, WORD_EE, 0, BRAIN_OFF], [140.0, WORD_OFF, 0, BRAIN_OFF],
	[141.0, WORD_AW, 214, BRAIN_NEXT_WORD], [143.0, WORD_AW, 297, BRAIN_NEXT_WORD], [145.0, WORD_AW, 348, BRAIN_NEXT_WORD], [149.0, WORD_EE, 400, BRAIN_NEXT_WORD],
	[153.0, WORD_AW, 455, BRAIN_NEXT_WORD], [155.0, WORD_OH, 523, BRAIN_NEXT_WORD], [159.0, WORD_AW, 593, BRAIN_NEXT_WORD], [163.0, WORD_AW, 619, BRAIN_NEXT_WORD],
	[171.0, WORD_OFF, 0, BRAIN_FLY_OFF], [172.0, WORD_OFF, 0, BRAIN_OFF], [173.0, WORD_AW, 214, BRAIN_FAST_ON], [175.0, WORD_AW, 297, BRAIN_NEXT_WORD],
	[177.0, WORD_AW, 348, BRAIN_NEXT_WORD], [181.0, WORD_EE, 400, BRAIN_NEXT_WORD], [185.0, WORD_AW, 455, BRAIN_NEXT_WORD], [187.0, WORD_OH, 523, BRAIN_NEXT_WORD],
	[191.0, WORD_AW, 593, BRAIN_NEXT_WORD], [193.0, WORD_AW, 619, BRAIN_NEXT_WORD], [199.0, WORD_AA, 0, BRAIN_FLY_OFF], [203.0, WORD_OFF, 0, BRAIN_OFF],
	[205.0, WORD_AW, 214, BRAIN_FLY_ON], [207.0, WORD_AW, 297, BRAIN_NEXT_WORD], [209.0, WORD_AW, 348, BRAIN_NEXT_WORD], [213.0, WORD_EE, 400, BRAIN_NEXT_WORD],
	[217.0, WORD_AW, 455, BRAIN_NEXT_WORD], [219.0, WORD_OH, 523, BRAIN_NEXT_WORD], [223.0, WORD_AW, 593, BRAIN_NEXT_WORD], [227.0, WORD_AW, 619, BRAIN_NEXT_WORD],
	[231.0, WORD_OFF, 0, BRAIN_FLY_OFF], [234.0, WORD_OFF, 0, BRAIN_OFF], [235.0, WORD_EE, 150, BRAIN_FAST_ON], [237.0, WORD_OH, 220, BRAIN_NEXT_WORD],
	[239.0, WORD_AW, 307, BRAIN_NEXT_WORD], [241.0, WORD_AW, 390, BRAIN_NEXT_WORD], [245.0, WORD_EE, 452, BRAIN_NEXT_WORD], [249.0, WORD_AW, 512, BRAIN_NEXT_WORD],
	[251.0, WORD_AW, 573, BRAIN_NEXT_WORD], [255.0, WORD_AW, 630, BRAIN_NEXT_WORD], [257.0, WORD_AW, 656, BRAIN_NEXT_WORD], [261.0, WORD_OFF, 0, BRAIN_FLY_OFF],
	[262.0, WORD_AA, 0, BRAIN_OFF], [266.0, WORD_OFF, 0, BRAIN_OFF], [266.5, WORD_AW, 96, BRAIN_FAST_ON], [268.5, WORD_OH, 154, BRAIN_NEXT_WORD],
	[270.5, WORD_OH, 244, BRAIN_NEXT_WORD], [272.5, WORD_AW, 329, BRAIN_NEXT_WORD], [276.5, WORD_AW, 419, BRAIN_NEXT_WORD], [279.5, WORD_AW, 506, BRAIN_NEXT_WORD],
	[281.5, WORD_AW, 597, BRAIN_NEXT_WORD], [284.5, WORD_AW, 671, BRAIN_NEXT_WORD], [286.5, WORD_OFF, 0, BRAIN_FLY_OFF], [287.0, WORD_OH, 48, BRAIN_FAST_ON],
	[288.0, WORD_AW, 125, BRAIN_NEXT_WORD], [290.0, WORD_OH, 193, BRAIN_NEXT_WORD], [291.0, WORD_EE, 254, BRAIN_NEXT_WORD], [294.5, WORD_AW, 318, BRAIN_NEXT_WORD],
	[295.0, WORD_AW, 375, BRAIN_NEXT_WORD], [296.0, WORD_AW, 438, BRAIN_NEXT_WORD], [297.0, WORD_AW, 480, BRAIN_NEXT_WORD], [299.0, WORD_AW, 556, BRAIN_NEXT_WORD],
	[301.0, WORD_AW, 619, BRAIN_NEXT_WORD], [303.0, WORD_AW, 675, BRAIN_NEXT_WORD], [305.0, WORD_AW, 744, BRAIN_NEXT_WORD], [307.0, WORD_OFF, 0, BRAIN_FLY_OFF],
	[309.5, WORD_OFF, 207, BRAIN_FLY_ON], [310.5, WORD_OFF, 287, BRAIN_NEXT_WORD], [311.5, WORD_OFF, 365, BRAIN_NEXT_WORD], [313.5, WORD_OFF, 435, BRAIN_NEXT_WORD],
	[315.5, WORD_OFF, 518, BRAIN_NEXT_WORD], [317.5, WORD_OFF, 603, BRAIN_NEXT_WORD], [318.5, WORD_OFF, 0, BRAIN_FAST_OFF], [319.5, WORD_OFF, 198, BRAIN_FAST_ON],
	[320.5, WORD_OFF, 264, BRAIN_NEXT_WORD], [322.5, WORD_OFF, 335, BRAIN_NEXT_WORD], [323.5, WORD_OFF, 411, BRAIN_NEXT_WORD], [324.5, WORD_OFF, 474, BRAIN_NEXT_WORD],
	[326.5, WORD_OFF, 527, BRAIN_NEXT_WORD], [328.5, WORD_OFF, 595, BRAIN_NEXT_WORD], [332.5, WORD_OFF, 0, BRAIN_FLY_OFF], [337.5, WORD_OFF, 0, BRAIN_OFF],
	[339.5, WORD_AW, 190, BRAIN_FLY_ON], [340.5, WORD_AW, 260, BRAIN_NEXT_WORD], [342.5, WORD_AA, 314, BRAIN_NEXT_WORD], [344.5, WORD_AW, 364, BRAIN_NEXT_WORD],
	[347.5, WORD_AW, 426, BRAIN_NEXT_WORD], [349.5, WORD_OH, 474, BRAIN_NEXT_WORD], [350.5, WORD_AW, 538, BRAIN_NEXT_WORD], [352.5, WORD_EE, 606, BRAIN_NEXT_WORD],
	[353.5, WORD_OFF, 0, BRAIN_FAST_OFF], [354.5, WORD_EE, 187, BRAIN_FAST_ON], [356.5, WORD_AW, 242, BRAIN_NEXT_WORD], [358.5, WORD_OH, 280, BRAIN_NEXT_WORD],
	[359.5, WORD_AW, 340, BRAIN_NEXT_WORD], [360.5, WORD_AW, 394, BRAIN_NEXT_WORD], [361.5, WORD_EE, 439, BRAIN_NEXT_WORD], [363.5, WORD_AW, 500, BRAIN_NEXT_WORD],
	[364.5, WORD_AW, 550, BRAIN_NEXT_WORD], [366.5, WORD_EE, 606, BRAIN_NEXT_WORD], [369.5, WORD_OFF, 0, BRAIN_FLY_OFF], [371.5, WORD_OFF, 200, BRAIN_FLY_ON],
	[372.5, WORD_OH, 258, BRAIN_NEXT_WORD], [374.5, WORD_OFF, 332, BRAIN_NEXT_WORD], [376.5, WORD_OFF, 416, BRAIN_NEXT_WORD], [378.5, WORD_OFF, 494, BRAIN_NEXT_WORD],
	[380.5, WORD_OFF, 576, BRAIN_NEXT_WORD], [381.5, WORD_OFF, 0, BRAIN_FAST_OFF], [382.5, WORD_OFF, 255, BRAIN_FAST_ON], [384.5, WORD_OFF, 322, BRAIN_NEXT_WORD],
	[386.5, WORD_OFF, 400, BRAIN_NEXT_WORD], [388.5, WORD_OFF, 474, BRAIN_NEXT_WORD], [390.5, WORD_OFF, 533, BRAIN_NEXT_WORD], [394.5, WORD_OFF, 0, BRAIN_FLY_OFF],
	[522.0, WORD_OFF, 0, BRAIN_OFF], [523.0, WORD_AW, 214, BRAIN_FAST_ON], [525.0, WORD_AW, 297, BRAIN_NEXT_WORD], [527.0, WORD_AW, 348, BRAIN_NEXT_WORD],
	[531.0, WORD_EE, 400, BRAIN_NEXT_WORD], [535.0, WORD_AW, 455, BRAIN_NEXT_WORD], [537.0, WORD_OH, 523, BRAIN_NEXT_WORD], [541.0, WORD_AW, 593, BRAIN_NEXT_WORD],
	[545.0, WORD_AW, 619, BRAIN_NEXT_WORD], [549.0, WORD_OFF, 0, BRAIN_FLY_OFF], [554.0, WORD_OFF, 0, BRAIN_OFF], [555.0, WORD_AW, 214, BRAIN_FAST_ON],
	[557.0, WORD_AW, 297, BRAIN_NEXT_WORD], [559.0, WORD_AW, 348, BRAIN_NEXT_WORD], [563.0, WORD_EE, 400, BRAIN_NEXT_WORD], [567.0, WORD_AW, 455, BRAIN_NEXT_WORD],
	[569.0, WORD_OH, 523, BRAIN_NEXT_WORD], [573.0, WORD_AW, 593, BRAIN_NEXT_WORD], [575.0, WORD_AW, 619, BRAIN_NEXT_WORD], [581.0, WORD_OFF, 0, BRAIN_FLY_OFF],
	[582.0, WORD_AA, 0, BRAIN_OFF], [586.0, WORD_OFF, 0, BRAIN_OFF], [587.0, WORD_AW, 214, BRAIN_FAST_ON], [589.0, WORD_AW, 297, BRAIN_NEXT_WORD],
	[591.0, WORD_AW, 348, BRAIN_NEXT_WORD], [595.0, WORD_EE, 400, BRAIN_NEXT_WORD], [599.0, WORD_AW, 455, BRAIN_NEXT_WORD], [601.0, WORD_OH, 523, BRAIN_NEXT_WORD],
	[605.0, WORD_AW, 593, BRAIN_NEXT_WORD], [609.0, WORD_AW, 619, BRAIN_NEXT_WORD], [613.0, WORD_OFF, 0, BRAIN_FLY_OFF], [616.0, WORD_OFF, 0, BRAIN_OFF],
	[617.0, WORD_EE, 150, BRAIN_FAST_ON], [619.0, WORD_OH, 220, BRAIN_NEXT_WORD], [621.0, WORD_AW, 307, BRAIN_NEXT_WORD], [623.0, WORD_AW, 390, BRAIN_NEXT_WORD],
	[627.0, WORD_EE, 452, BRAIN_NEXT_WORD], [631.0, WORD_AW, 512, BRAIN_NEXT_WORD], [633.0, WORD_AW, 573, BRAIN_NEXT_WORD], [637.0, WORD_AW, 630, BRAIN_NEXT_WORD],
	[639.0, WORD_AW, 656, BRAIN_NEXT_WORD], [643.0, WORD_OFF, 0, BRAIN_FLY_OFF], [644.0, WORD_AA, 0, BRAIN_OFF], [648.0, WORD_OFF, 0, BRAIN_OFF],
	[649.0, WORD_AA, 196, BRAIN_FAST_ON], [651.0, WORD_EE, 247, BRAIN_NEXT_WORD], [653.0, WORD_AW, 299, BRAIN_NEXT_WORD], [655.0, WORD_AW, 371, BRAIN_NEXT_WORD],
	[658.0, WORD_OH, 443, BRAIN_NEXT_WORD], [659.0, WORD_EE, 475, BRAIN_NEXT_WORD], [661.0, WORD_AW, 512, BRAIN_NEXT_WORD], [662.0, WORD_AA, 544, BRAIN_NEXT_WORD],
	[664.0, WORD_OH, 573, BRAIN_NEXT_WORD], [667.0, WORD_AA, 610, BRAIN_NEXT_WORD], [669.0, WORD_OFF, 0, BRAIN_FAST_OFF], [670.0, WORD_OFF, 48, BRAIN_FAST_ON],
	[671.0, WORD_OFF, 110, BRAIN_NEXT_WORD], [673.0, WORD_OFF, 185, BRAIN_NEXT_WORD], [674.0, WORD_OFF, 262, BRAIN_NEXT_WORD], [676.0, WORD_OFF, 317, BRAIN_NEXT_WORD],
	[677.0, WORD_OFF, 357, BRAIN_NEXT_WORD], [678.0, WORD_OFF, 417, BRAIN_NEXT_WORD], [679.0, WORD_OFF, 491, BRAIN_NEXT_WORD], [682.0, WORD_OFF, 558, BRAIN_NEXT_WORD],
	[685.0, WORD_OFF, 628, BRAIN_NEXT_WORD], [687.0, WORD_OFF, 720, BRAIN_NEXT_WORD], [689.0, WORD_OFF, 0, BRAIN_FLY_OFF], [690.0, WORD_OFF, 172, BRAIN_FAST_ON],
	[692.0, WORD_OFF, 263, BRAIN_NEXT_WORD], [694.0, WORD_OFF, 346, BRAIN_NEXT_WORD], [696.0, WORD_OFF, 423, BRAIN_NEXT_WORD], [698.0, WORD_OFF, 480, BRAIN_NEXT_WORD],
	[700.0, WORD_OFF, 536, BRAIN_NEXT_WORD], [702.0, WORD_OFF, 583, BRAIN_NEXT_WORD], [705.0, WORD_OFF, 633, BRAIN_NEXT_WORD], [708.0, WORD_OFF, 668, BRAIN_NEXT_WORD],
	[712.0, WORD_OFF, 0, BRAIN_FLY_OFF], [719.0, WORD_OFF, 0, BRAIN_OFF], [720.0, WORD_OFF, 182, BRAIN_FAST_ON], [722.0, WORD_OFF, 267, BRAIN_NEXT_WORD],
	[724.0, WORD_OFF, 331, BRAIN_NEXT_WORD], [726.0, WORD_OFF, 371, BRAIN_NEXT_WORD], [729.0, WORD_OFF, 434, BRAIN_NEXT_WORD], [731.0, WORD_OFF, 486, BRAIN_NEXT_WORD],
	[732.0, WORD_OFF, 562, BRAIN_NEXT_WORD], [734.0, WORD_OFF, 617, BRAIN_NEXT_WORD], [735.0, WORD_OFF, 0, BRAIN_FAST_OFF], [736.0, WORD_AW, 148, BRAIN_FAST_ON],
	[738.0, WORD_AW, 211, BRAIN_NEXT_WORD], [740.0, WORD_EE, 298, BRAIN_NEXT_WORD], [742.0, WORD_OH, 367, BRAIN_NEXT_WORD], [744.0, WORD_AW, 440, BRAIN_NEXT_WORD],
	[746.0, WORD_OH, 506, BRAIN_NEXT_WORD], [747.0, WORD_AW, 533, BRAIN_NEXT_WORD], [748.0, WORD_AW, 601, BRAIN_NEXT_WORD], [749.0, WORD_AW, 645, BRAIN_NEXT_WORD],
	[750.0, WORD_OFF, 0, BRAIN_FAST_OFF], [753.0, WORD_OFF, 123, BRAIN_FLY_ON], [755.0, WORD_OFF, 195, BRAIN_NEXT_WORD], [757.0, WORD_OFF, 255, BRAIN_NEXT_WORD],
	[759.0, WORD_OFF, 312, BRAIN_NEXT_WORD], [761.0, WORD_OFF, 378, BRAIN_NEXT_WORD], [763.0, WORD_OFF, 443, BRAIN_NEXT_WORD], [765.0, WORD_OFF, 516, BRAIN_NEXT_WORD],
	[767.0, WORD_OFF, 563, BRAIN_NEXT_WORD], [770.0, WORD_OFF, 588, BRAIN_NEXT_WORD], [773.0, WORD_OFF, 657, BRAIN_NEXT_WORD], [777.0, WORD_OFF, 0, BRAIN_FLY_OFF],
	[907.0, WORD_OFF, 0, BRAIN_OFF], [908.0, WORD_AW, 214, BRAIN_FAST_ON], [910.0, WORD_AW, 297, BRAIN_NEXT_WORD], [912.0, WORD_AW, 348, BRAIN_NEXT_WORD],
	[916.0, WORD_EE, 400, BRAIN_NEXT_WORD], [920.0, WORD_AW, 455, BRAIN_NEXT_WORD], [922.0, WORD_OH, 523, BRAIN_NEXT_WORD], [926.0, WORD_AW, 593, BRAIN_NEXT_WORD],
	[930.0, WORD_AW, 616, BRAIN_NEXT_WORD], [934.0, WORD_OFF, 0, BRAIN_FLY_OFF], [939.0, WORD_OFF, 0, BRAIN_OFF], [940.0, WORD_AW, 214, BRAIN_FAST_ON],
	[942.0, WORD_AW, 297, BRAIN_NEXT_WORD], [944.0, WORD_AW, 348, BRAIN_NEXT_WORD], [948.0, WORD_EE, 400, BRAIN_NEXT_WORD], [952.0, WORD_AW, 455, BRAIN_NEXT_WORD],
	[954.0, WORD_OH, 523, BRAIN_NEXT_WORD], [958.0, WORD_AW, 593, BRAIN_NEXT_WORD], [960.0, WORD_AW, 616, BRAIN_NEXT_WORD], [966.0, WORD_OFF, 0, BRAIN_FLY_OFF],
	[967.0, WORD_AA, 0, BRAIN_OFF], [971.0, WORD_OFF, 0, BRAIN_OFF], [972.0, WORD_AW, 214, BRAIN_FAST_ON], [974.0, WORD_AW, 297, BRAIN_NEXT_WORD],
	[976.0, WORD_AW, 348, BRAIN_NEXT_WORD], [980.0, WORD_EE, 400, BRAIN_NEXT_WORD], [984.0, WORD_AW, 455, BRAIN_NEXT_WORD], [986.0, WORD_OH, 523, BRAIN_NEXT_WORD],
	[990.0, WORD_AW, 593, BRAIN_NEXT_WORD], [994.0, WORD_AW, 616, BRAIN_NEXT_WORD], [998.0, WORD_OFF, 0, BRAIN_FLY_OFF], [1001.0, WORD_OFF, 0, BRAIN_OFF],
	[1002.0, WORD_EE, 150, BRAIN_FAST_ON], [1004.0, WORD_OH, 220, BRAIN_NEXT_WORD], [1006.0, WORD_AW, 307, BRAIN_NEXT_WORD], [1008.0, WORD_AW, 390, BRAIN_NEXT_WORD],
	[1012.0, WORD_EE, 452, BRAIN_NEXT_WORD], [1016.0, WORD_AW, 512, BRAIN_NEXT_WORD], [1018.0, WORD_AW, 573, BRAIN_NEXT_WORD], [1022.0, WORD_AW, 630, BRAIN_NEXT_WORD],
	[1024.0, WORD_AW, 656, BRAIN_NEXT_WORD], [1028.0, WORD_OFF, 0, BRAIN_FLY_OFF], [1029.0, WORD_AA, 0, BRAIN_OFF], [1033.0, WORD_OFF, 0, BRAIN_OFF],
]

const SECONDS_PER_UPDATE := 0.01

## CreditsOverlay: draws the end fade on top of the buttons.
class CreditsOverlay:
	extends Widget
	var owner_screen: CreditScreen

	func _init(screen: CreditScreen) -> void:
		owner_screen = screen
		mouse_visible = false

	func draw(g: Graphics) -> void:
		owner_screen.draw_credits_overlay(g)

var credits_phase := CREDITS_MAIN1
var credits_phase_counter := 0
var credits_reanim: Reanimation = null
var fog_particle: TodParticleSystem = null
var blink_countdown := 700
var main_menu_button: LawnStoneButton
var replay_button: NewLawnButton
var overlay_widget: CreditsOverlay
var draw_brain := false
var brain_pos_x := 0.0
var brain_pos_y := 0.0
var update_count := 0
var draw_count := 0
## PerfTimer mTimerSinceStart, as a start timestamp in milliseconds.
var timer_start_ms := 0
var dont_sync := false
var credits_paused := false
var original_music_volume := 0.0
var preloaded := false
var last_draw_count := 0

func _init() -> void:
	clip = false
	EffectSystem.free_all()
	App.music.stop_all_music()

	main_menu_button = LawnButtons.make_button(CREDITS_BUTTON_MAIN_MENU, self, "[CREDITS_MAIN_MENU_BUTTON]")
	main_menu_button.resize(298 + PvZ.BOARD_ADDITIONAL_WIDTH, 554 + PvZ.BOARD_OFFSET_Y, 209, 46)
	main_menu_button.set_visible(false)

	replay_button = LawnButtons.make_new_button(CREDITS_BUTTON_REPLAY, self, "[CREDITS_REPLAY_BUTTON]", Res.get_font("FONT_HOUSEOFTERROR16"), Res.get_image("IMAGE_CREDITS_PLAYBUTTON"), null, null)
	replay_button.text_down_offset_x = 1
	replay_button.text_down_offset_y = 1
	replay_button.colors[ButtonWidget.COLOR_LABEL] = Color8(255, 255, 255)
	replay_button.colors[ButtonWidget.COLOR_LABEL_HILITE] = Color8(213, 159, 43)
	replay_button.resize(10 + PvZ.BOARD_ADDITIONAL_WIDTH, 530 + PvZ.BOARD_OFFSET_Y, 125, 65)
	replay_button.set_visible(false)
	replay_button.text_offset_x = 33
	replay_button.text_offset_y = -5

	overlay_widget = CreditsOverlay.new(self)
	overlay_widget.resize(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)

	original_music_volume = App.music_volume
	if App.music_volume < 0.1:
		App.set_music_volume(0.85)

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	add_widget(main_menu_button)
	add_widget(replay_button)
	add_widget(overlay_widget)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	remove_widget(main_menu_button)
	remove_widget(replay_button)
	remove_widget(overlay_widget)
	App.set_music_volume(original_music_volume)  # ~CreditScreen

static func _set_words_font(reanim_type: int, only_first_124: bool) -> void:
	var def: Defs.ReanimDef = ReanimTypes.get_def(reanim_type)
	if def == null:
		return
	var black := Res.get_font("FONT_BRIANNETOD32BLACK")
	for td in def.tracks:
		var track := td as Defs.ReanimTrackDef
		for i in track.fonts.size():
			if only_first_124:
				if i < 124 and (track.name == "Words" or track.name == "Words2"):
					track.fonts[i] = black
			elif track.fonts[i] != null:
				track.fonts[i] = black

## Resources load on demand in the port, so preloading only has to patch the word fonts.
func pre_load_credits() -> void:
	preloaded = true
	_set_words_font(PvZ.REANIM_CREDITS_MAIN2, true)
	_set_words_font(PvZ.REANIM_CREDITS_MAIN3, true)
	_set_words_font(PvZ.REANIM_CREDITS_WEARETHEUNDEAD, false)

func _transform_count() -> int:
	return (credits_reanim.definition.tracks[0] as Defs.ReanimTrackDef).frame_count

## Returns [before, after, fraction]; before/after are timing rows or null.
func get_timing() -> Array:
	var frame := _transform_count() * credits_reanim.anim_time - 1.0
	match credits_phase:
		CREDITS_MAIN1: frame += 2.0
		CREDITS_MAIN2: frame += 400.0
		CREDITS_MAIN3: frame += 785.0
		_: return [null, null, 0.0]
	var first: Array = CREDITS_TIMING[0]
	if frame < first[T_FRAME]:
		return [null, first, frame / first[T_FRAME]]
	for i in CREDITS_TIMING.size() - 1:
		var t1: Array = CREDITS_TIMING[i]
		var t2: Array = CREDITS_TIMING[i + 1]
		if t2[T_FRAME] > frame:
			return [t1, t2, (frame - t1[T_FRAME]) / (t2[T_FRAME] - t1[T_FRAME])]
	return [CREDITS_TIMING[CREDITS_TIMING.size() - 1], null, 0.0]

func play_reanim(index: int) -> Reanimation:
	if credits_reanim and not credits_reanim.dead:
		credits_reanim.die()
	var r: Reanimation
	match index:
		1:
			r = App.add_reanimation(0.0, 0.0, 0, PvZ.REANIM_CREDITS_MAIN)
			r.assign_render_group_to_prefix("Background", 1)
			r.assign_render_group_to_prefix("attacher__Zombie", 2)
			r.assign_render_group_to_prefix("Words", 3)
			r.assign_render_group_to_prefix("SpotFront", 3)
		2:
			r = App.add_reanimation(0.0, 0.0, 0, PvZ.REANIM_CREDITS_MAIN2)
			r.assign_render_group_to_prefix("Background", 1)
			r.assign_render_group_to_prefix("attacher__Zombie", 2)
			r.assign_render_group_to_prefix("Words", 3)
			r.assign_render_group_to_prefix("SpotFront", 3)
			r.assign_render_group_to_prefix("attacher__undead", 2)
		3:
			r = App.add_reanimation(0.0, 0.0, 0, PvZ.REANIM_CREDITS_MAIN3)
			r.assign_render_group_to_prefix("Background", 1)
			r.assign_render_group_to_prefix("attacher__Zombie", 2)
			r.assign_render_group_to_prefix("attacher__DiscoLights", 2)
			r.assign_render_group_to_prefix("Words", 3)
			r.assign_render_group_to_prefix("attacher__cattail", 3)
			r.assign_render_group_to_prefix("attacher__undead", 2)
			for prefix in ["black1", "black2", "black3", "black4", "black_iris", "SpotFront", "Words", "Words2", "Words3"]:
				r.assign_render_group_to_prefix(prefix, 4)
		_:
			return null
	r.is_attachment = true
	r.loop_type = Reanimation.REANIM_PLAY_ONCE_AND_HOLD
	credits_reanim = r
	r.set_position(PvZ.BOARD_ADDITIONAL_WIDTH, PvZ.BOARD_OFFSET_Y)
	return r

static func draw_disco(g: Graphics, cx: float, cy: float, time: float) -> void:
	if not App.is_3d_accel():
		return
	var pts: Array = []
	for k in 4:
		pts.append(Vector2(cos(time + k * PI / 2) * 600.0 + cx, sin(time + k * PI / 2) * 200.0 + cy))
	var c := Color8(255, 255, 255, 128)
	var tris := [
		[[pts[0].x, pts[0].y, 0.0, 0.0, c], [pts[1].x, pts[1].y, 1.0, 0.0, c], [pts[3].x, pts[3].y, 0.0, 1.0, c]],
		[[pts[3].x, pts[3].y, 0.0, 1.0, c], [pts[1].x, pts[1].y, 1.0, 0.0, c], [pts[2].x, pts[2].y, 1.0, 1.0, c]],
	]
	var dg := g.copy()
	dg.trans_x = 0
	dg.trans_y = 0
	dg.clear_clip_rect()
	dg.draw_triangles_tex(Res.get_image("IMAGE_REANIM_CREDITS_DISCOLIGHTS"), tris)

func draw_fog_effect(g: Graphics, time: float) -> void:
	var accel := App.is_3d_accel()
	var fog := Res.get_image("IMAGE_FOG" if accel else "IMAGE_FOG_SOFTWARE")
	var fade := int(time * 255.0)
	for fx in 14:
		for fy in 7:
			var cel_look := fx + (fx + 17) * fy
			var cel_col := cel_look % 8
			var px := fx * 80 - 15.0 + PvZ.BOARD_ADDITIONAL_WIDTH
			var py := fy * 85 + 200.0
			var anim_time := _transform_count() * credits_reanim.anim_time / (credits_reanim.anim_rate * SECONDS_PER_UPDATE)
			var t := anim_time * PI * 2
			var phase_x := 6 * PI * fx / 14
			var phase_y := 6 * PI * fy / 7
			var motion := 13 + 4 * sin(t / 900 + phase_y) + 8 * sin(t / 500 + phase_x)
			var color_variant := int(255 - (cel_look % 20) * 1.5 - motion * 1.5)
			var lightness_variant := int(255 - (cel_look % 20) - motion)
			if not accel:
				px += 10
				py += 23
				cel_col = cel_look % fog.num_cols
				color_variant = 255
				lightness_variant = 255
			g.colorize_images = true
			g.color = Color8(color_variant, color_variant, lightness_variant, clampi(fade, 0, 255))
			g.draw_image_cel_rc(fog, px, py, cel_col, 0)
			g.colorize_images = false

func draw_credits_overlay(g: Graphics) -> void:
	if credits_phase == CREDITS_END:
		var fade := Tod.animate_curve(50, 100, credits_phase_counter, 255, 0, Tod.CURVE_LINEAR)
		if fade > 0:
			g.color = Color8(0, 0, 0, fade)
			g.fill_rect(0, 0, width, height)

func draw_final_credits(g: Graphics) -> void:
	var aw := PvZ.BOARD_ADDITIONAL_WIDTH
	var oy := PvZ.BOARD_OFFSET_Y
	var f16 := Res.get_font("FONT_HOUSEOFTERROR16")
	TodStrings.draw_string(g, "[CREDITS_GAMENAME]", PvZ.BOARD_WIDTH / 2, 60 + oy, Res.get_font("FONT_HOUSEOFTERROR28"), Color.WHITE, PvZ.DS_ALIGN_CENTER)
	TodStrings.draw_string_wrapped(g, "[CREDITS_NAMES1]", Rect2i(405 + aw, 90 + oy, 200, 200), f16, Color.WHITE, PvZ.DS_ALIGN_LEFT)
	TodStrings.draw_string_wrapped(g, "[CREDITS_ROLES1]", Rect2i(190 + aw, 90 + oy, 200, 200), f16, Color.WHITE, PvZ.DS_ALIGN_RIGHT)
	TodStrings.draw_string_wrapped(g, "[CREDITS_NAMES2]", Rect2i(340 + aw, 280 + oy, 450, 250), f16, Color.WHITE, PvZ.DS_ALIGN_LEFT)
	TodStrings.draw_string_wrapped(g, "[CREDITS_ROLES2]", Rect2i(30 + aw, 280 + oy, 300, 250), f16, Color.WHITE, PvZ.DS_ALIGN_RIGHT)
	TodStrings.draw_string(g, "[CREDITS_THANKS]", PvZ.BOARD_WIDTH / 2, 530 + oy, f16, Color.WHITE, PvZ.DS_ALIGN_CENTER)

func _transform(track_name: String) -> Reanimation.Transform:
	var t := Reanimation.Transform.new()
	credits_reanim.get_current_transform(credits_reanim.find_track_index(track_name), t)
	return t

## Draws a background image clipped to the rect of a moving reanim track.
func _draw_clipped(g: Graphics, t: Reanimation.Transform, image_name: String) -> void:
	if t.frame == -1.0 or t.image == null:
		return
	var bg := g.copy()
	bg.clip_rect(t.tx + PvZ.BOARD_ADDITIONAL_WIDTH, t.ty + PvZ.BOARD_OFFSET_Y, t.image.width - 1, t.image.height - 1)
	bg.draw_image_f(Res.get_image(image_name), t.tx - PvZ.BOARD_WIDTH / 2, t.ty - PvZ.BOARD_HEIGHT / 2)

func draw(g: Graphics) -> void:
	g.set_linear_blend(true)
	if not preloaded:
		g.color = Color.BLACK
		g.fill_rect(0, 0, width, height)
		draw_count = 1
		return

	# Draw #2 of the original only warms the texture cache (backgrounds and a few reanims); Godot needs no warm-up.
	draw_count += 1
	g.color = Color.BLACK
	g.fill_rect(0, 0, width, height)

	var r := credits_reanim
	var frame_factor := 1.0 / (_transform_count() - 1)
	var bg1 := _transform("Background")
	var bg2 := _transform("Background2")
	var bg2_g := g.copy()

	var clipped1 := credits_phase == CREDITS_MAIN2 and frame_factor * 125.0 > r.anim_time
	var clipped2 := credits_phase == CREDITS_MAIN3 and frame_factor * 125.0 > r.anim_time

	if credits_phase == CREDITS_END:
		draw_final_credits(g)
	if clipped1:
		var bg3 := _transform("Background3")
		var bg4 := _transform("Background4")
		if bg2.frame != -1.0 and bg2.image != null:
			bg2_g.clip_rect(bg2.tx + PvZ.BOARD_ADDITIONAL_WIDTH, bg2.ty + PvZ.BOARD_OFFSET_Y, bg2.image.width - 1, bg2.image.height - 1)
			bg2_g.draw_image_f(Res.get_image("IMAGE_BACKGROUND1"), bg2.tx - PvZ.BOARD_WIDTH / 2, bg2.ty - PvZ.BOARD_HEIGHT / 2)
			bg2_g.clear_clip_rect()
		_draw_clipped(g, bg3, "IMAGE_BACKGROUND1")
		_draw_clipped(g, bg4, "IMAGE_BACKGROUND2")
	if clipped2:
		var bg3b := _transform("Background3")
		var bg4b := _transform("Background4")
		_draw_clipped(g, bg1, "IMAGE_BACKGROUND1")
		if bg3b.frame != -1.0 and bg3b.image != null:
			var g3 := g.copy()
			g3.translate(bg3b.tx - 20.0 + PvZ.BOARD_ADDITIONAL_WIDTH, bg3b.ty - 260.0 + PvZ.BOARD_OFFSET_Y)
			g3.clip_rect(20, 260, bg3b.image.width - 1, bg3b.image.height - 1)
			g3.draw_image_f(Res.get_image("IMAGE_BACKGROUND3"), -220.0 - PvZ.BOARD_ADDITIONAL_WIDTH, 0.0 - PvZ.BOARD_OFFSET_Y)
			g3.draw_image_f(Res.get_image("IMAGE_POOL"), 34.0, 278.0)
		_draw_clipped(g, bg4b, "IMAGE_BACKGROUND2")
	r.draw_render_group(g, 1)

	var draw_pool := false
	var draw_night_pool := false
	var draw_door_bottom := false
	var draw_chimney := false
	var draw_disco_lights := false
	var draw_fog := false
	var at := r.anim_time
	if credits_phase == CREDITS_MAIN1:
		if at > frame_factor * 203.0 and at < frame_factor * 268.0:
			draw_pool = true
		if at > frame_factor * 305.0 and at < frame_factor * 339.0:
			draw_pool = true
			draw_door_bottom = true
	if credits_phase == CREDITS_MAIN2:
		if at > frame_factor * 187.0 and at < frame_factor * 249.0:
			draw_pool = true
			draw_night_pool = true
			if bg1.frame != -1.0 or bg2.frame != -1.0:
				draw_disco_lights = true
		if at > frame_factor * 123.0 and at < frame_factor * 189.0 and bg1.frame != -1.0:
			draw_disco_lights = true
		if at > frame_factor * 189.0 and at < frame_factor * 249.0 and bg2.frame != -1.0:
			draw_disco_lights = true
			draw_fog = true
	if credits_phase == CREDITS_MAIN3:
		if at > frame_factor * 123.0 and at < frame_factor * 218.0:
			draw_chimney = true
		if at > frame_factor * 217.0 and bg1.frame != -1.0:
			draw_disco_lights = true
	if bg2.frame == -1.0:
		draw_door_bottom = false
		draw_chimney = false
	else:
		bg2_g.translate(bg2.tx + 220.0, 0)
		if draw_pool or draw_night_pool:
			bg2_g.translate(PvZ.BOARD_ADDITIONAL_WIDTH * 2, PvZ.BOARD_OFFSET_Y)
			App.pool_effect.pool_effect_draw(bg2_g, draw_night_pool)
			bg2_g.translate(-PvZ.BOARD_ADDITIONAL_WIDTH * 2, -PvZ.BOARD_OFFSET_Y)

	if draw_door_bottom:
		bg2_g.draw_image(Res.get_image("IMAGE_BACKGROUND3_GAMEOVER_INTERIOR_OVERLAY"), -171 + PvZ.BOARD_ADDITIONAL_WIDTH * 2, 241 + PvZ.BOARD_OFFSET_Y)
	r.draw(g)

	if draw_door_bottom:
		g.clip_rect(48 + PvZ.BOARD_ADDITIONAL_WIDTH, PvZ.BOARD_OFFSET_Y, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	if draw_disco_lights:
		var disco_time := _transform_count() * r.anim_time / r.anim_rate
		draw_disco(g, 600.0 + PvZ.BOARD_ADDITIONAL_WIDTH, 450.0 + PvZ.BOARD_OFFSET_Y, disco_time)
		draw_disco(g, 200.0 + PvZ.BOARD_ADDITIONAL_WIDTH, 450.0 + PvZ.BOARD_OFFSET_Y, disco_time)
	if draw_fog:
		bg2_g.draw_image(Res.get_image("IMAGE_REANIM_CREDITS_FOGMACHINE"), 600, 200)
	r.draw_render_group(g, 2)

	if draw_door_bottom:
		g.clear_clip_rect()
		bg2_g.draw_image(Res.get_image("IMAGE_BACKGROUND3_GAMEOVER_MASK"), -172 + PvZ.BOARD_ADDITIONAL_WIDTH * 2, 234 + PvZ.BOARD_OFFSET_Y)
	if draw_chimney:
		bg2_g.draw_image(Res.get_image("IMAGE_BACKGROUND5_GAMEOVER_MASK"), -220 + PvZ.BOARD_ADDITIONAL_WIDTH * 2, 81 + PvZ.BOARD_OFFSET_Y)
	r.draw_render_group(g, 3)

	for ps in EffectSystem.particle_systems:
		if not ps.is_attachment and not ps.dead:
			ps.draw(g)

	if draw_fog:
		var percent := Tod.animate_curve_float_time(frame_factor * 189.0, frame_factor * 249.0, r.anim_time, 0.0, 1.0, Tod.CURVE_LINEAR)
		draw_fog_effect(bg2_g, percent)
	r.draw_render_group(g, 3)

	if draw_brain:
		g.draw_image_f(Res.get_image("IMAGE_BRAIN"), brain_pos_x + PvZ.BOARD_ADDITIONAL_WIDTH, brain_pos_y + PvZ.BOARD_OFFSET_Y)
	r.draw_render_group(g, 4)

static func find_sub_reanim(reanim: Reanimation, reanim_type: int) -> Reanimation:
	if reanim == null or reanim.definition == null:
		return null
	return reanim.find_sub_reanim(reanim_type)

func update_blink() -> void:
	blink_countdown -= 1
	if blink_countdown > 0:
		return
	blink_countdown = 700
	var sunflower := find_sub_reanim(credits_reanim, PvZ.REANIM_SUNFLOWER)
	if sunflower == null:
		return
	if credits_phase == CREDITS_MAIN3:
		var frame_factor := 1.0 / (_transform_count() - 1)
		if credits_reanim.anim_time > frame_factor * 200.0:
			return
	var blink := App.add_reanimation(0.0, 0.0, 0, PvZ.REANIM_SUNFLOWER)
	blink.set_frames_for_layer("anim_blink")
	blink.anim_rate = 15.0
	blink.loop_type = Reanimation.REANIM_PLAY_ONCE_FULL_LAST_FRAME
	blink.attach_to_another_reanimation(sunflower, "anim_idle")

func _timer_duration() -> int:
	return Time.get_ticks_msec() - timer_start_ms

## TodsHackyUnprotectedPerfTimer::SetStartTime
func _set_timer_start(ms_ago: int) -> void:
	timer_start_ms = Time.get_ticks_msec() - ms_ago

func update() -> void:
	super.update()
	if not credits_paused and not main_menu_button.is_over and not replay_button.is_over:
		App.set_cursor(App.CURSOR_POINTER)
	if draw_count == 0 or credits_paused:
		return

	update_count += 1
	if update_count == 1:
		pre_load_credits()
		play_reanim(1)
		App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_CREDITS_ZOMBIES_ON_YOUR_LAWN)
		_set_timer_start(0)
	elif dont_sync or credits_phase == CREDITS_END:
		update_movie()
	elif update_count > 1:
		# Keep the movie locked to wall-clock time so it stays in sync with the song.
		var since_start := _timer_duration()
		var reanim_ms := int((_transform_count() * credits_reanim.anim_time / credits_reanim.anim_rate) * 1000.0)
		if credits_phase == CREDITS_MAIN2:
			reanim_ms += 57142
		elif credits_phase == CREDITS_MAIN3:
			reanim_ms += 112000
		var unsynced := since_start - reanim_ms
		var unsynced_frames := Tod.idiv(unsynced + 5, 10)
		if unsynced > 10000:
			jump_to_frame(credits_phase + 1, 0.0)
			unsynced_frames = 0
		while unsynced_frames > 0:
			update_movie()
			unsynced_frames -= 1
	last_draw_count = draw_count

func _trigger_any(frame_factor: float, frames: Array) -> bool:
	for f in frames:
		if credits_reanim.should_trigger_timed_event(frame_factor * f):
			return true
	return false

func _add_center_particle(effect: int) -> void:
	App.add_tod_particle(PvZ.BOARD_WIDTH / 2, PvZ.BOARD_HEIGHT / 2, PvZ.RENDER_LAYER_TOP, effect)

func update_movie() -> void:
	update_blink()
	var r := credits_reanim
	var frame_factor := 1.0 / (_transform_count() - 1)
	r.update()
	EffectSystem.update()
	App.pool_effect.pool_effect_update()
	turn_off_tongues(r, 0)

	if credits_phase == CREDITS_MAIN1 and r.loop_count > 0:
		r = play_reanim(2)
		credits_phase = CREDITS_MAIN2
	elif credits_phase == CREDITS_MAIN2 and r.loop_count > 0:
		r = play_reanim(3)
		credits_phase = CREDITS_MAIN3
	elif credits_phase == CREDITS_MAIN3 and r.loop_count > 0:
		credits_phase = CREDITS_END
	elif credits_phase == CREDITS_END:
		credits_phase_counter += 1
		if credits_phase_counter == 50:
			main_menu_button.set_visible(true)
			replay_button.set_visible(true)
	# frame_factor intentionally still refers to the previous reanim on a phase switch, as in the original.

	if credits_phase == CREDITS_MAIN1:
		if _trigger_any(frame_factor, [128.0, 130.0, 132.0, 134.0, 136.0, 138.0, 140.0, 142.0]):
			_add_center_particle(PvZ.PARTICLE_CREDIT_STROBE)
		if r.should_trigger_timed_event(frame_factor * 136.5):
			_add_center_particle(PvZ.PARTICLE_CREDITS_RAYSWIPE)
		if r.should_trigger_timed_event(frame_factor * 330.0):
			App.play_foley(PvZ.FOLEY_SCREAM)
		if r.should_trigger_timed_event(frame_factor * 336.0):
			App.sound_system.stop_foley(PvZ.FOLEY_SCREAM)

	if credits_phase == CREDITS_MAIN2 or credits_phase == CREDITS_MAIN3:
		var words1 := r.get_track_instance("Words")
		var words2 := r.get_track_instance("Words2")
		var word_color := Color.BLACK if r.anim_time < frame_factor * 124.0 else Color.WHITE
		words1.track_color = word_color
		words2.track_color = word_color
		var undead := find_sub_reanim(r, PvZ.REANIM_CREDITS_WEARETHEUNDEAD)
		if undead:
			for bubble in ["bubbletext1", "bubbletext2", "bubbletext3"]:
				undead.get_track_instance(bubble).track_color = Color.BLACK
			undead.set_shake_override("ShakyText", 2.0 if r.anim_time > frame_factor * 112.0 else 0.0)
		if r.should_trigger_timed_event(frame_factor * 120.0):
			_add_center_particle(PvZ.PARTICLE_CREDITS_ZOMBIEHEADWIPE)

	if credits_phase == CREDITS_MAIN2:
		var strobes: Array = [111.5, 115.5, 119.5, 121.5, 123.5, 125.5, 127.5]
		var f := 131.5
		while f <= 243.5:
			strobes.append(f)
			f += 4.0
		if _trigger_any(frame_factor, strobes):
			_add_center_particle(PvZ.PARTICLE_CREDIT_STROBE)
		if r.should_trigger_timed_event(frame_factor * 332.75):
			App.add_tod_particle(678.0 + PvZ.BOARD_ADDITIONAL_WIDTH, 352.0 + PvZ.BOARD_OFFSET_Y, PvZ.RENDER_LAYER_TOP, PvZ.PARTICLE_MELONSPLASH)
		if r.should_trigger_timed_event(frame_factor * 336.0):
			for ps in EffectSystem.particle_systems.duplicate():
				if ps.effect_type == PvZ.PARTICLE_MELONSPLASH:
					ps.particle_system_die()
		if r.should_trigger_timed_event(frame_factor * 342.0):
			_add_center_particle(PvZ.PARTICLE_CREDIT_STROBE)

		var fog_pos_x := _transform("Background2").tx + 856.0
		if r.should_trigger_timed_event(frame_factor * 188.0):
			fog_particle = App.add_tod_particle(fog_pos_x, 230.0, PvZ.RENDER_LAYER_TOP, PvZ.PARTICLE_CREDITS_FOG)
		if fog_particle and not fog_particle.dead:
			if r.should_trigger_timed_event(frame_factor * 248.0):
				fog_particle.particle_system_die()
				fog_particle = null
			else:
				fog_particle.system_move(fog_pos_x, 230.0)

	if credits_phase == CREDITS_MAIN3:
		if r.should_trigger_timed_event(frame_factor * 65.0):
			App.play_foley(PvZ.FOLEY_DOLPHIN_APPEARS)
		if _trigger_any(frame_factor, [111.0, 115.0, 119.0, 121.0, 123.0, 219.0, 223.0, 227.0, 231.0, 235.0, 239.0, 243.0, 247.0]):
			_add_center_particle(PvZ.PARTICLE_CREDIT_STROBE)

	var timing := get_timing()
	var before = timing[0]
	var after = timing[1]
	var fraction: float = timing[2]
	var sunflower_frame := 0
	draw_brain = false
	if before != null and after != null:
		match after[T_BRAIN]:
			BRAIN_FLY_ON:
				brain_pos_x = Tod.animate_curve_float_time(0.0, 1.0, fraction, -50.0, after[T_WORD_X] - 15.0, Tod.CURVE_EASE_IN_OUT)
				brain_pos_y = Tod.animate_curve_float_time(0.0, 1.0, fraction, 505.0, 485.0, Tod.CURVE_BOUNCE_FAST_MIDDLE)
				draw_brain = true
			BRAIN_FAST_ON:
				brain_pos_x = Tod.animate_curve_float_time(0.0, 1.0, fraction, after[T_WORD_X] - 50.0, after[T_WORD_X] - 15.0, Tod.CURVE_EASE_IN_OUT)
				brain_pos_y = Tod.animate_curve_float_time(0.0, 1.0, fraction, 485.0, 505.0, Tod.CURVE_EASE_IN_OUT)
				draw_brain = true
			BRAIN_FLY_OFF:
				brain_pos_x = Tod.animate_curve_float_time(0.0, 1.0, fraction, before[T_WORD_X] - 15.0, 850.0, Tod.CURVE_EASE_IN_OUT)
				brain_pos_y = Tod.animate_curve_float_time(0.0, 1.0, fraction, 505.0, 485.0, Tod.CURVE_BOUNCE_FAST_MIDDLE)
				draw_brain = true
			BRAIN_FAST_OFF:
				brain_pos_x = Tod.animate_curve_float_time(0.0, 1.0, fraction, before[T_WORD_X] - 15.0, before[T_WORD_X] + 25.0, Tod.CURVE_EASE_IN_OUT)
				brain_pos_y = Tod.animate_curve_float_time(0.0, 1.0, fraction, 505.0, 485.0, Tod.CURVE_EASE_IN_OUT)
				draw_brain = true
			_:
				if before[T_BRAIN] in [BRAIN_FLY_ON, BRAIN_FAST_ON, BRAIN_NEXT_WORD]:
					brain_pos_x = Tod.animate_curve_float_time(0.0, 1.0, fraction, before[T_WORD_X] - 15.0, after[T_WORD_X] - 15.0, Tod.CURVE_EASE_IN_OUT)
					brain_pos_y = Tod.animate_curve_float_time(0.0, 1.0, fraction, 505.0, 485.0, Tod.CURVE_BOUNCE_FAST_MIDDLE)
					draw_brain = true

		var frames_for_word: float = after[T_FRAME] - before[T_FRAME]
		var frames_till_end := (1.0 - fraction) * frames_for_word
		if before[T_WORD] != WORD_OFF and frames_for_word * fraction < 0.2:
			sunflower_frame = 1
		elif before[T_WORD] != WORD_OFF and frames_till_end < 0.4:
			sunflower_frame = 1
		else:
			match before[T_WORD]:
				WORD_AA: sunflower_frame = 2
				WORD_EE: sunflower_frame = 3
				WORD_AW: sunflower_frame = 4
				WORD_OH: sunflower_frame = 5

	var sunflower := find_sub_reanim(r, PvZ.REANIM_SUNFLOWER)
	if sunflower:
		if credits_phase == CREDITS_MAIN3 and r.anim_time > frame_factor * 255.0:
			sunflower.set_image_override("anim_idle", Res.get_image("IMAGE_REANIM_SUNFLOWER_HEAD_WINK"))
			var stage := find_sub_reanim(r, PvZ.REANIM_CREDITS_STAGE)
			sunflower.anim_time -= sunflower.anim_rate * SECONDS_PER_UPDATE / sunflower.frame_count
			if stage:
				stage.anim_time -= stage.anim_rate * SECONDS_PER_UPDATE / stage.frame_count
		else:
			var head: PvzImage = null
			if sunflower_frame >= 1:
				head = Res.get_image("IMAGE_REANIM_SUNFLOWER_HEAD_SING%d" % sunflower_frame)
			sunflower.set_image_override("anim_idle", head)

func turn_off_tongues(reanim: Reanimation, parent_track: int) -> void:
	if reanim.definition == null:
		return
	for i in reanim.definition.tracks.size():
		var ti: Reanimation.TrackInstance = reanim.track_instances[i]
		if reanim.reanim_type == PvZ.REANIM_ZOMBIE_CREDITS_DANCE and parent_track % 4 != 1 \
				and (reanim.definition.tracks[i] as Defs.ReanimTrackDef).name.to_lower() == "anim_tongue":
			ti.render_group = Reanimation.RENDER_GROUP_HIDDEN
		var attached := Attachment.find_reanim_attachment(ti)
		if attached:
			turn_off_tongues(attached, i)

## [phase, frame >=, byte base offset, extra milliseconds] rows for the song seek in JumpToFrame.
const MUSIC_SEEK_TABLE := {
	CREDITS_MAIN1: [[368.0, 4634474.0, 0], [340.0, 4280738.0, 0], [304.0, 3825710.0, 0], [272.0, 3421764.0, 0], [144.0, 1805688.0, 0], [128.0, 1603662.0, 0]],
	CREDITS_MAIN2: [[320.0, 9069118.0, 57142], [248.0, 8159850.0, 57142], [188.0, 7401454.0, 57142], [124.0, 6593548.0, 57142], [0.0, 5026370.0, 57142]],
	CREDITS_MAIN3: [[240.0, 12897822.0, 112000], [216.0, 12594510.0, 112000], [124.0, 11434414.0, 112000], [0.0, 9864866.0, 112000]],
}

func jump_to_frame(phase: int, frame: float) -> void:
	main_menu_button.set_visible(false)
	replay_button.set_visible(false)
	credits_phase_counter = 0
	EffectSystem.free_all()
	var r := play_reanim(3 if phase == CREDITS_END else phase + 1)
	var frame_factor := 1.0 / (_transform_count() - 1)
	var music_offset := int(frame * 12142.0)
	var jump_ms := int(frame * 1000.0 / 7.0)
	if phase == CREDITS_END:
		music_offset = 14047138
		jump_ms += 159142
	else:
		for row in MUSIC_SEEK_TABLE[phase]:
			if frame >= row[0]:
				music_offset = int(12142.0 * (frame - row[0]) + row[1])
				jump_ms += row[2]
				break
	App.music.play_from_offset(Music.MUSIC_FILE_CREDITS_ZOMBIES_ON_YOUR_LAWN, music_offset - 900, 1.0)
	r.anim_time = 1.0 if phase == CREDITS_END else frame_factor * frame
	credits_phase = phase
	_set_timer_start(jump_ms)

const DEBUG_JUMPS := {
	"1": [CREDITS_MAIN1, 0.0], "2": [CREDITS_MAIN1, 128.0], "3": [CREDITS_MAIN1, 144.0], "4": [CREDITS_MAIN1, 272.0],
	"5": [CREDITS_MAIN1, 304.0], "6": [CREDITS_MAIN1, 340.0], "7": [CREDITS_MAIN1, 368.0],
	"q": [CREDITS_MAIN2, 0.0], "w": [CREDITS_MAIN2, 124.0], "e": [CREDITS_MAIN2, 188.0], "r": [CREDITS_MAIN2, 248.0], "t": [CREDITS_MAIN2, 320.0],
	"a": [CREDITS_MAIN3, 0.0], "s": [CREDITS_MAIN3, 124.0], "d": [CREDITS_MAIN3, 216.0], "f": [CREDITS_MAIN3, 240.0], "g": [CREDITS_MAIN3, 324.0],
}

func key_char(ch: String) -> void:
	if credits_paused or not App.tod_cheat_keys:
		return
	if DEBUG_JUMPS.has(ch):
		jump_to_frame(DEBUG_JUMPS[ch][0], DEBUG_JUMPS[ch][1])
	elif ch == "n":
		dont_sync = not dont_sync

func pause_credits() -> void:
	if credits_paused:
		return
	App.sound_system.stop_foley(PvZ.FOLEY_SCREAM)
	App.play_sample("SOUND_PAUSE")
	credits_paused = true
	var duration_on_pause := _timer_duration()
	App.music.game_music_pause(true)
	var result: int = await App.lawn_message_box(PvZ.DIALOG_MESSAGE, "[CREDITS_PAUSE_HEADER]", "[CREDITS_PAUSE_BODY]",
		"[CREDITS_RESUME_BUTTON]", "[MAIN_MENU_BUTTON]", Dialog.BUTTONS_YES_NO)
	if result == Dialog.ID_NO:
		App.kill_credit_screen()
		App.do_back_to_main()
	credits_paused = false
	App.music.game_music_pause(false)
	_set_timer_start(duration_on_pause)

func key_down(key: int) -> void:
	if credits_paused:
		return
	if key == WidgetManager.KEYCODE_SPACE or key == WidgetManager.KEYCODE_RETURN or key == WidgetManager.KEYCODE_ESCAPE:
		pause_credits()

func button_press(bid: int, _count: int = 1) -> void:
	if bid == CREDITS_BUTTON_MAIN_MENU:
		App.play_sample("SOUND_GRAVEBUTTON")
	elif bid == CREDITS_BUTTON_REPLAY:
		App.play_sample("SOUND_TAP")

func button_depress(bid: int) -> void:
	if bid == CREDITS_BUTTON_MAIN_MENU:
		App.kill_credit_screen()
		App.do_back_to_main()
	elif bid == CREDITS_BUTTON_REPLAY:
		App.kill_credit_screen()
		App.show_credit_screen()

func mouse_up(_mx: int, _my: int, _count: int) -> void:
	pass
