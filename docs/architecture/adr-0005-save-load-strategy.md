# ADR-0005: Save/Load Strategy

## Status
Accepted

## Date
2026-04-26

## Engine Compatibility

| Field | Value |
|-------|-------|
| **Engine** | Godot 4.6.2 |
| **Domain** | Core (serialization, file I/O) |
| **Knowledge Risk** | MEDIUM — FileAccess return types changed in 4.4 (store_* now returns bool) |
| **References Consulted** | VERSION.md, deprecated-apis.md, breaking-changes.md |
| **Post-Cutoff APIs Used** | FileAccess.store_*() return values (4.4+ — must check bool return) |
| **Verification Required** | Test that FileAccess.write failures are detected (disk full, permission denied) |

## ADR Dependencies

| Field | Value |
|-------|-------|
| **Depends On** | ADR-0002 (CardInstance as RefCounted with to_dict/from_dict serialization) |
| **Enables** | Match progression between sessions, alpha milestone (save/load is an alpha requirement) |
| **Blocks** | Stories involving match state persistence |
| **Ordering Note** | Must be Accepted before save/load implementation stories |

## Context

### Problem Statement
The game lasts 20-40 minutes (8 opponents). Players may need to quit mid-match and resume later. What state is persisted, in what format, and how is it validated on load?

### Constraints
- CardInstance is RefCounted (ADR-0002) — custom to_dict/from_dict already exists
- Single save slot (no multiplayer, no cloud saves, single-player card game)
- Godot 4.6.2: FileAccess.store_*() returns bool (4.4+ change — must check return values)
- Save data must be validated before applying (corrupt/modified saves must not crash the game)
- AI deck is regenerated each opponent — not saved
- Match is 8 opponents, each with multiple rounds

### Requirements
- Must persist: player deck (52 cards), chip balance, player HP, match state, opponent number, item inventory, round counter, first player
- Must regenerate: AI deck, AI HP, defense, transaction log, UI state
- Must validate all loaded data before applying (atomic: all-or-nothing)
- Must support schema versioning for future migration
- Must handle FileAccess errors gracefully (disk full, permission denied)
- Must complete save/load in <100ms

## Decision

### Format: JSON via FileAccess

```gdscript
const SAVE_PATH = "user://save_game.json"
const TEMP_PATH = "user://save_game.json.tmp"
const SCHEMA_VERSION = 1

func save_game() -> bool:
    var data := {
        "version": SCHEMA_VERSION,
        "match_state": match_prog.get_match_state(),
        "opponent_number": match_prog.get_opponent_number(),
        "total_opponents": match_prog.get_total_opponents(),
        "round_counter": round_mgr.get_round_counter(),
        "first_player": round_mgr.get_first_player(),
        "player_hp": combat.get_player_hp(),
        "player_max_hp": combat.get_player_max_hp(),
        "chip_balance": chips.get_balance(),
        "player_deck": _serialize_deck(card_data.get_player_deck()),
        "item_inventory": _serialize_inventory(items.get_inventory()),
    }
    var json_string := JSON.stringify(data, "  ")

    # Atomic write: temp file → rename. If crash mid-write, original is intact.
    var file := FileAccess.open(TEMP_PATH, FileAccess.WRITE)
    if file == null:
        push_error("Save failed: %s" % FileAccess.get_open_error())
        return false
    var ok := file.store_string(json_string)
    file.close()
    if not ok:
        push_error("Save failed: write error")
        DirAccess.remove_absolute(TEMP_PATH)
        return false

    var dir := DirAccess.open("user://")
    if dir == null:
        push_error("Save failed: cannot open user directory")
        return false
    if dir.rename(TEMP_PATH, SAVE_PATH) != OK:
        push_error("Save failed: could not rename temp to final")
        return false
    return true

func load_game() -> bool:
    # Clean up leftover temp from a failed save
    if FileAccess.file_exists(TEMP_PATH):
        DirAccess.remove_absolute(TEMP_PATH)

    if not FileAccess.file_exists(SAVE_PATH):
        return false
    var file := FileAccess.open(SAVE_PATH, FileAccess.READ)
    if file == null:
        return false
    var json_string := file.get_as_text()
    file.close()

    var json := JSON.new()
    if json.parse(json_string) != OK:
        push_error("Save corrupt: JSON parse failed")
        return false

    var data: Dictionary = json.data
    if not _validate_save(data):
        push_error("Save corrupt: validation failed")
        return false

    _apply_save(data)
    return true
```

### Save Data Schema

