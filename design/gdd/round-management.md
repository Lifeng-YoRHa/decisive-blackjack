# 回合管理 (Turn Management)

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-04-24
> **Implements Pillar**: Core loop — 对战回合 → 结算 → 商店构筑 → 下一回合

## Overview

回合管理系统是《决胜21点》的单回合指挥调度器——它将发牌、特殊玩法判定（保险/分牌/双倍下注）、要牌停牌循环、卡牌排序、结算引擎调用、筹码经济事件触发、生死判定、以及商店/下一对手跳转，统一编排为一个确定性的 8 阶段回合流程。系统维护回合级状态：先后手轮换、当前回合数、当前对手序号、牌堆管理（抽牌/弃牌），并通过回合结果（CONTINUE/PLAYER_WIN/PLAYER_LOSE）驱动对局进度系统的宏观循环。

在数据层面，回合管理是唯一同时与结算引擎（调用管道）、战斗状态系统（HP/防御初始化）、特殊玩法系统（触发条件检查）、筹码经济系统（回合开始/击败对手事件）和 AI 对手系统（决策调度）交互的上层系统——每个子系统只关心自己的计算规则，回合管理决定它们在什么顺序、什么条件下被激活。在玩家体验层面，回合管理不直接可见——玩家感受到的是每个回合的节奏和张力，但这些体验的全部戏剧节奏都由本系统的阶段切换驱动。

## Player Fantasy

回合管理的玩家幻想是间接的——**赌局的心跳**。玩家从不直接与本系统交互，但每个回合的情感弧线完全由本系统的阶段切换驱动：发牌是心跳加速（不确定性涌入），保险/分牌/双倍下注窗口是屏息的瞬间（资源押上去还是不押），要牌停牌循环是心跳最剧烈的阶段（每一张牌都可能爆牌或封神），排序是短暂的停顿（命运交出指挥棒，你来编排），结算是心跳释放（看着计划一步步兑现），生死判定是心跳重置——长舒一口气或一切归零。

这个幻想承接了卡牌排序系统的"赌桌操盘手"和结算引擎的"连锁裁决"——排序说"命运到此为此，接下来由我决定"，结算说"我决定的后果正在一步步展开"，而回合管理说"从不确定性到确定性、从被动到主动、从紧张到释放的整条弧线，由我编排"。它让单局 21 点的自然戏剧性变成可重复、可预期、可上瘾的情感节拍。每一次"再来一轮"的冲动，都来自这个心跳循环的精确编排。

## Detailed Design

### Core Rules

**1. 系统性质**

回合管理系统是一个确定性回合流程调度器。它维护回合级状态（先手方、回合计数器、对手序号），编排 8 个阶段的顺序执行，并通过 `round_result` 驱动对局级别的循环。系统不持有跨回合的可变战斗状态（HP/防御由战斗状态系统管理）。

**2. 牌组生命周期**

- 玩家和 AI 各持有独立的 52 张牌组，互不影响。
- 每个新对手开始时：双方牌组洗入各自的抽牌堆，弃牌堆清空。AI 牌组重新生成（新印记、新卡质），玩家牌组保留所有属性（印记、卡质），仅洗牌。
- 回合内发牌从抽牌堆抽取。回合结算后（Phase 7a/7b 完成后），所有发出的牌进入各自拥有者的弃牌堆。
- 抽牌堆耗尽时：弃牌堆洗入抽牌堆，当前发牌操作继续。52 张牌不变量保证牌组永不为空。
- 被摧毁的卡牌（宝石质被移除）保留在牌组中（quality=null），牌组始终 52 张。

**3. 回合阶段**

每个回合按以下 8 阶段执行：

```
Phase 1: 发牌 (DEAL)        — 抽牌堆各发 2 张
Phase 2: 边池 (SIDE_POOL)    — 含 4 个子阶段（#9 定义）：下注子阶段 2a(7边池下注)/2b(赛场战争下注) 实际在 Phase 1 发牌前执行，结算子阶段 2c(7边池结算)/2d(赛场战争结算) 在 Phase 1 发牌后执行。MVP 跳过。（Alpha 阶段）
Phase 3: 保险 (INSURANCE)    — 对手明牌=Ace 时提供
Phase 4: 分牌检查 (SPLIT)    — 起始两张 rank 相同时提供
Phase 5: 要牌/停牌 (HIT_STAND) — 先手方完整行动，后手方完整行动
Phase 6: 排序 (SORT)         — 玩家排序，AI 自动排序
Phase 7: 结算 (RESOLUTION)   — 调用结算引擎管道
Phase 8: 生死判定 (DEATH_CHECK) — CONTINUE / PLAYER_WIN / PLAYER_LOSE
```

