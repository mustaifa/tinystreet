class_name Progression
extends RefCounted
## Campaign and daily-challenge progression over the save dictionary.
## All award paths are idempotent: replays improve stars but never re-award
## first-clear tokens; a daily date is recorded once.

var campaign: Array = []   # Array[Dictionary] raw level dicts in order
var daily_pool: Array = []
var _defs := {}            # id -> LevelDef cache

func load_levels(campaign_path: String = "res://data/levels/campaign.json",
		daily_path: String = "res://data/levels/daily.json") -> void:
	campaign = _read(campaign_path)
	daily_pool = _read(daily_path)

static func _read(p: String) -> Array:
	if not FileAccess.file_exists(p):
		return []
	var d = JSON.parse_string(FileAccess.get_file_as_string(p))
	return d.levels if typeof(d) == TYPE_DICTIONARY and d.has("levels") else []

func def_for(id: String) -> LevelDef:
	if _defs.has(id):
		return _defs[id]
	for l in campaign + daily_pool:
		if l.id == id:
			_defs[id] = LevelDef.from_dict(l)
			return _defs[id]
	return null

func campaign_index(id: String) -> int:
	for i in campaign.size():
		if campaign[i].id == id:
			return i
	return -1

static func is_cleared(data: Dictionary, id: String) -> bool:
	return bool(data.campaign.cleared.get(id, false))

func is_unlocked(data: Dictionary, index: int) -> bool:
	return index == 0 or (index > 0 and index < campaign.size() and is_cleared(data, campaign[index - 1].id))

## First uncleared level (or the last level if all are cleared).
func next_level_index(data: Dictionary) -> int:
	for i in campaign.size():
		if not is_cleared(data, campaign[i].id):
			return i
	return campaign.size() - 1

func cleared_count(data: Dictionary) -> int:
	var n := 0
	for l in campaign:
		if is_cleared(data, l.id):
			n += 1
	return n

func total_stars(data: Dictionary) -> int:
	var n := 0
	for k in data.campaign.stars:
		n += int(data.campaign.stars[k])
	return n

## Records a campaign win. Returns {first_clear, tokens, best_stars, improved}.
static func record_win(data: Dictionary, id: String, stars: int) -> Dictionary:
	var first := not is_cleared(data, id)
	var prev := int(data.campaign.stars.get(id, 0))
	var out := {"first_clear": first, "tokens": 0, "best_stars": maxi(prev, stars), "improved": stars > prev}
	data.campaign.cleared[id] = true
	data.campaign.stars[id] = maxi(prev, stars)
	if first:
		data.tokens = int(data.tokens) + Restoration.TOKENS_PER_FIRST_CLEAR
		data.tokens_earned = int(data.tokens_earned) + Restoration.TOKENS_PER_FIRST_CLEAR
		out.tokens = Restoration.TOKENS_PER_FIRST_CLEAR
	return out

# --- Daily challenge -------------------------------------------------------
# Basis: the DEVICE'S LOCAL CALENDAR DATE (resets at local midnight). The same
# app version and date always yield the same puzzle. Device clocks can be
# changed offline; daily rewards are cosmetic records only (no tokens).

const DAILY_SALT := "tinystreet-daily-v1"

static func date_key(unix_local: Dictionary) -> String:
	return "%04d-%02d-%02d" % [unix_local.year, unix_local.month, unix_local.day]

static func today_key() -> String:
	return date_key(Time.get_date_dict_from_system(false))

func daily_index_for(date_key_str: String) -> int:
	if daily_pool.is_empty():
		return -1
	var parts := date_key_str.split("-")
	var days := int(Time.get_unix_time_from_datetime_dict({"year": int(parts[0]),
		"month": int(parts[1]), "day": int(parts[2]), "hour": 12}) / 86400)
	# A fixed salted permutation so consecutive days don't walk the pool in order.
	var order: Array = range(daily_pool.size())
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(DAILY_SALT)
	for i in range(order.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var t = order[i]; order[i] = order[j]; order[j] = t
	return order[posmod(days, order.size())]

func daily_level_id(date_key_str: String) -> String:
	var i := daily_index_for(date_key_str)
	return daily_pool[i].id if i >= 0 else ""

static func is_daily_done(data: Dictionary, date_key_str: String) -> bool:
	return data.daily.completed.has(date_key_str)

## Returns true only the first time a date is recorded.
static func record_daily(data: Dictionary, date_key_str: String, stars: int, moves: int) -> bool:
	if is_daily_done(data, date_key_str):
		var prev: Dictionary = data.daily.completed[date_key_str]
		prev.stars = maxi(int(prev.get("stars", 0)), stars)
		return false
	data.daily.completed[date_key_str] = {"stars": stars, "moves": moves}
	return true

static func daily_streak(data: Dictionary, today: String) -> int:
	var n := 0
	var t := Time.get_unix_time_from_datetime_string(today + "T12:00:00")
	while data.daily.completed.has(Time.get_date_string_from_unix_time(t - n * 86400)):
		n += 1
	return n

## Share text contains no names, device ids or personal data.
static func share_text(date_key_str: String, stars: int, moves: int) -> String:
	var s := ""
	for i in 3:
		s += "★" if i < stars else "☆"
	return Loc.t("share_card", [date_key_str, s, moves])
