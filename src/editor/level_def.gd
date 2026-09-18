class_name LevelDef
extends RefCounted
## Data model for a community-edition custom level. Everything the editor can change lives here and
## round-trips through JSON (level.json inside the level folder). Defaults reproduce a plain 1-1 style
## grass level, so a brand new level is immediately playable.

const FORMAT_VERSION := 3

# ---------------------------------------------------------------- enums (stored as ints in JSON)
enum { BG_BUILTIN, BG_CUSTOM }
## Lane metrics: how rows are spaced / sloped. Independent of what a lane "counts as".
enum { GEOM_GRASS, GEOM_POOL, GEOM_ROOF }
## Where the seed bank comes from.
enum { SEEDS_CHOOSER, SEEDS_PRESET, SEEDS_CONVEYOR, SEEDS_NONE }
## Lawn mower kind placed at the start of each playable row.
enum { MOWERS_NONE, MOWERS_AUTO, MOWERS_LAWN, MOWERS_POOL, MOWERS_ROOF }
## What ends the level with a win.
enum { WIN_WAVES, WIN_TIME, WIN_KILLS, WIN_SCRIPT }
## Where zombies come from at spawn time.
enum { SPAWN_WALK_RIGHT, SPAWN_GRAVES, SPAWN_ANY }

const GEOM_NAMES := ["Grass (5 lanes)", "Pool (6 lanes)", "Roof (5 lanes, sloped)"]
const SEEDS_NAMES := ["Seed chooser", "Preset bank", "Conveyor belt", "No seed bank"]
const MOWER_NAMES := ["None", "Match lane", "Lawn mower", "Pool cleaner", "Roof cleaner"]
const WIN_NAMES := ["Survive all waves", "Survive a time limit", "Kill N zombies", "Script decides"]
const ROW_TYPE_NAMES := ["Blocked (dirt)", "Ground", "Water", "High ground"]
const BG_NAMES := ["Day", "Night", "Pool", "Fog", "Roof", "Boss roof", "(7)", "Mushroom garden",
	"Greenhouse", "Aquarium", "Tree of wisdom"]

# ---------------------------------------------------------------- identity
var id := ""              ## folder name, unique per profile
var level_name := "New Level"
var author := ""
var description := ""
var created_unix := 0
var modified_unix := 0
var format_version := FORMAT_VERSION

# ---------------------------------------------------------------- stage
var bg_mode := BG_BUILTIN
var bg_builtin := PvZ.BACKGROUND_1_DAY
var bg_image := ""            ## custom asset key, drawn at the board origin
var bg_offset := Vector2i(0, 0)
var bg_scale := 1.0
var geometry := GEOM_GRASS
var night := false
var pool_water := false       ## draw the animated water overlay (builtin pool look)
var fog := false
var fog_column := 4
var bushes := true
var graves := false
var walk_in_from_right := true
var mowers := MOWERS_AUTO
var shake_on_spawn := false
## Logical lane types, one per row (PvZ.PLANTROW_*). With a custom background these are pure
## gameplay rules: nothing is drawn for them, so the background image supplies the look.
var row_type := [PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL,
	PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_NORMAL, PvZ.PLANTROW_DIRT]
## Optional per-cell overrides, 9x6, PvZ.GRIDSQUARE_* or -1 to follow the row.
var cell_type: Array = []
## Rows a zombie may be placed in even when the lane is blocked (e.g. decorative dirt lanes).
var force_zombie_rows: Array = []