**4. 先手轮换（发牌/要牌阶段）**

- `first_player` 每回合交替。回合 N 的先手方与回合 N-1 相反。
- 初始先手方由硬币翻转决定（随机）。
- 先手方决定：发牌顺序、要牌/停牌顺序。
- 分牌时，两手牌使用相同的 `first_player`，不交替。
- `first_player` **不影响**结算顺序——结算交替顺序由 Rule 4b 的 `settlement_first_player` 决定。

**4b. 结算先手方判定 (settlement_first_player)**

排序完成后、结算开始前，根据双方最终手牌点数判定结算先手方：

1. 比较双方 `point_total`（来自点数计算引擎）：点数较大一方为结算先手方
2. 若 `point_total` 相同：比较双方手牌中最大单卡的 21 点值（A=11, 2-10=面值, J/Q/K=10），拥有较大最大卡牌的一方为结算先手方
3. 若最大卡牌 21 点值仍相同：抛硬币随机决定，后手方获得 20 筹码补偿

结算先手方仅影响 Phase 7 (结算) 的交替顺序。分牌时，每手牌独立判定 `settlement_first_player`。爆牌不改变判定规则——双方爆牌时仍按 `point_total` 高低决定结算先手。

**5. 发牌阶段 (DEAL)**

从双方抽牌堆各发 2 张。发牌顺序：先手方第 1 张 → 后手方第 1 张 → 先手方第 2 张 → 后手方第 2 张。每方发出的第一张牌为"明牌"，对手可见。

**6. 要牌/停牌阶段 (HIT_STAND)**

按先后手顺序依次执行：
1. 先手方进入要牌/停牌循环（玩家：点击按钮；AI：调用决策函数）。先手方可以要牌、停牌或双倍下注（若条件满足）。
2. 先手方停牌后，后手方进入要牌/停牌循环。
3. 先手方不能看到后手方的要牌/停牌结果。

**7. 分牌子流程 (SPLIT)**

当分牌触发时（玩家和/或 AI），执行顺序子管道：

```
[双方手牌 A]
  玩家手牌 A: 要牌/停牌 → 牌型选择 → 排序
  AI 手牌 A:   要牌/停牌 → 牌型选择 → 排序
  手牌 A 结算 (Phase 0a-6, skip Phase 7a)
  → 玩家 HP=0? → 终止，手牌 B 不结算，宝石受保护

[双方手牌 B]（仅当手牌 A 后玩家存活）
  玩家手牌 B: 要牌/停牌 → 牌型选择 → 排序
  AI 手牌 B:   要牌/停牌 → 牌型选择 → 排序
  手牌 B 结算 (Phase 0a-7a)
  → Phase 7b 生死判定
```

AI 防御在手牌 A 和手牌 B 之间保持累积。Phase 7a（防御清零）延迟到手牌 B 完成后执行。

**8. 对手转换**

当生死判定返回 `PLAYER_WIN` 时，回合管理发出转换信号给对局进度系统。对局进度系统拥有 `opponent_number` 的唯一管理权，协调以下转换序列：
1. 对局进度系统：`opponent_number` += 1
2. 筹码经济：`on_opponent_defeated(N)` → 胜利奖励注入
3. 进入商店阶段（独立系统，对局进度编排时序）
4. 商店完成后，对局进度系统通知回合管理开始新对手：
   - AI 牌组重新生成（新实例，新印记，新卡质）
   - 玩家牌组洗牌（保留属性，洗入抽牌堆）
   - 战斗状态：AI HP = `ai_hp_scaling(opponent_number)`
   - 玩家 HP 不重置（跨对手累积伤害，商店治疗是唯一恢复手段）
   - 回合计数器重置为 1，先手方重新硬币翻转

**9. 游戏结束条件**

