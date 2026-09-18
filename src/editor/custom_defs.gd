class_name CustomDefs
## Runtime registry for a custom level's own plants, zombies and boss.
##
## Custom plants get real seed-type ids appended to LawnDefs.PLANT_DEFS, so cost, recharge time,
## packet art, reanim, subclass and launch rate all flow through the game's normal data paths.
## A plant keeps its custom id for identity and stats while its `seed_type` is the base plant it
## behaves like, so every `match seed_type` in Plant keeps working.
##
## Custom zombies keep the base zombie type at runtime for the same reason (Zombie is one huge
## per-type state machine) and carry a `custom_id` that supplies health, speed, size, tint, name
## and reskin. Everything the editor exposes is therefore guaranteed to actually behave.

const PLANT_FIELDS := ["cid", "name", "description", "base", "cost", "recharge", "health", "damage",
	"fire_rate", "reanim", "packet_image", "packet_bg", "tint", "scale", "sun_amount", "sun_interval",
	"range_rows", "armor", "explodes", "explode_radius", "nocturnal", "aquatic", "instant"]
const ZOMBIE_FIELDS := ["cid", "name", "description", "base", "health", "helm_health", "shield_health",
	"speed", "damage", "scale", "tint", "reanim", "part_skins", "value", "weight", "freeze_immune",
	"instakill_immune", "hypno_immune", "explode_on_death", "explode_damage", "death_event", "spawn_event"]

## Base plants worth offering as behaviour templates, grouped for the maker UI.
const PLANT_TEMPLATES := [
	{"base": PvZ.SEED_PEASHOOTER, "label": "Shooter (straight)"},
	{"base": PvZ.SEED_SNOWPEA, "label": "Shooter (slowing)"},
	{"base": PvZ.SEED_REPEATER, "label": "Shooter (double shot)"},
	{"base": PvZ.SEED_THREEPEATER, "label": "Shooter (three lanes)"},
	{"base": PvZ.SEED_SPLITPEA, "label": "Shooter (both ways)"},
	{"base": PvZ.SEED_GATLINGPEA, "label": "Shooter (four shot)"},
	{"base": PvZ.SEED_CACTUS, "label": "Shooter (hits flyers)"},
	{"base": PvZ.SEED_STARFRUIT, "label": "Shooter (five ways)"},
	{"base": PvZ.SEED_FUMESHROOM, "label": "Shooter (piercing fume)"},
	{"base": PvZ.SEED_GLOOMSHROOM, "label": "Shooter (all around)"},
	{"base": PvZ.SEED_CABBAGEPULT, "label": "Lobber (over walls)"},
	{"base": PvZ.SEED_MELONPULT, "label": "Lobber (splash)"},
	{"base": PvZ.SEED_KERNELPULT, "label": "Lobber (stunning)"},
	{"base": PvZ.SEED_WINTERMELON, "label": "Lobber (splash + slow)"},
	{"base": PvZ.SEED_SUNFLOWER, "label": "Sun producer"},
	{"base": PvZ.SEED_TWINSUNFLOWER, "label": "Sun producer (double)"},
	{"base": PvZ.SEED_SUNSHROOM, "label": "Sun producer (grows)"},
	{"base": PvZ.SEED_WALLNUT, "label": "Wall"},
	{"base": PvZ.SEED_TALLNUT, "label": "Wall (tall, blocks vaults)"},
	{"base": PvZ.SEED_PUMPKINSHELL, "label": "Wall (shell around a plant)"},
	{"base": PvZ.SEED_GARLIC, "label": "Lane diverter"},
	{"base": PvZ.SEED_CHERRYBOMB, "label": "Instant (area blast)"},
	{"base": PvZ.SEED_JALAPENO, "label": "Instant (burns a lane)"},
	{"base": PvZ.SEED_DOOMSHROOM, "label": "Instant (huge blast + crater)"},
	{"base": PvZ.SEED_ICESHROOM, "label": "Instant (freeze everything)"},
	{"base": PvZ.SEED_SQUASH, "label": "Instant (squashes one)"},
	{"base": PvZ.SEED_POTATOMINE, "label": "Mine (arms, then blows up)"},
	{"base": PvZ.SEED_CHOMPER, "label": "Melee (eats and chews)"},
	{"base": PvZ.SEED_HYPNOSHROOM, "label": "Melee (mind control)"},
	{"base": PvZ.SEED_SPIKEWEED, "label": "Ground spikes"},
	{"base": PvZ.SEED_SPIKEROCK, "label": "Ground spikes (tough)"},
	{"base": PvZ.SEED_TANGLEKELP, "label": "Water grab"},
	{"base": PvZ.SEED_LILYPAD, "label": "Water platform"},
	{"base": PvZ.SEED_FLOWERPOT, "label": "Roof platform"},
	{"base": PvZ.SEED_TORCHWOOD, "label": "Projectile booster"},
	{"base": PvZ.SEED_MAGNETSHROOM, "label": "Metal stealer"},
	{"base": PvZ.SEED_GOLD_MAGNET, "label": "Coin magnet"},
	{"base": PvZ.SEED_BLOVER, "label": "Blows away flyers"},
	{"base": PvZ.SEED_PLANTERN, "label": "Reveals fog"},
	{"base": PvZ.SEED_UMBRELLA, "label": "Shields from lobs"},
	{"base": PvZ.SEED_GRAVEBUSTER, "label": "Eats a gravestone"},
	{"base": PvZ.SEED_INSTANT_COFFEE, "label": "Wakes a sleeping plant"},
	{"base": PvZ.SEED_CATTAIL, "label": "Homing shooter"},
	{"base": PvZ.SEED_COBCANNON, "label": "Player-aimed cannon"},
	{"base": PvZ.SEED_MARIGOLD, "label": "Coin producer"},
]

