class_name NetSession
extends Node
## Community edition online play over localhost / LAN / Radmin VPN / Hamachi.
##
## The host owns the lobby and the clock. Matches are deterministic lockstep: every player runs the same board
## simulation from the same seed, and only clicks travel over the network. Clients send their clicks to the host,
## the host stamps each one with the frame it runs on and streams "frame N is ready" batches to everyone, so all
## boards apply the same clicks on the same frames. A board checksum is compared once a second and a client that
## drifts is re-synced from a snapshot of the host's board. If anyone leaves, the whole lobby closes.

const PROTOCOL := 1
const DEFAULT_PORT := 24642
const MAX_PLAYERS := 4
const MAX_NAME_CHARS := 16
const MAX_CHAT_CHARS := 120
const CHAT_HISTORY := 80
const CONNECT_TIMEOUT_MS := 8000
const HELLO_TIMEOUT_MS := 6000
const LOAD_TIMEOUT_MS := 30000
const PEER_TIMEOUT_MIN_MS := 4000
const PEER_TIMEOUT_MAX_MS := 10000
const HASH_INTERVAL := 100
const RESYNC_COOLDOWN := 500
const CURSOR_SEND_MS := 50
const FRAME_SEND_EVERY := 2
const CHANNEL_CURSOR := 1
const DIALOG_CONNECT := 900
const DIALOG_MENU := 901

enum { MODE_COOP, MODE_VERSUS }
enum { TEAM_PLANTS, TEAM_ZOMBIES }
enum { S_OFFLINE, S_CONNECTING, S_LOBBY, S_CHOOSING, S_PLAYING }

const PLAYER_COLORS := [Color8(96, 214, 64), Color8(72, 168, 255), Color8(255, 200, 40), Color8(236, 104, 214)]

## ---------------------------------------------------------------- session state
var state := S_OFFLINE
var is_host := false
var local_slot := 0
## Dictionary per player: id, slot, name, team, picks (Array), ready, loaded, in_lobby, ping
var players: Array = []
var mode := MODE_COOP
var level := 1
## {text, color, sys, time}
var chat_log: Array = []
var choose_info := {}          # mode, level, slots, plants (Array), zombies (Array)
var lobby_notice := ""
var lobby_notice_time := 0
var status_text := ""          # connect dialog status
var screen: Widget = null      # current lobby / chooser screen

var _peer: ENetMultiplayerPeer = null
var _connect_started := 0
var _pending_hello := {}       # host: peer id -> connect time
var _build_hash := ""
var _signals_connected := false

## ---------------------------------------------------------------- match state
var match_active := false
var net_frame := 0
var allowed_frame := 0
var sim_rng: RandomNumberGenerator = null
var match_info := {}
var _ui_rng: RandomNumberGenerator = null
var _host_queue: Array = []    # host: [slot, mx, my, count] waiting for the next frame
var _host_outgoing: Array = [] # host: [frame, slot, mx, my, count] executed but not sent yet
var _client_cmds := {}         # client: frame -> Array of [slot, mx, my, count]
var _host_hashes := {}         # host: frame -> hash
var _last_resync := {}         # host: peer id -> frame
var _go := false
var _load_started := 0
var _saved := {}
var stall_ticks := 0
var resync_count := 0
var cursors := {}              # slot -> {x, y, tx, ty, in}
var _last_cursor_send := 0
var _last_cursor_sent := Vector3i(-99999, 0, 0)
var overlay: NetGameOverlay = null
var chat_open := false
## Prints every board checksum (tools/net_test compares them between processes).
var debug_log_hashes := false
var desync_count := 0
var _host_end_frame := -1
var _host_end_text := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

# ================================================================ helpers
func is_active() -> bool:
	return state != S_OFFLINE

func local_player() -> Dictionary:
	return player_by_slot(local_slot)

func player_by_slot(slot: int) -> Dictionary:
	for p in players:
		if p.slot == slot:
			return p
	return {}

func player_by_id(id: int) -> Dictionary:
	for p in players:
		if p.id == id:
			return p
	return {}

static func player_color(slot: int) -> Color:
	return PLAYER_COLORS[clampi(slot, 0, PLAYER_COLORS.size() - 1)]

func can_start_game() -> String:
	if not is_host:
		return "Only the host can start the game."
	if players.size() < 2:
		return "Waiting for at least 1 more player to join..."
	if mode == MODE_VERSUS and players.size() != 2:
		return "Versus is a 1 vs 1 mode: it needs exactly 2 players."
	for p in players:
		if not p.in_lobby:
			return "Waiting for %s to get back to the lobby..." % p.name
	return ""

static func level_uses_loadouts(lvl: int) -> bool:
	# every x-5 and x-10 adventure level has fixed packets or a conveyor belt
	return lvl % 5 != 0

static func level_name(lvl: int) -> String:
	return "Level %d-%d" % [Tod.idiv(lvl - 1, 10) + 1, (lvl - 1) % 10 + 1]

static func level_area_name(lvl: int) -> String:
	var area: int = Tod.idiv(lvl - 1, 10)
	var names := ["Day", "Night", "Pool", "Fog", "Roof"]
	var n: String = names[clampi(area, 0, 4)]
	match lvl % 10:
		5:
			n += " - Special level"
		0:
			n += " - Conveyor belt"
	return n

func _local_name() -> String:
	var n := App.player_info.name if App.player_info else "Player"
	return n.substr(0, MAX_NAME_CHARS)

