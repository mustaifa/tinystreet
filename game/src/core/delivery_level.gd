class_name DeliveryLevel
extends RefCounted
## Static data of one Delivery Logic puzzle, parsed from an ASCII map
## (format and meaning: docs/DELIVERY_RULES.md §1–2). Holds no rules: moves,
## wins and deadlocks live in DeliveryRules.
##
## Cells are indexed y * w + x. Crates are stored sorted by symbol (then by
## start cell), so crate index i always has symbol crate_sym[i]; crates of
## one symbol are interchangeable.

enum { VOID, WALL, FLOOR }

const SYMBOLS := 4
## Product art index for each symbol: coffee, croissant, strawberry, tea.
const SYMBOL_PRODUCT := [0, 2, 4, 1]
const SYMBOL_IDS := ["coffee", "croissant", "strawberry", "tea"]
const MAX_CELLS := 255

var id := ""
var w := 0
var h := 0
var n := 0
var map: PackedStringArray = []
var kind := PackedByteArray()       # VOID / WALL / FLOOR per cell
var goal := PackedInt32Array()      # symbol of the destination on a cell, or -1
var nb := PackedInt32Array()        # neighbour of cell c in direction d at c * 4 + d, or -1
var start_player := -1
var start_crates := PackedInt32Array()
var crate_sym := PackedInt32Array()
var meta: Dictionary = {}           # title, nudge, coach, min_pushes, reward, design notes
var errors: Array[String] = []
var _live: Array = []               # per symbol PackedByteArray, filled by DeliveryRules

static func from_dict(d: Dictionary) -> DeliveryLevel:
	var l := DeliveryLevel.new()
	l.id = str(d.get("id", ""))
	l.meta = d
	var rows: Array = d.get("map", []) if d.get("map") is Array else []
	l.parse(PackedStringArray(rows))
	return l

static func from_rows(level_id: String, rows: Array) -> DeliveryLevel:
	return from_dict({"id": level_id, "map": rows})

func parse(rows: PackedStringArray) -> void:
	map = rows
	h = rows.size()
	w = 0
	for r in rows:
		w = maxi(w, r.length())
	n = w * h
	if h == 0 or w == 0:
		errors.append("empty map")
		return
	if n > MAX_CELLS:
		errors.append("map has %d cells (max %d)" % [n, MAX_CELLS])
		return
	kind.resize(n)
	kind.fill(VOID)
	goal.resize(n)
	goal.fill(-1)
	var crates: Array = []   # [sym, cell]
	for y in h:
		var r: String = rows[y]
		for x in w:
			var ch := r[x] if x < r.length() else " "
			var c := y * w + x
			match ch:
				" ":
					pass
				"#":
					kind[c] = WALL
				".":
					kind[c] = FLOOR
				"@":
					kind[c] = FLOOR
					if start_player >= 0:
						errors.append("more than one courier")
					start_player = c
				"a", "b", "c", "d":
					kind[c] = FLOOR
					goal[c] = ch.unicode_at(0) - "a".unicode_at(0)
				"A", "B", "C", "D":
					kind[c] = FLOOR
					crates.append([ch.unicode_at(0) - "A".unicode_at(0), c])
				"1", "2", "3", "4":
					var s := ch.unicode_at(0) - "1".unicode_at(0)
					kind[c] = FLOOR
					goal[c] = s
					crates.append([s, c])
				_:
					errors.append("unknown map character '%s' at %d,%d" % [ch, x, y])
	crates.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0] or (a[0] == b[0] and a[1] < b[1]))
	for cr in crates:
		crate_sym.append(int(cr[0]))
		start_crates.append(int(cr[1]))
	nb.resize(n * 4)
	for c in n:
		var x := c % w
		var y := c / w
		nb[c * 4 + 0] = c - w if y > 0 else -1
		nb[c * 4 + 1] = c + 1 if x < w - 1 else -1
		nb[c * 4 + 2] = c + w if y < h - 1 else -1
		nb[c * 4 + 3] = c - 1 if x > 0 else -1
	_check()

func _check() -> void:
	if start_player < 0:
		errors.append("no courier")
	if start_crates.is_empty():
		errors.append("no crates")
	for s in SYMBOLS:
		var nc := 0
		var ng := 0
		for i in crate_sym.size():
			if crate_sym[i] == s:
				nc += 1
		for c in n:
			if goal[c] == s:
				ng += 1
		if nc != ng:
			errors.append("symbol %s: %d crates but %d destinations" % [SYMBOL_IDS[s], nc, ng])
	# The courier must not be able to walk off the map: every floor cell on
	# the border or next to void is an authoring error.
	for c in n:
		if kind[c] != FLOOR:
			continue
		for d in 4:
			var t := nb[c * 4 + d]
			if t < 0 or kind[t] == VOID:
				errors.append("floor at %d,%d is open to the outside" % [c % w, c / w])
				break

func is_valid() -> bool:
	return errors.is_empty()

func floor_at(c: int) -> bool:
	return c >= 0 and kind[c] == FLOOR

func nbr(c: int, d: int) -> int:
	return nb[c * 4 + d]

func x_of(c: int) -> int:
	return c % w

func y_of(c: int) -> int:
	return c / w

func crate_count() -> int:
	return crate_sym.size()

func title() -> String:
	var k := str(meta.get("title", ""))
	return Loc.t(k) if k != "" else id

func min_pushes() -> int:
	return int(meta.get("min_pushes", -1))

func reward() -> int:
	return int(meta.get("reward", 0))

## Stable hash of everything that affects play: a saved attempt is resumed
## only against the same layout.
func content_hash() -> String:
	return ("|".join(map)).sha256_text().substr(0, 16)
