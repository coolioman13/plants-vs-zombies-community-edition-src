class_name EffectSystem
## Port of TodLib EffectSystem: owns every particle system, trail, reanimation and attachment.

static var particle_systems: Array = []
static var trails: Array = []
static var reanimations: Array = []
static var attachments: Array = []

static func alloc_reanimation(x: float, y: float, render_order: int, type: int) -> Reanimation:
	var r := Reanimation.new()
	r.render_order = render_order
	r.reanim_type = type
	if CustomAssets.is_active():
		r.initialize(x, y, CustomAssets.reanim_def_for(type))
		if CustomAssets.has_part_skins(type):
			CustomAssets.apply_part_skins(r, type)
	else:
		r.initialize(x, y, ReanimTypes.get_def(type))
	reanimations.append(r)
	return r

static func alloc_reanimation_from_def(x: float, y: float, render_order: int, def: Defs.ReanimDef) -> Reanimation:
	var r := Reanimation.new()
	r.render_order = render_order
	r.initialize(x, y, def)
	reanimations.append(r)
	return r

static func alloc_particle_system(x: float, y: float, render_order: int, effect: int) -> TodParticleSystem:
	return alloc_particle_system_from_def(x, y, render_order, ParticleTypes.get_def(effect), effect)

static func alloc_particle_system_from_def(x: float, y: float, render_order: int, def: Defs.ParticleDef, effect: int) -> TodParticleSystem:
	if particle_systems.size() >= 1024:
		return null
	var ps := TodParticleSystem.new()
	particle_systems.append(ps)
	ps.initialize_from_def(x, y, render_order, def, effect)
	return ps

static func alloc_trail(render_order: int, def: Defs.TrailDef) -> Trail:
	var t := Trail.new()
	t.render_order = render_order
	t.definition = def
	t.trail_duration = int(def.trail_duration.evaluate(0.0, Tod.rand_range_float(0.0, 1.0)))
	trails.append(t)
	return t

static func alloc_attachment() -> Attachment:
	var a := Attachment.new()
	attachments.append(a)
	return a

static func is_particle_overloaded() -> bool:
	return particle_systems.size() > TodParticleSystem.MAX_PARTICLES_SIZE or TodParticleSystem.total_particles > TodParticleSystem.MAX_PARTICLES_SIZE

static func update() -> void:
	for ps in particle_systems.duplicate():
		if not ps.is_attachment and not ps.freed:
			ps.update()
	for t in trails.duplicate():
		if not t.is_attachment and not t.freed:
			t.update()
	for r in reanimations.duplicate():
		if not r.is_attachment and not r.freed:
			r.update()

static func process_delete_queue() -> void:
	particle_systems = particle_systems.filter(func(ps):
		if ps.dead:
			ps.particle_system_die()
			ps.freed = true
			return false
		return true)
	trails = trails.filter(func(t):
		if t.dead:
			t.freed = true
			return false
		return true)
	reanimations = reanimations.filter(func(r):
		if r.dead:
			r.freed = true
			return false
		return true)
	attachments = attachments.filter(func(a):
		if a.dead:
			a.freed = true
			return false
		return true)

static func free_all() -> void:
	for ps in particle_systems:
		ps.particle_system_die()
		ps.freed = true
	for t in trails:
		t.freed = true
	for r in reanimations:
		r.dead = true
		r.freed = true
	for a in attachments:
		a.dead = true
		a.freed = true
	particle_systems.clear()
	trails.clear()
	reanimations.clear()
	attachments.clear()
	TodParticleSystem.total_particles = 0

## Helpers mirroring LawnApp::ReanimationTryToGet etc.
static func reanim_valid(r) -> bool:
	return r != null and not r.freed

static func particle_valid(p) -> bool:
	return p != null and not p.freed
