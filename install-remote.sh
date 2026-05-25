#!/usr/bin/env bash
# ==============================================================================
# install-remote.sh - One-line remote installer for git-identity-manager
#
# Usage:
#   curl -sSL https://raw.githubusercontent.com/NWGKGIT/git-identity-manager/main/install-remote.sh | bash
#
# Options (pass via environment variables):
#   GIT_IDENTITY_DIR   Override the clone destination (default: ~/.local/share/git-identity-manager)
#   GITUSER_SYSTEM     Set to 1 to install to /usr/local/bin instead of ~/.local/bin
# ==============================================================================

set -euo pipefail

REPO_URL="https://github.com/NWGKGIT/git-identity-manager.git"
INSTALL_PATH="${GIT_IDENTITY_DIR:-$HOME/.local/share/git-identity-manager}"

step()  { printf '\n[+] %s\n' "$*"; }
info()  { printf '    %s\n' "$*"; }
die()   { printf '    error: %s\n' "$*" >&2; exit 1; }

printf '\n%s\n' "========================================"
printf '%s\n'   " Git Identity Manager - Remote Installer"
printf '%s\n\n' "========================================"

# ------------------------------------------------------------------------------
# Preflight
# ------------------------------------------------------------------------------

step "Checking dependencies"

command -v git &>/dev/null || die "git is not installed. Please install git first."
info "git found: $(git --version)"

# ------------------------------------------------------------------------------
# Clone or update
# ------------------------------------------------------------------------------

step "Fetching git-identity-manager"

if [[ -d "$INSTALL_PATH/.git" ]]; then
    info "Existing installation found at $INSTALL_PATH. Updating..."
    git -C "$INSTALL_PATH" pull --ff-only --quiet
    info "Updated to latest version."
else
    info "Cloning to $INSTALL_PATH..."
    git clone --depth 1 --quiet "$REPO_URL" "$INSTALL_PATH"
    info "Clone complete."
fi

# ------------------------------------------------------------------------------
# Run local installer
# ------------------------------------------------------------------------------

step "Running installer"

INSTALLER_FLAGS=()
[[ "${GITUSER_SYSTEM:-0}" == "1" ]] && INSTALLER_FLAGS+=("--system")

bash "$INSTALL_PATH/install.sh" "${INSTALLER_FLAGS[@]+"${INSTALLER_FLAGS[@]}"}"
