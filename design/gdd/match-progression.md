# 对局进度系统 (Match Progression System)

> **Status**: Designed
> **Author**: user + agents
> **Last Updated**: 2026-04-25
> **Implements Pillar**: Progression — 对手序列、难度曲线、胜负条件

## Overview

对局进度系统是《决胜21点》的宏观调度器——它消费回合管理系统发出的 `round_result` 事件，驱动对手间转换（击败 → 商店 → 下一对手）、全局胜负判定（VICTORY / GAME_OVER）、以及难度参数的对手级缩放（AI HP、牌组质量、决策策略）。系统维护对局级状态：当前对手序号（1-8）、总对手数、全局胜负结果，并为牌桌 UI 提供 `opponent_number` 和 `total_opponents` 用于进度显示。

在数据层面，对局进度是一个状态机——消费回合管理的微观结果，产出宏观决策：继续当前对手的下一回合（CONTINUE）、进入对手转换流程（PLAYER_WIN）、或终止对局（PLAYER_LOSE / VICTORY）。对手转换时，系统协调各子系统的重置：战斗状态系统初始化新对手 HP（`ai_hp_scaling`）、AI 对手系统生成新牌组（按 `opponent_number` 缩放）、筹码经济系统注入胜利奖励（`victory_bonus`）、商店系统提供构筑窗口。这些转换逻辑当前散落在回合管理 GDD 的规则 8-10 中——对局进度系统将其提取为独立的所有权，使回合管理专注于单回合编排，对局进度专注于跨对手宏观流程。

在玩家体验层面，对局进度系统创造了《决胜21点》的核心张力弧——**8 个对手的递进挑战**。从对手 1 的 80 HP 教学战到对手 8 的 300 HP Boss 战，玩家在每次商店访问中做出的构筑决策（印记、卡质、提纯）在对局进度的框架下获得了战略意义：你不是在为下一回合构筑，你在为整个剩余赛程构筑。筹码花费是即时的，但收益是跨对手累积的——给一张牌赋予祖母绿 III 级（120 筹码）可能在本回合看不到回报，但对手 5、6、7 的经济引擎会验证这个投资。对局进度系统让每场 20-40 分钟的对局拥有完整的叙事弧：开场（低资源、学习 AI 行为）、中盘（资源充裕、构筑成型）、终盘（资源紧张、Boss 压力）、高潮（最终战）。

## Player Fantasy

**攀登者 — 一掷千金，步步为营**

核心时刻：你刚击败对手 5，剩 38 HP。商店灯光亮起。余额 280。治疗选项：花 310 筹码回复 62 HP 到满血。或者花 120 筹码给方片 K 赋红宝石 II 级——下个对手 220 HP，你需要 DPS。你选择投资。38 HP 面对对手 6。这不是赌博——这是攀登。你每一点剩余的 HP 都是前面对手留下的伤痕，每一次商店投资都是在为更高的山峰做准备。你不在"消耗资源"——你在分配攀登预算。

对局进度系统的玩家幻想是**赌场筹码阶梯上的攀登者**：从底层桌（对手 1, 80 HP）到 VIP 室（对手 8, 300 HP），每升一级赌注更大、对手更强、容错更低。你感受到的不是线性的难度增加——你感受到的是自己构筑决策的回响。对手 3 时你给草花 A 赋了祖母绿 III 级（120 筹码），当时觉得贵。到对手 6，这张牌每回合稳定产出 20+ 筹码，成为你经济引擎的核心——早期投资的复利正在兑现。同时，你的 HP 始终在下降。没有怜悯机制，没有跨对手重置。商店是你唯一的补给站，但补给和治疗是竞争同一笔筹码的两个需求。治疗保命，构筑保未来。你选择保未来，因为你相信自己的牌组和策略能在低 HP 下存活——这是攀登者的赌注。

这个幻想与筹码经济系统的"庄家"和商店系统的"军需官"一脉相承：筹码经济说你赌的是数字，商店说你分配的是战争预算，对局进度说你攀登的是筹码阶梯——每一步都在更高处，每一步都更贵，但顶峰的风景（击败 300 HP Boss）值得每一枚筹码。

## Detailed Design

### Core Rules

**1. 系统性质**

