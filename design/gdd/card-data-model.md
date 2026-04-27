# Card Data Model (卡牌数据模型)

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-23
> **Implements Pillar**: Foundation — all systems depend on this

## Overview

卡牌数据模型是《决胜21点》的数据基础层。它定义了每一张卡牌的完整属性结构（花色、点数、印记、卡质及等级）、一副标准牌组的构成规则、以及牌在游戏中的流转机制（发牌、排序、结算、摧毁、买卖）。作为 Foundation 层系统，它为下游全部 13 个系统提供统一的数据接口 — 点数计算引擎读取花色和点数，结算引擎消费所有属性，商店系统基于属性计算定价，牌桌 UI 渲染卡牌外观。没有这个系统，游戏无法表示"一张牌"是什么，也无法让玩家体验到卡牌的多样性、印记组合的构筑深度、以及卡质摧毁的风险与回报。

## Player Fantasy

此系统为纯基础设施，玩家不直接交互。玩家感受到的是它所赋能的体验：每张牌都有独特的属性组合（花色+印记+卡质），使得构筑决策充满深度 — 为一张黑桃 A 附上护盾印记并升级为 I 级黑曜石质，还是留着筹码买一张带钱币印记的草花 K？这些选择的丰富性，以及宝石质卡牌在结算时"会被摧毁吗？"的紧张感，都建立在卡牌数据模型的完整性之上。

## Detailed Design

### Core Rules

**1. 卡牌原型 (Card Prototype)**

52 个不可变模板，每个对应唯一的花色+点数组合。

| 字段 | 类型 | 说明 |
|------|------|------|
| `suit` | 枚举 {HEARTS, DIAMONDS, SPADES, CLUBS} | 花色 |
| `rank` | 枚举 {A, 2, 3, 4, 5, 6, 7, 8, 9, 10, J, Q, K} | 点数 |
| `bj_values` | Array[int] | A = [1, 11]，2-10 = [面值]，J-K = [10] |
| `effect_value` | int | A=15，2-10=面值，J=11，Q=12，K=13 |
| `chip_value` | int | A=75，2-10=10-50(步长5)，J=55，Q=60，K=65 |
| `base_buy_price` | int | = chip_value，黑桃 J/Q/K/A 额外 +10 |

原型通过 `(suit, rank)` 查找，运行时只读。

**2. 卡牌实例 (Card Instance)**

游戏中每张实际牌是一个实例，引用原型并携带可变增强属性。

| 字段 | 类型 | 默认值 | 说明 |
|------|------|--------|------|
| `prototype` | CardPrototype | 构造时传入 | 引用不可变原型 |
| `stamp` | 枚举 or null | null | {SWORD, SHIELD, HEART, COIN, HAMMER, RUNNING_SHOES, TURTLE} |
| `quality` | 枚举 or null | null | {COPPER, SILVER, GOLD, DIAMOND, RUBY, SAPPHIRE, EMERALD, OBSIDIAN} |
| `quality_level` | 枚举 {III, II, I} | III | 仅当 quality 非 null 时有意义 |
| `owner` | 枚举 {PLAYER, AI} | 构造时传入 | 牌属于谁的牌组 |

唯一键：`(owner, suit, rank)`。运行时共 104 个实例（52 玩家 + 52 AI）。

**3. 牌组不变量**

玩家牌组和 AI 牌组始终包含 52 张牌 — 每种花色+点数恰好一张。牌组永远不增长、不缩小。

**4. 牌组生命周期**

```
游戏开始
├── 玩家牌组: 52 张普通实例（无印记、无卡质）
├── AI 牌组: 52 张实例，随机分配印记和卡质
│
每个对手开始时:
├── 52 张牌洗入抽牌堆 (draw_pile)
│
对战回合:
├── 从抽牌堆发牌 → 手牌
├── 结算 → 弃牌堆 (discard_pile)
│
抽牌堆耗尽时:
├── 弃牌堆洗入抽牌堆
│
击败对手后:
├── 进入商店（修改实例属性）
├── 下一对手: 重新洗牌
│
游戏结束: 牌组销毁
```

