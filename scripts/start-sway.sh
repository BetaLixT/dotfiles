#!/bin/bash
# Launch sway with its log captured into the systemd journal.
#
# WHY A WRAPPER: sway has no configuration directive for logging. The log level
# is a command-line flag only (`sway --help`: -V verbose, -d debug), and sway
# writes every log line to stderr. So the only place logging can be turned on
# is where sway is started -- nothing in sway/config can do it.
#
# Reading the log afterwards:
#     journalctl -t sway -b              # this boot
#     journalctl -t sway -b -1           # previous boot
#     journalctl -t sway -f              # follow live
#     journalctl -t sway -g 'output'     # monitor connect/disconnect events
#
# VERBOSITY: default is --verbose, which records output add/remove and other
# lifecycle events -- that is what makes monitor history recoverable after the
# fact. --debug is far noisier; switch it on only when chasing something:
#     SWAY_LOG_LEVEL=debug start-sway
#     SWAY_LOG_LEVEL=quiet start-sway    # sway's own default, errors only
#
# stderr is filed at priority 'info' rather than systemd-cat's default 'err',
# so ordinary sway chatter does not flood `journalctl -p err` and bury real
# errors from other services.
#
# NOTE: with logs going to the journal, a sway startup failure no longer prints
# to the terminal -- you get a blank screen instead. If that happens:
#     journalctl -t sway -b -e
# To check the config without starting sway:  sway --validate

set -u

# Load session-wide environment before starting sway.
#
# environment.d is read by `systemd --user`, which covers user *services* - but
# sway is spawned by greetd into session-N.scope, not as a systemd unit, so it
# never inherits those values. Sourcing them here is what puts them in sway's own
# environment, which every app sway launches then inherits.
#
# Without this, GTK_THEME is unset in the session and GTK apps fall back to the
# light theme. Note sway/config also runs `dbus-update-activation-environment`,
# but that only reaches D-Bus-activated apps, not ones started via sway `exec`.
#
# Files are plain KEY=VALUE. `set -a` exports everything they define.
for _envfile in "${XDG_CONFIG_HOME:-$HOME/.config}"/environment.d/*.conf; do
    [ -r "$_envfile" ] || continue
    set -a
    # shellcheck disable=SC1090
    . "$_envfile"
    set +a
done
unset _envfile

case "${SWAY_LOG_LEVEL:-verbose}" in
    debug)   LOG_FLAG=(--debug)   ;;
    verbose) LOG_FLAG=(--verbose) ;;
    quiet)   LOG_FLAG=()          ;;
    *)
        echo "start-sway: SWAY_LOG_LEVEL must be debug, verbose or quiet" >&2
        exit 2
        ;;
esac

exec systemd-cat --identifier=sway --stderr-priority=info \
     sway "${LOG_FLAG[@]}" "$@"
