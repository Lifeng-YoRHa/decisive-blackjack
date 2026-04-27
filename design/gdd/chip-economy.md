# 筹码经济系统 (Chip Economy System)

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-24
> **Implements Pillar**: Economy — chip income, expenditure, balance, and progression pacing

## Overview

筹码经济系统是《决胜21点》的资源中枢——它追踪玩家的筹码余额，管理筹码的获得（草花卡牌结算产出、边池回报、卖卡退款）和消耗（商店购买、保险、边池下注），并为所有需要筹码操作的系统提供统一的余额查询和交易接口。在数据层面，它是连接结算引擎（Phase 5 产出筹码流）和商店系统（消耗筹码）的核心中介：结算引擎调用 `add_chips()` 注入收入，商店系统调用 `spend_chips()` 扣除支出，筹码经济系统保证余额不为负、记录每笔交易、在达到上限时发出警告。在玩家体验层面，筹码是你每次决策的代价标签——是买一张带印记的草花 K 来增加未来收入，还是花 120 筹码赋予黑桃 A 黑曜石质来提升防御？是省着筹码等刷新出更好的商品，还是现在就投资？筹码经济系统的设计目标不是让玩家"算账"，而是让每次购买都感觉像是一个有意义的取舍：资源有限，欲望无限，选择即策略。这个系统为商店、边池、保险和回合管理提供定价依据和经济平衡基础，确保游戏从第一回合到最终胜利始终保持着资源紧张感。

## Player Fantasy

**赌场庄家 — 庄家永远不亏，因为庄家精算在先**

核心时刻：商店界面，你的余额显示 412 筹码。你需要给黑桃 A 加护盾印记（150 筹码），也想升级那张祖母绿 III→II（100 筹码），同时随机栏里有一张带钱币印记的草花 K（97 筹码）。你能买两项，但不能全买。投资经济（祖母绿 + 草花 K），下回合收入更高但防御更弱；投资防御（护盾 + 祖母绿），活得更久但赚钱更慢。你不是在买卡——你在对策略下注。

筹码经济系统的玩家幻想是**投资回报感**——不是"我有多少钱"的满足，而是"我的钱在工作"的掌控。筹码不是运气给的，是你通过构建收入引擎赢来的：更多草花、更多金属质、更多钱币印记。每次商店访问是投资组合再平衡——固定资产（金属质，稳定回报）还是衍生品（宝石质，高风险高回报）。当你的收入引擎开始自我维持——这回合赚的筹码足以支付下回合的升级——你已经从赌徒变成了庄家。这个幻想衔接了结算引擎的"连锁裁决"——结算引擎说"你的编排正在一步步兑现"，筹码经济说"兑现的收益正在被你重新投资，变成下一回合的更强引擎"。

## Detailed Design

### Core Rules

**1. 系统性质**

筹码经济系统是一个资源管理单例——它追踪玩家的筹码余额，验证所有筹码交易（收入和支出），保证余额在 [0, 999] 范围内，并记录交易日志供 UI 显示。系统不计算 `chip_output`（由结算引擎根据已注册公式计算），只接收并存储结果。

**2. 初始筹码**

新游戏开始时，玩家筹码余额 = 100。AI 无筹码经济——`add_chips(AI, amount)` 为空操作，不追踪不报错。

**3. 筹码上限**

余额上限 = 999。`add_chips()` 超过上限时，余额钳制为 999，溢出部分丢弃。不转化为其他资源。

**4. 筹码收入来源**

| 来源 | 触发时机 | 金额 | 调用方式 |
|------|---------|------|---------|
| 草花卡牌结算 | 结算引擎 Phase 5 | `chip_output` 公式产出 | `add_chips(PLAYER, amount, RESOLUTION)` |
| 结算先手掷币补偿 | 结算先手决定掷币时（对手先手） | 20 | `add_chips(PLAYER, 20, SETTLEMENT_TIE_COMP)` |
| 边池回报 | 边池结算时 | 按边池规则 | `add_chips(PLAYER, amount, SIDE_POOL_RETURN)` |
| 卖卡退款 | 商店阶段 | 买入价 × 0.50 | `add_chips(PLAYER, amount, SHOP_SELL)` |
| 击败对手奖励 | 对手被击败时 | 50 + 25 × opponent_number | `add_chips(PLAYER, amount, VICTORY_BONUS)` |
| 保险返还 | 保险触发时（对手确为杰克/黑杰克） | 返还保险消耗 | `add_chips(PLAYER, 30, INSURANCE_REFUND)` |

