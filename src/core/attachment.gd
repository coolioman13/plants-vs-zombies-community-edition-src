class_name Attachment
extends RefCounted
## Port of TodLib Attachment. Functions that took an AttachmentID& in C++ take a "holder" object that
## has an `attachment` property (track instances, plants, zombies, projectiles ...).

const MAX_EFFECTS_PER_ATTACHMENT := 16
enum { EFFECT_PARTICLE, EFFECT_TRAIL, EFFECT_REANIM, EFFECT_ATTACHMENT, EFFECT_OTHER }

class Effect:
	var type := EFFECT_PARTICLE
	var obj: RefCounted
	var offset := Transform2D.IDENTITY
	var dont_draw_if_parent_hidden := false
	var dont_propogate_color := false

var effects: Array = []
var dead := false
var freed := false

## Bumped whenever a reanimation track gains an attachment, so reanimations know to rescan which tracks have one.
static var generation := 0

static func _alive(o: RefCounted) -> bool:
	return o != null and not o.freed

func update() -> void:
	var i := 0
	while i < effects.size():
		var e: Effect = effects[i]
		var empty := true
		var o = e.obj
		if _alive(o):
			match e.type:
				EFFECT_PARTICLE, EFFECT_TRAIL, EFFECT_REANIM:
					if not o.dead:
						o.update()
						empty = false
				EFFECT_ATTACHMENT:
					o.update()
					empty = false
		if empty:
			effects.remove_at(i)
		else:
			i += 1
	if effects.is_empty():
		dead = true

func set_position(pos: Vector2) -> void:
	for e in effects:
		var o = e.obj
		if not _alive(o):
			continue
		var np: Vector2 = e.offset * pos
		match e.type:
			EFFECT_PARTICLE: o.system_move(np.x, np.y)
			EFFECT_TRAIL: o.add_point(np.x, np.y)
			EFFECT_REANIM: o.set_position(np.x, np.y)
			EFFECT_ATTACHMENT: o.set_position(np)

func override_color(c: Color) -> void:
	for e in effects:
		var o = e.obj
		if not _alive(o):
			continue
		match e.type:
			EFFECT_PARTICLE: o.override_color("", c)
			EFFECT_REANIM: o.color_override = c
			EFFECT_ATTACHMENT: o.override_color(c)

func propogate_color(c: Color, enable_add: bool, add_col: Color, enable_over: bool, over_col: Color) -> void:
	for e in effects:
		if e.dont_propogate_color:
			continue
		var o = e.obj
		if not _alive(o):
			continue
		match e.type:
			EFFECT_PARTICLE:
				o.override_color(null, c)
				o.override_extra_additive_draw(null, enable_add)
			EFFECT_REANIM:
				o.color_override = c
				o.extra_additive_color = add_col
				o.enable_extra_additive_draw = enable_add
				o.extra_overlay_color = over_col
				o.enable_extra_overlay_draw = enable_over
				o.propogate_color_to_attachments()
			EFFECT_ATTACHMENT:
				o.propogate_color(c, enable_add, add_col, enable_over, over_col)

func override_scale(s: float) -> void:
	for e in effects:
		var o = e.obj
		if not _alive(o):
			continue
		match e.type:
			EFFECT_PARTICLE: o.override_scale(null, s)
			EFFECT_REANIM: o.override_scale(s, s)
			EFFECT_ATTACHMENT: o.override_scale(s)

func cross_fade(name: String) -> void:
	for e in effects:
		if e.type == EFFECT_PARTICLE and _alive(e.obj):
			e.obj.cross_fade(name)

func set_matrix(m: Transform2D) -> void:
	for e in effects:
		var o = e.obj
		if not _alive(o):
			continue
		var p: Transform2D = m * e.offset
		match e.type:
			EFFECT_PARTICLE: o.system_move(p.origin.x, p.origin.y)
			EFFECT_TRAIL: o.trail_center = p.origin
			EFFECT_REANIM: o.overlay_matrix = p
			EFFECT_ATTACHMENT: o.set_matrix(p)

func draw(g: Graphics, parent_hidden: bool) -> void:
	for e in effects:
		if parent_hidden and e.dont_draw_if_parent_hidden:
			continue
		var o = e.obj
		if not _alive(o):
			continue
		match e.type:
			EFFECT_PARTICLE, EFFECT_TRAIL, EFFECT_REANIM: o.draw(g)
			EFFECT_ATTACHMENT: o.draw(g, parent_hidden)

func detach() -> void:
	for e in effects:
		var o = e.obj
		if _alive(o):
			if e.type == EFFECT_ATTACHMENT:
				o.detach()
			else:
				o.is_attachment = false
	effects.clear()
	dead = true

