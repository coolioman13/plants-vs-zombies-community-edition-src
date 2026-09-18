class_name Zombie
extends GameObject
## Port of Zombie: every zombie's behaviour, animation, damage model and drawing.

const MAX_ZOMBIE_FOLLOWERS := 4
const NUM_BOBSLED_FOLLOWERS := 3
const NUM_BACKUP_DANCERS := 4
const NUM_BOSS_BUNGEES := 3
const ZOMBIE_START_RANDOM_OFFSET := 40
const BUNGEE_ZOMBIE_HEIGHT := 3000
const RENDER_GROUP_SHIELD := 1
const RENDER_GROUP_ARMS := 2
const RENDER_GROUP_OVER_SHIELD := 3
const RENDER_GROUP_BOSS_BACK_LEG := 4
const RENDER_GROUP_BOSS_FRONT_LEG := 5
const RENDER_GROUP_BOSS_BACK_ARM := 6
const RENDER_GROUP_BOSS_FIREBALL_ADDITIVE := 7
const RENDER_GROUP_BOSS_FIREBALL_TOP := 8
const ZOMBIE_LIMP_SPEED_FACTOR := 2
const POGO_BOUNCE_TIME := 80
const DOLPHIN_JUMP_TIME := 120
const JACK_IN_THE_BOX_ZOMBIE_RADIUS := 115
const JACK_IN_THE_BOX_PLANT_RADIUS := 90
const BOBSLED_CRASH_TIME := 150
const ZOMBIE_BACKUP_DANCER_RISE_HEIGHT := -200
const BOSS_FLASH_HEALTH_FRACTION := 10
const TICKS_BETWEEN_EATS := 4
const DAMAGE_PER_EAT := TICKS_BETWEEN_EATS
const THOWN_ZOMBIE_GRAVITY := 0.05
const CHILLED_SPEED_FACTOR := 0.4
const CLIP_HEIGHT_LIMIT := -100.0
const CLIP_HEIGHT_OFF := -200.0
const ZOMBIE_MINDCONTROLLED_COLOR := Color(128 / 255.0, 64 / 255.0, 192 / 255.0, 1.0)

const ZOMBIE_WAVE_DEBUG := -1
const ZOMBIE_WAVE_CUTSCENE := -2
const ZOMBIE_WAVE_UI := -3
const ZOMBIE_WAVE_WINNER := -4

enum { ATTACKTYPE_CHEW, ATTACKTYPE_DRIVE_OVER, ATTACKTYPE_VAULT, ATTACKTYPE_LADDER }

const BOSS_ZOMBIE_LIST := [
	PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_PAIL, PvZ.ZOMBIE_FOOTBALL, PvZ.ZOMBIE_POLEVAULTER, PvZ.ZOMBIE_JACK_IN_THE_BOX,
	PvZ.ZOMBIE_LADDER, PvZ.ZOMBIE_ZAMBONI, PvZ.ZOMBIE_CATAPULT, PvZ.ZOMBIE_POGO, PvZ.ZOMBIE_NEWSPAPER, PvZ.ZOMBIE_DOOR,
	PvZ.ZOMBIE_GARGANTUAR,
]

class DrawPosition:
	var head_x := 0
	var head_y := 0
	var arm_y := 0
	var body_y := 0.0
	var image_offset_x := 0.0
	var image_offset_y := 0.0
	var clip_height := 0.0

var zombie_type := PvZ.ZOMBIE_NORMAL
var zombie_phase := PvZ.PHASE_ZOMBIE_NORMAL
var pos_x := 0.0
var pos_y := 0.0
var vel_x := 0.0
var anim_counter := 0
var groan_counter := 0
var anim_ticks_per_frame := 0
var anim_frames := 0
var frame := 0
var prev_frame := 0
var variant := false
var is_eating := false
var just_got_shot_counter := 0
var shield_just_got_shot_counter := 0
var shield_recoil_counter := 0
var zombie_age := 0
var zombie_height := PvZ.HEIGHT_ZOMBIE_NORMAL
var phase_counter := 0
var from_wave := 0
var dropped_loot := false
var zombie_fade := -1
var flat_tires := false
var use_ladder_col := -1
var target_col := -1
var altitude := 0.0
var hit_umbrella := false
var zombie_rect := Rect2i()
var zombie_attack_rect := Rect2i()
var chilled_counter := 0
var buttered_counter := 0
var ice_trap_counter := 0
var mind_controlled := false:
	set(v):
		if mind_controlled != v:
			mind_controlled = v
			mind_control_version += 1
## Bumped whenever a zombie's mind control changes or a zombie joins the board (see BoardCore.any_zombie_with_mind_control).
static var mind_control_version := 0
## Scratch for the rect getters, which use the draw position immediately (avoids an allocation per call).
static var _rect_dp := DrawPosition.new()
var blowing_away := false
var has_head := true
var has_arm := true
var has_object := false
var in_pool := false
var on_high_ground := false
var yucky_face := false
var yucky_face_counter := 0
var helm_type := PvZ.HELMTYPE_NONE
var body_health := 0
var body_max_health := 0
var helm_health := 0
var helm_max_health := 0
var shield_type := PvZ.SHIELDTYPE_NONE
var shield_health := 0
var shield_max_health := 0
var flying_health := 0
var flying_max_health := 0
var related_zombie: Zombie = null
var follower_zombies: Array = [null, null, null, null]
var playing_song := false
var particle_offset_x := 0
var particle_offset_y := 0
var summon_counter := 0
var body_reanim: Reanimation = null
var scale_zombie := 1.0
var vel_z := 0.0
var original_anim_rate := 0.0
var target_plant: Plant = null
var boss_mode := 0
var target_row := -1
var boss_bungee_counter := 0
var boss_stomp_counter := 0
var boss_head_counter := 0
var boss_fire_ball_reanim: Reanimation = null
var special_head_reanim: Reanimation = null
var fireball_row := -1
var is_fire_ball := false
var mowered_reanim: Reanimation = null
var last_portal_x := -1
## Online Versus target zombie: stands still at the far right holding a screen door.
var vs_target := false
var board: Board = null

func _init() -> void:
	board = App.board
	zombie_id = _next_zombie_id
	_next_zombie_id += 1

## Custom-level identity. Survives zombie_initialize (which resets everything else) because
## the spawner sets it on the fresh object first.
var custom_id := -1

static func rv(r: Reanimation) -> Reanimation:
	if r == null or r.freed:
		return null
	return r

static func pv(p: TodParticleSystem) -> TodParticleSystem:
	if p == null or p.freed:
		return null
	return p

## ZombieTryToGet
static func zv(z: Zombie) -> Zombie:
	if z == null or z.freed:
		return null
	return z

static func plv(p: Plant) -> Plant:
	if p == null or p.freed:
		return null
	return p

func _def() -> Array:
	return LawnCommon.zombie_def(zombie_type)

# ================================================================ initialization
func zombie_initialize(the_row: int, the_type: int, the_variant: bool, parent_zombie: Zombie, the_from_wave: int, animate_bush: bool = true) -> void:
	from_wave = the_from_wave
	row = the_row
	pos_x = 780 + Tod.rand_int(ZOMBIE_START_RANDOM_OFFSET) + PvZ.BOARD_ADDITIONAL_WIDTH
	pos_y = get_pos_y_based_on_row(the_row)
	vel_x = 0.0
	vel_z = 0.0
	width = 120
	height = 120
	frame = 0
	prev_frame = 0
	zombie_type = the_type
	variant = the_variant
	is_eating = false
	just_got_shot_counter = 0
	shield_just_got_shot_counter = 0
	shield_recoil_counter = 0
	chilled_counter = 0
	ice_trap_counter = 0
	buttered_counter = 0
	mind_controlled = false
	blowing_away = false
	has_head = true
	has_arm = true
	has_object = false
	in_pool = false
	on_high_ground = false
	helm_type = PvZ.HELMTYPE_NONE
	shield_type = PvZ.SHIELDTYPE_NONE
	yucky_face = false
	yucky_face_counter = 0
	anim_counter = 0
	groan_counter = Tod.rand_range_int(300, 400)
	anim_ticks_per_frame = 12
	anim_frames = 12
	zombie_age = 0
	target_col = -1
	zombie_phase = PvZ.PHASE_ZOMBIE_NORMAL
	zombie_height = PvZ.HEIGHT_ZOMBIE_NORMAL
	phase_counter = 0
	hit_umbrella = false
	dropped_loot = false
	related_zombie = null
	zombie_rect = Rect2i(36, 0, 42, 115)
	zombie_attack_rect = Rect2i(50, 0, 20, 115)
	playing_song = false
	zombie_fade = -1
	flat_tires = false
	scale_zombie = 1.0
	use_ladder_col = -1
	shield_health = 0
	helm_health = 0
	altitude = 0.0
	flying_health = 0
	original_anim_rate = 0.0
	attachment = null
	summon_counter = 0
	boss_stomp_counter = -1
	boss_bungee_counter = -1
	boss_head_counter = -1
	body_reanim = null
	target_plant = null
	boss_mode = 0
	boss_fire_ball_reanim = null
	special_head_reanim = null
	target_row = -1
	fireball_row = -1
	is_fire_ball = false
	mowered_reanim = null
	last_portal_x = -1
	follower_zombies = [null, null, null, null]
	if board and board.is_flag_wave(from_wave):
		pos_x += 40.0
	pick_random_speed()
	body_health = 270

	var zdef := _def()
	var render_layer := PvZ.RENDER_LAYER_ZOMBIE
	var render_offset := 4
	if zdef[LawnCommon.ZDEF_REANIM] != PvZ.REANIM_NONE:
		load_reanim(zdef[LawnCommon.ZDEF_REANIM])

	match the_type:
		PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_DUCKY_TUBE:
			load_plain_zombie_reanim()
		PvZ.ZOMBIE_TRAFFIC_CONE:
			load_plain_zombie_reanim()
			reanim_show_prefix("anim_cone", Reanimation.RENDER_GROUP_NORMAL)
			reanim_show_prefix("anim_hair", Reanimation.RENDER_GROUP_HIDDEN)
			helm_type = PvZ.HELMTYPE_TRAFFIC_CONE
			helm_health = 370
		PvZ.ZOMBIE_PAIL:
			load_plain_zombie_reanim()
			reanim_show_prefix("anim_bucket", Reanimation.RENDER_GROUP_NORMAL)
			reanim_show_prefix("anim_hair", Reanimation.RENDER_GROUP_HIDDEN)
			helm_type = PvZ.HELMTYPE_PAIL
			helm_health = 1100
		PvZ.ZOMBIE_DOOR:
			shield_type = PvZ.SHIELDTYPE_DOOR
			shield_health = 1100
			load_plain_zombie_reanim()
			attach_shield()
		PvZ.ZOMBIE_YETI:
			body_health = 1350
			phase_counter = Tod.rand_range_int(1500, 2000)
			has_object = true
			zombie_attack_rect = Rect2i(20, 0, 50, 115)
		PvZ.ZOMBIE_LADDER:
			body_health = 500
			shield_health = 500
			shield_type = PvZ.SHIELDTYPE_LADDER
			zombie_attack_rect = Rect2i(10, 0, 50, 115)
			if is_on_board():
				zombie_phase = PvZ.PHASE_LADDER_CARRYING
				start_walk_anim(0)
			attach_shield()
		PvZ.ZOMBIE_BUNGEE:
			body_health = 450
			anim_frames = 4
			altitude = BUNGEE_ZOMBIE_HEIGHT + Tod.rand_range_int(0, 150)
			vel_x = 0.0
			if is_on_board():
				pick_bungee_zombie_target(-1)
				if dead:
					return
				zombie_phase = PvZ.PHASE_BUNGEE_DIVING
			else:
				zombie_phase = PvZ.PHASE_BUNGEE_CUTSCENE
				phase_counter = Tod.rand_range_int(0, 200)
			play_zombie_reanim("anim_drop", Reanimation.REANIM_LOOP, 0, 24.0)
			body_reanim.assign_render_group_to_prefix("Zombie_bungi_rightarm_lower2", RENDER_GROUP_ARMS)
			body_reanim.assign_render_group_to_prefix("Zombie_bungi_rightarm_hand2", RENDER_GROUP_ARMS)
			body_reanim.assign_render_group_to_prefix("Zombie_bungi_leftarm_lower2", RENDER_GROUP_ARMS)
			body_reanim.assign_render_group_to_prefix("Zombie_bungi_leftarm_hand2", RENDER_GROUP_ARMS)
			body_reanim.set_truncate_disappearing_frames("", false)
			render_layer = PvZ.RENDER_LAYER_GRAVE_STONE
			render_offset = 7
			zombie_rect = Rect2i(-20, 22, 110, 94)
			zombie_attack_rect = Rect2i(0, 0, 0, 0)
			variant = false
			animate_bush = false
		PvZ.ZOMBIE_FOOTBALL:
			zombie_rect = Rect2i(50, 0, 57, 115)
			reanim_show_prefix("anim_hair", Reanimation.RENDER_GROUP_HIDDEN)
			helm_type = PvZ.HELMTYPE_FOOTBALL
			helm_health = 1400
			anim_ticks_per_frame = 6
			variant = false
		PvZ.ZOMBIE_DIGGER:
			helm_type = PvZ.HELMTYPE_DIGGER
			helm_health = 100
			variant = false
			has_object = true
			zombie_rect = Rect2i(50, 0, 28, 115)
			body_reanim.set_truncate_disappearing_frames("", false)
			if not is_on_board():
				zombie_phase = PvZ.PHASE_DIGGER_CUTSCENE
			else:
				zombie_phase = PvZ.PHASE_DIGGER_TUNNELING
				add_attached_particle(60, 100, PvZ.PARTICLE_DIGGER_TUNNEL)
				render_offset = 7
				play_zombie_reanim("anim_dig", Reanimation.REANIM_LOOP_FULL_LAST_FRAME, 0, 12.0)
				pick_random_speed()
			animate_bush = false
		PvZ.ZOMBIE_POLEVAULTER:
			body_health = 500
			anim_ticks_per_frame = 6
			zombie_phase = PvZ.PHASE_POLEVAULTER_PRE_VAULT
			has_object = true
			variant = false
			pos_x = PvZ.WIDE_BOARD_WIDTH + 70 + Tod.rand_int(10)
			if is_on_board():
				play_zombie_reanim("anim_run", Reanimation.REANIM_LOOP, 0, 0.0)
				pick_random_speed()
			if App.is_wallnut_bowling_level():
				zombie_attack_rect = Rect2i(-229, 0, 270, 115)
			else:
				zombie_attack_rect = Rect2i(-29, 0, 70, 115)
		PvZ.ZOMBIE_DOLPHIN_RIDER:
			body_health = 500
			anim_ticks_per_frame = 6
			zombie_phase = PvZ.PHASE_DOLPHIN_WALKING
			variant = false
			if is_on_board():
				play_zombie_reanim("anim_walkdolphin", Reanimation.REANIM_LOOP, 0, 0.0)
				pick_random_speed()
			setup_water_track("zombie_dolphinrider_whitewater")
			setup_water_track("zombie_dolphinrider_dolphininwater")
		PvZ.ZOMBIE_GARGANTUAR, PvZ.ZOMBIE_REDEYE_GARGANTUAR:
			width = 180
			height = 180
			body_health = 3000
			anim_frames = 24
			anim_ticks_per_frame = 8
			pos_x = PvZ.WIDE_BOARD_WIDTH + 45 + Tod.rand_int(10)
			zombie_rect = Rect2i(-17, -38, 125, 154)
			zombie_attack_rect = Rect2i(-30, -38, 89, 154)
			variant = false
			render_offset = 8
			has_object = true
			var pole_hit := Tod.rand_int(100)
			var pole_variant := 0
			if not is_on_board() or board.level == 48:
				pole_variant = 0
			else:
				pole_variant = 2 if pole_hit < 10 else (1 if pole_hit < 35 else 0)
			if pole_variant == 2:
				body_reanim.set_image_override("Zombie_gargantuar_telephonepole", Res.get_image("IMAGE_REANIM_ZOMBIE_GARGANTUAR_ZOMBIE"))
			elif pole_variant == 1:
				body_reanim.set_image_override("Zombie_gargantuar_telephonepole", Res.get_image("IMAGE_REANIM_ZOMBIE_GARGANTUAR_DUCKXING"))
			if zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR:
				body_reanim.set_image_override("anim_head1", Res.get_image("IMAGE_REANIM_ZOMBIE_GARGANTUAR_HEAD_REDEYE"))
				body_health = 6000
		PvZ.ZOMBIE_ZAMBONI:
			body_health = 1350
			anim_frames = 2
			anim_ticks_per_frame = 8
			pos_x = PvZ.WIDE_BOARD_WIDTH + Tod.rand_int(10)
			render_offset = 8
			play_zombie_reanim("anim_drive", Reanimation.REANIM_LOOP, 0, 12.0)
			zombie_rect = Rect2i(0, -13, 153, 140)
			zombie_attack_rect = Rect2i(10, -13, 133, 140)
			variant = false
		PvZ.ZOMBIE_CATAPULT:
			body_health = 850
			pos_x = PvZ.WIDE_BOARD_WIDTH + 25 + Tod.rand_int(10)
			summon_counter = 20
			if is_on_board():
				play_zombie_reanim("anim_walk", Reanimation.REANIM_LOOP, 0, 5.5)
			else:
				play_zombie_reanim("anim_idle", Reanimation.REANIM_LOOP, 0, 8.0)
			zombie_rect = Rect2i(0, -13, 153, 140)
			zombie_attack_rect = Rect2i(10, -13, 133, 140)
			variant = false
		PvZ.ZOMBIE_SNORKEL:
			zombie_rect = Rect2i(12, 0, 62, 115)
			zombie_attack_rect = Rect2i(-5, 0, 55, 115)
			setup_water_track("Zombie_snorkle_whitewater")
			setup_water_track("Zombie_snorkle_whitewater2")
			variant = false
			zombie_phase = PvZ.PHASE_SNORKEL_WALKING
		PvZ.ZOMBIE_JACK_IN_THE_BOX:
			body_health = 500
			anim_ticks_per_frame = 6
			var distance := 450 + Tod.rand_int(300)
			if Tod.rand_int(20) == 0:
				distance = Tod.idiv(distance, 3)
			phase_counter = int(distance / vel_x) * ZOMBIE_LIMP_SPEED_FACTOR
			zombie_attack_rect = Rect2i(20, 0, 50, 115)
			if App.is_scary_potter_level():
				phase_counter = 10
			if is_on_board():
				zombie_phase = PvZ.PHASE_JACK_IN_THE_BOX_RUNNING
		PvZ.ZOMBIE_BOBSLED:
			render_offset = 3
			if parent_zombie:
				var position := 0
				while position < NUM_BOBSLED_FOLLOWERS and parent_zombie.follower_zombies[position] != null:
					position += 1
				parent_zombie.follower_zombies[position] = self
				related_zombie = parent_zombie
				pos_x = parent_zombie.pos_x + (position + 1) * 50
				if position == 0:
					render_offset = 1
					altitude = 9.0
				elif position == 1:
					render_offset = 2
					altitude = -7.0
				else:
					render_offset = 0
					altitude = 9.0
			else:
				pos_x = PvZ.WIDE_BOARD_WIDTH + 80
				zombie_rect = Rect2i(-50, 0, 275, 115)
				helm_type = PvZ.HELMTYPE_BOBSLED
				helm_health = 300
				altitude = -10.0
			vel_x = 0.6
			zombie_phase = PvZ.PHASE_BOBSLED_SLIDING
			phase_counter = 500
			variant = false
			if from_wave == ZOMBIE_WAVE_CUTSCENE:
				play_zombie_reanim("anim_jump", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 20.0)
				body_reanim.anim_time = 1.0
				altitude = 18.0
			elif is_on_board():
				play_zombie_reanim("anim_push", Reanimation.REANIM_LOOP, 0, 30.0)
		PvZ.ZOMBIE_FLAG:
			has_object = true
			load_plain_zombie_reanim()
			var flag := App.add_reanimation(0.0, 0.0, 0, PvZ.REANIM_FLAG)
			flag.play_reanim("Zombie_flag", Reanimation.REANIM_LOOP, 0, 15.0)
			special_head_reanim = flag
			var ti := body_reanim.get_track_instance("Zombie_flaghand")
			ti.render_in_back = true
			Attachment.attach_reanim(ti, flag, 0.0, 0.0)
			body_reanim.frame_base_pose = 0
			pos_x = PvZ.WIDE_BOARD_WIDTH
		PvZ.ZOMBIE_POGO:
			variant = false
			zombie_phase = PvZ.PHASE_POGO_BOUNCING
			phase_counter = Tod.rand_int(POGO_BOUNCE_TIME) + 1
			has_object = true
			body_health = 500
			zombie_attack_rect = Rect2i(10, 0, 30, 115)
			play_zombie_reanim("anim_pogo", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 40.0)
			body_reanim.anim_time = 1.0
		PvZ.ZOMBIE_NEWSPAPER:
			zombie_attack_rect = Rect2i(20, 0, 50, 115)
			zombie_phase = PvZ.PHASE_NEWSPAPER_READING
			shield_type = PvZ.SHIELDTYPE_NEWSPAPER
			shield_health = 150
			variant = false
			attach_shield()
		PvZ.ZOMBIE_BALLOON:
			body_reanim.set_truncate_disappearing_frames("", false)
			if is_on_board():
				altitude = 25.0
				zombie_phase = PvZ.PHASE_BALLOON_FLYING
				play_zombie_reanim("anim_idle", Reanimation.REANIM_LOOP, 0, body_reanim.anim_rate)
			else:
				set_anim_rate(Tod.rand_range_float(8.0, 10.0))
			var prop := App.add_reanimation(0.0, 0.0, 0, zdef[LawnCommon.ZDEF_REANIM])
			prop.set_frames_for_layer("Propeller")
			prop.loop_type = Reanimation.REANIM_LOOP_FULL_LAST_FRAME
			prop.attach_to_another_reanimation(body_reanim, "hat")
			flying_health = 20
			zombie_rect = Rect2i(36, 30, 42, 115)
			zombie_attack_rect = Rect2i(20, 30, 50, 115)
			variant = false
		PvZ.ZOMBIE_DANCER:
			if not is_on_board():
				play_zombie_reanim("anim_armraise", Reanimation.REANIM_LOOP, 0, 12.0)
			else:
				zombie_phase = PvZ.PHASE_DANCER_DANCING_IN
				vel_x = 0.5
				phase_counter = 300 + Tod.rand_int(12) + (100 if animate_bush else 0)
				play_zombie_reanim("anim_moonwalk", Reanimation.REANIM_LOOP, 0, 24.0)
			body_health = 500
			variant = false
		PvZ.ZOMBIE_BACKUP_DANCER:
			if not is_on_board():
				play_zombie_reanim("anim_armraise", Reanimation.REANIM_LOOP, 0, 12.0)
			zombie_phase = PvZ.PHASE_DANCER_DANCING_LEFT
			variant = false
			animate_bush = false
		PvZ.ZOMBIE_IMP:
			if not is_on_board():
				play_zombie_reanim("anim_walk", Reanimation.REANIM_LOOP, 0, 12.0)
			if App.is_izombie_level():
				body_health = 70
		PvZ.ZOMBIE_BOSS:
			pos_x = PvZ.BOARD_ADDITIONAL_WIDTH
			pos_y = PvZ.BOARD_OFFSET_Y
			zombie_rect = Rect2i(700, 80, 90, 430)
			zombie_attack_rect = Rect2i(0, 0, 0, 0)
			render_layer = PvZ.RENDER_LAYER_TOP
			body_health = 40000 if App.is_adventure_mode() else 60000
			if is_on_board():
				play_zombie_reanim("anim_enter", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 12.0)
				summon_counter = 500
				boss_head_counter = 5000
				zombie_phase = PvZ.PHASE_BOSS_ENTER
			else:
				play_zombie_reanim("anim_head_idle", Reanimation.REANIM_LOOP, 0, 12.0)
			boss_setup_reanim()
		PvZ.ZOMBIE_PEA_HEAD:
			load_plain_zombie_reanim()
			reanim_show_prefix("anim_hair", Reanimation.RENDER_GROUP_HIDDEN)
			reanim_show_prefix("anim_head2", Reanimation.RENDER_GROUP_HIDDEN)
			if is_on_board():
				body_reanim.set_frames_for_layer("anim_walk2")
			_attach_special_head("anim_head1", PvZ.REANIM_PEASHOOTER, "anim_head_idle", 65.0, -5.0, 0.2, -1.0, 1.0, true)
			phase_counter = 150
			variant = false
		PvZ.ZOMBIE_WALLNUT_HEAD:
			load_plain_zombie_reanim()
			_hide_head_for_nut()
			_attach_special_head("Zombie_body", PvZ.REANIM_WALLNUT, "anim_idle", 50.0, 0.0, 0.2, -0.8, 0.8, false)
			helm_type = PvZ.HELMTYPE_WALLNUT
			helm_health = 1100
			variant = false
		PvZ.ZOMBIE_TALLNUT_HEAD:
			load_plain_zombie_reanim()
			_hide_head_for_nut()
			_attach_special_head("Zombie_body", PvZ.REANIM_TALLNUT, "anim_idle", 37.0, 0.0, 0.2, -0.8, 0.8, false)
			helm_type = PvZ.HELMTYPE_TALLNUT
			helm_health = 2200
			variant = false
			pos_x += 30.0
		PvZ.ZOMBIE_JALAPENO_HEAD:
			load_plain_zombie_reanim()
			_hide_head_for_nut()
			_attach_special_head("Zombie_body", PvZ.REANIM_JALAPENO, "anim_idle", 55.0, -5.0, 0.2, -1.0, 1.0, false)
			variant = false
			body_health = 500
			var distance := 275 + Tod.rand_int(175)
			phase_counter = int(distance / vel_x) * ZOMBIE_LIMP_SPEED_FACTOR
		PvZ.ZOMBIE_GATLING_HEAD:
			load_plain_zombie_reanim()
			reanim_show_prefix("anim_hair", Reanimation.RENDER_GROUP_HIDDEN)
			reanim_show_prefix("anim_head2", Reanimation.RENDER_GROUP_HIDDEN)
			if is_on_board():
				body_reanim.set_frames_for_layer("anim_walk2")
			_attach_special_head("anim_head1", PvZ.REANIM_GATLINGPEA, "anim_head_idle", 65.0, -5.0, 0.2, -1.0, 1.0, true)
			phase_counter = 150
			variant = false
		PvZ.ZOMBIE_SQUASH_HEAD:
			load_plain_zombie_reanim()
			reanim_show_prefix("anim_hair", Reanimation.RENDER_GROUP_HIDDEN)
			reanim_show_prefix("anim_head2", Reanimation.RENDER_GROUP_HIDDEN)
			if is_on_board():
				body_reanim.set_frames_for_layer("anim_walk2")
			_attach_special_head("anim_head1", PvZ.REANIM_SQUASH, "anim_idle", 55.0, -15.0, 0.2, -0.75, 0.75, true)
			zombie_phase = PvZ.PHASE_SQUASH_PRE_LAUNCH
			variant = false

	if is_on_board() and App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZOMBIQUARIUM:
		play_zombie_reanim("anim_aquarium_swim", Reanimation.REANIM_LOOP, 0, Tod.rand_range_float(8.0, 10.0))
		zombie_height = PvZ.HEIGHT_ZOMBIQUARIUM
		zombie_phase = PvZ.PHASE_ZOMBIQUARIUM_DRIFT
		phase_counter = 200
		body_health = 200
		summon_counter = Tod.rand_range_int(200, 400)

	if App.is_little_trouble_level() and (is_on_board() or the_from_wave == ZOMBIE_WAVE_CUTSCENE):
		scale_zombie = 0.5
		body_health = Tod.idiv(body_health, 4)
		helm_health = Tod.idiv(helm_health, 4)
		shield_health = Tod.idiv(shield_health, 4)
		flying_health = Tod.idiv(flying_health, 4)

	if custom_id >= 0:
		CustomDefs.apply_zombie_profile(self)
	update_anim_speed()
	if variant:
		reanim_show_prefix("anim_tongue", Reanimation.RENDER_GROUP_NORMAL)

	body_max_health = body_health
	helm_max_health = helm_health
	shield_max_health = shield_health
	flying_max_health = flying_health
	dead = false
	x = int(pos_x)
	y = int(pos_y)
	render_order = BoardCore.make_render_order(render_layer, row, render_offset)
	if zombie_height == PvZ.HEIGHT_ZOMBIQUARIUM:
		body_max_health = 300
	if is_on_board():
		play_zombie_appear_sound()
		start_zombie_sound()
		if animate_bush:
			board.animate_bush(the_row)
	update_reanim()

func _hide_head_for_nut() -> void:
	reanim_show_prefix("anim_hair", Reanimation.RENDER_GROUP_HIDDEN)
	reanim_show_prefix("anim_head", Reanimation.RENDER_GROUP_HIDDEN)
	reanim_show_prefix("Zombie_tie", Reanimation.RENDER_GROUP_HIDDEN)

func _attach_special_head(track: String, rt: int, anim: String, ox: float, oy: float, rot: float, sx: float, sy: float, blank_track: bool) -> void:
	var ti := body_reanim.get_track_instance(track)
	if blank_track:
		ti.image_override = Res.get_image("IMAGE_BLANK")
	var head := App.add_reanimation(0.0, 0.0, 0, rt)
	head.play_reanim(anim, Reanimation.REANIM_LOOP, 0, 15.0)
	special_head_reanim = head
	var eff := Attachment.attach_reanim(ti, head, 0.0, 0.0)
	body_reanim.frame_base_pose = 0
	eff.offset = Tod.scale_rotate_matrix(ox, oy, rot, sx, sy)

static func setup_door_arms(r: Reanimation, show: bool) -> void:
	var arm_group := Reanimation.RENDER_GROUP_NORMAL
	var door_group := Reanimation.RENDER_GROUP_HIDDEN
	if show:
		arm_group = Reanimation.RENDER_GROUP_HIDDEN
		door_group = Reanimation.RENDER_GROUP_NORMAL
	r.assign_render_group_to_prefix("Zombie_outerarm_hand", arm_group)
	r.assign_render_group_to_prefix("Zombie_outerarm_lower", arm_group)
	r.assign_render_group_to_prefix("Zombie_outerarm_upper", arm_group)
	r.assign_render_group_to_prefix("anim_innerarm", arm_group)
	r.assign_render_group_to_prefix("Zombie_outerarm_screendoor", RENDER_GROUP_OVER_SHIELD)
	r.assign_render_group_to_prefix("Zombie_innerarm_screendoor", door_group)
	r.assign_render_group_to_prefix("Zombie_innerarm_screendoor_hand", RENDER_GROUP_OVER_SHIELD)

static func setup_reanim_layers(r: Reanimation, the_type: int) -> void:
	r.assign_render_group_to_prefix("anim_cone", Reanimation.RENDER_GROUP_HIDDEN)
	r.assign_render_group_to_prefix("anim_bucket", Reanimation.RENDER_GROUP_HIDDEN)
	r.assign_render_group_to_prefix("anim_screendoor", Reanimation.RENDER_GROUP_HIDDEN)
	r.assign_render_group_to_prefix("Zombie_flaghand", Reanimation.RENDER_GROUP_HIDDEN)
	r.assign_render_group_to_prefix("Zombie_duckytube", Reanimation.RENDER_GROUP_HIDDEN)
	r.assign_render_group_to_prefix("anim_tongue", Reanimation.RENDER_GROUP_HIDDEN)
	r.assign_render_group_to_prefix("Zombie_mustache", Reanimation.RENDER_GROUP_HIDDEN)
	setup_door_arms(r, false)
	match the_type:
		PvZ.ZOMBIE_TRAFFIC_CONE:
			r.assign_render_group_to_prefix("anim_cone", Reanimation.RENDER_GROUP_NORMAL)
			r.assign_render_group_to_prefix("anim_hair", Reanimation.RENDER_GROUP_HIDDEN)
		PvZ.ZOMBIE_PAIL:
			r.assign_render_group_to_prefix("anim_bucket", Reanimation.RENDER_GROUP_NORMAL)
			r.assign_render_group_to_prefix("anim_hair", Reanimation.RENDER_GROUP_HIDDEN)
		PvZ.ZOMBIE_DOOR:
			setup_door_arms(r, true)
		PvZ.ZOMBIE_NEWSPAPER:
			r.assign_render_group_to_prefix("Zombie_paper_paper", Reanimation.RENDER_GROUP_HIDDEN)
		PvZ.ZOMBIE_FLAG:
			r.assign_render_group_to_prefix("anim_innerarm", Reanimation.RENDER_GROUP_HIDDEN)
			r.assign_render_group_to_track("Zombie_flaghand", Reanimation.RENDER_GROUP_NORMAL)
			r.assign_render_group_to_track("Zombie_innerarm_screendoor", Reanimation.RENDER_GROUP_NORMAL)
		PvZ.ZOMBIE_DUCKY_TUBE:
			r.assign_render_group_to_prefix("Zombie_duckytube", Reanimation.RENDER_GROUP_NORMAL)

func show_door_arms(show: bool) -> void:
	var r := rv(body_reanim)
	if r:
		setup_door_arms(r, show)
		if not has_arm:
			reanim_show_prefix("Zombie_outerarm_lower", Reanimation.RENDER_GROUP_HIDDEN)
			reanim_show_prefix("Zombie_outerarm_hand", Reanimation.RENDER_GROUP_HIDDEN)

func reanim_ignore_clip_rect(track_name: String, ignore: bool) -> void:
	var r := rv(body_reanim)
	if r == null:
		return
	var lower := track_name.to_lower()
	for i in r.definition.tracks.size():
		if (r.definition.tracks[i] as Defs.ReanimTrackDef).name.to_lower() == lower:
			r.track_instances[i].ignore_clip_rect = ignore

func reanim_reenable_clipping() -> void:
	var r := rv(body_reanim)
	if r == null:
		return
	for ti in r.track_instances:
		ti.ignore_clip_rect = false

func load_plain_zombie_reanim() -> void:
	zombie_attack_rect = Rect2i(20, 0, 50, 115)
	var r := rv(body_reanim)
	if r == null:
		return
	setup_reanim_layers(r, zombie_type)
	if board:
		enable_mustache(board.mustache_mode)
		enable_future(board.future_mode)
	if (board and board.plant_row[row] == PvZ.PLANTROW_POOL) or zombie_type == PvZ.ZOMBIE_DUCKY_TUBE:
		reanim_show_prefix("zombie_duckytube", Reanimation.RENDER_GROUP_NORMAL)
		reanim_ignore_clip_rect("Zombie_duckytube", true)
		reanim_ignore_clip_rect("Zombie_outerarm_hand", true)
		reanim_ignore_clip_rect("Zombie_innerarm3", true)
		setup_water_track("Zombie_whitewater")
		setup_water_track("Zombie_whitewater2")

func load_reanim(rt: int) -> Reanimation:
	# a custom zombie (or a custom level's boss) can bring its own .reanim; everything after this
	# point poses whatever loads
	if custom_id >= 0:
		rt = CustomDefs.zombie_reanim_type(custom_id, rt)
	elif zombie_type == PvZ.ZOMBIE_BOSS:
		rt = CustomDefs.boss_reanim_type(rt)
	var r := App.add_reanimation(0.0, 0.0, 0, rt)
	body_reanim = r
	r.loop_type = Reanimation.REANIM_LOOP
	r.is_attachment = true
	if not is_on_board():
		if Tod.rand_int(4) > 0 and r.track_exists("anim_idle2"):
			play_zombie_reanim("anim_idle2", Reanimation.REANIM_LOOP, 0, Tod.rand_range_float(12.0, 24.0))
		elif r.track_exists("anim_idle"):
			play_zombie_reanim("anim_idle", Reanimation.REANIM_LOOP, 0, Tod.rand_range_float(12.0, 18.0))
		r.anim_time = Tod.rand_range_float(0.0, 0.99)
	else:
		start_walk_anim(0)
	return r

# ================================================================ bungee
func count_bungees_targeting_sun_flowers() -> int:
	var c := 0
	for z in board.zombies:
		if z.dead:
			continue
		if not z.is_dead_or_dying() and z.zombie_type == PvZ.ZOMBIE_BUNGEE and z.target_col != -1:
			var p := board.get_top_plant_at(z.target_col, z.row, PvZ.TOPPLANT_BUNGEE_ORDER)
			if p and p.makes_sun():
				c += 1
	return c

func pick_bungee_zombie_target(column: int) -> void:
	var allow_sun := true
	if count_bungees_targeting_sun_flowers() == board.count_sun_flowers() - 1:
		allow_sun = false
	var picks: Array = []
	for gx in BoardCore.MAX_GRID_SIZE_X:
		if column != -1 and column != gx:
			continue
		for gy in BoardCore.MAX_GRID_SIZE_Y:
			var weight := 1
			if board.get_grave_stone_at(gx, gy) or board.grid_square_type[gx][gy] == PvZ.GRIDSQUARE_DIRT:
				continue
			var p := board.get_top_plant_at(gx, gy, PvZ.TOPPLANT_BUNGEE_ORDER)
			if p:
				if not allow_sun and p.makes_sun():
					continue
				if p.seed_type == PvZ.SEED_GRAVEBUSTER or p.seed_type == PvZ.SEED_COBCANNON:
					continue
				weight = 10000
			if not board.bungee_is_targeting_cell(gx, gy):
				picks.append({"x": gx, "y": gy, "weight": weight})
	if picks.is_empty():
		die_no_loot()
		return
	var cell: Dictionary = Tod.pick_from_weighted_grid_array(picks)
	target_col = cell.x
	set_row(cell.y)
	pos_x = board.grid_to_pixel_x(target_col, row)
	pos_y = get_pos_y_based_on_row(row)

