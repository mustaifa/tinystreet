class_name Bakery
extends RefCounted
## Mira's Bakery (v3 second destination): a short restoration arc next door.
## Unlocked by the special order in level p12 (Specials, "unlock:bakery").
## Uses the same tokens (one wallet) and the same rules engine; its 8 levels
## (m01..m08, data/levels/bakery.json) feature "oven batches": a locked crate
## drawn as an oven, full of hot pastries.

const STEPS := [
	{"id": "ovens", "cost": 6, "choice": ""},
	{"id": "shelves", "cost": 10, "choice": "shelf"},
	{"id": "awning", "cost": 14, "choice": "awning"},
	{"id": "bopening", "cost": 18, "choice": "bsign"},
]

const CHOICES := {
	"shelf": {"step": 2, "options": ["pine", "whitewash"]},
	"awning": {"step": 3, "options": ["rose", "mint", "butter"]},
	"bsign": {"step": 4, "options": ["loaf", "whisk"]},
}
const DEFAULTS := {"shelf": "pine", "awning": "rose", "bsign": "loaf"}

static func is_unlocked(data: Dictionary) -> bool:
	return bool(data.bakery.unlocked)

static func steps(data: Dictionary) -> int:
	return clampi(int(data.bakery.steps), 0, STEPS.size())

static func is_complete(data: Dictionary) -> bool:
	return steps(data) >= STEPS.size()

static func next_index(data: Dictionary) -> int:
	var i := steps(data)
	return i if i < STEPS.size() else -1

static func can_unlock(data: Dictionary) -> bool:
	var i := next_index(data)
	return is_unlocked(data) and i >= 0 and int(data.tokens) >= int(STEPS[i].cost)

## Spends tokens once and completes the next bakery step. Returns its id or "".
static func unlock_next(data: Dictionary) -> String:
	if not can_unlock(data):
		return ""
	var i := next_index(data)
	if not Wallet.spend(data, int(STEPS[i].cost)):
		return ""
	data.bakery.steps = i + 1
	return STEPS[i].id

static func step_def(id: String) -> Dictionary:
	for s in STEPS:
		if s.id == id:
			return s
	return {}

static func is_option_available(data: Dictionary, cat: String, opt: String) -> bool:
	var c: Dictionary = CHOICES.get(cat, {})
	return not c.is_empty() and steps(data) >= int(c.step) and opt in c.options

static func choice(data: Dictionary, cat: String) -> String:
	var v := str(data.bakery.choices.get(cat, DEFAULTS[cat]))
	return v if is_option_available(data, cat, v) else DEFAULTS[cat]

static func set_choice(data: Dictionary, cat: String, opt: String) -> bool:
	if not is_option_available(data, cat, opt):
		return false
	data.bakery.choices[cat] = opt
	return true

static func view_state(data: Dictionary) -> Dictionary:
	var ch := {}
	for k in DEFAULTS:
		ch[k] = choice(data, k)
	return {"steps": steps(data), "choices": ch}
