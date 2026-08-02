# claude

Claude Code and its global configuration.

## apt, not the install script

Anthropic publishes a signed apt repository alongside the more widely advertised `curl https://claude.ai/install.sh | bash`. The repository is what this role uses.

The install script drops an unmanaged copy under `~/.local/share/claude/versions/` that replaces itself in the background. That is a reasonable default for a laptop nobody provisions, and the wrong one here: the whole point of the repo is that the `update` role decides when packages move. The apt path also gives GPG verification for free, through the same `apt_repo` helper every other third-party repository goes through.

`claude_apt_suite` is `stable`, a release channel rather than a distribution codename, which is why `apt_repo_probe` is `false` -- there is no `dists/<codename>` layout to probe. `stable` trails `latest` by roughly a week and skips releases with known regressions.

`DISABLE_AUTOUPDATER` is set in the seeded settings for the same reason: the binary belongs to dpkg, and letting Claude Code swap it out leaves apt reporting a version that is no longer on disk.

## settings.json is seeded, not managed

`claude_settings` is written to `~/.claude/settings.json` with `force: false`, so it lands once on a fresh machine and is never touched again.

This is deliberate. Claude Code rewrites that file itself every time `/config` changes a setting, so a managed template would silently revert those edits on the next converge -- the user would change the theme, and the next `ansible-playbook` run would change it back with no indication why. Seeding gives a sane starting point and then gets out of the way.

`verify.yml` parses the file rather than merely checking it exists. A malformed `settings.json` is ignored by Claude Code with no error anywhere except `claude doctor`, so parsing it here is what turns a bad edit into a converge failure.

## CLAUDE.md

`~/.claude/CLAUDE.md` is written with `blockinfile` rather than a template, so the managed block carries the house rules and anything written outside the markers survives. Set `claude_manage_instructions: false` to leave the file alone entirely.
