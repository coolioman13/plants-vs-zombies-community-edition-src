class_name DialogButton
extends ButtonWidget
## Port of Sexy::DialogButton.

var component_image: PvzImage
var text_offset_x := 0
var text_offset_y := 0
var translate_x := 1
var translate_y := 1

func _init(comp_image: PvzImage = null, the_id: int = 0, the_listener: Object = null) -> void:
	super._init(the_id, the_listener)
	component_image = comp_image
	do_finger = true
	set_colors([[255, 255, 255], [255, 255, 255], [0, 0, 0], [255, 255, 255], [132, 132, 132], [212, 212, 212]])

func draw(g: Graphics) -> void:
	if btn_no_draw:
		return
	if component_image == null:
		super.draw(g)
		return
	var text := TodStrings.translate(label)
	var do_translate := is_button_down()
	if normal_rect.size.x == 0:
		if do_translate:
			g.translate(translate_x, translate_y)
		g.draw_image_box(Rect2(0, 0, width, height), component_image)
	else:
		if disabled and disabled_rect.size.x > 0 and disabled_rect.size.y > 0:
			g.draw_image_box_src(Rect2(disabled_rect), Rect2(0, 0, width, height), component_image)
		elif is_button_down():
			g.draw_image_box_src(Rect2(down_rect), Rect2(0, 0, width, height), component_image)
		elif over_alpha > 0:
			if over_alpha < 1:
				g.draw_image_box_src(Rect2(normal_rect), Rect2(0, 0, width, height), component_image)
			g.colorize_images = true
			g.color = Color8(255, 255, 255, int(over_alpha * 255))
			g.draw_image_box_src(Rect2(over_rect), Rect2(0, 0, width, height), component_image)
			g.colorize_images = false
		elif is_over:
			g.draw_image_box_src(Rect2(over_rect), Rect2(0, 0, width, height), component_image)
		else:
			g.draw_image_box_src(Rect2(normal_rect), Rect2(0, 0, width, height), component_image)
		if do_translate:
			g.translate(translate_x, translate_y)
	if font != null:
		g.font = font
		g.color = colors[COLOR_LABEL_HILITE] if is_over else colors[COLOR_LABEL]
		var fx := Tod.idiv(width - font.string_width(text), 2)
		var fy := Tod.idiv(height + font.get_ascent() - font.get_ascent_padding() - Tod.idiv(font.get_ascent(), 6) - 1, 2)
		g.draw_string(text, fx + text_offset_x, fy + text_offset_y)
	if do_translate:
		g.translate(-translate_x, -translate_y)
