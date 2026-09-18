class_name CursorPreview
extends GameObject
## Port of CursorPreview: the translucent plant shown on the tile under the mouse.

var grid_x := 0
var grid_y := 0

func _init() -> void:
	visible = false
	width = 80
	height = 80

func update() -> void:
	var board: Board = App.board
	if App.game_scene != PvZ.SCENE_PLAYING and not board.cut_scene.is_in_shovel_tutorial():
		visible = false
		return
	var seed_type := board.get_seed_type_in_cursor()
	var mx: int = App.widget_manager.last_mouse_x
	var my: int = App.widget_manager.last_mouse_y
	grid_x = board.planting_pixel_to_grid_x(mx, my, seed_type)
	grid_y = board.planting_pixel_to_grid_y(mx, my, seed_type)
	if grid_x >= 0 and grid_x < BoardCore.MAX_GRID_SIZE_X and grid_y >= 0 and grid_y <= BoardCore.MAX_GRID_SIZE_Y:
		var show := false
		if board.is_plant_in_cursor() and board.can_plant_at(grid_x, grid_y, seed_type) == PvZ.PLANTING_OK:
			show = true
		elif board.cursor_object.cursor_type == PvZ.CURSOR_TYPE_WHEEELBARROW:
			if App.zen_garden.get_potted_plant_in_wheelbarrow() and board.can_plant_at(grid_x, grid_y, seed_type) == PvZ.PLANTING_OK:
				show = true
		if show:
			x = board.grid_to_pixel_x(grid_x, grid_y)
			y = board.grid_to_pixel_y(grid_x, grid_y)
			visible = true
			return
	visible = false

func draw(g: Graphics) -> void:
	var board: Board = App.board
	var seed_type := board.get_seed_type_in_cursor()
	if seed_type == PvZ.SEED_NONE:
		return
	g.colorize_images = true
	g.color = Color8(255, 255, 255, 100)
	var pp = null
	var ct := board.cursor_object.cursor_type
	if ct == PvZ.CURSOR_TYPE_WHEEELBARROW or ct == PvZ.CURSOR_TYPE_PLANT_FROM_WHEEL_BARROW:
		pp = App.zen_garden.get_potted_plant_in_wheelbarrow()
	elif ct == PvZ.CURSOR_TYPE_PLANT_FROM_GLOVE:
		pp = App.player_info.potted_plants[board.cursor_object.glove_plant.potted_plant_index]
	if pp:
		var draw_pot := not (board.background == PvZ.BACKGROUND_MUSHROOM_GARDEN or board.background == PvZ.BACKGROUND_ZOMBIQUARIUM)
		App.zen_garden.draw_potted_plant(g, 0.0, 0.0, pp, 1.0, draw_pot)
	else:
		var oy := Plant.plant_draw_height_offset(board, null, seed_type, grid_x, grid_y)
		Plant.draw_seed_type(g, board.cursor_object.type, board.cursor_object.imitater_type, PvZ.VARIATION_NORMAL, 0.0, oy)
	g.colorize_images = false
