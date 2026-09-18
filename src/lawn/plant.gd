class_name Plant
extends GameObject
## Port of Plant: every plant's behaviour, animation and drawing.

const MAX_MAGNET_ITEMS := 5

class MagnetItem:
	var pos_x := 0.0
	var pos_y := 0.0
	var dest_offset_x := 0.0
	var dest_offset_y := 0.0
	var item_type := PvZ.MAGNET_ITEM_NONE

var seed_type := PvZ.SEED_PEASHOOTER
var plant_col := 0
var anim_counter := 0
var frame := 0
var frame_length := 0
var num_frames := 0
var state := PvZ.STATE_NOTREADY
var plant_health := 0
var plant_max_health := 0
var subclass := 0
var disappear_countdown := 0
var do_special_countdown := 0
var state_countdown := 0
var launch_counter := 0
var launch_rate := 0
var plant_rect := Rect2i()
var plant_attack_rect := Rect2i()
var target_x := -1
var target_y := -1
var start_row := 0
var particle: TodParticleSystem = null
var shooting_counter := 0
var body_reanim: Reanimation = null
var head_reanim: Reanimation = null
var head_reanim2: Reanimation = null
var head_reanim3: Reanimation = null
var blink_reanim: Reanimation = null
var light_reanim: Reanimation = null
var sleeping_reanim: Reanimation = null
var blink_countdown := 0
var recently_eaten_countdown := 0
var eaten_flash_countdown := 0
var beghouled_flash_countdown := 0
var shake_offset_x := 0.0
var shake_offset_y := 0.0
var magnet_items: Array = []
var target_zombie: Zombie = null
var wake_up_counter := 0
var on_bungee_state := PvZ.NOT_ON_BUNGEE
var imitater_type := PvZ.SEED_NONE
var potted_plant_index := -1
var anim_ping := false
var squished := false
var is_asleep := false
var is_on_board := false
var highlighted := false
var board: Board = null

func _init() -> void:
	board = App.board
	for i in MAX_MAGNET_ITEMS:
		magnet_items.append(MagnetItem.new())

static func create(_seed_type: int) -> Plant:
	return Plant.new()

## ReanimationTryToGet equivalent.
## Seed type this plant was planted from when it is one of a custom level's own plants.
## `seed_type` stays the base plant so every behaviour branch keeps working.
var custom_seed := PvZ.SEED_NONE

static func rv(r: Reanimation) -> Reanimation:
	if r == null or r.freed:
		return null
	return r

static func pv(p: TodParticleSystem) -> TodParticleSystem:
	if p == null or p.freed:
		return null
	return p

func _def() -> Array:
	## Custom plants keep their own definition (cost, recharge, reanim, fire rate) while
	## `seed_type` stays the base plant they behave like.
	return LawnCommon.plant_def(custom_seed if custom_seed != PvZ.SEED_NONE else seed_type)

func _new_head(rt: int, track: String, attach_to: Reanimation, attach_track: String) -> Reanimation:
	var h := App.add_reanimation(0.0, 0.0, render_order + 2, rt)
	h.loop_type = Reanimation.REANIM_LOOP
	h.anim_rate = attach_to.anim_rate
	h.set_frames_for_layer(track)
	if attach_track != "":
		h.attach_to_another_reanimation(attach_to, attach_track)
	return h

func plant_initialize(gx: int, gy: int, the_seed_type: int, the_imitater_type: int) -> void:
	custom_seed = PvZ.SEED_NONE
	if CustomDefs.is_custom_plant(the_seed_type):
		custom_seed = the_seed_type
		the_seed_type = CustomDefs.plant_base(the_seed_type)
	plant_col = gx
	row = gy
	if board:
		x = board.grid_to_pixel_x(gx, gy)
		y = board.grid_to_pixel_y(gx, gy)
	anim_counter = 0
	anim_ping = true
	frame = 0
	shooting_counter = 0
	shake_offset_x = 0.0
	shake_offset_y = 0.0
	frame_length = Tod.rand_range_int(12, 18)
	target_x = -1
	target_y = -1
	start_row = row
	num_frames = 5
	state = PvZ.STATE_NOTREADY
	dead = false
	squished = false
	seed_type = the_seed_type
	imitater_type = the_imitater_type
	plant_health = 300
	do_special_countdown = 0
	disappear_countdown = 200
	state_countdown = 0
	blink_countdown = 0
	recently_eaten_countdown = 0
	eaten_flash_countdown = 0
	beghouled_flash_countdown = 0
	width = 80
	height = 80
	var pdef := _def()
	is_asleep = false
	wake_up_counter = 0
	on_bungee_state = PvZ.NOT_ON_BUNGEE
	potted_plant_index = -1
	launch_rate = pdef[LawnCommon.PDEF_LAUNCH_RATE]
	subclass = pdef[LawnCommon.PDEF_SUBCLASS]
	render_order = calc_render_order()
	var rt: int = pdef[LawnCommon.PDEF_REANIM]
	var body: Reanimation = null
	if rt >= 0:
		var oy := plant_draw_height_offset(board, self, seed_type, plant_col, row)
		body = App.add_reanimation(0.0, oy, render_order + 1, rt)
		body.loop_type = Reanimation.REANIM_LOOP
		body.anim_rate = Tod.rand_range_float(10.0, 15.0)
		if body.track_exists("anim_idle"):
			body.set_frames_for_layer("anim_idle")
		if App.is_wallnut_bowling_level() and body.track_exists("_ground"):
			body.set_frames_for_layer("_ground")
			if seed_type == PvZ.SEED_WALLNUT or seed_type == PvZ.SEED_EXPLODE_O_NUT:
				body.anim_rate = Tod.rand_range_float(12.0, 18.0)
			elif seed_type == PvZ.SEED_GIANT_WALLNUT:
				body.anim_rate = Tod.rand_range_float(6.0, 10.0)
		body.is_attachment = true
		body_reanim = body
		blink_countdown = 400 + Tod.rand_int(400)
	if is_nocturnal(seed_type) and board and not board.stage_is_night():
		set_sleeping(true)
	if launch_rate > 0:
		if makes_sun():
			launch_counter = Tod.rand_range_int(300, Tod.idiv(launch_rate, 2))
		else:
			launch_counter = Tod.rand_range_int(0, launch_rate)
	else:
		launch_counter = 0
	match the_seed_type:
		PvZ.SEED_BLOVER:
			do_special_countdown = 50
			if is_in_play():
				body.set_frames_for_layer("anim_blow")
				body.loop_type = Reanimation.REANIM_PLAY_ONCE_AND_HOLD
				body.anim_rate = 20.0
			else:
				body.set_frames_for_layer("anim_idle")
				body.anim_rate = 10.0
		PvZ.SEED_PEASHOOTER, PvZ.SEED_SNOWPEA, PvZ.SEED_REPEATER, PvZ.SEED_LEFTPEATER, PvZ.SEED_GATLINGPEA:
			if body:
				body.anim_rate = Tod.rand_range_float(15.0, 20.0)
				var track := ""
				if body.track_exists("anim_stem"):
					track = "anim_stem"
				elif body.track_exists("anim_idle"):
					track = "anim_idle"
				head_reanim = _new_head(rt, "anim_head_idle", body, track)
		PvZ.SEED_SPLITPEA:
			body.anim_rate = Tod.rand_range_float(15.0, 20.0)
			head_reanim = _new_head(rt, "anim_head_idle", body, "anim_idle")
			head_reanim2 = _new_head(rt, "anim_splitpea_idle", body, "anim_idle")
		PvZ.SEED_THREEPEATER:
			body.anim_rate = Tod.rand_range_float(15.0, 20.0)
			head_reanim = _new_head(rt, "anim_head_idle1", body, "anim_head1")
			head_reanim2 = _new_head(rt, "anim_head_idle2", body, "anim_head2")
			head_reanim3 = _new_head(rt, "anim_head_idle3", body, "anim_head3")
		PvZ.SEED_WALLNUT, PvZ.SEED_GIANT_WALLNUT:
			plant_health = 4000
			blink_countdown = 1000 + Tod.rand_int(1000)
		PvZ.SEED_EXPLODE_O_NUT:
			plant_health = 4000
			blink_countdown = 1000 + Tod.rand_int(1000)
			body.color_override = Color8(255, 64, 64)
		PvZ.SEED_TALLNUT:
			plant_health = 8000
			height = 80
			blink_countdown = 1000 + Tod.rand_int(1000)
		PvZ.SEED_GARLIC:
			plant_health = 400
			body.set_truncate_disappearing_frames()
		PvZ.SEED_GOLD_MAGNET, PvZ.SEED_MAGNETSHROOM, PvZ.SEED_TANGLEKELP:
			body.set_truncate_disappearing_frames()
		PvZ.SEED_IMITATER:
			body.anim_rate = Tod.rand_range_float(25.0, 30.0)
			state_countdown = 200
		PvZ.SEED_CHERRYBOMB, PvZ.SEED_JALAPENO:
			if is_in_play():
				do_special_countdown = 100
				body.set_frames_for_layer("anim_explode")
				body.loop_type = Reanimation.REANIM_PLAY_ONCE_AND_HOLD
				App.play_foley(PvZ.FOLEY_REVERSE_EXPLOSION)
		PvZ.SEED_POTATOMINE:
			body.anim_rate = 12.0
			if is_in_play():
				body.assign_render_group_to_track("anim_glow", Reanimation.RENDER_GROUP_HIDDEN)
				state_countdown = 1500
			else:
				body.set_frames_for_layer("anim_armed")
				state = PvZ.STATE_POTATO_ARMED
		PvZ.SEED_GRAVEBUSTER:
			if is_in_play():
				body.set_frames_for_layer("anim_land")
				body.loop_type = Reanimation.REANIM_PLAY_ONCE_AND_HOLD
				state = PvZ.STATE_GRAVEBUSTER_LANDING
				App.play_foley(PvZ.FOLEY_GRAVEBUSTERCHOMP)
		PvZ.SEED_SUNSHROOM:
			body.frame_base_pose = 6
			if is_in_play():
				x += Tod.rand_int(10) - 5
				y += Tod.rand_int(10) - 5
			elif is_asleep:
				body.set_frames_for_layer("anim_bigsleep")
			else:
				body.set_frames_for_layer("anim_bigidle")
			state = PvZ.STATE_SUNSHROOM_SMALL
			state_countdown = 12000
		PvZ.SEED_PUFFSHROOM, PvZ.SEED_SEASHROOM:
			if is_in_play():
				x += Tod.rand_int(10) - 5
				y += Tod.rand_int(6) - 3
		PvZ.SEED_PUMPKINSHELL:
			plant_health = 4000
			width = 120
			body.assign_render_group_to_track("Pumpkin_back", 1)
		PvZ.SEED_CHOMPER:
			state = PvZ.STATE_READY
		PvZ.SEED_PLANTERN:
			state_countdown = 50
			if not is_on_board_check() or App.game_mode != PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
				add_attached_particle(x + 40, y + 40, PvZ.RENDER_LAYER_FOG + 1, PvZ.PARTICLE_LANTERN_SHINE)
			if is_in_play():
				App.play_sample("SOUND_PLANTERN")
		PvZ.SEED_MARIGOLD:
			body.anim_rate = Tod.rand_range_float(15.0, 20.0)
		PvZ.SEED_CACTUS:
			state = PvZ.STATE_CACTUS_LOW
		PvZ.SEED_INSTANT_COFFEE:
			do_special_countdown = 100
		PvZ.SEED_SCAREDYSHROOM:
			state = PvZ.STATE_READY
		PvZ.SEED_COBCANNON:
			if is_in_play():
				state = PvZ.STATE_COBCANNON_ARMING
				state_countdown = 500
				body.set_frames_for_layer("anim_unarmed_idle")
		PvZ.SEED_KERNELPULT:
			body.assign_render_group_to_prefix("Cornpult_butter", Reanimation.RENDER_GROUP_HIDDEN)
		PvZ.SEED_SPIKEROCK:
			plant_health = 450
		PvZ.SEED_FLOWERPOT:
			if is_in_play():
				state = PvZ.STATE_FLOWERPOT_INVULNERABLE
				state_countdown = 100
		PvZ.SEED_LILYPAD:
			if is_in_play():
				state = PvZ.STATE_LILYPAD_INVULNERABLE
				state_countdown = 100
	if custom_seed != PvZ.SEED_NONE:
		CustomDefs.apply_plant_profile(self)
	plant_max_health = plant_health
	if seed_type != PvZ.SEED_FLOWERPOT and is_on_board_check():
		var pot := board.get_flower_pot_at(plant_col, row)
		if pot and rv(pot.body_reanim):
			pot.body_reanim.anim_rate = 0.0

func calc_render_order() -> int:
	var order := PvZ.PLANT_ORDER_NORMAL
	var layer := PvZ.RENDER_LAYER_PLANT
	var st := seed_type
	if seed_type == PvZ.SEED_IMITATER and imitater_type != PvZ.SEED_NONE:
		st = imitater_type
	if App.is_wallnut_bowling_level():
		layer = PvZ.RENDER_LAYER_PROJECTILE
	elif st == PvZ.SEED_PUMPKINSHELL:
		order = PvZ.PLANT_ORDER_PUMPKIN
	elif is_flying(st):
		order = PvZ.PLANT_ORDER_FLYER
	elif st == PvZ.SEED_FLOWERPOT or (st == PvZ.SEED_LILYPAD and App.game_mode != PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN):
		order = PvZ.PLANT_ORDER_LILYPAD
	return BoardCore.make_render_order(layer, row, order * 5 - x + 800)

func set_sleeping(asleep: bool) -> void:
	if is_asleep == asleep or not_on_ground():
		return
	is_asleep = asleep
	if asleep:
		var px := x + 50.0
		var py := y + 40.0
		if seed_type == PvZ.SEED_FUMESHROOM:
			px += 12.0
		elif seed_type == PvZ.SEED_SCAREDYSHROOM:
			py -= 20.0
		elif seed_type == PvZ.SEED_GLOOMSHROOM:
			py -= 12.0
		var sr := App.add_reanimation(px, py, render_order + 2, PvZ.REANIM_SLEEPING)
		sr.loop_type = Reanimation.REANIM_LOOP
		sr.anim_rate = Tod.rand_range_float(6.0, 8.0)
		sr.anim_time = Tod.rand_range_float(0.0, 0.9)
		sleeping_reanim = sr
	else:
		if rv(sleeping_reanim):
			sleeping_reanim.die()
		sleeping_reanim = null
	var body := rv(body_reanim)
	if body == null:
		return
	if asleep:
		if not is_in_play() and seed_type == PvZ.SEED_SUNSHROOM:
			body.set_frames_for_layer("anim_bigsleep")
		elif body.track_exists("anim_sleep"):
			var t := body.anim_time
			body.start_blend(20)
			body.set_frames_for_layer("anim_sleep")
			body.anim_time = t
		else:
			body.anim_rate = 1.0
		end_blink()
	else:
		if not is_in_play() and seed_type == PvZ.SEED_SUNSHROOM:
			body.set_frames_for_layer("anim_bigidle")
		elif body.track_exists("anim_idle"):
			var t := body.anim_time
			body.start_blend(20)
			body.set_frames_for_layer("anim_idle")
			body.anim_time = t
		if body.anim_rate < 2.0 and is_in_play():
			body.anim_rate = Tod.rand_range_float(10.0, 15.0)

func get_damage_range_flags(weapon: int = PvZ.WEAPON_PRIMARY) -> int:
	match seed_type:
		PvZ.SEED_CACTUS: return 1 if weapon == PvZ.WEAPON_SECONDARY else 2
		PvZ.SEED_CHERRYBOMB, PvZ.SEED_JALAPENO, PvZ.SEED_COBCANNON, PvZ.SEED_DOOMSHROOM: return 127
		PvZ.SEED_MELONPULT, PvZ.SEED_CABBAGEPULT, PvZ.SEED_KERNELPULT, PvZ.SEED_WINTERMELON: return 13
		PvZ.SEED_POTATOMINE: return 77
		PvZ.SEED_SQUASH: return 13
		PvZ.SEED_PUFFSHROOM, PvZ.SEED_SEASHROOM, PvZ.SEED_FUMESHROOM, PvZ.SEED_GLOOMSHROOM, PvZ.SEED_CHOMPER: return 9
		PvZ.SEED_CATTAIL: return 11
		PvZ.SEED_TANGLEKELP: return 5
		PvZ.SEED_GIANT_WALLNUT: return 17
	return 1

func is_on_high_ground() -> bool:
	return board != null and board.grid_square_type[plant_col][row] == PvZ.GRIDSQUARE_HIGH_GROUND

func spike_rock_take_damage() -> void:
	var body := rv(body_reanim)
	spikeweed_attack()
	plant_health -= 50
	if plant_health <= 300 and body:
		body.assign_render_group_to_track("bigspike3", Reanimation.RENDER_GROUP_HIDDEN)
	if plant_health <= 150 and body:
		body.assign_render_group_to_track("bigspike2", Reanimation.RENDER_GROUP_HIDDEN)
	if plant_health <= 0:
		App.play_foley(PvZ.FOLEY_SQUISH)
		die()

