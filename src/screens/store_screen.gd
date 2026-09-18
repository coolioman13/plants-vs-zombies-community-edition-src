class_name StoreScreen
extends Dialog
## Port of StoreScreen (Crazy Dave's Twiddydinkies) + StoreScreenOverlay.

const MAX_PAGE_SPOTS := 8
const MAX_PURCHASES := 80
const PURCHASE_COUNT_OFFSET := 1000
const STORESCREEN_BACK := 100
const STORESCREEN_PREV := 101
const STORESCREEN_NEXT := 102

const STORE_ITEM_SPOTS := [
	[PvZ.STORE_ITEM_PACKET_UPGRADE, PvZ.STORE_ITEM_POOL_CLEANER, PvZ.STORE_ITEM_RAKE, PvZ.STORE_ITEM_ROOF_CLEANER,
		PvZ.STORE_ITEM_PLANT_GATLINGPEA, PvZ.STORE_ITEM_PLANT_TWINSUNFLOWER, PvZ.STORE_ITEM_PLANT_GLOOMSHROOM, PvZ.STORE_ITEM_PLANT_CATTAIL],
	[PvZ.STORE_ITEM_PLANT_SPIKEROCK, PvZ.STORE_ITEM_PLANT_GOLD_MAGNET, PvZ.STORE_ITEM_PLANT_WINTERMELON, PvZ.STORE_ITEM_PLANT_COBCANNON,
		PvZ.STORE_ITEM_PLANT_IMITATER, PvZ.STORE_ITEM_FIRSTAID, PvZ.STORE_ITEM_INVALID, PvZ.STORE_ITEM_INVALID],
	[PvZ.STORE_ITEM_POTTED_MARIGOLD_1, PvZ.STORE_ITEM_POTTED_MARIGOLD_2, PvZ.STORE_ITEM_POTTED_MARIGOLD_3, PvZ.STORE_ITEM_GOLD_WATERINGCAN,
		PvZ.STORE_ITEM_FERTILIZER, PvZ.STORE_ITEM_BUG_SPRAY, PvZ.STORE_ITEM_PHONOGRAPH, PvZ.STORE_ITEM_GARDENING_GLOVE],
	[PvZ.STORE_ITEM_MUSHROOM_GARDEN, PvZ.STORE_ITEM_AQUARIUM_GARDEN, PvZ.STORE_ITEM_WHEEL_BARROW, PvZ.STORE_ITEM_STINKY_THE_SNAIL,
		PvZ.STORE_ITEM_TREE_OF_WISDOM, PvZ.STORE_ITEM_TREE_FOOD, PvZ.STORE_ITEM_INVALID, PvZ.STORE_ITEM_INVALID],
]

class StoreScreenOverlay:
	extends Widget
	var owner_store: StoreScreen

	func _init(s: StoreScreen) -> void:
		owner_store = s
		mouse_visible = false

	func draw(g: Graphics) -> void:
		owner_store.draw_overlay(g)

var back_button: NewLawnButton
var prev_button: NewLawnButton
var next_button: NewLawnButton
var overlay_widget: StoreScreenOverlay
var store_time := 0
var bubble_count_down := 0
var bubble_click_to_continue := false
var ambient_speech_count_down := 200
var previous_ambient_speech_index := -1
var page := PvZ.STORE_PAGE_SLOT_UPGRADES
var mouse_over_item := PvZ.STORE_ITEM_INVALID
var hatch_timer := 0
var hatch_open := true
var shake_x := 0
var shake_y := 0
var start_dialog := -1
var easy_buying_cheat := false
var wait_for_dialog := false
var potted_plant_specs := PlayerInfo.PottedPlant.new()
var coins: Array = []
var drawn_once := false
var go_to_tree_now := false
var purchased_full_version := false
var trial_locked_when_store_opened := false
var in_cutscene := false