# ---------------------------------------------------------------- rules
var start_sun := 50
var sun_drop := true
var sun_drop_first := 550
var sun_drop_min := 425
var sun_drop_max := 700
var sun_value := 25
var seed_mode := SEEDS_CHOOSER
var num_choose := 6
var allowed_seeds: Array = []      ## empty = everything the profile owns
var preset_seeds: Array = []       ## seed types for SEEDS_PRESET, in bank order
var conveyor_seeds: Array = []     ## [{"seed": int, "weight": int, "max": int}]
var conveyor_speed := 4
var shovel := true
var can_lose := true
var waves_per_flag := 10
var flag_final_wave := true
var win_mode := WIN_WAVES
var win_time := 0                  ## in ticks (100/s) for WIN_TIME
var win_kills := 0
var music_tune := PvZ.MUSIC_TUNE_DAY_GRASSWALK
var music_custom := ""             ## custom asset key (ogg/wav), overrides music_tune
var zombie_health_scale := 1.0
var zombie_speed_scale := 1.0
var plant_health_scale := 1.0
var plant_damage_scale := 1.0
var level_number := 1              ## what the game reports as "level" (affects a few built-in rules)
var award_seed := PvZ.SEED_NONE    ## plant handed out on win, SEED_NONE for none
var progress_meter := true
var final_wave_banner := true

# ---------------------------------------------------------------- waves
## Each wave: {"flag": bool, "delay": int, "health_trigger": float, "message": "",
##             "entries": [{"zombie": int, "custom": int, "count": int, "row": int}], "event": ""}
var waves: Array = []

# ---------------------------------------------------------------- crazy dave
var dave_enabled := false
var dave_intro: Array = []         ## lines before the level starts
var dave_win: Array = []           ## lines on the award screen
var dave_wave_lines: Array = []    ## [{"wave": int, "text": ""}]

# ---------------------------------------------------------------- board contents
## [{"x": int, "y": int, "seed": int, "custom": int, "imitater": int}]
var preset_plants: Array = []
## [{"x": int, "y": int, "type": int}] with PvZ.GRIDITEM_* (gravestone, crater, ladder, ...)
var preset_items: Array = []

# ---------------------------------------------------------------- custom content
## key -> {"type": "image"|"reanim"|"sound", "file": "assets/xyz.png"}
var assets: Dictionary = {}
## Reskins. reanim_skins: PvZ.REANIM_* (as string key) -> asset key of a .reanim
var reanim_skins: Dictionary = {}
## part_skins: "<REANIM_ID>" -> {"<track name>": asset key of an image}
var part_skins: Dictionary = {}
## image_skins: resource id ("IMAGE_BACKGROUND1") -> asset key
var image_skins: Dictionary = {}

## Custom plants, see CustomDefs.PLANT_FIELDS
var custom_plants: Array = []
## Custom zombies, see CustomDefs.ZOMBIE_FIELDS
var custom_zombies: Array = []
## Boss configuration, see CustomDefs.BOSS_FIELDS
var boss: Dictionary = {}

# ---------------------------------------------------------------- scripting
## Block script: {"stacks": [ {"x": float, "y": float, "blocks": [ ... ]} ], "vars": {name: value}}
var script_data: Dictionary = {"stacks": [], "vars": {}}

# ================================================================ construction
func _init() -> void:
	created_unix = int(Time.get_unix_time_from_system())
	modified_unix = created_unix
	cell_type = make_empty_cells()
	boss = default_boss()
	waves = default_waves()
	preset_seeds = [PvZ.SEED_PEASHOOTER, PvZ.SEED_SUNFLOWER, PvZ.SEED_CHERRYBOMB, PvZ.SEED_WALLNUT,
		PvZ.SEED_POTATOMINE, PvZ.SEED_SNOWPEA]

static func make_empty_cells() -> Array:
	var out: Array = []
	for gx in BoardCore.MAX_GRID_SIZE_X:
		var col: Array = []
		for gy in BoardCore.MAX_GRID_SIZE_Y:
			col.append(-1)
		out.append(col)
	return out

