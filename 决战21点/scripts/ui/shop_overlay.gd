class_name ShopOverlay
extends Control

signal shop_closed()
signal shop_purchase_made()

const BUTTON_HEIGHT: float = 36.0

var _shop: ShopSystem
var _combat: CombatState
var _chips: ChipEconomy
var _card_data: CardDataModel

var _inventory_items: Array[ShopItem] = []
var _all_cards: Array = []
var _displayed_cards: Array = []
var _selected_card_index: int = -1
var _rng: RandomNumberGenerator = RandomNumberGenerator.new()

const DISPLAYED_CARD_COUNT: int = 25

var _services_panel: VBoxContainer
var _heal_input: SpinBox
var _heal_button: Button
var _quality_option: OptionButton
var _quality_buy_button: Button
var _purify_button: Button
var _sell_button: Button

var _inventory_panel: VBoxContainer
var _inventory_grid: GridContainer
var _refresh_button: Button

var _card_selector_grid: GridContainer

var _detail_panel: VBoxContainer
var _detail_title: Label
var _detail_stamp: Label
var _detail_quality: Label
var _detail_stats: Label

var _chip_label: Label
var _close_button: Button
var _status_label: Label


func initialize(shop: ShopSystem, combat: CombatState, chips: ChipEconomy, card_data: CardDataModel) -> void:
	_shop = shop
	_combat = combat
	_chips = chips
	_card_data = card_data


func setup(inventory: Array[ShopItem], player_cards: Array) -> void:
	_inventory_items = inventory
	_all_cards = player_cards
	_selected_card_index = -1
	_pick_random_cards()
	_refresh_services_panel()
	_refresh_inventory_panel()
	_refresh_card_selector()
	_update_chip_label()
	_clear_status()
	_refresh_detail_panel()


func _pick_random_cards() -> void:
	_displayed_cards.clear()
	var pool: Array = _all_cards.duplicate()
	var count: int = mini(DISPLAYED_CARD_COUNT, pool.size())
	for _i in count:
		var idx: int = _rng.randi_range(0, pool.size() - 1)
		_displayed_cards.append(pool[idx])
		pool.remove_at(idx)


func _ready() -> void:
	visible = false
	anchors_preset = Control.PRESET_FULL_RECT
	size = Vector2(1920, 1080)
	_build_ui()


func _build_ui() -> void:
	var backdrop := ColorRect.new()
	backdrop.name = "Backdrop"
	backdrop.anchors_preset = Control.PRESET_FULL_RECT
	backdrop.color = Color(0, 0, 0, 0.7)
	backdrop.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(backdrop)

	var center := CenterContainer.new()
	center.name = "CenterContainer"
	center.anchors_preset = Control.PRESET_FULL_RECT
	add_child(center)

	var main_vbox := VBoxContainer.new()
	main_vbox.name = "MainVBox"
	main_vbox.custom_minimum_size = Vector2(1100, 750)
	main_vbox.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	main_vbox.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	main_vbox.add_theme_constant_override("separation", 12)
	center.add_child(main_vbox)

	var title := _make_label("S H O P", 28, Color(1.0, 0.85, 0.3))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main_vbox.add_child(title)

	var top_hbox := HBoxContainer.new()
	top_hbox.name = "TopHBox"
	top_hbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top_hbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	top_hbox.add_theme_constant_override("separation", 20)
	main_vbox.add_child(top_hbox)

	_build_services_panel(top_hbox)
	_build_inventory_panel(top_hbox)

	var selector_outer := VBoxContainer.new()
	selector_outer.add_theme_constant_override("separation", 4)
	var selector_header := _make_label("Select a Card (for quality/purify/sell/stamp targeting):", 14, Color(0.7, 0.7, 0.8))
	selector_outer.add_child(selector_header)
	var selector_hbox := HBoxContainer.new()
	selector_hbox.add_theme_constant_override("separation", 12)
	selector_outer.add_child(selector_hbox)
	_card_selector_grid = GridContainer.new()
	_card_selector_grid.name = "CardSelectorGrid"
	_card_selector_grid.columns = 8
	_card_selector_grid.add_theme_constant_override("h_separation", 6)
	_card_selector_grid.add_theme_constant_override("v_separation", 6)
	_card_selector_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	selector_hbox.add_child(_card_selector_grid)
	_build_detail_panel(selector_hbox)
	main_vbox.add_child(selector_outer)

	_build_bottom_bar(main_vbox)