func _init() -> void:
	super._init(PvZ.DIALOG_STORE, true, "", "", "", BUTTONS_NONE)
	clip = false
	resize(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	potted_plant_specs.initialize_potted_plant(PvZ.SEED_MARIGOLD)
	potted_plant_specs.draw_variation = Tod.rand_range_int(PvZ.VARIATION_MARIGOLD_WHITE, PvZ.VARIATION_MARIGOLD_LIGHT_GREEN)

	back_button = NewLawnButton.new(null, STORESCREEN_BACK, self)
	back_button.do_finger = true
	back_button.label = "[STORE_MAIN_MENU_BUTTON]"
	var menu_img := Res.get_image("IMAGE_STORE_MAINMENUBUTTON")
	back_button.button_image = menu_img
	back_button.over_image = Res.get_image("IMAGE_STORE_MAINMENUBUTTONHIGHLIGHT")
	back_button.down_image = Res.get_image("IMAGE_STORE_MAINMENUBUTTONDOWN")
	back_button.set_font(Res.get_font("FONT_HOUSEOFTERROR20"))
	back_button.colors[ButtonWidget.COLOR_LABEL] = Color8(98, 153, 235)
	back_button.colors[ButtonWidget.COLOR_LABEL_HILITE] = Color8(167, 192, 235)
	back_button.resize(370 + PvZ.BOARD_OFFSET_X, 572 + PvZ.BOARD_OFFSET_Y, menu_img.width, menu_img.height)
	back_button.text_offset_x = -7
	back_button.text_offset_y = 1
	back_button.text_down_offset_x = 2
	back_button.text_down_offset_y = 1

	prev_button = _make_page_button(STORESCREEN_PREV, "IMAGE_STORE_PREVBUTTON", "IMAGE_STORE_PREVBUTTONHIGHLIGHT")
	prev_button.resize(218 + PvZ.BOARD_OFFSET_X, 431 + PvZ.BOARD_OFFSET_Y, prev_button.button_image.width, prev_button.button_image.height)
	next_button = _make_page_button(STORESCREEN_NEXT, "IMAGE_STORE_NEXTBUTTON", "IMAGE_STORE_NEXTBUTTONHIGHLIGHT")
	next_button.resize(618 + PvZ.BOARD_OFFSET_X, 431 + PvZ.BOARD_OFFSET_Y, next_button.button_image.width, next_button.button_image.height)

	overlay_widget = StoreScreenOverlay.new(self)
	overlay_widget.resize(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)

	if not is_page_shown(PvZ.STORE_PAGE_PLANT_UPGRADES):
		prev_button.disabled_image = Res.get_image("IMAGE_STORE_PREVBUTTONDISABLED")
		prev_button.set_disabled(true)
		next_button.disabled_image = Res.get_image("IMAGE_STORE_NEXTBUTTONDISABLED")
		next_button.set_disabled(true)
	trial_locked_when_store_opened = App.is_trial_stage_locked()

func _make_page_button(bid: int, img: String, over: String) -> NewLawnButton:
	var b := NewLawnButton.new(null, bid, self)
	b.do_finger = true
	b.label = ""
	b.button_image = Res.get_image(img)
	b.over_image = Res.get_image(over)
	b.down_image = b.over_image
	b.colors[ButtonWidget.COLOR_LABEL] = Color8(255, 240, 0)
	b.colors[ButtonWidget.COLOR_LABEL_HILITE] = Color8(200, 200, 255)
	return b

func _purchases() -> Array:
	return App.player_info.purchases

func get_store_item_type(spot: int) -> int:
	if page < PvZ.NUM_STORE_PAGES and spot < MAX_PAGE_SPOTS:
		if page == PvZ.STORE_PAGE_SLOT_UPGRADES and spot == 6 and App.is_trial_stage_locked():
			return PvZ.STORE_ITEM_PVZ
		return STORE_ITEM_SPOTS[page][spot]
	return PvZ.STORE_ITEM_INVALID

func is_full_version_only(item: int) -> bool:
	if not App.is_trial_stage_locked():
		return false
	if item == PvZ.STORE_ITEM_PACKET_UPGRADE and _purchases()[PvZ.STORE_ITEM_PACKET_UPGRADE] >= 2:
		return true
	return item == PvZ.STORE_ITEM_PLANT_TWINSUNFLOWER

static func is_potted_plant(item: int) -> bool:
	return item == PvZ.STORE_ITEM_POTTED_MARIGOLD_1 or item == PvZ.STORE_ITEM_POTTED_MARIGOLD_2 or item == PvZ.STORE_ITEM_POTTED_MARIGOLD_3

func is_coming_soon(item: int) -> bool:
	if is_full_version_only(item):
		return true
	elif item == PvZ.STORE_ITEM_WHEEL_BARROW:
		return not _purchases()[PvZ.STORE_ITEM_MUSHROOM_GARDEN] and not _purchases()[PvZ.STORE_ITEM_AQUARIUM_GARDEN]
	elif is_potted_plant(item):
		return not App.has_finished_adventure()
	elif item == PvZ.STORE_ITEM_TREE_FOOD:
		return not _purchases()[PvZ.STORE_ITEM_TREE_OF_WISDOM] or _purchases()[PvZ.STORE_ITEM_TREE_FOOD] < PURCHASE_COUNT_OFFSET
	return false

func is_item_sold_out(item: int) -> bool:
	var pur := _purchases()
	if item == PvZ.STORE_ITEM_INVALID:
		return false
	elif item == PvZ.STORE_ITEM_PACKET_UPGRADE:
		return pur[item] >= 4
	elif item == PvZ.STORE_ITEM_FERTILIZER or item == PvZ.STORE_ITEM_BUG_SPRAY:
		return pur[item] - PURCHASE_COUNT_OFFSET > 15
	elif item == PvZ.STORE_ITEM_TREE_FOOD:
		return pur[item] - PURCHASE_COUNT_OFFSET > 10
	elif item == PvZ.STORE_ITEM_BONUS_LAWN_MOWER:
		return pur[item] >= 2
	elif is_potted_plant(item):
		return App.zen_garden.is_zen_garden_full(true) or pur[item] == LawnCommon.get_current_days_since_2000()
	return pur[item] != 0

func is_item_unavailable(item: int) -> bool:
	if easy_buying_cheat:
		return false
	var lvl: int = App.player_info.level
	var done := App.has_finished_adventure()
	if item == PvZ.STORE_ITEM_ROOF_CLEANER:
		return App.is_trial_stage_locked() or (not done and lvl < 42)
	if item == PvZ.STORE_ITEM_PLANT_GLOOMSHROOM or item == PvZ.STORE_ITEM_PLANT_CATTAIL:
		return App.is_trial_stage_locked() or (not done and lvl < 35)
	if item == PvZ.STORE_ITEM_PLANT_SPIKEROCK or item == PvZ.STORE_ITEM_PLANT_GOLD_MAGNET:
		return not done and lvl < 41
	if item in [PvZ.STORE_ITEM_PLANT_WINTERMELON, PvZ.STORE_ITEM_PLANT_COBCANNON, PvZ.STORE_ITEM_PLANT_IMITATER, PvZ.STORE_ITEM_FIRSTAID]:
		return not done
	return false

static func get_store_position(spot: int) -> Vector2i:
	if spot <= 3:
		return Vector2i(PvZ.STORESCREEN_ITEMOFFSET_1_X + PvZ.STORESCREEN_ITEMSIZE * spot, PvZ.STORESCREEN_ITEMOFFSET_1_Y)
	return Vector2i(PvZ.STORESCREEN_ITEMOFFSET_2_X + PvZ.STORESCREEN_ITEMSIZE * (spot - 4), PvZ.STORESCREEN_ITEMOFFSET_2_Y)

func draw_item_icon(g: Graphics, pos_index: int, item: int, for_highlight: bool) -> void:
	if for_highlight:
		g.set_draw_mode(Graphics.DRAWMODE_ADDITIVE)
		g.set_color(Tod.rgba(255, 255, 255, 96))
		g.set_colorize_images(true)
	var p := get_store_position(pos_index)
	var px := p.x
	var py := p.y
	var f16 := Res.get_font("FONT_HOUSEOFTERROR16")
	match item:
		PvZ.STORE_ITEM_PACKET_UPGRADE:
			g.set_color(Tod.rgba(255, 255, 255, 32))
			g.draw_image(Res.get_image("IMAGE_STORE_PACKETUPGRADE"), px - 7, py + 7)
			if for_highlight:
				g.set_draw_mode(Graphics.DRAWMODE_NORMAL)
				g.set_colorize_images(false)
			var slot_text := Tod.replace_number_string("[STORE_UPGRADE_SLOTS]", "{SLOTS}", _purchases()[PvZ.STORE_ITEM_PACKET_UPGRADE] + 7)
			TodStrings.draw_string_wrapped(g, slot_text, Rect2i(px, py + 6, 55, 70), f16, Color.WHITE, PvZ.DS_ALIGN_CENTER_VERTICAL_MIDDLE)
		PvZ.STORE_ITEM_POOL_CLEANER: g.draw_image(Res.get_image("IMAGE_ICON_POOLCLEANER"), px + 1, py + 7)
		PvZ.STORE_ITEM_RAKE: g.draw_image(Res.get_image("IMAGE_ICON_RAKE"), px - 5, py + 10)
		PvZ.STORE_ITEM_ROOF_CLEANER: g.draw_image(Res.get_image("IMAGE_ICON_ROOFCLEANER"), px, py + 28)
		PvZ.STORE_ITEM_PLANT_IMITATER:
			g.draw_image(Res.get_image("IMAGE_CONSOLE_IMITATERSEED" if PvZ.USE_CONSOLE_SEED_VARIANTS else "IMAGE_IMITATERSEED"), px, py)
		PvZ.STORE_ITEM_MUSHROOM_GARDEN: g.draw_image(Res.get_image("IMAGE_STORE_MUSHROOMGARDENICON"), px - 8, py + 2)
		PvZ.STORE_ITEM_AQUARIUM_GARDEN: g.draw_image(Res.get_image("IMAGE_STORE_AQUARIUMGARDENICON"), px - 8, py + 2)
		PvZ.STORE_ITEM_TREE_OF_WISDOM: g.draw_image(Res.get_image("IMAGE_STORE_TREEOFWISDOMICON"), px - 8, py + 2)
		PvZ.STORE_ITEM_FIRSTAID: g.draw_image(Res.get_image("IMAGE_STORE_FIRSTAIDWALLNUTICON"), px - 1, py + 13)
		PvZ.STORE_ITEM_PVZ: g.draw_image(Res.get_image("IMAGE_STORE_PVZICON"), px, py - 9)
		PvZ.STORE_ITEM_TREE_FOOD: g.draw_image(Res.get_image("IMAGE_TREEFOOD"), px - 8, py - 2)
		PvZ.STORE_ITEM_STINKY_THE_SNAIL: g.draw_image(Res.get_image("IMAGE_REANIM_STINKY_TURN3"), px - 24, py + 14)
		PvZ.STORE_ITEM_GOLD_WATERINGCAN: g.draw_image(Res.get_image("IMAGE_WATERINGCANGOLD"), px - 14, py - 4)
		PvZ.STORE_ITEM_FERTILIZER:
			g.draw_image(Res.get_image("IMAGE_FERTILIZER"), px - 11, py - 2)
			TodStrings.draw_string(g, "x5", px + 56, py + 62, f16, Color.WHITE, PvZ.DS_ALIGN_RIGHT)
		PvZ.STORE_ITEM_PHONOGRAPH: g.draw_image(Res.get_image("IMAGE_PHONOGRAPH"), px - 12, py + 3)
		PvZ.STORE_ITEM_BUG_SPRAY:
			g.draw_image(Res.get_image("IMAGE_BUG_SPRAY"), px - 12, py + 3)
			TodStrings.draw_string(g, "x5", px + 56, py + 62, f16, Color.WHITE, PvZ.DS_ALIGN_RIGHT)
		PvZ.STORE_ITEM_GARDENING_GLOVE: g.draw_image(Res.get_image("IMAGE_ZEN_GARDENGLOVE"), px - 12, py + 3)
		PvZ.STORE_ITEM_WHEEL_BARROW: g.draw_image(Res.get_image("IMAGE_ZEN_WHEELBARROW"), px - 12, py + 3)
		_:
			if is_potted_plant(item):
				App.zen_garden.draw_potted_plant_icon(g, px, py, potted_plant_specs)
			else:
				SeedPacket.draw_seed_packet(g, px, py, item + 40, PvZ.SEED_NONE, 0, 255, false, false)
	g.set_draw_mode(Graphics.DRAWMODE_NORMAL)
	g.set_colorize_images(false)

func draw_item(g: Graphics, pos_index: int, item: int) -> void:
	if is_item_unavailable(item):
		return
	draw_item_icon(g, pos_index, item, false)
	var p := get_store_position(pos_index)
	if item != PvZ.STORE_ITEM_PVZ:
		g.draw_image(Res.get_image("IMAGE_STORE_PRICETAG"), p.x - 3, p.y + 70)
		TodStrings.draw_string(g, App.get_money_string(get_item_cost(item)), p.x + 23, p.y + 85, Res.get_font("FONT_BRIANNETOD12"), Color.BLACK, PvZ.DS_ALIGN_CENTER)
	var f16 := Res.get_font("FONT_HOUSEOFTERROR16")
	if is_coming_soon(item):
		var r := Rect2i(p.x, p.y, 60, 70)
		if item == PvZ.STORE_ITEM_PLANT_TWINSUNFLOWER or item == PvZ.STORE_ITEM_PACKET_UPGRADE:
			r.position.x -= 4
		TodStrings.draw_string_wrapped(g, "[COMING_SOON]", r, f16, Color8(255, 0, 0), PvZ.DS_ALIGN_CENTER_VERTICAL_MIDDLE)
	elif is_item_sold_out(item):
		TodStrings.draw_string_wrapped(g, "[SOLD_OUT]", Rect2i(p.x, p.y, 50, 70), f16, Color8(255, 0, 0), PvZ.DS_ALIGN_CENTER_VERTICAL_MIDDLE)
	elif mouse_over_item == item:
		if item >= 0 and item <= 8:
			g.draw_image(Res.get_image("IMAGE_SEEDPACKETFLASH"), p.x, p.y)
		else:
			draw_item_icon(g, pos_index, item, true)

func draw(g: Graphics) -> void:
	g.set_linear_blend(true)
	drawn_once = true
	var sign_y := Tod.animate_curve(50, 110, store_time, -150, 0, Tod.CURVE_EASE_IN_OUT)
	# WIDETWEAK: fixed store showing up as daytime even when you're at the night areas of adventure mode
	g.draw_image(Res.get_image("IMAGE_STORE_BACKGROUNDNIGHT" if App.is_night() else "IMAGE_STORE_BACKGROUND"), 0, 0)

	var car_x := shake_x + 166 + PvZ.BOARD_OFFSET_X
	var car_y := shake_y + 138 + PvZ.BOARD_OFFSET_Y
	if hatch_timer == 0 and hatch_open:
		g.draw_image(Res.get_image("IMAGE_STORE_CAR"), car_x, car_y)
		g.draw_image(Res.get_image("IMAGE_STORE_HATCHBACKOPEN"), shake_x + 269 + PvZ.BOARD_OFFSET_X, shake_y + PvZ.BOARD_OFFSET_Y)
		if App.is_night():
			g.draw_image(Res.get_image("IMAGE_STORE_CAR_NIGHT"), car_x, car_y)
	else:
		g.draw_image(Res.get_image("IMAGE_STORE_CARCLOSED"), car_x, car_y)
		if App.is_night():
			g.draw_image(Res.get_image("IMAGE_STORE_CAR_NIGHT"), car_x, car_y)
			g.draw_image(Res.get_image("IMAGE_STORE_CARCLOSED_NIGHT"), car_x, car_y)
	g.draw_image(Res.get_image("IMAGE_STORE_SIGN"), 285 + PvZ.BOARD_OFFSET_X, sign_y)

	var dave_g := g.copy()
	dave_g.trans_x -= 42.0 + PvZ.BOARD_ADDITIONAL_WIDTH / 2
	dave_g.trans_y += 68.0 - PvZ.BOARD_OFFSET_Y
	App.draw_crazy_dave(dave_g)

	if hatch_timer == 0 and hatch_open:
		for i in MAX_PAGE_SPOTS:
			var item := get_store_item_type(i)
			if item != PvZ.STORE_ITEM_INVALID:
				draw_item(g, i, item)

	g.draw_image(Res.get_image("IMAGE_COINBANK"), PvZ.STORESCREEN_COINBANK_X, PvZ.STORESCREEN_COINBANK_Y)
	g.set_color(Color8(180, 255, 90))
	var font := Res.get_font("FONT_CONTINUUMBOLD14")
	g.set_font(font)
	var coin_label := App.get_money_string(App.player_info.coins)
	g.draw_string(coin_label, PvZ.STORESCREEN_COINBANK_X + 113 - font.string_width(coin_label), PvZ.STORESCREEN_COINBANK_Y + 24)

	if not prev_button.disabled:
		var num_pages := 0
		for p in PvZ.NUM_STORE_PAGES:
			if is_page_shown(p):
				num_pages += 1
		var page_str := Tod.replace_number_string(Tod.replace_number_string(TodStrings.translate("[STORE_PAGE]"), "{PAGE}", page + 1), "{NUM_PAGES}", num_pages)
		TodStrings.draw_string(g, page_str, PvZ.STORESCREEN_PAGESTRING_X, PvZ.STORESCREEN_PAGESTRING_Y, Res.get_font("FONT_BRIANNETOD12"), Color8(128, 128, 128), PvZ.DS_ALIGN_CENTER)

func draw_overlay(g: Graphics, _priority: int = 0) -> void:
	for c in coins:
		if not c.dead:
			c.draw(g)

func set_bubble_text(message: int, time: int, click_to_continue: bool) -> void:
	App.crazy_dave_talk_index(message)
	bubble_count_down = time
	bubble_click_to_continue = click_to_continue

const ITEM_MESSAGES := {
	PvZ.STORE_ITEM_PLANT_GATLINGPEA: 2000, PvZ.STORE_ITEM_PLANT_TWINSUNFLOWER: 2001, PvZ.STORE_ITEM_PLANT_GLOOMSHROOM: 2002,
	PvZ.STORE_ITEM_PLANT_CATTAIL: 2003, PvZ.STORE_ITEM_PLANT_WINTERMELON: 2004, PvZ.STORE_ITEM_PLANT_GOLD_MAGNET: 2005,
	PvZ.STORE_ITEM_PLANT_SPIKEROCK: 2006, PvZ.STORE_ITEM_PLANT_COBCANNON: 2007, PvZ.STORE_ITEM_PLANT_IMITATER: 2008,
	PvZ.STORE_ITEM_BONUS_LAWN_MOWER: 2009, PvZ.STORE_ITEM_POTTED_MARIGOLD_1: 2010, PvZ.STORE_ITEM_POTTED_MARIGOLD_2: 2010,
	PvZ.STORE_ITEM_POTTED_MARIGOLD_3: 2010, PvZ.STORE_ITEM_GOLD_WATERINGCAN: 2019, PvZ.STORE_ITEM_FERTILIZER: 2020,
	PvZ.STORE_ITEM_BUG_SPRAY: 2022, PvZ.STORE_ITEM_PHONOGRAPH: 2021, PvZ.STORE_ITEM_GARDENING_GLOVE: 2023,
	PvZ.STORE_ITEM_MUSHROOM_GARDEN: 2032, PvZ.STORE_ITEM_WHEEL_BARROW: 2024, PvZ.STORE_ITEM_STINKY_THE_SNAIL: 2025,
	PvZ.STORE_ITEM_POOL_CLEANER: 2026, PvZ.STORE_ITEM_ROOF_CLEANER: 2027, PvZ.STORE_ITEM_RAKE: 2028,
	PvZ.STORE_ITEM_AQUARIUM_GARDEN: 2029, PvZ.STORE_ITEM_TREE_OF_WISDOM: 2030, PvZ.STORE_ITEM_TREE_FOOD: 2031,
	PvZ.STORE_ITEM_FIRSTAID: 2033, PvZ.STORE_ITEM_PVZ: 2034,
}

func update_mouse() -> void:
	mouse_over_item = PvZ.STORE_ITEM_INVALID
	if in_cutscene:
		return
	if store_time < 120 or bubble_click_to_continue or hatch_timer > 0 or wait_for_dialog:
		return
	var mx := App.widget_manager.last_mouse_x - x
	var my := App.widget_manager.last_mouse_y - y
	var show_finger := false
	for pos_index in MAX_PAGE_SPOTS:
		var item := get_store_item_type(pos_index)
		if item != PvZ.STORE_ITEM_INVALID and not is_item_unavailable(item):
			var p := get_store_position(pos_index)
			if Rect2i(p.x, p.y, 50, 87).has_point(Vector2i(mx, my)):
				mouse_over_item = item
				var message := -1
				if item == PvZ.STORE_ITEM_PACKET_UPGRADE:
					var n: int = _purchases()[PvZ.STORE_ITEM_PACKET_UPGRADE]
					message = n + 2011 if n < 4 else 2014
				else:
					message = ITEM_MESSAGES.get(item, -1)
				if App.crazy_dave_message_index != message:
					set_bubble_text(message, 100, false)
				else:
					bubble_count_down = 100
				if is_full_version_only(item) or (not is_item_sold_out(item) and not is_item_unavailable(item) and not is_coming_soon(item)):
					show_finger = true
				break
	App.set_cursor(App.CURSOR_HAND if (back_button.is_over or prev_button.is_over or next_button.is_over or show_finger) else App.CURSOR_POINTER)

func store_preload() -> void:
	App.crazy_dave_enter()

func can_interact_with_buttons() -> bool:
	return store_time >= 120 and not bubble_click_to_continue and hatch_timer <= 0 and not wait_for_dialog

func update() -> void:
	App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_TITLE_CRAZY_DAVE_MAIN_THEME)
	App.update_crazy_dave()
	for c in coins.duplicate():
		if not c.dead:
			c.update()
	if wait_for_dialog:
		return
	if App.crazy_dave_state == PvZ.CRAZY_DAVE_OFF:
		if drawn_once:
			store_preload()
		return

	store_time += 1
	if App.crazy_dave_state != PvZ.CRAZY_DAVE_OFF and App.crazy_dave_state != PvZ.CRAZY_DAVE_ENTERING:
		if hatch_timer > 0:
			hatch_timer -= 1
			for b in [back_button, prev_button, next_button]:
				b.x -= shake_x
				b.y -= shake_y
			if hatch_timer == 0:
				enable_buttons(true)
				shake_x = 0
				shake_y = 0
			else:
				shake_x = 0
				shake_y = Tod.rand_range_int(1, 3) if hatch_timer > 35 else 0
			for b in [back_button, prev_button, next_button]:
				b.x += shake_x
				b.y += shake_y
		elif start_dialog != -1:
			set_bubble_text(start_dialog, 0, true)
			start_dialog = -1
		elif not bubble_click_to_continue:
			if bubble_count_down > 0:
				bubble_count_down -= 1
				if bubble_count_down == 0:
					var ss := App.sound_system
					if ss.is_foley_playing(PvZ.FOLEY_CRAZY_DAVE_SHORT) or ss.is_foley_playing(PvZ.FOLEY_CRAZY_DAVE_LONG) or ss.is_foley_playing(PvZ.FOLEY_CRAZY_DAVE_EXTRA_LONG):
						bubble_count_down = 1
					else:
						App.crazy_dave_stop_talking()
			else:
				ambient_speech_count_down -= 1
				if ambient_speech_count_down <= 0:
					var picks: Array = []
					for i in 4:
						var msg := 2015 + i
						var w := 100
						if previous_ambient_speech_index == msg:
							w = 0
						elif i == 3:
							w = 20 if App.has_finished_adventure() else 0
						picks.append([msg, w])
					var dave_message: int = Tod.pick_from_weighted_array(picks)
					previous_ambient_speech_index = dave_message
					set_bubble_text(dave_message, 800, false)
					ambient_speech_count_down = Tod.rand_range_int(500, 1000)

	update_mouse()
	if can_interact_with_buttons() and trial_locked_when_store_opened and not App.is_trial_stage_locked():
		purchased_full_version = true
		set_result(ID_YES)
	else:
		super.update()
	if App.crazy_dave_message_index >= 4000 and App.crazy_dave_message_index < 4004:
		if bubble_count_down <= 100:
			App.crazy_dave_message_index += 1
			set_bubble_text(App.crazy_dave_message_index, 300, false)
		if App.crazy_dave_message_index == 4004:
			in_cutscene = false
			App.get_achievement(PvZ.ACHIEVEMENT_MORTICULTURALIST)

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	for w in [back_button, prev_button, next_button, overlay_widget]:
		add_widget(w)

