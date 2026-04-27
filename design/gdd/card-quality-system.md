# 卡质系统 (Card Quality System)

> **Status**: In Design
> **Author**: user + agents
> **Last Updated**: 2026-04-24
> **Implements Pillar**: Core — card quality effects, gem destroy mechanics, and purification

## Overview

卡质系统是《决胜21点》的卡牌增强系统之一，与印记系统并列构成构筑的两大维度。它定义了 8 种卡质类型（4 种金属 + 4 种宝石）和 3 个纯度等级（III → II → I），赋予每张卡牌额外的筹码产出或战斗加成。金属质（铜/银/金/钻）提供纯筹码加成，安全但"只加钱"；宝石质（红水晶/蓝宝石/祖母绿/黑曜石）提供花色匹配的战斗加成（伤害/回复/筹码/防御），效果更强但每回合结算后有概率被摧毁。这个系统创造了游戏最核心的风险/回报张力：一张钻质 I 级的草花 7 每回合稳定产出 +82 筹码，而一张红水晶 I 级的方片 7 提供 +5 伤害但每回合 10% 概率永久失去品质——摧毁后印记保留，卡牌仍在牌组中，只是失去了那层锋芒。

在数据层面，卡质存储在 CardInstance 的 `quality` 和 `quality_level` 字段中，由卡牌数据模型定义结构，由商店系统写入（赋质和提纯服务），由结算引擎在"弹出数值 → 印记效果 → **卡质效果** → 牌型效果"的管道阶段 3 消费，并在阶段 6 执行宝石质的摧毁检查。提纯服务将等级从 III → II → I 逐级提升，降低摧毁概率并增加加成——投资越深，回报越高，风险越低。卡质与印记完全独立运作：宝石质摧毁不清除印记，印记覆盖不影响卡质，两者在结算管道的不同阶段各自触发。

## Player Fantasy

**炼金铸师 — 炼石成金，铸牌入魂**

核心时刻：你打开牌组查看器。方片 7 带着红水晶 III 级——粗砺、未提纯，15% 摧毁概率。它已经撑过了两个回合，像一颗定时炸弹。你进入商店，花 100 筹码提纯到 II 级：摧毁概率降至 10%，加成从 +3 伤害升至 +4。还不够。你再攒一回合筹码，花 200 筹码提纯到 I 级：+5 伤害，5% 摧毁概率。你看着那张牌——它和三个回合前完全不同了。不再是赌注，而是武器。你炼成了它。而当它最终崩解——不可避免地——那不是损失，而是一柄服役并消逝的利器。你从头再来。

卡质系统的玩家幻想是**炼金术士的掌控感**：将原始矿石（III 级，高内含物）逐步提纯为无瑕宝石（I 级，最低风险，最强加成）。每次提纯都是一次有意义的转化——不是简单的"买升级"，而是你用筹码和时间交换来的精炼过程。金属质是"基础金属"——稳妥、实用、永不磨损。宝石质是"珍贵矿石"——强大，但需要持续的炼金照料。这个二分法让每次商店决策都成为身份选择：你要安全的经济引擎（金属），还是高风险的战斗增幅器（宝石）？

这与印记系统的"序列锻造师"幻想形成完美对仗：印记决定你*如何使用*卡牌（编排时序、精准定位），卡质决定卡牌*是什么材质*（基础金属还是珍贵矿石）。一个锻造工具，一个炼化材质。两者结合，玩家同时是锻造师和炼金术士——双料大师。

摧毁时刻必须有重量。失去一颗 I 级红水晶不仅仅是"坏运气"——它是 300 筹码（100 + 200）的投资付诸东流。代价是真实的。这种紧张感服务了游戏的 Roguelike 构筑幻想：每次提纯都是不可逆的投资决策，每次摧毁检查都是对你判断力的考验——"我该把它提纯到 I 级吗？还是留着筹码买别的东西？"

## Detailed Design

### Core Rules

**1. 卡质分类 (Quality Categories)**

8 种卡质分为两大类：

| 类别 | 卡质 | 加成类型 | 摧毁风险 | 花色限制 |
|------|------|---------|---------|---------|
| 金属质 | COPPER (铜) | 筹码 | 无 | 无 |
| 金属质 | SILVER (银) | 筹码 | 无 | 无 |
| 金属质 | GOLD (金) | 筹码 | 无 | 无 |
| 金属质 | DIAMOND (钻) | 筹码 | 无 | 无 |
| 宝石质 | RUBY (红水晶) | 伤害 | 有 | 仅方片 |
| 宝石质 | SAPPHIRE (蓝宝石) | 回复 | 有 | 仅红桃 |
| 宝石质 | EMERALD (祖母绿) | 筹码 | 有 | 仅草花 |
| 宝石质 | OBSIDIAN (黑曜石) | 防御 | 有 | 仅黑桃 |

**2. 卡质等级 (Quality Level)**

