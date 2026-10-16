class_name Story
extends RefCounted
## Lightweight story beats: one to three short lines from the cast, shown as
## a skippable speech bubble. Each beat plays once (data.story.seen) and can
## be replayed from the Journal. All text is localised ("st_*" keys).
##
## Cast: Mira (baker next door, mentor), Theo (sleepy student, coffee),
## Mr. Basil (retired postman, tea). The player is the café's new owner.

const BEATS := {
	"intro": [["mira", "st_intro_1"], ["mira", "st_intro_2"]],
	"lvl:c004": [["theo", "st_theo_1"], ["mira", "st_theo_2"]],
	"lvl:f01": [["theo", "st_fresh_1"]],
	"lvl:c008": [["mira", "st_ch2_1"]],
	"lvl:c016": [["basil", "st_basil_1"], ["basil", "st_basil_2"]],
	"lvl:b01": [["mira", "st_bag_1"]],
	"lvl:c031": [["basil", "st_two_1"]],
	"lvl:k01": [["basil", "st_lock_1"], ["theo", "st_lock_2"]],
	"lvl:c053": [["mira", "st_ch6_1"], ["theo", "st_ch6_2"]],
	"step:clean": [["mira", "st_step_clean"]],
	"step:walls": [["theo", "st_step_walls"]],
	"step:floor": [["basil", "st_step_floor"]],
	"step:counter": [["mira", "st_step_counter"], ["theo", "st_step_counter_2"]],
	"step:lights": [["basil", "st_step_lights"]],
	"step:seating": [["theo", "st_step_seating"]],
	"step:plants": [["mira", "st_step_plants"]],
	"step:opening": [["basil", "st_step_opening"], ["mira", "st_step_opening_2"], ["theo", "st_step_opening_3"]],
}

## Order for the Journal's "replay story" list.
const JOURNAL := ["intro", "lvl:c004", "step:clean", "lvl:f01", "step:walls", "lvl:c008", "step:floor",
	"lvl:c016", "step:counter", "lvl:b01", "step:lights", "lvl:c031", "step:seating", "lvl:k01",
	"step:plants", "lvl:c053", "step:opening"]

static func has_beat(id: String) -> bool:
	return BEATS.has(id)

static func seen(data: Dictionary, id: String) -> bool:
	return data.story.seen.has(id)

static func mark_seen(data: Dictionary, id: String) -> void:
	data.story.seen[id] = true

## Shows a beat once. `done` runs when the bubble closes (or immediately if
## there is nothing to show).
static func play(id: String, done: Callable = Callable(), force: bool = false) -> bool:
	if not BEATS.has(id) or (seen(App.data, id) and not force) or App.main == null:
		if done.is_valid():
			done.call()
		return false
	mark_seen(App.data, id)
	App.save_soon()
	App.main.show_overlay(SpeechBubble.make(BEATS[id], done))
	return true

static func level_start(level_id: String) -> void:
	play("lvl:" + level_id)

static func after_step(step_id: String, done: Callable = Callable()) -> void:
	play("step:" + step_id, done)
