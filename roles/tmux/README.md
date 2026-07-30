# tmux

tmux, TPM and the tmux configuration.

## Clipboard

Copy works through OSC 52, which Windows Terminal supports natively -- no helper
binary, no X server, and it works over SSH and through nested tmux. That is
`set-clipboard on` plus the `terminal-features` lines in `tmux.conf`.

This role used to ship five further config files that nothing loaded: `tmux.conf`
is standalone, and `load.conf` referenced `*.tmux` filenames that do not exist in
the repository. They are gone; `set-clipboard on`, the one genuinely useful
setting among them, was folded into `tmux.conf`.

## TPM

Pinned to a specific ref and cloned with `force: true`, because it is a vendored
dependency rather than something to edit in place.

That `force` is load-bearing. An earlier version set `recurse: true` with
`mode: "0755"` on the plugin directory, which chmod'd every git-tracked file
inside TPM from 644 to 755. git then reported the whole tree as modified and
refused to update, so TPM was wedged at whatever commit it was first cloned at.

After a first install, press `prefix` + <kbd>I</kbd> in tmux to fetch the plugins
themselves.