对局进度系统是一个宏观状态机——它消费回合管理系统发出的 `round_result` 事件，产出对局级别的决策指令（继续当前对手、开始对手转换、结束对局）。系统维护对局级状态（当前对手序号、总对手数、对局状态），不持有回合级或战斗级状态。系统不直接调用战斗状态、筹码经济、AI 对手等子系统——它发出决策指令，由回合管理执行具体的子系统调用。

**2. 对局状态机**

对局进度维护 5 个顶层状态：

| 状态 | 说明 | 终止条件 |
|------|------|---------|
| NEW_GAME | 初始化中，未开始游戏 | 初始化完成后转入 OPPONENT_1 |
| OPPONENT_N | 对手 N 的战斗进行中 | 收到 round_result 后转入对应状态 |
| SHOP | 商店阶段（对手间暂停） | 商店关闭后转入 OPPONENT_N+1 |
| VICTORY | 击败所有对手（终态） | — |
| GAME_OVER | 玩家死亡（终态） | — |

**3. 对局级状态数据**

| 字段 | 类型 | 范围 | 说明 |
|------|------|------|------|
| `match_state` | enum | 5 种 | 当前对局状态 |
| `opponent_number` | int | [1, total_opponents] | 当前对手序号（本系统为唯一权威来源） |
| `total_opponents` | int | 默认 8 | 需击败的对手总数（调参点） |
| `opponents_defeated` | int | [0, total_opponents] | 已击败对手数（= opponent_number - 1） |

**4. 消费 round_result 事件**

回合管理在每次生死判定后发出 `round_result` 事件，本系统按以下规则映射：

| round_result | 条件 | 对局级决策 | 发出指令 |
|-------------|------|-----------|---------|
| CONTINUE | — | 继续当前对手的下一回合 | `round_continue()` |
| PLAYER_WIN | opponent_number < total_opponents | 对手转换流程 | `begin_opponent_transition(N)` |
| PLAYER_WIN | opponent_number == total_opponents | 游戏胜利 | `match_ended(VICTORY)` |
| PLAYER_LOSE | — | 游戏结束 | `match_ended(GAME_OVER)` |

**5. 对手转换流程**

当本系统发出 `begin_opponent_transition(N)` 后，回合管理执行以下序列：

1. **胜利奖励注入**：调用筹码经济的 `on_opponent_defeated(N)` → `victory_bonus` 注入余额
2. **商店阶段**：触发商店系统。商店运行期间，对局状态为 SHOP
3. **商店关闭后**：
   - `opponent_number` += 1
   - 协调各子系统初始化新对手：
     - 战斗状态：AI HP = `ai_hp_scaling(opponent_number)`
     - AI 对手系统：为对手 N+1 生成新牌组（按难度参数表）
     - 卡牌数据模型：玩家牌组洗入抽牌堆（保留属性），弃牌堆清空
   - 回合计数器重置为 1，先手方重新硬币翻转
   - 本系统发出 `opponent_ready(N+1)` → 回合管理开始新对手的第一回合

**6. 游戏胜利条件**

`victory = (opponent_number == total_opponents AND round_result == PLAYER_WIN)`

击败最后一个对手即游戏胜利。无商店访问（商店仅在对手 1 到 total_opponents-1 后触发）。

**7. 游戏失败条件**

`game_over = (round_result == PLAYER_LOSE)`

玩家 HP=0 的任何时刻（由战斗状态系统的生死判定检测），对局以 GAME_OVER 结束。同时死亡（双方 HP=0）也判 PLAYER_LOSE。

**8. 游戏初始化序列**

新游戏开始时，本系统进入 NEW_GAME 状态并协调以下初始化：

1. 卡牌数据模型：创建 104 个卡牌实例（52 玩家 + 52 AI）
2. 战斗状态系统：玩家 HP = `player_max_hp`(100)，AI HP = `ai_hp_scaling(1)`(80)
3. 筹码经济系统：`reset_for_new_game()`，余额 = `initial_chips`(100)
4. AI 对手系统：为对手 1 生成 AI 牌组
5. 双方牌组洗入抽牌堆
6. 本系统：`opponent_number = 1`，`match_state = OPPONENT_1`
7. 回合管理：`round_counter = 1`，`first_player = 硬币翻转`
8. 第一回合开始

