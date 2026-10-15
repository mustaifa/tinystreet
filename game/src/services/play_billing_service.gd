class_name PlayBillingService
extends BillingService
## Google Play Billing via godot-google-play-billing 3.3.0 (Billing Library
## 9.1.0, MIT). Only instantiated when BuildConfig.REAL_PURCHASES_ENABLED is
## true, which requires a server that verifies purchase tokens with the Google
## Play Developer API BEFORE granting entitlements. That server does not exist
## yet, so this path is DISABLED in every shipped configuration.
##
## Flow: connect -> query details -> purchase -> on_purchase_updated ->
## (verify on server) -> acknowledge non-consumables within 3 days -> grant.

const VERIFY_ENDPOINT := ""   # must be configured; never embed service-account keys here

var _p: Object
var _details := {}

func kind() -> String:
	return "play"

func is_available() -> bool:
	return _p != null and VERIFY_ENDPOINT != ""

func connect_store() -> void:
	_p = Engine.get_singleton("GodotGooglePlayBilling")
	if _p == null:
		return
	_p.initPlugin()
	_p.connect("connected", _on_connected)
	_p.connect("query_product_details_response", _on_details)
	_p.connect("query_purchases_response", _on_purchases)
	_p.connect("on_purchase_updated", _on_purchases)
	_p.connect("acknowledge_purchase_response", func(_r): pass)
	_p.startConnection()

func _on_connected() -> void:
	query_products()
	restore()

func query_products() -> void:
	if _p:
		_p.queryProductDetails(PackedStringArray(CATALOG.keys()), "inapp")

func _on_details(r: Dictionary) -> void:
	var out := {}
	if int(r.get("response_code", -1)) == 0:
		for d in r.get("product_details", []):
			out[d.get("product_id", "")] = {"title": d.get("name", ""),
				"price": d.get("one_time_purchase_offer_details", {}).get("formatted_price", "")}
	_details = out
	products_ready.emit(out)

func purchase(sku: String) -> void:
	if not is_available():
		purchase_event.emit.call_deferred(sku, "failed", "")
		return
	var r: Dictionary = _p.purchase(sku, "", "", false)
	if int(r.get("response_code", -1)) == 7:
		purchase_event.emit.call_deferred(sku, "already_owned", "")
	elif int(r.get("response_code", -1)) != 0:
		purchase_event.emit.call_deferred(sku, "failed", "")

func restore() -> void:
	if _p:
		_p.queryPurchases("inapp", false)

func _on_purchases(r: Dictionary) -> void:
	var code := int(r.get("response_code", -1))
	if code == 1:
		purchase_event.emit("", "cancelled", "")
		return
	if code != 0:
		purchase_event.emit("", "failed", "")
		return
	for pu in r.get("purchases", []):
		var token := str(pu.get("purchase_token", ""))
		var ref := token.sha256_text().substr(0, 16)  # never log/store the raw token
		var state := int(pu.get("purchase_state", 0))
		for sku in pu.get("product_ids", []):
			if state == 2:
				purchase_event.emit(sku, "pending", ref)
			elif state == 1:
				# Server-side verification is REQUIRED here before granting.
				# Not configured -> do not grant (is_available() is false anyway).
				pass
