class_name LevelDef
extends RefCounted
## Immutable, parsed level definition. See GAME_DESIGN.md "Level format".
##
## crates[i] is an ordered stack; index 0 is the FRONT (the only selectable item).
## orders[k] is an Array of stages; each stage is a PackedInt32Array of length
## Products.COUNT holding the required quantity of each product.

var id: String = ""
var crates: Array = []          # Array[PackedInt32Array]
var counter_slots: int = 4
var trays: int = 2
var orders: Array = []          # Array[Array[PackedInt32Array]]
var meta: Dictionary = {}       # tutorial, stars thresholds, solution, difficulty...

static func from_dict(d: Dictionary) -> LevelDef:
	var L := LevelDef.new()
	L.id = str(d.get("id", ""))
	L.counter_slots = int(d.get("counter", 4))
	L.trays = int(d.get("trays", 2))
	for c in d.get("crates", []):
		var stack := PackedInt32Array()
		for p in c:
			stack.append(Products.id_to_index(str(p)))
		L.crates.append(stack)
	for o in d.get("orders", []):
		var stages: Array = []
		for s in o:
			var need := PackedInt32Array()
			need.resize(Products.COUNT)
			for k in s:
				var pi := Products.id_to_index(str(k))
				if pi >= 0:
					need[pi] += int(s[k])
				else:
					need.append(-999) # poison: validator reports unknown product
			stages.append(need)
		L.orders.append(stages)
	L.meta = d.get("meta", {})
	return L

func to_dict() -> Dictionary:
	var cr: Array = []
	for c in crates:
		var a: Array = []
		for p in c:
			a.append(Products.index_to_id(p))
		cr.append(a)
	var od: Array = []
	for o in orders:
		var st: Array = []
		for s in o:
			var dd := {}
			for i in Products.COUNT:
				if s[i] > 0:
					dd[Products.index_to_id(i)] = s[i]
			st.append(dd)
		od.append(st)
	return {"id": id, "counter": counter_slots, "trays": trays, "crates": cr, "orders": od, "meta": meta}

func total_items() -> int:
	var n := 0
	for c in crates:
		n += c.size()
	return n

func has_two_stage() -> bool:
	for o in orders:
		if o.size() > 1:
			return true
	return false
