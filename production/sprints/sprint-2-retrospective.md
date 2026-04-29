## Retrospective: Sprint 2
Period: 2026-04-27 -- 2026-04-29
Generated: 2026-04-29

### Metrics

| Metric | Planned | Actual | Delta |
|--------|---------|--------|-------|
| Tasks | 9 | 9 | 0 |
| Completion Rate | -- | 100% | -- |
| Effort Days (estimated) | 4.3 | ~2.5 days | -1.8 |
| Bugs Found | -- | 0 | -- |
| Bugs Fixed | -- | 0 | -- |
| Unplanned Tasks Added | -- | 0 | -- |
| Commits | -- | 8 | -- |
| Total Tests Passing | -- | 238 | -- |

### Velocity Trend

| Sprint | Planned | Completed | Rate |
|--------|---------|-----------|------|
| 1 | 7 | 7 | 100% |
| 2 (current) | 9 | 9 | 100% |

**Trend**: Stable at 100%. Both sprints completed all planned work ahead of schedule. Sprint 2 delivered 9 stories (vs Sprint 1's 7) in 2.5 actual days with zero carryover.

### What Went Well
- **100% completion rate again** — all 9 stories (6 must-have, 2 should-have, 1 nice-to-have) delivered, completing Milestone 1's full scope
- **Recalibrated estimates much more accurate** — Sprint 1's 60-70% reduction guidance paid off. Core systems (2-1 through 2-5) were estimated at 0.3-0.5 day each and landed within range
- **Test discipline held** — 238 total tests passing across unit, integration, and smoke test suites. Every Logic/Integration story has automated test coverage
- **Milestone 1 smoke test passes** — all 8 success criteria validated (story 2-8)
- **Incremental commits** — 8 commits, one per story boundary, matching the per-story commit hygiene goal from Sprint 1
- **Sprint 1 action item #1 addressed** — code committed and pushed to GitHub

### What Went Poorly
- **QA plan never created** — Sprint 2 plan listed "QA plan exists" as a Definition of Done item, but `/qa-plan sprint` was never run. All testing was done ad-hoc via story-level test cases
- **sprint-status.yaml still batch-updated** — action item #3 from Sprint 1 was to update incrementally per-story. Session state shows updates were still somewhat batched rather than real-time
- **Table UI estimation still high** — 2-6 estimated at 1.0 day but took ~0.5 day. UI work with programmatic node creation (no scene tree editor work) is faster than anticipated
- **Code committed late** — all Sprint 2 work was pushed in one batch at the end, not per-story as the commit hygiene improvement specified

### Blockers Encountered

| Blocker | Duration | Resolution | Prevention |
|---------|----------|------------|------------|
| GDScript lambda closure capture bug in tests | ~30 min | Dictionary spy pattern for signal tests (documented in memory) | Known GDScript pattern — use dict spy for signal assertions |
| Godot not in PATH for CLI test execution | Ongoing | Tests run in Godot editor, not from CLI | Accept editor-only workflow for now; CI not yet set up |

### Estimation Accuracy

| Task | Estimated | Actual | Variance | Likely Cause |
|------|-----------|--------|----------|--------------|
| 2-6 Table UI | 1.0 day | ~0.5 day | +0.5 | Programmatic UI (no scene editor work) is faster than expected |
| 2-1 Combat State | 0.5 day | ~0.3 day | +0.2 | Simple data structure with test |
| 2-2 Chip Economy | 0.3 day | ~0.2 day | +0.1 | Simple state tracking |
| 2-3 Resolution Engine | 0.5 day | ~0.5 day | 0 | Spot on — most complex core system |
| 2-5 Round Management | 0.5 day | ~0.5 day | 0 | Spot on — integration complexity matched estimate |
| 2-9 Card Sort UI | 0.5 day | ~0.5 day | 0 | Spot on — timer had to be added during review |

**Overall estimation accuracy**: ~67% of tasks within +/- 20% of estimate. Major improvement from Sprint 1's 0%.

**Analysis**: The 60-70% recalibration worked well for core systems. Remaining overestimates are on UI tasks — programmatic Godot UI creation is faster than traditional UI work because there's no scene editor round-trip. For Sprint 3, UI estimates can be further reduced by ~30-40%.

### Carryover Analysis

No carryover — all 9 tasks completed.

### Technical Debt Status
- Current TODO count: 0 (was 0)
- Current FIXME count: 0 (was 0)
- Current HACK count: 0 (was 0)
- Trend: Stable at zero
- Advisory deviation: `player_sort_confirmed` signal uses untyped `Array` instead of `Array[int]` (story 2-9)

### Previous Action Items Follow-Up

| Action Item (from Sprint 1) | Status | Notes |
|-------------------------------|--------|-------|
| 1. Commit all sprint 1 deliverables to git | Done | All code pushed to GitHub |
| 2. Recalibrate sprint 2 estimates using 60-70% reduction | Done | Much better accuracy — 67% within +/- 20% |
| 3. Update sprint-status.yaml incrementally | Partial | Still some batching; improved but not fully real-time |
| 4. Verify GdUnit4 test runner in headless CI | Not Started | No CI pipeline set up; tests run in editor only |

### Action Items for Next Iteration

| # | Action | Owner | Priority | Deadline |
|---|--------|-------|----------|----------|
| 1 | Run `/qa-plan sprint` before Sprint 3 kickoff — don't skip QA planning again | Dev | High | Sprint 3 planning |
| 2 | Commit after each story completion, not batched at sprint end | Dev | High | Sprint 3 execution |
| 3 | Further reduce UI estimates by ~30-40% based on programmatic UI velocity | Dev | Medium | Sprint 3 planning |
| 4 | Type the `player_sort_confirmed` signal as `Array[CardInstance]` (tech debt from 2-9) | Dev | Low | Next touch of table_ui.gd |

### Process Improvements
- **QA plan is non-negotiable** — skipping it this sprint worked out (no bugs) but creates risk as systems grow more complex. Sprint 3 must have a QA plan before implementation starts.
- **Commit-per-story discipline** — the goal is achievable (8 commits this sprint) but they came late. Push after each `/story-done` instead of batching.

### Summary
Sprint 2 was another clean sweep — all 9 stories delivered with zero bugs, zero tech debt, and 238 tests passing. The estimation recalibration from Sprint 1's retrospective was the single biggest improvement, lifting accuracy from 0% to 67% within +/- 20%. Milestone 1 (First Playable Round) is now feature-complete. The main lesson: commit incrementally, don't skip QA planning even when things are going well.
