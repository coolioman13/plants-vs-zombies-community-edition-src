class_name Widget
extends RefCounted
## Port of Sexy::Widget / WidgetContainer.

var x := 0
var y := 0
var width := 0
var height := 0
var visible := true
var mouse_visible := true
var disabled := false
var has_focus := false
var is_down := false
var is_over := false
var do_finger := false
var wants_focus := false
var clip := true
var priority := 0
var z_order := 0
var update_cnt := 0
var mouse_insets := Rect2i()
var colors: Array = []
var widgets: Array = []
var parent: Widget = null
var widget_manager: WidgetManager = null
var write_colored_string := true

func resize(nx: int, ny: int, w: int, h: int) -> void:
	x = nx
	y = ny
	width = w
	height = h

func move(nx: int, ny: int) -> void:
	resize(nx, ny, width, height)

func set_visible(v: bool) -> void:
	visible = v
	if widget_manager and not v:
		widget_manager.rehup_mouse()

func set_disabled(d: bool) -> void:
	disabled = d
	if widget_manager and d:
		widget_manager.disable_widget(self)

func set_color(idx: int, c: Color) -> void:
	while colors.size() <= idx:
		colors.append(Color.BLACK)
	colors[idx] = c

func get_color(idx: int, default: Color = Color.BLACK) -> Color:
	return colors[idx] if idx < colors.size() else default

func set_colors(list: Array) -> void:
	colors.clear()
	for c in list:
		colors.append(Color8(c[0], c[1], c[2], c[3] if c.size() > 3 else 255))

func mark_dirty() -> void:
	pass

func mark_all_dirty() -> void:
	pass

# ---------------------------------------------------------------- containment
func add_widget(w: Widget) -> void:
	if widgets.has(w):
		return
	_insert_by_z(w)
	w.parent = self
	w.widget_manager = widget_manager
	if widget_manager != null:
		w.added_to_manager(widget_manager)
		widget_manager.rehup_mouse()

func _insert_by_z(w: Widget) -> void:
	var i := widgets.size()
	while i > 0 and (widgets[i - 1] as Widget).z_order > w.z_order:
		i -= 1
	widgets.insert(i, w)

func remove_widget(w: Widget) -> void:
	var idx := widgets.find(w)
	if idx == -1:
		return
	widgets.remove_at(idx)
	if widget_manager != null:
		w.removed_from_manager(widget_manager)
		widget_manager.disable_widget(w)
	w.parent = null
	w.widget_manager = null

func has_widget(w: Widget) -> bool:
	return widgets.has(w)

func remove_all_widgets() -> void:
	for w in widgets.duplicate():
		remove_widget(w)

func bring_to_front(w: Widget) -> void:
	var idx := widgets.find(w)
	if idx != -1:
		widgets.remove_at(idx)
		widgets.append(w)
		_order_changed(w)

func bring_to_back(w: Widget) -> void:
	var idx := widgets.find(w)
	if idx != -1:
		widgets.remove_at(idx)
		widgets.insert(0, w)
		_order_changed(w)

func put_behind(w: Widget, ref: Widget) -> void:
	var idx := widgets.find(w)
	if idx == -1:
		return
	widgets.remove_at(idx)
	var r := widgets.find(ref)
	widgets.insert(maxi(r, 0), w)
	_order_changed(w)

func put_infront(w: Widget, ref: Widget) -> void:
	var idx := widgets.find(w)
	if idx == -1:
		return
	widgets.remove_at(idx)
	var r := widgets.find(ref)
	widgets.insert(r + 1, w)
	_order_changed(w)

## Widget::OrderInManagerChanged notification.
func _order_changed(w: Widget) -> void:
	if widget_manager != null and w.has_method("order_in_manager_changed"):
		w.order_in_manager_changed()

func added_to_manager(wm: WidgetManager) -> void:
	widget_manager = wm
	for w in widgets:
		w.widget_manager = wm
		w.added_to_manager(wm)

func removed_from_manager(wm: WidgetManager) -> void:
	for w in widgets:
		w.removed_from_manager(wm)
		wm.disable_widget(w)
		w.widget_manager = null
	widget_manager = null

