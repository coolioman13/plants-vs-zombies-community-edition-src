extends Node
## One side of the two-process multiplayer test (run through tools/net_test.py, which starts both sides):
##   godot --headless --path . res://tools/net_test.tscn -- host|client <port> coop|versus <seconds>
## Both sides auto-play (packets, planting, sun) and print NETHASH lines; the harness compares them.

var role := "host"
var port := NetSession.DEFAULT_PORT + 7
var test_mode := "coop"
var seconds := 40
var rng := RandomNumberGenerator.new()
var phase := "loading"
var phase_ms := 0
var action_tick := 0
var pending_place := false
var chat_seen := false
var start_ms := 0
var both_in_lobby_ms := 0
var corrupt := false
var corrupted := false
var variant := ""

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: role = args[0]
	if args.size() > 1: port = int(args[1])
	if args.size() > 2: test_mode = args[2]
	if args.size() > 3: seconds = int(args[3])
	if args.size() > 4:
		variant = args[4]
		corrupt = variant == "corrupt"
	rng.seed = 1234 if role == "host" else 5678
	start_ms = Time.get_ticks_msec()
	App.set_process(false)
	await get_tree().process_frame
	while not App.loading_thread_completed:
		for i in 10:
			App._run_loading_tasks()
			App.update_frames()
		App._draw_frame()
		await get_tree().process_frame
	var profile := PlayerInfo.new()   # in memory only, never saved
	profile.name = "NetHost" if role == "host" else "NetClient"
	profile.id = 90 if role == "host" else 91
	profile.finished_adventure = 1
	profile.level = 1
	profile.purchases[PvZ.STORE_ITEM_PACKET_UPGRADE] = 2
	App.player_info = profile
	App.loading_completed()
	App.net.debug_log_hashes = true
	App.set_process(true)
	_set_phase("connect")

func _set_phase(p: String) -> void:
	phase = p
	phase_ms = Time.get_ticks_msec()
	print("PHASE ", role, " ", p)

func _fail(msg: String) -> void:
	print("FAIL ", role, ": ", msg)
	get_tree().quit(1)

