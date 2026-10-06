#!/bin/bash
# Bootstrap a fresh Fedora machine to this package set (sway desktop).
#
# Fedora counterpart of scripts/bootstrap.sh. Same contract: this installs
# SOFTWARE only. Configuration is a separate step -- run install-sway-arch.sh
# afterwards (it is distro-agnostic; it only links config into place).
#
#   ./scripts/bootstrap-fedora.sh --desktop            # skip laptop/Intel bits
#   ./scripts/bootstrap-fedora.sh --laptop             # everything
#   ./scripts/bootstrap-fedora.sh --desktop --dry-run
#   ./scripts/bootstrap-fedora.sh --laptop --only copr,dotnet
#
# Phases, in order:
#   repos    RPM Fusion + Microsoft/Resilio/Docker repo definitions
#   dnf      packages/fedora.txt, minus the profile/review skips
#   copr     packages/fedora-copr.txt (Fedora's AUR analogue)
#   flatpak  Flathub apps that have no sane RPM
#   dotnet   SDK/runtime from Fedora repos + the two global tools
#   go       packages/go-tools.txt
#   npm      packages/npm-global.txt under nvm, or system node
#   cargo    crates with no Fedora package
#   bin      tarball-only binaries (ngrok)
#   teams    teams-for-linux -- OPT-IN, only via --only teams
#   shell    oh-my-zsh, tmux TPM
#
# Idempotent: dnf uses `install --skip-installed`-equivalent semantics via
# `dnf install -y` on already-present packages (a no-op), and every other phase
# checks before acting. Safe to re-run.
#
# Regenerating the list after changes on a Fedora box:
#   dnf repoquery --userinstalled --qf '%{name}\n' | sort > packages/fedora.txt

set -euo pipefail

DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
PKG="$DIR/packages"

PROFILE=""
DRY_RUN=0
ONLY=""
FAILED=()

# The .NET line to install. Fedora 44 carries 8.0, 9.0 and 10.0 side by side.
DOTNET_CHANNEL="${DOTNET_CHANNEL:-9.0}"

usage() {
    sed -n '2,30p' "$0" | sed 's/^# \{0,1\}//'
    exit "${1:-0}"
}

while [ $# -gt 0 ]; do
    case "$1" in
        --desktop)  PROFILE=desktop ;;
        --laptop)   PROFILE=laptop ;;
        --dry-run)  DRY_RUN=1 ;;
        --only)     shift; ONLY="${1:-}" ;;
        -h|--help)  usage 0 ;;
        *) echo "unknown option: $1" >&2; usage 2 ;;
    esac
    shift
done

[ -n "$PROFILE" ] || { echo "error: pass --desktop or --laptop" >&2; usage 2; }

say()  { printf '\n\033[1m==> %s\033[0m\n' "$*"; }
info() { printf '    %s\n' "$*"; }
warn() { printf '    \033[33mWARN\033[0m %s\n' "$*"; }

run() {
    if [ "$DRY_RUN" = 1 ]; then
        printf '    [dry-run] %s\n' "$*"
    else
        "$@"
    fi
}

want() {
    [ -z "$ONLY" ] && return 0
    case ",$ONLY," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

list() { grep -vE '^\s*(#|$)' "$1" 2>/dev/null || true; }

# Like want(), but never runs in a default sweep -- only when named by --only.
# For phases that install something opinionated the base setup leaves out.
want_explicit() {
    [ -n "$ONLY" ] || return 1
    case ",$ONLY," in *",$1,"*) return 0 ;; *) return 1 ;; esac
}

# ---------------------------------------------------------------- preflight --
say "Preflight"
[ -f /etc/fedora-release ] || { echo "This script is Fedora-specific. On Arch use scripts/bootstrap.sh." >&2; exit 1; }
[ "$(id -u)" -ne 0 ] || { echo "Do not run as root; it uses sudo where needed." >&2; exit 1; }
command -v sudo >/dev/null || { echo "sudo is required." >&2; exit 1; }

FEDORA_VER="$(rpm -E %fedora)"
info "Fedora $FEDORA_VER"
info "profile: $PROFILE   dry-run: $DRY_RUN   only: ${ONLY:-<all phases>}"
info "package lists: $PKG"

