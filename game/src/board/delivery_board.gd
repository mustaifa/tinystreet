class_name DeliveryBoard
extends Control
## The Delivery Logic board. Draws walls, floor, pads, crates and the courier
## from a DeliveryState, animates the latest change, and turns touch into
## intents: one swipe = one direction (at most one per gesture), a short tap
## = a walk target. Holds no rules (DeliveryRules decides everything).
##
## Never mirrored in RTL: directions on the board are spatial.
## Skin keys (docs/ART_PIPELINE.md), each with the vector art as fallback:
##   delivery.floor  delivery.wall  delivery.pad  delivery.crate  delivery.courier

signal swiped(dir: int)
signal tapped(cell: int)

const SWIPE_MIN := 36.0      # design px before a drag counts as a swipe
const TAP_MAX := 22.0        # a release closer than this to the press is a tap
const MAX_CELL := 108.0
const STEP_TIME := 0.085     # seconds per cell (scaled by App.dur)

const FLOOR_A := Color("f1e4cf")
const FLOOR_B := Color("eadbc2")
const FLOOR_EDGE := Color("dcc8a8")
const WALL_TOP := Color("9a6a4a")
const WALL_FACE := Color("6f4a33")
const WALL_LINE := Color("5a3a28")
const SYMBOL_COLORS := [Color("8a5a3c"), Color("d9a441"), Color("d6453d"), Color("2f8f83")]

var level: DeliveryLevel
var state: DeliveryState
var cs := 64.0
var origin := Vector2.ZERO
var facing := 2
var hint_crate := -1
var hint_dir := -1
var blocked: Array = []       # crate indices to outline in red

var _pv := Vector2.ZERO       # courier position shown (cell units)
var _cv: Array[Vector2] = []  # crate positions shown (cell units)
var _queue: Array = []        # pending [courier target, crate index, crate target]
var _seg_from_p := Vector2.ZERO
var _seg_from_c := Vector2.ZERO
var _seg: Array = []
var _seg_t := 1.0
var _bump := Vector2.ZERO
var _bump_t := 0.0
var _pop := {}                # crate index -> remaining pop time
var _press := false
var _press_pos := Vector2.ZERO
var _gesture_used := false
var _clock := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	resized.connect(_layout)

func setup(l: DeliveryLevel, s: DeliveryState) -> void:
	level = l
	set_state(s)

## Shows a position at once (load, undo, redo, restart).
func set_state(s: DeliveryState) -> void:
	state = s
	_queue.clear()
	_seg = []
	_seg_t = 1.0
	_pv = _cell_v(s.player)
	_cv.clear()
	for c in s.crates:
		_cv.append(_cell_v(c))
	_layout()
	queue_redraw()

## Animates one step or push that has already been applied to `s`.
func animate_move(s: DeliveryState, d: int, pushed: int) -> void:
	finish()
	state = s
	facing = d
	_queue.append([_cell_v(s.player), pushed, _cell_v(s.crates[pushed]) if pushed >= 0 else Vector2.ZERO])
	_next_segment()

## Animates a tap-walk along `cells` (already applied to `s`).
func animate_walk(s: DeliveryState, cells: PackedInt32Array, dirs: PackedInt32Array) -> void:
	finish()
	state = s
	for k in cells.size():
		_queue.append([_cell_v(cells[k]), -1, Vector2.ZERO, dirs[k]])
	_next_segment()

## Snaps every running animation to its end (before any new input).
func finish() -> void:
	_queue.clear()
	_seg = []
	_seg_t = 1.0
	if state:
		_pv = _cell_v(state.player)
		for i in state.crates.size():
			_cv[i] = _cell_v(state.crates[i])
	_bump_t = 0.0
	queue_redraw()

func is_animating() -> bool:
	return _seg_t < 1.0 or not _queue.is_empty()

## Invalid move: the courier leans toward `d` and back; state unchanged.
func bump(d: int) -> void:
	finish()
	facing = d
	_bump = Vector2(DeliveryRules.DELTA[d])
	_bump_t = App.dur(0.18) if not App.reduced_motion() else 0.0
	queue_redraw()

func pop_crate(i: int) -> void:
	if not App.reduced_motion():
		_pop[i] = 0.28

