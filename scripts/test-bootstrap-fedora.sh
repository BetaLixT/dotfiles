#!/bin/bash
# Validate bootstrap-fedora.sh against a clean Fedora container.
#
# Nothing here touches the host: everything runs in a throwaway container, and
# the repo is mounted read-only then copied inside.
#
#   ./scripts/test-bootstrap-fedora.sh            # resolve + dry-run   (~2 min)
#   ./scripts/test-bootstrap-fedora.sh --repos    # also enable the real
#                                                 # third-party repos and
#                                                 # resolve against them (~5 min)
#   ./scripts/test-bootstrap-fedora.sh --full     # actually install (slow, GBs)
#   ./scripts/test-bootstrap-fedora.sh --shell    # drop into the container
#
# Default mode answers the two questions worth asking cheaply:
#   1. Does every package name still resolve?  (catches renames and retirements,
#      which is how these lists rot -- Fedora retires packages every release)
#   2. Does the script's logic work on a machine that is NOT this one?
#
# It deliberately does NOT try to validate the desktop: greetd, sway and GPU
# drivers need real hardware and a session. Use a VM for that.

set -euo pipefail

DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
IMAGE="${FEDORA_IMAGE:-fedora:latest}"
MODE="resolve"

# Docker Desktop's socket is often down; the system daemon is the reliable one.
if [ -S /var/run/docker.sock ]; then
    export DOCKER_HOST="unix:///var/run/docker.sock"
fi

while [ $# -gt 0 ]; do
    case "$1" in
        --repos) MODE=repos ;;
        --full)  MODE=full ;;
        --shell) MODE=shell ;;
        -h|--help) sed -n '2,22p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
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
# bootstrap-fedora.sh refuses to run as root.
read -r -d '' SETUP <<'EOS' || true
set -e
dnf -q -y install git sudo findutils >/dev/null 2>&1
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
. /etc/os-release
echo "    container: Fedora $VERSION_ID, $(dnf --version | head -1)"

# One repoquery for every name, instead of 126 sequential `dnf list` calls.
# That version was both slow (~2 min) and flaky: a single stalled mirror
# request hung the whole suite with no output, because each invocation
# re-checked metadata. repoquery also does not fail on unknown names, so the
# missing ones fall out of a plain set difference.
mapfile -t PKGS < <(grep -vE "^\s*(#|$)" packages/fedora.txt)
mapfile -t LAP  < <(grep -vE "^\s*(#|$)" packages/fedora-laptop-only.txt)
ALLNAMES=("${PKGS[@]}" "${LAP[@]}")

dnf -q makecache >/dev/null 2>&1 || true
dnf repoquery --qf "%{name}\n" "${ALLNAMES[@]}" 2>/dev/null | sort -u > /tmp/found.txt
printf "%s\n" "${ALLNAMES[@]}" | sort -u > /tmp/wanted.txt
comm -23 /tmp/wanted.txt /tmp/found.txt > /tmp/unresolved.txt

echo
echo "--- 1. every name in fedora.txt resolves against stock Fedora repos"
miss=0
while read -r p; do
    printf "%s\n" "${PKGS[@]}" | grep -qxF "$p" && { echo "    UNRESOLVED: $p"; miss=$((miss+1)); }
done < /tmp/unresolved.txt
echo "    checked ${#PKGS[@]} packages, $miss unresolved"

echo
echo "--- 2. every name in fedora-laptop-only.txt also resolves AND is in fedora.txt"
lmiss=0
for p in "${LAP[@]}"; do
    grep -qxF "$p" /tmp/unresolved.txt && { echo "    UNRESOLVED: $p"; lmiss=$((lmiss+1)); }
    grep -qxF "$p" packages/fedora.txt  || { echo "    ORPHAN (skipped but never listed): $p"; lmiss=$((lmiss+1)); }
done
echo "    checked ${#LAP[@]} laptop packages, $lmiss problems"

echo
FV=$(rpm -E %fedora)
echo "--- 3. COPR projects exist AND build for this Fedora release"
# Checking only that the project exists is not enough: solopasha/hyprland is a
# real project that returns 200 and builds for rawhide only, so `copr enable`
# succeeds and then yields no packages on a stable release.
while read -r proj pkgs; do
    [ -n "$proj" ] || continue
    body=$(curl -s "https://copr.fedorainfracloud.org/api_3/project?ownername=${proj%%/*}&projectname=${proj##*/}")
    if ! echo "$body" | grep -q "chroot_repos"; then
        echo "    MISSING  $proj does not exist"
    elif echo "$body" | grep -q "fedora-${FV}-x86_64"; then
        echo "    ok       $proj ($pkgs) builds for fedora-${FV}"
    else
        echo "    NO BUILD $proj exists but has no fedora-${FV} chroot"
        echo "             chroots: $(echo "$body" | grep -o "fedora-[0-9a-z]*-x86_64" | sort -u | tr "\n" " ")"
    fi
