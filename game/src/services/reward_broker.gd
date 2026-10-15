class_name RewardBroker
extends RefCounted
## Turns rewarded-ad callbacks into game rewards exactly once.
## - A reward is granted only on the provider's reward callback.
## - Each request id is processed at most once (idempotent; duplicate callbacks
##   are ignored).
## - The caller is told the final outcome so the UI never hangs.

signal finished(request_id: String, placement: String, granted: bool, outcome: String)

var app: Node
var _pending := {}   # request_id -> {placement, cb: Callable, granted}
var _seq := 0

func _init(a: Node) -> void:
	app = a
	app.ads.reward_earned.connect(_on_earned)
	app.ads.rewarded_closed.connect(_on_closed)

func available() -> bool:
	return app.ads.is_rewarded_available()

## `on_grant` runs once if and when the reward is confirmed.
func request(placement: String, on_grant: Callable) -> String:
	_seq += 1
	var id := "%s-%d-%d" % [placement, Time.get_ticks_msec(), _seq]
	_pending[id] = {"placement": placement, "cb": on_grant, "granted": false}
	app.analytics.event("ad_offered", {"placement": placement})
	app.ads.show_rewarded(id, placement)
	return id

func _on_earned(id: String) -> void:
	if not _pending.has(id) or _pending[id].granted:
		return # unknown or duplicate callback
	if app.data.rewards.handled.has(id):
		return
	_pending[id].granted = true
	app.data.rewards.handled[id] = true
	_trim_handled()
	app.analytics.event("ad_reward_granted", {"placement": _pending[id].placement})
	_pending[id].cb.call()
	app.save_soon()

func _on_closed(id: String, outcome: String) -> void:
	if not _pending.has(id):
		return
	var p: Dictionary = _pending[id]
	_pending.erase(id)
	if outcome == "completed":
		app.analytics.event("ad_completed", {"placement": p.placement})
	finished.emit(id, p.placement, p.granted, outcome)

func on_app_resumed() -> void:
	pass # providers deliver their callbacks after resume; nothing to fake here

func _trim_handled() -> void:
	var h: Dictionary = app.data.rewards.handled
	if h.size() > 200:
		var keys := h.keys()
		for i in keys.size() - 200:
			h.erase(keys[i])
