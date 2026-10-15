class_name ProductArt
extends RefCounted
## Original vector product illustrations drawn with CanvasItem primitives.
## Each product has a unique SILHOUETTE (cup, tin, crescent, cupcake, basket,
## gift box) so colour is never the only distinguishing cue.

const OUTLINE := Color("3b2f2a")

## Textures rendered once at boot (see bake()). Drawing a cached texture is far
## cheaper than re-triangulating the vector polygons every frame.
static var cache := {}
const BAKE_PX := 192

static func draw(ci: CanvasItem, p: int, c: Vector2, s: float, a: float = 1.0) -> void:
	var tex: Texture2D = cache.get(p)
	if tex:
		ci.draw_texture_rect(tex, Rect2(c - Vector2(s, s) / 2, Vector2(s, s)), false, Color(1, 1, 1, a))
		return
	draw_vector(ci, p, c, s, a)

static func draw_vector(ci: CanvasItem, p: int, c: Vector2, s: float, a: float = 1.0) -> void:
	match p:
		Products.COFFEE: _coffee(ci, c, s, a)
		Products.TEA: _tea(ci, c, s, a)
		Products.CROISSANT: _croissant(ci, c, s, a)
		Products.CUPCAKE: _cupcake(ci, c, s, a)
		Products.STRAWBERRY: _strawberry(ci, c, s, a)
		Products.CHOCOLATE: _chocolate(ci, c, s, a)

static func _col(hex: String, a: float) -> Color:
	var k := Color(hex)
	k.a *= a
	return k

static func _poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, line_w: float, a: float) -> void:
	ci.draw_colored_polygon(pts, fill)
	if line_w > 0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, Color(OUTLINE, 0.85 * a), line_w, true)

