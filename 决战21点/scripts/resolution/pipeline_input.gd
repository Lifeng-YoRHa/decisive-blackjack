class_name PipelineInput
extends RefCounted

## Bundles all pipeline inputs into a single typed object.
## MVP scope: no bust, no instant win, no insurance, no doubledown.

var sorted_player: Array[CardInstance] = []
var sorted_ai: Array[CardInstance] = []
var player_multipliers: Array[float] = []
var ai_multipliers: Array[float] = []
var settlement_first_player: int = CardEnums.Owner.PLAYER
