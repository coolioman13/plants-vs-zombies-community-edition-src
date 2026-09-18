class_name NetChooserScreen
extends Widget
## Online "Choose your plants / zombies": everyone picks at once. In Co-op a plant can only belong to one player.

const BTN_READY := 1
const BTN_BACK := 2
const BTN_LEAVE := 3
const GRID_COLS := 8
const TEAM_RECT := Rect2(488, 96, 772, 330)
const CHAT_RECT := Rect2i(520, 470, 710, 150)

var ready_button: GameButton
var back_button: NetUi.StoneButton
var leave_button: NetUi.StoneButton
var chat_edit: NetUi.ChatBox
var tool_tip := ToolTipWidget.new()
var age := 0

func _init() -> void:
	ready_button = GameButton.new(BTN_READY)
	ready_button.label = "[LETS_ROCK_BUTTON]"
	ready_button.button_image = Res.get_image("IMAGE_SEEDCHOOSER_BUTTON")
	ready_button.disabled_image = Res.get_image("IMAGE_SEEDCHOOSER_BUTTON_DISABLED")
	ready_button.over_overlay_image = Res.get_image("IMAGE_SEEDCHOOSER_BUTTON_GLOW")
	ready_button.set_font(Res.get_font("FONT_DWARVENTODCRAFT18YELLOW"))
	ready_button.colors[GameButton.COLOR_LABEL] = Color.WHITE
	ready_button.colors[GameButton.COLOR_LABEL_HILITE] = Color.WHITE
	ready_button.resize(154, 545 + PvZ.SEED_CHOOSER_EXTRA_HEIGHT, 156, 42)
	ready_button.text_offset_y = -1
	ready_button.parent_widget = self
	back_button = NetUi.StoneButton.new(BTN_BACK, self, "Back to Lobby")
	back_button.resize(870, 646, 190, 46)
	leave_button = NetUi.StoneButton.new(BTN_LEAVE, self, "Leave")
	leave_button.resize(1080, 646, 150, 46)
	chat_edit = NetUi.ChatBox.new(self)
	chat_edit.resize(CHAT_RECT.position.x, CHAT_RECT.end.y + 12, CHAT_RECT.size.x, 28)

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	add_widget(back_button)
	add_widget(leave_button)
	add_widget(chat_edit)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	remove_widget(back_button)
	remove_widget(leave_button)
	remove_widget(chat_edit)

func _net() -> NetSession:
	return App.net

func _my_seeds() -> Array:
	return _net().seed_list_for(_net().local_slot)

func _me() -> Dictionary:
	return _net().local_player()

func _seed_pos(index: int) -> Vector2i:
	return Vector2i(index % GRID_COLS * 53 + 22, Tod.idiv(index, GRID_COLS) * (PvZ.SEED_PACKET_HEIGHT + 2) + PvZ.SEED_PACKET_HEIGHT + 53)

func _bank_pos(index: int) -> Vector2i:
	return Vector2i(10 + 79 + index * 51, 8)

func _seed_at(mx: int, my: int) -> int:
	var seeds := _my_seeds()
	for i in seeds.size():
		var p := _seed_pos(i)
		if Rect2i(p.x, p.y, PvZ.SEED_PACKET_WIDTH, PvZ.SEED_PACKET_HEIGHT).has_point(Vector2i(mx, my)):
			return seeds[i]
	var me := _me()
	if not me.is_empty():
		for i in me.picks.size():
			var p := _bank_pos(i)
			if Rect2i(p.x, p.y, PvZ.SEED_PACKET_WIDTH, PvZ.SEED_PACKET_HEIGHT).has_point(Vector2i(mx, my)):
				return me.picks[i]
	return PvZ.SEED_NONE

