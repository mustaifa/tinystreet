class_name CharacterArt
extends RefCounted
## Original vector portraits for the cast and the neighbourhood customers.
## Each character differs in silhouette (hair, hat, glasses, moustache) as
## well as colour, so they stay distinguishable in greyscale.
##
## mood: 0 = neutral, 1 = happy (closed eyes, big smile), 2 = waiting (small mouth)

const OUTLINE := Color("3b2f2a")

## Neighbour customers: [skin, hair, shirt, hair_style]
const NEIGHBOURS := [
	[Color("e8b98f"), Color("2f2a28"), Color("4f7fb3"), "short"],
	[Color("a86b45"), Color("1e1a18"), Color("e0a93b"), "curly"],
	[Color("f3cfb0"), Color("c9893f"), Color("8a6bb0"), "long"],
	[Color("7a4a2f"), Color("1e1a18"), Color("6fb8ae"), "bun"],
	[Color("d9a27a"), Color("7a4a2a"), Color("b45a7a"), "bob"],
	[Color("f0c8a8"), Color("b9b2a8"), Color("5f8a5a"), "short"],
]

const MOODS := ["neutral", "happy", "waiting"]

static func draw(ci: CanvasItem, who: String, c: Vector2, s: float, mood: int = 0, a: float = 1.0) -> void:
	# Skin art: "character.<who>.<mood>" first, then "character.<who>".
	var m: String = MOODS[clampi(mood, 0, 2)]
	if ArtSkin.draw_fit(ci, "character.%s.%s" % [who, m], c, s, a) or ArtSkin.draw_fit(ci, "character." + who, c, s, a):
		return
	match who:
		"mira": _mira(ci, c, s, mood, a)
		"theo": _theo(ci, c, s, mood, a)
		"basil": _basil(ci, c, s, mood, a)
		_:
			var i := 0
			if who.begins_with("n"):
				i = posmod(int(who.substr(1)), NEIGHBOURS.size())
			_neighbour(ci, c, s, mood, a, NEIGHBOURS[i])

static func _k(col: Color, a: float) -> Color:
	return Color(col, col.a * a)

static func _ell(c: Vector2, rx: float, ry: float, n: int = 24) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var t := TAU * i / n
		pts.append(c + Vector2(cos(t) * rx, sin(t) * ry))
	return pts

static func _fill(ci: CanvasItem, pts: PackedVector2Array, col: Color, a: float, lw: float) -> void:
	ci.draw_colored_polygon(pts, _k(col, a))
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, _k(OUTLINE, 0.8 * a), lw, true)

static func _body(ci: CanvasItem, c: Vector2, s: float, col: Color, a: float) -> void:
	var lw := maxf(1.2, s * 0.025)
	var pts := PackedVector2Array()
	for i in 13:
		var t := PI + PI * i / 12.0
		pts.append(c + Vector2(cos(t) * 0.36, 0.48 + sin(t) * 0.26) * s)
	pts.append(c + Vector2(0.36, 0.5) * s)
	pts.append(c + Vector2(-0.36, 0.5) * s)
	_fill(ci, pts, col, a, lw)

static func _head(ci: CanvasItem, c: Vector2, s: float, skin: Color, a: float) -> void:
	_fill(ci, _ell(c + Vector2(0, -0.06) * s, 0.2 * s, 0.22 * s), skin, a, maxf(1.2, s * 0.025))

static func _face(ci: CanvasItem, c: Vector2, s: float, mood: int, a: float, blush: bool = true) -> void:
	var ink := _k(OUTLINE, a)
	var ey := c + Vector2(0, -0.08) * s
	var lw := maxf(1.5, s * 0.03)
	for side in [-1, 1]:
		var e: Vector2 = ey + Vector2(side * 0.075, 0) * s
		if mood == 1:
			ci.draw_arc(e + Vector2(0, 0.015) * s, 0.03 * s, PI * 1.1, PI * 1.9, 8, ink, lw, true)
		else:
			ci.draw_circle(e, 0.022 * s, ink)
	if blush:
		for side in [-1, 1]:
			ci.draw_circle(c + Vector2(side * 0.12, -0.0) * s, 0.03 * s, Color(0.9, 0.45, 0.45, 0.35 * a))
	var m := c + Vector2(0, 0.03) * s
	match mood:
		1:
			ci.draw_arc(m - Vector2(0, 0.02) * s, 0.06 * s, PI * 0.15, PI * 0.85, 10, ink, lw, true)
		2:
			ci.draw_line(m + Vector2(-0.03, 0) * s, m + Vector2(0.03, 0) * s, ink, lw, true)
		_:
			ci.draw_arc(m - Vector2(0, 0.025) * s, 0.04 * s, PI * 0.2, PI * 0.8, 8, ink, lw, true)

# Mira: the baker next door. Dark hair in a high bun, terracotta headscarf, apron.
static func _mira(ci: CanvasItem, c: Vector2, s: float, mood: int, a: float) -> void:
	var lw := maxf(1.2, s * 0.025)
	_body(ci, c, s, Color("c8643f"), a)
	_fill(ci, PackedVector2Array([c + Vector2(-0.16, 0.3) * s, c + Vector2(0.16, 0.3) * s,
		c + Vector2(0.2, 0.5) * s, c + Vector2(-0.2, 0.5) * s]), Color("fffaf2"), a, lw)
	_fill(ci, _ell(c + Vector2(0, -0.34) * s, 0.11 * s, 0.09 * s), Color("2a1d18"), a, lw)
	_fill(ci, _ell(c + Vector2(0, -0.12) * s, 0.23 * s, 0.2 * s), Color("2a1d18"), a, lw)
	_head(ci, c, s, Color("c68a5e"), a)
	ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.22, -0.2) * s, c + Vector2(0.22, -0.2) * s,
		c + Vector2(0.2, -0.26) * s, c + Vector2(-0.2, -0.26) * s]), _k(Color("e0a93b"), a))
	_face(ci, c, s, mood, a)

