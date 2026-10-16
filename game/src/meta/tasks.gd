class_name Tasks
extends RefCounted
## Café tasks: three small goals that rotate with the device's local date.
## Progress = growth of a lifetime counter since the tasks were assigned, so
## any play counts (campaign, replays, daily, rush). Rewards are claimed once
## per date and task through the wallet ledger ("task:<date>:<id>").
##
## LIMITATION (documented): the date comes from the device clock, which the
## player can change. Tasks are a relaxed personal goal, not a secure or
## competitive event; the worst case is a player granting themselves tokens.

const POOL := [
	{"id": "orders", "stat": "orders", "goal": 15, "reward": 2},
	{"id": "wins", "stat": "wins", "goal": 3, "reward": 2},
	{"id": "stars", "stat": "stars_earned", "goal": 5, "reward": 2},
	{"id": "three_star", "stat": "three_star", "goal": 2, "reward": 3},
	{"id": "theo", "stat": "cast.theo", "goal": 3, "reward": 2},
	{"id": "basil", "stat": "cast.basil", "goal": 3, "reward": 2},
	{"id": "mira", "stat": "cast.mira", "goal": 3, "reward": 2},
	{"id": "fresh", "stat": "fresh", "goal": 4, "reward": 2, "needs": "fresh"},
	{"id": "bags", "stat": "bags", "goal": 6, "reward": 2, "needs": "bag"},
	{"id": "no_hint", "stat": "no_hint_wins", "goal": 2, "reward": 2},
	{"id": "streak", "stat": "streak5_wins", "goal": 1, "reward": 2},
	{"id": "daily", "stat": "dailies", "goal": 1, "reward": 2},
]
const PER_DAY := 3

static func def(id: String) -> Dictionary:
	for t in POOL:
		if t.id == id:
			return t
	return {}

## Ensures today's tasks exist. Mechanic tasks are only offered once the
## player has reached that mechanic, so every offered task is completable.
static func refresh(data: Dictionary, today: String, seen_mechanics: Array) -> void:
	if str(data.tasks.date) == today and data.tasks.list.size() == PER_DAY:
		return
	var pool: Array = []
	for t in POOL:
		if not t.has("needs") or t.needs in seen_mechanics:
			pool.append(t.id)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash("tasks:" + today)
	var pick: Array = []
	while pick.size() < PER_DAY and not pool.is_empty():
		pick.append(pool.pop_at(rng.randi_range(0, pool.size() - 1)))
	var base := {}
	for id in pick:
		var st: String = def(id).stat
		base[id] = Achievements.value(data, st)
	data.tasks = {"date": today, "list": pick, "base": base}

static func progress(data: Dictionary, id: String) -> int:
	var t := def(id)
	if t.is_empty():
		return 0
	var now := Achievements.value(data, t.stat)
	return clampi(now - int(data.tasks.base.get(id, now)), 0, int(t.goal))

static func is_done(data: Dictionary, id: String) -> bool:
	return progress(data, id) >= int(def(id).goal)

static func key(data: Dictionary, id: String) -> String:
	return "task:%s:%s" % [data.tasks.date, id]

static func is_claimed(data: Dictionary, id: String) -> bool:
	return Wallet.has_grant(data, key(data, id))

static func claim(data: Dictionary, id: String) -> int:
	if not (id in data.tasks.list) or not is_done(data, id):
		return 0
	var r := int(def(id).reward)
	return r if Wallet.grant(data, key(data, id), r) else 0

static func ready_count(data: Dictionary) -> int:
	var n := 0
	for id in data.tasks.list:
		if is_done(data, id) and not is_claimed(data, id):
			n += 1
	return n
