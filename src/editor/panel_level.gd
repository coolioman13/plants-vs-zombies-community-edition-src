class_name PanelLevel
extends EditorPanel
## Identity and the level-wide rules: who made it, how sun works, how it is won or lost, how tough
## the zombies and plants are, and what music plays.

const F_NAME := 1
const F_AUTHOR := 2
const F_DESC := 3
const S_START_SUN := 10
const S_SUN_FIRST := 11
const S_SUN_MIN := 12
const S_SUN_MAX := 13
const S_WIN_MODE := 14
const S_WIN_TIME := 15
const S_WIN_KILLS := 16
const S_MUSIC := 17
const S_ZHEALTH := 18
const S_ZSPEED := 19
const S_PHEALTH := 20
const S_PDAMAGE := 21
const S_FLAG_EVERY := 22
const S_LEVEL_NUM := 23
const S_AWARD := 24
const T_SUN_DROP := 30
const T_SHOVEL := 31
const T_CAN_LOSE := 32
const T_PROGRESS := 33
const T_FINAL_BANNER := 34
const T_FLAG_FINAL := 35

const MUSIC_VALUES := [-1, PvZ.MUSIC_TUNE_DAY_GRASSWALK, PvZ.MUSIC_TUNE_NIGHT_MOONGRAINS,
	PvZ.MUSIC_TUNE_POOL_WATERYGRAVES, PvZ.MUSIC_TUNE_FOG_RIGORMORMIST, PvZ.MUSIC_TUNE_ROOF_GRAZETHEROOF,
	PvZ.MUSIC_TUNE_PUZZLE_CEREBRAWL, PvZ.MUSIC_TUNE_MINIGAME_LOONBOON, PvZ.MUSIC_TUNE_CONVEYER,
	PvZ.MUSIC_TUNE_FINAL_BOSS_BRAINIAC_MANIAC, PvZ.MUSIC_TUNE_ZEN_GARDEN,
	PvZ.MUSIC_TUNE_TITLE_CRAZY_DAVE_MAIN_THEME, PvZ.MUSIC_TUNE_CREDITS_ZOMBIES_ON_YOUR_LAWN]
const MUSIC_NAMES := ["Silence", "Grasswalk", "Moongrains", "Watery Graves", "Rigor Mormist",
	"Graze the Roof", "Cerebrawl", "Loonboon", "Conveyor", "Brainiac Maniac", "Zen Garden",
	"Crazy Dave's Theme", "Zombies on Your Lawn"]

var desc_area: EditorUi.TextArea

func build() -> void:
	var l := level()
	var col_w := Tod.idiv(width - PAD * 3, 2)
	var lx := PAD
	var rx := PAD * 2 + col_w
	var y := 44

	add_field(F_NAME, "Level name", l.level_name, lx, y, col_w, 118)
	y += ROW_H
	add_field(F_AUTHOR, "Author", l.author, lx, y, col_w, 118)
	y += ROW_H + 6
	desc_area = add_text_area(F_DESC, lx, y, col_w, 82)
	desc_area.set_lines(l.description.split("\n") if l.description != "" else [""])
	y += 82 + 16

	section_y_rules = y
	add_stepper(S_START_SUN, "Starting sun", l.start_sun, 0, 9990, 25, lx, y + 26, col_w, 150)
	add_toggle(T_SUN_DROP, "Sun falls from the sky", l.sun_drop, lx, y + 26 + ROW_H, col_w)
	add_stepper(S_SUN_FIRST, "First sun after", l.sun_drop_first, 60, 6000, 25, lx, y + 26 + ROW_H * 2, col_w, 150).suffix = " ticks"
	add_stepper(S_SUN_MIN, "Then every (min)", l.sun_drop_min, 60, 6000, 25, lx, y + 26 + ROW_H * 3, col_w, 150).suffix = " ticks"
	add_stepper(S_SUN_MAX, "Then every (max)", l.sun_drop_max, 60, 6000, 25, lx, y + 26 + ROW_H * 4, col_w, 150).suffix = " ticks"
	add_toggle(T_SHOVEL, "Give the player a shovel", l.shovel, lx, y + 26 + ROW_H * 5 + 2, col_w)

	# ---------------------------------------------------------------- right column
	var ry := 44
	section_y_win = ry
	add_choice(S_WIN_MODE, "Win when", l.win_mode, LevelDef.WIN_NAMES, rx, ry + 26, col_w, 150)
	add_stepper(S_WIN_TIME, "Time limit", float(l.win_time) / 100.0, 0, 3600, 5, rx, ry + 26 + ROW_H, col_w, 150).suffix = "s"
	add_stepper(S_WIN_KILLS, "Zombies to kill", l.win_kills, 0, 9999, 5, rx, ry + 26 + ROW_H * 2, col_w, 150)
	add_toggle(T_CAN_LOSE, "The player can lose", l.can_lose, rx, ry + 26 + ROW_H * 3, col_w)
	add_stepper(S_FLAG_EVERY, "Flag every", l.waves_per_flag, 0, 50, 1, rx, ry + 26 + ROW_H * 4, col_w, 150).suffix = " waves"
	add_toggle(T_FLAG_FINAL, "Last wave is a flag wave", l.flag_final_wave, rx, ry + 26 + ROW_H * 5, col_w)
	add_toggle(T_PROGRESS, "Show the progress meter", l.progress_meter, rx, ry + 26 + ROW_H * 6, col_w)
	add_toggle(T_FINAL_BANNER, "Show the FINAL WAVE banner", l.final_wave_banner, rx, ry + 26 + ROW_H * 7, col_w)

	var by := ry + 26 + ROW_H * 8 + 18
	section_y_balance = by
	add_choice(S_MUSIC, "Music", maxi(0, MUSIC_VALUES.find(l.music_tune)), MUSIC_NAMES, rx, by + 26, col_w, 150)
	var sh := add_stepper(S_ZHEALTH, "Zombie health", l.zombie_health_scale, 0.1, 10.0, 0.1, rx, by + 26 + ROW_H, col_w, 150)
	sh.decimals = 1
	sh.suffix = " x"
	var ss := add_stepper(S_ZSPEED, "Zombie speed", l.zombie_speed_scale, 0.1, 5.0, 0.1, rx, by + 26 + ROW_H * 2, col_w, 150)
	ss.decimals = 1
	ss.suffix = " x"
	var ph := add_stepper(S_PHEALTH, "Plant health", l.plant_health_scale, 0.1, 10.0, 0.1, rx, by + 26 + ROW_H * 3, col_w, 150)
	ph.decimals = 1
	ph.suffix = " x"
	add_stepper(S_LEVEL_NUM, "Reported level", l.level_number, 1, 50, 1, rx, by + 26 + ROW_H * 4, col_w, 150)

