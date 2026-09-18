class_name Projectile
extends GameObject
## Port of Projectile (peas, lobbed projectiles, stars, spikes, cob cannon, basketballs...).

var frame := 0
var num_frames := 1
var anim_counter := 0
var pos_x := 0.0
var pos_y := 0.0
var pos_z := 0.0
var vel_x := 0.0
var vel_y := 0.0
var vel_z := 0.0
var acc_z := 0.0
var shadow_y := 0.0
var anim_ticks_per_frame := 0
var motion_type := PvZ.MOTION_STRAIGHT
var projectile_type := PvZ.PROJECTILE_PEA
var projectile_age := 0
var click_backoff_counter := 0
var rotation := 0.0
var rotation_speed := 0.0
var on_high_ground := false
var damage_range_flags := 0
var hit_torchwood_grid_x := -1
var cob_target_x := 0.0
var cob_target_row := 0
var target_zombie: Zombie = null
var last_portal_x := -1

func _board() -> Board:
	return App.board

func projectile_initialize(px: int, py: int, order: int, the_row: int, type: int) -> void:
	var board := _board()
	var gx := board.pixel_to_grid_x_keep_on_board(px, py)
	projectile_type = type
	pos_x = px
	pos_y = py
	pos_z = 0.0
	vel_x = 0.0
	vel_y = 0.0
	vel_z = 0.0
	acc_z = 0.0
	shadow_y = board.grid_to_pixel_y(gx, the_row) + 67.0
	hit_torchwood_grid_x = -1
	motion_type = PvZ.MOTION_STRAIGHT
	frame = 0
	num_frames = 1
	row = the_row
	cob_target_x = 0.0
	damage_range_flags = 0
	dead = false
	cob_target_row = 0
	target_zombie = null
	on_high_ground = board.grid_square_type[gx][the_row] == PvZ.GRIDSQUARE_HIGH_GROUND
	if board.stage_has_roof():
		shadow_y -= 12.0
	render_order = order
	rotation = 0.0
	rotation_speed = 0.0
	width = 40
	height = 40
	projectile_age = 0
	click_backoff_counter = 0
	anim_ticks_per_frame = 0
	match projectile_type:
		PvZ.PROJECTILE_CABBAGE, PvZ.PROJECTILE_BUTTER:
			rotation = -7 * PI / 25
			rotation_speed = Tod.rand_range_float(-0.08, -0.02)
		PvZ.PROJECTILE_MELON, PvZ.PROJECTILE_WINTERMELON:
			rotation = -2 * PI / 5
			rotation_speed = Tod.rand_range_float(-0.08, -0.02)
		PvZ.PROJECTILE_KERNEL:
			rotation = 0.0
			rotation_speed = Tod.rand_range_float(-0.2, -0.08)
		PvZ.PROJECTILE_SNOWPEA:
			var ps := App.add_tod_particle(pos_x + 8.0, pos_y + 13.0, 400000, PvZ.PARTICLE_SNOWPEA_TRAIL)
			Attachment.attach_particle(self, ps, 8.0, 13.0)
		PvZ.PROJECTILE_COBBIG:
			var img := Res.get_image("IMAGE_REANIM_COBCANNON_COB")
			width = img.width
			height = img.height
			rotation = PI / 2
		PvZ.PROJECTILE_PUFF:
			var ps := App.add_tod_particle(pos_x + 13.0, pos_y + 13.0, 400000, PvZ.PARTICLE_PUFFSHROOM_TRAIL)
			Attachment.attach_particle(self, ps, 13.0, 13.0)
		PvZ.PROJECTILE_BASKETBALL:
			rotation = Tod.rand_range_float(0.0, 2 * PI)
			rotation_speed = Tod.rand_range_float(0.05, 0.1)
		PvZ.PROJECTILE_STAR:
			shadow_y += 15.0
			rotation_speed = Tod.rand_range_float(0.05, 0.1)
			if Tod.rand_int(2) == 0:
				rotation_speed = -rotation_speed
	anim_counter = 0
	x = int(pos_x)
	y = int(pos_y)

