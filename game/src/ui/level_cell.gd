class_name LevelCell
extends Button
## A level key, shared by the campaign map and the bakery. Drawn content sits
## on top of the shared tactile key styles. States:
##   completed  paper key, number and three stars (gold = earned)
##   current    teal key with a play mark (the next level to play)
##   locked     flat, faint number and a padlock (a tap explains the unlock)
##   mastered   a teal rosette on a completed key
## plus a "NEW" tag for levels that introduce a mechanic and a gold bell for
## special orders and the bell lesson. Shape and text carry every state.
var number := 1
var unlocked := true
var cleared := false
var current := false
var mastered := false
var is_new := false
var bell := false
var stars := 0


func apply_style() -> void:
	text = ""
	if current:
		theme_type_variation = "Button"
	elif cleared or unlocked:
		theme_type_variation = "TileButton"
	else:
		var flat := Style.box(Style.LINEN, 24, Style.PAPER_EDGE, 2, false)
		for s in ["normal", "hover", "pressed", "hover_pressed", "disabled"]:
			add_theme_stylebox_override(s, flat)
	if current and not App.reduced_motion():
		var tw := create_tween().set_loops(4)
		tw.tween_interval(0.9)
		tw.tween_callback(func(): pivot_offset = size / 2)
		tw.tween_property(self, "scale", Vector2(1.06, 1.06), 0.45).set_trans(Tween.TRANS_SINE)
		tw.tween_property(self, "scale", Vector2.ONE, 0.45).set_trans(Tween.TRANS_SINE)

func _draw() -> void:
	var pressed := is_pressed()
	var dy := 4.0 if pressed and unlocked else 0.0
	var w := size.x
	var h := size.y - (Style.EDGE if unlocked else 0)
	var ink := Color.WHITE if current else (Style.INK if unlocked else Style.INK_FAINT)
	var num_y := h * 0.5 + (2 if cleared else 12) + dy
	draw_string(Style.font_black, Vector2(0, num_y), str(number), HORIZONTAL_ALIGNMENT_CENTER, w, Style.fs(34), ink)
	if cleared:
		var sz := minf(26.0, (w - 20) / 3)
		var x0 := w / 2 - sz * 1.5
		for k in 3:
			Glyph.paint(self, "star" if k < stars else "star_empty",
				Rect2(Vector2(x0 + k * sz, h * 0.62 + dy), Vector2(sz, sz)), Style.GOLD if k < stars else Color(Style.INK_SOFT, 0.5))
	elif current:
		Glyph.paint(self, "play", Rect2(Vector2(w / 2 - 14, h * 0.64 + dy), Vector2(28, 28)), Color.WHITE)
	elif not unlocked:
		Glyph.paint(self, "lock", Rect2(Vector2(w / 2 - 15, h * 0.62), Vector2(30, 30)), Color(Style.INK_SOFT, 0.55))
	if mastered:
		Glyph.paint(self, "ribbon", Rect2(Vector2(w - 38, 2 + dy), Vector2(36, 36)), Style.TEAL)
	if bell:
		Glyph.paint(self, "bell", Rect2(Vector2(4, 4 + dy), Vector2(30, 30)), Style.GOLD_EDGE if not current else Style.GOLD_SOFT)
	if is_new:
		var tw := Style.font_bold.get_string_size(Loc.t("new_mark"), HORIZONTAL_ALIGNMENT_LEFT, -1, 16).x + 14
		var r := Rect2(Vector2(w - tw - 4, 4 + dy), Vector2(tw, 24))
		draw_style_box(Style.box(Style.GOLD, 12, Color.TRANSPARENT, 0, false), r)
		draw_string(Style.font_bold, Vector2(r.position.x, r.position.y + 18), Loc.t("new_mark"), HORIZONTAL_ALIGNMENT_CENTER, r.size.x, 16, Style.INK)
