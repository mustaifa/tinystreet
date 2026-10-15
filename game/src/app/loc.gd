class_name Loc
extends RefCounted
## Externalised UI strings. Files: res://data/i18n/<lang>.json (flat key map).
## Missing keys fall back to English, then to the key itself (never crash).

const LANGS := ["en", "ar"]
const RTL := ["ar"]

static var lang := "en"
static var _tables := {}

static func _table(l: String) -> Dictionary:
	if not _tables.has(l):
		var p := "res://data/i18n/%s.json" % l
		var d = JSON.parse_string(FileAccess.get_file_as_string(p)) if FileAccess.file_exists(p) else {}
		_tables[l] = d if typeof(d) == TYPE_DICTIONARY else {}
	return _tables[l]

static func set_lang(l: String) -> void:
	lang = l if l in LANGS else "en"

static func is_rtl() -> bool:
	return lang in RTL

## Device language if supported, else English.
static func detect() -> String:
	var os := OS.get_locale_language()
	return os if os in LANGS else "en"

## Translate `key`; `args` may be an Array (positional %s) or Dictionary ({name}).
static func t(key: String, args = null) -> String:
	var s = _table(lang).get(key, _table("en").get(key, key))
	s = str(s)
	if args is Array and not args.is_empty():
		s = s % args
	elif args is Dictionary:
		s = s.format(args)
	if lang == "ar":
		s = _arabic_digits(s)
	return s

static func has_key(key: String, l: String = "en") -> bool:
	return _table(l).has(key)

static func keys(l: String = "en") -> Array:
	return _table(l).keys()

## Numbers inside Arabic strings are kept as Western digits for readability in
## the game UI (a common choice in Gulf/Maghreb apps). Hook kept for review.
static func _arabic_digits(s: String) -> String:
	return s
