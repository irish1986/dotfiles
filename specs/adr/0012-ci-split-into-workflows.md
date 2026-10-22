# CI split into small workflows

Status: accepted, 2026-10-21

`ci.yml`, `renovate.yml` and `labels.yml` became two CI workflows, each named for when it runs, and one small workflow per admin task. Every job is short, so a problem fails fast.

- **`pr.yml`, on pull requests into main.** Stage 1 runs in parallel, each job a few minutes at most: one lint job per prek hook family (yaml, markdown, shell, ansible, renovate, hygiene), the PR title through the commitizen `commit-msg` hook (merges are squashed, so the title becomes the commit on main), and a bootstrap smoke test of `scripts/setup`'s first run and its refusals. Stage 2, the converge of each profile from the checkout (0009), starts only once stage 1 is green, and the first failed profile cancels the other. `CI OK` aggregates it all and stays the one required check. A title or body edit re-runs everything: a run with the other jobs skipped would report a green `CI OK` over an earlier failure.
- **`main.yml`, on every push to main.** It runs the same stage 1, then the README's one-liner instead of a checkout. The script comes from the merged commit's raw URL, it clones the repo, the fixture local file goes in, and setup runs twice, with the second run held to `changed=0`. Only after a merge does the public install path exist, so this is the one check a pull request cannot make. Runs are never cancelled, so each merged commit gets its own verdict.
- **One workflow per admin task**, each with only its own triggers, permissions and concurrency, so none needs an `if:` gate and any one can be disabled alone:
  - `renovate.yml`: daily at 06:00 UTC, on push to main and on a human edit of the dashboard (0005). Runs queue and are never cancelled.
  - `labels.yml`: syncs `.github/labels.yml` when it changes on main, and weekly to undo edits made by hand.
  - `stale.yml`: daily sweep of inactive issues and pull requests.
  - `triage.yml`: `needs-triage` on every issue a person opens.
  - `pr-labels.yml`: `area/*` labels from `.github/labeler.yml`.
  - `rot.yml`: main's install, daily at 06:30 after Renovate. This is the upstream-rot check, which went from weekly to daily and now runs the real install rather than a checkout. A scheduled failure opens or updates one `Upstream rot` issue, and the next green scheduled run closes it.

`pr.yml`, `main.yml` and `rot.yml` repeat their shared jobs rather than calling one reusable workflow: each stays readable on its own, at the cost of keeping the copies in step by hand. The CI workflows have no paths filter, for the reason 0009 gives. `labels.yml` has one, because it is not a required check.

## Consequences

- Actions are still pinned by SHA, but by convention only. The check that enforced it was dropped, so a hand-written `@v4` would merge.
- A broken commit on main is found after it lands, by `main.yml`, not before.
- Renovate's pull requests target main, so they get the full pull-request suite and auto-merge on `CI OK` as before.