# dnf5 (Fedora 41+) and dnf4 disagree on config-manager syntax. Detect once.
#
# Read the version with a command substitution, NOT `dnf --version | head -1`.
# Under `set -o pipefail`, head closing the pipe early kills dnf with SIGPIPE,
# the pipeline reports failure, and detection silently falls through to dnf4 --
# which then uses the wrong config-manager syntax and breaks the repos phase.
# That raced: the same container reported 5 on one run and 4 on the next.
DNF_VERSION_OUT="$(dnf --version 2>/dev/null || true)"
case "$DNF_VERSION_OUT" in
    dnf5*) DNF_GEN=5 ;;
    *)     DNF_GEN=4 ;;
esac
info "dnf generation: $DNF_GEN"

add_repofile() {
    # add_repofile <url-of-.repo-file>
    if [ "$DNF_GEN" = 5 ]; then
        run sudo dnf config-manager addrepo --overwrite --from-repofile="$1"
    else
        run sudo dnf config-manager --add-repo "$1"
    fi
}

# ----------------------------------------------------------------- repos ----
if want repos; then
    say "Repositories"

    if [ "$DNF_GEN" = 5 ]; then
        run sudo dnf install -y dnf5-plugins
    else
        run sudo dnf install -y dnf-plugins-core
    fi

    # Deliberately NOT here: Brave and Microsoft Edge. Firefox is the only
    # browser this setup installs -- see the "One browser" note in
    # docs/fedora-port.md for the reasoning and what it costs (Teams).
    info "RPM Fusion (free + nonfree) -- codecs and the nonfree driver path"
    run sudo dnf install -y \
        "https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-${FEDORA_VER}.noarch.rpm" \
        "https://download1.rpmfusion.org/nonfree/fedora/rpmfusion-nonfree-release-${FEDORA_VER}.noarch.rpm" \
        || { warn "RPM Fusion enable failed"; FAILED+=("repos:rpmfusion"); }

    # Microsoft publishes these in THREE different places, and the obvious
    # one is the wrong one. packages.microsoft.com/fedora/<ver>/prod exists and
    # returns a valid repomd.xml for every Fedora release, but it carries only
    # mdatp, procdump, procmon, sysinternals and libmsquic -- no powershell and
    # no edge. Verified by reading its primary.xml. Use these instead:
    info "Microsoft: PowerShell (rhel/9/prod -- what MS documents for Fedora)"
    run sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc || true
    if [ "$DRY_RUN" = 1 ]; then
        printf '    [dry-run] write /etc/yum.repos.d/microsoft-prod.repo\n'
    else
        sudo tee /etc/yum.repos.d/microsoft-prod.repo >/dev/null <<'EOF'
[packages-microsoft-com-prod]
name=packages-microsoft-com-prod
baseurl=https://packages.microsoft.com/rhel/9/prod/
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    fi

    info "Microsoft: VS Code (a third MS repo, separate again)"
    if [ "$DRY_RUN" = 1 ]; then
        printf '    [dry-run] write /etc/yum.repos.d/vscode.repo\n'
    else
        sudo tee /etc/yum.repos.d/vscode.repo >/dev/null <<'EOF'
[code]
name=Visual Studio Code
baseurl=https://packages.microsoft.com/yumrepos/vscode
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
    fi

    info "Resilio Sync"
    run sudo rpm --import https://linux-packages.resilio.com/resilio-sync/key.asc || true
    if [ "$DRY_RUN" = 1 ]; then
        printf '    [dry-run] write /etc/yum.repos.d/resilio-sync.repo\n'
    else
        sudo tee /etc/yum.repos.d/resilio-sync.repo >/dev/null <<'EOF'
[resilio-sync]
name=Resilio Sync
baseurl=https://linux-packages.resilio.com/resilio-sync/rpm/$basearch
enabled=1
gpgcheck=1
gpgkey=https://linux-packages.resilio.com/resilio-sync/key.asc
EOF
    fi

    # Docker CE. The Arch box runs docker-desktop from the AUR; on Fedora the
    # engine comes from Docker's own repo and Docker Desktop is a separate
    # hand-installed RPM (see docs/fedora-port.md).
    info "Docker CE"
    add_repofile https://download.docker.com/linux/fedora/docker-ce.repo \
        || { warn "docker repo failed"; FAILED+=("repos:docker"); }

    run sudo dnf -y makecache || true