func _process(_delta: float) -> void:
	if phase == "loading" or phase == "done":
		return
	var net: NetSession = App.net
	var elapsed := Time.get_ticks_msec() - phase_ms
	if Time.get_ticks_msec() - start_ms > (seconds + 60) * 1000:
		_fail("test timed out in phase " + phase)
		return
	match phase:
		"connect":
			var err := net.host(port) if role == "host" else net.join("localhost", port)
			if err != "":
				_fail(err)
				return
			_set_phase("lobby")
		"lobby":
			if net.state == NetSession.S_OFFLINE:
				_fail("disconnected in lobby")
				return
			if net.players.size() == 2 and net.state == NetSession.S_LOBBY:
				if not chat_seen:
					chat_seen = true
					both_in_lobby_ms = Time.get_ticks_msec()
					net.send_chat("hello from " + role)
				if role == "host" and Time.get_ticks_msec() - both_in_lobby_ms > 2500:
					var found := net.chat_log.any(func(e): return str(e.text).contains("hello from client"))
					print("PASS chat reached host: ", found)
					net.host_set_mode(NetSession.MODE_VERSUS if test_mode == "versus" else NetSession.MODE_COOP)
					net.host_set_level(12)
					net.host_start_game()
					_set_phase("choose")
				elif role == "client" and net.state == NetSession.S_CHOOSING:
					_set_phase("choose")
			if role == "client" and net.state == NetSession.S_CHOOSING:
				_set_phase("choose")
		"choose":
			if net.match_active:
				_set_phase("play")
				return
			if net.state != NetSession.S_CHOOSING or elapsed < 500:
				return
			var me := net.local_player()
			var list := net.seed_list_for(net.local_slot)
			if me.picks.size() < int(net.choose_info.slots):
				var order := list.duplicate()
				if role == "client":
					order.reverse()
				for st in order:
					if not (st in me.picks) and (test_mode == "versus" or net.seed_owner(st) == -1):
						net.request_pick(st)
						break
			elif not me.ready:
				net.request_ready_state(true)
		"play":
			if not net.match_active:
				if variant == "clientleave" and role == "host":
					_set_phase("await_end")
					return
				_fail("match ended early (state %d)" % net.state)
				return
			action_tick += 1
			if corrupt and role == "client" and not corrupted and net.net_frame > 1500 and App.game_scene == PvZ.SCENE_PLAYING:
				corrupted = true
				App.board.sun_money += 7
				print("CORRUPTED client board at frame ", net.net_frame)
			if action_tick % 12 == 0:
				_auto_play(net)
			# the client joins a little after the host, so it wraps up first
			if elapsed > (seconds - 4 if role == "client" else seconds) * 1000:
				var b: Board = App.board
				var plants := b.plants.filter(func(q): return not q.dead).size()
				var zombies := b.zombies.filter(func(q): return not q.dead).size()
				print("RESULT ", role, " frame=", net.net_frame, " resyncs=", net.resync_count, " host_desyncs=", net.desync_count,
					" plants=", plants, " zombies=", zombies, " sun=", b.sun_money, " zombie_sun=", b.vs_zombie_sun, " targets_destroyed=", NetVersus.targets_destroyed(b) if b.is_versus() else -1)
				if variant == "clientleave":
					if role == "client":
						net.leave()
						_set_phase("done")
						await get_tree().create_timer(1.5).timeout
						get_tree().quit(0)
					else:
						_set_phase("await_end")
				elif variant == "hostend":
					if role == "host":
						net._finish_match("Test match over")
						_set_phase("await_lobby_return")
					else:
						_set_phase("await_lobby")
				elif role == "host":
					net.leave()
					_set_phase("done")
					await get_tree().create_timer(1.5).timeout
					get_tree().quit(0)
				else:
					_set_phase("await_end")
		"await_lobby":
			if net.state == NetSession.S_LOBBY and not net.match_active:
				print("PASS client followed the host back to the lobby: ", net.lobby_notice)
				_set_phase("await_end")
			elif elapsed > 15000:
				_fail("client stayed in the match after the host ended it")
		"await_lobby_return":
			var other := net.player_by_slot(1)
			if not other.is_empty() and other.in_lobby:
				print("PASS host saw the client return to the lobby")
				net.leave()
				_set_phase("done")
				await get_tree().create_timer(1.5).timeout
				get_tree().quit(0)
			elif elapsed > 15000:
				_fail("client never came back to the lobby")
		"await_end":
			if net.state == NetSession.S_OFFLINE:
				print("PASS ", role, " returned to the menu after the other player left: ", App.game_selector != null, " message: ", App.get_dialog(PvZ.DIALOG_MESSAGE) != null)
				_set_phase("done")
				get_tree().quit(0)
			elif elapsed > 15000:
				_fail(role + " never noticed the other player leaving")

func _auto_play(net: NetSession) -> void:
	var board: Board = App.board
	if board == null or App.game_scene != PvZ.SCENE_PLAYING:
		return
	var zombie := board.is_versus() and board.net_team_of(net.local_slot) == NetSession.TEAM_ZOMBIES
	if pending_place:
		pending_place = false
		var gx := rng.randi_range(NetVersus.ZOMBIE_MIN_COL, 7) if zombie else rng.randi_range(0, 4 if board.is_versus() else 8)
		var gy := rng.randi_range(0, 4)
		net.queue_click(board.grid_to_pixel_x(gx, gy) + 40, board.grid_to_pixel_y(gx, gy) + 40, 1)
		return
	for c in board.coins:
		if c.dead or c.is_being_collected or not c.is_sun():
			continue
		if board.is_versus() and c.vs_zombie_sun != zombie:
			continue
		net.queue_click(int(c.pos_x) + 30, int(c.pos_y) + 30, 1)
		return
	var bank := board.seed_bank
	if bank.num_packets == 0:
		return
	var idx := rng.randi() % bank.num_packets
	var p: SeedPacket = bank.seed_packets[idx]
	net.queue_click(bank.x + p.x + p.offset_x + 25, bank.y + p.y + 35, 1)
	pending_place = true
