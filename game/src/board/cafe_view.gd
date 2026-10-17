class_name CafeView
extends Control
## The café interior as a cut-away illustration, drawn in a 600x560 design
## space and scaled to fit. Every restoration step changes it visibly:
##  0 neglected: grey walls, boarded window, broken floor, dust and boxes
##  1 clean      boards off the window, clutter gone, cobwebs swept
##  2 walls      fresh paint (walls choice) and a wainscot
##  3 floor      new floor (oak / checker / terracotta)
##  4 counter    counter, espresso machine, shelves; Mira behind the counter
##  5 lights     pendants / string lights / globes; a warm glow
##  6 seating    tables and chairs (bistro / rattan / booth); Theo and Basil
##  7 plants     plants and a window box (ferns / olive / flowers)
##  8 opening    the sign, bunting, OPEN board, neighbours at the window
## Extras (clock, cake stand, gramophone, cat, photos, chalkboard) draw when
## owned.
##
## v3 life: once the counter is restored, neighbours come in through the side
## door, queue at the counter, Mira hands over a drink and they leave with it
## (a fixed, cheap timeline; no AI). Plants sway, the door swings, the lights
## breathe. `cheer()` makes the cast celebrate a milestone for a moment.
## Reduced motion: one customer simply stands at the counter; nothing moves.

const W := 600.0
const H := 560.0

const WALLS := {"cream": Color("f1dfc0"), "sage": Color("c3d4b8"), "blush": Color("efcbbf"), "evening": Color("34495e")}
const TRIMS := {"cream": Color("1f7a72"), "sage": Color("7c5034"), "blush": Color("1f7a72"), "evening": Color("e0a93b")}

var steps := 0
var choices := {}
var extras := {}
var preview := false       # draws a "preview" ribbon (restore screen peek)
var _t := 0.0
var _cheer := 0.0          # > 0 while the cast celebrates a milestone

const VISIT := 14.0        # seconds per customer visit cycle
const DOOR_X := 34.0
const QUEUE_X := 300.0
const FEET_Y := 404.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _process(delta: float) -> void:
	if App.reduced_motion() or not is_visible_in_tree():
		return
	_t += delta
	_cheer = maxf(0.0, _cheer - delta)
	queue_redraw()

## The cast bounces with a happy face for a couple of seconds.
func cheer() -> void:
	_cheer = 2.4
	queue_redraw()

func _cast_mood() -> int:
	return 1 if steps >= 8 or _cheer > 0.0 else 0

func _hop(phase: float) -> Vector2:
	if _cheer <= 0.0 or App.reduced_motion():
		return Vector2.ZERO
	return Vector2(0, -absf(sin(_t * 9.0 + phase)) * 12.0)

func configure_state(v: Dictionary) -> void:
	steps = int(v.get("steps", 0))
	choices = (v.get("choices", {}) as Dictionary).duplicate()
	extras = (v.get("extras", {}) as Dictionary).duplicate()
	queue_redraw()

func _c(k: String) -> String:
	return str(choices.get(k, Restoration.DEFAULTS.get(k, "")))

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

func _poly(pts: Array, c: Color) -> void:
	draw_colored_polygon(PackedVector2Array(pts), c)

func _scene() -> void:
	var s := steps
	var evening := _c("walls") == "evening" and s >= 2
	# frame (rounded clip look)
	_rect(0, 0, W, H, Color("2f2a28"), 28)
	_room(s, evening)
	_window(s, evening)
	_lights(s, evening)
	_door(s)
	_visitor(s)
	_shelves_counter(s)
	if extras.has("chalkboard"):
		_chalkboard(s)
	if extras.has("breadbasket"):
		_breadbasket(s)
	if extras.has("lamp"):
		_lamp()
	_extras_back(s)
	_seating(s)
	_plants(s)
	_extras_front(s)
	if s < 1:
		_clutter()
	_fascia(s, evening)
	if s >= 8:
		_bunting()
		if not App.reduced_motion():
			for i in 10:
				var ph := fmod(_t * 0.25 + i * 0.1, 1.0)
				var p := Vector2(60 + fmod(i * 131.0, 480), 90 + ph * 160)
				draw_circle(p, 3 + (i % 3), [Style.GOLD, Style.TERRACOTTA, Style.TEAL][i % 3] * Color(1, 1, 1, 1.0 - ph))
	if s >= 5:
		# warm light wash
		draw_rect(Rect2(14, 70, W - 28, H - 84), Color(1, 0.85, 0.5, 0.06 if not evening else 0.1))
	if preview:
		_rect(W / 2 - 110, H - 56, 220, 44, Color(Style.INK, 0.85), 22)
		draw_string(Style.font_bold, Vector2(W / 2 - 110, H - 26), Loc.t("preview"), HORIZONTAL_ALIGNMENT_CENTER, 220, 24, Color.WHITE)