func update() -> void:
	super.update()
	age += 1
	var net := _net()
	var me := _me()
	var full: bool = not me.is_empty() and me.picks.size() == int(net.choose_info.get("slots", 0))
	ready_button.label = "Not Ready" if me.get("ready", false) else "[LETS_ROCK_BUTTON]"
	ready_button.disabled = not full
	ready_button.update()
	back_button.visible = net.is_host
	var wm := App.widget_manager
	var mx: int = wm.last_mouse_x - x
	var my: int = wm.last_mouse_y - y
	var st := _seed_at(mx, my)
	tool_tip.visible = false
	if st != PvZ.SEED_NONE:
		App.set_cursor(App.CURSOR_HAND)
		tool_tip.set_title("")
		tool_tip.set_label(Plant.get_name_string(st))
		var owner := net.seed_owner(st)
		if int(net.choose_info.get("mode", 0)) == NetSession.MODE_COOP and owner != -1 and owner != net.local_slot:
			tool_tip.set_warning_text("Taken by " + net.player_by_slot(owner).get("name", "?"))
		else:
			tool_tip.set_warning_text("")
		tool_tip.x = clampi(mx - Tod.idiv(tool_tip.width, 2), 4, PvZ.BOARD_WIDTH - tool_tip.width - 4)
		tool_tip.y = my + 28
		tool_tip.visible = true
	elif ready_button.is_mouse_over() and not ready_button.disabled:
		App.set_cursor(App.CURSOR_HAND)
	else:
		App.set_cursor(App.CURSOR_POINTER)

func mouse_down(mx: int, my: int, click_count: int) -> void:
	super.mouse_down(mx, my, click_count)
	if click_count < 0:
		return
	var net := _net()
	if ready_button.is_mouse_over() and not ready_button.disabled:
		App.play_sample("SOUND_TAP")
		net.request_ready_state(not _me().get("ready", false))
		return
	var st := _seed_at(mx, my)
	if st == PvZ.SEED_NONE:
		return
	var me := _me()
	if me.get("ready", false):
		App.play_sample("SOUND_BUZZER")
		return
	var owner := net.seed_owner(st)
	var coop := int(net.choose_info.get("mode", 0)) == NetSession.MODE_COOP
	if st in me.picks:
		App.play_sample("SOUND_TAP")
	elif coop and owner != -1:
		App.play_sample("SOUND_BUZZER")
		return
	elif me.picks.size() >= int(net.choose_info.get("slots", 0)):
		App.play_sample("SOUND_BUZZER")
		return
	else:
		App.play_sample("SOUND_SEEDLIFT")
	net.request_pick(st)

func button_press(_bid: int, _count: int = 1) -> void:
	App.play_sample("SOUND_TAP")

func button_depress(bid: int) -> void:
	match bid:
		BTN_BACK:
			_net().host_back_to_lobby()
		BTN_LEAVE:
			_net().leave()

func edit_widget_text(_eid: int, text: String) -> void:
	_net().send_chat(text)
	chat_edit.set_text("")

