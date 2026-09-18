class_name LawnButtons
## GameButton.cpp helpers: stone buttons, NewLawnButton factory, and the non-widget GameButton.

static func draw_stone_button(g: Graphics, px: int, py: int, w: int, h: int, down: bool, highlighted: bool, label: String, brightness: int = 255) -> void:
	var left := Res.get_image("IMAGE_BUTTON_LEFT")
	var middle := Res.get_image("IMAGE_BUTTON_MIDDLE")
	var right := Res.get_image("IMAGE_BUTTON_RIGHT")
	var fx := px
	var fy := py
	var ix := px
	if down:
		left = Res.get_image("IMAGE_BUTTON_DOWN_LEFT")
		middle = Res.get_image("IMAGE_BUTTON_DOWN_MIDDLE")
		right = Res.get_image("IMAGE_BUTTON_DOWN_RIGHT")
		fx += 1
		fy += 1
		ix += 1
	var old_color := g.color
	g.colorize_images = true
	g.color = Color8(brightness, brightness, brightness)
	g.draw_image(left, ix, py)
	ix += left.width
	var repeat := Tod.idiv(w - left.width - right.width, middle.width)
	for i in repeat:
		g.draw_image(middle, ix, py)
		ix += middle.width
	var remaining := w - left.width - right.width - repeat * middle.width
	if remaining > 0:
		g.draw_image_scaled_size(middle, ix, py, remaining, middle.height)
		ix += remaining
	g.draw_image(right, ix, py)
	var green := Res.get_font("FONT_DWARVENTODCRAFT18GREENINSET")
	g.font = Res.get_font("FONT_DWARVENTODCRAFT18BRIGHTGREENINSET") if highlighted else green
	var lw := green.string_width(label)
	var asc := green.get_ascent()
	fx += Tod.idiv(w - lw, 2) + 1
	fy += Tod.idiv(h - Tod.idiv(asc, 6) - 1 + asc, 2) - 4
	g.draw_string(label, fx, fy)
	g.color = old_color
	g.colorize_images = false

static func make_button(the_id: int, the_listener: Object, text: String) -> LawnStoneButton:
	var b := LawnStoneButton.new(null, the_id, the_listener)
	b.label = text
	b.translate_x = 1
	b.translate_y = 1
	b.height = 33
	return b

static func make_new_button(the_id: int, the_listener: Object, text: String, font: ImageFont, normal: PvzImage, over: PvzImage, down: PvzImage) -> NewLawnButton:
	var b := NewLawnButton.new(null, the_id, the_listener)
	b.set_font(font if font != null else Res.get_font("FONT_BRIANNETOD12"))
	b.label = text
	b.width = normal.width
	b.height = normal.height
	b.button_image = normal
	b.down_image = down
	b.over_image = over
	b.translate_x = 1
	b.translate_y = 1
	return b

static func make_new_checkbox(the_id: int, the_listener: Object, default: bool) -> Checkbox:
	var c := Checkbox.new(Res.get_image("IMAGE_OPTIONS_CHECKBOX0"), Res.get_image("IMAGE_OPTIONS_CHECKBOX1"), the_id, the_listener)
	c.checked = default
	return c

static func draw_edit_box(g: Graphics, w: Widget) -> void:
	g.draw_image_box(Rect2(w.x - 8, w.y - 4, w.width + 16, w.height + 8), Res.get_image("IMAGE_EDITBOX"))
