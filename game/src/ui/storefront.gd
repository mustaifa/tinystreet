class_name Storefront
extends Control
## The street front around a café (or bakery) interior: a striped awning with
## a scalloped edge, plaster pillars, a cornice, and a strip of pavement with
## two potted plants. The interior keeps its own aspect ratio and is centred;
## the facade fills the rest, so there are never empty bands.
## Decoration only: it draws nothing over the interior except the awning's
## soft shadow along the very top edge.

const SIDE := 20.0
const TOP := 58.0
const BOTTOM := 40.0

var view: Control             # CafeView or BakeryView (600x560 design space)
var awning := Style.TEAL
var awning_edge := Style.TEAL_EDGE
var plaster := Color("ead7b9")
var _front: _Front

func _init(interior: Control = null, bakery: bool = false) -> void:
	view = interior
	if bakery:
		awning = Color("d77f88")
		awning_edge = Color("a4525d")
		plaster = Color("efd9cc")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = false
	if view:
		view.mouse_filter = Control.MOUSE_FILTER_IGNORE
		add_child(view)
	_front = _Front.new()
	_front.owner_front = self
	_front.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_front)
	resized.connect(_layout)
	_layout()

func inner_rect() -> Rect2:
	var aw := 600.0
	var ah := 560.0
	var k := minf((size.x - SIDE * 2) / aw, (size.y - TOP - BOTTOM) / ah)
	k = maxf(k, 0.05)
	var w := aw * k
	var h := ah * k
	var x := (size.x - w) / 2
	# awning, facade and pavement stay together as one centred unit
	var y := TOP + (size.y - TOP - BOTTOM - h) / 2
	return Rect2(x, y, w, h)

func top_y() -> float:
	return inner_rect().position.y - TOP

func _layout() -> void:
	var r := inner_rect()
	if view:
		view.position = r.position
		view.size = r.size
	_front.position = Vector2.ZERO
	_front.size = size
	queue_redraw()
	_front.queue_redraw()

func _draw() -> void:
	var r := inner_rect()
	var t0 := top_y()
	var fr := Rect2(r.position.x - SIDE, t0 + 6, r.size.x + SIDE * 2, r.end.y + BOTTOM - 6 - t0)
	# soft ground shadow
	draw_style_box(Style.box(Color(0, 0, 0, 0), 30, Color.TRANSPARENT, 0, true), fr.grow(-6))
	var sb := StyleBoxFlat.new()
	sb.bg_color = plaster
	sb.corner_radius_top_left = 26
	sb.corner_radius_top_right = 26
	sb.corner_radius_bottom_left = 18
	sb.corner_radius_bottom_right = 18
	sb.anti_aliasing = true
	draw_style_box(sb, fr)
	# brick hints on the pillars
	var brick := Color(Style.WOOD, 0.13)
	var y := t0 + TOP
	var row := 0
	while y < r.end.y:
		for side in [fr.position.x + 4, r.end.x + 2]:
			var off := 0.0 if row % 2 == 0 else 7.0
			draw_line(Vector2(side, y), Vector2(side + SIDE - 6, y), brick, 2)
			draw_line(Vector2(side + off + 4, y), Vector2(side + off + 4, y + 14), brick, 2)
		y += 15
		row += 1
	# pavement
	var pv := Rect2(fr.position.x, r.end.y + 8, fr.size.x, BOTTOM - 8)
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color("cdb79a")
	ps.corner_radius_bottom_left = 18
	ps.corner_radius_bottom_right = 18
	draw_style_box(ps, pv)
	draw_line(Vector2(pv.position.x, pv.position.y), Vector2(pv.end.x, pv.position.y), Color("b59d7d"), 3)
	var x := pv.position.x + 30
	while x < pv.end.x:
		draw_line(Vector2(x, pv.position.y + 4), Vector2(x - 8, pv.end.y - 2), Color(1, 1, 1, 0.18), 2)
		x += 58
	# interior frame
	draw_style_box(Style.box(Color("4a3a30"), 22, Color.TRANSPARENT, 0, false), r.grow(5))

## Awning and planters, drawn above the interior.
class _Front extends Control:
	var owner_front: Storefront

	func _draw() -> void:
		var f := owner_front
		var r := f.inner_rect()
		var x0 := r.position.x - f.SIDE - 8
		var x1 := r.end.x + f.SIDE + 8
		var top := f.top_y()
		var h := f.TOP - 2
		# shadow cast on the wall/interior
		draw_rect(Rect2(r.position.x, r.position.y - 4, r.size.x, 12), Color(0, 0, 0, 0.14))
		# awning valance with stripes and a scalloped edge
		var n := maxi(6, int((x1 - x0) / 56.0))
		var sw := (x1 - x0) / n
		var body := Rect2(x0, top, x1 - x0, h - 14)
		var bsb := StyleBoxFlat.new()
		bsb.bg_color = Style.PAPER
		bsb.corner_radius_top_left = 18
		bsb.corner_radius_top_right = 18
		draw_style_box(bsb, body)
		for i in n:
			var sx := x0 + i * sw
			var col: Color = f.awning if i % 2 == 0 else Style.PAPER
			if i % 2 == 0:
				var st := StyleBoxFlat.new()
				st.bg_color = col
				if i == 0:
					st.corner_radius_top_left = 18
				if i == n - 1:
					st.corner_radius_top_right = 18
				draw_style_box(st, Rect2(sx, top, sw, h - 14))
			# scallop
			var pts := PackedVector2Array()
			for k in 13:
				var a := PI * k / 12.0
				pts.append(Vector2(sx + sw / 2 + cos(a) * sw / 2, top + h - 14 + sin(a) * 14))
			draw_colored_polygon(pts, col)
			draw_polyline(pts, Color(f.awning_edge, 0.45), 2, true)
		draw_line(Vector2(x0 + 6, top + h - 14), Vector2(x1 - 6, top + h - 14), Color(f.awning_edge, 0.35), 2)
		# top highlight
		draw_line(Vector2(x0 + 18, top + 6), Vector2(x1 - 18, top + 6), Color(1, 1, 1, 0.35), 3, true)
		# planters on the pavement
		for px in [r.position.x - 4, r.end.x + 4]:
			_planter(Vector2(px, r.end.y + f.BOTTOM - 6))

	func _planter(base: Vector2) -> void:
		var pot := PackedVector2Array([base + Vector2(-18, -26), base + Vector2(18, -26), base + Vector2(13, 0), base + Vector2(-13, 0)])
		draw_colored_polygon(pot, Style.TERRACOTTA)
		draw_rect(Rect2(base + Vector2(-20, -30), Vector2(40, 7)), Style.TERRACOTTA.darkened(0.15))
		var leaf := Color("5f8f5a")
		for k in 5:
			var a := -PI / 2 + (k - 2) * 0.42
			var tip := base + Vector2(0, -30) + Vector2(cos(a), sin(a)) * 30
			draw_line(base + Vector2(0, -30), tip, leaf, 6, true)
			draw_circle(tip, 7, leaf.lightened(0.1 * (k % 2)))
