class_name Restoration
extends RefCounted
## Café restoration catalogue and rules. One token is awarded on the FIRST clear
## of each campaign level (60 total). Milestone costs sum to 60, so the final
## milestone (sign + opening celebration) arrives with the final level.

const TOKENS_PER_FIRST_CLEAR := 1

## Milestones in order. `cost` is in restoration tokens.
const MILESTONES := [
	{"id": "storefront", "cost": 8},
	{"id": "windows", "cost": 10},
	{"id": "counter", "cost": 12},
	{"id": "seating", "cost": 14},
	{"id": "sign", "cost": 16},
]

## Cosmetic categories. `requires` = number of milestones unlocked; `sku` marks
## an option that needs the cosmetic purchase entitlement.
const CHOICES := {
	"wall": {"requires": 1, "options": [
		{"id": "cream"}, {"id": "sage"}, {"id": "blush"}, {"id": "evening", "sku": "theme_evening"}]},
	"seating": {"requires": 4, "options": [
		{"id": "bistro"}, {"id": "rattan"}, {"id": "booth"}, {"id": "evening", "sku": "theme_evening"}]},
	"plants": {"requires": 4, "options": [
		{"id": "ferns"}, {"id": "olive"}, {"id": "flowers"}]},
	"sign": {"requires": 5, "options": [
		{"id": "script"}, {"id": "block"}, {"id": "painted"}, {"id": "evening", "sku": "theme_evening"}]},
}

const DEFAULTS := {"wall": "cream", "seating": "bistro", "plants": "ferns", "sign": "script"}

static func total_cost() -> int:
	var n := 0
	for m in MILESTONES:
		n += int(m.cost)
	return n

## Next milestone index, or -1 when the café is complete.
static func next_index(data: Dictionary) -> int:
	var i := int(data.restoration.milestones)
	return i if i < MILESTONES.size() else -1

static func can_unlock(data: Dictionary) -> bool:
	var i := next_index(data)
	return i >= 0 and int(data.tokens) >= int(MILESTONES[i].cost)

## Spends tokens and unlocks the next milestone. Returns the milestone id or "".
static func unlock_next(data: Dictionary) -> String:
	if not can_unlock(data):
		return ""
	var i := next_index(data)
	data.tokens = int(data.tokens) - int(MILESTONES[i].cost)
	data.restoration.milestones = i + 1
	return MILESTONES[i].id

static func choice(data: Dictionary, category: String) -> String:
	return str(data.restoration.choices.get(category, DEFAULTS[category]))

static func is_option_available(data: Dictionary, category: String, option: String) -> bool:
	var cat: Dictionary = CHOICES.get(category, {})
	if cat.is_empty() or int(data.restoration.milestones) < int(cat.requires):
		return false
	for o in cat.options:
		if o.id == option:
			return not o.has("sku") or bool(data.purchases.owned.get(o.sku, false))
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
