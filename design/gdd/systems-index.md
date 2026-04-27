# Systems Index: 决胜21点

> **Status**: Approved
> **Created**: 2026-04-23
> **Last Updated**: 2026-04-24
> **Source Concept**: design/gdd/game-concept.md

---

## Overview

《决胜21点》是一款策略卡牌对战游戏，围绕传统 21 点规则构建，增加花色战斗效果、牌型倍率、卡牌印记/卡质构筑、商店系统、道具系统等 Roguelike 元素。系统分为 5 层 17 个系统：从卡牌数据模型和战斗状态的基础层，到结算引擎和排序的核心层，再到商店、道具和 AI 对手的功能层，最终通过回合管理和对局进度串联为完整游戏，由牌桌 UI 呈现给玩家。

核心循环：**对战回合 → 结算 → 商店构筑 → 下一回合 → 击败最终对手**

---

## Systems Enumeration

| # | System Name | Category | Priority | Status | Design Doc | Depends On |
|---|-------------|----------|----------|--------|------------|------------|
| 1 | 卡牌数据模型 | Core | MVP | Designed | design/gdd/card-data-model.md | — |
| 2 | 点数计算引擎 | Core | MVP | Designed | design/gdd/point-calculation-engine.md | 1 |
| 3 | 牌型检测系统 | Core | Vertical Slice | Designed | design/gdd/hand-type-detection.md | 1, 2 |
| 4 | 印记系统 | Core | Vertical Slice | Designed | design/gdd/stamp-system.md | 1 |
| 5 | 卡质系统 | Core | Vertical Slice | Designed* | design/gdd/card-quality-system.md | 1 |
| 6 | 结算引擎 | Core | MVP | Designed | design/gdd/resolution-engine.md | 1, 2, 3, 4, 5, 6a, 7 |
| 6a | 卡牌排序系统 | Core | MVP | Designed | design/gdd/card-sorting-system.md | 1, 4 |
| 7 | 战斗状态系统 | Core | MVP | Designed* | design/gdd/combat-system.md | — |
| 8 | 特殊玩法系统 | Gameplay | Vertical Slice | Designed | design/gdd/special-plays-system.md | 1, 2, 6, 7 |
| 9 | 边池系统 | Economy | Alpha | Designed | design/gdd/side-pool.md | 1, 10 |
| 10 | 筹码经济系统 | Economy | MVP | Needs Revision | design/gdd/chip-economy.md | 1, 6 |
| 11 | 商店系统 | Economy | Alpha | Designed | design/gdd/shop-system.md | 1, 4, 5, 7, 10 |
| 12 | AI 对手系统 | Gameplay | MVP | Designed | design/gdd/ai-opponent.md | 2, 3, 8 |
| 13 | 回合管理 | Core | MVP | Needs Revision | design/gdd/round-management.md | 6, 7, 8, 9, 10, 12 |
| 14 | 对局进度系统 | Progression | Alpha | Designed | design/gdd/match-progression.md | 7, 10, 12, 13 |
| 15 | 牌桌 UI 系统 | UI | MVP | Designed | design/gdd/table-ui.md | 1, 6, 7, 13, 14 |
| 16 | 道具系统 | Gameplay | Alpha | Approved | design/gdd/item-system.md | 1, 6a, 7, 10, 11 |

> \* `Designed*` = cross-GDD review flagged warnings (see design/gdd/gdd-cross-review-2026-04-26.md)

---

## Categories

| Category | Description | Systems |
|----------|-------------|---------|
| **Core** | 基础系统和核心机制 | 卡牌数据模型, 点数计算引擎, 牌型检测, 印记, 卡质, 结算引擎, 卡牌排序, 战斗状态, 回合管理 |
| **Gameplay** | 让游戏有策略深度的系统 | 特殊玩法, AI 对手, 道具 |
| **Economy** | 资源流转和经济系统 | 筹码经济, 边池, 商店 |
| **Progression** | 游戏进程和成长 | 对局进度 |
| **UI** | 玩家交互界面 | 牌桌 UI |

---

## Priority Tiers

| Tier | Definition | Systems |
|------|------------|---------|
| **MVP** | 可玩的最小单回合体验 — 能测试"这好不好玩" | 1, 2, 6, 6a, 7, 10, 12, 13, 15 (9 systems) |
| **Vertical Slice** | 完整单回合 + 深度机制 — 展示完整体验 | 3, 4, 5, 8 (4 systems) |
| **Alpha** | 完整游戏循环 + 进度系统 — 全功能范围 | 9, 11, 14, 16 (4 systems) |

