class_name TableUI
extends Control

signal player_hit_requested()
signal player_stand_requested()
signal start_round_requested()
signal transition_requested()
signal new_game_requested()
signal player_sort_confirmed(order: Array)

const CARD_WIDTH: float = 120.0
const CARD_HEIGHT: float = 168.0
const SORT_TIMER_SECONDS: int = 30
const SORT_TIMER_RED_THRESHOLD: int = 5

var _combat: CombatState
var _chips: ChipEconomy
var _round_manager: RoundManager

var _card_pool: Array[CardView] = []
var _player_card_views: Array[CardView] = []
var _ai_card_views: Array[CardView] = []

var _root_vbox: VBoxContainer
var _opponent_info_bar: HBoxContainer
var _ai_hand_area: HBoxContainer
var _central_info_bar: HBoxContainer
var _player_hand_area: HBoxContainer
var _action_bar: HBoxContainer

var _opponent_name_label: Label
var _opponent_hp_bar: ProgressBar
var _opponent_hp_label: Label
var _opponent_defense_label: Label

var _phase_label: Label
var _opponent_counter_label: Label
var _round_counter_label: Label
var _chip_counter_label: Label

var _player_hp_bar: ProgressBar
var _player_hp_label: Label
var _player_defense_label: Label
var _point_total_label: Label
var _hit_button: Button
var _stand_button: Button
var _start_round_button: Button
var _transition_button: Button
var _new_game_button: Button
var _confirm_sort_button: Button
var _sort_timer_label: Label
var _sort_timer: Timer
var _sort_time_remaining: int

var _result_label: Label


func set_phase_text(text: String) -> void:
	_phase_label.text = text


func show_new_game_button() -> void:
	_hit_button.disabled = true
	_stand_button.disabled = true
	_start_round_button.visible = false
	_transition_button.visible = false
	_new_game_button.visible = true
	_confirm_sort_button.visible = false
	_sort_timer_label.visible = false
	_result_label.visible = true
	_result_label.text = _phase_label.text
	_result_label.add_theme_color_override("font_color", Color.YELLOW)


func initialize(combat: CombatState, chips: ChipEconomy, round_manager: RoundManager) -> void:
	_combat = combat
	_chips = chips
	_round_manager = round_manager
	_connect_signals()
	_refresh_all_state()


func update_cards() -> void:
	_clear_cards()
	var player_hand: Array = _round_manager.player_hand
	var ai_hand: Array = _round_manager.ai_hand

	for i in player_hand.size():
		var card: CardInstance = player_hand[i]
		var view := _get_card_view()
		_player_hand_area.add_child(view)
		view.setup(card, true)
		_player_card_views.append(view)

	for i in ai_hand.size():
		var card: CardInstance = ai_hand[i]
		var view := _get_card_view()
		_ai_hand_area.add_child(view)
		view.setup(card, i == 0)
		_ai_card_views.append(view)

	_update_point_total()


func reveal_ai_cards() -> void:
	for view in _ai_card_views:
		view.set_face_up(true)


func update_counters() -> void:
	_round_counter_label.text = "Round %d" % _round_manager.round_counter
	_opponent_counter_label.text = "Opponent %d/8" % _round_manager.opponent_number
	_chip_counter_label.text = "Chips: %d" % _chips.get_balance()


func _ready() -> void:
	anchors_preset = Control.PRESET_FULL_RECT
	size = Vector2(1920, 1080)
	_build_ui()


func _build_ui() -> void:
	_root_vbox = VBoxContainer.new()
	_root_vbox.name = "RootVBox"
	_root_vbox.anchors_preset = Control.PRESET_FULL_RECT
	_root_vbox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_root_vbox.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_root_vbox.add_theme_constant_override("separation", 8)
	add_child(_root_vbox)

	_build_opponent_info_bar()
	_build_ai_hand_area()
	_build_central_info_bar()
	_build_player_hand_area()
	_build_action_bar()


func _build_opponent_info_bar() -> void:
	_opponent_info_bar = HBoxContainer.new()
	_opponent_info_bar.name = "OpponentInfoBar"
	_opponent_info_bar.custom_minimum_size = Vector2(0, 60)
	_opponent_info_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_opponent_info_bar.add_theme_constant_override("separation", 12)
	_root_vbox.add_child(_opponent_info_bar)

	_opponent_name_label = _make_label("Opponent", 20, Color.WHITE)
	_opponent_info_bar.add_child(_opponent_name_label)

	_opponent_hp_bar = ProgressBar.new()
	_opponent_hp_bar.name = "OpponentHPBar"
	_opponent_hp_bar.custom_minimum_size = Vector2(300, 20)
	_opponent_hp_bar.max_value = 100
	_opponent_hp_bar.value = 100
	_opponent_hp_bar.show_percentage = false
	_opponent_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.2, 0.2)
	bg.set_corner_radius_all(4)
	_opponent_hp_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.8, 0.2)
	fill.set_corner_radius_all(4)
	_opponent_hp_bar.add_theme_stylebox_override("fill", fill)
	_opponent_info_bar.add_child(_opponent_hp_bar)

	_opponent_hp_label = _make_label("100/100", 14, Color.WHITE)
	_opponent_info_bar.add_child(_opponent_hp_label)

	_opponent_defense_label = _make_label("Def: 0", 14, Color(0.5, 0.7, 1.0))
	_opponent_info_bar.add_child(_opponent_defense_label)


