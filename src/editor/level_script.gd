class_name LevelScript
## Block scripting for custom levels: the catalogue the editor draws from, and the little VM that
## runs the stacks while a custom level is being played.
##
## A block is {"op": String, "args": {name: value-or-block}, "body": [blocks], "body2": [blocks]}.
## Hat blocks sit at the top of a stack and say when it runs; everything else is a command.
## Reporter blocks appear inside args and produce a value.
##
## Threads run on the board's 100 Hz tick. Each one keeps a small frame stack so repeat / forever /
## if / wait can suspend cleanly between ticks without recursion.

const TICKS_PER_SECOND := 100
## Instructions a single thread may run in one tick before it is forced to yield (loop guard).
const MAX_STEPS_PER_TICK := 400

# ================================================================ block catalogue
enum { KIND_HAT, KIND_COMMAND, KIND_CONTROL, KIND_REPORTER, KIND_BOOLEAN }

## Argument kinds decide which editor widget a slot gets.
enum { ARG_NUMBER, ARG_TEXT, ARG_ZOMBIE, ARG_PLANT, ARG_ROW, ARG_COL, ARG_BOOL, ARG_VAR,
	ARG_EVENT, ARG_SOUND, ARG_MUSIC, ARG_LANE_TYPE, ARG_ANY, ARG_GRIDITEM }

const CAT_EVENTS := "Events"
const CAT_ZOMBIES := "Zombies"
const CAT_PLANTS := "Plants"
const CAT_BOARD := "Board"
const CAT_FLOW := "Control"
const CAT_DATA := "Data"
const CAT_LOOKS := "Looks & sound"
const CAT_GAME := "Level"

const CATEGORY_COLORS := {
	CAT_EVENTS: Color8(224, 168, 38),
	CAT_ZOMBIES: Color8(150, 92, 168),
	CAT_PLANTS: Color8(80, 158, 62),
	CAT_BOARD: Color8(198, 108, 60),
	CAT_FLOW: Color8(222, 150, 44),
	CAT_DATA: Color8(200, 72, 72),
	CAT_LOOKS: Color8(88, 122, 200),
	CAT_GAME: Color8(120, 120, 136),
}

## op -> {kind, cat, text, args:[{name, kind, default, label}], has_body, has_body2}
## `text` uses %name% placeholders that the editor replaces with argument slots.
static var BLOCKS: Dictionary = _build_blocks()

static func _b(kind: int, cat: String, text: String, args: Array = [], has_body := false, has_body2 := false) -> Dictionary:
	return {"kind": kind, "cat": cat, "text": text, "args": args, "has_body": has_body, "has_body2": has_body2}

static func _a(name: String, kind: int, default = 0) -> Dictionary:
	return {"name": name, "kind": kind, "default": default}

