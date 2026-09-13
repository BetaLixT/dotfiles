# SF Mono Nerd Font

Apple's SF Mono, patched with the [Nerd Fonts patcher](https://github.com/ryanoasis/nerd-fonts#font-patcher).

Vendored from <https://github.com/epk/SF-Mono-Nerd-Font> at commit `ebd4255`
(2024-07-19). Only the `.otf` files are kept; the upstream README screenshot and
git history are not.

## Why this lives in the repo

These faces provide the fontconfig family **`SFMono Nerd Font`**, which is the
family named by both `alacritty-lnx/alacritty.toml` (the desktop terminal) and
`system/greetd/alacritty.toml` (the login screen).

Previously they existed only in `~/.local/share/fonts`, which meant:

* a fresh install had no SF Mono at all until the fonts were cloned by hand, and
* the **greeter could never see them**. greetd runs the greeter as the `greeter`
  user, and `/home/dcruza` is mode `0750` (its ACL grants only `rslsync`), so
  fontconfig silently fell back to Nimbus Mono PS on the login screen.

`install-sway-arch.sh` now installs them to `/usr/local/share/fonts`, which is
world-readable and scanned by the system fontconfig, so the desktop and the
greeter resolve the same family.

Note the AUR package `nerd-fonts-sf-mono` provides a *different* family name
(`SFMono Nerd Font Mono`) and is not required by these dotfiles.