func _next_segment() -> void:
	if _queue.is_empty():
		_seg = []
		_seg_t = 1.0
		return
	_seg = _queue.pop_front()
	if _seg.size() > 3:
		facing = int(_seg[3])
	_seg_from_p = _pv
	_seg_from_c = _cv[int(_seg[1])] if int(_seg[1]) >= 0 else Vector2.ZERO
	_seg_t = 0.0 if not App.reduced_motion() else 1.0
	if _seg_t >= 1.0:
		_apply_segment(1.0)
		_next_segment()

func _apply_segment(t: float) -> void:
	var e := t * (2.0 - t)   # ease out
	_pv = _seg_from_p.lerp(_seg[0], e)
	if int(_seg[1]) >= 0:
		_cv[int(_seg[1])] = _seg_from_c.lerp(_seg[2], e)

func _process(delta: float) -> void:
	_clock += delta
	var dirty := hint_crate >= 0 or not blocked.is_empty()
	if not _seg.is_empty() and _seg_t < 1.0:
		_seg_t = minf(1.0, _seg_t + delta / maxf(0.001, App.dur(STEP_TIME)))
		_apply_segment(_seg_t)
		if _seg_t >= 1.0:
			_next_segment()
		dirty = true
	if _bump_t > 0.0:
		_bump_t = maxf(0.0, _bump_t - delta)
		dirty = true
	for k in _pop.keys():
		_pop[k] = float(_pop[k]) - delta
		if _pop[k] <= 0.0:
			_pop.erase(k)
		dirty = true
	if dirty:
		queue_redraw()

# --------------------------------------------------------------- geometry

func _cell_v(c: int) -> Vector2:
	return Vector2(c % level.w, c / level.w) if level else Vector2.ZERO

func _layout() -> void:
	if level == null:
		return
	cs = floorf(minf(MAX_CELL, minf(size.x / level.w, size.y / level.h)))
	origin = ((size - Vector2(level.w, level.h) * cs) / 2.0).floor()
	queue_redraw()

func cell_rect(c: int) -> Rect2:
	return Rect2(origin + _cell_v(c) * cs, Vector2(cs, cs))

## Centre of a cell in global coordinates (QA input, effects).
func cell_global_center(c: int) -> Vector2:
	return get_global_transform() * (origin + (_cell_v(c) + Vector2(0.5, 0.5)) * cs)

func cell_at(local: Vector2) -> int:
	var p := (local - origin) / cs
	if p.x < 0 or p.y < 0 or p.x >= level.w or p.y >= level.h:
		return -1
	return int(p.y) * level.w + int(p.x)

# --------------------------------------------------------------- input

func _gui_input(e: InputEvent) -> void:
	if level == null:
		return
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		if e.pressed:
			_press = true
			_press_pos = e.position
			_gesture_used = false
		else:
			if _press and not _gesture_used and e.position.distance_to(_press_pos) <= TAP_MAX:
				var c := cell_at(e.position)
				if c >= 0:
					tapped.emit(c)
			_press = false
		accept_event()
	elif e is InputEventMouseMotion and _press and not _gesture_used:
		var d: Vector2 = e.position - _press_pos
		if d.length() >= SWIPE_MIN:
			_gesture_used = true   # one gesture = at most one move
			if absf(d.x) > absf(d.y):
				swiped.emit(DeliveryRules.Dir.RIGHT if d.x > 0 else DeliveryRules.Dir.LEFT)
			else:
				swiped.emit(DeliveryRules.Dir.DOWN if d.y > 0 else DeliveryRules.Dir.UP)
		accept_event()

# --------------------------------------------------------------- drawing

