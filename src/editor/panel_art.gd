class_name PanelArt
extends EditorPanel
## Custom art. The left column is the level's own asset library (images, reanims, music); the right
## column is the reskinner: swap a whole reanim, swap individual body parts inside one, or replace
## any image the game loads by id. Everything here is scoped to this level only.

const MODE_REANIM := 0
const MODE_PARTS := 1
const MODE_IMAGES := 2
const MODE_NAMES := ["Whole reanim", "Body parts", "Any game image"]

const L_ASSETS := 1
const L_TARGETS := 2
const L_TRACKS := 3
const B_IMPORT_IMAGE := 10
const B_IMPORT_REANIM := 11
const B_IMPORT_SOUND := 12
const B_REMOVE_ASSET := 13
const B_PRUNE := 14
const B_ASSIGN := 15
const B_UNASSIGN := 16
const B_SET_MUSIC := 17
const S_MODE := 20
const F_FILTER := 21

const LEFT_W := 340

var asset_list: EditorUi.ScrollList
var target_list: EditorUi.ScrollList
var track_list: EditorUi.ScrollList
var mode := MODE_REANIM
var asset_keys: Array = []
var targets: Array = []          ## mode-dependent: reanim slots or image ids
var tracks: Array = []
var selected_asset := 0
var selected_target := 0
var selected_track := 0
var filter := ""
var preview_reanim: Reanimation = null
var preview_type := -1

func build() -> void:
	_refresh_assets()
	add_button_row_bottom([[B_IMPORT_IMAGE, "Add image"], [B_IMPORT_REANIM, "Add reanim"],
		[B_IMPORT_SOUND, "Add music"], [B_REMOVE_ASSET, "Remove"], [B_PRUNE, "Delete unused"],
		[B_SET_MUSIC, "Use as music"]], PAD, PAD + LEFT_W)
	asset_list = add_list(L_ASSETS, PAD, 66, LEFT_W, bottom_row_y - 76, 28)
	asset_list.count = asset_keys.size()
	asset_list.selected = selected_asset
	asset_list.empty_text = "No custom art yet."
	asset_list.draw_row = Callable(self, "_draw_asset_row")

	var rx := PAD * 2 + LEFT_W
	var rw := width - rx - PAD
	add_choice(S_MODE, "Reskin", mode, MODE_NAMES, rx, 38, rw, 80)

	_refresh_targets()
	var list_w := Tod.idiv(rw - 12, 2) if mode == MODE_PARTS else rw
	add_button_row_bottom([[B_ASSIGN, "Apply selected art"], [B_UNASSIGN, "Clear this skin"]],
		rx, width - PAD, 30)
	# the hint under the buttons needs a line or two of its own
	var right_list_h := bottom_row_y - 158
	target_list = add_list(L_TARGETS, rx, 104, list_w, right_list_h, 26)
	target_list.count = targets.size()
	target_list.selected = selected_target
	target_list.empty_text = "Nothing to reskin here."
	target_list.draw_row = Callable(self, "_draw_target_row")

	if mode == MODE_PARTS:
		_refresh_tracks()
		track_list = add_list(L_TRACKS, rx + list_w + 12, 104, list_w, right_list_h, 26)
		track_list.count = tracks.size()
		track_list.selected = selected_track
		track_list.empty_text = "Pick a reanim on the left."
		track_list.draw_row = Callable(self, "_draw_track_row")


func teardown() -> void:
	_kill_preview()
	super.teardown()

func _kill_preview() -> void:
	if preview_reanim != null and not preview_reanim.freed:
		preview_reanim.die()
	preview_reanim = null
	preview_type = -1

# ================================================================ data
func _refresh_assets() -> void:
	asset_keys = level().assets.keys()
	asset_keys.sort()
	selected_asset = clampi(selected_asset, 0, maxi(0, asset_keys.size() - 1))

func _refresh_targets() -> void:
	var l := level()
	targets = []
	match mode:
		MODE_REANIM, MODE_PARTS:
			for e in CustomAssets.skinnable_reanims():
				targets.append(e)
		MODE_IMAGES:
			for id in _skinnable_image_ids():
				targets.append({"id": id})
	selected_target = clampi(selected_target, 0, maxi(0, targets.size() - 1))

func _refresh_tracks() -> void:
	tracks = []
	if selected_target < 0 or selected_target >= targets.size():
		return
	tracks = CustomAssets.track_names(int(targets[selected_target].type))
	selected_track = clampi(selected_track, 0, maxi(0, tracks.size() - 1))