func bungee_drop_zombie(dropped: Zombie, gx: int, gy: int) -> void:
	target_col = gx
	set_row(gy)
	pos_x = board.grid_to_pixel_x(target_col, row)
	pos_y = get_pos_y_based_on_row(row)
	play_zombie_reanim("anim_raise", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 36.0)
	related_zombie = dropped
	dropped.pos_x = pos_x - 15.0
	dropped.set_row(gy)
	dropped.pos_y = get_pos_y_based_on_row(gy)
	dropped.zombie_height = PvZ.HEIGHT_GETTING_BUNGEE_DROPPED
	dropped.play_zombie_reanim("anim_idle", Reanimation.REANIM_LOOP, 0, 0.0)
	dropped.render_order = render_order + 1

func pick_random_speed() -> void:
	if zombie_phase == PvZ.PHASE_DOLPHIN_WALKING_IN_POOL:
		vel_x = 0.3
	elif zombie_phase == PvZ.PHASE_SNORKEL_WALKING_IN_POOL:
		vel_x = 0.2
	elif zombie_phase == PvZ.PHASE_DIGGER_WALKING:
		vel_x = 0.23 if App.is_izombie_level() else 0.12
	elif zombie_type == PvZ.ZOMBIE_IMP and App.is_izombie_level():
		vel_x = 0.9
	elif zombie_phase == PvZ.PHASE_YETI_RUNNING:
		vel_x = 0.8
	elif zombie_type == PvZ.ZOMBIE_YETI:
		vel_x = 0.4
	elif zombie_type == PvZ.ZOMBIE_DANCER or zombie_type == PvZ.ZOMBIE_BACKUP_DANCER or zombie_type == PvZ.ZOMBIE_POGO or zombie_type == PvZ.ZOMBIE_FLAG:
		vel_x = 0.45
	elif zombie_phase == PvZ.PHASE_DIGGER_TUNNELING or zombie_phase == PvZ.PHASE_POLEVAULTER_PRE_VAULT or zombie_type == PvZ.ZOMBIE_FOOTBALL \
			or zombie_type == PvZ.ZOMBIE_SNORKEL or zombie_type == PvZ.ZOMBIE_JACK_IN_THE_BOX:
		vel_x = Tod.rand_range_float(0.66, 0.68)
	elif zombie_phase == PvZ.PHASE_LADDER_CARRYING or zombie_type == PvZ.ZOMBIE_SQUASH_HEAD:
		vel_x = Tod.rand_range_float(0.79, 0.81)
	elif zombie_phase == PvZ.PHASE_NEWSPAPER_MAD or zombie_phase == PvZ.PHASE_DOLPHIN_WALKING or zombie_phase == PvZ.PHASE_DOLPHIN_WALKING_WITHOUT_DOLPHIN:
		vel_x = Tod.rand_range_float(0.89, 0.91)
	else:
		vel_x = Tod.rand_range_float(0.23, 0.37)
		anim_ticks_per_frame = 12 if vel_x < 0.3 else 15
	update_anim_speed()

func bungee_steal_target() -> void:
	play_zombie_reanim("anim_grab", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 24.0)
	var p := board.get_top_plant_at(target_col, row, PvZ.TOPPLANT_BUNGEE_ORDER)
	if p and not p.not_on_ground():
		if p.seed_type != PvZ.SEED_COBCANNON and p.seed_type != PvZ.SEED_GRAVEBUSTER:
			target_plant = p
			p.on_bungee_state = PvZ.GETTING_GRABBED_BY_BUNGEE
			render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_PROJECTILE, row, 0)

func bungee_lift_target() -> void:
	play_zombie_reanim("anim_raise", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 36.0)
	var p := plv(target_plant)
	if p == null:
		return
	for z in board.zombies:
		if not z.dead and z.zombie_type == PvZ.ZOMBIE_BUNGEE and z != self and z.target_plant == target_plant:
			z.target_plant = null
	p.on_bungee_state = PvZ.RISING_WITH_BUNGEE
	App.play_foley(PvZ.FOLEY_FLOOP)
	var pr := rv(p.body_reanim)
	if pr:
		pr.anim_rate = 0.1
	if p.seed_type == PvZ.SEED_CATTAIL and board.get_top_plant_at(target_col, row, PvZ.TOPPLANT_ONLY_PUMPKIN):
		board.new_plant(target_col, row, PvZ.SEED_LILYPAD, PvZ.SEED_NONE)
	if App.is_izombie_level():
		board.challenge.izombie_plant_drop_remaining_sun(p)

func bungee_landing() -> void:
	if zombie_phase == PvZ.PHASE_BUNGEE_DIVING and altitude < 1500.0 and not App.is_final_boss_level():
		App.play_foley(PvZ.FOLEY_BUNGEE_SCREAM)
		zombie_phase = PvZ.PHASE_BUNGEE_DIVING_SCREAMING
	if altitude > 40.0:
		return
	var umbrella := board.find_umbrella_plant(target_col, row)
	if umbrella:
		App.play_sample("SOUND_BOING")
		App.play_foley(PvZ.FOLEY_UMBRELLA)
		umbrella.do_special()
		zombie_phase = PvZ.PHASE_BUNGEE_RISING
		render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_TOP, 0, 1)
		hit_umbrella = true
		return
	if altitude > 0.0:
		return
	altitude = 0.0
	var z := zv(related_zombie)
	if z:
		z.zombie_height = PvZ.HEIGHT_ZOMBIE_NORMAL
		z.start_walk_anim(0)
		related_zombie = null
		zombie_phase = PvZ.PHASE_BUNGEE_RISING
		play_zombie_reanim("anim_raise", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 36.0)
	else:
		zombie_phase = PvZ.PHASE_BUNGEE_AT_BOTTOM
		phase_counter = 300
		play_zombie_reanim("anim_idle", Reanimation.REANIM_LOOP, 5, 24.0)
		body_reanim.anim_time = 0.5

func update_zombie_bungee() -> void:
	if is_dead_or_dying() or is_immobilizied():
		return
	match zombie_phase:
		PvZ.PHASE_BUNGEE_DIVING, PvZ.PHASE_BUNGEE_DIVING_SCREAMING:
			var old_alt := altitude
			altitude -= 8.0
			if altitude <= BUNGEE_ZOMBIE_HEIGHT - 404.0 and old_alt > BUNGEE_ZOMBIE_HEIGHT - 404.0 and related_zombie == null:
				App.play_foley(PvZ.FOLEY_GRASSSTEP)
			bungee_landing()
		PvZ.PHASE_BUNGEE_AT_BOTTOM:
			if phase_counter <= 0:
				bungee_steal_target()
				zombie_phase = PvZ.PHASE_BUNGEE_GRABBING
		PvZ.PHASE_BUNGEE_GRABBING:
			if body_reanim.loop_count > 0:
				bungee_lift_target()
				zombie_phase = PvZ.PHASE_BUNGEE_RISING
		PvZ.PHASE_BUNGEE_HIT_OUCHY:
			if phase_counter <= 0:
				die_with_loot()
		PvZ.PHASE_BUNGEE_RISING:
			altitude += 8.0
			if altitude >= 600.0:
				die_no_loot()
		PvZ.PHASE_BUNGEE_CUTSCENE:
			altitude = Tod.animate_curve(200, 0, phase_counter, 40, 0, Tod.CURVE_SIN_WAVE)
			if phase_counter <= 0:
				phase_counter = 200
	x = int(pos_x)
	y = int(pos_y)

# ================================================================ pogo
func pogo_break(damage_flags: int) -> void:
	if not has_object:
		return
	if not Tod.test_bit(damage_flags, PvZ.DAMAGE_DOESNT_LEAVE_BODY):
		var tp := get_track_position("Zombie_pogo_stick")
		var ps := App.add_tod_particle(tp.x, tp.y + 30.0, render_order + 1, PvZ.PARTICLE_ZOMBIE_POGO)
		override_particle_scale(ps)
	zombie_height = PvZ.HEIGHT_FALLING
	zombie_phase = PvZ.PHASE_ZOMBIE_NORMAL
	start_walk_anim(0)
	zombie_rect = Rect2i(36, 17, 42, 115)
	zombie_attack_rect = Rect2i(20, 17, 50, 115)
	shield_health = 0
	shield_type = PvZ.SHIELDTYPE_NONE
	has_object = false

func is_bouncing_pogo() -> bool:
	return zombie_phase >= PvZ.PHASE_POGO_BOUNCING and zombie_phase <= PvZ.PHASE_POGO_FORWARD_BOUNCE_7

func update_zombie_pogo() -> void:
	if is_dead_or_dying() or is_immobilizied() or not is_bouncing_pogo() or zombie_height == PvZ.HEIGHT_IN_TO_CHIMNEY:
		return
	var h := 40.0
	if zombie_phase >= PvZ.PHASE_POGO_HIGH_BOUNCE_1 and zombie_phase <= PvZ.PHASE_POGO_HIGH_BOUNCE_6:
		h = 50.0 + 20.0 * (zombie_phase - PvZ.PHASE_POGO_HIGH_BOUNCE_1)
	elif zombie_phase == PvZ.PHASE_POGO_FORWARD_BOUNCE_2:
		h = 90.0
	elif zombie_phase == PvZ.PHASE_POGO_FORWARD_BOUNCE_7:
		h = 170.0
	altitude = Tod.animate_curve_float(POGO_BOUNCE_TIME, 0, phase_counter, 9.0, h + 9.0, Tod.CURVE_BOUNCE_SLOW_MIDDLE)
	frame = clampi(int(3 - altitude / 3), 0, 3)
	if phase_counter == 7:
		body_reanim.anim_time = 0.0
		body_reanim.loop_type = Reanimation.REANIM_PLAY_ONCE_AND_HOLD
	if is_on_board() and phase_counter == 5:
		App.play_foley(PvZ.FOLEY_POGO_ZOMBIE)
	if zombie_height == PvZ.HEIGHT_UP_TO_HIGH_GROUND:
		altitude += PvZ.HIGH_GROUND_HEIGHT
		zombie_height = PvZ.HEIGHT_ZOMBIE_NORMAL
	elif zombie_height == PvZ.HEIGHT_DOWN_OFF_HIGH_GROUND:
		on_high_ground = false
		zombie_height = PvZ.HEIGHT_ZOMBIE_NORMAL
	elif on_high_ground:
		altitude += PvZ.HIGH_GROUND_HEIGHT
	if zombie_phase == PvZ.PHASE_POGO_FORWARD_BOUNCE_2 and phase_counter == 70:
		var tp := find_plant_target(ATTACKTYPE_VAULT)
		if tp and tp.seed_type == PvZ.SEED_TALLNUT:
			App.play_foley(PvZ.FOLEY_BONK)
			App.add_tod_particle(tp.x + 60, tp.y - 20, render_order + 1, PvZ.PARTICLE_TALL_NUT_BLOCK)
			shield_type = PvZ.SHIELDTYPE_NONE
			pogo_break(0)
			return
	if phase_counter != 0:
		return
	var p: Plant = null
	if is_on_board():
		p = find_plant_target(ATTACKTYPE_VAULT)
	if p == null:
		zombie_phase = PvZ.PHASE_POGO_BOUNCING
		pick_random_speed()
		phase_counter = POGO_BOUNCE_TIME
		return
	if zombie_phase == PvZ.PHASE_POGO_HIGH_BOUNCE_1:
		zombie_phase = PvZ.PHASE_POGO_FORWARD_BOUNCE_2
		vel_x = (x - p.x + 60) / float(POGO_BOUNCE_TIME)
		phase_counter = POGO_BOUNCE_TIME
	else:
		zombie_phase = PvZ.PHASE_POGO_HIGH_BOUNCE_1
		vel_x = 0.0
		phase_counter = POGO_BOUNCE_TIME

# ================================================================ catapult
func zombie_catapult_fire(p: Plant) -> void:
	var ox := pos_x + 113.0
	var oy := pos_y - 44.0
	var tx: int
	var ty: int
	if p:
		tx = p.x
		ty = p.y
	else:
		tx = int(pos_x - 300.0)
		ty = 0
	App.play_foley(PvZ.FOLEY_BASKETBALL)
	var proj := board.add_projectile(int(ox), int(oy), render_order, row, PvZ.PROJECTILE_BASKETBALL)
	var range_x := ox - tx - 20.0
	var range_y := ty - oy
	if range_x < 40.0:
		range_x = 40.0
	proj.motion_type = PvZ.MOTION_LOBBED
	proj.vel_x = -range_x / 120.0
	proj.vel_y = 0.0
	proj.vel_z = range_y / 120.0 - 7.0
	proj.acc_z = 0.115

func find_catapult_target() -> Plant:
	var target: Plant = null
	for p in board.plants:
		if p.dead:
			continue
		if p.row == row and x >= p.x + 100 and not p.not_on_ground() and not p.is_spiky():
			if target == null or p.plant_col < target.plant_col:
				target = board.get_top_plant_at(p.plant_col, p.row, PvZ.TOPPLANT_CATAPULT_ORDER)
	return target

func update_zombie_catapult() -> void:
	if zombie_phase == PvZ.PHASE_ZOMBIE_NORMAL:
		if pos_x <= 650 + PvZ.BOARD_ADDITIONAL_WIDTH and find_catapult_target() and summon_counter > 0:
			zombie_phase = PvZ.PHASE_CATAPULT_LAUNCHING
			phase_counter = 300
			play_zombie_reanim("anim_shoot", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 24.0)
	elif zombie_phase == PvZ.PHASE_CATAPULT_LAUNCHING:
		var r := body_reanim
		if r.should_trigger_timed_event(0.545):
			zombie_catapult_fire(find_catapult_target())
		if r.loop_count > 0:
			summon_counter -= 1
			if summon_counter == 4:
				reanim_show_track("Zombie_catapult_basketball", Reanimation.RENDER_GROUP_HIDDEN)
			elif summon_counter == 3:
				reanim_show_track("Zombie_catapult_basketball2", Reanimation.RENDER_GROUP_HIDDEN)
			elif summon_counter == 2:
				reanim_show_track("Zombie_catapult_basketball3", Reanimation.RENDER_GROUP_HIDDEN)
			elif summon_counter == 1:
				reanim_show_track("Zombie_catapult_basketball4", Reanimation.RENDER_GROUP_HIDDEN)
			if summon_counter == 0:
				play_zombie_reanim("anim_walk", Reanimation.REANIM_LOOP, 20, 6.0)
				zombie_phase = PvZ.PHASE_ZOMBIE_NORMAL
			else:
				play_zombie_reanim("anim_idle", Reanimation.REANIM_LOOP, 20, 12.0)
				zombie_phase = PvZ.PHASE_CATAPULT_RELOADING
	elif zombie_phase == PvZ.PHASE_CATAPULT_RELOADING and phase_counter == 0:
		if find_catapult_target():
			zombie_phase = PvZ.PHASE_CATAPULT_LAUNCHING
			phase_counter = 300
			play_zombie_reanim("anim_shoot", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 24.0)
		else:
			play_zombie_reanim("anim_walk", Reanimation.REANIM_LOOP, 20, 6.0)
			zombie_phase = PvZ.PHASE_ZOMBIE_NORMAL

# ================================================================ flyers / newspaper / polevaulter
func land_flyer(damage_flags: int) -> void:
	if not Tod.test_bit(damage_flags, PvZ.DAMAGE_DOESNT_LEAVE_BODY) and zombie_phase == PvZ.PHASE_BALLOON_FLYING:
		App.play_sample("SOUND_BALLOON_POP")
		zombie_phase = PvZ.PHASE_BALLOON_POPPING
		play_zombie_reanim("anim_pop", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 24.0)
	if board.plant_row[row] == PvZ.PLANTROW_POOL:
		die_with_loot()
	else:
		zombie_height = PvZ.HEIGHT_FALLING

func update_zombie_flyer() -> void:
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_HIGH_GRAVITY and pos_x < 720.0 + PvZ.BOARD_ADDITIONAL_WIDTH:
		altitude -= 0.1
		if altitude < -35.0:
			land_flyer(0)
	if zombie_phase == PvZ.PHASE_BALLOON_POPPING:
		if body_reanim.loop_count > 0:
			zombie_phase = PvZ.PHASE_BALLOON_WALKING
			start_walk_anim(0)
	if App.is_izombie_level() and zombie_phase == PvZ.PHASE_BALLOON_FLYING and board.challenge.izombie_get_brain_target(self):
		land_flyer(0)

func update_zombie_newspaper() -> void:
	if zombie_phase == PvZ.PHASE_NEWSPAPER_MADDENING:
		var r := body_reanim
		if r.loop_count > 0:
			zombie_phase = PvZ.PHASE_NEWSPAPER_MAD
			if board.count_zombies_on_screen() <= 10 and has_head:
				App.play_foley(PvZ.FOLEY_NEWSPAPER_RARRGH)
			start_walk_anim(20)
			r.set_image_override("anim_head1", Res.get_image("IMAGE_REANIM_ZOMBIE_PAPER_MADHEAD"))

func update_zombie_polevaulter() -> void:
	if zombie_phase == PvZ.PHASE_POLEVAULTER_PRE_VAULT and has_head and zombie_height == PvZ.HEIGHT_ZOMBIE_NORMAL:
		var p := find_plant_target(ATTACKTYPE_VAULT)
		if p:
			if board.get_ladder_at(p.plant_col, p.row):
				var plant_x := float(board.grid_to_pixel_x(p.plant_col, p.row) + 40)
				if plant_x > pos_x and zombie_height == PvZ.HEIGHT_ZOMBIE_NORMAL and use_ladder_col != p.plant_col:
					zombie_height = PvZ.HEIGHT_UP_LADDER
					use_ladder_col = p.plant_col
				return
			zombie_phase = PvZ.PHASE_POLEVAULTER_IN_VAULT
			play_zombie_reanim("anim_jump", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 24.0)
			var r := body_reanim
			var dur := r.frame_count / r.anim_rate * 100.0
			var jump := x - p.x - 80
			if App.is_wallnut_bowling_level():
				jump = 0
			vel_x = jump / dur
			has_object = false
		if App.is_izombie_level() and board.challenge.izombie_get_brain_target(self):
			zombie_phase = PvZ.PHASE_POLEVAULTER_POST_VAULT
			start_walk_anim(0)
	elif zombie_phase == PvZ.PHASE_POLEVAULTER_IN_VAULT:
		var r := body_reanim
		var jump_ends := false
		if r.anim_time > 0.6 and r.anim_time <= 0.7:
			var p := find_plant_target(ATTACKTYPE_VAULT)
			if p and p.seed_type == PvZ.SEED_TALLNUT:
				App.play_foley(PvZ.FOLEY_BONK)
				jump_ends = true
				App.add_tod_particle(p.x + 60, p.y - 20, render_order + 1, PvZ.PARTICLE_TALL_NUT_BLOCK)
				zombie_height = PvZ.HEIGHT_FALLING
				pos_x = p.x
				pos_y -= 30.0
		if r.loop_count > 0:
			jump_ends = true
			pos_x -= 150.0
		if r.should_trigger_timed_event(0.2):
			App.play_foley(PvZ.FOLEY_GRASSSTEP)
		if r.should_trigger_timed_event(0.4):
			App.play_foley(PvZ.FOLEY_POLEVAULT)
		if jump_ends:
			x = int(pos_x)
			zombie_phase = PvZ.PHASE_POLEVAULTER_POST_VAULT
			zombie_attack_rect = Rect2i(50, 0, 20, 115)
			start_walk_anim(0)
		else:
			var old := pos_x
			pos_x -= 150.0 * r.anim_time
			pos_y = get_pos_y_based_on_row(row)
			pos_x = old

func is_tangle_kelp_target() -> bool:
	for p in board.plants:
		if not p.dead and p.seed_type == PvZ.SEED_TANGLEKELP and p.target_zombie == self:
			return true
	return false

func _splash(ox: int, oy: int, px: int, py: int) -> void:
	var s := App.add_reanimation(x + ox, y + oy, render_order + 1, PvZ.REANIM_SPLASH)
	s.override_scale(1.2, 0.8)
	App.add_tod_particle(x + px, y + py, render_order + 1, PvZ.PARTICLE_PLANTING_POOL)
	App.play_foley(PvZ.FOLEY_ZOMBIE_ENTERING_WATER)

func update_zombie_dolphin_rider() -> void:
	if is_tangle_kelp_target():
		return
	var backwards := is_walking_backwards()
	if zombie_phase == PvZ.PHASE_DOLPHIN_WALKING and not backwards:
		if x > 700 + PvZ.BOARD_ADDITIONAL_WIDTH and x <= 720 + PvZ.BOARD_ADDITIONAL_WIDTH:
			zombie_phase = PvZ.PHASE_DOLPHIN_INTO_POOL
			play_zombie_reanim("anim_jumpinpool", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 16.0)
	elif zombie_phase == PvZ.PHASE_DOLPHIN_INTO_POOL:
		var r := body_reanim
		if r.should_trigger_timed_event(0.56):
			_splash(-83, 73, -46, 115)
		if r.loop_count > 0:
			pos_x -= 70.0
			zombie_phase = PvZ.PHASE_DOLPHIN_RIDING
			in_pool = true
			zombie_attack_rect = Rect2i(-29, 0, 70, 115)
			play_zombie_reanim("anim_ride", Reanimation.REANIM_LOOP_FULL_LAST_FRAME, 0, 12.0)
	elif zombie_phase == PvZ.PHASE_DOLPHIN_RIDING:
		if x <= 10 + PvZ.BOARD_ADDITIONAL_WIDTH:
			altitude = -40.0
			zombie_height = PvZ.HEIGHT_OUT_OF_POOL
			zombie_phase = PvZ.PHASE_DOLPHIN_WALKING
			pool_splash(false)
			play_zombie_reanim("anim_walkdolphin", Reanimation.REANIM_LOOP, 0, 0.0)
			pick_random_speed()
			return
		if has_head and not is_tangle_kelp_target():
			var p := find_plant_target(ATTACKTYPE_VAULT)
			if p:
				App.play_foley(PvZ.FOLEY_DOLPHIN_BEFORE_JUMPING)
				App.play_foley(PvZ.FOLEY_PLANT_WATER)
				vel_x = 0.5
				zombie_phase = PvZ.PHASE_DOLPHIN_IN_JUMP
				phase_counter = DOLPHIN_JUMP_TIME
				play_zombie_reanim("anim_dolphinjump", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 10.0)
	elif zombie_phase == PvZ.PHASE_DOLPHIN_IN_JUMP:
		var r := body_reanim
		altitude = Tod.animate_curve_float(DOLPHIN_JUMP_TIME, 0, phase_counter, 0.0, 10.0, Tod.CURVE_LINEAR)
		var jump_ends := false
		if r.should_trigger_timed_event(0.3):
			var p := find_plant_target(ATTACKTYPE_VAULT)
			if p and p.seed_type == PvZ.SEED_TALLNUT:
				App.play_foley(PvZ.FOLEY_BONK)
				jump_ends = true
				App.add_tod_particle(p.x + 60, p.y - 20, render_order + 1, PvZ.PARTICLE_TALL_NUT_BLOCK)
				zombie_height = PvZ.HEIGHT_FALLING
				pos_x = p.x + 25.0
				altitude = 30.0
		elif r.should_trigger_timed_event(0.49):
			_splash(-63, 73, -26, 115)
			vel_x = 0.0
		elif r.loop_count > 0:
			jump_ends = true
			pos_x -= 94.0
			altitude = 0.0
		if jump_ends:
			zombie_attack_rect = Rect2i(30, 0, 30, 115)
			zombie_rect = Rect2i(20, 0, 42, 115)
			zombie_phase = PvZ.PHASE_DOLPHIN_WALKING_IN_POOL
			start_walk_anim(0)
	elif zombie_phase == PvZ.PHASE_DOLPHIN_WALKING_IN_POOL:
		if (x <= 10 + PvZ.BOARD_ADDITIONAL_WIDTH and not backwards) or (x > 680 + PvZ.BOARD_ADDITIONAL_WIDTH and backwards):
			altitude = -40.0
			zombie_height = PvZ.HEIGHT_OUT_OF_POOL
			zombie_phase = PvZ.PHASE_DOLPHIN_WALKING_WITHOUT_DOLPHIN
			pool_splash(false)
			play_zombie_reanim("anim_walk", Reanimation.REANIM_LOOP, 0, 0.0)
			pick_random_speed()

func update_zombie_snorkel() -> void:
	var backwards := is_walking_backwards()
	if zombie_phase == PvZ.PHASE_SNORKEL_WALKING and not backwards:
		if x > 700 + PvZ.BOARD_ADDITIONAL_WIDTH and x <= 720 + PvZ.BOARD_ADDITIONAL_WIDTH:
			vel_x = 0.2
			zombie_phase = PvZ.PHASE_SNORKEL_INTO_POOL
			play_zombie_reanim("anim_jumpinpool", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 16.0)
	elif zombie_phase == PvZ.PHASE_SNORKEL_INTO_POOL:
		var r := body_reanim
		altitude = Tod.animate_curve_float(0, 1000, int(r.anim_time * 1000), 0.0, 10.0, Tod.CURVE_LINEAR)
		if r.should_trigger_timed_event(0.83):
			_splash(-47, 73, -10, 115)
		if r.loop_count > 0:
			zombie_phase = PvZ.PHASE_SNORKEL_WALKING_IN_POOL
			in_pool = true
			play_zombie_reanim("anim_swim", Reanimation.REANIM_LOOP_FULL_LAST_FRAME, 0, 12.0)
			pick_random_speed()
	elif zombie_phase == PvZ.PHASE_SNORKEL_WALKING_IN_POOL:
		if not has_head:
			take_damage(1800, 9)
		elif x <= 25 + PvZ.BOARD_ADDITIONAL_WIDTH and not backwards:
			altitude = -90.0
			pos_x -= 15.0
			zombie_phase = PvZ.PHASE_SNORKEL_WALKING
			zombie_height = PvZ.HEIGHT_OUT_OF_POOL
			pool_splash(false)
			start_walk_anim(0)
		elif x > 640 + PvZ.BOARD_ADDITIONAL_WIDTH and backwards:
			altitude = -90.0
			pos_x += 15.0
			zombie_phase = PvZ.PHASE_SNORKEL_WALKING
			zombie_height = PvZ.HEIGHT_OUT_OF_POOL
			pool_splash(false)
			start_walk_anim(0)
		elif is_eating:
			zombie_phase = PvZ.PHASE_SNORKEL_UP_TO_EAT
			play_zombie_reanim("anim_uptoeat", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 24.0)
	elif zombie_phase == PvZ.PHASE_SNORKEL_UP_TO_EAT:
		if not is_eating:
			zombie_phase = PvZ.PHASE_SNORKEL_DOWN_FROM_EAT
			play_zombie_reanim("anim_uptoeat", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, -24.0)
		elif body_reanim.loop_count > 0:
			zombie_phase = PvZ.PHASE_SNORKEL_EATING_IN_POOL
			play_zombie_reanim("anim_eat", Reanimation.REANIM_LOOP, 0, 0.0)
	elif zombie_phase == PvZ.PHASE_SNORKEL_EATING_IN_POOL:
		if not is_eating:
			zombie_phase = PvZ.PHASE_SNORKEL_DOWN_FROM_EAT
			play_zombie_reanim("anim_uptoeat", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, -24.0)
	elif zombie_phase == PvZ.PHASE_SNORKEL_DOWN_FROM_EAT:
		if body_reanim.loop_count > 0:
			zombie_phase = PvZ.PHASE_SNORKEL_WALKING_IN_POOL
			play_zombie_reanim("anim_swim", Reanimation.REANIM_LOOP_FULL_LAST_FRAME, 0, 0.0)
			pick_random_speed()

func update_zombie_jack_in_the_box() -> void:
	if zombie_phase == PvZ.PHASE_JACK_IN_THE_BOX_RUNNING:
		if phase_counter <= 0 and has_head:
			phase_counter = 110
			zombie_phase = PvZ.PHASE_JACK_IN_THE_BOX_POPPING
			stop_zombie_sound()
			App.play_sample("SOUND_BOING")
			play_zombie_reanim("anim_pop", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 28.0)
	elif zombie_phase == PvZ.PHASE_JACK_IN_THE_BOX_POPPING:
		if phase_counter == 80:
			App.play_foley(PvZ.FOLEY_JACK_SURPRISE)
		if phase_counter <= 0:
			App.play_foley(PvZ.FOLEY_EXPLOSION)
			var px := x + Tod.idiv(width, 2)
			var py := y + Tod.idiv(height, 2)
			if mind_controlled:
				board.kill_all_zombies_in_radius(row, px, py, JACK_IN_THE_BOX_ZOMBIE_RADIUS, 1, true, 127)
			else:
				board.kill_all_zombies_in_radius(row, px, py, JACK_IN_THE_BOX_ZOMBIE_RADIUS, 1, true, 255)
				board.kill_all_plants_in_radius(px, py, JACK_IN_THE_BOX_PLANT_RADIUS)
			App.add_tod_particle(px, py, BoardCore.make_render_order(PvZ.RENDER_LAYER_TOP, 0, 0), PvZ.PARTICLE_JACKEXPLODE)
			board.shake_board(4, -6)
			die_no_loot()
			if App.is_scary_potter_level():
				board.challenge.scary_potter_jack_explode(px, py)

func update_zombie_gargantuar() -> void:
	if zombie_phase == PvZ.PHASE_GARGANTUAR_SMASHING:
		var r := body_reanim
		if r.should_trigger_timed_event(0.64):
			if mind_controlled:
				var z := find_zombie_target()
				if z:
					z.take_damage(1000 if zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR else 500, 0)
			else:
				var p := find_plant_target(ATTACKTYPE_CHEW)
				if p:
					if p.seed_type == PvZ.SEED_SPIKEROCK:
						take_damage(20, 32)
						p.spike_rock_take_damage()
						if p.plant_health <= 0:
							squish_all_in_square(p.plant_col, p.row, ATTACKTYPE_CHEW)
					else:
						squish_all_in_square(p.plant_col, p.row, ATTACKTYPE_CHEW)
				if App.is_scary_potter_level():
					var gx := board.pixel_to_grid_x(int(pos_x), int(pos_y))
					var pot := board.get_scary_pot_at(gx, row)
					if pot:
						board.challenge.scary_potter_open_pot(pot)
				if App.is_izombie_level():
					var brain = board.challenge.izombie_get_brain_target(self)
					if brain:
						board.challenge.izombie_squish_brain(brain)
			App.play_foley(PvZ.FOLEY_THUMP)
			board.shake_board(0, 3)
		if r.loop_count > 0:
			zombie_phase = PvZ.PHASE_ZOMBIE_NORMAL
			start_walk_anim(20)
		return
	var throw_dist := pos_x - 360.0 - PvZ.BOARD_ADDITIONAL_WIDTH
	if zombie_phase == PvZ.PHASE_GARGANTUAR_THROWING:
		var r := body_reanim
		if r.should_trigger_timed_event(0.74):
			has_object = false
			reanim_show_prefix("Zombie_imp", Reanimation.RENDER_GROUP_HIDDEN)
			reanim_show_track("Zombie_gargantuar_whiterope", Reanimation.RENDER_GROUP_HIDDEN)
			App.play_foley(PvZ.FOLEY_SWING)
			var imp := board.add_zombie(PvZ.ZOMBIE_IMP, from_wave, true)
			if imp == null:
				return
			var min_throw := 40.0
			if board.stage_has_roof():
				throw_dist -= 180.0
				min_throw = -140.0
			if throw_dist < min_throw:
				throw_dist = min_throw
			elif throw_dist > 140.0:
				throw_dist -= Tod.rand_range_float(0.0, 100.0)
			imp.pos_x = pos_x - 133.0
			imp.pos_y = get_pos_y_based_on_row(row)
			imp.set_row(row)
			imp.variant = false
			imp.altitude = 88.0
			imp.render_order = render_order + 1
			imp.zombie_phase = PvZ.PHASE_IMP_GETTING_THROWN
			imp.scale_zombie = scale_zombie
			imp.body_health = int(imp.body_health * (scale_zombie * scale_zombie))
			imp.body_max_health = int(imp.body_max_health * (scale_zombie * scale_zombie))
			if mind_controlled:
				imp.pos_x = pos_x + width
				imp.start_mind_controlled()
				imp.vel_x = -3.0
			else:
				imp.vel_x = 3.0
			imp.chilled_counter = chilled_counter
			imp.vel_z = 0.5 * (throw_dist / imp.vel_x) * THOWN_ZOMBIE_GRAVITY
			imp.play_zombie_reanim("anim_thrown", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 18.0)
			imp.update_reanim()
			App.play_foley(PvZ.FOLEY_IMP)
		if r.loop_count > 0:
			zombie_phase = PvZ.PHASE_ZOMBIE_NORMAL
			start_walk_anim(20)
		return
	if is_immobilizied() or not has_head:
		return
	if has_object and body_health < Tod.idiv(body_max_health, 2) and throw_dist > 40.0:
		zombie_phase = PvZ.PHASE_GARGANTUAR_THROWING
		play_zombie_reanim("anim_throw", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 24.0)
		return
	var do_smash := false
	if find_plant_target(ATTACKTYPE_CHEW):
		do_smash = true
	elif App.is_scary_potter_level():
		if board.get_scary_pot_at(board.pixel_to_grid_x(int(pos_x), int(pos_y)), row):
			do_smash = true
	elif App.is_izombie_level():
		if board.challenge.izombie_get_brain_target(self):
			do_smash = true
	if do_smash:
		zombie_phase = PvZ.PHASE_GARGANTUAR_SMASHING
		App.play_foley(PvZ.FOLEY_LOW_GROAN)
		play_zombie_reanim("anim_smash", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 16.0)

func update_zombie_imp() -> void:
	if zombie_phase == PvZ.PHASE_IMP_GETTING_THROWN:
		vel_z -= THOWN_ZOMBIE_GRAVITY
		altitude += vel_z
		pos_x -= vel_x
		var dy := get_pos_y_based_on_row(row) - pos_y
		pos_y += dy
		altitude += dy
		if altitude <= 0.0:
			altitude = 0.0
			zombie_phase = PvZ.PHASE_IMP_LANDING
			play_zombie_reanim("anim_land", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 24.0)
	elif zombie_phase == PvZ.PHASE_IMP_LANDING:
		if body_reanim.loop_count > 0:
			zombie_phase = PvZ.PHASE_ZOMBIE_NORMAL
			start_walk_anim(0)

# ================================================================ zombotany
func update_zombie_pea_head() -> void:
	if not has_head:
		return
	if phase_counter == 35:
		special_head_reanim.play_reanim("anim_shooting", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 35.0)
	elif phase_counter == 0:
		special_head_reanim.play_reanim("anim_head_idle", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 15.0)
		App.play_foley(PvZ.FOLEY_THROW)
		var t := Reanimation.Transform.new()
		body_reanim.get_current_transform(body_reanim.find_track_index("anim_head1"), t)
		var ox := pos_x + t.tx - 9.0
		var oy := pos_y + t.ty + 6.0 - altitude
		if mind_controlled:
			ox += 90.0 * scale_zombie
			var proj := board.add_projectile(int(ox), int(oy), render_order, row, PvZ.PROJECTILE_PEA)
			proj.damage_range_flags = 1
		else:
			var proj := board.add_projectile(int(ox), int(oy), render_order, row, PvZ.PROJECTILE_ZOMBIE_PEA)
			proj.motion_type = PvZ.MOTION_BACKWARDS
		phase_counter = 150

func burn_row(the_row: int) -> void:
	for z in board.zombies.duplicate():
		if z.dead:
			continue
		if (z.zombie_type == PvZ.ZOMBIE_BOSS or z.row == the_row) and z.effected_by_damage(127):
			z.remove_cold_effects()
			z.apply_burn()
	for gi in board.grid_items:
		if not gi.dead and gi.grid_y == the_row and gi.grid_item_type == PvZ.GRIDITEM_LADDER:
			gi.grid_item_die()
	var boss := board.get_boss_zombie()
	if boss and boss.fireball_row == the_row:
		boss.boss_destroy_iceball_in_row(the_row)

func update_zombie_jalapeno_head() -> void:
	if not has_head:
		return
	if phase_counter == 0:
		App.play_foley(PvZ.FOLEY_JALAPENO_IGNITE)
		App.play_foley(PvZ.FOLEY_JUICY)
		board.do_fwoosh(row)
		board.shake_board(3, -4)
		if mind_controlled:
			burn_row(row)
		else:
			for p in board.plants.duplicate():
				if not p.dead and p.row == row and not p.not_on_ground():
					board.plants_eaten += 1
					p.die()
		die_no_loot()

