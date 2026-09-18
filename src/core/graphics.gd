class_name Graphics
extends RefCounted
## Port of Sexy::Graphics (the parts PvZ uses) on top of RenderingServer canvas commands.

const DRAWMODE_NORMAL := 0
const DRAWMODE_ADDITIVE := 1

var target: RenderTarget
var trans_x := 0.0
var trans_y := 0.0
var scale_x := 1.0
var scale_y := 1.0
var scale_orig_x := 0.0
var scale_orig_y := 0.0
var clip := Rect2(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)
var color := Color.WHITE
var font: ImageFont
var draw_mode := DRAWMODE_NORMAL
var colorize_images := false
var linear_blend := false
## Extra per-Graphics filter (used by reanim filter effects and for Godot-scene visuals).
var filter := RenderTarget.FILTER_NONE

static var _identity := Transform2D.IDENTITY
static var _last_xform: Dictionary = {}   # segment RID -> Transform2D currently set

func _init(t: RenderTarget = null) -> void:
	target = t

func copy() -> Graphics:
	var g := Graphics.new(target)
	g.trans_x = trans_x
	g.trans_y = trans_y
	g.scale_x = scale_x
	g.scale_y = scale_y
	g.scale_orig_x = scale_orig_x
	g.scale_orig_y = scale_orig_y
	g.clip = clip
	g.color = color
	g.font = font
	g.draw_mode = draw_mode
	g.colorize_images = colorize_images
	g.linear_blend = linear_blend
	g.filter = filter
	return g

static func reset_frame_state() -> void:
	_last_xform.clear()

# ---------------------------------------------------------------- state
func set_color(c: Color) -> void: color = c
func get_color() -> Color: return color
func set_colorize_images(on: bool) -> void: colorize_images = on
func get_colorize_images() -> bool: return colorize_images
func set_draw_mode(m: int) -> void: draw_mode = m
func get_draw_mode() -> int: return draw_mode
func set_font(f: ImageFont) -> void: font = f
func set_linear_blend(on: bool) -> void: linear_blend = on

func translate(x: float, y: float) -> void:
	trans_x += x
	trans_y += y

func set_scale(sx: float, sy: float, ox: float, oy: float) -> void:
	scale_x = sx
	scale_y = sy
	scale_orig_x = ox + trans_x
	scale_orig_y = oy + trans_y

func set_clip_rect(x: float, y: float, w: float, h: float) -> void:
	clip = Rect2(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT).intersection(Rect2(x + trans_x, y + trans_y, maxf(w, 0.0), maxf(h, 0.0)))

func set_clip_rect_r(r: Rect2) -> void:
	set_clip_rect(r.position.x, r.position.y, r.size.x, r.size.y)

func clip_rect(x: float, y: float, w: float, h: float) -> void:
	clip = clip.intersection(Rect2(x + trans_x, y + trans_y, maxf(w, 0.0), maxf(h, 0.0)))

func clear_clip_rect() -> void:
	clip = Rect2(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)

func _img_color() -> Color:
	return color if colorize_images else Color.WHITE

# ---------------------------------------------------------------- low level emit
func _set_xform(seg: RID, xf: Transform2D) -> void:
	var t := target
	var i := t.cur
	if i >= 0 and t.segments[i] == seg:
		# Fast path: draws always go to the current segment.
		if t.segment_xform_set[i] == 0 or t.segment_xforms[i] != xf:
			RenderingServer.canvas_item_add_set_transform(seg, xf)
			t.segment_xforms[i] = xf
			t.segment_xform_set[i] = 1
		return
	var last = _last_xform.get(seg)
	if last == null or last != xf:
		RenderingServer.canvas_item_add_set_transform(seg, xf)
		_last_xform[seg] = xf

