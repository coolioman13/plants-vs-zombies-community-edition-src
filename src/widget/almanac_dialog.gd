class_name AlmanacDialog
extends LawnDialog
## Port of AlmanacDialog (Suburban Almanac: index, plant and zombie pages, QE scrolling lists and description sliders).

const ALMANAC_PLANT_POSITION_X := 578.0 + PvZ.BOARD_ADDITIONAL_WIDTH
const ALMANAC_PLANT_POSITION_Y := 140.0 + PvZ.BOARD_OFFSET_Y
const ALMANAC_ZOMBIE_POSITION_X := 559.0 + PvZ.BOARD_ADDITIONAL_WIDTH
const ALMANAC_ZOMBIE_POSITION_Y := 175.0 + PvZ.BOARD_OFFSET_Y
const ALMANAC_INDEXPLANT_POSITION_X := 167 + PvZ.BOARD_ADDITIONAL_WIDTH
const ALMANAC_INDEXPLANT_POSITION_Y := 255 + PvZ.BOARD_OFFSET_Y
const ALMANAC_INDEXZOMBIE_POSITION_X := 535.0 + PvZ.BOARD_ADDITIONAL_WIDTH
const ALMANAC_INDEXZOMBIE_POSITION_Y := 215.0 + PvZ.BOARD_OFFSET_Y
const ALMANAC_DESCRIPTION_MIN_HEIGHT := 20

enum { ALMANAC_BUTTON_CLOSE, ALMANAC_BUTTON_PLANT, ALMANAC_BUTTON_ZOMBIE, ALMANAC_BUTTON_INDEX, ALMANAC_BUTTON_NEXT, ALMANAC_BUTTON_LAST }

const SEED_PACKET_ROWS := 8
const SEED_PACKET_Y_OFFSET := 8
const SEED_PACKET_Y_START_OFFSET := 14
const SEED_CLIP_RECT := Rect2i(0, PvZ.SEED_PACKET_HEIGHT + SEED_PACKET_Y_OFFSET + SEED_PACKET_Y_START_OFFSET + PvZ.BOARD_OFFSET_Y, PvZ.BOARD_WIDTH, 460)
const ZOMBIE_HEIGHT := 80
const ZOMBIE_Y_START_OFFSET := 6
const ZOMBIE_CLIP_RECT := Rect2i(0, ZOMBIE_HEIGHT + ZOMBIE_Y_START_OFFSET + PvZ.BOARD_OFFSET_Y, PvZ.BOARD_WIDTH, 474)
const ZOMBIE_ROWS := 5
const WEIRD_CHARACTERS := ["®"]
const BASE_SCROLL_SPEED := 1.0
const SCROLL_ACCEL := 0.1

## gZombieDefeated: zombies beaten this session, so a type introduced on the current level unlocks its entry.
static var zombie_defeated: Array = []

var close_button: GameButton
var index_button: GameButton
var plant_button: GameButton
var zombie_button: GameButton
var plant_slider: SexySlider
var zombie_slider: SexySlider
var open_page := PvZ.ALMANAC_PAGE_INDEX
var selected_seed := PvZ.SEED_PEASHOOTER
var selected_zombie := PvZ.ZOMBIE_NORMAL
var plant: Plant = null
var zombie: Zombie = null
var scroll_position := 0.0
var scroll_amount := 0.0
var max_scroll_position := 0.0
var last_mouse_x := 0
var last_mouse_y := 0
var is_over_description := false
var description_line_spacing := 0
var description_scroll := 0.0
var description_max_scroll := 0.0
var description_offset_scroll := 0.0
var description_y_offset := 0.0
var description_overfill := false
var description_rect := Rect2i()
var description_slider_rect := Rect2i()
var description_slider_dragging := false

