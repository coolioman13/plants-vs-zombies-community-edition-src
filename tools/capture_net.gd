extends Node
## Windowed screenshots of the multiplayer screens with a pretend second player (no second game needed).
## godot --path . res://tools/capture_net.tscn -- <output_dir>

var out_dir := "user://captures"

func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		out_dir = args[0]
	DirAccess.make_dir_recursive_absolute(out_dir)
	App.set_process(false)
	await get_tree().process_frame
	await _run()
	get_tree().quit()

func _pump(updates: int) -> void:
	for i in updates:
		App._run_loading_tasks()
		App.update_frames()

func _shot(file_name: String) -> void:
	App._draw_frame()
	await RenderingServer.frame_post_draw
	App._draw_frame()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(out_dir.path_join(file_name + ".png"))
	print("captured ", file_name)

func _pump_until_playing(limit: int) -> void:
	var n := 0
	while App.game_scene != PvZ.SCENE_PLAYING and n < limit:
		_pump(10)
		n += 10

func _run() -> void:
	while not App.loading_thread_completed:
		_pump(10)
		App._draw_frame()
		await get_tree().process_frame
	var profile := PlayerInfo.new()   # in memory only
	profile.name = "Dave"
	profile.id = 95
	profile.finished_adventure = 1
	profile.level = 1
	profile.purchases[PvZ.STORE_ITEM_PACKET_UPGRADE] = 2
	App.player_info = profile
	App.widget_manager.on_mouse_move(-100, -100)
	App.loading_completed()
	_pump(200)
	await _shot("net_01_menu_social")

	var gs: GameSelector = App.game_selector
	gs.button_depress(GameSelector.GAMESELECTOR_SOCIAL)
	_pump(10)
	await _shot("net_02_connect_dialog")
	App.kill_dialog(NetSession.DIALOG_CONNECT)

	var net: NetSession = App.net
	net.host(NetSession.DEFAULT_PORT + 20)
	# pretend a friend joined (id 1 so nothing is sent anywhere)
	var friend := net._new_player(1, 1, "Zomboss_99")
	friend.ping = 34
	net.players.append(friend)
	net._add_chat("Zomboss_99 joined the lobby.", NetUi.TEXT_SYSTEM, true)
	net._add_chat("Zomboss_99: hey! ready for some co-op?", NetSession.player_color(1), false)
	net._add_chat("Dave: yeah, pick night levels", NetSession.player_color(0), false)
	net.host_set_level(12)
	_pump(20)
	await _shot("net_03_lobby_coop")
	net.host_set_mode(NetSession.MODE_VERSUS)
	_pump(5)
	await _shot("net_04_lobby_versus")
	net.host_set_mode(NetSession.MODE_COOP)

	net.host_start_game()
	_pump(10)
	friend.picks = [PvZ.SEED_PUFFSHROOM, PvZ.SEED_SUNSHROOM, PvZ.SEED_FUMESHROOM, PvZ.SEED_GRAVEBUSTER]
	for st in [PvZ.SEED_PEASHOOTER, PvZ.SEED_SUNFLOWER, PvZ.SEED_WALLNUT, PvZ.SEED_CHERRYBOMB]:
		net.request_pick(st)
	_pump(10)
	App.widget_manager.on_mouse_move(97, 180)
	_pump(3)
	await _shot("net_05_chooser_coop")

	# finish picks and start the co-op match
	for st in [PvZ.SEED_SNOWPEA, PvZ.SEED_CHOMPER, PvZ.SEED_REPEATER, PvZ.SEED_POTATOMINE]:
		net.request_pick(st)
	friend.picks = [PvZ.SEED_PUFFSHROOM, PvZ.SEED_SUNSHROOM, PvZ.SEED_FUMESHROOM, PvZ.SEED_GRAVEBUSTER,
		PvZ.SEED_HYPNOSHROOM, PvZ.SEED_SCAREDYSHROOM, PvZ.SEED_ICESHROOM, PvZ.SEED_DOOMSHROOM]
	friend.ready = true
	net.request_ready_state(true)
	_pump(2)
	friend.loaded = true
	net._host_check_all_loaded()
	App.widget_manager.on_mouse_move(-100, -100)
	_pump(40)
	await _shot("net_06_coop_intro")
	_pump_until_playing(6000)
	var board: Board = App.board
	board.sun_money = 400
	# friend plants a few things, host too
	net._host_queue.append([1, board.seed_bank.x + 100, 40, 1])   # friend's packet slot 1 (sun-shroom)
	_pump(2)
	net._host_queue.append([1, board.grid_to_pixel_x(1, 1) + 40, board.grid_to_pixel_y(1, 1) + 40, 1])
	_pump(2)
	net.queue_click(board.seed_bank.x + board.seed_bank.seed_packets[1].x + 25, 40, 1)
	_pump(2)
	net.queue_click(board.grid_to_pixel_x(0, 2) + 40, board.grid_to_pixel_y(0, 2) + 40, 1)
	_pump(2)
	net._host_queue.append([1, board.seed_bank.x + board.seed_bank.seed_packets[2].x + 25, 40, 1])   # friend holds fume-shroom
	_pump(300)
	net.cursors[1] = {"x": 700.0, "y": 380.0, "tx": 700.0, "ty": 380.0, "in": true}
	net._add_chat("Zomboss_99: I'll cover the top lanes", NetSession.player_color(1), false)
	App.widget_manager.on_mouse_move(420, 300)
	_pump(2)
	await _shot("net_07_coop_playing")
	net.overlay.open_chat()
	net.overlay.chat_edit.set_text("nice, thanks!")
	_pump(2)
	await _shot("net_08_coop_chat")
	net.overlay.close_chat()
	net.open_menu()
	_pump(5)
	await _shot("net_09_ingame_menu")
	App.kill_dialog(NetSession.DIALOG_MENU)

	# ---------------------------------------------------------------- versus
	net._finish_match("Level 2-2 complete! Nice teamwork.")
	_pump(5)
	await _shot("net_10_lobby_after_match")
	friend.in_lobby = true
	net.host_set_mode(NetSession.MODE_VERSUS)
	net.host_start_game()
	_pump(5)
	await _shot("net_11_chooser_versus_plants")
	for st in [PvZ.SEED_PEASHOOTER, PvZ.SEED_SUNFLOWER, PvZ.SEED_WALLNUT, PvZ.SEED_REPEATER, PvZ.SEED_SNOWPEA, PvZ.SEED_POTATOMINE, PvZ.SEED_CHOMPER, PvZ.SEED_SQUASH]:
		net.request_pick(st)
	friend.picks = [NetVersus.SEED_GRAVE, PvZ.SEED_ZOMBIE_NORMAL, PvZ.SEED_ZOMBIE_TRAFFIC_CONE, PvZ.SEED_ZOMBIE_PAIL,
		PvZ.SEED_ZOMBIE_POLEVAULTER, PvZ.SEED_ZOMBIE_FOOTBALL, PvZ.SEED_ZOMBIE_SCREEN_DOOR, PvZ.SEED_ZOMBIE_IMP]
	friend.ready = true
	net.request_ready_state(true)
	_pump(2)
	friend.loaded = true
	net._host_check_all_loaded()
	_pump_until_playing(6000)
	board = App.board
	board.vs_zombie_sun = 500
	board.sun_money = 400
	# zombies: a grave and some zombies
	var zb: SeedBank = board.net_banks[1]
	for step in [[0, 6, 1], [0, 7, 3], [1, 6, 0], [3, 7, 2], [2, 6, 4]]:
		var pk: SeedPacket = zb.seed_packets[step[0]]
		zb.seed_packets[step[0]].refreshing = false
		zb.seed_packets[step[0]].active = true
		net._host_queue.append([1, zb.x + pk.x + 25, 40, 1])
		_pump(2)
		net._host_queue.append([1, board.grid_to_pixel_x(step[1], step[2]) + 40, board.grid_to_pixel_y(step[1], step[2]) + 40, 1])
		_pump(2)
	for step in [[0, 1, 0], [3, 2, 1], [1, 0, 2], [2, 2, 3]]:
		var pk2: SeedPacket = board.seed_bank.seed_packets[step[0]]
		net.queue_click(board.seed_bank.x + pk2.x + 25, 40, 1)
		_pump(2)
		net.queue_click(board.grid_to_pixel_x(step[1], step[2]) + 40, board.grid_to_pixel_y(step[1], step[2]) + 40, 1)
		_pump(2)
	_pump(900)
	net.cursors[1] = {"x": 900.0, "y": 300.0, "tx": 900.0, "ty": 300.0, "in": true}
	net._host_queue.append([1, zb.x + zb.seed_packets[5].x + 25, 40, 1])
	_pump(3)
	await _shot("net_12_versus_playing")
	# plants win screen
	for z in board.vs_targets:
		z.take_damage(5000, 0)
	_pump(150)
	await _shot("net_13_versus_plants_win")
	net.end_session("")
	_pump(5)
