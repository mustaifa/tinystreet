@tool
extends EditorExportPlugin
## Only presets whose custom features include "monetization" receive the ad and
## billing libraries; every other preset ships without any ad SDK.

const LIBS := "res://addons/tinystreet_monetization/libs/"
const ADMOB_TEST_APP_ID := "ca-app-pub-3940256099942544~3347511713"

func _get_name() -> String:
	return "TinyStreetMonetization"

func _supports_platform(platform: EditorExportPlatform) -> bool:
	return platform is EditorExportPlatformAndroid

func _enabled() -> bool:
	var p := get_export_preset()
	return p != null and "monetization" in p.get_custom_features()

func _get_android_libraries(_platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
	if not _enabled():
		return PackedStringArray()
	var v := "debug" if debug else "release"
	return PackedStringArray([
		LIBS + "poing-godot-admob-ads-%s.aar" % v,
		LIBS + "poing-godot-admob-core-%s.aar" % v,
		LIBS + "GodotGooglePlayBilling-%s.aar" % v,
	])

func _get_android_dependencies(_platform: EditorExportPlatform, _debug: bool) -> PackedStringArray:
	if not _enabled():
		return PackedStringArray()
	return PackedStringArray([
		"com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.4.0",
		"androidx.constraintlayout:constraintlayout:2.2.0",
		"com.android.billingclient:billing-ktx:9.1.0",
	])

func _get_android_manifest_application_element_contents(_platform: EditorExportPlatform, _debug: bool) -> String:
	if not _enabled():
		return ""
	# Google's sample App ID. A real AdMob App ID is a release blocker.
	return '\n<meta-data android:name="com.google.android.gms.ads.APPLICATION_ID" android:value="%s"/>\n' % ADMOB_TEST_APP_ID
