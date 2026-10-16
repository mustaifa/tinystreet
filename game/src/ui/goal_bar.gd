class_name GoalBar
extends Control
## "Next restoration step" card: name, tokens owned vs cost, and a bar. When
## affordable, it says so; when the café is complete, it points to extras.

var text := ""
var have := 0
var need := 1
var affordable := false

static func make(data: Dictionary) -> GoalBar:
	var g := GoalBar.new()
	g.custom_minimum_size = Vector2(540, 92)
	g.refresh(data)
	return g

func refresh(data: Dictionary) -> void:
	var i := Restoration.next_index(data)
	have = int(data.tokens)
	if i < 0:
		text = Loc.t("cafe_complete_extras")
		need = 0
		affordable = false
	else:
		var st: Dictionary = Restoration.STEPS[i]
		need = int(st.cost)
		affordable = have >= need
		text = Loc.t("next_step", [Loc.t("step_" + str(st.id))])
	queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	resized.connect(queue_redraw)

func _draw() -> void:
	var sb := Style.box(Style.CREAM_DEEP if not affordable else Style.TERRA_SOFT, 20, Color.TRANSPARENT, 0, false)
	draw_style_box(sb, Rect2(Vector2.ZERO, size))
	var rtl := Loc.is_rtl()
	var f := Style.font_bold
	var fs := Style.fs(24)
	draw_string(f, Vector2(18, 34), text, HORIZONTAL_ALIGNMENT_RIGHT if rtl else HORIZONTAL_ALIGNMENT_LEFT, size.x - 36, fs, Style.INK)
	if need <= 0:
		return
	var bar := Rect2(18, 52, size.x - 150, 22)
	if rtl:
		bar.position.x = 132
	draw_style_box(Style.box(Color(Style.INK_SOFT, 0.18), 11, Color.TRANSPARENT, 0, false), bar)
	var k := clampf(float(have) / float(need), 0.0, 1.0)
	if k > 0.0:
		var fill := Rect2(bar.position, Vector2(maxf(22.0, bar.size.x * k), bar.size.y))
		if rtl:
			fill.position.x = bar.end.x - fill.size.x
		draw_style_box(Style.box(Style.TERRACOTTA if affordable else Style.GOLD, 11, Color.TRANSPARENT, 0, false), fill)
	var t := "%d / %d" % [mini(have, need), need] if not affordable else Loc.t("ready")
	var tx := bar.end.x + 12 if not rtl else 18.0
	draw_string(f, Vector2(tx, 72), t, HORIZONTAL_ALIGNMENT_LEFT, 120, Style.fs(24), Style.TERRACOTTA if affordable else Style.INK_SOFT)
