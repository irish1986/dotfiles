# timezone

System timezone, and time synchronisation where it applies.

The previous version removed `systemd-timesyncd` and installed `ntp` in its place.
Two problems: on noble `ntp` is only a transitional package pulling in `ntpsec`,
so this traded a working default for a shim; and it removed the existing service
**before** installing the replacement, leaving no time synchronisation at all if
the install failed.

Now uses `systemd-timesyncd`, Ubuntu's default.

Time sync is skipped entirely on WSL, where the Windows host owns the clock and
there is no daemon to manage. Only the timezone is set inside the distro.
