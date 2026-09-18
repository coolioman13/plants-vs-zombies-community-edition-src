class_name NetVersus
## Community edition online Versus rules (console-style): plants defend on the left of the red line, zombies are
## placed on the right, graves are the zombies' sunflowers (they make purple sun), and plants win by destroying
## three of the stationary target zombies. Everything here runs inside the deterministic simulation.

const SEED_GRAVE := PvZ.NUM_ZOMBIE_SEEDS          # custom packet: the zombies' sun producer
const FILTER_EFFECT_ZOMBIE_SUN := 3                # reanim filter_effect -> shader filter 4 (purple)
const LEVEL := 6                                   # day lawn, five rows, no special rules
const WAVE := 1                                    # from_wave used for placed zombies
const PLANT_MAX_COL := 4                           # plants: columns 0..4
const ZOMBIE_MIN_COL := 5                          # zombies: columns 5..8, graves 5..7
const TARGET_COL := 8
const TARGETS_TO_WIN := 3
const START_SUN_PLANTS := 150
const START_SUN_ZOMBIES := 150
const GRAVE_FIRST_SUN := 700
const GRAVE_SUN_RATE := 2400
const END_DELAY := 450

## [seed type, brain cost, recharge]
const ZOMBIE_SEEDS := [
	[PvZ.SEED_ZOMBIE_NORMAL, 50, 500],
	[PvZ.SEED_ZOMBIE_TRAFFIC_CONE, 75, 750],
	[PvZ.SEED_ZOMBIE_POLEVAULTER, 75, 750],
	[PvZ.SEED_ZOMBIE_PAIL, 125, 1500],
	[PvZ.SEED_ZOMBIE_SCREEN_DOOR, 100, 1500],
	[PvZ.SEED_ZOMBIE_LADDER, 150, 2000],
	[PvZ.SEED_ZOMBIE_DIGGER, 125, 2000],
	[PvZ.SEED_ZOMBIE_BUNGEE, 125, 2000],
	[PvZ.SEED_ZOMBIE_FOOTBALL, 175, 3000],
	[PvZ.SEED_ZOMBIE_BALLOON, 150, 2000],
	[PvZ.SEED_ZOMBONI, 175, 3000],
	[PvZ.SEED_ZOMBIE_POGO, 200, 2500],
	[PvZ.SEED_ZOMBIE_DANCER, 350, 4000],
	[PvZ.SEED_ZOMBIE_IMP, 50, 750],
	[PvZ.SEED_ZOMBIE_GARGANTUAR, 300, 5000],
	[SEED_GRAVE, 50, 750],
]

static func is_zombie_side_seed(st: int) -> bool:
	return st == SEED_GRAVE or (st >= PvZ.SEED_ZOMBIE_NORMAL and st < PvZ.NUM_ZOMBIE_SEEDS)

static func zombie_seed_list() -> Array:
	return ZOMBIE_SEEDS.map(func(e: Array) -> int: return e[0])

static func _entry(st: int) -> Array:
	for e in ZOMBIE_SEEDS:
		if e[0] == st:
			return e
	return []

static func cost(st: int) -> int:
	var e := _entry(st)
	return e[1] if not e.is_empty() else 0

static func refresh_time(st: int) -> int:
	var e := _entry(st)
	return e[2] if not e.is_empty() else 0

static func seed_zombie_type(st: int) -> int:
	if st == PvZ.SEED_ZOMBONI:
		return PvZ.ZOMBIE_ZAMBONI
	return Challenge.izombie_seed_type_to_zombie_type(st)

static func seed_name(st: int) -> String:
	if st == SEED_GRAVE:
		return "Grave"
	return TodStrings.translate("[%s]" % LawnCommon.zombie_def(seed_zombie_type(st))[LawnCommon.ZDEF_NAME])

static func draw_grave_seed(g: Graphics, px: float, py: float) -> void:
	var img := Res.get_image("IMAGE_TOMBSTONES")
	g.tod_draw_image_cel_scaled_f(img, px, py, 0, 2, g.scale_x, g.scale_y)

