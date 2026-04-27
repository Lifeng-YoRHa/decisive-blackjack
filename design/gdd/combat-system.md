# 战斗状态系统 (Battle State System)

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-04-23
> **Implements Pillar**: Core loop — 对战回合的生命值、防御值与胜负判定

## Overview

战斗状态系统是《决胜21点》的对战状态追踪核心。它维护玩家和 AI 对手的生命值与防御值，并判定每回合的胜负与存活条件。作为 Foundation 层系统，它为结算引擎提供伤害/回复/防御的目标容器，为回合管理提供生死判定接口，为牌桌 UI 提供血条和防御条渲染数据。在玩家感受层面，这个系统创造了"我还能撑几个回合？"的核心紧张感 — 每次红桃回血是喘息，方片伤害是压力，黑桃防御是生存保险（吸收伤害，减少生命损失），爆牌自伤则是惩罚。没有这个系统，牌桌上的每一张牌都只是数字，而非关乎生死的抉择。

## Player Fantasy

**运筹帷幄 — 读牌编排，精密计算每一回合**

玩家幻想是读取战场局势并编排完美回合的掌控感。核心时刻：你看到对手的明牌是方片 Q（12 点伤害），你有 8 点生命值。你将红桃 J 排在第一位回复生命（回复 11），再用黑桃 9 积累防御挡住后续伤害，最后用方片 7 反刺对手。数字精确，顺序决定一切 — 当你的血量恰好让你活下来时，你破解了密码。这个系统服务于此幻想的方式是让生命值和防御值成为可读的、可计算的已知量 — 玩家不是在祈祷好运，而是在精确计算"我需要多少回复和防御才能撑住这一轮？"。紧张感来自计算本身：如果你算错了哪怕一点，代价就是生命值。爆牌自伤（超过 21 点按点数对自己造成伤害）将"要牌"从贪心行为变成了一次经过计算的冒险 — 多抽一张牌可能给你更好的编排空间，也可能让你自食其果。

## Detailed Design

### Core Rules

**1. 战斗参与者 (Combatant)**

每场对战有两个战斗参与者：玩家和 AI 对手。每个参与者维护三个核心状态值：

| 字段 | 类型 | 说明 |
|------|------|------|
| `hp` | int | 当前生命值 |
| `max_hp` | int | 生命值上限（= 初始 HP） |
| `defense` | int | 当前防御值 |
| `pending_defense` | int | 排队等待的延迟防御值（排序结束后、结算前 FIFO 执行） |
| `is_alive` | bool | `hp > 0` |

**2. 玩家 HP 规则**

- 玩家 `max_hp` = 100，固定不变，不随对手变化。
- `hp` 上限为 `max_hp`，回复不能超过此值。

**3. AI HP 规则**

- AI `max_hp` 按对手序号递增（见公式部分）。
- AI `hp` 在每个新对手开始时重置为该对手的 `max_hp`。
- AI `hp` 同样不能超过其 `max_hp`。

**4. 防御规则**

- 每回合开始时，双方 `defense` 和 `pending_defense` 重置为 0。
- 黑桃卡牌结算时，将效果值加入拥有者的 `defense`。
- 防御在回合内无上限，可以无限累积。
- 防御的唯一消耗方式：吸收方片伤害。
- 所有卡牌结算完毕后，未消耗的防御直接清零（不产生任何额外效果）。

**5. 伤害规则（方片）**

当一张方片卡牌对目标造成伤害时：
1. 从目标的 `defense` 中扣除。如果 `defense` >= 伤害值，全额吸收，`defense` 减少对应数值，HP 不受影响。
2. 如果 `defense` < 伤害值，`defense` 清零，剩余伤害扣减 `hp`。
3. `hp` 最低为 0（不会出现负数）。

**6. 回复规则（红桃）**

当一张红桃卡牌结算时：
1. 将回复值加到 `hp`。
2. 如果 `hp` 超过 `max_hp`，截断为 `max_hp`。
3. 溢出回复值不产生任何额外效果（不转化为防御或筹码）。

**7. 防御清零规则**

所有卡牌结算完成后：
1. 双方 `defense` 直接重置为 0。
2. 未消耗的防御不产生任何额外效果（不转化为伤害、筹码或其他收益）。

**8. 爆牌自伤规则**

