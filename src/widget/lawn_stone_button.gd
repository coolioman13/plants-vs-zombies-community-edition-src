class_name LawnStoneButton
extends DialogButton

func draw(g: Graphics) -> void:
	if btn_no_draw:
		return
	var down := (is_down and is_over and not disabled) != inverted
	LawnButtons.draw_stone_button(g, 0, 0, width, height, down, is_over, TodStrings.translate(label))