## Fingerprint of the game code: every script's path, variables, functions and constants. Script sources aren't
## shipped in exported builds, so this uses what both the editor and a build can see; builds of the same mod match.
func _build_id() -> String:
	if _build_hash != "":
		return _build_hash
	var ctx := HashingContext.new()
	ctx.start(HashingContext.HASH_MD5)
	for script_path in Res.list_scripts("res://src"):
		var s = load(script_path)
		if not (s is GDScript):
			continue
		var parts: Array = [script_path]
		for p in s.get_script_property_list():
			parts.append(p.name)
		var methods: Array = []
		for m in s.get_script_method_list():
			methods.append("%s/%d" % [m.name, m.args.size()])
		methods.sort()
		parts.append_array(methods)
		var consts: Array = s.get_script_constant_map().keys()
		consts.sort()
		for c in consts:
			var v = s.get_script_constant_map()[c]
			parts.append("%s=%s" % [c, v if typeof(v) in [TYPE_INT, TYPE_FLOAT, TYPE_STRING, TYPE_BOOL] else typeof(v)])
		ctx.update(("|".join(parts)).to_utf8_buffer())
	_build_hash = App.RECON_VERSION + ":" + str(PROTOCOL) + ":" + ctx.finish().hex_encode()
	return _build_hash

# ================================================================ connection
func _connect_signals() -> void:
	if _signals_connected:
		return
	_signals_connected = true
	multiplayer.peer_connected.connect(_on_peer_connected)
	multiplayer.peer_disconnected.connect(_on_peer_disconnected)
	multiplayer.connected_to_server.connect(_on_connected_to_server)
	multiplayer.connection_failed.connect(_on_connection_failed)
	multiplayer.server_disconnected.connect(_on_server_disconnected)
	(multiplayer as SceneMultiplayer).peer_packet.connect(_on_packet)

## Returns an error message, or "" when the lobby is open.
func host(port: int) -> String:
	if state != S_OFFLINE:
		return "Already in a multiplayer session."
	if not App.has_finished_adventure():
		return "Finish Adventure mode to unlock multiplayer."
	_connect_signals()
	_build_id()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(port, MAX_PLAYERS - 1, 2)
	if err != OK:
		return "Couldn't open port %d. Another program (or another copy of the game) may be using it." % port
	_peer = peer
	multiplayer.multiplayer_peer = peer
	is_host = true
	state = S_LOBBY
	local_slot = 0
	mode = MODE_COOP
	level = clampi(App.player_info.level if App.player_info.level <= 50 else 1, 1, 50)
	players = [_new_player(1, 0, _local_name())]
	players[0].in_lobby = true
	chat_log.clear()
	_sys("Lobby open on port %d." % port)
	var ips := _local_ipv4s()
	if not ips.is_empty():
		_sys("Players can join with: " + ", ".join(ips) + "   (or localhost on this PC)")
	show_lobby()
	return ""

func _local_ipv4s() -> Array:
	var out: Array = []
	for a in IP.get_local_addresses():
		if a.count(".") == 3 and not a.begins_with("127.") and not a.begins_with("169.254."):
			out.append(a)
	return out

## Returns an error message, or "" while connecting (the connect dialog shows progress).
func join(address: String, port: int) -> String:
	if state != S_OFFLINE:
		return "Already in a multiplayer session."
	if not App.has_finished_adventure():
		return "Finish Adventure mode to unlock multiplayer."
	address = address.strip_edges()
	if address == "" or address.to_lower() == "localhost":
		address = "127.0.0.1"
	_connect_signals()
	_build_id()
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(address, port, 2)
	if err != OK:
		return "Couldn't connect to %s:%d." % [address, port]
	_peer = peer
	multiplayer.multiplayer_peer = peer
	is_host = false
	state = S_CONNECTING
	_connect_started = Time.get_ticks_msec()
	status_text = "Connecting to %s:%d..." % [address, port]
	chat_log.clear()
	return ""

func cancel_connect() -> void:
	if state == S_CONNECTING:
		_close_peer()
		state = S_OFFLINE

func _new_player(id: int, slot: int, the_name: String) -> Dictionary:
	return {"id": id, "slot": slot, "name": the_name, "team": TEAM_PLANTS, "picks": [], "ready": false,
		"loaded": false, "in_lobby": true, "ping": 0}

func _set_peer_timeout(id: int) -> void:
	if _peer == null:
		return
	var pp := _peer.get_peer(id)
	if pp:
		pp.set_timeout(32, PEER_TIMEOUT_MIN_MS, PEER_TIMEOUT_MAX_MS)

func _on_peer_connected(id: int) -> void:
	_set_peer_timeout(id)
	if is_host:
		_pending_hello[id] = Time.get_ticks_msec()

func _on_connected_to_server() -> void:
	_set_peer_timeout(1)
	_send(1, {"t": "hello", "proto": PROTOCOL, "build": _build_id(), "name": _local_name(), "beaten": App.has_finished_adventure()})
	status_text = "Connected, joining lobby..."

func _on_connection_failed() -> void:
	if state == S_CONNECTING:
		end_session("Couldn't connect to the host. Check the IP address, port and firewall, then try again.")

func _on_server_disconnected() -> void:
	if state != S_OFFLINE:
		end_session("The connection to the host was lost." if state != S_CONNECTING else "Couldn't connect to the host.")

func _on_peer_disconnected(id: int) -> void:
	if not is_host:
		return
	_pending_hello.erase(id)
	var p := player_by_id(id)
	if not p.is_empty():
		players.erase(p)  # gone: don't try to tell them the lobby closed
		end_session("%s left the game, so the lobby was closed." % p.name)

## Leaves on purpose (lobby Leave button, in-game Leave Match, closing the game).
func leave() -> void:
	if state == S_OFFLINE:
		return
	if is_host:
		end_session("", "The host closed the lobby.")
	else:
		_send(1, {"t": "bye"})
		_flush()
		end_session("")

## Ends the session locally and returns to the main menu. The host tells everyone else why first.
func end_session(reason: String, broadcast_reason: String = "") -> void:
	if state == S_OFFLINE:
		return
	if is_host:
		var msg := broadcast_reason if broadcast_reason != "" else reason
		_broadcast({"t": "end", "reason": msg if msg != "" else "The host closed the lobby."})
		_flush()
	_close_peer()
	if match_active:
		_end_match_local()
	App.kill_dialog(DIALOG_CONNECT)
	App.kill_dialog(DIALOG_MENU)
	_remove_screen()
	var was_connecting := state == S_CONNECTING
	state = S_OFFLINE
	players.clear()
	is_host = false
	chat_open = false
	if not (was_connecting and App.game_selector):
		App.music.stop_all_music()
		App.show_game_selector()
	if reason != "":
		App.lawn_message_box(PvZ.DIALOG_MESSAGE, "Multiplayer", reason, "[DIALOG_BUTTON_OK]", "", Dialog.BUTTONS_FOOTER)