func find_collision_target_plant() -> Plant:
	var board := _board()
	var pr := get_projectile_rect()
	for p in board.plants:
		if p.dead or p.row != row:
			continue
		if projectile_type == PvZ.PROJECTILE_ZOMBIE_PEA:
			if p.seed_type in [PvZ.SEED_PUFFSHROOM, PvZ.SEED_SUNSHROOM, PvZ.SEED_POTATOMINE, PvZ.SEED_SPIKEWEED, PvZ.SEED_SPIKEROCK, PvZ.SEED_LILYPAD]:
				continue
		if LawnCommon.get_rect_overlap(pr, p.get_plant_rect()) > 8:
			if projectile_type == PvZ.PROJECTILE_ZOMBIE_PEA:
				return board.get_top_plant_at(p.plant_col, p.row, PvZ.TOPPLANT_EATING_ORDER)
			return board.get_top_plant_at(p.plant_col, p.row, PvZ.TOPPLANT_CATAPULT_ORDER)
	return null

func pea_about_to_hit_torchwood() -> bool:
	if motion_type != PvZ.MOTION_STRAIGHT:
		return false
	if projectile_type != PvZ.PROJECTILE_PEA and projectile_type != PvZ.PROJECTILE_SNOWPEA:
		return false
	for p in _board().plants:
		if not p.dead and p.seed_type == PvZ.SEED_TORCHWOOD and p.row == row and not p.not_on_ground() and hit_torchwood_grid_x != p.plant_col:
			var attack: Rect2i = p.get_plant_attack_rect(PvZ.WEAPON_PRIMARY)
			var pr := get_projectile_rect()
			pr.position.x += 40
			if LawnCommon.get_rect_overlap(attack, pr) > 10:
				return true
	return false

func find_collision_target() -> Zombie:
	if pea_about_to_hit_torchwood():
		return null
	var pr := get_projectile_rect()
	var best: Zombie = null
	var min_x := 0
	for z in _board().zombies:
		if z.dead:
			continue
		if (z.zombie_type == PvZ.ZOMBIE_BOSS or z.row == row) and z.effected_by_damage(damage_range_flags):
			if z.zombie_phase == PvZ.PHASE_SNORKEL_WALKING_IN_POOL and pos_z >= 45.0:
				continue
			if projectile_type == PvZ.PROJECTILE_STAR and projectile_age < 25 and vel_x >= 0.0 and z.zombie_type == PvZ.ZOMBIE_DIGGER:
				continue
			if LawnCommon.get_rect_overlap(pr, z.get_zombie_rect()) > 0:
				if best == null or z.x < min_x:
					best = z
					min_x = z.x
	return best

func check_for_collision() -> void:
	if motion_type == PvZ.MOTION_PUFF and projectile_age >= 75:
		die()
		return
	if pos_x > PvZ.WIDE_BOARD_WIDTH or pos_x + width < 0.0 + PvZ.BOARD_ADDITIONAL_WIDTH:
		die()
		return
	if motion_type == PvZ.MOTION_HOMING:
		var z: Zombie = BoardCore.try_get(target_zombie)
		if z and z.effected_by_damage(damage_range_flags):
			var zr: Rect2i = z.get_zombie_rect()
			if LawnCommon.get_rect_overlap(get_projectile_rect(), zr) >= 0 and pos_y > zr.position.y and pos_y < zr.position.y + zr.size.y:
				do_impact(z)
		return
	if pos_y > 600.0 + PvZ.BOARD_OFFSET_Y or pos_y < 0.0 + PvZ.BOARD_OFFSET_Y:
		die()
		return
	if (projectile_type == PvZ.PROJECTILE_PEA or projectile_type == PvZ.PROJECTILE_STAR) and shadow_y - pos_y > 90.0:
		return
	if motion_type == PvZ.MOTION_FLOAT_OVER:
		return
	if projectile_type == PvZ.PROJECTILE_ZOMBIE_PEA:
		var p := find_collision_target_plant()
		if p:
			p.plant_health -= get_damage()
			p.eaten_flash_countdown = maxi(p.eaten_flash_countdown, 25)
			App.play_foley(PvZ.FOLEY_SPLAT)
			App.add_tod_particle(pos_x - 3.0, pos_y + 17.0, render_order + 1, PvZ.PARTICLE_PEA_SPLAT)
			die()
		return
	var zombie := find_collision_target()
	if zombie:
		if zombie.on_high_ground and cant_hit_high_ground():
			return
		do_impact(zombie)

