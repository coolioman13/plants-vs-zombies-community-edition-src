class_name LawnMower
extends RefCounted
## Port of LawnMower (lawn mowers, pool cleaners, roof cleaners).

var pos_x := 0.0
var pos_y := 0.0
var render_order := 0
var row := 0
var reanim: Reanimation = null
var chomp_counter := 0
var rolling_in_counter := 0
var squished_counter := 0
var mower_state := PvZ.MOWER_READY
var dead := false
var freed := false
var visible := true
var mower_type := PvZ.LAWNMOWER_LAWN
var altitude := 0.0
var mower_height := PvZ.MOWER_HEIGHT_LAND
var last_portal_x := -1

func lawn_mower_initialize(the_row: int) -> void:
	var board: Board = App.board
	row = the_row
	pos_x = -160.0 + PvZ.BOARD_ADDITIONAL_WIDTH
	render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_LAWN_MOWER, the_row, 0)
	pos_y = board.get_pos_y_based_on_row(pos_x + 40.0, the_row) + 23.0
	dead = false
	mower_state = PvZ.MOWER_READY
	visible = true
	chomp_counter = 0
	rolling_in_counter = 0
	squished_counter = 0
	last_portal_x = -1
	var reanim_type: int
	if board.stage_has_roof():
		mower_type = PvZ.LAWNMOWER_ROOF
		reanim_type = PvZ.REANIM_ROOF_CLEANER
	elif board.plant_row[row] == PvZ.PLANTROW_POOL and App.player_info.purchases[PvZ.STORE_ITEM_POOL_CLEANER] != 0:
		mower_type = PvZ.LAWNMOWER_POOL
		reanim_type = PvZ.REANIM_POOL_CLEANER
	else:
		mower_type = PvZ.LAWNMOWER_LAWN
		reanim_type = PvZ.REANIM_LAWNMOWER
	reanim = App.add_reanimation(0.0, 18.0, render_order, reanim_type)
	reanim.anim_rate = 0.0
	reanim.loop_type = Reanimation.REANIM_LOOP
	reanim.is_attachment = true
	reanim.override_scale(0.85, 0.85)
	if mower_type == PvZ.LAWNMOWER_LAWN:
		reanim.set_frames_for_layer("anim_normal")
	elif mower_type == PvZ.LAWNMOWER_POOL:
		reanim.override_scale(0.8, 0.8)
		reanim.set_frames_for_layer("anim_land")
		reanim.set_truncate_disappearing_frames("", false)
	if board.super_mower_mode and mower_type == PvZ.LAWNMOWER_LAWN:
		enable_super_mower(true)

func update_pool() -> void:
	var in_pool_range := pos_x > 26.0 + PvZ.BOARD_ADDITIONAL_WIDTH and pos_x < 660.0 + PvZ.BOARD_ADDITIONAL_WIDTH
	if in_pool_range and mower_height == PvZ.MOWER_HEIGHT_LAND:
		var splash := App.add_reanimation(pos_x, pos_y + 25.0, render_order + 1, PvZ.REANIM_SPLASH)
		splash.override_scale(1.2, 0.8)
		App.add_tod_particle(pos_x + 50.0, pos_y + 42.0, render_order + 1, PvZ.PARTICLE_PLANTING_POOL)
		App.play_foley(PvZ.FOLEY_ZOMBIESPLASH)
		mower_height = PvZ.MOWER_HEIGHT_DOWN_TO_POOL
	elif mower_height == PvZ.MOWER_HEIGHT_DOWN_TO_POOL:
		altitude -= 2.0
		if altitude <= -28.0:
			altitude = 0.0
			mower_height = PvZ.MOWER_HEIGHT_IN_POOL
			reanim.play_reanim("anim_water", Reanimation.REANIM_LOOP, 0, 0.0)
	elif mower_height == PvZ.MOWER_HEIGHT_IN_POOL:
		if not in_pool_range:
			altitude = -28.0
			mower_height = PvZ.MOWER_HEIGHT_UP_TO_LAND
			var splash := App.add_reanimation(pos_x, pos_y + 25.0, render_order + 1, PvZ.REANIM_SPLASH)
			splash.override_scale(1.2, 0.8)
			App.add_tod_particle(pos_x + 50.0, pos_y + 42.0, render_order + 1, PvZ.PARTICLE_PLANTING_POOL)
			App.play_foley(PvZ.FOLEY_PLANT_WATER)
			reanim.play_reanim("anim_land", Reanimation.REANIM_LOOP, 0, 0.0)
	elif mower_height == PvZ.MOWER_HEIGHT_UP_TO_LAND:
		altitude += 2.0
		if altitude >= 0.0:
			altitude = 0.0
			mower_height = PvZ.MOWER_HEIGHT_LAND
	if mower_height == PvZ.MOWER_HEIGHT_IN_POOL and reanim.loop_type == Reanimation.REANIM_PLAY_ONCE_AND_HOLD and reanim.loop_count > 0:
		reanim.play_reanim("anim_water", Reanimation.REANIM_LOOP, 10, 35.0)

