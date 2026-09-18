class_name PlayerInfo
extends RefCounted
## Port of PlayerInfo (+ PottedPlant). Saved as JSON in user://userdata/.

const MAX_POTTED_PLANTS := 200
const PURCHASE_COUNT_OFFSET := 1000

class PottedPlant:
	const FACING_RIGHT := 0
	const FACING_LEFT := 1
	var seed_type := -1
	var which_zen_garden := 0
	var x := 0
	var y := 0
	var facing := FACING_RIGHT
	var last_watered_time := 0
	var draw_variation := 0
	var plant_age := 0
	var times_fed := 0
	var feedings_per_grow := 0
	var plant_need := 0
	var last_need_fulfilled_time := 0
	var last_fertilized_time := 0
	var last_chocolate_time := 0

	func initialize_potted_plant(the_seed_type: int) -> void:
		seed_type = the_seed_type
		which_zen_garden = PvZ.GARDEN_MAIN
		x = 0
		y = 0
		facing = FACING_RIGHT
		last_watered_time = 0
		draw_variation = PvZ.VARIATION_NORMAL
		plant_age = PvZ.PLANTAGE_SPROUT
		times_fed = 0
		feedings_per_grow = Tod.rand_range_int(3, 5)
		plant_need = PvZ.PLANTNEED_NONE
		last_need_fulfilled_time = 0
		last_fertilized_time = 0
		last_chocolate_time = 0

	func to_dict() -> Dictionary:
		return {"seed_type": seed_type, "garden": which_zen_garden, "x": x, "y": y, "facing": facing,
			"last_watered": last_watered_time, "variation": draw_variation, "age": plant_age, "times_fed": times_fed,
			"feedings_per_grow": feedings_per_grow, "need": plant_need, "last_need_fulfilled": last_need_fulfilled_time,
			"last_fertilized": last_fertilized_time, "last_chocolate": last_chocolate_time}

	func from_dict(d: Dictionary) -> void:
		seed_type = d.get("seed_type", -1); which_zen_garden = d.get("garden", 0); x = d.get("x", 0); y = d.get("y", 0)
		facing = d.get("facing", 0); last_watered_time = d.get("last_watered", 0); draw_variation = d.get("variation", 0)
		plant_age = d.get("age", 0); times_fed = d.get("times_fed", 0); feedings_per_grow = d.get("feedings_per_grow", 0)
		plant_need = d.get("need", 0); last_need_fulfilled_time = d.get("last_need_fulfilled", 0)
		last_fertilized_time = d.get("last_fertilized", 0); last_chocolate_time = d.get("last_chocolate", 0)

var name := ""
var use_seq := 0
var id := 0
var level := 1
var coins := 0
var finished_adventure := 0
var challenge_records: Array = []
var purchases: Array = []
var play_time_active_player := 0
var play_time_inactive_player := 0
var has_used_cheat_keys := 0
var has_woken_stinky := 0
var didnt_purchase_packet_upgrade := 0
var last_stinky_chocolate_time := 0
var stinky_pos_x := 0
var stinky_pos_y := 0
var has_unlocked_minigames := 0
var has_unlocked_puzzle_mode := 0
var has_new_mini_game := 0
var has_new_scary_potter := 0
var has_new_izombie := 0
var has_new_survival := 0
var has_unlocked_survival_mode := 0
var needs_message_on_game_selector := 0
var needs_magic_taco_reward := 0
var has_seen_stinky := 0
var has_seen_upsell := 0
var potted_plants: Array = []   # PottedPlant
var earned_achievements: Array = []
var shown_achievements: Array = []

func _init() -> void:
	reset()

func reset() -> void:
	level = 1
	coins = 0
	finished_adventure = 0
	challenge_records = []
	challenge_records.resize(100)
	challenge_records.fill(0)
	purchases = []
	purchases.resize(80)
	purchases.fill(0)
	play_time_active_player = 0
	play_time_inactive_player = 0
	has_used_cheat_keys = 0
	has_woken_stinky = 0
	didnt_purchase_packet_upgrade = 0
	last_stinky_chocolate_time = 0
	stinky_pos_x = 0
	stinky_pos_y = 0
	has_unlocked_minigames = 0
	has_unlocked_puzzle_mode = 0
	has_new_mini_game = 0
	has_new_scary_potter = 0
	has_new_izombie = 0
	has_new_survival = 0
	has_unlocked_survival_mode = 0
	needs_message_on_game_selector = 0
	needs_magic_taco_reward = 0
	has_seen_stinky = 0
	has_seen_upsell = 0
	potted_plants = []
	earned_achievements = []
	earned_achievements.resize(PvZ.NUM_ACHIEVEMENTS)
	earned_achievements.fill(false)
	shown_achievements = []
	shown_achievements.resize(PvZ.NUM_ACHIEVEMENTS)
	shown_achievements.fill(false)

