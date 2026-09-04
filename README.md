# dotfiles

Managed with [chezmoi](https://www.chezmoi.io/). No secrets live in this repo.

## New machine

```sh
# 1. System packages, oh-my-zsh, Docker, drivers, fonts
bash scripts/custom_local_pc_setup.sh

# 2. Dotfiles
chezmoi init --apply git@github.com:rqctl/dotfiles.git

# 3. Machine-local secrets (never versioned)
cp ~/.zshrc.local.example ~/.zshrc.local && chmod 600 ~/.zshrc.local && vim ~/.zshrc.local
```

Order matters: the setup script installs oh-my-zsh, and chezmoi writes the config
files inside it. Running chezmoi first leaves `~/.oh-my-zsh` populated and the
oh-my-zsh installer will refuse to run.

## Daily loop

```sh
chezmoi edit --apply ~/.zshrc   # edit source, apply immediately
chezmoi diff                    # what apply would change
chezmoi re-add                  # pull edits made directly in ~ back into the repo
chezmoi update                  # git pull + apply, on a second machine
```

## What is and isn't here

Managed: zsh (`.zshrc`, `.zshrc.custom`, `.oh-my-zsh/custom/*.zsh`), `.p10k.zsh`,
git config, mise, k9s, taplo, ghorg, glab aliases, VS Code settings, `~/.local/bin/tree1`,
`~/ansible.cfg`, `~/.vault`, and `scripts/custom_local_pc_setup.sh`.

Never managed: `~/.zshrc.local` (tokens), `~/.ssh/`, `~/.gnupg/`, `~/.kube/config`,
`~/.aws/sso/`, `~/.config/gcloud/`, `~/.config/glab-cli/config.yml`,
`~/.config/argocd/config`. See `.chezmoiignore`.

`~/.config/Code/User/settings.json` is a template (it holds a `$repoRoot`-relative
interpreter path). VS Code rewrites that file itself, and `chezmoi re-add` refuses to
overwrite templates — so settings changed through the VS Code UI are lost on the next
`chezmoi apply`. Change it with `chezmoi edit ~/.config/Code/User/settings.json`.

A `gitleaks` pre-commit hook guards the repo. Install it after cloning: `prek install`.

## Machine-specific values

Nothing is pinned to one machine, and **the repo contains no employer-identifying
data**. Values come from two places, neither of them committed:

**Personal / per-machine** — prompted once by `.chezmoi.toml.tmpl`, stored in
`~/.config/chezmoi/chezmoi.toml`: `repoRoot`, work and personal git identity, and
`isWork` (set false on a personal machine to skip the work-only modules).

**Organisation-specific** — `.chezmoidata/99-local.yaml`, which is git-ignored.
`.chezmoidata/00-defaults.yaml` is committed and holds neutral placeholders for the
same keys; `99-` sorts after `00-`, so the local file overrides every one of them.

```sh
chezmoi cd
cp docs/99-local.yaml.example .chezmoidata/99-local.yaml
$EDITOR .chezmoidata/99-local.yaml
chezmoi apply
```

Without that file everything still renders and parses — you get `gitlab.example.com`,
an empty Vault list, and the VPN registration step is skipped. Get the real values
from whoever shared this repo with you; they are deliberately not in git.

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
