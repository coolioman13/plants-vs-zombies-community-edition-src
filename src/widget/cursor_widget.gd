class_name CursorWidget
extends Widget
## Port of Sexy::CursorWidget: draws IMAGE_MOUSE_CURSOR at the mouse when the "Custom Cursor" advanced option is on.

var image: PvzImage = null
var draw_cursor := false

func _init() -> void:
	mouse_visible = false

func draw(g: Graphics) -> void:
	if image != null and draw_cursor:
		g.draw_image(image, 0, 0)

func set_image(img: PvzImage) -> void:
	image = img
	if image != null:
		resize(x, y, image.width, image.height)

func update() -> void:
	super.update()
	if image == null:
		set_image(Res.get_image("IMAGE_MOUSE_CURSOR"))
	x = widget_manager.last_mouse_x if widget_manager else 0
	y = widget_manager.last_mouse_y if widget_manager else 0
	draw_cursor = App.cursor_num != App.CURSOR_NONE and App.custom_cursor