func num_potted_plants() -> int:
	return potted_plants.size()

func add_coins(amount: int) -> void:
	coins = clampi(coins + amount, 0, 99999)

func reset_challenge_record(mode: int) -> void:
	challenge_records[mode - PvZ.GAMEMODE_SURVIVAL_NORMAL_STAGE_1] = 0

static func _path(the_id: int) -> String:
	return "user://userdata/user%d.json" % the_id

func save_details() -> void:
	DirAccess.make_dir_recursive_absolute("user://userdata")
	var pots: Array = []
	for p in potted_plants:
		pots.append(p.to_dict())
	var d := {
		"version": 12, "level": level, "coins": coins, "finished_adventure": finished_adventure,
		"challenge_records": challenge_records, "purchases": purchases,
		"play_time_active": play_time_active_player, "play_time_inactive": play_time_inactive_player,
		"has_used_cheat_keys": has_used_cheat_keys, "has_woken_stinky": has_woken_stinky,
		"didnt_purchase_packet_upgrade": didnt_purchase_packet_upgrade, "last_stinky_chocolate_time": last_stinky_chocolate_time,
		"stinky_pos_x": stinky_pos_x, "stinky_pos_y": stinky_pos_y, "has_unlocked_minigames": has_unlocked_minigames,
		"has_unlocked_puzzle_mode": has_unlocked_puzzle_mode, "has_new_mini_game": has_new_mini_game,
		"has_new_scary_potter": has_new_scary_potter, "has_new_izombie": has_new_izombie, "has_new_survival": has_new_survival,
		"has_unlocked_survival_mode": has_unlocked_survival_mode, "needs_message_on_game_selector": needs_message_on_game_selector,
		"needs_magic_taco_reward": needs_magic_taco_reward, "has_seen_stinky": has_seen_stinky, "has_seen_upsell": has_seen_upsell,
		"potted_plants": pots, "earned_achievements": earned_achievements, "shown_achievements": shown_achievements,
	}
	var f := FileAccess.open(_path(id), FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))

func load_details() -> void:
	if not FileAccess.file_exists(_path(id)):
		return
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(_path(id)))
	if not (parsed is Dictionary):
		push_warning("The save data is corrupted. Resetting")
		reset()
		return
	var d: Dictionary = parsed
	reset()
	level = int(d.get("level", 1))
	coins = int(d.get("coins", 0))
	finished_adventure = int(d.get("finished_adventure", 0))
	var cr: Array = d.get("challenge_records", [])
	for i in mini(cr.size(), 100):
		challenge_records[i] = int(cr[i])
	var pu: Array = d.get("purchases", [])
	for i in mini(pu.size(), 80):
		purchases[i] = int(pu[i])
	play_time_active_player = int(d.get("play_time_active", 0))
	play_time_inactive_player = int(d.get("play_time_inactive", 0))
	has_used_cheat_keys = int(d.get("has_used_cheat_keys", 0))
	has_woken_stinky = int(d.get("has_woken_stinky", 0))
	didnt_purchase_packet_upgrade = int(d.get("didnt_purchase_packet_upgrade", 0))
	last_stinky_chocolate_time = int(d.get("last_stinky_chocolate_time", 0))
	stinky_pos_x = int(d.get("stinky_pos_x", 0))
	stinky_pos_y = int(d.get("stinky_pos_y", 0))
	has_unlocked_minigames = int(d.get("has_unlocked_minigames", 0))
	has_unlocked_puzzle_mode = int(d.get("has_unlocked_puzzle_mode", 0))
	has_new_mini_game = int(d.get("has_new_mini_game", 0))
	has_new_scary_potter = int(d.get("has_new_scary_potter", 0))
	has_new_izombie = int(d.get("has_new_izombie", 0))
	has_new_survival = int(d.get("has_new_survival", 0))
	has_unlocked_survival_mode = int(d.get("has_unlocked_survival_mode", 0))
	needs_message_on_game_selector = int(d.get("needs_message_on_game_selector", 0))
	needs_magic_taco_reward = int(d.get("needs_magic_taco_reward", 0))
	has_seen_stinky = int(d.get("has_seen_stinky", 0))
	has_seen_upsell = int(d.get("has_seen_upsell", 0))
	for pd in d.get("potted_plants", []):
		var p := PottedPlant.new()
		p.from_dict(pd)
		potted_plants.append(p)
	var ea: Array = d.get("earned_achievements", [])
	for i in mini(ea.size(), 20):
		earned_achievements[i] = bool(ea[i])
	var sa: Array = d.get("shown_achievements", [])
	for i in mini(sa.size(), 20):
		shown_achievements[i] = bool(sa[i])

func delete_user_files() -> void:
	DirAccess.remove_absolute(_path(id))
	for mode in PvZ.NUM_GAME_MODES:
		var p := "user://userdata/game%d_%d.json" % [id, mode]
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
