class_name PoolEffect
extends RefCounted
## Port of PoolEffect: the animated pool mesh (base + shading layers) and the caustic light overlay.
## The caustic texture math runs in pool_caustic.gdshader instead of rewriting a 128x64 image on the CPU.

const CAUSTIC_IMAGE_WIDTH := 128
const CAUSTIC_IMAGE_HEIGHT := 64

var pool_counter := 0
var _caustic_material: ShaderMaterial

func pool_effect_initialize() -> void:
	_caustic_material = ShaderMaterial.new()
	_caustic_material.shader = load("res://src/system/pool_caustic.gdshader")
	var gray := Res.get_image("IMAGE_POOL_CAUSTIC_EFFECT")
	if gray:
		_caustic_material.set_shader_parameter("caustic_gray", gray.texture)

func pool_effect_dispose() -> void:
	_caustic_material = null

func pool_effect_update() -> void:
	pool_counter += 1

func pool_effect_draw(g: Graphics, is_night: bool) -> void:
	if not App.is_3d_accel():
		g.draw_image(Res.get_image("IMAGE_POOL_NIGHT" if is_night else "IMAGE_POOL"), 34, 278)
		return
	var pool := Res.get_image("IMAGE_POOL")
	var grid_x := pool.width / 15.0
	var grid_y := pool.height / 5.0
	var off0: Array = []
	var off1: Array = []
	var off2: Array = []
	for gx in 16:
		var c0: Array = []
		var c1: Array = []
		var c2: Array = []
		for gy in 6:
			var o0 := Vector2.ZERO
			var o1 := Vector2.ZERO
			var o2 := Vector2(gx / 15.0, gy / 5.0)
			if gx != 0 and gx != 15 and gy != 0 and gy != 5:
				var phase := pool_counter * 2 * PI
				var t1 := phase / 800.0
				var t2 := phase / 150.0
				var t3 := phase / 900.0
				var t4 := phase / 800.0
				var t5 := phase / 110.0
				var xp := gx * 3.0 * 2 * PI / 15.0
				var yp := gy * 3.0 * 2 * PI / 5.0
				o0 = Vector2(sin(yp + t2) * 0.002 + sin(yp + t1) * 0.005,
					sin(xp + t5) * 0.01 + sin(xp + t3) * 0.015 + sin(xp + t4) * 0.005)
				o1 = Vector2(sin(yp * 0.2 + t2) * 0.015 + sin(yp * 0.2 + t1) * 0.012,
					sin(xp * 0.2 + t5) * 0.005 + sin(xp * 0.2 + t3) * 0.015 + sin(xp * 0.2 + t4) * 0.02)
				o2 += Vector2(sin(yp + t1 * 1.5) * 0.004 + sin(yp + t2 * 1.5) * 0.005,
					sin(xp * 4.0 + t5 * 2.5) * 0.005 + sin(xp * 2.0 + t3 * 2.5) * 0.04 + sin(xp * 3.0 + t4 * 2.5) * 0.02)
			c0.append(o0)
			c1.append(o1)
			c2.append(o2)
		off0.append(c0)
		off1.append(c1)
		off2.append(c2)
	var idx_x := [0, 0, 1, 0, 1, 1]
	var idx_y := [0, 1, 1, 0, 1, 0]
	var tris0: Array = []
	var tris1: Array = []
	var tris2: Array = []
	# Graphics::mClipRect is in translated (local) coordinates in the original.
	var clip := Rect2(g.clip.position - Vector2(g.trans_x, g.trans_y), g.clip.size)
	var transparent := Color8(255, 255, 255, 0)
	for gx in 15:
		for gy in 5:
			var t0: Array = []
			var t1: Array = []
			var t2: Array = []
			for vi in 6:
				var ix: int = gx + idx_x[vi]
				var iy: int = gy + idx_y[vi]
				var bx := ix * grid_x + 35.0
				var by := iy * grid_y + 279.0
				var base_col := Color.WHITE if clip.has_point(Vector2(bx, by)) else transparent
				var o0: Vector2 = off0[ix][iy]
				var o1: Vector2 = off1[ix][iy]
				t0.append([bx, by, o0.x + ix / 15.0, o0.y + iy / 5.0, base_col])
				t1.append([bx, by, o1.x + ix / 15.0, o1.y + iy / 5.0, base_col])
				var cx := (704.0 / 15.0) * ix + 45.0
				var cy := 30.0 * iy + 288.0
				var ccol: Color
				if not clip.has_point(Vector2(cx, cy)):
					ccol = transparent
				elif ix == 0 or ix == 15 or iy == 0:
					ccol = Color8(255, 255, 255, 0x20)
				elif is_night:
					ccol = Color8(255, 255, 255, 0x30)
				else:
					ccol = Color8(255, 255, 255, 0xC0 if ix <= 7 else 0x80)
				var o2: Vector2 = off2[ix][iy]
				t2.append([cx, cy, o2.x + ix / 15.0, o2.y + iy / 5.0, ccol])
				if t0.size() == 3:
					tris0.append(t0)
					tris1.append(t1)
					tris2.append(t2)
					t0 = []
					t1 = []
					t2 = []
	if is_night:
		g.draw_triangles_tex(Res.get_image("IMAGE_POOL_BASE_NIGHT"), tris0)
		g.draw_triangles_tex(Res.get_image("IMAGE_POOL_SHADING_NIGHT"), tris1)
	else:
		g.draw_triangles_tex(Res.get_image("IMAGE_POOL_BASE"), tris0)
		g.draw_triangles_tex(Res.get_image("IMAGE_POOL_SHADING"), tris1)
	_draw_caustics(g, tris2)

func _draw_caustics(g: Graphics, tris: Array) -> void:
	if g.target == null or _caustic_material == null:
		return
	var gray := Res.get_image("IMAGE_POOL_CAUSTIC_EFFECT")
	if gray == null:
		return
	_caustic_material.set_shader_parameter("pool_counter", pool_counter)
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var uvs := PackedVector2Array()
	for tri in tris:
		for v in tri:
			pts.append(Vector2(v[0] + g.trans_x, v[1] + g.trans_y))
			uvs.append(Vector2(v[2], v[3]))
			cols.append(v[4])
	var seg := g.target.seg_for_material(g.clip, _caustic_material.get_rid(), true)
	g._set_xform(seg, Transform2D.IDENTITY)
	RenderingServer.canvas_item_add_triangle_array(seg, PackedInt32Array(), pts, cols, uvs, PackedInt32Array(), PackedFloat32Array(), gray.rid)
