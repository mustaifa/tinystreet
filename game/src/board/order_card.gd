class_name OrderCard
extends Control

signal tapped(tray: int)
## One customer order ticket. Shows who ordered (portrait), the current
## stage's requirements as one picture per unit (ghosted until filled), and
## the SECOND stage (if any) in advance, marked "then".

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
var bell_allowed := false       # v3: tap the ticket to ring its bell
var bell_on := false            # this customer is served first
var bell_spent := false         # v4: the page's bell budget is used up (still tappable, to explain)
var special := false            # 3-part special order (gold frame + banner)
var _wiggle := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_bell(allowed: bool, on: bool, spent: bool = false) -> void:
	bell_allowed = allowed
	bell_on = on
	bell_spent = spent
	mouse_filter = Control.MOUSE_FILTER_STOP if allowed else Control.MOUSE_FILTER_IGNORE
	queue_redraw()

func wiggle() -> void:
	if App.reduced_motion():
		return
	var tw := create_tween()
	tw.tween_method(func(v): _wiggle = v; queue_redraw(), 1.0, 0.0, 0.5)

func _gui_input(e: InputEvent) -> void:
	if bell_allowed and e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT and not e.pressed:
		if Rect2(Vector2.ZERO, size).has_point(e.position):
			tapped.emit(tray)
			accept_event()
	elif bell_allowed and e is InputEventMouseButton and e.pressed:
		accept_event()

func bell_center() -> Vector2:
	return Vector2(96, 32) if Loc.is_rtl() else Vector2(size.x - 96, 32)

## Bell drawn as a shape (dome, rim, clapper), filled when rung, outlined
## when not, so the state never depends on colour alone.
static func draw_bell(ci: CanvasItem, c: Vector2, r: float, on: bool, wig: float = 0.0) -> void:
	var col := Style.GOLD.darkened(0.15) if on else Style.INK_SOFT
	var ang := sin(wig * 18.0) * 0.35 * wig
	var pts := PackedVector2Array()
	for i in 13:
		var t := PI + PI * i / 12.0
		pts.append(c + Vector2(cos(t) * r * 0.8, sin(t) * r * 0.95 + r * 0.25).rotated(ang))
	pts.append(c + Vector2(r, r * 0.45).rotated(ang))
	pts.append(c + Vector2(-r, r * 0.45).rotated(ang))
	if on:
		ci.draw_colored_polygon(pts, Style.GOLD)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, col, maxf(2.0, r * 0.14), true)
	ci.draw_circle(c + Vector2(0, r * 0.62).rotated(ang), r * 0.18, col)
	ci.draw_circle(c + Vector2(0, -r * 0.78).rotated(ang), r * 0.13, col)

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

## v6 layout: one picture per unit the stage needs ("2 coffees" = two cups),
## ghosted until filled, so a ticket reads at a glance with no counting pips.
const HEAD := 58.0
const GAP := 8.0
const UNIT_MAX := 84.0
const UNIT_MIN := 50.0

static func units_of(req: PackedInt32Array) -> Array:
	var u: Array = []
	for p in Products.COUNT:
		for k in req[p]:
			u.append(p)
	return u

## [columns, unit size] that fit n units into `width`.
static func grid(n: int, width: float) -> Array:
	var avail := width - 28.0
	var cols := maxi(1, n)
	var u := 0.0
	for rows in range(1, 4):
		cols = int(ceil(n / float(rows)))
		u = minf(UNIT_MAX, (avail - (cols - 1) * GAP) / maxf(1, cols))
		if u >= UNIT_MIN:
			break
	return [cols, u]

## Height a ticket needs for the largest stage in `orders` at `width`.
static func needed_height(orders: Array, width: float) -> float:
	var h := 0.0
	for o in orders:
		var stg: Array = o
		for st in stg:
			var n := units_of(st).size()
			var g := grid(n, width)
			var rows := int(ceil(n / float(g[0])))
			h = maxf(h, HEAD + 12 + rows * (g[1] + GAP) + (52.0 if stg.size() > 1 else 6.0))
	return h

func icon_size() -> float:
	if order < 0 or stages.is_empty():
		return UNIT_MAX
	return grid(units_of(stages[stage]).size(), size.x)[1]

