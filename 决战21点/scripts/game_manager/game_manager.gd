class_name GameManager
extends Node

var _card_data: CardDataModel
var _combat: CombatState
var _chips: ChipEconomy
var _resolution: ResolutionEngine
var _ai: AIOpponent
var _round_manager: RoundManager
var _ui: TableUI


func _ready() -> void:
	_card_data = CardDataModel.new()
	_combat = CombatState.new()
	_chips = ChipEconomy.new()
	_resolution = ResolutionEngine.new()
	_ai = AIOpponent.new()
	_round_manager = RoundManager.new()
	_ui = TableUI.new()

	add_child(_card_data)
	add_child(_combat)
	add_child(_chips)
	add_child(_resolution)
	add_child(_ai)
	add_child(_round_manager)
	add_child(_ui)

	_card_data.initialize()
	_combat.initialize()
	_chips.initialize()
	_resolution.initialize(_combat, _chips)
	_ai.initialize()
	_round_manager.initialize(_card_data, _combat, _chips, _resolution, _ai, -1)
	_ui.initialize(_combat, _chips, _round_manager)

	_ui.player_hit_requested.connect(_on_player_hit)
	_ui.player_stand_requested.connect(_round_manager.player_stand)
	_ui.player_sort_confirmed.connect(_round_manager.confirm_sort)
	_ui.start_round_requested.connect(_on_start_round)
	_ui.transition_requested.connect(_on_transition)
	_ui.new_game_requested.connect(_on_new_game)

	_round_manager.phase_changed.connect(_on_phase_changed_for_cards)

	_round_manager.start_new_game()
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
	_round_manager.start_new_game()
	_ui.update_counters()
	_ui._refresh_all_state()


func _on_phase_changed_for_cards(old_phase: int, new_phase: int) -> void:
	match new_phase:
		RoundManager.RoundPhase.HIT_STAND:
			_ui.update_cards()
		RoundManager.RoundPhase.RESOLUTION:
			_ui.reveal_ai_cards()
