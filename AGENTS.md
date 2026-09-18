# Claude Code Game Studios — Workspace Instructions (ZCode)

Indie game development managed through 49 coordinated studio subagents and 73
workflow skills. Every agent owns a specific domain, enforcing separation of
concerns and quality.

This repository supports two agent clients side by side:

- **Claude Code** — `CLAUDE.md` + `.claude/` (agents, skills, hooks, rules,
  settings). This is the **source of truth**.
- **ZCode** — this file + `.zcode/` (generated agents and skills, hook wiring).

`.zcode/agents/` and `.zcode/skills/` are **generated** by `tools/zcode/sync.sh`
— never hand-edit them. After merging upstream changes, re-run the script and
commit the regenerated tree. See `docs/ZCODE-SUPPORT.md` for the full
client-capability mapping.

## Technology Stack

- **Engine**: [CHOOSE: Godot 4 / Unity / Unreal Engine 5]
- **Language**: [CHOOSE: GDScript / C# / C++ / Blueprint]
- **Version Control**: Git with trunk-based development

Before engine-specific work, read `.claude/docs/technical-preferences.md` and,
when a Godot project exists, `docs/engine-reference/godot/VERSION.md`.

## Project Structure

Read `.claude/docs/directory-structure.md` before creating new files or
directories so everything lands in the right place (`src/`, `assets/`,
`design/`, `docs/`, `production/`, `prototypes/`, `tests/`, `tools/`).

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Ask "May I write this to [filepath]?" before using Write/Edit tools
- Show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

Full protocol and examples: `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md`.

## Coordination Rules

Read `.claude/docs/coordination-rules.md` before dispatching work among agents
(vertical delegation, horizontal consultation, conflict escalation paths).

## Coding Standards

Read `.claude/docs/coding-standards.md` before writing code.

## Context Management

Follow `.claude/docs/context-management.md`: session state lives in
`production/session-state/active.md`; update it as work progresses.

## ZCode Adapter Conventions

### Slash skills

All 73 CCGS workflows are installed as skills — type `/` and pick from the
menu. One rename: CCGS `/code-review` is installed as **`ccgs-code-review`**
(avoids shadowing by a same-named personal user-scope skill).

### Subagents

The 49 studio agents are registered natively from `.zcode/agents/` (generated
from `.claude/agents/`). When a skill says "spawn X via Task" or
`subagent_type: X`, use the Agent tool with that type directly — tool
restrictions, `disallowedTools`, and `maxTurns` are enforced at runtime.

Fallback if a type is ever unavailable: spawn `general-purpose` and prepend the
full content of `.claude/agents/X.md` as the role prompt, followed by the task
brief. Per-agent `model:` tier hints (opus/sonnet/haiku) are Claude-specific
and stripped in the generated copies — all agents run on the session model.

### Path-scoped rules — read before editing

Claude Code auto-injects these by path; on ZCode, read the matching file first:

| Editing under | Read first |
|---|---|
| `src/gameplay/**` | `.claude/rules/gameplay-code.md` |
| `src/core/**` | `.claude/rules/engine-code.md` |
| `src/ai/**` | `.claude/rules/ai-code.md` |
| `src/networking/**` | `.claude/rules/network-code.md` |
| `src/ui/**` | `.claude/rules/ui-code.md` |
| `design/gdd/**` | `.claude/rules/design-docs.md` |
| `design/narrative/**` | `.claude/rules/narrative.md` |
| `tests/**` | `.claude/rules/test-standards.md` |
| `prototypes/**` | `.claude/rules/prototype-code.md` |
| `assets/data/**` | `.claude/rules/data-files.md` |
| `assets/shaders/**` | `.claude/rules/shader-code.md` |

### Directory-level context — read before working there

Claude Code auto-loads these folder memory files; on ZCode, read them first:

- `design/` → `design/CLAUDE.md`
- `docs/` → `docs/CLAUDE.md`
- `src/` → `src/CLAUDE.md`
- `CCGS Skill Testing Framework/` → `CCGS Skill Testing Framework/CLAUDE.md`

### Hooks and safety

Validation hooks run via `.zcode/config.json`: session context and gap
detection on SessionStart, commit/push validation plus a deny guard
(`rm -rf`, force push, `sudo`, `.env` access, …) on PreToolUse, asset and
skill-change validation on PostToolUse, session archival on Stop. Not
available on ZCode: statusline, desktop notifications, pre-compaction dump,
subagent lifecycle audit — see `docs/ZCODE-SUPPORT.md`.

## First Session?

If the project has no engine configured and no game concept, run `/start` to
begin the guided onboarding flow.
