class_name Analytics
extends RefCounted
## Analytics adapter. This build ships ONLY the development logger: events are
## kept in a local in-memory ring buffer (and printed in debug builds). Nothing
## is transmitted. A production provider would plug in at `_send` and must be
## gated on consent (data.consent.analytics).
##
## Parameters are non-personal: version, level id, duration, moves, outcome.
## Never pass purchase tokens, device ids or free text.

const RING := 200
const FORBIDDEN_KEYS := ["token", "purchase_token", "email", "device_id", "name"]

var app: Node
var buffer: Array = []
var sent_ids := {}   # de-duplication of one-shot events (completion, revenue)

func _init(a: Node = null) -> void:
	app = a

func event(name: String, params: Dictionary = {}) -> void:
	var p := params.duplicate()
	for k in FORBIDDEN_KEYS:
		p.erase(k)
	p["v"] = "0.1.0"
	var rec := {"t": Time.get_unix_time_from_system(), "e": name, "p": p}
	buffer.append(rec)
	if buffer.size() > RING:
		buffer.pop_front()
	if OS.is_debug_build():
		print("[analytics] ", name, " ", p)
	_send(rec)

## Emits only once per `dedupe_id` (e.g. attempt id + "complete").
func event_once(dedupe_id: String, name: String, params: Dictionary = {}) -> bool:
	if sent_ids.has(dedupe_id):
		return false
	sent_ids[dedupe_id] = true
	event(name, params)
	return true

func count(name: String) -> int:
	return buffer.filter(func(r): return r.e == name).size()

func _send(_rec: Dictionary) -> void:
	pass # no production provider configured (see PRIVACY.md)
