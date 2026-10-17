class_name DeliveryState
extends RefCounted
## Mutable position of one Delivery Logic attempt: courier, crates and the
## two counters. Changed only through DeliveryRules.

var player := -1
var crates := PackedInt32Array()   # cell of crate i (symbol: level.crate_sym[i])
var at := PackedInt32Array()       # crate index on each cell, or -1
var steps := 0
var pushes := 0

static func make(level: DeliveryLevel, p: int, cells: PackedInt32Array) -> DeliveryState:
	var s := DeliveryState.new()
	s.player = p
	s.crates = cells.duplicate()
	s.at.resize(level.n)
	s.at.fill(-1)
	for i in cells.size():
		s.at[cells[i]] = i
	return s

func copy() -> DeliveryState:
	var s := DeliveryState.new()
	s.player = player
	s.crates = crates.duplicate()
	s.at = at.duplicate()
	s.steps = steps
	s.pushes = pushes
	return s

## Compact snapshot for undo history and saves: [player, steps, pushes, crates...].
func snapshot() -> PackedInt32Array:
	var a := PackedInt32Array([player, steps, pushes])
	a.append_array(crates)
	return a

static func from_snapshot(level: DeliveryLevel, a: PackedInt32Array) -> DeliveryState:
	var s := make(level, a[0], a.slice(3))
	s.steps = a[1]
	s.pushes = a[2]
	return s

func equals(o: DeliveryState) -> bool:
	return player == o.player and crates == o.crates and steps == o.steps and pushes == o.pushes
