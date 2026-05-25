# ==============================================================================
# Bash completion for gituser and gitclone
# Install: copy to ~/.local/share/bash-completion/completions/gituser
# The install.sh script handles this automatically.
# ==============================================================================

_gituser_profile_names() {
    local config="${GIT_PROFILES:-$HOME/.git-profiles}"
    [[ -f "$config" ]] || return
    grep '^\[' "$config" 2>/dev/null | tr -d '[]'
}

_gituser_complete() {
    local cur="${COMP_WORDS[COMP_CWORD]}"
    local prev="${COMP_WORDS[COMP_CWORD-1]}"
    local subcmd="${COMP_WORDS[1]:-}"

    local all_commands="init status current list use add edit rename remove clone doctor version help"

    if [[ $COMP_CWORD -eq 1 ]]; then
        COMPREPLY=($(compgen -W "$all_commands" -- "$cur"))
        return
    fi

    local profiles
    profiles=$(_gituser_profile_names)

    case "$subcmd" in
        use)
            if [[ $COMP_CWORD -eq 2 ]]; then
                COMPREPLY=($(compgen -W "$profiles" -- "$cur"))
            elif [[ $COMP_CWORD -eq 3 ]]; then
                COMPREPLY=($(compgen -W "--global" -- "$cur"))
            fi
            ;;
        edit|remove)
            if [[ $COMP_CWORD -eq 2 ]]; then
                COMPREPLY=($(compgen -W "$profiles" -- "$cur"))
            fi
            ;;
        rename)
            if [[ $COMP_CWORD -le 3 ]]; then
                COMPREPLY=($(compgen -W "$profiles" -- "$cur"))
            fi
            ;;
        clone)
            if [[ "$prev" == "--as" ]]; then
                COMPREPLY=($(compgen -W "$profiles" -- "$cur"))
            elif [[ $COMP_CWORD -ge 3 ]]; then
                COMPREPLY=($(compgen -W "--as" -- "$cur"))
            fi
            ;;
    esac
}

complete -F _gituser_complete gituser
# gitclone delegates entirely to 'gituser clone', so reuse the same completion
complete -F _gituser_complete gitclone
