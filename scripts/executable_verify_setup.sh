#!/bin/bash
# Verifies a restore and lists what the setup does. Usage: verify_setup.sh [--backup]
# (--backup: an archive was restored). The lists are read from setup_fresh_install.sh.
# shellcheck disable=SC2016,SC2088  # check strings are eval'd; "~" in labels is plain text
set -u

SETUP="$HOME/scripts/setup_fresh_install.sh"
[ -f "$SETUP" ] || { echo "Missing $SETUP (run chezmoi apply)" >&2; exit 1; }

SKIP=1
[ "${1:-}" = "--backup" ] && SKIP=0

if [ -t 1 ] && [ -z "${NO_COLOR:-}" ]; then
    G=$'\e[32m' R=$'\e[31m' D=$'\e[2m' B=$'\e[1;34m' N=$'\e[0m'
else
    G='' R='' D='' B='' N=''
fi
bad=0

for arr in APT_PACKAGES VSCODE_EXTENSIONS GNOME_EXTENSIONS GSETTINGS; do
    eval "$(sed -n "/^$arr=(/,/^)/p" "$SETUP")"
done

section() { printf '\n%s== %s%s\n' "$B" "$1" "$N"; }
sub() { printf '%s-- %s%s\n' "$D" "$1" "$N"; }

# mark <rc>: sets M (not in a subshell, so failures are counted).
mark() {
    if [ "$1" = 0 ]; then M="${G}✓${N}"; else M="${R}✗${N}"; bad=$((bad + 1)); fi
}

# chk <label> <shell condition>; for archive items, SKIP=1 prints the item unchecked.
chk() {
    if [ "$ARCHIVE" = 1 ] && [ "$SKIP" = 1 ]; then M="${D}·${N}"; else eval "$2" >/dev/null 2>&1; mark $?; fi
    printf ' %s %s\n' "$M" "$1"
}

