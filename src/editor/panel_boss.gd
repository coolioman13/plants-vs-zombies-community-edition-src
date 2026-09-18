class_name PanelBoss
extends EditorPanel
## Boss maker: turns the final wave (or any wave) into a Dr. Zomboss style fight. Health, how many
## phases it breaks into, which attacks it is allowed, what it summons, and what its death
## broadcasts so a script can finish the level however the author wants.

const T_ENABLED := 1
const T_STOMP := 2
const T_FIRE := 3
const T_ICE := 4
const T_SUMMON := 5
const T_BUNGEE := 6
const F_NAME := 10
const F_DEATH_EVENT := 11
const S_HEALTH := 20
const S_PHASES := 21
const S_ENTER := 22
const S_INTERVAL := 23
const S_SPEED := 24
const S_MUSIC := 25
const S_REANIM := 26
const G_SUMMONS := 30

const LEFT_W := 430

var summon_grid: EditorUi.IconGrid
var summon_types: Array = []
var reanim_keys: Array = []
var preview: Reanimation = null

func cfg() -> Dictionary:
	return level().boss

func build() -> void:
	var b := cfg()
	add_toggle(T_ENABLED, "This level has a boss", bool(b.get("enabled", false)), PAD, 38, LEFT_W)
	if not bool(b.get("enabled", false)):
		return
	var y := 88
	add_field(F_NAME, "Boss name", str(b.get("name", "Dr. Zomboss")), PAD, y, LEFT_W, 140)
	y += ROW_H
	add_stepper(S_HEALTH, "Health", int(b.get("health", 40000)), 500, 500000, 2500, PAD, y, LEFT_W, 140)
	y += ROW_H
	add_stepper(S_PHASES, "Phases", int(b.get("phases", 3)), 1, 8, 1, PAD, y, LEFT_W, 140)
	y += ROW_H
	var waves: Array = ["Final wave"]
	for i in level().waves.size():
		waves.append("Wave %d" % (i + 1))
	var enter := int(b.get("enter_wave", -1))
	add_choice(S_ENTER, "Arrives on", 0 if enter < 0 else enter + 1, waves, PAD, y, LEFT_W, 140)
	y += ROW_H
	var iv := add_stepper(S_INTERVAL, "Attacks every", float(b.get("attack_interval", 700)) / 100.0,
		1.0, 60.0, 0.5, PAD, y, LEFT_W, 140)
	iv.decimals = 1
	iv.suffix = "s"
	y += ROW_H
	var sp := add_stepper(S_SPEED, "Animation speed", float(b.get("speed", 1.0)), 0.25, 3.0, 0.05, PAD, y, LEFT_W, 140)
	sp.decimals = 2
	sp.suffix = " x"
	y += ROW_H
	add_choice(S_MUSIC, "Boss music", maxi(0, PanelLevel.MUSIC_VALUES.find(int(b.get("music", PvZ.MUSIC_TUNE_FINAL_BOSS_BRAINIAC_MANIAC)))),
		PanelLevel.MUSIC_NAMES, PAD, y, LEFT_W, 140)
	y += ROW_H
	reanim_keys = _reanim_asset_keys()
	var names: Array = ["(the built-in Dr. Zomboss)"]
	for k in reanim_keys:
		names.append(str(k).get_file())
	add_choice(S_REANIM, "Animation", reanim_keys.find(str(b.get("reanim", ""))) + 1, names, PAD, y, LEFT_W, 140)
	y += ROW_H + 8

	attacks_y = y
	y += 24
	add_toggle(T_STOMP, "Stomps lanes flat", bool(b.get("stomp", true)), PAD, y, LEFT_W)
	y += 26
	add_toggle(T_FIRE, "Throws fireballs", bool(b.get("fireball", true)), PAD, y, LEFT_W)
	y += 26
	add_toggle(T_ICE, "Throws iceballs", bool(b.get("iceball", true)), PAD, y, LEFT_W)
	y += 26
	add_toggle(T_SUMMON, "Summons zombies", bool(b.get("summon", true)), PAD, y, LEFT_W)
	y += 26
	add_toggle(T_BUNGEE, "Drops bungee zombies", bool(b.get("bungee", true)), PAD, y, LEFT_W)
	y += 32
	add_field(F_DEATH_EVENT, "Death broadcasts", str(b.get("death_event", "")), PAD, y, LEFT_W, 140)

	summon_types = all_zombie_types()
	var rx := PAD * 2 + LEFT_W
	var rw := width - rx - PAD
	summon_grid = add_grid(G_SUMMONS, rx, 300, rw, height - 340, Vector2i(74, 90))
	summon_grid.count = summon_types.size()
	summon_grid.draw_cell = Callable(self, "_draw_summon_cell")

var attacks_y := 0

func teardown() -> void:
	if preview != null and not preview.freed:
		preview.die()
	preview = null
	super.teardown()

func _reanim_asset_keys() -> Array:
	var out: Array = []
	for k in level().assets:
		if str(level().assets[k].get("type", "")) == "reanim":
			out.append(str(k))
	out.sort()
	return out

func _summons() -> Array:
	return cfg().get("summon_zombies", [])

