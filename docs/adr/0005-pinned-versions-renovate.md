# Pinned versions, self-hosted Renovate

Status: accepted, 2026-10-01

Everything installed from a release is pinned, with a `# renovate: datasource=... depName=...` comment on the line above the version, in the profiles and role defaults. Renovate runs from this repo's own workflow rather than the Mend app, so its schedule and version are ours. Minor and patch updates merge themselves once CI passes, after a three-day buffer against yanked releases; majors wait for a human.

Tools that update themselves in place (Claude Code, Copilot CLI, rustup, uv) are installed once and not pinned. A node major is pinned; nvm takes its newest release at install time.
