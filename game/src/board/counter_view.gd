class_name CounterView
extends Control
## The holding counter. Calm amber warning when space runs low; no flashing.

var slots: PackedInt32Array = PackedInt32Array()
var base_slots := 4
var hidden_slots := {}     # slot -> true while an item is in flight to it
var preview_slot := -1     # destination preview while a crate is pressed
var gone_slots := {}       # slot -> product: items currently flying out

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func set_slots(s: PackedInt32Array, base: int) -> void:
	slots = s
	base_slots = base
	queue_redraw()

func slot_size() -> float:
	var n := maxi(1, slots.size())
	return minf(minf(112.0, size.y - 28), (size.x - 40 - (n - 1) * 12) / n)

func slot_center(i: int) -> Vector2:
	var n := slots.size()
	var s := slot_size()
	var total := n * s + (n - 1) * 12
	var x0 := (size.x - total) / 2 + s / 2
	var idx := (n - 1 - i) if Loc.is_rtl() else i
	return Vector2(x0 + idx * (s + 12), size.y / 2)

func slot_global_center(i: int) -> Vector2:
	return get_global_transform() * slot_center(i)

func free_count() -> int:
	var n := 0
	for v in slots:
		if v < 0:
			n += 1
	return n

func _draw() -> void:
	var r := Rect2(Vector2(0, 8), Vector2(size.x, size.y - 16))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Style.WOOD
	sb.set_corner_radius_all(24)
	sb.shadow_color = Style.SHADOW
	sb.shadow_size = 8
	sb.shadow_offset = Vector2(0, 4)
	var free := free_count()
	var low := free <= 1 and slots.size() > 1
	if low:
		sb.border_color = Style.WARN
		sb.set_border_width_all(5)
	if ArtSkin.draw_rect(self, "board.counter", r):
		if low:
			var warn := StyleBoxFlat.new()
			warn.draw_center = false
			warn.border_color = Style.WARN
			warn.set_border_width_all(5)
			warn.set_corner_radius_all(26)
			draw_style_box(warn, r.grow(2))
	else:
		draw_style_box(sb, r)
		draw_line(Vector2(18, r.position.y + 14), Vector2(size.x - 18, r.position.y + 14), Color(Style.WOOD_LIGHT, 0.6), 3, true)
	var s := slot_size()
	var skin_slot := ArtSkin.has("board.slot")
	for i in slots.size():
		var c := slot_center(i)
		var bonus := i >= base_slots
		if skin_slot:
			ArtSkin.draw_fit(self, "board.slot", c, s, 1.0)
			if i == preview_slot or bonus:
				draw_arc(c, s * 0.5, 0, TAU, 40, Style.TEAL, 5 if i == preview_slot else 3, true)
		var slot := StyleBoxFlat.new()
		slot.bg_color = Color(Style.CREAM, 0.95) if not bonus else Color(Style.TEAL_SOFT, 0.95)
		slot.set_corner_radius_all(int(s * 0.26))
		if i == preview_slot:
			slot.border_color = Style.TEAL
			slot.set_border_width_all(5)
		elif bonus:
			slot.border_color = Style.TEAL
			slot.set_border_width_all(3)
		if not skin_slot:
			draw_style_box(slot, Rect2(c - Vector2(s, s) / 2, Vector2(s, s)))
		var p := slots[i]
		if p >= 0 and not hidden_slots.has(i):
			ProductArt.draw(self, p, c, s * (0.9 if skin_slot else 0.84))
		elif gone_slots.has(i):
			pass
		elif bonus and p < 0:
			draw_string(Style.font_bold, c + Vector2(-s / 2, 10), "+1", HORIZONTAL_ALIGNMENT_CENTER, s, 28, Style.TEAL_DARK)