# --- room: walls and floor ---------------------------------------------------

func _room(s: int, evening: bool) -> void:
	var wall := Color("a9a196")
	if s >= 2:
		wall = WALLS.get(_c("walls"), WALLS.cream)
	elif s >= 1:
		wall = Color("cfc6b8")
	_rect(14, 70, W - 28, 330, wall)
	if s >= 2:
		var trim: Color = TRIMS.get(_c("walls"), TRIMS.cream)
		# wainscot and picture rail
		_rect(14, 318, W - 28, 82, wall.darkened(0.1))
		for i in 15:
			_rect(24 + i * 38, 328, 28, 62, Color(1, 1, 1, 0.08), 4)
		_rect(14, 314, W - 28, 6, trim)
		_rect(14, 112, W - 28, 4, Color(trim, 0.5))
	else:
		# peeling patches and water stains
		for i in 6:
			draw_circle(Vector2(60 + i * 92, 140 + (i * 53) % 150), 22 + (i % 3) * 8, Color(0.3, 0.27, 0.22, 0.14 if s == 0 else 0.07))
		if s == 0:
			# cracks in the plaster
			draw_polyline(PackedVector2Array([Vector2(330, 80), Vector2(322, 120), Vector2(340, 150), Vector2(328, 196)]), Color(0.25, 0.2, 0.16, 0.5), 3, true)
			draw_polyline(PackedVector2Array([Vector2(520, 240), Vector2(500, 262), Vector2(512, 290)]), Color(0.25, 0.2, 0.16, 0.5), 3, true)
	# floor
	var fy := 400.0
	var fh := H - 14 - fy
	if s < 3:
		_rect(14, fy, W - 28, fh, Color("7d6f62") if s < 1 else Color("8d7d6c"))
		for i in 8:
			var y := fy + 8 + i * 18
			draw_line(Vector2(14, y), Vector2(W - 14, y), Color(0, 0, 0, 0.18), 2)
		if s < 1:
			_poly([Vector2(160, 440), Vector2(230, 436), Vector2(222, 452), Vector2(168, 456)], Color("3b322b"))
			_poly([Vector2(420, 486), Vector2(470, 482), Vector2(476, 498), Vector2(424, 500)], Color("3b322b"))
	else:
		match _c("floor"):
			"checker":
				var t := 36.0
				for yy in int(fh / t) + 1:
					for xx in int((W - 28) / t) + 1:
						var col := Color("f4efe6") if (xx + yy) % 2 == 0 else Color("3f3a37")
						var rw := minf(t, W - 14 - (14 + xx * t))
						var rh := minf(t, H - 14 - (fy + yy * t))
						if rw > 0 and rh > 0:
							_rect(14 + xx * t, fy + yy * t, rw, rh, col)
			"terracotta":
				_rect(14, fy, W - 28, fh, Color("c4744d"))
				for yy in 5:
					for xx in 12:
						var cx := 14 + xx * 50 + (25 if yy % 2 else 0)
						var cy := fy + 14 + yy * 32
						if cx < 40 or cx > W - 40 or cy > H - 26:
							continue
						var hex: Array = []
						for kk in 6:
							var a := PI / 6 + TAU * kk / 6.0
							hex.append(Vector2(cx, cy) + Vector2(cos(a) * 22, sin(a) * 14))
						draw_polyline(PackedVector2Array(hex + [hex[0]]), Color("a85e3c"), 2, true)
			_:
				_rect(14, fy, W - 28, fh, Color("c08a58"))
				for i in 9:
					var y := fy + 6 + i * 17
					draw_line(Vector2(14, y), Vector2(W - 14, y), Color("9a6a40"), 2)
					var x0 := fmod(i * 97.0, 160.0)
					var x := 14 + x0
					while x < W - 14:
						draw_line(Vector2(x, y), Vector2(x, y + 17), Color("9a6a40"), 2)
						x += 160
	draw_line(Vector2(14, fy), Vector2(W - 14, fy), Color(0, 0, 0, 0.25), 3)

# --- window on the back wall --------------------------------------------------

