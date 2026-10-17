class_name Specials
extends RefCounted
## v3 special orders: a 3-part order in a longer level (meta.special), with a
## named customer, a banner, a story beat and a ONE-TIME reward on the first
## win. Rewards are recorded in the grant ledger ("special:<level>"), so
## replays, reloads or double callbacks can't pay twice.
##   reward "extra:<id>"   a café extra appears for free (e.g. the chalkboard)
##   reward "unlock:bakery" opens Mira's Bakery (second destination)

static func of(def: LevelDef) -> Dictionary:
	var sp = def.meta.get("special", {})
	return sp if sp is Dictionary else {}

static func is_special_order(def: LevelDef, o: int) -> bool:
	var sp := of(def)
	return not sp.is_empty() and o >= 0 and int(sp.get("order", -1)) == o

static func customer(def: LevelDef, o: int) -> String:
	return str(of(def).get("customer", "")) if is_special_order(def, o) else ""

## Grants the reward once. Returns {reward, new, title}.
static func on_win(data: Dictionary, def: LevelDef) -> Dictionary:
	var sp := of(def)
	if sp.is_empty():
		return {}
	var key := "special:" + def.id
	var out := {"reward": str(sp.get("reward", "")), "new": false, "title": str(sp.get("title", ""))}
	if data.grants.has(key):
		return out
	data.grants[key] = 0
	out.new = true
	var r: String = out.reward
	if r.begins_with("extra:"):
		data.restoration.extras[r.substr(6)] = true
	elif r == "unlock:bakery":
		data.bakery.unlocked = true
	return out
