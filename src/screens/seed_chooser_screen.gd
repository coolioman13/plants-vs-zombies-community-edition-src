class_name SeedChooserScreen
extends Widget
## Port of SeedChooserScreen (choose your plants).

const SEED_CHOOSER_START := 100
const SEED_CHOOSER_RANDOM := 101
const SEED_CHOOSER_VIEW_LAWN := 102
const SEED_CHOOSER_ALMANAC := 103
const SEED_CHOOSER_MENU := 104
const SEED_CHOOSER_STORE := 105
const SEED_CHOOSER_IMITATER := 106
const SEED_CHOOSER_SCROLLBAR := 107

const SEED_CLIP_RECT := Rect2i(0, 123, PvZ.BOARD_WIDTH, 420 + PvZ.SEED_CHOOSER_EXTRA_HEIGHT)
const SEED_PACKET_Y_OFFSET := 2
const SEED_PACKET_ROWS := 8
const BASE_SCROLL_SPEED := 1.0
const SCROLL_ACCEL := 0.1

class ChosenSeed:
	var x := 0
	var y := 0
	var time_start_motion := 0
	var time_end_motion := 0
	var start_x := 0
	var start_y := 0
	var end_x := 0
	var end_y := 0
	var seed_type := PvZ.SEED_NONE
	var seed_state := PvZ.SEED_IN_CHOOSER
	var seed_index_in_bank := 0
	var refreshing := false
	var refresh_counter := 0
	var imitater_type := PvZ.SEED_NONE
	var crazy_dave_picked := false

var start_button: GameButton
var random_button: GameButton
var view_lawn_button: GameButton
var store_button: GameButton
var almanac_button: GameButton
var menu_button: GameButton
var chosen_seeds: Array = []
## Seed types on offer, in grid order, and where each one sits in that grid.
var chooser_seeds: Array = []
var chooser_slot: Dictionary = {}
var board: Board
var num_seeds_to_choose := 0
var seed_chooser_age := 0
var seeds_in_flight := 0
var seeds_in_bank := 0
var tool_tip: ToolTipWidget
var tool_tip_seed := -1
var last_mouse_x := -1
var last_mouse_y := -1
var choose_state := PvZ.CHOOSE_NORMAL
var view_lawn_time := 0
var scroll_position := 0.0
var scroll_amount := 0.0
var slider: SexySlider
var max_scroll_position := 0.0
var previous_type := PvZ.SEED_NONE

func _init() -> void:
	board = App.board
	clip = false
	tool_tip = ToolTipWidget.new()

	start_button = GameButton.new(SEED_CHOOSER_START)
	start_button.label = "[LETS_ROCK_BUTTON]"
	start_button.button_image = Res.get_image("IMAGE_SEEDCHOOSER_BUTTON")
	start_button.over_image = null
	start_button.down_image = null
	start_button.disabled_image = Res.get_image("IMAGE_SEEDCHOOSER_BUTTON_DISABLED")
	start_button.over_overlay_image = Res.get_image("IMAGE_SEEDCHOOSER_BUTTON_GLOW")
	start_button.set_font(Res.get_font("FONT_DWARVENTODCRAFT18YELLOW"))
	start_button.colors[GameButton.COLOR_LABEL] = Color.WHITE
	start_button.colors[GameButton.COLOR_LABEL_HILITE] = Color.WHITE
	start_button.resize(154, 545 + PvZ.SEED_CHOOSER_EXTRA_HEIGHT, 156, 42)
	start_button.text_offset_y = -1
	enable_start_button(false)
	start_button.parent_widget = self

	var button_offset_x := PvZ.BOARD_ADDITIONAL_WIDTH * 2
	menu_button = GameButton.new(SEED_CHOOSER_MENU)
	menu_button.label = "[MENU_BUTTON]"
	menu_button.draw_stone_button = true
	menu_button.resize(681 + button_offset_x, -10, 117, 46)
	menu_button.parent_widget = self

	random_button = GameButton.new(SEED_CHOOSER_RANDOM)
	random_button.label = "[DEBUG_PLAY_BUTTON]"
	random_button.button_image = Res.get_image("IMAGE_BLANK")
	random_button.over_image = Res.get_image("IMAGE_BLANK")
	random_button.down_image = Res.get_image("IMAGE_BLANK")
	random_button.set_font(Res.get_font("FONT_BRIANNETOD12"))
	random_button.colors[0] = Color8(255, 240, 0)
	random_button.colors[1] = Color8(200, 200, 255)
	random_button.resize(332, 555 + PvZ.SEED_CHOOSER_EXTRA_HEIGHT, 100, 30)
	random_button.parent_widget = self

	var btn_color := Color8(42, 42, 90)
	var btn_image := Res.get_image("IMAGE_SEEDCHOOSER_BUTTON2")
	var over_image := Res.get_image("IMAGE_SEEDCHOOSER_BUTTON2_GLOW")
	var image_w := btn_image.width
	var image_h := over_image.height

	view_lawn_button = _make_small_button(SEED_CHOOSER_VIEW_LAWN, "[VIEW_LAWN]", btn_image, over_image, btn_color)
	view_lawn_button.resize(22, 561 + PvZ.SEED_CHOOSER_EXTRA_HEIGHT, image_w, image_h)
	if not board.cut_scene.is_survival_repick():
		view_lawn_button.btn_no_draw = true
		view_lawn_button.disabled = true

	almanac_button = _make_small_button(SEED_CHOOSER_ALMANAC, "[ALMANAC_BUTTON]", btn_image, over_image, btn_color)
	almanac_button.resize(560 + button_offset_x, 572 + PvZ.SEED_CHOOSER_EXTRA_HEIGHT, image_w, image_h)

	store_button = _make_small_button(SEED_CHOOSER_STORE, "[SHOP_BUTTON]", btn_image, over_image, btn_color)
	store_button.resize(680 + button_offset_x, 572 + PvZ.SEED_CHOOSER_EXTRA_HEIGHT, image_w, image_h)

	if not App.can_show_almanac():
		almanac_button.btn_no_draw = true
		almanac_button.disabled = true
	if not App.can_show_store():
		store_button.btn_no_draw = true
		store_button.disabled = true

	_build_chooser_seeds()
	for st in chosen_seeds.size():
		var cs: ChosenSeed = chosen_seeds[st]
		var pos := get_seed_position_in_chooser(st)
		cs.x = pos.x
		cs.y = pos.y
		cs.start_x = cs.x
		cs.start_y = cs.y
		cs.end_x = cs.x
		cs.end_y = cs.y

	if board.cut_scene.is_survival_repick():
		for idx in board.seed_bank.num_packets:
			var packet: SeedPacket = board.seed_bank.seed_packets[idx]
			var cs: ChosenSeed = chosen_seeds[packet.packet_type]
			cs.refreshing = packet.refreshing
			cs.refresh_counter = packet.refresh_counter
		board.seed_bank.num_packets = 0

	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_SEEING_STARS:
		var star: ChosenSeed = chosen_seeds[PvZ.SEED_STARFRUIT]
		var sx := board.get_seed_packet_position_x(0)
		star.x = sx; star.y = 8
		star.start_x = sx; star.start_y = 8
		star.end_x = sx; star.end_y = 8
		star.seed_state = PvZ.SEED_IN_BANK
		star.seed_index_in_bank = 0
		seeds_in_bank += 1

	if (App.crazy_seeds and App.playing_quickplay) or (App.is_adventure_mode() and not App.is_first_time_adventure_mode() and not App.playing_quickplay):
		crazy_dave_pick_seeds()

	slider = SexySlider.new(Res.get_image("IMAGE_OPTIONS_SLIDERSLOT_PLANT"), Res.get_image("IMAGE_OPTIONS_SLIDERKNOB_PLANT"), 0, self)
	slider.set_value(maxf(0.0, minf(max_scroll_position, scroll_position)))
	slider.horizontal = false
	slider.thumb_offset_x = -14
	slider.no_draw = true
	resize_slider()

