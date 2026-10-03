#!/bin/bash
# New-machine bootstrap: system packages, oh-my-zsh, dotfiles, mise tools.
# Needs ~/.config/chezmoi/chezmoi.toml restored first (see README). Safe to re-run.
# chezmoi owns the config file contents: never write a managed file from here.
set -euo pipefail

export DEBIAN_FRONTEND=noninteractive

# Define color variables
BLUE='\033[1;34m'
GREEN='\033[1;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

USERNAME="$(whoami)"
DOCKER_CONFIG_FILE="$HOME/.docker/config.json"
REGISTRY="europe-docker.pkg.dev"

log() {
    local color="$1"
    local msg="$2"
    echo -e "${color}${msg}${NC}"
}

if [ ! -f "$HOME/.config/chezmoi/chezmoi.toml" ]; then
    echo "Restore ~/.config/chezmoi/chezmoi.toml first (template: docs/chezmoi.toml.example)." >&2
    exit 1
fi

# Prime sudo credentials once upfront to avoid mid-script password prompts.
# Not `sudo -v`: it asks for a password while any matching rule needs one (the
# sudo group does), even after the NOPASSWD file below exists.
sudo true

# Configure passwordless sudo for the current user
if [ ! -f "/etc/sudoers.d/$USERNAME" ]; then
    log "$BLUE" "➔ Configuring passwordless sudo for $USERNAME..."
    echo "$USERNAME ALL=(ALL) NOPASSWD: ALL" | sudo tee "/etc/sudoers.d/$USERNAME" > /dev/null
    sudo chmod 440 "/etc/sudoers.d/$USERNAME"
    log "$GREEN" "✅ Passwordless sudo configured for $USERNAME."
fi

# List of apt packages to install
APT_PACKAGES=(
    bd                      # jump back to a parent directory
    build-essential         # essential compilation tools
    ca-certificates         # SSL certificates
    dconf-editor            # GNOME settings browser
    filezilla               # FTP/SFTP client
    ghostty                 # GPU-accelerated terminal emulator
    git                     # version control system
    gnome-shell-extensions  # GNOME desktop extensions
    gnome-video-trimmer     # trim videos without re-encoding
    htop                    # interactive process viewer
    iftop                   # bandwidth usage per connection
    inotify-tools           # watch files for changes
    ksnip
    lftp                    # scriptable FTP/SFTP client
    libffi-dev              # shared library for language bindings
    libyaml-dev             # YAML parser library headers
    locate                  # fast file search utility
    mtr                     # traceroute + ping
    ncdu                    # NCurses disk usage analyzer
    net-tools               # ifconfig, netstat, route
    ngrep                   # grep for network packets
    parallel
    pigz                    # parallel gzip compression
    read-edid               # monitor EDID information
    shellcheck              # shell script static analysis
    tcptraceroute           # traceroute over TCP
    tig                     # text-mode interface for git
    tree                    # recursive directory listing
    tshark                  # Wireshark command line
    vim                     # text editor
    wget                    # network downloader
    wireshark               # packet analyzer
    wl-clipboard            # Wayland clipboard (wl-copy, wl-paste)
    xclip                   # clipboard command-line utility
    whois
    zlib1g-dev              # compression library headers
    zsh                     # Z shell
)

# VS Code extensions (installing one already there is a no-op)
VSCODE_EXTENSIONS=(
    anthropic.claude-code
    chrislajoie.vscode-modelines
    davidanson.vscode-markdownlint
    eamodio.gitlens
    esbenp.prettier-vscode
    gitlab.gitlab-workflow
    golang.go
    hverlin.mise-vscode
    jinliming2.vscode-go-template
    karunamurti.tera
    matheusq94.tfs
    ms-kubernetes-tools.vscode-kubernetes-tools
    ms-python.debugpy
    ms-python.python
    ms-python.vscode-pylance
    ms-python.vscode-python-envs
    oderwat.indent-rainbow
    pascalreitermann93.vscode-yaml-sort
    pjmiravalle.terraform-advanced-syntax-highlighting
    redhat.ansible
    redhat.vscode-xml
    redhat.vscode-yaml
    richie5um2.vscode-sort-json
    ryu1kn.partial-diff
    tamasfe.even-better-toml
    tekumara.typos-vscode
    tim-koehler.helm-intellisense
    timonwong.shellcheck
    xshrim.txt-syntax
)