func _init() -> void:
	super._init(PvZ.DIALOG_ALMANAC, true, "Almanac", "", "", BUTTONS_NONE)
	draw_standard_back = false
	super.resize(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)

	var label_color := Color8(42, 42, 90)
	close_button = GameButton.new(ALMANAC_BUTTON_CLOSE)
	close_button.label = "[CLOSE_BUTTON]"
	close_button.button_image = Res.get_image("IMAGE_ALMANAC_CLOSEBUTTON")
	close_button.over_image = Res.get_image("IMAGE_ALMANAC_CLOSEBUTTONHIGHLIGHT")
	close_button.down_image = null
	close_button.set_font(Res.get_font("FONT_BRIANNETOD12"))
	close_button.colors[GameButton.COLOR_LABEL] = label_color
	close_button.colors[GameButton.COLOR_LABEL_HILITE] = label_color
	close_button.resize(676 + PvZ.BOARD_ADDITIONAL_WIDTH, 567 + PvZ.BOARD_OFFSET_Y, 89, 26)
	close_button.text_offset_x = -8
	close_button.text_offset_y = 1
	close_button.parent_widget = self

	index_button = GameButton.new(ALMANAC_BUTTON_INDEX)
	index_button.label = "[ALMANAC_INDEX]"
	index_button.button_image = Res.get_image("IMAGE_ALMANAC_INDEXBUTTON")
	index_button.over_image = Res.get_image("IMAGE_ALMANAC_INDEXBUTTONHIGHLIGHT")
	index_button.down_image = null
	index_button.set_font(Res.get_font("FONT_BRIANNETOD12"))
	index_button.colors[GameButton.COLOR_LABEL] = label_color
	index_button.colors[GameButton.COLOR_LABEL_HILITE] = label_color
	index_button.resize(32 + PvZ.BOARD_ADDITIONAL_WIDTH, 567 + PvZ.BOARD_OFFSET_Y, 164, 26)
	index_button.text_offset_x = 8
	index_button.text_offset_y = 1
	index_button.parent_widget = self

	plant_button = GameButton.new(ALMANAC_BUTTON_PLANT)
	plant_button.label = "[VIEW_PLANTS]"
	plant_button.button_image = Res.get_image("IMAGE_SEEDCHOOSER_BUTTON")
	plant_button.over_image = null
	plant_button.down_image = null
	plant_button.disabled_image = Res.get_image("IMAGE_SEEDCHOOSER_BUTTON_DISABLED")
	plant_button.over_overlay_image = Res.get_image("IMAGE_SEEDCHOOSER_BUTTON_GLOW")
	plant_button.set_font(Res.get_font("FONT_DWARVENTODCRAFT18YELLOW"))
	plant_button.colors[GameButton.COLOR_LABEL] = Color.WHITE
	plant_button.colors[GameButton.COLOR_LABEL_HILITE] = Color.WHITE
	plant_button.resize(130 + PvZ.BOARD_ADDITIONAL_WIDTH, 345 + PvZ.BOARD_OFFSET_Y, 156, 42)
	plant_button.text_offset_y = -1
	plant_button.parent_widget = self

	zombie_button = GameButton.new(ALMANAC_BUTTON_ZOMBIE)
	zombie_button.label = "[VIEW_ZOMBIES]"
	zombie_button.resize(487 + PvZ.BOARD_ADDITIONAL_WIDTH, 345 + PvZ.BOARD_OFFSET_Y, 210, 48)
	zombie_button.draw_stone_button = true
	zombie_button.parent_widget = self

	plant_slider = SexySlider.new(Res.get_image("IMAGE_OPTIONS_SLIDERSLOT_PLANT"), Res.get_image("IMAGE_OPTIONS_SLIDERKNOB_PLANT"), 0, self)
	plant_slider.set_value(maxf(0.0, minf(max_scroll_position, scroll_position)))
	plant_slider.horizontal = false
	plant_slider.resize(10 + PvZ.BOARD_ADDITIONAL_WIDTH, SEED_CLIP_RECT.position.y, 20, SEED_CLIP_RECT.size.y)
	plant_slider.thumb_offset_x = -5
	plant_slider.visible = false

	zombie_slider = SexySlider.new(Res.get_image("IMAGE_CHALLENGE_SLIDERSLOT"), Res.get_image("IMAGE_OPTIONS_SLIDERKNOB2"), 0, self)
	zombie_slider.set_value(maxf(0.0, minf(max_scroll_position, scroll_position)))
	zombie_slider.horizontal = false
	zombie_slider.resize(10 + PvZ.BOARD_ADDITIONAL_WIDTH, ZOMBIE_CLIP_RECT.position.y, 20, ZOMBIE_CLIP_RECT.size.y)
	zombie_slider.thumb_offset_x = -1
	zombie_slider.visible = false

	set_page(PvZ.ALMANAC_PAGE_INDEX)
	if App.board == null or not App.board.paused:
		App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_CHOOSE_YOUR_SEEDS)

func clear_objects() -> void:
	if plant:
		plant.die()
		plant = null
	if zombie:
		zombie.die_no_loot()
		zombie = null

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	clear_objects()
	remove_widget(plant_slider)
	remove_widget(zombie_slider)

## The original calls Widget::AddedToManager directly, skipping LawnDialog's buttons and reanim widget.
func added_to_manager(wm: WidgetManager) -> void:
	widget_manager = wm
	for w in widgets:
		w.widget_manager = wm
		w.added_to_manager(wm)
	add_widget(plant_slider)
	add_widget(zombie_slider)

func slider_val(sid: int, v: float) -> void:
	if sid == 0:
		scroll_position = v * max_scroll_position

func _new_ui_plant(seed_type: int, px: float, py: float) -> Plant:
	var p := Plant.new()
	p.board = null
	p.is_on_board = false
	p.plant_initialize(0, 0, seed_type, PvZ.SEED_NONE)
	p.x = int(px)
	p.y = int(py)
	return p

func _new_ui_zombie(zombie_type: int, px: float, py: float) -> Zombie:
	var z := Zombie.new()
	z.board = null
	z.zombie_initialize(0, zombie_type, false, null, Zombie.ZOMBIE_WAVE_UI)
	z.pos_x = px
	z.pos_y = py
	return z

