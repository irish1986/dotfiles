# Repos cloned from the profiles

Status: accepted, 2026-10-23

A new machine needs the same repositories cloned every time. The git role clones them from one list, `git_repos`, set in the profiles like any tool entry (0004): `base.yml` for every machine, `personal.yml` or `work.yml` for one kind. The list is not read from the local file. This repo is public, so `work.yml` names only repositories whose names may be published; a private work repository is still cloned by hand.

An entry is any git URL with an optional `dest`. Without one, the checkout lands in `~/git/<owner>/<repo>`, the layout `git_project_dir` already uses. A URL whose path is not exactly `owner/repo` (an Azure DevOps `org/proj/_git/x`, a GitLab subgroup) must set `dest`, and the run fails before cloning anything when it does not. That typo is the one failure: everything else warns.

- **A missing checkout is cloned and an existing one is never touched.** Nothing fetches or pulls, so the playbook never moves a branch you are working on, and a second run reports `changed=0` (0009). A directory that is not a git checkout, or whose `origin` differs from the entry, is reported and left alone.
- **Problems warn; the run goes on.** A repository that cannot be cloned (no access, renamed, no network, no key) is named in one warning at the end of the role, as the tool logins are (0010), and the roles after git still run. CI has no machine key, so its SSH entries warn on every run. That is accepted rather than special-cased, and the public HTTPS entries really clone.
- **Private repositories use SSH URLs**, authenticated by the machine key (0006), which the ssh role registers on GitHub. No HTTPS credential helper is configured. Your own repositories use SSH even when public, so you can push to them. Third-party repositories kept for reference use HTTPS, since they are only read, and sit side by side under `~/git/reference/<repo>` through a `dest` each rather than under their owners.
- **Only public repositories are listed**, even for your own private ones: this repo is public, so their names would be too. Private repositories are cloned by hand.
- **Clones run in parallel**, `git_repos_parallel` (8) at a time, in one task: a fresh machine clones dozens, and one after another they would dominate its run. The run shows one task rather than a line per repository; what was cloned and what went wrong are still named, each on a line of its own.
- **Host keys are fetched over TLS, not scanned or committed.** `StrictHostKeyChecking ask` cannot be answered during a run, and accepting a new key on first use would undo the hardened ssh configuration. No SSH material is kept in this repo, not even public host keys. Instead, each run the ssh role reads `ssh_keys` from `https://api.github.com/meta`, which TLS authenticates, and writes them hashed to `~/.ssh/known_hosts` before the git role clones. A failed fetch is a warning. An SSH entry whose host has no key in `known_hosts` is reported and skipped, so another host works once its key is added there by hand. Clones run with `BatchMode=yes` and no terminal prompt, so anything that needs a person fails at once instead of hanging.
- **A fresh clone gets `prek install`** when it has a `.pre-commit-config.yaml`, `.pre-commit-config.yml` or `prek.toml`, so its hooks are active from the first commit. Existing checkouts are not touched, by the rule above.
- `--tags repos` runs only the clones and the host-key fetch they depend on.

## Consequences

- A removed entry stops being cloned; the checkout stays.
- CI clones the reference repositories in `base.yml` for real on every profile, which costs it some time but exercises the clone path.
- GitHub's host keys follow a rotation on the next run, but a run only adds keys: a retired key stays in `known_hosts` until ssh's `UpdateHostKeys` or you remove it.
- Only github.com is covered. Any other SSH host (Azure DevOps, GitLab) needs its key added to `known_hosts` by hand, or its entries are skipped.
- A repository that is never wanted again on new machines must be removed from the profile, not just deleted locally, or the next run clones it back.
