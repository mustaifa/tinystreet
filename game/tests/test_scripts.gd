extends "res://tests/test_base.gd"
## Every GDScript in the project compiles. Screens and views are only loaded
## at runtime, so without this a parse error would surface on a device.

func _scan(dir: String, out: Array) -> void:
	var d := DirAccess.open(dir)
	if d == null:
		return
	for f in d.get_files():
		if f.ends_with(".gd"):
			out.append(dir.path_join(f))
	for sub in d.get_directories():
		_scan(dir.path_join(sub), out)

func test_all_scripts_compile() -> void:
	var files: Array = []
	for root in ["res://src", "res://tools", "res://tests"]:
		_scan(root, files)
	check(files.size() > 40, "found %d scripts" % files.size())
	for f in files:
		var s := load(f) as GDScript
		check(s != null and s.can_instantiate(), "%s does not compile" % f)
