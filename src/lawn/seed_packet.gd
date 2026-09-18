class_name SeedPacket
extends GameObject
## Port of SeedPacket (+ the DrawSeedPacket / SeedPacketDrawSeed helpers).

const SLOT_MACHINE_TIME := 400
const CONVEYOR_SPEED := 4

var refresh_counter := 0
var refresh_time := 0
var index := -1
var offset_x := 0
var packet_type := PvZ.SEED_NONE
var imitater_type := PvZ.SEED_NONE
var slot_machine_count_down := 0
var slot_machining_next_seed := PvZ.SEED_NONE
var slot_machining_position := 0.0
var active := true
var refreshing := false
var times_used := 0
## Online: player slot whose bank holds this packet (-1 = shared / offline).
var net_owner := -1

func _init() -> void:
	width = 50
	height = 70

func pick_next_slot_machine_seed() -> void:
	var board: Board = App.board
	var peas := board.count_plant_by_type(PvZ.SEED_PEASHOOTER)
	var arr: Array = []
	for st in [PvZ.SEED_SUNFLOWER, PvZ.SEED_PEASHOOTER, PvZ.SEED_SNOWPEA, PvZ.SEED_WALLNUT, PvZ.SEED_SLOT_MACHINE_SUN, PvZ.SEED_SLOT_MACHINE_DIAMOND]:
		var w := 100
		if st == PvZ.SEED_PEASHOOTER:
			w = Tod.animate_curve(0, 5, peas, 200, 100, Tod.CURVE_LINEAR)
		elif st == PvZ.SEED_SLOT_MACHINE_DIAMOND:
			w = 30
		if index == 2 and st != PvZ.SEED_SLOT_MACHINE_DIAMOND:
			if st == board.seed_bank.seed_packets[0].slot_machining_next_seed or st == board.seed_bank.seed_packets[1].slot_machining_next_seed:
				w += Tod.idiv(w, 2)
		arr.append([st, w])
	slot_machining_next_seed = Tod.pick_from_weighted_array(arr)

func slot_machine_start() -> void:
	slot_machine_count_down = 300
	slot_machining_position = 0.0
	pick_next_slot_machine_seed()

func flash_if_ready() -> void:
	var board: Board = App.board
	if not can_pick_up() or App.easy_planting_cheat:
		return
	if not board.has_conveyor_belt_seed_bank():
		var flash := App.add_tod_particle(x + board.seed_bank.x, y + board.seed_bank.y, BoardCore.make_render_order(PvZ.RENDER_LAYER_UI_BOTTOM, 0, 2), PvZ.PARTICLE_SEED_PACKET_FLASH)
		if flash and net_owner != -1 and net_owner != board.net_local_slot:
			flash.override_color(null, Color(1, 1, 1, 0))  # another player's packet: created everywhere, shown only to them
	if board.tutorial_state == PvZ.TUTORIAL_LEVEL_1_REFRESH_PEASHOOTER:
		board.set_tutorial_state(PvZ.TUTORIAL_LEVEL_1_PICK_UP_PEASHOOTER)
	elif board.tutorial_state == PvZ.TUTORIAL_LEVEL_2_REFRESH_SUNFLOWER and packet_type == PvZ.SEED_SUNFLOWER:
		board.set_tutorial_state(PvZ.TUTORIAL_LEVEL_2_PICK_UP_SUNFLOWER)
	elif board.tutorial_state == PvZ.TUTORIAL_MORESUN_REFRESH_SUNFLOWER and packet_type == PvZ.SEED_SUNFLOWER:
		board.set_tutorial_state(PvZ.TUTORIAL_MORESUN_PICK_UP_SUNFLOWER)

func activate() -> void:
	active = true

func deactivate() -> void:
	active = false
	refresh_counter = 0
	refresh_time = 0
	refreshing = false

func set_activate(on: bool) -> void:
	if on:
		activate()
	else:
		deactivate()