func setup_plant() -> void:
	clear_objects()
	var px := ALMANAC_PLANT_POSITION_X
	var py := ALMANAC_PLANT_POSITION_Y
	match selected_seed:
		PvZ.SEED_TALLNUT: py += 18
		PvZ.SEED_COBCANNON: px -= 40
		PvZ.SEED_FLOWERPOT: py -= 20
		PvZ.SEED_INSTANT_COFFEE: py += 20
		PvZ.SEED_GRAVEBUSTER: py += 55
	plant = _new_ui_plant(selected_seed, px, py)

func setup_zombie() -> void:
	clear_objects()
	zombie = _new_ui_zombie(selected_zombie, ALMANAC_ZOMBIE_POSITION_X, ALMANAC_ZOMBIE_POSITION_Y)

func set_page(page: int) -> void:
	open_page = page
	plant_slider.set_value(0.1)
	zombie_slider.set_value(0.1)
	clear_objects()
	if open_page == PvZ.ALMANAC_PAGE_INDEX:
		plant = _new_ui_plant(PvZ.SEED_SUNFLOWER, ALMANAC_INDEXPLANT_POSITION_X, ALMANAC_INDEXPLANT_POSITION_Y)
		zombie = _new_ui_zombie(PvZ.ZOMBIE_NORMAL, ALMANAC_INDEXZOMBIE_POSITION_X, ALMANAC_INDEXZOMBIE_POSITION_Y)
		index_button.btn_no_draw = true
		plant_button.btn_no_draw = false
		zombie_button.btn_no_draw = false
	else:
		if open_page == PvZ.ALMANAC_PAGE_PLANTS:
			setup_plant()
		elif open_page == PvZ.ALMANAC_PAGE_ZOMBIES:
			setup_zombie()
		else:
			return
		index_button.btn_no_draw = false
		plant_button.btn_no_draw = true
		zombie_button.btn_no_draw = true

func show_plant(seed_type: int) -> void:
	selected_seed = seed_type
	set_page(PvZ.ALMANAC_PAGE_PLANTS)

func show_zombie(zombie_type: int) -> void:
	selected_zombie = zombie_type
	set_page(PvZ.ALMANAC_PAGE_ZOMBIES)

func update() -> void:
	last_mouse_x = App.widget_manager.last_mouse_x
	last_mouse_y = App.widget_manager.last_mouse_y
	close_button.update()
	index_button.update()
	plant_button.update()
	zombie_button.update()
	if plant:
		plant.update()
	if zombie:
		zombie.update()

	if open_page == PvZ.ALMANAC_PAGE_PLANTS:
		max_scroll_position = maxi(0, ((PvZ.NUM_SEEDS_IN_CHOOSER - 2) / SEED_PACKET_ROWS) * (PvZ.SEED_PACKET_HEIGHT + SEED_PACKET_Y_OFFSET) + PvZ.SEED_PACKET_HEIGHT - SEED_CLIP_RECT.size.y)
		var speed := BASE_SCROLL_SPEED + absf(scroll_amount) * SCROLL_ACCEL
		scroll_position = clampf(scroll_position + scroll_amount * speed, 0, max_scroll_position)
		scroll_amount *= 1.0 - SCROLL_ACCEL
		plant_slider.visible = max_scroll_position != 0
	elif open_page == PvZ.ALMANAC_PAGE_ZOMBIES:
		max_scroll_position = maxi(0, ((PvZ.NUM_ZOMBIES_IN_ALMANAC - 1) / ZOMBIE_ROWS) * ZOMBIE_HEIGHT + ZOMBIE_HEIGHT - ZOMBIE_Y_START_OFFSET - ZOMBIE_CLIP_RECT.size.y)
		var speed2 := BASE_SCROLL_SPEED + absf(scroll_amount) * SCROLL_ACCEL
		scroll_position = clampf(scroll_position + scroll_amount * speed2, 0, max_scroll_position)
		scroll_amount *= 1.0 - SCROLL_ACCEL
		zombie_slider.visible = max_scroll_position != 0
	else:
		scroll_amount = 0
		scroll_position = 0
		plant_slider.visible = false
		zombie_slider.visible = false

	var slider_v := maxf(0.0, minf(max_scroll_position, scroll_position)) / max_scroll_position if max_scroll_position != 0 else 0.0
	plant_slider.set_value(slider_v)
	zombie_slider.set_value(slider_v)

	if not (plant_slider.is_over or plant_slider.dragging) and not (zombie_slider.is_over or zombie_slider.dragging):
		var zt := zombie_hit_test(last_mouse_x, last_mouse_y)
		if seed_hit_test(last_mouse_x, last_mouse_y) != PvZ.SEED_NONE or (zt != PvZ.ZOMBIE_INVALID and zombie_is_shown(zt)) \
				or close_button.is_mouse_over() or index_button.is_mouse_over() or plant_button.is_mouse_over() or zombie_button.is_mouse_over():
			App.set_cursor(App.CURSOR_HAND)
		else:
			App.set_cursor(App.CURSOR_POINTER)
	App.pool_effect.pool_effect_update()

