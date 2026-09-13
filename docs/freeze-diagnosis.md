# System Freeze Diagnosis & Monitoring Setup

## System Info

- **Machine**: Lenovo laptop (Alder Lake-P)
- **GPU**: Intel Iris Xe Graphics (i915 driver)
- **Kernel**: 6.19.9-arch1-1
- **Compositor**: sway 1.11 (stock, not swayfx)
- **RAM**: 32GB + 4GB zram swap
- **Browser**: Zen Browser 1.19.3b (Firefox-based)

## Freeze Symptoms (2026-03-30)

- Screen frozen on last frame
- TTY switching (Ctrl+Alt+F2) did not work
- SSH not available (sshd was disabled)
- Had to hard power-off

## What the Logs Show

### Previous boot journal (`journalctl -b -1`)
- Journal ends abruptly at ~17:22 on Mar 30 with rslsync spam
- **No OOM killer triggered**
- **No GPU error logged**
- **No segfault, watchdog, or lockup message**
- System just stopped writing logs — consistent with a hard lockup

### Previous boot errors (`journalctl -b -1 -p err..alert`)
- CPU topology firmware bugs (cosmetic, Alder Lake known issue)
- `xhci_hcd` PCI post-resume error -19 (USB controller via dock)
- `igb enp85s0: PCIe link lost` (Thunderbolt NIC disconnected)
- `magicmouse: unable to request touch data` (Bluetooth device)
- USB audio freq errors (USB DAC/headset)
- **No i915/GPU errors logged**

### Coredumps
- `slurp` segfaulted on Mar 25 (screenshot tool)
- `pipewire` segfaulted on Mar 13
- No compositor or browser coredumps

## Diagnosis

### Most likely cause: **i915 GPU hang**

Evidence:
1. **Silent hard lockup** — no error in journal before it stops. i915 GPU hangs are notorious for freezing the entire system (including disk I/O) with no log entry because the GPU hang blocks everything before the kernel can write to the journal.
2. **TTY switching failed** — rules out a simple compositor crash. Points to kernel/GPU level issue.
3. **Intel Alder Lake + kernel 6.19** — i915 driver bugs on Alder Lake are well-documented, particularly with multi-monitor setups.
4. **Multi-monitor setup** — config shows HDMI-A-1 (3440x1440), eDP-1, DP-3, DP-4 (scaled 1.5x). The boot log shows `[ENCODER:510:DDI B/PHY B] unusable PPS, disabling eDP` which means display port initialization issues.
5. **Browser GPU acceleration** — Zen (Firefox-based) uses WebRender with GPU acceleration on Wayland. Heavy GPU workloads from the browser can trigger i915 hangs.

### Less likely but possible
- **OOM** — 32GB RAM + 4GB zram makes this unlikely, but with many Zen tabs + containers it's possible. No earlyoom installed to catch it.
- **USB/Thunderbolt dock issues** — xhci and PCIe errors in boot log suggest dock instability. USB controller errors can cascade.

### Ruled out
- **Package mismatch** — sway 1.11 (stock) is running, wlroots0.19 matches. swayfx-debug is a leftover debug symbols package (harmless).
- **NVIDIA** — No NVIDIA GPU. linux-firmware-nvidia is just a dependency of linux-firmware.

## What Was Missing (Pre-Freeze)

| Protection | Status | Impact |
|---|---|---|
| Persistent journal | Partially working (dir exists, config commented out) | Logs survived but may be incomplete |
| SysRq | Value=16 (sync only) | Could not use REISUB for clean reboot |
| SSH | Installed but disabled | No remote diagnosis possible |
| earlyoom | Not installed | No OOM protection |

## Applied Status (verified 2026-08-10)

