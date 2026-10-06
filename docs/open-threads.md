# Open threads

Running state of in-flight work on this machine. Updated 2026-09-01.
Companion docs: `freeze-diagnosis.md`, `monitor-inventory.tsv`, `herdr-setup.md`,
`claude-phone-approvals.md`.

**Everything below is uncommitted in git.** See §7.

---

## 1. Memory / OOM  — DONE, verified through a reboot

Cause of the 2026-08-10 stall: a Claude Code process reached 11.6 GB, exhausted
the 4 GB zram, and the desktop thrashed until the kernel OOM killer fired. Not a
GPU hang. Full writeup in `freeze-diagnosis.md`.

Applied and confirmed surviving the 2026-08-31 reboot:

| Thing | State |
|---|---|
| `earlyoom` + tuned `system/default/earlyoom` | active |
| `system/sysctl.d/99-memory-pressure.conf` | 125 / 100 / 0 |
| 16 GB btrfs swapfile, `system/setup-swapfile.sh` | `/swap/swapfile` prio 10, from fstab |
| zram, `system/systemd/zram-generator.conf` | prio 100 |
| `/etc/fstab.bak-swapfile` | fallback, still present |

Nothing outstanding here.

## 2. Browser / memory footprint  — resolved by user action

Zen went 269 tabs -> 9. Userspace demand dropped 36.9 GB -> 21.8 GB; available
RAM 3.4 GB -> 12 GB. **Claude Code is now the largest consumer** (~9.9 GB across
~20 sessions), not the browser.

Still true and worth remembering:
- `/tmp` is tmpfs, so files there cost RAM *and* vanish on reboot. It held 2.1 GB
  of `claude-*` scratchpads. This is how `/tmp/herdr-setup-notes.md` was lost.
- earlyoom fires only when **both** mem <=10% and swap <=20% free. The swap
  condition is usually what protects you.

## 3. Monitors  — mostly done, two items left

`sway/config` now identifies displays two different ways, deliberately:

- **Samsung S32B80P pair** -> EDID (`"make model serial"`), unique serials, so
  settings follow the panel across dock ports.
- **ASUS MQ149CD pair** -> connector names `DP-5`/`DP-6`. Both panels report the
  **same** serial `T5LMCD002864` because it is one physical device with two
  screens. EDID keying is impossible; one rule would match both and stack them.
- `eDP-1` -> connector name; the internal panel never changes.

Ordering is load-bearing: connector rules first, EDID rules after, so an EDID
rule wins if a Samsung ever lands on DP-5/DP-6.

**Outstanding:**
1. **Delete the forced HDMI resolution.** `output HDMI-A-1 resolution 3440x1440
   pos 0 0` is keyed on the *port*, so any meeting-room projector on HDMI gets
   forced to 3440x1440 and fails. Agreed to remove; not done yet.
2. **Capture the ultrawide's EDID** while it is connected, then key it by EDID
   instead of `HDMI-A-1`. It has never been connected during a survey.

**Decided against:** `kanshi` and `nwg-displays`. Sway already applies output
rules on hotplug, and nwg-displays cannot express mixed keying or the
`workspace N output <primary> <fallback>` lists. Kanshi's only real advantage is
set-based matching (rules that fire only when a specific combination is
present); the user accepted the residual risk by agreeing to use Type-C port 1
for unknown displays. Revisit only if that changes.

**Installed instead:** `wdisplays` — live GUI, physically cannot write config,
so zero conflict. Bound to `d` in sway's options mode and added to
`scripts/options-menu.sh`. Float rule matches both plausible app_ids.

Sway defaults for an unconfigured display, verified on this hardware: scale 1
(sway does NOT auto-scale HiDPI), preferred mode from EDID, auto-placed to the
right.

## 4. Sway logging  — DONE, see section 10

Superseded: the wrapper existed from 2026-08-27 but was not actually being used
until greetd started launching it on 2026-09-11. Full detail in section 10.

One caveat that still stands: the journal sits at its 4 GB default cap, so sway
logs shorten retention for everything else. Raising `SystemMaxUse` was offered
and declined.

## 5. Claude approval notifications  — works, untracked

Built 2026-07-17, four files, still **untracked**: `scripts/claude-approval-notify.sh`,
`scripts/claude-approval.env.example`, `docs/claude-phone-approvals.md`,
`system/ntfy-server.example.yml`.