## Axis aligned blit, software clipped against [param clip_r] (absolute coordinates).
func _emit_rect(img: PvzImage, dest: Rect2, src: Rect2, col: Color, mode: int, clip_r: Rect2, mirror: bool = false) -> void:
	if img == null or target == null:
		return
	if dest.size.x <= 0 or dest.size.y <= 0 or col.a <= 0.0:
		return
	var cd := dest.intersection(clip_r)
	if cd.size.x <= 0 or cd.size.y <= 0:
		return
	var fx := src.size.x / dest.size.x
	var fy := src.size.y / dest.size.y
	var cs := Rect2()
	cs.size = Vector2(cd.size.x * fx, cd.size.y * fy)
	cs.position.y = src.position.y + (cd.position.y - dest.position.y) * fy
	if mirror:
		cs.position.x = src.position.x + (dest.end.x - cd.end.x) * fx
	else:
		cs.position.x = src.position.x + (cd.position.x - dest.position.x) * fx
	var seg := target.seg_for_rect(cd)
	_set_xform(seg, _identity)
	var r := cd
	if mirror:
		r = Rect2(cd.position.x + cd.size.x, cd.position.y, -cd.size.x, cd.size.y)
	RenderingServer.canvas_item_add_texture_rect_region(seg, r, img.rid, cs, RenderTarget.encode(col, mode, filter), false, true)

## Transformed blit (TodBltMatrix): the source rect is centered on the matrix origin.
func blt_matrix(img: PvzImage, xf: Transform2D, clip_r: Rect2, col: Color, mode: int, src: Rect2) -> void:
	if img == null or target == null or col.a <= 0.0:
		return
	var t := target
	var seg := t.seg_for_clip(clip_r)
	# _set_xform and RenderTarget.encode inlined: this runs for every sprite part of every zombie and plant.
	var i := t.cur
	if t.segment_xform_set[i] == 0 or t.segment_xforms[i] != xf:
		RenderingServer.canvas_item_add_set_transform(seg, xf)
		t.segment_xforms[i] = xf
		t.segment_xform_set[i] = 1
	col.a = clampf(col.a, 0.0, 1.0) + 4.0 * float(mode + 2 * filter)
	RenderingServer.canvas_item_add_texture_rect_region(seg, Rect2(-src.size.x * 0.5, -src.size.y * 0.5, src.size.x, src.size.y),
		img.rid, src, col, false, true)

# ---------------------------------------------------------------- images
func draw_image(img: PvzImage, x: float, y: float) -> void:
	if img == null:
		return
	draw_image_src(img, x, y, Rect2(0, 0, img.width, img.height))

func draw_image_src(img: PvzImage, x: float, y: float, src: Rect2) -> void:
	if img == null:
		return
	x += trans_x
	y += trans_y
	if scale_x != 1.0 or scale_y != 1.0:
		var d := Rect2(scale_orig_x + floorf((x - scale_orig_x) * scale_x), scale_orig_y + floorf((y - scale_orig_y) * scale_y),
			ceilf(src.size.x * scale_x), ceilf(src.size.y * scale_y))
		_emit_rect(img, d, src, _img_color(), draw_mode, clip)
		return
	_emit_rect(img, Rect2(x, y, src.size.x, src.size.y), src, _img_color(), draw_mode, clip)

func draw_image_f(img: PvzImage, x: float, y: float) -> void:
	if img == null:
		return
	_emit_rect(img, Rect2(x + trans_x, y + trans_y, img.width, img.height), Rect2(0, 0, img.width, img.height), _img_color(), draw_mode, clip)

func draw_image_f_src(img: PvzImage, x: float, y: float, src: Rect2) -> void:
	if img == null:
		return
	_emit_rect(img, Rect2(x + trans_x, y + trans_y, src.size.x, src.size.y), src, _img_color(), draw_mode, clip)

## DrawImage(Image*, const Rect& dest, const Rect& src)
func draw_image_stretch(img: PvzImage, dest: Rect2, src: Rect2) -> void:
	if img == null:
		return
	_emit_rect(img, Rect2(dest.position.x + trans_x, dest.position.y + trans_y, dest.size.x, dest.size.y), src, _img_color(), draw_mode, clip)

