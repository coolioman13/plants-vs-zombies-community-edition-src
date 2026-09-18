class_name BoardUpdate
extends BoardCore
## Board part 2: per-tick simulation (spawning, waves, sun, ice, fog, tutorial, progress meter).

## Online matches only advance the board inside NetSession's lockstep frames.
func update_all(modal_block: Array) -> void:
	if is_net_game() and not net_stepping:
		return
	super.update_all(modal_block)

func row_can_have_zombies(the_row: int) -> bool:
	if the_row < 0 or the_row >= MAX_GRID_SIZE_Y:
		return false
	var cl := custom_level()
	if cl != null:
		return cl.row_playable(the_row)
	return (App.game_mode == PvZ.GAMEMODE_CHALLENGE_RESODDED and the_row <= 4) or plant_row[the_row] != PvZ.PLANTROW_DIRT

func is_scary_potter_dave_talking() -> bool:
	return App.is_scary_potter_level() and next_survival_stage_counter > 0 and App.crazy_dave_state != PvZ.CRAZY_DAVE_OFF

func is_final_scary_potter_stage() -> bool:
	if not App.is_scary_potter_level():
		return false
	if App.is_adventure_mode():
		return challenge.survival_stage == 2
	return true

func is_final_survival_stage() -> bool:
	return false

func has_level_award_dropped() -> bool:
	return level_award_spawned or next_survival_stage_counter > 0 or board_fade_out_counter >= 0

func show_coin_bank(duration: int = 1000) -> void:
	coin_bank_fade_count = duration

func pause(p: bool) -> void:
	if paused == p:
		return
	paused = p
	if p and App.player_info.coins > 0:
		show_coin_bank()
	if not p or App.game_scene != PvZ.SCENE_LEVEL_INTRO:
		App.sound_system.game_pause(p)
		App.music.game_music_pause(p)

func pick_special_grave_stone() -> void:
	var picks: Array = []
	for gi in grid_items:
		if not gi.dead and gi.grid_item_type == PvZ.GRIDITEM_GRAVESTONE:
			picks.append(gi)
	if picks.size() > 0:
		(Tod.pick_from_array(picks) as GridItem).grid_item_state = PvZ.GRIDITEM_STATE_GRAVESTONE_SPECIAL

# ================================================================ grave / pool / sky spawns
func spawn_zombies_from_pool() -> void:
	if ice_trap_counter > 0:
		return
	var count: int
	var points: int
	if level == 21 or level == 22 or level == 31 or level == 32:
		count = 2; points = 3
	elif level in [23, 24, 25, 33, 34, 35]:
		count = 3; points = 5
	else:
		count = 3; points = 7
	var grid: Array = []
	for gx in range(5, MAX_GRID_SIZE_X):
		for gy in range(2, 4):
			grid.append({"x": gx, "y": gy, "weight": 10000})
	for i in count:
		var cell: Dictionary = Tod.pick_from_weighted_grid_array(grid)
		cell.weight = 0
		var zt := pick_grave_rising_zombie_type(points)
		var z := add_zombie_in_row(zt, cell.y, current_wave, true)
		if z == null:
			return
		z.rise_from_grave(cell.x, cell.y)
		points = maxi(points - LawnCommon.zombie_def(zt)[LawnCommon.ZDEF_VALUE], 1)

func setup_bungee_drop() -> Array:
	var grid: Array = []
	for gx in range(4, MAX_GRID_SIZE_X):
		for gy in range(0, 5):
			grid.append({"x": gx, "y": gy, "weight": 10000})
	return grid

func bungee_drop_zombie(grid: Array, zombie_type: int) -> void:
	var cell: Dictionary = Tod.pick_from_weighted_grid_array(grid)
	cell.weight = 1
	var bungee := add_zombie(PvZ.ZOMBIE_BUNGEE, current_wave)
	var z := add_zombie(zombie_type, current_wave)
	if bungee and z:
		bungee.bungee_drop_zombie(z, cell.x, cell.y)

func spawn_zombies_from_sky() -> void:
	if ice_trap_counter > 0:
		return
	var count: int
	var points: int
	if level == 41 or level == 42:
		count = 2; points = 3
	elif level == 43 or level == 44 or level == 45:
		count = 3; points = 5
	else:
		count = 3; points = 7
	var grid := setup_bungee_drop()
	count = mini(count, grid.size())
	if grid.is_empty() or count <= 0:
		return
	for i in count:
		var zt := pick_grave_rising_zombie_type(points)
		bungee_drop_zombie(grid, zt)
		points = maxi(points - LawnCommon.zombie_def(zt)[LawnCommon.ZDEF_VALUE], 1)

