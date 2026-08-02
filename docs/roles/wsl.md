# wsl

Everything that crosses into Windows: `wsl.conf`, `.wslconfig`, Windows Terminal settings, Windows font registration and the clipboard bridge.

A no-op off WSL. **Nothing here needs administrator rights.**

See [Windows and WSL](../getting-started/windows-wsl.md) for the user guide and [the architecture page](../architecture/wsl.md) for the reasoning.

## Requires a restart

`wsl.conf` and `.wslconfig` changes apply only after `wsl --shutdown`, run from Windows. A handler reports when either changed; the role cannot run the command itself, since doing so from inside the distro would terminate the playbook.

## Windows Terminal

Only `profiles.defaults` and the scalar globals are managed, merged into the parsed live file. `profiles.list`, `actions`, `keybindings`, `schemes` and `themes` are left alone -- `combine(recursive=true)` replaces lists wholesale, so managing them would silently revert UI changes.

Templating the whole file was rejected: the profile actually in use comes from the AppX generator, whose GUID is not reproducible from any documented formula, so a static `settings.json` can only ever match one machine and one Ubuntu version. The default profile is resolved by inspecting the live profile list instead.

The previous implementation wrote to the package root, omitting the `LocalState/` segment, so Terminal never read the file it produced.

## Fonts

Per-user install to `%LOCALAPPDATA%\Microsoft\Windows\Fonts` plus matching `HKCU` values, which needs no elevation. Two things make this harder than it looks:

- The registry value **name** must be the Win32 friendly name, e.g. `Hack Nerd Font Bold (TrueType)`, not the filename. `GlyphTypeface` exposes family *and* face names; `System.Drawing.PrivateFontCollection` reports the family for every weight, so all four would collide on one key.
- `New-Item -Path <registry key> -Force` **recreates the key and deletes every value in it.** The first version of this script therefore wiped the whole per-user font registry on each run. `-Force` is safe for directories, not keys.

A font file already loaded by a running process cannot be replaced, so a sharing violation is reported and the existing copy left in place rather than failing the run -- but the registry entry is still reconciled, because a file being present is not the same as Windows knowing about it.
