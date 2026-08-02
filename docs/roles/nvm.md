# nvm

Node Version Manager.

Installed with the upstream `install.sh`, guarded by `creates:` so the installer is fetched once rather than on every run.

`verify.yml` sources `nvm.sh` before checking the version, because nvm is a shell function rather than a binary and does not exist on `PATH`.
