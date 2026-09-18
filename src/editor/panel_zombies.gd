class_name PanelZombies
extends EditorPanel
## Custom zombie maker. A custom zombie picks a behaviour template, then sets its own health,
## armour, speed, bite strength, size, colour, animation and per-part art. Waves and scripts can
## spawn it by name, and it keeps the template's full behaviour on the lawn.

const L_ZOMBIES := 1
const L_TRACKS := 2
const L_ASSETS := 3
const B_ADD := 10
const B_DELETE := 11
const B_DUPLICATE := 12
const B_SKIN_PART := 13
const B_CLEAR_PART := 14
const F_NAME := 20
const F_DESC := 21
const F_DEATH_EVENT := 22
const S_BASE := 23
const S_HEALTH := 24
const S_HELM := 25
const S_SHIELD := 26
const S_SPEED := 27
const S_DAMAGE := 28
const S_SCALE := 29
const S_TINT_R := 30
const S_TINT_G := 31
const S_TINT_B := 32
const S_REANIM := 33
const T_FREEZE := 40
const T_INSTAKILL := 41
const T_HYPNO := 42
const T_EXPLODE := 43

const LIST_W := 230

var zombie_list: EditorUi.ScrollList
var track_list: EditorUi.ScrollList
var asset_list: EditorUi.ScrollList
var selected := 0
var selected_track := 0
var selected_asset := 0
var tracks: Array = []
var image_keys: Array = []
var reanim_keys: Array = []
var preview: Reanimation = null
var preview_cid := -1

func current() -> Dictionary:
	var l := level()
	if selected < 0 or selected >= l.custom_zombies.size():
		return {}
	return l.custom_zombies[selected]

func build() -> void:
	var l := level()
	selected = clampi(selected, 0, maxi(0, l.custom_zombies.size() - 1))
	add_button_row_bottom([[B_ADD, "New zombie"], [B_DUPLICATE, "Copy"], [B_DELETE, "Delete"]],
		PAD, PAD + LIST_W)
	zombie_list = add_list(L_ZOMBIES, PAD, 40, LIST_W, bottom_row_y - 50, 34)
	zombie_list.count = l.custom_zombies.size()
	zombie_list.selected = selected
	zombie_list.empty_text = "No custom zombies yet."
	zombie_list.draw_row = Callable(self, "_draw_zombie_row")

	var z := current()
	if z.is_empty():
		return
	var rx := PAD * 2 + LIST_W
	var rw := width - rx - PAD
	var col_w := 356
	var RH := 30
	var y := 38
	add_field(F_NAME, "Name", str(z.get("name", "")), rx, y, col_w, 118)
	y += RH
	add_field(F_DESC, "Almanac text", str(z.get("description", "")), rx, y, col_w, 118)
	y += RH
	var bases: Array = []
	var base_index := 0
	for i in CustomDefs.ZOMBIE_TEMPLATES.size():
		bases.append(str(CustomDefs.ZOMBIE_TEMPLATES[i].label))
		if int(CustomDefs.ZOMBIE_TEMPLATES[i].base) == int(z.get("base", PvZ.ZOMBIE_NORMAL)):
			base_index = i
	add_choice(S_BASE, "Behaves like", base_index, bases, rx, y, col_w, 118)
	y += RH + 6

	stats_y = y
	y += 26
	add_stepper(S_HEALTH, "Body health", int(z.get("health", 270)), 1, 100000, 50, rx, y, col_w, 118)
	y += RH
	add_stepper(S_HELM, "Helmet health", int(z.get("helm_health", -1)), -1, 20000, 50, rx, y, col_w, 118)
	y += RH
	add_stepper(S_SHIELD, "Shield health", int(z.get("shield_health", -1)), -1, 20000, 50, rx, y, col_w, 118)
	y += RH
	var sp := add_stepper(S_SPEED, "Speed", float(z.get("speed", 1.0)), 0.1, 5.0, 0.05, rx, y, col_w, 118)
	sp.decimals = 2
	sp.suffix = " x"
	y += RH
	add_stepper(S_DAMAGE, "Bite strength", int(z.get("damage", 100)), 0, 1000, 10, rx, y, col_w, 118).suffix = "%"
	y += RH
	var sc := add_stepper(S_SCALE, "Size", float(z.get("scale", 1.0)), 0.3, 3.0, 0.05, rx, y, col_w, 118)
	sc.decimals = 2
	sc.suffix = " x"
	y += RH
	var tint: Array = z.get("tint", [255, 255, 255])
	add_stepper(S_TINT_R, "Colour: red", int(tint[0]), 0, 255, 5, rx, y, col_w, 118)
	y += RH
	add_stepper(S_TINT_G, "Colour: green", int(tint[1]), 0, 255, 5, rx, y, col_w, 118)
	y += RH
	add_stepper(S_TINT_B, "Colour: blue", int(tint[2]), 0, 255, 5, rx, y, col_w, 118)
	y += RH + 4

	traits_y = y
	y += 26
	add_toggle(T_FREEZE, "Cannot be chilled or frozen", bool(z.get("freeze_immune", false)), rx, y, col_w)
	y += 25
	add_toggle(T_INSTAKILL, "Survives instant kills", bool(z.get("instakill_immune", false)), rx, y, col_w)
	y += 25
	add_toggle(T_HYPNO, "Cannot be mind controlled", bool(z.get("hypno_immune", false)), rx, y, col_w)
	y += 25
	add_toggle(T_EXPLODE, "Explodes when it dies", bool(z.get("explode_on_death", false)), rx, y, col_w)
	y += 28
	add_field(F_DEATH_EVENT, "Death broadcasts", str(z.get("death_event", "")), rx, y, col_w, 118)

	# ---------------------------------------------------------------- reskin column
	var sx := rx + col_w + 14
	var sw := width - sx - PAD
	reanim_keys = _asset_keys("reanim")
	var rnames: Array = ["(base zombie art)"]
	for k in reanim_keys:
		rnames.append(str(k).get_file())
	add_choice(S_REANIM, "Animation", reanim_keys.find(str(z.get("reanim", ""))) + 1, rnames, sx, 40, sw, 90)
	_refresh_tracks()
	image_keys = _asset_keys("image")
	var half := Tod.idiv(sw - 8, 2)
	add_button_row_bottom([[B_SKIN_PART, "Skin this part"], [B_CLEAR_PART, "Clear part"]],
		sx, width - PAD)
	var list_h := bottom_row_y - 116
	track_list = add_list(L_TRACKS, sx, 106, half, list_h, 24)
	track_list.count = tracks.size()
	track_list.selected = selected_track
	track_list.empty_text = "No parts."
	track_list.draw_row = Callable(self, "_draw_track_row")
	asset_list = add_list(L_ASSETS, sx + half + 8, 106, half, list_h, 24)
	asset_list.count = image_keys.size()
	asset_list.selected = selected_asset
	asset_list.empty_text = "Add images on the Art tab."
	asset_list.draw_row = Callable(self, "_draw_asset_row")

