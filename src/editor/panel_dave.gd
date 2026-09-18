class_name PanelDave
extends EditorPanel
## Crazy Dave's dialogue: what he says before the level, what he shouts mid-level on a given wave,
## and what he says once it is won. Lines use the same {HANDING} / {NO_SOUND} markers the base game
## does, and a live portrait shows him reading whichever line is selected.

const T_ENABLED := 1
const A_INTRO := 2
const A_WIN := 3
const L_WAVE_LINES := 4
const B_ADD_LINE := 10
const B_DEL_LINE := 11
const S_LINE_WAVE := 12
const F_LINE_TEXT := 13
const B_PREVIEW := 14

const LEFT_W := 470

var intro_area: EditorUi.TextArea
var win_area: EditorUi.TextArea
var wave_list: EditorUi.ScrollList
var selected_line := 0
var dave_reanim: Reanimation = null
var preview_text := ""
var preview_timer := 0

func build() -> void:
	var l := level()
	add_toggle(T_ENABLED, "Crazy Dave appears in this level", l.dave_enabled, PAD, 38, LEFT_W)
	if not l.dave_enabled:
		return
	intro_area = add_text_area(A_INTRO, PAD, 100, LEFT_W, 150)
	intro_area.set_lines(l.dave_intro)
	win_area = add_text_area(A_WIN, PAD, 296, LEFT_W, 110)
	win_area.set_lines(l.dave_win)

	var rx := PAD * 2 + LEFT_W
	var rw := width - rx - PAD
	wave_list = add_list(L_WAVE_LINES, rx, 100, rw, 168, 30)
	wave_list.count = l.dave_wave_lines.size()
	wave_list.selected = selected_line
	wave_list.empty_text = "No mid-level lines yet."
	wave_list.draw_row = Callable(self, "_draw_line_row")
	add_button_row([[B_ADD_LINE, "Add line"], [B_DEL_LINE, "Remove"]], rx, 276, width - PAD)
	if selected_line >= 0 and selected_line < l.dave_wave_lines.size():
		var e: Dictionary = l.dave_wave_lines[selected_line]
		add_stepper(S_LINE_WAVE, "Wave", int(e.get("wave", 0)) + 1, 1, maxi(1, l.waves.size()), 1, rx, 314, rw, 70)
		add_field(F_LINE_TEXT, "Says", str(e.get("text", "")), rx, 348, rw, 70)
	add_button(B_PREVIEW, "Hear it", rx, height - 46, 0, 28)

func teardown() -> void:
	_kill_dave()
	super.teardown()

func _kill_dave() -> void:
	if dave_reanim != null and not dave_reanim.freed:
		dave_reanim.die()
	dave_reanim = null

# ================================================================ drawing
func _draw_line_row(g: Graphics, index: int, r: Rect2, hovered: bool, selected: bool) -> void:
	var l := level()
	if index >= l.dave_wave_lines.size():
		return
	EditorUi.draw_slot(g, r, hovered, selected)
	var e: Dictionary = l.dave_wave_lines[index]
	var f := EditorUi.font_body()
	var ty := int(r.position.y + r.size.y * 0.5 + f.get_ascent() * 0.5) - 2
	EditorUi.draw_text(g, "Wave %d" % (int(e.get("wave", 0)) + 1), int(r.position.x + 8), ty, f, EditorUi.TEXT_GOLD)
	EditorUi.draw_text(g, EditorUi.elide(str(e.get("text", "")), f, int(r.size.x - 90)),
		int(r.position.x + 78), ty, f, EditorUi.TEXT_CREAM)

func draw_content(g: Graphics) -> void:
	var l := level()
	section(g, "Crazy Dave", PAD, 14, LEFT_W)
	if not l.dave_enabled:
		hint(g, "Turn this on to give the level its own dialogue. Dave rolls in before the level " + "starts, reads the intro lines one at a time as the player clicks, and can be told to " + "say more on any wave.\n\nScripts can also make him talk at any moment with the " + "\"Crazy Dave says\" block.", PAD, 74, width - PAD * 2)
		return
	section(g, "Before the level (one line per click)", PAD, 76, LEFT_W)
	section(g, "After winning", PAD, 272, LEFT_W)
	var rx := PAD * 2 + LEFT_W
	var rw := width - rx - PAD
	section(g, "Mid-level lines", rx, 76, rw)
	hint(g, "{HANDING} makes him hold something out, {NO_SOUND} keeps him quiet.",
		PAD, 254, LEFT_W)
	_draw_dave(g, rx, rw)