func _build_ai_hand_area() -> void:
	_ai_hand_area = HBoxContainer.new()
	_ai_hand_area.name = "AIHandArea"
	_ai_hand_area.custom_minimum_size = Vector2(0, 200)
	_ai_hand_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_ai_hand_area.alignment = BoxContainer.ALIGNMENT_CENTER
	_ai_hand_area.add_theme_constant_override("separation", 20)
	_root_vbox.add_child(_ai_hand_area)


func _build_central_info_bar() -> void:
	_central_info_bar = HBoxContainer.new()
	_central_info_bar.name = "CentralInfoBar"
	_central_info_bar.custom_minimum_size = Vector2(0, 40)
	_central_info_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_central_info_bar.add_theme_constant_override("separation", 40)
	_root_vbox.add_child(_central_info_bar)

	_phase_label = _make_label("Ready", 22, Color(0.9, 0.85, 0.7))
	_central_info_bar.add_child(_phase_label)

	_opponent_counter_label = _make_label("Opponent 1/8", 16, Color(0.7, 0.7, 0.7))
	_central_info_bar.add_child(_opponent_counter_label)

	_round_counter_label = _make_label("Round 1", 16, Color(0.7, 0.7, 0.7))
	_central_info_bar.add_child(_round_counter_label)

	_chip_counter_label = _make_label("Chips: 100", 18, Color(1.0, 0.85, 0.3))
	_central_info_bar.add_child(_chip_counter_label)


func _build_player_hand_area() -> void:
	_player_hand_area = HBoxContainer.new()
	_player_hand_area.name = "PlayerHandArea"
	_player_hand_area.custom_minimum_size = Vector2(0, 220)
	_player_hand_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_player_hand_area.alignment = BoxContainer.ALIGNMENT_CENTER
	_player_hand_area.add_theme_constant_override("separation", 20)
	_root_vbox.add_child(_player_hand_area)


func _build_action_bar() -> void:
	_action_bar = HBoxContainer.new()
	_action_bar.name = "ActionBar"
	_action_bar.custom_minimum_size = Vector2(0, 80)
	_action_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_action_bar.add_theme_constant_override("separation", 16)
	_root_vbox.add_child(_action_bar)

	_player_hp_bar = ProgressBar.new()
	_player_hp_bar.name = "PlayerHPBar"
	_player_hp_bar.custom_minimum_size = Vector2(300, 24)
	_player_hp_bar.max_value = 100
	_player_hp_bar.value = 100
	_player_hp_bar.show_percentage = false
	_player_hp_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.2, 0.2, 0.2)
	bg.set_corner_radius_all(4)
	_player_hp_bar.add_theme_stylebox_override("background", bg)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.8, 0.2)
	fill.set_corner_radius_all(4)
	_player_hp_bar.add_theme_stylebox_override("fill", fill)
	_action_bar.add_child(_player_hp_bar)

	_player_hp_label = _make_label("100/100", 16, Color.WHITE)
	_action_bar.add_child(_player_hp_label)

	_player_defense_label = _make_label("Def: 0", 14, Color(0.5, 0.7, 1.0))
	_action_bar.add_child(_player_defense_label)

	_point_total_label = _make_label("Points: --", 20, Color(1.0, 1.0, 1.0))
	_point_total_label.custom_minimum_size = Vector2(140, 0)
	_action_bar.add_child(_point_total_label)

	_hit_button = _make_button("Hit")
	_hit_button.disabled = true
	_action_bar.add_child(_hit_button)

	_stand_button = _make_button("Stand")
	_stand_button.disabled = true
	_action_bar.add_child(_stand_button)

	_result_label = _make_label("", 18, Color.YELLOW)
	_result_label.visible = false
	_action_bar.add_child(_result_label)

	_start_round_button = _make_button("Start Round")
	_start_round_button.visible = true
	_action_bar.add_child(_start_round_button)

	_transition_button = _make_button("Next Opponent")
	_transition_button.visible = false
	_action_bar.add_child(_transition_button)

	_new_game_button = _make_button("New Game")
	_new_game_button.visible = false
	_action_bar.add_child(_new_game_button)

	_confirm_sort_button = _make_button("Confirm Sort")
	_confirm_sort_button.visible = false
	_action_bar.add_child(_confirm_sort_button)

	_sort_timer_label = _make_label("", 20, Color.WHITE)
	_sort_timer_label.visible = false
	_sort_timer_label.custom_minimum_size = Vector2(60, 0)
	_action_bar.add_child(_sort_timer_label)

	_sort_timer = Timer.new()
	_sort_timer.name = "SortTimer"
	_sort_timer.one_shot = false
	_sort_timer.wait_time = 1.0
	_sort_timer.timeout.connect(_on_sort_timer_tick)
	add_child(_sort_timer)