func is_spiky() -> bool:
	return seed_type == PvZ.SEED_SPIKEWEED or seed_type == PvZ.SEED_SPIKEROCK

func do_row_area_damage(damage: int, damage_flags: int) -> void:
	var range_flags := get_damage_range_flags(PvZ.WEAPON_PRIMARY)
	var attack := get_plant_attack_rect(PvZ.WEAPON_PRIMARY)
	for z in board.zombies.duplicate():
		if z.dead:
			continue
		var dy: int = 0 if z.zombie_type == PvZ.ZOMBIE_BOSS else (z.row - row)
		if seed_type == PvZ.SEED_GLOOMSHROOM:
			if dy < -1 or dy > 1:
				continue
		elif dy != 0:
			continue
		if z.on_high_ground == is_on_high_ground() and z.effected_by_damage(range_flags):
			if LawnCommon.get_rect_overlap(attack, z.get_zombie_rect()) > 0:
				var dmg := damage
				if (z.zombie_type == PvZ.ZOMBIE_ZAMBONI or z.zombie_type == PvZ.ZOMBIE_CATAPULT) and Tod.test_bit(damage_flags, PvZ.DAMAGE_SPIKE):
					dmg = 1800
					if seed_type == PvZ.SEED_SPIKEROCK:
						spike_rock_take_damage()
					else:
						die()
				z.take_damage(dmg, damage_flags)
				App.play_foley(PvZ.FOLEY_SPLAT)

func add_attached_particle(px: int, py: int, order: int, effect: int) -> TodParticleSystem:
	var old := pv(particle)
	if old:
		old.particle_system_die()
	var ps := App.add_tod_particle(px, py, order, effect)
	if ps:
		particle = ps
	return ps

func _start_head_anim(r: Reanimation, track: String, rate: float, blend: int = 20) -> void:
	r.start_blend(blend)
	r.loop_type = Reanimation.REANIM_PLAY_ONCE_AND_HOLD
	r.anim_rate = rate
	r.set_frames_for_layer(track)

func find_target_and_fire(the_row: int, weapon: int = PvZ.WEAPON_PRIMARY) -> bool:
	var zombie := find_target_zombie(the_row, weapon)
	if zombie == null:
		return false
	end_blink()
	var body := rv(body_reanim)
	var head := rv(head_reanim)
	if seed_type == PvZ.SEED_SPLITPEA and weapon == PvZ.WEAPON_SECONDARY:
		_start_head_anim(head_reanim2, "anim_splitpea_shooting", 35.0)
		shooting_counter = 26
	elif head and head.track_exists("anim_shooting"):
		_start_head_anim(head, "anim_shooting", 35.0)
		shooting_counter = 33
		if seed_type == PvZ.SEED_REPEATER or seed_type == PvZ.SEED_SPLITPEA or seed_type == PvZ.SEED_LEFTPEATER:
			head.anim_rate = 45.0
			shooting_counter = 26
		elif seed_type == PvZ.SEED_GATLINGPEA:
			head.anim_rate = 38.0
			shooting_counter = 100
	elif state == PvZ.STATE_CACTUS_HIGH:
		play_body_reanim("anim_shootinghigh", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 35.0)
		shooting_counter = 23
	elif seed_type == PvZ.SEED_GLOOMSHROOM:
		play_body_reanim("anim_shooting", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 14.0)
		shooting_counter = 200
	elif seed_type == PvZ.SEED_CATTAIL:
		play_body_reanim("anim_shooting", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 30.0)
		shooting_counter = 50
	elif body and body.track_exists("anim_shooting"):
		play_body_reanim("anim_shooting", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 35.0)
		match seed_type:
			PvZ.SEED_FUMESHROOM: shooting_counter = 50
			PvZ.SEED_PUFFSHROOM: shooting_counter = 29
			PvZ.SEED_SCAREDYSHROOM: shooting_counter = 25
			PvZ.SEED_CABBAGEPULT: shooting_counter = 32
			PvZ.SEED_MELONPULT, PvZ.SEED_WINTERMELON: shooting_counter = 36
			PvZ.SEED_KERNELPULT:
				if Tod.rand_int(4) == 0:
					body.assign_render_group_to_prefix("Cornpult_butter", Reanimation.RENDER_GROUP_NORMAL)
					body.assign_render_group_to_prefix("Cornpult_kernal", Reanimation.RENDER_GROUP_HIDDEN)
					state = PvZ.STATE_KERNELPULT_BUTTER
				shooting_counter = 30
			PvZ.SEED_CACTUS: shooting_counter = 35
			_: shooting_counter = 29
	else:
		fire(zombie, the_row, weapon)
	return true

func launch_threepeater() -> void:
	var above := row - 1
	var below := row + 1
	if find_target_zombie(row, PvZ.WEAPON_PRIMARY) or (board.row_can_have_zombies(above) and find_target_zombie(above, PvZ.WEAPON_PRIMARY)) \
			or (board.row_can_have_zombies(below) and find_target_zombie(below, PvZ.WEAPON_PRIMARY)):
		if board.row_can_have_zombies(below):
			_start_head_anim(head_reanim, "anim_shooting1", 20.0, 10)
		_start_head_anim(head_reanim2, "anim_shooting2", 20.0, 10)
		if board.row_can_have_zombies(above):
			_start_head_anim(head_reanim3, "anim_shooting3", 20.0, 10)
		shooting_counter = 35

func find_star_fruit_target() -> bool:
	if recently_eaten_countdown > 0:
		return true
	var range_flags := get_damage_range_flags(PvZ.WEAPON_PRIMARY)
	var cx := x + 40
	var cy := y + 40
	for z in board.zombies:
		if z.dead:
			continue
		var zr: Rect2i = z.get_zombie_rect()
		if z.effected_by_damage(range_flags):
			if z.zombie_type == PvZ.ZOMBIE_BOSS and plant_col >= 5:
				return true
			if z.row == row:
				if zr.position.x + zr.size.x < cx:
					return true
			else:
				if z.zombie_type == PvZ.ZOMBIE_DIGGER:
					zr.position.x += 10
				var t := Tod.distance_2d(cx, cy, zr.position.x + Tod.idiv(zr.size.x, 2), zr.position.y + Tod.idiv(zr.size.y, 2)) / 3.33
				var hit_x: int = int(z.zombie_target_lead_x(t)) - Tod.idiv(zr.size.x, 2)
				if hit_x + zr.size.x > cx and hit_x < cx:
					return true
				var zcx := hit_x + Tod.idiv(zr.size.x, 2)
				var zcy := zr.position.y + Tod.idiv(zr.size.y, 2)
				var angle := rad_to_deg(atan2(zcy - cy, zcx - cx))
				if absi(z.row - row) < 2:
					if (angle > 20.0 and angle < 40.0) or (angle < -25.0 and angle > -45.0):
						return true
				else:
					if (angle > 25.0 and angle < 35.0) or (angle < -28.0 and angle > -38.0):
						return true
	return false

func launch_star_fruit() -> void:
	if find_star_fruit_target():
		play_body_reanim("anim_shoot", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 28.0)
		shooting_counter = 40

func star_fruit_fire() -> void:
	App.play_foley(PvZ.FOLEY_THROW)
	var ax := cos(deg_to_rad(30.0)) * 3.33
	var ay := sin(deg_to_rad(30.0)) * 3.33
	for i in 5:
		var p := board.add_projectile(x + 25, y + 25, render_order - 1, row, PvZ.PROJECTILE_STAR)
		p.damage_range_flags = get_damage_range_flags(PvZ.WEAPON_PRIMARY)
		p.motion_type = PvZ.MOTION_STAR
		match i:
			0: p.vel_x = -3.33; p.vel_y = 0.0
			1: p.vel_x = 0.0; p.vel_y = 3.33
			2: p.vel_x = 0.0; p.vel_y = -3.33
			3: p.vel_x = ax; p.vel_y = ay
			4: p.vel_x = ax; p.vel_y = -ay

func update_shooter() -> void:
	launch_counter -= 1
	if launch_counter <= 0:
		launch_counter = launch_rate - Tod.rand_int(15)
		if seed_type == PvZ.SEED_THREEPEATER:
			launch_threepeater()
		elif seed_type == PvZ.SEED_STARFRUIT:
			launch_star_fruit()
		elif seed_type == PvZ.SEED_SPLITPEA:
			find_target_and_fire(row, PvZ.WEAPON_SECONDARY)
		elif seed_type == PvZ.SEED_CACTUS:
			if state == PvZ.STATE_CACTUS_HIGH:
				find_target_and_fire(row, PvZ.WEAPON_PRIMARY)
			elif state == PvZ.STATE_CACTUS_LOW:
				find_target_and_fire(row, PvZ.WEAPON_SECONDARY)
		else:
			find_target_and_fire(row, PvZ.WEAPON_PRIMARY)
	if launch_counter == 50 and seed_type == PvZ.SEED_CATTAIL:
		find_target_and_fire(row, PvZ.WEAPON_PRIMARY)
	if launch_counter == 25:
		if seed_type == PvZ.SEED_REPEATER or seed_type == PvZ.SEED_LEFTPEATER:
			find_target_and_fire(row, PvZ.WEAPON_PRIMARY)
		elif seed_type == PvZ.SEED_SPLITPEA:
			find_target_and_fire(row, PvZ.WEAPON_PRIMARY)
			find_target_and_fire(row, PvZ.WEAPON_SECONDARY)

func makes_sun() -> bool:
	return seed_type == PvZ.SEED_SUNFLOWER or seed_type == PvZ.SEED_TWINSUNFLOWER or seed_type == PvZ.SEED_SUNSHROOM

func update_production_plant() -> void:
	if not is_in_play() or App.is_izombie_level() or App.game_mode == PvZ.GAMEMODE_UPSELL or App.game_mode == PvZ.GAMEMODE_INTRO:
		return
	if board.has_level_award_dropped():
		return
	if seed_type == PvZ.SEED_MARIGOLD and board.current_wave == board.num_waves:
		if state != PvZ.STATE_MARIGOLD_ENDING:
			state = PvZ.STATE_MARIGOLD_ENDING
			state_countdown = 6000
		elif state_countdown <= 0:
			return
	launch_counter -= 1
	if launch_counter <= 100:
		eaten_flash_countdown = maxi(eaten_flash_countdown, Tod.animate_curve(100, 0, launch_counter, 0, 100, Tod.CURVE_LINEAR))
	if launch_counter <= 0:
		launch_counter = Tod.rand_range_int(launch_rate - 150, launch_rate)
		App.play_foley(PvZ.FOLEY_SPAWN_SUN)
		match seed_type:
			PvZ.SEED_SUNSHROOM:
				board.add_coin(x, y, PvZ.COIN_SMALLSUN if state == PvZ.STATE_SUNSHROOM_SMALL else PvZ.COIN_SUN, PvZ.COIN_MOTION_FROM_PLANT)
			PvZ.SEED_SUNFLOWER:
				board.add_coin(x, y, PvZ.COIN_SUN, PvZ.COIN_MOTION_FROM_PLANT)
			PvZ.SEED_TWINSUNFLOWER:
				board.add_coin(x, y, PvZ.COIN_SUN, PvZ.COIN_MOTION_FROM_PLANT)
				board.add_coin(x, y, PvZ.COIN_SUN, PvZ.COIN_MOTION_FROM_PLANT)
			PvZ.SEED_MARIGOLD:
				board.add_coin(x, y, PvZ.COIN_GOLD if Tod.rand_int(100) < 10 else PvZ.COIN_SILVER, PvZ.COIN_MOTION_COIN)

func update_sun_shroom() -> void:
	var body := rv(body_reanim)
	if state == PvZ.STATE_SUNSHROOM_SMALL:
		if state_countdown == 0:
			play_body_reanim("anim_grow", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 10, 12.0)
			state = PvZ.STATE_SUNSHROOM_GROWING
			App.play_foley(PvZ.FOLEY_PLANTGROW)
		update_production_plant()
	elif state == PvZ.STATE_SUNSHROOM_GROWING:
		if body.loop_count > 0:
			play_body_reanim("anim_bigidle", Reanimation.REANIM_LOOP, 10, Tod.rand_range_float(12.0, 15.0))
			state = PvZ.STATE_SUNSHROOM_BIG
	else:
		update_production_plant()

func update_grave_buster() -> void:
	if state == PvZ.STATE_GRAVEBUSTER_LANDING:
		if body_reanim.loop_count > 0:
			play_body_reanim("anim_idle", Reanimation.REANIM_LOOP, 10, 12.0)
			state_countdown = 400
			state = PvZ.STATE_GRAVEBUSTER_EATING
			add_attached_particle(x + 40, y + 40, render_order + 4, PvZ.PARTICLE_GRAVE_BUSTER)
	elif state == PvZ.STATE_GRAVEBUSTER_EATING and state_countdown == 0:
		var grave := board.get_grave_stone_at(plant_col, row)
		if grave:
			grave.grid_item_die()
			board.graves_cleared += 1
		App.add_tod_particle(x + 40, y + 40, render_order + 4, PvZ.PARTICLE_GRAVE_BUSTER_DIE)
		die()
		board.drop_loot_piece(x + 40, y, 12)

func play_body_reanim(track: String, loop: int, blend: int, rate: float) -> void:
	var body := body_reanim
	if blend > 0:
		body.start_blend(blend)
	if rate > 0.0:
		body.anim_rate = rate
	body.loop_type = loop
	body.loop_count = 0
	body.set_frames_for_layer(track)

func update_potato() -> void:
	var body := body_reanim
	if state == PvZ.STATE_NOTREADY:
		if state_countdown == 0:
			App.add_tod_particle(x + Tod.idiv(width, 2), y + Tod.idiv(height, 2), render_order, PvZ.PARTICLE_POTATO_MINE_RISE)
			play_body_reanim("anim_rise", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 18.0)
			state = PvZ.STATE_POTATO_RISING
			App.play_foley(PvZ.FOLEY_DIRT_RISE)
	elif state == PvZ.STATE_POTATO_RISING:
		if body.loop_count > 0:
			var rate := Tod.rand_range_float(12.0, 15.0)
			play_body_reanim("anim_armed", Reanimation.REANIM_LOOP, 0, rate)
			var light := App.add_reanimation(0.0, 0.0, render_order + 2, _def()[LawnCommon.PDEF_REANIM])
			light.loop_type = Reanimation.REANIM_LOOP
			light.anim_rate = rate - 2.0
			light.set_frames_for_layer("anim_glow")
			light.frame_count = 10
			light.show_only_track("anim_glow")
			light.set_truncate_disappearing_frames("anim_glow", false)
			light_reanim = light
			light.attach_to_another_reanimation(body, "anim_light")
			state = PvZ.STATE_POTATO_ARMED
			blink_countdown = 400 + Tod.rand_int(4000)
	elif state == PvZ.STATE_POTATO_ARMED:
		if find_target_zombie(row, PvZ.WEAPON_PRIMARY):
			do_special()
		else:
			var light := rv(light_reanim)
			if light:
				light.frame_count = Tod.animate_curve(200, 50, distance_to_closest_zombie(), 10, 3, Tod.CURVE_LINEAR)

func update_tanglekelp() -> void:
	if state != PvZ.STATE_TANGLEKELP_GRABBING:
		var z := find_target_zombie(row, PvZ.WEAPON_PRIMARY)
		if z:
			App.play_foley(PvZ.FOLEY_FLOOP)
			state = PvZ.STATE_TANGLEKELP_GRABBING
			state_countdown = 100
			z.pool_splash(false)
			var vx := -13.0
			var vy := 15.0
			if z.zombie_type == PvZ.ZOMBIE_SNORKEL:
				vx = -43.0
				vy = 55.0
			if z.zombie_phase == PvZ.PHASE_DOLPHIN_RIDING:
				vx = -20.0
				vy = 37.0
			var grab: Reanimation = z.add_attached_reanim(int(vx), int(vy), PvZ.REANIM_TANGLEKELP)
			if grab:
				grab.set_frames_for_layer("anim_grab")
				grab.anim_rate = 24.0
				grab.loop_type = Reanimation.REANIM_PLAY_ONCE_AND_HOLD
			target_zombie = z
	else:
		if state_countdown == 50:
			var z: Zombie = BoardCore.try_get(target_zombie)
			if z:
				z.drag_under()
				z.pool_splash(false)
		if state_countdown == 20:
			var order := BoardCore.make_render_order(PvZ.RENDER_LAYER_PARTICLE, row, 0)
			var splash := App.add_reanimation(x - 23, y + 7, order, PvZ.REANIM_SPLASH)
			splash.override_scale(1.3, 1.3)
			App.add_tod_particle(x + 31, y + 64, order, PvZ.PARTICLE_PLANTING_POOL)
			App.play_foley(PvZ.FOLEY_ZOMBIE_ENTERING_WATER)
		if state_countdown == 0:
			die()
			var z: Zombie = BoardCore.try_get(target_zombie)
			if z:
				z.die_with_loot()

func spikeweed_attack() -> void:
	if state != PvZ.STATE_SPIKEWEED_ATTACKING:
		play_body_reanim("anim_attack", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 18.0)
		App.play_sample("SOUND_THROW")
		state = PvZ.STATE_SPIKEWEED_ATTACKING
		state_countdown = 100