func removed_from_manager(wm: WidgetManager) -> void:
	for w in [back_button, prev_button, next_button, overlay_widget]:
		remove_widget(w)
	super.removed_from_manager(wm)
	App.crazy_dave_die()

func button_press(bid: int, _count: int = 1) -> void:
	if bid != STORESCREEN_PREV and bid != STORESCREEN_NEXT:
		App.play_sample("SOUND_BUTTONCLICK")

func is_page_shown(p: int) -> bool:
	if App.is_trial_stage_locked():
		return p == PvZ.STORE_PAGE_SLOT_UPGRADES
	if App.has_finished_adventure():
		return true
	if p == PvZ.STORE_PAGE_PLANT_UPGRADES:
		return App.player_info.level >= 42
	if p == PvZ.STORE_PAGE_ZEN1:
		return App.player_info.level >= 45
	return p != PvZ.STORE_PAGE_ZEN2

func button_depress(bid: int) -> void:
	if in_cutscene:
		return
	if bid == STORESCREEN_BACK:
		App.kill_store_screen()
	elif bid == STORESCREEN_PREV or bid == STORESCREEN_NEXT:
		hatch_timer = 50
		App.play_sample("SOUND_HATCHBACK_CLOSE")
		bubble_count_down = 0
		App.crazy_dave_stop_talking()
		enable_buttons(false)
		while true:
			if bid == STORESCREEN_PREV:
				page -= 1
				if page < PvZ.STORE_PAGE_SLOT_UPGRADES:
					page = PvZ.STORE_PAGE_ZEN2
			else:
				page += 1
				if page >= PvZ.NUM_STORE_PAGES:
					page = PvZ.STORE_PAGE_SLOT_UPGRADES
			if is_page_shown(page):
				break

