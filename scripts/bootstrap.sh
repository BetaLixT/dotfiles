#!/bin/bash
# Bootstrap a fresh Arch machine to this package set.
#
# This installs SOFTWARE. It does not touch configuration — run
# install-sway-arch.sh afterwards for that. Keeping them separate means you can
# re-run either independently, and a config change never risks a 150-package
# transaction.
#
#   ./scripts/bootstrap.sh --desktop          # skip laptop/Intel-specific packages
#   ./scripts/bootstrap.sh --laptop           # everything, as on the original machine
#   ./scripts/bootstrap.sh --desktop --dry-run
#   ./scripts/bootstrap.sh --laptop --only aur,go
#
# Idempotent: pacman/yay use --needed, and every other phase checks before acting.
# Safe to re-run.
#
# Package lists live in packages/ so they can be regenerated:
#   pacman -Qenq | sort > packages/official.txt
#   pacman -Qemq | sort > packages/aur.txt

set -euo pipefail

DIR="$(cd "$(dirname "$(readlink -f "$0")")/.." && pwd)"
PKG="$DIR/packages"

PROFILE=""
DRY_RUN=0
ONLY=""
FAILED=()

usage() {
    sed -n '2,20p' "$0" | sed 's/^# \{0,1\}//'
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

# Read a list file, dropping comments and blanks.
list() { grep -vE '^\s*(#|$)' "$1" 2>/dev/null || true; }

# ---------------------------------------------------------------- preflight --
say "Preflight"
[ -f /etc/arch-release ] || { echo "This script is Arch-specific." >&2; exit 1; }
[ "$(id -u)" -ne 0 ] || { echo "Do not run as root; it uses sudo where needed." >&2; exit 1; }
command -v sudo >/dev/null || { echo "sudo is required." >&2; exit 1; }
info "profile: $PROFILE   dry-run: $DRY_RUN   only: ${ONLY:-<all phases>}"
info "package lists: $PKG"

# ------------------------------------------------------------------ pacman --
if want pacman; then
    say "Official repository packages"

    # Arch does not support partial upgrades; sync first or later installs can
    # pull mismatched libraries.
    run sudo pacman -Syu --needed --noconfirm base-devel git

    mapfile -t ALL < <(list "$PKG/official.txt")
    mapfile -t SKIP_REVIEW < <(list "$PKG/official-review.txt")
    SKIP=("${SKIP_REVIEW[@]}")
    if [ "$PROFILE" = desktop ]; then
        mapfile -t SKIP_LAPTOP < <(list "$PKG/official-laptop-only.txt")
        SKIP+=("${SKIP_LAPTOP[@]}")
    fi

    WANTED=()
    for p in "${ALL[@]}"; do
        skip=0
        for s in "${SKIP[@]}"; do [ "$p" = "$s" ] && { skip=1; break; }; done
        [ "$skip" = 0 ] && WANTED+=("$p")
    done

    info "${#ALL[@]} listed, ${#SKIP[@]} skipped for this profile, ${#WANTED[@]} to install"
    [ "${#SKIP[@]}" -gt 0 ] && info "skipped: ${SKIP[*]}"
    run sudo pacman -S --needed --noconfirm "${WANTED[@]}"

    if [ "$PROFILE" = desktop ]; then
        warn "GPU drivers were skipped. Install the one matching this machine:"
        warn "  Intel: vulkan-intel intel-media-driver  |  AMD: vulkan-radeon  |  NVIDIA: nvidia nvidia-utils"
    fi
fi

# --------------------------------------------------------------------- AUR --
if want aur; then
    say "AUR"
    if command -v yay >/dev/null; then
        info "yay already present"
    else
        info "bootstrapping yay-bin from the AUR (this is the one manual build)"
        if [ "$DRY_RUN" = 1 ]; then
            printf '    [dry-run] git clone https://aur.archlinux.org/yay-bin.git && makepkg -si\n'
        else
            tmp="$(mktemp -d)"
            git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$tmp/yay-bin"
            ( cd "$tmp/yay-bin" && makepkg -si --noconfirm )
            rm -rf "$tmp"
        fi
    fi

    mapfile -t AUR < <(list "$PKG/aur.txt" | grep -v -- '-debug$')
    info "${#AUR[@]} AUR packages (debug symbol packages excluded)"
    run yay -S --needed --noconfirm "${AUR[@]}" || { warn "some AUR builds failed"; FAILED+=("aur"); }
fi

# ----------------------------------------------------------------- flatpak --
if want flatpak; then
    say "Flatpak"
    if command -v flatpak >/dev/null; then
        run flatpak remote-add --if-not-exists flathub https://flathub.org/repo/flathub.flatpakrepo
        run flatpak install -y flathub it.mijorus.gearlever || { warn "flatpak install failed"; FAILED+=("flatpak"); }
    else
        warn "flatpak not installed; skipping"
    fi
fi

# ------------------------------------------------------------ dotnet tools --
if want dotnet; then
    say ".NET global tools"
    if command -v dotnet >/dev/null; then
        run dotnet tool install --global dotnet-ef 2>/dev/null || info "dotnet-ef already installed"
        # Azure DevOps feed on purpose: it tracks the version VS Code ships,
        # whereas nuget.org lags behind.
        run dotnet tool install --global roslyn-language-server --prerelease \
            --source https://pkgs.dev.azure.com/azure-public/vside/_packaging/vs-impl/nuget/v3/index.json \
            2>/dev/null || info "roslyn-language-server already installed"
        info "note: prefer per-project .config/dotnet-tools.json manifests over global tools"
    else
        warn "dotnet not found; skipping"
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
    # nvm ships as a pacman package; it must be sourced, it is not on PATH.
    if [ -s /usr/share/nvm/init-nvm.sh ]; then
        # shellcheck disable=SC1091
        . /usr/share/nvm/init-nvm.sh
    fi
    if command -v nvm >/dev/null 2>&1; then
        run nvm install --lts
        run nvm use --lts
    else
        warn "nvm not available; using system node if present"
    fi
    if command -v npm >/dev/null 2>&1; then
        mapfile -t NPMPKGS < <(list "$PKG/npm-global.txt")
        run npm install -g "${NPMPKGS[@]}" || { warn "npm global install failed"; FAILED+=("npm"); }
    else
        warn "npm not found; skipping"
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

    Not handled by this script, by design:
      * d2 and typst in ~/.local/bin are hand-dropped binaries with no package
        manager behind them — fetch them manually
      * /usr/local/bin/tuigreet-custom expects a locally built tuigreet
      * nvim plugins and mason tools install themselves on first `nvim` launch

NEXT