func _window(s: int, evening: bool) -> void:
	var r := Rect2(70, 130, 186, 170)
	var trim: Color = TRIMS.get(_c("walls"), TRIMS.cream) if s >= 2 else Color("6d655c")
	_rect(r.position.x - 10, r.position.y - 10, r.size.x + 20, r.size.y + 24, trim, 8)
	var sky := Color("bfe0e8") if not evening else Color("2c3e5a")
	_rect(r.position.x, r.position.y, r.size.x, r.size.y, sky)
	# the street outside
	_rect(r.position.x, r.position.y + 70, 80, 100, Color("d8b89a") if not evening else Color("4a556e"))
	_rect(r.position.x + 90, r.position.y + 40, 120, 130, Color("c9a98a") if not evening else Color("3f4a63"))
	for i in 3:
		_rect(r.position.x + 104 + i * 34, r.position.y + 60, 20, 26, Color("f3e3b5") if evening else Color("8fb7c4"), 3)
	if s >= 8:
		# neighbours peering in for the grand opening
		CharacterArt.draw(self, "n2", Vector2(r.position.x + 50, r.position.y + 140), 70, 1)
		CharacterArt.draw(self, "n1", Vector2(r.position.x + 120, r.position.y + 146), 66, 1)
		CharacterArt.draw(self, "n4", Vector2(r.position.x + 180, r.position.y + 142), 70, 1)
	draw_line(Vector2(r.position.x + r.size.x / 2, r.position.y), Vector2(r.position.x + r.size.x / 2, r.end.y), trim, 6)
	draw_line(Vector2(r.position.x, r.position.y + r.size.y / 2), Vector2(r.end.x, r.position.y + r.size.y / 2), trim, 6)
	if s < 1:
		# boards and grime
		_rect(r.position.x, r.position.y, r.size.x, r.size.y, Color(0.3, 0.27, 0.24, 0.55))
		for j in 3:
			var y := r.position.y + 22 + j * 52
			_poly([Vector2(r.position.x - 10, y), Vector2(r.end.x + 10, y + 14), Vector2(r.end.x + 10, y + 36), Vector2(r.position.x - 10, y + 22)], Color("9a7650"))
			draw_circle(Vector2(r.position.x + 4, y + 12), 3, Color("4a3b2c"))
			draw_circle(Vector2(r.end.x - 4, y + 26), 3, Color("4a3b2c"))
	else:
		draw_line(r.position + Vector2(16, 14), r.position + Vector2(48, 46), Color(1, 1, 1, 0.55), 5, true)
	_rect(r.position.x - 16, r.end.y + 10, r.size.x + 32, 12, trim.darkened(0.15), 4)  # sill
	if s >= 8:
		_rect(r.position.x + 64, r.position.y + 6, 82, 34, Color("2f2a28"), 6)
		draw_string(Style.font_bold, Vector2(r.position.x + 64, r.position.y + 31), Loc.t("open_sign"), HORIZONTAL_ALIGNMENT_CENTER, 82, 20, Color("fffaf2"))

# --- lighting -------------------------------------------------------------------

func _lights(s: int, evening: bool) -> void:
	if s < 5:
		# one bare bulb (flickers while the place is still dusty)
		var on := s >= 1 or fmod(_t, 3.0) > 0.2
		draw_line(Vector2(300, 70), Vector2(300, 112), Color("3b322b"), 2)
		draw_circle(Vector2(300, 120), 9, Color(1, 0.92, 0.6, 1.0 if on else 0.4))
		if on:
			draw_circle(Vector2(300, 120), 26, Color(1, 0.9, 0.55, 0.18))
		return
	var glow := Color(1, 0.86, 0.5, 0.22 if not evening else 0.35)
	match _c("lights"):
		"string":
			for row in 2:
				var pts := PackedVector2Array()
				for i in 25:
					var x := 20 + i * 23.3
					pts.append(Vector2(x, 82 + row * 26 + sin(i / 24.0 * PI * 2) * 10))
				draw_polyline(pts, Color("4a3f36"), 2, true)
				for i in range(0, 25, 2):
					var c := [Color(1, 0.84, 0.45), Color(1, 0.7, 0.5), Color(0.95, 0.9, 0.6)][(i / 2) % 3] as Color
					draw_circle(pts[i] + Vector2(0, 6), 5, c)
					draw_circle(pts[i] + Vector2(0, 6), 11, Color(c, 0.2))
		"globe":
			for x in [120.0, 300.0, 480.0]:
				draw_line(Vector2(x, 70), Vector2(x, 120), Color("b9893f"), 3)
				draw_circle(Vector2(x, 140), 22, Color(1, 0.96, 0.82, 0.95))
				draw_arc(Vector2(x, 140), 22, 0, TAU, 24, Color("b9893f"), 2, true)
				draw_circle(Vector2(x, 140), 44, glow)
		_:
			for x in [120.0, 300.0, 480.0]:
				draw_line(Vector2(x, 70), Vector2(x, 112), Color("2f2a28"), 3)
				_poly([Vector2(x - 26, 140), Vector2(x - 12, 112), Vector2(x + 12, 112), Vector2(x + 26, 140)], Style.TEAL_DARK if not evening else Style.GOLD)
				draw_circle(Vector2(x, 142), 8, Color(1, 0.92, 0.6))
				_poly([Vector2(x - 26, 142), Vector2(x + 26, 142), Vector2(x + 60, 230), Vector2(x - 60, 230)], Color(glow, 0.1))