func update_spikeweed() -> void:
	var body := body_reanim
	if state == PvZ.STATE_SPIKEWEED_ATTACKING:
		if state_countdown == 0:
			state = PvZ.STATE_NOTREADY
		elif seed_type == PvZ.SEED_SPIKEROCK:
			if state_countdown == 69 or state_countdown == 33:
				do_row_area_damage(20, 33)
		elif state_countdown == 75:
			do_row_area_damage(20, 33)
		if body.loop_count > 0:
			play_idle_anim(Tod.rand_range_float(12.0, 15.0))
	elif find_target_zombie(row, PvZ.WEAPON_PRIMARY):
		spikeweed_attack()

func update_scaredy_shroom() -> void:
	if shooting_counter > 0:
		return
	var nearby := false
	for z in board.zombies:
		if z.dead:
			continue
		var dy: int = 0 if z.zombie_type == PvZ.ZOMBIE_BOSS else (z.row - row)
		if not z.mind_controlled and not z.is_dead_or_dying() and dy <= 1 and dy >= -1 and LawnCommon.get_circle_rect_overlap(x, int(y + 20.0), 120, z.get_zombie_rect()):
			nearby = true
			break
	var body := body_reanim
	if state == PvZ.STATE_READY:
		if nearby:
			state = PvZ.STATE_SCAREDYSHROOM_LOWERING
			play_body_reanim("anim_scared", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 10, 10.0)
	elif state == PvZ.STATE_SCAREDYSHROOM_LOWERING:
		if body.loop_count > 0:
			state = PvZ.STATE_SCAREDYSHROOM_SCARED
			play_body_reanim("anim_scaredidle", Reanimation.REANIM_LOOP, 10, 0.0)
	elif state == PvZ.STATE_SCAREDYSHROOM_SCARED:
		if not nearby:
			state = PvZ.STATE_SCAREDYSHROOM_RAISING
			play_body_reanim("anim_grow", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 10, Tod.rand_range_float(7.0, 12.0))
	elif state == PvZ.STATE_SCAREDYSHROOM_RAISING:
		if body.loop_count > 0:
			state = PvZ.STATE_READY
			play_idle_anim(Tod.rand_range_float(10.0, 15.0))
	if state != PvZ.STATE_READY:
		launch_counter = launch_rate

func update_torchwood() -> void:
	var attack := get_plant_attack_rect(PvZ.WEAPON_PRIMARY)
	for p in board.projectiles:
		if p.dead:
			continue
		if p.row == row and (p.projectile_type == PvZ.PROJECTILE_PEA or p.projectile_type == PvZ.PROJECTILE_SNOWPEA):
			if LawnCommon.get_rect_overlap(attack, p.get_projectile_rect()) >= 10:
				if p.projectile_type == PvZ.PROJECTILE_PEA:
					p.convert_to_fireball(plant_col)
				elif p.projectile_type == PvZ.PROJECTILE_SNOWPEA:
					p.convert_to_pea(plant_col)

func do_squash_damage() -> void:
	var range_flags := get_damage_range_flags(PvZ.WEAPON_PRIMARY)
	var attack := get_plant_attack_rect(PvZ.WEAPON_PRIMARY)
	for z in board.zombies.duplicate():
		if z.dead:
			continue
		if (z.row == row or z.zombie_type == PvZ.ZOMBIE_BOSS) and z.effected_by_damage(range_flags):
			if LawnCommon.get_rect_overlap(attack, z.get_zombie_rect()) > (-20 if z.zombie_type == PvZ.ZOMBIE_FOOTBALL else 0):
				z.take_damage(1800, 18)

func find_squash_target() -> Zombie:
	var range_flags := get_damage_range_flags(PvZ.WEAPON_PRIMARY)
	var attack := get_plant_attack_rect(PvZ.WEAPON_PRIMARY)
	var closest_range := 0
	var closest: Zombie = null
	for z in board.zombies:
		if z.dead:
			continue
		if (z.row == row or z.zombie_type == PvZ.ZOMBIE_BOSS) and z.has_head and not z.is_tangle_kelp_target() and z.effected_by_damage(range_flags):
			var zr: Rect2i = z.get_zombie_rect()
			var ph: int = z.zombie_phase
			if (ph == PvZ.PHASE_POLEVAULTER_PRE_VAULT and zr.position.x < x + 20) or (ph != PvZ.PHASE_POLEVAULTER_PRE_VAULT \
					and ph != PvZ.PHASE_POLEVAULTER_IN_VAULT and ph != PvZ.PHASE_SNORKEL_INTO_POOL and ph != PvZ.PHASE_DOLPHIN_INTO_POOL \
					and ph != PvZ.PHASE_DOLPHIN_RIDING and ph != PvZ.PHASE_DOLPHIN_IN_JUMP and not z.is_bobsled_team_with_sled()):
				var rng := -LawnCommon.get_rect_overlap(attack, zr)
				if rng <= (110 if z.is_eating else 70):
					var px := attack.position.x
					if ph == PvZ.PHASE_POLEVAULTER_POST_VAULT or ph == PvZ.PHASE_POLEVAULTER_PRE_VAULT or ph == PvZ.PHASE_DOLPHIN_WALKING_IN_POOL \
							or z.zombie_type == PvZ.ZOMBIE_IMP or z.zombie_type == PvZ.ZOMBIE_FOOTBALL or App.is_scary_potter_level():
						px = attack.position.x - 60
					if z.is_walking_backwards() or zr.position.x + zr.size.x >= px:
						if z == target_zombie:
							return z
						if closest == null or rng < closest_range:
							closest = z
							closest_range = rng
	return closest

func update_squash() -> void:
	if state == PvZ.STATE_NOTREADY:
		var z := find_squash_target()
		if z:
			target_zombie = z
			target_x = int(z.zombie_target_lead_x(0.0)) - Tod.idiv(width, 2)
			state = PvZ.STATE_SQUASH_LOOK
			state_countdown = 80
			play_body_reanim("anim_lookleft" if target_x < x else "anim_lookright", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 10, 24.0)
			App.play_foley(PvZ.FOLEY_SQUASH_HMM)
	elif state == PvZ.STATE_SQUASH_LOOK:
		if state_countdown <= 0:
			play_body_reanim("anim_jumpup", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 24.0)
			state = PvZ.STATE_SQUASH_PRE_LAUNCH
			state_countdown = 30
	elif state == PvZ.STATE_SQUASH_PRE_LAUNCH:
		if state_countdown <= 0:
			var z := find_squash_target()
			if z:
				target_x = int(z.zombie_target_lead_x(30.0)) - Tod.idiv(width, 2)
			state = PvZ.STATE_SQUASH_RISING
			state_countdown = 50
			render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_PARTICLE, row, 0)
	else:
		var target_col := board.pixel_to_grid_x_keep_on_board(target_x, y)
		var dest_y := board.grid_to_pixel_y(target_col, row) + 8
		if state == PvZ.STATE_SQUASH_RISING:
			x = Tod.animate_curve(50, 20, state_countdown, board.grid_to_pixel_x(plant_col, start_row), target_x, Tod.CURVE_EASE_IN_OUT)
			y = Tod.animate_curve(50, 20, state_countdown, board.grid_to_pixel_y(plant_col, start_row), dest_y - 120, Tod.CURVE_EASE_IN_OUT)
			if state_countdown == 0:
				play_body_reanim("anim_jumpdown", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 60.0)
				state = PvZ.STATE_SQUASH_FALLING
				state_countdown = 10
		elif state == PvZ.STATE_SQUASH_FALLING:
			y = Tod.animate_curve(10, 0, state_countdown, dest_y - 120, dest_y, Tod.CURVE_EASE_IN_OUT)
			if state_countdown == 5:
				do_squash_damage()
			if state_countdown == 0:
				if board.is_pool_square(target_col, row):
					App.add_reanimation(x - 11, y + 20, render_order + 1, PvZ.REANIM_SPLASH)
					App.play_foley(PvZ.FOLEY_SPLAT)
					App.play_sample("SOUND_ZOMBIESPLASH")
					die()
				else:
					state = PvZ.STATE_SQUASH_DONE_FALLING
					state_countdown = 100
					board.shake_board(1, 4)
					App.play_foley(PvZ.FOLEY_THUMP)
					var oy := 69.0 if board.stage_has_roof() else 80.0
					App.add_tod_particle(x + 40, y + oy, render_order + 4, PvZ.PARTICLE_DUST_SQUASH)
		elif state == PvZ.STATE_SQUASH_DONE_FALLING:
			if state_countdown == 0:
				die()

func update_doom_shroom() -> void:
	if is_asleep or state == PvZ.STATE_DOINGSPECIAL:
		return
	state = PvZ.STATE_DOINGSPECIAL
	do_special_countdown = 100
	var body := body_reanim
	body.set_frames_for_layer("anim_explode")
	body.anim_rate = 23.0
	body.loop_type = Reanimation.REANIM_PLAY_ONCE_AND_HOLD
	body.set_shake_override("DoomShroom_head1", 1.0)
	body.set_shake_override("DoomShroom_head2", 2.0)
	body.set_shake_override("DoomShroom_head3", 2.0)
	App.play_foley(PvZ.FOLEY_REVERSE_EXPLOSION)

func update_ice_shroom() -> void:
	if not is_asleep and state != PvZ.STATE_DOINGSPECIAL:
		state = PvZ.STATE_DOINGSPECIAL
		do_special_countdown = 100

func update_blover() -> void:
	var body := body_reanim
	if body.loop_count > 0 and body.loop_type != Reanimation.REANIM_LOOP:
		body.set_frames_for_layer("anim_loop")
		body.loop_type = Reanimation.REANIM_LOOP
	if state != PvZ.STATE_DOINGSPECIAL and state_countdown == 0:
		do_special()

func update_flower_pot() -> void:
	if state == PvZ.STATE_FLOWERPOT_INVULNERABLE and state_countdown == 0:
		state = PvZ.STATE_NOTREADY

func update_lilypad() -> void:
	if state == PvZ.STATE_LILYPAD_INVULNERABLE and state_countdown == 0:
		state = PvZ.STATE_NOTREADY

func update_coffee_bean() -> void:
	if state == PvZ.STATE_DOINGSPECIAL:
		if body_reanim.loop_count > 0:
			die()

func update_umbrella() -> void:
	if state == PvZ.STATE_UMBRELLA_TRIGGERED:
		if state_countdown == 0:
			render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_PROJECTILE, row + 1, 0)
			state = PvZ.STATE_UMBRELLA_REFLECTING
	elif state == PvZ.STATE_UMBRELLA_REFLECTING:
		if body_reanim.loop_count > 0:
			play_idle_anim(0.0)
			state = PvZ.STATE_NOTREADY
			render_order = calc_render_order()

func update_cob_cannon() -> void:
	var body := body_reanim
	if state == PvZ.STATE_COBCANNON_ARMING:
		if state_countdown == 0:
			state = PvZ.STATE_COBCANNON_LOADING
			play_body_reanim("anim_charge", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 12.0)
	elif state == PvZ.STATE_COBCANNON_LOADING:
		if body.should_trigger_timed_event(0.5):
			App.play_foley(PvZ.FOLEY_SHOOP)
		if body.loop_count > 0:
			state = PvZ.STATE_COBCANNON_READY
			play_idle_anim(12.0)
	elif state == PvZ.STATE_COBCANNON_READY:
		body.get_track_instance("CobCannon_cob").track_color = Tod.get_flashing_color(board.main_counter, 75)
	elif state == PvZ.STATE_COBCANNON_FIRING:
		if body.should_trigger_timed_event(0.48):
			App.play_foley(PvZ.FOLEY_COB_LAUNCH)

func update_cactus() -> void:
	if shooting_counter > 0:
		return
	var body := body_reanim
	if state == PvZ.STATE_CACTUS_RISING:
		if body.loop_count > 0:
			state = PvZ.STATE_CACTUS_HIGH
			play_body_reanim("anim_idlehigh", Reanimation.REANIM_LOOP, 20, 0.0)
			launch_counter = 1
	elif state == PvZ.STATE_CACTUS_HIGH:
		if find_target_zombie(row, PvZ.WEAPON_PRIMARY) == null:
			state = PvZ.STATE_CACTUS_LOWERING
			play_body_reanim("anim_lower", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, body.definition.fps)
	elif state == PvZ.STATE_CACTUS_LOWERING:
		if body.loop_count > 0:
			state = PvZ.STATE_CACTUS_LOW
			play_idle_anim(0.0)
	elif find_target_zombie(row, PvZ.WEAPON_PRIMARY):
		state = PvZ.STATE_CACTUS_RISING
		play_body_reanim("anim_rise", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, body.definition.fps)
		App.play_foley(PvZ.FOLEY_PLANTGROW)

func update_chomper() -> void:
	var body := rv(body_reanim)
	if state == PvZ.STATE_READY:
		if find_target_zombie(row, PvZ.WEAPON_PRIMARY):
			play_body_reanim("anim_bite", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 24.0)
			state = PvZ.STATE_CHOMPER_BITING
			state_countdown = 70
	elif state == PvZ.STATE_CHOMPER_BITING:
		if state_countdown == 0:
			App.play_foley(PvZ.FOLEY_BIGCHOMP)
			var z := find_target_zombie(row, PvZ.WEAPON_PRIMARY)
			var do_bite := false
			if z and (z.zombie_type == PvZ.ZOMBIE_GARGANTUAR or z.zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR or z.zombie_type == PvZ.ZOMBIE_BOSS):
				do_bite = true
			var do_miss := false
			if z == null:
				do_miss = true
			elif not z.is_immobilizied():
				if z.is_bouncing_pogo() or z.zombie_phase == PvZ.PHASE_POLEVAULTER_IN_VAULT or z.zombie_phase == PvZ.PHASE_POLEVAULTER_PRE_VAULT:
					do_miss = true
			if do_bite:
				App.play_foley(PvZ.FOLEY_SPLAT)
				z.take_damage(40, 0)
				state = PvZ.STATE_CHOMPER_BITING_MISSED
			elif do_miss:
				state = PvZ.STATE_CHOMPER_BITING_MISSED
			else:
				z.die_with_loot()
				state = PvZ.STATE_CHOMPER_BITING_GOT_ONE
	elif state == PvZ.STATE_CHOMPER_BITING_GOT_ONE:
		if body.loop_count > 0:
			play_body_reanim("anim_chew", Reanimation.REANIM_LOOP, 0, 15.0)
			state = PvZ.STATE_CHOMPER_DIGESTING
			state_countdown = 4000
	elif state == PvZ.STATE_CHOMPER_DIGESTING:
		if state_countdown == 0:
			play_body_reanim("anim_swallow", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 12.0)
			state = PvZ.STATE_CHOMPER_SWALLOWING
	elif (state == PvZ.STATE_CHOMPER_SWALLOWING or state == PvZ.STATE_CHOMPER_BITING_MISSED) and body.loop_count > 0:
		play_idle_anim(body.definition.fps)
		state = PvZ.STATE_READY

func get_free_magnet_item() -> MagnetItem:
	if seed_type == PvZ.SEED_GOLD_MAGNET:
		for m in magnet_items:
			if m.item_type == PvZ.MAGNET_ITEM_NONE:
				return m
		return null
	return magnet_items[0]