# GNOME extensions from extensions.gnome.org
GNOME_EXTENSIONS=(
    azwallpaper@azwallpaper.gitlab.com            # wallpaper slideshow
    steal-my-focus-window@steal-my-focus-window   # focus new windows instead of "is ready"
    unblank@sun.wxg@gmail.com                     # keep the lock screen from blanking
)

# GNOME settings: "schema key value" (re-applying is a no-op)
GSETTINGS=(
    "org.gnome.desktop.interface gtk-enable-primary-paste true"
    "org.gnome.desktop.interface color-scheme 'prefer-dark'"
    "org.gnome.desktop.interface gtk-theme 'Yaru-dark'"
    "org.gnome.desktop.interface icon-theme 'Yaru-dark'"
    "org.gnome.desktop.interface clock-show-weekday true"
    "org.gnome.mutter edge-tiling false"
    "org.gnome.mutter workspaces-only-on-primary false"
    "org.gnome.mutter.keybindings toggle-tiled-left []"
    "org.gnome.mutter.keybindings toggle-tiled-right []"
    "org.gnome.shell favorite-apps ['firefox.desktop', 'com.mitchellh.ghostty.desktop', 'com.microsoft.VSCode.desktop', 'spotify.desktop', 'slack.desktop']"
    "org.gnome.shell enabled-extensions ['ding@rastersoft.com', 'ubuntu-dock@ubuntu.com', 'tiling-assistant@ubuntu.com', 'ubuntu-appindicators@ubuntu.com', 'azwallpaper@azwallpaper.gitlab.com', 'steal-my-focus-window@steal-my-focus-window', 'unblank@sun.wxg@gmail.com']"
)

# Update REQUIRED apt and install packages
log "$BLUE" "➔ Updating apt and installing packages..."
sudo apt-get update
sudo apt-get install curl -y
log "$GREEN" "✅ Successfully installed REQUIRED apt packages."

# Ensure the keyrings directory exists for all manually-added repository keys
sudo mkdir -p /etc/apt/keyrings

# Add Spotify apt repository if missing
if [ ! -f /etc/apt/sources.list.d/spotify.list ]; then
    log "$BLUE" "➔ Adding Spotify apt repository..."
    curl -fsSL https://download.spotify.com/debian/pubkey_5384CE82BA52C83A.asc \
        | sudo gpg --yes --dearmor --output /etc/apt/keyrings/spotify-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/spotify-keyring.gpg] https://repository.spotify.com stable non-free" \
        | sudo tee /etc/apt/sources.list.d/spotify.list
fi

# Update apt and install packages
log "$BLUE" "➔ Updating apt and installing packages..."
# Lets members of the wireshark group capture packets without root.
echo "wireshark-common wireshark-common/install-setuid boolean true" | sudo debconf-set-selections
sudo apt-get update
sudo apt-get install -y "${APT_PACKAGES[@]}" spotify-client
sudo usermod -aG wireshark "$USERNAME"
log "$GREEN" "✅ Successfully installed apt packages."

# Configure fingerprint authentication via PAM
if ! dpkg -s libpam-fprintd &>/dev/null; then
    log "$BLUE" "\n➔ Configuring fingerprint authentication..."
    sudo apt-get install -y fprintd libpam-fprintd
    sudo pam-auth-update --enable fprintd
    log "$GREEN" "✅ Fingerprint authentication configured."
fi

# Install Oh My Zsh and plugins
if [ ! -d "$HOME/.oh-my-zsh" ]; then
    log "$BLUE" "\n➔ Installing Oh My Zsh and plugins..."
    RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)"
    git clone https://github.com/romkatv/powerlevel10k.git "$HOME/.oh-my-zsh/themes/powerlevel10k"
    ZSH_CUSTOM="${ZSH_CUSTOM:-$HOME/.oh-my-zsh/custom}"
    git clone https://github.com/jkavan/terragrunt-oh-my-zsh-plugin.git "$ZSH_CUSTOM/plugins/terragrunt"
    git clone https://github.com/MichaelAquilina/zsh-you-should-use.git "$ZSH_CUSTOM/plugins/you-should-use"
    git clone https://github.com/zsh-users/zsh-autosuggestions "$ZSH_CUSTOM/plugins/zsh-autosuggestions"
    git clone https://github.com/fdellwing/zsh-bat.git "$ZSH_CUSTOM/plugins/zsh-bat"
    git clone https://github.com/zsh-users/zsh-history-substring-search "$ZSH_CUSTOM/plugins/zsh-history-substring-search"
    git clone https://github.com/zsh-users/zsh-syntax-highlighting "$ZSH_CUSTOM/plugins/zsh-syntax-highlighting"
    log "$GREEN" "✅ Successfully installed Oh My Zsh and plugins."
