class_name SpeechBubble
extends Control
## Short dialogue overlay: portrait, name and one line at a time near the
## bottom of the screen. Tap anywhere (or Enter / Space / a pad's A) for the
## next line; "Skip" or Back ends it. Never more than a few lines, so it never stands between the player and
## play for long.

var lines: Array = []     # [[who, key], ...]
var idx := 0
var done: Callable
var portrait: _Portrait
var name_label: Label
var text_label: Label
var card: PanelContainer
var _closing := false

static func make(beat: Array, on_done: Callable = Callable()) -> SpeechBubble:
	var s := SpeechBubble.new()
	s.lines = beat
	s.done = on_done
	s._build()
	return s

func _build() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.11, 0.08, 0.35)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var col := UI.vbox(0)
	col.set_anchors_preset(Control.PRESET_FULL_RECT)
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(col)
	var sp := UI.spacer(0, true)
	sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(sp)
	card = PanelContainer.new()
	card.add_theme_stylebox_override("panel", Style.box(Style.PAPER, 30, Style.GOLD, 4))
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var m := UI.margin(card, 24, 0, 24, 150)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(m)
	var row := UI.hbox(18)
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	card.add_child(row)
	portrait = _Portrait.new()
	portrait.custom_minimum_size = Vector2(150, 150)
	row.add_child(portrait)
	var v := UI.vbox(8)
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(v)
	var head := UI.hbox(8)
	name_label = UI.label("", "HeaderLabel", UI.al(), false)
	name_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(name_label)
	var skip := UI.button(Loc.t("skip"), _finish, "SecondaryButton", 64)
	skip.custom_minimum_size = Vector2(120, 64)
	skip.add_theme_font_size_override("font_size", Style.fs(24))
	head.add_child(skip)
	v.add_child(head)
	text_label = UI.label("", "", UI.al())
	text_label.custom_minimum_size = Vector2(380, 0)
	text_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(text_label)
	# RIGHT is mirrored in RTL, so this sits at the end of the line in both
	var tapl := UI.label(Loc.t("tap_continue"), "SoftLabel", HORIZONTAL_ALIGNMENT_RIGHT)
	tapl.add_theme_font_size_override("font_size", Style.fs(20))
	tapl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(tapl)
	_show_line()

func _show_line() -> void:
	var l: Array = lines[idx]
	portrait.who = l[0]
	portrait.queue_redraw()
	name_label.text = Loc.t("name_" + str(l[0]))
	text_label.text = Loc.t(l[1])
	if not App.reduced_motion():
		text_label.visible_ratio = 0.0
		var tw := create_tween()
		tw.tween_property(text_label, "visible_ratio", 1.0, 0.25)

func appear() -> void:
	if App.reduced_motion():
		return
	card.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(card, "modulate:a", 1.0, 0.18)

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed and e.button_index == MOUSE_BUTTON_LEFT:
		accept_event()
		_advance()

## Enter / Space / pad A, unless a focused key (Skip) took the press.
func _unhandled_input(e: InputEvent) -> void:
	if not _closing and e.is_action_pressed("ui_accept"):
		get_viewport().set_input_as_handled()
		_advance()

func _advance() -> void:
	if _closing:
		return
	if text_label.visible_ratio < 1.0:
		text_label.visible_ratio = 1.0
		return
	App.audio.play("tap")
	idx += 1
	if idx >= lines.size():
		_finish()
	else:
		_show_line()

func _finish() -> void:
	if _closing:
		return
	_closing = true
	if App.main:
		App.main.close_overlay(self)
	else:
		queue_free()
	if done.is_valid():
		done.call()

func on_back() -> bool:
	_finish()
	return true

class _Portrait extends Control:
	var who := "mira"
	func _draw() -> void:
		draw_circle(size / 2, size.x / 2, Style.TEAL_SOFT)
		CharacterArt.draw(self, who, size / 2 + Vector2(0, 6), size.x * 0.95, 1)
