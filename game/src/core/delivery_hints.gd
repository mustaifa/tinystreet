class_name DeliveryHints
extends RefCounted
## Hint content for Delivery Logic, derived only from the CURRENT position
## and a shortest-push solution from it (DeliverySolver). The screen turns
## the result into words; tests check it after moves, undo and restart.
##
## Tier 1 (idea) is authored per level; tiers 2 and 3 come from here:
##   {ok, crate, dir, away, wait_crate, pushes_left}
##   crate/dir    the next push of a shortest solution (tier 3)
##   away         that push moves the crate farther from its pads
##   wait_crate   an undelivered crate that looks closer to home but is not
##                the one to move now (or -1)
##   pushes_left  proved fewest pushes to finish from here

static func from_solution(l: DeliveryLevel, s: DeliveryState, pushes: Array) -> Dictionary:
	if pushes.is_empty():
		return {"ok": false}
	var first: Vector2i = pushes[0]
	var i := s.at[first.x]
	if i < 0:
		return {"ok": false}
	var sym := l.crate_sym[i]
	var pd := DeliveryRules.push_distance(l, sym)
	var to := l.nbr(first.x, first.y)
	var away := pd[to] > pd[first.x] or (DeliveryRules.on_match(l, s, i) and l.goal[to] != sym)
	var wait := -1
	if not away:
		var best_d := pd[first.x]
		for j in s.crates.size():
			if j == i or DeliveryRules.on_match(l, s, j) or l.crate_sym[j] == sym:
				continue
			var pj := DeliveryRules.push_distance(l, l.crate_sym[j])
			var dj := pj[s.crates[j]]
			if dj >= 0 and dj < best_d:
				best_d = dj
				wait = j
	return {"ok": true, "crate": i, "dir": first.y, "away": away, "wait_crate": wait, "pushes_left": pushes.size()}

## Blocking convenience for tests and tools.
static func compute(l: DeliveryLevel, s: DeliveryState, budget: int = 200000) -> Dictionary:
	var sv := DeliverySolver.solve(l, s, budget)
	if sv.status != DeliverySolver.SOLVED:
		return {"ok": false, "status": sv.status}
	var h := from_solution(l, s, sv.push_list)
	h["status"] = sv.status
	return h
