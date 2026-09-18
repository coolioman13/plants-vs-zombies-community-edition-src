class_name GridItem
extends RefCounted
## Port of GridItem (grave stones, craters, ladders, scary pots, rake, stinky, portals, brains...).

const NUM_MOTION_TRAIL_FRAMES := 12

var grid_item_type := PvZ.GRIDITEM_NONE
var grid_item_state := PvZ.GRIDITEM_STATE_NORMAL
var grid_x := 0
var grid_y := 0
var grid_item_counter := 0
var render_order := 0
var dead := false
var freed := false
var pos_x := 0.0
var pos_y := 0.0
var goal_x := 0.0
var goal_y := 0.0
var grid_item_reanim: Reanimation = null
var grid_item_particle: TodParticleSystem = null
var zombie_type := PvZ.ZOMBIE_INVALID
var seed_type := PvZ.SEED_NONE
var scary_pot_type := PvZ.SCARYPOT_NONE
var highlighted := false
var transparent_counter := 0
var sun_count := 0
## Online Versus grave placed by the zombie team (makes purple sun).
var vs_grave := false
## Each frame is [pos_x, pos_y, anim_time].
var motion_trail_frames: Array = []
var motion_trail_count := 0

func _init() -> void:
	for i in NUM_MOTION_TRAIL_FRAMES:
		motion_trail_frames.append([0.0, 0.0, 0.0])

func _reanim() -> Reanimation:
	if grid_item_reanim == null or grid_item_reanim.freed:
		return null
	return grid_item_reanim

func _particle() -> TodParticleSystem:
	if grid_item_particle == null or grid_item_particle.freed:
		return null
	return grid_item_particle

func grid_item_die() -> void:
	dead = true
	var r := _reanim()
	if r:
		r.die()
		grid_item_reanim = null
	var p := _particle()
	if p:
		p.particle_system_die()

func draw_grid_item_overlay(g: Graphics) -> void:
	var board: Board = App.board
	if grid_item_type == PvZ.GRIDITEM_STINKY:
		if board.cursor_object.cursor_type == PvZ.CURSOR_TYPE_CHOCOLATE and not App.zen_garden.is_stinky_high_on_chocolate():
			g.draw_image(Res.get_image("IMAGE_PLANTSPEECHBUBBLE"), pos_x + 50.0, pos_y - 36.0)
			g.tod_draw_image_scaled_f(Res.get_image("IMAGE_CHOCOLATE"), pos_x + 63.0, pos_y - 28.0, 0.44, 0.44)

func draw_grid_item(g: Graphics) -> void:
	match grid_item_type:
		PvZ.GRIDITEM_GRAVESTONE: draw_grave_stone(g)
		PvZ.GRIDITEM_CRATER: draw_crater(g)
		PvZ.GRIDITEM_LADDER: draw_ladder(g)
		PvZ.GRIDITEM_BRAIN: g.draw_image_f(Res.get_image("IMAGE_BRAIN"), pos_x, pos_y)
		PvZ.GRIDITEM_SCARY_POT: draw_scary_pot(g)
		PvZ.GRIDITEM_SQUIRREL: draw_squirrel(g)
		PvZ.GRIDITEM_STINKY: draw_stinky(g)
		PvZ.GRIDITEM_IZOMBIE_BRAIN: draw_izombie_brain(g)
		_:
			var r := _reanim()
			if r:
				r.draw(g)
	var p := _particle()
	if p:
		p.draw(g)

func draw_izombie_brain(g: Graphics) -> void:
	var board: Board = App.board
	var brain := Res.get_image("IMAGE_BRAIN")
	if grid_item_state == PvZ.GRIDITEM_STATE_BRAIN_SQUISHED:
		g.tod_draw_image_scaled_f(brain, pos_x, pos_y + 20.0, 1.0, 0.25)
		return
	if board.advice.duration > 0 and board.help_index == PvZ.ADVICE_I_ZOMBIE_EAT_ALL_BRAINS:
		g.colorize_images = true
		g.color = Tod.get_flashing_color(board.main_counter, 75)
	g.draw_image_f(brain, pos_x, pos_y)
	if transparent_counter > 0:
		g.draw_mode = Graphics.DRAWMODE_ADDITIVE
		g.colorize_images = true
		g.color = Color8(255, 255, 255, clampi(transparent_counter * 3, 0, 255))
		g.draw_image_f(brain, pos_x, pos_y)
		g.draw_mode = Graphics.DRAWMODE_NORMAL
	g.colorize_images = false