Live via a `PermissionRequest` hook at `~/.claude/settings.json:121`. Currently
**local mode** (swaync buttons) because `~/.config/claude-approval.env` does not
exist; the ntfy/phone path is dormant. Fails open.

The session that built it is unrecoverable — transcript retention only reaches
back to 2026-08-04. The doc is what survived.

**Outstanding:** not referenced by `install-sway-arch.sh`, so it would vanish on
a fresh machine.

## 6. AirPods Max mic quality  — diagnosed, fix not started

Colleagues complain about mic quality in meetings. **Not a misconfiguration.**
Measured live: capturing the mic switches the profile `a2dp-sink` ->
`headset-head-unit` and negotiates `lc3_a127` at **24 kHz mono**, which is the
best of the three available profiles (CVSD 8 kHz, mSBC 16 kHz, LC3 24 kHz). No
WirePlumber config exists and none is needed.

The iPhone gap is Apple-side integration: a proprietary 48 kHz headset path plus
on-device beamforming and noise suppression that standard HFP cannot reach.
Android would likely be **worse** — most phones land on mSBC.

Real causes: no noise suppression or AGC anywhere in the chain, and a very low
captured level (20 s gave peak 0.022, RMS 0.0003).

**Plan, in order:**
1. A/B the Alder Lake internal mic array against the AirPods mic. Using the
   laptop mic also keeps playback on A2DP AAC instead of collapsing to 24 kHz
   mono during calls. Free, and may end the problem.
2. `easyeffects` (extra/8.2.7) for RNNoise **and** WebRTC AGC. Chosen over a
   PipeWire filter-chain because EasyEffects uses `pw_filter`, so it is immune to
   the plugin-format change introduced in **PipeWire 1.6.3** — this machine runs
   **1.6.7**, so most online RNNoise guides (all 2024-era) will fail.
3. Only then convert a working setup into a persistent filter-chain in the repo.

**Next action:** user was about to `sudo pacman -S --needed easyeffects`. Once
installed: enable RNNoise on the Input side via the GUI, then capture the
generated JSON from `~/.config/easyeffects/input/` into the repo rather than
hand-writing a preset (the schema changes across major versions). Verify the
browser is actually using the processed virtual source, or the test will look
like a no-op.

## 7. Uncommitted  — still nothing committed, as of 2026-09-11

Last commit is `70ef930 mimeapps`. Everything below predates or postdates it and
is unstaged. This now covers the whole memory/OOM fix, the monitor EDID keying,
the .NET toolchain, the nvim treesitter migration and the greetd login stack.

Modified (11):
  - `.zshrc-lnx`
  - `install-sway-arch.sh`
  - `mako/config`
  - `mimeapps/mimeapps.list`
  - `nvim/init.lua`
  - `nvim/lazy-lock.json`
  - `nvim/lua/lazy/dap.lua`
  - `nvim/lua/lazy/lsp.lua`
  - `scripts/options-menu.sh`
  - `sway/config`
  - `zed/settings.json`

Untracked (16):
  - `docs/claude-phone-approvals.md`
  - `docs/freeze-diagnosis.md`
  - `docs/herdr-setup.md`
  - `docs/monitor-inventory.tsv`
  - `docs/open-threads.md`
  - `herdr/`
  - `nvim/lua/lazy/roslyn.lua`
  - `scripts/audio-output-menu.sh`
  - `scripts/claude-approval-notify.sh`
  - `scripts/claude-approval.env.example`
  - `scripts/start-sway.sh`
  - `sway/test.txt`
  - `swaync/`
  - `system/`
  - `systemd-sway-arch/user/visual-plan.service`
  - `zen/`

`sway/test.txt` is probably junk and worth deleting rather than committing.

## 8. Herdr — agent handles do not survive a reboot

The three agents listed here previously (`w1:t1` desktop, `w1:t2` herdr-tasks,
`w1:t3` notify) are gone; the 2026-09-11 reboot ended them. Herdr restores
layout, tabs, panes and cwd from `~/.config/herdr/session.json`, but **not
running processes** - see `herdr-setup.md`. Workspace `w1` is labelled
**system**.

Quirks worth keeping, all confirmed in practice:
- `agent_status: blocked` can be a **false positive** at an idle prompt. Check
  `interactive_ready`; when the block is real the CLI genuinely refuses to write.
- `agent read --source recent` is refused with `agent_not_idle` while an agent is
  working - use `--source visible`.
