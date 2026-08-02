# fonts

Nerd Fonts, on both sides of the WSL boundary.

This role installs the Linux side -- `~/.local/share/fonts` plus a `fc-cache` rebuild. The Windows side is the [wsl role](wsl.md), which stages from the directory this one populates, so `fonts` must come first in `dotfiles_roles`.

Both sides are needed on WSL: the Windows font is what the terminal actually draws with, and the Linux font feeds `fc-list`, WSLg applications and matplotlib.

`fonts_nerd_fonts` holds release **asset names**, not a family label. The previous value was `Nerd`, which built a URL for `Nerd.zip` -- an asset that has never existed in a Nerd Fonts release.

Three further faults were fixed here, none of which had ever been noticed because a stringly-typed WSL conditional meant the role had never run: the font directory was created mode `0644`, and a directory without the execute bit cannot be traversed; the `fc-cache` handler reported *changed* only when the command **failed**; and `fontconfig` was never installed, so `fc-cache` did not exist.