func cant_hit_high_ground() -> bool:
	if motion_type == PvZ.MOTION_BACKWARDS or motion_type == PvZ.MOTION_HOMING:
		return false
	return projectile_type in [PvZ.PROJECTILE_PEA, PvZ.PROJECTILE_SNOWPEA, PvZ.PROJECTILE_STAR, PvZ.PROJECTILE_PUFF, PvZ.PROJECTILE_FIREBALL] and not on_high_ground

func check_for_high_ground() -> void:
	var shadow_delta := shadow_y - pos_y
	if projectile_type in [PvZ.PROJECTILE_PEA, PvZ.PROJECTILE_SNOWPEA, PvZ.PROJECTILE_FIREBALL, PvZ.PROJECTILE_SPIKE, PvZ.PROJECTILE_COBBIG]:
		if shadow_delta < 28.0:
			do_impact(null)
			return
	if projectile_type == PvZ.PROJECTILE_PUFF and shadow_delta < 0.0:
		do_impact(null)
		return
	if projectile_type == PvZ.PROJECTILE_STAR and shadow_delta < 23.0:
		do_impact(null)
		return
	if cant_hit_high_ground():
		var board := _board()
		var gx := board.pixel_to_grid_x_keep_on_board(int(pos_x + 30), int(pos_y))
		if board.grid_square_type[gx][row] == PvZ.GRIDSQUARE_HIGH_GROUND:
			do_impact(null)

func is_splash_damage(zombie: Zombie) -> bool:
	if projectile_type != 0 and zombie and zombie.is_fire_resistant():
		return false
	return projectile_type == PvZ.PROJECTILE_MELON or projectile_type == PvZ.PROJECTILE_WINTERMELON or projectile_type == PvZ.PROJECTILE_FIREBALL

func get_damage_flags(zombie: Zombie) -> int:
	var flags := 0
	if is_splash_damage(zombie):
		flags = Tod.set_bit(flags, PvZ.DAMAGE_HITS_SHIELD_AND_BODY, true)
	elif motion_type == PvZ.MOTION_LOBBED or motion_type == PvZ.MOTION_BACKWARDS:
		flags = Tod.set_bit(flags, PvZ.DAMAGE_BYPASSES_SHIELD, true)
	elif motion_type == PvZ.MOTION_STAR and vel_x < 0.0:
		flags = Tod.set_bit(flags, PvZ.DAMAGE_BYPASSES_SHIELD, true)
	if projectile_type == PvZ.PROJECTILE_SNOWPEA or projectile_type == PvZ.PROJECTILE_WINTERMELON:
		flags = Tod.set_bit(flags, PvZ.DAMAGE_FREEZE, true)
	return flags

func is_zombie_hit_by_splash(zombie: Zombie) -> bool:
	var pr := get_projectile_rect()
	if projectile_type == PvZ.PROJECTILE_FIREBALL:
		pr.size.x = 100
	var row_dev: int = zombie.row - row
	if zombie.is_fire_resistant() and projectile_type == PvZ.PROJECTILE_FIREBALL:
		return false
	if zombie.zombie_type == PvZ.ZOMBIE_BOSS:
		row_dev = 0
	if projectile_type == PvZ.PROJECTILE_FIREBALL:
		if row_dev != 0:
			return false
	elif row_dev > 1 or row_dev < -1:
		return false
	return zombie.effected_by_damage(damage_range_flags) and LawnCommon.get_rect_overlap(pr, zombie.get_zombie_rect()) >= 0

func do_splash_damage(zombie: Zombie) -> void:
	var board := _board()
	var splashed := 0
	for z in board.zombies:
		if not z.dead and z != zombie and is_zombie_hit_by_splash(z):
			splashed += 1
	var original := get_damage()
	var splash := Tod.idiv(original, 3)
	var max_amount := splash * 7
	if projectile_type == PvZ.PROJECTILE_FIREBALL:
		max_amount = original
	var amount := splash * splashed
	if amount > max_amount:
		splash = Tod.idiv(original * max_amount, amount * 3)
		splash = maxi(splash, 1)
	for z in board.zombies.duplicate():
		if not z.dead and is_zombie_hit_by_splash(z):
			var flags := get_damage_flags(z)
			if z == zombie:
				z.take_damage(original, flags)
			else:
				z.take_damage(splash, flags)