func draw(g: Graphics) -> void:
	g.set_linear_blend(true)
	var net := _net()
	var info := net.choose_info
	var lvl: int = info.get("level", 1)
	var versus: bool = int(info.get("mode", 0)) == NetSession.MODE_VERSUS
	var bg_index := clampi(Tod.idiv(lvl - 1, 10) + 1, 1, 5)
	var bg := Res.load_image_path("images/background%d" % bg_index)
	if bg:
		g.set_colorize_images(true)
		g.set_color(Color8(150, 150, 150))
		g.draw_image(bg, -220, 0)
		g.set_colorize_images(false)
	var me := _me()
	var zombie_side: bool = versus and me.get("team", 0) == NetSession.TEAM_ZOMBIES

	# ------------------------------------------------ bank with my picks
	var bank := Res.get_image("IMAGE_SEEDBANK")
	var slots: int = info.get("slots", 6)
	if zombie_side:
		g.set_colorize_images(true)
		g.set_color(Color8(196, 150, 255))
	var extra := maxi(0, slots * 51 + 89 - bank.width + 14)
	g.draw_image(bank, 10, 0)
	if extra > 0:
		g.draw_image_src(bank, 10 + bank.width - 12, 0, Rect2(bank.width - extra - 12, 0, extra + 12, bank.height))
	g.set_colorize_images(false)
	TodStrings.draw_string(g, "?", 44, 78, Res.get_font("FONT_CONTINUUMBOLD14"), Color.BLACK, TodStrings.DS_ALIGN_CENTER)
	var silhouette := Res.get_image("IMAGE_SEEDPACKETSILHOUETTE")
	var picks: Array = me.get("picks", [])
	for i in slots:
		var bp := _bank_pos(i)
		if i < picks.size():
			SeedPacket.draw_seed_packet(g, bp.x, bp.y, picks[i], PvZ.SEED_NONE, 0, 255, true, false)
		else:
			g.draw_image(silhouette, bp.x, bp.y)

	# ------------------------------------------------ seed grid
	g.draw_image(Res.get_image("IMAGE_SEEDCHOOSER_BACKGROUND"), 0, 87)
	TodStrings.draw_string(g, "Choose your zombies!" if zombie_side else "[CHOOSE_YOUR_PLANTS]", 229, 110, Res.get_font("FONT_DWARVENTODCRAFT18YELLOW"), Color.WHITE, TodStrings.DS_ALIGN_CENTER)
	var seeds := _my_seeds()
	for i in seeds.size():
		var st: int = seeds[i]
		var p := _seed_pos(i)
		var owner := net.seed_owner(st)
		var mine := st in picks
		var taken := not versus and owner != -1 and not mine
		var gray := 255
		if mine:
			gray = 55
		elif taken or me.get("ready", false):
			gray = 90
		SeedPacket.draw_seed_packet(g, p.x, p.y, st, PvZ.SEED_NONE, 0, gray, true, false)
		if taken:
			var who: Dictionary = net.player_by_slot(owner)
			var col := NetSession.player_color(owner)
			g.color = Color8(0, 0, 0, 180)
			g.fill_rect(p.x + 29, p.y + 2, 19, 17)
			g.color = col
			g.fill_rect(p.x + 30, p.y + 3, 17, 15)
			var initial := str(who.get("name", "?")).substr(0, 1).to_upper()
			TodStrings.draw_string(g, initial, p.x + 38, p.y + 15, Res.get_font("FONT_BRIANNETOD12"), Color.BLACK, TodStrings.DS_ALIGN_CENTER)
	ready_button.draw(g)
	var status := "Pick %d, then press Let's Rock!" % slots
	if me.get("ready", false):
		status = "Ready! Waiting for the others..."
	elif picks.size() == slots:
		status = "All set! Press Let's Rock!"
	TodStrings.draw_string(g, status, 232, 540 + PvZ.SEED_CHOOSER_EXTRA_HEIGHT, Res.get_font("FONT_BRIANNETOD12"), Color8(255, 240, 150), TodStrings.DS_ALIGN_CENTER)

	# ------------------------------------------------ team panel
	NetUi.draw_frame(g, TEAM_RECT, 0.45)
	var title := ("Versus" if versus else "Co-op  -  " + NetSession.level_name(lvl))
	TodStrings.draw_string(g, title, int(TEAM_RECT.get_center().x), int(TEAM_RECT.position.y) + 40, Res.get_font("FONT_DWARVENTODCRAFT24"), NetUi.TEXT_GOLD, TodStrings.DS_ALIGN_CENTER)
	var row_y := int(TEAM_RECT.position.y) + 62
	for pl in net.players:
		var col := NetSession.player_color(pl.slot)
		var label: String = pl.name
		if versus:
			label += "  (Plants)" if pl.team == NetSession.TEAM_PLANTS else "  (Zombies)"
		NetUi.draw_text(g, label, 520, row_y + 18, Res.get_font("FONT_BRIANNETOD16"), col)
		var ready_text := "Ready!" if pl.ready else "Choosing... %d/%d" % [pl.picks.size(), slots]
		NetUi.draw_text(g, ready_text, 1226, row_y + 18, Res.get_font("FONT_BRIANNETOD16"), Color8(120, 255, 120) if pl.ready else Color8(230, 220, 190), TodStrings.DS_ALIGN_RIGHT)
		var sg := g.copy()
		sg.scale_x = 0.5
		sg.scale_y = 0.5
		for j in pl.picks.size():
			SeedPacket.draw_seed_packet(sg, 522 + j * 27, row_y + 24, pl.picks[j], PvZ.SEED_NONE, 0, 255, false, false)
		row_y += 64

	# ------------------------------------------------ chat
	NetUi.draw_shade(g, Rect2(CHAT_RECT.position.x - 10, CHAT_RECT.position.y - 8, CHAT_RECT.size.x + 20, CHAT_RECT.size.y + 16), 0.5)
	NetUi.draw_chat(g, CHAT_RECT, net.chat_log)
	LawnButtons.draw_edit_box(g, chat_edit)
	if chat_edit.text == "" and App.widget_manager.focus_widget != chat_edit:
		TodStrings.draw_string(g, "Click here to chat", chat_edit.x + 6, chat_edit.y + 20, Res.get_font("FONT_BRIANNETOD12"), Color8(170, 170, 190), TodStrings.DS_ALIGN_LEFT)
	tool_tip.draw(g)