func _zombotany_shoot() -> void:
	App.play_foley(PvZ.FOLEY_THROW)
	var t := Reanimation.Transform.new()
	body_reanim.get_current_transform(body_reanim.find_track_index("anim_head1"), t)
	var ox := pos_x + t.tx - 9.0
	var oy := pos_y + t.ty + 6.0 - altitude
	if mind_controlled:
		ox += 90.0 * scale_zombie
		var proj := board.add_projectile(int(ox), int(oy), render_order, row, PvZ.PROJECTILE_PEA)
		proj.damage_range_flags = 1
	else:
		var proj := board.add_projectile(int(ox), int(oy), render_order, row, PvZ.PROJECTILE_ZOMBIE_PEA)
		proj.motion_type = PvZ.MOTION_BACKWARDS

func update_zombie_gatling_head() -> void:
	if not has_head:
		return
	if phase_counter == 100:
		special_head_reanim.play_reanim("anim_shooting", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 38.0)
	elif phase_counter == 18 or phase_counter == 35 or phase_counter == 51 or phase_counter == 68:
		_zombotany_shoot()
	elif phase_counter == 0:
		special_head_reanim.play_reanim("anim_head_idle", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 15.0)
		phase_counter = 150

func _squash_dest_x() -> int:
	var dest_x := board.grid_to_pixel_x(board.pixel_to_grid_x_keep_on_board(x, y), row)
	if mind_controlled:
		var z := find_zombie_target()
		if z:
			dest_x = int(z.zombie_target_lead_x(0.0))
		else:
			dest_x = int(dest_x + 90.0 * scale_zombie)
	return dest_x

func update_zombie_squash_head() -> void:
	if has_head and is_eating and zombie_phase == PvZ.PHASE_SQUASH_PRE_LAUNCH:
		stop_eating()
		play_zombie_reanim("anim_idle", Reanimation.REANIM_LOOP, 20, 12.0)
		has_head = false
		var head := special_head_reanim
		head.play_reanim("anim_jumpup", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 24.0)
		head.render_order = render_order + 1
		head.set_position(pos_x + 6.0, pos_y - 21.0)
		Attachment.detach_on(body_reanim.get_track_instance("anim_head1"))
		head.override_scale(0.75, 0.75)
		head.overlay_matrix.x.y = 0.0
		zombie_phase = PvZ.PHASE_SQUASH_RISING
		phase_counter = 95
	if zombie_phase == PvZ.PHASE_SQUASH_RISING:
		var dest_x := _squash_dest_x()
		var px := Tod.animate_curve(50, 20, phase_counter, 0, int(dest_x - pos_x), Tod.CURVE_EASE_IN_OUT)
		var py := Tod.animate_curve(50, 20, phase_counter, 0, -20, Tod.CURVE_EASE_IN_OUT)
		special_head_reanim.set_position(pos_x + px + 6.0, pos_y + py - 21.0)
		if phase_counter == 0:
			special_head_reanim.play_reanim("anim_jumpdown", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 60.0)
			zombie_phase = PvZ.PHASE_SQUASH_FALLING
			phase_counter = 10
	if zombie_phase == PvZ.PHASE_SQUASH_FALLING:
		var py := Tod.animate_curve(10, 0, phase_counter, -20, 74, Tod.CURVE_LINEAR)
		var dest_x := _squash_dest_x()
		special_head_reanim.set_position(pos_x + 6.0 + dest_x - pos_x, pos_y - 21.0 + py)
		if phase_counter == 2:
			if mind_controlled:
				var attack := Rect2i(dest_x - 73, int(pos_y + 4), 65, 90)
				for z in board.zombies.duplicate():
					if z.dead:
						continue
					if (z.row == row or z.zombie_type == PvZ.ZOMBIE_BOSS) and z.effected_by_damage(13):
						if LawnCommon.get_rect_overlap(attack, z.get_zombie_rect()) > (-20 if z.zombie_type == PvZ.ZOMBIE_FOOTBALL else 0):
							z.take_damage(1800, 18)
			else:
				squish_all_in_square(board.pixel_to_grid_x_keep_on_board(x, y), row, ATTACKTYPE_CHEW)
		if phase_counter == 0:
			zombie_phase = PvZ.PHASE_SQUASH_DONE_FALLING
			phase_counter = 100
			board.shake_board(1, 4)
			App.play_foley(PvZ.FOLEY_THUMP)
	if zombie_phase == PvZ.PHASE_SQUASH_DONE_FALLING and phase_counter == 0:
		special_head_reanim.die()
		special_head_reanim = null
		take_damage(1800, 9)

# ================================================================ bobsled
func bobsled_crash() -> void:
	altitude = 0.0
	zombie_rect = Rect2i(36, 0, 42, 115)
	zombie_phase = PvZ.PHASE_BOBSLED_CRASHING
	phase_counter = BOBSLED_CRASH_TIME
	start_walk_anim(0)
	var leader := body_reanim
	for i in NUM_BOBSLED_FOLLOWERS:
		var f: Zombie = follower_zombies[i]
		if f == null:
			continue
		f.zombie_phase = PvZ.PHASE_BOBSLED_CRASHING
		f.phase_counter = BOBSLED_CRASH_TIME
		f.pos_y = get_pos_y_based_on_row(row)
		f.altitude = 0.0
		f.start_walk_anim(0)
		var fr := rv(f.body_reanim)
		if fr:
			f.vel_x = vel_x
			fr.anim_time = Tod.rand_range_float(0.0, 1.0)
			fr.anim_rate = leader.anim_rate

func update_zombie_bobsled() -> void:
	if zombie_phase == PvZ.PHASE_BOBSLED_CRASHING:
		if phase_counter == 0:
			zombie_phase = PvZ.PHASE_ZOMBIE_NORMAL
			if get_bobsled_position() == 0:
				for i in NUM_BOBSLED_FOLLOWERS:
					var f: Zombie = follower_zombies[i]
					if f:
						f.related_zombie = null
						f.pick_random_speed()
					follower_zombies[i] = null
				pick_random_speed()
		return
	if zombie_phase == PvZ.PHASE_BOBSLED_SLIDING:
		if phase_counter == 0:
			zombie_phase = PvZ.PHASE_BOBSLED_BOARDING
			play_zombie_reanim("anim_jump", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 20.0)
	else:
		if zombie_phase != PvZ.PHASE_BOBSLED_BOARDING:
			return
		var counter := int(body_reanim.anim_time * 50.0)
		var position := get_bobsled_position()
		if position == 1 or position == 3:
			altitude = Tod.animate_curve_float(0, 50, counter, 8.0, 18.0, Tod.CURVE_LINEAR)
		else:
			altitude = Tod.animate_curve_float(0, 50, counter, -9.0, 18.0, Tod.CURVE_LINEAR)
	board.ice_timer[row] = maxi(500, board.ice_timer[row])
	if pos_x + 10.0 < board.ice_min_x[row] and get_bobsled_position() == 0:
		take_damage(6, 8)

# ================================================================ digger
func digger_lose_axe() -> void:
	if zombie_phase == PvZ.PHASE_DIGGER_TUNNELING:
		zombie_phase = PvZ.PHASE_DIGGER_TUNNELING_PAUSE_WITHOUT_AXE
		phase_counter = 200
		set_anim_rate(0.0)
		update_anim_speed()
		Attachment.detach_cross_fade_particle_type(self, PvZ.PARTICLE_DIGGER_TUNNEL, "")
		stop_zombie_sound()
	has_object = false
	reanim_show_track("Zombie_digger_pickaxe", Reanimation.RENDER_GROUP_HIDDEN)
	reanim_show_track("Zombie_digger_dirt", Reanimation.RENDER_GROUP_HIDDEN)

func _digger_dirt() -> void:
	App.add_tod_particle(pos_x + 60.0, pos_y + 118.0, render_order + 1, PvZ.PARTICLE_DIGGER_RISE)
	var dirt := App.add_reanimation(pos_x + 13.0, pos_y + 97.0, render_order + 1, PvZ.REANIM_DIGGER_DIRT)
	dirt.anim_rate = 24.0

func update_zombie_digger() -> void:
	match zombie_phase:
		PvZ.PHASE_DIGGER_TUNNELING:
			if pos_x < 10.0 + PvZ.BOARD_ADDITIONAL_WIDTH:
				altitude = -120.0
				zombie_phase = PvZ.PHASE_DIGGER_RISING
				phase_counter = 130
				play_zombie_reanim("anim_drill", Reanimation.REANIM_LOOP, 0, 20.0)
				App.play_foley(PvZ.FOLEY_DIRT_RISE)
				App.play_foley(PvZ.FOLEY_WAKEUP)
				Attachment.detach_cross_fade_particle_type(self, PvZ.PARTICLE_DIGGER_TUNNEL, "")
				stop_zombie_sound()
				_digger_dirt()
		PvZ.PHASE_DIGGER_RISING:
			if phase_counter > 40:
				altitude = Tod.animate_curve(130, 40, phase_counter, -120, 20, Tod.CURVE_EASE_OUT)
			else:
				altitude = Tod.animate_curve(30, 0, phase_counter, 20, 0, Tod.CURVE_EASE_IN)
			if phase_counter == 30:
				play_zombie_reanim("anim_landing", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 12.0)
			if phase_counter == 0:
				altitude = 0.0
				zombie_phase = PvZ.PHASE_DIGGER_STUNNED
				play_zombie_reanim("anim_dizzy", Reanimation.REANIM_LOOP, 10, 12.0)
		PvZ.PHASE_DIGGER_TUNNELING_PAUSE_WITHOUT_AXE:
			if phase_counter == 150:
				add_attached_reanim(23, 93, PvZ.REANIM_ZOMBIE_SURPRISE)
			if phase_counter == 0:
				altitude = -120.0
				zombie_phase = PvZ.PHASE_DIGGER_RISE_WITHOUT_AXE
				phase_counter = 130
				play_zombie_reanim("anim_landing", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 0.0)
				App.play_foley(PvZ.FOLEY_DIRT_RISE)
				_digger_dirt()
		PvZ.PHASE_DIGGER_RISE_WITHOUT_AXE:
			if phase_counter > 40:
				altitude = Tod.animate_curve(130, 40, phase_counter, -120, 20, Tod.CURVE_EASE_OUT)
			else:
				altitude = Tod.animate_curve(30, 0, phase_counter, 20, 0, Tod.CURVE_EASE_IN)
			if phase_counter == 30:
				play_zombie_reanim("anim_landing", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 12.0)
			if phase_counter == 0:
				altitude = 0.0
				zombie_phase = PvZ.PHASE_DIGGER_WALKING_WITHOUT_AXE
				start_walk_anim(20)
		PvZ.PHASE_DIGGER_STUNNED:
			if body_reanim.loop_count > 1:
				zombie_phase = PvZ.PHASE_DIGGER_WALKING
				start_walk_anim(20)

# ================================================================ dancers
func summon_backup_dancer(the_row: int, px: int) -> Zombie:
	if not board.row_can_have_zombie_type(the_row, PvZ.ZOMBIE_BACKUP_DANCER):
		return null
	var z := board.add_zombie(PvZ.ZOMBIE_BACKUP_DANCER, from_wave)
	if z == null:
		return null
	z.pos_x = px
	z.pos_y = get_pos_y_based_on_row(the_row)
	z.set_row(the_row)
	z.x = int(z.pos_x)
	z.y = int(z.pos_y)
	z.altitude = ZOMBIE_BACKUP_DANCER_RISE_HEIGHT
	z.zombie_phase = PvZ.PHASE_DANCER_RISING
	z.phase_counter = 150
	z.related_zombie = self
	z.set_anim_rate(0.0)
	z.mind_controlled = mind_controlled
	var ppx := int(z.pos_x) + 64
	var ppy := int(z.pos_y) + 110
	if z.is_on_high_ground():
		ppy -= PvZ.HIGH_GROUND_HEIGHT
	App.add_tod_particle(ppx, ppy, BoardCore.make_render_order(PvZ.RENDER_LAYER_PARTICLE, the_row, 0), PvZ.PARTICLE_DANCER_RISE)
	App.play_foley(PvZ.FOLEY_GRAVESTONE_RUMBLE)
	return z

func summon_backup_dancers() -> void:
	if not has_head:
		return
	for i in NUM_BACKUP_DANCERS:
		if zv(follower_zombies[i]) == null:
			var r := row
			var px := int(pos_x)
			match i:
				0: r = row - 1
				1: r = row + 1
				2: px = int(pos_x - 100)
				3: px = int(pos_x + 100)
			follower_zombies[i] = summon_backup_dancer(r, px)

func needs_more_backup_dancers() -> bool:
	for i in NUM_BACKUP_DANCERS:
		if zv(follower_zombies[i]) == null:
			if i == 0 and not board.row_can_have_zombie_type(row - 1, PvZ.ZOMBIE_BACKUP_DANCER):
				continue
			if i == 1 and not board.row_can_have_zombie_type(row + 1, PvZ.ZOMBIE_BACKUP_DANCER):
				continue
			return true
	return false

func play_zombie_reanim(track_name: String, loop: int, blend_time: int, rate: float) -> void:
	var r := rv(body_reanim)
	if r == null:
		return
	r.play_reanim(track_name, loop, blend_time, rate)
	if rate != 0.0:
		original_anim_rate = rate
	update_anim_speed()

func _apply_dancer_phase(dancer_phase: int) -> void:
	if dancer_phase == zombie_phase:
		return
	match dancer_phase:
		PvZ.PHASE_DANCER_DANCING_LEFT:
			zombie_phase = dancer_phase
			play_zombie_reanim("anim_walk", Reanimation.REANIM_LOOP, 10, 0.0)
		PvZ.PHASE_DANCER_WALK_TO_RAISE:
			zombie_phase = dancer_phase
			play_zombie_reanim("anim_armraise", Reanimation.REANIM_LOOP, 10, 18.0)
			body_reanim.anim_time = 0.6
		PvZ.PHASE_DANCER_RAISE_LEFT_1, PvZ.PHASE_DANCER_RAISE_RIGHT_1, PvZ.PHASE_DANCER_RAISE_LEFT_2, PvZ.PHASE_DANCER_RAISE_RIGHT_2:
			zombie_phase = dancer_phase
			play_zombie_reanim("anim_armraise", Reanimation.REANIM_LOOP, 10, 18.0)

func update_zombie_backup_dancer() -> void:
	if is_eating:
		return
	if zombie_phase == PvZ.PHASE_DANCER_RISING:
		altitude = Tod.animate_curve(150, 0, phase_counter, ZOMBIE_BACKUP_DANCER_RISE_HEIGHT, 0, Tod.CURVE_LINEAR)
		if phase_counter != 0:
			return
		if is_on_high_ground():
			altitude = PvZ.HIGH_GROUND_HEIGHT
	_apply_dancer_phase(get_dancer_phase())

func update_zombie_dancer() -> void:
	if is_eating:
		return
	if summon_counter > 0:
		summon_counter -= 1
		if summon_counter == 0:
			if get_dancer_frame() == 12 and has_head and pos_x < 700.0 + PvZ.BOARD_ADDITIONAL_WIDTH:
				zombie_phase = PvZ.PHASE_DANCER_SNAPPING_FINGERS_WITH_LIGHT
				play_zombie_reanim("anim_point", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 24.0)
			else:
				summon_counter = 1
	if zombie_phase == PvZ.PHASE_DANCER_DANCING_IN:
		if has_head and phase_counter == 0:
			zombie_phase = PvZ.PHASE_DANCER_SNAPPING_FINGERS
			play_zombie_reanim("anim_point", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 24.0)
			pick_random_speed()
	elif zombie_phase == PvZ.PHASE_DANCER_SNAPPING_FINGERS or zombie_phase == PvZ.PHASE_DANCER_SNAPPING_FINGERS_WITH_LIGHT:
		if body_reanim.loop_count > 0:
			if zombie_phase == PvZ.PHASE_DANCER_SNAPPING_FINGERS and board.count_zombies_on_screen() <= 15:
				App.play_foley(PvZ.FOLEY_DANCER)
			summon_backup_dancers()
			zombie_phase = PvZ.PHASE_DANCER_SNAPPING_FINGERS_HOLD
			phase_counter = 200
	else:
		if zombie_phase == PvZ.PHASE_DANCER_SNAPPING_FINGERS_HOLD:
			if phase_counter != 0:
				return
			zombie_phase = PvZ.PHASE_DANCER_DANCING_LEFT
			play_zombie_reanim("anim_walk", Reanimation.REANIM_LOOP, 20, 0.0)
		_apply_dancer_phase(get_dancer_phase())
		if has_head and summon_counter == 0 and needs_more_backup_dancers():
			summon_counter = 100

func update_zombie_rise_from_grave() -> void:
	if in_pool:
		altitude = Tod.animate_curve(50, 0, phase_counter, -150, -40, Tod.CURVE_LINEAR) * scale_zombie
	else:
		altitude = Tod.animate_curve(50, 0, phase_counter, -200, 0, Tod.CURVE_LINEAR)
	if phase_counter == 0:
		zombie_phase = PvZ.PHASE_ZOMBIE_NORMAL
		if is_on_high_ground():
			altitude = PvZ.HIGH_GROUND_HEIGHT
		if in_pool:
			reanim_ignore_clip_rect("Zombie_duckytube", true)
			reanim_ignore_clip_rect("Zombie_whitewater", true)
			reanim_ignore_clip_rect("Zombie_outerarm_hand", true)
			reanim_ignore_clip_rect("Zombie_innerarm3", true)

func drag_under() -> void:
	zombie_height = PvZ.HEIGHT_DRAGGED_UNDER
	stop_eating()
	reanim_reenable_clipping()

# ================================================================ zombiquarium
func zombiquarium_find_closest_brain() -> bool:
	if board.has_level_award_dropped() or body_health > 150:
		return false
	var closest: GridItem = null
	var closest_dist := 0.0
	for gi in board.grid_items:
		if not gi.dead and gi.grid_item_type == PvZ.GRIDITEM_BRAIN and gi.grid_item_counter >= 15:
			var d := Tod.distance_2d(gi.pos_x + 15.0, gi.pos_y + 15.0, pos_x + 50.0, pos_y + 40.0)
			if closest == null or d < closest_dist:
				closest_dist = d
				closest = gi
	if closest:
		if closest_dist < 50.0:
			closest.grid_item_die()
			App.play_foley(PvZ.FOLEY_SLURP)
			body_health = mini(body_health + 200, body_max_health)
			play_zombie_reanim("anim_aquarium_bite", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 10, 24.0)
			zombie_phase = PvZ.PHASE_ZOMBIQUARIUM_BITE
			phase_counter = 200
			return false
		var ry: float = closest.pos_y + 15.0 - (pos_y + 40.0)
		var rx: float = closest.pos_x + 15.0 - (pos_x + 50.0)
		vel_z = atan2(ry, rx)
		if vel_z < 0.0:
			vel_z += PI * 2
		zombie_phase = PvZ.PHASE_ZOMBIQUARIUM_ACCEL
		return true
	return false

func update_zombiquarium() -> void:
	if is_dead_or_dying():
		return
	var r := rv(body_reanim)
	if zombie_phase == PvZ.PHASE_ZOMBIQUARIUM_BITE:
		if r.loop_count > 0:
			play_zombie_reanim("anim_aquarium_swim", Reanimation.REANIM_LOOP, 20, Tod.rand_range_float(8.0, 10.0))
			zombie_phase = PvZ.PHASE_ZOMBIQUARIUM_DRIFT
			phase_counter = 100
	elif not zombiquarium_find_closest_brain() and phase_counter == 0:
		var hit := Tod.rand_int(7)
		if hit <= 4:
			zombie_phase = PvZ.PHASE_ZOMBIQUARIUM_ACCEL
			vel_z = Tod.rand_range_float(0.0, PI * 2)
			phase_counter = Tod.rand_range_int(300, 1000)
			r.anim_rate = Tod.rand_range_float(15.0, 20.0)
		elif hit == 5:
			zombie_phase = PvZ.PHASE_ZOMBIQUARIUM_BACK_AND_FORTH
			vel_z = 0.0
			phase_counter = Tod.rand_range_int(300, 1000)
			r.anim_rate = Tod.rand_range_float(15.0, 20.0)
		else:
			zombie_phase = PvZ.PHASE_ZOMBIQUARIUM_BACK_AND_FORTH
			vel_z = PI
			phase_counter = Tod.rand_range_int(300, 1000)
			r.anim_rate = Tod.rand_range_float(15.0, 20.0)
	var vx := cos(vel_z)
	var vy := sin(vel_z)
	var oob := false
	if pos_x < 0.0 and vx < 0.0:
		oob = true
	elif pos_x > PvZ.BOARD_WIDTH - 120 and vx > 0.0:
		oob = true
	elif pos_y < 100.0 and vy < 0.0:
		oob = true
	elif pos_y > PvZ.BOARD_HEIGHT - 200 and vy > 0.0:
		oob = true
	var max_speed := 0.5
	if oob:
		max_speed = vel_x * 0.3
		phase_counter = mini(100, phase_counter)
	elif zombie_phase == PvZ.PHASE_ZOMBIQUARIUM_ACCEL:
		max_speed = 0.5
	elif zombie_phase == PvZ.PHASE_ZOMBIQUARIUM_BACK_AND_FORTH:
		if pos_x < 200.0 and vx < 0.0:
			vel_z = 0.0
		if pos_x > PvZ.BOARD_WIDTH - 250 and vx > 0.0:
			vel_z = PI
		max_speed = 0.3
	elif zombie_phase == PvZ.PHASE_ZOMBIQUARIUM_DRIFT or zombie_phase == PvZ.PHASE_ZOMBIQUARIUM_BITE:
		max_speed = 0.05
	vel_x = minf(max_speed, vel_x + 0.01)
	vx *= vel_x
	vy *= vel_x
	pos_x += vx
	pos_y += vy
	if not board.has_level_award_dropped():
		if summon_counter > 0:
			summon_counter -= 1
			if summon_counter == 0:
				App.play_foley(PvZ.FOLEY_SPAWN_SUN)
				board.add_coin(x + 50, y + 40, PvZ.COIN_SUN, PvZ.COIN_MOTION_FROM_PLANT)
				summon_counter = Tod.rand_range_int(1000, 1500)
		if zombie_age % 100 == 0:
			take_damage(10, 8)
			if is_dead_or_dying():
				App.play_sample("SOUND_ZOMBAQUARIUM_DIE")

# ================================================================ height updates
func update_zombie_pool() -> void:
	if zombie_height == PvZ.HEIGHT_OUT_OF_POOL:
		altitude += 1
		if zombie_type == PvZ.ZOMBIE_SNORKEL:
			altitude += 1
		if altitude >= 0.0:
			altitude = 0.0
			zombie_height = PvZ.HEIGHT_ZOMBIE_NORMAL
			in_pool = false
	elif zombie_height == PvZ.HEIGHT_IN_TO_POOL:
		altitude -= 1
		var depth := int(-40 * scale_zombie)
		if altitude <= depth:
			altitude = depth
			zombie_height = PvZ.HEIGHT_ZOMBIE_NORMAL
			start_walk_anim(0)
	elif zombie_height == PvZ.HEIGHT_DRAGGED_UNDER:
		altitude -= 1

func update_zombie_high_ground() -> void:
	if zombie_type == PvZ.ZOMBIE_POGO:
		return
	if zombie_height == PvZ.HEIGHT_UP_TO_HIGH_GROUND:
		altitude += 1
		if altitude >= PvZ.HIGH_GROUND_HEIGHT:
			altitude = PvZ.HIGH_GROUND_HEIGHT
			zombie_height = PvZ.HEIGHT_ZOMBIE_NORMAL
	elif zombie_height == PvZ.HEIGHT_DOWN_OFF_HIGH_GROUND:
		altitude -= 1
		if altitude <= 0.0:
			altitude = 0.0
			zombie_height = PvZ.HEIGHT_ZOMBIE_NORMAL
			on_high_ground = false

func update_zombie_falling() -> void:
	altitude -= 1
	if zombie_phase == PvZ.PHASE_POLEVAULTER_PRE_VAULT:
		altitude -= 1
	var ground := 0
	if is_on_high_ground():
		ground = PvZ.HIGH_GROUND_HEIGHT
	if altitude <= ground:
		altitude = ground
		zombie_height = PvZ.HEIGHT_ZOMBIE_NORMAL

func override_particle_scale(ps: TodParticleSystem) -> void:
	if ps:
		ps.override_scale(null, scale_zombie)

func override_particle_color(ps: TodParticleSystem) -> void:
	if ps:
		if mind_controlled:
			ps.override_color(null, ZOMBIE_MINDCONTROLLED_COLOR)
			ps.override_extra_additive_draw(null, true)
		elif chilled_counter > 0 or ice_trap_counter > 0:
			ps.override_color(null, Color8(75, 75, 255, 255))
			ps.override_extra_additive_draw(null, true)

# ================================================================ losing body parts
func drop_flag() -> void:
	if zombie_type != PvZ.ZOMBIE_FLAG or not has_object:
		return
	if rv(special_head_reanim):
		special_head_reanim.die()
	reanim_show_prefix("anim_innerarm", Reanimation.RENDER_GROUP_NORMAL)
	reanim_show_track("Zombie_flaghand", Reanimation.RENDER_GROUP_HIDDEN)
	reanim_show_track("Zombie_innerarm_screendoor", Reanimation.RENDER_GROUP_HIDDEN)
	has_object = false
	var fp := get_track_position("Zombie_flaghand")
	var ps := App.add_tod_particle(fp.x + 6.0, fp.y - 45.0, render_order + 1, PvZ.PARTICLE_ZOMBIE_FLAG)
	override_particle_color(ps)
	override_particle_scale(ps)

func drop_pole() -> void:
	if zombie_type != PvZ.ZOMBIE_POLEVAULTER:
		return
	reanim_show_prefix("Zombie_polevaulter_innerarm", Reanimation.RENDER_GROUP_HIDDEN)
	reanim_show_prefix("Zombie_polevaulter_innerhand", Reanimation.RENDER_GROUP_HIDDEN)
	reanim_show_prefix("Zombie_polevaulter_pole", Reanimation.RENDER_GROUP_HIDDEN)

func can_lose_body_parts() -> bool:
	return zombie_type != PvZ.ZOMBIE_ZAMBONI and zombie_type != PvZ.ZOMBIE_BUNGEE and zombie_type != PvZ.ZOMBIE_CATAPULT \
		and zombie_type != PvZ.ZOMBIE_GARGANTUAR and zombie_type != PvZ.ZOMBIE_REDEYE_GARGANTUAR and zombie_type != PvZ.ZOMBIE_BOSS \
		and zombie_height != PvZ.HEIGHT_ZOMBIQUARIUM and not is_flying() and not is_bobsled_team_with_sled()

func setup_reanim_for_lost_head() -> void:
	reanim_show_prefix("anim_head", Reanimation.RENDER_GROUP_HIDDEN)
	reanim_show_prefix("anim_hair", Reanimation.RENDER_GROUP_HIDDEN)
	reanim_show_prefix("anim_tongue", Reanimation.RENDER_GROUP_HIDDEN)

const _HEAD_IMAGES := {
	PvZ.ZOMBIE_DANCER: "IMAGE_ZOMBIEDANCERHEAD",
	PvZ.ZOMBIE_BACKUP_DANCER: "IMAGE_ZOMBIEBACKUPDANCERHEAD",
	PvZ.ZOMBIE_BOBSLED: "IMAGE_ZOMBIEBOBSLEDHEAD",
	PvZ.ZOMBIE_LADDER: "IMAGE_ZOMBIELADDERHEAD",
	PvZ.ZOMBIE_IMP: "IMAGE_ZOMBIEIMPHEAD",
	PvZ.ZOMBIE_FOOTBALL: "IMAGE_ZOMBIEFOOTBALLHEAD",
	PvZ.ZOMBIE_POLEVAULTER: "IMAGE_ZOMBIEPOLEVAULTERHEAD",
	PvZ.ZOMBIE_SNORKEL: "IMAGE_REANIM_ZOMBIE_SNORKLE_HEAD",
	PvZ.ZOMBIE_DIGGER: "IMAGE_ZOMBIEDIGGERHEAD",
	PvZ.ZOMBIE_DOLPHIN_RIDER: "IMAGE_ZOMBIEDOLPHINRIDERHEAD",
	PvZ.ZOMBIE_YETI: "IMAGE_ZOMBIEYETIHEAD",
}

func drop_head(damage_flags: int) -> void:
	if not can_lose_body_parts() or not has_head:
		return
	if buttered_counter > 0:
		buttered_counter = 0
		update_anim_speed()
	has_head = false
	setup_reanim_for_lost_head()
	if Tod.test_bit(damage_flags, PvZ.DAMAGE_DOESNT_LEAVE_BODY):
		return
	if Zombie.is_zombotany(zombie_type):
		if rv(special_head_reanim):
			special_head_reanim.die()
		special_head_reanim = null
		return
	var order := render_order + 1
	var dp := DrawPosition.new()
	get_draw_pos(dp)
	var px := pos_x + dp.image_offset_x + dp.head_x + 11.0
	var py := pos_y + dp.image_offset_y + dp.head_y + dp.body_y + 21.0
	if body_reanim != null:
		var tp := get_track_position("anim_head1")
		px = tp.x
		py = tp.y
	var effect := PvZ.PARTICLE_ZOMBIE_HEAD
	if zombie_phase == PvZ.PHASE_ZOMBIE_MOWERED:
		effect = PvZ.PARTICLE_MOWERED_ZOMBIE_HEAD
	elif in_pool:
		effect = PvZ.PARTICLE_ZOMBIE_HEAD_POOL
	match zombie_type:
		PvZ.ZOMBIE_DANCER:
			reanim_show_prefix("Zombie_disco_glasses", Reanimation.RENDER_GROUP_HIDDEN)
			reanim_show_prefix("Zombie_disco_chops", Reanimation.RENDER_GROUP_HIDDEN)
			order = render_order - 1
		PvZ.ZOMBIE_BACKUP_DANCER:
			reanim_show_prefix("Zombie_backup_stash", Reanimation.RENDER_GROUP_HIDDEN)
			reanim_show_prefix("Zombie_disco_chops", Reanimation.RENDER_GROUP_HIDDEN)
		PvZ.ZOMBIE_NEWSPAPER:
			effect = PvZ.PARTICLE_ZOMBIE_NEWSPAPER_HEAD
		PvZ.ZOMBIE_POGO:
			pogo_break(damage_flags)
			effect = PvZ.PARTICLE_ZOMBIE_POGO_HEAD
		PvZ.ZOMBIE_BALLOON:
			reanim_show_prefix("anim_hat", Reanimation.RENDER_GROUP_HIDDEN)
			reanim_show_prefix("hat", Reanimation.RENDER_GROUP_HIDDEN)
			effect = PvZ.PARTICLE_ZOMBIE_BALLOON_HEAD
		PvZ.ZOMBIE_POLEVAULTER:
			drop_pole()
		PvZ.ZOMBIE_FLAG:
			drop_flag()
	var ps := App.add_tod_particle(px, py, order, effect)
	override_particle_color(ps)
	override_particle_scale(ps)
	if ps and _HEAD_IMAGES.has(zombie_type):
		ps.override_image(null, Res.get_image(_HEAD_IMAGES[zombie_type]))
	var r := rv(body_reanim)
	if board.mustache_mode and r.track_exists("Zombie_mustache"):
		reanim_show_prefix("Zombie_mustache", Reanimation.RENDER_GROUP_HIDDEN)
		var mps := App.add_tod_particle(px, py, order, PvZ.PARTICLE_ZOMBIE_MUSTACHE)
		override_particle_color(mps)
		override_particle_scale(mps)
		var mimg := r.get_image_override("Zombie_mustache")
		if mps and mimg:
			mps.override_image(null, mimg)
	if board.future_mode:
		var himg := r.get_image_override("anim_head1")
		var fr := -1
		if himg:
			if himg == Res.get_image("IMAGE_REANIM_ZOMBIE_HEAD_SUNGLASSES1"):
				fr = 0
			elif himg == Res.get_image("IMAGE_REANIM_ZOMBIE_HEAD_SUNGLASSES2"):
				fr = 1
			elif himg == Res.get_image("IMAGE_REANIM_ZOMBIE_HEAD_SUNGLASSES3"):
				fr = 2
			elif himg == Res.get_image("IMAGE_REANIM_ZOMBIE_HEAD_SUNGLASSES4"):
				fr = 3
		if fr != -1:
			var sps := App.add_tod_particle(px, py, order, PvZ.PARTICLE_ZOMBIE_SUNGLASS)
			override_particle_color(sps)
			override_particle_scale(sps)
			if sps:
				sps.override_frame(null, fr)
	if board.pinata_mode and zombie_phase != PvZ.PHASE_ZOMBIE_MOWERED:
		App.add_tod_particle(px, py, order, PvZ.PARTICLE_ZOMBIE_PINATA)
		override_particle_scale(ps)
	App.play_foley(PvZ.FOLEY_LIMBS_POP)

const _LOST_ARM_OVERRIDES := {
	PvZ.ZOMBIE_FOOTBALL: ["Zombie_football_leftarm_hand", "Zombie_football_leftarm_upper", "IMAGE_REANIM_ZOMBIE_FOOTBALL_LEFTARM_UPPER2"],
	PvZ.ZOMBIE_NEWSPAPER: ["Zombie_paper_leftarm_lower", "Zombie_paper_leftarm_upper", "IMAGE_REANIM_ZOMBIE_PAPER_LEFTARM_UPPER2"],
	PvZ.ZOMBIE_POLEVAULTER: ["Zombie_polevaulter_outerarm_lower", "Zombie_polevaulter_outerarm_upper", "IMAGE_REANIM_ZOMBIE_POLEVAULTER_OUTERARM_UPPER2"],
	PvZ.ZOMBIE_BALLOON: ["Zombie_outerarm_lower", "Zombie_outerarm_upper", "IMAGE_REANIM_ZOMBIE_BALLOON_OUTERARM_UPPER2"],
	PvZ.ZOMBIE_IMP: ["Zombie_outerarm_lower", "Zombie_imp_outerarm_upper", "IMAGE_REANIM_ZOMBIE_IMP_ARM1_BONE"],
	PvZ.ZOMBIE_DIGGER: ["Zombie_outerarm_lower", "Zombie_digger_outerarm_upper", "IMAGE_REANIM_ZOMBIE_DIGGER_OUTERARM_UPPER2"],
	PvZ.ZOMBIE_BOBSLED: ["Zombie_outerarm_lower", "Zombie_dolphinrider_outerarm_upper", "IMAGE_REANIM_ZOMBIE_BOBSLED_OUTERARM_UPPER2"],
	PvZ.ZOMBIE_JACK_IN_THE_BOX: ["Zombie_jackbox_outerarm_lower", "Zombie_jackbox_outerarm_lower", "IMAGE_REANIM_ZOMBIE_JACKBOX_OUTERARM_LOWER2"],
	PvZ.ZOMBIE_SNORKEL: ["Zombie_outerarm_lower", "Zombie_snorkle_outerarm_upper", "IMAGE_REANIM_ZOMBIE_SNORKLE_OUTERARM_UPPER2"],
	PvZ.ZOMBIE_DOLPHIN_RIDER: ["Zombie_outerarm_lower", "Zombie_dolphinrider_outerarm_upper", "IMAGE_REANIM_ZOMBIE_DOLPHINRIDER_OUTERARM_UPPER2"],
	PvZ.ZOMBIE_DANCER: ["Zombie_disco_outerarm_lower", "Zombie_disco_outerarm_upper", "IMAGE_REANIM_ZOMBIE_DISCO_OUTERARM_UPPER2"],
	PvZ.ZOMBIE_BACKUP_DANCER: ["Zombie_disco_outerarm_lower", "Zombie_disco_outerarm_upper", "IMAGE_REANIM_ZOMBIE_BACKUP_OUTERARM_UPPER2"],
	PvZ.ZOMBIE_LADDER: ["Zombie_outerarm_hand", "Zombie_ladder_outerarm_upper", "IMAGE_REANIM_ZOMBIE_LADDER_OUTERARM_UPPER2"],
	PvZ.ZOMBIE_YETI: ["Zombie_outerarm_hand", "Zombie_yeti_outerarm_upper", "IMAGE_REANIM_ZOMBIE_YETI_OUTERARM_UPPER2"],
}

const _ARM_PARTICLE_IMAGES := {
	PvZ.ZOMBIE_FOOTBALL: "IMAGE_REANIM_ZOMBIE_FOOTBALL_LEFTARM_HAND",
	PvZ.ZOMBIE_NEWSPAPER: "IMAGE_REANIM_ZOMBIE_PAPER_LEFTARM_LOWER",
	PvZ.ZOMBIE_DANCER: "IMAGE_REANIM_ZOMBIE_DISCO_OUTERARM_HAND",
	PvZ.ZOMBIE_BACKUP_DANCER: "IMAGE_REANIM_ZOMBIE_BACKUP_INNERARM_HAND",
	PvZ.ZOMBIE_BOBSLED: "IMAGE_REANIM_ZOMBIE_BOBSLED_OUTERARM_HAND",
	PvZ.ZOMBIE_IMP: "IMAGE_REANIM_ZOMBIE_IMP_ARM2",
	PvZ.ZOMBIE_YETI: "IMAGE_REANIM_ZOMBIE_YETI_OUTERARM_HAND",
	PvZ.ZOMBIE_JACK_IN_THE_BOX: "IMAGE_ZOMBIEJACKBOXARM",
	PvZ.ZOMBIE_DIGGER: "IMAGE_ZOMBIEDIGGERARM",
	PvZ.ZOMBIE_POLEVAULTER: "IMAGE_REANIM_ZOMBIE_OUTERARM_HAND",
	PvZ.ZOMBIE_BALLOON: "IMAGE_REANIM_ZOMBIE_OUTERARM_HAND",
	PvZ.ZOMBIE_DOLPHIN_RIDER: "IMAGE_REANIM_ZOMBIE_OUTERARM_HAND",
	PvZ.ZOMBIE_POGO: "IMAGE_REANIM_ZOMBIE_OUTERARM_HAND",
	PvZ.ZOMBIE_LADDER: "IMAGE_REANIM_ZOMBIE_OUTERARM_HAND",
}