var stats_y := 0
var traits_y := 0

func teardown() -> void:
	_kill_preview()
	super.teardown()

func _kill_preview() -> void:
	if preview != null and not preview.freed:
		preview.die()
	preview = null
	preview_cid = -1

func _asset_keys(kind: String) -> Array:
	var out: Array = []
	for k in level().assets:
		if str(level().assets[k].get("type", "")) == kind:
			out.append(str(k))
	out.sort()
	return out

func _refresh_tracks() -> void:
	tracks = []
	var z := current()
	if z.is_empty():
		return
	var rt: int = LawnCommon.zombie_def(int(z.get("base", PvZ.ZOMBIE_NORMAL)))[LawnCommon.ZDEF_REANIM]
	rt = CustomDefs.zombie_reanim_type(int(z.get("cid", -1)), rt)
	if rt >= 0:
		tracks = CustomAssets.track_names(rt)
	selected_track = clampi(selected_track, 0, maxi(0, tracks.size() - 1))

# ================================================================ drawing
func _draw_zombie_row(g: Graphics, index: int, r: Rect2, hovered: bool, sel: bool) -> void:
	var l := level()
	if index >= l.custom_zombies.size():
		return
	EditorUi.draw_slot(g, r, hovered, sel)
	var z: Dictionary = l.custom_zombies[index]
	EditorUi.draw_zombie_portrait(g, int(z.get("base", PvZ.ZOMBIE_NORMAL)),
		r.position.x + 20, r.position.y + r.size.y - 2, 0.2)
	var f := EditorUi.font_body()
	EditorUi.draw_text(g, EditorUi.elide(str(z.get("name", "")), f, int(r.size.x - 44)),
		int(r.position.x + 42), int(r.position.y + r.size.y * 0.5 + f.get_ascent() * 0.5) - 2, f,
		EditorUi.TEXT_CREAM)

