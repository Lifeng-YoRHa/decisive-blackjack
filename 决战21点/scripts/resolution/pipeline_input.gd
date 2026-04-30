class_name PipelineInput
extends RefCounted

## Bundles all pipeline inputs into a single typed object.
## v2 scope: stamps + quality + HAMMER pre-scan + gem destroy. No bust, no instant win.

var sorted_player: Array[CardInstance] = []
var sorted_ai: Array[CardInstance] = []
var player_multipliers: Array[float] = []
var ai_multipliers: Array[float] = []
var settlement_first_player: CardEnums.Owner = CardEnums.Owner.PLAYER
var rng_seed: int = -1
var player_bust: bool = false
var ai_bust: bool = false
