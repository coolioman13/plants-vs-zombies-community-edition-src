class_name EditorPanel
extends Widget
## Base class for the editor's tab panels: a parchment sheet with helpers for laying out labelled
## rows of game-styled controls, plus no-op callbacks so a panel only implements what it uses.

const ROW_H := 32
const PAD := 18

var screen: EditorScreen
var scroll := 0
var scroll_max := 0
var _controls: Array = []
## Top of the last block laid out by [method add_button_row_bottom].
var bottom_row_y := 0

func level() -> LevelDef:
	return screen.level

func mark_dirty() -> void:
	screen.mark_dirty()

func toast(text: String, color: Color = EditorUi.TEXT_GREEN) -> void:
	screen.show_toast(text, color)

# ================================================================ lifecycle
## Creates this panel's widgets. Called once after the panel is added to the screen.
func build() -> void:
	pass

func rebuild() -> void:
	teardown()
	build()

func teardown() -> void:
	for c in _controls:
		remove_widget(c)
	_controls.clear()

func track(w: Widget) -> Widget:
	_controls.append(w)
	add_widget(w)
	return w

# ================================================================ control factories
## Buttons grow to fit their label: a clipped stone button reads as a bug, and the label is
## the only thing telling you what the button does.
func add_button(id: int, text: String, x: int, y: int, w: int, h: int = 30) -> EditorUi.StoneButton:
	var b := EditorUi.StoneButton.new(id, self, text, h <= 32)
	b.resize(x, y, maxi(w, EditorUi.button_width(text)), h)
	track(b)
	return b

## Lays a row of buttons out left to right, each sized to its own label, wrapping when it runs
## out of room. [param specs] is [[id, text], ...]. Returns the buttons in order.
func add_button_row(specs: Array, x: int, y: int, max_right: int, h: int = 28, gap: int = 6) -> Array:
	var out: Array = []
	var bx := x
	var by := y
	for spec in specs:
		var w := EditorUi.button_width(str(spec[1]))
		if bx > x and bx + w > max_right:
			bx = x
			by += h + 4
		var b := add_button(int(spec[0]), str(spec[1]), bx, by, w, h)
		out.append(b)
		bx += b.width + gap
	return out

## How many rows [method add_button_row] would need, so a caller can anchor the block to the
## bottom of the panel instead of letting it wrap off the sheet.
func button_row_rows(specs: Array, x: int, max_right: int, gap: int = 6) -> int:
	var rows := 1
	var bx := x
	for spec in specs:
		var w := EditorUi.button_width(str(spec[1]))
		if bx > x and bx + w > max_right:
			bx = x
			rows += 1
		bx += w + gap
	return rows

## Lays a wrapping button row along the bottom edge of the sheet, growing upwards so the last
## row always lands on the bottom margin. [member bottom_row_y] is where the block starts, which
## is what a list above it should stop at.
func add_button_row_bottom(specs: Array, x: int, max_right: int, h: int = 28, gap: int = 6) -> Array:
	var rows := button_row_rows(specs, x, max_right, gap)
	bottom_row_y = height - PAD - rows * (h + 4) + 4
	return add_button_row(specs, x, bottom_row_y, max_right, h, gap)

func add_toggle(id: int, text: String, value: bool, x: int, y: int, w: int) -> EditorUi.Toggle:
	var t := EditorUi.Toggle.new(id, self, text, value)
	t.resize(x, y, w, 26)
	track(t)
	return t

func add_stepper(id: int, text: String, value: float, lo: float, hi: float, step: float,
		x: int, y: int, w: int, label_w: int = 150) -> EditorUi.Stepper:
	var s := EditorUi.Stepper.new(id, self, text, value, lo, hi, step)
	s.label_width = maxi(label_w, EditorUi.caption_width(text))
	s.resize(x, y, w, 28)
	track(s)
	return s

func add_choice(id: int, text: String, value: int, names: Array, x: int, y: int, w: int,
		label_w: int = 150) -> EditorUi.Stepper:
	var s := add_stepper(id, text, float(value), 0.0, float(maxi(0, names.size() - 1)), 1.0, x, y, w, label_w)
	s.names = names
	s.big_step = 1.0
	return s

func add_field(id: int, text: String, value: String, x: int, y: int, w: int,
		label_w: int = 150) -> EditorUi.TextField:
	var f := EditorUi.TextField.new(id, self, text, value)
	f.caption_width = maxi(label_w, EditorUi.caption_width(text))
	f.resize(x, y, w, 28)
	track(f)
	return f