func setup_reanim_for_lost_arm(damage_flags: int) -> void:
	match zombie_type:
		PvZ.ZOMBIE_FOOTBALL:
			reanim_show_prefix("Zombie_football_leftarm_lower", Reanimation.RENDER_GROUP_HIDDEN)
			reanim_show_prefix("Zombie_football_leftarm_hand", Reanimation.RENDER_GROUP_HIDDEN)
		PvZ.ZOMBIE_NEWSPAPER:
			reanim_show_track("Zombie_paper_hands", Reanimation.RENDER_GROUP_HIDDEN)
			reanim_show_track("Zombie_paper_leftarm_lower", Reanimation.RENDER_GROUP_HIDDEN)
		PvZ.ZOMBIE_POLEVAULTER:
			reanim_show_track("Zombie_polevaulter_outerarm_lower", Reanimation.RENDER_GROUP_HIDDEN)
			reanim_show_track("Zombie_outerarm_hand", Reanimation.RENDER_GROUP_HIDDEN)
		PvZ.ZOMBIE_DANCER, PvZ.ZOMBIE_BACKUP_DANCER:
			reanim_show_track("Zombie_disco_outerarm_lower", Reanimation.RENDER_GROUP_HIDDEN)
			reanim_show_track("Zombie_disco_outerhand", Reanimation.RENDER_GROUP_HIDDEN)
			if zombie_type == PvZ.ZOMBIE_DANCER:
				reanim_show_track("Zombie_disco_outerhand_point", Reanimation.RENDER_GROUP_HIDDEN)
		_:
			reanim_show_prefix("Zombie_outerarm_lower", Reanimation.RENDER_GROUP_HIDDEN)
			reanim_show_prefix("Zombie_outerarm_hand", Reanimation.RENDER_GROUP_HIDDEN)
	var dp := DrawPosition.new()
	get_draw_pos(dp)
	var px := pos_x + dp.image_offset_x + 45.0
	var py := pos_y + dp.image_offset_y + dp.body_y + 78.0
	if is_walking_backwards():
		px += 36.0
	var r := rv(body_reanim)
	if r:
		if zombie_type == PvZ.ZOMBIE_POGO:
			var tp := get_track_position("Zombie_outerarm_lower")
			px = tp.x; py = tp.y
			r.set_image_override("Zombie_outerarm_upper", Res.get_image("IMAGE_REANIM_ZOMBIE_POGO_OUTERARM_UPPER2"))
			r.set_image_override("Zombie_pogo_stickhands", Res.get_image("IMAGE_REANIM_ZOMBIE_POGO_STICKHANDS2"))
			r.set_image_override("Zombie_pogo_stick", Res.get_image("IMAGE_REANIM_ZOMBIE_POGO_STICKDAMAGE2"))
			r.set_image_override("Zombie_pogo_stick2", Res.get_image("IMAGE_REANIM_ZOMBIE_POGO_STICK2DAMAGE2"))
		elif zombie_type == PvZ.ZOMBIE_FLAG:
			var tp := get_track_position("Zombie_outerarm_lower")
			px = tp.x; py = tp.y
			r.set_image_override("Zombie_outerarm_upper", Res.get_image("IMAGE_REANIM_ZOMBIE_OUTERARM_UPPER2"))
			var head := rv(special_head_reanim)
			if head:
				head.set_image_override("Zombie_flag", Res.get_image("IMAGE_REANIM_ZOMBIE_FLAG3"))
		elif _LOST_ARM_OVERRIDES.has(zombie_type):
			var o: Array = _LOST_ARM_OVERRIDES[zombie_type]
			var tp := get_track_position(o[0])
			px = tp.x; py = tp.y
			r.set_image_override(o[1], Res.get_image(o[2]))
		else:
			var tp := get_track_position("Zombie_outerarm_lower")
			px = tp.x; py = tp.y
			r.set_image_override("Zombie_outerarm_upper", Res.get_image("IMAGE_REANIM_ZOMBIE_OUTERARM_UPPER2"))
	if not in_pool and not Tod.test_bit(damage_flags, PvZ.DAMAGE_DOESNT_LEAVE_BODY):
		var effect := PvZ.PARTICLE_ZOMBIE_ARM
		if zombie_phase == PvZ.PHASE_ZOMBIE_MOWERED:
			effect = PvZ.PARTICLE_MOWERED_ZOMBIE_ARM
		var ps := App.add_tod_particle(px, py, render_order + 1, effect)
		override_particle_color(ps)
		override_particle_scale(ps)
		if ps and _ARM_PARTICLE_IMAGES.has(zombie_type):
			ps.override_image(null, Res.get_image(_ARM_PARTICLE_IMAGES[zombie_type]))

func drop_arm(damage_flags: int) -> void:
	if not can_lose_body_parts():
		return
	if shield_type == PvZ.SHIELDTYPE_DOOR or shield_type == PvZ.SHIELDTYPE_NEWSPAPER:
		return
	if zombie_phase == PvZ.PHASE_SNORKEL_INTO_POOL or zombie_phase == PvZ.PHASE_DOLPHIN_WALKING or zombie_phase == PvZ.PHASE_DOLPHIN_INTO_POOL \
			or zombie_phase == PvZ.PHASE_DOLPHIN_RIDING or zombie_phase == PvZ.PHASE_DOLPHIN_IN_JUMP or zombie_phase == PvZ.PHASE_NEWSPAPER_READING:
		return
	if not has_arm:
		return
	has_arm = false
	setup_reanim_for_lost_arm(damage_flags)
	App.play_foley(PvZ.FOLEY_LIMBS_POP)

func update_damage_states(damage_flags: int) -> void:
	if not can_lose_body_parts():
		return
	if has_arm and body_health < Tod.idiv(2 * body_max_health, 3) and body_health > 0:
		drop_arm(damage_flags)
	if has_head and body_health < Tod.idiv(body_max_health, 3):
		drop_head(damage_flags)
		drop_loot()
		stop_zombie_sound()
		if board.has_level_award_dropped():
			play_death_anim(damage_flags)
		if zombie_phase == PvZ.PHASE_SNORKEL_WALKING_IN_POOL:
			die_no_loot()

func zombie_target_lead_x(time: float) -> float:
	var speed := vel_x
	if chilled_counter > 0:
		speed *= CHILLED_SPEED_FACTOR
	if is_walking_backwards():
		speed = -speed
	if zombie_not_walking():
		speed = 0.0
	var zr := get_zombie_rect()
	var cur := float(zr.position.x + Tod.idiv(zr.size.x, 2))
	return cur - speed * time

func zombie_not_walking() -> bool:
	if is_eating or is_immobilizied():
		return true
	var p := zombie_phase
	if p == PvZ.PHASE_JACK_IN_THE_BOX_POPPING or p == PvZ.PHASE_NEWSPAPER_MADDENING or p == PvZ.PHASE_GARGANTUAR_THROWING \
			or p == PvZ.PHASE_GARGANTUAR_SMASHING or p == PvZ.PHASE_CATAPULT_LAUNCHING or p == PvZ.PHASE_CATAPULT_RELOADING \
			or p == PvZ.PHASE_DIGGER_RISING or p == PvZ.PHASE_DIGGER_TUNNELING_PAUSE_WITHOUT_AXE or p == PvZ.PHASE_DIGGER_RISE_WITHOUT_AXE \
			or p == PvZ.PHASE_DIGGER_STUNNED or p == PvZ.PHASE_DANCER_SNAPPING_FINGERS or p == PvZ.PHASE_DANCER_SNAPPING_FINGERS_WITH_LIGHT \
			or p == PvZ.PHASE_DANCER_SNAPPING_FINGERS_HOLD or p == PvZ.PHASE_DANCER_RISING or p == PvZ.PHASE_IMP_GETTING_THROWN \
			or p == PvZ.PHASE_IMP_LANDING or p == PvZ.PHASE_LADDER_PLACING or zombie_height == PvZ.HEIGHT_IN_TO_CHIMNEY \
			or zombie_height == PvZ.HEIGHT_GETTING_BUNGEE_DROPPED or zombie_height == PvZ.HEIGHT_ZOMBIQUARIUM \
			or zombie_type == PvZ.ZOMBIE_BUNGEE or zombie_type == PvZ.ZOMBIE_BOSS or p == PvZ.PHASE_DANCER_RAISE_LEFT_1 \
			or p == PvZ.PHASE_DANCER_WALK_TO_RAISE or p == PvZ.PHASE_DANCER_RAISE_RIGHT_1 or p == PvZ.PHASE_DANCER_RAISE_LEFT_2 \
			or p == PvZ.PHASE_DANCER_RAISE_RIGHT_2:
		return true
	if zombie_type == PvZ.ZOMBIE_DANCER or zombie_type == PvZ.ZOMBIE_BACKUP_DANCER:
		var leader: Zombie = self if zombie_type == PvZ.ZOMBIE_DANCER else zv(related_zombie)
		if leader:
			if leader.is_immobilizied() or leader.is_eating:
				return true
			for i in NUM_BACKUP_DANCERS:
				var d := zv(leader.follower_zombies[i])
				if d and (d.is_immobilizied() or d.is_eating):
					return true
	return false

func update_zamboni() -> void:
	if pos_x > 400.0 + PvZ.BOARD_ADDITIONAL_WIDTH and not flat_tires:
		vel_x = Tod.animate_curve_float(700 + PvZ.BOARD_ADDITIONAL_WIDTH, 300 + PvZ.BOARD_ADDITIONAL_WIDTH, int(pos_x), 0.25, 0.05, Tod.CURVE_LINEAR)
	elif flat_tires and vel_x > 0.0005:
		vel_x -= 0.0005
	var ice_x := int(pos_x + 118)
	if board.stage_has_roof():
		ice_x = maxi(ice_x, 500 + PvZ.BOARD_ADDITIONAL_WIDTH)
	else:
		ice_x = maxi(ice_x, 25 + PvZ.BOARD_ADDITIONAL_WIDTH)
	if ice_x < board.ice_min_x[row]:
		board.ice_min_x[row] = ice_x
	if ice_x < PvZ.BOARD_ICE_START:
		board.ice_timer[row] = 3000
		if App.game_mode == PvZ.GAMEMODE_CHALLENGE_BOBSLED_BONANZA:
			board.ice_timer[row] = 0x7FFFFFFF

func update_yeti() -> void:
	if mind_controlled or not has_head or is_dead_or_dying():
		return
	if zombie_phase == PvZ.PHASE_ZOMBIE_NORMAL and phase_counter == 0:
		zombie_phase = PvZ.PHASE_YETI_RUNNING
		has_object = false
		pick_random_speed()

func update_ladder() -> void:
	if mind_controlled or not has_head or is_dead_or_dying():
		return
	if zombie_phase == PvZ.PHASE_LADDER_CARRYING and zombie_height == PvZ.HEIGHT_ZOMBIE_NORMAL:
		if find_plant_target(ATTACKTYPE_LADDER):
			stop_eating()
			zombie_phase = PvZ.PHASE_LADDER_PLACING
			play_zombie_reanim("anim_placeladder", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 10, 24.0)
	elif zombie_phase == PvZ.PHASE_LADDER_PLACING:
		if body_reanim.loop_count > 0:
			var p := find_plant_target(ATTACKTYPE_LADDER)
			if p:
				board.add_a_ladder(p.plant_col, p.row)
				App.play_sample("SOUND_LADDER_ZOMBIE")
				zombie_height = PvZ.HEIGHT_UP_LADDER
				use_ladder_col = p.plant_col
				detach_shield()
			else:
				zombie_phase = PvZ.PHASE_LADDER_CARRYING
				start_walk_anim(0)

func update_zombie_walking() -> void:
	if zombie_not_walking():
		return
	var r := rv(body_reanim)
	if r:
		var speed: float
		if is_bouncing_pogo() or zombie_phase == PvZ.PHASE_BALLOON_FLYING or zombie_phase == PvZ.PHASE_DOLPHIN_RIDING \
				or zombie_phase == PvZ.PHASE_SNORKEL_WALKING_IN_POOL or zombie_type == PvZ.ZOMBIE_CATAPULT:
			speed = vel_x
			if is_moving_at_chilled_speed():
				speed *= CHILLED_SPEED_FACTOR
		elif zombie_type == PvZ.ZOMBIE_ZAMBONI or zombie_phase == PvZ.PHASE_DIGGER_TUNNELING or zombie_phase == PvZ.PHASE_DOLPHIN_IN_JUMP \
				or is_bobsled_team_with_sled() or zombie_phase == PvZ.PHASE_POLEVAULTER_IN_VAULT or zombie_phase == PvZ.PHASE_SNORKEL_INTO_POOL:
			speed = vel_x
		elif r.has_ground_track():
			speed = r.get_ground_velocity() * scale_zombie
		else:
			speed = vel_x
			if is_moving_at_chilled_speed():
				speed *= CHILLED_SPEED_FACTOR
		if is_walking_backwards() or zombie_phase == PvZ.PHASE_DANCER_DANCING_IN:
			pos_x += speed
		else:
			pos_x -= speed
		if zombie_type == PvZ.ZOMBIE_FOOTBALL and from_wave != ZOMBIE_WAVE_WINNER:
			if r.should_trigger_timed_event(0.03):
				App.add_tod_particle(x + 81, y + 106, render_order - 1, PvZ.PARTICLE_DUST_FOOT)
			if r.should_trigger_timed_event(0.61):
				App.add_tod_particle(x + 87, y + 110, render_order - 1, PvZ.PARTICLE_DUST_FOOT)
		if zombie_phase == PvZ.PHASE_POLEVAULTER_PRE_VAULT:
			if r.should_trigger_timed_event(0.16):
				App.add_tod_particle(x + 81, y + 106, render_order - 1, PvZ.PARTICLE_DUST_FOOT)
			if r.should_trigger_timed_event(0.67):
				App.add_tod_particle(x + 87, y + 110, render_order - 1, PvZ.PARTICLE_DUST_FOOT)
	else:
		var do_walk := false
		if zombie_phase == PvZ.PHASE_POLEVAULTER_IN_VAULT or zombie_phase == PvZ.PHASE_DIGGER_TUNNELING or zombie_type == PvZ.ZOMBIE_DANCER \
				or zombie_type == PvZ.ZOMBIE_BACKUP_DANCER or zombie_type == PvZ.ZOMBIE_BOBSLED or zombie_type == PvZ.ZOMBIE_POGO \
				or zombie_type == PvZ.ZOMBIE_DOLPHIN_RIDER or zombie_type == PvZ.ZOMBIE_BALLOON:
			do_walk = true
		elif zombie_type == PvZ.ZOMBIE_SNORKEL and in_pool:
			do_walk = true
		elif frame >= 0 and frame <= 2:
			do_walk = true
		elif frame >= 6 and frame <= 8:
			do_walk = true
		if do_walk:
			var speed := vel_x
			if is_moving_at_chilled_speed():
				speed *= CHILLED_SPEED_FACTOR
			if is_walking_backwards():
				pos_x += speed
			else:
				pos_x -= speed

func is_standing_on_spikeweed() -> Plant:
	if zombie_type == PvZ.ZOMBIE_ZAMBONI or zombie_type == PvZ.ZOMBIE_CATAPULT:
		return null
	var zr := get_zombie_rect()
	for p in board.plants:
		if p.dead:
			continue
		if p.row == row and p.is_spiky() and not p.not_on_ground() and (not on_high_ground or p.is_on_high_ground()):
			if LawnCommon.get_rect_overlap(p.get_plant_attack_rect(PvZ.WEAPON_PRIMARY), zr) > 0:
				return p
	return null

func check_for_zombie_step() -> void:
	if (zombie_type == PvZ.ZOMBIE_ZAMBONI or zombie_type == PvZ.ZOMBIE_CATAPULT) and not flat_tires:
		check_squish(ATTACKTYPE_DRIVE_OVER)

func update_zombie_position() -> void:
	if zombie_type == PvZ.ZOMBIE_BUNGEE or zombie_type == PvZ.ZOMBIE_BOSS or zombie_phase == PvZ.PHASE_RISING_FROM_GRAVE \
			or zombie_height == PvZ.HEIGHT_ZOMBIQUARIUM:
		return
	update_zombie_walking()
	check_for_zombie_step()
	if blowing_away:
		pos_x += 10.0
		if x > 850 + PvZ.BOARD_ADDITIONAL_WIDTH:
			die_with_loot()
			return
	if zombie_height == PvZ.HEIGHT_ZOMBIE_NORMAL:
		var desired := get_pos_y_based_on_row(row)
		if pos_y < desired:
			pos_y += minf(desired - pos_y, 1.0)
		elif pos_y > desired:
			pos_y -= minf(pos_y - desired, 1.0)

func is_on_board() -> bool:
	if from_wave == ZOMBIE_WAVE_CUTSCENE or from_wave == ZOMBIE_WAVE_UI:
		return false
	return true

func update_burn() -> void:
	phase_counter -= 1
	if phase_counter == 0:
		die_with_loot()

func update() -> void:
	zombie_age += 1
	var do_update := false
	if App.game_scene == PvZ.SCENE_LEVEL_INTRO and zombie_type == PvZ.ZOMBIE_BOSS:
		do_update = true
	elif is_on_board() and board.cut_scene.should_run_upsell_board():
		do_update = true
	elif App.game_scene == PvZ.SCENE_PLAYING or not is_on_board() or from_wave == ZOMBIE_WAVE_WINNER:
		do_update = true
	if not do_update:
		return
	if zombie_phase == PvZ.PHASE_ZOMBIE_BURNED:
		update_burn()
	elif zombie_phase == PvZ.PHASE_ZOMBIE_MOWERED:
		update_mowered()
	elif zombie_phase == PvZ.PHASE_ZOMBIE_DYING:
		update_death()
		update_zombie_walking()
	else:
		if phase_counter > 0 and not is_immobilizied():
			phase_counter -= 1
		if App.game_scene == PvZ.SCENE_ZOMBIES_WON:
			update_zombie_chimney()
			update_zombie_walking()
		elif is_on_board():
			update_playing()
		if zombie_type == PvZ.ZOMBIE_BUNGEE:
			update_zombie_bungee()
		if zombie_type == PvZ.ZOMBIE_POGO:
			update_zombie_pogo()
		animate()
	if dead:
		return
	just_got_shot_counter -= 1
	if shield_just_got_shot_counter > 0:
		shield_just_got_shot_counter -= 1
	if shield_recoil_counter > 0:
		shield_recoil_counter -= 1
	if zombie_fade > 0:
		zombie_fade -= 1
		if zombie_fade == 0:
			die_no_loot()
	x = int(pos_x)
	y = int(pos_y)
	Attachment.update_and_move(self, pos_x, pos_y)
	update_reanim()

func update_climbing_ladder() -> void:
	var off_ground := altitude
	if on_high_ground:
		off_ground -= PvZ.HIGH_GROUND_HEIGHT
	var ladder_x := board.pixel_to_grid_x_keep_on_board(int(x + 5 + off_ground * 0.5), y)
	if board.get_ladder_at(ladder_x, row) == null:
		zombie_height = PvZ.HEIGHT_FALLING
		return
	altitude += 0.8
	if vel_x < 0.5:
		pos_x -= 0.5
	var target_h := 90.0
	if on_high_ground:
		target_h += PvZ.HIGH_GROUND_HEIGHT
	if altitude >= target_h:
		zombie_height = PvZ.HEIGHT_FALLING

func update_actions() -> void:
	if zombie_height == PvZ.HEIGHT_UP_LADDER:
		update_climbing_ladder()
	if zombie_height == PvZ.HEIGHT_ZOMBIQUARIUM:
		update_zombiquarium()
	if zombie_height == PvZ.HEIGHT_OUT_OF_POOL or zombie_height == PvZ.HEIGHT_IN_TO_POOL or in_pool:
		update_zombie_pool()
	if zombie_height == PvZ.HEIGHT_UP_TO_HIGH_GROUND or zombie_height == PvZ.HEIGHT_DOWN_OFF_HIGH_GROUND:
		update_zombie_high_ground()
	if zombie_height == PvZ.HEIGHT_FALLING:
		update_zombie_falling()
	if zombie_height == PvZ.HEIGHT_IN_TO_CHIMNEY:
		update_zombie_chimney()
	match zombie_type:
		PvZ.ZOMBIE_POLEVAULTER: update_zombie_polevaulter()
		PvZ.ZOMBIE_CATAPULT: update_zombie_catapult()
		PvZ.ZOMBIE_DOLPHIN_RIDER: update_zombie_dolphin_rider()
		PvZ.ZOMBIE_SNORKEL: update_zombie_snorkel()
		PvZ.ZOMBIE_BALLOON: update_zombie_flyer()
		PvZ.ZOMBIE_NEWSPAPER: update_zombie_newspaper()
		PvZ.ZOMBIE_DIGGER: update_zombie_digger()
		PvZ.ZOMBIE_JACK_IN_THE_BOX: update_zombie_jack_in_the_box()
		PvZ.ZOMBIE_GARGANTUAR, PvZ.ZOMBIE_REDEYE_GARGANTUAR: update_zombie_gargantuar()
		PvZ.ZOMBIE_BOBSLED: update_zombie_bobsled()
		PvZ.ZOMBIE_ZAMBONI: update_zamboni()
		PvZ.ZOMBIE_LADDER: update_ladder()
		PvZ.ZOMBIE_YETI: update_yeti()
		PvZ.ZOMBIE_DANCER: update_zombie_dancer()
		PvZ.ZOMBIE_BACKUP_DANCER: update_zombie_backup_dancer()
		PvZ.ZOMBIE_IMP: update_zombie_imp()
		PvZ.ZOMBIE_PEA_HEAD: update_zombie_pea_head()
		PvZ.ZOMBIE_JALAPENO_HEAD: update_zombie_jalapeno_head()
		PvZ.ZOMBIE_GATLING_HEAD: update_zombie_gatling_head()
		PvZ.ZOMBIE_SQUASH_HEAD: update_zombie_squash_head()

func check_for_board_edge() -> void:
	if is_walking_backwards() and pos_x > PvZ.BOARD_WIDTH + 50:
		die_no_loot()
		return
	var edge := PvZ.BOARD_EDGE
	if zombie_type == PvZ.ZOMBIE_GARGANTUAR or zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR or zombie_type == PvZ.ZOMBIE_POLEVAULTER:
		edge -= 50
	elif zombie_type == PvZ.ZOMBIE_CATAPULT or zombie_type == PvZ.ZOMBIE_FOOTBALL or zombie_type == PvZ.ZOMBIE_ZAMBONI:
		edge -= 75
	elif zombie_type == PvZ.ZOMBIE_BACKUP_DANCER or zombie_type == PvZ.ZOMBIE_DANCER or zombie_type == PvZ.ZOMBIE_SNORKEL:
		edge -= 30
	if x <= edge and has_head:
		if App.is_izombie_level():
			if zombie_fade == -1:
				zombie_fade = 200
		elif App.game_mode != PvZ.GAMEMODE_CHALLENGE_ZOMBIQUARIUM:
			board.zombies_won(self)
	if x <= edge + 70 and not has_head:
		take_damage(1800, 9)

func update_playing() -> void:
	if vs_target:
		return
	groan_counter -= 1
	var count: int = board.zombies.size()
	if groan_counter == 0 and Tod.rand_int(count) == 0 and has_head and zombie_type != PvZ.ZOMBIE_BOSS and not board.has_level_award_dropped():
		var pitch := 0.0
		if App.is_little_trouble_level():
			pitch = Tod.rand_range_float(40.0, 50.0)
		if zombie_type == PvZ.ZOMBIE_GARGANTUAR:
			App.play_foley(PvZ.FOLEY_LOW_GROAN)
		elif variant:
			App.play_foley_pitch(PvZ.FOLEY_BRAINS, pitch)
		elif App.sukhbir_mode:
			App.play_foley_pitch(PvZ.FOLEY_SUKHBIR, pitch)
		else:
			App.play_foley_pitch(PvZ.FOLEY_GROAN, pitch)
		groan_counter = Tod.rand_int(1000) + 500
	if ice_trap_counter > 0:
		ice_trap_counter -= 1
		if ice_trap_counter == 0:
			remove_ice_trap()
			add_attached_particle(75, 106, PvZ.PARTICLE_ICE_TRAP_RELEASE)
	if chilled_counter > 0:
		chilled_counter -= 1
		if chilled_counter == 0:
			update_anim_speed()
	if buttered_counter > 0:
		buttered_counter -= 1
		if buttered_counter == 0:
			remove_butter()
	if zombie_phase == PvZ.PHASE_RISING_FROM_GRAVE:
		update_zombie_rise_from_grave()
		return
	if not is_immobilizied():
		update_actions()
		if dead:
			return
		update_zombie_position()
		if dead:
			return
		check_if_prey_caught()
		check_for_pool()
		check_for_high_ground()
		check_for_board_edge()
		if dead:
			return
	if zombie_type == PvZ.ZOMBIE_BOSS:
		update_boss()
	if not is_dead_or_dying() and from_wave != ZOMBIE_WAVE_WINNER:
		var dying := not has_head
		if zombie_type == PvZ.ZOMBIE_ZAMBONI or zombie_type == PvZ.ZOMBIE_CATAPULT:
			if body_health < 200:
				dying = true
		if dying:
			var dmg := 1
			if zombie_type == PvZ.ZOMBIE_YETI:
				dmg = 10
			if body_max_health >= 500:
				dmg = 3
			if Tod.rand_int(5) == 0:
				take_damage(dmg, 9)

func has_yucky_face_image() -> bool:
	if board.future_mode:
		return false
	return zombie_type in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_PAIL, PvZ.ZOMBIE_FLAG, PvZ.ZOMBIE_DOOR,
		PvZ.ZOMBIE_DUCKY_TUBE, PvZ.ZOMBIE_DANCER, PvZ.ZOMBIE_BACKUP_DANCER, PvZ.ZOMBIE_NEWSPAPER, PvZ.ZOMBIE_POLEVAULTER]

func show_yucky_face(show: bool) -> void:
	var r := rv(body_reanim)
	if r == null:
		return
	if has_yucky_face_image():
		if show:
			r.set_image_override("anim_head1", Res.get_image("IMAGE_REANIM_ZOMBIE_HEAD_GROSSOUT"))
			r.assign_render_group_to_track("anim_head2", Reanimation.RENDER_GROUP_HIDDEN)
			r.assign_render_group_to_track("anim_head_jaw", Reanimation.RENDER_GROUP_HIDDEN)
			r.assign_render_group_to_track("anim_tongue", Reanimation.RENDER_GROUP_HIDDEN)
		elif has_head:
			r.set_image_override("anim_head1", null)
			r.assign_render_group_to_track("anim_head2", Reanimation.RENDER_GROUP_NORMAL)
			r.assign_render_group_to_track("anim_head_jaw", Reanimation.RENDER_GROUP_NORMAL)
			if variant:
				r.assign_render_group_to_track("anim_tongue", Reanimation.RENDER_GROUP_NORMAL)

func _yuck_sound() -> void:
	if board.count_zombies_on_screen() <= 5 and has_head:
		App.play_foley(PvZ.FOLEY_YUCK)
	elif board.count_zombies_on_screen() <= 10 and has_head and Tod.rand_int(2) == 0:
		App.play_foley(PvZ.FOLEY_YUCK)

func update_yucky_face() -> void:
	yucky_face_counter += 1
	if yucky_face_counter > 20 and yucky_face_counter < 170 and not has_yucky_face_image():
		stop_eating()
		yucky_face_counter = 170
		_yuck_sound()
	if yucky_face_counter > 270:
		show_yucky_face(false)
		yucky_face = false
		yucky_face_counter = 0
		return
	if yucky_face_counter == 70:
		stop_eating()
		show_yucky_face(true)
		_yuck_sound()
	if yucky_face_counter == 170:
		start_walk_anim(20)
		var can_up := true
		var can_down := true
		var is_pool: bool = board.plant_row[row] == PvZ.PLANTROW_POOL
		if not board.row_can_have_zombies(row - 1):
			can_up = false
		elif board.plant_row[row - 1] == PvZ.PLANTROW_POOL and not is_pool:
			can_up = false
		elif board.plant_row[row - 1] != PvZ.PLANTROW_POOL and is_pool:
			can_up = false
		if not board.row_can_have_zombies(row + 1):
			can_down = false
		elif board.plant_row[row + 1] == PvZ.PLANTROW_POOL and not is_pool:
			can_down = false
		elif board.plant_row[row + 1] != PvZ.PLANTROW_POOL and is_pool:
			can_down = false
		if can_down and not can_up:
			set_row(row + 1)
		elif not can_down and can_up:
			set_row(row - 1)
		elif can_down and can_up:
			set_row(row + 1 if Tod.rand_int(2) == 0 else row - 1)

func animate_chew_sound() -> void:
	if zombie_phase == PvZ.PHASE_SNORKEL_UP_TO_EAT:
		return
	var p := find_plant_target(ATTACKTYPE_CHEW)
	if p:
		if p.seed_type == PvZ.SEED_HYPNOSHROOM and not p.is_asleep:
			App.play_foley(PvZ.FOLEY_FLOOP)
			p.die()
			start_mind_controlled()
			App.add_tod_particle(pos_x + 60.0, pos_y + 40.0, render_order + 1, PvZ.PARTICLE_MIND_CONTROL)
			try_spawn_level_award()
			vel_x = 0.17
			anim_ticks_per_frame = 18
			update_anim_speed()
			if zombie_type == PvZ.ZOMBIE_DANCER and not App.playing_quickplay:
				App.get_achievement(PvZ.ACHIEVEMENT_DISCO_IS_UNDEAD)
		elif p.seed_type == PvZ.SEED_GARLIC:
			if not yucky_face:
				yucky_face = true
				yucky_face_counter = 0
				update_anim_speed()
				App.play_foley(PvZ.FOLEY_CHOMP)
		elif p.seed_type == PvZ.SEED_WALLNUT or p.seed_type == PvZ.SEED_TALLNUT or p.seed_type == PvZ.SEED_PUMPKINSHELL:
			App.play_foley(PvZ.FOLEY_CHOMP_SOFT)
		else:
			App.play_foley(PvZ.FOLEY_CHOMP)
	elif mind_controlled:
		App.play_foley(PvZ.FOLEY_CHOMP_SOFT)
	else:
		App.play_foley(PvZ.FOLEY_CHOMP)

func animate_chew_effect() -> void:
	if zombie_phase == PvZ.PHASE_SNORKEL_UP_TO_EAT:
		return
	if App.is_izombie_level():
		var brain = board.challenge.izombie_get_brain_target(self)
		if brain:
			brain.transparent_counter = maxi(brain.transparent_counter, 25)
			return
	var p := find_plant_target(ATTACKTYPE_CHEW)
	if p:
		if p.seed_type == PvZ.SEED_WALLNUT or p.seed_type == PvZ.SEED_TALLNUT:
			var order := BoardCore.make_render_order(PvZ.RENDER_LAYER_PROJECTILE, row, 0)
			var dp := DrawPosition.new()
			get_draw_pos(dp)
			var px := pos_x + 37.0
			var py := pos_y + 40.0 + dp.body_y
			if zombie_type == PvZ.ZOMBIE_SNORKEL or zombie_type == PvZ.ZOMBIE_DOLPHIN_RIDER:
				px -= 7.0
				py += 70.0
			elif is_walking_backwards():
				px += 47.0
			elif zombie_type == PvZ.ZOMBIE_BALLOON:
				py += 47.0
			elif zombie_type == PvZ.ZOMBIE_IMP:
				px += 24.0
				py += 40.0
			App.add_tod_particle(px, py, order, PvZ.PARTICLE_WALLNUT_EAT_SMALL)
		p.eaten_flash_countdown = maxi(p.eaten_flash_countdown, 25)

func animate() -> void:
	prev_frame = frame
	if zombie_phase == PvZ.PHASE_JACK_IN_THE_BOX_POPPING or zombie_phase == PvZ.PHASE_NEWSPAPER_MADDENING \
			or zombie_phase == PvZ.PHASE_DIGGER_RISING or zombie_phase == PvZ.PHASE_DIGGER_TUNNELING_PAUSE_WITHOUT_AXE \
			or zombie_phase == PvZ.PHASE_DIGGER_RISE_WITHOUT_AXE or zombie_phase == PvZ.PHASE_DIGGER_STUNNED or is_immobilizied():
		return
	anim_counter += 1
	if yucky_face:
		update_yucky_face()
	if is_eating and has_head:
		var frame_len := 6
		if chilled_counter > 0:
			frame_len = 12
		if anim_counter >= anim_frames * frame_len:
			anim_counter = frame_len
		frame = Tod.idiv(anim_counter, frame_len)
		var r := body_reanim
		if r:
			var left := 0.14
			var right := 0.68
			if zombie_type == PvZ.ZOMBIE_POLEVAULTER:
				left = 0.38; right = 0.8
			elif zombie_type == PvZ.ZOMBIE_NEWSPAPER or zombie_type == PvZ.ZOMBIE_LADDER:
				left = 0.42; right = 0.42
			elif zombie_type == PvZ.ZOMBIE_JACK_IN_THE_BOX:
				left = 0.53; right = 0.53
			elif zombie_type == PvZ.ZOMBIE_BOBSLED:
				left = 0.33; right = 0.83
			elif zombie_type == PvZ.ZOMBIE_IMP:
				left = 0.33; right = 0.79
			if r.should_trigger_timed_event(left) or r.should_trigger_timed_event(right):
				animate_chew_sound()
				animate_chew_effect()
		else:
			if anim_counter == 4 * frame_len:
				animate_chew_sound()
			if anim_counter == 7 * frame_len and not mind_controlled:
				animate_chew_effect()
	else:
		if anim_counter >= anim_frames * anim_ticks_per_frame:
			anim_counter = 0
		frame = Tod.idiv(anim_counter, anim_ticks_per_frame)

func is_walking_backwards() -> bool:
	if mind_controlled:
		return true
	if zombie_height == PvZ.HEIGHT_ZOMBIQUARIUM:
		if vel_z < 1.5707964 or vel_z > 4.712389:
			return true
	if zombie_type == PvZ.ZOMBIE_DIGGER:
		if zombie_phase == PvZ.PHASE_DIGGER_RISING or zombie_phase == PvZ.PHASE_DIGGER_STUNNED or zombie_phase == PvZ.PHASE_DIGGER_WALKING:
			return true
		elif zombie_phase == PvZ.PHASE_ZOMBIE_DYING or zombie_phase == PvZ.PHASE_ZOMBIE_BURNED or zombie_phase == PvZ.PHASE_ZOMBIE_MOWERED:
			return has_object
		return false
	return zombie_type == PvZ.ZOMBIE_YETI and not has_object

# ================================================================ reanim update / drawing
func update_reanim() -> void:
	var r := rv(body_reanim)
	if r == null or r.dead:
		return
	if zombie_type == PvZ.ZOMBIE_CATAPULT:
		if get_body_damage_index() == 2 or zombie_phase == PvZ.PHASE_ZOMBIE_DYING:
			var pole := r.get_current_track_image("Zombie_catapult_pole")
			if pole == Res.get_image("IMAGE_REANIM_ZOMBIE_CATAPULT_POLE_WITHBALL") and summon_counter != 0:
				r.set_image_override("Zombie_catapult_pole", Res.get_image("IMAGE_REANIM_ZOMBIE_CATAPULT_POLE_DAMAGE_WITHBALL"))
			else:
				r.set_image_override("Zombie_catapult_pole", Res.get_image("IMAGE_REANIM_ZOMBIE_CATAPULT_POLE_DAMAGE"))
		elif summon_counter == 0:
			r.set_image_override("Zombie_catapult_pole", Res.get_image("IMAGE_REANIM_ZOMBIE_CATAPULT_POLE"))
	var dp := DrawPosition.new()
	get_draw_pos(dp)
	var ox := dp.image_offset_x + 15.0
	var oy := dp.image_offset_y + dp.body_y - 28.0 + 20.0
	if (zombie_type == PvZ.ZOMBIE_ZAMBONI or zombie_type == PvZ.ZOMBIE_CATAPULT) and zombie_phase != PvZ.PHASE_ZOMBIE_BURNED:
		if zombie_phase == PvZ.PHASE_ZOMBIE_DYING:
			var shake := Tod.animate_curve_float_time(0.7, 1.0, r.anim_time, 0.0, 1.0, Tod.CURVE_EASE_OUT)
			ox += Tod.rand_range_float(-shake, shake)
			oy += Tod.rand_range_float(-shake, shake)
		elif body_health < 200:
			ox += Tod.rand_range_float(-1.0, 1.0)
			oy += Tod.rand_range_float(-1.0, 1.0)
	if zombie_type == PvZ.ZOMBIE_FOOTBALL and scale_zombie < 1.0:
		oy += 20.0 - scale_zombie * 20.0
	var opposite := is_walking_backwards()
	if zombie_type == PvZ.ZOMBIE_DANCER or zombie_type == PvZ.ZOMBIE_BACKUP_DANCER:
		opposite = false
		if zombie_phase == PvZ.PHASE_DANCER_DANCING_IN or zombie_phase == PvZ.PHASE_DANCER_RAISE_RIGHT_1 or zombie_phase == PvZ.PHASE_DANCER_RAISE_RIGHT_2:
			if not is_eating:
				opposite = true
		if mind_controlled:
			opposite = not opposite
	if opposite:
		ox += 90.0 * scale_zombie
	r.overlay_matrix.x.y = 0.0
	r.overlay_matrix.y.y = 0.0
	r.override_scale(scale_zombie, scale_zombie)
	r.set_position(ox + 30.0 - scale_zombie * 30.0, oy + 120.0 - scale_zombie * 120.0)
	if opposite:
		r.overlay_matrix.x.x = -scale_zombie
	var mowered := rv(mowered_reanim)
	if mowered:
		mowered.update()
		var om := mowered.get_attachment_overlay_matrix(0)
		var bm := r.overlay_matrix
		# m00 m01 m02 / m10 m11 m12 (keeps the decomp's m02 += m11)
		var m00 := om.x.x * bm.x.x
		var m10 := om.x.y * bm.x.x
		var m01 := om.y.x * bm.y.y
		var m11 := om.y.y * bm.y.y
		var m02 := om.origin.x * bm.x.x + bm.y.y
		var m12 := om.origin.y * bm.y.y + bm.origin.y
		r.overlay_matrix = Transform2D(Vector2(m00, m10), Vector2(m01, m11), Vector2(m02, m12))
	r.update()
	r.propogate_color_to_attachments()