done < <(grep -vE "^\s*(#|$)" packages/fedora-copr.txt)

echo
echo "--- 4. third-party repo endpoints reachable"
for u in \
  "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${FV}.noarch.rpm" \
  "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FV}.noarch.rpm" \
  "https://packages.microsoft.com/rhel/9/prod/repodata/repomd.xml" \
  "https://packages.microsoft.com/yumrepos/edge/repodata/repomd.xml" \
  "https://brave-browser-rpm-release.s3.brave.com/brave-browser.repo" \
  "https://linux-packages.resilio.com/resilio-sync/key.asc" \
  "https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz" \
  "https://download.docker.com/linux/fedora/docker-ce.repo" ; do
  printf "    %s  %s\n" "$(curl -sL -o /dev/null -w "%{http_code}" "$u")" "${u#https://}"
done

echo
echo "--- 5. bootstrap-fedora.sh dry-run as a non-root user on a clean system"
su - tester -c "cd ~/dotfiles && ./scripts/bootstrap-fedora.sh --desktop --dry-run" \
    > /tmp/dry.log 2>&1 && echo "    exit 0" || echo "    EXIT $?"
grep -E "^    Fedora [0-9]|dnf generation|listed,|skipped:|WARN" /tmp/dry.log | sed "s/^/    /"

echo
echo "--- 6. laptop profile skips nothing"
su - tester -c "cd ~/dotfiles && ./scripts/bootstrap-fedora.sh --laptop --dry-run" 2>&1 \
    | grep -E "listed," | sed "s/^/    /"

echo
echo "--- 7. phase filters"
for ph in repos dnf copr flatpak dotnet go npm cargo bin teams shell; do
    if su - tester -c "cd ~/dotfiles && ./scripts/bootstrap-fedora.sh --desktop --dry-run --only $ph" >/dev/null 2>&1; then
        echo "    --only $ph: ok"
    else
        echo "    --only $ph: FAILED"
    fi
done

echo
echo "--- 8. refuses to run as root"
cd /home/tester/dotfiles
./scripts/bootstrap-fedora.sh --desktop --dry-run >/dev/null 2>&1 \
    && echo "    PROBLEM: ran as root" || echo "    correctly refused"

echo
echo "--- 9. requires a profile"
su - tester -c "cd ~/dotfiles && ./scripts/bootstrap-fedora.sh --dry-run" >/dev/null 2>&1 \
    && echo "    PROBLEM: ran without profile" || echo "    correctly refused"

echo
echo "--- 11. install-sway-arch.sh distro shim picks the Fedora branch"
# Extract the shim and exercise it in isolation -- running the real installer
# here would try to write /etc and enable units.
awk "/^if command -v pacman >\\/dev\\/null 2>&1; then\$/{f=1} f{print} /^# pkg_need/{p=1} p&&/^}\$/{exit}" \
    /home/tester/dotfiles/install-sway-arch.sh > /tmp/shim.sh
# shellcheck disable=SC1091
. /tmp/shim.sh
echo "    DISTRO=$DISTRO  (expected: fedora)"
[ "$DISTRO" = fedora ] || echo "    PROBLEM: wrong branch"
dnf -q -y install greetd >/dev/null 2>&1
pkg_installed greetd && echo "    ok      pkg_installed greetd (rpm-backed)" || echo "    PROBLEM: greetd not seen"
pkg_installed definitely-not-a-package && echo "    PROBLEM: false positive" || echo "    ok      unknown package correctly absent"
# the two names that actually differ between distros
for pair in "greetd-tuigreet tuigreet" "openssh openssh-server"; do
    set -- $pair
    if dnf -q list --available "$2" >/dev/null 2>&1 || rpm -q "$2" >/dev/null 2>&1; then
        echo "    ok      $1 -> $2 resolves on Fedora"
    else
        echo "    MISSING $1 -> $2"
    fi
    dnf -q list --available "$1" >/dev/null 2>&1 \
        && echo "    note    the Arch name $1 ALSO exists on Fedora" \
        || echo "    ok      the Arch name $1 does not exist on Fedora (shim is required)"