static func _pts(c: Vector2, s: float, arr: Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	for v in arr:
		out.append(c + Vector2(v[0], v[1]) * s)
	return out

static func _shadow(ci: CanvasItem, c: Vector2, s: float, a: float) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var ang := TAU * i / 24.0
		pts.append(c + Vector2(cos(ang) * 0.36, 0.42 + sin(ang) * 0.06) * s)
	ci.draw_colored_polygon(pts, Color(0.2, 0.12, 0.08, 0.16 * a))

static func _ellipse(c: Vector2, rx: float, ry: float, n: int = 28) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var ang := TAU * i / n
		pts.append(c + Vector2(cos(ang) * rx, sin(ang) * ry))
	return pts

# ---- coffee: white cup, brown band, handle, saucer, steam -------------------
static func _coffee(ci: CanvasItem, c: Vector2, s: float, a: float) -> void:
	var lw := maxf(1.5, s * 0.03)
	_shadow(ci, c, s, a)
	_poly(ci, _ellipse(c + Vector2(0, 0.34) * s, 0.4 * s, 0.08 * s), _col("efe4d6", a), lw, a)
	# handle
	ci.draw_arc(c + Vector2(0.27, 0.06) * s, 0.12 * s, -PI * 0.5, PI * 0.5, 16, _col("3b2f2a", 0.85 * a), lw * 2.6, true)
	ci.draw_arc(c + Vector2(0.27, 0.06) * s, 0.12 * s, -PI * 0.5, PI * 0.5, 16, _col("fffaf2", a), lw * 1.2, true)
	var cup := _pts(c, s, [[-0.3, -0.12], [0.3, -0.12], [0.24, 0.3], [-0.24, 0.3]])
	_poly(ci, cup, _col("fffaf2", a), lw, a)
	_poly(ci, _pts(c, s, [[-0.285, -0.02], [0.285, -0.02], [0.27, 0.08], [-0.27, 0.08]]), _col("8a5a3c", a), 0, a)
	_poly(ci, _ellipse(c + Vector2(0, -0.12) * s, 0.3 * s, 0.065 * s), _col("6b4029", a), lw, a)
	for i in 2:
		var x := (-0.08 + i * 0.16) * s
		var pts := PackedVector2Array()
		for k in 7:
			var t := k / 6.0
			pts.append(c + Vector2(x + sin(t * PI * 2.0) * 0.035 * s, (-0.2 - t * 0.22) * s))
		ci.draw_polyline(pts, _col("8a5a3c", 0.55 * a), lw * 1.2, true)

# ---- tea: teal tin cylinder with lid and leaf emblem ------------------------
static func _tea(ci: CanvasItem, c: Vector2, s: float, a: float) -> void:
	var lw := maxf(1.5, s * 0.03)
	_shadow(ci, c, s, a)
	var body := _pts(c, s, [[-0.26, -0.24], [0.26, -0.24], [0.26, 0.36], [-0.26, 0.36]])
	_poly(ci, body, _col("2f8f83", a), lw, a)
	_poly(ci, _pts(c, s, [[-0.26, 0.24], [0.26, 0.24], [0.26, 0.36], [-0.26, 0.36]]), _col("23695f", a), 0, a)
	# lid
	_poly(ci, _pts(c, s, [[-0.29, -0.36], [0.29, -0.36], [0.29, -0.22], [-0.29, -0.22]]), _col("e0a93b", a), lw, a)
	# label + leaf
	_poly(ci, _ellipse(c + Vector2(0, 0.05) * s, 0.17 * s, 0.15 * s), _col("fbf4e8", a), lw * 0.8, a)
	var leaf := PackedVector2Array()
	for i in 20:
		var t := i / 19.0
		leaf.append(c + Vector2(lerpf(-0.09, 0.09, t), 0.05 - sin(t * PI) * 0.07) * s)
	for i in 20:
		var t := 1.0 - i / 19.0
		leaf.append(c + Vector2(lerpf(-0.09, 0.09, t), 0.05 + sin(t * PI) * 0.07) * s)
	ci.draw_colored_polygon(leaf, _col("3f9a4a", a))
	ci.draw_line(c + Vector2(-0.09, 0.05) * s, c + Vector2(0.09, 0.05) * s, _col("2a6b33", a), lw * 0.7, true)

# ---- croissant: segmented golden crescent -----------------------------------
static func _croissant(ci: CanvasItem, c: Vector2, s: float, a: float) -> void:
	var lw := maxf(1.5, s * 0.03)
	_shadow(ci, c, s, a)
	var segs := 5
	for i in segs:
		var t := (i + 0.5) / segs
		var ang := lerpf(PI * 1.12, PI * 1.88, t)
		var pos := c + Vector2(cos(ang) * 0.3, 0.26 + sin(ang) * 0.38) * s
		var r := (0.11 + 0.07 * sin(t * PI)) * s
		var e := _ellipse(pos, r, r * 1.05, 20)
		_poly(ci, e, _col("d9a441", a) if i % 2 == 0 else _col("e7b95a", a), lw, a)
	for i in segs - 1:
		var t := (i + 1.0) / segs
		var ang := lerpf(PI * 1.12, PI * 1.88, t)
		var pos := c + Vector2(cos(ang) * 0.3, 0.26 + sin(ang) * 0.38) * s
		ci.draw_line(pos + Vector2(0, -0.08) * s, pos + Vector2(0, 0.08) * s, _col("a8712e", 0.8 * a), lw, true)

# ---- cupcake: pleated wrapper, swirl frosting, cherry -----------------------
static func _cupcake(ci: CanvasItem, c: Vector2, s: float, a: float) -> void:
	var lw := maxf(1.5, s * 0.03)
	_shadow(ci, c, s, a)
	var wrap := _pts(c, s, [[-0.28, 0.0], [0.28, 0.0], [0.2, 0.36], [-0.2, 0.36]])
	_poly(ci, wrap, _col("6fb8ae", a), lw, a)
	for i in 5:
		var x := -0.18 + i * 0.09
		ci.draw_line(c + Vector2(x * 1.4, 0.02) * s, c + Vector2(x, 0.34) * s, _col("3d8a80", a), lw * 0.8, true)
	_poly(ci, _ellipse(c + Vector2(0, -0.02) * s, 0.32 * s, 0.11 * s), _col("e58fa8", a), lw, a)
	_poly(ci, _ellipse(c + Vector2(0, -0.13) * s, 0.24 * s, 0.1 * s), _col("ee9fb6", a), lw, a)
	_poly(ci, _ellipse(c + Vector2(0, -0.23) * s, 0.15 * s, 0.08 * s), _col("f5b3c6", a), lw, a)
	_poly(ci, _ellipse(c + Vector2(0, -0.33) * s, 0.07 * s, 0.07 * s, 16), _col("c0303a", a), lw, a)

# ---- strawberry carton: woven basket with berries ---------------------------
static func _strawberry(ci: CanvasItem, c: Vector2, s: float, a: float) -> void:
	var lw := maxf(1.5, s * 0.03)
	_shadow(ci, c, s, a)
	for i in 3:
		var bx := (-0.18 + i * 0.18) * s
		var by := (-0.06 - (0.06 if i == 1 else 0.0)) * s
		var berry := PackedVector2Array()
		for k in 24:
			var t := TAU * k / 24.0
			var r := 0.12 * (1.0 - 0.25 * maxf(0.0, sin(t)))
			berry.append(c + Vector2(bx, by) + Vector2(cos(t) * r, -sin(t) * r * 1.15 + 0.01) * s)
		_poly(ci, berry, _col("d6453d", a), lw, a)
		for d in 3:
			ci.draw_circle(c + Vector2(bx, by) + Vector2((-0.04 + d * 0.04), 0.01 + (d % 2) * 0.03) * s, s * 0.012, _col("ffe08a", a))
		_poly(ci, _pts(c + Vector2(bx, by), s, [[-0.06, -0.12], [0.0, -0.08], [0.06, -0.12], [0.02, -0.15], [-0.02, -0.15]]), _col("3f9a4a", a), 0, a)
	var box := _pts(c, s, [[-0.36, 0.02], [0.36, 0.02], [0.3, 0.36], [-0.3, 0.36]])
	_poly(ci, box, _col("f2e2c4", a), lw, a)
	for i in 3:
		var y := 0.1 + i * 0.09
		ci.draw_line(c + Vector2(-0.34 + i * 0.015, y) * s, c + Vector2(0.34 - i * 0.015, y) * s, _col("c9a77a", a), lw * 0.8, true)
	_poly(ci, _pts(c, s, [[-0.12, 0.12], [0.12, 0.12], [0.12, 0.26], [-0.12, 0.26]]), _col("d6453d", a), 0, a)

# ---- chocolate: square gift box, gold ribbon and bow ------------------------
static func _chocolate(ci: CanvasItem, c: Vector2, s: float, a: float) -> void:
	var lw := maxf(1.5, s * 0.03)
	_shadow(ci, c, s, a)
	var box := _pts(c, s, [[-0.32, -0.18], [0.32, -0.18], [0.32, 0.36], [-0.32, 0.36]])
	_poly(ci, box, _col("5b3a2e", a), lw, a)
	_poly(ci, _pts(c, s, [[-0.35, -0.26], [0.35, -0.26], [0.35, -0.14], [-0.35, -0.14]]), _col("70483a", a), lw, a)
	_poly(ci, _pts(c, s, [[-0.05, -0.26], [0.05, -0.26], [0.05, 0.36], [-0.05, 0.36]]), _col("e0a93b", a), 0, a)
	_poly(ci, _pts(c, s, [[-0.32, 0.06], [0.32, 0.06], [0.32, 0.14], [-0.32, 0.14]]), _col("e0a93b", a), 0, a)
	_poly(ci, _pts(c, s, [[0.0, -0.27], [-0.16, -0.38], [-0.17, -0.25]]), _col("f0c25a", a), lw * 0.8, a)
	_poly(ci, _pts(c, s, [[0.0, -0.27], [0.16, -0.38], [0.17, -0.25]]), _col("f0c25a", a), lw * 0.8, a)
	ci.draw_circle(c + Vector2(0, -0.27) * s, s * 0.04, _col("c88f22", a))

## Renders every product into a texture using an offscreen viewport.
static func bake(host: Node) -> void:
	if not cache.is_empty() or DisplayServer.get_name() == "headless":
		return
	for p in Products.COUNT:
		var vp := SubViewport.new()
		vp.size = Vector2i(BAKE_PX, BAKE_PX)
		vp.transparent_bg = true
		vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var art := _Baker.new()
		art.product = p
		art.size = Vector2(BAKE_PX, BAKE_PX)
		vp.add_child(art)
		host.add_child(vp)
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.generate_mipmaps()
		cache[p] = ImageTexture.create_from_image(img)
		vp.queue_free()

class _Baker extends Control:
	var product := 0
	func _draw() -> void:
		ProductArt.draw_vector(self, product, size / 2, size.x)
