class_name DeliverySession
extends RefCounted
## One attempt at a Delivery Logic level: the position plus undo/redo
## history (§3.3). History entries are compact snapshots, so undo restores
## courier, crates and both counters exactly. Saved with to_dict(); a saved
## attempt is resumed only against the same layout (content hash).

const HISTORY_CAP := 3000

var level: DeliveryLevel
var state: DeliveryState
var history: Array[PackedInt32Array] = []
var redo_stack: Array[PackedInt32Array] = []
var hints_used := 0      # this attempt (removes the unassisted badge)
var undos := 0           # statistics only

static func start(l: DeliveryLevel) -> DeliverySession:
	var ps := DeliverySession.new()
	ps.level = l
	ps.state = DeliveryRules.start_state(l)
	return ps

func is_won() -> bool:
	return DeliveryRules.is_won(level, state)

## One step or push. Returns DeliveryRules.INVALID / STEP / PUSH.
func act(d: int) -> int:
	if is_won():
		return DeliveryRules.INVALID
	var before := state.snapshot()
	var r := DeliveryRules.move(level, state, d)
	if r != DeliveryRules.INVALID:
		_record(before)
	return r

## Tap-to-walk; one undo unit. Returns steps walked (0 = invalid).
func walk_to(cell: int) -> int:
	if is_won():
		return 0
	var before := state.snapshot()
	var k := DeliveryRules.walk(level, state, cell)
	if k > 0:
		_record(before)
	return k

func _record(before: PackedInt32Array) -> void:
	history.append(before)
	if history.size() > HISTORY_CAP:
		history.pop_front()
	redo_stack.clear()

func can_undo() -> bool:
	return not history.is_empty() and not is_won()

func can_redo() -> bool:
	return not redo_stack.is_empty() and not is_won()

func undo() -> bool:
	if not can_undo():
		return false
	redo_stack.append(state.snapshot())
	state = DeliveryState.from_snapshot(level, history.pop_back())
	undos += 1
	return true

func redo() -> bool:
	if not can_redo():
		return false
	history.append(state.snapshot())
	state = DeliveryState.from_snapshot(level, redo_stack.pop_back())
	return true

func restart() -> void:
	state = DeliveryRules.start_state(level)
	history.clear()
	redo_stack.clear()

# --------------------------------------------------------------- persistence

func to_dict() -> Dictionary:
	var h: Array = []
	for a in history:
		h.append(Array(a))
	var r: Array = []
	for a in redo_stack:
		r.append(Array(a))
	return {"hash": level.content_hash(), "state": Array(state.snapshot()), "history": h, "redo": r,
		"hints": hints_used, "undos": undos}

## Rebuilds a saved attempt. Returns null when the save does not fit this
## level (changed layout, wrong crate count, overlapping or off-floor
## objects), so the caller starts fresh instead of loading a broken board.
static func restore(l: DeliveryLevel, d: Dictionary) -> DeliverySession:
	if str(d.get("hash", "")) != l.content_hash():
		return null
	var st := _snap(l, d.get("state"))
	if st == null:
		return null
	var ps := DeliverySession.new()
	ps.level = l
	ps.state = st
	for key in ["history", "redo"]:
		var arr = d.get(key, [])
		if not arr is Array:
			return null
		for a in arr:
			if _snap(l, a) == null:
				return null
			var packed := PackedInt32Array(a)
			if key == "history":
				ps.history.append(packed)
			else:
				ps.redo_stack.append(packed)
	ps.hints_used = maxi(0, int(d.get("hints", 0)))
	ps.undos = maxi(0, int(d.get("undos", 0)))
	return ps

## A snapshot is usable if it has the right length and puts every object on
## its own floor cell.
static func _snap(l: DeliveryLevel, a) -> DeliveryState:
	if not a is Array or a.size() != 3 + l.crate_count():
		return null
	var seen := {}
	for idx in a.size():
		if typeof(a[idx]) not in [TYPE_INT, TYPE_FLOAT]:
			return null
		if idx == 1 or idx == 2:
			if int(a[idx]) < 0:
				return null
			continue
		var c := int(a[idx])
		if c >= l.n or not l.floor_at(c) or seen.has(c):
			return null
		seen[c] = true
	return DeliveryState.from_snapshot(l, PackedInt32Array(a))
