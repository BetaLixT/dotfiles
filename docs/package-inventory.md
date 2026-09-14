# Package inventory

Snapshot of this machine taken 2026-09-14, for rebuilding a
similar setup elsewhere. Regenerate the counts with the commands in section 7.

**This machine is a Lenovo laptop (Alder Lake, Intel Iris Xe).** A desktop rebuild
should skip the laptop- and Intel-specific packages flagged in section 3.

## 1. Totals

| | count |
|---|---|
| All installed (incl. dependencies) | 1378 |
| **Explicitly installed** | 158 |
| — from official repos | 136 |
| — foreign / AUR | 22 |
| Orphans (unneeded, see section 6) | 32 |

Only the explicit ones matter for a rebuild; pacman pulls the rest.

## 2. Install methods in use

There are **eight** distinct mechanisms here. Anything not reproduced by the
install script is called out.

| Method | Count | Reproduced by `install-sway-arch.sh`? |
|---|---|---|
| pacman (official) | 136 | partly — only the handful it guards |
| AUR via `yay` | 22 | no |
| `dotnet tool install -g` | 2 | no |
| nvim `mason` | 6 | auto, on first nvim launch |
| nvim `lazy.nvim` | 41 pinned | auto, `lazy-lock.json` pins versions |
| `go install` | 15 | no |
| `npm -g` (under `nvm`) | 5 | no |
| flatpak | 1 | no |

Plus manual binaries and git clones — section 5.

## 3. Official repo packages (136)

  alacritty aspnet-runtime-10.0 aspnet-runtime-9.0 azure-cli base base-devel bc bluez
  bluez-utils btop btrfs-progs cage calibre cifs-utils cliphist code dbeaver dmenu docker
  dotnet-runtime dotnet-runtime-9.0 dotnet-sdk dotnet-sdk-8.0 dotnet-sdk-9.0 earlyoom
  efibootmgr ex-vi-compat fastfetch filezilla firefox flatpak foot freerdp git gitleaks
  glow go graphicsmagick graphviz greetd greetd-tuigreet grim gst-plugin-pipewire helm htop
  hyprpicker imagemagick imv inetutils kubectl lazygit ldns libinput-tools libnotify
  libpulse libreoffice-fresh linux linux-firmware ly mako man-db nano neovim
  network-manager-applet networkmanager networkmanager-dmenu noto-fonts-emoji nvm okular
  pacman-contrib pandoc-cli pavucontrol pcmanfm pipewire pipewire-alsa pipewire-pulse
  protobuf pulsemixer python-pip recordmydesktop remmina ripgrep rofimoji rust slurp
  smartmontools sox sway swaybg swayidle swaylock swaync swayosd terraform tmux
  tree-sitter-cli ueberzugpp unrtf unzip valkey vim vlc vlc-plugin-ffmpeg waybar wdisplays
  wev wf-recorder wget wireplumber wl-clipboard wlsunset wob wofi xdg-utils xorg-xwayland
  xournalpp yazi zed zip zram-generator zsh

### Laptop / Intel specific — SKIP on a desktop unless it applies

  brightnessctl intel-media-driver intel-ucode iwd libva-intel-driver sof-firmware tlp
  vulkan-intel wireless_tools

`tlp` and `brightnessctl` are laptop power/backlight. `intel-*`, `vulkan-intel`
and `libva-intel-driver` are for Iris Xe. `iwd`/`wireless_tools` are wifi;
`sof-firmware` is this laptop's audio DSP.

### Other-GPU drivers — installed speculatively, probably unused here

  vulkan-radeon xf86-video-amdgpu xf86-video-ati xf86-video-nouveau

Pick the one matching the new machine's GPU instead of installing all of them.

### Legacy X — likely unnecessary on a pure Wayland setup

  xorg-server xorg-xinit

`xorg-xwayland` IS needed (X11 apps under sway); `xorg-server` and `xorg-xinit`
are a full X session and probably leftovers.

## 4. AUR packages (22)

Installed with `yay`. `yay-bin` itself must be bootstrapped first by cloning from
the AUR and running `makepkg -si`.

  bluetuith brave-bin docker-desktop eww herdr-bin hey-bin kanagawa-gtk-theme-git
  microsoft-edge-stable-bin nerd-fonts-sf-mono ngrok postman-bin powershell-bin
  rofi-bluetooth-git rslsync storageexplorer wlprop xdg-desktop-portal-termfilechooser-git
  xdg-desktop-portal-wlr-git xf86-video-vmware yay-bin yay-bin-debug zen-browser-bin

Notable: `herdr-bin` (terminal multiplexer for agents), `zen-browser-bin` (the
daily browser), `kanagawa-gtk-theme-git` (provides `/usr/share/themes/Kanagawa-Dark`,
which `GTK_THEME` points at), `nerd-fonts-sf-mono` (the greeter and terminal font),
`rslsync`, `xdg-desktop-portal-termfilechooser-git` (yazi as the file picker).

`*-debug` packages are debug symbols pulled in automatically; do not install them
deliberately.

## 5. Non-pacman installs

### dotnet global tools
    dotnet tool install -g dotnet-ef
    dotnet tool install -g roslyn-language-server --prerelease \
      --source https://pkgs.dev.azure.com/azure-public/vside/_packaging/vs-impl/nuget/v3/index.json

The Azure DevOps feed is deliberate — it tracks the version VS Code ships;
nuget.org lags. Note `dotnet-ef` is ALSO pinned per-project via
`.config/dotnet-tools.json` manifests, which is the better pattern.