static func _build_blocks() -> Dictionary:
	var d: Dictionary = {}

	# ---------------------------------------------------------------- hats
	d["when_level_start"] = _b(KIND_HAT, CAT_EVENTS, "when the level starts")
	d["when_wave"] = _b(KIND_HAT, CAT_EVENTS, "when wave %wave% begins", [_a("wave", ARG_NUMBER, 1)])
	d["when_any_wave"] = _b(KIND_HAT, CAT_EVENTS, "when any wave begins")
	d["when_flag_wave"] = _b(KIND_HAT, CAT_EVENTS, "when a flag wave begins")
	d["when_final_wave"] = _b(KIND_HAT, CAT_EVENTS, "when the final wave begins")
	d["when_zombie_dies"] = _b(KIND_HAT, CAT_EVENTS, "when a zombie dies")
	d["when_plant_placed"] = _b(KIND_HAT, CAT_EVENTS, "when a plant is planted")
	d["when_plant_eaten"] = _b(KIND_HAT, CAT_EVENTS, "when a plant is eaten")
	d["when_mower_fires"] = _b(KIND_HAT, CAT_EVENTS, "when a lawn mower fires")
	d["when_sun_collected"] = _b(KIND_HAT, CAT_EVENTS, "when sun is collected")
	d["when_every"] = _b(KIND_HAT, CAT_EVENTS, "every %seconds% seconds", [_a("seconds", ARG_NUMBER, 10)])
	d["when_event"] = _b(KIND_HAT, CAT_EVENTS, "when I receive %event%", [_a("event", ARG_EVENT, "")])
	d["when_boss_phase"] = _b(KIND_HAT, CAT_EVENTS, "when the boss enters phase %phase%", [_a("phase", ARG_NUMBER, 2)])
	d["when_level_won"] = _b(KIND_HAT, CAT_EVENTS, "when the level is won")
	d["when_level_lost"] = _b(KIND_HAT, CAT_EVENTS, "when the level is lost")

	# ---------------------------------------------------------------- zombies
	d["spawn_zombie"] = _b(KIND_COMMAND, CAT_ZOMBIES, "spawn %count% %zombie% in lane %row%",
		[_a("count", ARG_NUMBER, 1), _a("zombie", ARG_ZOMBIE, PvZ.ZOMBIE_NORMAL), _a("row", ARG_ROW, -1)])
	d["spawn_custom_zombie"] = _b(KIND_COMMAND, CAT_ZOMBIES, "spawn %count% of custom zombie %cid% in lane %row%",
		[_a("count", ARG_NUMBER, 1), _a("cid", ARG_NUMBER, 0), _a("row", ARG_ROW, -1)])
	d["spawn_zombie_at"] = _b(KIND_COMMAND, CAT_ZOMBIES, "spawn %zombie% at column %col% lane %row%",
		[_a("zombie", ARG_ZOMBIE, PvZ.ZOMBIE_NORMAL), _a("col", ARG_COL, 8), _a("row", ARG_ROW, 0)])
	d["kill_zombies_row"] = _b(KIND_COMMAND, CAT_ZOMBIES, "destroy every zombie in lane %row%", [_a("row", ARG_ROW, -1)])
	d["kill_all_zombies"] = _b(KIND_COMMAND, CAT_ZOMBIES, "destroy every zombie")
	d["freeze_zombies"] = _b(KIND_COMMAND, CAT_ZOMBIES, "chill every zombie for %seconds% seconds", [_a("seconds", ARG_NUMBER, 10)])
	d["set_zombie_speed"] = _b(KIND_COMMAND, CAT_ZOMBIES, "set zombie speed to %scale% x", [_a("scale", ARG_NUMBER, 1)])
	d["set_zombie_health_scale"] = _b(KIND_COMMAND, CAT_ZOMBIES, "set new zombie health to %scale% x", [_a("scale", ARG_NUMBER, 1)])
	d["zombies_alive"] = _b(KIND_REPORTER, CAT_ZOMBIES, "zombies on the lawn")
	d["zombies_alive_row"] = _b(KIND_REPORTER, CAT_ZOMBIES, "zombies in lane %row%", [_a("row", ARG_ROW, 0)])
	d["zombies_killed"] = _b(KIND_REPORTER, CAT_ZOMBIES, "zombies destroyed so far")

	# ---------------------------------------------------------------- plants
	d["plant_at"] = _b(KIND_COMMAND, CAT_PLANTS, "plant %plant% at column %col% lane %row%",
		[_a("plant", ARG_PLANT, PvZ.SEED_PEASHOOTER), _a("col", ARG_COL, 0), _a("row", ARG_ROW, 0)])
	d["remove_plant_at"] = _b(KIND_COMMAND, CAT_PLANTS, "remove the plant at column %col% lane %row%",
		[_a("col", ARG_COL, 0), _a("row", ARG_ROW, 0)])
	d["give_packet"] = _b(KIND_COMMAND, CAT_PLANTS, "add %plant% to the seed bank", [_a("plant", ARG_PLANT, PvZ.SEED_PEASHOOTER)])
	d["remove_packet"] = _b(KIND_COMMAND, CAT_PLANTS, "remove %plant% from the seed bank", [_a("plant", ARG_PLANT, PvZ.SEED_PEASHOOTER)])
	d["recharge_all"] = _b(KIND_COMMAND, CAT_PLANTS, "recharge every seed packet")
	d["plants_alive"] = _b(KIND_REPORTER, CAT_PLANTS, "plants on the lawn")
	d["plant_at_reporter"] = _b(KIND_BOOLEAN, CAT_PLANTS, "a plant is at column %col% lane %row%",
		[_a("col", ARG_COL, 0), _a("row", ARG_ROW, 0)])

	# ---------------------------------------------------------------- board
	d["add_sun"] = _b(KIND_COMMAND, CAT_BOARD, "change sun by %amount%", [_a("amount", ARG_NUMBER, 50)])
	d["set_sun"] = _b(KIND_COMMAND, CAT_BOARD, "set sun to %amount%", [_a("amount", ARG_NUMBER, 50)])
	d["drop_sun"] = _b(KIND_COMMAND, CAT_BOARD, "drop %count% sun from the sky", [_a("count", ARG_NUMBER, 1)])
	d["shake"] = _b(KIND_COMMAND, CAT_BOARD, "shake the board")
	d["spawn_item"] = _b(KIND_COMMAND, CAT_BOARD, "put %item% at column %col% lane %row%",
		[_a("item", ARG_GRIDITEM, PvZ.GRIDITEM_GRAVESTONE), _a("col", ARG_COL, 5), _a("row", ARG_ROW, 0)])
	d["set_lane_type"] = _b(KIND_COMMAND, CAT_BOARD, "make lane %row% count as %lane%",
		[_a("row", ARG_ROW, 0), _a("lane", ARG_LANE_TYPE, PvZ.PLANTROW_NORMAL)])
	d["set_ice"] = _b(KIND_COMMAND, CAT_BOARD, "freeze the ground of lane %row% for %seconds% seconds",
		[_a("row", ARG_ROW, 0), _a("seconds", ARG_NUMBER, 10)])
	d["give_mower"] = _b(KIND_COMMAND, CAT_BOARD, "give lane %row% a lawn mower back", [_a("row", ARG_ROW, 0)])
	d["sun_amount"] = _b(KIND_REPORTER, CAT_BOARD, "sun")
	d["current_wave"] = _b(KIND_REPORTER, CAT_BOARD, "current wave")
	d["total_waves"] = _b(KIND_REPORTER, CAT_BOARD, "total waves")
	d["time_elapsed"] = _b(KIND_REPORTER, CAT_BOARD, "seconds since the level started")

	# ---------------------------------------------------------------- control
	d["wait"] = _b(KIND_CONTROL, CAT_FLOW, "wait %seconds% seconds", [_a("seconds", ARG_NUMBER, 1)])
	d["wait_until"] = _b(KIND_CONTROL, CAT_FLOW, "wait until %cond%", [_a("cond", ARG_BOOL, true)])
	d["repeat"] = _b(KIND_CONTROL, CAT_FLOW, "repeat %times%", [_a("times", ARG_NUMBER, 5)], true)
	d["forever"] = _b(KIND_CONTROL, CAT_FLOW, "forever", [], true)
	d["if"] = _b(KIND_CONTROL, CAT_FLOW, "if %cond% then", [_a("cond", ARG_BOOL, true)], true)
	d["if_else"] = _b(KIND_CONTROL, CAT_FLOW, "if %cond% then / else", [_a("cond", ARG_BOOL, true)], true, true)
	d["repeat_until"] = _b(KIND_CONTROL, CAT_FLOW, "repeat until %cond%", [_a("cond", ARG_BOOL, true)], true)
	d["stop_this"] = _b(KIND_CONTROL, CAT_FLOW, "stop this script")
	d["broadcast"] = _b(KIND_COMMAND, CAT_FLOW, "broadcast %event%", [_a("event", ARG_EVENT, "")])

	# ---------------------------------------------------------------- data / operators
	d["set_var"] = _b(KIND_COMMAND, CAT_DATA, "set %name% to %value%", [_a("name", ARG_VAR, ""), _a("value", ARG_ANY, 0)])
	d["change_var"] = _b(KIND_COMMAND, CAT_DATA, "change %name% by %value%", [_a("name", ARG_VAR, ""), _a("value", ARG_NUMBER, 1)])
	d["get_var"] = _b(KIND_REPORTER, CAT_DATA, "%name%", [_a("name", ARG_VAR, "")])
	d["number"] = _b(KIND_REPORTER, CAT_DATA, "%value%", [_a("value", ARG_NUMBER, 0)])
	d["text"] = _b(KIND_REPORTER, CAT_DATA, "%value%", [_a("value", ARG_TEXT, "")])
	d["random"] = _b(KIND_REPORTER, CAT_DATA, "random %from% to %to%", [_a("from", ARG_NUMBER, 1), _a("to", ARG_NUMBER, 10)])
	d["add"] = _b(KIND_REPORTER, CAT_DATA, "%a% + %b%", [_a("a", ARG_NUMBER, 0), _a("b", ARG_NUMBER, 0)])
	d["sub"] = _b(KIND_REPORTER, CAT_DATA, "%a% - %b%", [_a("a", ARG_NUMBER, 0), _a("b", ARG_NUMBER, 0)])
	d["mul"] = _b(KIND_REPORTER, CAT_DATA, "%a% x %b%", [_a("a", ARG_NUMBER, 1), _a("b", ARG_NUMBER, 1)])
	d["div"] = _b(KIND_REPORTER, CAT_DATA, "%a% / %b%", [_a("a", ARG_NUMBER, 1), _a("b", ARG_NUMBER, 1)])
	d["mod"] = _b(KIND_REPORTER, CAT_DATA, "%a% mod %b%", [_a("a", ARG_NUMBER, 1), _a("b", ARG_NUMBER, 2)])
	d["lt"] = _b(KIND_BOOLEAN, CAT_DATA, "%a% < %b%", [_a("a", ARG_NUMBER, 0), _a("b", ARG_NUMBER, 0)])
	d["gt"] = _b(KIND_BOOLEAN, CAT_DATA, "%a% > %b%", [_a("a", ARG_NUMBER, 0), _a("b", ARG_NUMBER, 0)])
	d["eq"] = _b(KIND_BOOLEAN, CAT_DATA, "%a% = %b%", [_a("a", ARG_ANY, 0), _a("b", ARG_ANY, 0)])
	d["and"] = _b(KIND_BOOLEAN, CAT_DATA, "%a% and %b%", [_a("a", ARG_BOOL, true), _a("b", ARG_BOOL, true)])
	d["or"] = _b(KIND_BOOLEAN, CAT_DATA, "%a% or %b%", [_a("a", ARG_BOOL, true), _a("b", ARG_BOOL, false)])
	d["not"] = _b(KIND_BOOLEAN, CAT_DATA, "not %a%", [_a("a", ARG_BOOL, false)])
	d["true"] = _b(KIND_BOOLEAN, CAT_DATA, "true")

	# ---------------------------------------------------------------- looks and sound
	d["message"] = _b(KIND_COMMAND, CAT_LOOKS, "show the message %text%", [_a("text", ARG_TEXT, "Hello!")])
	d["dave_say"] = _b(KIND_COMMAND, CAT_LOOKS, "Crazy Dave says %text%", [_a("text", ARG_TEXT, "Wabby wabbo!")])
	d["dave_leave"] = _b(KIND_COMMAND, CAT_LOOKS, "Crazy Dave leaves")
	d["play_sound"] = _b(KIND_COMMAND, CAT_LOOKS, "play the sound %sound%", [_a("sound", ARG_SOUND, "SOUND_GRAVEBUTTON")])
	d["play_music"] = _b(KIND_COMMAND, CAT_LOOKS, "play the music %music%", [_a("music", ARG_MUSIC, PvZ.MUSIC_TUNE_DAY_GRASSWALK)])
	d["stop_music"] = _b(KIND_COMMAND, CAT_LOOKS, "stop the music")
	d["screen_flash"] = _b(KIND_COMMAND, CAT_LOOKS, "flash the screen")

	# ---------------------------------------------------------------- level control
	d["win_level"] = _b(KIND_COMMAND, CAT_GAME, "win the level")
	d["lose_level"] = _b(KIND_COMMAND, CAT_GAME, "lose the level")
	d["start_next_wave"] = _b(KIND_COMMAND, CAT_GAME, "release the next wave now")
	d["set_wave_countdown"] = _b(KIND_COMMAND, CAT_GAME, "set the next wave countdown to %seconds% seconds", [_a("seconds", ARG_NUMBER, 10)])
	d["spawn_boss"] = _b(KIND_COMMAND, CAT_GAME, "bring in the boss")
	d["set_boss_phase"] = _b(KIND_COMMAND, CAT_GAME, "set the boss to phase %phase%", [_a("phase", ARG_NUMBER, 2)])
	d["boss_health"] = _b(KIND_REPORTER, CAT_GAME, "boss health")
	return d