**5. 筹码消耗去向**

| 去向 | 触发时机 | 金额 | 调用方式 |
|------|---------|------|---------|
| 商店购买 | 商店阶段 | 按商店定价表 | `spend_chips(PLAYER, cost, SHOP_PURCHASE)` |
| 边池下注 | 发牌前 | 10 / 20 / 50（三档） | `spend_chips(PLAYER, bet, SIDE_POOL_BET)` |
| 保险购买 | 回合中，对手明牌为 A | 30 | `spend_chips(PLAYER, 30, INSURANCE)` |

**6. 跨对手持久性**

筹码在 8 个对手的整个游戏过程中累积。击败对手后进入商店，购买完成后筹码余额带入下一对手。不存在对手间的重置机制。

**7. 交易规则**

- **非负性**：`spend_chips()` 在余额不足时拒绝交易，返回失败结果。余额永远不会为负。
- **上限钳制**：`add_chips()` 将余额钳制在 999。返回实际增加量（可能小于请求量）。
- **零值交易**：金额为 0 的 `add_chips()` 或 `spend_chips()` 为空操作，不记录日志。
- **收入/支出校验**：所有金额必须为正整数。拒绝负值和浮点值。

**8. 无最低收入保证**

系统不提供回合最低收入保证。零收入是可能的结果——玩家未持有草花、未持金属质、未持钱币印记且未爆牌时，回合筹码收入为 0。这是"赌场庄家"幻想的一部分：经济引擎需要主动构建。

### States and Transitions

```
[游戏开始]
    │ reset_for_new_game(): balance = 100, log = []
    ▼
[对手 N 开始]
    │
    ├─► [回合 M 开始]
    │       ├─► [边池下注] ── spend_chips() ──► balance -= bet
    │       ├─► [保险决策] ── spend_chips(30) 或跳过
    │       ├─► [发牌 + 要牌/停牌]
    │       ├─► [结算引擎 Phase 5] ── add_chips() per card ──► balance += chip_output
    │       ├─► [边池结算] ── add_chips() or 无
    │       │
    │       ├─► [回合结果]
    │       │   ├─ CONTINUE → 下一回合
    │       │   ├─ PLAYER_WIN → on_opponent_defeated(N) → +victory_bonus → [商店]
    │       │   └─ PLAYER_LOSE → [游戏结束]
    │       ▼
    │   (循环至一方倒下)
    │
    ▼
[商店阶段]
    │ on_shop_enter()
    │ ├─ can_afford() 检查每件商品
    │ ├─ spend_chips() 购买
    │ ├─ add_chips(SHOP_SELL) 卖卡
    ▼
[下一对手] → 回到 [对手 N+1 开始]
    │
    ▼ (击败对手 8 后)
[胜利]
```

### Interactions with Other Systems

