class_name Achievements
extends RefCounted
## Achievement collection. Each one is a threshold on a lifetime counter in
## `data.stats` (or a derived value), so it unlocks from real play and can
## always be re-checked. The reward is claimed once via the wallet ledger
## ("ach:<id>"). Some unlock a cosmetic (see Restoration).

const LIST := [
	{"id": "first_steps", "stat": "wins", "goal": 1, "reward": 2},
	{"id": "regular", "stat": "wins", "goal": 15, "reward": 3},
	{"id": "dedicated", "stat": "wins", "goal": 50, "reward": 5},
	{"id": "star_collector", "stat": "@stars", "goal": 75, "reward": 4},
	{"id": "perfectionist", "stat": "three_star", "goal": 20, "reward": 5, "unlocks": "sign_gilded"},
	{"id": "hot_hands", "stat": "fresh", "goal": 25, "reward": 3},
	{"id": "unwrapped", "stat": "bags", "goal": 30, "reward": 3},
	{"id": "key_holder", "stat": "unlocks", "goal": 10, "reward": 3},
	{"id": "streaker", "stat": "best_streak", "goal": 8, "reward": 3},
	{"id": "own_steam", "stat": "no_hint_wins", "goal": 15, "reward": 3},
	{"id": "tidy", "stat": "tidy_wins", "goal": 5, "reward": 3},
	{"id": "theo_fan", "stat": "cast.theo", "goal": 20, "reward": 2},
	{"id": "basil_fan", "stat": "cast.basil", "goal": 20, "reward": 2},
	{"id": "mira_fan", "stat": "cast.mira", "goal": 20, "reward": 2},
	{"id": "regulars", "stat": "@fans", "goal": 3, "reward": 3, "unlocks": "extra_photos"},
	{"id": "first_restore", "stat": "@steps", "goal": 1, "reward": 2},
	{"id": "grand_opening", "stat": "@steps", "goal": 8, "reward": 5},
	{"id": "daily_three", "stat": "dailies", "goal": 3, "reward": 3},
	{"id": "rush_finish", "stat": "rush_done", "goal": 1, "reward": 3},
]

static func def(id: String) -> Dictionary:
	for a in LIST:
		if a.id == id:
			return a
	return {}

## Current value of a stat path. "@" values are derived from other state.
static func value(data: Dictionary, stat: String) -> int:
	match stat:
		"@stars":
			var n := 0
			for k in data.campaign.stars:
				n += int(data.campaign.stars[k])
			return n
		"@steps":
			return Restoration.steps(data)
		"@fans":
			var n2 := 0
			for f in ["theo_fan", "basil_fan", "mira_fan"]:
				if is_unlocked(data, f):
					n2 += 1
			return n2
	if stat.begins_with("cast."):
		return int(data.stats.cast.get(stat.substr(5), 0))
	return int(data.stats.get(stat, 0))

static func is_unlocked(data: Dictionary, id: String) -> bool:
	var a := def(id)
	return not a.is_empty() and value(data, a.stat) >= int(a.goal)

static func is_claimed(data: Dictionary, id: String) -> bool:
	return Wallet.has_grant(data, "ach:" + id)

## Grants the reward once. Returns tokens paid (0 if locked or already claimed).
static func claim(data: Dictionary, id: String) -> int:
	if not is_unlocked(data, id):
		return 0
	var r := int(def(id).reward)
	return r if Wallet.grant(data, "ach:" + id, r) else 0

static func unlocked_ids(data: Dictionary) -> Array:
	var out: Array = []
	for a in LIST:
		if is_unlocked(data, a.id):
			out.append(a.id)
	return out

static func claimable_count(data: Dictionary) -> int:
	var n := 0
	for a in LIST:
		if is_unlocked(data, a.id) and not is_claimed(data, a.id):
			n += 1
	return n

## Newly unlocked since the last call; records them as announced so a toast
## is shown once.
static func take_new(data: Dictionary) -> Array:
	var out: Array = []
	for id in unlocked_ids(data):
		if not data.achievements.announced.has(id):
			data.achievements.announced[id] = true
			out.append(id)
	return out