## Base zombies worth offering as behaviour templates.
const ZOMBIE_TEMPLATES := [
	{"base": PvZ.ZOMBIE_NORMAL, "label": "Walker"},
	{"base": PvZ.ZOMBIE_TRAFFIC_CONE, "label": "Walker with light helmet"},
	{"base": PvZ.ZOMBIE_PAIL, "label": "Walker with heavy helmet"},
	{"base": PvZ.ZOMBIE_DOOR, "label": "Walker with a front shield"},
	{"base": PvZ.ZOMBIE_FLAG, "label": "Flag leader (fast)"},
	{"base": PvZ.ZOMBIE_NEWSPAPER, "label": "Enrages when its item breaks"},
	{"base": PvZ.ZOMBIE_POLEVAULTER, "label": "Vaults the first plant"},
	{"base": PvZ.ZOMBIE_FOOTBALL, "label": "Fast and armoured"},
	{"base": PvZ.ZOMBIE_DANCER, "label": "Summons backup"},
	{"base": PvZ.ZOMBIE_BACKUP_DANCER, "label": "Summoned minion"},
	{"base": PvZ.ZOMBIE_SNORKEL, "label": "Swims, surfaces to eat"},
	{"base": PvZ.ZOMBIE_DOLPHIN_RIDER, "label": "Jumps over the first plant (water)"},
	{"base": PvZ.ZOMBIE_DUCKY_TUBE, "label": "Water walker"},
	{"base": PvZ.ZOMBIE_ZAMBONI, "label": "Vehicle, crushes and leaves ice"},
	{"base": PvZ.ZOMBIE_BOBSLED, "label": "Team that slides on ice"},
	{"base": PvZ.ZOMBIE_JACK_IN_THE_BOX, "label": "Explodes on a timer"},
	{"base": PvZ.ZOMBIE_BALLOON, "label": "Flies over everything"},
	{"base": PvZ.ZOMBIE_DIGGER, "label": "Tunnels to the back"},
	{"base": PvZ.ZOMBIE_POGO, "label": "Hops over plants"},
	{"base": PvZ.ZOMBIE_YETI, "label": "Runs away when hurt"},
	{"base": PvZ.ZOMBIE_BUNGEE, "label": "Drops in and steals a plant"},
	{"base": PvZ.ZOMBIE_LADDER, "label": "Puts ladders on walls"},
	{"base": PvZ.ZOMBIE_CATAPULT, "label": "Ranged, throws at plants"},
	{"base": PvZ.ZOMBIE_GARGANTUAR, "label": "Giant, smashes plants"},
	{"base": PvZ.ZOMBIE_REDEYE_GARGANTUAR, "label": "Giant (tougher)"},
	{"base": PvZ.ZOMBIE_IMP, "label": "Small and fast"},
]

## Base seed count before any custom plant is appended.
static var _base_seed_count := 0
static var _base_reanim_count := 0
static var level: LevelDef = null
## custom seed type -> {"cid", "base", profile dictionary}
static var _plants_by_seed: Dictionary = {}
## custom plant cid -> custom seed type
static var _seed_by_cid: Dictionary = {}
## custom zombie cid -> profile dictionary
static var _zombies: Dictionary = {}
static var _installed := false

# ================================================================ lifecycle
static func install(l: LevelDef) -> void:
	uninstall()
	level = l
	if l == null:
		return
	if _base_seed_count == 0:
		_base_seed_count = LawnDefs.PLANT_DEFS.size()
	if _base_reanim_count == 0:
		_base_reanim_count = ReanimTypes.files.size()
	for z in l.custom_zombies:
		_zombies[int(z.get("cid", -1))] = z
	for p in l.custom_plants:
		_register_plant(p)
	_installed = true

