class_name Coin
extends GameObject
## Port of Coin: sun, money, level awards, presents, usable seed packets.

var pos_x := 0.0
var pos_y := 0.0
var vel_x := 0.0
var vel_y := 0.0
var scale := 1.0
var fade_count := 0
var collect_x := 0.0
var collect_y := 0.0
var ground_y := 0
var coin_age := 0
var is_being_collected := false
var disappear_counter := 0
var type := PvZ.COIN_NONE
var coin_motion := PvZ.COIN_MOTION_FROM_SKY
var collection_distance := 0.0
var usable_seed_type := PvZ.SEED_NONE
var potted_plant_spec := PlayerInfo.PottedPlant.new()
var needs_bouncy_arrow := false
var has_bouncy_arrow := false
var hit_ground := false
var times_dropped := 0
## The board this coin belongs to (null for coins created outside a level).
## Online Versus: purple sun that only the zombie team can collect.
var vs_zombie_sun := false
## Online auto-collect already queued a click for this coin.
var net_click_sent := false
var sun_reanim: Reanimation = null
var board: Board = null
var is_on_board: bool:
	get: return board != null

const _SEED_LIST_DAY := [PvZ.SEED_PEASHOOTER, PvZ.SEED_SUNFLOWER, PvZ.SEED_CHERRYBOMB, PvZ.SEED_WALLNUT, PvZ.SEED_REPEATER, PvZ.SEED_POTATOMINE, PvZ.SEED_SNOWPEA, PvZ.SEED_CHOMPER]
const _SEED_LIST_NIGHT := [PvZ.SEED_PUFFSHROOM, PvZ.SEED_SUNSHROOM, PvZ.SEED_FUMESHROOM, PvZ.SEED_GRAVEBUSTER, PvZ.SEED_HYPNOSHROOM, PvZ.SEED_SCAREDYSHROOM, PvZ.SEED_ICESHROOM, PvZ.SEED_DOOMSHROOM]
const _SEED_LIST_POOL := [PvZ.SEED_LILYPAD, PvZ.SEED_SQUASH, PvZ.SEED_THREEPEATER, PvZ.SEED_TANGLEKELP, PvZ.SEED_JALAPENO, PvZ.SEED_SPIKEWEED, PvZ.SEED_TORCHWOOD, PvZ.SEED_TALLNUT]
const _SEED_LIST_FOG := [PvZ.SEED_SEASHROOM, PvZ.SEED_PLANTERN, PvZ.SEED_CACTUS, PvZ.SEED_BLOVER, PvZ.SEED_SPLITPEA, PvZ.SEED_STARFRUIT, PvZ.SEED_PUMPKINSHELL, PvZ.SEED_MAGNETSHROOM]
const _SEED_LIST_ROOF := [PvZ.SEED_CABBAGEPULT, PvZ.SEED_KERNELPULT, PvZ.SEED_INSTANT_COFFEE, PvZ.SEED_GARLIC, PvZ.SEED_UMBRELLA, PvZ.SEED_MELONPULT]

func _init() -> void:
	board = App.board

func _above_ui() -> int:
	return BoardCore.make_render_order(PvZ.RENDER_LAYER_ABOVE_UI, 0, 0)

func _add_coin_reanim(rt: int, ox: float, oy: float) -> Reanimation:
	var r := App.add_reanimation(0.0, 0.0, 0, rt)
	r.set_position(pos_x + ox, pos_y + oy)
	r.loop_type = Reanimation.REANIM_LOOP
	Attachment.attach_reanim(self, r, ox, oy)
	return r