func key_char(ch: String) -> void:
	if bubble_click_to_continue and (ch == " " or ch == "\r"):
		advance_crazy_dave_dialog()

func key_down(_key: int) -> void:
	pass

static func get_item_cost(item: int) -> int:
	var pur: Array = App.player_info.purchases
	if item == PvZ.STORE_ITEM_BONUS_LAWN_MOWER:
		return 500 if pur[item] else 200
	match item:
		PvZ.STORE_ITEM_PLANT_GATLINGPEA: return 500
		PvZ.STORE_ITEM_PLANT_TWINSUNFLOWER: return 500
		PvZ.STORE_ITEM_PLANT_GLOOMSHROOM: return 750
		PvZ.STORE_ITEM_PLANT_CATTAIL: return 1000
		PvZ.STORE_ITEM_PLANT_WINTERMELON: return 1000
		PvZ.STORE_ITEM_PLANT_GOLD_MAGNET: return 300
		PvZ.STORE_ITEM_PLANT_SPIKEROCK: return 750
		PvZ.STORE_ITEM_PLANT_COBCANNON: return 2000
		PvZ.STORE_ITEM_PLANT_IMITATER: return 3000
		PvZ.STORE_ITEM_POTTED_MARIGOLD_1, PvZ.STORE_ITEM_POTTED_MARIGOLD_2, PvZ.STORE_ITEM_POTTED_MARIGOLD_3: return 250
		PvZ.STORE_ITEM_GOLD_WATERINGCAN: return 1000
		PvZ.STORE_ITEM_FERTILIZER: return 75
		PvZ.STORE_ITEM_BUG_SPRAY: return 100
		PvZ.STORE_ITEM_PHONOGRAPH: return 1500
		PvZ.STORE_ITEM_GARDENING_GLOVE: return 100
		PvZ.STORE_ITEM_MUSHROOM_GARDEN: return 3000
		PvZ.STORE_ITEM_WHEEL_BARROW: return 20
		PvZ.STORE_ITEM_STINKY_THE_SNAIL: return 300
		PvZ.STORE_ITEM_PACKET_UPGRADE:
			var n: int = pur[item]
			return 75 if n == 0 else 500 if n == 1 else 2000 if n == 2 else 8000
		PvZ.STORE_ITEM_POOL_CLEANER: return 100
		PvZ.STORE_ITEM_ROOF_CLEANER: return 300
		PvZ.STORE_ITEM_RAKE: return 20
		PvZ.STORE_ITEM_AQUARIUM_GARDEN: return 3000
		PvZ.STORE_ITEM_TREE_OF_WISDOM: return 1000
		PvZ.STORE_ITEM_TREE_FOOD: return 250
		PvZ.STORE_ITEM_FIRSTAID: return 200
	return 0