func _build_services_panel(parent: Control) -> void:
	var wrapper := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.3, 0.4)
	wrapper.add_theme_stylebox_override("panel", style)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(wrapper)

	_services_panel = VBoxContainer.new()
	_services_panel.add_theme_constant_override("separation", 8)
	_services_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(_services_panel)

	var header := _make_label("Fixed Services", 18, Color(0.8, 0.8, 0.9))
	_services_panel.add_child(header)

	var heal_header := _make_label("HP Recovery (5 chips/HP)", 14, Color(0.6, 0.9, 0.6))
	_services_panel.add_child(heal_header)
	var heal_row := HBoxContainer.new()
	heal_row.add_theme_constant_override("separation", 8)
	_heal_input = SpinBox.new()
	_heal_input.min_value = 1
	_heal_input.max_value = 50
	_heal_input.value = 10
	_heal_input.prefix = "HP: "
	_heal_input.custom_minimum_size = Vector2(120, 32)
	heal_row.add_child(_heal_input)
	_heal_button = _make_button("Heal", 90)
	heal_row.add_child(_heal_button)
	_services_panel.add_child(heal_row)

	var quality_header := _make_label("Assign Quality to Selected Card", 14, Color(0.9, 0.8, 0.6))
	_services_panel.add_child(quality_header)
	_quality_option = OptionButton.new()
	_quality_option.custom_minimum_size = Vector2(180, 32)
	_populate_quality_options()
	_services_panel.add_child(_quality_option)
	_quality_buy_button = _make_button("Assign Quality", 130)
	_services_panel.add_child(_quality_buy_button)

	_purify_button = _make_button("Purify Selected Card", 180)
	_services_panel.add_child(_purify_button)

	_sell_button = _make_button("Sell Selected Card", 180)
	_services_panel.add_child(_sell_button)

	_heal_button.pressed.connect(_on_heal_pressed)
	_quality_buy_button.pressed.connect(_on_quality_buy_pressed)
	_purify_button.pressed.connect(_on_purify_pressed)
	_sell_button.pressed.connect(_on_sell_pressed)


func _build_inventory_panel(parent: Control) -> void:
	var wrapper := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.12, 0.12, 0.18)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.3, 0.4)
	wrapper.add_theme_stylebox_override("panel", style)
	wrapper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(wrapper)

	_inventory_panel = VBoxContainer.new()
	_inventory_panel.add_theme_constant_override("separation", 8)
	_inventory_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	wrapper.add_child(_inventory_panel)

	var header := _make_label("Random Inventory", 18, Color(0.8, 0.8, 0.9))
	_inventory_panel.add_child(header)

	_inventory_grid = GridContainer.new()
	_inventory_grid.name = "InventoryGrid"
	_inventory_grid.columns = 2
	_inventory_grid.add_theme_constant_override("h_separation", 12)
	_inventory_grid.add_theme_constant_override("v_separation", 12)
	_inventory_grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_inventory_panel.add_child(_inventory_grid)

	_refresh_button = _make_button("Refresh (20 chips)", 160)
	_inventory_panel.add_child(_refresh_button)

	_refresh_button.pressed.connect(_on_refresh_pressed)



func _build_detail_panel(parent: Control) -> void:
	var wrapper := PanelContainer.new()
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.1, 0.1, 0.15)
	style.set_corner_radius_all(6)
	style.set_border_width_all(1)
	style.border_color = Color(0.3, 0.3, 0.4)
	wrapper.add_theme_stylebox_override("panel", style)
	wrapper.custom_minimum_size = Vector2(220, 180)
	wrapper.size_flags_vertical = Control.SIZE_EXPAND_FILL
	parent.add_child(wrapper)

	_detail_panel = VBoxContainer.new()
	_detail_panel.add_theme_constant_override("separation", 6)
	_detail_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_detail_panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	wrapper.add_child(_detail_panel)

	var header := _make_label("Card Details", 15, Color(0.8, 0.8, 0.9))
	_detail_panel.add_child(header)

	_detail_title = _make_label("-", 14, Color.WHITE)
	_detail_panel.add_child(_detail_title)

	_detail_stamp = _make_label("-", 13, Color(0.7, 0.85, 0.7))
	_detail_panel.add_child(_detail_stamp)

	_detail_quality = _make_label("-", 13, Color(0.9, 0.8, 0.6))
	_detail_panel.add_child(_detail_quality)

	_detail_stats = _make_label("-", 12, Color(0.6, 0.6, 0.7))
	_detail_panel.add_child(_detail_stats)