func magnet_shroom_attact_item(z: Zombie) -> void:
	state = PvZ.STATE_MAGNETSHROOM_SUCKING
	state_countdown = 1500
	play_body_reanim("anim_shooting", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 12.0)
	App.play_foley(PvZ.FOLEY_MAGNETSHROOM)
	var m := get_free_magnet_item()
	if z.helm_type == PvZ.HELMTYPE_PAIL:
		var dmg: int = z.get_helm_damage_index()
		z.helm_health = 0
		z.helm_type = PvZ.HELMTYPE_NONE
		var p: Vector2 = z.get_track_position("anim_bucket")
		z.reanim_show_prefix("anim_bucket", Reanimation.RENDER_GROUP_HIDDEN)
		z.reanim_show_prefix("anim_hair", Reanimation.RENDER_GROUP_NORMAL)
		var img := Res.get_image("IMAGE_REANIM_ZOMBIE_BUCKET1")
		m.pos_x = p.x - Tod.idiv(img.width, 2)
		m.pos_y = p.y - Tod.idiv(img.height, 2)
		m.dest_offset_x = Tod.rand_range_float(-10.0, 10.0) + 25.0
		m.dest_offset_y = Tod.rand_range_float(-10.0, 10.0) + 20.0
		m.item_type = PvZ.MAGNET_ITEM_PAIL_1 + dmg
	elif z.helm_type == PvZ.HELMTYPE_FOOTBALL:
		var dmg: int = z.get_helm_damage_index()
		z.helm_health = 0
		z.helm_type = PvZ.HELMTYPE_NONE
		var p: Vector2 = z.get_track_position("zombie_football_helmet")
		z.reanim_show_prefix("zombie_football_helmet", Reanimation.RENDER_GROUP_HIDDEN)
		z.reanim_show_prefix("anim_hair", Reanimation.RENDER_GROUP_NORMAL)
		m.pos_x = p.x + 37.0
		m.pos_y = p.y - 60.0
		m.dest_offset_x = Tod.rand_range_float(-10.0, 10.0) + 20.0
		m.dest_offset_y = Tod.rand_range_float(-10.0, 10.0) + 20.0
		m.item_type = PvZ.MAGNET_ITEM_FOOTBALL_HELMET_1 + dmg
	elif z.shield_type == PvZ.SHIELDTYPE_DOOR:
		var dmg: int = z.get_shield_damage_index()
		z.detach_shield()
		z.zombie_phase = PvZ.PHASE_ZOMBIE_NORMAL
		if not z.is_eating:
			z.start_walk_anim(0)
		var p: Vector2 = z.get_track_position("anim_screendoor")
		var img := Res.get_image("IMAGE_REANIM_ZOMBIE_SCREENDOOR1")
		m.pos_x = p.x - Tod.idiv(img.width, 2)
		m.pos_y = p.y - Tod.idiv(img.height, 2)
		m.dest_offset_x = Tod.rand_range_float(-10.0, 10.0) + 30.0
		m.dest_offset_y = Tod.rand_range_float(-10.0, 10.0)
		m.item_type = PvZ.MAGNET_ITEM_DOOR_1 + dmg
	elif z.shield_type == PvZ.SHIELDTYPE_LADDER:
		var dmg: int = z.get_shield_damage_index()
		z.detach_shield()
		var img := Res.get_image("IMAGE_REANIM_ZOMBIE_LADDER_5")
		m.pos_x = z.pos_x + 31.0 - Tod.idiv(img.width, 2)
		m.pos_y = z.pos_y + 20.0 - Tod.idiv(img.height, 2)
		m.dest_offset_x = Tod.rand_range_float(-10.0, 10.0) + 30.0
		m.dest_offset_y = Tod.rand_range_float(-10.0, 10.0)
		m.item_type = PvZ.MAGNET_ITEM_LADDER_1 + dmg
	elif z.zombie_type == PvZ.ZOMBIE_POGO:
		z.pogo_break(16)
		var p: Vector2 = z.get_track_position("Zombie_pogo_stick")
		var img := Res.get_image("IMAGE_REANIM_ZOMBIE_LADDER_5")
		m.pos_x = p.x + 40.0 - Tod.idiv(img.width, 2)
		m.pos_y = p.y + 84.0 - Tod.idiv(img.height, 2)
		m.dest_offset_x = Tod.rand_range_float(-10.0, 10.0) + 30.0
		m.dest_offset_y = Tod.rand_range_float(-10.0, 10.0)
		m.item_type = PvZ.MAGNET_ITEM_POGO_1 if z.has_arm else PvZ.MAGNET_ITEM_POGO_3
	elif z.zombie_phase == PvZ.PHASE_JACK_IN_THE_BOX_RUNNING:
		z.stop_zombie_sound()
		z.pick_random_speed()
		z.zombie_phase = PvZ.PHASE_ZOMBIE_NORMAL
		z.reanim_show_prefix("Zombie_jackbox_box", Reanimation.RENDER_GROUP_HIDDEN)
		z.reanim_show_prefix("Zombie_jackbox_handle", Reanimation.RENDER_GROUP_HIDDEN)
		var p: Vector2 = z.get_track_position("Zombie_jackbox_box")
		var img := Res.get_image("IMAGE_REANIM_ZOMBIE_JACKBOX_BOX")
		m.pos_x = p.x - Tod.idiv(img.width, 2)
		m.pos_y = p.y - Tod.idiv(img.height, 2)
		m.dest_offset_x = Tod.rand_range_float(-10.0, 10.0) + 20.0
		m.dest_offset_y = Tod.rand_range_float(-10.0, 10.0) + 15.0
		m.item_type = PvZ.MAGNET_ITEM_JACK_IN_THE_BOX
	elif z.zombie_type == PvZ.ZOMBIE_DIGGER:
		z.digger_lose_axe()
		var p: Vector2 = z.get_track_position("Zombie_digger_pickaxe")
		var img := Res.get_image("IMAGE_REANIM_ZOMBIE_DIGGER_PICKAXE")
		m.pos_x = p.x - Tod.idiv(img.width, 2)
		m.pos_y = p.y - Tod.idiv(img.height, 2)
		m.dest_offset_x = Tod.rand_range_float(-10.0, 10.0) + 45.0
		m.dest_offset_y = Tod.rand_range_float(-10.0, 10.0) + 15.0
		m.item_type = PvZ.MAGNET_ITEM_PICK_AXE

func draw_magnet_items_on_top() -> bool:
	if seed_type == PvZ.SEED_GOLD_MAGNET:
		for m in magnet_items:
			if m.item_type != PvZ.MAGNET_ITEM_NONE:
				return true
		return false
	if seed_type == PvZ.SEED_MAGNETSHROOM:
		for m in magnet_items:
			if m.item_type != PvZ.MAGNET_ITEM_NONE:
				if Vector2(x + m.dest_offset_x - m.pos_x, y + m.dest_offset_y - m.pos_y).length() > 20.0:
					return true
	return false

func update_magnet_shroom() -> void:
	for m in magnet_items:
		if m.item_type != PvZ.MAGNET_ITEM_NONE:
			var v := Vector2(x + m.dest_offset_x - m.pos_x, y + m.dest_offset_y - m.pos_y)
			if v.length() > 20.0:
				m.pos_x += v.x * 0.05
				m.pos_y += v.y * 0.05
	if state == PvZ.STATE_MAGNETSHROOM_CHARGING:
		if state_countdown == 0:
			state = PvZ.STATE_READY
			play_body_reanim("anim_idle", Reanimation.REANIM_LOOP, 30, Tod.rand_range_float(10.0, 15.0))
			magnet_items[0].item_type = PvZ.MAGNET_ITEM_NONE
	elif state == PvZ.STATE_MAGNETSHROOM_SUCKING:
		if body_reanim.loop_count > 0:
			play_body_reanim("anim_nonactive_idle2", Reanimation.REANIM_LOOP, 20, 2.0)
			state = PvZ.STATE_MAGNETSHROOM_CHARGING
	else:
		var closest_dist := 0.0
		var closest: Zombie = null
		for z in board.zombies:
			if z.dead:
				continue
			var dy: int = z.row - row
			var zr: Rect2i = z.get_zombie_rect()
			if z.mind_controlled or not z.has_head:
				continue
			if z.zombie_height != PvZ.HEIGHT_ZOMBIE_NORMAL or z.zombie_phase == PvZ.PHASE_RISING_FROM_GRAVE:
				continue
			if z.is_dead_or_dying():
				continue
			if zr.position.x > PvZ.BOARD_WIDTH or dy > 2 or dy < -2:
				continue
			if z.zombie_phase == PvZ.PHASE_DIGGER_TUNNELING or z.zombie_phase == PvZ.PHASE_DIGGER_STUNNED \
					or z.zombie_phase == PvZ.PHASE_DIGGER_WALKING or z.zombie_type == PvZ.ZOMBIE_POGO:
				if not z.has_object:
					continue
			elif not (z.helm_type == PvZ.HELMTYPE_PAIL or z.helm_type == PvZ.HELMTYPE_FOOTBALL or z.shield_type == PvZ.SHIELDTYPE_DOOR \
					or z.shield_type == PvZ.SHIELDTYPE_LADDER or z.zombie_phase == PvZ.PHASE_JACK_IN_THE_BOX_RUNNING):
				continue
			var radius := 320 if z.is_eating else 270
			if LawnCommon.get_circle_rect_overlap(x, y + 20, radius, zr):
				var dist := Tod.distance_2d(x, y, zr.position.x, zr.position.y) + absi(dy) * 80.0
				if closest == null or dist < closest_dist:
					closest = z
					closest_dist = dist
		if closest:
			magnet_shroom_attact_item(closest)
			return
		var closest_ladder_dist := 0.0
		var closest_ladder: GridItem = null
		for gi in board.grid_items:
			if not gi.dead and gi.grid_item_type == PvZ.GRIDITEM_LADDER:
				var ddx := absi(gi.grid_x - plant_col)
				var ddy := absi(gi.grid_y - row)
				var sq := maxi(ddx, ddy)
				if sq <= 2:
					var dist := sq + ddy * 0.05
					if closest_ladder == null or dist < closest_ladder_dist:
						closest_ladder = gi
						closest_ladder_dist = dist
		if closest_ladder:
			state = PvZ.STATE_MAGNETSHROOM_SUCKING
			state_countdown = 1500
			play_body_reanim("anim_shooting", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 12.0)
			App.play_foley(PvZ.FOLEY_MAGNETSHROOM)
			closest_ladder.grid_item_die()
			var m := get_free_magnet_item()
			m.pos_x = board.grid_to_pixel_x(closest_ladder.grid_x, closest_ladder.grid_y) + 40
			m.pos_y = board.grid_to_pixel_y(closest_ladder.grid_x, closest_ladder.grid_y)
			m.dest_offset_x = Tod.rand_range_float(-10.0, 10.0) + 10.0
			m.dest_offset_y = Tod.rand_range_float(-10.0, 10.0)
			m.item_type = PvZ.MAGNET_ITEM_LADDER_PLACED

func find_gold_magnet_target() -> Coin:
	var closest: Coin = null
	var closest_dist := 0.0
	for c in board.coins:
		if not c.dead and c.is_money() and c.coin_motion != PvZ.COIN_MOTION_FROM_PRESENT and not c.is_being_collected and c.coin_age >= 50:
			var d := Tod.distance_2d(x + Tod.idiv(width, 2), y + Tod.idiv(height, 2), c.pos_x + Tod.idiv(c.width, 2), c.pos_y + Tod.idiv(c.height, 2))
			if closest == null or d < closest_dist:
				closest = c
				closest_dist = d
	return closest

func gold_magnet_find_targets() -> void:
	if get_free_magnet_item() == null:
		return
	while true:
		var m := get_free_magnet_item()
		if m == null:
			break
		var c := find_gold_magnet_target()
		if c == null:
			break
		m.pos_x = c.pos_x + 15.0
		m.pos_y = c.pos_y + 15.0
		m.dest_offset_x = Tod.rand_range_float(20.0, 40.0)
		m.dest_offset_y = Tod.rand_range_float(-20.0, 0.0) + 20.0
		match c.type:
			PvZ.COIN_SILVER: m.item_type = PvZ.MAGNET_ITEM_SILVER_COIN
			PvZ.COIN_GOLD: m.item_type = PvZ.MAGNET_ITEM_GOLD_COIN
			PvZ.COIN_DIAMOND: m.item_type = PvZ.MAGNET_ITEM_DIAMOND
		c.die()

func is_a_gold_magnet_about_to_suck() -> bool:
	for p in board.plants:
		if not p.dead and not p.not_on_ground() and p.seed_type == PvZ.SEED_GOLD_MAGNET and p.state == PvZ.STATE_MAGNETSHROOM_SUCKING:
			if p.body_reanim.anim_time < 0.5:
				return true
	return false

func update_gold_magnet_shroom() -> void:
	var body := body_reanim
	var sucking := false
	for m in magnet_items:
		if m.item_type != PvZ.MAGNET_ITEM_NONE:
			var v := Vector2(x + m.dest_offset_x - m.pos_x, y + m.dest_offset_y - m.pos_y)
			var d := v.length()
			if d < 20.0:
				var ct := PvZ.COIN_SILVER
				match m.item_type:
					PvZ.MAGNET_ITEM_GOLD_COIN: ct = PvZ.COIN_GOLD
					PvZ.MAGNET_ITEM_DIAMOND: ct = PvZ.COIN_DIAMOND
				var val := Coin.get_coin_value(ct)
				App.player_info.add_coins(val)
				board.coins_collected += val
				App.play_foley(PvZ.FOLEY_COIN)
				m.item_type = PvZ.MAGNET_ITEM_NONE
			else:
				var speed := Tod.animate_curve_float_time(30.0, 0.0, d, 0.02, 0.05, Tod.CURVE_LINEAR)
				m.pos_x += v.x * speed
				m.pos_y += v.y * speed
				sucking = true
	if state == PvZ.STATE_MAGNETSHROOM_CHARGING:
		if state_countdown == 0:
			state = PvZ.STATE_READY
	elif state == PvZ.STATE_MAGNETSHROOM_SUCKING:
		if body.should_trigger_timed_event(0.4):
			App.play_foley(PvZ.FOLEY_MAGNETSHROOM)
			gold_magnet_find_targets()
		if body.loop_count > 0 and not sucking:
			play_idle_anim(14.0)
			state = PvZ.STATE_MAGNETSHROOM_CHARGING
			state_countdown = Tod.rand_range_int(200, 300)
	elif not is_a_gold_magnet_about_to_suck() and Tod.rand_int(50) == 0 and find_gold_magnet_target():
		board.show_coin_bank()
		state = PvZ.STATE_MAGNETSHROOM_SUCKING
		play_body_reanim("anim_attract", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 12.0)

func remove_effects() -> void:
	if pv(particle):
		particle.particle_system_die()
	for r in [body_reanim, head_reanim, head_reanim2, head_reanim3, light_reanim, blink_reanim, sleeping_reanim]:
		if rv(r):
			r.die()

func squish() -> void:
	if not_on_ground():
		return
	if not is_asleep:
		if seed_type in [PvZ.SEED_CHERRYBOMB, PvZ.SEED_JALAPENO, PvZ.SEED_DOOMSHROOM, PvZ.SEED_ICESHROOM]:
			do_special()
			return
		elif seed_type == PvZ.SEED_POTATOMINE and state != PvZ.STATE_NOTREADY:
			do_special()
			return
	if seed_type == PvZ.SEED_SQUASH and state != PvZ.STATE_NOTREADY:
		return
	render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_GRAVE_STONE, row, 8)
	squished = true
	disappear_countdown = 500
	App.play_foley(PvZ.FOLEY_SQUISH)
	remove_effects()
	var ladder := board.get_ladder_at(plant_col, row)
	if ladder:
		ladder.grid_item_die()

func update_bowling() -> void:
	var body := rv(body_reanim)
	if body and body.has_ground_track():
		var speed := body.get_ground_velocity()
		if seed_type == PvZ.SEED_GIANT_WALLNUT:
			speed *= 2
		x -= int(speed)
		if x > 800 + PvZ.BOARD_ADDITIONAL_WIDTH:
			die()
	if state == PvZ.STATE_BOWLING_UP:
		y -= 2
	elif state == PvZ.STATE_BOWLING_DOWN:
		y += 2
	var dist := board.grid_to_pixel_y(0, row) - y
	if dist < -2 or dist > 2:
		return
	var new_state := state
	if state == PvZ.STATE_BOWLING_UP and row <= 0:
		new_state = PvZ.STATE_BOWLING_DOWN
	elif state == PvZ.STATE_BOWLING_DOWN and row >= 4:
		new_state = PvZ.STATE_BOWLING_UP
	var z := find_target_zombie(row, PvZ.WEAPON_PRIMARY)
	if z:
		var px := x + Tod.idiv(width, 2)
		var py := y + Tod.idiv(height, 2)
		if seed_type == PvZ.SEED_EXPLODE_O_NUT:
			App.play_foley(PvZ.FOLEY_CHERRYBOMB)
			App.play_sample("SOUND_BOWLINGIMPACT2")
			board.kill_all_zombies_in_radius(row, px, py, 90, 1, true, get_damage_range_flags(PvZ.WEAPON_PRIMARY) | 32)
			App.add_tod_particle(px, py, PvZ.RENDER_LAYER_TOP, PvZ.PARTICLE_POWIE)
			board.shake_board(3, -4)
			die()
			return
		App.play_foley(PvZ.FOLEY_BOWLINGIMPACT)
		board.shake_board(1, -2)
		if seed_type == PvZ.SEED_GIANT_WALLNUT:
			z.take_damage(1800, 0)
		elif z.shield_type == PvZ.SHIELDTYPE_DOOR and state != PvZ.STATE_NOTREADY:
			z.take_damage(1800, 0)
		elif z.shield_type != PvZ.SHIELDTYPE_NONE:
			z.take_shield_damage(400, 0)
		elif z.helm_type != PvZ.HELMTYPE_NONE:
			if z.helm_type == PvZ.HELMTYPE_PAIL:
				App.play_foley(PvZ.FOLEY_SHIELD_HIT)
			elif z.helm_type == PvZ.HELMTYPE_TRAFFIC_CONE:
				App.play_foley(PvZ.FOLEY_PLASTIC_HIT)
			z.take_helm_damage(900, 0)
		else:
			z.take_damage(1800, 0)
		if (not App.is_first_time_adventure_mode() or App.player_info.level > 10) and seed_type == PvZ.SEED_WALLNUT and not App.playing_quickplay:
			launch_counter += 1
			if launch_counter == 2:
				App.play_foley(PvZ.FOLEY_SPAWN_SUN)
				board.add_coin(px, py, PvZ.COIN_SILVER, PvZ.COIN_MOTION_COIN)
			elif launch_counter == 3:
				App.play_foley(PvZ.FOLEY_SPAWN_SUN)
				board.add_coin(px - 5, py, PvZ.COIN_SILVER, PvZ.COIN_MOTION_COIN)
				board.add_coin(px + 5, py, PvZ.COIN_SILVER, PvZ.COIN_MOTION_COIN)
			elif launch_counter == 4:
				App.play_foley(PvZ.FOLEY_SPAWN_SUN)
				board.add_coin(px - 10, py, PvZ.COIN_SILVER, PvZ.COIN_MOTION_COIN)
				board.add_coin(px, py, PvZ.COIN_SILVER, PvZ.COIN_MOTION_COIN)
				board.add_coin(px + 10, py, PvZ.COIN_SILVER, PvZ.COIN_MOTION_COIN)
			elif launch_counter >= 5:
				App.play_foley(PvZ.FOLEY_SPAWN_SUN)
				board.add_coin(px, py, PvZ.COIN_GOLD, PvZ.COIN_MOTION_COIN)
				App.get_achievement(PvZ.ACHIEVEMENT_ROLL_SOME_HEADS)
		if seed_type != PvZ.SEED_GIANT_WALLNUT:
			if row == 4 or state == PvZ.STATE_BOWLING_DOWN:
				new_state = PvZ.STATE_BOWLING_UP
			elif row == 0 or state == PvZ.STATE_BOWLING_UP:
				new_state = PvZ.STATE_BOWLING_DOWN
			else:
				new_state = PvZ.STATE_BOWLING_UP if Tod.rand_int(2) != 0 else PvZ.STATE_BOWLING_DOWN
	if new_state == PvZ.STATE_BOWLING_UP:
		row -= 1
		state = PvZ.STATE_BOWLING_UP
		render_order = calc_render_order()
	elif new_state == PvZ.STATE_BOWLING_DOWN:
		state = PvZ.STATE_BOWLING_DOWN
		render_order = calc_render_order()
		row += 1

