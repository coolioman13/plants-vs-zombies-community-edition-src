class_name Checkbox
extends Widget
## Port of Sexy::Checkbox.

var id := 0
var listener: Object
var checked := false
var unchecked_image: PvzImage
var checked_image: PvzImage
var checked_rect := Rect2i()
var unchecked_rect := Rect2i()

func _init(unchecked_img: PvzImage = null, checked_img: PvzImage = null, the_id: int = 0, the_listener: Object = null) -> void:
	unchecked_image = unchecked_img
	checked_image = checked_img
	id = the_id
	listener = the_listener
	do_finger = true

func set_checked(c: bool, tell_listener: bool = true) -> void:
	checked = c
	if tell_listener and listener and listener.has_method("checkbox_checked"):
		listener.checkbox_checked(id, checked)

func is_checked() -> bool:
	return checked

func draw(g: Graphics) -> void:
	if checked_rect.size.x == 0 and checked_image != null and unchecked_image != null:
		g.draw_image(checked_image if checked else unchecked_image, 0, 0)
	elif checked_rect.size.x != 0 and unchecked_image != null:
		g.draw_image_src(unchecked_image, 0, 0, Rect2(checked_rect if checked else unchecked_rect))
	elif unchecked_image == null and checked_image == null:
		g.color = Color.WHITE
		g.fill_rect(0, 0, width, height)
		g.color = Color8(80, 80, 80)
		g.fill_rect(1, 1, width - 2, height - 2)
		if checked:
			g.color = Color8(255, 255, 0)
			g.draw_line(1, 1, width - 2, height - 2)
			g.draw_line(width - 1, 1, 1, height - 2)

func mouse_down_btn(_mx: int, _my: int, _btn: int, _count: int) -> void:
	checked = not checked
	if listener and listener.has_method("checkbox_checked"):
		listener.checkbox_checked(id, checked)
