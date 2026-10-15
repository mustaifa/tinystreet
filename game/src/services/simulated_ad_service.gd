class_name SimulatedAdService
extends AdService
## DEVELOPMENT ONLY. Simulates a rewarded ad with a clearly labelled overlay
## ("SIMULATED TEST AD — no real advertising"). Lets QA exercise success,
## cancellation, no-fill and failure paths. Never used in release builds.

var next_outcome := ""          # tests can force "no_fill"/"failed"/"offline"
var auto_resolve := ""          # tests: "earn" or "cancel" resolves without UI
var _active := ""

func kind() -> String:
	return "simulated"

func is_rewarded_available() -> bool:
	return true

func show_rewarded(request_id: String, placement: String) -> void:
	if _active != "":
		rewarded_closed.emit.call_deferred(request_id, "failed")
		return
	if next_outcome != "":
		var o := next_outcome
		next_outcome = ""
		rewarded_closed.emit.call_deferred(request_id, o)
		return
	_active = request_id
	if auto_resolve != "":
		_finish.call_deferred(auto_resolve == "earn")
		return
	var ui := _overlay(placement)
	get_tree().root.add_child(ui)

func _finish(earned: bool) -> void:
	var id := _active
	_active = ""
	if earned:
		reward_earned.emit(id)
	rewarded_closed.emit(id, "completed" if earned else "cancelled")

func _overlay(placement: String) -> Node:
	var layer := CanvasLayer.new()
	layer.layer = 100
	var bg := ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.12, 0.96)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.custom_minimum_size = Vector2(560, 0)
	box.position = Vector2(-280, -220)
	box.add_theme_constant_override("separation", 24)
	bg.add_child(box)
	var lbl := Label.new()
	lbl.text = "SIMULATED TEST AD\nno real advertising\nplacement: %s" % placement
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.add_theme_color_override("font_color", Color.WHITE)
	box.add_child(lbl)
	var ok := Button.new()
	ok.text = "Finish ad (grant reward)"
	ok.custom_minimum_size = Vector2(0, 96)
	box.add_child(ok)
	var cancel := Button.new()
	cancel.text = "Close early (no reward)"
	cancel.theme_type_variation = "SecondaryButton"
	cancel.custom_minimum_size = Vector2(0, 96)
	box.add_child(cancel)
	ok.pressed.connect(func(): layer.queue_free(); _finish(true))
	cancel.pressed.connect(func(): layer.queue_free(); _finish(false))
	return layer
