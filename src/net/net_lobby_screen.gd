class_name NetLobbyScreen
extends Widget
## Multiplayer lobby, laid out like the mini-games screen: players, game mode, level / sides, chat, start.

const BTN_START := 1
const BTN_LEAVE := 2
const BTN_PREV := 3
const BTN_NEXT := 4
const BTN_SWAP := 5
const BTN_PREV10 := 6
const BTN_NEXT10 := 7

const PLAYER_Y := 190
const MODE_RECTS := [Rect2i(772, 190, 118, 120), Rect2i(930, 190, 118, 120)]
const CHAT_RECT := Rect2i(96, 392, 560, 196)
const HEADER_COLOR := Color8(120, 70, 25)

var start_button: NetUi.StoneButton
var leave_button: NetUi.StoneButton
var prev_button: NetUi.StoneButton
var next_button: NetUi.StoneButton
var prev10_button: NetUi.StoneButton
var next10_button: NetUi.StoneButton
var swap_button: NetUi.StoneButton
var chat_edit: NetUi.ChatBox
var hover_mode := -1

func _init() -> void:
	start_button = NetUi.StoneButton.new(BTN_START, self, "Start Game")
	start_button.resize(780, 626, 190, 46)
	leave_button = NetUi.StoneButton.new(BTN_LEAVE, self, "Leave")
	leave_button.resize(990, 626, 150, 46)
	prev10_button = NetUi.StoneButton.new(BTN_PREV10, self, "<<")
	prev10_button.resize(752, 382, 76, 46)
	prev_button = NetUi.StoneButton.new(BTN_PREV, self, "<")
	prev_button.resize(832, 382, 76, 46)
	next_button = NetUi.StoneButton.new(BTN_NEXT, self, ">")
	next_button.resize(1036, 382, 76, 46)
	next10_button = NetUi.StoneButton.new(BTN_NEXT10, self, ">>")
	next10_button.resize(1116, 382, 76, 46)
	swap_button = NetUi.StoneButton.new(BTN_SWAP, self, "Swap Sides")
	swap_button.resize(880, 470, 180, 46)
	chat_edit = NetUi.ChatBox.new(self)
	chat_edit.resize(CHAT_RECT.position.x + 8, CHAT_RECT.end.y + 16, CHAT_RECT.size.x - 16, 28)

func _buttons() -> Array:
	return [start_button, leave_button, prev_button, next_button, prev10_button, next10_button, swap_button]

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	for b in _buttons():
		add_widget(b)
	add_widget(chat_edit)
	wm.set_focus(chat_edit)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	for b in _buttons():
		remove_widget(b)
	remove_widget(chat_edit)

func update() -> void:
	super.update()
	var net: NetSession = App.net
	var host := net.is_host
	var coop := net.mode == NetSession.MODE_COOP
	for b in [prev_button, next_button, prev10_button, next10_button]:
		b.visible = host and coop
	swap_button.visible = host and not coop
	start_button.visible = host
	NetUi.set_enabled(start_button, net.can_start_game() == "")
	NetUi.set_enabled(prev_button, net.level > 1)
	NetUi.set_enabled(prev10_button, net.level > 1)
	NetUi.set_enabled(next_button, net.level < 50)
	NetUi.set_enabled(next10_button, net.level < 50)
	NetUi.set_enabled(swap_button, net.players.size() == 2)
	var wm := App.widget_manager
	hover_mode = -1
	for i in MODE_RECTS.size():
		if (MODE_RECTS[i] as Rect2i).has_point(Vector2i(wm.last_mouse_x - x, wm.last_mouse_y - y)):
			hover_mode = i
	if host and hover_mode != -1:
		App.set_cursor(App.CURSOR_HAND)

func mouse_down(mx: int, my: int, click_count: int) -> void:
	super.mouse_down(mx, my, click_count)
	var net: NetSession = App.net
	if not net.is_host or click_count < 0:
		return
	for i in MODE_RECTS.size():
		if (MODE_RECTS[i] as Rect2i).has_point(Vector2i(mx, my)) and net.mode != i:
			App.play_sample("SOUND_TAP")
			net.host_set_mode(i)