static func default_boss() -> Dictionary:
	return {
		"enabled": false,
		"name": "Dr. Zomboss",
		"reanim": "",                  ## asset key; empty = the built-in boss reanim
		"health": 40000,
		"phases": 3,
		"enter_wave": -1,              ## -1 = at the final wave, otherwise the wave index
		"stomp": true,
		"fireball": true,
		"iceball": true,
		"summon": true,
		"bungee": true,
		"summon_zombies": [PvZ.ZOMBIE_NORMAL, PvZ.ZOMBIE_TRAFFIC_CONE],
		"attack_interval": 700,
		"speed": 1.0,
		"music": PvZ.MUSIC_TUNE_FINAL_BOSS_BRAINIAC_MANIAC,
		"death_event": "",
	}

static func default_waves() -> Array:
	var out: Array = []
	for i in 10:
		out.append(new_wave(i == 9))
	return out

static func new_wave(flag: bool = false) -> Dictionary:
	return {
		"flag": flag,
		"delay": 0,               ## 0 = use the standard countdown
		"health_trigger": 0.6,    ## fraction of the previous wave's health that releases the next one
		"message": "",
		"event": "",
		"entries": [{"zombie": PvZ.ZOMBIE_NORMAL, "custom": -1, "count": 1, "row": -1}],
	}

static func new_entry(zombie_type: int = PvZ.ZOMBIE_NORMAL) -> Dictionary:
	return {"zombie": zombie_type, "custom": -1, "count": 1, "row": -1}

# ================================================================ derived helpers
func uses_custom_background() -> bool:
	return bg_mode == BG_CUSTOM and bg_image != ""

## Number of rows the lane metrics produce (the grid is always 6 wide internally).
func row_count() -> int:
	return 6 if geometry == GEOM_POOL else 5

func lane_type(gy: int) -> int:
	if gy < 0 or gy >= row_type.size():
		return PvZ.PLANTROW_DIRT
	return int(row_type[gy])

func cell_square_type(gx: int, gy: int) -> int:
	if gx < 0 or gx >= BoardCore.MAX_GRID_SIZE_X or gy < 0 or gy >= BoardCore.MAX_GRID_SIZE_Y:
		return PvZ.GRIDSQUARE_NONE
	var override: int = int(cell_type[gx][gy])
	if override >= 0:
		return override
	match lane_type(gy):
		PvZ.PLANTROW_DIRT: return PvZ.GRIDSQUARE_DIRT
		PvZ.PLANTROW_POOL: return PvZ.GRIDSQUARE_POOL
		PvZ.PLANTROW_HIGH_GROUND: return PvZ.GRIDSQUARE_HIGH_GROUND
	return PvZ.GRIDSQUARE_GRASS

func total_zombie_count() -> int:
	var n := 0
	for w in waves:
		for e in w.entries:
			n += int(e.count)
	return n

func mower_type_for_row(gy: int) -> int:
	match mowers:
		MOWERS_NONE: return -1
		MOWERS_LAWN: return PvZ.LAWNMOWER_LAWN
		MOWERS_POOL: return PvZ.LAWNMOWER_POOL
		MOWERS_ROOF: return PvZ.LAWNMOWER_ROOF
	# MOWERS_AUTO
	if lane_type(gy) == PvZ.PLANTROW_DIRT:
		return -1
	if lane_type(gy) == PvZ.PLANTROW_POOL:
		return PvZ.LAWNMOWER_POOL
	if geometry == GEOM_ROOF:
		return PvZ.LAWNMOWER_ROOF
	return PvZ.LAWNMOWER_LAWN

func wave_is_flag(index: int) -> bool:
	if index < 0 or index >= waves.size():
		return false
	if bool(waves[index].flag):
		return true
	if waves_per_flag > 0 and (index + 1) % waves_per_flag == 0:
		return true
	return flag_final_wave and index == waves.size() - 1

func dave_line_for_wave(wave: int) -> String:
	for e in dave_wave_lines:
		if int(e.wave) == wave:
			return str(e.text)
	return ""

func find_custom_plant(cid: int) -> Dictionary:
	for p in custom_plants:
		if int(p.get("cid", -1)) == cid:
			return p
	return {}

