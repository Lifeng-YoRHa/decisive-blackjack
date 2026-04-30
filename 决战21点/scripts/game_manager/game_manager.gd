class_name GameManager
extends Node

var _card_data: CardDataModel
var _combat: CombatState
var _chips: ChipEconomy
var _resolution: ResolutionEngine
var _ai: AIOpponent
var _round_manager: RoundManager
var _shop: ShopSystem
var _match: MatchProgression
var _ui: TableUI
var _shop_overlay: ShopOverlay


func _ready() -> void:
	_card_data = CardDataModel.new()
	_combat = CombatState.new()
	_chips = ChipEconomy.new()
	_resolution = ResolutionEngine.new()
	_ai = AIOpponent.new()
	_round_manager = RoundManager.new()
	_shop = ShopSystem.new()
	_match = MatchProgression.new()
	_ui = TableUI.new()
	_shop_overlay = ShopOverlay.new()

	add_child(_card_data)
	add_child(_combat)
	add_child(_chips)
	add_child(_resolution)
	add_child(_ai)
	add_child(_round_manager)
	add_child(_shop)
	add_child(_match)
	add_child(_ui)
	add_child(_shop_overlay)

	_card_data.initialize()
	_combat.initialize()
	_chips.initialize()
	_resolution.initialize(_combat, _chips)
	_ai.initialize()
	_round_manager.initialize(_card_data, _combat, _chips, _resolution, _ai, -1)
	_shop.initialize(_combat, _chips)
	_match.initialize(_round_manager, _shop, _chips, _combat, _card_data)
	_ui.initialize(_combat, _chips, _round_manager)
	_shop_overlay.initialize(_shop, _combat, _chips, _card_data)

	_ui.player_hit_requested.connect(_on_player_hit)
	_ui.player_stand_requested.connect(_round_manager.player_stand)
	_ui.player_sort_confirmed.connect(_round_manager.confirm_sort)
	_ui.start_round_requested.connect(_on_start_round)
	_ui.transition_requested.connect(_on_transition)
	_ui.new_game_requested.connect(_on_new_game)

	_round_manager.phase_changed.connect(_on_phase_changed_for_cards)
	_match.match_state_changed.connect(_on_match_state_changed)
	_shop_overlay.shop_closed.connect(_on_shop_closed)

	_match.start_new_game()
	_ui.update_counters()


func _on_player_hit() -> void:
	_round_manager.player_hit()
	_ui.update_cards()


func _on_start_round() -> void:
	_ui._clear_cards()
	_round_manager.start_round()


func _on_transition() -> void:
	_round_manager.transition_to_next_opponent()
	_ui.update_counters()
	_ui._on_hp_changed(CardEnums.Owner.AI, _combat.ai.hp, _combat.ai.max_hp)
	_ui._on_hp_changed(CardEnums.Owner.PLAYER, _combat.player.hp, _combat.player.max_hp)


func _on_new_game() -> void:
	_match.start_new_game()
	_ui.update_counters()
	_ui._refresh_all_state()


func _on_phase_changed_for_cards(old_phase: int, new_phase: int) -> void:
	match new_phase:
		RoundManager.RoundPhase.HIT_STAND:
			_ui.update_cards()
		RoundManager.RoundPhase.RESOLUTION:
			_ui.reveal_ai_cards()


func _on_match_state_changed(new_state: int, old_state: int) -> void:
	match new_state:
		MatchProgression.MatchState.SHOP:
			var inventory: Array[ShopItem] = _shop.get_current_inventory()
			var player_deck: Array = _card_data.get_all_player_cards()
			_shop_overlay.setup(inventory, player_deck)
			_shop_overlay.visible = true
			_ui.set_physics_process(false)
		MatchProgression.MatchState.OPPONENT_ACTIVE:
			_shop_overlay.visible = false
			_ui.set_physics_process(true)
			_ui.update_counters()
			_ui._on_hp_changed(CardEnums.Owner.AI, _combat.ai.hp, _combat.ai.max_hp)
			_ui._on_hp_changed(CardEnums.Owner.PLAYER, _combat.player.hp, _combat.player.max_hp)
		MatchProgression.MatchState.VICTORY:
			_ui.set_phase_text("VICTORY!")
			_ui.show_new_game_button()
		MatchProgression.MatchState.GAME_OVER:
			_ui.set_phase_text("GAME OVER")
			_ui.show_new_game_button()


func _on_shop_closed() -> void:
	_match.exit_shop()
