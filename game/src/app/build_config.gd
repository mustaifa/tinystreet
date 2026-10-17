class_name BuildConfig
extends RefCounted
## Which service implementations a build uses. Decided by export feature tags:
##   debug builds / editor  -> simulated ads + simulated billing (clearly labelled)
##   "monetization" feature -> AdMob with Google's OFFICIAL TEST ad unit IDs;
##                             Play Billing adapter compiled in but REAL PURCHASES
##                             stay disabled (no server verification configured)
##   plain release          -> ads disabled, billing disabled, shop hidden
## Interstitials are disabled in every configuration.

# Google's published sample/test IDs (safe for development, never earn revenue).
const ADMOB_TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"
const ADMOB_TEST_REWARDED_ID := "ca-app-pub-3940256099942544/5224354917"

## Real-money purchasing requires server-side purchase verification
## (Play Developer API) which is NOT configured. Keep false until it is.
const REAL_PURCHASES_ENABLED := false
const INTERSTITIALS_ENABLED := false

## Art/sound/colour skin (see ArtSkin, docs/ART_PIPELINE.md). A future
## seasonal or purchased theme sets `settings.skin`; `--skin=<id>` previews one.
const DEFAULT_SKIN := "default"

static var force_profile := ""   # tests may set "dev" / "release"

static func is_dev() -> bool:
	if force_profile != "":
		return force_profile == "dev"
	return OS.is_debug_build()

static func wants_admob() -> bool:
	return OS.has_feature("monetization") and Engine.has_singleton("PoingGodotAdMob")

static func wants_play_billing() -> bool:
	return REAL_PURCHASES_ENABLED and OS.has_feature("monetization") \
		and Engine.has_singleton("GodotGooglePlayBilling")

## QA builds only (export preset with the custom feature "qa", never the
## player APK): every Delivery Logic level is open for review.
static func qa_unlock_all() -> bool:
	return OS.has_feature("qa")

static func skin_id(settings: Dictionary) -> String:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--skin="):
			return a.substr(7)
	var s := str(settings.get("skin", ""))
	return s if s != "" else DEFAULT_SKIN
