class_name QuickPlayScreen
extends Widget
## Port of QuickPlayScreen (QE: replay any adventure level).

const LEVELS_PER_AREA := 10
const FINAL_LEVEL := 50
const NUM_LEVELS := 50

var back_button: NewLawnButton
var left_button: NewLawnButton
var right_button: NewLawnButton
var play_button: LawnStoneButton
var background := PvZ.BACKGROUND_1_DAY
var zombie_type := PvZ.ZOMBIE_NORMAL
var seed_type := PvZ.SEED_PEASHOOTER
var display_zombie: Zombie = null
var display_plant: Plant = null
var flower_pot: Plant = null
var hammer_reanim: Reanimation = null
var crazy_seeds_check: Checkbox

func _init() -> void:
	back_button = LawnButtons.make_new_button(0, self, "", null, Res.get_image("IMAGE_BLANK"),
		Res.get_image("IMAGE_QUICKPLAY_BACK_HIGHLIGHT"), Res.get_image("IMAGE_QUICKPLAY_BACK_HIGHLIGHT"))
	left_button = LawnButtons.make_new_button(1, self, "", null, Res.get_image("IMAGE_QUICKPLAY_LEFT_BUTTON"),
		Res.get_image("IMAGE_QUICKPLAY_LEFT_BUTTON_HIGHLIGHT"), Res.get_image("IMAGE_QUICKPLAY_LEFT_BUTTON_HIGHLIGHT"))
	right_button = LawnButtons.make_new_button(2, self, "", null, Res.get_image("IMAGE_QUICKPLAY_RIGHT_BUTTON"),
		Res.get_image("IMAGE_QUICKPLAY_RIGHT_BUTTON_HIGHLIGHT"), Res.get_image("IMAGE_QUICKPLAY_RIGHT_BUTTON_HIGHLIGHT"))
	play_button = LawnButtons.make_button(3, self, "[PLAY_BUTTON]")
	crazy_seeds_check = LawnButtons.make_new_checkbox(4, self, App.crazy_seeds)
	crazy_seeds_check.visible = true

	display_zombie = _new_display_zombie()
	display_plant = _new_display_plant(seed_type)
	flower_pot = _new_display_plant(PvZ.SEED_FLOWERPOT)

	hammer_reanim = App.add_reanimation(250.0 + PvZ.BOARD_ADDITIONAL_WIDTH, 280.0, 0, PvZ.REANIM_HAMMER)
	hammer_reanim.is_attachment = true
	hammer_reanim.play_reanim("anim_whack_zombie", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 24.0)
	hammer_reanim.anim_time = 1.0

	var bh := Res.get_image("IMAGE_QUICKPLAY_BACK_HIGHLIGHT")
	var lb := Res.get_image("IMAGE_QUICKPLAY_LEFT_BUTTON")
	var rb := Res.get_image("IMAGE_QUICKPLAY_RIGHT_BUTTON")
	back_button.resize(372, 533, bh.width, bh.height)
	left_button.resize(373 + PvZ.BOARD_ADDITIONAL_WIDTH, 380, lb.width, lb.height)
	play_button.resize(left_button.x + left_button.width + 20, left_button.y, 163, 46)
	right_button.resize(play_button.x + play_button.width + 20, play_button.y, rb.width, rb.height)
	crazy_seeds_check.resize(130 + PvZ.BOARD_ADDITIONAL_WIDTH, right_button.y + 2, 50, 50)

	choose_background()
	reset_zombie()
	reset_plant()

func _new_display_zombie() -> Zombie:
	var z := Zombie.new()
	z.board = null
	z.zombie_initialize(0, zombie_type, false, null, Zombie.ZOMBIE_WAVE_UI)
	return z

func _new_display_plant(st: int) -> Plant:
	var p := Plant.new()
	p.is_on_board = false
	p.plant_initialize(0, 0, st, PvZ.SEED_NONE)
	return p

