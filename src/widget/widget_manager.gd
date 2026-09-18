class_name WidgetManager
extends Widget
## Port of Sexy::WidgetManager: owns top level widgets, routes mouse/keyboard, modal handling.

const KEYCODE_BACK := 0x08
const KEYCODE_TAB := 0x09
const KEYCODE_RETURN := 0x0D
const KEYCODE_SHIFT := 0x10
const KEYCODE_CONTROL := 0x11
const KEYCODE_ESCAPE := 0x1B
const KEYCODE_SPACE := 0x20
const KEYCODE_PRIOR := 0x21
const KEYCODE_NEXT := 0x22
const KEYCODE_END := 0x23
const KEYCODE_HOME := 0x24
const KEYCODE_LEFT := 0x25
const KEYCODE_UP := 0x26
const KEYCODE_RIGHT := 0x27
const KEYCODE_DOWN := 0x28
const KEYCODE_DELETE := 0x2E
const KEYCODE_F1 := 0x70

var app: Node
var focus_widget: Widget = null
var over_widget: Widget = null
var last_down_widget: Widget = null
var base_modal_widget: Widget = null
var pre_modal_info: Array = []
var down_buttons := 0
var actual_down_buttons := 0
var last_mouse_x := 0
var last_mouse_y := 0
var mouse_in := true
var app_has_focus := true
var key_down_state: Dictionary = {}
var deferred_overlays: Array = []
var min_deferred_overlay_priority := 0x7FFFFFFF
var cur_g: Graphics
var update_counter := 0

func _init(the_app: Node) -> void:
	app = the_app
	widget_manager = self
	width = PvZ.BOARD_WIDTH
	height = PvZ.BOARD_HEIGHT
	clip = false

# ---------------------------------------------------------------- lifecycle
func add_widget(w: Widget) -> void:
	if widgets.has(w):
		return
	_insert_by_z(w)
	w.parent = null
	w.widget_manager = self
	w.added_to_manager(self)
	rehup_mouse()

func remove_widget(w: Widget) -> void:
	var idx := widgets.find(w)
	if idx == -1:
		return
	widgets.remove_at(idx)
	w.removed_from_manager(self)
	disable_widget(w)
	w.widget_manager = null
	rehup_mouse()

func disable_widget(w: Widget) -> void:
	if over_widget == w:
		var ow := over_widget
		over_widget = null
		_mouse_leave(ow)
	if last_down_widget == w:
		var ld := last_down_widget
		last_down_widget = null
		_do_mouse_ups(ld, down_buttons)
		down_buttons = 0
	if focus_widget == w:
		var fw := focus_widget
		focus_widget = null
		fw.lost_focus()
	if base_modal_widget == w:
		base_modal_widget = null

func is_below(w1: Widget, w2: Widget) -> bool:
	var found := [false]
	return _is_below_helper(self, w1, w2, found)

func _is_below_helper(cont: Widget, w1: Widget, w2: Widget, found: Array) -> bool:
	for w in cont.widgets:
		if w == w1:
			found[0] = true
			return true
		elif w == w2:
			found[0] = true
			return false
		var r := _is_below_helper(w, w1, w2, found)
		if found[0]:
			return r
	return false

# ---------------------------------------------------------------- modal
func add_base_modal(w: Widget) -> void:
	pre_modal_info.append({"widget": w, "prev_modal": base_modal_widget, "prev_focus": focus_widget})
	_set_base_modal(w)

func _set_base_modal(w: Widget) -> void:
	base_modal_widget = w
	if w == null:
		return
	if over_widget != null and is_below(over_widget, w):
		var ow := over_widget
		over_widget = null
		_mouse_leave(ow)
	if last_down_widget != null and is_below(last_down_widget, w):
		var ld := last_down_widget
		var db := down_buttons
		down_buttons = 0
		last_down_widget = null
		_do_mouse_ups(ld, db)
	if focus_widget != null and is_below(focus_widget, w):
		var fw := focus_widget
		focus_widget = null
		fw.lost_focus()