func update() -> void:
	var board: Board = App.board
	if App.game_scene != PvZ.SCENE_PLAYING or packet_type == PvZ.SEED_NONE:
		return
	if board.main_counter == 0:
		flash_if_ready()
	if not active and refreshing:
		refresh_counter += 1
		if refresh_counter > refresh_time:
			refresh_counter = 0
			refreshing = false
			activate()
			flash_if_ready()
	if slot_machine_count_down > 0:
		slot_machine_count_down -= 1
		var flips := Tod.animate_curve_float(SLOT_MACHINE_TIME, 0, slot_machine_count_down, 6.0, 2.0, Tod.CURVE_LINEAR)
		slot_machining_position += flips * 0.01
		if slot_machining_position >= 1.0:
			packet_type = slot_machining_next_seed
			if slot_machine_count_down == 0:
				activate()
				slot_machining_position = 0.0
			else:
				slot_machining_position -= 1.0
				pick_next_slot_machine_seed()
		elif slot_machine_count_down == 0:
			slot_machine_count_down = 1

const _PACKET_CELS := {
	PvZ.SEED_POTATOMINE: 0, PvZ.SEED_CHOMPER: 1, PvZ.SEED_HYPNOSHROOM: 2, PvZ.SEED_TALLNUT: 3, PvZ.SEED_BLOVER: 4,
	PvZ.SEED_PUMPKINSHELL: 5, PvZ.SEED_TWINSUNFLOWER: 6, PvZ.SEED_COBCANNON: 7, PvZ.SEED_CABBAGEPULT: 8,
	PvZ.SEED_KERNELPULT: 9, PvZ.SEED_MELONPULT: 10, PvZ.SEED_WINTERMELON: 11, PvZ.SEED_SPIKEROCK: 12,
}

static func seed_packet_draw_seed(g: Graphics, px: float, py: float, seed_type: int, imit_type: int, ox: float, oy: float, scale: float) -> void:
	var img := Res.get_image("IMAGE_PACKET_PLANTS")
	var use := seed_type
	var dg := g
	if seed_type == PvZ.SEED_IMITATER and imit_type != PvZ.SEED_NONE:
		use = imit_type
		dg = g.copy()
		dg.filter = RenderTarget.FILTER_WASHED_OUT
		if imit_type in [PvZ.SEED_HYPNOSHROOM, PvZ.SEED_SQUASH, PvZ.SEED_POTATOMINE, PvZ.SEED_GARLIC, PvZ.SEED_LILYPAD]:
			dg.filter = RenderTarget.FILTER_LESS_WASHED_OUT
	if _PACKET_CELS.has(use) and g.scale_x <= 1.0:
		dg.tod_draw_image_cel_scaled_f(img, px, py, _PACKET_CELS[use], 0, g.scale_x, g.scale_y)
	else:
		var sg := g.copy()
		sg.scale_x = scale * g.scale_x
		sg.scale_y = scale * g.scale_y
		Plant.draw_seed_type(sg, seed_type, imit_type, PvZ.VARIATION_NORMAL, px + ox, py + oy)

