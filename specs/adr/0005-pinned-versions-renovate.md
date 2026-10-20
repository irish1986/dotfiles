# Pinned versions, self-hosted Renovate

Status: accepted, 2026-10-01

Everything installed from a release is pinned, with a `# renovate: datasource=... depName=...` comment on the line above the version, in the profiles and role defaults. Renovate runs from this repo's own workflow rather than the Mend app, so its schedule and version are ours. Minor and patch updates merge themselves once CI passes, after a three-day buffer against yanked releases; majors wait for a human.

Tools that update themselves in place (Claude Code, rustup) are installed once and not pinned. uv, nvm and Copilot CLI are pinned installer-script entries: a run re-installs one when its version differs from the pin, and that also reverts a `uv self update`. oh-my-zsh is pinned to a commit and Copilot CLI to a release, each with its own updater turned off (`COPILOT_AUTO_UPDATE=false` in `.zshrc`). A node major is pinned; nvm takes that major's newest release at install time.

Amended 2026-10-20: Copilot CLI moved from unpinned to pinned.