func coin_initialize(px: int, py: int, coin_type: int, motion: int) -> void:
	pos_x = px
	pos_y = py
	type = coin_type
	collection_distance = 0.0
	dead = false
	width = 60
	height = 60
	disappear_counter = 0
	is_being_collected = false
	fade_count = 0
	coin_motion = motion
	coin_age = 0
	render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_COIN_BANK, 0, 1)
	scale = 1.0
	usable_seed_type = PvZ.SEED_NONE
	needs_bouncy_arrow = false
	has_bouncy_arrow = false
	hit_ground = false
	times_dropped = 0
	potted_plant_spec.initialize_potted_plant(PvZ.SEED_NONE)
	if is_sun():
		var r := _add_coin_reanim(PvZ.REANIM_SUN, width * 0.5, height * 0.5)
		r.anim_rate = 6.0
		sun_reanim = r
	elif type == PvZ.COIN_SILVER or type == PvZ.COIN_GOLD:
		pos_x -= 10.0
		pos_y -= 8.0
		var r := _add_coin_reanim(PvZ.REANIM_COIN_SILVER if type == PvZ.COIN_SILVER else PvZ.REANIM_COIN_GOLD, 9.0, 9.0)
		r.anim_time = Tod.rand_range_float(0.0, 0.99)
		r.anim_rate *= Tod.rand_range_float(0.6, 1.0)
	elif type == PvZ.COIN_DIAMOND:
		pos_x -= 15.0
		pos_y -= 15.0
		var r := _add_coin_reanim(PvZ.REANIM_DIAMOND, -3.0, 4.0)
		r.anim_time = Tod.rand_range_float(0.0, 0.99)
		r.anim_rate = Tod.rand_range_float(50.0, 80.0)
	if App.is_stormy_night_level():
		render_order = _above_ui()
	var size_image := ""
	match type:
		PvZ.COIN_FINAL_SEED_PACKET: size_image = "IMAGE_SEEDS"
		PvZ.COIN_TROPHY: size_image = "IMAGE_TROPHY"
		PvZ.COIN_AWARD_SILVER_SUNFLOWER, PvZ.COIN_AWARD_GOLD_SUNFLOWER: size_image = "IMAGE_SUNFLOWER_TROPHY"
		PvZ.COIN_SHOVEL: size_image = "IMAGE_SHOVEL"
		PvZ.COIN_CARKEYS: size_image = "IMAGE_CARKEYS"
		PvZ.COIN_ALMANAC: size_image = "IMAGE_ALMANAC"
		PvZ.COIN_VASE: size_image = "IMAGE_SCARY_POT"
		PvZ.COIN_WATERING_CAN: size_image = "IMAGE_WATERINGCAN"
		PvZ.COIN_TACO: size_image = "IMAGE_TACO"
		PvZ.COIN_NOTE: size_image = "IMAGE_ZOMBIE_NOTE_SMALL"
		PvZ.COIN_AWARD_MONEY_BAG, PvZ.COIN_AWARD_BAG_DIAMOND: size_image = "IMAGE_MONEYBAG"
		PvZ.COIN_CHOCOLATE, PvZ.COIN_AWARD_CHOCOLATE: size_image = "IMAGE_CHOCOLATE"
	if size_image != "":
		var img := Res.get_image(size_image)
		width = img.get_cel_width()
		height = img.get_cel_height()
		render_order = _above_ui()
	elif type == PvZ.COIN_USABLE_SEED_PACKET:
		var img := Res.get_image("IMAGE_SEEDS")
		width = img.get_cel_width()
		height = img.get_cel_height()
		render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_FOG, 0, 2)
	elif type == PvZ.COIN_PRESENT_PLANT or type == PvZ.COIN_AWARD_PRESENT:
		var img := Res.get_image("IMAGE_PRESENT")
		width = img.get_cel_width()
		height = img.get_cel_height()
		var seed_type: int
		match board.background:
			PvZ.BACKGROUND_1_DAY: seed_type = Tod.pick_from_array(_SEED_LIST_DAY)
			PvZ.BACKGROUND_2_NIGHT: seed_type = Tod.pick_from_array(_SEED_LIST_NIGHT)
			PvZ.BACKGROUND_3_POOL: seed_type = Tod.pick_from_array(_SEED_LIST_POOL)
			PvZ.BACKGROUND_4_FOG: seed_type = Tod.pick_from_array(_SEED_LIST_FOG)
			PvZ.BACKGROUND_5_ROOF: seed_type = Tod.pick_from_array(_SEED_LIST_ROOF)
			_: seed_type = App.zen_garden.pick_random_seed_type()
		potted_plant_spec.initialize_potted_plant(seed_type)
	elif is_present_with_advice():
		var img := Res.get_image("IMAGE_PRESENT")
		width = img.get_cel_width()
		height = img.get_cel_height()
		render_order = _above_ui()
	match coin_motion:
		PvZ.COIN_MOTION_FROM_SKY:
			vel_y = 0.67
			vel_x = 0.0
			ground_y = Tod.rand_int(250) + 300
		PvZ.COIN_MOTION_FROM_SKY_SLOW:
			vel_y = 0.33
			vel_x = 0.0
			ground_y = Tod.rand_int(250) + 300
		PvZ.COIN_MOTION_FROM_PLANT:
			vel_y = -1.7 - Tod.rand_range_float(0.0, 1.7)
			vel_x = -0.4 + Tod.rand_range_float(0.0, 0.8)
			ground_y = int(pos_y) + 15 + Tod.rand_int(20)
			scale = 0.4
		PvZ.COIN_MOTION_COIN:
			vel_y = -3.0 - Tod.rand_range_float(0.0, 2.0)
			vel_x = -0.5 + Tod.rand_range_float(0.0, 1.0)
			ground_y = clampi(int(pos_y) + 45 + Tod.rand_int(20), 80, 521)
			if type == PvZ.COIN_AWARD_SILVER_SUNFLOWER or type == PvZ.COIN_AWARD_GOLD_SUNFLOWER:
				pos_y -= 100.0
				ground_y = mini(int(pos_y + 45.0), 400)
			if type in [PvZ.COIN_FINAL_SEED_PACKET, PvZ.COIN_USABLE_SEED_PACKET, PvZ.COIN_TROPHY, PvZ.COIN_SHOVEL, PvZ.COIN_CARKEYS,
					PvZ.COIN_ALMANAC, PvZ.COIN_VASE, PvZ.COIN_WATERING_CAN, PvZ.COIN_TACO, PvZ.COIN_NOTE]:
				ground_y -= 30
		PvZ.COIN_MOTION_LAWNMOWER_COIN:
			vel_y = 0.0
			vel_x = 0.0
			ground_y = 600
			collect()
		PvZ.COIN_MOTION_FROM_PRESENT:
			vel_y = 0.0
			vel_x = 0.0
			ground_y = 600
			render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_ABOVE_UI, 0, 1)
		PvZ.COIN_MOTION_FROM_BOSS:
			vel_y = -5.0
			vel_x = -3.0
			pos_x = 750.0
			pos_y = 130.0 if type == PvZ.COIN_AWARD_SILVER_SUNFLOWER else 245.0
			ground_y = int(pos_y) + 40
	scale *= get_sun_scale()
	if coin_gets_bouncy_arrow():
		needs_bouncy_arrow = true
	if coin_motion != PvZ.COIN_MOTION_FROM_PRESENT:
		play_launch_sound()