# --- counter, machine, shelves (Mira) -----------------------------------------

func _shelves_counter(s: int) -> void:
	if s < 4:
		# the old counter under a dust sheet
		_poly([Vector2(340, 300), Vector2(574, 296), Vector2(586, 400), Vector2(334, 404)], Color("b9b2a6") if s >= 1 else Color("958c80"))
		for i in 5:
			draw_line(Vector2(360 + i * 46, 300), Vector2(350 + i * 48, 400), Color(0, 0, 0, 0.1), 3)
		if s < 1:
			for i in 2:
				draw_arc(Vector2(560, 90), 30 + i * 18, PI * 0.5, PI, 10, Color(0.9, 0.9, 0.9, 0.5), 1.5, true)
		return
	# shelves
	for y in [160.0, 220.0]:
		_rect(340, y, 230, 10, Style.WOOD_DARK, 3)
	var items := [Products.TEA, Products.CHOCOLATE, Products.TEA, Products.STRAWBERRY, Products.CHOCOLATE]
	for i in 5:
		ProductArt.draw(self, items[i], Vector2(362 + i * 46, 140), 40)
	for i in 6:
		ProductArt.draw(self, Products.COFFEE, Vector2(358 + i * 38, 202), 32)
	# Mira behind the counter
	CharacterArt.draw(self, "mira", Vector2(470, 278) + _hop(0.0) + _mira_lean(), 110, _cast_mood())
	# counter body
	var front := Color("a8714a")
	var top := Color("d9a87c")
	match _c("counter"):
		"marble":
			front = Color("e7e2da")
			top = Color("f7f4ef")
		"teal":
			front = Style.TEAL
			top = Color("d9a87c")
	_rect(330, 300, 256, 18, top, 6)
	_rect(338, 318, 240, 86, front, 4)
	if _c("counter") == "marble":
		for i in 4:
			draw_line(Vector2(350 + i * 60, 330), Vector2(380 + i * 60, 390), Color(0.6, 0.6, 0.6, 0.35), 2, true)
	else:
		for i in 5:
			draw_line(Vector2(338 + i * 48, 322), Vector2(338 + i * 48, 400), Color(0, 0, 0, 0.12), 3)
	# espresso machine
	_rect(350, 248, 70, 54, Color("9aa4a6"), 8)
	_rect(358, 238, 54, 12, Color("6d7476"), 4)
	draw_circle(Vector2(385, 276), 10, Color("3b2f2a"))
	_rect(374, 292, 22, 8, Color("3b2f2a"), 2)
	ProductArt.draw(self, Products.COFFEE, Vector2(440, 288), 30)
	if not App.reduced_motion():
		for k in 2:
			var ph := fmod(_t * 0.6 + k * 0.5, 1.0)
			draw_circle(Vector2(440 + sin(ph * 6.0 + k) * 4, 268 - ph * 34), 4 + ph * 4, Color(1, 1, 1, 0.5 * (1.0 - ph)))
	# pastry case
	_rect(500, 262, 80, 40, Color(0.85, 0.95, 0.95, 0.6), 6)
	ProductArt.draw(self, Products.CROISSANT, Vector2(522, 286), 26)
	ProductArt.draw(self, Products.CUPCAKE, Vector2(556, 284), 26)

# --- seating (Theo and Basil) -------------------------------------------------