static func _seed_layout(use: int) -> Array:
	# [scale, offset_x, offset_y, draw_in_middle]
	match use:
		PvZ.SEED_TALLNUT: return [0.3, 12.0, 22.0, true]
		PvZ.SEED_INSTANT_COFFEE: return [0.55, 0.0, 9.0, true]
		PvZ.SEED_COBCANNON: return [0.26, 6.0, 22.0, true]
		PvZ.SEED_CACTUS: return [0.5, 9.0, 13.0, true]
		PvZ.SEED_POTATOMINE: return [0.4, 8.0, 12.0, true]
		PvZ.SEED_MAGNETSHROOM: return [0.5, 5.0, 12.0, true]
		PvZ.SEED_FUMESHROOM, PvZ.SEED_PUMPKINSHELL, PvZ.SEED_CHOMPER, PvZ.SEED_DOOMSHROOM, PvZ.SEED_SQUASH, PvZ.SEED_HYPNOSHROOM, \
		PvZ.SEED_SPIKEWEED, PvZ.SEED_SPIKEROCK, PvZ.SEED_PLANTERN, PvZ.SEED_TORCHWOOD, PvZ.SEED_TANGLEKELP:
			return [0.4, 8.0, 12.0, true]
		PvZ.SEED_TWINSUNFLOWER, PvZ.SEED_GLOOMSHROOM: return [0.45, 7.0, 14.0, true]
		PvZ.SEED_CATTAIL: return [0.45, 8.0, 13.0, true]
		PvZ.SEED_UMBRELLA: return [0.5, 5.0, 10.0, true]
		PvZ.SEED_KERNELPULT: return [0.4, 13.0, 14.0, true]
		PvZ.SEED_CABBAGEPULT: return [0.4, 15.0, 14.0, true]
		PvZ.SEED_MELONPULT, PvZ.SEED_WINTERMELON: return [0.35, 18.0, 19.0, true]
		PvZ.SEED_GRAVEBUSTER: return [0.4, 10.0, 15.0, true]
		PvZ.SEED_SPLITPEA: return [0.45, 12.0, 12.0, true]
		PvZ.SEED_BLOVER: return [0.4, 8.0, 17.0, true]
		PvZ.SEED_STARFRUIT: return [0.5, 6.0, 8.0, true]
		PvZ.SEED_THREEPEATER: return [0.5, 5.0, 10.0, true]
		PvZ.SEED_GATLINGPEA: return [0.5, 2.0, 8.0, true]
		PvZ.SEED_ZOMBIE_NORMAL, PvZ.SEED_ZOMBIE_TRAFFIC_CONE, PvZ.SEED_ZOMBIE_PAIL, PvZ.SEED_ZOMBIE_DANCER: return [0.35, -3.0, -7.0, true]
		PvZ.SEED_ZOMBIE_POLEVAULTER: return [0.35, -8.0, -12.0, true]
		PvZ.SEED_ZOMBIE_LADDER, PvZ.SEED_ZOMBIE_DIGGER, PvZ.SEED_ZOMBIE_SCREEN_DOOR, PvZ.SEED_ZOMBIE_POGO: return [0.35, -3.0, -10.0, true]
		PvZ.SEED_ZOMBIE_BUNGEE: return [0.3, 1.0, -1.0, true]
		PvZ.SEED_ZOMBIE_FOOTBALL: return [0.33, -7.0, -9.0, true]
		PvZ.SEED_ZOMBIE_BALLOON: return [0.35, -3.0, -5.0, true]
		PvZ.SEED_ZOMBIE_IMP: return [0.4, -12.0, -17.0, true]
		PvZ.SEED_ZOMBONI: return [0.23, 12.0, 3.0, true]
		PvZ.SEED_ZOMBIE_GARGANTUAR: return [0.23, 4.0, 3.0, true]
		NetVersus.SEED_GRAVE: return [0.45, 5.0, 12.0, true]
		PvZ.SEED_BEGHOULED_BUTTON_SHUFFLE, PvZ.SEED_BEGHOULED_BUTTON_CRATER, PvZ.SEED_SLOT_MACHINE_SUN, PvZ.SEED_SLOT_MACHINE_DIAMOND, \
		PvZ.SEED_ZOMBIQUARIUM_SNORKLE, PvZ.SEED_ZOMBIQUARIUM_TROPHY:
			return [0.5, 5.0, 8.0, false]
	return [0.5, 5.0, 8.0, true]

static func packet_background(seed_type: int, use: int) -> int:
	if seed_type == PvZ.SEED_IMITATER:
		return 0
	if Plant.is_upgrade(use):
		return 1
	match seed_type:
		PvZ.SEED_BEGHOULED_BUTTON_CRATER: return 3
		PvZ.SEED_BEGHOULED_BUTTON_SHUFFLE: return 4
		PvZ.SEED_SLOT_MACHINE_SUN: return 5
		PvZ.SEED_SLOT_MACHINE_DIAMOND: return 6
		PvZ.SEED_ZOMBIQUARIUM_SNORKLE: return 7
		PvZ.SEED_ZOMBIQUARIUM_TROPHY: return 8
	return 2

