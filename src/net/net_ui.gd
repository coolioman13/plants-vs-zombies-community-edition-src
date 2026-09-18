class_name NetUi
## Drawing helpers shared by the multiplayer screens, built from the game's own art so they match PvZ.

const TEXT_DARK := Color8(42, 42, 90)        # mini-game window text
const TEXT_BROWN := Color8(90, 55, 20)
const TEXT_GOLD := Color8(224, 187, 98)      # dialog header gold
const TEXT_SYSTEM := Color8(255, 240, 150)

class StoneButton:
	extends DialogButton
	## LawnStoneButton that greys out when disabled.
	func _init(the_id: int, the_listener: Object, text: String) -> void:
		super._init(null, the_id, the_listener)
		label = text
		height = 46

	func draw(g: Graphics) -> void:
		if btn_no_draw:
			return
		var down := is_down and is_over and not disabled
		LawnButtons.draw_stone_button(g, 0, 0, width, height, down, is_over and not disabled, TodStrings.translate(label), 120 if disabled else 255)

class ChatBox:
	extends EditWidget
	## Chat input: sends on Enter, keeps focus so several messages can be typed in a row.
	var on_close: Callable

	func _init(the_listener: Object) -> void:
		super._init(0, the_listener, null)
		font = Res.get_font("FONT_BRIANNETOD16")
		set_colors([[0, 0, 0, 0], [0, 0, 0, 0], [240, 240, 255, 255], [255, 255, 255, 255], [0, 0, 0, 255]])
		blink_delay = 14
		max_chars = NetSession.MAX_CHAT_CHARS

	func key_down(key: int) -> void:
		if key == WidgetManager.KEYCODE_ESCAPE and on_close.is_valid():
			on_close.call()
			return
		super.key_down(key)

static func set_enabled(b: ButtonWidget, on: bool) -> void:
	if b.disabled == on:
		b.set_disabled(not on)

## Stretchable stone dialog frame (the LawnDialog pieces, scaled down for smaller panels).
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

## Text with a 1px dark drop shadow (the in-game advice look).
static func draw_text(g: Graphics, text: String, x: int, y: int, font: ImageFont, color: Color, align: int = TodStrings.DS_ALIGN_LEFT) -> void:
	TodStrings.draw_string(g, text, x + 1, y + 1, font, Color(0, 0, 0, color.a * 0.8), align)
	TodStrings.draw_string(g, text, x, y, font, color, align)

## Word-wraps chat lines into rect bottom-up. fade_ms > 0 fades lines older than that.
static func draw_chat(g: Graphics, rect: Rect2i, log: Array, fade_ms: int = 0, shadow: bool = true) -> void:
	var font := Res.get_font("FONT_BRIANNETOD12")
	var line_h := font.get_line_spacing() + 2
	var now := Time.get_ticks_msec()
	var lines: Array = []   # [text, color, alpha]
	for e in log:
		var alpha := 1.0
		if fade_ms > 0:
			var age: int = now - int(e.time)
			if age > fade_ms + 1500:
				continue
			alpha = clampf(1.0 - float(age - fade_ms) / 1500.0, 0.0, 1.0)
		var col: Color = e.color
		for l in wrap_text(str(e.text), font, rect.size.x):
			lines.append([l, col, alpha])
	var max_lines := maxi(1, Tod.idiv(rect.size.y, line_h))
	var start := maxi(0, lines.size() - max_lines)
	var y := rect.position.y + rect.size.y - (lines.size() - start) * line_h + font.get_ascent()
	for i in range(start, lines.size()):
		var c: Color = lines[i][1]
		c.a = lines[i][2]
		if shadow:
			draw_text(g, lines[i][0], rect.position.x, y, font, c)
		else:
			TodStrings.draw_string(g, lines[i][0], rect.position.x, y, font, c, TodStrings.DS_ALIGN_LEFT)
		y += line_h

static func wrap_text(text: String, font: ImageFont, max_w: int) -> Array:
	var out: Array = []
	var cur := ""
	for word in text.split(" "):
		var cand := word if cur == "" else cur + " " + word
		if font.string_width(cand) <= max_w or cur == "":
			cur = cand
		else:
			out.append(cur)
			cur = word
	if cur != "":
		out.append(cur)
	return out

## A translucent dark strip behind text laid over the lawn.
static func draw_shade(g: Graphics, r: Rect2, alpha: float = 0.45) -> void:
	g.color = Color(0, 0, 0, alpha)
	g.fill_rect(r.position.x, r.position.y, r.size.x, r.size.y)

## Small player tag: a flag in the player's colour with the name (used on cursors and lists).
static func draw_name_tag(g: Graphics, text: String, x: int, y: int, color: Color) -> void:
	var font := Res.get_font("FONT_BRIANNETOD12")
	var w := font.string_width(text) + 10
	var h := font.get_height() + 4
	g.color = Color8(0, 0, 0, 170)
	g.fill_rect(x - 1, y - 1, w + 2, h + 2)
	g.color = Color(color.r * 0.55, color.g * 0.55, color.b * 0.55, 0.92)
	g.fill_rect(x, y, w, h)
	g.color = color
	g.fill_rect(x, y, 3, h)
	TodStrings.draw_string(g, text, x + 6, y + font.get_ascent() + 2, font, Color.WHITE, TodStrings.DS_ALIGN_LEFT)

## Draws a plant / zombie / grave portrait with its feet at (x, y).
static func draw_portrait(g: Graphics, seed_type: int, x: float, y: float, scale: float) -> void:
	var sg := g.copy()
	sg.scale_x = scale
	sg.scale_y = scale
	if NetVersus.is_zombie_side_seed(seed_type) and seed_type != NetVersus.SEED_GRAVE:
		Plant.draw_seed_type(sg, seed_type, PvZ.SEED_NONE, PvZ.VARIATION_NORMAL, x - 60.0 * scale, y - 125.0 * scale)
	else:
		Plant.draw_seed_type(sg, seed_type, PvZ.SEED_NONE, PvZ.VARIATION_NORMAL, x - 40.0 * scale, y - 78.0 * scale)
