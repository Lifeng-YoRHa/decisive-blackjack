# 商店系统 (Shop System)

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-25
> **Implements Pillar**: Economy — buildcraft, resource investment, card enhancement

## Overview

商店系统是《决胜21点》的构筑中枢——每击败一个对手后进入商店，用回合中赚取的筹码购买卡牌增强（印记、卡质、提纯）、恢复生命、或刷新随机商品，为下一场战斗做准备。在玩家层面，商店是每轮构建策略的核心时刻：是花 120 筹码给草花 K 赋予祖母绿 III 级来加速经济引擎？还是花 100 筹码给方片 Q 加短剑印记来提升伤害输出？还是花 50 筹码回复 10 HP 保命？筹码有限，欲望无限，选择即策略。在数据层面，商店是一个状态机——管理库存生成（随机商品的种子和权重）、价格计算（基于卡牌数据模型的定价公式）、交易执行（通过筹码经济系统的 `spend_chips()` / `add_chips()` 接口）和卡牌实例修改（通过卡牌数据模型的属性写入）。商店不创建或销毁卡牌实例——它只修改现有实例的 `stamp`、`quality`、`quality_level` 字段。商店系统连接了筹码经济系统（消耗筹码）和卡牌数据模型（增强卡牌），是游戏中唯一的卡牌增强入口——玩家构筑的每一步都经过商店。

## Player Fantasy

**赌场老板 — 资源调度，一掷千金**

核心时刻：商店界面亮起。余额 312。随机栏里一张带钱币印记的草花 K 标价 97——它能让你的经济引擎每回合多产出 10 筹码。固定栏里，黑曜石赋质要 120——你的黑桃 A 需要它撑过下个对手的高伤害。而刷新按钮只要 20——也许下一轮会出更好的东西？你不是在"买东西"。你在分配有限的战争预算。每一枚筹码都在说：投给我，我回报最多。

商店系统的玩家幻想是**战时军需官的调度感**：资源永远不够，欲望永远超额，选择即战略。你在筹码经济中是"庄家"（投资回报），在印记系统中是"锻造师"（编排时序），在卡质系统中是"炼金术士"（提纯材质）——商店是你同时扮演这三个角色的舞台。每次访问都是一次投资组合再平衡：进攻投资（短剑、红水晶）、防御投资（护盾、黑曜石）、经济投资（钱币、金属质）、生存投资（回血）。刷新是追加情报费——你花 20 筹码买一次"再看两张牌"的机会，本质上是对信息下注。卖卡是止损——50% 回收率意味着投资有沉没成本，轮换牌组有真实代价。当你在商店中做出完美的三选二决策，下个回合的结算引擎验证你的判断时，你不是在验证一张牌的强弱——你在验证一个策略愿景。

## Detailed Design

### Core Rules

**1. 系统性质**

商店系统是一个回合间构筑界面——每击败一个对手后触发一次，管理固定服务（HP 恢复、赋质、提纯、卖卡、印记赋予）和随机商品（2 个印记 + 2 张增强卡牌），通过筹码经济系统执行所有资金流转，通过卡牌数据模型修改卡牌实例属性。商店不创建或销毁卡牌实例——只修改现有实例的 `stamp`、`quality`、`quality_level` 字段。52 张牌不变量始终维护。

**2. 商店触发时机**

商店在以下时机触发：
- 击败对手 1-7 后，进入商店阶段
- 击败对手 8 后，游戏胜利，不进入商店
- 共 7 次商店访问

**3. 商店库存结构**

| 类别 | 内容 | 数量 | 可刷新 |
|------|------|------|--------|
| 固定服务 | HP 恢复 | 不限次 | 否 |
| 固定服务 | 印记赋予（7 种） | 不限次 | 否 |
| 固定服务 | 赋质（8 种） | 不限次 | 否 |
| 固定服务 | 提纯 | 不限次 | 否 |
| 固定服务 | 卖卡 | 不限次 | 否 |
| 固定服务 | 道具购买（7 种） | 不限次 | 否 |
| 随机商品 | 随机印记 | 2 件 | 是 |
| 随机商品 | 随机增强卡牌 | 2 件 | 是 |

固定服务始终可用，不受刷新影响。随机商品每次刷新重新生成。

**4. 固定服务**

**4a. HP 恢复**

- 价格：5 筹码 / HP
- 玩家选择恢复量（整数 HP），上限为 `max_hp - current_hp`
- 不可超额恢复（current_hp > max_hp 不可能）
- 调用 `spend_chips(PLAYER, hp_amount × 5, SHOP_PURCHASE)` 扣款
- AI 无 HP 恢复服务

**4b. 印记赋予**

- 价格表：

