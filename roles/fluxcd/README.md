# fluxcd

Flux CD command line tool, installed with the upstream installer.

The installer is fetched to a private temporary file rather than a fixed `/tmp`
path: a predictable name in a world-writable directory is a symlink attack
waiting to happen. It is also skipped entirely when the binary already exists,
where the previous version re-downloaded on every run.
