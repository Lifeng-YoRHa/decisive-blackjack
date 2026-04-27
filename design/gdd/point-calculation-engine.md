# Point Calculation Engine (点数计算引擎)

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-24
> **Implements Pillar**: Core — 21-point hand value calculation and bust detection

## Overview

点数计算引擎是《决胜21点》的手牌点数计算核心。它接收一组卡牌实例，按照 21 点规则计算手牌总点数（A 可选 1 或 11，2-10 按面值，J-K 按 10），自动选择最优的 A 取值组合使总点数尽可能接近 21 但不超出，并判断手牌是否爆牌（>21）。作为 Core 层系统，它为结算引擎提供 `point_total`（爆牌自伤值）、为牌型检测系统提供精确点数（判定"21"、"杰克"、"黑杰克"等牌型）、为 AI 对手系统提供期望点数（辅助决策是否继续要牌）。没有这个系统，游戏无法判断一手牌的点数，也无法区分"21 点完美手"和"23 点爆牌"。

## Player Fantasy

**悬崖边的数字 — 一点之差，两种命运**

每次抽牌，点数在脑中翻滚 — A 是 1 还是 11？当前 19，再来一张会是完美的 21 还是致命的 26？点数计算引擎赋予了这个瞬间以重量。同一手牌，同一个数字，却决定了两条截然不同的命运：恰好 21，牌型倍率全开，一切放大；超过 21，花色效果归零，按点数自伤，从"神之一手"翻转为"万劫不复"。玩家构筑牌组、选择要牌或停牌、编排卡牌顺序时，本质上都在和这个数字博弈 — 让它在 21 这边多停留一秒，就是对命运的嘲弄；让它越过那条线哪怕一点，代价就是生命值。玩家不会"看到"点数计算引擎，但每一次"要牌"按钮按下后的心跳加速，每一次恰好落在 21 的狂喜，都是它在幕后裁决的结果。

## Detailed Design

### Core Rules

**1. 系统性质**

点数计算引擎是一个无状态纯函数系统。它不持有任何可变状态，没有生命周期，没有初始化/销毁。给定相同的卡牌输入，始终返回相同的结果。

**2. 点数值映射**

每张卡牌对点数总和的贡献值由 Card Data Model 的 `bj_values` 字段决定：

| rank | bj_values | 说明 |
|------|-----------|------|
| A | [1, 11] | 动态取值，由解析算法决定 |
| 2-10 | [面值] | 固定贡献 |
| J, Q, K | [10] | 固定贡献 10 |

**3. A 解析算法**

手牌中所有 A 的取值通过贪心算法确定：

```
1. 将所有非 A 牌的 bj_values[0] 累加到 total
2. 统计 A 的数量 → ace_count
3. 每张 A 先按 11 计入 total
4. 当 total > BUST_THRESHOLD 且仍有 A 按 11 计算时：
     total -= 10（将一张 A 从 11 降为 1）
     soft_ace_count -= 1
5. 返回最终的 total 和 soft_ace_count
```

此算法保证：如果能通过 A 的取值组合使 total ≤ 21，则返回最大的可能值；如果无法避免爆牌，则返回最小的可能值。

**4. 爆牌判定**

`is_bust = (point_total > BUST_THRESHOLD)`

BUST_THRESHOLD = 21（常量，非调参数）。

**5. 输出结构**

```
PointResult:
  point_total: int       # 解析后的 21 点总和
  is_bust: bool          # point_total > 21
  ace_count: int         # 手牌中 A 的总数
  soft_ace_count: int    # 仍按 11 计算的 A 数量（爆牌时 = 0）
  card_count: int        # 手牌中的卡牌总数
```

**6. 公共 API**

| 方法 | 签名 | 说明 |
|------|------|------|
| `calculate_hand` | `(cards: Array[CardInstance]) -> PointResult` | 主函数：给定手牌，计算点数结果 |
| `simulate_hit` | `(current: PointResult, new_card: CardInstance) -> PointResult` | 增量计算：在当前结果上追加一张牌，O(1) 而非重新遍历整手牌 |

**7. 边界定义**

- 本系统**只负责** 21 点算术运算（点数求和、A 解析、爆牌判定）。
- 本系统**不负责**：花色效果计算、牌型分类、筹码计算、概率估计。
- AI 对手系统使用 `simulate_hit` 配合牌组知识来估算爆牌概率 — 概率计算不属于本系统。

### States and Transitions

无状态机。本系统是纯函数层，不驱动游戏流程，不持有可变状态。

### Interactions with Other Systems