static func draw_seed_packet(g: Graphics, px: float, py: float, seed_type: int, imit_type: int, percent_dark: float, grayness: int, draw_cost: bool, use_current_cost: bool) -> void:
	var use := seed_type
	if use == PvZ.SEED_IMITATER and imit_type != PvZ.SEED_NONE:
		use = imit_type
	if grayness != 255:
		g.color = Color8(grayness, grayness, grayness)
		g.colorize_images = true
	elif percent_dark > 0:
		g.color = Color8(128, 128, 128, 255)
		g.colorize_images = true
	var bg := packet_background(seed_type, use)
	var seeds := Res.get_image("IMAGE_SEEDS")
	var zombie_packet := NetVersus.is_zombie_side_seed(seed_type)
	var packet_color := g.color
	var packet_colorize := g.colorize_images
	if zombie_packet:
		# console Versus zombie packets are purple
		var base := g.color if g.colorize_images else Color.WHITE
		g.color = Color(base.r * 0.78, base.g * 0.62, base.b, base.a)
		g.colorize_images = true
	if g.scale_x > 1:
		g.tod_draw_image_cel_scaled_f(Res.get_image("IMAGE_SEEDPACKET_LARGER"), px, py, 0, 0, g.scale_x * 0.5, g.scale_y * 0.5)
	else:
		g.tod_draw_image_cel_scaled_f(seeds, px, py, bg, 0, g.scale_x, g.scale_y)
	if zombie_packet:
		g.color = packet_color
		g.colorize_images = packet_colorize
	var layout := _seed_layout(use)
	var scale: float = layout[0]
	var ox: float = layout[1]
	var oy: float = layout[2]
	var in_middle: bool = layout[3]
	if use == PvZ.SEED_GIANT_WALLNUT:
		scale *= 0.75
		ox = 52.0
		oy = 58.0
	ox = g.scale_x * ox
	oy = g.scale_y * (oy + 1.0)
	if in_middle:
		seed_packet_draw_seed(g, px, py, seed_type, imit_type, ox, oy, scale)
	if percent_dark > 0.0:
		var dark_h := Tod.round_to_int(68.0 * percent_dark) + 2
		var pg := g.copy()
		pg.color = Color8(64, 64, 64, 255)
		pg.colorize_images = true
		pg.clip_rect(px, py, PvZ.SEED_PACKET_WIDTH, dark_h)
		pg.tod_draw_image_cel_scaled_f(seeds, px, py, bg, 0, pg.scale_x, pg.scale_y)
		if in_middle:
			seed_packet_draw_seed(pg, px, py, seed_type, imit_type, ox, oy, scale)
	if draw_cost:
		var cost_str := str(Plant.get_cost(seed_type, imit_type))
		var font := Res.get_font("FONT_BRIANNETOD12")
		var tox := 32 - font.string_width(cost_str)
		var toy := font.get_ascent() + 52
		if g.scale_x == 1.0 and g.scale_y == 1.0:
			TodStrings.draw_string(g, cost_str, int(px + tox), int(py + toy), font, Color.BLACK, TodStrings.DS_ALIGN_LEFT)
		else:
			# the matrix is absolute, so fold in the translation the rest of the packet already got
			var m := Tod.scale_matrix(tox * g.scale_x + px + g.trans_x, toy * g.scale_y + py + g.trans_y,
				g.scale_x, g.scale_y)
			font.draw_string_matrix(g, m, cost_str, Color.BLACK)
	g.colorize_images = false

func draw(g: Graphics) -> void:
	var board: Board = App.board
	var percent_dark := 0.0
	if not active:
		if refresh_time == 0:
			percent_dark = 1.0
		else:
			percent_dark = float(refresh_time - refresh_counter) / float(refresh_time)
	if slot_machine_count_down > 0:
		var oy := Tod.round_to_int(-height * slot_machining_position)
		var cg := g.copy()
		cg.clip_rect(0, 0, width, height)
		draw_seed_packet(cg, 0.0, oy, packet_type, PvZ.SEED_NONE, 0.0, 128, false, false)
		draw_seed_packet(cg, 0.0, height + oy, slot_machining_next_seed, PvZ.SEED_NONE, 0.0, 128, false, false)
		return
	var use := packet_type
	if packet_type == PvZ.SEED_IMITATER and imitater_type != PvZ.SEED_NONE:
		use = imitater_type
	var draw_cost := not (board.has_conveyor_belt_seed_bank() or App.is_slot_machine_level())
	var cost := board.get_current_plant_cost(packet_type, imitater_type)
	var grayness := 255
	if App.game_scene != PvZ.SCENE_PLAYING:
		grayness = board.seed_bank.cut_scene_darken
		percent_dark = 0.0
	elif board.tutorial_state == PvZ.TUTORIAL_LEVEL_1_PICK_UP_PEASHOOTER and board.tutorial_timer == -1 and packet_type == PvZ.SEED_PEASHOOTER:
		grayness = Tod.get_flashing_color(board.main_counter, 75).r8
	elif board.tutorial_state == PvZ.TUTORIAL_LEVEL_2_PICK_UP_SUNFLOWER and packet_type == PvZ.SEED_SUNFLOWER:
		grayness = Tod.get_flashing_color(board.main_counter, 75).r8
	elif board.tutorial_state == PvZ.TUTORIAL_MORESUN_PICK_UP_SUNFLOWER and packet_type == PvZ.SEED_SUNFLOWER:
		grayness = Tod.get_flashing_color(board.main_counter, 75).r8
	elif board.tutorial_state == PvZ.TUTORIAL_WHACK_A_ZOMBIE_PICK_SEED:
		grayness = Tod.get_flashing_color(board.main_counter, 75).r8
	elif App.easy_planting_cheat:
		percent_dark = 0.0
	elif (not board.can_take_sun_money(cost) and draw_cost) or percent_dark > 1.0 or not board.planting_requirements_met(use):
		grayness = 128
	draw_seed_packet(g, offset_x, 0.0, packet_type, imitater_type, percent_dark, grayness, draw_cost, true)

