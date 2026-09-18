class_name ButtonWidget
extends Widget
## Port of Sexy::ButtonWidget (+ DialogButton behaviour when component_image is set).

enum { COLOR_LABEL, COLOR_LABEL_HILITE, COLOR_DARK_OUTLINE, COLOR_LIGHT_OUTLINE, COLOR_MEDIUM_OUTLINE, COLOR_BKG }
enum { BUTTON_LABEL_LEFT = -1, BUTTON_LABEL_CENTER = 0, BUTTON_LABEL_RIGHT = 1 }

var id := 0
var label := ""
var label_justify := BUTTON_LABEL_CENTER
var font: ImageFont
var button_image: PvzImage
var over_image: PvzImage
var down_image: PvzImage
var disabled_image: PvzImage
var normal_rect := Rect2i()
var over_rect := Rect2i()
var down_rect := Rect2i()
var disabled_rect := Rect2i()
var inverted := false
var btn_no_draw := false
var frame_no_draw := false
var listener: Object
var over_alpha := 0.0
var over_alpha_speed := 0.0
var over_alpha_fade_in_speed := 0.0

func _init(the_id: int = 0, the_listener: Object = null) -> void:
	id = the_id
	listener = the_listener
	set_colors([[0, 0, 0], [0, 0, 0], [0, 0, 0], [255, 255, 255], [132, 132, 132], [212, 212, 212]])

func set_font(f: ImageFont) -> void:
	font = f

func is_button_down() -> bool:
	return is_down and is_over and not disabled

static func have_button_image(img: PvzImage, r: Rect2i) -> bool:
	return img != null or r.size.x != 0

func draw_button_image(g: Graphics, img: PvzImage, r: Rect2i, px: int, py: int) -> void:
	if r.size.x != 0:
		g.draw_image_src(button_image, px, py, Rect2(r))
	else:
		g.draw_image(img, px, py)

func draw(g: Graphics) -> void:
	if btn_no_draw:
		return
	var text := TodStrings.translate(label)
	var down := (is_down and is_over and not disabled) != inverted
	var fx := 0
	var fy := 0
	if font != null:
		if label_justify == BUTTON_LABEL_CENTER:
			fx = Tod.idiv(width - font.string_width(text), 2)
		elif label_justify == BUTTON_LABEL_RIGHT:
			fx = width - font.string_width(text)
		fy = Tod.idiv(height + font.get_ascent() - Tod.idiv(font.get_ascent(), 6) - 1, 2)
	g.font = font
	if button_image == null and down_image == null:
		if not frame_no_draw:
			g.color = colors[COLOR_BKG]
			g.fill_rect(0, 0, width, height)
		g.color = colors[COLOR_LABEL_HILITE] if is_over else colors[COLOR_LABEL]
		if font:
			g.draw_string(text, fx + (1 if down else 0), fy + (1 if down else 0))
		return
	if not down:
		if disabled and have_button_image(disabled_image, disabled_rect):
			draw_button_image(g, disabled_image, disabled_rect, 0, 0)
		elif over_alpha > 0 and have_button_image(over_image, over_rect):
			if have_button_image(button_image, normal_rect) and over_alpha < 1:
				draw_button_image(g, button_image, normal_rect, 0, 0)
			g.colorize_images = true
			g.color = Color8(255, 255, 255, int(over_alpha * 255))
			draw_button_image(g, over_image, over_rect, 0, 0)
			g.colorize_images = false
		elif (is_over or is_down) and have_button_image(over_image, over_rect):
			draw_button_image(g, over_image, over_rect, 0, 0)
		elif have_button_image(button_image, normal_rect):
			draw_button_image(g, button_image, normal_rect, 0, 0)
		g.color = colors[COLOR_LABEL_HILITE] if is_over else colors[COLOR_LABEL]
		if font:
			g.draw_string(text, fx, fy)
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

func mouse_enter() -> void:
	if over_alpha_fade_in_speed == 0 and over_alpha > 0:
		over_alpha = 0
	if listener and listener.has_method("button_mouse_enter"):
		listener.button_mouse_enter(id)

func mouse_leave() -> void:
	if over_alpha_speed == 0 and over_alpha > 0:
		over_alpha = 0
	elif over_alpha_speed > 0 and over_alpha == 0:
		over_alpha = 1
	if listener and listener.has_method("button_mouse_leave"):
		listener.button_mouse_leave(id)

func mouse_move(mx: int, my: int) -> void:
	if listener and listener.has_method("button_mouse_move"):
		listener.button_mouse_move(id, mx, my)

func mouse_down_btn(_mx: int, _my: int, _btn: int, count: int) -> void:
	if listener and listener.has_method("button_press"):
		listener.button_press(id, count)

func mouse_up_btn(_mx: int, _my: int, _btn: int, _count: int) -> void:
	if is_over and widget_manager and widget_manager.app_has_focus:
		if listener and listener.has_method("button_depress"):
			listener.button_depress(id)

func update() -> void:
	super.update()
	if is_down and is_over and listener and listener.has_method("button_down_tick"):
		listener.button_down_tick(id)
	if not is_down and not is_over and over_alpha > 0:
		if over_alpha_speed > 0:
			over_alpha = maxf(over_alpha - over_alpha_speed, 0)
		else:
			over_alpha = 0
	elif is_over and over_alpha_fade_in_speed > 0 and over_alpha < 1:
		over_alpha = minf(over_alpha + over_alpha_fade_in_speed, 1)