func spawn_zombies_from_graves() -> void:
	if stage_has_roof():
		spawn_zombies_from_sky()
	elif stage_has_pool():
		spawn_zombies_from_pool()
		return
	var points := get_grave_stones_count()
	for gi in grid_items.duplicate():
		if gi.dead or gi.grid_item_type != PvZ.GRIDITEM_GRAVESTONE or gi.grid_item_counter < 100:
			continue
		var zt := pick_grave_rising_zombie_type(points)
		var z := add_zombie(zt, current_wave, true)
		if z == null:
			return
		z.rise_from_grave(gi.grid_x, gi.grid_y)
		points -= LawnCommon.zombie_def(zt)[LawnCommon.ZDEF_VALUE]
		# (original checks the zombie type < 1 here instead of the points; kept as-is)

func get_grave_stones_count() -> int:
	return get_grave_stone_count()

func total_zombies_health_in_wave(wave: int) -> int:
	var total := 0
	for z in zombies:
		if not z.dead and z.from_wave == wave and not z.mind_controlled and not z.is_dead_or_dying() \
				and z.zombie_type != PvZ.ZOMBIE_BUNGEE and z.related_zombie == null:
			total += int(z.body_health + z.helm_health + z.shield_health * 0.2 + z.flying_health)
	return total

func spawn_zombie_wave() -> void:
	var cl := custom_level()
	if cl != null:
		cl.spawn_wave(self, current_wave)
		if is_flag_wave(current_wave):
			flag_raise_counter = PvZ.FLAG_RAISE_TIME
		current_wave += 1
		total_spawned_waves += 1
		return
	challenge.spawn_zombie_wave()
	var arr: PackedInt32Array = zombies_in_wave[current_wave]
	if App.is_bungee_blitz_level():
		var grid := setup_bungee_drop()
		for i in MAX_ZOMBIES_IN_WAVE:
			var zt := arr[i]
			if zt == PvZ.ZOMBIE_INVALID:
				break
			if zt == PvZ.ZOMBIE_BUNGEE or zt == PvZ.ZOMBIE_ZAMBONI:
				add_zombie(zt, current_wave)
			else:
				bungee_drop_zombie(grid, zt)
	else:
		for i in MAX_ZOMBIES_IN_WAVE:
			var zt := arr[i]
			if zt == PvZ.ZOMBIE_INVALID:
				break
			if zt == PvZ.ZOMBIE_BOBSLED and not can_add_bob_sled():
				for j in 3:
					add_zombie(PvZ.ZOMBIE_NORMAL, current_wave)
			else:
				add_zombie(zt, current_wave)
	if current_wave == num_waves - 1 and not App.is_continuous_challenge():
		rise_from_grave_counter = 210
	if is_flag_wave(current_wave):
		flag_raise_counter = PvZ.FLAG_RAISE_TIME
	current_wave += 1
	total_spawned_waves += 1

func update_game_objects() -> void:
	for p in plants.duplicate():
		if not p.dead:
			p.update()
	for z in zombies.duplicate():
		if not z.dead:
			z.update()
	for b in bush_list:
		b.update()
	for pr in projectiles.duplicate():
		if not pr.dead:
			pr.update()
	for c in coins.duplicate():
		if not c.dead:
			c.update()
	for m in lawn_mowers.duplicate():
		if not m.dead:
			m.update()
	cursor_preview.update()
	cursor_object.update()
	if is_net_game():
		var seen: Array = []
		for bank in net_banks:
			if bank in seen:
				continue
			seen.append(bank)
			for i in bank.num_packets:
				bank.seed_packets[i].update()
	else:
		for i in seed_bank.num_packets:
			seed_bank.seed_packets[i].update()

func stop_all_zombie_sounds() -> void:
	for z in zombies:
		if not z.dead:
			z.stop_zombie_sound()

func zombies_won(the_zombie: Zombie) -> void:
	if is_versus() and vs_winner == -1:
		vs_winner = NetSession.TEAM_ZOMBIES
	App.is_fast_mode = false
	if App.game_scene == PvZ.SCENE_ZOMBIES_WON:
		return
	clear_advice(PvZ.ADVICE_NONE)
	App.board_result = PvZ.BOARDRESULT_LOST
	for z in zombies.duplicate():
		if z.dead or z == the_zombie:
			continue
		if z.get_zombie_rect().position.x < -50 or z.zombie_phase == PvZ.PHASE_RISING_FROM_GRAVE or z.zombie_phase == PvZ.PHASE_DANCER_RISING:
			if (z.zombie_type == PvZ.ZOMBIE_GARGANTUAR or z.zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR) and z.is_dead_or_dying() \
					and z.pos_x < 140 + PvZ.BOARD_ADDITIONAL_WIDTH:
				z.die_no_loot()
	App.game_scene = PvZ.SCENE_ZOMBIES_WON
	if the_zombie:
		the_zombie.walk_into_house()
	clear_advice(PvZ.ADVICE_NONE)
	cut_scene.start_zombies_won()
	freeze_effects_for_cutscene(true)
	tutorial_arrow_remove()
	update_cursor()

