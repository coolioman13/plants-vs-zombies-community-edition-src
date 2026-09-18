class_name TodParticleSystem
extends RefCounted
## Port of TodParticleSystem / TodParticleEmitter / TodParticle.

enum { PARTICLE_RANDOM_LAUNCH_SPIN, PARTICLE_ALIGN_LAUNCH_SPIN, PARTICLE_ALIGN_TO_PIXELS, PARTICLE_SYSTEM_LOOPS,
	PARTICLE_PARTICLE_LOOPS, PARTICLE_PARTICLES_DONT_FOLLOW, PARTICLE_RANDOM_START_TIME, PARTICLE_DIE_IF_OVERLOADED,
	PARTICLE_ADDITIVE, PARTICLE_FULLSCREEN, PARTICLE_SOFTWARE_ONLY, PARTICLE_HARDWARE_ONLY }
enum { FIELD_INVALID, FIELD_FRICTION, FIELD_ACCELERATION, FIELD_ATTRACTOR, FIELD_MAX_VELOCITY, FIELD_VELOCITY,
	FIELD_POSITION, FIELD_SYSTEM_POSITION, FIELD_GROUND_CONSTRAINT, FIELD_SHAKE, FIELD_CIRCLE, FIELD_AWAY }
enum { EMITTER_CIRCLE, EMITTER_BOX, EMITTER_BOX_PATH, EMITTER_CIRCLE_PATH, EMITTER_CIRCLE_EVEN_SPACING }
enum { TRACK_SPAWN_RATE, TRACK_SPAWN_MIN_ACTIVE, TRACK_SPAWN_MAX_ACTIVE, TRACK_SPAWN_MAX_LAUNCHED, TRACK_EMITTER_PATH,
	TRACK_SYSTEM_RED, TRACK_SYSTEM_GREEN, TRACK_SYSTEM_BLUE, TRACK_SYSTEM_ALPHA, TRACK_SYSTEM_BRIGHTNESS }
enum { TRACK_PARTICLE_RED, TRACK_PARTICLE_GREEN, TRACK_PARTICLE_BLUE, TRACK_PARTICLE_ALPHA, TRACK_PARTICLE_BRIGHTNESS,
	TRACK_PARTICLE_SPIN_SPEED, TRACK_PARTICLE_SPIN_ANGLE, TRACK_PARTICLE_SCALE, TRACK_PARTICLE_STRETCH,
	TRACK_PARTICLE_COLLISION_REFLECT, TRACK_PARTICLE_COLLISION_SPIN, TRACK_PARTICLE_CLIP_TOP, TRACK_PARTICLE_CLIP_BOTTOM,
	TRACK_PARTICLE_CLIP_LEFT, TRACK_PARTICLE_CLIP_RIGHT, TRACK_PARTICLE_ANIMATION_RATE }
const MAX_PARTICLES_SIZE := 900

class Particle:
	var emitter: Emitter
	var duration := 0
	var age := 0
	var time_value := 0.0
	var last_time_value := 0.0
	var animation_time_value := 0.0
	var velocity := Vector2.ZERO
	var position := Vector2.ZERO
	var image_frame := 0
	var spin_position := 0.0
	var spin_velocity := 0.0
	var cross_fade_particle: Particle = null
	var cross_fade_duration := 0
	var interp := PackedFloat32Array()
	var field_interp := PackedFloat32Array()
	var freed := false

class RenderParams:
	var red_set := false
	var green_set := false
	var blue_set := false
	var alpha_set := false
	var scale_set := false
	var stretch_set := false
	var spin_set := false
	var pos_set := false
	var red := 0.0
	var green := 0.0
	var blue := 0.0
	var alpha := 0.0
	var scale := 0.0
	var stretch := 0.0
	var spin := 0.0
	var pos_x := 0.0
	var pos_y := 0.0

