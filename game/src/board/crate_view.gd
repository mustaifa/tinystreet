class_name CrateView
extends Control
## One delivery crate. The FRONT item (bottom, large) is the only selectable
## one; every item behind it is drawn above in order, so the full contents are
## always visible (paper bags show as a bag until they reach the front).
##
## A badge on the front item always says where a tap would send it:
##   numbered order ticket, counter, hot "wait" mark, padlock, or a cross.
## Shape and number carry the meaning; colour only reinforces it.
## Press lifts the item; it can be dragged, and releasing over the crate or
## its destination confirms the move (the board decides).

signal pressed_down(index: int)
signal released(index: int, global_pos: Vector2)
signal dragged(index: int, global_pos: Vector2)

var index := 0
var items: PackedInt32Array = PackedInt32Array()   # remaining, [0] = front; -1 = bagged
var fresh: Array = []          # bool per remaining item
var lock_left := 0             # deliveries still needed to open
var badge := {}                # {kind: "tray"|"counter"|"fresh"|"locked"|"full", tray: int}
var highlight := false         # hint / tutorial ring
var hide_front := false        # while the front item is flying
var dim := false
var lifted := false
var drag_local := Vector2.INF  # finger position while dragging the front item
var _shake := 0.0
var _pulse := 0.0
var _down := false
var _press_pos := Vector2.ZERO
var _unlock_flash := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func set_state(it: PackedInt32Array, fr: Array, lock: int, b: Dictionary) -> void:
	items = it
	fresh = fr
	lock_left = lock
	badge = b
	queue_redraw()

func front_size() -> float:
	return minf(size.x * 0.86, 124.0)

func back_size() -> float:
	return front_size() * 0.62

func front_center() -> Vector2:
	return Vector2(size.x / 2, size.y - front_size() * 0.5 - 20)

func front_global_center() -> Vector2:
	return get_global_transform() * front_center()

func shake() -> void:
	if App.reduced_motion():
		return
	var tw := create_tween()
	tw.tween_method(func(v): _shake = v; queue_redraw(), 1.0, 0.0, 0.32)

func flash_unlock() -> void:
	var tw := create_tween()
	tw.tween_method(func(v): _unlock_flash = v; queue_redraw(), 1.0, 0.0, App.dur(0.6))

func _process(delta: float) -> void:
	if highlight or (not fresh.is_empty() and fresh[0]):
		_pulse = fmod(_pulse + delta * (0.0 if App.reduced_motion() else 1.4), 1.0)
		queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true
			_press_pos = e.position
			drag_local = Vector2.INF
			pressed_down.emit(index)
			accept_event()
		elif _down:
			_down = false
			drag_local = Vector2.INF
			released.emit(index, get_global_transform() * e.position)
			accept_event()
			queue_redraw()
	elif e is InputEventMouseMotion and _down:
		if drag_local != Vector2.INF or e.position.distance_to(_press_pos) > 18.0:
			drag_local = e.position
			dragged.emit(index, get_global_transform() * e.position)
			queue_redraw()
		accept_event()

## Cancels an in-progress press without emitting a release (e.g. on pause).
func cancel_press() -> void:
	_down = false
	lifted = false
	drag_local = Vector2.INF
	queue_redraw()

func _draw() -> void:
	var off := Vector2(sin(_shake * 28.0) * 7.0 * _shake, 0)
	var w := size.x
	var fs := front_size()
	var bs := back_size()
	_draw_crate(off, w, fs)
	var tray := Rect2(Vector2(4, size.y - fs - 38) + off, Vector2(w - 8, fs + 34))
	if items.is_empty():
		draw_string(Style.font_regular, Vector2(0, tray.get_center().y + 10) + off, "—", HORIZONTAL_ALIGNMENT_CENTER, w, 34, Color(Style.PAPER, 0.8))
		return
	# Items behind the front, bottom-to-top = next-to-last. Every item is always
	# drawn: if the column is short, items shrink to fit instead of being cut.
	var behind := items.size() - 1
	var avail := tray.position.y - 8.0
	var step := bs * 0.86
	if behind > 0 and behind * step > avail:
		step = avail / behind
		bs = minf(bs, step / 0.86)
	var y0 := tray.position.y - step * 0.5 - 4
	for i in range(1, items.size()):
		var c := Vector2(w / 2, y0 - (i - 1) * step) + off
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color(Style.PAPER, 0.85)
		plate.set_corner_radius_all(int(bs * 0.3))
		draw_style_box(plate, Rect2(c - Vector2(bs, bs) * 0.48, Vector2(bs, bs) * 0.96))
		_draw_item(items[i], c, bs * 0.82, 0.55 if dim else 0.92, i < fresh.size() and fresh[i])
	if not hide_front:
		var fc := front_center() + off
		var sc := 1.0
		if lifted and not App.reduced_motion():
			fc += Vector2(0, -16)
			sc = 1.08
		if drag_local != Vector2.INF:
			# A faint ghost stays in the crate; the item follows the finger.
			_plate(front_center() + off, fs, Color(Style.PAPER, 0.35))
			fc = drag_local
			sc = 1.12
		if highlight:
			var r := fs * (0.62 + 0.06 * sin(_pulse * TAU))
			draw_arc(fc, r, 0, TAU, 40, Style.GOLD, 7, true)
		if lifted:
			var shadow := StyleBoxFlat.new()
			shadow.bg_color = Color(0, 0, 0, 0.0)
			shadow.shadow_color = Color(0.2, 0.12, 0.06, 0.3)
			shadow.shadow_size = 16
			shadow.shadow_offset = Vector2(0, 12)
			shadow.set_corner_radius_all(int(fs * 0.28))
			draw_style_box(shadow, Rect2(fc - Vector2(fs, fs) * 0.5 * sc, Vector2(fs, fs) * sc))
		var is_fresh: bool = not fresh.is_empty() and fresh[0]
		_plate(fc, fs * sc, Style.PAPER if not is_fresh else Color("fff3e4"))
		if is_fresh:
			_fresh_ring(fc, fs * sc)
		_draw_item(items[0], fc, fs * 0.86 * sc, 0.6 if dim else 1.0, false)
		if drag_local == Vector2.INF:
			_draw_badge(fc + Vector2(fs * 0.42, -fs * 0.42) * sc)
	if lock_left > 0:
		_draw_lock(off, w)
	if _unlock_flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, size), Color(1, 0.95, 0.75, 0.45 * _unlock_flash))

