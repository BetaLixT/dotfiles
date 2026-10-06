# Fedora port of the sway setup

Fedora counterpart of the Arch bootstrap. Written against **Fedora 44 / dnf5**
and validated in a container (`scripts/test-bootstrap-fedora.sh`).

```
./scripts/bootstrap-fedora.sh --laptop     # software
./install-sway-arch.sh                     # configuration (runs on both distros)
```

## File map

| Arch | Fedora |
|---|---|
| `scripts/bootstrap.sh` | `scripts/bootstrap-fedora.sh` |
| `scripts/test-bootstrap.sh` | `scripts/test-bootstrap-fedora.sh` |
| `packages/official.txt` | `packages/fedora.txt` |
| `packages/official-laptop-only.txt` | `packages/fedora-laptop-only.txt` |
| `packages/official-review.txt` | `packages/fedora-review.txt` |
| `packages/aur.txt` | `packages/fedora-copr.txt` + repos + flatpak + go/cargo |
| `install-sway-arch.sh` | *same file* — now distro-aware |

`packages/go-tools.txt` and `packages/npm-global.txt` are shared unchanged.

## install-sway-arch.sh is no longer Arch-only

It was ~362 lines of symlinks plus eight `pacman` calls that deployed a config
right after installing its package. On Fedora those died at
`pacman: command not found`. They now go through a shim:

```sh
pkg_need    <arch-name> [fedora-name]   # install if missing
pkg_installed <arch-name> [fedora-name] # query only
```

The Arch branch issues byte-identical commands to before, so running it on the
existing laptop is unchanged. Only two names actually differ:

| Arch | Fedora | note |
|---|---|---|
| `greetd-tuigreet` | `tuigreet` | the Arch name does not exist on Fedora |
| `openssh` | `openssh-server` | Fedora *has* an `openssh`, but it is client+common only — installing it would leave `sshd.service` missing |

Everything else is identical, including two paths worth noting because they
were the likely breakages and turned out not to be:

* `/etc/default/earlyoom` — Fedora's unit really does carry
  `EnvironmentFile=-/etc/default/earlyoom`, not the `/etc/sysconfig` location
  Fedora usually prefers.
* `/etc/systemd/zram-generator.conf` — same path on both.
* `sshd.service` — same unit name on both.

The script was renamed-in-spirit but not on disk; `install-sway-arch.sh` is
referenced by docs and commit history, so the name stayed.

## Where the AUR packages went

Fedora has no single AUR equivalent, so the 22 AUR packages split five ways.

**COPR** (`packages/fedora-copr.txt`) — same trust model as the AUR: each line
is a decision to trust that owner. All four were confirmed to exist via the
COPR API.

| package | project |
|---|---|
| `lazygit` | `atim/lazygit` |
| `nerd-fonts` | `che/nerd-fonts` |
| `hyprpicker` | `solopasha/hyprland` |
| `yazi` | `lihaohong/yazi` |

**Vendor RPM repos** (the `repos` phase). Microsoft needs **three separate
repos**, and the obvious one is the wrong one:

| what | repo |
|---|---|
| `powershell` | `packages.microsoft.com/rhel/9/prod` |
| `microsoft-edge-stable` | `packages.microsoft.com/yumrepos/edge` |
| `code` | `packages.microsoft.com/yumrepos/vscode` |
| `brave-browser` | `brave-browser-rpm-release.s3.brave.com` |
| `resilio-sync` | `linux-packages.resilio.com` |
| `docker-ce` + plugins | `download.docker.com/linux/fedora` |
| codecs, nonfree drivers | RPM Fusion free + nonfree |

> `packages.microsoft.com/fedora/<ver>/prod` exists and returns a valid
> `repomd.xml` for Fedora 41–44, which makes it look correct. Reading its
> `primary.xml` shows it carries only `mdatp`, `procdump`, `procmon`,
> `sysinternalsebpf`, `libmsquic` and `packages-microsoft-prod` — **no
> powershell, no edge**. Pointing at it is a silent failure: the repo loads,
> then the package is "not found". This cost one test cycle to catch.

**Flathub** — apps with no maintained RPM, the same bargain the `-bin` AUR
packages were: `app.zen_browser.zen`, `com.getpostman.Postman`,
`io.dbeaver.DBeaverCommunity`, `dev.zed.Zed`, `it.mijorus.gearlever`.

**go install** — `bluetuith`, `hey` (both AUR-only on Arch).

**cargo / pipx / tarball** — `eww` (cargo, needs `gtk3-devel
gtk-layer-shell-devel`), `pulsemixer` (pipx; Fedora enforces PEP 668 so plain
`pip install --user` is refused), `ngrok` (tarball — see below).

