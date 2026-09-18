class_name CustomRuntime
## Plays a LevelDef. Owns the level's stage overrides, its wave schedule, its Crazy Dave dialogue
## and its block script, and exposes the handful of queries the board asks while a custom level runs.
##
## The board calls into here through CustomRuntime.active; when nothing is loaded every hook is a
## cheap `null` check, so the stock game is untouched.

static var active: CustomRuntime = null

## Where to go when the level ends: back to the editor (test run) or to the level browser.
enum { RETURN_BROWSER, RETURN_EDITOR }

var level: LevelDef
var machine: LevelScript.Machine
var board: Board = null
var return_to := RETURN_BROWSER
var zombies_killed := 0
var ticks_elapsed := 0
var wave_delay_override := -1
var runtime_zombie_speed := 1.0
var last_conveyor_seed := PvZ.SEED_NONE
var runtime_zombie_health := 1.0
var boss_zombie: Zombie = null
var boss_phase := 1
var dave_queue: Array = []
var _lane_overrides: Dictionary = {}     ## row -> PLANTROW_*, from the set_lane_type block
var _win_pending := false
var _lose_pending := false

# ================================================================ lifecycle
static func start(l: LevelDef, where: int = RETURN_BROWSER) -> void:
	stop()
	var rt := CustomRuntime.new()
	rt.level = l
	rt.return_to = where
	CustomAssets.install(l)
	CustomDefs.install(l)
	active = rt
	rt.machine = LevelScript.Machine.new(rt, l.script_data)
	App.playing_quickplay = true
	App.game_mode = PvZ.GAMEMODE_ADVENTURE
	App.quick_level = l.level_number
	App.crazy_seeds = false
	App.new_game()

static func stop() -> void:
	if active != null and active.machine != null:
		active.machine.stop_all()
	active = null
	CustomDefs.uninstall()
	CustomAssets.uninstall()

static func is_running() -> bool:
	return active != null

## The board a custom level is attached to, or null.
static func current_level() -> LevelDef:
	return active.level if active != null else null

func attach(b: Board) -> void:
	board = b
	zombies_killed = 0
	ticks_elapsed = 0
	boss_zombie = null
	boss_phase = 1
	_win_pending = false
	_lose_pending = false
	runtime_zombie_speed = level.zombie_speed_scale
	runtime_zombie_health = level.zombie_health_scale
	_lane_overrides.clear()

# ================================================================ stage queries (board hooks)
func lane_type(gy: int) -> int:
	if _lane_overrides.has(gy):
		return int(_lane_overrides[gy])
	return level.lane_type(gy)

func apply_grid(b: Board) -> void:
	for gy in BoardCore.MAX_GRID_SIZE_Y:
		b.plant_row[gy] = lane_type(gy)
	for gx in BoardCore.MAX_GRID_SIZE_X:
		for gy in BoardCore.MAX_GRID_SIZE_Y:
			b.grid_square_type[gx][gy] = level.cell_square_type(gx, gy)

func is_night() -> bool:
	return level.night

func has_pool_water() -> bool:
	## The animated water overlay is drawn only when the level asked for it, so a custom background
	## can declare water lanes purely as a rule and paint them itself.
	return level.pool_water

func has_six_rows() -> bool:
	return level.geometry == LevelDef.GEOM_POOL

func has_roof() -> bool:
	return level.geometry == LevelDef.GEOM_ROOF

func has_fog() -> bool:
	return level.fog

func has_bushes() -> bool:
	return level.bushes and not level.uses_custom_background()

func has_graves() -> bool:
	return level.graves

func walks_in_from_right() -> bool:
	return level.walk_in_from_right

func row_playable(gy: int) -> bool:
	if level.force_zombie_rows.has(gy):
		return true
	return lane_type(gy) != PvZ.PLANTROW_DIRT