| 印记 | 价格 |
|------|------|
| 短剑 (SWORD) | 100 |
| 护盾 (SHIELD) | 100 |
| 心 (HEART) | 100 |
| 钱币 (COIN) | 100 |
| 跑鞋 (RUNNING_SHOES) | 150 |
| 乌龟 (TURTLE) | 150 |
| 重锤 (HAMMER) | 300 |

- 玩家选择印记类型 → 选择目标玩家卡牌 → 确认
- 任何印记可赋予任何花色的卡牌（无花色限制）
- 允许覆盖已有印记（旧印记完全丢弃，不可恢复）
- 执行：`card.stamp = selected_stamp`，调用 `spend_chips()`

**4c. 赋质**

- 价格表（与卡质系统 GDD 一致）：

| 卡质 | 价格 |
|------|------|
| 铜 (COPPER) | 40 |
| 银 (SILVER) | 80 |
| 金 (GOLD) | 120 |
| 钻 (DIAMOND) | 200 |
| 宝石质 (RUBY/SAPPHIRE/EMERALD/OBSIDIAN) | 120 |

- 新赋予品质始终从 III 级开始
- 允许覆盖已有卡质（旧卡质完全丢弃，不可恢复）
- 宝石质必须通过花色限制验证：`is_valid_assignment(suit, quality)`
- 执行：`card.quality = selected_quality`，`card.quality_level = III`，调用 `spend_chips()`

**4d. 提纯**

- 价格表（与卡质系统 GDD 一致）：

| 升级路径 | 费用 |
|---------|------|
| III → II | 100 |
| II → I | 200 |

- 前提：`quality != null` 且 `quality_level != I`
- 被摧毁的卡牌（quality=null）不可提纯
- 每次提纯只升一级
- 执行：`card.quality_level` 递增一级，调用 `spend_chips()`

**4e. 卖卡**

- 退款公式：`sell_refund = floor(total_investment × sell_price_ratio)`
- `total_investment` = 该卡牌当前增强的总投入（印记购买价 + 赋质购买价 + 累计提纯费用）
- 卖卡执行：`card.stamp = null`，`card.quality = null`，`card.quality_level = III`
- 卡牌仍在牌组中（52 张不变量），回归普通牌
- 仅有增强的卡牌可卖（stamp=null 且 quality=null 的牌退款为 0，灰显）
- 调用 `add_chips(PLAYER, sell_refund, SHOP_SELL)`

**4f. 道具购买**

- 价格表（与道具系统 GDD 一致）：

| 道具 | 价格 |
|------|------|
| 能量饮料 (ENERGY_DRINK) | 70 |
| 小刀 (KNIFE) | 70 |
| 透视眼镜 (XRAY_GLASSES) | 150 |
| 小镜子 (SMALL_MIRROR) | 100 |
| 微缩炸药 (MINI_EXPLOSIVE) | 150 |
| 厚衣服 (THICK_CLOTHES) | 60 |
| 密码锁 (PADLOCK) | 100 |

- 前提：`len(inventory) < item_max_inventory`（默认 5）且筹码余额足够
- 购买后创建 `ItemInstance` 加入玩家道具库存
- 同种道具可叠加购买（如 3 瓶能量饮料）
- 调用 `spend_chips(PLAYER, item_price, SHOP_PURCHASE)`
- 道具详细效果定义在道具系统 GDD 中

**5. 随机商品生成**

每次商店访问或刷新时生成 4 件随机商品：

**5a. 随机印记（2 件）**

- 从 7 种印记中加权随机抽取 2 个（不重复）
- 抽取到的印记以固定服务价格出售（SWORD/SHIELD/HEART/COIN=100, RUN/TURTLE=150, HAMMER=300）
- 购买后玩家选择目标卡牌应用（与固定服务相同）
- 权重表：

| 印记 | 权重 | 出现率 |
|------|------|--------|
| SWORD | 25 | ~25% |
| SHIELD | 25 | ~25% |
| HEART | 25 | ~25% |
| COIN | 25 | ~25% |
| RUNNING_SHOES | 12 | ~12% |
| TURTLE | 12 | ~12% |
| HAMMER | 1 | ~1% |

总权重 = 125。每件独立抽取。

**5b. 随机增强卡牌（2 件）**

每件随机增强卡牌的生成流程：
1. 从玩家牌组（52 张）中随机选择一张卡牌
2. 随机选择一个增强类型：印记 (40%) 或卡质 (60%)
3. 若选印记：按印记权重表（同 5a）随机选择印记类型
4. 若选卡质：按卡质权重表随机选择卡质类型，验证花色限制，不合格则重抽
5. 计算价格（见规则 6）
6. 若目标卡牌已有完全相同的增强（同印记或同卡质同等级），灰显并标注"已拥有"