func attachment_die() -> void:
	for e in effects:
		var o = e.obj
		if not _alive(o):
			continue
		match e.type:
			EFFECT_PARTICLE: o.particle_system_die()
			EFFECT_TRAIL: o.dead = true
			EFFECT_REANIM: o.die()
			EFFECT_ATTACHMENT: o.attachment_die()
	effects.clear()
	dead = true

# ================================================================ holder helpers
static func _att(holder: Object) -> Attachment:
	var a = holder.attachment
	if a == null or a.freed:
		return null
	return a

static func update_and_set_matrix(holder: Object, m: Transform2D) -> void:
	var a := _att(holder)
	if a == null:
		holder.attachment = null
		return
	a.update()
	a.set_matrix(m)

static func update_and_move(holder: Object, x: float, y: float) -> void:
	var a := _att(holder)
	if a == null:
		holder.attachment = null
		return
	a.update()
	a.set_position(Vector2(x, y))

static func override_color_on(holder: Object, c: Color) -> void:
	var a := _att(holder)
	if a != null:
		a.override_color(c)

static func override_scale_on(holder: Object, s: float) -> void:
	var a := _att(holder)
	if a != null:
		a.override_scale(s)

static func propogate_color_on(holder: Object, c: Color, enable_add: bool, add_col: Color, enable_over: bool, over_col: Color) -> void:
	var a := _att(holder)
	if a != null:
		a.propogate_color(c, enable_add, add_col, enable_over, over_col)

static func cross_fade_on(holder: Object, name: String) -> void:
	var a := _att(holder)
	if a != null:
		a.cross_fade(name)

static func draw_on(holder: Object, g: Graphics, parent_hidden: bool) -> void:
	var a := _att(holder)
	if a != null:
		a.draw(g, parent_hidden)

static func die_on(holder: Object) -> void:
	var a := _att(holder)
	holder.attachment = null
	if a != null:
		a.attachment_die()

static func detach_on(holder: Object) -> void:
	var a := _att(holder)
	holder.attachment = null
	if a != null:
		a.detach()

static func reanim_type_die(holder: Object, type: int) -> void:
	var a := _att(holder)
	if a == null:
		return
	for e in a.effects:
		if e.type == EFFECT_REANIM and _alive(e.obj) and e.obj.reanim_type == type:
			e.obj.die()

static func detach_cross_fade_particle_type(holder: Object, effect: int, cross_fade_name: String) -> void:
	var a := _att(holder)
	if a == null:
		return
	var def: Defs.ParticleDef = ParticleTypes.get_def(effect)
	for e in a.effects:
		if e.type == EFFECT_PARTICLE and _alive(e.obj) and e.obj.particle_def == def:
			if cross_fade_name != "":
				e.obj.is_attachment = false
				e.obj.cross_fade(cross_fade_name)
			else:
				e.obj.particle_system_die()
			holder.attachment = null

static func find_reanim_attachment(holder: Object) -> Reanimation:
	var a := _att(holder)
	if a == null:
		return null
	for e in a.effects:
		if e.type == EFFECT_REANIM and _alive(e.obj):
			return e.obj
	return null

static func find_first_attachment(holder: Object) -> Effect:
	var a := _att(holder)
	if a == null or a.effects.is_empty():
		return null
	return a.effects[0]

static func _create_effect(holder: Object, type: int, obj: RefCounted, ox: float, oy: float) -> Effect:
	var a := _att(holder)
	if a == null or a.dead:
		a = EffectSystem.alloc_attachment()
		holder.attachment = a
		if holder is Reanimation.TrackInstance:
			generation += 1
	var e := Effect.new()
	e.type = type
	e.obj = obj
	e.offset = Transform2D(Vector2(1, 0), Vector2(0, 1), Vector2(ox, oy))
	a.effects.append(e)
	return e

static func attach_reanim(holder: Object, r: Reanimation, ox: float, oy: float) -> Effect:
	var e := _create_effect(holder, EFFECT_REANIM, r, ox, oy)
	r.is_attachment = true
	return e

static func attach_particle(holder: Object, ps: TodParticleSystem, ox: float, oy: float) -> Effect:
	if ps == null:
		return null
	var e := _create_effect(holder, EFFECT_PARTICLE, ps, ox, oy)
	ps.is_attachment = true
	return e

static func attach_trail(holder: Object, t: Trail, ox: float, oy: float) -> Effect:
	var e := _create_effect(holder, EFFECT_TRAIL, t, ox, oy)
	t.is_attachment = true
	return e

static func is_full(holder: Object) -> bool:
	var a := _att(holder)
	return a != null and a.effects.size() >= MAX_EFFECTS_PER_ATTACHMENT