func draw_bobsled_reanim(g: Graphics, dp: DrawPosition, before_zombie: bool) -> void:
	var position := get_bobsled_position()
	var draw_front := false
	var draw_back := false
	var leader: Zombie
	if from_wave == ZOMBIE_WAVE_CUTSCENE:
		leader = self
	else:
		if position == -1:
			return
		if position == 0:
			leader = self
		else:
			leader = related_zombie
	if leader == null:
		return
	if from_wave == ZOMBIE_WAVE_CUTSCENE:
		if before_zombie:
			draw_back = true
		else:
			draw_front = true
	elif zombie_phase == PvZ.PHASE_BOBSLED_CRASHING:
		if position == 0 and not before_zombie:
			draw_front = true
			draw_back = true
	elif zombie_phase == PvZ.PHASE_BOBSLED_SLIDING or zombie_phase == PvZ.PHASE_ZOMBIE_BURNED:
		if position == 2 and before_zombie:
			draw_front = true
			draw_back = true
	elif zombie_phase == PvZ.PHASE_BOBSLED_BOARDING:
		if body_reanim.anim_time < 0.5:
			if position == 2 and before_zombie:
				draw_front = true
				draw_back = true
		elif position == 0 and not before_zombie:
			draw_front = true
		elif position == 3 and before_zombie:
			draw_back = true
	var ox := leader.pos_x + dp.image_offset_x - pos_x - 76.0
	var oy := 15.0
	var status: int
	if zombie_phase == PvZ.PHASE_BOBSLED_CRASHING:
		status = 3
		var alpha := Tod.animate_curve(30, 0, phase_counter, 255, 0, Tod.CURVE_LINEAR)
		ox += (BOBSLED_CRASH_TIME - phase_counter) * vel_x / ZOMBIE_LIMP_SPEED_FACTOR
		ox -= Tod.animate_curve_float(BOBSLED_CRASH_TIME, 0, phase_counter, 0.0, 50.0, Tod.CURVE_EASE_OUT)
		oy += Tod.animate_curve_float(BOBSLED_CRASH_TIME, 75, phase_counter, 5.0, 10.0, Tod.CURVE_LINEAR)
		if alpha != 255:
			g.colorize_images = true
			g.color = Color8(255, 255, 255, alpha)
	else:
		status = leader.get_helm_damage_index()
	var img: PvzImage
	if status == 0:
		img = Res.get_image("IMAGE_ZOMBIE_BOBSLED1")
	elif status == 1:
		img = Res.get_image("IMAGE_ZOMBIE_BOBSLED2")
	elif status == 2:
		img = Res.get_image("IMAGE_ZOMBIE_BOBSLED3")
	else:
		img = Res.get_image("IMAGE_ZOMBIE_BOBSLED4")
	if zombie_phase == PvZ.PHASE_ZOMBIE_BURNED:
		g.colorize_images = true
		g.color = Color.BLACK
	var inside := Res.get_image("IMAGE_ZOMBIE_BOBSLED_INSIDE")
	if draw_back and status != 3:
		g.draw_image_f(inside, ox, oy)
	if draw_front:
		g.draw_image_f(img, ox, oy)
	if leader.just_got_shot_counter > 0:
		g.draw_mode = Graphics.DRAWMODE_ADDITIVE
		g.colorize_images = true
		var grey := leader.just_got_shot_counter * 10
		g.color = Color8(grey, grey, grey, 255)
		if draw_back and status != 3:
			g.draw_image_f(inside, ox, oy)
		if draw_front:
			g.draw_image_f(img, ox, oy)
		g.draw_mode = Graphics.DRAWMODE_NORMAL
	g.colorize_images = false

func draw_bungee_reanim(g: Graphics, dp: DrawPosition) -> void:
	var r := body_reanim
	var oy := dp.body_y + dp.image_offset_y + 14.0
	draw_bungee_cord(g, -22, int(oy))
	r.draw(g)
	var dropped := zv(related_zombie)
	if dropped:
		var dg := g.copy()
		dg.trans_y -= altitude
		dg.trans_x += dropped.pos_x - pos_x
		var ddp := DrawPosition.new()
		dropped.get_draw_pos(ddp)
		dropped.draw_reanim(dg, ddp, Reanimation.RENDER_GROUP_NORMAL)
	else:
		var p := plv(target_plant)
		if p:
			var pg := g.copy()
			pg.trans_y += 30.0 - altitude
			if zombie_phase == PvZ.PHASE_BUNGEE_RISING:
				if p.seed_type == PvZ.SEED_SPIKEWEED or p.seed_type == PvZ.SEED_SPIKEROCK:
					pg.trans_y -= 34.0
			if p.plant_col <= 4 and board.stage_has_roof():
				pg.trans_y += 10
			p.draw(pg)
	r.draw_render_group(g, RENDER_GROUP_ARMS)

func draw_bungee_target(g: Graphics) -> void:
	if not is_on_board() or App.is_final_boss_level():
		return
	if zombie_phase == PvZ.PHASE_BUNGEE_HIT_OUCHY or zombie_phase == PvZ.PHASE_BUNGEE_RISING:
		return
	if related_zombie != null:
		return
	var dp := DrawPosition.new()
	get_draw_pos(dp)
	var tx := x + 10.0
	var ty := y + 60.0 + dp.body_y + dp.image_offset_y
	if zombie_phase == PvZ.PHASE_BUNGEE_DIVING or zombie_phase == PvZ.PHASE_BUNGEE_DIVING_SCREAMING:
		tx += Tod.animate_curve_float(BUNGEE_ZOMBIE_HEIGHT, BUNGEE_ZOMBIE_HEIGHT - 400, int(altitude), 30.0, 0.0, Tod.CURVE_LINEAR)
		ty += Tod.animate_curve_float(BUNGEE_ZOMBIE_HEIGHT, BUNGEE_ZOMBIE_HEIGHT - 400, int(altitude), -600.0, 0.0, Tod.CURVE_LINEAR)
	g.draw_image_f(Res.get_image("IMAGE_BUNGEETARGET"), tx, ty + altitude)

func draw_dancer_reanim(g: Graphics, _dp: DrawPosition) -> void:
	var spot := Color.WHITE
	var draw_spot := false
	if zombie_phase != PvZ.PHASE_DANCER_DANCING_IN and zombie_phase != PvZ.PHASE_DANCER_SNAPPING_FINGERS \
			and zombie_phase != PvZ.PHASE_ZOMBIE_NORMAL and zombie_phase != PvZ.PHASE_ZOMBIE_DYING and App.game_scene != PvZ.SCENE_ZOMBIES_WON:
		draw_spot = true
		match (Tod.idiv(zombie_age, 100) * 7 % 5) if zombie_age >= 700 else 0:
			0: spot = Color8(250, 250, 160)
			1: spot = Color8(114, 234, 170)
			2: spot = Color8(216, 126, 202)
			3: spot = Color8(90, 110, 140)
			4: spot = Color8(240, 90, 130)
		g.colorize_images = true
		g.color = spot
		g.tod_draw_image_scaled_f(Res.get_image("IMAGE_SPOTLIGHT2"), -30.0, 60.0, 4.0, 4.0)
		g.colorize_images = false
	body_reanim.draw(g)
	if draw_spot:
		g.colorize_images = true
		g.color = spot
		g.tod_draw_image_scaled_f(Res.get_image("IMAGE_SPOTLIGHT"), -30.0, -480.0, 4.0, 4.0)
		g.colorize_images = false

func draw_reanim(g: Graphics, dp: DrawPosition, base_group: int) -> void:
	var r := rv(body_reanim)
	if r == null:
		return
	if dp.clip_height > CLIP_HEIGHT_LIMIT:
		var dh := 120.0 - dp.clip_height + 71.0
		g.set_clip_rect(dp.image_offset_x - 200.0, dp.image_offset_y + dp.body_y - 78.0, 520, dh)
	var fade_alpha := 255
	if zombie_fade >= 0:
		fade_alpha = clampi(Tod.idiv(255 * zombie_fade, 10), 0, 255)
	var col := Color8(255, 255, 255, fade_alpha)
	var add_col := Color.BLACK
	var enable_add := false
	if zombie_phase == PvZ.PHASE_ZOMBIE_BURNED:
		col = Color8(0, 0, 0, fade_alpha)
	elif zombie_type == PvZ.ZOMBIE_BOSS and zombie_phase != PvZ.PHASE_ZOMBIE_DYING and body_health < Tod.idiv(body_max_health, BOSS_FLASH_HEALTH_FRACTION):
		var grey := Tod.animate_curve(0, 39, board.main_counter % 40, 155, 255, Tod.CURVE_BOUNCE)
		if chilled_counter > 0 or ice_trap_counter > 0:
			var cold := Tod.animate_curve(0, 39, board.main_counter % 40, 65, 75, Tod.CURVE_BOUNCE)
			col = Color8(cold, cold, grey, fade_alpha)
		else:
			col = Color8(grey, grey, grey, fade_alpha)
	elif mind_controlled:
		col = ZOMBIE_MINDCONTROLLED_COLOR
		col.a8 = fade_alpha
		add_col = col
		enable_add = true
	elif chilled_counter > 0 or ice_trap_counter > 0:
		col = Color8(75, 75, 255, fade_alpha)
		add_col = col
		enable_add = true
	elif zombie_height == PvZ.HEIGHT_ZOMBIQUARIUM and body_health < 100:
		col = Color8(100, 150, 25, fade_alpha)
		add_col = col
		enable_add = true
	if just_got_shot_counter > 0 and not is_bobsled_team_with_sled():
		var grey := just_got_shot_counter * 10
		add_col = Tod.color_add(Color8(grey, grey, grey, 255), add_col)
		enable_add = true
	r.color_override = col
	r.extra_additive_color = add_col
	r.enable_extra_additive_draw = enable_add
	if zombie_type == PvZ.ZOMBIE_BOBSLED:
		draw_bobsled_reanim(g, dp, true)
		r.draw_render_group(g, base_group)
		draw_bobsled_reanim(g, dp, false)
	elif zombie_type == PvZ.ZOMBIE_BUNGEE:
		draw_bungee_reanim(g, dp)
	elif zombie_type == PvZ.ZOMBIE_DANCER:
		draw_dancer_reanim(g, dp)
	else:
		r.draw_render_group(g, base_group)
	if shield_type != PvZ.SHIELDTYPE_NONE:
		if zombie_phase == PvZ.PHASE_ZOMBIE_BURNED:
			r.color_override = Color8(0, 0, 0, fade_alpha)
			r.extra_additive_color = Color.BLACK
			r.enable_extra_additive_draw = false
		elif shield_just_got_shot_counter > 0:
			var grey := shield_just_got_shot_counter * 10
			r.color_override = Color8(grey, grey, grey, fade_alpha)
			r.extra_additive_color = Color.WHITE
			r.enable_extra_additive_draw = true
		else:
			r.color_override = Color8(255, 255, 255, fade_alpha)
			r.extra_additive_color = Color.BLACK
			r.enable_extra_additive_draw = false
		var hit_off := 0.0
		if shield_recoil_counter > 0:
			hit_off = Tod.animate_curve_float(12, 0, shield_recoil_counter, 3.0, 0.0, Tod.CURVE_LINEAR)
		g.trans_x += hit_off
		r.draw_render_group(g, RENDER_GROUP_SHIELD)
		g.trans_x -= hit_off
	if shield_type == PvZ.SHIELDTYPE_NEWSPAPER or shield_type == PvZ.SHIELDTYPE_DOOR or shield_type == PvZ.SHIELDTYPE_LADDER:
		r.color_override = col
		r.extra_additive_color = add_col
		r.enable_extra_additive_draw = enable_add
		r.draw_render_group(g, RENDER_GROUP_OVER_SHIELD)
	g.clear_clip_rect()

func get_helm_damage_index() -> int:
	if helm_health < Tod.idiv(helm_max_health, 3):
		return 2
	if helm_health < Tod.idiv(helm_max_health * 2, 3):
		return 1
	return 0

func get_body_damage_index() -> int:
	if zombie_type == PvZ.ZOMBIE_BOSS:
		if body_health < Tod.idiv(body_max_health, 2):
			return 2
		if body_health < Tod.idiv(body_max_health * 4, 5):
			return 1
		return 0
	if body_health < Tod.idiv(body_max_health, 3):
		return 2
	if body_health < Tod.idiv(body_max_health * 2, 3):
		return 1
	return 0

func get_shield_damage_index() -> int:
	if shield_health < Tod.idiv(shield_max_health, 3):
		return 2
	if shield_health < Tod.idiv(shield_max_health * 2, 3):
		return 1
	return 0