## ngrok has no RPM repo

ngrok's docs imply `https://ngrok-agent.s3.amazonaws.com/rpm`. That path 404s.
Listing the bucket shows only `dists/`, `pool/` and `ngrok.asc` — it is a
**Debian-only** repository. The `bin` phase installs the published tarball to
`~/.local/bin` instead; verified to deliver a working `ngrok version 3.39.11`.

## Things Fedora simply does not have

No package, no COPR, no flatpak. Build from source or do without:

`ueberzugpp`, `swayosd`, `recordmydesktop`, `networkmanager-dmenu`,
`hyprpicker`, `nvm`, `herdr`, Docker Desktop, Azure Storage Explorer,
SF Mono Nerd Font, `kanagawa-gtk-theme`, `rofi-bluetooth`, `wlprop`,
`d2`, `typst`.

`hyprpicker` deserves a note: `solopasha/hyprland` carries it and the project
resolves fine over the COPR API, but it builds for **rawhide only**, so
`copr enable` succeeds and then installs nothing on a stable release. The
colour picker entry in `scripts/options-menu.sh` is dead on Fedora until you
build it yourself.

One consequence worth knowing before switching:

* **`terraform` is `opentofu`.** HashiCorp relicensed under the BSL, so Fedora
  ships the fork. Same HCL, different binary name.

## One browser: Firefox

Brave, Edge and Zen are deliberately **not** installed on either distro.
The Arch side drops them via `packages/aur-review.txt`; the Fedora side never
adds the Brave or Edge repos.

The question was whether something lighter than Firefox could replace it. It
cannot, and the reason is structural: **full WebExtension support exists only
on Gecko and Chromium.** Everything genuinely lighter gives it up.

| Browser | Engine | WebExtensions |
|---|---|---|
| qutebrowser | QtWebEngine | none (built-in adblock only) |
| Falkon | QtWebEngine (Chromium) | none -- own legacy system, no modern API |
| Pale Moon | Goanna | none, by design (legacy XUL) |
| Midori | WebKitGTK | basic adblock only |
| Waterfox | Gecko | yes -- but a Firefox fork, so no memory win |

Falkon is the instructive case: it is Chromium-based and *still* has no
WebExtension support, because the engine is not what provides it.

Between the two engines that do, Firefox is the lighter: it caps content
processes at 8 while Chromium spawns a renderer per site origin, which is
roughly 3.8 GB vs 6.5 GB at 50 tabs. **Zen, despite being a Firefox fork,
benchmarks heavier than Firefox itself** (5424 MB vs 4755 MB) -- the workspace
UI costs memory. On the machine that prompted the earlyoom and zram work, that
is the wrong direction, so dropping Zen is a small real win rather than just a
disk saving.

### What this costs: Teams

Firefox cannot screen-share in Teams web, and incoming calls divert to your
phone. Microsoft discontinued its own Linux Teams client, so the options are a
dedicated Electron app or a second browser engine. The app is far smaller:

```sh
./scripts/bootstrap-fedora.sh --laptop --only teams   # Fedora: upstream RPM
./scripts/bootstrap.sh        --laptop --only teams   # Arch:   teams-for-linux-bin
```

`IsmaelMartinez/teams-for-linux` is actively maintained (v2.24.0, 3 Oct 2026)
and ships an x86_64 RPM. Wayland screen sharing goes through the PipeWire
portal, and `xdg-desktop-portal-wlr` is already in the package list. Sharing a
whole output is reliable; sharing a single window is still rough upstream.

Both `teams` phases are **opt-in**: they use `want_explicit`, so they never run
in a default sweep and only fire when named by `--only teams`.

## rofi is Wayland-native — `rofi-wayland` is obsolete on both distros

There is no `rofi-wayland` package on Fedora, and that is **not** a gap. The
lbonn Wayland fork was merged upstream in rofi 2.0, and Fedora's changelog
says so outright:

```
* Mon Sep 01 2025 Aleksei Bavshin <alebastr@fedoraproject.org> - 2.0.0-1
- Update to 2.0.0
- Enable Wayland backend and replace rofi-wayland
```

`rofi -help` on Fedora reports:

```
Display backends:
	• xcb
	• wayland          <- "wayland enabled (1.24.0)"
```

Arch did the same thing: `rofi-wayland` there is now `rofi 2.0.0-1` via
`provides`. Both distros are on the identical upstream release, so
`packages/official.txt`'s `rofi-wayland` maps to plain `rofi` and nothing is
lost. `rofi/config.rasi` and `rofi/kanagawa.rasi` were both parsed against
Fedora's build (`-dump-theme`, `-dump-config`) with no errors or warnings.