# ================================================================ sun and waves
func update_sun_spawning() -> void:
	if is_versus():
		NetVersus.update_sun_spawning(self)
		return
	var cl_sun := custom_level()
	if cl_sun != null:
		if not cl_sun.level.sun_drop or has_level_award_dropped():
			return
	var gm := App.game_mode
	if (cl_sun == null and stage_is_night()) or has_level_award_dropped() or gm == PvZ.GAMEMODE_CHALLENGE_RAINING_SEEDS or gm == PvZ.GAMEMODE_CHALLENGE_ICE \
			or gm == PvZ.GAMEMODE_UPSELL or gm == PvZ.GAMEMODE_INTRO or gm == PvZ.GAMEMODE_CHALLENGE_ZOMBIQUARIUM \
			or gm == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN or gm == PvZ.GAMEMODE_TREE_OF_WISDOM or gm == PvZ.GAMEMODE_CHALLENGE_LAST_STAND \
			or App.is_izombie_level() or App.is_scary_potter_level() or App.is_squirrel_level() or has_conveyor_belt_seed_bank() \
			or tutorial_state == PvZ.TUTORIAL_SLOT_MACHINE_PULL:
		return
	if tutorial_state == PvZ.TUTORIAL_LEVEL_1_PICK_UP_PEASHOOTER or tutorial_state == PvZ.TUTORIAL_LEVEL_1_PLANT_PEASHOOTER:
		if plants.is_empty():
			return
	sun_count_down -= 1
	if sun_count_down != 0:
		return
	num_suns_fallen += 1
	var cl := custom_level()
	if cl != null:
		sun_count_down = Tod.rand_range_int(mini(cl.level.sun_drop_min, cl.level.sun_drop_max),
			maxi(cl.level.sun_drop_min, cl.level.sun_drop_max))
		add_coin(Tod.rand_range_int(100 + PvZ.BOARD_ADDITIONAL_WIDTH, 649 + PvZ.BOARD_ADDITIONAL_WIDTH),
			60, PvZ.COIN_SUN, PvZ.COIN_MOTION_FROM_SKY)
		return
	sun_count_down = mini(PvZ.SUN_COUNTDOWN_MAX, PvZ.SUN_COUNTDOWN + num_suns_fallen * 10) + Tod.rand_int(PvZ.SUN_COUNTDOWN_RANGE)
	var sun_type := PvZ.COIN_LARGESUN if gm == PvZ.GAMEMODE_CHALLENGE_SUNNY_DAY else PvZ.COIN_SUN
	add_coin(Tod.rand_range_int(100 + PvZ.BOARD_ADDITIONAL_WIDTH, 649 + PvZ.BOARD_ADDITIONAL_WIDTH), 60, sun_type, PvZ.COIN_MOTION_FROM_SKY)

func next_wave_coming() -> void:
	var cl := custom_level()
	if cl != null and not cl.level.final_wave_banner:
		if current_wave == 0:
			App.play_sample("SOUND_AWOOGA")
		elif is_flag_wave(current_wave):
			App.play_sample("SOUND_SIREN")
		return
	if current_wave + 1 == num_waves:
		if not is_survival_stage_with_repick() and App.game_mode != PvZ.GAMEMODE_CHALLENGE_LAST_STAND and not App.is_continuous_challenge():
			App.add_reanimation(PvZ.BOARD_ADDITIONAL_WIDTH, PvZ.BOARD_OFFSET_Y, make_render_order(PvZ.RENDER_LAYER_ABOVE_UI, 0, 0), PvZ.REANIM_FINAL_WAVE)
			final_wave_sound_counter = 60
	if current_wave == 0:
		App.play_sample("SOUND_AWOOGA")
	elif (App.is_whack_a_zombie_level() and current_wave == num_waves - 1) or is_flag_wave(current_wave):
		App.play_sample("SOUND_SIREN")