## Called when the window closes.
func shutdown() -> void:
	if state == S_OFFLINE:
		return
	if is_host:
		_broadcast({"t": "end", "reason": "The host closed the game."})
	else:
		_send(1, {"t": "bye"})
	_flush()
	_close_peer()

func _flush() -> void:
	if _peer and _peer.host:
		_peer.host.flush()

func _close_peer() -> void:
	if _peer:
		_peer.close()
	_peer = null
	multiplayer.multiplayer_peer = null
	_pending_hello.clear()

# ================================================================ messaging
func _send(id: int, msg: Dictionary, unreliable: bool = false) -> void:
	if _peer == null or _peer.get_connection_status() == MultiplayerPeer.CONNECTION_DISCONNECTED:
		return
	var mp := multiplayer as SceneMultiplayer
	if unreliable:
		mp.send_bytes(var_to_bytes(msg), id, MultiplayerPeer.TRANSFER_MODE_UNRELIABLE_ORDERED, CHANNEL_CURSOR)
	else:
		mp.send_bytes(var_to_bytes(msg), id, MultiplayerPeer.TRANSFER_MODE_RELIABLE, 0)

## Host: to every joined client (optionally skipping one).
func _broadcast(msg: Dictionary, unreliable: bool = false, except_id: int = 0) -> void:
	if not is_host:
		return
	for p in players:
		if p.id != 1 and p.id != except_id:
			_send(p.id, msg, unreliable)

func _on_packet(id: int, packet: PackedByteArray) -> void:
	var msg = bytes_to_var(packet)
	if not (msg is Dictionary) or not msg.has("t"):
		return
	if is_host:
		_host_message(id, msg)
	elif id == 1:
		_client_message(msg)

func _host_message(id: int, msg: Dictionary) -> void:
	var t: String = str(msg.t)
	if t == "hello":
		_host_hello(id, msg)
		return
	var p := player_by_id(id)
	if p.is_empty():
		return
	match t:
		"bye":
			players.erase(p)
			end_session("%s left the game, so the lobby was closed." % p.name)
		"chat":
			_host_chat(p.slot, str(msg.get("text", "")))
		"pick":
			if state == S_CHOOSING:
				_host_apply_pick(p.slot, int(msg.get("seed", -1)))
		"ready":
			if state == S_CHOOSING:
				_host_set_ready(p.slot, bool(msg.get("on", false)))
		"inlobby":
			p.in_lobby = true
			_broadcast_lobby()
		"loaded":
			p.loaded = true
			_host_check_all_loaded()
		"cmd":
			if match_active and _go:
				_host_queue.append([p.slot, int(msg.get("x", 0)), int(msg.get("y", 0)), int(msg.get("c", 1))])
		"cur":
			var cur := [p.slot, int(msg.get("x", 0)), int(msg.get("y", 0)), bool(msg.get("in", false))]
			_on_cursor(cur)
			_broadcast({"t": "cur", "s": cur[0], "x": cur[1], "y": cur[2], "in": cur[3]}, true, id)
		"h":
			_host_check_hash(id, int(msg.get("f", 0)), int(msg.get("v", 0)))

func _client_message(msg: Dictionary) -> void:
	match str(msg.t):
		"welcome":
			local_slot = int(msg.slot)
			state = S_LOBBY
			App.kill_dialog(DIALOG_CONNECT)
			show_lobby()
		"reject":
			end_session(str(msg.get("reason", "The host refused the connection.")))
		"end":
			end_session(str(msg.get("reason", "The lobby was closed.")))
		"lobby":
			_client_apply_lobby(msg)
		"chat":
			_add_chat(str(msg.get("text", "")), player_color(int(msg.get("s", 0))), false)
		"sys":
			_sys(str(msg.get("text", "")))
		"choose":
			_enter_chooser(msg)
		"picks":
			_client_apply_picks(msg)
		"back":
			_return_to_lobby("")
		"start":
			_begin_match(msg)
		"f":
			_client_frames(msg)
		"matchend":
			_host_end_frame = int(msg.get("f", 0))
			_host_end_text = str(msg.get("text", ""))
		"rs":
			_client_resync(msg)
		"cur":
			_on_cursor([int(msg.get("s", 0)), int(msg.get("x", 0)), int(msg.get("y", 0)), bool(msg.get("in", false))])

# ================================================================ lobby (host)
func _host_hello(id: int, msg: Dictionary) -> void:
	_pending_hello.erase(id)
	var reason := ""
	if int(msg.get("proto", 0)) != PROTOCOL or str(msg.get("build", "")) != _build_id():
		reason = "Your game version doesn't match the host's. Both players need the exact same copy of the mod."
	elif not bool(msg.get("beaten", false)):
		reason = "You need to finish Adventure mode before playing multiplayer."
	elif state != S_LOBBY or match_active:
		reason = "That lobby is already in a match. Try again when it's back in the lobby."
	elif players.size() >= MAX_PLAYERS:
		reason = "That lobby is full (%d players)." % MAX_PLAYERS
	if reason != "":
		_send(id, {"t": "reject", "reason": reason})
		var pp := _peer.get_peer(id) if _peer else null
		if pp:
			pp.peer_disconnect_later()
		return
	var slot := 0
	while not player_by_slot(slot).is_empty():
		slot += 1
	var the_name := _unique_name(str(msg.get("name", "Player")).strip_edges().substr(0, MAX_NAME_CHARS))
	var p := _new_player(id, slot, the_name)
	players.append(p)
	players.sort_custom(func(a, b): return a.slot < b.slot)
	_assign_versus_teams()
	_send(id, {"t": "welcome", "slot": slot})
	_host_sys("%s joined the lobby." % the_name)
	_broadcast_lobby()
	App.play_sample("SOUND_TAP")