done

echo
echo "--- 12. nothing in install-sway-arch.sh calls pacman outside the shim"
if grep -nE "^\s*[^#]*\b(pacman|yay)\b" /home/tester/dotfiles/install-sway-arch.sh | grep -vE "command -v pacman|DISTRO=arch|arch\)" ; then
    echo "    PROBLEM: bare pacman/yay above would fail on Fedora"
else
    echo "    ok      all package calls go through pkg_need/pkg_installed"
fi

echo
echo "--- 13. dnf-generation detection is stable (regression: pipefail/SIGPIPE race)"
# `dnf --version | head -1 | grep` under `set -o pipefail` raced: head closing
# the pipe killed dnf with SIGPIPE, so detection fell through to dnf4 and the
# repos phase would have used the wrong config-manager syntax. Run it enough
# times to catch a reintroduction.
gens=$(for i in $(seq 1 8); do
    su - tester -c "cd ~/dotfiles && ./scripts/bootstrap-fedora.sh --desktop --dry-run --only nothing" 2>&1 \
      | sed -n "s/.*dnf generation: //p"
done | sort -u | tr "\n" " ")
echo "    observed over 8 runs: [$gens]"
case "$(echo "$gens" | tr -d " ")" in
    5) echo "    ok      always dnf5, as expected on Fedora 44" ;;
    4) echo "    PROBLEM: detected dnf4 on a dnf5 system" ;;
    *) echo "    PROBLEM: unstable detection -- the race is back" ;;
esac

echo
echo "--- 14. rofi has a Wayland backend and the repo .rasi files parse"
# Load-bearing: the whole options menu is rofi, and the desktop is Wayland.
# Fedora has no rofi-wayland package because rofi 2.0 merged the fork
# upstream -- so this asserts the backend is really there, rather than
# trusting the package name.
dnf -q -y install rofi >/dev/null 2>&1
echo "    version: $(rofi -version 2>&1 | head -1)"
if rofi -help 2>&1 | sed -n "/Display backends/,/^$/p" | grep -q "wayland"; then
    echo "    ok      wayland backend present"
else
    echo "    PROBLEM: no wayland backend -- rofi would need Xwayland"