卡质权重表（用于随机生成）：

| 卡质 | 权重 | 出现率 |
|------|------|--------|
| COPPER | 25 | ~25% |
| SILVER | 25 | ~25% |
| GOLD | 20 | ~20% |
| RUBY/SAPPHIRE/EMERALD/OBSIDIAN | 25 (各 ~6%) | ~25% |
| DIAMOND | 5 | ~5% |

总权重 = 100。宝石质按花色匹配筛选。

**6. 随机增强卡牌定价**

定价公式：`random_card_price = base_buy_price + enhancement_discount`

其中：
- `base_buy_price` = 卡牌原型的 `chip_value + spade_face_bonus`（来自卡牌数据模型）
- `enhancement_discount` = 增强服务价格 × 0.50
  - 印记增强：`stamp_price × 0.50`
  - 卡质增强：`quality_price × 0.50`

示例：
- 草花 K + COIN 印记：`65 + floor(100 × 0.50)` = 65 + 50 = **115 筹码**
- 黑桃 A + DIAMOND III：`(75+10) + floor(200 × 0.50)` = 85 + 100 = **185 筹码**
- 方片 2 + SWORD：`10 + floor(100 × 0.50)` = 10 + 50 = **60 筹码**

**7. 刷新机制**

- 每次商店访问允许刷新 **1 次**
- 费用：20 筹码
- 效果：重新生成全部 4 件随机商品（2 印记 + 2 增强卡牌）
- 固定服务不受影响
- 调用 `spend_chips(PLAYER, 20, SHOP_PURCHASE)`

**8. 交易规则**

- **先扣款后执行**：每次交易先调用 `spend_chips()`，成功后才修改卡牌实例属性
- **原子性**：每次交易是独立的，无购物车或捆绑机制
- **余额不足**：`spend_chips()` 返回失败时，不修改任何卡牌属性，无部分状态
- **无限次购买**：玩家在每次商店访问中可购买任意次数（受余额限制）
- **零值交易**：与筹码经济系统规则一致，金额为 0 的交易为空操作

**9. 卖卡退款计算细则**

| 增强组合 | 总投入计算 | 退款 (×0.50) |
|---------|-----------|-------------|
| SWORD 印记 | 100 | 50 |
| SWORD + GOLD III | 100 + 120 = 220 | 110 |
| SWORD + GOLD II | 100 + 120 + 100 = 320 | 160 |
| COIN + RUBY I | 100 + 120 + 100 + 200 = 520 | 260 |
| HAMMER + DIAMOND I | 300 + 200 + 100 + 200 = 800 | 400 |

### States and Transitions

```
[SHOP_ENTER]
    │ on_shop_enter(opponent_number): 生成随机库存, 显示商店
    ▼
[BROWSE]
    │ 显示固定服务 + 随机商品
    │
    ├─► 选择固定服务 ──► [SERVICE_SELECT]
    ├─► 选择随机商品 ──► [SERVICE_SELECT]
    ├─► 刷新(若未用) ──► 重新生成随机库存, 留在 BROWSE
    └─► 离开商店 ──► [SHOP_EXIT]

[SERVICE_SELECT]
    │ 玩家选择目标卡牌/参数
    │ 验证：余额、花色限制、前提条件
    │
    ├─► 验证通过 ──► [CONFIRM]
    └─► 验证失败 ──► 显示错误, 回到 BROWSE

[CONFIRM]
    │ 显示价格、效果预览、确认按钮
    │
    ├─► 确认 ──► spend_chips() → 写入 CardInstance → 回到 BROWSE
    └─► 取消 ──► 回到 BROWSE

[SHOP_EXIT]
    │ 清理, 返回游戏流程(下一对手)
    ▼
[返回回合管理]
```

**状态不变量：**
- BROWSE 是唯一空闲状态，所有交易完成后返回 BROWSE
- 无跨商店访问的状态持久化
- 刷新标记（已用/未用）在每次 SHOP_ENTER 时重置

### Interactions with Other Systems

