# fastfetch

System information tool, run at shell startup.

Not in the 22.04 or 24.04 archives, so the upstream `.deb` is installed and the installed version is compared first so re-runs do not re-download.

Removes `neofetch`, which upstream archived in 2024.

An earlier version of this role never installed fastfetch at all: it queried the latest release, assigned it to a fact twice -- the second assignment read `.stdout` off a string, yielding `''` -- printed it with `debug`, removed neofetch and stopped.
