class_name Glyph
extends Control
## The game's icon set, drawn as vectors (no icon font, no emoji). One style
## throughout: rounded line icons with a stroke of ~7.5% of the icon size,
## filled shapes only for solid objects (coin, star, bell, lock body).
## Directional glyphs (back, next, undo, redo, chevron) mirror in RTL.
## `Glyph.paint()` draws any icon into any CanvasItem (medallions, cells).

var kind := "back"
var color := Color.WHITE
var thickness := 0.0

func _ready() -> void:
	resized.connect(queue_redraw)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Icons on buttons dim with the button (the button redraws when disabled).
	var p := get_parent()
	if p is BaseButton:
		p.draw.connect(queue_redraw)

func _draw() -> void:
	var col := color
	var p := get_parent()
	if p is BaseButton and (p as BaseButton).disabled:
		col = Color(col, col.a * 0.38)
	paint(self, kind, Rect2(Vector2.ZERO, size), col, thickness)

static func paint(ci: CanvasItem, kind: String, rect: Rect2, color: Color, thickness: float = 0.0) -> void:
	var s := minf(rect.size.x, rect.size.y)
	var c := rect.get_center()
	var w := thickness if thickness > 0 else maxf(2.5, s * 0.075)
	var r := s * 0.26
	var flip := -1.0 if (Loc.is_rtl() and kind in ["back", "undo", "next", "redo", "chevron"]) else 1.0
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x * flip, y) * s
	var line := func(a: Vector2, b: Vector2, k: float = 1.0) -> void:
		ci.draw_line(c + a * s, c + b * s, color, w * k, true)
		ci.draw_circle(c + a * s, w * k * 0.5, color)
		ci.draw_circle(c + b * s, w * k * 0.5, color)
	# Skin icons: "icon.<kind>" (mark white line icons "tint": true in the manifest).
	# Directional ones mirror in RTL like the built-in glyphs.
	if ArtSkin.has("icon." + kind):
		if flip < 0:
			ci.draw_set_transform(c, 0.0, Vector2(-1, 1))
			ArtSkin.draw_fit(ci, "icon." + kind, Vector2.ZERO, s, 1.0, color)
			ci.draw_set_transform(Vector2.ZERO)
		else:
			ArtSkin.draw_fit(ci, "icon." + kind, c, s, 1.0, color)
		return
	if kind.begins_with("p_"):
		# the game's own full-colour product art, e.g. "p_croissant"
		ProductArt.draw(ci, Products.IDS.find(kind.substr(2)), c, s * 0.82, color.a)
		return
	match kind:
		"arrow_up", "arrow_right", "arrow_down", "arrow_left":
			# Board directions: spatial, so never mirrored in RTL.
			var ang: float = {"arrow_up": -PI / 2, "arrow_right": 0.0, "arrow_down": PI / 2, "arrow_left": PI}[kind]
			var fw := Vector2(cos(ang), sin(ang))
			var sd := Vector2(-fw.y, fw.x)
			var tip := c + fw * s * 0.24
			ci.draw_line(c - fw * s * 0.22, c + fw * s * 0.08, color, w * 1.25, true)
			ci.draw_colored_polygon(PackedVector2Array([tip, tip - fw * s * 0.24 + sd * s * 0.2, tip - fw * s * 0.24 - sd * s * 0.2]), color)
		"back", "chevron_back":
			ci.draw_polyline(PackedVector2Array([P.call(0.08, -0.2), P.call(-0.12, 0.0), P.call(0.08, 0.2)]), color, w * 1.15, true)
		"next", "chevron":
			ci.draw_polyline(PackedVector2Array([P.call(-0.08, -0.2), P.call(0.12, 0.0), P.call(-0.08, 0.2)]), color, w * 1.15, true)
		"undo", "redo":
			# Arc over the top, arrowhead pointing down at the start side.
			var f := 1.0 if kind == "undo" else -1.0
			var arc := PackedVector2Array()
			for i in 17:
				var a := lerpf(0.35 * PI, -PI, i / 16.0)
				arc.append(P.call(cos(a) * 0.19 * f, sin(a) * 0.19 + 0.05))
			ci.draw_polyline(arc, color, w, true)
			var tip: Vector2 = P.call(-0.19 * f, 0.05)
			ci.draw_colored_polygon(PackedVector2Array([tip + Vector2(-0.1, -0.02) * s, tip + Vector2(0.1, -0.02) * s, tip + Vector2(0, 0.12) * s]), color)
		"restart":
			ci.draw_arc(c, r, -PI * 0.3, PI * 1.45, 24, color, w, true)
			var t2 := c + Vector2(cos(-PI * 0.3), sin(-PI * 0.3)) * r
			ci.draw_colored_polygon(PackedVector2Array([t2 + Vector2(-0.12, -0.04) * s, t2 + Vector2(0.06, -0.12) * s, t2 + Vector2(0.05, 0.08) * s]), color)
		"hint":
			var bc := c + Vector2(0, -0.07) * s
			ci.draw_arc(bc, r * 0.72, PI * 0.72, PI * 2.28, 24, color, w, true)
			line.call(Vector2(-0.075, 0.1), Vector2(-0.075, 0.15))
			line.call(Vector2(0.075, 0.1), Vector2(0.075, 0.15))
			line.call(Vector2(-0.085, 0.16), Vector2(0.085, 0.16))
			line.call(Vector2(-0.05, 0.23), Vector2(0.05, 0.23))
			for a in [-PI * 0.5, -PI * 0.15, -PI * 0.85]:
				var d := Vector2(cos(a), sin(a))
				ci.draw_line(bc + d * r * 1.0, bc + d * r * 1.3, color, w * 0.8, true)
		"pause":
			line.call(Vector2(-0.09, -0.16), Vector2(-0.09, 0.16), 1.3)
			line.call(Vector2(0.09, -0.16), Vector2(0.09, 0.16), 1.3)
		"gear":
			ci.draw_arc(c, r * 0.5, 0, TAU, 20, color, w, true)
			var pts := PackedVector2Array()
			for i in 48:
				var a := TAU * i / 48.0
				var tooth := 1.0 if (i % 6) < 3 else 0.78
				pts.append(c + Vector2(cos(a), sin(a)) * r * 1.12 * tooth)
			pts.append(pts[0])
			ci.draw_polyline(pts, color, w * 0.9, true)
		"help":
			ci.draw_arc(c + Vector2(0, -0.08) * s, r * 0.6, PI, PI * 2.4, 16, color, w, true)
			line.call(Vector2(0.06, 0.0), Vector2(0.0, 0.07))
			ci.draw_circle(c + Vector2(0, 0.2) * s, w * 0.8, color)
		"info":
			ci.draw_arc(c, r * 1.1, 0, TAU, 28, color, w, true)
			line.call(Vector2(0, -0.02), Vector2(0, 0.14))
			ci.draw_circle(c + Vector2(0, -0.12) * s, w * 0.75, color)
		"star", "star_empty":
			var pts2 := PackedVector2Array()
			for i in 10:
				var a := -PI / 2 + TAU * i / 10.0
				var rr := r * (1.3 if i % 2 == 0 else 0.58)
				pts2.append(c + Vector2(cos(a), sin(a)) * rr + Vector2(0, s * 0.02))
			if kind == "star":
				ci.draw_colored_polygon(pts2, color)
				var hl := pts2.duplicate()
				for i in hl.size():
					hl[i] = c + (hl[i] - c) * 0.55 + Vector2(-s * 0.03, -s * 0.03)
				ci.draw_colored_polygon(hl, Color(1, 1, 1, 0.22))
			else:
				pts2.append(pts2[0])
				ci.draw_polyline(pts2, color, w * 0.8, true)
		"lock":
			ci.draw_arc(c + Vector2(0, -0.06) * s, r * 0.55, PI, TAU, 16, color, w, true)
			line.call(Vector2(-0.143, -0.06), Vector2(-0.143, -0.02))
			line.call(Vector2(0.143, -0.06), Vector2(0.143, -0.02))
			var body := StyleBoxFlat.new()
			body.bg_color = color
			body.set_corner_radius_all(int(s * 0.05))
			ci.draw_style_box(body, Rect2(c + Vector2(-0.2, -0.04) * s, Vector2(0.4, 0.3) * s))
		"check":
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.18, 0.0) * s, c + Vector2(-0.05, 0.13) * s, c + Vector2(0.2, -0.14) * s]), color, w * 1.35, true)
		"close":
			line.call(Vector2(-0.14, -0.14), Vector2(0.14, 0.14), 1.2)
			line.call(Vector2(0.14, -0.14), Vector2(-0.14, 0.14), 1.2)
		"plus":
			line.call(Vector2(-0.17, 0), Vector2(0.17, 0), 1.2)
			line.call(Vector2(0, -0.17), Vector2(0, 0.17), 1.2)
		"play":
			ci.draw_colored_polygon(PackedVector2Array([P.call(-0.12, -0.2), P.call(0.18, 0.0), P.call(-0.12, 0.2)]), color)
		"share":
			for p in [Vector2(0.15, -0.17), Vector2(-0.15, 0.0), Vector2(0.15, 0.17)]:
				ci.draw_circle(c + p * s, s * 0.06, color)
			ci.draw_line(c + Vector2(0.15, -0.17) * s, c + Vector2(-0.15, 0.0) * s, color, w * 0.8, true)
			ci.draw_line(c + Vector2(0.15, 0.17) * s, c + Vector2(-0.15, 0.0) * s, color, w * 0.8, true)
		"coin":
			# restoration token: a round coin with a small cup stamped on it
			ci.draw_circle(c + Vector2(0, s * 0.02), r * 1.3, color.darkened(0.3))
			ci.draw_circle(c, r * 1.3, color)
			ci.draw_arc(c, r * 1.02, 0, TAU, 28, color.darkened(0.22), w * 0.5, true)
			var cup := PackedVector2Array([c + Vector2(-0.11, -0.05) * s, c + Vector2(0.11, -0.05) * s,
				c + Vector2(0.08, 0.11) * s, c + Vector2(-0.08, 0.11) * s])
			ci.draw_colored_polygon(cup, color.darkened(0.38))
			ci.draw_arc(c + Vector2(0.12, 0.02) * s, 0.045 * s, -PI * 0.5, PI * 0.5, 8, color.darkened(0.38), w * 0.5, true)
			ci.draw_arc(c + Vector2(-0.05, -0.05) * s, r * 0.9, PI * 1.05, PI * 1.45, 8, Color(1, 1, 1, 0.45), w * 0.5, true)
		"book", "journal":
			var pts3 := PackedVector2Array([c + Vector2(0, -0.13) * s, c + Vector2(-0.24, -0.19) * s, c + Vector2(-0.24, 0.17) * s, c + Vector2(0, 0.22) * s,
				c + Vector2(0.24, 0.17) * s, c + Vector2(0.24, -0.19) * s, c + Vector2(0, -0.13) * s])
			ci.draw_polyline(pts3, color, w * 0.9, true)
			line.call(Vector2(0, -0.13), Vector2(0, 0.22), 0.8)
			for i in 2:
				line.call(Vector2(-0.17, -0.07 + i * 0.09), Vector2(-0.07, -0.05 + i * 0.09), 0.6)
				line.call(Vector2(0.07, -0.05 + i * 0.09), Vector2(0.17, -0.07 + i * 0.09), 0.6)
		"trophy":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.16, -0.2) * s, c + Vector2(0.16, -0.2) * s,
				c + Vector2(0.12, 0.0) * s, c + Vector2(0.0, 0.06) * s, c + Vector2(-0.12, 0.0) * s]), color)
			ci.draw_arc(c + Vector2(-0.16, -0.1) * s, 0.07 * s, PI * 0.5, PI * 1.5, 8, color, w * 0.7, true)
			ci.draw_arc(c + Vector2(0.16, -0.1) * s, 0.07 * s, -PI * 0.5, PI * 0.5, 8, color, w * 0.7, true)
			line.call(Vector2(0, 0.05), Vector2(0, 0.14))
			var base := StyleBoxFlat.new()
			base.bg_color = color
			base.set_corner_radius_all(int(s * 0.03))
			ci.draw_style_box(base, Rect2(c + Vector2(-0.13, 0.14) * s, Vector2(0.26, 0.08) * s))
		"timer":
			ci.draw_arc(c + Vector2(0, 0.03) * s, r, 0, TAU, 24, color, w, true)
			line.call(Vector2(0, 0.03), Vector2(0, -0.08))
			line.call(Vector2(0, 0.03), Vector2(0.08, 0.06))
			line.call(Vector2(-0.05, -0.26), Vector2(0.05, -0.26))
		"eye":
			var pts4 := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				pts4.append(c + Vector2(lerpf(-0.25, 0.25, t), -sin(t * PI) * 0.14) * s)
			for i in 13:
				var t := 1.0 - i / 12.0
				pts4.append(c + Vector2(lerpf(-0.25, 0.25, t), sin(t * PI) * 0.14) * s)
			pts4.append(pts4[0])
			ci.draw_polyline(pts4, color, w * 0.85, true)
			ci.draw_circle(c, 0.075 * s, color)
		"ribbon":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.12, 0.05) * s, c + Vector2(-0.2, 0.32) * s,
				c + Vector2(-0.08, 0.26) * s, c + Vector2(0.0, 0.08) * s]), color.darkened(0.2))
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.12, 0.05) * s, c + Vector2(0.2, 0.32) * s,
				c + Vector2(0.08, 0.26) * s, c + Vector2(0.0, 0.08) * s]), color.darkened(0.2))
			ci.draw_circle(c + Vector2(0, -0.06) * s, r * 0.85, color)
			ci.draw_arc(c + Vector2(0, -0.06) * s, r * 0.6, 0, TAU, 20, Color.WHITE, w * 0.5, true)
		"bell":
			_bell(ci, c, s * 0.3, color, true)
		"bell_line":
			_bell(ci, c, s * 0.3, color, false)
		"paint", "brush":
			# a roller: drum, handle, grip
			var drum := StyleBoxFlat.new()
			drum.bg_color = color
			drum.set_corner_radius_all(int(s * 0.04))
			ci.draw_style_box(drum, Rect2(c + Vector2(-0.2, -0.22) * s, Vector2(0.36, 0.14) * s))
			ci.draw_polyline(PackedVector2Array([c + Vector2(0.16, -0.15) * s, c + Vector2(0.23, -0.15) * s,
				c + Vector2(0.23, -0.02) * s, c + Vector2(-0.01, 0.01) * s, c + Vector2(-0.01, 0.06) * s]), color, w * 0.8, true)
			var grip := StyleBoxFlat.new()
			grip.bg_color = color
			grip.set_corner_radius_all(int(s * 0.03))
			ci.draw_style_box(grip, Rect2(c + Vector2(-0.045, 0.06) * s, Vector2(0.07, 0.18) * s))
		"map":
			var m := PackedVector2Array([c + Vector2(-0.24, -0.16) * s, c + Vector2(-0.08, -0.22) * s, c + Vector2(0.08, -0.16) * s,
				c + Vector2(0.24, -0.22) * s, c + Vector2(0.24, 0.16) * s, c + Vector2(0.08, 0.22) * s, c + Vector2(-0.08, 0.16) * s,
				c + Vector2(-0.24, 0.22) * s, c + Vector2(-0.24, -0.16) * s])
			ci.draw_polyline(m, color, w * 0.85, true)
			line.call(Vector2(-0.08, -0.22), Vector2(-0.08, 0.16), 0.7)
			line.call(Vector2(0.08, -0.16), Vector2(0.08, 0.22), 0.7)
		"levels":
			# a winding path with numbered stops
			var pts5 := PackedVector2Array()
			for i in 21:
				var t := i / 20.0
				pts5.append(c + Vector2(lerpf(-0.22, 0.22, t), sin(t * PI * 2.0) * 0.1 + 0.04) * s)
			ci.draw_polyline(pts5, Color(color, 0.55), w * 0.7, true)
			for t in [0.0, 0.5, 1.0]:
				var p := c + Vector2(lerpf(-0.22, 0.22, t), sin(t * PI * 2.0) * 0.1 + 0.04) * s
				ci.draw_circle(p, s * 0.075, color)
			_flag(ci, c + Vector2(0.22, -0.02) * s, s, color, w)
		"cup":
			var cupb := PackedVector2Array([c + Vector2(-0.19, -0.06) * s, c + Vector2(0.13, -0.06) * s,
				c + Vector2(0.1, 0.16) * s, c + Vector2(-0.16, 0.16) * s])
			ci.draw_colored_polygon(cupb, color)
			ci.draw_arc(c + Vector2(0.15, 0.03) * s, 0.065 * s, -PI * 0.5, PI * 0.5, 10, color, w * 0.8, true)
			line.call(Vector2(-0.22, 0.21), Vector2(0.18, 0.21), 0.8)
			for k in 2:
				var x := -0.08 + k * 0.1
				ci.draw_polyline(PackedVector2Array([c + Vector2(x, -0.12) * s, c + Vector2(x + 0.03, -0.17) * s, c + Vector2(x, -0.22) * s]), color, w * 0.6, true)
		"croissant":
			var cr := PackedVector2Array()
			for i in 17:
				var a := PI + PI * i / 16.0
				cr.append(c + Vector2(cos(a) * 0.24, sin(a) * 0.16 + 0.06) * s)
			for i in 17:
				var a := TAU - PI * i / 16.0
				cr.append(c + Vector2(cos(a) * 0.12, sin(a) * 0.06 + 0.07) * s)
			ci.draw_colored_polygon(cr, color)
			for x in [-0.1, 0.0, 0.1]:
				ci.draw_line(c + Vector2(x, -0.08) * s, c + Vector2(x * 0.7, 0.04) * s, Color(1, 1, 1, 0.5), w * 0.5, true)
		"moon":
			_crescent(ci, c, r * 1.1, color)
		"lantern":
			line.call(Vector2(0, -0.27), Vector2(0, -0.21), 0.8)
			ci.draw_arc(c + Vector2(0, -0.27) * s, 0.04 * s, PI, TAU, 8, color, w * 0.6, true)
			var top := PackedVector2Array([c + Vector2(-0.14, -0.13) * s, c + Vector2(0, -0.21) * s, c + Vector2(0.14, -0.13) * s])
			ci.draw_colored_polygon(top, color)
			ci.draw_rect(Rect2(c + Vector2(-0.12, -0.13) * s, Vector2(0.24, 0.27) * s), color, false, w * 0.8)
			ci.draw_rect(Rect2(c + Vector2(-0.07, -0.08) * s, Vector2(0.14, 0.17) * s), Color(color, 0.55))
			line.call(Vector2(-0.15, 0.15), Vector2(0.15, 0.15), 1.0)
		"stamp":
			# an ink stamp mark: double ring with a tick
			ci.draw_arc(c, r * 1.12, 0, TAU, 32, color, w * 0.9, true)
			ci.draw_arc(c, r * 0.86, 0, TAU, 32, color, w * 0.45, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.1, 0.0) * s, c + Vector2(-0.03, 0.07) * s, c + Vector2(0.11, -0.07) * s]), color, w * 1.1, true)
		"target":
			ci.draw_arc(c, r * 1.1, 0, TAU, 28, color, w * 0.85, true)
			ci.draw_arc(c, r * 0.62, 0, TAU, 24, color, w * 0.85, true)
			ci.draw_circle(c, r * 0.22, color)
		"music":
			line.call(Vector2(-0.08, 0.12), Vector2(-0.08, -0.18))
			line.call(Vector2(0.16, 0.06), Vector2(0.16, -0.24))
			ci.draw_line(c + Vector2(-0.08, -0.18) * s, c + Vector2(0.16, -0.24) * s, color, w * 1.6, true)
			ci.draw_circle(c + Vector2(-0.14, 0.13) * s, s * 0.075, color)
			ci.draw_circle(c + Vector2(0.1, 0.07) * s, s * 0.075, color)
		"sound":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(-0.22, -0.07) * s, c + Vector2(-0.12, -0.07) * s, c + Vector2(0.0, -0.18) * s,
				c + Vector2(0.0, 0.18) * s, c + Vector2(-0.12, 0.07) * s, c + Vector2(-0.22, 0.07) * s]), color)
			ci.draw_arc(c + Vector2(0.02, 0) * s, s * 0.11, -PI * 0.3, PI * 0.3, 10, color, w * 0.8, true)
			ci.draw_arc(c + Vector2(0.02, 0) * s, s * 0.2, -PI * 0.3, PI * 0.3, 12, color, w * 0.8, true)
		"vibrate":
			var ph := StyleBoxFlat.new()
			ph.bg_color = Color(0, 0, 0, 0)
			ph.border_color = color
			ph.set_border_width_all(int(maxf(2.0, w * 0.8)))
			ph.set_corner_radius_all(int(s * 0.05))
			ci.draw_style_box(ph, Rect2(c + Vector2(-0.1, -0.2) * s, Vector2(0.2, 0.4) * s))
			for sd in [-1.0, 1.0]:
				ci.draw_polyline(PackedVector2Array([c + Vector2(0.17 * sd, -0.1) * s, c + Vector2(0.22 * sd, -0.04) * s,
					c + Vector2(0.17 * sd, 0.03) * s, c + Vector2(0.22 * sd, 0.1) * s]), color, w * 0.7, true)
		"motion":
			# a soft wave: "motion" setting
			var wv := PackedVector2Array()
			for i in 25:
				var t := i / 24.0
				wv.append(c + Vector2(lerpf(-0.24, 0.24, t), sin(t * TAU * 1.5) * 0.08) * s)
			ci.draw_polyline(wv, color, w, true)
			ci.draw_circle(c + Vector2(0.24, sin(TAU * 1.5) * 0.08) * s, s * 0.05, color)
		"text":
			line.call(Vector2(-0.2, -0.17), Vector2(0.06, -0.17))
			line.call(Vector2(-0.07, -0.17), Vector2(-0.07, 0.18))
			line.call(Vector2(0.06, -0.02), Vector2(0.22, -0.02), 0.8)
			line.call(Vector2(0.14, -0.02), Vector2(0.14, 0.18), 0.8)
		"globe":
			ci.draw_arc(c, r * 1.05, 0, TAU, 28, color, w * 0.85, true)
			ci.draw_line(c + Vector2(-r * 1.05, 0), c + Vector2(r * 1.05, 0), color, w * 0.7, true)
			var ell := PackedVector2Array()
			for i in 25:
				var a := TAU * i / 24.0
				ell.append(c + Vector2(cos(a) * r * 0.45, sin(a) * r * 1.05))
			ci.draw_polyline(ell, color, w * 0.7, true)
		"calendar":
			var cal := StyleBoxFlat.new()
			cal.bg_color = Color(0, 0, 0, 0)
			cal.border_color = color
			cal.set_border_width_all(int(maxf(2.0, w * 0.85)))
			cal.set_corner_radius_all(int(s * 0.05))
			ci.draw_style_box(cal, Rect2(c + Vector2(-0.22, -0.16) * s, Vector2(0.44, 0.38) * s))
			ci.draw_rect(Rect2(c + Vector2(-0.22, -0.16) * s, Vector2(0.44, 0.1) * s), color)
			line.call(Vector2(-0.11, -0.24), Vector2(-0.11, -0.13), 0.9)
			line.call(Vector2(0.11, -0.24), Vector2(0.11, -0.13), 0.9)
			for k in 3:
				ci.draw_circle(c + Vector2(-0.11 + k * 0.11, 0.06) * s, s * 0.025, color)
		"bolt":
			ci.draw_colored_polygon(PackedVector2Array([c + Vector2(0.04, -0.26) * s, c + Vector2(-0.14, 0.03) * s, c + Vector2(-0.01, 0.03) * s,
				c + Vector2(-0.05, 0.26) * s, c + Vector2(0.14, -0.04) * s, c + Vector2(0.01, -0.04) * s]), color)
		"door", "home":
			var dr := StyleBoxFlat.new()
			dr.bg_color = Color(0, 0, 0, 0)
			dr.border_color = color
			dr.set_border_width_all(int(maxf(2.0, w * 0.85)))
			dr.corner_radius_top_left = int(s * 0.12)
			dr.corner_radius_top_right = int(s * 0.12)
			ci.draw_style_box(dr, Rect2(c + Vector2(-0.15, -0.22) * s, Vector2(0.3, 0.44) * s))
			ci.draw_circle(c + Vector2(0.07, 0.03) * s, s * 0.03, color)
			line.call(Vector2(-0.24, 0.22), Vector2(0.24, 0.22), 0.9)
		"spark":
			for a in 4:
				var ang := a * PI / 2
				var d2 := Vector2(cos(ang), sin(ang))
				ci.draw_line(c + d2 * s * 0.08, c + d2 * s * 0.26, color, w, true)
			for a in 4:
				var ang2 := PI / 4 + a * PI / 2
				var d3 := Vector2(cos(ang2), sin(ang2))
				ci.draw_line(c + d3 * s * 0.08, c + d3 * s * 0.16, color, w * 0.8, true)
		"counter":
			for k in 3:
				var sl := StyleBoxFlat.new()
				sl.bg_color = color
				sl.set_corner_radius_all(int(s * 0.03))
				ci.draw_style_box(sl, Rect2(c + Vector2(-0.22 + k * 0.155, -0.1) * s, Vector2(0.13, 0.14) * s))
			line.call(Vector2(-0.25, 0.12), Vector2(0.25, 0.12), 1.0)
		"crate":
			ci.draw_rect(Rect2(c + Vector2(-0.2, -0.16) * s, Vector2(0.4, 0.34) * s), color, false, w * 0.85)
			line.call(Vector2(-0.2, -0.04), Vector2(0.2, -0.04), 0.6)
			line.call(Vector2(-0.2, 0.07), Vector2(0.2, 0.07), 0.6)
		"tap":
			ci.draw_arc(c + Vector2(0, -0.1) * s, s * 0.12, PI, TAU, 12, color, w * 0.7, true)
			var fp := StyleBoxFlat.new()
			fp.bg_color = color
			fp.set_corner_radius_all(int(s * 0.05))
			ci.draw_style_box(fp, Rect2(c + Vector2(-0.05, -0.12) * s, Vector2(0.1, 0.36) * s))
		"reset", "trash":
			line.call(Vector2(-0.2, -0.14), Vector2(0.2, -0.14))
			line.call(Vector2(-0.06, -0.2), Vector2(0.06, -0.2))
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.15, -0.1) * s, c + Vector2(-0.12, 0.22) * s,
				c + Vector2(0.12, 0.22) * s, c + Vector2(0.15, -0.1) * s]), color, w * 0.85, true)
		"shield":
			var sh := PackedVector2Array([c + Vector2(0, -0.24) * s, c + Vector2(0.2, -0.16) * s, c + Vector2(0.18, 0.04) * s,
				c + Vector2(0, 0.24) * s, c + Vector2(-0.18, 0.04) * s, c + Vector2(-0.2, -0.16) * s, c + Vector2(0, -0.24) * s])
			ci.draw_polyline(sh, color, w * 0.85, true)
			ci.draw_polyline(PackedVector2Array([c + Vector2(-0.08, 0.0) * s, c + Vector2(-0.02, 0.06) * s, c + Vector2(0.09, -0.06) * s]), color, w * 0.85, true)
		"heart":
			var hp := PackedVector2Array()
			for i in 33:
				var t := TAU * i / 32.0
				var x := 16 * pow(sin(t), 3)
				var y := -(13 * cos(t) - 5 * cos(2 * t) - 2 * cos(3 * t) - cos(4 * t))
				hp.append(c + Vector2(x, y) * s * 0.014)
			ci.draw_colored_polygon(hp, color)
		"cake":
			ci.draw_rect(Rect2(c + Vector2(-0.2, -0.02) * s, Vector2(0.4, 0.22) * s), color)
			ci.draw_rect(Rect2(c + Vector2(-0.14, -0.14) * s, Vector2(0.28, 0.12) * s), Color(color, 0.7))
			line.call(Vector2(0, -0.24), Vector2(0, -0.15), 0.7)
		"flag":
			_flag(ci, c + Vector2(-0.05, 0.1) * s, s * 1.6, color, w)

