# herdr role

Installs herdr at a pinned version, owns its `config.toml`, manages its plugins and agent integrations, and makes a login shell exec into it. The variables are documented in [`defaults/main.yml`](defaults/main.yml); the plugins it gets are listed in [`profiles/base.yml`](../../profiles/base.yml).

## One-time manual step: Claude's statusLine

The tab-bar usage segment and usagebar's sidebar `$limit` read Claude Code's 5-hour and weekly windows. Claude reports them fresh only to its `statusLine` command; without it they come from a cache in `~/.claude.json` that can be hours old. The statusLine is yours to set, not the playbook's ([ADR 0009](../../docs/adr/0009-herdr-agent-integrations.md)), so this is done once by hand.

Point it at usagebar's bridge. The plugin root is stable across reinstalls:

```bash
root="$(herdr plugin list --json | jq -r '.result.plugins[] | select(.plugin_id == "usagebar") | .plugin_root')"
echo "$root/bin/run-statusline.sh"
```

Then in `~/.claude/settings.json`, with that path:

```json
{
  "statusLine": {
    "type": "command",
    "command": "bash /home/<you>/.config/herdr/plugins/github/usagebar-<hash>/bin/run-statusline.sh"
  }
}
```

If you already have a statusLine, `herdr plugin action invoke usagebar.setup` shows how to chain it instead of replacing it.

## After a herdr bump

The playbook reinstalls the Claude and Copilot integrations when `herdr integration status` reports them outdated, and Renovate's pull request gets its checksums from `.github/workflows/herdr-checksums.yml`. A running server keeps the old binary until it restarts; `herdr status` says so (`server_binary_stale`).
