# ssh

SSH client, key permissions and `authorized_keys`.

Key **material** is this role's job; the directory and mode enforcement is
`scripts/setup`'s. That split matters: the previous arrangement had both creating
`~/.ssh/id_ed25519` and fighting over it.

## Importing the Windows key

Off by default. A WSL-native key is independently revocable and needs no
Windows-side change.

Enable with `ssh_import_from_windows: true`. The copy is `force: false`, so it
seeds an empty `~/.ssh` but can **never** overwrite a locally generated key -- the
previous version overwrote on every run, silently replacing whatever
`scripts/setup` had generated.

The `/mnt/c` probes are gated on WSL, where they previously ran on every host and
produced two pointless `stat` results off WSL.

`verify.yml` asserts `~/.ssh` is `0700`, because ssh refuses to use a keypair in a
group- or world-readable directory and the failure message is not obvious.