func _draw() -> void:
	if level == null or state == null:
		return
	var n := level.n
	# floor and pads
	for c in n:
		if level.kind[c] != DeliveryLevel.FLOOR:
			continue
		var r := cell_rect(c)
		if not ArtSkin.draw_rect(self, "delivery.floor", r):
			var x := c % level.w
			var y := c / level.w
			draw_rect(r, FLOOR_A if (x + y) % 2 == 0 else FLOOR_B)
			draw_rect(Rect2(r.position, Vector2(r.size.x, 1.5)), Color(FLOOR_EDGE, 0.5))
		if level.goal[c] >= 0:
			_draw_pad(r, level.goal[c])
	# walls (a darker face where a wall meets floor below gives depth)
	for c in n:
		if level.kind[c] != DeliveryLevel.WALL:
			continue
		var r := cell_rect(c)
		if ArtSkin.draw_rect(self, "delivery.wall", r):
			continue
		draw_rect(r.grow(0.5), WALL_TOP)
		var below := level.nbr(c, DeliveryRules.Dir.DOWN)
		if below >= 0 and level.kind[below] == DeliveryLevel.FLOOR:
			draw_rect(Rect2(r.position + Vector2(0, r.size.y * 0.72), Vector2(r.size.x, r.size.y * 0.28 + 0.5)), WALL_FACE)
		draw_rect(Rect2(r.position + Vector2(cs * 0.08, cs * 0.12), Vector2(cs * 0.38, cs * 0.05)), Color(WALL_LINE, 0.35))
		draw_rect(Rect2(r.position + Vector2(cs * 0.54, cs * 0.42), Vector2(cs * 0.38, cs * 0.05)), Color(WALL_LINE, 0.35))
	# hint arrow under the crate layer's glow
	# crates
	for i in state.crates.size():
		_draw_crate(i)
	_draw_courier()
	if hint_crate >= 0 and hint_crate < _cv.size():
		_draw_hint_arrow(hint_crate, hint_dir)

func _sym_color(s: int) -> Color:
	return SYMBOL_COLORS[s]

func _draw_pad(r: Rect2, s: int) -> void:
	var inner := r.grow(-cs * 0.07)
	if ArtSkin.draw_rect(self, "delivery.pad", inner, Color(_sym_color(s), 1.0)):
		ProductArt.draw(self, DeliveryLevel.SYMBOL_PRODUCT[s], r.get_center(), cs * 0.5, 0.6)
		return
	# Round mats, so a pad never reads as a (square) crate: a soft disc, a
	# solid ring and a dashed inner ring in the symbol colour, faded art.
	var c := r.get_center()
	var col := _sym_color(s)
	draw_circle(c, cs * 0.4, Color(col, 0.16))
	draw_arc(c, cs * 0.4, 0, TAU, 40, Color(col, 0.9), maxf(2.0, cs * 0.05), true)
	var segs := 12
	for k in segs:
		var a0 := TAU * k / segs
		draw_arc(c, cs * 0.31, a0, a0 + TAU / segs * 0.55, 4, Color(col, 0.55), maxf(1.5, cs * 0.025), true)
	ProductArt.draw(self, DeliveryLevel.SYMBOL_PRODUCT[s], c, cs * 0.42, 0.6)

func _draw_crate(i: int) -> void:
	var s := level.crate_sym[i]
	var pos: Vector2 = _cv[i]
	var r := Rect2(origin + pos * cs, Vector2(cs, cs)).grow(-cs * 0.11)
	if _pop.has(i):
		r = r.grow(cs * 0.06 * sin(clampf(float(_pop[i]) / 0.28, 0.0, 1.0) * PI))
	var cell := state.crates[i]
	var settled := _seg_t >= 1.0 and _queue.is_empty()
	var on_goal := settled and level.goal[cell] >= 0
	var home := on_goal and level.goal[cell] == s
	# shadow
	draw_rect(Rect2(r.position + Vector2(cs * 0.03, cs * 0.06), r.size), Color(0.23, 0.14, 0.08, 0.18))
	if not ArtSkin.draw_rect(self, "delivery.crate", r):
		var sb := StyleBoxFlat.new()
		sb.bg_color = Style.WOOD_LIGHT
		sb.border_color = Style.TEAL if home else Style.WOOD_DARK
		sb.set_border_width_all(maxi(3, int(cs * (0.075 if home else 0.055))))
		sb.set_corner_radius_all(int(cs * 0.12))
		draw_style_box(sb, r)
		var pl := Color(Style.WOOD, 0.55)
		var lw := maxf(1.5, cs * 0.025)
		draw_line(r.position + Vector2(r.size.x * 0.12, r.size.y * 0.5), r.position + Vector2(r.size.x * 0.88, r.size.y * 0.5), pl, lw)
		draw_line(r.position + Vector2(r.size.x * 0.16, r.size.y * 0.16), r.position + Vector2(r.size.x * 0.84, r.size.y * 0.84), pl, lw)
	# symbol badge: paper disc ringed in the symbol colour, product art inside
	var cc := r.get_center()
	draw_circle(cc, cs * 0.25, Style.PAPER)
	draw_arc(cc, cs * 0.25, 0, TAU, 32, _sym_color(s), maxf(2.0, cs * 0.045), true)
	ProductArt.draw(self, DeliveryLevel.SYMBOL_PRODUCT[s], cc, cs * 0.4, 1.0)
	if home:
		var bc := r.position + Vector2(r.size.x - cs * 0.05, cs * 0.05)
		draw_circle(bc, cs * 0.13, Style.TEAL)
		Glyph.paint(self, "check", Rect2(bc - Vector2(cs * 0.11, cs * 0.11), Vector2(cs * 0.22, cs * 0.22)), Color.WHITE)
	elif on_goal:
		# wrong pad: the pad's own symbol peeks out at the corner
		var gs := level.goal[cell]
		var bc2 := r.position + Vector2(r.size.x - cs * 0.04, r.size.y - cs * 0.04)
		draw_circle(bc2, cs * 0.15, Style.PAPER)
		draw_arc(bc2, cs * 0.15, 0, TAU, 24, _sym_color(gs), maxf(2.0, cs * 0.04), true)
		ProductArt.draw(self, DeliveryLevel.SYMBOL_PRODUCT[gs], bc2, cs * 0.22, 1.0)
	if i in blocked:
		var pulse := 0.65 + 0.35 * sin(_clock * 5.0) if not App.reduced_motion() else 1.0
		var ob := StyleBoxFlat.new()
		ob.draw_center = false
		ob.border_color = Color(Style.DANGER, pulse)
		ob.set_border_width_all(maxi(3, int(cs * 0.07)))
		ob.set_corner_radius_all(int(cs * 0.16))
		draw_style_box(ob, r.grow(cs * 0.06))

