extends Control
## The Midnight Ledger: optional expert puzzles (v4), presented as a book of
## pages under a night sky. Lessons, puzzles and the final page are separate
## sections; each page is a parchment card with its stamp and badges. The
## notice states plainly that difficulty labels are provisional until people
## have played the pages.

var screen_mode := "night"

func setup(_p: Dictionary) -> void:
	if not bool(App.data.ledger.offer_seen):
		App.data.ledger.offer_seen = true
		App.save_soon()
	var root := UI.vbox(14)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	var done := Ledger.done_count(App.data)
	var total := Ledger.pages().size()
	var pill := UI.pill("stamp", "%d/%d" % [done, total], Style.LANTERN, "night")
	root.add_child(UI.header(Loc.t("ledger_title"), func(): App.main.back(), pill, true))
	var v := UI.vbox(16)
	root.add_child(UI.scroll(v))
	v.add_child(_hero(done, total))
	if not Ledger.is_open(App.data):
		var lk := UI.row(UI.medallion("lock", Style.NIGHT_3, Style.MOON_SOFT, 64),
			Loc.t("ledger_locked", [App.progression.campaign_index(Ledger.UNLOCK_LEVEL) + 1]), "", null, "NightHeader")
		v.add_child(UI.card(lk, "NightCard"))
		return
	var last_group := ""
	for p in Ledger.pages():
		var grp := Ledger.group(p)
		if grp != last_group:
			last_group = grp
			v.add_child(_section(grp))
		v.add_child(_row(p))
	v.add_child(UI.spacer(8))

func _hero(done: int, total: int) -> Control:
	var col := UI.vbox(12)
	var art := _LedgerArt.new()
	art.custom_minimum_size = Vector2(0, 170)
	col.add_child(art)
	col.add_child(UI.label(Loc.t("ledger_intro"), "NightLabel"))
	# the stamp tracker: one mark per page
	var stamps := HFlowContainer.new()
	stamps.alignment = FlowContainer.ALIGNMENT_CENTER
	stamps.add_theme_constant_override("h_separation", 6)
	stamps.add_theme_constant_override("v_separation", 6)
	for p in Ledger.pages():
		var m := _Dot.new()
		m.state = 2 if Ledger.is_done(App.data, p.id) else (1 if Ledger.is_unlocked(App.data, p.id) else 0)
		m.final = Ledger.group(p) == "final"
		m.custom_minimum_size = Vector2(36, 36)
		stamps.add_child(m)
	col.add_child(stamps)
	col.add_child(UI.label(Loc.t("ledger_progress", [done, total]), "NightCaption"))
	var note := UI.row(UI.medallion("info", Style.NIGHT_3, Style.MOON_SOFT, 44), Loc.t("ledger_notice"), "", null, "NightSoft")
	col.add_child(note)
	return UI.card(col, "NightCard")

func _section(grp: String) -> Control:
	var h := UI.hbox(10)
	var g := Glyph.new()
	g.kind = {"lesson": "book", "puzzle": "moon", "final": "lantern"}.get(grp, "book")
	g.color = Style.LANTERN
	g.custom_minimum_size = Vector2(40, 40)
	h.add_child(g)
	var l := UI.label(Loc.t("ledger_group_" + grp), "NightHeader", UI.al(), false)
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(l)
	var n := 0
	var of := 0
	for p in Ledger.pages():
		if Ledger.group(p) == grp:
			of += 1
			if Ledger.is_done(App.data, p.id):
				n += 1
	h.add_child(UI.label("%d/%d" % [n, of], "NightCaption", HORIZONTAL_ALIGNMENT_CENTER, false))
	var wrap := UI.margin(h, 4, 10, 4, 0)
	return wrap

func _row(p: Dictionary) -> Control:
	var id: String = p.id
	var i := Ledger.info(p)
	var open := Ledger.is_unlocked(App.data, id)
	var done := Ledger.is_done(App.data, id)
	var final := Ledger.group(p) == "final"
	var row := UI.hbox(14)
	var num := str(Ledger.index(id) + 1)
	var med := _PageNumber.new()
	med.text = num
	med.state = 2 if done else (1 if open else 0)
	med.custom_minimum_size = Vector2(68, 68)
	med.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	row.add_child(med)
	var col := UI.vbox(4)
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var t := UI.label(Loc.t(str(i.get("name", ""))), "StrongLabel" if open else "NightHeader", UI.al())
	t.add_theme_font_size_override("font_size", Style.fs(28))
	if not open:
		t.add_theme_color_override("font_color", Style.MOON_SOFT)
	col.add_child(t)
	var sub := Loc.t(str(i.get("tagline", "")))
	if not open:
		sub = Loc.t("ledger_locked_final", [Ledger.FINAL_NEEDS]) if final else Loc.t("ledger_locked_page")
	var sl := UI.label(sub, "SoftLabel" if open else "NightSoft", UI.al())
	sl.add_theme_font_size_override("font_size", Style.fs(22))
	col.add_child(sl)
	if done:
		var tags := HFlowContainer.new()
		tags.add_theme_constant_override("h_separation", 6)
		tags.add_theme_constant_override("v_separation", 6)
		tags.add_child(UI.tag(Loc.t("ledger_tag_stamped"), Style.TEAL, Color.WHITE))
		if bool(App.data.ledger.nohint.get(id, false)):
			tags.add_child(UI.tag(Loc.t("ledger_tag_nohint"), Style.GOLD_SOFT, Style.INK))
		if bool(App.data.ledger.precision.get(id, false)):
			tags.add_child(UI.tag(Loc.t("ledger_tag_precision"), Style.GOLD_SOFT, Style.INK))
		col.add_child(tags)
	row.add_child(col)
	if open:
		var b := UI.button(Loc.t("replay") if done else Loc.t("ledger_open"), func(): App.main.goto("game", {"kind": "ledger", "id": id}),
			"SecondaryButton" if done else "LanternButton", 80)
		b.custom_minimum_size = Vector2(150, 80)
		b.autowrap_mode = TextServer.AUTOWRAP_OFF
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
	else:
		var g := Glyph.new()
		g.kind = "lock"
		g.color = Style.MOON_SOFT
		g.custom_minimum_size = Vector2(52, 52)
		g.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(g)
	var c := UI.card(row, "ParchmentCard" if open else "NightCard")
	if final and open:
		var sb := (c.get_theme_stylebox("panel") as StyleBoxFlat).duplicate() as StyleBoxFlat
		sb.border_color = Style.LANTERN
		sb.set_border_width_all(4)
		c.add_theme_stylebox_override("panel", sb)
	return c