static func is_money_type(t: int) -> bool:
	return t == PvZ.COIN_SILVER or t == PvZ.COIN_GOLD or t == PvZ.COIN_DIAMOND

func is_money() -> bool:
	return is_money_type(type)

func is_sun() -> bool:
	return type == PvZ.COIN_SUN or type == PvZ.COIN_SMALLSUN or type == PvZ.COIN_LARGESUN

func is_present_with_advice() -> bool:
	return type == PvZ.COIN_PRESENT_MINIGAMES or type == PvZ.COIN_PRESENT_PUZZLE_MODE or type == PvZ.COIN_PRESENT_SURVIVAL_MODE

func make_zombie_sun() -> void:
	vs_zombie_sun = true
	if sun_reanim != null and not sun_reanim.freed:
		sun_reanim.filter_effect = NetVersus.FILTER_EFFECT_ZOMBIE_SUN

func score_coin() -> void:
	die()
	if is_sun() and board and vs_zombie_sun != board.net_zombie_context:
		board.vs_zombie_sun = mini(board.vs_zombie_sun + get_sun_value(), 9990)
	elif is_sun():
		board.add_sun_money(get_sun_value())
		if CustomRuntime.active != null:
			CustomRuntime.active.notify_sun_collected(get_sun_value())
	elif is_money():
		var v := get_coin_value(type)
		App.player_info.add_coins(v)
		if board:
			board.coins_collected += v
			board.achievement_coin_count += 1
			if board.achievement_coin_count >= 30 and not board.coin_faded and not App.playing_quickplay:
				App.get_achievement(PvZ.ACHIEVEMENT_PENNY_PINCHER)
	if type == PvZ.COIN_DIAMOND and board:
		board.diamonds_collected += 1

func start_fade() -> void:
	fade_count = 15

func update_fade() -> void:
	if type == PvZ.COIN_NOTE or not is_level_award():
		fade_count -= 1
		if fade_count == 0:
			board.coin_faded = true
			die()

func update_fall() -> void:
	if coin_motion == PvZ.COIN_MOTION_FROM_PRESENT:
		pos_x += vel_x
		pos_y += vel_y
		vel_x *= 0.95
		vel_y *= 0.95
		if coin_age >= 80:
			collect()
	elif pos_y + vel_y < ground_y:
		pos_y += vel_y
		if coin_motion == PvZ.COIN_MOTION_FROM_PLANT:
			vel_y += 0.09
		elif coin_motion == PvZ.COIN_MOTION_COIN or coin_motion == PvZ.COIN_MOTION_FROM_BOSS:
			vel_y += 0.15
		pos_x += vel_x
		if pos_x > PvZ.BOARD_WIDTH - width and coin_motion != PvZ.COIN_MOTION_FROM_BOSS:
			pos_x = PvZ.BOARD_WIDTH - width
			vel_x = -0.4 - Tod.rand_range_float(0.0, 0.4)
		elif pos_x < 0.0:
			pos_x = 0.0
			vel_x = 0.4 + Tod.rand_range_float(0.0, 0.4)
	else:
		if needs_bouncy_arrow and not has_bouncy_arrow:
			var pox := float(Tod.idiv(width, 2))
			var poy := float(Tod.idiv(height, 2) - 60)
			if type == PvZ.COIN_TROPHY:
				pox += 2.0
			elif type == PvZ.COIN_AWARD_MONEY_BAG or type == PvZ.COIN_AWARD_BAG_DIAMOND:
				pox += 2.0
				poy -= 2.0
			elif type == PvZ.COIN_AWARD_PRESENT or is_present_with_advice():
				poy -= 20.0
			elif type == PvZ.COIN_AWARD_SILVER_SUNFLOWER or type == PvZ.COIN_AWARD_GOLD_SUNFLOWER:
				pox -= 6.0
				poy -= 40.0
			elif is_money():
				pox += 12.0
				poy += 21.0
			var effect: int
			if type == PvZ.COIN_FINAL_SEED_PACKET:
				effect = PvZ.PARTICLE_SEED_PACKET
			elif is_money():
				effect = PvZ.PARTICLE_COIN_PICKUP_ARROW
			else:
				effect = PvZ.PARTICLE_AWARD_PICKUP_ARROW
			var ps := App.add_tod_particle(pos_x + pox, pos_y + poy, 0, effect)
			Attachment.attach_particle(self, ps, pox, poy)
			has_bouncy_arrow = true
		if not hit_ground:
			hit_ground = true
			play_ground_sound()
		pos_y = ground_y
		pos_x = Tod.round_to_int(pos_x)
		if not is_level_award() and not is_present_with_advice():
			disappear_counter += 1
			if disappear_counter >= get_disappear_time():
				start_fade()
	if coin_motion == PvZ.COIN_MOTION_FROM_PLANT:
		var final_scale := get_sun_scale()
		if scale < final_scale:
			scale += 0.02
		else:
			scale = final_scale