## Image ids worth offering: backgrounds, UI furniture and the seed packet sheet, which is what
## people actually want to reskin. Anything else can still be reached by typing its id.
static func _skinnable_image_ids() -> Array:
	return ["IMAGE_BACKGROUND1", "IMAGE_BACKGROUND2", "IMAGE_BACKGROUND3", "IMAGE_BACKGROUND4",
		"IMAGE_BACKGROUND5", "IMAGE_BACKGROUND6BOSS", "IMAGE_BACKGROUND1UNSODDED",
		"IMAGE_BACKGROUND_GREENHOUSE", "IMAGE_BACKGROUND_MUSHROOMGARDEN", "IMAGE_AQUARIUM1",
		"IMAGE_SEEDBANK", "IMAGE_SEEDS", "IMAGE_SEEDPACKET_LARGER", "IMAGE_SUNBANK",
		"IMAGE_SHOVEL", "IMAGE_SHOVELBANK", "IMAGE_FLAGMETER", "IMAGE_FLAGMETERPARTS",
		"IMAGE_TOMBSTONES", "IMAGE_CRATER", "IMAGE_POOL_CLEANER", "IMAGE_BUTTON_LEFT",
		"IMAGE_BUTTON_MIDDLE", "IMAGE_BUTTON_RIGHT", "IMAGE_SUN", "IMAGE_ZOMBIE_HEAD"]

func _current_target_label() -> String:
	if selected_target < 0 or selected_target >= targets.size():
		return ""
	var t: Dictionary = targets[selected_target]
	return str(t.get("label", t.get("id", "")))

func _selected_asset_key() -> String:
	if selected_asset < 0 or selected_asset >= asset_keys.size():
		return ""
	return str(asset_keys[selected_asset])

func _asset_type(key: String) -> String:
	return str(level().assets.get(key, {}).get("type", ""))

# ================================================================ drawing
func _draw_asset_row(g: Graphics, index: int, r: Rect2, hovered: bool, selected: bool) -> void:
	if index >= asset_keys.size():
		return
	EditorUi.draw_slot(g, r, hovered, selected)
	var key := str(asset_keys[index])
	var kind := _asset_type(key)
	var f := EditorUi.font_body()
	var ty := int(r.position.y + r.size.y * 0.5 + f.get_ascent() * 0.5) - 2
	var col := EditorUi.TEXT_CREAM
	if kind == "reanim":
		col = EditorUi.TEXT_GOLD
	elif kind == "sound":
		col = Color8(140, 190, 240)
	if kind == "image":
		var img := CustomAssets.get_image(key)
		if img != null:
			var s: float = minf(22.0 / maxf(img.width, 1.0), 22.0 / maxf(img.height, 1.0))
			g.draw_image_scaled_size(img, r.position.x + 4, r.position.y + 2, img.width * s, img.height * s)
	EditorUi.draw_text(g, EditorUi.elide(key.get_file(), f, int(r.size.x - 40)),
		int(r.position.x + 30), ty, f, col)

func _draw_target_row(g: Graphics, index: int, r: Rect2, hovered: bool, selected: bool) -> void:
	if index >= targets.size():
		return
	EditorUi.draw_slot(g, r, hovered, selected)
	var t: Dictionary = targets[index]
	var f := EditorUi.font_small()
	var ty := int(r.position.y + r.size.y * 0.5 + f.get_ascent() * 0.5) - 1
	var label := str(t.get("label", t.get("id", "")))
	var assigned := ""
	var l := level()
	if mode == MODE_REANIM:
		assigned = str(l.reanim_skins.get(str(int(t.type)), ""))
	elif mode == MODE_PARTS:
		var d: Dictionary = l.part_skins.get(str(int(t.type)), {})
		if not d.is_empty():
			assigned = "%d part%s" % [d.size(), "" if d.size() == 1 else "s"]
	else:
		assigned = str(l.image_skins.get(str(t.id), ""))
	EditorUi.draw_text(g, EditorUi.elide(label, f, int(r.size.x - 110)), int(r.position.x + 8), ty, f,
		EditorUi.TEXT_GREEN if assigned != "" else EditorUi.TEXT_CREAM)
	if assigned != "":
		EditorUi.draw_text(g, EditorUi.elide(assigned.get_file(), f, 100), int(r.end.x - 8), ty, f,
			EditorUi.TEXT_GOLD, TodStrings.DS_ALIGN_RIGHT)

