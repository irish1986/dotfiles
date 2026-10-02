# Tokens and corporate URLs in an env file

Status: accepted, 2026-10-01

The repo still has no secrets solution (0001), but some tools are useless without one: ggshield and snyk need API tokens, and on the work network uv and npm need package mirrors (0007). These live in one plain file, `.env` at the checkout root, which `.gitignore` excludes and the playbook keeps at mode 0600. `.env.sample` is committed as the reference, every line commented out, and `scripts/setup` copies it on the first run.

The file uses each tool's own variable names (`UV_DEFAULT_INDEX`, `NPM_CONFIG_REGISTRY`, `GH_TOKEN`, `GITGUARDIAN_API_KEY`, `SNYK_TOKEN`, ...), and is exported as it is: by every zsh, from a block in `~/.zshenv`, and by `scripts/setup` before it installs anything, so the playbook run inherits it. Nothing in the repo holds a value, so there is no translation into tool config and nothing to hide from the run's output.

The tools that need a login, gh, Copilot CLI, ggshield and snyk, all get it the same way: each reads its own variable (Copilot shares `GH_TOKEN` with gh), and the playbook never runs a login or writes a credential store, so changing a token in `.env` takes effect in the next shell. The tools role checks them from one list, `tools_auth_checks`: a bash command tests that the variable is set and not a `<placeholder>`, then runs the tool's status command with its output discarded, and the run prints one warning naming each tool that failed. It warns and never fails, skips the checks in a container (CI has no tokens), and `--tags auth` runs only them. A failed check cannot tell a rejected token from an unreachable service, and Copilot, with no status command, is checked only for a fine-grained token.

This replaced, before it shipped, a map of variables in the local file that the playbook wrote into `~/.zshenv`: the values then existed in two places, and the run had to be kept from logging them.

## Consequences

- The values sit in plain text, and every process started from a shell, agent CLIs included, can read them.
- The file is inside the checkout: a forced `git add` could commit it (the ggshield pre-commit hook is the second guard), and deleting the checkout deletes it.
- An uncommented but empty line exports an empty value, which is not the same as unset; leave unused lines commented.
