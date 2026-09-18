class_name EditorUi
## Widgets and drawing helpers for the level editor, built from the game's own art so the editor
## reads as part of Plants vs. Zombies rather than a tool bolted on to it: stone buttons, the
## almanac's parchment panels, seed packets, the options checkbox and slider, and the game fonts.

const TEXT_DARK := Color8(42, 42, 90)
const TEXT_BROWN := Color8(90, 55, 20)
const TEXT_HEADER := Color8(120, 70, 25)
const TEXT_GOLD := Color8(224, 187, 98)
const TEXT_CREAM := Color8(255, 246, 214)
const TEXT_DIM := Color8(150, 140, 120)
const TEXT_GREEN := Color8(126, 198, 60)
const TEXT_RED := Color8(216, 96, 80)
const PANEL_SHADE := Color(0, 0, 0, 0.42)
const SLOT_FILL := Color8(58, 44, 30, 190)
const SLOT_FILL_HOVER := Color8(86, 66, 44, 210)
const SLOT_EDGE := Color8(28, 20, 12, 220)
const SELECT_EDGE := Color8(255, 220, 120)

static func font_small() -> ImageFont: return Res.get_font("FONT_BRIANNETOD12")
static func font_body() -> ImageFont: return Res.get_font("FONT_BRIANNETOD16")
static func font_head() -> ImageFont: return Res.get_font("FONT_DWARVENTODCRAFT18")
static func font_title() -> ImageFont: return Res.get_font("FONT_DWARVENTODCRAFT24")
## The font LawnButtons.draw_stone_button prints its label in.
static func font_button() -> ImageFont: return Res.get_font("FONT_DWARVENTODCRAFT18GREENINSET")

## Width a stone button needs so its label is not clipped by the stone end caps.
static func button_width(text: String) -> int:
	return font_button().string_width(TodStrings.translate(text)) + 34

## Width a control caption needs before its value box starts.
static func caption_width(text: String) -> int:
	return font_body().string_width(text) + 12 if text != "" else 0

## Numbers the way a person writes them: 1 rather than 1.0, 1.5 rather than 1.500000.
static func num_text(v) -> String:
	if typeof(v) == TYPE_INT:
		return str(v)
	if typeof(v) == TYPE_FLOAT:
		var f := float(v)
		if is_equal_approx(f, round(f)):
			return str(int(round(f)))
		return String.num(f, 2).rstrip("0").rstrip(".")
	return str(v)

# ================================================================ drawing helpers
## Stretchable stone dialog frame (the LawnDialog pieces, scaled for smaller panels).
static func draw_frame(g: Graphics, r: Rect2, scale: float = 0.5) -> void:
	var tl := Res.get_image("IMAGE_DIALOG_TOPLEFT")
	var tm := Res.get_image("IMAGE_DIALOG_TOPMIDDLE")
	var tr := Res.get_image("IMAGE_DIALOG_TOPRIGHT")
	var cl := Res.get_image("IMAGE_DIALOG_CENTERLEFT")
	var cm := Res.get_image("IMAGE_DIALOG_CENTERMIDDLE")
	var cr := Res.get_image("IMAGE_DIALOG_CENTERRIGHT")
	var bl := Res.get_image("IMAGE_DIALOG_BOTTOMLEFT")
	var bm := Res.get_image("IMAGE_DIALOG_BOTTOMMIDDLE")
	var br := Res.get_image("IMAGE_DIALOG_BOTTOMRIGHT")
	if tl == null or cm == null:
		g.color = Color8(40, 30, 20, 230)
		g.fill_rect_r(r)
		return
	var lw := tl.width * scale
	var rw := tr.width * scale
	var th := tl.height * scale
	var bh := bl.height * scale
	var mw := maxf(r.size.x - lw - rw, 1.0)
	var mh := maxf(r.size.y - th - bh, 1.0)
	var x0 := r.position.x
	var y0 := r.position.y
	var xm := x0 + lw
	var xr := xm + mw
	var ym := y0 + th
	var yb := ym + mh
	g.draw_image_stretch(tl, Rect2(x0, y0, lw, th), Rect2(0, 0, tl.width, tl.height))
	g.draw_image_stretch(tm, Rect2(xm, y0, mw, th), Rect2(0, 0, tm.width, tm.height))
	g.draw_image_stretch(tr, Rect2(xr, y0, rw, th), Rect2(0, 0, tr.width, tr.height))
	g.draw_image_stretch(cl, Rect2(x0, ym, lw, mh), Rect2(0, 0, cl.width, cl.height))
	g.draw_image_stretch(cm, Rect2(xm, ym, mw, mh), Rect2(0, 0, cm.width, cm.height))
	g.draw_image_stretch(cr, Rect2(xr, ym, rw, mh), Rect2(0, 0, cr.width, cr.height))
	g.draw_image_stretch(bl, Rect2(x0, yb, lw, bh), Rect2(0, 0, bl.width, bl.height))
	g.draw_image_stretch(bm, Rect2(xm, yb, mw, bh), Rect2(0, 0, bm.width, bm.height))
	g.draw_image_stretch(br, Rect2(xr, yb, rw, bh), Rect2(0, 0, br.width, br.height))