static func block_def(op: String) -> Dictionary:
	return BLOCKS.get(op, {})

static func is_hat(op: String) -> bool:
	return int(block_def(op).get("kind", KIND_COMMAND)) == KIND_HAT

static func is_reporter(op: String) -> bool:
	var k := int(block_def(op).get("kind", KIND_COMMAND))
	return k == KIND_REPORTER or k == KIND_BOOLEAN

static func palette_for(cat: String) -> Array:
	var out: Array = []
	for op in BLOCKS:
		if str(BLOCKS[op].cat) == cat:
			out.append(op)
	out.sort()
	return out

static func categories() -> Array:
	return [CAT_EVENTS, CAT_FLOW, CAT_ZOMBIES, CAT_PLANTS, CAT_BOARD, CAT_DATA, CAT_LOOKS, CAT_GAME]

static func make_block(op: String) -> Dictionary:
	var def := block_def(op)
	var args: Dictionary = {}
	for a in def.get("args", []):
		args[str(a.name)] = a.default
	var b := {"op": op, "args": args}
	if bool(def.get("has_body", false)):
		b["body"] = []
	if bool(def.get("has_body2", false)):
		b["body2"] = []
	return b

## Human readable label with argument values filled in, for the block canvas.
static func describe(block: Dictionary) -> String:
	var def := block_def(str(block.get("op", "")))
	if def.is_empty():
		return str(block.get("op", "?"))
	var text := str(def.text)
	for a in def.get("args", []):
		var name := str(a.name)
		var v = block.get("args", {}).get(name, a.default)
		text = text.replace("%" + name + "%", value_label(v, int(a.kind)))
	return text