func find_custom_zombie(cid: int) -> Dictionary:
	for z in custom_zombies:
		if int(z.get("cid", -1)) == cid:
			return z
	return {}

func next_custom_id(list: Array) -> int:
	var best := 0
	for e in list:
		best = maxi(best, int(e.get("cid", 0)) + 1)
	return best

## Asset keys actually referenced anywhere, used to prune orphans on save.
func referenced_assets() -> Array:
	var out: Array = []
	var push := func(k) -> void:
		var s := str(k)
		if s != "" and not out.has(s):
			out.append(s)
	push.call(bg_image)
	push.call(music_custom)
	for v in reanim_skins.values():
		push.call(v)
	for tracks in part_skins.values():
		for v in tracks.values():
			push.call(v)
	for v in image_skins.values():
		push.call(v)
	for p in custom_plants:
		push.call(p.get("reanim", ""))
		push.call(p.get("packet_image", ""))
	for z in custom_zombies:
		push.call(z.get("reanim", ""))
		for v in Dictionary(z.get("part_skins", {})).values():
			push.call(v)
	push.call(boss.get("reanim", ""))
	return out

# ================================================================ serialisation
func to_dict() -> Dictionary:
	return {
		"format_version": FORMAT_VERSION,
		"id": id,
		"name": level_name,
		"author": author,
		"description": description,
		"created": created_unix,
		"modified": modified_unix,
		"stage": {
			"bg_mode": bg_mode, "bg_builtin": bg_builtin, "bg_image": bg_image,
			"bg_offset": [bg_offset.x, bg_offset.y], "bg_scale": bg_scale,
			"geometry": geometry, "night": night, "pool_water": pool_water,
			"fog": fog, "fog_column": fog_column, "bushes": bushes, "graves": graves,
			"walk_in_from_right": walk_in_from_right, "mowers": mowers,
			"shake_on_spawn": shake_on_spawn,
			"row_type": row_type.duplicate(), "cell_type": _cells_to_flat(),
			"force_zombie_rows": force_zombie_rows.duplicate(),
		},
		"rules": {
			"start_sun": start_sun, "sun_drop": sun_drop, "sun_drop_first": sun_drop_first,
			"sun_drop_min": sun_drop_min, "sun_drop_max": sun_drop_max, "sun_value": sun_value,
			"seed_mode": seed_mode, "num_choose": num_choose,
			"allowed_seeds": allowed_seeds.duplicate(), "preset_seeds": preset_seeds.duplicate(),
			"conveyor_seeds": conveyor_seeds.duplicate(true), "conveyor_speed": conveyor_speed,
			"shovel": shovel, "can_lose": can_lose,
			"waves_per_flag": waves_per_flag, "flag_final_wave": flag_final_wave,
			"win_mode": win_mode, "win_time": win_time, "win_kills": win_kills,
			"music_tune": music_tune, "music_custom": music_custom,
			"zombie_health_scale": zombie_health_scale, "zombie_speed_scale": zombie_speed_scale,
			"plant_health_scale": plant_health_scale, "plant_damage_scale": plant_damage_scale,
			"level_number": level_number, "award_seed": award_seed,
			"progress_meter": progress_meter, "final_wave_banner": final_wave_banner,
		},
		"waves": waves.duplicate(true),
		"dave": {
			"enabled": dave_enabled, "intro": dave_intro.duplicate(),
			"win": dave_win.duplicate(), "wave_lines": dave_wave_lines.duplicate(true),
		},
		"board": {"plants": preset_plants.duplicate(true), "items": preset_items.duplicate(true)},
		"assets": assets.duplicate(true),
		"skins": {
			"reanim": reanim_skins.duplicate(true),
			"parts": part_skins.duplicate(true),
			"images": image_skins.duplicate(true),
		},
		"custom_plants": custom_plants.duplicate(true),
		"custom_zombies": custom_zombies.duplicate(true),
		"boss": boss.duplicate(true),
		"script": script_data.duplicate(true),
	}