# ---------------------------------------------------------------- setup
static func setup_board(board: Board) -> void:
	board.sun_money = START_SUN_PLANTS
	board.vs_zombie_sun = START_SUN_ZOMBIES
	board.vs_zombie_sun_count_down = Tod.rand_range_int(900, 1300)
	board.enable_grave_stones = true
	board.vs_targets.clear()
	for row in BoardCore.MAX_GRID_SIZE_Y:
		if board.plant_row[row] != PvZ.PLANTROW_NORMAL:
			continue
		var z := board.add_zombie_in_row(PvZ.ZOMBIE_LADDER, row, WAVE, true)
		if z:
			make_target(board, z)
			board.vs_targets.append(z)

static func make_target(board: Board, z: Zombie) -> void:
	z.vs_target = true
	z.pos_x = board.grid_to_pixel_x(TARGET_COL, z.row) - 15  # clear of the bushes on the right edge
	z.x = int(z.pos_x)
	z.shield_health = 1100
	z.body_health = 500
	z.zombie_phase = PvZ.PHASE_ZOMBIE_NORMAL
	var r := Zombie.rv(z.body_reanim)
	if r:
		r.set_image_override("Zombie_ladder_1", Res.get_image("IMAGE_REANIM_ZOMBIE_SCREENDOOR1"))
	z.play_zombie_reanim("anim_idle", Reanimation.REANIM_LOOP, 0, 12.0)

static func targets_destroyed(board: Board) -> int:
	var n := 0
	for z in board.vs_targets:
		if z == null or z.dead or z.is_dead_or_dying() or z.mind_controlled:
			n += 1
	return n

# ---------------------------------------------------------------- per frame
static func update(board: Board) -> void:
	if board.vs_winner != -1:
		board.vs_end_counter += 1
		return
	if App.game_scene != PvZ.SCENE_PLAYING:
		return
	if targets_destroyed(board) >= TARGETS_TO_WIN:
		board.vs_winner = NetSession.TEAM_PLANTS
		board.vs_end_counter = 0
		App.music.stop_all_music()
		App.play_foley(PvZ.FOLEY_WINMUSIC)
		for z in board.zombies:
			if not z.dead and not z.is_dead_or_dying():
				z.take_damage(1800, 0)
	for gi in board.grid_items:
		if gi.dead or not gi.vs_grave:
			continue
		gi.sun_count -= 1
		if gi.sun_count <= 0:
			gi.sun_count = GRAVE_SUN_RATE + Tod.rand_int(200)
			var px := board.grid_to_pixel_x(gi.grid_x, gi.grid_y) + 10
			var py := board.grid_to_pixel_y(gi.grid_x, gi.grid_y)
			var coin := board.add_coin(px, py, PvZ.COIN_SUN, PvZ.COIN_MOTION_FROM_PLANT)
			coin.make_zombie_sun()
			App.play_foley(PvZ.FOLEY_SPAWN_SUN)

static func update_sun_spawning(board: Board) -> void:
	board.sun_count_down -= 1
	if board.sun_count_down <= 0:
		board.num_suns_fallen += 1
		board.sun_count_down = mini(PvZ.SUN_COUNTDOWN_MAX, PvZ.SUN_COUNTDOWN + board.num_suns_fallen * 10) + Tod.rand_int(PvZ.SUN_COUNTDOWN_RANGE)
		var right := board.grid_to_pixel_x(PLANT_MAX_COL, 0) + 30
		board.add_coin(Tod.rand_range_int(100 + PvZ.BOARD_ADDITIONAL_WIDTH, right), 60, PvZ.COIN_SUN, PvZ.COIN_MOTION_FROM_SKY)
	board.vs_zombie_sun_count_down -= 1
	if board.vs_zombie_sun_count_down <= 0:
		board.vs_zombie_suns_fallen += 1
		board.vs_zombie_sun_count_down = mini(PvZ.SUN_COUNTDOWN_MAX, PvZ.SUN_COUNTDOWN + board.vs_zombie_suns_fallen * 10) + Tod.rand_int(PvZ.SUN_COUNTDOWN_RANGE)
		var left := board.grid_to_pixel_x(ZOMBIE_MIN_COL, 0) + 10
		var coin := board.add_coin(Tod.rand_range_int(left, left + 260), 60, PvZ.COIN_SUN, PvZ.COIN_MOTION_FROM_SKY)
		coin.make_zombie_sun()

