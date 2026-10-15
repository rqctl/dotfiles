# dotfiles

Managed with [chezmoi](https://www.chezmoi.io/). No secrets live in this repo.

## Daily loop

| Need | Do |
|---|---|
| Edit or add any config file | `dot` (fzf picker) or `dot ~/.some/file` |
| Back it up | `chezmoi cd`, `git commit -am "..."`, `git push` |
| A file holds a private value | `dot -t <file>`, see below |
| What's managed, and how | `dot -l` |

`dot` edits the source and applies it, for plain files and templates alike. A file
chezmoi doesn't manage yet is added first, even if you then change nothing
(`chezmoi forget <file>` undoes that); one that looks like it holds a token is
refused. On a managed file, quitting without changes is a no-op.

Plain files are symlinks into this repo (`mode = "symlink"`), so editing them
directly, or a tool rewriting them, changes the repo at once. Templates and
private/executable files stay as copies: edit those through `dot`. A change made
another way still works on this machine but is not backed up: `chezmoi status`
shows it as `MM`, and the next apply asks before overwriting it. The usual cases are
VS Code's settings UI and Claude Code's `/model` or `/plugin`: both settings files
are templates.

`dot -l` types: `symlink` green (edit anywhere), `template` yellow and `copy` cyan
(edit with `dot`), `link` purple (a link chezmoi makes to a path outside this repo).
Colour only on a terminal, and not with `NO_COLOR` set.

### A file holds a private value

Managed or not, same two steps:

```sh
chezmoi edit-config      # only if the value is new: add it under [data] or [data.org]
dot -t <file>            # makes it a template, then replace the value with {{ .key }}
```

e.g. `{{ .gitWorkEmail }}`, `{{ .org.gitlabHost }}`. The rendered file in `~` stays
identical; only the repo copy holds the placeholder.

Only declared values are protected: gitleaks and `dot` recognise tokens, not personal
data such as a card number or an email. Once a value is in `chezmoi.toml`, the hook
refuses any commit while a tracked file still holds it, exactly as written (same
spacing). It cannot clean what was already pushed: that stays in GitHub's history.

A `{{ .key }}` that isn't declared yet makes the apply fail and leaves the file in `~`
untouched; add the key and run `chezmoi apply`.

## Backup and restore

**Backup**, before wiping the old PC (asks for sudo, then an archive passphrase):

```sh
~/scripts/backup_pc.sh <usb-dir>       # -> <usb-dir>/pc-backup-<date>.tar.gz.gpg
gpg -d <usb-dir>/pc-backup-<date>.tar.gz.gpg | tar -tz >/dev/null && echo OK   # verify
```

The paths it covers are the `PATHS` list in `backup_pc.sh`. Git repos are not in it, and
the restore downloads this repo from GitHub: push this one and your others first.

**Restore**, on the fresh install:

```sh
# 1. Archive (asks for the passphrase typed at backup time, no key involved), then GPG keys
gpg -d <usb-dir>/pc-backup-<date>.tar.gz.gpg | tar -xz -C ~
gpg --import ~/.gnupg-export/secret-keys.asc
gpg --import-ownertrust ~/.gnupg-export/ownertrust.txt && rm -rf ~/.gnupg-export

# 2. Everything else: Wi-Fi, packages, oh-my-zsh, mise, dotfiles, tools, git hooks
wget -qO setup.sh https://raw.githubusercontent.com/rqctl/dotfiles/main/scripts/executable_custom_local_pc_setup.sh
bash setup.sh
```

**Without an archive** (a colleague, or a PC you start clean): skip step 1. Copy
`docs/chezmoi.toml.example` to `~/.config/chezmoi/chezmoi.toml` and fill it in, then run
step 2. `~/.zshrc.local` is optional (`dot_zshrc.local.example`). To use your own fork,
run `DOTFILES_REPO=you/dotfiles bash setup.sh`.

Then reboot and follow the TODO list the script prints (also in `~/todo_*.txt`). The
script is safe to re-run.

**Check the result**, and see everything the setup customizes, with
`~/scripts/healthcheck.sh` (add `--backup` if you restored an archive). Each line is
one customization, marked ✓ or ✗; the package, extension and GNOME lists are read from
the setup script.

**Secure Boot:** the first reboot may show a blue "Perform MOK management" screen: a
DKMS driver (DisplayLink) queued a signing key, and without it the module stays
blocked. Choose *Enroll MOK*, *Continue*, *Yes*, then the one-time password set when
the key was queued. Forgot it? *Continue boot*, then queue a new key and reboot:

```sh
sudo update-secureboot-policy --new-key
sudo mokutil --import /var/lib/shim-signed/mok/MOK.der   # asks for a new one-time password
```

## Manual emergency backup (for control freaks)

A full copy of `~` and `/etc` as one encrypted file, on top of `backup_pc.sh`. A single
tar keeps permissions and symlinks, which an exFAT drive can't. Regenerable bulk and git
repos are left out; adjust the excludes to taste.

```sh
MEDIA=White                            # label of the external drive
DEST=/run/media/$USER/$MEDIA
H=${HOME#/}                            # home path without the leading /

sudo true && sudo tar -C / -cpf - \
    --exclude=$H/github --exclude=$H/gitlab \
    --exclude=$H/.cache --exclude=$H/.local/share/Trash --exclude=$H/.local/share/mise \
    --exclude=$H/go --exclude=$H/.rustup --exclude=$H/.cargo --exclude=$H/.npm \
    --exclude=$H/.var \
    $H etc \
  | pigz | gpg --symmetric --cipher-algo AES256 -o "$DEST/full-backup-$(date +%Y%m%d).tar.gz.gpg"
sync                                    # flush to the drive before unplugging
```

Verify it:

```sh
gpg -d "$DEST"/full-backup-*.tar.gz.gpg | pigz -d | tar -t >/dev/null && echo OK
```

## Machine-local values

Two files, never committed. `backup_pc.sh` includes both.

| File | Holds |
|---|---|
| `~/.zshrc.local` | tokens, exported as env vars |
| `~/.config/chezmoi/chezmoi.toml` | every private value a managed file needs: git identities, `isWork`, `repoRoot`, organisation values under `[data.org]`, anything moved out with `dot -t` |

**The repo contains no employer-identifying data.** `.chezmoidata/00-defaults.yaml`
holds neutral placeholders for the `[data.org]` keys, so everything renders without
real values (`gitlab.example.com`, empty Vault list, VPN step skipped). Get the real
values from whoever shared this repo with you.

Pre-commit hooks: `gitleaks` for tokens, and `.check-private-values.sh`, which
refuses any commit while a tracked file contains a value (6+ characters) from `[data]`
in `chezmoi.toml`; `localUser` is declared there so the login name can't leak.
Bypass a false positive with `git commit --no-verify`.

Set `isWork = false` on a personal machine to skip the work-only modules.

## Never in this repo

Files holding credentials or connection secrets: SSH and GPG keys, kubeconfig, cloud
CLI auth (`~/.aws/sso/`, `~/.config/gcloud/`), and tool tokens (`glab`, `argocd`).
`backup_pc.sh` backs up some of them (see Backup and restore).

## Git identity

`~/.gitconfig` has **no** `[user]` section. Identity is chosen by repo location:

| Location | Identity | Signing |
|---|---|---|
| `$repoRoot/` (GitLab clones) | work | GPG signed |
| `~/github/` | personal | unsigned |
| `~/.local/share/chezmoi/` | personal | unsigned |

A repo outside all three has no identity and `git commit` will refuse — deliberate,
so a work commit can never go out under the personal address. For a one-off repo:
`git config user.email you@example.com`.

## Learning chezmoi

See [docs/chezmoi-cheatsheet.md](docs/chezmoi-cheatsheet.md).
