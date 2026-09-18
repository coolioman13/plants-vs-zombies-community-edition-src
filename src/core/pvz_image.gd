class_name PvzImage
extends RefCounted
## Equivalent of Sexy::Image as used by the game: a texture plus cel grid information.

var texture: Texture2D
var rid: RID
var width := 0
var height := 0
var num_rows := 1
var num_cols := 1
var id := ""
var path := ""

func _init(tex: Texture2D = null, rows: int = 1, cols: int = 1) -> void:
	if tex != null:
		set_texture(tex)
	num_rows = maxi(rows, 1)
	num_cols = maxi(cols, 1)

func set_texture(tex: Texture2D) -> void:
	texture = tex
	rid = tex.get_rid()
	width = tex.get_width()
	height = tex.get_height()

func get_cel_width() -> int:
	@warning_ignore("integer_division")
	return width / num_cols

func get_cel_height() -> int:
	@warning_ignore("integer_division")
	return height / num_rows

func get_cel_rect(col: int, row: int = 0) -> Rect2:
	var cw := get_cel_width()
	var ch := get_cel_height()
	return Rect2(col * cw, row * ch, cw, ch)

func duplicate_grid(rows: int, cols: int) -> PvzImage:
	var img := PvzImage.new(texture, rows, cols)
	img.id = id
	img.path = path
	return img