func draw(g: Graphics) -> void:
	g.draw_image(Res.get_image("IMAGE_QUICKPLAY_BACKGROUND"), 0, -42)
	var cg := g.copy()
	cg.set_clip_rect(130 + PvZ.BOARD_ADDITIONAL_WIDTH, 30, 530, 370)
	match background:
		PvZ.BACKGROUND_1_DAY: cg.draw_image(Res.get_image("IMAGE_BACKGROUND1"), -130, -PvZ.BOARD_OFFSET_Y)
		PvZ.BACKGROUND_2_NIGHT: cg.draw_image(Res.get_image("IMAGE_BACKGROUND2"), -130, -PvZ.BOARD_OFFSET_Y)
		PvZ.BACKGROUND_3_POOL:
			cg.draw_image(Res.get_image("IMAGE_BACKGROUND3"), -130, -PvZ.BOARD_OFFSET_Y)
			draw_pool(cg, false)
		PvZ.BACKGROUND_4_FOG:
			cg.draw_image(Res.get_image("IMAGE_BACKGROUND4"), -130, -PvZ.BOARD_OFFSET_Y)
			draw_pool(cg, true)
		PvZ.BACKGROUND_5_ROOF: cg.draw_image(Res.get_image("IMAGE_BACKGROUND5"), -130, -PvZ.BOARD_OFFSET_Y)
		PvZ.BACKGROUND_6_BOSS: cg.draw_image(Res.get_image("IMAGE_BACKGROUND6BOSS"), -130, -PvZ.BOARD_OFFSET_Y)

	if display_zombie and App.quick_level != 35:
		var zg := cg.copy()
		if App.quick_level == 25:
			display_zombie.scale_zombie = 0.5
		display_zombie.pos_x = 340 + PvZ.BOARD_ADDITIONAL_WIDTH
		display_zombie.pos_y = 240
		if background == PvZ.BACKGROUND_3_POOL or background == PvZ.BACKGROUND_4_FOG:
			display_zombie.pos_y -= 120
		if zombie_type == PvZ.ZOMBIE_BOSS:
			display_zombie.pos_x = -100 + PvZ.BOARD_ADDITIONAL_WIDTH
			display_zombie.pos_y = -20
		if display_zombie.begin_draw(zg):
			if zombie_type not in [PvZ.ZOMBIE_BUNGEE, PvZ.ZOMBIE_BOSS, PvZ.ZOMBIE_ZAMBONI, PvZ.ZOMBIE_CATAPULT]:
				display_zombie.draw_shadow(zg)
			display_zombie.draw(zg)
			display_zombie.end_draw(zg)

	if flower_pot and (background == PvZ.BACKGROUND_5_ROOF or background == PvZ.BACKGROUND_6_BOSS):
		var pg := cg.copy()
		flower_pot.x = 280 + PvZ.BOARD_ADDITIONAL_WIDTH
		flower_pot.y = 280
		if flower_pot.begin_draw(pg):
			flower_pot.draw(pg)
			flower_pot.end_draw(pg)

	if display_plant and App.quick_level != 35 and App.quick_level != 15:
		var pg := cg.copy()
		display_plant.x = 280 + PvZ.BOARD_ADDITIONAL_WIDTH
		display_plant.y = 280
		if (background == PvZ.BACKGROUND_3_POOL or background == PvZ.BACKGROUND_4_FOG) and not Plant.is_aquatic(display_plant.seed_type):
			display_plant.y -= 120
		if background == PvZ.BACKGROUND_5_ROOF or background == PvZ.BACKGROUND_6_BOSS:
			display_plant.y -= 10
		if display_plant.begin_draw(pg):
			display_plant.draw(pg)
			display_plant.end_draw(pg)

	if App.quick_level == 5:
		cg.draw_image(Res.get_image("IMAGE_WALLNUT_BOWLINGSTRIPE"), 268 + PvZ.BOARD_ADDITIONAL_WIDTH, 77)
	if App.quick_level == 15 and hammer_reanim:
		hammer_reanim.draw(cg)
	if App.quick_level == 35:
		cg.draw_image_cel_rc(Res.get_image("IMAGE_SCARY_POT"), 370 + PvZ.BOARD_ADDITIONAL_WIDTH, 270, 0, 1)
		cg.draw_image_cel_rc(Res.get_image("IMAGE_SCARY_POT"), 290 + PvZ.BOARD_ADDITIONAL_WIDTH, 270, 1, 1)

	var pos_x := 100 + PvZ.BOARD_ADDITIONAL_WIDTH
	var widget_img := Res.get_image("IMAGE_QUICKPLAY_WIDGET")
	g.draw_image(widget_img, pos_x, 0)
	var font := Res.get_font("FONT_DWARVENTODCRAFT18GREENINSET")
	TodStrings.draw_string(g, App.get_stage_string(App.quick_level).substr(1), pos_x + Tod.idiv(widget_img.width, 2), 30, font, Color.WHITE, PvZ.DS_ALIGN_CENTER)
	TodStrings.draw_string(g, TodStrings.translate("[CRAZY_DAVE_SEEDS]"), crazy_seeds_check.x + 45, crazy_seeds_check.y + 23, font, Color.WHITE, PvZ.DS_ALIGN_LEFT)

