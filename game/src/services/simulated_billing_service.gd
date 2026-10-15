class_name SimulatedBillingService
extends BillingService
## DEVELOPMENT ONLY. Labelled "TEST STORE — simulated, no charge" in the UI.
## Lets QA drive every purchase state. Never used in release builds and never
## presented as real billing.

var owned := {}
var next_state := "purchased"   # tests/QA: pending, cancelled, failed, already_owned
var _seq := 0

func kind() -> String:
	return "simulated"

func is_available() -> bool:
	return true

func is_simulated() -> bool:
	return true

func query_products() -> void:
	products_ready.emit.call_deferred({"theme_evening": {"title": "Evening Lights theme", "price": "TEST"}})

func purchase(sku: String) -> void:
	_seq += 1
	var ref := ("sim-%s-%d" % [sku, _seq]).sha256_text().substr(0, 16)
	var st := next_state
	if owned.has(sku) and st == "purchased":
		st = "already_owned"
	if st == "purchased":
		owned[sku] = ref
	purchase_event.emit.call_deferred(sku, st, ref)

## QA helper: complete a pending purchase later (mirrors Play's pending flow).
func complete_pending(sku: String) -> void:
	owned[sku] = "sim-pending-" + sku
	purchase_event.emit(sku, "purchased", ("pend-" + sku).sha256_text().substr(0, 16))

func revoke(sku: String) -> void:
	owned.erase(sku)
	purchase_event.emit(sku, "revoked", "")

func restore() -> void:
	for sku in owned:
		purchase_event.emit.call_deferred(sku, "restored", str(owned[sku]))
