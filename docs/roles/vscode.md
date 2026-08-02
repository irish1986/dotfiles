# vscode

Visual Studio Code from the Microsoft apt repository.

A deliberate no-op on WSL, with an explanatory message rather than a silent skip: there, VS Code runs on Windows and attaches to the distro through the Remote-WSL extension, so a Linux build inside WSL is redundant and pulls in a large GUI dependency tree.

The role also dropped `files/vscode.sh`, macOS-only dead code referencing `/opt/homebrew` and a settings path that does not exist, invoked by nothing and ending in an interactive `read`.