每个卡质有 3 个纯度等级：III → II → I（基于国际宝石分级标准）。

- 等级越高（I 为最高），加成越大，摧毁概率越低
- 等级只能通过商店提纯服务逐级提升，不可跳跃（III→II→I）
- 新赋予的卡质（商店赋质、AI 生成）始终从 III 级开始

**3. 双轨结算输出 (Dual-Track Settlement Output)**

卡质加成在结算管道阶段 3 触发时，产生**两个独立的输出流**：

**战斗效果流** — 伤害/回复/防御：
```
combat_effect = (effect_value + stamp_combat_bonus + gem_quality_bonus) × hand_type_multiplier
```
- `effect_value`: 卡牌原型的效果值（A=15, 2-10=面值, J=11, Q=12, K=13）
- `stamp_combat_bonus`: 印记的战斗加成（短剑+2伤害/护盾+2防御/心+2回复）
- `gem_quality_bonus`: 宝石质的战斗加成（红水晶+伤害/蓝宝石+回复/黑曜石+防御），按等级查表

**筹码流** — 筹码收益：
```
chip_output = (chip_value_base + metal_chip_bonus + gem_chip_bonus + stamp_coin_bonus) × hand_type_multiplier
```
- `chip_value_base`: 草花牌使用 `chip_value`（A=75, 2=10...7=35...K=65），非草花牌为 0
- `metal_chip_bonus`: 金属质的筹码加成，按卡质类型和等级查表
- `gem_chip_bonus`: 祖母绿质的筹码加成（仅草花牌可拥有），按等级查表
- `stamp_coin_bonus`: 钱币印记的 +10 筹码

两条流完全独立：金属质不影响战斗效果，宝石质（除祖母绿外）不影响筹码流。

**4. 花色限制执行 (Suit Restriction Enforcement)**

宝石质与花色绑定：
- 红水晶 (RUBY) → 仅方片 (DIAMONDS)
- 蓝宝石 (SAPPHIRE) → 仅红桃 (HEARTS)
- 祖母绿 (EMERALD) → 仅草花 (CLUBS)
- 黑曜石 (OBSIDIAN) → 仅黑桃 (SPADES)

验证通过 `is_valid_assignment(suit, quality) → bool` 执行（由卡牌数据模型提供）。商店赋质、AI 生成、以及任何写入 `quality` 字段的操作都必须调用此函数。违反花色限制的赋值被拒绝并记录警告日志。

金属质无花色限制——任何花色的卡牌都可以拥有任何金属卡质。

**5. 宝石质摧毁检查 (Gem Destroy Check)**

每张宝石质卡牌在完成当次结算的全部效果（阶段 1-5）后，在阶段 6 执行独立的摧毁检查：

1. 对每张宝石质卡牌独立掷骰：`randf() < gem_destroy_prob(quality_level)`
2. 摧毁概率：III 级 = 15%，II 级 = 10%，I 级 = 5%
3. 掷骰失败的卡牌：`quality` 设为 null，`quality_level` 重置为 III
4. `stamp` 不受影响——摧毁只移除卡质，不移除印记
5. 被摧毁卡牌的当次结算效果已完整执行——摧毁是"事后结算"
6. 掷骰结果互相独立——同手牌中多张宝石质卡牌的摧毁结果互不影响

金属质卡牌不做摧毁检查。

**6. 提纯服务 (Purification Service)**

商店提供提纯服务，逐级提升卡质等级：

| 升级路径 | 费用 |
|---------|------|
| III → II | 100 筹码 |
| II → I | 200 筹码 |

规则：
- 每次提纯只升一级，不可跳跃
- 只有 `quality != null` 的卡牌才能提纯（被摧毁后 quality=null 的卡牌无法提纯）
- 提纯不改变卡质类型——铜质提纯后还是铜质，只是等级变了
- 提纯效果立即生效（下一回合结算时使用新等级）

**7. 赋质服务 (Quality Assignment Service)**

商店提供赋质服务，为卡牌附加卡质：

- 所有卡质类型的赋质价格：铜 40 / 银 80 / 金 120 / 钻 200 / 宝石质统一 120
- 新赋予的卡质等级固定为 III
- 赋质可以覆盖已有卡质（旧卡质完全丢弃，不可恢复）
- 赋质时必须通过花色限制验证（宝石质只能赋予匹配花色的卡牌）
- 赋质不影响该卡牌已有的印记

**8. 卡质与印记的独立性**

卡质和印记是完全独立的两个系统，互不影响：
- 宝石质摧毁不清除印记
- 印记覆盖（商店购买新印记）不改变卡质
- 两者在结算管道的不同阶段各自触发（印记在阶段 2，卡质在阶段 3）
- 一张卡牌可以同时拥有印记和卡质

**9. 爆牌时卡质效果**

当一方爆牌时，该方所有卡牌的花色效果无效——卡质效果同样无效。宝石质的摧毁检查也跳过（爆牌方不存在结算阶段 3-6）。