# ================================================================ level setup
func init_level(b: Board) -> void:
	attach(b)
	b.background = level.bg_builtin
	apply_grid(b)
	b.num_waves = level.waves.size()
	b.current_wave = 0
	b.total_spawned_waves = 0
	b.sun_money = level.start_sun
	b.sun_count_down = level.sun_drop_first if level.sun_drop else 0
	b.zombie_count_down = _wave_delay(0)
	b.zombie_count_down_start = b.zombie_count_down
	b.zombie_health_to_next_wave = -1
	b.show_shovel = level.shovel
	if level.graves:
		b.enable_grave_stones = true

func place_board_items(b: Board) -> void:
	for item in level.preset_items:
		var gx := int(item.get("x", 0))
		var gy := int(item.get("y", 0))
		match int(item.get("type", PvZ.GRIDITEM_GRAVESTONE)):
			PvZ.GRIDITEM_GRAVESTONE:
				b.enable_grave_stones = true
				b.add_a_grave_stone(gx, gy)
			PvZ.GRIDITEM_CRATER:
				b.add_a_crater(gx, gy)
			PvZ.GRIDITEM_LADDER:
				b.add_a_ladder(gx, gy)
	for p in level.preset_plants:
		var seed := int(p.get("seed", PvZ.SEED_PEASHOOTER))
		var cid := int(p.get("custom", -1))
		if cid >= 0:
			var st := CustomDefs.seed_type_for_cid(cid)
			if st != PvZ.SEED_NONE:
				seed = st
		b.add_plant(int(p.get("x", 0)), int(p.get("y", 0)), seed, int(p.get("imitater", PvZ.SEED_NONE)))

func setup_seed_bank(b: Board) -> void:
	match level.seed_mode:
		LevelDef.SEEDS_PRESET:
			var slots: Array = level.preset_seeds
			b.seed_bank.num_packets = clampi(slots.size(), 0, PvZ.SEEDBANK_MAX)
			b.seed_bank.update_width()
			for i in b.seed_bank.num_packets:
				b.seed_bank.seed_packets[i].x = b.get_seed_packet_position_x(i)
				b.seed_bank.seed_packets[i].set_packet_type(int(slots[i]))
		LevelDef.SEEDS_NONE:
			b.seed_bank.num_packets = 0
			b.seed_bank.update_width()

func num_seeds_in_bank() -> int:
	match level.seed_mode:
		LevelDef.SEEDS_PRESET:
			return clampi(level.preset_seeds.size(), 0, PvZ.SEEDBANK_MAX)
		LevelDef.SEEDS_NONE:
			return 0
		LevelDef.SEEDS_CONVEYOR:
			return PvZ.SEEDBANK_MAX
	return clampi(level.num_choose, 1, PvZ.SEEDBANK_MAX)

func uses_chooser() -> bool:
	return level.seed_mode == LevelDef.SEEDS_CHOOSER

func uses_conveyor() -> bool:
	return level.seed_mode == LevelDef.SEEDS_CONVEYOR

# ---------------------------------------------------------------- conveyor belt
## How much longer (or shorter) than the stock belt this level waits between packets. The editor's
## "Belt speed" is a multiplier, so 4 is the pace of the base game's conveyor levels.
func conveyor_interval_scale() -> float:
	return 4.0 / float(maxi(1, level.conveyor_speed))

## `[[seed_type, weight], ...]` for the belt, with anything already at its cap dropped. An empty
## belt list means "everything this level allows", so a level that only ticked the conveyor box
## still hands out plants.
func conveyor_picks(b: Board) -> Array:
	var out: Array = []
	if level.conveyor_seeds.is_empty():
		for st in _default_conveyor_seeds():
			out.append([st, 100])
	else:
		for e in level.conveyor_seeds:
			var st := int((e as Dictionary).get("seed", PvZ.SEED_NONE))
			if st == PvZ.SEED_NONE:
				continue
			var weight := maxi(0, int((e as Dictionary).get("weight", 100)))
			var cap := int((e as Dictionary).get("max", 0))
			if cap > 0 and b.seed_bank.count_of_type_on_conveyor_belt(st) >= cap:
				continue
			if weight > 0:
				out.append([st, weight])
	# the base game leans away from whatever it just handed out, and stops a single type filling
	# the tray; keep that so a one-entry belt still feels like a conveyor
	if out.size() > 2:
		for pick in out:
			var in_bank := b.seed_bank.count_of_type_on_conveyor_belt(int(pick[0]))
			if in_bank >= 4:
				pick[1] = 1
			elif in_bank >= 3:
				pick[1] = 5
			elif int(pick[0]) == last_conveyor_seed:
				pick[1] = maxi(1, int(pick[1]) / 2)
	return out