## The almanac's parchment sheet, used for the big content panels.
static func draw_parchment(g: Graphics, r: Rect2) -> void:
	var img := Res.get_image("IMAGE_ALMANAC_PLANTBACK")
	if img == null:
		g.color = Color8(214, 186, 134)
		g.fill_rect_r(r)
		return
	g.draw_image_stretch(img, r, Rect2(0, 0, img.width, img.height))

static func draw_text(g: Graphics, text: String, x: int, y: int, font: ImageFont, color: Color,
		align: int = TodStrings.DS_ALIGN_LEFT) -> void:
	TodStrings.draw_string(g, text, x + 1, y + 1, font, Color(0, 0, 0, color.a * 0.75), align)
	TodStrings.draw_string(g, text, x, y, font, color, align)

static func draw_plain(g: Graphics, text: String, x: int, y: int, font: ImageFont, color: Color,
		align: int = TodStrings.DS_ALIGN_LEFT) -> void:
	TodStrings.draw_string(g, text, x, y, font, color, align)

static func draw_shade(g: Graphics, r: Rect2, alpha: float = 0.42) -> void:
	g.color = Color(0, 0, 0, alpha)
	g.fill_rect_r(r)

## A sunken slot: the look used for value boxes, list rows and grid cells.
static func draw_slot(g: Graphics, r: Rect2, hover: bool = false, selected: bool = false) -> void:
	g.color = SLOT_FILL_HOVER if hover else SLOT_FILL
	g.fill_rect_r(r)
	g.color = SELECT_EDGE if selected else SLOT_EDGE
	g.draw_rect(r.position.x, r.position.y, r.size.x - 1, r.size.y - 1)
	if selected:
		g.draw_rect(r.position.x + 1, r.position.y + 1, r.size.x - 3, r.size.y - 3)

static func wrap_text(text: String, font: ImageFont, max_w: int) -> Array:
	var out: Array = []
	for para in text.split("\n"):
		var cur := ""
		for word in str(para).split(" "):
			var cand := word if cur == "" else cur + " " + word
			if font.string_width(cand) <= max_w or cur == "":
				cur = cand
			else:
				out.append(cur)
				cur = word
		out.append(cur)
	return out

static func draw_wrapped(g: Graphics, text: String, r: Rect2i, font: ImageFont, color: Color) -> int:
	var y := r.position.y + font.get_ascent()
	var line_h := font.get_line_spacing() + 1
	for line in wrap_text(text, font, r.size.x):
		if y > r.end.y:
			break
		draw_plain(g, line, r.position.x, y, font, color)
		y += line_h
	return y - r.position.y

static func elide(text: String, font: ImageFont, max_w: int) -> String:
	if font.string_width(text) <= max_w:
		return text
	var out := text
	while out.length() > 1 and font.string_width(out + "...") > max_w:
		out = out.substr(0, out.length() - 1)
	return out + "..."

## A plant portrait with its feet at (x, y), scaled. Works for custom plants too.
## Preview reanims live inside a panel box, so every track has to respect the clip - a few of the
## game's animations (Dr. Zomboss above all) opt out of it to cover the whole board.
static func tame_preview(r: Reanimation) -> void:
	if r == null or r.freed:
		return
	for ti in r.track_instances:
		ti.ignore_clip_rect = false