## Page number medallion: ink on parchment; teal when stamped; dim when locked.
class _PageNumber extends Control:
	var text := "1"
	var state := 1

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) / 2
		var bg := Style.TEAL if state == 2 else (Style.NIGHT_2 if state == 1 else Style.NIGHT_3)
		draw_circle(c, r, bg)
		draw_arc(c, r - 4, 0, TAU, 32, Color(Style.LANTERN, 0.8 if state > 0 else 0.25), 2, true)
		if state == 2:
			Glyph.paint(self, "check", Rect2(c - Vector2(r, r) * 0.8, Vector2(r, r) * 1.6), Color.WHITE)
		else:
			draw_string(Style.font_black, Vector2(0, c.y + 11), text, HORIZONTAL_ALIGNMENT_CENTER, size.x, 32, Style.MOON if state > 0 else Style.MOON_SOFT)

## One mark in the stamp tracker.
class _Dot extends Control:
	var state := 0
	var final := false

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func _draw() -> void:
		var c := size / 2
		var r := minf(size.x, size.y) / 2 - 2
		match state:
			2:
				draw_circle(c, r, Style.LANTERN)
				Glyph.paint(self, "check", Rect2(c - Vector2(r, r), Vector2(r, r) * 2), Style.INK)
			1:
				draw_arc(c, r - 1, 0, TAU, 24, Style.LANTERN, 3, true)
			_:
				draw_arc(c, r - 1, 0, TAU, 24, Color(Style.MOON_SOFT, 0.35), 2, true)
		if final:
			draw_arc(c, r + 1, 0, TAU, 24, Color(Style.LANTERN, 0.6), 1.5, true)

## An open ledger under a lantern and a crescent moon.
class _LedgerArt extends Control:
	var _t := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE
		resized.connect(queue_redraw)

	func _process(delta: float) -> void:
		if App.reduced_motion() or not is_visible_in_tree():
			return
		_t += delta
		queue_redraw()

	func _draw() -> void:
		var c := Vector2(size.x / 2, size.y / 2 + 14)
		var glow := 0.5 + 0.08 * sin(_t * 1.3)
		for k in 5:
			draw_circle(c + Vector2(0, -20), 150.0 - k * 26, Color(Style.LANTERN, 0.03 * glow * (k + 1)))
		Glyph.paint(self, "moon", Rect2(Vector2(size.x * 0.12, 6), Vector2(70, 70)), Color(Style.MOON, 0.9))
		# book
		var w := 300.0
		var h := 110.0
		var left := PackedVector2Array([c + Vector2(0, -h * 0.42), c + Vector2(-w / 2, -h * 0.5), c + Vector2(-w / 2, h * 0.45), c + Vector2(0, h * 0.52)])
		var right := PackedVector2Array([c + Vector2(0, -h * 0.42), c + Vector2(w / 2, -h * 0.5), c + Vector2(w / 2, h * 0.45), c + Vector2(0, h * 0.52)])
		draw_colored_polygon(PackedVector2Array([c + Vector2(-w / 2 - 10, -h * 0.42), c + Vector2(w / 2 + 10, -h * 0.42), c + Vector2(w / 2 + 10, h * 0.6), c + Vector2(-w / 2 - 10, h * 0.6)]), Color("6b2f2a"))
		draw_colored_polygon(left, Style.PARCHMENT)
		draw_colored_polygon(right, Style.PARCHMENT.darkened(0.04))
		draw_line(c + Vector2(0, -h * 0.42), c + Vector2(0, h * 0.52), Style.PARCHMENT_EDGE, 3)
		for k in 5:
			var y := -h * 0.25 + k * 18.0
			draw_line(c + Vector2(-w / 2 + 22, y), c + Vector2(-18, y + 4), Color(Style.INK_SOFT, 0.35), 2)
			draw_line(c + Vector2(18, y + 4), c + Vector2(w / 2 - 22, y), Color(Style.INK_SOFT, 0.35), 2)
		Glyph.paint(self, "stamp", Rect2(c + Vector2(w / 2 - 92, -h * 0.05), Vector2(64, 64)), Color(Style.TERRACOTTA, 0.85))
		# lantern
		Glyph.paint(self, "lantern", Rect2(Vector2(size.x * 0.78, 0), Vector2(84, 84)), Style.LANTERN)
