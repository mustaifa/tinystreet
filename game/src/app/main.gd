extends Control
## Root host: full-bleed background, safe-area container, screen stack,
## modal overlays and toasts. Android back (and Escape / a pad's B) is routed
## through handle_back(): overlay -> screen-specific handling -> pop screen ->
## exit confirmation.
##
## Keyboard and D-pad: every UI key takes focus. A screen or dialog may name
## its `default_focus` (its main action); after key or pad input it gets
## focus when it opens, and the first arrow/Tab press focuses it when nothing
## has focus. Touch never moves focus visibly.

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
	"bakery": "res://src/screens/bakery_screen.gd",
	"ledger": "res://src/screens/ledger_screen.gd",
	"puzzle": "res://src/screens/puzzle_screen.gd",     # v8 Delivery Logic
	"puzzles": "res://src/screens/puzzles_screen.gd",
}

var bg: ScreenBackdrop
var safe: MarginContainer
var host: Control
var overlay_host: Control
var stack: Array = []        # [{name, params}]
var current: Control
var overlays: Array = []
var sim_cutout := 0          # debug: simulate a top cutout (px) via --sim-cutout=N
var _toast: Control
var _lock_until := 0         # ms: UI buttons ignore presses during a screen transition
var keyboard_nav := false    # the last input came from keys or a pad (not touch)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	bg = ScreenBackdrop.new()
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
		# Immersive mode can report no bottom inset: keep the dock clear of
		# the gesture-navigation strip anyway (~14 dp on a 360 dp phone).
		m[3] = 28
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

## Screens may set `var screen_mode := "night"` (or "bakery") to change the
## full-bleed background. New screens fade and rise in briefly; presses on UI
## buttons are ignored until the transition ends (no duplicate actions).
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
	if keyboard_nav:
		focus_default.call_deferred()
	var mode = scr.get("screen_mode")
	bg.set_mode(str(mode) if mode != null else "cafe")
	_lock_until = Time.get_ticks_msec() + int(Style.M_BASE * 1000)
	if not App.reduced_motion() and App.data.size() > 0:
		scr.modulate.a = 0.0
		scr.position.y = 18
		var tw := scr.create_tween().set_parallel()
		tw.tween_property(scr, "modulate:a", 1.0, Style.M_BASE)
		tw.tween_property(scr, "position:y", 0.0, Style.M_BASE + 0.04).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)

## Ignores UI-key presses for `ms` (e.g. a result card that appears under a
## finger still tapping the board must not take that tap as a choice).
func lock_input(ms: int) -> void:
	_lock_until = maxi(_lock_until, Time.get_ticks_msec() + ms)

func input_locked() -> bool:
	return Time.get_ticks_msec() < _lock_until

func current_name() -> String:
	return stack.back().name if not stack.is_empty() else ""

func _input(e: InputEvent) -> void:
	if e is InputEventKey or e is InputEventJoypadButton:
		keyboard_nav = true
	elif (e is InputEventMouseButton or e is InputEventScreenTouch) and e.is_pressed():
		keyboard_nav = false

func _unhandled_input(e: InputEvent) -> void:
	# KEY_BACK arrives as NOTIFICATION_WM_GO_BACK_REQUEST (App) as well.
	if e is InputEventKey and e.keycode == KEY_BACK:
		return
	if e.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		handle_back()
		return
	if get_viewport().gui_get_focus_owner() != null:
		return
	for a in ["ui_focus_next", "ui_focus_prev", "ui_up", "ui_down", "ui_left", "ui_right"]:
		if e.is_action_pressed(a):
			if focus_default(true):
				get_viewport().set_input_as_handled()
			return

## Focuses the top overlay's or screen's `default_focus`, or with `any` the
## first focusable control in it. Returns true when something took focus.
func focus_default(any: bool = false) -> bool:
	var root: Control = overlays.back() if not overlays.is_empty() else current
	if root == null or not is_instance_valid(root):
		return false
	var c: Control = null
	var f = root.get("default_focus")
	if f is Control and is_instance_valid(f) and f.is_visible_in_tree():
		c = f
	elif any:
		c = root.find_next_valid_focus()
		if c != null and not root.is_ancestor_of(c):
			c = null
	if c == null:
		return false
	c.grab_focus()
	return true

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
	], null, "door")
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
	if keyboard_nav:
		focus_default.call_deferred()

func close_all_overlays() -> void:
	for o in overlays.duplicate():
		close_overlay(o)

## A short message in an espresso pill above the thumb zone. Never blocks input.
func toast(text: String, seconds: float = 2.2) -> void:
	if _toast and is_instance_valid(_toast):
		_toast.queue_free()
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.add_theme_color_override("font_color", Style.PAPER)
	l.add_theme_font_override("font", Style.font_bold)
	l.add_theme_font_size_override("font_size", Style.fs(26))
	var sb := Style.box(Color(Style.INK, 0.94), 30)
	sb.content_margin_left = 28
	sb.content_margin_right = 28
	sb.content_margin_top = 16
	sb.content_margin_bottom = 18
	l.add_theme_stylebox_override("normal", sb)
	var vw := get_viewport_rect().size.x
	l.custom_minimum_size = Vector2(minf(600.0, vw - 64), 0)
	l.size = l.custom_minimum_size
	l.position = Vector2((vw - l.size.x) / 2, get_viewport_rect().size.y - 300)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(l)
	_toast = l
	var tw := create_tween()
	if not App.reduced_motion():
		l.modulate.a = 0.0
		l.position.y += 16
		tw.set_parallel()
		tw.tween_property(l, "modulate:a", 1.0, Style.M_BASE)
		tw.tween_property(l, "position:y", l.position.y - 16, Style.M_BASE).set_ease(Tween.EASE_OUT)
		tw.set_parallel(false)
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