胜负结果由对局进度系统最终判定：
- 对局进度系统判定击败对手 8（`opponent_number == total_opponents AND round_result == PLAYER_WIN`）→ 游戏胜利 (VICTORY)。
- 玩家在任何时候 HP=0 → 对局进度系统判定游戏结束 (GAME_OVER)。

本系统提供 `round_result`，对局进度系统据此决定 VICTORY / GAME_OVER。

**10. 游戏初始化**

新游戏开始时（由对局进度系统协调初始化序列）：
1. 对局进度系统：`match_state=NEW_GAME`, `opponent_number=1`, `total_opponents=8`
2. 卡牌数据模型：创建 104 个实例（52 玩家 + 52 AI）
3. AI 对手系统：为对手 1 生成 AI 牌组
4. 战斗状态：玩家 HP=100，AI HP=`ai_hp_scaling(1)`=80
5. 筹码经济：`reset_for_new_game()`，余额=100
6. 回合管理：`round_counter`=1（`opponent_number` 由对局进度系统设置）
7. 先手方 = 硬币翻转
8. 双方牌组洗入抽牌堆

### States and Transitions

```
IDLE ──(回合开始)──→ DEALING
SIDE_POOL_BET (MVP: 跳过) ──→ DEALING ──(发牌完成)──→ SIDE_POOL_SETTLE (MVP: 跳过) ──→ INSURANCE
INSURANCE ──(对手明牌≠Ace或跳过)──→ SPLIT_CHECK
SPLIT_CHECK ──(起始对子或跳过)──→ HIT_STAND
HIT_STAND ──(双方停牌)──→ SORTING
SORTING ──(排序确认)──→ RESOLUTION
RESOLUTION ──(管道完成)──→ DEATH_CHECK
DEATH_CHECK ──(CONTINUE)──→ IDLE
DEATH_CHECK ──(PLAYER_WIN)──→ OPPONENT_WIN → 商店 → DEALING (新对手)
DEATH_CHECK ──(PLAYER_LOSE)──→ GAME_OVER
```

分牌分支：`SPLIT_CHECK` 进入分牌子流程（手牌 A 完整管道 → 手牌 B 完整管道），完成后回到 `DEATH_CHECK`。

### Interactions with Other Systems

