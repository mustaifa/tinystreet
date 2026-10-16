extends "res://tests/test_base.gd"
## Persistence, progression, economy, monetisation-callback and settings tests.

const DIR := "user://test_saves"
var tree: SceneTree

func setup_suite(t: SceneTree) -> void:
	tree = t
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(DIR))

func _store(name: String) -> SaveStore:
	var s := SaveStore.new(DIR + "/" + name + ".json")
	s.delete_all()
	return s

## Minimal stand-in for the App autoload exposing what services touch.
class FakeApp extends Node:
	var data := GameData.fresh()
	var analytics := Analytics.new()
	var ads: AdService
	var billing: BillingService
	var saves := 0
	func save_soon() -> void: saves += 1
	func save_now() -> void: saves += 1

# ------------------------------------------------------------------ saves

func test_save_roundtrip() -> void:
	var s := _store("rt")
	var d := GameData.fresh()
	d.tokens = 7
	d.campaign.stars["c001"] = 3
	d.settings.lang = "ar"
	check(s.save(d))
	var back := s.load_data()
	eq(s.last_load_source, "main")
	eq(back.tokens, 7)
	eq(int(back.campaign.stars["c001"]), 3)
	eq(back.settings.lang, "ar")

func test_fresh_install() -> void:
	var s := _store("fresh")
	var d := s.load_data()
	eq(s.last_load_source, "fresh")
	eq(d.tokens, 0)
	check(d.campaign.cleared.is_empty())

func test_corrupt_main_recovers_backup() -> void:
	var s := _store("corrupt")
	var d := GameData.fresh()
	d.tokens = 3
	s.save(d)            # becomes main
	d.tokens = 4
	s.save(d)            # previous main -> .bak, new main
	var f := FileAccess.open(s.path, FileAccess.WRITE)
	f.store_string("{\"schema\":2,\"sha256\":\"bad\",\"payload\":\"{}\"")  # truncated / bad checksum
	f.close()
	var back := s.load_data()
	eq(s.last_load_source, "backup")
	eq(back.tokens, 3)

func test_interrupted_save_uses_tmp() -> void:
	var s := _store("interrupt")
	var d := GameData.fresh()
	d.tokens = 9
	s.save(d)
	# Simulate a crash after the tmp was written and main moved to .bak but
	# before the final rename: main missing, tmp complete.
	DirAccess.rename_absolute(ProjectSettings.globalize_path(s.path), ProjectSettings.globalize_path(s.path + ".tmp"))
	var back := s.load_data()
	eq(s.last_load_source, "tmp")
	eq(back.tokens, 9)

func test_everything_corrupt_starts_fresh() -> void:
	var s := _store("allbad")
	for suffix in ["", ".tmp", ".bak"]:
		var f := FileAccess.open(s.path + suffix, FileAccess.WRITE)
		f.store_string("not json at all")
		f.close()
	var back := s.load_data()
	eq(s.last_load_source, "fresh")
	check(s.last_load_issue.contains("corrupt"))
	eq(back.tokens, 0)

func test_tampered_payload_detected() -> void:
	var s := _store("tamper")
	var d := GameData.fresh()
	s.save(d)
	var env = JSON.parse_string(FileAccess.get_file_as_string(s.path))
	env.payload = str(env.payload).replace("\"tokens\":0", "\"tokens\":999")
	var f := FileAccess.open(s.path, FileAccess.WRITE)
	f.store_string(JSON.stringify(env))
	f.close()
	var back := s.load_data()
	check(back.tokens != 999, "checksum mismatch rejected")

func test_migration_v1_to_v2() -> void:
	var s := _store("mig")
	var v1 := {"stars": [["c001", 2], ["c002", 3]], "tokens": 2, "settings": {"music": 0.2}}
	var payload := JSON.stringify(v1)
	var f := FileAccess.open(s.path, FileAccess.WRITE)
	f.store_string(JSON.stringify({"schema": 1, "sha256": payload.sha256_text(), "payload": payload}))
	f.close()
	var back := s.load_data()
	eq(int(back.campaign.stars["c002"]), 3)
	check(bool(back.campaign.cleared["c001"]))
	eq(back.tokens, 5, "v1 -> v3: 2+3 earned stars credited (never below the old 2)")
	check(Wallet.has_grant(back, "star:c002:3"), "earned stars recorded in the ledger")
	check(absf(back.settings.music - 0.2) < 0.001)
	check(back.daily.has("completed"), "new block added")

