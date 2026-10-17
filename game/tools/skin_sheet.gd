extends SceneTree
## Renders every image in a skin into one contact sheet PNG (headless).
##   godot --headless --path game -s res://tools/skin_sheet.gd -- [skin_id] [out.png] [cell_px]
## Also prints any key that failed to load. Used to review new art quickly.

func _init() -> void:
	var args := OS.get_cmdline_user_args()
	var skin_id := args[0] if args.size() > 0 else "default"
	var out := args[1] if args.size() > 1 else "user://skin_sheet.png"
	var cell := int(args[2]) if args.size() > 2 else 160
	ArtSkin.load_skin(skin_id)
	var keys: Array = ArtSkin.image_keys()
	keys.sort()
	var cols := 6
	var rows := int(ceil(keys.size() / float(cols)))
	var sheet := Image.create(cols * cell, maxi(1, rows) * cell, false, Image.FORMAT_RGBA8)
	sheet.fill(Color("fbf4e8"))
	for i in keys.size():
		var path := ArtSkin.path_of(keys[i])
		var img := Image.new()
		var err := OK
		if path.get_extension() == "svg":
			var src := FileAccess.get_file_as_string(path)
			var probe := Image.new()
			probe.load_svg_from_string(src)
			var sc := (cell - 16) / float(maxi(probe.get_width(), probe.get_height()))
			err = img.load_svg_from_string(src, sc)
		else:
			err = img.load(ProjectSettings.globalize_path(path))
			if err == OK:
				var k := (cell - 16) / float(maxi(img.get_width(), img.get_height()))
				img.resize(maxi(1, int(img.get_width() * k)), maxi(1, int(img.get_height() * k)))
		if err != OK:
			print("FAILED ", keys[i], " ", path)
			continue
		img.convert(Image.FORMAT_RGBA8)
		var at := Vector2i((i % cols) * cell + (cell - img.get_width()) / 2, (i / cols) * cell + (cell - img.get_height()) / 2)
		sheet.blend_rect(img, Rect2i(Vector2i.ZERO, img.get_size()), at)
	sheet.save_png(out)
	print("keys=", keys.size(), " errors=", ArtSkin.errors.size(), " -> ", out)
	for e in ArtSkin.errors:
		print("  ", e)
	quit()