### States and Transitions

```
[无卡质] ── 商店赋质 ──→ [金属质 III]
  │                          │
  │                          ├── 商店提纯 → [金属质 II] → 商店提纯 → [金属质 I]
  │                          │                                          │
  │                          └── 商店覆盖赋质 → [其他卡质 III] ──→ ...
  │
  └── 商店赋质(宝石质) ──→ [宝石质 III]
                               │
                               ├── 商店提纯 → [宝石质 II] → 商店提纯 → [宝石质 I]
                               │                                          │
                               ├── 结算摧毁检查 ──→ [无卡质] (quality=null, level=III)
                               │                          │
                               │                          └── 可再次赋质 → [任意卡质 III]
                               │
                               └── 商店覆盖赋质 → [其他卡质 III]
```

关键状态：
- **无卡质**：quality=null, quality_level=III（默认）
- **金属质 N 级**：quality∈{COPPER,SILVER,GOLD,DIAMOND}, quality_level=N。无摧毁风险。
- **宝石质 N 级**：quality∈{RUBY,SAPPHIRE,EMERALD,OBSIDIAN}, quality_level=N。每回合结算后有摧毁风险。
- 所有状态都可以通过商店赋质覆盖为新的 III 级卡质。

### Interactions with Other Systems

| 系统 | 方向 | 数据流 | 触发时机 |
|------|------|--------|---------|
| 卡牌数据模型 | 双向 | 读取 `quality`, `quality_level`, `suit`；写入 `quality`（摧毁时）、`quality_level`（提纯时） | 结算时读取，摧毁/提纯时写入 |
| 结算引擎 | 出 | `combat_effect`（战斗效果值）、`chip_output`（筹码收益值）、摧毁检查结果 | 结算管道阶段 3、阶段 6 |
| 印记系统 | 无直接交互 | 卡质与印记独立运作，通过 `combat_effect` / `chip_output` 分别消费 | N/A |
| 商店系统 | 入 | 商店赋质请求（写入 `quality`=III）、提纯请求（递增 `quality_level`） | 商店阶段 |
| AI 对手系统 | 出 | 生成时随机分配 `quality`，遵守花色限制和 `ai_max_qualities`=30 约束 | 新对手开始时 |
| 战斗状态系统 | 间接（经结算引擎） | 宝石质加成后的伤害/回复/防御值 | 结算管道阶段 5 |
| 筹码经济系统 | 间接（经结算引擎） | 金属质筹码加成、草花筹码产出 | 结算管道阶段 5 |
| 牌桌 UI | 间接 | 读取 `quality`, `quality_level` 渲染卡质图标和等级指示 | 持续 |

## Formulas

### 1. 战斗效果值 (combat_effect)

The `combat_effect` formula is defined as:

```
combat_effect = (effect_value + stamp_combat_bonus + gem_quality_bonus) × hand_type_multiplier
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| effect_value | V_e | int | 2 ~ 15 | 卡牌原型效果值（A=15, 2-10=面值, J=11, Q=12, K=13） |
| stamp_combat_bonus | V_sc | int | 0 ~ 2 | 印记战斗加成（SWORD=2伤害/SHIELD=2防御/HEART=2回复，其他=0） |
| gem_quality_bonus | V_gq | int | 0 ~ 5 | 宝石质战斗加成（RUBY=+dmg/SAPPHIRE=+heal/OBSIDIAN=+def，按等级 3/4/5） |
| hand_type_multiplier | M_h | float | 1.0 ~ 11.0 | 牌型倍率（无牌型=1.0，FLUSH最高=手牌数≤11） |

**Output Range:** [2, 242]。最小 = 2×1.0（无印记无卡质的 2 号牌）。最大 = (15+2+5)×11 = 242（方片 A + 短剑 + 红水晶 I 级 + 同花 11 张）。金属质对战斗效果无贡献。
**Example:** 方片 7 + SWORD + RUBY II，PAIR (×2) → (7+2+4)×2 = **26 伤害**

### 2. 筹码收益 (chip_output)

The `chip_output` formula is defined as:

```
chip_output = (chip_value_base + metal_chip_bonus + gem_chip_bonus + stamp_coin_bonus) × hand_type_multiplier
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| chip_value_base | V_cb | int | 0 ~ 75 | 草花牌 = chip_value（按 rank 查表），非草花 = 0 |
| metal_chip_bonus | V_mc | int | 0 ~ 82 | 金属质筹码加成（COPPER [10-20]/SILVER [20-36]/GOLD [30-50]/DIAMOND [50-82]） |
| gem_chip_bonus | V_gc | int | 0 ~ 25 | 祖母绿质筹码加成（仅草花牌可拥有，EMERALD III=15/II=20/I=25，其他宝石质=0） |
| stamp_coin_bonus | V_sc | int | 0 ~ 10 | 钱币印记加成（COIN=10，其他印记=0） |
| hand_type_multiplier | M_h | float | 1.0 ~ 11.0 | 牌型倍率 |