# chk_list <label> <test function> <items...>; DISP, when set, replaces the shown names.
chk_list() {
    local label=$1 fn=$2 i missing=()
    shift 2
    if [ "$ARCHIVE" = 1 ] && [ "$SKIP" = 1 ]; then M="${D}·${N}"; else
        for i in "$@"; do "$fn" "$i" >/dev/null 2>&1 || missing+=("$i"); done
        if [ ${#missing[@]} -eq 0 ]; then mark 0; else mark 1; fi
    fi
    printf ' %s %s (%d)\n' "$M" "$label" "$#"
    [ ${#DISP[@]} -gt 0 ] && set -- "${DISP[@]}"
    printf '%s' "$D"; printf '%s ' "$@" | fold -s -w 96 | sed 's/^/     /'; printf '%s\n' "$N"
    [ ${#missing[@]} -gt 0 ] && printf '     %smissing: %s%s\n' "$R" "${missing[*]}" "$N"
    DISP=()
    return 0
}
DISP=()

has_pkg() { dpkg-query -W -f='${db:Status-Abbrev}' "$1" | grep -q '^ii'; }
has_dir() { [ -d "$1" ]; }
has_file() { [ -e "$1" ]; }
has_gext() { [ -d "$HOME/.local/share/gnome-shell/extensions/$1" ] || [ -d "/usr/share/gnome-shell/extensions/$1" ]; }
has_repo() { [ -f "/etc/apt/sources.list.d/$1" ]; }
has_cmd() { command -v "$1"; }
has_vscode() { printf '%s\n' "$CODE_EXTS" | grep -qix "$1"; }
has_group() { getent group "${1%%:*}" | grep -qw "$USER"; }
has_omz() { [ -d "$HOME/.oh-my-zsh/custom/plugins/$1" ]; }
# "schema key value"; lists compare as sets, as gsettings may reorder them.
has_gsetting() {
    local schema key value cur
    read -r schema key value <<< "$1"
    cur=$(gsettings get "$schema" "$key" | sed -e 's/^@[a-z]* //' -e 's/^uint32 //')
    # Doubles print with float noise (0.8 -> 0.80000000000000004): compare numerically.
    if [[ "$cur" =~ ^[0-9.]+$ && "$value" =~ ^[0-9.]+$ ]]; then
        awk -v a="$cur" -v b="$value" 'BEGIN { exit !(a - b < 1e-9 && b - a < 1e-9) }'
        return
    fi
    [ "$(tr -d ' []' <<< "$cur" | tr ',' '\n' | sort)" = "$(tr -d ' []' <<< "$value" | tr ',' '\n' | sort)" ]
}

ARCHIVE=1
section "Archive restore (pc-backup, only checked with --backup)"
[ "$SKIP" = 1 ] && printf '%s   not checked: no --backup (·)%s\n' "$D" "$N"
sub "secrets"
chk "SSH keys, ~/.ssh is 700 and private keys 600" \
    '[ "$(stat -c %a ~/.ssh)" = 700 ] && ! find ~/.ssh -name "id_*" ! -name "*.pub" -perm /077 | grep -q .'
chk "GPG secret keys imported; export dir removed" \
    'gpg -K | grep -q "^sec" && [ ! -e ~/.gnupg-export ]'
chk "Wi-Fi passwords (netplan files + NetworkManager); export dir removed" \
    'sudo -n ls /etc/netplan/90-NM-*.yaml && nmcli -t -f TYPE connection show | grep -q wireless && [ ! -e ~/.nm-export ]'
chk "~/.config/chezmoi/chezmoi.toml and ~/.zshrc.local" \
    '[ -f ~/.config/chezmoi/chezmoi.toml ] && [ -f ~/.zshrc.local ]'
chk "kubeconfigs (~/.kube) and ~/.aws/config" '[ -f ~/.kube/config ] && [ -f ~/.aws/config ]'
chk "~/.mcp.json" 'has_file ~/.mcp.json'
chk "FileZilla saved sites (~/.config/filezilla)" 'has_file ~/.config/filezilla/sitemanager.xml'
sub "history, profile and memory"
chk "zsh history" '[ -s ~/.zsh_history ]'
chk "Firefox profile (~/.config/mozilla)" 'ls -d ~/.config/mozilla/firefox/*.default* '
chk "Claude memories (~/.claude/projects/*/memory)" 'ls -d ~/.claude/projects/*/memory'
sub "personal files"
chk "~/scripts, ~/vscode" 'has_dir ~/scripts && has_dir ~/vscode'
chk "Desktop Documents Music Notes Pictures Videos" \
    'for d in Desktop Documents Music Notes Pictures Videos; do [ -d ~/$d ] || exit 1; done'

ARCHIVE=0
section "Setup script (setup_fresh_install.sh)"

sub "system"
chk "passwordless sudo (/etc/sudoers.d/$USER)" 'sudo -n true && [ -f /etc/sudoers.d/$USER ]'
chk "default shell is zsh" 'getent passwd $USER | grep -q zsh'
chk "locale: English, week starts Monday (LC_TIME=en_GB.UTF-8)" 'localectl status | grep -q LC_TIME=en_GB.UTF-8'
chk "groups docker and wireshark (wireshark capture without root)" 'has_group docker && has_group wireshark'
chk "fingerprint login: fprintd and its PAM module (enrolling is manual)" 'has_pkg fprintd && has_pkg libpam-fprintd'

sub "packages"
chk_list "apt packages" has_pkg "${APT_PACKAGES[@]}"
chk_list "apt packages added from other repos" has_pkg spotify-client firefox cloudflare-warp code \
    slack-desktop 1password docker-ce docker-ce-cli containerd.io docker-buildx-plugin \
    docker-compose-plugin displaylink-driver fprintd libpam-fprintd
chk_list "apt repos added" has_repo spotify.list mozilla.list cloudflare-client.list slack.list \
    1password.list docker.list synaptics.list
chk "Firefox: Mozilla repo wins, Ubuntu's snap package blocked" \
    '[ -f /etc/apt/preferences.d/firefox-deb-nosnap ] && ! snap list firefox'
CODE_EXTS=$(code --list-extensions 2>/dev/null)
chk_list "VS Code extensions" has_vscode "${VSCODE_EXTENSIONS[@]}"
chk_list "standalone binaries" has_cmd docker-credential-gcr vault-token-helper claude mise
chk "vault-token-helper is the fork with 'list -e', wired in ~/.vault" \
    'vault-token-helper list --help | grep -q extended && grep -q vault-token-helper ~/.vault'

sub "networking"
chk "Docker daemon: bridge 10.200.0.1/24 and address pools (/etc/docker/daemon.json)" 'grep -q 10.200.0.1/24 /etc/docker/daemon.json'
chk "Docker registry login helper for europe-docker.pkg.dev" 'grep -q europe-docker.pkg.dev ~/.docker/config.json'
chk "/etc/hosts: metadata.google.internal -> 127.0.0.1" 'grep -q "^127.0.0.1 metadata.google.internal" /etc/hosts'
chk "DNS: ~cloudproxy.app resolved via 8.8.8.8" 'grep -q "^Domains=~cloudproxy.app" /etc/systemd/resolved.conf.d/cloudproxy.conf'
chk "Wi-Fi power saving off (wifi.powersave is not 3)" \
    '! grep -qP "^\s*wifi\.powersave\s*=\s*3" /etc/NetworkManager/conf.d/default-wifi-powersave-on.conf'
chk "Cloudflare WARP installed and registered (when an org is configured)" \
    'o=$(chezmoi execute-template "{{ .org.vpnOrg }}"); [ -z "$o" ] || warp-cli registration show'
chk "DisplayLink kernel module loaded (needs Secure Boot key enrolled)" 'lsmod | grep -q evdi'

sub "shell and tools"
chk "oh-my-zsh and powerlevel10k" 'has_dir ~/.oh-my-zsh/themes/powerlevel10k'
chk_list "oh-my-zsh plugins" has_omz \
    you-should-use zsh-autosuggestions zsh-history-substring-search zsh-syntax-highlighting
chk "mise: every tool in ~/.config/mise/config.toml installed" '! GITLAB_TOKEN= mise ls --missing | grep -q .'
chk "gcloud components and python default packages (mise hooks)" \
    'has_cmd gke-gcloud-auth-plugin && python -c "import boto3, hvac, gitlab"'

sub "dotfiles"
chk "chezmoi source is a git clone with an SSH origin" \
    'git -C ~/.local/share/chezmoi remote get-url origin | grep -q "^git@"'
chk "chezmoi: home matches the repo (chezmoi verify)" 'chezmoi verify'
chk "pre-commit hooks installed in the chezmoi repo (prek)" 'has_file ~/.local/share/chezmoi/.git/hooks/pre-commit'

sub "desktop (GNOME)"
chk_list "GNOME extensions" has_gext "${GNOME_EXTENSIONS[@]}"
for s in "${GSETTINGS[@]}"; do read -r _ k v <<< "$s"; DISP+=("$k=$v"); done
chk_list "GNOME settings" has_gsetting "${GSETTINGS[@]}"
chk "wallpaper slideshow folder (azwallpaper)" \
    '[ "$(dconf read /org/gnome/shell/extensions/azwallpaper/slideshow-directory)" = "'"'$HOME/Pictures/Slideshow'"'" ]'

echo
if [ "$bad" -eq 0 ]; then printf '%sAll checks passed.%s\n' "$G" "$N"; else printf '%s%d check(s) failed.%s\n' "$R" "$bad" "$N"; exit 1; fi
