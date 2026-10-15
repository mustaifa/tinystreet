class_name CafeView
extends Control
## The café illustration. Drawn in a 600x520 design space, scaled to fit.
## `milestones` 0..5 changes the building visibly at each stage:
##  0 abandoned  1 clean storefront  2 windows+entrance  3 counter+coffee
##  4 seating, lighting, plants  5 sign + opening celebration

const W := 600.0
const H := 520.0

const WALLS := {"cream": Color("f1dfc0"), "sage": Color("bccfb2"), "blush": Color("eec4b8"), "evening": Color("2f4858")}
const TRIMS := {"cream": Color("1f7a72"), "sage": Color("7c5034"), "blush": Color("1f7a72"), "evening": Color("e0a93b")}

var milestones := 0
var choices := {"wall": "cream", "seating": "bistro", "plants": "ferns", "sign": "script"}
var celebrate := 0.0     # 0..1 animated sparkle for the opening
var preview_flash := 0.0
var _t := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if milestones >= 5 and not App.reduced_motion():
		_t += delta
		queue_redraw()

func configure(m: int, ch: Dictionary) -> void:
	milestones = m
	choices = ch.duplicate()
	queue_redraw()

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
		draw_style_box(sb, Rect2(x, y, w, h))

func _scene() -> void:
	var m := milestones
	var evening: bool = choices.get("wall") == "evening"
	# sky + street
	_rect(0, 0, W, H, Color("f6ead7") if not evening else Color("3d4b63"), 30)
	if evening:
		for i in 14:
			draw_circle(Vector2(fmod(i * 97.0, W), 20 + fmod(i * 53.0, 90)), 2, Color(1, 1, 0.9, 0.7))
	_rect(0, 440, W, 80, Color("cbb79c") if not evening else Color("5a5560"))
	for i in 8:
		_rect(i * 80 + 10, 470, 50, 6, Color(1, 1, 1, 0.25))
	# neighbours (simple, muted)
	_rect(0, 90, 70, 350, Color("d8c7b0") if not evening else Color("44506a"))
	_rect(530, 70, 70, 370, Color("cdb9a0") if not evening else Color("3f4a63"))
	# building facade
	var wall: Color = WALLS.get(choices.get("wall", "cream"), WALLS.cream)
	var trim: Color = TRIMS.get(choices.get("wall", "cream"), TRIMS.cream)
	if m == 0:
		wall = Color("a39b90")
		trim = Color("6d655c")
	_rect(70, 60, 460, 380, wall)
	_rect(60, 50, 480, 22, trim, 6)           # cornice
	_rect(70, 420, 460, 20, wall.darkened(0.12))
	if m == 0:
		# grime patches and cracks
		for i in 7:
			draw_circle(Vector2(110 + i * 62, 120 + (i * 37) % 260), 26 + (i % 3) * 10, Color(0.35, 0.3, 0.25, 0.18))
		draw_polyline(PackedVector2Array([Vector2(420, 70), Vector2(410, 120), Vector2(430, 160), Vector2(415, 210)]), Color(0.3, 0.25, 0.2, 0.6), 3, true)
	# --- sign board
	_sign(m, trim, evening)
	# --- windows & door
	_windows(m, trim, evening)
	# --- awning (m>=2)
	if m >= 2:
		var stripes := 9
		for i in stripes:
			var c := Style.TERRACOTTA if i % 2 == 0 else Color("f6ead7")
			draw_colored_polygon(PackedVector2Array([Vector2(90 + i * 46.6, 186), Vector2(90 + (i + 1) * 46.6, 186),
				Vector2(84 + (i + 1) * 48, 226), Vector2(84 + i * 48, 226)]), c)
		for i in stripes:
			draw_circle(Vector2(84 + i * 48 + 24, 226), 24, Style.TERRACOTTA if i % 2 == 0 else Color("f6ead7"))
		_rect(86, 182, 428, 8, trim, 3)
	# --- seating, lighting, plants
	if m >= 4:
		_lights(evening)
		_plants()
		_seating()
	elif m >= 1:
		# a tidy bench outline and broom shows the clean-up has begun
		draw_line(Vector2(470, 440), Vector2(500, 370), Style.WOOD_DARK, 5, true)
		draw_colored_polygon(PackedVector2Array([Vector2(492, 368), Vector2(512, 372), Vector2(506, 352), Vector2(496, 350)]), Color("d9a441"))
	if m == 0:
		# litter + leaves on the pavement
		for i in 9:
			var p := Vector2(90 + i * 52, 448 + (i % 3) * 8)
			draw_colored_polygon(PackedVector2Array([p, p + Vector2(14, -6), p + Vector2(22, 4), p + Vector2(8, 8)]), Color("9b7a4a") if i % 2 else Color("b88c55"))
	# --- opening celebration
	if m >= 5:
		_bunting()
		_open_board()
		if not App.reduced_motion():
			for i in 10:
				var ph := fmod(_t * 0.3 + i * 0.1, 1.0)
				var p := Vector2(80 + fmod(i * 131.0, 440), 40 + ph * 120)
				draw_circle(p, 3 + (i % 3), [Style.GOLD, Style.TERRACOTTA, Style.TEAL][i % 3] * Color(1, 1, 1, 1.0 - ph))

