class_name ArtSkin
extends RefCounted
## Swappable art, sound and colour ("skins"). A skin is a folder with a
## `skin.json` manifest that maps art KEYS to files:
##
##   res://skins/<id>/skin.json      shipped skins (default, seasonal themes)
##   user://skins/<id>/skin.json     downloaded or side-loaded skins (future)
##
## Every drawing site asks the skin first and falls back to the built-in vector
## art when a key is missing, so a skin can replace one image or all of them.
## A skin may `extend` another skin and override only some keys (a Christmas
## theme only needs the keys it changes). Colours override Style tokens by name.
## The full key list, sizes and formats are in docs/ART_PIPELINE.md.

const DEFAULT := "default"
static var roots: Array[String] = ["user://skins/", "res://skins/"]   # user first: side-loaded skins win

static var id := ""
static var name := ""
static var chain: Array[String] = []      # skin ids, base first
static var _images := {}                   # key -> {path, margins: [l,t,r,b], scale}
static var _sounds := {}                   # key -> path
static var _sound_db := {}                 # key -> volume offset in dB
static var _colors := {}                   # Style token -> Color
static var _tex := {}                      # key -> Texture2D (null = failed / missing)
static var _snd := {}                      # key -> AudioStream
static var _boxes := {}                    # key -> StyleBoxTexture
static var _default_colors := {}           # Style tokens before any skin was applied
static var errors: Array[String] = []

## Loads skin `skin_id` (and the skins it extends). Unknown ids fall back to
## the default skin; a missing default skin simply means "all built-in art".
static func load_skin(skin_id: String = DEFAULT) -> bool:
	_reset()
	var ok := _merge(skin_id, 0)
	if not ok and skin_id != DEFAULT:
		_reset()
		_merge(DEFAULT, 0)
	id = skin_id if ok else DEFAULT
	_apply_colors()
	return ok

static func _reset() -> void:
	id = ""
	name = ""
	chain.clear()
	_images.clear()
	_sounds.clear()
	_sound_db.clear()
	_colors.clear()
	_tex.clear()
	_snd.clear()
	_boxes.clear()
	errors.clear()

static func dir_of(skin_id: String) -> String:
	for r in roots:
		if FileAccess.file_exists(r + skin_id + "/skin.json"):
			return r + skin_id + "/"
	return ""

static func _merge(skin_id: String, depth: int) -> bool:
	if depth > 4 or skin_id in chain:
		errors.append("skin chain too deep or circular at '%s'" % skin_id)
		return false
	var dir := dir_of(skin_id)
	if dir == "":
		errors.append("skin '%s' not found" % skin_id)
		return false
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir + "skin.json"))
	if not parsed is Dictionary:
		errors.append("skin '%s': skin.json is not a JSON object" % skin_id)
		return false
	var m: Dictionary = parsed
	var base: String = str(m.get("extends", ""))
	if base != "":
		_merge(base, depth + 1)
	chain.append(skin_id)
	name = str(m.get("name", skin_id))
	var images: Dictionary = m.get("images", {})
	for k: String in images:
		var v: Variant = images[k]
		var spec := {"margins": [], "scale": 1.0, "tile": false, "tint": false}
		if v is Dictionary:
			var d: Dictionary = v
			spec.path = _resolve(dir, str(d.get("file", "")))
			spec.margins = d.get("margins", [])
			spec.scale = float(d.get("scale", 1.0))
			spec.tile = bool(d.get("tile", false))
			spec.tint = bool(d.get("tint", false))
		else:
			spec.path = _resolve(dir, str(v))
		_images[k] = spec
	var sounds: Dictionary = m.get("sounds", {})
	for k: String in sounds:
		var sv: Variant = sounds[k]
		if sv is Dictionary:
			_sounds[k] = _resolve(dir, str((sv as Dictionary).get("file", "")))
			_sound_db[k] = float((sv as Dictionary).get("volume_db", 0.0))
		else:
			_sounds[k] = _resolve(dir, str(sv))
			_sound_db.erase(k)
	var colors: Dictionary = m.get("colors", {})
	for k: String in colors:
		var c := str(colors[k])
		if c.is_valid_html_color():
			_colors[k] = Color(c)
		else:
			errors.append("skin '%s': colour %s = '%s' is not a colour" % [skin_id, k, c])
	return true

static func _resolve(dir: String, f: String) -> String:
	if f == "" or f.begins_with("res://") or f.begins_with("user://"):
		return f
	return dir + f

## Style tokens are static vars, so a skin can recolour the whole UI. The
## Theme is built after this, at boot.
static func _apply_colors() -> void:
	var s: Script = load("res://src/ui/style.gd")
	if _default_colors.is_empty():
		for p in s.get_property_list():   # static vars are listed here (usage SCRIPT_VARIABLE)
			var n: String = p.name
			if n == n.to_upper() and p.type == TYPE_COLOR and s.get(n) is Color:
				_default_colors[n] = s.get(n)
	for n: String in _default_colors:
		s.set(n, _colors.get(n, _default_colors[n]))
	for n: String in _colors:
		if not _default_colors.has(n):
			errors.append("skin colour '%s' is not a Style token" % n)

# --------------------------------------------------------------- queries

static func has(key: String) -> bool:
	return _images.has(key) and tex(key) != null

static func image_keys() -> Array:
	return _images.keys()

static func sound_keys() -> Array:
	return _sounds.keys()

static func path_of(key: String) -> String:
	return str((_images.get(key, {}) as Dictionary).get("path", ""))