func update_lob_motion() -> void:
	var board := _board()
	if projectile_type == PvZ.PROJECTILE_COBBIG and pos_z < -700.0:
		vel_z = 8.0
		row = cob_target_row
		pos_x = cob_target_x
		var col := board.pixel_to_grid_x_keep_on_board(int(cob_target_x), 0)
		pos_y = board.grid_to_pixel_y(col, cob_target_row)
		shadow_y = pos_y + 67.0
		rotation = -PI / 2
	vel_z += acc_z
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_HIGH_GRAVITY:
		vel_z += acc_z
	pos_x += vel_x
	pos_y += vel_y
	pos_z += vel_z
	var rising := vel_z < 0.0
	if rising and (projectile_type == PvZ.PROJECTILE_BASKETBALL or projectile_type == PvZ.PROJECTILE_COBBIG):
		return
	if projectile_age > 20:
		if rising:
			return
		var min_z := 0.0
		match projectile_type:
			PvZ.PROJECTILE_BUTTER: min_z = -32.0
			PvZ.PROJECTILE_BASKETBALL: min_z = 60.0
			PvZ.PROJECTILE_MELON, PvZ.PROJECTILE_WINTERMELON: min_z = -35.0
			PvZ.PROJECTILE_CABBAGE, PvZ.PROJECTILE_KERNEL: min_z = -30.0
			PvZ.PROJECTILE_COBBIG: min_z = -60.0
		if board.plant_row[row] == PvZ.PLANTROW_POOL:
			min_z += 40.0
		if pos_z <= min_z:
			return
	var plant: Plant = null
	var zombie: Zombie = null
	if projectile_type == PvZ.PROJECTILE_BASKETBALL or projectile_type == PvZ.PROJECTILE_ZOMBIE_PEA:
		plant = find_collision_target_plant()
	else:
		zombie = find_collision_target()
	var ground_z := -40.0 if projectile_type == PvZ.PROJECTILE_COBBIG else 80.0
	var hit_ground := pos_z > ground_z
	if zombie == null and plant == null and not hit_ground:
		return
	if plant:
		var umbrella := board.find_umbrella_plant(plant.plant_col, plant.row)
		if umbrella:
			if umbrella.state == PvZ.STATE_UMBRELLA_REFLECTING:
				App.play_foley(PvZ.FOLEY_SPLAT)
				App.add_tod_particle(pos_x + 20.0, pos_y + 20.0, BoardCore.make_render_order(PvZ.RENDER_LAYER_TOP, 0, 1), PvZ.PARTICLE_UMBRELLA_REFLECT)
				die()
			elif umbrella.state != PvZ.STATE_UMBRELLA_TRIGGERED:
				App.play_foley(PvZ.FOLEY_UMBRELLA)
				umbrella.do_special()
		else:
			plant.plant_health -= get_damage()
			plant.eaten_flash_countdown = maxi(plant.eaten_flash_countdown, 25)
			App.play_foley(PvZ.FOLEY_SPLAT)
			die()
	elif projectile_type == PvZ.PROJECTILE_COBBIG:
		if get_gargantuars(row, int(pos_x + 80), int(pos_y + 40), 115, 1):
			board.gargantuars_killed += 1
			if board.gargantuars_killed >= 2 and not App.playing_quickplay:
				App.get_achievement(PvZ.ACHIEVEMENT_POPCORN_PARTY)
		board.kill_all_zombies_in_radius(row, int(pos_x + 80), int(pos_y + 40), 115, 1, true, damage_range_flags)
		do_impact(null)
	else:
		do_impact(zombie)