# Theo: student. Messy spiky hair, round glasses, teal hoodie.
static func _theo(ci: CanvasItem, c: Vector2, s: float, mood: int, a: float) -> void:
	var lw := maxf(1.2, s * 0.025)
	_body(ci, c, s, Color("1f7a72"), a)
	ci.draw_arc(c + Vector2(0, 0.28) * s, 0.12 * s, 0, PI, 12, _k(Color("165a54"), a), lw * 2.5, true)
	_head(ci, c, s, Color("f1c7a5"), a)
	var hair := PackedVector2Array()
	for i in 9:
		var t := PI + PI * i / 8.0
		var r := 0.24 if i % 2 == 0 else 0.3
		hair.append(c + Vector2(cos(t) * 0.22, -0.12 + sin(t) * r) * s)
	_fill(ci, hair, Color("6b4029"), a, lw)
	_face(ci, c, s, mood, a, false)
	for side in [-1, 1]:
		ci.draw_arc(c + Vector2(side * 0.075, -0.08) * s, 0.05 * s, 0, TAU, 16, _k(OUTLINE, a), lw, true)
	ci.draw_line(c + Vector2(-0.025, -0.08) * s, c + Vector2(0.025, -0.08) * s, _k(OUTLINE, a), lw, true)

# Mr. Basil: retired postman. Flat cap, white moustache, olive jacket, bow tie.
static func _basil(ci: CanvasItem, c: Vector2, s: float, mood: int, a: float) -> void:
	var lw := maxf(1.2, s * 0.025)
	_body(ci, c, s, Color("6f7a4a"), a)
	_fill(ci, PackedVector2Array([c + Vector2(-0.07, 0.25) * s, c + Vector2(0, 0.28) * s, c + Vector2(-0.07, 0.31) * s]), Color("c8643f"), a, lw * 0.6)
	_fill(ci, PackedVector2Array([c + Vector2(0.07, 0.25) * s, c + Vector2(0, 0.28) * s, c + Vector2(0.07, 0.31) * s]), Color("c8643f"), a, lw * 0.6)
	_head(ci, c, s, Color("e0b088"), a)
	for side in [-1, 1]:
		_fill(ci, _ell(c + Vector2(side * 0.19, -0.06) * s, 0.045 * s, 0.07 * s), Color("ece6dc"), a, lw * 0.6)
	_fill(ci, PackedVector2Array([c + Vector2(-0.24, -0.17) * s, c + Vector2(0.26, -0.17) * s, c + Vector2(0.3, -0.13) * s,
		c + Vector2(0.18, -0.12) * s, c + Vector2(-0.22, -0.13) * s]), Color("7c5034"), a, lw)
	_fill(ci, _ell(c + Vector2(0, -0.22) * s, 0.21 * s, 0.08 * s), Color("8a6142"), a, lw)
	_face(ci, c, s, mood, a)
	_fill(ci, PackedVector2Array([c + Vector2(-0.11, 0.0) * s, c + Vector2(0, -0.02) * s, c + Vector2(0.11, 0.0) * s,
		c + Vector2(0.06, 0.03) * s, c + Vector2(0, 0.01) * s, c + Vector2(-0.06, 0.03) * s]), Color("ece6dc"), a, lw * 0.6)

static func _neighbour(ci: CanvasItem, c: Vector2, s: float, mood: int, a: float, spec: Array) -> void:
	var lw := maxf(1.2, s * 0.025)
	var skin: Color = spec[0]
	var hair: Color = spec[1]
	_body(ci, c, s, spec[2], a)
	match String(spec[3]):
		"long":
			_fill(ci, PackedVector2Array([c + Vector2(-0.23, -0.14) * s, c + Vector2(0.23, -0.14) * s,
				c + Vector2(0.25, 0.22) * s, c + Vector2(-0.25, 0.22) * s]), hair, a, lw)
		"bun":
			_fill(ci, _ell(c + Vector2(0, -0.33) * s, 0.09 * s, 0.08 * s), hair, a, lw)
		"bob":
			_fill(ci, _ell(c + Vector2(0, -0.08) * s, 0.25 * s, 0.24 * s), hair, a, lw)
	_head(ci, c, s, skin, a)
	match String(spec[3]):
		"curly":
			for i in 7:
				var t := PI + PI * i / 6.0
				ci.draw_circle(c + Vector2(cos(t) * 0.2, -0.13 + sin(t) * 0.17) * s, 0.07 * s, _k(hair, a))
		"bob", "long":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.21, -0.1) * s, c + Vector2(-0.12, -0.27) * s,
				c + Vector2(0.14, -0.27) * s, c + Vector2(0.21, -0.1) * s, c + Vector2(0.05, -0.18) * s]), _k(hair, a))
		_:
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.21, -0.1) * s, c + Vector2(-0.16, -0.26) * s,
				c + Vector2(0.16, -0.26) * s, c + Vector2(0.21, -0.1) * s, c + Vector2(0.0, -0.2) * s]), _k(hair, a))
	_face(ci, c, s, mood, a)