| 系统 | 方向 | 数据流 | 触发时机 |
|------|------|--------|---------|
| 卡牌数据模型 | 入 | 读取 `bj_values`, `suit`, `rank` | 每次计算 |
| 结算引擎 | 出 | `point_total`, `is_bust` | 结算前爆牌检测阶段 |
| 牌型检测系统 | 出 | `point_total`, `ace_count`, `card_count` | 手牌确定后、牌型分类前 |
| AI 对手系统 | 出 | `PointResult` 结构体 + `simulate_hit` 函数 | AI 决策要牌/停牌时 |
| 战斗状态系统 | 间接出 | `point_total` 经结算引擎传递至 `apply_bust_damage` | 爆牌检测阶段 |

本系统**不与**以下系统直接交互：花色效果、印记系统、卡质系统、筹码经济、商店系统、牌桌 UI。

## Formulas

### 1. 手牌总点计算 (hand_point_total)

The `calculate_hand` formula is defined as:

```
non_ace_sum = SUM( card.prototype.bj_values[0] )  for all non-Ace cards
ace_count = COUNT( cards where bj_values == [1, 11] )
raw_sum = non_ace_sum + ace_count × 11

while raw_sum > BUST_THRESHOLD AND ace_count_as_11 > 0:
    raw_sum -= 10
    ace_count_as_11 -= 1

point_total = raw_sum
soft_ace_count = ace_count_as_11
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| cards | — | Array[CardInstance] | 0 ~ 52 | 输入手牌 |
| non_ace_sum | S | int | 0 ~ 70 | 所有非 A 牌的 bj_values[0] 之和（7 张牌 ×10 = 70） |
| ace_count | N_a | int | 0 ~ 4 | 手牌中 A 的数量 |
| BUST_THRESHOLD | B | int | 21（常量） | 爆牌阈值 |
| point_total | T | int | 2 ~ 31 | 解析后的最终手牌点数 |
| soft_ace_count | S_a | int | 0 ~ N_a | 仍按 11 计算的 A 数量 |

**Output Range:** point_total ∈ [2, ~31]（实际手牌上限 7 张，理论最大 4×10 + 3×11 = 73，但爆牌通常在 22-31 区间已触发惩罚）

**Example 1（软 18）**: Hand=[A♠, 7♥] → non_ace_sum=7, ace_count=1, raw_sum=18 → 18 ≤ 21，无需降级 → point_total=18, soft_ace_count=1

**Example 2（A 降级至 21）**: Hand=[A♥, A♠, 9♦] → non_ace_sum=9, ace_count=2, raw_sum=31 → 31 > 21，降级 1 次 → point_total=21, soft_ace_count=1

**Example 3（硬爆牌）**: Hand=[K♣, 7♦, 6♥] → non_ace_sum=23, ace_count=0 → point_total=23, is_bust=true

**Example 4（四张 A）**: Hand=[A♥, A♠, A♦, A♣] → non_ace_sum=0, ace_count=4, raw_sum=44 → 降级 3 次 → point_total=14, soft_ace_count=1

### 2. 增量计算 (simulate_hit)

The `simulate_hit` formula is defined as:

```
情况 A — 新牌非 A:
  point_total_new = current.point_total + card.prototype.bj_values[0]
  soft_ace_count_new = current.soft_ace_count

情况 B — 新牌为 A:
  point_total_new = current.point_total + 11
  ace_count_new = current.ace_count + 1
  soft_ace_count_new = current.soft_ace_count + 1

共有降级（两种情况）:
  while point_total_new > BUST_THRESHOLD AND soft_ace_count_new > 0:
      point_total_new -= 10
      soft_ace_count_new -= 1

共有推导:
  card_count_new = current.card_count + 1
  is_bust_new = (point_total_new > BUST_THRESHOLD)
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| current.point_total | T_old | int | 2 ~ 31 | 抽牌前手牌总点数 |
| current.soft_ace_count | S_old | int | 0 ~ 3 | 抽牌前软 A 数量 |
| current.card_count | C_old | int | 1 ~ 6 | 抽牌前手牌数 |
| new_card_value | V | int | 2 ~ 10 | 新牌的 bj_values[0]（非 A） |
| point_total_new | T_new | int | 3 ~ 41 | 更新后的手牌总点数 |
| is_bust_new | — | bool | — | 更新后的爆牌标志 |

**Output Range:** 与公式 1 相同

**Example 1（软手变硬手）**: current={total:18, soft:1, count:2} + 8♦ → new_total=26 → 降级：26>21, soft=1 → new_total=16, soft=0 → 未爆牌，但软 A 已耗尽

**Example 2（硬手爆牌）**: current={total:18, soft:0, count:3} + K♣ → new_total=28 → 无法降级（soft=0） → is_bust=true

**Example 3（加 A 恰好 21）**: current={total:10, soft:0, count:1} + A♠ → new_total=21, soft=1 → 无需降级 → 完美 21

### 3. 爆牌判定 (is_bust)

