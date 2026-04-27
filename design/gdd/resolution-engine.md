# 结算引擎 (Resolution Engine)

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-04-24
> **Implements Pillar**: Core — card settlement pipeline, dual-track output, and bust resolution

## Overview

结算引擎是《决胜21点》的卡牌结算指挥中心——它将排序系统输出的有序手牌、牌型检测系统的倍率分配、印记系统的固定加成、卡质系统的双轨输出（战斗效果流和筹码流）、以及战斗状态系统的 HP/防御容器，统一编排为一条确定性的 6 阶段结算管道：爆牌检测 → 交替逐牌结算（弹出基础值 → 印记加成 → 卡质加成 → 牌型倍率 → 执行效果 → 摧毁检查）→ 防御清零 → 生死判定。在数据层面，它是连接七个核心系统的唯一调度者——每个系统只定义自己的计算规则，结算引擎决定它们在什么顺序、什么时机、什么条件下被调用。在玩家体验层面，结算引擎驱动的"卡牌一张张翻开、效果一步步执行"的结算动画，是游戏中最重要的戏剧时刻：你看着黑桃防御先挡住对手的方片伤害，看着红桃在最后一刻将你的 HP 从 0 拉回，看着宝石质卡牌在摧毁检查中闪烁——每一张牌的结算都是一次小型赌注兑现，而整条管道就是你编排的结果。没有这个系统，卡牌只是数据，花色只是颜色，牌型只是倍率——结算引擎让它们全部活起来。

## Player Fantasy

**连锁裁决 — 一牌牵动万局，步步皆为因果**

核心时刻：位置 1，你的黑桃 9 带跑鞋印记最先结算，9 点防御竖起高墙。位置 1（对手），方片 Q 重重砸上——全额吸收。位置 2，红桃 J 回复 11 点，HP 从 4 拉回 15。位置 2（对手），方片 7 造成 7 点伤害——15 降到 8。你还站着。最后一张，你的方片 K 带短剑印记结算——12 伤害直扣对手 HP。结束。你的编排是一个完整的论证：先防御，活下来，再反击。每张牌是一个前提，结算引擎是结论。

结算引擎的玩家幻想是**因果满足感**——看着一个每块拼图都不可或缺、每个位置都经过深思熟虑的计划一步步兑现。这不是老虎机，这是你自己搭建的鲁布·戈德堡机械。交替结算模式（你的牌 → 对手的牌 → 你的牌 → 对手的牌）创造了天然的张力节奏：你的牌执行（满足或恐惧），对手的牌执行（威胁或宽慰），循环往复。这个一进一出的节拍是结算引擎对游戏情感弧线的独特贡献。当你的黑桃在位置 1 完美挡住对手方片在位置 1 的攻击时，你感到聪明。当对手方片穿透了因为你把黑桃排晚了，你感到自己决策的重量。引擎从不说谎，从不掷骰子，从不以随机性制造惊喜。它只是向你展示你编排的真相。

这个幻想承接了卡牌排序系统的"赌桌操盘手"——排序说"运气到此为止，接下来由我决定"，结算引擎说"我决定的后果正在一步步展开，牌对牌，位对位"。动词从"编排"转为"见证我建造的连锁"。

## Detailed Design

### Core Rules

**1. 系统性质**

结算引擎是一个确定性管道系统。给定相同的输入（排序后的手牌、点数结果、牌型倍率、战斗状态），始终产出相同的结算结果（宝石质摧毁检查除外，其使用独立随机数生成器）。结算引擎不持有跨回合的可变状态。

**2. 输入数据**

结算引擎在启动时接收以下输入（由回合管理系统和各子系统提供）：

| 输入 | 来源 | 说明 |
|------|------|------|
| `player_sorted_hand` | 卡牌排序系统 | 玩家有序手牌（已含结算位编号） |
| `ai_sorted_hand` | 卡牌排序系统 | AI 有序手牌 |
| `player_point_result` | 点数计算引擎 | 玩家手牌点数 |
| `ai_point_result` | 点数计算引擎 | AI 手牌点数 |
| `player_per_card_multiplier` | 牌型检测系统 | 玩家每卡倍率数组 |
| `ai_per_card_multiplier` | 牌型检测系统 | AI 每卡倍率数组 |
| `player_hand_type_result` | 牌型检测系统 | 含 SPADE_BLACKJACK 标志 |
| `ai_hand_type_result` | 牌型检测系统 | 含 SPADE_BLACKJACK 标志 |
| `settlement_first_player` | 回合管理 | 结算先手方（PLAYER 或 AI），由点数比较决定（非发牌先手方） |
| `player_insurance_active` | 特殊玩法系统 | 对手是否购买了保险且生效 |
| `ai_insurance_active` | 特殊玩法系统 | 对手是否购买了保险且生效 |
| `skip_defense_reset` | 回合管理 | 分牌时跳过 Phase 7a（防御清零），延迟到手牌 B 完成后。默认 false |

**3. 三层管道架构**

```
Layer 1: 前处理（结算循环前执行一次）
  Phase 0a: SPADE_BLACKJACK 即时胜利检查
  Phase 0b: 爆牌检测 + 爆牌自伤
  Phase 0c: 重锤预扫描（标记无效化目标）

Layer 2: 逐牌结算循环（交替：P1→A1→P2→A2→...）
  Phase 1: 弹出基础值
  Phase 2: 印记加成
  Phase 3: 卡质加成
  Phase 4: 牌型倍率
  Phase 5: 执行效果（分流派发）
  Phase 6: 宝石摧毁检查

Layer 3: 后处理（结算循环后执行一次）
  Phase 7a: 防御清零
  Phase 7b: 生死判定
```

**4. Phase 0a: SPADE_BLACKJACK 即时胜利检查**