func update_abilities() -> void:
	if not is_in_play():
		return
	if state == PvZ.STATE_DOINGSPECIAL or squished:
		disappear_countdown -= 1
		if disappear_countdown < 0:
			die()
			return
	if wake_up_counter > 0:
		wake_up_counter -= 1
		if wake_up_counter == 60:
			App.play_foley(PvZ.FOLEY_WAKEUP)
		if wake_up_counter == 0:
			set_sleeping(false)
	if is_asleep or squished or on_bungee_state != PvZ.NOT_ON_BUNGEE:
		return
	update_shooting()
	if state_countdown > 0:
		state_countdown -= 1
	if App.is_wallnut_bowling_level():
		update_bowling()
		return
	match seed_type:
		PvZ.SEED_SQUASH: update_squash()
		PvZ.SEED_DOOMSHROOM: update_doom_shroom()
		PvZ.SEED_ICESHROOM: update_ice_shroom()
		PvZ.SEED_CHOMPER: update_chomper()
		PvZ.SEED_BLOVER: update_blover()
		PvZ.SEED_FLOWERPOT: update_flower_pot()
		PvZ.SEED_LILYPAD: update_lilypad()
		PvZ.SEED_IMITATER: update_imitater()
		PvZ.SEED_INSTANT_COFFEE: update_coffee_bean()
		PvZ.SEED_UMBRELLA: update_umbrella()
		PvZ.SEED_COBCANNON: update_cob_cannon()
		PvZ.SEED_CACTUS: update_cactus()
		PvZ.SEED_MAGNETSHROOM: update_magnet_shroom()
		PvZ.SEED_GOLD_MAGNET: update_gold_magnet_shroom()
		PvZ.SEED_SUNSHROOM: update_sun_shroom()
		PvZ.SEED_SUNFLOWER, PvZ.SEED_TWINSUNFLOWER, PvZ.SEED_MARIGOLD: update_production_plant()
		PvZ.SEED_GRAVEBUSTER: update_grave_buster()
		PvZ.SEED_TORCHWOOD: update_torchwood()
		PvZ.SEED_POTATOMINE: update_potato()
		PvZ.SEED_SPIKEWEED, PvZ.SEED_SPIKEROCK: update_spikeweed()
		PvZ.SEED_TANGLEKELP: update_tanglekelp()
		PvZ.SEED_SCAREDYSHROOM: update_scaredy_shroom()
	if subclass == PvZ.SUBCLASS_SHOOTER:
		update_shooter()
	if do_special_countdown > 0:
		do_special_countdown -= 1
		if do_special_countdown == 0:
			do_special()

func is_part_of_upgradable_to(upgraded: int) -> bool:
	if upgraded == PvZ.SEED_COBCANNON and seed_type == PvZ.SEED_KERNELPULT:
		return board.is_valid_cob_cannon_spot(plant_col, row) or board.is_valid_cob_cannon_spot(plant_col - 1, row)
	return is_upgradable_to(upgraded)

func is_upgradable_to(upgraded: int) -> bool:
	if upgraded == PvZ.SEED_GATLINGPEA and seed_type == PvZ.SEED_REPEATER: return true
	if upgraded == PvZ.SEED_WINTERMELON and seed_type == PvZ.SEED_MELONPULT: return true
	if upgraded == PvZ.SEED_TWINSUNFLOWER and seed_type == PvZ.SEED_SUNFLOWER: return true
	if upgraded == PvZ.SEED_SPIKEROCK and seed_type == PvZ.SEED_SPIKEWEED: return true
	if upgraded == PvZ.SEED_COBCANNON and seed_type == PvZ.SEED_KERNELPULT: return board.is_valid_cob_cannon_spot(plant_col, row)
	if upgraded == PvZ.SEED_GOLD_MAGNET and seed_type == PvZ.SEED_MAGNETSHROOM: return true
	if upgraded == PvZ.SEED_GLOOMSHROOM and seed_type == PvZ.SEED_FUMESHROOM: return true
	if upgraded == PvZ.SEED_CATTAIL and seed_type == PvZ.SEED_LILYPAD:
		var p := board.get_top_plant_at(plant_col, row, PvZ.TOPPLANT_ONLY_NORMAL_POSITION)
		return p == null or p.seed_type != PvZ.SEED_CATTAIL
	return false

func update_reanim_color() -> void:
	if not is_on_board_check():
		return
	var body := rv(body_reanim)
	if body == null:
		return
	var cursor_seed := board.get_seed_type_in_cursor()
	var color_override: Color
	var on_glove := false
	if board.cursor_object.cursor_type == PvZ.CURSOR_TYPE_PLANT_FROM_GLOVE:
		var gp: Plant = BoardCore.try_get(board.cursor_object.glove_plant)
		if gp and gp.plant_col == plant_col and gp.row == row:
			on_glove = true
	if on_glove:
		color_override = Color8(128, 128, 128)
	elif is_part_of_upgradable_to(cursor_seed) and board.can_plant_at(plant_col, row, cursor_seed) == PvZ.PLANTING_OK:
		color_override = Tod.get_flashing_color(board.main_counter, 90)
	elif cursor_seed == PvZ.SEED_COBCANNON and seed_type == PvZ.SEED_KERNELPULT and board.can_plant_at(plant_col - 1, row, cursor_seed) == PvZ.PLANTING_OK:
		color_override = Tod.get_flashing_color(board.main_counter, 90)
	elif seed_type == PvZ.SEED_EXPLODE_O_NUT:
		color_override = Color8(255, 64, 64)
	else:
		color_override = Color8(255, 255, 255)
	body.color_override = color_override
	if highlighted:
		body.extra_additive_color = Color8(255, 255, 255, 196)
		body.enable_extra_additive_draw = true
		if imitater_type == PvZ.SEED_IMITATER:
			body.extra_additive_color = Color8(255, 255, 255, 92)
	elif beghouled_flash_countdown > 0:
		body.extra_additive_color = Color8(255, 255, 255, Tod.animate_curve(50, 0, beghouled_flash_countdown % 50, 0, 128, Tod.CURVE_BOUNCE))
		body.enable_extra_additive_draw = true
	elif eaten_flash_countdown > 0:
		var gray := clampi(eaten_flash_countdown * 3, 0, 128 if imitater_type == PvZ.SEED_IMITATER else 255)
		body.extra_additive_color = Color8(gray, gray, gray)
		body.enable_extra_additive_draw = true
	else:
		body.enable_extra_additive_draw = false
	if beghouled_flash_countdown > 0:
		body.extra_overlay_color = Color8(255, 255, 255, Tod.animate_curve(50, 0, beghouled_flash_countdown % 50, 0, 128, Tod.CURVE_BOUNCE))
		body.enable_extra_overlay_draw = true
	else:
		body.enable_extra_overlay_draw = false
	body.propogate_color_to_attachments()

## IsOnBoard (named to avoid clashing with the is_on_board flag).
func is_on_board_check() -> bool:
	return is_on_board

func is_in_play() -> bool:
	return is_on_board and App.game_mode != PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN and App.game_mode != PvZ.GAMEMODE_TREE_OF_WISDOM

func update_reanim() -> void:
	var body := rv(body_reanim)
	if body == null:
		return
	update_reanim_color()
	var ox := shake_offset_x
	var oy := plant_draw_height_offset(board, self, seed_type, plant_col, row)
	var sx := 1.0
	var sy := 1.0
	if seed_type == PvZ.SEED_GIANT_WALLNUT:
		sx = 2.0
		sy = 2.0
		ox -= 76.0
		oy -= 64.0
	if seed_type == PvZ.SEED_INSTANT_COFFEE:
		sx = 0.8
		sy = 0.8
		ox += 12.0
		oy += 10.0
	if seed_type == PvZ.SEED_POTATOMINE:
		sx = 0.8
		sy = 0.8
		ox += 12.0
		oy += 12.0
	if state == PvZ.STATE_GRAVEBUSTER_EATING:
		oy += Tod.animate_curve_float(400, 0, state_countdown, 0.0, 30.0, Tod.CURVE_LINEAR)
	if wake_up_counter > 0:
		var f := Tod.animate_curve_float(70, 0, wake_up_counter, 1.0, 0.8, Tod.CURVE_EASE_SIN_WAVE)
		sy *= f
		oy += 80.0 - 80.0 * f
	body.update()
	if seed_type == PvZ.SEED_LEFTPEATER:
		ox += 80.0 * sx
		sx *= -1.0
	if potted_plant_index != -1:
		var pp = App.player_info.potted_plants[potted_plant_index]
		if pp.facing == PlayerInfo.PottedPlant.FACING_LEFT:
			ox += 80.0 * sx
			sx *= -1.0
		var ox_s: float
		var ox_e: float
		var oy_s: float
		var oy_e: float
		var sc_s: float
		var sc_e: float
		if pp.plant_age == PvZ.PLANTAGE_SMALL:
			ox_s = 20.0; ox_e = 20.0; oy_s = 40.0; oy_e = 40.0; sc_s = 0.5; sc_e = 0.5
		elif pp.plant_age == PvZ.PLANTAGE_MEDIUM:
			ox_s = 20.0; ox_e = 10.0; oy_s = 40.0; oy_e = 20.0; sc_s = 0.5; sc_e = 0.75
		else:
			ox_s = 10.0; ox_e = 0.0; oy_s = 20.0; oy_e = 0.0; sc_s = 0.75; sc_e = 1.0
		var aox := Tod.animate_curve_float(100, 0, state_countdown, ox_s, ox_e, Tod.CURVE_LINEAR)
		var aoy := Tod.animate_curve_float(100, 0, state_countdown, oy_s, oy_e, Tod.CURVE_LINEAR)
		var asc := Tod.animate_curve_float(100, 0, state_countdown, sc_s, sc_e, Tod.CURVE_LINEAR)
		ox += aox * sx
		oy += aoy * sy
		sx *= asc
		sy *= asc
		ox += App.zen_garden.zen_plant_offset_x(pp)
		oy += App.zen_garden.plant_potted_draw_height_offset(seed_type, sy)
	body.set_position(ox, oy)
	body.override_scale(sx, sy)

func update() -> void:
	var do_update := false
	if is_on_board and App.game_scene == PvZ.SCENE_LEVEL_INTRO and App.is_wallnut_bowling_level():
		do_update = true
	elif is_on_board and App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
		do_update = true
	elif is_on_board and board.cut_scene.should_run_upsell_board():
		do_update = true
	elif not is_on_board or App.game_scene == PvZ.SCENE_PLAYING:
		do_update = true
	if do_update:
		update_abilities()
		animate()
		if plant_health < 0:
			die()
		update_reanim()

func not_on_ground() -> bool:
	if seed_type == PvZ.SEED_SQUASH:
		if state == PvZ.STATE_SQUASH_RISING or state == PvZ.STATE_SQUASH_FALLING or state == PvZ.STATE_SQUASH_DONE_FALLING:
			return true
	return squished or on_bungee_state == PvZ.RISING_WITH_BUNGEE or dead

func attach_blink_anim(body: Reanimation) -> Reanimation:
	var rt: int = _def()[LawnCommon.PDEF_REANIM]
	var attach_to: Reanimation = body
	var track_to_play := "anim_blink"
	var track_to_attach := ""
	if seed_type in [PvZ.SEED_WALLNUT, PvZ.SEED_TALLNUT, PvZ.SEED_EXPLODE_O_NUT, PvZ.SEED_GIANT_WALLNUT]:
		var hit := Tod.rand_int(10)
		if hit < 1 and body.track_exists("anim_blink_twitch"):
			track_to_play = "anim_blink_twitch"
		else:
			track_to_play = "anim_blink_twice" if hit < 7 else "anim_blink_thrice"
	elif seed_type == PvZ.SEED_THREEPEATER:
		var hit := Tod.rand_int(3)
		var n := hit + 1
		track_to_play = "anim_blink%d" % n
		track_to_attach = "anim_face%d" % n
		attach_to = Attachment.find_reanim_attachment(body.get_track_instance("anim_head%d" % n))
	elif seed_type == PvZ.SEED_SPLITPEA:
		if Tod.rand_int(2) == 0:
			track_to_play = "anim_blink"
			track_to_attach = "anim_face"
			attach_to = rv(head_reanim)
		else:
			track_to_play = "anim_blink2"
			track_to_attach = "anim_face2"
			attach_to = rv(head_reanim2)
	elif seed_type == PvZ.SEED_TWINSUNFLOWER:
		if Tod.rand_int(2) == 0:
			track_to_play = "anim_blink"
			track_to_attach = "anim_face"
		else:
			track_to_play = "anim_blink2"
			track_to_attach = "anim_face2"
	elif seed_type in [PvZ.SEED_PEASHOOTER, PvZ.SEED_SNOWPEA, PvZ.SEED_REPEATER, PvZ.SEED_LEFTPEATER, PvZ.SEED_GATLINGPEA]:
		if body.track_exists("anim_stem"):
			attach_to = Attachment.find_reanim_attachment(body.get_track_instance("anim_stem"))
		elif body.track_exists("anim_idle"):
			attach_to = Attachment.find_reanim_attachment(body.get_track_instance("anim_idle"))
	if attach_to == null:
		return null
	if not body.track_exists(track_to_play):
		return null
	var blink := EffectSystem.alloc_reanimation(0.0, 0.0, 0, rt)
	blink.set_frames_for_layer(track_to_play)
	blink.loop_type = Reanimation.REANIM_PLAY_ONCE_FULL_LAST_FRAME_AND_HOLD
	blink.anim_rate = 15.0
	blink.color_override = body.color_override
	if track_to_attach != "" and attach_to.track_exists(track_to_attach):
		blink.attach_to_another_reanimation(attach_to, track_to_attach)
	elif attach_to.track_exists("anim_face"):
		blink.attach_to_another_reanimation(attach_to, "anim_face")
	elif attach_to.track_exists("anim_idle"):
		blink.attach_to_another_reanimation(attach_to, "anim_idle")
	blink.filter_effect = body.filter_effect
	return blink

func do_blink() -> void:
	blink_countdown = 400 + Tod.rand_int(400)
	if not_on_ground() or shooting_counter != 0:
		return
	if seed_type == PvZ.SEED_POTATOMINE and state != PvZ.STATE_POTATO_ARMED:
		return
	if state in [PvZ.STATE_CACTUS_RISING, PvZ.STATE_CACTUS_HIGH, PvZ.STATE_CACTUS_LOWERING, PvZ.STATE_MAGNETSHROOM_SUCKING, PvZ.STATE_MAGNETSHROOM_CHARGING]:
		return
	end_blink()
	var body := rv(body_reanim)
	if body == null:
		return
	if (seed_type == PvZ.SEED_TALLNUT and body.get_image_override("anim_idle") == Res.get_image("IMAGE_REANIM_TALLNUT_CRACKED2")) \
			or (seed_type == PvZ.SEED_GARLIC and body.get_image_override("anim_face") == Res.get_image("IMAGE_REANIM_GARLIC_BODY3")):
		return
	if seed_type in [PvZ.SEED_WALLNUT, PvZ.SEED_TALLNUT, PvZ.SEED_EXPLODE_O_NUT, PvZ.SEED_GIANT_WALLNUT]:
		blink_countdown = 1000 + Tod.rand_int(1000)
	var blink := attach_blink_anim(body)
	if blink:
		blink_reanim = blink
	body.assign_render_group_to_prefix("anim_eye", Reanimation.RENDER_GROUP_HIDDEN)

func end_blink() -> void:
	if blink_reanim != null:
		if rv(blink_reanim):
			blink_reanim.die()
		blink_reanim = null
		var body := rv(body_reanim)
		if body:
			body.assign_render_group_to_prefix("anim_eye", Reanimation.RENDER_GROUP_NORMAL)