func _make_small_button(bid: int, text: String, img: PvzImage, over: PvzImage, col: Color) -> GameButton:
	var b := GameButton.new(bid)
	b.label = text
	b.button_image = img
	b.over_image = over
	b.down_image = null
	b.set_font(Res.get_font("FONT_BRIANNETOD12"))
	b.colors[0] = col
	b.colors[1] = col
	b.text_offset_y = 1
	b.parent_widget = self
	return b

## Uses the level RNG so Crazy Dave always picks the same seeds for a level.
static func pick_from_weighted_array_using_special_rand_seed(arr: Array, rng: RandomNumberGenerator) -> int:
	var total := 0
	for e in arr:
		total += e[1]
	if total <= 0:
		return arr[0][0]
	var r := rng.randi() % total
	var w := 0
	for e in arr:
		w += e[1]
		if w > r:
			return e[0]
	return arr[0][0]

## WIDETWEAK: fixes the seed packets Crazy Dave chooses so you won't end up with Lily Pad on roof levels (by BeeTeeKay).
func crazy_dave_pick_seeds() -> void:
	# stock range only: this runs in the tutorial levels, and the fix-ups below index arr by seed type
	var arr: Array = []
	for st in PvZ.NUM_SEEDS_IN_CHOOSER:
		var w := 1
		if (st == PvZ.SEED_GATLINGPEA and not App.player_info.purchases[PvZ.STORE_ITEM_PLANT_GATLINGPEA]) or not App.seed_type_available(st) \
				or seed_not_allowed_to_pick(st) or Plant.is_upgrade(st) or st == PvZ.SEED_IMITATER or st == PvZ.SEED_UMBRELLA \
				or st == PvZ.SEED_BLOVER or st == PvZ.SEED_GRAVEBUSTER or st == PvZ.SEED_PLANTERN or Plant.is_nocturnal(st) \
				or st == PvZ.SEED_FLOWERPOT or Plant.is_aquatic(st):
			w = 0
		if board.stage_is_night():
			if Plant.is_nocturnal(st) and not Plant.is_upgrade(st) and not Plant.is_aquatic(st):
				w = 1
		if board.stage_has_pool():
			if Plant.is_aquatic(st) and not Plant.is_upgrade(st) and not Plant.is_nocturnal(st):
				w = 1
			elif board.stage_is_night() and Plant.is_aquatic(st) and Plant.is_nocturnal(st) and not Plant.is_upgrade(st):
				w = 1
		arr.append([st, w])
	if board.stage_is_night():
		arr[PvZ.SEED_INSTANT_COFFEE][1] = 0
	if board.stage_has_grave_stones():
		arr[PvZ.SEED_GRAVEBUSTER][1] = 1
	if board.stage_has_fog():
		arr[PvZ.SEED_PLANTERN][1] = 1
	if board.zombie_allowed[PvZ.ZOMBIE_BALLOON] or board.stage_has_fog():
		arr[PvZ.SEED_BLOVER][1] = 1
	if board.stage_has_roof():
		arr[PvZ.SEED_TORCHWOOD][1] = 0
		arr[PvZ.SEED_SPIKEWEED][1] = 0
		arr[PvZ.SEED_FLOWERPOT][1] = 1
	if board.zombie_allowed[PvZ.ZOMBIE_BUNGEE] or board.zombie_allowed[PvZ.ZOMBIE_CATAPULT]:
		arr[PvZ.SEED_UMBRELLA][1] = 1

	var rng := RandomNumberGenerator.new()
	rng.seed = board.get_level_rand_seed()
	for i in 3:
		var picked := pick_from_weighted_array_using_special_rand_seed(arr, rng)
		arr[picked][1] = 0
		var cs: ChosenSeed = chosen_seeds[picked]
		var px := board.get_seed_packet_position_x(i)
		cs.x = px; cs.y = 8
		cs.start_x = px; cs.start_y = 8
		cs.end_x = px; cs.end_y = 8
		cs.seed_state = PvZ.SEED_IN_BANK
		cs.seed_index_in_bank = i
		cs.crazy_dave_picked = true
		seeds_in_bank += 1

func has_7_rows() -> bool:
	if App.has_finished_adventure() or App.player_info.purchases[PvZ.STORE_ITEM_PLANT_GATLINGPEA]:
		return true
	for st in range(PvZ.SEED_TWINSUNFLOWER, PvZ.SEED_COBCANNON):
		if st != PvZ.SEED_SPIKEROCK and App.seed_type_available(st):
			return true
	return false

## The seed types the chooser offers, in grid order: the stock 49, plus whatever plants the custom
## level being played defines. `chosen_seeds` stays indexed by seed type, so the extra entries sit
## past the stock ones and `chooser_seeds` says which of them are actually on screen.
func _build_chooser_seeds() -> void:
	chooser_seeds.clear()
	chooser_slot.clear()
	chosen_seeds.clear()
	for st in PvZ.NUM_SEEDS_IN_CHOOSER:
		chooser_seeds.append(st)
		chooser_slot[st] = st
	var customs: Array = CustomDefs.custom_plant_seed_types()
	# custom packets fill the grid cell the imitater vacates (it lives in its own add-on panel)
	var slot := PvZ.NUM_SEEDS_IN_CHOOSER - 1
	var highest: int = PvZ.NUM_SEEDS_IN_CHOOSER - 1
	for st in customs:
		chooser_seeds.append(int(st))
		chooser_slot[int(st)] = slot
		slot += 1
		highest = maxi(highest, int(st))
	for st in highest + 1:
		var cs := ChosenSeed.new()
		cs.seed_type = st
		cs.seed_state = PvZ.SEED_IN_CHOOSER
		chosen_seeds.append(cs)

