class_name Ledger
extends RefCounted
## The Midnight Ledger (v4): an optional expert mode of hand-curated, proven
## puzzle pages (data/levels/ledger.json). It never pays tokens, so the
## campaign, café and bakery economy is untouched. Rewards:
##   stamp      first completion of a page
##   no-hint    completion without opening any hint stage
##   precision  completion in at most the page's verified move target
##              (only offered where the target is proven minimal)
##   lamp       a café extra for stamping every page (once)
## Each reward is recorded once (ledger keys in data.grants with amount 0, and
## the data.ledger maps), so replays, reloads and double callbacks can't
## duplicate anything. An improved badge never re-grants the stamp.
##
## A MOVE is one crate tap or one bell ring in your final sequence; undone
## actions don't count.
##
## Access: after the bell lesson (p01). Lessons open one after another; the
## nine puzzles open after the lessons; the final page after six puzzles.

const FILE := "res://data/levels/ledger.json"
const UNLOCK_LEVEL := "p01"
const FINAL_NEEDS := 6

static var _pages: Array = []

static func pages() -> Array:
	if _pages.is_empty() and FileAccess.file_exists(FILE):
		var d = JSON.parse_string(FileAccess.get_file_as_string(FILE))
		if typeof(d) == TYPE_DICTIONARY and d.get("pages") is Array:
			_pages = d.pages
	return _pages

static func page(id: String) -> Dictionary:
	for p in pages():
		if p.id == id:
			return p
	return {}

static func index(id: String) -> int:
	for i in pages().size():
		if pages()[i].id == id:
			return i
	return -1

static func info(p: Dictionary) -> Dictionary:
	return p.get("meta", {}).get("ledger", {})

static func group(p: Dictionary) -> String:
	return str(info(p).get("group", "puzzle"))

static func is_open(data: Dictionary) -> bool:
	return Progression.is_cleared(data, UNLOCK_LEVEL)

static func is_done(data: Dictionary, id: String) -> bool:
	return bool(data.ledger.done.get(id, false))

static func done_count(data: Dictionary, grp: String = "") -> int:
	var n := 0
	for p in pages():
		if (grp == "" or group(p) == grp) and is_done(data, p.id):
			n += 1
	return n

static func is_unlocked(data: Dictionary, id: String) -> bool:
	if not is_open(data):
		return false
	var p := page(id)
	match group(p):
		"lesson":
			var i := index(id)
			return i == 0 or is_done(data, pages()[i - 1].id) or is_done(data, id)
		"puzzle":
			return done_count(data, "lesson") >= 3 or is_done(data, id)
		"final":
			return done_count(data, "puzzle") >= FINAL_NEEDS or is_done(data, id)
	return false

static func precision_target(p: Dictionary) -> int:
	return int(info(p).get("precision_target", 0))

## Records a finished page. `moves` = actions in the final log, `hints` = hint
## stages opened. Returns what is new this time.
static func record(data: Dictionary, id: String, moves: int, hints: int) -> Dictionary:
	var p := page(id)
	var out := {"stamp_new": false, "nohint_new": false, "precision_new": false, "lamp_new": false,
		"precision_met": false, "nohint_met": hints == 0}
	if p.is_empty():
		return out
	if not is_done(data, id):
		data.ledger.done[id] = true
		out.stamp_new = true
	if hints == 0 and not bool(data.ledger.nohint.get(id, false)):
		data.ledger.nohint[id] = true
		out.nohint_new = true
	var tgt := precision_target(p)
	if tgt > 0 and moves <= tgt:
		out.precision_met = true
		if not bool(data.ledger.precision.get(id, false)):
			data.ledger.precision[id] = true
			out.precision_new = true
	if done_count(data) >= pages().size() and not data.grants.has("ledger:collection"):
		data.grants["ledger:collection"] = 0
		data.restoration.extras["lamp"] = true
		out.lamp_new = true
	return out
