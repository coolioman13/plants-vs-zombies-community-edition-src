class_name Music
extends Node
## Port of Music.cpp on top of pre-rendered stems (tools/render_music.py).
## Stems of a tune share length and loop points, so they stay sample-aligned while playing together.

enum { MUSIC_FILE_NONE = -1, MUSIC_FILE_MAIN_MUSIC = 1, MUSIC_FILE_DRUMS = 2, MUSIC_FILE_HIHATS = 3, MUSIC_FILE_CREDITS_ZOMBIES_ON_YOUR_LAWN = 4 }
enum { MUSIC_BURST_OFF, MUSIC_BURST_STARTING, MUSIC_BURST_ON, MUSIC_BURST_FINISHING }
enum { MUSIC_DRUMS_OFF, MUSIC_DRUMS_ON_QUEUED, MUSIC_DRUMS_ON, MUSIC_DRUMS_OFF_QUEUED, MUSIC_DRUMS_FADING }

const TUNE_FILES := {
	PvZ.MUSIC_TUNE_DAY_GRASSWALK: "grasswalk",
	PvZ.MUSIC_TUNE_NIGHT_MOONGRAINS: "moongrains",
	PvZ.MUSIC_TUNE_POOL_WATERYGRAVES: "wateryg",
	PvZ.MUSIC_TUNE_FOG_RIGORMORMIST: "rigormormist",
	PvZ.MUSIC_TUNE_ROOF_GRAZETHEROOF: "grazetheroof",
	PvZ.MUSIC_TUNE_CHOOSE_YOUR_SEEDS: "chooseseeds",
	PvZ.MUSIC_TUNE_TITLE_CRAZY_DAVE_MAIN_THEME: "crazydave",
	PvZ.MUSIC_TUNE_ZEN_GARDEN: "zengarden",
	PvZ.MUSIC_TUNE_PUZZLE_CEREBRAWL: "cerebrawl",
	PvZ.MUSIC_TUNE_MINIGAME_LOONBOON: "loonboon",
	PvZ.MUSIC_TUNE_CONVEYER: "ultimatebattle",
	PvZ.MUSIC_TUNE_FINAL_BOSS_BRAINIAC_MANIAC: "brainiacmaniac",
}

var meta: Dictionary = {}
var players: Dictionary = {}       # music file -> AudioStreamPlayer
var player_meta: Dictionary = {}   # music file -> timeline meta
var file_volume: Dictionary = {}   # music file -> 0..1 song volume
var cur_music_tune := PvZ.MUSIC_TUNE_NONE
var cur_file_main := MUSIC_FILE_NONE
var cur_file_drums := MUSIC_FILE_NONE
var cur_file_hihats := MUSIC_FILE_NONE
var burst_override := -1
var music_drums_state := MUSIC_DRUMS_OFF
var queued_drum_track_packed_order := -1
var music_burst_state := MUSIC_BURST_OFF
var burst_state_counter := 0
var drums_state_counter := 0
var paused := false
var pause_positions: Dictionary = {}
var music_disabled := false
var fade_out_counter := 0
var fade_out_duration := 0
var music_volume := 0.85

var _stream_cache: Dictionary = {}

func _ready() -> void:
	var p := "res://music/music.json"
	if FileAccess.file_exists(p):
		meta = JSON.parse_string(FileAccess.get_file_as_string(p))
	else:
		music_disabled = true
		push_warning("Music stems missing; run tools/render_music.py")
	for f in [MUSIC_FILE_MAIN_MUSIC, MUSIC_FILE_DRUMS, MUSIC_FILE_HIHATS, MUSIC_FILE_CREDITS_ZOMBIES_ON_YOUR_LAWN]:
		var pl := AudioStreamPlayer.new()
		add_child(pl)
		players[f] = pl
		file_volume[f] = 1.0