func update_normal_motion() -> void:
	var board := _board()
	match motion_type:
		PvZ.MOTION_BACKWARDS:
			pos_x -= 3.33
		PvZ.MOTION_HOMING:
			var z: Zombie = BoardCore.try_get(target_zombie)
			if z and z.effected_by_damage(damage_range_flags):
				var zr: Rect2i = z.get_zombie_rect()
				var target := Vector2(z.zombie_target_lead_x(0.0), zr.position.y + Tod.idiv(zr.size.y, 2))
				var center := Vector2(pos_x + Tod.idiv(width, 2), pos_y + Tod.idiv(height, 2))
				var to_target := (target - center).normalized()
				var motion := Vector2(vel_x, vel_y)
				motion += to_target * (0.001 * projectile_age)
				motion = motion.normalized() * 2.0
				vel_x = motion.x
				vel_y = motion.y
				rotation = -atan2(vel_y, vel_x)
			pos_y += vel_y
			pos_x += vel_x
			shadow_y += vel_y
			row = board.pixel_to_grid_y_keep_on_board(int(pos_x), int(pos_y))
		PvZ.MOTION_STAR:
			pos_y += vel_y
			pos_x += vel_x
			shadow_y += vel_y
			if vel_y != 0.0:
				row = board.pixel_to_grid_y_keep_on_board(int(pos_x), int(pos_y))
		PvZ.MOTION_BEE:
			if projectile_age < 60:
				pos_y -= 0.5
			pos_x += 3.33
		PvZ.MOTION_FLOAT_OVER:
			if vel_z < 0.0:
				vel_z += 0.002
				vel_z = minf(vel_z, 0.0)
				pos_y += vel_z
				rotation = 0.3 - 0.7 * vel_z * PI * 0.25
			pos_x += 0.4
		PvZ.MOTION_BEE_BACKWARDS:
			if projectile_age < 60:
				pos_y -= 0.5
			pos_x -= 3.33
		PvZ.MOTION_THREEPEATER:
			pos_x += 3.33
			pos_y += vel_y
			vel_y *= 0.97
			shadow_y += vel_y
		_:
			pos_x += 3.33
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_HIGH_GRAVITY:
		if motion_type == PvZ.MOTION_FLOAT_OVER:
			vel_z += 0.004
		else:
			vel_z += 0.2
		pos_y += vel_z
	check_for_collision()
	check_for_high_ground()

func update_motion() -> void:
	var board := _board()
	if anim_ticks_per_frame > 0:
		anim_counter = (anim_counter + 1) % (num_frames * anim_ticks_per_frame)
		frame = Tod.idiv(anim_counter, anim_ticks_per_frame)
	var old_row := row
	var old_y := board.get_pos_y_based_on_row(pos_x, row)
	if motion_type == PvZ.MOTION_LOBBED:
		update_lob_motion()
	else:
		update_normal_motion()
	var slope := board.get_pos_y_based_on_row(pos_x, old_row) - old_y
	if projectile_type == PvZ.PROJECTILE_COBBIG:
		slope = 0.0
	if motion_type == PvZ.MOTION_FLOAT_OVER:
		pos_y += slope
	if motion_type == PvZ.MOTION_LOBBED:
		pos_y += slope
		pos_z -= slope
	shadow_y += slope
	x = int(pos_x)
	y = int(pos_y + pos_z)

func play_impact_sound(zombie: Zombie) -> void:
	var helm_sound := true
	var splat_sound := true
	if projectile_type == PvZ.PROJECTILE_KERNEL:
		App.play_foley(PvZ.FOLEY_KERNEL_SPLAT)
		helm_sound = false
		splat_sound = false
	elif projectile_type == PvZ.PROJECTILE_BUTTER:
		App.play_foley(PvZ.FOLEY_BUTTER)
		splat_sound = false
	elif projectile_type == PvZ.PROJECTILE_FIREBALL and is_splash_damage(zombie):
		App.play_foley(PvZ.FOLEY_IGNITE)
		helm_sound = false
		splat_sound = false
	elif projectile_type == PvZ.PROJECTILE_MELON or projectile_type == PvZ.PROJECTILE_WINTERMELON:
		App.play_foley(PvZ.FOLEY_MELONIMPACT)
		splat_sound = false
	if helm_sound and zombie:
		if zombie.helm_type == PvZ.HELMTYPE_PAIL:
			App.play_foley(PvZ.FOLEY_SHIELD_HIT)
			splat_sound = false
		elif zombie.helm_type == PvZ.HELMTYPE_TRAFFIC_CONE or zombie.helm_type == PvZ.HELMTYPE_DIGGER or zombie.helm_type == PvZ.HELMTYPE_FOOTBALL:
			App.play_foley(PvZ.FOLEY_PLASTIC_HIT)
	if splat_sound:
		App.play_foley(PvZ.FOLEY_SPLAT)