func draw_grave_stone(g: Graphics) -> void:
	if grid_item_counter <= 0:
		return
	var board: Board = App.board
	var tomb := Res.get_image("IMAGE_TOMBSTONES")
	var height_pos := Tod.animate_curve(0, 100, grid_item_counter, 1000, 0, Tod.CURVE_EASE_IN_OUT)
	var look: int = board.grid_cel_look[grid_x][grid_y]
	var off: Vector2i = board.grid_cel_offset[grid_x][grid_y]
	var cw := tomb.get_cel_width()
	var ch := tomb.get_cel_height()
	var col := look % 5
	var row: int
	if grid_y == 0:
		row = 1
	elif grid_item_state == PvZ.GRIDITEM_STATE_GRAVESTONE_SPECIAL:
		row = 0
	else:
		row = 2 + look % 2
	var visible_h := Tod.animate_curve(0, 1000, height_pos, ch, 0, Tod.CURVE_EASE_IN_OUT)
	var extra_bottom := Tod.animate_curve(0, 50, height_pos, 0, 14, Tod.CURVE_EASE_IN_OUT)
	var visible_h_dirt := Tod.animate_curve(500, 1000, height_pos, ch, 0, Tod.CURVE_EASE_IN_OUT)
	var extra_top := 0
	var plant := board.get_top_plant_at(grid_x, grid_y, PvZ.TOPPLANT_ONLY_NORMAL_POSITION)
	if plant and plant.state == PvZ.STATE_GRAVEBUSTER_EATING:
		extra_top = int(Tod.animate_curve_float(400, 0, plant.state_countdown, 10.0, 40.0, Tod.CURVE_LINEAR))
	var src := Rect2(cw * col, ch * row + extra_top, cw, visible_h - extra_bottom - extra_top)
	var src_dirt := Rect2(cw * col, ch * row, cw, visible_h_dirt)
	var px := board.grid_to_pixel_x(grid_x, grid_y) + off.x - 4
	var py := board.grid_to_pixel_y(grid_x, grid_y) + ch + off.y - 9
	g.draw_image_src(tomb, px, py - visible_h + extra_top, src)
	g.draw_image_src(Res.get_image("IMAGE_TOMBSTONE_MOUNDS"), px, py - visible_h_dirt, src_dirt)

func draw_stinky(g: Graphics) -> void:
	var r := _reanim()
	if r == null:
		return
	var original_time := r.anim_time
	for i in range(motion_trail_count - 1, -1, -1):
		if i % 2 != 0:
			var f: Array = motion_trail_frames[i]
			var dx: float = f[0] - pos_x
			var dy: float = f[1] - pos_y
			g.color = Color8(255, 255, 255, Tod.animate_curve(0, 11, i, 64, 16, Tod.CURVE_LINEAR))
			g.colorize_images = true
			r.anim_time = f[2]
			g.trans_x += dx
			g.trans_y += dy
			r.draw(g)
			g.colorize_images = false
			g.trans_x -= dx
			g.trans_y -= dy
	r.anim_time = original_time
	if grid_item_type == PvZ.GRIDITEM_STINKY and highlighted:
		r.enable_extra_additive_draw = true
		r.extra_additive_color = Color8(255, 255, 255, 196)
	r.draw(g)
	r.enable_extra_additive_draw = false