func update_zombie_spawning() -> void:
	if is_versus():
		NetVersus.update(self)
		return
	if App.game_mode == PvZ.GAMEMODE_UPSELL or App.game_mode == PvZ.GAMEMODE_INTRO:
		return
	if final_wave_sound_counter > 0:
		final_wave_sound_counter -= 1
		if final_wave_sound_counter == 0:
			App.play_sample("SOUND_FINALWAVE")
	if tutorial_state in [PvZ.TUTORIAL_LEVEL_1_PICK_UP_PEASHOOTER, PvZ.TUTORIAL_LEVEL_1_PLANT_PEASHOOTER,
			PvZ.TUTORIAL_LEVEL_1_REFRESH_PEASHOOTER, PvZ.TUTORIAL_SLOT_MACHINE_PULL]:
		return
	if has_level_award_dropped():
		return
	if rise_from_grave_counter > 0:
		rise_from_grave_counter -= 1
		if rise_from_grave_counter == 0:
			spawn_zombies_from_graves()
	if huge_wave_count_down > 0:
		huge_wave_count_down -= 1
		if huge_wave_count_down == 0:
			clear_advice(PvZ.ADVICE_HUGE_WAVE)
			next_wave_coming()
			zombie_count_down = 1
		else:
			if huge_wave_count_down == 725:
				App.play_sample("SOUND_HUGE_WAVE")
			else:
				var tune: int = App.music.cur_music_tune
				if tune == PvZ.MUSIC_TUNE_DAY_GRASSWALK or tune == PvZ.MUSIC_TUNE_POOL_WATERYGRAVES \
						or tune == PvZ.MUSIC_TUNE_FOG_RIGORMORMIST or tune == PvZ.MUSIC_TUNE_ROOF_GRAZETHEROOF:
					if huge_wave_count_down == 400:
						App.music.start_burst()
				elif tune == PvZ.MUSIC_TUNE_NIGHT_MOONGRAINS:
					if huge_wave_count_down == 700:
						App.music.start_burst()
			return
	if challenge.update_zombie_spawning():
		return
	if current_wave == num_waves:
		if App.game_mode == PvZ.GAMEMODE_CHALLENGE_LAST_STAND:
			return
		if not App.is_continuous_challenge():
			return
	zombie_count_down -= 1
	if zombie_count_down > 200 and zombie_count_down_start - zombie_count_down > 400 \
			and total_zombies_health_in_wave(current_wave - 1) <= zombie_health_to_next_wave:
		zombie_count_down = 200
	if zombie_count_down == 5:
		if is_flag_wave(current_wave):
			clear_advice_immediately()
			display_advice_again("[ADVICE_HUGE_WAVE]", PvZ.MESSAGE_STYLE_HUGE_WAVE, PvZ.ADVICE_HUGE_WAVE)
			huge_wave_count_down = 750
			return
		next_wave_coming()
	if zombie_count_down == 0:
		spawn_zombie_wave()
		zombie_health_wave_start = total_zombies_health_in_wave(current_wave - 1)
		var cl_wave := custom_level()
		if cl_wave != null:
			# a custom level paces its own waves
			zombie_health_to_next_wave = int(cl_wave.wave_health_trigger(current_wave - 1) * zombie_health_wave_start)
			zombie_count_down = cl_wave.wave_delay(current_wave)
			zombie_count_down_start = zombie_count_down
			return
		if is_flag_wave(current_wave) and (App.is_wallnut_bowling_level() or App.game_mode == PvZ.GAMEMODE_CHALLENGE_LAST_STAND):
			zombie_health_to_next_wave = 0
			zombie_count_down = PvZ.ZOMBIE_COUNTDOWN_BEFORE_FLAG
		else:
			zombie_health_to_next_wave = int(Tod.rand_range_float(0.5, 0.65) * zombie_health_wave_start)
			if App.is_little_trouble_level() or App.game_mode == PvZ.GAMEMODE_CHALLENGE_COLUMN or App.game_mode == PvZ.GAMEMODE_CHALLENGE_LAST_STAND:
				zombie_count_down = 750
			else:
				zombie_count_down = PvZ.ZOMBIE_COUNTDOWN + Tod.rand_int(PvZ.ZOMBIE_COUNTDOWN_RANGE)
		zombie_count_down_start = zombie_count_down