```
IF player_hand_type_result.has_instant_win AND NOT ai_insurance_active:
    → PLAYER_INSTANT_WIN（跳至 Phase 7，跳过所有中间阶段）
ELIF ai_hand_type_result.has_instant_win AND NOT player_insurance_active:
    → AI_INSTANT_WIN（跳至 Phase 7，跳过所有中间阶段）
ELIF 双方均有 SPADE_BLACKJACK:
    → 互相否定，进入正常结算（双方回退至 TWENTY_ONE ×2）
```

即时胜利跳过所有后续结算阶段（0b-6），包括宝石摧毁检查。即时胜利方的卡牌不执行任何效果，但也不承受任何风险。

**5. Phase 0b: 爆牌检测 + 爆牌自伤**

```
player_bust = player_point_result.is_bust
ai_bust = ai_point_result.is_bust

IF 双方均爆牌:
    combat_state.apply_bust_damage(PLAYER, player_point_result.point_total)
    combat_state.apply_bust_damage(AI, ai_point_result.point_total)
    → 标记双方所有卡牌为"爆牌无效"，跳至 Phase 7

ELIF 仅玩家爆牌:
    combat_state.apply_bust_damage(PLAYER, player_point_result.point_total)
    → 标记玩家所有卡牌为"爆牌无效"
    → AI 卡牌连续逐张结算（无交替，无 Phase 0c 重锤扫描）
    → 跳至 Phase 7

ELIF 仅 AI 爆牌:
    combat_state.apply_bust_damage(AI, ai_point_result.point_total)
    → 标记 AI 所有卡牌为"爆牌无效"
    → 玩家卡牌连续逐张结算（无交替，无 Phase 0c 重锤扫描）
    → 跳至 Phase 7

ELSE:
    → 进入 Phase 0c
```

爆牌自伤绕过防御，直接扣减 HP。爆牌方所有卡牌的花色效果、印记效果、卡质效果、牌型倍率全部无效。爆牌方的宝石质卡牌跳过摧毁检查（当前回合保护）。

**6. Phase 0c: 重锤预扫描**

在交替结算开始前，扫描双方所有"存活"卡牌的重锤印记：

```
FOR pos = 1 TO max(player_hand_size, ai_hand_size):
    player_card = player_sorted_hand[pos-1]
    ai_card = ai_sorted_hand[pos-1]

    player_hammer = (player_card ≠ null AND player_card.stamp == HAMMER)
    ai_hammer = (ai_card ≠ null AND ai_card.stamp == HAMMER)

    IF player_hammer AND ai_card ≠ null:
        MARK ai_card as "invalidated"
    IF ai_hammer AND player_card ≠ null:
        MARK player_card as "invalidated"
```

**"无效化"定义**：被标记的卡牌跳过 Phase 1-6（不弹出基础值，不加成，不执行效果，不做摧毁检查）。卡牌保留在手牌中，结算位编号不变，位置被保留为空操作。

**对称处理**：当双方在相同位置都拥有重锤时，两张卡牌互相无效化（无先手优势）。被重锤无效化的卡牌的宝石质在当前回合受到保护（跳过 Phase 6 摧毁检查）。

**7. Phase 1-4: 逐卡计算（纯计算，无副作用）**

对每张非无效卡牌，按顺序执行四个纯计算阶段，构建两个累加器：

| 阶段 | combat_effect 流 | chip_output 流 |
|-------|-----------------|---------------|
| Phase 1: 弹出基础值 | `effect_value` (查 effect_value_lookup) | `chip_value_base` (CLUBS=chip_value, else=0) |
| Phase 2: 印记加成 | `+ stamp_combat_bonus` (SWORD/SHIELD/HEART=2, else=0) | `+ stamp_coin_bonus` (COIN=10, else=0) |
| Phase 3: 卡质加成 | `+ gem_quality_bonus` (RUBY/SAPPHIRE/OBSIDIAN 按等级) | `+ metal_chip_bonus + gem_chip_bonus` (金属或祖母绿按等级) |
| Phase 4: 牌型倍率 | `× per_card_multiplier[pos-1]` | `× per_card_multiplier[pos-1]` |

Phase 1-3 构建预倍率总和，Phase 4 一次性应用倍率。四个阶段均为纯算术运算，不调用任何外部 API，不修改任何状态。

**8. Phase 5: 执行效果（分流派发）**

印记战斗加成始终按印记类型派发，而非卡牌花色（追踪分离法）：

```
// 计算卡牌花色效果（不含印记战斗部分）
suit_base = (card.effect_value + gem_quality_bonus) × M

// 计算印记独立战斗效果
stamp_base = stamp_combat_bonus × M

// 按卡牌花色派发花色效果
MATCH card.suit:
    DIAMONDS → combat_state.apply_damage(opponent, suit_base)
    HEARTS   → combat_state.apply_heal(self, suit_base)
    SPADES   → combat_state.add_defense(self, suit_base)
    CLUBS    → (无战斗效果)

// 按印记类型派发印记独立战斗效果
IF card.stamp == SWORD:
    combat_state.apply_damage(opponent, stamp_base)  // 始终伤害
ELIF card.stamp == SHIELD:
    combat_state.add_defense(self, stamp_base)        // 始终防御
ELIF card.stamp == HEART:
    combat_state.apply_heal(self, stamp_base)         // 始终回复
// HAMMER/COIN/RUNNING_SHOES/TURTLE/null: 无印记战斗效果

// 派发筹码流（单流，无分流）
IF chip_acc > 0:
    chip_economy.add_chips(side.owner, chip_acc)
```

**示例**：黑桃 9 + SWORD + 无卡质 + 无牌型 → suit_base=(9+0)×1=9 防御, stamp_base=2×1=2 伤害 → `add_defense(self, 9)` + `apply_damage(opponent, 2)`

**9. Phase 6: 宝石摧毁检查**

```
IF card.quality ∈ {RUBY, SAPPHIRE, EMERALD, OBSIDIAN}:
    IF randf() < gem_destroy_prob(card.quality_level):
        card.quality = null
        card.quality_level = III
```

每张宝石质卡牌独立掷骰。摧毁在当次效果完整执行后发生（"事后结算"）。摧毁不影响印记。

**10. 交替结算模式**