## World-space bounds of everything a reanim is drawing this frame, with its overlay matrix
## taken out, so callers can frame it however they like. Returns an empty rect if it draws nothing.
static func preview_bounds(r: Reanimation) -> Rect2:
	var saved := r.overlay_matrix
	r.overlay_matrix = Transform2D.IDENTITY
	var lo := Vector2(INF, INF)
	var hi := Vector2(-INF, -INF)
	var t := Reanimation.Transform.new()
	for i in r.track_instances.size():
		var ti: Reanimation.TrackInstance = r.track_instances[i]
		if ti.render_group != Reanimation.RENDER_GROUP_NORMAL:
			continue
		r.get_current_transform(i, t)
		if t.image == null or Tod.round_to_int(t.frame) < 0 or t.alpha <= 0.0:
			continue
		var m := r.get_track_matrix(i)
		var hw := t.image.get_cel_width() * 0.5
		@warning_ignore("integer_division")
		var hh := (t.image.height / t.image.num_rows) * 0.5
		for c in [Vector2(-hw, -hh), Vector2(hw, -hh), Vector2(-hw, hh), Vector2(hw, hh)]:
			var w: Vector2 = m.origin + m.basis_xform(c)
			lo = Vector2(minf(lo.x, w.x), minf(lo.y, w.y))
			hi = Vector2(maxf(hi.x, w.x), maxf(hi.y, w.y))
	r.overlay_matrix = saved
	if lo.x > hi.x:
		return Rect2()
	return Rect2(lo, hi - lo)

## Scales and centres a preview reanim so all of it lands inside [param box], never magnifying
## past [param max_scale]. Falls back to the given scale while the animation has nothing to show.
static func fit_preview(r: Reanimation, box: Rect2, max_scale: float = 1.0, pad: float = 8.0) -> void:
	if r == null or r.freed:
		return
	var b := preview_bounds(r)
	if b.size.x <= 0.0 or b.size.y <= 0.0:
		r.overlay_matrix = Transform2D(Vector2(max_scale, 0), Vector2(0, max_scale),
			box.position + box.size * 0.5)
		return
	var sc := minf(max_scale, minf((box.size.x - pad * 2) / b.size.x, (box.size.y - pad * 2) / b.size.y))
	var centre := box.position + box.size * 0.5
	r.overlay_matrix = Transform2D(Vector2(sc, 0), Vector2(0, sc),
		centre - (b.position + b.size * 0.5) * sc)

## Counts, healths and costs: plain thousands separators, not the money format.
static func thousands(v: int) -> String:
	var s := str(absi(v))
	var out := ""
	while s.length() > 3:
		out = "," + s.substr(s.length() - 3) + out
		s = s.substr(0, s.length() - 3)
	return ("-" if v < 0 else "") + s + out

static func draw_plant_portrait(g: Graphics, seed_type: int, x: float, y: float, scale: float,
		tint: Color = Color.WHITE) -> void:
	var sg := g.copy()
	sg.scale_x = scale
	sg.scale_y = scale
	if tint != Color.WHITE:
		sg.color = tint
		sg.colorize_images = true
	Plant.draw_seed_type(sg, seed_type, PvZ.SEED_NONE, PvZ.VARIATION_NORMAL, x - 40.0 * scale, y - 78.0 * scale)

static func draw_zombie_portrait(g: Graphics, zombie_type: int, x: float, y: float, scale: float) -> void:
	var sg := g.copy()
	sg.scale_x = scale
	sg.scale_y = scale
	ReanimatorCache.draw_cached_zombie(sg, x - 70.0 * scale, y - 120.0 * scale, zombie_type)

static func draw_seed_packet(g: Graphics, seed_type: int, x: float, y: float, scale: float,
		greyed: bool = false) -> void:
	var sg := g.copy()
	sg.scale_x = scale
	sg.scale_y = scale
	SeedPacket.draw_seed_packet(sg, x, y, seed_type, PvZ.SEED_NONE, 0.0, 128 if greyed else 255, true, false)

# ================================================================ widgets
class StoneButton:
	extends DialogButton
	## Stone button that greys out when disabled and can carry a tooltip.
	var tip := ""
	var small := false

	func _init(the_id: int, the_listener: Object, text: String, is_small: bool = false) -> void:
		super._init(null, the_id, the_listener)
		label = text
		small = is_small
		height = 30 if is_small else 42

	func draw(g: Graphics) -> void:
		if btn_no_draw:
			return
		var down := is_down and is_over and not disabled
		LawnButtons.draw_stone_button(g, 0, 0, width, height, down, is_over and not disabled,
			TodStrings.translate(label), 110 if disabled else 255)