func unit_pos(j: int, n: int) -> Vector2:
	var g := grid(n, size.x)
	var cols: int = g[0]
	var u: float = g[1]
	var row := j / cols
	var in_row := mini(cols, n - row * cols)
	var col := j % cols
	var row_w := in_row * u + (in_row - 1) * GAP
	var x := (size.x - row_w) / 2 + u / 2 + col * (u + GAP)
	if Loc.is_rtl():
		x = size.x - x
	return Vector2(x, HEAD + 12 + row * (u + GAP) + u / 2)

func _row_y(i: int) -> float:
	var g := grid(units_of(stages[stage]).size(), size.x)
	return HEAD + 12 + i * (g[1] + GAP) + g[1] / 2

## Where the next item of product `p` lands: its first unit not drawn as filled.
func product_pos(p: int) -> Vector2:
	if order < 0 or stages.is_empty():
		return size / 2
	var units := units_of(stages[stage])
	var first := units.find(p)
	if first < 0:
		return size / 2
	var have := clampi(fill[p] - int(in_flight.get(p, 0)), 0, stages[stage][p] - 1)
	return unit_pos(first + have, units.size())

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
	if special and order >= 0:
		var sp := StyleBoxFlat.new()
		sp.bg_color = Color.TRANSPARENT
		sp.border_color = Style.GOLD
		sp.set_border_width_all(5)
		sp.set_corner_radius_all(22)
		draw_style_box(sp, rect)
	var head := StyleBoxFlat.new()
	head.bg_color = Color(Style.TEAL_SOFT, 0.75) if order >= 0 else Color(Style.CREAM_DEEP, 0.6)
	if bell_on and order >= 0:
		head.bg_color = Color("f6dd9c")
	head.corner_radius_top_left = 22
	head.corner_radius_top_right = 22
	draw_style_box(head, Rect2(Vector2(4, 4), Vector2(size.x - 8, HEAD)))
	for k in int((size.x - 30) / 16):
		draw_circle(Vector2(18 + k * 16, HEAD + 4), 3, Style.CREAM_DEEP)
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
	if bell_allowed:
		var bc := bell_center()
		draw_circle(bc, 22, Style.PAPER if not bell_on else Color("fff3d0"))
		draw_bell(self, bc, 15, bell_on, _wiggle)
		if bell_spent and not bell_on:
			draw_line(bc + Vector2(-14, 14), bc + Vector2(14, -14), Style.INK_SOFT, 3, true)
	if special:
		draw_string(Style.font_bold, Vector2(0, size.y - 14), Loc.t("special_tag"), HORIZONTAL_ALIGNMENT_CENTER, size.x, Style.fs(18), Style.WOOD_DARK)
	if stages.size() > 1:
		var lbl := "%d/%d" % [stage + 1, stages.size()]
		var lx := 58.0 if not rtl else size.x - 58.0 - 40
		draw_string(Style.font_regular, Vector2(lx, 42), lbl, HORIZONTAL_ALIGNMENT_LEFT, -1, Style.fs(22), Style.INK_SOFT)
	# current stage: one picture per unit, ghosted until it arrives
	var req: PackedInt32Array = stages[stage]
	var units := units_of(req)
	var u := icon_size()
	var seen := {}
	for j in units.size():
		var p: int = units[j]
		var k := int(seen.get(p, 0))
		seen[p] = k + 1
		var pos := unit_pos(j, units.size())
		var have := fill[p] - int(in_flight.get(p, 0))
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color(Style.CREAM_DEEP, 0.7) if k >= have else Color(Style.TEAL_SOFT, 0.9)
		plate.set_corner_radius_all(int(u * 0.3))
		draw_style_box(plate, Rect2(pos - Vector2(u, u) / 2, Vector2(u, u)))
		if k < have:
			ProductArt.draw(self, p, pos, u * 0.92)
			var cc := pos + Vector2(u * 0.34, u * 0.34)
			draw_circle(cc, u * 0.17 + 2, Style.PAPER)
			draw_circle(cc, u * 0.17, Style.TEAL)
			var q := u * 0.17
			draw_polyline(PackedVector2Array([cc + Vector2(-q * 0.45, 0), cc + Vector2(-q * 0.1, q * 0.4), cc + Vector2(q * 0.5, -q * 0.4)]), Color.WHITE, maxf(2.0, q * 0.28), true)
		else:
			ProductArt.draw(self, p, pos, u * 0.86, 0.38)
	var grid_rows := int(ceil(units.size() / float(grid(units.size(), size.x)[0])))
	var isz := u
	# next stage preview
	if stage + 1 < stages.size():
		var y := _row_y(grid_rows) - isz / 2 + 6
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