## The palette shows a block before it has any values, so its slots read as empty sockets
## rather than repeating the argument's name.
static func describe_template(op: String) -> String:
	var def := block_def(op)
	if def.is_empty():
		return op
	var text := str(def.text)
	for a in def.get("args", []):
		text = text.replace("%" + str(a.name) + "%", "( )")
	return text

static func value_label(v, kind: int) -> String:
	if typeof(v) == TYPE_DICTIONARY:
		return "(" + describe(v) + ")"
	match kind:
		ARG_ZOMBIE:
			return zombie_label(int(v))
		ARG_PLANT:
			return plant_label(int(v))
		ARG_ROW:
			return "any" if int(v) < 0 else str(int(v) + 1)
		ARG_COL:
			return str(int(v) + 1)
		ARG_LANE_TYPE:
			return LevelDef.ROW_TYPE_NAMES[clampi(int(v), 0, 3)]
		ARG_MUSIC:
			return music_label(int(v))
		ARG_GRIDITEM:
			return griditem_label(int(v))
		ARG_BOOL:
			return "yes" if v else "no"
	return EditorUi.num_text(v)

static func zombie_label(zt: int) -> String:
	if zt < 0 or zt >= PvZ.NUM_ZOMBIE_TYPES:
		return "?"
	return TodStrings.translate("[%s]" % LawnCommon.zombie_def(zt)[LawnCommon.ZDEF_NAME])

