# Hand Type Detection System (牌型检测系统)

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-24
> **Implements Pillar**: Core — hand composition analysis and multiplier assignment

## Overview

牌型检测系统是《决胜21点》的手牌组成分析器。它接收一手确定的手牌（卡牌实例数组）和该手牌的点数计算结果（PointResult），在非爆牌前提下（`is_bust = false`），检测手牌满足哪些预定义牌型（对子、同花、三条、三七、21、杰克、黑杰克共 7 种），并为每种匹配的牌型生成对应的倍率分配方案（哪些卡牌获得倍率、倍率值是多少）。当多个牌型同时满足时，系统返回所有匹配项供玩家选择其一；当无牌型匹配时，返回默认倍率 1.0 应用于全部卡牌。作为 Core 层系统，它为结算引擎的 `combat_effect` 和 `chip_output` 公式提供 `hand_type_multiplier` 参数，为 AI 对手系统提供牌型评估能力（辅助决策是否继续要牌），为牌桌 UI 提供牌型高亮和选择界面数据。没有这个系统，所有卡牌只能按基础值结算，失去了 21 点策略卡牌游戏中"追求完美牌型"的核心驱动力。

## Player Fantasy

**赌桌上的审判者 — 看穿牌面，裁决命运**

你手里 18 点，你选择要牌。一张 3 — 完美的 21。心跳还没平复，牌型检测亮起：你同时满足 21 牌型（×2）和同花（×5）。游戏把选择权交给你 — 5 张牌全部 ×2，还是全部 ×5？这不是游戏告诉你"你赢了这些"，而是你审视局势、权衡取舍、做出裁决。新手看到"两个都亮了！"随手点一个；老手看到"同花×5 远超 21 点×2，但同花需要全部同花色"而精准选择。这个差距，就是技巧。

牌型检测系统的玩家幻想是**紧张释放后的掌控感**。要牌阶段，点数在悬崖边游走（点数计算引擎的紧张感）；一旦安全落定，牌型检测接棒，把"我没爆"的释然转化为"我还有什么"的兴奋。当多种牌型同时匹配时，这个瞬间从被动接受变为主动裁决 — 你不是在等庄家宣布结果，你是在审视牌桌，决定哪条路最致命。对子只在两张牌上生效（×2），三条让三张牌爆发（×5），三七让所有牌爆炸（×7），而黑桃A配黑桃J直接获胜 — 每种牌型都是一个不同的故事，而你选择讲哪一个。

## Detailed Design

### Core Rules

**1. 系统性质**

牌型检测系统是一个无状态纯函数系统。给定相同的卡牌数组和点数结果，始终返回相同的检测结果。不持有可变状态，不驱动游戏流程。

**2. 牌型定义（9 种）**

| # | 牌型 | 枚举值 | 检测条件 | 倍率 | 作用范围 |
|---|------|--------|---------|------|---------|
| 1 | 对子 | `PAIR` | 某一 rank 恰好出现 2 次 | ×2 | 仅匹配的 2 张 |
| 2 | 同花 | `FLUSH` | 所有卡牌花色相同 | ×手牌数 | 全部卡牌 |
| 3 | 三条 | `THREE_KIND` | 某一 rank 恰好出现 3 次 | ×5 | 仅匹配的 3 张 |
| 4 | 三七 | `TRIPLE_SEVEN` | rank=7 恰好出现 3 次 | ×7 | 全部卡牌 |
| 5 | 21 | `TWENTY_ONE` | point_total = 21 | ×2 | 全部卡牌 |
| 6 | 杰克 | `BLACKJACK_TYPE` | point_total=21 且恰好 2 张牌：一张 A + 一张 J | ×4 | 全部卡牌 |
| 7 | 黑杰克 | `SPADE_BLACKJACK` | point_total=21 且恰好 2 张牌：黑桃 A + 黑桃 J | 直接获胜 | — |

**3. 前置条件**

所有牌型检测仅在 `is_bust = false` 时执行。爆牌时返回空列表（无匹配）。

**4. 检测算法**

