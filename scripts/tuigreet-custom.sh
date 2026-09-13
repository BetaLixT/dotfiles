#!/bin/sh
#
# Launch the locally-built tuigreet if it is present, otherwise the packaged one.
#
# WHY A WRAPPER: greetd's command line is fixed in /etc/greetd/config.toml. If it
# named the custom binary directly, then any machine where the build had not run
# -- a fresh install, no network, no Rust, a failed compile -- would have a
# greetd command pointing at a file that does not exist, and the login screen
# would not come up at all.
#
# With this indirection the worst case is a missing animation, never a missing
# greeter. The packaged tuigreet is deliberately kept installed as that fallback.
#
# Note /usr/local/lib, not /usr/local/bin: a binary named `tuigreet` in
# /usr/local/bin would come before /usr/bin on PATH, and the fallback below
# would re-exec this wrapper instead of the packaged greeter.
#
# Build/refresh the custom binary with:  ~/dotfiles/system/tuigreet/build.sh
# Inspect what is in use with:           ~/dotfiles/system/tuigreet/build.sh --check

set -u

CUSTOM=/usr/local/lib/tuigreet/tuigreet
PACKAGED=/usr/bin/tuigreet

if [ -x "$CUSTOM" ]; then
    exec "$CUSTOM" "$@"
fi

exec "$PACKAGED" "$@"