static func get_zombie_type(index: int) -> int:
	return index if index < PvZ.NUM_ZOMBIE_TYPES else PvZ.ZOMBIE_INVALID

func draw_index(g: Graphics) -> void:
	g.draw_image(Res.get_image("IMAGE_ALMANAC_INDEXBACK"), 0, 0)
	TodStrings.draw_string(g, "[SUBURBAN_ALMANAC_INDEX]", PvZ.BOARD_WIDTH / 2, 60 + PvZ.BOARD_OFFSET_Y, Res.get_font("FONT_HOUSEOFTERROR28"), Color8(220, 220, 220), PvZ.DS_ALIGN_CENTER)
	if plant:
		var pg := g.copy()
		plant.begin_draw(pg)
		plant.draw(pg)
	if zombie:
		var zg := g.copy()
		zombie.begin_draw(zg)
		zombie.draw(zg)

## Draws the scrollable description block shared by the plant and zombie cards.
func _draw_description(g: Graphics, the_name: String, rect: Rect2i, bar_color: Color) -> void:
	var font := Res.get_font("FONT_BRIANNETOD12")
	var color := Color8(40, 50, 90)
	var just := PvZ.DS_ALIGN_LEFT
	description_rect = rect
	var header := translate_and_sanitize("[%s_DESCRIPTION_HEADER]" % the_name)
	TodStrings.draw_string_wrapped(g, header, description_rect, font, color, just)
	var spacing := TodStrings._draw_wrapped_helper(g, header, description_rect, font, color, just, false)
	description_rect.position.y += spacing
	description_rect.size.y -= spacing
	var description := translate_and_sanitize("[%s_DESCRIPTION]" % the_name)
	spacing = TodStrings._draw_wrapped_helper(g, description, description_rect, font, color, just, false)
	var rect_height: int
	if description_rect.size.y < spacing:
		is_over_description = description_rect.has_point(Vector2i(last_mouse_x, last_mouse_y))
		description_line_spacing = font.get_line_spacing()
		var bar_w := 8
		var bar_x := description_rect.position.x + description_rect.size.x - bar_w / 2
		description_rect.size.x -= bar_w
		spacing = TodStrings._draw_wrapped_helper(g, description, description_rect, font, color, just, false)
		g.color = Color(bar_color, 75 / 255.0)
		g.fill_rect(bar_x, description_rect.position.y, bar_w, description_rect.size.y)
		description_max_scroll = spacing - description_rect.size.y
		g.color = bar_color
		var bar_h := int(description_rect.size.y - description_max_scroll)
		var pos_y := description_scroll
		description_overfill = bar_h < ALMANAC_DESCRIPTION_MIN_HEIGHT
		if description_overfill:
			bar_h = ALMANAC_DESCRIPTION_MIN_HEIGHT
			pos_y = (description_scroll / description_max_scroll) * (description_rect.size.y - bar_h)
		description_slider_rect = Rect2i(bar_x, int(description_rect.position.y + pos_y), bar_w, bar_h)
		g.fill_rect_r(Rect2(description_slider_rect))
		rect_height = spacing
	else:
		is_over_description = false
		description_line_spacing = 0
		description_scroll = 0
		description_max_scroll = 0
		rect_height = description_rect.size.y
	g.set_clip_rect_r(Rect2(description_rect))
	TodStrings.draw_string_wrapped(g, description, Rect2i(description_rect.position.x, int(description_rect.position.y - description_scroll), description_rect.size.x, rect_height), font, color, just)
	g.clear_clip_rect()

