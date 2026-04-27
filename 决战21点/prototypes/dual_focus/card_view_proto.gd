extends Control

var _is_mouse_hovered: bool = false
var _is_kb_focus_visible: bool = false
var _last_input_was_mouse: bool = false

var gamepad_focus_color: Color = Color.YELLOW
var mouse_hover_color: Color = Color.WHITE
var card_label: String = ""

func _init() -> void:
	custom_minimum_size = Vector2(120, 168)
	focus_mode = Control.FOCUS_ALL
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


func _ready() -> void:
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)


func setup(label: String) -> void:
	card_label = label


func _input(event: InputEvent) -> void:
	if event is InputEventMouse:
		_last_input_was_mouse = true
	elif event is InputEventKey or event is InputEventJoypadButton:
		_last_input_was_mouse = false


func _on_mouse_entered() -> void:
	_is_mouse_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_is_mouse_hovered = false
	queue_redraw()


func _on_focus_entered() -> void:
	_is_kb_focus_visible = not _last_input_was_mouse
	queue_redraw()


func _on_focus_exited() -> void:
	_is_kb_focus_visible = false
	queue_redraw()


func _draw() -> void:
	# Card background
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.15, 0.15, 0.2))

	# Card label
	var font := ThemeDB.fallback_font
	var font_size := 16
	var text_size := font.get_string_size(card_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	font.draw_string(get_canvas_item(), Vector2((size.x - text_size.x) / 2, size.y / 2 + font_size / 3), card_label, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

	# Mouse hover glow (white, semi-transparent)
	if _is_mouse_hovered:
		var glow_width: float = 3.0
		var inner_rect := Rect2(Vector2(glow_width, glow_width), size - Vector2(glow_width * 2, glow_width * 2))
		draw_rect(inner_rect, Color(mouse_hover_color.r, mouse_hover_color.g, mouse_hover_color.b, 0.3), false, glow_width)

	# Gamepad/keyboard focus border (yellow, solid)
	if _is_kb_focus_visible:
		var border_width: float = 2.0
		var border_rect := Rect2(Vector2.ZERO, size).grow(-border_width)
		draw_rect(border_rect, gamepad_focus_color, false, border_width)

	# Status indicator at bottom
	var status_parts: Array[String] = []
	if _is_mouse_hovered:
		status_parts.append("HOVER")
	if _is_kb_focus_visible:
		status_parts.append("FOCUS")
	if _is_mouse_hovered or _is_kb_focus_visible:
		var status_text := " ".join(status_parts)
		var st_size := font.get_string_size(status_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12)
		font.draw_string(get_canvas_item(), Vector2((size.x - st_size.x) / 2, size.y - 10), status_text, HORIZONTAL_ALIGNMENT_CENTER, -1, 12, Color.CYAN)