func update_blink() -> void:
	if blink_reanim != null:
		var b := rv(blink_reanim)
		if b == null or b.loop_count > 0:
			end_blink()
	if is_asleep:
		return
	if blink_countdown > 0:
		blink_countdown -= 1
		if blink_countdown == 0:
			do_blink()

func animate_nuts() -> void:
	var body := rv(body_reanim)
	if body == null:
		return
	var cracked1: PvzImage
	var cracked2: PvzImage
	var track: String
	if seed_type == PvZ.SEED_WALLNUT:
		cracked1 = Res.get_image("IMAGE_REANIM_WALLNUT_CRACKED1")
		cracked2 = Res.get_image("IMAGE_REANIM_WALLNUT_CRACKED2")
		track = "anim_face"
	elif seed_type == PvZ.SEED_TALLNUT:
		cracked1 = Res.get_image("IMAGE_REANIM_TALLNUT_CRACKED1")
		cracked2 = Res.get_image("IMAGE_REANIM_TALLNUT_CRACKED2")
		track = "anim_idle"
	else:
		return
	var px := x + 40
	var py := y + 10
	if seed_type == PvZ.SEED_TALLNUT:
		py -= 32
	var ov := body.get_image_override(track)
	if plant_health < Tod.idiv(plant_max_health, 3):
		if ov != cracked2:
			body.set_image_override(track, cracked2)
			App.add_tod_particle(px, py, render_order + 4, PvZ.PARTICLE_WALLNUT_EAT_LARGE)
	elif plant_health < Tod.idiv(plant_max_health * 2, 3):
		if ov != cracked1:
			body.set_image_override(track, cracked1)
			App.add_tod_particle(px, py, render_order + 4, PvZ.PARTICLE_WALLNUT_EAT_LARGE)
	else:
		body.set_image_override(track, null)
	if is_in_play() and not App.is_izombie_level():
		if recently_eaten_countdown > 0:
			body.anim_rate = 0.1
			return
		if body.anim_rate < 1.0 and on_bungee_state != PvZ.RISING_WITH_BUNGEE:
			body.anim_rate = Tod.rand_range_float(10.0, 15.0)

func animate_garlic() -> void:
	var body := body_reanim
	var ov := body.get_image_override("anim_face")
	var b3 := Res.get_image("IMAGE_REANIM_GARLIC_BODY3")
	var b2 := Res.get_image("IMAGE_REANIM_GARLIC_BODY2")
	if plant_health < Tod.idiv(plant_max_health, 3):
		if ov != b3:
			body.set_image_override("anim_face", b3)
			body.assign_render_group_to_prefix("Garlic_stem", Reanimation.RENDER_GROUP_HIDDEN)
	elif plant_health < Tod.idiv(plant_max_health * 2, 3):
		if ov != b2:
			body.set_image_override("anim_face", b2)
	else:
		body.set_image_override("anim_face", null)

func animate_pumpkin() -> void:
	var body := body_reanim
	var ov := body.get_image_override("Pumpkin_front")
	var d3 := Res.get_image("IMAGE_REANIM_PUMPKIN_DAMAGE3")
	var d1 := Res.get_image("IMAGE_REANIM_PUMPKIN_DAMAGE1")
	if plant_health < Tod.idiv(plant_max_health, 3):
		if ov != d3:
			body.set_image_override("Pumpkin_front", d3)
	elif plant_health < Tod.idiv(plant_max_health * 2, 3):
		if ov != d1:
			body.set_image_override("Pumpkin_front", d1)
	else:
		body.set_image_override("Pumpkin_front", null)

func _return_head_to_idle(h: Reanimation, track: String, body: Reanimation) -> void:
	h.start_blend(20)
	h.loop_type = Reanimation.REANIM_LOOP
	h.set_frames_for_layer(track)
	h.anim_rate = body.anim_rate
	h.anim_time = body.anim_time

func update_shooting() -> void:
	if not_on_ground() or shooting_counter == 0:
		return
	shooting_counter -= 1
	if seed_type == PvZ.SEED_FUMESHROOM and shooting_counter == 15:
		add_attached_particle(x + 85, y + 31, BoardCore.make_render_order(PvZ.RENDER_LAYER_PARTICLE, row, 0), PvZ.PARTICLE_FUMECLOUD)
	if seed_type == PvZ.SEED_GLOOMSHROOM:
		if shooting_counter in [136, 108, 80, 52]:
			add_attached_particle(x + 40, y + 40, BoardCore.make_render_order(PvZ.RENDER_LAYER_PARTICLE, row, 0), PvZ.PARTICLE_GLOOMCLOUD)
		if shooting_counter in [126, 98, 70, 42]:
			fire(null, row, PvZ.WEAPON_PRIMARY)
	elif seed_type == PvZ.SEED_GATLINGPEA:
		if shooting_counter in [18, 35, 51, 68]:
			fire(null, row, PvZ.WEAPON_PRIMARY)
	elif seed_type == PvZ.SEED_CATTAIL:
		if shooting_counter == 19:
			var z := find_target_zombie(row, PvZ.WEAPON_PRIMARY)
			if z:
				fire(z, row, PvZ.WEAPON_PRIMARY)
	elif shooting_counter == 1:
		if seed_type == PvZ.SEED_THREEPEATER:
			if head_reanim.loop_type == Reanimation.REANIM_PLAY_ONCE_AND_HOLD:
				fire(null, row + 1, PvZ.WEAPON_PRIMARY)
			if head_reanim2.loop_type == Reanimation.REANIM_PLAY_ONCE_AND_HOLD:
				fire(null, row, PvZ.WEAPON_PRIMARY)
			if head_reanim3.loop_type == Reanimation.REANIM_PLAY_ONCE_AND_HOLD:
				fire(null, row - 1, PvZ.WEAPON_PRIMARY)
		elif seed_type == PvZ.SEED_SPLITPEA:
			if head_reanim.loop_type == Reanimation.REANIM_PLAY_ONCE_AND_HOLD and launch_counter <= 1:
				fire(null, row, PvZ.WEAPON_PRIMARY)
			if head_reanim2.loop_type == Reanimation.REANIM_PLAY_ONCE_AND_HOLD:
				fire(null, row, PvZ.WEAPON_SECONDARY)
		elif state == PvZ.STATE_CACTUS_LOW:
			fire(null, row, PvZ.WEAPON_SECONDARY)
		elif seed_type in [PvZ.SEED_CABBAGEPULT, PvZ.SEED_KERNELPULT, PvZ.SEED_MELONPULT, PvZ.SEED_WINTERMELON]:
			var weapon := PvZ.WEAPON_PRIMARY
			if state == PvZ.STATE_KERNELPULT_BUTTER:
				body_reanim.assign_render_group_to_prefix("Cornpult_butter", Reanimation.RENDER_GROUP_HIDDEN)
				body_reanim.assign_render_group_to_prefix("Cornpult_kernal", Reanimation.RENDER_GROUP_NORMAL)
				state = PvZ.STATE_NOTREADY
				weapon = PvZ.WEAPON_SECONDARY
			fire(find_target_zombie(row, weapon), row, weapon)
		else:
			fire(null, row, PvZ.WEAPON_PRIMARY)
		return
	if shooting_counter != 0:
		return
	var body := rv(body_reanim)
	var head := rv(head_reanim)
	if seed_type == PvZ.SEED_THREEPEATER:
		if head_reanim2.loop_count > 0:
			if head.loop_type == Reanimation.REANIM_PLAY_ONCE_AND_HOLD:
				_return_head_to_idle(head, "anim_head_idle1", body)
			_return_head_to_idle(head_reanim2, "anim_head_idle2", body)
			if head_reanim3.loop_type == Reanimation.REANIM_PLAY_ONCE_AND_HOLD:
				_return_head_to_idle(head_reanim3, "anim_head_idle3", body)
			return
	elif seed_type == PvZ.SEED_SPLITPEA:
		if head.loop_count > 0:
			_return_head_to_idle(head, "anim_head_idle", body)
		if head_reanim2.loop_count > 0:
			_return_head_to_idle(head_reanim2, "anim_splitpea_idle", body)
		return
	elif state == PvZ.STATE_CACTUS_HIGH:
		if body.loop_count > 0:
			play_body_reanim("anim_idlehigh", Reanimation.REANIM_LOOP, 20, 0.0)
			body.anim_rate = body.definition.fps
			return
	elif head:
		if head.loop_count > 0:
			_return_head_to_idle(head, "anim_head_idle", body)
			return
	elif seed_type == PvZ.SEED_COBCANNON:
		if body.loop_count > 0:
			state = PvZ.STATE_COBCANNON_ARMING
			state_countdown = 3000
			play_body_reanim("anim_unarmed_idle", Reanimation.REANIM_LOOP, 20, body.definition.fps)
			return
	elif body and body.loop_count > 0:
		play_idle_anim(body.definition.fps)
		return
	shooting_counter = 1

func animate() -> void:
	if (seed_type == PvZ.SEED_CHERRYBOMB or seed_type == PvZ.SEED_JALAPENO) and App.game_mode != PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
		shake_offset_x = Tod.rand_range_float(-1.0, 1.0)
		shake_offset_y = Tod.rand_range_float(-1.0, 1.0)
	if recently_eaten_countdown > 0:
		recently_eaten_countdown -= 1
	if eaten_flash_countdown > 0:
		eaten_flash_countdown -= 1
	if beghouled_flash_countdown > 0:
		beghouled_flash_countdown -= 1
	if squished:
		frame = 0
		return
	if seed_type == PvZ.SEED_WALLNUT or seed_type == PvZ.SEED_TALLNUT:
		animate_nuts()
	elif seed_type == PvZ.SEED_GARLIC:
		animate_garlic()
	elif seed_type == PvZ.SEED_PUMPKINSHELL:
		animate_pumpkin()
	update_blink()
	if anim_ping:
		if anim_counter < frame_length * num_frames - 1:
			anim_counter += 1
		else:
			anim_ping = false
			anim_counter -= frame_length
	elif anim_counter > 0:
		anim_counter -= 1
	else:
		anim_ping = true
		anim_counter += frame_length
	frame = Tod.idiv(anim_counter, frame_length)

static func plant_flower_pot_height_offset(st: int, pot_scale: float) -> float:
	var h := -5.0 * pot_scale
	var fix := 0.0
	match st:
		PvZ.SEED_CHOMPER, PvZ.SEED_PLANTERN:
			h -= 5.0
		PvZ.SEED_SCAREDYSHROOM:
			h += 5.0
			fix -= 8.0
		PvZ.SEED_SUNSHROOM, PvZ.SEED_PUFFSHROOM:
			fix -= 4.0
		PvZ.SEED_HYPNOSHROOM, PvZ.SEED_MAGNETSHROOM, PvZ.SEED_PEASHOOTER, PvZ.SEED_REPEATER, PvZ.SEED_LEFTPEATER, PvZ.SEED_SNOWPEA, \
		PvZ.SEED_THREEPEATER, PvZ.SEED_SUNFLOWER, PvZ.SEED_MARIGOLD, PvZ.SEED_CABBAGEPULT, PvZ.SEED_MELONPULT, PvZ.SEED_TANGLEKELP, \
		PvZ.SEED_BLOVER, PvZ.SEED_SPIKEWEED:
			fix -= 8.0
		PvZ.SEED_SEASHROOM, PvZ.SEED_POTATOMINE:
			fix -= 4.0
		PvZ.SEED_LILYPAD:
			fix -= 16.0
		PvZ.SEED_INSTANT_COFFEE:
			fix -= 20.0
	return h + (pot_scale * fix - fix)

static func plant_draw_height_offset(b: Board, plant: Plant, st: int, col: int, the_row: int) -> float:
	var h := 0.0
	var floating := false
	if is_flying(st):
		floating = false
	elif b == null:
		if is_aquatic(st):
			floating = true
	elif b.is_pool_square(col, the_row):
		floating = true
	if floating:
		var counter: int = b.main_counter if b else App.app_counter
		var phase := the_row * PI + col * 0.25 * PI
		var t := counter * 2.0 * PI / 200.0
		h += sin(phase + t) * 2.0
	if b and (plant == null or not plant.squished):
		var pot := b.get_flower_pot_at(col, the_row)
		if pot and not pot.squished and st != PvZ.SEED_FLOWERPOT:
			h += plant_flower_pot_height_offset(st, 1.0)
	match st:
		PvZ.SEED_FLOWERPOT: h += 26.0
		PvZ.SEED_LILYPAD: h += 25.0
		PvZ.SEED_STARFRUIT: h += 10.0
		PvZ.SEED_TANGLEKELP: h += 24.0
		PvZ.SEED_SEASHROOM: h += 28.0
		PvZ.SEED_INSTANT_COFFEE: h -= 20.0
		PvZ.SEED_CACTUS: return h
		PvZ.SEED_PUMPKINSHELL: h += 15.0
		PvZ.SEED_PUFFSHROOM: h += 5.0
		PvZ.SEED_SCAREDYSHROOM: h -= 14.0
		PvZ.SEED_GRAVEBUSTER: h -= 40.0
		PvZ.SEED_SPIKEWEED, PvZ.SEED_SPIKEROCK:
			if st == PvZ.SEED_SPIKEROCK:
				h += 6.0
			if b and b.get_flower_pot_at(col, the_row) and App.game_mode != PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
				h += 5.0
			elif b and b.stage_has_roof():
				h += 15.0
			elif b and b.is_pool_square(col, the_row):
				h += 0.0
			else:
				h += 15.0
	return h

func get_pea_head_offset() -> Vector2i:
	var body := rv(body_reanim)
	var idx := 0
	if body.track_exists("anim_stem"):
		idx = body.find_track_index("anim_stem")
	elif body.track_exists("anim_idle"):
		idx = body.find_track_index("anim_idle")
	var t := Reanimation.Transform.new()
	body.get_current_transform(idx, t)
	return Vector2i(int(t.tx), int(t.ty))

const _MAGNET_IMAGES := {
	PvZ.MAGNET_ITEM_PAIL_1: "IMAGE_REANIM_ZOMBIE_BUCKET1",
	PvZ.MAGNET_ITEM_PAIL_2: "IMAGE_REANIM_ZOMBIE_BUCKET2",
	PvZ.MAGNET_ITEM_PAIL_3: "IMAGE_REANIM_ZOMBIE_BUCKET3",
	PvZ.MAGNET_ITEM_FOOTBALL_HELMET_1: "IMAGE_REANIM_ZOMBIE_FOOTBALL_HELMET",
	PvZ.MAGNET_ITEM_FOOTBALL_HELMET_2: "IMAGE_REANIM_ZOMBIE_FOOTBALL_HELMET2",
	PvZ.MAGNET_ITEM_FOOTBALL_HELMET_3: "IMAGE_REANIM_ZOMBIE_FOOTBALL_HELMET3",
	PvZ.MAGNET_ITEM_DOOR_1: "IMAGE_REANIM_ZOMBIE_SCREENDOOR1",
	PvZ.MAGNET_ITEM_DOOR_2: "IMAGE_REANIM_ZOMBIE_SCREENDOOR2",
	PvZ.MAGNET_ITEM_DOOR_3: "IMAGE_REANIM_ZOMBIE_SCREENDOOR3",
	PvZ.MAGNET_ITEM_POGO_1: "IMAGE_ZOMBIEPOGO",
	PvZ.MAGNET_ITEM_POGO_2: "IMAGE_ZOMBIEPOGO",
	PvZ.MAGNET_ITEM_POGO_3: "IMAGE_ZOMBIEPOGO",
	PvZ.MAGNET_ITEM_LADDER_1: "IMAGE_REANIM_ZOMBIE_LADDER_1",
	PvZ.MAGNET_ITEM_LADDER_2: "IMAGE_REANIM_ZOMBIE_LADDER_1_DAMAGE1",
	PvZ.MAGNET_ITEM_LADDER_3: "IMAGE_REANIM_ZOMBIE_LADDER_1_DAMAGE2",
	PvZ.MAGNET_ITEM_LADDER_PLACED: "IMAGE_REANIM_ZOMBIE_LADDER_5",
	PvZ.MAGNET_ITEM_JACK_IN_THE_BOX: "IMAGE_REANIM_ZOMBIE_JACKBOX_BOX",
	PvZ.MAGNET_ITEM_PICK_AXE: "IMAGE_REANIM_ZOMBIE_DIGGER_PICKAXE",
	PvZ.MAGNET_ITEM_SILVER_COIN: "IMAGE_REANIM_COIN_SILVER_DOLLAR",
	PvZ.MAGNET_ITEM_GOLD_COIN: "IMAGE_REANIM_COIN_GOLD_DOLLAR",
	PvZ.MAGNET_ITEM_DIAMOND: "IMAGE_REANIM_DIAMOND",
}

