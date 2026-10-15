class_name ServiceFactory
extends RefCounted
## Builds the service graph. `overrides` (tests) may supply any of:
## analytics, ads, billing, consent.

static func create(app: Node, overrides: Dictionary = {}) -> Dictionary:
	var out := {}
	out.analytics = overrides.get("analytics", Analytics.new(app))
	if overrides.has("ads"):
		out.ads = overrides.ads
	elif BuildConfig.wants_admob():
		out.ads = AdMobAdService.new()
	elif BuildConfig.is_dev():
		out.ads = SimulatedAdService.new()
	else:
		out.ads = AdService.new()
	if overrides.has("billing"):
		out.billing = overrides.billing
	elif BuildConfig.wants_play_billing():
		out.billing = PlayBillingService.new()
	elif BuildConfig.is_dev():
		out.billing = SimulatedBillingService.new()
	else:
		out.billing = BillingService.new()
	out.consent = overrides.get("consent", ConsentService.new(out.ads.kind() == "admob"))
	return out