The `is_bust` formula is defined as:

`is_bust = (point_total > BUST_THRESHOLD)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| point_total | T | int | 2 ~ 31 | 解析后的手牌总点数 |
| BUST_THRESHOLD | B | int | 21（常量） | 爆牌阈值 |

**Output Range:** {true, false}。当 true 时，point_total ∈ [22, 31+]

**Example**: T=22 → is_bust=true（爆牌自伤 22 点）。T=21 → is_bust=false（完美手，触发牌型检测）

## Edge Cases

- **If `calculate_hand` receives an empty array (0 cards)**: 返回 `PointResult {point_total:0, is_bust:false, ace_count:0, soft_ace_count:0, card_count:0}`。零元素之和为零。card_count=0 表示无效手牌状态，由回合管理层负责校验，本系统不报错。

- **If `calculate_hand` receives exactly 1 card**: 正常计算。单张 K → `{total:10, bust:false}`。单张 A → `{total:11, bust:false, soft:1}`。算法在 ace_count=0 或 1 时自然退化，无需特殊处理。

- **If 手牌包含全部 4 张 A**: `raw_sum=44`，降级 3 次 → `point_total=14, soft_ace_count=1`。贪心算法正确产出最大非爆牌值（11+1+1+1=14）。4 张 A 是手牌中最低的 4 张牌总点数。

- **If `point_total` 恰好等于 21**: `is_bust=false`。这是目标值，手牌处于最强状态。本系统不设置额外标志 — "21"、"杰克"、"黑杰克"等牌型判定由牌型检测系统负责。

- **If `point_total` 恰好等于 22（最小爆牌）**: `is_bust=true`。爆牌自伤 22 点（绕过防御）。这是最轻微的爆牌惩罚。例：[K, 5, 7] → total=22。

- **If `simulate_hit` 收到手牌中已存在的牌（重复牌）**: 系统按正常算术处理，不执行牌组完整性校验。重复检测是回合管理系统的责任。本系统作为纯算术函数，信任调用方传入的输入。

- **If `simulate_hit` 在已爆牌的手牌上调用**: 函数正常追加新牌值。由于爆牌手牌 soft_ace_count=0，无法进一步降级，point_total 严格递增。结果在算术上正确。调用方（AI 或回合管理）负责不在已爆牌手牌上继续要牌。

- **If 新牌导致软手牌级联降级**: current={total:12, soft:1}（[A, A]）加 10 牌 → new_total=22 → 降级：22>21, soft=1 → new_total=12, soft=0。现有软 A 降级吸收了新牌，手牌从软变硬，总点数不变。AI 系统在使用 `simulate_hit` 估算风险时必须考虑此交互 — 在软手牌上要牌并非零风险。

- **If 所有非 A 牌之和已超过 21 且无 A**: 无降级循环运行，`point_total = non_ace_sum > 21`，`is_bust=true`。最简单的爆牌路径，无 A 解析歧义。

- **If `point_total` 理论上溢出 int 范围**: 不可能。52 张牌理论最大 point_total=404（40 张×10 + 4 张 A 按 1 计），远在 32 位 int 范围内。实际手牌上限 7 张，最大约 31。无需溢出保护。

## Dependencies

**上游依赖（本系统依赖）:**

| 系统 | 依赖类型 | 接口 | GDD 状态 |
|------|---------|------|---------|
| 卡牌数据模型 (#1) | 硬 | 读取 `bj_values`, `suit`, `rank` | 已完成 |

**下游依赖（被依赖）:**

| 系统 | 依赖类型 | 接口 | GDD 状态 |
|------|---------|------|---------|
| 牌型检测系统 (#3) | 硬 | 读取 `point_total`, `ace_count`, `card_count` | 已设计 |
| 结算引擎 (#6) | 硬 | 读取 `point_total`, `is_bust` | 已完成 |
| AI 对手系统 (#12) | 硬 | 读取 `PointResult` 结构体 + 调用 `simulate_hit` 函数 | 已设计 |
| 战斗状态系统 (#7) | 间接（经结算引擎） | `point_total` 传递至 `apply_bust_damage` | 已完成 |

## Tuning Knobs

本系统无可调参数。所有值均为 21 点规则常量：

| 常量 | 值 | 说明 |
|------|-----|------|
| BUST_THRESHOLD | 21 | 爆牌阈值，不可调 |
| ACE_HIGH_VALUE | 11 | A 的高值，不可调 |
| ACE_LOW_VALUE | 1 | A 的低值，不可调 |
| ACE_DOWNGRADE_DELTA | 10 | 每次降级减去的值 = ACE_HIGH − ACE_LOW |

这些值是标准 21 点规则的数学恒等式，不是平衡调参点。如需未来变体模式（如"迷你 21 点"阈值为 17），应通过配置文件覆盖常量，而非作为游戏内调参。

## Acceptance Criteria

**AC-01: 标准手牌（无 A）**
GIVEN 手牌 [7, K, 3]
WHEN 调用 calculate_hand(cards)
THEN point_total=20, is_bust=false, ace_count=0, soft_ace_count=0, card_count=3

**AC-02: 单张 A 软手牌**
GIVEN 手牌 [A, 7]
WHEN 调用 calculate_hand(cards)
THEN point_total=18, is_bust=false, ace_count=1, soft_ace_count=1, card_count=2

**AC-03: A 降级**
GIVEN 手牌 [A, A, 9]
WHEN 调用 calculate_hand(cards)
THEN point_total=21, is_bust=false, ace_count=2, soft_ace_count=1, card_count=3

**AC-04: 爆牌（无 A）**
GIVEN 手牌 [K, 7, 6]
WHEN 调用 calculate_hand(cards)
THEN point_total=23, is_bust=true, ace_count=0, soft_ace_count=0, card_count=3

**AC-05: 四张 A**
GIVEN 手牌 [A, A, A, A]
WHEN 调用 calculate_hand(cards)
THEN point_total=14, is_bust=false, ace_count=4, soft_ace_count=1, card_count=4

**AC-06: 空数组**
GIVEN 空手牌 []
WHEN 调用 calculate_hand(cards)
THEN point_total=0, is_bust=false, ace_count=0, soft_ace_count=0, card_count=0

**AC-07: 恰好 21（边界）**
GIVEN 手牌产生 point_total=21（如 [K, A]）
WHEN 读取 is_bust
THEN is_bust=false

**AC-08: 恰好 22（最小爆牌）**
GIVEN 手牌产生 point_total=22（如 [K, 5, 7]）
WHEN 读取 is_bust
THEN is_bust=true

**AC-09: simulate_hit 非新 A 牌**
GIVEN current={total:12, soft:0, count:2}, new_card=8
WHEN 调用 simulate_hit(current, new_card)
THEN point_total=20, is_bust=false, soft_ace_count=0, card_count=3

**AC-10: simulate_hit 新 A 牌**
GIVEN current={total:10, soft:0, count:1}, new_card=A
WHEN 调用 simulate_hit(current, new_card)
THEN point_total=21, is_bust=false, ace_count=1, soft_ace_count=1, card_count=2

**AC-11: simulate_hit 级联降级**
GIVEN current={total:18, soft:1, count:2}, new_card=8
WHEN 调用 simulate_hit(current, new_card)
THEN point_total=16, is_bust=false, soft_ace_count=0, card_count=3

**AC-12: simulate_hit 在已爆牌手牌上**
GIVEN current={total:23, bust:true, soft:0, count:3}, new_card=5
WHEN 调用 simulate_hit(current, new_card)
THEN point_total=28, is_bust=true, soft_ace_count=0, card_count=4

**AC-13: PointResult 字段完整性**
GIVEN 手牌 [A, K] 产生 PointResult
WHEN 检查返回对象
THEN 包含恰好 5 个字段：point_total(int)=21, is_bust(bool)=false, ace_count(int)=1, soft_ace_count(int)=1, card_count(int)=2

**AC-14: 纯函数确定性**
GIVEN 相同输入 [A, 7, K]
WHEN calculate_hand 被调用 N 次（N≥3）
THEN 每次返回相同的 PointResult，且无全局或静态状态被读取或修改

**AC-15: 单张牌输入**
GIVEN 手牌 [K]
WHEN 调用 calculate_hand(cards)
THEN point_total=10, is_bust=false, ace_count=0, card_count=1

GIVEN 手牌 [A]
WHEN 调用 calculate_hand(cards)
THEN point_total=11, is_bust=false, ace_count=1, soft_ace_count=1, card_count=1

**AC-16: 点数值映射覆盖所有 rank 类别**
GIVEN 以下单牌手牌
WHEN 分别调用 calculate_hand：
[2]→2, [5]→5, [10]→10, [J]→10, [Q]→10, [K]→10, [A]→11(soft)
THEN 每个结果符合 bj_values 映射

**AC-17: 边界 — 不执行排除的职责**
GIVEN 手牌包含带花色、印记、卡质属性的卡牌
WHEN 调用 calculate_hand(cards)
THEN 返回的 PointResult 不包含花色、牌型分类、筹码计算相关字段
AND 函数不读取 bj_values 以外的任何属性

**AC-18: 降级精确停在 21**
GIVEN 手牌 [A, A, 9]（raw_sum=31）
WHEN 调用 calculate_hand(cards)
THEN point_total=21（不是 11 或 31），验证贪心算法降级到最大非爆牌值即停止