func _connect_signals() -> void:
	_combat.hp_changed.connect(_on_hp_changed)
	_combat.defense_changed.connect(_on_defense_changed)
	_chips.chips_changed.connect(_on_chips_changed)
	_round_manager.phase_changed.connect(_on_phase_changed)
	_round_manager.round_result.connect(_on_round_result)

	_hit_button.pressed.connect(_on_hit_pressed)
	_stand_button.pressed.connect(_on_stand_pressed)
	_start_round_button.pressed.connect(_on_start_round_pressed)
	_transition_button.pressed.connect(_on_transition_pressed)
	_new_game_button.pressed.connect(_on_new_game_pressed)
	_confirm_sort_button.pressed.connect(_on_confirm_sort_pressed)


func _on_hp_changed(target: int, new_hp: int, max_hp: int) -> void:
	if target == CardEnums.Owner.PLAYER:
		_player_hp_bar.max_value = max_hp
		_player_hp_bar.value = new_hp
		_player_hp_label.text = "%d/%d" % [new_hp, max_hp]
		_update_hp_bar_color(_player_hp_bar, new_hp, max_hp)
	else:
		_opponent_hp_bar.max_value = max_hp
		_opponent_hp_bar.value = new_hp
		_opponent_hp_label.text = "%d/%d" % [new_hp, max_hp]
		_update_hp_bar_color(_opponent_hp_bar, new_hp, max_hp)


func _on_defense_changed(target: int, new_defense: int) -> void:
	if target == CardEnums.Owner.PLAYER:
		_player_defense_label.text = "Def: %d" % new_defense
	else:
		_opponent_defense_label.text = "Def: %d" % new_defense


func _on_chips_changed(new_balance: int, _delta: int, _source: int) -> void:
	_chip_counter_label.text = "Chips: %d" % new_balance


func _on_phase_changed(old_phase: int, new_phase: int) -> void:
	_start_round_button.visible = false
	_transition_button.visible = false
	_new_game_button.visible = false
	_result_label.visible = false

	match new_phase:
		RoundManager.RoundPhase.DEAL:
			_phase_label.text = "Dealing..."
			_set_action_buttons(false, false)
		RoundManager.RoundPhase.HIT_STAND:
			_phase_label.text = "Hit or Stand"
			_set_action_buttons(true, true)
		RoundManager.RoundPhase.SORT:
			_phase_label.text = "Arrange your cards"
			_set_action_buttons(false, false)
			_confirm_sort_button.visible = true
			_enable_sort_mode()
			_start_sort_timer()
		RoundManager.RoundPhase.RESOLUTION:
			_phase_label.text = "Resolving..."
			_set_action_buttons(false, false)
			_disable_sort_mode()
			_stop_sort_timer()
		RoundManager.RoundPhase.DEATH_CHECK:
			_phase_label.text = "Round Over"
			_set_action_buttons(false, false)
	_update_point_total()
	update_counters()


func _on_round_result(result: int, opp: int, round_num: int, p_hp: int, ai_hp: int) -> void:
	_result_label.visible = true
	match result:
		RoundManager.RoundResult.CONTINUE:
			_result_label.text = "Round complete!"
			_result_label.add_theme_color_override("font_color", Color(0.7, 0.9, 1.0))
			_start_round_button.visible = true
			_transition_button.visible = false
			_new_game_button.visible = false
		RoundManager.RoundResult.PLAYER_WIN:
			_result_label.text = "Opponent defeated!"
			_result_label.add_theme_color_override("font_color", Color(0.2, 1.0, 0.3))
			# MatchProgression handles shop/victory automatically
			_start_round_button.visible = false
			_transition_button.visible = false
			_new_game_button.visible = false
		RoundManager.RoundResult.PLAYER_LOSE:
			_result_label.text = "Game Over"
			_result_label.add_theme_color_override("font_color", Color(1.0, 0.2, 0.2))
			_start_round_button.visible = false
			_transition_button.visible = false
			_new_game_button.visible = true


