class_name GameObject
extends RefCounted
## Port of GameObject: common positional data for plants, zombies, projectiles, coins, seed packets...

var x := 0
var y := 0
var width := 0
var height := 0
var visible := true
var row := -1
var render_order := PvZ.RENDER_LAYER_TOP
var dead := false
## Set once the owning Board list has dropped the object (DataArrayFree).
var freed := false
## Holder slot for Attachment helpers (plants/zombies/projectiles/coins own attachments).
var attachment: Attachment = null

func begin_draw(g: Graphics) -> bool:
	if not visible:
		return false
	g.translate(x, y)
	return true

func end_draw(g: Graphics) -> void:
	g.translate(-x, -y)

func make_parent_graphics_frame(g: Graphics) -> void:
	g.translate(-x, -y)
