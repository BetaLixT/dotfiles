# tuigreet / greetd — customization context

Handoff doc, written 2026-09-11. Everything here was verified on this machine or
read from upstream source, not recalled. Where something is a judgement call or
unverified it says so.

Lives in the repo on purpose: an earlier handoff was written to `/tmp` and the
reboot destroyed it. `/tmp` here is tmpfs.

---

## 1. The stack, and why it is shaped this way

    greetd.service
      └─ cage -s -- alacritty --config-file /etc/greetd/alacritty.toml \
                      -e tuigreet

| Piece | Version | Job |
|---|---|---|
| `greetd` | 0.10.3-2 | login daemon, owns the VT, runs the greeter as user `greeter` |
| `cage` | 0.3.1-1 | minimal Wayland compositor, one app fullscreen. `-s` keeps VT switching working |
| `alacritty` | (system) | the terminal that actually gives truecolor + font rendering |
| `greetd-tuigreet` | 0.11.1-2 | the greeter UI. Arch tracks `github.com/tuigreet/tuigreet`, the Ratatui rewrite |

**THE CRITICAL CONSTRAINT.** The reason for the cage+alacritty sandwich is that a
bare Linux VT is an 8-colour terminal. Measured:

    tput -T linux colors      ->  8
    tput -T alacritty colors  ->  256

Running a TUI greeter directly on the VT crushes every hex colour to the nearest
ANSI slot. That is what killed the first attempt (ly): three separate rounds of
tuning Kanagawa hex values all came out grey/greenish, and no palette choice can
fix it. **If colours ever look wrong again, check terminal capability before
touching hex values.**

## 2. Files — repo source -> deployed destination

| Repo | Deployed to | Notes |
|---|---|---|
| `system/greetd/config.toml` | `/etc/greetd/config.toml` | the greetd command line, `vt = 1` |
| `system/greetd/alacritty.toml` | `/etc/greetd/alacritty.toml` | greeter terminal: colours + font |
| `system/tuigreet/config.toml` | `/etc/tuigreet/config.toml` | **theme + animation live here** |
| `system/greetd/sessions/sway-logged.desktop` | `/etc/greetd/sessions/` | the ONLY session tuigreet lists |
| `system/wayland-sessions/sway-logged.desktop` | `/usr/share/wayland-sessions/` | standard location, for the ly fallback |
| `scripts/start-sway.sh` | `/usr/local/bin/start-sway` | `install -Dm755` |
| `fonts/SF-Mono-Nerd-Font/*.otf` | `/usr/local/share/fonts/SF-Mono-Nerd-Font/` | greeter-readable; see §3 |

All deployed by `install-sway-arch.sh` (search for `# Login screen: greetd`).
They are **copied, not symlinked** — `/etc` is root-owned and these are read by
the `greeter` user.

Deploy after editing:

    cd ~/dotfiles && ./install-sway-arch.sh
    # or just the one file:
    sudo cp ~/dotfiles/system/tuigreet/config.toml /etc/tuigreet/config.toml

Changes take effect at the next greeter start (log out, or restart greetd from a
text TTY — NOT from inside the session, see §6).

## 3. Where colours come from — two separate layers

This tripped me up, so be explicit about which layer you are changing.

**Layer 1: alacritty** (`/etc/greetd/alacritty.toml`) sets the terminal's
background, foreground and 16 ANSI slots, plus the font. Kanagawa values here are
a hand-copy of `alacritty-lnx/alacritty.toml` — **there is no include mechanism,
so they must be synced by hand** if the terminal theme changes.

    [colors.primary] background = "0x1F1F28"   foreground = "0xdcd7ba"
    [font.normal]    family = "SFMono Nerd Font"   size = 14.0