func _default_conveyor_seeds() -> Array:
	var out: Array = []
	if not level.allowed_seeds.is_empty():
		out = level.allowed_seeds.duplicate()
	else:
		for st in PvZ.NUM_SEED_TYPES:
			if st == PvZ.SEED_SPROUT or st == PvZ.SEED_LEFTPEATER or Plant.is_upgrade(st):
				continue
			if App.seed_type_available(st):
				out.append(st)
	for st in CustomDefs.custom_plant_seed_types():
		out.append(st)
	return out

## Picks the next packet for the belt and remembers it. SEED_NONE when the level offers nothing.
func next_conveyor_seed(b: Board) -> int:
	var picks := conveyor_picks(b)
	if picks.is_empty():
		return PvZ.SEED_NONE
	var chosen = Tod.pick_from_weighted_array(picks)
	if chosen == null:
		return PvZ.SEED_NONE
	last_conveyor_seed = int(chosen)
	return last_conveyor_seed

## Which plants the seed chooser offers. An empty allow-list means "everything owned", plus every
## custom plant this level defines.
func seed_allowed(st: int) -> bool:
	if CustomDefs.is_custom_plant(st):
		return true
	if level.allowed_seeds.is_empty():
		return true
	return level.allowed_seeds.has(st)

func start_music() -> void:
	var custom := CustomAssets.get_sound(level.music_custom)
	if custom != null:
		App.music.stop_all_music()
		_play_custom_music(custom)
		return
	if level.music_tune >= 0:
		App.music.play_music(level.music_tune)

var _music_player: AudioStreamPlayer = null

func _play_custom_music(stream: AudioStream) -> void:
	if _music_player == null or not is_instance_valid(_music_player):
		_music_player = AudioStreamPlayer.new()
		_music_player.name = "CustomLevelMusic"
		App.add_child(_music_player)
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = true
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = true
	_music_player.stream = stream
	_music_player.volume_db = linear_to_db(clampf(App.get_music_volume(), 0.0001, 1.0))
	_music_player.play()

func stop_custom_music() -> void:
	if _music_player != null and is_instance_valid(_music_player):
		_music_player.stop()

# ================================================================ waves
func _wave_delay(index: int) -> int:
	if index < 0 or index >= level.waves.size():
		return PvZ.ZOMBIE_COUNTDOWN
	var d := int(level.waves[index].get("delay", 0))
	if d > 0:
		return d
	return PvZ.ZOMBIE_COUNTDOWN_FIRST_WAVE if index == 0 else PvZ.ZOMBIE_COUNTDOWN + Tod.rand_int(PvZ.ZOMBIE_COUNTDOWN_RANGE)

## Ticks to wait before wave [param index] arrives (0 in the editor means "the usual pause").
func wave_delay(index: int) -> int:
	return _wave_delay(index)

## Fraction of the previous wave that has to be left before the next one is released early.
func wave_health_trigger(index: int) -> float:
	if index < 0 or index >= level.waves.size():
		return 0.6
	return clampf(float(level.waves[index].get("health_trigger", 0.6)), 0.0, 1.0)

func wave_is_flag(index: int) -> bool:
	return level.wave_is_flag(index)

