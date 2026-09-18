class_name CursorObject
extends GameObject
## Port of CursorObject: the plant / tool that follows the mouse.

var seed_bank_index := -1
var type := PvZ.SEED_NONE
var imitater_type := PvZ.SEED_NONE
var cursor_type := PvZ.CURSOR_TYPE_NORMAL
var coin: Coin = null
var glove_plant: Plant = null
var duplicator_plant: Plant = null
var cob_cannon_plant: Plant = null
var hammer_down_counter := 0
var reanim_cursor: Reanimation = null

func _init() -> void:
	width = 80
	height = 80

func update() -> void:
	var board: Board = App.board
	if App.game_scene != PvZ.SCENE_PLAYING and not board.cut_scene.is_in_shovel_tutorial():
		visible = false
		return
	if not App.widget_manager.mouse_in:
		visible = false
		return
	if reanim_cursor != null and not reanim_cursor.freed:
		reanim_cursor.update()
	visible = true
	x = App.widget_manager.last_mouse_x - 25
	y = App.widget_manager.last_mouse_y - 35

func die() -> void:
	if reanim_cursor != null and not reanim_cursor.freed:
		reanim_cursor.die()
	reanim_cursor = null

func draw(g: Graphics) -> void:
	var board: Board = App.board
	match cursor_type:
		PvZ.CURSOR_TYPE_SHOVEL:
			g.draw_image(Res.get_image("IMAGE_SHOVEL"), 10, -30)
		PvZ.CURSOR_TYPE_WATERING_CAN:
			if App.player_info.purchases[PvZ.STORE_ITEM_GOLD_WATERINGCAN] != 0:
				g.draw_image(Res.get_image("IMAGE_ZEN_GOLDTOOLRETICLE"), -62, -37)
				g.draw_image(Res.get_image("IMAGE_WATERINGCANGOLD"), -3, 12)
			else:
				g.draw_image(Res.get_image("IMAGE_WATERINGCAN"), -3, 12)
		PvZ.CURSOR_TYPE_FERTILIZER:
			g.draw_image(Res.get_image("IMAGE_FERTILIZER"), -15, 0)
		PvZ.CURSOR_TYPE_BUG_SPRAY:
			g.draw_image(Res.get_image("IMAGE_BUG_SPRAY"), -9, -1)
		PvZ.CURSOR_TYPE_PHONOGRAPH:
			g.draw_image(Res.get_image("IMAGE_PHONOGRAPH"), -17, 10)
		PvZ.CURSOR_TYPE_CHOCOLATE:
			g.draw_image(Res.get_image("IMAGE_CHOCOLATE"), -2, -8)
		PvZ.CURSOR_TYPE_GLOVE:
			g.draw_image(Res.get_image("IMAGE_ZEN_GARDENGLOVE"), -17, 15)
		PvZ.CURSOR_TYPE_MONEY_SIGN:
			g.draw_image(Res.get_image("IMAGE_ZEN_MONEYSIGN"), -17, -10)
		PvZ.CURSOR_TYPE_TREE_FOOD:
			g.draw_image(Res.get_image("IMAGE_TREEFOOD"), -15, 0)
		PvZ.CURSOR_TYPE_WHEEELBARROW:
			var pp = App.zen_garden.get_potted_plant_in_wheelbarrow()
			if pp:
				g.draw_image(Res.get_image("IMAGE_ZEN_WHEELBARROW"), -20, -23)
				if pp.plant_age == PvZ.PLANTAGE_SMALL:
					App.zen_garden.draw_potted_plant(g, 10.0, -35.0, pp, 0.6, true)
				elif pp.plant_age == PvZ.PLANTAGE_MEDIUM:
					App.zen_garden.draw_potted_plant(g, 15.0, -25.0, pp, 0.5, true)
				else:
					App.zen_garden.draw_potted_plant(g, 21.0, -15.0, pp, 0.4, true)
			else:
				g.draw_image(Res.get_image("IMAGE_ZEN_WHEELBARROW"), -20, -30)
		PvZ.CURSOR_TYPE_PLANT_FROM_GLOVE, PvZ.CURSOR_TYPE_PLANT_FROM_WHEEL_BARROW:
			var pp
			if cursor_type == PvZ.CURSOR_TYPE_PLANT_FROM_GLOVE:
				pp = App.player_info.potted_plants[glove_plant.potted_plant_index]
			else:
				pp = App.zen_garden.get_potted_plant_in_wheelbarrow()
			if board.background == PvZ.BACKGROUND_MUSHROOM_GARDEN or board.background == PvZ.BACKGROUND_ZOMBIQUARIUM:
				App.zen_garden.draw_potted_plant(g, -10.0, -10.0, pp, 1.0, false)
			else:
				App.zen_garden.draw_potted_plant(g, -22.0, -38.0, pp, 1.0, true)
		PvZ.CURSOR_TYPE_PLANT_FROM_BANK, PvZ.CURSOR_TYPE_PLANT_FROM_USABLE_COIN, PvZ.CURSOR_TYPE_PLANT_FROM_DUPLICATOR:
			var ox := -10.0
			var oy := Plant.plant_draw_height_offset(board, null, type, -1, -1) - 10.0
			if Plant.is_flying(type) or type == PvZ.SEED_GRAVEBUSTER:
				oy += 30.0
			oy -= 15.0
			Plant.draw_seed_type(g, type, imitater_type, PvZ.VARIATION_NORMAL, ox, oy)
		PvZ.CURSOR_TYPE_HAMMER:
			if reanim_cursor:
				reanim_cursor.draw(g)
		PvZ.CURSOR_TYPE_COBCANNON_TARGET:
			var hit := HitResult.new()
			board.mouse_hit_test(board.prev_mouse_x, board.prev_mouse_y, hit)
			if hit.object_type == PvZ.OBJECT_TYPE_NONE and board.prev_mouse_y >= 80:
				g.draw_image_cel(Res.get_image("IMAGE_COBCANNON_TARGET"), -11, 7, 0)
