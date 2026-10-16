class_name Fx
extends RefCounted
## Short-lived visual effects: particle bursts, floating text and the
## press-and-hold guide line. Effects never touch game state, and every node
## frees itself. Reduced motion swaps movement for a brief, still glow.

const CONFETTI := [Color("c8643f"), Color("1f7a72"), Color("e0a93b"), Color("e58fa8"), Color("6fb8ae")]

## Spawns a burst at `global_pos` inside `layer`.
## kind: "sparkle" (small, landing), "pop" (delivery), "confetti" (win).
static func burst(layer: Control, global_pos: Vector2, kind: String = "sparkle", colors: Array = []) -> Control:
	var b := _Burst.new()
	b.kind = kind
	b.colors = colors if not colors.is_empty() else CONFETTI
	b.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.position = layer.get_global_transform().affine_inverse() * global_pos
	layer.add_child(b)
	b.start()
	return b

## Text that rises and fades. Used for streaks and "+N" rewards.
static func float_text(layer: Control, global_pos: Vector2, text: String, color: Color = Style.TEAL_DARK, size: int = 40) -> Label:
	var l := Label.new()
	l.text = text
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", Style.font_bold)
	l.add_theme_font_size_override("font_size", Style.fs(size))
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Style.PAPER)
	l.add_theme_constant_override("outline_size", 10)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	layer.add_child(l)
	l.size = Vector2(520, 70)
	l.position = layer.get_global_transform().affine_inverse() * global_pos - l.size / 2
	l.pivot_offset = l.size / 2
	var tw := l.create_tween()
	if App.reduced_motion():
		tw.tween_interval(0.7)
		tw.tween_property(l, "modulate:a", 0.0, 0.2)
	else:
		l.scale = Vector2(0.6, 0.6)
		tw.tween_property(l, "scale", Vector2.ONE, 0.16).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.parallel().tween_property(l, "position:y", l.position.y - 70, 0.8).set_ease(Tween.EASE_OUT)
		tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(l.queue_free)
	return l

class _Burst extends Control:
	var kind := "sparkle"
	var colors: Array = []
	var parts: Array = []      # [pos, vel, life, max_life, color, size, spin, shape]
	var t := 0.0
	var still := false

	func start() -> void:
		still = App.reduced_motion()
		var rng := RandomNumberGenerator.new()
		rng.seed = Time.get_ticks_usec()
		var n := {"sparkle": 8, "pop": 16, "confetti": 70}.get(kind, 10) as int
		if still:
			n = 0
		for i in n:
			var ang := rng.randf_range(0, TAU)
			var spd := rng.randf_range(120, 300)
			var life := rng.randf_range(0.35, 0.6)
			var shape := 0
			var sz := rng.randf_range(4, 8)
			if kind == "confetti":
				ang = rng.randf_range(-PI * 0.95, -PI * 0.05)
				spd = rng.randf_range(420, 900)
				life = rng.randf_range(1.0, 1.6)
				shape = 1
				sz = rng.randf_range(8, 14)
			elif kind == "pop":
				spd = rng.randf_range(200, 420)
				shape = 2 if i % 3 == 0 else 0
				sz = rng.randf_range(6, 11)
			parts.append([Vector2.ZERO, Vector2(cos(ang), sin(ang)) * spd, life, life,
				colors[i % colors.size()], sz, rng.randf_range(-8, 8), shape])

	func _process(delta: float) -> void:
		t += delta
		var alive := false
		for p in parts:
			if p[2] <= 0:
				continue
			alive = true
			p[2] -= delta
			p[1] += Vector2(0, 900 if kind == "confetti" else 500) * delta
			p[1] *= 0.985 if kind == "confetti" else 0.96
			p[0] += p[1] * delta
		queue_redraw()
		if (not alive and not still) or (still and t > 0.35):
			queue_free()

	func _draw() -> void:
		if still:
			var a := 1.0 - t / 0.35
			var r := {"sparkle": 34.0, "pop": 60.0, "confetti": 120.0}.get(kind, 40.0) as float
			draw_circle(Vector2.ZERO, r, Color(Style.GOLD, 0.25 * a))
			return
		for p in parts:
			if p[2] <= 0:
				continue
			var k: float = p[2] / p[3]
			var c: Color = p[4]
			c.a = clampf(k * 1.5, 0, 1)
			var s: float = p[5]
			match int(p[7]):
				0:
					draw_circle(p[0], s * (0.5 + 0.5 * k), c)
				1:
					draw_set_transform(p[0], t * p[6], Vector2.ONE)
					draw_rect(Rect2(Vector2(-s / 2, -s / 4), Vector2(s, s / 2)), c)
					draw_set_transform(Vector2.ZERO)
				2:
					var pts := PackedVector2Array()
					for i in 10:
						var a := -PI / 2 + TAU * i / 10.0
						var rr := s * (1.0 if i % 2 == 0 else 0.45)
						pts.append(p[0] + Vector2(cos(a), sin(a)) * rr)
					draw_colored_polygon(pts, c)

## Dashed arc from a crate to the destination of its front item.
class GuideLine extends Control:
	var from := Vector2.ZERO
	var to := Vector2.ZERO
	var color := Style.TEAL
	var _phase := 0.0

	func _ready() -> void:
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_points(a: Vector2, b: Vector2, c: Color) -> void:
		from = a
		to = b
		color = c
		queue_redraw()

	func _process(delta: float) -> void:
		if not App.reduced_motion():
			_phase = fmod(_phase + delta * 1.6, 1.0)
			queue_redraw()

	func _draw() -> void:
		var mid := (from + to) / 2 + Vector2(0, -80)
		var n := 22
		for i in n:
			if (i + int(_phase * 2)) % 2 == 1:
				continue
			var k0 := float(i) / n
			var k1 := float(i + 1) / n
			draw_line(_q(k0, mid), _q(k1, mid), Color(color, 0.85), 6, true)
		draw_circle(to, 12, Color(color, 0.9))
		draw_circle(to, 22, Color(color, 0.25))

	func _q(k: float, mid: Vector2) -> Vector2:
		return (1 - k) * (1 - k) * from + 2 * (1 - k) * k * mid + k * k * to
