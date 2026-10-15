class_name AdService
extends Node
## Rewarded/interstitial advertising adapter interface. The base class is the
## DISABLED implementation: nothing is ever available and no SDK is touched.
##
## Contract for implementations:
##  - show_rewarded(request_id, placement) never starts on its own; the UI calls
##    it only after an explicit player tap.
##  - reward_earned(request_id) is emitted ONLY from the provider's confirmed
##    reward callback (at most once per request id).
##  - rewarded_closed(request_id, outcome) is emitted exactly once per request,
##    outcome in: "completed", "cancelled", "no_fill", "failed", "offline", "timeout".

signal reward_earned(request_id: String)
signal rewarded_closed(request_id: String, outcome: String)

func kind() -> String:
	return "disabled"

func initialize(_can_request_ads: bool) -> void:
	pass

func is_rewarded_available() -> bool:
	return false

func show_rewarded(request_id: String, _placement: String) -> void:
	rewarded_closed.emit.call_deferred(request_id, "failed")

## Interstitials are disabled by default in every shipped configuration.
func interstitials_enabled() -> bool:
	return false

func show_interstitial() -> void:
	pass