- The default viewport truncates; `--source recent --lines 160` gets full output.
- Control commands need `HERDR_ENV=1`, i.e. running inside a Herdr pane. That is
  environment-dependent and changed mid-session once already.

## 9. Stuck I-beam cursor — SOLVED 2026-09-11, cause worth remembering

**Symptom:** mouse cursor stuck as an I-beam across every app and workspace.

**Cause:** a stuck/phantom touch contact on the touchscreen
(`ELAN901C:00 04F3:2EA4`, 10-point capacitive, `event8`). The held contact kept
an input grab open compositor-wide, so the cursor shape never got re-evaluated
no matter which client had focus.

**Fix:** *touch the touchscreen.* A fresh touch completes the sequence and
clears the stale grab.

**Why the obvious fix does not work:** `swaymsg seat seat0 cursor release
button1` synthesises a *pointer button* event. A touch grab is a separate input
class, so pointer-button releases cannot clear it. All three button releases
reported `success: true` and changed nothing.

**Ruled out along the way** (so nobody re-checks these):
- Not a client bug - reproduced with Alacritty and Zen focused, both native
  `xdg_shell`, and there are zero Xwayland windows.
- Not the cursor theme - `adwaita-cursors 50.0-1` is installed and
  `/usr/share/icons/Adwaita/cursors` is fully populated. `/usr/share/icons/default/`
  holding only `index.theme` with `Inherits=Adwaita` is normal and resolves fine.
- Not a leftover overlay - no `hyprpicker`/`slurp`/`rofi`/`wl-mirror` running.
  (`fullscreen_mode` on nodes in `get_tree` is set on *workspaces*, so it is not
  a useful signal for finding fullscreen windows.)

**Diagnosis route for next time:** the user is in the `input` group, so
`libinput debug-events` works unprivileged. Filter out the noise:

    timeout 8 libinput debug-events | grep -vE "POINTER_MOTION|DEVICE_ADDED|POINTER_AXIS"

Look for a TOUCH_DOWN or BUTTON_PRESS with no matching release.

**If it recurs often,** the touchscreen can be disabled:

    swaymsg input 1267:11940:ELAN901C:00_04F3:2EA4 events disabled

## 10. Sway logging — DONE 2026-09-11, verified

`journalctl -t sway -b` now has content (447 entries on first verified login).
The chain is: greetd -> `/etc/greetd/sessions/sway-logged.desktop` ->
`/usr/local/bin/start-sway` -> `systemd-cat --identifier=sway`.

Confirm it is actually going through the wrapper by checking the cmdline: the
wrapper passes `--verbose`, so `sway --verbose` means logging is on, while a
bare `sway` means the stock session entry was used.

    journalctl -t sway -b            # this boot
    journalctl -t sway -b -1         # previous boot
    journalctl -t sway -g output     # monitor connect/disconnect

That last one is what was missing when the ASUS/Samsung EDID inventory had to be
captured live (section 3) and when the stuck-cursor incident (section 9) had no
trace to read.

sway itself has NO config directive for logging - verbosity is a CLI flag only
(`sway --help`), and sway writes everything to stderr. So the wrapper is the only
place it can be enabled. See `scripts/start-sway.sh`; `SWAY_LOG_LEVEL=debug|quiet`
overrides the default `verbose`.

## 11. Login screen: greetd + cage + alacritty + tuigreet — DONE 2026-09-11

Working. `greetd` enabled and active, `NRestarts=0`, session on tty1.

### Why not ly (which was the first attempt)

The "ldm" originally remembered is **`ly`**, and it was already installed
(`ly 1.4.1-1`, with a `/etc/ly/save.ini` dated 2026-01-30). `ldm` is not a
display manager and is not in the repos at all.

ly is the only greeter found with real vi keybindings (`vi_mode = true`), and it
was configured and working - but it is **stuck on the Linux VT, which is an
8-colour terminal**:

    tput -T linux colors  ->  8
    tput -T alacritty colors -> 256

That is measured, not assumed. Kanagawa hex values get crushed to the nearest
ANSI slot, which is why three attempts at tuning `colormix_col1/2/3` all came out
grey or washed out. No palette choice can fix it. Three rounds were spent tuning
hex before checking terminal capability - check capability first next time.

Also learned while debugging that: ly's `colormix` is NOT a pixel shader. From
`src/animations/ColorMix.zig`, it builds a 12-entry palette of the three colours
taken as PAIRS, each drawn with block glyphs `0x2588/2593/2592/2591`. The full
block renders a colour at FULL strength over large areas, so the **brightest** of
the three dominates the whole screen regardless of the other two.

