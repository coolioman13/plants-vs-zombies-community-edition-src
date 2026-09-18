class_name GameButton
extends RefCounted
## Port of GameButton: a light-weight button drawn/updated manually by its owner (Board, SeedChooser ...).

enum { COLOR_LABEL, COLOR_LABEL_HILITE, COLOR_DARK_OUTLINE, COLOR_LIGHT_OUTLINE, COLOR_MEDIUM_OUTLINE, COLOR_BKG }
enum { BUTTON_LABEL_LEFT = -1, BUTTON_LABEL_CENTER = 0, BUTTON_LABEL_RIGHT = 1 }

var id := 0
var label := ""
var label_justify := 0
var font: ImageFont
var button_image: PvzImage
var over_image: PvzImage
var down_image: PvzImage
var disabled_image: PvzImage
var over_overlay_image: PvzImage
var normal_rect := Rect2i()
var over_rect := Rect2i()
var down_rect := Rect2i()
var disabled_rect := Rect2i()
var inverted := false
var btn_no_draw := false
var frame_no_draw := false
var is_over := false
var is_down := false
var disabled := false
var x := 0
var y := 0
var width := 0
var height := 0
var parent_widget: Widget
var draw_stone_button := false
var text_offset_x := 0
var text_offset_y := 0
var button_offset_x := 0
var button_offset_y := 0
var over_alpha := 0.0
var over_alpha_speed := 0.0
var over_alpha_fade_in_speed := 0.0
var colors := [Color8(0, 0, 0), Color8(0, 0, 0), Color8(0, 0, 0), Color8(255, 255, 255), Color8(132, 132, 132), Color8(212, 212, 212)]

func _init(the_id: int = 0) -> void:
	id = the_id

func set_disabled(d: bool) -> void:
	disabled = d

func set_font(f: ImageFont) -> void:
	font = f

func resize(nx: int, ny: int, w: int, h: int) -> void:
	x = nx
	y = ny
	width = w
	height = h

func is_button_down() -> bool:
	return is_down and is_over and not disabled and not btn_no_draw

func is_mouse_over() -> bool:
	return is_over and not disabled and not btn_no_draw

static func have_button_image(img: PvzImage, r: Rect2i) -> bool:
	return img != null or r.size.x != 0

func draw_button_image(g: Graphics, img: PvzImage, r: Rect2i, px: int, py: int) -> void:
	var ax := px + button_offset_x
	var ay := py + button_offset_y
	if r.size.x != 0:
		g.draw_image_src(button_image, ax, ay, Rect2(r))
	else:
		g.draw_image(img, ax, ay)

func draw(g: Graphics) -> void:
	if btn_no_draw:
		return
	var text := TodStrings.translate(label)
	var down := is_button_down() != inverted
	var hi := is_mouse_over()
	if draw_stone_button:
		LawnButtons.draw_stone_button(g, x, y, width, height, down, hi, text)
		return
	g.trans_x += x
	g.trans_y += y
	var fx := text_offset_x
	var fy := text_offset_y
	if font:
		if label_justify == BUTTON_LABEL_CENTER:
			fx += Tod.idiv(width - font.string_width(text), 2)
		elif label_justify == BUTTON_LABEL_RIGHT:
			fx += width - font.string_width(text)
		fy += Tod.idiv(height - Tod.idiv(font.get_ascent(), 6) + font.get_ascent() - 1, 2)
	g.font = font
	if not down:
		if disabled and have_button_image(disabled_image, disabled_rect):
			draw_button_image(g, disabled_image, disabled_rect, 0, 0)
		elif over_alpha > 0.0 and have_button_image(over_image, over_rect):
			if have_button_image(button_image, normal_rect) and over_alpha < 1.0:
				draw_button_image(g, button_image, normal_rect, 0, 0)
			g.colorize_images = true
			g.color = Color8(255, 255, 255, int(over_alpha * 255))
			draw_button_image(g, over_image, over_rect, 0, 0)
			g.colorize_images = false
		elif hi and have_button_image(over_image, over_rect):
			draw_button_image(g, over_image, over_rect, 0, 0)
		elif have_button_image(button_image, normal_rect):
			draw_button_image(g, button_image, normal_rect, 0, 0)
		g.color = colors[COLOR_LABEL_HILITE if hi else COLOR_LABEL]
		if font:
			g.draw_string(text, fx, fy)
		if hi and over_overlay_image:
			g.draw_mode = Graphics.DRAWMODE_ADDITIVE
			draw_button_image(g, over_overlay_image, normal_rect, 0, 0)
			g.draw_mode = Graphics.DRAWMODE_NORMAL
	else:
		if have_button_image(down_image, down_rect):
			draw_button_image(g, down_image, down_rect, 0, 0)
		elif have_button_image(over_image, over_rect):
			draw_button_image(g, over_image, over_rect, 1, 1)
		else:
			draw_button_image(g, button_image, normal_rect, 1, 1)
		g.color = colors[COLOR_LABEL_HILITE]
		if font:
			g.draw_string(text, fx + 1, fy + 1)
		if hi and over_overlay_image:
			g.draw_mode = Graphics.DRAWMODE_ADDITIVE
			draw_button_image(g, over_overlay_image, normal_rect, 0, 0)
			g.draw_mode = Graphics.DRAWMODE_NORMAL
	g.translate(-x, -y)

func update() -> void:
	var wm: WidgetManager = App.widget_manager
	var mx := wm.last_mouse_x
	var my := wm.last_mouse_y
	if parent_widget:
		var ap := parent_widget.get_abs_pos()
		mx -= ap.x
		my -= ap.y
	if (wm.focus_widget != null and wm.focus_widget == parent_widget) or App.get_dialog_count() <= 0:
		is_over = Rect2i(x, y, width, height).has_point(Vector2i(mx, my))
		is_down = (wm.down_buttons & 5) != 0
	else:
		is_over = false
		is_down = false
	if not is_down and not is_over and over_alpha > 0:
		if over_alpha_speed < 0:
			over_alpha = 0
			return
		over_alpha = maxf(over_alpha - over_alpha_speed, 0)
	elif is_over and over_alpha_fade_in_speed > 0 and over_alpha < 1:
		over_alpha = minf(over_alpha + over_alpha_fade_in_speed, 1)