func do_impact(zombie: Zombie) -> void:
	var board := _board()
	play_impact_sound(zombie)
	if is_splash_damage(zombie):
		if projectile_type == PvZ.PROJECTILE_FIREBALL and zombie:
			zombie.remove_cold_effects()
		do_splash_damage(zombie)
	elif zombie:
		zombie.take_damage(get_damage(), get_damage_flags(zombie))
	var last_x := pos_x - vel_x
	var last_y := pos_y + pos_z - vel_y - vel_z
	var effect := PvZ.PARTICLE_NONE
	var splat_x := pos_x + 12.0
	var splat_y := pos_y + 12.0
	match projectile_type:
		PvZ.PROJECTILE_MELON:
			App.add_tod_particle(last_x + 30.0, last_y + 30.0, render_order + 1, PvZ.PARTICLE_MELONSPLASH)
		PvZ.PROJECTILE_WINTERMELON:
			App.add_tod_particle(last_x + 30.0, last_y + 30.0, render_order + 1, PvZ.PARTICLE_WINTERMELON)
		PvZ.PROJECTILE_COBBIG:
			App.add_tod_particle(pos_x + 80.0, pos_y + 40.0, BoardCore.make_render_order(PvZ.RENDER_LAYER_GROUND, cob_target_row, 2), PvZ.PARTICLE_BLASTMARK)
			App.add_tod_particle(pos_x + 80.0, pos_y + 40.0, render_order + 1, PvZ.PARTICLE_POPCORNSPLASH)
			App.play_sample("SOUND_DOOMSHROOM")
			board.shake_board(3, -4)
		PvZ.PROJECTILE_PEA:
			splat_x -= 15.0
			effect = PvZ.PARTICLE_PEA_SPLAT
		PvZ.PROJECTILE_SNOWPEA:
			splat_x -= 15.0
			effect = PvZ.PARTICLE_SNOWPEA_SPLAT
		PvZ.PROJECTILE_FIREBALL:
			if is_splash_damage(zombie):
				var fire := App.add_reanimation(pos_x + 38.0, pos_y - 20.0, render_order + 1, PvZ.REANIM_JALAPENO_FIRE)
				fire.anim_time = 0.25
				fire.anim_rate = 24.0
				fire.override_scale(0.7, 0.4)
		PvZ.PROJECTILE_STAR:
			effect = PvZ.PARTICLE_STAR_SPLAT
		PvZ.PROJECTILE_PUFF:
			splat_x -= 20.0
			effect = PvZ.PARTICLE_PUFF_SPLAT
		PvZ.PROJECTILE_CABBAGE:
			splat_x = last_x - 38.0
			splat_y = last_y + 23.0
			effect = PvZ.PARTICLE_CABBAGE_SPLAT
		PvZ.PROJECTILE_BUTTER:
			splat_x = last_x - 20.0
			splat_y = last_y + 63.0
			effect = PvZ.PARTICLE_BUTTER_SPLAT
			if zombie:
				zombie.apply_butter()
	if effect != PvZ.PARTICLE_NONE:
		if zombie:
			var ax := splat_x + 52.0 - zombie.x
			var ay := splat_y - zombie.y
			if zombie.zombie_phase == PvZ.PHASE_SNORKEL_WALKING_IN_POOL or zombie.zombie_phase == PvZ.PHASE_DOLPHIN_WALKING_IN_POOL:
				ay += 60.0
			if motion_type == PvZ.MOTION_BACKWARDS:
				ax -= 80.0
			elif pos_x > zombie.x + 40 and motion_type != PvZ.MOTION_LOBBED:
				ax -= 60.0
			ay = clampf(ay, 20.0, 100.0)
			zombie.add_attached_particle(int(ax), int(ay), effect)
		else:
			App.add_tod_particle(splat_x, splat_y, render_order + 1, effect)
	die()