## Replaces BoardCore's zombie-wave picker: a custom level spells its waves out.
func spawn_wave(b: Board, index: int) -> void:
	if index < 0 or index >= level.waves.size():
		return
	var wave: Dictionary = level.waves[index]
	for entry in wave.get("entries", []):
		var count := maxi(1, int(entry.get("count", 1)))
		var row := int(entry.get("row", -1))
		var cid := int(entry.get("custom", -1))
		var zt := int(entry.get("zombie", PvZ.ZOMBIE_NORMAL))
		for i in count:
			spawn_zombie(b, zt, cid, row, index)
	var msg := str(wave.get("message", ""))
	if msg != "":
		b.display_advice(msg, PvZ.MESSAGE_STYLE_HINT_FAST, PvZ.ADVICE_NONE)
	var dave_line := level.dave_line_for_wave(index)
	if dave_line != "":
		say_dave(dave_line)
	var event := str(wave.get("event", ""))
	if event != "":
		machine.broadcast(event)
	machine.fire("when_any_wave", {"wave": index})
	machine.fire("when_wave", {"wave": index})
	if wave_is_flag(index):
		machine.fire("when_flag_wave", {"wave": index})
	if index == level.waves.size() - 1:
		machine.fire("when_final_wave", {"wave": index})
	var boss_wave := int(level.boss.get("enter_wave", -1))
	if CustomDefs.boss_enabled() and ((boss_wave < 0 and index == level.waves.size() - 1) or boss_wave == index):
		spawn_boss(b)

## Creates one zombie, applying the custom profile when [param cid] names one.
func spawn_zombie(b: Board, zombie_type: int, cid: int, row: int, wave: int) -> Zombie:
	var zt := zombie_type
	if cid >= 0 and CustomDefs.has_zombie(cid):
		zt = CustomDefs.zombie_base(cid)
	var use_row := row
	if use_row < 0 or not row_playable(use_row):
		use_row = b.pick_row_for_new_zombie(zt)
	if use_row < 0:
		return null
	var z: Zombie = b.alloc_zombie()
	z.custom_id = cid
	z.zombie_initialize(use_row, zt, Tod.rand_int(5) == 0, null,
		wave, not has_bushes() or App.game_scene != PvZ.SCENE_PLAYING)
	if z.dead:
		return null
	if not is_equal_approx(runtime_zombie_health, 1.0):
		z.body_health = maxi(1, int(z.body_health * runtime_zombie_health))
		z.body_max_health = z.body_health
	if not is_equal_approx(runtime_zombie_speed, 1.0):
		z.vel_x *= runtime_zombie_speed
	if cid >= 0:
		var p := CustomDefs.zombie_profile(cid)
		var ev := str(p.get("spawn_event", ""))
		if ev != "":
			machine.broadcast(ev)
	return z

func spawn_boss(b: Board) -> void:
	if boss_zombie != null and not boss_zombie.dead:
		return
	var cfg := CustomDefs.boss_config()
	boss_zombie = b.add_zombie(PvZ.ZOMBIE_BOSS, 0)
	if boss_zombie == null:
		return
	var hp := maxi(1, int(cfg.get("health", 40000)))
	boss_zombie.body_health = hp
	boss_zombie.body_max_health = hp
	boss_phase = 1
	var tune := int(cfg.get("music", PvZ.MUSIC_TUNE_FINAL_BOSS_BRAINIAC_MANIAC))
	if tune >= 0:
		App.music.play_music(tune)

func update_boss() -> void:
	if boss_zombie == null or boss_zombie.dead:
		return
	var cfg := CustomDefs.boss_config()
	var phases := maxi(1, int(cfg.get("phases", 3)))
	var frac := 1.0 - float(boss_zombie.body_health) / float(maxi(1, boss_zombie.body_max_health))
	var want := clampi(int(frac * phases) + 1, 1, phases)
	if want != boss_phase:
		boss_phase = want
		machine.fire("when_boss_phase", {"phase": boss_phase})

# ================================================================ crazy dave
func say_dave(text: String) -> void:
	if App.crazy_dave_state == PvZ.CRAZY_DAVE_OFF:
		App.crazy_dave_enter()
	App.crazy_dave_message_index = -1
	App.crazy_dave_talk_message(text)