**5. 增强获取（商店购买）**

购买增强牌时，不创建新实例，而是修改现有实例的属性：
1. 在玩家牌组中找到 `(PLAYER, suit, rank)` 对应的实例
2. 将 `stamp`、`quality`、`quality_level` 设置为新值
3. 旧属性被覆盖 — 购买是取舍，不是纯增强

**6. 卡质摧毁（结算中）**

宝石质卡牌摧毁检查失败时：
1. 将该实例的 `quality` 设为 null
2. 将 `quality_level` 重置为 III
3. `stamp` 不受影响（摧毁只移除卡质，不移除印记）
4. 被摧毁卡牌仍完成当次结算的完整效果

**7. AI 牌组生成**

每个新对手开始时：
1. 创建 52 个 CardInstance，owner = AI
2. 随机分配印记，约束：
   - 重锤印记不超过 3 个
   - 总印记数量不超过 30 个
3. 随机分配卡质，约束：
   - 有卡质的卡牌数量不超过 30 个
4. 卡质等级固定为 III
5. 宝石质遵守花色限制（红水晶→方片，蓝宝石→红桃，祖母绿→草花，黑曜石→黑桃）
6. AI 牌组不跨对手保留 — 每次刷新

### States and Transitions

无状态机 — 卡牌数据模型是纯数据层，不驱动游戏流程。牌的位置（抽牌堆/手牌/弃牌堆）由牌组管理系统追踪，不属于本系统。

### Interactions with Other Systems

| 下游系统 | 读取什么 | 写入什么 |
|---------|---------|---------|
| 点数计算引擎 | `suit`, `rank`, `bj_values` | 无 |
| 牌型检测系统 | `suit`, `rank` | 无 |
| 印记系统 | `stamp` | 修改 `stamp`（商店赋印记） |
| 卡质系统 | `quality`, `quality_level`, `suit` | 修改 `quality`（摧毁时清空）、`quality_level`（提纯时升级） |
| 结算引擎 | 所有属性 | 无（通过卡质系统间接修改） |
| 排序系统 | `stamp`（跑鞋/乌龟） | 无 |
| 筹码经济 | `suit`, `rank`, `chip_value` | 无 |
| 商店系统 | 所有属性 | 修改 `stamp`, `quality`, `quality_level` |
| AI 对手 | 所有属性 | 生成时写入随机 `stamp`, `quality` |
| 牌桌 UI | `suit`, `rank`, `stamp`, `quality` | 无 |

## Formulas

### 1. 效果值查找

`effect_value = lookup(rank)`

| rank | A | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | J | Q | K |
|------|---|---|---|---|---|---|---|---|---|----|---|---|---|
| effect_value | 15 | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | 11 | 12 | 13 |

**Output Range**: [2, 15]，离散。每个点数对应唯一值。
**Example**: rank=Q → effect_value=12

### 2. 筹码值查找

`chip_value = lookup(rank)`

| rank | A | 2 | 3 | 4 | 5 | 6 | 7 | 8 | 9 | 10 | J | Q | K |
|------|---|---|---|---|---|---|---|---|---|----|---|---|---|
| chip_value | 75 | 10 | 15 | 20 | 25 | 30 | 35 | 40 | 45 | 50 | 55 | 60 | 65 |

**Output Range**: [10, 75]，离散。
**Example**: rank=7 → chip_value=35

### 3. 基础购价

```
base_buy_price = chip_value + spade_face_bonus
spade_face_bonus = 10 (if suit=SPADES AND rank∈{J,Q,K,A}), else 0
```

**Output Range**: [10, 85]。最小 = 方片2 的 chip_value (10)。最大 = 黑桃A 的 75 + 10 = 85。
**Example**: 黑桃K → 65 + 10 = 75

### 4. 宝石质摧毁概率

`gem_destroy_prob = lookup(quality_level)`