func update_ice() -> void:
	for r in MAX_GRID_SIZE_Y:
		if ice_timer[r] == 0:
			continue
		ice_timer[r] -= 1
		var ps: TodParticleSystem = ice_particle[r]
		if ps != null and ps.freed:
			ps = null
		if ice_timer[r] == 0:
			ice_min_x[r] = PvZ.BOARD_ICE_START
			if ps:
				ps.particle_system_die()
		else:
			var px := float(ice_min_x[r])
			var py := float(grid_to_pixel_y(8, r))
			if ps:
				ps.system_move(px, py)
			else:
				ps = App.add_tod_particle(px, py, make_render_order(PvZ.RENDER_LAYER_GROUND, r, 3), PvZ.PARTICLE_ICE_SPARKLE)
				ice_particle[r] = ps
		if ps:
			ps.override_color(null, Color8(255, 255, 255, clampi(Tod.idiv(ice_timer[r], 10), 0, 255)))

func progress_meter_has_flags() -> bool:
	var cl := custom_level()
	if cl != null:
		return cl.level.waves_per_flag > 0
	if App.is_first_time_adventure_mode() and level == 1:
		return false
	if App.is_whack_a_zombie_level() or App.is_final_boss_level() or App.game_mode == PvZ.GAMEMODE_CHALLENGE_BEGHOULED 			or App.game_mode == PvZ.GAMEMODE_CHALLENGE_BEGHOULED_TWIST or App.is_slot_machine_level() or App.is_squirrel_level() or App.is_izombie_level():
		return false
	return true

func has_progress_meter() -> bool:
	if is_versus():
		return false
	var cl := custom_level()
	if cl != null:
		return cl.level.progress_meter and progress_meter_width > 0
	if App.is_final_boss_level() or App.is_slot_machine_level() or App.is_squirrel_level() or App.is_izombie_level() 			or App.game_mode == PvZ.GAMEMODE_CHALLENGE_BEGHOULED or App.game_mode == PvZ.GAMEMODE_CHALLENGE_BEGHOULED_TWIST:
		return true
	if progress_meter_width == 0:
		return false
	if App.is_continuous_challenge() or App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN or App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM or App.is_scary_potter_level():
		return false
	return true

func update_progress_meter() -> void:
	if App.is_final_boss_level():
		var boss := get_boss_zombie()
		if boss and not boss.is_dead_or_dying():
			progress_meter_width = Tod.idiv(150 * (boss.body_max_health - boss.body_health), boss.body_max_health)
		else:
			progress_meter_width = 150
	elif current_wave != 0:
		if flag_raise_counter > 0:
			flag_raise_counter -= 1
		var total_width := 150
		var wpf := maxi(1, get_num_waves_per_flag())
		var has_flags := progress_meter_has_flags()
		if has_flags:
			total_width -= Tod.idiv(12 * num_waves, wpf)
		# a custom level is allowed to have a single wave, which the stock levels never do
		var spans := maxi(1, num_waves - 1)
		var wave_len := Tod.idiv(total_width, spans)
		var cur_len := Tod.idiv((current_wave - 1) * total_width, spans)
		var next_len := Tod.idiv(current_wave * total_width, spans)
		if has_flags:
			var extra := Tod.idiv(current_wave, wpf) * 12
			cur_len += extra
			next_len += extra
		var frac := float(zombie_count_down_start - zombie_count_down) / float(zombie_count_down_start)
		if zombie_health_to_next_wave != -1:
			var health_cur := total_zombies_health_in_wave(current_wave - 1)
			var dmg_target := maxi(zombie_health_wave_start - zombie_health_to_next_wave, 1)
			var hf := float(dmg_target - health_cur + zombie_health_to_next_wave) / float(dmg_target)
			frac = maxf(hf, frac)
		var length := clampi(cur_len + Tod.round_to_int((next_len - cur_len) * frac), 1, 150)
		var delta := length - progress_meter_width
		if (delta > wave_len and main_counter % 5 == 0) or (delta > 0 and main_counter % 20 == 0):
			progress_meter_width += 1

# ================================================================ tutorial
func tutorial_arrow_show(px: int, py: int) -> void:
	tutorial_arrow_remove()
	tutorial_particle = App.add_tod_particle(px, py, PvZ.RENDER_LAYER_TOP, PvZ.PARTICLE_SEED_PACKET_PICK)

func tutorial_arrow_remove() -> void:
	if tutorial_particle != null and not tutorial_particle.freed:
		tutorial_particle.particle_system_die()
	tutorial_particle = null

