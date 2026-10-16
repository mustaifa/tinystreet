class_name ScreenBackdrop
extends Control
## Full-bleed background behind every screen. Decoration stays low-contrast
## so text and controls keep their contrast.
##   cafe    warm cream with soft wallpaper stripes and a few coffee beans
##   night   Midnight Ledger: deep blue gradient, faint stars, lantern glow
##   bakery  rose-tinted cream for Mira's Bakery
## Drawn on resize or mode change only (no per-frame cost).

var mode := "cafe"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_mode(m: String) -> void:
	if m != mode:
		mode = m
		queue_redraw()

func _draw() -> void:
	match mode:
		"night": _night()
		"bakery": _cafe(Color("fbefe9"), Color(Style.ROSE, 0.10))
		_: _cafe(Style.CREAM, Color(1, 1, 1, 0.42))

func _cafe(ground: Color, stripe: Color) -> void:
	var w := size.x
	var h := size.y
	draw_rect(Rect2(Vector2.ZERO, size), ground)
	var sw := 54.0
	for i in int(w / sw) + 1:
		if i % 2 == 0:
			draw_rect(Rect2(i * sw, 0, sw * 0.5, h), stripe)
	# scattered coffee beans, faint
	var rng := RandomNumberGenerator.new()
	rng.seed = 11
	for k in 26:
		var p := Vector2(rng.randf_range(0, w), rng.randf_range(0, h))
		var a := rng.randf_range(0, PI)
		_bean(p, 9.0, a, Color(Style.WOOD, 0.07))
	# a warm glow from the top and a slightly deeper floor at the bottom
	var top := PackedColorArray([Color(1, 0.97, 0.9, 0.55), Color(1, 0.97, 0.9, 0.0)])
	_vgrad(Rect2(0, 0, w, h * 0.3), top)
	_vgrad(Rect2(0, h * 0.78, w, h * 0.22), PackedColorArray([Color(Style.WOOD_LIGHT, 0.0), Color(Style.WOOD_LIGHT, 0.16)]))

func _night() -> void:
	var w := size.x
	var h := size.y
	_vgrad(Rect2(Vector2.ZERO, size), PackedColorArray([Style.NIGHT, Color("0f1528")]))
	# lantern glow, top corner
	var gc := Vector2(w * 0.86, h * 0.06)
	for k in 6:
		draw_circle(gc, 260.0 - k * 38.0, Color(Style.LANTERN, 0.025 + k * 0.006))
	# faint stars
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	for k in 70:
		var p := Vector2(rng.randf_range(0, w), rng.randf_range(0, h * 0.85))
		var r := rng.randf_range(0.8, 2.2)
		draw_circle(p, r, Color(Style.MOON, rng.randf_range(0.10, 0.35)))
	# a ledger-paper rule pattern near the bottom, barely visible
	var y := h * 0.82
	while y < h:
		draw_line(Vector2(0, y), Vector2(w, y), Color(Style.MOON_SOFT, 0.04), 2)
		y += 34.0

func _bean(c: Vector2, r: float, a: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var t := TAU * i / 16.0
		pts.append(c + Vector2(cos(t) * r, sin(t) * r * 0.66).rotated(a))
	draw_colored_polygon(pts, col)
	draw_line(c + Vector2(-r * 0.7, 0).rotated(a), c + Vector2(r * 0.7, 0).rotated(a), Color(col, col.a * 1.8), 1.5, true)

func _vgrad(r: Rect2, cols: PackedColorArray) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	draw_polygon(pts, PackedColorArray([cols[0], cols[0], cols[1], cols[1]]))