| quality_level | III | II | I |
|---------------|-----|----|----|
| destroy_prob  | 15% | 10% | 5% |

适用于所有宝石质（红水晶/蓝宝石/祖母绿/黑曜石）。金属质（铜/银/金/钻）永不摧毁。

### 5. 金属质筹码加成

`metal_chip_bonus = lookup(quality, quality_level)`

| quality | III | II | I |
|---------|-----|----|----|
| 铜质 | 10 | 15 | 20 |
| 银质 | 20 | 28 | 36 |
| 金质 | 30 | 40 | 50 |
| 钻质 | 50 | 66 | 82 |

**Output Range**: [10, 82]，12 个离散值。

### 6. 宝石质属性加成

`gem_bonus = lookup(quality, quality_level)`

| quality | 加成类型 | III | II | I |
|---------|---------|-----|----|----|
| 红水晶 | 伤害 | 3 | 4 | 5 |
| 蓝宝石 | 回复 | 3 | 4 | 5 |
| 祖母绿 | 筹码 | 15 | 20 | 25 |
| 黑曜石 | 防御 | 3 | 4 | 5 |

**Output Range**: [3, 25]，12 个离散值。

## Edge Cases

- **如果抽牌堆和弃牌堆同时耗尽**: 不应发生（52 张牌对 21 点足够），但作为安全网：重新生成完整的 52 张牌组并洗牌。日志警告。
- **宝石质摧毁后再次购买提纯**: 商店必须检查 `quality != null` 才能提供提纯服务。摧毁后 quality=null 时，提纯选项不可选。摧毁操作原子性执行：同时设置 quality=null 和 quality_level=III。
- **"卖卡"与 52 张不变量的冲突**: 卖卡不移除卡牌实例，而是剥离所有增强（stamp=null, quality=null, level=III），卡牌回归普通版。退款为买入价的 50%。牌组保持 52 张。
- **宝石质花色限制的执行点**: 数据模型拥有验证函数 `is_valid_assignment(suit, quality) → bool`。商店、AI 生成、以及任何未来系统都调用此函数。运行时检测到无效赋值时拒绝操作并日志警告。
- **印记/卡质变更后的下游缓存失效**: 当实例的 stamp 或 quality 变更时，任何缓存了派生状态的下游系统必须视为脏数据。每个实例维护递增的 `revision` 计数器，消费者通过比较 revision 检测变更。
- **AI 牌组重新生成时的悬空引用**: AI 牌组在每个对手开始时刷新。旧实例标记为 `expired = true`。持有引用的系统必须检查此标志。
- **购买完全相同的增强牌**: 如果商店刷出的牌与玩家已有牌的 stamp 和 quality 完全相同，商店应灰显该选项并提示"已拥有相同牌"。部分重叠（如同一 stamp 但更高品质）允许购买，显示差异对比。
- **AI 生成过程中超过上限**: 先生成所有卡牌，再检查约束。如超限，移除最后添加的超限项并重新随机，直到满足约束。
- **存档加载违反 104 实例不变量**: 反序列化后验证：恰好 104 个实例、104 个唯一键完整、无重复、无异常字段。任一检查失败则拒绝加载并报错。

## Dependencies

**上游依赖**: 无 — 本系统是 Foundation 层。

**下游依赖（被依赖）**:

| 系统 | 依赖类型 | 接口 |
|------|---------|------|
| 点数计算引擎 | 硬 | 读取 `suit`, `rank`, `bj_values` |
| 牌型检测系统 | 硬 | 读取 `suit`, `rank` |
| 印记系统 | 硬 | 读写 `stamp` |
| 卡质系统 | 硬 | 读写 `quality`, `quality_level` |
| 结算引擎 | 硬 | 读取所有属性 |
| 卡牌排序系统 | 硬 | 读取 `stamp`（跑鞋/乌龟） |
| 筹码经济系统 | 硬 | 读取 `chip_value` |
| 特殊玩法系统 | 软 | 读取卡牌数量（分牌判定） |
| 边池系统 | 软 | 读取 `rank`（7 边池检测） |
| 商店系统 | 硬 | 读写 `stamp`, `quality`, `quality_level` |
| AI 对手系统 | 硬 | 生成时写入随机 `stamp`, `quality` |
| 回合管理 | 硬 | 管理牌组生命周期 |
| 牌桌 UI | 硬 | 读取 `suit`, `rank`, `stamp`, `quality` 渲染 |