func mow_zombie(zombie: Zombie) -> void:
	if mower_state == PvZ.MOWER_READY:
		start_mower()
		chomp_counter = 25
	elif mower_state == PvZ.MOWER_TRIGGERED:
		chomp_counter = 50
	if mower_type == PvZ.LAWNMOWER_POOL:
		App.play_foley(PvZ.FOLEY_SHOOP)
		if mower_height == PvZ.MOWER_HEIGHT_IN_POOL:
			reanim.play_reanim("anim_suck", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 10, 35.0)
		else:
			reanim.play_reanim("anim_landsuck", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 10, 35.0)
		zombie.die_with_loot()
	else:
		App.play_foley(PvZ.FOLEY_SPLAT)
		zombie.mow_down()

func update() -> void:
	var board: Board = App.board
	if mower_state == PvZ.MOWER_SQUISHED:
		squished_counter -= 1
		if squished_counter <= 0:
			die()
		return
	if mower_state == PvZ.MOWER_ROLLING_IN:
		rolling_in_counter += 1
		pos_x = Tod.animate_curve_float(0, 100, rolling_in_counter, -160.0 + PvZ.BOARD_ADDITIONAL_WIDTH, -21.0 + PvZ.BOARD_ADDITIONAL_WIDTH, Tod.CURVE_EASE_IN_OUT)
		if rolling_in_counter == 100:
			mower_state = PvZ.MOWER_READY
		return
	if App.game_scene != PvZ.SCENE_PLAYING and not board.cut_scene.should_run_upsell_board():
		return
	var attack := get_lawn_mower_attack_rect()
	for z in board.zombies.duplicate():
		if z.dead or z.zombie_type == PvZ.ZOMBIE_BOSS or z.row != row or z.vs_target:  # versus: targets are the plants' job
			continue
		if z.zombie_phase != PvZ.PHASE_ZOMBIE_MOWERED and not z.is_tangle_kelp_target() and z.effected_by_damage(127):
			var overlap := LawnCommon.get_rect_overlap(attack, z.get_zombie_rect())
			if overlap > (20 if z.zombie_type == PvZ.ZOMBIE_BALLOON else 0):
				if mower_state != PvZ.MOWER_READY or (z.zombie_type != PvZ.ZOMBIE_BUNGEE and z.has_head):
					mow_zombie(z)
	if mower_state != PvZ.MOWER_TRIGGERED and mower_state != PvZ.MOWER_SQUISHED:
		return
	var speed := 3.33
	if mower_type == PvZ.LAWNMOWER_POOL:
		speed = 2.5
	if chomp_counter > 0:
		chomp_counter -= 1
		speed = Tod.animate_curve_float(50, 0, chomp_counter, speed, 1.0, Tod.CURVE_BOUNCE_SLOW_MIDDLE)
	pos_x += speed
	pos_y = board.get_pos_y_based_on_row(pos_x + 40.0, row) + 23.0
	if mower_type == PvZ.LAWNMOWER_POOL:
		update_pool()
	if mower_type == PvZ.LAWNMOWER_LAWN and board.plant_row[row] == PvZ.PLANTROW_POOL and pos_x > 50.0:
		var splash := App.add_reanimation(pos_x, pos_y + 25.0, render_order + 1, PvZ.REANIM_SPLASH)
		splash.override_scale(1.2, 0.8)
		App.add_tod_particle(pos_x + 50.0, pos_y + 67.0, render_order + 1, PvZ.PARTICLE_PLANTING_POOL)
		App.play_sample("SOUND_ZOMBIE_ENTERING_WATER")
		App.sound_system.stop_foley(PvZ.FOLEY_LAWNMOWER)
		die()
	if pos_x > PvZ.WIDE_BOARD_WIDTH:
		die()
	if reanim and not reanim.freed:
		reanim.update()