func _cells_to_flat() -> Array:
	var out: Array = []
	for gx in BoardCore.MAX_GRID_SIZE_X:
		for gy in BoardCore.MAX_GRID_SIZE_Y:
			out.append(int(cell_type[gx][gy]))
	return out

func _cells_from_flat(flat: Array) -> void:
	cell_type = make_empty_cells()
	var i := 0
	for gx in BoardCore.MAX_GRID_SIZE_X:
		for gy in BoardCore.MAX_GRID_SIZE_Y:
			if i < flat.size():
				cell_type[gx][gy] = int(flat[i])
			i += 1

static func from_dict(d: Dictionary) -> LevelDef:
	var l := LevelDef.new()
	l.format_version = int(d.get("format_version", 1))
	l.id = str(d.get("id", ""))
	l.level_name = str(d.get("name", "Unnamed"))
	l.author = str(d.get("author", ""))
	l.description = str(d.get("description", ""))
	l.created_unix = int(d.get("created", 0))
	l.modified_unix = int(d.get("modified", 0))

	var s: Dictionary = d.get("stage", {})
	l.bg_mode = int(s.get("bg_mode", BG_BUILTIN))
	l.bg_builtin = int(s.get("bg_builtin", PvZ.BACKGROUND_1_DAY))
	l.bg_image = str(s.get("bg_image", ""))
	var off: Array = s.get("bg_offset", [0, 0])
	l.bg_offset = Vector2i(int(off[0]) if off.size() > 0 else 0, int(off[1]) if off.size() > 1 else 0)
	l.bg_scale = float(s.get("bg_scale", 1.0))
	l.geometry = int(s.get("geometry", GEOM_GRASS))
	l.night = bool(s.get("night", false))
	l.pool_water = bool(s.get("pool_water", false))
	l.fog = bool(s.get("fog", false))
	l.fog_column = int(s.get("fog_column", 4))
	l.bushes = bool(s.get("bushes", true))
	l.graves = bool(s.get("graves", false))
	l.walk_in_from_right = bool(s.get("walk_in_from_right", true))
	l.mowers = int(s.get("mowers", MOWERS_AUTO))
	l.shake_on_spawn = bool(s.get("shake_on_spawn", false))
	var rt: Array = s.get("row_type", [])
	if rt.size() == BoardCore.MAX_GRID_SIZE_Y:
		l.row_type = rt.map(func(v): return int(v))
	l._cells_from_flat(s.get("cell_type", []))
	l.force_zombie_rows = (s.get("force_zombie_rows", []) as Array).map(func(v): return int(v))

	var r: Dictionary = d.get("rules", {})
	l.start_sun = int(r.get("start_sun", 50))
	l.sun_drop = bool(r.get("sun_drop", true))
	l.sun_drop_first = int(r.get("sun_drop_first", 550))
	l.sun_drop_min = int(r.get("sun_drop_min", 425))
	l.sun_drop_max = int(r.get("sun_drop_max", 700))
	l.sun_value = int(r.get("sun_value", 25))
	l.seed_mode = int(r.get("seed_mode", SEEDS_CHOOSER))
	l.num_choose = int(r.get("num_choose", 6))
	l.allowed_seeds = (r.get("allowed_seeds", []) as Array).map(func(v): return int(v))
	l.preset_seeds = (r.get("preset_seeds", []) as Array).map(func(v): return int(v))
	l.conveyor_seeds = (r.get("conveyor_seeds", []) as Array).duplicate(true)
	l.conveyor_speed = int(r.get("conveyor_speed", 4))
	l.shovel = bool(r.get("shovel", true))
	l.can_lose = bool(r.get("can_lose", true))
	l.waves_per_flag = int(r.get("waves_per_flag", 10))
	l.flag_final_wave = bool(r.get("flag_final_wave", true))
	l.win_mode = int(r.get("win_mode", WIN_WAVES))
	l.win_time = int(r.get("win_time", 0))
	l.win_kills = int(r.get("win_kills", 0))
	l.music_tune = int(r.get("music_tune", PvZ.MUSIC_TUNE_DAY_GRASSWALK))
	l.music_custom = str(r.get("music_custom", ""))
	l.zombie_health_scale = float(r.get("zombie_health_scale", 1.0))
	l.zombie_speed_scale = float(r.get("zombie_speed_scale", 1.0))
	l.plant_health_scale = float(r.get("plant_health_scale", 1.0))
	l.plant_damage_scale = float(r.get("plant_damage_scale", 1.0))
	l.level_number = int(r.get("level_number", 1))
	l.award_seed = int(r.get("award_seed", PvZ.SEED_NONE))
	l.progress_meter = bool(r.get("progress_meter", true))
	l.final_wave_banner = bool(r.get("final_wave_banner", true))

	l.waves = _sanitise_waves(d.get("waves", []))

	var dv: Dictionary = d.get("dave", {})
	l.dave_enabled = bool(dv.get("enabled", false))
	l.dave_intro = (dv.get("intro", []) as Array).map(func(v): return str(v))
	l.dave_win = (dv.get("win", []) as Array).map(func(v): return str(v))
	l.dave_wave_lines = (dv.get("wave_lines", []) as Array).duplicate(true)

	var b: Dictionary = d.get("board", {})
	l.preset_plants = (b.get("plants", []) as Array).duplicate(true)
	l.preset_items = (b.get("items", []) as Array).duplicate(true)

	l.assets = (d.get("assets", {}) as Dictionary).duplicate(true)
	var sk: Dictionary = d.get("skins", {})
	l.reanim_skins = (sk.get("reanim", {}) as Dictionary).duplicate(true)
	l.part_skins = (sk.get("parts", {}) as Dictionary).duplicate(true)
	l.image_skins = (sk.get("images", {}) as Dictionary).duplicate(true)

	l.custom_plants = (d.get("custom_plants", []) as Array).duplicate(true)
	l.custom_zombies = (d.get("custom_zombies", []) as Array).duplicate(true)
	var bs: Dictionary = default_boss()
	bs.merge(d.get("boss", {}), true)
	l.boss = bs
	var sc: Dictionary = d.get("script", {})
	l.script_data = {"stacks": (sc.get("stacks", []) as Array).duplicate(true),
		"vars": (sc.get("vars", {}) as Dictionary).duplicate(true)}
	return l

