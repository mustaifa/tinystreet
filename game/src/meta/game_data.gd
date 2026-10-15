class_name GameData
extends RefCounted
## Shape of the persisted save payload. `sanitize` repairs missing or wrongly
## typed fields so a partially valid save never crashes the game.

static func fresh() -> Dictionary:
	return {
		"settings": {"music": 0.6, "sfx": 0.9, "haptics": true, "reduced_motion": false,
			"lang": "", "large_text": false},
		"tutorial": {"done": {}},
		"campaign": {"stars": {}, "cleared": {}},
		"tokens": 0,
		"tokens_earned": 0,
		"restoration": {"milestones": 0, "choices": {}},
		"daily": {"completed": {}},
		"current": {},
		"purchases": {"owned": {}, "pending": {}, "handled": {}},
		"rewards": {"handled": {}},
		"consent": {"analytics": false, "asked": false},
		"analytics": {"first_launch": false, "sent_once": {}},
		"stats": {"sessions": 0, "levels_played": 0},
	}

static func sanitize(d: Dictionary) -> Dictionary:
	var out := _merge(fresh(), d)
	# Clamp values that must stay in range.
	out.tokens = maxi(0, out.tokens)
	out.restoration.milestones = clampi(int(out.restoration.milestones), 0, Restoration.MILESTONES.size())
	for v in ["music", "sfx"]:
		out.settings[v] = clampf(out.settings[v], 0.0, 1.0)
	return out

## Keeps keys/types of `template`, taking values from `src` when type-compatible.
static func _merge(template: Dictionary, src: Dictionary) -> Dictionary:
	var out := {}
	for k in template:
		var tv = template[k]
		if not src.has(k):
			out[k] = tv
			continue
		var sv = src[k]
		if typeof(tv) == TYPE_DICTIONARY:
			if typeof(sv) != TYPE_DICTIONARY:
				out[k] = tv
			elif tv.is_empty():
				out[k] = sv # free-form maps (stars, choices...) keep their content
			else:
				out[k] = _merge(tv, sv)
		elif typeof(tv) in [TYPE_INT, TYPE_FLOAT] and typeof(sv) in [TYPE_INT, TYPE_FLOAT]:
			out[k] = int(sv) if typeof(tv) == TYPE_INT else float(sv)
		elif typeof(tv) == typeof(sv):
			out[k] = sv
		else:
			out[k] = tv
	return out
