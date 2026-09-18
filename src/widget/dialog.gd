class_name Dialog
extends Widget
## Port of Sexy::Dialog.

enum { BUTTONS_NONE, BUTTONS_YES_NO, BUTTONS_OK_CANCEL, BUTTONS_FOOTER }
const ID_YES := 1000
const ID_NO := 1001
const ID_FOOTER := 1000
enum { COLOR_HEADER, COLOR_LINES, COLOR_FOOTER, COLOR_BUTTON_TEXT, COLOR_BUTTON_TEXT_HILITE, COLOR_BKG, COLOR_OUTLINE }

var id := 0
var result := 0x7FFFFFFF
var is_modal := true
var dialog_header := ""
var dialog_lines := ""
var dialog_footer := ""
var button_mode := BUTTONS_NONE
var header_font: ImageFont
var lines_font: ImageFont
var text_align := 0
var line_spacing_offset := 0
var button_height := 24
var space_after_header := 10
var dragging := false
var drag_mouse_x := 0
var drag_mouse_y := 0
var content_insets := [24, 24, 24, 24]     # left, top, right, bottom
var background_insets := [0, 0, 0, 0]
var dialog_listener: Object
var _killed := false

## Emitted when the result is set or the dialog is killed (lets WaitForResult be an await).
signal result_changed

func _init(the_id: int = 0, modal: bool = true, header: String = "", lines: String = "", footer: String = "", mode: int = BUTTONS_NONE) -> void:
	id = the_id
	is_modal = modal
	dialog_header = header
	dialog_lines = lines
	dialog_footer = footer
	button_mode = mode
	priority = 1
	set_colors([[255, 255, 255], [255, 255, 0], [255, 255, 255], [0, 0, 0], [0, 0, 0], [80, 80, 80], [255, 255, 255]])

func mouse_down(mx: int, my: int, click_count: int) -> void:
	if click_count == 1:
		App.set_cursor(App.CURSOR_DRAGGING)
		dragging = true
		drag_mouse_x = mx
		drag_mouse_y = my
	super.mouse_down(mx, my, click_count)

func mouse_drag(mx: int, my: int) -> void:
	if dragging:
		var nx := x + mx - drag_mouse_x
		var ny := y + my - drag_mouse_y
		if nx < -8:
			nx = -8
		elif nx + width > PvZ.BOARD_WIDTH + 8:
			nx = PvZ.BOARD_WIDTH - width + 8
		if ny < -8:
			ny = -8
		elif ny + height > PvZ.BOARD_HEIGHT + 8:
			ny = PvZ.BOARD_HEIGHT - height + 8
		drag_mouse_x = clampi(x + mx - nx, 8, width - 9)
		drag_mouse_y = clampi(y + my - ny, 8, height - 9)
		move(nx, ny)

func mouse_up(mx: int, my: int, click_count: int) -> void:
	if dragging:
		App.set_cursor(App.CURSOR_POINTER)
		dragging = false
	super.mouse_up(mx, my, click_count)

func button_press(bid: int, _count: int = 1) -> void:
	if bid == ID_YES or bid == ID_NO:
		if dialog_listener and dialog_listener.has_method("dialog_button_press"):
			dialog_listener.dialog_button_press(id, bid)
		else:
			App.dialog_button_press(id, bid)

func button_depress(bid: int) -> void:
	if bid == ID_YES or bid == ID_NO:
		result = bid
		result_changed.emit()
		if dialog_listener and dialog_listener.has_method("dialog_button_depress"):
			dialog_listener.dialog_button_depress(id, bid)
		else:
			App.dialog_button_depress(id, bid)

func set_result(r: int) -> void:
	result = r
	result_changed.emit()

## Called by App.kill_dialog once the dialog has been removed.
func dialog_killed() -> void:
	_killed = true
	result_changed.emit()

## Dialog::WaitForResult as a coroutine: `var r = await dialog.wait_for_result(true)`.
func wait_for_result(auto_kill: bool = false) -> int:
	while result == 0x7FFFFFFF and not _killed:
		await result_changed
	if auto_kill:
		App.kill_dialog(id)
	return result

func get_preferred_height(w: int) -> int:
	var h: int = content_insets[1] + content_insets[3] + background_insets[1] + background_insets[3]
	var need_space := false
	if dialog_header.length() > 0 and header_font:
		h += header_font.get_height() - header_font.get_ascent_padding()
		need_space = true
	if dialog_lines.length() > 0 and lines_font:
		if need_space:
			h += space_after_header
		h += TextWriter.get_word_wrapped_height(lines_font, w - content_insets[0] - content_insets[2] - background_insets[0] - background_insets[2] - 4, dialog_lines, lines_font.get_line_spacing() + line_spacing_offset)
	return h