func draw_bungee_cord(g: Graphics, offset_x: int, _offset_y: int) -> void:
	var cord := Res.get_image("IMAGE_BUNGEECORD")
	var cel_h := int(cord.get_cel_height() * scale_zombie)
	var tp := get_track_position("Zombie_bungi_body")
	var set_clip := false
	if is_on_board() and App.is_final_boss_level():
		var boss := board.get_boss_zombie()
		if boss:
			var clip_amount := 55
			if boss.zombie_phase == PvZ.PHASE_BOSS_BUNGEES_LEAVE:
				clip_amount = int(Tod.animate_curve_float_time(0.0, 0.2, boss.body_reanim.anim_time, 55.0, 0.0, Tod.CURVE_LINEAR))
			if target_col > boss.target_col:
				g.set_clip_rect(-g.trans_x, clip_amount - g.trans_y, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
				set_clip = true
	var cy := tp.y - cel_h
	while cy > -cel_h - PvZ.BOARD_OFFSET_Y:
		g.tod_draw_image_scaled_f(cord, offset_x + 61.0 - 4.0 / scale_zombie, cy - pos_y, scale_zombie, scale_zombie)
		cy -= cel_h
	if set_clip:
		g.clear_clip_rect()

func get_draw_pos(dp: DrawPosition) -> void:
	dp.image_offset_x = pos_x - x
	dp.image_offset_y = pos_y - y
	if is_eating:
		dp.head_x = 47
		dp.head_y = 4
	else:
		match frame:
			0: dp.head_x = 50; dp.head_y = 2
			1: dp.head_x = 49; dp.head_y = 1
			2: dp.head_x = 49; dp.head_y = 2
			3: dp.head_x = 48; dp.head_y = 4
			4: dp.head_x = 48; dp.head_y = 5
			5: dp.head_x = 48; dp.head_y = 4
			6: dp.head_x = 48; dp.head_y = 2
			7: dp.head_x = 49; dp.head_y = 1
			8: dp.head_x = 49; dp.head_y = 2
			9: dp.head_x = 50; dp.head_y = 4
			10: dp.head_x = 50; dp.head_y = 5
			_: dp.head_x = 50; dp.head_y = 4
	dp.arm_y = Tod.idiv(dp.head_y, 2)
	match zombie_type:
		PvZ.ZOMBIE_FOOTBALL: dp.image_offset_y -= 16.0
		PvZ.ZOMBIE_YETI: dp.image_offset_y -= 20.0
		PvZ.ZOMBIE_CATAPULT:
			dp.image_offset_x -= 25.0
			dp.image_offset_y -= 18.0
		PvZ.ZOMBIE_POGO: dp.image_offset_y += 16.0
		PvZ.ZOMBIE_BALLOON: dp.image_offset_y += 17.0
		PvZ.ZOMBIE_POLEVAULTER:
			dp.image_offset_x -= 6.0
			dp.image_offset_y -= 11.0
		PvZ.ZOMBIE_ZAMBONI:
			dp.image_offset_x += 68.0
			dp.image_offset_y -= 23.0
		PvZ.ZOMBIE_GARGANTUAR, PvZ.ZOMBIE_REDEYE_GARGANTUAR: dp.image_offset_y -= 8.0
		PvZ.ZOMBIE_BOBSLED: dp.image_offset_y -= 12.0
	if zombie_phase == PvZ.PHASE_RISING_FROM_GRAVE:
		dp.body_y = -altitude
		if in_pool:
			dp.clip_height = dp.body_y
		else:
			dp.clip_height = dp.body_y + minf(phase_counter, 40.0)
		if is_on_high_ground():
			dp.body_y -= PvZ.HIGH_GROUND_HEIGHT
		return
	if zombie_type == PvZ.ZOMBIE_DOLPHIN_RIDER:
		dp.body_y = -altitude
		dp.clip_height = CLIP_HEIGHT_OFF
		if zombie_phase == PvZ.PHASE_DOLPHIN_INTO_POOL:
			var t := body_reanim.anim_time
			if t >= 0.56 and t <= 0.65:
				dp.clip_height = 0.0
			elif t >= 0.75:
				dp.clip_height = -altitude - 10.0
		elif zombie_phase == PvZ.PHASE_DOLPHIN_RIDING:
			dp.image_offset_x += 70.0
			if zombie_height == PvZ.HEIGHT_DRAGGED_UNDER:
				dp.clip_height = -altitude - 15.0
			else:
				dp.clip_height = -altitude - 10.0
		elif zombie_phase == PvZ.PHASE_DOLPHIN_IN_JUMP:
			dp.image_offset_x += 70.0 + altitude
			var t := body_reanim.anim_time
			if t <= 0.06:
				dp.clip_height = -altitude - 10.0
			elif t >= 0.5 and t <= 0.76:
				dp.clip_height = -13.0
		elif zombie_phase == PvZ.PHASE_DOLPHIN_WALKING_IN_POOL or zombie_phase == PvZ.PHASE_ZOMBIE_DYING:
			dp.image_offset_y += 50.0
			if zombie_phase == PvZ.PHASE_ZOMBIE_DYING:
				dp.clip_height = -altitude + 44.0
			elif zombie_height == PvZ.HEIGHT_DRAGGED_UNDER:
				dp.clip_height = -altitude + 36.0
		elif zombie_phase == PvZ.PHASE_DOLPHIN_WALKING and zombie_height == PvZ.HEIGHT_OUT_OF_POOL:
			dp.clip_height = -altitude
		elif zombie_phase == PvZ.PHASE_DOLPHIN_WALKING_WITHOUT_DOLPHIN and zombie_height == PvZ.HEIGHT_OUT_OF_POOL:
			dp.clip_height = -altitude
	elif zombie_type == PvZ.ZOMBIE_SNORKEL:
		dp.body_y = -altitude
		dp.clip_height = CLIP_HEIGHT_OFF
		if zombie_phase == PvZ.PHASE_SNORKEL_INTO_POOL:
			if body_reanim.anim_time >= 0.8:
				dp.clip_height = -10.0
		elif in_pool:
			dp.clip_height = -altitude - 5.0
			dp.clip_height += 20.0 - 20.0 * scale_zombie
	elif in_pool:
		dp.body_y = -altitude
		dp.clip_height = -altitude - 7.0
		dp.clip_height += 10.0 - 10.0 * scale_zombie
		if is_eating:
			dp.clip_height += 7.0
	elif zombie_phase == PvZ.PHASE_DANCER_RISING:
		dp.body_y = -altitude
		dp.clip_height = -altitude
		if is_on_high_ground():
			dp.body_y -= PvZ.HIGH_GROUND_HEIGHT
	elif zombie_phase == PvZ.PHASE_DIGGER_RISING or zombie_phase == PvZ.PHASE_DIGGER_RISE_WITHOUT_AXE:
		dp.body_y = -altitude
		if phase_counter > 20:
			dp.clip_height = -altitude
		else:
			dp.clip_height = CLIP_HEIGHT_OFF
	elif zombie_type == PvZ.ZOMBIE_BUNGEE:
		dp.body_y = -altitude
		dp.image_offset_x -= 18.0
		if is_on_high_ground():
			dp.body_y -= PvZ.HIGH_GROUND_HEIGHT
		dp.clip_height = CLIP_HEIGHT_OFF
	else:
		dp.body_y = -altitude
		dp.clip_height = CLIP_HEIGHT_OFF

func get_dancer_frame() -> int:
	if from_wave == ZOMBIE_WAVE_UI or is_immobilizied():
		return 0
	var frame_len := 20
	var frames := 23
	if zombie_phase == PvZ.PHASE_DANCER_DANCING_IN:
		frames = 11
		frame_len = 10
	if board:
		return Tod.idiv(board.main_counter % (frame_len * frames), frame_len)
	return Tod.idiv(App.app_counter % (frame_len * frames), frame_len)

func get_dancer_phase() -> int:
	var f := get_dancer_frame()
	if f <= 11: return PvZ.PHASE_DANCER_DANCING_LEFT
	if f <= 12: return PvZ.PHASE_DANCER_WALK_TO_RAISE
	if f <= 15: return PvZ.PHASE_DANCER_RAISE_RIGHT_1
	if f <= 18: return PvZ.PHASE_DANCER_RAISE_LEFT_1
	if f <= 21: return PvZ.PHASE_DANCER_RAISE_RIGHT_2
	return PvZ.PHASE_DANCER_RAISE_LEFT_2

func draw_ice_trap(g: Graphics, dp: DrawPosition, front: bool) -> void:
	if in_pool or zombie_type == PvZ.ZOMBIE_BOSS:
		return
	var ox := 46.0
	var oy := dp.body_y + 92.0
	var sc := 1.0
	match zombie_type:
		PvZ.ZOMBIE_POGO:
			ox -= 10.0
			oy += 20.0
		PvZ.ZOMBIE_GARGANTUAR, PvZ.ZOMBIE_REDEYE_GARGANTUAR:
			ox -= 20.0
			oy -= 7.0
			sc = 1.6
		PvZ.ZOMBIE_BUNGEE:
			ox -= 45.0
			oy -= 23.0
			sc = 1.2
		PvZ.ZOMBIE_DIGGER:
			ox -= 27.0
		PvZ.ZOMBIE_CATAPULT:
			ox += 32.0
		PvZ.ZOMBIE_BALLOON:
			ox -= 9.0
			oy += 27.0
	g.tod_draw_image_scaled_f(Res.get_image("IMAGE_ICETRAP" if front else "IMAGE_ICETRAP2"), ox, oy, sc, sc)

func draw_butter(g: Graphics, dp: DrawPosition) -> void:
	var ox := pos_x + dp.image_offset_x + dp.head_x + 11.0
	var oy := pos_y + dp.image_offset_y + dp.head_y + dp.body_y + 21.0
	var sc := 1.0
	if zombie_phase == PvZ.PHASE_NEWSPAPER_MADDENING:
		var tp := get_track_position("anim_head_look")
		ox = tp.x; oy = tp.y
	elif zombie_type == PvZ.ZOMBIE_CATAPULT:
		var tp := get_track_position("Zombie_catapult_driver_head")
		ox = tp.x; oy = tp.y
	elif body_reanim != null:
		var tp := get_track_position("anim_head1")
		ox = tp.x; oy = tp.y
	ox -= pos_x + 29.0
	oy -= pos_y + 36.0
	match zombie_type:
		PvZ.ZOMBIE_POGO:
			oy -= 5.0
		PvZ.ZOMBIE_GARGANTUAR, PvZ.ZOMBIE_REDEYE_GARGANTUAR:
			ox -= 5.0
			oy -= 15.0
			sc = 1.2
		PvZ.ZOMBIE_SQUASH_HEAD:
			ox += 6.0
			oy -= 9.0
		PvZ.ZOMBIE_WALLNUT_HEAD:
			ox -= 6.0
			oy -= 1.0
		PvZ.ZOMBIE_TALLNUT_HEAD:
			ox -= 24.0
			oy -= 39.0
	g.tod_draw_image_scaled_f(Res.get_image("IMAGE_REANIM_CORNPULT_BUTTER_SPLAT"), ox, oy, sc, sc)

func draw(g: Graphics) -> void:
	if zombie_height == PvZ.HEIGHT_GETTING_BUNGEE_DROPPED:
		return
	var dp := DrawPosition.new()
	get_draw_pos(dp)
	if App.game_scene == PvZ.SCENE_ZOMBIES_WON and not setup_draw_zombie_won(g):
		return
	if is_on_board() and App.game_scene == PvZ.SCENE_PLAYING and App.game_mode != PvZ.GAMEMODE_CHALLENGE_ZOMBIQUARIUM:
		g.set_clip_rect(-x, -y, PvZ.ZOMBIE_CLIPRECT_WIDTH, PvZ.BOARD_HEIGHT)
	if ice_trap_counter > 0:
		draw_ice_trap(g, dp, false)
	if App.game_mode != PvZ.GAMEMODE_CHALLENGE_INVISIGHOUL or from_wave == ZOMBIE_WAVE_UI:
		if body_reanim != null:
			draw_reanim(g, dp, Reanimation.RENDER_GROUP_NORMAL)
	if ice_trap_counter > 0:
		draw_ice_trap(g, dp, true)
	if buttered_counter > 0:
		draw_butter(g, dp)
	if attachment != null:
		var pg := g.copy()
		make_parent_graphics_frame(pg)
		pg.trans_y += dp.body_y
		if dp.clip_height > CLIP_HEIGHT_LIMIT:
			var dh := 120.0 - dp.clip_height + 21.0
			pg.clip_rect(x + dp.image_offset_x - 400.0, y + dp.image_offset_y - 28.0, 920, dh)
		Attachment.draw_on(self, pg, false)
	g.clear_clip_rect()

# ================================================================ targeting
func can_target_plant(p: Plant, attack_type: int) -> bool:
	if App.is_wallnut_bowling_level() and attack_type != ATTACKTYPE_VAULT:
		return false
	if p.not_on_ground() or p.seed_type == PvZ.SEED_TANGLEKELP:
		return false
	if not in_pool and board.is_pool_square(p.plant_col, p.row):
		return false
	if zombie_phase == PvZ.PHASE_DIGGER_TUNNELING:
		return p.seed_type == PvZ.SEED_POTATOMINE and p.state == PvZ.STATE_NOTREADY
	if p.is_spiky():
		return zombie_type == PvZ.ZOMBIE_GARGANTUAR or zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR or zombie_type == PvZ.ZOMBIE_ZAMBONI \
			or board.is_pool_square(p.plant_col, p.row) or board.get_flower_pot_at(p.plant_col, p.row) != null
	if attack_type == ATTACKTYPE_DRIVE_OVER:
		if p.seed_type == PvZ.SEED_CHERRYBOMB or p.seed_type == PvZ.SEED_JALAPENO or p.seed_type == PvZ.SEED_BLOVER or p.seed_type == PvZ.SEED_SQUASH:
			return false
		if p.seed_type == PvZ.SEED_DOOMSHROOM or p.seed_type == PvZ.SEED_ICESHROOM:
			return p.is_asleep
	if zombie_phase == PvZ.PHASE_LADDER_CARRYING or zombie_phase == PvZ.PHASE_LADDER_PLACING:
		var place := p.seed_type == PvZ.SEED_WALLNUT or p.seed_type == PvZ.SEED_TALLNUT or p.seed_type == PvZ.SEED_PUMPKINSHELL
		if board.get_ladder_at(p.plant_col, p.row):
			place = false
		if (attack_type == ATTACKTYPE_CHEW and place) or (attack_type == ATTACKTYPE_LADDER and not place):
			return false
	if attack_type == ATTACKTYPE_CHEW:
		var top := board.get_top_plant_at(p.plant_col, p.row, PvZ.TOPPLANT_EATING_ORDER)
		if top != p and top and can_target_plant(top, attack_type):
			return false
	if attack_type == ATTACKTYPE_VAULT:
		var top := board.get_top_plant_at(p.plant_col, p.row, PvZ.TOPPLANT_ONLY_NORMAL_POSITION)
		if top != p and top and can_target_plant(top, attack_type):
			return false
	return true

func find_plant_target(attack_type: int) -> Plant:
	var ar := get_zombie_attack_rect()
	for p in board.plants:
		if p.dead:
			continue
		if p.row == row:
			if LawnCommon.get_rect_overlap(ar, p.get_plant_rect()) >= 20 and can_target_plant(p, attack_type):
				return p
	return null

func find_zombie_target() -> Zombie:
	if zombie_phase == PvZ.PHASE_DIGGER_TUNNELING:
		return null
	# Only zombies on the other side (mind controlled or not) can be eaten. In a normal wave there are none, and
	# skipping the scan keeps hundreds of zombies from each checking every other zombie.
	if not board.any_zombie_with_mind_control(not mind_controlled):
		return null
	var ar := get_zombie_attack_rect()
	for z in board.zombies:
		if z.dead:
			continue
		if mind_controlled != z.mind_controlled and not z.is_flying() and z.zombie_phase != PvZ.PHASE_DIGGER_TUNNELING \
				and z.zombie_phase != PvZ.PHASE_BUNGEE_DIVING and z.zombie_phase != PvZ.PHASE_BUNGEE_DIVING_SCREAMING \
				and z.zombie_phase != PvZ.PHASE_BUNGEE_RISING and z.zombie_height != PvZ.HEIGHT_GETTING_BUNGEE_DROPPED \
				and not z.is_dead_or_dying() and z.row == row:
			var overlap := LawnCommon.get_rect_overlap(ar, z.get_zombie_rect())
			if overlap >= 20 or (overlap > 0 and z.is_eating):
				return z
	return null

func squish_all_in_square(gx: int, gy: int, attack_type: int) -> void:
	for p in board.plants.duplicate():
		if p.dead:
			continue
		if p.row == gy and p.plant_col == gx:
			if attack_type == ATTACKTYPE_DRIVE_OVER and p.is_spiky():
				continue
			if p.seed_type != PvZ.SEED_SPIKEROCK:
				board.plants_eaten += 1
				p.squish()

func zamboni_death(damage_flags: int) -> void:
	if Tod.test_bit(damage_flags, PvZ.DAMAGE_SPIKE):
		flat_tires = true
		App.play_foley(PvZ.FOLEY_TIRE_POP)
		zombie_phase = PvZ.PHASE_ZOMBIE_DYING
		App.add_tod_particle(pos_x + 29.0, pos_y + 114.0, render_order + 1, PvZ.PARTICLE_ZAMBONI_TIRE)
		vel_x = 0.0
		if Tod.rand_int(4) == 0 and pos_x < 600.0 + PvZ.BOARD_ADDITIONAL_WIDTH:
			play_zombie_reanim("anim_wheelie2", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 10, 10.0)
			phase_counter = 280
		else:
			var r := rv(body_reanim)
			var ps := App.add_tod_particle(0.0, 0.0, 0, PvZ.PARTICLE_ZAMBONI_SMOKE)
			if ps:
				r.attach_particle_to_track("zombie_zamboni_1", ps, 35.0, 85.0)
			phase_counter = 280
			play_zombie_reanim("anim_wheelie1", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 10, 12.0)
	else:
		App.add_tod_particle(pos_x + 80.0, pos_y + 60.0, render_order + 1, PvZ.PARTICLE_ZAMBONI_EXPLOSION)
		die_with_loot()
		App.play_foley(PvZ.FOLEY_EXPLOSION)

func catapult_death(damage_flags: int) -> void:
	if Tod.test_bit(damage_flags, PvZ.DAMAGE_SPIKE):
		App.play_foley(PvZ.FOLEY_TIRE_POP)
		zombie_phase = PvZ.PHASE_ZOMBIE_DYING
		App.add_tod_particle(pos_x + 29.0, pos_y + 114.0, render_order + 1, PvZ.PARTICLE_ZAMBONI_TIRE)
		vel_x = 0.0
		add_attached_particle(47, 77, PvZ.PARTICLE_ZAMBONI_SMOKE)
		phase_counter = 280
		play_zombie_reanim("anim_bounce", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 10, 12.0)
	else:
		App.add_tod_particle(pos_x + 80.0, pos_y + 60.0, render_order + 1, PvZ.PARTICLE_CATAPULT_EXPLOSION)
		die_with_loot()
		App.play_foley(PvZ.FOLEY_EXPLOSION)

func check_squish(attack_type: int) -> void:
	var ar := get_zombie_attack_rect()
	for p in board.plants:
		if p.dead:
			continue
		if p.row == row:
			if LawnCommon.get_rect_overlap(ar, p.get_plant_rect()) >= 20 and can_target_plant(p, attack_type) and not p.is_spiky():
				squish_all_in_square(p.plant_col, p.row, attack_type)
				break
	if App.is_izombie_level():
		var brain = board.challenge.izombie_get_brain_target(self)
		if brain:
			board.challenge.izombie_squish_brain(brain)

func is_immobilizied() -> bool:
	return ice_trap_counter > 0 or buttered_counter > 0

func is_moving_at_chilled_speed() -> bool:
	if chilled_counter > 0:
		return true
	if zombie_type == PvZ.ZOMBIE_DANCER or zombie_type == PvZ.ZOMBIE_BACKUP_DANCER:
		var leader: Zombie = self if zombie_type == PvZ.ZOMBIE_DANCER else zv(related_zombie)
		if leader:
			if leader.chilled_counter > 0:
				return true
			for i in NUM_BACKUP_DANCERS:
				var d := zv(leader.follower_zombies[i])
				if d and d.chilled_counter > 0:
					return true
	return false

func set_anim_rate(rate: float) -> void:
	original_anim_rate = rate
	apply_anim_rate(rate)

func apply_anim_rate(rate: float) -> void:
	var r := rv(body_reanim)
	if r:
		r.anim_rate = rate * 0.5 if is_moving_at_chilled_speed() else rate

func update_anim_speed() -> void:
	if not is_on_board():
		return
	var r := rv(body_reanim)
	if r == null:
		return
	if is_immobilizied() or (yucky_face and yucky_face_counter < 170):
		apply_anim_rate(0.0)
		return
	if zombie_phase == PvZ.PHASE_SNORKEL_UP_TO_EAT or zombie_phase == PvZ.PHASE_SNORKEL_DOWN_FROM_EAT or is_dead_or_dying():
		apply_anim_rate(original_anim_rate)
		return
	if is_eating:
		if zombie_type in [PvZ.ZOMBIE_POLEVAULTER, PvZ.ZOMBIE_BALLOON, PvZ.ZOMBIE_IMP, PvZ.ZOMBIE_DIGGER, PvZ.ZOMBIE_JACK_IN_THE_BOX, PvZ.ZOMBIE_SNORKEL, PvZ.ZOMBIE_YETI]:
			apply_anim_rate(20.0)
		else:
			apply_anim_rate(36.0)
	else:
		if zombie_not_walking() or is_bobsled_team_with_sled() or zombie_type == PvZ.ZOMBIE_CATAPULT \
				or zombie_phase == PvZ.PHASE_DOLPHIN_RIDING or zombie_phase == PvZ.PHASE_SNORKEL_WALKING_IN_POOL:
			apply_anim_rate(original_anim_rate)
		elif r.track_exists("_ground"):
			var td: Defs.ReanimTrackDef = r.definition.tracks[r.find_track_index("_ground")]
			var dist := td.x[r.frame_start + r.frame_count - 1] - td.x[r.frame_start]
			if dist >= 1e-6:
				var one_over := r.frame_count / dist
				apply_anim_rate(vel_x * one_over * 47.0 / scale_zombie)

func convert_to_normal_zombie() -> void:
	stop_zombie_sound()
	pos_y = get_pos_y_based_on_row(row)
	x = int(pos_x)
	y = int(pos_y)
	zombie_type = PvZ.ZOMBIE_NORMAL
	zombie_phase = PvZ.PHASE_ZOMBIE_NORMAL
	zombie_attack_rect = Rect2i(50, 0, 20, 115)
	anim_frames = 12
	anim_ticks_per_frame = 12
	phase_counter = 0
	pick_random_speed()

func start_eating() -> void:
	if is_eating:
		return
	is_eating = true
	if zombie_phase == PvZ.PHASE_DIGGER_TUNNELING:
		return
	if zombie_phase == PvZ.PHASE_LADDER_CARRYING:
		play_zombie_reanim("anim_laddereat", Reanimation.REANIM_LOOP, 20, 0.0)
	elif zombie_phase == PvZ.PHASE_NEWSPAPER_MAD:
		play_zombie_reanim("anim_eat_nopaper", Reanimation.REANIM_LOOP, 20, 0.0)
	else:
		if zombie_type != PvZ.ZOMBIE_SNORKEL:
			play_zombie_reanim("anim_eat", Reanimation.REANIM_LOOP, 20, 0.0)
		if shield_type == PvZ.SHIELDTYPE_DOOR:
			show_door_arms(false)

func start_walk_anim(blend_time: int) -> void:
	var r := rv(body_reanim)
	if r == null:
		return
	pick_random_speed()
	if zombie_phase == PvZ.PHASE_LADDER_CARRYING:
		play_zombie_reanim("anim_ladderwalk", Reanimation.REANIM_LOOP, blend_time, 0.0)
	elif zombie_phase == PvZ.PHASE_NEWSPAPER_MAD:
		play_zombie_reanim("anim_walk_nopaper", Reanimation.REANIM_LOOP, blend_time, 0.0)
	elif in_pool and zombie_height != PvZ.HEIGHT_IN_TO_POOL and zombie_height != PvZ.HEIGHT_OUT_OF_POOL and r.track_exists("anim_swim"):
		play_zombie_reanim("anim_swim", Reanimation.REANIM_LOOP, blend_time, 0.0)
	elif (zombie_type == PvZ.ZOMBIE_NORMAL or zombie_type == PvZ.ZOMBIE_TRAFFIC_CONE or zombie_type == PvZ.ZOMBIE_PAIL) and board and board.dance_mode:
		play_zombie_reanim("anim_dance", Reanimation.REANIM_LOOP, blend_time, 0.0)
	else:
		var walk_variant := Tod.rand_int(2)
		if zombie_type == PvZ.ZOMBIE_PEA_HEAD or zombie_type == PvZ.ZOMBIE_FLAG:
			walk_variant = 0
		if walk_variant == 0 and r.track_exists("anim_walk2"):
			play_zombie_reanim("anim_walk2", Reanimation.REANIM_LOOP, blend_time, 0.0)
		elif r.track_exists("anim_walk"):
			play_zombie_reanim("anim_walk", Reanimation.REANIM_LOOP, blend_time, 0.0)

func stop_eating() -> void:
	if not is_eating:
		return
	is_eating = false
	var r := rv(body_reanim)
	if zombie_phase == PvZ.PHASE_DIGGER_TUNNELING:
		return
	if r and zombie_type != PvZ.ZOMBIE_SNORKEL:
		start_walk_anim(20)
	if shield_type == PvZ.SHIELDTYPE_DOOR:
		show_door_arms(true)
	update_anim_speed()

func check_if_prey_caught() -> void:
	var p := zombie_phase
	if zombie_type == PvZ.ZOMBIE_BUNGEE or zombie_type == PvZ.ZOMBIE_GARGANTUAR or zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR \
			or zombie_type == PvZ.ZOMBIE_ZAMBONI or zombie_type == PvZ.ZOMBIE_CATAPULT or zombie_type == PvZ.ZOMBIE_BOSS \
			or is_bouncing_pogo() or is_bobsled_team_with_sled() or p == PvZ.PHASE_POLEVAULTER_IN_VAULT \
			or p == PvZ.PHASE_POLEVAULTER_PRE_VAULT or p == PvZ.PHASE_NEWSPAPER_MADDENING or p == PvZ.PHASE_DIGGER_RISING \
			or p == PvZ.PHASE_DIGGER_TUNNELING_PAUSE_WITHOUT_AXE or p == PvZ.PHASE_DIGGER_RISE_WITHOUT_AXE or p == PvZ.PHASE_DIGGER_STUNNED \
			or p == PvZ.PHASE_RISING_FROM_GRAVE or p == PvZ.PHASE_IMP_GETTING_THROWN or p == PvZ.PHASE_IMP_LANDING \
			or p == PvZ.PHASE_DANCER_RISING or p == PvZ.PHASE_DANCER_SNAPPING_FINGERS or p == PvZ.PHASE_DANCER_SNAPPING_FINGERS_WITH_LIGHT \
			or p == PvZ.PHASE_DANCER_SNAPPING_FINGERS_HOLD or p == PvZ.PHASE_DOLPHIN_WALKING or p == PvZ.PHASE_DOLPHIN_WALKING_WITHOUT_DOLPHIN \
			or p == PvZ.PHASE_DOLPHIN_INTO_POOL or p == PvZ.PHASE_DOLPHIN_RIDING or p == PvZ.PHASE_DOLPHIN_IN_JUMP \
			or p == PvZ.PHASE_SNORKEL_INTO_POOL or p == PvZ.PHASE_SNORKEL_WALKING or p == PvZ.PHASE_LADDER_PLACING \
			or p == PvZ.PHASE_JACK_IN_THE_BOX_POPPING or zombie_height == PvZ.HEIGHT_GETTING_BUNGEE_DROPPED \
			or zombie_height == PvZ.HEIGHT_UP_LADDER or zombie_height == PvZ.HEIGHT_IN_TO_POOL or zombie_height == PvZ.HEIGHT_OUT_OF_POOL \
			or is_tangle_kelp_target_or_dragged() or zombie_height == PvZ.HEIGHT_FALLING or not has_head or is_flying():
		return
	var ticks := TICKS_BETWEEN_EATS
	if chilled_counter > 0:
		ticks *= 2
	if zombie_age % ticks != 0:
		return
	var z := find_zombie_target()
	if z:
		eat_zombie(z)
		return
	if not mind_controlled:
		var pl := find_plant_target(ATTACKTYPE_CHEW)
		if pl:
			eat_plant(pl)
			return
	if App.is_izombie_level() and board.challenge.izombie_eat_brain(self):
		return
	if is_eating:
		stop_eating()

func pool_splash(into_pool_sound: bool) -> void:
	var ox := 23.0
	var oy := 78.0
	if zombie_phase == PvZ.PHASE_SNORKEL_WALKING_IN_POOL:
		ox -= 37.0
		oy -= -8.0
	App.add_reanimation(x + ox, y + oy, render_order + 1, PvZ.REANIM_SPLASH).override_scale(0.8, 0.8)
	App.add_tod_particle(x + ox + 37.0, y + oy + 42.0, render_order + 1, PvZ.PARTICLE_PLANTING_POOL)
	if into_pool_sound:
		App.play_foley(PvZ.FOLEY_ZOMBIESPLASH)
	else:
		App.play_foley(PvZ.FOLEY_PLANT_WATER)

func check_for_pool() -> void:
	if not Zombie.zombie_type_can_go_in_pool(zombie_type) or is_flying():
		return
	if zombie_type == PvZ.ZOMBIE_DOLPHIN_RIDER or zombie_type == PvZ.ZOMBIE_SNORKEL:
		return
	if zombie_height == PvZ.HEIGHT_IN_TO_POOL or zombie_height == PvZ.HEIGHT_OUT_OF_POOL:
		return
	var pool_sq := board.is_pool_square(board.pixel_to_grid_x(x + 75, y), row) and board.is_pool_square(board.pixel_to_grid_x(x + 45, y), row) \
		and x < 680 + PvZ.BOARD_ADDITIONAL_WIDTH
	if not in_pool and pool_sq:
		if board.ice_trap_counter > 0:
			ice_trap_counter = board.ice_trap_counter
			apply_chill(true)
		else:
			zombie_height = PvZ.HEIGHT_IN_TO_POOL
			in_pool = true
			pool_splash(true)
	elif in_pool and not pool_sq:
		zombie_height = PvZ.HEIGHT_OUT_OF_POOL
		start_walk_anim(0)
		pool_splash(false)

func is_on_high_ground() -> bool:
	return is_on_board() and board.grid_square_type[board.pixel_to_grid_x_keep_on_board(x + 75, y)][row] == PvZ.GRIDSQUARE_HIGH_GROUND

func check_for_high_ground() -> void:
	if zombie_height != PvZ.HEIGHT_ZOMBIE_NORMAL or zombie_type == PvZ.ZOMBIE_BUNGEE:
		return
	var hg := is_on_high_ground()
	if not on_high_ground and hg:
		zombie_height = PvZ.HEIGHT_UP_TO_HIGH_GROUND
		on_high_ground = true
	elif on_high_ground and not hg:
		zombie_height = PvZ.HEIGHT_DOWN_OFF_HIGH_GROUND

func start_mind_controlled() -> void:
	App.play_sample("SOUND_MINDCONTROLLED")
	mind_controlled = true
	last_portal_x = -1
	if zombie_type == PvZ.ZOMBIE_DANCER:
		for i in NUM_BACKUP_DANCERS:
			follower_zombies[i] = null
	elif zombie_type == PvZ.ZOMBIE_BACKUP_DANCER:
		var leader := zv(related_zombie)
		if leader:
			for i in NUM_BACKUP_DANCERS:
				if leader.follower_zombies[i] == self:
					leader.follower_zombies[i] = null
					break
		related_zombie = null
	else:
		var z := zv(related_zombie)
		if z:
			z.related_zombie = null
			related_zombie = null

func eat_plant(p: Plant) -> void:
	if zombie_phase == PvZ.PHASE_DANCER_DANCING_IN:
		phase_counter = 1
		return
	if yucky_face:
		return
	if board.get_ladder_at(p.plant_col, p.row) and zombie_type != PvZ.ZOMBIE_DIGGER:
		stop_eating()
		if zombie_height == PvZ.HEIGHT_ZOMBIE_NORMAL and use_ladder_col != p.plant_col:
			zombie_height = PvZ.HEIGHT_UP_LADDER
			use_ladder_col = p.plant_col
		return
	start_eating()
	if p.seed_type == PvZ.SEED_JALAPENO or p.seed_type == PvZ.SEED_CHERRYBOMB or p.seed_type == PvZ.SEED_DOOMSHROOM \
			or p.seed_type == PvZ.SEED_ICESHROOM or p.seed_type == PvZ.SEED_HYPNOSHROOM or p.state == PvZ.STATE_FLOWERPOT_INVULNERABLE \
			or p.state == PvZ.STATE_LILYPAD_INVULNERABLE or p.state == PvZ.STATE_SQUASH_LOOK or p.state == PvZ.STATE_SQUASH_PRE_LAUNCH:
		if not p.is_asleep:
			return
	if p.seed_type == PvZ.SEED_POTATOMINE and p.state != PvZ.STATE_NOTREADY:
		return
	var triggered := p.seed_type == PvZ.SEED_BLOVER
	if p.seed_type == PvZ.SEED_ICESHROOM and not p.is_asleep:
		triggered = true
	if triggered:
		p.do_special()
		return
	if chilled_counter > 0 and zombie_age % 2 == 1:
		return
	if App.is_izombie_level() and p.seed_type == PvZ.SEED_SUNFLOWER:
		var before := Tod.idiv(p.plant_health, 40)
		var after := Tod.idiv(p.plant_health - DAMAGE_PER_EAT, 40)
		if after < before or p.plant_health - DAMAGE_PER_EAT <= 0:
			board.add_coin(p.x, p.y, PvZ.COIN_SUN, PvZ.COIN_MOTION_FROM_PLANT)
	p.plant_health -= DAMAGE_PER_EAT
	p.recently_eaten_countdown = 50
	if App.is_izombie_level() and just_got_shot_counter < -500:
		if p.seed_type == PvZ.SEED_WALLNUT or p.seed_type == PvZ.SEED_TALLNUT or p.seed_type == PvZ.SEED_PUMPKINSHELL:
			p.plant_health -= DAMAGE_PER_EAT
	if p.plant_health <= 0:
		App.play_sample("SOUND_GULP")
		board.plants_eaten += 1
		p.die()
		board.challenge.zombie_ate_plant(self, p)
		if board.level >= 2 and board.level <= 4 and App.is_first_time_adventure_mode():
			if p.plant_col > 4 and board.plants.size() < 15 and p.seed_type == PvZ.SEED_PEASHOOTER:
				board.display_advice("[ADVICE_PEASHOOTER_DIED]", PvZ.MESSAGE_STYLE_HINT_TALL_FAST, PvZ.ADVICE_PEASHOOTER_DIED)

func eat_zombie(z: Zombie) -> void:
	z.take_damage(DAMAGE_PER_EAT, 9)
	start_eating()
	if z.body_health <= 0:
		App.play_sample("SOUND_GULP")

func try_spawn_level_award() -> bool:
	if board and board.is_versus():
		return false
	if not is_on_board() or board.has_level_award_dropped() or board.level_complete or dropped_loot:
		return false
	if App.is_final_boss_level():
		if zombie_type != PvZ.ZOMBIE_BOSS:
			return false
	elif App.is_scary_potter_level():
		if not board.challenge.scary_potter_is_completed():
			return false
	elif App.is_continuous_challenge() or board.current_wave < board.num_waves or board.are_enemy_zombies_on_screen():
		return false
	if App.is_whack_a_zombie_level() and board.zombie_count_down > 0:
		return false
	board.level_award_spawned = true
	App.board_result = PvZ.BOARDRESULT_WON
	var zr := get_zombie_rect()
	var cx := zr.position.x + Tod.idiv(zr.size.x, 2)
	var cy := zr.position.y + Tod.idiv(zr.size.y, 2)
	if not board.is_survival_stage_with_repick():
		board.remove_all_zombies()
	var coin_type: int
	var lvl: int = board.level
	if App.playing_quickplay:
		coin_type = PvZ.COIN_NONE
		board.fade_out_level()
	elif App.is_scary_potter_level() and not board.is_final_scary_potter_stage():
		coin_type = PvZ.COIN_NONE
		board.challenge.puzzle_phase_complete(board.pixel_to_grid_x_keep_on_board(int(pos_x + 75), int(pos_y)), row)
	elif App.is_adventure_mode() and lvl <= 50:
		if lvl == 9 or lvl == 19 or lvl == 29 or lvl == 39 or lvl == 49:
			coin_type = PvZ.COIN_NOTE
		elif lvl == 50:
			coin_type = PvZ.COIN_AWARD_MONEY_BAG if App.has_finished_adventure() else PvZ.COIN_AWARD_SILVER_SUNFLOWER
		elif App.has_finished_adventure():
			coin_type = PvZ.COIN_AWARD_MONEY_BAG
		elif lvl == 4:
			coin_type = PvZ.COIN_SHOVEL
		elif lvl == 14:
			coin_type = PvZ.COIN_ALMANAC
		elif lvl == 24:
			coin_type = PvZ.COIN_CARKEYS
		elif lvl == 34:
			coin_type = PvZ.COIN_TACO
		elif lvl == 44:
			coin_type = PvZ.COIN_WATERING_CAN
		else:
			coin_type = PvZ.COIN_FINAL_SEED_PACKET
	elif board.is_survival_stage_with_repick():
		coin_type = PvZ.COIN_NONE
		board.fade_out_level()
	elif board.is_last_stand_stage_with_repick():
		coin_type = PvZ.COIN_NONE
		board.fade_out_level()
		App.play_foley(PvZ.FOLEY_SPAWN_SUN)
		for i in 10:
			board.add_coin(cx + i * 5, cy, PvZ.COIN_SUN, PvZ.COIN_MOTION_COIN)
	elif not App.is_adventure_mode():
		if App.has_beaten_challenge(App.game_mode):
			coin_type = PvZ.COIN_AWARD_MONEY_BAG
		elif App.trophies_need_for_gold_sunflower() == 1:
			coin_type = PvZ.COIN_AWARD_GOLD_SUNFLOWER
		else:
			coin_type = PvZ.COIN_TROPHY
	else:
		coin_type = PvZ.COIN_AWARD_MONEY_BAG
	var motion := PvZ.COIN_MOTION_COIN
	if zombie_type == PvZ.ZOMBIE_BOSS:
		motion = PvZ.COIN_MOTION_FROM_BOSS
	if coin_type != PvZ.COIN_NONE:
		App.play_foley(PvZ.FOLEY_SPAWN_SUN)
		board.add_coin(cx, cy, coin_type, motion)
	dropped_loot = true
	return true

func drop_loot() -> void:
	if not is_on_board():
		return
	AlmanacDialog.almanac_player_defeated_zombie(zombie_type)
	if CustomRuntime.active != null:
		CustomRuntime.active.notify_zombie_died(self)
	if zombie_type == PvZ.ZOMBIE_YETI:
		board.killed_yeti = true
	try_spawn_level_award()
	if dropped_loot or board.has_level_award_dropped() or not board.can_drop_loot():
		return
	dropped_loot = true
	var value: int = _def()[LawnCommon.ZDEF_VALUE]
	if App.is_little_trouble_level() and Tod.rand_int(4) != 0:
		return
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZOMBIQUARIUM or App.is_izombie_level():
		return
	var zr := get_zombie_rect()
	var cx := zr.position.x + Tod.idiv(zr.size.x, 2)
	var cy := zr.position.y + Tod.idiv(zr.size.y, 4)
	if zombie_type == PvZ.ZOMBIE_YETI and not App.playing_quickplay:
		App.play_foley(PvZ.FOLEY_SPAWN_SUN)
		board.add_coin(cx - 20, cy, PvZ.COIN_DIAMOND, PvZ.COIN_MOTION_COIN)
		board.add_coin(cx - 30, cy, PvZ.COIN_DIAMOND, PvZ.COIN_MOTION_COIN)
		board.add_coin(cx - 40, cy, PvZ.COIN_DIAMOND, PvZ.COIN_MOTION_COIN)
		board.add_coin(cx - 50, cy, PvZ.COIN_DIAMOND, PvZ.COIN_MOTION_COIN)
	else:
		board.drop_loot_piece(cx, cy, value)

func die_with_loot() -> void:
	die_no_loot()
	drop_loot()

func bobsled_die() -> void:
	if not is_bobsled_team_with_sled() or not is_on_board():
		return
	var leader: Zombie = self if related_zombie == null else related_zombie
	if not leader.dead:
		leader.die_no_loot()
	for i in NUM_BOBSLED_FOLLOWERS:
		var z: Zombie = leader.follower_zombies[i]
		if z and not z.dead:
			z.die_no_loot()

func bobsled_burn() -> void:
	if not is_bobsled_team_with_sled():
		return
	var leader: Zombie = self if related_zombie == null else related_zombie
	leader.apply_burn()
	for i in NUM_BOBSLED_FOLLOWERS:
		var z: Zombie = leader.follower_zombies[i]
		if z:
			z.die_no_loot()

func bungee_drop_plant() -> void:
	if zombie_phase == PvZ.PHASE_BUNGEE_GRABBING:
		var p := plv(target_plant)
		if p:
			if p.on_bungee_state == PvZ.GETTING_GRABBED_BY_BUNGEE:
				p.on_bungee_state = PvZ.NOT_ON_BUNGEE
			elif p.on_bungee_state == PvZ.RISING_WITH_BUNGEE:
				p.die()
			target_plant = null

func bungee_die() -> void:
	bungee_drop_plant()
	if board:
		var p := plv(target_plant)
		if p and not p.dead:
			board.plants_eaten += 1
			p.die()
	var z := zv(related_zombie)
	if z and not z.dead:
		z.die_no_loot()

func die_no_loot() -> void:
	stop_zombie_sound()
	Attachment.die_on(self)
	if rv(body_reanim):
		body_reanim.die()
	if rv(mowered_reanim):
		mowered_reanim.die()
	if rv(special_head_reanim):
		special_head_reanim.die()
	dead = true
	try_spawn_level_award()
	if zombie_type == PvZ.ZOMBIE_BOBSLED:
		bobsled_die()
	if zombie_type == PvZ.ZOMBIE_BUNGEE:
		bungee_die()
	if zombie_type == PvZ.ZOMBIE_BOSS:
		boss_die()

func play_zombie_appear_sound() -> void:
	if zombie_type == PvZ.ZOMBIE_DOLPHIN_RIDER:
		App.play_foley(PvZ.FOLEY_DOLPHIN_APPEARS)
	elif zombie_type == PvZ.ZOMBIE_BALLOON:
		App.play_foley(PvZ.FOLEY_BALLOONINFLATE)
	elif zombie_type == PvZ.ZOMBIE_ZAMBONI:
		App.play_foley(PvZ.FOLEY_ZAMBONI)

func start_zombie_sound() -> void:
	if playing_song:
		return
	if zombie_phase == PvZ.PHASE_JACK_IN_THE_BOX_RUNNING and has_head:
		App.play_foley(PvZ.FOLEY_JACKINTHEBOX)
		playing_song = true
	elif zombie_phase == PvZ.PHASE_DIGGER_TUNNELING:
		App.play_foley(PvZ.FOLEY_DIGGER)
		playing_song = true

func stop_zombie_sound() -> void:
	if zombie_type == PvZ.ZOMBIE_DANCER or zombie_type == PvZ.ZOMBIE_BACKUP_DANCER:
		var stop := false
		if board:
			for z in board.zombies:
				if z.dead:
					continue
				if z.has_head and not z.is_dead_or_dying() and z.is_on_board() \
						and (z.zombie_type == PvZ.ZOMBIE_DANCER or z.zombie_type == PvZ.ZOMBIE_BACKUP_DANCER):
					stop = true
					break
		if stop:
			App.sound_system.stop_foley(PvZ.FOLEY_DANCER)
	if playing_song:
		playing_song = false
		if zombie_type == PvZ.ZOMBIE_JACK_IN_THE_BOX:
			App.sound_system.stop_foley(PvZ.FOLEY_JACKINTHEBOX)
		elif zombie_type == PvZ.ZOMBIE_DIGGER:
			App.sound_system.stop_foley(PvZ.FOLEY_DIGGER)

func apply_chill(is_ice_trap: bool) -> void:
	if not can_be_chilled():
		return
	if chilled_counter == 0:
		App.play_foley(PvZ.FOLEY_FROZEN)
	var chill := 2000 if is_ice_trap else 1000
	chilled_counter = maxi(chill, chilled_counter)
	update_anim_speed()

func drop_shield(damage_flags: int) -> void:
	if shield_type == PvZ.SHIELDTYPE_NONE:
		return
	if shield_type == PvZ.SHIELDTYPE_DOOR:
		detach_shield()
		if not Tod.test_bit(damage_flags, PvZ.DAMAGE_DOESNT_LEAVE_BODY):
			var tp := get_track_position("anim_screendoor")
			override_particle_scale(App.add_tod_particle(tp.x, tp.y, render_order + 1, PvZ.PARTICLE_ZOMBIE_DOOR))
	elif shield_type == PvZ.SHIELDTYPE_NEWSPAPER:
		stop_eating()
		if yucky_face:
			show_yucky_face(false)
			yucky_face = false
			yucky_face_counter = 0
		zombie_phase = PvZ.PHASE_NEWSPAPER_MADDENING
		play_zombie_reanim("anim_gasp", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 10, 8.0)
		detach_shield()
		if not Tod.test_bit(damage_flags, PvZ.DAMAGE_DOESNT_LEAVE_BODY):
			var tp := get_track_position("Zombie_paper_paper")
			override_particle_scale(App.add_tod_particle(tp.x, tp.y, render_order + 1, PvZ.PARTICLE_ZOMBIE_NEWSPAPER))
		if not Tod.test_bit(damage_flags, PvZ.DAMAGE_DOESNT_LEAVE_BODY) and not Tod.test_bit(damage_flags, PvZ.DAMAGE_BYPASSES_SHIELD):
			App.play_foley(PvZ.FOLEY_NEWSPAPER_RIP)
			add_attached_reanim(-11, 0, PvZ.REANIM_ZOMBIE_SURPRISE)
	elif shield_type == PvZ.SHIELDTYPE_LADDER:
		detach_shield()
		if not Tod.test_bit(damage_flags, PvZ.DAMAGE_DOESNT_LEAVE_BODY):
			override_particle_scale(App.add_tod_particle(pos_x + 31.0, pos_y + 80.0, render_order + 1, PvZ.PARTICLE_ZOMBIE_DOOR if vs_target else PvZ.PARTICLE_ZOMBIE_LADDER))
	shield_type = PvZ.SHIELDTYPE_NONE

func take_shield_damage(damage: int, damage_flags: int) -> int:
	if not Tod.test_bit(damage_flags, PvZ.DAMAGE_DOESNT_CAUSE_FLASH):
		shield_just_got_shot_counter = 25
		if just_got_shot_counter < 0:
			just_got_shot_counter = 0
	if not Tod.test_bit(damage_flags, PvZ.DAMAGE_DOESNT_CAUSE_FLASH) and not Tod.test_bit(damage_flags, PvZ.DAMAGE_HITS_SHIELD_AND_BODY):
		shield_recoil_counter = 12
		if shield_type == PvZ.SHIELDTYPE_DOOR or shield_type == PvZ.SHIELDTYPE_LADDER:
			App.play_foley(PvZ.FOLEY_SHIELD_HIT)
	var before := get_shield_damage_index()
	var actual := mini(shield_health, damage)
	var remaining := damage - actual
	shield_health -= actual
	if shield_health == 0:
		drop_shield(damage_flags)
		return remaining
	var after := get_shield_damage_index()
	if after != before:
		var r := rv(body_reanim)
		if r:
			if shield_type == PvZ.SHIELDTYPE_DOOR and after == 1:
				r.set_image_override("anim_screendoor", Res.get_image("IMAGE_REANIM_ZOMBIE_SCREENDOOR2"))
			elif shield_type == PvZ.SHIELDTYPE_DOOR and after == 2:
				r.set_image_override("anim_screendoor", Res.get_image("IMAGE_REANIM_ZOMBIE_SCREENDOOR3"))
			elif shield_type == PvZ.SHIELDTYPE_NEWSPAPER and after == 1:
				r.set_image_override("Zombie_paper_paper", Res.get_image("IMAGE_REANIM_ZOMBIE_PAPER_PAPER2"))
			elif shield_type == PvZ.SHIELDTYPE_NEWSPAPER and after == 2:
				r.set_image_override("Zombie_paper_paper", Res.get_image("IMAGE_REANIM_ZOMBIE_PAPER_PAPER3"))
			elif shield_type == PvZ.SHIELDTYPE_LADDER and after == 1:
				r.set_image_override("Zombie_ladder_1", Res.get_image("IMAGE_REANIM_ZOMBIE_SCREENDOOR2" if vs_target else "IMAGE_REANIM_ZOMBIE_LADDER_1_DAMAGE1"))
			elif shield_type == PvZ.SHIELDTYPE_LADDER and after == 2:
				r.set_image_override("Zombie_ladder_1", Res.get_image("IMAGE_REANIM_ZOMBIE_SCREENDOOR3" if vs_target else "IMAGE_REANIM_ZOMBIE_LADDER_1_DAMAGE2"))
	return remaining

func drop_helm(damage_flags: int) -> void:
	if helm_type == PvZ.HELMTYPE_NONE:
		return
	var dp := DrawPosition.new()
	get_draw_pos(dp)
	var px := pos_x + dp.image_offset_x + dp.head_x + 14.0
	var py := pos_y + dp.image_offset_y + dp.head_y + dp.body_y + 18.0
	var effect := PvZ.PARTICLE_NONE
	if helm_type == PvZ.HELMTYPE_TRAFFIC_CONE:
		var tp := get_track_position("anim_cone")
		px = tp.x; py = tp.y
		reanim_show_prefix("anim_cone", Reanimation.RENDER_GROUP_HIDDEN)
		reanim_show_prefix("anim_hair", Reanimation.RENDER_GROUP_NORMAL)
		effect = PvZ.PARTICLE_ZOMBIE_TRAFFIC_CONE
	elif helm_type == PvZ.HELMTYPE_PAIL:
		var tp := get_track_position("anim_bucket")
		px = tp.x; py = tp.y
		reanim_show_prefix("anim_bucket", Reanimation.RENDER_GROUP_HIDDEN)
		reanim_show_prefix("anim_hair", Reanimation.RENDER_GROUP_NORMAL)
		effect = PvZ.PARTICLE_ZOMBIE_PAIL
	elif helm_type == PvZ.HELMTYPE_FOOTBALL:
		var tp := get_track_position("zombie_football_helmet")
		px = tp.x; py = tp.y
		reanim_show_prefix("zombie_football_helmet", Reanimation.RENDER_GROUP_HIDDEN)
		reanim_show_prefix("anim_hair", Reanimation.RENDER_GROUP_NORMAL)
		effect = PvZ.PARTICLE_ZOMBIE_HELMET
	elif helm_type == PvZ.HELMTYPE_DIGGER:
		var tp := get_track_position("Zombie_digger_hardhat")
		px = tp.x; py = tp.y
		reanim_show_track("Zombie_digger_hardhat", Reanimation.RENDER_GROUP_HIDDEN)
		effect = PvZ.PARTICLE_ZOMBIE_HEADLIGHT
	elif helm_type == PvZ.HELMTYPE_BOBSLED and not Tod.test_bit(damage_flags, PvZ.DAMAGE_DOESNT_LEAVE_BODY):
		bobsled_crash()
	if not Tod.test_bit(damage_flags, PvZ.DAMAGE_DOESNT_LEAVE_BODY) and effect != PvZ.PARTICLE_NONE:
		override_particle_scale(App.add_tod_particle(px, py, render_order + 1, effect))
	helm_type = PvZ.HELMTYPE_NONE

func take_helm_damage(damage: int, damage_flags: int) -> int:
	if not Tod.test_bit(damage_flags, PvZ.DAMAGE_DOESNT_CAUSE_FLASH):
		just_got_shot_counter = 25
	var before := get_helm_damage_index()
	var actual := mini(helm_health, damage)
	var remaining := damage - actual
	helm_health -= actual
	if Tod.test_bit(damage_flags, PvZ.DAMAGE_FREEZE):
		apply_chill(false)
	if helm_health == 0:
		drop_helm(damage_flags)
		return remaining
	var after := get_helm_damage_index()
	if before != after:
		var r := rv(body_reanim)
		if helm_type == PvZ.HELMTYPE_TRAFFIC_CONE and after == 1 and r:
			r.set_image_override("anim_cone", Res.get_image("IMAGE_REANIM_ZOMBIE_CONE2"))
		elif helm_type == PvZ.HELMTYPE_TRAFFIC_CONE and after == 2 and r:
			r.set_image_override("anim_cone", Res.get_image("IMAGE_REANIM_ZOMBIE_CONE3"))
		elif helm_type == PvZ.HELMTYPE_PAIL and after == 1 and r:
			r.set_image_override("anim_bucket", Res.get_image("IMAGE_REANIM_ZOMBIE_BUCKET2"))
		elif helm_type == PvZ.HELMTYPE_PAIL and after == 2 and r:
			r.set_image_override("anim_bucket", Res.get_image("IMAGE_REANIM_ZOMBIE_BUCKET3"))
		elif helm_type == PvZ.HELMTYPE_DIGGER and after == 1 and r:
			r.set_image_override("Zombie_digger_hardhat", Res.get_image("IMAGE_REANIM_ZOMBIE_DIGGER_HARDHAT2"))
		elif helm_type == PvZ.HELMTYPE_DIGGER and after == 2 and r:
			r.set_image_override("Zombie_digger_hardhat", Res.get_image("IMAGE_REANIM_ZOMBIE_DIGGER_HARDHAT3"))
		elif helm_type == PvZ.HELMTYPE_FOOTBALL and after == 1 and r:
			r.set_image_override("zombie_football_helmet", Res.get_image("IMAGE_REANIM_ZOMBIE_FOOTBALL_HELMET2"))
		elif helm_type == PvZ.HELMTYPE_FOOTBALL and after == 2 and r:
			r.set_image_override("zombie_football_helmet", Res.get_image("IMAGE_REANIM_ZOMBIE_FOOTBALL_HELMET3"))
		elif helm_type == PvZ.HELMTYPE_WALLNUT and after == 1 and rv(special_head_reanim):
			special_head_reanim.set_image_override("anim_face", Res.get_image("IMAGE_REANIM_WALLNUT_CRACKED1"))
		elif helm_type == PvZ.HELMTYPE_WALLNUT and after == 2 and rv(special_head_reanim):
			special_head_reanim.set_image_override("anim_face", Res.get_image("IMAGE_REANIM_WALLNUT_CRACKED2"))
		elif helm_type == PvZ.HELMTYPE_TALLNUT and after == 1 and rv(special_head_reanim):
			special_head_reanim.set_image_override("anim_idle", Res.get_image("IMAGE_REANIM_TALLNUT_CRACKED1"))
		elif helm_type == PvZ.HELMTYPE_TALLNUT and after == 2 and rv(special_head_reanim):
			special_head_reanim.set_image_override("anim_idle", Res.get_image("IMAGE_REANIM_TALLNUT_CRACKED2"))
	return remaining

func take_flying_damage(damage: int, damage_flags: int) -> int:
	if not Tod.test_bit(damage_flags, PvZ.DAMAGE_DOESNT_CAUSE_FLASH):
		just_got_shot_counter = 25
	var actual := mini(flying_health, damage)
	var remaining := damage - actual
	flying_health -= actual
	if flying_health == 0:
		land_flyer(damage_flags)
	return remaining

func take_body_damage(damage: int, damage_flags: int) -> void:
	if not Tod.test_bit(damage_flags, PvZ.DAMAGE_DOESNT_CAUSE_FLASH):
		just_got_shot_counter = 25
	if Tod.test_bit(damage_flags, PvZ.DAMAGE_FREEZE):
		apply_chill(false)
	var origin := body_health
	var before := get_body_damage_index()
	body_health -= damage
	var after := get_body_damage_index()
	if zombie_type == PvZ.ZOMBIE_ZAMBONI:
		var r := body_reanim
		if not Tod.test_bit(damage_flags, PvZ.DAMAGE_DOESNT_CAUSE_FLASH):
			App.play_foley(PvZ.FOLEY_SHIELD_HIT)
		if Tod.test_bit(damage_flags, PvZ.DAMAGE_SPIKE):
			r.set_image_override("Zombie_zamboni_1", Res.get_image("IMAGE_REANIM_ZOMBIE_ZAMBONI_1_DAMAGE2"))
			r.set_image_override("Zombie_zamboni_2", Res.get_image("IMAGE_REANIM_ZOMBIE_ZAMBONI_2_DAMAGE2"))
			zamboni_death(damage_flags)
		elif body_health <= 0:
			zamboni_death(damage_flags)
		elif before != after:
			if after == 1:
				r.set_image_override("Zombie_zamboni_1", Res.get_image("IMAGE_REANIM_ZOMBIE_ZAMBONI_1_DAMAGE1"))
				r.set_image_override("Zombie_zamboni_2", Res.get_image("IMAGE_REANIM_ZOMBIE_ZAMBONI_2_DAMAGE1"))
			elif after == 2:
				r.set_image_override("Zombie_zamboni_1", Res.get_image("IMAGE_REANIM_ZOMBIE_ZAMBONI_1_DAMAGE2"))
				r.set_image_override("Zombie_zamboni_2", Res.get_image("IMAGE_REANIM_ZOMBIE_ZAMBONI_2_DAMAGE2"))
				add_attached_particle(27, 72, PvZ.PARTICLE_ZAMBONI_SMOKE)
	elif zombie_type == PvZ.ZOMBIE_CATAPULT:
		var r := body_reanim
		if Tod.test_bit(damage_flags, PvZ.DAMAGE_SPIKE) or body_health <= 0:
			r.set_image_override("Zombie_catapult_siding", Res.get_image("IMAGE_REANIM_ZOMBIE_CATAPULT_SIDING_DAMAGE"))
			catapult_death(damage_flags)
		elif before != after:
			if after == 1:
				r.set_image_override("Zombie_catapult_siding", Res.get_image("IMAGE_REANIM_ZOMBIE_CATAPULT_SIDING_DAMAGE"))
			elif after == 2:
				add_attached_particle(47, 77, PvZ.PARTICLE_ZAMBONI_SMOKE)
	elif zombie_type == PvZ.ZOMBIE_GARGANTUAR or zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR:
		var r := body_reanim
		if before != after:
			if after == 1:
				r.set_image_override("Zombie_gargantua_body1", Res.get_image("IMAGE_REANIM_ZOMBIE_GARGANTUAR_BODY1_2"))
				r.set_image_override("Zombie_gargantuar_outerarm_lower", Res.get_image("IMAGE_REANIM_ZOMBIE_GARGANTUAR_OUTERARM_LOWER2"))
			elif after == 2:
				r.set_image_override("Zombie_gargantua_body1", Res.get_image("IMAGE_REANIM_ZOMBIE_GARGANTUAR_BODY1_3"))
				r.set_image_override("Zombie_gargantuar_outerleg_foot", Res.get_image("IMAGE_REANIM_ZOMBIE_GARGANTUAR_FOOT2"))
				r.set_image_override("Zombie_gargantuar_outerarm_lower", Res.get_image("IMAGE_REANIM_ZOMBIE_GARGANTUAR_OUTERARM_LOWER2"))
				if zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR:
					r.set_image_override("anim_head1", Res.get_image("IMAGE_REANIM_ZOMBIE_GARGANTUAR_HEAD2_REDEYE"))
				else:
					r.set_image_override("anim_head1", Res.get_image("IMAGE_REANIM_ZOMBIE_GARGANTUAR_HEAD2"))
	elif zombie_type == PvZ.ZOMBIE_BOSS:
		if not Tod.test_bit(damage_flags, PvZ.DAMAGE_DOESNT_CAUSE_FLASH):
			App.play_foley(PvZ.FOLEY_SHIELD_HIT)
		var r := body_reanim
		if before != after:
			if after == 1:
				r.set_image_override("Boss_head", Res.get_image("IMAGE_REANIM_ZOMBIE_BOSS_HEAD_DAMAGE1"))
				r.set_image_override("Boss_jaw", Res.get_image("IMAGE_REANIM_ZOMBIE_BOSS_JAW_DAMAGE1"))
				r.set_image_override("Boss_outerarm_hand", Res.get_image("IMAGE_REANIM_ZOMBIE_BOSS_OUTERARM_HAND_DAMAGE1"))
				r.set_image_override("Boss_outerarm_thumb2", Res.get_image("IMAGE_REANIM_ZOMBIE_BOSS_OUTERARM_THUMB_DAMAGE1"))
				r.set_image_override("Boss_innerleg_foot", Res.get_image("IMAGE_REANIM_ZOMBIE_BOSS_FOOT_DAMAGE1"))
			elif after == 2:
				r.set_image_override("Boss_head", Res.get_image("IMAGE_REANIM_ZOMBIE_BOSS_HEAD_DAMAGE2"))
				r.set_image_override("Boss_jaw", Res.get_image("IMAGE_REANIM_ZOMBIE_BOSS_JAW_DAMAGE2"))
				r.set_image_override("Boss_outerarm_hand", Res.get_image("IMAGE_REANIM_ZOMBIE_BOSS_OUTERARM_HAND_DAMAGE2"))
				r.set_image_override("Boss_outerarm_thumb2", Res.get_image("IMAGE_REANIM_ZOMBIE_BOSS_OUTERARM_THUMB_DAMAGE2"))
				r.set_image_override("Boss_outerleg_foot", Res.get_image("IMAGE_REANIM_ZOMBIE_BOSS_FOOT_DAMAGE2"))
				apply_boss_smoke_particles(true)
		var flash := Tod.idiv(body_max_health, BOSS_FLASH_HEALTH_FRACTION)
		if origin >= flash and body_health < flash:
			App.add_tod_particle(770.0, 260.0, BoardCore.make_render_order(PvZ.RENDER_LAYER_TOP, 0, 0), PvZ.PARTICLE_BOSS_EXPLOSION)
			App.play_foley(PvZ.FOLEY_BOSS_EXPLOSION_SMALL)
			apply_boss_smoke_particles(true)
		if body_health <= 0:
			body_health = 1
	else:
		update_damage_states(damage_flags)
	if body_health <= 0:
		body_health = 0
		play_death_anim(damage_flags)
		drop_loot()

func take_damage(damage: int, damage_flags: int) -> void:
	if zombie_phase == PvZ.PHASE_JACK_IN_THE_BOX_POPPING or is_dead_or_dying():
		return
	var remaining := damage
	if is_flying():
		remaining = take_flying_damage(remaining, damage_flags)
	if remaining > 0 and shield_type != PvZ.SHIELDTYPE_NONE and not Tod.test_bit(damage_flags, PvZ.DAMAGE_BYPASSES_SHIELD):
		remaining = take_shield_damage(remaining, damage_flags)
		if Tod.test_bit(damage_flags, PvZ.DAMAGE_HITS_SHIELD_AND_BODY):
			remaining = damage
	if remaining > 0 and helm_type != PvZ.HELMTYPE_NONE:
		remaining = take_helm_damage(remaining, damage_flags)
	if remaining > 0:
		take_body_damage(remaining, damage_flags)

func get_pos_y_based_on_row(the_row: int) -> float:
	if not is_on_board():
		return 0.0
	if is_on_high_ground():
		if altitude < PvZ.HIGH_GROUND_HEIGHT:
			zombie_height = PvZ.HEIGHT_UP_TO_HIGH_GROUND
		on_high_ground = true
	var py: float = board.get_pos_y_based_on_row(pos_x + 40.0, the_row) - 30.0
	if zombie_type == PvZ.ZOMBIE_BALLOON:
		py -= 30.0
	elif zombie_type == PvZ.ZOMBIE_POGO:
		py -= 16.0
	return py

func can_be_chilled() -> bool:
	if zombie_type == PvZ.ZOMBIE_ZAMBONI or is_bobsled_team_with_sled():
		return false
	if is_dead_or_dying():
		return false
	var p := zombie_phase
	if p == PvZ.PHASE_DIGGER_TUNNELING or p == PvZ.PHASE_DIGGER_RISING or p == PvZ.PHASE_DIGGER_TUNNELING_PAUSE_WITHOUT_AXE \
			or p == PvZ.PHASE_DIGGER_RISE_WITHOUT_AXE or p == PvZ.PHASE_RISING_FROM_GRAVE or p == PvZ.PHASE_DANCER_RISING:
		return false
	if mind_controlled:
		return false
	return zombie_type != PvZ.ZOMBIE_BOSS or p == PvZ.PHASE_BOSS_HEAD_IDLE_BEFORE_SPIT or p == PvZ.PHASE_BOSS_HEAD_IDLE_AFTER_SPIT or p == PvZ.PHASE_BOSS_HEAD_SPIT

func can_be_frozen() -> bool:
	if not can_be_chilled():
		return false
	var p := zombie_phase
	if p == PvZ.PHASE_POLEVAULTER_IN_VAULT or p == PvZ.PHASE_DOLPHIN_INTO_POOL or p == PvZ.PHASE_DOLPHIN_IN_JUMP \
			or p == PvZ.PHASE_SNORKEL_INTO_POOL or is_flying() or p == PvZ.PHASE_IMP_GETTING_THROWN or p == PvZ.PHASE_IMP_LANDING \
			or p == PvZ.PHASE_BOBSLED_CRASHING or p == PvZ.PHASE_JACK_IN_THE_BOX_POPPING or p == PvZ.PHASE_SQUASH_RISING \
			or p == PvZ.PHASE_SQUASH_FALLING or p == PvZ.PHASE_SQUASH_DONE_FALLING or is_bouncing_pogo():
		return false
	return zombie_type != PvZ.ZOMBIE_BUNGEE or p == PvZ.PHASE_BUNGEE_AT_BOTTOM

func effected_by_damage(range_flags: int) -> bool:
	if not Tod.test_bit(range_flags, PvZ.DAMAGES_DYING) and is_dead_or_dying():
		return false
	if Tod.test_bit(range_flags, PvZ.DAMAGES_ONLY_MINDCONTROLLED):
		if not mind_controlled:
			return false
	elif mind_controlled:
		return false
	if zombie_type == PvZ.ZOMBIE_BUNGEE and zombie_phase != PvZ.PHASE_BUNGEE_AT_BOTTOM and zombie_phase != PvZ.PHASE_BUNGEE_GRABBING:
		return false
	if zombie_height == PvZ.HEIGHT_GETTING_BUNGEE_DROPPED:
		return false
	if zombie_type == PvZ.ZOMBIE_BOSS:
		var r := body_reanim
		if zombie_phase == PvZ.PHASE_BOSS_HEAD_ENTER and r.anim_time < 0.5:
			return false
		if zombie_phase == PvZ.PHASE_BOSS_HEAD_LEAVE and r.anim_time > 0.5:
			return false
		if zombie_phase != PvZ.PHASE_BOSS_HEAD_IDLE_BEFORE_SPIT and zombie_phase != PvZ.PHASE_BOSS_HEAD_IDLE_AFTER_SPIT and zombie_phase != PvZ.PHASE_BOSS_HEAD_SPIT:
			return false
	if zombie_type == PvZ.ZOMBIE_BOBSLED and get_bobsled_position() > 0:
		return false
	var p := zombie_phase
	if p == PvZ.PHASE_POLEVAULTER_IN_VAULT or p == PvZ.PHASE_IMP_GETTING_THROWN or p == PvZ.PHASE_DIGGER_RISING \
			or p == PvZ.PHASE_DIGGER_TUNNELING_PAUSE_WITHOUT_AXE or p == PvZ.PHASE_DIGGER_RISE_WITHOUT_AXE or p == PvZ.PHASE_DOLPHIN_INTO_POOL \
			or p == PvZ.PHASE_DOLPHIN_IN_JUMP or p == PvZ.PHASE_SNORKEL_INTO_POOL or p == PvZ.PHASE_BALLOON_POPPING \
			or p == PvZ.PHASE_RISING_FROM_GRAVE or p == PvZ.PHASE_BOBSLED_CRASHING or p == PvZ.PHASE_DANCER_RISING:
		return Tod.test_bit(range_flags, PvZ.DAMAGES_OFF_GROUND)
	if zombie_type != PvZ.ZOMBIE_BOBSLED and get_zombie_rect().position.x > PvZ.WIDE_BOARD_WIDTH:
		return false
	var submerged := zombie_type == PvZ.ZOMBIE_SNORKEL and in_pool and not is_eating
	if Tod.test_bit(range_flags, PvZ.DAMAGES_SUBMERGED) and submerged:
		return true
	var underground := zombie_phase == PvZ.PHASE_DIGGER_TUNNELING
	if Tod.test_bit(range_flags, PvZ.DAMAGES_UNDERGROUND) and underground:
		return true
	if Tod.test_bit(range_flags, PvZ.DAMAGES_FLYING) and is_flying():
		return true
	return Tod.test_bit(range_flags, PvZ.DAMAGES_GROUND) and not is_flying() and not submerged and not underground

func set_row(the_row: int) -> void:
	row = the_row
	render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_ZOMBIE, row, 4)