爆牌检测在卡牌结算**之前**执行。当手牌点数超过 21 时：
1. 爆牌方**所有**卡牌的花色效果无效（不回复、不造成伤害、不获得防御、不获得筹码）。
2. 对自己造成等同于手牌点数总和的伤害（21 点计算值，非 effect_value）。
3. 爆牌自伤**绕过**防御，直接扣减 HP。
4. 双倍下注时，爆牌自伤翻倍（由特殊玩法系统处理，战斗状态系统只接收翻倍后的值）。
5. 非爆牌方的卡牌照常结算。

**9. 生死判定**

- 生死判定**仅在所有卡牌结算完毕且防御清零后**统一执行，不在卡牌结算中途判定。
- 结算过程中 HP 可以降至 0 以下（截断为 0），但后续的红桃回复可能将其恢复。
- 所有卡牌结算完毕且防御清零后，检查双方 `hp`：
  - 玩家 `hp` > 0 + AI `hp` > 0 → CONTINUE（下一回合）
  - 玩家 `hp` > 0 + AI `hp` = 0 → PLAYER_WIN
  - 玩家 `hp` = 0 + AI `hp` > 0 → PLAYER_LOSE
  - 玩家 `hp` = 0 + AI `hp` = 0 → PLAYER_LOSE（同时死亡判负）

**10. 战斗状态接口**

战斗状态系统为结算引擎提供以下原子操作：

| 方法 | 说明 |
|------|------|
| `apply_damage(target, amount)` | 防御先吸收，剩余扣 HP |
| `apply_heal(target, amount)` | 回复 HP，不超过 max_hp |
| `add_defense(target, amount)` | 增加防御值 |
| `queue_defense(target, amount)` | 排队延迟防御：将 amount 加入 `pending_defense`，在排序结束→结算前的间隙按 FIFO 执行 `add_defense()` |
| `apply_bust_damage(target, amount)` | 绕过防御，直接扣 HP |
| `reset_defense()` | 双方防御清零（结算结束后调用） |
| `check_death(target) → bool` | 检查 hp 是否 ≤ 0 |
| `get_round_result() → enum` | PLAYER_WIN / PLAYER_LOSE / CONTINUE |

### States and Transitions

```
[回合开始]
    │
    ▼
defense = 0 (双方)
    │
    ▼
[要牌/停牌阶段] → 双方手牌确定
    │
    ▼
[排序卡牌] → 双方各自排好结算顺序
    │
    ▼
[执行 pending_defense] → 排队防御按 FIFO 应用（厚衣服等延迟道具）
    │
    ▼
[爆牌检测]
    │
    ├─ 双方均未爆牌 → 进入交替结算
    │   │
    │   ▼
    │   [交替结算] A1→B1→A2→B2→... ◄────────┐
    │       │                                  │
    │       ├─ 方片 → apply_damage()           │
    │       ├─ 红桃 → apply_heal()            │
    │       ├─ 黑桃 → add_defense()           │
    │       ├─ 草花 → (筹码经济系统处理)       │
    │       │                                  │
    │       ▼                                  │
    │   还有未结算的卡牌？ ──── 是 ───────────┘
    │       │ 否
    │       ▼
    │   defense = 0 (双方清零)
    │
    ├─ 仅一方爆牌 → 爆牌方自伤，该方所有卡牌无效
    │   │           非爆牌方逐张结算（无交替，连续执行）
    │   ▼
    │   defense = 0 (双方清零)
    │
    └─ 双方均爆牌 → 各自自伤，所有卡牌无效
        │
        ▼
    defense = 0 (双方清零)
    │
    ▼
[生死判定]
    │
    ├─ 玩家 hp > 0 + AI hp > 0 → CONTINUE（下一回合）
    ├─ 玩家 hp > 0 + AI hp = 0 → PLAYER_WIN
    ├─ 玩家 hp = 0 + AI hp > 0 → PLAYER_LOSE
    └─ 玩家 hp = 0 + AI hp = 0 → PLAYER_LOSE（同时死亡判负）
```

### Interactions with Other Systems