func test_sanitize_bad_types() -> void:
	var d := GameData.sanitize({"tokens": "lots", "settings": "loud", "restoration": {"steps": 99}, "tasks": {"list": "x"}})
	eq(d.tokens, 0)
	eq(typeof(d.settings), TYPE_DICTIONARY)
	eq(d.restoration.steps, Restoration.STEPS.size(), "clamped")
	eq(typeof(d.tasks.list), TYPE_ARRAY)

# ------------------------------------------------------------------ progression

func test_star_tokens_award_once_per_star() -> void:
	var d := GameData.fresh()
	var r1 := Progression.record_win(d, "c001", 1)
	var r2 := Progression.record_win(d, "c001", 3)
	var r3 := Progression.record_win(d, "c001", 2)
	var r4 := Progression.record_win(d, "c001", 3)
	check(r1.first_clear and r1.tokens == 1)
	check(not r2.first_clear and r2.tokens == 2 and r2.improved, "1★ -> 3★ pays the 2 new stars")
	eq(r3.best_stars, 3, "stars never decrease")
	eq(r3.tokens, 0)
	eq(r4.tokens, 0, "repeating a 3★ pays nothing")
	eq(d.tokens, 3)
	eq(d.tokens_earned, 3)

func test_campaign_tokens_cover_restoration() -> void:
	var p := Progression.new()
	p.load_levels()
	check(p.campaign.size() * 2 >= Restoration.total_cost(),
		"the whole café is reachable at an average of 2 stars, without tasks or achievements")
	check(Restoration.STEPS[0].cost <= 3, "first step affordable after one 3-star tutorial")

func test_restoration_unlock_flow() -> void:
	var d := GameData.fresh()
	check(not Restoration.can_unlock(d))
	d.tokens = 3
	eq(Restoration.unlock_next(d), "clean")
	eq(d.tokens, 0)
	eq(Restoration.unlock_next(d), "", "cannot unlock without tokens")
	check(not Restoration.set_choice(d, "walls", "sage"), "walls open with the walls step")
	d.tokens = 6
	eq(Restoration.unlock_next(d), "walls")
	check(Restoration.set_choice(d, "walls", "sage"))
	check(not Restoration.set_choice(d, "seating", "rattan"), "seating locked until its step")
	check(not Restoration.set_choice(d, "walls", "evening"), "premium option needs entitlement")
	d.purchases.owned["theme_evening"] = true
	check(Restoration.set_choice(d, "walls", "evening"))
	d.purchases.owned.erase("theme_evening")
	eq(Restoration.effective_choice(d, "walls"), "cream", "revoked option falls back to default")

func test_level_unlocking() -> void:
	var p := Progression.new()
	p.load_levels()
	var d := GameData.fresh()
	check(p.is_unlocked(d, 0))
	check(not p.is_unlocked(d, 1))
	Progression.record_win(d, p.campaign[0].id, 1)
	check(p.is_unlocked(d, 1))
	eq(p.next_level_index(d), 1)
	# v2 inserted levels: a v1 player who cleared c007 and c008 but not the new
	# f01 between them keeps c008 playable, and f01 opens (c006 cleared).
	var v1 := GameData.fresh()
	for id in ["c001", "c002", "c003", "c004", "c005", "c006", "c007", "c008"]:
		Progression.record_win(v1, id, 2)
	var f01 := p.campaign_index("f01")
	check(p.is_unlocked(v1, f01), "new level after a cleared one is open")
	check(p.is_unlocked(v1, p.campaign_index("c008")), "cleared v1 levels stay open")
	eq(p.next_level_index(v1), f01, "Play goes to the first new level")

