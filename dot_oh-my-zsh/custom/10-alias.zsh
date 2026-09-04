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

# TODO/clean code and output

# Usage: upgrade
# — apt, mise, omz, gcloud, in that order.
upgrade() {
    local orig_dir="$PWD"
    # -n never prompts, so a broken sudo fails here rather than ten minutes in.
    # `sudo -v` would prompt even with NOPASSWD: it validates the user, and the
    # plain "(ALL : ALL) ALL" rule wants a password.
    sudo -n true 2>/dev/null || { echo "sudo needs a password — check your NOPASSWD rule."; return 1; }

    echo -e "\n### Reset working dir\n"
    cd || return 1

    echo -e "\n### APT upgrade tasks\n"
    apt update
    command apt list --upgradable 2>/dev/null
    apt upgrade -y

    echo -e "\n### APT cleaning tasks\n"
    apt autoremove -y
    apt-get clean


    echo -e "\n### MISE upgrade\n"
    mise self-update
    # GITLAB_TOKEN prevent glab cli upgrade
    env -u GITLAB_TOKEN mise up --bump -i

    # mise up installs new versions but leaves this shell's PATH on the old
    # install dirs, so everything below would run the pre-upgrade binaries.
    eval "$(mise hook-env -f -s zsh)"

    echo -e "\n### OMZ upgrade\n"
    omz update

    echo -e "\n### GCLOUD install python packages\n"
    local gcloud_python
    gcloud_python=$(gcloud info --format="value(basic.python_location)")
    if [[ -x "$gcloud_python" ]]; then
        "$gcloud_python" -m pip install --upgrade pip numpy
    else
        echo "Skipped: gcloud reported no usable python (got '${gcloud_python:-nothing}')."
    fi

    echo -e "\n### GCLOUD components upgrade\n"
    gcloud components update

    source "$HOME/.zshrc.custom"
    cd "$orig_dir"
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
