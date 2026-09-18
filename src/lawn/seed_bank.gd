class_name SeedBank
extends GameObject
## Port of SeedBank (the packet tray and the conveyor belt).

var num_packets := 0
var seed_packets: Array = []
var cut_scene_darken := 255
var conveyor_belt_counter := 0
## Online Versus: which team this bank belongs to (zombie banks use the purple sun pool).
var net_team := 0

func _init() -> void:
	var img := Res.get_image("IMAGE_SEEDBANK")
	width = img.width
	height = img.height
	for i in PvZ.SEEDBANK_MAX:
		seed_packets.append(SeedPacket.new())

func move(nx: int, ny: int) -> void:
	x = nx
	y = ny

func draw(g: Graphics) -> void:
	var board: Board = App.board
	if board.cut_scene and board.cut_scene.is_before_preloading():
		return
	if App.game_scene != PvZ.SCENE_PLAYING:
		g.trans_x -= board.x
		g.trans_y -= board.y
	var zombie_bank := board.is_versus() and net_team == NetSession.TEAM_ZOMBIES
	if zombie_bank:
		board.net_swap_sun(true)
	var bank := Res.get_image("IMAGE_SEEDBANK")
	if App.is_slot_machine_level():
		g.draw_image(Res.get_image("IMAGE_SUNBANK"), 0, 0)
	elif board.has_conveyor_belt_seed_bank():
		g.draw_image(Res.get_image("IMAGE_CONVEYORBELT_BACKDROP"), 83, 0)
		g.draw_image_cel(Res.get_image("IMAGE_CONVEYORBELT"), 90, 63, Tod.idiv(conveyor_belt_counter, 4) % 6)
		g.set_clip_rect(90, 0, 501, PvZ.BOARD_HEIGHT)
	else:
		var extra := board.get_seed_bank_extra_width()
		if zombie_bank:
			g.colorize_images = true
			g.color = Color8(196, 150, 255)
		g.draw_image(bank, 0, 0)
		g.draw_image_src(bank, bank.width - 12, 0, Rect2(bank.width - extra - 12, 0, extra + 12, bank.height))
		g.colorize_images = false
	for i in num_packets:
		var p: SeedPacket = seed_packets[i]
		if p.packet_type != PvZ.SEED_NONE and p.begin_draw(g):
			p.draw(g)
			p.end_draw(g)
	g.clear_clip_rect()
	if App.is_slot_machine_level() and y > -bank.height:
		g.draw_image(Res.get_image("IMAGE_SLOTMACHINE_OVERLAY"), 189, -2)
	if not board.has_conveyor_belt_seed_bank():
		var money_color := Color.BLACK
		if board.out_of_money_counter > 0 and board.out_of_money_counter % 20 < 10:
			money_color = Color8(255, 0, 0)
		TodStrings.draw_string(g, str(maxi(board.sun_money, 0)), 34, 78, Res.get_font("FONT_CONTINUUMBOLD14"), money_color, TodStrings.DS_ALIGN_CENTER)
	if zombie_bank:
		board.net_swap_sun(false)
	if App.game_scene != PvZ.SCENE_PLAYING:
		g.trans_x += board.x
		g.trans_y += board.y

func mouse_hit_test(mx: int, my: int, hit: HitResult) -> bool:
	if mx - x <= width - 5 and num_packets > 0:
		for p in seed_packets:
			if p.mouse_hit_test(mx - x, my - y, hit):
				return true
	hit.clear()
	return false

func contains_point(px: int, py: int) -> bool:
	return px >= x and px < x + width and py >= y and py < y + height

func add_seed(seed_type: int, place_on_left: bool = false) -> void:
	var n := get_num_seeds_on_conveyor_belt()
	if n == num_packets:
		return
	var p: SeedPacket = seed_packets[n]
	p.packet_type = seed_type
	p.refresh_counter = 0
	p.refresh_time = 0
	p.refreshing = false
	p.active = true
	p.offset_x = 515 - (PvZ.SEED_PACKET_WIDTH + 1) * n
	if place_on_left:
		p.offset_x = 0
	if n > 0:
		var prev: SeedPacket = seed_packets[n - 1]
		if p.offset_x < prev.offset_x:
			p.offset_x = prev.offset_x + 40

func remove_seed(idx: int) -> void:
	for i in range(idx, num_packets):
		var p: SeedPacket = seed_packets[i]
		if p.packet_type == PvZ.SEED_NONE:
			break
		if i == num_packets - 1:
			p.packet_type = PvZ.SEED_NONE
			p.offset_x = 0
		else:
			var nxt: SeedPacket = seed_packets[i + 1]
			p.packet_type = nxt.packet_type
			p.offset_x = nxt.offset_x + PvZ.SEED_PACKET_WIDTH + 1
		p.refresh_counter = 0
		p.refresh_time = 0
		p.refreshing = false
		p.active = true

func get_num_seeds_on_conveyor_belt() -> int:
	for i in num_packets:
		if seed_packets[i].packet_type == PvZ.SEED_NONE:
			return i
	return num_packets

func count_of_type_on_conveyor_belt(seed_type: int) -> int:
	var c := 0
	for i in num_packets:
		if seed_packets[i].packet_type == seed_type:
			c += 1
	return c

func update_conveyor_belt() -> void:
	conveyor_belt_counter += 1
	if conveyor_belt_counter % SeedPacket.CONVEYOR_SPEED == 0:
		for i in num_packets:
			var p: SeedPacket = seed_packets[i]
			if p.offset_x > 0:
				p.offset_x = maxi(p.offset_x - 1, 0)
		App.board.update_tool_tip()

func update_width() -> void:
	var board: Board = App.board
	num_packets = board.get_num_seeds_in_bank()
	width = Res.get_image("IMAGE_SEEDBANK").width + board.get_seed_bank_extra_width()
	for i in num_packets:
		seed_packets[i].x = board.get_seed_packet_position_x(i)

func refresh_all_packets() -> void:
	for i in num_packets:
		var p: SeedPacket = seed_packets[i]
		if p.packet_type == PvZ.SEED_NONE:
			break
		if p.refreshing:
			p.refresh_counter = 0
			p.refreshing = false
			p.active = true
			p.flash_if_ready()