func get_seed_position_in_chooser(index: int) -> Vector2i:
	if index == PvZ.SEED_IMITATER:
		return Vector2i(PvZ.IMITATER_POS_X + 5, PvZ.IMITATER_POS_Y + 12 + PvZ.SEED_CHOOSER_EXTRA_HEIGHT)
	var slot: int = chooser_slot.get(index, index)
	return Vector2i(slot % SEED_PACKET_ROWS * 53 + 22,
		int(slot / SEED_PACKET_ROWS * (PvZ.SEED_PACKET_HEIGHT + SEED_PACKET_Y_OFFSET) + (PvZ.SEED_PACKET_HEIGHT + 53) - scroll_position))

func get_seed_position_in_bank(index: int) -> Vector2i:
	return Vector2i(board.seed_bank.x - x + board.get_seed_packet_position_x(index), board.seed_bank.y - y + 8)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	remove_widget(slider)

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	add_widget(slider)

func seed_not_recommended_to_pick(st: int) -> int:
	var flags := board.seed_not_recommended_for_level(st)
	if Tod.test_bit(flags, PvZ.NOT_RECOMMENDED_NOCTURNAL) and picked_plant_type(PvZ.SEED_INSTANT_COFFEE):
		flags = Tod.set_bit(flags, PvZ.NOT_RECOMMENDED_NOCTURNAL, false)
	return flags

func seed_not_allowed_to_pick(st: int) -> bool:
	if CustomRuntime.active != null:
		return not CustomRuntime.active.seed_allowed(st)
	return App.game_mode == PvZ.GAMEMODE_CHALLENGE_LAST_STAND and st in [PvZ.SEED_SUNFLOWER, PvZ.SEED_SUNSHROOM, PvZ.SEED_TWINSUNFLOWER, PvZ.SEED_SEASHROOM, PvZ.SEED_PUFFSHROOM]

func seed_not_allowed_during_trial(st: int) -> bool:
	return App.is_trial_stage_locked() and (st == PvZ.SEED_SQUASH or st == PvZ.SEED_THREEPEATER)

func draw(g: Graphics) -> void:
	if App.get_dialog(PvZ.DIALOG_STORE) or App.get_dialog(PvZ.DIALOG_ALMANAC):
		return
	g.set_linear_blend(true)
	if not board.choose_seeds_on_current_level() or (board.cut_scene and board.cut_scene.is_before_preloading()):
		return

	g.draw_image(Res.get_image("IMAGE_SEEDCHOOSER_BACKGROUND"), 0, 87)
	if App.seed_type_available(PvZ.SEED_IMITATER):
		g.draw_image(Res.get_image("IMAGE_SEEDCHOOSER_IMITATERADDON"), PvZ.IMITATER_POS_X, PvZ.IMITATER_POS_Y + PvZ.SEED_CHOOSER_EXTRA_HEIGHT)

	TodStrings.draw_string(g, "[CHOOSE_YOUR_PLANTS]", 229, 110, Res.get_font("FONT_DWARVENTODCRAFT18YELLOW"), Color.WHITE, PvZ.DS_ALIGN_CENTER)
	slider.slider_draw(g)
	var silhouette := Res.get_image("IMAGE_SEEDPACKETSILHOUETTE")
	for st in chooser_seeds:
		var sg := g.copy()
		if st != PvZ.SEED_IMITATER:
			sg.set_clip_rect_r(Rect2(SEED_CLIP_RECT))
		var pos := get_seed_position_in_chooser(st)
		var cs: ChosenSeed = chosen_seeds[st]
		if App.seed_type_available(st):
			if cs.seed_state != PvZ.SEED_IN_CHOOSER:
				SeedPacket.draw_seed_packet(sg, pos.x, pos.y, st, PvZ.SEED_NONE, 0, 55, st != PvZ.SEED_IMITATER, false)
		elif st != PvZ.SEED_IMITATER:
			sg.draw_image(silhouette, pos.x, pos.y)

		var state := cs.seed_state
		if App.seed_type_available(st) and state != PvZ.SEED_FLYING_TO_BANK and state != PvZ.SEED_FLYING_TO_CHOOSER \
				and state != PvZ.SEED_PACKET_HIDDEN and (state == PvZ.SEED_IN_CHOOSER or board.cut_scene.seed_choosing):
			var grayed := ((seed_not_recommended_to_pick(st) != 0 or seed_not_allowed_to_pick(st) or is_imitater_unselectable(st)) and state == PvZ.SEED_IN_CHOOSER) or seed_not_allowed_during_trial(st)
			var px: int
			var py: int
			if state == PvZ.SEED_IN_CHOOSER:
				var p := get_seed_position_in_chooser(st)
				px = p.x
				py = p.y
			elif state == PvZ.SEED_IN_BANK:
				sg = g.copy()
				px = cs.x
				py = cs.y
			else:
				px = cs.x
				py = cs.y
			if choose_state != PvZ.CHOOSE_VIEW_LAWN or state == PvZ.SEED_IN_CHOOSER:
				SeedPacket.draw_seed_packet(sg, px, py, cs.seed_type, cs.imitater_type, 0, 115 if grayed else 255, st != PvZ.SEED_IMITATER or state != PvZ.SEED_IN_CHOOSER, false)

	for st in chooser_seeds:
		var cs: ChosenSeed = chosen_seeds[st]
		if App.seed_type_available(st) and (cs.seed_state == PvZ.SEED_FLYING_TO_BANK or cs.seed_state == PvZ.SEED_FLYING_TO_CHOOSER):
			SeedPacket.draw_seed_packet(g, cs.x, cs.y, cs.seed_type, cs.imitater_type, 0, 255, true, false)

	for idx in board.seed_bank.num_packets:
		if find_seed_in_bank(idx) == PvZ.SEED_NONE:
			var p := get_seed_position_in_bank(idx)
			g.draw_image(silhouette, p.x, p.y)

	start_button.draw(g)
	random_button.draw(g)
	view_lawn_button.draw(g)
	almanac_button.draw(g)
	store_button.draw(g)
	var frame_g := g.copy()
	frame_g.trans_x -= x
	frame_g.trans_y -= y
	menu_button.draw(frame_g)
	tool_tip.draw(g)