func remove_base_modal(w: Widget) -> void:
	var first := true
	while pre_modal_info.size() > 0:
		var info: Dictionary = pre_modal_info[pre_modal_info.size() - 1]
		if first and info.widget != w:
			return
		var done: bool = info.prev_modal != null or pre_modal_info.size() == 1
		_set_base_modal(info.prev_modal)
		if focus_widget == null:
			focus_widget = info.prev_focus
			if focus_widget != null and focus_widget.widget_manager == self:
				focus_widget.got_focus()
			else:
				focus_widget = null
		pre_modal_info.pop_back()
		if done:
			break
		first = false

func set_focus(w: Widget) -> void:
	if w == focus_widget:
		return
	if focus_widget != null:
		focus_widget.lost_focus()
	if w != null and w.widget_manager == self:
		focus_widget = w
		if app_has_focus:
			w.got_focus()
	else:
		focus_widget = null

# ---------------------------------------------------------------- hit testing
func get_widget_at(px: int, py: int) -> Array:
	## returns [widget or null, local Vector2i]
	var block_below := false
	for i in range(widgets.size() - 1, -1, -1):
		var w: Widget = widgets[i]
		if w.visible and not block_below:
			var out := [false, Vector2i()]
			var c := w.get_widget_at_helper(px - w.x, py - w.y, out)
			if c != null or out[0]:
				if c != null and c.disabled:
					return [null, Vector2i()]
				return [c, out[1]]
			if w.mouse_visible and w.get_inset_rect().has_point(Vector2i(px, py)):
				if w.is_point_visible(px - w.x, py - w.y):
					if w.disabled:
						return [null, Vector2i()]
					return [w, Vector2i(px - w.x, py - w.y)]
				return [null, Vector2i()]
		if w == base_modal_widget:
			block_below = true
	return [null, Vector2i()]

func _mouse_enter(w: Widget) -> void:
	w.is_over = true
	w.mouse_enter()
	if w.do_finger:
		w.show_finger(true)

func _mouse_leave(w: Widget) -> void:
	w.is_over = false
	w.mouse_leave()
	if w.do_finger:
		w.show_finger(false)

func _do_mouse_ups(w: Widget, codes: int) -> void:
	var table := [1, -1, 3]
	for i in 3:
		if (codes & (1 << i)) != 0:
			w.is_down = false
			var ap := w.get_abs_pos()
			w.mouse_up(last_mouse_x - ap.x, last_mouse_y - ap.y, table[i])

func mouse_position(px: int, py: int) -> void:
	var lx := last_mouse_x
	var ly := last_mouse_y
	last_mouse_x = px
	last_mouse_y = py
	var r := get_widget_at(px, py)
	var w: Widget = r[0]
	if w != over_widget:
		var last := over_widget
		over_widget = null
		if last != null:
			_mouse_leave(last)
		over_widget = w
		if w != null:
			_mouse_enter(w)
			w.mouse_move(r[1].x, r[1].y)
	elif lx != px or ly != py:
		if w != null:
			w.mouse_move(r[1].x, r[1].y)

func rehup_mouse() -> void:
	if last_down_widget != null:
		if over_widget != null:
			var r := get_widget_at(last_mouse_x, last_mouse_y)
			if r[0] != last_down_widget:
				var ow := over_widget
				over_widget = null
				_mouse_leave(ow)
	elif mouse_in:
		mouse_position(last_mouse_x, last_mouse_y)

# ---------------------------------------------------------------- input entry points
func on_mouse_down(px: int, py: int, click_count: int) -> void:
	var mask := 0x02 if click_count < 0 else (0x04 if click_count == 3 else 0x01)
	actual_down_buttons |= mask
	mouse_position(px, py)
	var r := get_widget_at(px, py)
	var w: Widget = r[0]
	var local: Vector2i = r[1]
	if last_down_widget != null:
		w = last_down_widget
		var ap := w.get_abs_pos()
		local = Vector2i(px - ap.x, py - ap.y)
	down_buttons |= mask
	last_down_widget = w
	if w != null:
		if w.wants_focus:
			set_focus(w)
		w.is_down = true
		w.mouse_down(local.x, local.y, click_count)

func on_mouse_up(px: int, py: int, click_count: int) -> void:
	var mask := 0x02 if click_count < 0 else (0x04 if click_count == 3 else 0x01)
	actual_down_buttons &= ~mask
	if last_down_widget != null and (down_buttons & mask) != 0:
		var ld := last_down_widget
		down_buttons &= ~mask
		if down_buttons == 0:
			last_down_widget = null
		ld.is_down = false
		var ap := ld.get_abs_pos()
		ld.mouse_up(px - ap.x, py - ap.y, click_count)
	else:
		down_buttons &= ~mask
	mouse_position(px, py)