fi

# Before the dotfiles: the installer rewrites ~/.claude/settings.json, chezmoi's copy must win.
log "$BLUE" "\n➔ Installing Claude Code..."
if [ ! -f "$HOME/.local/bin/claude" ]; then
    curl -fsSL https://claude.ai/install.sh | bash
fi

# Dotfiles, after oh-my-zsh: its installer refuses to run once ~/.oh-my-zsh exists.
# mise comes first and provides chezmoi; the restored mise config then lists every tool.
log "$BLUE" "\n➔ Installing mise, dotfiles and mise tools..."
if [ ! -f "$HOME/.local/bin/mise" ]; then
    curl https://mise.run | sh
fi
export PATH="$HOME/.local/bin:$HOME/.local/share/mise/shims:$PATH"
# GITHUB_TOKEN lifts GitHub's anonymous API limit (60/h), too low for ~50 mise tools.
# shellcheck source=/dev/null
[ -f "$HOME/.zshrc.local" ] && . "$HOME/.zshrc.local"
if [ ! -d "$HOME/.local/share/chezmoi/.git" ]; then
    # HTTPS needs no SSH key yet; the remote switches to SSH for pushing.
    mise exec chezmoi -- chezmoi init --apply --force https://github.com/rqctl/dotfiles.git
    git -C "$HOME/.local/share/chezmoi" remote set-url origin git@github.com:rqctl/dotfiles.git
fi
# GITLAB_TOKEN is for the self-hosted GitLab: mise would send it to gitlab.com for glab (401).
GITLAB_TOKEN='' mise install
(cd "$HOME/.local/share/chezmoi" && prek install)
log "$GREEN" "✅ Dotfiles applied and mise tools installed."

# Set zsh as the default shell
if [ "$SHELL" != "$(command -v zsh)" ]; then
    log "$BLUE" "\n➔ Setting zsh as the default shell..."
    chsh -s "$(command -v zsh)"
    log "$GREEN" "✅ Default shell set to zsh (takes effect on next login)."
fi

# Install MesloLGS NF fonts required by Powerlevel10k
if [ ! -f "$HOME/.local/share/fonts/MesloLGS NF Regular.ttf" ]; then
    log "$BLUE" "\n➔ Installing MesloLGS NF fonts..."
    mkdir -p "$HOME/.local/share/fonts"
    FONT_BASE="https://github.com/romkatv/powerlevel10k-media/raw/master"
    curl -fsSL "${FONT_BASE}/MesloLGS%20NF%20Regular.ttf"      -o "$HOME/.local/share/fonts/MesloLGS NF Regular.ttf"
    curl -fsSL "${FONT_BASE}/MesloLGS%20NF%20Bold.ttf"         -o "$HOME/.local/share/fonts/MesloLGS NF Bold.ttf"
    curl -fsSL "${FONT_BASE}/MesloLGS%20NF%20Italic.ttf"       -o "$HOME/.local/share/fonts/MesloLGS NF Italic.ttf"
    curl -fsSL "${FONT_BASE}/MesloLGS%20NF%20Bold%20Italic.ttf" -o "$HOME/.local/share/fonts/MesloLGS NF Bold Italic.ttf"
    fc-cache -f "$HOME/.local/share/fonts"
    log "$GREEN" "✅ MesloLGS NF fonts installed."
fi

# GNOME extensions; they load at the next login
log "$BLUE" "\n➔ Installing GNOME extensions..."
shell_major="$(gnome-shell --version | grep -oE '[0-9]+' | head -1)"
for uuid in "${GNOME_EXTENSIONS[@]}"; do
    [ -d "$HOME/.local/share/gnome-shell/extensions/$uuid" ] && continue
    url="$(curl -fsSL "https://extensions.gnome.org/extension-info/?uuid=$uuid&shell_version=$shell_major" \
        | grep -oE '"download_url": *"[^"]+"' | sed -E 's/.*"([^"]+)"$/\1/')"
    zip="$(mktemp --suffix=.zip)"
    curl -fsSL "https://extensions.gnome.org$url" -o "$zip"
    gnome-extensions install --force "$zip"
    rm -f "$zip"
done
log "$GREEN" "✅ GNOME extensions installed."

log "$BLUE" "\n➔ Applying GNOME settings..."
for setting in "${GSETTINGS[@]}"; do
    read -r schema key value <<< "$setting"
    gsettings set "$schema" "$key" "$value"