fi

# ------------------------------------------------------------------- dnf ----
if want dnf; then
    say "Fedora repository packages"

    run sudo dnf -y upgrade --refresh

    mapfile -t ALL < <(list "$PKG/fedora.txt")
    mapfile -t SKIP_REVIEW < <(list "$PKG/fedora-review.txt")
    SKIP=("${SKIP_REVIEW[@]}")
    if [ "$PROFILE" = desktop ]; then
        mapfile -t SKIP_LAPTOP < <(list "$PKG/fedora-laptop-only.txt")
        SKIP+=("${SKIP_LAPTOP[@]}")
    fi

    WANTED=()
    for p in "${ALL[@]}"; do
        skip=0
        for s in "${SKIP[@]:-}"; do [ "$p" = "$s" ] && { skip=1; break; }; done
        [ "$skip" = 0 ] && WANTED+=("$p")
    done

    info "${#ALL[@]} listed, ${#SKIP[@]} skipped for this profile, ${#WANTED[@]} to install"
    [ "${#SKIP[@]}" -gt 0 ] && info "skipped: ${SKIP[*]}"
    run sudo dnf install -y "${WANTED[@]}" || { warn "some packages failed"; FAILED+=("dnf"); }

    # Third-party-repo packages, kept out of fedora.txt so that list stays
    # resolvable against a stock Fedora mirror (which is what the test harness
    # checks). These need the repos phase to have run.
    THIRDPARTY=(powershell code resilio-sync
                docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin)
    info "third-party-repo packages: ${THIRDPARTY[*]}"
    run sudo dnf install -y "${THIRDPARTY[@]}" || { warn "some third-party packages failed"; FAILED+=("dnf:thirdparty"); }

    if [ "$PROFILE" = desktop ]; then
        warn "Intel-specific packages were skipped. mesa-vulkan-drivers covers"
        warn "every Mesa ICD, so AMD and Intel need nothing more. For NVIDIA:"
        warn "  sudo dnf install akmod-nvidia xorg-x11-drv-nvidia-cuda   (RPM Fusion nonfree)"
    fi
fi

