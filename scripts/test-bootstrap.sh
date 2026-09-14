#!/bin/bash
# Validate bootstrap.sh against a clean Arch container.
#
# Nothing here touches the host: everything runs in a throwaway container, and
# the repo is mounted read-only then copied inside.
#
#   ./scripts/test-bootstrap.sh                 # resolve + dry-run  (~1 min)
#   ./scripts/test-bootstrap.sh --full          # actually install   (slow, GBs)
#   ./scripts/test-bootstrap.sh --shell         # drop into the container
#
# Default mode answers the two questions worth asking cheaply:
#   1. Does every package name still resolve?  (catches renames and typos,
#      which is how these lists rot)
#   2. Does the script's logic work on a machine that is NOT this one?
#      (missing tools, unset vars, wrong assumptions about what exists)
#
# It deliberately does NOT try to validate the desktop: greetd, sway and GPU
# drivers need real hardware and a session. Use a VM for that.

set -euo pipefail

DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
IMAGE="archlinux:base-devel"
MODE="resolve"

# Docker Desktop's socket is often down; the system daemon is the reliable one.
if [ -S /var/run/docker.sock ]; then
    export DOCKER_HOST="unix:///var/run/docker.sock"
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --full)  MODE=full ;;
        --shell) MODE=shell ;;
        -h|--help) sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
        *) echo "unknown option: $1" >&2; exit 2 ;;
    esac
    shift
done

say() { printf '\n\033[1m==> %s\033[0m\n' "$*"; }

command -v docker >/dev/null || { echo "docker not found" >&2; exit 1; }
docker version >/dev/null 2>&1 || {
    echo "cannot reach a docker daemon. Try: sudo systemctl start docker" >&2
    exit 1
}

say "Pulling $IMAGE"
docker pull -q "$IMAGE"

# Shared container setup: a non-root user with passwordless sudo, because
# bootstrap.sh refuses to run as root.
read -r -d '' SETUP <<'EOS' || true
set -e
pacman -Sy --noconfirm --needed git sudo >/dev/null
useradd -m tester
echo 'tester ALL=(ALL) NOPASSWD: ALL' > /etc/sudoers.d/tester
cp -r /repo /home/tester/dotfiles
chown -R tester:tester /home/tester/dotfiles
EOS

case "$MODE" in
shell)
    say "Interactive shell (container is removed on exit)"
    exec docker run --rm -it -v "$DIR":/repo:ro "$IMAGE" bash -c "$SETUP; su - tester"
    ;;

resolve)
    say "Mode: resolve + dry-run (no packages installed)"
    docker run --rm -v "$DIR":/repo:ro "$IMAGE" bash -c "$SETUP"'
set -e
cd /home/tester/dotfiles

echo
echo "--- 1. every official package name resolves against a fresh mirror db"
mapfile -t PKGS < <(grep -vE "^\s*(#|$)" packages/official.txt)
missing=0
for p in "${PKGS[@]}"; do
    if ! pacman -Sp --print-format "%n" "$p" >/dev/null 2>&1; then
        echo "    UNRESOLVED: $p"
        missing=$((missing+1))
    fi
done
echo "    checked ${#PKGS[@]} packages, $missing unresolved"

echo
echo "--- 2. bootstrap.sh dry-run as a non-root user on a clean system"
su - tester -c "cd ~/dotfiles && ./scripts/bootstrap.sh --desktop --dry-run" \
    > /tmp/dry.log 2>&1 && echo "    exit 0" || echo "    EXIT $?"
grep -E "listed,|skipped for|WARN" /tmp/dry.log | sed "s/^/    /"

echo
echo "--- 3. phase filters"
for ph in pacman aur go npm shell dotnet flatpak; do
    if su - tester -c "cd ~/dotfiles && ./scripts/bootstrap.sh --desktop --dry-run --only $ph" >/dev/null 2>&1; then
        echo "    --only $ph: ok"
    else
        echo "    --only $ph: FAILED"
    fi
done

echo
echo "--- 4. refuses to run as root"
cd /home/tester/dotfiles
./scripts/bootstrap.sh --desktop --dry-run >/dev/null 2>&1 \
    && echo "    PROBLEM: ran as root" || echo "    correctly refused (exit $?)"

echo
echo "--- 5. requires a profile"
su - tester -c "cd ~/dotfiles && ./scripts/bootstrap.sh --dry-run" >/dev/null 2>&1 \
    && echo "    PROBLEM: ran without profile" || echo "    correctly refused"
'
    ;;

full)
    say "Mode: FULL — really installs everything. This is slow and downloads GBs."
    printf '    continue? [y/N] '
    read -r ans
    [ "$ans" = y ] || { echo "    aborted"; exit 0; }
    docker run --rm -v "$DIR":/repo:ro "$IMAGE" bash -c "$SETUP"'
su - tester -c "cd ~/dotfiles && ./scripts/bootstrap.sh --desktop --only pacman,aur,go,npm,shell"
'
    ;;
esac

say "Done"