func _draw_track_row(g: Graphics, index: int, r: Rect2, hovered: bool, selected: bool) -> void:
	if index >= tracks.size():
		return
	EditorUi.draw_slot(g, r, hovered, selected)
	var track := str(tracks[index])
	var f := EditorUi.font_small()
	var ty := int(r.position.y + r.size.y * 0.5 + f.get_ascent() * 0.5) - 1
	var rt := int(targets[selected_target].type)
	var d: Dictionary = level().part_skins.get(str(rt), {})
	var skinned := d.has(track)
	var img := CustomAssets.track_preview_image(rt, track)
	if img != null:
		var s: float = minf(20.0 / maxf(img.width, 1.0), 20.0 / maxf(img.height, 1.0))
		g.draw_image_scaled_size(img, r.position.x + 3, r.position.y + 3, img.width * s, img.height * s)
	EditorUi.draw_text(g, EditorUi.elide(track, f, int(r.size.x - 34)), int(r.position.x + 28), ty, f,
		EditorUi.TEXT_GREEN if skinned else EditorUi.TEXT_CREAM)

func draw_content(g: Graphics) -> void:
	section(g, "Art in this level", PAD, 14, LEFT_W)
	hint(g, "Files are copied into the level folder, so exporting carries them with it.", PAD, 40, LEFT_W)
	var rx := PAD * 2 + LEFT_W
	var rw := width - rx - PAD
	section(g, "Reskin", rx, 14, rw)
	var note := ""
	match mode:
		MODE_REANIM:
			note = "Replaces a whole animation with your own .reanim. Track names inside it should " + "match the original's so the game can still pose it."
		MODE_PARTS:
			note = "Swaps one image inside an animation - a zombie's head, cone, arm, anything. " + "Pick the animation, pick the part, pick the picture."
		MODE_IMAGES:
			note = "Replaces any image the game loads by resource id, for this level only."
	hint(g, note, rx, bottom_row_y - 50, rw)
	if mode == MODE_PARTS:
		_draw_part_preview(g, rx, rw)

func _draw_part_preview(g: Graphics, rx: int, rw: int) -> void:
	if selected_target < 0 or selected_target >= targets.size():
		return
	var rt := int(targets[selected_target].type)
	if preview_reanim == null or preview_reanim.freed or preview_type != rt:
		_kill_preview()
		preview_reanim = App.add_reanimation(0.0, 0.0, 0, rt)
		preview_reanim.is_attachment = true
		EditorUi.tame_preview(preview_reanim)
		if preview_reanim.track_exists("anim_idle"):
			preview_reanim.play_reanim("anim_idle", Reanimation.REANIM_LOOP, 0, 12.0)
		preview_type = rt
	var box := Rect2(rx + rw - 210, 104, 200, 200)
	var cg := g.copy()
	cg.clip_rect(box.position.x, box.position.y, box.size.x, box.size.y)
	cg.color = Color(0, 0, 0, 0.3)
	cg.fill_rect_r(box)
	EditorUi.fit_preview(preview_reanim, box, 0.9)
	preview_reanim.draw(cg)

func update() -> void:
	super.update()
	if preview_reanim != null and not preview_reanim.freed:
		preview_reanim.update()

# ================================================================ callbacks
func editor_stepper(id: int, value: float) -> void:
	if id == S_MODE:
		mode = int(value)
		selected_target = 0
		selected_track = 0
		_kill_preview()
		rebuild()

func editor_list_click(id: int, index: int, _mx: int, _btn: int, clicks: int) -> void:
	match id:
		L_ASSETS:
			selected_asset = index
			if clicks >= 2:
				_assign()
		L_TARGETS:
			selected_target = index
			selected_track = 0
			_kill_preview()
			rebuild()
		L_TRACKS:
			selected_track = index
			if clicks >= 2:
				_assign()

func button_depress(bid: int) -> void:
	match bid:
		B_IMPORT_IMAGE: _import("image")
		B_IMPORT_REANIM: _import("reanim")
		B_IMPORT_SOUND: _import("sound")
		B_REMOVE_ASSET: _remove_asset()
		B_PRUNE:
			var n := CustomLevels.prune_assets(level())
			screen.reinstall()
			mark_dirty()
			rebuild()
			toast("Deleted %d unused file%s." % [n, "" if n == 1 else "s"])
		B_ASSIGN: _assign()
		B_UNASSIGN: _unassign()
		B_SET_MUSIC:
			var key := _selected_asset_key()
			if _asset_type(key) != "sound":
				toast("Pick a music file first.", EditorUi.TEXT_RED)
				return
			level().music_custom = key
			mark_dirty()
			toast("\"%s\" will play in this level." % key.get_file())