# ------------------------------------------------------------------ copr ----
if want copr; then
    say "COPR (Fedora's AUR analogue)"
    while IFS= read -r line; do
        [ -n "$line" ] || continue
        proj="${line%%[[:space:]]*}"
        pkgs="${line#"$proj"}"
        # shellcheck disable=SC2086
        set -- $pkgs
        [ $# -gt 0 ] || continue
        info "copr enable $proj  ->  $*"
        run sudo dnf -y copr enable "$proj" || { warn "copr enable failed: $proj"; FAILED+=("copr:$proj"); continue; }
        run sudo dnf install -y "$@" || { warn "install failed from $proj"; FAILED+=("copr:$proj"); }
    done < <(list "$PKG/fedora-copr.txt")
fi

# --------------------------------------------------------------- flatpak ----
if want flatpak; then
    say "Flatpak"
    if command -v flatpak >/dev/null; then
        run flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        # Postman, DBeaver and Zed have no maintained Fedora RPM; on Arch
        # these came from the AUR as -bin packages, which is the same bargain.
        run flatpak install -y flathub \
            it.mijorus.gearlever \
            com.getpostman.Postman \
            io.dbeaver.DBeaverCommunity \
            dev.zed.Zed \
            || { warn "flatpak install failed"; FAILED+=("flatpak"); }
    else
        warn "flatpak not installed; skipping"
    fi
fi

# ---------------------------------------------------------------- dotnet ----
if want dotnet; then
    say ".NET ${DOTNET_CHANNEL}"
    # Unlike Arch (one rolling dotnet-sdk), Fedora versions the packages, so
    # the channel is explicit and several can coexist.
    run sudo dnf install -y \
        "dotnet-sdk-${DOTNET_CHANNEL}" \
        "dotnet-runtime-${DOTNET_CHANNEL}" \
        "aspnetcore-runtime-${DOTNET_CHANNEL}" \
        || { warn "dotnet install failed"; FAILED+=("dotnet:sdk"); }

    if command -v dotnet >/dev/null || [ "$DRY_RUN" = 1 ]; then
        run dotnet tool install --global dotnet-ef 2>/dev/null || info "dotnet-ef already installed"
        # Azure DevOps feed on purpose: it tracks the version VS Code ships,
        # whereas nuget.org lags behind.
        run dotnet tool install --global roslyn-language-server --prerelease \
            --source https://pkgs.dev.azure.com/azure-public/vside/_packaging/vs-impl/nuget/v3/index.json \
            2>/dev/null || info "roslyn-language-server already installed"
        info "note: prefer per-project .config/dotnet-tools.json manifests over global tools"
        info "~/.dotnet/tools must be on PATH (.zshrc-lnx already does this)"
    else
        warn "dotnet not on PATH after install; skipping global tools"
    fi
fi

# ---------------------------------------------------------------- go tools --
if want go; then
    say "Go tools"
    if command -v go >/dev/null; then
        while IFS= read -r mod; do
            info "go install $mod@latest"
            run go install "$mod@latest" || { warn "failed: $mod"; FAILED+=("go:$mod"); }
        done < <(list "$PKG/go-tools.txt")

        # Fedora has no package for these three; on Arch they came from the AUR.
        for extra in \
            github.com/darkhz/bluetuith \
            github.com/rakyll/hey ; do
            info "go install $extra@latest   (AUR replacement)"
            run go install "$extra@latest" || { warn "failed: $extra"; FAILED+=("go:$extra"); }
        done

        # Private techunicorn.com modules are deliberately NOT installed here.
        # They need working company credentials, fail noisily without them, and
        # are only relevant on a machine already set up for that work. Install
        # them by hand if needed; GOPRIVATE is already set in .zshrc-lnx.
    else
        warn "go not found; skipping"
    fi
fi

# ------------------------------------------------------------ node / npm -g --
if want npm; then
    say "Node and global npm packages"
    # Fedora has no nvm package (Arch does, at /usr/share/nvm/init-nvm.sh), so
    # use nvm if the user installed it by hand, else the dnf nodejs24.
    if [ -s "$HOME/.nvm/nvm.sh" ]; then
        # shellcheck disable=SC1091
        . "$HOME/.nvm/nvm.sh"
    fi
    if command -v nvm >/dev/null 2>&1; then
        run nvm install --lts
        run nvm use --lts
    else
        info "nvm not present; using the nodejs24 package from dnf"
        info "to get nvm: curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.40.1/install.sh | bash"
    fi
    if command -v npm >/dev/null 2>&1; then
        mapfile -t NPMPKGS < <(list "$PKG/npm-global.txt")
        run npm install -g "${NPMPKGS[@]}" || { warn "npm global install failed"; FAILED+=("npm"); }
    else
        warn "npm not found; skipping"
    fi
fi

# ----------------------------------------------------------------- cargo ----
if want cargo; then
    say "Cargo crates"
    # eww has no Fedora package and no trustworthy COPR; it builds cleanly.
    if command -v cargo >/dev/null; then
        run cargo install eww --git https://github.com/elkowar/eww --locked \
            || { warn "eww build failed (needs gtk3-devel gtk-layer-shell-devel)"; FAILED+=("cargo:eww"); }
    else
        warn "cargo not found; skipping"
    fi
fi

# ------------------------------------------------------------------- bin ----
if want bin; then
    say "Hand-installed binaries"
    # ngrok ships a Debian repo and nothing else -- its S3 bucket has dists/
    # and pool/ only, no rpm tree, despite the docs implying otherwise. The
    # published tarball is the supported route on RPM distros.
    # pulsemixer has no RPM and is a single Python script. Fedora enforces
    # PEP 668, so `pip install --user` is refused outright -- pipx is the route.
    if command -v pulsemixer >/dev/null; then
        info "pulsemixer already present"
    else
        run sudo dnf install -y pipx
        run pipx install pulsemixer || { warn "pulsemixer install failed"; FAILED+=("bin:pulsemixer"); }
    fi

    if command -v ngrok >/dev/null; then
        info "ngrok already present ($(command -v ngrok))"
    else
        info "ngrok -> ~/.local/bin"
        if [ "$DRY_RUN" = 1 ]; then
            printf '    [dry-run] curl ngrok-v3-stable-linux-amd64.tgz | tar -xz -C ~/.local/bin\n'
        else
            mkdir -p "$HOME/.local/bin"
            if curl -fsSL https://bin.equinox.io/c/bNyj1mQVY4c/ngrok-v3-stable-linux-amd64.tgz \
                 | tar -xz -C "$HOME/.local/bin" ngrok; then
                chmod +x "$HOME/.local/bin/ngrok"
            else
                warn "ngrok download failed"; FAILED+=("bin:ngrok")
            fi
        fi
    fi
fi

# ----------------------------------------------------------------- teams ----
if want_explicit teams; then
    say "Microsoft Teams (opt-in)"
    # Only reachable via `--only teams`; a default run installs no Teams client.
    #
    # This exists because Firefox is the only browser this setup installs, and
    # Teams-in-Firefox cannot screen-share (incoming calls also divert to your
    # phone). Microsoft discontinued its own Linux Teams client, so the choice
    # is a dedicated ~200MB Electron app or a whole second browser engine. The
    # app is the smaller of the two.
    #
    # IsmaelMartinez/teams-for-linux is actively maintained (v2.24.0, Oct 2026)
    # and ships an x86_64 RPM. Wayland screen sharing goes through the PipeWire
    # portal -- xdg-desktop-portal-wlr is already in packages/fedora.txt.
    # Sharing a single window is still rough upstream; sharing a whole output
    # is the reliable path.
    if rpm -q teams-for-linux >/dev/null 2>&1; then
        info "teams-for-linux already installed"
    elif [ "$DRY_RUN" = 1 ]; then
        printf '    [dry-run] resolve + install latest teams-for-linux x86_64 rpm from GitHub\n'
    else
        info "resolving the latest release from GitHub"
        TFL_URL=$(curl -fsSL https://api.github.com/repos/IsmaelMartinez/teams-for-linux/releases/latest \
            | grep -o '"browser_download_url": *"[^"]*\.x86_64\.rpm"' \
            | head -1 | sed 's/.*"\(https[^"]*\)"/\1/')
        if [ -n "$TFL_URL" ]; then
            info "${TFL_URL##*/}"
            run sudo dnf install -y "$TFL_URL" \
                || { warn "teams-for-linux install failed"; FAILED+=("teams"); }
        else
            warn "could not find an x86_64 rpm in the latest release"
            FAILED+=("teams")
        fi
    fi
fi

# ------------------------------------------------------------ shell extras --
if want shell; then
    say "Shell and tmux extras"
    if [ -d "$HOME/.oh-my-zsh" ]; then
        info "oh-my-zsh already present"
    else
        run git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$HOME/.oh-my-zsh"
    fi
    if [ -d "$HOME/.tmux/plugins/tpm" ]; then
        info "tmux TPM already present"
    else
        run git clone --depth=1 https://github.com/tmux-plugins/tpm "$HOME/.tmux/plugins/tpm"
        info "after starting tmux, press prefix + I to install plugins"
    fi
fi

# ------------------------------------------------------------------- wrap ---
say "Done"
if [ "${#FAILED[@]}" -gt 0 ]; then
    warn "phases with failures: ${FAILED[*]}"
fi
cat <<'NEXT'

    Software is installed. Configuration is a separate step:

        ./install-sway-arch.sh

    (Despite the name it now runs on both distros: it is mostly symlinks, and
    the few package guards inside it go through a pacman/dnf shim.)

    Browsers: Firefox only. Brave, Edge and Zen are deliberately not
    installed. The one thing this costs is Microsoft Teams: Firefox cannot
    screen-share in Teams web, and incoming calls divert to your phone. If
    you need that back, install the dedicated client rather than a whole
    second browser:

        ./scripts/bootstrap-fedora.sh --laptop --only teams

    Not handled by this script, by design -- see docs/fedora-port.md:
      * herdr        -- install from https://herdr.dev
      * Docker Desktop, Azure Storage Explorer, SF Mono Nerd Font,
        kanagawa-gtk-theme, rofi-bluetooth, wlprop -- hand-installed, no RPM
      * ueberzugpp, swayosd, recordmydesktop, networkmanager-dmenu and
        hyprpicker have no Fedora package and no usable COPR -- build from
        source if you want them. hyprpicker is the colour picker in
        scripts/options-menu.sh, so that entry will not work until you do.
      * d2 and typst in ~/.local/bin are hand-dropped binaries
      * nvim plugins and mason tools install themselves on first `nvim` launch

NEXT