func test_daily_deterministic_and_once() -> void:
	var p := Progression.new()
	p.load_levels()
	if p.daily_pool.is_empty():
		check(false, "daily pool missing")
		return
	eq(p.daily_level_id("2026-10-15"), p.daily_level_id("2026-10-15"), "same date same puzzle")
	var ids := {}
	for day in range(1, 29):
		ids[p.daily_level_id("2026-02-%02d" % day)] = true
	check(ids.size() > 20, "dates spread across the pool")
	var d := GameData.fresh()
	check(Progression.record_daily(d, "2026-10-15", 2, 30))
	check(not Progression.record_daily(d, "2026-10-15", 3, 25), "no double award")
	eq(int(d.daily.completed["2026-10-15"].stars), 3)
	eq(d.tokens, 0, "daily never awards tokens")
	Progression.record_daily(d, "2026-10-14", 1, 10)
	eq(Progression.daily_streak(d, "2026-10-15"), 2)

func test_share_text_has_no_personal_data() -> void:
	Loc.set_lang("en")
	var t := Progression.share_text("2026-10-15", 2, 31)
	check(t.contains("2026-10-15") and t.contains("31"))
	check(not t.contains(OS.get_unique_id()) or OS.get_unique_id() == "")

# ------------------------------------------------------------------ monetisation callbacks

func _fake_with_ads() -> Array:
	var app := FakeApp.new()
	var ads := SimulatedAdService.new()
	app.ads = ads
	app.add_child(ads)
	tree.root.add_child(app)
	return [app, ads, RewardBroker.new(app)]

func test_reward_only_on_confirmed_callback_and_once() -> void:
	var r := _fake_with_ads()
	var app: FakeApp = r[0]
	var ads: SimulatedAdService = r[1]
	var broker: RewardBroker = r[2]
	var granted := [0]
	var id := broker.request("hint", func(): granted[0] += 1)
	eq(granted[0], 0, "nothing granted before callback")
	ads.reward_earned.emit(id)
	ads.reward_earned.emit(id)      # duplicate callback
	ads.rewarded_closed.emit(id, "completed")
	ads.reward_earned.emit(id)      # late duplicate after close
	eq(granted[0], 1, "idempotent")
	check(app.data.rewards.handled.has(id))
	eq(app.analytics.count("ad_reward_granted"), 1)
	app.queue_free()

func test_reward_cancel_and_failures_grant_nothing() -> void:
	var r := _fake_with_ads()
	var app: FakeApp = r[0]
	var ads: SimulatedAdService = r[1]
	var broker: RewardBroker = r[2]
	var granted := [0]
	var outcomes: Array = []
	broker.finished.connect(func(_i, _p, g, o): outcomes.append([g, o]))
	var id := broker.request("continue", func(): granted[0] += 1)
	ads.rewarded_closed.emit(id, "cancelled")
	for o in ["no_fill", "offline", "timeout", "failed"]:
		var id2 := broker.request("hint", func(): granted[0] += 1)
		ads.rewarded_closed.emit(id2, o)
	ads.reward_earned.emit("unknown-id")
	eq(granted[0], 0)
	eq(outcomes.size(), 5)
	check(outcomes.all(func(x): return x[0] == false))
	app.queue_free()

func test_disabled_ads_report_failure() -> void:
	var app := FakeApp.new()
	app.ads = AdService.new()
	app.add_child(app.ads)
	tree.root.add_child(app)
	var broker := RewardBroker.new(app)
	check(not broker.available())
	var outcomes: Array = []
	broker.finished.connect(func(_i, _p, g, o): outcomes.append(o))
	broker.request("hint", func(): pass)
	await tree.process_frame
	await tree.process_frame
	eq(outcomes, ["failed"])
	app.queue_free()

func _fake_with_billing() -> Array:
	var app := FakeApp.new()
	var b := SimulatedBillingService.new()
	app.billing = b
	app.add_child(b)
	tree.root.add_child(app)
	return [app, b, Entitlements.new(app)]