**Output Range:** [0, 1837]。最小 = 0（非草花牌 + 无金属质 + 无钱币印记）。一条卡只能有一个 quality，因此 metal_chip_bonus 和 gem_chip_bonus 互斥。

- 纯金属路径最大：草花 A + DIAMOND I + COIN + FLUSH×11 → (75+82+0+10)×11 = **1837 筹码**
- 宝石路径最大：草花 A + EMERALD I + COIN + FLUSH×11 → (75+0+25+10)×11 = **1210 筹码**

**Example:** 草花 7 + DIAMOND I + COIN + 三七(×7) → (35+82+0+10)×7 = **889 筹码** ✓

**Example:** 方片 7 + COPPER III + COIN + PAIR(×2) → combat_effect=(7+2+0)×2=18 伤害，chip_output=(0+10+0+10)×2=40 筹码

### 3. 宝石质摧毁概率 (gem_destroy_prob)

The `gem_destroy_prob` formula is defined as:

```
gem_destroy_prob = lookup(quality_level)
```

| quality_level | III | II | I |
|---------------|-----|----|----|
| destroy_prob | 0.15 | 0.10 | 0.05 |

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| quality_level | — | 枚举 | {III, II, I} | 宝石质的纯度等级 |

**Output Range:** [0.05, 0.15]
**Example:** quality_level=II → destroy_prob=0.10（每回合 10% 概率被摧毁）

### 4. 摧毁检查掷骰 (gem_destroy_roll)

```
is_destroyed = (randf() < gem_destroy_prob)
```

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| gem_destroy_prob | P_d | float | 0.05 ~ 0.15 | 由 gem_destroy_prob 查找得出 |

**Output Range:** {true, false}
**Example:** quality_level=I → P_d=0.05 → 5% 概率 is_destroyed=true

### 5. 卡质加成统一查找 (quality_bonus_resolve)

```
quality_bonus_resolve(quality, quality_level) → {combat_type, combat_value, chip_value}
```

| quality | combat_type | combat_value (III/II/I) | chip_value (III/II/I) |
|---------|------------|------------------------|----------------------|
| COPPER | NONE | 0 | 10 / 15 / 20 |
| SILVER | NONE | 0 | 20 / 28 / 36 |
| GOLD | NONE | 0 | 30 / 40 / 50 |
| DIAMOND | NONE | 0 | 50 / 66 / 82 |
| RUBY | DAMAGE | 3 / 4 / 5 | 0 |
| SAPPHIRE | HEAL | 3 / 4 / 5 | 0 |
| EMERALD | CHIPS | 0 | 15 / 20 / 25 |
| OBSIDIAN | DEFENSE | 3 / 4 / 5 | 0 |
| null | NONE | 0 | 0 |

**Output:** 三元组 `{combat_type, combat_value ∈ [0, 5], chip_value ∈ [0, 82]}`
**Example:** quality=DIAMOND, quality_level=I → {NONE, 0, 82}

### 6. 提纯费用 (purification_cost)

```
purification_cost = lookup(current_level)
```

| current_level → target_level | cost |
|------------------------------|------|
| III → II | 100 |
| II → I | 200 |
| I → (无升级) | N/A |

**Output Range:** {100, 200}

### 7. 赋质费用 (assignment_cost)

```
assignment_cost = lookup(quality)
```

| quality | cost |
|---------|------|
| COPPER | 40 |
| SILVER | 80 |
| GOLD | 120 |
| DIAMOND | 200 |
| RUBY / SAPPHIRE / EMERALD / OBSIDIAN | 120 |

**Output Range:** [40, 200]

## Edge Cases

- **如果被摧毁的宝石质卡牌尝试提纯**: 商店必须拒绝——`quality != null` 是硬前提。被摧毁的卡牌必须重新赋质（120 筹码，III 级起）才能再提纯。恢复路径：摧毁 → 重新赋质(120) → 提纯(100) → 提纯(200) = 420 筹码恢复到 I 级。

- **如果 I 级卡质被覆盖赋值为同类型**: 卡牌回到 III 级，300 筹码的提纯投资永久丢失。商店 UI 应检测降级并警告。

- **如果覆盖赋值将 DIAMOND I 降级为 COPPER III**: 500 筹码投资（200赋质+100+200提纯）永久丢失，卡牌变为 COPPER III（+10筹码）。灾难性误购——商店 UI 必须对覆盖操作显示明确确认。

- **如果方片牌有 RUBY 品质 + COIN 印记**: 双轨独立产出。combat_effect = (effect_value + 5) × M 伤害。chip_output = 10 × M 筹码。RUBY 加伤害，COIN 加筹码，互不干扰。