func can_pick_up() -> bool:
	var board: Board = App.board
	if board.paused or App.game_scene != PvZ.SCENE_PLAYING or packet_type == PvZ.SEED_NONE:
		return false
	var use := packet_type
	if packet_type == PvZ.SEED_IMITATER and imitater_type != PvZ.SEED_NONE:
		use = imitater_type
	if App.is_slot_machine_level():
		return false
	if not App.easy_planting_cheat:
		if not active:
			return false
		if not board.can_take_sun_money(board.get_current_plant_cost(packet_type, imitater_type)) and not board.has_conveyor_belt_seed_bank():
			return false
		if not board.planting_requirements_met(use):
			return false
	return true

const _NEEDS_ADVICE := {
	PvZ.SEED_GATLINGPEA: ["[ADVICE_PLANT_NEEDS_REPEATER]", PvZ.ADVICE_PLANT_NEEDS_REPEATER],
	PvZ.SEED_WINTERMELON: ["[ADVICE_PLANT_NEEDS_MELONPULT]", PvZ.ADVICE_PLANT_NEEDS_MELONPULT],
	PvZ.SEED_TWINSUNFLOWER: ["[ADVICE_PLANT_NEEDS_SUNFLOWER]", PvZ.ADVICE_PLANT_NEEDS_SUNFLOWER],
	PvZ.SEED_SPIKEROCK: ["[ADVICE_PLANT_NEEDS_SPIKEWEED]", PvZ.ADVICE_PLANT_NEEDS_SPIKEWEED],
	PvZ.SEED_COBCANNON: ["[ADVICE_PLANT_NEEDS_KERNELPULT]", PvZ.ADVICE_PLANT_NEEDS_KERNELPULT],
	PvZ.SEED_GOLD_MAGNET: ["[ADVICE_PLANT_NEEDS_MAGNETSHROOM]", PvZ.ADVICE_PLANT_NEEDS_MAGNETSHROOM],
	PvZ.SEED_GLOOMSHROOM: ["[ADVICE_PLANT_NEEDS_FUMESHROOM]", PvZ.ADVICE_PLANT_NEEDS_FUMESHROOM],
	PvZ.SEED_CATTAIL: ["[ADVICE_PLANT_NEEDS_LILYPAD]", PvZ.ADVICE_PLANT_NEEDS_LILYPAD],
}

