class_name AdMobAdService
extends AdService
## Rewarded ads through the Poing Studios AdMob Android plugin (v5.1.0, MIT),
## driven via its JNI singletons. Uses Google's OFFICIAL TEST ad unit only.
## STATUS: compiled into "monetization" builds; not verified on a device with
## Google Play services in this environment (see TEST_REPORT.md).

const LOAD_TIMEOUT_S := 20.0

var _admob: Object
var _rw: Object
var _uid := -1
var _loaded := false
var _loading := false
var _active := ""
var _earned := false
var _can_request := false
var _timer: Timer

func kind() -> String:
	return "admob"

func initialize(can_request_ads: bool) -> void:
	_can_request = can_request_ads
	_admob = Engine.get_singleton("PoingGodotAdMob")
	_rw = Engine.get_singleton("PoingGodotAdMobRewardedAd")
	_timer = Timer.new()
	_timer.one_shot = true
	_timer.timeout.connect(_on_timeout)
	add_child(_timer)
	if _admob == null or _rw == null or not _can_request:
		return
	_admob.initialize()
	_rw.connect("on_rewarded_ad_loaded", _on_loaded)
	_rw.connect("on_rewarded_ad_failed_to_load", _on_load_failed)
	_rw.connect("on_rewarded_ad_user_earned_reward", _on_earned)
	_rw.connect("on_rewarded_ad_dismissed_full_screen_content", _on_dismissed)
	_rw.connect("on_rewarded_ad_failed_to_show_full_screen_content", _on_show_failed)
	_preload()

func _preload() -> void:
	if _loading or _loaded or not _can_request:
		return
	_loading = true
	_uid = _rw.create()
	var req := {"mediation_extras": {}, "extras": {}, "google_request_agent": "Godot-PoingStudios-v5.1.0"}
	_rw.load(BuildConfig.ADMOB_TEST_REWARDED_ID, req, [], _uid)

func is_rewarded_available() -> bool:
	return _can_request and _rw != null

func show_rewarded(request_id: String, _placement: String) -> void:
	if not is_rewarded_available() or _active != "":
		rewarded_closed.emit.call_deferred(request_id, "failed")
		return
	_active = request_id
	_earned = false
	if _loaded:
		_rw.show(_uid)
	else:
		_preload()
		_timer.start(LOAD_TIMEOUT_S)  # wait for the load, then show

func _on_loaded(uid: int) -> void:
	if uid != _uid:
		return
	_loading = false
	_loaded = true
	if _active != "" and not _timer.is_stopped():
		_timer.stop()
		_rw.show(_uid)

func _on_load_failed(uid: int, err: Dictionary) -> void:
	if uid != _uid:
		return
	_loading = false
	_loaded = false
	if _active != "":
		_timer.stop()
		# AdMob error code 3 = NO_FILL, 2 = NETWORK_ERROR
		var code := int(err.get("code", -1))
		_close("no_fill" if code == 3 else ("offline" if code == 2 else "failed"))

func _on_earned(uid: int, _item: Dictionary) -> void:
	if uid == _uid and _active != "" and not _earned:
		_earned = true
		reward_earned.emit(_active)

func _on_dismissed(uid: int) -> void:
	if uid == _uid and _active != "":
		_close("completed" if _earned else "cancelled")

func _on_show_failed(uid: int, _err: Dictionary) -> void:
	if uid == _uid and _active != "":
		_close("failed")

func _on_timeout() -> void:
	if _active != "":
		_close("timeout")

func _close(outcome: String) -> void:
	var id := _active
	_active = ""
	if _loaded and _uid >= 0:
		_rw.destroy(_uid)
	_loaded = false
	_uid = -1
	rewarded_closed.emit(id, outcome)
	_preload()