```json
{
  "version": 1,
  "match_state": "OPPONENT_N",
  "opponent_number": 3,
  "total_opponents": 8,
  "round_counter": 5,
  "first_player": "PLAYER",
  "player_hp": 45,
  "player_max_hp": 100,
  "chip_balance": 280,
  "player_deck": [
    {
      "suit": "SPADES",
      "rank": "A",
      "stamp": "SHIELD",
      "quality": "OBSIDIAN",
      "quality_level": "II",
      "revision": 7
    }
  ],
  "item_inventory": [
    {
      "item_type": "ENERGY_DRINK",
      "purchase_price": 70,
      "purchase_round": 2
    }
  ]
}
```

### Save Triggers

Auto-save at these game flow points:
1. **After DEATH_CHECK with result=CONTINUE** — every round boundary is a checkpoint
2. **On shop enter** — safest rollback point (match_state=SHOP, opponent_number=N+1)
3. **On opponent defeated (before shop)** — guarantees shop entry state is saved

Delete save on:
- Match VICTORY (game complete)
- Match GAME_OVER (player death)
- New Game start (fresh state)

Delete must remove both `SAVE_PATH` and `TEMP_PATH` (if present):
```gdscript
func delete_save() -> void:
    if FileAccess.file_exists(SAVE_PATH):
        DirAccess.remove_absolute(SAVE_PATH)
    if FileAccess.file_exists(TEMP_PATH):
        DirAccess.remove_absolute(TEMP_PATH)
```

### Atomic Validation

```gdscript
func _validate_save(data: Dictionary) -> bool:
    # Schema version check
    if data.get("version", 0) != SCHEMA_VERSION:
        return false

    # Match state validation
    var valid_states := ["NEW_GAME", "OPPONENT_N", "SHOP", "VICTORY", "GAME_OVER"]
    if data.get("match_state", "") not in valid_states:
        return false

    # Range checks
    var opp: int = data.get("opponent_number", 0)
    var total: int = data.get("total_opponents", 0)
    if total < 3 or total > 8:
        return false
    if opp < 1 or opp > total:
        return false

    var hp: int = data.get("player_hp", -1)
    var max_hp: int = data.get("player_max_hp", 0)
    if hp < 0 or hp > max_hp or max_hp <= 0:
        return false

    var balance: int = data.get("chip_balance", -1)
    if balance < 0 or balance > 999:
        return false

    # Player deck: exactly 52 entries, unique (suit, rank) pairs
    var deck: Array = data.get("player_deck", [])
    if deck.size() != 52:
        return false
    var seen_keys: Dictionary = {}
    for card_data in deck:
        var key := "%s_%s" % [card_data.get("suit", ""), card_data.get("rank", "")]
        if key in seen_keys:
            return false
        seen_keys[key] = true
        # Enum validation
        if card_data.get("suit", "") not in ["HEARTS", "DIAMONDS", "SPADES", "CLUBS"]:
            return false
        # Gem-suit binding validation
        var quality = card_data.get("quality")
        var suit = card_data.get("suit")
        if quality in ["RUBY", "SAPPHIRE", "EMERALD", "OBSIDIAN"]:
            if not CardDataModel.is_valid_assignment(suit, quality):
                return false

    # Item inventory: max 5 items
    var inventory: Array = data.get("item_inventory", [])
    if inventory.size() > 5:
        return false

    return true
```

### Load Reconstruction

```gdscript
func _apply_save(data: Dictionary) -> void:
    # 1. Restore player deck (52 CardInstances from serialized data)
    var prototypes := card_data.get_all_prototypes()
    var player_deck: Array[CardInstance] = []
    for card_data in data.player_deck:
        var card := CardInstance.from_dict(card_data, prototypes)
        player_deck.append(card)
    card_data.restore_player_deck(player_deck)

    # 2. Restore combat state
    combat.restore_player_hp(data.player_hp, data.player_max_hp)

    # 3. Restore chip balance
    chips.restore_balance(data.chip_balance)

    # 4. Restore match progression
    match_prog.restore_state(data.match_state, data.opponent_number, data.total_opponents)

    # 5. Restore round management
    round_mgr.restore_state(data.round_counter, data.first_player)

    # 6. Restore item inventory
    items.restore_inventory(data.item_inventory)

    # 7. Regenerate AI (not from save data)
    var ai_hp := CombatState.AI_HP_TABLE[data.opponent_number - 1]
    combat.restore_ai_hp(ai_hp, ai_hp)
    card_data.regenerate_ai_deck(data.opponent_number)
```

## Alternatives Considered