static func plant_label(st: int) -> String:
	if CustomDefs.is_custom_plant(st):
		return CustomDefs.plant_name(st)
	if st < 0 or st >= LawnDefs.PLANT_DEFS.size():
		return "?"
	return TodStrings.translate("[%s]" % LawnCommon.plant_def(st)[LawnCommon.PDEF_NAME])

static func music_label(tune: int) -> String:
	const NAMES := {1: "Grasswalk", 2: "Moongrains", 3: "Watery Graves", 4: "Rigor Mormist",
		5: "Graze the Roof", 6: "Choose Your Seeds", 7: "Crazy Dave", 8: "Zen Garden",
		9: "Cerebrawl", 10: "Loonboon", 11: "Conveyor", 12: "Brainiac Maniac", 13: "Zombies on Your Lawn"}
	return str(NAMES.get(tune, "none"))

static func griditem_label(t: int) -> String:
	match t:
		PvZ.GRIDITEM_GRAVESTONE: return "a gravestone"
		PvZ.GRIDITEM_CRATER: return "a crater"
		PvZ.GRIDITEM_LADDER: return "a ladder"
		PvZ.GRIDITEM_PORTAL_CIRCLE: return "a round portal"
		PvZ.GRIDITEM_PORTAL_SQUARE: return "a square portal"
	return "an item"