func draw_plants(g: Graphics) -> void:
	var aw := PvZ.BOARD_ADDITIONAL_WIDTH
	var oy := PvZ.BOARD_OFFSET_Y
	g.draw_image(Res.get_image("IMAGE_ALMANAC_PLANTBACK"), 0, 0)
	TodStrings.draw_string(g, "[SUBURBAN_ALMANAC_PLANTS]", PvZ.BOARD_WIDTH / 2, 48 + oy, Res.get_font("FONT_HOUSEOFTERROR20"), Color8(213, 159, 43), PvZ.DS_ALIGN_CENTER)
	var mouse_seed := seed_hit_test(last_mouse_x, last_mouse_y)
	for st in PvZ.NUM_SEEDS_IN_CHOOSER:
		var pos := get_seed_position(st)
		if not App.seed_type_available(st):
			if st != PvZ.SEED_IMITATER:
				g.set_clip_rect_r(Rect2(SEED_CLIP_RECT))
				g.draw_image(Res.get_image("IMAGE_ALMANAC_PLANTBLANK"), pos.x, pos.y)
			g.clear_clip_rect()
		elif st == PvZ.SEED_IMITATER:
			g.clear_clip_rect()
			if st == mouse_seed:
				g.draw_image(Res.get_image("IMAGE_ALMANAC_IMITATER"), pos.x, pos.y)
			g.draw_image(Res.get_image("IMAGE_ALMANAC_IMITATER"), pos.x, pos.y)
		else:
			g.set_clip_rect_r(Rect2(SEED_CLIP_RECT))
			SeedPacket.draw_seed_packet(g, pos.x, pos.y, st, PvZ.SEED_NONE, 0, 255, true, false)
			if st == mouse_seed:
				g.draw_image(Res.get_image("IMAGE_SEEDPACKETFLASH"), pos.x, pos.y)
	g.clear_clip_rect()

	if selected_seed in [PvZ.SEED_LILYPAD, PvZ.SEED_TANGLEKELP, PvZ.SEED_CATTAIL, PvZ.SEED_SEASHROOM]:
		var night := selected_seed == PvZ.SEED_SEASHROOM
		g.draw_image(Res.get_image("IMAGE_ALMANAC_GROUNDNIGHTPOOL" if night else "IMAGE_ALMANAC_GROUNDPOOL"), 521 + aw, 107 + oy)
		if App.is_3d_accel():
			g.set_clip_rect(475, 0, 397, 500)
			g.translate(aw, -85)
			App.pool_effect.pool_effect_draw(g, night)
			g.translate(-aw, 85)
			g.clear_clip_rect()
	else:
		var ground := "IMAGE_ALMANAC_GROUNDDAY"
		if Plant.is_nocturnal(selected_seed) or selected_seed == PvZ.SEED_GRAVEBUSTER or selected_seed == PvZ.SEED_PLANTERN:
			ground = "IMAGE_ALMANAC_GROUNDNIGHT"
		elif selected_seed == PvZ.SEED_FLOWERPOT:
			ground = "IMAGE_ALMANAC_GROUNDROOF"
		g.draw_image(Res.get_image(ground), 521 + aw, 107 + oy)

	if plant:
		var pg := g.copy()
		plant.begin_draw(pg)
		plant.draw(pg)

	g.draw_image(Res.get_image("IMAGE_ALMANAC_PLANTCARD"), 459 + aw, 86 + oy)
	var def: Array = LawnDefs.PLANT_DEFS[selected_seed]
	var plant_name: String = def[7]
	TodStrings.draw_string(g, Plant.get_name_string(selected_seed, PvZ.SEED_NONE), 617 + aw, 288 + oy, Res.get_font("FONT_DWARVENTODCRAFT18YELLOW"), Color.WHITE, PvZ.DS_ALIGN_CENTER)
	_draw_description(g, plant_name, Rect2i(485 + aw, 309 + oy, 258, 210), Color8(143, 67, 27))

	if selected_seed != PvZ.SEED_IMITATER:
		var cost := Tod.replace_string("{KEYWORD}{COST}:{STAT} %d" % def[3], "{COST}", "[COST]")
		TodStrings.draw_string_wrapped(g, cost, Rect2i(485 + aw, 520 + oy, 134, 50), Res.get_font("FONT_BRIANNETOD12"), Color.WHITE, PvZ.DS_ALIGN_LEFT)
		var refresh: int = def[4]
		var length := "[WAIT_TIME_SHORT]" if refresh == 750 else "[WAIT_TIME_LONG]" if refresh == 3000 else "[WAIT_TIME_VERY_LONG]"
		var recharge := Tod.replace_string("{KEYWORD}{WAIT_TIME}:{STAT} {WAIT_TIME_LENGTH}", "{WAIT_TIME_LENGTH}", length)
		recharge = Tod.replace_string(recharge, "{WAIT_TIME}", "[WAIT_TIME]")
		TodStrings.draw_string_wrapped(g, recharge, Rect2i(600 + aw, 520 + oy, 139, 50), Res.get_font("FONT_BRIANNETOD12"), Color8(40, 50, 90), PvZ.DS_ALIGN_RIGHT)

## Per-type nudges for the small portraits in the zombie grid.
const GRID_ZOMBIE_OFFSETS := {
	PvZ.ZOMBIE_POLEVAULTER: Vector2(2, -3), PvZ.ZOMBIE_FLAG: Vector2(2, 10), PvZ.ZOMBIE_TRAFFIC_CONE: Vector2(0, 12),
	PvZ.ZOMBIE_TALLNUT_HEAD: Vector2(0, 12), PvZ.ZOMBIE_PAIL: Vector2(0, 9), PvZ.ZOMBIE_FOOTBALL: Vector2(-8, 5),
	PvZ.ZOMBIE_ZAMBONI: Vector2(0, 3), PvZ.ZOMBIE_DOLPHIN_RIDER: Vector2(-2, -10), PvZ.ZOMBIE_POGO: Vector2(0, -3),
	PvZ.ZOMBIE_GARGANTUAR: Vector2(15, 17), PvZ.ZOMBIE_REDEYE_GARGANTUAR: Vector2(15, 17), PvZ.ZOMBIE_IMP: Vector2(-8, -7),
	PvZ.ZOMBIE_BUNGEE: Vector2(-4, 3), PvZ.ZOMBIE_BACKUP_DANCER: Vector2(-8, 5), PvZ.ZOMBIE_SNORKEL: Vector2(-10, 0),
	PvZ.ZOMBIE_YETI: Vector2(0, 4), PvZ.ZOMBIE_CATAPULT: Vector2(-24, -1), PvZ.ZOMBIE_BOBSLED: Vector2(0, -8),
	PvZ.ZOMBIE_LADDER: Vector2(0, -3),
}