func get_abs_pos() -> Vector2i:
	var p := Vector2i(x, y)
	var par := parent
	while par != null:
		p += Vector2i(par.x, par.y)
		par = par.parent
	return p

func contains(px: int, py: int) -> bool:
	return px >= x and px < x + width and py >= y and py < y + height

func get_inset_rect() -> Rect2i:
	return Rect2i(x + mouse_insets.position.x, y + mouse_insets.position.y,
		width - mouse_insets.position.x - mouse_insets.size.x, height - mouse_insets.position.y - mouse_insets.size.y)

func is_point_visible(_px: int, _py: int) -> bool:
	return true

const LAY_SAME_WIDTH := 0x0001
const LAY_SAME_HEIGHT := 0x0002
const LAY_SET_LEFT := 0x0010
const LAY_SET_TOP := 0x0020
const LAY_SET_WIDTH := 0x0040
const LAY_SET_HEIGHT := 0x0080
const LAY_ABOVE := 0x0100
const LAY_BELOW := 0x0200
const LAY_RIGHT := 0x0400
const LAY_LEFT := 0x0800
const LAY_SAME_LEFT := 0x1000
const LAY_SAME_RIGHT := 0x2000
const LAY_SAME_TOP := 0x4000
const LAY_SAME_BOTTOM := 0x8000
const LAY_GROW_TO_RIGHT := 0x10000
const LAY_GROW_TO_LEFT := 0x20000
const LAY_GROW_TO_TOP := 0x40000
const LAY_GROW_TO_BOTTOM := 0x80000
const LAY_HCENTER := 0x100000
const LAY_VCENTER := 0x200000
const LAY_MAX := 0x400000

## Widget::Layout. Flags are applied in ascending bit order, like the original.
func layout(flags: int, rel: Widget, left_pad: int = 0, top_pad: int = 0, width_pad: int = 0, height_pad: int = 0) -> void:
	var rel_left := 0 if rel == parent else rel.x
	var rel_top := 0 if rel == parent else rel.y
	var rel_right := rel_left + rel.width
	var rel_bottom := rel_top + rel.height
	var l := x
	var t := y
	var w := width
	var h := height
	var bit := 1
	while bit < LAY_MAX:
		if flags & bit:
			match bit:
				LAY_SAME_WIDTH: w = rel.width + width_pad
				LAY_SAME_HEIGHT: h = rel.height + height_pad
				LAY_ABOVE: t = rel_top - h + top_pad
				LAY_BELOW: t = rel_bottom + top_pad
				LAY_RIGHT: l = rel_right + left_pad
				LAY_LEFT: l = rel_left - w + left_pad
				LAY_SAME_LEFT: l = rel_left + left_pad
				LAY_SAME_RIGHT: l = rel_right - w + left_pad
				LAY_SAME_TOP: t = rel_top + top_pad
				LAY_SAME_BOTTOM: t = rel_bottom - h + top_pad
				LAY_GROW_TO_RIGHT: w = rel_right - l + width_pad
				LAY_GROW_TO_LEFT: w = rel_left - l + width_pad
				LAY_GROW_TO_TOP: h = rel_top - t + height_pad
				LAY_GROW_TO_BOTTOM: h = rel_bottom - t + height_pad
				LAY_SET_LEFT: l = left_pad
				LAY_SET_TOP: t = top_pad
				LAY_SET_WIDTH: w = width_pad
				LAY_SET_HEIGHT: h = height_pad
				LAY_HCENTER: l = rel_left + Tod.idiv(rel.width - w, 2) + left_pad
				LAY_VCENTER: t = rel_top + Tod.idiv(rel.height - h, 2) + top_pad
		bit <<= 1
	resize(l, t, w, h)

# ---------------------------------------------------------------- virtuals
func update() -> void:
	update_cnt += 1

func draw(_g: Graphics) -> void:
	pass

func draw_overlay(_g: Graphics, _priority: int = 0) -> void:
	pass

func show_finger(on: bool) -> void:
	if widget_manager == null:
		return
	App.set_cursor(App.CURSOR_HAND if on else App.CURSOR_POINTER)

func defer_overlay(prio: int = 0) -> void:
	if widget_manager:
		widget_manager.add_deferred_overlay(self, prio)

func got_focus() -> void:
	has_focus = true