static func tex(key: String) -> Texture2D:
	if _tex.has(key):
		return _tex[key]
	var t: Texture2D = null
	if _images.has(key):
		t = _load_texture(str(_images[key].path))
		if t == null:
			errors.append("image '%s' could not be loaded from %s" % [key, _images[key].path])
	_tex[key] = t
	return t

static func _load_texture(path: String) -> Texture2D:
	if path.begins_with("res://"):
		return load(path) as Texture2D if ResourceLoader.exists(path) else null
	if not FileAccess.file_exists(path):
		return null
	var img := Image.new()
	var err := OK
	if path.get_extension().to_lower() == "svg":
		err = img.load_svg_from_string(FileAccess.get_file_as_string(path))
	else:
		err = img.load(path)
	if err != OK:
		return null
	img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

## Volume offset for a sound (manifest `volume_db`), so mixed packs can be balanced.
static func sound_db(key: String) -> float:
	return float(_sound_db.get(key, 0.0))

## Texture pixels per design pixel. SVGs are imported at `svg/scale` (2× by
## default, see project importer_defaults) so they stay sharp on dense screens;
## nine-patch margins in the manifest are in design pixels.
static func density(key: String) -> float:
	var path := path_of(key)
	if path.get_extension().to_lower() != "svg" or not path.begins_with("res://"):
		return 1.0
	var cf := ConfigFile.new()
	if cf.load(path + ".import") != OK:
		return 1.0
	return float(cf.get_value("params", "svg/scale", 1.0))

static func sound(key: String) -> AudioStream:
	if _snd.has(key):
		return _snd[key]
	var s: AudioStream = null
	var path: String = _sounds.get(key, "")
	if path.begins_with("res://") and ResourceLoader.exists(path):
		s = load(path) as AudioStream
	elif path != "" and FileAccess.file_exists(path):
		match path.get_extension().to_lower():
			"ogg": s = AudioStreamOggVorbis.load_from_file(path)
			"wav": s = AudioStreamWAV.load_from_file(path)
			"mp3": s = AudioStreamMP3.load_from_file(path)
	if path != "" and s == null:
		errors.append("sound '%s' could not be loaded from %s" % [key, path])
	_snd[key] = s
	return s

# --------------------------------------------------------------- drawing

## Draws `key` centred on `c`, fitted inside an s×s square (aspect kept).
## Returns false when the skin has no such image, so the caller can fall back.
## `tint` colours images whose manifest entry says `"tint": true` (white
## line icons that take the UI colour); full-colour art only takes alpha.
static func draw_fit(ci: CanvasItem, key: String, c: Vector2, s: float, a: float = 1.0, tint: Color = Color.WHITE) -> bool:
	var t := tex(key) if _images.has(key) else null
	if t == null:
		return false
	var ts := t.get_size()
	var k := s * float(_images[key].scale) / maxf(ts.x, ts.y)
	var sz := ts * k
	var m := Color(tint, tint.a * a) if bool(_images[key].tint) else Color(1, 1, 1, a)
	ci.draw_texture_rect(t, Rect2(c - sz / 2, sz), false, m)
	return true

## Fills `r` with `key`, scaled to cover it (aspect kept, overflow cropped).
## For full-screen backgrounds. Returns false when the skin has no such image.
static func draw_cover(ci: CanvasItem, key: String, r: Rect2, modulate: Color = Color.WHITE) -> bool:
	var t := tex(key) if _images.has(key) else null
	if t == null:
		return false
	var ts := t.get_size()
	var k := maxf(r.size.x / ts.x, r.size.y / ts.y)
	var src_size := r.size / k
	var src := Rect2((ts - src_size) / 2, src_size)
	ci.draw_texture_rect_region(t, r, src, modulate)
	return true

## Fills `r` with `key`: nine-patch when the manifest gives margins, otherwise
## stretched. Returns false when the skin has no such image.
static func draw_rect(ci: CanvasItem, key: String, r: Rect2, modulate: Color = Color.WHITE) -> bool:
	var sb := box(key)
	if sb == null:
		var t := tex(key) if _images.has(key) else null
		if t == null:
			return false
		ci.draw_texture_rect(t, r, false, modulate)
		return true
	sb.modulate_color = modulate
	var f: float = sb.get_meta("density", 1.0)
	if is_equal_approx(f, 1.0):
		ci.draw_style_box(sb, r)
	else:
		# Draw the high-density texture at design size (note: resets any
		# transform the caller set with draw_set_transform).
		ci.draw_set_transform(r.position, 0.0, Vector2.ONE / f)
		ci.draw_style_box(sb, Rect2(Vector2.ZERO, r.size * f))
		ci.draw_set_transform(Vector2.ZERO)
	return true

## A nine-patch StyleBoxTexture for `key`, or null if the image is missing or
## the manifest gives no margins.
static func box(key: String) -> StyleBoxTexture:
	if _boxes.has(key):
		return _boxes[key]
	var sb: StyleBoxTexture = null
	var spec: Dictionary = _images.get(key, {})
	var m: Array = spec.get("margins", [])
	var t := tex(key) if not spec.is_empty() else null
	if t != null and m.size() == 4:
		var f := density(key)
		sb = StyleBoxTexture.new()
		sb.texture = t
		sb.texture_margin_left = float(m[0]) * f
		sb.texture_margin_top = float(m[1]) * f
		sb.texture_margin_right = float(m[2]) * f
		sb.texture_margin_bottom = float(m[3]) * f
		sb.set_meta("density", f)
		if bool(spec.get("tile", false)):
			sb.axis_stretch_vertical = StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT
	_boxes[key] = sb
	return sb