func update_view_lawn() -> void:
	if choose_state != PvZ.CHOOSE_VIEW_LAWN:
		return
	view_lawn_time += 1
	if view_lawn_time == 100:
		board.display_advice_again("[CLICK_TO_CONTINUE]", PvZ.MESSAGE_STYLE_HINT_STAY, PvZ.ADVICE_CLICK_TO_CONTINUE)
	elif view_lawn_time == 251:
		view_lawn_time = 250

	for idx in board.seed_bank.num_packets:
		var st := find_seed_in_bank(idx)
		if st == PvZ.SEED_NONE:
			break
		var cs: ChosenSeed = chosen_seeds[st]
		(board.seed_bank.seed_packets[idx] as SeedPacket).set_packet_type(st, cs.imitater_type)

	var chooser_y := PvZ.SEED_CHOOSER_OFFSET_Y - Res.get_image("IMAGE_SEEDCHOOSER_BACKGROUND").height - 87
	var street_offset := PvZ.BOARD_IMAGE_WIDTH_OFFSET + PvZ.BOARD_ADDITIONAL_WIDTH - PvZ.BOARD_WIDTH
	if view_lawn_time <= 100:
		board.roof_pole_offset = Tod.animate_curve(0, 100, view_lawn_time, PvZ.ROOF_POLE_END, PvZ.ROOF_POLE_START, Tod.CURVE_EASE_IN_OUT)
		board.roof_tree_offset = Tod.animate_curve(0, 100, view_lawn_time, PvZ.ROOF_TREE_END, PvZ.ROOF_TREE_START, Tod.CURVE_EASE_IN_OUT)
		board.move(-Tod.animate_curve(0, 100, view_lawn_time, street_offset, 0, Tod.CURVE_EASE_IN_OUT), 0)
		move(0, Tod.animate_curve(0, 40, view_lawn_time, chooser_y, PvZ.SEED_CHOOSER_OFFSET_Y, Tod.CURVE_EASE_IN_OUT))
	elif view_lawn_time <= 250:
		board.move(0, 0)
		move(0, PvZ.SEED_CHOOSER_OFFSET_Y)
	elif view_lawn_time <= 350:
		board.clear_advice(PvZ.ADVICE_CLICK_TO_CONTINUE)
		board.roof_pole_offset = Tod.animate_curve(250, 350, view_lawn_time, PvZ.ROOF_POLE_START, PvZ.ROOF_POLE_END, Tod.CURVE_EASE_IN_OUT)
		board.roof_tree_offset = Tod.animate_curve(250, 350, view_lawn_time, PvZ.ROOF_TREE_START, PvZ.ROOF_TREE_END, Tod.CURVE_EASE_IN_OUT)
		board.move(-Tod.animate_curve(250, 350, view_lawn_time, 0, street_offset, Tod.CURVE_EASE_IN_OUT), 0)
		move(0, Tod.animate_curve(310, 350, view_lawn_time, PvZ.SEED_CHOOSER_OFFSET_Y, chooser_y, Tod.CURVE_EASE_IN_OUT))
	else:
		choose_state = PvZ.CHOOSE_NORMAL
		view_lawn_time = 0
		menu_button.disabled = false
		for idx in board.seed_bank.num_packets:
			(board.seed_bank.seed_packets[idx] as SeedPacket).set_packet_type(PvZ.SEED_NONE, PvZ.SEED_NONE)

func land_flying_seed(cs: ChosenSeed) -> void:
	if cs.seed_state == PvZ.SEED_FLYING_TO_BANK:
		cs.x = cs.end_x
		cs.y = cs.end_y
		cs.time_start_motion = 0
		cs.time_end_motion = 0
		cs.seed_state = PvZ.SEED_IN_BANK
		seeds_in_flight -= 1
	elif cs.seed_state == PvZ.SEED_FLYING_TO_CHOOSER:
		cs.x = cs.end_x
		cs.y = cs.end_y
		cs.time_start_motion = 0
		cs.time_end_motion = 0
		cs.seed_state = PvZ.SEED_IN_CHOOSER
		seeds_in_flight -= 1
		if cs.seed_type == PvZ.SEED_IMITATER:
			cs.imitater_type = PvZ.SEED_NONE

func update_cursor() -> void:
	if App.get_dialog_count() > 0 or board.cut_scene.is_in_shovel_tutorial() or App.game_mode == PvZ.GAMEMODE_UPSELL or slider.is_over or slider.dragging:
		return
	var mouse_seed := seed_hit_test(last_mouse_x, last_mouse_y)
	if mouse_seed != PvZ.SEED_NONE:
		if is_imitater_unselectable(mouse_seed):
			mouse_seed = PvZ.SEED_NONE
		else:
			var cs: ChosenSeed = chosen_seeds[mouse_seed]
			if cs.seed_state == PvZ.SEED_IN_BANK and cs.crazy_dave_picked:
				mouse_seed = PvZ.SEED_NONE
	if mouse_visible and choose_state != PvZ.CHOOSE_VIEW_LAWN and ((zombie_hit_test(last_mouse_x, last_mouse_y) and App.can_show_almanac() and not is_over_imitater(last_mouse_x, last_mouse_y)) \
			or (mouse_seed != PvZ.SEED_NONE and not seed_not_allowed_to_pick(mouse_seed)) or random_button.is_mouse_over() \
			or view_lawn_button.is_mouse_over() or almanac_button.is_mouse_over() or store_button.is_mouse_over() \
			or menu_button.is_mouse_over() or start_button.is_mouse_over()):
		App.set_cursor(App.CURSOR_HAND)
	else:
		App.set_cursor(App.CURSOR_POINTER)