func _draw_courier() -> void:
	var p := _pv
	if _bump_t > 0.0:
		var k := sin((1.0 - _bump_t / maxf(0.001, App.dur(0.18))) * PI)
		p += _bump * 0.16 * k
	var c := origin + (p + Vector2(0.5, 0.5)) * cs
	if ArtSkin.draw_fit(self, "delivery.courier", c, cs * 0.86):
		return
	var f := Vector2(DeliveryRules.DELTA[facing])
	draw_circle(c + Vector2(cs * 0.03, cs * 0.07), cs * 0.33, Color(0.23, 0.14, 0.08, 0.2))
	draw_circle(c, cs * 0.33, Style.TEAL_DARK)                          # shoulders / jacket
	draw_circle(c, cs * 0.29, Style.TEAL)
	draw_circle(c - f * cs * 0.02, cs * 0.2, Color("f0c8a0"))           # head
	# cap with a brim pointing where the courier faces
	draw_arc(c - f * cs * 0.02, cs * 0.2, f.angle() + PI * 0.55, f.angle() + PI * 1.45, 16, Style.TERRACOTTA, cs * 0.1, true)
	var brim := c + f * cs * 0.2
	draw_circle(brim, cs * 0.08, Style.CORAL_EDGE)
	# eyes look the same way
	var side := Vector2(-f.y, f.x)
	for k2 in [-1.0, 1.0]:
		draw_circle(c + f * cs * 0.07 + side * cs * 0.07 * k2, cs * 0.028, Style.INK)

func _draw_hint_arrow(i: int, d: int) -> void:
	var a := 0.75 + 0.25 * sin(_clock * 4.0) if not App.reduced_motion() else 1.0
	var c := origin + (_cv[i] + Vector2(0.5, 0.5)) * cs
	var f := Vector2(DeliveryRules.DELTA[d])
	var tip := c + f * cs * 0.95
	draw_line(c + f * cs * 0.32, tip - f * cs * 0.2, Color(Style.GOLD_EDGE, a), cs * 0.14, true)
	draw_line(c + f * cs * 0.32, tip - f * cs * 0.2, Color(Style.GOLD, a), cs * 0.09, true)
	var sd := Vector2(-f.y, f.x)
	var tri := PackedVector2Array([tip, tip - f * cs * 0.3 + sd * cs * 0.22, tip - f * cs * 0.3 - sd * cs * 0.22])
	draw_colored_polygon(tri, Color(Style.GOLD, a))
	draw_polyline(PackedVector2Array([tri[0], tri[1], tri[2], tri[0]]), Color(Style.GOLD_EDGE, a), maxf(2.0, cs * 0.03), true)
