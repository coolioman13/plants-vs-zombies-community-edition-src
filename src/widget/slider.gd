class_name SexySlider
extends Widget
## Port of Sexy::Slider.

var track_image: PvzImage
var thumb_image: PvzImage
var id := 0
var listener: Object
var val := 0.0
var dragging := false
var horizontal := true
var rel_x := 0
var rel_y := 0
var thumb_offset_x := 0
var no_draw := false

func _init(track: PvzImage = null, thumb: PvzImage = null, the_id: int = 0, the_listener: Object = null) -> void:
	track_image = track
	thumb_image = thumb
	id = the_id
	listener = the_listener

func set_value(v: float) -> void:
	val = clampf(v, 0.0, 1.0)

func draw(g: Graphics) -> void:
	if no_draw:
		return
	slider_draw(g)

## Slider::SliderDraw. Screens that draw their own slider (no_draw) call this with their own Graphics,
## so it offsets by the slider position itself and skips hidden sliders.
func slider_draw(g: Graphics) -> void:
	if no_draw:
		if not visible:
			return
		g.translate(x, y)
	if track_image != null:
		var cw := Tod.idiv(track_image.width, 3) if horizontal else track_image.width
		var ch := track_image.height if horizontal else Tod.idiv(track_image.height, 3)
		if horizontal:
			var ty := Tod.idiv(height - ch, 2)
			g.draw_image_src(track_image, 0, ty, Rect2(0, 0, cw, ch))
			var cg := g.copy()
			cg.clip_rect(cw, ty, width - cw * 2, ch)
			for i in Tod.idiv(width - cw * 2 + cw - 1, cw):
				cg.draw_image_src(track_image, cw + i * cw, ty, Rect2(cw, 0, cw, ch))
			g.draw_image_src(track_image, width - cw, ty, Rect2(cw * 2, 0, cw, ch))
		else:
			g.draw_image_src(track_image, 0, 0, Rect2(0, 0, cw, ch))
			var cg2 := g.copy()
			cg2.clip_rect(0, ch, cw, height - ch * 2)
			for i in Tod.idiv(height - ch * 2 + ch - 1, ch):
				cg2.draw_image_src(track_image, 0, ch + i * ch, Rect2(0, ch, cw, ch))
			g.draw_image_src(track_image, 0, height - ch, Rect2(0, ch * 2, cw, ch))
	g.clear_clip_rect()
	if horizontal and thumb_image != null:
		g.draw_image(thumb_image, int(val * (width - thumb_image.width)) + thumb_offset_x, Tod.idiv(height - thumb_image.height, 2))
	elif not horizontal and thumb_image != null:
		g.draw_image(thumb_image, Tod.idiv(width - thumb_image.width, 2) + thumb_offset_x, int(val * (height - thumb_image.height)))
	g.translate(-x, -y)

func mouse_down(mx: int, my: int, _count: int) -> void:
	if horizontal:
		var tx := int(val * (width - thumb_image.width)) + thumb_offset_x
		if mx >= tx and mx < tx + thumb_image.width:
			App.set_cursor(App.CURSOR_DRAGGING)
			dragging = true
			rel_x = mx - tx
		else:
			set_value(float(mx) / width)
	else:
		var tyy := int(val * (height - thumb_image.height))
		var tcx := Tod.idiv(width - thumb_image.width, 2) + thumb_offset_x
		if mx >= tcx and mx < tcx + thumb_image.width and my >= tyy and my < tyy + thumb_image.height:
			App.set_cursor(App.CURSOR_DRAGGING)
			dragging = true
			rel_y = my - tyy
		else:
			set_value(float(my) / height)

func mouse_move(mx: int, my: int) -> void:
	if horizontal:
		var tx := int(val * (width - thumb_image.width)) + thumb_offset_x
		App.set_cursor(App.CURSOR_DRAGGING if (mx >= tx and mx < tx + thumb_image.width) else App.CURSOR_POINTER)
	else:
		var tyy := int(val * (height - thumb_image.height))
		var tcx := Tod.idiv(width - thumb_image.width, 2) + thumb_offset_x
		var over := mx >= tcx and mx < tcx + thumb_image.width and my >= tyy and my < tyy + thumb_image.height
		App.set_cursor(App.CURSOR_DRAGGING if over else App.CURSOR_POINTER)

func mouse_drag(mx: int, my: int) -> void:
	if dragging:
		var old := val
		if horizontal:
			val = (mx - rel_x) / float(width - thumb_image.width)
		else:
			val = (my - rel_y) / float(height - thumb_image.height)
		val = clampf(val, 0.0, 1.0)
		if val != old and listener and listener.has_method("slider_val"):
			listener.slider_val(id, val)

func mouse_up(_mx: int, _my: int, _count: int) -> void:
	dragging = false
	App.set_cursor(App.CURSOR_POINTER)
	if listener and listener.has_method("slider_val"):
		listener.slider_val(id, val)

func mouse_leave() -> void:
	if not dragging:
		App.set_cursor(App.CURSOR_POINTER)
