class_name Dialog
extends Control
## Modal card on a dimmed background. Buttons close the dialog, then run.
## Back closes it unless `back_closes` is false.
## The body (text + extra) scrolls when it is taller than the screen allows,
## so a dialog never runs off-screen on short phones or with large text.
## `night` gives the Midnight Ledger look (midnight card, lantern buttons).

var card: PanelContainer
var body: VBoxContainer
var content: VBoxContainer
var scroll: ScrollContainer
var back_closes := true
var on_dismiss: Callable
var night := false
var icon := ""
var default_focus: Control   # the first (main) action; focused for keyboard / pad players
var _ready_to_show := false

static func make(title: String, text: String, buttons: Array, extra: Control = null, icon_kind: String = "", night_style: bool = false) -> Dialog:
	var d := Dialog.new()
	d.icon = icon_kind
	d.night = night_style
	d._build(title, text, buttons, extra)
	return d

func _map_variant(v: String) -> String:
	if not night:
		return v
	match v:
		"", "Button", "WarmButton", "GoldButton": return "LanternButton"
		"SecondaryButton", "GhostButton": return "NightButton"
	return v

func _build(title: String, text: String, buttons: Array, extra: Control) -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.07, 0.14, 0.72) if night else Color(0.17, 0.11, 0.07, 0.55)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	card = PanelContainer.new()
	var sb := Style.box(Style.NIGHT_2 if night else Style.PAPER, Style.R_LG, Style.NIGHT_LINE if night else Style.PAPER_EDGE, 2, true)
	sb.shadow_size = 24
	sb.shadow_offset = Vector2(0, 10)
	sb.shadow_color = Color(0, 0, 0, 0.35) if night else Color(Style.SHADOW, 0.3)
	sb.content_margin_left = 32
	sb.content_margin_right = 32
	sb.content_margin_top = 30
	sb.content_margin_bottom = 28
	card.add_theme_stylebox_override("panel", sb)
	var vw := 720.0
	if is_inside_tree():
		vw = get_viewport_rect().size.x
	card.custom_minimum_size = Vector2(minf(624.0, vw - 48.0), 0)
	center.add_child(card)
	body = UI.vbox(20)
	card.add_child(body)
	if icon != "":
		var m := UI.medallion(icon, Style.NIGHT_3 if night else Style.GOLD_SOFT, Style.LANTERN if night else Style.GOLD_EDGE, 84)
		m.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		body.add_child(m)
	if title != "":
		var tl := UI.label(title, "NightHeader" if night else "HeaderLabel")
		tl.add_theme_font_override("font", Style.font_black)
		tl.add_theme_font_size_override("font_size", Style.fs(36))
		body.add_child(tl)
	content = UI.vbox(18)
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	if text != "":
		var long := text.length() > 110 or text.contains("\n\n")
		var l := UI.label(text, "NightLabel" if night else "", UI.al() if long else HORIZONTAL_ALIGNMENT_CENTER)
		l.custom_minimum_size = Vector2(520, 0)
		content.add_child(l)
	if extra:
		content.add_child(extra)
	if content.get_child_count() > 0:
		scroll = ScrollContainer.new()
		scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
		scroll.follow_focus = true
		scroll.add_child(content)
		body.add_child(scroll)
	# Layout: two buttons share a row; with more, the main actions stack and
	# the last two secondary actions (e.g. Replay / Café) share a row.
	var row: BoxContainer = UI.vbox(12) if buttons.size() > 2 else UI.hbox(14)
	var pair: HBoxContainer
	var n := buttons.size()
	var pair_from := n
	if n > 2 and _is_secondary(buttons[n - 1]) and _is_secondary(buttons[n - 2]):
		pair_from = n - 2
		pair = UI.hbox(12)
	for k in n:
		var b: Array = buttons[k]
		var cb: Callable = b[1]
		var btn := UI.button(b[0], func(): close(); cb.call(), _map_variant(b[2] if b.size() > 2 else ""))
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		if k == 0:
			default_focus = btn
		if k >= pair_from:
			pair.add_child(btn)
		else:
			row.add_child(btn)
	if pair:
		row.add_child(pair)
	if not buttons.is_empty():
		body.add_child(UI.spacer(2))
		body.add_child(row)

func _is_secondary(b: Array) -> bool:
	return b.size() > 2 and str(b[2]) in ["SecondaryButton", "GhostButton"]

## Sizes the scrolling body to its content, capped by the screen height.
func _fit() -> void:
	if scroll == null:
		return
	scroll.custom_minimum_size.y = 0
	for i in 2:
		await get_tree().process_frame
	if not is_inside_tree():
		return
	var vp := get_viewport_rect().size
	var others := card.size.y - scroll.size.y
	var maxh := maxf(160.0, vp.y - 96.0 - others)
	var need := content.get_combined_minimum_size().y
	scroll.custom_minimum_size.y = minf(need, maxh)
	scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO if need > maxh else ScrollContainer.SCROLL_MODE_DISABLED

func appear() -> void:
	modulate.a = 0.0
	await _fit()
	if not is_inside_tree():
		return
	if App.main and App.main.get("keyboard_nav") and default_focus:
		default_focus.grab_focus()
	if App.reduced_motion():
		modulate.a = 1.0
		return
	card.pivot_offset = card.size / 2
	card.scale = Vector2(0.94, 0.94)
	var tw := create_tween().set_parallel()
	tw.tween_property(self, "modulate:a", 1.0, 0.14)
	tw.tween_property(card, "scale", Vector2.ONE, Style.M_BASE).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

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
