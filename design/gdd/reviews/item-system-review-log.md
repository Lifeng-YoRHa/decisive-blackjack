# Review Log: 道具系统 (item-system)

---

## Review — 2026-04-26 — Verdict: NEEDS REVISION
Scope signal: M
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director
Blocking items: 5 | Recommended: 8
Summary: 道具系统 GDD 结构完整（8/8 sections），7 种道具规则清晰，一致性检查通过无冲突。主要问题集中在密码锁锁定目标歧义（已修订为卡牌实例锁定）、厚衣服叠加无上限（用户确认有意设计）、微缩炸药经济亏损（用户确认应急定位）、以及整体经济平衡（创意总监建议 25-30% 降价，用户未调整）。排序计时器交互已文档化但不调整。
Prior verdict resolved: First review

### Blocking Items Resolved

| # | Issue | Source | Resolution |
|---|-------|--------|------------|
| 1 | 厚衣服叠加无上限，防御值可无限增长 | [systems-designer] | 用户决策：不设上限，允许同回合多次使用同种道具 |
| 2 | 微缩炸药净经济亏损，被商店覆盖功能碾压 | [economy-designer] | 用户决策：爆牌应急措施，经济亏损是设计意图 |
| 3 | 密码锁锁定目标歧义（位置 vs 卡牌实例） | [game-designer] | 已修订：改为按卡牌实例锁定，更新接口为 set_card_locked(card_instance, bool) |
| 4 | 排序计时器与道具交互未说明 | [game-designer] | 用户决策：保持现状不调整，已在 Rule 4 文档化 |
| 5 | 整体经济平衡 — 道具 60-150 筹码 vs 永久强化竞争 | [creative-director] | 开放议题：用户拒绝单项调价，建议后续经济迭代时重新评估 |

### Recommended Revisions (not yet applied)

1. 拆分 5 个混合 UI/逻辑断言的 AC（AC-09/10/11）为独立可测试条目 — [qa-lead]
2. 在 combat-system.md 数据模型中定义 pending_defense 字段 — [systems-designer]
3. 补充 ~20 条缺失 AC 覆盖（负面测试、叠加上限、经济边界等） — [qa-lead]
4. 破坏性道具增加确认对话框规格 — [game-designer]
5. 文档化 AI 不使用道具对难度曲线的影响 — [game-designer]
6. 经济再平衡：创意总监建议降价 25-30% 或增加独特效果 — [economy-designer]

### Edits Applied to item-system.md

1. 微缩炸药核心用途补充：移除手牌中的牌可降低点数总和，在 Phase 7 爆牌检测前可防止爆牌
2. 密码锁改为按卡牌实例锁定（非位置锁定）
3. thick_clothes_defense 变量表修正：防御范围从 "0" 改为 "0 ~ defense_bonus × n_thick_clothes"
4. 排序计时器交互说明添加至 Rule 4（道具使用消耗排序计时器 ~3-5s）
5. 厚衣服+爆牌边界用例添加
6. 微缩炸药+牌型倍率边界用例添加（牌型在 Phase 5 锁定，道具使用不重检）
7. pending_defense 数据归属：存储于战斗状态系统，queue_defense(PLAYER, amount) FIFO 执行
8. 密码锁接口更新：set_card_locked(card_instance, true/false)

### Status
- Systems-index updated: In Review
- Registry: 12 constants registered, no conflicts
- Cross-references updated: shop-system, combat-system, card-sorting-system
- Re-review pending: recommended in new session after /clear

---

## Review — 2026-04-26 — Verdict: NEEDS REVISION (Re-review #1)
Scope signal: M
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director
Blocking items: 2 | Recommended: 12
Summary: 重审发现 2 个跨系统接口阻塞项：(1) ITEM_PURCHASE 交易类型在 chip-economy 中未定义，已统一改为 SHOP_PURCHASE；(2) queue_defense/pending_defense 接口未在 combat-system 数据模型中定义，已补充字段、方法和状态图。创意总监认定其余 12 项建议为经济平衡/AC 质量/设计打磨问题，应在 playtest 迭代中解决。
Prior verdict resolved: Yes — prior 5 blockers all addressed, 2 new blockers found and fixed

### Blocking Items Resolved