**9. 商店门控**

商店仅在击败对手 1 到 total_opponents-1 后触发。击败最后一个对手后直接进入 VICTORY，不进入商店。共 total_opponents-1 次商店访问（默认 7 次）。

**10. 对手序号验证**

`opponent_number` 必须在 [1, total_opponents] 范围内。超出范围的调用为非法——记录错误日志，对局不继续。`total_opponents` 的安全范围为 [3, 8]，受 `ai_hp_scaling` 查找表条目数约束。

**11. 对局级只读数据**

本系统为以下系统提供只读数据：
- 牌桌 UI：`opponent_number`、`total_opponents`、`opponents_defeated`（进度显示）
- 筹码经济：`opponent_number`（victory_bonus 计算参数）
- 战斗状态：`opponent_number`（ai_hp_scaling 查找参数）
- AI 对手：`opponent_number`（牌组难度参数选择）

### States and Transitions

```
NEW_GAME
    │ 初始化序列完成
    ▼
OPPONENT_N (N = opponent_number)
    │
    ├─ round_result=CONTINUE
    │   → 发出 round_continue()
    │   → 保持 OPPONENT_N（回合管理处理下一回合）
    │
    ├─ round_result=PLAYER_WIN AND N < total_opponents
    │   │ 发出 begin_opponent_transition(N)
    │   ▼
    │ SHOP
    │   │ 回合管理执行: on_opponent_defeated → 商店 → 新对手初始化
    │   │ 商店关闭
    │   │ opponent_number += 1
    │   │ 发出 opponent_ready(N+1)
    │   ▼
    │ OPPONENT_N+1
    │
    ├─ round_result=PLAYER_WIN AND N == total_opponents
    │   │ 发出 match_ended(VICTORY)
    │   ▼
    │ VICTORY (终态)
    │
    └─ round_result=PLAYER_LOSE
        │ 发出 match_ended(GAME_OVER)
        ▼
        GAME_OVER (终态)
```

**状态不变量：**
- OPPONENT_N 是唯一活跃游戏状态，SHOP 是暂停状态
- 终态（VICTORY / GAME_OVER）不可逆转，只能通过 NEW_GAME 重新开始
- `opponent_number` 仅在对手转换完成后递增（商店关闭后）
- 本系统不持有 HP、防御、筹码等可变战斗/经济状态

### Interactions with Other Systems

