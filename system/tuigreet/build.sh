#!/bin/bash
#
# Build the locally-patched tuigreet (adds the `wave` background animation) and
# install it to /usr/local/lib/tuigreet/tuigreet.
#
# WHY A LOCAL BUILD AT ALL
#   tuigreet has no runtime plugin mechanism: animations are Rust, registered at
#   compile time in crates/tuigreet/src/ui/bg_animation/mod.rs. A custom
#   animation therefore means building the greeter. See ../../docs/tuigreet-wave.md.
#
# WHY /usr/local/lib AND NOT /usr/bin
#   pacman owns /usr/bin/tuigreet and would overwrite it on every update. Nothing
#   in the repos touches /usr/local, so the custom build survives -Syu. The
#   packaged binary is deliberately left in place as the fallback: greetd runs
#   /usr/local/bin/tuigreet-custom, which prefers this build and falls back to
#   /usr/bin/tuigreet when it is missing.
#
#   It is /usr/local/LIB rather than /usr/local/BIN on purpose -- a binary named
#   `tuigreet` on PATH would shadow the packaged one and the wrapper could
#   recurse into itself.
#
# SAFETY
#   Nothing here can cost a login. If any step fails the custom binary is simply
#   not installed, the wrapper falls through to the packaged tuigreet, and an
#   unknown `kind = "wave"` in the config degrades to no animation (verified:
#   stock tuigreet renders the form normally and ignores names it does not know).
#
# USAGE
#   ./build.sh            build and install if out of date
#   ./build.sh --check    report status, build nothing, exit 0
#   ./build.sh --force    rebuild even if the stamp is current
#
set -euo pipefail

# Upstream tag to build. MUST match the version the patch was written against;
# bumping it is a deliberate act -- see "Keeping it updated" in
# docs/tuigreet-wave.md.
PIN="0.11.1"

REPO_URL="https://github.com/tuigreet/tuigreet.git"
DIR="$(dirname "$(readlink -f "$0")")"
SRC="$DIR/src"
CACHE="${XDG_CACHE_HOME:-$HOME/.cache}/dotfiles-tuigreet"
PREFIX="/usr/local/lib/tuigreet"
TARGET="$PREFIX/tuigreet"
STAMP="$PREFIX/.stamp"

FORCE=0
CHECK=0
for arg in "$@"; do
    case "$arg" in
        --force) FORCE=1 ;;
        --check) CHECK=1 ;;
        *) echo "build.sh: unknown argument: $arg" >&2; exit 2 ;;
    esac
done

say()  { printf '  %s\n' "$*"; }
warn() { printf 'build.sh: %s\n' "$*" >&2; }

# The stamp ties the installed binary to the exact inputs that produced it: the
# upstream tag plus the content of both local sources. Change any one and the
# next run rebuilds; change none and it is a no-op, which matters because
# install-sway-arch.sh is re-run routinely and a Rust build is minutes.
want_stamp() {
    printf '%s %s\n' "$PIN" \
        "$(cat "$SRC/wave.rs" "$SRC/register.patch" | sha256sum | cut -d' ' -f1)"
}

have_stamp() { [ -r "$STAMP" ] && cat "$STAMP" || echo "none"; }

# Warn when the distro package has moved past the pinned tag. Without this the
# custom greeter would silently sit on an old tuigreet forever.
staleness_note() {
    local pkg
    pkg="$(pacman -Q greetd-tuigreet 2>/dev/null | awk '{print $2}' | cut -d- -f1)" || return 0
    [ -n "$pkg" ] || return 0
    if [ "$pkg" != "$PIN" ]; then
        warn "packaged greetd-tuigreet is $pkg but the custom build is pinned to $PIN."
        warn "  To pick up upstream changes: bump PIN in $(basename "$0"), re-run, test with --mock."
    fi
}

status() {
    echo "tuigreet custom build"
    say "pinned tag   : $PIN"
    say "installed    : $([ -x "$TARGET" ] && echo "$TARGET" || echo "(none -- wrapper falls back to /usr/bin/tuigreet)")"
    say "stamp wanted : $(want_stamp)"
    say "stamp present: $(have_stamp)"
    if [ -x "$TARGET" ] && [ "$(have_stamp)" = "$(want_stamp)" ]; then
        say "state        : up to date"
    else
        say "state        : REBUILD NEEDED"
    fi
    staleness_note
}

if [ "$CHECK" = 1 ]; then
    status
    exit 0
fi

[ -r "$SRC/wave.rs" ]         || { warn "missing $SRC/wave.rs"; exit 1; }
[ -r "$SRC/register.patch" ]  || { warn "missing $SRC/register.patch"; exit 1; }

if [ "$FORCE" = 0 ] && [ -x "$TARGET" ] && [ "$(have_stamp)" = "$(want_stamp)" ]; then
    echo "tuigreet custom build already current ($PIN); nothing to do."
    staleness_note
    exit 0
fi

command -v cargo > /dev/null 2>&1 || {
    warn "cargo not found. Install the toolchain first:  sudo pacman -S rust"
    exit 1
}

echo "Building custom tuigreet $PIN (this takes a few minutes the first time)..."

# Reuse one checkout so repeat builds hit the cargo cache instead of recompiling
# every dependency from scratch.
if [ ! -d "$CACHE/.git" ]; then
    rm -rf "$CACHE"
    git clone --quiet --depth 1 --branch "$PIN" "$REPO_URL" "$CACHE"
else
    git -C "$CACHE" fetch --quiet --depth 1 origin "refs/tags/$PIN:refs/tags/$PIN" 2>/dev/null || true
fi

# Always build from a pristine tree: reset discards a previous run's patch so
# applying it again cannot conflict with itself.
#
# `^{commit}` peels the annotated tag object down to the commit it points at.
# Without it `git reset --hard` warns "refs/tags/<tag> ... is not a commit!"
# on every run, because the tag ref resolves to the tag object itself.
git -C "$CACHE" checkout --quiet --force "tags/$PIN^{commit}"
git -C "$CACHE" reset  --quiet --hard   "tags/$PIN^{commit}"
git -C "$CACHE" clean  --quiet -fd

if ! git -C "$CACHE" apply --check "$SRC/register.patch" 2>/dev/null; then
    warn "register.patch does not apply to tuigreet $PIN."
    warn "  Upstream has moved. Re-create it against the new tag -- see"
    warn "  'Re-creating the patch' in docs/tuigreet-wave.md."
    exit 1
fi
git -C "$CACHE" apply "$SRC/register.patch"
install -m 0644 "$SRC/wave.rs" "$CACHE/crates/tuigreet/src/ui/bg_animation/wave.rs"

( cd "$CACHE" && cargo build --release --locked )

BUILT="$CACHE/target/release/tuigreet"
[ -x "$BUILT" ] || { warn "build reported success but $BUILT is missing"; exit 1; }

# Smoke-test before installing. The login screen depends on this binary, so it
# does not get installed until it has demonstrated it can at least run.
if ! "$BUILT" --version > /dev/null 2>&1; then
    warn "built binary failed to run; refusing to install it."
    exit 1
fi
if ! "$BUILT" --help 2>&1 | grep -q -- "--background"; then
    warn "built binary does not advertise --background; refusing to install it."
    exit 1
fi

sudo install -Dm755 "$BUILT" "$TARGET"
want_stamp | sudo tee "$STAMP" > /dev/null

echo "Installed $TARGET"
say "verify:  $TARGET --version"
say "preview: $TARGET --mock --config /etc/tuigreet/config.toml"
staleness_note