| # | Issue | Source | Resolution |
|---|-------|--------|------------|
| 1 | `ITEM_PURCHASE` 交易类型在 chip-economy 中不存在 | [game-designer + systems-designer + economy-designer] | 统一改为 `SHOP_PURCHASE`（item-system.md 2 处） |
| 2 | `queue_defense` / `pending_defense` 接口未在 combat-system 定义 | [systems-designer] | combat-system.md 新增 `pending_defense` 字段、`queue_defense()` 方法、状态图步骤、重置规则 |

### Specialist Disagreements

| Issue | [game-designer] | [economy-designer] | [creative-director] Resolution |
|-------|-----------------|-------------------|-------------------------------|
| Padlock 战术价值 | BLOCKING (幻想不匹配) | RECOMMENDED (定价过高) | 降为 RECOMMENDED — 功能可用但偏弱 |
| Energy Drink 定价 | 未单独标记 | BLOCKING (被商店治疗碾压) | 降为 RECOMMENDED — 应急定位合理 |
| Thick Clothes 性价比 | 未单独标记 | BLOCKING (vs SHIELD 7x 差距) | 保留 RECOMMENDED — playtest 验证 |

### Remaining Recommended Items (deferred to playtest iteration)

1. Mini Explosive 用途描述矛盾（爆牌避免 vs 手牌操控）— 措辞修复
2. Thick Clothes 防御公式范围应改为 "0 ~ unbounded" — [systems-designer]
3. Energy Drink 应急定位应在 GDD 中明确说明 — [economy-designer]
4. Thick Clothes vs SHIELD stamp 机会成本 (~7x) — [economy-designer]
5. Padlock 仅阻止 Pass 1，考虑加强或降价 — [game-designer + economy-designer]
6. 全道具投资成本 vs 永久强化竞争 — [economy-designer]
7. 破坏性道具增加确认对话框规格 — [game-designer]
8. AI 不使用道具对难度曲线的影响需文档化 — [game-designer]
9. X-Ray 空抽牌堆无 UI 禁用规则 — [systems-designer]
10. add_defense vs queue_defense 命名已在本次修订中统一 — [systems-designer]
11. AC 质量清理（拆分 UI/逻辑、补充缺失 AC）— [qa-lead]
12. Knife 扁平伤害不随 AI HP 缩放 — [economy-designer]

### Files Modified This Review

- `design/gdd/item-system.md` — 3 处编辑（SHOP_PURCHASE ×2, queue_defense）
- `design/gdd/combat-system.md` — 5 处编辑（pending_defense 字段、queue_defense 方法、交互表、状态图、重置规则）

### Status
- Systems-index: In Review（等待新会话重审通过后标记 Approved）
- Re-review #2 pending: 建议 /clear 后运行 /design-review item-system

---

## Review — 2026-04-26 — Verdict: NEEDS REVISION (Re-review #2)
Scope signal: M
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director
Blocking items: 5 | Recommended: 11
Summary: 重审 #2 发现 5 个文档一致性阻塞项：(1) 微缩炸药用途矛盾（line 77 vs 313）——point_result 在 Phase 5 冻结，Phase 6 移除卡牌不能改变爆牌状态，已重写 line 77；(2) shop-system.md 仍用 ITEM_PURCHASE，已统一为 SHOP_PURCHASE；(3) Rule 10 line 135 "商店可查看和使用"与 Rule 4 矛盾，已移除"和使用"；(4) set_card_locked 接口未在 card-sorting-system 声明，已补充锁定字段、接口和 Pass 1 检查逻辑；(5) PAIR 倍率在微缩炸药移除后的行为未定义，已添加明确规则（倍率保留在存活卡牌上）。创意总监确认无基础设计缺陷，全部为文档一致性问题。
Prior verdict resolved: Yes — prior 2 blockers from re-review #1 all addressed, 5 new blockers found and fixed

### Blocking Items Resolved

| # | Issue | Source | Resolution |
|---|-------|--------|------------|
| 1 | 微缩炸药 line 77 与 line 313 爆牌避免用途矛盾 | [game-designer + systems-designer + qa-lead] | 重写 line 77：明确 point_result 在 Phase 5 冻结，移除卡牌不改变爆牌状态 |
| 2 | shop-system.md line 136 仍用 ITEM_PURCHASE | [all 4 specialists] | 统一改为 SHOP_PURCHASE |
| 3 | Rule 10 "商店可查看和使用"与 Rule 4 "仅排序阶段可用"矛盾 | [qa-lead] | 移除"和使用"，改为"商店购物期间可查看库存状态" |
| 4 | set_card_locked 接口未在 card-sorting-system 声明 | [systems-designer] | card-sorting-system.md 新增锁定瞬态字段、接口声明、Pass 1 检查逻辑、状态图更新 |
| 5 | PAIR 倍率在微缩炸药移除一张牌后的行为未定义 | [qa-lead] | 新增边界用例：倍率保留在存活卡牌上，不回退 |