| 系统 | 筹码经济接收 | 筹码经济提供 | 触发时机 |
|------|-------------|-------------|---------|
| 结算引擎 (#6) | 无 | `add_chips(owner, amount)` 接收每卡筹码产出 | Phase 5 |
| 卡牌数据模型 (#1) | 无（间接通过结算引擎） | 无 | N/A |
| 回合管理 (#13) | `round_number`, `opponent_number` | `get_balance()` 余额查询 | 回合结束 |
| 商店系统 (#11) | `spend_chips()` 购买请求；`add_chips()` 卖卡退款 | `can_afford()`, `get_balance()` 可购查询 | 商店阶段 |
| 边池系统 (#9) | 下注金额 (10/20/50)；边池回报 | 余额校验 | 发牌前/边池结算 |
| 特殊玩法系统 (#8) | 保险消耗 (30)；保险返还 (30) | `can_afford()` 保险可购检查 | 保险决策 |
| 对局进度系统 (#14) | `opponent_number` 击败通知 | 无 | 对手击败时 |
| 牌桌 UI (#15) | 无 | `get_balance()`, `get_transaction_log()` 显示 | 实时 |

**关键依赖链**: 结算引擎使用已注册的 `chip_output` 公式计算每卡筹码产出 → 调用 `add_chips()` → 筹码经济系统存储结果。筹码经济系统本身不执行任何公式计算。

## Formulas

### 1. 初始余额 (initial_balance)

The `initial_balance` formula is defined as:

`initial_balance = INITIAL_CHIPS`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| INITIAL_CHIPS | — | int | 100 | 新游戏起始筹码 |

**Output Range:** 100（常量）
**示例:** 新游戏开始，余额设为 100。

### 2. 筹码上限 (chip_cap)

The `chip_cap` formula is defined as:

`chip_cap = CHIP_CAP`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| CHIP_CAP | — | int | 999 | 余额硬上限 |

**Output Range:** 999（常量）
**示例:** 余额 980，`add_chips(PLAYER, 50)` → 980+50=1030 钳制为 999。实际增加 19，溢出 31 丢弃。

### 3. 击败对手奖励 (victory_bonus)

The `victory_bonus` formula is defined as:

`victory_bonus = VICTORY_BASE + VICTORY_SCALE × opponent_number`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| VICTORY_BASE | — | int | 50 | 击败任意对手的基础奖励 |
| VICTORY_SCALE | — | int | 25 | 每递增一位对手的额外奖励 |
| opponent_number | n | int | [1, 8] | 被击败的对手编号（1-indexed） |

**Output Range:** 75 到 250（线性整数）。Min: 50+25×1=75（对手 1）。Max: 50+25×8=250（对手 8）。
**示例:** 击败对手 3 → `victory_bonus = 50 + 25×3 = 125`。`add_chips(PLAYER, 125, VICTORY_BONUS)`。

### 4. 卖卡价格 (sell_price)

The `sell_price` formula is defined as:

`sell_price = floor(buy_price × sell_price_ratio)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| buy_price | p | int | [0, 800] | `total_investment`（来自商店系统 = 印记成本 + 赋质成本 + 提纯成本） |
| sell_price_ratio | r | float | 0.50 | 退款比率（来自 card-data-model，已注册常量） |

**Output Range:** 0 到 400（整数，向下取整）。Min: floor(0×0.50)=0（无增强卡牌）。Max: floor(800×0.50)=400（完全增强卡牌）。
**取整规则:** Floor（向零截断）。防止买卖同价的 1 筹码套利漏洞。
**示例:** 卖出 SWORD+RUBY II 卡牌。`total_investment`=160（印记 60 + 赋质 100）。`sell_price=floor(160×0.50)=80`。获得 80 筹码。

**注:** `buy_price` = `total_investment`（由商店系统的 `sell_refund` 公式定义）。基础卡牌本身无购买成本（初始 52 张免费），仅增强投入计入。详见 `design/gdd/shop-system.md` 公式 #4。

### 5. 保险费 (insurance_cost)

The `insurance_cost` formula is defined as:

`insurance_cost = INSURANCE_CHIP_COST`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| INSURANCE_CHIP_COST | — | int | 30 | 筹码支付的保险费用 |

**Output Range:** 30（常量）
**示例:** 玩家选择筹码支付保险 → `spend_chips(PLAYER, 30, INSURANCE)`。

**注:** 保险有替代的 HP 支付路径（6 HP），由特殊玩法系统定义。筹码经济系统仅处理筹码支付路径。

### 6. 保险返还 (insurance_refund)

The `insurance_refund` formula is defined as:

`insurance_refund = insurance_cost`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| insurance_cost | c | int | 30 | 玩家最初支付的保险费 |

**Output Range:** 30（常量）
**示例:** 保险触发（对手确为黑杰克）→ `add_chips(PLAYER, 30, INSURANCE_REFUND)`。净成本: 0。

### 7. 结算先手掷币补偿 (settlement_tie_comp)

The `settlement_tie_comp` formula is defined as:

`settlement_tie_comp = SETTLEMENT_TIE_COMP`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| SETTLEMENT_TIE_COMP | — | int | 20 | 结算先手掷币时，对手获得先手（优势），玩家获得补偿 |

**触发条件**: 结算先手决定时，比较 `point_total`（低者优先），再比较最大牌 `bj_value`。若仍平局，掷币决定。掷币输家（未获先手方）获得此补偿。
**Output Range:** 20（常量）
**示例:** 双方 `point_total` 均为 18，最大牌 `bj_value` 相同，掷币结果对手先手。玩家获得 `add_chips(PLAYER, 20, SETTLEMENT_TIE_COMP)`。

## Edge Cases

- **If 余额为 0 且本回合无任何筹码收入（无草花、无金属质、无钱币印记、先手方）**: 回合筹码收入为 0，玩家无法下注边池、购买保险。若击败对手，`victory_bonus`（最低 75）注入经济。若未击败对手，死亡螺旋只能靠下一回合的草花结算打破。这是"赌场庄家"幻想的核心压力——经济引擎需要主动构建，忽视经济的构建会面临真正的资源枯竭。

- **If 结算先手掷币补偿时余额接近上限**: `settlement_tie_comp` 固定 20，若余额 ≥ 980 则 `add_chips(PLAYER, 20, SETTLEMENT_TIE_COMP)` 钳制至 999。补偿不受余额影响，掷币输家始终获得 20（或实际可增加量）。

- **If 余额达到 999 上限时结算引擎产出筹码**: `add_chips()` 钳制余额为 999，溢出部分永久丢弃。交易日志记录实际增加量而非请求量。UI 需在此时显示明确的溢出提示（如"筹码已满，294→4"），防止玩家困惑。

- **If 即时胜利（SPADE_BLACKJACK）跳过全部结算**: Phase 0a→即时胜利，Phase 0b-6 全部跳过。所有草花卡牌不结算，`chip_output` 为 0，`add_chips()` 不被调用。玩家仅依赖 `victory_bonus`（75-250）。即时胜利以牺牲经济收入换取确定胜利——这是一个有意义的战略取舍。

- **If 爆牌导致本回合零筹码收入**: 爆牌方所有卡牌标记为"爆牌无效"，Phase 1-6 全部跳过。草花、金属质、钱币印记的 `chip_output` 全部为 0。爆牌承受双重惩罚：HP 自伤 + 经济零收入。

- **If 保险返还时余额已达上限**: 保险返还是普通的 `add_chips()` 调用，受上限钳制。若余额为 990→保险 30 返还→1020 钳制为 999，实际返还 9 而非 30。玩家在高余额时购买保险经济上更差——这是上限系统的自然后果，不是缺陷。

- **If 边池下注后输掉边池，进入商店时筹码不足**: 边池下注是纯消耗——下注时 `spend_chips()` 立即扣款。若输掉边池，筹码不返还。最高下注 50 筹码（约初始余额的 50%），损失可能影响商店购买力。边池是高风险投资，需 playtest 验证风险/回报比。

- **If 卖卡价格因 Floor 取整产生 1 筹码偏差**: `sell_price = floor(buy_price × 0.50)`。当 `buy_price` 为奇数时（如 75），`sell_price = floor(37.5) = 37`（损失 38，非严格 50%）。Floor 取整保证 `sell_price < buy_price` 永远成立，防止买卖套利。

- **If `add_chips()` 和 `spend_chips()` 在同一帧被调用**: GDScript 单线程保证不会并发。当前状态机保证收入（结算阶段）和支出（商店阶段）不会重叠。若未来系统引入战斗内支出机制，需在 API 文档中明确：这两个方法是顺序执行，不支持原子事务。

- **If `spend_chips()` 在 `can_afford()` 检查后失败**: 商店系统必须使用"先扣款后发卡"模式——先调用 `spend_chips()`，成功后才修改卡牌实例属性。若 `spend_chips()` 返回失败，商店不执行任何物品变更。不存在部分状态。

- **If 草花卡牌的 `chip_output` 因被重锤无效化而为 0**: 被无效化的草花卡牌跳过 Phase 1-6，不产出筹码。这是重锤的战略价值之一——不仅无效化战斗效果，还切断经济产出。

## Dependencies

**上游依赖（本系统依赖）:**

| 系统 | 依赖类型 | 接口 | GDD 状态 |
|------|---------|------|---------|
| 卡牌数据模型 (#1) | 硬 | 读取 `chip_value`, `base_buy_price`, `sell_price_ratio` | 已完成 |
| 结算引擎 (#6) | 硬 | `add_chips(owner, amount)` — Phase 5 筹码派发 | 已完成 |

**下游依赖（被依赖）:**

| 系统 | 依赖类型 | 接口 | GDD 状态 |
|------|---------|------|---------|
| 边池系统 (#9) | 硬 | `spend_chips()` 下注 + `add_chips()` 回报 | 已设计 |
| 商店系统 (#11) | 硬 | `spend_chips()` 购买 + `add_chips()` 卖卡退款 + `can_afford()` | 未设计 |
| 特殊玩法系统 (#8) | 软 | `spend_chips(30)` 保险 + `add_chips(30)` 保险返还 | 已设计 |
| 回合管理 (#13) | 硬 | `on_opponent_defeated()` 胜利奖励 | 已完成 |
| 对局进度系统 (#14) | 软 | `on_opponent_defeated()` 触发时机 | 未设计 |
| 牌桌 UI (#15) | 软 | `get_balance()` 余额显示 + `get_transaction_log()` 交易历史 | 未设计 |

**双向依赖验证:**

| 系统 | 本文档列出 | 对方文档是否列出本系统 | 状态 |
|------|-----------|---------------------|------|
| 卡牌数据模型 | 上游硬依赖 | ✓ 下游（筹码经济读取 chip_value） | 一致 |
| 结算引擎 | 上游硬依赖 | ✓ 下游（Phase 5 调用 add_chips） | 一致 |
| 边池系统 | 下游 | ✓ 上游（边池下注/回报） | 一致（金额已同步更新） |
| 商店系统 | 下游 | 未设计（待验证） | 待确认 |
| 特殊玩法系统 | 下游 | 已设计（已验证） | 一致 |
| 回合管理 | 下游 | 未设计（待验证） | 待确认 |

## Tuning Knobs

| 调参点 | 类型 | 默认值 | 安全范围 | 影响什么 |
|--------|------|--------|----------|---------|
| `initial_chips` | int | 100 | 50–500 | 新游戏起始经济压力。调低=更紧的早期选择，调高=更宽容的开局 |
| `chip_cap` | int | 999 | 500–9999 | 最大余额。调低迫使更积极的消费，调高允许囤积。999 适配三位数显示 |
| `victory_base` | int | 50 | 0–200 | 击败对手基础奖励。调低削弱纯战斗构建的经济基础，调高降低经济引擎的必要性 |
| `victory_scale` | int | 25 | 0–50 | 每递增一位对手的额外奖励。调高减少游戏后期经济压力，调低保持全程紧张 |
| `insurance_chip_cost` | int | 30 | 0–100 | 保险筹码成本。调低降低防御门槛，调高使保险成为更重的经济负担 |
| `sell_price_ratio` | float | 0.50 | 0.25–0.75 | 卖卡退款比率（由 card-data-model 拥有，本系统消费）。调低惩罚快速轮换，调高减少投资风险 |
| `settlement_tie_compensation` | int | 20 | 0–100 | 结算先手掷币补偿。调高减少先手劣势的经济影响，调低（或 0）使掷币结果纯为时序优势 |

**依赖系统的调参点（本系统消费但不拥有）:**

| 调参点 | 来源 | 本系统如何消费 |
|--------|------|--------------|
| `chip_value_lookup` | 卡牌数据模型 | 决定草花卡牌的基础筹码产出（通过结算引擎的 `chip_output` 公式） |
| `metal_chip_bonus` | 卡质系统 | 金属质筹码加成（通过结算引擎的 `chip_output` 公式） |
| `stamp_coin_bonus` | 印记系统 | 钱币印记筹码加成（通过结算引擎的 `chip_output` 公式） |
| `base_buy_price` | 卡牌数据模型 | 卖卡价格的计算基数 |

## Visual/Audio Requirements

**视觉反馈:**
- 筹码余额变化时，计数器播放数字滚动动画（收入向上翻滚，支出向下翻滚）。动画时长 ≤ 0.5 秒
- 收入事件（`add_chips`）触发金色闪光 + 上浮数字（如 "+45"）从结算卡牌飘向筹码计数器
- 支出事件（`spend_chips`）触发红色闪光 + 下沉数字（如 "-80"）从筹码计数器飘向目标
- 上限钳制时（溢出丢弃），闪光变暗灰色并显示"已满"提示
- 余额为 0 时，筹码计数器显示为暗灰色并轻微抖动（警示状态）

**音频反馈:**
- 收入：清脆硬币声（`coin_gain.wav`），音量与收入金额正相关
- 支出：沉闷金属声（`coin_spend.wav`）
- 上限钳制：短促警告音（`cap_warning.wav`）
- 余额归零：低沉鼓声（`balance_zero.wav`）
- 击败对手奖励收入：胜利金币雨声（`victory_bonus.wav`），区别于普通收入

## UI Requirements

- **筹码计数器 (HUD)**：始终可见，位于牌桌界面右上角。显示当前余额 / 上限（如"412/999"）。字体大小 ≥ 24px，支持三位数显示
- **交易提示 (HUD)**：每次余额变化时，在计数器旁显示 2 秒的浮动提示（如"+45 草花结算"、"-30 保险"），使用 `ChipSource`/`ChipPurpose` 枚举的本地化文本
- **可购高亮 (商店 UI)**：商店中每件商品旁显示价格。`can_afford()` 为 true 时价格显示为金色，false 时显示为暗红色并灰显购买按钮。由牌桌 UI 系统在商店阶段实现
- **余额归零警告 (HUD)**：余额为 0 时，筹码计数器下方显示"筹码耗尽"警告文字，持续至余额恢复

## Acceptance Criteria

### 核心规则

**AC-01: 初始余额**
GIVEN 新游戏开始
WHEN `reset_for_new_game()` 被调用
THEN `get_balance()` 返回 100，交易日志为空

**AC-02: AI 筹码操作为空操作**
GIVEN 游戏进行中，玩家余额为 200
WHEN `add_chips(AI, 500)` 被调用
THEN 玩家余额不变，无 AI 余额追踪，无日志条目

**AC-03: 上限钳制**
GIVEN 玩家余额为 980
WHEN `add_chips(PLAYER, 50, RESOLUTION)` 被调用
THEN 余额变为 999（非 1030），返回实际增加量 19

**AC-04: 六种收入来源独立生效**
GIVEN 玩家余额为 0
WHEN 依次调用 `add_chips(PLAYER, 25, RESOLUTION)` / `add_chips(PLAYER, 20, SETTLEMENT_TIE_COMP)` / `add_chips(PLAYER, 100, SIDE_POOL_RETURN)` / `add_chips(PLAYER, 37, SHOP_SELL)` / `add_chips(PLAYER, 125, VICTORY_BONUS)` / `add_chips(PLAYER, 30, INSURANCE_REFUND)`
THEN 余额累加至 337，日志包含 6 条不同来源的记录

**AC-05: 跨对手持久性**
GIVEN 击败对手 3 后余额为 250
WHEN 玩家在商店花费 80 后对手 4 开始
THEN 余额 170 带入对手 4，无重置

**AC-06: 无最低收入保证**
GIVEN 玩家无草花、无金属质、无钱币印记、先手方、未下注边池
WHEN 结算引擎完成所有阶段
THEN 回合筹码收入为 0，余额不变

### 公式

**AC-07: victory_bonus — 对手 1**
GIVEN 对手 1 被击败
WHEN `on_opponent_defeated(1)` 被调用
THEN `add_chips(PLAYER, 75, VICTORY_BONUS)` 被调用

**AC-08: victory_bonus — 对手 8**
GIVEN 对手 8 被击败
WHEN `on_opponent_defeated(8)` 被调用
THEN `add_chips(PLAYER, 250, VICTORY_BONUS)` 被调用

**AC-09: sell_price — 典型增强卡牌**
GIVEN `buy_price = 220` (SWORD 印记 100 + RUBY II 赋质 120)
WHEN 计算卖价
THEN `sell_price = floor(220 × 0.50) = 110`

**AC-10: sell_price — 奇数 total_investment (Floor 取整)**
GIVEN `buy_price = 221` (SHIELD 印记 100 + RUBY III 赋质 120 + 1 溢出)
WHEN 计算卖价
THEN `sell_price = floor(221 × 0.50) = 110`（非 111）

**AC-11: sell_price — 最小边界**
GIVEN `buy_price = 0`（无增强的卡牌）
WHEN 计算卖价
THEN `sell_price = floor(0 × 0.50) = 0`（不可卖，由商店系统灰显）

**AC-12: sell_price — 最大边界**
GIVEN `buy_price = 800`（HAMMER 印记 300 + DIAMOND I 赋质 200 + 累计提纯 300）
WHEN 计算卖价
THEN `sell_price = floor(800 × 0.50) = 400`

**AC-13: insurance_cost = 30**
GIVEN 玩家余额 ≥ 30
WHEN 玩家选择筹码支付保险
THEN `spend_chips(PLAYER, 30, INSURANCE)` 成功，余额减少 30

**AC-14: insurance_refund = 30**
GIVEN 玩家已购买保险（30 筹码），对手确为黑杰克
WHEN 保险触发
THEN `add_chips(PLAYER, 30, INSURANCE_REFUND)` 被调用，净成本 0

### 交易规则

**AC-15: 余额不足拒绝交易**
GIVEN 玩家余额为 50
WHEN `spend_chips(PLAYER, 75, SHOP_PURCHASE)` 被调用
THEN 调用返回失败，余额保持 50，无日志条目

**AC-16: 零值交易为空操作**
GIVEN 玩家余额为 100
WHEN `add_chips(PLAYER, 0, RESOLUTION)` 被调用
THEN 余额不变，无日志条目

**AC-17: 拒绝负值金额**
GIVEN 玩家余额为 100
WHEN `add_chips(PLAYER, -50, RESOLUTION)` 被调用
THEN 调用被拒绝，余额不变

**AC-18: add_chips 返回实际增加量**
GIVEN 玩家余额为 990
WHEN `add_chips(PLAYER, 50, RESOLUTION)` 被调用
THEN 返回值为 9（实际增加量），余额变为 999

### 边界情况

**AC-19: 零余额 — 所有支出操作失败**
GIVEN 玩家余额为 0
WHEN 尝试购买保险（30）、下注边池（10/20/50）或商店购买（任意金额 > 0）
THEN 所有 `spend_chips()` 返回失败，余额保持 0

**AC-20: 死亡螺旋通过胜利奖励恢复**
GIVEN 玩家余额为 0，击败对手 2
WHEN `on_opponent_defeated(2)` 被调用
THEN 余额恢复为 100（50+25×2）

**AC-21: 即时胜利跳过全部筹码收入**
GIVEN 玩家触发 SPADE_BLACKJACK
WHEN 结算引擎完成（Phase 0a→即时胜利，Phase 0b-6 跳过）
THEN 无 `add_chips(PLAYER, amount, RESOLUTION)` 调用发生

**AC-22: 爆牌导致零筹码收入**
GIVEN 玩家爆牌
WHEN 结算引擎处理爆牌
THEN 所有玩家卡牌标记"爆牌无效"，Phase 1-6 跳过，`chip_output` 为 0

**AC-23: 保险返还时上限钳制**
GIVEN 玩家余额为 990，保险触发返还 30
WHEN `add_chips(PLAYER, 30, INSURANCE_REFUND)` 被调用
THEN 余额变为 999（非 1020），实际返还 9

**AC-24: HAMMER 无效化草花卡牌切断筹码收入**
GIVEN 草花 K 被对手重锤无效化
WHEN 结算引擎处理该卡
THEN `chip_output = 0`，无 `add_chips()` 调用

### 跨系统交互

**AC-25: 结算引擎注入筹码**
GIVEN 结算引擎计算 `chip_output = 45`（草花 Q）
WHEN Phase 5 调用 `add_chips(PLAYER, 45, RESOLUTION)`
THEN 筹码经济存储结果，余额增加 45

**AC-26: can_afford 用于商店和保险校验**
GIVEN 玩家余额为 25
WHEN `can_afford(30)` 被调用（保险）
THEN 返回 false
WHEN `can_afford(25)` 被调用
THEN 返回 true

**AC-27: 交易日志可供 UI 查询**
GIVEN 玩家完成一回合：结算收入 45、购买保险 30
WHEN `get_transaction_log()` 被调用
THEN 日志包含 2 条按时间排序的条目：+45(RESOLUTION)、-30(INSURANCE)

**AC-28: 重置清空所有状态**
GIVEN 玩家余额 750，日志 40 条
WHEN `reset_for_new_game()` 被调用
THEN 余额变为 100，日志清空

## Open Questions

- [ ] `opponent_number` 超出 [1, 8] 范围时 `victory_bonus` 的行为——是拒绝调用还是钳制到边界值？需与对局进度系统协调
- [ ] 初始筹码 100 是否过紧——对手 1 阶段玩家可能无法负担商店任意商品（如 HAMMER 印记 300），需 playtest 验证早期经济压力是否合理
- [x] 边池系统作为筹码经济的高波动收支源——已确认：7 边池庄家优势 52%（激进筹码消耗口），赌场战争庄家优势 10.3%（温和消耗口）。两者均为负 EV，不会替代经济引擎构建。边池 GDD: `design/gdd/side-pool.md`
- [ ] 筹码上限 999 在游戏后期是否过紧——若玩家构建了高产出经济引擎（每回合 200-300 筹码），上限可能在 2-3 回合内触及。需 playtest 验证是否需要提高上限或引入溢出转化机制