---

## Dependency Map

### Foundation Layer (no dependencies)

1. **卡牌数据模型** — 一切系统的基础数据结构：花色、点数、印记、卡质、卡质等级
2. **战斗状态系统** — HP、防御值 — 独立于其他系统的纯状态追踪

### Core Layer (depends on Foundation)

3. **点数计算引擎** — depends on: 1
4. **牌型检测系统** — depends on: 1, 2
5. **印记系统** — depends on: 1
6. **卡质系统** — depends on: 1
7. **卡牌排序系统** — depends on: 1, 4
8. **结算引擎** — depends on: 1, 2, 3, 4, 5, 6a, 7

### Feature Layer (depends on Core)

9. **特殊玩法系统** — depends on: 1, 2, 6, 7
10. **边池系统** — depends on: 1, 10
11. **筹码经济系统** — depends on: 1, 6
12. **商店系统** — depends on: 1, 4, 5, 7, 10
13. **AI 对手系统** — depends on: 2, 3, 8
14. **道具系统** — depends on: 1, 6a, 7, 10, 11

### Game Flow Layer (depends on Feature)

14. **回合管理** — depends on: 6, 7, 8, 9, 10, 12
15. **对局进度系统** — depends on: 7, 10, 12, 13

### Presentation Layer (depends on Game Flow)

17. **牌桌 UI 系统** — depends on: 1, 6, 7, 13, 14

---

## Recommended Design Order

| Order | System | Priority | Layer | Agent(s) | Est. Effort |
|-------|--------|----------|-------|----------|-------------|
| 1 | 卡牌数据模型 | MVP | Foundation | game-designer | S |
| 2 | 战斗状态系统 | MVP | Foundation | game-designer | S |
| 3 | 点数计算引擎 | MVP | Core | game-designer | S |
| 4 | 印记系统 | Vertical Slice | Core | game-designer | M |
| 5 | 卡牌排序系统 | MVP | Core | game-designer | S |
| 6 | 牌型检测系统 | Vertical Slice | Core | game-designer | M |
| 7 | 卡质系统 | Vertical Slice | Core | game-designer | M |
| 8 | 结算引擎 | MVP | Core | game-designer | L |
| 9 | 筹码经济系统 | MVP | Feature | game-designer + economy-designer | S |
| 10 | 特殊玩法系统 | Vertical Slice | Feature | game-designer | M |
| 11 | AI 对手系统 | MVP | Feature | ai-programmer + game-designer | L |
| 12 | 边池系统 | Alpha | Feature | game-designer | S |
| 13 | 商店系统 | Alpha | Feature | game-designer + economy-designer | M |
| 14 | 回合管理 | MVP | Game Flow | game-designer + gameplay-programmer | L |
| 15 | 对局进度系统 | Alpha | Game Flow | game-designer | M |
| 16 | 牌桌 UI 系统 | MVP | Presentation | ux-designer + ui-programmer | L |

---

## Circular Dependencies

- None found. Counter-attack resolves as the final step of the resolution engine, not as a separate callback.

---

## High-Risk Systems

| System | Risk Type | Risk Description | Mitigation |
|--------|-----------|-----------------|------------|
| 结算引擎 | Design | 牌型×印记×卡质×排序的组合爆炸 — 交互规则复杂，容易遗漏边界情况 | 早期原型验证，完整边界用例测试 |
| AI 对手系统 | Design | AI 需要在不完全信息下做决策（对手手牌不可见），且难度需可调 | 先实现简单规则 AI，再迭代策略 |
| 商店系统 | Scope | 定价公式涉及印记/卡质/提纯的组合计算，数值平衡难度大 | 用 economy-designer 审查定价公式 |

---

## Progress Tracker

| Metric | Count |
|--------|-------|
| Total systems identified | 17 |
| Design docs started | 16 |
| Design docs reviewed | 1 |
| Design docs approved | 1 |
| Cross-GDD review | 2026-04-26 — CONCERNS (0 blockers, 17 warnings) |
| MVP systems designed | 9/9 |
| Vertical Slice systems designed | 4/4 |
| Alpha systems designed | 4/4 |

---

## Next Steps

- [ ] Design MVP-tier systems first (use `/design-system [system-name]`)
- [ ] Start with: `/design-system card-data-model`
- [ ] Run `/design-review` on each completed GDD
- [ ] Run `/gate-check pre-production` when MVP systems are designed
- [ ] Prototype the Resolution Engine early (`/prototype resolution-engine`)