func update() -> void:
	super.update()
	random_button.btn_no_draw = not App.tod_cheat_keys
	random_button.disabled = not App.tod_cheat_keys
	max_scroll_position = maxf(0, int((chooser_seeds.size() - 2) / SEED_PACKET_ROWS) * (PvZ.SEED_PACKET_HEIGHT + SEED_PACKET_Y_OFFSET) + PvZ.SEED_PACKET_HEIGHT - SEED_CLIP_RECT.size.y)
	slider.visible = max_scroll_position != 0
	if slider.visible:
		scroll_position = clampf(scroll_position + scroll_amount * (BASE_SCROLL_SPEED + absf(scroll_amount) * SCROLL_ACCEL), 0, max_scroll_position)
		scroll_amount *= (1.0 - SCROLL_ACCEL)
		slider.set_value(maxf(0.0, minf(max_scroll_position, scroll_position)) / max_scroll_position)
	else:
		scroll_position = 0
		scroll_amount = 0

	last_mouse_x = App.widget_manager.last_mouse_x
	last_mouse_y = App.widget_manager.last_mouse_y

	seed_chooser_age += 1
	tool_tip.update()

	for st in chooser_seeds:
		if App.seed_type_available(st):
			var cs: ChosenSeed = chosen_seeds[st]
			if cs.seed_state == PvZ.SEED_FLYING_TO_BANK:
				cs.x = Tod.animate_curve(cs.time_start_motion, cs.time_end_motion, seed_chooser_age, cs.start_x, cs.end_x, Tod.CURVE_EASE_IN_OUT)
				cs.y = Tod.animate_curve(cs.time_start_motion, cs.time_end_motion, seed_chooser_age, cs.start_y, cs.end_y, Tod.CURVE_EASE_IN_OUT)
				if seed_chooser_age >= cs.time_end_motion:
					land_flying_seed(cs)

	show_tool_tip()
	start_button.update()
	random_button.update()
	view_lawn_button.update()
	almanac_button.update()
	store_button.update()
	menu_button.update()
	update_view_lawn()
	update_cursor()

func mouse_wheel(delta: int) -> bool:
	if choose_state != PvZ.CHOOSE_NORMAL:
		return true
	scroll_amount -= BASE_SCROLL_SPEED * delta
	scroll_amount -= scroll_amount * SCROLL_ACCEL
	return true

func display_repick_warning_dialog(message: String) -> bool:
	return await App.lawn_message_box(PvZ.DIALOG_CHOOSER_WARNING, "[DIALOG_WARNING]", message, "[DIALOG_BUTTON_YES]", "[REPICK_BUTTON]", Dialog.BUTTONS_YES_NO) == Dialog.ID_YES

func flyers_are_comming() -> bool:
	for wave in board.num_waves:
		for idx in BoardCore.MAX_ZOMBIES_IN_WAVE:
			var zt: int = board.zombies_in_wave[wave][idx]
			if zt == PvZ.ZOMBIE_INVALID:
				break
			if zt == PvZ.ZOMBIE_BALLOON:
				return true
	return false

func fly_protection_currently_planted() -> bool:
	for p in board.plants:
		if not p.dead and (p.seed_type == PvZ.SEED_CATTAIL or p.seed_type == PvZ.SEED_CACTUS):
			return true
	return false

func check_seed_upgrade(to: int, from: int) -> bool:
	if App.is_survival_mode() or not picked_plant_type(to) or picked_plant_type(from):
		return true
	var warning := TodStrings.translate("[SEED_CHOOSER_UPGRADE_WARNING]")
	warning = Tod.replace_string(warning, "{UPGRADE_TO}", Plant.get_name_string(to))
	warning = Tod.replace_string(warning, "{UPGRADE_FROM}", Plant.get_name_string(from))
	return await display_repick_warning_dialog(warning)

func on_start_button() -> void:
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_SEEING_STARS and not picked_plant_type(PvZ.SEED_STARFRUIT):
		if not await display_repick_warning_dialog("[SEED_CHOOSER_SEEING_STARS_WARNING]"):
			return
	if App.is_first_time_adventure_mode() and board.level == 11 and not picked_plant_type(PvZ.SEED_PUFFSHROOM):
		if not await display_repick_warning_dialog("[SEED_CHOOSER_PUFFSHROOM_WARNING]"):
			return
	if not picked_plant_type(PvZ.SEED_SUNFLOWER) and not picked_plant_type(PvZ.SEED_TWINSUNFLOWER) and not picked_plant_type(PvZ.SEED_SUNSHROOM) \
			and not board.cut_scene.is_survival_repick() and App.game_mode != PvZ.GAMEMODE_CHALLENGE_LAST_STAND:
		if App.is_first_time_adventure_mode() and board.level == 11:
			if not await display_repick_warning_dialog("[SEED_CHOOSER_NIGHT_SUN_WARNING]"):
				return
		elif not await display_repick_warning_dialog("[SEED_CHOOSER_SUN_WARNING]"):
			return
	if board.stage_has_pool() and not picked_plant_type(PvZ.SEED_LILYPAD) and not picked_plant_type(PvZ.SEED_SEASHROOM) \
			and not picked_plant_type(PvZ.SEED_TANGLEKELP) and not board.cut_scene.is_survival_repick():
		if App.is_first_time_adventure_mode() and board.level == 21:
			if not await display_repick_warning_dialog("[SEED_CHOOSER_LILY_WARNING]"):
				return
		elif not await display_repick_warning_dialog("[SEED_CHOOSER_POOL_WARNING]"):
			return
	if board.stage_has_roof() and not picked_plant_type(PvZ.SEED_FLOWERPOT) and App.seed_type_available(PvZ.SEED_FLOWERPOT):
		if not await display_repick_warning_dialog("[SEED_CHOOSER_ROOF_WARNING]"):
			return
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ART_CHALLENGE_WALLNUT and not picked_plant_type(PvZ.SEED_WALLNUT):
		if not await display_repick_warning_dialog("[SEED_CHOOSER_ART_WALLNUT_WARNING]"):
			return
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ART_CHALLENGE_SUNFLOWER and (not picked_plant_type(PvZ.SEED_STARFRUIT) or not picked_plant_type(PvZ.SEED_UMBRELLA) or not picked_plant_type(PvZ.SEED_WALLNUT)):
		if not await display_repick_warning_dialog("[SEED_CHOOSER_ART_2_WARNING]"):
			return
	if flyers_are_comming() and not fly_protection_currently_planted() and not picked_plant_type(PvZ.SEED_CATTAIL) and not picked_plant_type(PvZ.SEED_CACTUS) and not picked_plant_type(PvZ.SEED_BLOVER):
		if not await display_repick_warning_dialog("[SEED_CHOOSER_FLYER_WARNING]"):
			return
	for pair in [[PvZ.SEED_GATLINGPEA, PvZ.SEED_REPEATER], [PvZ.SEED_WINTERMELON, PvZ.SEED_MELONPULT], [PvZ.SEED_TWINSUNFLOWER, PvZ.SEED_SUNFLOWER],
			[PvZ.SEED_SPIKEROCK, PvZ.SEED_SPIKEWEED], [PvZ.SEED_COBCANNON, PvZ.SEED_KERNELPULT], [PvZ.SEED_GOLD_MAGNET, PvZ.SEED_MAGNETSHROOM],
			[PvZ.SEED_GLOOMSHROOM, PvZ.SEED_FUMESHROOM], [PvZ.SEED_CATTAIL, PvZ.SEED_LILYPAD]]:
		if not await check_seed_upgrade(pair[0], pair[1]):
			return
	close_seed_chooser()