## A button that shows its state: used for tab strips and toggle rows.
class TabButton:
	extends ButtonWidget
	var active := false
	var badge := ""

	func _init(the_id: int, the_listener: Object, text: String) -> void:
		super._init(the_id, the_listener)
		label = text
		do_finger = true
		height = 34

	func draw(g: Graphics) -> void:
		var r := Rect2(0, 0, width, height)
		if active:
			g.color = Color8(120, 92, 52, 235)
			g.fill_rect_r(r)
			g.color = EditorUi.SELECT_EDGE
			g.draw_rect(0, 0, width - 1, height - 1)
		else:
			g.color = Color8(46, 36, 24, 200) if not is_over else Color8(74, 58, 38, 215)
			g.fill_rect_r(r)
			g.color = EditorUi.SLOT_EDGE
			g.draw_rect(0, 0, width - 1, height - 1)
		var f := EditorUi.font_body()
		var col := EditorUi.TEXT_CREAM if (active or is_over) else Color8(196, 178, 148)
		EditorUi.draw_text(g, TodStrings.translate(label), 12, Tod.idiv(height - f.get_height(), 2) + f.get_ascent(), f, col)
		if badge != "":
			EditorUi.draw_text(g, badge, width - 10, Tod.idiv(height - f.get_height(), 2) + f.get_ascent(),
				EditorUi.font_small(), EditorUi.TEXT_GOLD, TodStrings.DS_ALIGN_RIGHT)

## Checkbox plus a caption, clickable across its whole width.
class Toggle:
	extends Widget
	var id := 0
	var listener: Object
	var checked := false
	var label := ""
	var tip := ""

	func _init(the_id: int, the_listener: Object, text: String, value: bool) -> void:
		id = the_id
		listener = the_listener
		label = text
		checked = value
		do_finger = true
		height = 26

	func draw(g: Graphics) -> void:
		var box := Res.get_image("IMAGE_OPTIONS_CHECKBOX1" if checked else "IMAGE_OPTIONS_CHECKBOX0")
		if box != null:
			g.draw_image(box, 0, Tod.idiv(height - box.height, 2))
		else:
			EditorUi.draw_slot(g, Rect2(0, 4, 18, 18), is_over, checked)
		var f := EditorUi.font_body()
		var col := EditorUi.TEXT_CREAM if is_over else Color8(226, 214, 186)
		EditorUi.draw_text(g, TodStrings.translate(label), 30, Tod.idiv(height - f.get_height(), 2) + f.get_ascent(), f, col)

	func mouse_down_btn(_mx: int, _my: int, _btn: int, _count: int) -> void:
		checked = not checked
		if listener and listener.has_method("editor_toggle"):
			listener.editor_toggle(id, checked)

