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

enum Dest { NONE, TRAY, COUNTER }
## Why a tap is illegal (for feedback). NONE when the tap is legal.
enum Block { NONE, EMPTY, LOCKED, FRESH, FULL }

const EV_PICK := "pick"                 # {crate, product}
const EV_TO_TRAY := "to_tray"           # {crate, product, tray}
const EV_TO_COUNTER := "to_counter"     # {crate, product, slot}
const EV_COUNTER_TO_TRAY := "counter_to_tray" # {slot, product, tray}
const EV_STAGE := "stage_advance"       # {tray, order, stage}
const EV_DELIVER := "order_complete"    # {tray, order}
const EV_ARRIVE := "order_arrive"       # {tray, order}
const EV_REVEAL := "reveal"             # {crate, product} a bagged item became the front
const EV_UNLOCK := "crate_unlock"       # {crate}

## Which tray (or counter) a tap on `crate` would send its product to.
## Returns {dest: Dest, tray: int, slot: int, product: int, block: Block, fresh: bool}.
static func preview(s: PuzzleState, crate: int) -> Dictionary:
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

static func is_lost(s: PuzzleState) -> bool:
	return not is_won(s) and legal_moves(s).is_empty()

## Applies a tap. Mutates `s` and returns the ordered event list for
## presentation, or an empty array if the move was illegal (state unchanged).
static func apply_move(s: PuzzleState, crate: int) -> Array:
	var pv := preview(s, crate)
	if pv.dest == Dest.NONE:
		return []
	var p: int = pv.product
	var events: Array = [{"type": EV_PICK, "crate": crate, "product": p, "fresh": pv.fresh}]
	s.crate_pos[crate] += 1
	s.moves += 1
	if s.crate_remaining(crate) > 0 and (s.level.flag(crate, s.crate_pos[crate]) & LevelDef.BAG) != 0:
		events.append({"type": EV_REVEAL, "crate": crate, "product": s.front(crate)})
	if pv.dest == Dest.TRAY:
		s.tray_fill[pv.tray][p] += 1
		events.append({"type": EV_TO_TRAY, "crate": crate, "product": p, "tray": pv.tray})
	else:
		s.counter[pv.slot] = p
		s.peak_counter = maxi(s.peak_counter, s.counter_used())
		events.append({"type": EV_TO_COUNTER, "crate": crate, "product": p, "slot": pv.slot})
	resolve(s, events)
	return events

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
					s.completed += 1
					s.tray_stage[t] = 0
					s.tray_order[t] = -1
					events.append({"type": EV_DELIVER, "tray": t, "order": o})
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
				events.append({"type": EV_COUNTER_TO_TRAY, "slot": slot, "product": p, "tray": t})
				changed = true

## Adds a temporary counter slot (rewarded continuation). Not a move.
static func add_bonus_slot(s: PuzzleState) -> void:
	s.bonus_slots += 1
	s.counter.append(-1)