func _draw_track_row(g: Graphics, index: int, r: Rect2, hovered: bool, sel: bool) -> void:
	if index >= tracks.size():
		return
	EditorUi.draw_slot(g, r, hovered, sel)
	var z := current()
	var parts: Dictionary = z.get("part_skins", {})
	var track := str(tracks[index])
	var f := EditorUi.font_small()
	EditorUi.draw_text(g, EditorUi.elide(track, f, int(r.size.x - 10)), int(r.position.x + 6),
		int(r.position.y + r.size.y * 0.5 + f.get_ascent() * 0.5) - 1, f,
		EditorUi.TEXT_GREEN if parts.has(track) else EditorUi.TEXT_CREAM)

func _draw_asset_row(g: Graphics, index: int, r: Rect2, hovered: bool, sel: bool) -> void:
	if index >= image_keys.size():
		return
	EditorUi.draw_slot(g, r, hovered, sel)
	var key := str(image_keys[index])
	var img := CustomAssets.get_image(key)
	if img != null:
		var s: float = minf(18.0 / maxf(img.width, 1.0), 18.0 / maxf(img.height, 1.0))
		g.draw_image_scaled_size(img, r.position.x + 3, r.position.y + 3, img.width * s, img.height * s)
	var f := EditorUi.font_small()
	EditorUi.draw_text(g, EditorUi.elide(key.get_file(), f, int(r.size.x - 30)), int(r.position.x + 24),
		int(r.position.y + r.size.y * 0.5 + f.get_ascent() * 0.5) - 1, f, EditorUi.TEXT_CREAM)

func draw_content(g: Graphics) -> void:
	section(g, "Custom zombies", PAD, 14, LIST_W)
	var rx := PAD * 2 + LIST_W
	var rw := width - rx - PAD
	if current().is_empty():
		section(g, "Zombie maker", rx, 14, rw)
		hint(g, "Make a zombie, choose what it behaves like on the lawn, then change its health, " + "armour, speed, bite, size and colour.\n\nLoad your own .reanim on the Art tab and pick it " + "here to replace the whole animation, or skin single body parts - a head, a cone, an arm - " + "with your own images. Waves and scripts can then spawn it by name.", rx, 48, rw)
		return
	section(g, "Identity and behaviour", rx, 14, rw - 250)
	section(g, "Numbers", rx, stats_y, 356)
	section(g, "Traits", rx, traits_y, 356)
	var sx := rx + 370
	section(g, "Art", sx, 14, width - sx - PAD)
	label(g, "Body part", sx, 88, EditorUi.TEXT_GOLD)
	label(g, "Image", sx + Tod.idiv(width - sx - PAD - 8, 2) + 8, 88, EditorUi.TEXT_GOLD)
	_draw_preview(g)

func _draw_preview(g: Graphics) -> void:
	var z := current()
	var cid := int(z.get("cid", -1))
	var base := int(z.get("base", PvZ.ZOMBIE_NORMAL))
	var rt: int = LawnCommon.zombie_def(base)[LawnCommon.ZDEF_REANIM]
	rt = CustomDefs.zombie_reanim_type(cid, rt)
	if rt < 0:
		return
	if preview == null or preview.freed or preview_cid != cid:
		_kill_preview()
		preview = App.add_reanimation(0.0, 0.0, 0, rt)
		preview.is_attachment = true
		EditorUi.tame_preview(preview)
		Zombie.setup_reanim_layers(preview, base)
		if preview.track_exists("anim_walk"):
			preview.play_reanim("anim_walk", Reanimation.REANIM_LOOP, 0, 12.0)
		elif preview.track_exists("anim_idle"):
			preview.play_reanim("anim_idle", Reanimation.REANIM_LOOP, 0, 12.0)
		CustomAssets.apply_part_dict(preview, z.get("part_skins", {}))
		preview_cid = cid
	var box := Rect2(PAD, height - 232, LIST_W, 168)
	EditorUi.draw_shade(g, box, 0.32)
	var cg := g.copy()
	cg.clip_rect(box.position.x, box.position.y, box.size.x, box.size.y)
	var tint: Array = z.get("tint", [255, 255, 255])
	preview.color_override = Color8(int(tint[0]), int(tint[1]), int(tint[2]))
	# the size setting is meant to show, so use it as a ceiling rather than a fixed scale
	EditorUi.fit_preview(preview, box, 0.6 * float(z.get("scale", 1.0)))
	preview.draw(cg)