### Alternative 1: Godot Resource Binary (.tres)
- **Description**: Use ResourceSaver/ResourceLoader with a custom SaveData Resource class
- **Pros**: Engine-native serialization; type-safe; binary format prevents casual editing; Inspector preview
- **Cons**: CardInstance is RefCounted (not Resource) — would need a parallel Resource wrapper; binary format is not diffable or debuggable; Resource format changes between engine versions; no human-readable format for bug reports
- **Rejection Reason**: ADR-0002 chose RefCounted over Resource for CardInstance. Creating a Resource wrapper just for serialization defeats the purpose. JSON is simpler, debuggable, and works with the existing to_dict/from_dict API.

### Alternative 2: Encrypted Binary
- **Description**: Encrypt save data to prevent cheating/modification
- **Pros**: Prevents save editing; protects game integrity
- **Cons**: Single-player card game — no competitive reason to prevent save editing; adds complexity; encryption keys must be stored in code (security theater); makes debugging harder
- **Rejection Reason**: This is a single-player game. Save editing is the player's choice. The validation on load is to prevent crashes from corrupt data, not to enforce anti-cheat.

## Consequences

### Positive
- Human-readable: JSON can be inspected, diffed, and edited for debugging
- Consistent with ADR-0002: uses existing to_dict/from_dict serialization
- Schema versioning: future migrations handled by version field
- Atomic validation: corrupt saves are rejected without modifying game state
- FileAccess error handling: write failures detected via bool return (4.4+)
- Single file: easy to manage, delete, and back up

### Negative
- Custom validation: every field must be checked manually (no schema compiler)
- Manual migration: new schema versions require explicit migration code
- JSON.stringify produces a large file (~15-20KB for 52 cards with whitespace)

### Risks
- **Risk**: Save data grows if player deck size changes
  **Mitigation**: Schema version field supports migration. Deck size validated as exactly 52.
- **Risk**: FileAccess.write fails silently if bool return not checked
  **Mitigation**: All store_*() calls check return value (MEDIUM risk from VERSION.md — verified)
- **Risk**: JSON parse fails on corrupted file (disk corruption, partial write)
  **Mitigation**: Atomic write — temp-file-then-rename pattern. If crash mid-write, original save is intact. Leftover temp files cleaned on load.
- **Risk**: total_opponents tuning change invalidates existing saves
  **Mitigation**: Clamp total_opponents to [3, 8] on load. If opponent_number exceeds clamped total, treat as GAME_OVER.

## GDD Requirements Addressed

| GDD System | Requirement | How This ADR Addresses It |
|------------|-------------|--------------------------|
| card-data-model.md | to_dict/from_dict for 104 instances | 52 player CardInstance.to_dict() serialized; from_dict() used on load |
| card-data-model.md | 104-instance validation on load | _validate_save checks exactly 52 deck entries with unique (suit, rank) keys |
| card-data-model.md | is_valid_assignment on load | Gem-suit binding validated in _validate_save |
| match-progression.md | Match state persistence across sessions | match_state, opponent_number, total_opponents persisted |
| match-progression.md | Opponent transition state | Save triggers on shop enter — safest rollback point |
| chip-economy.md | Balance persistence | chip_balance saved and validated in [0, 999] |
| chip-economy.md | Transaction log NOT saved | Architecture decision: transaction log regenerated empty on load |
| item-system.md | Inventory persists across opponents | item_inventory array persisted, max 5 items validated |
| combat-system.md | Player HP persistence | player_hp saved, validated in [0, max_hp] |
| combat-system.md | AI HP regenerated | AI HP looked up from ai_hp_scaling table by opponent_number |

## Performance Implications
- **CPU**: JSON.stringify 52 cards ≈ 1ms. JSON.parse ≈ 1ms. Validation ≈ 0.5ms. Total <5ms.
- **Memory**: Save data in memory ≈ 20KB during serialization. Freed after write.
- **Load Time**: File read + parse + validate + reconstruct ≈ <20ms. Well within 100ms target.
- **Network**: N/A

## Migration Plan
First implementation — no migration needed.

Future migrations: increment SCHEMA_VERSION. Add `_migrate_v1_to_v2(data)` function. Load reads version, runs migration chain, then validates against current schema.

## Validation Criteria
- Save produces valid JSON with all required fields
- Load rejects corrupt/modified saves without crashing
- Load reconstructs game state matching pre-save state exactly
- AI deck regenerated correctly from opponent_number
- 52-card invariant holds after load
- Gem-suit binding valid after load
- FileAccess write failures detected and reported
- Save deleted on VICTORY/GAME_OVER/New Game
- Schema version mismatch rejected gracefully