func can_afford_item(item: int) -> bool:
	return App.player_info.coins >= get_item_cost(item)

func purchase_item(item: int) -> void:
	App.set_cursor(App.CURSOR_POINTER)
	bubble_count_down = 0
	App.crazy_dave_stop_talking()
	if not can_afford_item(item):
		var d := App.do_dialog(PvZ.DIALOG_NOT_ENOUGH_MONEY, true, "[NOT_ENOUGH_MONEY]", "[CANNOT_AFFORD_ITEM]", "[DIALOG_BUTTON_OK]", BUTTONS_FOOTER)
		wait_for_dialog = true
		await d.wait_for_result(true)
		wait_for_dialog = false
		return

	var confirm: LawnDialog = App.do_dialog(PvZ.DIALOG_STORE_PURCHASE, true, "[BUY_THIS_ITEM_HEADER]", "[BUY_THIS_ITEM]", "", BUTTONS_YES_NO)
	confirm.lawn_yes_button.label = "[DIALOG_BUTTON_YES]"
	confirm.lawn_no_button.label = "[DIALOG_BUTTON_NO]"
	wait_for_dialog = true
	var confirm_result := await confirm.wait_for_result(true)
	wait_for_dialog = false
	if confirm_result != ID_YES:
		return

	var pi := App.player_info
	pi.add_coins(-get_item_cost(item))
	if item == PvZ.STORE_ITEM_PACKET_UPGRADE:
		pi.purchases[item] += 1
		var d := App.do_dialog(PvZ.DIALOG_UPGRADED, true, "[MORE_SLOTS]",
			Tod.replace_number_string(TodStrings.translate("[CHOOSE_SEEDS_PER_LEVEL]"), "{AMOUNT}", 6 + pi.purchases[item]), "[DIALOG_BUTTON_OK]", BUTTONS_FOOTER)
		wait_for_dialog = true
		await d.wait_for_result(true)
		wait_for_dialog = false
		if App.board:
			App.board.seed_bank.update_width()
	elif item == PvZ.STORE_ITEM_BONUS_LAWN_MOWER:
		pi.purchases[item] += 1
	elif item == PvZ.STORE_ITEM_RAKE:
		pi.purchases[item] = 3
	elif item == PvZ.STORE_ITEM_STINKY_THE_SNAIL:
		pi.purchases[item] = int(Time.get_unix_time_from_system())
	elif item == PvZ.STORE_ITEM_FERTILIZER or item == PvZ.STORE_ITEM_BUG_SPRAY:
		if pi.purchases[item] < PURCHASE_COUNT_OFFSET:
			pi.purchases[item] = PURCHASE_COUNT_OFFSET
		pi.purchases[item] += 5
	elif item == PvZ.STORE_ITEM_TREE_FOOD:
		if pi.purchases[item] < PURCHASE_COUNT_OFFSET:
			pi.purchases[item] = PURCHASE_COUNT_OFFSET
		pi.purchases[item] += 1
	elif item == PvZ.STORE_ITEM_TREE_OF_WISDOM:
		pi.purchases[item] = 1
		pi.challenge_records[PvZ.GAMEMODE_TREE_OF_WISDOM] = 1
		var d: LawnDialog = App.do_dialog(PvZ.DIALOG_STORE_PURCHASE, true, "[VISIT_TREE_HEADER]", "[VISIT_TREE_BODY]", "", BUTTONS_YES_NO)
		d.lawn_yes_button.label = "[DIALOG_BUTTON_YES]"
		d.lawn_no_button.label = "[DIALOG_BUTTON_NO]"
		wait_for_dialog = true
		var r := await d.wait_for_result(true)
		wait_for_dialog = false
		if r == ID_YES:
			go_to_tree_now = true
			set_result(r)
	elif is_potted_plant(item):
		App.zen_garden.add_potted_plant(potted_plant_specs)
		potted_plant_specs.initialize_potted_plant(PvZ.SEED_MARIGOLD)
		potted_plant_specs.draw_variation = Tod.rand_range_int(PvZ.VARIATION_MARIGOLD_WHITE, PvZ.VARIATION_MARIGOLD_LIGHT_GREEN)
		pi.purchases[item] = LawnCommon.get_current_days_since_2000()
	else:
		pi.purchases[item] = 1

	if item == PvZ.STORE_ITEM_FIRSTAID:
		set_bubble_text(3400, 800, false)
	if App.seed_chooser_screen:
		App.seed_chooser_screen.update_after_purchase()
	if item >= PvZ.STORE_ITEM_PLANT_GATLINGPEA and item <= PvZ.STORE_ITEM_PLANT_IMITATER:
		if App.has_all_upgrades():
			in_cutscene = true
			set_bubble_text(4000, 300, false)
			advance_crazy_dave_dialog()
	App.write_current_user_config()

