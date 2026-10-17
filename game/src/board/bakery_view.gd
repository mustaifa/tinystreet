class_name BakeryView
extends Control
## Mira's Bakery, drawn in a 600x560 design space. A distinct look from the
## café: rose-and-mint tiles, a domed brick oven, bread shelves, a striped
## awning over the shop window. Every step changes it visibly:
##  0 dusty: cold oven, flour sacks, cobwebs, papered window
##  1 ovens     oven lit (fire flickers), floor swept, Mira at work
##  2 shelves   bread shelves (pine / whitewash) full of loaves
##  3 awning    striped awning (rose / mint / butter) and a clear window
##  4 opening   sign (loaf / whisk), bunting, customers at the counter

const W := 600.0
const H := 560.0
const AWNING := {"rose": Color("e58fa8"), "mint": Color("8fcfb7"), "butter": Color("f0d27a")}

var steps := 0
var choices := {}
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if App.reduced_motion() or not is_visible_in_tree():
		return
	_t += delta
	queue_redraw()

func configure_state(v: Dictionary) -> void:
	steps = int(v.get("steps", 0))
	choices = (v.get("choices", {}) as Dictionary).duplicate()
	queue_redraw()

func _c(k: String) -> String:
	return str(choices.get(k, Bakery.DEFAULTS.get(k, "")))

func _draw() -> void:
	var k := minf(size.x / W, size.y / H)
	var off := Vector2((size.x - W * k) / 2, (size.y - H * k) / 2)
	draw_set_transform(off, 0, Vector2(k, k))
	_scene()
	draw_set_transform(Vector2.ZERO)

func _rect(x: float, y: float, w: float, h: float, c: Color, r: int = 0) -> void:
	if r <= 0:
		draw_rect(Rect2(x, y, w, h), c)
	else:
		var sb := StyleBoxFlat.new()
		sb.bg_color = c
		sb.set_corner_radius_all(r)
		sb.anti_aliasing = true
		draw_style_box(sb, Rect2(x, y, w, h))

func _scene() -> void:
	var s := steps
	_rect(0, 0, W, H, Color("3a2a2a"), 28)
	# wall: rose and mint tiles (grey and grimy before the ovens step)
	var a := Color("f4d6dc") if s >= 1 else Color("bdb2ad")
	var b := Color("d9efe6") if s >= 1 else Color("aaa39e")
	for yy in 9:
		for xx in 15:
			_rect(14 + xx * 38.2, 70 + yy * 36, 37, 35, a if (xx + yy) % 2 == 0 else b)
	# floor
	_rect(14, 400, W - 28, H - 414, Color("cfa57a") if s >= 1 else Color("8d7d6c"))
	for i in 8:
		draw_line(Vector2(14, 410 + i * 18), Vector2(W - 14, 410 + i * 18), Color(0, 0, 0, 0.12), 2)
	_window(s)
	_oven(s)
	_shelves(s)
	_counter(s)
	if s < 1:
		for p in [Vector2(470, 470), Vector2(520, 486)]:
			_rect(p.x - 26, p.y - 34, 52, 60, Color("e8dcc4"), 12)
			draw_string(Style.font_bold, Vector2(p.x - 26, p.y), "FLOUR", HORIZONTAL_ALIGNMENT_CENTER, 52, 12, Color(0.4, 0.33, 0.25))
		for i in 3:
			draw_arc(Vector2(30, 76), 18 + i * 14, 0, PI * 0.5, 10, Color(0.95, 0.95, 0.95, 0.45), 1.5, true)
	_fascia(s)
	if s >= 4:
		for i in 14:
			var x := 20 + i * 40.0
			var y := 76 + sin(i / 13.0 * PI) * 12
			draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + 30, y), Vector2(x + 15, y + 22)]),
				[Color("e58fa8"), Color("8fcfb7"), Style.GOLD][i % 3])

func _window(s: int) -> void:
	var r := Rect2(380, 120, 190, 150)
	_rect(r.position.x - 8, r.position.y - 8, r.size.x + 16, r.size.y + 16, Style.WOOD_DARK, 8)
	_rect(r.position.x, r.position.y, r.size.x, r.size.y, Color("bfe0e8"))
	_rect(r.position.x, r.position.y + 70, r.size.x, 80, Color("cdb9a0"))
	if s >= 4:
		CharacterArt.draw(self, "n3", Vector2(r.position.x + 50, r.end.y - 20), 64, 1)
		CharacterArt.draw(self, "n5", Vector2(r.position.x + 130, r.end.y - 16), 64, 1)
	if s < 3:
		_rect(r.position.x, r.position.y, r.size.x, r.size.y, Color(0.85, 0.8, 0.7, 0.85))
		for i in 4:
			draw_line(r.position + Vector2(10 + i * 44, 10), r.position + Vector2(40 + i * 44, r.size.y - 10), Color(0.6, 0.55, 0.45, 0.4), 3)
	else:
		var col: Color = AWNING.get(_c("awning"), AWNING.rose)
		for i in 7:
			var x := r.position.x - 14 + i * 31.0
			draw_colored_polygon(PackedVector2Array([Vector2(x, 100), Vector2(x + 31, 100), Vector2(x + 31, 128), Vector2(x, 128)]),
				col if i % 2 == 0 else Color("fffaf2"))
			draw_circle(Vector2(x + 15.5, 128), 15.5, col if i % 2 == 0 else Color("fffaf2"))
		draw_line(r.position + Vector2(16, 14), r.position + Vector2(44, 42), Color(1, 1, 1, 0.6), 4, true)