func intro_lines() -> Array:
	return level.dave_intro if level.dave_enabled else []

func win_lines() -> Array:
	return level.dave_win if level.dave_enabled else []

# ================================================================ per-tick
func update() -> void:
	if board == null:
		return
	ticks_elapsed += 1
	update_boss()
	if machine != null:
		machine.update()
	_check_win_conditions()

func notify_zombie_died(z: Zombie) -> void:
	zombies_killed += 1
	if machine != null:
		machine.fire("when_zombie_dies", {"row": z.row, "zombie": z.zombie_type, "custom": z.custom_id})
	if z.custom_id >= 0:
		var p := CustomDefs.zombie_profile(z.custom_id)
		if bool(p.get("explode_on_death", false)) and board != null:
			var dmg := int(p.get("explode_damage", 0))
			if dmg > 0:
				board.kill_all_plants_in_radius(int(z.pos_x) + 40, int(z.pos_y) + 40, 90)
		var ev := str(p.get("death_event", ""))
		if ev != "":
			machine.broadcast(ev)
	if z == boss_zombie:
		var ev2 := str(CustomDefs.boss_config().get("death_event", ""))
		if ev2 != "":
			machine.broadcast(ev2)

func notify_plant_placed(p: Plant) -> void:
	if machine != null:
		machine.fire("when_plant_placed", {"row": p.row, "col": p.plant_col, "plant": p.seed_type})

func notify_plant_eaten(p: Plant) -> void:
	if machine != null:
		machine.fire("when_plant_eaten", {"row": p.row, "col": p.plant_col, "plant": p.seed_type})

func notify_mower_fired(row: int) -> void:
	if machine != null:
		machine.fire("when_mower_fires", {"row": row})

func notify_sun_collected(amount: int) -> void:
	if machine != null:
		machine.fire("when_sun_collected", {"amount": amount})

func notify_level_start() -> void:
	if machine != null:
		machine.fire("when_level_start")
	start_music()

func _check_win_conditions() -> void:
	if board == null or board.has_level_award_dropped() or board.level_complete:
		return
	if _lose_pending:
		_lose_pending = false
		var z := board.get_winning_zombie()
		board.zombies_won(z)
		if machine != null:
			machine.fire("when_level_lost")
		return
	var won := _win_pending
	if not won:
		match level.win_mode:
			LevelDef.WIN_TIME:
				won = level.win_time > 0 and ticks_elapsed >= level.win_time
			LevelDef.WIN_KILLS:
				won = level.win_kills > 0 and zombies_killed >= level.win_kills
	if won:
		_win_pending = false
		do_win()

func do_win() -> void:
	if board == null or board.has_level_award_dropped() or board.level_complete:
		return
	board.level_award_spawned = true
	App.board_result = PvZ.BOARDRESULT_WON
	board.remove_all_zombies()
	App.add_tod_particle(PvZ.BOARD_WIDTH / 2, PvZ.BOARD_HEIGHT / 2, PvZ.RENDER_LAYER_TOP, PvZ.PARTICLE_SCREEN_FLASH)
	board.fade_out_level()
	if machine != null:
		machine.fire("when_level_won")