kmscon would have given ly truecolor, but it is poorly maintained and forces
`--font-engine unifont`, so it was rejected.

### The stack that replaced it

    greetd -> cage -s -- alacritty --config-file /etc/greetd/alacritty.toml \
                -e tuigreet

Running the TUI inside a real Wayland terminal inside a minimal compositor gives
truecolor **and** proper font rendering (`SFMono Nerd Font`). All four packages
are in `extra` and actively maintained; Arch's `greetd-tuigreet` tracks
`github.com/tuigreet/tuigreet`, the Ratatui rewrite.

Trade-off accepted: **tuigreet has no vi keybindings**, only configurable F-keys.
On a username/password form there is little to navigate, so correct colours plus
a maintained project won out.

Repo files:
- `system/greetd/config.toml`      -> `/etc/greetd/config.toml`
- `system/greetd/alacritty.toml`   -> `/etc/greetd/alacritty.toml`
- `system/greetd/sessions/sway-logged.desktop` -> `/etc/greetd/sessions/`
- `system/tuigreet/config.toml`    -> `/etc/tuigreet/config.toml`
- `system/wayland-sessions/sway-logged.desktop` -> `/usr/share/wayland-sessions/`

### Two bugs that cost a session — do not repeat

**1. `--cmd start-sway` can never resolve.** greetd launches sessions with a
minimal environment that does not include `~/.local/bin`, which is only on PATH
via `.zshrc-lnx`. Fixed by installing the wrapper system-wide to
`/usr/local/bin/start-sway` and dropping `--cmd` in favour of a session entry
with an absolute `Exec=`.

**2. `vt = 2` killed a running sway session.** The packaged `greetd.service`
declares `Conflicts=getty@tty1.service`, so it is built for tty1. Setting
`vt = 2` meant starting greetd tore down the tty1 getty for no reason - and
because `getty@tty1` has `TTYVHangup=yes`, that SIGHUPs anything whose
*controlling terminal* is tty1. sway died. A cgroup check said the session was
safe and was not wrong, but cgroups cannot see the controlling-terminal/SIGHUP
path. **Config is now `vt = 1`, aligned with the unit.** Escape hatches are
tty2-6.

Lesson: do not test a display manager from inside the session it will contend
with. Test from a text TTY, or reboot.

### Making the logged session the default

Two mechanisms, both in place:

1. `[session] sessions_dirs = ["/etc/greetd/sessions"]` in the tuigreet config.
   That directory holds ONLY `sway-logged.desktop`, so the single offered session
   always logs. Deliberately not `/usr/share/wayland-sessions`, which also holds
   the stock `sway.desktop` - having both listed meant one careless F3 pick
   silently lost logging, which is exactly what happened on the first login.
2. `--remember-user-session` persists the choice in
   `/var/cache/tuigreet/lastsession-path-<user>`. That cache dir **must exist and
   be owned by `greeter`** or every `--remember*` feature silently fails. The
   install script creates it and pre-seeds the correct path.

`--asterisks` no longer exists; it is deprecated in favour of
`[secret] mode = "characters"`.

### Animations

Two ship with tuigreet: `doom` (aliases `fire`) and `matrix` (aliases `cmatrix`).
Currently `doom` with Kanagawa colours (`autumnRed` -> `autumnYellow` ->
`sumiInk1`, so the flames fade into the background). `F4` switches live without a
restart.

They ARE extensible, but only in Rust at compile time - there is no runtime
plugin loading. `crates/tuigreet/src/ui/bg_animation/mod.rs` has a three-method
`Animation` trait plus a `KINDS` registry that drives the F4 menu, with `doom.rs`
and `matrix.rs` as siblings. Porting ly's colormix would be a small PR. PINNED.

### Fallback

ly is deliberately left installed with its config still deployed:

    sudo systemctl disable greetd && sudo systemctl enable ly@tty2

Only one display manager may own a VT, hence the explicit `disable ly@tty2` in
the install script.

## 12. Lock screen — swaylock works, idle locking PINNED

Already on **swaylock** (`sway/config:271`), not i3lock - i3lock is X11 and would
not work on sway at all. It has a Kanagawa theme in `swaylock/config`.

greetd cannot do this: it is a login daemon, and locking uses the separate
`ext-session-lock-v1` protocol.

