#!/usr/bin/env bash
set -euo pipefail

if (( EUID == 0 )); then
    printf '%s\n' "Lance l’installateur avec ton compte utilisateur. Il utilisera sudo pour les paquets." >&2
    exit 1
fi

. /etc/os-release
case " ${ID:-} ${ID_LIKE:-} " in
    *" debian "*|*" ubuntu "*) manager=apt; git_package=git ;;
    *" fedora "*|*" rhel "*|*" centos "*) manager=dnf; git_package=git-core ;;
    *) printf 'Distribution inconnue : %s\n' "${ID:-?}" >&2; exit 1 ;;
esac

install_packages() {
    if [[ "$manager" == apt ]]; then
        sudo apt-get install "$@"
    else
        sudo dnf install "$@"
    fi
}

eza_compatible() {
    "$1" -ld --icons=always --header --color=auto --classify=always --git --git-repos . >/dev/null 2>&1
}

install_upstream_eza() (
    case "$(uname -m)" in
        x86_64)
            archive=eza_x86_64-unknown-linux-musl.tar.gz
            checksum=e06eebab74b73d6b7d51a796a353824b001bea82df077706382e100815d28904 ;;
        aarch64)
            archive=eza_aarch64-unknown-linux-gnu.tar.gz
            checksum=40b87ae8628aa2ff0f0d2dc24ab52f689631366385c3da630bae745671fd71ec ;;
        *)
            printf '%s\n' "Installe une version récente d’eza pour cette architecture, puis relance." >&2
            exit 1 ;;
    esac

    command -v curl >/dev/null 2>&1 || install_packages curl
    tmp=$(mktemp -d)
    trap 'rm -rf -- "$tmp"' EXIT
    curl --fail --silent --show-error --location \
        "https://github.com/eza-community/eza/releases/download/v0.23.5/$archive" \
        --output "$tmp/$archive"
    printf '%s  %s\n' "$checksum" "$tmp/$archive" | sha256sum --check --status
    tar -xzf "$tmp/$archive" -C "$tmp"
    eza_compatible "$tmp/eza" || {
        printf '%s\n' "Le binaire eza téléchargé ne fonctionne pas sur ce système." >&2
        exit 1
    }
    install -d "$HOME/.local/bin"
    install -m 755 "$tmp/eza" "$HOME/.local/bin/eza"
)

packages=()
command -v fzf >/dev/null 2>&1 || packages+=(fzf)
command -v git >/dev/null 2>&1 || packages+=("$git_package")
if [[ "$manager" == apt ]] &&
   { (( ${#packages[@]} > 0 )) || ! command -v eza >/dev/null 2>&1; }; then
    sudo apt-get update
fi
if (( ${#packages[@]} > 0 )); then
    install_packages "${packages[@]}"
fi

local_eza=false
if eza_compatible "$HOME/.local/bin/eza"; then
    local_eza=true
elif ! eza_compatible eza; then
    if ! command -v eza >/dev/null 2>&1; then
        install_packages eza || printf '%s\n' "Paquet eza indisponible. Essai de la version officielle." >&2
    fi
    if ! eza_compatible eza; then
        install_upstream_eza
        local_eza=true
    fi
fi

config_dir="$HOME/.bashrc.d"
mkdir -p "$config_dir"

write_config() {
    local path="$1" content
    content=$(cat)
    if [[ -f "$path" ]]; then
        if cmp -s "$path" <(printf '%s\n' "$content"); then
            return
        fi
        local backup
        backup=$(mktemp "${TMPDIR:-/tmp}/${path##*/}.backup.XXXXXX")
        cp -- "$path" "$backup"
        printf 'Sauvegarde : %s\n' "$backup"
    fi
    printf '%s\n' "$content" > "$path"
}

{
    if [[ "$local_eza" == true ]]; then
        printf '%s\n' 'PATH="$HOME/.local/bin:$PATH"'
    fi
    cat <<'CONFIG'
if command -v eza >/dev/null 2>&1; then
    alias ls='eza -l --icons=always --header --color=auto --classify=always --git --git-repos'
    alias ll='eza -l --icons=always --header --color=auto --classify=always --git --git-repos'
fi
CONFIG
} | write_config "$config_dir/eza.sh"

write_config "$config_dir/fzf-history.sh" <<'CONFIG'
if [[ $- == *i* ]] && command -v fzf >/dev/null 2>&1; then
    if fzf_bash=$(fzf --bash 2>/dev/null); then
        FZF_CTRL_T_COMMAND= FZF_ALT_C_COMMAND= eval "$fzf_bash"
    else
        for fzf_bindings in /usr/share/doc/fzf/examples/key-bindings.bash /usr/share/fzf/key-bindings.bash; do
            if [[ -r "$fzf_bindings" ]]; then
                . "$fzf_bindings"
                break
            fi
        done
    fi
    unset fzf_bash fzf_bindings
fi
CONFIG

write_config "$config_dir/git-prompt.sh" <<'CONFIG'
if [[ $- == *i* ]]; then
    for git_prompt in /usr/share/git-core/contrib/completion/git-prompt.sh \
                      /usr/lib/git-core/git-sh-prompt /etc/bash_completion.d/git-prompt; do
        if [[ -r "$git_prompt" ]] && . "$git_prompt" && declare -F __git_ps1 >/dev/null; then
            break
        fi
    done
    unset git_prompt

    PS1='\[\e[90m\]╭─\[\e[0m\] \[\e[36m\]\u@\h\[\e[0m\]  \[\e[1;34m\]\w\[\e[0m\]'
    if declare -F __git_ps1 >/dev/null; then
        PS1+='\[\e[33m\]$(__git_ps1 "  [git:%s]")\[\e[0m\]'
    fi
    PS1+='\n\[\e[90m\]╰─\[\e[1;32m\]❯\[\e[0m\] '
fi
CONFIG

if ! grep -Fq '~/.bashrc.d/*' "$HOME/.bashrc" 2>/dev/null &&
   ! grep -Fq '# terminal-fedora' "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" <<'CONFIG'

# terminal-fedora
[ ! -r "$HOME/.bashrc.d/eza.sh" ] || . "$HOME/.bashrc.d/eza.sh"
[ ! -r "$HOME/.bashrc.d/fzf-history.sh" ] || . "$HOME/.bashrc.d/fzf-history.sh"
CONFIG
fi

if ! grep -Fq '~/.bashrc.d/*' "$HOME/.bashrc" 2>/dev/null &&
   ! grep -Fq '.bashrc.d/git-prompt.sh' "$HOME/.bashrc" 2>/dev/null; then
    cat >> "$HOME/.bashrc" <<'CONFIG'
[ ! -r "$HOME/.bashrc.d/git-prompt.sh" ] || . "$HOME/.bashrc.d/git-prompt.sh"
CONFIG
fi

printf '%s\n' 'Ouvre un nouveau terminal Bash, puis essaie ls et Ctrl+R.'