func key_down(key: int) -> void:
	if App.widget_manager.focus_widget != self:
		return
	match key:
		WidgetManager.KEYCODE_ESCAPE: exit_screen()
		WidgetManager.KEYCODE_LEFT: previous_level()
		WidgetManager.KEYCODE_RIGHT: next_level()
		WidgetManager.KEYCODE_RETURN: start_level()

func draw_pool(g: Graphics, is_night: bool) -> void:
	var pg := g.copy()
	pg.set_clip_rect(135 + PvZ.BOARD_ADDITIONAL_WIDTH - x, 30, 450, 370)
	pg.trans_x += PvZ.BOARD_ADDITIONAL_WIDTH / 2 + 12
	App.pool_effect.pool_effect_draw(pg, is_night)

func choose_background() -> void:
	var lvl := App.quick_level
	if lvl == 35:
		background = PvZ.BACKGROUND_2_NIGHT
	elif lvl <= 1 * LEVELS_PER_AREA:
		background = PvZ.BACKGROUND_1_DAY
	elif lvl <= 2 * LEVELS_PER_AREA:
		background = PvZ.BACKGROUND_2_NIGHT
	elif lvl <= 3 * LEVELS_PER_AREA:
		background = PvZ.BACKGROUND_3_POOL
	elif lvl <= 4 * LEVELS_PER_AREA:
		background = PvZ.BACKGROUND_4_FOG
	elif lvl < FINAL_LEVEL:
		background = PvZ.BACKGROUND_5_ROOF
	elif lvl == FINAL_LEVEL:
		background = PvZ.BACKGROUND_6_BOSS
	else:
		background = PvZ.BACKGROUND_1_DAY

func choose_zombie_type() -> void:
	if App.quick_level == 45:
		zombie_type = PvZ.ZOMBIE_BUNGEE
		return
	for i in PvZ.NUM_ZOMBIE_TYPES:
		var def := LawnCommon.zombie_def(i)
		if App.quick_level == def[LawnCommon.ZDEF_STARTING_LEVEL]:
			zombie_type = def[LawnCommon.ZDEF_TYPE]
			break
		else:
			zombie_type = PvZ.ZOMBIE_NORMAL

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	for w in [back_button, left_button, right_button, play_button, crazy_seeds_check]:
		add_widget(w)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	for w in [back_button, left_button, right_button, play_button, crazy_seeds_check]:
		remove_widget(w)
	if hammer_reanim:
		hammer_reanim.die()
		hammer_reanim = null

func button_press(_bid: int, _count: int = 1) -> void:
	App.play_sample("SOUND_BUTTONCLICK")

func update() -> void:
	super.update()
	if hammer_reanim and not hammer_reanim.dead:
		hammer_reanim.update()
	App.pool_effect.pool_effect_update()
	if display_zombie:
		display_zombie.update()
	if display_plant:
		display_plant.update()
	if flower_pot:
		flower_pot.update()

func button_depress(bid: int) -> void:
	match bid:
		0: exit_screen()
		1: previous_level()
		2: next_level()
		3: start_level()

func checkbox_checked(_cid: int, _checked: bool) -> void:
	pass

func reset_zombie() -> void:
	choose_zombie_type()
	display_zombie = _new_display_zombie()

func reset_plant() -> void:
	var seed_level := App.quick_level - 1
	if App.quick_level % 10 == 0:
		seed_level -= 1
	if App.get_award_seed_for_level(App.quick_level - 1) == PvZ.SEED_FLOWERPOT:
		return
	var special := App.quick_level == 5 or App.quick_level == 25 or App.quick_level == 45
	var special_seed := PvZ.SEED_PEASHOOTER
	match App.quick_level:
		5: special_seed = PvZ.SEED_EXPLODE_O_NUT
		45: special_seed = PvZ.SEED_CHOMPER
	display_plant = _new_display_plant(special_seed if special else App.get_award_seed_for_level(seed_level))

func start_level() -> void:
	App.crazy_seeds = crazy_seeds_check.checked
	App.kill_game_selector()
	App.kill_quick_play_screen()
	App.start_quick_play()

func exit_screen() -> void:
	var gs: GameSelector = App.game_selector
	gs.movement_timer = 75
	gs.selector_state = GameSelector.SELECTOR_IDLE
	gs.destination_x = 0
	gs.enable_buttons_transition = true
	App.widget_manager.set_focus(gs)
	for b in [back_button, left_button, right_button, play_button]:
		b.set_disabled(true)

func previous_level() -> void:
	App.quick_level = clampi(App.quick_level - 1, 1, NUM_LEVELS)
	choose_background()
	reset_zombie()
	reset_plant()

func next_level() -> void:
	App.quick_level = clampi(App.quick_level + 1, 1, NUM_LEVELS)
	choose_background()
	reset_zombie()
	reset_plant()