- **如果黑桃牌有 OBSIDIAN 品质 + SHIELD 印记**: combat_effect = (effect_value + 2 + 5) × M 防御（OBSIDIAN I 级 + SHIELD）。纯防御堆叠，无筹码产出。单张黑桃 K + OBSIDIAN I + SHIELD = (13+2+5)×1.0 = 20 防御。

- **如果非草花牌有金属品质**: 金属质独立产生筹码流。红桃 7 + GOLD I = 7 回复 + 50 筹码。方片 A + DIAMOND I = 15 伤害 + 82 筹码。两条流同时触发，互不影响。

- **如果同手牌中所有宝石质卡牌全部摧毁检查失败**: "灾难性宝石崩塌"——所有宝石质卡牌同时失去品质。5 张 III 级宝石同时摧毁的概率 = (0.15)^5 = 0.0076%，极端罕见但可能发生。无安全网。

- **如果宝石质卡牌在提纯到 I 级的同一回合被摧毁**: 卡牌以 I 级加成完整执行了当次效果，然后在阶段 6 被摧毁。200 筹码的提纯投资仅获得一次 I 级输出。最差提纯回报。

- **如果摧毁检查在对手已死亡时执行**: 摧毁检查始终在阶段 6 执行，不论比赛结果是否已确定。玩家可能"赢了战斗但失去了投资"——刻意的 Roguelike 紧张感。

- **如果爆牌方的宝石质卡牌**: 爆牌方跳过阶段 2-6，宝石质卡牌不触发效果也不做摧毁检查。爆牌是宝石质卡牌的"安全回合"——它们在本回合不会被摧毁。

- **如果 AI 宝石质卡牌被摧毁**: AI 的卡牌失去品质。由于 AI 牌组在每个对手开始时刷新，摧毁仅影响当前对手内的后续回合。AI 宝石质在第一回合最强（15%摧毁率），后续逐步衰减。

- **如果 AI 获得金属质卡牌**: 金属质给 AI 产出的筹码加成对 AI 无意义——AI 没有筹码经济。AI 金属质卡牌的功能效果为零。AI 的品质分配应偏向宝石质以提供战斗挑战。

- **如果 EMERALD 看起来不如 DIAMOND**: EMERALD I 级 +25 筹码有 10% 摧毁风险，DIAMOND I 级 +82 筹码无风险。EMERALD 的存在理由是**可获得性**——DIAMOND 在商店中出现概率低于其他品质，EMERALD 作为更容易获得的草花筹码加成选项。定价差异（EMERALD 120 vs DIAMOND 200）和稀缺性差异由商店系统控制。

- **如果手牌牌型是 FLUSH 且金属质卡牌在非草花花色**: 金属筹码加成被 FLUSH 倍率放大。红桃 7 + GOLD I 在 5 张红桃同花中：chip_output = (0+50)×5 = 250 筹码。FLUSH 使金属质在任何花色上都经济强劲。

- **如果一张卡牌同时贡献战斗效果和筹码流**: 仅在金属质 + COIN 印记的非草花牌上发生。红桃 Q + GOLD I + COIN：12 回复 + 60 筹码（50金属+10印记）。"战斗-经济混合"卡。

- **如果分牌后一手牌中的宝石质被摧毁**: 品质跟随卡牌实例，不跟随手牌。摧毁只影响该卡牌本身。分牌后两手牌中的卡牌各自独立结算和摧毁检查。

## Dependencies

**上游依赖（本系统依赖）:**

