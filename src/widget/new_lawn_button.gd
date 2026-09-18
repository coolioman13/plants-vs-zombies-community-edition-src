class_name NewLawnButton
extends DialogButton
## Port of NewLawnButton.

var hilite_font: ImageFont
var text_down_offset_x := 0
var text_down_offset_y := 0
var button_offset_x := 0
var button_offset_y := 0
var use_polygon_shape := false
var polygon_shape: Array = []

func _init(comp_image: PvzImage = null, the_id: int = 0, the_listener: Object = null) -> void:
	super._init(comp_image, the_id, the_listener)
	set_color(COLOR_BKG, Color.WHITE)

func set_button_offset(ox: int, oy: int) -> void:
	button_offset_x = ox
	button_offset_y = oy

func draw(g: Graphics) -> void:
	if btn_no_draw:
		return
	var text := TodStrings.translate(label)
	var down := (is_down and is_over and not disabled) != inverted
	var fx := text_offset_x + translate_x
	var fy := text_offset_y + translate_y
	if font:
		if label_justify == BUTTON_LABEL_CENTER:
			fx += Tod.idiv(width - font.string_width(text), 2)
		elif label_justify == BUTTON_LABEL_RIGHT:
			fx += width - font.string_width(text)
		fy += Tod.idiv(height - Tod.idiv(font.get_ascent(), 6) + font.get_ascent() - 1, 2)
	g.colorize_images = true
	if not down:
		g.color = colors[COLOR_BKG]
		if disabled and have_button_image(disabled_image, disabled_rect):
			draw_button_image(g, disabled_image, disabled_rect, button_offset_x, button_offset_y)
		elif over_alpha > 0.0 and have_button_image(over_image, over_rect):
			if have_button_image(button_image, normal_rect) and over_alpha < 1.0:
				draw_button_image(g, button_image, normal_rect, button_offset_x, button_offset_y)
			g.color.a8 = int(over_alpha * 255)
			draw_button_image(g, over_image, over_rect, button_offset_x, button_offset_y)
		elif (is_over or is_down) and have_button_image(over_image, over_rect):
			draw_button_image(g, over_image, over_rect, button_offset_x, button_offset_y)
		elif have_button_image(button_image, normal_rect):
			draw_button_image(g, button_image, normal_rect, button_offset_x, button_offset_y)
		g.colorize_images = false
		if is_over:
			g.font = hilite_font if hilite_font else font
			g.color = colors[COLOR_LABEL_HILITE]
		else:
			g.font = font
			g.color = colors[COLOR_LABEL]
		if g.font:
			g.draw_string(text, fx, fy)
	else:
		g.color = colors[COLOR_BKG]
		if have_button_image(down_image, down_rect):
			draw_button_image(g, down_image, down_rect, button_offset_x + translate_x, button_offset_y + translate_y)
		elif have_button_image(over_image, over_rect):
			draw_button_image(g, over_image, over_rect, button_offset_x + translate_x, button_offset_y + translate_y)
		else:
			draw_button_image(g, button_image, normal_rect, button_offset_x + translate_x, button_offset_y + translate_y)
		g.colorize_images = false
		g.font = hilite_font if hilite_font else font
		g.color = colors[COLOR_LABEL_HILITE]
		if g.font:
			g.draw_string(text, fx + text_down_offset_x, fy + text_down_offset_y)

func is_point_visible(px: int, py: int) -> bool:
	if not use_polygon_shape:
		return super.is_point_visible(px, py)
	return Tod.is_point_in_polygon(polygon_shape, Vector2(px, py))
