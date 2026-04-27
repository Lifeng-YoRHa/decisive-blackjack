# 特殊玩法系统 (Special Plays System)

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-04-24
> **Implements Pillar**: 策略深度 + 赌场庄家幻想

## Overview

特殊玩法系统管理三种高风险战术选择：双倍下注、分牌、和保险。每种玩法都在关键决策点提供"加注或保守"的二元选择——玩家在信息不完全时押注自己的判断力。系统本身是一个状态机，追踪每个特殊玩法的触发条件、激活状态和结算参数，通过输入参数影响结算引擎管道的行为。三种玩法在时机上互斥：保险在发牌后立即可用，分牌在保险之后判定，双倍下注在要牌阶段可用。分牌后，系统将单一结算管道分裂为两个独立的子管道，共享同一个 HP 池。

玩家的核心体验是"赌场里的老手"——知道何时加注、何时止损、何时对冲。每一次特殊玩法的选择都是一次风险/回报的计算：双倍下注放大收益但也放大自伤，分牌创建两条战线但削弱每手的牌力，保险花费资源但可能完全无效。

## Player Fantasy

"赌桌上的决胜者"——你不是赌徒，你是牌桌上的掠食者。一切信息都已看在眼里，每一次加注都是确认优势后的决断：双倍下注是因为你精确计算过 11 点是最优加注位，分牌是因为你读出了一对可以变成两条战线，保险是因为你嗅到了对手明牌 A 背面的危险。这不是冲动的豪赌——是冷静的战略家在扣下扳机。

**标志性时刻**：手牌 [8, 3]，总计 11。对手的明牌是一张暗淡的 4。双倍下注按钮亮起。你按下它——抽到一张 10——总计 21。基础数值翻倍，结算时方片 K 如陨石般坠落，对手生命条被削去一半。这不是运气。你在 11 点双倍下注，因为风险在掌控之中。

风险不是需要恐惧的未知——风险是你已经量化的变量。这套系统让"读牌"从被动接收信息变成主动的资源投入决策：你用筹码买信息（保险），用手牌数量换灵活性（分牌），用确定性换倍率（双倍下注）。每一次选择的背后都站着同一个信念：**我比你更了解这场牌局。**

## Detailed Design

### Core Rules

#### 1. 双倍下注 (Double Down)

**DD-1** — 双倍下注仅在当前手牌恰好有 2 张卡牌且未分牌时可触发。触发后：强制抽取 1 张牌，然后停牌。

**DD-2** — 玩家和 AI 均可使用双倍下注。AI 启发式：当手牌点数为 10 或 11 时双倍下注（数学最优加注位）。其他情况 AI 不双倍下注。

**DD-3** — 效果实现：结算引擎 Phase 1 弹出 `effect_value` 和 `chip_value_base` 时将值乘以 2。Phase 2-4（印记、卡质、牌型倍率）正常叠加，不受翻倍影响。
- 战斗效果：`(effect_value × 2 + stamp_combat_bonus + gem_quality_bonus) × M`
- 筹码收益：`(chip_value_base × 2 + metal_chip_bonus + gem_chip_bonus + stamp_coin_bonus) × M`

**DD-4** — 爆牌自伤公式：`bust_damage = point_total × bust_damage_multiplier × 2`。`bust_damage_multiplier` 旋钮（默认 1.0）在 ×2 之前应用，独立控制基础爆牌严重性。传递给战斗状态系统的值是翻倍后的最终值。

#### 2. 分牌 (Split)

**SP-1** — 发牌后，若玩家的两张起始牌 `rank` 相同，可触发分牌。将两张牌分别成为两手独立手牌的第一张。

**SP-2** — 每只分牌手牌立即从牌堆抽取 1 张牌。结果：两手牌，各 2 张。分牌后的手牌只能要牌或停牌，不允许双倍下注。

**SP-3** — 玩家和 AI 均可分牌。AI 在起始两张牌 rank 相同时总是分牌（AI 对手系统启发式）。

**SP-4** — 禁止二次分牌。补牌后即使 rank 匹配，也不能再次分牌。

**SP-5** — 分牌手牌不能触发 `BLACKJACK_TYPE`（×4）或 `SPADE_BLACKJACK`（即时胜利）。这些牌型要求恰好两张"原始"手牌。分牌手牌仍可触发 `TWENTY_ONE`（×2）、`PAIR`、`FLUSH` 等。

