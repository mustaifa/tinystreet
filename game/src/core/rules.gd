class_name Rules
extends RefCounted
## Deterministic puzzle rules. Pure functions over PuzzleState.
##
## ROUTING PRIORITY (documented in GAME_DESIGN.md):
##   1. A tapped product goes to the LEFTMOST active tray whose current stage
##      still needs it.
##   2. Otherwise it goes to the leftmost empty counter slot.
##   3. Otherwise the tap is illegal (gentle feedback, state unchanged).
## RESOLUTION (repeated until nothing changes):
##   a. Trays are checked left to right. A completed stage reveals the next
##      stage of that order; a completed final stage delivers the order and the
##      next queued order arrives in the SAME tray.
##   b. Counter slots are scanned left to right; each item moves to the leftmost
##      tray that needs it.
## Completion is evaluated before defeat. Defeat = not won AND no legal move.
##
## MECHANICS (v2, all optional per level):
##   FRESH item: may only go to a tray (step 1). If no tray needs it, the tap
##     is illegal; it never goes to the counter.
##   BAG item: purely informational. Its product is hidden until it becomes
##     the front item. Routing is unchanged (the rules always know contents).
##   LOCKED crate: illegal to tap until `completed >= locks[crate]`. The crate
##     opens during resolution, the moment the required delivery happens.
##   BELL (v3, on unless the level says "bell": false): the player may ring
##     one ticket's bell (a free action, not a move). While rung, that ticket
##     takes priority over the leftmost rule in step 1 and resolution b.
##     Ringing another ticket moves the bell; ringing the same one clears it;
##     delivering that order clears it. The bell never makes an illegal tap
##     legal (it only chooses between tickets that both need the item), so it
##     doesn't change win/loss detection.
##
##   BELL BUDGET (v4, "bell_budget": n): every ring (including clearing a
##     bell) uses one; once n are used, ringing is refused. Unlimited if absent.
##   ORDER SEQUENCE (v4, "sequence": [o1, o2, ...]): the listed orders must be
##     delivered in that relative order. A crate tap whose cascade would deliver
##     a listed order before an earlier listed one is refused (state
##     unchanged), exactly like any other illegal tap.
##
## SCORE TALLIES (v7): every item that reaches an order is counted on the
##   state as direct (crate -> order) or via the counter. Scoring derives
##   points from these and `completed`, so undo/redo/restore stay exact.
##
## ACTIONS: an int >= 0 taps that crate; an int < 0 rings tray (-a - 1).

enum Dest { NONE, TRAY, COUNTER }
## Why a tap is illegal (for feedback). NONE when the tap is legal.
enum Block { NONE, EMPTY, LOCKED, FRESH, FULL, SEQUENCE }

const EV_PICK := "pick"                 # {crate, product}
const EV_TO_TRAY := "to_tray"           # {crate, product, tray}
const EV_TO_COUNTER := "to_counter"     # {crate, product, slot}
const EV_COUNTER_TO_TRAY := "counter_to_tray" # {slot, product, tray}
const EV_STAGE := "stage_advance"       # {tray, order, stage}
const EV_DELIVER := "order_complete"    # {tray, order}
const EV_ARRIVE := "order_arrive"       # {tray, order}
const EV_REVEAL := "reveal"             # {crate, product} a bagged item became the front
const EV_UNLOCK := "crate_unlock"       # {crate}
const EV_BELL := "bell"                 # {tray, on}

static func bell_action(tray: int) -> int:
	return -tray - 1

static func action_tray(a: int) -> int:
	return -a - 1 if a < 0 else -1

## Applies a crate tap (a >= 0) or a bell ring (a < 0). [] if illegal.
static func apply_action(s: PuzzleState, a: int) -> Array:
	return apply_move(s, a) if a >= 0 else ring(s, action_tray(a))

static func can_ring(s: PuzzleState, tray: int) -> bool:
	return s.level.allow_bell and tray >= 0 and tray < s.tray_order.size() and s.tray_order[tray] >= 0 \
		and rings_left(s) != 0

## Rings still allowed: -1 = unlimited.
static func rings_left(s: PuzzleState) -> int:
	return -1 if s.level.bell_budget < 0 else maxi(0, s.level.bell_budget - s.rings_used)