func update_tutorial() -> void:
	if tutorial_timer > 0:
		tutorial_timer -= 1
	var p0: SeedPacket = seed_bank.seed_packets[0]
	if tutorial_state == PvZ.TUTORIAL_LEVEL_1_PICK_UP_PEASHOOTER and tutorial_timer == 0:
		display_advice("[ADVICE_CLICK_PEASHOOTER]", PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL1_STAY, PvZ.ADVICE_NONE)
		tutorial_arrow_show(seed_bank.x + p0.x, seed_bank.y + p0.y)
		tutorial_timer = -1
	elif tutorial_state in [PvZ.TUTORIAL_LEVEL_2_PICK_UP_SUNFLOWER, PvZ.TUTORIAL_LEVEL_2_PLANT_SUNFLOWER, PvZ.TUTORIAL_LEVEL_2_REFRESH_SUNFLOWER]:
		if tutorial_timer == 0:
			display_advice("[ADVICE_PLANT_SUNFLOWER2]", PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL2, PvZ.ADVICE_NONE)
			tutorial_timer = -1
		elif zombie_count_down == 750 and current_wave == 0:
			display_advice("[ADVICE_PLANT_SUNFLOWER3]", PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL2, PvZ.ADVICE_NONE)
	elif tutorial_state in [PvZ.TUTORIAL_MORESUN_PICK_UP_SUNFLOWER, PvZ.TUTORIAL_MORESUN_PLANT_SUNFLOWER, PvZ.TUTORIAL_MORESUN_REFRESH_SUNFLOWER]:
		if tutorial_timer == 0:
			display_advice("[ADVICE_PLANT_SUNFLOWER5]", PvZ.MESSAGE_STYLE_TUTORIAL_LATER, PvZ.ADVICE_PLANT_SUNFLOWER5)
			tutorial_timer = -1
	if App.is_first_time_adventure_mode() and level >= 3 and level != 5 and level <= 7 and tutorial_state == PvZ.TUTORIAL_OFF \
			and current_wave >= 5 and not BoardCore.shown_more_sun_tutorial and seed_bank.seed_packets[1].can_pick_up() \
			and count_plant_by_type(PvZ.SEED_SUNFLOWER) < 3:
		display_advice("[ADVICE_PLANT_SUNFLOWER4]", PvZ.MESSAGE_STYLE_TUTORIAL_LATER_STAY, PvZ.ADVICE_NONE)
		BoardCore.shown_more_sun_tutorial = true
		set_tutorial_state(PvZ.TUTORIAL_MORESUN_PICK_UP_SUNFLOWER)
		tutorial_timer = 500

func set_tutorial_state(state: int) -> void:
	match state:
		PvZ.TUTORIAL_LEVEL_1_PICK_UP_PEASHOOTER:
			if plants.is_empty():
				var p0: SeedPacket = seed_bank.seed_packets[0]
				tutorial_arrow_show(seed_bank.x + p0.x, seed_bank.y + p0.y)
				display_advice("[ADVICE_CLICK_SEED_PACKET]", PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL1_STAY, PvZ.ADVICE_NONE)
			else:
				display_advice("[ADVICE_ENOUGH_SUN]", PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL1_STAY, PvZ.ADVICE_NONE)
				tutorial_timer = 400
		PvZ.TUTORIAL_LEVEL_1_PLANT_PEASHOOTER:
			tutorial_timer = -1
			tutorial_arrow_remove()
			if plants.is_empty():
				display_advice("[ADVICE_CLICK_ON_GRASS]", PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL1_STAY, PvZ.ADVICE_NONE)
			else:
				clear_advice(PvZ.ADVICE_NONE)
		PvZ.TUTORIAL_LEVEL_1_REFRESH_PEASHOOTER:
			display_advice("[ADVICE_PLANTED_PEASHOOTER]", PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL1_STAY, PvZ.ADVICE_NONE)
			sun_count_down = 400
		PvZ.TUTORIAL_LEVEL_1_COMPLETED:
			display_advice("[ADVICE_ZOMBIE_ONSLAUGHT]", PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL1, PvZ.ADVICE_NONE)
			zombie_count_down = 99
			zombie_count_down_start = zombie_count_down
		PvZ.TUTORIAL_LEVEL_2_PICK_UP_SUNFLOWER, PvZ.TUTORIAL_MORESUN_PICK_UP_SUNFLOWER:
			var p1: SeedPacket = seed_bank.seed_packets[1]
			tutorial_arrow_show(seed_bank.x + p1.x, seed_bank.y + p1.y)
		PvZ.TUTORIAL_LEVEL_2_PLANT_SUNFLOWER, PvZ.TUTORIAL_LEVEL_2_REFRESH_SUNFLOWER, PvZ.TUTORIAL_MORESUN_PLANT_SUNFLOWER, PvZ.TUTORIAL_MORESUN_REFRESH_SUNFLOWER:
			tutorial_arrow_remove()
		PvZ.TUTORIAL_LEVEL_2_COMPLETED:
			if current_wave == 0:
				zombie_count_down = 999
				zombie_count_down_start = zombie_count_down
		PvZ.TUTORIAL_SLOT_MACHINE_PULL:
			display_advice("[ADVICE_SLOT_MACHINE_PULL]", PvZ.MESSAGE_STYLE_SLOT_MACHINE, PvZ.ADVICE_SLOT_MACHINE_PULL)
		PvZ.TUTORIAL_SLOT_MACHINE_COMPLETED:
			clear_advice(PvZ.ADVICE_SLOT_MACHINE_PULL)
		PvZ.TUTORIAL_SHOVEL_PICKUP:
			display_advice("[ADVICE_CLICK_SHOVEL]", PvZ.MESSAGE_STYLE_HINT_STAY, PvZ.ADVICE_NONE)
			var r := get_shovel_button_rect()
			tutorial_arrow_show(r.position.x + Tod.idiv(r.size.x, 2) - 25, r.position.y + r.size.y - 65)
		PvZ.TUTORIAL_SHOVEL_DIG:
			display_advice("[ADVICE_CLICK_PLANT]", PvZ.MESSAGE_STYLE_HINT_STAY, PvZ.ADVICE_NONE)
			tutorial_arrow_remove()
		PvZ.TUTORIAL_SHOVEL_KEEP_DIGGING:
			display_advice("[ADVICE_KEEP_DIGGING]", PvZ.MESSAGE_STYLE_HINT_STAY, PvZ.ADVICE_NONE)
		PvZ.TUTORIAL_SHOVEL_COMPLETED:
			clear_advice(PvZ.ADVICE_NONE)
			cut_scene.cutscene_time = 1500
			cut_scene.crazy_dave_dialog_start = 2410
	tutorial_state = state