func pick_random_seeds() -> void:
	for idx in range(seeds_in_bank, board.seed_bank.num_packets):
		var st := _random_pickable_seed()
		if st == PvZ.SEED_NONE:
			break
		var cs: ChosenSeed = chosen_seeds[st]
		cs.time_start_motion = 0
		cs.time_end_motion = 0
		cs.start_x = cs.x
		cs.start_y = cs.y
		var p := get_seed_position_in_bank(idx)
		cs.end_x = p.x
		cs.end_y = p.y
		cs.seed_state = PvZ.SEED_IN_BANK
		cs.seed_index_in_bank = idx
		seeds_in_bank += 1
	for cs in chosen_seeds:
		land_flying_seed(cs)
	close_seed_chooser()

## A custom level can forbid most of the tray and add plants of its own, so there the pick comes
## from what is actually on offer. Without one this keeps the stock draw, RNG sequence and all.
func _random_pickable_seed() -> int:
	if CustomRuntime.active == null:
		var st: int
		while true:
			st = Tod.rand_int(App.get_seeds_available())
			if App.seed_type_available(st) and st != PvZ.SEED_IMITATER and (chosen_seeds[st] as ChosenSeed).seed_state == PvZ.SEED_IN_CHOOSER:
				break
		return st
	var pool: Array = []
	for st in chooser_seeds:
		if st == PvZ.SEED_IMITATER or not App.seed_type_available(st):
			continue
		if seed_not_allowed_to_pick(st) or seed_not_recommended_to_pick(st) != 0:
			continue
		if (chosen_seeds[st] as ChosenSeed).seed_state != PvZ.SEED_IN_CHOOSER:
			continue
		pool.append(st)
	if pool.is_empty():
		return PvZ.SEED_NONE
	return int(pool[Tod.rand_int(pool.size())])

func button_depress(bid: int) -> void:
	if seeds_in_flight > 0 or choose_state == PvZ.CHOOSE_VIEW_LAWN or not mouse_visible:
		return
	if bid == SEED_CHOOSER_VIEW_LAWN:
		choose_state = PvZ.CHOOSE_VIEW_LAWN
		menu_button.disabled = true
		view_lawn_time = 0
	elif bid == SEED_CHOOSER_ALMANAC:
		var almanac := App.do_almanac_dialog()
		await almanac.wait_for_result(true)
		App.widget_manager.set_focus(self)
	elif bid == SEED_CHOOSER_STORE:
		var store := App.show_store_screen()
		store.back_button.label = "[STORE_BACK_TO_GAME]"
		await store.wait_for_result()
		if store.go_to_tree_now:
			App.kill_board()
			App.pre_new_game(PvZ.GAMEMODE_TREE_OF_WISDOM, false)
		else:
			App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_CHOOSE_YOUR_SEEDS)
			App.widget_manager.set_focus(self)
	elif bid == SEED_CHOOSER_MENU:
		menu_button.is_over = false
		menu_button.is_down = false
		update_cursor()
		App.do_new_options(false)
	elif App.get_seeds_available() >= board.seed_bank.num_packets:
		if bid == SEED_CHOOSER_START:
			on_start_button()
		elif bid == SEED_CHOOSER_RANDOM:
			pick_random_seeds()

func seed_hit_test(px: int, py: int) -> int:
	if mouse_visible:
		for st in chooser_seeds:
			var cs: ChosenSeed = chosen_seeds[st]
			if not App.seed_type_available(st) or cs.seed_state == PvZ.SEED_PACKET_HIDDEN:
				continue
			if cs.seed_state == PvZ.SEED_IN_CHOOSER:
				var r := Rect2i(cs.x, cs.y + (int(-scroll_position) if cs.seed_type != PvZ.SEED_IMITATER else 0), PvZ.SEED_PACKET_WIDTH, PvZ.SEED_PACKET_HEIGHT)
				if (SEED_CLIP_RECT.has_point(Vector2i(px, py)) if cs.seed_type != PvZ.SEED_IMITATER else true) and r.has_point(Vector2i(px, py)):
					return st
			elif Rect2i(cs.x, cs.y, PvZ.SEED_PACKET_WIDTH, PvZ.SEED_PACKET_HEIGHT).has_point(Vector2i(px, py)):
				return st
	return PvZ.SEED_NONE

func find_seed_in_bank(index: int) -> int:
	for st in chooser_seeds:
		if App.seed_type_available(st):
			var cs: ChosenSeed = chosen_seeds[st]
			if cs.seed_state == PvZ.SEED_IN_BANK and cs.seed_index_in_bank == index:
				return st
	return PvZ.SEED_NONE

func enable_start_button(enabled: bool) -> void:
	start_button.set_disabled(not enabled)
	start_button.colors[GameButton.COLOR_LABEL] = Color.WHITE if enabled else Color8(64, 64, 64)

func clicked_seed_in_bank(cs: ChosenSeed) -> void:
	previous_type = find_seed_in_bank(seeds_in_bank - (2 if cs.seed_index_in_bank == seeds_in_bank - 1 else 1))
	for idx in range(cs.seed_index_in_bank + 1, board.seed_bank.num_packets):
		var st := find_seed_in_bank(idx)
		if st != PvZ.SEED_NONE:
			var other: ChosenSeed = chosen_seeds[st]
			other.time_start_motion = seed_chooser_age
			other.time_end_motion = seed_chooser_age + 15
			other.start_x = other.x
			other.start_y = other.y
			var p := get_seed_position_in_bank(idx - 1)
			other.end_x = p.x
			other.end_y = p.y
			other.seed_state = PvZ.SEED_FLYING_TO_BANK
			other.seed_index_in_bank = idx - 1
			seeds_in_flight += 1
	var cp := get_seed_position_in_chooser(cs.seed_type)
	cs.x = cp.x
	cs.y = cp.y + (0 if cs.seed_type == PvZ.SEED_IMITATER else int(scroll_position))
	cs.seed_state = PvZ.SEED_IN_CHOOSER
	cs.imitater_type = PvZ.SEED_NONE
	cs.seed_index_in_bank = 0
	seeds_in_bank -= 1
	remove_tool_tip()
	enable_start_button(false)
	App.play_sample("SOUND_TAP")

