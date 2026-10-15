extends Control
## Optional cosmetic shop. Only reachable when a billing service is available.
## In development builds the simulated store is labelled on screen and never
## charges; there is no real-money path until server verification exists.

var status: Label
var buy: Button

func setup(_p: Dictionary) -> void:
	var root := UI.vbox(16)
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)
	root.add_child(UI.header(Loc.t("shop"), func(): App.main.back()))
	if App.billing.is_simulated():
		var warn := UI.label(Loc.t("shop_simulated"), "HeaderLabel")
		warn.add_theme_color_override("font_color", Style.TERRACOTTA)
		root.add_child(UI.card(warn))
	if not App.billing.is_available():
		root.add_child(UI.label(Loc.t("shop_unavailable")))
		return
	var item := UI.vbox(10)
	item.add_child(UI.label(Loc.t("sku_theme_evening"), "HeaderLabel"))
	item.add_child(UI.label(Loc.t("sku_theme_evening_desc")))
	var preview := CafeView.new()
	preview.custom_minimum_size = Vector2(0, 300)
	preview.configure(5, {"wall": "evening", "seating": "evening", "plants": "flowers", "sign": "evening"})
	item.add_child(preview)
	buy = UI.button("", func(): App.billing.purchase("theme_evening"), "WarmButton")
	item.add_child(buy)
	status = UI.label("", "SoftLabel")
	item.add_child(status)
	root.add_child(UI.card(item))
	root.add_child(UI.button(Loc.t("restore_purchases"), func(): App.billing.restore(); App.main.toast(Loc.t("restoring")), "SecondaryButton"))
	root.add_child(UI.label(Loc.t("shop_note"), "SoftLabel"))
	App.entitlements.changed.connect(_on_changed)
	App.billing.products_ready.connect(_on_products)
	App.billing.query_products()
	_update()

func _update() -> void:
	if not is_instance_valid(buy):
		return
	var owned: bool = App.entitlements.owns("theme_evening")
	var pending := bool(App.data.purchases.pending.get("theme_evening", false))
	buy.disabled = owned or pending
	buy.text = Loc.t("owned") if owned else (Loc.t("pending") if pending else Loc.t("buy"))

func _on_changed(_sku: String, state: String) -> void:
	_update()
	if is_instance_valid(status):
		status.text = Loc.t("purchase_" + state)

func _on_products(_p: Dictionary) -> void:
	_update()