func _stream(stem: String, loop_start_samples: int, rate: int, loops: bool) -> AudioStream:
	var key := stem
	if _stream_cache.has(key):
		return _stream_cache[key]
	var path := "res://music/%s.ogg" % stem
	if not ResourceLoader.exists(path):
		return null
	var s: AudioStream = load(path).duplicate()
	if s is AudioStreamOggVorbis:
		s.loop = loops
		s.loop_offset = float(loop_start_samples) / rate
	_stream_cache[key] = s
	return s

func _apply_volume(file: int) -> void:
	var pl: AudioStreamPlayer = players[file]
	var v: float = file_volume[file] * music_volume
	pl.volume_db = linear_to_db(maxf(v, 0.00001))

func set_song_volume(file: int, v: float) -> void:
	if file == MUSIC_FILE_NONE:
		return
	file_volume[file] = v
	_apply_volume(file)

func set_music_volume(v: float) -> void:
	music_volume = v
	for f in players.keys():
		_apply_volume(f)

func _start_stem(file: int, stem: String, meta_name: String, position: float, volume: float) -> void:
	var m: Dictionary = meta.get(meta_name, {})
	if m.is_empty() and file != MUSIC_FILE_CREDITS_ZOMBIES_ON_YOUR_LAWN:
		return
	var st: AudioStream
	if file == MUSIC_FILE_CREDITS_ZOMBIES_ON_YOUR_LAWN:
		st = load("res://music/zombiesonyourlawn.ogg")
		if st and "loop" in st:
			st.loop = false  # the credits song plays once (BassMusicInterface noLoop)
	else:
		st = _stream(stem, int(m.loop_start), int(m.rate), true)
	var pl: AudioStreamPlayer = players[file]
	pl.stop()
	pl.stream = st
	player_meta[file] = m
	file_volume[file] = volume
	_apply_volume(file)
	if st != null:
		pl.play(position)

## Music::PlayFromOffset for the credits stream. BASS stream offsets are PCM byte positions,
## which for this song run at 88200 bytes per second.
const CREDITS_BYTES_PER_SECOND := 88200.0

func play_from_offset(file: int, offset: int, volume: float) -> void:
	if music_disabled or file != MUSIC_FILE_CREDITS_ZOMBIES_ON_YOUR_LAWN:
		return
	cur_music_tune = PvZ.MUSIC_TUNE_CREDITS_ZOMBIES_ON_YOUR_LAWN
	cur_file_main = file
	_start_stem(file, "", "", maxf(0.0, offset / CREDITS_BYTES_PER_SECOND), volume)

func stop_all_music() -> void:
	for f in players.keys():
		players[f].stop()
	cur_music_tune = PvZ.MUSIC_TUNE_NONE
	cur_file_main = MUSIC_FILE_NONE
	cur_file_drums = MUSIC_FILE_NONE
	cur_file_hihats = MUSIC_FILE_NONE
	queued_drum_track_packed_order = -1
	music_drums_state = MUSIC_DRUMS_OFF
	music_burst_state = MUSIC_BURST_OFF
	paused = false
	pause_positions.clear()
	fade_out_counter = 0