## Rings (or clears) a ticket's bell. Not a move: `moves` doesn't change.
static func ring(s: PuzzleState, tray: int) -> Array:
	if not can_ring(s, tray):
		return []
	s.pin = -1 if s.pin == tray else tray
	s.rings_used += 1
	return [{"type": EV_BELL, "tray": tray, "on": s.pin == tray}]

## Which tray (or counter) a tap on `crate` would send its product to.
## Returns {dest: Dest, tray: int, slot: int, product: int, block: Block, fresh: bool}.
## On sequence levels a legal preview also carries the simulated result
## ("after", "events") so applying it does not run the cascade again.
static func preview(s: PuzzleState, crate: int) -> Dictionary:
	var r := _route(s, crate)
	if r.dest != Dest.NONE and not s.level.sequence.is_empty():
		# The tap is only legal if its whole cascade respects the sequence.
		var sim := s.copy()
		var ev: Array = []
		_apply_routed(sim, crate, r, ev)
		if sim.violation:
			r.dest = Dest.NONE
			r.block = Block.SEQUENCE
		else:
			r["after"] = sim
			r["events"] = ev
	return r

## Where a tap would go, ignoring the order-sequence constraint.
static func _route(s: PuzzleState, crate: int) -> Dictionary:
	var r := {"dest": Dest.NONE, "tray": -1, "slot": -1, "product": -1, "block": Block.EMPTY, "fresh": false}
	if crate < 0 or crate >= s.crate_pos.size():
		return r
	var p := s.front(crate)
	r.product = p
	if p < 0:
		return r
	r.fresh = is_fresh_front(s, crate)
	if is_locked(s, crate):
		r.block = Block.LOCKED
		return r
	var t := first_tray_needing(s, p)
	if t >= 0:
		r.dest = Dest.TRAY
		r.tray = t
		r.block = Block.NONE
		return r
	if r.fresh:
		r.block = Block.FRESH
		return r
	var slot := s.counter.find(-1)
	if slot >= 0:
		r.dest = Dest.COUNTER
		r.slot = slot
		r.block = Block.NONE
	else:
		r.block = Block.FULL
	return r

static func is_locked(s: PuzzleState, crate: int) -> bool:
	return s.completed < s.level.locks[crate]

## Deliveries still needed before `crate` opens (0 if open).
static func lock_remaining(s: PuzzleState, crate: int) -> int:
	return maxi(0, s.level.locks[crate] - s.completed)

static func is_fresh_front(s: PuzzleState, crate: int) -> bool:
	return s.crate_remaining(crate) > 0 and (s.level.flag(crate, s.crate_pos[crate]) & LevelDef.FRESH) != 0

## Item k (absolute index in the crate) as the player may see it:
## its product, or -1 while it is still bagged behind the front.
static func visible_product(s: PuzzleState, crate: int, k: int) -> int:
	var c: PackedInt32Array = s.level.crates[crate]
	if k < s.crate_pos[crate] or k >= c.size():
		return -1
	if k > s.crate_pos[crate] and (s.level.flag(crate, k) & LevelDef.BAG) != 0:
		return -1
	return c[k]

static func first_tray_needing(s: PuzzleState, p: int) -> int:
	if s.pin >= 0 and s.tray_needs(s.pin, p) > 0:
		return s.pin
	for t in s.tray_order.size():
		if s.tray_needs(t, p) > 0:
			return t
	return -1

static func is_legal(s: PuzzleState, crate: int) -> bool:
	return preview(s, crate).dest != Dest.NONE

static func legal_moves(s: PuzzleState) -> PackedInt32Array:
	var out := PackedInt32Array()
	for c in s.crate_pos.size():
		if is_legal(s, c):
			out.append(c)
	return out

static func is_won(s: PuzzleState) -> bool:
	return s.completed >= s.level.orders.size()

## Lost = not won, no legal tap, and no single bell ring that would create
## one. (Without a sequence, ringing never changes legality; with one, a ring
## can redirect a cascade away from an out-of-sequence delivery.)
static func is_lost(s: PuzzleState) -> bool:
	if is_won(s) or not legal_moves(s).is_empty():
		return false
	if s.level.sequence.is_empty():
		return true
	for t in s.tray_order.size():
		if can_ring(s, t):
			var b := s.copy()
			ring(b, t)
			if not legal_moves(b).is_empty():
				return false
	return true