func _draw_crate(off: Vector2, w: float, fs: float) -> void:
	# Back boards: a slatted wooden crate standing behind the stack.
	var body := Rect2(Vector2(6, 2) + off, Vector2(w - 12, size.y - 8))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color("e9cfae")
	sb.set_corner_radius_all(18)
	sb.border_color = Color(Style.WOOD, 0.55)
	sb.set_border_width_all(3)
	draw_style_box(sb, body)
	var slats := int((size.y - fs - 40) / 46.0)
	for k in slats:
		var y := 30 + k * 46.0
		draw_line(Vector2(14, y) + off, Vector2(w - 14, y) + off, Color(Style.WOOD, 0.22), 3, true)
	draw_line(Vector2(18, 10) + off, Vector2(18, size.y - fs - 40) + off, Color(Style.WOOD, 0.18), 4)
	draw_line(Vector2(w - 18, 10) + off, Vector2(w - 18, size.y - fs - 40) + off, Color(Style.WOOD, 0.18), 4)
	# Front box that holds the selectable item.
	var tray := Rect2(Vector2(4, size.y - fs - 38) + off, Vector2(w - 8, fs + 34))
	var tb := StyleBoxFlat.new()
	tb.bg_color = Style.WOOD if not items.is_empty() else Color(Style.WOOD, 0.35)
	tb.set_corner_radius_all(20)
	tb.shadow_color = Style.SHADOW
	tb.shadow_size = 6
	tb.shadow_offset = Vector2(0, 3)
	draw_style_box(tb, tray)
	draw_line(Vector2(14, tray.position.y + 12) + off, Vector2(w - 14, tray.position.y + 12) + off, Color(Style.WOOD_LIGHT, 0.6), 3, true)
	draw_line(Vector2(14, tray.end.y - 12) + off, Vector2(w - 14, tray.end.y - 12) + off, Color(Style.WOOD_DARK, 0.4), 3, true)

func _plate(c: Vector2, s: float, col: Color) -> void:
	var p := StyleBoxFlat.new()
	p.bg_color = col
	p.set_corner_radius_all(int(s * 0.28))
	draw_style_box(p, Rect2(c - Vector2(s, s) * 0.5, Vector2(s, s)))

func _draw_item(p: int, c: Vector2, s: float, a: float, is_fresh: bool) -> void:
	if p < 0:
		draw_bag(self, c, s, a)
		return
	ProductArt.draw(self, p, c, s, a)
	if is_fresh:
		draw_steam(self, c + Vector2(-s * 0.36, -s * 0.3), s * 0.32, a)

## Fresh items: a dashed warm ring plus rising steam marks (shape, not colour).
func _fresh_ring(c: Vector2, s: float) -> void:
	var r := s * 0.5
	var n := 16
	for i in n:
		if i % 2 == 0:
			var a0 := TAU * i / n + _pulse * 0.4
			draw_arc(c, r, a0, a0 + TAU / n, 6, Style.TERRACOTTA, 4, true)
	draw_steam(self, c + Vector2(-s * 0.36, -s * 0.36), s * 0.34, 1.0)

static func draw_steam(ci: CanvasItem, c: Vector2, s: float, a: float) -> void:
	for k in 3:
		var pts := PackedVector2Array()
		var x := (k - 1) * s * 0.3
		for i in 7:
			var t := i / 6.0
			pts.append(c + Vector2(x + sin(t * TAU) * s * 0.1, s * 0.4 - t * s * 0.8))
		ci.draw_polyline(pts, Color(Style.TERRACOTTA, 0.9 * a), maxf(2.0, s * 0.1), true)