func _seating(s: int) -> void:
	if s < 6:
		if s < 1:
			# a broken chair
			draw_line(Vector2(110, 470), Vector2(140, 420), Color("6b5545"), 6, true)
			_rect(96, 440, 60, 10, Color("6b5545"), 3)
			draw_line(Vector2(150, 450), Vector2(170, 490), Color("6b5545"), 6, true)
		return
	var style := _c("seating")
	var c: Color = {"bistro": Style.WOOD_DARK, "rattan": Color("c9a26b"), "booth": Style.TERRACOTTA, "evening": Color("2b2b2b")}.get(style, Style.WOOD_DARK)
	# characters sit first, then tables in front
	CharacterArt.draw(self, "theo", Vector2(110, 420) + _hop(1.3), 96, _cast_mood())
	CharacterArt.draw(self, "basil", Vector2(262, 424) + _hop(2.1), 96, _cast_mood())
	for tx in [150.0, 230.0]:
		if style == "booth":
			_rect(tx - 120 if tx < 200 else tx + 30, 440, 90, 70, c, 12)
			_rect(tx - 120 if tx < 200 else tx + 30, 430, 90, 22, c.lightened(0.15), 10)
	var tables := [Vector2(150, 470), Vector2(230, 472)]
	if style != "booth":
		for i in 2:
			var tc: Vector2 = tables[i]
			for side in [-1, 1]:
				var cx: float = tc.x + side * 48
				if style == "rattan":
					_rect(cx - 18, tc.y - 14, 36, 44, c, 14)
					for k in 3:
						draw_line(Vector2(cx - 14, tc.y - 6 + k * 10), Vector2(cx + 14, tc.y - 6 + k * 10), Color("a8834e"), 2, true)
				else:
					draw_line(Vector2(cx - 10, tc.y + 40), Vector2(cx - 10, tc.y - 16), c, 4, true)
					draw_line(Vector2(cx + 10, tc.y + 40), Vector2(cx + 10, tc.y + 6), c, 4, true)
					_rect(cx - 14, tc.y + 2, 28, 6, c, 3)
	for tc in tables:
		draw_line(Vector2(tc.x, tc.y), Vector2(tc.x, tc.y + 50), Color("4a4a4a"), 5)
		_rect(tc.x - 36, tc.y + 46, 72, 6, Color("4a4a4a"), 3)
		_rect(tc.x - 40, tc.y - 6, 80, 12, Color("f4efe6") if style != "evening" else Style.GOLD, 6)
	ProductArt.draw(self, Products.COFFEE, Vector2(140, 452), 28)
	ProductArt.draw(self, Products.CROISSANT, Vector2(166, 456), 24)
	ProductArt.draw(self, Products.TEA, Vector2(222, 452), 26)
	# Basil's newspaper
	_rect(244, 446, 34, 22, Color("efe9de"), 2)
	for k in 3:
		draw_line(Vector2(248, 452 + k * 5), Vector2(274, 452 + k * 5), Color(0, 0, 0, 0.25), 1)
	if not App.reduced_motion():
		for k in 2:
			var ph := fmod(_t * 0.5 + k * 0.5, 1.0)
			draw_circle(Vector2(140 + sin(ph * 5.0) * 3, 436 - ph * 26), 3 + ph * 3, Color(1, 1, 1, 0.5 * (1.0 - ph)))

# --- plants ---------------------------------------------------------------------

func _plants(s: int) -> void:
	if s < 7:
		return
	var style := _c("plants")
	for x in [34.0, 540.0]:
		_rect(x, 470, 44, 56, Style.TERRACOTTA, 8)
		_rect(x - 4, 466, 52, 12, Style.TERRACOTTA.darkened(0.15), 4)
		match style:
			"olive":
				draw_line(Vector2(x + 22, 470), Vector2(x + 22, 380), Style.WOOD_DARK, 5)
				draw_circle(Vector2(x + 22, 370), 32, Color("8aa26a"))
				draw_circle(Vector2(x + 6, 384), 20, Color("9db37b"))
				draw_circle(Vector2(x + 38, 382), 20, Color("7d9660"))
			"flowers":
				for i in 6:
					var p := Vector2(x + 4 + i * 7.5, 444 - (i % 2) * 14)
					draw_line(Vector2(x + 22, 470), p, Color("4f8a4f"), 3, true)
					draw_circle(p, 8, [Color("e58fa8"), Color("f0c25a"), Color("ffffff")][i % 3])
			_:
				for i in 9:
					var a := PI + PI * i / 8.0
					var sway := sin(_t * 1.3 + i) * 0.06 if not App.reduced_motion() else 0.0
					draw_line(Vector2(x + 22, 470), Vector2(x + 22, 470) + Vector2(cos(a + sway), sin(a + sway)) * 50, Color("3f8a52"), 7, true)
	# window box under the window
	_rect(62, 312, 198, 18, Style.WOOD, 4)
	for i in 10:
		var p := Vector2(72 + i * 19, 306)
		match style:
			"flowers": draw_circle(p, 7, [Color("e58fa8"), Color("f0c25a"), Color("d6453d")][i % 3])
			"olive": draw_circle(p, 8, Color("8aa26a"))
			_: draw_line(Vector2(p.x, 314), p + Vector2(4, -12), Color("3f8a52"), 5, true)
	# hanging plant
	draw_line(Vector2(560, 70), Vector2(560, 104), Color("6b5545"), 2)
	_rect(544, 104, 32, 22, Style.TERRACOTTA, 6)
	for i in 4:
		draw_line(Vector2(548 + i * 8, 124), Vector2(544 + i * 9, 150 + (i % 2) * 12), Color("3f8a52"), 4, true)

# --- extras ---------------------------------------------------------------------

