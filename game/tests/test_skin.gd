extends "res://tests/test_base.gd"
## v6 art skins: the shipped default skin is complete and loads cleanly; a
## partial skin can extend it, override images and colours, and be side-loaded
## from user://; anything missing falls back to the built-in vector art.

const TEST_DIR := "user://skins/qa_partial/"

func _write_partial_skin(manifest: Dictionary) -> void:
	DirAccess.make_dir_recursive_absolute(TEST_DIR)
	var svg := '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 64 64" width="64" height="64"><circle cx="32" cy="32" r="28" fill="#ff0000"/></svg>'
	var f := FileAccess.open(TEST_DIR + "red.svg", FileAccess.WRITE)
	f.store_string(svg)
	f.close()
	f = FileAccess.open(TEST_DIR + "skin.json", FileAccess.WRITE)
	f.store_string(JSON.stringify(manifest))
	f.close()

func _cleanup() -> void:
	for n in ["red.svg", "skin.json"]:
		DirAccess.remove_absolute(TEST_DIR + n)
	DirAccess.remove_absolute(TEST_DIR)
	ArtSkin.load_skin(ArtSkin.DEFAULT)

func test_default_skin_is_complete_and_loads() -> void:
	check(ArtSkin.load_skin(ArtSkin.DEFAULT), "default skin found")
	eq(ArtSkin.errors.size(), 0, "no manifest errors: %s" % [ArtSkin.errors])
	for id in Products.IDS:
		check(ArtSkin.has("product." + id), "product art for " + id)
	check(ArtSkin.has("product.bag"), "paper bag art")
	for k in ["board.crate", "board.crate_front", "board.counter"]:
		check(ArtSkin.box(k) != null, k + " is a nine-patch")
	for k in ArtSkin.image_keys():
		check(ArtSkin.tex(k) != null, "image loads: " + k)
	for n in AudioManager.SFX:
		if n == "lose":
			continue   # deliberately still the built-in sound
		check(ArtSkin.sound("sfx." + n) != null, "sound loads: " + n)
	eq(ArtSkin.errors.size(), 0, "nothing failed to load: %s" % [ArtSkin.errors])

func test_nine_patch_margins_follow_import_density() -> void:
	ArtSkin.load_skin(ArtSkin.DEFAULT)
	var f := ArtSkin.density("board.counter")
	check(f >= 1.0, "density read from the import settings")
	var sb := ArtSkin.box("board.counter")
	eq(sb.texture_margin_left, 44.0 * f, "manifest margins are design pixels")
	check(ArtSkin.box("board.crate").axis_stretch_vertical == StyleBoxTexture.AXIS_STRETCH_MODE_TILE_FIT, "crate slats tile")

func test_partial_user_skin_extends_and_overrides() -> void:
	var teal_before: Color = Style.TEAL
	_write_partial_skin({"name": "QA partial", "extends": "default",
		"colors": {"TEAL": "#ff0000", "NOT_A_TOKEN": "#00ff00", "GOLD": "nonsense"},
		"images": {"product.coffee": "red.svg", "product.tea": "missing.png"}})
	check(ArtSkin.load_skin("qa_partial"), "user skin found")
	eq(ArtSkin.chain, ["default", "qa_partial"] as Array[String], "base first")
	eq(Style.TEAL, Color("#ff0000"), "colour token overridden")
	check(ArtSkin.path_of("product.coffee").begins_with("user://"), "override comes from the user skin")
	check(ArtSkin.tex("product.coffee") != null, "side-loaded SVG decodes")
	check(ArtSkin.path_of("product.croissant").begins_with("res://skins/default/"), "unchanged keys come from the base")
	check(not ArtSkin.has("product.tea"), "a broken file is reported missing, so the caller falls back")
	var joined := "\n".join(ArtSkin.errors)
	check(joined.contains("NOT_A_TOKEN"), "unknown colour token reported")
	check(joined.contains("GOLD"), "invalid colour reported")
	check(joined.contains("product.tea"), "unloadable image reported")
	_cleanup()
	eq(Style.TEAL, teal_before, "switching back restores the default palette")

func test_missing_skin_falls_back_to_default() -> void:
	check(not ArtSkin.load_skin("no_such_skin"), "unknown skin reported")
	eq(ArtSkin.id, ArtSkin.DEFAULT, "fell back to default")
	check(ArtSkin.has("product.coffee"), "default art active")
	ArtSkin.load_skin(ArtSkin.DEFAULT)

func test_missing_key_draws_nothing_and_returns_false() -> void:
	ArtSkin.load_skin(ArtSkin.DEFAULT)
	var c := Control.new()
	check(not ArtSkin.draw_fit(c, "no.such.key", Vector2.ZERO, 10.0), "missing key -> caller draws the built-in art")
	check(not ArtSkin.draw_rect(c, "no.such.key", Rect2(0, 0, 10, 10)), "missing nine-patch -> built-in art")
	c.free()

func test_skin_selection_from_settings() -> void:
	eq(BuildConfig.skin_id({}), "default", "default when unset")
	eq(BuildConfig.skin_id({"skin": "winter"}), "winter", "settings pick a skin")