func add_list(id: int, x: int, y: int, w: int, h: int, row_h: int = 28) -> EditorUi.ScrollList:
	var l := EditorUi.ScrollList.new(id, self)
	l.row_height = row_h
	l.resize(x, y, w, h)
	track(l)
	return l

## The height is snapped down to whole rows, so the grid never shows a sliced row of packets.
func add_grid(id: int, x: int, y: int, w: int, h: int, cell: Vector2i) -> EditorUi.IconGrid:
	var gr := EditorUi.IconGrid.new(id, self)
	gr.cell = cell
	var pitch := cell.y + gr.gap.y
	var rows := maxi(1, Tod.idiv(h + gr.gap.y, pitch))
	gr.resize(x, y, w, rows * pitch - gr.gap.y)
	track(gr)
	return gr

func add_text_area(id: int, x: int, y: int, w: int, h: int) -> EditorUi.TextArea:
	var t := EditorUi.TextArea.new(id, self)
	t.resize(x, y, w, h)
	track(t)
	return t

# ================================================================ drawing helpers
func draw(g: Graphics) -> void:
	EditorUi.draw_frame(g, Rect2(0, 0, width, height), 0.5)
	draw_content(g)

func draw_content(_g: Graphics) -> void:
	pass

func section(g: Graphics, title: String, x: int, y: int, w: int) -> void:
	var f := EditorUi.font_head()
	EditorUi.draw_text(g, title, x, y + f.get_ascent(), f, EditorUi.TEXT_GOLD)
	g.color = Color8(140, 112, 64, 170)
	g.fill_rect(x, y + f.get_height() + 2, w, 1)

func hint(g: Graphics, text: String, x: int, y: int, w: int) -> int:
	return EditorUi.draw_wrapped(g, text, Rect2i(x, y, w, 200), EditorUi.font_small(), EditorUi.TEXT_DIM)

func label(g: Graphics, text: String, x: int, y: int, color: Color = Color8(212, 198, 168)) -> void:
	var f := EditorUi.font_body()
	EditorUi.draw_text(g, text, x, y + f.get_ascent(), f, color)

# ================================================================ callbacks (overridden as needed)
func editor_toggle(_id: int, _value: bool) -> void: pass
func editor_stepper(_id: int, _value: float) -> void: pass
func editor_list_click(_id: int, _index: int, _mx: int, _btn: int, _clicks: int) -> void: pass
func editor_grid_click(_id: int, _index: int, _btn: int) -> void: pass
func editor_textarea_changed(_id: int, _lines: Array) -> void: pass
func edit_widget_text(_id: int, _text: String) -> void: pass
func button_press(_bid: int, _count: int = 1) -> void:
	App.play_sample("SOUND_TAP")
func button_depress(_bid: int) -> void: pass

# ================================================================ shared pickers
## Seed types the editor offers: everything the base game has plus this level's custom plants.
static func all_seed_types() -> Array:
	var out: Array = []
	for st in PvZ.NUM_SEED_TYPES:
		if st == PvZ.SEED_SPROUT or st == PvZ.SEED_LEFTPEATER:
			continue
		out.append(st)
	for st in CustomDefs.custom_plant_seed_types():
		out.append(st)
	return out

static func seed_name(st: int) -> String:
	if CustomDefs.is_custom_plant(st):
		return CustomDefs.plant_name(st)
	if st < 0 or st >= LawnDefs.PLANT_DEFS.size():
		return "-"
	return _named(LawnCommon.plant_def(st)[LawnCommon.PDEF_NAME])

## Some types the base game never shows the player (the Versus-side plant zombies) have no name
## string, and "<Missing FOO>" in a picker reads as a broken editor. Title-case the key instead.
static func _named(key: String) -> String:
	var t := TodStrings.translate("[%s]" % key)
	if not t.begins_with("<Missing"):
		return t
	var words := key.to_lower().split("_", false)
	for i in words.size():
		words[i] = String(words[i]).capitalize()
	return " ".join(words)

static func zombie_name(zt: int) -> String:
	if zt < 0 or zt >= PvZ.NUM_ZOMBIE_TYPES:
		return "-"
	return _named(LawnCommon.zombie_def(zt)[LawnCommon.ZDEF_NAME])

## Zombie types worth offering in the wave editor (everything but the internal helpers).
static func all_zombie_types() -> Array:
	var out: Array = []
	for zt in PvZ.NUM_ZOMBIE_TYPES:
		if zt == PvZ.ZOMBIE_BOSS:
			continue
		out.append(zt)
	return out