| # | Item | Status |
|---|---|---|
| 1 | Full SysRq (`kernel.sysrq=1`) | **Applied** — `/etc/sysctl.d/99-sysrq.conf`, live |
| 2 | Persistent journal | **Applied** — `/var/log/journal` exists, 5 boots retained |
| 3 | sshd enabled | **Applied** — enabled + active |
| 4 | earlyoom installed + enabled | **Applied** — enabled + active, tuned config |
| 5 | i915 kernel params | **Won't apply** — invalid/redundant on kernel 7.1, see below |
| 6 | GPU health monitoring | Informational only, nothing to install |
| 7 | Remove `swayfx-debug` | **Done** — package no longer present |
| — | Memory pressure sysctls | **Applied** — `99-memory-pressure.conf` |
| — | 16 GB btrfs disk swapfile | **Applied** — priority 10 behind zram's 100 |
| — | zram tier-1 swap | **Running, now tracked** — see gap note below |
| — | Zen `user.js` (disables GPU accel) | **Linked, pending Zen restart** — see caveat below |

### Gap found: zram was untracked

`/etc/systemd/zram-generator.conf` was a hand-written bare `[zram0]` stanza that
**no package owned** (`pacman -Qo` reports no owner) and that this repo did not
track. Every actual value — 4 GiB size, zstd compression, swap priority 100 —
came from an unstated default.

That made it the weakest link in the memory setup: a fresh machine running
`install-sway-arch.sh` would have got the 16 GB swapfile at priority 10 and **no
zram at all**, silently losing tier 1. earlyoom's `-s` thresholds are
percentages of total swap, so they would also have shifted meaning.

Now captured in `system/systemd/zram-generator.conf` with every value explicit,
and the install script installs the `zram-generator` package and deploys it.

### Caveat on the Zen `user.js`

`zen/user.js` disables hardware acceleration outright
(`layers.acceleration.disabled`, `gfx.webrender.software`,
`media.hardware-video-decoding.enabled=false`). It was written as a mitigation
for the *GPU-hang* theory. It is now linked into the profile but has not taken
effect — `prefs.js` still predates it, so it applies on the next Zen restart.

Reconsider before keeping it. Software WebRender and software video decoding
push work onto the CPU and **increase** memory use, which is the opposite of
what the confirmed 2026-08-10 failure mode needs. There is still no logged
evidence of a GPU hang on any boot. Unless the March 30 lockup recurs, removing
this file is probably the better trade.

## Monitoring & Prevention Setup

### 1. Enable full SysRq (allows REISUB recovery)

```bash
echo 'kernel.sysrq = 1' | sudo tee /etc/sysctl.d/99-sysrq.conf
sudo sysctl -w kernel.sysrq=1
```

When frozen, hold **Alt + SysRq (PrintScreen)** and slowly press: **R E I S U B**

### 2. Ensure persistent journal logging

```bash
sudo sed -i 's/^#\?Storage=.*/Storage=persistent/' /etc/systemd/journald.conf
sudo systemctl restart systemd-journald
```

### 3. Enable SSH for remote diagnosis

```bash
sudo systemctl enable --now sshd
```

Find your IP: `ip -4 addr show | grep inet`
From another device: `ssh dcruza@<IP>`

### 4. Install and enable earlyoom

```bash
sudo pacman -S earlyoom
sudo systemctl enable --now earlyoom
```

### 5. i915 GPU hang mitigation — NOT NEEDED, do not apply as written

The original advice here was `i915.enable_hangcheck=1 i915.reset=3`. Checked
against kernel 7.1.3 on 2026-08-10, both parts are wrong or redundant:

```console
$ modinfo -p i915 | grep -E '^(reset|enable_hangcheck):'
reset:Attempt GPU resets (0=disabled, 1=full gpu reset, 2=engine reset [default]) (uint)
enable_hangcheck:Periodically check GPU activity for detecting hangs. ... (default: true) (bool)
```

- `enable_hangcheck=1` is a **no-op** — it already defaults to true.
- `reset=3` is **not a valid value** in this kernel. Only 0, 1 and 2 are
  documented, and the default (2, engine reset) is already the most capable
  option. Passing 3 sets an undefined mode.

So there is nothing to add to the cmdline. Current `/proc/cmdline` carries no
i915 parameters, which is correct. Leave it that way unless a *confirmed* GPU
hang appears in the journal (`GPU HANG`, `drm ... reset`), which has not
happened on any boot so far.

To test if Zen browser GPU acceleration is the trigger:
1. Open Zen → Settings → search "hardware acceleration" → disable it
2. Use for a few days and see if freezes stop
3. If they stop, re-enable and try with `MOZ_DISABLE_WAYLAND_PROXY=1` in your env instead

