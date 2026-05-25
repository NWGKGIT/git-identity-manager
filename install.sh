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
# Install prompt integration
# ------------------------------------------------------------------------------

step "Configuring shell prompts"

_add_prompt_integration() {
    local rc_file="$1"
    local shell_type="$2"
    
    if [[ -f "$rc_file" ]]; then
        if grep -q 'gituser current' "$rc_file"; then
            info "Prompt integration already exists in $rc_file"
        else
            printf '\n# git-identity-manager prompt integration\n' >> "$rc_file"
            if [[ "$shell_type" == "zsh" ]]; then
                cat << 'EOF' >> "$rc_file"
setopt prompt_subst 2>/dev/null || true
# Intelligently inject before the last newline if the prompt is multi-line
if [[ "$PROMPT" == *$'\n'* ]]; then
  PROMPT="${PROMPT%$'\n'*}\$(gituser current)"$'\n'"${PROMPT##*$'\n'}"
elif [[ "$PROMPT" == *'\n'* ]]; then
  PROMPT="${PROMPT%\\n*}\$(gituser current)\n${PROMPT##*\\n}"
else
  PROMPT="${PROMPT}\$(gituser current)"
fi
EOF
            elif [[ "$shell_type" == "bash" ]]; then
                cat << 'EOF' >> "$rc_file"
# Intelligently inject before the last newline if the prompt is multi-line
if [[ "$PS1" == *$'\n'* ]]; then
  PS1="${PS1%$'\n'*}\$(gituser current)"$'\n'"${PS1##*$'\n'}"
elif [[ "$PS1" == *'\n'* ]]; then
  PS1="${PS1%\\n*}\$(gituser current)\n${PS1##*\\n}"
else
  PS1="${PS1}\$(gituser current)"
fi
EOF
            fi
            ok "Added smart prompt integration to $rc_file"
        fi
    fi
}

_add_prompt_integration "$HOME/.bashrc" "bash"
_add_prompt_integration "$HOME/.zshrc" "zsh"

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