func on_mouse_move(px: int, py: int) -> void:
	if down_buttons != 0:
		on_mouse_drag(px, py)
		return
	mouse_in = true
	mouse_position(px, py)

func on_mouse_drag(px: int, py: int) -> void:
	mouse_in = true
	last_mouse_x = px
	last_mouse_y = py
	if over_widget != null and over_widget != last_down_widget:
		var ow := over_widget
		over_widget = null
		_mouse_leave(ow)
	if last_down_widget != null:
		var ap := last_down_widget.get_abs_pos()
		last_down_widget.mouse_drag(px - ap.x, py - ap.y)
		var r := get_widget_at(px, py)
		if last_down_widget != null and r[0] == last_down_widget:
			if over_widget == null:
				over_widget = last_down_widget
				_mouse_enter(over_widget)
		elif over_widget != null:
			var ow2 := over_widget
			over_widget = null
			_mouse_leave(ow2)

func on_mouse_exit() -> void:
	mouse_in = false
	if over_widget != null:
		_mouse_leave(over_widget)
		over_widget = null

## The wheel goes to whatever is under the cursor, bubbling up to its parents, and only falls back
## to the focus widget when nothing there wants it. Screens that scroll are their own focus widget,
## so they still get it exactly as before.
func on_mouse_wheel(delta: int) -> void:
	var w := over_widget
	while w != null:
		if w.mouse_wheel(delta):
			return
		w = w.parent
	if focus_widget != null:
		focus_widget.mouse_wheel(delta)

func on_key_char(ch: String) -> void:
	if focus_widget != null:
		focus_widget.key_char(ch)

func on_key_down(key: int) -> void:
	key_down_state[key] = true
	if focus_widget != null:
		focus_widget.key_down(key)

func on_key_up(key: int) -> void:
	key_down_state[key] = false
	if focus_widget != null:
		focus_widget.key_up(key)

func is_key_down(key: int) -> bool:
	return key_down_state.get(key, false)

func is_left_button_down() -> bool:
	return (actual_down_buttons & 1) != 0

func on_got_focus() -> void:
	if not app_has_focus:
		app_has_focus = true
		if focus_widget != null:
			focus_widget.got_focus()

func on_lost_focus() -> void:
	if app_has_focus:
		actual_down_buttons = 0
		for k in key_down_state.keys():
			if key_down_state[k]:
				on_key_up(k)
		app_has_focus = false
		if focus_widget != null:
			focus_widget.lost_focus()

# ---------------------------------------------------------------- frame
func update_frame() -> void:
	update_counter += 1
	for w in widgets.duplicate():
		if w.widget_manager == self:
			w.update_all([])

func add_deferred_overlay(w: Widget, prio: int) -> void:
	deferred_overlays.append([w, prio])
	if prio < min_deferred_overlay_priority:
		min_deferred_overlay_priority = prio

func flush_deferred_overlay_widgets(max_priority: int) -> void:
	while true:
		var next_min := 0x7FFFFFFF
		for e in deferred_overlays:
			var w: Widget = e[0]
			if w == null:
				continue
			var p: int = e[1]
			if p == min_deferred_overlay_priority:
				var g := cur_g.copy()
				var ap := w.get_abs_pos()
				g.translate(ap.x, ap.y)
				w.draw_overlay(g, p)
				e[0] = null
			elif p < next_min:
				next_min = p
		min_deferred_overlay_priority = next_min
		if next_min == 0x7FFFFFFF:
			deferred_overlays.clear()
			break
		if next_min >= max_priority:
			break

func draw_screen(g: Graphics) -> void:
	min_deferred_overlay_priority = 0x7FFFFFFF
	deferred_overlays.clear()
	cur_g = g
	for w in widgets.duplicate():
		if w.visible:
			var cg := g.copy()
			cg.translate(w.x, w.y)
			w.draw_all(cg)
	flush_deferred_overlay_widgets(0x7FFFFFFF)
	cur_g = null