`xorg-x11-server-Xwayland` stays in the package list, but for the genuinely
X11-only apps (Electron bundles, Storage Explorer), not for rofi.

## Naming differences that are easy to get wrong

| Arch | Fedora |
|---|---|
| `swaync` | `SwayNotificationCenter` (capitalised) |
| `vim` | `vim-enhanced` (plain `vim` is a meta-package) |
| `wget` | `wget2-wget` |
| `go` | `golang` |
| `kubectl` | `kubernetes1.34-client` (versioned) |
| `python-pip` | `python3-pip` |
| `networkmanager` | `NetworkManager` |
| `pipewire-pulse` | `pipewire-pulseaudio` |
| `noto-fonts-emoji` | `google-noto-emoji-fonts` |
| `xorg-xwayland` | `xorg-x11-server-Xwayland` |
| `intel-ucode` | `microcode_ctl` |
| `intel-media-driver` | `libva-intel-media-driver` |
| `sof-firmware` | `alsa-sof-firmware` |
| `wireless_tools` | `iw` |
| `rofi-wayland` | `rofi` (2.0 merged the fork; see above) |
| `graphicsmagick` | `GraphicsMagick` |
| `imagemagick` | `ImageMagick` |
| `libinput-tools` | `libinput-utils` |
| `pandoc` | `pandoc-cli` |
| `gst-plugin-pipewire` | `pipewire-gstreamer` |
| `vulkan-intel` / `vulkan-radeon` | `mesa-vulkan-drivers` (one package, all ICDs) |

That last row is why `fedora-laptop-only.txt` is shorter than its Arch
counterpart: Arch splits the Vulkan ICD per vendor, so it was laptop-only;
Fedora ships them together, so it belongs on both profiles.

## .NET

The real divergence. Arch has one rolling `dotnet-sdk`; Fedora versions the
packages and carries **8.0, 9.0 and 10.0 side by side**. The channel is
explicit and overridable:

```sh
DOTNET_CHANNEL=10.0 ./scripts/bootstrap-fedora.sh --laptop --only dotnet
```

Default is `9.0`. All three channels were confirmed to have all of
`dotnet-sdk-*`, `dotnet-runtime-*` and `aspnetcore-runtime-*`.

The two global tools are unchanged from Arch, including the Azure DevOps feed
for `roslyn-language-server` (it tracks what VS Code ships; nuget.org lags).
`~/.dotnet/tools` must be on `PATH` — `.zshrc-lnx` already does this.

## Testing

```sh
./scripts/test-bootstrap-fedora.sh            # resolve + dry-run  (~2 min)
./scripts/test-bootstrap-fedora.sh --repos    # really enable the vendor repos
./scripts/test-bootstrap-fedora.sh --full     # really install (slow, GBs)
./scripts/test-bootstrap-fedora.sh --shell    # interactive container
```

Twelve checks: every package name resolves, laptop-only names are not orphans,
COPR projects exist, vendor endpoints are reachable, dry-run works as non-root,
both profiles, all ten phase filters, refuses root, requires a profile, all
three .NET channels, the distro shim picks the Fedora branch, and no bare
`pacman` survives in `install-sway-arch.sh`.

What it deliberately does not test: greetd, sway and GPU drivers need real
hardware and a session. Use a VM.

### Caveat on the container

`fedora:latest` tracks the newest release (44 at time of writing) while the
installer ISO may be a release behind. Pin it if that matters:

```sh
FEDORA_IMAGE=fedora:43 ./scripts/test-bootstrap-fedora.sh
```

Package resolution is the check most likely to differ between the two.

### Use `repoquery`, not `dnf list`, to check a name

The first version of test 1 called `dnf -q list --available <pkg>` once per
package. Two problems, both of which bit:

* **It is slow and fragile.** 126 invocations, each re-checking metadata. One
  stalled mirror request hung the whole suite for 28 minutes with no output.
* **It glob-matches and ignores case.** `dnf list imagemagick` succeeds against
  a package actually named `ImageMagick`, so the list carried a name that
  `dnf install` would have rejected. One `dnf repoquery --qf '%{name}\n'` over
  every name at once is exact, and a set difference against the wanted list
  gives the misses. It is also ~100x faster.

### Watch `set -o pipefail` around `head`

`dnf --version | head -1 | grep -q '^dnf5'` is a race. `head` closes the pipe,
`dnf` takes SIGPIPE, the pipeline reports failure under `pipefail`, and dnf
generation silently detects as 4 on a dnf5 box — which then uses the wrong
`config-manager` syntax and breaks the repos phase. The same container
reported 5 on one run and 4 on the next. Read the version with a command
substitution instead; test 13 runs the detection 8 times to keep it honest.