## A value box with < > steppers. Integer or float, with an optional label list for enum values.
class Stepper:
	extends Widget
	var id := 0
	var listener: Object
	var label := ""
	var value := 0.0
	var min_value := 0.0
	var max_value := 100.0
	var step := 1.0
	var big_step := 10.0
	var decimals := 0
	var names: Array = []        ## when set, the value indexes this list
	var suffix := ""
	## Shown instead of the number when the value is the minimum (e.g. "no limit" for 0).
	var zero_text := ""
	var label_width := 150
	var tip := ""
	var _hover_part := 0         ## -1 left, 1 right, 0 none

	func _init(the_id: int, the_listener: Object, text: String, v: float, lo: float, hi: float, st: float = 1.0) -> void:
		id = the_id
		listener = the_listener
		label = text
		value = v
		min_value = lo
		max_value = hi
		step = st
		big_step = st * 10.0
		height = 28

	func value_text() -> String:
		if not names.is_empty():
			return str(names[clampi(int(value), 0, names.size() - 1)])
		if zero_text != "" and is_equal_approx(value, min_value):
			return zero_text
		if decimals > 0:
			return ("%." + str(decimals) + "f") % value + suffix
		return str(int(round(value))) + suffix

	## The value box needs room for the widest label a choice stepper can show.
	func widest_value_width() -> int:
		var f := EditorUi.font_body()
		if names.is_empty():
			return f.string_width(value_text()) + 16
		var w := 0
		for n in names:
			w = maxi(w, f.string_width(str(n)))
		return w + 16

	func _arrow_rects() -> Array:
		var bx := label_width
		return [Rect2(bx, 2, 24, height - 4), Rect2(width - 24, 2, 24, height - 4)]

	func draw(g: Graphics) -> void:
		var f := EditorUi.font_body()
		var ty := Tod.idiv(height - f.get_height(), 2) + f.get_ascent()
		if label != "":
			EditorUi.draw_text(g, label, 0, ty, f, Color8(212, 198, 168))
		var rects := _arrow_rects()
		var box := Rect2(label_width + 26, 2, width - label_width - 52, height - 4)
		EditorUi.draw_slot(g, box, is_over)
		EditorUi.draw_text(g, value_text(), int(box.position.x + box.size.x * 0.5), ty, f,
			EditorUi.TEXT_CREAM, TodStrings.DS_ALIGN_CENTER)
		for i in 2:
			var r: Rect2 = rects[i]
			var enabled := (value > min_value) if i == 0 else (value < max_value)
			EditorUi.draw_slot(g, r, _hover_part == (-1 if i == 0 else 1) and enabled)
			EditorUi.draw_text(g, "<" if i == 0 else ">", int(r.position.x + r.size.x * 0.5), ty, f,
				EditorUi.TEXT_GOLD if enabled else EditorUi.TEXT_DIM, TodStrings.DS_ALIGN_CENTER)

	func mouse_move(mx: int, my: int) -> void:
		_hover_part = 0
		var rects := _arrow_rects()
		if (rects[0] as Rect2).has_point(Vector2(mx, my)):
			_hover_part = -1
		elif (rects[1] as Rect2).has_point(Vector2(mx, my)):
			_hover_part = 1

	func mouse_leave() -> void:
		_hover_part = 0

	func _apply(delta: float) -> void:
		var old := value
		value = clampf(value + delta, min_value, max_value)
		if not is_equal_approx(old, value) and listener and listener.has_method("editor_stepper"):
			listener.editor_stepper(id, value)

	func mouse_down_btn(mx: int, my: int, btn: int, _count: int) -> void:
		var rects := _arrow_rects()
		var amount := big_step if btn == 1 else step
		if (rects[0] as Rect2).has_point(Vector2(mx, my)):
			_apply(-amount)
			App.play_sample("SOUND_TAP")
		elif (rects[1] as Rect2).has_point(Vector2(mx, my)):
			_apply(amount)
			App.play_sample("SOUND_TAP")

	func mouse_wheel(delta: int) -> bool:
		_apply(step * delta)
		return true

## A labelled single-line text field drawn in the game's edit box art.
class TextField:
	extends EditWidget
	var caption := ""
	var caption_width := 150
	var placeholder := ""

	func _init(the_id: int, the_listener: Object, text: String, value: String) -> void:
		super._init(the_id, the_listener, null)
		caption = text
		font = EditorUi.font_body()
		set_colors([[0, 0, 0, 0], [0, 0, 0, 0], [255, 246, 214, 255], [255, 255, 255, 255], [0, 0, 0, 255]])
		blink_delay = 14
		auto_cap_first_letter = false
		height = 28
		set_text(value)

	func draw(g: Graphics) -> void:
		var f := EditorUi.font_body()
		var ty := Tod.idiv(height - f.get_height(), 2) + f.get_ascent()
		if caption != "":
			EditorUi.draw_text(g, caption, 0, ty, f, Color8(212, 198, 168))
		var box := Rect2(caption_width, 1, width - caption_width, height - 2)
		EditorUi.draw_slot(g, box, is_over, has_focus)
		var cg := g.copy()
		cg.translate(box.position.x + 6, 0)
		cg.clip_rect(0, 0, box.size.x - 12, height)
		if text == "" and not has_focus and placeholder != "":
			EditorUi.draw_plain(cg, placeholder, 0, ty, f, EditorUi.TEXT_DIM)
		else:
			super.draw(cg)

	func mouse_down_btn(mx: int, my: int, btn: int, count: int) -> void:
		super.mouse_down_btn(mx - caption_width - 6, my, btn, count)
		if widget_manager:
			widget_manager.set_focus(self)