func _on_hit_pressed() -> void:
	player_hit_requested.emit()


func _on_stand_pressed() -> void:
	player_stand_requested.emit()


func _on_start_round_pressed() -> void:
	start_round_requested.emit()


func _on_transition_pressed() -> void:
	transition_requested.emit()


func _on_new_game_pressed() -> void:
	new_game_requested.emit()


func _set_action_buttons(hit_enabled: bool, stand_enabled: bool) -> void:
	_hit_button.disabled = not hit_enabled
	_stand_button.disabled = not stand_enabled


func _update_point_total() -> void:
	var result: PointResult = _round_manager.player_result
	if result == null:
		_point_total_label.text = "Points: --"
		return
	if result.is_bust:
		_point_total_label.text = "Points: %d BUST!" % result.point_total
		_point_total_label.add_theme_color_override("font_color", Color(1.0, 0.3, 0.3))
	else:
		_point_total_label.text = "Points: %d" % result.point_total
		_point_total_label.add_theme_color_override("font_color", Color.WHITE)


func _update_hp_bar_color(bar: ProgressBar, hp: int, max_hp: int) -> void:
	var ratio: float = float(hp) / float(max_hp)
	var fill := bar.get_theme_stylebox("fill") as StyleBoxFlat
	if fill == null:
		return
	if ratio > 0.5:
		fill.bg_color = Color(0.2, 0.8, 0.2)
	elif ratio > 0.25:
		fill.bg_color = Color(0.9, 0.8, 0.1)
	else:
		fill.bg_color = Color(0.9, 0.2, 0.2)


func _get_card_view() -> CardView:
	if not _card_pool.is_empty():
		return _card_pool.pop_back() as CardView
	return CardView.new()


func _clear_cards() -> void:
	for view in _player_card_views:
		_player_hand_area.remove_child(view)
		_card_pool.append(view)
	_player_card_views.clear()
	for view in _ai_card_views:
		_ai_hand_area.remove_child(view)
		_card_pool.append(view)
	_ai_card_views.clear()


func _refresh_all_state() -> void:
	if _combat.player != null:
		_on_hp_changed(CardEnums.Owner.PLAYER, _combat.player.hp, _combat.player.max_hp)
		_on_defense_changed(CardEnums.Owner.PLAYER, _combat.player.defense)
	if _combat.ai != null:
		_on_hp_changed(CardEnums.Owner.AI, _combat.ai.hp, _combat.ai.max_hp)
		_on_defense_changed(CardEnums.Owner.AI, _combat.ai.defense)
	_chip_counter_label.text = "Chips: %d" % _chips.get_balance()
	update_counters()


func _on_confirm_sort_pressed() -> void:
	var order: Array = []
	for view in _player_card_views:
		order.append(view.get_card_instance())
	player_sort_confirmed.emit(order)
	_stop_sort_timer()


func _start_sort_timer() -> void:
	_sort_time_remaining = SORT_TIMER_SECONDS
	_sort_timer_label.text = "%ds" % _sort_time_remaining
	_sort_timer_label.add_theme_color_override("font_color", Color.WHITE)
	_sort_timer_label.visible = true
	_sort_timer.start()


func _stop_sort_timer() -> void:
	_sort_timer.stop()
	_sort_timer_label.visible = false


func _on_sort_timer_tick() -> void:
	_sort_time_remaining -= 1
	if _sort_time_remaining <= 0:
		_on_confirm_sort_pressed()
		return
	_sort_timer_label.text = "%ds" % _sort_time_remaining
	if _sort_time_remaining <= SORT_TIMER_RED_THRESHOLD:
		_sort_timer_label.add_theme_color_override("font_color", Color.RED)


func _enable_sort_mode() -> void:
	for i in _player_card_views.size():
		_player_card_views[i].enable_sort_mode(true, i, _on_card_swap)


func _disable_sort_mode() -> void:
	_confirm_sort_button.visible = false
	for view in _player_card_views:
		view.enable_sort_mode(false, -1, Callable())


func _on_card_swap(from: int, to: int) -> void:
	var temp = _player_card_views[from]
	_player_card_views[from] = _player_card_views[to]
	_player_card_views[to] = temp
	for view in _player_card_views:
		_player_hand_area.remove_child(view)
	for i in _player_card_views.size():
		_player_hand_area.add_child(_player_card_views[i])
		_player_card_views[i].set_sort_position(i)


func _make_label(text: String, font_size: int, color: Color) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return label


func _make_button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(120, 40)
	btn.add_theme_font_size_override("font_size", 16)
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	return btn