**The font must be installed system-wide, and this was broken until 2026-09-11.**
`SFMono Nerd Font` existed only in `~/.local/share/fonts`. greetd runs the
greeter as the `greeter` user, and `/home/dcruza` is mode `0750` (its ACL grants
only `rslsync`), so fontconfig could not see it and **silently substituted Nimbus
Mono PS** — fontconfig raises no error for a missing family, it just picks
something else. Measured:

    env -i HOME=/nonexistent fc-match "SFMono Nerd Font"
      before -> NimbusMonoPS-Regular.otf   "Nimbus Mono PS"
      after  -> SFMono Regular Nerd Font Complete.otf   "SFMono Nerd Font"

The faces are now vendored in `fonts/SF-Mono-Nerd-Font/` and installed to
`/usr/local/share/fonts` by the install script, which also runs `fc-cache` and
then re-runs that same `fc-match` as a guard, warning if the family ever stops
resolving. The desktop terminal gets them from the same place.

Do **not** rely on the AUR package `nerd-fonts-sf-mono`: it is installed on this
machine but provides a different family name (`SFMono Nerd Font Mono`), and
nothing in the repo asks for it.

**Layer 2: tuigreet** (`/etc/tuigreet/config.toml`) sets the UI element colours
and the animation. These accept `#RRGGBB`, `0xRRGGBB`, or a ratatui named
colour. Hex parsing is covered by upstream tests in
`crates/tuigreet/src/ui/bg_animation/mod.rs::parse_color`.

Current `[theme]` (all 10 components set):

    container = "#1F1F28"   # sumiInk1  - matches alacritty background
    text      = "#DCD7BA"   # fujiWhite
    border    = "#957FB8"   # oniViolet - matches sway's focused border
    title     = "#957FB8"
    prompt    = "#7E9CD8"   # crystalBlue
    input     = "#E6C384"   # carpYellow
    greet     = "#7AA89F"   # waveAqua2
    time      = "#7AA89F"
    action    = "#C0A36E"   # boatYellow2
    button    = "#E6C384"   # carpYellow - brighter twin of action

Component meanings (from upstream README): `text` is the base; `time` is the
date/time and falls back to `text`; `container` is the centred box background;
`border` its border; `title` falls back to `border`; `greet` is the issue/greeting
and falls back to `text`; `prompt` is "Username:" etc.; `input` is typed
feedback; `action` is the bottom-row actions; `button` is their key hints and
falls back to `action`.

## 4. Animations

Two ship upstream. Current config uses `doom`.

    [background]
    kind = "doom"          # "doom" | "matrix" | "none"
    fps = 30

    [background.doom]
    height = 5             # 1-9, taller flames at higher values
    spread = 2             # 0-4, horizontal jitter
    top_color    = "#C34043"   # autumnRed
    middle_color = "#DCA561"   # autumnYellow
    bottom_color = "#1F1F28"   # sumiInk1 - fades into the background

    [background.matrix]        # the alternative
    head_color = "..."  bright_color = "..."  dim_color = "..."
    min_length = 6      max_length = 18
    min_speed = 0.30    max_speed = 1.10
    mutate_chance = 0.02

Aliases accepted: `doom`/`fire`, `matrix`/`cmatrix` (see `Kind::from_name`).

**`F4` switches animation live at the greeter**, no restart — the quickest way to
compare. The menu is generated from the `KINDS` registry, so anything added
upstream appears automatically.

### Adding a new animation

Possible, but **Rust at compile time only — there is no runtime plugin loading.**
In `crates/tuigreet/src/ui/bg_animation/`:

    mod.rs      trait Animation { resize(); step(); render(); }
                enum Kind          — add a variant
                const KINDS        — add a KindInfo entry (drives the F4 menu)
                enum AnimationSpec — add a variant
                fn build()         — add the dispatch arm
    doom.rs     }  existing implementations to copy the shape from
    matrix.rs   }

PINNED idea: port ly's `colormix`. Its source is
`src/animations/ColorMix.zig`, ~130 lines, and worth understanding before
copying: it is **not** a pixel shader. It builds a 12-entry palette of three
colours taken as PAIRS — (col1,col2), (col2,col3), (col3,col1) — each drawn with
block glyphs `0x2588` █ full, `0x2593` ▓, `0x2592` ▒, `0x2591` ░. The shades
dither the pair's fg/bg at ~75/50/25%.

