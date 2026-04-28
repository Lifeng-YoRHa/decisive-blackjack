class_name CardView
extends Control

const CARD_WIDTH: float = 120.0
const CARD_HEIGHT: float = 168.0

const SUIT_COLORS: Dictionary = {
	CardEnums.Suit.HEARTS: Color(0.85, 0.2, 0.2),
	CardEnums.Suit.DIAMONDS: Color(0.9, 0.55, 0.1),
	CardEnums.Suit.SPADES: Color(0.2, 0.2, 0.35),
	CardEnums.Suit.CLUBS: Color(0.2, 0.55, 0.2),
}

const RANK_LABELS: Dictionary = {
	CardEnums.Rank.ACE: "A", CardEnums.Rank.TWO: "2", CardEnums.Rank.THREE: "3",
	CardEnums.Rank.FOUR: "4", CardEnums.Rank.FIVE: "5", CardEnums.Rank.SIX: "6",
	CardEnums.Rank.SEVEN: "7", CardEnums.Rank.EIGHT: "8", CardEnums.Rank.NINE: "9",
	CardEnums.Rank.TEN: "10", CardEnums.Rank.JACK: "J", CardEnums.Rank.QUEEN: "Q",
	CardEnums.Rank.KING: "K",
}

const SUIT_SYMBOLS: Dictionary = {
	CardEnums.Suit.HEARTS: "♥",
	CardEnums.Suit.DIAMONDS: "♦",
	CardEnums.Suit.SPADES: "♠",
	CardEnums.Suit.CLUBS: "♣",
}

var _card_instance: CardInstance
var _face_up: bool = true

var _background: ColorRect
var _rank_label: Label
var _suit_label: Label
var _center_label: Label
var _card_back: ColorRect

var _position_label: Label
var _sort_mode: bool = false
var _sort_position: int = -1
var sort_swap_callback: Callable


func _ready() -> void:
	custom_minimum_size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	_build_ui()


func setup(card: CardInstance, face_up: bool) -> void:
	_card_instance = card
	_face_up = face_up
	_refresh_visuals()


func set_face_up(is_face_up: bool) -> void:
	_face_up = is_face_up
	_refresh_visuals()


func get_card_instance() -> CardInstance:
	return _card_instance


func enable_sort_mode(enabled: bool, position: int, callback: Callable) -> void:
	_sort_mode = enabled
	_sort_position = position
	sort_swap_callback = callback
	_position_label.visible = enabled
	_position_label.text = str(position + 1) if enabled else ""
	mouse_filter = Control.MOUSE_FILTER_STOP if enabled else Control.MOUSE_FILTER_IGNORE


func set_sort_position(pos: int) -> void:
	_sort_position = pos
	_position_label.text = str(pos + 1)


func _get_drag_data(_at: Vector2) -> Variant:
	if not _sort_mode:
		return null
	var preview := ColorRect.new()
	preview.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	preview.color = Color(1, 1, 1, 0.3)
	set_drag_preview(preview)
	return {"sort_position": _sort_position}


func _can_drop_data(_at: Vector2, data: Variant) -> bool:
	return _sort_mode and data is Dictionary and data.has("sort_position")


func _drop_data(_at: Vector2, data: Variant) -> void:
	if not _sort_mode:
		return
	var from_position: int = data["sort_position"]
	if from_position != _sort_position and sort_swap_callback.is_valid():
		sort_swap_callback.call(from_position, _sort_position)


func _build_ui() -> void:
	_background = ColorRect.new()
	_background.name = "Background"
	_background.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	_background.color = Color(0.5, 0.5, 0.5)
	add_child(_background)

	_rank_label = Label.new()
	_rank_label.name = "RankLabel"
	_rank_label.position = Vector2(6, 4)
	_rank_label.size = Vector2(40, 24)
	_rank_label.add_theme_font_size_override("font_size", 18)
	_rank_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(_rank_label)

	_suit_label = Label.new()
	_suit_label.name = "SuitLabel"
	_suit_label.position = Vector2(CARD_WIDTH - 28, 4)
	_suit_label.size = Vector2(24, 24)
	_suit_label.add_theme_font_size_override("font_size", 18)
	_suit_label.add_theme_color_override("font_color", Color.WHITE)
	_suit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(_suit_label)

	_center_label = Label.new()
	_center_label.name = "CenterLabel"
	_center_label.position = Vector2(0, CARD_HEIGHT * 0.3)
	_center_label.size = Vector2(CARD_WIDTH, CARD_HEIGHT * 0.4)
	_center_label.add_theme_font_size_override("font_size", 36)
	_center_label.add_theme_color_override("font_color", Color.WHITE)
	_center_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_center_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	add_child(_center_label)

	_card_back = ColorRect.new()
	_card_back.name = "CardBack"
	_card_back.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	_card_back.color = Color(0.15, 0.15, 0.25)
	_card_back.visible = false
	var back_label := Label.new()
	back_label.text = "?"
	back_label.add_theme_font_size_override("font_size", 32)
	back_label.add_theme_color_override("font_color", Color(0.4, 0.4, 0.5))
	back_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	back_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	back_label.size = Vector2(CARD_WIDTH, CARD_HEIGHT)
	_card_back.add_child(back_label)
	add_child(_card_back)

	_position_label = Label.new()
	_position_label.name = "PositionLabel"
	_position_label.position = Vector2(CARD_WIDTH / 2 - 10, 0)
	_position_label.size = Vector2(20, 20)
	_position_label.add_theme_font_size_override("font_size", 14)
	_position_label.add_theme_color_override("font_color", Color.YELLOW)
	_position_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_position_label.visible = false
	add_child(_position_label)

	for child in get_children():
		child.mouse_filter = Control.MOUSE_FILTER_IGNORE


func _refresh_visuals() -> void:
	var show_info: bool = _face_up and _card_instance != null
	_card_back.visible = not _face_up

	if not show_info:
		_rank_label.visible = false
		_suit_label.visible = false
		_center_label.visible = false
		_background.color = Color(0.15, 0.15, 0.25) if not _face_up else Color(0.5, 0.5, 0.5)
		return

	var suit: int = _card_instance.prototype.suit
	var rank: int = _card_instance.prototype.rank

	_background.color = SUIT_COLORS.get(suit, Color(0.5, 0.5, 0.5))
	_rank_label.visible = true
	_rank_label.text = RANK_LABELS.get(rank, "?")
	_suit_label.visible = true
	_suit_label.text = SUIT_SYMBOLS.get(suit, "?")
	_center_label.visible = true
	_center_label.text = RANK_LABELS.get(rank, "?")