func update_collected() -> void:
	var dest_x: int
	var dest_y: int
	if is_sun():
		dest_x = board.seed_bank.x + 5
		dest_y = maxi(0, board.seed_bank.y)
	elif is_money():
		if App.get_dialog(PvZ.DIALOG_STORE):
			dest_x = PvZ.STORESCREEN_COINBANK_X + 12
			dest_y = PvZ.STORESCREEN_COINBANK_Y - 10
		else:
			var money_x := -2 if (App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN or App.crazy_dave_state != PvZ.CRAZY_DAVE_OFF) else -18
			dest_x = board.coin_bank_x + money_x
			dest_y = board.coin_bank_y - 10
	elif is_present_with_advice():
		dest_x = 35 + PvZ.BOARD_ADDITIONAL_WIDTH
		dest_y = PvZ.BOARD_HEIGHT - 113
	elif type == PvZ.COIN_AWARD_PRESENT or type == PvZ.COIN_PRESENT_PLANT:
		disappear_counter += 1
		if disappear_counter >= 200:
			start_fade()
		return
	elif not is_level_award():
		if type == PvZ.COIN_USABLE_SEED_PACKET:
			disappear_counter += 1
		return
	else:
		dest_x = 400 - Tod.idiv(width, 2) + PvZ.BOARD_ADDITIONAL_WIDTH
		dest_y = 200 - Tod.idiv(height, 2) + PvZ.BOARD_OFFSET_Y
		disappear_counter += 1
	if is_level_award():
		scale = Tod.animate_curve_float(0, 400, disappear_counter, 1.01, 2.0, Tod.CURVE_EASE_IN_OUT)
		pos_x = Tod.animate_curve_float(0, 350, disappear_counter, collect_x, dest_x, Tod.CURVE_EASE_OUT)
		pos_y = Tod.animate_curve_float(0, 350, disappear_counter, collect_y, dest_y, Tod.CURVE_EASE_OUT)
		return
	var dx := absf(pos_x - dest_x)
	var dy := absf(pos_y - dest_y)
	if pos_x > dest_x:
		pos_x -= dx / 21.0
	elif pos_x < dest_x:
		pos_x += dx / 21.0
	if pos_y > dest_y:
		pos_y -= dy / 21.0
	elif pos_y < dest_y:
		pos_y += dy / 21.0
	collection_distance = sqrt(dy * dy + dx * dx)
	if is_present_with_advice():
		if collection_distance < 15.0:
			if not board.help_displayed[PvZ.ADVICE_UNLOCKED_MODE]:
				if type == PvZ.COIN_PRESENT_MINIGAMES:
					board.display_advice("[UNLOCKED_MINIGAMES]", PvZ.MESSAGE_STYLE_HINT_TALL_UNLOCKMESSAGE, PvZ.ADVICE_UNLOCKED_MODE)
				elif type == PvZ.COIN_PRESENT_PUZZLE_MODE:
					board.display_advice("[UNLOCKED_PUZZLE_MODE]", PvZ.MESSAGE_STYLE_HINT_TALL_UNLOCKMESSAGE, PvZ.ADVICE_UNLOCKED_MODE)
			elif board.help_index != PvZ.ADVICE_UNLOCKED_MODE or not board.advice.is_being_displayed():
				die()
	else:
		var scoring_distance := 12.0 if is_money() else 8.0
		if collection_distance < scoring_distance:
			score_coin()
		scale = clampf(collection_distance * 0.05, 0.5, 1.0)
		scale *= get_sun_scale()

