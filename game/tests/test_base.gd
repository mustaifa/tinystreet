extends RefCounted
## Minimal assertion helpers shared by test suites.

var failures: Array = []
var current := ""

func check(cond: bool, msg: String = "") -> void:
	if not cond:
		failures.append("%s: %s" % [current, msg])

func eq(a, b, msg: String = "") -> void:
	if a != b:
		failures.append("%s: expected %s got %s %s" % [current, b, a, msg])

## Builds a level from a compact dict, filling defaults.
func lvl(d: Dictionary) -> LevelDef:
	var full := {"id": "t", "counter": 2, "trays": 1, "crates": [], "orders": []}
	full.merge(d, true)
	return LevelDef.from_dict(full)