func draw_magnet_items(g: Graphics) -> void:
	var oy := plant_draw_height_offset(board, self, seed_type, plant_col, row)
	for m in magnet_items:
		if m.item_type == PvZ.MAGNET_ITEM_NONE or not _MAGNET_IMAGES.has(m.item_type):
			continue
		var col := 0
		var sc := 0.8
		if m.item_type >= PvZ.MAGNET_ITEM_POGO_1 and m.item_type <= PvZ.MAGNET_ITEM_POGO_3:
			col = m.item_type - PvZ.MAGNET_ITEM_POGO_1
		if m.item_type in [PvZ.MAGNET_ITEM_SILVER_COIN, PvZ.MAGNET_ITEM_GOLD_COIN, PvZ.MAGNET_ITEM_DIAMOND]:
			sc = 1.0
		var img := Res.get_image(_MAGNET_IMAGES[m.item_type])
		if sc == 1.0:
			g.draw_image_cel_rc(img, m.pos_x - x, m.pos_y - y + oy, col, 0)
		else:
			g.tod_draw_image_cel_scaled_f(img, m.pos_x - x, m.pos_y - y + oy, col, 0, sc, sc)

func draw_shadow(g: Graphics, ox: float, oy: float) -> void:
	if seed_type in [PvZ.SEED_LILYPAD, PvZ.SEED_STARFRUIT, PvZ.SEED_TANGLEKELP, PvZ.SEED_SEASHROOM, PvZ.SEED_COBCANNON, PvZ.SEED_SPIKEWEED,
			PvZ.SEED_SPIKEROCK, PvZ.SEED_GRAVEBUSTER, PvZ.SEED_CATTAIL] or on_bungee_state == PvZ.RISING_WITH_BUNGEE:
		return
	if is_on_board and App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN and App.zen_garden.garden_type == PvZ.GARDEN_MAIN:
		return
	var sx := -3.0
	var sy := 51.0
	var sc := 1.0
	match seed_type:
		PvZ.SEED_SQUASH:
			if board:
				sy += board.grid_to_pixel_y(plant_col, row) - y
			sy += 5.0
		PvZ.SEED_PUFFSHROOM:
			sc = 0.5
			sy = 42.0
		PvZ.SEED_SUNSHROOM:
			sy = 42.0
			if state == PvZ.STATE_SUNSHROOM_SMALL:
				sc = 0.5
			elif state == PvZ.STATE_SUNSHROOM_GROWING:
				sc = 0.5 + 0.5 * body_reanim.anim_time
		PvZ.SEED_UMBRELLA:
			sc = 0.5
			sx = -7.0
			sy = 52.0
		PvZ.SEED_FUMESHROOM, PvZ.SEED_GLOOMSHROOM:
			sc = 1.3
			sy = 47.0
		PvZ.SEED_CABBAGEPULT, PvZ.SEED_MELONPULT, PvZ.SEED_WINTERMELON:
			sy = 47.0
		PvZ.SEED_KERNELPULT:
			sx = 0.0
			sy = 47.0
		PvZ.SEED_SCAREDYSHROOM:
			sx = -9.0
			sy = 55.0
		PvZ.SEED_CHOMPER:
			sx = -21.0
			sy = 57.0
		PvZ.SEED_FLOWERPOT:
			sx = -4.0
			sy = 46.0
		PvZ.SEED_TALLNUT:
			sy = 54.0
			sc = 1.3
		PvZ.SEED_PUMPKINSHELL:
			sy = 46.0
			sc = 1.4
		PvZ.SEED_CACTUS:
			sx = -8.0
			sy = 50.0
		PvZ.SEED_PLANTERN:
			sy = 57.0
		PvZ.SEED_INSTANT_COFFEE:
			sy = 71.0
		PvZ.SEED_GIANT_WALLNUT:
			sx = -33.0
			sy = 56.0
			sc = 1.7
	if is_flying(seed_type):
		sy += 10.0
		if board and (board.get_top_plant_at(plant_col, row, PvZ.TOPPLANT_ONLY_NORMAL_POSITION) or board.get_top_plant_at(plant_col, row, PvZ.TOPPLANT_ONLY_PUMPKIN)):
			return
	var img := Res.get_image("IMAGE_PLANTSHADOW2" if (board and board.stage_is_night()) else "IMAGE_PLANTSHADOW")
	g.tod_draw_image_cel_center_scaled_f(img, ox + sx, oy + sy, 0, sc, sc)

func draw(g: Graphics) -> void:
	var ox := 0.0
	var oy := plant_draw_height_offset(board, self, seed_type, plant_col, row)
	if is_flying(seed_type) and squished:
		oy += 30.0
	if squished:
		if seed_type == PvZ.SEED_FLOWERPOT:
			oy -= 15.0
		if seed_type == PvZ.SEED_INSTANT_COFFEE:
			oy -= 20.0
		g.set_scale(1.0, 0.25, 0.0, 0.0)
		draw_seed_type(g, seed_type, imitater_type, PvZ.VARIATION_NORMAL, ox, 60.0 + oy)
		g.set_scale(1.0, 1.0, 0.0, 0.0)
		return
	var draw_pumpkin_back := false
	var pumpkin: Plant = null
	if is_on_board:
		pumpkin = board.get_pumpkin_at(plant_col, row)
		if pumpkin:
			var inside := board.get_top_plant_at(plant_col, row, PvZ.TOPPLANT_ONLY_NORMAL_POSITION)
			if inside:
				if inside.render_order > pumpkin.render_order or inside.on_bungee_state == PvZ.GETTING_GRABBED_BY_BUNGEE:
					inside = null
			if inside == self:
				draw_pumpkin_back = true
			if inside == null and seed_type == PvZ.SEED_PUMPKINSHELL:
				draw_pumpkin_back = true
		elif seed_type == PvZ.SEED_PUMPKINSHELL:
			draw_pumpkin_back = true
			pumpkin = self
	elif seed_type == PvZ.SEED_PUMPKINSHELL:
		draw_pumpkin_back = true
		pumpkin = self
	draw_shadow(g, ox, oy)
	if is_flying(seed_type):
		var counter: int = board.main_counter if is_on_board else App.app_counter
		var t := (row * 97 + plant_col * 61 + counter) * 0.03
		oy += sin(t) * 2.0
	if draw_pumpkin_back:
		var pr := rv(pumpkin.body_reanim)
		if pr:
			var pg := g.copy()
			pg.trans_x += pumpkin.x - x
			pg.trans_y += pumpkin.y - y
			pr.draw_render_group(pg, 1)
	ox += shake_offset_x
	oy += shake_offset_y
	if body_reanim != null:
		var body := rv(body_reanim)
		if body:
			body.draw(g)
	if seed_type == PvZ.SEED_MAGNETSHROOM and not draw_magnet_items_on_top():
		draw_magnet_items(g)

static func draw_seed_type(g: Graphics, st: int, imit: int, variation: int, px: float, py: float) -> void:
	var sg := g.copy()
	var ox := 0.0
	var oy := 0.0
	var use := st
	var v := variation
	if st == PvZ.SEED_IMITATER and imit != PvZ.SEED_NONE:
		use = imit
		v = PvZ.VARIATION_IMITATER
		if imit in [PvZ.SEED_HYPNOSHROOM, PvZ.SEED_SQUASH, PvZ.SEED_POTATOMINE, PvZ.SEED_GARLIC, PvZ.SEED_LILYPAD]:
			v = PvZ.VARIATION_IMITATER_LESS
	elif variation == PvZ.VARIATION_NORMAL and st == PvZ.SEED_TANGLEKELP:
		v = PvZ.VARIATION_AQUARIUM
	if use == PvZ.SEED_LEFTPEATER:
		ox += sg.scale_x * 80.0
		sg.scale_x *= -1.0
	if use == NetVersus.SEED_GRAVE:
		NetVersus.draw_grave_seed(sg, px + ox, py + oy)
		return
	if use >= PvZ.SEED_ZOMBIE_NORMAL and use < PvZ.NUM_ZOMBIE_SEEDS:
		ReanimatorCache.draw_cached_zombie(sg, px + ox, py + oy, NetVersus.seed_zombie_type(use))
		return
	if use == PvZ.SEED_GIANT_WALLNUT:
		sg.scale_x *= 1.4
		sg.scale_y *= 1.4
		sg.tod_draw_image_scaled_f(Res.get_image("IMAGE_REANIM_WALLNUT_BODY"), px - 53.0, py - 56.0, sg.scale_x, sg.scale_y)
	elif LawnCommon.plant_def(use)[LawnCommon.PDEF_REANIM] >= 0:
		ReanimatorCache.draw_cached_plant(sg, px + ox, py + oy, use, v)

func mouse_down(mx: int, my: int, click_count: int) -> void:
	if click_count < 0:
		return
	if state == PvZ.STATE_COBCANNON_READY:
		board.clear_cursor()
		var co := board.cursor_object
		co.type = PvZ.SEED_NONE
		co.cursor_type = PvZ.CURSOR_TYPE_COBCANNON_TARGET
		co.seed_bank_index = -1
		co.coin = null
		co.cob_cannon_plant = self
		board.cob_cannon_cursor_delay_counter = 30
		board.cob_cannon_mouse_x = mx
		board.cob_cannon_mouse_y = my

func ice_zombies() -> void:
	for z in board.zombies.duplicate():
		if not z.dead:
			z.hit_ice_trap()
	board.ice_trap_counter = 300
	if pv(board.pool_sparkly_particle):
		board.pool_sparkly_particle.dont_update = false
	var boss := board.get_boss_zombie()
	if boss:
		boss.boss_destroy_fireball()

func burn_row(the_row: int) -> void:
	var range_flags := get_damage_range_flags(PvZ.WEAPON_PRIMARY)
	for z in board.zombies.duplicate():
		if z.dead:
			continue
		if (z.zombie_type == PvZ.ZOMBIE_BOSS or z.row == the_row) and z.effected_by_damage(range_flags):
			z.remove_cold_effects()
			z.apply_burn()
	for gi in board.grid_items:
		if not gi.dead and gi.grid_y == the_row and gi.grid_item_type == PvZ.GRIDITEM_LADDER:
			gi.grid_item_die()
	var boss := board.get_boss_zombie()
	if boss and boss.fireball_row == the_row:
		boss.boss_destroy_iceball_in_row(the_row)

func blow_away_fliers(_px: int, _the_row: int) -> void:
	for z in board.zombies:
		if not z.dead and not z.is_dead_or_dying() and z.is_flying():
			z.blowing_away = true
	App.play_sample("SOUND_BLOVER")
	board.fog_blown_count_down = 4000

func kill_all_plants_near_doom() -> void:
	for p in board.plants.duplicate():
		if not p.dead and p.row == row and p.plant_col == plant_col:
			p.die()

func do_special() -> void:
	var px := x + Tod.idiv(width, 2)
	var py := y + Tod.idiv(height, 2)
	var range_flags := get_damage_range_flags(PvZ.WEAPON_PRIMARY)
	match seed_type:
		PvZ.SEED_BLOVER:
			if state != PvZ.STATE_DOINGSPECIAL:
				state = PvZ.STATE_DOINGSPECIAL
				blow_away_fliers(x, row)
		PvZ.SEED_CHERRYBOMB:
			App.play_foley(PvZ.FOLEY_CHERRYBOMB)
			App.play_foley(PvZ.FOLEY_JUICY)
			if board.get_all_zombies_in_radius(row, px, py, 115, 1, range_flags) >= 10 and not App.playing_quickplay:
				App.get_achievement(PvZ.ACHIEVEMENT_EXPLODONATOR)
			board.kill_all_zombies_in_radius(row, px, py, 115, 1, true, range_flags)
			App.add_tod_particle(px, py, PvZ.RENDER_LAYER_TOP, PvZ.PARTICLE_POWIE)
			board.shake_board(3, -4)
			die()
		PvZ.SEED_DOOMSHROOM:
			App.play_sample("SOUND_DOOMSHROOM")
			board.kill_all_zombies_in_radius(row, px, py, 250, 3, true, range_flags)
			kill_all_plants_near_doom()
			App.add_tod_particle(px, py, PvZ.RENDER_LAYER_TOP, PvZ.PARTICLE_DOOM)
			board.add_a_crater(plant_col, row).grid_item_counter = 18000
			board.shake_board(3, -4)
			die()
		PvZ.SEED_JALAPENO:
			App.play_foley(PvZ.FOLEY_JALAPENO_IGNITE)
			App.play_foley(PvZ.FOLEY_JUICY)
			board.do_fwoosh(row)
			board.shake_board(3, -4)
			burn_row(row)
			board.ice_timer[row] = 20
			die()
		PvZ.SEED_UMBRELLA:
			if state != PvZ.STATE_UMBRELLA_TRIGGERED and state != PvZ.STATE_UMBRELLA_REFLECTING:
				state = PvZ.STATE_UMBRELLA_TRIGGERED
				state_countdown = 5
				play_body_reanim("anim_block", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 22.0)
		PvZ.SEED_ICESHROOM:
			App.play_foley(PvZ.FOLEY_FROZEN)
			ice_zombies()
			App.add_tod_particle(px, py, PvZ.RENDER_LAYER_TOP, PvZ.PARTICLE_ICE_TRAP)
			die()
		PvZ.SEED_POTATOMINE:
			px = x + Tod.idiv(width, 2) - 20
			py = y + Tod.idiv(height, 2)
			App.play_sample("SOUND_POTATO_MINE")
			board.kill_all_zombies_in_radius(row, px, py, 60, 0, false, range_flags)
			if not App.is_izombie_level() and not App.playing_quickplay:
				App.get_achievement(PvZ.ACHIEVEMENT_SPUDOW)
			App.add_tod_particle(px + 20.0, py, BoardCore.make_render_order(PvZ.RENDER_LAYER_PARTICLE, row, 0), PvZ.PARTICLE_POTATO_MINE)
			board.shake_board(3, -4)
			die()
		PvZ.SEED_INSTANT_COFFEE:
			var p := board.get_top_plant_at(plant_col, row, PvZ.TOPPLANT_ONLY_NORMAL_POSITION)
			if p and p.is_asleep:
				p.wake_up_counter = 100
			state = PvZ.STATE_DOINGSPECIAL
			play_body_reanim("anim_crumble", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 22.0)
			App.play_foley(PvZ.FOLEY_COFFEE)

func imitater_morph() -> void:
	die()
	var p := board.add_plant(plant_col, row, imitater_type, PvZ.SEED_IMITATER)
	var f := PvZ.FILTER_EFFECT_WASHED_OUT
	if imitater_type in [PvZ.SEED_HYPNOSHROOM, PvZ.SEED_SQUASH, PvZ.SEED_POTATOMINE, PvZ.SEED_GARLIC, PvZ.SEED_LILYPAD]:
		f = PvZ.FILTER_EFFECT_LESS_WASHED_OUT
	for r in [p.body_reanim, p.head_reanim, p.head_reanim2, p.head_reanim3]:
		if rv(r):
			r.filter_effect = f

func update_imitater() -> void:
	if state != PvZ.STATE_IMITATER_MORPHING:
		if state_countdown == 0:
			state = PvZ.STATE_IMITATER_MORPHING
			play_body_reanim("anim_explode", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 26.0)
	else:
		var body := body_reanim
		if body.should_trigger_timed_event(0.8):
			App.add_tod_particle(x + 40, y + 40, PvZ.RENDER_LAYER_TOP, PvZ.PARTICLE_IMITATER_MORPH)
		if body.loop_count > 0:
			imitater_morph()

func cob_cannon_fire(tx: int, ty: int) -> void:
	state = PvZ.STATE_COBCANNON_FIRING
	shooting_counter = 206
	play_body_reanim("anim_shooting", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 12.0)
	target_x = int(tx - 47.0)
	target_y = ty
	body_reanim.get_track_instance("CobCannon_Cob").track_color = Color.WHITE

