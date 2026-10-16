class_name Wallet
extends RefCounted
## Restoration tokens with an idempotent grant ledger. Every reward has a
## stable key ("star:c004:2", "task:2026-10-16:orders", "ach:first_steps");
## a key can pay out once, ever. Reloading, replaying or double-tapping can't
## duplicate a reward, because the ledger is saved in the same atomic write as
## the balance.

## Grants `amount` once for `key`. Returns true if this call paid out.
static func grant(data: Dictionary, key: String, amount: int) -> bool:
	if key == "" or amount <= 0 or data.grants.has(key):
		return false
	data.grants[key] = amount
	data.tokens = int(data.tokens) + amount
	data.tokens_earned = int(data.tokens_earned) + amount
	return true

static func has_grant(data: Dictionary, key: String) -> bool:
	return data.grants.has(key)

static func spend(data: Dictionary, amount: int) -> bool:
	if amount < 0 or int(data.tokens) < amount:
		return false
	data.tokens = int(data.tokens) - amount
	return true

## Star tokens: one per star, keyed per level and star index, so a replay
## that improves 1★ -> 3★ pays exactly 2 more and repeats pay nothing.
static func grant_stars(data: Dictionary, level_id: String, stars: int) -> int:
	var paid := 0
	for k in range(1, clampi(stars, 0, 3) + 1):
		if grant(data, "star:%s:%d" % [level_id, k], 1):
			paid += 1
	return paid
