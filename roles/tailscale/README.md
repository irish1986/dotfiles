# tailscale

Tailscale mesh VPN client.

The previous version of this role only ran `stat /usr/local/bin/tailscale` and
registered the result into a fact nothing consumed -- it never installed anything.

Tailscale publishes a per-codename suite and a matching per-codename key, and lags
new Ubuntu releases, so the [apt_repo](apt_repo.md) suite probe earns its keep
here.

Bringing the node up is left to you: `tailscale up` needs an auth key and is an
interactive, stateful decision. The role installs the client and starts the
daemon.

If Tailscale was previously installed by hand, its documented steps write a
`.list` file whose `Signed-By` points at `/usr/share/keyrings`. apt refuses to
load two sources for one URI with different `Signed-By` values, so this role
removes the legacy pair *before* its first apt call -- otherwise apt is already
broken by the time the cleanup would run.
