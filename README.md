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

## New machine

```sh
# 1. Restore from your backup (password manager), chmod 600 both.
#    Templates are in this repo on GitHub:
#    ~/.config/chezmoi/chezmoi.toml   (or start from docs/chezmoi.toml.example)
#    ~/.zshrc.local                   (or start from dot_zshrc.local.example)

# 2. Everything else: packages, oh-my-zsh, mise, dotfiles, mise tools, git hooks
wget -qO setup.sh https://raw.githubusercontent.com/rqctl/dotfiles/main/scripts/executable_custom_local_pc_setup.sh
bash setup.sh
```

The script installs mise, which runs chezmoi once to apply the dotfiles; the mise
config they bring then installs every tool, chezmoi included. It is safe to re-run:
the applied copy lives at `~/scripts/custom_local_pc_setup.sh`.

## Machine-local values

Two files, never committed. Back both up outside git.

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
in `chezmoi.toml`. Bypass a false positive with `git commit --no-verify`.

Set `isWork = false` on a personal machine to skip the work-only modules.

## Never in this repo

Files holding credentials or connection secrets: SSH and GPG keys, kubeconfig, cloud
CLI auth (`~/.aws/sso/`, `~/.config/gcloud/`), and tool tokens (`glab`, `argocd`).
Back them up separately; the setup script's TODO lists them.

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