## Per-type nudges for the big zombie on the card.
const CARD_ZOMBIE_OFFSETS := {
	PvZ.ZOMBIE_ZAMBONI: Vector2(-30, 5), PvZ.ZOMBIE_GARGANTUAR: Vector2(0, 30), PvZ.ZOMBIE_REDEYE_GARGANTUAR: Vector2(0, 30),
	PvZ.ZOMBIE_FOOTBALL: Vector2(-17, 5), PvZ.ZOMBIE_BALLOON: Vector2(0, -20), PvZ.ZOMBIE_BUNGEE: Vector2(15, 0),
	PvZ.ZOMBIE_CATAPULT: Vector2(-10, 0), PvZ.ZOMBIE_BOSS: Vector2(-540, -175),
}

func _draw_window_hilite(g: Graphics, img: PvzImage, px: int, py: int) -> void:
	g.set_draw_mode(Graphics.DRAWMODE_ADDITIVE)
	g.color = Color8(255, 255, 255, 48)
	g.colorize_images = true
	g.draw_image(img, px, py)
	g.set_draw_mode(Graphics.DRAWMODE_NORMAL)
	g.colorize_images = false

func draw_zombies(g: Graphics) -> void:
	var aw := PvZ.BOARD_ADDITIONAL_WIDTH
	var oy := PvZ.BOARD_OFFSET_Y
	g.draw_image(Res.get_image("IMAGE_ALMANAC_ZOMBIEBACK"), 0, 0)
	TodStrings.draw_string(g, "[SUBURBAN_ALMANAC_ZOMBIES]", PvZ.BOARD_WIDTH / 2, 54 + oy, Res.get_font("FONT_DWARVENTODCRAFT24"), Color8(0, 196, 0), PvZ.DS_ALIGN_CENTER)

	var mouse_zombie := zombie_hit_test(last_mouse_x, last_mouse_y)
	var window := Res.get_image("IMAGE_ALMANAC_ZOMBIEWINDOW")
	var window2 := Res.get_image("IMAGE_ALMANAC_ZOMBIEWINDOW2")
	g.set_clip_rect_r(Rect2(ZOMBIE_CLIP_RECT))
	for i in PvZ.NUM_ZOMBIES_IN_ALMANAC:
		var zt := get_zombie_type(i)
		if zt == PvZ.ZOMBIE_INVALID:
			continue
		var pos := get_zombie_position(zt)
		if not zombie_is_shown(zt):
			g.draw_image(Res.get_image("IMAGE_ALMANAC_ZOMBIEBLANK"), pos.x, pos.y)
			continue
		g.draw_image(window, pos.x, pos.y)
		if zt == mouse_zombie:
			_draw_window_hilite(g, window, pos.x, pos.y)

		var draw_type := zt
		var zg := g.copy()
		zg.clip_rect(pos.x + 2, pos.y + 2, 72, 72)
		zg.translate(pos.x + 1, pos.y - 6)
		zg.scale_x = 0.5
		zg.scale_y = 0.5
		if GRID_ZOMBIE_OFFSETS.has(zt):
			var o: Vector2 = GRID_ZOMBIE_OFFSETS[zt]
			zg.translate(o.x, o.y)
		if zt == PvZ.ZOMBIE_POLEVAULTER:
			draw_type = PvZ.ZOMBIE_CACHED_POLEVAULTER_WITH_POLE
		if zombie_has_silhouette(zt):
			zg.color = Color8(0, 0, 0, 40)
			zg.colorize_images = true
		ReanimatorCache.draw_cached_zombie(zg, 0, 0, draw_type)
		zg.colorize_images = false

		g.draw_image(window2, pos.x, pos.y)
		if zt == mouse_zombie:
			_draw_window_hilite(g, window2, pos.x, pos.y)
	g.clear_clip_rect()

	var icy := zombie != null and (zombie.zombie_type == PvZ.ZOMBIE_ZAMBONI or zombie.zombie_type == PvZ.ZOMBIE_BOBSLED)
	g.draw_image(Res.get_image("IMAGE_ALMANAC_GROUNDICE" if icy else "IMAGE_ALMANAC_GROUNDDAY"), 518 + aw, 110 + oy)
	if zombie and not zombie_has_silhouette(zombie.zombie_type):
		var cg := g.copy()
		zombie.begin_draw(cg)
		cg.set_clip_rect(-42, -51, 197, 187)
		if CARD_ZOMBIE_OFFSETS.has(zombie.zombie_type):
			var o2: Vector2 = CARD_ZOMBIE_OFFSETS[zombie.zombie_type]
			cg.translate(o2.x, o2.y)
		if not zombie.zombie_type in [PvZ.ZOMBIE_BUNGEE, PvZ.ZOMBIE_BOSS, PvZ.ZOMBIE_ZAMBONI, PvZ.ZOMBIE_CATAPULT]:
			zombie.draw_shadow(cg)
		zombie.draw(cg)
	g.draw_image(Res.get_image("IMAGE_ALMANAC_ZOMBIECARD"), 455 + aw, 78 + oy)

	var zdef: Array = LawnDefs.ZOMBIE_DEFS[selected_zombie]
	var zombie_name: String = zdef[6]
	var shown_name := "???" if zombie_has_silhouette(selected_zombie) else "[%s]" % zombie_name
	TodStrings.draw_string(g, shown_name, 613 + aw, 362 + oy, Res.get_font("FONT_DWARVENTODCRAFT18GREENINSET"), Color8(190, 255, 235, 255), PvZ.DS_ALIGN_CENTER)

	# Hide the metal-related lines until the player owns a Magnet-shroom.
	var font := Res.get_font("FONT_BRIANNETOD12")
	for fm in TodStrings.formats:
		if Tod.test_bit(fm[3], TodStrings.TOD_FORMAT_HIDE_UNTIL_MAGNETSHROOM):
			var c: Color = fm[1]
			if App.has_seed_type(PvZ.SEED_MAGNETSHROOM):
				c.a8 = 255
				fm[2] = 0
			else:
				c.a8 = 0
				fm[2] = -Tod.idiv(font.get_line_spacing(), 2)
			fm[1] = c

	var rect := Rect2i(485 + aw, 377 + oy, 257, 160)
	if zombie_has_description(selected_zombie):
		_draw_description(g, zombie_name, rect, Color8(95, 97, 129))
	else:
		description_rect = rect
		TodStrings.draw_string_wrapped(g, "[NOT_ENCOUNTERED_YET]", rect, font, Color8(40, 50, 90), PvZ.DS_ALIGN_CENTER_VERTICAL_MIDDLE)