### Specialist Disagreements

| Issue | [game-designer] | [systems-designer] | [creative-director] Resolution |
|-------|-----------------|-------------------|-------------------------------|
| Mini Explosive 可否避免爆牌 | line 313 正确（不能避免） | 取决于 point_total 何时计算 | 创意总监裁定：point_result 在 Phase 5 冻结，line 77 错误，已修正 |

### Remaining Recommended Items (deferred to playtest iteration)

1. 密码锁幻想错位 + 定价建议 100→60-70 — [game-designer + economy-designer]
2. 战斗增益道具 vs 永久印记性价比不足 — [economy-designer]
3. AI 不使用道具对难度曲线影响未文档化 — [game-designer]
4. chip_balance 范围声明 "0 ~ infinity" 应为 "0 ~ 999" — [systems-designer]
5. 缺失边界用例：AI HP=0 时使用第二把刀 — [systems-designer]
6. 缺失边界用例：厚衣服 + 黑桃黑杰克即死浪费 — [systems-designer]
7. 28 个缺失 AC（芯片经济验证、负面测试、计时器、分牌、跨回合计久性）— [qa-lead]
8. AC-09/10/11 UI/逻辑混合需拆分 — [qa-lead]
9. AC-17 冗余密码锁未明确双消耗 — [qa-lead]
10. 道具卖回机制建议（50% 退款缓解囤积陷阱）— [economy-designer]
11. 全道具定价调整建议（ED 70→50, Knife 70→50, TC 60→30, XRAY 150→80, Mirror 100→70, ME 150→80-100, Padlock 100→60）— [economy-designer]

### Files Modified This Review

- `design/gdd/item-system.md` — 4 处编辑（微缩炸药用途重写、商店阶段措辞修正、PAIR 倍率规则新增、爆牌边界用例措辞修正）
- `design/gdd/shop-system.md` — 1 处编辑（ITEM_PURCHASE → SHOP_PURCHASE）
- `design/gdd/card-sorting-system.md` — 5 处编辑（锁定瞬态字段、接口声明、AI 排序锁定检查、状态图锁定/解锁、交互表更新）

### Status
- Systems-index: In Review（等待新会话重审 #3 通过后标记 Approved）
- Re-review #3 pending: 建议 /clear 后运行 /design-review item-system

---

## Review — 2026-04-26 — Verdict: NEEDS REVISION (Re-review #3)
Scope signal: M
Specialists: game-designer, systems-designer, economy-designer, qa-lead
Review mode: Lean (no creative-director gate)
Blocking items: 2 | Recommended: 14
Summary: 重审 #3 发现 2 个文档内文本矛盾：(1) Line 77 微缩炸药描述仍含误导性手型倍率变化文字（与 lines 333-334 倍率锁定规则矛盾），已重写为明确说明倍率不变；(2) Line 273 厚衣服公式说明错误使用 add_defense() 接口名（与 line 89 的 queue_defense() 矛盾），已修正为 queue_defense 并注明间接执行。14 项建议（经济平衡、AC 质量、道具设计深度）均与前两次审查一致，维持 playtest 后迭代决策。经济分析确认所有道具在性价比上劣于永久印记/卡质投资，但用户维持当前定价。
Prior verdict resolved: Yes — prior 5 blockers from re-review #2 all addressed, 2 new text-level contradictions found and fixed

### Blocking Items Resolved

| # | Issue | Source | Resolution |
|---|-------|--------|------------|
| 1 | Line 77 "影响牌型判定（如 FLUSH ×5 降为 ×4）"与 lines 333-334 倍率锁定规则矛盾 | [game-designer + systems-designer] | 重写：改为"手牌数减少（注：牌型倍率在 Phase 5 已锁定，移除卡牌不改变已锁定的倍率——存活的卡牌仍按原倍率结算）" |
| 2 | Line 273 接口名错误：add_defense() 应为 queue_defense()（与 line 89 矛盾） | [systems-designer] | 修正为 queue_defense(PLAYER, 10) 并注明"由战斗状态系统在排序结束后 FIFO 执行 add_defense" |

### Remaining Recommended Items (deferred to playtest iteration)