func _build_bottom_bar(parent: Control) -> void:
	var bar := HBoxContainer.new()
	bar.name = "BottomBar"
	bar.custom_minimum_size = Vector2(0, 50)
	bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_theme_constant_override("separation", 16)
	parent.add_child(bar)

	_chip_label = _make_label("Chips: 0", 20, Color(1.0, 0.85, 0.3))
	_chip_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_chip_label)

	_status_label = _make_label("", 14, Color.WHITE)
	_status_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(_status_label)

	_close_button = _make_button("Exit Shop", 120)
	bar.add_child(_close_button)

	_close_button.pressed.connect(_on_close_pressed)


# ---------------------------------------------------------------------------
# Populate and refresh
# ---------------------------------------------------------------------------


func _refresh_detail_panel() -> void:
	if _selected_card_index < 0 or _selected_card_index >= _displayed_cards.size():
		_detail_title.text = "No card selected"
		_detail_stamp.text = ""
		_detail_quality.text = ""
		_detail_stats.text = ""
		return
	var card: CardInstance = _displayed_cards[_selected_card_index]
	var suit_sym: String = CardView.SUIT_SYMBOLS.get(card.prototype.suit, "?")
	var rank_lbl: String = CardView.RANK_LABELS.get(card.prototype.rank, "?")
	_detail_title.text = "%s%s" % [rank_lbl, suit_sym]
	_detail_title.add_theme_color_override("font_color", Color(1.0, 0.95, 0.7))

	var stamp_name: String = CardEnums.Stamp.keys()[card.stamp]
	_detail_stamp.text = "Stamp: %s" % stamp_name

	if card.quality != CardEnums.Quality.NONE:
		var q_name: String = CardEnums.Quality.keys()[card.quality]
		var ql_name: String = CardEnums.QualityLevel.keys()[card.quality_level]
		_detail_quality.text = "Quality: %s (%s)" % [q_name, ql_name]
	else:
		_detail_quality.text = "Quality: None"

	var bj_str: String = ",".join(card.prototype.bj_values.map(func(v): return str(v)))
	_detail_stats.text = "BJ: [%s]  Effect: %d  Chip: %d" % [bj_str, card.prototype.effect_value, card.prototype.chip_value]

func _populate_quality_options() -> void:
	_quality_option.clear()
	var qualities: Array = [
		[CardEnums.Quality.COPPER, "Copper (40)"],
		[CardEnums.Quality.SILVER, "Silver (80)"],
		[CardEnums.Quality.GOLD, "Gold (120)"],
		[CardEnums.Quality.DIAMOND_Q, "Diamond (200)"],
		[CardEnums.Quality.RUBY, "Ruby (120)"],
		[CardEnums.Quality.SAPPHIRE, "Sapphire (120)"],
		[CardEnums.Quality.EMERALD, "Emerald (120)"],
		[CardEnums.Quality.OBSIDIAN, "Obsidian (120)"],
	]
	for entry in qualities:
		_quality_option.add_item(entry[1], entry[0])


func _refresh_services_panel() -> void:
	if _selected_card_index >= 0 and _selected_card_index < _displayed_cards.size():
		var card: CardInstance = _displayed_cards[_selected_card_index]
		if card.quality != CardEnums.Quality.NONE and card.quality_level != CardEnums.QualityLevel.I:
			var cost: int = QualitySystem.PURIFY_COST.get(card.quality_level, 0)
			_purify_button.text = "Purify Selected Card (%d chips)" % cost
			_purify_button.disabled = false
		else:
			_purify_button.text = "Purify (card not eligible)"
			_purify_button.disabled = true
		var investment: int = card.prototype.base_buy_price \
			+ StampSystem.get_price(card.stamp) \
			+ QualitySystem.get_price(card.quality)
		var refund: int = int(investment * ShopSystem.SELL_PRICE_RATIO)
		_sell_button.text = "Sell Selected Card (+%d chips)" % refund
		_sell_button.disabled = false
	else:
		_purify_button.text = "Purify (select a card first)"
		_purify_button.disabled = true
		_sell_button.text = "Sell (select a card first)"
		_sell_button.disabled = true


