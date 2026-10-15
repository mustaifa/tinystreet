class_name CrateView
extends Control
## One delivery crate. The FRONT item (bottom, large) is the only selectable
## one; every item behind it is drawn above in order, so the full contents are
## always visible. Emits press/tap; the board decides what happens.

signal pressed_down(index: int)
signal released(index: int, inside: bool)

var index := 0
var items: PackedInt32Array = PackedInt32Array()   # remaining, [0] = front
var highlight := false        # hint / tutorial ring
var hide_front := false       # during pick animation start
var dim := false
var _shake := 0.0
var _pulse := 0.0
var _down := false

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	resized.connect(queue_redraw)

func set_items(a: PackedInt32Array) -> void:
	items = a
	queue_redraw()

func front_size() -> float:
	return minf(size.x * 0.86, 120.0)

func back_size() -> float:
	return front_size() * 0.62

func front_center() -> Vector2:
	return Vector2(size.x / 2, size.y - front_size() * 0.5 - 18)

func front_global_center() -> Vector2:
	return get_global_transform() * front_center()

func shake() -> void:
	if App.reduced_motion():
		return
	var tw := create_tween()
	tw.tween_method(func(v): _shake = v; queue_redraw(), 1.0, 0.0, 0.32)

func _process(delta: float) -> void:
	if highlight:
		_pulse = fmod(_pulse + delta * (0.0 if App.reduced_motion() else 1.4), 1.0)
		queue_redraw()

func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_down = true
			pressed_down.emit(index)
			accept_event()
		elif _down:
			_down = false
			released.emit(index, Rect2(Vector2.ZERO, size).has_point(e.position))
			accept_event()

func _notification(what: int) -> void:
	if what == NOTIFICATION_MOUSE_EXIT and _down:
		pass # keep preview until release; release outside cancels

func _draw() -> void:
	var off := Vector2(sin(_shake * 28.0) * 7.0 * _shake, 0)
	var w := size.x
	var fs := front_size()
	var bs := back_size()
	# crate body (warm wood) behind the stack
	var body := Rect2(Vector2(4, 0) + off, Vector2(w - 8, size.y - 4))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(Style.WOOD_LIGHT, 0.35)
	sb.set_corner_radius_all(20)
	sb.border_color = Color(Style.WOOD, 0.5)
	sb.set_border_width_all(2)
	draw_style_box(sb, body)
	# front tray
	var tray := Rect2(Vector2(4, size.y - fs - 34) + off, Vector2(w - 8, fs + 30))
	var tb := StyleBoxFlat.new()
	tb.bg_color = Style.WOOD if not items.is_empty() else Color(Style.WOOD, 0.35)
	tb.set_corner_radius_all(20)
	tb.shadow_color = Style.SHADOW
	tb.shadow_size = 6
	tb.shadow_offset = Vector2(0, 3)
	draw_style_box(tb, tray)
	for k in 2:
		var y := tray.position.y + 14 + k * (tray.size.y - 28)
		draw_line(Vector2(16, y) + off, Vector2(w - 16, y) + off, Color(Style.WOOD_DARK, 0.35), 2, true)
	if items.is_empty():
		var f := Style.font_regular
		draw_string(f, Vector2(0, tray.get_center().y + 10) + off, "—", HORIZONTAL_ALIGNMENT_CENTER, w, 34, Color(Style.PAPER, 0.8))
		return
	# Items behind the front, bottom-to-top = next-to-last. Every item is always
	# drawn: if the column is short, items shrink to fit instead of being cut.
	var behind := items.size() - 1
	var avail := tray.position.y - 6.0
	var step := bs * 0.86
	if behind > 0 and behind * step > avail:
		step = avail / behind
		bs = minf(bs, step / 0.86)
	var y0 := tray.position.y - step * 0.5 - 2
	for i in range(1, items.size()):
		var c := Vector2(w / 2, y0 - (i - 1) * step) + off
		var plate := StyleBoxFlat.new()
		plate.bg_color = Color(Style.PAPER, 0.85)
		plate.set_corner_radius_all(int(bs * 0.3))
		draw_style_box(plate, Rect2(c - Vector2(bs, bs) * 0.48, Vector2(bs, bs) * 0.96))
		ProductArt.draw(self, items[i], c, bs * 0.82, 0.55 if dim else 0.92)
	if not hide_front:
		var fc := front_center() + off
		if highlight:
			var r := fs * (0.6 + 0.06 * sin(_pulse * TAU))
			draw_arc(fc, r, 0, TAU, 40, Style.GOLD, 6, true)
		var plate2 := StyleBoxFlat.new()
		plate2.bg_color = Style.PAPER
		plate2.set_corner_radius_all(int(fs * 0.28))
		draw_style_box(plate2, Rect2(fc - Vector2(fs, fs) * 0.5, Vector2(fs, fs)))
		ProductArt.draw(self, items[0], fc, fs * 0.86, 0.6 if dim else 1.0)
