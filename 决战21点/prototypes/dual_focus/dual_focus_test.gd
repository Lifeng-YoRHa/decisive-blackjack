extends Control

## Dual-focus prototype test scene.
## Validates Godot 4.6 dual-focus behavior: mouse hover and gamepad focus
## are independent and can be active on different cards simultaneously.
##
## HOW TO RUN:
##   1. Create a new scene with a Control root node
##   2. Attach this script to the root node
##   3. Set as main scene (Play F5)
##
## WHAT TO VERIFY:
##   1. Mouse hover Card A → white glow appears on Card A
##   2. Press Tab/arrow keys to focus Card B → yellow border on Card B
##   3. Both should render simultaneously on different cards
##   4. Click Card C with mouse → NO yellow border (hidden focus)
##   5. Then press Tab → yellow border moves to next card
##
## PASS CRITERIA (per ADR-0008):
##   - Mouse hover and gamepad focus visuals are independent
##   - Mouse click gives hidden focus (no yellow border)
##   - Keyboard/gamepad shows visible focus (yellow border)
##   - Both can be active on different cards at the same time

const CARD_VIEW_SCRIPT := preload("res://prototypes/dual_focus/card_view_proto.gd")


var _cards: Array[Control] = []


func _ready() -> void:
	# Root setup
	anchors_preset = Control.PRESET_FULL_RECT
	size = Vector2(1280, 720)

	# Instructions
	var instructions := Label.new()
	instructions.text = "DUAL-FOCUS PROTOTYPE — ADR-0008 Validation\n\n" + \
		"1. Mouse hover a card → white glow (HOVER)\n" + \
		"2. Tab/arrows to keyboard-focus a card → yellow border (FOCUS)\n" + \
		"3. Verify both can appear on DIFFERENT cards simultaneously\n" + \
		"4. Click a card with mouse → should show HOVER only (no yellow border)\n" + \
		"5. Click card, then immediately press Tab → yellow border on next card\n\n" + \
		"PASS: Mouse hover + keyboard focus render independently on different cards\n" + \
		"FAIL: Mouse click also shows yellow focus border (pre-4.6 behavior)"
	instructions.autowrap_mode = TextServer.AUTOWRAP_WORD
	instructions.anchors_preset = Control.PRESET_TOP_WIDE
	instructions.custom_minimum_size = Vector2(0, 180)
	instructions.add_theme_font_size_override("font_size", 14)
	add_child(instructions)

	# Card container
	var container := HBoxContainer.new()
	container.anchors_preset = Control.PRESET_CENTER
	container.offset_top = 200
	container.offset_left = 100
	container.offset_right = 1180
	container.offset_bottom = 400
	container.add_theme_constant_override("separation", 20)
	container.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(container)

	# Create 5 test cards
	var labels := ["Card A", "Card B", "Card C", "Card D", "Card E"]
	for label in labels:
		var card := Control.new()
		card.set_script(CARD_VIEW_SCRIPT)
		container.add_child(card)
		card.setup(label)
		_cards.append(card)

	# Status bar
	var status := Label.new()
	status.name = "StatusBar"
	status.text = "Cards ready. Use mouse + keyboard to test."
	status.anchors_preset = Control.PRESET_BOTTOM_WIDE
	status.offset_top = -40
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	status.add_theme_font_size_override("font_size", 14)
	add_child(status)