func _refresh_inventory_panel() -> void:
	for child in _inventory_grid.get_children():
		_inventory_grid.remove_child(child)
		child.queue_free()
	for item in _inventory_items:
		var item_panel := _make_inventory_item_panel(item)
		_inventory_grid.add_child(item_panel)


func _refresh_card_selector() -> void:
	for child in _card_selector_grid.get_children():
		_card_selector_grid.remove_child(child)
		child.queue_free()
	for i in _displayed_cards.size():
		var card: CardInstance = _displayed_cards[i]
		var btn := Button.new()
		var suit_symbol: String = CardView.SUIT_SYMBOLS.get(card.prototype.suit, "?")
		var rank_label: String = CardView.RANK_LABELS.get(card.prototype.rank, "?")
		btn.text = "%s%s" % [rank_label, suit_symbol]
		btn.custom_minimum_size = Vector2(55, 36)
		btn.add_theme_font_size_override("font_size", 13)
		var idx: int = i
		if idx == _selected_card_index:
			btn.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
		btn.pressed.connect(_on_card_selected.bind(idx))
		_card_selector_grid.add_child(btn)


func _update_chip_label() -> void:
	if _chips != null:
		_chip_label.text = "Chips: %d" % _chips.get_balance()


func _clear_status() -> void:
	_status_label.text = ""
	_status_label.add_theme_color_override("font_color", Color.WHITE)


func _set_status(text: String, color: Color) -> void:
	_status_label.text = text
	_status_label.add_theme_color_override("font_color", color)


func _make_inventory_item_panel(item: ShopItem) -> Control:
	var panel := VBoxContainer.new()
	panel.add_theme_constant_override("separation", 4)

	var desc_label := Label.new()
	desc_label.add_theme_font_size_override("font_size", 13)

	match item.kind:
		ShopItem.Kind.STAMP:
			desc_label.text = "Stamp: %s" % CardEnums.Stamp.keys()[item.stamp]
		ShopItem.Kind.CARD_STAMP:
			var card: CardInstance = item.target_card
			var suit_sym: String = CardView.SUIT_SYMBOLS.get(card.prototype.suit, "?")
			var rank_lbl: String = CardView.RANK_LABELS.get(card.prototype.rank, "?")
			desc_label.text = "%s%s + %s stamp" % [rank_lbl, suit_sym, CardEnums.Stamp.keys()[item.stamp]]
		ShopItem.Kind.CARD_QUALITY:
			var card: CardInstance = item.target_card
			var suit_sym: String = CardView.SUIT_SYMBOLS.get(card.prototype.suit, "?")
			var rank_lbl: String = CardView.RANK_LABELS.get(card.prototype.rank, "?")
			desc_label.text = "%s%s -> %s" % [rank_lbl, suit_sym, CardEnums.Quality.keys()[item.quality]]

	desc_label.add_theme_color_override("font_color", Color(0.85, 0.85, 0.9))
	panel.add_child(desc_label)

	var price_label := _make_label("%d chips" % item.price, 14, Color(1.0, 0.85, 0.3))
	panel.add_child(price_label)

	var buy_btn := _make_button("Buy", 60)
	buy_btn.disabled = _chips != null and not _chips.can_afford(item.price)
	buy_btn.pressed.connect(_on_buy_inventory_item.bind(item))
	panel.add_child(buy_btn)

	return panel


# ---------------------------------------------------------------------------
# Button handlers
# ---------------------------------------------------------------------------

func _on_heal_pressed() -> void:
	var hp_amount: int = int(_heal_input.value)
	var price: int = hp_amount * ShopSystem.HP_COST_PER_POINT
	if _shop.buy_hp(hp_amount):
		_set_status("Healed %d HP for %d chips!" % [hp_amount, price], Color(0.3, 0.9, 0.3))
		_update_chip_label()
		_refresh_services_panel()
		shop_purchase_made.emit()
	else:
		_set_status("Not enough chips!", Color(0.9, 0.3, 0.3))