## A scrollable list of rows. The owner draws each row through a callback.
class ScrollList:
	extends Widget
	const BAR_W := 9
	var id := 0
	var listener: Object
	var row_height := 28
	var count := 0
	var selected := -1
	var scroll := 0
	var hover_row := -1
	## func(g, index, rect, hovered, selected)
	var draw_row: Callable
	var empty_text := "Nothing here yet."
	var bar_dragging := false

	func _init(the_id: int, the_listener: Object) -> void:
		id = the_id
		listener = the_listener
		do_finger = true

	func visible_rows() -> int:
		return maxi(1, Tod.idiv(height, row_height))

	func max_scroll() -> int:
		return maxi(0, count - visible_rows())

	func clamp_scroll() -> void:
		scroll = clampi(scroll, 0, max_scroll())

	func ensure_visible(index: int) -> void:
		if index < 0:
			return
		if index < scroll:
			scroll = index
		elif index >= scroll + visible_rows():
			scroll = index - visible_rows() + 1
		clamp_scroll()

	func draw(g: Graphics) -> void:
		EditorUi.draw_shade(g, Rect2(0, 0, width, height), 0.3)
		clamp_scroll()
		if count == 0:
			EditorUi.draw_text(g, empty_text, Tod.idiv(width, 2), Tod.idiv(height, 2),
				EditorUi.font_body(), EditorUi.TEXT_DIM, TodStrings.DS_ALIGN_CENTER)
			return
		var rows := visible_rows()
		var rg := g.copy()
		rg.clip_rect(0, 0, width, height)
		for i in rows:
			var index := scroll + i
			if index >= count:
				break
			var r := Rect2(2, i * row_height, width - (14 if max_scroll() > 0 else 4), row_height - 2)
			if draw_row.is_valid():
				draw_row.call(rg, index, r, index == hover_row, index == selected)
		if max_scroll() > 0:
			var track := Rect2(width - BAR_W - 1, 0, BAR_W, height)
			g.color = Color8(24, 18, 12, 180)
			g.fill_rect_r(track)
			var bar_h := bar_height()
			var bar_y := (height - bar_h) * (float(scroll) / float(max_scroll()))
			g.color = Color8(210, 178, 116) if bar_dragging else Color8(172, 140, 88)
			g.fill_rect(width - BAR_W - 1, bar_y, BAR_W, bar_h)

	func row_at(my: int) -> int:
		var index := scroll + Tod.idiv(my, row_height)
		return index if index >= 0 and index < count else -1

	func mouse_move(_mx: int, my: int) -> void:
		hover_row = row_at(my)

	func mouse_leave() -> void:
		hover_row = -1

	func mouse_wheel(delta: int) -> bool:
		var before := scroll
		scroll = clampi(scroll - delta * 2, 0, max_scroll())
		return scroll != before

	func bar_height() -> float:
		return maxf(18.0, height * float(visible_rows()) / float(maxi(1, count)))

	func over_bar(mx: int) -> bool:
		return max_scroll() > 0 and mx >= width - BAR_W - 5

	## Drags the bar so its middle follows the pointer.
	func scroll_to_bar(my: int) -> void:
		var bar_h := bar_height()
		var span := maxf(1.0, height - bar_h)
		scroll = clampi(Tod.round_to_int((my - bar_h * 0.5) / span * max_scroll()), 0, max_scroll())

	func mouse_down_btn(mx: int, my: int, btn: int, count_clicks: int) -> void:
		if over_bar(mx):
			bar_dragging = true
			scroll_to_bar(my)
			return
		var index := row_at(my)
		if index == -1:
			return
		selected = index
		App.play_sample("SOUND_TAP")
		if listener and listener.has_method("editor_list_click"):
			listener.editor_list_click(id, index, mx, btn, count_clicks)

	func mouse_drag(_mx: int, my: int) -> void:
		if bar_dragging:
			scroll_to_bar(my)

	func mouse_up_btn(_mx: int, _my: int, _btn: int, _count: int) -> void:
		bar_dragging = false

