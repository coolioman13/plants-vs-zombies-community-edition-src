class_name NetGameOverlay
extends Widget
## Online match HUD on top of the board: chat, Versus score, connection notices. Other players' cursors are drawn
## from inside the board's UI layer (draw_remote_cursors) so they pan with the lawn during cutscenes.

const CHAT_RECT := Rect2i(14, 470, 470, 150)
const CHAT_FADE_MS := 9000

var chat_edit: NetUi.ChatBox = null

func _init() -> void:
	mouse_visible = false
	clip = false

func open_chat() -> void:
	if chat_edit != null:
		App.widget_manager.set_focus(chat_edit)
		return
	chat_edit = NetUi.ChatBox.new(self)
	chat_edit.on_close = close_chat
	chat_edit.resize(CHAT_RECT.position.x + 8, CHAT_RECT.end.y + 14, CHAT_RECT.size.x - 16, 28)
	add_widget(chat_edit)
	App.widget_manager.set_focus(chat_edit)
	App.net.chat_open = true

func close_chat() -> void:
	if chat_edit == null:
		return
	remove_widget(chat_edit)
	chat_edit = null
	App.net.chat_open = false
	if App.board:
		App.widget_manager.set_focus(App.board)

func edit_widget_text(_eid: int, text: String) -> void:
	if text.strip_edges() != "":
		App.net.send_chat(text)
	close_chat()

func removed_from_manager(wm: WidgetManager) -> void:
	if chat_edit:
		remove_widget(chat_edit)
		chat_edit = null
	super.removed_from_manager(wm)

func update() -> void:
	super.update()
	if chat_edit and App.widget_manager.focus_widget != chat_edit and App.get_dialog_count() == 0:
		close_chat()

func draw(g: Graphics) -> void:
	var net: NetSession = App.net
	var board: Board = App.board
	if board == null:
		return
	g.set_linear_blend(true)

	# ------------------------------------------------ chat
	if chat_edit:
		NetUi.draw_shade(g, Rect2(CHAT_RECT.position.x - 6, CHAT_RECT.position.y - 6, CHAT_RECT.size.x + 12, CHAT_RECT.size.y + 50), 0.45)
		NetUi.draw_chat(g, CHAT_RECT, net.chat_log)
		LawnButtons.draw_edit_box(g, chat_edit)
	else:
		if not net.chat_log.is_empty():
			var age: int = Time.get_ticks_msec() - int(net.chat_log[-1].time)
			var fade := clampf(1.0 - float(age - CHAT_FADE_MS) / 1500.0, 0.0, 1.0)
			if fade > 0.0:
				NetUi.draw_shade(g, Rect2(CHAT_RECT.position.x - 6, CHAT_RECT.position.y - 6, CHAT_RECT.size.x + 12, CHAT_RECT.size.y + 12), 0.3 * fade)
		NetUi.draw_chat(g, CHAT_RECT, net.chat_log, CHAT_FADE_MS)
		if App.game_scene == PvZ.SCENE_PLAYING and board.main_counter < 1500:
			NetUi.draw_text(g, "Press Enter to chat", CHAT_RECT.position.x, CHAT_RECT.end.y + 34, Res.get_font("FONT_BRIANNETOD12"), Color8(255, 255, 255, 170))

	# ------------------------------------------------ versus score
	if board.is_versus() and App.game_scene != PvZ.SCENE_LEVEL_INTRO:
		_draw_versus_hud(g, board)

	# ------------------------------------------------ connection notices
	var notice := ""
	if not net.is_host and net.stall_ticks > 60:
		notice = "Waiting for the host..."
	elif not net._go:
		notice = "Waiting for everyone to load..."
	if notice != "":
		var font := Res.get_font("FONT_DWARVENTODCRAFT18")
		var w := font.string_width(notice) + 40
		NetUi.draw_shade(g, Rect2(640 - w / 2, 96, w, 34), 0.55)
		NetUi.draw_text(g, notice, 640, 120, font, NetUi.TEXT_SYSTEM, TodStrings.DS_ALIGN_CENTER)

func _draw_versus_hud(g: Graphics, board: Board) -> void:
	var destroyed := NetVersus.targets_destroyed(board)
	var font := Res.get_font("FONT_HOUSEOFTERROR20")
	var text := "Targets destroyed: %d / %d" % [mini(destroyed, NetVersus.TARGETS_TO_WIN), NetVersus.TARGETS_TO_WIN]
	var w := font.string_width(text) + 50
	var px := PvZ.BOARD_WIDTH - w - 150
	NetUi.draw_frame(g, Rect2(px, PvZ.BOARD_HEIGHT - 60, w, 64), 0.3)
	TodStrings.draw_string(g, text, px + w / 2, PvZ.BOARD_HEIGHT - 20, font, NetUi.TEXT_GOLD, TodStrings.DS_ALIGN_CENTER)
	if board.vs_winner != -1:
		var big := Res.get_font("FONT_HOUSEOFTERROR28")
		var win := "PLANTS WIN!" if board.vs_winner == NetSession.TEAM_PLANTS else "ZOMBIES WIN!"
		var mine := board.net_team_of(board.net_local_slot) == board.vs_winner
		var col := Color8(120, 255, 90) if board.vs_winner == NetSession.TEAM_PLANTS else Color8(210, 120, 255)
		var ww := big.string_width(win) + 120
		NetUi.draw_frame(g, Rect2(640 - ww / 2, 230, ww, 130), 0.5)
		TodStrings.draw_string(g, win, 640, 300, big, col, TodStrings.DS_ALIGN_CENTER)
		TodStrings.draw_string(g, "You won!" if mine else "Better luck next time!", 640, 332, Res.get_font("FONT_DWARVENTODCRAFT18"), NetUi.TEXT_GOLD, TodStrings.DS_ALIGN_CENTER)

## Other players' cursors, in board coordinates: pointer, name tag and what they're holding.
func draw_remote_cursors(board: Board, g: Graphics) -> void:
	var net: NetSession = App.net
	if App.game_scene != PvZ.SCENE_PLAYING:
		return
	var pointer := Res.get_image("IMAGE_MOUSE_CURSOR")
	for slot in net.cursors:
		var c: Dictionary = net.cursors[slot]
		if not c.get("in", false) or slot >= board.net_cursors.size():
			continue
		var p := net.player_by_slot(slot)
		if p.is_empty():
			continue
		var cx := int(c.x)
		var cy := int(c.y)
		var co: CursorObject = board.net_cursors[slot]
		var held := PvZ.SEED_NONE
		if co.cursor_type == PvZ.CURSOR_TYPE_PLANT_FROM_BANK or co.cursor_type == PvZ.CURSOR_TYPE_PLANT_FROM_USABLE_COIN:
			held = co.imitater_type if co.type == PvZ.SEED_IMITATER else co.type
		var hg := g.copy()
		hg.colorize_images = true
		hg.color = Color(1, 1, 1, 0.65)
		if held != PvZ.SEED_NONE:
			Plant.draw_seed_type(hg, held, PvZ.SEED_NONE, PvZ.VARIATION_NORMAL, cx - 25, cy - 35)
		elif co.cursor_type == PvZ.CURSOR_TYPE_SHOVEL:
			hg.draw_image(Res.get_image("IMAGE_SHOVEL"), cx - 15, cy - 65)
		var col := NetSession.player_color(slot)
		var pg := g.copy()
		pg.colorize_images = true
		pg.color = col.lightened(0.35)
		if pointer:
			pg.draw_image(pointer, cx, cy)
		NetUi.draw_name_tag(g, p.name, cx + 18, cy + 26, col)
