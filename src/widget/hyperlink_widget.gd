class_name HyperlinkWidget
extends ButtonWidget
## Port of Sexy::HyperlinkWidget.

var color := Color.WHITE
var over_color := Color.WHITE
var underline_offset := 3
var underline_size := 1

func _init(the_id: int = 0, the_listener: Object = null) -> void:
	super._init(the_id, the_listener)
	do_finger = true

func draw(g: Graphics) -> void:
	if font == null:
		font = Res.get_font("FONT_BRIANNETOD12")
	var text := TodStrings.translate(label)
	var fx := Tod.idiv(width - font.string_width(text), 2)
	var fy := Tod.idiv(height + font.get_ascent(), 2) - 1
	g.color = over_color if is_over else color
	g.font = font
	g.draw_string(text, fx, fy)
	for i in underline_size:
		g.fill_rect(fx, fy + underline_offset + i, font.string_width(text), 1)
