extends Node
## Global application service (autoload "App").
## Owns the save payload, progression, services and screen navigation.
## Services are created by `ServiceFactory` from BuildConfig and can be
## replaced in tests (simple dependency injection).

signal data_changed
signal language_changed
signal settings_changed

const VERSION := "0.5.0"

var data: Dictionary = {}
var store: SaveStore
var progression := Progression.new()
var ads: AdService
var billing: BillingService
var analytics: Analytics
var consent: ConsentService
var rewards: RewardBroker
var entitlements: Entitlements
var audio: AudioManager
var theme: Theme
var main: Node               # main.gd host (screens + overlays)
var session_started_at := 0
var load_notice := ""         # shown once if the save had to be recovered
var rush: RushRun             # optional Café Rush in progress (memory only)

var _save_pending := false
var _save_timer: Timer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	get_tree().set_auto_accept_quit(false)
	get_tree().set_quit_on_go_back(false)
	_save_timer = Timer.new()
	_save_timer.one_shot = true
	_save_timer.wait_time = 0.6
	_save_timer.timeout.connect(save_now)
	add_child(_save_timer)

## Called by boot. `save_path` and `services` are injectable for tests.
func boot(save_path: String = "user://save.json", services: Dictionary = {}) -> void:
	store = SaveStore.new(save_path)
	data = store.load_data()
	if store.last_load_source in ["tmp", "backup"]:
		load_notice = "save_recovered"
	elif store.last_load_source == "fresh" and store.last_load_issue.contains("corrupt"):
		load_notice = "save_reset"
	progression.load_levels()
	# Today's café tasks exist before any play, so every win counts.
	Tasks.refresh(data, Progression.today_key(), Meta.seen_mechanics(data, progression))
	if str(data.settings.lang) == "":
		data.settings.lang = Loc.detect()
	Loc.set_lang(data.settings.lang)
	Style.text_scale = 1.15 if data.settings.large_text else 1.0
	theme = Style.build_theme()
	get_tree().root.theme = theme
	var made := ServiceFactory.create(self, services)
	analytics = made.analytics
	ads = made.ads
	billing = made.billing
	consent = made.consent
	for n in [ads, billing, consent]:
		if n.get_parent() == null:
			add_child(n)
	rewards = RewardBroker.new(self)
	entitlements = Entitlements.new(self)
	if audio == null:
		audio = AudioManager.new()
		add_child(audio)
	audio.apply_settings(data.settings)
	data.stats.sessions = int(data.stats.sessions) + 1
	session_started_at = Time.get_ticks_msec()
	if not data.analytics.first_launch:
		data.analytics.first_launch = true
		analytics.event("first_launch", {})
	analytics.event("session_start", {"session": data.stats.sessions})
	save_now()

## Debounced save for frequent small changes.
func save_soon() -> void:
	_save_pending = true
	_save_timer.start()

func save_now() -> void:
	_save_pending = false
	if store:
		store.save(data)
	data_changed.emit()

func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_PAUSED, NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_CLOSE_REQUEST:
			if main and main.has_method("persist_current"):
				main.persist_current()
			save_now()
			if what == NOTIFICATION_WM_CLOSE_REQUEST:
				get_tree().quit()
		NOTIFICATION_APPLICATION_RESUMED:
			if rewards:
				rewards.on_app_resumed()
			if entitlements:
				entitlements.refresh()
		NOTIFICATION_WM_GO_BACK_REQUEST:
			if main:
				main.handle_back()

# --- settings ---------------------------------------------------------------

func set_setting(key: String, value) -> void:
	data.settings[key] = value
	match key:
		"lang":
			Loc.set_lang(value)
			theme = Style.build_theme()
			get_tree().root.theme = theme
			language_changed.emit()
		"large_text":
			Style.text_scale = 1.15 if value else 1.0
			theme = Style.build_theme()
			get_tree().root.theme = theme
			language_changed.emit() # forces screens to rebuild with new sizes
		"music", "sfx":
			audio.apply_settings(data.settings)
	settings_changed.emit()
	save_soon()

func reduced_motion() -> bool:
	return bool(data.settings.reduced_motion)

## Animation duration helper: reduced motion collapses movement to near-instant.
func dur(seconds: float) -> float:
	return 0.01 if reduced_motion() else seconds

func haptic(ms: int = 18) -> void:
	if bool(data.settings.haptics) and OS.has_feature("mobile"):
		Input.vibrate_handheld(ms)

## Sharing: Godot has no built-in Android share sheet. We copy the (personal-
## data-free) text to the clipboard and tell the player. Returns "clipboard".
func share_text(text: String) -> String:
	DisplayServer.clipboard_set(text)
	return "clipboard"

func is_dev_build() -> bool:
	return BuildConfig.is_dev()

# --- Café Rush ------------------------------------------------------------------

func goto_rush_level() -> void:
	if rush == null or rush.current_id() == "":
		return
	if main.current_name() == "game":
		main.replace("game", {"kind": "rush", "id": rush.current_id()})
	else:
		main.goto("game", {"kind": "rush", "id": rush.current_id()})

func on_rush_win() -> void:
	if rush == null:
		return
	if not rush.advance():
		goto_rush_level()
		return
	var best := rush.record(data)
	var t := RushRun.fmt_time(int(rush.elapsed_ms))
	var news := Achievements.take_new(data)
	analytics.event("rush_complete", {"ms": int(rush.elapsed_ms)})
	save_now()
	rush = null
	var body := Loc.t("rush_done_body", [t]) + ("\n" + Loc.t("rush_new_best") if best else "")
	for a in news:
		body += "\n" + Loc.t("ach_unlocked", [Loc.t("ach_" + str(a))])
	main.show_overlay(Dialog.make(Loc.t("rush_done_title"), body, [
		[Loc.t("rush_again"), func():
			rush = RushRun.create(progression.daily_pool, int(Time.get_unix_time_from_system()))
			goto_rush_level(), "WarmButton"],
		[Loc.t("challenges"), func(): main.goto("home", {}, false); main.goto("daily"), "SecondaryButton"],
	], null, "bolt"))