class Emitter:
	var def: Defs.EmitterDef
	var system: TodParticleSystem
	var particles: Array = []
	var spawn_accum := 0.0
	var system_center := Vector2.ZERO
	var particles_spawned := 0
	var system_age := -1
	var system_duration := 0
	var system_time_value := -1.0
	var system_last_time_value := -1.0
	var dead := false
	var freed := false
	var color_override := Color.WHITE
	var extra_additive_draw_override := false
	var scale_override := 1.0
	var image_override: PvzImage = null
	var cross_fade_emitter: Emitter = null
	var emitter_cross_fade_count_down := 0
	var frame_override := -1
	var track_interp := PackedFloat32Array()
	var system_field_interp := PackedFloat32Array()

	func initialize(x: float, y: float, sys: TodParticleSystem, d: Defs.EmitterDef) -> void:
		system_center = Vector2(x, y)
		system = sys
		def = d
		if def.system_duration.is_set():
			system_duration = int(def.system_duration.evaluate(0.0, Tod.rand_float(1.0)))
		else:
			system_duration = int(def.particle_duration.evaluate(0.0, 1.0))
		system_duration = maxi(1, system_duration)
		system_field_interp.resize(def.system_fields.size() * 2)
		for i in system_field_interp.size():
			system_field_interp[i] = Tod.rand_float(1.0)
		track_interp.resize(10)
		for j in 10:
			track_interp[j] = Tod.rand_float(1.0)
		update()

	func system_track_evaluate(track: Defs.FloatTrack, which: int) -> float:
		return track.evaluate(system_time_value, track_interp[which])

	static func particle_track_evaluate(track: Defs.FloatTrack, p: Particle, which: int) -> float:
		return track.evaluate(p.time_value, p.interp[which])

	func spawn_particle(index: int, spawn_count: int) -> Particle:
		if system.holder_particle_count() >= 1024:
			return null
		var p := Particle.new()
		p.field_interp.resize(def.particle_fields.size() * 2)
		for i in p.field_interp.size():
			p.field_interp[i] = Tod.rand_float(1.0)
		p.interp.resize(16)
		for i in 16:
			p.interp[i] = Tod.rand_float(1.0)
		var dur_interp := Tod.rand_float(1.0)
		var speed_interp := Tod.rand_float(1.0)
		var offx_interp := Tod.rand_float(1.0)
		var offy_interp := Tod.rand_float(1.0)
		p.duration = maxi(1, int(def.particle_duration.evaluate(system_time_value, dur_interp)))
		p.age = 0
		p.emitter = self
		p.time_value = -1.0
		p.last_time_value = -1.0
		if Tod.test_bit(def.flags, PARTICLE_RANDOM_START_TIME):
			p.age = Tod.rand_int(p.duration)
		var launch_speed := def.launch_speed.evaluate(system_time_value, speed_interp) * 0.01
		var angle_interp := Tod.rand_float(1.0)
		var launch_angle: float
		if def.emitter_type == EMITTER_CIRCLE_PATH:
			launch_angle = def.emitter_path.evaluate(system_time_value, track_interp[TRACK_EMITTER_PATH]) * 2.0 * PI
			launch_angle += Tod.deg_to_rad_f(def.launch_angle.evaluate(system_time_value, angle_interp))
		elif def.emitter_type == EMITTER_CIRCLE_EVEN_SPACING:
			launch_angle = 2.0 * PI * index / spawn_count + Tod.deg_to_rad_f(def.launch_angle.evaluate(system_time_value, angle_interp))
		elif def.launch_angle.is_constant_zero():
			launch_angle = Tod.rand_float(2.0 * PI)
		else:
			launch_angle = Tod.deg_to_rad_f(def.launch_angle.evaluate(system_time_value, angle_interp))
		var px := 0.0
		var py := 0.0
		match def.emitter_type:
			EMITTER_CIRCLE, EMITTER_CIRCLE_PATH, EMITTER_CIRCLE_EVEN_SPACING:
				var radius := def.emitter_radius.evaluate(system_time_value, Tod.rand_float(1.0))
				px = sin(launch_angle) * radius
				py = cos(launch_angle) * radius
			EMITTER_BOX:
				var bx_i := Tod.rand_float(1.0)
				var by_i := Tod.rand_float(1.0)
				px = def.emitter_box_x.evaluate(system_time_value, bx_i)
				py = def.emitter_box_y.evaluate(system_time_value, by_i)
			EMITTER_BOX_PATH:
				var path_pos := def.emitter_path.evaluate(system_time_value, track_interp[TRACK_EMITTER_PATH])
				var min_x := def.emitter_box_x.evaluate(system_time_value, 0.0)
				var max_x := def.emitter_box_x.evaluate(system_time_value, 1.0)
				var min_y := def.emitter_box_y.evaluate(system_time_value, 0.0)
				var max_y := def.emitter_box_y.evaluate(system_time_value, 1.0)
				var dx := max_x - min_x
				var dy := max_y - min_y
				var pp := path_pos * (dy + dx + dy + dx)
				if pp < dy:
					px = min_x; py = min_y + pp
				elif pp < dy + dx:
					px = min_x + (pp - dy); py = max_y
				elif pp < dy + dx + dy:
					px = max_x; py = max_y - (pp - dy - dx)
				else:
					px = max_x - (pp - dy - dx - dy); py = min_y
		var skx_i := Tod.rand_float(1.0)
		var sky_i := Tod.rand_float(1.0)
		var skew_x := def.emitter_skew_x.evaluate(system_time_value, skx_i)
		var skew_y := def.emitter_skew_y.evaluate(system_time_value, sky_i)
		p.position.x = system_center.x + px + py * skew_x
		p.position.y = system_center.y + py + px * skew_y
		p.velocity.x = sin(launch_angle) * launch_speed
		p.velocity.y = cos(launch_angle) * launch_speed
		p.position.x += def.emitter_offset_x.evaluate(system_time_value, offx_interp)
		p.position.y += def.emitter_offset_y.evaluate(system_time_value, offy_interp)
		p.animation_time_value = 0.0
		if def.animated != 0 or def.animation_rate.is_set():
			p.image_frame = 0
		else:
			p.image_frame = Tod.rand_int(def.image_frames)
		if Tod.test_bit(def.flags, PARTICLE_RANDOM_LAUNCH_SPIN):
			p.spin_position = Tod.rand_float(2.0 * PI)
		elif Tod.test_bit(def.flags, PARTICLE_ALIGN_LAUNCH_SPIN):
			p.spin_position = launch_angle
		else:
			p.spin_position = 0.0
		p.spin_velocity = 0.0
		p.cross_fade_duration = 0
		p.cross_fade_particle = null
		particles.push_front(p)
		system.particle_count_delta(1)
		particles_spawned += 1
		update_particle(p)
		return p

	func update_particle_field(p: Particle, field: Defs.ParticleField, t: float, fi: int) -> void:
		var ix := p.field_interp[fi * 2]
		var iy := p.field_interp[fi * 2 + 1]
		var x := field.x.evaluate(t, ix)
		var y := field.y.evaluate(t, iy)
		match field.type:
			FIELD_FRICTION:
				p.velocity.x *= 1.0 - x
				p.velocity.y *= 1.0 - y
			FIELD_ACCELERATION:
				p.velocity.x += 0.01 * x
				p.velocity.y += 0.01 * y
			FIELD_ATTRACTOR:
				p.velocity.x += 0.01 * (x - (p.position.x - system_center.x))
				p.velocity.y += 0.01 * (y - (p.position.y - system_center.y))
			FIELD_MAX_VELOCITY:
				p.velocity.x = clampf(p.velocity.x, -x, x)
				p.velocity.y = clampf(p.velocity.y, -y, y)
			FIELD_VELOCITY:
				p.position.x += 0.01 * x
				p.position.y += 0.01 * y
			FIELD_POSITION:
				p.position.x += x - field.x.evaluate_from_last_time(p.last_time_value, ix)
				p.position.y += y - field.y.evaluate_from_last_time(p.last_time_value, iy)
			FIELD_GROUND_CONSTRAINT:
				if p.position.y > system_center.y + y:
					p.position.y = system_center.y + y
					var reflect := def.collision_reflect.evaluate(t, p.interp[TRACK_PARTICLE_COLLISION_REFLECT])
					var cspin := def.collision_spin.evaluate(t, p.interp[TRACK_PARTICLE_COLLISION_SPIN]) / 1000.0
					p.spin_velocity = p.velocity.y * cspin
					p.velocity.x *= reflect
					p.velocity.y *= -reflect
			FIELD_SHAKE:
				var lx := field.x.evaluate_from_last_time(p.last_time_value, ix)
				var ly := field.y.evaluate_from_last_time(p.last_time_value, iy)
				var seed_base := p.get_instance_id()
				var last_seed := p.age - 1
				if last_seed == -1:
					last_seed = p.duration - 1
				var r := RandomNumberGenerator.new()
				r.seed = last_seed * seed_base
				p.position.x -= lx * (r.randf() * 2.0 - 1.0)
				p.position.y -= ly * (r.randf() * 2.0 - 1.0)
				r.seed = p.age * seed_base
				p.position.x += x * (r.randf() * 2.0 - 1.0)
				p.position.y += y * (r.randf() * 2.0 - 1.0)
			FIELD_CIRCLE:
				var to_center := p.position - system_center
				var motion := Vector2(-to_center.y, to_center.x).normalized()
				p.position += motion * (0.01 * (x + to_center.length() * y))
			FIELD_AWAY:
				var to_c := p.position - system_center
				p.position += to_c.normalized() * (0.01 * (x + to_c.length() * y))

	func update_system_field(field: Defs.ParticleField, t: float, fi: int) -> void:
		var ix := system_field_interp[fi * 2]
		var iy := system_field_interp[fi * 2 + 1]
		if field.type == FIELD_SYSTEM_POSITION:
			var x := field.x.evaluate(t, ix)
			var y := field.y.evaluate(t, iy)
			system_center.x += x - field.x.evaluate_from_last_time(system_last_time_value, ix)
			system_center.y += y - field.y.evaluate_from_last_time(system_last_time_value, iy)

	func cross_fade_particle_to_name(p: Particle, name: String) -> bool:
		var d := system.find_emitter_def_by_name(name)
		if d == null:
			return false
		var e := Emitter.new()
		e.initialize(system_center.x, system_center.y, system, d)
		system.emitters.append(e)
		return cross_fade_particle(p, e)

	func update_particle(p: Particle) -> bool:
		if p.age >= p.duration:
			if Tod.test_bit(def.flags, PARTICLE_PARTICLE_LOOPS):
				p.age = 0
			elif p.cross_fade_duration > 0:
				p.age = p.duration - 1
			elif def.on_duration == "" or not cross_fade_particle_to_name(p, def.on_duration):
				return false
		if p.cross_fade_particle != null and p.cross_fade_particle.freed:
			return false
		p.time_value = p.age / (float(p.duration) - 1.0)
		for i in def.particle_fields.size():
			update_particle_field(p, def.particle_fields[i], p.time_value, i)
		p.position += p.velocity
		var spin_speed := particle_track_evaluate(def.particle_spin_speed, p, TRACK_PARTICLE_SPIN_SPEED) * 0.01
		var spin_angle := particle_track_evaluate(def.particle_spin_angle, p, TRACK_PARTICLE_SPIN_ANGLE)
		var last_spin := def.particle_spin_angle.evaluate_from_last_time(p.last_time_value, p.interp[TRACK_PARTICLE_SPIN_ANGLE])
		p.spin_position += Tod.deg_to_rad_f(spin_speed + spin_angle - last_spin) + p.spin_velocity
		if def.animation_rate.is_set():
			p.animation_time_value += particle_track_evaluate(def.animation_rate, p, TRACK_PARTICLE_ANIMATION_RATE) * 0.01
			while p.animation_time_value >= 1.0:
				p.animation_time_value -= 1.0
			while p.animation_time_value < 0.0:
				p.animation_time_value += 1.0
		p.age += 1
		p.last_time_value = p.time_value
		return true

	func update_spawning() -> void:
		var cfe := cross_fade_emitter if (cross_fade_emitter != null and not cross_fade_emitter.freed) else null
		var se: Emitter = self if cfe == null else cfe
		spawn_accum += se.system_track_evaluate(se.def.spawn_rate, TRACK_SPAWN_RATE) * 0.01
		var spawn_count := int(spawn_accum)
		spawn_accum -= spawn_count
		var min_active := int(se.system_track_evaluate(se.def.spawn_min_active, TRACK_SPAWN_MIN_ACTIVE))
		if min_active >= 0 and spawn_count < min_active - particles.size():
			spawn_count = min_active - particles.size()
		var max_active := int(se.system_track_evaluate(se.def.spawn_max_active, TRACK_SPAWN_MAX_ACTIVE))
		if max_active >= 0 and spawn_count > max_active - particles.size():
			spawn_count = max_active - particles.size()
		if se.def.spawn_max_launched.is_set():
			var max_launched := int(se.system_track_evaluate(se.def.spawn_max_launched, TRACK_SPAWN_MAX_LAUNCHED))
			if spawn_count > max_launched - particles_spawned:
				spawn_count = max_launched - particles_spawned
		for i in spawn_count:
			var p := spawn_particle(i, spawn_count)
			if cfe != null and p != null:
				cross_fade_particle(p, cfe)

	func delete_non_cross_fading() -> void:
		for p in particles.duplicate():
			if p.cross_fade_duration <= 0:
				delete_particle(p)

	func delete_all() -> void:
		for p in particles:
			p.freed = true
		system.particle_count_delta(-particles.size())
		particles.clear()

	func cross_fade_particle(p: Particle, to: Emitter) -> bool:
		if p.cross_fade_duration > 0:
			return false
		if not to.def.cross_fade_duration.is_set():
			return false
		var tp := to.spawn_particle(0, 1)
		if tp == null:
			return false
		if emitter_cross_fade_count_down > 0:
			p.cross_fade_duration = emitter_cross_fade_count_down
		else:
			var d := int(to.def.cross_fade_duration.evaluate(system_time_value, Tod.rand_float(1.0)))
			p.cross_fade_duration = maxi(1, d)
		if not to.def.particle_duration.is_set():
			tp.duration = p.cross_fade_duration
		tp.cross_fade_particle = p
		return true

	func delete_particle(p: Particle) -> void:
		if p.freed:
			return
		var cf := p.cross_fade_particle
		if cf != null and not cf.freed:
			cf.emitter.delete_particle(cf)
			p.cross_fade_particle = null
		var idx := particles.find(p)
		if idx != -1:
			particles.remove_at(idx)
			system.particle_count_delta(-1)
		p.freed = true

	func update() -> void:
		if dead:
			return
		system_age += 1
		var die := false
		if system_age >= system_duration:
			if Tod.test_bit(def.flags, PARTICLE_SYSTEM_LOOPS):
				system_age = 0
			else:
				system_age = system_duration - 1
				die = true
		if emitter_cross_fade_count_down > 0:
			emitter_cross_fade_count_down -= 1
			if emitter_cross_fade_count_down == 0:
				die = true
		if cross_fade_emitter != null:
			if cross_fade_emitter.freed or cross_fade_emitter.dead:
				die = true
		system_time_value = system_age / float(system_duration - 1)
		for i in def.system_fields.size():
			update_system_field(def.system_fields[i], system_time_value, i)
		for p in particles.duplicate():
			if p.freed:
				continue
			if not update_particle(p):
				delete_particle(p)
		update_spawning()
		if die:
			delete_non_cross_fading()
			if particles.is_empty():
				dead = true
				return
		system_last_time_value = system_time_value

	static func get_render_params(p: Particle, rp: RenderParams) -> bool:
		var e := p.emitter
		var d := e.def
		rp.red_set = d.system_red.is_set() or d.particle_red.is_set() or e.color_override.r8 != 1
		rp.green_set = d.system_green.is_set() or d.particle_green.is_set() or e.color_override.g8 != 1
		rp.blue_set = d.system_blue.is_set() or d.particle_blue.is_set() or e.color_override.b8 != 1
		rp.alpha_set = d.system_alpha.is_set() or d.particle_alpha.is_set() or e.color_override.a8 != 1
		rp.scale_set = d.particle_scale.is_set() or e.scale_override != 1.0
		rp.stretch_set = d.particle_stretch.is_set()
		rp.spin_set = d.particle_spin_speed.is_set() or d.particle_spin_angle.is_set() \
			or Tod.test_bit(d.flags, PARTICLE_RANDOM_LAUNCH_SPIN) or Tod.test_bit(d.flags, PARTICLE_ALIGN_LAUNCH_SPIN)
		rp.pos_set = d.particle_fields.size() > 0 or d.emitter_radius.is_set() or d.emitter_offset_x.is_set() \
			or d.emitter_offset_y.is_set() or d.emitter_box_x.is_set() or d.emitter_box_y.is_set()
		var sr := e.system_track_evaluate(d.system_red, TRACK_SYSTEM_RED)
		var sg := e.system_track_evaluate(d.system_green, TRACK_SYSTEM_GREEN)
		var sb := e.system_track_evaluate(d.system_blue, TRACK_SYSTEM_BLUE)
		var sa := e.system_track_evaluate(d.system_alpha, TRACK_SYSTEM_ALPHA)
		var sbr := e.system_track_evaluate(d.system_brightness, TRACK_SYSTEM_BRIGHTNESS)
		var pr := particle_track_evaluate(d.particle_red, p, TRACK_PARTICLE_RED)
		var pg := particle_track_evaluate(d.particle_green, p, TRACK_PARTICLE_GREEN)
		var pb := particle_track_evaluate(d.particle_blue, p, TRACK_PARTICLE_BLUE)
		var pa := particle_track_evaluate(d.particle_alpha, p, TRACK_PARTICLE_ALPHA)
		var pbr := particle_track_evaluate(d.particle_brightness, p, TRACK_PARTICLE_BRIGHTNESS)
		var br := pbr * sbr
		# Sexy::Color components are 0..255 ints; the original compares them against 1.0 (so the *_set flags
		# are effectively always true) and multiplies in 0..255 space. Both quirks are kept.
		rp.red = pr * sr * e.color_override.r8 * br
		rp.green = pg * sg * e.color_override.g8 * br
		rp.blue = pb * sb * e.color_override.b8 * br
		rp.alpha = pa * sa * e.color_override.a8 * br
		rp.pos_x = p.position.x
		rp.pos_y = p.position.y
		var ps := particle_track_evaluate(d.particle_scale, p, TRACK_PARTICLE_SCALE)
		rp.stretch = particle_track_evaluate(d.particle_stretch, p, TRACK_PARTICLE_STRETCH)
		rp.scale = ps * e.scale_override
		rp.spin = p.spin_position
		var cf := p.cross_fade_particle
		if cf != null and not cf.freed:
			var cp := RenderParams.new()
			if get_render_params(cf, cp):
				var frac := p.age / float(cf.cross_fade_duration - 1)
				rp.red = _cfl(cp.red, rp.red, cp.red_set, rp.red_set, frac)
				rp.green = _cfl(cp.green, rp.green, cp.green_set, rp.green_set, frac)
				rp.blue = _cfl(cp.blue, rp.blue, cp.blue_set, rp.blue_set, frac)
				rp.alpha = _cfl(cp.alpha, rp.alpha, cp.alpha_set, rp.alpha_set, frac)
				rp.scale = _cfl(cp.scale, rp.scale, cp.scale_set, rp.scale_set, frac)
				rp.stretch = _cfl(cp.stretch, rp.stretch, cp.stretch_set, rp.stretch_set, frac)
				rp.spin = _cfl(cp.spin, rp.spin, cp.spin_set, rp.spin_set, frac)
				rp.pos_x = _cfl(cp.pos_x, rp.pos_x, cp.pos_set, rp.pos_set, frac)
				rp.pos_y = _cfl(cp.pos_y, rp.pos_y, cp.pos_set, rp.pos_set, frac)
				rp.red_set = rp.red_set or cp.red_set
				rp.green_set = rp.green_set or cp.green_set
				rp.blue_set = rp.blue_set or cp.blue_set
				rp.alpha_set = rp.alpha_set or cp.alpha_set
				rp.scale_set = rp.scale_set or cp.scale_set
				rp.stretch_set = rp.stretch_set or cp.stretch_set
				rp.spin_set = rp.spin_set or cp.spin_set
				rp.pos_set = rp.pos_set or cp.pos_set
		return true

	static func _cfl(from: float, to: float, from_set: bool, to_set: bool, frac: float) -> float:
		if not from_set:
			return to
		if not to_set:
			return from
		return from + (to - from) * frac

	func draw(g: Graphics) -> void:
		if Tod.test_bit(def.flags, PARTICLE_SOFTWARE_ONLY):
			return
		var rp := RenderParams.new()
		for p in particles:
			draw_particle(g, p, rp)

	func draw_particle(g: Graphics, p: Particle, rp: RenderParams) -> void:
		if p.cross_fade_duration > 0:
			return
		if not get_render_params(p, rp):
			return
		var col := Color8(clampi(Tod.round_to_int(rp.red), 0, 255), clampi(Tod.round_to_int(rp.green), 0, 255),
			clampi(Tod.round_to_int(rp.blue), 0, 255), clampi(Tod.round_to_int(rp.alpha), 0, 255))
		if col.a8 <= 0:
			return
		rp.pos_x += g.trans_x
		rp.pos_y += g.trans_y
		var rpart: Particle = p
		if image_override == null and def.image == null:
			rpart = p.cross_fade_particle if (p.cross_fade_particle != null and not p.cross_fade_particle.freed) else null
		if rpart != null:
			render_particle(g, rpart, col, rp)

	static func render_particle(g: Graphics, p: Particle, col: Color, rp: RenderParams) -> void:
		var e := p.emitter
		var d := e.def
		var img: PvzImage = e.image_override if e.image_override != null else d.image
		if img == null:
			return
		var cw := img.get_cel_width()
		var ch := img.get_cel_height()
		var frame := e.frame_override
		if frame == -1:
			if d.animation_rate.is_set():
				frame = clampi(int(p.animation_time_value * d.image_frames), 0, d.image_frames - 1)
			elif d.animated != 0:
				frame = clampi(int(p.time_value * d.image_frames), 0, d.image_frames - 1)
			else:
				frame = p.image_frame
		frame += d.image_col
		if frame >= img.num_cols:
			frame = img.num_cols - 1
		var src := Rect2(frame * cw, mini(d.image_row, img.num_rows - 1) * ch, cw, ch)
		var ct := particle_track_evaluate(d.clip_top, p, TRACK_PARTICLE_CLIP_TOP)
		var cb := particle_track_evaluate(d.clip_bottom, p, TRACK_PARTICLE_CLIP_BOTTOM)
		var cl := particle_track_evaluate(d.clip_left, p, TRACK_PARTICLE_CLIP_LEFT)
		var cr := particle_track_evaluate(d.clip_right, p, TRACK_PARTICLE_CLIP_RIGHT)
		rp.pos_x += cl * cw
		rp.pos_y += ct * ch
		src.position.x += Tod.round_to_int(cl * cw)
		src.position.y += Tod.round_to_int(ct * ch)
		src.size.x -= Tod.round_to_int(cw * (cl + cr))
		src.size.y -= Tod.round_to_int(ch * (cb + ct))
		if Tod.test_bit(d.flags, PARTICLE_ALIGN_TO_PIXELS):
			rp.pos_x = Tod.round_to_int(rp.pos_x)
			rp.pos_y = Tod.round_to_int(rp.pos_y)
		var mode := g.draw_mode
		if Tod.test_bit(d.flags, PARTICLE_ADDITIVE):
			mode = Graphics.DRAWMODE_ADDITIVE
		if Tod.test_bit(d.flags, PARTICLE_FULLSCREEN):
			var old_color := g.color
			var old_mode := g.draw_mode
			g.color = col
			g.fill_rect(-g.trans_x, -g.trans_y, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
			g.color = old_color
			g.draw_mode = old_mode
		else:
			var xf := Tod.scale_rotate_matrix(rp.pos_x, rp.pos_y, rp.spin, rp.scale, rp.stretch * rp.scale)
			g.blt_matrix(img, xf, g.clip, col, mode, src)
			if e.extra_additive_draw_override:
				g.blt_matrix(img, xf, g.clip, col, Graphics.DRAWMODE_ADDITIVE, src)

	func system_move(x: float, y: float) -> void:
		var dx := x - system_center.x
		var dy := y - system_center.y
		if Tod.approx_equal(dx, 0.0) and Tod.approx_equal(dy, 0.0):
			return
		system_center = Vector2(x, y)
		if not Tod.test_bit(def.flags, PARTICLE_PARTICLES_DONT_FOLLOW):
			for p in particles:
				p.position.x += dx
				p.position.y += dy

	func cross_fade_emitter_to(to: Emitter) -> void:
		if emitter_cross_fade_count_down > 0:
			return
		if not to.def.cross_fade_duration.is_set():
			return
		emitter_cross_fade_count_down = maxi(1, int(to.def.cross_fade_duration.evaluate(system_time_value, Tod.rand_float(1.0))))
		cross_fade_emitter = to
		if not to.def.system_duration.is_set():
			to.system_duration = emitter_cross_fade_count_down
		for p in particles.duplicate():
			cross_fade_particle(p, to)

# ================================================================ system
var effect_type := -1
var particle_def: Defs.ParticleDef
var emitters: Array = []
var dead := false
var freed := false
var is_attachment := false
var render_order := 0
var dont_update := false

static var total_particles := 0

func holder_particle_count() -> int:
	return total_particles

func particle_count_delta(d: int) -> void:
	total_particles += d

func initialize_from_def(x: float, y: float, order: int, def: Defs.ParticleDef, type: int) -> void:
	particle_def = def
	effect_type = type
	render_order = order
	for d in def.emitters:
		var ed: Defs.EmitterDef = d
		if not ed.cross_fade_duration.is_set():
			if Tod.test_bit(ed.flags, PARTICLE_DIE_IF_OVERLOADED) and EffectSystem.is_particle_overloaded():
				particle_system_die()
				break
			var e := Emitter.new()
			emitters.append(e)
			e.initialize(x, y, self, ed)

func particle_system_die() -> void:
	for e in emitters:
		e.delete_all()
		e.freed = true
	emitters.clear()
	dead = true

func update() -> void:
	if dont_update:
		return
	var alive := false
	for e in emitters.duplicate():
		e.update()
		if (e.def.cross_fade_duration.is_set() and e.particles.size() > 0) or not e.dead:
			alive = true
	if not alive:
		dead = true

func draw(g: Graphics) -> void:
	for e in emitters:
		e.draw(g)

func system_move(x: float, y: float) -> void:
	for e in emitters:
		e.system_move(x, y)

static func _name_match(filter, e: Emitter) -> bool:
	return filter == null or str(filter).to_lower() == e.def.name.to_lower()

func override_color(emitter_name, c: Color) -> void:
	for e in emitters:
		if _name_match(emitter_name, e):
			e.color_override = c

func override_extra_additive_draw(emitter_name, on: bool) -> void:
	for e in emitters:
		if _name_match(emitter_name, e):
			e.extra_additive_draw_override = on

func override_image(emitter_name, img: PvzImage) -> void:
	for e in emitters:
		if _name_match(emitter_name, e):
			e.image_override = img

func override_frame(emitter_name, frame: int) -> void:
	for e in emitters:
		if _name_match(emitter_name, e):
			e.frame_override = frame

func override_scale(emitter_name, s: float) -> void:
	for e in emitters:
		if _name_match(emitter_name, e):
			e.scale_override = s

func find_emitter_by_name(name: String) -> Emitter:
	for e in emitters:
		if e.def.name.to_lower() == name.to_lower():
			return e
	return null

func find_emitter_def_by_name(name: String) -> Defs.EmitterDef:
	for d in particle_def.emitters:
		if d.name.to_lower() == name.to_lower():
			return d
	return null

func cross_fade(name: String) -> void:
	var d := find_emitter_def_by_name(name)
	if d == null or not d.cross_fade_duration.is_set():
		return
	for e in emitters.duplicate():
		if e.def != d:
			var ne := Emitter.new()
			ne.initialize(e.system_center.x, e.system_center.y, self, d)
			emitters.append(ne)
			e.cross_fade_emitter_to(ne)