| 系统 | 商店接收 | 商店提供 | 触发时机 |
|------|---------|---------|---------|
| 卡牌数据模型 (#1) | 读取 `suit`, `rank`, `stamp`, `quality`, `quality_level`, `chip_value`, `base_buy_price` | 写入 `stamp`（印记赋予）、`quality`（赋质）、`quality_level`（提纯）；全部清空（卖卡） | 商店阶段 |
| 筹码经济系统 (#10) | `get_balance()` 余额查询、`can_afford()` 可购检查 | `spend_chips()` 购买/刷新、`add_chips()` 卖卡退款 | 每次交易 |
| 卡质系统 (#5) | 赋质价格表、提纯价格表、`is_valid_assignment()` 花色验证 | 赋质请求（写入 quality=III）、提纯请求（递增 quality_level） | 商店阶段 |
| 印记系统 (#4) | 印记价格表 | 印记赋予请求（写入 stamp） | 商店阶段 |
| 战斗状态系统 (#7) | `current_hp`, `max_hp` | HP 恢复 | 商店阶段 |
| 回合管理 (#13) | `on_shop_enter()` 触发时机、`on_shop_exit()` 完成通知 | 商店完成信号 | 对手击败后 |
| 牌桌 UI (#15) | 无 | 商店界面布局、商品显示、交易反馈 | 商店阶段 |

## Formulas

### 1. HP 恢复费用 (hp_recovery_cost)

The `hp_recovery_cost` formula is defined as:

`hp_recovery_cost = hp_amount × HP_COST_PER_POINT`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| hp_amount | h | int | [1, max_hp - current_hp] | 玩家选择恢复的 HP 数量 |
| HP_COST_PER_POINT | — | int | 5 | 每 HP 的筹码成本 |

**Output Range:** [5, 500]。Min: 1 HP = 5 筹码。Max: 从 0 恢复到满 = 100 × 5 = 500。
**示例:** 玩家 current_hp=60, max_hp=100, 选择恢复 25 HP → cost = 25 × 5 = **125 筹码**。

### 2. 印记价格 (stamp_price)

The `stamp_price` formula is defined as:

`stamp_price = lookup(stamp_type)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| stamp_type | — | 枚举 | 7 种 | 印记类型 |

| stamp_type | price |
|------------|-------|
| SWORD | 100 |
| SHIELD | 100 |
| HEART | 100 |
| COIN | 100 |
| RUNNING_SHOES | 150 |
| TURTLE | 150 |
| HAMMER | 300 |

**Output Range:** [100, 300]。固定服务与随机印记共享同一价格表。

### 3. 随机增强卡牌价格 (random_card_price)

The `random_card_price` formula is defined as:

`random_card_price = base_buy_price + floor(enhancement_price × RANDOM_DISCOUNT_RATIO)`

每件随机增强卡牌恰好包含一种增强（印记或卡质，不叠加）。

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| base_buy_price | P_b | int | [10, 85] | 卡牌原型的 `chip_value + spade_face_bonus`（来自卡牌数据模型） |
| enhancement_price | P_e | int | [40, 300] | 增强服务价格（印记价格或赋质价格） |
| RANDOM_DISCOUNT_RATIO | — | float | 0.50 | 随机商品增强部分的折扣率 |

**Output Range:** [30, 235]。Min: Clubs 2 + COPPER = 10 + floor(40×0.50) = 30。Max: Spades A + HAMMER = 85 + floor(300×0.50) = 235。

**示例:**
- 草花 K + COIN：65 + floor(100 × 0.50) = 65 + 50 = **115**
- 黑桃 A + DIAMOND：85 + floor(200 × 0.50) = 85 + 100 = **185**
- 方片 2 + SWORD：10 + floor(100 × 0.50) = 10 + 50 = **60**

### 4. 卖卡退款 (sell_refund)

The `sell_refund` formula is defined as:

`sell_refund = floor(total_investment × SELL_PRICE_RATIO)`

`total_investment` = 该卡牌上当前所有增强的总投入（印记购买价 + 赋质购买价 + 累计提纯费用）。基础卡牌本身无购买成本（初始 52 张牌为免费获得），不计入 total_investment。

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| total_investment | I_t | int | [0, 800] | 印记成本 + 赋质成本 + 提纯成本之和 |
| SELL_PRICE_RATIO | — | float | 0.50 | 退款比率（来自卡牌数据模型，已注册常量） |

**Output Range:** [0, 400]。仅增强卡牌可卖。Min: 单一 SWORD = floor(100×0.50) = 50。Max: HAMMER+DIAMOND I = floor((300+200+100+200)×0.50) = floor(800×0.50) = 400。

**示例:** SWORD + RUBY II：floor((100 + 120 + 100) × 0.50) = floor(320 × 0.50) = **160**。

**与筹码经济 sell_price 公式的关系：** 本公式是筹码经济 GDD 中 `sell_price = floor(buy_price × sell_price_ratio)` 的具体实现。筹码经济 GDD 第 199 行注明"buy_price 使用带溢价的实际买入价（由商店系统提供）"——本公式定义了 `buy_price` 即 `total_investment`。

### 5. 刷新费用 (refresh_cost)

The `refresh_cost` formula is defined as:

`refresh_cost = REFRESH_COST`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| REFRESH_COST | — | int | 20 | 每次商店访问仅允许刷新 1 次 |

**Output Range:** 20（常量）。每次 SHOP_ENTER 重置刷新计数。

## Edge Cases

- **If 玩家余额为 0 且商店无可购买商品**: 所有购买被 `can_afford()` 拒绝。卖卡是唯一的筹码来源（如果有增强卡牌）。如果所有卡牌都无增强，玩家只能离开商店，依赖下回合的后手补偿或胜利奖励恢复经济。

- **If 玩家 HP 已满**: HP 恢复服务灰显。其他服务正常可用。

- **If 卖卡退款将余额推超上限（999）**: `add_chips()` 钳制到 999，溢出部分永久丢弃。

- **If 随机增强卡牌生成选择了已有同类型品质的卡牌（等级不同）**: 灰显并标注"已拥有同类品质"。购买此商品需要确认操作。

- **If 随机增强卡牌的品质违反花色限制（如 RUBY 选到了红桃牌）**: 品质生成失败，重新抽取品质（保留卡牌选择），最多重试 10 次。若仍无法匹配，降级为 COPPER（任何花色均有效）。

- **If 玩家在同一商店访问内先购买后卖卡**: 合法。`total_investment` 始终反映卡牌当前增强状态。在同一访问内购买后卖卡净损失 50%，是犹豫的代价。

- **If 购买后随机商品状态过时**: 随机商品在 SHOP_ENTER 和刷新时生成，购买不触发生成。购买时重新检查目标卡牌——若已拥有相同增强，按"已拥有"规则灰显或拒绝。

- **If 两个随机印记抽到同种类型**: 两次抽取为无放回抽样——第一件抽取后，第二件从剩余 6 种中按权重重归一化抽取。保证 2 个印记不重复。

- **If 所有 4 件随机商品均不可购买（已拥有或买不起）**: 无特殊处理。玩家仍可使用固定服务、卖卡、或直接离开。刷新可能改善但不保证。

- **If 赋质覆盖已有品质**: 需要确认操作。确认后旧品质永久丢失，不可恢复。

- **If 提纯目标品质等级为 I（已满级）**: 提纯选项灰显。不可购买。

- **If `spend_chips()` 成功但卡牌属性写入失败**: 所有前提条件在调用 `spend_chips()` 前验证。`spend_chips()` 是最后一步。若因编程错误导致写入失败，记录错误日志并回滚筹码。

- **If 宝石质在战斗中被摧毁，进入商店时品质为 null**: stamp 保留。卖卡退款仅计算 stamp 投资。玩家可重新赋质或卖卡。

- **If 玩家首次商店访问筹码有限（~175 筹码）**: 设计意图——早期资源紧张，无法负担 HAMMER 和 DIAMOND。调参点 `initial_chips` 和 `victory_base` 控制早期购买力。

- **If 玩家不购买任何东西直接离开**: 始终允许。随机库存丢弃，刷新标记重置。

- **If 购买将余额降至 0**: 商店显示确认提示。确认后余额归零，下回合依赖战斗收入。

- **买卖套利不可能**: 随机卡牌价格包含 `base_buy_price`，卖卡退款仅基于 `total_investment`。`base_buy_price` 部分在卖卡时永久损失。无套利路径。

## Dependencies

**上游依赖（本系统依赖）:**

| 系统 | 依赖类型 | 接口 | GDD 状态 |
|------|---------|------|---------|
| 卡牌数据模型 (#1) | 硬 | 读取 `suit`, `rank`, `chip_value`, `base_buy_price`, `stamp`, `quality`, `quality_level`；写入 `stamp`, `quality`, `quality_level` | 已设计 |
| 印记系统 (#4) | 硬 | 读取印记价格表；写入 `stamp`（印记赋予） | 已设计 |
| 卡质系统 (#5) | 硬 | 读取赋质价格表、提纯价格表；调用 `is_valid_assignment()`；写入 `quality`, `quality_level` | 已设计 |
| 战斗状态系统 (#7) | 硬 | 读取 `current_hp`, `max_hp`（HP 恢复上限） | 已设计 |
| 筹码经济系统 (#10) | 硬 | `spend_chips()` 购买/刷新、`add_chips()` 卖卡退款、`get_balance()` 余额查询、`can_afford()` 可购检查 | 已设计 |

**下游依赖（被依赖）:**

| 系统 | 依赖类型 | 接口 | GDD 状态 |
|------|---------|------|---------|
| 回合管理 (#13) | 硬 | 商店触发时机（`on_shop_enter` / `on_shop_exit`） | 已设计 |
| 牌桌 UI (#15) | 硬 | 商店界面布局、商品显示、交易反馈 | 已设计 |

**双向依赖验证:**

| 系统 | 本文档列出 | 对方文档列出本系统 | 状态 |
|------|-----------|-------------------|------|
| 卡牌数据模型 | 上游硬依赖 | ✓ 下游（商店读写 stamp/quality/quality_level） | 一致 |
| 印记系统 | 上游硬依赖 | ✓ 下游（商店写入 stamp） | 一致 |
| 卡质系统 | 上游硬依赖 | ✓ 下游（商店赋质和提纯请求） | 一致 |
| 战斗状态系统 | 上游硬依赖 | ✓ 下游（商店 HP 恢复） | 一致 |
| 筹码经济系统 | 上游硬依赖 | ✓ 下游（商店 spend_chips/add_chips） | 一致 |
| 回合管理 | 下游硬依赖 | ✓ 上游（商店触发时机） | 一致 |
| 牌桌 UI | 下游硬依赖 | ✓ 上游（商店界面） | 一致 |

## Tuning Knobs

| 调参点 | 类型 | 默认值 | 安全范围 | 影响什么 |
|--------|------|--------|----------|---------|
| `hp_cost_per_point` | int | 5 | 1–20 | 每 HP 恢复成本。调高使回血成为重投资，调低降低生存压力 |
| `stamp_price_sword` | int | 100 | 50–200 | 短剑价格。调高抑制攻击型构筑，调低鼓励早期进攻投资 |
| `stamp_price_shield` | int | 100 | 50–200 | 护盾价格。应与 SWORD 保持相同值以维持攻防平衡 |
| `stamp_price_heart` | int | 100 | 50–200 | 心价格。调高使续航更昂贵，调低降低生存门槛 |
| `stamp_price_coin` | int | 100 | 50–200 | 钱币价格。调高抑制经济型构筑速度，调低加速经济飞轮 |
| `stamp_price_running_shoes` | int | 150 | 80–300 | 跑鞋价格。战术型印记，价格应高于战斗印记以反映其情景依赖性 |
| `stamp_price_turtle` | int | 150 | 80–300 | 乌龟价格。应与跑鞋保持相同值 |
| `stamp_price_hammer` | int | 300 | 150–500 | 重锤价格。最贵印记，调高使其成为中后期大投资，调低增加对抗性 |
| `refresh_cost` | int | 20 | 0–100 | 刷新费用。调高抑制刷新冲动，调低鼓励探索。0 = 免费刷新 |
| `random_discount_ratio` | float | 0.50 | 0.25–0.75 | 随机商品增强部分的折扣率。调高使随机商品更贵（接近原价），调低增加随机商品吸引力 |
| `shop_stamp_weight_[TYPE]` | int | 各 1–25 | 0–100 | 各印记在随机池中的权重。设为 0 则完全排除该印记 |
| `shop_quality_weight_[TYPE]` | int | 各 5–25 | 0–100 | 各卡质在随机池中的权重。DIAMOND 默认 5 以保持稀缺性 |
| `random_stamp_to_card_ratio` | float | 0.40 | 0.0–1.0 | 随机增强卡牌选择印记的概率。0.60 为卡质。调高增加印记出现率 |

**依赖系统的调参点（本系统消费但不拥有）:**

| 调参点 | 来源 | 本系统如何消费 |
|--------|------|--------------|
| `initial_chips` | 筹码经济 | 决定首次商店的购买力 |
| `chip_cap` | 筹码经济 | 卖卡退款的上限钳制 |
| `victory_base` / `victory_scale` | 筹码经济 | 每次商店访问的可用筹码量 |
| `sell_price_ratio` | 卡牌数据模型 | 卖卡退款比率 |
| `player_max_hp` | 战斗状态 | HP 恢复上限 |
| `assignment_cost` (各品质) | 卡质系统 | 赋质定价 |
| `purification_cost` | 卡质系统 | 提纯定价 |
| `spade_face_bonus` | 卡牌数据模型 | 黑桃面牌的基础价加成 |

## Visual/Audio Requirements

**视觉反馈:**
- 购买成功：商品卡片播放闪光动画 + 筹码数字从计数器飘向商品（支出）或从商品飘向计数器（卖卡退款），动画时长 ≤ 0.5 秒
- 余额不足：商品卡片轻微抖动 + 价格文字闪红色
- 赋质/印记应用：目标卡牌播放对应增强图标浮现动画
- 卖卡：卡牌上的增强图标逐个碎裂消散
- 刷新：4 件随机商品同时翻面替换（旧商品翻出，新商品翻入）
- 商品可购状态：可购 = 金色边框，不可购 = 暗红边框 + 灰显购买按钮

**音频反馈:**
- 购买成功：清脆收银声（`shop_buy.wav`）
- 卖卡：沉闷金属声（`shop_sell.wav`）
- 刷新：翻牌声（`shop_refresh.wav`）
- 余额不足：短促错误音（`shop_error.wav`）
- 进入商店：轻快开门声（`shop_enter.wav`）

## UI Requirements

- **商店界面布局**: 全屏覆盖牌桌，顶部显示筹码余额，左侧固定服务面板，右侧随机商品面板，底部玩家牌组预览（可滚动）
- **固定服务面板**: 列出 HP 恢复、7 种印记、8 种卡质、提纯、卖卡。每项显示图标 + 价格。可购状态实时反映余额
- **随机商品面板**: 2 张印记卡 + 2 张增强卡，每张显示：卡牌/印记图标、增强内容、价格、可购状态。刷新按钮位于面板底部
- **HP 恢复滑块**: 拖拽选择恢复量，实时显示花费和恢复后 HP。最大值 = max_hp - current_hp
- **卡牌选择**: 购买印记/赋质/提纯时，显示玩家牌组的卡片网格。可应用目标高亮，不可应用目标灰显
- **确认对话框**: 赋质覆盖、余额归零等操作弹出确认
- **牌组查看器**: 可随时展开查看完整牌组，显示每张牌的 stamp + quality + quality_level

> **📌 UX Flag — 商店系统**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the shop screen before writing epics. Stories that reference shop UI should cite `design/ux/shop.md`, not the GDD directly.

## Acceptance Criteria

**核心规则验证:**

- **AC-1 52 张不变量**: 商店进入和退出时，玩家牌组始终为 52 张卡牌实例，无创建或销毁。商店仅修改 `stamp`、`quality`、`quality_level` 三个字段。
- **AC-2 触发时机**: 击败对手 1-7 后各触发一次商店（共 7 次）。击败对手 8 后不触发商店，直接进入胜利流程。
- **AC-3 库存结构**: 每次商店访问显示固定服务（HP 恢复、7 印记、8 卡质、提纯、卖卡）和 4 件随机商品（2 印记 + 2 增强卡牌）。固定服务购买次数无上限（受余额限制）。
- **AC-4 HP 恢复**: 恢复 N HP 花费 N×5 筹码。上限为 `max_hp - current_hp`。HP 已满时服务灰显。AI 无 HP 恢复。
- **AC-5 印记赋予**: 7 种印记价格正确（SWORD/SHIELD/HEART/COIN=100, RUN/TURTLE=150, HAMMER=300）。任何印记可赋予任何花色。覆盖时需确认，旧印记永久丢失。
- **AC-6 赋质**: 8 种卡质价格正确（COPPER=40, SILVER=80, GOLD=120, 宝石=120, DIAMOND=200）。新赋质从 III 级开始。宝石质必须通过花色限制验证。覆盖时需确认。
- **AC-7 提纯**: III→II=100, II→I=200。前提条件：`quality != null` 且 `quality_level != I`。被摧毁卡牌和已满级卡牌的提纯灰显。每次恰好升一级。
- **AC-8 卖卡**: 退款 = `floor(total_investment × 0.50)`。卖卡后 `stamp = null`, `quality = null`, `quality_level = III`，卡牌仍在牌组。无增强卡牌灰显不可卖。`total_investment` 从卡牌当前属性反推：当前印记价 + 当前赋质价 + 当前 quality_level 对应的累计提纯费。
- **AC-9 随机商品生成**: 随机印记无放回抽取（2 件不重复）。随机增强卡牌每件恰好一种增强（印记 40% / 卡质 60%）。卡质违反花色限制时重抽最多 10 次，仍不匹配则降级为 COPPER。已有完全相同增强的随机商品灰显标注"已拥有"。
- **AC-10 随机卡牌定价**: `base_buy_price + floor(enhancement_price × 0.50)` 使用 `floor` 向下取整。三个示例值正确：草花 K+COIN=115, 黑桃 A+DIAMOND=185, 方片 2+SWORD=60。价格范围 [30, 235]。
- **AC-11 刷新**: 每次商店访问最多刷新 1 次，费用 20 筹码。刷新重新生成全部 4 件随机商品。固定服务不受影响。已刷新后按钮灰显。
- **AC-12 交易原子性**: 先扣款后执行——`spend_chips()` 成功后才修改卡牌属性。余额不足时不修改任何属性，无部分状态。每笔交易独立，无购物车。金额为 0 的交易为空操作。

**公式验证:**

- **AC-F1 HP 恢复费用**: `hp_amount × 5` 线性计算正确。输出范围 [5, 500]。
- **AC-F2 印记价格**: 查表与价格表完全一致。固定服务与随机商品共享价格表。
- **AC-F3 随机卡牌价格**: `floor` 取整正确（非四舍五入）。`base_buy_price` 范围 [10, 85] 与卡牌数据模型一致。
- **AC-F4 卖卡退款**: `total_investment = 0` 时退款为 0。`total_investment = 800` 时退款为 400。示例 SWORD+RUBY II=160 正确。退款后 `add_chips()` 钳制到 999。
- **AC-F5 刷新费用**: 固定 20。每次 SHOP_ENTER 重置刷新计数。

**边缘情况验证:**

- **AC-E1 零余额**: 余额为 0 时所有购买被 `can_afford()` 拒绝。卖卡是唯一筹码来源（若有增强卡牌）。无增强卡牌时唯一操作是离开商店。
- **AC-E2 套利不可能**: 对任意增强组合，`sell_refund < total_investment` 恒成立。`random_card_price` 包含 `base_buy_price` 而卖卡退款不包含，无套利路径。
- **AC-E3 覆盖后卖卡**: 卡牌先赋 GOLD(120) 再覆盖为 SILVER(80)，卖卡时 `total_investment` 仅计算当前品质（SILVER=80 + 印记价 + 提纯费），不含被覆盖的历史投入。
- **AC-E4 先买后卖（同次访问）**: 合法。在同一商店访问内购买后卖卡，净损失 50% 为预期行为。
- **AC-E5 退款溢出**: 卖卡退款将余额推超 999 时，`add_chips()` 钳制到 999，溢出部分永久丢弃。
- **AC-E6 随机商品状态过时**: 购买时不触发重新生成。确认提交时实时检查目标卡牌状态，若已拥有相同增强则拒绝交易。
- **AC-E7 宝石质摧毁后进入商店**: stamp 保留。卖卡退款仅计算 stamp 投资。玩家可重新赋质或卖卡。
- **AC-E8 不购买直接离开**: 始终允许。卡牌和筹码状态无变化。刷新标记重置。
- **AC-E9 扣款成功但写入失败**: 记录错误日志并回滚筹码。卡牌属性不变。

**状态机验证:**

- **AC-S1 进入商店**: SHOP_ENTER 后随机库存生成完毕，刷新标记为未用，状态为 BROWSE。
- **AC-S2 验证失败路径**: SERVICE_SELECT 验证失败（余额不足、花色不匹配、前提不满足）时，显示错误信息回到 BROWSE，无状态修改。
- **AC-S3 交易成功路径**: CONFIRM → `spend_chips()` 成功 → 写入卡牌属性 → 回到 BROWSE，余额和卡牌状态已更新。
- **AC-S4 交易失败路径**: CONFIRM → `spend_chips()` 失败 → 不写入属性 → 回到 BROWSE，显示错误。
- **AC-S5 取消交易**: CONFIRM 取消 → 无扣款无属性修改 → 回到 BROWSE。
- **AC-S6 状态不变量**: 每次交易完成后状态必然回到 BROWSE。无跨商店访问的状态持久化。刷新标记在每次 SHOP_ENTER 时重置。

**集成验证:**

- **AC-I1 筹码经济交互**: 所有 `spend_chips()` 和 `add_chips()` 调用正确传递金额和原因标签（`SHOP_PURCHASE` / `SHOP_SELL`）。
- **AC-I2 卡牌数据模型交互**: 所有属性写入（`stamp`, `quality`, `quality_level`）与卡牌数据模型 GDD 定义的字段类型一致。
- **AC-I3 回合管理交互**: `on_shop_exit()` 信号在 SHOP_EXIT 时正确发出，回合管理可接收并继续流程。

## Open Questions

- [ ] **早期经济压力是否过紧** — 对手 1 后首次商店仅 ~175 筹码，无法负担 HAMMER（300）和 DIAMOND（200）。这是否限制了早期构筑多样性？需 playtest 验证。负责人：game designer，目标：Alpha 阶段前。
- [ ] **随机商品增强折扣率（0.50）是否合适** — 如果随机商品太便宜，玩家会等刷新而不是用固定服务。如果太贵，随机商品失去吸引力。需 playtest 验证。负责人：economy designer，目标：Alpha 阶段前。
- [ ] **卖卡退款是否应包含 base_buy_price** — 当前设计退款仅基于增强投资，不含基础牌价。这是否使卖卡吸引力不足？如果包含 base_buy_price，是否引入套利风险？负责人：economy designer + game designer，目标：Alpha 阶段前。
- [ ] **商店是否需要对手间缩放** — 当前定价固定，不随对手序号变化。后期收入自然增加（胜利奖励递增），但物价不变。是否需要在后期引入新商品或价格调整？负责人：game designer，目标：对局进度系统设计时协调。
- [ ] **刷新是否应限制为 1 次** — 当前设计每次访问仅允许 1 次刷新。这是否过于限制？如果放开，是否需要递增成本（20/40/60）？负责人：game designer，目标：playtest 后决策。