### nvim — mason
`csharpier`, `docker-langserver`, `gopls`, `lua-language-server`, `netcoredbg`,
`rust-analyzer`. Installed on demand by mason; `:MasonInstall` to force.

### nvim — lazy.nvim
41 plugins, versions pinned in `nvim/lazy-lock.json`. Restored automatically on
first launch. `nvim-treesitter` is pinned to the **`main`** branch — the `master`
branch is frozen at Neovim 0.11 and breaks on 0.12+.

### go install (15 binaries)
  dlv easyjson gopls handlergen hndlrgen kubent protoc-gen-go protoc-gen-go-grpc
  protoc-gen-goblthttp protoc-gen-goconsgen protoc-gen-goconstrgen protoc-gen-gocqrshttp
  protoc-gen-gog3v2 staticcheck wire

Mostly protobuf/codegen tooling plus `dlv` (debugger) and `staticcheck`.

### npm -g, under nvm
`backlog.md`, `bun`, `corepack`, `npm`, `pnpm`. Node itself is managed by `nvm`
(pacman package), with 4 versions installed:
v20.20.2, v21.7.3, v22.14.0, v22.23.1.

### flatpak
`it.mijorus.gearlever` (AppImage manager).

### Manual binaries in `~/.local/bin`
- `d2` (47 MB) and `typst` (55 MB) — dropped in by hand, **no package manager
  tracks these, so they will not update**
- `claude` — symlink into `~/.local/share/claude/versions/`
- `agent-native`, `orca-ide` — point into `~/projects/personal/`
- `start-sway` — symlink into this repo

### Manual binaries in `/usr/local/bin`
- `start-sway` — installed by `install-sway-arch.sh`
- `tuigreet-custom` — a wrapper that prefers a locally-built tuigreet and falls
  back to the packaged one. **Created outside this repo**; if a custom tuigreet
  build is part of the setup, that build process is not captured anywhere yet.
- `docker`, `compose-bridge` — symlinks from docker-desktop

### git clones
- `~/.oh-my-zsh`
- `~/.tmux/plugins/tpm` + `tmux-resurrect`, `tmux-continuum`
- `~/.config/yazi/flavors/kanagawa.yazi` (cloned by the install script)

## 6. Orphans — do NOT reinstall (32)

  bluetuith-debug docker-desktop-debug dwarfs dwarfs-debug electron34 electron37 electron39
  fuse2 gnu-netcat-debug gtk-engine-murrine-debug haskell-foldable1-classes-compat
  herdr-bin-debug hey-bin-debug intltool libayatana-appindicator libayatana-indicator
  lua-lpeg mathjax powershell-bin-debug python-freezegun python-ftputil python-pytest
  python-pyzstd python-sgmllib3k rslsync-debug scenefx0.4 sdl2_ttf squashfs-tools
  storageexplorer-debug w3m xdg-desktop-portal-termfilechooser-git-debug xdg-user-dirs

Mostly `*-debug` symbol packages and abandoned deps. On this machine they can be
removed with `sudo pacman -Rns $(pacman -Qdtq)`; on a new machine simply never
install them.

## 7. Regenerating this inventory

    pacman -Qenq                     # explicit, official
    pacman -Qemq                     # explicit, foreign/AUR
    pacman -Qdtq                     # orphans
    dotnet tool list --global
    ls ~/.local/share/nvim/mason/bin/
    ls ~/go/bin ~/.local/bin /usr/local/bin
    npm ls -g --depth=0
    flatpak list --app

To reinstall in bulk on a new machine, use the bootstrap script rather than
doing it by hand:

    ./scripts/bootstrap.sh --desktop --dry-run    # see what it would do
    ./scripts/bootstrap.sh --desktop              # software only
    ./install-sway-arch.sh                        # then configuration

Lists it reads, all regenerable:

    packages/official.txt              all 136 explicit official packages
    packages/official-laptop-only.txt  skipped by --desktop
    packages/official-review.txt       always skipped; decide per machine
    packages/aur.txt                   22 AUR packages
    packages/go-tools.txt              11 public Go modules
    packages/npm-global.txt            global npm packages

## 8. Remaining gaps

`scripts/bootstrap.sh` now covers packages, AUR bootstrap, dotnet tools, Go
tools, npm globals, flatpak, oh-my-zsh and TPM. What it deliberately does not
handle:

1. **`d2` (47 MB) and `typst` (55 MB)** in `~/.local/bin` are hand-dropped
   binaries with no package manager behind them. They will not update and the
   script cannot fetch them.
2. **`/usr/local/bin/tuigreet-custom`** expects a locally built tuigreet. That
   build process is not described by any file in this repo.
3. **Private Go modules** (`techunicorn.com/golang/hndlrgen`,
   `constructorgen`, `protoc-gen-gocqrshttp`, `protoc-gen-gog3v2`) are
   deliberately excluded — they need company credentials and only matter on a
   machine already set up for that work. `GOPRIVATE` is set in `.zshrc-lnx`;
   `go install` them by hand if needed.
4. **`xf86-video-vmware`** is in the AUR list — a VMware guest driver, almost
   certainly unwanted on real hardware. There is no AUR equivalent of
   `official-review.txt`; remove it by hand if it does not apply.
5. **Hardware drivers on `--desktop`** are skipped entirely, with a printed
   reminder. Pick per machine: Intel `vulkan-intel intel-media-driver`,
   AMD `vulkan-radeon`, NVIDIA `nvidia nvidia-utils`.
6. **nvim plugins and mason tools** install themselves on first `nvim` launch,
   so they need one interactive run rather than a scripted step.
