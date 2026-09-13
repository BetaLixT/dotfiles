# The `wave` animation — building and keeping it updated

tuigreet has **no runtime plugin mechanism**. Animations are Rust, registered at
compile time in `crates/tuigreet/src/ui/bg_animation/mod.rs`. A custom animation
therefore means building the greeter from source. This file is the operating
manual for that.

Background on the greeter stack itself is in `tuigreet-customization.md`; this
doc only covers the custom build.

---

## 1. What is where

| Repo file | Role |
|---|---|
| `system/tuigreet/src/wave.rs` | the animation itself — the only real code |
| `system/tuigreet/src/register.patch` | the 4 registration edits (see §4) |
| `system/tuigreet/build.sh` | clone → pin → patch → build → verify → install |
| `scripts/tuigreet-custom.sh` | wrapper installed to `/usr/local/bin/tuigreet-custom` |
| `scripts/wave-preview.py` | tune the look without a Rust toolchain |

Installed to:

    /usr/local/lib/tuigreet/tuigreet    the custom binary
    /usr/local/lib/tuigreet/.stamp      pin + hash of the inputs that built it
    /usr/local/bin/tuigreet-custom      the wrapper greetd actually runs

`/usr/local` is used because **pacman never touches it** — a `-Syu` cannot
overwrite the custom build. The packaged `/usr/bin/tuigreet` is deliberately left
installed as the fallback.

It is `/usr/local/lib`, not `/usr/local/bin`, on purpose: a binary named
`tuigreet` on `PATH` would shadow the packaged one and the wrapper would re-exec
itself instead of falling back.

## 2. Nothing here can cost you a login

Three independent layers, each verified:

1. **The config degrades.** Stock tuigreet given `kind = "wave"` renders the
   login form normally and simply draws no animation — no error, no panic.
   Verified by running the stock binary under `--mock` with that config.
2. **The wrapper falls back.** `tuigreet-custom` execs the custom binary only if
   it is executable, otherwise `/usr/bin/tuigreet`. A machine that never built it
   gets a working greeter.
3. **The build verifies before installing.** `build.sh` smoke-tests the compiled
   binary (`--version`, and that it still advertises `--background`) and refuses
   to install one that fails.

The escape hatches from `tuigreet-customization.md` §6 all still apply: text
logins on tty2–6, and `ly` still installed.

## 3. Routine use

    system/tuigreet/build.sh --check    # what is installed, is it current
    system/tuigreet/build.sh            # build + install if out of date
    system/tuigreet/build.sh --force    # rebuild regardless

`--check` never builds and never needs sudo. Use it first, always.

`build.sh` is a no-op when the stamp matches, which is what makes it safe to call
from `install-sway-arch.sh` on every run — otherwise each install would sit
through a multi-minute Rust build.

Preview without touching the greeter:

    /usr/local/lib/tuigreet/tuigreet --mock --config /etc/tuigreet/config.toml

`--mock` skips the greetd socket and fakes auth locally, so this is safe from
inside a running session. **Do not** restart greetd to test — see
`tuigreet-customization.md` §6, that already killed a session once.

## 4. What the patch actually does

`wave.rs` is a whole new file, so it can never conflict. Everything else is four
small registrations, which is all `register.patch` contains:

| File | Edit |
|---|---|
| `bg_animation/mod.rs` | `pub mod wave;`, `Kind::Wave`, a `KINDS` entry (this drives the F4 menu), a `from_name` arm, `AnimationSpec::Wave`, a `build()` arm, a `default_spec()` arm |
| `tuigreet-config/src/schema.rs` | `WaveConfig` struct + `wave` field on `BackgroundConfig` |
| `tuigreet/src/greeter.rs` | a `Kind::Wave` arm mapping config → `wave::Options` |

Additive only — no upstream line is modified, one is only extended. That is why
the patch is likely to survive upstream churn.

## 5. Keeping it updated

The pin is the whole story. `build.sh` has one line that matters:

    PIN="0.11.1"

The custom build stays on that tag until you change it. This is deliberate:
an unpinned build tracking `master` would break at an unpredictable moment, and
you would discover it at a login screen.

**The cost:** when `greetd-tuigreet` updates, your greeter does not. `build.sh`
detects this and says so on every run:

    build.sh: packaged greetd-tuigreet is 0.12.0 but the custom build is pinned to 0.11.1.
    build.sh:   To pick up upstream changes: bump PIN in build.sh, re-run, test with --mock.

### Bumping to a new upstream release

1. Bump `PIN` in `system/tuigreet/build.sh`.
2. `system/tuigreet/build.sh --force`
3. If the patch still applies, it builds and you are done. Test with `--mock`.
4. If it does **not** apply, build.sh stops with:

       register.patch does not apply to tuigreet <tag>.

   Nothing is installed and the old binary stays in place, so the greeter keeps
   working while you sort it out. Re-create the patch as below.