**Outstanding:** nothing locks on idle. `swayidle` is not installed and the
auto-lock lines at `sway/config:60-62` are commented out. Deferred 2026-09-11.

More capable lockers if wanted: `gtklock` (GTK/CSS-themeable), `hyprlock` (most
visually capable, uses `ext-session-lock-v1` so should work on sway),
`waylock` (more minimal than swaylock).

## 13. install-sway-arch.sh — guard rewritten 2026-09-11

`remove_non_dirlink` was replaced with `link_path <src> <dest>`, which prompts
only when real content would actually be lost. It stays silent when dest is
already correct, is a symlink pointing elsewhere, is an empty dir, or is a dir
whose every entry is a symlink resolving inside src - that last case is what
`~/.config/rofi` was, and it now converts without prompting.

It also fixed a latent bug: the old call sites did `ln -sfn $DIR/x $HOME/.config`,
linking *into* a directory, which created a nested junk symlink
(`~/.config/rofi/rofi`) whenever a declined prompt left the target dir in place.
All 13 sites now pass an explicit destination.

Uses `find` rather than a glob so it needs neither `shopt -s nullglob` (bash-only)
nor `(N)` (zsh-only); 34 tests pass under both shells, covering false positives,
false negatives, mixed dirs, nested subdirs, filenames with spaces and newlines,
and unreadable entries.

The script is idempotent: all 13 `link_path` targets no-op on a second run, the
swapfile script greps before appending to fstab, package installs are guarded by
`pacman -Qq`, and the yazi `git clone` is swallowed by `|| true`. Two operations
do repeat harmlessly: `systemctl restart systemd-journald` and
`restart earlyoom` (the latter briefly gaps OOM protection).

## 14. Flashing monitor on the small HDMI dock — SOLVED 2026-09-25

**Symptom:** the Samsung LS24DG30X (1920x1080, on the small HDMI dock, enumerates
as `DP-1`) flashes intermittently.

**Cause:** it was running at **180Hz**, which that dock cannot carry. 1080p@180
needs roughly a 370-400MHz pixel clock - inside HDMI 2.0's 594MHz but well past
HDMI 1.4's 340MHz. The monitor's EDID advertises 180 and the adapter passes that
claim through unchanged, so sway picks the highest mode offered and the link then
fails to sustain it.

**Fix:** pin 120Hz. In `sway/config`:

    output $mon_hdmi mode 1920x1080@120Hz pos 1520 1440

Advertised rates are 180, 120, 119.9, 60, 59.9, 50. If 120 ever proves marginal,
60 is comfortably inside HDMI 1.4.

**Why this was hard to find:** nothing logs it. sway presents frames normally and
the kernel reports no link-training or DRM errors, because the fault is in the
physical link, below both. The only evidence is visual.

**MISDIAGNOSIS WORTH REMEMBERING.** This was first blamed on the page-flip
failures in section 15, because those were dramatic and concurrent. They are on
different displays entirely:

    eDP-1   1803 failures     laptop panel
    DP-4     283              Samsung 4K, CalDigit dock
    DP-3     131              Samsung 4K, CalDigit dock
    DP-1       4              <- the display that was actually flashing

Four failures. The flashing display was almost perfectly clean in the log the
whole time. A dramatic signal that correlates in time is not necessarily the
signal for the symptom being reported - check that the evidence names the thing
being complained about before building on it.

## 15. Page-flip failures on eDP-1 and the CalDigit Samsungs — UNRESOLVED

Separate from section 14 and still unexplained. sway logs a continuous stream of:

    connector DP-4: Atomic commit failed: Device or resource busy
    Page-flip failed on output DP-4

Affects the laptop panel and the two 4K Samsungs behind the CalDigit TS3 Plus.
Bursty; hourly counts have ranged 4 to 942. Bursts begin within a second of the
dock being attached (kernel logs its card reader enumerating at the same moment).

**No known user-visible symptom.** It was assumed to be the cause of the flashing
in section 14 and was not.

**Ruled out:**
- Not the GPU - the kernel logs zero i915 errors, only normal resume reinit.
- Not accumulated compositor state - reproduces on fresh sway sessions.
- Not suspend/resume - one instance began 22 seconds into a session.
- Not the 180Hz monitor's bandwidth, and not fractional scaling: three 90s
  windows (baseline 7, DP-1 disabled 38, integer scale 2 = 73) showed no
  improvement from either. Those samples are too few and too noisy to prove
  anything beyond the absence of a large effect - each change also forces a
  modeset, which bursts.

