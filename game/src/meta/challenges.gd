class_name Challenges
extends RefCounted
## v3 challenge cards: a small, fixed collection of puzzles taken from the
## validated daily pool, each with ONE visible goal and a one-time token
## reward (ledger key "challenge:<id>"). Replays are always allowed; the card
## keeps its completed state. Available once the bell has been learned (p01
## cleared), because these puzzles allow the bell.
##
## Goals are checked from the finished attempt only:
##   win        finish the puzzle
##   three      finish with 3 stars
##   no_hint    finish without a hint
##   no_undo    finish without undo
##   tidy       peak counter at or below the solver-proven minimum (mastery)

const LIST := [
	{"id": "ch01", "level": "d004", "goal": "win", "reward": 2},
	{"id": "ch02", "level": "d011", "goal": "no_undo", "reward": 3},
	{"id": "ch03", "level": "d017", "goal": "three", "reward": 3},
	{"id": "ch04", "level": "d022", "goal": "no_hint", "reward": 3},
	{"id": "ch05", "level": "d026", "goal": "tidy", "reward": 4},
	{"id": "ch06", "level": "d031", "goal": "three", "reward": 3},
	{"id": "ch07", "level": "d035", "goal": "no_undo", "reward": 3},
	{"id": "ch08", "level": "d040", "goal": "tidy", "reward": 4},
	{"id": "ch09", "level": "d044", "goal": "three", "reward": 4},
	{"id": "ch10", "level": "d049", "goal": "no_hint", "reward": 4},
	{"id": "ch11", "level": "d053", "goal": "tidy", "reward": 5},
	{"id": "ch12", "level": "d058", "goal": "three", "reward": 5},
]
const UNLOCK_LEVEL := "p01"

static func def(id: String) -> Dictionary:
	for c in LIST:
		if c.id == id:
			return c
	return {}

static func is_open(data: Dictionary) -> bool:
	return Progression.is_cleared(data, UNLOCK_LEVEL)

static func is_done(data: Dictionary, id: String) -> bool:
	return bool(data.challenges.done.get(id, false))

static func done_count(data: Dictionary) -> int:
	var n := 0
	for c in LIST:
		if is_done(data, c.id):
			n += 1
	return n

## Did this finished attempt meet the card's goal?
static func goal_met(c: Dictionary, level: LevelDef, stars: int, hints: int, undos: int, peak: int) -> bool:
	match str(c.goal):
		"win": return true
		"three": return stars >= 3
		"no_hint": return hints == 0
		"no_undo": return undos == 0
		"tidy": return peak <= Progression.mastery_target(level)
	return false

## Records a finished attempt. Returns {met, new, tokens}. Tokens pay once.
static func record(data: Dictionary, id: String, met: bool) -> Dictionary:
	var c := def(id)
	var out := {"met": met, "new": false, "tokens": 0}
	if c.is_empty() or not met:
		return out
	out.new = not is_done(data, id)
	data.challenges.done[id] = true
	if Wallet.grant(data, "challenge:" + id, int(c.reward)):
		out.tokens = int(c.reward)
	return out

## Localised goal line ("Finish with 3 stars", "Counter never above 2"...).
static func goal_text(c: Dictionary, level: LevelDef) -> String:
	var g := str(c.get("goal", "win"))
	if g == "tidy":
		return Loc.t("goal_tidy", [Progression.mastery_target(level) if level else 0])
	return Loc.t("goal_" + g)
