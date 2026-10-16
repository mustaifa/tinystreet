class_name LevelDef
extends RefCounted
## Immutable, parsed level definition. See GAME_DESIGN.md "Level format".
##
## crates[i] is an ordered stack; index 0 is the FRONT (the only selectable item).
## orders[k] is an Array of stages; each stage is a PackedInt32Array of length
## Products.COUNT holding the required quantity of each product.
##
## Item strings in JSON may carry mechanic markers (see GAME_DESIGN.md):
##   "coffee!"  FRESH: must go straight into an order, never onto the counter.
##   "?coffee"  BAG:   wrapped; its product is hidden until it reaches the front.
## Optional "locks": [n0, n1, ...] per crate: the crate stays strapped shut
## until n orders have been delivered (0 = open from the start).
## Optional "bell": false disables the priority bell (v3) for this level; the
## bell is allowed by default. Only the first tutorials turn it off.

const FRESH := 1
const BAG := 2

var id: String = ""
var crates: Array = []          # Array[PackedInt32Array]
var flags: Array = []           # Array[PackedInt32Array], parallel to crates (FRESH | BAG)
var locks: PackedInt32Array = PackedInt32Array()  # per crate: deliveries needed to open
var allow_bell := true          # v3: the player may ring a ticket's bell
var bell_budget := -1           # v4 ledger: max bell rings (-1 = unlimited)
var sequence: PackedInt32Array = PackedInt32Array()  # v4 ledger: orders that must be delivered in this order
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
		var fl := PackedInt32Array()
		for p in c:
			var it := parse_item(str(p))
			stack.append(it[0])
			fl.append(it[1])
		L.crates.append(stack)
		L.flags.append(fl)
	L.locks.resize(L.crates.size())
	var lk = d.get("locks", [])
	if lk is Array:
		for i in mini(lk.size(), L.crates.size()):
			L.locks[i] = maxi(0, int(lk[i]))
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
	L.allow_bell = bool(d.get("bell", true))
	L.bell_budget = int(d.get("bell_budget", -1))
	var sq = d.get("sequence", [])
	if sq is Array:
		for v in sq:
			L.sequence.append(int(v))
	L.meta = d.get("meta", {})
	return L

## "?tea!" -> [TEA, BAG | FRESH]. Unknown product -> [-1, flags].
static func parse_item(raw: String) -> Array:
	var f := 0
	var t := raw
	if t.begins_with("?"):
		f |= BAG
		t = t.substr(1)
	if t.ends_with("!"):
		f |= FRESH
		t = t.substr(0, t.length() - 1)
	return [Products.id_to_index(t), f]

static func item_string(p: int, f: int) -> String:
	return ("?" if f & BAG else "") + Products.index_to_id(p) + ("!" if f & FRESH else "")

func flag(crate: int, k: int) -> int:
	var fl: PackedInt32Array = flags[crate]
	return fl[k] if k < fl.size() else 0

func to_dict() -> Dictionary:
	var cr: Array = []
	for ci in crates.size():
		var a: Array = []
		var c: PackedInt32Array = crates[ci]
		for k in c.size():
			a.append(item_string(c[k], flag(ci, k)))
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
	var out := {"id": id, "counter": counter_slots, "trays": trays, "crates": cr, "orders": od, "meta": meta}
	if has_locks():
		out["locks"] = Array(locks)
	if not allow_bell:
		out["bell"] = false
	if bell_budget >= 0:
		out["bell_budget"] = bell_budget
	if not sequence.is_empty():
		out["sequence"] = Array(sequence)
	return out

## Same level with the bell disabled (used to measure what the bell adds).
func without_bell() -> LevelDef:
	var L := LevelDef.new()
	L.id = id
	L.crates = crates
	L.flags = flags
	L.locks = locks
	L.counter_slots = counter_slots
	L.trays = trays
	L.orders = orders
	L.meta = meta
	L.allow_bell = false
	L.bell_budget = bell_budget
	L.sequence = sequence
	return L

## Same level with a different bell budget (proofs of the minimum rings).
func with_budget(n: int) -> LevelDef:
	var L := without_bell()
	L.allow_bell = allow_bell
	L.bell_budget = n
	return L

## Hash of everything that affects the rules (not meta). Saved puzzle states
## are only resumed against content with the same hash.
func content_hash() -> String:
	var d := to_dict()
	d.erase("meta")
	d.erase("id")
	return JSON.stringify(d, "", true).sha256_text().substr(0, 16)

func max_stages() -> int:
	var n := 0
	for o in orders:
		n = maxi(n, o.size())
	return n

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

func has_locks() -> bool:
	for v in locks:
		if v > 0:
			return true
	return false

func count_flag(f: int) -> int:
	var n := 0
	for fl in flags:
		for v in fl:
			if v & f:
				n += 1
	return n

## Mechanics this level uses: any of "fresh", "bag", "lock", "two_stage"
## (an order in 2 parts), "special" (a 3-part special order).
func mechanics() -> Array:
	var m: Array = []
	if count_flag(FRESH) > 0:
		m.append("fresh")
	if count_flag(BAG) > 0:
		m.append("bag")
	if has_locks():
		m.append("lock")
	for o in orders:
		if o.size() == 2:
			m.append("two_stage")
			break
	if max_stages() >= 3:
		m.append("special")
	return m
