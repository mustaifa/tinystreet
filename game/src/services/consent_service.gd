class_name ConsentService
extends Node
## Consent flow. When the AdMob SDK is present we run Google's User Messaging
## Platform (UMP): request consent info -> show the form if required -> only
## then allow ad requests. Without an ad SDK no consent is needed because the
## game collects and transmits nothing.

signal finished(can_request_ads: bool)

var uses_ump := false
var can_request_ads := false
var privacy_options_required := false
var _ci: Object
var _ump: Object

func _init(with_ump: bool = false) -> void:
	uses_ump = with_ump

func start() -> void:
	if not uses_ump:
		can_request_ads = false
		finished.emit.call_deferred(false)
		return
	_ci = Engine.get_singleton("PoingGodotAdMobConsentInformation")
	_ump = Engine.get_singleton("PoingGodotAdMobUserMessagingPlatform")
	if _ci == null or _ump == null:
		finished.emit.call_deferred(false)
		return
	_ci.connect("on_consent_info_updated_success", _on_info_ok, CONNECT_ONE_SHOT)
	_ci.connect("on_consent_info_updated_failure", _on_info_fail, CONNECT_ONE_SHOT)
	_ci.update({"tag_for_under_age_of_consent": false, "consent_debug_settings": null})

func _on_info_ok() -> void:
	if _ci.get_is_consent_form_available() and int(_ci.get_consent_status()) == 2: # REQUIRED
		_ump.connect("on_consent_form_load_success_listener", _on_form_loaded, CONNECT_ONE_SHOT)
		_ump.connect("on_consent_form_load_failure_listener", func(_e): _done(), CONNECT_ONE_SHOT)
		_ump.load_consent_form()
	else:
		_done()

func _on_info_fail(_err) -> void:
	_done() # can_request_ads reflects any previously stored consent

func _on_form_loaded(uid: int) -> void:
	# The UMP singleton also owns loaded forms (addressed by uid).
	_ump.connect("on_consent_form_dismissed", func(_u, _e): _done(), CONNECT_ONE_SHOT)
	_ump.show(uid)

func _done() -> void:
	# Consent status 1 = NOT_REQUIRED, 3 = OBTAINED (UMP ConsentStatus enum).
	var st := int(_ci.get_consent_status()) if _ci else 0
	can_request_ads = st == 1 or st == 3
	privacy_options_required = _ci != null and int(_ci.get_privacy_options_requirement_status()) == 2
	finished.emit(can_request_ads)

## Re-open the privacy choices form (required entry point in settings).
func show_privacy_options() -> void:
	if _ump:
		_ump.show_privacy_options_form()