fi
mkdir -p ~/.config/rofi && cp /home/tester/dotfiles/rofi/*.rasi ~/.config/rofi/ 2>/dev/null
if rofi -no-config -theme ~/.config/rofi/kanagawa.rasi -dump-theme >/dev/null 2>/tmp/th.err; then
    echo "    ok      kanagawa.rasi parses$([ -s /tmp/th.err ] && echo " (with warnings)")"
    [ -s /tmp/th.err ] && sed "s/^/            /" /tmp/th.err
else
    echo "    PROBLEM: kanagawa.rasi failed to parse"; sed "s/^/            /" /tmp/th.err
fi
if rofi -dump-config >/dev/null 2>/tmp/cf.err; then
    echo "    ok      config.rasi parses$([ -s /tmp/cf.err ] && echo " (with warnings)")"
    [ -s /tmp/cf.err ] && sed "s/^/            /" /tmp/cf.err
else
    echo "    PROBLEM: config.rasi failed to parse"; sed "s/^/            /" /tmp/cf.err
fi

echo
echo "--- 15. Firefox is the only browser, and the teams phase is opt-in"
for b in brave-browser microsoft-edge-stable app.zen_browser.zen chromium google-chrome; do
    if grep -q "$b" /home/tester/dotfiles/scripts/bootstrap-fedora.sh; then
        echo "    PROBLEM: $b is still referenced"
    else
        echo "    ok      no $b"
    fi
done
grep -qx "firefox" /home/tester/dotfiles/packages/fedora.txt \
    && echo "    ok      firefox is in fedora.txt" \
    || echo "    PROBLEM: firefox missing"
# A default sweep must not pull in Teams; only --only teams may.
if su - tester -c "cd ~/dotfiles && ./scripts/bootstrap-fedora.sh --laptop --dry-run" 2>&1 | grep -q "==> Microsoft Teams"; then
    echo "    PROBLEM: teams phase ran in a default sweep"
else
    echo "    ok      teams phase skipped by default"
fi
if su - tester -c "cd ~/dotfiles && ./scripts/bootstrap-fedora.sh --laptop --dry-run --only teams" 2>&1 | grep -q "==> Microsoft Teams"; then
    echo "    ok      --only teams reaches the phase"
else
    echo "    PROBLEM: --only teams did not run the phase"
fi
# and the release really does publish an x86_64 rpm, which the phase greps for
# Read into a variable rather than piping to `grep -q`: grep exits on the
# first match, curl takes SIGPIPE and prints "Failed writing body".
# (No single quotes in this block -- the whole inner script is single-quoted.)
TFL_JSON=$(curl -fsSL https://api.github.com/repos/IsmaelMartinez/teams-for-linux/releases/latest || true)
TFL_TAG=$(printf "%s" "$TFL_JSON" | grep -o "\"tag_name\": *\"[^\"]*\"" | head -1 | sed "s/.*: *\"//;s/\"//")
case "$TFL_JSON" in
    *browser_download_url*x86_64.rpm*)
        echo "    ok      upstream publishes an x86_64 rpm (${TFL_TAG:-unknown})" ;;
    *)  echo "    PROBLEM: no x86_64 rpm in the latest release" ;;
esac

echo
echo "--- 10. .NET channel is installable and overridable"
for ch in 8.0 9.0 10.0; do
    ok=1
    for p in "dotnet-sdk-$ch" "dotnet-runtime-$ch" "aspnetcore-runtime-$ch"; do
        dnf repoquery --qf "%{name}\n" "$p" 2>/dev/null | grep -qx "$p" || ok=0
    done
    [ "$ok" = 1 ] && echo "    DOTNET_CHANNEL=$ch: all three resolve" || echo "    DOTNET_CHANNEL=$ch: NOT available"
done
su - tester -c "cd ~/dotfiles && DOTNET_CHANNEL=10.0 ./scripts/bootstrap-fedora.sh --desktop --dry-run --only dotnet" 2>&1 \
    | grep -E "dotnet-sdk|\.NET" | head -3 | sed "s/^/    /"
'
    ;;

repos)
    say "Mode: repos — really enables RPM Fusion and the third-party repos,"
    say "then resolves the packages that depend on them. No packages installed."
    docker run --rm -v "$DIR":/repo:ro "$IMAGE" bash -c "$SETUP"'
set -e
su - tester -c "cd ~/dotfiles && ./scripts/bootstrap-fedora.sh --desktop --only repos" 2>&1 | grep -vE "^\\s*$" | tail -40
echo
echo "--- third-party packages resolve now that their repos are enabled"
# Read the list out of the script rather than restating it here: a hardcoded
# copy silently stopped covering `code` when it was added.
TP=$(sed -n "/^    THIRDPARTY=(/,/)$/p" /home/tester/dotfiles/scripts/bootstrap-fedora.sh \
     | tr "\n" " " | sed "s/.*THIRDPARTY=(//;s/).*//")
for p in $TP; do
    if dnf -q list --available "$p" >/dev/null 2>&1; then echo "    ok      $p"; else echo "    MISSING $p"; fi
done

echo
echo "--- bin phase really installs ngrok (no RPM repo exists for it)"
su - tester -c "cd ~/dotfiles && ./scripts/bootstrap-fedora.sh --desktop --only bin" >/dev/null 2>&1 || true
if [ -x /home/tester/.local/bin/ngrok ]; then
    echo "    ok      ngrok $(su - tester -c "~/.local/bin/ngrok version" 2>/dev/null | head -1)"
else
    echo "    MISSING ngrok was not installed"
fi

echo
echo "--- COPR packages resolve once enabled"
su - tester -c "cd ~/dotfiles && ./scripts/bootstrap-fedora.sh --desktop --only copr" >/dev/null 2>&1 || true
# Likewise driven by the list file, not a copy.
while read -r proj pkgs; do
    [ -n "$proj" ] || continue
    for p in $pkgs; do
        if dnf -q list --available "$p" >/dev/null 2>&1 || rpm -q "$p" >/dev/null 2>&1; then
            echo "    ok      $p (from $proj)"
        else
            echo "    MISSING $p (from $proj)"
        fi
    done
done < <(grep -vE "^\s*(#|$)" /home/tester/dotfiles/packages/fedora-copr.txt)
'
    ;;

full)
    say "Mode: FULL — really installs everything. This is slow and downloads GBs."
    printf '    continue? [y/N] '
    read -r ans
    [ "$ans" = y ] || { echo "    aborted"; exit 0; }
    docker run --rm -v "$DIR":/repo:ro "$IMAGE" bash -c "$SETUP"'
su - tester -c "cd ~/dotfiles && ./scripts/bootstrap-fedora.sh --desktop --only repos,dnf,copr,dotnet,shell"
'
    ;;
esac

say "Done"