# ================================================================ script actions
func run_action(op: String, args: Dictionary, context: Dictionary) -> void:
	var b := board
	if b == null:
		return
	match op:
		"spawn_zombie":
			for i in maxi(1, int(args.get("count", 1))):
				spawn_zombie(b, int(args.get("zombie", PvZ.ZOMBIE_NORMAL)), -1, int(args.get("row", -1)), b.current_wave)
		"spawn_custom_zombie":
			var cid := int(args.get("cid", 0))
			for i in maxi(1, int(args.get("count", 1))):
				spawn_zombie(b, CustomDefs.zombie_base(cid), cid, int(args.get("row", -1)), b.current_wave)
		"spawn_zombie_at":
			var z := spawn_zombie(b, int(args.get("zombie", PvZ.ZOMBIE_NORMAL)), -1, int(args.get("row", 0)), b.current_wave)
			if z != null:
				z.pos_x = b.grid_to_pixel_x(int(args.get("col", 8)), z.row)
				z.x = int(z.pos_x)
		"kill_zombies_row":
			var row := int(args.get("row", -1))
			for z2 in b.zombies.duplicate():
				if not z2.dead and not z2.is_dead_or_dying() and (row < 0 or z2.row == row):
					z2.take_damage(20000, 0)
		"kill_all_zombies":
			b.remove_all_zombies()
		"freeze_zombies":
			var ticks := int(args.get("seconds", 10)) * LevelScript.TICKS_PER_SECOND
			for z3 in b.zombies:
				if not z3.dead and not z3.is_dead_or_dying():
					z3.chilled_counter = maxi(z3.chilled_counter, ticks)
		"set_zombie_speed":
			runtime_zombie_speed = maxf(0.05, float(args.get("scale", 1.0)))
		"set_zombie_health_scale":
			runtime_zombie_health = maxf(0.05, float(args.get("scale", 1.0)))
		"plant_at":
			b.add_plant(int(args.get("col", 0)), int(args.get("row", 0)), int(args.get("plant", PvZ.SEED_PEASHOOTER)))
		"remove_plant_at":
			var p := b.get_top_plant_at(int(args.get("col", 0)), int(args.get("row", 0)), PvZ.TOPPLANT_ANY)
			if p != null:
				p.die()
		"give_packet":
			_give_packet(b, int(args.get("plant", PvZ.SEED_PEASHOOTER)))
		"remove_packet":
			_remove_packet(b, int(args.get("plant", PvZ.SEED_PEASHOOTER)))
		"recharge_all":
			for i in b.seed_bank.num_packets:
				var pk: SeedPacket = b.seed_bank.seed_packets[i]
				pk.refresh_counter = 0
				pk.refreshing = false
				pk.activate()
		"add_sun":
			b.add_sun_money(int(args.get("amount", 0)))
		"set_sun":
			b.sun_money = maxi(0, int(args.get("amount", 0)))
		"drop_sun":
			for i in maxi(1, int(args.get("count", 1))):
				b.add_coin(Tod.rand_range_int(100 + PvZ.BOARD_ADDITIONAL_WIDTH, 649 + PvZ.BOARD_ADDITIONAL_WIDTH),
					60, PvZ.COIN_SUN, PvZ.COIN_MOTION_FROM_SKY)
		"shake":
			b.shake_board(4, 4)
		"spawn_item":
			var gx := int(args.get("col", 5))
			var gy := int(args.get("row", 0))
			match int(args.get("item", PvZ.GRIDITEM_GRAVESTONE)):
				PvZ.GRIDITEM_GRAVESTONE:
					b.enable_grave_stones = true
					b.add_a_grave_stone(gx, gy)
				PvZ.GRIDITEM_CRATER:
					b.add_a_crater(gx, gy)
				PvZ.GRIDITEM_LADDER:
					b.add_a_ladder(gx, gy)
		"set_lane_type":
			var row2 := int(args.get("row", 0))
			_lane_overrides[row2] = clampi(int(args.get("lane", PvZ.PLANTROW_NORMAL)), 0, 3)
			apply_grid(b)
		"set_ice":
			var r := clampi(int(args.get("row", 0)), 0, BoardCore.MAX_GRID_SIZE_Y - 1)
			b.ice_timer[r] = int(args.get("seconds", 10)) * LevelScript.TICKS_PER_SECOND
			b.ice_min_x[r] = 200 + PvZ.BOARD_ADDITIONAL_WIDTH
		"give_mower":
			_give_mower(b, int(args.get("row", 0)))
		"message":
			b.display_advice(str(args.get("text", "")), PvZ.MESSAGE_STYLE_HINT_FAST, PvZ.ADVICE_NONE)
		"dave_say":
			say_dave(str(args.get("text", "")))
		"dave_leave":
			App.crazy_dave_leave()
		"play_sound":
			App.play_sample(str(args.get("sound", "")))
		"play_music":
			App.music.play_music(int(args.get("music", PvZ.MUSIC_TUNE_DAY_GRASSWALK)))
		"stop_music":
			App.music.stop_all_music()
			stop_custom_music()
		"screen_flash":
			App.add_tod_particle(PvZ.BOARD_WIDTH / 2, PvZ.BOARD_HEIGHT / 2, PvZ.RENDER_LAYER_TOP, PvZ.PARTICLE_SCREEN_FLASH)
		"win_level":
			_win_pending = true
		"lose_level":
			_lose_pending = true
		"start_next_wave":
			b.zombie_count_down = 1
		"set_wave_countdown":
			b.zombie_count_down = maxi(1, int(args.get("seconds", 10)) * LevelScript.TICKS_PER_SECOND)
			b.zombie_count_down_start = b.zombie_count_down
		"spawn_boss":
			spawn_boss(b)
		"set_boss_phase":
			boss_phase = maxi(1, int(args.get("phase", 1)))