func update() -> void:
	coin_age += 1
	if App.game_scene != PvZ.SCENE_PLAYING and App.game_scene != PvZ.SCENE_AWARD and board and not board.cut_scene.should_run_upsell_board():
		return
	if fade_count != 0:
		update_fade()
	elif not is_being_collected:
		update_fall()
	else:
		update_collected()
	if attachment != null:
		var ox := 0.0
		var oy := 0.0
		if type == PvZ.COIN_DIAMOND:
			ox = 18.0 - 18.0 * scale
			oy = 13.0 - 13.0 * scale
		Attachment.update_and_move(self, pos_x + ox, pos_y + oy)
		Attachment.override_color_on(self, get_color())
		Attachment.override_scale_on(self, scale)
		if (not hit_ground or is_being_collected) and (type == PvZ.COIN_SILVER or type == PvZ.COIN_GOLD):
			Attachment.override_color_on(self, Color(0, 0, 0, 0))
	# QE auto-collect: suns / money are picked up as soon as the mouse passes over them.
	# (Online matches send these as clicks instead, see NetSession.)
	if board and board.is_net_game():
		return
	if (App.auto_collect_suns and is_sun()) or (App.auto_collect_coins and is_money()):
		var mx: int = App.widget_manager.last_mouse_x - x
		var my: int = App.widget_manager.last_mouse_y - y
		if mouse_hit_test(mx, my, HitResult.new()):
			mouse_down(mx, my, 0)

func get_color() -> Color:
	if (is_sun() or is_money()) and is_being_collected:
		return Color8(255, 255, 255, int(clampf(collection_distance * 0.035, 0.35, 1.0) * 255.0))
	if fade_count > 0:
		return Color8(255, 255, 255, Tod.animate_curve(15, 0, fade_count, 255, 0, Tod.CURVE_LINEAR))
	return Color.WHITE

func get_final_seed_packet_type() -> int:
	if App.is_first_time_adventure_mode() and board and board.level <= 50:
		return App.get_award_seed_for_level(board.level)
	return PvZ.SEED_NONE

func draw(g: Graphics) -> void:
	g.color = get_color()
	var glow := Res.get_image("IMAGE_AWARDPICKUPGLOW")
	if type == PvZ.COIN_DIAMOND:
		g.colorize_images = true
		g.draw_image(glow, pos_x - 56.0, pos_y - 66.0)
		g.colorize_images = false
	if type == PvZ.COIN_PRESENT_PLANT:
		g.colorize_images = true
		g.draw_image(glow, pos_x - 50.0, pos_y - 64.0)
		g.colorize_images = false
	if type == PvZ.COIN_AWARD_PRESENT and is_being_collected:
		g.colorize_images = true
		g.draw_image(glow, pos_x - 50.0, pos_y - 64.0)
		g.colorize_images = false
	if type == PvZ.COIN_CHOCOLATE or type == PvZ.COIN_AWARD_CHOCOLATE:
		g.colorize_images = true
		g.draw_image(glow, pos_x - 56.0, pos_y - 50.0)
		g.colorize_images = false
	if attachment != null:
		var ag := g.copy()
		make_parent_graphics_frame(ag)
		Attachment.draw_on(self, ag, false)
	if (type == PvZ.COIN_SILVER or type == PvZ.COIN_GOLD) and hit_ground and not is_being_collected:
		return
	if type == PvZ.COIN_DIAMOND:
		return
	if is_level_award() and not is_being_collected:
		g.color = Tod.get_flashing_color(coin_age, 75)
	if type == PvZ.COIN_SILVER or type == PvZ.COIN_GOLD:
		g.colorize_images = true
		g.tod_draw_image_center_scaled_f(Res.get_image("IMAGE_REANIM_COINGLOW"), pos_x - 14.0, pos_y - 12.0, scale, scale)
		g.colorize_images = false
	var img := ""
	var cel := 0
	var draw_scale := scale
	var ox := 0.0
	var oy := 0.0
	match type:
		PvZ.COIN_SILVER:
			img = "IMAGE_REANIM_COIN_SILVER_DOLLAR"; ox = 8.0; oy = 10.0
		PvZ.COIN_GOLD:
			img = "IMAGE_REANIM_COIN_GOLD_DOLLAR"; ox = 8.0; oy = 10.0
		PvZ.COIN_SUN, PvZ.COIN_SMALLSUN, PvZ.COIN_LARGESUN:
			return
		PvZ.COIN_FINAL_SEED_PACKET:
			var st := get_final_seed_packet_type()
			var sg := g.copy()
			sg.scale_x = scale
			sg.scale_y = scale
			SeedPacket.draw_seed_packet(sg, 0.5 * (width - scale * width) + pos_x, 0.5 * (height - scale * height) + pos_y, st, PvZ.SEED_NONE, 0.0, 255, true, false)
			return
		PvZ.COIN_PRESENT_PLANT, PvZ.COIN_AWARD_PRESENT:
			if is_being_collected:
				App.zen_garden.draw_potted_plant_icon(g, pos_x + 10.0, pos_y - 20.0, potted_plant_spec)
				return
			img = "IMAGE_PRESENT"; oy = -20.0
		PvZ.COIN_PRESENT_MINIGAMES, PvZ.COIN_PRESENT_PUZZLE_MODE, PvZ.COIN_PRESENT_SURVIVAL_MODE:
			oy = -20.0
			if is_being_collected:
				ox = -10.0
				oy -= -10.0
				img = "IMAGE_PRESENTOPEN"
			else:
				img = "IMAGE_PRESENT"
		PvZ.COIN_AWARD_MONEY_BAG, PvZ.COIN_AWARD_BAG_DIAMOND:
			img = "IMAGE_MONEYBAG_HI_RES"; ox -= Tod.idiv(width, 2); oy -= Tod.idiv(height, 2); draw_scale *= 0.5
		PvZ.COIN_CHOCOLATE, PvZ.COIN_AWARD_CHOCOLATE:
			img = "IMAGE_CHOCOLATE"
		PvZ.COIN_TROPHY:
			img = "IMAGE_TROPHY_HI_RES"; ox -= Tod.idiv(width, 2); oy -= Tod.idiv(height, 2); draw_scale *= 0.5
		PvZ.COIN_AWARD_SILVER_SUNFLOWER:
			img = "IMAGE_SUNFLOWER_TROPHY"; ox -= 5.0; draw_scale *= 0.6
		PvZ.COIN_AWARD_GOLD_SUNFLOWER:
			img = "IMAGE_SUNFLOWER_TROPHY"; cel = 1; ox -= 5.0; draw_scale *= 0.6
		PvZ.COIN_SHOVEL:
			img = "IMAGE_SHOVEL_HI_RES"; ox -= 20.0; oy -= 20.0; draw_scale *= 0.5
		PvZ.COIN_CARKEYS: img = "IMAGE_CARKEYS"
		PvZ.COIN_ALMANAC: img = "IMAGE_ALMANAC"
		PvZ.COIN_TACO: img = "IMAGE_TACO"
		PvZ.COIN_VASE: img = "IMAGE_SCARY_POT"
		PvZ.COIN_WATERING_CAN: img = "IMAGE_WATERINGCAN"
		PvZ.COIN_NOTE: img = "IMAGE_ZOMBIE_NOTE_SMALL"
		PvZ.COIN_USABLE_SEED_PACKET:
			var grayness := 255
			if is_being_collected:
				grayness = 128
			elif disappear_counter > get_disappear_time() - 300 and disappear_counter % 60 < 30:
				grayness = 192
			g.colorize_images = true
			SeedPacket.draw_seed_packet(g, int(pos_x), int(pos_y), usable_seed_type, PvZ.SEED_NONE, 0.0, grayness, false, false)
			g.colorize_images = false
			return
	if img == "":
		return
	g.colorize_images = true
	g.tod_draw_image_cel_center_scaled_f(Res.get_image(img), pos_x + ox, pos_y + oy, cel, draw_scale, draw_scale)
	g.colorize_images = false