func _unique_name(n: String) -> String:
	if n == "":
		n = "Player"
	var out := n
	var i := 2
	while players.any(func(p): return p.name == out):
		out = "%s (%d)" % [n, i]
		i += 1
	return out

func _assign_versus_teams() -> void:
	var zombies := players.filter(func(p): return p.team == TEAM_ZOMBIES).size()
	for p in players:
		if mode == MODE_COOP:
			p.team = TEAM_PLANTS
	if mode == MODE_VERSUS and players.size() >= 2 and zombies != 1:
		for i in players.size():
			players[i].team = TEAM_PLANTS if i == 0 else TEAM_ZOMBIES

func host_set_mode(m: int) -> void:
	if not is_host or state != S_LOBBY:
		return
	mode = m
	_assign_versus_teams()
	_broadcast_lobby()

func host_set_level(lvl: int) -> void:
	if not is_host or state != S_LOBBY:
		return
	level = clampi(lvl, 1, 50)
	_broadcast_lobby()

func host_swap_teams() -> void:
	if not is_host or state != S_LOBBY or mode != MODE_VERSUS:
		return
	for p in players:
		p.team = TEAM_ZOMBIES if p.team == TEAM_PLANTS else TEAM_PLANTS
	_broadcast_lobby()

func _lobby_msg() -> Dictionary:
	var list: Array = []
	for p in players:
		list.append({"id": p.id, "slot": p.slot, "name": p.name, "team": p.team, "in_lobby": p.in_lobby, "ping": p.ping})
	return {"t": "lobby", "players": list, "mode": mode, "level": level}

func _broadcast_lobby() -> void:
	_broadcast(_lobby_msg())

func _client_apply_lobby(msg: Dictionary) -> void:
	mode = int(msg.get("mode", MODE_COOP))
	level = int(msg.get("level", 1))
	var old := {}
	for p in players:
		old[p.slot] = p
	players.clear()
	for e in msg.get("players", []):
		var p := _new_player(int(e.id), int(e.slot), str(e.name))
		p.team = int(e.team)
		p.in_lobby = bool(e.in_lobby)
		p.ping = int(e.get("ping", 0))
		if old.has(p.slot):
			p.picks = old[p.slot].picks
			p.ready = old[p.slot].ready
		players.append(p)

# ================================================================ chat
func send_chat(text: String) -> void:
	text = text.strip_edges().substr(0, MAX_CHAT_CHARS)
	if text == "" or state == S_OFFLINE or state == S_CONNECTING:
		return
	if is_host:
		_host_chat(local_slot, text)
	else:
		_send(1, {"t": "chat", "text": text})

func _host_chat(slot: int, text: String) -> void:
	text = text.strip_edges().substr(0, MAX_CHAT_CHARS)
	var p := player_by_slot(slot)
	if text == "" or p.is_empty():
		return
	var line := "%s: %s" % [p.name, text]
	_add_chat(line, player_color(slot), false)
	_broadcast({"t": "chat", "s": slot, "text": line})

func _host_sys(text: String) -> void:
	_sys(text)
	_broadcast({"t": "sys", "text": text})

func _sys(text: String) -> void:
	_add_chat(text, Color8(255, 240, 150), true)

func _add_chat(text: String, color: Color, sys: bool) -> void:
	chat_log.append({"text": text, "color": color, "sys": sys, "time": Time.get_ticks_msec()})
	while chat_log.size() > CHAT_HISTORY:
		chat_log.pop_front()
	if not sys:
		App.play_sample("SOUND_TAP")

# ================================================================ screens
func show_lobby() -> void:
	_remove_screen()
	App.kill_game_selector()
	App.game_scene = PvZ.SCENE_MENU
	var s := NetLobbyScreen.new()
	s.resize(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	App.widget_manager.add_widget(s)
	App.widget_manager.bring_to_back(s)
	App.widget_manager.set_focus(s)
	screen = s
	App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_TITLE_CRAZY_DAVE_MAIN_THEME)

