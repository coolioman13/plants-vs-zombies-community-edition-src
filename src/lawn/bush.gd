class_name Bush
extends GameObject
## Port of Bush (the widescreen right-edge bushes that rustle when zombies walk in).

const BUSH_REANIMS := [PvZ.REANIM_BUSH3, PvZ.REANIM_BUSH5, PvZ.REANIM_BUSH4, PvZ.REANIM_BUSH3_NIGHT, PvZ.REANIM_BUSH5_NIGHT, PvZ.REANIM_BUSH4_NIGHT]
const BUSH_POS := [[950, 40], [962, 168], [968, 258], [972, 378], [964, 459], [980, 510]]
const BUSH_POS_6_ROWS := [[952, 42], [964, 170], [968, 258], [974, 380], [966, 461], [979, 509]]

var pos_x := 0
var pos_y := 0
var id := 0
var bush_index := 0
var reanim: Reanimation = null

func bush_initialize(the_row: int, night: bool) -> void:
	var index := (the_row + 3) % 3
	if night:
		index += 3
	var six: bool = App.board.stage_has_6_rows()
	pos_x = BUSH_POS_6_ROWS[the_row][0] if six else BUSH_POS[the_row][0]
	pos_y = BUSH_POS_6_ROWS[the_row][1] if six else BUSH_POS[the_row][1]
	id = the_row
	bush_index = index
	render_order = BoardCore.make_render_order(PvZ.RENDER_LAYER_ZOMBIE, the_row + 1, 0)
	reanim = App.add_reanimation(pos_x, pos_y, render_order, BUSH_REANIMS[bush_index])
	reanim.play_reanim("base bush", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 0, 0.001)

func _get_reanim() -> Reanimation:
	if reanim == null or reanim.freed:
		return null
	return reanim

func animate_bush() -> void:
	var r := _get_reanim()
	if r:
		r.play_reanim("anim_rustle", Reanimation.REANIM_PLAY_ONCE_AND_HOLD, 10, Tod.rand_range_float(8.0, 10.0))

func update() -> void:
	var r := _get_reanim()
	if r:
		r.update()

func draw(g: Graphics) -> void:
	var r := _get_reanim()
	if r:
		r.draw(g)