func fan_out_coins(coin_type: int, num: int) -> void:
	for i in num:
		var angle := PI / 2 + PI * (i + 1) / (num + 1)
		var c := board.add_coin(int(pos_x + 20.0), int(pos_y), coin_type, PvZ.COIN_MOTION_FROM_PRESENT)
		c.vel_x = 5.0 * sin(angle)
		c.vel_y = 5.0 * cos(angle)

func try_auto_collect_after_level_award() -> void:
	var can := false
	if is_money() and coin_motion != PvZ.COIN_MOTION_FROM_PRESENT:
		can = true
	if is_sun():
		can = true
	if type == PvZ.COIN_PRESENT_PLANT or type == PvZ.COIN_CHOCOLATE or is_present_with_advice():
		can = true
	if can:
		play_collect_sound()
		collect()

func _detach_arrow(effect: int) -> void:
	Attachment.detach_cross_fade_particle_type(self, effect, "")

func collect() -> void:
	if dead:
		return
	collect_x = pos_x
	collect_y = pos_y
	is_being_collected = true
	if type == PvZ.COIN_PRESENT_PLANT or type == PvZ.COIN_AWARD_PRESENT:
		if App.zen_garden.is_zen_garden_full(false):
			board.display_advice("[DIALOG_ZEN_GARDEN_FULL]", PvZ.MESSAGE_STYLE_HINT_FAST, PvZ.ADVICE_NONE)
		else:
			board.potted_plants_collected += 1
			board.display_advice("[ADVICE_FOUND_PLANT]", PvZ.MESSAGE_STYLE_HINT_FAST, PvZ.ADVICE_NONE)
			App.add_tod_particle(pos_x + 30.0, pos_y + 30.0, render_order + 1, PvZ.PARTICLE_PRESENT_PICKUP)
			App.zen_garden.add_potted_plant(potted_plant_spec)
		disappear_counter = 0
		fade_count = 0
		return
	if is_present_with_advice():
		App.add_tod_particle(pos_x + 30.0, pos_y + 30.0, render_order + 1, PvZ.PARTICLE_PRESENT_PICKUP)
		disappear_counter = 0
		fade_count = 0
		_detach_arrow(PvZ.PARTICLE_AWARD_PICKUP_ARROW)
		match type:
			PvZ.COIN_PRESENT_MINIGAMES: App.player_info.has_unlocked_minigames = 1
			PvZ.COIN_PRESENT_PUZZLE_MODE: App.player_info.has_unlocked_puzzle_mode = 1
			PvZ.COIN_PRESENT_SURVIVAL_MODE: App.player_info.has_unlocked_survival_mode = 1
		return
	if type == PvZ.COIN_CHOCOLATE or type == PvZ.COIN_AWARD_CHOCOLATE:
		board.chocolate_collected += 1
		App.add_tod_particle(pos_x + 30.0, pos_y + 30.0, render_order + 1, PvZ.PARTICLE_PRESENT_PICKUP)
		if App.player_info.purchases[PvZ.STORE_ITEM_CHOCOLATE] < BoardInput.PURCHASE_COUNT_OFFSET:
			board.display_advice("[ADVICE_FOUND_CHOCOLATE]", PvZ.MESSAGE_STYLE_HINT_TALL_FAST, PvZ.ADVICE_NONE)
			App.player_info.purchases[PvZ.STORE_ITEM_CHOCOLATE] = BoardInput.PURCHASE_COUNT_OFFSET + 1
		else:
			App.player_info.purchases[PvZ.STORE_ITEM_CHOCOLATE] += 1
		disappear_counter = 0
		start_fade()
		return
	if is_level_award():
		if App.is_scary_potter_level():
			if type == PvZ.COIN_TROPHY or type == PvZ.COIN_AWARD_MONEY_BAG:
				App.play_foley(PvZ.FOLEY_COIN)
				fan_out_coins(PvZ.COIN_GOLD, 5)
		elif App.is_adventure_mode() and board.level == 50:
			fan_out_coins(PvZ.COIN_DIAMOND, 3)
		elif type == PvZ.COIN_AWARD_GOLD_SUNFLOWER:
			fan_out_coins(PvZ.COIN_DIAMOND, 5)
		elif App.is_first_time_adventure_mode() and board.level == 4:
			App.play_sample("SOUND_SHOVEL")
		elif App.is_first_time_adventure_mode() and (board.level == 24 or board.level == 34 or board.level == 44):
			App.play_sample("SOUND_TAP2")
		elif type == PvZ.COIN_TROPHY:
			App.play_sample("SOUND_DIAMOND")
			fan_out_coins(PvZ.COIN_DIAMOND, 1)
		elif type == PvZ.COIN_AWARD_MONEY_BAG:
			App.play_foley(PvZ.FOLEY_COIN)
			fan_out_coins(PvZ.COIN_GOLD, 5)
		else:
			App.play_sample("SOUND_SEEDLIFT")
			App.play_sample("SOUND_TAP2")
		App.add_tod_particle(pos_x + 30.0, pos_y + 30.0, render_order + 1, PvZ.PARTICLE_STARBURST)
		board.fade_out_level()
		_detach_arrow(PvZ.PARTICLE_SEED_PACKET)
		_detach_arrow(PvZ.PARTICLE_AWARD_PICKUP_ARROW)
		_detach_arrow(PvZ.PARTICLE_COIN_PICKUP_ARROW)
		if type == PvZ.COIN_NOTE:
			App.add_tod_particle(pos_x + 30.0, pos_y + 30.0, render_order + 1, PvZ.PARTICLE_PRESENT_PICKUP)
			start_fade()
		else:
			var pox := float(Tod.idiv(width, 2))
			var poy := float(Tod.idiv(height, 2))
			var ps := App.add_tod_particle(pos_x + pox, pos_y + poy, render_order - 1, PvZ.PARTICLE_SEED_PACKET_PICKUP)
			Attachment.attach_particle(self, ps, pox, poy)
		disappear_counter = 0
		return
	if type == PvZ.COIN_USABLE_SEED_PACKET:
		board.cursor_object.type = usable_seed_type
		board.cursor_object.cursor_type = PvZ.CURSOR_TYPE_PLANT_FROM_USABLE_COIN
		board.cursor_object.coin = self
		ground_y = int(pos_y)
		fade_count = 0
		return
	if is_money() and board:
		board.show_coin_bank()
	fade_count = 0
	if is_sun() and board and not board.has_conveyor_belt_seed_bank() and not vs_zombie_sun:
		for i in board.seed_bank.num_packets:
			var p: SeedPacket = board.seed_bank.seed_packets[i]
			var cost := board.get_current_plant_cost(p.packet_type, p.imitater_type)
			var profit := board.sun_money + board.count_sun_being_collected() - cost
			if profit >= 0 and profit < get_sun_value():
				p.flash_if_ready()
		if board.stage_has_fog():
			render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_ABOVE_UI, 0, 2)
	_detach_arrow(PvZ.PARTICLE_COIN_PICKUP_ARROW)
	if App.is_first_time_adventure_mode() and board and board.level == 11 and (type == PvZ.COIN_GOLD or type == PvZ.COIN_SILVER):
		board.display_advice("[ADVICE_CLICKED_ON_COIN]", PvZ.MESSAGE_STYLE_HINT_FAST, PvZ.ADVICE_CLICKED_ON_COIN)

