class_name Restoration
extends RefCounted
## Café restoration (v2): eight visible steps bought with tokens, decor
## choices that can be changed any time, and collectible extras.
## Tokens come from stars (1 per star per level, idempotent), café tasks and
## achievements. The first step costs 3, so it is affordable after level 1.

## Steps in order. `choice` names the decor category the step unlocks; the
## player picks an option right after buying (and can change it later).
const STEPS := [
	{"id": "clean", "cost": 3, "choice": ""},
	{"id": "walls", "cost": 6, "choice": "walls"},
	{"id": "floor", "cost": 10, "choice": "floor"},
	{"id": "counter", "cost": 14, "choice": "counter"},
	{"id": "lights", "cost": 18, "choice": "lights"},
	{"id": "seating", "cost": 22, "choice": "seating"},
	{"id": "plants", "cost": 26, "choice": "plants"},
	{"id": "opening", "cost": 30, "choice": "sign"},
]

## Decor categories. `step` = steps owned before the category is available.
## Options: `sku` needs the cosmetic purchase; `ach` needs an achievement.
const CHOICES := {
	"walls": {"step": 2, "options": [{"id": "cream"}, {"id": "sage"}, {"id": "blush"}, {"id": "evening", "sku": "theme_evening"}]},
	"floor": {"step": 3, "options": [{"id": "oak"}, {"id": "checker"}, {"id": "terracotta"}]},
	"counter": {"step": 4, "options": [{"id": "oakwood"}, {"id": "marble"}, {"id": "teal"}]},
	"lights": {"step": 5, "options": [{"id": "pendant"}, {"id": "string"}, {"id": "globe"}]},
	"seating": {"step": 6, "options": [{"id": "bistro"}, {"id": "rattan"}, {"id": "booth"}, {"id": "evening", "sku": "theme_evening"}]},
	"plants": {"step": 7, "options": [{"id": "ferns"}, {"id": "olive"}, {"id": "flowers"}]},
	"sign": {"step": 8, "options": [{"id": "script"}, {"id": "block"}, {"id": "painted"},
		{"id": "gilded", "ach": "perfectionist"}, {"id": "evening", "sku": "theme_evening"}]},
}

const DEFAULTS := {"walls": "cream", "floor": "oak", "counter": "oakwood", "lights": "pendant",
	"seating": "bistro", "plants": "ferns", "sign": "script"}

## Collectible extras: bought with tokens once available, visible in the café,
## and can be shown or hidden.
const EXTRAS := [
	{"id": "clock", "cost": 10, "step": 2},
	{"id": "cakestand", "cost": 12, "step": 4},
	{"id": "gramophone", "cost": 15, "step": 5},
	{"id": "cat", "cost": 18, "step": 6},
	{"id": "photos", "cost": 0, "step": 3, "ach": "regulars"},
]

static func total_cost() -> int:
	var n := 0
	for m in STEPS:
		n += int(m.cost)
	return n

static func steps(data: Dictionary) -> int:
	return clampi(int(data.restoration.steps), 0, STEPS.size())

static func is_complete(data: Dictionary) -> bool:
	return steps(data) >= STEPS.size()

## Next step index, or -1 when the café is complete.
static func next_index(data: Dictionary) -> int:
	var i := steps(data)
	return i if i < STEPS.size() else -1

static func next_cost(data: Dictionary) -> int:
	var i := next_index(data)
	return int(STEPS[i].cost) if i >= 0 else 0

static func can_unlock(data: Dictionary) -> bool:
	var i := next_index(data)
	return i >= 0 and int(data.tokens) >= int(STEPS[i].cost)

## Spends tokens and completes the next step. Returns the step id or "".
## Safe against double taps: the second call sees the new step count.
static func unlock_next(data: Dictionary) -> String:
	if not can_unlock(data):
		return ""
	var i := next_index(data)
	if not Wallet.spend(data, int(STEPS[i].cost)):
		return ""
	data.restoration.steps = i + 1
	return STEPS[i].id

static func step_def(id: String) -> Dictionary:
	for s in STEPS:
		if s.id == id:
			return s
	return {}

static func choice(data: Dictionary, category: String) -> String:
	return str(data.restoration.choices.get(category, DEFAULTS[category]))

static func is_category_open(data: Dictionary, category: String) -> bool:
	var cat: Dictionary = CHOICES.get(category, {})
	return not cat.is_empty() and steps(data) >= int(cat.step)

static func is_option_available(data: Dictionary, category: String, option: String) -> bool:
	if not is_category_open(data, category):
		return false
	for o in CHOICES[category].options:
		if o.id == option:
			if o.has("sku") and not bool(data.purchases.owned.get(o.sku, false)):
				return false
			if o.has("ach") and not Achievements.is_unlocked(data, o.ach):
				return false
			return true
	return false

static func set_choice(data: Dictionary, category: String, option: String) -> bool:
	if not is_option_available(data, category, option):
		return false
	data.restoration.choices[category] = option
	return true

## Effective choice: falls back to default if an option became unavailable
## (e.g. a refunded purchase).
static func effective_choice(data: Dictionary, category: String) -> String:
	var c := choice(data, category)
	if c != DEFAULTS[category] and not is_option_available(data, category, c):
		return DEFAULTS[category]
	return c

static func effective_choices(data: Dictionary) -> Dictionary:
	var out := {}
	for k in DEFAULTS:
		out[k] = effective_choice(data, k)
	return out

# --- extras ------------------------------------------------------------------

static func extra_def(id: String) -> Dictionary:
	for e in EXTRAS:
		if e.id == id:
			return e
	return {}

static func owns_extra(data: Dictionary, id: String) -> bool:
	var e := extra_def(id)
	if e.has("ach"):
		return Achievements.is_unlocked(data, e.ach)
	return bool(data.restoration.extras.get(id, false))

static func can_buy_extra(data: Dictionary, id: String) -> bool:
	var e := extra_def(id)
	return not e.is_empty() and not e.has("ach") and not owns_extra(data, id) \
		and steps(data) >= int(e.step) and int(data.tokens) >= int(e.cost)

static func buy_extra(data: Dictionary, id: String) -> bool:
	if not can_buy_extra(data, id):
		return false
	if not Wallet.spend(data, int(extra_def(id).cost)):
		return false
	data.restoration.extras[id] = true
	return true

## Extras the café should draw: owned and not hidden by the player.
static func shown_extras(data: Dictionary) -> Dictionary:
	var out := {}
	for e in EXTRAS:
		if owns_extra(data, e.id) and not bool(data.restoration.hidden.get(e.id, false)):
			out[e.id] = true
	return out

static func toggle_extra(data: Dictionary, id: String) -> void:
	if owns_extra(data, id):
		data.restoration.hidden[id] = not bool(data.restoration.hidden.get(id, false))

## Everything the café drawing needs.
static func view_state(data: Dictionary) -> Dictionary:
	return {"steps": steps(data), "choices": effective_choices(data), "extras": shown_extras(data)}