func rise_from_grave(col: int, the_row: int) -> void:
	pos_x = board.grid_to_pixel_x(col, row) - 25
	pos_y = get_pos_y_based_on_row(the_row)
	set_row(the_row)
	x = int(pos_x)
	y = int(pos_y)
	altitude = CLIP_HEIGHT_OFF
	zombie_phase = PvZ.PHASE_RISING_FROM_GRAVE
	phase_counter = 150
	if board.stage_has_pool():
		altitude = -150.0
		in_pool = true
		phase_counter = 50
		zombie_height = PvZ.HEIGHT_ZOMBIE_NORMAL
		start_walk_anim(0)
		reanim_ignore_clip_rect("Zombie_duckytube", false)
		reanim_ignore_clip_rect("Zombie_whitewater", false)
		reanim_ignore_clip_rect("Zombie_outerarm_hand", false)
		reanim_ignore_clip_rect("Zombie_innerarm3", false)
		var r := body_reanim
		var ps := App.add_tod_particle(0.0, 0.0, 0, PvZ.PARTICLE_ZOMBIE_SEAWEED)
		override_particle_scale(ps)
		if zombie_type == PvZ.ZOMBIE_TRAFFIC_CONE and ps:
			r.attach_particle_to_track("anim_cone", ps, 37.0, 20.0)
		elif zombie_type == PvZ.ZOMBIE_PAIL and ps:
			r.attach_particle_to_track("anim_bucket", ps, 37.0, 20.0)
		elif ps:
			r.attach_particle_to_track("anim_head1", ps, 30.0, 20.0)
		var ps2 := App.add_tod_particle(0.0, 0.0, 0, PvZ.PARTICLE_ZOMBIE_SEAWEED)
		if ps2:
			override_particle_scale(ps2)
			r.attach_particle_to_track("Zombie_outerarm_upper", ps2, 5.0, 5.0)
		var ps3 := App.add_tod_particle(0.0, 0.0, 0, PvZ.PARTICLE_ZOMBIE_SEAWEED)
		if ps3:
			override_particle_scale(ps3)
			r.attach_particle_to_track("Zombie_duckytube", ps3, 77.0, 20.0)
		pool_splash(false)
	else:
		var ppx := int(pos_x + 60)
		var ppy := int(pos_y + 110)
		if is_on_high_ground():
			ppy -= PvZ.HIGH_GROUND_HEIGHT
		var order := BoardCore.make_render_order(PvZ.RENDER_LAYER_PARTICLE, the_row, 0)
		if App.is_whack_a_zombie_level():
			App.play_foley(PvZ.FOLEY_DIRT_RISE)
			App.add_tod_particle(ppx, ppy, order, PvZ.PARTICLE_WHACK_A_ZOMBIE_RISE)
		else:
			App.play_foley(PvZ.FOLEY_GRAVESTONE_RUMBLE)
			App.add_tod_particle(ppx, ppy, order, PvZ.PARTICLE_ZOMBIE_RISE)

static func is_zombotany(t: int) -> bool:
	return t == PvZ.ZOMBIE_PEA_HEAD or t == PvZ.ZOMBIE_WALLNUT_HEAD or t == PvZ.ZOMBIE_TALLNUT_HEAD or t == PvZ.ZOMBIE_JALAPENO_HEAD \
		or t == PvZ.ZOMBIE_GATLING_HEAD or t == PvZ.ZOMBIE_SQUASH_HEAD

static func zombie_type_can_go_in_pool(t: int) -> bool:
	return t in [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_PAIL, PvZ.ZOMBIE_FLAG, PvZ.ZOMBIE_SNORKEL, PvZ.ZOMBIE_DOLPHIN_RIDER,
		PvZ.ZOMBIE_PEA_HEAD, PvZ.ZOMBIE_WALLNUT_HEAD, PvZ.ZOMBIE_JALAPENO_HEAD, PvZ.ZOMBIE_GATLING_HEAD, PvZ.ZOMBIE_TALLNUT_HEAD]

static func zombie_type_can_go_on_high_ground(t: int) -> bool:
	return t != PvZ.ZOMBIE_ZAMBONI and t != PvZ.ZOMBIE_BOBSLED

func get_zombie_rect() -> Rect2i:
	var r := zombie_rect
	if is_walking_backwards():
		r.position.x = width - r.position.x - r.size.x
	var dp := _rect_dp
	get_draw_pos(dp)
	r.position += Vector2i(x, int(y + dp.body_y))
	if dp.clip_height > CLIP_HEIGHT_LIMIT:
		r.size.y -= int(dp.clip_height)
	return r

func get_zombie_attack_rect() -> Rect2i:
	var r := zombie_attack_rect
	if zombie_phase == PvZ.PHASE_POLEVAULTER_IN_VAULT or zombie_phase == PvZ.PHASE_DOLPHIN_IN_JUMP:
		r = Rect2i(-40, 0, 100, 115)
	if is_walking_backwards():
		r.position.x = width - r.position.x - r.size.x
	var dp := _rect_dp
	get_draw_pos(dp)
	r.position += Vector2i(x, int(y + dp.body_y))
	if dp.clip_height > CLIP_HEIGHT_LIMIT:
		r.size.y -= int(dp.clip_height)
	return r

func add_attached_particle(px: int, py: int, effect: int) -> TodParticleSystem:
	if dead:
		return null
	if Attachment.is_full(self):
		return null
	var ps := App.add_tod_particle(x + px, y + py, 0, effect)
	if ps:
		Attachment.attach_particle(self, ps, px, py)
	return ps

func add_attached_reanim(px: int, py: int, rt: int) -> Reanimation:
	if dead:
		return null
	var r := App.add_reanimation(x + px, y + py, 0, rt)
	if r:
		Attachment.attach_reanim(self, r, px, py)
	return r

func remove_ice_trap() -> void:
	ice_trap_counter = 0
	if zombie_type == PvZ.ZOMBIE_BALLOON:
		balloon_propeller_hat_spin(true)
	update_anim_speed()
	start_zombie_sound()

func hit_ice_trap() -> void:
	var cold := chilled_counter > 0 or ice_trap_counter != 0
	apply_chill(true)
	if not can_be_frozen():
		return
	if in_pool:
		ice_trap_counter = 300
	elif cold:
		ice_trap_counter = Tod.rand_range_int(300, 400)
	else:
		ice_trap_counter = Tod.rand_range_int(400, 600)
	stop_zombie_sound()
	if zombie_type == PvZ.ZOMBIE_BALLOON:
		balloon_propeller_hat_spin(false)
	if zombie_phase == PvZ.PHASE_BOSS_HEAD_SPIT:
		board.remove_particle_by_type(PvZ.PARTICLE_ZOMBIE_BOSS_FIREBALL)
	take_damage(20, 1)
	update_anim_speed()

## Zombie::IsTangleKelpTarget (the overload that also counts being dragged under).
func is_tangle_kelp_target_or_dragged() -> bool:
	if zombie_height == PvZ.HEIGHT_DRAGGED_UNDER:
		return true
	return is_tangle_kelp_target()

func is_squash_target(except: Plant) -> bool:
	for p in board.plants:
		if not p.dead and p != except and p.seed_type == PvZ.SEED_SQUASH and p.target_zombie == self:
			return true
	return false

func is_fire_resistant() -> bool:
	return zombie_type == PvZ.ZOMBIE_CATAPULT or zombie_type == PvZ.ZOMBIE_ZAMBONI or shield_type == PvZ.SHIELDTYPE_DOOR or shield_type == PvZ.SHIELDTYPE_LADDER

func balloon_propeller_hat_spin(spinning: bool) -> void:
	var r := body_reanim
	var prop := Attachment.find_reanim_attachment(r.get_track_instance("hat"))
	if prop:
		prop.anim_rate = prop.definition.fps if spinning else 0.0

func remove_butter() -> void:
	if zombie_type == PvZ.ZOMBIE_BALLOON:
		balloon_propeller_hat_spin(true)
	if Zombie.is_zombotany(zombie_type):
		var head := rv(special_head_reanim)
		if head:
			if zombie_type == PvZ.ZOMBIE_PEA_HEAD and head.is_anim_playing("anim_shooting"):
				head.anim_rate = 35.0
			elif zombie_type == PvZ.ZOMBIE_GATLING_HEAD and head.is_anim_playing("anim_shooting"):
				head.anim_rate = 38.0
			else:
				head.anim_rate = 15.0
	update_anim_speed()
	start_zombie_sound()

func apply_butter() -> void:
	if not has_head or not can_be_frozen():
		return
	if zombie_type == PvZ.ZOMBIE_ZAMBONI or zombie_type == PvZ.ZOMBIE_BOSS or is_tangle_kelp_target_or_dragged() or is_bobsled_team_with_sled() or is_flying():
		return
	buttered_counter = 400
	var z := zv(related_zombie)
	if z:
		z.related_zombie = null
		related_zombie = null
	if zombie_type == PvZ.ZOMBIE_POGO:
		altitude = 0.0
		if on_high_ground:
			altitude += PvZ.HIGH_GROUND_HEIGHT
	elif zombie_type == PvZ.ZOMBIE_BALLOON:
		balloon_propeller_hat_spin(false)
	elif Zombie.is_zombotany(zombie_type):
		var head := rv(special_head_reanim)
		if head:
			head.anim_rate = 0.0
	update_anim_speed()
	stop_zombie_sound()

func mow_down() -> void:
	if dead or zombie_phase == PvZ.PHASE_ZOMBIE_MOWERED or zombie_type == PvZ.ZOMBIE_BOSS:
		return
	if zombie_type == PvZ.ZOMBIE_CATAPULT:
		App.add_tod_particle(pos_x + 80.0, pos_y + 60.0, render_order + 1, PvZ.PARTICLE_CATAPULT_EXPLOSION)
		App.play_foley(PvZ.FOLEY_EXPLOSION)
		die_with_loot()
		return
	if zombie_type == PvZ.ZOMBIE_ZAMBONI:
		App.add_tod_particle(pos_x + 80.0, pos_y + 60.0, render_order + 1, PvZ.PARTICLE_ZAMBONI_EXPLOSION)
		App.play_foley(PvZ.FOLEY_EXPLOSION)
		die_with_loot()
		return
	var p := zombie_phase
	if p == PvZ.PHASE_ZOMBIE_DYING or p == PvZ.PHASE_POLEVAULTER_IN_VAULT or p == PvZ.PHASE_RISING_FROM_GRAVE \
			or p == PvZ.PHASE_DANCER_RISING or p == PvZ.PHASE_SNORKEL_INTO_POOL or p == PvZ.PHASE_ZOMBIE_BURNED \
			or zombie_type == PvZ.ZOMBIE_GARGANTUAR or zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR or zombie_type == PvZ.ZOMBIE_BUNGEE \
			or zombie_type == PvZ.ZOMBIE_DIGGER or zombie_type == PvZ.ZOMBIE_IMP or zombie_type == PvZ.ZOMBIE_YETI \
			or zombie_type == PvZ.ZOMBIE_DOLPHIN_RIDER or is_bobsled_team_with_sled() or is_flying() or in_pool:
		var puff := App.add_reanimation(pos_x - 73.0, pos_y - 56.0, render_order + 2, PvZ.REANIM_PUFF)
		puff.set_frames_for_layer("anim_puff")
		App.add_tod_particle(pos_x + 110.0, pos_y + 0.0, render_order + 1, PvZ.PARTICLE_MOWER_CLOUD)
		if board.plant_row[row] != PvZ.PLANTROW_POOL:
			drop_head(0)
			drop_arm(0)
			drop_helm(0)
			drop_shield(0)
		die_with_loot()
		return
	if ice_trap_counter > 0:
		remove_ice_trap()
	if buttered_counter > 0:
		buttered_counter = 0
	drop_shield(0)
	drop_helm(0)
	if zombie_type == PvZ.ZOMBIE_FLAG:
		drop_flag()
	elif zombie_type == PvZ.ZOMBIE_POLEVAULTER:
		drop_pole()
	elif zombie_type == PvZ.ZOMBIE_NEWSPAPER or zombie_type == PvZ.ZOMBIE_BALLOON:
		drop_head(0)
	elif zombie_type == PvZ.ZOMBIE_POGO:
		drop_head(0)
		altitude = 0.0
	var mr := App.add_reanimation(0.0, 0.0, render_order, PvZ.REANIM_LAWN_MOWERED_ZOMBIE)
	mr.anim_rate = 8.0
	mr.is_attachment = false
	mr.loop_type = Reanimation.REANIM_PLAY_ONCE_AND_HOLD
	mowered_reanim = mr
	zombie_phase = PvZ.PHASE_ZOMBIE_MOWERED
	drop_loot()

func remove_cold_effects() -> void:
	if ice_trap_counter > 0:
		remove_ice_trap()
	if chilled_counter > 0:
		chilled_counter = 0
		update_anim_speed()

func apply_burn() -> void:
	if dead or zombie_phase == PvZ.PHASE_ZOMBIE_BURNED:
		return
	if body_health >= 1800 or zombie_type == PvZ.ZOMBIE_BOSS:
		take_damage(1800, 18)
		return
	if zombie_type == PvZ.ZOMBIE_SQUASH_HEAD and not has_head:
		if rv(special_head_reanim):
			special_head_reanim.die()
		special_head_reanim = null
	if ice_trap_counter > 0:
		remove_ice_trap()
	if buttered_counter > 0:
		buttered_counter = 0
	Attachment.detach_cross_fade_particle_type(self, PvZ.PARTICLE_ZAMBONI_SMOKE, "")
	bungee_drop_plant()
	var p := zombie_phase
	if p == PvZ.PHASE_ZOMBIE_DYING or p == PvZ.PHASE_POLEVAULTER_IN_VAULT or p == PvZ.PHASE_IMP_GETTING_THROWN \
			or p == PvZ.PHASE_RISING_FROM_GRAVE or p == PvZ.PHASE_DANCER_RISING or p == PvZ.PHASE_DOLPHIN_INTO_POOL \
			or p == PvZ.PHASE_DOLPHIN_IN_JUMP or p == PvZ.PHASE_DOLPHIN_RIDING or p == PvZ.PHASE_SNORKEL_INTO_POOL \
			or p == PvZ.PHASE_DIGGER_TUNNELING or p == PvZ.PHASE_DIGGER_TUNNELING_PAUSE_WITHOUT_AXE or p == PvZ.PHASE_DIGGER_RISING \
			or p == PvZ.PHASE_DIGGER_RISE_WITHOUT_AXE or p == PvZ.PHASE_ZOMBIE_MOWERED or in_pool:
		die_with_loot()
	elif zombie_type == PvZ.ZOMBIE_BUNGEE or zombie_type == PvZ.ZOMBIE_YETI or Zombie.is_zombotany(zombie_type) \
			or is_bobsled_team_with_sled() or is_flying() or not has_head:
		set_anim_rate(0.0)
		var head := rv(special_head_reanim)
		if head:
			head.anim_rate = 0.0
		zombie_phase = PvZ.PHASE_ZOMBIE_BURNED
		phase_counter = 300
		just_got_shot_counter = 0
		drop_loot()
		if zombie_type == PvZ.ZOMBIE_BALLOON:
			balloon_propeller_hat_spin(false)
	else:
		var rt := PvZ.REANIM_ZOMBIE_CHARRED
		var cx := pos_x + 22.0
		var cy := pos_y - 10.0
		if zombie_type == PvZ.ZOMBIE_BALLOON:
			cy += 31.0
		if zombie_type == PvZ.ZOMBIE_IMP:
			cx -= 6.0
			rt = PvZ.REANIM_ZOMBIE_CHARRED_IMP
		if zombie_type == PvZ.ZOMBIE_DIGGER:
			if is_walking_backwards():
				cx += 14.0
			rt = PvZ.REANIM_ZOMBIE_CHARRED_DIGGER
		if zombie_type == PvZ.ZOMBIE_ZAMBONI:
			rt = PvZ.REANIM_ZOMBIE_CHARRED_ZAMBONI
			cx += 61.0
			cy -= 16.0
		if zombie_type == PvZ.ZOMBIE_CATAPULT:
			rt = PvZ.REANIM_ZOMBIE_CHARRED_CATAPULT
			cx -= 36.0
			cy -= 20.0
		if zombie_type == PvZ.ZOMBIE_GARGANTUAR or zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR:
			rt = PvZ.REANIM_ZOMBIE_CHARRED_GARGANTUAR
			cx -= 15.0
			cy -= 10.0
		var cr := App.add_reanimation(cx, cy, render_order, rt)
		cr.anim_rate *= Tod.rand_range_float(0.9, 1.1)
		if zombie_phase == PvZ.PHASE_DIGGER_WALKING_WITHOUT_AXE:
			cr.set_frames_for_layer("anim_crumble_noaxe")
		elif zombie_type == PvZ.ZOMBIE_DIGGER:
			cr.set_frames_for_layer("anim_crumble")
		elif (zombie_type == PvZ.ZOMBIE_GARGANTUAR or zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR) and not has_object:
			cr.set_image_override("impblink", Res.get_image("IMAGE_BLANK"))
			cr.set_image_override("imphead", Res.get_image("IMAGE_BLANK"))
		if scale_zombie != 1.0:
			cr.overlay_matrix.x.x = scale_zombie
			cr.overlay_matrix.y.y = scale_zombie
			cr.overlay_matrix.origin.x += 20.0 - scale_zombie * 20.0
			cr.overlay_matrix.origin.y += 120.0 - scale_zombie * 120.0
			cr.override_scale(scale_zombie, scale_zombie)
		if is_walking_backwards():
			cr.override_scale(-scale_zombie, scale_zombie)
			cr.overlay_matrix.origin.x += 60.0 * scale_zombie
		die_with_loot()
	if zombie_type == PvZ.ZOMBIE_BOBSLED:
		bobsled_burn()

func attach_shield() -> void:
	var track := ""
	var r := body_reanim
	if shield_type == PvZ.SHIELDTYPE_DOOR:
		show_door_arms(true)
		reanim_show_prefix("Zombie_outerarm_screendoor", RENDER_GROUP_OVER_SHIELD)
		track = "anim_screendoor"
	elif shield_type == PvZ.SHIELDTYPE_NEWSPAPER:
		reanim_show_prefix("Zombie_paper_hands", RENDER_GROUP_OVER_SHIELD)
		track = "Zombie_paper_paper"
	elif shield_type == PvZ.SHIELDTYPE_LADDER:
		reanim_show_prefix("Zombie_outerarm", RENDER_GROUP_OVER_SHIELD)
		track = "Zombie_ladder_1"
	r.assign_render_group_to_track(track, RENDER_GROUP_SHIELD)

func detach_shield() -> void:
	var r := rv(body_reanim)
	if r:
		if shield_type == PvZ.SHIELDTYPE_DOOR:
			show_door_arms(false)
		elif shield_type == PvZ.SHIELDTYPE_NEWSPAPER:
			reanim_show_prefix("Zombie_paper_hands", Reanimation.RENDER_GROUP_NORMAL)
		elif shield_type == PvZ.SHIELDTYPE_LADDER:
			if has_arm:
				reanim_show_prefix("Zombie_outerarm", Reanimation.RENDER_GROUP_NORMAL)
			zombie_phase = PvZ.PHASE_ZOMBIE_NORMAL
			if vs_target:
				play_zombie_reanim("anim_idle", Reanimation.REANIM_LOOP, 10, 12.0)
			elif is_eating:
				play_zombie_reanim("anim_eat", Reanimation.REANIM_LOOP, 20, 0.0)
			else:
				start_walk_anim(0)
	shield_type = PvZ.SHIELDTYPE_NONE
	shield_health = 0

func reanim_show_prefix(prefix: String, group: int) -> void:
	var r := rv(body_reanim)
	if r:
		r.assign_render_group_to_prefix(prefix, group)

func reanim_show_track(track_name: String, group: int) -> void:
	var r := rv(body_reanim)
	if r:
		r.assign_render_group_to_track(track_name, group)

func play_death_anim(damage_flags: int) -> void:
	if zombie_phase == PvZ.PHASE_ZOMBIE_DYING or zombie_phase == PvZ.PHASE_ZOMBIE_BURNED or zombie_phase == PvZ.PHASE_ZOMBIE_MOWERED:
		return
	var r := rv(body_reanim)
	if r == null or not r.track_exists("anim_death"):
		die_no_loot()
		return
	if zombie_type == PvZ.ZOMBIE_DOLPHIN_RIDER and zombie_phase != PvZ.PHASE_DOLPHIN_WALKING_IN_POOL:
		die_no_loot()
		return
	if zombie_phase == PvZ.PHASE_SNORKEL_INTO_POOL or zombie_phase == PvZ.PHASE_SNORKEL_WALKING:
		die_no_loot()
		return
	if ice_trap_counter > 0:
		add_attached_particle(75, 106, PvZ.PARTICLE_ICE_TRAP_RELEASE)
		ice_trap_counter = 0
	if buttered_counter > 0:
		buttered_counter = 0
	if yucky_face:
		show_yucky_face(false)
		yucky_face = false
		yucky_face_counter = 0
	if Tod.test_bit(damage_flags, PvZ.DAMAGE_DOESNT_LEAVE_BODY):
		if zombie_type != PvZ.ZOMBIE_BOSS and zombie_type != PvZ.ZOMBIE_GARGANTUAR and zombie_type != PvZ.ZOMBIE_REDEYE_GARGANTUAR:
			die_no_loot()
			return
	if zombie_type == PvZ.ZOMBIE_POGO:
		altitude = 0.0
	Attachment.reanim_type_die(self, PvZ.REANIM_ZOMBIE_SURPRISE)
	stop_eating()
	if shield_type != PvZ.SHIELDTYPE_NONE:
		drop_shield(1)
	if zombie_type == PvZ.ZOMBIE_SQUASH_HEAD and not has_head:
		if rv(special_head_reanim):
			special_head_reanim.die()
		special_head_reanim = null
	vel_x = 0.0
	zombie_phase = PvZ.PHASE_ZOMBIE_DYING
	if zombie_height == PvZ.HEIGHT_ZOMBIQUARIUM:
		play_zombie_reanim("anim_aquarium_death", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 14.0)
		return
	if zombie_height == PvZ.HEIGHT_UP_LADDER:
		zombie_height = PvZ.HEIGHT_FALLING
	var rate: float
	if zombie_type == PvZ.ZOMBIE_FOOTBALL:
		rate = 24.0
	elif zombie_type == PvZ.ZOMBIE_GARGANTUAR or zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR:
		rate = 14.0
		App.play_foley(PvZ.FOLEY_GARGANTUDEATH)
	elif zombie_type == PvZ.ZOMBIE_SNORKEL:
		rate = 14.0
	elif zombie_type == PvZ.ZOMBIE_DIGGER:
		rate = 18.0
	elif zombie_type == PvZ.ZOMBIE_YETI:
		rate = 14.0
	elif zombie_type == PvZ.ZOMBIE_BOSS:
		rate = 18.0
		boss_die()
		special_head_reanim.play_reanim("anim_death", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, rate)
	else:
		rate = Tod.rand_range_float(24.0, 30.0)
	var track := "anim_death"
	var hit := Tod.rand_int(100)
	var super_long_ok: bool = App.has_finished_adventure() or board.level > 5
	if in_pool and r.track_exists("anim_waterdeath"):
		track = "anim_waterdeath"
		reanim_ignore_clip_rect("Zombie_duckytube", false)
	elif hit == 99 and r.track_exists("anim_superlongdeath") and super_long_ok and chilled_counter == 0 and board.count_zombies_on_screen() <= 5:
		rate = 14.0
		track = "anim_superlongdeath"
	elif hit > 50 and r.track_exists("anim_death2"):
		track = "anim_death2"
	play_zombie_reanim(track, Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, rate)
	reanim_show_prefix("anim_tongue", Reanimation.RENDER_GROUP_HIDDEN)

func do_daisies() -> void:
	if is_walking_backwards():
		return
	if board.plant_row[row] == PvZ.PLANTROW_POOL:
		return
	if zombie_type == PvZ.ZOMBIE_BOBSLED or zombie_type == PvZ.ZOMBIE_ZAMBONI or zombie_type == PvZ.ZOMBIE_CATAPULT:
		return
	if board.stage_has_roof():
		return
	var ox := 20.0
	var oy := 100.0
	if zombie_type == PvZ.ZOMBIE_FOOTBALL or zombie_type == PvZ.ZOMBIE_DANCER or zombie_type == PvZ.ZOMBIE_BACKUP_DANCER:
		ox += 160.0
	elif zombie_type == PvZ.ZOMBIE_POGO:
		oy += 120.0
	elif zombie_type == PvZ.ZOMBIE_BALLOON:
		oy += 30.0
		ox += 110.0
	if board.stage_has_grave_stones():
		oy += 15.0
	App.add_tod_particle(x + ox, y + oy, BoardCore.make_render_order(PvZ.RENDER_LAYER_GRAVE_STONE, row, 5), PvZ.PARTICLE_ZOMBIE_DAISIES)

func update_death() -> void:
	var r := rv(body_reanim)
	if r == null:
		die_no_loot()
		return
	if zombie_height == PvZ.HEIGHT_FALLING:
		update_zombie_falling()
	if zombie_type == PvZ.ZOMBIE_GARGANTUAR or zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR:
		if r.should_trigger_timed_event(0.89):
			board.shake_board(0, 3)
		elif r.should_trigger_timed_event(0.98):
			board.shake_board(0, 1)
	if not in_pool:
		var fall := -1.0
		match zombie_type:
			PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_FLAG, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_PAIL, PvZ.ZOMBIE_DOOR, PvZ.ZOMBIE_PEA_HEAD, \
					PvZ.ZOMBIE_WALLNUT_HEAD, PvZ.ZOMBIE_TALLNUT_HEAD, PvZ.ZOMBIE_JALAPENO_HEAD, PvZ.ZOMBIE_GATLING_HEAD, \
					PvZ.ZOMBIE_SQUASH_HEAD, PvZ.ZOMBIE_DUCKY_TUBE:
				if r.is_anim_playing("anim_superlongdeath"):
					fall = 0.788
				elif r.is_anim_playing("anim_death2"):
					fall = 0.71
				else:
					fall = 0.77
			PvZ.ZOMBIE_POLEVAULTER: fall = 0.68
			PvZ.ZOMBIE_FOOTBALL: fall = 0.52
			PvZ.ZOMBIE_NEWSPAPER: fall = 0.63
			PvZ.ZOMBIE_DANCER, PvZ.ZOMBIE_BACKUP_DANCER: fall = 0.83
			PvZ.ZOMBIE_BOBSLED: fall = 0.81
			PvZ.ZOMBIE_JACK_IN_THE_BOX: fall = 0.64
			PvZ.ZOMBIE_BALLOON: fall = 0.68
			PvZ.ZOMBIE_DIGGER: fall = 0.85
			PvZ.ZOMBIE_POGO: fall = 0.84
			PvZ.ZOMBIE_YETI: fall = 0.68
			PvZ.ZOMBIE_LADDER: fall = 0.62
			PvZ.ZOMBIE_GARGANTUAR, PvZ.ZOMBIE_REDEYE_GARGANTUAR: fall = 0.86
		if fall > 0 and r.should_trigger_timed_event(fall):
			App.play_foley(PvZ.FOLEY_ZOMBIE_FALLING)
			if zombie_type == PvZ.ZOMBIE_GARGANTUAR or zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR:
				App.play_foley(PvZ.FOLEY_THUMP)
			if board.daisy_mode:
				do_daisies()
	if zombie_type == PvZ.ZOMBIE_BOSS:
		for t in [0.1, 0.12, 0.15, 0.19, 0.2, 0.26, 0.3, 0.4, 0.42, 0.5, 0.58, 0.61, 0.71]:
			if r.should_trigger_timed_event(t):
				var ex := Tod.rand_range_float(600.0, 750.0)
				var ey := Tod.rand_range_float(50.0, 300.0)
				App.add_tod_particle(ex, ey, PvZ.RENDER_LAYER_TOP, PvZ.PARTICLE_BOSS_EXPLOSION)
				App.play_foley(PvZ.FOLEY_BOSS_EXPLOSION_SMALL)
				break
		var head := rv(special_head_reanim)
		if r.should_trigger_timed_event(0.93):
			board.shake_board(1, 2)
			App.play_foley(PvZ.FOLEY_BOSS_EXPLOSION_SMALL)
			App.play_foley(PvZ.FOLEY_THUMP)
		if r.should_trigger_timed_event(0.99):
			head.play_reanim("anim_flag", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 30.0)
		if head.is_anim_playing("anim_flag") and head.loop_count > 0:
			head.play_reanim("anim_flag_loop", Reanimation.REANIM_LOOP, 20, 17.0)
		if r.loop_count > 0:
			drop_loot()
	if zombie_type == PvZ.ZOMBIE_ZAMBONI and phase_counter > 0:
		phase_counter -= 1
		if phase_counter == 0:
			if r.is_track_showing("anim_wheelie2"):
				App.add_tod_particle(pos_x + 80.0, pos_y + 60.0, render_order + 1, PvZ.PARTICLE_ZAMBONI_EXPLOSION2)
			else:
				App.add_tod_particle(pos_x + 80.0, pos_y + 60.0, render_order + 1, PvZ.PARTICLE_ZAMBONI_EXPLOSION)
			die_with_loot()
			App.play_foley(PvZ.FOLEY_EXPLOSION)
	elif zombie_type == PvZ.ZOMBIE_CATAPULT:
		phase_counter -= 1
		if phase_counter == 0:
			App.add_tod_particle(pos_x + 80.0, pos_y + 60.0, render_order + 1, PvZ.PARTICLE_CATAPULT_EXPLOSION)
			die_with_loot()
			App.play_foley(PvZ.FOLEY_EXPLOSION)
	elif zombie_fade == -1 and r.loop_count > 0 and zombie_type != PvZ.ZOMBIE_BOSS:
		zombie_fade = 10 if in_pool else 100