func get_sun_scale() -> float:
	return 0.5 if type == PvZ.COIN_SMALLSUN else 2.0 if type == PvZ.COIN_LARGESUN else 1.0

func get_sun_value() -> int:
	return 25 if type == PvZ.COIN_SUN else 15 if type == PvZ.COIN_SMALLSUN else 50 if type == PvZ.COIN_LARGESUN else 0

static func get_coin_value(t: int) -> int:
	return 1 if t == PvZ.COIN_SILVER else 5 if t == PvZ.COIN_GOLD else 100 if t == PvZ.COIN_DIAMOND else 0

func play_launch_sound() -> void:
	if type in [PvZ.COIN_DIAMOND, PvZ.COIN_CHOCOLATE, PvZ.COIN_AWARD_CHOCOLATE, PvZ.COIN_PRESENT_PLANT, PvZ.COIN_AWARD_PRESENT] or is_present_with_advice():
		App.play_foley(PvZ.FOLEY_CHIME)

func play_ground_sound() -> void:
	if type == PvZ.COIN_GOLD:
		App.play_foley(PvZ.FOLEY_MONEYFALLS)

func play_collect_sound() -> void:
	if type == PvZ.COIN_USABLE_SEED_PACKET:
		App.play_sample("SOUND_SEEDLIFT")
	elif type == PvZ.COIN_SILVER or type == PvZ.COIN_GOLD:
		App.play_foley(PvZ.FOLEY_COIN)
	elif type == PvZ.COIN_DIAMOND:
		App.play_sample("SOUND_DIAMOND")
	elif is_sun():
		App.play_foley(PvZ.FOLEY_SUN)
	elif type in [PvZ.COIN_CHOCOLATE, PvZ.COIN_PRESENT_PLANT, PvZ.COIN_AWARD_PRESENT, PvZ.COIN_AWARD_CHOCOLATE] or is_present_with_advice():
		App.play_foley(PvZ.FOLEY_PRIZE)

