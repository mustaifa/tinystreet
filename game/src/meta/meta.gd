class_name Meta
extends RefCounted
## Lifetime statistics and the single entry point that turns a finished
## puzzle into meta progress (stats -> tasks -> achievements). Pure functions
## over the save dictionary, so they are unit-tested without the UI.

## Called once per won puzzle (campaign, daily or rush) with a summary:
## {kind, level, stars, moves, hints, undos, best_streak, peak, first_clear,
##  tokens (star tokens just granted), first_daily}.
## Returns {tokens, new_achievements, tasks_ready}.
static func on_level_won(data: Dictionary, def: LevelDef, summary: Dictionary) -> Dictionary:
	var st: Dictionary = data.stats
	st.wins = int(st.wins) + 1
	st.orders = int(st.orders) + def.orders.size()
	st.fresh = int(st.fresh) + def.count_flag(LevelDef.FRESH)
	st.bags = int(st.bags) + def.count_flag(LevelDef.BAG)
	var locked := 0
	for v in def.locks:
		if v > 0:
			locked += 1
	st.unlocks = int(st.unlocks) + locked
	var cast := Customers.cast_counts(def)
	for k in cast:
		st.cast[k] = int(st.cast.get(k, 0)) + int(cast[k])
	var stars := int(summary.get("stars", 0))
	if stars >= 3:
		st.three_star = int(st.three_star) + 1
	if int(summary.get("hints", 0)) == 0:
		st.no_hint_wins = int(st.no_hint_wins) + 1
	if int(summary.get("peak", 1)) == 0:
		st.tidy_wins = int(st.tidy_wins) + 1
	var bs := int(summary.get("best_streak", 0))
	st.best_streak = maxi(int(st.best_streak), bs)
	if bs >= 5:
		st.streak5_wins = int(st.streak5_wins) + 1
	st.stars_earned = int(st.stars_earned) + int(summary.get("tokens", 0))
	if bool(summary.get("first_daily", false)):
		st.dailies = int(st.dailies) + 1
	return {"tokens": int(summary.get("tokens", 0)), "new_achievements": Achievements.take_new(data),
		"tasks_ready": Tasks.ready_count(data)}

## Mechanics the player has met (from cleared campaign levels), used to keep
## café tasks completable.
static func seen_mechanics(data: Dictionary, prog: Progression) -> Array:
	var out: Array = []
	for l in prog.campaign:
		if Progression.is_cleared(data, l.id):
			for m in prog.def_for(l.id).mechanics():
				if not (m in out):
					out.append(m)
	return out
