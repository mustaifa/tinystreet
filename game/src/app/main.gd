extends Control
## Root host: full-bleed background, safe-area container, screen stack,
## modal overlays and toasts. Android back is routed through handle_back():
## overlay -> screen-specific handling -> pop screen -> exit confirmation.

const SCREENS := {
	"boot": "res://src/screens/boot_screen.gd",
	"home": "res://src/screens/home_screen.gd",
	"levels": "res://src/screens/level_select_screen.gd",
	"game": "res://src/screens/game_screen.gd",
	"restore": "res://src/screens/restore_screen.gd",
	"daily": "res://src/screens/daily_screen.gd",
	"settings": "res://src/screens/settings_screen.gd",
	"help": "res://src/screens/help_screen.gd",
	"credits": "res://src/screens/credits_screen.gd",
	"privacy": "res://src/screens/privacy_screen.gd",
	"shop": "res://src/screens/shop_screen.gd",
	"journal": "res://src/screens/journal_screen.gd",
}

var bg: ColorRect
var safe: MarginContainer
var host: Control
var overlay_host: Control
var stack: Array = []        # [{name, params}]
var current: Control
var overlays: Array = []
var sim_cutout := 0          # debug: simulate a top cutout (px) via --sim-cutout=N
var _toast: Label

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	bg = ColorRect.new()
	bg.color = Style.CREAM
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	safe = MarginContainer.new()
	safe.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(safe)
	host = Control.new()
	safe.add_child(host)
	overlay_host = Control.new()
	overlay_host.set_anchors_preset(Control.PRESET_FULL_RECT)
	overlay_host.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(overlay_host)
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--sim-cutout="):
			sim_cutout = int(a.split("=")[1])
		if a.begins_with("--qa="):
			add_child(load("res://src/app/qa_driver.gd").new())
	get_viewport().size_changed.connect(_apply_safe_area)
	App.main = self
	App.language_changed.connect(_on_language_changed)
	_apply_safe_area()
	goto("boot", {}, false)

## Safe area from the OS (display cutouts, gesture bars) mapped into the
## stretched viewport. Desktop builds use the full window unless simulated.
func _apply_safe_area() -> void:
	var vp := get_viewport_rect().size
	var m := [24, 16, 24, 16] # l, t, r, b minimum comfortable margins
	if OS.has_feature("mobile"):
		var win := Vector2(DisplayServer.window_get_size())
		var sa := DisplayServer.get_display_safe_area()
		if win.x > 0 and win.y > 0 and sa.size.x > 0:
			var sx := vp.x / win.x
			var sy := vp.y / win.y
			m[0] = maxi(m[0], int(sa.position.x * sx))
			m[1] = maxi(m[1], int(sa.position.y * sy))
			m[2] = maxi(m[2], int((win.x - sa.end.x) * sx))
			m[3] = maxi(m[3], int((win.y - sa.end.y) * sy))
	m[1] = maxi(m[1], sim_cutout)
	for i in 4:
		safe.add_theme_constant_override(["margin_left", "margin_top", "margin_right", "margin_bottom"][i], m[i])

func _apply_direction() -> void:
	var d := Control.LAYOUT_DIRECTION_RTL if Loc.is_rtl() else Control.LAYOUT_DIRECTION_LTR
	safe.layout_direction = d
	overlay_host.layout_direction = d

func goto(name: String, params: Dictionary = {}, push: bool = true) -> void:
	persist_current()
	close_all_overlays()
	if not push:
		stack.clear()
	stack.append({"name": name, "params": params})
	_show(name, params)

## Replace the top of the stack (e.g. game -> next game).
func replace(name: String, params: Dictionary = {}) -> void:
	persist_current()
	close_all_overlays()
	if not stack.is_empty():
		stack.pop_back()
	stack.append({"name": name, "params": params})
	_show(name, params)

func back() -> void:
	persist_current()
	close_all_overlays()
	if stack.size() <= 1:
		goto("home", {}, false)
		return
	stack.pop_back()
	var top: Dictionary = stack.back()
	_show(top.name, top.params)

func _show(name: String, params: Dictionary) -> void:
	_apply_direction()
	if current:
		current.queue_free()
	var scr: Control = load(SCREENS[name]).new()
	scr.name = name.capitalize()
	scr.set_anchors_preset(Control.PRESET_FULL_RECT)
	host.add_child(scr)
	current = scr
	if scr.has_method("setup"):
		scr.setup(params)

func current_name() -> String:
	return stack.back().name if not stack.is_empty() else ""

func handle_back() -> void:
	if not overlays.is_empty():
		var o: Control = overlays.back()
		if o.has_method("on_back") and o.on_back():
			return
		close_overlay(o)
		return
	if current and current.has_method("on_back") and current.on_back():
		return
	if stack.size() > 1:
		back()
	elif current_name() != "home" and current_name() != "boot":
		goto("home", {}, false)
	else:
		_confirm_exit()

func _confirm_exit() -> void:
	var d := Dialog.make(Loc.t("exit_title"), Loc.t("exit_body"), [
		[Loc.t("exit_stay"), func(): pass, "SecondaryButton"],
		[Loc.t("exit_leave"), func(): App.save_now(); get_tree().quit(), ""],
	])
	show_overlay(d)

func show_overlay(o: Control) -> void:
	o.set_anchors_preset(Control.PRESET_FULL_RECT)
	o.layout_direction = overlay_host.layout_direction
	overlay_host.mouse_filter = Control.MOUSE_FILTER_STOP
	overlay_host.add_child(o)
	overlays.append(o)
	if o.has_method("appear"):
		o.appear()

func close_overlay(o: Control) -> void:
	overlays.erase(o)
	if is_instance_valid(o):
		o.queue_free()
	if overlays.is_empty():
		overlay_host.mouse_filter = Control.MOUSE_FILTER_IGNORE

func close_all_overlays() -> void:
	for o in overlays.duplicate():
		close_overlay(o)

func toast(text: String, seconds: float = 2.2) -> void:
	if _toast and is_instance_valid(_toast):
		_toast.queue_free()
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_stylebox_override("normal", Style.box(Color(Style.INK, 0.92), 24))
	l.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	l.custom_minimum_size = Vector2(560, 0)
	l.position = Vector2(get_viewport_rect().size.x / 2 - 280, get_viewport_rect().size.y - 260)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	_toast = l
	var tw := create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(l, "modulate:a", 0.0, 0.3)
	tw.tween_callback(l.queue_free)

func persist_current() -> void:
	if current and is_instance_valid(current) and current.has_method("persist"):
		current.persist()

func _on_language_changed() -> void:
	_apply_direction()
	if not stack.is_empty() and current_name() != "game":
		var top: Dictionary = stack.back()
		_show(top.name, top.params)