func fire(target: Zombie, the_row: int, weapon: int) -> void:
	if seed_type == PvZ.SEED_FUMESHROOM:
		do_row_area_damage(20, 2)
		App.play_foley(PvZ.FOLEY_FUME)
		return
	if seed_type == PvZ.SEED_GLOOMSHROOM:
		do_row_area_damage(20, 2)
		return
	if seed_type == PvZ.SEED_STARFRUIT:
		star_fruit_fire()
		return
	var pt := PvZ.PROJECTILE_PEA
	match seed_type:
		PvZ.SEED_PEASHOOTER, PvZ.SEED_REPEATER, PvZ.SEED_THREEPEATER, PvZ.SEED_SPLITPEA, PvZ.SEED_GATLINGPEA, PvZ.SEED_LEFTPEATER:
			pt = PvZ.PROJECTILE_PEA
		PvZ.SEED_SNOWPEA: pt = PvZ.PROJECTILE_SNOWPEA
		PvZ.SEED_PUFFSHROOM, PvZ.SEED_SCAREDYSHROOM, PvZ.SEED_SEASHROOM: pt = PvZ.PROJECTILE_PUFF
		PvZ.SEED_CACTUS, PvZ.SEED_CATTAIL: pt = PvZ.PROJECTILE_SPIKE
		PvZ.SEED_CABBAGEPULT: pt = PvZ.PROJECTILE_CABBAGE
		PvZ.SEED_KERNELPULT: pt = PvZ.PROJECTILE_KERNEL
		PvZ.SEED_MELONPULT: pt = PvZ.PROJECTILE_MELON
		PvZ.SEED_WINTERMELON: pt = PvZ.PROJECTILE_WINTERMELON
		PvZ.SEED_COBCANNON: pt = PvZ.PROJECTILE_COBBIG
	if seed_type == PvZ.SEED_KERNELPULT and weapon == PvZ.WEAPON_SECONDARY:
		pt = PvZ.PROJECTILE_BUTTER
	App.play_foley(PvZ.FOLEY_THROW)
	if seed_type == PvZ.SEED_SNOWPEA or seed_type == PvZ.SEED_WINTERMELON:
		App.play_foley(PvZ.FOLEY_SNOW_PEA_SPARKLES)
	elif seed_type == PvZ.SEED_PUFFSHROOM or seed_type == PvZ.SEED_SCAREDYSHROOM or seed_type == PvZ.SEED_SEASHROOM:
		App.play_foley(PvZ.FOLEY_PUFF)
	var ox: int
	var oy: int
	match seed_type:
		PvZ.SEED_PUFFSHROOM: ox = x + 40; oy = y + 40
		PvZ.SEED_SEASHROOM: ox = x + 45; oy = y + 63
		PvZ.SEED_CABBAGEPULT: ox = x + 5; oy = y - 12
		PvZ.SEED_MELONPULT, PvZ.SEED_WINTERMELON: ox = x + 25; oy = y - 46
		PvZ.SEED_CATTAIL: ox = x + 20; oy = y - 3
		PvZ.SEED_KERNELPULT:
			if weapon == PvZ.WEAPON_PRIMARY:
				ox = x + 19; oy = y - 37
			else:
				ox = x + 12; oy = y - 56
		PvZ.SEED_PEASHOOTER, PvZ.SEED_SNOWPEA, PvZ.SEED_REPEATER:
			var h := get_pea_head_offset()
			ox = x + h.x + 24; oy = y + h.y - 33
		PvZ.SEED_LEFTPEATER:
			var h := get_pea_head_offset()
			ox = x + h.x - 30; oy = y + h.y - 33
		PvZ.SEED_GATLINGPEA:
			var h := get_pea_head_offset()
			ox = x + h.x + 34; oy = y + h.y - 33
		PvZ.SEED_SPLITPEA:
			var h := get_pea_head_offset()
			oy = y + h.y - 33
			ox = x + h.x - 64 if weapon == PvZ.WEAPON_SECONDARY else x + h.x + 24
		PvZ.SEED_THREEPEATER: ox = x + 45; oy = y + 10
		PvZ.SEED_SCAREDYSHROOM: ox = x + 29; oy = y + 21
		PvZ.SEED_CACTUS:
			if weapon == PvZ.WEAPON_PRIMARY:
				ox = x + 93; oy = y - 50
			else:
				ox = x + 70; oy = y + 23
		PvZ.SEED_COBCANNON: ox = x - 44; oy = y - 184
		_: ox = x + 10; oy = y + 5
	if board.get_flower_pot_at(plant_col, row):
		oy -= 5
	var mower_order := BoardCore.make_render_order(PvZ.RENDER_LAYER_LAWN_MOWER, row, 1)
	if seed_type == PvZ.SEED_SNOWPEA:
		App.add_tod_particle(ox + 8, oy + 13, mower_order, PvZ.PARTICLE_SNOWPEA_PUFF)
	elif seed_type == PvZ.SEED_PUFFSHROOM:
		App.add_tod_particle(ox + 18, oy + 13, mower_order, PvZ.PARTICLE_PUFFSHROOM_MUZZLE)
	elif seed_type == PvZ.SEED_SCAREDYSHROOM:
		App.add_tod_particle(ox + 27, oy + 13, mower_order, PvZ.PARTICLE_PUFFSHROOM_MUZZLE)
	var proj := board.add_projectile(ox, oy, render_order - 1, the_row, pt)
	proj.damage_range_flags = get_damage_range_flags(weapon)
	if seed_type in [PvZ.SEED_CABBAGEPULT, PvZ.SEED_KERNELPULT, PvZ.SEED_MELONPULT, PvZ.SEED_WINTERMELON]:
		var rx: float
		var ry: float
		if target:
			var zr: Rect2i = target.get_zombie_rect()
			rx = target.zombie_target_lead_x(50.0) - ox - 30.0
			ry = zr.position.y - oy
			if target.zombie_phase == PvZ.PHASE_DOLPHIN_RIDING:
				rx -= 60.0
			if target.zombie_type == PvZ.ZOMBIE_POGO and target.has_object:
				rx -= 60.0
			if target.zombie_phase == PvZ.PHASE_SNORKEL_WALKING_IN_POOL:
				rx -= 40.0
			if target.zombie_type == PvZ.ZOMBIE_BOSS:
				ry = board.grid_to_pixel_y(8, row) - oy
		else:
			rx = 700.0 - ox
			ry = 0.0
		if rx < 40.0:
			rx = 40.0
		proj.motion_type = PvZ.MOTION_LOBBED
		proj.vel_x = rx / 120.0
		proj.vel_y = 0.0
		proj.vel_z = ry / 120.0 - 7.0
		proj.acc_z = 0.115
	elif seed_type == PvZ.SEED_THREEPEATER:
		if the_row < row:
			proj.motion_type = PvZ.MOTION_THREEPEATER
			proj.vel_y = -3.0
			proj.shadow_y += 80.0
		elif the_row > row:
			proj.motion_type = PvZ.MOTION_THREEPEATER
			proj.vel_y = 3.0
			proj.shadow_y -= 80.0
	elif seed_type == PvZ.SEED_PUFFSHROOM or seed_type == PvZ.SEED_SEASHROOM:
		proj.motion_type = PvZ.MOTION_PUFF
	elif seed_type == PvZ.SEED_SPLITPEA and weapon == PvZ.WEAPON_SECONDARY:
		proj.motion_type = PvZ.MOTION_BACKWARDS
	elif seed_type == PvZ.SEED_LEFTPEATER:
		proj.motion_type = PvZ.MOTION_BACKWARDS
	elif seed_type == PvZ.SEED_CATTAIL:
		proj.vel_x = 2.0
		proj.motion_type = PvZ.MOTION_HOMING
		proj.target_zombie = target
	elif seed_type == PvZ.SEED_COBCANNON:
		proj.vel_x = 0.001
		proj.damage_range_flags = get_damage_range_flags(PvZ.WEAPON_PRIMARY)
		proj.motion_type = PvZ.MOTION_LOBBED
		proj.vel_y = 0.0
		proj.acc_z = 0.0
		proj.vel_z = -8.0
		proj.cob_target_x = target_x - 40
		proj.cob_target_row = board.pixel_to_grid_y_keep_on_board(target_x, target_y)

func find_target_zombie(the_row: int, weapon: int = PvZ.WEAPON_PRIMARY) -> Zombie:
	var range_flags := get_damage_range_flags(weapon)
	var attack := get_plant_attack_rect(weapon)
	var highest := 0
	var best: Zombie = null
	for z in board.zombies:
		if z.dead:
			continue
		var dev: int = z.row - the_row
		if z.zombie_type == PvZ.ZOMBIE_BOSS:
			dev = 0
		if not z.has_head or z.is_tangle_kelp_target():
			if seed_type == PvZ.SEED_POTATOMINE or seed_type == PvZ.SEED_CHOMPER or seed_type == PvZ.SEED_TANGLEKELP:
				continue
		if seed_type != PvZ.SEED_CATTAIL:
			if seed_type == PvZ.SEED_GLOOMSHROOM:
				if dev < -1 or dev > 1:
					continue
			elif dev != 0:
				continue
		if not z.effected_by_damage(range_flags):
			continue
		var extra := 0
		if seed_type == PvZ.SEED_CHOMPER:
			if z.zombie_phase == PvZ.PHASE_DIGGER_WALKING:
				attack.position.x += 20
				attack.size.x -= 20
			if z.zombie_phase == PvZ.PHASE_POGO_BOUNCING or (z.zombie_type == PvZ.ZOMBIE_BUNGEE and z.target_col == plant_col):
				continue
			if z.is_eating or state == PvZ.STATE_CHOMPER_BITING:
				extra = 60
		if seed_type == PvZ.SEED_POTATOMINE:
			if (z.zombie_type == PvZ.ZOMBIE_POGO and z.has_object) or z.zombie_phase == PvZ.PHASE_POLEVAULTER_IN_VAULT or z.zombie_phase == PvZ.PHASE_POLEVAULTER_PRE_VAULT:
				continue
			if z.zombie_type == PvZ.ZOMBIE_POLEVAULTER:
				attack.position.x += 40
				attack.size.x -= 40
			if z.zombie_type == PvZ.ZOMBIE_BUNGEE and z.target_col != plant_col:
				continue
			if z.is_eating:
				extra = 30
		if (seed_type == PvZ.SEED_EXPLODE_O_NUT and z.zombie_phase == PvZ.PHASE_POLEVAULTER_IN_VAULT) or (seed_type == PvZ.SEED_TANGLEKELP and not z.in_pool):
			continue
		var zr: Rect2i = z.get_zombie_rect()
		if LawnCommon.get_rect_overlap(attack, zr) < -extra:
			continue
		var weight := -zr.position.x
		if seed_type == PvZ.SEED_CATTAIL:
			weight = -int(Tod.distance_2d(x + 40.0, y + 40.0, zr.position.x + Tod.idiv(zr.size.x, 2), zr.position.y + Tod.idiv(zr.size.y, 2)))
			if z.is_flying():
				weight += 10000
		if best == null or weight > highest:
			highest = weight
			best = z
	return best

func distance_to_closest_zombie() -> int:
	var range_flags := get_damage_range_flags(PvZ.WEAPON_PRIMARY)
	var attack := get_plant_attack_rect(PvZ.WEAPON_PRIMARY)
	var closest := 1000
	for z in board.zombies:
		if not z.dead and z.row == row and z.effected_by_damage(range_flags):
			var d := -LawnCommon.get_rect_overlap(attack, z.get_zombie_rect())
			if d < closest:
				closest = maxi(d, 0)
	return closest

func die() -> void:
	if is_on_board and seed_type == PvZ.SEED_TANGLEKELP:
		var z: Zombie = BoardCore.try_get(target_zombie)
		if z:
			z.die_with_loot()
	dead = true
	remove_effects()
	if not is_flying(seed_type) and is_on_board:
		var ladder := board.get_ladder_at(plant_col, row)
		if ladder:
			ladder.grid_item_die()
	if is_on_board:
		var top := board.get_top_plant_at(plant_col, row, PvZ.TOPPLANT_BUNGEE_ORDER)
		var pot := board.get_flower_pot_at(plant_col, row)
		if pot and top == pot and rv(pot.body_reanim):
			pot.body_reanim.anim_rate = Tod.rand_range_float(10.0, 15.0)

static func get_cost(st: int, imit: int = PvZ.SEED_NONE) -> int:
	match st:
		PvZ.SEED_SLOT_MACHINE_SUN, PvZ.SEED_SLOT_MACHINE_DIAMOND: return 0
		PvZ.SEED_ZOMBIQUARIUM_SNORKLE: return 100
		PvZ.SEED_ZOMBIQUARIUM_TROPHY: return 1000
		PvZ.SEED_ZOMBIE_NORMAL: return 50
		PvZ.SEED_ZOMBIE_TRAFFIC_CONE: return 75
		PvZ.SEED_ZOMBIE_POLEVAULTER: return 75
		PvZ.SEED_ZOMBIE_PAIL: return 125
		PvZ.SEED_ZOMBIE_LADDER: return 150
		PvZ.SEED_ZOMBIE_DIGGER: return 125
		PvZ.SEED_ZOMBIE_BUNGEE: return 125
		PvZ.SEED_ZOMBIE_FOOTBALL: return 175
		PvZ.SEED_ZOMBIE_BALLOON: return 150
		PvZ.SEED_ZOMBIE_SCREEN_DOOR: return 100
		PvZ.SEED_ZOMBONI: return 175
		PvZ.SEED_ZOMBIE_POGO: return 200
		PvZ.SEED_ZOMBIE_DANCER: return 350
		PvZ.SEED_ZOMBIE_GARGANTUAR: return 300
		PvZ.SEED_ZOMBIE_IMP: return 50
		NetVersus.SEED_GRAVE: return NetVersus.cost(st)
	if st == PvZ.SEED_IMITATER and imit != PvZ.SEED_NONE:
		return LawnCommon.plant_def(imit)[LawnCommon.PDEF_COST]
	return LawnCommon.plant_def(st)[LawnCommon.PDEF_COST]

static func get_name_string(st: int, imit: int = PvZ.SEED_NONE) -> String:
	if NetVersus.is_zombie_side_seed(st):
		return NetVersus.seed_name(st)
	var name := TodStrings.translate("[%s]" % LawnCommon.plant_def(st)[LawnCommon.PDEF_NAME])
	if st == PvZ.SEED_IMITATER and imit != PvZ.SEED_NONE:
		return "%s %s" % [name, TodStrings.translate("[%s]" % LawnCommon.plant_def(imit)[LawnCommon.PDEF_NAME])]
	return name

static func get_tool_tip(st: int) -> String:
	return TodStrings.translate("[%s_TOOLTIP]" % LawnCommon.plant_def(st)[LawnCommon.PDEF_NAME])

static func get_refresh_time(st: int, imit: int = PvZ.SEED_NONE) -> int:
	if NetVersus.is_zombie_side_seed(st):
		return NetVersus.refresh_time(st) if App.board and App.board.is_versus() else 0
	if st == PvZ.SEED_IMITATER and imit != PvZ.SEED_NONE:
		return LawnCommon.plant_def(imit)[LawnCommon.PDEF_REFRESH]
	return LawnCommon.plant_def(st)[LawnCommon.PDEF_REFRESH]

static func is_nocturnal(st: int) -> bool:
	return st in [PvZ.SEED_PUFFSHROOM, PvZ.SEED_SEASHROOM, PvZ.SEED_SUNSHROOM, PvZ.SEED_FUMESHROOM, PvZ.SEED_HYPNOSHROOM,
		PvZ.SEED_DOOMSHROOM, PvZ.SEED_ICESHROOM, PvZ.SEED_MAGNETSHROOM, PvZ.SEED_SCAREDYSHROOM, PvZ.SEED_GLOOMSHROOM]

static func is_aquatic(st: int) -> bool:
	return st == PvZ.SEED_LILYPAD or st == PvZ.SEED_TANGLEKELP or st == PvZ.SEED_SEASHROOM or st == PvZ.SEED_CATTAIL

static func is_flying(st: int) -> bool:
	return st == PvZ.SEED_INSTANT_COFFEE

static func is_upgrade(st: int) -> bool:
	return st in [PvZ.SEED_GATLINGPEA, PvZ.SEED_WINTERMELON, PvZ.SEED_TWINSUNFLOWER, PvZ.SEED_SPIKEROCK, PvZ.SEED_COBCANNON,
		PvZ.SEED_GOLD_MAGNET, PvZ.SEED_GLOOMSHROOM, PvZ.SEED_CATTAIL]

func get_plant_rect() -> Rect2i:
	match seed_type:
		PvZ.SEED_TALLNUT: return Rect2i(x + 10, y, width, height)
		PvZ.SEED_PUMPKINSHELL: return Rect2i(x, y, width - 20, height)
		PvZ.SEED_COBCANNON: return Rect2i(x, y, 140, 80)
	return Rect2i(x + 10, y, width - 20, height)

func get_plant_attack_rect(weapon: int = PvZ.WEAPON_PRIMARY) -> Rect2i:
	if App.is_wallnut_bowling_level():
		return Rect2i(x, y, width - 20, height)
	if weapon == PvZ.WEAPON_SECONDARY and seed_type == PvZ.SEED_SPLITPEA:
		return Rect2i(0, y, x + 16, height)
	match seed_type:
		PvZ.SEED_LEFTPEATER: return Rect2i(0, y, x, height)
		PvZ.SEED_SQUASH: return Rect2i(x + 20, y, width - 35, height)
		PvZ.SEED_CHOMPER: return Rect2i(x + 80, y, 40, height)
		PvZ.SEED_SPIKEWEED, PvZ.SEED_SPIKEROCK: return Rect2i(x + 20, y, width - 50, height)
		PvZ.SEED_POTATOMINE: return Rect2i(x, y, width - 25, height)
		PvZ.SEED_TORCHWOOD: return Rect2i(x + 50, y, 30, height)
		PvZ.SEED_PUFFSHROOM, PvZ.SEED_SEASHROOM: return Rect2i(x + 60, y, 230, height)
		PvZ.SEED_FUMESHROOM: return Rect2i(x + 60, y, 340, height)
		PvZ.SEED_GLOOMSHROOM: return Rect2i(x - 80, y - 80, 240, 240)
		PvZ.SEED_TANGLEKELP: return Rect2i(x, y, width, height)
		PvZ.SEED_CATTAIL: return Rect2i(-PvZ.BOARD_WIDTH, -PvZ.BOARD_HEIGHT, PvZ.BOARD_WIDTH * 2, PvZ.BOARD_HEIGHT * 2)
	return Rect2i(x + 60, y, PvZ.BOARD_WIDTH, height)

func play_idle_anim(rate: float) -> void:
	if rv(body_reanim):
		play_body_reanim("anim_idle", Reanimation.REANIM_LOOP, 20, rate)