func _oven(s: int) -> void:
	var c := Vector2(170, 330)
	# brick dome
	var pts := PackedVector2Array()
	for i in 25:
		var t := PI + PI * i / 24.0
		pts.append(c + Vector2(cos(t) * 140, sin(t) * 150))
	draw_colored_polygon(pts, Color("b0563f") if s >= 1 else Color("7d6a62"))
	for row in 6:
		var y := c.y - 20 - row * 24
		var half := sqrt(maxf(0.0, 1.0 - pow((c.y - y) / 150.0, 2))) * 140
		draw_line(Vector2(c.x - half, y), Vector2(c.x + half, y), Color(0, 0, 0, 0.18), 2)
		var x := c.x - half + (row % 2) * 18
		while x < c.x + half:
			draw_line(Vector2(x, y), Vector2(x, y - 24), Color(0, 0, 0, 0.14), 2)
			x += 36
	_rect(c.x - 150, c.y, 300, 70, Color("8c4632") if s >= 1 else Color("6b5a52"), 6)
	# mouth and fire
	var mouth := PackedVector2Array()
	for i in 17:
		var t := PI + PI * i / 16.0
		mouth.append(c + Vector2(cos(t) * 56, sin(t) * 62 - 4))
	draw_colored_polygon(mouth, Color("2a1d18"))
	if s >= 1:
		var fl := 1.0 + (0.12 * sin(_t * 7.0) + 0.08 * sin(_t * 11.3) if not App.reduced_motion() else 0.0)
		for k in 3:
			var fc := c + Vector2(-26 + k * 26, -12)
			draw_colored_polygon(PackedVector2Array([fc + Vector2(-14, 8), fc + Vector2(0, -30 * fl), fc + Vector2(14, 8)]), Color("f0a03a"))
			draw_colored_polygon(PackedVector2Array([fc + Vector2(-7, 8), fc + Vector2(0, -16 * fl), fc + Vector2(7, 8)]), Color("ffe08a"))
		draw_circle(c + Vector2(0, -20), 70, Color(1, 0.6, 0.2, 0.12))
		# a peel with fresh croissants
		ProductArt.draw(self, Products.CROISSANT, c + Vector2(-90, 40), 34)
		ProductArt.draw(self, Products.CROISSANT, c + Vector2(90, 40), 34)

func _shelves(s: int) -> void:
	if s < 2:
		return
	var wood := Color("d9b77f") if _c("shelf") == "pine" else Color("f2efe8")
	# a narrow loaf rack between the oven and the window
	_rect(318, 150, 6, 200, wood.darkened(0.25), 2)
	_rect(366, 150, 6, 200, wood.darkened(0.25), 2)
	for row in 3:
		var y := 190.0 + row * 56
		_rect(316, y, 58, 8, wood, 3)
		draw_colored_polygon(_ell(Vector2(345, y - 10), 20, 10), Color("c8873f"))
		draw_line(Vector2(336, y - 13), Vector2(354, y - 13), Color("8a5a2a"), 2)
	# a long shelf under the window
	_rect(380, 286, 190, 10, wood.darkened(0.15), 3)
	for i in 5:
		draw_colored_polygon(_ell(Vector2(400 + i * 36, 278), 16, 9), Color("c8873f"))
		draw_line(Vector2(392 + i * 36, 274), Vector2(408 + i * 36, 274), Color("8a5a2a"), 2)

func _ell(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 20:
		var t := TAU * i / 20.0
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	return pts

func _counter(s: int) -> void:
	if s >= 1:
		CharacterArt.draw(self, "mira", Vector2(470, 340), 110, 1 if s >= 4 else 0)
	_rect(330, 360, 256, 16, Color("f2efe8"), 5)
	_rect(338, 376, 240, 70, Color("8fcfb7") if s >= 1 else Color("9a948c"), 4)
	if s >= 1:
		_rect(350, 324, 110, 36, Color(0.9, 0.97, 0.97, 0.6), 6)
		ProductArt.draw(self, Products.CUPCAKE, Vector2(372, 344), 26)
		ProductArt.draw(self, Products.STRAWBERRY, Vector2(404, 344), 26)
		ProductArt.draw(self, Products.CHOCOLATE, Vector2(436, 344), 24)
	if s >= 4:
		CharacterArt.draw(self, "theo", Vector2(300, 452), 86, 1)
		CharacterArt.draw(self, "n1", Vector2(220, 456), 86, 1)

func _fascia(s: int) -> void:
	_rect(0, 0, W, 72, Color("5e5246") if s < 1 else Color("b45a7a"), 28)
	_rect(0, 40, W, 32, Color("5e5246") if s < 1 else Color("b45a7a"))
	if s < 4:
		_rect(150, 12, 300, 50, Color("8b7e70") if s < 1 else Color("e9d6db"), 10)
		draw_string(Style.font_bold, Vector2(150, 46), Loc.t("cafe_closed") if s < 1 else Loc.t("cafe_sign_soon"), HORIZONTAL_ALIGNMENT_CENTER, 300, 24, Color(Style.INK, 0.6))
		return
	_rect(120, 8, 360, 58, Color("fffaf2"), 18)
	draw_string(Style.font_bold, Vector2(176, 49), Loc.t("bakery_sign"), HORIZONTAL_ALIGNMENT_CENTER, 296, 30, Color("b45a7a"))
	if _c("bsign") == "whisk":
		var w := Vector2(140, 36)
		draw_line(w + Vector2(0, 14), w + Vector2(0, -2), Style.WOOD_DARK, 4)
		for k in 3:
			draw_arc(w + Vector2(0, -12), 8 + k * 2, PI, TAU, 10, Color("9aa4a6"), 2, true)
	else:
		draw_colored_polygon(_ell(Vector2(140, 36), 16, 10), Color("c8873f"))
		for k in 3:
			draw_line(Vector2(132 + k * 7, 31), Vector2(136 + k * 7, 41), Color("8a5a2a"), 2)
