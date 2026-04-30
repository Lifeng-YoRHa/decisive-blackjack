class_name CombatState
extends Node

## Combat state manager for the card-battle system.
## Tracks HP, defense, and combatant lifecycle for player and AI opponents.
##
## Design reference: Combat System design doc -- Combatant Core API story.

## Inner class representing a single combatant (player or AI).
class Combatant extends RefCounted:
	var hp: int
	var max_hp: int
	var defense: int

	func _init(p_max_hp: int) -> void:
		max_hp = p_max_hp
		hp = p_max_hp
		defense = 0

	var is_alive: bool:
		get:
			return hp > 0


## Signals -- emitted on any state change for UI presentation.
## target: CardEnums.Owner.PLAYER (0) or CardEnums.Owner.AI (1)
signal hp_changed(target: CardEnums.Owner, new_hp: int, max_hp: int)
signal defense_changed(target: CardEnums.Owner, new_defense: int)

## Constants -- player HP is fixed; AI scales per opponent number.
const PLAYER_MAX_HP: int = 100
const AI_HP_SCALING: Dictionary[int, int] = {
	1: 80, 2: 100, 3: 120, 4: 150,
	5: 180, 6: 220, 7: 260, 8: 300,
}

## State -- the two combatants.
var player: Combatant
var ai: Combatant


## Initialize with default first-opponent AI.
func initialize() -> void:
	player = Combatant.new(PLAYER_MAX_HP)
	ai = Combatant.new(AI_HP_SCALING[1])


## Swap the AI opponent based on round number (1-8).
func setup_opponent(opponent_number: int) -> void:
	if not AI_HP_SCALING.has(opponent_number):
		push_error("CombatState.setup_opponent: invalid opponent_number %d" % opponent_number)
		return
	ai = Combatant.new(AI_HP_SCALING[opponent_number])


## Apply damage to a combatant. Defense absorbs first, then HP.
## hp_changed fires only when HP actually changes.
## defense_changed fires only when defense actually changes.
func apply_damage(target: CardEnums.Owner, amount: int) -> void:
	var combatant := _get_combatant(target)
	if amount <= combatant.defense:
		combatant.defense -= amount
		defense_changed.emit(target, combatant.defense)
	else:
		var remaining := amount - combatant.defense
		combatant.defense = 0
		defense_changed.emit(target, 0)
		combatant.hp = maxi(combatant.hp - remaining, 0)
		hp_changed.emit(target, combatant.hp, combatant.max_hp)


## Heal a combatant. Capped at max_hp. Returns overflow (amount above max).
## hp_changed fires only when HP actually changes.
func apply_heal(target: CardEnums.Owner, amount: int) -> int:
	var combatant := _get_combatant(target)
	var old_hp := combatant.hp
	var new_hp := combatant.hp + amount
	var overflow := 0
	if new_hp > combatant.max_hp:
		overflow = new_hp - combatant.max_hp
		new_hp = combatant.max_hp
	combatant.hp = new_hp
	if combatant.hp != old_hp:
		hp_changed.emit(target, combatant.hp, combatant.max_hp)
	return overflow


## Add defense to a combatant. No cap -- accumulates freely.
func add_defense(target: CardEnums.Owner, amount: int) -> void:
	var combatant := _get_combatant(target)
	combatant.defense += amount
	defense_changed.emit(target, combatant.defense)


## Apply bust damage directly to HP, bypassing defense entirely.
func apply_bust_damage(target: CardEnums.Owner, amount: int) -> void:
	var combatant := _get_combatant(target)
	combatant.hp = maxi(combatant.hp - amount, 0)
	hp_changed.emit(target, combatant.hp, combatant.max_hp)


## Reset both combatants' defense to 0 (end of combat turn).
## Only emits defense_changed when defense actually changes.
func reset_defense() -> void:
	if player.defense != 0:
		player.defense = 0
		defense_changed.emit(CardEnums.Owner.PLAYER, 0)
	if ai.defense != 0:
		ai.defense = 0
		defense_changed.emit(CardEnums.Owner.AI, 0)


## Resolve a target int to the correct Combatant.
func _get_combatant(target: CardEnums.Owner) -> Combatant:
	if target == CardEnums.Owner.PLAYER:
		return player
	if target == CardEnums.Owner.AI:
		return ai
	push_error("CombatState._get_combatant: invalid target %d" % target)
	return null
