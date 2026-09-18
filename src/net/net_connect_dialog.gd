class_name NetConnectDialog
extends LawnDialog
## "Social" from the main menu: host a lobby, or join one by IP (localhost, LAN, Radmin VPN, Hamachi) and port.

const BTN_HOST := 10
const BTN_JOIN := 11
const BTN_CANCEL := 12
const EDIT_IP := 1
const EDIT_PORT := 2
const EXTRA_HEIGHT := 150

var ip_edit: EditWidget
var port_edit: EditWidget
var host_button: NetUi.StoneButton
var join_button: NetUi.StoneButton
var cancel_button: NetUi.StoneButton
var message := ""
var message_is_error := false

func _init() -> void:
	super._init(NetSession.DIALOG_CONNECT, true, "Multiplayer",
		"Play Co-op or Versus with friends on this PC, your LAN, Radmin VPN or Hamachi. Host a lobby, or type the host's IP address to join.",
		"", BUTTONS_NONE)
	vertical_center_text = false
	ip_edit = EditWidget.create_lawn(EDIT_IP, self, self)
	ip_edit.max_chars = 64
	ip_edit.set_text(str(App._settings.get_value("net", "LastAddress", "localhost")))
	port_edit = EditWidget.create_lawn(EDIT_PORT, self, self)
	port_edit.max_chars = 5
	port_edit.set_text(str(App._settings.get_value("net", "LastPort", NetSession.DEFAULT_PORT)))
	host_button = NetUi.StoneButton.new(BTN_HOST, self, "Host Lobby")
	join_button = NetUi.StoneButton.new(BTN_JOIN, self, "Join")
	cancel_button = NetUi.StoneButton.new(BTN_CANCEL, self, "[DIALOG_BUTTON_CANCEL]")
	calc_size(170, EXTRA_HEIGHT)

func added_to_manager(wm: WidgetManager) -> void:
	super.added_to_manager(wm)
	for w in [ip_edit, port_edit, host_button, join_button, cancel_button]:
		add_widget(w)
	wm.set_focus(ip_edit)

func removed_from_manager(wm: WidgetManager) -> void:
	super.removed_from_manager(wm)
	for w in [ip_edit, port_edit, host_button, join_button, cancel_button]:
		remove_widget(w)

func resize(nx: int, ny: int, w: int, h: int) -> void:
	super.resize(nx, ny, w, h)
	if ip_edit == null:
		return
	var left: int = content_insets[0] + 20
	var inner_w: int = width - content_insets[0] - content_insets[2] - 40
	var top: int = height - EXTRA_HEIGHT - 70
	ip_edit.resize(left + 110, top, inner_w - 110 - 150, 28)
	port_edit.resize(left + inner_w - 80, top, 80, 28)
	var bw: int = Tod.idiv(inner_w - 20, 3)
	var by: int = height - content_insets[3] - 60
	host_button.resize(left, by, bw, 46)
	join_button.resize(left + bw + 10, by, bw, 46)
	cancel_button.resize(left + (bw + 10) * 2, by, bw, 46)

func draw(g: Graphics) -> void:
	super.draw(g)
	var font := Res.get_font("FONT_DWARVENTODCRAFT15")
	var label_y := ip_edit.y + 20
	TodStrings.draw_string(g, "IP address", ip_edit.x - 110, label_y, font, NetUi.TEXT_GOLD, TodStrings.DS_ALIGN_LEFT)
	TodStrings.draw_string(g, "Port", port_edit.x - 50, label_y, font, NetUi.TEXT_GOLD, TodStrings.DS_ALIGN_LEFT)
	LawnButtons.draw_edit_box(g, ip_edit)
	LawnButtons.draw_edit_box(g, port_edit)
	var hint := "Tip: \"localhost\" joins a lobby on this PC. Default port %d." % NetSession.DEFAULT_PORT
	var small := Res.get_font("FONT_BRIANNETOD12")
	TodStrings.draw_string(g, hint, Tod.idiv(width, 2), ip_edit.y + 58, small, Color8(200, 190, 150), TodStrings.DS_ALIGN_CENTER)
	var text := message
	var col := Color8(255, 110, 90) if message_is_error else NetUi.TEXT_SYSTEM
	if App.net.state == NetSession.S_CONNECTING:
		text = App.net.status_text + "." .repeat(Tod.idiv(update_cnt, 30) % 3)
		col = NetUi.TEXT_SYSTEM
	if text != "":
		var rect := Rect2i(content_insets[0] + 20, ip_edit.y + 70, width - content_insets[0] - content_insets[2] - 40, 44)
		TodStrings.draw_string_wrapped(g, text, rect, small, col, PvZ.DS_ALIGN_CENTER_VERTICAL_MIDDLE)

func update() -> void:
	super.update()
	var connecting := App.net.state == NetSession.S_CONNECTING
	NetUi.set_enabled(host_button, not connecting)
	NetUi.set_enabled(join_button, not connecting)
	ip_edit.visible = not connecting
	port_edit.visible = not connecting

func _port() -> int:
	var p := port_edit.text.strip_edges()
	if not p.is_valid_int() or int(p) < 1 or int(p) > 65535:
		return -1
	return int(p)

func _remember() -> void:
	App._settings.set_value("net", "LastAddress", ip_edit.text.strip_edges())
	App._settings.set_value("net", "LastPort", port_edit.text.strip_edges())
	App._settings.save(App.SETTINGS_PATH)

func button_press(_bid: int, _count: int = 1) -> void:
	App.play_sample("SOUND_GRAVEBUTTON")

func button_depress(bid: int) -> void:
	match bid:
		BTN_HOST:
			var port := _port()
			if port < 0:
				_error("The port must be a number from 1 to 65535.")
				return
			_remember()
			var err := App.net.host(port)
			if err != "":
				_error(err)
				return
			App.kill_dialog(id)
		BTN_JOIN:
			var port := _port()
			if port < 0:
				_error("The port must be a number from 1 to 65535.")
				return
			if ip_edit.text.strip_edges() == "":
				_error("Type the host's IP address (or localhost).")
				return
			_remember()
			var err := App.net.join(ip_edit.text, port)
			if err != "":
				_error(err)
		BTN_CANCEL:
			if App.net.state == NetSession.S_CONNECTING:
				App.net.cancel_connect()
				message = "Cancelled."
				message_is_error = false
			else:
				App.kill_dialog(id)

func _error(text: String) -> void:
	message = text
	message_is_error = true
	App.play_sample("SOUND_BUZZER")

func edit_widget_text(eid: int, _s: String) -> void:
	if eid == EDIT_IP:
		button_depress(BTN_JOIN)
	else:
		button_depress(BTN_JOIN)

func allow_char(eid: int, ch: String) -> bool:
	var c := ch.unicode_at(0)
	if eid == EDIT_PORT:
		return c >= 0x30 and c <= 0x39
	return c > 32 and c < 127

func key_down(key: int) -> void:
	if key == WidgetManager.KEYCODE_ESCAPE:
		button_depress(BTN_CANCEL)
	elif key == WidgetManager.KEYCODE_TAB:
		App.widget_manager.set_focus(port_edit if App.widget_manager.focus_widget == ip_edit else ip_edit)