当双方均未爆牌时，按交替模式结算：

```
pos = 1
max_pos = max(len(player_sorted_hand), len(ai_sorted_hand))

WHILE pos <= max_pos:
    // 先手方的卡牌
    card = settlement_first_player.sorted_hand[pos-1]
    IF card ≠ null AND NOT card.invalidated:
        执行 Phase 1-6

    // 后手方的卡牌
    card = settlement_second_player.sorted_hand[pos-1]
    IF card ≠ null AND NOT card.invalidated:
        执行 Phase 1-6

    pos += 1
```

当一方手牌数少于另一方时，较长一方的多余位置无对手卡牌（跳过该方的结算轮次）。

**11. 单方连续结算模式**

当仅一方爆牌时，非爆牌方的卡牌连续逐张结算（无交替，无重锤预扫描）：

```
FOR pos = 1 TO len(non_busting_side.sorted_hand):
    card = non_busting_side.sorted_hand[pos-1]
    IF card ≠ null AND NOT card.invalidated:
        执行 Phase 1-6
```

非爆牌方的重锤印记得无效果——爆牌方的卡牌已被爆牌标记为无效，重锤额外的无效化是幂等的。为简化实现，爆牌情况下跳过 Phase 0c。

**12. Phase 7a: 防御清零**

所有卡牌结算完成后（无论哪种结算模式），双方防御重置为 0：

```
combat_state.reset_defense()
```

**13. Phase 7b: 生死判定**

防御清零后，统一执行生死判定（不在结算中途判定）：

```
result = combat_state.get_round_result()
// CONTINUE / PLAYER_WIN / PLAYER_LOSE
```

### States and Transitions

```
[接收输入]
    │
    ▼
[Phase 0a: SPADE_BLACKJACK 检查]
    │
    ├─ 即时胜利 → [Phase 7: 后处理]（跳过 0b-6）
    │
    ▼
[Phase 0b: 爆牌检测]
    │
    ├─ 双方爆牌 → 自伤双方 → [Phase 7]
    ├─ 仅一方爆牌 → 自伤爆牌方 → [单方连续结算] → [Phase 7]
    │
    ▼
[Phase 0c: 重锤预扫描]
    │
    ▼
[Phase 1-6: 交替结算循环]
    │ pos=1 → settlement_first_player → settlement_second_player → pos=2 → ...
    │ 每张非无效卡牌: 计算(1-4) → 派发(5) → 摧毁检查(6)
    ▼
[Phase 7a: 防御清零]
    │
    ▼
[Phase 7b: 生死判定]
    │
    ├─ CONTINUE → [返回回合管理，进入下一回合]
    ├─ PLAYER_WIN → [进入商店阶段]
    └─ PLAYER_LOSE → [游戏结束]
```

### Interactions with Other Systems

