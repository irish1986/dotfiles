# CI split into three workflows

Status: accepted, 2026-10-21

One `ci.yml` became three workflows, each named for when it runs, and every job in them is short so a problem fails fast.

- **`pr.yml`, on pull requests into main.** Stage 1 runs in parallel, each job a few minutes at most: one lint job per prek hook family (yaml, markdown, shell, ansible, renovate, hygiene), the PR title through the commitizen `commit-msg` hook (merges are squashed, so the title becomes the commit on main), and a bootstrap smoke test of `scripts/setup`'s first run and its refusals. Stage 2, the converge of each profile from the checkout (0009), starts only once stage 1 is green, and the first failed profile cancels the other. `CI OK` aggregates it all and stays the one required check. A title or body edit re-runs everything: a run with the other jobs skipped would report a green `CI OK` over an earlier failure.
- **`main.yml`, on every push to main.** It runs the same stage 1, then the README's one-liner instead of a checkout. The script comes from the merged commit's raw URL, it clones the repo, the fixture local file goes in, and setup runs twice, with the second run held to `changed=0`. Only after a merge does the public install path exist, so this is the one check a pull request cannot make. Runs are never cancelled, so each merged commit gets its own verdict.
- **`cron.yml`, the admin workflow.** It runs once a day (06:00 UTC), on dispatch with a choice of job, and on the events its jobs need. It covers Renovate (also on push to main and on a human edit of the dashboard; 0005), the label sync from `.github/labels.yml`, the stale sweep, `needs-triage` on issues people open, `area/*` labels on pull requests from `.github/labeler.yml`, and the upstream-rot install. The rot check went from weekly to daily and now runs main's real install rather than a checkout.

The three files are copies rather than one reusable workflow: each stays readable on its own, at the cost of keeping the shared jobs in step by hand. There is no paths filter anywhere, for the reason 0009 gives.

## Consequences

- Actions are still pinned by SHA, but by convention only. The check that enforced it was dropped, so a hand-written `@v4` would merge.
- A broken commit on main is found after it lands, by `main.yml`, not before.
- Renovate's pull requests target main, so they get the full pull-request suite and auto-merge on `CI OK` as before.