# ================================================================ fog
func clear_fog_around_plant(plant: Plant, size: int) -> void:
	var speed := 6
	if fog_blown_count_down > 0 and fog_blown_count_down < 2000:
		speed = 2
	elif fog_blown_count_down > 0:
		speed = 40
	var left := left_fog_column()
	var fog_off_x := int((fog_offset + 50) / 100)
	var sx := maxi(plant.plant_col - size - fog_off_x, left)
	var ex := mini(plant.plant_col + size - fog_off_x, MAX_GRID_SIZE_X - 1)
	var sy := maxi(plant.row - size, 0)
	var ey := mini(plant.row + size, MAX_GRID_SIZE_Y)
	for gx in range(sx, ex + 1):
		for gy in range(sy, ey + 1):
			var dx := absi(gx + fog_off_x - plant.plant_col)
			var dy := absi(gy - plant.row)
			if size == 4:
				if dx > 3 or dy > 2:
					continue
				if dx + dy == 5:
					continue
			elif dx + dy > size:
				continue
			grid_cel_fog[gx][gy] = maxi(grid_cel_fog[gx][gy] - speed, 0)

func update_fog() -> void:
	if not stage_has_fog():
		return
	var speed := 3
	if fog_blown_count_down > 0 and fog_blown_count_down < 2000:
		speed = 1
	elif fog_blown_count_down > 0:
		speed = 20
	var left := left_fog_column()
	for gx in range(left, MAX_GRID_SIZE_X):
		var col: PackedInt32Array = grid_cel_fog[gx]
		var fmax := 200 if gx == left else 255
		for gy in MAX_GRID_SIZE_Y + 1:
			col[gy] = mini(col[gy] + speed, fmax)
		grid_cel_fog[gx] = col
	for p in plants:
		if p.dead or p.not_on_ground():
			continue
		if p.seed_type == PvZ.SEED_PLANTERN:
			clear_fog_around_plant(p, 4)
		elif p.seed_type == PvZ.SEED_TORCHWOOD:
			clear_fog_around_plant(p, 1)