| 系统 | 结算引擎接收什么 | 结算引擎提供什么 | 触发时机 |
|------|-----------------|-----------------|---------|
| 卡牌数据模型 (#1) | 读取 CardInstance 的 suit, rank, effect_value, chip_value, stamp, quality, quality_level | 无 | 每张卡牌结算时 |
| 点数计算引擎 (#2) | PointResult (point_total, is_bust) | 无 | Phase 0b |
| 牌型检测系统 (#3) | per_card_multiplier[], has_instant_win | 无 | Phase 0a, Phase 4 |
| 印记系统 (#4) | stamp_bonus_lookup (SWORD=2, SHIELD=2, HEART=2, COIN=10) | 无 | Phase 2 |
| 卡质系统 (#5) | quality_bonus_resolve(), gem_destroy_prob() | 写入 quality=null（摧毁时） | Phase 3, Phase 6 |
| 卡牌排序系统 (#6a) | sorted_hand[], 结算位编号 | 无 | 启动时 |
| 战斗状态系统 (#7) | apply_damage(), apply_heal(), add_defense(), apply_bust_damage(), reset_defense(), get_round_result() | 无 | Phase 0b, 5, 7 |
| 筹码经济系统 (#10) | 无 | add_chips(owner, amount) | Phase 5 |
| 特殊玩法系统 (#8) | insurance_active 标志 | 无 | Phase 0a |
| 回合管理 (#13) | settlement_first_player, 启动信号 | 结算结果 (round_result) | 启动时 |
| AI 对手系统 (#12) | AI sorted_hand, AI per_card_multiplier | 无 | 启动时 |
| 牌桌 UI (#15) | 无 | 每张卡牌的结算事件流（基础值、加成、最终值、摧毁结果） | Phase 1-6 |

结算引擎是唯一调用战斗状态系统 API 的系统（除商店直接调用 apply_heal 外）。所有伤害/回复/防御操作都通过结算引擎统一派发。

## Formulas

### 1. 花色效果派发 (suit_effect_dispatch)

The `suit_effect_dispatch` formula is defined as:

`suit_effect = (effect_value + gem_quality_bonus) × M`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| effect_value | V_e | int | 2 ~ 15 | 卡牌原型效果值 (effect_value_lookup) |
| gem_quality_bonus | V_gq | int | 0 ~ 5 | 宝石质战斗加成 (quality_bonus_resolve) |
| M | M | float | 1.0 ~ 11.0 | 每卡倍率 (per_card_multiplier) |

**Output Range:** [2, 220]。最小 = 2×1.0（2 号牌，无宝石，无牌型）。最大 = (15+5)×11 = 220（方片 A + 红水晶 I 级 + 同花 11 张）。
**示例:** 方片 7 + RUBY II (+4) + PAIR(×2) → (7+4)×2 = **22 伤害**

### 2. 印记效果派发 (stamp_effect_dispatch)

The `stamp_effect_dispatch` formula is defined as:

`stamp_effect = stamp_combat_bonus × M`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| stamp_combat_bonus | V_sc | int | 0 ~ 2 | 印记战斗加成 (stamp_bonus_lookup: SWORD/SHIELD/HEART=2, others=0) |
| M | M | float | 1.0 ~ 11.0 | 每卡倍率 (per_card_multiplier) |

**Output Range:** [0, 22]。最小 = 0（非战斗印记或无印记）。最大 = 2×11 = 22（SWORD + 同花 11 张）。
**示例:** SWORD 印记 + PAIR(×2) → 2×2 = **4 伤害**（始终作为伤害派发，无视卡牌花色）

### 3. 追踪分离恒等式 (track_separation_identity)

```
combat_effect = suit_effect_dispatch + stamp_effect_dispatch
             = (effect_value + gem_quality_bonus) × M + stamp_combat_bonus × M
             = (effect_value + stamp_combat_bonus + gem_quality_bonus) × M
```

此恒等式保证已注册的 `combat_effect` 公式保持不变——追踪分离法是其加法分解，不改变数值结果。`combat_effect` 代表战斗效果总量；`suit_effect_dispatch` 和 `stamp_effect_dispatch` 是 Phase 5 派发时的两个独立流。

### 4. 结算位数 (settlement_position_count)

The `settlement_position_count` formula is defined as:

`N = max(len(player_sorted_hand), len(ai_sorted_hand))`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| player_sorted_hand | H_p | Array | 1 ~ 11 | 玩家排序后手牌 |
| ai_sorted_hand | H_a | Array | 1 ~ 11 | AI 排序后手牌 |

**Output Range:** [1, 11]。受 `ui_hand_display_limit` = 11 约束。
**示例:** 玩家 4 张牌，AI 3 张牌 → N=4。位置 4 仅玩家卡牌结算，AI 方跳过。

### 5. 宝石摧毁检查 (gem_destroy_check)

The `gem_destroy_check` formula is defined as:

`is_destroyed = (card.quality ∈ {RUBY, SAPPHIRE, EMERALD, OBSIDIAN}) AND (randf() < gem_destroy_prob(card.quality_level))`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| card.quality | Q | enum or null | 8 types + null | 卡牌当前品质 |
| card.quality_level | L | enum | {III, II, I} | 品质等级 |
| gem_destroy_prob | P_d | float | 0.05 ~ 0.15 | 来自 gem_destroy_prob 查找 |
| is_destroyed | D | bool | {true, false} | 宝石品质是否被摧毁 |

**Output Range:** 仅宝石质卡牌参与掷骰；金属质和 null 品质始终返回 false。
**示例:** RUBY III → is_gem=true, P_d=0.15, roll=0.12 < 0.15 → **摧毁**。品质设为 null，等级重置为 III。

## Edge Cases

- **If 双方均有 SPADE_BLACKJACK**: 互相否定优先于保险检查。无论双方是否购买保险，双方 SPADE_BLACKJACK 均不触发，进入正常结算。双方回退至 TWENTY_ONE (×2)（牌型检测系统的吸收规则保证 BLACKJACK_TYPE 已被移除，但 TWENTY_ONE 仍保留）。

- **If SPADE_BLACKJACK 被对手保险无效化**: 玩家失去即时胜利，所有卡牌进入正常结算管道（含 Phase 6 宝石摧毁检查）。作为保险的附加效果，玩家的宝石质卡牌在本回合暴露于摧毁风险之下——即时胜利本可跳过摧毁检查，但保险使管道完整运行，包括 Phase 6。玩家从"即时胜利 + 宝石保护"降级为"TWENTY_ONE ×2 + 宝石风险"。

- **If 一方手牌为空（0 张卡牌）**: 管道正常运行。空方 settlement_position_count 贡献 0，所有位置均由对手方结算。空方不触发任何效果、不构建防御、不产出筹码。防御清零后进入生死判定。这是理论边界情况——正常游戏中不应出现（21 点规则保证至少 2 张起始牌），但管道优雅退化不报错。

- **If HAMMER 无效化一张宝石质卡牌**: 被无效化的卡牌跳过 Phase 1-6，宝石质在当前回合受到保护（不触发摧毁检查）。但 HAMMER 持有者自身的宝石质卡牌仍正常进入 Phase 6 摧毁检查——HAMMER 保护目标，不保护使用者。

- **If HAMMER 卡牌自身也拥有宝石质**: HAMMER 在 Phase 0c 标记对手卡牌无效，自身的花色效果和宝石质在 Phase 1-6 正常执行（包括 Phase 6 摧毁检查）。无效化和自身结算是两个独立的管道阶段，无冲突。这是一张高风险高回报的组合牌：你摧毁对手卡牌效果的同时承受宝石摧毁风险。

- **If 重锤预扫描标记了参与牌型检测的卡牌**: 牌型检测在 Phase 0c 之前完成（排序后、结算前）。被 HAMMER 无效化的卡牌仍参与了牌型检测和倍率分配——`per_card_multiplier` 数组在 HAMMER 扫描前已冻结。被无效化的卡牌保留了分配的倍率但不执行。这意味着剩余的同类卡牌仍享受倍率加成。例：[7,7,3] 检测出 PAIR，对手 HAMMER 无效化其中一张 7，幸存的 7 仍以 ×2 执行。

- **If 先手方在同一结算位先建防御，后手方随后攻击**: 交替结算的天然时序使先手方在每个位置享有防御优势——先手方的 pos N 结算先于后手方的 pos N。先手方的黑桃防御可以在同一位置挡住后手方的方片伤害。先后手由回合管理系统轮换决定，这是管道设计的固有特性而非缺陷。

- **If 非对称手牌中 HAMMER 在对手无卡牌的位置**: HAMMER 无目标，效果浪费。卡牌自身的花色效果正常执行。例：玩家 5 张牌，AI 2 张牌，玩家的 HAMMER 在 pos 4 无效——无 AI 卡牌可标记。

- **If 双方在不同位置拥有 HAMMER**: 各自独立生效，互不影响。玩家 pos 2 的 HAMMER 无效化 AI pos 2 的卡牌；AI pos 3 的 HAMMER 无效化玩家 pos 3 的卡牌。只有同一位置双方均有 HAMMER 时才互相无效化。

- **If 仅一方爆牌，非爆牌方的卡牌连续结算**: 无交替模式，无 Phase 0c 重锤预扫描。非爆牌方的 HAMMER 卡牌仍执行花色效果，但爆牌方的卡牌已被爆牌标记为无效——HAMMER 的额外无效化是幂等的，跳过预扫描简化实现。

- **If Phase 5 产出为零的卡牌仍触发 Phase 6**: 宝石摧毁检查独立于 Phase 5 的输出值。即使卡牌因倍率为 0（未来机制可能性）或基础值为 0 而不产生任何战斗/筹码效果，Phase 6 摧毁检查仍正常执行。当前版本中 `per_card_multiplier` 最小值为 1.0，此情况不会发生，但管道设计保证 Phase 6 始终在宝石质卡牌上运行。

- **If 爆牌自伤将 HP 降至 0，非爆牌方的后续伤害叠加**: 爆牌自伤先执行（Phase 0b），然后非爆牌方的卡牌连续结算。非爆牌方的方片伤害在爆牌自伤之后进一步扣减 HP。爆牌方承受双重打击：自伤 + 对手攻击，且爆牌方无防御（防御在回合开始时为 0，爆牌方无卡牌构建防御）。

## Dependencies

**上游依赖（本系统依赖）:**

| 系统 | 依赖类型 | 接口 | GDD 状态 |
|------|---------|------|---------|
| 卡牌数据模型 (#1) | 硬 | 读取 suit, rank, effect_value, chip_value, stamp, quality, quality_level | 已完成 |
| 点数计算引擎 (#2) | 硬 | PointResult (point_total, is_bust) | 已完成 |
| 牌型检测系统 (#3) | 硬 | per_card_multiplier[], has_instant_win | 已完成 |
| 印记系统 (#4) | 硬 | stamp_bonus_lookup (数值型加成) | 已完成 |
| 卡质系统 (#5) | 硬 | quality_bonus_resolve(), gem_destroy_prob(); 写入 quality=null (摧毁) | 已完成 |
| 卡牌排序系统 (#6a) | 硬 | sorted_hand[], 结算位编号 | 已完成 |
| 战斗状态系统 (#7) | 硬 | apply_damage(), apply_heal(), add_defense(), apply_bust_damage(), reset_defense(), get_round_result() | 已完成 |
| 特殊玩法系统 (#8) | 软 | insurance_active 标志 (Phase 0a 保险检查) | 已设计 |
| 回合管理 (#13) | 软 | settlement_first_player 先手标志, 启动信号 | 未设计 |

**下游依赖（被依赖）:**

| 系统 | 依赖类型 | 接口 | GDD 状态 |
|------|---------|------|---------|
| 筹码经济系统 (#10) | 硬 | add_chips(owner, amount) — Phase 5 筹码派发 | 已设计 |
| 回合管理 (#13) | 硬 | 结算结果 (round_result: CONTINUE/PLAYER_WIN/PLAYER_LOSE) | 未设计 |
| 牌桌 UI (#15) | 软 | 每张卡牌的结算事件流（基础值、各加成、最终值、摧毁结果） | 未设计 |
| 特殊玩法系统 (#8) | 间接 | 结算引擎为特殊玩法提供结算管道，特殊玩法的分牌/双倍下注通过输入参数影响管道行为 | 已设计 |

**双向依赖验证:**

| 系统 | 本文档列出 | 对方文档是否列出本系统 | 状态 |
|------|-----------|---------------------|------|
| 卡牌数据模型 | 上游硬依赖 | ✓ 下游（结算引擎读取 CardInstance 属性） | 一致 |
| 点数计算引擎 | 上游硬依赖 | ✓ 下游（结算引擎消费 PointResult） | 一致 |
| 牌型检测系统 | 上游硬依赖 | ✓ 下游（结算引擎消费 per_card_multiplier） | 一致 |
| 印记系统 | 上游硬依赖 | ✓ 下游（结算引擎消费 stamp_bonus） | 一致 |
| 卡质系统 | 上游硬依赖 | ✓ 下游（结算引擎消费 quality bonus + 写入摧毁） | 一致 |
| 卡牌排序系统 | 上游硬依赖 | ✓ 下游（结算引擎消费 sorted_hand） | 一致 |
| 战斗状态系统 | 上游硬依赖 | ✓ 下游（结算引擎调用 combat state API） | 一致 |
| 筹码经济系统 | 下游 | 已设计（已验证） | 一致 |
| 回合管理 | 双向 | 未设计（待验证） | 待确认 |

## Tuning Knobs

结算引擎的大部分数值由依赖系统定义。本系统引入的调参点仅限于管道行为控制：

| 调参点 | 类型 | 默认值 | 安全范围 | 影响什么 |
|--------|------|--------|----------|---------|
| `logic_settle_delay_ms` | int | 500 | 100 ~ 2000 | 结算管道中每步之间的逻辑延迟（毫秒）。控制结算节奏。0 = 无延迟（测试/debug 模式） |
| `phase_animation_enabled` | bool | true | — | 是否在 Phase 1-6 之间显示逐层加成动画。false = 仅显示最终值。影响 UI 体验，不影响逻辑 |
| `gem_destroy_rng_seed` | int | -1 | -1 ~ MAX_INT | 宝石摧毁检查的 RNG 种子。-1 = 真随机（生产环境），其他值 = 固定种子（测试/replay 用） |

**依赖系统的调参点（本系统消费但不拥有）:**

| 调参点 | 来源 | 本系统如何消费 |
|--------|------|--------------|
| `stamp_sword_bonus` / `stamp_shield_bonus` / `stamp_heart_bonus` / `stamp_coin_bonus` | 印记系统 | Phase 2 加成计算 |
| `gem_destroy_prob_iii` / `_ii` / `_i` | 卡质系统 | Phase 6 摧毁概率 |
| `multiplier_*` (9 种牌型倍率) | 牌型检测系统 | Phase 4 倍率来源 |
| `player_max_hp` / `ai_hp_table` | 战斗状态系统 | Phase 5/7 HP 操作 |
| `BUST_THRESHOLD` | 点数计算引擎 | Phase 0b 爆牌阈值 |

## Acceptance Criteria

### Phase 0a: SPADE_BLACKJACK

**AC-01: 即时胜利 — 玩家**
GIVEN 玩家 `has_instant_win=true`, AI `has_instant_win=false`, `ai_insurance_active=false`
WHEN Phase 0a 执行
THEN 结果=PLAYER_INSTANT_WIN; Phase 0b-6 全部跳过; 玩家宝石卡牌跳过摧毁检查; AI 不承受伤害; 管道跳至 Phase 7

**AC-02: 即时胜利 — AI**
GIVEN AI `has_instant_win=true`, 玩家 `has_instant_win=false`, `player_insurance_active=false`
WHEN Phase 0a 执行
THEN 结果=AI_INSTANT_WIN; Phase 0b-6 全部跳过; 玩家承受 0 伤害

**AC-03: 双方 SPADE_BLACKJACK — 互相否定**
GIVEN 双方 `has_instant_win=true`
WHEN Phase 0a 执行
THEN 双方即时胜利均不触发; 管道进入 Phase 0b; 双方 per_card_multiplier 反映 TWENTY_ONE ×2（BLACKJACK_TYPE 已被吸收，TWENTY_ONE 保留）

**AC-04: 保险否定 SPADE_BLACKJACK — 回退 TWENTY_ONE**
GIVEN 玩家 `has_instant_win=true`, AI `insurance_active=true`
WHEN Phase 0a 执行
THEN 玩家即时胜利被否定; 管道进入正常结算; 玩家 per_card_multiplier 反映 TWENTY_ONE ×2; 玩家宝石卡牌执行 Phase 6 摧毁检查（即时胜利的保护被保险移除）

### Phase 0b: 爆牌检测

**AC-05: 双方爆牌 — 全部无效**
GIVEN 玩家 `is_bust=true`, point_total=24; AI `is_bust=true`, point_total=26; 玩家 HP=50, AI HP=80
WHEN Phase 0b 执行
THEN `apply_bust_damage(PLAYER, 24)` 和 `apply_bust_damage(AI, 26)` 被调用; 玩家 HP=26, AI HP=54; 双方所有卡牌标记"爆牌无效"; Phase 0c-6 跳过; 管道跳至 Phase 7

**AC-06: 仅玩家爆牌 — AI 连续结算**
GIVEN 玩家 `is_bust=true`, point_total=22, HP=40; AI `is_bust=false`, 手牌: [黑桃9, 方片5]
WHEN Phase 0b 执行
THEN `apply_bust_damage(PLAYER, 22)` 调用; 玩家 HP=18; 玩家所有卡牌标记"爆牌无效"; Phase 0c 跳过; AI 黑桃9: `add_defense(AI, 9)`; AI 方片5: `apply_damage(PLAYER, 5)`; 玩家 HP=13

**AC-07: 仅 AI 爆牌 — 玩家连续结算**
GIVEN AI `is_bust=true`, point_total=25, HP=60; 玩家 `is_bust=false`, 手牌: [方片K, 红桃J]
WHEN Phase 0b 执行
THEN `apply_bust_damage(AI, 25)` 调用; AI HP=35; AI 所有卡牌标记"爆牌无效"; 玩家方片K: `apply_damage(AI, 13)`; AI HP=22; 玩家红桃J: `apply_heal(PLAYER, 11)`

**AC-08: 双方均未爆牌 — 进入 Phase 0c**
GIVEN 双方 `is_bust=false`
WHEN Phase 0b 执行
THEN 无自伤; 无卡牌标记; 管道进入 Phase 0c

### Phase 0c: 重锤预扫描

**AC-09: 重锤无效化对手卡牌**
GIVEN 玩家手牌: [黑桃9, 方片7+HAMMER, 红桃J]; AI 手牌: [方片Q, 方片5, 方片3]
WHEN Phase 0c 执行
THEN AI 方片5 标记"invalidated"; AI 方片5 跳过 Phase 1-6; 玩家方片7 花色效果正常执行

**AC-10: 同位置双方重锤 — 互相无效化**
GIVEN 玩家 pos 3 = 方片K+HAMMER; AI pos 3 = 红桃J+HAMMER
WHEN Phase 0c 执行
THEN 双方 pos 3 卡牌标记"invalidated"; 双方都不产生效果; 无先手优势

**AC-11: 非对称手牌 — 重锤无目标**
GIVEN 玩家 5 张牌（HAMMER 在 pos 4）; AI 2 张牌
WHEN Phase 0c 执行
THEN pos 4 无 AI 卡牌; 无卡牌被标记; 玩家 pos 4 花色效果正常执行

**AC-12: 不同位置重锤 — 独立生效**
GIVEN 玩家 pos 2 = 方片7+HAMMER; AI pos 3 = 红桃J+HAMMER; 玩家 pos 3 = 黑桃K; AI pos 2 = 方片5
WHEN Phase 0c 执行
THEN 玩家 HAMMER(pos2) 标记 AI 方片5; AI HAMMER(pos3) 标记玩家黑桃K; 两个无效化独立生效

### Phase 1-6: 逐卡结算

**AC-13: 交替结算顺序**
GIVEN 双方未爆牌; `settlement_first_player=PLAYER`; 玩家手牌: [A, B, C]; AI 手牌: [X, Y]
WHEN Layer 2 执行
THEN 结算顺序: P-pos1(A) → A-pos1(X) → P-pos2(B) → A-pos2(Y) → P-pos3(C); pos 3 AI 跳过

**AC-14: 先手防御优势**
GIVEN `settlement_first_player=PLAYER`; 玩家 pos 1 = 黑桃9 (M=1.0); AI pos 1 = 方片12 (M=1.0)
WHEN pos 1 结算
THEN 玩家黑桃9 先结算: `add_defense(PLAYER, 9)`; AI 方片12 后结算: `apply_damage(PLAYER, 12)` → 防御吸收 9, HP 受到 3 伤害

**AC-15: 方片花色 — 伤害**
GIVEN 方片7, 无印记, 无卡质, M=1.0; AI HP=60, AI defense=0
WHEN Phase 5 执行
THEN `apply_damage(AI, 7)`; AI HP=53

**AC-16: 红桃花色 — 回复**
GIVEN 红桃J (effect_value=11), 无印记, 无卡质, M=1.0; 玩家 HP=40
WHEN Phase 5 执行
THEN `apply_heal(PLAYER, 11)`; 玩家 HP=51

**AC-17: 黑桃花色 — 防御**
GIVEN 黑桃9, 无印记, 无卡质, M=1.0; 玩家 defense=0
WHEN Phase 5 执行
THEN `add_defense(PLAYER, 9)`; 玩家 defense=9

**AC-18: 草花花色 — 无战斗效果，仅筹码**
GIVEN 草花K (effect_value=13, chip_value=65), 无印记, 无卡质, M=1.0
WHEN Phase 5 执行
THEN 无 combat_state 调用; `chip_output=65`; `add_chips(owner, 65)` 被调用

**AC-19: 追踪分离 — 黑桃+SWORD = 防御+伤害**
GIVEN 黑桃9 + SWORD, 无卡质, M=1.0; AI HP=50
WHEN Phase 5 执行
THEN suit_base=(9+0)×1=9 → `add_defense(PLAYER, 9)`; stamp_base=2×1=2 → `apply_damage(AI, 2)`

**AC-20: 追踪分离 — 方片+SHIELD = 伤害+防御**
GIVEN 方片7 + SHIELD, 无卡质, M=1.0; AI HP=50
WHEN Phase 5 执行
THEN suit_base=(7+0)×1=7 → `apply_damage(AI, 7)`; stamp_base=2×1=2 → `add_defense(PLAYER, 2)`

**AC-21: 追踪分离 — COIN 印记无战斗效果**
GIVEN 方片7 + COIN, 无卡质, M=1.0; AI HP=50
WHEN Phase 5 执行
THEN suit_base=(7+0)×1=7 → `apply_damage(AI, 7)`; stamp_combat_bonus=0 → 无印记战斗派发; chip_output 含 COIN +10

### Phase 7: 后处理

**AC-22: 防御清零**
GIVEN 玩家 defense=18, AI defense=10, 所有卡牌结算完毕
WHEN Phase 7a 执行
THEN `reset_defense()` 被调用; 双方 defense=0

**AC-23: 生死判定 — 双方存活**
GIVEN 玩家 HP=30, AI HP=20, 防御已清零
WHEN Phase 7b 执行
THEN 结果=CONTINUE

**AC-24: 生死判定 — 玩家胜利**
GIVEN 玩家 HP=30, AI HP=0, 防御已清零
WHEN Phase 7b 执行
THEN 结果=PLAYER_WIN

**AC-25: 生死判定 — 同时死亡判负**
GIVEN 玩家 HP=0, AI HP=0, 防御已清零
WHEN Phase 7b 执行
THEN 结果=PLAYER_LOSE

**AC-26: 中途 HP=0 不中止 — 后续红桃救回**
GIVEN 玩家 HP=10, defense=0, 结算顺序: 方片12(pos2), 红桃8(pos4)
WHEN 结算执行完毕
THEN pos 2 后玩家 HP=0; 结算未中止; pos 4 后玩家 HP=8; Phase 7b: HP=8 > 0 → CONTINUE

### 公式

**AC-F1: suit_effect_dispatch — 基础值**
GIVEN 方片2 (effect_value=2), 无卡质, M=1.0
WHEN 计算 suit_effect_dispatch
THEN (2+0)×1.0 = **2**

**AC-F2: suit_effect_dispatch — 宝石加成 + 倍率**
GIVEN 方片7 + RUBY II (+4), 无印记, PAIR M=2.0
WHEN 计算 suit_effect_dispatch
THEN (7+4)×2.0 = **22**

**AC-F3: suit_effect_dispatch — 最大理论值**
GIVEN 方片A (effect_value=15) + RUBY I (+5), FLUSH M=11.0
WHEN 计算 suit_effect_dispatch
THEN (15+5)×11 = **220**

**AC-F4: stamp_effect_dispatch — 战斗印记**
GIVEN SWORD 印记, PAIR M=2.0
WHEN 计算 stamp_effect_dispatch
THEN 2×2.0 = **4**

**AC-F5: stamp_effect_dispatch — 非战斗印记**
GIVEN COIN 印记, PAIR M=2.0
WHEN 计算 stamp_effect_dispatch
THEN 0×2.0 = **0**

**AC-F6: 追踪分离恒等式验证**
GIVEN 方片7 + SWORD (+2) + RUBY II (+4), PAIR M=2.0
WHEN 计算 suit_effect + stamp_effect
THEN suit_effect=(7+4)×2=22; stamp_effect=2×2=4; 总和=26; 等价于 combat_effect=(7+2+4)×2=26 ✓

**AC-F7: settlement_position_count — 非对称**
GIVEN 玩家 4 张牌, AI 3 张牌
WHEN 计算 settlement_position_count
THEN max(4, 3) = **4**

**AC-F8: gem_destroy_check — 宝石摧毁**
GIVEN 卡牌 RUBY III (destroy_prob=0.15); 模拟掷骰返回 0.12
WHEN Phase 6 执行
THEN 0.12 < 0.15 → 摧毁; quality=null, quality_level=III, stamp 不变

**AC-F9: gem_destroy_check — 宝石幸存**
GIVEN 卡牌 RUBY I (destroy_prob=0.10); 模拟掷骰返回 0.35
WHEN Phase 6 执行
THEN 0.35 < 0.10 为 false; quality=RUBY I 不变

**AC-F10: gem_destroy_check — 金属质永不检查**
GIVEN 卡牌 GOLD I
WHEN Phase 6 执行
THEN 无掷骰; quality=GOLD I 不变

### 边界情况

**AC-E1: HAMMER 无效化宝石质 — 保护目标不保护使用者**
GIVEN 玩家 pos 2 = 方片7+HAMMER+RUBY III; AI pos 2 = 红桃J+SAPPHIRE II
WHEN Phase 0c + 结算执行
THEN AI 红桃J 标记 invalidated → 跳过 Phase 1-6（SAPPHIRE 受保护）; 玩家方片7 正常执行 Phase 1-6（RUBY III 进入 Phase 6 摧毁检查）

**AC-E2: HAMMER + 倍率保留**
GIVEN 玩家 [方片7+HAMMER, 方片7] — PAIR 检测, multiplier=[2.0, 2.0]; AI pos 2 HAMMER 无效化玩家 pos 2
WHEN 结算执行
THEN 玩家 pos 2 (HAMMER 持有者) 跳过; 玩家 pos 1 (方片7) 以 M=2.0 正常结算

**AC-E3: 空手牌优雅退化**
GIVEN 玩家 0 张牌; AI 1 张: [方片5]; 双方未爆牌
WHEN 管道执行
THEN settlement_position_count=max(0,1)=1; pos 1 玩家跳过; AI 方片5 正常结算; 管道无错误

**AC-E4: 爆牌自伤 + 对手伤害叠加**
GIVEN 玩家 is_bust=true, point_total=22, HP=40; AI 未爆牌, 手牌: [方片7 (M=1.0)]
WHEN 管道执行
THEN apply_bust_damage(PLAYER, 22) → HP=18; AI 方片7: apply_damage(PLAYER, 7) → HP=11; 玩家承受自伤+攻击双重打击

**AC-E5: 爆牌方宝石保护**
GIVEN 玩家 is_bust=true; 手牌含 RUBY III, SAPPHIRE II
WHEN Phase 0b 执行
THEN Phase 1-6 全部跳过; 两张宝石质不触发摧毁检查; 品质完整保留

**AC-E6: 即时胜利方宝石保护**
GIVEN 玩家 has_instant_win=true, AI insurance_active=false; 玩家手牌含宝石质
WHEN Phase 0a 触发即时胜利
THEN 玩家卡牌不执行任何效果; 玩家宝石质跳过摧毁检查

**AC-E7: Phase 6 独立于 Phase 5 输出**
GIVEN 草花4 + RUBY III, 无印记, M=1.0（注意：RUBY+CLUBS 是非法配置，此处测试管道健壮性）
WHEN Phase 5 + Phase 6 执行
THEN Phase 5: suit_effect=(4+3)×1=7 但草花无战斗派发; Phase 6: 摧毁检查仍触发（is_gem=true）

### 管道集成

**AC-I1: 完整交替结算**
GIVEN 玩家 HP=100, AI HP=80; settlement_first_player=PLAYER; 玩家: [黑桃9(pos1), 红桃J(pos2), 方片7(pos3)]; AI: [方片Q(pos1), 方片5(pos2), 黑桃3(pos3)]; 无加成, 无倍率
WHEN 完整管道执行
THEN pos1: 玩家黑桃9→add_defense(9); AI方片Q→apply_damage(12), 防御吸收9→HP伤害3; pos2: 玩家红桃J→apply_heal(11), HP→100; AI方片5→apply_damage(5), HP→95; pos3: 玩家方片7→apply_damage(AI,7), AI HP→73; AI黑桃3→add_defense(AI,3); Phase 7a: 防御清零; Phase 7b: CONTINUE

**AC-I2: 爆牌 + 连续结算 + 死亡**
GIVEN 玩家 HP=20, AI HP=30; 玩家 is_bust=true, point_total=25; AI 未爆牌: [方片K, 方片7]
WHEN 完整管道执行
THEN Phase 0b: apply_bust_damage(PLAYER,25)→HP=0; AI方片K→HP仍0; AI方片7→HP仍0; Phase 7b: PLAYER_LOSE

**AC-I3: 即时胜利跳过全部**
GIVEN 玩家 has_instant_win=true, AI insurance_active=false; 玩家手牌含 RUBY III
WHEN 完整管道执行
THEN Phase 0a→PLAYER_INSTANT_WIN; Phase 0b-6 跳过; RUBY III 不触发摧毁检查; Phase 7b→PLAYER_WIN

**AC-I4: 双方爆牌**
GIVEN 玩家 HP=50, AI HP=60; 双方 is_bust=true; point_total 分别 24 和 26
WHEN 完整管道执行
THEN Phase 0b: HP 分别变 26 和 34; Phase 0c-6 跳过; Phase 7b: CONTINUE

## Open Questions

- [ ] 先手防御优势是否需要平衡补偿？（交替结算使先手方在每个位置享有防御时序优势。后手筹码补偿 50 是否足以平衡？）——需回合管理设计时确认，playtest 验证
- [x] ~~印记系统 GDD 中的 `final_card_value` 公式需正式标记为 deprecated 并替换为 `combat_effect` + `chip_output` 双轨模型——印记系统 GDD 更新时处理~~ 已完成 (2026-04-24)
- [ ] HAMMER + RUNNING_SHOES 组合是否过强？（跑鞋保证 HAMMER 在 pos 1 先手触发，同时自身花色效果最先执行）——需 playtest 验证，可能需要在印记系统中限制同一卡牌不能同时拥有两者
- [ ] 保险否定 SPADE_BLACKJACK 后玩家回退至 TWENTY_ONE (×2) 而非 BLACKJACK_TYPE (×4) 是否过于强力？（保险不仅阻止即时胜利，还使倍率从理论上可能的 ×4 降至 ×2，并暴露宝石质于摧毁风险）——需 playtest 验证
- [ ] 结算动画延迟 500ms 是否合适？需 UI 原型验证——新手可能需要更多时间理解逐层加成，老玩家可能觉得太慢
- [ ] 分牌后两手牌的结算交错方式？（当前 GDD 定义单手牌结算管道，分牌后两手牌如何交替/顺序执行待特殊玩法系统设计时确认）