## Applies a tap. Mutates `s` and returns the ordered event list for
## presentation, or an empty array if the move was illegal (state unchanged).
static func apply_move(s: PuzzleState, crate: int) -> Array:
	return apply_previewed(s, crate, preview(s, crate))

## Applies a tap whose preview(s, crate) the caller already has.
static func apply_previewed(s: PuzzleState, crate: int, pv: Dictionary) -> Array:
	if pv.dest == Dest.NONE:
		return []
	if pv.has("after"):
		s.assign((pv.after as PuzzleState).copy())
		var ev: Array = pv.events
		return ev.duplicate(true)
	var events: Array = []
	_apply_routed(s, crate, pv, events)
	return events

## Performs a routed tap (no legality re-check) and resolves the board.
static func _apply_routed(s: PuzzleState, crate: int, pv: Dictionary, events: Array) -> void:
	var p: int = pv.product
	events.append({"type": EV_PICK, "crate": crate, "product": p, "fresh": pv.fresh})
	s.crate_pos[crate] += 1
	s.moves += 1
	if s.crate_remaining(crate) > 0 and (s.level.flag(crate, s.crate_pos[crate]) & LevelDef.BAG) != 0:
		events.append({"type": EV_REVEAL, "crate": crate, "product": s.front(crate)})
	if pv.dest == Dest.TRAY:
		s.tray_fill[pv.tray][p] += 1
		s.served_direct += 1
		events.append({"type": EV_TO_TRAY, "crate": crate, "product": p, "tray": pv.tray})
	else:
		s.counter[pv.slot] = p
		s.peak_counter = maxi(s.peak_counter, s.counter_used())
		events.append({"type": EV_TO_COUNTER, "crate": crate, "product": p, "slot": pv.slot})
	resolve(s, events)

## Runs automatic effects until the board is stable.
static func resolve(s: PuzzleState, events: Array) -> void:
	var changed := true
	var guard := 0
	while changed:
		guard += 1
		assert(guard < 10000, "resolve did not converge")
		changed = false
		# a. stages and deliveries
		for t in s.tray_order.size():
			if s.tray_stage_complete(t):
				changed = true
				var o := s.tray_order[t]
				s.tray_fill[t].fill(0)
				if s.tray_stage[t] + 1 < s.level.orders[o].size():
					s.tray_stage[t] += 1
					events.append({"type": EV_STAGE, "tray": t, "order": o, "stage": s.tray_stage[t]})
				else:
					if not _sequence_allows(s, o):
						s.violation = true
					s.completed += 1
					s.tray_stage[t] = 0
					s.tray_order[t] = -1
					events.append({"type": EV_DELIVER, "tray": t, "order": o})
					if s.pin == t:
						s.pin = -1
						events.append({"type": EV_BELL, "tray": t, "on": false})
					for c in s.level.locks.size():
						if s.level.locks[c] == s.completed:
							events.append({"type": EV_UNLOCK, "crate": c})
					if s.next_order < s.level.orders.size():
						s.tray_order[t] = s.next_order
						s.next_order += 1
						events.append({"type": EV_ARRIVE, "tray": t, "order": s.tray_order[t]})
		# b. counter auto-fill
		for slot in s.counter.size():
			var p := s.counter[slot]
			if p < 0:
				continue
			var t := first_tray_needing(s, p)
			if t >= 0:
				s.counter[slot] = -1
				s.tray_fill[t][p] += 1
				s.served_counter += 1
				events.append({"type": EV_COUNTER_TO_TRAY, "slot": slot, "product": p, "tray": t})
				changed = true

## Adds a temporary counter slot (rewarded continuation). Not a move.
static func add_bonus_slot(s: PuzzleState) -> void:
	s.bonus_slots += 1
	s.counter.append(-1)

## v4: may order o be delivered now? Every order listed before it in
## level.sequence must already be delivered.
static func _sequence_allows(s: PuzzleState, o: int) -> bool:
	var seq := s.level.sequence
	var i := seq.find(o)
	if i <= 0:
		return true
	for k in i:
		if not s.delivered(seq[k]):
			return false
	return true

## v4: index into level.sequence of the next order still to deliver, or -1.
static func sequence_next(s: PuzzleState) -> int:
	for k in s.level.sequence.size():
		if not s.delivered(s.level.sequence[k]):
			return k
	return -1