| 系统 | 战斗状态接收什么 | 战斗状态提供什么 |
|------|-----------------|-----------------|
| 结算引擎 | `apply_damage(target, amount)` 等 API 调用，以及最终效果值 | HP/defense/alive 状态的读写接口 |
| 卡牌数据模型 | 无直接交互 | 无 |
| 特殊玩法系统 | 双倍下注的爆牌自伤翻倍标志 | HP/defense 状态（保险、分牌等特殊玩法需要读取） |
| 商店系统 | 无 | HP 状态（商店恢复生命服务需要读取和修改） |
| 回合管理 | 回合开始时触发 defense 重置 | `get_round_result()` 判定结果 |
| 对局进度系统 | 无 | 当前对手序号 → 决定 AI max_hp |
| 牌桌 UI | 无 | `hp`, `max_hp`, `defense`, `is_alive` 用于渲染血条和防御条 |
| 道具系统 (#16) | `apply_heal(PLAYER, 10)`（能量饮料）、`apply_damage(AI, 10)`（小刀）、`queue_defense(PLAYER, 10)`（厚衣服，排队至结算前 FIFO 触发） | 无 |

## Formulas

### 1. 伤害应用 (damage_application)

方片卡牌结算时，防御先吸收伤害：

```
absorbed = min(defense, amount)
damage_to_hp = amount - absorbed
defense_new = defense - absorbed
hp_new = max(0, hp - damage_to_hp)
```

**变量：**
| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| defense | int | 0 ~ ∞ | 目标当前防御值 |
| amount | int | 1 ~ ∞ | 结算引擎传入的最终伤害值 |
| absorbed | int | 0 ~ amount | 被防御吸收的伤害 |
| damage_to_hp | int | 0 ~ amount | 穿透防御直接扣 HP 的伤害 |

**输出范围**：hp_new ∈ [0, max_hp]；defense_new ∈ [0, 之前防御值]
**示例**：defense=8, amount=15, hp=40 → absorbed=8, damage_to_hp=7, defense_new=0, hp_new=33

### 2. 回复应用 (heal_application)

红桃卡牌结算时，回复 HP 但不超过上限：

```
hp_new = min(max_hp, hp + amount)
overflow = max(0, hp + amount - max_hp)  // 无游戏效果
```

**变量：**
| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| hp | int | 0 ~ max_hp | 目标当前 HP |
| max_hp | int | 80 ~ 300 | HP 上限（= 初始 HP） |
| amount | int | 1 ~ ∞ | 结算引擎传入的最终回复值 |
| overflow | int | 0 ~ amount | 超出上限的回复（浪费） |

**输出范围**：hp_new ∈ [0, max_hp]
**示例**：hp=95, max_hp=100, amount=12 → hp_new=100, overflow=7（浪费）

### 3. 防御累积 (defense_accumulation)

黑桃卡牌结算时，防御值增加：

```
defense_new = defense + amount
```

**变量：**
| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| defense | int | 0 ~ ∞ | 当前防御值 |
| amount | int | 1 ~ ∞ | 结算引擎传入的最终防御值 |

**输出范围**：无上限，在回合内自由累积
**示例**：defense=5, amount=9 → defense_new=14

### 4. 防御清零 (defense_reset)

所有卡牌结算完成后，双方防御直接归零：

```
player.defense = 0
ai.defense = 0
```

未消耗的防御不产生任何额外效果。

### 5. 爆牌自伤 (bust_self_damage)

手牌超过 21 点时，对自己造成等同于点数总和的伤害：

```
bust_damage = point_total
hp_new = max(0, hp - bust_damage)
```

**变量：**
| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| point_total | int | 22 ~ 31+ | 手牌的 21 点计算总和（必然 > 21） |
| hp | int | 0 ~ max_hp | 爆牌者的当前 HP |
| bust_damage | int | 22 ~ 31+ | 自伤值 = point_total，绕过防御 |

**输出范围**：bust_damage ∈ [22, 31+]，hp_new ∈ [0, max_hp]
**注意**：point_total 使用 21 点计算规则（A=1 或 11，J-K=10），不是 effect_value。双倍下注时由特殊玩法系统传入 `bust_damage × 2`。
**示例**：Hand=[K, 7, 6] → point_total=23, hp=40 → hp_new=17

### 6. AI HP 缩放 (ai_hp_scaling)

AI 对手的 max_hp 按对手序号递增：

```
ai_max_hp = lookup(ai_hp_table, opponent_number)
```

| opponent_number | ai_max_hp |
|-----------------|-----------|
| 1 | 80 |
| 2 | 100 |
| 3 | 120 |
| 4 | 150 |
| 5 | 180 |
| 6 | 220 |
| 7 | 260 |
| 8 | 300 |

**变量：**
| 变量 | 类型 | 范围 | 说明 |
|------|------|------|------|
| opponent_number | int | 1 ~ 8 | 当前对手序号 |
| ai_max_hp | int | 80 ~ 300 | AI 该对手的初始 HP |

**输出范围**：ai_max_hp ∈ [80, 300]。玩家 max_hp 固定 100。
**示例**：Opponent 4 → ai_max_hp=150。Boss (opponent 8) → ai_max_hp=300（玩家 HP 的 3 倍）。

## Edge Cases

- **如果 HP 在结算途中降至 0**：结算不中止，所有剩余卡牌继续结算完毕。后续的红桃回复可能将 HP 恢复至 0 以上。生死判定在所有卡牌结算完毕且防御清零后统一执行。

- **如果双方均爆牌**：各自独立承受自伤（绕过防御），双方均无卡牌效果触发，防御保持为 0，结算后防御清零，进入生死判定。如果双方自伤后都 HP=0，判 PLAYER_LOSE。

- **如果仅一方爆牌**：爆牌方自伤后，该方所有卡牌不参与结算。非爆牌方的卡牌连续逐张结算（无交替），正常触发花色效果和防御累积。结算后双方防御清零，进入生死判定。

- **如果爆牌自伤将 HP 降至 0**：HP 截断为 0，但结算继续。非爆牌方的卡牌仍正常结算。防御清零后统一生死判定。

- **如果防御值远超任何可能伤害**：防御无上限，未消耗的防御在结算后直接清零，不产生任何额外效果。黑桃是纯防御花色，不会转化为伤害。

- **如果满 HP 时红桃结算**：回复值全部浪费（overflow），无任何替代效果。玩家在卡牌排序时应将红桃安排在 HP 较低时结算。

- **如果防御为 0 时结算结束**：双方防御清零，无特殊效果。

- **如果分牌后一手爆牌导致自伤**：爆牌伤害作用于玩家的共享 HP 池。如果 HP 降至 0，另一手不再结算，防御清零后进入生死判定。

- **如果商店回复使 HP 超过 max_hp**：`apply_heal` 统一处理，截断为 max_hp。商店恢复走同一接口，不直接操纵 HP。

- **如果保险以 HP 支付且 HP 不足**（保险 = 30 筹码或 6 HP）：如果选择 HP 支付且 HP ≤ 6，HP 截断为 0。防御清零后判 PLAYER_LOSE。UI 应在 HP ≤ 6 时禁用 HP 支付选项。

- **如果抽牌堆耗尽**：不是战斗状态系统的问题（属于回合管理/牌组管理），但防御和 HP 状态保持不变，不受洗牌影响。

## Dependencies

**上游依赖**: 无 — 本系统是 Foundation 层，独立于其他系统。

**下游依赖（被依赖）**:

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 结算引擎 | 硬 | 调用 `apply_damage`, `apply_heal`, `add_defense`, `apply_bust_damage`, `reset_defense` |
| 特殊玩法系统 | 硬 | 读取 `hp`, `defense` 状态；传入爆牌翻倍标志 |
| 商店系统 | 硬 | 调用 `apply_heal` 恢复生命；读取 `hp`/`max_hp` 计算费用 |
| 回合管理 | 硬 | 回合开始时触发 `defense = 0` 重置；调用 `get_round_result()` 判定结果 |
| 对局进度系统 | 硬 | 提供 `opponent_number` → 战斗状态计算 AI `max_hp` |
| 牌桌 UI | 硬 | 读取 `hp`, `max_hp`, `defense` 渲染血条和防御条 |

## Tuning Knobs

| 调参点 | 类型 | 默认值 | 安全范围 | 影响什么 |
|--------|------|--------|----------|---------|
| `player_max_hp` | int | 100 | 50 ~ 200 | 玩家生命上限。调低增加难度紧张感，调高更宽容 |
| `ai_hp_table` | int[8] | [80,100,120,150,180,220,260,300] | 每项 50~500 | AI 对手 HP 曲线。整体调高延长游戏时间，单个调高制造难度峰值 |
| `bust_damage_multiplier` | float | 1.0 | 0.5 ~ 3.0 | 爆牌自伤倍率基础值。双倍下注时在此基础上再 ×2 |
| `settlement_tie_compensation` | int | 20 | 0 ~ 100 | 结算先手掷币补偿（不直接影响战斗状态，但影响经济与战斗节奏）。注册名：settlement_tie_compensation (chip-economy) |

## Acceptance Criteria

### 核心规则

**AC-01: is_alive 由 hp 派生**
GIVEN 战斗参与者 hp=0, max_hp=100, defense=5
WHEN 系统检查 is_alive
THEN is_alive = false

GIVEN 战斗参与者 hp=1, max_hp=100, defense=0
WHEN 系统检查 is_alive
THEN is_alive = true

**AC-02: 玩家 HP 固定 100，回复不超过上限**
GIVEN 新游戏开始，opponent_number=1
WHEN 玩家战斗参与者初始化
THEN player.hp=100, player.max_hp=100

GIVEN player hp=100, max_hp=100
WHEN 调用 apply_heal(player, 50)
THEN player.hp=100（不变），overflow=50

**AC-03: AI HP 按对手序号缩放，每个对手重置**
GIVEN opponent_number=1
WHEN AI 战斗参与者初始化
THEN ai.hp=80, ai.max_hp=80

GIVEN opponent_number=4
WHEN AI 战斗参与者初始化
THEN ai.hp=150, ai.max_hp=150

GIVEN opponent_number=8
WHEN AI 战斗参与者初始化
THEN ai.hp=300, ai.max_hp=300

GIVEN 对手 2 结束时 ai.hp=40，对手 3 开始
WHEN AI 战斗参与者重新初始化
THEN ai.hp=120, ai.max_hp=120（重置，非继承）

**AC-04: 防御每回合重置为 0，无上限累积**
GIVEN 玩家上回合 defense=15
WHEN 新回合开始
THEN player.defense=0, ai.defense=0

GIVEN player defense=0
WHEN 同一回合内调用 add_defense(player, 10) 三次
THEN player.defense=30（无上限）

**AC-05: 方片伤害被防御先吸收，剩余扣 HP，HP 最低 0**
GIVEN target hp=40, defense=8
WHEN 调用 apply_damage(target, 15)
THEN target.defense=0, target.hp=33

GIVEN target hp=3, defense=5
WHEN 调用 apply_damage(target, 10)
THEN target.defense=0, target.hp=0（不为负数）

GIVEN target hp=20, defense=30
WHEN 调用 apply_damage(target, 15)
THEN target.defense=15, target.hp=20（防御全额吸收，HP 不变）

**AC-06: 红桃回复不超过 max_hp，溢出浪费**
GIVEN target hp=95, max_hp=100
WHEN 调用 apply_heal(target, 12)
THEN target.hp=100（截断），overflow=7

GIVEN target hp=30, max_hp=100
WHEN 调用 apply_heal(target, 10)
THEN target.hp=40（无溢出）

**AC-07: 防御清零 — 结算后防御直接归零**
GIVEN player defense=18, ai defense=10
WHEN 调用 reset_defense()
THEN player.defense=0, ai.defense=0

GIVEN player defense=0, ai defense=0
WHEN 调用 reset_defense()
THEN player.defense=0, ai.defense=0（无变化）

**AC-08: 爆牌 — 结算前检测，自伤绕过防御，该方所有卡牌无效**
GIVEN player hp=40, defense=10, 手牌 point_total=23
WHEN 爆牌检测通过
THEN player.hp=17（40-23, 防御不吸收），玩家所有卡牌效果无效，非爆牌方 AI 正常结算

GIVEN player hp=20, defense=15, 手牌 point_total=25
WHEN 爆牌检测通过
THEN player.hp=0（20-25, 截断为 0），所有卡牌效果无效

**AC-09: 结算中途 HP=0 不中止 — 死亡判定在防御清零后**
GIVEN player hp=10, defense=0, 结算顺序中方片-12 在位置 2，红桃-8 在位置 4
WHEN 结算执行完毕
THEN 位置 2 后：player.hp=0；位置 4 后：player.hp=8；结算未中止；防御清零后生死判定

**AC-10: 同时死亡 — 玩家判负**
GIVEN player hp=20, defense=0, ai hp=20, defense=0
WHEN 双方结算后 hp 同时 ≤ 0
THEN 结果=PLAYER_LOSE（玩家先攻先判，同时归零判玩家负）

### 公式

**AC-F1: damage_application**
GIVEN target defense=8, hp=40
WHEN apply_damage(target, 15) 被调用
THEN absorbed=8, damage_to_hp=7, defense_new=0, hp_new=33

GIVEN target defense=50, hp=40
WHEN apply_damage(target, 15) 被调用
THEN absorbed=15, damage_to_hp=0, defense_new=35, hp_new=40

**AC-F2: heal_application**
GIVEN target hp=95, max_hp=100
WHEN apply_heal(target, 12) 被调用
THEN hp_new=100, overflow=7

GIVEN target hp=0, max_hp=100
WHEN apply_heal(target, 20) 被调用
THEN hp_new=20, overflow=0

**AC-F3: defense_accumulation**
GIVEN target defense=5
WHEN add_defense(target, 9) 被调用
THEN defense_new=14

GIVEN target defense=100
WHEN add_defense(target, 50) 被调用
THEN defense_new=150（无上限）

**AC-F4: defense_reset**
GIVEN player defense=18, ai defense=10
WHEN reset_defense() 执行
THEN player.defense=0, ai.defense=0

**AC-F5: bust_self_damage**
GIVEN player 手牌 [K, 7, 6]，point_total=23, player hp=40, defense=10
WHEN 爆牌检测通过并调用 apply_bust_damage(player, 23)
THEN bust_damage=23, hp_new=17（防御被忽略）

**AC-F6: ai_hp_scaling 查找表**
GIVEN opponent_number 1 到 8
WHEN 每个 AI 战斗参与者初始化
THEN 查找返回 [80, 100, 120, 150, 180, 220, 260, 300]

### 边界情况

**AC-E1: 结算中途 HP=0 后被红桃回复救回**
GIVEN player hp=10, defense=0, 结算顺序：方片-12（位置 2）→ 红桃-8（位置 4）
WHEN 结算执行完毕
THEN 位置 2 后 player.hp=0；位置 4 后 player.hp=8；结算未中止

**AC-E2: 双方均爆牌**
GIVEN player hp=50, defense=0, point_total=24; ai hp=80, defense=0, point_total=26
WHEN 双方均被检测为爆牌
THEN player.hp=26（50-24）, ai.hp=54（80-26）, 无卡牌效果触发, 防御清零, 结果=CONTINUE

**AC-E3: 仅一方爆牌**
GIVEN player hp=40, defense=0, point_total=22（爆牌）; ai hp=60, defense=0, AI 未爆牌且有黑桃-9 和方片-5
WHEN 爆牌检测执行
THEN player.hp=18（40-22, 自伤）; AI 黑桃-9 结算：ai.defense=9; AI 方片-5 结算：player.hp=13（18-5）; 结算后防御清零; 结果=CONTINUE

**AC-E4: 满 HP 时回复全部浪费**
GIVEN player hp=100, max_hp=100
WHEN apply_heal(player, 30) 被调用
THEN player.hp=100, overflow=30, 无防御或筹码转化

**AC-E5: 双方防御均为 0 时清零无效果**
GIVEN player hp=50, defense=0, ai hp=80, defense=0
WHEN reset_defense() 被调用
THEN player.hp=50, ai.hp=80（均不变）

**AC-E6: 双方同时死于爆牌自伤**
GIVEN player hp=22, defense=0, point_total=24; ai hp=26, defense=0, point_total=30
WHEN 双方均被检测为爆牌
THEN player.hp=0（22-24 截断）, ai.hp=0（26-30 截断）, 结果=PLAYER_LOSE

## Open Questions

- [ ] 初始筹码数是多少？（影响筹码经济系统，不影响战斗状态）
- [ ] AI 难度递进规则：除 HP 外，AI 的印记/卡质概率是否随对手递增？（影响 AI 对手系统）
- [ ] 分牌时两手牌的结算交互细节（一手爆牌后另一手是否继续？）——待特殊玩法系统设计时确认。