func _on_quality_buy_pressed() -> void:
	if _selected_card_index < 0 or _selected_card_index >= _displayed_cards.size():
		_set_status("Select a card first!", Color(0.9, 0.3, 0.3))
		return
	var card: CardInstance = _displayed_cards[_selected_card_index]
	var quality_id: int = _quality_option.get_selected_id()
	if _shop.buy_quality(card, quality_id):
		_set_status("Assigned %s to card!" % CardEnums.Quality.keys()[quality_id], Color(0.3, 0.9, 0.3))
		_update_chip_label()
		_refresh_card_selector()
		_refresh_services_panel()
		_refresh_inventory_panel()
		shop_purchase_made.emit()
	else:
		_set_status("Cannot assign quality (invalid suit or not enough chips)!", Color(0.9, 0.3, 0.3))


func _on_purify_pressed() -> void:
	if _selected_card_index < 0 or _selected_card_index >= _displayed_cards.size():
		_set_status("Select a card first!", Color(0.9, 0.3, 0.3))
		return
	var card: CardInstance = _displayed_cards[_selected_card_index]
	if _shop.purify(card):
		_set_status("Purified card!", Color(0.3, 0.9, 0.3))
		_update_chip_label()
		_refresh_card_selector()
		_refresh_services_panel()
		shop_purchase_made.emit()
	else:
		_set_status("Cannot purify (not eligible or not enough chips)!", Color(0.9, 0.3, 0.3))


func _on_sell_pressed() -> void:
	if _selected_card_index < 0 or _selected_card_index >= _displayed_cards.size():
		_set_status("Select a card first!", Color(0.9, 0.3, 0.3))
		return
	var card: CardInstance = _displayed_cards[_selected_card_index]
	var refund: int = _shop.sell_card(card)
	if refund > 0:
		_set_status("Sold card for %d chips!" % refund, Color(0.3, 0.9, 0.3))
		_update_chip_label()
		_refresh_card_selector()
		_refresh_services_panel()
		_refresh_inventory_panel()
		shop_purchase_made.emit()
	else:
		_set_status("Cannot sell this card!", Color(0.9, 0.3, 0.3))


func _on_buy_inventory_item(item: ShopItem) -> void:
	var success: bool = false
	match item.kind:
		ShopItem.Kind.STAMP:
			if _selected_card_index < 0 or _selected_card_index >= _displayed_cards.size():
				_set_status("Select a target card first!", Color(0.9, 0.3, 0.3))
				return
			var card: CardInstance = _displayed_cards[_selected_card_index]
			success = _shop.buy_stamp(card, item.stamp)
			if not success:
				_set_status("Cannot buy stamp (not enough chips)!", Color(0.9, 0.3, 0.3))
		ShopItem.Kind.CARD_STAMP:
			success = _shop.buy_stamp(item.target_card, item.stamp)
		ShopItem.Kind.CARD_QUALITY:
			success = _shop.buy_quality(item.target_card, item.quality)
	if success:
		_set_status("Purchased!", Color(0.3, 0.9, 0.3))
		_inventory_items.erase(item)
		_update_chip_label()
		_refresh_inventory_panel()
		_refresh_card_selector()
		_refresh_services_panel()
		shop_purchase_made.emit()
	elif item.kind != ShopItem.Kind.STAMP:
		_set_status("Not enough chips!", Color(0.9, 0.3, 0.3))


func _on_refresh_pressed() -> void:
	var typed_deck: Array[CardInstance] = []
	for card in _displayed_cards:
		typed_deck.append(card)
	var result: int = _shop.refresh_inventory(typed_deck, 0)
	if result == 1:
		_inventory_items = _shop.get_current_inventory()
		_selected_card_index = -1
		_pick_random_cards()
		_refresh_inventory_panel()
		_refresh_card_selector()
		_refresh_services_panel()
		_update_chip_label()
		_set_status("Inventory refreshed!", Color(0.3, 0.9, 0.3))
		shop_purchase_made.emit()
	elif result == -1:
		_set_status("You have already refreshed the shop!", Color(0.9, 0.3, 0.3))
	else:
		_set_status("Not enough chips to refresh!", Color(0.9, 0.3, 0.3))


func _on_card_selected(index: int) -> void:
	_selected_card_index = index
	_refresh_card_selector()
	_refresh_services_panel()
	_refresh_detail_panel()


func _on_close_pressed() -> void:
	visible = false
	shop_closed.emit()


# ---------------------------------------------------------------------------
# Utility
# ---------------------------------------------------------------------------

func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


func _make_button(text: String, min_width: float) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(min_width, BUTTON_HEIGHT)
	btn.add_theme_font_size_override("font_size", 14)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return btn