func update() -> void:
	super.update()
	if preview != null and not preview.freed:
		preview.update()
	var z := current()
	if z.is_empty():
		return
	for c in _controls:
		if c is EditorUi.TextField and c.has_focus:
			var f: EditorUi.TextField = c
			match f.id:
				F_NAME:
					if str(z.get("name", "")) != f.text:
						z["name"] = f.text
						mark_dirty()
				F_DESC:
					if str(z.get("description", "")) != f.text:
						z["description"] = f.text
						mark_dirty()
				F_DEATH_EVENT:
					if str(z.get("death_event", "")) != f.text:
						z["death_event"] = f.text
						mark_dirty()

# ================================================================ callbacks
func editor_list_click(id: int, index: int, _mx: int, _btn: int, clicks: int) -> void:
	match id:
		L_ZOMBIES:
			selected = index
			selected_track = 0
			_kill_preview()
			rebuild()
		L_TRACKS:
			selected_track = index
			if clicks >= 2:
				_skin_part()
		L_ASSETS:
			selected_asset = index
			if clicks >= 2:
				_skin_part()

func editor_stepper(id: int, value: float) -> void:
	var z := current()
	if z.is_empty():
		return
	var tint: Array = z.get("tint", [255, 255, 255])
	match id:
		S_BASE:
			z["base"] = int(CustomDefs.ZOMBIE_TEMPLATES[clampi(int(value), 0, CustomDefs.ZOMBIE_TEMPLATES.size() - 1)].base)
			z["part_skins"] = {}
		S_HEALTH: z["health"] = int(value)
		S_HELM: z["helm_health"] = int(value)
		S_SHIELD: z["shield_health"] = int(value)
		S_SPEED: z["speed"] = value
		S_DAMAGE: z["damage"] = int(value)
		S_SCALE: z["scale"] = value
		S_TINT_R: tint[0] = int(value)
		S_TINT_G: tint[1] = int(value)
		S_TINT_B: tint[2] = int(value)
		S_REANIM:
			var index := int(value) - 1
			z["reanim"] = str(reanim_keys[index]) if index >= 0 and index < reanim_keys.size() else ""
			z["part_skins"] = {}
	z["tint"] = tint
	_apply()

func editor_toggle(id: int, value: bool) -> void:
	var z := current()
	if z.is_empty():
		return
	match id:
		T_FREEZE: z["freeze_immune"] = value
		T_INSTAKILL: z["instakill_immune"] = value
		T_HYPNO: z["hypno_immune"] = value
		T_EXPLODE:
			z["explode_on_death"] = value
			if value and int(z.get("explode_damage", 0)) == 0:
				z["explode_damage"] = 300
	mark_dirty()

func button_depress(bid: int) -> void:
	var l := level()
	match bid:
		B_ADD:
			var z := CustomDefs.default_zombie(l.next_custom_id(l.custom_zombies))
			z["name"] = "Custom Zombie %d" % (l.custom_zombies.size() + 1)
			l.custom_zombies.append(z)
			selected = l.custom_zombies.size() - 1
		B_DUPLICATE:
			var src := current()
			if src.is_empty():
				return
			var copy := src.duplicate(true)
			copy["cid"] = l.next_custom_id(l.custom_zombies)
			copy["name"] = str(src.get("name", "Zombie")) + " copy"
			l.custom_zombies.append(copy)
			selected = l.custom_zombies.size() - 1
		B_DELETE:
			if current().is_empty():
				return
			var cid := int(current().get("cid", -1))
			l.custom_zombies.remove_at(selected)
			for w in l.waves:
				w.entries = (w.entries as Array).filter(func(e): return int(e.get("custom", -1)) != cid)
			selected = clampi(selected, 0, maxi(0, l.custom_zombies.size() - 1))
		B_SKIN_PART:
			_skin_part()
			return
		B_CLEAR_PART:
			var z2 := current()
			if not z2.is_empty() and selected_track < tracks.size():
				(z2.get("part_skins", {}) as Dictionary).erase(str(tracks[selected_track]))
			_apply()
			return
	_apply()

func _skin_part() -> void:
	var z := current()
	if z.is_empty():
		return
	if selected_track < 0 or selected_track >= tracks.size():
		toast("Pick a body part first.", EditorUi.TEXT_RED)
		return
	if selected_asset < 0 or selected_asset >= image_keys.size():
		toast("Add an image on the Art tab first.", EditorUi.TEXT_RED)
		return
	var parts: Dictionary = z.get("part_skins", {})
	parts[str(tracks[selected_track])] = str(image_keys[selected_asset])
	z["part_skins"] = parts
	toast("%s now uses \"%s\"." % [tracks[selected_track], str(image_keys[selected_asset]).get_file()])
	_apply()

func _apply() -> void:
	screen.reinstall()
	_kill_preview()
	mark_dirty()
	rebuild()
