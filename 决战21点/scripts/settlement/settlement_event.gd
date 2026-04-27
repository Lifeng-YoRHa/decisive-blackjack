class_name SettlementEvent extends RefCounted

enum StepKind {
	BASE_VALUE,
	STAMP_EFFECT,
	QUALITY_EFFECT,
	MULTIPLIER_APPLIED,
	BUST_DAMAGE,
	GEM_DESTROY,
	CHIP_GAINED,
	DEFENSE_APPLIED,
	HEAL_APPLIED,
}

var step: StepKind
var card: CardInstance
var value: int = 0
var target: String = ""
var metadata: Dictionary = {}