func advance_crazy_dave_dialog() -> void:
	if not bubble_click_to_continue:
		return
	if App.crazy_dave_message_index == 3100:
		hatch_timer = 150
		hatch_open = true
		App.play_sample("SOUND_HATCHBACK_OPEN")
	if not App.advance_crazy_dave_text():
		App.crazy_dave_stop_talking()
		bubble_click_to_continue = false
		bubble_count_down = 500
		if hatch_timer == 0:
			enable_buttons(true)
	else:
		set_bubble_text(App.crazy_dave_message_index, 0, true)

	var message := App.crazy_dave_message_index
	if message == 303 or message == 606 or message == 2601:
		hatch_timer = 150
		hatch_open = true
		App.play_sample("SOUND_HATCHBACK_OPEN")
	elif message == 603:
		App.player_info.needs_magic_taco_reward = 0
		App.write_current_user_config()
		App.play_sample("SOUND_DIAMOND")
		var coin := Coin.new()
		coin.board = null
		coin.coin_initialize(178 + PvZ.BOARD_ADDITIONAL_WIDTH / 2, 510 - PvZ.BOARD_OFFSET_Y, PvZ.COIN_DIAMOND, PvZ.COIN_MOTION_FROM_PRESENT)
		coin.vel_x = 0
		coin.vel_y = -5
		coins.append(coin)
	elif message == 902 or message == 1002:
		App.player_info.add_coins(100)