## Kraft paper bag with a folded top and a question mark.
static func draw_bag(ci: CanvasItem, c: Vector2, s: float, a: float) -> void:
	var lw := maxf(1.5, s * 0.03)
	var body := PackedVector2Array([c + Vector2(-0.3, -0.18) * s, c + Vector2(0.3, -0.18) * s,
		c + Vector2(0.34, 0.38) * s, c + Vector2(-0.34, 0.38) * s])
	ci.draw_colored_polygon(body, Color(Color("c9a26b"), a))
	var top := PackedVector2Array([c + Vector2(-0.3, -0.18) * s, c + Vector2(-0.24, -0.36) * s,
		c + Vector2(0.24, -0.36) * s, c + Vector2(0.3, -0.18) * s])
	ci.draw_colored_polygon(top, Color(Color("b48a55"), a))
	for poly in [body, top]:
		var cl: PackedVector2Array = poly.duplicate()
		cl.append(poly[0])
		ci.draw_polyline(cl, Color(ProductArt.OUTLINE, 0.8 * a), lw, true)
	ci.draw_line(c + Vector2(-0.3, -0.18) * s, c + Vector2(0.3, -0.18) * s, Color(Color("8a6a3e"), a), lw * 1.4, true)
	ci.draw_string(Style.font_bold, c + Vector2(-s * 0.3, s * 0.24), "?", HORIZONTAL_ALIGNMENT_CENTER, s * 0.6, int(s * 0.46), Color(Color("6b4a24"), a))

func _draw_badge(at: Vector2) -> void:
	if badge.is_empty() or lock_left > 0:
		return
	var r := 21.0
	var kind: String = badge.get("kind", "")
	var bg := Style.TEAL
	match kind:
		"counter": bg = Style.WOOD_DARK
		"fresh": bg = Style.TERRACOTTA
		"full": bg = Color("8b8079")
	draw_circle(at + Vector2(0, 2), r + 2, Color(0, 0, 0, 0.15))
	draw_circle(at, r + 3, Style.PAPER)
	draw_circle(at, r, bg)
	match kind:
		"tray":
			draw_string(Style.font_bold, at + Vector2(-r, 9), str(int(badge.get("tray", 0)) + 1), HORIZONTAL_ALIGNMENT_CENTER, r * 2, 26, Color.WHITE)
		"counter":
			for k in 3:
				draw_rect(Rect2(at + Vector2(-12 + k * 9, -4), Vector2(6, 8)), Color.WHITE)
			draw_line(at + Vector2(-14, 6), at + Vector2(14, 6), Color.WHITE, 3)
		"fresh":
			# "wait" mark: a small clock face
			draw_arc(at, 11, 0, TAU, 16, Color.WHITE, 3, true)
			draw_line(at, at + Vector2(0, -7), Color.WHITE, 3, true)
			draw_line(at, at + Vector2(5, 3), Color.WHITE, 3, true)
		"full":
			draw_line(at + Vector2(-8, -8), at + Vector2(8, 8), Color.WHITE, 4, true)
			draw_line(at + Vector2(8, -8), at + Vector2(-8, 8), Color.WHITE, 4, true)

## Straps across the crate and a padlock tag with the deliveries remaining.
func _draw_lock(off: Vector2, w: float) -> void:
	draw_rect(Rect2(Vector2(4, 0) + off, Vector2(w - 8, size.y - 4)), Color(Style.CREAM_DEEP, 0.45))
	var strap := Color("7c5034")
	for y in [size.y * 0.3, size.y * 0.72]:
		draw_line(Vector2(2, y - 18) + off, Vector2(w - 2, y + 18) + off, strap, 12, true)
		draw_line(Vector2(2, y - 18) + off, Vector2(w - 2, y + 18) + off, Color(Style.WOOD_LIGHT, 0.6), 3, true)
	var c := Vector2(w / 2, size.y * 0.5) + off
	var tag := StyleBoxFlat.new()
	tag.bg_color = Style.PAPER
	tag.set_corner_radius_all(16)
	tag.border_color = Style.WOOD_DARK
	tag.set_border_width_all(4)
	tag.shadow_color = Style.SHADOW
	tag.shadow_size = 6
	var tw := minf(w - 16, 104.0)
	draw_style_box(tag, Rect2(c - Vector2(tw / 2, 44), Vector2(tw, 88)))
	var lc := c + Vector2(-tw * 0.2, -4)
	draw_arc(lc + Vector2(0, -8), 10, PI, TAU, 12, Style.INK, 5, true)
	draw_rect(Rect2(lc + Vector2(-14, -8), Vector2(28, 24)), Style.INK)
	draw_string(Style.font_bold, c + Vector2(0, 14), str(lock_left), HORIZONTAL_ALIGNMENT_LEFT, -1, 38, Style.INK)
	draw_string(Style.font_regular, c + Vector2(-tw / 2, 38), Loc.t("lock_orders_short"), HORIZONTAL_ALIGNMENT_CENTER, tw, 17, Style.INK_SOFT)