func draw(g: Graphics) -> void:
	g.set_linear_blend(true)
	match open_page:
		PvZ.ALMANAC_PAGE_INDEX: draw_index(g)
		PvZ.ALMANAC_PAGE_PLANTS: draw_plants(g)
		PvZ.ALMANAC_PAGE_ZOMBIES: draw_zombies(g)
	close_button.draw(g)
	index_button.draw(g)
	plant_button.draw(g)
	zombie_button.draw(g)

func get_seed_position(seed_type: int) -> Vector2i:
	var idx := seed_type
	if idx > PvZ.SEED_IMITATER:
		idx -= 1
	if idx == PvZ.SEED_IMITATER:
		return Vector2i(20, 23)
	var pw := PvZ.SEED_PACKET_WIDTH + 2
	var ph := PvZ.SEED_PACKET_HEIGHT + SEED_PACKET_Y_OFFSET
	return Vector2i(idx % SEED_PACKET_ROWS * pw + pw / 2 + PvZ.BOARD_ADDITIONAL_WIDTH,
		int(idx / SEED_PACKET_ROWS * ph + (ph + SEED_PACKET_Y_START_OFFSET) - scroll_position + PvZ.BOARD_OFFSET_Y))

func seed_hit_test(px: int, py: int) -> int:
	if mouse_visible and open_page == PvZ.ALMANAC_PAGE_PLANTS:
		var imitater := Res.get_image("IMAGE_ALMANAC_IMITATER")
		for st in PvZ.NUM_SEEDS_IN_CHOOSER:
			if not App.seed_type_available(st):
				continue
			var pos := get_seed_position(st)
			var r := Rect2i(pos.x, pos.y, PvZ.SEED_PACKET_WIDTH, PvZ.SEED_PACKET_HEIGHT) if st != PvZ.SEED_IMITATER else Rect2i(pos.x, pos.y, imitater.width, imitater.height)
			var p := Vector2i(px, py)
			if (SEED_CLIP_RECT.has_point(p) or st == PvZ.SEED_IMITATER) and r.has_point(p):
				return st
	return PvZ.SEED_NONE

func zombie_has_silhouette(zombie_type: int) -> bool:
	if zombie_type != PvZ.ZOMBIE_YETI or App.can_spawn_yetis():
		return false
	return App.has_finished_adventure() or App.player_info.level > LawnDefs.ZOMBIE_DEFS[PvZ.ZOMBIE_YETI][3]

func zombie_is_shown(zombie_type: int) -> bool:
	if App.is_trial_stage_locked() and zombie_type > PvZ.ZOMBIE_SNORKEL:
		return false
	if zombie_type == PvZ.ZOMBIE_YETI:
		return App.can_spawn_yetis() or zombie_has_silhouette(PvZ.ZOMBIE_YETI)
	if zombie_type <= PvZ.ZOMBIE_BOSS:
		if App.has_finished_adventure():
			return true
		var lvl: int = App.player_info.level
		var start: int = LawnDefs.ZOMBIE_DEFS[zombie_type][3]
		return start <= lvl and (start != lvl or not BoardCore.is_zombie_type_spawned_only(zombie_type) or _defeated(zombie_type))
	return true