# ================================================================ importing
func _import(kind: String) -> void:
	var filters: PackedStringArray
	match kind:
		"image": filters = PackedStringArray(["*.png,*.jpg,*.jpeg,*.webp,*.bmp;Images"])
		"reanim": filters = PackedStringArray(["*.reanim;PopCap reanimations"])
		_: filters = PackedStringArray(["*.ogg,*.mp3,*.wav;Audio"])
	if DisplayServer.has_feature(DisplayServer.FEATURE_NATIVE_DIALOG_FILE):
		DisplayServer.file_dialog_show("Add %s to \"%s\"" % [kind, level().level_name],
			CustomLevels.start_browse_dir(), "", false, DisplayServer.FILE_DIALOG_MODE_OPEN_FILE,
			filters, Callable(self, "_on_file_chosen").bind(kind))
		return
	toast("No file picker on this system - drop files into %s and use Add again." %
		ProjectSettings.globalize_path(CustomLevels.asset_dir(level().id)), EditorUi.TEXT_RED)

func _on_file_chosen(ok: bool, paths: PackedStringArray, _index: int, kind: String) -> void:
	if not ok or paths.is_empty():
		return
	var l := level()
	var key := ""
	if kind == "reanim":
		key = CustomLevels.import_reanim_folder(l, paths[0])
	else:
		key = CustomLevels.import_asset(l, paths[0], kind)
	if key == "":
		toast("That file could not be read.", EditorUi.TEXT_RED)
		return
	screen.save_level(true)
	screen.reinstall()
	mark_dirty()
	_refresh_assets()
	selected_asset = asset_keys.find(key)
	rebuild()
	toast("Added \"%s\"." % key.get_file())

func _remove_asset() -> void:
	var key := _selected_asset_key()
	if key == "":
		return
	var l := level()
	# forget anything pointing at it, then delete the file
	for k in l.reanim_skins.keys().duplicate():
		if str(l.reanim_skins[k]) == key:
			l.reanim_skins.erase(k)
	for k in l.part_skins.keys().duplicate():
		var d: Dictionary = l.part_skins[k]
		for t in d.keys().duplicate():
			if str(d[t]) == key:
				d.erase(t)
		if d.is_empty():
			l.part_skins.erase(k)
	for k in l.image_skins.keys().duplicate():
		if str(l.image_skins[k]) == key:
			l.image_skins.erase(k)
	if l.bg_image == key:
		l.bg_image = ""
	if l.music_custom == key:
		l.music_custom = ""
	CustomLevels.remove_asset(l, key)
	screen.reinstall()
	mark_dirty()
	_refresh_assets()
	rebuild()
	toast("Removed \"%s\"." % key.get_file())

# ================================================================ assigning
func _assign() -> void:
	var key := _selected_asset_key()
	if key == "":
		toast("Pick a file on the left first.", EditorUi.TEXT_RED)
		return
	if selected_target < 0 or selected_target >= targets.size():
		return
	var l := level()
	var kind := _asset_type(key)
	match mode:
		MODE_REANIM:
			if kind != "reanim":
				toast("That needs a .reanim file.", EditorUi.TEXT_RED)
				return
			l.reanim_skins[str(int(targets[selected_target].type))] = key
		MODE_PARTS:
			if kind != "image":
				toast("That needs an image file.", EditorUi.TEXT_RED)
				return
			if selected_track < 0 or selected_track >= tracks.size():
				toast("Pick a body part first.", EditorUi.TEXT_RED)
				return
			var slot := str(int(targets[selected_target].type))
			if not l.part_skins.has(slot):
				l.part_skins[slot] = {}
			(l.part_skins[slot] as Dictionary)[str(tracks[selected_track])] = key
		MODE_IMAGES:
			if kind != "image":
				toast("That needs an image file.", EditorUi.TEXT_RED)
				return
			l.image_skins[str(targets[selected_target].id)] = key
	screen.reinstall()
	_kill_preview()
	mark_dirty()
	rebuild()
	toast("Reskinned %s." % _current_target_label())

func _unassign() -> void:
	if selected_target < 0 or selected_target >= targets.size():
		return
	var l := level()
	match mode:
		MODE_REANIM:
			l.reanim_skins.erase(str(int(targets[selected_target].type)))
		MODE_PARTS:
			var slot := str(int(targets[selected_target].type))
			if l.part_skins.has(slot):
				if selected_track >= 0 and selected_track < tracks.size():
					(l.part_skins[slot] as Dictionary).erase(str(tracks[selected_track]))
				if (l.part_skins[slot] as Dictionary).is_empty():
					l.part_skins.erase(slot)
		MODE_IMAGES:
			l.image_skins.erase(str(targets[selected_target].id))
	screen.reinstall()
	_kill_preview()
	mark_dirty()
	rebuild()
	toast("Skin cleared.")
