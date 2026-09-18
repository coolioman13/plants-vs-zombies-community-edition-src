extends Node2D

var target: RenderTarget
var pea: Reanimation
var zombie: Reanimation
var sun: Reanimation
var ps: TodParticleSystem
var bg: PvzImage
var font: ImageFont
var ticks := 0
var shot_at := 60

func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	Res.init()
	TodStrings.load_dir("res://languages")
	print("res init ms ", Time.get_ticks_msec() - t0)
	target = RenderTarget.new(get_canvas_item())
	bg = Res.get_image("IMAGE_BACKGROUND1")
	t0 = Time.get_ticks_msec()
	pea = EffectSystem.alloc_reanimation(560, 250, 0, PvZ.REANIM_PEASHOOTER)
	pea.play_reanim("anim_idle", Reanimation.REANIM_LOOP, 0, 0)
	zombie = EffectSystem.alloc_reanimation(760, 220, 0, PvZ.REANIM_ZOMBIE)
	zombie.play_reanim("anim_walk", Reanimation.REANIM_LOOP, 0, 0)
	for tr in ["anim_cone", "anim_bucket", "anim_screendoor", "Zombie_flaghand", "Zombie_innerarm_screendoor", "Zombie_innerarm_screendoor_hand", "Zombie_outerarm_screendoor", "anim_tongue", "Zombie_mustache", "Zombie_duckytube", "Zombie_whitewater", "Zombie_whitewater2", "anim_hair"]:
		if zombie.track_exists(tr):
			zombie.get_track_instance(tr).render_group = Reanimation.RENDER_GROUP_HIDDEN
	sun = EffectSystem.alloc_reanimation(400, 100, 0, PvZ.REANIM_SUN)
	sun.loop_type = Reanimation.REANIM_LOOP
	print("reanim load ms ", Time.get_ticks_msec() - t0)
	ps = EffectSystem.alloc_particle_system(600, 400, 0, PvZ.PARTICLE_POOL_SPARKLY)
	font = Res.get_font("FONT_HOUSEOFTERROR28")
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		shot_at = int(args[0])

func _physics_process(_d: float) -> void:
	EffectSystem.update()
	ticks += 1
	if ticks == 40 and ps != null:
		pass

func _process(_d: float) -> void:
	target.begin_frame()
	Graphics.reset_frame_state()
	var g := Graphics.new(target)
	g.draw_image(bg, -220, 0)
	pea.draw(g)
	zombie.draw(g)
	sun.draw(g)
	ps.draw(g)
	g.draw_mode = Graphics.DRAWMODE_NORMAL
	TodStrings.draw_string(g, "Plants vs. Zombies", 640, 100, font, Color8(255, 255, 0), TodStrings.DS_ALIGN_CENTER)
	TodStrings.draw_string_wrapped(g, "[PEASHOOTER_DESCRIPTION]", Rect2i(40, 450, 400, 260), Res.get_font("FONT_BRIANNETOD12"), Color.WHITE, TodStrings.DS_ALIGN_LEFT)
	if Engine.get_process_frames() == shot_at:
		await RenderingServer.frame_post_draw
		get_viewport().get_texture().get_image().save_png("user://render_test.png")
		print("saved ", ProjectSettings.globalize_path("user://render_test.png"))
		get_tree().quit()
