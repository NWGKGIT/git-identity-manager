#!/usr/bin/env bash
# ==============================================================================
# install.sh - Local installer for git-identity-manager
# Run this after cloning the repository.
#
# Usage:
#   ./install.sh            Install to ~/.local/bin (no sudo required)
#   ./install.sh --system   Install to /usr/local/bin (requires sudo)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
INSTALL_DIR="$HOME/.local/bin"
CONFIG_FILE="$HOME/.git-profiles"

# ------------------------------------------------------------------------------
# Parse flags
# ------------------------------------------------------------------------------

SYSTEM_INSTALL=false
for arg in "$@"; do
    case "$arg" in
        --system) SYSTEM_INSTALL=true ;;
        --help|-h)
            echo "Usage: ./install.sh [--system]"
            echo ""
            echo "  --system   Install to /usr/local/bin (requires sudo)"
            echo "             Default: install to ~/.local/bin"
            exit 0
            ;;
    esac
done

if $SYSTEM_INSTALL; then
    INSTALL_DIR="/usr/local/bin"
fi

# ------------------------------------------------------------------------------
# Helpers
# ------------------------------------------------------------------------------

step()  { printf '\n[+] %s\n' "$*"; }
info()  { printf '    %s\n' "$*"; }
ok()    { printf '    ok: %s\n' "$*"; }
err()   { printf '    error: %s\n' "$*" >&2; }
die()   { err "$*"; exit 1; }

# ------------------------------------------------------------------------------
# Preflight checks
# ------------------------------------------------------------------------------

step "Checking dependencies"

command -v git &>/dev/null || die "git is not installed. Please install git first."
ok "git found: $(git --version)"

if $SYSTEM_INSTALL && [[ "$EUID" -ne 0 ]]; then
    die "--system install requires root. Re-run with sudo."
fi

# ------------------------------------------------------------------------------
# Install binaries
# ------------------------------------------------------------------------------

step "Installing binaries to $INSTALL_DIR"

mkdir -p "$INSTALL_DIR"

install -m 755 "$SCRIPT_DIR/gituser"  "$INSTALL_DIR/gituser"
ok "gituser  -> $INSTALL_DIR/gituser"

install -m 755 "$SCRIPT_DIR/gitclone" "$INSTALL_DIR/gitclone"
ok "gitclone -> $INSTALL_DIR/gitclone"

# ------------------------------------------------------------------------------
# Ensure INSTALL_DIR is in PATH (user installs only)
# ------------------------------------------------------------------------------

if [[ "$INSTALL_DIR" == "$HOME/.local/bin" ]]; then
    step "Checking PATH"

    _add_path_line() {
        local rc_file="$1"
        local line='export PATH="$HOME/.local/bin:$PATH"'
        if [[ -f "$rc_file" ]] && ! grep -q '.local/bin' "$rc_file"; then
            printf '\n# Added by git-identity-manager installer\n%s\n' "$line" >> "$rc_file"
            ok "Added ~/.local/bin to PATH in $rc_file"
        elif [[ -f "$rc_file" ]]; then
            info "$rc_file already includes ~/.local/bin"
        fi
    }

    _add_path_line "$HOME/.bashrc"
    _add_path_line "$HOME/.zshrc"
fi

# ------------------------------------------------------------------------------
# Install shell completions
# ------------------------------------------------------------------------------

step "Installing shell completions"

# Zsh
if command -v zsh &>/dev/null; then
    ZSH_COMP_DIR="${ZDOTDIR:-$HOME}/.zsh/completions"
    mkdir -p "$ZSH_COMP_DIR"
    install -m 644 "$SCRIPT_DIR/completions/_gituser" "$ZSH_COMP_DIR/_gituser"
    ok "Zsh completion -> $ZSH_COMP_DIR/_gituser"

    # Add completions dir to fpath if not already present
    ZSHRC="${ZDOTDIR:-$HOME}/.zshrc"
    if [[ -f "$ZSHRC" ]] && ! grep -q 'git-identity-manager completions' "$ZSHRC"; then
        {
            printf '\n# git-identity-manager completions\n'
            printf 'fpath=("%s" $fpath)\n' "$ZSH_COMP_DIR"
            printf 'autoload -Uz compinit && compinit\n'
        } >> "$ZSHRC"
        ok "Added fpath entry to $ZSHRC"
    fi
else
    info "zsh not found, skipping zsh completions"
fi

# Bash
BASH_COMP_DIR="$HOME/.local/share/bash-completion/completions"
mkdir -p "$BASH_COMP_DIR"
install -m 644 "$SCRIPT_DIR/completions/gituser.bash" "$BASH_COMP_DIR/gituser"
ok "Bash completion -> $BASH_COMP_DIR/gituser"

# ------------------------------------------------------------------------------
# Legacy config migration
# ------------------------------------------------------------------------------

step "Checking config file"

if [[ -f "$CONFIG_FILE" ]] && grep -q ":" "$CONFIG_FILE" && ! grep -q '^\[' "$CONFIG_FILE" 2>/dev/null; then
    info "Legacy colon-separated format detected. Migrating..."
    _migrate_tmpfile=$(mktemp)
    while IFS=':' read -r _lprofile _lname _lemail _lssh; do
        [[ -z "$_lprofile" || "$_lprofile" == \#* ]] && continue
        printf '[%s]\nname = %s\nemail = %s\n' "$_lprofile" "$_lname" "$_lemail" >> "$_migrate_tmpfile"
        [[ -n "$_lssh" ]] && printf 'ssh_key = %s\n' "$_lssh" >> "$_migrate_tmpfile"
    done < "$CONFIG_FILE"
    cp "$CONFIG_FILE" "${CONFIG_FILE}.bak"
    mv "$_migrate_tmpfile" "$CONFIG_FILE"
    ok "Migration complete. Backup saved to ${CONFIG_FILE}.bak"
elif [[ ! -f "$CONFIG_FILE" ]]; then
    touch "$CONFIG_FILE"
    ok "Created $CONFIG_FILE"
else
    ok "$CONFIG_FILE already exists"
fi

# ------------------------------------------------------------------------------
# Done
# ------------------------------------------------------------------------------

printf '\n%s\n' "========================================"
printf '%s\n'   " Installation complete."
printf '%s\n'   "========================================"
echo ""
echo "Restart your terminal, or run one of:"
echo ""
echo "  source ~/.bashrc"
echo "  source ~/.zshrc"
echo ""
echo "Then run 'gituser init' to create your first profile."
echo ""