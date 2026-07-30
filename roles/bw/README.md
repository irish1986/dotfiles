# bw

Bitwarden CLI (`bw`).

This is the password-manager CLI, which is a *different product* from Bitwarden
Secrets Manager -- the `bws`/`bitwarden-sdk` path used for
[secrets](../../docs/getting-started/secrets.md). Kept because it is useful
interactively; it is not what the playbook uses to read secrets.

The releases feed is filtered for the `cli-v` prefix rather than taking
`releases/latest`. The `bitwarden/clients` repository publishes desktop, browser
and CLI releases together, so `latest` is not reliably the CLI. An earlier version
computed the latest tag and then ignored it, downloading a hardcoded
`cli-v2025.1.3` -- eighteen months stale by the time it was noticed.