func _give_packet(b: Board, seed_type: int) -> void:
	if b.seed_bank.num_packets >= PvZ.SEEDBANK_MAX:
		return
	var idx := b.seed_bank.num_packets
	b.seed_bank.num_packets += 1
	b.seed_bank.update_width()
	for i in b.seed_bank.num_packets:
		b.seed_bank.seed_packets[i].x = b.get_seed_packet_position_x(i)
	b.seed_bank.seed_packets[idx].set_packet_type(seed_type)

func _remove_packet(b: Board, seed_type: int) -> void:
	var found := -1
	for i in b.seed_bank.num_packets:
		if b.seed_bank.seed_packets[i].packet_type == seed_type:
			found = i
			break
	if found == -1:
		return
	for i in range(found, b.seed_bank.num_packets - 1):
		var next: SeedPacket = b.seed_bank.seed_packets[i + 1]
		b.seed_bank.seed_packets[i].set_packet_type(next.packet_type, next.imitater_type)
	b.seed_bank.num_packets -= 1
	b.seed_bank.seed_packets[b.seed_bank.num_packets].set_packet_type(PvZ.SEED_NONE)
	b.seed_bank.update_width()
	for i in b.seed_bank.num_packets:
		b.seed_bank.seed_packets[i].x = b.get_seed_packet_position_x(i)

func _give_mower(b: Board, row: int) -> void:
	for m in b.lawn_mowers:
		if not m.dead and m.row == row and m.mower_state != PvZ.MOWER_TRIGGERED and m.mower_state != PvZ.MOWER_SQUISHED:
			return
	var mower := LawnMower.new()
	b.lawn_mowers.append(mower)
	mower.lawn_mower_initialize(row)

# ================================================================ script queries
func query(op: String, args: Dictionary, _context: Dictionary):
	var b := board
	if b == null:
		return 0
	match op:
		"zombies_alive":
			var n := 0
			for z in b.zombies:
				if not z.dead and not z.is_dead_or_dying():
					n += 1
			return n
		"zombies_alive_row":
			var row := int(args.get("row", 0))
			var n2 := 0
			for z in b.zombies:
				if not z.dead and not z.is_dead_or_dying() and z.row == row:
					n2 += 1
			return n2
		"zombies_killed":
			return zombies_killed
		"plants_alive":
			var n3 := 0
			for p in b.plants:
				if not p.dead:
					n3 += 1
			return n3
		"plant_at_reporter":
			return b.get_top_plant_at(int(args.get("col", 0)), int(args.get("row", 0)), PvZ.TOPPLANT_ANY) != null
		"sun_amount":
			return b.sun_money
		"current_wave":
			return b.current_wave
		"total_waves":
			return b.num_waves
		"time_elapsed":
			return float(ticks_elapsed) / float(LevelScript.TICKS_PER_SECOND)
		"boss_health":
			if boss_zombie != null and not boss_zombie.dead:
				return boss_zombie.body_health
			return 0
	return 0