## DrawImage(Image*, x, y, stretchedW, stretchedH)
func draw_image_scaled_size(img: PvzImage, x: float, y: float, w: float, h: float) -> void:
	if img == null:
		return
	_emit_rect(img, Rect2(x + trans_x, y + trans_y, w, h), Rect2(0, 0, img.width, img.height), _img_color(), draw_mode, clip)

func draw_image_mirror(img: PvzImage, x: float, y: float, mirror: bool = true) -> void:
	if img == null:
		return
	draw_image_mirror_src(img, x, y, Rect2(0, 0, img.width, img.height), mirror)

func draw_image_mirror_src(img: PvzImage, x: float, y: float, src: Rect2, mirror: bool = true) -> void:
	if not mirror:
		draw_image_src(img, x, y, src)
		return
	_emit_rect(img, Rect2(x + trans_x, y + trans_y, src.size.x, src.size.y), src, _img_color(), draw_mode, clip, true)

func draw_image_mirror_stretch(img: PvzImage, dest: Rect2, src: Rect2, mirror: bool = true) -> void:
	if not mirror:
		draw_image_stretch(img, dest, src)
		return
	_emit_rect(img, Rect2(dest.position.x + trans_x, dest.position.y + trans_y, dest.size.x, dest.size.y), src, _img_color(), draw_mode, clip, true)

func draw_image_cel(img: PvzImage, x: float, y: float, cel: int) -> void:
	if img == null:
		return
	draw_image_cel_rc(img, x, y, cel % img.num_cols, Tod.idiv(cel, img.num_cols))

func draw_image_cel_rc(img: PvzImage, x: float, y: float, col: int, row: int) -> void:
	if img == null or row < 0 or col < 0 or row >= img.num_rows or col >= img.num_cols:
		return
	draw_image_src(img, x, y, img.get_cel_rect(col, row))

func draw_image_cel_dest(img: PvzImage, dest: Rect2, col: int, row: int) -> void:
	if img == null or row < 0 or col < 0 or row >= img.num_rows or col >= img.num_cols:
		return
	draw_image_stretch(img, dest, img.get_cel_rect(col, row))

## Graphics::DrawImageMatrix-like helper: xf is applied after the current translation.
func draw_image_matrix(img: PvzImage, xf: Transform2D, src: Rect2) -> void:
	var m := xf
	m.origin += Vector2(trans_x, trans_y)
	blt_matrix(img, m, clip, _img_color(), draw_mode, src)

func draw_image_rotated_f(img: PvzImage, x: float, y: float, rot: float, cx: float, cy: float, src: Rect2 = Rect2()) -> void:
	if img == null:
		return
	if src.size.x <= 0:
		src = Rect2(0, 0, img.width, img.height)
	# Sexy rotates counter-clockwise for positive angles around (x+cx, y+cy)
	var xf := Transform2D(-rot, Vector2(x + trans_x + cx, y + trans_y + cy))
	xf = xf * Transform2D(0.0, Vector2(-cx + src.size.x * 0.5, -cy + src.size.y * 0.5))
	blt_matrix(img, xf, clip, _img_color(), draw_mode, src)

func draw_image_box(dest: Rect2, img: PvzImage) -> void:
	draw_image_box_src(Rect2(0, 0, img.width, img.height), dest, img)