done
log "$GREEN" "✅ GNOME settings applied."

# Block Ubuntu's snap-transition firefox package — written unconditionally so re-runs fix a broken state
sudo tee /etc/apt/preferences.d/firefox-deb-nosnap > /dev/null << 'EOF'
Package: firefox*
Pin: release o=Ubuntu*
Pin-Priority: -1

Package: firefox*
Pin: origin packages.mozilla.org
Pin-Priority: 1000
EOF

# Install Firefox from Mozilla repository
if [ ! -f /etc/apt/sources.list.d/mozilla.list ]; then
    log "$BLUE" "\n➔ Installing Firefox from Mozilla repository..."
    sudo snap remove --purge firefox 2>/dev/null || true
    sudo apt-get purge firefox -y 2>/dev/null || true
    sudo curl -fsSL https://packages.mozilla.org/apt/repo-signing-key.gpg \
        -o /etc/apt/keyrings/packages.mozilla.org.asc
    echo "deb [signed-by=/etc/apt/keyrings/packages.mozilla.org.asc] https://packages.mozilla.org/apt mozilla main" \
        | sudo tee /etc/apt/sources.list.d/mozilla.list
    sudo apt-get update
    sudo apt-get install -y firefox
    log "$GREEN" "✅ Successfully installed Firefox."
fi

# Install Cloudflare Warp
if ! command -v warp-cli &>/dev/null; then
    log "$BLUE" "\n➔ Installing Cloudflare Warp..."
    sudo curl -fsSL https://pkg.cloudflareclient.com/pubkey.gpg | sudo gpg --yes --dearmor --output /etc/apt/keyrings/cloudflare-warp-keyring.gpg
    echo "deb [signed-by=/etc/apt/keyrings/cloudflare-warp-keyring.gpg] https://pkg.cloudflareclient.com/ trixie main" | sudo tee /etc/apt/sources.list.d/cloudflare-client.list
    sudo apt-get update
    sudo apt-get install -y cloudflare-warp
    log "$GREEN" "✅ Successfully installed Cloudflare Warp."

    vpn_org="$(chezmoi execute-template '{{ .org.vpnOrg }}')"
    if [ -n "$vpn_org" ]; then
        log "$BLUE" "\n➔ Configuring Cloudflare Warp..."
        warp-cli registration new "$vpn_org"
        log "$GREEN" "✅ Successfully configured Cloudflare Warp."
    fi
fi

# Install VS Code
if ! command -v code &>/dev/null; then
    log "$BLUE" "\n➔ Installing VS Code..."
    code_deb="$(mktemp --suffix=.deb)"
    curl -fsSL -o "$code_deb" 'https://code.visualstudio.com/sha/download?build=stable&os=linux-deb-x64'
    sudo dpkg -i "$code_deb" || sudo apt-get -f install -y
    rm -f "$code_deb"
    log "$GREEN" "✅ Successfully installed VS Code."
fi
log "$BLUE" "\n➔ Installing VS Code extensions..."
has_ext() { code --list-extensions 2>/dev/null | grep -qix "$1"; }
for ext in "${VSCODE_EXTENSIONS[@]}"; do
    # `code` can exit 0 without installing (marketplace hiccup): check, retry once.
    for _ in 1 2; do
        has_ext "$ext" || code --install-extension "$ext" >/dev/null 2>&1 || true
    done
    has_ext "$ext" || log "$YELLOW" "⚠ VS Code extension $ext failed; re-run the script"
done
log "$GREEN" "✅ VS Code extensions installed."

# Install Slack
if [ ! -f /etc/apt/sources.list.d/slack.list ]; then
    log "$BLUE" "\n➔ Installing Slack..."
    # Slack only publishes this generic repo (packagecloud's installer picks the Ubuntu
    # codename, which 404s); key and line match what slack-desktop's cron.daily keeps.
    curl -fsSL https://packagecloud.io/slacktechnologies/slack/gpgkey \
        | sudo gpg --yes --dearmor --output /etc/apt/trusted.gpg.d/slack-desktop.gpg
    echo "deb https://packagecloud.io/slacktechnologies/slack/debian/ jessie main" \
        | sudo tee /etc/apt/sources.list.d/slack.list
    sudo apt-get update
    sudo apt-get install -y slack-desktop
    log "$GREEN" "✅ Successfully installed Slack."
fi