func play_music(tune: int, positions: Dictionary = {}) -> void:
	if music_disabled:
		return
	cur_music_tune = tune
	cur_file_main = MUSIC_FILE_NONE
	cur_file_drums = MUSIC_FILE_NONE
	cur_file_hihats = MUSIC_FILE_NONE
	var pos_main: float = positions.get(MUSIC_FILE_MAIN_MUSIC, 0.0)
	var pos_drums: float = positions.get(MUSIC_FILE_DRUMS, pos_main)
	var pos_hihats: float = positions.get(MUSIC_FILE_HIHATS, pos_main)
	if tune == PvZ.MUSIC_TUNE_CREDITS_ZOMBIES_ON_YOUR_LAWN:
		cur_file_main = MUSIC_FILE_CREDITS_ZOMBIES_ON_YOUR_LAWN
		_start_stem(cur_file_main, "", "", pos_main, 1.0)
		return
	var name: String = TUNE_FILES.get(tune, "")
	if name == "":
		return
	match tune:
		PvZ.MUSIC_TUNE_DAY_GRASSWALK, PvZ.MUSIC_TUNE_POOL_WATERYGRAVES, PvZ.MUSIC_TUNE_FOG_RIGORMORMIST, PvZ.MUSIC_TUNE_ROOF_GRAZETHEROOF:
			cur_file_main = MUSIC_FILE_MAIN_MUSIC
			cur_file_drums = MUSIC_FILE_DRUMS
			cur_file_hihats = MUSIC_FILE_HIHATS
			_start_stem(cur_file_main, name + "_main", name, pos_main, 1.0)
			_start_stem(cur_file_drums, name + "_drums", name, pos_drums, 0.0)
			_start_stem(cur_file_hihats, name + "_hihats", name, pos_hihats, 0.0)
		PvZ.MUSIC_TUNE_NIGHT_MOONGRAINS:
			cur_file_main = MUSIC_FILE_MAIN_MUSIC
			cur_file_drums = MUSIC_FILE_DRUMS
			_start_stem(cur_file_main, name + "_main", name, pos_main, 1.0)
			var drum_stem: String = positions.get("drum_stem", "")
			if drum_stem != "":
				_start_stem(cur_file_drums, drum_stem, drum_stem, pos_drums, 0.0)
			else:
				players[MUSIC_FILE_DRUMS].stop()
				player_meta[MUSIC_FILE_DRUMS] = {}
				file_volume[MUSIC_FILE_DRUMS] = 0.0
		_:
			cur_file_main = MUSIC_FILE_MAIN_MUSIC
			_start_stem(cur_file_main, name + "_main", name, pos_main, 1.0)

## Packed position like BASS_MusicGetOrderPosition with PSCALER 4: LOWORD = order, HIWORD = row * 4
func get_music_order(file: int) -> int:
	var pl: AudioStreamPlayer = players.get(file)
	var m: Dictionary = player_meta.get(file, {})
	if pl == null or m.is_empty() or not pl.playing:
		return 0
	var sample := int(pl.get_playback_position() * int(m.rate))
	var tl: Array = m.timeline
	var lo := 0
	var hi := tl.size() - 1
	while lo < hi:
		var mid := (lo + hi + 1) >> 1
		if int(tl[mid][0]) <= sample:
			lo = mid
		else:
			hi = mid - 1
	var e: Array = tl[lo]
	return int(e[1]) | (int(e[2]) * 4 << 16)

func start_burst() -> void:
	if music_burst_state == MUSIC_BURST_OFF:
		music_burst_state = MUSIC_BURST_STARTING
		burst_state_counter = 400

func fade_out(duration: int) -> void:
	if cur_music_tune != PvZ.MUSIC_TUNE_NONE:
		fade_out_counter = duration
		fade_out_duration = duration