## Tuning Knobs

| 调参点 | 类型 | 默认值 | 安全范围 | 影响什么 |
|--------|------|--------|----------|---------|
| `ai_max_hammers` | int | 3 | 0-52 | AI 牌组重锤印记上限，影响 AI 进攻强度 |
| `ai_max_stamps` | int | 30 | 0-52 | AI 牌组总印记上限，影响 AI 复杂度 |
| `ai_max_qualities` | int | 30 | 0-52 | AI 牌组有卡质的卡牌上限，影响 AI 经济产出 |
| `ai_stamp_probability` | float | 0.50 | 0.0-1.0 | ~~已弃用~~ 由 AI 对手系统的 `ai_stamp_prob_table` 查找表取代（按对手序号缩放） |
| `ai_quality_probability` | float | 0.40 | 0.0-1.0 | ~~已弃用~~ 由 AI 对手系统的 `ai_quality_prob_table` 查找表取代（按对手序号缩放） |
| `gem_destroy_prob_iii` | float | 0.15 | 0.0-1.0 | III 级宝石质摧毁概率 |
| `gem_destroy_prob_ii` | float | 0.10 | 0.0-1.0 | II 级宝石质摧毁概率 |
| `gem_destroy_prob_i` | float | 0.05 | 0.0-1.0 | I 级宝石质摧毁概率 |
| `spade_face_bonus` | int | 10 | 0-50 | 黑桃 J/Q/K/A 的商店加价 |
| `sell_price_ratio` | float | 0.50 | 0.0-1.0 | 卖卡退款比例 |

## Acceptance Criteria

**AC-01: 原型查找完整性**
GIVEN 原型注册表包含所有 52 个 CardPrototype 条目
WHEN 通过任意有效的 (suit, rank) 对进行查找
THEN 恰好返回一个原型，52 种组合各返回不同原型（无重复、无缺失）。

**AC-02: 原型字段值正确性**
GIVEN 查找 rank=A 的原型
WHEN 读取 `bj_values`, `effect_value`, `chip_value`
THEN `bj_values`=[1,11], `effect_value`=15, `chip_value`=75。

GIVEN 查找 rank=K, suit=SPADES 的原型
WHEN 读取 `base_buy_price`
THEN = 65 + 10 = 75（黑桃面牌加价生效）。

GIVEN 查找 rank=K, suit=HEARTS 的原型
WHEN 读取 `base_buy_price`
THEN = 65（非黑桃，无加价）。

**AC-03: 实例创建与唯一性**
GIVEN 游戏初始化新会话
WHEN 创建所有 CardInstance（52 PLAYER + 52 AI）
THEN 恰好 104 个实例，(owner, suit, rank) 唯一键集合大小为 104。

**AC-04: 玩家牌组默认状态**
GIVEN 52 个 PLAYER 实例已创建
WHEN 检查每个 PLAYER 实例
THEN 每个 `stamp`=null, `quality`=null, `quality_level`=III。

**AC-05: 增强后牌组不变量**
GIVEN 玩家牌组经过任意次数商店购买修改
WHEN 统计 PLAYER 实例总数
THEN 恰好 52 个，每种 (suit, rank) 恰好出现一次。

**AC-06: 增强覆盖机制**
GIVEN 实例 (PLAYER, SPADES, A) 当前 stamp=SHIELD, quality=COPPER, quality_level=II
WHEN 购买增强 stamp=COIN, quality=GOLD, quality_level=III
THEN stamp=COIN, quality=GOLD, quality_level=III，旧值完全丢弃。

