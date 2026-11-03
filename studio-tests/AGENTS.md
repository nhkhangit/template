# Studio Tests — Agent Instructions

This folder is the quality assurance layer for the Claude Code Game Studios skill/agent
framework. It is self-contained and separate from any game project.

## Key files

| File | Purpose |
|------|---------|
| `catalog.yaml` | Master registry for all 74 skills and 49 agents. Contains category, spec path, and last-test tracking fields. Always read this first when running any test command. |
| `quality-rubric.md` | Category-specific pass/fail metrics. Read the matching `###` section for the skill's category when running `/skill-test category`. |
| `skills/[category]/[name].md` | Behavioral spec for a skill — 5 or more test cases + protocol compliance assertions. |
| `agents/[tier]/[name].md` | Behavioral spec for an agent — 5 or more test cases + protocol compliance assertions. |
| `templates/skill-test-spec.md` | Template for writing new skill spec files. |
| `templates/agent-test-spec.md` | Template for writing new agent spec files. |
| `results/` | Written by `/skill-test spec` when results are saved. Not gitignored — add it to `.gitignore` to keep results out of commits. |

## Path conventions

- Skill specs: `studio-tests/skills/[category]/[name].md`
- Agent specs: `studio-tests/agents/[tier]/[name].md`
- Catalog: `studio-tests/catalog.yaml`
- Rubric: `studio-tests/quality-rubric.md`

The `spec:` field in `catalog.yaml` is the authoritative path for each skill/agent spec.
Always read it rather than guessing the path.

## Workflow for testing a skill or agent

1. Read `catalog.yaml` to get the `spec:` path and `category:` — from the
   `skills:` entry for a skill, the `agents:` entry for an agent
2. Read the skill at `.claude/skills/[name]/SKILL.md` and every file in its
   `references/` folder, or the agent at `.claude/agents/[name].md` (or `.agents/agents/[name].md`)
3. Read the project `AGENTS.md` / `CLAUDE.md` and the files it imports: every
   subagent receives them, so a rule stated there (for example a redirect in
   `coordination-rules.md`) counts as the skill's or agent's own
4. Read the spec at the `spec:` path
5. Evaluate the spec's Static Assertions, each case's assertions, and its
   Protocol Compliance list
6. Offer to write results to `results/` and update `catalog.yaml`
