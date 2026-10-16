class_name RushRun
extends RefCounted
## Café Rush: an OPTIONAL challenge of three validated puzzles from the daily
## pool, played back to back. The clock only counts up; there is no fail
## state. The result is a personal best (stats.rush_best_ms); no tokens are
## paid per run (the "rush_finish" achievement pays once). The run lives in
## memory only: leaving the run or closing the app abandons it.

const LENGTH := 3

var ids: Array = []
var index := 0
var elapsed_ms := 0.0
var finished := false

## Picks LENGTH distinct puzzles. `seed_value` makes runs reproducible in tests.
static func create(pool: Array, seed_value: int) -> RushRun:
	var r := RushRun.new()
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var idx: Array = range(pool.size())
	while r.ids.size() < mini(LENGTH, pool.size()):
		r.ids.append(pool[idx.pop_at(rng.randi_range(0, idx.size() - 1))].id)
	return r

func current_id() -> String:
	return ids[index] if index < ids.size() else ""

func tick(delta: float) -> void:
	if not finished:
		elapsed_ms += delta * 1000.0

## Advances after a win. Returns true when the whole run is complete.
func advance() -> bool:
	index += 1
	if index >= ids.size():
		finished = true
	return finished

## Records the finished run once. Returns true for a new personal best.
func record(data: Dictionary) -> bool:
	if not finished:
		return false
	data.stats.rush_done = int(data.stats.rush_done) + 1
	var best := int(data.stats.rush_best_ms)
	var t := int(elapsed_ms)
	if best <= 0 or t < best:
		data.stats.rush_best_ms = t
		return true
	return false

static func fmt_time(ms: int) -> String:
	var s := int(ms / 1000)
	return "%d:%02d" % [s / 60, s % 60]