func clicked_seed_in_chooser(cs: ChosenSeed) -> void:
	if seeds_in_bank == board.seed_bank.num_packets:
		return
	if is_imitater_unselectable(cs.seed_type):
		return
	if cs.seed_type == PvZ.SEED_IMITATER:
		cs.imitater_type = find_seed_in_bank(seeds_in_bank - 1)
	else:
		previous_type = cs.seed_type
	cs.time_start_motion = seed_chooser_age
	cs.time_end_motion = seed_chooser_age + 25
	cs.start_x = cs.x
	cs.start_y = cs.y - (0 if cs.seed_type == PvZ.SEED_IMITATER else int(scroll_position))
	var p := get_seed_position_in_bank(seeds_in_bank)
	cs.end_x = p.x
	cs.end_y = p.y
	cs.seed_state = PvZ.SEED_FLYING_TO_BANK
	cs.seed_index_in_bank = seeds_in_bank
	seeds_in_flight += 1
	seeds_in_bank += 1
	remove_tool_tip()
	App.play_sample("SOUND_TAP")
	if seeds_in_bank == board.seed_bank.num_packets:
		enable_start_button(true)

func show_tool_tip() -> void:
	if not App.widget_manager.mouse_in or not App.active or App.get_dialog_count() > 0 or choose_state == PvZ.CHOOSE_VIEW_LAWN:
		remove_tool_tip()
		return

	var zombie := zombie_hit_test(last_mouse_x, last_mouse_y)
	if zombie == null or zombie.from_wave != Zombie.ZOMBIE_WAVE_CUTSCENE:
		remove_tool_tip()
	elif not is_over_imitater(last_mouse_x, last_mouse_y):
		tool_tip.set_title("[%s]" % LawnCommon.zombie_def(zombie.zombie_type)[LawnCommon.ZDEF_NAME])
		tool_tip.set_label("[CLICK_TO_VIEW]" if App.can_show_almanac() else "")
		tool_tip.set_warning_text("")
		var r := zombie.get_zombie_rect()
		tool_tip.x = r.size.x / 2 + r.position.x + 5 + board.x
		tool_tip.y = r.size.y + r.position.y - 10 - board.y
		if zombie.zombie_type == PvZ.ZOMBIE_BUNGEE:
			tool_tip.y = zombie.y
		tool_tip.center = true
		tool_tip.visible = true
		tool_tip.max_bottom = PvZ.BOARD_HEIGHT if (almanac_button.btn_no_draw and store_button.btn_no_draw) else PvZ.BOARD_HEIGHT - 30
		return

	if seeds_in_flight <= 0:
		var st := seed_hit_test(last_mouse_x, last_mouse_y)
		if st == PvZ.SEED_NONE:
			remove_tool_tip()
		elif st != tool_tip_seed:
			remove_tool_tip()
			var cs: ChosenSeed = chosen_seeds[st]
			var flags := seed_not_recommended_to_pick(st)
			if seed_not_allowed_to_pick(st):
				tool_tip.set_warning_text("[NOT_ALLOWED_ON_THIS_LEVEL]")
			elif seed_not_allowed_during_trial(st):
				tool_tip.set_warning_text("[FULL_VERSION_ONLY]")
			elif cs.seed_state == PvZ.SEED_IN_BANK and cs.crazy_dave_picked:
				tool_tip.set_warning_text("[CRAZY_DAVE_WANTS]")
			elif flags != 0:
				tool_tip.set_warning_text("[NOCTURNAL_WARNING]" if Tod.test_bit(flags, PvZ.NOT_RECOMMENDED_NOCTURNAL) else "[NOT_RECOMMENDED_FOR_LEVEL]")
			else:
				tool_tip.set_warning_text("")

			if st == PvZ.SEED_IMITATER:
				tool_tip.set_title(Plant.get_name_string(st, cs.imitater_type))
				tool_tip.set_label(Plant.get_tool_tip(PvZ.SEED_IMITATER if cs.imitater_type == PvZ.SEED_NONE else cs.imitater_type))
			else:
				tool_tip.set_title(Plant.get_name_string(st, PvZ.SEED_NONE))
				tool_tip.set_label(Plant.get_tool_tip(st))

			var sp := get_seed_position_in_bank(cs.seed_index_in_bank) if cs.seed_state == PvZ.SEED_IN_BANK else get_seed_position_in_chooser(st)
			tool_tip.x = clampi(Tod.idiv(PvZ.SEED_PACKET_WIDTH - tool_tip.width, 2) + sp.x, 0, PvZ.BOARD_WIDTH - tool_tip.width)
			tool_tip.y = sp.y + (-tool_tip.height if (st == PvZ.SEED_IMITATER and cs.seed_state == PvZ.SEED_IN_CHOOSER) else PvZ.SEED_PACKET_HEIGHT)
			tool_tip.visible = true
			tool_tip_seed = st
		else:
			var cs: ChosenSeed = chosen_seeds[st]
			if cs.seed_state != PvZ.SEED_IN_CHOOSER:
				return
			# Update tooltip pos since seeds in the chooser might be moving
			var sp := get_seed_position_in_chooser(st)
			tool_tip.x = clampi(Tod.idiv(PvZ.SEED_PACKET_WIDTH - tool_tip.width, 2) + sp.x, 0, PvZ.BOARD_WIDTH - tool_tip.width)
			tool_tip.y = sp.y + 70

func remove_tool_tip() -> void:
	tool_tip.visible = false
	tool_tip.max_bottom = PvZ.BOARD_HEIGHT
	tool_tip.center = false
	tool_tip_seed = PvZ.SEED_NONE

func cancel_lawn_view() -> void:
	if choose_state == PvZ.CHOOSE_VIEW_LAWN and view_lawn_time > 100 and view_lawn_time <= 250:
		view_lawn_time = 251

func is_over_imitater(px: int, py: int) -> bool:
	var addon := Res.get_image("IMAGE_SEEDCHOOSER_IMITATERADDON")
	return App.seed_type_available(PvZ.SEED_IMITATER) and Rect2i(PvZ.IMITATER_POS_X, PvZ.IMITATER_POS_Y + PvZ.SEED_CHOOSER_EXTRA_HEIGHT, addon.width, addon.height).has_point(Vector2i(px, py))

func resize_slider() -> void:
	var addon_h := Res.get_image("IMAGE_SEEDCHOOSER_IMITATERADDON").height + 4 if App.seed_type_available(PvZ.SEED_IMITATER) else 0
	slider.resize(472, 92, 40, Res.get_image("IMAGE_SEEDCHOOSER_BACKGROUND").height - addon_h - 11)