### Re-creating the patch

    cd /tmp
    git clone --depth 1 --branch <new-tag> https://github.com/tuigreet/tuigreet.git t
    cd t
    git apply ~/dotfiles/system/tuigreet/src/register.patch   # see how far it gets

Re-apply the four edits from §4 by hand where it failed, then:

    cp ~/dotfiles/system/tuigreet/src/wave.rs crates/tuigreet/src/ui/bg_animation/wave.rs
    git diff > ~/dotfiles/system/tuigreet/src/register.patch   # wave.rs is untracked, so it is excluded

Confirm before committing to it:

    git -C <pristine clone> apply --check ~/dotfiles/system/tuigreet/src/register.patch

Changing `wave.rs` or `register.patch` changes the stamp hash, so the next
`build.sh` rebuilds automatically. No manual cache clearing.

### On a fresh machine

`install-sway-arch.sh` handles it: installs `rust`, runs `build.sh`, and if
anything fails prints a warning and moves on — the wrapper falls back to the
packaged greeter. To skip the toolchain entirely on a minimal box:

    SKIP_TUIGREET_BUILD=1 ./install-sway-arch.sh

### Abandoning the custom build

    sudo rm -rf /usr/local/lib/tuigreet

The wrapper falls back to the packaged tuigreet on the next greeter start. Set
`kind` back to `doom` or `matrix` in `system/tuigreet/config.toml` and redeploy,
though leaving it as `wave` is harmless (§2, layer 1).

## 6. The animation

Config lives in `system/tuigreet/config.toml` under `[background.wave]`; every
key is optional and falls back to the tuned default in `wave.rs`.

    [background]
    kind = "wave"           # aliases: "wave", "water"

    [background.wave]
    crest_color = "#A3D4D5" # lightBlue   - the waterline
    upper_color = "#7E9CD8" # crystalBlue
    mid_color   = "#6A9589" # waveAqua1
    deep_color  = "#2D4F67" # waveBlue2
    abyss_color = "#223249" # waveBlue1   - fades into the container
    foam_color  = "#DCD7BA" # fujiWhite   - foam on steep crests
    level       = 0.62      # waterline, fraction of screen height
    amplitude   = 1.0       # swell height multiplier
    speed       = 1.0       # scroll speed multiplier
    warp        = 0.55      # texture strength; 0.0 = flat depth bands
    foam_slope  = 0.55      # gradient needed for foam; higher = less foam

### Provenance

The domain-warp field and the `░▒▓█` shading are **ported from ly's
`src/animations/ColorMix.zig`** (fairyglade/ly, **WTFPL** — maximally permissive,
so the port carries no copyleft obligation into tuigreet's GPL-3.0-only tree).

This follows existing practice rather than departing from it: upstream's
`doom.rs` opens *"DOOM-style fire effect, ported from Ly's
`src/animations/Doom.zig`"*. (`matrix.rs` is **not** an ly port — it is
cmatrix-style rain written independently, and mentions ly nowhere.)

Neither half of `wave` is novel, and it is not meant to be. The iterated
domain-warp idiom — `uv += 0.5 * vec2(cos(…), sin(…))`, then index by
`length(uv)` — is a long-standing shader-demo plasma pattern; ly's ColorMix is
one implementation of it, and the specific constants here came from ly's.
Summing sinusoids for a water surface is likewise the standard approach.
What is local is the *combination*: see below.

ly's original is an isotropic plasma: warp a UV coordinate three times, then
index a 12-entry palette (4 glyphs × 3 colour *pairs*) by
`floor(length(uv) * 5.0) % 12`.

`wave` keeps that warp verbatim but uses it differently. A real water surface is
computed from three superimposed sine components (one running against the other
two, so the surface has no short repeat period); cells below it are coloured by
**depth** through the Kanagawa blue ramp; and the warp only picks the shading
glyph. The ramp gives depth, the warp gives visible current, and foam on steep
crests keeps the surface from reading as a plotted sine.

### Tuning without a toolchain

    python3 scripts/wave-preview.py                  # the wave
    python3 scripts/wave-preview.py --mode colormix  # ly's original mapping

Pure stdlib, installs nothing. The constants at the top of the preview map
one-to-one onto `Options` in `wave.rs`, so tuning there is the design step —
change the preview until it looks right, then mirror the numbers into `wave.rs`
(or into `[background.wave]`, for anything exposed as config).

## 7. Upstream bug found while building this

`head_color` in `[background.matrix]` is **silently ignored** in 0.11.1. Not a
config problem — the plumbing is correct. It is an ordering bug in
`matrix.rs::step()`: new heads are stamped with `age: 1`, then the aging loop in
the *same* call increments every painted cell, so `age == 1` never survives to
`render()`, where the head colour is selected. The head branch is unreachable.

Demonstrated by setting all three matrix colours to loud values:

    head   #FF00FF magenta ->     0 cells rendered
    bright #FFA500 orange  ->  6197
    dim    #00FF00 green   ->  6622

Worth reporting upstream. `wave` does not depend on it.
