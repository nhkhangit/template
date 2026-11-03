# Claude Code Game Studios -- Game Studio Agent Architecture (Antigravity Edition)

Indie game development managed through 49 coordinated subagents and 74 skills.
Each agent owns a specific domain, enforcing separation of concerns and quality.

## Antigravity Runtime & Tool Mapping

This repository supports both **Google Antigravity (AGY)** (via `.agents/` and `AGENTS.md`) and **Claude Code** (via `.claude/` and `CLAUDE.md`). When running in Antigravity, apply these mappings whenever a skill (`.claude/skills/*/SKILL.md`) or subagent (`.agents/agents/*.md`) references Claude Code conventions:

- **Skill Preprocessor Lines (`` !`bash "${CLAUDE_SKILL_DIR}/..."` ``)**: Antigravity does not auto-expand `` !`...` `` blocks when reading `SKILL.md`. Whenever a skill starts with `` !`bash "${CLAUDE_SKILL_DIR}/../../hooks/yaml-helper.sh" resolve_config ...` `` (or another script under `${CLAUDE_SKILL_DIR}/../..`), run it via `run_command` by replacing `${CLAUDE_SKILL_DIR}/../..` with `.claude` (e.g., `bash .claude/hooks/yaml-helper.sh resolve_config ...`).
- **Tool Name Mapping**:
  - `Read` -> `read_file` (use `StartLine` and `EndLine` for ranged/section reads)
  - `Write` -> `write_file`
  - `Edit` -> `edit_file`
  - `Bash` / `PowerShell` -> `run_command`
  - `Glob` / `Grep` -> `run_command` (e.g. `rg` / `find`) or file search tools
  - `AskUserQuestion` -> `ask_question`
  - `Agent` (spawning subagents) -> `invoke_subagent` (pass `TypeName` matching the agent name in `.agents/agents/<name>.md`, `Role`, and `Prompt`)
  - `WebSearch` -> `search_web`
- **Model Tiers**: `opus` maps to `pro`, `sonnet` maps to `inherit` (or `pro`/`flash`), and `haiku` maps to `flash` / `flash_lite`.

## Technology Stack

- **Engine**: [CHOOSE: Godot 4 / Unity / Unreal Engine 5]
- **Language**: [CHOOSE: GDScript / C# / C++ / Blueprint]
- **Version Control**: Git with trunk-based development
- **Build System**: [SPECIFY after choosing engine]
- **Asset Pipeline**: [SPECIFY after choosing engine]

> **Note**: Engine-specialist agents exist for Godot, Unity, and Unreal with
> dedicated sub-specialists. Use the set matching your engine.

## Project Structure

@[directory-structure](.claude/docs/directory-structure.md)

## Engine Version Reference

<!-- ENGINE-REFERENCE-IMPORT: the line below is engine-specific. /setup-engine
     rewrites it to @[engine-version](docs/engine-reference/<engine>/VERSION.md) for the chosen
     engine, so a Unity or Unreal project stops loading the Godot reference every
     session. It defaults to Godot (the template's example engine); skills that
     need the pinned version read docs/engine-reference/<engine>/VERSION.md on
     demand regardless of this import. -->
@[engine-version](docs/engine-reference/godot/VERSION.md)

## Technical Preferences

`project.yaml` at the repo root is the primary config store — engine, specialists,
naming, platform, performance, modes. Skills resolve it via `resolve_config`
(see `.claude/docs/config-resolution.md`).

`.claude/docs/technical-preferences.md` is the **legacy fallback**, read on demand
when a key is absent from `project.yaml`. It is not imported here: before
`/setup-engine` runs it is almost entirely `[TO BE CONFIGURED]` placeholders, and
after it runs `project.yaml` holds the real values.

## Coordination Rules

@[coordination-rules](.claude/docs/coordination-rules.md)

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using `write_file` / `edit_file` tools
  (exempt: `active.md` appends, agent memory, a subagent's new file at the path
  its orchestrating skill named; see `.agents/rules/agent-memory.md`)
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction
- A skipped or dismissed question is not an answer: act on nothing, re-ask in
  plain text and wait
- Started outside this file's folder? Warn first: hooks, deny rules and the
  ask-first mode load only when the agent starts here

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

@[coding-standards](.claude/docs/coding-standards.md)

## Context Management

Read `.claude/docs/context-management.md` on demand — it is a reference, not
session context. Two of its conventions are load-bearing and cited by name
elsewhere in the repo, so they are restated here rather than lost:

- **`production/session-state/active.md` is the session checkpoint.** The file is
  the memory, not the conversation. Read it first after any compaction, crash, or
  `/clear`.
- **Helpers in `.claude/scripts/` emit observations, never verdicts.** A script
  that scores or judges will eventually contradict a mode or override it cannot
  see. (Cited by `artifact-check.sh` and `adr-dep-graph.sh`.)
