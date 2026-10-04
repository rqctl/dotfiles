#!/bin/bash
# Backs up what chezmoi and git can't restore into one passphrase-encrypted
# archive. Usage: backup_pc.sh <dest-dir>. Restore steps: README, "New machine".
set -euo pipefail

DEST="${1:?usage: $0 <destination-dir>}"
[ -d "$DEST" ] || { echo "Not a directory: $DEST" >&2; exit 1; }

# Claude names a project dir after its path, with every / replaced by -.
CLAUDE_PROJECTS=".claude/projects/${HOME//\//-}"

# Relative to $HOME.
PATHS=(
    .ssh
    .gnupg-export
    .zshrc.local
    .zsh_history
    .config/chezmoi/chezmoi.toml
    .kube
    .aws
    .azure
    .confluent
    .vault-tokens
    .docker/config.json
    "$CLAUDE_PROJECTS/memory"
    "$CLAUDE_PROJECTS-gitlab-idp-resource-plane-infra-core/memory"
    Desktop
    Documents
    Music
    Notes
    Pictures
    Videos
)

cd "$HOME"

# Exported keys restore cleanly on another gpg version; a copy of ~/.gnupg may not.
rm -rf .gnupg-export
mkdir -m 700 .gnupg-export
trap 'rm -rf "$HOME/.gnupg-export"' EXIT
gpg --export-secret-keys --armor > .gnupg-export/secret-keys.asc
gpg --export-ownertrust > .gnupg-export/ownertrust.txt

existing=()
for p in "${PATHS[@]}"; do
    if [ -e "$p" ]; then existing+=("$p"); else echo "skip (missing): ~/$p" >&2; fi
done

out="$DEST/pc-backup-$(date +%Y%m%d-%H%M).tar.gz.gpg"
tar -cz --exclude=.kube/cache "${existing[@]}" \
    | gpg --symmetric --cipher-algo AES256 -o "$out"

echo "✅ $out ($(du -h "$out" | cut -f1))"
