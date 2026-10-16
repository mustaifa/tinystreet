class_name Backdrop
extends Control
## Setting behind the puzzle: wallpaper above `split` (local y) and a warm
## wooden counter top below it, where the crates stand. Decoration is kept
## low-contrast so pieces, tickets and labels always read first.
##   cafe    cream stripes with a small bean motif, picture rail, oak counter
##   night   Midnight Ledger: midnight wallpaper with a faint gold lattice,
##           a lantern glow, and a dark walnut counter
##   bakery  rose stripes and a pale beech counter
## Drawn on resize/split change only; no per-frame cost.

var split := 600.0
var mode := "cafe"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_split(y: float) -> void:
	if absf(y - split) > 0.5:
		split = y
		queue_redraw()

func _draw() -> void:
	var w := size.x
	match mode:
		"night": _night_wall(w)
		"bakery": _wall(w, Color("f8e6df"), Color(1, 1, 1, 0.45), Color(Style.ROSE, 0.22))
		_: _wall(w, Color("f6e7cf"), Color(1, 1, 1, 0.30), Color(Style.WOOD, 0.12))
	_rail(w)
	_counter(w)

func _wall(w: float, base: Color, stripe: Color, motif: Color) -> void:
	draw_rect(Rect2(0, 0, w, split), base)
	var sw := 44.0
	for i in int(w / sw) + 1:
		if i % 2 == 0:
			draw_rect(Rect2(i * sw, 0, sw * 0.5, split), stripe)
	for i in int(w / sw) + 1:
		for j in int(split / 120.0) + 1:
			var c := Vector2(i * sw + sw * 0.75, 50 + j * 120 + (i % 2) * 60)
			_bean(c, 5.0, 0.6 + i * 0.3, motif)
	# soft light from above
	_vgrad(Rect2(0, 0, w, 160), Color(1, 0.98, 0.92, 0.5), Color(1, 0.98, 0.92, 0.0))

func _night_wall(w: float) -> void:
	_vgrad(Rect2(0, 0, w, split), Color("1d2747"), Color("172038"))
	# a faint gold lattice
	var step := 64.0
	var col := Color(Style.LANTERN, 0.06)
	var x := -split
	while x < w:
		draw_line(Vector2(x, 0), Vector2(x + split, split), col, 2)
		draw_line(Vector2(x + split, 0), Vector2(x, split), col, 2)
		x += step
	# lantern glow, top corner
	var gc := Vector2(w * 0.9, 30)
	for k in 6:
		draw_circle(gc, 220.0 - k * 34.0, Color(Style.LANTERN, 0.02 + k * 0.006))

func _rail(w: float) -> void:
	var night := mode == "night"
	draw_rect(Rect2(0, split - 28, w, 28), Color("2a3352") if night else Color("e8d2b0"))
	draw_line(Vector2(0, split - 28), Vector2(w, split - 28), Color(Style.LANTERN, 0.35) if night else Color(Style.WOOD, 0.4), 3)

func _counter(w: float) -> void:
	var night := mode == "night"
	var top := Color("4f3527") if night else (Color("d6aa7f") if mode == "bakery" else Color("c48d5e"))
	var lip := Color("6e4a35") if night else (Color("e7c49f") if mode == "bakery" else Color("d9a87c"))
	var h := size.y - split
	draw_rect(Rect2(0, split, w, h), top)
	draw_rect(Rect2(0, split, w, 14), lip)
	draw_line(Vector2(0, split + 14), Vector2(w, split + 14), Color(0, 0, 0, 0.18), 3)
	var plank := 92.0
	var y := split + 14 + plank
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(w, y), Color(0, 0, 0, 0.08), 2)
		y += plank
	# wood grain
	for i in 12:
		var gx := fmod(i * 173.0, w)
		var gy := split + 30 + fmod(i * 67.0, maxf(h - 40, 1))
		draw_line(Vector2(gx, gy), Vector2(gx + 50, gy), Color(0, 0, 0, 0.06), 2)
	# a darker floor at the very bottom, under the dock
	_vgrad(Rect2(0, size.y - 220, w, 220), Color(0, 0, 0, 0.0), Color(0, 0, 0, 0.10))

func _bean(c: Vector2, r: float, a: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 12:
		var t := TAU * i / 12.0
		pts.append(c + Vector2(cos(t) * r, sin(t) * r * 0.66).rotated(a))
	draw_colored_polygon(pts, col)

func _vgrad(r: Rect2, a: Color, b: Color) -> void:
	var pts := PackedVector2Array([r.position, Vector2(r.end.x, r.position.y), r.end, Vector2(r.position.x, r.end.y)])
	draw_polygon(pts, PackedColorArray([a, a, b, b]))