Consequence, learned the hard way: **the full block renders a colour at FULL
strength over large areas, so the brightest of the three dominates the entire
screen** regardless of how dark the other two are. One mid-luminance colour
(oniViolet #957FB8, ~53% luminance) was enough to wash everything out. If
porting it, keep all three dark.

## 5. Other tuigreet settings currently in use

    [secret]
    mode = "characters"      # or "hidden"
    characters = "*"

`--asterisks` and `[display] asterisks` are **deprecated**; `secret.mode` wins if
both are set.

    [session]
    sessions_dirs = ["/etc/greetd/sessions"]
    xsessions_dirs = []

Deliberately NOT `/usr/share/wayland-sessions`, which also contains the stock
`sway.desktop`. That entry runs `sway` directly and produces **no journal log**;
having both listed meant one careless F3 pick silently lost logging, which is
exactly what happened on the first login. One entry = cannot be mis-picked.

    [keybindings]
    command = 2   sessions = 3   background = 4   power = 12   # F-key numbers

Command-line flags in `/etc/greetd/config.toml`: `--remember`,
`--remember-user-session`, `--time`. All verified as documented upstream.

**`--remember*` needs `/var/cache/tuigreet` to exist and be owned by `greeter`**
or it silently does nothing. The install script creates it, chowns it, and
pre-seeds `lastsession-path-$USER` with the logged session.

    /var/cache/tuigreet/lastuser
    /var/cache/tuigreet/lastsession-path-dcruza

Config search order: `~/.config/tuigreet/config.toml` (useless here — greeter
user), then `/etc/tuigreet/config.toml`, then `--config <path>`. Priority: CLI
args > env vars > user config > system config > defaults. There are also
`TUIGREET_THEME_*` env vars.

## 6. Gotchas that have already caused real damage

**Do not restart greetd from inside the session it will contend with.** The
packaged `greetd.service` declares `Conflicts=getty@tty1.service`, and
`getty@tty1` has `TTYVHangup=yes`. Stopping it SIGHUPs anything whose
*controlling terminal* is tty1 — which killed a running sway session on
2026-09-11. A cgroup check said the session was safe; cgroups cannot see the
controlling-terminal path. Config is now `vt = 1`, aligned with the unit. Test
from a text TTY (tty2-6) or reboot.

**Paths must be absolute in session entries.** `--cmd start-sway` could never
resolve: greetd launches sessions with a minimal environment that excludes
`~/.local/bin`. Hence `/usr/local/bin/start-sway` and
`Exec=/usr/local/bin/start-sway`.

**Verify the wrapper is actually being used** by the sway cmdline: `sway --verbose`
means logging is on; a bare `sway` means the stock session entry got used.

## 7. Diagnosing

    systemctl status greetd --no-pager
    journalctl -u greetd -b --no-pager | tail -40     # cage/alacritty failures show here
    journalctl -t sway -b                             # 447 entries on a good login
    cat /var/cache/tuigreet/lastsession-path-dcruza

A restart loop logs `error: check_children: greeter exited without creating a
session`. Check `NRestarts` — it should be 0.

Fallback to ly (still installed and configured, just disabled):

    sudo systemctl disable greetd && sudo systemctl enable ly@tty2

## 8. Known-untidy / open

- The alacritty colours in `system/greetd/alacritty.toml` are a hand-copy and can
  drift from `alacritty-lnx/alacritty.toml`. No include mechanism exists.
- `system/wayland-sessions/sway-logged.desktop` and
  `system/greetd/sessions/sway-logged.desktop` are identical files kept in two
  places for two consumers. Could be one source installed twice.
- Nothing in the repo is committed. See `open-threads.md` §7.
- tuigreet has **no vi keybindings** — only F-keys. ly had `vi_mode` and was given
  up for correct colours. If vi motions matter more than colour, that trade is
  revisitable (§11 of `open-threads.md`).