func _extras_back(s: int) -> void:
	if extras.has("clock"):
		var c := Vector2(300, 190)
		draw_circle(c, 30, Style.WOOD_DARK)
		draw_circle(c, 25, Color("fffaf2"))
		for i in 12:
			var a := TAU * i / 12.0
			draw_line(c + Vector2(cos(a), sin(a)) * 20, c + Vector2(cos(a), sin(a)) * 23, Style.INK, 2)
		var tm := Time.get_time_dict_from_system()
		var ha := TAU * (int(tm.hour) % 12 + int(tm.minute) / 60.0) / 12.0 - PI / 2
		var ma := TAU * int(tm.minute) / 60.0 - PI / 2
		draw_line(c, c + Vector2(cos(ha), sin(ha)) * 12, Style.INK, 3, true)
		draw_line(c, c + Vector2(cos(ma), sin(ma)) * 18, Style.INK, 2, true)
	if extras.has("photos"):
		var who := ["mira", "theo", "basil"]
		for i in 3:
			var frame := Rect2([264.0, 302.0, 283.0][i], [232.0, 232.0, 278.0][i], 34, 38)
			_rect(frame.position.x - 3, frame.position.y - 3, frame.size.x + 6, frame.size.y + 6, Style.GOLD, 3)
			_rect(frame.position.x, frame.position.y, frame.size.x, frame.size.y, Color("efe6d6"))
			CharacterArt.draw(self, who[i], frame.get_center() + Vector2(0, 4), 34, 1)
	if extras.has("cakestand") and s >= 4:
		_rect(518, 252, 44, 6, Color("f4efe6"), 3)
		draw_line(Vector2(540, 258), Vector2(540, 300), Color("c9c1b5"), 3)
		_rect(512, 296, 56, 6, Color("f4efe6"), 3)
		ProductArt.draw(self, Products.CUPCAKE, Vector2(540, 238), 30)

func _extras_front(s: int) -> void:
	if extras.has("gramophone"):
		# on the window sill, horn pointing into the room
		var b := Vector2(214, 302)
		_rect(b.x - 34, b.y - 4, 68, 22, Style.WOOD_DARK, 4)
		_rect(b.x - 26, b.y - 9, 52, 7, Color("3b2f2a"), 3)
		draw_line(b + Vector2(-8, -8), b + Vector2(-18, -34), Color("b9893f"), 4, true)
		_poly([b + Vector2(-16, -34), b + Vector2(-56, -66), b + Vector2(-66, -44), b + Vector2(-22, -28)], Color("d8a640"))
		if not App.reduced_motion():
			var ph := fmod(_t * 0.4, 1.0)
			draw_string(Style.font_bold, b + Vector2(-80 - ph * 20, -70 - ph * 30), "♪", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(Style.INK, 1.0 - ph))
	if extras.has("cat"):
		# Pip the café cat, curled on a cushion; the tail sways.
		var c := Vector2(470, 500)
		_rect(c.x - 46, c.y + 6, 92, 20, Style.TERRA_SOFT, 10)
		draw_colored_polygon(_ell(c, 40, 22), Color("e09a4a"))
		draw_circle(c + Vector2(-30, -10), 18, Color("e09a4a"))
		_poly([c + Vector2(-44, -20), c + Vector2(-40, -38), c + Vector2(-32, -24)], Color("e09a4a"))
		_poly([c + Vector2(-26, -26), c + Vector2(-18, -40), c + Vector2(-14, -22)], Color("e09a4a"))
		draw_arc(c + Vector2(-36, -10), 4, PI * 0.1, PI * 0.9, 6, Style.INK, 2, true)
		draw_arc(c + Vector2(-24, -10), 4, PI * 0.1, PI * 0.9, 6, Style.INK, 2, true)
		for k in 3:
			draw_line(c + Vector2(-8 + k * 14, -18), c + Vector2(-4 + k * 14, -4), Color("c27a34"), 3, true)
		var sw := sin(_t * 2.0) * 0.4 if not App.reduced_motion() else 0.0
		var tail := PackedVector2Array()
		for i in 8:
			var k := i / 7.0
			tail.append(c + Vector2(38 + k * 26, 4 - sin(k * PI) * (14 + sw * 20) - k * 10))
		draw_polyline(tail, Color("e09a4a"), 8, true)