func _draw_summon_cell(g: Graphics, index: int, r: Rect2, hovered: bool, _sel: bool) -> void:
	var zt: int = summon_types[index]
	var on: bool = _summons().has(zt)
	EditorUi.draw_slot(g, r, hovered, on)
	EditorUi.draw_zombie_portrait(g, zt, r.position.x + r.size.x * 0.5, r.position.y + r.size.y - 14, 0.3)
	var f := EditorUi.font_small()
	EditorUi.draw_text(g, EditorUi.elide(zombie_name(zt), f, int(r.size.x - 4)),
		int(r.position.x + r.size.x * 0.5), int(r.end.y - 3), f,
		EditorUi.TEXT_GREEN if on else EditorUi.TEXT_DIM, TodStrings.DS_ALIGN_CENTER)

func draw_content(g: Graphics) -> void:
	var b := cfg()
	section(g, "Boss", PAD, 14, LEFT_W)
	if not bool(b.get("enabled", false)):
		hint(g, "Turn this on for a Dr. Zomboss style fight. The boss arrives on the wave you pick " + "(the final one by default), takes the health you set, and breaks into phases as it is " + "worn down - each phase fires a script event, so you can change the fight as it goes.\n\n" + "Give it your own animation on the Art tab to make it something else entirely.",
			PAD, 74, width - PAD * 2)
		return
	section(g, "Attacks", PAD, attacks_y, LEFT_W)
	var rx := PAD * 2 + LEFT_W
	var rw := width - rx - PAD
	section(g, "Fight", rx, 14, rw)
	var phases := int(b.get("phases", 3))
	var hp := int(b.get("health", 40000))
	var lines := "The boss enters with %s health.\n" % EditorUi.thousands(hp)
	lines += "It drops a phase every %d damage, firing \"when the boss enters phase N\" each time.\n" % Tod.idiv(hp, maxi(1, phases))
	lines += "Blocks on the Scripting tab can read its health and force a phase at any moment."
	hint(g, lines, rx, 44, rw)
	section(g, "Zombies it summons", rx, 272, rw)
	_draw_preview(g, rx, rw)

func _draw_preview(g: Graphics, rx: int, rw: int) -> void:
	if preview == null or preview.freed:
		var rt := PvZ.REANIM_BOSS
		var key := str(cfg().get("reanim", ""))
		if key != "":
			var def := CustomAssets.get_reanim_def(key)
			if def != null:
				rt = ReanimTypes.register_def("bosspreview:" + key, def)
		preview = App.add_reanimation(0.0, 0.0, 0, rt)
		preview.is_attachment = true
		EditorUi.tame_preview(preview)
		if preview.track_exists("anim_idle"):
			preview.play_reanim("anim_idle", Reanimation.REANIM_LOOP, 0, 12.0)
		elif preview.track_exists("anim_head_idle"):
			preview.play_reanim("anim_head_idle", Reanimation.REANIM_LOOP, 0, 12.0)
	var box := Rect2(rx, 126, rw, 140)
	EditorUi.draw_shade(g, box, 0.3)
	var cg := g.copy()
	cg.clip_rect(box.position.x, box.position.y, box.size.x, box.size.y)
	EditorUi.fit_preview(preview, box, 0.5)
	preview.anim_rate = 12.0 * float(cfg().get("speed", 1.0))
	preview.draw(cg)

func update() -> void:
	super.update()
	if preview != null and not preview.freed:
		preview.update()
	var b := cfg()
	for c in _controls:
		if c is EditorUi.TextField and c.has_focus:
			var f: EditorUi.TextField = c
			if f.id == F_NAME and str(b.get("name", "")) != f.text:
				b["name"] = f.text
				mark_dirty()
			elif f.id == F_DEATH_EVENT and str(b.get("death_event", "")) != f.text:
				b["death_event"] = f.text
				mark_dirty()

# ================================================================ callbacks
func editor_toggle(id: int, value: bool) -> void:
	var b := cfg()
	match id:
		T_ENABLED:
			b["enabled"] = value
			mark_dirty()
			rebuild()
			return
		T_STOMP: b["stomp"] = value
		T_FIRE: b["fireball"] = value
		T_ICE: b["iceball"] = value
		T_SUMMON: b["summon"] = value
		T_BUNGEE: b["bungee"] = value
	mark_dirty()

func editor_stepper(id: int, value: float) -> void:
	var b := cfg()
	match id:
		S_HEALTH: b["health"] = int(value)
		S_PHASES: b["phases"] = int(value)
		S_ENTER: b["enter_wave"] = int(value) - 1
		S_INTERVAL: b["attack_interval"] = int(value * 100.0)
		S_SPEED: b["speed"] = value
		S_MUSIC:
			b["music"] = int(PanelLevel.MUSIC_VALUES[clampi(int(value), 0, PanelLevel.MUSIC_VALUES.size() - 1)])
		S_REANIM:
			var index := int(value) - 1
			b["reanim"] = str(reanim_keys[index]) if index >= 0 and index < reanim_keys.size() else ""
			if preview != null and not preview.freed:
				preview.die()
			preview = null
	mark_dirty()

func editor_grid_click(id: int, index: int, _btn: int) -> void:
	if id != G_SUMMONS or index < 0 or index >= summon_types.size():
		return
	var zt: int = summon_types[index]
	var list: Array = _summons()
	if list.has(zt):
		list.erase(zt)
	else:
		list.append(zt)
	cfg()["summon_zombies"] = list
	mark_dirty()