| 系统 | 依赖类型 | 接口 | GDD 状态 |
|------|---------|------|---------|
| 卡牌数据模型 (#1) | 硬 | 读取 `quality`, `quality_level`, `suit`, `effect_value`, `chip_value`；写入 `quality`（摧毁时清空）、`quality_level`（提纯时升级）；调用 `is_valid_assignment(suit, quality)` | 已完成 |

**下游依赖（被依赖）:**

| 系统 | 依赖类型 | 接口 | GDD 状态 |
|------|---------|------|---------|
| 结算引擎 (#6) | 硬 | 消费 `combat_effect`（战斗效果值）、`chip_output`（筹码收益值）、摧毁检查结果 | 已完成 |
| 商店系统 (#11) | 硬 | 写入 `quality`（赋质）、递增 `quality_level`（提纯）；读取赋质价格表和提纯价格表 | 未设计 |
| AI 对手系统 (#12) | 硬 | 生成时随机分配 `quality`，遵守花色限制、`ai_max_qualities`=30 约束、卡质等级固定 III | 已设计 |
| 战斗状态系统 (#7) | 间接（经结算引擎） | 接收宝石质加成后的伤害/回复/防御值 | 已完成 |
| 筹码经济系统 (#10) | 间接（经结算引擎） | 接收金属质筹码加成、草花筹码产出 | 已设计 |
| 牌桌 UI (#15) | 间接 | 读取 `quality`, `quality_level` 渲染卡质图标和等级 | 未设计 |

**双向依赖验证:**

| 系统 | 本文档列出 | 对方文档是否列出本系统 | 状态 |
|------|-----------|---------------------|------|
| 卡牌数据模型 | 上游 | ✓ 下游（卡质系统读写 quality/quality_level） | 一致 |
| 印记系统 | 无直接交互 | ✓ 无直接引用（经结算引擎独立消费） | 一致 |
| 战斗状态系统 | 间接下游 | ✓ 无直接引用（经结算引擎间接） | 一致 |

**结算引擎公式接口变更（已完成）**
本系统将印记系统定义的单一 `final_card_value` 公式拆分为两个独立流：`combat_effect` 和 `chip_output`。结算引擎 GDD 已基于双轨模型设计。印记系统 GDD 中的 `final_card_value` 已于 2026-04-24 更新为双轨引用。

## Tuning Knobs

| 调参点 | 类型 | 默认值 | 安全范围 | 影响什么 |
|--------|------|--------|----------|---------|
| `gem_destroy_prob_iii` | float | 0.15 | 0.0 ~ 0.50 | III 级宝石质摧毁概率。调高增加风险紧张感但降低宝石质吸引力，调低使宝石质接近金属质的安全感 |
| `gem_destroy_prob_ii` | float | 0.10 | 0.0 ~ 0.40 | II 级宝石质摧毁概率。应低于 III 级 |
| `gem_destroy_prob_i` | float | 0.05 | 0.0 ~ 0.30 | I 级宝石质摧毁概率。应低于 II 级。这是提纯的核心动力——降低风险 |
| `purify_cost_iii_to_ii` | int | 100 | 50 ~ 300 | III→II 提纯费用。调高增加投资门槛，调低鼓励早期提纯 |
| `purify_cost_ii_to_i` | int | 200 | 100 ~ 500 | II→I 提纯费用。应显著高于 III→II 以制造投资递增感 |
| `ai_max_qualities` | int | 30 | 0 ~ 52 | AI 牌组有卡质的卡牌上限。owned by card-data-model，本系统消费。调高增加 AI 难度，调低简化 AI 行为 |
| ~~`ai_quality_probability`~~ | float | 0.40 | 0.0 ~ 1.0 | ~~已弃用~~ 由 AI 对手系统的 `ai_quality_prob_table` 查找表取代（按对手序号缩放） |
| `diamond_shop_rarity` | float | — | 0.0 ~ 1.0 | DIAMOND 品质在商店随机商品中的出现概率。调低增加 EMERALD 的可获得性优势（由商店系统定义） |

**调参交互注意事项**：
- 三个 `gem_destroy_prob` 必须保持严格递减：III > II > I。如果 I 级概率不低于 II 级，提纯失去了降低风险的动机
- `purify_cost_ii_to_i` 应约为 `purify_cost_iii_to_ii` 的 2 倍，制造投资递增感
- `gem_destroy_prob` 和 `purify_cost` 交互：摧毁概率越低 + 提纯费用越高 → 提纯动力越弱（已经够安全了）。摧毁概率越高 + 提纯费用越低 → 提纯成为必买（太强）
- `metal_chip_bonus` 表（由卡牌数据模型拥有）直接影响金属质 vs 宝石质的经济吸引力。如果金属筹码加成过高，宝石质的风险/回报比失衡
- AI 品质分配应偏向宝石质——AI 不使用筹码经济，金属质对 AI 无功能价值。`ai_quality_probability` 可考虑拆分为 `ai_metal_probability` 和 `ai_gem_probability`（由 AI 对手系统定义）

## Visual/Audio Requirements

此系统为纯数据/逻辑系统，无直接视觉或音频需求。卡质图标渲染和摧毁动画由牌桌 UI 系统负责设计。

## UI Requirements

此系统的 UI 需求由牌桌 UI 系统和商店系统负责。关键 UI 触点：
- 卡牌上的品质图标和等级指示
- 商店赋质和提纯界面
- 摧毁检查结果反馈

> **📌 UX Flag — 卡质系统**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for each screen or HUD element this system contributes to **before** writing epics.

## Acceptance Criteria

### 核心规则

**AC-R1: 金属质分类——无战斗加成，无摧毁风险**
GIVEN 一张红桃 7 无卡质
WHEN 赋予 COPPER 品质
THEN `combat_type=NONE`, `combat_value=0`, `chip_value` 按 COPPER 查表；该卡牌永不触发摧毁检查。

**AC-R1b: 宝石质花色锁定——非法赋值被拒绝**
GIVEN 一张方片 7 无卡质
WHEN 尝试赋予 SAPPHIRE（红桃限定）品质
THEN `is_valid_assignment(DIAMONDS, SAPPHIRE)` 返回 false；赋值被拒绝，quality 仍为 null。

**AC-R2: 新赋品质始终从 III 级开始**
GIVEN 任意卡牌无卡质
WHEN 商店赋予 RUBY 品质
THEN `quality_level=III`, `quality=RUBY`, `gem_destroy_prob=0.15`。

**AC-R3: 双轨输出独立性**
GIVEN 方片 7 + GOLD I + SWORD 印记
WHEN 结算执行
THEN `combat_effect` 包含 effect_value + SWORD 加成但不包含 GOLD 筹码加成；`chip_output` 包含 GOLD 筹码加成但不包含 SWORD 战斗加成。两值独立计算。

**AC-R4: 花色限制——有效与无效赋值**
GIVEN 草花 5 无卡质
WHEN 尝试赋予 RUBY（方片限定）→ `is_valid_assignment(CLUBS, RUBY)` 返回 false，拒绝。
WHEN 尝试赋予 EMERALD（草花限定）→ `is_valid_assignment(CLUBS, EMERALD)` 返回 true，成功。

**AC-R5: 摧毁检查——独立掷骰**
GIVEN 同手牌两张宝石质卡牌：RUBY III 和 SAPPHIRE III
WHEN 阶段 6 摧毁检查执行
THEN 每张卡牌独立掷骰；可能一张被摧毁一张幸存。被摧毁卡牌 `quality=null`, `quality_level=III`。幸存卡牌不变。

**AC-R5b: 摧毁在完整结算后执行**
GIVEN 红桃 Q + SAPPHIRE I
WHEN 摧毁检查摧毁该卡牌
THEN 该卡牌当回合的 combat_effect 和 chip_output 已完整执行；摧毁仅影响未来回合。

**AC-R6: 提纯逐级升级**
GIVEN 卡牌 RUBY III
WHEN 购买提纯（100 筹码）
THEN `quality_level=II`, `quality=RUBY`（类型不变）。
GIVEN 同卡牌 RUBY II
WHEN 再次购买提纯（200 筹码）
THEN `quality_level=I`；I 级无法继续提纯。

**AC-R6b: 被摧毁卡牌无法提纯**
GIVEN 卡牌 quality=null（已被摧毁）
WHEN 尝试购买提纯
THEN 商店拒绝操作；卡牌状态不变。

**AC-R7: 赋质覆盖——旧品质完全丢失**
GIVEN 卡牌 DIAMOND I
WHEN 赋予 COPPER 品质
THEN quality=COPPER, quality_level=III。原 DIAMOND I 状态永久丢失。

**AC-R8: 卡质与印记独立性**
GIVEN 黑桃 K + OBSIDIAN I + SHIELD 印记
WHEN 摧毁检查移除品质
THEN `quality=null`, `quality_level=III`, `stamp=SHIELD`（不变）。
WHEN 商店赋予新 stamp=SWORD
THEN `stamp=SWORD`, `quality=null`（不变）。

**AC-R9: 爆牌跳过卡质效果和摧毁检查**
GIVEN 玩家爆牌（is_bust=true），手牌含两张宝石质卡牌（RUBY III, SAPPHIRE II）
WHEN 结算执行
THEN 阶段 2-6 全部跳过；无卡质效果触发，无摧毁检查。两张卡牌品质完整保留。

**AC-R10: 摧毁检查不因比赛结果跳过**
GIVEN 对手 HP 在结算中途降至 0（比赛结果已确定）
WHEN 结算管道到达阶段 6
THEN 宝石质摧毁检查仍然执行。玩家可能"赢了战斗但失去了投资"。

### 公式

**AC-F1: combat_effect 计算**
GIVEN 方片 7 (effect_value=7) + SWORD 印记 (+2) + RUBY II 品质 (+4) + PAIR 牌型 (×2)
WHEN 计算 combat_effect
THEN (7 + 2 + 4) × 2 = **26 伤害**。

**AC-F1b: combat_effect 无卡质无印记**
GIVEN 红桃 3 (effect_value=3) + 无印记 + 无卡质 + 无牌型 (×1.0)
WHEN 计算 combat_effect
THEN (3 + 0 + 0) × 1.0 = **3 回复**。

**AC-F2: chip_output 金属路径最大值**
GIVEN 草花 A (chip_value_base=75) + DIAMOND I (metal_chip_bonus=82) + 无钱币印记 + FLUSH×11
WHEN 计算 chip_output
THEN (75 + 82 + 0 + 0) × 11 = **1837 筹码**。

**AC-F2b: chip_output 非草花金属质**
GIVEN 方片 7 (chip_value_base=0) + COPPER III (+10) + COIN 印记 (+10) + PAIR (×2)
WHEN 计算 chip_output
THEN (0 + 10 + 0 + 10) × 2 = **40 筹码**。

**AC-F3: gem_destroy_prob 查找**
GIVEN quality_level=III → destroy_prob=0.15
GIVEN quality_level=II → destroy_prob=0.10
GIVEN quality_level=I → destroy_prob=0.05

**AC-F4: quality_bonus_resolve 完整查找**
GIVEN 以下输入
WHEN 调用 quality_bonus_resolve
THEN 返回值匹配：

| 输入 | 期望输出 |
|------|---------|
| (COPPER, I) | {NONE, 0, 20} |
| (SILVER, II) | {NONE, 0, 28} |
| (GOLD, III) | {NONE, 0, 30} |
| (DIAMOND, I) | {NONE, 0, 82} |
| (RUBY, I) | {DAMAGE, 5, 0} |
| (SAPPHIRE, II) | {HEAL, 4, 0} |
| (EMERALD, I) | {CHIPS, 0, 25} |
| (OBSIDIAN, III) | {DEFENSE, 3, 0} |
| (null, III) | {NONE, 0, 0} |

**AC-F5: purification_cost 查找**
GIVEN current_level=III → cost=100
GIVEN current_level=II → cost=200
GIVEN current_level=I → 无有效升级路径

**AC-F6: assignment_cost 查找**
GIVEN quality=COPPER → 40, SILVER → 80, GOLD → 120, DIAMOND → 200, RUBY/SAPPHIRE/EMERALD/OBSIDIAN → 120

### 边界情况

**AC-E1: 同回合提纯后被摧毁（最差 ROI）**
GIVEN 卡牌 RUBY II
WHEN 提纯到 RUBY I（花费 200），紧接着当回合摧毁检查失败
THEN 卡牌以 I 级加成执行了一回合效果后被摧毁。200 筹码提纯投资仅获一次 I 级输出。

**AC-E2: 灾难性宝石崩塌**
GIVEN 5 张 III 级宝石质卡牌在同一手牌
WHEN 全部 5 张摧毁检查失败
THEN 全部 quality=null。概率 = (0.25)^5 = 0.0977%。合法结果。

**AC-E3: 非草花牌金属质独立产出筹码**
GIVEN 红桃 7 + GOLD I
WHEN 结算执行
THEN combat_effect 产出回复（红桃花色效果），chip_output 产出 50 筹码（GOLD I）。两条流独立生效。

**AC-E4: 祖母绿筹码加成仅走筹码流**
GIVEN 草花 7 + EMERALD I
WHEN 计算 chip_output
THEN gem_chip_bonus=25，无 metal_chip_bonus。chip_output 包含 EMERALD 的筹码贡献。
GIVEN 草花 7 + RUBY I（非法——花色限制，此场景不会发生，通过 AC-R4 阻止）

**AC-E5: 覆盖高等级品质丢失全部投资**
GIVEN 卡牌 DIAMOND I（总投资：200赋质+100+200提纯=500）
WHEN 赋予 COPPER（花费 40）
THEN 卡牌变为 COPPER III (chip_value=10)。原 DIAMOND I (chip_value=82) 永久丢失，无退款。

### 跨系统交互

**AC-X1: 卡质+印记在双轨中的独立消费**
GIVEN 方片 A + RUBY I (gem_quality_bonus=5 DAMAGE) + COIN 印记 (stamp_coin_bonus=10) + 无牌型 (×1.0)
WHEN 结算执行
THEN combat_effect = (15 + 0 + 5) × 1.0 = 20 伤害；chip_output = (0 + 0 + 0 + 10) × 1.0 = 10 筹码。RUBY 仅影响战斗，COIN 仅影响筹码。

**AC-X2: 卡质+牌型倍率放大战斗效果**
GIVEN 红桃 7 + SAPPHIRE I (+5 回复) + SHIELD 印记 (+2 防御) + FLUSH×5
WHEN 计算 combat_effect
THEN (7 + 2 + 5) × 5 = **70**。所有加成被牌型倍率放大。

**AC-X3: 金属筹码加成被 FLUSH 放大**
GIVEN 红桃 7 + GOLD I (+50 筹码) + FLUSH×5（非草花同花）
WHEN 计算 chip_output
THEN (0 + 50 + 0 + 0) × 5 = **250 筹码**。FLUSH 放大金属质在任何花色上的筹码产出。

**AC-X4: 金属和宝石筹码加成互斥**
GIVEN 任意卡牌
WHEN 检查 metal_chip_bonus 和 gem_chip_bonus
THEN 两者不可能同时非零——一张卡牌只能有一个 quality，要么是金属要么是宝石要么为 null。

## Open Questions

- [ ] DIAMOND 品质在商店中的稀缺度如何设定？（影响 EMERALD 的可获得性优势）——属于商店系统设计范围
- [ ] AI 品质分配是否应偏向宝石质？（当前 AI 金属质无功能效果）——属于 AI 对手系统设计范围
- [ ] 赋质覆盖时是否需要二次确认 UI？（覆盖高等级品质的误购风险）——属于 UX 设计范围
- [x] ~~`final_card_value` 公式（印记系统）需拆分为 `combat_effect` 和 `chip_output` 双轨公式——结算引擎设计时确认~~ 已完成 (2026-04-24)
- [ ] 牌型倍率放大金属筹码加成是否过强？（FLUSH×5 使金属质在任何花色上都产出大量筹码）——需游戏测试验证
