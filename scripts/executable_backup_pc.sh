#!/bin/bash
# Backs up what chezmoi and git can't restore into one passphrase-encrypted
# archive. Usage: backup_pc.sh <dest-dir>. Restore steps: README, "Backup and restore".
set -euo pipefail

DEST="${1:?usage: $0 <destination-dir>}"
[ -d "$DEST" ] || { echo "Not a directory: $DEST" >&2; exit 1; }

# Relative to $HOME.
PATHS=(
    .ssh
    .gnupg-export
    .nm-export
    .zshrc.local
    .zsh_history
    .config/chezmoi/chezmoi.toml
    .kube
    .aws/config
    .config/mozilla
    .mcp.json
    scripts
    vscode
    Desktop
    Documents
    Music
    Notes
    Pictures
    Videos
)

cd "$HOME"

# Exported keys restore cleanly on another gpg version; a copy of ~/.gnupg may not.
rm -rf .gnupg-export .nm-export
mkdir -m 700 .gnupg-export .nm-export
trap 'rm -rf "$HOME/.gnupg-export" "$HOME/.nm-export"' EXIT
gpg --export-secret-keys --armor > .gnupg-export/secret-keys.asc
gpg --export-ownertrust > .gnupg-export/ownertrust.txt

# One memory dir per Claude project; they only match again at the same paths.
for m in .claude/projects/*/memory; do PATHS+=("$m"); done

# Wi-Fi passwords: NetworkManager keeps them in root-only netplan files.
sudo cp /etc/netplan/90-NM-*.yaml .nm-export/
sudo chown -R "$USER:" .nm-export

existing=()
for p in "${PATHS[@]}"; do
    if [ -e "$p" ]; then existing+=("$p"); else echo "skip (missing): ~/$p" >&2; fi
done

out="$DEST/pc-backup-$(date +%Y%m%d-%H%M).tar.gz.gpg"
tar -c -I pigz --exclude=.kube/cache "${existing[@]}" \
    | gpg --symmetric --cipher-algo AES256 -o "$out"

# Flush to the drive, or an unplug right after could leave a partial file.
sync

echo "✅ $out ($(du -h "$out" | cut -f1))"
