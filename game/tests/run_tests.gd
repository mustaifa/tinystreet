extends SceneTree
## Headless test runner:
##   godot --headless --path game -s res://tests/run_tests.gd [-- filter]
## Runs every test_*.gd suite's test_* methods. Exit code 1 on any failure.

func _init() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		filter = args[0]
	var passed := 0
	var failed := 0
	var dir := DirAccess.open("res://tests")
	var files: Array = []
	for f in dir.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_base.gd":
			files.append(f)
	files.sort()
	for f in files:
		var script: GDScript = load("res://tests/" + f)
		var suite = script.new()
		if suite.has_method("setup_suite"):
			suite.setup_suite(self)
		for m in suite.get_method_list():
			var name: String = m.name
			if not name.begins_with("test_"):
				continue
			if filter != "" and not (f + ":" + name).contains(filter):
				continue
			suite.failures = []
			suite.current = f + ":" + name
			var t0 := Time.get_ticks_msec()
			var r = suite.call(name)
			if r is Object and r.has_signal("completed"):
				await r.completed
			if suite.failures.is_empty():
				passed += 1
				print("PASS ", suite.current, " (", Time.get_ticks_msec() - t0, " ms)")
			else:
				failed += 1
				for x in suite.failures:
					print("FAIL ", x)
	print("\nRESULT: %d passed, %d failed" % [passed, failed])
	quit(1 if failed > 0 else 0)