| 系统 | 方向 | 接口 | 触发时机 |
|------|------|------|---------|
| 卡牌数据模型 (#1) | 双向 | 读取牌堆/弃牌堆状态；发牌时将牌移入/移出手牌 | DEAL, HIT_STAND |
| 点数计算引擎 (#2) | 入 | 要牌后调用 `calculate_points()` 或 `simulate_hit()` | HIT_STAND |
| 牌型检测系统 (#3) | 入 | 调用 `detect_hand_types()`，传递结果给排序和结算 | SORT → RESOLUTION |
| 卡牌排序系统 (#6a) | 出 | 调用排序函数，传入手牌和先手信息 | SORT |
| 结算引擎 (#6) | 出 | 调用 `run_pipeline(sorted_hands, point_results, multipliers, combat_state, settlement_first_player, insurance_flags)`；分牌时传 `skip_defense_reset` | RESOLUTION |
| 战斗状态系统 (#7) | 双向 | 回合开始：`reset_defense()`；生死判定：`get_round_result()`；对手转换：初始化 AI HP | DEAL, DEATH_CHECK, 对手转换 |
| 特殊玩法系统 (#8) | 双向 | 检查保险/分牌/双倍下注条件；执行特殊玩法逻辑 | INSURANCE, SPLIT_CHECK, HIT_STAND |
| 边池系统 (#9) | 出 | MVP 跳过；预留接口：`place_bet()`, `resolve_pool()` | SIDE_POOL |
| 筹码经济系统 (#10) | 双向 | `on_opponent_defeated(N)` → 胜利奖励 | DEATH_CHECK |
| AI 对手系统 (#12) | 出 | 调用 AI 决策函数获取行动指令（HIT/STAND/DD/保险/分牌/牌型选择/排序策略） | INSURANCE, SPLIT_CHECK, HIT_STAND, SORT |
| 对局进度系统 (#14) | 出 | 发出 `round_result` 事件 (result, opponent_number, round_number, player_hp, ai_hp) | DEATH_CHECK |
| 牌桌 UI (#15) | 出 | 发出阶段切换事件、当前阶段状态、牌堆/手牌渲染数据 | 所有阶段 |

## Formulas

### 1. 先手方确定 (first_player_determination)

```
first_player(round_counter, initial_coin_flip):
  IF round_counter == 1:
    return initial_coin_flip  (PLAYER or AI, 随机)
  ELSE:
    return opposite(round_N-1.first_player)
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| round_counter | R | int | 1+ | 当前对手内的回合编号 |
| initial_coin_flip | C | enum | {PLAYER, AI} | 每个对手开始时的随机先手方 |

**Output:** PLAYER 或 AI。每个对手开始时重新硬币翻转。

### 1b. 结算先手方判定 (settlement_first_player_determination)

```
settlement_first_player(player_points, ai_points, player_hand, ai_hand):
  IF player_points > ai_points:
    return PLAYER
  ELIF ai_points > player_points:
    return AI
  ELSE:
    player_max = max(card.blackjack_value for card in player_hand)
    ai_max = max(card.blackjack_value for card in ai_hand)
    IF player_max > ai_max:
      return PLAYER
    ELIF ai_max > player_max:
      return AI
    ELSE:
      result = coin_flip()  // 50/50 随机
      add_chips(opposite(result), 20, SETTLEMENT_TIE_COMP)
      return result
```

`blackjack_value` 定义：A=11, 2-10=面值, J/Q/K=10。分牌时每手牌独立调用此函数。

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| player_points | P_p | int | 2 ~ 31 | 玩家手牌点数（来自点数计算引擎） |
| ai_points | A_p | int | 2 ~ 31 | AI 手牌点数 |
| player_max_card | M_p | int | 2 ~ 11 | 玩家手牌中最大单卡 blackjack_value |
| ai_max_card | M_a | int | 2 ~ 11 | AI 手牌中最大单卡 blackjack_value |

**Output:** PLAYER 或 AI。每手牌独立判定，不跨回合轮换。
**Example:** 玩家 point_total=18, AI point_total=18（平局），玩家最大卡=K(blackjack_value=10), AI 最大卡=A(blackjack_value=11) → AI 最大卡更高 → settlement_first_player=AI。

### 2. 后手判定 (is_second_player)

```
is_second_player = (first_player ≠ PLAYER)
```

当 `first_player = AI` 时，玩家是后手。每回合判定一次，不因分牌重复。发牌后手无经济补偿——先手的防御时序优势不通过筹码平衡。

### 3. 游戏胜利条件 (victory_condition)

```
victory = (opponent_number == total_opponents AND round_result == PLAYER_WIN)
```

击败最后一个对手即游戏胜利。`opponent_number` 由对局进度系统提供（只读），范围 [1, `total_opponents`]。

## Edge Cases

- **如果在分牌手牌 A 结算期间 AI HP 降至 0**：立即返回 `PLAYER_WIN`，手牌 B 不执行。玩家手牌 B 的宝石卡牌受保护（不执行 Phase 6 摧毁检查）。SP-9 仅覆盖玩家死亡；AI 死亡是对手层面的胜利，无需继续无意义的子流程。
- **如果仅一方分牌而另一方不分牌**（例如 AI 分牌，玩家不分牌）：玩家的单一手牌参与两次结算——先与 AI 手牌 A 结算，再与 AI 手牌 B 结算。玩家的要牌/停牌决定仅执行一次（在手牌 A 子流程中），手牌状态在手牌 B 中复用。玩家不获得额外的要牌/停牌机会。
- **如果双方均分牌**：双方在 SPLIT_CHECK 阶段各自拆分起始手牌。执行流程不受影响——"cross-player A-first"管道已经定义为按手牌、交叉玩家的顺序，双方分牌不产生额外的排序冲突。
- **如果分牌手牌 A 中双方均爆牌**：双方各自承受爆牌自伤（作用于玩家的共享 HP 池和 AI 的 HP）。Phase 7a（防御清零）延迟到手牌 B 完成后。若双方均存活，手牌 B 正常进行。若玩家 HP=0，SP-9 生效，手牌 B 跳过。
- **如果在第 8 个对手中双方同时死亡**（HP 均降至 0）：结果为 `PLAYER_LOSE`。胜利条件要求 `round_result = PLAYER_WIN`，同时死亡产生 `PLAYER_LOSE`（战斗状态系统规则 9）。玩家必须在最终战中存活。
- **如果发牌阶段抽牌堆耗尽**：弃牌堆洗入抽牌堆，发牌继续。52 张牌不变量保证牌组足够发牌（4 张）和分牌补牌（2 张）。
- **如果分牌时抽牌堆耗尽**：弃牌堆洗入抽牌堆，补牌继续。52 张不变量保证。
- **如果玩家以 HP 支付保险（6 HP）后 HP 极低，且分牌条件满足**：分牌仍可触发。保险 HP 支付在分牌检查之前执行（Phase 3 先于 Phase 4）。低 HP 分牌是有意的高风险策略，UI 可选显示风险提示。
- **如果硬币翻转使玩家在第一个对手的第一个回合即为后手**：玩家以 100 筹码开始，先手拥有防御时序优势但无经济补偿。先手优势需要通过构建经济引擎来克服。
- **如果玩家在击败对手后以 1 HP 进入商店**：这是有效且危险的游戏状态。商店提供治疗（商店系统依赖）。若玩家无法负担治疗，以 1 HP 进入下一个对手，必须依赖红桃回复存活。不存在强制治疗或怜悯机制。
- **如果 first_player（发牌先手）与 settlement_first_player（结算先手）不同**：这是正常情况。发牌先手由轮换决定，结算先手由点数决定。例如：玩家发牌先手（先要牌/停牌），但最终点数低于 AI → AI 结算先手。两个先手概念完全独立。
- **如果分牌两手牌的 settlement_first_player 不同**：每手牌独立判定。手牌 A 可能玩家先结算（玩家 18 > AI 16），手牌 B 可能 AI 先结算（AI 20 > 玩家 15）。

## Dependencies

**上游依赖（本系统依赖）：**

| 系统 | 依赖类型 | 接口 | GDD 状态 |
|------|---------|------|---------|
| 卡牌数据模型 (#1) | 硬 | 读取牌堆/弃牌堆状态；发牌时将牌移入/移出手牌；52 张牌不变量 | 已完成 |
| 点数计算引擎 (#2) | 硬 | 要牌后调用 `calculate_points()` / `simulate_hit()` | 已完成 |
| 牌型检测系统 (#3) | 硬 | 调用 `detect_hand_types()`，传递结果给排序和结算 | 已完成 |
| 卡牌排序系统 (#6a) | 硬 | 调用排序函数，传入手牌和先手信息 | 已完成 |
| 结算引擎 (#6) | 硬 | 调用 `run_pipeline()`，传入手牌/点数/倍率/战斗状态/settlement_first_player/保险标志；分牌时传 `skip_defense_reset` | 已完成 |
| 战斗状态系统 (#7) | 硬 | 回合开始：`reset_defense()`；生死判定：`get_round_result()`；对手转换：初始化 AI HP | 已完成 |
| 特殊玩法系统 (#8) | 硬 | 检查保险/分牌/双倍下注条件；执行特殊玩法逻辑 | 已完成 |
| 边池系统 (#9) | 软 | MVP 跳过；预留接口：`place_bet()`, `resolve_pool()` | 未设计 |
| 筹码经济系统 (#10) | 硬 | `settlement_first_player` 平局时 → 硬币翻转补偿(20)；`on_opponent_defeated(N)` → 胜利奖励 | 已完成 |
| AI 对手系统 (#12) | 硬 | 调用 AI 决策函数获取行动指令（HIT/STAND/DD/保险/分牌/牌型选择/排序策略） | 已完成 |

**下游依赖（被依赖）：**

| 系统 | 依赖类型 | 接口 | GDD 状态 |
|------|---------|------|---------|
| 对局进度系统 (#14) | 硬 | 消费 `round_result` 事件 (result, opponent_number, round_number, player_hp, ai_hp) | 未设计 |
| 牌桌 UI (#15) | 硬 | 消费阶段切换事件、当前阶段状态、牌堆/手牌渲染数据 | 未设计 |

**双向依赖验证：**

| 系统 | 本文档列出 | 对方文档是否列出本系统 | 状态 |
|------|-----------|---------------------|------|
| 结算引擎 | 上游硬依赖 | ✓ 下游（消费 settlement_first_player, 启动信号） | 一致 |
| 战斗状态系统 | 上游硬依赖 | ✓ 下游（消费 reset_defense, HP 初始化） | 一致 |
| 特殊玩法系统 | 上游硬依赖 | ✓ 间接（特殊玩法消费回合阶段的触发时机） | 一致 |
| 筹码经济系统 | 上游硬依赖 | ✓ 下游（消费 on_round_start, on_opponent_defeated） | 一致 |
| AI 对手系统 | 上游硬依赖 | ✓ 下游（AI 是被动策略层，被回合管理调用） | 一致 |
| 对局进度系统 | 下游 | 未设计（待验证） | 待确认 |
| 牌桌 UI | 下游 | 未设计（待验证） | 待确认 |

## Tuning Knobs

| 调参点 | 类型 | 默认值 | 安全范围 | 影响什么 |
|--------|------|--------|----------|---------|
| `initial_coin_flip_seed` | int | -1 | -1 ~ MAX_INT | 先手硬币翻转 RNG 种子。-1 = 每局随机（生产环境），其他值 = 固定种子（测试/replay） |
| `shop_enabled` | bool | true | — | 对手之间是否进入商店。false = 跳过商店（测试/debug 模式） |
| `split_defense_reset_delay` | bool | true | — | 分牌时是否延迟防御清零到手牌 B 之后。false = 每手牌后清零（测试变体） |
| `settlement_tie_compensation` | int | 20 | 0 ~ 100 | 结算先手方硬币翻转时后手方获得的筹码补偿 |

**依赖系统的调参点（本系统消费但不拥有）：**

| 调参点 | 来源 | 本系统如何消费 |
|--------|------|--------------|
| `total_opponents` | 对局进度系统 | 对手总数（默认 8）。本系统不拥有此值，从对局进度系统只读获取 |
| `opponent_number` | 对局进度系统 | 当前对手序号。本系统不拥有此值，从对局进度系统只读获取 |
| `deck_size` | 卡牌数据模型 | 牌组洗牌和发牌逻辑（默认 52） |
| `ai_hp_scaling` | 战斗状态系统 | 对手转换时初始化 AI HP（查找表 [80-300]） |
| `player_max_hp` | 战斗状态系统 | 游戏初始化时设置玩家 HP（默认 100） |
| `initial_chips` | 筹码经济系统 | 游戏初始化时设置起始筹码（默认 100） |
| `victory_base` / `victory_scale` | 筹码经济系统 | 击败对手时胜利奖励（默认 50 + 25×n） |
| `sort_timer_seconds` | 卡牌排序系统 | 排序阶段倒计时（默认 30 秒） |
| `ui_hand_display_limit` | 卡牌排序系统 | 最大手牌数（默认 11） |

## Acceptance Criteria

**AC-01: 正常回合流程**
GIVEN opponent 1, round 1, first_player=PLAYER
WHEN 回合完成，双方未爆牌，HP>0
THEN round_result=CONTINUE, round_counter 递增为 2, first_player 翻转为 AI

**AC-02: 玩家击败对手**
GIVEN 玩家未爆牌, AI 未爆牌, 玩家 HP>0, AI HP 在结算中降至 0
WHEN 生死判定执行
THEN round_result=PLAYER_WIN, on_opponent_defeated(N) 调用后胜利奖励注入, 商店阶段触发

**AC-03: 玩家死亡**
GIVEN 结算将玩家 HP 降至 0, AI HP>0
WHEN 生死判定执行
THEN round_result=PLAYER_LOSE, 游戏结束触发

**AC-04: 先手轮换**
GIVEN 回合 N 的 first_player=PLAYER, round_result=CONTINUE
WHEN 回合 N+1 开始
THEN first_player=AI

**AC-05: 结算先手方 — 点数决定**
GIVEN 玩家 point_total=19, AI point_total=16
WHEN 排序完成，结算开始前判定 settlement_first_player
THEN settlement_first_player=PLAYER（19 > 16）

**AC-05c: 结算先手方 — 硬币翻转 + 补偿**
GIVEN 玩家 point_total=18, AI point_total=18, 玩家最大卡=K(10), AI 最大卡=A(11)
WHEN settlement_first_player 判定
THEN settlement_first_player=AI（最大卡 A(11) > K(10)）

**AC-05d: 结算先手方 — 爆牌不改变规则**
GIVEN 玩家 point_total=20, AI point_total=20, 双方最大卡均为 K(10)
WHEN settlement_first_player 判定
THEN 抛硬币决定 settlement_first_player，后手方获得 20 筹码补偿（SETTLEMENT_TIE_COMP）

**AC-05e: 结算先手方 — 爆牌不改变规则**
GIVEN 玩家 point_total=24（爆牌）, AI point_total=26（爆牌）
WHEN settlement_first_player 判定
THEN settlement_first_player=AI（26 > 24，点数比较不考虑爆牌状态）

**AC-06: 分牌流程**
GIVEN 玩家起始手牌 [7♥, 7♦], AI 不分牌
WHEN 分牌触发
THEN 手牌 A 子流程完成（玩家要牌/停牌→排序→结算, skip_defense_reset=true）, 然后手牌 B 子流程完成（skip_defense_reset=false）

**AC-07: 分牌手牌 A 玩家死亡**
GIVEN 分牌触发, 手牌 A 结算将玩家 HP 降至 0
WHEN 手牌 A 管道完成
THEN 手牌 B 不执行, 玩家手牌 B 宝石卡牌受保护, round_result=PLAYER_LOSE

**AC-08: 分牌手牌 A AI 死亡**
GIVEN 双方均分牌, 手牌 A 结算将 AI HP 降至 0
WHEN 手牌 A 管道完成
THEN round_result=PLAYER_WIN, 手牌 B 不执行

**AC-09: 单方分牌**
GIVEN AI 分牌（两张 8）, 玩家不分牌（手牌 [K♥, 5♦]）
WHEN 分牌子流程执行
THEN 玩家单一手牌先与 AI 手牌 A 结算（玩家排序状态复用，不再要牌/停牌）, 再与 AI 手牌 B 结算

**AC-10: 对手转换**
GIVEN 对手 3 被击败（round_result=PLAYER_WIN）, 玩家 HP=45
WHEN 对局进度系统完成转换，商店完成
THEN opponent_number=4（由对局进度系统设置）, AI 牌组全新生成（新实例/印记/卡质）, 玩家牌组洗牌（同一批实例，属性保留）, AI HP=150 (ai_hp_scaling(4)), 玩家 HP=45（不变）, round_counter=1, 新硬币翻转

**AC-11: 游戏胜利**
GIVEN 对局进度系统记录 opponent_number=8, round_result=PLAYER_WIN
WHEN 对局进度系统执行胜负判定
THEN 游戏以 VICTORY 结束（由对局进度系统判定）

**AC-12: 最终战同时死亡**
GIVEN opponent_number=8, 结算将双方 HP 均降至 0
WHEN 生死判定执行
THEN round_result=PLAYER_LOSE（非 VICTORY）。玩家必须在最终战存活

**AC-13: 牌组洗牌**
GIVEN 玩家抽牌堆剩余 3 张, 本回合需发 4 张
WHEN DEAL 阶段执行
THEN 弃牌堆洗入抽牌堆, 发牌继续。draw_pile + discard_pile + hand = 52（每方）

**AC-14: 保险后分牌**
GIVEN 对手明牌=Ace, 玩家 HP=8, 购买保险（HP 支付: -6 → HP=2）, 起始手牌为一对 7
WHEN Phase 3-4 依次执行
THEN 保险先结算（Phase 3）, 分牌随后提供（Phase 4）, 低 HP 分牌可用

**AC-15: 游戏初始化**
GIVEN 新游戏开始
WHEN 初始化完成
THEN 玩家 HP=100, AI HP=80 (opponent 1), 筹码余额=100, 双方牌组洗好（各 52 张）, opponent_number=1（由对局进度系统设置）, round_counter=1, first_player=随机

**AC-16: 发牌顺序**
GIVEN first_player=PLAYER, 双方抽牌堆充足
WHEN Phase 1 (DEAL) 执行
THEN 发牌顺序：玩家第 1 张 → AI 第 1 张 → 玩家第 2 张 → AI 第 2 张。每方第一张为对手可见的明牌

**AC-17: 弃牌堆累积**
GIVEN 回合 1 完成, 发出 4 张牌（每方 2 张）, 无分牌
WHEN Phase 7 完成
THEN 玩家弃牌堆含 2 张, AI 弃牌堆含 2 张, 双方抽牌堆各减 2 张, 每方总牌数 = 52

**AC-18: 回合开始防御重置**
GIVEN 上回合结束时玩家 defense=12, AI defense=5
WHEN 新回合 DEAL 阶段开始
THEN reset_defense() 调用, 双方 defense=0

**AC-19: 双方均分牌**
GIVEN 玩家起始手牌 [7, 7], AI 起始手牌 [8, 8], 双方均触发分牌
WHEN 分牌子流程执行
THEN cross-player A-first: [玩家手牌 A 要牌/停牌 → AI 手牌 A 要牌/停牌 → 排序 → 手牌 A 结算] → [玩家手牌 B 要牌/停牌 → AI 手牌 B 要牌/停牌 → 排序 → 手牌 B 结算]。双方各为每只分牌手补 1 张牌

**AC-20: 分牌手牌 A 双方爆牌**
GIVEN 分牌触发, 手牌 A 双方爆牌（玩家 point_total=24, AI point_total=26）, 玩家 HP=60, AI HP=80
WHEN 手牌 A 结算
THEN 玩家 HP=36 (60-24), AI HP=54 (80-26), Phase 7a 延迟。双方 HP>0 → 手牌 B 正常执行

**AC-21: 双倍下注集成**
GIVEN 玩家 2 张牌（point_total=11）, 未分牌
WHEN 玩家在 HIT_STAND 阶段选择双倍下注
THEN 玩家恰好抽 1 张牌, 强制停牌, doubledown_active=true 传入结算引擎 Phase 1

**AC-22: 胜利奖励先于商店**
GIVEN 对手被击败（PLAYER_WIN）
WHEN 对手转换序列执行
THEN on_opponent_defeated(N) 调用且筹码余额更新完成 BEFORE 商店 UI 加载。商店可立即查询更新后余额

**AC-23: 被摧毁卡牌仍在牌组**
GIVEN 玩家有 1 张卡牌 quality=null（上回合 RUBY III 被摧毁）
WHEN 新回合 DEAL 阶段抽到该卡
THEN quality=null 卡牌正常发牌, 参与点数计算时 gem_quality_bonus=0, 无崩溃

**AC-24: 回合初始化时序**
GIVEN 回合即将开始
WHEN 回合初始化执行
THEN 防御重置（reset_defense）在 Phase 1 (DEAL) 之前完成。先手方交替完成。无筹码补偿事件。

## Open Questions

1. **边池系统 (#9) 的接口合同何时确定？** — MVP 跳过 SIDE_POOL 阶段，但预留了 `place_bet()` / `resolve_pool()` 接口。当边池系统设计时，需确认这些接口是否满足需求，以及边池阶段是否插入在 DEAL 之后、INSURANCE 之前。负责人：game designer，目标：Alpha 阶段。

2. **对局进度系统 (#14) 消费 round_result 事件的格式？** — 本系统定义了事件字段 (result, opponent_number, round_number, player_hp, ai_hp)，但 #14 未设计。当设计时需确认是否需要额外字段（如 chip_balance, deck_size_remaining）。负责人：game designer，目标：Alpha 阶段。

3. **商店阶段的回退机制？** — 如果商店阶段崩溃或玩家意外退出，回合管理需要知道如何恢复。当前设计假设商店是原子操作——进入商店，完成购买，返回。是否需要检查点？负责人：technical director，目标：架构阶段。

4. **玩家 HP 跨对手不重置的平衡验证？** — 对手 4 的 AI HP=150（玩家 100 的 1.5 倍），对手 8 为 300（3 倍）。如果玩家以 30 HP 进入对手 5，是否在数学上可解？需要 playtest 验证商店治疗的性价比是否足够支撑全程存活。负责人：game designer，目标：playtest 阶段。

5. **`total_opponents` 旋钮是否应影响 ai_hp_scaling 表？** — 当前 ai_hp_scaling 表固定 8 条目。如果 `total_opponents` 调为 5，AI HP 曲线应截取前 5 条还是重新分布？负责人：game designer，目标：Alpha 阶段平衡调优。