func zombie_has_description(zombie_type: int) -> bool:
	var lvl: int = App.player_info.level
	var start: int = LawnDefs.ZOMBIE_DEFS[zombie_type][3]
	if zombie_type == PvZ.ZOMBIE_YETI:
		if not App.can_spawn_yetis():
			return false
		if App.player_info.finished_adventure >= 2:
			return true
	elif App.has_finished_adventure():
		return true
	return start <= lvl and (start != lvl or _defeated(zombie_type))

func get_zombie_position(zombie_type: int) -> Vector2i:
	return Vector2i(zombie_type % ZOMBIE_ROWS * 85 + 22 + PvZ.BOARD_ADDITIONAL_WIDTH,
		int(zombie_type / ZOMBIE_ROWS * ZOMBIE_HEIGHT + (ZOMBIE_HEIGHT + ZOMBIE_Y_START_OFFSET) - scroll_position + PvZ.BOARD_OFFSET_Y))

func zombie_hit_test(px: int, py: int) -> int:
	if mouse_visible and open_page == PvZ.ALMANAC_PAGE_ZOMBIES:
		var p := Vector2i(px, py)
		for i in PvZ.NUM_ZOMBIES_IN_ALMANAC:
			var zt := get_zombie_type(i)
			if zt == PvZ.ZOMBIE_INVALID:
				continue
			var pos := get_zombie_position(zt)
			if Rect2i(pos.x, pos.y, 76, 76).has_point(p) and ZOMBIE_CLIP_RECT.has_point(p):
				return zt
	return PvZ.ZOMBIE_INVALID

func mouse_up(_mx: int, _my: int, _count: int) -> void:
	if description_slider_dragging:
		description_slider_dragging = false
		return
	if plant_button.is_mouse_over():
		set_page(PvZ.ALMANAC_PAGE_PLANTS)
	elif zombie_button.is_mouse_over():
		set_page(PvZ.ALMANAC_PAGE_ZOMBIES)
	elif close_button.is_mouse_over():
		App.kill_almanac_dialog()
	elif index_button.is_mouse_over():
		set_page(PvZ.ALMANAC_PAGE_INDEX)

func mouse_down(mx: int, my: int, _count: int) -> void:
	if description_slider_rect.has_point(Vector2i(mx, my)):
		var overfill_off := (description_scroll / description_max_scroll) * (description_rect.size.y - ALMANAC_DESCRIPTION_MIN_HEIGHT) if description_overfill else 0.0
		description_y_offset = my - overfill_off
		description_offset_scroll = description_scroll
		description_slider_dragging = true
		return
	if plant_button.is_mouse_over() or close_button.is_mouse_over() or index_button.is_mouse_over():
		App.play_sample("SOUND_TAP")
	if zombie_button.is_mouse_over():
		App.play_sample("SOUND_GRAVEBUTTON")
	var st := seed_hit_test(mx, my)
	if st != PvZ.SEED_NONE and st != selected_seed:
		selected_seed = st
		setup_plant()
		App.play_sample("SOUND_TAP")
	var zt := zombie_hit_test(mx, my)
	if zt != PvZ.ZOMBIE_INVALID and zt != selected_zombie and zombie_is_shown(zt):
		selected_zombie = zt
		setup_zombie()
		App.play_sample("SOUND_TAP")

func mouse_drag(_mx: int, my: int) -> void:
	if not description_slider_dragging:
		return
	if description_overfill:
		description_scroll = ((my - description_y_offset) / (description_rect.size.y - ALMANAC_DESCRIPTION_MIN_HEIGHT)) * description_max_scroll
	else:
		description_scroll = my - (description_y_offset - description_offset_scroll)
	description_scroll = clampf(description_scroll, 0, description_max_scroll)

func mouse_wheel(delta: int) -> bool:
	if is_over_description and not description_slider_dragging:
		description_scroll = clampf(description_scroll - description_line_spacing * delta, 0, description_max_scroll)
	else:
		scroll_amount -= BASE_SCROLL_SPEED * delta
		scroll_amount -= scroll_amount * SCROLL_ACCEL
	return true

func key_char(_ch: String) -> void:
	pass

static func _defeated(zombie_type: int) -> bool:
	return zombie_type < zombie_defeated.size() and zombie_defeated[zombie_type]

static func almanac_init_for_player() -> void:
	zombie_defeated.resize(PvZ.NUM_ZOMBIE_TYPES)
	zombie_defeated.fill(false)

static func almanac_player_defeated_zombie(zombie_type: int) -> void:
	if zombie_defeated.size() < PvZ.NUM_ZOMBIE_TYPES:
		almanac_init_for_player()
	zombie_defeated[zombie_type] = true

## QE strips the stray lead byte that C++ byte strings leave in front of "®" (UTF-8 C2 AE).
## Godot decodes the file as UTF-8, so only a mis-decoded "Â" before the symbol can appear here.
func translate_and_sanitize(s: String) -> String:
	var ret := TodStrings.translate(s)
	for weird in WEIRD_CHARACTERS:
		ret = ret.replace("Â" + weird, weird)
	return ret