func _sign(m: int, trim: Color, evening: bool) -> void:
	if m < 5:
		var col := Color("8b7e70") if m == 0 else Color("c9b79e")
		var tilt := 0.05 if m == 0 else 0.0
		_rect(170, 92 + tilt * 40, 260, 64, col, 10)
		if m >= 1:
			draw_string(Style.font_bold, Vector2(170, 136), Loc.t("cafe_sign_soon"), HORIZONTAL_ALIGNMENT_CENTER, 260, 24, Color(Style.INK, 0.55))
		return
	var style: String = choices.get("sign", "script")
	var bg: Color = {"script": Color("fffaf2"), "block": Style.TEAL, "painted": Style.TERRACOTTA, "evening": Color("23303e")}.get(style, Color("fffaf2"))
	var fg: Color = {"script": Style.TEAL_DARK, "block": Color.WHITE, "painted": Color("fffaf2"), "evening": Style.GOLD}.get(style, Style.TEAL_DARK)
	_rect(150, 86, 300, 76, bg, 16 if style != "block" else 6)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.border_color = trim if style != "evening" else Style.GOLD
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(16 if style != "block" else 6)
	draw_style_box(sb, Rect2(150, 86, 300, 76))
	var f: Font = Style.font_bold
	draw_string(f, Vector2(150, 136), Loc.t("cafe_sign"), HORIZONTAL_ALIGNMENT_CENTER, 300, 34, fg)
	if style == "evening" or evening:
		for i in 12:
			draw_circle(Vector2(160 + i * 25.5, 82), 3, Color(1, 0.86, 0.5, 0.9))

func _windows(m: int, trim: Color, evening: bool) -> void:
	var glass := Color("bfe0dc") if not evening else Color("f3c770")
	var interior := Color("f7e6c4") if not evening else Color("f6c76a")
	for wx in [100.0, 380.0]:
		_rect(wx - 8, 238, 136, 172, trim, 8)
		if m < 2:
			_rect(wx, 246, 120, 156, Color("4f463d"))
			for j in 3:
				var y := 262 + j * 46
				draw_colored_polygon(PackedVector2Array([Vector2(wx - 6, y), Vector2(wx + 126, y + 10), Vector2(wx + 126, y + 30), Vector2(wx - 6, y + 20)]), Color("9a7650") if m == 0 else Color("b48d62"))
		else:
			_rect(wx, 246, 120, 156, interior if m >= 3 else glass)
			if m >= 3:
				_interior(wx)
			draw_line(Vector2(wx + 60, 246), Vector2(wx + 60, 402), trim, 5)
			draw_line(Vector2(wx, 324), Vector2(wx + 120, 324), trim, 5)
			draw_line(Vector2(wx + 14, 260), Vector2(wx + 40, 286), Color(1, 1, 1, 0.6), 4, true)
	# door
	_rect(252, 238, 96, 182, trim, 8)
	if m < 2:
		_rect(260, 246, 80, 174, Color("5e5246"))
		draw_colored_polygon(PackedVector2Array([Vector2(254, 280), Vector2(346, 330), Vector2(346, 348), Vector2(254, 298)]), Color("9a7650"))
		draw_colored_polygon(PackedVector2Array([Vector2(346, 300), Vector2(254, 360), Vector2(254, 378), Vector2(346, 318)]), Color("9a7650"))
	else:
		_rect(260, 246, 80, 174, Style.WOOD)
		_rect(270, 256, 60, 80, interior if m >= 3 else glass, 6)
		draw_circle(Vector2(326, 340), 5, Style.GOLD)
		_rect(240, 420, 120, 12, Color("b9a98f"), 3)   # step

func _interior(wx: float) -> void:
	# counter and espresso machine silhouettes visible through the window
	_rect(wx + 4, 352, 112, 46, Style.WOOD, 4)
	_rect(wx + 4, 348, 112, 8, Style.WOOD_DARK, 3)
	_rect(wx + 14, 314, 40, 34, Color("9aa4a6"), 6)
	_rect(wx + 20, 306, 28, 10, Color("6d7476"), 3)
	draw_circle(Vector2(wx + 34, 332), 6, Color("3b2f2a"))
	for i in 3:
		ProductArt.draw(self, Products.COFFEE, Vector2(wx + 74 + i * 14, 338), 16)
	_rect(wx + 10, 262, 100, 6, Style.WOOD_DARK, 2)
	for i in 4:
		ProductArt.draw(self, [Products.TEA, Products.CHOCOLATE, Products.TEA, Products.CUPCAKE][i], Vector2(wx + 22 + i * 26, 254), 20)