static func uninstall() -> void:
	if _installed:
		if _base_seed_count > 0 and LawnDefs.PLANT_DEFS.size() > _base_seed_count:
			LawnDefs.PLANT_DEFS.resize(_base_seed_count)
		if _base_reanim_count > 0 and ReanimTypes.files.size() > _base_reanim_count:
			ReanimTypes.truncate(_base_reanim_count)
	level = null
	_plants_by_seed.clear()
	_seed_by_cid.clear()
	_zombies.clear()
	_installed = false

static func is_active() -> bool:
	return level != null

# ================================================================ defaults
static func default_plant(cid: int) -> Dictionary:
	return {
		"cid": cid,
		"name": "Custom Plant",
		"description": "A plant of your own design.",
		"base": PvZ.SEED_PEASHOOTER,
		"cost": 100,
		"recharge": 750,
		"health": 300,
		"damage": 20,
		"fire_rate": 150,
		"reanim": "",          ## asset key of a .reanim; empty = the base plant's reanim
		"packet_image": "",    ## asset key drawn on the seed packet instead of the plant
		"packet_bg": -1,       ## seed packet background cel, -1 = follow the base plant
		"tint": [255, 255, 255],
		"scale": 1.0,
		"sun_amount": 25,
		"sun_interval": 2500,
		"range_rows": 0,
		"armor": 0,
		"explodes": false,
		"explode_radius": 115,
		"nocturnal": false,
		"aquatic": false,
		"instant": false,
	}

static func default_zombie(cid: int) -> Dictionary:
	return {
		"cid": cid,
		"name": "Custom Zombie",
		"description": "A zombie of your own design.",
		"base": PvZ.ZOMBIE_NORMAL,
		"health": 270,
		"helm_health": -1,      ## -1 = keep whatever the base type gives it
		"shield_health": -1,
		"speed": 1.0,           ## multiplier on the base walk speed
		"damage": 100,          ## bite damage per second-ish, relative to 100 = normal
		"scale": 1.0,
		"tint": [255, 255, 255],
		"reanim": "",           ## asset key; replaces the body reanim for this zombie only
		"part_skins": {},       ## track name -> image asset key
		"value": 1,
		"weight": 1000,
		"freeze_immune": false,
		"instakill_immune": false,
		"hypno_immune": false,
		"explode_on_death": false,
		"explode_damage": 0,
		"death_event": "",
		"spawn_event": "",
	}

# ================================================================ custom plants
static func _register_plant(p: Dictionary) -> void:
	var cid := int(p.get("cid", -1))
	if cid < 0:
		return
	var base := int(p.get("base", PvZ.SEED_PEASHOOTER))
	var base_def: Array = LawnCommon.plant_def(base)
	var reanim_type: int = base_def[LawnCommon.PDEF_REANIM]
	var key := str(p.get("reanim", ""))
	if key != "":
		var def := CustomAssets.get_reanim_def(key)
		if def != null:
			reanim_type = ReanimTypes.register_def("custom:" + key, def)
	var seed_type := LawnDefs.PLANT_DEFS.size()
	var packet: int = int(p.get("packet_bg", -1))
	if packet < 0:
		packet = base_def[LawnCommon.PDEF_PACKET]
	LawnDefs.PLANT_DEFS.append([
		seed_type,
		reanim_type,
		packet,
		int(p.get("cost", 100)),
		int(p.get("recharge", 750)),
		base_def[LawnCommon.PDEF_SUBCLASS],
		int(p.get("fire_rate", base_def[LawnCommon.PDEF_LAUNCH_RATE])),
		str(p.get("name", "Custom Plant")),
	])
	_plants_by_seed[seed_type] = p
	_seed_by_cid[cid] = seed_type

static func is_custom_plant(seed_type: int) -> bool:
	return _plants_by_seed.has(seed_type)

static func plant_profile(seed_type: int) -> Dictionary:
	return _plants_by_seed.get(seed_type, {})

static func plant_base(seed_type: int) -> int:
	var p: Dictionary = _plants_by_seed.get(seed_type, {})
	return int(p.get("base", PvZ.SEED_PEASHOOTER)) if not p.is_empty() else seed_type

static func seed_type_for_cid(cid: int) -> int:
	return int(_seed_by_cid.get(cid, PvZ.SEED_NONE))

static func custom_plant_seed_types() -> Array:
	var out: Array = _plants_by_seed.keys()
	out.sort()
	return out

static func plant_name(seed_type: int) -> String:
	var p: Dictionary = _plants_by_seed.get(seed_type, {})
	return str(p.get("name", "")) if not p.is_empty() else ""