**SP-6** — 两手牌共享玩家的 HP 池。任一手牌的爆牌自伤消耗同一 HP。

**SP-7** — 结算采用顺序子管道：手牌 A 完全结算（Phase 0a-7），然后手牌 B 完全结算。结算引擎不感知分牌——回合管理器连续调用两次 `resolve_pipeline(hand, ai_hand, combat_state)`，共享同一个 `combat_state`。

**SP-8** — AI 的防御在手牌 A 和手牌 B 之间保持累积。手牌 B 面对手牌 A 留下的 AI 防御状态。玩家防御同理——手牌 A 积累的防御保留到手牌 B 结算结束。

**SP-9** — 若手牌 A 的结算导致玩家 HP 降至 0（爆牌自伤或 AI 伤害），手牌 B **不结算**。立即执行死亡判定。未结算手牌的宝石卡牌受保护（不执行 Phase 6 摧毁检查）。

#### 3. 保险 (Insurance)

**INS-1** — 当对手的可见牌为 Ace 时，保险可用。在分牌检查之前立即提供。

**INS-2** — 费用：30 筹码或 6 HP，由玩家选择支付方式。
- 若筹码 < 30：仅 HP 选项可用
- 若 HP ≤ 6：仅筹码选项可用（防止自杀）
- 若两者均不满足：保险不可用

**INS-3** — 购买保险后揭示对手的完整手牌。

**INS-4** — 若对手持有 `BLACKJACK_TYPE`（×4）或 `SPADE_BLACKJACK`（即时胜利）：
- 退还费用（退还筹码或恢复 HP）
- 对手牌型降级：`SPADE_BLACKJACK` 不触发即时胜利，`BLACKJACK_TYPE` 降级为 `TWENTY_ONE`（×2）
- 结算引擎接收 `insurance_active = true` 用于 Phase 0a 处理

**INS-5** — 若对手不持有 Jack/Blackjack 牌型：费用不退还。揭示的信息是唯一收益。

**INS-6** — AI 可对玩家购买保险，遵循相同规则（30 AI 筹码或 6 AI HP）。AI 启发式：当玩家明牌为 Ace 时总是购买保险。

**INS-7** — 双方可独立购买保险，各自独立检查对手的实际牌型。

**INS-8** — 保险揭示后，玩家不能改变先前的决策（不能撤回已有的双倍下注或重新分牌）。揭示是信息性的——为后续要牌/停牌决策提供参考。

### States and Transitions

```
[发牌] → [保险窗口] → [分牌检查] → [要牌/停牌/双倍下注] → [排序] → [结算]

保险窗口: 仅当对手明牌 = Ace 时开放
分牌检查: 仅当玩家起始两张牌 rank 相同时开放
双倍下注: 仅当当前手牌恰好 2 张牌且未分牌时可用
```

| 状态 | 触发条件 | 可用操作 | 转换到 |
|------|----------|----------|--------|
| DEALT | 发牌完成 | 检查保险条件 | INSURANCE_WINDOW / SPLIT_CHECK |
| INSURANCE_WINDOW | 对手明牌 = Ace | 购买/跳过 | SPLIT_CHECK |
| SPLIT_CHECK | 起始两张牌 rank 相同 | 分牌/不分 | HIT_STAND |
| HIT_STAND | 进入要牌阶段 | 要牌/停牌/双倍下注 | SORT / HIT_STAND |
| SORT | 双方停牌 | 排序卡牌 | RESOLUTION |
| RESOLUTION | 排序完成 | 自动执行 | ROUND_RESULT |

### Interactions with Other Systems