func draw_crater(g: Graphics) -> void:
	var board: Board = App.board
	var px := board.grid_to_pixel_x(grid_x, grid_y) - 8.0
	var py := board.grid_to_pixel_y(grid_x, grid_y) + 40.0
	if grid_item_counter < 25:
		g.color = Color8(255, 255, 255, Tod.animate_curve(25, 0, grid_item_counter, 255, 0, Tod.CURVE_LINEAR))
		g.colorize_images = true
	var fading := grid_item_counter < 9000
	var img := "IMAGE_CRATER"
	var cel := 0
	if board.is_pool_square(grid_x, grid_y):
		img = "IMAGE_CRATER_WATER_NIGHT" if board.stage_is_night() else "IMAGE_CRATER_WATER_DAY"
		if fading:
			cel = 1
		var phase := grid_y * PI + grid_x * PI * 0.25
		var t := board.main_counter * PI * 2.0 / 200.0
		py += sin(phase + t) * 2.0
	elif board.stage_has_roof():
		if grid_x < 5:
			img = "IMAGE_CRATER_ROOF_LEFT"
			px += 16.0
			py += -16.0
		else:
			img = "IMAGE_CRATER_ROOF_CENTER"
			px += 18.0
			py += -9.0
		if fading:
			cel = 1
	elif board.stage_is_night():
		cel = 1
		if fading:
			img = "IMAGE_CRATER_FADING"
	elif fading:
		img = "IMAGE_CRATER_FADING"
	g.tod_draw_image_cel_f(Res.get_image(img), px, py, cel, 0)
	g.colorize_images = false

func draw_scary_pot(g: Graphics) -> void:
	var board: Board = App.board
	var pot := Res.get_image("IMAGE_SCARY_POT")
	var col := grid_item_state - PvZ.GRIDITEM_STATE_SCARY_POT_QUESTION
	var px := board.grid_to_pixel_x(grid_x, grid_y) - 5
	var py := board.grid_to_pixel_y(grid_x, grid_y) - 15
	g.tod_draw_image_cel_center_scaled_f(Res.get_image("IMAGE_PLANTSHADOW2"), px - 5.0, py + 72.0, 0, 1.3, 1.3)
	if transparent_counter > 0:
		g.draw_image_cel_rc(pot, px, py, col, 0)
		var ig := g.copy()
		if scary_pot_type == PvZ.SCARYPOT_SEED:
			ig.scale_x = 0.7
			ig.scale_y = 0.7
			SeedPacket.draw_seed_packet(ig, px + 23.0, py + 33.0, seed_type, PvZ.SEED_NONE, 0.0, 255, false, false)
		elif scary_pot_type == PvZ.SCARYPOT_ZOMBIE:
			ig.scale_x = 0.4
			ig.scale_y = 0.4
			var ox := 6.0
			var oy := 19.0
			if zombie_type == PvZ.ZOMBIE_FOOTBALL:
				ox = 1.0
				oy = 16.0
			if zombie_type == PvZ.ZOMBIE_GARGANTUAR:
				ig.scale_x = 0.3
				ig.scale_y = 0.3
				ox += 9.0
				oy += 7.0
			ReanimatorCache.draw_cached_zombie(ig, px + ox, py + oy, zombie_type)
		elif scary_pot_type == PvZ.SCARYPOT_SUN:
			var suns: int = board.challenge.scary_potter_count_sun_in_pot(self)
			var sun := Reanimation.new()
			sun.initialize(0.0, 0.0, ReanimTypes.get_def(PvZ.REANIM_SUN))
			sun.override_scale(0.5, 0.5)
			for i in suns:
				var ox := 42.0
				var oy := 62.0
				match i:
					1: ox += 3.0; oy -= 20.0
					2: ox -= 6.0; oy -= 10.0
					3: ox += 6.0; oy -= 5.0
					4: ox += 5.0; oy -= 15.0
				sun.set_position(px + ox, py + oy)
				sun.draw(g)
		g.colorize_images = true
		g.color = Color8(255, 255, 255, Tod.animate_curve(0, 50, transparent_counter, 255, 58, Tod.CURVE_LINEAR))
	g.draw_image_cel_rc(pot, px, py, col, 1)
	if highlighted and not board.paused:
		g.draw_mode = Graphics.DRAWMODE_ADDITIVE
		g.colorize_images = true
		if transparent_counter == 0:
			g.color = Color8(255, 255, 255, 196)
		g.draw_image_cel_rc(pot, px, py, col, 1)
		g.draw_mode = Graphics.DRAWMODE_NORMAL
	g.colorize_images = false

