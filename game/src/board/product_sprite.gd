class_name ProductSprite
extends Control
## A single drawn product, used for flying transfer animations.

var product := 0
var art_scale := 1.0

func _init(p: int = 0, px: float = 80.0) -> void:
	product = p
	size = Vector2(px, px)
	pivot_offset = size / 2
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _draw() -> void:
	ProductArt.draw(self, product, size / 2, size.x * 0.92 * art_scale)
