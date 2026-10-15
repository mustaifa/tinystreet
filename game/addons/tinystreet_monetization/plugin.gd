@tool
extends EditorPlugin
## Registers the export plugin. Vendored binaries (MIT):
##  - Poing Studios godot-admob-plugin v5.1.0 (ads + core AARs)
##    -> Google Mobile Ads SDK com.google.android.libraries.ads.mobile.sdk:ads-mobile-sdk:1.4.0
##  - godot-sdk-integrations/godot-google-play-billing 3.3.0
##    -> com.android.billingclient:billing-ktx:9.1.0

var _exp: EditorExportPlugin

func _enter_tree() -> void:
	_exp = preload("res://addons/tinystreet_monetization/export_plugin.gd").new()
	add_export_plugin(_exp)

func _exit_tree() -> void:
	remove_export_plugin(_exp)
	_exp = null
