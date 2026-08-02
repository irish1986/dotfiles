# ssh

SSH client, hardened client configuration, key permissions and `authorized_keys`.

Key **material** is this role's job; the directory and mode enforcement is `scripts/setup`'s. That split matters: the previous arrangement had both creating `~/.ssh/id_ed25519` and fighting over it.

## The managed block goes last

`ssh_config_options` is rendered into a `Host *` block appended to `~/.ssh/config`, inside an `ANSIBLE MANAGED BLOCK defaults` marker. The rest of the file is yours.

Being last is not cosmetic. `ssh_config` takes the **first** value it obtains for each keyword, not the most specific one -- the opposite of how nearly every other config format behaves. A `Host *` block at the top of the file would silently win over every host-specific block below it, and the symptom is an option that appears in the file and has no effect. Put your own `Host` entries above the marker and they take precedence; that is also the escape hatch for a server the hardened defaults cannot reach:

```text
Host legacy.example.com
  HostKeyAlgorithms +ssh-rsa
  PubkeyAcceptedAlgorithms +ssh-rsa

# BEGIN ANSIBLE MANAGED BLOCK defaults
Host *
  ...
```

## What is hardened, and what it costs

The algorithm lists are allowlists rather than the `-weak-thing` removal form. Naming what is acceptable fails closed: a future OpenSSH that adds something questionable does not quietly inherit it. The price is that a server offering nothing on the list becomes unreachable until you add a `Host` block for it, as above.

Everything in the list exists in OpenSSH 8.9, which is what jammy ships -- the oldest release this repo targets.

Three choices worth calling out:

- `IdentitiesOnly yes` stops ssh from walking every key in the agent and offering each one to the server. Without it, a machine with several keys leaks which keys exist and often exhausts the server's `MaxAuthTries` before reaching the right one.
- `UpdateHostKeys yes` learns a server's new host keys once it has authenticated with an already-known one, so key rotation does not train you to accept a changed-key warning.
- `ForwardAgent no` is the default and is set anyway, because the failure mode -- a compromised remote host using your forwarded agent to authenticate elsewhere as you -- is worth being explicit about.

`ControlPath` uses `%C`, the hash of the connection tuple, rather than a readable `%r@%h:%p`. A literal path blows past the ~104-byte `sun_path` limit on long hostnames, and the resulting failure reads like an unrelated connection error.

## Validation

`blockinfile` runs `ssh -G` against the candidate file before installing it. A typo'd keyword is a parse error that would otherwise break every `ssh` invocation on the machine -- including the ones later in the same play.

`verify.yml` then resolves the installed file with `ssh -G` again, because validate only ever saw this role's own block and not the merge with whatever else is in the file. It also asserts no CBC or arcfour cipher survives into the negotiated set, which is a property of the result rather than an echo of the input.

## Importing the Windows key

Off by default. A WSL-native key is independently revocable and needs no Windows-side change.

Enable with `ssh_import_from_windows: true`. The copy is `force: false`, so it seeds an empty `~/.ssh` but can **never** overwrite a locally generated key -- the previous version overwrote on every run, silently replacing whatever `scripts/setup` had generated.

The `/mnt/c` probes are gated on WSL, where they previously ran on every host and produced two pointless `stat` results off WSL.

`verify.yml` asserts `~/.ssh` is `0700`, because ssh refuses to use a keypair in a group- or world-readable directory and the failure message is not obvious.