```
detect_hand_types(cards, point_result) -> HandTypeResult

Step 0: 前置检查
    IF point_result.is_bust: RETURN 空结果

Step 1: 构建 rank 直方图
    rank_counts: {rank -> count}
    rank_cards:  {rank -> [card indices]}

Step 2: 构建 suit 集合
    suit_set: {unique suits}

Step 3: 检测 N-of-a-kind（对子/三条）
    FOR each rank r:
        IF rank_counts[r] == 2: emit PAIR(×2, scoped=rank_cards[r])
        IF rank_counts[r] == 3: emit THREE_KIND(×5, scoped=rank_cards[r])

Step 4: 检测同花
    IF suit_set.size == 1: emit FLUSH(×cards.size, ALL)

Step 5: 检测三七
    IF rank_counts[7] == 3: emit TRIPLE_SEVEN(×7, ALL)

Step 6: 检测 21
    IF point_result.point_total == 21: emit TWENTY_ONE(×2, ALL)

Step 7: 检测杰克
    IF point_result.point_total == 21
       AND cards.size == 2
       AND 一张 rank=A, 另一张 rank=J:
        emit BLACKJACK_TYPE(×4, ALL)

Step 8: 检测黑杰克
    IF point_result.point_total == 21
       AND cards.size == 2
       AND 一张 (SPADES, A), 另一张 (SPADES, J):
        emit SPADE_BLACKJACK(instant_win=true)

Step 9: 返回所有匹配项
```

时间复杂度 O(n)，n 为手牌数（最大 11）。

**5. 黑杰克特殊规则**

- 当黑杰克被检测到时，自动选中（不可拒绝），前提是对手未购买保险
- 若对手已购买保险且保险生效，黑杰克的直接获胜效果被无效化，该牌型不触发
- 黑杰克是杰克的子集：满足黑杰克的手牌必然也满足杰克。当两者同时匹配时，仅报告黑杰克（杰克被吸收）

**6. N-of-a-kind 层级规则**

每个 rank 只报告最高匹配级别：
- 3 张同 rank → 仅报三条，不报对子
- 不同 rank 的匹配独立检测：[K,K,7,7] 报两个对子（K 对和 7 对）

**7. 多牌型匹配处理**

- 系统检测所有匹配的牌型，全部返回
- 玩家从匹配列表中选择一个激活
- 当无匹配时，默认倍率 1.0 应用于全部卡牌
- 黑杰克例外：自动选中，不需要玩家确认

**8. 分牌抑制**

分牌后的手牌不触发杰克和黑杰克。系统接受 `suppress_blackjack: bool` 标志，当为 true 时跳过 Step 8 和 Step 9。

**9. 输出数据结构**

```
HandTypeOption:
  type: HandType enum              // 牌型标识
  display_name: String             // UI 显示名
  display_multiplier: int          // UI 显示倍率（2-7）
  is_instant_win: bool             // 仅黑杰克为 true
  per_card_multiplier: Array[float] // 每张卡牌的实际倍率

HandTypeResult:
  matches: Array[HandTypeOption]   // 所有匹配项
  default_multiplier: float        // 1.0（无匹配时使用）
  has_instant_win: bool            // 快捷标志
```

`per_card_multiplier` 示例：
- 对子 [7♠,7♥,4♦]，选中 PAIR(7)：`[2.0, 2.0, 1.0]`
- 三条 [7♥,7♠,7♦,4♣]，选中 THREE_KIND(7)：`[5.0, 5.0, 5.0, 1.0]`
- 三七 [7♥,7♠,7♦]，选中 TRIPLE_SEVEN：`[7.0, 7.0, 7.0]`

### States and Transitions

无状态机。本系统是纯函数层，不持有可变状态。

### Interactions with Other Systems

| 系统 | 方向 | 数据流 | 触发时机 |
|------|------|--------|---------|
| 卡牌数据模型 | 入 | 读取 `suit`, `rank` | 每次检测 |
| 点数计算引擎 | 入 | 读取 `PointResult`（point_total, is_bust, card_count） | 每次检测 |
| 结算引擎 | 出 | `HandTypeResult`（玩家选择后的 `per_card_multiplier`） | 结算前牌型检测阶段 |
| 特殊玩法系统 | 入 | `suppress_blackjack` 标志（分牌时抑制杰克/黑杰克）；保险状态（对手是否购买保险） | 分牌判定后 |
| AI 对手系统 | 出 | `HandTypeResult`（AI 获取所有匹配项，自行决定选择策略） | AI 决策要牌/停牌时 |
| 牌桌 UI | 出 | 所有匹配项列表（用于选择界面）、`display_name`、`display_multiplier` | 手牌确定后 |

