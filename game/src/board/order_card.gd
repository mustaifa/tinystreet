class_name OrderCard
extends Control
## One customer order ticket. Shows who ordered (portrait), the current
## stage's requirements with fill pips, and the SECOND stage (if any) in
## advance, marked "then".

var tray := 0
var order := -1
var stages: Array = []          # Array[PackedInt32Array]
var stage := 0
var fill := PackedInt32Array()
var in_flight := {}             # product -> count not yet landed (drawn as empty)
var highlight := false          # destination preview
var hint_glow := false
var show_number := true
var customer := ""
var mood := 2                   # CharacterArt mood: waiting until served

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_order(o: int, st: Array, stg: int, f: PackedInt32Array) -> void:
	order = o
	stages = st
	stage = stg
	fill = f.duplicate()
	queue_redraw()

func _rows(stage_req: PackedInt32Array) -> Array:
	var r: Array = []
	for p in Products.COUNT:
		if stage_req[p] > 0:
			r.append(p)
	return r

func icon_size() -> float:
	return minf(70.0, size.x * 0.3)

func _row_y(i: int) -> float:
	return 74 + i * (icon_size() + 10) + icon_size() / 2

func product_pos(p: int) -> Vector2:
	if order < 0 or stages.is_empty():
		return size / 2
	var rows := _rows(stages[stage])
	var i := maxi(0, rows.find(p))
	var x := 18 + icon_size() / 2
	if Loc.is_rtl():
		x = size.x - x
	return Vector2(x, _row_y(i))

func product_global_pos(p: int) -> Vector2:
	return get_global_transform() * product_pos(p)

func _draw() -> void:
	var rect := Rect2(Vector2(4, 4), size - Vector2(8, 8))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.PAPER
	sb.set_corner_radius_all(22)
	sb.shadow_color = Style.SHADOW
	sb.shadow_size = 10
	sb.shadow_offset = Vector2(0, 5)
	if highlight:
		sb.border_color = Style.TEAL
		sb.set_border_width_all(6)
	elif hint_glow:
		sb.border_color = Style.GOLD
		sb.set_border_width_all(5)
	draw_style_box(sb, rect)
	var f := Style.font_bold
	var rtl := Loc.is_rtl()
	# ticket header strip with a perforated edge
	var head := StyleBoxFlat.new()
	head.bg_color = Color(Style.TEAL_SOFT, 0.75) if order >= 0 else Color(Style.CREAM_DEEP, 0.6)
	head.corner_radius_top_left = 22
	head.corner_radius_top_right = 22
	draw_style_box(head, Rect2(Vector2(4, 4), Vector2(size.x - 8, 60)))
	for k in int((size.x - 30) / 16):
		draw_circle(Vector2(18 + k * 16, 64), 3, Style.CREAM_DEEP)
	if order < 0:
		draw_string(Style.font_regular, Vector2(0, size.y / 2 + 10), Loc.t("tray_free"), HORIZONTAL_ALIGNMENT_CENTER, size.x, Style.fs(24), Style.INK_SOFT)
		return
	# header: tray number badge + customer portrait
	var badge := Vector2(size.x - 32, 34) if rtl else Vector2(32, 34)
	draw_circle(badge, 20, Style.TEAL)
	draw_string(f, badge + Vector2(-20, 9), str(tray + 1), HORIZONTAL_ALIGNMENT_CENTER, 40, 26, Color.WHITE)
	var cpos := Vector2(40, 32) if rtl else Vector2(size.x - 40, 32)
	draw_circle(cpos, 30, Style.PAPER)
	CharacterArt.draw(self, customer, cpos + Vector2(0, 2), 58, mood)
	if stages.size() > 1:
		var lbl := "%d/%d" % [stage + 1, stages.size()]
		draw_string(Style.font_regular, Vector2(0, 46), lbl, HORIZONTAL_ALIGNMENT_CENTER, size.x, Style.fs(22), Style.INK_SOFT)
	# current stage rows
	var req: PackedInt32Array = stages[stage]
	var rows := _rows(req)
	var isz := icon_size()
	for i in rows.size():
		var p: int = rows[i]
		var pos := product_pos(p)
		ProductArt.draw(self, p, pos, isz * 0.9)
		var need := req[p]
		var have := fill[p] - int(in_flight.get(p, 0))
		var pip := minf(16.0, (size.x - isz - 48) / maxf(1.0, need) / 2.4)
		for k in need:
			var px := 30 + isz + pip + k * pip * 2.4
			if rtl:
				px = size.x - px
			var pc := Vector2(px, pos.y)
			if k < have:
				draw_circle(pc, pip, Style.TEAL)
				draw_polyline(PackedVector2Array([pc + Vector2(-pip * 0.45, 0), pc + Vector2(-pip * 0.1, pip * 0.4), pc + Vector2(pip * 0.5, -pip * 0.4)]), Color.WHITE, maxf(2.0, pip * 0.25), true)
			else:
				draw_arc(pc, pip - 1.5, 0, TAU, 20, Color(Style.INK_SOFT, 0.7), 3, true)
	# next stage preview
	if stage + 1 < stages.size():
		var y := _row_y(rows.size()) - isz / 2 + 6
		draw_line(Vector2(18, y - 4), Vector2(size.x - 18, y - 4), Color(Style.INK_SOFT, 0.25), 2, true)
		var nreq: PackedInt32Array = stages[stage + 1]
		var x := 22.0
		var label := Loc.t("then")
		var lw := f.get_string_size(label, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(20)).x
		draw_string(Style.font_regular, Vector2(size.x - x - lw if rtl else x, y + 32), label, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(20), Style.INK_SOFT)
		x += lw + 10
		var small := isz * 0.6
		for p in _rows(nreq):
			var cx := x + small / 2
			ProductArt.draw(self, p, Vector2(size.x - cx if rtl else cx, y + 24), small, 0.6)
			x += small + 2
			var t := "×%d" % nreq[p]
			var tw := Style.font_bold.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(20)).x
			draw_string(Style.font_bold, Vector2(size.x - x - tw if rtl else x, y + 32), t, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(20), Style.INK_SOFT)
			x += tw + 10