# ================================================================ main update
func update_game() -> void:
	update_game_objects()
	if stage_has_fog() and fog_blown_count_down > 0:
		var max_off := 1065.0 - left_fog_column() * 70.0
		if App.game_scene == PvZ.SCENE_LEVEL_INTRO:
			fog_offset = Tod.animate_curve_float(200, 0, fog_blown_count_down, max_off, 0, Tod.CURVE_EASE_OUT)
		elif fog_blown_count_down < 2000:
			fog_offset = Tod.animate_curve_float(2000, 0, fog_blown_count_down, max_off, 0, Tod.CURVE_EASE_OUT)
		elif fog_offset < max_off:
			fog_offset = Tod.animate_curve_float_time(-5, max_off, fog_offset * 1.1, 0, max_off, Tod.CURVE_LINEAR)
	if App.game_scene != PvZ.SCENE_PLAYING and not cut_scene.should_run_upsell_board():
		return
	main_counter += 1
	update_sun_spawning()
	update_zombie_spawning()
	if CustomRuntime.active != null:
		CustomRuntime.active.update()
	update_ice()
	if ice_trap_counter > 0:
		ice_trap_counter -= 1
		if ice_trap_counter == 0 and pool_sparkly_particle != null and not pool_sparkly_particle.freed:
			pool_sparkly_particle.dont_update = false
	if fog_blown_count_down > 0:
		fog_blown_count_down -= 1
	if main_counter == 1 and App.is_first_time_adventure_mode():
		if level == 1:
			set_tutorial_state(PvZ.TUTORIAL_LEVEL_1_PICK_UP_PEASHOOTER)
		elif level == 2:
			set_tutorial_state(PvZ.TUTORIAL_LEVEL_2_PICK_UP_SUNFLOWER)
			display_advice("[ADVICE_PLANT_SUNFLOWER1]", PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL2, PvZ.ADVICE_NONE)
			tutorial_timer = 500
	update_progress_meter()

func update() -> void:
	super.update()
	if paused and App.is_fast_mode:
		App.is_fast_mode = false
	if fast_button != null and not fast_button.btn_no_draw:
		var fast := Res.get_image("IMAGE_FASTBUTTON")
		var fast_hi := Res.get_image("IMAGE_FASTBUTTON_HIGHLIGHT")
		fast_button.button_image = fast_hi if App.is_fast_mode else fast
		fast_button.over_image = fast_hi if App.is_fast_mode else fast
		fast_button.down_image = fast if App.is_fast_mode else fast_hi
	if sun_money >= 8000 and not App.playing_quickplay:
		App.get_achievement(PvZ.ACHIEVEMENT_SUNNY_DAYS)
	cut_scene.update()
	var local_zombie := is_versus() and net_team_of(net_local_slot) == NetSession.TEAM_ZOMBIES
	if local_zombie:
		net_swap_sun(true)
	update_mouse_position()
	if local_zombie:
		net_swap_sun(false)
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
		App.zen_garden.zen_garden_update()
	if is_scary_potter_dave_talking():
		App.update_crazy_dave()
	if paused:
		challenge.update()
		cursor_preview.visible = false
		cursor_object.visible = false
		return
	var btn_disabled := not can_interact_with_board_buttons() or ignore_mouse_up
	if not menu_button.btn_no_draw:
		menu_button.disabled = btn_disabled
	menu_button.update()
	if not fast_button.btn_no_draw:
		fast_button.disabled = btn_disabled
	fast_button.update()
	if store_button:
		store_button.disabled = btn_disabled
		store_button.update()
	EffectSystem.update()
	advice.update()
	update_tutorial()
	if cob_cannon_cursor_delay_counter > 0:
		cob_cannon_cursor_delay_counter -= 1
	if out_of_money_counter > 0:
		out_of_money_counter -= 1
	if shake_counter > 0:
		shake_counter -= 1
		if shake_counter == 0:
			x = 0
			y = 0
		else:
			if Tod.rand_int(3) == 0:
				shake_amount_x = -shake_amount_x
			x = Tod.animate_curve(12, 0, shake_counter, 0, shake_amount_x, Tod.CURVE_BOUNCE)
			y = Tod.animate_curve(12, 0, shake_counter, 0, shake_amount_y, Tod.CURVE_BOUNCE)
	if coin_bank_fade_count > 0 and App.get_dialog(PvZ.DIALOG_PURCHASE_PACKET_SLOT) == null:
		coin_bank_fade_count -= 1
	if time_stop_counter > 0:
		return
	effect_counter += 1
	if stage_has_pool() and ice_trap_counter == 0 and App.game_scene != PvZ.SCENE_ZOMBIES_WON and not cut_scene.is_survival_repick():
		App.pool_effect.pool_effect_update()
	if background == PvZ.BACKGROUND_3_POOL and pool_sparkly_particle == null and draw_count > 0:
		pool_sparkly_particle = App.add_tod_particle(450 + PvZ.BOARD_ADDITIONAL_WIDTH, 295 + PvZ.BOARD_OFFSET_Y,
			make_render_order(PvZ.RENDER_LAYER_GROUND, 2, 0), PvZ.PARTICLE_POOL_SPARKLY)
	update_grid_items()
	update_fwoosh()
	update_game()
	update_fog()
	challenge.update()
	update_level_end_sequence()
	prev_mouse_x = App.widget_manager.last_mouse_x
	prev_mouse_y = App.widget_manager.last_mouse_y