func mouse_down(_mx: int, _my: int, _click_count: int) -> void:
	var board: Board = App.board
	if board.paused or App.game_scene != PvZ.SCENE_PLAYING or packet_type == PvZ.SEED_NONE:
		return
	var use := packet_type
	if packet_type == PvZ.SEED_IMITATER and imitater_type != PvZ.SEED_NONE:
		use = imitater_type
	if not App.easy_planting_cheat:
		if not active:
			App.play_sample("SOUND_BUZZER")
			if App.is_first_time_adventure_mode() and board.level == 1 and board.help_displayed[PvZ.ADVICE_CLICK_ON_SUN]:
				board.display_advice("[ADVICE_SEED_REFRESH]", PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL1, PvZ.ADVICE_SEED_REFRESH)
			return
		if not board.can_take_sun_money(board.get_current_plant_cost(packet_type, imitater_type)) and not board.has_conveyor_belt_seed_bank():
			App.play_sample("SOUND_BUZZER")
			board.out_of_money_counter = 70
			if App.is_first_time_adventure_mode() and board.level == 1 and board.help_displayed[PvZ.ADVICE_CLICK_ON_SUN]:
				board.display_advice("[ADVICE_CANT_AFFORD_PLANT]", PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL1, PvZ.ADVICE_CANT_AFFORD_PLANT)
			return
		if not board.planting_requirements_met(use):
			App.play_sample("SOUND_BUZZER")
			if _NEEDS_ADVICE.has(use):
				board.display_advice(_NEEDS_ADVICE[use][0], PvZ.MESSAGE_STYLE_HINT_LONG, _NEEDS_ADVICE[use][1])
			return
	for adv in [PvZ.ADVICE_CANT_AFFORD_PLANT, PvZ.ADVICE_PLANT_NEEDS_REPEATER, PvZ.ADVICE_PLANT_NEEDS_MELONPULT, PvZ.ADVICE_PLANT_NEEDS_SUNFLOWER,
			PvZ.ADVICE_PLANT_NEEDS_KERNELPULT, PvZ.ADVICE_PLANT_NEEDS_SPIKEWEED, PvZ.ADVICE_PLANT_NEEDS_MAGNETSHROOM,
			PvZ.ADVICE_PLANT_NEEDS_FUMESHROOM, PvZ.ADVICE_PLANT_NEEDS_LILYPAD]:
		board.clear_advice(adv)
	var co := board.cursor_object
	co.type = packet_type
	co.imitater_type = imitater_type
	co.cursor_type = PvZ.CURSOR_TYPE_PLANT_FROM_BANK
	co.seed_bank_index = index
	App.play_sample("SOUND_SEEDLIFT")
	if board.tutorial_state == PvZ.TUTORIAL_LEVEL_1_PICK_UP_PEASHOOTER:
		board.set_tutorial_state(PvZ.TUTORIAL_LEVEL_1_PLANT_PEASHOOTER)
	elif board.tutorial_state == PvZ.TUTORIAL_LEVEL_2_PICK_UP_SUNFLOWER:
		board.set_tutorial_state(PvZ.TUTORIAL_LEVEL_2_PLANT_SUNFLOWER if packet_type == PvZ.SEED_SUNFLOWER else PvZ.TUTORIAL_LEVEL_2_REFRESH_SUNFLOWER)
	elif board.tutorial_state == PvZ.TUTORIAL_MORESUN_PICK_UP_SUNFLOWER:
		board.set_tutorial_state(PvZ.TUTORIAL_MORESUN_PLANT_SUNFLOWER if packet_type == PvZ.SEED_SUNFLOWER else PvZ.TUTORIAL_MORESUN_REFRESH_SUNFLOWER)
	elif board.tutorial_state == PvZ.TUTORIAL_WHACK_A_ZOMBIE_PICK_SEED or board.tutorial_state == PvZ.TUTORIAL_WHACK_A_ZOMBIE_BEFORE_PICK_SEED:
		board.set_tutorial_state(PvZ.TUTORIAL_WHACK_A_ZOMBIE_COMPLETED)
	deactivate()

func was_planted() -> void:
	var board: Board = App.board
	if board.has_conveyor_belt_seed_bank():
		board.seed_bank.remove_seed(index)
	elif App.is_slot_machine_level():
		deactivate()
	else:
		times_used += 1
		refreshing = true
		refresh_time = Plant.get_refresh_time(packet_type, imitater_type)

func mouse_hit_test(tx: int, ty: int, hit: HitResult) -> bool:
	if slot_machine_count_down > 0 or packet_type == PvZ.SEED_NONE:
		hit.clear()
		return false
	if tx >= x + offset_x and tx < x + offset_x + width and ty >= y and ty < y + height:
		hit.object = self
		hit.object_type = PvZ.OBJECT_TYPE_SEEDPACKET
		return true
	hit.clear()
	return false

func set_packet_type(seed_type: int, imit_type: int = PvZ.SEED_NONE) -> void:
	packet_type = seed_type
	imitater_type = imit_type
	refresh_counter = 0
	refresh_time = 0
	refreshing = false
	active = true
	var use := seed_type
	if seed_type == PvZ.SEED_IMITATER and imit_type != PvZ.SEED_NONE:
		use = imit_type
	if App.is_scary_potter_level() or App.is_whack_a_zombie_level():
		return
	var rt := Plant.get_refresh_time(packet_type, imitater_type)
	if Plant.is_upgrade(use) or rt == 5000:
		refresh_time = 3500
		refreshing = true
		active = false
	elif rt == 3000:
		refresh_time = 2000
		refreshing = true
		active = false