func draw(g: Graphics) -> void:
	if not visible:
		return
	var board: Board = App.board
	if mower_height != PvZ.MOWER_HEIGHT_UP_TO_LAND and mower_height != PvZ.MOWER_HEIGHT_DOWN_TO_POOL \
			and mower_height != PvZ.MOWER_HEIGHT_IN_POOL and mower_state != PvZ.MOWER_SQUISHED:
		var sy := 1.0
		var shadow_x := pos_x - 7.0
		var shadow_y := pos_y - altitude + 47.0
		if mower_type == PvZ.LAWNMOWER_POOL:
			shadow_x -= 17.0
			shadow_y -= 8.0
		if mower_type == PvZ.LAWNMOWER_ROOF:
			shadow_x -= 9.0
			shadow_y -= 36.0
			sy = 1.2
			if mower_state == PvZ.MOWER_TRIGGERED:
				shadow_y += 36.0
		var shadow := Res.get_image("IMAGE_PLANTSHADOW2" if board.stage_is_night() else "IMAGE_PLANTSHADOW")
		g.tod_draw_image_cel_center_scaled_f(shadow, shadow_x, shadow_y, 0, 1.0, sy)
	var mg := g.copy()
	mg.trans_x += pos_x + 6.0
	mg.trans_y += pos_y - altitude
	if mower_type == PvZ.LAWNMOWER_POOL:
		if mower_state == PvZ.MOWER_TRIGGERED:
			mg.trans_y -= 7.0
			mg.trans_x -= 10.0
		else:
			mg.trans_y -= 33.0
		if mower_height == PvZ.MOWER_HEIGHT_UP_TO_LAND or mower_height == PvZ.MOWER_HEIGHT_DOWN_TO_POOL:
			mg.set_clip_rect(-50, -50, 150, 132 + altitude)
	elif mower_type == PvZ.LAWNMOWER_ROOF:
		if mower_state == PvZ.MOWER_TRIGGERED:
			mg.trans_y -= 4.0
			mg.trans_x -= 10.0
		else:
			mg.trans_y -= 40.0
	if mower_state == PvZ.MOWER_TRIGGERED or mower_state == PvZ.MOWER_SQUISHED:
		if reanim:
			reanim.draw(mg)
	else:
		var mt := mower_type
		if mower_type == PvZ.LAWNMOWER_LAWN and board.super_mower_mode:
			mt = PvZ.LAWNMOWER_SUPER_MOWER
		ReanimatorCache.draw_cached_mower(mg, 0.0, 19.0, mt)

func die() -> void:
	var board: Board = App.board
	dead = true
	if reanim and not reanim.freed:
		reanim.die()
	if board.bonus_lawn_mowers_remaining > 0 and not board.has_level_award_dropped():
		var m := LawnMower.new()
		board.lawn_mowers.append(m)
		m.lawn_mower_initialize(row)
		m.mower_state = PvZ.MOWER_ROLLING_IN
		board.bonus_lawn_mowers_remaining -= 1

func start_mower() -> void:
	if mower_state == PvZ.MOWER_TRIGGERED:
		return
	var board: Board = App.board
	if mower_type == PvZ.LAWNMOWER_POOL:
		reanim.anim_rate = 35.0
		App.play_foley(PvZ.FOLEY_POOL_CLEANER)
	else:
		reanim.anim_rate = 70.0
		App.play_foley(PvZ.FOLEY_LAWNMOWER)
	board.wave_row_got_lawn_mowered[row] = board.current_wave
	board.triggered_lawn_mowers += 1
	mower_state = PvZ.MOWER_TRIGGERED
	if CustomRuntime.active != null:
		CustomRuntime.active.notify_mower_fired(row)

func squish_mower() -> void:
	reanim.override_scale(0.85, 0.22)
	reanim.set_position(-11.0, 65.0)
	mower_state = PvZ.MOWER_SQUISHED
	squished_counter = 500
	App.play_foley(PvZ.FOLEY_SQUISH)

func get_lawn_mower_attack_rect() -> Rect2i:
	return Rect2i(int(pos_x), int(pos_y), 50, 80)

func enable_super_mower(_enable: bool) -> void:
	if mower_type == PvZ.LAWNMOWER_LAWN:
		reanim.set_frames_for_layer("anim_tricked")
