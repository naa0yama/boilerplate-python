---
name: project-conventions
description: >-
  Project-specific conventions for boilerplate-python. Covers mise commands,
  Python coding rules (ruff, mypy, pytest), test structure, and commit workflow.
  Use when writing, reviewing, or modifying .py files, running builds/tests,
  or creating commits.
license: AGPL-3.0
---

# Project Conventions — boilerplate-python

## Commands: mise Only

All tasks go through `mise run`:

| Task                  | Command               |
| --------------------- | --------------------- |
| Setup                 | `mise run setup`      |
| Install               | `mise run install`    |
| Build                 | `mise run build`      |
| Test                  | `mise run test`       |
| Coverage view (HTML)  | `mise run test:view`  |
| Format                | `mise run fmt`        |
| Format check          | `mise run fmt:check`  |
| Ruff lint             | `mise run ruff:check` |
| Type check (mypy)     | `mise run mypy`       |
| Lint                  | `mise run lint`       |
| Lint (GitHub Actions) | `mise run lint:gh`    |
| Pre-commit (required) | `mise run pre-commit` |
| Pre-push              | `mise run pre-push`   |
| Docs                  | `mise run docs`       |
| Docs (live)           | `mise run docs:live`  |
| Clean                 | `mise run clean`      |

## Python Coding Rules

- **Type annotations**: mandatory everywhere (mypy enforced via `pyproject.toml`)
- **Docstrings**: Google-style
- **Comments**: concise English only
- **Line length / quotes / lint ignores**: defined in `[tool.ruff]` in `pyproject.toml`
- **Formatter**: `ruff format` + `dprint` (TOML/YAML/JSON/Markdown)
- **Linter**: `ruff check` + `mypy`

## Test Structure

- Tests in `tests/` mirroring `src/` directory structure
- Framework: pytest
- Coverage outputs go to `target/` (configured in `[tool.coverage]` in `pyproject.toml`)

## Commit Convention

Conventional Commits: `<type>: <description>` or `<type>(<scope>): <description>`

Allowed types: `feat`, `update`, `fix`, `style`, `refactor`, `docs`, `perf`, `test`, `build`, `ci`, `chore`, `remove`, `revert`

## Workflow

1. Write tests (for new features / bug fixes)
2. Implement
3. Run `mise run test` — all tests must pass
4. Stage only the relevant files
5. Run `mise run pre-commit` (runs `fmt:check`, `ruff:check`, `mypy`, `lint:gh`)
6. If errors, fix → re-stage → re-run `mise run pre-commit`

## Reference Files

| Topic             | File                                         |
| ----------------- | -------------------------------------------- |
| Testing patterns  | `references/testing-patterns.md`             |
| Project structure | `references/module-and-project-structure.md` |