func update() -> void:
	projectile_age += 1
	if App.game_scene != PvZ.SCENE_PLAYING and not _board().cut_scene.should_run_upsell_board():
		return
	var t := 20
	if projectile_type in [PvZ.PROJECTILE_PEA, PvZ.PROJECTILE_SNOWPEA, PvZ.PROJECTILE_CABBAGE, PvZ.PROJECTILE_MELON, PvZ.PROJECTILE_WINTERMELON,
			PvZ.PROJECTILE_KERNEL, PvZ.PROJECTILE_BUTTER, PvZ.PROJECTILE_COBBIG, PvZ.PROJECTILE_ZOMBIE_PEA, PvZ.PROJECTILE_SPIKE]:
		t = 0
	if projectile_age > t:
		render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_PROJECTILE, row, 0)
	if click_backoff_counter > 0:
		click_backoff_counter -= 1
	rotation += rotation_speed
	update_motion()
	Attachment.update_and_move(self, pos_x, pos_y + pos_z)

const _IMAGES := {
	PvZ.PROJECTILE_COBBIG: ["IMAGE_REANIM_COBCANNON_COB", 0.9],
	PvZ.PROJECTILE_PEA: ["IMAGE_PROJECTILEPEA", 1.0],
	PvZ.PROJECTILE_ZOMBIE_PEA: ["IMAGE_PROJECTILEPEA", 1.0],
	PvZ.PROJECTILE_SNOWPEA: ["IMAGE_PROJECTILESNOWPEA", 1.0],
	PvZ.PROJECTILE_SPIKE: ["IMAGE_PROJECTILECACTUS", 1.0],
	PvZ.PROJECTILE_STAR: ["IMAGE_PROJECTILE_STAR", 1.0],
	PvZ.PROJECTILE_PUFF: ["IMAGE_PUFFSHROOM_PUFF1", 1.0],
	PvZ.PROJECTILE_BASKETBALL: ["IMAGE_REANIM_ZOMBIE_CATAPULT_BASKETBALL", 1.1],
	PvZ.PROJECTILE_CABBAGE: ["IMAGE_REANIM_CABBAGEPULT_CABBAGE", 1.0],
	PvZ.PROJECTILE_KERNEL: ["IMAGE_REANIM_CORNPULT_KERNAL", 0.95],
	PvZ.PROJECTILE_BUTTER: ["IMAGE_REANIM_CORNPULT_BUTTER", 0.8],
	PvZ.PROJECTILE_MELON: ["IMAGE_REANIM_MELONPULT_MELON", 1.0],
	PvZ.PROJECTILE_WINTERMELON: ["IMAGE_REANIM_WINTERMELON_PROJECTILE", 1.0],
}

func draw(g: Graphics) -> void:
	var board := _board()
	if _IMAGES.has(projectile_type):
		var img := Res.get_image(_IMAGES[projectile_type][0])
		var sc: float = _IMAGES[projectile_type][1]
		if projectile_type == PvZ.PROJECTILE_PUFF:
			sc = Tod.animate_curve_float(0, 30, projectile_age, 0.3, 1.0, Tod.CURVE_LINEAR)
		var mirror := motion_type == PvZ.MOTION_BEE_BACKWARDS
		var cw := img.get_cel_width()
		var ch := img.get_cel_height()
		var image_row: int = LawnDefs.PROJECTILE_DEFS[projectile_type][1]
		var src := Rect2(cw * frame, ch * image_row, cw, ch)
		if Tod.approx_equal(rotation, 0.0) and Tod.approx_equal(sc, 1.0):
			g.draw_image_mirror_stretch(img, Rect2(0, 0, cw, ch), src, mirror)
		else:
			var ox := pos_x + cw * 0.5
			var oy := pos_z + pos_y + ch * 0.5
			var xf := Tod.scale_rotate_matrix(ox + board.x, oy + board.y, rotation, sc, sc)
			g.blt_matrix(img, xf, g.clip, Color.WHITE, g.draw_mode, src)
	if attachment != null:
		var pg := g.copy()
		make_parent_graphics_frame(pg)
		Attachment.draw_on(self, pg, false)