1. 密码锁幻想错位 + 定价建议 100→60-70 — [game-designer + economy-designer]
2. 战斗增益道具 vs 永久印记性价比不足 — [economy-designer]
3. AI 不使用道具对难度曲线影响未文档化 — [game-designer]
4. chip_balance 范围 "0 ~ ∞" 应为 "0 ~ 999" — [systems-designer]
5. 缺失边界用例：AI HP=0 时使用第二把刀 — [systems-designer]
6. 缺失边界用例：厚衣服 + 黑桃黑杰克即死浪费 — [systems-designer]
7. ~15 个缺失 AC（手型倍率保留、负面测试、计时器、分牌、跨回合持久性、筹码边界）— [qa-lead]
8. AC-09/10/11 UI/逻辑混合需拆分 — [qa-lead]
9. AC-17 冗余密码锁未明确双消耗 — [qa-lead]
10. AC-01 未验证 spend_chips 交易类型 — [qa-lead]
11. 全道具定价调整建议（维持用户决策，playtest 后评估）— [economy-designer]
12. 道具卖回机制建议（50% 退款缓解囤积陷阱）— [economy-designer]
13. ItemInstance 缺少 uid 字段（UI 定位需要）— [systems-designer]
14. card-data-model 交互表缺少道具系统条目 — [systems-designer]

### Files Modified This Review

- `design/gdd/item-system.md` — 2 处编辑（line 77 手型倍率描述重写、line 273 接口名修正）

### Status
- Systems-index: In Review（等待 /clear 后重审 #4 通过后标记 Approved）
- Re-review #4 pending: 建议 /clear 后运行 /design-review item-system

---

## Review — 2026-04-26 — Verdict: APPROVED (Re-review #4)
Scope signal: M
Specialists: game-designer, systems-designer, economy-designer, qa-lead, creative-director
Blocking items: 0 | Recommended: 19
Summary: 第四次审查通过。前三次审查共修复 12 个文档一致性阻塞项，本次审查未发现任何文档缺陷。专家聚焦于玩法设计质量和经济平衡：(1) 密码锁幻想错位（Pass 2 自动排序使其效果微弱），(2) 小刀/能量饮料缺乏戏剧张力（结算前使用非反应性），(3) 死库存陷阱（无丢弃机制），(4) 终局筹码过剩（无高端道具）。创意总监裁定所有 19 项建议均为 playtest 验证项，GDD 已诚实记录所有已知弱点，调参点提供充分调整杠杆。Systems-index 已更新为 Approved。
Prior verdict resolved: Yes — prior 2 blockers from re-review #3 all addressed, no new blockers

### Specialist Findings (all RECOMMENDED, deferred to playtest)

| # | Finding | Source | Priority |
|---|---------|--------|----------|
| 1 | 密码锁幻想错位 — Pass 2 自动排序使其在多数场景无效 | [game-designer] | High |
| 2 | 小刀/能量饮料缺乏戏剧张力 — 结算前使用而非反应性 | [game-designer] | High |
| 3 | 30 秒计时器 + 道具使用认知过载 | [game-designer] | High |
| 4 | 死库存陷阱 — 5 槽位 + 无丢弃机制 | [economy-designer] | Medium |
| 5 | 后手补偿可能资助回血循环 | [economy-designer] | Medium |
| 6 | 终局筹码过剩无高端道具消耗口 | [economy-designer] | Medium |
| 7 | 微缩炸药战术价值不明确 | [game-designer] | Medium |
| 8 | 道具无成长维度 | [game-designer] | Low |
| 9 | purchase_price/purchase_round 字段未被读取 | [systems-designer] | Low |
| 10-19 | AC 精确性 + 覆盖缺口（11 项）| [qa-lead] | Low |

### Specialist Disagreements

无重大分歧。创意总监与 game-designer 在微缩炸药价值上有轻微分歧：game-designer 认为战术价值不明确，creative-director 认为已文档化但用途狭窄。Playtest 验证。

### Validation Criteria (playtest)

1. 玩家每局自然使用 2-3 件道具
2. 密码锁每局至少创造一个"记得住的时刻"
3. 30 秒计时器制造紧张感而非挫败感

### Files Modified This Review

- `design/gdd/systems-index.md` — #16 状态更新为 Approved，Progress Tracker 更新

### Status
- Systems-index: Approved ✓
- All 16 system GDDs complete (MVP 9/9, Vertical Slice 4/4, Alpha 4/4)
- Review log complete (4 entries)
- Recommended next: /review-all-gdds for holistic cross-GDD validation
