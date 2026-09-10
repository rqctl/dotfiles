## ----- Global -----

alias -g -- --help='--help 2>&1 | bat --language=help --style=plain'
alias -g XSC="| xclip -sel c" # On MacOS, swap xclip for pbcopy.
alias -g SCB="SKIP=commitizen-branch"

## ----- Tools -----

alias cat='bat -pp'
alias k='kubectl'
alias tf='terraform'
alias tg='terragrunt'
alias td='mise run terradrift'
alias mr='mise run'
alias k9S='k9s'
alias cm='chezmoi'
alias sk='sofka'

## ----- Cleaning -----

alias dockerrm='docker container prune -f'

## ----- Sudo -----

alias apt='sudo apt'
alias apt-get='sudo apt-get'
alias shn='sudo systemctl poweroff'
alias systemctl='sudo systemctl'
alias rmrf='rm -rf'
alias srm='sudo rm'
vi() {
    if [[ $1 == "/etc/"* ]]; then
        sudo vim "$@"
    else
        vim "$@"
    fi
}

## -----  System Upgrade  -----

# Section header used by upgrade's steps below.
_upgrade_step() {
    print -P "\n%F{cyan}==> $1%f"
}

_upgrade_apt() {
    _upgrade_step "APT: upgrade"
    apt update
    command apt list --upgradable 2>/dev/null
    apt upgrade -y

    _upgrade_step "APT: clean"
    apt autoremove -y
    apt-get clean
}

_upgrade_mise() {
    _upgrade_step "MISE: upgrade"
    mise self-update
    # GITLAB_TOKEN prevent glab cli upgrade
    env -u GITLAB_TOKEN mise up --bump -i

    # mise up installs new versions but leaves this shell's PATH on the old
    # install dirs, so everything below would run the pre-upgrade binaries.
    eval "$(mise hook-env -f -s zsh)"
    mise prune -y
}

_upgrade_omz() {
    _upgrade_step "OMZ: upgrade"
    omz update
}

_upgrade_gcloud() {
    _upgrade_step "GCLOUD: python packages"
    local gcloud_python
    gcloud_python=$(gcloud info --format="value(basic.python_location)")
    if [[ -x "$gcloud_python" ]]; then
        "$gcloud_python" -m pip install --upgrade pip numpy
    else
        print -P "%F{yellow}Skipped: gcloud reported no usable python (got '${gcloud_python:-nothing}').%f"
    fi

    _upgrade_step "GCLOUD: components"
    gcloud components update
}

# Usage: upgrade
# — apt, mise, omz, gcloud, in that order.
upgrade() {
    local orig_dir="$PWD"
    # -n never prompts, so a broken sudo fails here rather than ten minutes in.
    # `sudo -v` would prompt even with NOPASSWD: it validates the user, and the
    # plain "(ALL : ALL) ALL" rule wants a password.
    sudo -n true 2>/dev/null || { print -P "%F{red}sudo needs a password — check your NOPASSWD rule.%f"; return 1; }

    cd || return 1

    _upgrade_apt
    _upgrade_mise
    _upgrade_omz
    _upgrade_gcloud

    source "$HOME/.zshrc.custom"
    cd "$orig_dir"

    print -P "\n%F{green}==> Upgrade complete%f"
}



## -----  Certificates  -----

alias x509l="openssl x509 -noout -text -in"

# Usage: x509s <cert.pem>
# Print only useful information from a certificate
x509s() {
    [[ -r "$1" ]] || { echo "Usage: x509s <cert.pem>"; return 1; }
    local text sep=$(printf '#%.0s' {1..98})
    text=$(openssl x509 -noout -text -in "$1") || return 1

    echo "$sep"
    openssl x509 -noout -sha256 -pubkey -in "$1" \
        | openssl pkey -pubin -outform der \
        | openssl dgst -sha256 \
        | awk '{print "sha256 Public Key:\n    " $2}'
    openssl x509 -noout -fingerprint -sha256 -inform pem -in "$1" \
        | sed "s/=/:\n    /"
    openssl x509 -noout -fingerprint -sha1 -inform pem -in "$1" \
        | sed "s/=/:\n    /"
    print -r -- "$text" \
        | grep -B7 "Subject:" \
        | grep -v "Signature Algorithm:" \
        | sed "s@^[[:blank:]]\{8\}@@"
    print -r -- "$text" | grep -A1 "Alternative Name" --color=never
    echo "$sep"
}