func _draw_dave(g: Graphics, rx: int, rw: int) -> void:
	var box := Rect2(rx, 390, rw, height - 440)
	var cg := g.copy()
	cg.clip_rect(box.position.x, box.position.y, box.size.x, box.size.y)
	if dave_reanim != null and not dave_reanim.freed:
		EditorUi.fit_preview(dave_reanim, box, 0.62)
		dave_reanim.draw(cg)
	else:
		EditorUi.draw_text(cg, "Press \"Hear it\" to watch him read the selected line.",
			rx + Tod.idiv(rw, 2), 450, EditorUi.font_small(), EditorUi.TEXT_DIM, TodStrings.DS_ALIGN_CENTER)
	if preview_timer > 0 and preview_text != "":
		var caption := Rect2(rx, height - 92, rw, 40)
		EditorUi.draw_shade(g, caption, 0.55)
		EditorUi.draw_text(g, EditorUi.elide(preview_text, EditorUi.font_body(), rw - 12),
			rx + 6, height - 66, EditorUi.font_body(), EditorUi.TEXT_CREAM)

func update() -> void:
	super.update()
	if dave_reanim != null and not dave_reanim.freed:
		dave_reanim.update()
	if preview_timer > 0:
		preview_timer -= 1
	var l := level()
	if selected_line >= 0 and selected_line < l.dave_wave_lines.size():
		for c in _controls:
			if c is EditorUi.TextField and c.has_focus and c.id == F_LINE_TEXT:
				var e: Dictionary = l.dave_wave_lines[selected_line]
				if str(e.get("text", "")) != c.text:
					e["text"] = c.text
					mark_dirty()

# ================================================================ callbacks
func editor_toggle(id: int, value: bool) -> void:
	if id == T_ENABLED:
		level().dave_enabled = value
		mark_dirty()
		rebuild()

func editor_textarea_changed(id: int, lines: Array) -> void:
	if id == A_INTRO:
		level().dave_intro = lines
	elif id == A_WIN:
		level().dave_win = lines
	mark_dirty()

func editor_list_click(id: int, index: int, _mx: int, _btn: int, _clicks: int) -> void:
	if id == L_WAVE_LINES:
		selected_line = index
		rebuild()

func editor_stepper(id: int, value: float) -> void:
	if id == S_LINE_WAVE and selected_line < level().dave_wave_lines.size():
		level().dave_wave_lines[selected_line]["wave"] = int(value) - 1
		mark_dirty()

func button_depress(bid: int) -> void:
	var l := level()
	match bid:
		B_ADD_LINE:
			l.dave_wave_lines.append({"wave": mini(selected_line + 1, maxi(0, l.waves.size() - 1)),
				"text": "Careful, they're coming!"})
			selected_line = l.dave_wave_lines.size() - 1
			mark_dirty()
			rebuild()
		B_DEL_LINE:
			if selected_line >= 0 and selected_line < l.dave_wave_lines.size():
				l.dave_wave_lines.remove_at(selected_line)
				selected_line = clampi(selected_line, 0, maxi(0, l.dave_wave_lines.size() - 1))
				mark_dirty()
				rebuild()
		B_PREVIEW:
			_preview()

func _preview() -> void:
	var l := level()
	var text := ""
	if selected_line >= 0 and selected_line < l.dave_wave_lines.size():
		text = str(l.dave_wave_lines[selected_line].get("text", ""))
	elif not l.dave_intro.is_empty():
		text = str(l.dave_intro[0])
	if text.strip_edges() == "":
		toast("Write a line first.", EditorUi.TEXT_RED)
		return
	preview_text = text
	preview_timer = 420
	_kill_dave()
	var r := App.add_reanimation(0.0, 0.0, 0, PvZ.REANIM_CRAZY_DAVE)
	r.is_attachment = true
	EditorUi.tame_preview(r)
	r.set_base_pose_from_anim("anim_idle_handing")
	r.play_reanim("anim_talk", Reanimation.REANIM_LOOP, 0, 18.0)
	dave_reanim = r
	App.play_foley(PvZ.FOLEY_CRAZY_DAVE_SHORT)