# ================================================================ virtual machine
class Frame:
	extends RefCounted
	var body: Array
	var index := 0
	var kind := 0          ## 0 = plain body, 1 = repeat, 2 = forever, 3 = repeat_until
	var counter := 0
	var cond = null
	func _init(the_body: Array) -> void:
		body = the_body

class ScriptThread:
	extends RefCounted
	var frames: Array = []
	var wait_ticks := 0
	var wait_cond = null
	var finished := false
	var origin := ""       ## op of the hat that started it, for restart rules
	var context: Dictionary = {}

class Machine:
	extends RefCounted
	## Runs a level's stacks. Owned by CustomRuntime; ticks once per board update.
	var runtime                       ## CustomRuntime, supplies the board actions
	var stacks: Array = []            ## [{"op": hat op, "args": {}, "body": [...]}]
	var vars: Dictionary = {}
	var threads: Array = []
	var every_timers: Dictionary = {} ## stack index -> ticks remaining
	var tick_count := 0
	var stopped := false

	func _init(the_runtime, script_data: Dictionary) -> void:
		runtime = the_runtime
		for s in script_data.get("stacks", []):
			if typeof(s) != TYPE_DICTIONARY:
				continue
			var op := str(s.get("op", ""))
			if op == "" or not LevelScript.is_hat(op):
				continue
			stacks.append(s)
		for k in script_data.get("vars", {}):
			vars[str(k)] = script_data.vars[k]

	func has_scripts() -> bool:
		return not stacks.is_empty()

	## Fires every stack whose hat matches, optionally filtered by a predicate on the hat's args.
	func fire(hat_op: String, context: Dictionary = {}) -> void:
		if stopped:
			return
		for i in stacks.size():
			var s: Dictionary = stacks[i]
			if str(s.op) != hat_op:
				continue
			if not _hat_matches(s, context):
				continue
			var t := ScriptThread.new()
			t.origin = hat_op
			t.context = context
			t.frames.append(Frame.new(s.get("body", [])))
			threads.append(t)

	func _hat_matches(stack: Dictionary, context: Dictionary) -> bool:
		match str(stack.op):
			"when_wave":
				return int(_literal(stack.args.get("wave", 1))) == int(context.get("wave", -1)) + 1
			"when_boss_phase":
				return int(_literal(stack.args.get("phase", 1))) == int(context.get("phase", -1))
			"when_event":
				return str(stack.args.get("event", "")) == str(context.get("event", ""))
		return true

	static func _literal(v):
		return v if typeof(v) != TYPE_DICTIONARY else 0

	func broadcast(event: String) -> void:
		if event != "":
			fire("when_event", {"event": event})

	func stop_all() -> void:
		threads.clear()
		stopped = true

	# ---------------------------------------------------------------- tick
	func update() -> void:
		if stopped:
			return
		tick_count += 1
		_update_every_timers()
		var alive: Array = []
		for t in threads:
			_run_thread(t)
			if not t.finished:
				alive.append(t)
		threads = alive

	func _update_every_timers() -> void:
		for i in stacks.size():
			var s: Dictionary = stacks[i]
			if str(s.op) != "when_every":
				continue
			var period: int = maxi(1, int(round(float(_number(s.args.get("seconds", 10), {})) * TICKS_PER_SECOND)))
			var left: int = int(every_timers.get(i, period))
			left -= 1
			if left <= 0:
				left = period
				var t := ScriptThread.new()
				t.origin = "when_every"
				t.frames.append(Frame.new(s.get("body", [])))
				threads.append(t)
			every_timers[i] = left

	func _run_thread(t: ScriptThread) -> void:
		if t.wait_ticks > 0:
			t.wait_ticks -= 1
			return
		if t.wait_cond != null:
			if not _boolean(t.wait_cond, t.context):
				return
			t.wait_cond = null
		var steps := 0
		while steps < LevelScript.MAX_STEPS_PER_TICK:
			steps += 1
			if t.frames.is_empty():
				t.finished = true
				return
			var f: Frame = t.frames[-1]
			if f.index >= f.body.size():
				if not _loop_back(t, f):
					t.frames.pop_back()
				continue
			var block = f.body[f.index]
			f.index += 1
			if typeof(block) != TYPE_DICTIONARY:
				continue
			if _execute(t, block):
				return     # the block yielded (wait / wait_until)

	## Returns true when the loop frame restarts instead of being popped.
	func _loop_back(t: ScriptThread, f: Frame) -> bool:
		match f.kind:
			1:
				f.counter -= 1
				if f.counter > 0:
					f.index = 0
					return true
			2:
				f.index = 0
				# forever always yields a tick so it cannot lock the game up
				t.wait_ticks = 0
				return true
			3:
				if not _boolean(f.cond, t.context):
					f.index = 0
					return true
		return false

	# ---------------------------------------------------------------- execution
	## Returns true if the thread should stop running this tick.
	func _execute(t: ScriptThread, block: Dictionary) -> bool:
		var op := str(block.get("op", ""))
		var args: Dictionary = block.get("args", {})
		match op:
			"wait":
				t.wait_ticks = maxi(0, int(round(_number(args.get("seconds", 1), t.context) * TICKS_PER_SECOND)))
				return t.wait_ticks > 0
			"wait_until":
				var c = args.get("cond", true)
				if _boolean(c, t.context):
					return false
				t.wait_cond = c
				return true
			"repeat":
				var times := int(_number(args.get("times", 0), t.context))
				if times > 0:
					var f := Frame.new(block.get("body", []))
					f.kind = 1
					f.counter = times
					t.frames.append(f)
				return false
			"forever":
				var ff := Frame.new(block.get("body", []))
				ff.kind = 2
				t.frames.append(ff)
				return false
			"repeat_until":
				var fu := Frame.new(block.get("body", []))
				fu.kind = 3
				fu.cond = args.get("cond", true)
				if not _boolean(fu.cond, t.context):
					t.frames.append(fu)
				return false
			"if":
				if _boolean(args.get("cond", true), t.context):
					t.frames.append(Frame.new(block.get("body", [])))
				return false
			"if_else":
				if _boolean(args.get("cond", true), t.context):
					t.frames.append(Frame.new(block.get("body", [])))
				else:
					t.frames.append(Frame.new(block.get("body2", [])))
				return false
			"stop_this":
				t.frames.clear()
				t.finished = true
				return true
			"set_var":
				vars[str(args.get("name", ""))] = _value(args.get("value", 0), t.context)
				return false
			"change_var":
				var key := str(args.get("name", ""))
				vars[key] = float(vars.get(key, 0)) + _number(args.get("value", 1), t.context)
				return false
			"broadcast":
				broadcast(str(args.get("event", "")))
				return false
		# everything else is an action on the board
		runtime.run_action(op, _resolve_args(block, t.context), t.context)
		return false

	func _resolve_args(block: Dictionary, context: Dictionary) -> Dictionary:
		var out: Dictionary = {}
		var def := LevelScript.block_def(str(block.get("op", "")))
		var args: Dictionary = block.get("args", {})
		for a in def.get("args", []):
			var name := str(a.name)
			var raw = args.get(name, a.default)
			if int(a.kind) == ARG_TEXT or int(a.kind) == ARG_VAR or int(a.kind) == ARG_EVENT or int(a.kind) == ARG_SOUND:
				out[name] = str(_value(raw, context))
			elif int(a.kind) == ARG_BOOL:
				out[name] = _boolean(raw, context)
			else:
				out[name] = _value(raw, context)
		return out

	# ---------------------------------------------------------------- evaluation
	func _value(v, context: Dictionary):
		if typeof(v) != TYPE_DICTIONARY:
			return v
		return _evaluate(v, context)

	func _number(v, context: Dictionary) -> float:
		var out = _value(v, context)
		match typeof(out):
			TYPE_INT, TYPE_FLOAT: return float(out)
			TYPE_BOOL: return 1.0 if out else 0.0
			TYPE_STRING: return String(out).to_float()
		return 0.0

	func _boolean(v, context: Dictionary) -> bool:
		var out = _value(v, context)
		match typeof(out):
			TYPE_BOOL: return out
			TYPE_INT, TYPE_FLOAT: return float(out) != 0.0
			TYPE_STRING: return String(out) != "" and String(out) != "0"
		return false

	func _evaluate(block: Dictionary, context: Dictionary):
		var op := str(block.get("op", ""))
		var args: Dictionary = block.get("args", {})
		match op:
			"number", "text":
				return args.get("value", 0)
			"true":
				return true
			"get_var":
				return vars.get(str(args.get("name", "")), 0)
			"random":
				var lo := int(_number(args.get("from", 1), context))
				var hi := int(_number(args.get("to", 10), context))
				return Tod.rand_range_int(mini(lo, hi), maxi(lo, hi))
			"add":
				return _number(args.get("a", 0), context) + _number(args.get("b", 0), context)
			"sub":
				return _number(args.get("a", 0), context) - _number(args.get("b", 0), context)
			"mul":
				return _number(args.get("a", 1), context) * _number(args.get("b", 1), context)
			"div":
				var den := _number(args.get("b", 1), context)
				return 0.0 if is_zero_approx(den) else _number(args.get("a", 1), context) / den
			"mod":
				var m := _number(args.get("b", 2), context)
				return 0.0 if is_zero_approx(m) else fposmod(_number(args.get("a", 1), context), m)
			"lt":
				return _number(args.get("a", 0), context) < _number(args.get("b", 0), context)
			"gt":
				return _number(args.get("a", 0), context) > _number(args.get("b", 0), context)
			"eq":
				var a = _value(args.get("a", 0), context)
				var b = _value(args.get("b", 0), context)
				if typeof(a) == TYPE_STRING or typeof(b) == TYPE_STRING:
					return str(a) == str(b)
				return is_equal_approx(float(a), float(b))
			"and":
				return _boolean(args.get("a", true), context) and _boolean(args.get("b", true), context)
			"or":
				return _boolean(args.get("a", true), context) or _boolean(args.get("b", false), context)
			"not":
				return not _boolean(args.get("a", false), context)
		# board queries live on the runtime
		return runtime.query(op, _resolve_args(block, context), context)