func update_mowered() -> void:
	var mr := rv(mowered_reanim)
	if mr == null or mr.loop_count > 0:
		drop_head(0)
		drop_arm(0)
		die_with_loot()

func has_shadow() -> bool:
	var p := zombie_phase
	if p == PvZ.PHASE_ZOMBIE_DYING or p == PvZ.PHASE_DIGGER_RISING or p == PvZ.PHASE_DIGGER_TUNNELING_PAUSE_WITHOUT_AXE \
			or p == PvZ.PHASE_DIGGER_RISE_WITHOUT_AXE or p == PvZ.PHASE_DIGGER_TUNNELING or p == PvZ.PHASE_RISING_FROM_GRAVE \
			or p == PvZ.PHASE_DANCER_RISING or p == PvZ.PHASE_BOBSLED_BOARDING or p == PvZ.PHASE_POLEVAULTER_IN_VAULT \
			or p == PvZ.PHASE_DOLPHIN_INTO_POOL or p == PvZ.PHASE_SNORKEL_INTO_POOL:
		return false
	if zombie_type == PvZ.ZOMBIE_ZAMBONI or zombie_type == PvZ.ZOMBIE_CATAPULT or zombie_type == PvZ.ZOMBIE_BOSS:
		return false
	if zombie_type == PvZ.ZOMBIE_BUNGEE:
		if not is_on_board() or hit_umbrella:
			return false
	if zombie_height == PvZ.HEIGHT_DRAGGED_UNDER or zombie_height == PvZ.HEIGHT_IN_TO_CHIMNEY or zombie_height == PvZ.HEIGHT_GETTING_BUNGEE_DROPPED:
		return false
	if in_pool:
		return false
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZOMBIQUARIUM:
		return false
	return App.game_mode != PvZ.GAMEMODE_CHALLENGE_INVISIGHOUL or from_wave == ZOMBIE_WAVE_UI

func setup_draw_zombie_won(g: Graphics) -> bool:
	if from_wave != ZOMBIE_WAVE_WINNER:
		return true
	match board.background:
		PvZ.BACKGROUND_1_DAY, PvZ.BACKGROUND_2_NIGHT:
			g.clip_rect(-123 + PvZ.BOARD_ADDITIONAL_WIDTH - x, -y, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
		PvZ.BACKGROUND_3_POOL, PvZ.BACKGROUND_4_FOG:
			g.clip_rect(-172 + PvZ.BOARD_ADDITIONAL_WIDTH - x, -y, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
		PvZ.BACKGROUND_5_ROOF, PvZ.BACKGROUND_6_BOSS:
			if board.cut_scene.cutscene_time > 1500:
				g.clip_rect(-220 + PvZ.BOARD_ADDITIONAL_WIDTH - x, -y, PvZ.BOARD_WIDTH, 187 + PvZ.BOARD_OFFSET_Y)
	return true

func draw_shadow(g: Graphics) -> void:
	var dp := DrawPosition.new()
	get_draw_pos(dp)
	if App.game_scene == PvZ.SCENE_ZOMBIES_WON and not setup_draw_zombie_won(g):
		return
	if is_on_board() and App.game_scene == PvZ.SCENE_PLAYING and App.game_mode != PvZ.GAMEMODE_CHALLENGE_ZOMBIQUARIUM:
		g.set_clip_rect(-x, -y, PvZ.ZOMBIE_CLIPRECT_WIDTH, PvZ.BOARD_HEIGHT)
	var shadow_type := 0
	var sx := dp.image_offset_x
	var sy := dp.image_offset_y + dp.body_y
	var sc := scale_zombie
	sx += scale_zombie * 20.0 - 20.0
	if is_on_board() and board.stage_is_night():
		shadow_type = 1
	var back := is_walking_backwards()
	match zombie_type:
		PvZ.ZOMBIE_FOOTBALL:
			if back:
				sx -= 11.0 * scale_zombie
			else:
				sx += 20.0 + 21.0 * scale_zombie
			sy += 16.0
		PvZ.ZOMBIE_NEWSPAPER:
			sx += 5.0 if back else 29.0
		PvZ.ZOMBIE_POLEVAULTER:
			sx += -5.0 if back else 36.0
			sy += 11.0
		PvZ.ZOMBIE_BOBSLED:
			sx += 13.0 if back else 20.0
			sy += 13.0
		PvZ.ZOMBIE_IMP:
			sc *= 0.6
			sy += 7.0
			sx += 13.0 if back else 25.0
		PvZ.ZOMBIE_DIGGER:
			sy += 5.0
			sx += 14.0 if back else 17.0
		PvZ.ZOMBIE_SNORKEL:
			sy += 5.0
			sx += -2.0 if back else 35.0
		PvZ.ZOMBIE_DOLPHIN_RIDER:
			sy += 11.0
			sx += 15.0 if back else 19.0
		PvZ.ZOMBIE_YETI:
			sy += 20.0
			sx += 20.0 if back else 3.0
		PvZ.ZOMBIE_GARGANTUAR, PvZ.ZOMBIE_REDEYE_GARGANTUAR:
			sc *= 1.5
			sx += 27.0
			sy += 7.0
		_:
			if rv(body_reanim) != null:
				sx += 11.0 if back else 23.0
			else:
				sx += -2.0 if back else 35.0
	if zombie_type == PvZ.ZOMBIE_NEWSPAPER:
		sy += 4.0
	elif zombie_type == PvZ.ZOMBIE_BALLOON:
		sy += 13.0
	elif zombie_type == PvZ.ZOMBIE_BUNGEE:
		sx -= 12.0
		sc = Tod.animate_curve_float(BUNGEE_ZOMBIE_HEIGHT - 1000, 100, int(altitude), 0.1, 1.5, Tod.CURVE_LINEAR)
	if zombie_height == PvZ.HEIGHT_UP_LADDER or zombie_height == PvZ.HEIGHT_FALLING or zombie_phase == PvZ.PHASE_IMP_GETTING_THROWN \
			or zombie_type == PvZ.ZOMBIE_BUNGEE or is_bouncing_pogo() or is_flying():
		sy += altitude
		if on_high_ground:
			sy -= PvZ.HIGH_GROUND_HEIGHT
	if in_pool:
		g.tod_draw_image_center_scaled_f(Res.get_image("IMAGE_WHITEWATER_SHADOW"), sx, sy + 67.0, sc, sc)
	else:
		g.tod_draw_image_center_scaled_f(Res.get_image("IMAGE_PLANTSHADOW" if shadow_type == 0 else "IMAGE_PLANTSHADOW2"), sx, sy + 92.0, sc, sc)
	g.clear_clip_rect()

## GetTrackPosition: the track anchor in board coordinates.
func get_track_position(track_name: String) -> Vector2:
	var r := rv(body_reanim)
	if r == null:
		return Vector2(pos_x, pos_y)
	var m := r.get_track_matrix(r.find_track_index(track_name))
	return Vector2(m.origin.x + pos_x, m.origin.y + pos_y)

func is_flying() -> bool:
	return zombie_phase == PvZ.PHASE_BALLOON_FLYING or zombie_phase == PvZ.PHASE_BALLOON_POPPING

func get_bobsled_position() -> int:
	if zombie_type != PvZ.ZOMBIE_BOBSLED:
		return -1
	if related_zombie == null and follower_zombies[0] == null:
		return -1
	if related_zombie == null:
		return 0
	for i in NUM_BOBSLED_FOLLOWERS:
		if related_zombie.follower_zombies[i] == self:
			return i + 1
	return -1

func is_bobsled_team_with_sled() -> bool:
	return get_bobsled_position() != -1

func is_dead_or_dying() -> bool:
	return dead or zombie_phase == PvZ.PHASE_ZOMBIE_DYING or zombie_phase == PvZ.PHASE_ZOMBIE_BURNED or zombie_phase == PvZ.PHASE_ZOMBIE_MOWERED

func update_zombie_chimney() -> void:
	if board.background == PvZ.BACKGROUND_5_ROOF or board.background == PvZ.BACKGROUND_6_BOSS:
		pos_y = 250 + PvZ.BOARD_OFFSET_Y
		altitude = Tod.animate_curve(4000, 5000, board.cut_scene.cutscene_time, 200, 0, Tod.CURVE_EASE_IN)

func walk_into_house() -> void:
	Attachment.detach_cross_fade_particle_type(self, PvZ.PARTICLE_ZAMBONI_SMOKE, "")
	from_wave = ZOMBIE_WAVE_WINNER
	reanim_reenable_clipping()
	if zombie_phase == PvZ.PHASE_POLEVAULTER_PRE_VAULT:
		zombie_phase = PvZ.PHASE_POLEVAULTER_POST_VAULT
		start_walk_anim(0)
	var bg: int = board.background
	if bg == PvZ.BACKGROUND_1_DAY or bg == PvZ.BACKGROUND_2_NIGHT or bg == PvZ.BACKGROUND_3_POOL or bg == PvZ.BACKGROUND_4_FOG:
		pos_y = 290.0 + PvZ.BOARD_OFFSET_Y
		render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_ZOMBIE, 2, 0)
		if zombie_type == PvZ.ZOMBIE_GARGANTUAR or zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR:
			pos_y += 30.0
		elif zombie_phase == PvZ.PHASE_POLEVAULTER_PRE_VAULT:
			pos_x += 35.0
		elif zombie_type == PvZ.ZOMBIE_ZAMBONI:
			pos_y += 15.0
		if board.stage_has_pool():
			if zombie_type == PvZ.ZOMBIE_FOOTBALL:
				pos_x -= 10.0
			else:
				pos_x -= 80.0
	elif bg == PvZ.BACKGROUND_5_ROOF or bg == PvZ.BACKGROUND_6_BOSS:
		pos_x = -180.0 + PvZ.BOARD_ADDITIONAL_WIDTH
		pos_y = 250.0 + PvZ.BOARD_OFFSET_Y
		zombie_height = PvZ.HEIGHT_IN_TO_CHIMNEY
		render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_GRAVE_STONE, 0, 2)
		if zombie_type == PvZ.ZOMBIE_GARGANTUAR or zombie_type == PvZ.ZOMBIE_REDEYE_GARGANTUAR:
			pos_y += 5.0
		elif zombie_type == PvZ.ZOMBIE_FOOTBALL:
			pos_x -= 14.0
		elif zombie_type == PvZ.ZOMBIE_ZAMBONI:
			pos_x -= 28.0
		var r := rv(body_reanim)
		if r and r.track_exists("anim_idle") and zombie_type != PvZ.ZOMBIE_POLEVAULTER:
			play_zombie_reanim("anim_idle", Reanimation.REANIM_LOOP, 0, 15.0)

# ================================================================ Dr. Zomboss
func boss_play_idle() -> void:
	zombie_phase = PvZ.PHASE_BOSS_IDLE
	phase_counter = Tod.rand_range_int(100, 200)
	play_zombie_reanim("anim_idle", Reanimation.REANIM_LOOP, 0, 6.0)

func draw_boss_fire_ball(g: Graphics, _dp: DrawPosition) -> void:
	make_parent_graphics_frame(g)
	var fb := rv(boss_fire_ball_reanim)
	if fb:
		fb.draw_render_group(g, Reanimation.RENDER_GROUP_NORMAL)
		g.draw_mode = Graphics.DRAWMODE_ADDITIVE
		fb.draw_render_group(g, RENDER_GROUP_BOSS_FIREBALL_ADDITIVE)
		g.draw_mode = Graphics.DRAWMODE_NORMAL
		fb.draw_render_group(g, RENDER_GROUP_BOSS_FIREBALL_TOP)
	g.translate(x, y)

func draw_boss_back_arm(g: Graphics, dp: DrawPosition) -> void:
	var ox := 0.0
	var oy := 0.0
	if zombie_phase == PvZ.PHASE_BOSS_DROP_RV:
		oy = (target_row - 1) * 85.0 - target_col * 20.0
		ox = target_col * 80.0
	elif zombie_phase == PvZ.PHASE_BOSS_BUNGEES_ENTER or zombie_phase == PvZ.PHASE_BOSS_BUNGEES_DROP or zombie_phase == PvZ.PHASE_BOSS_BUNGEES_LEAVE:
		ox = target_col * 80.0 - 23.0
	var r := body_reanim
	r.overlay_matrix.origin += Vector2(ox, oy)
	draw_reanim(g, dp, RENDER_GROUP_BOSS_BACK_ARM)
	r.overlay_matrix.origin -= Vector2(ox, oy)

func boss_rv_attack() -> void:
	remove_cold_effects()
	zombie_phase = PvZ.PHASE_BOSS_DROP_RV
	target_row = Tod.rand_range_int(0, 4 if board.stage_has_6_rows() else 3)
	target_col = Tod.rand_range_int(0, 2)
	play_zombie_reanim("anim_RV_1", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 16.0)
	App.play_foley(PvZ.FOLEY_HYDRAULIC_SHORT)

func boss_rv_landing() -> void:
	for p in board.plants.duplicate():
		if p.dead:
			continue
		if p.row >= target_row and p.row <= target_row + 1 and p.plant_col >= target_col and p.plant_col <= target_col + 2:
			p.squish()
	board.shake_board(1, 2)
	App.play_sample("SOUND_RVTHROW")
	summon_counter = 500
	boss_head_counter = 5000
	if boss_mode >= 1:
		boss_stomp_counter = 4000
	if boss_mode >= 2:
		boss_bungee_counter = 6500

func boss_spawn_attack() -> void:
	remove_cold_effects()
	zombie_phase = PvZ.PHASE_BOSS_SPAWNING
	if boss_mode == 0:
		summon_counter = Tod.rand_range_int(450, 550)
	elif boss_mode == 1:
		summon_counter = Tod.rand_range_int(350, 450)
	elif boss_mode == 2:
		summon_counter = Tod.rand_range_int(150, 250)
	target_row = board.pick_row_for_new_zombie(PvZ.ZOMBIE_NORMAL)
	var track := "anim_spawn_5"
	match target_row:
		0: track = "anim_spawn_1"
		1: track = "anim_spawn_2"
		2: track = "anim_spawn_3"
		3: track = "anim_spawn_4"
	play_zombie_reanim(track, Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 12.0)
	App.play_foley(PvZ.FOLEY_HYDRAULIC_SHORT)

func boss_spawn_contact() -> void:
	var zt: int
	if zombie_age < 3500:
		zt = PvZ.ZOMBIE_NORMAL
	elif zombie_age < 8000:
		zt = PvZ.ZOMBIE_TRAFFIC_CONE
	elif zombie_age < 12500:
		zt = PvZ.ZOMBIE_PAIL
	else:
		var list: Array = BOSS_ZOMBIE_LIST.duplicate()
		if target_row == 0:
			list.pop_back()
		zt = Tod.pick_from_array(list)
	var z := board.add_zombie_in_row(zt, target_row, 0)
	if z:
		z.pos_x = 600.0 + PvZ.BOARD_ADDITIONAL_WIDTH

func boss_stomp_attack() -> void:
	remove_cold_effects()
	zombie_phase = PvZ.PHASE_BOSS_STOMPING
	boss_stomp_counter = Tod.rand_range_int(5500, 6500)
	var rows: Array = []
	for i in 4:
		if boss_can_stomp_row(i):
			rows.append(i)
	if rows.is_empty():
		return
	target_row = Tod.pick_from_array(rows)
	var track := "anim_stomp_1"
	match target_row:
		0: track = "anim_stomp_1"
		1: track = "anim_stomp_2"
		2: track = "anim_stomp_3"
		3: track = "anim_stomp_4"
	play_zombie_reanim(track, Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 12.0)
	App.play_foley(PvZ.FOLEY_HYDRAULIC_SHORT)

func boss_can_stomp_row(the_row: int) -> bool:
	for p in board.plants:
		if not p.dead and not p.not_on_ground() and p.row >= the_row and p.row <= the_row + 1 and p.plant_col >= 5:
			return true
	return false

func boss_stomp_contact() -> void:
	for p in board.plants.duplicate():
		if not p.dead and p.row >= target_row and p.row <= target_row + 1 and p.plant_col >= 5:
			p.squish()
	board.shake_board(1, 4)
	App.play_foley(PvZ.FOLEY_THUMP)

func boss_bungee_attack() -> void:
	remove_cold_effects()
	zombie_phase = PvZ.PHASE_BOSS_BUNGEES_ENTER
	boss_bungee_counter = Tod.rand_range_int(4000, 5000)
	target_col = Tod.rand_range_int(0, 2)
	play_zombie_reanim("anim_bungee_1_enter", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 12.0)
	App.play_foley(PvZ.FOLEY_HYDRAULIC_SHORT)
	App.play_foley(PvZ.FOLEY_BUNGEE_SCREAM)

func boss_bungee_spawn() -> void:
	zombie_phase = PvZ.PHASE_BOSS_BUNGEES_DROP
	for i in NUM_BOSS_BUNGEES:
		var z := board.add_zombie_in_row(PvZ.ZOMBIE_BUNGEE, 0, 0)
		if z == null:
			continue
		z.pick_bungee_zombie_target(target_col + i)
		z.altitude = z.pos_y - 30.0
		follower_zombies[i] = z

func boss_bungee_leave() -> void:
	zombie_phase = PvZ.PHASE_BOSS_BUNGEES_LEAVE
	for i in NUM_BOSS_BUNGEES:
		var z := zv(follower_zombies[i])
		if z and not z.dead and z.buttered_counter > 0:
			z.die_with_loot()
	play_zombie_reanim("anim_bungee_1_leave", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 18.0)

func boss_are_bungees_done() -> bool:
	var remaining := 0
	for i in NUM_BOSS_BUNGEES:
		var z := zv(follower_zombies[i])
		if z:
			if z.zombie_phase == PvZ.PHASE_BUNGEE_RISING:
				return true
			remaining += 1
	return remaining == 0

func boss_head_attack() -> void:
	zombie_phase = PvZ.PHASE_BOSS_HEAD_ENTER
	boss_head_counter = Tod.rand_range_int(4000, 5000)
	play_zombie_reanim("anim_head_enter", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 12.0)
	App.play_foley(PvZ.FOLEY_HYDRAULIC_SHORT)

func boss_head_spit() -> void:
	var fb := rv(boss_fire_ball_reanim)
	if fb:
		fb.die()
		boss_fire_ball_reanim = null
	zombie_phase = PvZ.PHASE_BOSS_HEAD_SPIT
	fireball_row = Tod.rand_range_int(0, 5 if board.stage_has_6_rows() else 4)
	is_fire_ball = Tod.rand_range_int(0, 1) == 0
	var track := "anim_head_attack_5"
	match fireball_row:
		0: track = "anim_head_attack_1"
		1: track = "anim_head_attack_2"
		2: track = "anim_head_attack_3"
		3: track = "anim_head_attack_4"
	play_zombie_reanim(track, Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 20, 12.0)
	var r := body_reanim
	if is_fire_ball:
		r.set_image_override("Boss_eyeglow_red", null)
		r.set_image_override("Boss_mouthglow_red", null)
	else:
		r.set_image_override("Boss_eyeglow_red", Res.get_image("IMAGE_REANIM_ZOMBIE_BOSS_EYEGLOW_BLUE"))
		r.set_image_override("Boss_mouthglow_red", Res.get_image("IMAGE_REANIM_ZOMBIE_BOSS_MOUTHGLOW_BLUE"))
	special_head_reanim.play_reanim("anim_drive", Reanimation.REANIM_LOOP, 20, 36.0)

func boss_destroy_iceball_in_row(_the_row: int) -> void:
	var fb := rv(boss_fire_ball_reanim)
	if fb and not is_fire_ball:
		var px := fb.overlay_matrix.origin.x + 80.0
		var py := fb.overlay_matrix.origin.y + 80.0
		App.add_tod_particle(px, py, 400000, PvZ.PARTICLE_ICEBALL_DEATH)
		fb.die()
		boss_fire_ball_reanim = null
		board.remove_particle_by_type(PvZ.PARTICLE_ICEBALL_TRAIL)

func boss_destroy_fireball() -> void:
	var fb := rv(boss_fire_ball_reanim)
	if fb and is_fire_ball:
		var px := fb.overlay_matrix.origin.x + 80.0
		var py := fb.overlay_matrix.origin.y + 40.0
		for i in 6:
			var ang := 2 * PI * i / 6 + PI / 2
			var f := App.add_reanimation(px + 60.0 * sin(ang), py + 60.0 * cos(ang), 400000, PvZ.REANIM_JALAPENO_FIRE)
			f.anim_time = 0.2
			f.loop_type = Reanimation.REANIM_PLAY_ONCE_FULL_LAST_FRAME
			f.anim_rate = Tod.rand_range_float(20.0, 25.0)
		fb.die()
		boss_fire_ball_reanim = null
		board.remove_particle_by_type(PvZ.PARTICLE_FIREBALL_TRAIL)

func boss_head_spit_effect() -> void:
	var t := Reanimation.Transform.new()
	body_reanim.get_current_transform(body_reanim.find_track_index("Boss_jaw"), t)
	var fx := pos_x + t.tx + 100.0
	var fy := pos_y + t.ty + 50.0
	var ps := App.add_tod_particle(fx, fy, render_order + 2, PvZ.PARTICLE_ZOMBIE_BOSS_FIREBALL)
	if not is_fire_ball and ps:
		ps.override_image(null, Res.get_image("IMAGE_ZOMBIE_BOSS_ICEBALL_PARTICLES"))
	App.play_foley(PvZ.FOLEY_BOSS_BOULDER_ATTACK)

func boss_head_spit_contact() -> void:
	var py: float = board.get_pos_y_based_on_row(550.0, fireball_row) - 90.0
	var fb: Reanimation
	if is_fire_ball:
		fb = App.add_reanimation(455.0 + PvZ.BOARD_ADDITIONAL_WIDTH, py, render_order + 1, PvZ.REANIM_BOSS_FIREBALL)
		fb.play_reanim("anim_form", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 16.0)
		fb.is_attachment = true
		fb.assign_render_group_to_track("additive", RENDER_GROUP_BOSS_FIREBALL_ADDITIVE)
		fb.assign_render_group_to_track("superglow", RENDER_GROUP_BOSS_FIREBALL_ADDITIVE)
	else:
		fb = App.add_reanimation(455.0 + PvZ.BOARD_ADDITIONAL_WIDTH, py, render_order + 1, PvZ.REANIM_BOSS_ICEBALL)
		fb.play_reanim("anim_form", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 16.0)
		fb.is_attachment = true
		fb.assign_render_group_to_track("ice_highlight", RENDER_GROUP_BOSS_FIREBALL_ADDITIVE)
	boss_fire_ball_reanim = fb
	special_head_reanim.play_reanim("anim_laugh", Reanimation.REANIM_LOOP, 20, 18.0)
	App.play_foley(PvZ.FOLEY_HYDRAULIC_SHORT)

func update_boss_fireball() -> void:
	var fb := rv(boss_fire_ball_reanim)
	if fb == null:
		return
	var speed := fb.get_track_velocity("_ground")
	fb.overlay_matrix.origin.x -= speed
	var px := fb.overlay_matrix.origin.x
	var py: float = board.get_pos_y_based_on_row(px + 75.0, fireball_row) - 90.0
	fb.overlay_matrix.origin.y = py
	if px < -180.0 + PvZ.BOARD_ADDITIONAL_WIDTH:
		fb.die()
		boss_fire_ball_reanim = null
	squish_all_in_square(board.pixel_to_grid_x(int(px + 75), int(py)), fireball_row, ATTACKTYPE_DRIVE_OVER)
	for m in board.lawn_mowers:
		if not m.dead and m.mower_state != PvZ.MOWER_SQUISHED and m.row == fireball_row and m.pos_x > px and m.pos_x < px + 50.0:
			m.squish_mower()
	if fb.loop_type == Reanimation.REANIM_PLAY_ONCE_AND_HOLD and fb.loop_count > 0:
		fb.play_reanim("anim_role", Reanimation.REANIM_LOOP, 0, 2.0)
		fb.render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_PARTICLE, fireball_row, 0)
	if fb.loop_type == Reanimation.REANIM_LOOP and Tod.rand_int(10) == 0:
		var bx := px + 100.0 + Tod.rand_range_float(0.0, 20.0)
		var by: float = board.get_pos_y_based_on_row(bx - 40.0, fireball_row) + 90.0 + Tod.rand_range_float(-50.0, 0.0)
		var order := BoardCore.make_render_order(PvZ.RENDER_LAYER_GRAVE_STONE, fireball_row, 6)
		App.add_tod_particle(bx, by, order, PvZ.PARTICLE_FIREBALL_TRAIL if is_fire_ball else PvZ.PARTICLE_ICEBALL_TRAIL)
	fb.update()

func boss_start_death() -> void:
	zombie_phase = PvZ.PHASE_BOSS_HEAD_LEAVE
	play_zombie_reanim("anim_head_leave", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 24.0)
	App.add_tod_particle(700.0, 150.0, 400000, PvZ.PARTICLE_BOSS_EXPLOSION)
	App.play_sample("SOUND_BOSSEXPLOSION")
	App.play_foley(PvZ.FOLEY_GARGANTUDEATH)
	boss_die()

func update_boss() -> void:
	var r := rv(body_reanim)
	if App.game_scene == PvZ.SCENE_LEVEL_INTRO:
		if r.should_trigger_timed_event(0.24) or r.should_trigger_timed_event(0.79):
			App.play_foley(PvZ.FOLEY_THUMP)
			board.shake_board(1, 4)
		return
	var head := special_head_reanim
	update_boss_fireball()
	if ice_trap_counter == 0:
		if summon_counter > 0:
			summon_counter -= 1
		if boss_bungee_counter > 0:
			boss_bungee_counter -= 1
		if boss_stomp_counter > 0:
			boss_stomp_counter -= 1
		if boss_head_counter > 0:
			boss_head_counter -= 1
		if chilled_counter > 0:
			head.anim_rate = 6.0
		elif head.anim_rate == 0.0:
			head.anim_rate = 12.0
	else:
		head.anim_rate = 0.0
	match zombie_phase:
		PvZ.PHASE_BOSS_ENTER:
			boss_play_idle()
		PvZ.PHASE_BOSS_IDLE:
			if body_health == 1:
				play_death_anim(0)
				return
			if phase_counter > 0:
				return
			var dmg_index := get_body_damage_index()
			if dmg_index != boss_mode:
				boss_mode = dmg_index
				if boss_mode == 1:
					boss_bungee_attack()
				else:
					boss_rv_attack()
			elif boss_stomp_counter == 0:
				boss_stomp_attack()
			elif boss_bungee_counter == 0:
				if Tod.rand_int(4 if App.is_adventure_mode() else 2) == 0:
					boss_bungee_counter = Tod.rand_range_int(4000, 5000)
					boss_rv_attack()
				else:
					boss_bungee_attack()
			elif boss_head_counter == 0:
				boss_head_attack()
			elif summon_counter == 0:
				boss_spawn_attack()
			else:
				phase_counter = Tod.rand_range_int(100, 200)
		PvZ.PHASE_BOSS_SPAWNING:
			if r.should_trigger_timed_event(0.6):
				boss_spawn_contact()
			if r.loop_count > 0:
				boss_play_idle()
		PvZ.PHASE_BOSS_STOMPING:
			var trig := 0.55 if target_row >= 2 else 0.5
			if r.should_trigger_timed_event(trig):
				boss_stomp_contact()
			if r.loop_count > 0:
				boss_play_idle()
		PvZ.PHASE_BOSS_BUNGEES_ENTER:
			if r.should_trigger_timed_event(0.4):
				boss_bungee_spawn()
		PvZ.PHASE_BOSS_BUNGEES_DROP:
			if boss_are_bungees_done():
				boss_bungee_leave()
		PvZ.PHASE_BOSS_BUNGEES_LEAVE:
			if r.loop_count > 0:
				boss_play_idle()
		PvZ.PHASE_BOSS_DROP_RV:
			if r.should_trigger_timed_event(0.65):
				boss_rv_landing()
			if r.loop_count > 0:
				boss_play_idle()
		PvZ.PHASE_BOSS_HEAD_ENTER:
			if get_body_damage_index() == 2 and r.should_trigger_timed_event(0.37):
				apply_boss_smoke_particles(true)
			if r.should_trigger_timed_event(0.55):
				App.play_foley(PvZ.FOLEY_HYDRAULIC)
			if r.loop_count > 0:
				zombie_phase = PvZ.PHASE_BOSS_HEAD_IDLE_BEFORE_SPIT
				play_zombie_reanim("anim_head_idle", Reanimation.REANIM_LOOP, 0, 12.0)
				phase_counter = 500
		PvZ.PHASE_BOSS_HEAD_IDLE_BEFORE_SPIT:
			if body_health == 1:
				boss_start_death()
			elif phase_counter == 0:
				boss_head_spit()
		PvZ.PHASE_BOSS_HEAD_SPIT:
			if r.should_trigger_timed_event(0.37):
				boss_head_spit_effect()
			if r.should_trigger_timed_event(0.42):
				boss_head_spit_contact()
			if r.loop_count > 0:
				special_head_reanim.play_reanim("anim_idle", Reanimation.REANIM_LOOP, 20, 18.0)
				zombie_phase = PvZ.PHASE_BOSS_HEAD_IDLE_AFTER_SPIT
				play_zombie_reanim("anim_head_idle", Reanimation.REANIM_LOOP, 0, 12.0)
				phase_counter = 300
		PvZ.PHASE_BOSS_HEAD_IDLE_AFTER_SPIT:
			if body_health == 1:
				boss_start_death()
			elif phase_counter == 0:
				zombie_phase = PvZ.PHASE_BOSS_HEAD_LEAVE
				play_zombie_reanim("anim_head_leave", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 12.0)
		PvZ.PHASE_BOSS_HEAD_LEAVE:
			if r.should_trigger_timed_event(0.23):
				chilled_counter = 0
				update_anim_speed()
			if r.should_trigger_timed_event(0.48) or r.should_trigger_timed_event(0.8):
				App.play_foley(PvZ.FOLEY_THUMP)
			if r.loop_count > 0:
				apply_boss_smoke_particles(false)
				boss_play_idle()

func boss_die() -> void:
	if not is_on_board():
		return
	var fb := rv(boss_fire_ball_reanim)
	if fb:
		fb.die()
		boss_fire_ball_reanim = null
		boss_destroy_iceball_in_row(target_row)
		boss_destroy_fireball()
	App.music.fade_out(200)
	for z in board.zombies.duplicate():
		if z != self and not z.is_dead_or_dying():
			z.die_with_loot()
	remove_cold_effects()

func boss_setup_reanim() -> void:
	var r := body_reanim
	r.assign_render_group_to_prefix("Boss_innerleg", RENDER_GROUP_BOSS_BACK_LEG)
	r.assign_render_group_to_prefix("Boss_outerleg", RENDER_GROUP_BOSS_FRONT_LEG)
	r.assign_render_group_to_prefix("Boss_body2", RENDER_GROUP_BOSS_FRONT_LEG)
	r.assign_render_group_to_prefix("Boss_innerarm", RENDER_GROUP_BOSS_BACK_ARM)
	r.assign_render_group_to_prefix("Boss_RV", RENDER_GROUP_BOSS_BACK_ARM)
	var head := App.add_reanimation(0.0, 0.0, 0, PvZ.REANIM_BOSS_DRIVER)
	head.play_reanim("anim_idle", Reanimation.REANIM_LOOP, 0, 18.0)
	special_head_reanim = head
	var eff := Attachment.attach_reanim(r.get_track_instance("Boss_head2"), head, 28.0, -84.0)
	r.frame_base_pose = 0
	eff.offset.x.x = 1.2
	eff.offset.y.y = 1.2
	eff.dont_draw_if_parent_hidden = true

func draw_boss_part(g: Graphics, part: int) -> void:
	var dp := DrawPosition.new()
	get_draw_pos(dp)
	match part:
		PvZ.BOSS_PART_BACK_LEG: draw_reanim(g, dp, RENDER_GROUP_BOSS_BACK_LEG)
		PvZ.BOSS_PART_FRONT_LEG: draw_reanim(g, dp, RENDER_GROUP_BOSS_FRONT_LEG)
		PvZ.BOSS_PART_MAIN: draw_reanim(g, dp, 0)
		PvZ.BOSS_PART_BACK_ARM: draw_boss_back_arm(g, dp)
		PvZ.BOSS_PART_FIREBALL: draw_boss_fire_ball(g, dp)

func apply_boss_smoke_particles(enable: bool) -> void:
	var r := rv(body_reanim)
	var ti := r.get_track_instance("Boss_head")
	Attachment.detach_cross_fade_particle_type(ti, PvZ.PARTICLE_ZAMBONI_SMOKE, "")
	if enable:
		var p1 := App.add_tod_particle(0.0, 0.0, 0, PvZ.PARTICLE_ZAMBONI_SMOKE)
		var p2 := App.add_tod_particle(0.0, 0.0, 0, PvZ.PARTICLE_ZAMBONI_SMOKE)
		if p1:
			var e := r.attach_particle_to_track("Boss_head", p1, 120.0, 30.0)
			e.dont_draw_if_parent_hidden = true
			e.dont_propogate_color = true
		if p2:
			var e := r.attach_particle_to_track("Boss_head", p2, 205.0, 58.0)
			e.dont_draw_if_parent_hidden = true
			e.dont_propogate_color = true
		if body_health < Tod.idiv(body_max_health, BOSS_FLASH_HEALTH_FRACTION):
			var p3 := App.add_tod_particle(0.0, 0.0, 0, PvZ.PARTICLE_ZAMBONI_SMOKE)
			if p3:
				var e := r.attach_particle_to_track("Boss_head", p3, 193.0, 27.0)
				e.dont_draw_if_parent_hidden = true
				e.dont_propogate_color = true

# ================================================================ cheat codes / setup
func enable_mustache(on: bool) -> void:
	if from_wave == ZOMBIE_WAVE_UI:
		return
	if not has_head or Zombie.is_zombotany(zombie_type):
		return
	var r := rv(body_reanim)
	if r == null or not r.track_exists("Zombie_mustache"):
		return
	if on:
		r.assign_render_group_to_prefix("Zombie_mustache", Reanimation.RENDER_GROUP_NORMAL)
		match Tod.rand_range_int(1, 3):
			1: r.set_image_override("Zombie_mustache", null)
			2: r.set_image_override("Zombie_mustache", Res.get_image("IMAGE_REANIM_ZOMBIE_MUSTACHE2"))
			3: r.set_image_override("Zombie_mustache", Res.get_image("IMAGE_REANIM_ZOMBIE_MUSTACHE3"))
	else:
		r.assign_render_group_to_prefix("Zombie_mustache", Reanimation.RENDER_GROUP_HIDDEN)

static var _next_zombie_id := 0
var zombie_id := 0

func enable_future(on: bool) -> void:
	if from_wave == ZOMBIE_WAVE_UI or Zombie.is_zombotany(zombie_type):
		return
	var r := rv(body_reanim)
	if r == null or r.reanim_type != PvZ.REANIM_ZOMBIE:
		return
	if on:
		r.set_image_override("anim_head1", Res.get_image("IMAGE_REANIM_ZOMBIE_HEAD_SUNGLASSES%d" % (zombie_id % 4 + 1)))
	else:
		r.set_image_override("anim_head1", null)

func enable_dance(_on: bool) -> void:
	if not is_on_board():
		return
	if zombie_not_walking() or is_dead_or_dying():
		return
	if zombie_type == PvZ.ZOMBIE_NORMAL or zombie_type == PvZ.ZOMBIE_TRAFFIC_CONE or zombie_type == PvZ.ZOMBIE_PAIL:
		start_walk_anim(0)

func setup_water_track(track_name: String) -> void:
	var ti := body_reanim.get_track_instance(track_name)
	ti.ignore_extra_additive_color = true
	ti.ignore_color_override = true
	ti.ignore_clip_rect = true