func update_music_burst() -> void:
	var board = App.board
	if board == null:
		return
	if App.game_mode == PvZ.GAMEMODE_INTRO:
		return
	var scheme := 0
	if cur_music_tune == PvZ.MUSIC_TUNE_DAY_GRASSWALK or cur_music_tune == PvZ.MUSIC_TUNE_POOL_WATERYGRAVES \
			or cur_music_tune == PvZ.MUSIC_TUNE_FOG_RIGORMORMIST or cur_music_tune == PvZ.MUSIC_TUNE_ROOF_GRAZETHEROOF:
		scheme = 1
	elif cur_music_tune == PvZ.MUSIC_TUNE_NIGHT_MOONGRAINS:
		scheme = 2
	else:
		return
	var packed_main := get_music_order(cur_file_main)
	if burst_state_counter > 0:
		burst_state_counter -= 1
	if drums_state_counter > 0:
		drums_state_counter -= 1
	var fade_vol := 0.0
	var drums_vol := 0.0
	var main_vol := 1.0
	match music_burst_state:
		MUSIC_BURST_OFF:
			if board.count_zombies_on_screen() >= 10 or burst_override == 1:
				start_burst()
		MUSIC_BURST_STARTING:
			if scheme == 1:
				fade_vol = Tod.animate_curve_float(400, 0, burst_state_counter, 0.0, 1.0, Tod.CURVE_LINEAR)
				if burst_state_counter == 100:
					music_drums_state = MUSIC_DRUMS_ON_QUEUED
					queued_drum_track_packed_order = packed_main
				elif burst_state_counter == 0:
					music_burst_state = MUSIC_BURST_ON
					burst_state_counter = 800
			else:
				if music_drums_state == MUSIC_DRUMS_OFF:
					music_drums_state = MUSIC_DRUMS_ON_QUEUED
					queued_drum_track_packed_order = packed_main
					burst_state_counter = 400
				elif music_drums_state == MUSIC_DRUMS_ON_QUEUED:
					burst_state_counter = 400
				else:
					main_vol = Tod.animate_curve_float(400, 0, burst_state_counter, 1.0, 0.0, Tod.CURVE_LINEAR)
					if burst_state_counter == 0:
						music_burst_state = MUSIC_BURST_ON
						burst_state_counter = 800
		MUSIC_BURST_ON:
			fade_vol = 1.0
			if scheme == 2:
				main_vol = 0.0
			if burst_state_counter == 0 and ((board.count_zombies_on_screen() < 4 and burst_override == -1) or burst_override == 2):
				if scheme == 1:
					music_burst_state = MUSIC_BURST_FINISHING
					burst_state_counter = 800
					music_drums_state = MUSIC_DRUMS_OFF_QUEUED
					queued_drum_track_packed_order = packed_main
				else:
					music_burst_state = MUSIC_BURST_FINISHING
					burst_state_counter = 1100
					music_drums_state = MUSIC_DRUMS_FADING
					drums_state_counter = 800
		MUSIC_BURST_FINISHING:
			if scheme == 1:
				fade_vol = Tod.animate_curve_float(800, 0, burst_state_counter, 1.0, 0.0, Tod.CURVE_LINEAR)
			else:
				main_vol = Tod.animate_curve_float(400, 0, burst_state_counter, 0.0, 1.0, Tod.CURVE_LINEAR)
			if burst_state_counter == 0 and music_drums_state == MUSIC_DRUMS_OFF:
				music_burst_state = MUSIC_BURST_OFF
	var drums_jump_order := -1
	var order_main := 0
	var order_drum := 0
	if scheme == 1:
		order_main = ((packed_main >> 16) & 0xFFFF) / 128
		order_drum = ((queued_drum_track_packed_order >> 16) & 0xFFFF) / 128
	else:
		order_main = packed_main & 0xFFFF
		order_drum = queued_drum_track_packed_order & 0xFFFF
		if ((packed_main >> 16) & 0xFFFF) > 252:
			order_main += 1
		if ((queued_drum_track_packed_order >> 16) & 0xFFFF) > 252:
			order_drum += 1
	match music_drums_state:
		MUSIC_DRUMS_ON_QUEUED:
			if order_main != order_drum:
				drums_vol = 1.0
				music_drums_state = MUSIC_DRUMS_ON
				if scheme == 2:
					drums_jump_order = 76 if order_main % 2 == 0 else 77
		MUSIC_DRUMS_ON:
			drums_vol = 1.0
		MUSIC_DRUMS_OFF_QUEUED:
			drums_vol = 1.0
			if order_main != order_drum and scheme == 1:
				music_drums_state = MUSIC_DRUMS_FADING
				drums_state_counter = 50
		MUSIC_DRUMS_FADING:
			if scheme == 2:
				drums_vol = Tod.animate_curve_float(800, 0, drums_state_counter, 1.0, 0.0, Tod.CURVE_LINEAR)
			else:
				drums_vol = Tod.animate_curve_float(50, 0, drums_state_counter, 1.0, 0.0, Tod.CURVE_LINEAR)
			if drums_state_counter == 0:
				music_drums_state = MUSIC_DRUMS_OFF
	if scheme == 1:
		set_song_volume(cur_file_hihats, fade_vol)
		set_song_volume(cur_file_drums, drums_vol)
	else:
		set_song_volume(cur_file_main, main_vol)
		if drums_jump_order != -1:
			var stem := "moongrains_burst%d" % drums_jump_order
			_start_stem(MUSIC_FILE_DRUMS, stem, stem, 0.0, drums_vol)
		set_song_volume(cur_file_drums, drums_vol)