func test_purchase_states() -> void:
	var r := _fake_with_billing()
	var app: FakeApp = r[0]
	var b: SimulatedBillingService = r[1]
	var ent: Entitlements = r[2]
	b.next_state = "cancelled"; b.purchase("theme_evening"); await tree.process_frame
	check(not ent.owns("theme_evening"), "cancelled grants nothing")
	b.next_state = "failed"; b.purchase("theme_evening"); await tree.process_frame
	check(not ent.owns("theme_evening"), "failed grants nothing")
	b.next_state = "pending"; b.purchase("theme_evening"); await tree.process_frame
	check(not ent.owns("theme_evening"), "pending grants nothing yet")
	check(bool(app.data.purchases.pending.get("theme_evening", false)))
	b.complete_pending("theme_evening")
	check(ent.owns("theme_evening"), "pending -> purchased grants")
	check(not app.data.purchases.pending.has("theme_evening"))
	b.next_state = "purchased"; b.purchase("theme_evening"); await tree.process_frame
	check(ent.owns("theme_evening"), "already owned stays owned")
	b.revoke("theme_evening")
	check(not ent.owns("theme_evening"), "refund/revoke removes entitlement")
	app.queue_free()

func test_duplicate_purchase_callbacks_and_restore() -> void:
	var r := _fake_with_billing()
	var app: FakeApp = r[0]
	var b: SimulatedBillingService = r[1]
	var ent: Entitlements = r[2]
	ent.on_event("theme_evening", "purchased", "ref1")
	ent.on_event("theme_evening", "purchased", "ref1")
	ent.on_event("theme_evening", "purchased", "ref1")
	eq(app.analytics.count("purchase_result"), 1, "revenue event not duplicated")
	app.data.purchases.owned.clear()       # e.g. fresh reinstall
	b.owned["theme_evening"] = "ref1"
	b.restore()
	await tree.process_frame
	check(ent.owns("theme_evening"), "restore re-grants")
	app.queue_free()

func test_purchase_ref_never_contains_raw_token() -> void:
	var app := FakeApp.new()
	app.billing = BillingService.new()
	app.add_child(app.billing)
	tree.root.add_child(app)
	var ent := Entitlements.new(app)
	ent.on_event("theme_evening", "purchased", "abc123")
	for rec in app.analytics.buffer:
		check(not str(rec).contains("token"), "no token keys in analytics")
	app.queue_free()

func test_release_profile_has_no_simulated_services() -> void:
	BuildConfig.force_profile = "release"
	var app := FakeApp.new()
	var made := ServiceFactory.create(app)
	eq(made.ads.kind(), "disabled")
	eq(made.billing.kind(), "disabled")
	check(not made.billing.is_available(), "shop hidden in release")
	BuildConfig.force_profile = "dev"
	var dev := ServiceFactory.create(app)
	eq(dev.ads.kind(), "simulated")
	BuildConfig.force_profile = ""
	for n in [made.ads, made.billing, made.consent, dev.ads, dev.billing, dev.consent]:
		n.free()
	app.free()

func test_analytics_dedupe_and_scrub() -> void:
	var a := Analytics.new()
	check(a.event_once("x", "level_complete", {"level": "c001"}))
	check(not a.event_once("x", "level_complete", {"level": "c001"}))
	a.event("purchase_result", {"token": "SECRET", "sku": "s"})
	eq(a.count("level_complete"), 1)
	check(not str(a.buffer).contains("SECRET"))

# ------------------------------------------------------------------ settings / language

func test_language_switch_and_persist() -> void:
	var s := _store("lang")
	var d := GameData.fresh()
	d.settings.lang = "ar"
	d.settings.large_text = true
	s.save(d)
	var back := s.load_data()
	Loc.set_lang(back.settings.lang)
	check(Loc.is_rtl())
	eq(Loc.t("undo"), "تراجع")
	Loc.set_lang("xx")
	eq(Loc.lang, "en", "unknown language falls back to English")
	eq(Loc.t("undo"), "Undo")
	check(bool(back.settings.large_text))

func test_string_tables_complete() -> void:
	for k in Loc.keys("en"):
		check(Loc.has_key(k, "ar"), "ar missing " + k)
		var a := str(Loc._table("en")[k]).count("%s")
		var b := str(Loc._table("ar")[k]).count("%s")
		eq(a, b, "placeholder count " + k)
	eq(Loc.t("definitely_missing_key"), "definitely_missing_key")
