class_name SaveStore
extends RefCounted
## Versioned, checksummed, atomic local save with backup recovery.
##
## File envelope: {"schema": int, "sha256": hex, "payload": "<json string>"}
## Write sequence: write <file>.tmp -> rename <file> to <file>.bak -> rename tmp
## to <file>. Load order: <file>, then <file>.tmp, then <file>.bak, then fresh.
## Offline saves cannot provide anti-cheat protection; the checksum detects
## corruption, not tampering.

const SCHEMA := 5

var path: String
var last_load_source := ""     # "main", "tmp", "backup", "fresh"
var last_load_issue := ""      # human-readable reason if recovery happened
var backup_written := ""       # pre-migration copy written by the last load

func _init(p: String = "user://save.json") -> void:
	path = p

func save(data: Dictionary) -> bool:
	var payload := JSON.stringify(data)
	var env := {"schema": SCHEMA, "sha256": payload.sha256_text(), "payload": payload}
	var tmp := path + ".tmp"
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		push_warning("save: cannot open temp file (%d)" % FileAccess.get_open_error())
		return false
	f.store_string(JSON.stringify(env))
	f.flush()
	f.close()
	var abs_main := ProjectSettings.globalize_path(path)
	var abs_tmp := ProjectSettings.globalize_path(tmp)
	var abs_bak := ProjectSettings.globalize_path(path + ".bak")
	if FileAccess.file_exists(path):
		if _read_valid(path) != null:
			DirAccess.remove_absolute(abs_bak)
			DirAccess.rename_absolute(abs_main, abs_bak)
	var err := DirAccess.rename_absolute(abs_tmp, abs_main)
	return err == OK

## Returns a migrated, validated save dictionary (never null).
func load_data() -> Dictionary:
	last_load_issue = ""
	for pair in [[path, "main"], [path + ".tmp", "tmp"], [path + ".bak", "backup"]]:
		if not FileAccess.file_exists(pair[0]):
			if pair[1] == "main":
				last_load_issue = "no main save"
			continue
		var d = _read_valid(pair[0])
		if d == null:
			last_load_issue = "%s save unreadable or corrupt" % pair[1]
			continue
		last_load_source = pair[1]
		if int(d.schema) < SCHEMA:
			_backup_before_migration(pair[0], int(d.schema))
		return GameData.sanitize(migrate(d.payload, int(d.schema)))
	last_load_source = "fresh"
	return GameData.fresh()

## Parsed envelope if checksum and JSON are valid, else null.
func _read_valid(p: String):
	var txt := FileAccess.get_file_as_string(p)
	if txt.is_empty():
		return null
	var env = JSON.parse_string(txt)
	if typeof(env) != TYPE_DICTIONARY or not env.has("payload") or not env.has("sha256"):
		return null
	if str(env.payload).sha256_text() != str(env.sha256):
		return null
	var payload = JSON.parse_string(str(env.payload))
	if typeof(payload) != TYPE_DICTIONARY:
		return null
	return {"schema": int(env.get("schema", 1)), "payload": payload}

## Upgrades older schemas step by step.
static func migrate(d: Dictionary, from_schema: int) -> Dictionary:
	var s := from_schema
	if s < 2:
		# v1 stored stars as an Array of [id, stars] pairs and had no daily block.
		var stars := {}
		for pair in d.get("stars", []):
			if pair is Array and pair.size() == 2:
				stars[str(pair[0])] = int(pair[1])
		d.erase("stars")
		var camp: Dictionary = d.get("campaign", {})
		camp["stars"] = stars
		var cleared := {}
		for k in stars:
			cleared[k] = true
		camp["cleared"] = cleared
		d["campaign"] = camp
		if not d.has("daily"):
			d["daily"] = {"completed": {}}
		s = 2
	if s < 3:
		d = migrate_v2_to_v3(d)
		s = 3
	if s < 4:
		# v3 game (schema 4) only ADDS state: mastery ribbons, bakery,
		# challenge cards. Defaults come from GameData.sanitize; nothing
		# existing is changed, so no reward is granted twice or lost.
		s = 4
	if s < 5:
		# v7 (schema 5) adds personal-best scores per level. Old wins have no
		# recorded score, so the map starts empty; stars and tokens are untouched.
		var camp: Dictionary = d.get("campaign", {})
		if not camp.has("best"):
			camp["best"] = {}
		d["campaign"] = camp
		s = 5
	return d

## Keeps an untouched copy of an older-schema save (once per schema) before
## the migrated data is first written, e.g. user://save.json.schema3.bak.
func _backup_before_migration(src: String, schema: int) -> void:
	var dst := path + ".schema%d.bak" % schema
	if FileAccess.file_exists(dst):
		return
	var txt := FileAccess.get_file_as_string(src)
	if txt.is_empty():
		return
	var f := FileAccess.open(dst, FileAccess.WRITE)
	if f:
		f.store_string(txt)
		f.close()
		backup_written = dst

## v2 -> v3 (Tiny Street v2 economy and café):
##  - 5 café milestones become 8 restoration steps without losing anything
##    already visible: storefront->clean+walls, windows->+floor,
##    counter->+counter, seating/lights/plants->+lights+seating+plants,
##    sign->opening. Decor choices carry over (wall->walls).
##  - Tokens become star-based. Every star already earned is recorded in the
##    grant ledger (so it can never pay twice) and credited; the cost of the
##    steps the player now owns is deducted. The balance never goes below
##    what the player had before the update.
const V2_STEP_MAP := [0, 2, 3, 4, 7, 8]
const V2_COSTS := [3, 6, 10, 14, 18, 22, 26, 30]

static func migrate_v2_to_v3(d: Dictionary) -> Dictionary:
	var rest: Dictionary = d.get("restoration", {}) if d.get("restoration") is Dictionary else {}
	var old_m := clampi(int(rest.get("milestones", 0)), 0, 5)
	var steps: int = V2_STEP_MAP[old_m]
	var old_choices: Dictionary = rest.get("choices", {}) if rest.get("choices") is Dictionary else {}
	var choices := {}
	for k in old_choices:
		choices["walls" if k == "wall" else str(k)] = old_choices[k]
	d["restoration"] = {"steps": steps, "choices": choices, "extras": {}, "hidden": {}}
	var grants := {}
	var earned := 0
	var camp: Dictionary = d.get("campaign", {}) if d.get("campaign") is Dictionary else {}
	var stars: Dictionary = camp.get("stars", {}) if camp.get("stars") is Dictionary else {}
	var cleared: Dictionary = camp.get("cleared", {}) if camp.get("cleared") is Dictionary else {}
	for id in stars:
		if not bool(cleared.get(id, false)):
			continue
		for k in range(1, clampi(int(stars[id]), 0, 3) + 1):
			grants["star:%s:%d" % [id, k]] = 1
			earned += 1
	var spent := 0
	for i in steps:
		spent += V2_COSTS[i]
	var old_tokens := maxi(0, int(d.get("tokens", 0)))
	d["grants"] = grants
	d["tokens"] = maxi(old_tokens, earned - spent)
	d["tokens_earned"] = maxi(int(d.get("tokens_earned", 0)), earned)
	return d

func delete_all() -> void:
	for suffix in ["", ".tmp", ".bak", ".schema1.bak", ".schema2.bak", ".schema3.bak", ".schema4.bak"]:
		if FileAccess.file_exists(path + suffix):
			DirAccess.remove_absolute(ProjectSettings.globalize_path(path + suffix))
