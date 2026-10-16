class_name Backdrop
extends Control
## Café setting behind the puzzle: striped wallpaper with a scalloped trim
## above, a warm wooden counter top below `split` (local y). Drawn once per
## resize; no per-frame cost.

var split := 600.0
var tint := Color("f6e7cf")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_split(y: float) -> void:
	if absf(y - split) > 0.5:
		split = y
		queue_redraw()

func _draw() -> void:
	var w := size.x
	draw_rect(Rect2(0, 0, w, split), tint)
	var stripe := 44.0
	for i in int(w / stripe) + 1:
		if i % 2 == 0:
			draw_rect(Rect2(i * stripe, 0, stripe * 0.5, split), Color(1, 1, 1, 0.28))
	# a small repeating motif (coffee bean) between stripes
	for i in int(w / stripe) + 1:
		for j in int(split / 120.0) + 1:
			var c := Vector2(i * stripe + stripe * 0.75, 50 + j * 120 + (i % 2) * 60)
			draw_circle(c, 4, Color(Style.WOOD, 0.12))
	# picture rail and wainscot
	draw_rect(Rect2(0, split - 28, w, 28), Color("e8d2b0"))
	draw_line(Vector2(0, split - 28), Vector2(w, split - 28), Color(Style.WOOD, 0.4), 3)
	# counter top
	draw_rect(Rect2(0, split, w, size.y - split), Color("c48d5e"))
	draw_rect(Rect2(0, split, w, 14), Color("d9a87c"))
	draw_line(Vector2(0, split + 14), Vector2(w, split + 14), Color(Style.WOOD_DARK, 0.5), 3)
	var plank := 92.0
	var y := split + 14 + plank
	while y < size.y:
		draw_line(Vector2(0, y), Vector2(w, y), Color(Style.WOOD_DARK, 0.18), 2)
		y += plank
	for i in 9:
		var x := fmod(i * 173.0, w)
		draw_line(Vector2(x, split + 30), Vector2(x + 40, split + 30), Color(Style.WOOD_DARK, 0.12), 2)