func draw_ladder(g: Graphics) -> void:
	var board: Board = App.board
	var px := board.grid_to_pixel_x(grid_x, grid_y)
	var py := board.grid_to_pixel_y(grid_x, grid_y)
	g.tod_draw_image_scaled_f(Res.get_image("IMAGE_REANIM_ZOMBIE_LADDER_5"), px + 25.0, py - 4.0, 0.8, 0.8)

func draw_squirrel(g: Graphics) -> void:
	var board: Board = App.board
	var px := board.grid_to_pixel_x(grid_x, grid_y)
	var py := board.grid_to_pixel_y(grid_x, grid_y)
	match grid_item_state:
		PvZ.GRIDITEM_STATE_SQUIRREL_PEEKING: py += Tod.animate_curve(50, 0, grid_item_counter, 0, -40, Tod.CURVE_BOUNCE_SLOW_MIDDLE)
		PvZ.GRIDITEM_STATE_SQUIRREL_RUNNING_UP: py += Tod.animate_curve(50, 0, grid_item_counter, 100, 0, Tod.CURVE_EASE_IN)
		PvZ.GRIDITEM_STATE_SQUIRREL_RUNNING_DOWN: py += Tod.animate_curve(50, 0, grid_item_counter, -100, 0, Tod.CURVE_EASE_IN)
		PvZ.GRIDITEM_STATE_SQUIRREL_RUNNING_LEFT: px += Tod.animate_curve(50, 0, grid_item_counter, 80, 0, Tod.CURVE_EASE_IN)
		PvZ.GRIDITEM_STATE_SQUIRREL_RUNNING_RIGHT: px += Tod.animate_curve(50, 0, grid_item_counter, -80, 0, Tod.CURVE_EASE_IN)
	if Res.has_image("IMAGE_SQUIRREL"):
		g.draw_image(Res.get_image("IMAGE_SQUIRREL"), px, py)

func add_grave_stone_particles() -> void:
	var board: Board = App.board
	var off: Vector2i = board.grid_cel_offset[grid_x][grid_y]
	var px := board.grid_to_pixel_x(grid_x, grid_y) + 14 + off.x
	var py := board.grid_to_pixel_y(grid_x, grid_y) + 78 + off.y
	App.add_tod_particle(px, py, render_order + 1, PvZ.PARTICLE_GRAVE_STONE_RISE)
	App.play_foley(PvZ.FOLEY_DIRT_RISE)

func open_portal() -> void:
	var board: Board = App.board
	var px := grid_x * 80.0 - 6.0 + PvZ.BOARD_ADDITIONAL_WIDTH
	var py := board.grid_to_pixel_y(0, grid_y) - 65.0
	var r := _reanim()
	if r == null:
		var rt := PvZ.REANIM_PORTAL_CIRCLE
		if grid_item_type == PvZ.GRIDITEM_PORTAL_SQUARE:
			py += 25.0
			px -= 4.0
			rt = PvZ.REANIM_PORTAL_SQUARE
		r = App.add_reanimation(px, py, 0, rt)
		r.is_attachment = true
		grid_item_reanim = r
	else:
		r.set_position(px, py)
	var p := _particle()
	if p:
		p.particle_system_die()
		grid_item_particle = null
	r.play_reanim("anim_appear", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 12.0)
	App.play_foley(PvZ.FOLEY_PORTAL)

func close_portal() -> void:
	var r := _reanim()
	if r:
		r.play_reanim("anim_disappear", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 12.0)
	var p := _particle()
	if p:
		p.particle_system_die()
		grid_item_particle = null
	grid_item_state = PvZ.GRIDITEM_STATE_PORTAL_CLOSED

