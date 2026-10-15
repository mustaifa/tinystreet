class_name Dialog
extends Control
## Modal card on a dimmed background. Buttons close the dialog, then run.
## Back closes it unless `back_closes` is false.

var card: PanelContainer
var body: VBoxContainer
var back_closes := true
var on_dismiss: Callable

static func make(title: String, text: String, buttons: Array, extra: Control = null) -> Dialog:
	var d := Dialog.new()
	d._build(title, text, buttons, extra)
	return d

func _build(title: String, text: String, buttons: Array, extra: Control) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.16, 0.11, 0.08, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	card = PanelContainer.new()
	card.theme_type_variation = "CardPanel"
	card.custom_minimum_size = Vector2(600, 0)
	center.add_child(card)
	body = UI.vbox(22)
	card.add_child(UI.margin(body, 12, 16, 12, 12))
	if title != "":
		body.add_child(UI.label(title, "HeaderLabel"))
	if text != "":
		var l := UI.label(text)
		l.custom_minimum_size = Vector2(540, 0)
		body.add_child(l)
	if extra:
		body.add_child(extra)
	var row: BoxContainer = UI.vbox(14) if buttons.size() > 2 else UI.hbox(16)
	for b in buttons:
		var cb: Callable = b[1]
		var btn := UI.button(b[0], func(): close(); cb.call(), b[2] if b.size() > 2 else "")
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(btn)
	if not buttons.is_empty():
		body.add_child(row)

func appear() -> void:
	if App.reduced_motion():
		return
	card.pivot_offset = card.size / 2
	card.scale = Vector2(0.94, 0.94)
	modulate.a = 0.0
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.14)
	tw.tween_property(card, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func close() -> void:
	if App.main:
		App.main.close_overlay(self)
	else:
		queue_free()

func on_back() -> bool:
	if not back_closes:
		return true
	if on_dismiss.is_valid():
		on_dismiss.call()
	return false