| 系统 | 方向 | 接口 | 触发时机 |
|------|------|------|----------|
| 战斗状态系统 (#7) | 双向 | 读取 HP 判断保险可用性；传递 `bust_damage × 2`（双倍下注）；分牌共享 HP 池 | 保险窗口、结算 Phase 0b |
| 结算引擎 (#6) | 出 | `insurance_active` 布尔值用于 Phase 0a；双倍下注标志用于 Phase 1；分牌触发连续两次管道调用 | 结算启动时 |
| 筹码经济系统 (#10) | 双向 | `spend_chips(30, INSURANCE)` / `add_chips(30, INSURANCE_REFUND)`；读取 `can_afford(30)` | 保险窗口 |
| 卡牌数据模型 (#1) | 入 | 读取手牌 `rank` 判断分牌条件；读取卡牌数量判断双倍下注条件 | 分牌检查、双倍下注检查 |
| 点数计算引擎 (#2) | 入 | 双倍下注后新增牌的点数计算 | 要牌阶段 |

## Formulas

### 1. 双倍下注爆牌自伤 (doubledown_bust_damage)

The `doubledown_bust_damage` formula is defined as:

`bust_damage_dd = point_total × bust_damage_multiplier × 2`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| point_total | P | int | 22–31 | 爆牌时的手牌点数（bust 仅在 >21 时触发，所以最小 22） |
| bust_damage_multiplier | K_b | float | 0.5–3.0 | 基础爆牌严重性旋钮（默认 1.0，来自战斗状态系统） |

**Output Range:** [22, 186] — 最小 22×0.5×2=22，最大 31×3.0×2=186。默认旋钮下（K_b=1.0）范围 [44, 62]。
**Example:** 双倍下注后爆牌，point_total=24，K_b=1.0 → `bust_damage_dd = 24 × 1.0 × 2 = 48`。传递 `apply_bust_damage(PLAYER, 48)`。

### 2. 双倍下注效果修正 (doubledown value doubling)

双倍下注不定义独立公式，而是作为已有 `combat_effect` 和 `chip_output` 公式的条件变体。当 `doubledown_active = true` 时，结算引擎 Phase 1 将 `effect_value` 和 `chip_value_base` 输入值乘以 2 后传入现有公式。

**战斗效果**（条件变体 of `combat_effect`）：
`combat_effect_dd = (effect_value × 2 + stamp_combat_bonus + gem_quality_bonus) × M`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| effect_value | V_e | int | 2–15 | 卡牌原型效果值（×2 后传入公式，实际输入 4–30） |
| stamp_combat_bonus | V_sc | int | 0–2 | 印记战斗加成（不变） |
| gem_quality_bonus | V_gq | int | 0–5 | 宝石质战斗加成（不变） |
| M | M | float | 1.0–11.0 | 牌型倍率（不变） |

**Output Range:** [4, 484]。最小 (2×2+0+0)×1.0=4，最大 (15×2+2+5)×11=484。恰好是 `combat_effect` 上下限的两倍。

**筹码收益**（条件变体 of `chip_output`）：
`chip_output_dd = (chip_value_base × 2 + metal_chip_bonus + gem_chip_bonus + stamp_coin_bonus) × M`

| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| chip_value_base | V_cb | int | 0–75 | 草花牌基础筹码值（×2 后传入，实际输入 0–150） |
| metal_chip_bonus | V_mc | int | 0–82 | 金属质筹码加成（不变） |
| gem_chip_bonus | V_gc | int | 0–25 | 祖母绿筹码加成（不变） |
| stamp_coin_bonus | V_sco | int | 0–10 | 钱币印记加成（不变） |
| M | M | float | 1.0–11.0 | 牌型倍率（不变） |

**Output Range:** [0, 3674]。最小 0，最大 (75×2+82+0+10)×11=3674。恰好是 `chip_output` 上限的两倍。

**Example:** 草花 A（chip_value_base=75）+ DIAMOND I（metal_chip_bonus=82）+ COIN 印记（+10）+ 双倍下注 + FLUSH（M=11.0）→ `chip_output_dd = (75×2+82+0+10)×11 = 3674`。

### 3. 保险费用 (insurance_cost)

两种支付路径，玩家二选一：

| 路径 | 公式 | 值 | 注册常量 |
|------|------|-----|----------|
| 筹码 | `insurance_chip_cost` | 30 | ✅ 已注册 |
| 生命 | `insurance_hp_cost` | 6 | 待注册 |

### 4. AI 双倍下注阈值 (ai_doubledown_threshold)

AI 启发式规则（非公式）：当 `hand_point_total ∈ {10, 11}` 时，AI 触发双倍下注。理由：10/11 是数学最优加注位——抽到 10/J/Q/K（概率 16/52 ≈ 30.8%）可凑成 20/21。

### 5. 分牌

分牌不引入新公式。它是结构性的变化：结算引擎管道被连续调用两次，使用完全相同的公式，共享同一个 `combat_state`。

## Edge Cases

- **If 玩家选择 HP 支付保险且 HP 恰好为 6**: INS-2 规定 HP ≤ 6 时仅筹码选项可用。HP=7 支付后剩余 1，存活。边界明确：HP 必须 > 6（即 ≥ 7）才显示 HP 支付选项。HP=6 时禁用 HP 支付以防止自杀。

- **If 双方均购买保险且双方均持有 SPADE_BLACKJACK**: 结算引擎 Phase 0a 优先检查互斥即时胜利——双方即时胜利直接抵消，进入正常结算。保险退款仍触发：双方对手确实持有 SPADE_BLACKJACK（购买条件成立），尽管即时胜利会被互斥规则抵消。双方各获得退款。

- **If 分牌手牌 A 的结算执行了 Phase 7a（防御清零）后手牌 B 才开始**: Phase 7a 必须延迟到两手牌全部结算完成后执行。手牌 A 的管道调用跳过 Phase 7a，仅在手牌 B 的管道调用结束时执行 Phase 7a。否则手牌 A 积累的防御会在手牌 B 开始前被清空，违反 SP-8。

- **If 保险退款将筹码余额推超过 chip_cap=999**: 筹码经济系统按 AC-25 钳制到 999。保险退款不保证无损——若结算过程中余额已接近上限，退款部分会被截断。这是有意的惩罚：在高余额时购买保险的风险更高。

- **If 玩家分牌两张 A 并各抽到 10 值牌**: 每手达到 21，但 SP-5 压制 `BLACKJACK_TYPE` 和 `SPADE_BLACKJACK`。每手仅触发 `TWENTY_ONE`（×2）。分牌 A 是强操作但付出 ×4→×2 的代价。应在 playtest 中追踪分牌 A 的胜率。

- **If 保险 HP 支付后 HP 极低（如 HP 8→2）且分牌可用**: 保险 HP 支付在分牌判定之前执行。玩家以完整信息选择了 HP 支付，低 HP 分牌是有意的风险。UI 应在保险后 HP 低于 10 且分牌可用时显示风险提示。

- **If 双倍下注的 ×2 误泄漏到分牌手牌的爆牌计算中**: `bust_damage_multiplier` 是调参旋钮（始终生效），×2 仅在 `doubledown_active=true` 时叠加。分牌手牌的爆牌公式为 `point_total × bust_damage_multiplier`（无 ×2）。分牌后 `doubledown_active` 必须为 false。

- **If AI 双倍下注后手牌包含红桃（回复效果也被翻倍）**: DD-3 翻倍 `effect_value` 对所有花色生效——包括红桃的回复。AI 双倍下注时回复量翻倍是预期行为。AI 启发式仅考虑点数 {10, 11}，不考虑花色构成，这是简化设计的取舍。

## Dependencies

| 依赖系统 | 方向 | 硬/软 | 接口 | 状态 |
|----------|------|-------|------|------|
| 卡牌数据模型 (#1) | 入 | 硬 | 读取 `rank`（分牌条件）、`effect_value`（双倍下注翻倍目标）、`chip_value_base`（双倍下注翻倍目标）、卡牌数量（双倍下注条件） | ✅ 已设计 |
| 点数计算引擎 (#2) | 入 | 硬 | `hand_point_total`（AI 双倍下注判定：10/11 阈值）、`simulate_hit`（AI 决策模拟） | ✅ 已设计 |
| 结算引擎 (#6) | 双向 | 硬 | 出：`insurance_active` 布尔值（Phase 0a）、`doubledown_active` 布尔值（Phase 1 翻倍）；入：结算管道作为分牌的执行引擎（连续两次调用） | ✅ 已设计 |
| 战斗状态系统 (#7) | 双向 | 硬 | 入：读取 HP（保险可用性判定）、读取防御状态；出：传递翻倍后爆牌自伤值 `apply_bust_damage`；分牌共享 `combat_state` | ✅ 已设计 |
| 筹码经济系统 (#10) | 双向 | 硬 | 出：`spend_chips(30, INSURANCE)`、`add_chips(30, INSURANCE_REFUND)`；入：`can_afford(30)` | ✅ 已设计 |
| AI 对手系统 (#12) | 出 | 软 | 提供 AI 双倍下注启发式（{10, 11}）、AI 分牌启发式（总是分牌）和 AI 保险启发式（总是购买） | ✅ 已设计 |

## Tuning Knobs

| 旋钮 | 类型 | 默认值 | 安全范围 | 影响 |
|------|------|--------|----------|------|
| `insurance_chip_cost` | int | 30 | 0–100 | 保险筹码成本。调低降低对冲门槛，调高使保险成为更重的经济负担（由筹码经济系统拥有，本系统消费） |
| `insurance_hp_cost` | int | 6 | 1–20 | 保险生命成本。调低降低 HP 支付门槛，调高使 HP 支付风险更大。HP ≤ 此值时禁用 HP 支付 |
| `bust_damage_multiplier` | float | 1.0 | 0.5–3.0 | 基础爆牌严重性。双倍下注时在此基础上再 ×2。调高增加爆牌惩罚（所有爆牌），调低使爆牌更宽容（由战斗状态系统拥有，本系统消费） |
| `ai_doubledown_points` | Set[int] | {10, 11} | {2–20} | AI 双倍下注的点数集合。扩大集合使 AI 更激进，缩小使 AI 更保守。加入 9 或 12 会显著改变 AI 行为 |
| `ai_always_buy_insurance` | bool | true | true/false | AI 是否总是购买保险。设为 false 时 AI 系统需提供自定义策略 |

**旋钮交互：**
- `insurance_chip_cost` 和 `insurance_hp_cost` 的比率决定筹码 vs HP 支付的吸引力。当前比率 30:6 = 5:1。若 chip_cost 调高到 60 而 hp_cost 不变（60:6 = 10:1），HP 支付变得明显更优。
- `bust_damage_multiplier` 同时影响正常爆牌和双倍下注爆牌（×2 叠加在乘数之上）。调高此值会同时惩罚所有爆牌行为，间接削弱双倍下注的风险/回报比。

## Visual/Audio Requirements

待牌桌 UI 系统设计时补充。关键反馈时刻：
- 双倍下注确认：加注音效 + 卡牌发光特效
- 分牌动画：两张牌分别滑向牌桌两侧
- 保险购买：揭示对手暗牌的翻转动画
- 保险退款触发：金币返还特效

## UI Requirements

待牌桌 UI 系统设计时补充。关键交互元素：
- 双倍下注按钮（仅 2 张牌且未分牌时激活）
- 分牌按钮（仅起始两张 rank 相同时激活）
- 保险支付选择器（筹码/HP 二选一）
- 分牌双手牌的独立显示区域

## Acceptance Criteria

**AC-DD1** — **GIVEN** 玩家恰好 2 张牌且未分牌，**WHEN** 进入要牌阶段，**THEN** 双倍下注可用。**GIVEN** 玩家 3+ 张牌或为分牌手牌，**THEN** 双倍下注不可用。

**AC-DD2** — **GIVEN** AI 手牌点数为 10 或 11，**WHEN** AI 评估操作，**THEN** 触发双倍下注。**GIVEN** AI 点数为其他值，**THEN** 不触发。

**AC-DD3** — **GIVEN** `doubledown_active=true`，**WHEN** 结算 Phase 1 执行，**THEN** `effect_value` 和 `chip_value_base` 乘以 2 后传入公式；`stamp_combat_bonus`、`gem_quality_bonus`、`stamp_coin_bonus` 和倍率 M 不变。

**AC-DD4** — **GIVEN** `doubledown_active=true` 且爆牌 point_total=P，bust_damage_multiplier=K，**WHEN** 爆牌自伤应用，**THEN** 传递给 `apply_bust_damage` 的值为 P×K×2。

**AC-SP1** — **GIVEN** 玩家两张起始牌 rank 相同，**WHEN** 分牌检查阶段，**THEN** 分牌可用。**GIVEN** rank 不同，**THEN** 分牌不可用。

**AC-SP2** — **GIVEN** 玩家触发分牌，**WHEN** 分牌执行，**THEN** 每手各抽 1 张牌，后续仅可要牌或停牌。

**AC-SP4** — **GIVEN** 玩家已分牌，**WHEN** 任一手牌补牌后出现相同 rank，**THEN** 不允许再次分牌。

**AC-SP5** — **GIVEN** 分牌手牌，**WHEN** 牌型检测，**THEN** `BLACKJACK_TYPE` 和 `SPADE_BLACKJACK` 不触发；`TWENTY_ONE` 正常触发。

**AC-SP7** — **GIVEN** 分牌激活，**WHEN** 结算执行，**THEN** 手牌 A 所有阶段完全结算后手牌 B 才开始；共享同一 `combat_state`。

**AC-SP8** — **GIVEN** 手牌 A 的结算在共享 `combat_state` 上积累了防御值，**WHEN** 手牌 B 开始，**THEN** AI 和玩家的防御值反映手牌 A 的累积结果。

**AC-SP9** — **GIVEN** 手牌 A 结算使玩家 HP 降至 0，**WHEN** 引擎评估是否继续，**THEN** 手牌 B 不结算，其宝石卡牌受保护（不执行 Phase 6）。

**AC-INS2** — **GIVEN** 对手明牌=Ace，玩家筹码≥30 且 HP>6，**THEN** 两种支付方式均显示。**GIVEN** 筹码<30 且 HP>6，**THEN** 仅 HP 选项。**GIVEN** HP≤6 且筹码≥30，**THEN** 仅筹码选项。**GIVEN** 筹码<30 且 HP≤6，**THEN** 保险不可用。

**AC-INS4** — **GIVEN** 对手持 `BLACKJACK_TYPE` 或 `SPADE_BLACKJACK` 且保险已购买，**WHEN** 保险结算，**THEN** 费用退还，即时胜利被抑制，`BLACKJACK_TYPE` 降级为 `TWENTY_ONE`。

**AC-INS5** — **GIVEN** 对手不持有 Jack/Blackjack 牌型且保险已购买，**WHEN** 保险结算，**THEN** 费用不退还，仅保留揭示的信息。

**AC-INS6** — **GIVEN** AI 的对手（玩家）明牌为 Ace，**WHEN** AI 评估保险，**THEN** 总是购买保险。

**AC-EC1** — **GIVEN** 分牌激活，**WHEN** 手牌 A 结算完成，**THEN** Phase 7a（防御清零）延迟执行；仅在手牌 B 管道完成后执行一次。

**AC-EC2** — **GIVEN** 筹码余额接近 999 且保险退款 30 会超出上限，**WHEN** 退款应用，**THEN** 余额钳制到 999。

**AC-EC3** — **GIVEN** 玩家 HP=6，**WHEN** 保险支付选项评估，**THEN** HP 支付禁用（HP 必须 >6 即 ≥7）。

**AC-EC4** — **GIVEN** 玩家分牌两张 A 且各抽到 10 值牌达到 21，**WHEN** 牌型评估，**THEN** 每手触发 `TWENTY_ONE`（×2），不触发 `BLACKJACK_TYPE`（×4）。

**AC-EC5** — **GIVEN** 玩家已分牌（`doubledown_active=false`），**WHEN** 分牌手牌爆牌，**THEN** 爆牌自伤为 `point_total × bust_damage_multiplier`，无 ×2 翻倍。

## Open Questions

1. **分牌两手牌间 AI 防御累积是否过强？** — 手牌 A 给 AI 堆叠防御后，手牌 B 面对更高防御。若 playtest 显示分牌惩罚过重，可考虑手牌 B 重置 AI 防御。负责人：game designer，目标：首次 playtest 后。

2. **分牌 A 的胜率是否需要压制？** — 分牌两张 A 各抽 10 值牌是极强操作（两手 ×2）。若数据表明过于 dominant，可考虑分牌 A 只允许各抽 1 张后强制停牌。负责人：game designer + economy designer，目标：平衡调优阶段。

3. **AI 双倍下注是否应考虑花色构成？** — 当前启发式仅看点数 {10, 11}，不考虑手牌中红桃（翻倍回复）或方片（翻倍伤害）的比例。若 AI 行为过于简单可预测，AI 系统可覆盖此启发式。负责人：AI programmer，目标：AI 对手系统设计时。 — ✅ 已在 AI 对手系统 GDD 中解决：保持简单启发式。

4. **保险的 HP 支付路径是否应随游戏进程缩放？** — 当前固定 6 HP，但对手递增时 6 HP 的代价感会降低（后期 HP 损耗更大）。负责人：game designer，目标：Alpha 阶段平衡调优。