# Install 1Password
if [ ! -f /etc/apt/sources.list.d/1password.list ]; then
    log "$BLUE" "\n➔ Installing 1Password..."
    curl -fsSL https://downloads.1password.com/linux/keys/1password.asc \
        | sudo gpg --yes --dearmor --output /etc/apt/keyrings/1password-keyring.gpg
    echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/1password-keyring.gpg] https://downloads.1password.com/linux/debian/$(dpkg --print-architecture) stable main" \
        | sudo tee /etc/apt/sources.list.d/1password.list
    sudo mkdir -p /etc/debsig/policies/AC2D62742012EA22/
    curl -fsSL https://downloads.1password.com/linux/debian/debsig/1password.pol \
        | sudo tee /etc/debsig/policies/AC2D62742012EA22/1password.pol
    sudo mkdir -p /usr/share/debsig/keyrings/AC2D62742012EA22
    curl -fsSL https://downloads.1password.com/linux/keys/1password.asc \
        | sudo gpg --yes --dearmor --output /usr/share/debsig/keyrings/AC2D62742012EA22/debsig.gpg
    sudo apt-get update
    sudo apt-get install -y 1password
    log "$GREEN" "✅ Successfully installed 1Password."
fi

# Install docker-credential-gcr
if ! command -v docker-credential-gcr &>/dev/null; then
    log "$BLUE" "\n➔ Installing docker-credential-gcr..."
    VERSION=2.1.32
    OS=linux
    ARCH=amd64
    curl -fsSL "https://github.com/GoogleCloudPlatform/docker-credential-gcr/releases/download/v${VERSION}/docker-credential-gcr_${OS}_${ARCH}-${VERSION}.tar.gz" \
        | tar xz docker-credential-gcr
    chmod +x docker-credential-gcr
    sudo mv docker-credential-gcr /usr/bin/
    log "$GREEN" "✅ Successfully installed docker-credential-gcr."
fi

# Install vault-token-helper
if ! command -v vault-token-helper &>/dev/null; then
    log "$BLUE" "\n➔ Installing vault-token-helper..."
    VERSION=0.3.7
    curl -fsSL "https://github.com/joemiller/vault-token-helper/releases/download/v${VERSION}/vault-token-helper_${VERSION}_linux_amd64.tar.gz" \
        | tar xz vault-token-helper
    chmod +x vault-token-helper
    sudo mv vault-token-helper /usr/local/bin/
    log "$GREEN" "✅ Successfully installed vault-token-helper."
fi
if ! grep -q 'vault-token-helper' "$HOME/.vault" 2>/dev/null; then
    log "$BLUE" "\n➔ Enabling vault-token-helper..."
    vault-token-helper enable
    log "$GREEN" "✅ vault-token-helper enabled."
fi

# Install Docker
if ! command -v docker &>/dev/null; then
    log "$BLUE" "\n➔ Installing Docker..."
    sudo apt-get update
    sudo apt-get install -y ca-certificates curl
    sudo install -m 0755 -d /etc/apt/keyrings
    sudo curl -fsSL https://download.docker.com/linux/ubuntu/gpg -o /etc/apt/keyrings/docker.asc
    sudo chmod a+r /etc/apt/keyrings/docker.asc
    # shellcheck disable=SC1091
    echo \
        "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/ubuntu \
        $(source /etc/os-release && echo "${UBUNTU_CODENAME:-$VERSION_CODENAME}") stable" | \
        sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin
    log "$GREEN" "✅ Successfully installed Docker."
fi
# Outside the install block, so a re-run after a failure still adds the group.
sudo groupadd -f docker
sudo usermod -aG docker "$USERNAME"

# Configure Docker daemon (custom bridge IP and address pools to avoid conflicts with internal networks)
if [ ! -f /etc/docker/daemon.json ]; then
    log "$BLUE" "\n➔ Configuring Docker daemon..."
    sudo tee /etc/docker/daemon.json > /dev/null << 'EOF'
{
  "bip": "10.200.0.1/24",
  "default-address-pools": [
    {"base":"10.200.1.1/24","size":24},
    {"base":"10.200.2.1/24","size":24},
    {"base":"10.200.3.1/24","size":24},
    {"base":"10.200.4.1/24","size":24},
    {"base":"10.200.5.1/24","size":24},
    {"base":"10.200.6.1/24","size":24},
    {"base":"10.200.7.1/24","size":24},
    {"base":"10.200.8.1/24","size":24},
    {"base":"10.200.9.1/24","size":24}
  ],
  "features": {
    "containerd-snapshotter": true
  }
}
EOF
    log "$GREEN" "✅ Docker daemon configured."
    sudo systemctl is-active --quiet docker && sudo systemctl restart docker || true