## Applied from Plant.plant_initialize once the base behaviour has been set up.
static func apply_plant_profile(plant: Plant) -> void:
	var p: Dictionary = _plants_by_seed.get(plant.custom_seed, {})
	if p.is_empty():
		return
	plant.plant_health = int(p.get("health", plant.plant_health))
	plant.plant_max_health = plant.plant_health
	var r := Plant.rv(plant.body_reanim)
	if r != null:
		var scale := float(p.get("scale", 1.0))
		if not is_equal_approx(scale, 1.0):
			r.override_scale(scale, scale)
		var tint: Array = p.get("tint", [255, 255, 255])
		if tint.size() >= 3 and (int(tint[0]) != 255 or int(tint[1]) != 255 or int(tint[2]) != 255):
			r.color_override = Color8(int(tint[0]), int(tint[1]), int(tint[2]))

## Damage multiplier a custom plant's projectiles get, relative to the base plant.
static func plant_damage_scale(seed_type: int) -> float:
	var p: Dictionary = _plants_by_seed.get(seed_type, {})
	if p.is_empty():
		return 1.0
	var base := int(p.get("base", PvZ.SEED_PEASHOOTER))
	var base_damage := 20
	match base:
		PvZ.SEED_CABBAGEPULT, PvZ.SEED_KERNELPULT, PvZ.SEED_FUMESHROOM: base_damage = 40
		PvZ.SEED_MELONPULT, PvZ.SEED_WINTERMELON: base_damage = 80
	return float(p.get("damage", base_damage)) / float(maxi(base_damage, 1))

# ================================================================ custom zombies
static func zombie_profile(cid: int) -> Dictionary:
	return _zombies.get(cid, {})

static func zombie_base(cid: int) -> int:
	var z: Dictionary = _zombies.get(cid, {})
	return int(z.get("base", PvZ.ZOMBIE_NORMAL)) if not z.is_empty() else PvZ.ZOMBIE_NORMAL

static func zombie_name(cid: int) -> String:
	var z: Dictionary = _zombies.get(cid, {})
	return str(z.get("name", "")) if not z.is_empty() else ""

static func has_zombie(cid: int) -> bool:
	return _zombies.has(cid)

static func custom_zombie_ids() -> Array:
	var out: Array = _zombies.keys()
	out.sort()
	return out

## Applied from Zombie.zombie_initialize, after the base type finished setting itself up and
## before max health is latched.
static func apply_zombie_profile(z: Zombie) -> void:
	var p: Dictionary = _zombies.get(z.custom_id, {})
	if p.is_empty():
		return
	z.body_health = maxi(1, int(p.get("health", z.body_health)))
	var helm := int(p.get("helm_health", -1))
	if helm >= 0:
		z.helm_health = helm
	var shield := int(p.get("shield_health", -1))
	if shield >= 0:
		z.shield_health = shield
	var speed := float(p.get("speed", 1.0))
	if not is_equal_approx(speed, 1.0):
		z.vel_x *= speed
	z.scale_zombie *= float(p.get("scale", 1.0))
	var r := Zombie.rv(z.body_reanim)
	if r != null:
		var tint: Array = p.get("tint", [255, 255, 255])
		if tint.size() >= 3 and (int(tint[0]) != 255 or int(tint[1]) != 255 or int(tint[2]) != 255):
			r.color_override = Color8(int(tint[0]), int(tint[1]), int(tint[2]))
		var parts: Dictionary = p.get("part_skins", {})
		if not parts.is_empty():
			CustomAssets.apply_part_dict(r, parts)

## Body reanim replacement for one custom zombie (empty when it uses the base art).
static func zombie_reanim_type(cid: int, fallback: int) -> int:
	var p: Dictionary = _zombies.get(cid, {})
	var key := str(p.get("reanim", "")) if not p.is_empty() else ""
	if key == "":
		return fallback
	var def := CustomAssets.get_reanim_def(key)
	if def == null:
		return fallback
	return ReanimTypes.register_def("customz:" + key, def)

static func zombie_damage_scale(cid: int) -> float:
	var p: Dictionary = _zombies.get(cid, {})
	if p.is_empty():
		return 1.0
	return float(p.get("damage", 100)) / 100.0

# ================================================================ boss
static func boss_config() -> Dictionary:
	return level.boss if level != null else LevelDef.default_boss()

static func boss_enabled() -> bool:
	return level != null and bool(level.boss.get("enabled", false))

## Body reanim replacement for the level's boss, if it brought its own .reanim.
static func boss_reanim_type(fallback: int) -> int:
	if level == null or not boss_enabled():
		return fallback
	var key := str(level.boss.get("reanim", ""))
	if key == "":
		return fallback
	var def := CustomAssets.get_reanim_def(key)
	if def == null:
		return fallback
	return ReanimTypes.register_def("customboss:" + key, def)