var section_y_rules := 0
var section_y_win := 0
var section_y_balance := 0

func draw_content(g: Graphics) -> void:
	var col_w := Tod.idiv(width - PAD * 3, 2)
	var lx := PAD
	var rx := PAD * 2 + col_w
	section(g, "This level", lx, 16, col_w)
	section(g, "Rules", lx, section_y_rules, col_w)
	section(g, "Winning and losing", rx, 16, col_w)
	section(g, "Balance and music", rx, section_y_balance, col_w)
	var l := level()
	var note := ""
	match l.win_mode:
		LevelDef.WIN_WAVES: note = "The level is won once every wave has been cleared."
		LevelDef.WIN_TIME: note = "The level is won after the time limit, however many zombies are left."
		LevelDef.WIN_KILLS: note = "The level is won as soon as enough zombies have been destroyed."
		LevelDef.WIN_SCRIPT: note = "Nothing wins the level by itself - use a \"win the level\" block on the Scripting tab."
	hint(g, note, rx, section_y_balance - 24, col_w)
	if l.music_custom != "":
		hint(g, "A custom music file is set on the Art tab and overrides this choice.", rx, height - 40, col_w)

# ================================================================ callbacks
func edit_widget_text(id: int, text: String) -> void:
	_commit_text(id, text)

func _commit_text(id: int, text: String) -> void:
	match id:
		F_NAME:
			level().level_name = text.strip_edges()
		F_AUTHOR:
			level().author = text.strip_edges()
	mark_dirty()

func editor_textarea_changed(id: int, lines: Array) -> void:
	if id == F_DESC:
		level().description = "\n".join(lines)
		mark_dirty()

func editor_toggle(id: int, value: bool) -> void:
	var l := level()
	match id:
		T_SUN_DROP: l.sun_drop = value
		T_SHOVEL: l.shovel = value
		T_CAN_LOSE: l.can_lose = value
		T_PROGRESS: l.progress_meter = value
		T_FINAL_BANNER: l.final_wave_banner = value
		T_FLAG_FINAL: l.flag_final_wave = value
	mark_dirty()

func editor_stepper(id: int, value: float) -> void:
	var l := level()
	match id:
		S_START_SUN: l.start_sun = int(value)
		S_SUN_FIRST: l.sun_drop_first = int(value)
		S_SUN_MIN: l.sun_drop_min = int(value)
		S_SUN_MAX: l.sun_drop_max = int(value)
		S_WIN_MODE: l.win_mode = int(value)
		S_WIN_TIME: l.win_time = int(value * 100.0)
		S_WIN_KILLS: l.win_kills = int(value)
		S_MUSIC: l.music_tune = int(MUSIC_VALUES[clampi(int(value), 0, MUSIC_VALUES.size() - 1)])
		S_ZHEALTH: l.zombie_health_scale = value
		S_ZSPEED: l.zombie_speed_scale = value
		S_PHEALTH: l.plant_health_scale = value
		S_PDAMAGE: l.plant_damage_scale = value
		S_FLAG_EVERY: l.waves_per_flag = int(value)
		S_LEVEL_NUM: l.level_number = int(value)
	mark_dirty()

## Text fields commit on every keystroke so nothing is lost when a tab is switched.
func update() -> void:
	super.update()
	for c in _controls:
		if c is EditorUi.TextField:
			var f: EditorUi.TextField = c
			match f.id:
				F_NAME:
					if f.text.strip_edges() != level().level_name and f.has_focus:
						level().level_name = f.text.strip_edges()
						mark_dirty()
				F_AUTHOR:
					if f.text.strip_edges() != level().author and f.has_focus:
						level().author = f.text.strip_edges()
						mark_dirty()
