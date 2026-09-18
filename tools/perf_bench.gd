extends Node
## Headless stress benchmark: a full day lawn of plants against a huge wave, timing the simulation and draw.
## godot --headless --path . res://tools/perf_bench.tscn [-- zombies=400 frames=600]

const TEST_PROFILE := "PerfBench"

func _ready() -> void:
	App.set_process(false)
	await get_tree().process_frame
	_run()
	get_tree().quit()

func _pump(updates: int) -> void:
	for i in updates:
		App._run_loading_tasks()
		App.update_frames()
		if i % 5 == 0:
			App._draw_frame()

func _arg(name: String, def: int) -> int:
	for a in OS.get_cmdline_user_args():
		if a.begins_with(name + "="):
			return int(a.substr(name.length() + 1))
	return def

func _run() -> void:
	var guard := 0
	while not App.loading_thread_completed and guard < 20000:
		_pump(10)
		guard += 10
	var made_profile := false
	if App.player_info == null:
		App.player_info = App.profile_mgr.add_profile(TEST_PROFILE)
		made_profile = true
	App.loading_completed()
	_pump(50)

	var zombie_count := _arg("zombies", 400)
	var frames := _arg("frames", 600)
	App.quick_level = 4
	App.start_quick_play()
	var picked := false
	for i in 1000:
		_pump(10)
		if not picked and App.seed_chooser_screen != null and App.board.cut_scene.cutscene_time > 3000:
			picked = true
			App.seed_chooser_screen.pick_random_seeds()
		if App.game_scene == PvZ.SCENE_PLAYING:
			break
	var board: Board = App.board
	print("scene=", App.game_scene, " level=", board.level, " cutscene_time=", board.cut_scene.cutscene_time, " chooser=", App.seed_chooser_screen)
	App.widget_manager.on_mouse_move(400, 300)

	seed(1234)
	var plant_types := [PvZ.SEED_REPEATER, PvZ.SEED_SNOWPEA, PvZ.SEED_PEASHOOTER, PvZ.SEED_WALLNUT, PvZ.SEED_SUNFLOWER]
	for gy in 5:
		for gx in 6:
			board.new_plant(gx, gy, plant_types[(gx + gy) % plant_types.size()], PvZ.SEED_NONE)
	var zombie_types := [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE, PvZ.ZOMBIE_PAIL, PvZ.ZOMBIE_FOOTBALL, PvZ.ZOMBIE_DOOR]
	var spawned := 0
	for i in zombie_count:
		var z := board.add_zombie_in_row(zombie_types[i % zombie_types.size()], i % 5, 1, true)
		if z:
			z.pos_x = 500.0 + randf() * 500.0 + PvZ.BOARD_ADDITIONAL_WIDTH
			z.x = int(z.pos_x)
			spawned += 1
	board.sun_money = 0
	print("plants=", board.plants.size(), " zombies=", spawned)

	var upd_us := 0
	var draw_us := 0
	var worst_upd := 0
	var worst_draw := 0
	for f in frames:
		var t0 := Time.get_ticks_usec()
		App.update_frames()
		var t1 := Time.get_ticks_usec()
		App._draw_frame()
		var t2 := Time.get_ticks_usec()
		upd_us += t1 - t0
		draw_us += t2 - t1
		worst_upd = maxi(worst_upd, t1 - t0)
		worst_draw = maxi(worst_draw, t2 - t1)
		if App.board == null or App.game_scene != PvZ.SCENE_PLAYING:
			print("stopped at frame ", f)
			frames = f + 1
			break
	var alive := 0
	if App.board:
		for z in App.board.zombies:
			if not z.dead:
				alive += 1
	print("BENCH update avg %.2f ms (worst %.2f)  draw avg %.2f ms (worst %.2f)  frames=%d zombies_left=%d particles=%d reanims=%d" % [
		upd_us / 1000.0 / frames, worst_upd / 1000.0, draw_us / 1000.0 / frames, worst_draw / 1000.0, frames, alive,
		EffectSystem.particle_systems.size(), EffectSystem.reanimations.size()])
	if App.board and _arg("profile", 0) != 0:
		_profile(App.board, 100)
		_profile_zombie_parts(App.board, 50)
		_profile_draw_calls(App.board)
		_profile_misc(App.board, 30)
		_profile_track_draw(App.board)
	App.kill_board()
	if made_profile:
		App.profile_mgr.delete_profile(TEST_PROFILE)
		App.player_info = null