# ---------------------------------------------------------------- planting rules
static func plant_restriction(board: Board, gx: int, gy: int, seed_type: int) -> int:
	if is_zombie_side_seed(seed_type):
		return can_place(board, gx, gy, seed_type)
	if gx > PLANT_MAX_COL:
		if seed_type == PvZ.SEED_GRAVEBUSTER and board.get_grave_stone_at(gx, gy) != null:
			return PvZ.PLANTING_OK
		return PvZ.PLANTING_NOT_PASSED_LINE
	return PvZ.PLANTING_OK

static func can_place(board: Board, gx: int, gy: int, seed_type: int) -> int:
	if gx < ZOMBIE_MIN_COL or gx >= BoardCore.MAX_GRID_SIZE_X or gy < 0 or gy >= BoardCore.MAX_GRID_SIZE_Y:
		return PvZ.PLANTING_NOT_HERE
	if board.plant_row[gy] != PvZ.PLANTROW_NORMAL:
		return PvZ.PLANTING_NOT_HERE
	if seed_type == SEED_GRAVE:
		if gx >= TARGET_COL or not board.can_add_grave_stone_at(gx, gy):
			return PvZ.PLANTING_NOT_HERE
		if board.get_top_plant_at(gx, gy, PvZ.TOPPLANT_ANY) != null:
			return PvZ.PLANTING_NOT_HERE
	return PvZ.PLANTING_OK

## Zombie-team click with a zombie or grave packet in the cursor (runs with the zombie sun swapped in).
static func mouse_down_with_zombie(board: Board, mx: int, my: int, seed_type: int) -> void:
	var gx := board.pixel_to_grid_x(mx, my)
	var gy := board.pixel_to_grid_y(mx, my)
	if can_place(board, gx, gy, seed_type) != PvZ.PLANTING_OK:
		if board.net_exec_is_local():
			board.display_advice("Zombies can only be placed right of the red line.", PvZ.MESSAGE_STYLE_HINT_FAST, PvZ.ADVICE_NONE)
		return
	if not board.take_sun_money(Plant.get_cost(seed_type)):
		return
	if seed_type == SEED_GRAVE:
		var gi := board.add_a_grave_stone(gx, gy)
		gi.vs_grave = true
		gi.grid_item_counter = 0
		gi.sun_count = GRAVE_FIRST_SUN
		gi.add_grave_stone_particles()
	else:
		var zt := seed_zombie_type(seed_type)
		var z := board.add_zombie_in_row(zt, gy, WAVE, true)
		if z == null:
			return
		if zt != PvZ.ZOMBIE_BUNGEE:
			z.pos_x = board.grid_to_pixel_x(gx, gy) + 10
			z.x = int(z.pos_x)
		App.add_tod_particle(board.grid_to_pixel_x(gx, gy) + 40, board.grid_to_pixel_y(gx, gy) + 90,
			BoardCore.make_render_order(PvZ.RENDER_LAYER_ZOMBIE, gy, 1), PvZ.PARTICLE_ZOMBIE_RISE)
		App.play_foley(PvZ.FOLEY_DIRT_RISE)
	var idx := board.cursor_object.seed_bank_index
	if idx >= 0 and idx < board.seed_bank.num_packets:
		board.seed_bank.seed_packets[idx].was_planted()
	board.clear_cursor()

static func draw_line(board: Board, g: Graphics) -> void:
	var stripe := Res.get_image("IMAGE_WALLNUT_BOWLINGSTRIPE")
	g.draw_image(stripe, board.grid_to_pixel_x(ZOMBIE_MIN_COL, 0) - 12, 77 + PvZ.BOARD_OFFSET_Y)
