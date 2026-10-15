class_name BillingService
extends Node
## In-app purchase adapter interface. The base class is the DISABLED
## implementation: no products, shop hidden. Purchase states reported through
## `purchase_event(sku, state, ref)`:
##   "pending", "purchased", "cancelled", "failed", "already_owned",
##   "restored", "revoked"
## `ref` is an opaque, non-sensitive reference (hash of the token, never the token).

signal products_ready(products: Dictionary)   # sku -> {title, price}
signal purchase_event(sku: String, state: String, ref: String)

## Catalogue. Non-consumable cosmetic theme only (no subscriptions, no loot boxes).
const CATALOG := {
	"theme_evening": {"type": "non_consumable"},
}

func kind() -> String:
	return "disabled"

func is_available() -> bool:
	return false

func is_simulated() -> bool:
	return false

func connect_store() -> void:
	pass

func query_products() -> void:
	products_ready.emit.call_deferred({})

func purchase(sku: String) -> void:
	purchase_event.emit.call_deferred(sku, "failed", "")

## Re-queries owned purchases; emits "restored" for owned and "revoked" for
## cached entitlements no longer owned (only on a successful query).
func restore() -> void:
	pass