**Untested:** whether moving a Samsung off the CalDigit to a direct port changes
anything. The kernel flagged a device at half its possible PCIe width at boot
(7.876 Gb/s on an x1 link, capable of x2).

Check the current rate with:

    journalctl -t sway --since "-5min" | grep -c "Page-flip failed"

## 16. Fedora port — DONE 2026-10-06, validated in a container

Goal: reproduce this sway setup on Fedora, so a second machine is not locked
to Arch. Full write-up in `docs/fedora-port.md`; this is the short version.

**What was added**

* `scripts/bootstrap-fedora.sh` — ten phases: repos, dnf, copr, flatpak,
  dotnet, go, npm, cargo, bin, shell. Same `--desktop`/`--laptop`/`--dry-run`/
  `--only` contract as the Arch one.
* `scripts/test-bootstrap-fedora.sh` — twelve checks, container-based.
* `packages/fedora.txt` (126), `fedora-laptop-only.txt` (7),
  `fedora-review.txt`, `fedora-copr.txt` (4 projects).
* `install-sway-arch.sh` now runs on both distros via a `pkg_need` /
  `pkg_installed` shim. **The Arch branch emits byte-identical commands**, so
  running it on this laptop is unchanged.

**Four things the testing caught that guesswork would not have**

1. `packages.microsoft.com/fedora/<ver>/prod` is a *decoy*. It exists, it
   returns a valid `repomd.xml` for every Fedora release, and it contains
   neither powershell nor edge — only mdatp/procmon/sysinternals. PowerShell
   is in `rhel/9/prod`, Edge in `yumrepos/edge`, VS Code in `yumrepos/vscode`.
   Three separate Microsoft repos.
2. **ngrok has no RPM repository at all.** Its S3 bucket holds `dists/` and
   `pool/` — Debian only. Installed from the tarball in the `bin` phase.
3. Diffing `official.txt` against `fedora.txt` found ~20 packages I had simply
   missed, including things `scripts/options-menu.sh` calls directly
   (`wdisplays`, `rofimoji`, `cliphist`, `wf-recorder`, `hyprpicker`,
   `pulsemixer`, `yazi`). Mapping the obvious packages was not the same as
   reproducing the desktop.
4. `vim` → `vim-enhanced` was applied with a substring replace that hit the
   `vim` inside `neovim`, silently producing `neovim-enhanced`. Only the
   container re-run caught it. Line-exact matching when editing package lists.
5. `dnf list <pkg>` glob-matches and ignores case, so it happily "resolved"
   `imagemagick` against the real package `ImageMagick` — a name `dnf install`
   would have rejected. Switching the test to one exact
   `dnf repoquery --qf '%{name}\n'` over all names caught it, and cut test 1
   from 126 dnf invocations to one.
6. `dnf --version | head -1 | grep` under `set -o pipefail` is a race: `head`
   closes the pipe, dnf dies on SIGPIPE, the pipeline "fails", and the script
   silently decided it was on dnf4 — which would have used the wrong
   `config-manager` syntax on a real Fedora 41+ box. The same container
   reported 5 on one run and 4 on the next. Test 13 now asserts stability
   over 8 runs.

**Two Fedora facts that were expected to break and did not:** earlyoom really
does read `/etc/default/earlyoom` on Fedora (not `/etc/sysconfig`), and
zram-generator uses the same `/etc/systemd/zram-generator.conf` path.

**Known gaps, documented not fixed:** `terraform` is `opentofu`; and
`ueberzugpp`,
`swayosd`, `recordmydesktop`, `networkmanager-dmenu`, `hyprpicker`, `nvm`,
herdr and the hand-dropped binaries have no Fedora packaging.

**Corrected after the first write-up:** I claimed rofi would run under
Xwayland on Fedora because there is no `rofi-wayland` package. Wrong, and I
asserted it without checking the binary. rofi 2.0 merged the lbonn Wayland
fork upstream; Fedora's changelog reads "Enable Wayland backend and replace
rofi-wayland", and `rofi -help` lists a wayland backend. Arch did the same --
`rofi-wayland` there is now `rofi 2.0.0-1` via provides. Both distros run the
same upstream release, and both `.rasi` files parse against Fedora's build.

**Not done:** nothing has been run on real Fedora hardware. Container testing
covers package resolution and script logic; greetd, sway and the GPU path need
a VM or a real install.