func lost_focus() -> void:
	has_focus = false

func key_char(_ch: String) -> void:
	pass

func key_down(_key: int) -> void:
	pass

func key_up(_key: int) -> void:
	pass

func mouse_enter() -> void:
	pass

func mouse_leave() -> void:
	pass

func mouse_move(_mx: int, _my: int) -> void:
	pass

## click_count: 1 = left, 2 = left double, -1 = right, 3 = middle (PopCap convention)
func mouse_down(mx: int, my: int, click_count: int) -> void:
	if click_count == 3:
		mouse_down_btn(mx, my, 2, 1)
	elif click_count >= 0:
		mouse_down_btn(mx, my, 0, click_count)
	else:
		mouse_down_btn(mx, my, 1, -click_count)

func mouse_down_btn(_mx: int, _my: int, _btn: int, _count: int) -> void:
	pass

func mouse_up(mx: int, my: int, click_count: int) -> void:
	if click_count == 3:
		mouse_up_btn(mx, my, 2, 1)
	elif click_count >= 0:
		mouse_up_btn(mx, my, 0, click_count)
	else:
		mouse_up_btn(mx, my, 1, -click_count)

func mouse_up_btn(_mx: int, _my: int, _btn: int, _count: int) -> void:
	pass

func mouse_drag(_mx: int, _my: int) -> void:
	pass

## Returns true when this widget consumed the wheel; the manager walks up to the parent otherwise.
func mouse_wheel(_delta: int) -> bool:
	return false

# ---------------------------------------------------------------- recursion
func update_all(modal_block: Array) -> void:
	update()
	var i := 0
	var snapshot := widgets.duplicate()
	for w in snapshot:
		if w.parent == self:
			w.update_all(modal_block)
		i += 1

func draw_all(g: Graphics) -> void:
	if widget_manager and priority > widget_manager.min_deferred_overlay_priority:
		widget_manager.flush_deferred_overlay_widgets(priority)
	if clip:
		g.clip_rect(0, 0, width, height)
	var gs := g.copy()
	draw(gs)
	for w in widgets.duplicate():
		if w.visible:
			var cg := g.copy()
			cg.translate(w.x, w.y)
			w.draw_all(cg)

func get_widget_at_helper(px: int, py: int, out: Array) -> Widget:
	## out[0] = found flag, out[1] = local pos
	for i in range(widgets.size() - 1, -1, -1):
		var w: Widget = widgets[i]
		if not w.visible:
			continue
		var child_out := [false, Vector2i()]
		var c := w.get_widget_at_helper(px - w.x, py - w.y, child_out)
		if c != null or child_out[0]:
			out[0] = true
			out[1] = child_out[1]
			return c
		if w.mouse_visible and w.get_inset_rect().has_point(Vector2i(px, py)):
			out[0] = true
			if w.is_point_visible(px - w.x, py - w.y):
				out[1] = Vector2i(px - w.x, py - w.y)
				return w
	out[0] = false
	return null

# ---------------------------------------------------------------- text helpers (Widget::WriteXXX)
func write_centered_line(g: Graphics, offset: int, line: String) -> Rect2i:
	var f := g.font
	var w := f.string_width(line)
	var ax := Tod.idiv(width - w, 2)
	g.draw_string(line, ax, offset)
	return Rect2i(ax, offset - f.get_ascent(), w, f.get_height())

func write_centered_line_shadow(g: Graphics, offset: int, line: String, c1: Color, c2: Color, shadow: Vector2i = Vector2i(1, 2)) -> void:
	var f := g.font
	var w := f.string_width(line)
	g.color = c2
	g.draw_string(line, Tod.idiv(width - w, 2) + shadow.x, offset + shadow.y)
	g.color = c1
	g.draw_string(line, Tod.idiv(width - w, 2), offset)

func write_word_wrapped(g: Graphics, rect: Rect2i, line: String, line_spacing: int, justification: int) -> int:
	return TextWriter.write_word_wrapped(g, rect, line, line_spacing, justification, write_colored_string)

func get_word_wrapped_height(g: Graphics, w: int, line: String, line_spacing: int) -> int:
	return TextWriter.get_word_wrapped_height(g.font, w, line, line_spacing)
