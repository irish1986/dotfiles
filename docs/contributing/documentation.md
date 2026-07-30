# Documentation

The site is [MkDocs](https://www.mkdocs.org/) with
[Material](https://squidfunk.github.io/mkdocs-material/). Build it locally:

```bash
uv run mkdocs serve          # http://127.0.0.1:8000
uv run mkdocs build --strict # what CI runs
```

`--strict` turns MkDocs warnings into failures, so a broken internal link or a
nav entry pointing at a missing file fails the build rather than shipping.

## Generated versus written

Two kinds of page, and the split matters:

**Written by hand** — everything under `docs/`. Prose that explains *why*:
architecture, guides, troubleshooting.

**Generated at build time** — every role page, the role matrix, the variables and
collections references, and the mirrored `CHANGELOG`, `CONTRIBUTING`, `SECURITY`
and `LICENSE`. Produced by `scripts/gen_docs.py` through `mkdocs-gen-files`.

Generated pages are **never written into `docs/`**. They go into MkDocs'
in-memory file tree, so they cannot be committed stale, edited by mistake, or
drift from the roles they describe. Mirrored files have no copy under `docs/`
either — the source of truth stays where GitHub expects it.

Adding a role therefore needs no documentation change: the page, the nav entry and
the matrix row all appear on the next build.

## Role READMEs

Each role has a `roles/<role>/README.md` holding the human half — why the role
exists, what is surprising about it, upstream links. The generator reads it,
strips the H1 (the page already has one) and demotes the remaining headings so
they nest correctly.

Everything mechanical is derived from the role's own source and must **not** be
written by hand:

- variables and their defaults, from `defaults/main.yml`
- the comment above each default, used as its description
- packages installed and removed, from the `apt` tasks
- tags, handlers, services, files deployed
- external URLs the role fetches
- whether the role is in the default selection

Keep a README to the parts a reader cannot get from the table: the reason it is
written this way, and anything that will surprise them.

`MKDOCS_STRICT_ROLES=1` fails the build when a role has no README. CI sets it, so
a new role cannot land undocumented.

## Style

- **Headings ≤ 40 characters.** markdownlint MD013 enforces
  `heading_line_length: 40`.
- **Use `!!! note` admonitions**, the Material syntax, not GitHub's `> [!NOTE]`.
- **Say why, not what.** The generated tables already say what.
- **Show real output.** A console block from an actual run is worth more than a
  description of it.

## Deployment

`.github/workflows/docs.yml` builds on every pull request with `--strict`, and
deploys to GitHub Pages on push to `main` using the OIDC
`upload-pages-artifact` / `deploy-pages` flow — no `gh-pages` branch and no
`contents: write`.