## A grid of pickable icons (seed packets, zombie portraits, tiles).
class IconGrid:
	extends Widget
	const BAR_W := 9
	var id := 0
	var listener: Object
	var cell := Vector2i(56, 76)
	var gap := Vector2i(4, 4)
	var count := 0
	var selected := -1
	var hover := -1
	var scroll := 0
	## func(g, index, rect, hovered, selected)
	var draw_cell: Callable
	var bar_dragging := false

	func _init(the_id: int, the_listener: Object) -> void:
		id = the_id
		listener = the_listener
		do_finger = true

	func columns() -> int:
		# the bar rides in the slack the cells leave at the right edge, so it never costs a column
		return maxi(1, Tod.idiv(width + gap.x, cell.x + gap.x))

	func rows_visible() -> int:
		return maxi(1, Tod.idiv(height + gap.y, cell.y + gap.y))

	func total_rows() -> int:
		return Tod.idiv(count + columns() - 1, columns())

	func max_scroll() -> int:
		return maxi(0, total_rows() - rows_visible())

	func cell_rect(index: int) -> Rect2:
		var c := columns()
		var row := Tod.idiv(index, c) - scroll
		var col := index % c
		return Rect2(col * (cell.x + gap.x), row * (cell.y + gap.y), cell.x, cell.y)

	func index_at(mx: int, my: int) -> int:
		var c := columns()
		var col := Tod.idiv(mx, cell.x + gap.x)
		var row := Tod.idiv(my, cell.y + gap.y) + scroll
		if col < 0 or col >= c or row < 0:
			return -1
		var index := row * c + col
		return index if index < count else -1

	func draw(g: Graphics) -> void:
		scroll = clampi(scroll, 0, max_scroll())
		var first := scroll * columns()
		var last := mini(count, first + (rows_visible() + 1) * columns())
		var cg := g.copy()
		cg.clip_rect(0, 0, width, height)
		for i in range(first, last):
			var r := cell_rect(i)
			if r.position.y + r.size.y < 0 or r.position.y > height:
				continue
			if draw_cell.is_valid():
				draw_cell.call(cg, i, r, i == hover, i == selected)
		if max_scroll() > 0:
			g.color = Color8(24, 18, 12, 180)
			g.fill_rect(width - BAR_W - 1, 0, BAR_W, height)
			var bar_h := bar_height()
			g.color = Color8(210, 178, 116) if bar_dragging else Color8(172, 140, 88)
			g.fill_rect(width - BAR_W - 1, (height - bar_h) * (float(scroll) / float(max_scroll())), BAR_W, bar_h)

	func mouse_move(mx: int, my: int) -> void:
		hover = index_at(mx, my)

	func mouse_leave() -> void:
		hover = -1

	func mouse_wheel(delta: int) -> bool:
		var before := scroll
		scroll = clampi(scroll - delta, 0, max_scroll())
		return scroll != before

	func bar_height() -> float:
		return maxf(18.0, height * float(rows_visible()) / float(maxi(1, total_rows())))

	func over_bar(mx: int) -> bool:
		return max_scroll() > 0 and mx >= width - BAR_W - 5

	func scroll_to_bar(my: int) -> void:
		var bar_h := bar_height()
		var span := maxf(1.0, height - bar_h)
		scroll = clampi(Tod.round_to_int((my - bar_h * 0.5) / span * max_scroll()), 0, max_scroll())

	func mouse_down_btn(mx: int, my: int, btn: int, _count: int) -> void:
		if over_bar(mx):
			bar_dragging = true
			scroll_to_bar(my)
			return
		var index := index_at(mx, my)
		if index == -1:
			return
		selected = index
		App.play_sample("SOUND_TAP")
		if listener and listener.has_method("editor_grid_click"):
			listener.editor_grid_click(id, index, btn)

	func mouse_drag(_mx: int, my: int) -> void:
		if bar_dragging:
			scroll_to_bar(my)

	func mouse_up_btn(_mx: int, _my: int, _btn: int, _count: int) -> void:
		bar_dragging = false