func mouse_up(_mx: int, _my: int, click_count: int) -> void:
	if click_count == 1:
		if menu_button.is_mouse_over():
			button_depress(SEED_CHOOSER_MENU)
		elif start_button.is_mouse_over():
			button_depress(SEED_CHOOSER_START)
		elif almanac_button.is_mouse_over():
			button_depress(SEED_CHOOSER_ALMANAC)
		elif store_button.is_mouse_over():
			button_depress(SEED_CHOOSER_STORE)

func is_imitater_unselectable(st: int) -> bool:
	return st == PvZ.SEED_IMITATER and (seeds_in_bank == 0 or seeds_in_bank == board.seed_bank.num_packets \
		or (previous_type != PvZ.SEED_NONE and (Plant.is_upgrade(previous_type) or seed_not_allowed_to_pick(previous_type))))

func mouse_down(mx: int, my: int, click_count: int) -> void:
	super.mouse_down(mx, my, click_count)
	if seeds_in_flight > 0:
		for cs in chosen_seeds:
			land_flying_seed(cs)

	if choose_state == PvZ.CHOOSE_VIEW_LAWN:
		cancel_lawn_view()
	elif random_button.is_mouse_over():
		App.play_sample("SOUND_TAP")
		button_depress(SEED_CHOOSER_RANDOM)
	elif view_lawn_button.is_mouse_over():
		App.play_sample("SOUND_TAP")
		button_depress(SEED_CHOOSER_VIEW_LAWN)
	elif menu_button.is_mouse_over():
		App.play_sample("SOUND_GRAVEBUTTON")
	elif start_button.is_mouse_over() or almanac_button.is_mouse_over():
		App.play_sample("SOUND_TAP")
	elif store_button.is_mouse_over():
		# WIDETWEAK: fixed scrolling CYS hitbox bug after visiting shop
		App.play_sample("SOUND_TAP")
		scroll_amount = 0
		scroll_position = 0
	else:
		if not is_over_imitater(mx, my) and not almanac_button.is_mouse_over() and not store_button.is_mouse_over() and App.can_show_almanac():
			var zombie := zombie_hit_test(mx, my)
			if zombie and zombie.from_wave == Zombie.ZOMBIE_WAVE_CUTSCENE and zombie.zombie_type != PvZ.ZOMBIE_REDEYE_GARGANTUAR:
				App.play_sample("SOUND_TAP")
				var almanac := App.do_almanac_dialog(PvZ.SEED_NONE, zombie.zombie_type)
				await almanac.wait_for_result(true)
				App.widget_manager.set_focus(self)
				return

		var st := seed_hit_test(mx, my)
		if st != PvZ.SEED_NONE and not seed_not_allowed_to_pick(st):
			if seed_not_allowed_during_trial(st):
				App.play_sample("SOUND_TAP")
				if await App.lawn_message_box(PvZ.DIALOG_MESSAGE, "[GET_FULL_VERSION_TITLE]", "[GET_FULL_VERSION_BODY]", "[GET_FULL_VERSION_YES_BUTTON]", "[GET_FULL_VERSION_NO_BUTTON]", Dialog.BUTTONS_YES_NO) == Dialog.ID_YES:
					App.do_back_to_main()
			else:
				var cs: ChosenSeed = chosen_seeds[st]
				if cs.seed_state == PvZ.SEED_IN_BANK:
					if cs.crazy_dave_picked:
						App.play_sample("SOUND_BUZZER")
						tool_tip.flash_warning()
					else:
						clicked_seed_in_bank(cs)
				elif cs.seed_state == PvZ.SEED_IN_CHOOSER:
					clicked_seed_in_chooser(cs)

func picked_plant_type(st: int) -> bool:
	for cs in chosen_seeds:
		if cs.seed_state == PvZ.SEED_IN_BANK or cs.seed_state == PvZ.SEED_FLYING_TO_BANK:
			if cs.seed_type == st or (cs.seed_type == PvZ.SEED_IMITATER and cs.imitater_type == st):
				return true
	return false

func close_seed_chooser() -> void:
	for idx in board.seed_bank.num_packets:
		var st := find_seed_in_bank(idx)
		if st == PvZ.SEED_NONE:
			continue
		var cs: ChosenSeed = chosen_seeds[st]
		var packet: SeedPacket = board.seed_bank.seed_packets[idx]
		packet.set_packet_type(st, cs.imitater_type)
		if cs.refreshing:
			packet.refresh_counter = cs.refresh_counter
			packet.refresh_time = Plant.get_refresh_time(packet.packet_type, packet.imitater_type)
			packet.refreshing = true
			packet.active = false
	board.cut_scene.end_seed_chooser()

func key_down(key: int) -> void:
	board.do_typing_check(key)

func key_char(ch: String) -> void:
	if choose_state == PvZ.CHOOSE_VIEW_LAWN and (ch == " " or ch == "\r" or ch == ""):
		cancel_lawn_view()
	elif App.tod_cheat_keys and ch == "":
		pick_random_seeds()
	else:
		board.key_char(ch)

func update_after_purchase() -> void:
	for st in chooser_seeds:
		var cs: ChosenSeed = chosen_seeds[st]
		var p: Vector2i
		if cs.seed_state == PvZ.SEED_IN_BANK:
			p = get_seed_position_in_bank(cs.seed_index_in_bank)
		elif cs.seed_state == PvZ.SEED_IN_CHOOSER:
			p = get_seed_position_in_chooser(st)
		else:
			continue
		cs.x = p.x
		cs.y = p.y
		cs.start_x = cs.x
		cs.start_y = cs.y
		cs.end_x = cs.x
		cs.end_y = cs.y
	enable_start_button(seeds_in_bank == board.seed_bank.num_packets)
	resize_slider()

func zombie_hit_test(px: int, py: int) -> Zombie:
	var record: Zombie = null
	var sb := board.seed_bank
	if mouse_visible and not Rect2i(sb.x - x, sb.y - y, sb.width, sb.height).has_point(Vector2i(px, py)):
		for z in board.zombies:
			if z.dead or z.is_dead_or_dying() or z.zombie_type >= PvZ.NUM_ZOMBIES_IN_ALMANAC:
				continue
			if z.get_zombie_rect().has_point(Vector2i(px - board.x, py - board.y)):
				if record == null or z.y > record.y:
					record = z
	return record

func slider_val(sid: int, v: float) -> void:
	if sid == 0:
		scroll_position = v * max_scroll_position