func _lights(evening: bool) -> void:
	var pts := PackedVector2Array()
	for i in 21:
		var x := 80 + i * 22.0
		pts.append(Vector2(x, 176 + sin(i / 20.0 * PI * 3) * 6 + 6))
	draw_polyline(pts, Color("5e5246"), 2, true)
	for i in range(0, 21, 2):
		draw_circle(pts[i] + Vector2(0, 7), 6, Color(1, 0.85, 0.45) if not evening else Color(1, 0.8, 0.35))
		draw_circle(pts[i] + Vector2(0, 7), 11, Color(1, 0.85, 0.45, 0.25))

func _plants() -> void:
	var style: String = choices.get("plants", "ferns")
	for x in [60.0, 520.0]:
		_rect(x, 400, 40, 40, Style.TERRACOTTA, 6)
		match style:
			"olive":
				draw_line(Vector2(x + 20, 400), Vector2(x + 20, 330), Style.WOOD_DARK, 5)
				draw_circle(Vector2(x + 20, 318), 30, Color("8aa26a"))
				draw_circle(Vector2(x + 6, 330), 18, Color("9db37b"))
				draw_circle(Vector2(x + 34, 328), 18, Color("7d9660"))
			"flowers":
				for i in 5:
					var p := Vector2(x + 4 + i * 8, 392 - (i % 2) * 10)
					draw_line(Vector2(x + 20, 400), p, Color("4f8a4f"), 3, true)
					draw_circle(p, 7, [Color("e58fa8"), Color("f0c25a"), Color("ffffff")][i % 3])
			_:
				for i in 7:
					var a := PI + PI * i / 6.0
					draw_line(Vector2(x + 20, 400), Vector2(x + 20, 400) + Vector2(cos(a), sin(a)) * 42, Color("3f8a52"), 6, true)
	if style == "flowers":
		for wx in [92.0, 372.0]:
			_rect(wx, 404, 136, 14, Style.WOOD, 4)
			for i in 9:
				draw_circle(Vector2(wx + 10 + i * 15, 400), 6, [Color("e58fa8"), Color("f0c25a"), Color("d6453d")][i % 3])

func _seating() -> void:
	var style: String = choices.get("seating", "bistro")
	var c: Color = {"bistro": Style.WOOD_DARK, "rattan": Color("c9a26b"), "booth": Style.TERRACOTTA, "evening": Color("2b2b2b")}.get(style, Style.WOOD_DARK)
	for tx in [150.0, 450.0]:
		# table
		draw_line(Vector2(tx, 448), Vector2(tx, 470), Color("4a4a4a"), 4)
		_rect(tx - 28, 440, 56, 10, Color("f4efe6") if style != "evening" else Style.GOLD, 5)
		ProductArt.draw(self, Products.COFFEE, Vector2(tx - 8, 430), 22)
		ProductArt.draw(self, Products.CROISSANT, Vector2(tx + 12, 432), 20)
		for side in [-1, 1]:
			var cx: float = tx + side * 44
			if style == "booth":
				_rect(cx - 16, 438, 32, 34, c, 8)
			else:
				draw_line(Vector2(cx - side * 10, 470), Vector2(cx - side * 10, 430), c, 4, true)
				draw_line(Vector2(cx + side * 10, 470), Vector2(cx + side * 10, 448), c, 4, true)
				_rect(cx - 14, 446, 28, 6, c, 3)
				if style == "rattan":
					for k in 3:
						draw_line(Vector2(cx - side * 10, 432 + k * 5), Vector2(cx + side * 4, 432 + k * 5), Color("a8834e"), 2, true)

func _bunting() -> void:
	for i in 12:
		var x := 76 + i * 38.0
		var y := 64 + sin(i / 11.0 * PI) * 12
		draw_colored_polygon(PackedVector2Array([Vector2(x, y), Vector2(x + 30, y), Vector2(x + 15, y + 24)]),
			[Style.TERRACOTTA, Style.TEAL, Style.GOLD][i % 3])

func _open_board() -> void:
	_rect(372, 430, 76, 56, Color("2f2a28"), 6)
	draw_string(Style.font_bold, Vector2(372, 466), Loc.t("open_sign"), HORIZONTAL_ALIGNMENT_CENTER, 76, 20, Color("fffaf2"))
	draw_line(Vector2(380, 486), Vector2(372, 500), Color("2f2a28"), 4)
	draw_line(Vector2(440, 486), Vector2(448, 500), Color("2f2a28"), 4)
