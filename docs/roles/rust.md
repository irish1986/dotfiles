# rust

The [Rust](https://www.rust-lang.org/) toolchain -- `cargo`, `rustc` and `rustup` -- installed user-scoped from the upstream [rustup](https://rustup.rs/) installer.

## Why rustup and not the apt package

`apt install cargo rustc` pins the toolchain to whatever the release shipped: 1.75 on 24.04, older on 22.04. Crates increasingly declare a `rust-version` newer than that, and when one does, the build fails with no way forward short of adding a PPA. rustup keeps the toolchain independent of the distro, which is the same reason [nvm](nvm.md) and [uv](uv.md) are here rather than their apt equivalents.

It also means `cargo` is user-owned, so `cargo install` needs no `sudo` and nothing lands in `/usr/local`.

## What gets installed where

| Path | Contents |
| --- | --- |
| `~/.cargo/bin` | `cargo`, `rustc`, `rustup`, `rustfmt`, `clippy-driver` |
| `~/.cargo/env` | the `PATH` snippet the shell sources |
| `~/.rustup` | toolchains and their components |

`build-essential` is a real dependency, not a precaution: cargo shells out to `cc` as its default linker and cannot produce a binary without it.

## PATH

The installer runs with `--no-modify-path`. Left to itself, rustup appends its own `PATH` line to `.profile`, `.bashrc` *and* `.zshenv`, which on this repo's setup would put `~/.cargo/bin` on `PATH` two or three times over.

Instead the [zsh role](zsh.md) sources the env script behind the same guard it uses for uv:

```zsh
[[ -r $HOME/.cargo/env ]] && source $HOME/.cargo/env
```

The guard matters because the file does not exist until this role has run, and an unguarded `source` would print an error at every prompt on a box where `rust` is not selected. `verify.yml` asserts the file is actually there -- without that check a broken install would leave a green playbook and no `cargo` in a new shell.

## Choosing a toolchain

`rust_toolchain` accepts anything `rustup default` does:

```yaml
rust_toolchain: stable    # tracks releases
rust_toolchain: "1.90.0"  # frozen
rust_toolchain: nightly
```

It is re-applied on every run, not just at install time, so changing it in `group_vars` takes effect on a machine that already has rustup.

`rust_profile` selects how much comes with it -- `minimal`, `default` or `complete`. `default` already includes `rustfmt` and `clippy`, which is why `rust_components` is empty; add to it for anything beyond the profile:

```yaml
rust_components:
  - rust-analyzer
  - rust-src
```

## Ordering

`rust` depends on no other role and nothing here depends on it, so it can go anywhere in `dotfiles_roles`. It is opt-in and commented out in the example configuration.