## Formulas

### 1. 同花倍率 (flush_multiplier)

`M_flush = |cards|`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| cards | — | Array[CardInstance] | 2–11 elements | 手牌 |
| M_flush | M_f | int | 2–11 | 同花牌型的倍率 |

**Output Range:** [2, 11]。最小 = 2 张同花色。最大 = 11 张全部同花色（理论极值，11 张牌不爆牌且全部同花色几乎不可能）。
**Example:** 5 张牌全部黑桃 → M_flush = 5。

### 2. 每卡倍率解析 (per_card_multiplier)

```
per_card_multiplier[i] = M_base       IF scope == ALL
per_card_multiplier[i] = M_base       IF scope == SCOPED AND i ∈ affected_indices
per_card_multiplier[i] = 1.0          IF scope == SCOPED AND i ∉ affected_indices
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| scope | — | enum {ALL, SCOPED} | — | 牌型作用范围 |
| M_base | M_b | float | 2.0–11.0 | 牌型的显示倍率 |
| affected_indices | — | Array[int] | subset of [0, \|cards\|-1] | 受影响的卡牌索引（仅 PAIR/THREE_KIND） |
| i | — | int | 0 ~ \|cards\|-1 | 手牌中的卡牌索引 |
| per_card_multiplier[i] | M_i | float | 1.0–11.0 | 位置 i 处卡牌的倍率 |

**按牌型的作用范围：**

| 牌型 | 作用范围 | M_base | affected_indices |
|------|---------|--------|-----------------|
| PAIR | SCOPED | 2.0 | 2 张匹配 rank 的卡牌索引 |
| THREE_KIND | SCOPED | 5.0 | 3 张匹配 rank 的卡牌索引 |
| FLUSH | ALL | 手牌数 (2–11) | 全部 |
| TRIPLE_SEVEN | ALL | 7.0 | 全部 |
| TWENTY_ONE | ALL | 2.0 | 全部 |
| BLACKJACK_TYPE | ALL | 4.0 | 全部 |
| SPADE_BLACKJACK | — | 直接获胜 | N/A |
| (无匹配) | ALL | 1.0 | 全部 |

**Output Range:** 每个元素 ∈ {1.0} ∪ [2.0, 11.0]。
**Example:** 手牌 [7♠(0), 7♥(1), 4♦(2)]，选中 PAIR(7)：`per_card_multiplier = [2.0, 2.0, 1.0]`。

### 3. AI 牌型评估 (ai_hand_type_score)

```
option_score = SUM_i( per_card_multiplier[i] × (effect_value[i] + stamp_bonus[i] + quality_bonus[i]) )
```

SPADE_BLACKJACK: `option_score = ∞`（始终选中）。

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| per_card_multiplier[i] | M_i | float | 1.0–11.0 | 来自公式 2 |
| effect_value[i] | V_i | int | 2–15 | 卡牌原型 effect_value |
| stamp_bonus[i] | S_i | int | 0–10 | 印记加成（仅数值型） |
| quality_bonus[i] | Q_i | int | 0–82 | 卡质加成（宝石或金属） |
| option_score | — | float | 2.0–unbounded | 该选项的估算总输出 |

**Output Range:** 有界但无上限。实际最大约 (15+10+82)×11 ≈ 1177。
**Example:** 手牌 [D7+SWORD+RUBY_II(0), DK(1), D4(2)]（3 张方片，point_total=21）。检测到 FLUSH(×3) 和 TWENTY_ONE(×2)。FLUSH(×3): score = 3×(7+2+4) + 3×13 + 3×4 = 39+39+12 = 90。TWENTY_ONE(×2): score = 2×(7+2+4) + 2×13 + 2×4 = 26+26+8 = 60。AI 选择 FLUSH。

## Edge Cases

- **If TRIPLE_SEVEN(×7 ALL) and THREE_KIND(7)(×5 scoped) both match**: THREE_KIND(7) is strictly dominated by TRIPLE_SEVEN (×7 ALL > ×5 scoped to same 3 cards). Both are returned per the algorithm; UI should indicate TRIPLE_SEVEN as the superior choice.

- **If opponent insurance negates SPADE_BLACKJACK**: SPADE_BLACKJACK is removed from matches. BLACKJACK_TYPE was already absorbed by the absorption rule. TWENTY_ONE(×2) from Step 6 remains (absorption only removes BLACKJACK_TYPE, not TWENTY_ONE). Player falls back to TWENTY_ONE(×2).

- **If split suppresses BLACKJACK_TYPE/SPADE_BLACKJACK but hand has point_total=21 with exactly 2 cards**: Steps 7-8 are skipped. TWENTY_ONE(×2) from Step 6 still triggers. Split hands can benefit from TWENTY_ONE(×2) but never BLACKJACK_TYPE(×4) or SPADE_BLACKJACK. This is the intended split penalty.

- **If bust occurs (is_bust=true)**: Step 0 returns empty results before any detection. No hand types match. The default 1.0 multiplier is also irrelevant because the resolution engine voids all card effects for the busting player.

- **If HAMMER-invalidated cards are counted in hand type detection**: Invalidated cards remain in the hand array and participate in detection normally. PAIR, THREE_KIND, etc. trigger as expected. per_card_multiplier assigns boosted values to invalidated cards, but those cards skip execution in the resolution pipeline. Player should account for which cards are invalidated when choosing a hand type.

- **If 2-card hand [A, Q] or [A, K] reaches point_total=21**: Matches TWENTY_ONE(×2) but NOT BLACKJACK_TYPE. BLACKJACK_TYPE requires the second card to be exactly J; rank=Q or rank=K does not qualify. This is a deliberate narrowing — only A+J triggers the 杰克 bonus.

- **If 2-card hand [A, 10] reaches point_total=21**: Matches TWENTY_ONE(×2) but NOT BLACKJACK_TYPE. rank=10 does not qualify for any face-card bonus.

- **If hand has multiple independent pairs (e.g., [K,K,7,7,3])**: Two PAIRs are detected and returned. Player selects one. Unselected pair's cards receive ×1.0. Player evaluates stamp/quality stacking on each rank to pick the optimal pair.

- **If hand has 4 sevens**: 4 sevens = point_total 28 > BUST_THRESHOLD, guaranteed bust. Step 0 returns empty. No perverse incentive exists — 4 sevens is mathematically impossible to achieve without busting.

- **If AI evaluates SPADE_BLACKJACK while opponent has insurance**: Detection system is unaware of insurance status; always emits SPADE_BLACKJACK when matched. Insurance negation is handled by the calling system (resolution engine / round management), not by detection.

## Dependencies

**Upstream dependencies (this system depends on):**

| System | Type | Interface | GDD Status |
|--------|------|-----------|------------|
| 卡牌数据模型 (#1) | Hard | Reads `suit`, `rank` | Designed |
| 点数计算引擎 (#2) | Hard | Reads `PointResult` (`point_total`, `is_bust`, `card_count`) | Designed |

**Downstream dependencies (depended on by):**

| System | Type | Interface | GDD Status |
|--------|------|-----------|------------|
| 结算引擎 (#6) | Hard | Consumes `HandTypeResult` (player-selected `per_card_multiplier`) | Designed |
| 特殊玩法系统 (#8) | Hard | Provides `suppress_blackjack` flag; provides opponent insurance status | Designed |
| AI 对手系统 (#12) | Hard | Consumes `HandTypeResult` + `ai_hand_type_score` evaluation formula | Designed |
| 牌桌 UI (#15) | Hard | Consumes match list, `display_name`, `display_multiplier` for selection UI | Not designed |

**Bidirectional dependency verification:**

| System | Listed here | Listed in counterpart | Status |
|--------|-------------|----------------------|--------|
| 卡牌数据模型 | Upstream | ✓ Listed as downstream (reads suit, rank) | Consistent |
| 点数计算引擎 | Upstream | ✓ Listed as downstream (reads PointResult) | Consistent |
| 结算引擎 | Downstream | Designed (verified) | Consistent |
| AI 对手系统 | Downstream | Designed (verified) | Consistent |

## Tuning Knobs

| Knob | Type | Default | Safe Range | Affects |
|------|------|---------|------------|---------|
| `multiplier_pair` | int | 2 | 1–5 | Pair multiplier. Higher increases same-rank building value; lower makes pairs not worth pursuing |
| `multiplier_three_kind` | int | 5 | 3–7 | Three of a kind multiplier. Should exceed PAIR to maintain hierarchy |
| `multiplier_flush_uses_hand_size` | bool | true | — | Whether FLUSH uses hand size as multiplier. If false, FLUSH uses fixed `multiplier_flush_fixed` |
| `multiplier_flush_fixed` | int | 5 | 2–7 | FLUSH fixed multiplier (only effective when `multiplier_flush_uses_hand_size=false`) |
| `multiplier_triple_seven` | int | 7 | 4–10 | Triple Seven multiplier. Highest non-win multiplier in the game; raising increases 7-rank building value |
| `multiplier_twenty_one` | int | 2 | 1–4 | Twenty-One multiplier. Gap vs BLACKJACK_TYPE affects "perfect 21" bonus feel |
| `multiplier_blackjack_type` | int | 4 | 3–6 | Blackjack multiplier. Should exceed TWENTY_ONE to reward the 2-card difficulty |

**Interaction notes:**
- All multipliers should satisfy: PAIR ≤ THREE_KIND ≤ TRIPLE_SEVEN
- TRIPLE_SEVEN should remain the highest fixed multiplier (currently ×7) as a "rare but achievable" reward
- FLUSH(×hand_size) exceeding TRIPLE_SEVEN at 5+ cards is intentional — flush+multi-card combination is rarer

## Visual/Audio Requirements

本系统为纯逻辑层，无直接的视觉/音频需求。牌型检测结果的视觉反馈（牌型高亮、选择界面、倍率展示）属于牌桌 UI 系统的设计范围。

## UI Requirements

本系统无直接的 UI 组件。匹配列表和倍率数据通过 `HandTypeResult` 输出给牌桌 UI 系统消费。UI 选择界面的交互设计属于 UX 设计范围。

## Acceptance Criteria

**AC-01: Bust returns empty result**
GIVEN a hand with is_bust=true (e.g., [K, 7, 6], point_total=23)
WHEN detect_hand_types(cards, point_result) is called
THEN matches is empty, default_multiplier=1.0, has_instant_win=false.

**AC-02: Non-bust proceeds to detection**
GIVEN a hand with is_bust=false (e.g., [K, 7], point_total=17)
WHEN detect_hand_types(cards, point_result) is called
THEN detection proceeds normally and matches may be non-empty or empty.

**AC-03: PAIR detection**
GIVEN hand [7♠, 7♥, 4♦], is_bust=false, point_total=18
WHEN detect_hand_types is called
THEN matches contains PAIR with display_multiplier=2, per_card_multiplier=[2.0, 2.0, 1.0].

**AC-04: FLUSH detection + formula (M_flush = hand_size)**
GIVEN hand of 5 cards all SPADES, is_bust=false (e.g., [A♠, 3♠, 5♠, 2♠, 7♠], point_total=18)
WHEN detect_hand_types is called
THEN matches contains FLUSH with display_multiplier=5, per_card_multiplier=[5.0, 5.0, 5.0, 5.0, 5.0].

**AC-05: THREE_KIND detection**
GIVEN hand [3♠, 3♥, 3♦, 5♣], is_bust=false, point_total=14
WHEN detect_hand_types is called
THEN matches contains THREE_KIND with display_multiplier=5, per_card_multiplier=[5.0, 5.0, 5.0, 1.0].

**AC-06: TRIPLE_SEVEN detection**
GIVEN hand with exactly 3 sevens (e.g., [7♥, 7♠, 7♦]), is_bust=false, point_total=21
WHEN detect_hand_types is called
THEN matches contains TRIPLE_SEVEN with display_multiplier=7, per_card_multiplier=[7.0, 7.0, 7.0].

**AC-07: TWENTY_ONE detection**
GIVEN hand with point_total=21, is_bust=false (e.g., [K, 5, 6])
WHEN detect_hand_types is called
THEN matches contains TWENTY_ONE with display_multiplier=2, ALL-scope per_card_multiplier (all 2.0).

**AC-08: BLACKJACK_TYPE (A + J, exactly 2 cards)**
GIVEN hand of exactly 2 cards [A♠, J♥], point_total=21, is_bust=false
WHEN detect_hand_types is called
THEN matches contains BLACKJACK_TYPE with display_multiplier=4, is_instant_win=false, per_card_multiplier=[4.0, 4.0].

**AC-09: BLACKJACK_TYPE excludes rank=Q, K, 10**
GIVEN hand [A♠, Q♥] or [A♠, K♥] or [A♠, 10♥], point_total=21, is_bust=false
WHEN detect_hand_types is called
THEN matches does NOT contain BLACKJACK_TYPE. Contains TWENTY_ONE(×2).

**AC-10: SPADE_BLACKJACK detection**
GIVEN hand [A♠, J♠], point_total=21, is_bust=false
WHEN detect_hand_types is called
THEN matches contains SPADE_BLACKJACK with is_instant_win=true, has_instant_win=true.

**AC-11: SPADE_BLACKJACK requires exact (A♠, J♠)**
GIVEN hand [A♠, Q♠] or [A♠, K♠], point_total=21, is_bust=false
WHEN detect_hand_types is called
THEN matches does NOT contain SPADE_BLACKJACK. Contains TWENTY_ONE(×2).

**AC-12: Different ranks are independent**
GIVEN hand [7♠, 7♥, 3♦, 3♣], is_bust=false, point_total=20
WHEN detect_hand_types is called
THEN matches contains both PAIR(7) and PAIR(3) as separate options.

**AC-13: SPADE_BLACKJACK absorbs BLACKJACK_TYPE**
GIVEN hand [A♠, J♠], point_total=21, is_bust=false
WHEN detect_hand_types is called
THEN matches contains SPADE_BLACKJACK, does NOT contain BLACKJACK_TYPE. Still contains TWENTY_ONE(×2).

**AC-14: Split suppresses BLACKJACK_TYPE and SPADE_BLACKJACK**
GIVEN split hand (suppress_blackjack=true), exactly 2 cards [A♠, J♠], point_total=21, is_bust=false
WHEN detect_hand_types is called with suppress_blackjack=true
THEN matches does NOT contain BLACKJACK_TYPE or SPADE_BLACKJACK. Still contains TWENTY_ONE(×2).

**AC-15: TRIPLE_SEVEN and THREE_KIND(7) co-occur**
GIVEN hand [7♥, 7♠, 7♦], is_bust=false, point_total=21
WHEN detect_hand_types is called
THEN matches contains both TRIPLE_SEVEN(×7 ALL) and THREE_KIND(7)(×5 scoped).

**AC-16: FLUSH at 2-card hand**
GIVEN hand of 2 cards same suit (e.g., [3♠, 7♠]), is_bust=false, point_total=10
WHEN detect_hand_types is called
THEN FLUSH display_multiplier=2, per_card_multiplier=[2.0, 2.0].

**AC-17: AI score calculation**
GIVEN hand [D7+SWORD+RUBY_II(0), DK(1), D4(2)] (3 diamonds, point_total=21), FLUSH(×3) and TWENTY_ONE(×2) both detected
WHEN ai_hand_type_score is computed for each option
THEN FLUSH score = 3×(7+2+4) + 3×13 + 3×4 = 90. TWENTY_ONE score = 2×(7+2+4) + 2×13 + 2×4 = 60. FLUSH score > TWENTY_ONE score.

**AC-18: Output data structure completeness**
GIVEN any non-bust hand matching at least one type
WHEN detect_hand_types returns
THEN each HandTypeOption has 5 fields: type(HandType enum), display_name(non-empty String), display_multiplier(int 2–11), is_instant_win(bool), per_card_multiplier(Array[float] length=hand_size). HandTypeResult has 3 fields: matches(Array), default_multiplier=1.0, has_instant_win(bool).

## Open Questions

- [ ] Does FLUSH at 7+ cards (×7+) undermine TRIPLE_SEVEN(×7) as the "highest multiplier"? (Owner: balance tuning, target: before Alpha)
- [ ] Multi-type match UI selection method: radio buttons, card-highlight click, or auto-recommend optimal? (Owner: UX designer, target: Pre-Production)
- [ ] Can AI opponents also trigger SPADE_BLACKJACK instant win? Current design supports detection for both sides, but game concept does not specify. (Owner: game designer, target: resolution engine design phase)