fi

# Add metadata.google.internal to /etc/hosts if missing
if ! grep -q "^127.0.0.1 metadata.google.internal" /etc/hosts; then
    log "$BLUE" "\n➔ Adding metadata.google.internal to /etc/hosts..."
    echo "127.0.0.1 metadata.google.internal" | sudo tee -a /etc/hosts > /dev/null
    log "$GREEN" "✅ Successfully added metadata.google.internal to /etc/hosts."
fi

# Cloudproxy dns resolver configuration
if ! grep -q "^Domains=~cloudproxy.app" /etc/systemd/resolved.conf.d/cloudproxy.conf 2>/dev/null; then
    log "$BLUE" "\n➔ Configuring systemd-resolved for cloudproxy.app..."
    sudo mkdir -p /etc/systemd/resolved.conf.d/
    sudo tee /etc/systemd/resolved.conf.d/cloudproxy.conf > /dev/null << 'EOF'
[Resolve]
DNS=8.8.8.8
Domains=~cloudproxy.app
EOF
    sudo systemctl restart systemd-resolved
    log "$GREEN" "✅ Successfully configured systemd-resolved for cloudproxy.app."
fi

# Disable WiFi power saving (prevents connection drops on some hardware)
WIFI_POWERSAVE_CONF="/etc/NetworkManager/conf.d/default-wifi-powersave-on.conf"
if [ -f "$WIFI_POWERSAVE_CONF" ] && grep -qP '^\s*wifi\.powersave\s*=\s*3' "$WIFI_POWERSAVE_CONF"; then
    log "$BLUE" "\n➔ Disabling WiFi power saving..."
    sudo sed -i 's/^\(\s*wifi\.powersave\s*=\s*\)3/\12/' "$WIFI_POWERSAVE_CONF"
    sudo systemctl restart NetworkManager
    log "$GREEN" "✅ WiFi power saving disabled (wifi.powersave set to 2)."
fi

# Docker registry configuration
if [ ! -f "$DOCKER_CONFIG_FILE" ] || ! grep -q "$REGISTRY" "$DOCKER_CONFIG_FILE"; then
    log "$BLUE" "\n➔ Configuring Docker for $REGISTRY..."
    gcloud auth configure-docker "$REGISTRY"
    log "$GREEN" "✅ Docker configured for $REGISTRY."
fi

# Install DisplayLink driver (required for Dell/Synaptics USB docking stations)
if ! dpkg -s displaylink-driver &>/dev/null; then
    log "$BLUE" "\n➔ Installing DisplayLink driver..."
    local_deb="$(mktemp --suffix=.deb)"
    curl -fsSL https://www.synaptics.com/sites/default/files/Ubuntu/pool/stable/main/all/synaptics-repository-keyring.deb \
        -o "$local_deb"
    sudo dpkg -i "$local_deb"
    rm -f "$local_deb"
    sudo apt-get update
    sudo apt-get install -y displaylink-driver
    log "$GREEN" "✅ Successfully installed DisplayLink driver."
fi

TODO_FILE="$HOME/todo_$(date +%Y%m%d-%H%M).txt"

TODO_ITEMS=(
    ""
    "=== ACTIONS ==="
    "[ ] Enroll fingerprint: fprintd-enroll"
    "[ ] Reboot to activate the DisplayLink driver and handle the Docker group membership change"
    ""
    "=== RESTORE FROM BACKUP (secrets and data — not in the dotfiles repo) ==="
    "[ ] ~/.ssh/ (private keys — remember to chmod 600)"
    "[ ] ~/.gnupg/ (GPG keys for commit signing)"
    "[ ] ~/.kube/config (cluster contexts)"
    "[ ] ~/.aws/sso/ (SSO cache)"
    "[ ] ~/.config/glab-cli/config.yml and ~/.config/argocd/config (tokens)"
    "[ ] ~/.mozilla/ or sign in to Firefox account"
    "[ ] ~/Documents/, ~/Pictures/ and other user data"
)

{
    echo "Post-install TODO — $(date '+%Y-%m-%d %H:%M')"
    echo "================================================"
    printf '%s\n' "${TODO_ITEMS[@]}"
} > "$TODO_FILE"

log "$YELLOW" "\n🎗️  Post-install TODO (saved to $TODO_FILE):"
while IFS= read -r line; do
    log "$YELLOW" "   $line"
done < "$TODO_FILE"
