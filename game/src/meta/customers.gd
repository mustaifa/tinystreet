class_name Customers
extends RefCounted
## Who places each order. Deterministic from the order's contents, so the
## same order always shows the same face and tasks can count regulars:
##   Theo   orders only coffee.
##   Basil  orders only tea.
##   Mira   orders only pastries (croissant, cupcake).
## Everyone else is a neighbour (a stable pick from six neighbour portraits).

const CAST := ["mira", "theo", "basil"]

static func for_order(def: LevelDef, o: int) -> String:
	if o < 0 or o >= def.orders.size():
		return "n0"
	var sp := Specials.customer(def, o)
	if sp != "":
		return sp
	var fixed = def.meta.get("customers", [])
	if fixed is Array and o < fixed.size():
		return str(fixed[o])   # v4 ledger pages name every customer
	if def.id.begins_with("m"):
		# Mira's Bakery: Mira serves; the neighbours come to buy.
		return "n%d" % posmod(hash(def.id + ":" + str(o)), 6)
	var st: PackedInt32Array = def.orders[o][0]
	var kinds := {}
	for p in Products.COUNT:
		if st[p] > 0:
			kinds[p] = true
	if kinds.size() == 1 and kinds.has(Products.COFFEE):
		return "theo"
	if kinds.size() == 1 and kinds.has(Products.TEA):
		return "basil"
	var pastry := true
	for p in kinds:
		if p != Products.CROISSANT and p != Products.CUPCAKE:
			pastry = false
	if pastry and not kinds.is_empty():
		return "mira"
	return "n%d" % posmod(hash(def.id + ":" + str(o)), 6)

## Count of orders in a level placed by each cast member.
static func cast_counts(def: LevelDef) -> Dictionary:
	var out := {"mira": 0, "theo": 0, "basil": 0}
	for o in def.orders.size():
		var w := for_order(def, o)
		if out.has(w):
			out[w] += 1
	return out