func draw_image_box_src(src: Rect2, dest: Rect2, img: PvzImage) -> void:
	if src.size.x <= 0 or src.size.y <= 0:
		return
	var cw := int(src.size.x) / 3
	var ch := int(src.size.y) / 3
	var cx := src.position.x
	var cy := src.position.y
	var cmw := int(src.size.x) - cw * 2
	var cmh := int(src.size.y) - ch * 2
	draw_image_src(img, dest.position.x, dest.position.y, Rect2(cx, cy, cw, ch))
	draw_image_src(img, dest.position.x + dest.size.x - cw, dest.position.y, Rect2(cx + cw + cmw, cy, cw, ch))
	draw_image_src(img, dest.position.x, dest.position.y + dest.size.y - ch, Rect2(cx, cy + ch + cmh, cw, ch))
	draw_image_src(img, dest.position.x + dest.size.x - cw, dest.position.y + dest.size.y - ch, Rect2(cx + cw + cmw, cy + ch + cmh, cw, ch))
	var gv := copy()
	gv.clip_rect(dest.position.x + cw, dest.position.y, dest.size.x - cw * 2, dest.size.y)
	for col in int((dest.size.x - cw * 2 + cmw - 1) / cmw):
		gv.draw_image_src(img, dest.position.x + cw + col * cmw, dest.position.y, Rect2(cx + cw, cy, cmw, ch))
		gv.draw_image_src(img, dest.position.x + cw + col * cmw, dest.position.y + dest.size.y - ch, Rect2(cx + cw, cy + ch + cmh, cmw, ch))
	var gh := copy()
	gh.clip_rect(dest.position.x, dest.position.y + ch, dest.size.x, dest.size.y - ch * 2)
	for row in int((dest.size.y - ch * 2 + cmh - 1) / cmh):
		gh.draw_image_src(img, dest.position.x, dest.position.y + ch + row * cmh, Rect2(cx, cy + ch, cw, cmh))
		gh.draw_image_src(img, dest.position.x + dest.size.x - cw, dest.position.y + ch + row * cmh, Rect2(cx + cw + cmw, cy + ch, cw, cmh))
	var gc := copy()
	gc.clip_rect(dest.position.x + cw, dest.position.y + ch, dest.size.x - cw * 2, dest.size.y - ch * 2)
	for col in int((dest.size.x - cw * 2 + cmw - 1) / cmw):
		for row in int((dest.size.y - ch * 2 + cmh - 1) / cmh):
			gc.draw_image_src(img, dest.position.x + cw + col * cmw, dest.position.y + ch + row * cmh, Rect2(cx + cw, cy + ch, cmw, cmh))

# ---------------------------------------------------------------- Tod draw helpers
func tod_draw_image_scaled_f(img: PvzImage, x: float, y: float, sx: float, sy: float) -> void:
	if img == null:
		return
	if sx == 1.0 and sy == 1.0:
		draw_image_f(img, x, y)
		return
	var xf := Tod.scale_matrix(img.width * 0.5 * sx + x + trans_x, img.height * 0.5 * sy + y + trans_y, sx, sy)
	blt_matrix(img, xf, clip, _img_color(), draw_mode, Rect2(0, 0, img.width, img.height))

func tod_draw_image_center_scaled_f(img: PvzImage, x: float, y: float, sx: float, sy: float) -> void:
	if img == null:
		return
	if sx == 1.0 and sy == 1.0:
		draw_image_f(img, x, y)
		return
	var xf := Tod.scale_matrix(img.width * 0.5 + x + trans_x, img.height * 0.5 + y + trans_y, sx, sy)
	blt_matrix(img, xf, clip, _img_color(), draw_mode, Rect2(0, 0, img.width, img.height))

func tod_draw_image_cel_f(img: PvzImage, x: float, y: float, col: int, row: int) -> void:
	if img == null:
		return
	draw_image_f_src(img, x, y, img.get_cel_rect(col, row))

func tod_draw_image_cel_scaled_f(img: PvzImage, x: float, y: float, col: int, row: int, sx: float, sy: float) -> void:
	if img == null:
		return
	var cw := img.get_cel_width()
	var ch := img.get_cel_height()
	var src := Rect2(cw * col, ch * row, cw, ch)
	if sx == 1.0 and sy == 1.0:
		draw_image_f_src(img, x, y, src)
		return
	var xf := Tod.scale_matrix(cw * 0.5 * sx + x + trans_x, ch * 0.5 * sy + y + trans_y, sx, sy)
	blt_matrix(img, xf, clip, _img_color(), draw_mode, src)

func tod_draw_image_cel_center_scaled_f(img: PvzImage, x: float, y: float, col: int, sx: float, sy: float) -> void:
	if img == null:
		return
	var cw := img.get_cel_width()
	var ch := img.get_cel_height()
	var src := Rect2(cw * col, 0, cw, ch)
	if sx == 1.0 and sy == 1.0:
		draw_image_f_src(img, x, y, src)
		return
	var xf := Tod.scale_matrix(cw * 0.5 + x + trans_x, ch * 0.5 + y + trans_y, sx, sy)
	blt_matrix(img, xf, clip, _img_color(), draw_mode, src)

