# Project Summary

- Think in English, explain, and respond to chat in Japanese.
- Use half-width brackets instead of full-width brackets in the Japanese explanations output.
- When writing Japanese and half-width alphanumeric characters or codes in one sentence, please enclose the half-width alphanumeric characters in backquotes and leave half-width spaces before and after them.

## Commands

All tasks use `mise run <task>`:

| Task                  | Command                       |
| --------------------- | ----------------------------- |
| Setup                 | `mise run setup`              |
| Install               | `mise run install`            |
| Build                 | `mise run build`              |
| Test                  | `mise run test`               |
| Coverage view (HTML)  | `mise run test:view`          |
| Format                | `mise run fmt`                |
| Format check          | `mise run fmt:check`          |
| Ruff lint             | `mise run ruff:check`         |
| Type check (mypy)     | `mise run mypy`               |
| Lint                  | `mise run lint`               |
| Lint (GitHub Actions) | `mise run lint:gh`            |
| Pre-commit (required) | `mise run pre-commit`         |
| Pre-push              | `mise run pre-push`           |
| Docs                  | `mise run docs`               |
| Docs (live)           | `mise run docs:live`          |
| Clean                 | `mise run clean`              |
| Audit (deps)          | `mise run audit`              |
| Badges (init)         | `mise run badges:init`        |
| Claude Code (install) | `mise run claudecode:install` |
| Dev (start)           | `mise run dev:up`             |
| Dev (stop)            | `mise run dev:down`           |
| Dev (exec)            | `mise run dev:exec`           |
| Dev (status)          | `mise run dev:status`         |
| Traefik setup         | `mise run traefik:setup`      |

## Commit Convention

Conventional Commits: `<type>: <description>` or `<type>(<scope>): <description>`

Allowed types: feat, update, fix, style, refactor, docs, perf, test, build, ci, chore, remove, revert

## Workflow

1. Write tests (for new features / bug fixes)
2. Implement
3. Run `mise run test` — all tests must pass
4. Stage only the relevant files
5. Run `mise run pre-commit` (runs fmt:check, ruff:check, mypy, lint:gh)
6. If errors, fix → re-stage → re-run `mise run pre-commit`

## Code Comments

- Write all code comments (doc comments, inline comments) in concise English.
- Type annotations are mandatory (mypy enforced via `pyproject.toml`).
- Google-style docstrings.
- Coding rules (line length, quotes, lint ignores) are defined in `pyproject.toml` — see `[tool.ruff]` and `[tool.mypy]`.

## Test Structure

- Place tests in `tests/` mirroring the `src/` directory structure.
- Use pytest. Coverage outputs go to `target/`.

## Skill Maintenance

- **Global skills** (`~/.claude/skills/`): Language-agnostic skills shared across all projects.
  - `mem/`, `commit/`, `brainstorming/`, `workflow-entry/` — session workflow
  - `deps-sync/`, `deps-sync-mise/` — dependency sync
  - `simplify/`, `verification-before-completion/` — quality gates
- **Project skills** (`.claude/skills/`): Project-specific overrides only.
  - `project-conventions/` — Python-specific rules for this project
- When modifying coding rules in `CLAUDE.md`, update the corresponding skill files:
  - Universal rules → the corresponding skill under `~/.claude/skills/`
  - Project-specific rules → `.claude/skills/project-conventions/`