func dropped_usable_seed() -> void:
	is_being_collected = false
	if times_dropped == 0:
		disappear_counter = mini(disappear_counter, 1200)
	times_dropped += 1

func mouse_down(_mx: int, _my: int, click_count: int) -> void:
	if board == null or board.paused or App.game_scene != PvZ.SCENE_PLAYING or dead:
		return
	if click_count >= 0 and not is_being_collected:
		play_collect_sound()
		collect()
		if App.is_first_time_adventure_mode() and board.level == 1:
			board.display_advice("[ADVICE_CLICKED_ON_SUN]", PvZ.MESSAGE_STYLE_TUTORIAL_LEVEL1_STAY, PvZ.ADVICE_CLICKED_ON_SUN)

func die() -> void:
	dead = true
	Attachment.die_on(self)

func mouse_hit_test(tx: int, ty: int, hit: HitResult) -> bool:
	var oy := 0
	if type == PvZ.COIN_PRESENT_PLANT or type == PvZ.COIN_AWARD_PRESENT or is_present_with_advice():
		oy = -20
	var extra := 0
	var extra_h := 0
	if App.is_whack_a_zombie_level():
		extra_h = 30
		extra = 15
	if type == PvZ.COIN_SUN:
		extra = 15
	var can_hit := not (dead or is_being_collected)
	if type == PvZ.COIN_USABLE_SEED_PACKET and board:
		if board.cursor_object.cursor_type != PvZ.CURSOR_TYPE_NORMAL and not App.is_whack_a_zombie_level():
			can_hit = false
	if can_hit and tx >= pos_x - extra and tx < pos_x + width + extra and ty >= pos_y + oy - extra and ty < pos_y + height + oy + extra + extra_h:
		hit.object = self
		hit.object_type = PvZ.OBJECT_TYPE_COIN
		return true
	hit.clear()
	return false

func is_level_award() -> bool:
	return type in [PvZ.COIN_FINAL_SEED_PACKET, PvZ.COIN_TROPHY, PvZ.COIN_AWARD_SILVER_SUNFLOWER, PvZ.COIN_AWARD_GOLD_SUNFLOWER,
		PvZ.COIN_SHOVEL, PvZ.COIN_CARKEYS, PvZ.COIN_ALMANAC, PvZ.COIN_VASE, PvZ.COIN_WATERING_CAN, PvZ.COIN_TACO, PvZ.COIN_NOTE,
		PvZ.COIN_AWARD_MONEY_BAG, PvZ.COIN_AWARD_BAG_DIAMOND, PvZ.COIN_AWARD_PRESENT, PvZ.COIN_AWARD_CHOCOLATE]

func coin_gets_bouncy_arrow() -> bool:
	if is_level_award():
		return true
	if type == PvZ.COIN_SILVER or type == PvZ.COIN_GOLD:
		if App.is_first_time_adventure_mode() and board and board.level == 11 and not board.dropped_first_coin:
			return true
	return is_present_with_advice()

func get_disappear_time() -> int:
	var t := 750
	if type == PvZ.COIN_DIAMOND or type == PvZ.COIN_PRESENT_PLANT or type == PvZ.COIN_CHOCOLATE or has_bouncy_arrow:
		t = 1500
	if App.is_scary_potter_level() and type == PvZ.COIN_USABLE_SEED_PACKET:
		t = 1500
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN:
		t = 6000
	return t