| 系统 | 本系统接收 | 本系统提供 | 触发时机 |
|------|-----------|-----------|---------|
| 回合管理 (#13) | 无（发出指令，不接收回调） | `round_continue()`, `begin_opponent_transition(N)`, `opponent_ready(N+1)`, `match_ended(result)` | round_result 事件后 |
| 战斗状态系统 (#7) | 无直接交互 | `opponent_number`（只读，用于 ai_hp_scaling 查找） | 对手初始化时 |
| 筹码经济系统 (#10) | 无直接交互 | `opponent_number`（只读，用于 victory_bonus 计算） | 对手转换时 |
| AI 对手系统 (#12) | 无直接交互 | `opponent_number`（只读，用于难度参数选择） | 对手初始化时 |
| 商店系统 (#11) | 商店关闭信号 | 商店触发指令（通过回合管理中转） | PLAYER_WIN 且非最终对手时 |
| 牌桌 UI (#15) | 无 | `opponent_number`, `total_opponents`, `opponents_defeated`, `match_state` | 状态变化时 |
| 卡牌数据模型 (#1) | 无直接交互 | 无直接交互 | 通过回合管理间接协调 |

## Formulas

本系统不定义复杂的计算公式——所有数值缩放已委托给子系统：AI HP 缩放（战斗状态系统）、AI 难度参数（AI 对手系统）、胜利奖励（筹码经济系统）。本系统仅维护以下推导字段和验证逻辑。

### 1. 已击败对手数 (opponents_defeated)

The `opponents_defeated` formula is defined as:

`opponents_defeated = opponent_number - 1`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| opponent_number | N | int | [1, total_opponents] | 当前对手序号 |

**Output Range:** [0, total_opponents - 1]。初始 = 0，每击败一个对手后递增。
**示例:** opponent_number=5 → opponents_defeated=4（已击败对手 1-4）。

### 2. 剩余商店访问 (shop_visits_remaining)

The `shop_visits_remaining` formula is defined as:

`shop_visits_remaining = total_opponents - opponent_number`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| total_opponents | T | int | 默认 8 | 需击败的对手总数 |
| opponent_number | N | int | [1, T] | 当前对手序号 |

**Output Range:** [0, T-1]。对手 1 = 7 次剩余，对手 8 = 0 次剩余。
**示例:** total_opponents=8, opponent_number=3 → shop_visits_remaining=5。

### 3. 对手序号验证 (is_valid_opponent)

The `is_valid_opponent` formula is defined as:

`is_valid_opponent(n) = (n ≥ 1 AND n ≤ total_opponents)`

**Variables:**
| Variable | Symbol | Type | Range | Description |
|----------|--------|------|-------|-------------|
| n | N | int | — | 待验证的对手序号 |
| total_opponents | T | int | [3, 8] | 受 ai_hp_scaling 查找表条目数约束 |

**Output:** 布尔值。非法值触发错误日志，对局不继续。

## Edge Cases

- **If `round_result` 在 SHOP 状态到达**: 拒绝事件。记录警告日志（当前状态、opponent_number、收到的结果）。不发生状态转换。此防护防止商店期间的竞态条件。

- **If `round_result` 在 VICTORY 或 GAME_OVER 终态到达**: 静默丢弃。终态不可逆，只能通过 NEW_GAME 重新开始。

- **If `opponent_number` 因编程错误变为 0 或超过 `total_opponents`**: 视为无效状态。记录错误。强制 `match_state = GAME_OVER`，UI 显示通用错误信息。不可恢复——`ai_hp_scaling` 查找会越界。

- **If `total_opponents` 被调到 [3, 8] 范围外**: 在 NEW_GAME → OPPONENT_1 转换时钳制：< 3 钳制到 3，> 8 钳制到 8。记录警告。`ai_hp_scaling` 查找表只有 8 条目。

- **If 游戏初始化在 8 步中第 K 步失败**: 中止初始化，保持 `match_state = NEW_GAME`。不创建部分游戏状态。UI 报告初始化失败。无中间状态——游戏要么进入 OPPONENT_1，要么留在 NEW_GAME。

- **If 商店阶段崩溃或玩家中途退出**: `match_state` 保持 SHOP，`opponent_number` 保持已击败对手编号（尚未递增）。这是最简单的回滚点——除筹码余额外，无对手初始化发生。保存/恢复（若实现）恢复到商店状态。对局进度系统保证状态不变量，不拥有保存/恢复逻辑。

- **If `total_opponents` = 3（最小值）**: 对手 1 → 商店 → 对手 2 → 商店 → 对手 3 → VICTORY。共 2 次商店访问。`ai_hp_scaling` 使用前 3 条 [80, 100, 120]。最终 Boss 仅 120 HP——更短更轻松的对局。

- **If 玩家在对手 1 第一回合即死亡**: 有效 GAME_OVER。0 次商店访问、1 回合、初始资源。作为教学时刻存在——"爆牌有代价"。

- **If 击败最后一个对手时玩家 HP 也为 0**: 战斗状态系统保证同时死亡映射为 `PLAYER_LOSE`（非 `PLAYER_WIN`）。本系统不会在 opponent_number=total_opponents 时收到"同时死亡的 PLAYER_WIN"。胜利条件要求 `round_result == PLAYER_WIN`。

- **If 对手转换期间保存且恢复加载此中间状态**: `opponent_number` 已递增但子系统初始化可能未完成。恢复时防御性检查：若子系统对手初始化未运行，触发完整的对手初始化序列。此为架构层面问题，需与技术服务商确认。当前记录为"如有保存/恢复则必需"。

- **If 商店系统报告完成但筹码/HP 状态不一致**: 对局进度不验证子系统状态——它只响应商店关闭信号前进。子系统一致性由商店系统和筹码经济系统负责。

- **If UI 在状态转换帧查询 `opponents_defeated`**: `opponents_defeated = opponent_number - 1` 为计算属性，非存储值。UI 永远看到一致值——`opponent_number` 在商店关闭后才递增。

## Dependencies

**上游依赖（本系统依赖）:**

| 系统 | 依赖类型 | 接口 | GDD 状态 |
|------|---------|------|---------|
| 回合管理 (#13) | 硬 | 消费 `round_result` 事件 (result, opponent_number, round_number, player_hp, ai_hp) | 已设计 |
| 战斗状态系统 (#7) | 硬 | 读取 `ai_hp_scaling(opponent_number)` 作为对手初始化参数（通过回合管理中转） | 已设计 |
| 筹码经济系统 (#10) | 硬 | 读取 `victory_bonus(opponent_number)` 作为对手转换参数（通过回合管理中转） | 已设计 |
| AI 对手系统 (#12) | 硬 | 读取 `opponent_number` 选择难度参数表（通过回合管理中转） | 已设计 |

**下游依赖（被依赖）:**

| 系统 | 依赖类型 | 接口 | GDD 状态 |
|------|---------|------|---------|
| 牌桌 UI (#15) | 软 | 读取 `opponent_number`, `total_opponents`, `opponents_defeated`, `match_state` 用于进度显示 | 已设计 |
| 商店系统 (#11) | 软 | 读取 `shop_visits_remaining` 了解剩余商店次数；本系统决定商店触发时机 | 已设计 |

**双向依赖验证:**

| 系统 | 本文档列出 | 对方文档列出本系统 | 状态 |
|------|-----------|-------------------|------|
| 回合管理 | 上游硬依赖 | ✓ 下游（消费 round_result）| 需更新 — 回合管理 GDD 中对局进度为"未设计"，需更新为"已设计"并调整 Rule 8-10 的所有权说明 |
| 战斗状态系统 | 上游硬依赖 | ✓ 下游（提供 opponent_number → ai_hp_scaling） | 一致 |
| 筹码经济系统 | 上游硬依赖 | ✓ 下游（提供 opponent_number → victory_bonus） | 一致 |
| AI 对手系统 | 上游硬依赖 | ✓ 下游（提供 opponent_number → 难度参数选择） | 一致 |
| 牌桌 UI | 下游软依赖 | ✓ 上游（读取 opponent_number, total_opponents） | 一致 |
| 商店系统 | 下游软依赖 | ✓ 上游（商店触发时机由对局进度决定） | 一致 |

## Tuning Knobs

| 调参点 | 类型 | 默认值 | 安全范围 | 影响什么 |
|--------|------|--------|----------|---------|
| `total_opponents` | int | 8 | 3–8 | 需击败的对手数量。调高延长对局时间和构筑深度，调低变为快速体验。受 `ai_hp_scaling` 查找表条目数约束（当前 8 条）。 |

**依赖系统的调参点（本系统消费但不拥有）:**

| 调参点 | 来源 | 本系统如何消费 |
|--------|------|--------------|
| `player_max_hp` | 战斗状态系统 | 游戏初始化时设置玩家 HP |
| `initial_chips` | 筹码经济系统 | 游戏初始化时设置起始筹码 |
| `ai_hp_scaling` | 战斗状态系统 | 对手转换时初始化 AI HP（查找表 [80-300]） |
| `victory_base` / `victory_scale` | 筹码经济系统 | 对手转换时计算胜利奖励（默认 50 + 25×n） |
| `ai_stamp_prob_table` | AI 对手系统 | 对手转换时 AI 牌组生成参数 |
| `ai_quality_prob_table` | AI 对手系统 | 对手转换时 AI 牌组生成参数 |

## Visual/Audio Requirements

**视觉反馈:**
- 对手击败：对手头像/血条播放碎裂消散动画（≤ 1 秒），随后显示"对手 N 击败！"文字弹出
- 对局胜利：金色光环从牌桌中心扩散 + "胜利"文字弹出 + 烟花粒子效果（3 秒）
- 游戏失败：屏幕边缘泛红 + 画面缓慢变灰 + "游戏结束"文字渐入（2 秒）
- 新对手登场：对手头像从右侧滑入 + 血条从 0 增长到 max_hp 的填充动画（0.5 秒）
- 进度变化：进度指示器（对手 N/8）在对手转换时播放简短的高亮闪烁

**音频反馈:**
- 对手击败：短促的胜利号角（`opponent_defeated.wav`）
- 对局胜利：完整的胜利乐章（`match_victory.wav`，5-8 秒）
- 游戏失败：低沉的失败音效（`match_game_over.wav`）
- 新对手登场：紧张的鼓点（`opponent_enter.wav`）

## UI Requirements

- **进度指示器**: 牌桌顶部或侧边显示"对手 N / 8"进度条。已完成对手为绿色，当前对手为金色，未到达对手为灰色
- **对手信息面板**: 显示当前对手的 HP、已击败标志。对手转换时短暂显示下一个对手的预览信息
- **终局屏幕**: VICTORY 显示统计摘要（击败对手数、总回合数、最终筹码余额）。GAME_OVER 显示"再试一次"按钮
- **对手转换动画**: 击败 → 奖励数字飘入 → 商店入口 → 商店关闭 → 新对手登场。转换序列不可跳过（≤ 3 秒）

> **UX Flag — 对局进度系统**: This system has UI requirements. In Phase 4 (Pre-Production), run `/ux-design` to create a UX spec for the match progression screens before writing epics. Stories that reference match progression UI should cite `design/ux/match-progression.md`, not the GDD directly.

## Acceptance Criteria

**核心规则验证:**

- **AC-1 宏观状态机**: 系统仅消费 `round_result` 事件，不直接调用战斗状态、筹码经济、AI 对手等子系统接口。系统状态仅含 `match_state`、`opponent_number`、`total_opponents`，不持有 HP、防御、筹码等可变状态。
- **AC-2 五状态枚举**: 状态精确为 NEW_GAME、OPPONENT_N、SHOP、VICTORY、GAME_OVER 五种，无多余或缺失状态。
- **AC-3 opponent_number 权威来源**: 本系统为 `opponent_number` 的唯一权威来源。子系统通过只读接口获取，不可外部修改。范围始终为 [1, total_opponents]。
- **AC-4 round_result 映射**: CONTINUE → `round_continue()` + 保持 OPPONENT_N。PLAYER_WIN + N < total → `begin_opponent_transition(N)`。PLAYER_WIN + N == total → `match_ended(VICTORY)`。PLAYER_LOSE → `match_ended(GAME_OVER)`。
- **AC-5 对手转换序列**: 胜利奖励注入 → 商店 → 新对手初始化 → `opponent_ready(N+1)`。`opponent_number` 在商店关闭后才递增，不在进入商店时递增。
- **AC-6 胜利条件**: 仅当 `opponent_number == total_opponents` 且 `round_result == PLAYER_WIN` 时进入 VICTORY。两个条件缺一不可。
- **AC-7 失败条件**: 任意对手序号下 `round_result == PLAYER_LOSE` 均触发 GAME_OVER。
- **AC-8 游戏初始化**: NEW_GAME 按 8 步序列初始化。完成后：玩家 HP=100，AI HP=80，筹码=100，opponent_number=1。初始化失败则保持 NEW_GAME，不创建部分状态。
- **AC-9 商店门控**: 击败对手 1-7 后进入 SHOP（默认 8 对手）。击败对手 8 后直接 VICTORY，不进入商店。总商店访问 = total_opponents - 1。
- **AC-10 对手序号验证**: `opponent_number` 越界时记录错误并强制 GAME_OVER。`total_opponents` 超出 [3, 8] 时在初始化时钳制并记录警告。
- **AC-11 只读数据**: UI 和子系统通过 getter 获取 `opponent_number`、`total_opponents`、`opponents_defeated`、`match_state`，无 setter 暴露。

**公式验证:**

- **AC-F1 opponents_defeated**: opponent_number=1 → 0, opponent_number=8 → 7。始终 = opponent_number - 1，无独立赋值路径。
- **AC-F2 shop_visits_remaining**: total=8, opponent=1 → 7, opponent=3 → 5, opponent=8 → 0。始终 = total_opponents - opponent_number。
- **AC-F3 is_valid_opponent**: n=0 → false, n=1 → true, n=total → true, n=total+1 → false。非法值记录错误日志，对局不继续。

**状态机验证:**

- **AC-T1 NEW_GAME → OPPONENT_1**: 初始化完成后 match_state 变为 OPPONENT_N，opponent_number=1。
- **AC-T2 OPPONENT_N → SHOP**: PLAYER_WIN + N < total 时进入 SHOP，opponent_number 不变。
- **AC-T3 OPPONENT_N → VICTORY**: PLAYER_WIN + N == total 时进入 VICTORY（终态，不可逆）。
- **AC-T4 SHOP → OPPONENT_N+1**: 商店关闭后 opponent_number += 1，发出 `opponent_ready(N+1)`。
- **AC-T5 OPPONENT_N → GAME_OVER**: PLAYER_LOSE 时进入 GAME_OVER（终态，不可逆）。
- **AC-T6 终态不变量**: VICTORY/GAME_OVER 下收到任何 round_result 均不改变状态。

**边缘情况验证:**

- **AC-E1 SHOP 状态收到 round_result**: 拒绝事件 + 警告日志 + 无状态转换。
- **AC-E2 终态收到 round_result**: 静默丢弃，无日志，状态不变。
- **AC-E3 opponent_number 越界**: 记录错误 + 强制 GAME_OVER + UI 显示通用错误。
- **AC-E4 total_opponents 越界钳制**: NEW_GAME 时 < 3 钳制到 3，> 8 钳制到 8，记录警告。
- **AC-E5 初始化部分失败**: 保持 NEW_GAME，不创建部分游戏状态。
- **AC-E6 商店崩溃/退出**: match_state 保持 SHOP，opponent_number 保持已击败编号（未递增）。
- **AC-E7 最小对局 (total=3)**: 对手 1 → 商店 → 对手 2 → 商店 → 对手 3 → VICTORY。共 2 次商店。
- **AC-E8 对手 1 首回合死亡**: 正常 GAME_OVER，0 次商店。
- **AC-E9 同时死亡**: 本系统仅按 round_result 映射表处理。战斗状态系统保证同时死亡映射为 PLAYER_LOSE。
- **AC-E10 UI 查询一致性**: `opponents_defeated` 为计算属性，UI 永远看到一致值。

**集成验证:**

- **AC-I1 与回合管理协调**: 对手转换序列中各子系统调用由回合管理执行，本系统仅发出指令。round-management 收到 `begin_opponent_transition(N)` 后正确执行奖励注入、商店触发、新对手初始化。
- **AC-I2 与牌桌 UI 集成**: UI 正确读取 `opponent_number`、`total_opponents`、`opponents_defeated` 并渲染进度显示。对手转换时进度指示器正确更新。

## Open Questions

- [ ] **回合管理 GDD 的 Rule 8-10 需要更新** — 对局进度系统提取了对手转换、游戏结束条件和初始化序列的所有权。回合管理 GDD 需要相应更新：Rule 8 改为"消费对局进度的 `begin_opponent_transition` 指令后执行转换序列"，Rule 9 改为"发出 round_result 供对局进度决策"，Rule 10 改为"消费对局进度的 NEW_GAME 初始化指令后执行回合级初始化"。负责人：game designer，目标：本 GDD 完成后立即更新。
- [ ] **opponent_number 的所有权转移** — 当前回合管理 GDD 的调参点和 AC 引用 `opponent_number` 为自身状态。需要确认：回合管理是否改为从对局进度系统查询此值，还是保持本地副本（以只读方式同步）。负责人：game designer + gameplay programmer，目标：架构阶段。
- [ ] **保存/恢复是否需要** — 当前设计无保存/恢复。20-40 分钟的对局长度是否需要中断恢复？如果需要，对局进度系统需要定义持久化字段（match_state, opponent_number, total_opponents）。负责人：game designer，目标：Alpha 阶段前决策。
- [ ] **匹配级别统计数据** — 是否需要追踪总回合数、总筹码收入/支出等统计数据用于终局显示？当前设计不含此功能。若添加，需定义数据来源和存储方式。负责人：game designer，目标：Alpha 阶段后根据玩家反馈决定。
- [ ] **total_opponents 调优是否影响 AI 难度表** — 当前 `ai_hp_scaling` 有 8 条固定条目。如果 `total_opponents` 调为 5，是否截取前 5 条 [80, 100, 120, 150, 180]（对手 5 仅 180 HP，偏弱）还是重新分布到 [80, 150, 200, 260, 300]（更均匀）？负责人：game designer，目标：Alpha 阶段平衡调优。
