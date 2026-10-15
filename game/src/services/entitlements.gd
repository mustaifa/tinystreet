class_name Entitlements
extends RefCounted
## Applies purchase events to the persisted entitlement cache idempotently.
## data.purchases.owned[sku]   -> true when the entitlement is active
## data.purchases.pending[sku] -> true while a purchase awaits completion
## data.purchases.handled[ref] -> refs already processed (duplicate callbacks)

signal changed(sku: String, state: String)

var app: Node

func _init(a: Node) -> void:
	app = a
	app.billing.purchase_event.connect(on_event)
	app.billing.connect_store()

func refresh() -> void:
	if app.billing.is_available():
		app.billing.restore()

func owns(sku: String) -> bool:
	return bool(app.data.purchases.owned.get(sku, false))

func on_event(sku: String, state: String, ref: String) -> void:
	var p: Dictionary = app.data.purchases
	match state:
		"purchased", "restored", "already_owned":
			if ref != "" and p.handled.has(ref) and owns(sku):
				return # duplicate callback
			var newly := not owns(sku)
			p.owned[sku] = true
			p.pending.erase(sku)
			if ref != "":
				p.handled[ref] = true
			if newly and state == "purchased":
				app.analytics.event_once("purchase-" + ref, "purchase_result",
					{"sku": sku, "result": "success", "simulated": app.billing.is_simulated()})
		"pending":
			p.pending[sku] = true
			app.analytics.event("purchase_result", {"sku": sku, "result": "pending"})
		"revoked":
			p.owned.erase(sku)
			p.pending.erase(sku)
			app.analytics.event("purchase_result", {"sku": sku, "result": "revoked"})
		"cancelled", "failed":
			app.analytics.event("purchase_result", {"sku": sku, "result": state})
	app.save_now()
	changed.emit(sku, state)