## Crescent = outer disc minus an offset disc, built from the two arcs
## between the circles' intersection points.
static func _crescent(ci: CanvasItem, c: Vector2, R: float, color: Color) -> void:
	var c2 := c + Vector2(R * 0.42, -R * 0.3)
	var r2 := R * 0.86
	var D := c.distance_to(c2)
	var phi := (c2 - c).angle()
	var alpha := acos(clampf((R * R + D * D - r2 * r2) / (2 * R * D), -1, 1))
	var pts := PackedVector2Array()
	for i in 25:
		var a := phi + alpha + (TAU - 2 * alpha) * i / 24.0
		pts.append(c + Vector2(cos(a), sin(a)) * R)
	var p_end := pts[pts.size() - 1]
	var p_start := pts[0]
	var b0 := (p_end - c2).angle()
	var b1 := (p_start - c2).angle()
	# inner arc from p_end back to p_start, through the part inside the outer disc
	var span := wrapf(b1 - b0, -PI, PI)
	var mid := b0 + span / 2
	if c.distance_to(c2 + Vector2(cos(mid), sin(mid)) * r2) > R:
		span = span - TAU if span > 0 else span + TAU
	for i in range(1, 24):
		var a2 := b0 + span * i / 24.0
		pts.append(c2 + Vector2(cos(a2), sin(a2)) * r2)
	ci.draw_colored_polygon(pts, color)

static func _flag(ci: CanvasItem, base: Vector2, s: float, color: Color, w: float) -> void:
	ci.draw_line(base, base + Vector2(0, -0.2) * s, color, w * 0.8, true)
	ci.draw_colored_polygon(PackedVector2Array([base + Vector2(0, -0.2) * s, base + Vector2(0.12, -0.16) * s, base + Vector2(0, -0.12) * s]), color)

## Bell drawn as a shape (dome, rim, clapper).
static func _bell(ci: CanvasItem, c: Vector2, r: float, col: Color, filled: bool) -> void:
	var pts := PackedVector2Array()
	for i in 13:
		var t := PI + PI * i / 12.0
		pts.append(c + Vector2(cos(t) * r * 0.8, sin(t) * r * 0.95 + r * 0.25))
	pts.append(c + Vector2(r, r * 0.45))
	pts.append(c + Vector2(-r, r * 0.45))
	if filled:
		ci.draw_colored_polygon(pts, col)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, col, maxf(2.0, r * 0.16), true)
	ci.draw_circle(c + Vector2(0, r * 0.62), r * 0.18, col)
	ci.draw_circle(c + Vector2(0, -r * 0.78), r * 0.13, col)