**AC-07: 修订计数器递增**
GIVEN CardInstance 当前 revision=N
WHEN 对 stamp, quality, 或 quality_level 执行任意修改
THEN revision=N+1。

**AC-08: 宝石质摧毁**
GIVEN CardInstance quality=RUBY, quality_level=II, stamp=SWORD
WHEN 执行摧毁操作
THEN quality=null, quality_level=III, stamp=SWORD（不变）。

**AC-09: 宝石质摧毁（所有等级）**
GIVEN CardInstance quality 为任意宝石质（RUBY/SAPPHIRE/EMERALD/OBSIDIAN），quality_level 为 {III, II, I}
WHEN 执行摧毁
THEN 结果始终：quality=null, quality_level=III, stamp 不变。

**AC-10: 卖卡机制**
GIVEN 实例 (PLAYER, HEARTS, K) stamp=HAMMER, quality=DIAMOND, quality_level=I
WHEN 执行卖卡操作
THEN stamp=null, quality=null, quality_level=III，实例仍在牌组中，牌组保持 52 张。

**AC-11: AI 生成约束 — 重锤上限**
GIVEN AI 牌组已生成
WHEN 检查 stamp=HAMMER 的实例数量
THEN ≤ `ai_max_hammers`（默认 3）。

**AC-12: AI 生成约束 — 印记上限**
GIVEN AI 牌组已生成
WHEN 统计 stamp 非 null 的实例数量
THEN ≤ `ai_max_stamps`（默认 30）。

**AC-13: AI 生成约束 — 卡质上限**
GIVEN AI 牌组已生成
WHEN 统计 quality 非 null 的实例数量
THEN ≤ `ai_max_qualities`（默认 30），且所有此类实例 quality_level=III。

**AC-14: 验证函数 — 宝石质花色限制**
GIVEN `is_valid_assignment(suit, quality)` 被调用
WHEN 测试: (DIAMONDS, RUBY)→true, (HEARTS, SAPPHIRE)→true, (CLUBS, EMERALD)→true, (SPADES, OBSIDIAN)→true, (HEARTS, RUBY)→false, (SPADES, SAPPHIRE)→false, (DIAMONDS, EMERALD)→false, (CLUBS, OBSIDIAN)→false
THEN 每个结果匹配预期布尔值。

**AC-15: 验证函数 — 金属质无花色限制**
GIVEN `is_valid_assignment(suit, quality)` 被调用
WHEN quality 为任意金属质（COPPER/SILVER/GOLD/DIAMOND）且 suit 为任意花色
THEN 所有 16 种组合均返回 true。

**AC-16: 存档加载 — 有效数据**
GIVEN 存档文件包含恰好 104 个条目，104 个唯一键完整无重复
WHEN 加载并运行不变量验证
THEN 加载成功，内存状态与存档数据一致。

**AC-17: 存档加载 — 无效数据拒绝**
GIVEN 存档文件实例数 ≠ 104，或存在重复键，或字段值越界
WHEN 加载并运行不变量验证
THEN 加载被拒绝，记录错误，不应用任何损坏状态。

**AC-18: AI 牌组重新生成 — 无悬空引用**
GIVEN 对手 1 的 AI 牌组已生成（52 实例）
WHEN 生成对手 2 的新 AI 牌组
THEN 对手 1 的 52 实例全部标记 expired=true，创建新的 52 实例，系统总实例数仍为 104。

## Open Questions

- [ ] 初始生命值和初始筹码数是多少？（影响战斗状态系统和筹码经济系统）
- [ ] 每局需要击败多少个对手？（影响对局进度系统）
- [ ] AI 难度是否随对手递进？如是，`ai_stamp_probability` 和 `ai_quality_probability` 是否按难度调整？（影响 AI 对手系统）
- [ ] 玩家是否可以在同一张牌上同时拥有印记和卡质？（当前设计允许，确认是否正确）
- [ ] 商店是否可以出售已摧毁的宝石质的重新应用？（还是一旦摧毁就永久失去该品质？）