func tod_draw_image_cel_scaled(img: PvzImage, x: int, y: int, col: int, row: int, sx: float, sy: float) -> void:
	if img == null:
		return
	var cw := img.get_cel_width()
	var ch := img.get_cel_height()
	draw_image_stretch(img, Rect2(x, y, Tod.round_to_int(cw * sx), Tod.round_to_int(ch * sy)), Rect2(cw * col, ch * row, cw, ch))

# ---------------------------------------------------------------- primitives
func fill_rect(x: float, y: float, w: float, h: float) -> void:
	# Sexy's Rect::Intersection treats non-positive sizes as empty; Godot's Rect2 errors on them.
	if color.a <= 0.0 or target == null or w <= 0 or h <= 0:
		return
	var d := Rect2(x + trans_x, y + trans_y, w, h).intersection(clip)
	if d.size.x <= 0 or d.size.y <= 0:
		return
	var seg := target.seg_for_rect(d)
	_set_xform(seg, _identity)
	RenderingServer.canvas_item_add_rect(seg, d, RenderTarget.encode(color, draw_mode, RenderTarget.FILTER_NONE))

func fill_rect_r(r: Rect2) -> void:
	fill_rect(r.position.x, r.position.y, r.size.x, r.size.y)

func draw_rect(x: float, y: float, w: float, h: float) -> void:
	if color.a <= 0.0:
		return
	fill_rect(x, y, w + 1, 1)
	fill_rect(x, y + h, w + 1, 1)
	fill_rect(x, y + 1, 1, h - 1)
	fill_rect(x + w, y + 1, 1, h - 1)

func draw_rect_r(r: Rect2) -> void:
	draw_rect(r.position.x, r.position.y, r.size.x, r.size.y)

func draw_line(x1: float, y1: float, x2: float, y2: float) -> void:
	if target == null:
		return
	var seg := target.seg_for_clip(clip)
	_set_xform(seg, _identity)
	RenderingServer.canvas_item_add_line(seg, Vector2(x1 + trans_x, y1 + trans_y), Vector2(x2 + trans_x, y2 + trans_y),
		RenderTarget.encode(color, draw_mode, RenderTarget.FILTER_NONE), 1.0)

## Anti-aliased line strip of the given width (in current coordinates, with the current color).
func draw_polyline(points: PackedVector2Array, width: float) -> void:
	if target == null or points.size() < 2 or color.a <= 0.0:
		return
	var pts := PackedVector2Array()
	for p in points:
		pts.append(p + Vector2(trans_x, trans_y))
	var seg := target.seg_for_clip(clip)
	_set_xform(seg, _identity)
	RenderingServer.canvas_item_add_polyline(seg, pts, PackedColorArray([RenderTarget.encode(color, draw_mode, RenderTarget.FILTER_NONE)]), width, true)

## verts: Array of triangles; each triangle is Array of 3 [x, y, u, v, Color]
func draw_triangles_tex(img: PvzImage, tris: Array, repeat: bool = false) -> void:
	if img == null or target == null or tris.is_empty():
		return
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	for tri in tris:
		for v in tri:
			pts.append(Vector2(v[0] + trans_x, v[1] + trans_y))
			uvs.append(Vector2(v[2], v[3]))
			cols.append(RenderTarget.encode(v[4], draw_mode, filter))
	var seg := target.seg_for_clip(clip, repeat)
	_set_xform(seg, _identity)
	RenderingServer.canvas_item_add_triangle_array(seg, PackedInt32Array(), pts, cols, uvs, PackedInt32Array(), PackedFloat32Array(), img.rid)

# ---------------------------------------------------------------- text
func string_width(s: String) -> int:
	return font.string_width(s) if font else 0

func draw_string(s: String, x: float, y: float) -> void:
	if font:
		font.draw_string(self, int(x), int(y), s, color, clip)
