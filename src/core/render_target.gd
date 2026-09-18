class_name RenderTarget
extends RefCounted
## Owns a list of child canvas items ("segments") under a parent canvas item. Every frame the
## game redraws into segment 0.. in order. A new segment is started whenever a transformed draw
## needs a clip rectangle different from the current segment, so draw order is preserved while
## still allowing GPU scissoring of rotated/skewed sprites (e.g. zombies half submerged in water).

const DRAW_NORMAL := 0
const DRAW_ADDITIVE := 1

enum { FILTER_NONE, FILTER_WASHED_OUT, FILTER_LESS_WASHED_OUT, FILTER_WHITE, FILTER_ZOMBIE_SUN }

static var _material: ShaderMaterial
static var _material_rid: RID

var parent_rid: RID
var segments: Array[RID] = []
var segment_clips: Array[Rect2] = []   # size.x < 0 means "unclipped"
var segment_repeat: Array[bool] = []
var segment_mats: Array[RID] = []
## Transform last set on each segment this frame (Graphics skips redundant canvas_item_add_set_transform calls).
var segment_xforms: Array[Transform2D] = []
var segment_xform_set := PackedByteArray()
var cur := -1
var screen_rect := Rect2(0, 0, PvZ.BOARD_WIDTH, PvZ.BOARD_HEIGHT)

static func get_material() -> ShaderMaterial:
	if _material == null:
		_material = ShaderMaterial.new()
		_material.shader = load("res://src/core/pvz_canvas.gdshader")
		_material_rid = _material.get_rid()
	return _material

static func material_rid() -> RID:
	if _material == null:
		get_material()
	return _material_rid

func _init(parent_canvas_item: RID) -> void:
	parent_rid = parent_canvas_item

func begin_frame() -> void:
	for i in cur + 1:
		RenderingServer.canvas_item_clear(segments[i])
		# canvas_item_clear also turns the item's clip flag back off, so forget the clip we
		# cached for it - otherwise every segment after the first frame draws unscissored.
		segment_clips[i] = Rect2(0, 0, -1, -1)
	cur = -1

func end_frame() -> void:
	pass

func _new_segment(clip: Rect2, repeat: bool = false, mat: RID = RID()) -> RID:
	cur += 1
	if cur >= segments.size():
		var rid := RenderingServer.canvas_item_create()
		RenderingServer.canvas_item_set_parent(rid, parent_rid)
		RenderingServer.canvas_item_set_material(rid, get_material().get_rid())
		RenderingServer.canvas_item_set_default_texture_filter(rid, RenderingServer.CANVAS_ITEM_TEXTURE_FILTER_LINEAR)
		RenderingServer.canvas_item_set_draw_index(rid, cur)
		segments.append(rid)
		segment_clips.append(Rect2(0, 0, -1, -1))
		segment_repeat.append(false)
		segment_mats.append(material_rid())
		segment_xforms.append(Transform2D.IDENTITY)
		segment_xform_set.append(0)
	segment_xform_set[cur] = 0
	var seg := segments[cur]
	var want_mat := mat if mat.is_valid() else material_rid()
	if segment_mats[cur] != want_mat:
		segment_mats[cur] = want_mat
		RenderingServer.canvas_item_set_material(seg, want_mat)
	if segment_repeat[cur] != repeat:
		segment_repeat[cur] = repeat
		RenderingServer.canvas_item_set_default_texture_repeat(seg, RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_ENABLED if repeat else RenderingServer.CANVAS_ITEM_TEXTURE_REPEAT_DISABLED)
	var old: Rect2 = segment_clips[cur]
	if clip != old:
		segment_clips[cur] = clip
		if clip.size.x < 0:
			RenderingServer.canvas_item_set_clip(seg, false)
			RenderingServer.canvas_item_set_custom_rect(seg, false)
		else:
			RenderingServer.canvas_item_set_clip(seg, true)
			RenderingServer.canvas_item_set_custom_rect(seg, true, clip)
	return seg

## Segment for software-clipped (axis aligned) draws: any segment whose clip contains dest works.
func seg_for_rect(dest: Rect2) -> RID:
	if cur >= 0 and not segment_repeat[cur] and segment_mats[cur] == _material_rid:
		var c: Rect2 = segment_clips[cur]
		if c.size.x < 0 or c.encloses(dest):
			return segments[cur]
	return _new_segment(Rect2(0, 0, -1, -1))

## Segment for GPU-clipped draws (transformed sprites).
func seg_for_clip(clip: Rect2, repeat: bool = false) -> RID:
	var want := clip
	if clip.position.x <= 0 and clip.position.y <= 0 and clip.end.x >= screen_rect.size.x and clip.end.y >= screen_rect.size.y:
		want = Rect2(0, 0, -1, -1)
	if cur >= 0 and segment_clips[cur] == want and segment_repeat[cur] == repeat and segment_mats[cur] == _material_rid:
		return segments[cur]
	return _new_segment(want, repeat)

## Segment drawn with a custom material (always a fresh segment so draw order is kept).
func seg_for_material(clip: Rect2, mat: RID, repeat: bool = false) -> RID:
	var want := clip
	if clip.position.x <= 0 and clip.position.y <= 0 and clip.end.x >= screen_rect.size.x and clip.end.y >= screen_rect.size.y:
		want = Rect2(0, 0, -1, -1)
	return _new_segment(want, repeat, mat)

static func encode(color: Color, draw_mode: int, filter: int) -> Color:
	var c := color
	c.a = clampf(c.a, 0.0, 1.0) + 4.0 * float(draw_mode + 2 * filter)
	return c

func free_all() -> void:
	for rid in segments:
		RenderingServer.free_rid(rid)
	segments.clear()
	segment_clips.clear()
	segment_repeat.clear()
	segment_mats.clear()
	segment_xforms.clear()
	segment_xform_set.clear()
	cur = -1
