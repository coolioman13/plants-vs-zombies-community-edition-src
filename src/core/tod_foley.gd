class_name TodFoley
extends Node
## Port of TodFoley: named sound effects with variations, pitch ranges, and instance limits.

const MAX_FOLEY_INSTANCES := 8
const FOLEYFLAGS_LOOP := 0
const FOLEYFLAGS_ONE_AT_A_TIME := 1
const FOLEYFLAGS_MUTE_ON_PAUSE := 2
const FOLEYFLAGS_USES_MUSIC_VOLUME := 3
const FOLEYFLAGS_DONT_REPEAT := 4

class FoleyInstance:
	var player: AudioStreamPlayer
	var ref_count := 0
	var paused := false
	var start_time := 0
	var pause_offset := 0.0

var type_data: Array = []   # per foley: {instances: Array[FoleyInstance], last_variation}
var sfx_volume := 0.85
var music_volume := 0.85

func _ready() -> void:
	for i in FoleyTable.ENTRIES.size():
		var insts: Array = []
		for j in MAX_FOLEY_INSTANCES:
			insts.append(FoleyInstance.new())
		type_data.append({"instances": insts, "last_variation": -1})

func _flag(foley: int, bit: int) -> bool:
	return Tod.test_bit(FoleyTable.ENTRIES[foley][2], bit)

func _make_player(stream: AudioStream) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.stream = stream
	add_child(p)
	return p

func _release(fi: FoleyInstance) -> void:
	if fi.player != null:
		fi.player.stop()
		fi.player.queue_free()
		fi.player = null
	fi.ref_count = 0
	fi.paused = false

func release_finished_instances() -> void:
	for td in type_data:
		for fi in td.instances:
			if fi.ref_count != 0 and not fi.paused:
				if fi.player == null or not fi.player.playing:
					_release(fi)

func _played_too_recently(foley: int) -> bool:
	for fi in type_data[foley].instances:
		if fi.ref_count != 0 and App.update_count - fi.start_time < 10:
			return true
	return false

func _find_instance(foley: int) -> FoleyInstance:
	for fi in type_data[foley].instances:
		if fi.ref_count > 0:
			return fi
	return null

func _free_instance(foley: int) -> FoleyInstance:
	for fi in type_data[foley].instances:
		if fi.ref_count == 0:
			return fi
	return null

func play_foley_pitch(foley: int, pitch: float) -> void:
	var params: Array = FoleyTable.ENTRIES[foley]
	release_finished_instances()
	if _played_too_recently(foley) and not _flag(foley, FOLEYFLAGS_LOOP):
		return
	if _flag(foley, FOLEYFLAGS_ONE_AT_A_TIME):
		var existing := _find_instance(foley)
		if existing != null:
			existing.ref_count += 1
			existing.start_time = App.update_count
			return
	var fi := _free_instance(foley)
	if fi == null:
		return
	var td: Dictionary = type_data[foley]
	var sfx: Array = params[1]
	var variations: Array = []
	for i in sfx.size():
		if not _flag(foley, FOLEYFLAGS_DONT_REPEAT) or td.last_variation != i:
			variations.append(i)
	if variations.is_empty():
		return
	var v: int = Tod.pick_from_array(variations)
	td.last_variation = v
	var stream := Res.get_sound(sfx[v])
	if stream == null:
		return
	var looping := _flag(foley, FOLEYFLAGS_LOOP)
	if looping and stream is AudioStreamOggVorbis:
		stream = stream.duplicate()
		stream.loop = true
	var p := _make_player(stream)
	fi.player = p
	fi.ref_count = 1
	fi.start_time = App.update_count
	if pitch != 0.0:
		p.pitch_scale = pow(1.0594630943592952645618252949463, pitch)
	var vol := sfx_volume
	if _flag(foley, FOLEYFLAGS_USES_MUSIC_VOLUME):
		vol = music_volume
	p.volume_db = linear_to_db(maxf(vol, 0.0001))
	p.play()

func play_foley(foley: int) -> void:
	var pr: float = FoleyTable.ENTRIES[foley][0]
	var pitch := 0.0
	if pr != 0.0:
		pitch = Tod.rand_float(pr)
	play_foley_pitch(foley, pitch)

func stop_foley(foley: int) -> void:
	release_finished_instances()
	var fi := _find_instance(foley)
	if fi == null:
		return
	fi.ref_count -= 1
	if fi.ref_count == 0:
		_release(fi)

func is_foley_playing(foley: int) -> bool:
	release_finished_instances()
	return _find_instance(foley) != null

func game_pause(entering: bool) -> void:
	release_finished_instances()
	for foley in type_data.size():
		if not _flag(foley, FOLEYFLAGS_MUTE_ON_PAUSE):
			continue
		for fi in type_data[foley].instances:
			if fi.ref_count == 0 or fi.player == null:
				continue
			if entering:
				fi.paused = true
				fi.pause_offset = fi.player.get_playback_position()
				fi.player.stop()
			elif fi.paused:
				fi.paused = false
				fi.player.play(fi.pause_offset)

func cancel_paused_foley() -> void:
	release_finished_instances()
	for td in type_data:
		for fi in td.instances:
			if fi.ref_count != 0 and fi.paused:
				_release(fi)

func rehookup_sound_with_music_volume() -> void:
	for foley in type_data.size():
		if _flag(foley, FOLEYFLAGS_USES_MUSIC_VOLUME):
			for fi in type_data[foley].instances:
				if fi.ref_count != 0 and fi.player:
					fi.player.volume_db = linear_to_db(maxf(music_volume, 0.0001))

## Plays a raw sound id like SexyAppBase::PlaySample
func play_sample(sound_id: String) -> void:
	var stream := Res.get_sound(sound_id)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = linear_to_db(maxf(sfx_volume, 0.0001))
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

## SoundInstance::Play + AdjustPitch(steps) for a raw sound id.
func play_sample_pitch(sound_id: String, steps: float) -> void:
	var stream := Res.get_sound(sound_id)
	if stream == null:
		return
	var p := AudioStreamPlayer.new()
	p.stream = stream
	p.volume_db = linear_to_db(maxf(sfx_volume, 0.0001))
	p.pitch_scale = pow(1.0594630943592952645618252949463, steps)
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()