func is_open_portal() -> bool:
	return grid_item_state != PvZ.GRIDITEM_STATE_PORTAL_CLOSED and (grid_item_type == PvZ.GRIDITEM_PORTAL_CIRCLE or grid_item_type == PvZ.GRIDITEM_PORTAL_SQUARE)

func update_portal() -> void:
	var r := _reanim()
	if r == null:
		return
	if grid_item_state == PvZ.GRIDITEM_STATE_PORTAL_CLOSED:
		if r.loop_count > 0:
			grid_item_die()
	elif r.loop_type == Reanimation.REANIM_PLAY_ONCE_AND_HOLD and r.loop_count > 0:
		r.play_reanim("anim_pulse", Reanimation.REANIM_LOOP, 0, 12.0)
		var effect := PvZ.PARTICLE_PORTAL_CIRCLE
		var px := grid_x * 80.0 + 13.0 + PvZ.BOARD_ADDITIONAL_WIDTH
		var py: float = App.board.grid_to_pixel_y(0, grid_y) - 39.0
		if grid_item_type == PvZ.GRIDITEM_PORTAL_SQUARE:
			effect = PvZ.PARTICLE_PORTAL_SQUARE
			px -= 8.0
			py += 15.0
		grid_item_particle = App.add_tod_particle(px, py, 0, effect)

func update_scary_pot() -> void:
	if App.tod_cheat_keys and App.widget_manager.is_key_down(WidgetManager.KEYCODE_SHIFT):
		if transparent_counter < 50:
			transparent_counter += 1
		return
	var board: Board = App.board
	for p in board.plants:
		if not p.dead and p.seed_type == PvZ.SEED_PLANTERN and not p.not_on_ground():
			if maxi(absi(p.plant_col - grid_x), absi(p.row - grid_y)) <= 1:
				if transparent_counter < 50:
					transparent_counter += 1
				return
	if transparent_counter > 0:
		transparent_counter -= 1

func update_brain() -> void:
	if grid_item_state == PvZ.GRIDITEM_STATE_BRAIN_SQUISHED:
		grid_item_counter -= 1
		if grid_item_counter <= 0:
			grid_item_die()
	if transparent_counter > 0:
		transparent_counter -= 1

func update() -> void:
	var r := _reanim()
	if r:
		r.update()
	var p := _particle()
	if p:
		p.update()
	match grid_item_type:
		PvZ.GRIDITEM_PORTAL_CIRCLE, PvZ.GRIDITEM_PORTAL_SQUARE: update_portal()
		PvZ.GRIDITEM_SCARY_POT: update_scary_pot()
		PvZ.GRIDITEM_RAKE: update_rake()
		PvZ.GRIDITEM_IZOMBIE_BRAIN: update_brain()

func rake_find_zombie() -> Zombie:
	var board: Board = App.board
	var rake_rect := Rect2i(int(pos_x), int(pos_y), 63, 80)
	for z in board.zombies:
		if not z.dead and not z.is_dead_or_dying() and not z.is_bobsled_team_with_sled() and z.row == grid_y and z.effected_by_damage(1):
			if LawnCommon.get_rect_overlap(rake_rect, z.get_zombie_rect()) >= 0:
				return z
	return null

func update_rake() -> void:
	if grid_item_state == PvZ.GRIDITEM_STATE_RAKE_ATTRACTING or grid_item_state == PvZ.GRIDITEM_STATE_RAKE_WAITING:
		if rake_find_zombie():
			var r := _reanim()
			if r:
				r.anim_rate = 20.0
			grid_item_counter = 200
			grid_item_state = PvZ.GRIDITEM_STATE_RAKE_TRIGGERED
			App.play_foley(PvZ.FOLEY_SWING)
	elif grid_item_state == PvZ.GRIDITEM_STATE_RAKE_TRIGGERED:
		var r := _reanim()
		if r and r.should_trigger_timed_event(0.8):
			var z := rake_find_zombie()
			if z:
				z.take_damage(1800, 0)
				App.play_foley(PvZ.FOLEY_BONK)
		grid_item_counter -= 1
		if grid_item_counter == 0:
			grid_item_die()