### 6. Monitor GPU health

```bash
# Watch for i915 errors in real time
sudo journalctl -f -k | grep -i 'i915\|drm\|gpu'

# Check GPU frequency throttling
sudo cat /sys/kernel/debug/dri/0/i915_frequency_info
```

### 7. Clean up leftover packages

```bash
# swayfx-debug is an orphaned debug symbols package from old swayfx install
sudo pacman -Rns swayfx-debug
```

## Second Incident (2026-08-10) — Different Cause: Memory Exhaustion

This one was **not** a GPU hang, and it corrects an assumption made above.

### What happened

| Time | Event |
|---|---|
| ~08:10 | A Claude Code session starts in a tmux pane |
| 13:53:39 | pipewire starts erroring (`snd_pcm_avail after recover: Broken pipe`) — first sign of stalling |
| 13:53:46 | Kernel OOM-kills a Zen content process (`Isolated Web Co`, 1.7 GB) |
| 13:54:41 | Kernel OOM-kills the real offender: 11.5 GB anon RSS |
| ~13:55 | System recovers on its own — **no reboot needed** |

The offender was `comm=2.1.224`, i.e. Claude Code, which execs a version-named
binary at `~/.local/share/claude/versions/<ver>`. systemd's accounting:

```
tmux-spawn-01319161-...scope: Consumed 7min 42s CPU over 5h 44min wall clock,
11.6G memory peak, 163M memory swap peak.
```

Why the whole desktop stalled rather than just that process dying: zram was
completely exhausted (`Free swap = 236kB` of 4 GB) with only ~112 MB free in the
Normal zone. Everything was in direct reclaim, thrashing on compressed swap —
and zram decompression competes for the very CPUs needed to stay responsive.
Memory pressure confirmed it: `full avg300=3.38%`.

### Corrections to the March 30 analysis above

- **"OOM — 32GB RAM + 4GB zram makes this unlikely"** — disproven. 32 GB is no
  protection against a single process leaking to 11.6 GB, and 4 GB of zram is a
  cliff, not a cushion.
- **"earlyoom — Not installed"** — it was installed at some point after that
  writeup, but left **disabled and inactive**, so it never ran. The install
  script had `systemctl enable --now earlyoom` added but never executed.
- The two incidents are genuinely distinct: March 30 was a hard lockup (journal
  stopped abruptly, hard power-off required); Aug 10 logged everything and
  self-recovered. Don't assume a future freeze is i915 just because one was.

### Distinguishing the two on the next freeze

- **Journal ends abruptly, no OOM lines, hard power-off needed** → GPU/kernel lockup
- **`Out of memory: Killed process` present, machine recovers, uptime unbroken** → memory exhaustion

### Fixes applied

1. `system/default/earlyoom` — tuned thresholds (`-m 10,5 -s 20,8`),
   `--sort-by-rss`, `--prefer` for known ballooners, `--avoid` for session
   infrastructure. `--sort-by-rss` matters: Firefox/Zen sets
   `oom_score_adj=200` on content processes, so the default score-based
   selection killed a 1.7 GB browser tab as collateral while the actual 11.6 GB
   offender kept growing.
2. `system/sysctl.d/99-memory-pressure.conf` — `watermark_scale_factor=125` so
   reclaim starts with real runway instead of at the cliff edge.
3. `system/setup-swapfile.sh` — 16 GB btrfs swapfile at priority 10 behind zram
   (priority 100), giving earlyoom time to act before exhaustion.

## When the Next Freeze Happens

1. **Try SysRq REISUB** (Alt + SysRq + R E I S U B slowly)
2. **SSH in from another device**: `ssh dcruza@<IP>`
3. After reboot, collect:

```bash
journalctl -b -1 -p err..alert --no-pager
journalctl -b -1 | grep -Ei 'i915|drm|gpu|oom|hang|lockup|segfault|watchdog'
journalctl -b -1 | tail -100
dmesg -T | grep -Ei 'i915|drm|gpu|error'
coredumpctl list --reverse | head -10
```