## Rough breakdown: runs each piece of the frame on its own (the simulation keeps advancing, so numbers are relative).
func _profile(board: Board, n: int) -> void:
	var t := {}
	var add := func(k: String, us: int) -> void: t[k] = t.get(k, 0) + us
	for f in n:
		var t0 := Time.get_ticks_usec()
		for p in board.plants.duplicate():
			if not p.dead: p.update()
		var t1 := Time.get_ticks_usec(); add.call("plants", t1 - t0)
		for z in board.zombies.duplicate():
			if not z.dead: z.update()
		var t2 := Time.get_ticks_usec(); add.call("zombies", t2 - t1)
		for pr in board.projectiles.duplicate():
			if not pr.dead: pr.update()
		var t3 := Time.get_ticks_usec(); add.call("projectiles", t3 - t2)
		EffectSystem.update()
		var t4 := Time.get_ticks_usec(); add.call("effects", t4 - t3)
		board.process_delete_queue()
		EffectSystem.process_delete_queue()
		var t5 := Time.get_ticks_usec(); add.call("delete_queues", t5 - t4)
		App._target.begin_frame()
		Graphics.reset_frame_state()
		var g := Graphics.new(App._target)
		var t6 := Time.get_ticks_usec()
		for z in board.zombies:
			if not z.dead and z.begin_draw(g):
				z.draw(g)
				z.end_draw(g)
		var t7 := Time.get_ticks_usec(); add.call("draw_zombies", t7 - t6)
		for z in board.zombies:
			if not z.dead and z.has_shadow() and z.begin_draw(g):
				z.draw_shadow(g)
				z.end_draw(g)
		var t8 := Time.get_ticks_usec(); add.call("draw_zombie_shadows", t8 - t7)
		for p in board.plants:
			if not p.dead and p.begin_draw(g):
				p.draw(g)
				p.end_draw(g)
		var t9 := Time.get_ticks_usec(); add.call("draw_plants", t9 - t8)
		App._target.end_frame()
	var keys := t.keys()
	keys.sort_custom(func(a, b): return t[a] > t[b])
	for k in keys:
		print("PROFILE %-22s %.2f ms/frame" % [k, t[k] / 1000.0 / n])

func _profile_zombie_parts(board: Board, n: int) -> void:
	var names := ["update_playing", "is_immobilizied", "is_dead_or_dying", "update_reanim", "animate", "update_actions", "update_zombie_position", "check_if_prey_caught", "check_for_pool",
		"check_for_high_ground", "check_for_board_edge", "get_zombie_rect"]
	var t := {}
	for f in n:
		for nm in names:
			var t0 := Time.get_ticks_usec()
			for z in board.zombies:
				if not z.dead:
					z.call(nm)
			t[nm] = t.get(nm, 0) + Time.get_ticks_usec() - t0
		var t1 := Time.get_ticks_usec()
		for z in board.zombies:
			if not z.dead:
				var r: Reanimation = z.body_reanim
				if r: r.update()
		t["reanim.update only"] = t.get("reanim.update only", 0) + Time.get_ticks_usec() - t1
		var t2 := Time.get_ticks_usec()
		for z in board.zombies:
			if not z.dead:
				var r: Reanimation = z.body_reanim
				if r: r.propogate_color_to_attachments()
		t["propogate_color"] = t.get("propogate_color", 0) + Time.get_ticks_usec() - t2
		var t3 := Time.get_ticks_usec()
		for z in board.zombies:
			if not z.dead:
				Attachment.update_and_move(z, z.pos_x, z.pos_y)
		t["attachment_move"] = t.get("attachment_move", 0) + Time.get_ticks_usec() - t3
	var keys := t.keys()
	keys.sort_custom(func(a, b): return t[a] > t[b])
	for k in keys:
		print("ZPART %-24s %.2f ms/frame" % [k, t[k] / 1000.0 / n])