func _ell(c: Vector2, rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(c + Vector2(cos(a) * rx, sin(a) * ry))
	return pts

func _clutter() -> void:
	for b in [Rect2(420, 420, 70, 56), Rect2(470, 440, 60, 50), Rect2(440, 380, 50, 42)]:
		_rect(b.position.x, b.position.y, b.size.x, b.size.y, Color("b08a5a"), 3)
		draw_line(b.position + Vector2(0, b.size.y / 2), b.position + Vector2(b.size.x, b.size.y / 2), Color("8a6a40"), 3)
	for i in 14:
		draw_circle(Vector2(30 + fmod(i * 61.0, 540), 410 + fmod(i * 37.0, 130)), 3, Color(0.25, 0.2, 0.15, 0.3))
	for x in [30.0, 560.0]:
		for i in 3:
			draw_arc(Vector2(x, 76), 18 + i * 14, 0, PI * 0.5 if x < 300 else PI, 10, Color(0.95, 0.95, 0.95, 0.45), 1.5, true)

# --- fascia and sign ------------------------------------------------------------

func _fascia(s: int, evening: bool) -> void:
	var band := Color("5e5246") if s < 2 else TRIMS.get(_c("walls"), TRIMS.cream) as Color
	_rect(0, 0, W, 72, band, 28)
	_rect(0, 40, W, 32, band)
	if s < 8:
		_rect(150, 12, 300, 50, Color("8b7e70") if s < 1 else Color("c9b79e"), 10)
		draw_string(Style.font_bold, Vector2(150, 46), Loc.t("cafe_sign_soon") if s >= 1 else Loc.t("cafe_closed"), HORIZONTAL_ALIGNMENT_CENTER, 300, 24, Color(Style.INK, 0.6))
		return
	var style := _c("sign")
	var bg: Color = {"script": Color("fffaf2"), "block": Style.TEAL, "painted": Style.TERRACOTTA, "gilded": Color("2a2320"), "evening": Color("23303e")}.get(style, Color("fffaf2"))
	var fg: Color = {"script": Style.TEAL_DARK, "block": Color.WHITE, "painted": Color("fffaf2"), "gilded": Style.GOLD, "evening": Style.GOLD}.get(style, Style.TEAL_DARK)
	_rect(110, 8, 380, 58, bg, 16 if style != "block" else 6)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color.TRANSPARENT
	sb.border_color = Style.GOLD if style in ["gilded", "evening"] else Color(Style.INK, 0.4)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(16 if style != "block" else 6)
	draw_style_box(sb, Rect2(110, 8, 380, 58))
	draw_string(Style.font_bold, Vector2(110, 49), Loc.t("cafe_sign"), HORIZONTAL_ALIGNMENT_CENTER, 380, 32, fg)
	if style in ["gilded", "evening"] or evening:
		for i in 14:
			draw_circle(Vector2(122 + i * 26.5, 5), 3, Color(1, 0.86, 0.5, 0.9))

func _bunting() -> void:
	for i in 14:
		var x := 20 + i * 40.0
		var y := 76 + sin(i / 13.0 * PI) * 14
		_poly([Vector2(x, y), Vector2(x + 32, y), Vector2(x + 16, y + 24)], [Style.TERRACOTTA, Style.TEAL, Style.GOLD][i % 3])

# --- v3: door, visitors ----------------------------------------------------------

## Where the current visitor is: {who, x, phase (walk cycle), cup, at_counter}
## or {} when the café is empty. A fixed 14 s timeline per visit.
func _visit_state() -> Dictionary:
	if steps < 4:
		return {}
	var cycle := int(_t / VISIT)
	var k := fmod(_t, VISIT)
	var who := "n%d" % posmod(cycle * 5 + 2, 6)
	if App.reduced_motion():
		return {"who": "n2", "x": QUEUE_X, "phase": 0.0, "cup": false, "at_counter": true}
	if k < 3.0:
		return {"who": who, "x": lerpf(DOOR_X - 20, QUEUE_X, k / 3.0), "phase": k * 7.0, "cup": false, "at_counter": false}
	if k < 5.5:
		return {"who": who, "x": QUEUE_X, "phase": 0.0, "cup": k > 4.6, "at_counter": true}
	if k < 8.5:
		return {"who": who, "x": lerpf(QUEUE_X, DOOR_X - 30, (k - 5.5) / 3.0), "phase": k * 7.0, "cup": true, "at_counter": false}
	return {}

## Mira leans toward the counter while serving.
func _mira_lean() -> Vector2:
	var v := _visit_state()
	if v.is_empty() or not v.at_counter or App.reduced_motion():
		return Vector2.ZERO
	return Vector2(-10, 4)

func _door(s: int) -> void:
	var x := 16.0
	var y := 214.0
	var w := 40.0
	var h := 188.0
	var frame := TRIMS.get(_c("walls"), TRIMS.cream) as Color if s >= 2 else Color("6d655c")
	_rect(x - 4, y - 6, w + 8, h + 6, frame, 4)
	_rect(x, y, w, h, Color("e9e2c8") if s >= 1 else Color("4f463d"))   # street light behind
	var open := 0.0
	var v := _visit_state()
	if not v.is_empty() and not App.reduced_motion():
		open = clampf(1.0 - absf(float(v.x) - DOOR_X) / 70.0, 0.0, 1.0)
	var pw := lerpf(w, 8.0, open)
	_rect(x, y, pw, h, Style.WOOD if s >= 1 else Color("5e5246"), 3)
	if pw > 20:
		_rect(x + 6, y + 14, pw - 12, 60, Color("bfe0dc") if s >= 1 else Color("3b322b"), 3)
		draw_circle(Vector2(x + pw - 8, y + 100), 3, Style.GOLD)

func _visitor(s: int) -> void:
	var v := _visit_state()
	if v.is_empty():
		return
	var spec: Array = CharacterArt.NEIGHBOURS[int(str(v.who).substr(1)) % CharacterArt.NEIGHBOURS.size()]
	var x: float = v.x
	var feet := FEET_Y
	var swing := sin(float(v.phase)) * 7.0
	var trousers := Color("4a4a58")
	draw_line(Vector2(x - 6, feet - 40), Vector2(x - 6 + swing, feet), trousers, 9, true)
	draw_line(Vector2(x + 6, feet - 40), Vector2(x + 6 - swing, feet), trousers, 9, true)
	_rect(x - 18, feet - 78, 36, 44, spec[2], 10)
	CharacterArt.draw(self, str(v.who), Vector2(x, feet - 92), 70, 1 if v.cup else 2)
	if v.cup:
		ProductArt.draw(self, Products.COFFEE, Vector2(x + 20, feet - 52), 24)
	elif v.at_counter:
		# a small speech bubble with what they ordered
		_rect(x + 14, feet - 150, 40, 34, Style.PAPER, 10)
		ProductArt.draw(self, Products.COFFEE, Vector2(x + 34, feet - 133), 24)

## Theo's study-group menu board (special-order reward): on the counter front
## once the counter is restored, otherwise leaning on the wall.
func _chalkboard(s: int) -> void:
	var r := Rect2(362, 330, 104, 62) if s >= 4 else Rect2(266, 330, 62, 72)
	_rect(r.position.x - 4, r.position.y - 4, r.size.x + 8, r.size.y + 8, Style.WOOD_DARK, 4)
	_rect(r.position.x, r.position.y, r.size.x, r.size.y, Color("2f3b34"), 3)
	draw_string(Style.font_bold, Vector2(r.position.x, r.position.y + 18), Loc.t("menu_board"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 14, Color(1, 1, 1, 0.9))
	for i in 3:
		var y := r.position.y + 28 + i * 11
		draw_line(Vector2(r.position.x + 8, y), Vector2(r.position.x + r.size.x * (0.55 + 0.12 * (i % 2)), y), Color(1, 1, 1, 0.55), 2)
		draw_circle(Vector2(r.end.x - 10, y), 2, Color(1, 0.85, 0.5, 0.8))
	if s < 4:
		draw_line(Vector2(r.position.x + 6, r.end.y + 4), Vector2(r.position.x - 4, r.end.y + 14), Style.WOOD_DARK, 4)
		draw_line(Vector2(r.end.x - 6, r.end.y + 4), Vector2(r.end.x + 4, r.end.y + 14), Style.WOOD_DARK, 4)

## Mira's bread basket (bakery special-order reward).
func _breadbasket(s: int) -> void:
	var c := Vector2(478, 292) if s >= 4 else Vector2(112, 300)
	draw_colored_polygon(PackedVector2Array([c + Vector2(-24, -6), c + Vector2(24, -6), c + Vector2(18, 12), c + Vector2(-18, 12)]), Color("c9a26b"))
	for k in 3:
		draw_line(c + Vector2(-22 + k * 2, -2 + k * 5), c + Vector2(22 - k * 2, -2 + k * 5), Color("a8834e"), 2)
	for k in 3:
		var pts := PackedVector2Array()
		for i in 16:
			var t := TAU * i / 16.0
			pts.append(c + Vector2(-12 + k * 12, -12) + Vector2(cos(t) * 10, sin(t) * 6))
		draw_colored_polygon(pts, Color("c8873f"))

## The Midnight Ledger lantern (reward for stamping every expert page).
func _lamp() -> void:
	var c := Vector2(206, 112)
	draw_line(Vector2(c.x, 72), c + Vector2(0, -16), Color("2f2a28"), 2)
	_rect(c.x - 12, c.y - 16, 24, 6, Style.GOLD.darkened(0.2), 2)
	_rect(c.x - 10, c.y - 10, 20, 26, Color("26365a"), 5)
	var glow := 0.75 + (0.15 * sin(_t * 2.2) if not App.reduced_motion() else 0.0)
	draw_circle(c + Vector2(0, 3), 7, Color(1, 0.86, 0.45, glow))
	draw_circle(c + Vector2(3, 0), 6, Color("26365a"))   # crescent moon cut-out
	draw_circle(c + Vector2(0, 3), 22, Color(1, 0.86, 0.45, 0.12))
	_rect(c.x - 12, c.y + 16, 24, 4, Style.GOLD.darkened(0.2), 2)