func draw_shadow(g: Graphics) -> void:
	var board := _board()
	var cel := 0
	var sc := 1.0
	var stretch := 1.0
	var ox := pos_x - x
	var oy := pos_y - y
	var gx := board.pixel_to_grid_x_keep_on_board(x, y)
	var is_high: bool = board.grid_square_type[gx][row] == PvZ.GRIDSQUARE_HIGH_GROUND
	if on_high_ground and not is_high:
		oy += PvZ.HIGH_GROUND_HEIGHT
	elif not on_high_ground and is_high:
		oy -= PvZ.HIGH_GROUND_HEIGHT
	if board.stage_is_night():
		cel = 1
	match projectile_type:
		PvZ.PROJECTILE_PEA, PvZ.PROJECTILE_ZOMBIE_PEA:
			ox += 3.0
		PvZ.PROJECTILE_SNOWPEA:
			ox += -1.0
			sc = 1.3
		PvZ.PROJECTILE_STAR:
			ox += 7.0
		PvZ.PROJECTILE_CABBAGE, PvZ.PROJECTILE_KERNEL, PvZ.PROJECTILE_BUTTER, PvZ.PROJECTILE_MELON, PvZ.PROJECTILE_WINTERMELON:
			ox += 3.0
			oy += 10.0
			sc = 1.6
		PvZ.PROJECTILE_PUFF:
			return
		PvZ.PROJECTILE_COBBIG:
			sc = 1.0
			stretch = 3.0
			ox += 57.0
		PvZ.PROJECTILE_FIREBALL:
			sc = 1.4
	if motion_type == PvZ.MOTION_LOBBED:
		var h := clampf(-pos_z, 0.0, 200.0)
		sc *= 200.0 / (h + 200.0)
	g.tod_draw_image_cel_scaled_f(Res.get_image("IMAGE_PEA_SHADOWS"), ox, shadow_y - pos_y + oy, cel, 0, sc * stretch, sc)

func die() -> void:
	dead = true
	if projectile_type == PvZ.PROJECTILE_PUFF or projectile_type == PvZ.PROJECTILE_SNOWPEA:
		Attachment.cross_fade_on(self, "FadeOut")
		Attachment.detach_on(self)
	else:
		Attachment.die_on(self)

func get_projectile_rect() -> Rect2i:
	match projectile_type:
		PvZ.PROJECTILE_PEA, PvZ.PROJECTILE_SNOWPEA, PvZ.PROJECTILE_ZOMBIE_PEA:
			return Rect2i(x - 15, y, width + 15, height)
		PvZ.PROJECTILE_COBBIG:
			return Rect2i(x + Tod.idiv(width, 2) - 115, y + Tod.idiv(height, 2) - 115, 230, 230)
		PvZ.PROJECTILE_MELON, PvZ.PROJECTILE_WINTERMELON:
			return Rect2i(x + 20, y, 60, height)
		PvZ.PROJECTILE_FIREBALL:
			return Rect2i(x, y, width - 10, height)
		PvZ.PROJECTILE_SPIKE:
			return Rect2i(x - 25, y, width + 25, height)
	return Rect2i(x, y, width, height)

func convert_to_fireball(gx: int) -> void:
	if hit_torchwood_grid_x == gx:
		return
	projectile_type = PvZ.PROJECTILE_FIREBALL
	hit_torchwood_grid_x = gx
	App.play_foley(PvZ.FOLEY_FIREPEA)
	var ox := -25.0
	var oy := -25.0
	var r := App.add_reanimation(0.0, 0.0, 0, PvZ.REANIM_FIRE_PEA)
	if motion_type == PvZ.MOTION_BACKWARDS:
		r.override_scale(-1.0, 1.0)
		ox += 80.0
	r.set_position(pos_x + ox, pos_y + oy)
	r.loop_type = Reanimation.REANIM_LOOP
	r.anim_rate = Tod.rand_range_float(50.0, 80.0)
	Attachment.attach_reanim(self, r, ox, oy)

func convert_to_pea(gx: int) -> void:
	if hit_torchwood_grid_x == gx:
		return
	Attachment.die_on(self)
	projectile_type = PvZ.PROJECTILE_PEA
	hit_torchwood_grid_x = gx
	App.play_foley(PvZ.FOLEY_THROW)

func get_damage() -> int:
	return LawnDefs.PROJECTILE_DEFS[projectile_type][2]

func get_gargantuars(the_row: int, px: int, py: int, radius: int, row_range: int) -> bool:
	for z in _board().zombies:
		if not z.dead and not z.is_dead_or_dying() and not z.mind_controlled and (z.zombie_type == PvZ.ZOMBIE_GARGANTUAR or z.zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR):
			var rd: int = z.row - the_row
			if rd <= row_range and rd >= -row_range and LawnCommon.get_circle_rect_overlap(px, py, radius, z.get_zombie_rect()):
				return true
	return false