## Defensive: a hand-edited or older file must never crash the game.
static func _sanitise_waves(raw: Array) -> Array:
	var out: Array = []
	for w in raw:
		if typeof(w) != TYPE_DICTIONARY:
			continue
		var wave := new_wave()
		wave.flag = bool(w.get("flag", false))
		wave.delay = int(w.get("delay", 0))
		wave.health_trigger = float(w.get("health_trigger", 0.6))
		wave.message = str(w.get("message", ""))
		wave.event = str(w.get("event", ""))
		var entries: Array = []
		for e in (w.get("entries", []) as Array):
			if typeof(e) != TYPE_DICTIONARY:
				continue
			entries.append({
				"zombie": int(e.get("zombie", PvZ.ZOMBIE_NORMAL)),
				"custom": int(e.get("custom", -1)),
				"count": maxi(1, int(e.get("count", 1))),
				"row": int(e.get("row", -1)),
			})
		wave.entries = entries
		out.append(wave)
	if out.is_empty():
		out = default_waves()
	return out

func to_json() -> String:
	return JSON.stringify(to_dict(), "\t")

static func from_json(text: String) -> LevelDef:
	var parsed = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		return null
	return from_dict(parsed)

func duplicate_def() -> LevelDef:
	return LevelDef.from_dict(to_dict())