func _profile_draw_calls(board: Board) -> void:
	# how many blits the zombies make, and what the raw RenderingServer calls cost on their own
	var counter := {"n": 0}
	App._target.begin_frame()
	Graphics.reset_frame_state()
	var g := Graphics.new(App._target)
	var t0 := Time.get_ticks_usec()
	for z in board.zombies:
		if not z.dead and z.begin_draw(g):
			z.draw(g)
			z.end_draw(g)
	var t1 := Time.get_ticks_usec()
	var segs := App._target.cur + 1
	App._target.begin_frame()
	var seg: RID = App._target.segments[0]
	var img := Res.get_image("IMAGE_REANIM_ZOMBIE_HEAD")
	var t2 := Time.get_ticks_usec()
	for i in 8000:
		RenderingServer.canvas_item_add_set_transform(seg, Transform2D(0.1 * i, Vector2(i % 800, 300)))
		RenderingServer.canvas_item_add_texture_rect_region(seg, Rect2(0, 0, 40, 40), img.rid, Rect2(0, 0, 40, 40), Color.WHITE, false, true)
	var t3 := Time.get_ticks_usec()
	RenderingServer.canvas_item_clear(seg)
	print("DRAWCALLS zombies draw %.2f ms, segments used %d; 8000 raw set_transform+rect pairs %.2f ms" % [(t1 - t0) / 1000.0, segs, (t3 - t2) / 1000.0])

func _profile_misc(board: Board, n: int) -> void:
	var t0 := Time.get_ticks_usec()
	for f in n:
		for z in board.zombies:
			board.cut_scene.should_run_upsell_board()
	var t1 := Time.get_ticks_usec()
	for f in n:
		for z in board.zombies:
			z.update()
	var t2 := Time.get_ticks_usec()
	print("MISC should_run_upsell_board x zombies %.2f ms/frame, zombie.update %.2f ms/frame" % [(t1 - t0) / 1000.0 / n, (t2 - t1) / 1000.0 / n])

func _profile_track_draw(board: Board) -> void:
	var z: Zombie = null
	for zz in board.zombies:
		if not zz.dead and zz.zombie_type == PvZ.ZOMBIE_NORMAL:
			z = zz
			break
	var r = z.body_reanim
	var list = r.call("_tracks_in_group", 0) if r.has_method("_tracks_in_group") else range(r.definition.tracks.size())
	var n := 0
	App._target.begin_frame()
	Graphics.reset_frame_state()
	var g := Graphics.new(App._target)
	r.get_frame_time()
	var reps := 400
	var t0 := Time.get_ticks_usec()
	for k in reps:
		for i in list:
			if r.has_method("_draw_track_at_frame_time"): r.call("_draw_track_at_frame_time", g, i)
			else: r.draw_track(g, i, 0)
	var t1 := Time.get_ticks_usec()
	var tr = Reanimation.Transform.new()
	for k in reps:
		for i in list:
			r.get_transform_at_time(i, tr, r._ft_fraction, r._ft_before, r._ft_after)
	var t2 := Time.get_ticks_usec()
	for k in reps:
		for i in list:
			Reanimation.matrix_from_transform(tr)
	var t3 := Time.get_ticks_usec()
	var img := Res.get_image("IMAGE_REANIM_ZOMBIE_HEAD")
	var m := Transform2D(0.3, Vector2(100, 100))
	for k in reps:
		for i in list:
			g.blt_matrix(img, m, g.clip, Color.WHITE, 0, Rect2(0, 0, 30, 30))
	var t4 := Time.get_ticks_usec()
	var drawn := 0
	for i in list:
		if r.call("_draw_track_at_frame_time", g, i) if r.has_method("_draw_track_at_frame_time") else r.draw_track(g, i, 0):
			drawn += 1
	App._target.begin_frame()
	var cnt: int = reps * list.size()
	print("TRACK list=%d drawn=%d/%d  per track: whole %.2f us, lerp %.2f us, matrix %.2f us, blt %.2f us" % [list.size(), drawn, r.definition.tracks.size(),
		float(t1 - t0) / cnt, float(t2 - t1) / cnt, float(t3 - t2) / cnt, float(t4 - t3) / cnt])