## A multi-line text area (Crazy Dave's lines, descriptions).
class TextArea:
	extends Widget
	var id := 0
	var listener: Object
	var lines: Array = [""]
	var cursor_line := 0
	var cursor_col := 0
	var scroll := 0
	var caption := ""
	var blink := 0
	var max_line_chars := 120

	func _init(the_id: int, the_listener: Object) -> void:
		id = the_id
		listener = the_listener
		wants_focus = true
		do_finger = false

	func set_lines(l: Array) -> void:
		lines = l.duplicate() if not l.is_empty() else [""]
		cursor_line = 0
		cursor_col = 0

	func get_lines() -> Array:
		var out: Array = []
		for l in lines:
			if str(l).strip_edges() != "":
				out.append(str(l))
		return out

	func line_height() -> int:
		return EditorUi.font_body().get_line_spacing() + 2

	func visible_lines() -> int:
		return maxi(1, Tod.idiv(height - 8, line_height()))

	func update() -> void:
		super.update()
		if has_focus:
			blink = (blink + 1) % 40

	func draw(g: Graphics) -> void:
		EditorUi.draw_slot(g, Rect2(0, 0, width, height), is_over, has_focus)
		var f := EditorUi.font_body()
		var lh := line_height()
		var y := 6 + f.get_ascent()
		scroll = clampi(scroll, 0, maxi(0, lines.size() - visible_lines()))
		for i in range(scroll, mini(lines.size(), scroll + visible_lines())):
			var text := str(lines[i])
			EditorUi.draw_plain(g, "%d. %s" % [i + 1, text], 8, y, f,
				EditorUi.TEXT_CREAM if i == cursor_line else Color8(206, 194, 166))
			if has_focus and i == cursor_line and blink < 20:
				var prefix := "%d. %s" % [i + 1, text.substr(0, cursor_col)]
				g.color = EditorUi.TEXT_GOLD
				g.fill_rect(8 + f.string_width(prefix), y - f.get_ascent() + 2, 2, f.get_height() - 2)
			y += lh

	func ensure_cursor_visible() -> void:
		if cursor_line < scroll:
			scroll = cursor_line
		elif cursor_line >= scroll + visible_lines():
			scroll = cursor_line - visible_lines() + 1

	func mouse_down_btn(_mx: int, my: int, _btn: int, _count: int) -> void:
		var index := scroll + Tod.idiv(my - 4, line_height())
		cursor_line = clampi(index, 0, lines.size() - 1)
		cursor_col = str(lines[cursor_line]).length()
		if widget_manager:
			widget_manager.set_focus(self)

	func mouse_wheel(delta: int) -> bool:
		var before := scroll
		scroll = clampi(scroll - delta, 0, maxi(0, lines.size() - visible_lines()))
		return scroll != before

	func _changed() -> void:
		if listener and listener.has_method("editor_textarea_changed"):
			listener.editor_textarea_changed(id, get_lines())

	func key_char(ch: String) -> void:
		if ch.is_empty() or ch.unicode_at(0) < 32 or ch.unicode_at(0) == 127:
			return
		var line := str(lines[cursor_line])
		if line.length() >= max_line_chars:
			return
		lines[cursor_line] = line.substr(0, cursor_col) + ch + line.substr(cursor_col)
		cursor_col += 1
		_changed()

	func key_down(key: int) -> void:
		var line := str(lines[cursor_line])
		match key:
			WidgetManager.KEYCODE_RETURN:
				var rest := line.substr(cursor_col)
				lines[cursor_line] = line.substr(0, cursor_col)
				lines.insert(cursor_line + 1, rest)
				cursor_line += 1
				cursor_col = 0
				_changed()
			WidgetManager.KEYCODE_BACK:
				if cursor_col > 0:
					lines[cursor_line] = line.substr(0, cursor_col - 1) + line.substr(cursor_col)
					cursor_col -= 1
					_changed()
				elif cursor_line > 0:
					var prev := str(lines[cursor_line - 1])
					cursor_col = prev.length()
					lines[cursor_line - 1] = prev + line
					lines.remove_at(cursor_line)
					cursor_line -= 1
					_changed()
			WidgetManager.KEYCODE_DELETE:
				if cursor_col < line.length():
					lines[cursor_line] = line.substr(0, cursor_col) + line.substr(cursor_col + 1)
					_changed()
			WidgetManager.KEYCODE_LEFT:
				cursor_col = maxi(0, cursor_col - 1)
			WidgetManager.KEYCODE_RIGHT:
				cursor_col = mini(line.length(), cursor_col + 1)
			WidgetManager.KEYCODE_UP:
				cursor_line = maxi(0, cursor_line - 1)
				cursor_col = mini(cursor_col, str(lines[cursor_line]).length())
			WidgetManager.KEYCODE_DOWN:
				cursor_line = mini(lines.size() - 1, cursor_line + 1)
				cursor_col = mini(cursor_col, str(lines[cursor_line]).length())
			WidgetManager.KEYCODE_HOME:
				cursor_col = 0
			WidgetManager.KEYCODE_END:
				cursor_col = line.length()
		blink = 0
		ensure_cursor_visible()
