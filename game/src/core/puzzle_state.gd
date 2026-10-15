class_name PuzzleState
extends RefCounted
## Complete mutable state of one puzzle attempt. Everything the rules need is
## here, so copying this object is a full-fidelity undo snapshot.

var level: LevelDef
var crate_pos: PackedInt32Array      # items already taken from each crate
var counter: PackedInt32Array        # slot -> product index, -1 = empty
var bonus_slots: int = 0             # temporary extra counter slots (rewarded continue)
var tray_order: PackedInt32Array     # tray -> order index into level.orders, -1 = empty
var tray_stage: PackedInt32Array     # tray -> current stage index
var tray_fill: Array = []            # tray -> PackedInt32Array(Products.COUNT) filled amounts
var next_order: int = 0              # index of the next queued order
var completed: int = 0               # orders fully delivered
var moves: int = 0
var peak_counter: int = 0            # highest simultaneous counter occupancy reached

static func create(def: LevelDef) -> PuzzleState:
	var s := PuzzleState.new()
	s.level = def
	s.crate_pos.resize(def.crates.size())
	s.counter.resize(def.counter_slots)
	s.counter.fill(-1)
	var t := mini(def.trays, 3)
	s.tray_order.resize(t)
	s.tray_order.fill(-1)
	s.tray_stage.resize(t)
	for i in t:
		var f := PackedInt32Array()
		f.resize(Products.COUNT)
		s.tray_fill.append(f)
	# Fill trays from the queue in tray order (left to right).
	for i in t:
		if s.next_order < def.orders.size():
			s.tray_order[i] = s.next_order
			s.next_order += 1
	return s

func copy() -> PuzzleState:
	var s := PuzzleState.new()
	s.level = level
	s.crate_pos = crate_pos.duplicate()
	s.counter = counter.duplicate()
	s.bonus_slots = bonus_slots
	s.tray_order = tray_order.duplicate()
	s.tray_stage = tray_stage.duplicate()
	for f in tray_fill:
		s.tray_fill.append(f.duplicate())
	s.next_order = next_order
	s.completed = completed
	s.moves = moves
	s.peak_counter = peak_counter
	return s

func front(crate: int) -> int:
	var c: PackedInt32Array = level.crates[crate]
	var p := crate_pos[crate]
	return c[p] if p < c.size() else -1

func crate_remaining(crate: int) -> int:
	return level.crates[crate].size() - crate_pos[crate]

func counter_used() -> int:
	var n := 0
	for v in counter:
		if v >= 0:
			n += 1
	return n

func counter_free() -> int:
	return counter.size() - counter_used()

## Remaining amount of product p the tray's current stage still needs.
func tray_needs(tray: int, p: int) -> int:
	var o := tray_order[tray]
	if o < 0:
		return 0
	var stage: PackedInt32Array = level.orders[o][tray_stage[tray]]
	return stage[p] - tray_fill[tray][p]

func tray_stage_complete(tray: int) -> bool:
	var o := tray_order[tray]
	if o < 0:
		return false
	var stage: PackedInt32Array = level.orders[o][tray_stage[tray]]
	var f: PackedInt32Array = tray_fill[tray]
	for i in Products.COUNT:
		if f[i] < stage[i]:
			return false
	return true

## Stable string key used by the solver's transposition table.
func key() -> String:
	return "%s|%s|%s|%s|%s|%d" % [crate_pos, counter, tray_order, tray_stage, tray_fill, next_order]
