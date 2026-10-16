class_name Glyph
extends Control
## Simple drawn icons (no icon font needed). Mirrors horizontally in RTL for
## directional glyphs (back, undo).

var kind := "back"
var color := Color.WHITE
var thickness := 0.0

func _ready() -> void:
	resized.connect(queue_redraw)

func _draw() -> void:
	var s := minf(size.x, size.y)
	var c := size / 2.0
	var w := thickness if thickness > 0 else maxf(3.0, s * 0.075)
	var r := s * 0.26
	var flip := -1.0 if (Loc.is_rtl() and kind in ["back", "undo", "next"]) else 1.0
	var P := func(x: float, y: float) -> Vector2: return c + Vector2(x * flip, y) * s
	match kind:
		"back":
			draw_polyline(PackedVector2Array([P.call(0.08, -0.2), P.call(-0.12, 0.0), P.call(0.08, 0.2)]), color, w, true)
		"next":
			draw_polyline(PackedVector2Array([P.call(-0.08, -0.2), P.call(0.12, 0.0), P.call(-0.08, 0.2)]), color, w, true)
		"undo":
			# Arc over the top from right to left, arrowhead pointing down on the left.
			var arc := PackedVector2Array()
			for i in 17:
				var a := lerpf(0.35 * PI, -PI, i / 16.0)
				arc.append(P.call(cos(a) * 0.19, sin(a) * 0.19 + 0.05))
			draw_polyline(arc, color, w, true)
			var tip: Vector2 = P.call(-0.19, 0.05)
			draw_colored_polygon(PackedVector2Array([tip + Vector2(-0.1, -0.02) * s, tip + Vector2(0.1, -0.02) * s, tip + Vector2(0, 0.12) * s]), color)
		"restart":
			draw_arc(c, r, -PI * 0.3, PI * 1.45, 24, color, w, true)
			var t2 := c + Vector2(cos(-PI * 0.3), sin(-PI * 0.3)) * r
			draw_colored_polygon(PackedVector2Array([t2 + Vector2(-0.12, -0.04) * s, t2 + Vector2(0.06, -0.12) * s, t2 + Vector2(0.05, 0.08) * s]), color)
		"hint":
			# light bulb: rounded glass, collar, base, and three rays
			var bc := c + Vector2(0, -0.07) * s
			draw_arc(bc, r * 0.72, PI * 0.72, PI * 2.28, 24, color, w, true)
			draw_line(c + Vector2(-0.075, 0.1) * s, c + Vector2(-0.075, 0.16) * s, color, w, true)
			draw_line(c + Vector2(0.075, 0.1) * s, c + Vector2(0.075, 0.16) * s, color, w, true)
			draw_line(c + Vector2(-0.085, 0.16) * s, c + Vector2(0.085, 0.16) * s, color, w, true)
			draw_line(c + Vector2(-0.05, 0.23) * s, c + Vector2(0.05, 0.23) * s, color, w, true)
			for a in [-PI * 0.5, -PI * 0.15, -PI * 0.85]:
				var d := Vector2(cos(a), sin(a))
				draw_line(bc + d * r * 1.0, bc + d * r * 1.3, color, w * 0.8, true)
		"pause":
			draw_line(c + Vector2(-0.09, -0.18) * s, c + Vector2(-0.09, 0.18) * s, color, w * 1.4, true)
			draw_line(c + Vector2(0.09, -0.18) * s, c + Vector2(0.09, 0.18) * s, color, w * 1.4, true)
		"gear":
			draw_arc(c, r * 0.55, 0, TAU, 20, color, w, true)
			for i in 8:
				var a := TAU * i / 8.0
				draw_line(c + Vector2(cos(a), sin(a)) * r * 0.8, c + Vector2(cos(a), sin(a)) * r * 1.15, color, w * 1.2, true)
		"help":
			draw_arc(c + Vector2(0, -0.08) * s, r * 0.6, PI, PI * 2.4, 16, color, w, true)
			draw_line(c + Vector2(0.06, 0.0) * s, c + Vector2(0.0, 0.08) * s, color, w, true)
			draw_circle(c + Vector2(0, 0.2) * s, w * 0.75, color)
		"star":
			var pts := PackedVector2Array()
			for i in 10:
				var a := -PI / 2 + TAU * i / 10.0
				var rr := r * (1.15 if i % 2 == 0 else 0.5)
				pts.append(c + Vector2(cos(a), sin(a)) * rr)
			draw_colored_polygon(pts, color)
		"lock":
			draw_arc(c + Vector2(0, -0.06) * s, r * 0.55, PI, TAU, 16, color, w, true)
			draw_rect(Rect2(c + Vector2(-0.2, -0.06) * s, Vector2(0.4, 0.3) * s), color)
		"check":
			draw_polyline(PackedVector2Array([c + Vector2(-0.18, 0.0) * s, c + Vector2(-0.05, 0.14) * s, c + Vector2(0.2, -0.14) * s]), color, w * 1.3, true)
		"share":
			for p in [Vector2(0.15, -0.17), Vector2(-0.15, 0.0), Vector2(0.15, 0.17)]:
				draw_circle(c + p * s, s * 0.06, color)
			draw_line(c + Vector2(0.15, -0.17) * s, c + Vector2(-0.15, 0.0) * s, color, w * 0.8, true)
			draw_line(c + Vector2(0.15, 0.17) * s, c + Vector2(-0.15, 0.0) * s, color, w * 0.8, true)
		"plus":
			draw_line(c + Vector2(-0.18, 0) * s, c + Vector2(0.18, 0) * s, color, w * 1.2, true)
			draw_line(c + Vector2(0, -0.18) * s, c + Vector2(0, 0.18) * s, color, w * 1.2, true)
		"close":
			draw_line(c + Vector2(-0.15, -0.15) * s, c + Vector2(0.15, 0.15) * s, color, w * 1.2, true)
			draw_line(c + Vector2(0.15, -0.15) * s, c + Vector2(-0.15, 0.15) * s, color, w * 1.2, true)
		"play":
			draw_colored_polygon(PackedVector2Array([P.call(-0.12, -0.2), P.call(0.18, 0.0), P.call(-0.12, 0.2)]), color)
		"coin":
			# restoration token: a round coin with a small cup stamped on it
			draw_circle(c, r * 1.25, color)
			draw_arc(c, r * 1.0, 0, TAU, 28, color.darkened(0.25), w * 0.6, true)
			var cup := PackedVector2Array([c + Vector2(-0.11, -0.05) * s, c + Vector2(0.11, -0.05) * s,
				c + Vector2(0.08, 0.11) * s, c + Vector2(-0.08, 0.11) * s])
			draw_colored_polygon(cup, color.darkened(0.35))
			draw_arc(c + Vector2(0.12, 0.02) * s, 0.045 * s, -PI * 0.5, PI * 0.5, 8, color.darkened(0.35), w * 0.5, true)
		"book":
			draw_rect(Rect2(c + Vector2(-0.2, -0.18) * s, Vector2(0.18, 0.36) * s), color, false, w * 0.8)
			draw_rect(Rect2(c + Vector2(0.02, -0.18) * s, Vector2(0.18, 0.36) * s), color, false, w * 0.8)
			for i in 3:
				draw_line(c + Vector2(-0.16, -0.08 + i * 0.08) * s, c + Vector2(-0.06, -0.08 + i * 0.08) * s, color, w * 0.5)
				draw_line(c + Vector2(0.06, -0.08 + i * 0.08) * s, c + Vector2(0.16, -0.08 + i * 0.08) * s, color, w * 0.5)
		"trophy":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.16, -0.2) * s, c + Vector2(0.16, -0.2) * s,
				c + Vector2(0.1, 0.04) * s, c + Vector2(-0.1, 0.04) * s]), color)
			draw_arc(c + Vector2(-0.16, -0.1) * s, 0.07 * s, PI * 0.5, PI * 1.5, 8, color, w * 0.6, true)
			draw_arc(c + Vector2(0.16, -0.1) * s, 0.07 * s, -PI * 0.5, PI * 0.5, 8, color, w * 0.6, true)
			draw_line(c + Vector2(0, 0.04) * s, c + Vector2(0, 0.14) * s, color, w)
			draw_rect(Rect2(c + Vector2(-0.12, 0.14) * s, Vector2(0.24, 0.07) * s), color)
		"timer":
			draw_arc(c + Vector2(0, 0.03) * s, r, 0, TAU, 24, color, w, true)
			draw_line(c + Vector2(0, 0.03) * s, c + Vector2(0, -0.08) * s, color, w, true)
			draw_line(c + Vector2(0, 0.03) * s, c + Vector2(0.08, 0.06) * s, color, w, true)
			draw_line(c + Vector2(-0.05, -0.26) * s, c + Vector2(0.05, -0.26) * s, color, w, true)
		"eye":
			var pts2 := PackedVector2Array()
			for i in 13:
				var t := i / 12.0
				pts2.append(c + Vector2(lerpf(-0.24, 0.24, t), -sin(t * PI) * 0.13) * s)
			for i in 13:
				var t := 1.0 - i / 12.0
				pts2.append(c + Vector2(lerpf(-0.24, 0.24, t), sin(t * PI) * 0.13) * s)
			pts2.append(pts2[0])
			draw_polyline(pts2, color, w * 0.8, true)
			draw_circle(c, 0.07 * s, color)
		"ribbon":
			# mastery rosette: a disc with two tails
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.12, 0.05) * s, c + Vector2(-0.2, 0.32) * s,
				c + Vector2(-0.08, 0.26) * s, c + Vector2(0.0, 0.08) * s]), color.darkened(0.2))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0.12, 0.05) * s, c + Vector2(0.2, 0.32) * s,
				c + Vector2(0.08, 0.26) * s, c + Vector2(0.0, 0.08) * s]), color.darkened(0.2))
			draw_circle(c + Vector2(0, -0.06) * s, r * 0.85, color)
			draw_arc(c + Vector2(0, -0.06) * s, r * 0.6, 0, TAU, 20, Color.WHITE, w * 0.5, true)
		"bell":
			OrderCard.draw_bell(self, c, s * 0.3, true)
		"paint":
			draw_rect(Rect2(c + Vector2(-0.18, -0.2) * s, Vector2(0.36, 0.14) * s), color)
			draw_line(c + Vector2(0.18, -0.13) * s, c + Vector2(0.24, -0.13) * s, color, w)
			draw_line(c + Vector2(0.24, -0.13) * s, c + Vector2(0.24, 0.0) * s, color, w)
			draw_line(c + Vector2(0.24, 0.0) * s, c + Vector2(0.0, 0.02) * s, color, w)
			draw_rect(Rect2(c + Vector2(-0.03, 0.02) * s, Vector2(0.06, 0.2) * s), color)
