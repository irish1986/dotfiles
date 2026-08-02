# copilot

GitHub Copilot CLI and its global configuration.

## The install script, not npm

The npm package (`@github/copilot`) needs Node 22 or later, and nothing in this repo provides it -- the `nvm` role installs nvm and deliberately stops there, without installing a Node version. The upstream install script ships a self-contained binary instead, so there is no runtime to bootstrap first.

It is run without `become`, with `PREFIX` set to `~/.local`, so the binary is user-owned at `~/.local/bin/copilot`. `.zshrc` already puts that directory on `PATH`.

`PATH` is also set for the install command itself, with the install directory in front. The script probes `command -v copilot` at the end and, when it comes up empty, branches into offering to append an `export PATH=...` line to a shell profile. Putting the directory on `PATH` makes that probe succeed, so the branch never runs -- a write this role does not want, and could not make idempotent if it happened.

## Why the version comparison

The script has no notion of "already installed": it downloads and extracts unconditionally. A `creates:` guard would therefore pin the machine to whatever version it first installed, and no guard at all would report `changed` on every run, which the twice-over converge in CI treats as a failure.

So the role resolves the latest tag from the releases API, compares it against `copilot --version`, and runs the installer only on a mismatch. When the API call fails -- an unauthenticated runner that has burned its 60 requests an hour -- and something is already installed, the role does nothing rather than reinstall blindly. A fresh machine with no binary still installs, because the script treats an empty `VERSION` as latest.

`copilot_version` pins a release; the script accepts an explicit version and prefixes it with `v` itself.

## config.json is off limits

`~/.copilot` holds two files that belong to the user and one that does not.

`settings.json` and `copilot-instructions.md` are the user's, and this role seeds both. `config.json` is application state the CLI manages itself -- `loggedInUsers`, `installedPlugins`, `firstLaunchAt` -- and it is where authentication lands. Nothing here writes to it.

`copilot_settings` defaults to empty, and the seeding task is skipped when it is. GitHub publishes no settings reference for this file; `model` and `hooks` are the only keys the documentation confirms. Guessing at the rest would produce keys the CLI ignores, which is worse than an empty file because it looks like configuration that works.