func _show_chooser() -> void:
	_remove_screen()
	var s := NetChooserScreen.new()
	s.resize(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	App.widget_manager.add_widget(s)
	App.widget_manager.bring_to_back(s)
	App.widget_manager.set_focus(s)
	screen = s
	App.music.make_sure_music_is_playing(PvZ.MUSIC_TUNE_CHOOSE_YOUR_SEEDS)

func _remove_screen() -> void:
	if screen and screen.widget_manager:
		App.widget_manager.remove_widget(screen)
	screen = null

func _return_to_lobby(notice: String) -> void:
	state = S_LOBBY
	for p in players:
		p.picks = []
		p.ready = false
		p.loaded = false
	lobby_notice = notice
	lobby_notice_time = Time.get_ticks_msec()
	show_lobby()
	var me := local_player()
	if not me.is_empty():
		me.in_lobby = true
	if is_host:
		_broadcast_lobby()
	else:
		_send(1, {"t": "inlobby"})

# ================================================================ seed choosing
func host_start_game() -> void:
	if can_start_game() != "":
		return
	for p in players:
		p.picks = []
		p.ready = false
		p.in_lobby = false
	var lvl := NetVersus.LEVEL if mode == MODE_VERSUS else level
	var slots := mini(App.player_info.purchases[PvZ.STORE_ITEM_PACKET_UPGRADE] + 6, PvZ.SEEDBANK_MAX)
	var plants: Array = []
	for st in PvZ.NUM_SEEDS_IN_CHOOSER:
		if st != PvZ.SEED_IMITATER and App.seed_type_available(st):
			plants.append(st)
	if mode == MODE_COOP:
		slots = mini(slots, Tod.idiv(plants.size(), players.size()))
	var msg := {"t": "choose", "mode": mode, "level": lvl, "slots": slots, "plants": plants, "zombies": NetVersus.zombie_seed_list()}
	if mode == MODE_COOP and not level_uses_loadouts(lvl):
		_broadcast_lobby()
		host_begin_match()
		return
	_broadcast(msg)
	_enter_chooser(msg)
	_broadcast_lobby()

func _enter_chooser(msg: Dictionary) -> void:
	choose_info = {"mode": int(msg.mode), "level": int(msg.level), "slots": int(msg.slots),
		"plants": msg.plants, "zombies": msg.zombies}
	state = S_CHOOSING
	for p in players:
		p.picks = []
		p.ready = false
		p.in_lobby = false
	_show_chooser()

func seed_list_for(slot: int) -> Array:
	var p := player_by_slot(slot)
	if choose_info.is_empty() or p.is_empty():
		return []
	if choose_info.mode == MODE_VERSUS and p.team == TEAM_ZOMBIES:
		return choose_info.zombies
	return choose_info.plants

## Which player (slot) already has this seed, -1 if free. Only co-op requires unique picks.
func seed_owner(seed_type: int) -> int:
	for p in players:
		if seed_type in p.picks:
			return p.slot
	return -1

func request_pick(seed_type: int) -> void:
	if state != S_CHOOSING:
		return
	if is_host:
		_host_apply_pick(local_slot, seed_type)
	else:
		_send(1, {"t": "pick", "seed": seed_type})

func request_ready_state(on: bool) -> void:
	if state != S_CHOOSING:
		return
	if is_host:
		_host_set_ready(local_slot, on)
	else:
		_send(1, {"t": "ready", "on": on})

func host_back_to_lobby() -> void:
	if not is_host or state != S_CHOOSING:
		return
	_broadcast({"t": "back"})
	_return_to_lobby("")

func _host_apply_pick(slot: int, seed_type: int) -> void:
	var p := player_by_slot(slot)
	if p.is_empty() or p.ready:
		return
	if seed_type in p.picks:
		p.picks.erase(seed_type)
	elif seed_type in seed_list_for(slot) and p.picks.size() < choose_info.slots:
		if choose_info.mode == MODE_COOP and seed_owner(seed_type) != -1:
			return
		p.picks.append(seed_type)
	else:
		return
	_broadcast_picks()

func _host_set_ready(slot: int, on: bool) -> void:
	var p := player_by_slot(slot)
	if p.is_empty():
		return
	p.ready = on and p.picks.size() == choose_info.slots
	_broadcast_picks()
	if players.all(func(q): return q.ready):
		host_begin_match()

func _broadcast_picks() -> void:
	var picks := {}
	var ready := {}
	for p in players:
		picks[p.slot] = p.picks.duplicate()
		ready[p.slot] = p.ready
	_broadcast({"t": "picks", "picks": picks, "ready": ready})

func _client_apply_picks(msg: Dictionary) -> void:
	var picks: Dictionary = msg.get("picks", {})
	var ready: Dictionary = msg.get("ready", {})
	for p in players:
		p.picks = picks.get(p.slot, [])
		p.ready = ready.get(p.slot, false)

# ================================================================ match start
func host_begin_match() -> void:
	if not is_host:
		return
	var lvl: int = NetVersus.LEVEL if mode == MODE_VERSUS else level
	var list: Array = []
	for p in players:
		list.append({"slot": p.slot, "name": p.name, "team": p.team, "picks": p.picks.duplicate()})
	var msg := {"t": "start", "mode": mode, "level": lvl, "seed": randi(), "players": list,
		"purchases": App.player_info.purchases.duplicate(), "host_name": App.player_info.name,
		"auto_suns": false}
	for p in players:
		p.loaded = false
		p.in_lobby = false
	_broadcast(msg)
	_begin_match(msg)

func _begin_match(msg: Dictionary) -> void:
	_remove_screen()
	App.kill_game_selector()
	match_info = msg
	mode = int(msg.mode)
	var lvl := int(msg.level)
	var list: Array = msg.players
	var teams: Array = []
	var picks: Array = []
	for e in list:
		while teams.size() <= int(e.slot):
			teams.append(TEAM_PLANTS)
			picks.append([])
		teams[int(e.slot)] = int(e.team)
		picks[int(e.slot)] = e.picks
		var p := player_by_slot(int(e.slot))
		if not p.is_empty():
			p.team = int(e.team)
			p.picks = e.picks
	state = S_PLAYING
	match_active = true
	_go = false
	net_frame = 0
	allowed_frame = 0
	stall_ticks = 0
	resync_count = 0
	_host_queue.clear()
	_host_outgoing.clear()
	_client_cmds.clear()
	_host_hashes.clear()
	_last_resync.clear()
	_host_end_frame = -1
	cursors.clear()
	_load_started = Time.get_ticks_msec()

	# Everything the simulation reads from the app has to be identical on every machine.
	_saved = {"player_info": App.player_info, "auto_collect_suns": App.auto_collect_suns, "auto_collect_coins": App.auto_collect_coins,
		"tod_cheat_keys": App.tod_cheat_keys, "debug_keys_enabled": App.debug_keys_enabled, "easy_planting_cheat": App.easy_planting_cheat,
		"app_rand_seed": App.app_rand_seed, "game_mode": App.game_mode, "playing_quickplay": App.playing_quickplay,
		"modes": [App.mustache_mode, App.super_mower_mode, App.future_mode, App.pinata_mode, App.dance_mode, App.daisy_mode, App.sukhbir_mode]}
	var team_profile := PlayerInfo.new()
	team_profile.name = str(msg.get("host_name", "Team"))
	team_profile.id = -1
	team_profile.level = lvl
	team_profile.finished_adventure = 1
	team_profile.purchases = (msg.purchases as Array).duplicate()
	App.player_info = team_profile
	App.tod_cheat_keys = false
	App.debug_keys_enabled = false
	App.easy_planting_cheat = false
	App.is_fast_mode = false
	App.playing_quickplay = false
	App.mustache_mode = false
	App.super_mower_mode = false
	App.future_mode = false
	App.pinata_mode = false
	App.dance_mode = false
	App.daisy_mode = false
	App.sukhbir_mode = false
	App.game_mode = PvZ.GAMEMODE_ADVENTURE
	App.board_result = PvZ.BOARDRESULT_NONE
	App.app_rand_seed = int(msg.seed)

	_ui_rng = Tod.rng
	sim_rng = RandomNumberGenerator.new()
	sim_rng.seed = int(msg.seed)
	Tod.rng = sim_rng
	var shared_bank := mode == MODE_COOP and not level_uses_loadouts(lvl)
	App.kill_board()
	App.make_new_board()
	var board: Board = App.board
	board.net_setup(mode, teams, local_slot, shared_bank)
	board.init_level()
	board.draw_count = 1
	board.net_apply_loadouts(picks, shared_bank)
	for c in board.net_cursors:
		c.cursor_type = board.cursor_object.cursor_type  # whack-a-zombie starts everyone with a hammer
	if mode == MODE_VERSUS:
		NetVersus.setup_board(board)
	App.game_scene = PvZ.SCENE_LEVEL_INTRO
	board.cut_scene.start_level_intro()
	Tod.rng = _ui_rng

	overlay = NetGameOverlay.new()
	overlay.resize(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
	App.widget_manager.add_widget(overlay)
	App.widget_manager.bring_to_front(overlay)
	App.widget_manager.set_focus(board)

	var me := local_player()
	if not me.is_empty():
		me.loaded = true
	if is_host:
		_host_check_all_loaded()
	else:
		_send(1, {"t": "loaded"})
	if mode == MODE_VERSUS:
		var team := "PLANTS" if board.net_team_of(local_slot) == TEAM_PLANTS else "ZOMBIES"
		_sys("You are the %s! %s" % [team, "Destroy 3 target zombies to win." if team == "PLANTS" else "Get a zombie into the house to win."])

func _host_check_all_loaded() -> void:
	if not is_host or not match_active or _go:
		return
	if players.all(func(p): return p.loaded):
		_go = true

# ================================================================ frame loop
## Called once per 10 ms app update, before the widgets update.
func tick() -> void:
	if _peer == null and state == S_OFFLINE:
		return
	var now := Time.get_ticks_msec()
	if state == S_CONNECTING and now - _connect_started > CONNECT_TIMEOUT_MS:
		end_session("Couldn't reach the host (timed out). Check the IP address, port and that the host's firewall allows the game.")
		return
	if is_host:
		for id in _pending_hello.keys():
			if now - _pending_hello[id] > HELLO_TIMEOUT_MS:
				_pending_hello.erase(id)
				if _peer and _peer.get_peer(id):
					_peer.get_peer(id).peer_disconnect()
		if App.update_count % 100 == 0:
			_host_update_pings()
	if not match_active:
		return
	if not _go and now - _load_started > LOAD_TIMEOUT_MS:
		end_session("A player took too long to load the match.")
		return
	_send_cursor(now)
	_update_cursors()
	if is_host:
		if _go:
			_host_frame()
	else:
		_client_frames_step()
	_check_match_end()

func _host_frame() -> void:
	var frame := net_frame + 1
	var cmds := _host_queue
	_host_queue = []
	for c in cmds:
		_host_outgoing.append([frame, c[0], c[1], c[2], c[3]])
	_sim_step(frame, cmds)
	net_frame = frame
	if frame % FRAME_SEND_EVERY == 0 or not _host_outgoing.is_empty():
		_host_send_frames()

func _host_send_frames() -> void:
	_broadcast({"t": "f", "n": net_frame, "c": _host_outgoing})
	_host_outgoing = []

func _client_frames(msg: Dictionary) -> void:
	for c in msg.get("c", []):
		var f := int(c[0])
		if f <= net_frame:
			continue
		if not _client_cmds.has(f):
			_client_cmds[f] = []
		_client_cmds[f].append([int(c[1]), int(c[2]), int(c[3]), int(c[4])])
	allowed_frame = maxi(allowed_frame, int(msg.get("n", 0)))
	_go = true

func _client_frames_step() -> void:
	var behind := allowed_frame - net_frame
	var steps := 0
	if behind > 0:
		steps = 1
		if behind > 40:
			steps = mini(behind, 8)
		elif behind > 12:
			steps = 2
	stall_ticks = stall_ticks + 1 if steps == 0 and _go else 0
	for i in steps:
		if not match_active or App.board == null:
			return
		var frame := net_frame + 1
		var cmds: Array = _client_cmds.get(frame, [])
		_client_cmds.erase(frame)
		_sim_step(frame, cmds)
		net_frame = frame
	if _host_end_frame >= 0 and net_frame >= _host_end_frame and match_active:
		# give this board a moment to finish on its own, then follow the host
		if net_frame >= _host_end_frame + 50 or allowed_frame <= net_frame:
			_finish_match(_host_end_text)

func _sim_step(frame: int, cmds: Array) -> void:
	var board: Board = App.board
	if board == null:
		return
	var ui := Tod.rng
	Tod.rng = sim_rng
	board.process_delete_queue()
	EffectSystem.process_delete_queue()
	for c in cmds:
		var slot: int = c[0]
		if slot < 0 or slot >= board.net_banks.size():
			continue
		board.net_begin_exec(slot)
		board.mouse_down(c[1], c[2], c[3])
		board.net_end_exec()
	board.net_stepping = true
	board.update_all([])
	board.net_stepping = false
	Tod.rng = ui
	if frame % HASH_INTERVAL == 0 and App.board == board:
		var h := board_hash(board, frame)
		if debug_log_hashes:
			print("NETHASH %d %d" % [frame, h])
		if is_host:
			_host_hashes[frame] = h
			_host_hashes.erase(frame - HASH_INTERVAL * 30)
		else:
			_send(1, {"t": "h", "f": frame, "v": h})

func board_hash(board: Board, frame: int) -> int:
	var a: Array = [frame, board.sun_money, board.vs_zombie_sun, sim_rng.state, board.main_counter, App.game_scene]
	for p in board.plants:
		if not p.dead:
			a.append_array([p.seed_type, p.plant_col, p.row, p.plant_health])
	for z in board.zombies:
		if not z.dead:
			a.append_array([z.zombie_type, z.row, int(z.pos_x * 4.0), z.body_health, z.helm_health, z.shield_health])
	var coins := 0
	for c in board.coins:
		if not c.dead:
			coins += 1
	a.append(coins)
	return hash(a)

# ================================================================ desync recovery
func _host_check_hash(id: int, frame: int, value: int) -> void:
	if not _host_hashes.has(frame) or _host_hashes[frame] == value:
		return
	desync_count += 1
	var board: Board = App.board
	if board == null or App.game_scene != PvZ.SCENE_PLAYING or App.crazy_dave_state != PvZ.CRAZY_DAVE_OFF or board.board_fade_out_counter >= 0:
		return
	if _last_resync.has(id) and net_frame - int(_last_resync[id]) < RESYNC_COOLDOWN:
		return
	_last_resync[id] = net_frame
	var p := player_by_id(id)
	print("net: board of %s drifted at frame %d, sending a resync" % [p.get("name", id), frame])
	if not _host_outgoing.is_empty() or net_frame % FRAME_SEND_EVERY != 0:
		_host_send_frames()
	var data := SaveGame.snapshot_to_bytes(board)
	_send(id, {"t": "rs", "f": net_frame, "d": data, "rng": sim_rng.state, "scene": App.game_scene,
		"purchases": App.player_info.purchases.duplicate()})

func _client_resync(msg: Dictionary) -> void:
	if not match_active:
		return
	var root = SaveGame.snapshot_from_bytes(msg.get("d", PackedByteArray()))
	if root == null:
		return
	var ui := Tod.rng
	Tod.rng = RandomNumberGenerator.new()
	App.make_new_board()
	var board: Board = App.board
	var ok := SaveGame.apply_snapshot(board, root)
	Tod.rng = ui
	if not ok:
		end_session("Couldn't resynchronize with the host.")
		return
	board.net_relink(local_slot)
	board.menu_button.btn_no_draw = App.game_scene != PvZ.SCENE_PLAYING
	board.fast_button.btn_no_draw = true
	board.draw_count = maxi(board.draw_count, 1)
	sim_rng.state = int(msg.rng)
	App.game_scene = int(msg.scene)
	App.player_info.purchases = (msg.purchases as Array).duplicate()
	net_frame = int(msg.f)
	allowed_frame = maxi(allowed_frame, net_frame)
	for f in _client_cmds.keys():
		if f <= net_frame:
			_client_cmds.erase(f)
	resync_count += 1
	if overlay and overlay.widget_manager:
		App.widget_manager.bring_to_front(overlay)
	App.widget_manager.set_focus(board)

# ================================================================ local input during a match
## Board.mouse_down while online: menu button stays local, everything else becomes a queued click.
func local_board_click(board: Board, mx: int, my: int, click_count: int) -> void:
	if not match_active:
		return
	if board.menu_button.is_mouse_over() and click_count > 0 and not board.menu_button.btn_no_draw:
		open_menu()
		return
	queue_click(mx, my, click_count)

func queue_click(mx: int, my: int, click_count: int) -> void:
	if not match_active:
		return
	if is_host:
		if _go:
			_host_queue.append([local_slot, mx, my, click_count])
	else:
		_send(1, {"t": "cmd", "x": mx, "y": my, "c": click_count})

func board_key_down(board: Board, key: int) -> void:
	match key:
		WidgetManager.KEYCODE_RETURN:
			if overlay:
				overlay.open_chat()
		WidgetManager.KEYCODE_ESCAPE:
			if board.cursor_object.cursor_type != PvZ.CURSOR_TYPE_NORMAL and board.cursor_object.cursor_type != PvZ.CURSOR_TYPE_HAMMER:
				queue_click(0, 0, -1)
			else:
				open_menu()
		WidgetManager.KEYCODE_SPACE:
			if App.crazy_dave_state != PvZ.CRAZY_DAVE_OFF:
				queue_click(PvZ.BOARD_WIDTH / 2, PvZ.BOARD_HEIGHT / 2, 1)

## Seed bank keybinds (Options > bank keybinds) become clicks on the packet / shovel.
func board_key_char(board: Board, ch: String) -> void:
	if not App.bank_keybinds or App.game_scene != PvZ.SCENE_PLAYING or chat_open:
		return
	if ch.length() == 1 and ch >= "0" and ch <= "9":
		var idx := ch.unicode_at(0) - 0x30
		if App.zero_nine_bank_format:
			idx = 9 if idx == 0 else idx - 1
		else:
			idx -= 1
		if idx < 0 or idx >= board.seed_bank.num_packets:
			return
		var packet: SeedPacket = board.seed_bank.seed_packets[idx]
		if board.cursor_object.cursor_type != PvZ.CURSOR_TYPE_NORMAL:
			queue_click(0, 0, -1)
		if board.cursor_object.seed_bank_index != idx:
			queue_click(board.seed_bank.x + packet.x + packet.offset_x + 25, board.seed_bank.y + packet.y + 35, 1)
	elif ch.to_lower() == "s" and board.show_shovel:
		var r := board.get_shovel_button_rect()
		queue_click(r.position.x + r.size.x / 2, r.position.y + r.size.y / 2, 1)

func open_menu() -> void:
	if App.get_dialog(DIALOG_MENU):
		return
	App.play_sample("SOUND_PAUSE")
	var d := NetMenuDialog.new()
	App.center_dialog(d, d.width, d.height)
	App.add_dialog(DIALOG_MENU, d)
	App.widget_manager.set_focus(d)

## Auto-collect (QE option) online: the local player's hover sends a click instead of collecting directly.
func _auto_collect() -> void:
	var board: Board = App.board
	if board == null or App.game_scene != PvZ.SCENE_PLAYING or board.cursor_object.cursor_type != PvZ.CURSOR_TYPE_NORMAL:
		return
	if not (App.auto_collect_suns or App.auto_collect_coins):
		return
	var mx: int = App.widget_manager.last_mouse_x - board.x
	var my: int = App.widget_manager.last_mouse_y - board.y
	var zombie_team := board.is_versus() and board.net_team_of(local_slot) == TEAM_ZOMBIES
	for c in board.coins:
		if c.dead or c.is_being_collected or c.net_click_sent:
			continue
		if board.is_versus() and c.vs_zombie_sun != zombie_team:
			continue
		if not ((App.auto_collect_suns and c.is_sun()) or (App.auto_collect_coins and c.is_money())):
			continue
		if c.mouse_hit_test(mx, my, HitResult.new()):
			c.net_click_sent = true
			queue_click(mx, my, 1)
			return

# ================================================================ cursors
func _send_cursor(now: int) -> void:
	if now - _last_cursor_send < CURSOR_SEND_MS or App.board == null:
		return
	_last_cursor_send = now
	_auto_collect()
	var wm := App.widget_manager
	var cur := Vector3i(wm.last_mouse_x - App.board.x, wm.last_mouse_y - App.board.y, 1 if wm.mouse_in else 0)
	if cur == _last_cursor_sent:
		return
	_last_cursor_sent = cur
	var msg := {"t": "cur", "x": cur.x, "y": cur.y, "in": cur.z == 1}
	if is_host:
		msg["s"] = local_slot
		_broadcast(msg, true)
	else:
		_send(1, msg, true)

func _on_cursor(c: Array) -> void:
	var slot: int = c[0]
	if slot == local_slot:
		return
	if not cursors.has(slot):
		cursors[slot] = {"x": float(c[1]), "y": float(c[2]), "tx": float(c[1]), "ty": float(c[2]), "in": c[3]}
	var e: Dictionary = cursors[slot]
	e.tx = float(c[1])
	e.ty = float(c[2])
	e["in"] = c[3]

func _update_cursors() -> void:
	for slot in cursors:
		var e: Dictionary = cursors[slot]
		e.x = lerpf(e.x, e.tx, 0.35)
		e.y = lerpf(e.y, e.ty, 0.35)

## Drawn by the board (inside its UI layer) so cursors pan with the lawn.
func draw_board_overlay(board: Board, g: Graphics) -> void:
	if overlay:
		overlay.draw_remote_cursors(board, g)

# ================================================================ match end
func _check_match_end() -> void:
	var board: Board = App.board
	if board == null or not match_active:
		return
	if board.is_versus():
		if board.vs_winner == TEAM_PLANTS and board.vs_end_counter >= NetVersus.END_DELAY:
			_finish_match(_versus_result_text(TEAM_PLANTS))
		elif board.vs_winner == TEAM_ZOMBIES and App.game_scene == PvZ.SCENE_ZOMBIES_WON and board.cut_scene.is_cut_scene_over():
			_finish_match(_versus_result_text(TEAM_ZOMBIES))
		return
	if board.level_complete:
		_finish_match("%s complete! Nice teamwork." % level_name(board.level))
	elif App.game_scene == PvZ.SCENE_ZOMBIES_WON and board.cut_scene.is_cut_scene_over():
		_finish_match("The zombies ate your brains! (%s)" % level_name(board.level))

func _versus_result_text(winner: int) -> String:
	var names: Array = []
	for p in players:
		if p.team == winner:
			names.append(p.name)
	return "%s win! (%s)" % ["Plants" if winner == TEAM_PLANTS else "Zombies", ", ".join(names)]

func _finish_match(text: String) -> void:
	if not match_active:
		return
	if is_host:
		# clients may still be a few frames behind: send them the rest and the end marker
		_host_send_frames()
		_broadcast({"t": "matchend", "f": net_frame, "text": text})
	_end_match_local()
	_sys(text)
	_return_to_lobby(text)

func _end_match_local() -> void:
	match_active = false
	_go = false
	if Tod.rng == sim_rng and _ui_rng:
		Tod.rng = _ui_rng
	App.kill_dialog(DIALOG_MENU)
	if overlay and overlay.widget_manager:
		App.widget_manager.remove_widget(overlay)
	overlay = null
	chat_open = false
	App.kill_board()
	App.music.stop_all_music()
	App.sound_system.cancel_paused_foley()
	if not _saved.is_empty():
		App.player_info = _saved.player_info
		App.auto_collect_suns = _saved.auto_collect_suns
		App.auto_collect_coins = _saved.auto_collect_coins
		App.tod_cheat_keys = _saved.tod_cheat_keys
		App.debug_keys_enabled = _saved.debug_keys_enabled
		App.easy_planting_cheat = _saved.easy_planting_cheat
		App.app_rand_seed = _saved.app_rand_seed
		App.game_mode = _saved.game_mode
		App.playing_quickplay = _saved.playing_quickplay
		var m: Array = _saved.modes
		App.mustache_mode = m[0]
		App.super_mower_mode = m[1]
		App.future_mode = m[2]
		App.pinata_mode = m[3]
		App.dance_mode = m[4]
		App.daisy_mode = m[5]
		App.sukhbir_mode = m[6]
		_saved = {}
	App.game_scene = PvZ.SCENE_MENU

func _host_update_pings() -> void:
	if _peer == null:
		return
	var changed := false
	for p in players:
		if p.id == 1:
			continue
		var pp := _peer.get_peer(p.id)
		if pp:
			var rtt := int(pp.get_statistic(ENetPacketPeer.PEER_ROUND_TRIP_TIME))
			if rtt != p.ping:
				p.ping = rtt
				changed = true
	if changed and state == S_LOBBY:
		_broadcast_lobby()