func mouse_down(mx: int, my: int, _click_count: int) -> void:
	if in_cutscene:
		return
	if bubble_click_to_continue:
		advance_crazy_dave_dialog()
		return
	if not can_interact_with_buttons():
		return
	for pos_index in MAX_PAGE_SPOTS:
		var item := get_store_item_type(pos_index)
		if item == PvZ.STORE_ITEM_INVALID:
			continue
		var p := get_store_position(pos_index)
		if Rect2i(p.x, p.y, 50, 87).has_point(Vector2i(mx, my)):
			if is_full_version_only(item):
				wait_for_dialog = true
				await App.lawn_message_box(PvZ.DIALOG_MESSAGE, "[GET_FULL_VERSION_TITLE]", "[FULL_VERSION_TO_BUY]", "[DIALOG_BUTTON_OK]", "", BUTTONS_FOOTER)
				wait_for_dialog = false
			elif item == PvZ.STORE_ITEM_PVZ:
				wait_for_dialog = true
				await App.lawn_message_box(PvZ.DIALOG_MESSAGE, "[BUY_PVZ_TITLE]", "[BUY_PVZ_BODY]", "[GET_FULL_VERSION_YES_BUTTON]", "[GET_FULL_VERSION_NO_BUTTON]", BUTTONS_YES_NO)
				wait_for_dialog = false
			elif not is_item_sold_out(item) and not is_item_unavailable(item) and not is_coming_soon(item):
				purchase_item(item)
			break

func mouse_drag(_mx: int, _my: int) -> void:
	pass

func enable_buttons(enable: bool) -> void:
	if easy_buying_cheat or is_page_shown(PvZ.STORE_PAGE_PLANT_UPGRADES) or not enable:
		next_button.mouse_visible = enable
		next_button.set_disabled(not enable)
		prev_button.mouse_visible = enable
		prev_button.set_disabled(not enable)
	back_button.mouse_visible = enable
	back_button.set_disabled(not enable)

func setup_for_intro(dialog_index: int) -> void:
	start_dialog = dialog_index
	hatch_open = false
	back_button.label = TodStrings.translate("[STORE_NEXT_LEVEL_BUTTON]")
	enable_buttons(false)
