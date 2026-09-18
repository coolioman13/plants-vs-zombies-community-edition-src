class_name Achievements
extends RefCounted
## Port of Achievements.cpp (QE achievement list).

## [achievement_type, image_index, name, show_in_awards]
const DEFS := [
	[PvZ.ACHIEVEMENT_HOME_SECURITY, 0, "HOME_SECURITY", true],
	[PvZ.ACHIEVEMENT_NOBEL_PEAS_PRIZE, 1, "NOBEL_PEAS_PRIZE", true],
	[PvZ.ACHIEVEMENT_BETTER_OFF_DEAD, 2, "BETTER_OFF_DEAD", false],
	[PvZ.ACHIEVEMENT_CHINA_SHOP, 3, "CHINA_SHOP", false],
	[PvZ.ACHIEVEMENT_SPUDOW, 4, "SPUDOW", true],
	[PvZ.ACHIEVEMENT_EXPLODONATOR, 5, "EXPLODONATOR", true],
	[PvZ.ACHIEVEMENT_MORTICULTURALIST, 6, "MORTICULTURALIST", false],
	[PvZ.ACHIEVEMENT_DONT_PEA_IN_POOL, 7, "DONT_PEA_IN_POOL", true],
	[PvZ.ACHIEVEMENT_ROLL_SOME_HEADS, 8, "ROLL_SOME_HEADS", true],
	[PvZ.ACHIEVEMENT_GROUNDED, 9, "GROUNDED", true],
	[PvZ.ACHIEVEMENT_ZOMBOLOGIST, 10, "ZOMBOLOGIST", true],
	[PvZ.ACHIEVEMENT_PENNY_PINCHER, 11, "PENNY_PINCHER", true],
	[PvZ.ACHIEVEMENT_SUNNY_DAYS, 12, "SUNNY_DAYS", true],
	[PvZ.ACHIEVEMENT_POPCORN_PARTY, 13, "POPCORN_PARTY", true],
	[PvZ.ACHIEVEMENT_GOOD_MORNING, 14, "GOOD_MORNING", true],
	[PvZ.ACHIEVEMENT_NO_FUNGUS_AMONG_US, 15, "NO_FUNGUS_AMONG_US", true],
	[PvZ.ACHIEVEMENT_BEYOND_THE_GRAVE, 16, "BEYOND_THE_GRAVE", true],
	[PvZ.ACHIEVEMENT_IMMORTAL, 17, "IMMORTAL", false],
	[PvZ.ACHIEVEMENT_TOWERING_WISDOM, 18, "TOWERING_WISDOM", false],
	[PvZ.ACHIEVEMENT_MUSTACHE_MODE, 19, "MUSTACHE_MODE", true],
	[PvZ.ACHIEVEMENT_DISCO_IS_UNDEAD, 20, "DISCO_IS_UNDEAD", true],
]

func give_achievement(type: int) -> void:
	var pi = App.player_info
	if pi == null or pi.earned_achievements[type] or not PvZ.HAS_ACHIEVEMENTS:
		return
	pi.earned_achievements[type] = true
	App.play_sample("SOUND_ACHIEVEMENT")
	if App.board:
		var title := "[ACHIEVEMENT_%s_TITLE]" % return_achievement_name(type)
		var msg := Tod.replace_string("[ACHIEVEMENT_ACHIEVED]", "{ACHIEVEMENT}", title)
		App.board.display_advice(msg, PvZ.MESSAGE_STYLE_HINT_FAST, PvZ.ADVICE_NONE)

func init_achievement() -> void:
	if App.player_info == null or not PvZ.HAS_ACHIEVEMENTS:
		return
	if App.has_finished_adventure():
		give_achievement(PvZ.ACHIEVEMENT_HOME_SECURITY)
	if App.earned_gold_trophy():
		give_achievement(PvZ.ACHIEVEMENT_NOBEL_PEAS_PRIZE)
	if App.can_spawn_yetis():
		give_achievement(PvZ.ACHIEVEMENT_ZOMBOLOGIST)
	var tree_size: int = App.player_info.challenge_records[PvZ.GAMEMODE_TREE_OF_WISDOM - 1]
	if tree_size >= 100:
		give_achievement(PvZ.ACHIEVEMENT_TOWERING_WISDOM)
	if App.get_num_trophies(PvZ.CHALLENGE_PAGE_CHALLENGE) >= App.get_total_trophies(PvZ.CHALLENGE_PAGE_CHALLENGE):
		give_achievement(PvZ.ACHIEVEMENT_BEYOND_THE_GRAVE)

static func return_achievement_name(index: int) -> String:
	return DEFS[index][2]

static func return_show_in_awards(index: int) -> bool:
	return DEFS[index][3]
