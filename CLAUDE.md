# Claude Code Game Studios -- Game Studio Agent Architecture

Indie game development managed through 48 coordinated Claude Code subagents.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Technology Stack

- **Engine**: Godot 4.6.2
- **Language**: GDScript
- **Version Control**: Git with trunk-based development
- **Build System**: SCons (engine), Godot Export Templates
- **Asset Pipeline**: Godot Import System + custom resource pipeline

> **Note**: Engine-specialist agents exist for Godot, Unity, and Unreal with
> dedicated sub-specialists. Use the set matching your engine.

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md

## GDScript / Godot Conventions
- Always call `add_child()` before calling any setup/init methods that reference child nodes. Never assume `_ready()` has run during manual initialization.
- Be careful with lambda closures in signal callbacks — always capture variables explicitly rather than relying on closure over loop variables.
- When moving logic between classes (e.g., from RoundManager to MatchProgression), always search for and update all references including tests.

## Testing
- After any code change that moves logic between classes or changes method signatures, immediately run the related tests before considering the task done.
- When writing smoke tests or integration tests, test one behavior at a time rather than combining assertions.

## Agent Delegation
- When delegating implementation work to Task Agents, always verify the agent produced actual file output. If an agent only returns analysis/design without code, implement directly rather than re-delegating.
- For complex multi-file implementations, prefer doing the work directly rather than delegating to a sub-agent.