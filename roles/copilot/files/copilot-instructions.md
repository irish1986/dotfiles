# Copilot instructions

This repo is a **`uv` workspace monorepo template** for the org: independent
Python apps and shared libraries in one workspace, one lockfile, one toolchain,
one release train. Its purpose is to be easy to deploy and to absorb the org's
legacy projects.

## Layout

- `packages/*` — apps (have a `[project.scripts]` entry point). `packages/legacy-*`
  get scoped lint/type relief.
- `shared/*` — reusable libraries other members import via
  `[tool.uv.sources] <lib> = { workspace = true }`.
- `scripts/*` — internal, stdlib-only dev/CI tooling (not workspace members).
- `template/` — the copier generator for new/migrated members.
- `docs/` — topic guides (workspace, testing, linting, CI, releases, migration,
  deployment) and the `docs/projects.md` per-member index.

## Toolchain

- **`uv`** for everything: `uv sync --all-packages`, `uv add <dep> --package <m>`,
  `uv run …`, `uv lock`. No `requirements.txt`, no Django.
- **`ruff`** (line-length 100, double quotes, target py312) and **`ty`** (Astral
  type checker). Python floor `>=3.12`.
- **`pytest`** with an 80% per-package coverage gate.
- **commitizen** owns versioning (conventional commits → one workspace SemVer).

## Working here

- Add a member with `uvx copier copy --trust template/ .` — it wires the member
  into `[tool.commitizen].version_files`; the `check-version-files` hook enforces it.
- Migrate a legacy project by following `docs/migration.md` (detailed playbook in
  the `repo-migration` skill under `.github/skills/`).
- Conventional-commit messages and branch prefixes (`feat/`, `fix/`, …) — see
  `.github/instructions/git.instructions.md`.
- Before pushing: `uv run ruff check .`, `uv run ty check`, `uv run pytest`.

`docs/` is the source of truth; keep these notes consistent with it.