func music_update() -> void:
	if fade_out_counter > 0:
		fade_out_counter -= 1
		if fade_out_counter == 0:
			stop_all_music()
		else:
			set_song_volume(cur_file_main, Tod.animate_curve_float(fade_out_duration, 0, fade_out_counter, 1.0, 0.0, Tod.CURVE_LINEAR))
	if App.board == null or not App.board.paused:
		update_music_burst()

func make_sure_music_is_playing(tune: int) -> void:
	if cur_music_tune != tune:
		stop_all_music()
		play_music(tune)

func start_game_music() -> void:
	var board = App.board
	if App.game_mode == PvZ.GAMEMODE_CHALLENGE_ZEN_GARDEN or App.game_mode == PvZ.GAMEMODE_TREE_OF_WISDOM:
		make_sure_music_is_playing(PvZ.MUSIC_TUNE_ZEN_GARDEN)
	elif App.is_final_boss_level():
		make_sure_music_is_playing(PvZ.MUSIC_TUNE_FINAL_BOSS_BRAINIAC_MANIAC)
	elif App.is_wallnut_bowling_level() or App.is_whack_a_zombie_level() or App.is_little_trouble_level() or App.is_bungee_blitz_level() \
			or App.game_mode == PvZ.GAMEMODE_CHALLENGE_SPEED:
		make_sure_music_is_playing(PvZ.MUSIC_TUNE_MINIGAME_LOONBOON)
	elif App.is_mini_boss_level() or App.game_mode == PvZ.GAMEMODE_CHALLENGE_COLUMN:
		make_sure_music_is_playing(PvZ.MUSIC_TUNE_CONVEYER)
	elif App.is_stormy_night_level():
		stop_all_music()
	elif App.is_scary_potter_level() or App.is_izombie_level():
		make_sure_music_is_playing(PvZ.MUSIC_TUNE_PUZZLE_CEREBRAWL)
	elif board.stage_has_fog():
		make_sure_music_is_playing(PvZ.MUSIC_TUNE_FOG_RIGORMORMIST)
	elif board.stage_is_night():
		make_sure_music_is_playing(PvZ.MUSIC_TUNE_NIGHT_MOONGRAINS)
	elif board.stage_has_6_rows():
		make_sure_music_is_playing(PvZ.MUSIC_TUNE_POOL_WATERYGRAVES)
	elif board.stage_has_roof():
		make_sure_music_is_playing(PvZ.MUSIC_TUNE_ROOF_GRAZETHEROOF)
	else:
		make_sure_music_is_playing(PvZ.MUSIC_TUNE_DAY_GRASSWALK)

func game_music_pause(pause: bool) -> void:
	if pause:
		if not paused and cur_music_tune != PvZ.MUSIC_TUNE_NONE:
			pause_positions.clear()
			for f in players.keys():
				var pl: AudioStreamPlayer = players[f]
				if pl.playing:
					pause_positions[f] = pl.get_playback_position()
					pl.stream_paused = true
			paused = true
	elif paused:
		for f in pause_positions.keys():
			players[f].stream_paused = false
		paused = false