func button_press(bid: int, _count: int = 1) -> void:
	App.play_sample("SOUND_GRAVEBUTTON" if bid == BTN_START else "SOUND_TAP")

func button_depress(bid: int) -> void:
	var net: NetSession = App.net
	match bid:
		BTN_START:
			net.host_start_game()
		BTN_LEAVE:
			net.leave()
		BTN_PREV:
			net.host_set_level(net.level - 1)
		BTN_NEXT:
			net.host_set_level(net.level + 1)
		BTN_PREV10:
			net.host_set_level(net.level - 10)
		BTN_NEXT10:
			net.host_set_level(net.level + 10)
		BTN_SWAP:
			net.host_swap_teams()

func edit_widget_text(_eid: int, text: String) -> void:
	App.net.send_chat(text)
	chat_edit.set_text("")

func draw(g: Graphics) -> void:
	g.set_linear_blend(true)
	var net: NetSession = App.net
	g.draw_image(Res.get_image("IMAGE_CHALLENGE_BACKGROUND"), 0, 0)
	TodStrings.draw_string(g, "Multiplayer Lobby", 400 + PvZ.BOARD_OFFSET_X + 19, 58 + PvZ.BOARD_OFFSET_Y, Res.get_font("FONT_HOUSEOFTERROR28"), Color8(220, 220, 220), TodStrings.DS_ALIGN_CENTER)
	var head := Res.get_font("FONT_DWARVENTODCRAFT18")
	var body := Res.get_font("FONT_BRIANNETOD16")
	var small := Res.get_font("FONT_BRIANNETOD12")

	# ------------------------------------------------ players
	TodStrings.draw_string(g, "Players (%d/%d)" % [net.players.size(), NetSession.MAX_PLAYERS], 376, PLAYER_Y - 12, head, HEADER_COLOR, TodStrings.DS_ALIGN_CENTER)
	for slot in NetSession.MAX_PLAYERS:
		var px := 110 + slot * 136
		var p := net.player_by_slot(slot)
		if p.is_empty():
			g.draw_image(Res.get_image("IMAGE_CHALLENGE_BLANK"), px + 7, PLAYER_Y + 2)
			TodStrings.draw_string_wrapped(g, "Waiting for a player..." if slot < 4 else "", Rect2i(px + 8, PLAYER_Y + 128, 104, 40), small, NetUi.TEXT_DARK, PvZ.DS_ALIGN_CENTER_VERTICAL_MIDDLE)
			continue
		var col := NetSession.player_color(slot)
		g.color = Color(col.r, col.g, col.b, 0.55)
		g.fill_rect(px + 13, PLAYER_Y + 4, 93, 68)
		var portrait := _portrait_for(p)
		var cg := g.copy()
		cg.set_clip_rect(px + 13, PLAYER_Y + 4, 93, 68)
		NetUi.draw_portrait(cg, portrait, px + 59, PLAYER_Y + 72, 0.62 if NetVersus.is_zombie_side_seed(portrait) else 0.7)
		g.draw_image(Res.get_image("IMAGE_CHALLENGE_WINDOW_HIGHLIGHT" if slot == net.local_slot else "IMAGE_CHALLENGE_WINDOW"), px, PLAYER_Y)
		TodStrings.draw_string_wrapped(g, p.name, Rect2i(px + 6, PLAYER_Y + 74, 106, 33), small, NetUi.TEXT_DARK, PvZ.DS_ALIGN_CENTER_VERTICAL_MIDDLE)
		var tag := "Host" if slot == 0 else ("%d ms" % p.ping if p.ping > 0 else "Connected")
		if slot == net.local_slot:
			tag += "  (you)"
		TodStrings.draw_string(g, tag, px + 59, PLAYER_Y + 136, small, col.darkened(0.35), TodStrings.DS_ALIGN_CENTER)
		if net.mode == NetSession.MODE_VERSUS:
			var team := "Plants" if p.team == NetSession.TEAM_PLANTS else "Zombies"
			TodStrings.draw_string(g, team, px + 59, PLAYER_Y + 154, body, Color8(40, 120, 30) if p.team == NetSession.TEAM_PLANTS else Color8(110, 50, 140), TodStrings.DS_ALIGN_CENTER)
		if not p.in_lobby:
			TodStrings.draw_string(g, "(still in match)", px + 59, PLAYER_Y + 172, small, Color8(150, 60, 40), TodStrings.DS_ALIGN_CENTER)

	# ------------------------------------------------ game mode
	TodStrings.draw_string(g, "Game Mode", 958, PLAYER_Y - 12, head, HEADER_COLOR, TodStrings.DS_ALIGN_CENTER)
	var mode_names := ["Co-op", "Versus"]
	var mode_desc := ["Up to 4 players", "1 vs 1"]
	for i in 2:
		var r: Rect2i = MODE_RECTS[i]
		var selected := net.mode == i
		var mg := g.copy()
		mg.set_clip_rect(r.position.x + 13, r.position.y + 4, 93, 68)
		mg.color = Color8(140, 200, 90) if i == 0 else Color8(150, 110, 170)
		mg.fill_rect(r.position.x + 13, r.position.y + 4, 93, 68)
		if i == 0:
			NetUi.draw_portrait(mg, PvZ.SEED_SUNFLOWER, r.position.x + 40, r.position.y + 74, 0.62)
			NetUi.draw_portrait(mg, PvZ.SEED_PEASHOOTER, r.position.x + 78, r.position.y + 74, 0.62)
		else:
			NetUi.draw_portrait(mg, PvZ.SEED_PEASHOOTER, r.position.x + 38, r.position.y + 74, 0.62)
			NetUi.draw_portrait(mg, PvZ.SEED_ZOMBIE_NORMAL, r.position.x + 84, r.position.y + 76, 0.5)
		if not selected:
			g.color = Color8(0, 0, 0, 90)
			g.fill_rect(r.position.x + 13, r.position.y + 4, 93, 68)
		var img := "IMAGE_CHALLENGE_WINDOW_HIGHLIGHT" if selected or (net.is_host and hover_mode == i) else "IMAGE_CHALLENGE_WINDOW"
		g.draw_image(Res.get_image(img), r.position.x, r.position.y)
		var tc := Color8(250, 40, 40) if selected else NetUi.TEXT_DARK
		TodStrings.draw_string_wrapped(g, mode_names[i], Rect2i(r.position.x + 6, r.position.y + 74, 106, 33), body, tc, PvZ.DS_ALIGN_CENTER_VERTICAL_MIDDLE)
		TodStrings.draw_string(g, mode_desc[i], r.position.x + 59, r.position.y + 136, small, NetUi.TEXT_DARK, TodStrings.DS_ALIGN_CENTER)

	if net.mode == NetSession.MODE_COOP:
		TodStrings.draw_string(g, "Level", 958, 366, head, HEADER_COLOR, TodStrings.DS_ALIGN_CENTER)
		TodStrings.draw_string(g, NetSession.level_name(net.level), 972, 414, Res.get_font("FONT_HOUSEOFTERROR20"), Color8(70, 40, 15), TodStrings.DS_ALIGN_CENTER)
		TodStrings.draw_string(g, NetSession.level_area_name(net.level), 972, 444, small, NetUi.TEXT_DARK, TodStrings.DS_ALIGN_CENTER)
		var info := "Pick any Adventure level. Each player picks their own plants; no two players can take the same plant. Sun is shared by the whole team."
		TodStrings.draw_string_wrapped(g, info, Rect2i(760, 470, 424, 80), small, NetUi.TEXT_DARK, PvZ.DS_ALIGN_CENTER_VERTICAL_MIDDLE)
	else:
		TodStrings.draw_string(g, "Sides", 958, 366, head, HEADER_COLOR, TodStrings.DS_ALIGN_CENTER)
		var plants := net.players.filter(func(p): return p.team == NetSession.TEAM_PLANTS)
		var zombies := net.players.filter(func(p): return p.team == NetSession.TEAM_ZOMBIES)
		TodStrings.draw_string(g, "Plants: " + (plants[0].name if plants.size() > 0 else "-"), 958, 402, body, Color8(40, 120, 30), TodStrings.DS_ALIGN_CENTER)
		TodStrings.draw_string(g, "Zombies: " + (zombies[0].name if zombies.size() > 0 else "-"), 958, 428, body, Color8(110, 50, 140), TodStrings.DS_ALIGN_CENTER)
		if not net.is_host:
			TodStrings.draw_string_wrapped(g, "Plants win by destroying 3 target zombies. Zombies win by reaching the house.", Rect2i(760, 460, 424, 60), small, NetUi.TEXT_DARK, PvZ.DS_ALIGN_CENTER_VERTICAL_MIDDLE)
		else:
			TodStrings.draw_string_wrapped(g, "Plants win by destroying 3 target zombies. Zombies win by reaching the house.", Rect2i(760, 520, 424, 40), small, NetUi.TEXT_DARK, PvZ.DS_ALIGN_CENTER_VERTICAL_MIDDLE)

	# ------------------------------------------------ status
	var status := net.can_start_game()
	if not net.is_host:
		status = "Waiting for the host to start the game..."
	if status != "":
		TodStrings.draw_string_wrapped(g, status, Rect2i(760, 572, 424, 46), body, Color8(150, 60, 40), PvZ.DS_ALIGN_CENTER_VERTICAL_MIDDLE)
	elif net.is_host:
		TodStrings.draw_string_wrapped(g, "Everyone's here. Ready when you are!", Rect2i(760, 572, 424, 46), body, Color8(40, 120, 30), PvZ.DS_ALIGN_CENTER_VERTICAL_MIDDLE)

	# ------------------------------------------------ chat
	TodStrings.draw_string(g, "Chat", 376, CHAT_RECT.position.y - 12, head, HEADER_COLOR, TodStrings.DS_ALIGN_CENTER)
	g.color = Color8(60, 35, 10, 60)
	g.fill_rect(CHAT_RECT.position.x - 8, CHAT_RECT.position.y - 4, CHAT_RECT.size.x + 16, CHAT_RECT.size.y + 8)
	NetUi.draw_chat(g, Rect2i(CHAT_RECT.position.x, CHAT_RECT.position.y, CHAT_RECT.size.x, CHAT_RECT.size.y), _chat_for_parchment(net.chat_log), 0, false)
	LawnButtons.draw_edit_box(g, chat_edit)
	if chat_edit.text == "" and App.widget_manager.focus_widget != chat_edit:
		TodStrings.draw_string(g, "Click here and press Enter to chat", chat_edit.x + 6, chat_edit.y + 20, small, Color8(170, 170, 190), TodStrings.DS_ALIGN_LEFT)

	# ------------------------------------------------ last match result
	if net.lobby_notice != "" and Time.get_ticks_msec() - net.lobby_notice_time < 9000:
		var font := Res.get_font("FONT_HOUSEOFTERROR20")
		var w := font.string_width(net.lobby_notice) + 60
		var cx := 640
		NetUi.draw_frame(g, Rect2(cx - w / 2, 8, w, 66), 0.35)
		TodStrings.draw_string(g, net.lobby_notice, cx, 50, font, NetUi.TEXT_GOLD, TodStrings.DS_ALIGN_CENTER)

## Chat colours are tuned for the dark in-game strip; darken them for the parchment.
func _chat_for_parchment(log: Array) -> Array:
	var out: Array = []
	for e in log:
		var c: Color = e.color
		out.append({"text": e.text, "time": e.time, "color": Color8(120, 70, 20) if e.sys else c.darkened(0.55)})
	return out

func _portrait_for(p: Dictionary) -> int:
	var net: NetSession = App.net
	if net.mode == NetSession.MODE_VERSUS and p.team == NetSession.TEAM_ZOMBIES:
		return [PvZ.SEED_ZOMBIE_NORMAL, PvZ.SEED_ZOMBIE_TRAFFIC_CONE, PvZ.SEED_ZOMBIE_PAIL, PvZ.SEED_ZOMBIE_FOOTBALL][p.slot % 4]
	return [PvZ.SEED_PEASHOOTER, PvZ.SEED_SUNFLOWER, PvZ.SEED_WALLNUT, PvZ.SEED_CHERRYBOMB][p.slot % 4]
